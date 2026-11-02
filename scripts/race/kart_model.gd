@tool
class_name KartModel
extends RefCounted
## Maillages d'un kart et de son pilote, fabriqués avec MeshBuilder (formes
## lisses, couleurs peintes) et gardés en mémoire : chaque personnage n'est
## construit qu'une fois, même si la course est relancée.
##
## Repère du kart : sol à y = 0, avant vers -Z, droite vers +X.

const WHEEL_R_REAR := 0.36
const WHEEL_R_FRONT := 0.3
const REAR_WHEEL := Vector3(0.8, 0.36, 0.72)
const FRONT_WHEEL := Vector3(0.77, 0.3, -0.8)
## Centre du volant (son axe est incliné vers le pilote).
const STEERING := Vector3(0.0, 0.98, -0.42)
const STEERING_TILT := -38.0
## Plaque du numéro, sur le nez (et la pente du nez à cet endroit, en degrés).
const PLATE := Vector3(0.0, 0.533, -1.18)
const PLATE_SLOPE := 16.7
## Sorties des pots d'échappement (flammes du turbo).
const EXHAUSTS: Array[Vector3] = [Vector3(-0.22, 0.66, 1.56), Vector3(0.22, 0.66, 1.56)]

const DARK := Color("#26282f")
const SEAT := Color("#30333c")
const CHROME := Color("#e9edf2")
const METAL := Color("#8e97a4")
const WHITE := Color("#f6f6f2")
const TIRE := Color("#1d1e22")

static var _cache := {}


## Maillages du personnage (construits à la première demande) :
## chassis, wheel_rear, wheel_front, steering, et ceux du pilote (AnimalModel).
static func get_meshes(info: CharacterData) -> Dictionary:
	var key := JSON.stringify(info.to_dict())
	if not _cache.has(key):
		var m := {
			"chassis": _chassis(info),
			"wheel_rear": _wheel(WHEEL_R_REAR, 0.36, info),
			"wheel_front": _wheel(WHEEL_R_FRONT, 0.28, info),
			"steering": _steering(info),
		}
		m.merge(AnimalModel.build(info))
		_cache[key] = m
	return _cache[key]


static func clear_cache() -> void:
	_cache.clear()


## Couleur d'accent du kart (rayures, liserés) : blanc, ou presque noir sur un kart clair.
static func accent(kc: Color) -> Color:
	return WHITE if kc.get_luminance() < 0.72 else Color("#2b2d42")


static func _chassis(info: CharacterData) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var kc: Color = info.kart_color
	var acc := accent(kc)
	var low := kc.darkened(0.22)

	# Nez : carénage arrondi qui monte vers le volant, deux fines rayures au milieu.
	var nose_paint := func(p: Vector3) -> Color:
		var ax := absf(p.x)
		if p.y > 0.36 and ax > 0.045 and ax < 0.1:
			return acc
		return kc if p.y > 0.25 else low
	mb.loft([
		[-1.56, 0.5, 0.09, 0.3, 3.0],
		[-1.4, 0.6, 0.14, 0.32, 3.2],
		[-1.1, 0.58, 0.18, 0.37, 3.4],
		[-0.8, 0.5, 0.21, 0.43, 3.4],
		[-0.5, 0.42, 0.22, 0.47, 3.2],
		[-0.3, 0.36, 0.18, 0.47, 3.0],
	], "paint", nose_paint, 32, 0.1, 0.06)
	# Aileron avant et ses dérives
	mb.rbox(Vector3(0, 0.2, -1.66), Vector3(0.86, 0.045, 0.13), "plastic", DARK, Basis(), 0.3)
	for s in [-1.0, 1.0]:
		mb.rbox(Vector3(s * 0.86, 0.24, -1.66), Vector3(0.03, 0.1, 0.16), "paint", kc, Basis(), 0.35)
	# Phares
	for s in [-1.0, 1.0]:
		mb.ellipsoid(Vector3(s * 0.33, 0.36, -1.5), Vector3(0.075, 0.05, 0.05), "glass", Color("#fff3c4"), Basis(Vector3.UP, s * 0.35))
	# Plaque du numéro
	mb.rbox(PLATE, Vector3(0.17, 0.014, 0.13), "plastic", WHITE, Basis(Vector3.RIGHT, -deg_to_rad(PLATE_SLOPE)), 0.3)

	# Pontons latéraux avec une bande
	var pod_paint := func(p: Vector3) -> Color:
		return acc if absf(p.y - 0.4) < 0.025 else kc
	for s in [-1.0, 1.0]:
		mb.push(Transform3D(Basis(), Vector3(s * 0.5, 0, 0)))
		mb.loft([
			[-0.45, 0.1, 0.1, 0.36, 3.0],
			[-0.2, 0.15, 0.15, 0.38, 3.2],
			[0.05, 0.16, 0.16, 0.38, 3.2],
			[0.22, 0.13, 0.12, 0.36, 3.0],
		], "paint", pod_paint, 24, 0.06, 0.06)
		mb.pop()
	# Plancher
	mb.rbox(Vector3(0, 0.17, -0.05), Vector3(0.48, 0.04, 1.25), "plastic", DARK, Basis(), 0.3, 10, 24)

	# Siège baquet
	mb.rbox(Vector3(0, 0.43, 0.22), Vector3(0.32, 0.06, 0.26), "plastic", SEAT, Basis(), 0.35)
	mb.rbox(Vector3(0, 0.8, 0.5), Vector3(0.36, 0.36, 0.07), "plastic", SEAT, Basis(Vector3.RIGHT, deg_to_rad(14.0)), 0.3)
	for s in [-1.0, 1.0]:
		mb.rbox(Vector3(s * 0.34, 0.62, 0.32), Vector3(0.05, 0.2, 0.26), "plastic", kc.darkened(0.35), Basis(), 0.4)

	# Moteur : bloc, ailettes, filtre à air, bouchon rouge
	mb.rbox(Vector3(0, 0.52, 0.98), Vector3(0.26, 0.17, 0.2), "metal", METAL, Basis(), 0.3)
	for i in 4:
		mb.rbox(Vector3(0, 0.71 + i * 0.04, 0.98), Vector3(0.22 - i * 0.02, 0.012, 0.16 - i * 0.015), "chrome", CHROME, Basis(), 0.4, 6, 16)
	mb.lathe(PackedVector2Array([Vector2(0, -0.08), Vector2(0.1, -0.08), Vector2(0.11, -0.06), Vector2(0.11, 0.06), Vector2(0.1, 0.08), Vector2(0, 0.08)]),
		"chrome", CHROME, Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3(0.38, 0.6, 0.92)), 20)
	mb.lathe(PackedVector2Array([Vector2(0.112, -0.025), Vector2(0.116, 0.0), Vector2(0.112, 0.025)]),
		"paint", kc, Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3(0.38, 0.6, 0.92)), 20)
	mb.ellipsoid(Vector3(0, 0.88, 0.98), Vector3(0.04, 0.03, 0.04), "plastic", Color("#e63946"))
	# Pots d'échappement chromés
	for e in EXHAUSTS:
		var s := signf(e.x)
		var path := MeshBuilder.smooth_path(PackedVector3Array([
			Vector3(s * 0.1, 0.5, 1.12), Vector3(s * 0.18, 0.56, 1.3), e - Vector3(0, 0, 0.02)]), 4)
		mb.tube(path, MeshBuilder.taper(path.size(), 0.05, 0.07), "chrome", CHROME, 14, 1.0, Vector3.ZERO, false, false)
		mb.tube(PackedVector3Array([e - Vector3(0, 0, 0.03), e]), PackedFloat32Array([0.052, 0.052]), "matte", Color("#101010"), 14, 1.0, Vector3.ZERO, false, false)

	# Pare-chocs arrière et cadre
	var bumper := MeshBuilder.smooth_path(PackedVector3Array([
		Vector3(-0.72, 0.28, 1.1), Vector3(-0.66, 0.3, 1.34), Vector3(0, 0.3, 1.4), Vector3(0.66, 0.3, 1.34), Vector3(0.72, 0.28, 1.1)]), 4)
	mb.tube(bumper, MeshBuilder.taper(bumper.size(), 0.055, 0.055), "plastic", DARK, 12)
	# Aileron arrière
	for s in [-1.0, 1.0]:
		mb.tube(PackedVector3Array([Vector3(s * 0.34, 0.6, 1.2), Vector3(s * 0.36, 0.9, 1.32)]), PackedFloat32Array([0.025, 0.025]), "plastic", DARK, 8)
	var wing_paint := func(p: Vector3) -> Color:
		return acc if p.x > 0.11 else kc
	mb.push(Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(0, 0.94, 1.34)))
	mb.loft([[-0.58, 0.17, 0.035, 0.0, 2.6], [0.0, 0.18, 0.04, 0.0, 2.6], [0.58, 0.17, 0.035, 0.0, 2.6]], "paint",
		wing_paint, 20, 0.02, 0.02)
	mb.pop()
	for s in [-1.0, 1.0]:
		mb.rbox(Vector3(s * 0.6, 0.94, 1.34), Vector3(0.02, 0.1, 0.19), "plastic", DARK, Basis(), 0.35)

	# Essieux et bras de direction
	mb.tube(PackedVector3Array([Vector3(-0.66, 0.36, 0.72), Vector3(0.66, 0.36, 0.72)]), PackedFloat32Array([0.035, 0.035]), "chrome", CHROME, 10)
	for s in [-1.0, 1.0]:
		mb.tube(PackedVector3Array([Vector3(s * 0.3, 0.32, -0.8), Vector3(s * 0.64, 0.3, -0.8)]), PackedFloat32Array([0.032, 0.032]), "chrome", CHROME, 10)
		mb.tube(PackedVector3Array([Vector3(s * 0.3, 0.22, -0.62), Vector3(s * 0.62, 0.26, -0.78)]), PackedFloat32Array([0.022, 0.022]), "plastic", DARK, 8)
	# Colonne de direction
	var col_end := STEERING + Basis(Vector3.RIGHT, deg_to_rad(STEERING_TILT)) * Vector3(0, 0, 0.04)
	mb.tube(PackedVector3Array([Vector3(0, 0.6, -0.64), col_end]), PackedFloat32Array([0.03, 0.026]), "chrome", CHROME, 10)
	return mb.commit()


## Roue : pneu sculpté, flanc avec un liseré, jante chromée à 5 branches,
## enjoliveur de la couleur du kart. Axe : X ; face extérieure vers +X.
static func _wheel(r: float, w: float, info: CharacterData) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rr := r * 0.6
	var hw := w / 2.0
	var axis := Transform3D(Basis(Vector3.BACK, -PI / 2.0), Vector3.ZERO) # Y du profil -> X de la roue
	var tire := PackedVector2Array([
		Vector2(rr, -hw * 0.82), Vector2(rr + 0.03, -hw * 0.98), Vector2(r * 0.84, -hw), Vector2(r * 0.97, -hw * 0.9),
		Vector2(r, -hw * 0.62), Vector2(r, 0.0), Vector2(r, hw * 0.62), Vector2(r * 0.97, hw * 0.9),
		Vector2(r * 0.84, hw), Vector2(rr + 0.03, hw * 0.98), Vector2(rr, hw * 0.82)])
	var treads := 16.0
	var tire_paint := func(p: Vector3) -> Color:
		var rad := Vector2(p.y, p.z).length()
		if absf(p.x) > hw * 0.9 and rad > r * 0.8 and rad < r * 0.88:
			return Color("#4a4d57")
		return TIRE
	# sculptures de la bande de roulement (décalées d'un côté à l'autre)
	var grooves := func(th: float, h: float) -> float:
		if absf(h) > hw * 0.7:
			return 0.0
		return -0.018 * clampf(sin(th * treads + (0.6 if h > 0.0 else 0.0)) * 3.0, 0.0, 1.0)
	mb.lathe(tire, "rubber", tire_paint, axis, 64, grooves)
	# jante : cuvette chromée
	var rim := PackedVector2Array([
		Vector2(rr * 0.96, -hw * 0.8), Vector2(rr * 1.02, hw * 0.55), Vector2(rr * 0.9, hw * 0.62),
		Vector2(rr * 0.8, hw * 0.4), Vector2(rr * 0.3, hw * 0.3), Vector2(0.0, hw * 0.3)])
	mb.lathe(rim, "chrome", CHROME, axis, 28)
	mb.ellipsoid(Vector3(-hw * 0.7, 0, 0), Vector3(0.012, rr * 0.97, rr * 0.97), "chrome", METAL, Basis(), [], 4, 24)
	for i in 5:
		var a := TAU * i / 5.0
		var b := Basis(Vector3.RIGHT, a)
		mb.rbox(b * Vector3(hw * 0.42, rr * 0.5, 0.0), Vector3(0.025, rr * 0.42, 0.032), "chrome", CHROME, b, 0.4, 6, 12)
	# enjoliveur : métal teinté de la couleur du kart
	mb.ellipsoid(Vector3(hw * 0.42, 0, 0), Vector3(0.05, rr * 0.34, rr * 0.34), "chrome", info.kart_color.lightened(0.15))
	return mb.commit()


## Volant : jante en caoutchouc, trois branches, centre de la couleur du kart.
## Son axe est Z (vers le pilote).
static func _steering(info: CharacterData) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var ring := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in 24:
		var a := TAU * i / 24.0
		ring.append(Vector3(cos(a) * 0.2, sin(a) * 0.2, 0.0))
		radii.append(0.03)
	mb.tube(ring, radii, "rubber", DARK, 10, 1.0, Vector3.ZERO, true)
	for a in [PI / 2.0 + 0.0, PI / 2.0 + TAU / 3.0, PI / 2.0 - TAU / 3.0]:
		var dir := Vector3(cos(a), -sin(a), 0.0)
		mb.tube(PackedVector3Array([Vector3.ZERO, dir * 0.19]), PackedFloat32Array([0.022, 0.018]), "chrome", CHROME, 8)
	mb.ellipsoid(Vector3(0, 0, 0.01), Vector3(0.07, 0.07, 0.035), "chrome", info.kart_color.lightened(0.15))
	mb.ellipsoid(Vector3(0, 0, 0.04), Vector3(0.035, 0.035, 0.012), "rubber", accent(info.kart_color))
	return mb.commit()
