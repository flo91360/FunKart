class_name Race
extends Node3D
## Le monde 3D de la course : circuit, karts, caméra, objets à esquiver, sons,
## interface de course (Hud) et écran d'arrivée (Results).
##
## Trois modes :
## - PREVIEW : les karts attendent sur la grille, la caméra tourne autour du
##   pilote (derrière le menu) ;
## - RACE : la course ;
## - RESULTS : écran d'arrivée.

signal menu_requested

enum Mode { PREVIEW, RACE, RESULTS }

const GRID_LATERAL := 2.6
const RACE_LANES := [-5.0, -3.0, -1.0, 1.0, 3.0, 5.0]
const OBSTACLE_AHEAD := 15.0
const OBSTACLE_SCALE := 1.7
const BURST_COLORS := [Color("#ffd60a"), Color("#ff6b35"), Color("#ff4d6d"), Color("#2d7ff9"), Color("#17b169")]

@onready var environment: WorldEnvironment = $Environment
@onready var sun: DirectionalLight3D = $Sun
@onready var camera: Camera3D = $Camera
@onready var track_slot: Node3D = $TrackSlot
@onready var karts_root: Node3D = $Karts
@onready var sfx: Sfx = $Sfx
@onready var hud: Hud = $Hud
@onready var results: Results = $Results

var mode := Mode.PREVIEW
var profile: Profile
var track: Track
var logic: RaceLogic
var karts := {} # Racer -> Kart
var obstacle: Node3D
var paused := false
## Décalage horizontal de la caméra en mode PREVIEW (< 0 : kart à droite de l'écran).
var preview_side := -2.8
var _track_index := -1
var _t := 0.0
var _hud_timer := 0.0
var _lane_timer := 0.0
var _orbit := 0.0
var _shake := 0.0


func _ready() -> void:
	hud.visible = false
	results.visible = false
	hud.resume_pressed.connect(func(): set_paused(false))
	hud.quit_pressed.connect(func(): menu_requested.emit())
	results.replay_pressed.connect(start)
	results.menu_pressed.connect(func(): menu_requested.emit())


## Prépare une course pour ce profil : circuit, karts sur la grille.
func prepare(p: Profile) -> void:
	profile = p
	_load_track(p.track_index)
	for k in karts.values():
		k.queue_free()
	karts.clear()
	_remove_obstacle()

	var content := GameContent.get_content()
	var bots := []
	var bot_chars := content.bot_characters()
	var kpm: Array = p.get_setting("bot_kpm")
	for i in mini(int(p.get_setting("bot_count")), bot_chars.size()):
		var c := bot_chars[i]
		bots.append({"name": c.display_name, "character": c.id, "kpm": float(kpm[i]) if i < kpm.size() else 20.0})
	var player_name := p.name if p.name != "" else "Toi"
	logic = RaceLogic.new(p.settings, p.words(), track.length, {"name": player_name, "character": p.character_id}, bots)
	logic.countdown_tick.connect(_on_countdown)
	logic.race_started.connect(_on_go)
	logic.word_started.connect(_on_word_started)
	logic.key_ok.connect(_on_key_ok)
	logic.key_error.connect(_on_key_error)
	logic.word_completed.connect(_on_word_completed)
	logic.player_finished.connect(_on_player_finished)
	for r in logic.racers:
		var k := Kart.new(content.character(r.character), r.name, not r.is_player)
		karts_root.add_child(k)
		k.lateral = -GRID_LATERAL if r.slot % 2 == 0 else GRID_LATERAL
		k.target_lateral = k.lateral
		k.update_visual(track, r.distance, 0.0, 1.0, 0.016, false, false)
		karts[r] = k


func show_preview() -> void:
	mode = Mode.PREVIEW
	paused = false
	_orbit = 0.0
	sfx.stop_engine()
	sfx.music.stop()
	hud.visible = false
	results.visible = false


## Lance la course (après un compte à rebours).
func start() -> void:
	prepare(profile)
	mode = Mode.RACE
	paused = false
	results.visible = false
	hud.visible = true
	hud.setup(track.minimap_points(), logic.laps, profile)
	hud.update_race(logic)
	hud.show_center("3", 0.6)
	sfx.play("count")
	sfx.start_race_audio()
	get_viewport().gui_release_focus()
	_place_chase_camera(1.0)


func _load_track(index: int) -> void:
	var scenes := GameContent.get_content().tracks
	index = clampi(index, 0, scenes.size() - 1)
	if track and index == _track_index:
		return
	if track:
		track.queue_free()
	track = scenes[index].instantiate()
	track_slot.add_child(track)
	_track_index = index
	_apply_theme(track.track_theme)


func _apply_theme(th: TrackTheme) -> void:
	var env := environment.environment
	var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
	sky_mat.sky_top_color = th.sky_top
	sky_mat.sky_horizon_color = th.sky_horizon
	sky_mat.ground_horizon_color = th.sky_horizon
	sky_mat.ground_bottom_color = th.hills_color
	env.ambient_light_color = th.ambient_color
	env.ambient_light_energy = th.ambient_energy
	env.fog_light_color = th.fog_color
	env.fog_density = th.fog_density
	sun.light_energy = th.sun_energy
	sun.rotation_degrees = th.sun_rotation


# ---------------- Événements de la course ----------------

func _on_countdown(n: int) -> void:
	hud.show_center(str(n), 0.6)
	sfx.play("count")


func _on_go() -> void:
	hud.show_center("GO !", 0.6)
	sfx.play("go")


func _on_word_started(word: String) -> void:
	hud.show_word(word, 0)
	hud.set_hint("Tape le mot pour avoir un turbo !")
	if profile.get_setting("speak"):
		sfx.speak(word)
	_remove_obstacle()
	obstacle = Props.make(word)
	add_child(obstacle)
	obstacle.scale = Vector3.ONE * 0.01
	_update_obstacle()
	create_tween().tween_property(obstacle, "scale", Vector3.ONE * OBSTACLE_SCALE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_key_ok(typed: int) -> void:
	hud.show_word(logic.player.word, typed)
	hud.set_hint("Tape le mot pour avoir un turbo !")
	sfx.play("key_ok")


func _on_key_error(expected: String) -> void:
	var letter := expected.to_upper() if profile.get_setting("uppercase") else expected
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
		Mk.burst(self, obstacle.global_position, BURST_COLORS)
		var o := obstacle
		obstacle = null
		var tw := create_tween()
		tw.tween_property(o, "scale", Vector3.ONE * 0.01, 0.15)
		tw.tween_callback(o.queue_free)
	get_tree().create_timer(1.0).timeout.connect(func():
		if mode == Mode.RACE and logic.player.word == "" and not logic.player.finished:
			hud.clear_word())


func _on_player_finished() -> void:
	_remove_obstacle()
	sfx.play("finish")
	hud.clear_word("Arrivée !")
	hud.show_center("ARRIVÉE !", 2.0)
	if logic.player_position() <= 3:
		var k: Kart = karts[logic.player]
		for i in 3:
			get_tree().create_timer(0.3 * i).timeout.connect(func():
				Mk.burst(self, k.global_position + Vector3(0, 4, 0), BURST_COLORS + [Color.WHITE], 80, 12.0))
	get_tree().create_timer(2.6).timeout.connect(_show_results)


func _show_results() -> void:
	if mode != Mode.RACE:
		return
	mode = Mode.RESULTS
	_orbit = 0.0
	sfx.stop_engine()
	hud.visible = false
	results.visible = true
	results.show_results(logic, profile.name)
	var bot_kpm := []
	for r in logic.racers:
		if not r.is_player:
			bot_kpm.append(r.kpm)
	Profiles.add_history({
		"date": Time.get_datetime_string_from_system(),
		"character": GameContent.get_content().character(profile.character_id).display_name,
		"track": track.title,
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
	}, profile)


func set_paused(p: bool) -> void:
	if mode != Mode.RACE or logic.state == "finished":
		return
	paused = p
	hud.set_paused(p)
	sfx.engine.stream_paused = p
	if not p:
		get_viewport().gui_release_focus()


func _remove_obstacle() -> void:
	if obstacle:
		obstacle.queue_free()
		obstacle = null


# ---------------- Boucle ----------------

func _process(delta: float) -> void:
	if logic == null:
		return
	_t += delta
	match mode:
		Mode.PREVIEW:
			_update_karts(0.0)
			_orbit_camera(delta, preview_side)
		Mode.RACE:
			var dt := 0.0 if paused else delta
			logic.update(dt)
			_update_karts(dt)
			_update_lanes(dt)
			_update_obstacle()
			_place_chase_camera(dt)
			sfx.set_engine_speed(logic.player.mult)
			_hud_timer -= delta
			if _hud_timer <= 0.0:
				_hud_timer = 0.15
				hud.update_race(logic)
			hud.update_minimap(_minimap_dots())
		Mode.RESULTS:
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


func _update_obstacle() -> void:
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
	camera.v_offset = -1.2 # remonte le kart au-dessus du panneau du mot
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
	camera.v_offset = 0.0
	camera.fov = 60.0


func _minimap_dots() -> Array:
	var dots := []
	var content := GameContent.get_content()
	for r in logic.racers:
		var k: Kart = karts[r]
		dots.append([Vector2(k.global_position.x, k.global_position.z), content.character(r.character).kart_color, r.is_player])
	return dots


# ---------------- Clavier ----------------

func _input(event: InputEvent) -> void:
	if mode != Mode.RACE or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		set_paused(not paused)
		get_viewport().set_input_as_handled()
		return
	if paused:
		return
	if event.unicode > 31:
		logic.handle_char(char(event.unicode))
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mode == Mode.RACE and logic and logic.state == "running":
		set_paused(true)
