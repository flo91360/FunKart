@tool
class_name GameContent
extends Resource
## Catalogue du contenu livré avec le jeu (data/content.tres).

@export var characters: Array[CharacterData] = []
## Scènes de circuits (racine : Track).
@export var tracks: Array[PackedScene] = []
@export var word_lists: Array[WordList] = []

const PATH := "res://data/content.tres"
static var _instance: GameContent


static func get_content() -> GameContent:
	if _instance == null:
		_instance = load(PATH)
	return _instance


func character(id: String) -> CharacterData:
	for c in characters:
		if c.id == id:
			return c
	return characters[0]


func playable_characters() -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	for c in characters:
		if c.playable:
			out.append(c)
	return out


func bot_characters() -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	for c in characters:
		if not c.playable:
			out.append(c)
	return out


func default_word_list() -> WordList:
	return word_lists[0]
