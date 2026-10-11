class_name Props
## Objets « obstacles » qui apparaissent devant le kart du joueur quand un mot
## est à taper. Le modèle dépend du mot (banane, champignon, étoile…) ; pour les
## autres mots, c'est une boîte mystère.

const RAINBOW_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled;
void fragment() {
	float h = fract(TIME * 0.3 + UV.x * 0.5 + UV.y * 0.5);
	vec3 c = clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	ALBEDO = mix(vec3(1.0), c, 0.75);
	EMISSION = c * 0.4;
	ALPHA = 0.8;
}
"""


static func _key(word: String) -> String:
	var s := ""
	for ch in word.to_lower():
		s += RaceLogic.ACCENTS.get(ch, ch)
	return s


static func make(word: String) -> Node3D:
	var root := Node3D.new()
	match _key(word):
		"banane":
			_banana(root)
		"champignon":
			_mushroom(root)
		"etoile":
			_star(root)
		"pomme", "cerise", "tomate":
			_fruit(root, Color("#e5383b"))
		"citron":
			_fruit(root, Color("#ffe066"), Vector3(1.3, 1, 1))
		"fraise":
			_strawberry(root)
		"ballon":
			_balloon(root)
		"cadeau":
			_gift(root)
		_:
			_item_box(root)
	return root


static func _banana(root: Node3D) -> void:
	for i in 7:
		var t := i / 6.0
		var a := lerpf(-1.0, 1.0, t)
		var r := 0.32 * (1.0 - absf(t - 0.5) * 1.1)
		var col := Color("#ffd23f") if i > 0 and i < 6 else Color("#6b4f1d")
		Mk.part(root, Mk.sphere(maxf(r, 0.1)), col, Vector3(sin(a) * 1.0, -cos(a) * 0.7 + 0.4, 0))


static func _mushroom(root: Node3D) -> void:
	Mk.part(root, Mk.cyl(0.38, 0.48, 0.9), Color("#fff3d6"), Vector3(0, -0.2, 0))
	Mk.part(root, Mk.sphere(1.0, true), Color("#e63946"), Vector3(0, 0.22, 0), Vector3.ZERO, Vector3(1, 0.85, 1))
	for dir in [Vector3(0, 1, 0), Vector3(0.7, 0.5, 0), Vector3(-0.7, 0.5, 0), Vector3(0, 0.5, 0.7), Vector3(0, 0.5, -0.7)]:
		var n: Vector3 = dir.normalized()
		Mk.part(root, Mk.sphere(0.22), Color.WHITE, Vector3(0, 0.22, 0) + Vector3(n.x, n.y * 0.85, n.z) * 0.95, Vector3.ZERO, Vector3(1, 0.5, 1))
	for s in [-1.0, 1.0]:
		Mk.part(root, Mk.capsule(0.06, 0.25), Color("#151515"), Vector3(s * 0.14, -0.15, -0.45))


static func _star(root: Node3D) -> void:
	var mi := Mk.part(root, Mk.star_mesh(1.1, 0.5, 0.35), Color("#ffd60a"))
	mi.material_override = Mk.mat(Color("#ffd60a"), false, 0.6)
	for s in [-1.0, 1.0]:
		Mk.part(root, Mk.capsule(0.06, 0.28), Color("#151515"), Vector3(s * 0.16, 0.08, -0.25))


static func _fruit(root: Node3D, color: Color, scl := Vector3.ONE) -> void:
	Mk.part(root, Mk.sphere(0.75), color, Vector3.ZERO, Vector3.ZERO, scl)
	Mk.part(root, Mk.cyl(0.05, 0.06, 0.4, 8), Color("#6b4f1d"), Vector3(0, 0.85, 0))
	Mk.part(root, Mk.sphere(0.2), Color("#3fb24f"), Vector3(0.2, 0.9, 0), Vector3(0, 0, -30), Vector3(1.4, 0.4, 0.8))


static func _strawberry(root: Node3D) -> void:
	Mk.part(root, Mk.cyl(0.7, 0.08, 1.3, 16), Color("#e5383b"), Vector3.ZERO)
	Mk.part(root, Mk.sphere(0.7), Color("#e5383b"), Vector3(0, 0.6, 0), Vector3.ZERO, Vector3(1, 0.4, 1))
	Mk.part(root, Mk.sphere(0.45), Color("#3fb24f"), Vector3(0, 0.8, 0), Vector3.ZERO, Vector3(1, 0.3, 1))


static func _balloon(root: Node3D) -> void:
	Mk.part(root, Mk.sphere(0.8), Color("#ff4d6d"), Vector3(0, 0.4, 0), Vector3.ZERO, Vector3(1, 1.15, 1))
	Mk.part(root, Mk.cyl(0.0, 0.12, 0.2, 8), Color("#ff4d6d"), Vector3(0, -0.55, 0), Vector3(180, 0, 0))
	Mk.part(root, Mk.cyl(0.015, 0.015, 1.2, 4), Color("#eeeeee"), Vector3(0, -1.2, 0))


static func _gift(root: Node3D) -> void:
	Mk.part(root, Mk.box(Vector3(1.3, 1.1, 1.3)), Color("#2d7ff9"))
	Mk.part(root, Mk.box(Vector3(1.34, 1.14, 0.25)), Color("#ffd60a"))
	Mk.part(root, Mk.box(Vector3(0.25, 1.14, 1.34)), Color("#ffd60a"))
	for s in [-1.0, 1.0]:
		Mk.part(root, Mk.torus(0.1, 0.28), Color("#ffd60a"), Vector3(s * 0.25, 0.7, 0), Vector3(90, 0, 0))


static func _item_box(root: Node3D) -> void:
	var sh := Shader.new()
	sh.code = RAINBOW_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	var mi := MeshInstance3D.new()
	mi.mesh = Mk.box(Vector3(1.5, 1.5, 1.5))
	mi.material_override = m
	root.add_child(mi)
	for i in 4:
		var label := Label3D.new()
		label.text = "?"
		label.font_size = 140
		label.outline_size = 24
		label.pixel_size = 0.01
		label.modulate = Color.WHITE
		label.outline_modulate = Color("#1d3557")
		label.rotation_degrees = Vector3(0, i * 90.0, 0)
		label.position = Basis(Vector3.UP, deg_to_rad(i * 90.0)) * Vector3(0, 0, 0.78)
		root.add_child(label)
