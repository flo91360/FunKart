class_name KeyboardView
extends Control
## Clavier AZERTY à l'écran : chaque touche a la couleur du doigt qui doit la
## taper, et la touche attendue est surlignée. Désactivable dans les réglages
## (« Clavier à l'écran ») quand l'enfant n'en a plus besoin.

## Rangées du clavier AZERTY français (touches qui produisent un caractère).
const ROWS := [
	["²", "&", "é", "\"", "'", "(", "-", "è", "_", "ç", "à", ")", "="],
	["a", "z", "e", "r", "t", "y", "u", "i", "o", "p", "^", "$"],
	["q", "s", "d", "f", "g", "h", "j", "k", "l", "m", "ù", "*"],
	["<", "w", "x", "c", "v", "b", "n", ",", ";", ":", "!"],
]
## Décalage de chaque rangée (en largeur de touche), comme sur un vrai clavier.
const ROW_OFFSET := [0.0, 0.5, 0.75, 0.25]
## Doigt de chaque touche (voir FINGER_NAMES).
const ROW_FINGERS := [
	[0, 0, 1, 2, 3, 3, 4, 4, 5, 6, 7, 7, 7],
	[0, 1, 2, 3, 3, 4, 4, 5, 6, 7, 7, 7],
	[0, 1, 2, 3, 3, 4, 4, 5, 6, 7, 7, 7],
	[0, 0, 1, 2, 3, 3, 4, 4, 5, 6, 7],
]
const THUMB := 8
const FINGER_NAMES := ["auriculaire gauche", "annulaire gauche", "majeur gauche", "index gauche",
	"index droit", "majeur droit", "annulaire droit", "auriculaire droit", "pouce"]
## Une couleur par doigt, la même pour la main gauche et la main droite.
const FINGER_COLORS := [Color("#cdb4ff"), Color("#a0c4ff"), Color("#b9f2c0"), Color("#ffd6a5"),
	Color("#ffd6a5"), Color("#b9f2c0"), Color("#a0c4ff"), Color("#cdb4ff"), Color("#dfe3ea")]
## Lettres qui se tapent en deux temps : accent (touche ^, ou Maj + ^ pour le
## tréma), puis la lettre.
const DEAD_KEYS := {
	"â": "a", "ê": "e", "î": "i", "ô": "o", "û": "u",
	"ä": "a", "ë": "e", "ï": "i", "ö": "o", "ü": "u", "ÿ": "y",
}
const TREMA := "äëïöüÿ"

const KEY := 30.0 # taille d'une touche
const GAP := 3.0
const SPACE_HEIGHT := 16.0

var _highlight: Array = [] # touches à montrer
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var width := (13.0 + 0.25) * (KEY + GAP)
	custom_minimum_size = Vector2(width, ROWS.size() * (KEY + GAP) + SPACE_HEIGHT + GAP)


## Doigt (index dans FINGER_NAMES) d'une touche, ou -1 si elle n'est pas sur le clavier.
static func finger_of(key: String) -> int:
	if key == " ":
		return THUMB
	for r in ROWS.size():
		var i: int = ROWS[r].find(key)
		if i != -1:
			return ROW_FINGERS[r][i]
	return -1


## Touches à appuyer pour obtenir ce caractère (« ê » : « ^ » puis « e »).
static func keys_for(ch: String) -> Array:
	var c := ch.to_lower()
	if DEAD_KEYS.has(c):
		return ["^", DEAD_KEYS[c]]
	if finger_of(c) != -1:
		return [c]
	return []


## Comment taper ce caractère : « index gauche », ou « ^ puis e (majeur gauche) »
## pour une lettre avec accent circonflexe ; "" s'il n'est pas sur le clavier.
static func finger_hint(ch: String) -> String:
	var keys := keys_for(ch)
	if keys.is_empty():
		return ""
	var finger: String = FINGER_NAMES[finger_of(keys.back())]
	if keys.size() == 1:
		return finger
	return "%s^ puis %s (%s)" % ["Maj + " if ch.to_lower() in TREMA else "", keys.back(), finger]


func show_char(ch: String) -> void:
	_highlight = keys_for(ch)
	queue_redraw()


func clear() -> void:
	_highlight = []
	queue_redraw()


func _process(delta: float) -> void:
	if visible and not _highlight.is_empty():
		_t += delta
		queue_redraw()


func _draw() -> void:
	var font := Ui.font()
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	for r in ROWS.size():
		var y: float = r * (KEY + GAP)
		for i in ROWS[r].size():
			var key: String = ROWS[r][i]
			var x: float = (ROW_OFFSET[r] + i) * (KEY + GAP)
			_draw_key(Rect2(x, y, KEY, KEY), key, ROW_FINGERS[r][i], font, pulse)
	# barre d'espace (pouces)
	var sy := ROWS.size() * (KEY + GAP)
	_draw_key(Rect2(3.5 * (KEY + GAP), sy, 6.0 * (KEY + GAP) - GAP, SPACE_HEIGHT), "", THUMB, font, pulse)


func _draw_key(rect: Rect2, key: String, finger: int, font: Font, pulse: float) -> void:
	var on := _highlight.has(key) and key != ""
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(6)
	if on:
		box.bg_color = Ui.YELLOW
		box.border_color = Ui.INK
		box.set_border_width_all(2 + int(round(pulse * 2.0)))
		rect = rect.grow(1.0 + pulse * 2.0)
	else:
		box.bg_color = FINGER_COLORS[finger]
		box.bg_color.a = 0.85
	draw_style_box(box, rect)
	if key in ["f", "j"]:
		# repères des index, comme les petites bosses du vrai clavier
		draw_line(rect.position + Vector2(rect.size.x * 0.35, rect.size.y - 5), rect.position + Vector2(rect.size.x * 0.65, rect.size.y - 5), Ui.INK, 2.0)
	if key != "":
		var fs := 18 if on else 15
		var base := rect.position + Vector2(0, rect.size.y / 2.0 + fs * 0.35)
		draw_string(font, base, key, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fs, Ui.INK)
