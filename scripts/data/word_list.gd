@tool
class_name WordList
extends Resource
## Liste de mots à taper (listes livrées avec le jeu : data/words).

@export var id := ""
@export var title := ""
@export var words := PackedStringArray()

## Lettres absentes du clavier AZERTY standard : remplacées par ce qui se tape.
const REPLACEMENTS := {"œ": "oe", "Œ": "Oe", "æ": "ae", "Æ": "Ae", "ß": "ss", "’": "'"}


## Le mot tel qu'il peut être tapé au clavier (« cœur » -> « coeur »).
static func typeable(word: String) -> String:
	for k in REPLACEMENTS:
		word = word.replace(k, REPLACEMENTS[k])
	return word


## Découpe un texte en mots : séparés par des retours à la ligne, espaces,
## virgules ou points-virgules (pratique pour coller une liste). Ne garde que
## les lettres, l'apostrophe et le trait d'union ; ignore les doublons et ce
## qui ne contient aucune lettre (nombres, emojis…).
static func parse(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	var cleaned := text.replace("﻿", "")
	for sep in [",", ";", "\t", "\r", "\n"]:
		cleaned = cleaned.replace(sep, " ")
	for token in typeable(cleaned).split(" ", false):
		var w := ""
		var has_letter := false
		for ch in token:
			if is_letter(ch):
				w += ch
				has_letter = true
			elif ch == "'" or ch == "’" or ch == "-":
				w += "'" if ch == "’" else ch
		w = w.trim_prefix("-").trim_suffix("-").trim_prefix("'").trim_suffix("'")
		if has_letter and w != "" and not out.has(w):
			out.append(w)
	return out


static func is_letter(ch: String) -> bool:
	return ch.to_lower() != ch.to_upper() or ch in "ßœæ"
