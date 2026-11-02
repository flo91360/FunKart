@tool
class_name Mk
## Petites formes et effets de particules (flammes du turbo, fumée,
## confettis de l'arrivée). Les modèles 3D sont faits avec MeshBuilder.


static func sphere(r: float, hemisphere := false) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r if hemisphere else r * 2.0
	m.is_hemisphere = hemisphere
	m.radial_segments = 16
	m.rings = 8
	return m


static func gradient(colors: Array) -> Gradient:
	var offsets := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offsets.append(float(i) / maxf(1.0, colors.size() - 1.0))
		cols.append(colors[i])
	var g := Gradient.new()
	g.offsets = offsets
	g.colors = cols
	return g


## Gerbe de particules (explosion de couleurs) qui se détruit toute seule.
static func burst(parent: Node, pos: Vector3, colors: Array, amount := 50, speed := 9.0) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 1.4
	var confetti := BoxMesh.new()
	confetti.size = Vector3(0.22, 0.04, 0.14)
	p.mesh = confetti
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	p.material_override = m
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9, 0)
	p.damping_min = 1.5
	p.damping_max = 3.0
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.particle_flag_rotate_y = true
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.5
	p.color_initial_ramp = gradient(colors)
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(2.5).timeout.connect(p.queue_free)
