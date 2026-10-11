@tool
class_name Track
extends Node3D
## Un circuit : un tracé (enfant « Path », une courbe Path3D fermée) et tout ce
## qui est construit autour (route, vibreurs, talus, décor), aux couleurs du
## thème choisi.
##
## Dans l'éditeur Godot, ouvrir tracks/*.tscn, sélectionner « Path » et
## déplacer les points de la courbe : le circuit se reconstruit tout seul.
## Le premier point de la courbe est la ligne de départ.

const CURB := 1.4
const ROAD_Y := 0.08

const ROAD_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 road_color;
uniform vec3 line_color;
void fragment() {
	float u = UV.x;
	float d = UV.y;
	vec3 col = road_color;
	float n = fract(sin(dot(floor(vec2(u * 80.0, d * 5.0)), vec2(12.9898, 78.233))) * 43758.5453);
	col *= 0.94 + 0.06 * n;
	if (u < 0.025 || u > 0.975) col = line_color;
	if (abs(u - 0.5) < 0.007 && mod(d, 8.0) < 4.0) col = line_color;
	if (d < 3.0) {
		float c = mod(floor(u * 14.0) + floor(d / 1.0), 2.0);
		col = c < 1.0 ? vec3(0.97) : vec3(0.08);
	}
	// Couleurs du thème en sRGB -> espace linéaire (le rendu « Compatibilité »
	// ne fait pas la conversion automatiquement).
	ALBEDO = pow(col, vec3(2.2));
	ROUGHNESS = 0.85;
}
"""

const CURB_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 color_a;
uniform vec3 color_b;
void fragment() {
	ALBEDO = pow(mod(UV.y, 4.0) < 2.0 ? color_a : color_b, vec3(2.2));
	ROUGHNESS = 0.7;
}
"""

const GRASS_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 color_a;
uniform vec3 color_b;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float s = mod(floor(wp.x / 10.0) + floor(wp.z / 10.0), 2.0);
	ALBEDO = pow(mix(color_a, color_b, s), vec3(2.2));
	ROUGHNESS = 1.0;
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
## Graine du placement des arbres : changer la valeur pour un autre décor.
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

var curve: Curve3D
var length := 1.0
var _generated: Node3D
var _crowd: MultiMeshInstance3D
var _crowd_base: Array[Transform3D] = []
var _rebuild_queued := false
var _t := 0.0


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
	# Courbe fermée : on recopie le premier point à la fin.
	curve = path.curve.duplicate()
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
	_build_road()
	_build_ground()
	_build_start_arch()
	if track_theme.grandstand and grandstand_distance >= 0.0:
		_build_grandstand()
	_build_trees()
	_build_scenery()


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


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _crowd == null:
		return
	_t += delta
	var mm := _crowd.multimesh
	for i in _crowd_base.size():
		var tr := _crowd_base[i]
		tr.origin.y += maxf(0.0, sin(_t * 9.0 + i * 1.7)) * 0.25
		mm.set_instance_transform(i, tr)


# ---------------- Construction ----------------

func _shader_mat(code: String, params: Dictionary) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	for key in params:
		m.set_shader_parameter(key, params[key])
	return m


func _grass_mat() -> ShaderMaterial:
	return _shader_mat(GRASS_SHADER, {"color_a": track_theme.grass_a, "color_b": track_theme.grass_b})


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n0: Vector3, n1: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	# a,b : bords au début du segment ; c,d : mêmes bords à la fin
	_tri(st, [a, b, c], [n0, n0, n1], [ua, ub, uc])
	_tri(st, [b, d, c], [n0, n1, n1], [ub, ud, uc])


## Ajoute un triangle orienté vers sa normale (Godot : sens horaire = face avant).
func _tri(st: SurfaceTool, p: Array, n: Array, uv: Array) -> void:
	var order := [0, 1, 2]
	if (p[1] - p[0]).cross(p[2] - p[0]).dot(n[0]) > 0.0:
		order = [0, 2, 1]
	for i in order:
		st.set_normal(n[i])
		st.set_uv(uv[i])
		st.add_vertex(p[i])


func _edge(f: Transform3D, l: float, h := 0.0) -> Vector3:
	return f.origin + f.basis.x * l + f.basis.y * h


func _build_road() -> void:
	var half := road_half_width
	var road := SurfaceTool.new()
	var curb := SurfaceTool.new()
	var bank := SurfaceTool.new()
	for st in [road, curb, bank]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := int(ceil(length / 1.5))
	for i in count:
		var d0 := i * length / count
		var d1 := (i + 1) * length / count
		var f0 := frame_at(d0)
		var f1 := frame_at(d1)
		var n0 := f0.basis.y
		var n1 := f1.basis.y
		_quad(road, _edge(f0, -half), _edge(f0, half), _edge(f1, -half), _edge(f1, half), n0, n1,
			Vector2(0, d0), Vector2(1, d0), Vector2(0, d1), Vector2(1, d1))
		for s in [-1.0, 1.0]:
			var inner: float = s * half
			var outer: float = s * (half + CURB)
			_quad(curb, _edge(f0, inner, 0.03), _edge(f0, outer, 0.03), _edge(f1, inner, 0.03), _edge(f1, outer, 0.03), n0, n1,
				Vector2(0, d0), Vector2(1, d0), Vector2(0, d1), Vector2(1, d1))
			# talus en herbe jusqu'au sol
			var a: Vector3 = _edge(f0, outer)
			var c: Vector3 = _edge(f1, outer)
			var b: Vector3 = a + f0.basis.x * s * (3.0 + a.y * 2.5)
			var dd: Vector3 = c + f1.basis.x * s * (3.0 + c.y * 2.5)
			b.y = -0.3
			dd.y = -0.3
			_quad(bank, a, b, c, dd, Vector3.UP, Vector3.UP, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	var th := track_theme
	var parts := [
		[road, _shader_mat(ROAD_SHADER, {"road_color": th.road_color, "line_color": th.line_color})],
		[curb, _shader_mat(CURB_SHADER, {"color_a": th.curb_a, "color_b": th.curb_b})],
		[bank, _grass_mat()],
	]
	for pair in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = pair[0].commit()
		mi.material_override = pair[1]
		_generated.add_child(mi)


func _build_ground() -> void:
	var b := bounds()
	var plane := PlaneMesh.new()
	plane.size = Vector2(3000, 3000)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = _grass_mat()
	mi.position = Vector3(b.get_center().x, 0, b.get_center().y)
	_generated.add_child(mi)


func _build_start_arch() -> void:
	var arch := Node3D.new()
	_generated.add_child(arch)
	arch.transform = frame_at(0.0)
	var w := road_half_width + CURB + 1.0
	for s in [-1.0, 1.0]:
		Mk.part(arch, Mk.box(Vector3(1.0, 8.0, 1.0)), Color("#eeeeee"), Vector3(s * w, 4.0, 0))
	Mk.part(arch, Mk.box(Vector3(w * 2.0 + 1.0, 2.0, 0.6)), Color("#e63946"), Vector3(0, 7.2, 0))
	for side in [0.0, 180.0]:
		var label := Label3D.new()
		label.text = "FUNKART"
		label.font_size = 160
		label.outline_size = 32
		label.pixel_size = 0.01
		label.modulate = Color("#ffd60a")
		label.outline_modulate = Color("#1d3557")
		label.position = Vector3(0, 7.2, 0.32 if side == 0.0 else -0.32)
		label.rotation_degrees = Vector3(0, side, 0)
		arch.add_child(label)


func _grandstand_center() -> Vector3:
	var f := frame_at(grandstand_distance)
	return f.origin - f.basis.x * (road_half_width + CURB + 13.0)


func _build_grandstand() -> void:
	var f := frame_at(grandstand_distance)
	var stand := Node3D.new()
	_generated.add_child(stand)
	stand.transform = Transform3D(f.basis, f.origin - f.basis.x * (road_half_width + CURB + 9.0) - Vector3(0, f.origin.y, 0))
	var depth := 40.0
	for k in 5:
		Mk.part(stand, Mk.box(Vector3(2.2, 1.0 * (k + 1), depth)), Color("#c9cdd6").darkened(k * 0.05),
			Vector3(-k * 2.2, 0.5 * (k + 1), 0))
	Mk.part(stand, Mk.box(Vector3(12.0, 0.4, depth + 2.0)), Color("#1d3557"), Vector3(-4.4, 9.0, 0))
	for z in [-depth / 2.0, 0.0, depth / 2.0]:
		Mk.part(stand, Mk.box(Vector3(0.4, 9.0, 0.4)), Color("#eeeeee"), Vector3(-9.6, 4.5, z))
	Mk.part(stand, Mk.box(Vector3(0.3, 1.0, depth)), Color("#e63946"), Vector3(2.0, 0.5, 0))

	# public (petits personnages colorés qui sautillent)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = Mk.capsule(0.3, 1.1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var palette := [Color("#ff595e"), Color("#ffca3a"), Color("#8ac926"), Color("#1982c4"), Color("#6a4c93"), Color("#ff924c")]
	var list: Array[Transform3D] = []
	for k in 5:
		var z := -depth / 2.0 + 1.0
		while z < depth / 2.0 - 0.5:
			if rng.randf() < 0.85:
				list.append(Transform3D(Basis(), Vector3(-k * 2.2, 1.0 * (k + 1) + 0.55, z)))
			z += 0.9
	mm.instance_count = list.size()
	for i in list.size():
		mm.set_instance_transform(i, list[i])
		mm.set_instance_color(i, palette[rng.randi() % palette.size()])
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	_crowd = MultiMeshInstance3D.new()
	_crowd.multimesh = mm
	_crowd.material_override = m
	stand.add_child(_crowd)
	_crowd_base = list


func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = decor_seed
	var area := bounds().grow(70.0)
	var has_stand := track_theme.grandstand and grandstand_distance >= 0.0
	var stand_center := _grandstand_center()
	var min_dist := road_half_width + CURB + 11.0
	var trunks: Array[Transform3D] = []
	var leaves: Array[Transform3D] = []
	var leaf_colors: Array[Color] = []
	var greens := track_theme.tree_leaves
	var tries := 0
	while trunks.size() < track_theme.tree_count and tries < track_theme.tree_count * 25:
		tries += 1
		var p := Vector3(rng.randf_range(area.position.x, area.end.x), 0, rng.randf_range(area.position.y, area.end.y))
		var c := curve.get_closest_point(p)
		if Vector2(c.x - p.x, c.z - p.z).length() < min_dist:
			continue
		if has_stand and Vector2(stand_center.x - p.x, stand_center.z - p.z).length() < 30.0:
			continue
		var s := rng.randf_range(0.8, 1.5)
		trunks.append(Transform3D(Basis().scaled(Vector3(s, s, s)), p + Vector3(0, 1.25 * s, 0)))
		var col: Color = greens[rng.randi() % greens.size()] if not greens.is_empty() else Color.GREEN
		leaves.append(Transform3D(Basis().scaled(Vector3.ONE * s * 2.4), p + Vector3(0, 3.4 * s, 0)))
		leaf_colors.append(col)
		leaves.append(Transform3D(Basis().scaled(Vector3.ONE * s * 1.6), p + Vector3(0, 5.0 * s, 0)))
		leaf_colors.append(col.lightened(0.1))
	_multimesh(Mk.cyl(0.3, 0.42, 2.5, 8), trunks, [], track_theme.tree_trunk)
	_multimesh(Mk.sphere(1.0), leaves, leaf_colors, Color.WHITE)


func _multimesh(mesh: Mesh, transforms: Array[Transform3D], colors: Array, color: Color) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.vertex_color_use_as_albedo = mm.use_colors
	m.vertex_color_is_srgb = true
	m.roughness = 0.9
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m
	_generated.add_child(mi)


func _build_scenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = decor_seed + 4
	var b := bounds()
	var center := Vector3(b.get_center().x, 0, b.get_center().y)
	var radius := b.size.length() / 2.0
	# collines au loin
	for i in 16:
		var a := TAU * i / 16.0 + rng.randf_range(-0.1, 0.1)
		var r := rng.randf_range(90.0, 150.0)
		var pos := center + Vector3(cos(a), 0, sin(a)) * (radius + rng.randf_range(200.0, 290.0))
		Mk.part(_generated, Mk.sphere(r), track_theme.hills_color.darkened(rng.randf_range(0.0, 0.25)), pos,
			Vector3.ZERO, Vector3(1, rng.randf_range(0.35, 0.6), 1))
	# nuages
	var cloud_mat := Mk.mat(Color.WHITE, true)
	for i in track_theme.cloud_count:
		var a := rng.randf() * TAU
		var pos := center + Vector3(cos(a), 0, sin(a)) * rng.randf_range(radius * 0.6, radius + 300.0) + Vector3(0, rng.randf_range(55.0, 100.0), 0)
		for j in 4:
			var mi := MeshInstance3D.new()
			mi.mesh = Mk.sphere(rng.randf_range(6.0, 11.0))
			mi.material_override = cloud_mat
			mi.position = pos + Vector3(j * 8.0 - 12.0, rng.randf_range(-2.0, 3.0), rng.randf_range(-4.0, 4.0))
			mi.scale = Vector3(1, 0.7, 1)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_generated.add_child(mi)
	# drapeaux le long de la ligne de départ
	var flag_colors := track_theme.flags
	if flag_colors.is_empty():
		return
	for k in flags_count:
		var f := frame_at(flags_start + k * 12.0)
		for s in [-1.0, 1.0]:
			var pole := Node3D.new()
			_generated.add_child(pole)
			pole.transform = Transform3D(f.basis, f.origin + f.basis.x * s * (road_half_width + CURB + 2.0))
			Mk.part(pole, Mk.cyl(0.08, 0.08, 5.0, 8), Color("#dddddd"), Vector3(0, 2.5, 0))
			Mk.part(pole, Mk.box(Vector3(0.05, 1.0, 1.6)), flag_colors[(k + int(s > 0)) % flag_colors.size()], Vector3(0, 4.4, 0.8))
