class_name RaceLogic
extends RefCounted
## Règles de la course, indépendantes de l'affichage.
##
## Chaque pilote roule en pilote automatique à une vitesse de croisière.
## Régulièrement, un mot apparaît : tant qu'il n'est pas entièrement tapé, le
## kart ralentit ; une fois tapé, le kart reçoit un turbo temporaire.
## Les adversaires suivent exactement les mêmes règles : ils « tapent » leurs
## mots à une vitesse (en frappes par minute) réglée par l'adulte.

signal countdown_tick(n: int)
signal race_started
signal word_started(word: String)
signal key_ok(typed: int)
signal key_error(expected: String)
signal word_completed(word: String)
signal player_finished

const ACCENTS := {
	"à": "a", "â": "a", "ä": "a", "á": "a",
	"é": "e", "è": "e", "ê": "e", "ë": "e",
	"î": "i", "ï": "i", "í": "i",
	"ô": "o", "ö": "o", "ó": "o",
	"ù": "u", "û": "u", "ü": "u", "ú": "u",
	"ç": "c", "ÿ": "y", "ñ": "n",
}

const GRID_ROW_SPACING := 5.0


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
	var next_word_in := 1.5
	var boost := 0.0
	var finished := false
	var finish_time := -1.0
	var predicted_finish := INF

	func copy():
		var r = Racer.new()
		for p in ["name", "character", "is_player", "kpm", "slot", "distance", "mult", "word",
				"typed", "word_elapsed", "word_duration", "word_errors", "next_word_in", "boost",
				"finished", "finish_time"]:
			r.set(p, get(p))
		return r


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
var stats := {"correct": 0, "errors": 0, "active_time": 0.0, "words": []}
var _recent: Array[String] = []


func _init(p_settings: Dictionary, word_list: PackedStringArray, p_track_length: float,
		player_info: Dictionary, bot_infos: Array) -> void:
	settings = p_settings
	var max_len := int(settings.max_word_length)
	for w in word_list:
		if w.length() <= max_len:
			words.append(w)
	if words.is_empty():
		words = word_list if not word_list.is_empty() else PackedStringArray(["kart"])
	laps = int(settings.laps)
	track_length = p_track_length
	race_length = laps * track_length
	base_speed = track_length / float(settings.lap_time)

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
	for r in racers:
		if not r.finished:
			_update_racer(r, delta, time, true)


func _update_racer(r, dt: float, now: float, live: bool) -> void:
	if r.word == "":
		r.next_word_in -= dt
		if r.next_word_in <= 0.0:
			_spawn_word(r, live)
	else:
		r.word_elapsed += dt
		if r.is_player and live:
			stats.active_time += dt
		if not r.is_player and r.word_elapsed >= r.word_duration:
			_complete_word(r, live)
	if r.boost > 0.0:
		r.boost = maxf(0.0, r.boost - dt)

	var target := 1.0
	if r.word != "":
		target = float(settings.slow_factor)
	elif r.boost > 0.0:
		target = float(settings.boost_factor)
	var rate := 4.0 if target > r.mult else 3.0
	r.mult += (target - r.mult) * minf(1.0, rate * dt)
	r.distance += base_speed * r.mult * dt

	if r.distance >= race_length:
		r.distance = race_length
		r.finished = true
		r.finish_time = now
		r.word = ""
		if live:
			finished_count += 1
			if r.is_player:
				_on_player_finish()


func _spawn_word(r, live: bool) -> void:
	r.word = _pick_word(r.is_player)
	r.typed = 0
	r.word_elapsed = 0.0
	r.word_errors = 0
	if not r.is_player:
		# Temps de frappe simulé avec un peu de variabilité (±20 %).
		r.word_duration = r.word.length() * 60.0 / maxf(1.0, r.kpm) * randf_range(0.8, 1.2)
	elif live:
		word_started.emit(r.word)


func _complete_word(r, live: bool) -> void:
	var w: String = r.word
	if r.is_player and live:
		stats.words.append({"word": w, "time": r.word_elapsed, "errors": r.word_errors})
	r.word = ""
	r.boost = float(settings.boost_duration)
	r.next_word_in = float(settings.word_gap) + (0.0 if r.is_player else randf_range(-0.3, 0.3))
	if r.is_player and live:
		word_completed.emit(w)


static func normalize_char(c: String, accents_tolerant: bool) -> String:
	var s := c.to_lower()
	if accents_tolerant:
		s = ACCENTS.get(s, s)
	return s


## Lettre tapée par l'enfant.
func handle_char(c: String) -> void:
	var p := player
	if state != "running" or p.finished or p.word == "":
		return
	var expected := p.word[p.typed]
	var tol := bool(settings.accents_tolerant)
	if normalize_char(c, tol) == normalize_char(expected, tol):
		p.typed += 1
		stats.correct += 1
		key_ok.emit(p.typed)
		if p.typed >= p.word.length():
			_complete_word(p, true)
	else:
		stats.errors += 1
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
