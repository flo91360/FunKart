class_name Hud
extends CanvasLayer
## Interface pendant la course : place, tour, classement, vitesse de frappe,
## mini-carte et surtout le mot à taper.

signal resume_pressed
signal quit_pressed

const WORD_SIZES := [72, 104, 140]
const IDLE_HINT := "Ton kart roule tout seul… prépare tes doigts !"

## Traits de vitesse sur les bords de l'écran pendant le turbo.
const SPEED_LINES_SHADER := """
shader_type canvas_item;
uniform float strength = 0.0;
float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}
void fragment() {
	vec2 p = UV - 0.5;
	p.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float a = atan(p.y, p.x) / 6.2831853 + 0.5;
	float r = length(p);
	float lanes = 110.0;
	float id = floor(a * lanes);
	float rnd = hash(id);
	float t = fract(TIME * (1.2 + rnd * 1.8) + rnd * 7.0);
	float head = mix(0.3, 1.0, t);
	float streak = smoothstep(head - 0.22, head, r) * (1.0 - smoothstep(head, head + 0.015, r));
	float lane = abs(fract(a * lanes) - 0.5);
	float thin = 1.0 - smoothstep(0.06, 0.22, lane);
	float mask = smoothstep(0.3, 0.55, r) * step(0.5, rnd);
	COLOR = vec4(1.0, 0.98, 0.9, streak * thin * mask * strength * 0.6);
}
"""

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
## Clavier à l'écran, sous le mot (désactivable dans les réglages du profil).
var keyboard: KeyboardView
var _center_tween: Tween
var _shake_tween: Tween
var _speed_lines: ColorRect
var _boost := 0.0
var _shake_x := 0.0 # position du panneau du mot au repos
var _uppercase := false


func _ready() -> void:
	%ResumeButton.pressed.connect(func(): resume_pressed.emit())
	%QuitButton.pressed.connect(func(): quit_pressed.emit())
	pause_layer.visible = false
	keyboard = KeyboardView.new()
	keyboard.name = "Keyboard"
	word_label.get_parent().add_child(keyboard)
	_style()


## Polices et styles (thème du jeu) ; traits de vitesse du turbo.
func _style() -> void:
	var title := Ui.title_font()
	var shadow := Color(0.03, 0.05, 0.16, 0.5)
	for l in [place_label, place_suffix, lap_label, center_label, status_label, kpm_label, acc_label, speed_label]:
		l.add_theme_font_override("font", title)
		l.add_theme_color_override("font_shadow_color", shadow)
		l.add_theme_constant_override("shadow_offset_y", 5)
		l.add_theme_constant_override("shadow_outline_size", l.get_theme_constant("outline_size"))
	for path in ["Root/TopRight/Stats/KpmBox/KpmTitle", "Root/TopRight/Stats/AccBox/AccTitle", "Root/TopRight/Stats/SpeedBox/SpeedTitle"]:
		(get_node(path) as Label).add_theme_font_override("font", Ui.bold_font())
	word_label.add_theme_font_override("normal_font", Ui.word_font())
	hint_label.add_theme_font_override("font", Ui.bold_font())
	var panel := Ui.flat(Color("#fffaf0"), 30, Color("#ff6b35"), 0, 18)
	panel.border_width_top = 8
	panel.shadow_color = Color(0.03, 0.05, 0.16, 0.35)
	panel.shadow_size = 16
	panel.shadow_offset = Vector2(0, 6)
	word_panel.add_theme_stylebox_override("panel", panel)
	var pause_title: Label = $Root/PauseLayer/PauseCenter/PausePanel/PauseBox/PauseTitle
	pause_title.add_theme_font_override("font", title)
	pause_title.add_theme_color_override("font_color", Ui.NAVY)
	Ui.set_button_color(%ResumeButton, Color("#17b169"))
	Ui.set_button_color(%QuitButton, Color("#7b8bb2"))
	_speed_lines = ColorRect.new()
	_speed_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_speed_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = MeshBuilder._shader(SPEED_LINES_SHADER)
	_speed_lines.material = m
	$Root.add_child(_speed_lines)
	$Root.move_child(_speed_lines, 0)
	_speed_lines.visible = false


## Turbo en cours : traits de vitesse (ils apparaissent et s'effacent en douceur).
func set_boost(on: bool, delta: float) -> void:
	_boost = move_toward(_boost, 1.0 if on else 0.0, delta * (4.0 if on else 2.0))
	_speed_lines.visible = _boost > 0.01
	if _speed_lines.visible:
		(_speed_lines.material as ShaderMaterial).set_shader_parameter("strength", _boost)


func setup(track_points: PackedVector2Array, laps: int, profile: Profile) -> void:
	_uppercase = bool(profile.get_setting("uppercase"))
	var size: int = WORD_SIZES[clampi(int(profile.get_setting("text_size")), 0, 2)]
	word_label.add_theme_font_size_override("normal_font_size", size)
	word_label.custom_minimum_size.y = size * 1.25
	keyboard.visible = bool(profile.get_setting("keyboard"))
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
	var upper := _uppercase
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
	if success or typed >= word.length():
		keyboard.clear()
	else:
		keyboard.show_char(word[typed])
	if success:
		var tw := create_tween()
		word_panel.pivot_offset = word_panel.size / 2.0
		tw.tween_property(word_panel, "scale", Vector2(1.08, 1.08), 0.1)
		tw.tween_property(word_panel, "scale", Vector2.ONE, 0.2)


func clear_word(hint := IDLE_HINT) -> void:
	word_label.text = ""
	keyboard.clear()
	set_hint(hint)


func set_hint(text: String, error := false) -> void:
	hint_label.text = text
	hint_label.add_theme_color_override("font_color", Ui.RED if error else Color("#5f6470"))


func shake_word() -> void:
	var tw := create_tween()
	# Plusieurs erreurs de suite : on repart toujours de la position de repos,
	# sinon le panneau resterait décalé.
	if _shake_tween and _shake_tween.is_running():
		_shake_tween.kill()
	else:
		_shake_x = word_panel.position.x
	_shake_tween = tw
	for dx in [-14.0, 14.0, -8.0, 8.0, 0.0]:
		tw.tween_property(word_panel, "position:x", _shake_x + dx, 0.04)


## Grand texte au centre (compte à rebours, « ARRIVÉE ! »), centré dans la
## place libre au-dessus du panneau du mot pour ne pas être caché par lui.
func show_center(text: String, hold := 0.8) -> void:
	var root_h := (center_label.get_parent() as Control).size.y
	var free_bottom := maxf(word_panel.position.y - 12.0, 260.0)
	center_label.offset_bottom = free_bottom - root_h
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
	if logic.state == "running" and p.boost > 0.0:
		status_label.text = "TURBO !"
		status_label.add_theme_color_override("font_color", Ui.YELLOW)
	elif logic.state == "running" and p.word != "":
		status_label.text = "Ralenti…"
		status_label.add_theme_color_override("font_color", Color("#ffb4a2"))
	else:
		status_label.text = ""

	for c in standings_box.get_children():
		c.queue_free()
	var standings := logic.standings()
	for i in standings.size():
		var r = standings[i]
		var row := PanelContainer.new()
		var color: Color = GameContent.get_content().character(r.character).kart_color
		var style := Ui.flat(color, 14, Color.WHITE, 4 if r.is_player else 0, 5)
		style.border_width_bottom = 8 if r.is_player else 5
		if not r.is_player:
			style.border_color = color.darkened(0.3)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.shadow_color = Color(0.03, 0.05, 0.16, 0.3)
		style.shadow_size = 5
		style.shadow_offset = Vector2(0, 2)
		row.add_theme_stylebox_override("panel", style)
		var txt := Ui.label("%d  %s" % [i + 1, r.name], 26 if r.is_player else 22,
			Color.WHITE, 8, Color(0.03, 0.05, 0.16, 0.65))
		txt.add_theme_font_override("font", Ui.bold_font())
		row.add_child(txt)
		row.custom_minimum_size.x = 200
		standings_box.add_child(row)
