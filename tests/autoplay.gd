extends SceneTree
## Test automatique : lance une course et tape les mots avec de vrais événements
## clavier (avec une erreur volontaire), jusqu'à l'arrivée.
##
## godot --path . --script res://tests/autoplay.gd [-- --shots=dossier] [--fast]
## Sans --shots, peut tourner en mode --headless.

var main: Node
var shots_dir := ""
var frame := 0
var shot_index := 0
var next_key_at := 0.0
var elapsed := 0.0
var made_error := false
var shots_taken := {}
var finished_at := -1.0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.get_slice("=", 1)
		if arg == "--fast":
			Engine.time_scale = 4.0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	frame += 1
	elapsed += delta
	if frame == 2:
		var gs = root.get_node("GameSettings")
		gs.data = gs.DEFAULTS.duplicate(true)
		gs.data.player_name = "Léa"
		gs.data.laps = 1
	if frame == 30:
		_shot("menu")
		main.start_race()
	if frame < 31:
		return false
	var logic: RaceLogic = main.logic
	if main.state == 1 and logic.state == "countdown" and logic.countdown < 2.2:
		_shot_once("countdown")
	if main.state == 1 and logic.state == "running":
		var p := logic.player
		if p.word != "" and elapsed >= next_key_at:
			if not made_error and p.typed == 1:
				_key("x")
				made_error = true
				next_key_at = elapsed + 0.2
				return false
			_key(p.word[p.typed])
			next_key_at = elapsed + 0.22
			if p.typed == 2:
				_shot_once("word_%d" % logic.stats.words.size())
		if p.boost > 1.5 and p.word == "":
			_shot_once("boost")
	if main.state == 2 and finished_at < 0.0:
		finished_at = elapsed
	if finished_at > 0.0 and elapsed - finished_at > 1.0:
		_shot("results")
		var h: Array = History.load_all()
		print("RESULT ", JSON.stringify(h.back()))
		print("STANDINGS ", logic.standings().map(func(r): return "%s %.1f" % [r.name, logic.finish_of(r)]))
		if h.is_empty() or int(h.back().words) < 1 or int(h.back().errors) < 1:
			push_error("Résultat inattendu")
			quit(1)
			return false
		print("OK")
		return true
	if elapsed > 400.0:
		push_error("La course ne s'est pas terminée à temps")
		quit(1)
	return false


func _key(ch: String) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.unicode = ch.unicode_at(0)
	ev.keycode = OS.find_keycode_from_string(ch.to_upper())
	Input.parse_input_event(ev)
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


func _shot_once(name: String) -> void:
	if shots_taken.has(name):
		return
	shots_taken[name] = true
	_shot(name)


func _shot(name: String) -> void:
	if shots_dir == "":
		return
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(shots_dir.path_join("%02d_%s.png" % [shot_index, name]))
	shot_index += 1
	print("shot ", name)
