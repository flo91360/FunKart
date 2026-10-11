class_name Profile
extends RefCounted
## Le profil d'un enfant : prénom, pilote, réglages de course, listes de mots.
## Enregistré en JSON dans <données>/profiles/<id>/profile.json ; l'historique
## des courses est à côté, dans history.json.

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
## Listes de mots de l'enfant : [{ "title": String, "words": Array[String] }].
var word_lists: Array = []
var active_word_list := 0


static func create(p_name: String) -> Profile:
	var p := Profile.new()
	p.id = "p%d_%d" % [int(Time.get_unix_time_from_system()), randi() % 100000]
	p.name = p_name
	var base := GameContent.get_content().default_word_list()
	p.word_lists = [{"title": base.title, "words": Array(base.words)}]
	return p


func words() -> PackedStringArray:
	if word_lists.is_empty():
		return GameContent.get_content().default_word_list().words
	var list: Dictionary = word_lists[clampi(active_word_list, 0, word_lists.size() - 1)]
	return PackedStringArray(list.get("words", []))


func set_words(words_array: PackedStringArray) -> void:
	if word_lists.is_empty():
		word_lists.append({"title": "Ma liste", "words": []})
	word_lists[clampi(active_word_list, 0, word_lists.size() - 1)]["words"] = Array(words_array)


func get_setting(key: String) -> Variant:
	return settings.get(key, DEFAULT_SETTINGS.get(key))


func to_dict() -> Dictionary:
	return {
		"version": 1, "id": id, "name": name, "character_id": character_id,
		"track_index": track_index, "settings": settings,
		"word_lists": word_lists, "active_word_list": active_word_list,
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
	p.word_lists = wl if wl is Array else []
	p.active_word_list = int(d.get("active_word_list", 0))
	return p
