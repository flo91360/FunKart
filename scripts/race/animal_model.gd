@tool
class_name AnimalModel
extends RefCounted
## Pilotes : animaux détaillés (yeux brillants, museau, oreilles, moustaches,
## crinière…) fabriqués avec MeshBuilder, assis dans le kart (repère de
## KartModel). Quelques parties sont à part pour être animées : la tête, les
## yeux (ils clignent), les oreilles souples, la queue et le pan de l'écharpe.
##
## Tête : repère centré sur la tête, avant vers -Z. Chaque espèce règle la
## forme de la tête (bosses : museau, joues…), ses couleurs « peintes »
## (museau clair, taches, rayures…) et ses détails.

## Centre de la tête dans le kart.
const HEAD_POS := Vector3(0.0, 1.8, 0.2)
const NECK_BACK := Vector3(0.0, 1.35, 0.38)
const DARK_LINE := Color("#3b2a26")
## Torse (ellipsoïde déformée) : centre, rayons, inclinaison, bosses (épaules, ventre).
const TORSO_CENTER := Vector3(0, 0.96, 0.27)
const TORSO_RADII := Vector3(0.31, 0.37, 0.25)
static var TORSO_BASIS := Basis(Vector3.RIGHT, deg_to_rad(8.0))
static var TORSO_BUMPS: Array = [[Vector3(1, 0.55, 0).normalized(), 0.12, 4.0], [Vector3(-1, 0.55, 0).normalized(), 0.12, 4.0], [Vector3(0, -0.4, -1).normalized(), 0.08, 3.0]]
const PAW_GRIP := 0.173 # écart des mains sur le volant

var info: CharacterData
var species := "generic"
var fur: Color
var ear_col: Color
var snout_col: Color
var shirt: Color
var head_r := Vector3(0.42, 0.4, 0.41)
var bumps: Array = []
var paint_fn := Callable() # couleur de la fourrure de la tête (position -> couleur)
var head := MeshBuilder.new()
var eye_centers: Array[Vector3] = []
var eye_r := 0.115
var out := {}


static func build(character: CharacterData) -> Dictionary:
	return AnimalModel.new(character)._build()


## Espèce du pilote : « extra », ou à défaut d'après ses oreilles.
static func species_of(c: CharacterData) -> String:
	if c.extra != "" and c.extra != "none":
		return c.extra
	match c.ears:
		"cat":
			return "cat"
		"floppy":
			return "dog"
		"long":
			return "rabbit"
		"mouse":
			return "mouse"
		"round":
			return "bear"
		"monkey":
			return "monkey"
	return "generic"


func _init(character: CharacterData) -> void:
	info = character
	species = species_of(info)
	fur = info.fur_color
	ear_col = info.ear_color
	snout_col = info.snout_color if info.has_snout else info.fur_color
	shirt = info.shirt_color


func _build() -> Dictionary:
	_head()
	out["head"] = head.commit()
	out["head_pos"] = HEAD_POS
	var eyes_y := 0.0
	for c in eye_centers:
		eyes_y += c.y
	eyes_y /= maxf(1.0, eye_centers.size())
	out["eyes_pos"] = Vector3(0, eyes_y, 0)
	# les yeux sont construits par rapport à leur hauteur (clignement : écrasement vertical)
	var em := MeshBuilder.new()
	em.push(Transform3D(Basis(), Vector3(0, -eyes_y, 0)))
	for e in _eye_jobs:
		_eye_into(em, e[0], e[1], e[2], e[3], e[4], e[5])
	em.pop()
	out["eyes"] = em.commit()
	out["driver"] = _driver()
	_scarf()
	_tail()
	return out


# ---------------- Forme de la tête ----------------

## Point de la surface de la tête dans une direction.
func surf(d: Vector3) -> Vector3:
	d = d.normalized()
	var k := 1.0
	for b in bumps:
		var dir: Vector3 = b[0]
		var dt := d.dot(dir)
		if dt > 0.0:
			k += float(b[1]) * pow(dt, float(b[2]))
	return d * k * head_r


## Normale de la surface de la tête dans une direction.
func normal_at(d: Vector3) -> Vector3:
	d = d.normalized()
	var t1 := d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized()
	var t2 := d.cross(t1).normalized()
	var e := 0.01
	var n := (surf(d + t1 * e) - surf(d - t1 * e)).cross(surf(d + t2 * e) - surf(d - t2 * e))
	if n.dot(d) < 0.0:
		n = -n
	return n.normalized()


## Point posé sur la tête (projeté depuis son centre), un peu au-dessus.
func on_head(p: Vector3, lift := 0.004) -> Vector3:
	var d := p.normalized()
	return surf(d) + normal_at(d) * lift


func bump(dir: Vector3, amount: float, power: float) -> void:
	bumps.append([dir.normalized(), amount, power])


static func dir(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z).normalized()


## 1 au centre d'une zone, 0 au-delà, avec un bord doux.
static func blob_mask(dist: float, radius: float, soft := 0.02) -> float:
	return 1.0 - smoothstep(radius - soft, radius + soft, dist)


func _head() -> void:
	match species:
		"cat":
			_cat()
		"dog":
			_dog()
		"fox":
			_fox()
		"bear":
			_bear()
		"rabbit":
			_rabbit()
		"mouse":
			_mouse()
		"lion":
			_lion()
		"panda":
			_panda()
		"unicorn":
			_unicorn()
		"penguin":
			_penguin()
		"frog":
			_frog()
		"turtle":
			_turtle()
		"monkey":
			_monkey()
		_:
			_generic()


## La tête elle-même (après les réglages de forme et de couleurs).
func _skull(kind := "fur", rings := 28, segs := 40) -> void:
	var pf: Variant = paint_fn if paint_fn.is_valid() else fur
	head.ellipsoid(Vector3.ZERO, Vector3.ONE, kind, pf, Basis(), [], rings, segs, surf)


# ---------------- Détails communs ----------------

var _eye_jobs: Array = [] # [centre, rayon, regard, iris, fente, enfoncement]


## Deux yeux : écart et hauteur (radians), rayon, couleur de l'iris.
## lid : paupière (0 : grand ouvert, 0.5 : mi-clos), liner : contour sombre.
func add_eyes(spread: float, up: float, re: float, iris: Color, slit := false, lid := 0.0,
		lid_color := Color(), liner := Color("#2a1f1c"), sink := 0.52) -> void:
	eye_r = re
	if lid_color == Color():
		lid_color = fur
	for s: float in [-1.0, 1.0]:
		var d := Vector3(s * sin(spread), sin(up), -cos(spread) * cos(up)).normalized()
		var n := normal_at(d)
		var c := surf(d) - n * re * sink
		add_eye_at(c, re, iris, slit, lid, lid_color, liner, s, sink)


## Un œil (centre, rayon) ; sink : profondeur dans la tête (en rayons), pour
## placer le contour sombre là où l'œil sort de la tête.
func add_eye_at(c: Vector3, re: float, iris: Color, slit: bool, lid: float, lid_color: Color, liner: Color, s: float, sink := 0.45) -> void:
	eye_centers.append(c)
	var look := (Vector3(-s * 0.1, 0.04, -1.0).normalized() * 0.8 + c.normalized() * 0.2).normalized()
	_eye_jobs.append([c, re, look, iris, slit, sink])
	if lid > 0.0:
		var up_e := (Vector3.UP - look * look.dot(Vector3.UP)).normalized()
		var ang := PI / 2.0 - lerpf(0.75, -0.2, lid)
		head.cap(c, re * 1.05, up_e, ang, "fur", lid_color, 6, 24)


func _eye_into(mb: MeshBuilder, c: Vector3, re: float, look: Vector3, iris: Color, slit: bool, sink: float) -> void:
	# repère de l'œil vu de face : droite (de celui qui regarde), haut
	var up_e := (Vector3.UP - look * look.dot(Vector3.UP)).normalized()
	var right_e := up_e.cross(look)
	var span := re * sin(0.66)
	mb.uv_fn = func(p: Vector3) -> Vector2:
		var v := p - c
		if v.dot(look) < 0.0:
			return Vector2(4.0, 4.0)
		return Vector2(v.dot(right_e), v.dot(up_e)) / span
	mb.uv2 = Vector2(0.62, 0.42) if slit else Vector2(0.5, 1.0)
	# alpha : rayon du contour sombre (là où l'œil sort de la tête), divisé par 2
	var liner_r := sin(acos(clampf(sink, 0.0, 0.95))) / sin(0.66)
	mb.sphere(c, re, "eye", Color(iris.r, iris.g, iris.b, clampf(liner_r / 2.0, 0.0, 1.0)), 18, 30)
	mb.uv_fn = Callable()
	mb.uv2 = Vector2.ZERO


## Truffe : "tri" (chat, triangle arrondi), "big" (chien, ours), "button".
func add_nose(p: Vector3, kind: String, color: Color, size := 1.0) -> void:
	var mat := "skin" if color.get_luminance() > 0.3 else "gloss"
	match kind:
		"tri":
			# triangle arrondi, pointe en bas
			var w := 0.056 * size
			var h := 0.036 * size
			var dz := 0.034 * size
			var tri := func(d: Vector3) -> Vector3:
				var t := (d.y + 1.0) / 2.0
				return Vector3(d.x * w * lerpf(0.3, 1.1, t), d.y * h, d.z * dz)
			head.ellipsoid(p, Vector3.ONE, mat, color, Basis(), [], 12, 20, tri)
		"big":
			head.ellipsoid(p, Vector3(0.085, 0.058, 0.06) * size, mat, color, Basis(),
				[[Vector3.UP, 0.15, 2.0], [Vector3.FORWARD, 0.1, 2.0]], 12, 20)
			for s: float in [-1.0, 1.0]:
				head.ellipsoid(p + Vector3(s * 0.032, -0.012, -0.05) * size, Vector3(0.018, 0.012, 0.012) * size, "matte", Color("#050505"), Basis(), [], 6, 10)
		_:
			head.sphere(p, 0.04 * size, mat, color, 8, 14)


## Joues roses (petits disques posés sur la tête).
func add_cheeks(color := Color("#ff9eb5"), spread := 0.62, height := -0.1, r := 0.075) -> void:
	for s: float in [-1.0, 1.0]:
		var d := dir(s * spread, height, -0.78)
		var n := normal_at(d)
		head.ellipsoid(surf(d) - n * 0.004, Vector3(r, r * 0.75, 0.012), "skin", color, MeshBuilder._basis_from_dir(n), [], 6, 16)


## Bouche en « w » sous la truffe.
func add_mouth(center: Vector3, w: float, color := DARK_LINE, smile := 0.02) -> void:
	var pts := PackedVector3Array()
	for i in 9:
		var t := -1.0 + 2.0 * i / 8.0
		var y := -absf(sin(t * PI)) * 0.025 + t * t * smile
		pts.append(on_head(center + Vector3(t * w, y, 0.0), 0.003))
	head.tube(MeshBuilder.smooth_path(pts, 2), MeshBuilder.taper(17, 0.008, 0.008), "skin", color, 6)


## Coussinets du museau (où poussent les moustaches).
func add_pads(center: Vector3, spread: float, r: Vector3, color: Color) -> void:
	for s: float in [-1.0, 1.0]:
		head.ellipsoid(center + Vector3(s * spread, 0, 0), r, "fur", color, Basis(), [], 12, 18)


func add_whiskers(center: Vector3, spread: float, color: Color, length := 0.3) -> void:
	for s: float in [-1.0, 1.0]:
		var o := center + Vector3(s * spread, 0, 0)
		for i in 3:
			var d := Vector3(s, 0.22 - i * 0.2, 0.25).normalized()
			var mid := o + d * length * 0.5 + Vector3(0, 0.01, 0)
			var tip := o + d * length + Vector3(0, -0.03 - i * 0.01, 0.02)
			head.tube(MeshBuilder.smooth_path(PackedVector3Array([o, mid, tip]), 3),
				MeshBuilder.taper(7, 0.0055, 0.0015), "plastic", color, 5)


## Oreille : base (sur la tête), direction de la pointe, direction vers
## laquelle elle s'ouvre, hauteur, largeur, épaisseur ; shape : "point",
## "round", "long", "floppy". L'intérieur (creusé) a sa propre couleur.
func make_ear(mb: MeshBuilder, base: Vector3, up: Vector3, face: Vector3, h: float, w: float, t: float,
		shape: String, outer: Color, inner: Color, tip_color := Color(), cup := 0.7, bend := 0.0) -> void:
	var y := up.normalized()
	var z := (face - y * face.dot(y)).normalized()
	var x := y.cross(z).normalized()
	mb.push(Transform3D(Basis(x, y, z), base))
	var ear_shape := func(d: Vector3) -> Vector3:
		var yn := (d.y + 1.0) / 2.0
		var rho := 0.0
		match shape:
			"round":
				rho = sqrt(maxf(0.0, 1.0 - pow(2.0 * yn - 1.0, 2.0)))
			"long":
				rho = pow(maxf(0.0, 1.0 - pow(yn, 3.0)), 0.6) * pow(minf(1.0, yn * 5.0), 0.5)
			"floppy":
				rho = pow(maxf(0.0, sin(PI * yn)), 0.55)
			_:
				rho = pow(maxf(0.0, 1.0 - yn), 0.85) * pow(minf(1.0, yn * 5.0), 0.5)
		var hl := sqrt(d.x * d.x + d.z * d.z)
		var cx := d.x / hl if hl > 1e-5 else 0.0
		var cz := d.z / hl if hl > 1e-5 else 0.0
		var px := cx * w * rho
		var pz := cz * t * rho
		if cz > 0.0:
			# creux de l'oreille, côté ouvert
			pz -= cup * t * rho * (1.0 - cx * cx) * cz
		pz += bend * yn * yn
		return Vector3(px, yn * h, pz)
	var ear_paint := func(p: Vector3) -> Color:
		var yn := p.y / h
		var col := outer
		if p.z > 0.0 - bend * yn * yn and yn > 0.1 and yn < 0.9:
			var wide := 0.0
			match shape:
				"round":
					wide = sqrt(maxf(0.0, 1.0 - pow(2.0 * yn - 1.0, 2.0)))
				"floppy":
					wide = pow(maxf(0.0, sin(PI * yn)), 0.55)
				_:
					wide = pow(maxf(0.0, 1.0 - yn), 0.85)
			var m := 1.0 - smoothstep(0.55, 0.75, absf(p.x) / maxf(0.001, w * wide))
			col = outer.lerp(inner, m)
		if tip_color != Color() and yn > 0.68:
			col = col.lerp(tip_color, smoothstep(0.68, 0.8, yn))
		return col
	mb.ellipsoid(Vector3.ZERO, Vector3.ONE, "fur", ear_paint, Basis(), [], 14, 20, ear_shape)
	mb.pop()


## Petites mèches de fourrure (joues, sommet de la tête) : base, direction, longueur.
func add_tuft(mb: MeshBuilder, base: Vector3, d: Vector3, length: float, r: float, color: Variant, droop := 0.04) -> void:
	var tip := base + d.normalized() * length + Vector3(0, -droop, 0)
	var mid := base + d.normalized() * length * 0.5 + Vector3(0, -droop * 0.2, 0)
	var path := MeshBuilder.smooth_path(PackedVector3Array([base, mid, tip]), 3)
	mb.tube(path, MeshBuilder.taper(path.size(), r, 0.0, 0.8), "fur", color, 8)


func add_cheek_tufts(color: Color, size := 1.0) -> void:
	for s: float in [-1.0, 1.0]:
		for i in 4:
			var d := Vector3(s * 0.88, -0.12 - i * 0.12, -0.3 + i * 0.07).normalized()
			var base := surf(d) * 0.93
			add_tuft(head, base, Vector3(s * 0.9, -0.2 - i * 0.14, 0.1), (0.11 - i * 0.012) * size, 0.05 * size, color, 0.015)


## Lunettes de pilote relevées sur le front.
func add_goggles(strap: Color, frame: Color, lens: Color, elev := 0.5, spread := 0.24) -> void:
	elev += 0.3
	var ring := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in 32:
		var a := TAU * i / 32.0
		var e := lerpf(elev - 0.05, 0.3, (1.0 - cos(a)) / 2.0)
		var d := Vector3(sin(a) * cos(e), sin(e), -cos(a) * cos(e))
		ring.append(surf(d) + normal_at(d) * 0.01)
		radii.append(0.024)
	head.tube(ring, radii, "plastic", strap, 8, 0.35, ring[0].normalized(), true)
	for s: float in [-1.0, 1.0]:
		var d := dir(s * spread * 0.85, sin(elev), -cos(elev))
		var n := normal_at(d)
		var c := surf(d) + n * 0.03
		var b := MeshBuilder._basis_from_dir(n)
		var frame_ring := PackedVector3Array()
		var fr := PackedFloat32Array()
		for i in 20:
			var a := TAU * i / 20.0
			frame_ring.append(c + b * Vector3(cos(a) * 0.072, sin(a) * 0.064, 0.0))
			fr.append(0.02)
		head.tube(frame_ring, fr, "chrome", frame, 8, 1.0, Vector3.ZERO, true)
		head.ellipsoid(c + n * 0.005, Vector3(0.07, 0.062, 0.024), "glass", lens, b, [], 8, 18)


# ---------------- Espèces ----------------

func _generic() -> void:
	bump(dir(0, -0.3, -1), 0.18, 9.0)
	_skull()
	add_eyes(0.4, 0.14, 0.11, Color("#6b4f2a"))
	add_nose(surf(dir(0, -0.12, -1)) + Vector3(0, 0, -0.01), "big", Color("#222222"), 0.8)
	add_mouth(surf(dir(0, -0.32, -1)), 0.06)
	add_goggles(Color("#2b2d42"), Color("#e9edf2"), Color("#ffb347"))


func _cat() -> void:
	head_r = Vector3(0.44, 0.39, 0.4)
	bump(dir(0, -0.42, -1), 0.12, 10.0)
	bump(dir(0.8, -0.35, -0.5), 0.1, 5.0)
	bump(dir(-0.8, -0.35, -0.5), 0.1, 5.0)
	bump(Vector3.UP, -0.06, 2.0)
	var stripe := fur.darkened(0.28)
	var white := snout_col
	paint_fn = func(p: Vector3) -> Color:
		var c := fur
		# rayures du front et des joues (chat tigré)
		if p.y > 0.15 and p.z < 0.25:
			for sx: float in [-0.1, 0.0, 0.1]:
				c = c.lerp(stripe, blob_mask(absf(p.x - sx * (1.0 + p.y)), 0.026, 0.01) * smoothstep(0.15, 0.24, p.y))
		if absf(p.x) > 0.3 and p.z < 0.15:
			for sy: float in [0.02, -0.08]:
				c = c.lerp(stripe, blob_mask(absf(p.y - sy - absf(p.x) * 0.15), 0.014, 0.008) * smoothstep(0.3, 0.36, absf(p.x)))
		# museau et menton clairs
		var m := blob_mask(Vector2(p.x * 0.8, p.y + 0.17).length(), 0.16, 0.05) * smoothstep(0.0, -0.2, p.z)
		return c.lerp(white, m)
	_skull()
	add_eyes(0.42, 0.13, 0.12, Color("#7ac143"), true, 0.1)
	var muzzle := surf(dir(0, -0.3, -1))
	add_pads(muzzle + Vector3(0, -0.02, 0.01), 0.055, Vector3(0.07, 0.055, 0.055), white)
	add_nose(muzzle + Vector3(0, 0.045, -0.02), "tri", Color("#ff8fa3"))
	add_mouth(muzzle + Vector3(0, -0.075, 0.0), 0.05)
	add_whiskers(muzzle + Vector3(0, -0.02, -0.01), 0.09, Color("#fffaf0"), 0.32)
	add_cheek_tufts(fur.lightened(0.05))
	for s: float in [-1.0, 1.0]:
		make_ear(head, surf(dir(s * 0.55, 0.8, -0.08)) * 0.93, Vector3(s * 0.42, 1, 0.05), Vector3(s * 0.25, 0.1, -1),
			0.3, 0.17, 0.06, "point", ear_col, Color("#ffb3c1"), Color(), 0.7)
	add_goggles(Color("#2b2d42"), Color("#e9edf2"), Color("#7fd1ff"), 0.52, 0.25)


func _dog() -> void:
	head_r = Vector3(0.41, 0.4, 0.41)
	bump(dir(0, -0.38, -1), 0.34, 7.0)
	bump(dir(0.7, -0.3, -0.6), 0.06, 4.0)
	bump(dir(-0.7, -0.3, -0.6), 0.06, 4.0)
	var light := snout_col
	var patch := ear_col
	paint_fn = func(p: Vector3) -> Color:
		var c := fur
		# museau clair
		var m := blob_mask(Vector2(p.x * 0.75, p.y + 0.14).length(), 0.19, 0.05) * smoothstep(-0.05, -0.28, p.z)
		c = c.lerp(light, m)
		# tache autour de l'œil droit
		c = c.lerp(patch.lerp(fur, 0.35), blob_mask(Vector2(p.x - 0.2, p.y - 0.16).length(), 0.1, 0.035) * smoothstep(0.0, -0.2, p.z))
		# poitrail clair
		return c.lerp(light, smoothstep(-0.2, -0.32, p.y) * 0.8)
	_skull()
	add_eyes(0.38, 0.14, 0.11, Color("#8a5a2b"))
	var muzzle := surf(dir(0, -0.25, -1))
	add_nose(muzzle + Vector3(0, 0.02, -0.03), "big", Color("#1c1c1e"), 1.1)
	# sourire et bout de langue
	add_mouth(muzzle + Vector3(0, -0.075, 0.02), 0.08, DARK_LINE, 0.04)
	var tongue := muzzle + Vector3(0.015, -0.1, 0.0)
	head.ellipsoid(tongue, Vector3(0.042, 0.055, 0.02), "skin", Color("#ff7b93"),
		Basis(Vector3.RIGHT, -0.5), [[Vector3.DOWN, 0.15, 2.0]], 10, 16)
	# oreilles tombantes (animées)
	for s: float in [-1.0, 1.0]:
		var base := surf(dir(s * 0.72, 0.55, 0.05)) * 0.96
		var em := MeshBuilder.new()
		make_ear(em, Vector3.ZERO, Vector3(s * 0.35, -1, 0.1), Vector3(-s, 0, -0.3), 0.42, 0.14, 0.05, "floppy", ear_col, ear_col.lightened(0.15), Color(), 0.3)
		out["ear_l" if s < 0.0 else "ear_r"] = em.commit()
		out["ear_l_pos" if s < 0.0 else "ear_r_pos"] = base
	add_goggles(Color("#c1121f"), Color("#e9edf2"), Color("#ffd166"), 0.52, 0.24)


func _fox() -> void:
	head_r = Vector3(0.42, 0.38, 0.4)
	bump(dir(0, -0.25, -1), 0.5, 12.0)
	bump(dir(0.85, -0.3, -0.4), 0.12, 5.0)
	bump(dir(-0.85, -0.3, -0.4), 0.12, 5.0)
	var white := snout_col
	paint_fn = func(p: Vector3) -> Color:
		# joues, menton et dessous du museau blancs
		var w := smoothstep(-0.02, -0.12, p.y - absf(p.x) * 0.25) * smoothstep(0.15, -0.05, p.z)
		w = maxf(w, smoothstep(0.3, 0.42, absf(p.x)) * smoothstep(0.02, -0.1, p.y))
		return fur.lerp(white, clampf(w, 0.0, 1.0))
	_skull()
	add_eyes(0.4, 0.12, 0.11, Color("#e8a020"), true, 0.2)
	var tip := surf(dir(0, -0.2, -1))
	add_nose(tip + Vector3(0, 0.0, 0.0), "big", Color("#141414"), 0.62)
	add_mouth(tip + Vector3(0, -0.07, 0.07), 0.05)
	add_whiskers(tip + Vector3(0, -0.04, 0.08), 0.06, Color("#2b2b2b"), 0.26)
	add_cheek_tufts(white, 1.25)
	for s: float in [-1.0, 1.0]:
		make_ear(head, surf(dir(s * 0.5, 0.82, 0.0)) * 0.93, Vector3(s * 0.35, 1, 0.08), Vector3(s * 0.2, 0.1, -1),
			0.36, 0.17, 0.06, "point", fur, Color("#fff3e6"), Color("#2b1d16"), 0.65)
	add_goggles(Color("#264653"), Color("#e9edf2"), Color("#90e0ef"), 0.5, 0.24)


func _bear() -> void:
	head_r = Vector3(0.45, 0.41, 0.42)
	bump(dir(0, -0.35, -1), 0.24, 8.0)
	bump(dir(0.75, -0.3, -0.5), 0.08, 4.0)
	bump(dir(-0.75, -0.3, -0.5), 0.08, 4.0)
	var light := snout_col
	paint_fn = func(p: Vector3) -> Color:
		var m := blob_mask(Vector2(p.x * 0.8, p.y + 0.15).length(), 0.17, 0.04) * smoothstep(-0.05, -0.28, p.z)
		return fur.lerp(light, m)
	_skull()
	add_eyes(0.36, 0.14, 0.095, Color("#5a3a20"))
	var muzzle := surf(dir(0, -0.26, -1))
	add_nose(muzzle + Vector3(0, 0.03, -0.02), "big", Color("#1a1210"), 1.0)
	add_mouth(muzzle + Vector3(0, -0.07, 0.02), 0.06, DARK_LINE, 0.03)
	for s: float in [-1.0, 1.0]:
		make_ear(head, surf(dir(s * 0.68, 0.7, 0.05)) * 0.95, Vector3(s * 0.6, 1, 0.1), Vector3(s * 0.2, 0, -1),
			0.17, 0.13, 0.06, "round", ear_col, light, Color(), 0.7)
	add_goggles(Color("#3d405b"), Color("#f2cc8f"), Color("#81b29a"), 0.5, 0.24)


func _rabbit() -> void:
	head_r = Vector3(0.4, 0.42, 0.4)
	bump(dir(0, -0.4, -1), 0.14, 9.0)
	bump(dir(0.75, -0.35, -0.55), 0.1, 5.0)
	bump(dir(-0.75, -0.35, -0.55), 0.1, 5.0)
	_skull()
	add_cheeks(Color("#ffc2d1"), 0.6, -0.14, 0.065)
	add_eyes(0.43, 0.14, 0.12, Color("#7b5ea7"))
	var muzzle := surf(dir(0, -0.3, -1))
	add_pads(muzzle + Vector3(0, -0.02, 0.01), 0.05, Vector3(0.065, 0.055, 0.05), Color.WHITE)
	add_nose(muzzle + Vector3(0, 0.04, -0.015), "tri", Color("#ff8fab"), 0.8)
	for s: float in [-1.0, 1.0]:
		head.rbox(muzzle + Vector3(s * 0.017, -0.085, 0.01), Vector3(0.016, 0.03, 0.008), "gloss", Color.WHITE, Basis(), 0.4, 6, 12)
	add_mouth(muzzle + Vector3(0, -0.06, 0.0), 0.045)
	add_whiskers(muzzle + Vector3(0, -0.02, -0.01), 0.08, Color("#8d8d99"), 0.3)
	# grandes oreilles (animées) ; une est pliée au bout
	for s: float in [-1.0, 1.0]:
		var base := surf(dir(s * 0.28, 1, 0.05)) * 0.95
		var em := MeshBuilder.new()
		make_ear(em, Vector3.ZERO, Vector3(s * 0.18, 1, 0.12), Vector3(0, 0.05, -1), 0.72, 0.13, 0.055, "long",
			ear_col, Color("#ffb3c6"), Color(), 0.65, 0.18 if s > 0.0 else 0.04)
		out["ear_l" if s < 0.0 else "ear_r"] = em.commit()
		out["ear_l_pos" if s < 0.0 else "ear_r_pos"] = base
	add_goggles(Color("#457b9d"), Color("#e9edf2"), Color("#ffafcc"), 0.48, 0.24)


func _mouse() -> void:
	head_r = Vector3(0.38, 0.37, 0.4)
	bump(dir(0, -0.3, -1), 0.45, 9.0)
	bump(dir(0.7, -0.3, -0.6), 0.06, 4.0)
	bump(dir(-0.7, -0.3, -0.6), 0.06, 4.0)
	var light := snout_col
	paint_fn = func(p: Vector3) -> Color:
		var m := smoothstep(-0.05, -0.2, p.y) * smoothstep(0.1, -0.15, p.z)
		return fur.lerp(light, m * 0.85)
	_skull()
	add_eyes(0.42, 0.16, 0.105, Color("#4a4458"))
	var tip := surf(dir(0, -0.25, -1))
	add_nose(tip + Vector3(0, 0.01, 0.0), "button", Color("#ff8fab"), 0.95)
	add_mouth(tip + Vector3(0, -0.07, 0.08), 0.04)
	add_whiskers(tip + Vector3(0, -0.02, 0.08), 0.05, Color("#3b3b45"), 0.34)
	for s: float in [-1.0, 1.0]:
		make_ear(head, surf(dir(s * 0.62, 0.72, 0.1)) * 0.92, Vector3(s * 0.65, 1, 0.12), Vector3(s * 0.15, 0, -1),
			0.36, 0.2, 0.04, "round", ear_col, Color("#ffb3c6"), Color(), 0.75)
	add_goggles(Color("#ef476f"), Color("#e9edf2"), Color("#06d6a0"), 0.46, 0.22)


func _lion() -> void:
	head_r = Vector3(0.42, 0.4, 0.41)
	bump(dir(0, -0.4, -1), 0.16, 9.0)
	bump(dir(0.7, -0.3, -0.6), 0.08, 4.0)
	bump(dir(-0.7, -0.3, -0.6), 0.08, 4.0)
	var light := snout_col
	paint_fn = func(p: Vector3) -> Color:
		var m := blob_mask(Vector2(p.x * 0.8, p.y + 0.17).length(), 0.16, 0.05) * smoothstep(0.0, -0.2, p.z)
		return fur.lerp(light, m)
	_skull()
	add_eyes(0.4, 0.14, 0.11, Color("#c98a1b"), false, 0.12)
	var muzzle := surf(dir(0, -0.3, -1))
	add_pads(muzzle + Vector3(0, -0.02, 0.01), 0.058, Vector3(0.075, 0.058, 0.055), light)
	add_nose(muzzle + Vector3(0, 0.05, -0.02), "tri", Color("#8a4b2d"), 1.2)
	add_mouth(muzzle + Vector3(0, -0.08, 0.0), 0.055)
	add_whiskers(muzzle + Vector3(0, -0.02, -0.01), 0.095, Color("#fff8e7"), 0.3)
	# crinière : trois couronnes de mèches autour du visage
	var mane_dark := Color("#9c4f16")
	var mane_light := Color("#d9822b")
	var mane_paint := func(p: Vector3) -> Color:
		return mane_dark.lerp(mane_light, clampf((p.length() - 0.38) / 0.3, 0.0, 1.0))
	var rings := [[22, 0.12, 0.2, 0.08], [20, 0.4, 0.26, 0.09], [16, 0.75, 0.24, 0.085]]
	for ri in rings.size():
		var cfg: Array = rings[ri]
		var count: int = cfg[0]
		for i in count:
			var a := TAU * (i + 0.5 * ri) / count
			var d := Vector3(cos(a) * 0.95, sin(a) * 0.95, float(cfg[1])).normalized()
			var base := surf(d) * 0.88
			var out_dir := (d + Vector3(0, -0.15, 0.25)).normalized()
			add_tuft(head, base, out_dir, float(cfg[2]) * (0.9 + 0.2 * sin(i * 2.3)), float(cfg[3]), mane_paint, 0.05)
	for s: float in [-1.0, 1.0]:
		make_ear(head, surf(dir(s * 0.62, 0.72, -0.05)) * 0.97, Vector3(s * 0.55, 1, 0.0), Vector3(s * 0.2, 0, -1),
			0.15, 0.12, 0.05, "round", fur, Color("#8a5a2b"), Color(), 0.7)
	add_goggles(Color("#6a040f"), Color("#ffd60a"), Color("#ff9f1c"), 0.5, 0.24)


func _panda() -> void:
	head_r = Vector3(0.45, 0.41, 0.41)
	bump(dir(0, -0.4, -1), 0.14, 9.0)
	bump(dir(0.8, -0.3, -0.5), 0.1, 4.0)
	bump(dir(-0.8, -0.3, -0.5), 0.1, 4.0)
	var black := ear_col
	paint_fn = func(p: Vector3) -> Color:
		var c := fur
		# taches autour des yeux, en goutte inclinée
		for s: float in [-1.0, 1.0]:
			var q := Vector2(p.x - s * 0.16, p.y - 0.06)
			q = q.rotated(s * 0.5)
			var m := blob_mask(Vector2(q.x / 1.25, q.y).length(), 0.1, 0.02) * smoothstep(0.05, -0.15, p.z)
			c = c.lerp(black, m)
		return c
	_skull()
	add_eyes(0.38, 0.12, 0.1, Color("#5a3a20"))
	var muzzle := surf(dir(0, -0.32, -1))
	add_nose(muzzle + Vector3(0, 0.035, -0.02), "big", Color("#141414"), 0.85)
	add_mouth(muzzle + Vector3(0, -0.06, 0.01), 0.055)
	for s: float in [-1.0, 1.0]:
		make_ear(head, surf(dir(s * 0.7, 0.68, 0.05)) * 0.95, Vector3(s * 0.6, 1, 0.1), Vector3(s * 0.2, 0, -1),
			0.17, 0.14, 0.07, "round", black, black.lightened(0.12), Color(), 0.5)
	add_goggles(Color("#2a9d8f"), Color("#e9edf2"), Color("#e9c46a"), 0.5, 0.25)


func _unicorn() -> void:
	head_r = Vector3(0.37, 0.42, 0.4)
	bump(dir(0, -0.55, -1), 0.62, 6.0)
	bump(dir(0.6, -0.4, -0.7), 0.08, 4.0)
	bump(dir(-0.6, -0.4, -0.7), 0.08, 4.0)
	bump(dir(0, -1, -0.2), -0.08, 2.0)
	var pink := snout_col
	paint_fn = func(p: Vector3) -> Color:
		return fur.lerp(pink, smoothstep(-0.42, -0.58, p.z) * smoothstep(-0.05, -0.2, p.y))
	_skull()
	add_cheeks(Color("#ffb3d9"), 0.66, -0.06, 0.065)
	add_eyes(0.44, 0.16, 0.12, Color("#9b5de5"))
	# cils
	for s: float in [-1.0, 1.0]:
		var c: Vector3 = eye_centers[eye_centers.size() - (2 if s < 0.0 else 1)]
		for i in 3:
			var a := (0.35 + i * 0.3) * s
			var base := c + Vector3(s * 0.04 + sin(a) * 0.1, 0.1, -0.05)
			head.tube(MeshBuilder.smooth_path(PackedVector3Array([base, base + Vector3(s * 0.04, 0.03, -0.01), base + Vector3(s * 0.07, 0.02, 0.0)]), 2),
				MeshBuilder.taper(5, 0.008, 0.003), "plastic", Color("#2b2033"), 5)
	# naseaux
	var snout := surf(dir(0, -0.55, -1))
	for s: float in [-1.0, 1.0]:
		head.ellipsoid(snout + Vector3(s * 0.055, 0.03, 0.01), Vector3(0.022, 0.03, 0.015), "skin", Color("#c9184a"), Basis(), [], 8, 12)
	add_mouth(snout + Vector3(0, -0.07, 0.06), 0.06)
	# corne torsadée dorée
	var horn_base := surf(dir(0, 0.82, -0.55)) * 0.95
	var hb := MeshBuilder._basis_from_dir(Vector3(0, 0.9, -0.45))
	var horn_t := Transform3D(Basis(hb.x, hb.z, -hb.y), horn_base)
	var spiral := func(th: float, y: float) -> float:
		return 0.012 * sin(th * 2.0 + y * 38.0) * (1.0 - y / 0.48)
	head.lathe(PackedVector2Array([Vector2(0.075, -0.05), Vector2(0.07, 0.0), Vector2(0.05, 0.16), Vector2(0.03, 0.32), Vector2(0.008, 0.46), Vector2(0.0, 0.48)]),
		"skin", Color("#ffe08a"), horn_t, 24, spiral)
	# crinière arc-en-ciel : mèche sur le front et le long de la nuque
	var rainbow := [Color("#ff70a6"), Color("#ff9770"), Color("#ffd670"), Color("#70d6ff"), Color("#b388eb")]
	for i in 16:
		var t := -0.1 + i * 0.17
		var side := 0.16 * sin(i * 1.7)
		var d := Vector3(side, cos(t), sin(t)).normalized()
		var base := surf(d) * 0.92
		var flow := (d + Vector3(side * 2.0, -0.5, 0.9) * (0.3 + 0.08 * i)).normalized()
		add_tuft(head, base, flow, 0.26 + 0.03 * (i % 3), 0.075, rainbow[i % rainbow.size()], 0.08)
	# toupet sur le front, entre les oreilles
	for i in 3:
		var base := surf(dir(-0.12 + i * 0.12, 0.92, -0.25)) * 0.95
		add_tuft(head, base, Vector3(-0.3 + i * 0.3, 0.2, -1.0), 0.2, 0.06, rainbow[(i + 1) % rainbow.size()], 0.12)
	for s: float in [-1.0, 1.0]:
		make_ear(head, surf(dir(s * 0.42, 0.85, 0.12)) * 0.94, Vector3(s * 0.3, 1, 0.1), Vector3(s * 0.3, 0.1, -1),
			0.26, 0.11, 0.05, "point", fur, Color("#ffc8dd"), Color(), 0.6)


func _penguin() -> void:
	head_r = Vector3(0.42, 0.42, 0.41)
	var white := Color("#fbfbfb")
	paint_fn = func(p: Vector3) -> Color:
		# masque blanc en cœur
		var m := 0.0
		for s: float in [-1.0, 1.0]:
			m = maxf(m, blob_mask(Vector2(p.x - s * 0.14, p.y - 0.02).length(), 0.17, 0.03))
		m = maxf(m, blob_mask(Vector2(p.x * 0.8, p.y + 0.16).length(), 0.24, 0.03))
		return fur.lerp(white, m * smoothstep(0.02, -0.18, p.z))
	_skull()
	add_eyes(0.36, 0.1, 0.105, Color("#5a4030"))
	var beak := surf(dir(0, -0.12, -1))
	head.ellipsoid(beak + Vector3(0, 0.0, -0.04), Vector3(0.075, 0.04, 0.12), "plastic", Color("#ffa630"), Basis(),
		[[Vector3.FORWARD, 0.6, 3.0]], 12, 18)
	head.ellipsoid(beak + Vector3(0, -0.04, -0.02), Vector3(0.06, 0.028, 0.09), "plastic", Color("#ff7f11"), Basis(),
		[[Vector3.FORWARD, 0.5, 3.0]], 10, 16)
	add_blush_paint_only()
	# petite houppette
	for i in 3:
		add_tuft(head, surf(dir(0.02 * i, 1, 0.05)) * 0.95, Vector3(-0.1 + i * 0.1, 1, 0.3), 0.12, 0.03, fur, 0.02)
	add_goggles(Color("#0077b6"), Color("#e9edf2"), Color("#90e0ef"), 0.55, 0.25)


func _frog() -> void:
	head_r = Vector3(0.5, 0.33, 0.43)
	bump(dir(0, 1, 0), -0.08, 2.0)
	bump(dir(0, -0.2, -1), 0.05, 4.0)
	var belly := fur.lightened(0.45)
	var spot := fur.darkened(0.25)
	paint_fn = func(p: Vector3) -> Color:
		var c := fur.lerp(belly, smoothstep(-0.08, -0.22, p.y))
		var spots: Array[Vector3] = [Vector3(0.12, 0.3, 0.1), Vector3(-0.2, 0.26, 0.2), Vector3(0.28, 0.2, 0.25), Vector3(-0.05, 0.28, 0.3)]
		for sp in spots:
			c = c.lerp(spot, blob_mask(p.distance_to(sp), 0.05, 0.02))
		return c
	_skull("skin", 26, 40)
	add_cheeks(Color("#ff9eb5"), 0.7, -0.05, 0.07)
	# yeux sur deux bosses
	for s: float in [-1.0, 1.0]:
		var m := Vector3(s * 0.22, 0.24, -0.12)
		head.ellipsoid(m, Vector3(0.17, 0.15, 0.16), "skin", fur, Basis(), [], 14, 20)
		add_eye_at(m + Vector3(s * 0.01, 0.06, -0.06), 0.12, Color("#c9a227"), false, 0.0, fur, Color("#24331c"), s, 0.3)
	# grand sourire
	var pts := PackedVector3Array()
	for i in 11:
		var t := -1.0 + 2.0 * i / 10.0
		pts.append(on_head(Vector3(t * 0.4, -0.06 - (1.0 - t * t) * 0.05, -0.3 + absf(t) * 0.2), 0.002))
	head.tube(MeshBuilder.smooth_path(pts, 2), MeshBuilder.taper(21, 0.011, 0.011), "skin", Color("#7a1f2b"), 6)
	for s: float in [-1.0, 1.0]:
		head.sphere(on_head(Vector3(s * 0.05, 0.05, -0.42), 0.0), 0.012, "matte", Color("#1c2a14"), 5, 8)


func _turtle() -> void:
	head_r = Vector3(0.36, 0.36, 0.42)
	bump(dir(0, -0.2, -1), 0.14, 6.0)
	var spot := fur.darkened(0.2)
	paint_fn = func(p: Vector3) -> Color:
		var c := fur.lerp(fur.lightened(0.35), smoothstep(-0.1, -0.25, p.y))
		var spots: Array[Vector3] = [Vector3(0.1, 0.32, -0.05), Vector3(-0.12, 0.3, 0.08), Vector3(0.02, 0.28, 0.22)]
		for sp in spots:
			c = c.lerp(spot, blob_mask(p.distance_to(sp), 0.045, 0.02))
		return c
	_skull("skin", 26, 40)
	add_eyes(0.4, 0.16, 0.105, Color("#4a2c12"), false, 0.32, fur.darkened(0.08))
	var tip := surf(dir(0, -0.15, -1))
	for s: float in [-1.0, 1.0]:
		head.sphere(tip + Vector3(s * 0.04, 0.04, 0.0), 0.012, "matte", Color("#1c2a14"), 5, 8)
	add_mouth(tip + Vector3(0, -0.08, 0.05), 0.11, Color("#2f3d1f"), 0.05)
	add_goggles(Color("#e76f51"), Color("#e9edf2"), Color("#f4a261"), 0.48, 0.23)


func _monkey() -> void:
	head_r = Vector3(0.42, 0.4, 0.4)
	bump(dir(0, -0.4, -1), 0.2, 8.0)
	var face := ear_col
	paint_fn = func(p: Vector3) -> Color:
		var m := 0.0
		for s: float in [-1.0, 1.0]:
			m = maxf(m, blob_mask(Vector2(p.x - s * 0.13, p.y - 0.05).length(), 0.16, 0.02))
		m = maxf(m, blob_mask(Vector2(p.x * 0.8, p.y + 0.15).length(), 0.22, 0.02))
		return fur.lerp(face, m * smoothstep(0.05, -0.15, p.z))
	_skull()
	add_eyes(0.32, 0.1, 0.105, Color("#6a4520"))
	var muzzle := surf(dir(0, -0.3, -1))
	for s: float in [-1.0, 1.0]:
		head.ellipsoid(muzzle + Vector3(s * 0.025, 0.04, -0.005), Vector3(0.014, 0.01, 0.01), "matte", Color("#3a2414"), Basis(), [], 6, 10)
	add_mouth(muzzle + Vector3(0, -0.05, 0.0), 0.09, DARK_LINE, 0.05)
	for s: float in [-1.0, 1.0]:
		make_ear(head, surf(dir(s, 0.05, 0.05)) * 0.92, Vector3(s, 0.15, 0.05), Vector3(s * 1, 0.1, -0.6),
			0.2, 0.16, 0.06, "round", fur, face, Color(), 0.75)
	for i in 3:
		add_tuft(head, surf(dir(-0.05 + 0.05 * i, 1, -0.1)) * 0.95, Vector3(-0.2 + 0.2 * i, 1, -0.4), 0.13, 0.035, fur, -0.02)
	add_goggles(Color("#2a9d8f"), Color("#e9edf2"), Color("#ffd166"), 0.55, 0.24)


## Joues roses dessinées dans la couleur de la tête (pingouin).
func add_blush_paint_only() -> void:
	for s: float in [-1.0, 1.0]:
		var d := dir(s * 0.58, -0.08, -0.8)
		head.cap(Vector3.ZERO, surf(d).length() + 0.003, d, 0.09, "fur", Color("#ffadc6"), 3, 14)


# ---------------- Corps, écharpe, queue ----------------

## Corps du pilote : combinaison (couleur du t-shirt), bras jusqu'au volant,
## pattes, cou et col.
func _driver() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var acc := KartModel.accent(shirt)
	var kc := info.kart_color
	var belly := species == "penguin"
	var suit := func(p: Vector3) -> Color:
		var c := shirt
		# bandes sur les côtés, fermeture éclair, écusson
		if absf(p.x) > 0.25:
			c = kc if kc.get_luminance() < 0.85 and kc != shirt else acc
		if belly and p.z < 0.15:
			c = c.lerp(Color("#fbfbfb"), blob_mask(Vector2(p.x * 1.1, p.y - 0.95).length(), 0.24, 0.04))
		return c
	mb.ellipsoid(TORSO_CENTER, TORSO_RADII, "cloth", suit, TORSO_BASIS, TORSO_BUMPS, 18, 28)
	# écusson sur la poitrine
	if not belly:
		var d := Vector3(0.42, 0.36, -0.83).normalized()
		var badge := torso_point(d)
		var bb := MeshBuilder._basis_from_dir(TORSO_BASIS * Vector3(d.x / 0.31, d.y / 0.37, d.z / 0.25).normalized())
		mb.ellipsoid(badge, Vector3(0.055, 0.055, 0.018), "plastic", acc, bb, [], 8, 16)
		mb.ellipsoid(badge + bb.z * 0.012, Vector3(0.033, 0.033, 0.01), "paint", kc, bb, [], 6, 14)
	# jambes (cuisses et genoux sous le volant)
	var pants := shirt.darkened(0.45)
	for s: float in [-1.0, 1.0]:
		var leg := MeshBuilder.smooth_path(PackedVector3Array([
			Vector3(s * 0.14, 0.56, 0.18), Vector3(s * 0.17, 0.66, -0.3), Vector3(s * 0.15, 0.5, -0.75)]), 4)
		mb.tube(leg, MeshBuilder.taper(leg.size(), 0.12, 0.09), "cloth", pants, 12)
	# cou et col
	mb.tube(PackedVector3Array([Vector3(0, 1.26, 0.27), Vector3(0, 1.5, 0.22)]), PackedFloat32Array([0.14, 0.12]), "fur", fur, 14)
	# écharpe autour du cou
	var scarf_col := _scarf_color()
	var scarf := PackedVector3Array()
	var sr := PackedFloat32Array()
	for i in 20:
		var a := TAU * i / 20.0
		scarf.append(Vector3(cos(a) * 0.155, 1.36 + sin(a) * 0.012, 0.25 + sin(a) * 0.145))
		sr.append(0.06)
	mb.tube(scarf, sr, "felt", scarf_col, 8, 0.6, Vector3.RIGHT, true)
	mb.ellipsoid(Vector3(0.0, 1.35, 0.4), Vector3(0.075, 0.065, 0.05), "felt", scarf_col.darkened(0.1), Basis(), [], 8, 12)
	# bras et pattes sur le volant
	var wheel := Basis(Vector3.RIGHT, deg_to_rad(KartModel.STEERING_TILT))
	for s: float in [-1.0, 1.0]:
		var grip := KartModel.STEERING + wheel * Vector3(s * PAW_GRIP, 0.1, 0.0)
		var shoulder := Vector3(s * 0.29, 1.17, 0.26)
		var elbow := Vector3(s * 0.4, 0.93, 0.02)
		var wrist := grip + Vector3(s * 0.02, -0.01, 0.1)
		if species == "penguin":
			var flip := MeshBuilder.smooth_path(PackedVector3Array([shoulder, elbow, grip]), 4)
			mb.tube(flip, MeshBuilder.taper(flip.size(), 0.1, 0.05), "fur", fur, 12, 0.45, Vector3(s, 0, 0))
			continue
		var arm := MeshBuilder.smooth_path(PackedVector3Array([shoulder, elbow, wrist]), 4)
		mb.tube(arm, MeshBuilder.taper(arm.size(), 0.1, 0.078), "cloth", shirt, 12)
		mb.tube(PackedVector3Array([wrist + Vector3(0, 0, 0.02), wrist - Vector3(0, 0, 0.03)]), PackedFloat32Array([0.085, 0.085]), "cloth", acc, 12)
		var paw := ear_col if species == "panda" else fur
		mb.ellipsoid(grip + Vector3(0, 0.005, 0.0), Vector3(0.075, 0.065, 0.085), "fur", paw, Basis(), [], 10, 16)
		mb.sphere(grip + Vector3(-s * 0.045, 0.045, 0.02), 0.032, "fur", paw, 6, 10)
	# carapace de la tortue
	if species == "turtle":
		_shell(mb)
	return mb.commit()


## Point de la surface du torse (direction dans le repère du torse).
static func torso_point(d: Vector3) -> Vector3:
	d = d.normalized()
	var k := 1.0
	for b in TORSO_BUMPS:
		var bd: Vector3 = b[0]
		var dt := d.dot(bd)
		if dt > 0.0:
			k += float(b[1]) * pow(dt, float(b[2]))
	return TORSO_CENTER + TORSO_BASIS * (d * k * TORSO_RADII)


func _scarf_color() -> Color:
	var kc := info.kart_color
	if absf(kc.h - shirt.h) < 0.08 and absf(kc.v - shirt.v) < 0.2:
		return KartModel.accent(kc)
	return kc


## Pan de l'écharpe qui flotte derrière le pilote (animé).
func _scarf() -> void:
	var mb := MeshBuilder.new()
	var col := _scarf_color()
	var stripes := col.lightened(0.45)
	var path := MeshBuilder.smooth_path(PackedVector3Array([
		Vector3(0, 0, 0), Vector3(0.05, -0.04, 0.18), Vector3(0.1, -0.12, 0.36), Vector3(0.14, -0.16, 0.52)]), 4)
	var striped := func(p: Vector3) -> Color:
		return stripes if fmod(p.z + 1.0, 0.16) < 0.05 else col
	mb.tube(path, MeshBuilder.taper(path.size(), 0.07, 0.085), "felt", striped, 8, 0.28, Vector3.UP)
	out["scarf"] = mb.commit()
	out["scarf_pos"] = NECK_BACK + Vector3(0, 0, 0.02)


## Queue (animée) : chat, chien, renard, lion, singe, souris, lapin, licorne, ours.
func _tail() -> void:
	var mb := MeshBuilder.new()
	var pos := Vector3(0.16, 0.62, 0.62)
	match species:
		"cat", "generic":
			var stripe := fur.darkened(0.25)
			var path := MeshBuilder.smooth_path(PackedVector3Array([Vector3.ZERO, Vector3(0.08, 0.15, 0.12), Vector3(0.12, 0.42, 0.2), Vector3(0.05, 0.62, 0.18), Vector3(-0.04, 0.68, 0.1)]), 5)
			var cat_paint := func(p: Vector3) -> Color:
				return stripe if species == "cat" and fmod(p.y + 1.0, 0.14) < 0.045 else fur
			mb.tube(path, MeshBuilder.taper(path.size(), 0.055, 0.045), "fur", cat_paint, 10)
		"dog":
			var path := MeshBuilder.smooth_path(PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.12, 0.1), Vector3(0.0, 0.3, 0.12)]), 4)
			mb.tube(path, MeshBuilder.taper(path.size(), 0.06, 0.035), "fur", fur, 10)
			pos = Vector3(0.0, 0.62, 0.62)
		"fox":
			var white := snout_col
			var path := MeshBuilder.smooth_path(PackedVector3Array([Vector3.ZERO, Vector3(0.12, 0.06, 0.18), Vector3(0.3, 0.12, 0.34), Vector3(0.42, 0.28, 0.42)]), 6)
			var radii := PackedFloat32Array()
			for i in path.size():
				var t := float(i) / (path.size() - 1)
				radii.append(0.06 + sin(t * PI * 0.92) * 0.13)
			var fox_paint := func(p: Vector3) -> Color:
				return fur.lerp(white, smoothstep(0.32, 0.4, p.x + p.y * 0.3))
			mb.tube(path, radii, "fur", fox_paint, 14)
			pos = Vector3(0.2, 0.55, 0.62)
		"lion":
			var path := MeshBuilder.smooth_path(PackedVector3Array([Vector3.ZERO, Vector3(0.1, 0.05, 0.2), Vector3(0.2, 0.25, 0.3), Vector3(0.18, 0.45, 0.28)]), 5)
			mb.tube(path, MeshBuilder.taper(path.size(), 0.04, 0.03), "fur", fur, 10)
			mb.ellipsoid(Vector3(0.18, 0.5, 0.28), Vector3(0.07, 0.1, 0.07), "fur", Color("#8c4a14"), Basis(), [[Vector3.UP, 0.4, 3.0]], 10, 14)
		"monkey":
			var pts := PackedVector3Array()
			for i in 12:
				var t := float(i) / 11.0
				var a := t * 4.2
				var rad := 0.2 * (1.0 - t * 0.6)
				pts.append(Vector3(0.05 + t * 0.15, t * 0.5 + sin(a) * rad * 0.6, 0.15 + cos(a) * rad - 0.15))
			mb.tube(MeshBuilder.smooth_path(pts, 2), MeshBuilder.taper(23, 0.045, 0.03), "fur", fur, 10)
		"mouse":
			var path := MeshBuilder.smooth_path(PackedVector3Array([Vector3.ZERO, Vector3(0.1, 0.0, 0.25), Vector3(0.3, 0.1, 0.4), Vector3(0.45, 0.3, 0.35), Vector3(0.4, 0.45, 0.2)]), 5)
			mb.tube(path, MeshBuilder.taper(path.size(), 0.03, 0.01), "skin", Color("#f4a6b8"), 8)
		"rabbit":
			mb.ellipsoid(Vector3.ZERO, Vector3(0.12, 0.12, 0.12), "fur", Color.WHITE, Basis(),
				[[dir(1, 0.5, 0.3), 0.15, 8.0], [dir(-0.6, 0.8, 0.4), 0.15, 8.0], [dir(0.2, -0.5, 1), 0.15, 8.0], [dir(-0.5, -0.3, 0.8), 0.12, 8.0]], 12, 18)
			pos = Vector3(0.0, 0.66, 0.6)
		"bear", "panda":
			mb.sphere(Vector3.ZERO, 0.08, "fur", fur if species == "bear" else info.ear_color, 8, 12)
			pos = Vector3(0.0, 0.6, 0.6)
		"unicorn":
			var rainbow := [Color("#ff70a6"), Color("#ffd670"), Color("#70d6ff"), Color("#b388eb")]
			for i in 7:
				var a := -0.5 + i * 0.17
				var d := Vector3(sin(a) * 0.6, 0.3, 1.0).normalized()
				add_tuft(mb, Vector3.ZERO, d, 0.4 + 0.05 * (i % 2), 0.06, rainbow[i % rainbow.size()], 0.22)
			pos = Vector3(0.0, 0.7, 0.62)
		_:
			return
	out["tail"] = mb.commit()
	out["tail_pos"] = pos


## Carapace sur le dos (tortue) : écailles dessinées, bord clair.
func _shell(mb: MeshBuilder) -> void:
	var shell := Color("#6b8e23")
	var groove := Color("#3d4f1a")
	var rim := Color("#d4a937")
	var centers: Array[Vector2] = [Vector2(0, 0)]
	for i in 6:
		var a := TAU * i / 6.0
		centers.append(Vector2(cos(a), sin(a)) * 0.2)
	var shell_paint := func(p: Vector3) -> Color:
		var q := Vector2(p.x, p.y - 1.0)
		var r := Vector2(q.x / 0.42, q.y / 0.4).length()
		if r > 0.82:
			return rim
		var d1 := INF
		var d2 := INF
		for c in centers:
			var d := q.distance_to(c)
			if d < d1:
				d2 = d1
				d1 = d
			elif d < d2:
				d2 = d
		return groove if d2 - d1 < 0.018 else shell.lightened(0.12 * (1.0 - r))
	mb.ellipsoid(Vector3(0, 1.0, 0.5), Vector3(0.42, 0.4, 0.2), "skin", shell_paint, Basis(),
		[[Vector3.BACK, 0.25, 2.0]], 16, 28)
