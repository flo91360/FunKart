class_name Profile
extends RefCounted
## Le profil d'un enfant : prénom, pilote, réglages de course, listes de mots.
## Enregistré en JSON dans <données>/profiles/<id>/profile.json ; l'historique
## des courses est à côté, dans history.json.
##
## Listes de mots : l'enfant joue avec une ou plusieurs listes « actives »,
## choisies parmi les listes livrées avec le jeu (data/words, identifiants
## comme "base" ou "animaux") et ses listes personnelles (identifiants "perso_…").

const VERSION := 2

## Réglages pédagogiques (propres à chaque enfant).
const DEFAULT_SETTINGS := {
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
}

var id := ""
var name := ""
var character_id := "chat"
var track_index := 0
var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
## Listes personnelles : [{ "id": "perso_…", "title": String, "words": Array[String] }].
var word_lists: Array = []
## Identifiants des listes utilisées pendant les courses.
var active_lists: Array = ["base"]


static func create(p_name: String) -> Profile:
	var p := Profile.new()
	p.id = "p%d_%d" % [int(Time.get_unix_time_from_system()), randi() % 100000]
	p.name = p_name
	return p


func get_setting(key: String) -> Variant:
	return settings.get(key, DEFAULT_SETTINGS.get(key))


# ---------------- Listes de mots ----------------

## Toutes les listes que l'enfant peut choisir : celles du jeu puis les siennes.
## Chaque élément : { id, title, words (PackedStringArray), builtin (bool) }.
func available_lists() -> Array:
	var out := []
	for wl in GameContent.get_content().word_lists:
		out.append({"id": wl.id, "title": wl.title, "words": wl.words, "builtin": true})
	for l in word_lists:
		out.append({"id": l.id, "title": l.title, "words": PackedStringArray(l.words), "builtin": false})
	return out


func find_list(list_id: String) -> Dictionary:
	for l in available_lists():
		if l.id == list_id:
			return l
	return {}


func is_active(list_id: String) -> bool:
	return active_lists.has(list_id)


func set_active(list_id: String, on: bool) -> void:
	if on and not active_lists.has(list_id):
		active_lists.append(list_id)
	elif not on:
		active_lists.erase(list_id)


## Listes actives qui existent encore (une liste personnelle a pu être supprimée).
func active_list_infos() -> Array:
	var out := []
	for l in available_lists():
		if active_lists.has(l.id):
			out.append(l)
	return out


func active_titles() -> PackedStringArray:
	var out := PackedStringArray()
	for l in active_list_infos():
		out.append(l.title)
	return out


## Les mots de la course : tous les mots des listes actives, sans doublon.
## Sans liste active (ou si elles sont vides), la liste de base du jeu.
func words() -> PackedStringArray:
	var out := PackedStringArray()
	for l in active_list_infos():
		for w in l.words:
			if not out.has(w):
				out.append(w)
	if out.is_empty():
		out = GameContent.get_content().default_word_list().words
	return out


func add_list(title: String, list_words: PackedStringArray) -> Dictionary:
	var l := {
		"id": "perso_%d_%d" % [int(Time.get_unix_time_from_system()), randi() % 1000000],
		"title": title, "words": Array(list_words),
	}
	word_lists.append(l)
	return l


func update_list(list_id: String, title: String, list_words: PackedStringArray) -> void:
	for l in word_lists:
		if l.id == list_id:
			l.title = title
			l.words = Array(list_words)


func remove_list(list_id: String) -> void:
	for l in word_lists.duplicate():
		if l.id == list_id:
			word_lists.erase(l)
	active_lists.erase(list_id)
	if active_lists.is_empty():
		active_lists.append(GameContent.get_content().default_word_list().id)


# ---------------- Enregistrement ----------------

func to_dict() -> Dictionary:
	return {
		"version": VERSION, "id": id, "name": name, "character_id": character_id,
		"track_index": track_index, "settings": settings,
		"word_lists": word_lists, "active_lists": active_lists,
	}


static func from_dict(d: Dictionary) -> Profile:
	var p := Profile.new()
	p.id = String(d.get("id", ""))
	p.name = String(d.get("name", ""))
	p.character_id = String(d.get("character_id", "chat"))
	p.track_index = int(d.get("track_index", 0))
	var s: Variant = d.get("settings", {})
	if s is Dictionary:
		for key in s:
			if p.settings.has(key):
				p.settings[key] = s[key]
	var wl: Variant = d.get("word_lists", [])
	var lists: Array = wl if wl is Array else []
	if int(d.get("version", 1)) < 2:
		p._migrate_word_lists_v1(lists, int(d.get("active_word_list", 0)))
	else:
		for l in lists:
			if l is Dictionary and l.has("id"):
				p.word_lists.append({"id": String(l.id), "title": String(l.get("title", "")),
					"words": Array(l.get("words", []))})
		var act: Variant = d.get("active_lists", ["base"])
		p.active_lists = act if act is Array else ["base"]
	return p


## Version 1 : une seule liste choisie parmi les listes du profil (la liste de
## base y était recopiée). Une copie identique à la liste de base redevient la
## liste de base du jeu ; les autres deviennent des listes personnelles.
func _migrate_word_lists_v1(lists: Array, active_index: int) -> void:
	var base := GameContent.get_content().default_word_list()
	active_lists = []
	for i in lists.size():
		var l: Variant = lists[i]
		if not (l is Dictionary):
			continue
		var list_words := PackedStringArray(l.get("words", []))
		var list_id: String = base.id
		if list_words != base.words:
			list_id = add_list(String(l.get("title", "Ma liste")), list_words).id
		if i == active_index and not active_lists.has(list_id):
			active_lists.append(list_id)
	if active_lists.is_empty():
		active_lists.append(base.id)
