class_name GiftProps
## Objets 3D des cases cadeau, faits de formes simples par le code : paquets
## cadeau posés sur la piste, plaque d'huile, planche à clous, nuage de
## tempête (avec sa pluie), fusée du kart, flèche au-dessus de la case choisie.

static var _mats := {}


static func mat(color: Color, rough := 0.5, metal := 0.0, glow := 0.0) -> StandardMaterial3D:
	var key := "%s/%.2f/%.2f/%.2f" % [color.to_html(), rough, metal, glow]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	_mats[key] = m
	return m


static func _part(parent: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot_deg := Vector3.ZERO,
		scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _cyl(top: float, bottom: float, height: float, segments := 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = segments
	c.rings = 1
	return c


## Paquet cadeau qui flotte au-dessus de la piste. L'enfant « Spin » tourne
## et rebondit (animé par Race), il rétrécit quand la case est prise.
static func gift_box(color: Color) -> Node3D:
	var root := Node3D.new()
	var spin := Node3D.new()
	spin.name = "Spin"
	root.add_child(spin)
	var s := 1.3
	var paper := mat(color, 0.35, 0.0, 0.25)
	var ribbon := mat(Color("#fff3b0"), 0.3, 0.2, 0.35)
	_part(spin, _box(Vector3(s, s, s)), paper)
	_part(spin, _box(Vector3(s + 0.04, s + 0.04, 0.24)), ribbon)
	_part(spin, _box(Vector3(0.24, s + 0.04, s + 0.04)), ribbon)
	# nœud sur le dessus
	var loop := TorusMesh.new()
	loop.inner_radius = 0.1
	loop.outer_radius = 0.24
	loop.rings = 16
	loop.ring_segments = 8
	_part(spin, loop, ribbon, Vector3(-0.2, s / 2.0 + 0.16, 0), Vector3(90, 0, 35))
	_part(spin, loop, ribbon, Vector3(0.2, s / 2.0 + 0.16, 0), Vector3(90, 0, -35))
	_part(spin, Mk.sphere(0.12), ribbon, Vector3(0, s / 2.0 + 0.08, 0))
	return root


## Plaque d'huile : flaque noire et brillante sur la route.
static func oil_puddle() -> Node3D:
	var root := Node3D.new()
	var oil := mat(Color("#14121c"), 0.06, 0.5)
	var sheen := mat(Color(0.45, 0.35, 0.85, 0.45), 0.05, 0.3)
	_part(root, _cyl(1.25, 1.3, 0.05, 24), oil, Vector3(0, 0.03, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.8))
	for spot in [Vector3(1.1, 0, 0.55), Vector3(-1.05, 0, -0.5), Vector3(0.3, 0, -1.05)]:
		_part(root, _cyl(0.38, 0.42, 0.05, 16), oil, spot + Vector3(0, 0.03, 0))
	# reflets irisés
	_part(root, _cyl(0.5, 0.5, 0.01, 16), sheen, Vector3(-0.3, 0.065, 0.15), Vector3.ZERO, Vector3(1.0, 1.0, 0.5))
	_part(root, _cyl(0.3, 0.3, 0.01, 16), sheen, Vector3(0.45, 0.065, -0.3), Vector3.ZERO, Vector3(1.0, 1.0, 0.6))
	return root


## Clou : une planche hérissée de gros clous, pointes en l'air.
static func nail_board() -> Node3D:
	var root := Node3D.new()
	var wood := mat(Color("#a0673a"), 0.8)
	var steel := mat(Color("#c9ced6"), 0.25, 0.8)
	_part(root, _box(Vector3(1.8, 0.1, 0.6)), wood, Vector3(0, 0.05, 0))
	var shaft := _cyl(0.045, 0.045, 0.42, 8)
	var tip := _cyl(0.0, 0.045, 0.16, 8)
	for i in 5:
		var x := -0.72 + i * 0.36
		var z := 0.12 if i % 2 == 0 else -0.12
		var lean := Vector3((i % 3 - 1) * 8.0, 0, (i % 2 * 2 - 1) * 6.0)
		var nail := Node3D.new()
		nail.position = Vector3(x, 0.1, z)
		nail.rotation_degrees = lean
		root.add_child(nail)
		_part(nail, shaft, steel, Vector3(0, 0.21, 0))
		_part(nail, tip, steel, Vector3(0, 0.5, 0))
	# deux clous tombés à côté
	for side in [-1.0, 1.0]:
		var lying := Node3D.new()
		lying.position = Vector3(side * 1.25, 0.05, side * 0.3)
		lying.rotation_degrees = Vector3(0, side * 40.0, 90)
		root.add_child(lying)
		_part(lying, shaft, steel, Vector3(0, 0.0, 0))
		_part(lying, _cyl(0.1, 0.1, 0.03, 10), steel, Vector3(0, -0.22, 0))
	return root


## Nuage de tempête avec sa pluie (l'enfant « Rain » : particules).
static func storm_cloud() -> Node3D:
	var root := Node3D.new()
	var cloud := mat(Color("#4a4e69"), 1.0)
	var dark := mat(Color("#2b2d42"), 1.0)
	for puff in [[Vector3(-0.9, 0, 0), 0.75], [Vector3(0, 0.25, 0), 0.95], [Vector3(0.95, 0.05, 0.1), 0.7],
			[Vector3(0.3, -0.1, 0.5), 0.6], [Vector3(-0.4, -0.05, -0.5), 0.62]]:
		_part(root, Mk.sphere(puff[1]), cloud, puff[0])
	_part(root, Mk.sphere(1.0), dark, Vector3(0, -0.35, 0), Vector3.ZERO, Vector3(1.7, 0.35, 0.9))
	var rain := CPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = 70
	rain.lifetime = 0.45
	rain.local_coords = true
	rain.mesh = _box(Vector3(0.035, 0.45, 0.035))
	rain.material_override = mat(Color(0.7, 0.82, 1.0, 0.75), 0.2, 0.0, 0.3)
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(1.5, 0.1, 1.1)
	rain.direction = Vector3.DOWN
	rain.spread = 4.0
	rain.initial_velocity_min = 9.0
	rain.initial_velocity_max = 12.0
	rain.gravity = Vector3(0, -20, 0)
	rain.position = Vector3(0, -0.5, 0)
	root.add_child(rain)
	return root


## Fusée fixée sur le kart (pointe vers l'avant, -Z), avec sa flamme.
static func rocket() -> Node3D:
	var root := Node3D.new()
	var body := mat(Color("#f1f1f1"), 0.35, 0.2)
	var red := mat(Color("#e63946"), 0.4)
	var glass := mat(Color("#4cc9f0"), 0.1, 0.3, 0.4)
	var flame := mat(Color("#ffb703"), 0.5, 0.0, 2.5)
	_part(root, _cyl(0.26, 0.26, 1.2, 16), body, Vector3.ZERO, Vector3(90, 0, 0))
	_part(root, _cyl(0.0, 0.26, 0.5, 16), red, Vector3(0, 0, -0.85), Vector3(-90, 0, 0))
	_part(root, Mk.sphere(0.11), glass, Vector3(0, 0.2, -0.25))
	for a in [0.0, 120.0, 240.0]:
		var fin := Node3D.new()
		fin.rotation_degrees = Vector3(0, 0, a)
		root.add_child(fin)
		_part(fin, _box(Vector3(0.05, 0.32, 0.4)), red, Vector3(0, 0.36, 0.45))
	_part(root, _cyl(0.0, 0.2, 0.7, 12), flame, Vector3(0, 0, 0.95), Vector3(90, 0, 0))
	return root


## Flèche jaune au-dessus de la case choisie par l'enfant.
static func marker() -> Node3D:
	var root := Node3D.new()
	var yellow := mat(Color("#ffd60a"), 0.3, 0.0, 0.8)
	# contour foncé : la même forme un peu plus grande, vue de l'intérieur
	var outline := StandardMaterial3D.new()
	outline.albedo_color = Color("#1d3557")
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.cull_mode = BaseMaterial3D.CULL_FRONT
	_part(root, _cyl(0.55, 0.0, 0.8, 16), outline, Vector3(0, -0.02, 0), Vector3.ZERO, Vector3(1.15, 1.12, 1.15))
	_part(root, _cyl(0.55, 0.0, 0.8, 16), yellow)
	_part(root, _cyl(0.22, 0.22, 0.6, 12), yellow, Vector3(0, 0.65, 0))
	return root
