class_name Kart
extends Node3D
## Un kart avec son pilote. L'avant du kart est vers -Z.
## Les maillages viennent de KartModel (kart) et AnimalModel (pilote) ; ici,
## on les assemble et on les anime : roues, direction, volant, pilote qui se
## penche, yeux qui clignent, oreilles, queue et écharpe dans le vent, turbo.

const WHEEL_R_REAR := KartModel.WHEEL_R_REAR

const SHADOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	float d = length(q);
	ALBEDO = vec3(0.0);
	ALPHA = (1.0 - smoothstep(0.35, 1.0, d)) * 0.42;
}
"""

static var _shadow_mat: ShaderMaterial
static var _flame_mat: StandardMaterial3D
static var _smoke_mat: StandardMaterial3D

var info: CharacterData
var model := Node3D.new() # inclinaison dans les virages
var body := Node3D.new() # petits rebonds
var driver := Node3D.new() # le pilote se penche dans les virages
var head := Node3D.new()
var eyes: MeshInstance3D
var ears: Array[Node3D] = []
var tail: Node3D
var scarf: Node3D
var steering_wheel: Node3D
var wheels: Array[Node3D] = []
var steer_pivots: Array[Node3D] = []
var flames: Array[CPUParticles3D] = []
var smoke: CPUParticles3D
var lateral := 0.0
var target_lateral := 0.0
var extra_distance := 0.0 # distance parcourue après l'arrivée (tour d'honneur)
## Petites animations (clignements, regard, oreilles…) ; false : pose fixe.
var animated := true
var _t := randf() * 10.0
var _blink := randf_range(1.0, 4.0)
var _steer := 0.0
var _speed := 0.0
var _head_y := 0.0


func _init(character: CharacterData = null, display_name := "", show_label := false) -> void:
	info = character if character else GameContent.get_content().characters[0]
	add_child(model)
	model.add_child(body)
	model.scale = Vector3.ONE * 1.3
	var m := KartModel.get_meshes(info)
	_mesh(body, m["chassis"])
	# roues (les roues avant tournent dans les virages)
	for side: float in [-1.0, 1.0]:
		var rear := _wheel(m["wheel_rear"], side)
		rear.position = Vector3(side * KartModel.REAR_WHEEL.x, KartModel.REAR_WHEEL.y, KartModel.REAR_WHEEL.z)
		body.add_child(rear)
		var pivot := Node3D.new()
		pivot.position = Vector3(side * KartModel.FRONT_WHEEL.x, KartModel.FRONT_WHEEL.y, KartModel.FRONT_WHEEL.z)
		body.add_child(pivot)
		pivot.add_child(_wheel(m["wheel_front"], side))
		steer_pivots.append(pivot)
	steering_wheel = Node3D.new()
	steering_wheel.position = KartModel.STEERING
	steering_wheel.rotation_degrees.x = KartModel.STEERING_TILT
	body.add_child(steering_wheel)
	_mesh(steering_wheel, m["steering"])
	# pilote
	body.add_child(driver)
	_mesh(driver, m["driver"])
	head.position = m["head_pos"]
	_head_y = head.position.y
	driver.add_child(head)
	_mesh(head, m["head"])
	eyes = _mesh(head, m["eyes"])
	eyes.position = m["eyes_pos"]
	for key in ["ear_l", "ear_r"]:
		if m.has(key):
			var ear := Node3D.new()
			ear.position = m[key + "_pos"]
			head.add_child(ear)
			_mesh(ear, m[key])
			ears.append(ear)
	if m.has("tail"):
		tail = Node3D.new()
		tail.position = m["tail_pos"]
		driver.add_child(tail)
		_mesh(tail, m["tail"])
	scarf = Node3D.new()
	scarf.position = m["scarf_pos"]
	driver.add_child(scarf)
	_mesh(scarf, m["scarf"])
	_number_plate()
	_shadow_blob()
	_build_effects()
	if show_label:
		var label := Label3D.new()
		label.text = display_name
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font = Ui.title_font()
		label.font_size = 64
		label.outline_size = 18
		label.pixel_size = 0.008
		label.position = Vector3(0, 3.9, 0)
		label.modulate = Color.WHITE
		label.outline_modulate = Color(0.08, 0.1, 0.2, 0.85)
		add_child(label)


func _mesh(parent: Node3D, mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	parent.add_child(mi)
	return mi


func _wheel(mesh: Mesh, side: float) -> Node3D:
	var spin := Node3D.new()
	var mi := _mesh(spin, mesh)
	if side < 0.0:
		mi.rotation.y = PI # face extérieure (enjoliveur) vers l'extérieur du kart
	wheels.append(spin)
	return spin


## Numéro de course sur le nez du kart (lisible de face).
func _number_plate() -> void:
	var content := GameContent.get_content()
	var number := content.characters.find(info) + 1
	if number <= 0:
		return
	var a := deg_to_rad(KartModel.PLATE_SLOPE)
	var n := Vector3(0, cos(a), -sin(a))
	var up := Vector3(0, sin(a), cos(a))
	var label := Label3D.new()
	label.text = str(number)
	label.font = Ui.title_font()
	label.font_size = 72
	label.pixel_size = 0.0028
	label.outline_size = 0
	label.modulate = Color("#1d1d1f")
	label.shaded = true
	label.double_sided = false
	label.transform = Transform3D(Basis(Vector3(-1, 0, 0), up, n), KartModel.PLATE + n * 0.016)
	body.add_child(label)


## Ombre douce sous le kart (elle reste quand les ombres sont désactivées).
func _shadow_blob() -> void:
	if _shadow_mat == null:
		var sh := Shader.new()
		sh.code = SHADOW_SHADER
		_shadow_mat = ShaderMaterial.new()
		_shadow_mat.shader = sh
	var q := QuadMesh.new()
	q.size = Vector2(2.3, 3.6)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _shadow_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation_degrees.x = -90.0
	mi.position = Vector3(0, 0.03, 0.0)
	model.add_child(mi)


func _build_effects() -> void:
	if _flame_mat == null:
		_flame_mat = StandardMaterial3D.new()
		_flame_mat.vertex_color_use_as_albedo = true
		_flame_mat.vertex_color_is_srgb = true
		_flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flame_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_flame_mat.albedo_color = Color(2.2, 2.2, 2.2)
		_flame_mat.disable_receive_shadows = true
		_smoke_mat = StandardMaterial3D.new()
		_smoke_mat.vertex_color_use_as_albedo = true
		_smoke_mat.vertex_color_is_srgb = true
		_smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for e in KartModel.EXHAUSTS:
		var f := CPUParticles3D.new()
		f.amount = 34
		f.lifetime = 0.22
		f.emitting = false
		f.local_coords = false
		f.mesh = Mk.sphere(0.12)
		f.material_override = _flame_mat
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.direction = Vector3(0, 0.15, 1)
		f.spread = 10.0
		f.initial_velocity_min = 5.0
		f.initial_velocity_max = 8.0
		f.gravity = Vector3.ZERO
		f.scale_amount_min = 0.9
		f.scale_amount_max = 1.7
		f.scale_amount_curve = _fade_curve()
		f.color_ramp = Mk.gradient([Color("#ffffff"), Color("#fff1a8"), Color("#ffb703"), Color("#ff5400"), Color(0.6, 0.1, 0.0, 0.0)])
		f.position = e + Vector3(0, 0, 0.04)
		body.add_child(f)
		flames.append(f)

	smoke = CPUParticles3D.new()
	smoke.amount = 10
	smoke.lifetime = 0.7
	smoke.emitting = false
	smoke.local_coords = false
	smoke.mesh = Mk.sphere(0.16)
	smoke.material_override = _smoke_mat
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smoke.direction = Vector3(0, 1, 1)
	smoke.spread = 25.0
	smoke.initial_velocity_min = 1.0
	smoke.initial_velocity_max = 2.0
	smoke.gravity = Vector3(0, 1, 0)
	smoke.scale_amount_min = 0.8
	smoke.scale_amount_max = 1.7
	smoke.color_ramp = Mk.gradient([Color(0.95, 0.95, 0.95, 0.5), Color(0.75, 0.75, 0.78, 0.0)])
	smoke.position = Vector3(0, 0.55, 1.45)
	body.add_child(smoke)


static func _fade_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0, 0.6))
	c.add_point(Vector2(0.3, 1.0))
	c.add_point(Vector2(1, 0.2))
	return c


## Place le kart sur la piste et anime roues, virages, turbo.
func update_visual(track: Track, distance: float, speed: float, mult: float, dt: float,
		boosting: bool, slowed: bool) -> void:
	var prev := lateral
	lateral = move_toward(lateral, target_lateral, 3.5 * dt)
	var lat_v := (lateral - prev) / maxf(dt, 0.0001)
	var yaw := clampf(-lat_v * 0.07, -0.35, 0.35)
	var f := track.frame_at(distance)
	global_transform = Transform3D(f.basis * Basis(Vector3.UP, yaw), f.origin + f.basis.x * lateral)

	var steer := clampf(track.curvature_at(distance + 3.0) * 14.0 + yaw * 1.5, -0.5, 0.5)
	var k := minf(1.0, dt * 8.0)
	_steer = lerpf(_steer, steer, k)
	_speed = speed
	for p in steer_pivots:
		p.rotation.y = _steer
	steering_wheel.rotation.z = _steer * 1.6
	model.rotation.z = lerp(model.rotation.z, -steer * 0.12 * clampf(mult, 0.0, 2.0), minf(1.0, dt * 5.0))
	body.position.y = sin(_t * 23.0) * 0.012 * clampf(mult, 0.2, 2.0) if speed > 0.1 else 0.0
	for w in wheels:
		w.rotation.x -= speed * dt / WHEEL_R_REAR
	for fl in flames:
		fl.emitting = boosting
	smoke.emitting = slowed


## Petites animations, même à l'arrêt (menu) : clignements, regard, oreilles,
## queue, écharpe.
func _process(delta: float) -> void:
	if not animated:
		return
	_t += delta
	var fast := clampf(_speed / 12.0, 0.0, 1.5)
	# clignement des yeux
	_blink -= delta
	if _blink < 0.0:
		eyes.scale.y = 0.12
		if _blink < -0.11:
			eyes.scale.y = 1.0
			_blink = randf_range(2.0, 5.0)
	# le pilote se penche dans les virages ; à l'arrêt, il regarde autour de lui
	driver.rotation.z = lerpf(driver.rotation.z, _steer * 0.22, minf(1.0, delta * 6.0))
	var look := sin(_t * 0.6) * 0.35 * (1.0 - minf(fast * 2.0, 1.0)) + _steer * 0.7
	head.rotation.y = lerpf(head.rotation.y, look, minf(1.0, delta * 4.0))
	head.rotation.z = lerpf(head.rotation.z, _steer * 0.12 + sin(_t * 1.3) * 0.03, minf(1.0, delta * 4.0))
	head.position.y = _head_y + sin(_t * 2.0) * 0.008 + absf(sin(_t * 11.0)) * 0.012 * fast
	# oreilles souples : elles flottent vers l'arrière avec la vitesse
	for i in ears.size():
		var side := -1.0 if i == 0 else 1.0
		var wob := sin(_t * (9.0 + i) + i * 1.7) * (0.05 + 0.08 * fast)
		ears[i].rotation.x = 0.1 + fast * 0.45 + wob
		ears[i].rotation.z = side * (0.05 + fast * 0.15) + wob * 0.5
	if tail:
		var wag := 14.0 if AnimalModel.species_of(info) == "dog" else 3.0
		tail.rotation.y = sin(_t * wag) * (0.55 if wag > 10.0 else 0.22)
		tail.rotation.x = -fast * 0.25 + sin(_t * 2.1) * 0.05
	scarf.rotation.x = -0.15 - fast * 0.35 + sin(_t * (6.0 + 6.0 * fast)) * (0.06 + 0.1 * fast)
	scarf.rotation.y = sin(_t * 4.3) * (0.12 + 0.1 * fast)
