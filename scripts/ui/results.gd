class_name Results
extends CanvasLayer
## Écran d'arrivée : place, classement et statistiques de frappe.

signal replay_pressed
signal menu_pressed

@onready var box: VBoxContainer = %Box
var replay_button: Button


func show_results(logic: RaceLogic, player_name: String) -> void:
	for c in box.get_children():
		c.queue_free()
	var standings := logic.standings()
	var place := standings.find(logic.player) + 1

	var caption := Ui.label("CARNET DE COURSE", 12, Color("#a9beab"))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(caption)
	var big := Ui.label(Ui.place_text(place), 58, Color("#eac482"))
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(big)
	var who := (", " + player_name) if player_name != "" else ""
	var title := Ui.label(("Bravo%s, quelle course !" % who) if place == 1 else ("Bravo%s !" % who), 23, Color("#f3e7cf"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)

	# Classement et statistiques : défilent si l'écran est trop petit,
	# pour que les boutons restent toujours visibles en bas.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 6)
	scroll.add_child(middle)

	for i in standings.size():
		var r = standings[i]
		var row := PanelContainer.new()
		var style := Ui.flat(Color("#214740"), 9, Color("#e3bc79"), 2 if r.is_player else 0, 4)
		style.content_margin_left = 16
		style.content_margin_right = 16
		row.add_theme_stylebox_override("panel", style)
		var h := HBoxContainer.new()
		row.add_child(h)
		var n := Ui.label("%s   %s" % [Ui.place_text(i + 1), r.name], 16, Color("#e9e7d6"), 0)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		h.add_child(Ui.label(Ui.format_time(logic.finish_of(r)), 16, Color("#e9e7d6"), 0))
		middle.add_child(row)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	middle.add_child(grid)
	var stats := [
		[str(roundi(logic.kpm())), "frappes / min"],
		["%d %%" % roundi(logic.accuracy() * 100.0), "précision"],
		[str(logic.stats.words.size()), "mots tapés"],
		["%.1f s" % logic.average_word_time(), "temps moyen / mot"],
		[str(logic.stats.errors), "erreurs"],
		[Ui.format_time(logic.player.finish_time), "temps de course"],
	]
	for s in stats:
		var cell := PanelContainer.new()
		cell.add_theme_stylebox_override("panel", Ui.flat(Color("#23483f"), 12, Color.TRANSPARENT, 0, 6))
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -4)
		cell.add_child(v)
		var a := Ui.label(s[0], 27, Color("#f0ddb7"))
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(a)
		var b := Ui.label(s[1], 12, Color("#a9c0af"))
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(b)
		grid.add_child(cell)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	replay_button = Ui.button("Encore une course", 21, Color("#e7b66c"))
	replay_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replay_button.pressed.connect(func(): replay_pressed.emit())
	buttons.add_child(replay_button)
	var menu := Ui.button("Atelier", 20, Color("#34564a"))
	menu.pressed.connect(func(): menu_pressed.emit())
	buttons.add_child(menu)
