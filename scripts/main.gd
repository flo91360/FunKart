extends Node
## Point d'entrée du jeu : passe du menu à la course et inversement.
## - Race (scenes/race/race.tscn) : le monde 3D et tout ce qui concerne la course ;
## - Menu (scenes/ui/menu.tscn) : profils, pilote, réglages, historique.

@onready var race: Race = $Race
@onready var menu: Menu = $Menu


func _ready() -> void:
	menu.play_pressed.connect(_start_race)
	menu.profile_changed.connect(_show_menu)
	race.menu_requested.connect(_show_menu)
	_show_menu()


func _show_menu() -> void:
	race.prepare(Profiles.current)
	race.show_preview()
	menu.visible = true
	menu.focus_play()


func _start_race() -> void:
	menu.visible = false
	race.start()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		AppSettings.set_value("fullscreen", not AppSettings.get_value("fullscreen"))
