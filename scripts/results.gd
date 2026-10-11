class_name Results
extends CanvasLayer
## Écran d'arrivée : place, classement et statistiques de frappe.

signal replay_pressed
signal menu_pressed

const PLACE_COLORS := [Color("#ffd60a"), Color("#d9dde4"), Color("#e09f5a")]

var root := Control.new()
var box: VBoxContainer
var replay_button: Button


func _ready() -> void:
	root.theme = Ui.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -600
	panel.offset_right = -30
	panel.offset_top = 30
	panel.offset_bottom = -30
	root.add_child(panel)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)


func show_results(logic: RaceLogic, player_name: String) -> void:
	for c in box.get_children():
		c.queue_free()
	var standings := logic.standings()
	var place := standings.find(logic.player) + 1
	var color: Color = PLACE_COLORS[place - 1] if place <= 3 else Color.WHITE

	var big := Ui.label(Ui.place_text(place), 110, color, 24, Ui.NAVY)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(big)
	var who := (", " + player_name) if player_name != "" else ""
	var title := Ui.label(("Bravo%s, tu as gagné !" % who) if place == 1 else ("Bravo%s !" % who), 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)

	for i in standings.size():
		var r = standings[i]
		var row := PanelContainer.new()
		var kc: Color = Characters.get_info(r.character).kart
		var style := Ui.flat(kc, 12, Color.WHITE, 4 if r.is_player else 0, 6)
		style.content_margin_left = 16
		style.content_margin_right = 16
		row.add_theme_stylebox_override("panel", style)
		var h := HBoxContainer.new()
		row.add_child(h)
		var n := Ui.label("%s   %s" % [Ui.place_text(i + 1), r.name], 26, Color.WHITE, 8, Color(0, 0, 0, 0.7))
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		h.add_child(Ui.label(Ui.format_time(logic.finish_of(r)), 26, Color.WHITE, 8, Color(0, 0, 0, 0.7)))
		box.add_child(row)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
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
		cell.add_theme_stylebox_override("panel", Ui.flat(Color("#eef0f5"), 12))
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -4)
		cell.add_child(v)
		var a := Ui.label(s[0], 34)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(a)
		var b := Ui.label(s[1], 16, Color("#5f6470"))
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(b)
		grid.add_child(cell)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	replay_button = Ui.button("Rejouer", 38, Color("#17b169"))
	replay_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replay_button.pressed.connect(func(): replay_pressed.emit())
	buttons.add_child(replay_button)
	var menu := Ui.button("Menu", 30, Color("#8d99ae"))
	menu.pressed.connect(func(): menu_pressed.emit())
	buttons.add_child(menu)
