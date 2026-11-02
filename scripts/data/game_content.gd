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


## Propriété du nœud racine d'un circuit, lue dans sa scène sans la
## construire (pour le menu) ; null si elle n'y est pas.
func track_property(index: int, property: String) -> Variant:
	var state := tracks[index].get_state()
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == property:
			return state.get_node_property_value(0, i)
	return null


## Tracé d'un circuit vu de dessus (plan XZ), lu dans sa scène sans la
## construire : pour les cartes du menu.
func track_outline(index: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var state := tracks[index].get_state()
	for n in state.get_node_count():
		if state.get_node_name(n) != "Path":
			continue
		for i in state.get_node_property_count(n):
			if state.get_node_property_name(n, i) == "curve":
				var c: Curve3D = (state.get_node_property_value(n, i) as Curve3D).duplicate()
				c.add_point(c.get_point_position(0), c.get_point_in(0), c.get_point_out(0))
				c.bake_interval = 2.0
				for p in c.get_baked_points():
					out.append(Vector2(p.x, p.z))
	return out


func track_title(index: int) -> String:
	var title: Variant = track_property(index, "title")
	return String(title) if title != null else "Circuit %d" % (index + 1)


func track_theme(index: int) -> TrackTheme:
	var theme: Variant = track_property(index, "track_theme")
	return theme if theme is TrackTheme else TrackTheme.new()


func word_list(id: String) -> WordList:
	for wl in word_lists:
		if wl.id == id:
			return wl
	return null


func default_word_list() -> WordList:
	return word_lists[0]
