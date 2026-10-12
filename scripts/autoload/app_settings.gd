extends Node
## Réglages de l'ordinateur, communs à tous les profils (autoload « AppSettings ») :
## plein écran, sons, musique, volumes, qualité des graphismes, dernier profil utilisé.
##
## Les données sont dans le dossier utilisateur de Godot ; on peut en choisir un
## autre avec l'argument « -- --data-dir=... » (utilisé par les tests).

const DEFAULTS := {
	"fullscreen": true,
	"sound": true,
	"music": true,
	"volume_master": 0.8,
	"volume_music": 0.7,
	"volume_effects": 0.8,
	"graphics": 1,
	"last_profile": "",
}

## Qualité des graphismes.
enum Graphics { SIMPLE, NORMAL, BEAU }
const GRAPHICS_NAMES := ["Simple (ordinateur lent)", "Normal", "Beau (ordinateur récent)"]
## Le mode « Beau » utilise le moteur de rendu avancé de Godot (Forward+), qui
## se choisit au démarrage : il est enregistré dans ce fichier, lu par Godot
## grâce au réglage de projet application/config/project_settings_override.
const OVERRIDE_PATH := "user://override.cfg"

## Bus audio (créés au démarrage) : la musique et les effets ont leur volume.
const BUS_MUSIC := "Musique"
const BUS_EFFECTS := "Effets"

var data_dir := "user://"
var data: Dictionary = {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--data-dir="):
			data_dir = arg.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(data_dir)
	_create_buses()
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
	apply_volumes()


func save() -> void:
	write_json(path("app.json"), data)


func get_value(key: String) -> Variant:
	return data.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	data[key] = value
	save()
	if key == "fullscreen":
		apply_display()
	elif key.begins_with("volume_"):
		apply_volumes()
	elif key == "graphics":
		_write_renderer_override()


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


# ---------------- Son ----------------

func _create_buses() -> void:
	for bus_name in [BUS_MUSIC, BUS_EFFECTS]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, "Master")


func apply_volumes() -> void:
	for pair in [["Master", "volume_master"], [BUS_MUSIC, "volume_music"], [BUS_EFFECTS, "volume_effects"]]:
		var i := AudioServer.get_bus_index(pair[0])
		if i == -1:
			continue
		var v := clampf(float(get_value(pair[1])), 0.0, 1.0)
		AudioServer.set_bus_mute(i, v <= 0.001)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))


# ---------------- Graphismes ----------------

func graphics() -> int:
	return clampi(int(get_value("graphics")), Graphics.SIMPLE, Graphics.BEAU)


## Le mode « Beau » est-il réellement actif ? (Il demande un redémarrage, et
## l'ordinateur doit gérer Vulkan ou Direct3D 12 ; sinon Godot revient au rendu simple.)
static func advanced_renderer_active() -> bool:
	return RenderingServer.get_current_rendering_method() != "gl_compatibility"


## État du réglage des graphismes par rapport au moteur de rendu en cours :
## "" : appliqué ; "restart" : il faut relancer le jeu ; "unsupported" : le mode
## « Beau » a été demandé mais l'ordinateur ne le permet pas (Godot est revenu
## automatiquement au rendu simple).
func graphics_status() -> String:
	var want_advanced := graphics() == Graphics.BEAU
	var active := advanced_renderer_active()
	if want_advanced and not active:
		return "unsupported" if _started_with_override else "restart"
	if active and not want_advanced:
		return "restart"
	return ""


var _started_with_override := FileAccess.file_exists(OVERRIDE_PATH)


func _write_renderer_override() -> void:
	if graphics() == Graphics.BEAU:
		var cfg := ConfigFile.new()
		cfg.set_value("rendering", "renderer/rendering_method", "forward_plus")
		cfg.save(OVERRIDE_PATH)
	elif FileAccess.file_exists(OVERRIDE_PATH):
		DirAccess.remove_absolute(OVERRIDE_PATH)


## Relance le jeu (pour changer de moteur de rendu).
func restart() -> void:
	OS.set_restart_on_exit(true, OS.get_cmdline_args())
	get_tree().quit()


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
