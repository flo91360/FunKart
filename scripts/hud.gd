class_name Hud
extends CanvasLayer
## Interface pendant la course : place, tour, classement, vitesse de frappe,
## mini-carte et surtout le mot à taper.

signal resume_pressed
signal quit_pressed

const WORD_SIZES := [72, 104, 140]
const IDLE_HINT := "Ton kart roule tout seul… prépare tes doigts !"

var root := Control.new()
var place_label: Label
var place_suffix: Label
var lap_label: Label
var standings_box: VBoxContainer
var kpm_label: Label
var acc_label: Label
var speed_label: Label
var status_label: Label
var center_label: Label
var word_panel: PanelContainer
var word_label: RichTextLabel
var hint_label: Label
var minimap: Minimap
var pause_layer: Control
var _center_tween: Tween
var _word_base_x := 0.0


class Minimap:
	extends Control
	var points := PackedVector2Array()
	var dots: Array = [] # [Vector2 monde, Color, est_joueur]
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
		_scale = minf((size.x - 24.0) / span.x, (size.y - 24.0) / span.y)
		_offset = (size - span * _scale) / 2.0

	func _to_map(v: Vector2) -> Vector2:
		return _offset + (v - _min) * _scale

	func _draw() -> void:
		if points.is_empty():
			return
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
		var mapped := PackedVector2Array()
		for v in points:
			mapped.append(_to_map(v))
		mapped.append(mapped[0])
		draw_polyline(mapped, Color(0.1, 0.1, 0.12), 12.0, true)
		draw_polyline(mapped, Color(0.85, 0.85, 0.88), 7.0, true)
		draw_circle(mapped[0], 6.0, Color.WHITE)
		for d in dots:
			if not d[2]:
				draw_circle(_to_map(d[0]), 7.0, Color.BLACK)
				draw_circle(_to_map(d[0]), 5.5, d[1])
		for d in dots:
			if d[2]:
				draw_circle(_to_map(d[0]), 11.0, Color.WHITE)
				draw_circle(_to_map(d[0]), 8.0, d[1])


func _ready() -> void:
	root.theme = Ui.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Place et tour (en haut à gauche)
	var tl := VBoxContainer.new()
	tl.position = Vector2(24, 8)
	root.add_child(tl)
	var place_row := HBoxContainer.new()
	place_row.add_theme_constant_override("separation", 0)
	tl.add_child(place_row)
	place_label = Ui.label("1", 110, Ui.YELLOW, 22, Ui.NAVY)
	place_row.add_child(place_label)
	place_suffix = Ui.label("er", 52, Ui.YELLOW, 16, Ui.NAVY)
	place_suffix.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	place_suffix.position.y = 12
	place_row.add_child(place_suffix)
	lap_label = Ui.label("TOUR 1/3", 38, Color.WHITE, 14, Ui.NAVY)
	tl.add_child(lap_label)
	standings_box = VBoxContainer.new()
	standings_box.add_theme_constant_override("separation", 4)
	tl.add_child(standings_box)

	# Statistiques et mini-carte (en haut à droite)
	var tr := VBoxContainer.new()
	tr.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tr.position = Vector2(-24, 12)
	tr.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(tr)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 22)
	tr.add_child(stats)
	kpm_label = _stat(stats, "FRAPPES/MIN")
	acc_label = _stat(stats, "PRÉCISION")
	speed_label = _stat(stats, "KM/H")
	minimap = Minimap.new()
	minimap.custom_minimum_size = Vector2(250, 210)
	minimap.size = Vector2(250, 210)
	minimap.size_flags_horizontal = Control.SIZE_SHRINK_END
	tr.add_child(minimap)

	status_label = Ui.label("", 54, Ui.YELLOW, 18, Ui.NAVY)
	status_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.position.y = 120
	status_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(status_label)

	center_label = Ui.label("", 190, Color.WHITE, 30, Ui.NAVY)
	center_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_label.offset_bottom = -160
	center_label.pivot_offset = Vector2(640, 280)
	root.add_child(center_label)

	# Le mot à taper (en bas)
	word_panel = PanelContainer.new()
	word_panel.add_theme_stylebox_override("panel", _word_style())
	word_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	word_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	word_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	word_panel.position.y = -20
	word_panel.custom_minimum_size = Vector2(760, 0)
	root.add_child(word_panel)
	var wbox := VBoxContainer.new()
	wbox.add_theme_constant_override("separation", 2)
	word_panel.add_child(wbox)
	word_label = RichTextLabel.new()
	word_label.bbcode_enabled = true
	word_label.fit_content = true
	word_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	word_label.scroll_active = false
	word_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	word_label.add_theme_font_override("normal_font", Ui.word_font())
	wbox.add_child(word_label)
	hint_label = Ui.label(IDLE_HINT, 30, Color("#5f6470"))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wbox.add_child(hint_label)

	# Pause
	var ov := Ui.overlay(root, Vector2(520, 0))
	pause_layer = ov[0]
	var box: VBoxContainer = ov[1]
	var title := Ui.label("Pause", 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var tip := Ui.label("Appuie sur Échap pour reprendre.", 24, Color("#5f6470"))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tip)
	var resume := Ui.button("Reprendre", 34)
	resume.pressed.connect(func(): resume_pressed.emit())
	box.add_child(resume)
	var quit := Ui.button("Quitter la course", 26, Color("#8d99ae"))
	quit.pressed.connect(func(): quit_pressed.emit())
	box.add_child(quit)
	pause_layer.visible = false


func _stat(parent: Control, title: String) -> Label:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -6)
	parent.add_child(box)
	var t := Ui.label(title, 18, Color.WHITE, 8, Ui.NAVY)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var v := Ui.label("–", 46, Color.WHITE, 14, Ui.NAVY)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.custom_minimum_size.x = 110
	box.add_child(v)
	return v


func _word_style() -> StyleBoxFlat:
	var s := Ui.flat(Color("#fdf6e3"), 26, Ui.ORANGE, 0, 18)
	s.border_width_top = 8
	s.border_color = Ui.ORANGE
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 10
	return s


func setup(track_points: PackedVector2Array, laps: int) -> void:
	var size: int = WORD_SIZES[clampi(int(GameSettings.data.text_size), 0, 2)]
	word_label.add_theme_font_size_override("normal_font_size", size)
	word_label.custom_minimum_size.y = size * 1.25
	minimap.set_track(track_points)
	lap_label.text = "TOUR 1/%d" % laps
	pause_layer.visible = false
	status_label.text = ""
	center_label.text = ""
	clear_word()


func set_paused(p: bool) -> void:
	pause_layer.visible = p


## Mot à taper : lettres tapées en vert, lettre attendue surlignée en jaune.
func show_word(word: String, typed: int, success := false) -> void:
	var upper := bool(GameSettings.data.uppercase)
	var s := "[center]"
	for i in word.length():
		var ch := word[i].to_upper() if upper else word[i]
		if success or i < typed:
			s += "[color=#27ae60]%s[/color]" % ch
		elif i == typed:
			s += "[bgcolor=#ffd60a][color=#1d1d1f]%s[/color][/bgcolor]" % ch
		else:
			s += "[color=#9aa0ac]%s[/color]" % ch
	word_label.text = s + "[/center]"
	if success:
		var tw := create_tween()
		word_panel.pivot_offset = word_panel.size / 2.0
		tw.tween_property(word_panel, "scale", Vector2(1.08, 1.08), 0.1)
		tw.tween_property(word_panel, "scale", Vector2.ONE, 0.2)


func clear_word(hint := IDLE_HINT) -> void:
	word_label.text = ""
	set_hint(hint)


func set_hint(text: String, error := false) -> void:
	hint_label.text = text
	hint_label.add_theme_color_override("font_color", Ui.RED if error else Color("#5f6470"))


func shake_word() -> void:
	var tw := create_tween()
	var x := word_panel.position.x
	for dx in [-14.0, 14.0, -8.0, 8.0, 0.0]:
		tw.tween_property(word_panel, "position:x", x + dx, 0.04)


func show_center(text: String, hold := 0.8) -> void:
	center_label.text = text
	center_label.pivot_offset = center_label.size / 2.0
	if _center_tween:
		_center_tween.kill()
	center_label.scale = Vector2(1.8, 1.8)
	center_label.modulate.a = 1.0
	_center_tween = create_tween()
	_center_tween.tween_property(center_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if hold > 0.0:
		_center_tween.tween_interval(hold)
		_center_tween.tween_property(center_label, "modulate:a", 0.0, 0.2)


func update_minimap(dots: Array) -> void:
	minimap.dots = dots
	minimap.queue_redraw()


func update_race(logic: RaceLogic) -> void:
	var place := logic.player_position()
	place_label.text = str(place)
	place_suffix.text = "er" if place == 1 else "e"
	lap_label.text = "TOUR %d/%d" % [logic.current_lap(), logic.laps]
	kpm_label.text = str(roundi(logic.kpm())) if logic.stats.correct > 0 else "–"
	var keys: int = logic.stats.correct + logic.stats.errors
	acc_label.text = "%d%%" % roundi(logic.accuracy() * 100.0) if keys > 0 else "–"
	var p := logic.player
	speed_label.text = str(roundi(logic.base_speed * p.mult * 3.6)) if logic.state != "countdown" else "0"
	if logic.state == "running" and p.word != "":
		status_label.text = "Ralenti…"
		status_label.add_theme_color_override("font_color", Color("#ffb4a2"))
	elif logic.state == "running" and p.boost > 0.0:
		status_label.text = "TURBO !"
		status_label.add_theme_color_override("font_color", Ui.YELLOW)
	else:
		status_label.text = ""

	for c in standings_box.get_children():
		c.queue_free()
	var standings := logic.standings()
	for i in standings.size():
		var r = standings[i]
		var row := PanelContainer.new()
		var color: Color = Characters.get_info(r.character).kart
		var style := Ui.flat(color, 10, Color.WHITE, 4 if r.is_player else 0, 6)
		style.content_margin_left = 12
		style.content_margin_right = 12
		row.add_theme_stylebox_override("panel", style)
		var txt := Ui.label("%d  %s" % [i + 1, r.name], 26 if r.is_player else 22,
			Color.WHITE, 8, Color(0, 0, 0, 0.7))
		row.add_child(txt)
		row.custom_minimum_size.x = 200
		standings_box.add_child(row)
