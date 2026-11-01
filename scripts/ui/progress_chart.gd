class_name ProgressChart
extends Control
## Courbe de progression (dans l'historique) : frappes par minute des
## dernières courses, records en doré. Données : Progress.series().

var points: Array = []


func _ready() -> void:
	custom_minimum_size = Vector2(0, 150)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resized.connect(queue_redraw)


func set_points(p: Array) -> void:
	points = p
	queue_redraw()


func _draw() -> void:
	var font := Ui.font()
	draw_style_box(Ui.flat(Color("#eef0f5"), 12), Rect2(Vector2.ZERO, size))
	if points.size() < 2:
		draw_string(font, Vector2(0, size.y / 2.0 + 8), "Joue au moins deux courses pour voir ta courbe de progression.",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color("#5f6470"))
		return
	var left := 56.0
	var right := 20.0
	var top := 30.0
	var bottom := 16.0
	var area := Rect2(left, top, size.x - left - right, size.y - top - bottom)
	var hi := 0.0
	for p in points:
		hi = maxf(hi, float(p.kpm))
	# échelle arrondie à la dizaine au-dessus
	var top_value := maxf(10.0, ceilf(hi * 1.1 / 10.0) * 10.0)
	draw_string(font, Vector2(left, 22), "Frappes par minute (%d dernières courses)" % points.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Ui.INK)
	for k in 3:
		var v := top_value * k / 2.0
		var y := area.end.y - area.size.y * v / top_value
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color("#d5d8e0"), 1.0)
		draw_string(font, Vector2(0, y + 6), str(roundi(v)), HORIZONTAL_ALIGNMENT_RIGHT, left - 8, 16, Color("#5f6470"))
	var line := PackedVector2Array()
	for i in points.size():
		var x := area.position.x + area.size.x * i / float(points.size() - 1)
		var y := area.end.y - area.size.y * float(points[i].kpm) / top_value
		line.append(Vector2(x, y))
	draw_polyline(line, Ui.ORANGE, 3.0, true)
	for i in points.size():
		if points[i].record:
			draw_circle(line[i], 8.0, Ui.INK)
			draw_circle(line[i], 6.5, Ui.YELLOW)
		else:
			draw_circle(line[i], 4.5, Ui.ORANGE)
