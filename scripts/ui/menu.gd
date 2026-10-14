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


func _ready() -> void:
	Ui.backdrop($Root)
	Ui.set_button_color(play_button, Color("#e8b76c"))
	Ui.set_button_color(profile_select, Color("#365348"))
	for button in [%SettingsButton, %HistoryButton, %QuitButton, %NewProfileButton]:
		Ui.set_button_color(button, Color("#1b3c3c"))
	var credits := AcceptDialog.new()
	credits.title = "Crédits — FunKart"
	credits.ok_button_text = "Fermer"
	$Root.add_child(credits)
	var license_text := RichTextLabel.new()
	license_text.custom_minimum_size = Vector2(620, 360)
	license_text.add_theme_font_size_override("normal_font_size", 18)
	license_text.text = "FunKart — L’atelier des bois\nModèles originaux façonnés pour FunKart.\n\nPolice Nunito : auteurs du projet Nunito.\n\n" + FileAccess.get_file_as_string("res://ui/fonts/OFL.txt")
	credits.add_child(license_text)
	var credits_button := LinkButton.new()
	credits_button.text = "Crédits"
	credits_button.add_theme_font_size_override("font_size", 14)
	credits_button.add_theme_color_override("font_color", Color("#fff1d6"))
	$Root.add_child(credits_button)
	credits_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	credits_button.offset_left = 150
	credits_button.offset_top = -24
	credits_button.offset_right = 220
	credits_button.offset_bottom = -4
	credits_button.pressed.connect(func(): credits.popup_centered(Vector2i(660, 440)))
	play_button.pressed.connect(func(): play_pressed.emit())
	%SettingsButton.pressed.connect(func(): settings_dialog.open(Profiles.current))
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

	for c in GameContent.get_content().playable_characters():
		var b := Button.new()
		b.custom_minimum_size = Vector2(139, 104)
		b.pressed.connect(_select_character.bind(c.id))
		character_grid.add_child(b)
		var portrait := Ui.portrait(c.id)
		b.add_child(portrait)
		portrait.position = Vector2(35, 0)
		portrait.size = Vector2(70, 76)
		var name_label := Ui.label(c.display_name, 15, Color("#e7e5d1"))
		name_label.name = "Name"
		name_label.position = Vector2(0, 77)
		name_label.size = Vector2(139, 25)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(name_label)
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
		var button: Button = _char_buttons[id]
		var shade := Color("#365348") if selected else Color("#183b39")
		Ui.set_button_color(button, shade, Color("#e7b66b") if selected else Color("#426052"))
		button.get_node("Name").add_theme_color_override("font_color", Color("#f4d49a") if selected else Color("#d4dfcf"))
	character_name.text = content.character(Profiles.current.character_id).display_name
	%WordsLabel.text = "Mots : " + ", ".join(Profiles.current.active_titles())


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
	if settings_dialog.visible:
		settings_dialog.close_dialog()
	history_dialog.visible = false
	new_profile_layer.visible = false
