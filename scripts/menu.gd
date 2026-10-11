class_name Menu
extends CanvasLayer
## Menu principal : prénom, choix du pilote, réglages (adulte), historique.

signal play_pressed
signal character_changed
signal settings_changed

const PRESETS := [["Très facile (≈ 10)", 10], ["Facile (≈ 20)", 20], ["Moyen (≈ 35)", 35],
	["Difficile (≈ 50)", 50], ["Expert (≈ 80)", 80]]
const PRESET_SPREAD := [0.8, 1.0, 1.2, 0.9, 1.1]

var root := Control.new()
var char_buttons := {}
var char_name_label: Label
var settings_layer: Control
var history_layer: Control
var history_grid: GridContainer
var history_status: Label
var bot_spins: Array[SpinBox] = []
var _controls := {}
var _words_edit: TextEdit
var _play_button: Button


func _ready() -> void:
	root.theme = Ui.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_build_main()
	_build_settings()
	_build_history()


func _build_main() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(36, 30)
	panel.custom_minimum_size = Vector2(540, 0)
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Ui.label("FunKart", 84, Ui.ORANGE, 18, Ui.NAVY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Ui.label("La course où l'on avance en tapant au clavier !", 22, Color("#5f6470"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(sub)

	box.add_child(Ui.label("Ton prénom", 28))
	var name_edit := LineEdit.new()
	name_edit.text = GameSettings.data.player_name
	name_edit.placeholder_text = "Prénom"
	name_edit.max_length = 16
	name_edit.add_theme_font_size_override("font_size", 32)
	name_edit.text_changed.connect(func(t): GameSettings.set_value("player_name", t.strip_edges()))
	name_edit.text_submitted.connect(func(_t): name_edit.release_focus())
	box.add_child(name_edit)

	box.add_child(Ui.label("Choisis ton pilote", 28))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for id in Characters.PLAYER_IDS:
		var b := Ui.button(Characters.ALL[id].name, 20)
		b.custom_minimum_size = Vector2(120, 56)
		b.pressed.connect(_select_character.bind(id))
		grid.add_child(b)
		char_buttons[id] = b
	_refresh_char_buttons()

	_play_button = Ui.button("JOUER !", 52, Color("#17b169"))
	_play_button.custom_minimum_size.y = 96
	_play_button.pressed.connect(func(): play_pressed.emit())
	box.add_child(_play_button)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	for item in [["Réglages (adulte)", _open_settings], ["Historique", _open_history], ["Quitter", _quit]]:
		var b := Ui.button(item[0], 20, Color("#8d99ae"))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(item[1])
		row.add_child(b)

	char_name_label = Ui.label("", 64, Color.WHITE, 18, Ui.NAVY)
	char_name_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	char_name_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	char_name_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	char_name_label.position += Vector2(-40, -30)
	root.add_child(char_name_label)
	_refresh_char_buttons()


func focus_play() -> void:
	_play_button.grab_focus()


func _select_character(id: String) -> void:
	GameSettings.set_value("character", id)
	_refresh_char_buttons()
	character_changed.emit()


func _refresh_char_buttons() -> void:
	for id in char_buttons:
		var c: Color = Characters.ALL[id].kart
		var selected: bool = id == GameSettings.data.character
		Ui.set_button_color(char_buttons[id], c, Color.WHITE if selected else Color.TRANSPARENT)
		char_buttons[id].scale = Vector2.ONE
	if char_name_label:
		char_name_label.text = Characters.get_info(GameSettings.data.character).name


func _quit() -> void:
	get_tree().quit()


# ---------------- Réglages ----------------

func _build_settings() -> void:
	var ov := Ui.overlay(root, Vector2(1040, 640))
	settings_layer = ov[0]
	var box: VBoxContainer = ov[1]
	box.add_child(Ui.label("Réglages (adulte)", 40))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 470
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 12)
	scroll.add_child(inner)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 10)
	inner.add_child(grid)

	_spin(grid, "Nombre de tours", "laps", 1, 10, 1)
	_spin(grid, "Nombre d'adversaires", "bot_count", 0, 5, 1)
	_spin(grid, "Pause entre deux mots (s)", "word_gap", 0, 20, 0.5)
	_spin(grid, "Durée d'un tour sans mot (s)", "lap_time", 8, 120, 1)
	_option(grid, "Ralentissement pendant un mot", "slow_factor", [["Léger", 0.7], ["Moyen", 0.4], ["Fort", 0.2]])
	_option(grid, "Puissance du turbo", "boost_factor", [["Petit", 1.4], ["Moyen", 1.8], ["Grand", 2.3]])
	_spin(grid, "Durée du turbo (s)", "boost_duration", 0, 10, 0.5)
	_spin(grid, "Longueur max des mots", "max_word_length", 2, 20, 1)
	_option(grid, "Taille du mot à l'écran", "text_size", [["Normale", 0], ["Grande", 1], ["Très grande", 2]])

	inner.add_child(Ui.label("Niveau des adversaires (frappes par minute)", 28))
	var help := Ui.label("Un adversaire réglé sur 30 frappes/min va à peu près aussi vite qu'un enfant qui tape 30 frappes/min.", 18, Color("#5f6470"))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(help)
	var bots_row := HBoxContainer.new()
	bots_row.add_theme_constant_override("separation", 14)
	inner.add_child(bots_row)
	var preset := OptionButton.new()
	preset.add_item("Préréglage…")
	for p in PRESETS:
		preset.add_item(p[0])
	preset.item_selected.connect(func(idx):
		if idx == 0:
			return
		var base: float = PRESETS[idx - 1][1]
		var kpm := []
		for k in PRESET_SPREAD:
			kpm.append(roundi(base * k))
		GameSettings.set_value("bot_kpm", kpm)
		_refresh_bot_spins()
		preset.select(0))
	bots_row.add_child(preset)
	for i in Characters.BOT_IDS.size():
		var col := VBoxContainer.new()
		bots_row.add_child(col)
		col.add_child(Ui.label(Characters.ALL[Characters.BOT_IDS[i]].name, 18))
		var sb := SpinBox.new()
		sb.min_value = 1
		sb.max_value = 400
		sb.value_changed.connect(func(v):
			var arr: Array = GameSettings.data.bot_kpm.duplicate()
			arr[i] = v
			GameSettings.set_value("bot_kpm", arr))
		col.add_child(sb)
		bot_spins.append(sb)

	var checks := GridContainer.new()
	checks.columns = 3
	inner.add_child(checks)
	_check(checks, "Mots en MAJUSCULES", "uppercase")
	_check(checks, "Accents facultatifs (e pour é)", "accents_tolerant")
	_check(checks, "Lire le mot à voix haute", "speak")
	_check(checks, "Sons", "sound")
	_check(checks, "Musique", "music")
	_check(checks, "Plein écran (F11)", "fullscreen")

	inner.add_child(Ui.label("Liste de mots (un mot par ligne)", 28))
	_words_edit = TextEdit.new()
	_words_edit.custom_minimum_size.y = 220
	_words_edit.add_theme_font_size_override("font_size", 22)
	_words_edit.text_changed.connect(func(): GameSettings.set_value("words", _words_edit.text))
	inner.add_child(_words_edit)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	var b1 := Ui.button("Rétablir la liste de mots", 20, Color("#8d99ae"))
	b1.pressed.connect(func():
		GameSettings.set_value("words", GameSettings.DEFAULT_WORDS)
		_refresh_settings())
	buttons.add_child(b1)
	var b2 := Ui.button("Tout réinitialiser", 20, Color("#8d99ae"))
	b2.pressed.connect(func():
		GameSettings.reset_all()
		_refresh_settings())
	buttons.add_child(b2)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	var close := Ui.button("Fermer", 26)
	close.pressed.connect(func():
		settings_layer.visible = false
		settings_changed.emit())
	buttons.add_child(close)
	settings_layer.visible = false


func _spin(grid: GridContainer, text: String, key: String, lo: float, hi: float, step: float) -> void:
	var l := Ui.label(text, 20)
	grid.add_child(l)
	var sb := SpinBox.new()
	sb.min_value = lo
	sb.max_value = hi
	sb.step = step
	sb.value_changed.connect(func(v):
		GameSettings.set_value(key, v)
		if key == "bot_count":
			_refresh_bot_spins())
	grid.add_child(sb)
	_controls[key] = sb


func _option(grid: GridContainer, text: String, key: String, items: Array) -> void:
	grid.add_child(Ui.label(text, 20))
	var ob := OptionButton.new()
	for it in items:
		ob.add_item(it[0])
	ob.item_selected.connect(func(idx): GameSettings.set_value(key, items[idx][1]))
	ob.set_meta("values", items.map(func(it): return it[1]))
	grid.add_child(ob)
	_controls[key] = ob


func _check(parent: Control, text: String, key: String) -> void:
	var cb := CheckBox.new()
	cb.text = text
	cb.add_theme_font_size_override("font_size", 20)
	cb.toggled.connect(func(on): GameSettings.set_value(key, on))
	parent.add_child(cb)
	_controls[key] = cb


func _refresh_settings() -> void:
	var d := GameSettings.data
	for key in _controls:
		var c = _controls[key]
		if c is SpinBox:
			c.set_value_no_signal(float(d[key]))
		elif c is CheckBox:
			c.set_pressed_no_signal(bool(d[key]))
		elif c is OptionButton:
			var values: Array = c.get_meta("values")
			var best := 0
			for i in values.size():
				if absf(float(values[i]) - float(d[key])) < absf(float(values[best]) - float(d[key])):
					best = i
			c.select(best)
	_words_edit.text = d.words
	_refresh_bot_spins()


func _refresh_bot_spins() -> void:
	var kpm: Array = GameSettings.data.bot_kpm
	for i in bot_spins.size():
		bot_spins[i].set_value_no_signal(float(kpm[i]) if i < kpm.size() else 20.0)
		bot_spins[i].editable = i < int(GameSettings.data.bot_count)


func _open_settings() -> void:
	_refresh_settings()
	settings_layer.visible = true


# ---------------- Historique ----------------

func _build_history() -> void:
	var ov := Ui.overlay(root, Vector2(1100, 600))
	history_layer = ov[0]
	var box: VBoxContainer = ov[1]
	box.add_child(Ui.label("Historique des courses", 40))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 420
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	history_grid = GridContainer.new()
	history_grid.columns = 8
	history_grid.add_theme_constant_override("h_separation", 22)
	history_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(history_grid)
	history_status = Ui.label("", 18, Color("#5f6470"))
	history_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(history_status)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	var export_btn := Ui.button("Exporter (CSV)", 20, Color("#2d7ff9"))
	export_btn.pressed.connect(func():
		var path := History.export_csv()
		history_status.text = ("Fichier enregistré : " + path) if path != "" else "Impossible d'enregistrer le fichier.")
	buttons.add_child(export_btn)
	var open := Ui.button("Ouvrir le dossier", 20, Color("#8d99ae"))
	open.pressed.connect(func():
		var path := History.export_csv()
		if path != "":
			OS.shell_show_in_file_manager(path))
	buttons.add_child(open)
	var clear := Ui.button("Effacer l'historique", 20, Color("#8d99ae"))
	var confirm := ConfirmationDialog.new()
	confirm.dialog_text = "Effacer tout l'historique des courses ?"
	confirm.ok_button_text = "Effacer"
	confirm.cancel_button_text = "Annuler"
	confirm.confirmed.connect(func():
		History.clear()
		_refresh_history())
	root.add_child(confirm)
	clear.pressed.connect(func(): confirm.popup_centered())
	buttons.add_child(clear)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	var close := Ui.button("Fermer", 26)
	close.pressed.connect(func(): history_layer.visible = false)
	buttons.add_child(close)
	history_layer.visible = false


func _refresh_history() -> void:
	for c in history_grid.get_children():
		c.queue_free()
	for h in ["Date", "Prénom", "Place", "Frappes/min", "Précision", "Mots", "Temps/mot", "Adversaires"]:
		history_grid.add_child(Ui.label(h, 20, Ui.ORANGE))
	var all := History.load_all()
	all.reverse()
	for h in all.slice(0, 200):
		var date := String(h.get("date", "")).replace("T", " ").substr(0, 16)
		var bots := " / ".join(PackedStringArray(Array(h.get("bot_kpm", [])).map(func(v): return str(int(v)))))
		var cells := [date, h.get("name", "—"), "%d/%d" % [int(h.get("place", 0)), int(h.get("total", 0))],
			str(roundi(float(h.get("kpm", 0)))), "%d %%" % roundi(float(h.get("accuracy", 0)) * 100.0),
			str(int(h.get("words", 0))), "%.1f s" % float(h.get("avg_word_time", 0)), bots if bots != "" else "—"]
		for c in cells:
			history_grid.add_child(Ui.label(str(c), 18))
	history_status.text = "" if not all.is_empty() else "Aucune course pour le moment."


func _open_history() -> void:
	_refresh_history()
	history_layer.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if settings_layer.visible:
			settings_layer.visible = false
			settings_changed.emit()
		history_layer.visible = false
