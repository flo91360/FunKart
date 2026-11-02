class_name Menu
extends CanvasLayer
## Menu principal : qui joue (profil), choix du pilote et du circuit, réglages,
## historique. La mise en page est dans scenes/ui/menu.tscn ; le logo animé,
## les cartes des pilotes (portraits 3D) et des circuits (tracé) sont faits ici.

signal play_pressed
## Le profil, son pilote ou ses réglages ont changé : la course doit être refaite.
signal profile_changed

const LOGO_TEXT := "FunKart"
const LOGO_COLORS := [Color("#ff595e"), Color("#ff924c"), Color("#ffca3a"), Color("#8ac926"),
	Color("#1fb5ff"), Color("#9b5de5"), Color("#ff70a6")]
const LOGO_SIZE := 104
const PLAY_COLOR := Color("#17b169")
## Bord droit du panneau des pilotes et largeur de la colonne de droite (voir menu.tscn).
const LEFT_EDGE := 596.0
const RIGHT_COLUMN := 352.0

const VIGNETTE_SHADER := """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV - 0.5;
	float v = smoothstep(0.3, 0.9, length(uv * vec2(1.0, 1.2)));
	COLOR = vec4(0.03, 0.05, 0.16, v * 0.5);
}
"""

@onready var profile_select: OptionButton = %ProfileSelect
@onready var character_grid: GridContainer = %CharacterGrid
@onready var track_grid: GridContainer = %TrackGrid
@onready var play_button: Button = %PlayButton
@onready var character_name: Label = %CharacterName
@onready var new_profile_layer: Control = %NewProfileLayer
@onready var new_profile_name: LineEdit = %NewProfileName
@onready var settings_dialog: SettingsDialog = %Settings
@onready var history_dialog: HistoryDialog = %History

var _char_buttons := {} # id -> Button
var _track_buttons: Array[Button] = []
## Calcul « Réservé aux adultes » avant les réglages (si la protection est active).
var _gate: ParentGate
var _letters: Array[Label] = []
var _letter_x: Array[float] = []
var _t := 0.0
## Portraits 3D des pilotes : photographiés un par un, une image par carte.
var _portraits := Node.new()
var _portrait_queue: Array = [] # [CharacterData, TextureRect]


## Cadre du tracé d'un circuit sur sa carte.
class TrackOutline extends Control:
	var points := PackedVector2Array()

	func _draw() -> void:
		if points.size() < 3:
			return
		var lo := points[0]
		var hi := points[0]
		for p in points:
			lo = lo.min(p)
			hi = hi.max(p)
		var span := (hi - lo).max(Vector2.ONE)
		var m := 10.0
		var sc := minf((size.x - 2.0 * m) / span.x, (size.y - 2.0 * m) / span.y)
		var off := (size - span * sc) / 2.0
		var pts := PackedVector2Array()
		for p in points:
			pts.append(off + (p - lo) * sc)
		pts.append(pts[0])
		draw_polyline(pts, Color(0.04, 0.07, 0.18, 0.45), 10.0, true)
		draw_polyline(pts, Color.WHITE, 5.5, true)
		draw_circle(pts[0], 6.5, Color(0.04, 0.07, 0.18, 0.6))
		draw_circle(pts[0], 4.5, Color("#ffd60a"))


func _ready() -> void:
	play_button.pressed.connect(func(): play_pressed.emit())
	_gate = ParentGate.new()
	$Root.add_child(_gate)
	_gate.passed.connect(func(): settings_dialog.open(Profiles.current))
	%SettingsButton.pressed.connect(func():
		if AppSettings.get_value("parent_lock"):
			_gate.open()
		else:
			settings_dialog.open(Profiles.current))
	%HistoryButton.pressed.connect(func(): history_dialog.open(Profiles.current))
	%QuitButton.pressed.connect(func(): get_tree().quit())
	%NewProfileButton.pressed.connect(_open_new_profile)
	%CreateProfileButton.pressed.connect(_create_profile)
	%CancelProfileButton.pressed.connect(func(): new_profile_layer.visible = false)
	new_profile_name.text_submitted.connect(func(_t): _create_profile())
	profile_select.item_selected.connect(func(idx):
		Profiles.select(Profiles.profiles[idx])
		_refresh()
		profile_changed.emit())
	settings_dialog.closed.connect(func():
		_refresh()
		profile_changed.emit())
	settings_dialog.profile_deleted.connect(func():
		_refresh()
		profile_changed.emit())
	new_profile_layer.visible = false
	%VersionLabel.text = "FunKart v" + str(ProjectSettings.get_setting("application/config/version", "?"))
	add_child(_portraits)

	_style()
	_build_logo()
	_build_characters()
	_build_tracks()
	$Root.resized.connect(_place_name)
	_place_name()
	_refresh()
	_intro()


## Arrivée du menu : les lettres du logo tombent une à une, les panneaux
## apparaissent en grandissant (sans toucher à leur place : l'écran peut
## changer de taille au lancement, en passant en plein écran).
func _intro() -> void:
	for i in _letters.size():
		var l := _letters[i]
		l.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(0.05 + i * 0.07)
		tw.tween_property(l, "modulate:a", 1.0, 0.15)
	var panels: Array[Control] = [%Ribbon, $Root/Panel, %TrackPanel, %PlayBox]
	for i in panels.size():
		var c := panels[i]
		c.modulate.a = 0.0
		c.scale = Vector2(0.9, 0.9)
		var tw := create_tween()
		tw.tween_interval(0.15 + i * 0.1)
		tw.tween_callback(func(): c.pivot_offset = c.size / 2.0)
		tw.set_parallel()
		tw.tween_property(c, "modulate:a", 1.0, 0.25)
		tw.tween_property(c, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func focus_play() -> void:
	play_button.grab_focus()


## Décalage de la caméra du menu pour que le kart soit au milieu de l'espace
## libre entre le panneau des pilotes et la colonne de droite.
func kart_side() -> float:
	var vp := get_viewport().get_visible_rect().size
	var frac := (LEFT_EDGE + vp.x - RIGHT_COLUMN) / 2.0 / vp.x
	var half_w := tan(deg_to_rad(30.0)) * 7.5 * vp.x / vp.y
	return -(frac - 0.5) * 2.0 * half_w


# ---------------- Mise en forme ----------------

func _style() -> void:
	# léger assombrissement des bords de l'écran : les panneaux ressortent
	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	vm.shader = MeshBuilder._shader(VIGNETTE_SHADER)
	vignette.material = vm
	$Root.add_child(vignette)
	$Root.move_child(vignette, 0)
	var ribbon := Ui.flat(Ui.NAVY, 18, Color(1, 1, 1, 0.85), 3, 6)
	ribbon.shadow_color = Color(0, 0, 0, 0.3)
	ribbon.shadow_size = 8
	%Ribbon.add_theme_stylebox_override("panel", ribbon)
	$Root/Ribbon/Subtitle.add_theme_font_override("font", Ui.bold_font())
	for l in [$Root/Panel/Box/WhoLabel, $Root/Panel/Box/CharacterLabel, $Root/TrackPanel/TrackBox/TrackLabel]:
		l.add_theme_font_override("font", Ui.title_font())
		l.add_theme_color_override("font_color", Ui.NAVY)
	Ui.set_button_color(%NewProfileButton, Color("#2d7ff9"))
	Ui.set_button_color(play_button, PLAY_COLOR, Color.TRANSPARENT, 26)
	play_button.add_theme_font_override("font", Ui.title_font())
	for c in ["font_outline_color"]:
		play_button.add_theme_color_override(c, Color(0.03, 0.3, 0.16, 0.6))
	play_button.add_theme_constant_override("outline_size", 10)
	Ui.bounce_on_hover(play_button, 1.04)
	for b in [%SettingsButton, %HistoryButton, %QuitButton]:
		Ui.set_button_color(b, Color("#7b8bb2"))
		Ui.bounce_on_hover(b)
	character_name.add_theme_font_override("font", Ui.title_font())
	character_name.add_theme_color_override("font_color", Color.WHITE)
	character_name.add_theme_color_override("font_outline_color", Ui.NAVY)
	character_name.add_theme_constant_override("outline_size", 18)
	character_name.add_theme_color_override("font_shadow_color", Color(0.03, 0.05, 0.16, 0.5))
	character_name.add_theme_constant_override("shadow_offset_y", 6)
	character_name.add_theme_constant_override("shadow_outline_size", 18)
	Ui.set_button_color(%CreateProfileButton, PLAY_COLOR)
	Ui.set_button_color(%CancelProfileButton, Color("#7b8bb2"))
	%NewProfileTitle.add_theme_font_override("font", Ui.title_font())
	%NewProfileTitle.add_theme_color_override("font_color", Ui.NAVY)
	# le bouton JOUER respire doucement
	var tw := play_button.create_tween().set_loops()
	tw.tween_property(play_button, "scale", Vector2(1.035, 1.035), 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(play_button, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)
	play_button.resized.connect(func(): play_button.pivot_offset = play_button.size / 2.0)


## Logo : une lettre par couleur, qui ondulent doucement.
func _build_logo() -> void:
	var logo: Control = %Logo
	var font := Ui.title_font()
	var x := 10.0
	for i in LOGO_TEXT.length():
		var ch := LOGO_TEXT[i]
		var l := Ui.title(ch, LOGO_SIZE, LOGO_COLORS[i % LOGO_COLORS.size()], 26, Ui.NAVY)
		l.add_theme_constant_override("shadow_offset_y", 9)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		logo.add_child(l)
		l.position = Vector2(x, 0)
		_letters.append(l)
		_letter_x.append(x)
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, LOGO_SIZE).x + 4.0


func _build_characters() -> void:
	for c in GameContent.get_content().playable_characters():
		var b := Button.new()
		b.custom_minimum_size = Vector2(126, 142)
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_select_character.bind(c.id))
		Ui.bounce_on_hover(b, 1.06)
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.offset_top = 6
		box.offset_bottom = -10
		box.add_theme_constant_override("separation", -2)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(box)
		var pic := TextureRect.new()
		pic.custom_minimum_size = Vector2(104, 104)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(pic)
		var name_label := Ui.label(c.display_name, 18, Color.WHITE, 6, Color(0.03, 0.05, 0.16, 0.7))
		name_label.add_theme_font_override("font", Ui.bold_font())
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(name_label)
		character_grid.add_child(b)
		_char_buttons[c.id] = b
		_portrait_queue.append([c, pic])


func _build_tracks() -> void:
	var content := GameContent.get_content()
	if content.tracks.size() < 2:
		%TrackPanel.visible = false
		return
	for i in content.tracks.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 122)
		b.pressed.connect(_select_track.bind(i))
		Ui.bounce_on_hover(b, 1.06)
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.offset_top = 4
		box.offset_bottom = -8
		box.add_theme_constant_override("separation", 0)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(box)
		var outline := TrackOutline.new()
		outline.points = content.track_outline(i)
		outline.size_flags_vertical = Control.SIZE_EXPAND_FILL
		outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(outline)
		var t := Ui.label(content.track_title(i), 18, Color.WHITE, 6, Color(0.03, 0.05, 0.16, 0.7))
		t.add_theme_font_override("font", Ui.bold_font())
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(t)
		track_grid.add_child(b)
		_track_buttons.append(b)


## Nom du pilote, en grand, sous le kart (au milieu de l'espace libre).
func _place_name() -> void:
	var vp: Vector2 = $Root.size
	var cx := (LEFT_EDGE + vp.x - RIGHT_COLUMN) / 2.0
	character_name.size = Vector2(340, 84)
	character_name.position = Vector2(cx - 170.0, vp.y - 108.0)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	for i in _letters.size():
		var l := _letters[i]
		var drop := clampf(1.0 - (_t - 0.05 - i * 0.07) / 0.45, 0.0, 1.0)
		l.position = Vector2(_letter_x[i], 6.0 + sin(_t * 2.6 - i * 0.55) * 6.0 - drop * drop * 160.0)
		l.pivot_offset = l.size / 2.0
		l.rotation = sin(_t * 1.8 - i * 0.7) * 0.05
	# un portrait par image, pour ne pas ralentir l'ouverture du menu
	if not _portrait_queue.is_empty():
		var job: Array = _portrait_queue.pop_front()
		_make_portrait(job[0], job[1])


## Photo de la tête du pilote (petite scène 3D à part, rendue une seule fois).
func _make_portrait(c: CharacterData, rect: TextureRect) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(208, 208)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#dbe6ff")
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, -150, 0)
	key.light_energy = 1.7
	key.light_color = Color("#fff3e0")
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, 20, 0)
	rim.light_energy = 1.1
	rim.light_color = Color("#cfe1ff")
	vp.add_child(rim)
	var kart := Kart.new(c, "")
	kart.animated = false
	vp.add_child(kart)
	var cam := Camera3D.new()
	cam.fov = 26.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0.7, 2.78, -2.6), Vector3(0, 2.48, 0.1))
	_portraits.add_child(vp)
	rect.texture = vp.get_texture()


func _refresh() -> void:
	profile_select.clear()
	for p in Profiles.profiles:
		profile_select.add_item(p.name)
	profile_select.select(Profiles.profiles.find(Profiles.current))
	var content := GameContent.get_content()
	for id in _char_buttons:
		var selected: bool = id == Profiles.current.character_id
		Ui.set_button_color(_char_buttons[id], content.character(id).kart_color, Color.WHITE if selected else Color.TRANSPARENT)
	character_name.text = content.character(Profiles.current.character_id).display_name
	%WordsLabel.text = "Mots : " + ", ".join(Profiles.current.active_titles())
	for i in _track_buttons.size():
		var selected: bool = i == clampi(Profiles.current.track_index, 0, _track_buttons.size() - 1)
		Ui.set_button_color(_track_buttons[i], content.track_theme(i).menu_color, Color.WHITE if selected else Color.TRANSPARENT)


func _select_track(index: int) -> void:
	Profiles.current.track_index = index
	Profiles.save_profile()
	_refresh()
	Ui.pop(_track_buttons[index])
	profile_changed.emit()


func _select_character(id: String) -> void:
	Profiles.current.character_id = id
	Profiles.save_profile()
	_refresh()
	Ui.pop(_char_buttons[id])
	Ui.pop(character_name, 1.2)
	profile_changed.emit()


func _open_new_profile() -> void:
	new_profile_name.text = ""
	new_profile_layer.visible = true
	new_profile_name.grab_focus()


func _create_profile() -> void:
	var n := new_profile_name.text.strip_edges()
	if n == "":
		return
	Profiles.create(n)
	new_profile_layer.visible = false
	_refresh()
	profile_changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.keycode != KEY_ESCAPE:
		return
	_gate.visible = false
	if settings_dialog.visible:
		settings_dialog.close_dialog()
	history_dialog.visible = false
	new_profile_layer.visible = false
