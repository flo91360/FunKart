@tool
class_name Track
extends Node3D
## Un circuit : un tracé (enfant « Path », une courbe Path3D fermée) et tout ce
## qui est construit autour : route en enrobé, vibreurs en relief, talus,
## relief (collines, montagnes, mer), arche de départ avec ses feux, tribune et
## public, drapeaux, barrières dans les virages serrés, et le décor du thème
## (arbres, rochers, fleurs, nuages… : Scenery).
##
## Dans l'éditeur Godot, ouvrir tracks/*.tscn, sélectionner « Path » et
## déplacer les points de la courbe : le circuit se reconstruit tout seul.
## Le premier point de la courbe est la ligne de départ.

const CURB := 1.4
const ROAD_Y := 0.08
## Niveau de la mer (thème « plage »).
const WATER_Y := -1.2

const ROAD_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 road_color : source_color;
uniform vec3 line_color : source_color;
uniform float half_width = 7.0;
uniform float track_length = 600.0;
varying vec3 wp;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// 1 entre a et b, avec des bords sans escalier
float band(float x, float a, float b) {
	float w = fwidth(x) * 0.8 + 1e-5;
	return clamp((x - a) / w + 0.5, 0.0, 1.0) - clamp((x - b) / w + 0.5, 0.0, 1.0);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float across = (UV.x - 0.5) * 2.0 * half_width;
	float d = UV.y;
	float fade = clamp(1.0 - length(VERTEX) / 60.0, 0.0, 1.0);
	vec3 col = road_color;
	// grain de l'enrobé et grandes plaques
	float g = noise(wp.xz * 4.0) * 0.5 + noise(wp.xz * 13.0) * 0.5;
	col *= 1.0 + (g - 0.5) * 0.18 * fade;
	float plates = noise(wp.xz * 0.07) * 0.6 + noise(wp.xz * 0.21) * 0.4;
	col *= 0.9 + 0.16 * smoothstep(0.25, 0.75, plates);
	// traces de pneus sur les trajectoires
	col *= 1.0 - 0.13 * exp(-pow((abs(across) - half_width * 0.42) / 1.1, 2.0));
	// bords pleins, milieu en pointillés
	float lines = band(abs(across), half_width - 0.65, half_width - 0.45);
	lines += band(abs(across), -1.0, 0.11) * band(mod(d, 9.0), 0.0, 4.5);
	// cases de la grille de départ
	float dn = d - track_length;
	if (dn > -20.0) {
		for (int i = 0; i < 6; i++) {
			float fi = float(i);
			float ds = -3.0 - floor(fi / 2.0) * 5.0 - mod(fi, 2.0) * 1.5 + 2.6;
			float cx = mod(fi, 2.0) < 0.5 ? -2.6 : 2.6;
			lines += band(dn, ds - 0.18, ds) * band(across, cx - 1.25, cx + 1.25);
			lines += band(dn, ds - 1.4, ds) * (band(across, cx - 1.25, cx - 1.07) + band(across, cx + 1.07, cx + 1.25));
		}
	}
	col = mix(col, line_color, clamp(lines, 0.0, 1.0) * 0.95);
	// damier de la ligne d'arrivée
	if (d < 2.8) {
		float cx = clamp(sin(PI * across / 0.7) / (fwidth(across / 0.7) * PI + 1e-4), -1.0, 1.0);
		float cy = clamp(sin(PI * d / 0.7) / (fwidth(d / 0.7) * PI + 1e-4), -1.0, 1.0);
		col = mix(vec3(0.05), vec3(0.93), cx * cy * 0.5 + 0.5);
	}
	ALBEDO = col;
	ROUGHNESS = 0.82;
	SPECULAR = 0.35;
}
"""

const CURB_SHADER := """
shader_type spatial;
uniform vec3 color_a : source_color;
uniform vec3 color_b : source_color;
void fragment() {
	float s = UV.y / 2.0;
	float w = fwidth(s) * 1.2 + 1e-4;
	float t = clamp((abs(fract(s) - 0.5) - 0.25) / w + 0.5, 0.0, 1.0);
	vec3 col = mix(color_a, color_b, t);
	col *= 0.82 + 0.18 * smoothstep(0.0, 0.25, min(UV.x, 1.0 - UV.x));
	ALBEDO = col;
	ROUGHNESS = 0.55;
	SPECULAR = 0.4;
}
"""

## Sol (relief, talus) : motif d'herbe ou de sable tiré du thème (alpha de la
## couleur du sommet = 1), ou couleur du sommet (rocher, neige, alpha = 0) ;
## petites fleurs, rides du sable, écume au bord de l'eau.
const GROUND_SHADER := """
shader_type spatial;
uniform vec3 color_a : source_color;
uniform vec3 color_b : source_color;
uniform vec3 speck_a : source_color = vec3(1.0);
uniform vec3 speck_b : source_color = vec3(1.0, 0.85, 0.2);
uniform float specks = 0.0;
uniform float ripples = 0.0;
uniform float water_level = -1000.0;
varying vec3 wp;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz;
	float fade = clamp(1.0 - length(VERTEX) / 90.0, 0.0, 1.0);
	float n1 = noise(p * 0.018) * 0.6 + noise(p * 0.05) * 0.4;
	vec3 grass = mix(color_a, color_b, smoothstep(0.3, 0.7, n1));
	grass *= 0.9 + 0.14 * noise(p * 0.35);
	float n3 = noise(p * 3.1) * 0.5 + noise(p * 7.3) * 0.5;
	grass *= 1.0 + (n3 - 0.5) * 0.2 * fade;
	grass *= 1.0 + ripples * sin(p.x * 1.6 + p.y * 0.5 + noise(p * 0.3) * 6.0) * 0.07 * fade;
	if (specks > 0.0) {
		vec2 q = p * 1.4;
		vec2 cell = floor(q);
		vec2 f = fract(q) - 0.5 - (vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5) * 0.6;
		float m = (1.0 - smoothstep(0.07, 0.12, length(f))) * step(1.0 - specks, hash(cell)) * fade;
		grass = mix(grass, mix(speck_a, speck_b, step(0.5, hash(cell + 1.3))), m);
	}
	vec3 col = mix(to_linear(COLOR.rgb), grass, COLOR.a);
	// bord de l'eau : sable mouillé et écume des vagues
	float wl = wp.y - water_level;
	if (wl > -0.8 && wl < 0.35) {
		float wave = sin(TIME * 1.2 + p.x * 0.04 + noise(p * 0.06) * 5.0);
		col *= mix(1.0, 0.72, smoothstep(0.25, -0.25, wl - wave * 0.12));
		float foam = smoothstep(0.12, -0.02, abs(wl - wave * 0.16 + 0.12)) * (0.55 + 0.45 * noise(p * 1.7 + TIME * 0.4));
		col = mix(col, vec3(0.93, 0.96, 0.97), foam);
	}
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
"""

const WATER_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;
uniform vec3 deep : source_color = vec3(0.04, 0.3, 0.55);
uniform vec3 shallow : source_color = vec3(0.2, 0.78, 0.8);
varying vec3 wp;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wp.x * 0.07 + TIME * 1.1) * 0.1 + sin(wp.z * 0.09 + TIME * 0.8) * 0.08;
}

void fragment() {
	vec2 p = wp.xz * 0.3;
	float t = TIME * 0.5;
	float e = 0.15;
	float h0 = noise(p + vec2(t, t * 0.6)) + noise(p * 2.3 - vec2(t * 0.7, t));
	float hx = noise(p + vec2(e, 0.0) + vec2(t, t * 0.6)) + noise((p + vec2(e, 0.0)) * 2.3 - vec2(t * 0.7, t));
	float hz = noise(p + vec2(0.0, e) + vec2(t, t * 0.6)) + noise((p + vec2(0.0, e)) * 2.3 - vec2(t * 0.7, t));
	vec3 bump = vec3(h0 - hx, 0.0, h0 - hz) * 1.6;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(bump, 0.0)).xyz);
	float depth = COLOR.r;
	ALBEDO = mix(shallow, deep, smoothstep(0.0, 1.0, depth));
	ALPHA = mix(0.5, 0.94, smoothstep(0.0, 0.7, depth));
	ROUGHNESS = 0.05;
	SPECULAR = 0.65;
}
"""

@export var title := "Circuit"
@export var track_theme: TrackTheme:
	set(v):
		track_theme = v
		_queue_rebuild()
@export var road_half_width := 7.0:
	set(v):
		road_half_width = v
		_queue_rebuild()
## Graine du décor (relief, arbres) : changer la valeur pour un autre décor.
@export var decor_seed := 7:
	set(v):
		decor_seed = v
		_queue_rebuild()
@export_group("Tribune et drapeaux")
## Distance (en mètres depuis la ligne) du milieu de la tribune ; négatif = pas de tribune.
@export var grandstand_distance := 32.0:
	set(v):
		grandstand_distance = v
		_queue_rebuild()
@export var flags_start := -40.0
@export var flags_count := 8
@export_tool_button("Reconstruire le circuit") var rebuild_button := rebuild
## Quantité de décor (arbres, herbes, relief) : 1 = normal, 0.5 = ordinateurs lents.
var detail := 1.0

var curve: Curve3D
var length := 1.0
var _generated: Node3D
var _crowd: MultiMeshInstance3D
var _crowd_base: Array[Transform3D] = []
var _rebuild_queued := false
var _t := 0.0
## Feux de départ (rouges, puis tous verts).
var _light_mats: Array[StandardMaterial3D] = []
## Objets qui flottent doucement (montgolfières, bateaux) : [nœud, position de départ, phase, amplitude].
var _floaters: Array = []
## Objets qui tournent (ailes du moulin) : [nœud, vitesse].
var _spinners: Array = []
# relief : hauteurs sur une grille
var _hgrid := PackedFloat32Array()
var _hn := 0
var _horigin := Vector2.ZERO
var _hcell := 1.0
var _sea_z := INF


func _ready() -> void:
	var path := get_node_or_null("Path") as Path3D
	if path and Engine.is_editor_hint() and not path.curve_changed.is_connected(_queue_rebuild):
		path.curve_changed.connect(_queue_rebuild)
	rebuild()


## Construit un tracé fermé et lisse passant par ces points (utilisé pour créer
## un circuit par le code, et plus tard par l'éditeur de circuits du jeu).
static func smooth_curve(points: PackedVector3Array, smoothness := 0.22) -> Curve3D:
	var c := Curve3D.new()
	var n := points.size()
	for i in n:
		var tangent := (points[(i + 1) % n] - points[(i - 1 + n) % n]) * smoothness
		c.add_point(points[i], -tangent, tangent)
	return c


## La route ne passe jamais sous le sol (y = 0, où est posée l'herbe) : les
## poignées de la courbe sont limitées pour que tous ses points de contrôle
## restent au-dessus, et une courbe de Bézier reste entre ses points de contrôle.
static func keep_above_ground(c: Curve3D) -> void:
	for i in c.point_count:
		var pos := c.get_point_position(i)
		if pos.y < 0.0:
			pos.y = 0.0
			c.set_point_position(i, pos)
		var p_in := c.get_point_in(i)
		var p_out := c.get_point_out(i)
		p_in.y = clampf(p_in.y, -pos.y, pos.y)
		p_out.y = clampf(p_out.y, -pos.y, pos.y)
		c.set_point_in(i, p_in)
		c.set_point_out(i, p_out)


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	rebuild.call_deferred()


func rebuild() -> void:
	_rebuild_queued = false
	var path := get_node_or_null("Path") as Path3D
	if path == null or path.curve == null or path.curve.point_count < 3:
		return
	curve = path.curve.duplicate()
	keep_above_ground(curve)
	# Courbe fermée : on recopie le premier point à la fin.
	curve.add_point(curve.get_point_position(0), curve.get_point_in(0), curve.get_point_out(0))
	curve.bake_interval = 0.5
	length = curve.get_baked_length()
	if track_theme == null:
		track_theme = TrackTheme.new()

	if _generated:
		_generated.free()
	_generated = Node3D.new()
	_generated.name = "Generated"
	add_child(_generated) # sans « owner » : jamais enregistré dans la scène
	_crowd = null
	_light_mats.clear()
	_floaters.clear()
	_spinners.clear()
	_build_road()
	_build_terrain()
	if track_theme.decor == "plage":
		_build_water()
	_build_start_arch()
	if track_theme.grandstand and grandstand_distance >= 0.0:
		_build_grandstand()
	_build_flags()
	_build_barriers()
	Scenery.build(self, _generated)


## Repère local de la piste à une distance donnée : -Z vers l'avant, X vers la droite.
func frame_at(d: float) -> Transform3D:
	d = fposmod(d, length)
	var p := curve.sample_baked(d, true)
	var p2 := curve.sample_baked(fposmod(d + 1.0, length), true)
	var fwd := (p2 - p).normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var up := right.cross(fwd).normalized()
	return Transform3D(Basis(right, up, -fwd), p + up * ROAD_Y)


## Courbure signée (radians par mètre), positive dans les virages à gauche.
func curvature_at(d: float) -> float:
	var a := -frame_at(d).basis.z
	var b := -frame_at(d + 2.0).basis.z
	return atan2(a.cross(b).y, a.dot(b)) / 2.0


func minimap_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var d := 0.0
	while d < length:
		var p := curve.sample_baked(d)
		pts.append(Vector2(p.x, p.z))
		d += 5.0
	return pts


## Rectangle (plan XZ) qui contient le tracé.
func bounds() -> Rect2:
	var pts := curve.get_baked_points()
	var r := Rect2(Vector2(pts[0].x, pts[0].z), Vector2.ZERO)
	for p in pts:
		r = r.expand(Vector2(p.x, p.z))
	return r


## Distance (vue de dessus) entre ce point et le milieu de la route la plus proche.
func distance_to_road(p: Vector3) -> float:
	var c := curve.get_closest_point(Vector3(p.x, 0.0, p.z))
	return Vector2(c.x - p.x, c.z - p.z).length()


## Hauteur du sol (relief) en un point.
func height_at(x: float, z: float) -> float:
	if _hn < 2:
		return 0.0
	var fx := clampf((x - _horigin.x) / _hcell, 0.0, _hn - 1.001)
	var fz := clampf((z - _horigin.y) / _hcell, 0.0, _hn - 1.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var a := lerpf(_hgrid[j * _hn + i], _hgrid[j * _hn + i + 1], tx)
	var b := lerpf(_hgrid[(j + 1) * _hn + i], _hgrid[(j + 1) * _hn + i + 1], tx)
	return lerpf(a, b, tz)


## La mer (thème plage) commence à peu près à cette distance vers le sud (+Z).
func sea_start() -> float:
	return _sea_z


## Feux de départ : 0 = éteints, 1 à 3 = feux rouges allumés, 4 = tous verts.
func set_start_lights(step: int) -> void:
	for i in _light_mats.size():
		var m := _light_mats[i]
		var on := step >= 4 or i < step
		var col := Color("#3cff6a") if step >= 4 else Color("#ff2d2d")
		m.albedo_color = col if on else Color("#2a1a1a")
		m.emission_enabled = on
		m.emission = col
		m.emission_energy_multiplier = 3.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	if _crowd:
		var mm := _crowd.multimesh
		for i in _crowd_base.size():
			var tr := _crowd_base[i]
			tr.origin.y += maxf(0.0, sin(_t * 9.0 + i * 1.7)) * 0.25
			mm.set_instance_transform(i, tr)
	for f in _floaters:
		var node: Node3D = f[0]
		var base: Vector3 = f[1]
		var ph: float = f[2]
		var amp: float = f[3]
		node.position = base + Vector3(sin(_t * 0.05 + ph) * amp * 6.0, sin(_t * 0.6 + ph) * amp, 0.0)
		node.rotation.y = ph + _t * 0.03
	for s in _spinners:
		var rotor: Node3D = s[0]
		rotor.rotation.z += float(s[1]) * delta


# ---------------- Construction ----------------

func _shader_mat(code: String, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = MeshBuilder._shader(code)
	for key in params:
		m.set_shader_parameter(key, params[key])
	return m


## Matériau du sol (relief et talus) aux couleurs du thème.
func ground_material() -> ShaderMaterial:
	var th := track_theme
	var params := {"color_a": th.grass_a, "color_b": th.grass_b}
	match th.decor:
		"prairie":
			params["specks"] = 0.16
			params["speck_a"] = Color("#fffbf0")
			params["speck_b"] = Color("#ffd23f")
		"plage":
			params["ripples"] = 1.0
			params["water_level"] = WATER_Y
			params["specks"] = 0.03
			params["speck_a"] = Color("#fff4e8")
			params["speck_b"] = Color("#f4a6a6")
		"canyon":
			params["ripples"] = 0.6
			params["specks"] = 0.04
			params["speck_a"] = Color("#8a5a3c")
			params["speck_b"] = Color("#e9c46a")
		"montagne":
			params["specks"] = 0.0
	return _shader_mat(GROUND_SHADER, params)


func _edge(f: Transform3D, l: float, h := 0.0) -> Vector3:
	return f.origin + f.basis.x * l + f.basis.y * h


## Ajoute une grille de points (rows rangées de cols points) à des tableaux de
## maillage, avec ses normales (lissées) et ses coordonnées de texture.
static func _grid_arrays(pts: PackedVector3Array, uvs: PackedVector2Array, cols: PackedColorArray,
		rows: int, ncols: int, closed: bool) -> Array:
	var nrm := PackedVector3Array()
	nrm.resize(pts.size())
	var idx := PackedInt32Array()
	var rmax := rows if closed else rows - 1
	for r in rmax:
		var r2 := (r + 1) % rows
		for c in ncols - 1:
			var a := r * ncols + c
			var b := r * ncols + c + 1
			var d := r2 * ncols + c
			var e := r2 * ncols + c + 1
			for tri in [[a, b, d], [b, e, d]]:
				var i0: int = tri[0]
				var i1: int = tri[1]
				var i2: int = tri[2]
				var n := (pts[i1] - pts[i0]).cross(pts[i2] - pts[i0])
				# Godot : faces avant dans le sens horaire vues du dessus
				if n.y > 0.0:
					idx.append_array([i0, i2, i1])
				else:
					idx.append_array([i0, i1, i2])
					n = -n
				nrm[i0] += n
				nrm[i1] += n
				nrm[i2] += n
	for i in nrm.size():
		var n := nrm[i]
		if n.y < 0.0:
			n = -n
		nrm[i] = n.normalized() if n.length_squared() > 1e-12 else Vector3.UP
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pts
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	if not cols.is_empty():
		arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	return arrays


func _mesh_node(arrays: Array, mat: Material, shadows := true) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_generated.add_child(mi)
	return mi


## Route, vibreurs en relief (un bourrelet arrondi de chaque côté) et talus.
func _build_road() -> void:
	var half := road_half_width
	var count := int(ceil(length / 1.5))
	var road := PackedVector3Array()
	var road_uv := PackedVector2Array()
	var curb := PackedVector3Array()
	var curb_uv := PackedVector2Array()
	var bank := PackedVector3Array()
	var bank_uv := PackedVector2Array()
	var bank_col := PackedColorArray()
	# profil du vibreur : décalage latéral (depuis le bord de la route), hauteur
	var profile := [[0.0, 0.0], [0.12, 0.05], [0.3, 0.075], [CURB - 0.3, 0.075], [CURB - 0.12, 0.05], [CURB, 0.0]]
	for i in count + 1:
		var d := i * length / count
		var f := frame_at(d)
		for k in 5:
			var u := k / 4.0
			road.append(_edge(f, lerpf(-half, half, u)))
			road_uv.append(Vector2(u, d))
		for s: float in [-1.0, 1.0]:
			for k in profile.size():
				var pr: Array = profile[k]
				var off: float = pr[0]
				curb.append(_edge(f, s * (half + off), float(pr[1])))
				curb_uv.append(Vector2(off / CURB, d))
			# talus en herbe jusqu'au sol
			var a := _edge(f, s * (half + CURB))
			var far := a + f.basis.x * s * (3.0 + a.y * 2.5)
			far.y = -0.3
			for k in 4:
				var t := k / 3.0
				var p := a.lerp(far, t)
				p.y = lerpf(a.y, far.y, t * t * (3.0 - 2.0 * t))
				bank.append(p)
				bank_uv.append(Vector2(t, d))
				bank_col.append(Color(1, 1, 1, 1))
	var th := track_theme
	_mesh_node(_grid_arrays(road, road_uv, PackedColorArray(), count + 1, 5, false),
		_shader_mat(ROAD_SHADER, {"road_color": th.road_color, "line_color": th.line_color, "half_width": half, "track_length": length}))
	# vibreurs : deux bandes (gauche, droite) dans le même tableau, rangées de 6 points
	var pc := profile.size()
	var curb_l := PackedVector3Array()
	var curb_r := PackedVector3Array()
	var uv_l := PackedVector2Array()
	var uv_r := PackedVector2Array()
	for i in count + 1:
		for k in pc:
			curb_l.append(curb[i * pc * 2 + k])
			uv_l.append(curb_uv[i * pc * 2 + k])
			curb_r.append(curb[i * pc * 2 + pc + k])
			uv_r.append(curb_uv[i * pc * 2 + pc + k])
	var curb_mat := _shader_mat(CURB_SHADER, {"color_a": th.curb_a, "color_b": th.curb_b})
	_mesh_node(_grid_arrays(curb_l, uv_l, PackedColorArray(), count + 1, pc, false), curb_mat)
	_mesh_node(_grid_arrays(curb_r, uv_r, PackedColorArray(), count + 1, pc, false), curb_mat)
	var bl := PackedVector3Array()
	var br := PackedVector3Array()
	var bul := PackedVector2Array()
	var bur := PackedVector2Array()
	var bcl := PackedColorArray()
	var bcr := PackedColorArray()
	for i in count + 1:
		for k in 4:
			bl.append(bank[i * 8 + k])
			bul.append(bank_uv[i * 8 + k])
			bcl.append(bank_col[i * 8 + k])
			br.append(bank[i * 8 + 4 + k])
			bur.append(bank_uv[i * 8 + 4 + k])
			bcr.append(bank_col[i * 8 + 4 + k])
	var gm := ground_material()
	_mesh_node(_grid_arrays(bl, bul, bcl, count + 1, 4, false), gm, false)
	_mesh_node(_grid_arrays(br, bur, bcr, count + 1, 4, false), gm, false)


## Relief : plat près de la route, collines plus loin, montagnes (ou mesas,
## mer…) à l'horizon, selon le thème.
func _build_terrain() -> void:
	var b := bounds()
	var center := b.get_center()
	var size := maxf(b.size.x, b.size.y) + 1300.0
	_hn = int(lerpf(80.0, 140.0, clampf(detail, 0.0, 1.0)))
	_hcell = size / (_hn - 1)
	_horigin = center - Vector2(size, size) / 2.0
	_sea_z = b.end.y + 55.0 if track_theme.decor == "plage" else INF
	var noise := FastNoiseLite.new()
	noise.seed = decor_seed * 31 + 5
	noise.frequency = 0.006
	noise.fractal_octaves = 4
	var ridge := FastNoiseLite.new()
	ridge.seed = decor_seed * 17 + 3
	ridge.frequency = 0.0045
	ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge.fractal_octaves = 4
	_hgrid.resize(_hn * _hn)
	var pts := PackedVector3Array()
	var uvs := PackedVector2Array()
	for j in _hn:
		for i in _hn:
			var x := _horigin.x + i * _hcell
			var z := _horigin.y + j * _hcell
			var c := curve.get_closest_point(Vector3(x, 0.0, z))
			var dist := Vector2(c.x - x, c.z - z).length()
			var h := _relief(x, z, dist, c.y, noise, ridge)
			_hgrid[j * _hn + i] = h
			pts.append(Vector3(x, h, z))
			uvs.append(Vector2(x, z))
	var cols := PackedColorArray()
	cols.resize(pts.size())
	for j in _hn:
		for i in _hn:
			var hx := _hgrid[j * _hn + mini(i + 1, _hn - 1)] - _hgrid[j * _hn + maxi(i - 1, 0)]
			var hz := _hgrid[mini(j + 1, _hn - 1) * _hn + i] - _hgrid[maxi(j - 1, 0) * _hn + i]
			var n := Vector3(-hx, 2.0 * _hcell, -hz).normalized()
			cols[j * _hn + i] = _ground_color(pts[j * _hn + i], 1.0 - n.y, noise)
	var mi := _mesh_node(_grid_arrays(pts, uvs, cols, _hn, _hn, false), ground_material(), false)
	mi.name = "Relief"


func _relief(x: float, z: float, dist: float, road_y: float, noise: FastNoiseLite, ridge: FastNoiseLite) -> float:
	var clear := road_half_width + CURB + 6.0 + maxf(road_y, 0.0) * 2.6
	var near := smoothstep(clear, clear + 55.0, dist)
	var n1 := noise.get_noise_2d(x, z)
	var r := ridge.get_noise_2d(x, z) * 0.5 + 0.5
	var h := 0.0
	match track_theme.decor:
		"montagne":
			var low := noise.get_noise_2d(x * 0.25, z * 0.25) * 0.5 + 0.5
			h = near * (8.0 + 14.0 * n1) + smoothstep(150.0, 430.0, dist) * (60.0 + 330.0 * pow(r, 1.3) * (0.4 + 0.8 * low))
		"canyon":
			var m := near * (2.0 + 3.0 * n1) + smoothstep(90.0, 280.0, dist) * (30.0 + 75.0 * (r * 0.7 + (n1 * 0.5 + 0.5) * 0.3))
			# mesas : paliers aux bords raides
			var step := 16.0
			var k := m / step
			h = (floorf(k) + smoothstep(0.72, 1.0, k - floorf(k))) * step
		"plage":
			var sea := smoothstep(_sea_z - 35.0, _sea_z + 45.0, z + 18.0 * noise.get_noise_1d(x * 0.7))
			h = near * (1.5 + 3.0 * n1) + smoothstep(260.0, 520.0, dist) * (25.0 + 110.0 * r) * (1.0 - sea)
			h = lerpf(h, -7.0, sea)
		_:
			var low := noise.get_noise_2d(x * 0.25, z * 0.25) * 0.5 + 0.5
			h = near * (7.0 + 11.0 * n1) + smoothstep(270.0, 560.0, dist) * (25.0 + 230.0 * pow(r, 1.4) * (0.35 + 0.9 * low))
	return maxf(h, -9.0)


## Couleur d'un point du relief : alpha 1 = motif d'herbe ou de sable du thème,
## sinon rocher, neige… (pente de 0, plat, à 1, vertical).
func _ground_color(p: Vector3, slope: float, noise: FastNoiseLite) -> Color:
	var c := _ground_color_near(p, slope, noise)
	# au loin : couleurs adoucies (sans motif, qui scintillerait), plus bleutées
	var dist := distance_to_road(p)
	var far := smoothstep(220.0, 480.0, dist)
	if far > 0.0:
		var flat := track_theme.grass_a.lerp(track_theme.grass_b, 0.5)
		var base := Color(c.r, c.g, c.b).lerp(flat, c.a)
		base = base.lerp(track_theme.sky_horizon.lerp(base, 0.6), far * 0.35)
		c = Color(base.r, base.g, base.b, c.a * (1.0 - far))
	return c


func _ground_color_near(p: Vector3, slope: float, noise: FastNoiseLite) -> Color:
	var rock := smoothstep(0.38, 0.62, slope)
	match track_theme.decor:
		"montagne":
			var stone := Color("#6f7480").lerp(Color("#8d939e"), noise.get_noise_2d(p.x * 3.0, p.z * 3.0) * 0.5 + 0.5)
			return Color(stone.r, stone.g, stone.b, 1.0 - rock)
		"canyon":
			var band := sin(p.y * 0.55 + noise.get_noise_2d(p.x, p.z) * 2.0) * 0.5 + 0.5
			var strata := Color("#a4472a").lerp(Color("#d98a54"), band).lerp(Color("#7a2e1d"), smoothstep(0.75, 1.0, band) * 0.6)
			return Color(strata.r, strata.g, strata.b, 1.0 - smoothstep(0.22, 0.4, slope))
		"plage":
			var green := Color("#6c9a45").lerp(Color("#4f7d36"), noise.get_noise_2d(p.x * 2.0, p.z * 2.0) * 0.5 + 0.5)
			var hill := smoothstep(4.0, 12.0, p.y)
			var c := green.lerp(Color("#8a7f73"), rock)
			return Color(c.r, c.g, c.b, (1.0 - hill) * (1.0 - rock))
		_:
			var stone := Color("#8a8a80").lerp(Color("#a59f8f"), noise.get_noise_2d(p.x * 3.0, p.z * 3.0) * 0.5 + 0.5)
			var snow := smoothstep(120.0 + 30.0 * noise.get_noise_2d(p.x * 2.0, p.z * 2.0), 170.0, p.y)
			var c := stone.lerp(Color("#f4f7fb"), snow)
			return Color(c.r, c.g, c.b, (1.0 - rock) * (1.0 - snow))


## La mer (thème plage) : grande étendue, plus foncée au large.
func _build_water() -> void:
	var b := bounds()
	var n := 70
	var x0 := b.get_center().x - 900.0
	var x1 := b.get_center().x + 900.0
	var z0 := _sea_z - 60.0
	var z1 := _sea_z + 900.0
	var pts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	for j in n:
		for i in n:
			var x := lerpf(x0, x1, i / (n - 1.0))
			var z := lerpf(z0, z1, pow(j / (n - 1.0), 1.6))
			pts.append(Vector3(x, WATER_Y, z))
			uvs.append(Vector2(x, z))
			var depth := clampf((WATER_Y - height_at(x, z)) / 5.0, 0.0, 1.0)
			cols.append(Color(depth, 0, 0, 1))
	var mat := _shader_mat(WATER_SHADER, {})
	var mi := _mesh_node(_grid_arrays(pts, uvs, cols, n, n, false), mat, false)
	mi.name = "Mer"


## Arche gonflable de départ, bannière « FUNKART » et feux du départ.
func _build_start_arch() -> void:
	var arch := Node3D.new()
	_generated.add_child(arch)
	arch.transform = frame_at(0.0)
	var w := road_half_width + CURB + 1.4
	var mb := MeshBuilder.new()
	var th := track_theme
	var col_a: Color = th.curb_a
	var col_b: Color = th.curb_b
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in 97:
		var a := PI * i / 96.0
		path.append(Vector3(cos(a) * w, sin(a) * 8.2, 0.0))
		radii.append(1.05)
	var stripes := func(p: Vector3) -> Color:
		var a := atan2(p.y / 8.2, p.x / w)
		return col_a if int(floor(a / PI * 12.0)) % 2 == 0 else col_b
	mb.tube(path, radii, "plastic", stripes, 18, 1.0, Vector3.ZERO, false, true)
	# bannière
	mb.rbox(Vector3(0, 5.9, 0), Vector3(w * 0.6, 0.95, 0.22), "plastic", Color("#1d3557"), Basis(), 0.25, 8, 24)
	for s: float in [-1.0, 1.0]:
		mb.tube(PackedVector3Array([Vector3(s * w * 0.45, 6.8, 0), Vector3(s * w * 0.45, 7.6, 0)]), PackedFloat32Array([0.05, 0.05]), "metal", Color("#cfd4dc"), 6)
	# rampe des feux
	mb.rbox(Vector3(0, 4.45, 0), Vector3(2.3, 0.4, 0.3), "plastic", Color("#16181d"), Basis(), 0.3, 8, 20)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.commit()
	arch.add_child(mi)
	for side in [0.0, 180.0]:
		var label := Label3D.new()
		label.text = "FUNKART"
		label.font = Ui.title_font()
		label.font_size = 150
		label.outline_size = 26
		label.pixel_size = 0.0105
		label.modulate = Color("#ffd60a")
		label.outline_modulate = Color("#e63946")
		label.position = Vector3(0, 5.9, 0.24 if side == 0.0 else -0.24)
		label.rotation_degrees = Vector3(0, side, 0)
		arch.add_child(label)
	# feux : quatre ronds de chaque côté de la rampe
	for i in 4:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("#2a1a1a")
		m.roughness = 0.2
		var s := SphereMesh.new()
		s.radius = 0.26
		s.height = 0.52
		s.radial_segments = 16
		s.rings = 8
		for side: float in [-1.0, 1.0]:
			var lamp := MeshInstance3D.new()
			lamp.mesh = s
			lamp.material_override = m
			lamp.position = Vector3(-1.65 + i * 1.1, 4.45, side * 0.22)
			lamp.scale = Vector3(1, 1, 0.5)
			lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			arch.add_child(lamp)
		_light_mats.append(m)
	set_start_lights(0)


func _grandstand_center() -> Vector3:
	var f := frame_at(grandstand_distance)
	return f.origin - f.basis.x * (road_half_width + CURB + 13.0)


## Tribune : gradins, sièges de couleur, toit, et public d'animaux qui sautille.
func _build_grandstand() -> void:
	var f := frame_at(grandstand_distance)
	var stand := Node3D.new()
	_generated.add_child(stand)
	stand.transform = Transform3D(f.basis, f.origin - f.basis.x * (road_half_width + CURB + 9.0) - Vector3(0, f.origin.y, 0))
	var depth := 40.0
	var mb := MeshBuilder.new()
	var seat_cols: Array[Color] = [Color("#e63946"), Color("#ffd60a"), Color("#2d7ff9"), Color("#17b169"), Color("#ff6b35")]
	for k in 5:
		mb.rbox(Vector3(-k * 2.2, 0.5 * (k + 1), 0), Vector3(1.1, 0.5 * (k + 1), depth / 2.0), "plastic",
			Color("#d9dce3").darkened(k * 0.04), Basis(), 0.12, 6, 12)
		mb.rbox(Vector3(-k * 2.2 + 0.55, 1.0 * (k + 1) + 0.12, 0), Vector3(0.35, 0.12, depth / 2.0 - 0.3), "plastic",
			seat_cols[k % seat_cols.size()], Basis(), 0.3, 6, 12)
	# toit et poteaux
	mb.rbox(Vector3(-4.4, 9.2, 0), Vector3(6.6, 0.25, depth / 2.0 + 1.2), "paint", Color("#1d3557"), Basis(Vector3.BACK, deg_to_rad(-6.0)), 0.2, 6, 12)
	mb.rbox(Vector3(-4.4, 9.55, 0), Vector3(6.5, 0.12, depth / 2.0 + 1.1), "paint", Color("#e63946"), Basis(Vector3.BACK, deg_to_rad(-6.0)), 0.3, 6, 12)
	for z in [-depth / 2.0, 0.0, depth / 2.0]:
		mb.tube(PackedVector3Array([Vector3(-9.6, 0, z), Vector3(-9.6, 9.0, z)]), PackedFloat32Array([0.22, 0.22]), "metal", Color("#cfd4dc"), 10)
		mb.tube(PackedVector3Array([Vector3(1.2, 0, z), Vector3(1.2, 8.4, z)]), PackedFloat32Array([0.16, 0.16]), "metal", Color("#cfd4dc"), 10)
	# muret et bannière
	mb.rbox(Vector3(2.0, 0.55, 0), Vector3(0.18, 0.55, depth / 2.0), "paint", Color("#e63946"), Basis(), 0.3, 6, 12)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.commit()
	stand.add_child(mi)

	# public : petits animaux colorés qui sautillent
	var fan := MeshBuilder.new()
	fan.ellipsoid(Vector3(0, 0.45, 0), Vector3(0.3, 0.42, 0.26), "felt", Color.WHITE, Basis(), [], 8, 12)
	fan.sphere(Vector3(0, 1.05, 0), 0.28, "fur", Color.WHITE, 8, 12)
	for s: float in [-1.0, 1.0]:
		fan.sphere(Vector3(s * 0.2, 1.3, 0), 0.1, "fur", Color.WHITE, 5, 8)
		fan.tube(PackedVector3Array([Vector3(s * 0.25, 0.65, 0), Vector3(s * 0.45, 1.25, 0)]), PackedFloat32Array([0.07, 0.06]), "felt", Color.WHITE, 6)
	for s: float in [-1.0, 1.0]:
		fan.sphere(Vector3(s * 0.1, 1.08, 0.25), 0.045, "matte", Color("#1b1b1b"), 4, 6)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = fan.commit()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var palette := [Color("#ff595e"), Color("#ffca3a"), Color("#8ac926"), Color("#1982c4"), Color("#6a4c93"), Color("#ff924c"), Color("#f4f1de"), Color("#c08552")]
	var list: Array[Transform3D] = []
	for k in 5:
		var z := -depth / 2.0 + 1.0
		while z < depth / 2.0 - 0.5:
			if rng.randf() < 0.82:
				var b := Basis(Vector3.UP, PI / 2.0 + rng.randf_range(-0.4, 0.4))
				list.append(Transform3D(b, Vector3(-k * 2.2, 1.0 * (k + 1) + 0.1, z)))
			z += 0.95
	mm.instance_count = list.size()
	for i in list.size():
		mm.set_instance_transform(i, list[i])
		mm.set_instance_color(i, palette[rng.randi() % palette.size()])
	_crowd = MultiMeshInstance3D.new()
	_crowd.multimesh = mm
	_crowd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stand.add_child(_crowd)
	_crowd_base = list


## Drapeaux le long de la ligne droite du départ (ils flottent au vent).
func _build_flags() -> void:
	var flag_colors := track_theme.flags
	if flag_colors.is_empty():
		return
	var poles := MeshBuilder.new()
	var cloth := MeshBuilder.new()
	for k in flags_count:
		var f := frame_at(flags_start + k * 12.0)
		for s: float in [-1.0, 1.0]:
			var base := f.origin + f.basis.x * s * (road_half_width + CURB + 2.2)
			base.y = maxf(height_at(base.x, base.z), f.origin.y - 0.3)
			var up := Vector3.UP
			poles.tube(PackedVector3Array([base, base + up * 6.0]), PackedFloat32Array([0.07, 0.06]), "metal", Color("#e6e8ec"), 8)
			poles.sphere(base + up * 6.05, 0.1, "chrome", Color("#e9edf2"), 6, 8)
			var col: Color = flag_colors[(k + int(s > 0.0)) % flag_colors.size()]
			var back := f.basis.z
			var top := base + up * 5.9
			cloth.uv_fn = func(p: Vector3) -> Vector2:
				return Vector2((p - top).dot(back) / 1.9, 0.0)
			var pts := PackedVector3Array()
			var idx := PackedInt32Array()
			for j in 4:
				for i in 7:
					pts.append(top + back * (i / 6.0) * 1.9 - up * (j / 3.0) * 1.2)
			for j in 3:
				for i in 6:
					var a := j * 7 + i
					idx.append_array([a, a + 1, a + 7, a + 1, a + 8, a + 7])
			cloth.triangles(pts, idx, "flag", col, top + f.basis.x * 5.0, true)
	cloth.uv_fn = Callable()
	MeshBuilder.register_material("flag", Scenery.flag_material())
	for mb in [poles, cloth]:
		var mi := MeshInstance3D.new()
		mi.mesh = mb.commit()
		_generated.add_child(mi)


## Barrières rouges et blanches (et panneaux à flèches) à l'extérieur des
## virages serrés.
func _build_barriers() -> void:
	var blocks: Array[Transform3D] = []
	var block_cols: Array[Color] = []
	var signs_l: Array[Transform3D] = []
	var signs_r: Array[Transform3D] = []
	var d := 20.0
	var n := 0
	while d < length - 20.0:
		var k := curvature_at(d)
		if absf(k) > 0.018:
			var f := frame_at(d)
			var out := -signf(k) # côté extérieur du virage
			var pos := f.origin + f.basis.x * out * (road_half_width + CURB + 3.4)
			if distance_to_road(pos) > road_half_width + CURB + 2.0:
				pos.y = maxf(height_at(pos.x, pos.z), 0.0)
				var basis := Basis(Vector3.UP, atan2(-f.basis.z.x, -f.basis.z.z))
				blocks.append(Transform3D(basis, pos + Vector3(0, 0.45, 0)))
				block_cols.append(track_theme.curb_a if n % 2 == 0 else track_theme.curb_b)
				if n % 9 == 4:
					var sp := f.origin + f.basis.x * out * (road_half_width + CURB + 5.2)
					sp.y = maxf(height_at(sp.x, sp.z), 0.0)
					var t := Transform3D(basis, sp)
					if k > 0.0:
						signs_l.append(t)
					else:
						signs_r.append(t)
				n += 1
		d += 1.25
	if blocks.is_empty():
		return
	var block := MeshBuilder.new()
	block.rbox(Vector3.ZERO, Vector3(0.55, 0.45, 0.62), "plastic", Color.WHITE, Basis(), 0.35, 8, 14)
	_multimesh(block.commit(), blocks, block_cols)
	for pair in [[signs_l, 1.0], [signs_r, -1.0]]:
		var list: Array[Transform3D] = pair[0]
		if list.is_empty():
			continue
		_multimesh(_chevron_sign(pair[1]), list, [])


## Panneau à flèches (direction : 1 = virage à gauche) face aux karts qui arrivent.
func _chevron_sign(direction: float) -> ArrayMesh:
	var mb := MeshBuilder.new()
	for s: float in [-1.0, 1.0]:
		mb.tube(PackedVector3Array([Vector3(s * 0.9, 0, 0), Vector3(s * 0.9, 2.3, 0)]), PackedFloat32Array([0.06, 0.06]), "metal", Color("#cfd4dc"), 8)
	var red := track_theme.curb_a
	var arrows := func(p: Vector3) -> Color:
		var x := p.x * direction
		var v := fposmod(x * 1.6 + absf(p.y - 2.0) * 1.3, 1.0)
		return red if v < 0.5 else Color.WHITE
	mb.rbox(Vector3(0, 2.0, 0.0), Vector3(1.2, 0.42, 0.05), "plastic", arrows, Basis(), 0.15, 12, 40)
	return mb.commit()


func _multimesh(mesh: Mesh, transforms: Array[Transform3D], colors: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	_generated.add_child(mi)
	return mi
