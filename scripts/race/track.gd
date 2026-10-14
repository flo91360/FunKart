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
	col *= 0.97 + 0.03 * n;
	if (u < 0.012 || u > 0.988) col = line_color;
	col *= 1.0 - 0.06 * exp(-pow((abs(u - 0.5) - 0.23) * 35.0, 2.0));
	if (d < 3.0) {
		float c = mod(floor(u * 14.0) + floor(d / 1.0), 2.0);
		col = c < 1.0 ? vec3(0.97) : vec3(0.08);
	}
	// Couleurs du thème en sRGB -> espace linéaire (le rendu « Compatibilité »
	// ne fait pas la conversion automatiquement).
	ALBEDO = pow(col, vec3(2.2));
	EMISSION = pow(col, vec3(2.2)) * 0.10;
	ROUGHNESS = 0.85;
}
"""

const CURB_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 color_a;
uniform vec3 color_b;
void fragment() {
	ALBEDO = pow(mix(color_a, color_b, 0.5 + sin(UV.y * 0.7) * 0.2), vec3(2.2));
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
	float s = 0.5 + 0.24 * sin(wp.x * 0.043 + sin(wp.z * 0.031) * 2.0) + 0.2 * cos(wp.z * 0.067);
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
@export_tool_button("Reconstruire le circuit") var rebuild_button := rebuild
## Quantité de décor (arbres, champignons) : 1 = normal, 0.5 = ordinateurs lents.
var detail := 1.0

var curve: Curve3D
var length := 1.0
var _generated: Node3D
var _rebuild_queued := false


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
	_build_road()
	_build_ground()
	Woodland.populate(_generated, self)


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
	# Les tangentes de la courbe descendent légèrement sous le niveau zéro.
	# Le sol rejoint le bas des talus et ne doit pas recouvrir ces portions.
	mi.position = Vector3(b.get_center().x, -0.3, b.get_center().y)
	_generated.add_child(mi)
