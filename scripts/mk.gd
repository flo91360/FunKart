class_name Mk
## Petites fonctions pour fabriquer des modèles 3D à partir de formes simples
## (aucun fichier 3D externe n'est nécessaire).

static var _mats := {}


static func mat(color: Color, unshaded := false, emission := 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [color.to_html(), unshaded, emission]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	m.metallic_specular = 0.2
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m


static func part(parent: Node3D, mesh: Mesh, color: Color, pos := Vector3.ZERO,
		rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(color)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func sphere(r: float, hemisphere := false) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r if hemisphere else r * 2.0
	m.is_hemisphere = hemisphere
	m.radial_segments = 24
	m.rings = 12
	return m


## Cylindre ou cône (top = 0 pour un cône pointé vers le haut).
static func cyl(top: float, bottom: float, height: float, segments := 20) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return m


static func capsule(r: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = height
	return m


static func torus(inner: float, outer: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	return m


## Étoile à 5 branches en relief.
static func star_mesh(outer: float, inner: float, depth: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	for i in 10:
		var a := PI / 2.0 + i * PI / 5.0
		var r := outer if i % 2 == 0 else inner
		pts.append(Vector3(cos(a) * r, sin(a) * r, 0.0))
	var front := Vector3(0, 0, -depth / 2.0)
	var back := Vector3(0, 0, depth / 2.0)
	for i in 10:
		var a := pts[i]
		var b := pts[(i + 1) % 10]
		# faces avant et arrière
		st.set_normal(Vector3.FORWARD)
		st.add_vertex(front); st.add_vertex(a + front * 0.3); st.add_vertex(b + front * 0.3)
		st.set_normal(Vector3.BACK)
		st.add_vertex(back); st.add_vertex(b + back * 0.3); st.add_vertex(a + back * 0.3)
		# côtés
		var n := (b - a).cross(Vector3.BACK).normalized()
		st.set_normal(n)
		st.add_vertex(a + front * 0.3); st.add_vertex(a + back * 0.3); st.add_vertex(b + back * 0.3)
		st.add_vertex(a + front * 0.3); st.add_vertex(b + back * 0.3); st.add_vertex(b + front * 0.3)
	return st.commit()


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
	p.lifetime = 1.0
	p.mesh = sphere(0.15)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = m
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -12, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	p.color_initial_ramp = gradient(colors)
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(2.0).timeout.connect(p.queue_free)
