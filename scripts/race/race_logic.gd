class_name RaceLogic
extends RefCounted
## Règles de la course, indépendantes de l'affichage.
##
## Chaque pilote roule en pilote automatique à une vitesse de croisière.
## Régulièrement, un mot apparaît : tant qu'il n'est pas entièrement tapé, le
## kart ralentit ; une fois tapé, le kart reçoit un turbo temporaire.
## Les adversaires suivent exactement les mêmes règles : ils « tapent » leurs
## mots à une vitesse (en frappes par minute) réglée par l'adulte.
## Le turbo dure « boost_duration » secondes, même si le mot suivant est déjà
## affiché. Un mot sans aucune bonne lettre pendant SKIP_AFTER secondes est
## passé (sans turbo) : l'enfant n'est jamais bloqué sur un mot.
##
## Cases cadeau (réglages et règles dans Gifts) : des rangées de cases en
## travers de la piste donnent un cadeau à chaque kart qui passe dessus (un
## seul à la fois). L'enfant choisit sa case avec les flèches à l'approche
## (choose_box) et utilise son cadeau avec Entrée (use_gift) ; les adversaires
## suivent les mêmes règles. Huile et clou sont posés derrière le kart et
## touchent le kart suivant, sauf s'il tape « évite » à temps.

signal countdown_tick(n: int)
signal race_started
signal word_started(word: String)
signal key_ok(typed: int)
signal key_error(expected: String)
signal word_completed(word: String)
signal word_skipped(word: String)
signal player_finished
## Cases cadeau (tous les karts) : case prise, cadeau reçu, case prise avec
## déjà un cadeau en main, cadeau utilisé (target : kart visé ou rattrapé).
signal gift_box_taken(row: int, box: int, racer)
signal gift_received(racer, kind: String)
signal gift_kept(racer)
signal gift_used(racer, kind: String, target)
## L'enfant ne peut pas utiliser son cadeau pour l'instant (il le garde).
signal gift_blocked(kind: String)
## Un kart subit une huile, un clou ou une tempête (by : kart qui l'a envoyé).
signal gift_hit(victim, kind: String, by)
signal trap_added(trap)
signal trap_removed(trap)
signal trap_dodged(racer, trap)
## Esquive de l'enfant : « évite » apparaît, bonne lettre, fin (result :
## "ok" mot tapé, "hit" piège touché, "cancel" plus de piège à éviter).
signal dodge_started(trap)
signal dodge_key_ok(typed: int)
signal dodge_ended(result: String)

const ACCENTS := {
	"à": "a", "â": "a", "ä": "a", "á": "a",
	"é": "e", "è": "e", "ê": "e", "ë": "e",
	"î": "i", "ï": "i", "í": "i",
	"ô": "o", "ö": "o", "ó": "o",
	"ù": "u", "û": "u", "ü": "u", "ú": "u",
	"ç": "c", "ÿ": "y", "ñ": "n",
}

const GRID_ROW_SPACING := 5.0
## Secondes sans bonne lettre avant de passer le mot.
const SKIP_AFTER := 15.0


class Racer:
	var name := ""
	var character := ""
	var is_player := false
	var kpm := 20.0
	var slot := 0
	var distance := 0.0 # mètres parcourus depuis la ligne de départ
	var mult := 1.0 # multiplicateur de vitesse actuel
	var word := ""
	var typed := 0
	var word_elapsed := 0.0
	var word_duration := 0.0
	var word_errors := 0
	var stuck := 0.0 # secondes depuis la dernière bonne lettre
	var last_key_at := 0.0 # moment (dans le mot) de la dernière bonne lettre
	var next_word_in := 1.5
	var boost := 0.0
	var finished := false
	var finish_time := -1.0
	var predicted_finish := INF
	# Cases cadeau
	var lateral := 0.0 # position sur la largeur de la piste (m), recopiée du kart par Race
	var gift := "" # cadeau gardé (Gifts.KINDS), "" : aucun
	var gift_wait := 0.0 # adversaire : secondes avant d'utiliser son cadeau
	var box_row := -1 # rangée de cases en approche (-1 : pilote automatique)
	var box_choice := -1 # case visée dans cette rangée
	var slip := 0.0 # secondes de glissade (huile)
	var flat := 0.0 # secondes de pneu crevé (clou)
	var storm := 0.0 # secondes de tempête
	var blur := 0.0 # secondes de mot flou (tempête)
	var blur_pending := false # le prochain mot sera flou
	var rocket := 0.0 # secondes de fusée
	var rocket_target = null # kart à rattraper
	## Esquive en cours : {trap, typed, time, done, gap0} (enfant), {trap, time, need} (adversaire).
	var dodge := {}

	func copy():
		var r = Racer.new()
		for p in ["name", "character", "is_player", "kpm", "slot", "distance", "mult", "word",
				"typed", "word_elapsed", "word_duration", "word_errors", "stuck", "last_key_at", "next_word_in", "boost",
				"finished", "finish_time", "lateral", "slip", "flat", "storm"]:
			r.set(p, get(p))
		return r


## Huile ou clou posé sur la piste.
class Trap:
	var kind := ""
	var distance := 0.0 # distance (depuis le départ) où il est posé
	var lateral := 0.0
	var owner = null # kart qui l'a posé (il ne le subit pas)
	var age := 0.0


var settings: Dictionary
var words := PackedStringArray()
var laps := 3
var track_length := 1.0
var race_length := 1.0
var base_speed := 1.0 # mètres par seconde en vitesse de croisière
var time := 0.0
var state := "countdown" # countdown -> running -> finished
var countdown := 3.0
var racers: Array = []
var player: Racer
var finished_count := 0
## letters : chiffres par lettre attendue (voir LetterStats).
var stats := {"correct": 0, "errors": 0, "active_time": 0.0, "words": [], "skipped": 0, "letters": {}}
var _recent: Array[String] = []
## Cases cadeau (réglage du profil « gifts »).
var gifts_on := true
## Rangées de cases : distance sur un tour (m).
var rows: Array[float] = []
## boxes[rangée][case] : secondes avant que la case réapparaisse (0 : présente).
var boxes: Array = []
var traps: Array = []


func _init(p_settings: Dictionary, word_list: PackedStringArray, p_track_length: float,
		player_info: Dictionary, bot_infos: Array) -> void:
	settings = p_settings
	var max_len := int(settings.max_word_length)
	var all_words := PackedStringArray()
	for w in word_list:
		all_words.append(WordList.typeable(w))
	for w in all_words:
		if w.length() <= max_len:
			words.append(w)
	if words.is_empty():
		words = all_words if not all_words.is_empty() else PackedStringArray(["kart"])
	laps = int(settings.laps)
	track_length = p_track_length
	race_length = laps * track_length
	base_speed = track_length / float(settings.lap_time)
	gifts_on = bool(settings.get("gifts", true))
	if gifts_on:
		for f in Gifts.ROWS:
			rows.append(float(f) * track_length)
			var row := []
			for i in Gifts.BOX_LATERALS.size():
				row.append(0.0)
			boxes.append(row)

	# Grille de départ en quinconce ; le joueur part dernier, comme dans les jeux de kart.
	var infos := bot_infos.duplicate()
	var p_info := player_info.duplicate()
	p_info["is_player"] = true
	infos.append(p_info)
	for i in infos.size():
		var r := Racer.new()
		r.name = infos[i].name
		r.character = infos[i].character
		r.is_player = infos[i].get("is_player", false)
		r.kpm = float(infos[i].get("kpm", 20))
		r.slot = i
		r.distance = -3.0 - floorf(i / 2.0) * GRID_ROW_SPACING - (i % 2) * 1.5
		r.lateral = -2.6 if i % 2 == 0 else 2.6
		r.next_word_in = 1.5 if r.is_player else 1.5 + randf() * 0.4
		racers.append(r)
		if r.is_player:
			player = r


func _pick_word(for_player: bool) -> String:
	var pool := words
	if for_player and words.size() > 1:
		# Évite de redonner un des derniers mots à l'enfant.
		var n := mini(5, words.size() - 1)
		var avoid := _recent.slice(maxi(0, _recent.size() - n))
		var filtered := PackedStringArray()
		for w in words:
			if not avoid.has(w):
				filtered.append(w)
		if not filtered.is_empty():
			pool = filtered
	var w := pool[randi() % pool.size()]
	if for_player:
		_recent.append(w)
	return w


func update(delta: float) -> void:
	if state == "countdown":
		var before := ceili(countdown)
		countdown -= delta
		var after := ceili(countdown)
		if after != before and after > 0:
			countdown_tick.emit(after)
		if countdown <= 0.0:
			state = "running"
			race_started.emit()
		return
	time += delta
	if _gifts_live():
		_update_gift_world(delta)
	for r in racers:
		if not r.finished:
			_update_racer(r, delta, time, true)


func _update_racer(r, dt: float, now: float, live: bool) -> void:
	# Pendant que l'enfant tape « évite », son mot attend (il ne sera pas passé).
	var dodging := is_dodging(r)
	if r.word == "":
		if not dodging:
			r.next_word_in -= dt
		elif live:
			stats.active_time += dt # « évite » est un mot à l'écran
		if r.next_word_in <= 0.0:
			_spawn_word(r, live)
	else:
		if not dodging:
			r.word_elapsed += dt
			r.stuck += dt
			r.blur = maxf(0.0, r.blur - dt)
		if r.is_player and live:
			stats.active_time += dt
		if not r.is_player and r.word_elapsed >= r.word_duration:
			_complete_word(r, live)
		elif r.is_player and r.stuck >= SKIP_AFTER:
			_skip_word(r, live)
	if r.boost > 0.0:
		r.boost = maxf(0.0, r.boost - dt)
	r.slip = maxf(0.0, r.slip - dt)
	r.flat = maxf(0.0, r.flat - dt)
	r.storm = maxf(0.0, r.storm - dt)
	var gifts := live and _gifts_live()
	if gifts:
		_approach_boxes(r)
		_watch_traps(r, dt)
		if not r.is_player:
			_bot_gift(r, dt)

	var target := 1.0
	if r.boost > 0.0:
		target = float(settings.boost_factor)
	elif r.word != "":
		target = float(settings.slow_factor)
	if r.rocket > 0.0:
		target = maxf(target, Gifts.ROCKET_FACTOR)
	else:
		target *= Gifts.effect_factor(r.slip, r.flat, r.storm)
	var rate := 4.0 if target > r.mult else 3.0
	if target < r.mult and (r.slip > 0.0 or r.flat > 0.0):
		rate = 8.0 # huile, clou : le kart freine d'un coup
	r.mult += (target - r.mult) * minf(1.0, rate * dt)
	var before: float = r.distance
	r.distance += base_speed * r.mult * dt
	if r.rocket > 0.0:
		_fly_rocket(r, dt)
	if gifts:
		_cross_gifts(r, before)

	if r.distance >= race_length:
		r.distance = race_length
		r.finished = true
		r.finish_time = now
		r.word = ""
		r.gift = ""
		r.box_row = -1
		r.box_choice = -1
		r.rocket = 0.0
		if r.is_player and is_dodging(r) and live:
			dodge_ended.emit("cancel")
		r.dodge = {}
		if live:
			finished_count += 1
			if r.is_player:
				_on_player_finish()


func _spawn_word(r, live: bool) -> void:
	r.word = _pick_word(r.is_player)
	r.typed = 0
	r.word_elapsed = 0.0
	r.word_errors = 0
	r.stuck = 0.0
	r.last_key_at = 0.0
	if not r.is_player:
		# Temps de frappe simulé avec un peu de variabilité (±20 %).
		r.word_duration = r.word.length() * 60.0 / maxf(1.0, r.kpm) * randf_range(0.8, 1.2)
	if r.blur_pending:
		# tempête : ce mot est flou
		r.blur_pending = false
		if r.is_player:
			r.blur = Gifts.STORM_BLUR_TIME
		else:
			r.word_duration += Gifts.STORM_BOT_DELAY
	if r.is_player and live:
		word_started.emit(r.word)


func _complete_word(r, live: bool) -> void:
	var w: String = r.word
	if r.is_player and live:
		stats.words.append({"word": w, "time": r.word_elapsed, "errors": r.word_errors})
	r.word = ""
	r.blur = 0.0
	r.boost = float(settings.boost_duration)
	r.next_word_in = float(settings.word_gap) + (0.0 if r.is_player else randf_range(-0.3, 0.3))
	if r.is_player and live:
		word_completed.emit(w)


## Mot passé sans turbo (aucune bonne lettre depuis SKIP_AFTER secondes).
func _skip_word(r, live: bool) -> void:
	var w: String = r.word
	r.word = ""
	r.next_word_in = float(settings.word_gap)
	if live:
		stats.skipped += 1
		word_skipped.emit(w)


static func normalize_char(c: String, accents_tolerant: bool) -> String:
	var s := c.to_lower()
	if accents_tolerant:
		s = ACCENTS.get(s, s)
	return s


## Lettre tapée par l'enfant.
func handle_char(c: String) -> void:
	var p := player
	if state != "running" or p.finished:
		return
	if is_dodging(p):
		_dodge_char(c)
		return
	if p.word == "":
		return
	var expected := p.word[p.typed]
	var tol := bool(settings.accents_tolerant)
	var letter := normalize_char(expected, false)
	var ls: Array = stats.letters.get(letter, LetterStats.empty())
	stats.letters[letter] = ls
	if normalize_char(c, tol) == normalize_char(expected, tol):
		ls[LetterStats.OK] += 1
		if p.typed > 0:
			# temps pour trouver la lettre (pas pour la première : lecture du mot)
			ls[LetterStats.TIME] += p.word_elapsed - p.last_key_at
			ls[LetterStats.TIMED] += 1
		p.last_key_at = p.word_elapsed
		p.typed += 1
		p.stuck = 0.0
		stats.correct += 1
		key_ok.emit(p.typed)
		if p.typed >= p.word.length():
			_complete_word(p, true)
	else:
		stats.errors += 1
		ls[LetterStats.ERRORS] += 1
		p.word_errors += 1
		key_error.emit(expected)


func _on_player_finish() -> void:
	state = "finished"
	# Heure d'arrivée prévue des adversaires encore en course : on simule une
	# copie de chacun jusqu'à la ligne.
	for r in racers:
		if r.finished:
			continue
		var clone = r.copy()
		var t := time
		var i := 0
		while not clone.finished and i < 200000:
			t += 0.05
			_update_racer(clone, 0.05, t, false)
			i += 1
		r.predicted_finish = clone.finish_time if clone.finished else INF
	player_finished.emit()


func finish_of(r) -> float:
	return r.finish_time if r.finished else r.predicted_finish


## Classement : arrivés (par temps) puis en course (par distance).
func standings() -> Array:
	var list := racers.duplicate()
	list.sort_custom(_compare)
	return list


func _compare(a, b) -> bool:
	if state == "finished":
		return finish_of(a) < finish_of(b)
	if a.finished and b.finished:
		return a.finish_time < b.finish_time
	if a.finished != b.finished:
		return a.finished
	return a.distance > b.distance


func player_position() -> int:
	return standings().find(player) + 1


func current_lap(r = null) -> int:
	if r == null:
		r = player
	return clampi(floori(maxf(r.distance, 0.0) / track_length) + 1, 1, laps)


## Frappes par minute : bonnes frappes / temps passé avec un mot à l'écran.
func kpm() -> float:
	var minutes: float = stats.active_time / 60.0
	return stats.correct / minutes if minutes > 0.0 else 0.0


func accuracy() -> float:
	var total: int = stats.correct + stats.errors
	return float(stats.correct) / total if total > 0 else 1.0


func average_word_time() -> float:
	if stats.words.is_empty():
		return 0.0
	var s := 0.0
	for w in stats.words:
		s += w.time
	return s / stats.words.size()


# ---------------- Cases cadeau ----------------

func _gifts_live() -> bool:
	return gifts_on and state == "running"


## L'enfant est en train de taper « évite ».
func is_dodging(r) -> bool:
	return r.is_player and not r.dodge.is_empty() and not r.dodge.done


## Écart (m, le long de la piste) jusqu'à la prochaine fois que ce kart passera à cette distance.
func gap_to(r, at: float) -> float:
	return fposmod(at - r.distance, track_length)


func box_ready(row: int, box: int) -> bool:
	return boxes[row][box] <= 0.0


## Cases qui réapparaissent, pièges qui disparaissent.
func _update_gift_world(dt: float) -> void:
	for row in boxes:
		for i in row.size():
			row[i] = maxf(0.0, row[i] - dt)
	for t in traps.duplicate():
		t.age += dt
		if t.age >= Gifts.TRAP_LIFETIME:
			_remove_trap(t)


func _remove_trap(t) -> void:
	traps.erase(t)
	trap_removed.emit(t)


## À l'approche d'une rangée de cases : choix de la case (l'enfant la change
## avec les flèches, les adversaires visent une case libre).
func _approach_boxes(r) -> void:
	if rows.is_empty():
		return
	var row := -1
	var gap := INF
	for i in rows.size():
		var g := gap_to(r, rows[i])
		if g < gap:
			gap = g
			row = i
	if gap / maxf(base_speed * r.mult, 1.0) > Gifts.APPROACH_TIME:
		r.box_row = -1
		r.box_choice = -1
		return
	if r.box_row != row:
		r.box_row = row
		r.box_choice = _best_box(r, row)
	elif not r.is_player and not box_ready(row, r.box_choice):
		r.box_choice = _best_box(r, row) # case prise par un autre : une autre case libre


## Case libre la plus proche, en évitant celles déjà visées par un autre kart.
func _best_box(r, row: int) -> int:
	var best := 0
	var best_score := INF
	for i in Gifts.BOX_LATERALS.size():
		var score := absf(Gifts.BOX_LATERALS[i] - r.lateral)
		if not box_ready(row, i):
			score += 100.0
		for o in racers:
			if o != r and o.box_row == row and o.box_choice == i:
				score += 2.5
		if score < best_score:
			best_score = score
			best = i
	return best


## Flèche gauche (-1) ou droite (+1) à l'approche des cases. Renvoie true si
## la case visée a changé.
func choose_box(dir: int) -> bool:
	var p := player
	if not _gifts_live() or p.finished or p.box_row < 0:
		return false
	var c := clampi(p.box_choice + dir, 0, Gifts.BOX_LATERALS.size() - 1)
	if c == p.box_choice:
		return false
	p.box_choice = c
	return true


## Cases cadeau et pièges sur lesquels le kart vient de passer.
func _cross_gifts(r, before: float) -> void:
	var moved: float = r.distance - before
	if moved <= 0.0:
		return
	for i in rows.size():
		var g := fposmod(rows[i] - before, track_length)
		if g > 0.0 and g <= moved:
			_take_box(r, i)
	for t in traps.duplicate():
		if t.owner == r or not traps.has(t):
			continue
		var g := fposmod(t.distance - before, track_length)
		if g <= 0.0 or g > moved or r.rocket > 0.0: # la fusée passe par-dessus
			continue
		var dodged := false
		if not r.dodge.is_empty() and r.dodge.trap == t:
			dodged = will_dodge(r)
			if r.is_player and not dodged:
				dodge_ended.emit("hit")
			r.dodge = {}
		if dodged:
			trap_dodged.emit(r, t)
			continue
		_remove_trap(t)
		_hit(r, t.kind, t.owner)


func _take_box(r, row: int) -> void:
	var box := Gifts.nearest_box(r.lateral)
	r.box_row = -1
	r.box_choice = -1
	if not box_ready(row, box):
		return # case déjà prise : elle réapparaît bientôt
	boxes[row][box] = Gifts.BOX_RESPAWN
	gift_box_taken.emit(row, box, r)
	if r.gift != "":
		gift_kept.emit(r) # un seul cadeau à la fois
		return
	r.gift = Gifts.random_gift(position_of(r) == 1)
	r.gift_wait = randf_range(Gifts.BOT_USE_DELAY[0], Gifts.BOT_USE_DELAY[1])
	gift_received.emit(r, r.gift)


func position_of(r) -> int:
	return standings().find(r) + 1


## Premier kart encore en course (celui que vise la tempête).
func leader():
	for r in standings():
		if not r.finished:
			return r
	return null


## Kart juste devant dans le classement (celui que rattrape la fusée), s'il est encore en course.
func ahead_of(r):
	var list := standings()
	var i := list.find(r)
	if i <= 0 or list[i - 1].finished:
		return null
	return list[i - 1]


## Kart qui suit, encore en course (null : personne derrière).
func behind_of(r):
	var list := standings()
	var i := list.find(r)
	if i < 0 or i + 1 >= list.size() or list[i + 1].finished:
		return null
	return list[i + 1]


## Le cadeau peut-il servir maintenant ? (tempête : pas si on est premier ;
## fusée : il faut quelqu'un à rattraper)
func can_use(r) -> bool:
	match r.gift:
		"":
			return false
		Gifts.STORM:
			var l = leader()
			return l != null and l != r
		Gifts.ROCKET:
			return ahead_of(r) != null
	return true


## Utilise le cadeau du kart (Entrée pour l'enfant). Renvoie false s'il n'a
## pas de cadeau ou s'il le garde pour plus tard (inutilisable pour l'instant).
func use_gift(r) -> bool:
	if not _gifts_live() or r.finished or r.gift == "":
		return false
	var kind: String = r.gift
	if not can_use(r):
		if r.is_player:
			gift_blocked.emit(kind)
		return false
	var target = null
	r.gift = ""
	match kind:
		Gifts.CHARGE:
			r.boost = maxf(r.boost, float(settings.boost_duration))
		Gifts.OIL, Gifts.NAIL:
			var t := Trap.new()
			t.kind = kind
			t.distance = r.distance - Gifts.TRAP_BEHIND
			t.lateral = r.lateral
			t.owner = r
			traps.append(t)
			trap_added.emit(t)
		Gifts.STORM:
			target = leader()
		Gifts.ROCKET:
			target = ahead_of(r)
			r.rocket = Gifts.ROCKET_TIME
			r.rocket_target = target
	gift_used.emit(r, kind, target)
	if kind == Gifts.STORM:
		_hit(target, kind, r)
	return true


## Effet d'une huile, d'un clou ou d'une tempête.
func _hit(r, kind: String, by) -> void:
	match kind:
		Gifts.OIL:
			r.slip = Gifts.SLIP_TIME
		Gifts.NAIL:
			r.flat = Gifts.FLAT_TIME
		Gifts.STORM:
			r.storm = Gifts.STORM_TIME
			# Le mot à taper (celui à l'écran, sinon le prochain) est flou.
			if r.word != "" and r.typed < r.word.length():
				if r.is_player:
					r.blur = Gifts.STORM_BLUR_TIME
				else:
					r.word_duration += Gifts.STORM_BOT_DELAY
			else:
				r.blur_pending = true
	gift_hit.emit(r, kind, by)


## Fusée : en ROCKET_TIME secondes, le kart passe juste devant celui qu'il rattrape.
func _fly_rocket(r, dt: float) -> void:
	var t = r.rocket_target
	if t != null and not t.finished:
		var gap: float = t.distance + Gifts.ROCKET_MARGIN - r.distance
		if gap > 0.0:
			r.distance += gap * minf(1.0, dt / r.rocket)
	r.rocket = maxf(0.0, r.rocket - dt)
	if r.rocket <= 0.0:
		r.rocket_target = null


## Adversaire : utilise son cadeau après un petit délai, quand il sert.
func _bot_gift(r, dt: float) -> void:
	if r.gift == "":
		return
	r.gift_wait -= dt
	if r.gift_wait > 0.0:
		return
	if r.gift == Gifts.OIL or r.gift == Gifts.NAIL:
		# posé quand un kart le suit (l'enfant aussi peut être visé)
		var b = behind_of(r)
		if b == null:
			return
		if r.distance - b.distance > Gifts.BOT_TRAP_RANGE and r.gift_wait > -Gifts.BOT_MAX_HOLD:
			return
	if can_use(r):
		use_gift(r)


## Huile ou clou que ce kart sera le prochain à croiser (null : aucun).
func trap_ahead(r):
	var best = null
	var best_gap := INF
	for t in traps:
		if t.owner == r:
			continue
		var g := gap_to(r, t.distance)
		if g < best_gap and next_victim(t) == r:
			best_gap = g
			best = t
	return best


## Prochain kart qui passera sur ce piège (pas celui qui l'a posé).
func next_victim(t):
	var best = null
	var best_gap := INF
	for o in racers:
		if o == t.owner or o.finished:
			continue
		var g := gap_to(o, t.distance)
		if g < best_gap:
			best_gap = g
			best = o
	return best


## Temps laissé à ce kart pour taper « évite » (d'après sa vitesse de frappe).
func dodge_window(r) -> float:
	var level: float = r.kpm
	if r.is_player and stats.correct >= Gifts.LIVE_KPM_KEYS and kpm() > 0.0:
		level = kpm()
	return Gifts.dodge_window(level)


## Le kart évitera-t-il le piège de son esquive en cours ?
func will_dodge(r) -> bool:
	if r.dodge.is_empty():
		return false
	if r.is_player:
		return r.dodge.done
	return r.dodge.time >= r.dodge.need


## Esquive : « évite » apparaît quand le kart arrivera sur le piège dans le
## temps laissé pour le taper.
func _watch_traps(r, dt: float) -> void:
	if not r.dodge.is_empty():
		var current = r.dodge.trap
		if not traps.has(current) or next_victim(current) != r:
			if is_dodging(r):
				dodge_ended.emit("cancel")
			r.dodge = {}
		else:
			r.dodge.time += dt
		return
	var t = trap_ahead(r)
	if t == null:
		return
	var gap := gap_to(r, t.distance)
	if gap / maxf(base_speed * r.mult, 1.0) > dodge_window(r):
		return
	if r.is_player:
		r.dodge = {"trap": t, "typed": 0, "time": 0.0, "done": false, "gap0": maxf(gap, 0.1)}
		dodge_started.emit(t)
	else:
		# même règle pour les adversaires : ils « tapent » le mot à leur vitesse
		var need := randf_range(Gifts.BOT_DODGE_REACTION[0], Gifts.BOT_DODGE_REACTION[1])
		need += Gifts.DODGE_WORD.length() * 60.0 / maxf(1.0, r.kpm) * randf_range(Gifts.BOT_DODGE_SPREAD[0], Gifts.BOT_DODGE_SPREAD[1])
		r.dodge = {"trap": t, "time": 0.0, "need": need}


## Part du temps d'esquive qui reste (1 : début, 0 : sur le piège).
func dodge_left() -> float:
	var p := player
	if p.dodge.is_empty():
		return 0.0
	return clampf(gap_to(p, p.dodge.trap.distance) / p.dodge.gap0, 0.0, 1.0)


## Lettre de « évite » tapée par l'enfant (accents toujours facultatifs).
func _dodge_char(c: String) -> void:
	var p := player
	var w := Gifts.DODGE_WORD
	var expected := w[p.dodge.typed]
	var letter := normalize_char(expected, false)
	var ls: Array = stats.letters.get(letter, LetterStats.empty())
	stats.letters[letter] = ls
	if normalize_char(c, true) == normalize_char(expected, true):
		ls[LetterStats.OK] += 1
		stats.correct += 1
		p.dodge.typed += 1
		dodge_key_ok.emit(p.dodge.typed)
		if p.dodge.typed >= w.length():
			p.dodge.done = true
			dodge_ended.emit("ok")
	else:
		stats.errors += 1
		ls[LetterStats.ERRORS] += 1
		key_error.emit(expected)
