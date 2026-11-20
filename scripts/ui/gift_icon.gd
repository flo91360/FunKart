class_name GiftIcon
extends Control
## Dessin d'un cadeau (Gifts.KINDS : charge électrique, huile, clou, tempête,
## fusée) ou d'une flèche de touche du clavier ("left", "right"), sans image ni
## police : de grandes formes bien lisibles pour un enfant.

const INK := Color("#1f2433")

var kind := "":
	set(v):
		kind = v
		queue_redraw()
## Repère du dessin : centre, taille et rotation (les points vont de -0.5 à 0.5).
var _center := Vector2.ZERO
var _scale := 1.0
var _angle := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	_scale = minf(size.x, size.y)
	if _scale <= 0.0:
		return
	_center = size / 2.0
	_angle = 0.0
	match kind:
		Gifts.CHARGE:
			_charge()
		Gifts.OIL:
			_oil()
		Gifts.NAIL:
			_nail()
		Gifts.STORM:
			_storm()
		Gifts.ROCKET:
			_rocket()
		"left":
			_arrow(-1.0)
		"right":
			_arrow(1.0)


## Point du dessin (de -0.5 à 0.5) en pixels du contrôle.
func _p(v: Vector2) -> Vector2:
	return _center + v.rotated(_angle) * _scale


func _poly(points: Array, color: Color, outline := INK, width := 0.045) -> void:
	var pts := PackedVector2Array()
	for v in points:
		pts.append(_p(v))
	draw_colored_polygon(pts, color)
	if outline.a > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, outline, width * _scale, true)


func _line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	draw_line(_p(a), _p(b), color, width * _scale, true)


func _circle(c: Vector2, r: float, color: Color) -> void:
	draw_circle(_p(c), r * _scale, color)


func _ellipse(center: Vector2, radius: Vector2, color: Color, outline := INK, width := 0.045, n := 28) -> void:
	var pts := []
	for i in n:
		var a := TAU * i / n
		pts.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	_poly(pts, color, outline, width)


func _charge() -> void:
	_ellipse(Vector2.ZERO, Vector2(0.47, 0.47), Color("#2d7ff9"), Color.TRANSPARENT)
	_poly([Vector2(0.08, -0.42), Vector2(-0.24, 0.06), Vector2(-0.03, 0.06), Vector2(-0.12, 0.42),
		Vector2(0.24, -0.1), Vector2(0.03, -0.1), Vector2(0.16, -0.42)], Color("#ffd60a"))


func _oil() -> void:
	# flaque irrégulière
	var pts := []
	for i in 32:
		var a := TAU * i / 32.0
		var r := 0.36 + 0.05 * sin(3.0 * a + 0.5) + 0.03 * cos(5.0 * a)
		pts.append(Vector2(cos(a) * r, 0.16 + sin(a) * r * 0.55))
	_poly(pts, Color("#14121c"), Color.TRANSPARENT)
	_ellipse(Vector2(-0.12, 0.12), Vector2(0.1, 0.035), Color(0.65, 0.55, 1.0, 0.8), Color.TRANSPARENT)
	_ellipse(Vector2(0.13, 0.22), Vector2(0.06, 0.02), Color(0.4, 0.9, 1.0, 0.7), Color.TRANSPARENT)
	# goutte qui tombe
	var drop := [Vector2(0.0, -0.46)]
	for i in 13:
		var a := deg_to_rad(-25.0 + i * 230.0 / 12.0) # de la droite au bas, puis à la gauche
		drop.append(Vector2(0.0, -0.2) + Vector2(cos(a), sin(a)) * 0.12)
	_poly(drop, Color("#14121c"), Color.TRANSPARENT)
	_ellipse(Vector2(-0.04, -0.2), Vector2(0.03, 0.05), Color(1, 1, 1, 0.7), Color.TRANSPARENT)


func _nail() -> void:
	var steel := Color("#c9ced6")
	_angle = deg_to_rad(35.0)
	_poly([Vector2(-0.045, -0.26), Vector2(0.045, -0.26), Vector2(0.045, 0.28), Vector2(0.0, 0.44),
		Vector2(-0.045, 0.28)], steel)
	_poly([Vector2(-0.16, -0.36), Vector2(0.16, -0.36), Vector2(0.16, -0.27), Vector2(-0.16, -0.27)], steel)
	_line(Vector2(0.015, -0.22), Vector2(0.015, 0.26), Color(1, 1, 1, 0.8), 0.02)


func _storm() -> void:
	var cloud := Color("#8d99ae")
	for drop in [Vector2(-0.22, 0.12), Vector2(-0.05, 0.16), Vector2(0.12, 0.12), Vector2(0.27, 0.16)]:
		_line(drop, drop + Vector2(-0.08, 0.24), Color("#4cc9f0"), 0.05)
	_poly([Vector2(0.02, 0.02), Vector2(-0.1, 0.24), Vector2(0.0, 0.24), Vector2(-0.06, 0.42), Vector2(0.12, 0.17),
		Vector2(0.02, 0.17), Vector2(0.1, 0.02)], Color("#ffd60a"), INK, 0.03)
	var puffs := [[Vector2(-0.22, -0.06), 0.16], [Vector2(0.0, -0.18), 0.21], [Vector2(0.22, -0.06), 0.15]]
	for puff in puffs:
		_circle(puff[0], puff[1] + 0.035, INK)
	_poly([Vector2(-0.24, -0.08), Vector2(0.24, -0.08), Vector2(0.24, 0.12), Vector2(-0.24, 0.12)], INK, Color.TRANSPARENT)
	for puff in puffs:
		_circle(puff[0], puff[1], cloud)
	_poly([Vector2(-0.22, -0.06), Vector2(0.22, -0.06), Vector2(0.22, 0.09), Vector2(-0.22, 0.09)], cloud, Color.TRANSPARENT)
	_circle(Vector2(-0.06, -0.22), 0.06, Color(1, 1, 1, 0.45))


func _rocket() -> void:
	_angle = deg_to_rad(45.0)
	var red := Color("#e63946")
	_poly([Vector2(-0.06, 0.24), Vector2(0.0, 0.47), Vector2(0.06, 0.24)], Color("#ffb703"), Color("#ff5400"), 0.03)
	_poly([Vector2(-0.13, 0.1), Vector2(-0.24, 0.3), Vector2(-0.1, 0.26)], red)
	_poly([Vector2(0.13, 0.1), Vector2(0.24, 0.3), Vector2(0.1, 0.26)], red)
	var body := []
	for i in 21:
		var t := i / 20.0
		var y := lerpf(-0.42, 0.26, t)
		var w := 0.13 * sqrt(clampf((y + 0.42) / 0.3, 0.0, 1.0))
		body.append(Vector2(w, y))
	for i in 21:
		var p: Vector2 = body[20 - i]
		body.append(Vector2(-p.x, p.y))
	_poly(body, Color("#f1f1f1"))
	_poly([Vector2(-0.1, -0.2), Vector2(0.0, -0.42), Vector2(0.1, -0.2)], red, Color.TRANSPARENT)
	_ellipse(Vector2(0.0, -0.04), Vector2(0.06, 0.06), Color("#4cc9f0"), INK, 0.03)


func _arrow(dir: float) -> void:
	_poly([Vector2(0.3 * dir, 0.0), Vector2(-0.18 * dir, -0.3), Vector2(-0.18 * dir, 0.3)], INK, Color.TRANSPARENT)
