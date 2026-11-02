class_name Results
extends CanvasLayer
## Écran d'arrivée : place, classement et statistiques de frappe.

signal replay_pressed
signal menu_pressed

const PLACE_COLORS := [Color("#ffd60a"), Color("#d9dde4"), Color("#e09f5a")]

@onready var box: VBoxContainer = %Box
var replay_button: Button


## previous_best > 0 : nouveau record de frappes par minute (ancien record).
func show_results(logic: RaceLogic, player_name: String, previous_best := -1.0) -> void:
	for c in box.get_children():
		c.queue_free()
	var standings := logic.standings()
	var place := standings.find(logic.player) + 1
	var color: Color = PLACE_COLORS[place - 1] if place <= 3 else Color.WHITE

	var big := Ui.title(Ui.place_text(place), 92, color, 22, Ui.NAVY)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(big)
	big.resized.connect(func(): big.pivot_offset = big.size / 2.0)
	big.scale = Vector2(0.3, 0.3)
	big.create_tween().tween_property(big, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var who := (", " + player_name) if player_name != "" else ""
	var title := Ui.label(("Bravo%s, tu as gagné !" % who) if place == 1 else ("Bravo%s !" % who), 30, Ui.NAVY)
	title.add_theme_font_override("font", Ui.title_font())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	if previous_best > 0.0:
		var rec := Ui.title("NOUVEAU RECORD ! %d frappes/min (avant : %d)" % [roundi(logic.kpm()), roundi(previous_best)],
			28, Ui.YELLOW, 10, Ui.NAVY)
		rec.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(rec)
		# petit rebond pour attirer l'œil
		rec.resized.connect(func(): rec.pivot_offset = rec.size / 2.0)
		var tw := rec.create_tween().set_loops(3)
		tw.tween_property(rec, "scale", Vector2(1.12, 1.12), 0.25)
		tw.tween_property(rec, "scale", Vector2.ONE, 0.25)

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
		var kc: Color = GameContent.get_content().character(r.character).kart_color
		var style := Ui.flat(kc, 14, Color.WHITE, 4 if r.is_player else 0, 4)
		style.border_width_bottom = 8 if r.is_player else 5
		if not r.is_player:
			style.border_color = kc.darkened(0.3)
		style.content_margin_left = 16
		style.content_margin_right = 16
		row.add_theme_stylebox_override("panel", style)
		var h := HBoxContainer.new()
		row.add_child(h)
		var n := Ui.label("%s   %s" % [Ui.place_text(i + 1), r.name], 21, Color.WHITE, 8, Color(0.03, 0.05, 0.16, 0.65))
		n.add_theme_font_override("font", Ui.bold_font())
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		var tl := Ui.label(Ui.format_time(logic.finish_of(r)), 21, Color.WHITE, 8, Color(0.03, 0.05, 0.16, 0.65))
		tl.add_theme_font_override("font", Ui.bold_font())
		h.add_child(tl)
		middle.add_child(row)

	var grid := GridContainer.new()
	grid.columns = 3
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
	var stat_colors := [Color("#ff6b35"), Color("#17b169"), Color("#2d7ff9"), Color("#9b5de5"), Color("#e63946"), Color("#1d3557")]
	for k in stats.size():
		var s: Array = stats[k]
		var cell := PanelContainer.new()
		var cs := Ui.flat(Color("#f1f4fb"), 16, Color("#dfe5f1"), 0, 6)
		cs.border_width_bottom = 4
		cell.add_theme_stylebox_override("panel", cs)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -4)
		cell.add_child(v)
		var a := Ui.label(s[0], 30, stat_colors[k % stat_colors.size()])
		a.add_theme_font_override("font", Ui.title_font())
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(a)
		var b := Ui.label(s[1], 16, Color("#5f6478"))
		b.add_theme_font_override("font", Ui.bold_font())
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(b)
		grid.add_child(cell)

	# Lettres ratées ou cherchées longtemps pendant cette course.
	var hard := LetterStats.difficult(logic.stats.letters, 3, 2)
	if not hard.is_empty():
		var tip := Ui.label("Lettres à retravailler : " + "  ".join(LetterStats.letters_of(hard)), 20, Color("#5f6470"))
		tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		middle.add_child(tip)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	replay_button = Ui.button("Rejouer", 38, Color("#17b169"))
	replay_button.add_theme_font_override("font", Ui.title_font())
	replay_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replay_button.pressed.connect(func(): replay_pressed.emit())
	Ui.bounce_on_hover(replay_button, 1.04)
	buttons.add_child(replay_button)
	var menu := Ui.button("Menu", 30, Color("#7b8bb2"))
	menu.add_theme_font_override("font", Ui.title_font())
	Ui.bounce_on_hover(menu)
	menu.pressed.connect(func(): menu_pressed.emit())
	buttons.add_child(menu)
