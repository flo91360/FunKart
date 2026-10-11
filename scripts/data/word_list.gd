@tool
class_name WordList
extends Resource
## Liste de mots à taper.

@export var id := ""
@export var title := ""
@export var words := PackedStringArray()


## Un mot par ligne ; tout ce qui suit le premier espace est ignoré.
static func parse(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for line in text.split("\n"):
		var w := line.strip_edges().get_slice(" ", 0).strip_edges()
		if w != "":
			out.append(w)
	return out
