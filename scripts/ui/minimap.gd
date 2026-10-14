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
	Ui.flat(Color(0.06, 0.19, 0.23, 0.8), 20).draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
	var mapped := PackedVector2Array()
	for v in points:
		mapped.append(_to_map(v))
	mapped.append(mapped[0])
	draw_polyline(mapped, Color(0.1, 0.1, 0.12), 12.0, true)
	draw_polyline(mapped, Color("#f7deb0"), 7.0, true)
	draw_circle(mapped[0], 6.0, Color.WHITE)
	for d in dots:
		if not d[2]:
			draw_circle(_to_map(d[0]), 7.0, Color.BLACK)
			draw_circle(_to_map(d[0]), 5.5, d[1])
	for d in dots:
		if d[2]:
			draw_circle(_to_map(d[0]), 11.0, Color.WHITE)
			draw_circle(_to_map(d[0]), 8.0, d[1])
