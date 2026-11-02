@tool
class_name MeshBuilder
extends RefCounted
## Fabrique de maillages lisses à partir de formes simples (ellipsoïdes
## déformées, profils tournés, tubes, profilés…), sans fichier 3D externe.
##
## Chaque forme a sa couleur, éventuellement « peinte » par une fonction
## (taches, rayures, museau clair…), et un matériau (peinture brillante,
## fourrure, caoutchouc, chrome…). Toutes les formes d'un même matériau sont
## réunies dans une seule surface : un modèle très détaillé ne coûte que
## quelques appels de dessin.
##
## Les couleurs « peintes » reçoivent la position du sommet dans le repère
## courant (celui du dernier push), avant tout autre déplacement.

## Ombrage « fourrure » (et tissu, peau) : lumière enveloppante, léger grain,
## halo doux sur les bords.
const SOFT_SHADER := """
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx;
uniform float roughness_value = 0.85;
uniform float specular_value = 0.3;
uniform float grain = 0.12;
uniform float grain_scale = 55.0;
uniform float sheen = 0.45;
varying vec3 obj_pos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	vec3 base = to_linear(COLOR.rgb);
	vec3 q = obj_pos * grain_scale;
	// grain de la fourrure, estompé au loin (sinon il scintille)
	float fade = clamp(1.6 - length(fwidth(q)), 0.0, 1.0);
	float g = (vnoise(q) * 0.6 + vnoise(q * vec3(2.7, 1.3, 2.7)) * 0.4 - 0.5) * grain * fade;
	ALBEDO = base * (1.0 + g);
	ROUGHNESS = roughness_value;
	SPECULAR = specular_value;
	RIM = sheen;
	RIM_TINT = 0.55;
}
"""

## Orientation des faces d'une forme : d'après un point intérieur, telle
## quelle, ou retournée.
enum { ORIENT_REF, ORIENT_KEEP, ORIENT_FLIP }

## Yeux : iris (couleur du sommet), pupille, reflets et contour dessinés au
## pixel près. UV : position sur l'œil (1 = bord de l'iris, vu de face) ;
## UV2 : taille de la pupille et aplatissement (fente des yeux de chat).
const EYE_SHADER := """
shader_type spatial;
render_mode specular_schlick_ggx;
uniform vec3 sclera : source_color = vec3(0.98, 0.97, 0.94);
uniform vec3 liner : source_color = vec3(0.16, 0.11, 0.1);

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	vec2 q = UV;
	float r = length(q);
	float aa = max(fwidth(r), 0.002) * 1.3;
	vec3 iris = to_linear(COLOR.rgb);
	// blanc de l'œil, plus sombre vers le bord (creux de l'orbite), puis contour
	float lr = COLOR.a * 2.0;
	vec3 col = mix(sclera, sclera * vec3(0.78, 0.74, 0.72), smoothstep(lr * 0.72, lr, r));
	col = mix(col, liner, smoothstep(lr - 0.07 - aa, lr - 0.02 + aa, r));
	// iris : dégradé, stries, anneau sombre au bord
	float a = atan(q.y, q.x);
	float streak = 0.88 + 0.12 * sin(a * 23.0 + sin(a * 5.0) * 2.0);
	vec3 ic = mix(iris * 1.7, iris * 0.6, smoothstep(0.15, 1.0, r)) * streak;
	ic = mix(ic, iris * 0.22, smoothstep(0.78, 1.0, r));
	col = mix(ic, col, smoothstep(1.0 - aa, 1.0 + aa, r));
	// pupille (ronde, ou fente)
	vec2 pq = q / vec2(max(UV2.y, 0.05), 1.0);
	float pr = length(pq) / max(UV2.x, 0.05);
	float paa = max(fwidth(pr), 0.002) * 1.3;
	col = mix(vec3(0.008), col, smoothstep(1.0 - paa, 1.0 + paa, pr));
	// reflets de lumière : grand en haut à gauche, petit en bas à droite
	float h1 = length((q - vec2(-0.36, 0.4)) / vec2(0.3, 0.26));
	float h2 = length(q - vec2(0.34, -0.36)) / 0.11;
	float h = max(1.0 - smoothstep(1.0 - aa * 4.0, 1.0 + aa * 4.0, h1), 1.0 - smoothstep(1.0 - aa * 9.0, 1.0 + aa * 9.0, h2));
	ALBEDO = mix(col, vec3(1.0), h);
	EMISSION = vec3(h) * 0.6;
	ROUGHNESS = 0.07;
	SPECULAR = 0.75;
}
"""

static var _materials := {}


## Triangles d'un même matériau.
class Surf:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var i := PackedInt32Array()
	var has_uv2 := false


var _surf := {} # matériau -> Surf
var _xf := Transform3D.IDENTITY
## Coordonnées de texture des formes suivantes (position -> Vector2), et UV2
## constant ; à remettre à zéro après usage (Callable(), Vector2.ZERO).
var uv_fn := Callable()
var uv2 := Vector2.ZERO
var _stack: Array[Transform3D] = []


# ---------------- Matériaux ----------------

## Matériau partagé d'un type de surface (les couleurs viennent des sommets).
static func material(kind: String) -> Material:
	if _materials.has(kind):
		return _materials[kind]
	var m: Material
	match kind:
		"fur":
			m = _soft(0.85, 0.3, 0.06, 70.0, 0.28)
		"cloth":
			m = _soft(0.9, 0.25, 0.04, 120.0, 0.25)
		"skin":
			m = _soft(0.42, 0.5, 0.04, 30.0, 0.2)
		"felt":
			m = _soft(0.95, 0.15, 0.1, 90.0, 0.35)
		"eye":
			var em := ShaderMaterial.new()
			em.shader = _shader(EYE_SHADER)
			m = em
		_:
			var s := StandardMaterial3D.new()
			s.vertex_color_use_as_albedo = true
			s.vertex_color_is_srgb = true
			match kind:
				"paint":
					s.roughness = 0.3
					s.metallic_specular = 0.4
					s.clearcoat_enabled = true
					s.clearcoat = 0.25
					s.clearcoat_roughness = 0.08
				"plastic":
					s.roughness = 0.5
					s.metallic_specular = 0.45
				"rubber":
					s.roughness = 0.92
					s.metallic_specular = 0.2
				"chrome":
					s.metallic = 1.0
					s.roughness = 0.16
				"metal":
					s.metallic = 0.65
					s.roughness = 0.42
				"gloss":
					s.roughness = 0.14
					s.metallic_specular = 0.8
				"glass":
					s.roughness = 0.04
					s.metallic = 0.35
					s.metallic_specular = 1.0
				"glow":
					s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				"matte":
					s.roughness = 1.0
					s.metallic_specular = 0.1
				_:
					s.roughness = 0.7
					s.metallic_specular = 0.35
			m = s
	_materials[kind] = m
	return m


static func _soft(rough: float, spec: float, grain: float, scale: float, sheen: float) -> ShaderMaterial:
	var sh := _shader(SOFT_SHADER)
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("roughness_value", rough)
	m.set_shader_parameter("specular_value", spec)
	m.set_shader_parameter("grain", grain)
	m.set_shader_parameter("grain_scale", scale)
	m.set_shader_parameter("sheen", sheen)
	return m


static var _shaders := {}


## Shader compilé une seule fois pour un même code.
static func _shader(code: String) -> Shader:
	var key := code.hash()
	if not _shaders.has(key):
		var sh := Shader.new()
		sh.code = code
		_shaders[key] = sh
	return _shaders[key]


static func clear_cache() -> void:
	_materials.clear()
	_shaders.clear()


## Enregistre un matériau sur mesure (feuillage qui ondule, eau…) sous un nom.
static func register_material(kind: String, m: Material) -> void:
	_materials[kind] = m


# ---------------- Repère ----------------

## Les formes suivantes sont placées dans ce repère (relatif au repère courant).
func push(t: Transform3D) -> void:
	_stack.append(_xf)
	_xf = _xf * t


func pop() -> void:
	_xf = _stack.pop_back()


func is_empty() -> bool:
	return _surf.is_empty()


# ---------------- Formes ----------------

## Ellipsoïde déformée par des bosses : chaque bosse [direction, force, finesse]
## pousse la surface vers l'extérieur (force > 0) ou l'enfonce (force < 0)
## autour d'une direction (repère de la forme). Avec shape (fonction : direction
## unitaire -> position), la forme est entièrement libre.
func ellipsoid(center: Vector3, radii: Vector3, kind: String, paint: Variant, basis := Basis(),
		bumps: Array = [], rings := 14, segs := 24, shape := Callable()) -> void:
	var v := PackedVector3Array()
	var idx := PackedInt32Array()
	for r in rings + 1:
		var phi := PI * r / rings
		var sp := sin(phi)
		var cp := cos(phi)
		for s in segs:
			var th := TAU * s / segs
			var d := Vector3(sp * cos(th), cp, -sp * sin(th))
			var p: Vector3
			if shape.is_valid():
				p = shape.call(d)
			else:
				var k := 1.0
				for b in bumps:
					var dir: Vector3 = b[0]
					var dt := d.dot(dir)
					if dt > 0.0:
						k += float(b[1]) * pow(dt, float(b[2]))
				p = d * k * radii
			v.append(center + basis * p)
	_grid(idx, rings + 1, segs, true)
	_emit(kind, v, idx, paint, center)


func sphere(center: Vector3, r: float, kind: String, paint: Variant, rings := 12, segs := 20) -> void:
	ellipsoid(center, Vector3(r, r, r), kind, paint, Basis(), [], rings, segs)


## Boîte aux angles arrondis (superellipsoïde : e proche de 0 = boîte, 1 = ellipsoïde).
func rbox(center: Vector3, half: Vector3, kind: String, paint: Variant, basis := Basis(),
		e := 0.25, rings := 12, segs := 20) -> void:
	var v := PackedVector3Array()
	var idx := PackedInt32Array()
	for r in rings + 1:
		var phi := -PI / 2.0 + PI * r / rings
		for s in segs:
			var th := -PI + TAU * s / segs
			var cphi := _spow(cos(phi), e)
			var p := Vector3(half.x * cphi * _spow(cos(th), e), -half.y * _spow(sin(phi), e), half.z * cphi * _spow(sin(th), e))
			v.append(center + basis * p)
	_grid(idx, rings + 1, segs, true)
	_emit(kind, v, idx, paint, center)


## Profil tourné autour de l'axe Y du repère t : points (rayon, hauteur).
func lathe(profile: PackedVector2Array, kind: String, paint: Variant, t := Transform3D.IDENTITY,
		segs := 24, wobble := Callable()) -> void:
	var v := PackedVector3Array()
	var idx := PackedInt32Array()
	for pr in profile:
		for s in segs:
			var th := TAU * s / segs
			var rad := pr.x
			if wobble.is_valid():
				rad += float(wobble.call(th, pr.y))
			v.append(t * Vector3(rad * cos(th), pr.y, -rad * sin(th)))
	_grid(idx, profile.size(), segs, true)
	var mid := profile[profile.size() / 2]
	_emit(kind, v, idx, paint, t * Vector3(0.0, mid.y, 0.0))


## Tube le long d'un chemin (rayon pour chaque point). flat < 1 : section
## aplatie selon flat_axis (par exemple une oreille aplatie vers l'avant).
## Les extrémités de rayon non nul sont arrondies (ou plates).
func tube(path: PackedVector3Array, radii: PackedFloat32Array, kind: String, paint: Variant,
		segs := 10, flat := 1.0, flat_axis := Vector3.ZERO, closed := false, round_ends := true) -> void:
	var n := path.size()
	if n < 2:
		return
	# repères le long du chemin (transport parallèle : pas de torsion)
	var tangents: Array[Vector3] = []
	for i in n:
		var a := path[(i - 1 + n) % n] if closed or i > 0 else path[i]
		var b := path[(i + 1) % n] if closed or i < n - 1 else path[i]
		tangents.append((b - a).normalized())
	var t0 := tangents[0]
	var bin0: Vector3
	if flat_axis != Vector3.ZERO and absf(flat_axis.normalized().dot(t0)) < 0.98:
		bin0 = (flat_axis - t0 * flat_axis.dot(t0)).normalized()
	else:
		bin0 = t0.cross(Vector3.UP if absf(t0.y) < 0.9 else Vector3.RIGHT).normalized()
	var nrm := bin0.cross(t0).normalized()
	var rings_pts: Array[PackedVector3Array] = []
	for i in n:
		if i > 0:
			var axis := tangents[i - 1].cross(tangents[i])
			if axis.length() > 1e-6:
				nrm = nrm.rotated(axis.normalized(), tangents[i - 1].angle_to(tangents[i]))
		var bin := tangents[i].cross(nrm).normalized()
		var ring := PackedVector3Array()
		for s in segs:
			var th := TAU * s / segs
			ring.append(path[i] + (nrm * cos(th) + bin * sin(th) * flat) * radii[i])
		rings_pts.append(ring)
	var v := PackedVector3Array()
	var caps := 3
	var round_start := not closed and round_ends and radii[0] > 0.0
	var round_end := not closed and round_ends and radii[n - 1] > 0.0
	if round_start:
		for c in caps:
			var a := PI / 2.0 * (1.0 - float(c) / caps)
			var off := -tangents[0] * sin(a) * radii[0]
			for s in segs:
				v.append(path[0] + off + (rings_pts[0][s] - path[0]) * cos(a))
	for ring in rings_pts:
		v.append_array(ring)
	if round_end:
		for c in range(1, caps + 1):
			var a := PI / 2.0 * float(c) / caps
			var off := tangents[n - 1] * sin(a) * radii[n - 1]
			for s in segs:
				v.append(path[n - 1] + off + (rings_pts[n - 1][s] - path[n - 1]) * cos(a))
	var rows := v.size() / segs
	var idx := PackedInt32Array()
	_grid(idx, rows, segs, true)
	if closed:
		for s in segs:
			var a := (rows - 1) * segs + s
			var b := (rows - 1) * segs + (s + 1) % segs
			var d := s
			var e := (s + 1) % segs
			idx.append_array([a, d, e, a, e, b])
	# La grille d'un tube tourne ses faces vers l'intérieur : on les retourne.
	_emit(kind, v, idx, paint, Vector3.ZERO, true, ORIENT_FLIP)
	if not closed and not round_ends:
		# extrémités plates (arêtes vives : formes à part)
		for e in [0, n - 1]:
			if radii[e] <= 0.0:
				continue
			var cv := PackedVector3Array([path[e]])
			cv.append_array(rings_pts[e])
			var ci := PackedInt32Array()
			for s in segs:
				ci.append_array([0, 1 + s, 1 + (s + 1) % segs])
			var inside := path[1] if e == 0 else path[n - 2]
			_emit(kind, cv, ci, paint, inside, false)


## Profilé le long de Z : sections [z, demi-largeur, demi-hauteur, y du centre,
## exposant] (exposant 2 = ellipse, 4 et plus = rectangle arrondi). Les deux
## bouts sont arrondis sur une profondeur donnée.
func loft(sections: Array, kind: String, paint: Variant, segs := 28, round_front := 0.08, round_back := 0.08) -> void:
	var secs: Array = []
	var first: Array = sections[0]
	var last: Array = sections[sections.size() - 1]
	var steps := 4
	if round_front > 0.0:
		for k in steps:
			var a := PI / 2.0 * (1.0 - float(k) / steps)
			var sc := cos(a)
			secs.append([float(first[0]) - round_front * sin(a), float(first[1]) * sc, float(first[2]) * sc, first[3], first[4]])
	secs.append_array(sections)
	if round_back > 0.0:
		for k in range(1, steps + 1):
			var a := PI / 2.0 * float(k) / steps
			var sc := cos(a)
			secs.append([float(last[0]) + round_back * sin(a), float(last[1]) * sc, float(last[2]) * sc, last[3], last[4]])
	var v := PackedVector3Array()
	var ref := Vector3.ZERO
	for sec in secs:
		var z: float = sec[0]
		var hw: float = sec[1]
		var hh: float = sec[2]
		var yc: float = sec[3]
		var ex: float = 2.0 / float(sec[4])
		for s in segs:
			var th := TAU * s / segs
			v.append(Vector3(hw * _spow(cos(th), ex), yc + hh * _spow(sin(th), ex), z))
		ref += Vector3(0.0, yc, z)
	ref /= secs.size()
	var idx := PackedInt32Array()
	_grid(idx, secs.size(), segs, true)
	_emit(kind, v, idx, paint, ref)


## Calotte de sphère (centre, rayon) autour d'une direction, d'ouverture
## angle (radians) : iris, pupilles, taches posées sur une surface ronde.
func cap(center: Vector3, radius: float, dir: Vector3, angle: float, kind: String, paint: Variant,
		rings := 5, segs := 22, squash := Vector2.ONE) -> void:
	var b := _basis_from_dir(dir)
	var v := PackedVector3Array()
	for r in rings + 1:
		var a := angle * r / rings
		for s in segs:
			var th := TAU * s / segs
			var d := Vector3(sin(a) * cos(th) * squash.x, sin(a) * sin(th) * squash.y, cos(a)).normalized()
			v.append(center + b * (d * radius))
	var idx := PackedInt32Array()
	_grid(idx, rings + 1, segs, true)
	_emit(kind, v, idx, paint, center)


## Forme plate épaisse (polygone du plan XY extrudé sur Z) dans le repère t.
func extrude(poly: PackedVector2Array, depth: float, kind: String, paint: Variant, t := Transform3D.IDENTITY) -> void:
	var tris := Geometry2D.triangulate_polygon(poly)
	if tris.is_empty():
		return
	var n := poly.size()
	var hz := depth / 2.0
	# faces avant et arrière (sommets séparés : arêtes vives)
	for side in [-1.0, 1.0]:
		var v := PackedVector3Array()
		for p in poly:
			v.append(t * Vector3(p.x, p.y, hz * side))
		var idx := PackedInt32Array()
		for i in range(0, tris.size(), 3):
			idx.append_array([tris[i], tris[i + 1], tris[i + 2]])
		_emit(kind, v, idx, paint, t * Vector3(0, 0, -hz * side * 4.0), false)
	var vs := PackedVector3Array()
	var ids := PackedInt32Array()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var base := vs.size()
		vs.append_array([t * Vector3(a.x, a.y, -hz), t * Vector3(b.x, b.y, -hz), t * Vector3(b.x, b.y, hz), t * Vector3(a.x, a.y, hz)])
		ids.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var c := Vector2.ZERO
	for p in poly:
		c += p
	_emit(kind, vs, ids, paint, t * Vector3(c.x / n, c.y / n, 0.0), false)


## Ajoute des triangles déjà calculés (repère courant), sans lissage commun.
func triangles(v: PackedVector3Array, idx: PackedInt32Array, kind: String, paint: Variant, ref: Vector3, smooth := true) -> void:
	_emit(kind, v, idx, paint, ref, smooth)


# ---------------- Chemins ----------------

## Courbe lisse (Catmull-Rom) passant par ces points.
static func smooth_path(points: PackedVector3Array, subdiv := 4) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := points.size()
	for i in n - 1:
		var p0 := points[maxi(i - 1, 0)]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[mini(i + 2, n - 1)]
		for k in subdiv:
			var t := float(k) / subdiv
			out.append(p1.cubic_interpolate(p2, p0, p3, t))
	out.append(points[n - 1])
	return out


## Rayons qui varient régulièrement d'une valeur à l'autre le long d'un chemin.
static func taper(count: int, r0: float, r1: float, curve := 1.0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in count:
		var t := pow(float(i) / maxf(1.0, count - 1.0), curve)
		out.append(lerpf(r0, r1, t))
	return out


# ---------------- Fabrication ----------------

## Le maillage final : une surface par matériau.
func commit(mesh: ArrayMesh = null) -> ArrayMesh:
	if mesh == null:
		mesh = ArrayMesh.new()
	var kinds := _surf.keys()
	kinds.sort()
	for kind in kinds:
		var s: Surf = _surf[kind]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = s.v
		arrays[Mesh.ARRAY_NORMAL] = s.n
		arrays[Mesh.ARRAY_COLOR] = s.c
		arrays[Mesh.ARRAY_TEX_UV] = s.uv
		if s.has_uv2:
			arrays[Mesh.ARRAY_TEX_UV2] = s.uv2
		arrays[Mesh.ARRAY_INDEX] = s.i
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material(kind))
	return mesh


## Nombre de sommets (pour les tests et les mesures).
func vertex_count() -> int:
	var n := 0
	for kind in _surf:
		n += (_surf[kind] as Surf).v.size()
	return n


# ---------------- Interne ----------------

static func _spow(x: float, e: float) -> float:
	return signf(x) * pow(absf(x), e)


static func _basis_from_dir(dir: Vector3) -> Basis:
	var z := dir.normalized()
	var x := Vector3.UP.cross(z)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	return Basis(x, z.cross(x), z)


## Triangles d'une grille de rows lignes de cols points (refermée en largeur).
static func _grid(idx: PackedInt32Array, rows: int, cols: int, wrap: bool) -> void:
	var cmax := cols if wrap else cols - 1
	for r in rows - 1:
		for c in cmax:
			var a := r * cols + c
			var b := r * cols + (c + 1) % cols
			var d := (r + 1) * cols + c
			var e := (r + 1) * cols + (c + 1) % cols
			idx.append_array([a, d, e, a, e, b])


## Ajoute une forme : couleurs, soudure des sommets confondus (ombrage lisse),
## repère courant, faces orientées vers l'extérieur, normales lissées.
## ref : point intérieur de la forme (avec ORIENT_REF).
func _emit(kind: String, v: PackedVector3Array, idx: PackedInt32Array, paint: Variant, ref: Vector3,
		weld := true, orient := ORIENT_REF) -> void:
	var n := v.size()
	var cols := PackedColorArray()
	cols.resize(n)
	if paint is Callable:
		var f: Callable = paint
		for i in n:
			cols[i] = f.call(v[i])
	elif paint is PackedColorArray:
		cols = (paint as PackedColorArray).duplicate()
	else:
		cols.fill(paint as Color)
	var uvs := PackedVector2Array()
	uvs.resize(n)
	if uv_fn.is_valid():
		for i in n:
			uvs[i] = uv_fn.call(v[i])
	if weld:
		var map := {}
		var remap := PackedInt32Array()
		remap.resize(n)
		var nv := PackedVector3Array()
		var nc := PackedColorArray()
		var nu := PackedVector2Array()
		for i in n:
			var p := v[i]
			var key := Vector3i(roundi(p.x * 8192.0), roundi(p.y * 8192.0), roundi(p.z * 8192.0))
			var j: int = map.get(key, -1)
			if j < 0:
				j = nv.size()
				map[key] = j
				nv.append(p)
				nc.append(cols[i])
				nu.append(uvs[i])
			remap[i] = j
		var ni := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			var a := remap[idx[t]]
			var b := remap[idx[t + 1]]
			var c := remap[idx[t + 2]]
			if a != b and b != c and a != c:
				ni.append_array([a, b, c])
		v = nv
		idx = ni
		cols = nc
		uvs = nu
		n = v.size()
	for i in n:
		v[i] = _xf * v[i]
	# orientation : volume signé par rapport au point intérieur
	var flip := orient == ORIENT_FLIP
	if orient == ORIENT_REF:
		var rw := _xf * ref
		var vol := 0.0
		for t in range(0, idx.size(), 3):
			vol += (v[idx[t]] - rw).dot((v[idx[t + 1]] - rw).cross(v[idx[t + 2]] - rw))
		flip = vol < 0.0
	if flip:
		for t in range(0, idx.size(), 3):
			var tmp := idx[t + 1]
			idx[t + 1] = idx[t + 2]
			idx[t + 2] = tmp
	var nrm := PackedVector3Array()
	nrm.resize(n)
	for t in range(0, idx.size(), 3):
		var a := idx[t]
		var b := idx[t + 1]
		var c := idx[t + 2]
		var fn := (v[b] - v[a]).cross(v[c] - v[a])
		nrm[a] += fn
		nrm[b] += fn
		nrm[c] += fn
	for i in n:
		var nn := nrm[i]
		nrm[i] = nn.normalized() if nn.length_squared() > 1e-20 else Vector3.UP
	if not _surf.has(kind):
		_surf[kind] = Surf.new()
	var s: Surf = _surf[kind]
	var base := s.v.size()
	s.v.append_array(v)
	s.n.append_array(nrm)
	s.c.append_array(cols)
	s.uv.append_array(uvs)
	var u2 := PackedVector2Array()
	u2.resize(n)
	if uv2 != Vector2.ZERO:
		u2.fill(uv2)
		s.has_uv2 = true
	s.uv2.append_array(u2)
	var out := PackedInt32Array()
	out.resize(idx.size())
	# Godot : faces avant dans le sens horaire (vues de l'extérieur)
	for t in range(0, idx.size(), 3):
		out[t] = base + idx[t]
		out[t + 1] = base + idx[t + 2]
		out[t + 2] = base + idx[t + 1]
	s.i.append_array(out)
