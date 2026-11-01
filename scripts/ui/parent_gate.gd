class_name ParentGate
extends Control
## « Réservé aux adultes » : un petit calcul à résoudre avant d'ouvrir les
## réglages, pour que l'enfant ne les change pas seul. Désactivable dans les
## réglages (« Protéger les réglages », réglage de l'ordinateur « parent_lock »).

signal passed

const MIN_FACTOR := 6
const MAX_FACTOR := 9

var _a := 7
var _b := 8
var _question: Label
var _answer: LineEdit
var _message: Label
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ov := Ui.overlay(self, Vector2(560, 0))
	var box: VBoxContainer = ov[1]
	box.add_child(Ui.label("Réservé aux adultes", 34))
	var help := Ui.label("Pour ouvrir les réglages, résous ce calcul :", 20, Color("#5f6470"))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(help)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	_question = Ui.label("", 34)
	row.add_child(_question)
	_answer = LineEdit.new()
	_answer.max_length = 3
	_answer.custom_minimum_size.x = 120
	_answer.add_theme_font_size_override("font_size", 30)
	_answer.text_submitted.connect(func(_t): _validate())
	row.add_child(_answer)
	_message = Ui.label("", 18, Ui.RED)
	box.add_child(_message)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	var cancel := Ui.button("Annuler", 22, Color("#8d99ae"))
	cancel.pressed.connect(func(): visible = false)
	buttons.add_child(cancel)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	var ok := Ui.button("Valider", 24)
	ok.pressed.connect(_validate)
	buttons.add_child(ok)
	visible = false


## Un calcul « a × b » (deux nombres de MIN_FACTOR à MAX_FACTOR).
static func make_question(rng: RandomNumberGenerator) -> Array:
	return [rng.randi_range(MIN_FACTOR, MAX_FACTOR), rng.randi_range(MIN_FACTOR, MAX_FACTOR)]


static func is_correct(text: String, a: int, b: int) -> bool:
	var t := text.strip_edges()
	return t.is_valid_int() and int(t) == a * b


func open() -> void:
	_message.text = ""
	_new_question()
	visible = true
	_answer.grab_focus()


func _new_question() -> void:
	var q := make_question(_rng)
	_a = q[0]
	_b = q[1]
	_question.text = "%d × %d =" % [_a, _b]
	_answer.text = ""


func _validate() -> void:
	if is_correct(_answer.text, _a, _b):
		visible = false
		passed.emit()
	else:
		_message.text = "Ce n'est pas ça : voici un autre calcul."
		_new_question()
		_answer.grab_focus()
