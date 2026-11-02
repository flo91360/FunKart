class_name HistoryDialog
extends Control
## Fenêtre « Historique » : les courses du profil sélectionné, et l'export CSV
## de tous les profils.

var profile: Profile
var _title: Label
var _grid: GridContainer
var _status: Label
var _confirm_clear: ConfirmationDialog
var _letters: Label
var _practice_btn: Button
var _hard: Array = [] # lettres à travailler (LetterStats.difficult)
var _chart: ProgressChart
var _best: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ov := Ui.overlay(self, Vector2(1100, 600))
	var box: VBoxContainer = ov[1]
	_title = Ui.title("Historique", 40, Ui.NAVY, 0)
	box.add_child(_title)
	# Courbe de progression et record.
	_chart = ProgressChart.new()
	box.add_child(_chart)
	_best = Ui.label("", 20)
	box.add_child(_best)
	# Lettres à travailler sur les dernières courses, et liste d'entraînement.
	var letters_row := HBoxContainer.new()
	letters_row.add_theme_constant_override("separation", 12)
	box.add_child(letters_row)
	_letters = Ui.label("", 20)
	_letters.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_letters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	letters_row.add_child(_letters)
	_practice_btn = Ui.button("Créer une liste d'entraînement", 18, Color("#17b169"))
	_practice_btn.pressed.connect(_create_practice_list)
	letters_row.add_child(_practice_btn)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 150
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 8
	_grid.add_theme_constant_override("h_separation", 22)
	_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_grid)
	_status = Ui.label("", 18, Color("#5f6470"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	var export_btn := Ui.button("Exporter tous les profils (CSV)", 20, Color("#2d7ff9"))
	export_btn.pressed.connect(func():
		var path := Profiles.export_csv()
		_status.text = ("Fichier enregistré : " + path) if path != "" else "Impossible d'enregistrer le fichier.")
	buttons.add_child(export_btn)
	var open_btn := Ui.button("Ouvrir le dossier", 20, Color("#8d99ae"))
	open_btn.pressed.connect(func():
		var path := Profiles.export_csv()
		if path != "":
			OS.shell_show_in_file_manager(path))
	buttons.add_child(open_btn)
	var clear := Ui.button("Effacer", 20, Color("#8d99ae"))
	_confirm_clear = ConfirmationDialog.new()
	_confirm_clear.ok_button_text = "Effacer"
	_confirm_clear.cancel_button_text = "Annuler"
	_confirm_clear.confirmed.connect(func():
		Profiles.clear_history(profile)
		refresh())
	add_child(_confirm_clear)
	clear.pressed.connect(func(): _confirm_clear.popup_centered())
	buttons.add_child(clear)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	var close := Ui.button("Fermer", 26)
	close.pressed.connect(func(): visible = false)
	buttons.add_child(close)
	visible = false


func open(p: Profile) -> void:
	profile = p
	refresh()
	visible = true


func refresh() -> void:
	_title.text = "Historique de %s" % profile.name
	_confirm_clear.dialog_text = "Effacer l'historique de %s ?" % profile.name
	for c in _grid.get_children():
		c.queue_free()
	for h in ["Date", "Circuit", "Place", "Frappes/min", "Précision", "Mots", "Temps/mot", "Adversaires"]:
		_grid.add_child(Ui.label(h, 20, Ui.ORANGE))
	var all := Profiles.history(profile)
	all.reverse()
	for h in all.slice(0, 200):
		var date := String(h.get("date", "")).replace("T", " ").substr(0, 16)
		var bots := " / ".join(PackedStringArray(Array(h.get("bot_kpm", [])).map(func(v): return str(int(v)))))
		var cells := [date, h.get("track", "—"), "%d/%d" % [int(h.get("place", 0)), int(h.get("total", 0))],
			str(roundi(float(h.get("kpm", 0)))), "%d %%" % roundi(float(h.get("accuracy", 0)) * 100.0),
			str(int(h.get("words", 0))), "%.1f s" % float(h.get("avg_word_time", 0)), bots if bots != "" else "—"]
		for c in cells:
			_grid.add_child(Ui.label(str(c), 18))
	_status.text = "" if not all.is_empty() else "Aucune course pour le moment."
	all.reverse()
	_chart.set_points(Progress.series(all))
	var best := Progress.best_kpm(all)
	_best.text = ("Record : %d frappes par minute" % roundi(best)) if best > 0.0 else "Record : pas encore de course complète."
	_hard = LetterStats.difficult(LetterStats.from_history(all))
	if _hard.is_empty():
		_letters.text = "Lettres à travailler : aucune pour le moment (%d dernières courses)." % LetterStats.RECENT_RACES
	else:
		_letters.text = "Lettres à travailler (%d dernières courses) : %s" % [LetterStats.RECENT_RACES, LetterStats.describe(_hard)]
	_practice_btn.visible = not _hard.is_empty()


## Liste personnelle de mots contenant les lettres à travailler, cochée pour
## les prochaines courses.
func _create_practice_list() -> void:
	var letters := LetterStats.letters_of(_hard)
	var pool := PackedStringArray()
	for source in profile.available_lists():
		pool.append_array(source.words)
	var words := LetterStats.practice_words(pool, letters)
	var practice := profile.add_list("Entraînement : " + ", ".join(letters), words)
	profile.set_active(practice.id, true)
	Profiles.save_profile(profile)
	_status.text = "Liste « %s » créée (%d mots) et cochée pour les prochaines courses (Réglages → Listes de mots)." % [practice.title, words.size()]
