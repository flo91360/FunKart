class_name Kart
extends Node3D
## Un kart avec son pilote. L'avant du kart est vers -Z.

const WHEEL_R_REAR := 0.46
const WHEEL_R_FRONT := 0.46

var info: CharacterData
var model := Node3D.new() # inclinaison dans les virages
var body := Node3D.new() # petits rebonds
var wheels: Array[Node3D] = []
var steer_pivots: Array[Node3D] = []
var flames: Array[CPUParticles3D] = []
var smoke: CPUParticles3D
var lateral := 0.0
var target_lateral := 0.0
var extra_distance := 0.0 # distance parcourue après l'arrivée (tour d'honneur)
var driver_head: Node3D
var driver_root: Node3D
var eyes: Array[Node3D] = []
var _t := randf() * 10.0


func _init(character: CharacterData = null, display_name := "", show_label := false) -> void:
	info = character if character else GameContent.get_content().characters[0]
	add_child(model)
	model.add_child(body)
	model.scale = Vector3.ONE * 1.0
	_build_kart()
	_build_driver()
	_build_effects()
	if show_label:
		var label := Label3D.new()
		label.text = display_name
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 48
		label.outline_size = 6
		label.pixel_size = 0.008
		label.position = Vector3(0, 3.8, 0)
		label.font = Ui.font()
		label.modulate = Color.WHITE
		label.outline_modulate = Color(0, 0, 0, 0.8)
		add_child(label)


const PAINTS := {
	"chat": Color("#c88c4e"), "chien": Color("#7193a0"), "grenouille": Color("#7e9f78"),
	"licorne": Color("#a98ca8"), "panda": Color("#596c72"), "lion": Color("#c9ac65"),
	"singe": Color("#a87151"), "pingouin": Color("#719aa0"), "tortue": Color("#6f947d"),
	"lapin": Color("#bb857c"), "renard": Color("#c18660"), "ours": Color("#81798f"),
	"souris": Color("#ad8997"),
}


func _build_kart() -> void:
	var car: Node3D = load("res://assets/models/racer.glb").instantiate()
	body.add_child(car)
	var paint: Color = PAINTS.get(info.id, info.kart_color)
	for node in car.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		for surface in mesh_node.mesh.get_surface_count():
			var material := mesh_node.get_active_material(surface) as StandardMaterial3D
			if material and material.resource_name.begins_with("Paint"):
				var colored := material.duplicate() as StandardMaterial3D
				colored.albedo_color = paint
				mesh_node.set_surface_override_material(surface, colored)
	for wheel_name in ["WheelRearL", "WheelRearR", "WheelFrontL", "WheelFrontR"]:
		var wheel := car.find_child(wheel_name, true, false) as Node3D
		if wheel_name.begins_with("WheelFront"):
			var pivot := Node3D.new()
			wheel.get_parent().add_child(pivot)
			pivot.transform = wheel.transform
			wheel.owner = null
			wheel.reparent(pivot, false)
			wheel.transform = Transform3D.IDENTITY
			steer_pivots.append(pivot)
		wheels.append(wheel)


func _build_driver() -> void:
	var path := "res://assets/models/%s.glb" % info.id
	if not ResourceLoader.exists(path):
		path = "res://assets/models/chat.glb"
	driver_root = load(path).instantiate()
	body.add_child(driver_root)
	driver_head = driver_root.find_child("Head", true, false) as Node3D
	for eye_name in ["EyeL", "EyeR"]:
		var eye := driver_root.find_child(eye_name, true, false) as Node3D
		if eye:
			eyes.append(eye)


func _build_effects() -> void:
	var fm := StandardMaterial3D.new()
	fm.vertex_color_use_as_albedo = true
	fm.vertex_color_is_srgb = true
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for x in [-0.5, 0.5]:
		var f := CPUParticles3D.new()
		f.amount = 30
		f.lifetime = 0.25
		f.emitting = false
		f.local_coords = false
		f.mesh = Mk.sphere(0.13)
		f.material_override = fm
		f.direction = Vector3(0, 0.2, 1)
		f.spread = 12.0
		f.initial_velocity_min = 4.0
		f.initial_velocity_max = 7.0
		f.gravity = Vector3.ZERO
		f.scale_amount_min = 1.0
		f.scale_amount_max = 1.8
		f.color_ramp = Mk.gradient([Color("#fff3b0"), Color("#ffb703"), Color(1.0, 0.3, 0.0, 0.0)])
		f.position = Vector3(x, 0.62, 1.65)
		body.add_child(f)
		flames.append(f)

	smoke = CPUParticles3D.new()
	smoke.amount = 8
	smoke.lifetime = 0.6
	smoke.emitting = false
	smoke.local_coords = false
	smoke.mesh = Mk.sphere(0.14)
	smoke.material_override = fm
	smoke.direction = Vector3(0, 1, 1)
	smoke.spread = 25.0
	smoke.initial_velocity_min = 1.0
	smoke.initial_velocity_max = 2.0
	smoke.gravity = Vector3(0, 1, 0)
	smoke.scale_amount_min = 0.8
	smoke.scale_amount_max = 1.6
	smoke.color_ramp = Mk.gradient([Color(0.9, 0.9, 0.9, 0.45), Color(0.7, 0.7, 0.7, 0.0)])
	smoke.position = Vector3(0, 0.3, 1.2)
	body.add_child(smoke)


## Place le kart sur la piste et anime roues, virages, turbo.
func update_visual(track: Track, distance: float, speed: float, mult: float, dt: float,
		boosting: bool, slowed: bool) -> void:
	_t += dt
	var prev := lateral
	lateral = move_toward(lateral, target_lateral, 3.5 * dt)
	var lat_v := (lateral - prev) / maxf(dt, 0.0001)
	var yaw := clampf(-lat_v * 0.07, -0.35, 0.35)
	var f := track.frame_at(distance)
	global_transform = Transform3D(f.basis * Basis(Vector3.UP, yaw), f.origin + f.basis.x * lateral)

	var steer := clampf(track.curvature_at(distance + 3.0) * 14.0 + yaw * 1.5, -0.5, 0.5)
	for p in steer_pivots:
		p.rotation.y = lerp_angle(p.rotation.y, steer, minf(1.0, dt * 8.0))
	model.rotation.z = lerp(model.rotation.z, -steer * 0.12 * clampf(mult, 0.0, 2.0), minf(1.0, dt * 5.0))
	if driver_head:
		driver_head.rotation.z = -steer * 0.12 + sin(_t * 2.0) * 0.025
		driver_head.rotation.y = lerp_angle(driver_head.rotation.y, -steer * 0.3, minf(1.0, dt * 5.0))
	var blink := fposmod(_t, 4.8)
	for eye in eyes:
		eye.scale.y = maxf(0.12, absf(blink - 0.09) / 0.09) if blink < 0.18 else 1.0
	body.position.y = sin(_t * 23.0) * 0.012 * clampf(mult, 0.2, 2.0)
	for w in wheels:
		w.rotation.x -= speed * dt / WHEEL_R_REAR
	for fl in flames:
		fl.emitting = boosting
	smoke.emitting = slowed
