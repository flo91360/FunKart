class_name Menu
extends CanvasLayer
## Menu principal : qui joue (profil), choix du pilote, réglages, historique.
## La mise en page est dans scenes/ui/menu.tscn.

signal play_pressed
## Le profil, son pilote ou ses réglages ont changé : la course doit être refaite.
signal profile_changed

@onready var profile_select: OptionButton = %ProfileSelect
@onready var character_grid: GridContainer = %CharacterGrid
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


func _ready() -> void:
	play_button.pressed.connect(func(): play_pressed.emit())
	_gate = ParentGate.new()
	add_child(_gate)
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

	_build_track_panel()
	for c in GameContent.get_content().playable_characters():
		var b := Ui.button(c.display_name, 20)
		b.custom_minimum_size = Vector2(120, 56)
		b.pressed.connect(_select_character.bind(c.id))
		character_grid.add_child(b)
		_char_buttons[c.id] = b
	_refresh()


func focus_play() -> void:
	play_button.grab_focus()


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
		Ui.set_button_color(_track_buttons[i], content.track_theme(i).menu_color, Ui.NAVY if selected else Color.TRANSPARENT)


## Choix du circuit : petit panneau en haut à droite (le panneau principal
## remplit déjà la hauteur de l'écran). Le circuit choisi apparaît derrière le menu.
func _build_track_panel() -> void:
	var content := GameContent.get_content()
	if content.tracks.size() < 2:
		return
	var panel := PanelContainer.new()
	panel.name = "TrackPanel"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -36.0
	panel.offset_right = -36.0
	panel.offset_top = 18.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(Ui.label("Choisis ton circuit", 24))
	for i in content.tracks.size():
		var b := Ui.button(content.track_title(i), 20)
		b.custom_minimum_size = Vector2(240, 46)
		b.pressed.connect(_select_track.bind(i))
		box.add_child(b)
		_track_buttons.append(b)
	# sous les fenêtres (nouveau profil, réglages, historique) qui doivent le recouvrir
	var root: Control = $Root
	root.add_child(panel)
	root.move_child(panel, new_profile_layer.get_index())


func _select_track(index: int) -> void:
	Profiles.current.track_index = index
	Profiles.save_profile()
	_refresh()
	profile_changed.emit()


func _select_character(id: String) -> void:
	Profiles.current.character_id = id
	Profiles.save_profile()
	_refresh()
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
