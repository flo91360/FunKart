class_name WordListEditor
extends Control
## Fenêtre d'édition d'une liste de mots : nom, mots (un par ligne, ou séparés
## par des espaces ou des virgules), import et export en fichier texte.
## Les listes du jeu s'ouvrent en lecture seule et peuvent être copiées.

signal saved

var profile: Profile
var _list_id := "" # "" : nouvelle liste
var _readonly := false
var _header: Label
var _name_edit: LineEdit
var _text: TextEdit
var _count: Label
var _save_btn: Button
var _copy_btn: Button
var _export_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ov := Ui.overlay(self, Vector2(820, 600))
	var box: VBoxContainer = ov[1]
	_header = Ui.label("", 34)
	box.add_child(_header)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	box.add_child(name_row)
	name_row.add_child(Ui.label("Nom", 22))
	_name_edit = LineEdit.new()
	_name_edit.max_length = 40
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_edit)
	var help := Ui.label("Un mot par ligne (ou séparés par des espaces ou des virgules). Les chiffres et symboles sont ignorés.", 17, Color("#5f6470"))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(help)
	_text = TextEdit.new()
	_text.custom_minimum_size.y = 300
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("font_size", 22)
	_text.text_changed.connect(_update_count)
	box.add_child(_text)
	_count = Ui.label("", 18, Color("#5f6470"))
	_count.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_count)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	_export_btn = Ui.button("Exporter (.txt)", 18, Color("#8d99ae"))
	_export_btn.pressed.connect(export_file)
	buttons.add_child(_export_btn)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	_copy_btn = Ui.button("Copier dans mes listes", 20, Color("#2d7ff9"))
	_copy_btn.pressed.connect(func(): open_new(profile, _name_edit.text + " (copie)", _text.text))
	buttons.add_child(_copy_btn)
	_save_btn = Ui.button("Enregistrer", 22, Color("#17b169"))
	_save_btn.pressed.connect(save)
	buttons.add_child(_save_btn)
	var close := Ui.button("Annuler", 20, Color("#8d99ae"))
	close.pressed.connect(func(): visible = false)
	buttons.add_child(close)
	visible = false


func open_list(p: Profile, l: Dictionary, readonly: bool) -> void:
	profile = p
	_list_id = "" if readonly else String(l.id)
	_readonly = readonly
	_header.text = "Liste du jeu" if readonly else "Modifier la liste"
	_fill(String(l.title), "\n".join(l.words))


func open_new(p: Profile, title := "Nouvelle liste", text := "") -> void:
	profile = p
	_list_id = ""
	_readonly = false
	_header.text = "Nouvelle liste"
	_fill(title, text)


func _fill(title: String, text: String) -> void:
	_name_edit.text = title
	_text.text = text
	_name_edit.editable = not _readonly
	_text.editable = not _readonly
	_save_btn.visible = not _readonly
	_copy_btn.visible = _readonly
	_update_count()
	visible = true
	if not _readonly:
		_text.grab_focus()


func _update_count() -> void:
	var words := WordList.parse(_text.text)
	var max_len := int(profile.get_setting("max_word_length")) if profile else 99
	var too_long := 0
	for w in words:
		if w.length() > max_len:
			too_long += 1
	var t := "%d mots" % words.size()
	if too_long > 0:
		t += " — %d de plus de %d lettres ne seront pas proposés (réglage « Longueur max des mots »)" % [too_long, max_len]
	_count.text = t
	_count.add_theme_color_override("font_color", Color("#5f6470"))


func save() -> void:
	var words := WordList.parse(_text.text)
	if words.is_empty():
		_count.text = "La liste est vide : écris au moins un mot."
		_count.add_theme_color_override("font_color", Ui.RED)
		return
	var title := _name_edit.text.strip_edges()
	if title == "":
		title = "Ma liste"
	if _list_id == "":
		var l := profile.add_list(title, words)
		profile.set_active(l.id, true)
	else:
		profile.update_list(_list_id, title, words)
	Profiles.save_profile(profile)
	visible = false
	saved.emit()


# ---------------- Fichiers texte ----------------

func _file_dialog(mode: FileDialog.FileMode) -> FileDialog:
	var fd := FileDialog.new()
	fd.file_mode = mode
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.use_native_dialog = true
	fd.filters = PackedStringArray(["*.txt ; Fichier texte"])
	var docs := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if docs != "":
		fd.current_dir = docs
	fd.canceled.connect(fd.queue_free)
	add_child(fd)
	return fd


## Importer : ouvre un fichier texte et propose son contenu comme nouvelle liste.
func import_file(p: Profile) -> void:
	profile = p
	var fd := _file_dialog(FileDialog.FILE_MODE_OPEN_FILE)
	fd.file_selected.connect(func(path: String):
		fd.queue_free()
		open_new(p, path.get_file().get_basename(), FileAccess.get_file_as_string(path)))
	fd.popup_centered_ratio(0.7)


func export_file() -> void:
	var fd := _file_dialog(FileDialog.FILE_MODE_SAVE_FILE)
	fd.current_file = (_name_edit.text.strip_edges() if _name_edit.text.strip_edges() != "" else "mots") + ".txt"
	var content := "\n".join(WordList.parse(_text.text))
	fd.file_selected.connect(func(path: String):
		fd.queue_free()
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(content + "\n")
			_count.text = "Liste enregistrée dans " + path
		else:
			_count.text = "Impossible d'enregistrer le fichier.")
	fd.popup_centered_ratio(0.7)
