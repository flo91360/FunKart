@tool
class_name Scenery
extends RefCounted
## Décor d'un circuit, selon le style de son thème (TrackTheme.decor) :
## arbres, palmiers, sapins enneigés ou cactus, rochers, buissons, fleurs,
## touffes d'herbe qui ondulent au vent, nuages, montgolfières, et quelques
## surprises (moulin, phare et voiliers, bonshommes de neige et chalets…).
##
## Les modèles sont fabriqués avec MeshBuilder puis répétés (MultiMesh) :
## des milliers d'objets pour quelques appels de dessin.

## Feuillage : lumière douce, un peu de lumière à travers les feuilles, et
## le vent qui balance le haut de l'arbre.
const FOLIAGE_SHADER := """
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx;
uniform float sway = 1.0;
varying vec3 obj;

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
	obj = VERTEX;
	vec3 w = MODEL_MATRIX[3].xyz;
	float h = max(VERTEX.y, 0.0);
	float ph = TIME * 1.3 + w.x * 0.11 + w.z * 0.07;
	float amp = sway * 0.005 * h * h;
	VERTEX.x += sin(ph) * amp;
	VERTEX.z += cos(ph * 0.83) * amp * 0.7;
}

void fragment() {
	vec3 base = to_linear(COLOR.rgb);
	float n = vnoise(obj * 2.4) * 0.6 + vnoise(obj * 6.0) * 0.4;
	ALBEDO = base * (0.78 + 0.44 * n);
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
	RIM = 0.3;
	RIM_TINT = 0.75;
}
"""

## Brins d'herbe : des deux côtés, éclairés comme le sol, pointes au vent.
const GRASS_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap;
vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}
void vertex() {
	vec3 w = MODEL_MATRIX[3].xyz;
	float h = max(VERTEX.y, 0.0);
	float ph = TIME * 2.2 + w.x * 0.3 + w.z * 0.2;
	VERTEX.x += sin(ph) * 0.1 * h * h;
	VERTEX.z += cos(ph * 0.7) * 0.06 * h * h;
}
void fragment() {
	ALBEDO = to_linear(COLOR.rgb);
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
}
"""

## Nuages : blancs en haut, un peu bleutés en dessous, plus clairs côté soleil.
const CLOUD_SHADER := """
shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform vec3 top : source_color = vec3(1.0);
uniform vec3 bottom : source_color = vec3(0.78, 0.84, 0.94);
uniform float drift = 0.6;
void vertex() {
	VERTEX.x += sin(TIME * 0.01 + MODEL_MATRIX[3].z * 0.01) * 60.0 * drift;
}
void fragment() {
	vec3 n = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float t = smoothstep(-0.35, 0.75, n.y);
	ALBEDO = mix(bottom, top, t);
}
"""

## Drapeaux : le tissu ondule, de plus en plus loin du mât (UV.x).
const FLAG_SHADER := """
shader_type spatial;
render_mode cull_disabled;
vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}
void vertex() {
	float u = UV.x;
	float w = sin(TIME * 7.0 - u * 6.0 + VERTEX.x * 0.3) * 0.22 * u;
	VERTEX += NORMAL * w;
}
void fragment() {
	ALBEDO = to_linear(COLOR.rgb);
	ROUGHNESS = 0.8;
	SPECULAR = 0.2;
}
"""

const SHADOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
void fragment() {
	float d = length((UV - 0.5) * 2.0);
	ALBEDO = vec3(0.0, 0.03, 0.0);
	ALPHA = (1.0 - smoothstep(0.3, 1.0, d)) * 0.38;
}
"""

static var _mats_ready := false


static func _setup_materials() -> void:
	if _mats_ready:
		return
	_mats_ready = true
	var leaf := ShaderMaterial.new()
	leaf.shader = MeshBuilder._shader(FOLIAGE_SHADER)
	MeshBuilder.register_material("leaf", leaf)
	var stiff := ShaderMaterial.new()
	stiff.shader = MeshBuilder._shader(FOLIAGE_SHADER)
	stiff.set_shader_parameter("sway", 0.25)
	MeshBuilder.register_material("leaf_stiff", stiff)
	MeshBuilder.register_material("bark", MeshBuilder._soft(0.95, 0.15, 0.25, 9.0, 0.1))
	MeshBuilder.register_material("rock", MeshBuilder._soft(0.92, 0.2, 0.22, 3.5, 0.08))
	MeshBuilder.register_material("snow", MeshBuilder._soft(0.7, 0.35, 0.05, 6.0, 0.25))
	var grass := ShaderMaterial.new()
	grass.shader = MeshBuilder._shader(GRASS_SHADER)
	MeshBuilder.register_material("grass", grass)
	var cloud := ShaderMaterial.new()
	cloud.shader = MeshBuilder._shader(CLOUD_SHADER)
	MeshBuilder.register_material("cloud", cloud)


static func flag_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = MeshBuilder._shader(FLAG_SHADER)
	return m


static func shadow_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = MeshBuilder._shader(SHADOW_SHADER)
	return m


## Construit le décor du circuit.
static func build(track: Track, parent: Node3D) -> void:
	_setup_materials()
	var d := Scenery.new()
	d.track = track
	d.parent = parent
	d.rng.seed = track.decor_seed * 101 + 7
	d.th = track.track_theme
	d._build()


var track: Track
var parent: Node3D
var th: TrackTheme
var rng := RandomNumberGenerator.new()
var _shadows: Array[Transform3D] = []


func _build() -> void:
	var detail := track.detail
	match th.decor:
		"plage":
			_beach(detail)
		"montagne":
			_mountain(detail)
		"canyon":
			_canyon(detail)
		_:
			_meadow(detail)
	_clouds()
	if not _shadows.is_empty():
		var q := QuadMesh.new()
		q.size = Vector2(2, 2)
		q.orientation = PlaneMesh.FACE_Y
		var mi := _instances(q, _shadows)
		mi.material_override = shadow_material()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ---------------- Placement ----------------

func _instances(mesh: Mesh, transforms: Array[Transform3D], shadows := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _single(mesh: Mesh, t: Transform3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = t
	parent.add_child(mi)
	return mi


## Points au hasard autour du circuit, loin de la route (et de la tribune, et
## hors de l'eau), sur un sol pas trop pentu ; y : hauteur du sol.
func _spots(count: int, min_road: float, max_road: float, area_grow: float, max_slope := 0.35) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var area := track.bounds().grow(area_grow)
	var has_stand := th.grandstand and track.grandstand_distance >= 0.0
	var stand := track._grandstand_center()
	var tries := 0
	while out.size() < count and tries < count * 30:
		tries += 1
		var x := rng.randf_range(area.position.x, area.end.x)
		var z := rng.randf_range(area.position.y, area.end.y)
		var dr := track.distance_to_road(Vector3(x, 0, z))
		if dr < min_road or dr > max_road:
			continue
		if has_stand and Vector2(stand.x - x, stand.z - z).length() < 34.0:
			continue
		var y := track.height_at(x, z)
		if y < Track.WATER_Y + 0.6 and th.decor == "plage":
			continue
		var slope := absf(track.height_at(x + 2.0, z) - y) + absf(track.height_at(x, z + 2.0) - y)
		if slope > max_slope * 4.0:
			continue
		out.append(Vector3(x, y, z))
	return out


## Points regroupés en bosquets (plus naturel qu'au hasard partout).
func _groves(count: int, min_road: float, max_road: float, area_grow: float, spread := 14.0) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var centers := _spots(maxi(1, count / 6), min_road, max_road, area_grow, 0.5)
	var has_stand := th.grandstand and track.grandstand_distance >= 0.0
	var stand := track._grandstand_center()
	var tries := 0
	while out.size() < count and tries < count * 20 and not centers.is_empty():
		tries += 1
		var c := centers[rng.randi() % centers.size()]
		var p := c + Vector3(rng.randfn(0.0, spread), 0, rng.randfn(0.0, spread))
		if track.distance_to_road(p) < min_road:
			continue
		if has_stand and Vector2(stand.x - p.x, stand.z - p.z).length() < 34.0:
			continue
		p.y = track.height_at(p.x, p.z)
		if th.decor == "plage" and p.y < Track.WATER_Y + 0.6:
			continue
		out.append(p)
	return out


## Points le long de la route, juste après les vibreurs (herbes, fleurs).
func _roadside(count: int, near: float, far: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var edge := track.road_half_width + Track.CURB
	var tries := 0
	while out.size() < count and tries < count * 4:
		tries += 1
		var f := track.frame_at(rng.randf() * track.length)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var off := edge + lerpf(near, far, pow(rng.randf(), 1.6))
		var p := f.origin + f.basis.x * side * off
		if track.distance_to_road(p) < edge + near * 0.8:
			continue
		var h := track.height_at(p.x, p.z)
		# sur le talus d'une portion surélevée : rester sur le talus
		var bank_h := f.origin.y - (off - edge) / (3.0 + f.origin.y * 2.5) * (f.origin.y + 0.3)
		p.y = maxf(h, bank_h)
		if th.decor == "plage" and p.y < Track.WATER_Y + 0.6:
			continue
		out.append(p)
	return out


## Répartit des points entre plusieurs modèles, avec rotation et taille au hasard.
func _scatter(models: Array, spots: Array[Vector3], smin: float, smax: float, shadow_r := 0.0, shadows := true) -> void:
	var lists: Array = []
	for m in models:
		lists.append([])
	for p in spots:
		var s := rng.randf_range(smin, smax)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.12), s))
		var k := rng.randi() % models.size()
		(lists[k] as Array).append(Transform3D(b, p))
		if shadow_r > 0.0:
			_shadows.append(Transform3D(Basis().scaled(Vector3(shadow_r * s, 1, shadow_r * s)), p + Vector3(0, 0.06, 0)))
	for i in models.size():
		var list: Array[Transform3D] = []
		list.assign(lists[i])
		if not list.is_empty():
			_instances(models[i], list, shadows)


# ---------------- Styles de décor ----------------

func _meadow(detail: float) -> void:
	var greens: Array[Color] = []
	for c in th.tree_leaves:
		greens.append(c)
	var trunk := th.tree_trunk
	var trees: Array = []
	for i in 4:
		trees.append(_round_tree(greens[i % greens.size()], trunk))
	var pines: Array = [_pine(Color("#2f7d4a"), false, trunk), _pine(Color("#3a8f55"), false, trunk)]
	var n := int(th.tree_count * detail)
	var edge := track.road_half_width + Track.CURB
	_scatter(trees, _groves(int(n * 0.6), edge + 9.0, 120.0, 110.0), 0.8, 1.35, 2.6)
	_scatter(trees, _spots(int(n * 0.25), edge + 9.0, 120.0, 110.0), 0.8, 1.35, 2.6)
	_scatter(pines, _groves(int(n * 0.35), edge + 9.0, 150.0, 140.0, 10.0), 0.8, 1.3, 2.0)
	# forêts sur les collines
	_scatter(trees + pines, _groves(int(n * 1.6), 120.0, 380.0, 400.0, 24.0), 1.0, 1.7, 0.0, false)
	_scatter([_bush(greens[0]), _bush(greens[greens.size() - 1])], _spots(int(50 * detail), track.road_half_width + Track.CURB + 5.0, 90.0, 80.0), 0.8, 1.4, 1.4)
	_scatter([_rock(Color("#9a968c")), _rock(Color("#86827a"))], _spots(int(24 * detail), track.road_half_width + Track.CURB + 6.0, 140.0, 120.0), 0.6, 1.6, 1.5)
	_scatter([_flower(Color("#fffdf5"), Color("#ffd23f")), _flower(Color("#ff5d8f"), Color("#ffe66d")), _flower(Color("#ffd23f"), Color("#ff9f1c")), _flower(Color("#b8a1ff"), Color("#fff3b0"))],
		_roadside(int(900 * detail), 0.4, 26.0), 0.8, 1.3, 0.0, false)
	_scatter([_grass_tuft(Color("#3f8f3a"), Color("#a6d86a")), _grass_tuft(Color("#367d33"), Color("#8fcf58"))], _roadside(int(2600 * detail), 0.2, 16.0), 0.8, 1.5, 0.0, false)
	_windmill()
	_balloons(3)


func _beach(detail: float) -> void:
	var palms: Array = [_palm(0.0), _palm(1.0), _palm(2.0)]
	var n := int(th.tree_count * detail)
	_scatter(palms, _spots(n, track.road_half_width + Track.CURB + 7.0, 110.0, 100.0), 0.85, 1.25, 2.2)
	var greens: Array[Color] = []
	for c in th.tree_leaves:
		greens.append(c)
	_scatter([_round_tree(greens[0], th.tree_trunk), _bush(greens[1 % greens.size()])], _spots(int(n * 0.6), 120.0, 340.0, 360.0, 0.5), 1.0, 1.5, 0.0, false)
	_scatter([_rock(Color("#b9a98f")), _rock(Color("#a0907a"))], _spots(int(20 * detail), track.road_half_width + Track.CURB + 6.0, 120.0, 100.0), 0.6, 1.8, 1.4)
	_scatter([_grass_tuft(Color("#9a9a52"), Color("#d8d08a"))], _roadside(int(900 * detail), 0.4, 14.0), 0.7, 1.3, 0.0, false)
	# parasols et serviettes entre la route et la mer
	var sea := track.sea_start()
	var b := track.bounds()
	var umbrellas: Array = [_umbrella(Color("#ff595e"), Color.WHITE), _umbrella(Color("#1982c4"), Color("#ffca3a")), _umbrella(Color("#8ac926"), Color.WHITE)]
	var spots: Array[Vector3] = []
	for i in 14:
		var x := rng.randf_range(b.position.x - 40.0, b.end.x + 40.0)
		var z := rng.randf_range(sea - 42.0, sea - 14.0)
		var p := Vector3(x, track.height_at(x, z), z)
		if track.distance_to_road(p) > track.road_half_width + Track.CURB + 6.0 and p.y > Track.WATER_Y + 0.8:
			spots.append(p)
	_scatter(umbrellas, spots, 0.9, 1.1, 1.6)
	# voiliers au large et phare
	for i in 4:
		var x := b.get_center().x + rng.randf_range(-320.0, 320.0)
		var z := sea + rng.randf_range(90.0, 320.0)
		var boat := _single(_sailboat(), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(x, Track.WATER_Y, z)))
		track._floaters.append([boat, boat.position, rng.randf() * TAU, 0.18])
	var lh := Vector3(b.end.x + 160.0, 0.0, sea + 20.0)
	lh.y = track.height_at(lh.x, lh.z)
	_single(_lighthouse(), Transform3D(Basis(), lh))
	_balloons(2)


func _mountain(detail: float) -> void:
	var trunk := th.tree_trunk
	var pines: Array = [_pine(Color("#1f5e3a"), true, trunk), _pine(Color("#2a6e45"), true, trunk), _pine(Color("#18502f"), false, trunk)]
	var n := int(th.tree_count * detail)
	var edge := track.road_half_width + Track.CURB
	_scatter(pines, _groves(int(n * 0.7), edge + 8.0, 130.0, 120.0, 12.0), 0.8, 1.5, 2.0)
	_scatter(pines, _spots(int(n * 0.3), edge + 8.0, 130.0, 120.0), 0.8, 1.5, 2.0)
	_scatter(pines, _groves(int(n * 1.4), 120.0, 400.0, 420.0, 26.0), 1.1, 1.9, 0.0, false)
	_scatter([_rock(Color("#8d939e"), true), _rock(Color("#7a808c"), true)], _spots(int(40 * detail), track.road_half_width + Track.CURB + 5.0, 150.0, 130.0), 0.7, 2.2, 1.4)
	_scatter([_snowman()], _spots(6, track.road_half_width + Track.CURB + 5.0, 30.0, 40.0), 1.0, 1.2, 1.0)
	_scatter([_chalet()], _spots(3, 40.0, 110.0, 110.0, 0.2), 1.0, 1.1, 0.0)
	_balloons(2)


func _canyon(detail: float) -> void:
	var cacti: Array = [_cactus(0), _cactus(1), _cactus(2), _barrel_cactus()]
	var n := int(th.tree_count * detail)
	_scatter(cacti, _spots(n, track.road_half_width + Track.CURB + 5.0, 120.0, 110.0), 0.8, 1.3, 1.1)
	_scatter([_rock(Color("#b0603a")), _rock(Color("#9a4f2f")), _rock(Color("#c47a4a"))], _spots(int(60 * detail), track.road_half_width + Track.CURB + 5.0, 170.0, 150.0), 0.7, 2.6, 1.5)
	_scatter([_dry_bush()], _spots(int(70 * detail), track.road_half_width + Track.CURB + 3.0, 100.0, 90.0), 0.7, 1.3, 0.9)
	_scatter([_grass_tuft(Color("#a08a4a"), Color("#e0c27a"))], _roadside(int(500 * detail), 0.4, 12.0), 0.7, 1.2, 0.0, false)
	_balloons(3)


# ---------------- Modèles ----------------

func _leaf_paint(base: Color, low: float, high: float) -> Callable:
	var dark := base.darkened(0.32)
	var light := base.lightened(0.18)
	return func(p: Vector3) -> Color:
		return dark.lerp(light, clampf((p.y - low) / (high - low), 0.0, 1.0))


func _round_tree(green: Color, trunk: Color) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var bend := Vector3(rng.randf_range(-0.35, 0.35), 0, rng.randf_range(-0.35, 0.35))
	var top := Vector3(0, 3.0, 0) + bend
	var tpath := MeshBuilder.smooth_path(PackedVector3Array([Vector3.ZERO, Vector3(0, 1.5, 0) + bend * 0.3, top]), 4)
	var bark := func(p: Vector3) -> Color:
		return trunk.darkened(0.15 * (sin(p.y * 9.0 + p.x * 5.0) * 0.5 + 0.5))
	mb.tube(tpath, MeshBuilder.taper(tpath.size(), 0.36, 0.2), "bark", bark, 10)
	for i in 3:
		var a := TAU * i / 3.0 + rng.randf()
		var start := Vector3(0, 2.2, 0) + bend * 0.7
		var tip := start + Vector3(cos(a) * 1.2, 1.3, sin(a) * 1.2)
		mb.tube(PackedVector3Array([start, tip]), PackedFloat32Array([0.15, 0.06]), "bark", trunk, 6)
	var center := Vector3(0, 4.3, 0) + bend
	var paint := _leaf_paint(green, center.y - 1.8, center.y + 2.2)
	for i in 6:
		var a := TAU * i / 6.0 + rng.randf() * 0.6
		var off := Vector3(cos(a) * rng.randf_range(0.8, 1.4), rng.randf_range(-0.5, 0.6), sin(a) * rng.randf_range(0.8, 1.4))
		if i == 0:
			off = Vector3(0, 1.0, 0)
		var r := rng.randf_range(1.25, 1.75)
		var bumps := []
		for k in 5:
			bumps.append([Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 1), rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.08, 0.2), 4.0])
		mb.ellipsoid(center + off, Vector3(r, r * 0.86, r), "leaf", paint, Basis(), bumps, 10, 16)
	return mb.commit()


func _pine(green: Color, snow: bool, trunk: Color) -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.tube(PackedVector3Array([Vector3.ZERO, Vector3(0, 1.6, 0)]), PackedFloat32Array([0.3, 0.2]), "bark", trunk, 8)
	var tiers := 4
	for t in tiers:
		var y0 := 1.0 + t * 1.3
		var r0 := 2.5 - t * 0.5
		var ph := rng.randf() * TAU
		var tip := 2.3 - t * 0.15
		var dark := green.darkened(0.25)
		var light := green.lightened(0.12)
		var paint := func(p: Vector3) -> Color:
			var k := clampf((p.y - y0) / tip, 0.0, 1.0)
			var c := dark.lerp(light, k)
			if snow:
				var rad := Vector2(p.x, p.z).length()
				var s := smoothstep(0.18, 0.4, k) * smoothstep(r0 * 0.98, r0 * 0.6, rad)
				c = c.lerp(Color("#f6f9ff"), s * 0.92)
			return c
		var branches := func(th_: float, y: float) -> float:
			return 0.22 * sin(th_ * 9.0 + ph) * smoothstep(y0 + 0.6, y0 + 0.1, y)
		mb.lathe(PackedVector2Array([Vector2(0.2, y0 - 0.05), Vector2(r0, y0 + 0.1), Vector2(r0 * 0.9, y0 + 0.32), Vector2(r0 * 0.45, y0 + tip * 0.55), Vector2(0.0, y0 + tip)]),
			"leaf_stiff", paint, Transform3D.IDENTITY, 27, branches)
	return mb.commit()


func _palm(variant: float) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var lean := Vector3(rng.randf_range(-1.6, 1.6), 0, rng.randf_range(-1.6, 1.6))
	var h := 6.5 + variant * 0.8
	var top := Vector3(0, h, 0) + lean
	var tpath := MeshBuilder.smooth_path(PackedVector3Array([Vector3.ZERO, Vector3(0, h * 0.5, 0) + lean * 0.25, top]), 6)
	var trunk := Color("#9a6b3f")
	var rings := func(p: Vector3) -> Color:
		return trunk.darkened(0.25) if fmod(p.y + 10.0, 0.42) < 0.12 else trunk
	mb.tube(tpath, MeshBuilder.taper(tpath.size(), 0.34, 0.2), "bark", rings, 10)
	mb.sphere(top + Vector3(0, 0.15, 0), 0.42, "bark", Color("#6b5a2e"), 8, 12)
	var green := Color("#3f9b45")
	for i in 9:
		var a := TAU * i / 9.0 + rng.randf() * 0.3
		var out := Vector3(cos(a), 0, sin(a))
		var len := rng.randf_range(2.6, 3.4)
		var pts := PackedVector3Array()
		for k in 7:
			var t := k / 6.0
			pts.append(top + out * len * t + Vector3(0, sin(t * PI * 0.9) * 0.9 - t * t * 2.1, 0))
		var radii := PackedFloat32Array()
		for k in 7:
			var t := k / 6.0
			radii.append(0.06 + sin(t * PI) * 0.42 * (1.0 - t * 0.3))
		var tip := green.lerp(Color("#b8d65a"), 0.5)
		var frond := func(p: Vector3) -> Color:
			return green.darkened(0.15).lerp(tip, clampf(Vector2(p.x - top.x, p.z - top.z).length() / 3.2, 0.0, 1.0))
		mb.tube(pts, radii, "leaf", frond, 8, 0.12, Vector3.UP)
	for i in 3:
		var a := TAU * i / 3.0
		mb.sphere(top + Vector3(cos(a) * 0.3, -0.25, sin(a) * 0.3), 0.18, "bark", Color("#5a3d1e"), 6, 10)
	return mb.commit()


func _cactus(variant: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var green := Color("#4f8a3a").lerp(Color("#6aa04a"), variant * 0.3)
	var h := 3.0 + variant * 0.6
	var ribs := func(th_: float, _y: float) -> float:
		return 0.035 * cos(th_ * 10.0)
	var paint := func(p: Vector3) -> Color:
		return green.lightened(0.12 * (sin(atan2(p.z, p.x) * 10.0) * 0.5 + 0.5))
	mb.lathe(PackedVector2Array([Vector2(0.36, 0.0), Vector2(0.36, h - 0.4), Vector2(0.3, h - 0.12), Vector2(0.16, h), Vector2(0.0, h + 0.04)]), "leaf_stiff", paint, Transform3D.IDENTITY, 30, ribs)
	var arms := 1 + variant % 2
	for i in arms:
		var s := -1.0 if i == 0 else 1.0
		var y := 1.2 + i * 0.55 + variant * 0.2
		var a := rng.randf() * TAU
		var dir := Vector3(cos(a), 0, sin(a)) * s
		var path := MeshBuilder.smooth_path(PackedVector3Array([Vector3(0, y, 0), Vector3(0, y, 0) + dir * 0.75, Vector3(0, y + 0.3, 0) + dir * 0.85, Vector3(0, y + 1.3, 0) + dir * 0.85]), 4)
		mb.tube(path, MeshBuilder.taper(path.size(), 0.22, 0.2), "leaf_stiff", green, 12)
	for i in 3:
		var a := TAU * i / 3.0
		mb.sphere(Vector3(cos(a) * 0.12, h + 0.02, sin(a) * 0.12), 0.07, "leaf_stiff", Color("#ff70a6"), 6, 8)
	return mb.commit()


func _barrel_cactus() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var ribs := func(th_: float, _y: float) -> float:
		return 0.04 * cos(th_ * 14.0)
	mb.lathe(PackedVector2Array([Vector2(0.4, 0.0), Vector2(0.55, 0.3), Vector2(0.5, 0.75), Vector2(0.25, 0.98), Vector2(0.0, 1.02)]), "leaf_stiff", Color("#5c9a42"), Transform3D.IDENTITY, 28, ribs)
	for i in 5:
		var a := TAU * i / 5.0
		mb.sphere(Vector3(cos(a) * 0.14, 1.0, sin(a) * 0.14), 0.08, "leaf_stiff", Color("#ffd23f"), 6, 8)
	return mb.commit()


func _rock(color: Color, snowy := false) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var bumps := []
	for k in 8:
		bumps.append([Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.2, 1), rng.randf_range(-1, 1)).normalized(), rng.randf_range(-0.12, 0.22), rng.randf_range(3.0, 8.0)])
	bumps.append([Vector3.DOWN, -0.55, 1.5])
	var paint := func(p: Vector3) -> Color:
		var c := color.lightened(0.08 * sin(p.x * 3.0 + p.z * 2.0))
		if snowy:
			c = c.lerp(Color("#f6f9ff"), smoothstep(0.35, 0.75, p.y))
		return c
	mb.ellipsoid(Vector3(0, 0.25, 0), Vector3(1.0, 0.75, 0.85), "rock", paint, Basis(), bumps, 10, 16)
	return mb.commit()


func _bush(green: Color) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var paint := _leaf_paint(green, 0.0, 1.4)
	for i in 4:
		var a := TAU * i / 4.0 + rng.randf()
		var r := rng.randf_range(0.6, 0.9)
		mb.ellipsoid(Vector3(cos(a) * 0.55, r * 0.6, sin(a) * 0.55), Vector3(r, r * 0.8, r), "leaf", paint, Basis(), [], 8, 12)
	return mb.commit()


func _dry_bush() -> ArrayMesh:
	var mb := MeshBuilder.new()
	for i in 9:
		var a := TAU * i / 9.0
		var tip := Vector3(cos(a) * 0.7, rng.randf_range(0.5, 0.9), sin(a) * 0.7)
		mb.tube(MeshBuilder.smooth_path(PackedVector3Array([Vector3.ZERO, tip * 0.5 + Vector3(0, 0.2, 0), tip]), 3), MeshBuilder.taper(7, 0.04, 0.01), "bark", Color("#8a6a3e"), 5)
	mb.ellipsoid(Vector3(0, 0.45, 0), Vector3(0.55, 0.35, 0.55), "leaf_stiff", Color("#9a9a52"), Basis(), [], 8, 12)
	return mb.commit()


func _flower(petal: Color, heart: Color) -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.tube(PackedVector3Array([Vector3.ZERO, Vector3(0, 0.32, 0)]), PackedFloat32Array([0.012, 0.01]), "grass", Color("#3f8f3a"), 4, 1.0, Vector3.ZERO, false, false)
	for i in 5:
		var a := TAU * i / 5.0
		mb.ellipsoid(Vector3(cos(a) * 0.06, 0.33, sin(a) * 0.06), Vector3(0.05, 0.015, 0.05), "leaf_stiff", petal, Basis(Vector3.UP, -a), [], 4, 6)
	mb.sphere(Vector3(0, 0.345, 0), 0.03, "leaf_stiff", heart, 4, 6)
	return mb.commit()


## Touffe d'herbe : des brins fins (triangles), sombres en bas, clairs en haut.
func _grass_tuft(low: Color, high: Color) -> ArrayMesh:
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var n := PackedVector3Array()
	for i in 9:
		var a := TAU * i / 9.0 + rng.randf() * 0.5
		var r := rng.randf_range(0.02, 0.16)
		var base := Vector3(cos(a) * r, 0, sin(a) * r)
		var lean := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.08, 0.25)
		var h := rng.randf_range(0.35, 0.65)
		var side := Vector3(-sin(a), 0, cos(a)) * 0.035
		v.append_array([base - side, base + side, base + lean + Vector3(0, h, 0)])
		c.append_array([low, low, high])
		n.append_array([Vector3.UP, Vector3.UP, Vector3.UP])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, MeshBuilder.material("grass"))
	return mesh


func _umbrella(a: Color, b: Color) -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.tube(PackedVector3Array([Vector3.ZERO, Vector3(0, 2.4, 0)]), PackedFloat32Array([0.04, 0.04]), "metal", Color("#e9edf2"), 6)
	var stripes := func(p: Vector3) -> Color:
		return a if int(floor((atan2(p.z, p.x) + PI) / TAU * 12.0)) % 2 == 0 else b
	mb.lathe(PackedVector2Array([Vector2(1.5, 2.0), Vector2(1.3, 2.25), Vector2(0.7, 2.5), Vector2(0.0, 2.62)]), "felt", stripes, Transform3D.IDENTITY, 24)
	mb.rbox(Vector3(0.9, 0.03, 0.3), Vector3(0.5, 0.02, 0.9), "felt", b.lerp(a, 0.5), Basis(Vector3.UP, 0.3), 0.2, 4, 8)
	return mb.commit()


func _sailboat() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var hull := func(p: Vector3) -> Color:
		return Color("#1d3557") if p.y < 0.2 else Color.WHITE
	mb.loft([[-2.2, 0.15, 0.25, 0.25, 2.5], [-1.4, 0.75, 0.38, 0.3, 3.0], [1.4, 0.8, 0.38, 0.3, 3.5], [2.0, 0.65, 0.32, 0.3, 3.5]], "paint",
		hull, 20, 0.2, 0.05)
	mb.tube(PackedVector3Array([Vector3(0, 0.4, -0.3), Vector3(0, 6.2, -0.3)]), PackedFloat32Array([0.06, 0.05]), "metal", Color("#e9edf2"), 6)
	var sail := PackedVector3Array([Vector3(0, 0.9, -0.1), Vector3(0, 6.0, -0.2), Vector3(0, 0.9, 2.3)])
	mb.triangles(sail, PackedInt32Array([0, 1, 2]), "felt", Color("#fffdf7"), Vector3(1, 2, 1), false)
	mb.triangles(sail, PackedInt32Array([0, 2, 1]), "felt", Color("#fffdf7"), Vector3(-1, 2, 1), false)
	var jib := PackedVector3Array([Vector3(0, 0.9, -0.5), Vector3(0, 5.2, -0.4), Vector3(0, 0.9, -2.1)])
	mb.triangles(jib, PackedInt32Array([0, 1, 2]), "felt", Color("#ff595e"), Vector3(1, 2, -1), false)
	mb.triangles(jib, PackedInt32Array([0, 2, 1]), "felt", Color("#ff595e"), Vector3(-1, 2, -1), false)
	return mb.commit()


func _lighthouse() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var stripes := func(p: Vector3) -> Color:
		return Color("#e63946") if fmod(p.y, 5.0) < 2.5 else Color.WHITE
	mb.lathe(PackedVector2Array([Vector2(3.6, 0.0), Vector2(3.2, 4.0), Vector2(2.2, 22.0), Vector2(2.2, 22.5), Vector2(0.0, 22.6)]), "paint", stripes, Transform3D.IDENTITY, 24)
	mb.lathe(PackedVector2Array([Vector2(1.6, 22.5), Vector2(1.6, 25.0)]), "glow", Color("#fff3b0"), Transform3D.IDENTITY, 16)
	mb.lathe(PackedVector2Array([Vector2(2.4, 25.0), Vector2(1.2, 26.4), Vector2(0.0, 27.0)]), "paint", Color("#e63946"), Transform3D.IDENTITY, 16)
	return mb.commit()


func _snowman() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var snow := Color("#f7faff")
	mb.sphere(Vector3(0, 0.55, 0), 0.62, "snow", snow, 12, 18)
	mb.sphere(Vector3(0, 1.4, 0), 0.45, "snow", snow, 12, 18)
	mb.sphere(Vector3(0, 2.05, 0), 0.32, "snow", snow, 12, 18)
	var nose_t := Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(0, 2.05, -0.3))
	mb.lathe(PackedVector2Array([Vector2(0.06, 0.0), Vector2(0.0, 0.28)]), "felt", Color("#ff7f11"), nose_t, 10)
	for s: float in [-1.0, 1.0]:
		mb.sphere(Vector3(s * 0.11, 2.15, -0.27), 0.04, "matte", Color("#151515"), 4, 6)
		mb.tube(PackedVector3Array([Vector3(s * 0.4, 1.5, 0), Vector3(s * 0.85, 1.9, 0), Vector3(s * 1.0, 2.1, 0.05)]), PackedFloat32Array([0.035, 0.03, 0.02]), "bark", Color("#6b4423"), 5)
	for i in 3:
		mb.sphere(Vector3(0, 1.25 + i * 0.17, -0.43 + absf(i - 1) * 0.02), 0.045, "matte", Color("#151515"), 4, 6)
	var ring := PackedVector3Array()
	var rr := PackedFloat32Array()
	for i in 16:
		var a := TAU * i / 16.0
		ring.append(Vector3(cos(a) * 0.3, 1.78, sin(a) * 0.3))
		rr.append(0.07)
	mb.tube(ring, rr, "felt", Color("#e63946"), 6, 1.0, Vector3.ZERO, true)
	mb.lathe(PackedVector2Array([Vector2(0.0, 2.3), Vector2(0.36, 2.3), Vector2(0.36, 2.35), Vector2(0.22, 2.35), Vector2(0.22, 2.7), Vector2(0.0, 2.7)]), "plastic", Color("#1d1d1f"), Transform3D.IDENTITY, 16)
	return mb.commit()


func _chalet() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var wood := Color("#9b5d34")
	mb.rbox(Vector3(0, 1.8, 0), Vector3(3.5, 1.8, 2.8), "bark", wood, Basis(), 0.08, 6, 12)
	for s: float in [-1.0, 1.0]:
		mb.rbox(Vector3(0, 4.2, s * 1.6), Vector3(4.0, 0.15, 2.0), "snow", Color("#f7faff"), Basis(Vector3.RIGHT, s * deg_to_rad(38.0)), 0.15, 4, 8)
	for x in [-1.8, 1.8]:
		mb.rbox(Vector3(x, 2.0, -2.82), Vector3(0.55, 0.55, 0.05), "glass", Color("#ffe8a3"), Basis(), 0.2, 4, 8)
	mb.rbox(Vector3(0, 1.1, -2.82), Vector3(0.6, 1.1, 0.06), "bark", wood.darkened(0.35), Basis(), 0.2, 4, 8)
	mb.rbox(Vector3(1.8, 5.0, 0.8), Vector3(0.35, 0.8, 0.35), "rock", Color("#8d939e"), Basis(), 0.2, 4, 8)
	return mb.commit()


## Moulin à vent sur une colline, ses ailes tournent.
func _windmill() -> void:
	var b := track.bounds()
	var p := Vector3(b.end.x + 90.0, 0.0, b.position.y + b.size.y * 0.3)
	p.y = track.height_at(p.x, p.z)
	var mb := MeshBuilder.new()
	mb.lathe(PackedVector2Array([Vector2(3.4, 0.0), Vector2(2.6, 11.0), Vector2(0.0, 11.1)]), "plastic", Color("#f4efe6"), Transform3D.IDENTITY, 20)
	mb.lathe(PackedVector2Array([Vector2(3.0, 10.8), Vector2(0.0, 14.5)]), "paint", Color("#c1440e"), Transform3D.IDENTITY, 20)
	mb.rbox(Vector3(0, 1.4, -3.2), Vector3(0.8, 1.4, 0.2), "bark", Color("#6b4423"), Basis(), 0.15, 4, 8)
	var tower := _single(mb.commit(), Transform3D(Basis(Vector3.UP, PI * 0.15), p))
	var sails := MeshBuilder.new()
	for i in 4:
		var a := TAU * i / 4.0
		var dir := Vector3(cos(a), sin(a), 0)
		sails.tube(PackedVector3Array([Vector3.ZERO, dir * 8.5]), PackedFloat32Array([0.12, 0.1]), "bark", Color("#6b4423"), 6)
		var side := Vector3(-sin(a), cos(a), 0)
		sails.rbox(dir * 5.0 + side * 0.75, Vector3(0.7, 3.2, 0.04), "felt", Color("#fffaf0"), Basis(Vector3.BACK, a - PI / 2.0), 0.1, 4, 8)
	sails.sphere(Vector3.ZERO, 0.5, "bark", Color("#6b4423"), 8, 10)
	var rotor := Node3D.new()
	rotor.position = Vector3(0, 9.8, -3.2)
	tower.add_child(rotor)
	var smi := MeshInstance3D.new()
	smi.mesh = sails.commit()
	rotor.add_child(smi)
	track._spinners.append([rotor, 0.6])


func _balloons(count: int) -> void:
	var b := track.bounds()
	var c := b.get_center()
	var palettes := [[Color("#ff595e"), Color("#ffca3a")], [Color("#1982c4"), Color("#8ac926")], [Color("#6a4c93"), Color("#ff924c")], [Color("#ff70a6"), Color("#70d6ff")]]
	for i in count:
		var pal: Array = palettes[(i + track.decor_seed) % palettes.size()]
		var mb := MeshBuilder.new()
		var ca: Color = pal[0]
		var cb: Color = pal[1]
		var stripes := func(p: Vector3) -> Color:
			return ca if int(floor((atan2(p.z, p.x) + PI) / TAU * 10.0)) % 2 == 0 else cb
		mb.lathe(PackedVector2Array([Vector2(0.7, 0.0), Vector2(1.6, 1.2), Vector2(3.6, 3.8), Vector2(4.3, 6.2), Vector2(3.9, 8.4), Vector2(2.4, 10.0), Vector2(0.0, 10.6)]), "paint", stripes, Transform3D.IDENTITY, 24)
		mb.rbox(Vector3(0, -2.3, 0), Vector3(0.75, 0.55, 0.75), "bark", Color("#8a5a2b"), Basis(), 0.25, 6, 10)
		for k in 4:
			var a := TAU * k / 4.0 + PI / 4.0
			mb.tube(PackedVector3Array([Vector3(cos(a) * 0.95, -1.8, sin(a) * 0.95), Vector3(cos(a) * 0.65, 0.05, sin(a) * 0.65)]), PackedFloat32Array([0.025, 0.025]), "matte", Color("#3b2a20"), 4)
		var a := TAU * i / maxf(1.0, count) + rng.randf() * 0.8
		var r := rng.randf_range(170.0, 260.0)
		var pos := Vector3(c.x + cos(a) * r, rng.randf_range(42.0, 75.0), c.y + sin(a) * r)
		var node := _single(mb.commit(), Transform3D(Basis(), pos))
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		track._floaters.append([node, pos, rng.randf() * TAU, 1.6])


func _clouds() -> void:
	var count := int(th.cloud_count * clampf(track.detail, 0.5, 1.0) * 0.7)
	if count <= 0:
		return
	var protos: Array[ArrayMesh] = []
	for v in 4:
		var mb := MeshBuilder.new()
		var puffs := 5 + v
		for i in puffs:
			var x := (i - puffs / 2.0) * rng.randf_range(5.0, 7.5)
			var r := rng.randf_range(6.0, 10.0) * (1.0 - absf(i - puffs / 2.0) / puffs * 0.8)
			mb.ellipsoid(Vector3(x, rng.randf_range(-1.0, 2.5), rng.randf_range(-3.0, 3.0)), Vector3(r, r * 0.75, r * 0.85), "cloud", Color.WHITE,
				Basis(), [[Vector3.DOWN, -0.35, 2.0]], 8, 12)
		protos.append(mb.commit())
	var b := track.bounds()
	var c := b.get_center()
	var lists: Array = [[], [], [], []]
	for i in count:
		var a := rng.randf() * TAU
		var r := rng.randf_range(120.0, 560.0)
		var s := rng.randf_range(0.8, 1.6)
		var t := Transform3D(Basis(Vector3.UP, rng.randf_range(-0.4, 0.4)).scaled(Vector3(s, s * 0.8, s)), Vector3(c.x + cos(a) * r, rng.randf_range(70.0, 120.0), c.y + sin(a) * r))
		(lists[i % 4] as Array).append(t)
	for v in 4:
		var list: Array[Transform3D] = []
		list.assign(lists[v])
		if not list.is_empty():
			_instances(protos[v], list, false)
