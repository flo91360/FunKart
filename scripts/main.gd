extends Node3D
## Chef d'orchestre du jeu : menu, course (caméra derrière le kart), arrivée.

enum State { MENU, RACE, RESULTS }

const GRID_LATERAL := 2.6
const RACE_LANES := [-5.0, -3.0, -1.0, 1.0, 3.0, 5.0]
const OBSTACLE_AHEAD := 15.0
const OBSTACLE_SCALE := 1.7

var state := State.MENU
var track: Track
var camera := Camera3D.new()
var sfx := Sfx.new()
var hud := Hud.new()
var menu := Menu.new()
var results := Results.new()
var logic: RaceLogic
var karts := {} # Racer -> Kart
var obstacle: Node3D
var paused := false
var _t := 0.0
var _hud_timer := 0.0
var _lane_timer := 0.0
var _orbit := 0.0
var _shake := 0.0


func _ready() -> void:
	_build_environment()
	track = Track.new()
	add_child(track)
	camera.fov = 70.0
	camera.far = 3000.0
	camera.v_offset = -1.2 # remonte le kart au-dessus du panneau du mot
	add_child(camera)
	camera.current = true
	add_child(sfx)
	add_child(hud)
	add_child(results)
	add_child(menu)
	hud.resume_pressed.connect(func(): _set_paused(false))
	hud.quit_pressed.connect(_show_menu)
	menu.play_pressed.connect(start_race)
	menu.character_changed.connect(_prepare_race)
	menu.settings_changed.connect(_prepare_race)
	results.replay_pressed.connect(start_race)
	results.menu_pressed.connect(_show_menu)
	_show_menu()


func _build_environment() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#2f7fe0")
	sky_mat.sky_horizon_color = Color("#b8dcff")
	sky_mat.ground_horizon_color = Color("#b8dcff")
	sky_mat.ground_bottom_color = Color("#4caf50")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c9d6e8")
	env.ambient_light_energy = 0.35
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("#cfe6ff")
	env.fog_density = 0.0007
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)


# ---------------- États ----------------

## Crée la course (karts sur la grille de départ) avec les réglages actuels.
func _prepare_race() -> void:
	for k in karts.values():
		k.queue_free()
	karts.clear()
	_remove_obstacle()
	var s := GameSettings.data
	var player_name: String = s.player_name if String(s.player_name) != "" else "Toi"
	var bots := []
	var kpm: Array = s.bot_kpm
	for i in mini(int(s.bot_count), Characters.BOT_IDS.size()):
		var id: String = Characters.BOT_IDS[i]
		bots.append({"name": Characters.ALL[id].name, "character": id, "kpm": float(kpm[i]) if i < kpm.size() else 20.0})
	logic = RaceLogic.new(s, GameSettings.word_list(), track.length,
		{"name": player_name, "character": s.character}, bots)
	logic.countdown_tick.connect(_on_countdown)
	logic.race_started.connect(_on_go)
	logic.word_started.connect(_on_word_started)
	logic.key_ok.connect(_on_key_ok)
	logic.key_error.connect(_on_key_error)
	logic.word_completed.connect(_on_word_completed)
	logic.player_finished.connect(_on_player_finished)
	for r in logic.racers:
		var k := Kart.new(r.character, r.name, not r.is_player)
		add_child(k)
		k.lateral = -GRID_LATERAL if r.slot % 2 == 0 else GRID_LATERAL
		k.target_lateral = k.lateral
		k.update_visual(track, r.distance, 0.0, 1.0, 0.016, false, false)
		karts[r] = k


func _show_menu() -> void:
	state = State.MENU
	paused = false
	sfx.stop_engine()
	sfx.music.stop()
	hud.visible = false
	results.visible = false
	menu.visible = true
	_orbit = 0.0
	_prepare_race()
	menu.focus_play()


func start_race() -> void:
	_prepare_race()
	state = State.RACE
	paused = false
	menu.visible = false
	results.visible = false
	hud.visible = true
	hud.setup(track.minimap_points(), logic.laps)
	hud.update_race(logic)
	hud.show_center("3", 0.6)
	sfx.play("count")
	sfx.start_race_audio()
	get_viewport().gui_release_focus()
	_place_chase_camera(1.0)


func _on_countdown(n: int) -> void:
	hud.show_center(str(n), 0.6)
	sfx.play("count")


func _on_go() -> void:
	hud.show_center("GO !", 0.6)
	sfx.play("go")


func _on_word_started(word: String) -> void:
	hud.show_word(word, 0)
	hud.set_hint("Tape le mot pour avoir un turbo !")
	sfx.speak(word)
	_remove_obstacle()
	obstacle = Props.make(word)
	add_child(obstacle)
	obstacle.scale = Vector3.ONE * 0.01
	_update_obstacle(0.0)
	create_tween().tween_property(obstacle, "scale", Vector3.ONE * OBSTACLE_SCALE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_key_ok(typed: int) -> void:
	hud.show_word(logic.player.word, typed)
	hud.set_hint("Tape le mot pour avoir un turbo !")
	sfx.play("key_ok")


func _on_key_error(expected: String) -> void:
	var letter := expected.to_upper() if GameSettings.data.uppercase else expected
	hud.shake_word()
	hud.set_hint("Oups ! Cherche la lettre « %s »" % letter, true)
	sfx.play("key_error")
	_shake = 0.15


func _on_word_completed(word: String) -> void:
	hud.show_word(word, word.length(), true)
	hud.set_hint("TURBO !")
	sfx.play("word")
	sfx.play("boost")
	if obstacle:
		Mk.burst(self, obstacle.global_position, [Color("#ffd60a"), Color("#ff6b35"), Color("#ff4d6d"), Color("#2d7ff9"), Color("#17b169")])
		var o := obstacle
		obstacle = null
		var tw := create_tween()
		tw.tween_property(o, "scale", Vector3.ONE * 0.01, 0.15)
		tw.tween_callback(o.queue_free)
	get_tree().create_timer(1.0).timeout.connect(func():
		if state == State.RACE and logic.player.word == "" and not logic.player.finished:
			hud.clear_word())


func _on_player_finished() -> void:
	_remove_obstacle()
	sfx.play("finish")
	hud.clear_word("Arrivée !")
	hud.show_center("ARRIVÉE !", 2.0)
	var place := logic.player_position()
	if place <= 3:
		var k: Kart = karts[logic.player]
		for i in 3:
			get_tree().create_timer(0.3 * i).timeout.connect(func():
				Mk.burst(self, k.global_position + Vector3(0, 4, 0), [Color("#ffd60a"), Color("#ff4d6d"), Color("#2d7ff9"), Color("#17b169"), Color.WHITE], 80, 12.0))
	get_tree().create_timer(2.6).timeout.connect(_show_results)


func _show_results() -> void:
	if state != State.RACE:
		return
	state = State.RESULTS
	_orbit = 0.0
	sfx.stop_engine()
	hud.visible = false
	results.visible = true
	var s := GameSettings.data
	results.show_results(logic, String(s.player_name))
	var bot_kpm := []
	for r in logic.racers:
		if not r.is_player:
			bot_kpm.append(r.kpm)
	History.add({
		"date": Time.get_datetime_string_from_system(),
		"name": s.player_name if String(s.player_name) != "" else "—",
		"character": Characters.get_info(s.character).name,
		"place": logic.player_position(),
		"total": logic.racers.size(),
		"laps": logic.laps,
		"kpm": logic.kpm(),
		"accuracy": logic.accuracy(),
		"words": logic.stats.words.size(),
		"errors": logic.stats.errors,
		"avg_word_time": logic.average_word_time(),
		"time": logic.player.finish_time,
		"bot_kpm": bot_kpm,
	})


func _set_paused(p: bool) -> void:
	if state != State.RACE or logic.state == "finished":
		return
	paused = p
	hud.set_paused(p)
	if p:
		sfx.engine.stream_paused = true
	else:
		sfx.engine.stream_paused = false
		get_viewport().gui_release_focus()


func _remove_obstacle() -> void:
	if obstacle:
		obstacle.queue_free()
		obstacle = null


# ---------------- Boucle ----------------

func _process(delta: float) -> void:
	_t += delta
	match state:
		State.MENU:
			_update_karts(0.0)
			_orbit_camera(delta, -2.8)
		State.RACE:
			var dt := 0.0 if paused else delta
			logic.update(dt)
			_update_karts(dt)
			_update_lanes(dt)
			_update_obstacle(dt)
			_place_chase_camera(dt)
			sfx.set_engine_speed(logic.player.mult)
			_hud_timer -= delta
			if _hud_timer <= 0.0:
				_hud_timer = 0.15
				hud.update_race(logic)
			hud.update_minimap(_minimap_dots())
		State.RESULTS:
			logic.update(delta)
			_update_karts(delta)
			_update_lanes(delta)
			_orbit_camera(delta, 3.0)


func _update_karts(dt: float) -> void:
	for r in logic.racers:
		var k: Kart = karts[r]
		var speed: float = logic.base_speed * r.mult
		if r.finished:
			# tour d'honneur au ralenti après la ligne
			speed = logic.base_speed * 0.45
			k.extra_distance += speed * dt
		if logic.state == "countdown":
			speed = 0.0
		var boosting: bool = r.boost > 0.0 and r.word == "" and not r.finished
		var slowed: bool = r.word != "" and logic.state == "running"
		k.update_visual(track, r.distance + k.extra_distance, speed, r.mult, dt, boosting, slowed)


## Pilote automatique : les karts changent de couloir pour doubler.
func _update_lanes(dt: float) -> void:
	if logic.state == "countdown":
		return
	_lane_timer -= dt
	if _lane_timer > 0.0:
		return
	_lane_timer = 0.25
	for r in logic.racers:
		var k: Kart = karts[r]
		var blocked := false
		for o in logic.racers:
			if o == r:
				continue
			var gap: float = (o.distance + karts[o].extra_distance) - (r.distance + k.extra_distance)
			if gap > 0.0 and gap < 9.0 and absf(karts[o].lateral - k.target_lateral) < 2.0:
				blocked = true
		if blocked or randf() < 0.02:
			var best: float = k.target_lateral
			var best_score := INF
			for lane in RACE_LANES:
				var score := absf(lane - k.lateral) + randf() * 0.5
				for o in logic.racers:
					if o == r:
						continue
					var gap: float = (o.distance + karts[o].extra_distance) - (r.distance + k.extra_distance)
					if gap > -4.0 and gap < 12.0 and absf(karts[o].target_lateral - lane) < 2.0:
						score += 100.0
				if score < best_score:
					best_score = score
					best = lane
			k.target_lateral = best


func _update_obstacle(_dt: float) -> void:
	if obstacle == null:
		return
	var p := logic.player
	var k: Kart = karts[p]
	var f := track.frame_at(p.distance + OBSTACLE_AHEAD)
	obstacle.global_position = f.origin + f.basis.x * k.lateral + f.basis.y * (2.2 + sin(_t * 3.0) * 0.3)
	obstacle.global_basis = f.basis * Basis(Vector3.UP, _t * 1.5) * Basis.from_scale(obstacle.scale)


func _place_chase_camera(dt: float) -> void:
	var p := logic.player
	var k: Kart = karts[p]
	var f := track.frame_at(p.distance + k.extra_distance)
	var target := f.origin + f.basis.x * k.lateral * 0.7 + f.basis.z * 8.0 + Vector3.UP * 3.4
	var w := 1.0 if dt >= 1.0 else 1.0 - exp(-dt * 7.0)
	camera.global_position = camera.global_position.lerp(target, w)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - dt)
		camera.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.6
	var look := f.origin + f.basis.x * k.lateral * 0.85 + Vector3.UP * 0.6 - f.basis.z * 6.0
	camera.look_at(look)
	var fov_target := 70.0 + (p.mult - 1.0) * 14.0
	camera.fov = lerpf(camera.fov, fov_target, 1.0 if dt >= 1.0 else 1.0 - exp(-dt * 4.0))


## Caméra qui se balance autour du kart du joueur (menu, arrivée), vue de trois quarts avant.
## side décale le kart à droite (<0) ou à gauche (>0) de l'écran.
func _orbit_camera(dt: float, side: float) -> void:
	var k: Kart = karts[logic.player]
	_orbit += dt
	var center := k.global_position + Vector3.UP * 1.2
	var fwd := -k.global_basis.z
	var angle := 0.55 * signf(side) + sin(_orbit * 0.4) * 0.45
	var dir := fwd.rotated(Vector3.UP, angle)
	camera.global_position = center + dir * 7.5 + Vector3.UP * 1.8
	camera.look_at(center)
	camera.global_position += camera.global_basis.x * side
	camera.fov = 60.0


func _minimap_dots() -> Array:
	var dots := []
	for r in logic.racers:
		var k: Kart = karts[r]
		dots.append([Vector2(k.global_position.x, k.global_position.z), Characters.get_info(r.character).kart, r.is_player])
	return dots


# ---------------- Clavier ----------------

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F11:
		GameSettings.set_value("fullscreen", not GameSettings.data.fullscreen)
		return
	if state != State.RACE:
		return
	if event.keycode == KEY_ESCAPE:
		_set_paused(not paused)
		get_viewport().set_input_as_handled()
		return
	if paused:
		return
	if event.unicode > 31:
		logic.handle_char(char(event.unicode))
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == State.RACE and logic.state == "running":
		_set_paused(true)
