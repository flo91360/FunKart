class_name Hud
extends CanvasLayer
## Interface pendant la course : place, tour, classement, vitesse de frappe,
## mini-carte et surtout le mot à taper.
## Cases cadeau : cadeau gardé (en haut à gauche, à côté de la place),
## messages (en haut au milieu), choix de la case avec les flèches, mot
## « évite » (panneau rouge et temps qui reste), pluie de la tempête, mot flou.

signal resume_pressed
signal quit_pressed

const WORD_SIZES := [72, 104, 140]
const CENTER_FONT_SIZE := 190 # grand texte central, avant d'être rétréci pour tenir
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

## Pluie de la tempête sur tout l'écran.
const RAIN_SHADER := """
shader_type canvas_item;
uniform float strength = 0.0;
float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}
void fragment() {
	vec2 uv = UV;
	uv.x += uv.y * 0.16;
	float cols = 95.0;
	float id = floor(uv.x * cols);
	float rnd = hash(id);
	float y = fract(uv.y * 1.4 - TIME * (1.4 + rnd * 1.2) + rnd * 13.0);
	float drop = smoothstep(0.0, 0.02, y) * (1.0 - smoothstep(0.02, 0.14, y));
	float lane = abs(fract(uv.x * cols) - 0.5);
	float mask = drop * (1.0 - smoothstep(0.04, 0.14, lane)) * step(0.4, rnd);
	COLOR = mix(vec4(0.06, 0.08, 0.2, 0.28), vec4(0.8, 0.88, 1.0, 0.7), mask);
	COLOR.a *= strength;
}
"""

## Flou du mot (tempête) : moyenne des pixels de l'écran autour de chaque point.
const BLUR_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount = 0.0;
void fragment() {
	vec4 c = vec4(0.0);
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			c += texture(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * amount / 3.0 * SCREEN_PIXEL_SIZE);
		}
	}
	COLOR = c / 49.0;
}
"""
## Flou du mot au plus fort (pixels).
const BLUR_PIXELS := 16.0


## Barre du temps qui reste pour taper « évite ».
class TimeBar:
	extends Control
	var value := 1.0:
		set(v):
			value = v
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(Ui.flat(Color(0.03, 0.05, 0.16, 0.55), int(size.y / 2.0), Color.TRANSPARENT, 0, 0), r)
		if value > 0.0:
			var fill := Rect2(Vector2(3, 3), Vector2((size.x - 6.0) * value, size.y - 6.0))
			var color := Ui.RED.lerp(Ui.YELLOW, clampf(value * 2.0, 0.0, 1.0))
			draw_style_box(Ui.flat(color, int(size.y / 2.0), Color.TRANSPARENT, 0, 0), fill)


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
## Cases cadeau
var gift_panel: PanelContainer
var gift_icon: GiftIcon
var gift_name: Label
var toast_label: Label
var choose_row: HBoxContainer
var _choose_label: Label
var _banner: VBoxContainer
var _toast_tween: Tween
var _gift_tween: Tween
var _dodge_bar: TimeBar
var _rain: ColorRect
var _rain_strength := 0.0
var _blur: ColorRect
var _word_style: StyleBoxFlat
var _dodge_style: StyleBoxFlat
var dodging := false


func _ready() -> void:
	%ResumeButton.pressed.connect(func(): resume_pressed.emit())
	%QuitButton.pressed.connect(func(): quit_pressed.emit())
	pause_layer.visible = false
	keyboard = KeyboardView.new()
	keyboard.name = "Keyboard"
	word_label.get_parent().add_child(keyboard)
	_style()
	_build_gift_ui()


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
	_word_style = panel
	_dodge_style = panel.duplicate()
	_dodge_style.bg_color = Color("#fff0ec")
	_dodge_style.border_color = Ui.RED
	_dodge_style.set_border_width_all(6)
	_dodge_style.border_width_top = 10
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


## Cases cadeau : cadeau gardé (à droite de la place), bandeau des messages et
## du choix de la case, barre de l'esquive, pluie et flou de la tempête.
func _build_gift_ui() -> void:
	gift_panel = PanelContainer.new()
	gift_panel.name = "GiftPanel"
	gift_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	gift_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	gift_panel.add_child(box)
	gift_icon = GiftIcon.new()
	gift_icon.custom_minimum_size = Vector2(66, 66)
	gift_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(gift_icon)
	gift_name = Ui.label("", 19, Ui.INK)
	gift_name.add_theme_font_override("font", Ui.bold_font())
	gift_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(gift_name)
	var key := _keycap(null, "Entrée")
	key.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(key)
	var row := place_label.get_parent()
	var gap := Control.new()
	gap.custom_minimum_size.x = 14
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	row.add_child(gift_panel)
	gift_panel.visible = false

	_banner = VBoxContainer.new()
	_banner.name = "GiftBanner"
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.offset_top = 96
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner.add_theme_constant_override("separation", 6)
	$Root.add_child(_banner)
	$Root.move_child(_banner, center_label.get_index())
	choose_row = HBoxContainer.new()
	choose_row.alignment = BoxContainer.ALIGNMENT_CENTER
	choose_row.add_theme_constant_override("separation", 12)
	choose_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	choose_row.add_child(_keycap("left", ""))
	_choose_label = Ui.label("Choisis ta case cadeau !", 28, Color.WHITE, 12, Ui.NAVY)
	_choose_label.add_theme_font_override("font", Ui.bold_font())
	choose_row.add_child(_choose_label)
	choose_row.add_child(_keycap("right", ""))
	_banner.add_child(choose_row)
	choose_row.visible = false
	toast_label = Ui.label("", 28, Color.WHITE, 12, Ui.NAVY)
	toast_label.add_theme_font_override("font", Ui.bold_font())
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_banner.add_child(toast_label)
	toast_label.visible = false

	_dodge_bar = TimeBar.new()
	_dodge_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dodge_bar.visible = false
	$Root.add_child(_dodge_bar)
	$Root.move_child(_dodge_bar, pause_layer.get_index())

	_rain = ColorRect.new()
	_rain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rm := ShaderMaterial.new()
	rm.shader = MeshBuilder._shader(RAIN_SHADER)
	_rain.material = rm
	$Root.add_child(_rain)
	$Root.move_child(_rain, 1)
	_rain.visible = false

	_blur = ColorRect.new()
	_blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bm := ShaderMaterial.new()
	bm.shader = MeshBuilder._shader(BLUR_SHADER)
	_blur.material = bm
	word_label.add_child(_blur)
	_blur.visible = false


## Touche du clavier dessinée : flèche (icon : "left", "right") ou texte.
func _keycap(icon, text: String) -> PanelContainer:
	var key := PanelContainer.new()
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := Ui.flat(Color.WHITE, 9, Color("#9aa3b5"), 0, 6)
	st.border_width_bottom = 5
	st.content_margin_top = 3
	st.content_margin_bottom = 3
	key.add_theme_stylebox_override("panel", st)
	if icon != null:
		var g := GiftIcon.new()
		g.kind = icon
		g.custom_minimum_size = Vector2(34, 34)
		key.add_child(g)
	else:
		var l := Ui.label(text, 17, Ui.INK)
		l.add_theme_font_override("font", Ui.bold_font())
		key.add_child(l)
	return key


## Cadeau gardé, en haut à gauche ("" : aucun).
func show_gift(kind: String) -> void:
	if kind == "":
		gift_panel.visible = false
		gift_icon.kind = ""
		return
	gift_icon.kind = kind
	gift_name.text = Gifts.NAMES.get(kind, kind)
	var st := Ui.flat(Color("#fffaf0"), 18, Gifts.COLORS.get(kind, Ui.ORANGE), 5, 8)
	st.shadow_color = Color(0.03, 0.05, 0.16, 0.35)
	st.shadow_size = 8
	st.shadow_offset = Vector2(0, 3)
	gift_panel.add_theme_stylebox_override("panel", st)
	gift_panel.visible = true
	if _gift_tween:
		_gift_tween.kill()
	gift_panel.pivot_offset = gift_panel.size / 2.0
	gift_panel.scale = Vector2(1.35, 1.35)
	_gift_tween = create_tween()
	_gift_tween.tween_property(gift_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Message court en haut au milieu (cadeau reçu, attaque subie…).
func show_toast(text: String, color := Color.WHITE, hold := 2.2) -> void:
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", color)
	toast_label.visible = true
	toast_label.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	toast_label.pivot_offset = toast_label.size / 2.0
	toast_label.scale = Vector2(1.2, 1.2)
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_interval(hold)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.3)
	_toast_tween.tween_callback(func(): toast_label.visible = false)


func clear_toast() -> void:
	if _toast_tween:
		_toast_tween.kill()
	toast_label.visible = false


## À l'approche des cases cadeau : « Choisis ta case cadeau ! » entre les flèches.
func set_choosing(on: bool, has_gift := false) -> void:
	choose_row.visible = on
	if on:
		_choose_label.text = "Tu as déjà un cadeau : Entrée !" if has_gift else "Choisis ta case cadeau !"


## « évite » à taper : panneau du mot en rouge et barre du temps qui reste.
func show_dodge(word: String, typed: int, kind: String) -> void:
	if not dodging:
		dodging = true
		word_panel.add_theme_stylebox_override("panel", _dodge_style)
		_dodge_bar.visible = true
		set_blur(0.0)
	show_word(word, typed)
	var w := word.to_upper() if _uppercase else word
	set_hint("Vite ! Tape « %s » pour éviter %s !" % [w, "l'huile" if kind == Gifts.OIL else "le clou"], true)


func end_dodge() -> void:
	if not dodging:
		return
	dodging = false
	word_panel.add_theme_stylebox_override("panel", _word_style)
	_dodge_bar.visible = false


## Temps qui reste pour taper « évite » (1 : tout, 0 : plus rien).
func set_dodge_time(value: float) -> void:
	if not dodging:
		return
	_dodge_bar.value = value
	var r := word_panel.get_global_rect()
	_dodge_bar.position = Vector2(r.position.x + 40.0, r.position.y - 24.0)
	_dodge_bar.size = Vector2(r.size.x - 80.0, 16.0)


## Tempête sur l'enfant : pluie sur l'écran (elle arrive et s'en va en douceur).
func set_storm(on: bool, delta: float) -> void:
	_rain_strength = move_toward(_rain_strength, 1.0 if on else 0.0, delta * (3.0 if on else 1.5))
	_rain.visible = _rain_strength > 0.01
	if _rain.visible:
		(_rain.material as ShaderMaterial).set_shader_parameter("strength", _rain_strength)


## Mot flou (tempête) : 1 au plus flou, 0 net.
func set_blur(amount: float) -> void:
	_blur.visible = amount > 0.01 and word_label.text != ""
	if _blur.visible:
		(_blur.material as ShaderMaterial).set_shader_parameter("amount", amount * BLUR_PIXELS)


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
	end_dodge()
	show_gift("")
	set_choosing(false)
	clear_toast()
	_rain_strength = 0.0
	_rain.visible = false
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


## Place libre pour le grand texte central, en coordonnées de l'écran.
func center_text_box() -> Rect2:
	var margin := 16.0
	var left := ($Root/TopLeft as Control).get_global_rect().end.x + margin
	var right := minimap.get_global_rect().position.x - margin
	var top := ($Root/TopRight/Stats as Control).get_global_rect().end.y + margin
	var bottom := word_panel.global_position.y - margin
	return Rect2(left, top, maxf(right - left, 200.0), maxf(bottom - top, 80.0))


## Grand texte au centre (compte à rebours, « ARRIVÉE ! ») : il tient dans
## la place libre entre le classement et la minimap, et entre les stats du
## haut et le panneau du mot (la police rétrécit si besoin).
func show_center(text: String, hold := 0.8) -> void:
	center_label.text = text
	_layout_center()
	# Juste après l'affichage du HUD (premier « 3 »), ses panneaux ne sont pas
	# encore à leur place : on recale le texte une fois la mise en page faite.
	_layout_center.call_deferred()
	center_label.scale = Vector2(1.8, 1.8)
	center_label.modulate.a = 1.0
	if _center_tween:
		_center_tween.kill()
	_center_tween = create_tween()
	_center_tween.tween_property(center_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if hold > 0.0:
		_center_tween.tween_interval(hold)
		_center_tween.tween_property(center_label, "modulate:a", 0.0, 0.2)


func _layout_center() -> void:
	var text := center_label.text
	var box := center_text_box()
	var font := center_label.get_theme_font("font")
	var outline := center_label.get_theme_constant("outline_size")
	var size := CENTER_FONT_SIZE
	var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + outline
	var text_h := font.get_ascent(size) + outline
	var fit := minf(box.size.x / text_w, box.size.y / text_h)
	if fit < 1.0:
		size = maxi(int(size * fit), 40)
	center_label.add_theme_font_size_override("font_size", size)
	# Les majuscules (avec l'accent de « É ») occupent la hauteur de l'ascent :
	# on centre cette partie-là, pas toute la ligne (la descente reste vide).
	var root := center_label.get_parent() as Control
	var mid := box.get_center()
	var top := mid.y - font.get_ascent(size) / 2.0
	center_label.offset_left = box.position.x
	center_label.offset_right = box.end.x - root.size.x
	center_label.offset_top = top
	center_label.offset_bottom = top + font.get_height(size) - root.size.y
	center_label.pivot_offset = center_label.size / 2.0


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
	var running := logic.state == "running" and not p.finished
	if running and p.rocket > 0.0:
		status_label.text = "FUSÉE !"
		status_label.add_theme_color_override("font_color", Color("#ffb703"))
	elif running and p.slip > 0.0:
		status_label.text = "Ça glisse !"
		status_label.add_theme_color_override("font_color", Color("#ffb4a2"))
	elif running and p.flat > 0.0:
		status_label.text = "Pneu crevé !"
		status_label.add_theme_color_override("font_color", Color("#ffb4a2"))
	elif running and p.storm > 0.0:
		status_label.text = "Tempête !"
		status_label.add_theme_color_override("font_color", Color("#bde0fe"))
	elif logic.state == "running" and p.boost > 0.0:
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
