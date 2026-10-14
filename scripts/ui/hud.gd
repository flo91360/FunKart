class_name Hud
extends CanvasLayer
## Interface pendant la course : place, tour, classement, vitesse de frappe,
## mini-carte et surtout le mot à taper.

signal resume_pressed
signal quit_pressed

const WORD_SIZES := [72, 104, 140]
const IDLE_HINT := "Ton kart roule tout seul… prépare tes doigts !"

@onready var place_label: Label = %PlaceLabel
@onready var place_suffix: Label = %PlaceSuffix
@onready var lap_label: Label = %LapLabel
@onready var standings_box: VBoxContainer = %Standings
@onready var kpm_label: Label = %KpmLabel
@onready var acc_label: Label = %AccLabel
@onready var speed_label: Label = %SpeedLabel
@onready var status_label: Label = %StatusLabel
@onready var center_label: Label = %CenterLabel
@onready var word_panel: PanelContainer = %WordPanel
@onready var word_label: RichTextLabel = %WordLabel
@onready var hint_label: Label = %HintLabel
@onready var minimap: Minimap = %Minimap
@onready var pause_layer: Control = %PauseLayer
var _center_tween: Tween
var _uppercase := false
var word_progress: ProgressBar


func _ready() -> void:
	word_label.add_theme_font_override("normal_font", Ui.word_font())
	word_progress = ProgressBar.new()
	word_progress.custom_minimum_size = Vector2(0, 8)
	word_progress.show_percentage = false
	word_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	word_progress.add_theme_stylebox_override("background", Ui.flat(Color("#dce5d9"), 4, Color.TRANSPARENT, 0, 0))
	word_progress.add_theme_stylebox_override("fill", Ui.flat(Ui.GREEN, 4, Color.TRANSPARENT, 0, 0))
	word_label.get_parent().add_child(word_progress)
	word_label.get_parent().move_child(word_progress, 1)
	%ResumeButton.pressed.connect(func(): resume_pressed.emit())
	%QuitButton.pressed.connect(func(): quit_pressed.emit())
	pause_layer.visible = false


func setup(track_points: PackedVector2Array, laps: int, profile: Profile) -> void:
	_uppercase = bool(profile.get_setting("uppercase"))
	var size: int = WORD_SIZES[clampi(int(profile.get_setting("text_size")), 0, 2)]
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
	if p:
		%VolumeSliders.refresh()


## Mot à taper : lettres tapées en vert, lettre attendue surlignée en jaune.
func show_word(word: String, typed: int, success := false) -> void:
	word_progress.visible = true
	word_progress.value = 100.0 * typed / maxf(1.0, word.length())
	var upper := _uppercase
	var s := "[center]"
	for i in word.length():
		var ch := word[i].to_upper() if upper else word[i]
		if success or i < typed:
			s += "[color=#269779]%s[/color]" % ch
		elif i == typed:
			s += "[bgcolor=#ffcf76][color=#183e4b]%s[/color][/bgcolor]" % ch
		else:
			s += "[color=#657e88]%s[/color]" % ch
	word_label.text = s + "[/center]"
	if success:
		var tw := create_tween()
		word_panel.pivot_offset = word_panel.size / 2.0
		tw.tween_property(word_panel, "scale", Vector2(1.08, 1.08), 0.1)
		tw.tween_property(word_panel, "scale", Vector2.ONE, 0.2)


func clear_word(hint := IDLE_HINT) -> void:
	word_label.text = ""
	word_progress.visible = false
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
		var color: Color = GameContent.get_content().character(r.character).kart_color
		var style := Ui.flat(Ui.NAVY.lightened(0.05), 12, color, 3 if r.is_player else 1, 6)
		style.content_margin_left = 12
		style.content_margin_right = 12
		row.add_theme_stylebox_override("panel", style)
		var txt := Ui.label("%d  %s" % [i + 1, r.name], 26 if r.is_player else 22,
			Color.WHITE, 0)
		row.add_child(txt)
		row.custom_minimum_size.x = 200
		standings_box.add_child(row)
