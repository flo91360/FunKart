class_name Race
extends Node3D
## Le monde 3D de la course : circuit, karts, caméra, sons,
## interface de course (Hud) et écran d'arrivée (Results).
##
## Trois modes :
## - PREVIEW : les karts attendent sur la grille, la caméra tourne autour du
##   pilote (derrière le menu) ;
## - RACE : la course ;
## - RESULTS : écran d'arrivée.
##
## Cases cadeau (règles dans RaceLogic et Gifts) : paquets cadeau posés en
## travers de la piste, flèche au-dessus de la case choisie par l'enfant,
## huile et clou posés, effets sur les karts. Flèches gauche/droite : choix de
## la case à l'approche ; Entrée : utiliser le cadeau.

signal menu_requested

enum Mode { PREVIEW, RACE, RESULTS }

const GRID_LATERAL := 2.6
const RACE_LANES := [-5.0, -3.0, -1.0, 1.0, 3.0, 5.0]
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
var paused := false
## Décalage horizontal de la caméra en mode PREVIEW (< 0 : kart à droite de l'écran).
var preview_side := -2.8
var _track_key := ""
## Caméra de course : derrière et au-dessus du kart (mètres).
const CAMERA_BACK := 10.0
const CAMERA_HEIGHT := 3.8
const CAMERA_AIM_AHEAD := 8.0
## La caméra ne descend jamais à moins de cette hauteur au-dessus de la route ou du sol.
const CAMERA_MIN_CLEARANCE := 1.6
## Place du centre du kart à l'écran : fraction de la hauteur libre au-dessus
## du panneau du mot (0 : en haut de l'écran, 1 : au bord du panneau). Ses
## roues restent ainsi visibles au-dessus du panneau.
const KART_SCREEN_SPOT := 0.68
var _t := 0.0
var _hud_timer := 0.0
var _lane_timer := 0.0
var _orbit := 0.0
var _shake := 0.0
var _fov := 70.0
## Décentrement vertical de l'objectif (voir _set_lens).
var _lens_y := 0.0
## Cases cadeau : paquets [rangée][case], pièges posés, flèche de la case choisie.
var _gift_root: Node3D
var _box_nodes: Array = []
var _trap_nodes := {} # RaceLogic.Trap -> Node3D
var _marker: Node3D
## Un kart va droit sur le piège (ou l'évite) quand il en est à moins de cette distance (m).
const TRAP_STEER_DISTANCE := 26.0


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

	var content := GameContent.get_content()
	var bots := []
	var bot_chars := content.bot_characters()
	var bot_count := mini(int(p.get_setting("bot_count")), bot_chars.size())
	var kpm: Array = p.get_setting("bot_kpm")
	if p.get_setting("bot_auto"):
		kpm = AutoLevel.bot_kpm(Profiles.history(p), bot_count, kpm)
	for i in bot_count:
		var c := bot_chars[i]
		bots.append({"name": c.display_name, "character": c.id, "kpm": float(kpm[i]) if i < kpm.size() else 20.0})
	var player_name := p.name if p.name != "" else "Toi"
	# Niveau de l'enfant (temps laissé pour taper « évite » au début de la course).
	var level := AutoLevel.reference_kpm(Profiles.history(p))
	var player_info := {"name": player_name, "character": p.character_id, "kpm": level if level > 0.0 else Gifts.DEFAULT_KPM}
	logic = RaceLogic.new(p.settings, p.words(), track.length, player_info, bots)
	logic.countdown_tick.connect(_on_countdown)
	logic.race_started.connect(_on_go)
	logic.word_started.connect(_on_word_started)
	logic.key_ok.connect(_on_key_ok)
	logic.key_error.connect(_on_key_error)
	logic.word_completed.connect(_on_word_completed)
	logic.word_skipped.connect(_on_word_skipped)
	logic.player_finished.connect(_on_player_finished)
	logic.gift_box_taken.connect(_on_gift_box_taken)
	logic.gift_received.connect(_on_gift_received)
	logic.gift_kept.connect(_on_gift_kept)
	logic.gift_used.connect(_on_gift_used)
	logic.gift_blocked.connect(_on_gift_blocked)
	logic.gift_hit.connect(_on_gift_hit)
	logic.trap_added.connect(_on_trap_added)
	logic.trap_removed.connect(_on_trap_removed)
	logic.trap_dodged.connect(_on_trap_dodged)
	logic.dodge_started.connect(_on_dodge_started)
	logic.dodge_key_ok.connect(_on_dodge_key_ok)
	logic.dodge_ended.connect(_on_dodge_ended)
	_build_gift_boxes()
	for r in logic.racers:
		var k := Kart.new(content.character(r.character), r.name, not r.is_player)
		karts_root.add_child(k)
		k.lateral = -GRID_LATERAL if r.slot % 2 == 0 else GRID_LATERAL
		k.target_lateral = k.lateral
		k.update_visual(track, r.distance, 0.0, 1.0, 0.016, false, false)
		karts[r] = k
		r.lateral = k.lateral


func show_preview() -> void:
	mode = Mode.PREVIEW
	paused = false
	track.set_start_lights(0)
	# menu : le kart de l'enfant seul sur la grille, comme en vitrine
	for r in karts:
		(karts[r] as Kart).visible = r.is_player
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
	track.set_start_lights(1)
	sfx.play("count")
	sfx.start_race_audio(track.track_theme.music)
	get_viewport().gui_release_focus()
	_place_chase_camera(1.0)


func _load_track(index: int) -> void:
	var scenes := GameContent.get_content().tracks
	index = clampi(index, 0, scenes.size() - 1)
	var level := AppSettings.graphics()
	var key := "%d/%d" % [index, level]
	if track and key == _track_key:
		return
	if track:
		track.queue_free()
	track = scenes[index].instantiate()
	track.detail = 0.5 if level == AppSettings.Graphics.SIMPLE else 1.0
	track_slot.add_child(track)
	_track_key = key
	_apply_theme(track.track_theme)
	_apply_quality(level)


## Ciel, soleil, brume et rendu de l'image du thème (voir Ambience).
func _apply_theme(th: TrackTheme) -> void:
	Ambience.apply(environment.environment, sun, th, AppSettings.graphics(), AppSettings.advanced_renderer_active())


## Réglage « Graphismes » : Simple (rapide), Normal, Beau (rendu avancé).
func _apply_quality(level: int) -> void:
	var vp := get_viewport()
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][level]
	var advanced := AppSettings.advanced_renderer_active()
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if advanced else Viewport.SCREEN_SPACE_AA_DISABLED
	# Léger flou au loin, comme une profondeur de champ de caméra (rendu avancé).
	var attrs := camera.attributes as CameraAttributesPractical
	if attrs == null:
		attrs = CameraAttributesPractical.new()
		camera.attributes = attrs
	attrs.dof_blur_far_enabled = advanced
	attrs.dof_blur_far_distance = 160.0
	attrs.dof_blur_far_transition = 90.0
	attrs.dof_blur_amount = 0.05


# ---------------- Événements de la course ----------------

func _on_countdown(n: int) -> void:
	hud.show_center(str(n), 0.6)
	track.set_start_lights(4 - n)
	sfx.play("count")


func _on_go() -> void:
	hud.show_center("GO !", 0.6)
	track.set_start_lights(4)
	sfx.play("go")


func _on_word_started(word: String) -> void:
	hud.show_word(word, 0)
	hud.set_hint("Tape le mot pour avoir un turbo !")
	if profile.get_setting("speak"):
		sfx.speak(word)


func _on_key_ok(typed: int) -> void:
	hud.show_word(logic.player.word, typed)
	hud.set_hint("Tape le mot pour avoir un turbo !")
	sfx.play("key_ok")


func _on_key_error(expected: String) -> void:
	var letter := expected.to_upper() if profile.get_setting("uppercase") else expected
	hud.shake_word()
	var finger := KeyboardView.finger_hint(expected)
	if finger != "":
		hud.set_hint("Oups ! Cherche « %s » : %s" % [letter, finger], true)
	else:
		hud.set_hint("Oups ! Cherche la lettre « %s »" % letter, true)
	sfx.play("key_error")
	_shake = 0.15


func _on_word_completed(word: String) -> void:
	hud.show_word(word, word.length(), true)
	hud.set_hint("TURBO !")
	sfx.play("word")
	sfx.play("boost")
	get_tree().create_timer(1.0).timeout.connect(func():
		if mode == Mode.RACE and logic.player.word == "" and not logic.player.finished and not hud.dodging:
			hud.clear_word())


func _on_word_skipped(_word: String) -> void:
	hud.clear_word("Ce mot est passé, le suivant arrive !")


func _on_player_finished() -> void:
	sfx.play("finish")
	hud.end_dodge()
	hud.show_gift("")
	hud.set_choosing(false)
	hud.clear_toast()
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
	# Record : comparé aux courses d'avant (celle-ci n'est pas encore enregistrée).
	var previous_best := Progress.best_kpm(Profiles.history(profile))
	var record := Progress.is_record(previous_best, logic.kpm(), logic.stats.words.size())
	results.show_results(logic, profile.name, previous_best if record else -1.0)
	if record:
		sfx.play("word")
	var bot_kpm := []
	for r in logic.racers:
		if not r.is_player:
			bot_kpm.append(r.kpm)
	Profiles.add_history({
		"date": Time.get_datetime_string_from_system(),
		"character": GameContent.get_content().character(profile.character_id).display_name,
		"track": track.title,
		"word_lists": ", ".join(profile.active_titles()),
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
		"bot_auto": bool(profile.get_setting("bot_auto")),
		"letters": logic.stats.letters,
		"record": record,
	}, profile)


func set_paused(p: bool) -> void:
	if mode != Mode.RACE or logic.state == "finished":
		return
	paused = p
	hud.set_paused(p)
	sfx.engine.stream_paused = p
	if not p:
		get_viewport().gui_release_focus()


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
			for r in logic.racers:
				r.lateral = (karts[r] as Kart).lateral
			logic.update(dt)
			_update_karts(dt)
			_update_lanes(dt)
			_steer_for_gifts()
			_update_gift_props(dt)
			_update_gift_hud(delta)
			_place_chase_camera(dt)
			sfx.set_engine_speed(logic.player.mult)
			hud.set_boost(logic.player.boost > 0.0 and not logic.player.finished and not paused, delta)
			_hud_timer -= delta
			if _hud_timer <= 0.0:
				_hud_timer = 0.15
				hud.update_race(logic)
			hud.update_minimap(_minimap_dots())
		Mode.RESULTS:
			logic.update(delta)
			_update_karts(delta)
			_update_lanes(delta)
			_steer_for_gifts()
			_update_gift_props(delta)
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
		var boosting: bool = (r.boost > 0.0 or r.rocket > 0.0) and not r.finished
		var slowed: bool = r.word != "" and r.boost <= 0.0 and logic.state == "running"
		k.update_visual(track, r.distance + k.extra_distance, speed, r.mult, dt, boosting, slowed)
		k.update_effects(r.slip, r.flat, r.storm, r.rocket, dt)


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


## Caméra de course, derrière le kart. Elle ne descend jamais sous la route ni
## sous le sol (montées, descentes, creux). Le kart est cadré juste au-dessus
## du panneau du mot par un décentrement de l'objectif (_set_lens), sans
## abaisser la caméra : la hauteur du panneau varie (taille du mot, clavier).
func _place_chase_camera(dt: float) -> void:
	var p := logic.player
	var k: Kart = karts[p]
	var d: float = p.distance + k.extra_distance
	var f := track.frame_at(d)
	var target := f.origin + f.basis.x * k.lateral * 0.7 + f.basis.z * CAMERA_BACK + Vector3.UP * CAMERA_HEIGHT
	var w := 1.0 if dt >= 1.0 else 1.0 - exp(-dt * 7.0)
	var pos := camera.global_position.lerp(target, w)
	var road_y := maxf(f.origin.y, track.frame_at(d - CAMERA_BACK).origin.y)
	pos.y = maxf(pos.y, maxf(road_y, 0.0) + CAMERA_MIN_CLEARANCE)
	camera.global_position = pos
	var look := f.origin + f.basis.x * k.lateral * 0.85 + Vector3.UP * 0.6 - f.basis.z * CAMERA_AIM_AHEAD
	camera.look_at(look)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - dt)
		camera.global_position += camera.global_basis.x * randf_range(-1, 1) * _shake * 0.6
	var fov_target := 70.0 + (p.mult - 1.0) * 14.0
	_fov = fov_target if dt >= 1.0 else lerpf(_fov, fov_target, 1.0 - exp(-dt * 4.0))
	var wanted := _lens_offset_for(k.global_position + Vector3.UP * 1.2, _fov)
	_lens_y = wanted if dt >= 1.0 else lerpf(_lens_y, wanted, 1.0 - exp(-dt * 6.0))
	_set_lens(_fov, _lens_y)


## Objectif de la caméra : angle de vue vertical (degrés) et décentrement
## vertical (comme un objectif à décentrement : l'image glisse vers le haut
## ou le bas sans que la caméra bouge).
func _set_lens(fov_deg: float, offset_y: float) -> void:
	camera.projection = Camera3D.PROJECTION_FRUSTUM
	camera.size = 2.0 * camera.near * tan(deg_to_rad(fov_deg) / 2.0)
	camera.frustum_offset = Vector2(0.0, offset_y)


## Décentrement qui place ce point juste au-dessus du panneau du mot.
func _lens_offset_for(anchor: Vector3, fov_deg: float) -> float:
	var local := camera.global_transform.affine_inverse() * anchor
	if local.z > -0.5:
		return _lens_y
	var screen_h := get_viewport().get_visible_rect().size.y
	var free_h := hud.word_panel.global_position.y if hud.word_panel.global_position.y > 0.0 else screen_h
	var spot := clampf(free_h * KART_SCREEN_SPOT / screen_h, 0.2, 0.8) # fraction depuis le haut
	var half := camera.near * tan(deg_to_rad(fov_deg) / 2.0)
	# hauteur du point sur le plan proche, moins celle voulue à l'écran
	return clampf(local.y * camera.near / -local.z - (1.0 - 2.0 * spot) * half, -half, half)


## Caméra qui se balance autour du kart du joueur (menu, arrivée), vue de trois quarts avant.
## side décale le kart à droite (<0) ou à gauche (>0) de l'écran.
func _orbit_camera(dt: float, side: float) -> void:
	var k: Kart = karts[logic.player]
	_orbit += dt
	var center := k.global_position + Vector3.UP * 1.2
	var fwd := -k.global_basis.z
	var angle := 0.55 * signf(side) + sin(_orbit * 0.4) * 0.45
	if mode == Mode.PREVIEW:
		# menu : caméra du côté extérieur de la grille (le kart voisin ne
		# passe pas devant), qui se balance doucement
		var outside := -1.0 if k.lateral > 0.0 else 1.0
		angle = outside * (0.62 + sin(_orbit * 0.35) * 0.3)
	var dir := fwd.rotated(Vector3.UP, angle)
	camera.global_position = center + dir * 7.5 + Vector3.UP * 1.8
	camera.look_at(center)
	camera.global_position += camera.global_basis.x * side
	_lens_y = 0.0
	_set_lens(60.0, 0.0)


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
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_use_player_gift()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT:
		if logic.choose_box(-1 if event.keycode == KEY_LEFT else 1):
			sfx.play("key_ok")
		get_viewport().set_input_as_handled()
		return
	if event.unicode > 31:
		logic.handle_char(char(event.unicode))
		get_viewport().set_input_as_handled()


# ---------------- Cases cadeau ----------------

## Paquets cadeau sur la piste (une rangée en travers de la route à chaque
## distance de RaceLogic.rows) et flèche de la case choisie.
func _build_gift_boxes() -> void:
	if _gift_root:
		_gift_root.queue_free()
	_gift_root = Node3D.new()
	_gift_root.name = "Gifts"
	add_child(_gift_root)
	_box_nodes.clear()
	_trap_nodes.clear()
	for i in logic.rows.size():
		var f := track.frame_at(logic.rows[i])
		var row := []
		for j in Gifts.BOX_LATERALS.size():
			var b := GiftProps.gift_box(Gifts.BOX_COLORS[j % Gifts.BOX_COLORS.size()])
			_gift_root.add_child(b)
			b.global_transform = Transform3D(f.basis, f.origin + f.basis.x * Gifts.BOX_LATERALS[j] + f.basis.y * 1.05)
			row.append(b)
		_box_nodes.append(row)
	_marker = GiftProps.marker()
	_gift_root.add_child(_marker)
	_marker.visible = false


## Paquets qui tournent et rebondissent, disparaissent quand ils sont pris et
## réapparaissent ; flèche au-dessus de la case visée par l'enfant.
func _update_gift_props(dt: float) -> void:
	for i in _box_nodes.size():
		for j in _box_nodes[i].size():
			var b: Node3D = _box_nodes[i][j]
			var spin: Node3D = b.get_node("Spin")
			var want := 1.0 if logic.box_ready(i, j) else 0.0
			var sc := move_toward(spin.scale.x, want, dt * (3.0 if want > 0.0 else 12.0))
			spin.scale = Vector3.ONE * maxf(sc, 0.01)
			b.visible = sc > 0.02
			spin.rotation.y = _t * 1.3 + j * 0.8
			spin.position.y = sin(_t * 2.4 + j * 1.3) * 0.12
	var p := logic.player
	_marker.visible = mode == Mode.RACE and logic.state == "running" and p.box_row >= 0 and p.box_choice >= 0
	if _marker.visible:
		var box: Node3D = _box_nodes[p.box_row][p.box_choice]
		_marker.global_position = box.global_position + box.global_basis.y * (1.9 + absf(sin(_t * 5.0)) * 0.35)
		_marker.rotation.y = _t * 2.0


## Interface des cadeaux à chaque image : choix de la case, temps pour
## « évite », pluie et mot flou de la tempête.
func _update_gift_hud(delta: float) -> void:
	var p := logic.player
	var running := logic.state == "running" and not p.finished
	hud.set_choosing(running and p.box_row >= 0, p.gift != "")
	if hud.dodging:
		hud.set_dodge_time(logic.dodge_left())
	hud.set_storm(running and p.storm > 0.0 and not paused, delta)
	hud.set_blur(0.0 if hud.dodging or not running else p.blur / Gifts.STORM_BLUR_TIME)


## Pilote automatique et cadeaux : à l'approche des cases, le kart va vers la
## case visée ; près d'une huile ou d'un clou, il roule dessus, sauf s'il
## l'évite (il le contourne).
func _steer_for_gifts() -> void:
	for r in logic.racers:
		var k: Kart = karts[r]
		k.lateral_speed = Kart.LATERAL_SPEED
		if r.finished or logic.state != "running":
			continue
		var t = logic.trap_ahead(r)
		if t != null and logic.gap_to(r, t.distance) < TRAP_STEER_DISTANCE:
			var dodging: bool = not r.dodge.is_empty() and r.dodge.trap == t and logic.will_dodge(r)
			var side := -1.0 if t.lateral > 0.0 else 1.0
			k.target_lateral = t.lateral + (side * Gifts.DODGE_SWERVE if dodging else 0.0)
			k.lateral_speed = Gifts.STEER_SPEED
		elif r.box_row >= 0 and r.box_choice >= 0:
			k.target_lateral = Gifts.BOX_LATERALS[r.box_choice]
			k.lateral_speed = Gifts.STEER_SPEED


## Entrée : l'enfant utilise son cadeau.
func _use_player_gift() -> void:
	var p := logic.player
	if logic.state != "running" or p.finished:
		return
	if p.gift == "":
		if logic.gifts_on:
			hud.show_toast("Pas de cadeau : passe sur une case cadeau !", Color.WHITE, 1.4)
		return
	logic.use_gift(p)


func _kart_pos(r) -> Vector3:
	return (karts[r] as Kart).global_position


func _on_gift_box_taken(row: int, box: int, r) -> void:
	var n: Node3D = _box_nodes[row][box]
	Mk.burst(self, n.global_position, [Gifts.BOX_COLORS[box % Gifts.BOX_COLORS.size()], Color.WHITE, Ui.YELLOW], 36, 7.0)
	if r.is_player:
		sfx.play("gift")


func _on_gift_received(r, kind: String) -> void:
	if not r.is_player:
		return
	hud.show_gift(kind)
	hud.show_toast("Cadeau : %s ! Appuie sur Entrée." % Gifts.NAMES[kind], Gifts.COLORS[kind].lightened(0.55))


func _on_gift_kept(r) -> void:
	if r.is_player:
		hud.show_toast("Un seul cadeau à la fois : Entrée pour l'utiliser !", Color.WHITE, 1.8)


func _on_gift_used(r, kind: String, target) -> void:
	var pos := _kart_pos(r) + Vector3.UP * 1.2
	match kind:
		Gifts.CHARGE:
			Mk.burst(self, pos, [Color("#ffd60a"), Color("#4cc9f0"), Color.WHITE], 40, 9.0)
		Gifts.ROCKET:
			Mk.burst(self, pos, [Color("#ffb703"), Color("#e63946"), Color.WHITE], 40, 9.0)
	if r.is_player:
		hud.show_gift("")
		match kind:
			Gifts.CHARGE:
				sfx.play("boost")
				hud.show_toast("Charge électrique : TURBO !", Ui.YELLOW)
			Gifts.OIL:
				hud.show_toast("Huile posée derrière toi !")
			Gifts.NAIL:
				hud.show_toast("Clou posé derrière toi !")
			Gifts.STORM:
				sfx.play("storm")
				hud.show_toast("Tempête sur %s, le premier !" % target.name, Color("#bde0fe"))
			Gifts.ROCKET:
				sfx.play("boost")
				hud.show_toast("Fusée : tu rattrapes %s !" % target.name, Color("#ffb703"))
	elif kind == Gifts.ROCKET and target == logic.player:
		hud.show_toast("%s te rattrape avec une fusée !" % r.name, Color("#ffb4a2"))


func _on_gift_blocked(kind: String) -> void:
	sfx.play("key_error")
	if kind == Gifts.STORM:
		hud.show_toast("Tu es 1er : garde ta tempête pour plus tard !", Color.WHITE, 2.0)
	else:
		hud.show_toast("Personne à rattraper : garde ta fusée !", Color.WHITE, 2.0)


func _on_gift_hit(victim, kind: String, by) -> void:
	var pos := _kart_pos(victim) + Vector3.UP * 0.4
	match kind:
		Gifts.OIL:
			Mk.burst(self, pos, [Color("#14121c"), Color("#5e548e")], 24, 5.0)
		Gifts.NAIL:
			Mk.burst(self, pos, [Color("#c9ced6"), Color("#6c757d"), Color.WHITE], 24, 6.0)
	if victim.is_player:
		_shake = 0.35
		sfx.play("hit")
		match kind:
			Gifts.OIL:
				hud.show_toast("Oh non, de l'huile ! Ton kart glisse !", Color("#ffb4a2"))
			Gifts.NAIL:
				hud.show_toast("Aïe, un clou ! Ton pneu est crevé !", Color("#ffb4a2"))
			Gifts.STORM:
				sfx.play("storm")
				hud.show_toast("%s t'envoie une tempête !" % by.name, Color("#bde0fe"))
	elif by == logic.player and kind != Gifts.STORM:
		sfx.play("word")
		hud.show_toast(("%s glisse sur ton huile !" if kind == Gifts.OIL else "%s roule sur ton clou !") % victim.name, Ui.YELLOW)


func _on_trap_added(t) -> void:
	var n := GiftProps.oil_puddle() if t.kind == Gifts.OIL else GiftProps.nail_board()
	_gift_root.add_child(n)
	var f := track.frame_at(t.distance)
	n.global_transform = Transform3D(f.basis, f.origin + f.basis.x * t.lateral)
	n.scale = Vector3.ONE * 0.2
	n.create_tween().tween_property(n, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_trap_nodes[t] = n
	if t.owner == logic.player or logic.next_victim(t) == logic.player:
		sfx.play("drop")


func _on_trap_removed(t) -> void:
	var n: Node3D = _trap_nodes.get(t)
	_trap_nodes.erase(t)
	if n == null or not is_instance_valid(n):
		return
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector3.ONE * 0.05, 0.3)
	tw.tween_callback(n.queue_free)


func _on_trap_dodged(r, t) -> void:
	if not r.is_player and t.owner == logic.player:
		hud.show_toast("%s évite ton %s !" % [r.name, "huile" if t.kind == Gifts.OIL else "clou"], Color.WHITE, 1.6)


func _on_dodge_started(t) -> void:
	hud.show_dodge(Gifts.DODGE_WORD, 0, t.kind)
	sfx.play("alarm")
	if profile.get_setting("speak"):
		sfx.speak(Gifts.DODGE_WORD)


func _on_dodge_key_ok(typed: int) -> void:
	var p := logic.player
	hud.show_dodge(Gifts.DODGE_WORD, typed, p.dodge.trap.kind if not p.dodge.is_empty() else Gifts.OIL)
	sfx.play("key_ok")


func _on_dodge_ended(result: String) -> void:
	hud.end_dodge()
	if result == "ok":
		sfx.play("dodge")
		hud.show_toast("Bravo, tu l'évites !", Ui.YELLOW, 1.6)
	# Le mot de la course revient (là où l'enfant s'était arrêté).
	var p := logic.player
	if p.finished:
		return
	if p.word != "":
		hud.show_word(p.word, p.typed)
		hud.set_hint("Tape le mot pour avoir un turbo !")
	else:
		hud.clear_word()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mode == Mode.RACE and logic and logic.state == "running":
		set_paused(true)
