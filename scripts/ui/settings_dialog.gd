class_name SettingsDialog
extends Control
## Fenêtre « Réglages (adulte) » : réglages du profil sélectionné (niveau,
## mots, affichage) et réglages de l'ordinateur (son, plein écran).
## Le formulaire est construit à partir des listes de champs ci-dessous.

signal closed
signal profile_deleted

const PRESETS := [["Très facile (≈ 10)", 10], ["Facile (≈ 20)", 20], ["Moyen (≈ 35)", 35],
	["Difficile (≈ 50)", 50], ["Expert (≈ 80)", 80]]
const PRESET_SPREAD := [0.8, 1.0, 1.2, 0.9, 1.1]

var profile: Profile
var _title: Label
var _name_edit: LineEdit
var _delete_button: Button
var _controls := {} # clé du réglage -> contrôle
var _app_checks := {} # clé du réglage de l'ordinateur -> CheckBox
var _bot_spins: Array[SpinBox] = []
var _word_lists: WordListsPanel
var _list_editor: WordListEditor
var _confirm_delete: ConfirmationDialog
var _volumes: VolumeSliders
var _graphics: OptionButton
var _graphics_status: Label
var _restart_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ov := Ui.overlay(self, Vector2(1060, 650))
	var box: VBoxContainer = ov[1]
	_title = Ui.label("Réglages", 38)
	box.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 480
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 12)
	scroll.add_child(inner)

	# Profil
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	inner.add_child(name_row)
	name_row.add_child(Ui.label("Prénom", 22))
	_name_edit = LineEdit.new()
	_name_edit.max_length = 16
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_changed.connect(func(t):
		profile.name = t.strip_edges()
		_save())
	name_row.add_child(_name_edit)
	_delete_button = Ui.button("Supprimer ce profil", 18, Ui.RED)
	_delete_button.pressed.connect(func(): _confirm_delete.popup_centered())
	name_row.add_child(_delete_button)
	_confirm_delete = ConfirmationDialog.new()
	_confirm_delete.ok_button_text = "Supprimer"
	_confirm_delete.cancel_button_text = "Annuler"
	_confirm_delete.confirmed.connect(func():
		Profiles.delete(profile)
		visible = false
		profile_deleted.emit())
	add_child(_confirm_delete)

	# Course
	inner.add_child(_section("Course"))
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

	# Adversaires
	inner.add_child(_section("Niveau des adversaires (frappes par minute)"))
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
		profile.settings["bot_kpm"] = kpm
		_save()
		_refresh_bot_spins()
		preset.select(0))
	bots_row.add_child(preset)
	var bot_chars := GameContent.get_content().bot_characters()
	for i in bot_chars.size():
		var col := VBoxContainer.new()
		bots_row.add_child(col)
		col.add_child(Ui.label(bot_chars[i].display_name, 18))
		var sb := SpinBox.new()
		sb.min_value = 1
		sb.max_value = 400
		sb.value_changed.connect(func(v):
			var arr: Array = profile.get_setting("bot_kpm").duplicate()
			while arr.size() <= i:
				arr.append(20)
			arr[i] = v
			profile.settings["bot_kpm"] = arr
			_save())
		col.add_child(sb)
		_bot_spins.append(sb)

	# Affichage et aide
	inner.add_child(_section("Affichage et aide"))
	var checks := GridContainer.new()
	checks.columns = 3
	inner.add_child(checks)
	_check(checks, "Mots en MAJUSCULES", "uppercase")
	_check(checks, "Accents facultatifs (e pour é)", "accents_tolerant")
	_check(checks, "Lire le mot à voix haute", "speak")

	# Mots
	inner.add_child(_section("Listes de mots"))
	_word_lists = WordListsPanel.new()
	_word_lists.changed.connect(_save)
	_word_lists.new_requested.connect(func(): _list_editor.open_new(profile))
	_word_lists.import_requested.connect(func(): _list_editor.import_file(profile))
	_word_lists.edit_requested.connect(func(l, readonly): _list_editor.open_list(profile, l, readonly))
	inner.add_child(_word_lists)

	# Ordinateur
	inner.add_child(_section("Cet ordinateur (tous les profils)"))
	var app_row := HBoxContainer.new()
	app_row.add_theme_constant_override("separation", 24)
	inner.add_child(app_row)
	for item in [["Sons", "sound"], ["Musique", "music"], ["Plein écran (F11)", "fullscreen"]]:
		var cb := CheckBox.new()
		cb.text = item[0]
		cb.add_theme_font_size_override("font_size", 20)
		var key: String = item[1]
		cb.toggled.connect(func(on): AppSettings.set_value(key, on))
		app_row.add_child(cb)
		_app_checks[key] = cb
	_volumes = VolumeSliders.new()
	inner.add_child(_volumes)
	var gfx_row := HBoxContainer.new()
	gfx_row.add_theme_constant_override("separation", 14)
	inner.add_child(gfx_row)
	gfx_row.add_child(Ui.label("Graphismes", 22))
	_graphics = OptionButton.new()
	for g in AppSettings.GRAPHICS_NAMES:
		_graphics.add_item(g)
	_graphics.item_selected.connect(func(idx):
		AppSettings.set_value("graphics", idx)
		_refresh_graphics())
	gfx_row.add_child(_graphics)
	_restart_button = Ui.button("Relancer le jeu", 20, Color("#2d7ff9"))
	_restart_button.pressed.connect(func(): AppSettings.restart())
	gfx_row.add_child(_restart_button)
	_graphics_status = Ui.label("", 18, Color("#5f6470"))
	_graphics_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(_graphics_status)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	var b2 := Ui.button("Réglages par défaut", 20, Color("#8d99ae"))
	b2.pressed.connect(func():
		profile.settings = Profile.DEFAULT_SETTINGS.duplicate(true)
		_save()
		refresh())
	buttons.add_child(b2)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	var close := Ui.button("Fermer", 26)
	close.pressed.connect(close_dialog)
	buttons.add_child(close)
	# Éditeur de liste : par-dessus la fenêtre des réglages.
	_list_editor = WordListEditor.new()
	_list_editor.saved.connect(func(): _word_lists.refresh())
	add_child(_list_editor)
	visible = false


func open(p: Profile) -> void:
	profile = p
	refresh()
	visible = true


func close_dialog() -> void:
	# Échap ferme d'abord l'éditeur de liste s'il est ouvert.
	if _list_editor.visible:
		_list_editor.visible = false
		return
	if visible:
		visible = false
		closed.emit()


func refresh() -> void:
	_title.text = "Réglages de %s" % profile.name
	_name_edit.text = profile.name
	_delete_button.disabled = Profiles.profiles.size() <= 1
	_confirm_delete.dialog_text = "Supprimer le profil « %s » et son historique ?" % profile.name
	for key in _controls:
		var c = _controls[key]
		var v: Variant = profile.get_setting(key)
		if c is SpinBox:
			c.set_value_no_signal(float(v))
		elif c is CheckBox:
			c.set_pressed_no_signal(bool(v))
		elif c is OptionButton:
			var values: Array = c.get_meta("values")
			var best := 0
			for i in values.size():
				if absf(float(values[i]) - float(v)) < absf(float(values[best]) - float(v)):
					best = i
			c.select(best)
	for key in _app_checks:
		_app_checks[key].set_pressed_no_signal(bool(AppSettings.get_value(key)))
	_volumes.refresh()
	_graphics.select(AppSettings.graphics())
	_refresh_graphics()
	_word_lists.profile = profile
	_word_lists.refresh()
	_refresh_bot_spins()


func _refresh_graphics() -> void:
	var status := AppSettings.graphics_status()
	_restart_button.visible = status == "restart"
	match status:
		"restart":
			_graphics_status.text = "Ce changement sera appliqué au prochain lancement du jeu."
		"unsupported":
			_graphics_status.text = "Cet ordinateur ne permet pas le mode « Beau » (carte graphique trop ancienne) : le jeu reste en mode Normal."
		_:
			_graphics_status.text = "Simple : plus fluide sur les ordinateurs lents. Beau : lumière et ombres plus réalistes, pour les ordinateurs récents."


func _save() -> void:
	Profiles.save_profile(profile)


func _section(text: String) -> Label:
	return Ui.label(text, 26, Ui.ORANGE)


func _spin(grid: GridContainer, text: String, key: String, lo: float, hi: float, step: float) -> void:
	grid.add_child(Ui.label(text, 20))
	var sb := SpinBox.new()
	sb.min_value = lo
	sb.max_value = hi
	sb.step = step
	sb.value_changed.connect(func(v):
		profile.settings[key] = v
		_save()
		if key == "bot_count":
			_refresh_bot_spins()
		elif key == "max_word_length":
			_word_lists.refresh())
	grid.add_child(sb)
	_controls[key] = sb


func _option(grid: GridContainer, text: String, key: String, items: Array) -> void:
	grid.add_child(Ui.label(text, 20))
	var ob := OptionButton.new()
	for it in items:
		ob.add_item(it[0])
	ob.item_selected.connect(func(idx):
		profile.settings[key] = items[idx][1]
		_save())
	ob.set_meta("values", items.map(func(it): return it[1]))
	grid.add_child(ob)
	_controls[key] = ob


func _check(parent: Control, text: String, key: String) -> void:
	var cb := CheckBox.new()
	cb.text = text
	cb.add_theme_font_size_override("font_size", 20)
	cb.toggled.connect(func(on):
		profile.settings[key] = on
		_save())
	parent.add_child(cb)
	_controls[key] = cb


func _refresh_bot_spins() -> void:
	var kpm: Array = profile.get_setting("bot_kpm")
	for i in _bot_spins.size():
		_bot_spins[i].set_value_no_signal(float(kpm[i]) if i < kpm.size() else 20.0)
		_bot_spins[i].editable = i < int(profile.get_setting("bot_count"))
