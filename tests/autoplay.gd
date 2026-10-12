extends SceneTree
## Test automatique : lance une course et tape les mots avec de vrais événements
## clavier (avec une erreur volontaire), jusqu'à l'arrivée ; vérifie que la
## course est enregistrée dans l'historique du profil.
##
## godot --path . --script res://tests/autoplay.gd -- [--shots=dossier] [--fast] [--bots=N]
## Les données de test sont dans user://test_autoplay (les vrais profils ne sont pas touchés).
## Sans --shots, peut tourner en mode --headless.

const DATA_DIR := "user://test_autoplay"
# Valeurs de Race.Mode (le script de test ne doit pas dépendre de Race, qui
# utilise les autoloads, pas encore chargés à la compilation de ce script).
const MODE_RACE := 1
const MODE_RESULTS := 2

var main: Node
var race
var shots_dir := ""
var frame := 0
var shot_index := 0
var next_key_at := 0.0
var elapsed := 0.0
var made_error := false
var shots_taken := {}
var finished_at := -1.0
var bot_count := 3


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.get_slice("=", 1)
		if arg.begins_with("--bots="):
			bot_count = int(arg.get_slice("=", 1))
		if arg == "--fast":
			Engine.time_scale = 4.0


## Appelé à la première image : les autoloads (AppSettings, Profiles) sont prêts.
func _setup() -> void:
	TestUtil.reset_data(root, DATA_DIR)
	var profiles = root.get_node("Profiles")
	var p: Profile = profiles.current
	p.name = "Léa"
	p.settings["laps"] = 1
	p.settings["bot_count"] = bot_count
	profiles.save_profile(p)
	root.get_node("AppSettings").data["fullscreen"] = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	race = main.race


func _process(delta: float) -> bool:
	frame += 1
	elapsed += delta
	if frame == 1:
		_setup()
	if frame == 30:
		_shot("menu")
		if not _check_version_label():
			quit(1)
			return false
		main._start_race()
	if frame < 31:
		return false
	var logic: RaceLogic = race.logic
	if race.mode == MODE_RACE and logic.state == "countdown" and logic.countdown < 2.2:
		_shot_once("countdown")
	if race.mode == MODE_RACE and logic.state == "running":
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
	if race.mode == MODE_RESULTS and finished_at < 0.0:
		finished_at = elapsed
	if finished_at > 0.0 and elapsed - finished_at > 1.0:
		_shot("results")
		var h: Array = root.get_node("Profiles").history()
		print("RESULT ", JSON.stringify(h.back() if not h.is_empty() else {}))
		print("STANDINGS ", logic.standings().map(func(r): return "%s %.1f" % [r.name, logic.finish_of(r)]))
		if h.size() != 1 or int(h.back().words) < 1 or int(h.back().errors) < 1 or h.back().get("word_lists", "") != "Mots de base":
			push_error("Résultat inattendu")
			quit(1)
			return false
		print("OK")
		return true
	if elapsed > 400.0:
		push_error("La course ne s'est pas terminée à temps")
		quit(1)
	return false


## Le numéro de version est affiché en petit, en bas à gauche du menu principal,
## sans être caché par le panneau du menu.
func _check_version_label() -> bool:
	var label: Label = main.menu.get_node("%VersionLabel")
	var panel: Control = main.menu.get_node("Root/Panel")
	var version := str(ProjectSettings.get_setting("application/config/version"))
	var screen := label.get_viewport_rect().size
	var rect := label.get_global_rect()
	print("VERSION ", label.text, " ", rect)
	if not label.is_visible_in_tree() or not label.text.ends_with("v" + version):
		push_error("Numéro de version absent du menu : « %s »" % label.text)
		return false
	if rect.position.x > 40.0 or rect.end.y > screen.y or rect.end.y < screen.y - 20.0:
		push_error("Numéro de version mal placé (attendu en bas à gauche) : %s" % rect)
		return false
	if rect.intersects(panel.get_global_rect()):
		push_error("Numéro de version caché par le panneau du menu : %s / %s" % [rect, panel.get_global_rect()])
		return false
	return true


func _key(ch: String) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.unicode = ch.unicode_at(0)
	ev.keycode = OS.find_keycode_from_string(ch.to_upper())
	Input.parse_input_event(ev)
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


func _shot_once(shot_name: String) -> void:
	if shots_taken.has(shot_name):
		return
	shots_taken[shot_name] = true
	_shot(shot_name)


func _shot(shot_name: String) -> void:
	if shots_dir == "":
		return
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(shots_dir.path_join("%02d_%s.png" % [shot_index, shot_name]))
	shot_index += 1
	print("shot ", shot_name)
