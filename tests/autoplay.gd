extends SceneTree
## Test automatique : lance une course et tape les mots avec de vrais événements
## clavier (avec une erreur volontaire), jusqu'à l'arrivée ; vérifie que la
## course est enregistrée dans l'historique du profil.
##
## godot --path . --script res://tests/autoplay.gd -- [--shots=dossier] [--fast] [--bots=N] [--track=N] [--thumbs]
## --track : circuit (0 : la Prairie). --thumbs (avec --shots) : chaque capture est
## aussi écrite en petit dans la sortie (JPEG en base64, lignes « THUMB »), pour
## la voir dans le journal de la CI sans télécharger les Artifacts.
## Pendant la course, la caméra doit rester au-dessus de la route et du sol, et
## le kart visible au-dessus du panneau du mot.
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
var track_index := 0
var thumbs := false
var cam_clearance := INF # plus petite hauteur de la caméra au-dessus de la route ou du sol
var kart_hidden := 0 # images où le kart est caché par le panneau du mot
var running_frames := 0
var player_finished_for := 0.0 # temps écoulé depuis l'arrivée du joueur


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.get_slice("=", 1)
		if arg.begins_with("--bots="):
			bot_count = int(arg.get_slice("=", 1))
		if arg == "--fast":
			Engine.time_scale = 4.0
		if arg.begins_with("--track="):
			track_index = int(arg.get_slice("=", 1))
		if arg == "--thumbs":
			thumbs = true


## Appelé à la première image : les autoloads (AppSettings, Profiles) sont prêts.
func _setup() -> void:
	TestUtil.reset_data(root, DATA_DIR)
	var profiles = root.get_node("Profiles")
	var p: Profile = profiles.current
	p.name = "Léa"
	p.settings["laps"] = 1
	p.settings["bot_count"] = bot_count
	p.track_index = track_index
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
		_check_camera(logic)
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
	if race.mode == MODE_RACE and logic.player.finished:
		player_finished_for += delta
		if player_finished_for > 0.6 and not shots_taken.has("arrivee"):
			_shot_once("arrivee")
			if not _check_center_label():
				quit(1)
				return false
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
		print("CAMERA hauteur mini au-dessus de la route : %.2f m ; kart caché par le panneau : %d images sur %d" % [cam_clearance, kart_hidden, running_frames])
		if cam_clearance < 1.0:
			push_error("La caméra est descendue trop près de la route ou du sol (%.2f m)" % cam_clearance)
			quit(1)
			return false
		if kart_hidden > 0:
			push_error("Le kart a été caché par le panneau du mot (%d images)" % kart_hidden)
			quit(1)
			return false
		print("OK")
		return true
	if elapsed > 400.0:
		push_error("La course ne s'est pas terminée à temps")
		quit(1)
	return false


## « ARRIVÉE ! » s'affiche en entier dans la place libre : entre le classement
## et la minimap, entre les stats du haut et le panneau du mot.
func _check_center_label() -> bool:
	var hud = race.hud
	var label: Label = hud.center_label
	var font := label.get_theme_font("font")
	var size := label.get_theme_font_size("font_size")
	var rect := label.get_global_rect()
	var text_w := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var text := Rect2(rect.get_center().x - text_w / 2.0, rect.position.y, text_w, font.get_ascent(size))
	var box: Rect2 = hud.center_text_box()
	print("ARRIVEE texte %s (taille %d) ; place libre %s" % [text, size, box])
	if not box.grow(1.0).encloses(text):
		push_error("« ARRIVÉE ! » déborde de la place libre (classement, minimap, stats ou panneau du mot)")
		return false
	return true


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


## La caméra reste au-dessus de la route et du sol ; le kart reste visible
## au-dessus du panneau du mot, roues comprises (après la première seconde,
## le temps du cadrage).
func _check_camera(logic: RaceLogic) -> void:
	running_frames += 1
	var k = race.karts[logic.player] # Kart (non typé : le script ne dépend pas des classes de la course)
	var d: float = logic.player.distance + k.extra_distance
	var cam: Camera3D = race.camera
	var road_y: float = maxf(race.track.frame_at(d).origin.y, 0.0)
	cam_clearance = minf(cam_clearance, cam.global_position.y - road_y)
	if logic.time > 1.0:
		var spot := cam.unproject_position(k.global_position + Vector3.UP * 0.1)
		if spot.y > race.hud.word_panel.global_position.y:
			kart_hidden += 1


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
	if thumbs:
		img.resize(480, int(480.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_BILINEAR)
		print("THUMB %d_%s %s" % [track_index, shot_name, Marshalls.raw_to_base64(img.save_jpg_to_buffer(0.6))])
	shot_index += 1
	print("shot ", shot_name)
