@tool
class_name Woodland
extends RefCounted
## Décor original : un village d'ateliers dans une forêt miniature.

const WOOD := Color("#735641")
const CUT_WOOD := Color("#b59b70")
const MOSS := Color("#365b50")
const GOLD := Color("#e9bc74")
const CREAM := Color("#f2e6c9")


static func populate(parent: Node3D, track: Track) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = track.decor_seed + 2026
	var area := track.bounds().grow(60)
	var rocks: Array[Transform3D] = []
	var fern: Array[Transform3D] = []
	var blooms: Array[Transform3D] = []
	var trunks: Array[Transform3D] = []
	for i in int(140 * track.detail):
		var p := Vector3(rng.randf_range(area.position.x, area.end.x), 0, rng.randf_range(area.position.y, area.end.y))
		var distance := Vector2(p.x, p.z).distance_to(Vector2(track.curve.get_closest_point(p).x, track.curve.get_closest_point(p).z))
		if distance < track.road_half_width + 9.0:
			continue
		var scale_tree := rng.randf_range(0.7, 1.5)
		trunks.append(Transform3D(Basis().scaled(Vector3(1, 1, 1) * scale_tree), p))
		# Sous-bois avec silhouettes de grandes feuilles, rochers et petites baies.
		for j in 5:
			var q := p + Vector3(rng.randf_range(-4, 4), 0.2, rng.randf_range(-4, 4))
			var basis := Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3.RIGHT, 0.5)
			fern.append(Transform3D(basis.scaled(Vector3(0.4, 0.15, 1.4)), q + Vector3.UP * 0.3))
			blooms.append(Transform3D(Basis().scaled(Vector3(0.12, 0.2, 0.12)), q + Vector3.UP * 0.65))
		if i % 3 == 0:
			rocks.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(2, 1.3, 1.5)), p + Vector3(3, 0.3, 0)))
	_batch_model(parent, "res://assets/models/oak.glb", trunks)
	var canopy := Mk.sphere(1)
	canopy.radial_segments = 12
	canopy.rings = 6
	_batch(parent, canopy, rocks, Color("#647975"))
	_batch(parent, canopy, fern, Color("#679678"))
	_batch(parent, Mk.sphere(1), blooms, Color("#e8bc7a"))
	# Ateliers aux fenêtres chaudes, répartis dans les clairières.
	for i in 10:
		var f := track.frame_at(30 + i * 61.0)
		var side := -1.0 if i % 2 == 0 else 1.0
		var p := f.origin + f.basis.x * side * 23.0
		p.y = 0
		if track.curve.get_closest_point(p).distance_to(p) < track.road_half_width + 7:
			continue
		var house := _house()
		parent.add_child(house)
		house.position = p
		house.rotation.y = atan2(f.origin.x - p.x, f.origin.z - p.z) + PI
	# Lanternes : jalons chaleureux qui guident le regard dans les virages.
	for i in int(track.length / 19.0):
		var f := track.frame_at(i * 19.0 + 8)
		for side in [-1.0, 1.0]:
			var lamp := _lantern()
			parent.add_child(lamp)
			lamp.transform = Transform3D(f.basis, f.origin + f.basis.x * side * (track.road_half_width + 2.3))
	# Champignons géants et rondins au bord du sentier.
	for i in int(65 * track.detail):
		var f := track.frame_at(i * 9.7)
		var side := -1.0 if i % 2 == 0 else 1.0
		var p := f.origin + f.basis.x * side * (track.road_half_width + 5.0)
		p.y = 0
		_mushroom(parent, p, rng.randf_range(0.6, 1.4))
	_gate(parent, track.frame_at(0))
	# Paysage éloigné : silhouettes superposées, sans horizon quadrillé.
	var center := Vector3(area.get_center().x, 0, area.get_center().y)
	for i in 18:
		var angle := i * TAU / 18
		var p := center + Vector3(cos(angle), 0, sin(angle)) * 380
		var mesh := Mk.sphere(1)
		mesh.radial_segments = 16
		mesh.rings = 8
		Mk.part(parent, mesh, Color("#486b65").lerp(Color("#81918a"), float(i % 3) / 3), p, Vector3.ZERO, Vector3(140, rng.randf_range(65, 100), 105))


static func _batch(parent: Node3D, mesh: Mesh, transforms: Array[Transform3D], color: Color, colors: Array[Color] = []) -> void:
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
	var material := Mk.mat(color).duplicate() as StandardMaterial3D
	material.vertex_color_use_as_albedo = mm.use_colors
	material.vertex_color_is_srgb = true
	mi.material_override = material
	parent.add_child(mi)


static func _mushroom(parent: Node3D, p: Vector3, s: float) -> void:
	var prop: Node3D = load("res://assets/models/mushroom.glb").instantiate()
	parent.add_child(prop)
	prop.position = p
	prop.scale = Vector3.ONE * s


static func _lantern() -> Node3D:
	var n := Node3D.new()
	Mk.part(n, Mk.cyl(0.09, 0.15, 2.9, 8), WOOD, Vector3(0, 1.45, 0))
	Mk.part(n, Mk.box(Vector3(0.8, 0.12, 0.15)), WOOD, Vector3(0.25, 2.8, 0))
	Mk.part(n, Mk.cyl(0.015, 0.015, 0.3, 6), CUT_WOOD, Vector3(0.6, 2.6, 0))
	var light := Mk.part(n, Mk.cyl(0.19, 0.23, 0.45, 8), GOLD, Vector3(0.6, 2.3, 0))
	light.material_override = Mk.mat(GOLD, true, 0.35)
	for y in [2.04, 2.56]:
		Mk.part(n, Mk.cyl(0.25, 0.27, 0.07, 8), Color("#314b46"), Vector3(0.6, y, 0))
	return n


static func _house() -> Node3D:
	return load("res://assets/models/workshop.glb").instantiate()


static func _gate(parent: Node3D, transform: Transform3D) -> void:
	var n := Node3D.new()
	parent.add_child(n)
	n.transform = transform
	for side in [-1, 1]:
		Mk.part(n, Mk.cyl(0.6, 1, 8, 10), WOOD, Vector3(side * 9.4, 4, 0))
		Mk.part(n, Mk.sphere(1), MOSS, Vector3(side * 9.4, 8.0, 0), Vector3.ZERO, Vector3(2.8, 1.4, 2))
	Mk.part(n, Mk.rounded_box(Vector3(18.2, 1.7, 0.65), 0.25), CUT_WOOD, Vector3(0, 7.3, 0))
	for side in [0, 180]:
		var text := Label3D.new()
		text.text = "L’ATELIER DES BOIS"
		text.font = Ui.font()
		text.font_size = 100
		text.pixel_size = 0.011
		text.outline_size = 0
		text.modulate = CREAM
		text.position = Vector3(0, 7.3, 0.35 if side == 0 else -0.35)
		text.rotation_degrees.y = side
		n.add_child(text)
	for i in 9:
		var lamp := _lantern()
		lamp.scale = Vector3.ONE * 0.55
		lamp.position = Vector3(-8 + i * 2, 4.8, 0)
		n.add_child(lamp)


static func showroom() -> Node3D:
	var n := Node3D.new()
	n.name = "Showroom"
	n.position = Vector3(-320, 0, 0)
	Mk.part(n, Mk.cyl(5.0, 5.35, 0.6, 64), WOOD, Vector3(0, 0.3, 0))
	Mk.part(n, Mk.cyl(4.97, 4.97, 0.06, 64), CUT_WOOD, Vector3(0, 0.62, 0))
	for r in [2.7, 3.9, 4.6]:
		Mk.part(n, Mk.torus(r - 0.018, r + 0.018), WOOD.lightened(0.13), Vector3(0.14, 0.659, 0.08), Vector3.ZERO, Vector3(1, 0.1, 1))
	var ground := PlaneMesh.new()
	ground.size = Vector2(130, 130)
	Mk.part(n, ground, MOSS, Vector3(0, -0.05, 0))
	var places := [Vector3(-11, 0, 14), Vector3(8, 0, 15), Vector3(19, 0, 24)]
	for i in places.size():
		var house := _house()
		n.add_child(house)
		house.position = places[i]
	var grove: Array[Transform3D] = []
	for i in 12:
		var p := Vector3(-32 + i * 6, 0, 24 + (i % 3) * 6)
		grove.append(Transform3D(Basis().scaled(Vector3.ONE * (1.2 + (i % 3) * 0.3)), p))
	_batch_model(n, "res://assets/models/oak.glb", grove)
	var key := OmniLight3D.new()
	key.position = Vector3(-4, 5, -6)
	key.light_color = Color("#ffe4ba")
	key.light_energy = 2.4
	key.omni_range = 14
	n.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(4, 4, 2)
	rim.light_color = Color("#bddbe2")
	rim.light_energy = 1.5
	rim.omni_range = 12
	n.add_child(rim)
	for i in 9:
		var a := i * TAU / 9
		_mushroom(n, Vector3(cos(a) * 6.5, 0, sin(a) * 6.5), 0.7 + (i % 3) * 0.2)
	for side in [-1, 1]:
		var lamp := _lantern()
		n.add_child(lamp)
		lamp.position = Vector3(side * 5.4, 0, 0)
	return n


## Regroupe les exemplaires d'un modèle sculpté en quelques appels de dessin.
static func _batch_model(parent: Node3D, path: String, transforms: Array[Transform3D]) -> void:
	var template: Node3D = load(path).instantiate()
	for child in template.find_children("*", "MeshInstance3D", true, false):
		var source := child as MeshInstance3D
		var local := source.transform
		var ancestor := source.get_parent() as Node3D
		while ancestor and ancestor != template:
			local = ancestor.transform * local
			ancestor = ancestor.get_parent() as Node3D
		local = template.transform * local
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = source.mesh
		mm.instance_count = transforms.size()
		for i in transforms.size():
			mm.set_instance_transform(i, transforms[i] * local)
		var batch := MultiMeshInstance3D.new()
		batch.multimesh = mm
		parent.add_child(batch)
	template.free()
