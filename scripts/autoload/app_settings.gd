extends Node
## Réglages de l'ordinateur, communs à tous les profils (autoload « AppSettings ») :
## plein écran, sons, musique, dernier profil utilisé.
##
## Les données sont dans le dossier utilisateur de Godot ; on peut en choisir un
## autre avec l'argument « -- --data-dir=... » (utilisé par les tests).

const DEFAULTS := {
	"fullscreen": true,
	"sound": true,
	"music": true,
	"last_profile": "",
}

var data_dir := "user://"
var data: Dictionary = {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--data-dir="):
			data_dir = arg.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(data_dir)
	reload()
	# Appliqué une fois la fenêtre créée, sinon la demande de plein écran est ignorée.
	apply_display.call_deferred()


func path(file: String) -> String:
	return data_dir.path_join(file)


func reload() -> void:
	data = DEFAULTS.duplicate(true)
	var parsed: Variant = read_json(path("app.json"))
	if parsed is Dictionary:
		for key in parsed:
			if data.has(key):
				data[key] = parsed[key]


func save() -> void:
	write_json(path("app.json"), data)


func get_value(key: String) -> Variant:
	return data.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	data[key] = value
	save()
	if key == "fullscreen":
		apply_display()


func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if data.get("fullscreen", true):
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		return
	# Fenêtre : on reste dans la zone utile de l'écran (sans la barre des tâches).
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var usable := DisplayServer.screen_get_usable_rect()
	var size := Vector2i(mini(1280, usable.size.x - 40), mini(720, usable.size.y - 60))
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)


static func read_json(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(file_path))


static func write_json(file_path: String, value: Variant) -> bool:
	var f := FileAccess.open(file_path, FileAccess.WRITE)
	if f == null:
		push_error("Impossible d'écrire %s" % file_path)
		return false
	f.store_string(JSON.stringify(value, "\t"))
	return true
