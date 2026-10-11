extends Node
## Réglages persistants du jeu (autoload « GameSettings »).
## Ils sont enregistrés dans le dossier utilisateur de Godot (user://settings.json).

const PATH := "user://settings.json"

const DEFAULT_WORDS := """banane
champignon
étoile
ballon
cadeau
pomme
cerise
fraise
citron
tomate
kart
turbo
fusée
drapeau
coupe
auto
moto
bus
vélo
camion
route
piste
virage
bonbon
gâteau
glace
chat
chien
lapin
tortue
renard
poisson
oiseau
cheval
soleil
lune
nuage
fleur
arbre
feu
eau
jeu
bravo
vite"""

const DEFAULTS := {
	"player_name": "",
	"character": "chat",
	"laps": 3,
	"bot_count": 3,
	"bot_kpm": [16, 20, 24, 18, 22],
	"lap_time": 20.0,
	"word_gap": 2.5,
	"slow_factor": 0.4,
	"boost_factor": 1.8,
	"boost_duration": 2.0,
	"max_word_length": 8,
	"uppercase": false,
	"accents_tolerant": true,
	"text_size": 1,
	"speak": false,
	"sound": true,
	"music": true,
	"fullscreen": false,
	"words": DEFAULT_WORDS,
}

var data: Dictionary = {}


func _ready() -> void:
	data = DEFAULTS.duplicate(true)
	if FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			for key in parsed:
				if data.has(key):
					data[key] = parsed[key]
	apply_display()


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func set_value(key: String, value: Variant) -> void:
	data[key] = value
	save()
	if key == "fullscreen":
		apply_display()


func reset_all() -> void:
	var keep_name: Variant = data.get("player_name", "")
	var keep_char: Variant = data.get("character", "chat")
	data = DEFAULTS.duplicate(true)
	data["player_name"] = keep_name
	data["character"] = keep_char
	save()
	apply_display()


func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if data.get("fullscreen", false) else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


## Liste de mots : un mot par ligne (tout ce qui suit le premier espace est ignoré).
func word_list() -> PackedStringArray:
	var out := PackedStringArray()
	for line in String(data.get("words", "")).split("\n"):
		var w := line.strip_edges().get_slice(" ", 0).strip_edges()
		if w != "":
			out.append(w)
	return out
