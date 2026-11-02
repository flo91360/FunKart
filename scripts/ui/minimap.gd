class_name Minimap
extends Control
## Mini-carte du circuit avec la position des karts.

var points := PackedVector2Array()
var dots: Array = [] # [Vector2 (monde, plan XZ), Color, est_joueur]
var _min := Vector2.ZERO
var _scale := 1.0
var _offset := Vector2.ZERO


func set_track(p: PackedVector2Array) -> void:
	points = p
	var lo := p[0]
	var hi := p[0]
	for v in p:
		lo = lo.min(v)
		hi = hi.max(v)
	_min = lo
	var span := hi - lo
	var area := custom_minimum_size if size == Vector2.ZERO else size
	_scale = minf((area.x - 24.0) / span.x, (area.y - 24.0) / span.y)
	_offset = (area - span * _scale) / 2.0
	queue_redraw()


func _to_map(v: Vector2) -> Vector2:
	return _offset + (v - _min) * _scale


func _draw() -> void:
	if points.is_empty():
		return
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.07, 0.2, 0.42)
	bg.set_corner_radius_all(22)
	bg.border_color = Color(1, 1, 1, 0.35)
	bg.set_border_width_all(2)
	draw_style_box(bg, Rect2(Vector2.ZERO, size))
	var mapped := PackedVector2Array()
	for v in points:
		mapped.append(_to_map(v))
	mapped.append(mapped[0])
	draw_polyline(mapped, Color(0.03, 0.05, 0.16, 0.8), 14.0, true)
	draw_polyline(mapped, Color(0.97, 0.97, 1.0), 8.0, true)
	# ligne d'arrivée en damier
	var a := mapped[0]
	var dir := (mapped[1] - mapped[0]).normalized()
	var side := Vector2(-dir.y, dir.x)
	for k in 4:
		var c := Color.BLACK if k % 2 == 0 else Color.WHITE
		draw_line(a + side * (k - 2) * 2.6, a + side * (k - 1) * 2.6, c, 5.0)
	for d in dots:
		if not d[2]:
			draw_circle(_to_map(d[0]), 7.5, Color(0.03, 0.05, 0.16))
			draw_circle(_to_map(d[0]), 5.5, d[1])
	var pulse := 1.0 + 0.2 * sin(Time.get_ticks_msec() / 160.0)
	for d in dots:
		if d[2]:
			draw_circle(_to_map(d[0]), 13.0 * pulse, Color(1, 1, 1, 0.35))
			draw_circle(_to_map(d[0]), 10.0, Color.WHITE)
			draw_circle(_to_map(d[0]), 7.5, d[1])
