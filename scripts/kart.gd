class_name Kart
extends Node3D
## Un kart avec son pilote. L'avant du kart est vers -Z.

const WHEEL_R_REAR := 0.36
const WHEEL_R_FRONT := 0.3

var info: Dictionary
var model := Node3D.new() # inclinaison dans les virages
var body := Node3D.new() # petits rebonds
var wheels: Array[Node3D] = []
var steer_pivots: Array[Node3D] = []
var flames: Array[CPUParticles3D] = []
var smoke: CPUParticles3D
var lateral := 0.0
var target_lateral := 0.0
var extra_distance := 0.0 # distance parcourue après l'arrivée (tour d'honneur)
var _t := randf() * 10.0


func _init(character_id := "chat", display_name := "", show_label := false) -> void:
	info = Characters.get_info(character_id)
	add_child(model)
	model.add_child(body)
	model.scale = Vector3.ONE * 1.3
	_build_kart()
	_build_driver()
	_build_effects()
	if show_label:
		var label := Label3D.new()
		label.text = display_name
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 64
		label.outline_size = 16
		label.pixel_size = 0.008
		label.position = Vector3(0, 3.6, 0)
		label.modulate = Color.WHITE
		label.outline_modulate = Color(0, 0, 0, 0.8)
		add_child(label)


func _build_kart() -> void:
	var kc: Color = info.kart
	var dark := Color("#2b2d33")
	Mk.part(body, Mk.box(Vector3(1.3, 0.22, 2.1)), kc, Vector3(0, 0.32, 0))
	Mk.part(body, Mk.box(Vector3(0.28, 0.32, 1.2)), kc.darkened(0.15), Vector3(-0.72, 0.4, 0.05))
	Mk.part(body, Mk.box(Vector3(0.28, 0.32, 1.2)), kc.darkened(0.15), Vector3(0.72, 0.4, 0.05))
	Mk.part(body, Mk.box(Vector3(1.0, 0.3, 0.55)), kc, Vector3(0, 0.38, -1.1), Vector3(-12, 0, 0))
	Mk.part(body, Mk.box(Vector3(1.55, 0.18, 0.24)), dark, Vector3(0, 0.26, -1.42))
	Mk.part(body, Mk.box(Vector3(1.55, 0.2, 0.22)), dark, Vector3(0, 0.3, 1.15))
	# siège
	Mk.part(body, Mk.box(Vector3(0.8, 0.75, 0.2)), dark, Vector3(0, 0.8, 0.5), Vector3(-10, 0, 0))
	Mk.part(body, Mk.box(Vector3(0.8, 0.15, 0.6)), dark, Vector3(0, 0.5, 0.22))
	# moteur et pots d'échappement
	Mk.part(body, Mk.box(Vector3(0.85, 0.45, 0.45)), Color("#8d99ae"), Vector3(0, 0.62, 0.95))
	for x in [-0.25, 0.25]:
		Mk.part(body, Mk.cyl(0.08, 0.08, 0.5, 12), Color("#c0c0c0"), Vector3(x, 0.72, 1.25), Vector3(90, 0, 0))
	# volant
	Mk.part(body, Mk.cyl(0.04, 0.04, 0.6, 8), dark, Vector3(0, 0.7, -0.45), Vector3(-40, 0, 0))
	Mk.part(body, Mk.torus(0.13, 0.21), dark, Vector3(0, 0.95, -0.3), Vector3(55, 0, 0))
	# roues (les roues avant tournent dans les virages)
	for side in [-1.0, 1.0]:
		var rear := _wheel(WHEEL_R_REAR, 0.38)
		rear.position = Vector3(side * 0.84, WHEEL_R_REAR, 0.75)
		body.add_child(rear)
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.8, WHEEL_R_FRONT, -0.78)
		body.add_child(pivot)
		pivot.add_child(_wheel(WHEEL_R_FRONT, 0.3))
		steer_pivots.append(pivot)


func _wheel(r: float, w: float) -> Node3D:
	var n := Node3D.new()
	Mk.part(n, Mk.cyl(r, r, w, 18), Color("#1b1b1f"), Vector3.ZERO, Vector3(0, 0, 90))
	Mk.part(n, Mk.cyl(r * 0.5, r * 0.5, w + 0.02, 12), info.kart.lightened(0.3), Vector3.ZERO, Vector3(0, 0, 90))
	# un rayon pour voir la roue tourner
	Mk.part(n, Mk.box(Vector3(w + 0.04, r * 1.2, 0.08)), Color("#eeeeee"), Vector3.ZERO)
	wheels.append(n)
	return n


func _build_driver() -> void:
	var fur: Color = info.fur
	var shirt: Color = info.shirt
	Mk.part(body, Mk.capsule(0.32, 0.95), shirt, Vector3(0, 1.05, 0.28))
	for side in [-1.0, 1.0]:
		Mk.part(body, Mk.capsule(0.1, 0.6), shirt, Vector3(side * 0.26, 1.08, -0.08), Vector3(60, 0, 0))
		Mk.part(body, Mk.sphere(0.1), fur, Vector3(side * 0.18, 0.95, -0.33))
	var extra: String = info.get("extra", "")
	if extra == "turtle":
		Mk.part(body, Mk.sphere(0.55, true), Color("#2e7d32"), Vector3(0, 1.1, 0.55), Vector3(90, 0, 0), Vector3(1, 1, 0.7))
	var head := Node3D.new()
	head.position = Vector3(0, 1.8, 0.2)
	body.add_child(head)
	_build_head(head)


func _build_head(h: Node3D) -> void:
	var fur: Color = info.fur
	var ear_color: Color = info.get("ear", fur)
	var extra: String = info.get("extra", "")
	var black := Color("#151515")
	var white := Color("#ffffff")

	if extra == "lion":
		Mk.part(h, Mk.sphere(0.64), Color("#b5651d"), Vector3(0, 0, 0.14), Vector3.ZERO, Vector3(1, 1, 0.6))
	Mk.part(h, Mk.sphere(0.42), fur)

	match String(info.get("ears", "none")):
		"cat":
			for s in [-1.0, 1.0]:
				Mk.part(h, Mk.cyl(0.0, 0.16, 0.36, 12), ear_color, Vector3(s * 0.24, 0.4, 0.02), Vector3(0, 0, -s * 22))
		"round":
			for s in [-1.0, 1.0]:
				Mk.part(h, Mk.sphere(0.14), ear_color, Vector3(s * 0.3, 0.33, 0.04))
		"floppy":
			for s in [-1.0, 1.0]:
				Mk.part(h, Mk.sphere(0.17), ear_color, Vector3(s * 0.42, -0.02, 0.05), Vector3(0, 0, s * 15), Vector3(0.55, 1.4, 0.9))
		"long":
			for s in [-1.0, 1.0]:
				Mk.part(h, Mk.capsule(0.1, 0.8), ear_color, Vector3(s * 0.15, 0.68, 0.06), Vector3(0, 0, -s * 8))
				Mk.part(h, Mk.capsule(0.05, 0.6), Color("#ffb3c6"), Vector3(s * 0.15, 0.68, -0.02), Vector3(0, 0, -s * 8))
		"mouse":
			for s in [-1.0, 1.0]:
				Mk.part(h, Mk.sphere(0.24), ear_color, Vector3(s * 0.34, 0.34, 0.05), Vector3.ZERO, Vector3(1, 1, 0.35))
		"monkey":
			for s in [-1.0, 1.0]:
				Mk.part(h, Mk.sphere(0.15), ear_color, Vector3(s * 0.44, 0.04, 0.02), Vector3.ZERO, Vector3(0.5, 1, 1))

	match extra:
		"unicorn":
			Mk.part(h, Mk.cyl(0.0, 0.09, 0.5, 12), Color("#ffd60a"), Vector3(0, 0.48, -0.24), Vector3(-25, 0, 0))
			for i in 4:
				Mk.part(h, Mk.sphere(0.13), Color("#ff7ab6").lerp(Color("#7ad7ff"), i / 3.0), Vector3(0, 0.36 - i * 0.16, 0.3 + i * 0.04))
		"panda":
			for s in [-1.0, 1.0]:
				Mk.part(h, Mk.sphere(0.13), black, Vector3(s * 0.15, 0.08, -0.31), Vector3.ZERO, Vector3(1, 1.2, 0.5))
		"monkey":
			Mk.part(h, Mk.sphere(0.32), ear_color, Vector3(0, -0.05, -0.2), Vector3.ZERO, Vector3(1.1, 0.9, 0.6))
		"penguin":
			Mk.part(h, Mk.sphere(0.33), white, Vector3(0, -0.02, -0.18), Vector3.ZERO, Vector3(1, 1, 0.6))
			Mk.part(h, Mk.cyl(0.0, 0.1, 0.26, 10), Color("#ff9f1c"), Vector3(0, -0.1, -0.5), Vector3(-90, 0, 0))

	# yeux
	if extra == "frog":
		for s in [-1.0, 1.0]:
			Mk.part(h, Mk.sphere(0.18), white, Vector3(s * 0.2, 0.36, -0.14))
			Mk.part(h, Mk.sphere(0.09), black, Vector3(s * 0.2, 0.38, -0.3))
		Mk.part(h, Mk.box(Vector3(0.36, 0.04, 0.04)), Color("#b22222"), Vector3(0, -0.12, -0.4))
	else:
		for s in [-1.0, 1.0]:
			Mk.part(h, Mk.sphere(0.11), white, Vector3(s * 0.15, 0.09, -0.34))
			Mk.part(h, Mk.sphere(0.06), black, Vector3(s * 0.15, 0.09, -0.44))
	if info.has("snout"):
		Mk.part(h, Mk.sphere(0.2), info.snout, Vector3(0, -0.12, -0.33), Vector3.ZERO, Vector3(1.1, 0.75, 0.8))
		Mk.part(h, Mk.sphere(0.065), black, Vector3(0, -0.05, -0.5))


func _build_effects() -> void:
	var fm := StandardMaterial3D.new()
	fm.vertex_color_use_as_albedo = true
	fm.vertex_color_is_srgb = true
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for x in [-0.25, 0.25]:
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
		f.position = Vector3(x, 0.72, 1.55)
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
	body.position.y = sin(_t * 23.0) * 0.012 * clampf(mult, 0.2, 2.0)
	for w in wheels:
		w.rotation.x -= speed * dt / WHEEL_R_REAR
	for fl in flames:
		fl.emitting = boosting
	smoke.emitting = slowed
