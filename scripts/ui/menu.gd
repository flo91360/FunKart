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
	var credits := AcceptDialog.new()
	credits.title = "Crédits — FunKart"
	credits.ok_button_text = "Fermer"
	$Root.add_child(credits)
	var license_text := RichTextLabel.new()
	license_text.custom_minimum_size = Vector2(620, 360)
	license_text.add_theme_font_size_override("normal_font_size", 18)
	license_text.text = "FunKart — Festival de la forêt\nGraphismes procéduraux réalisés avec Godot.\n\nPolice Nunito : auteurs du projet Nunito.\n\n" + FileAccess.get_file_as_string("res://ui/fonts/OFL.txt")
	credits.add_child(license_text)
	var credits_button := LinkButton.new()
	credits_button.text = "Crédits"
	credits_button.add_theme_font_size_override("font_size", 14)
	credits_button.add_theme_color_override("font_color", Color("#fff1d6"))
	$Root.add_child(credits_button)
	credits_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	credits_button.offset_left = 150
	credits_button.offset_top = -26
	credits_button.offset_right = 220
	credits_button.offset_bottom = -4
	credits_button.pressed.connect(func(): credits.popup_centered(Vector2i(660, 440)))
	var hero := Ui.label("LE FESTIVAL\nDE LA FORÊT", 34, Color("#fff1d6"), 2, Ui.NAVY)
	hero.name = "FestivalTitle"
	hero.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	$Root.add_child(hero)
	hero.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	hero.offset_left = -420
	hero.offset_top = 34
	hero.offset_right = -40
	hero.offset_bottom = 134
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag := Ui.label("UN CLAVIER. UNE GRANDE AVENTURE.", 16, Color("#fff1d6"), 2, Ui.NAVY)
	$Root.add_child(tag)
	tag.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tag.offset_left = -420
	tag.offset_top = 140
	tag.offset_right = -40
	tag.offset_bottom = 170
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.set_button_color(play_button, Ui.ORANGE)
	for button in [%SettingsButton, %HistoryButton, %QuitButton]:
		Ui.set_button_color(button, Ui.NAVY)
	Ui.set_button_color(%NewProfileButton, Color("#cb7668"))
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
		Ui.set_button_color(_char_buttons[id], content.character(id).kart_color, Ui.YELLOW if selected else Color.TRANSPARENT)
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
