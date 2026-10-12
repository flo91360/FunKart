@tool
class_name CharacterData
extends Resource
## Un pilote : un animal construit à partir de formes simples.
## Ces fiches sont modifiables dans l'éditeur Godot (dossier data/characters)
## et serviront de base à l'éditeur de personnages.

const EARS := ["none", "cat", "round", "floppy", "long", "mouse", "monkey"]
const EXTRAS := ["none", "unicorn", "panda", "lion", "penguin", "turtle", "frog", "monkey"]

@export var id := ""
@export var display_name := ""
## Personnage proposé à l'enfant (sinon : adversaire uniquement).
@export var playable := true
@export_group("Couleurs")
@export var fur_color := Color.WHITE
@export var kart_color := Color.RED
@export var shirt_color := Color.BLUE
@export_group("Tête")
@export_enum("none", "cat", "round", "floppy", "long", "mouse", "monkey") var ears := "none"
@export var ear_color := Color.WHITE
@export var has_snout := false
@export var snout_color := Color.WHITE
@export_enum("none", "unicorn", "panda", "lion", "penguin", "turtle", "frog", "monkey") var extra := "none"


func to_dict() -> Dictionary:
	return {
		"id": id, "display_name": display_name, "playable": playable,
		"fur_color": fur_color.to_html(), "kart_color": kart_color.to_html(),
		"shirt_color": shirt_color.to_html(), "ears": ears, "ear_color": ear_color.to_html(),
		"has_snout": has_snout, "snout_color": snout_color.to_html(), "extra": extra,
	}


static func from_dict(d: Dictionary) -> CharacterData:
	var c := CharacterData.new()
	c.id = String(d.get("id", ""))
	c.display_name = String(d.get("display_name", ""))
	c.playable = bool(d.get("playable", true))
	c.fur_color = Color(String(d.get("fur_color", "ffffff")))
	c.kart_color = Color(String(d.get("kart_color", "ff0000")))
	c.shirt_color = Color(String(d.get("shirt_color", "0000ff")))
	c.ears = String(d.get("ears", "none"))
	c.ear_color = Color(String(d.get("ear_color", "ffffff")))
	c.has_snout = bool(d.get("has_snout", false))
	c.snout_color = Color(String(d.get("snout_color", "ffffff")))
	c.extra = String(d.get("extra", "none"))
	return c
