class_name WordListsPanel
extends VBoxContainer
## Choix des listes de mots d'un profil (dans les réglages) : listes du jeu et
## listes personnelles, à cocher. Les boutons ouvrent l'éditeur de liste.

signal changed
signal edit_requested(list: Dictionary, readonly: bool)
signal new_requested
signal import_requested

var profile: Profile
var _rows: VBoxContainer
var _summary: Label
var _confirm_delete: ConfirmationDialog
var _pending_delete := ""


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var help := Ui.label("Coche les listes utilisées pendant les courses : les mots sont tirés au hasard parmi toutes les listes cochées.", 18, Color("#5f6470"))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(help)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	add_child(_rows)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	add_child(buttons)
	var new_btn := Ui.button("+ Nouvelle liste", 20, Color("#17b169"))
	new_btn.pressed.connect(func(): new_requested.emit())
	buttons.add_child(new_btn)
	var import_btn := Ui.button("Importer un fichier .txt", 20, Color("#2d7ff9"))
	import_btn.pressed.connect(func(): import_requested.emit())
	buttons.add_child(import_btn)
	_summary = Ui.label("", 18, Color("#5f6470"))
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_summary)
	_confirm_delete = ConfirmationDialog.new()
	_confirm_delete.ok_button_text = "Supprimer"
	_confirm_delete.cancel_button_text = "Annuler"
	_confirm_delete.confirmed.connect(func():
		profile.remove_list(_pending_delete)
		changed.emit()
		refresh())
	add_child(_confirm_delete)


func refresh() -> void:
	for c in _rows.get_children():
		c.queue_free()
	for l in profile.available_lists():
		_rows.add_child(_row(l))
	_update_summary()


func _row(l: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var cb := CheckBox.new()
	cb.text = "%s  (%d mots)" % [l.title, l.words.size()]
	cb.add_theme_font_size_override("font_size", 20)
	cb.button_pressed = profile.is_active(l.id)
	cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cb.toggled.connect(func(on):
		if not on and profile.active_list_infos().size() <= 1:
			cb.set_pressed_no_signal(true)
			_summary.text = "Il faut garder au moins une liste cochée."
			return
		profile.set_active(l.id, on)
		changed.emit()
		_update_summary())
	row.add_child(cb)
	var kind := Ui.label("Liste du jeu" if l.builtin else "Ma liste", 16, Color("#8d99ae") if l.builtin else Ui.ORANGE)
	kind.custom_minimum_size.x = 100
	row.add_child(kind)
	if l.builtin:
		var view := Ui.button("Voir / copier", 16, Color("#8d99ae"))
		view.custom_minimum_size.x = 210
		view.pressed.connect(func(): edit_requested.emit(l, true))
		row.add_child(view)
	else:
		var edit := Ui.button("Modifier", 16, Color("#2d7ff9"))
		edit.custom_minimum_size.x = 100
		edit.pressed.connect(func(): edit_requested.emit(l, false))
		row.add_child(edit)
		var del := Ui.button("Supprimer", 16, Ui.RED)
		del.custom_minimum_size.x = 100
		del.pressed.connect(func():
			_pending_delete = l.id
			_confirm_delete.dialog_text = "Supprimer la liste « %s » ?" % l.title
			_confirm_delete.popup_centered())
		row.add_child(del)
	return row


func _update_summary() -> void:
	var words := profile.words()
	var max_len := int(profile.get_setting("max_word_length"))
	var too_long := 0
	for w in words:
		if w.length() > max_len:
			too_long += 1
	var text := "En course : %d mots différents (%s)." % [words.size(), ", ".join(profile.active_titles())]
	if too_long > 0:
		text += " %d mots de plus de %d lettres ne seront pas proposés (réglage « Longueur max des mots »)." % [too_long, max_len]
	_summary.text = text
