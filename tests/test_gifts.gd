extends SceneTree
## Tests des cases cadeau (règles de RaceLogic et Gifts, sans affichage) :
## tirage, un seul cadeau à la fois, choix de la case, effets des cinq
## cadeaux, tempête et fusée jamais données au premier, huile et clou posés
## derrière et évités avec « évite », adversaires qui ramassent et visent l'enfant.
##
## godot --headless --path . --script res://tests/test_gifts.gd

var failures := 0
var completed := false
var frame := 0


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 1:
		_run()
		if not completed:
			failures += 1
			push_error("ÉCHEC : les tests ne sont pas allés jusqu'au bout (erreur ci-dessus)")
		print("ÉCHECS : %d" % failures if failures else "OK")
		quit(1 if failures else 0)
	return false


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		push_error("ÉCHEC " + what)


## Course de test : circuit de 600 m (30 m/s en croisière), sans mots à taper
## (pour maîtriser les vitesses). bots : frappes par minute des adversaires.
func make_logic(bots: Array, extra := {}) -> RaceLogic:
	var s := Profile.DEFAULT_SETTINGS.duplicate(true)
	s.merge(extra, true)
	var infos := []
	for i in bots.size():
		infos.append({"name": "Bot%d" % i, "character": "tortue", "kpm": bots[i]})
	var l := RaceLogic.new(s, PackedStringArray(["chat"]), 600.0, {"name": "Test", "character": "chat", "kpm": 30.0}, infos)
	l.state = "running"
	for r in l.racers:
		r.next_word_in = 9999.0
	return l


func bot(l: RaceLogic, i := 0):
	return l.racers[i]


## Avance la course par petits pas.
func run(l: RaceLogic, seconds: float, step := 0.05) -> void:
	var t := 0.0
	while t < seconds:
		l.update(step)
		t += step


func _run() -> void:
	seed(20261120)

	print("Tirage des cadeaux")
	var leader_ok := true
	for i in 200:
		var k := Gifts.pick(true, randf(), randf())
		if k == Gifts.STORM or k == Gifts.ROCKET:
			leader_ok = false
	check(leader_ok, "premier : jamais de tempête ni de fusée")
	check(Gifts.pick(false, 0.49, 0.0) == Gifts.CHARGE and Gifts.pick(false, 0.5, 0.0) != Gifts.CHARGE, "charge électrique : une chance sur deux")
	var seen := {}
	for x in [0.0, 0.26, 0.51, 0.76, 0.99]:
		seen[Gifts.pick(false, 0.9, x)] = true
	check(seen.size() == 4 and not seen.has(Gifts.CHARGE), "les autres cadeaux se partagent l'autre moitié")
	check(Gifts.dodge_window(20.0) > Gifts.dodge_window(40.0) and Gifts.dodge_window(40.0) > Gifts.dodge_window(80.0),
		"temps pour taper « évite » : plus long pour un enfant qui tape lentement")
	check(Gifts.dodge_window(1000.0) == Gifts.DODGE_MIN and Gifts.dodge_window(1.0) == Gifts.DODGE_MAX, "temps d'esquive borné")
	print("  temps pour « évite » : %.1f s à 20 frappes/min, %.1f s à 40, %.1f s à 80" % [Gifts.dodge_window(20.0), Gifts.dodge_window(40.0), Gifts.dodge_window(80.0)])

	print("Cases cadeau")
	var l := make_logic([20.0])
	var p := l.player
	check(l.rows.size() == Gifts.ROWS.size() and l.boxes[0].size() == Gifts.BOX_LATERALS.size(), "rangées de cases sur la largeur de la piste")
	var taken := []
	var received := []
	l.gift_box_taken.connect(func(row, box, r): taken.append([row, box, r]))
	l.gift_received.connect(func(r, kind): received.append([r, kind]))
	p.distance = l.rows[0] - 100.0
	l.update(0.01)
	check(p.box_row == -1 and not l.choose_box(1), "loin des cases : pilote automatique, les flèches ne font rien")
	p.distance = l.rows[0] - 60.0 # arrivée dans 2 s
	p.lateral = 0.0
	l.update(0.01)
	check(p.box_row == 0 and p.box_choice >= 0, "à l'approche, une case est visée")
	while l.choose_box(-1):
		pass
	check(p.box_choice == 0 and not l.choose_box(-1), "flèche gauche jusqu'à la case de gauche")
	check(l.choose_box(1) and p.box_choice == 1, "flèche droite : case suivante")
	p.lateral = Gifts.BOX_LATERALS[p.box_choice]
	run(l, 2.5)
	check(taken.size() == 1 and taken[0][1] == 1 and taken[0][2] == p, "le kart passe sur la case choisie")
	check(received.size() == 1 and received[0][0] == p and p.gift == received[0][1] and Gifts.KINDS.has(p.gift), "cadeau obtenu (%s)" % p.gift)
	check(not l.box_ready(0, 1), "case prise : elle disparaît")
	run(l, Gifts.BOX_RESPAWN + 0.1)
	check(l.box_ready(0, 1), "puis réapparaît")
	var first_gift := p.gift
	var kept := [0]
	l.gift_kept.connect(func(_r): kept[0] += 1)
	p.distance = l.rows[1] - 10.0
	run(l, 1.0)
	check(p.gift == first_gift and kept[0] == 1 and received.size() == 1, "un seul cadeau à la fois")

	print("Tirage dans la course")
	var lr := make_logic([20.0])
	var pr := lr.player
	var b0 = bot(lr)
	var counts := {}
	for i in 2000:
		pr.gift = ""
		pr.distance = 200.0
		b0.distance = 100.0 if i < 1000 else 300.0 # premier, puis deuxième
		lr.boxes[0][0] = 0.0
		pr.lateral = Gifts.BOX_LATERALS[0]
		lr._take_box(pr, 0)
		var key := ("1er " if i < 1000 else "2e ") + pr.gift
		counts[key] = counts.get(key, 0) + 1
	print("  ", counts)
	check(not counts.has("1er " + Gifts.STORM) and not counts.has("1er " + Gifts.ROCKET), "tempête et fusée jamais données au premier")
	check(counts.has("2e " + Gifts.STORM) and counts.has("2e " + Gifts.ROCKET), "tempête et fusée pour les suivants")
	var charges: int = counts.get("1er " + Gifts.CHARGE, 0) + counts.get("2e " + Gifts.CHARGE, 0)
	check(charges > 900 and charges < 1100, "charge électrique environ une fois sur deux (%d sur 2000)" % charges)

	print("Charge électrique")
	l = make_logic([])
	p = l.player
	p.gift = Gifts.CHARGE
	check(l.use_gift(p) and p.gift == "" and p.boost == float(Profile.DEFAULT_SETTINGS.boost_duration), "turbo identique à celui d'un mot tapé")
	run(l, 0.6)
	check(p.mult > 1.3, "le kart accélère")
	check(not l.use_gift(p), "plus de cadeau après usage")

	print("Huile")
	l = make_logic([1.0])
	p = l.player
	var b = bot(l)
	var hits := []
	l.gift_hit.connect(func(v, kind, by): hits.append([v, kind, by]))
	p.distance = 300.0
	p.lateral = 1.0
	b.distance = 270.0
	p.gift = Gifts.OIL
	check(l.use_gift(p) and l.traps.size() == 1, "huile posée")
	var oil = l.traps[0]
	check(oil.distance < p.distance and oil.lateral == 1.0 and l.next_victim(oil) == b, "derrière le kart, sur le chemin du kart suivant")
	run(l, 1.5)
	check(hits.size() == 1 and hits[0][0] == b and hits[0][2] == p and b.slip > 0.0 and l.traps.is_empty(), "le kart suivant glisse")
	check(b.mult < 0.8 and p.slip == 0.0, "il perd un peu de temps, pas celui qui l'a posée")
	run(l, Gifts.SLIP_TIME + 1.0)
	check(b.slip == 0.0 and b.mult > 0.8, "la glissade est courte")

	print("Clou évité avec « évite »")
	for variant in [["évite", true], ["evite", true], ["evite", false]]:
		l = make_logic([20.0], {"accents_tolerant": variant[1]})
		p = l.player
		b = bot(l)
		var events := []
		l.dodge_started.connect(func(_t): events.append("start"))
		l.dodge_ended.connect(func(res): events.append(res))
		l.trap_dodged.connect(func(r, _t): events.append("dodged" if r == p else "?"))
		b.distance = 300.0
		p.distance = 250.0
		b.gift = Gifts.NAIL
		l.use_gift(b)
		l.update(0.02)
		check(events == ["start"] and l.is_dodging(p), "« évite » apparaît à l'approche du clou")
		for ch in variant[0]:
			l.handle_char(ch)
		check(events == ["start", "ok"] and not l.is_dodging(p), "« %s » tapé (accents facultatifs : %s)" % [variant[0], variant[1]])
		run(l, 3.0)
		check(events.has("dodged") and p.flat == 0.0, "le clou est évité")
	check(l.stats.correct == 5 and l.stats.letters.has("é"), "frappes de « évite » comptées")

	print("Clou touché")
	l = make_logic([20.0])
	p = l.player
	b = bot(l)
	var ends := []
	l.dodge_ended.connect(func(res): ends.append(res))
	b.distance = 300.0
	p.distance = 250.0
	b.gift = Gifts.NAIL
	l.use_gift(b)
	l.update(0.02)
	l.handle_char("x")
	check(l.stats.errors == 1 and p.dodge.typed == 0, "mauvaise lettre : « évite » n'avance pas")
	run(l, 2.5)
	check(ends == ["hit"] and p.flat > 0.0, "pas tapé à temps : pneu crevé")
	check(p.mult < 0.5, "le kart ralentit fortement (%.2f)" % p.mult)
	run(l, Gifts.FLAT_TIME + 1.5)
	check(p.flat == 0.0 and p.mult > 0.8, "puis repart")

	print("Temps laissé pour « évite »")
	l = make_logic([20.0])
	p = l.player
	b = bot(l)
	b.distance = 500.0
	p.distance = 0.0 # à plus de 16 s du piège
	b.gift = Gifts.OIL
	l.use_gift(b)
	var window := l.dodge_window(p)
	var t_start := -1.0
	var t := 0.0
	while t < 20.0 and l.traps.size() == 1:
		l.update(0.05)
		t += 0.05
		if t_start < 0.0 and l.is_dodging(p):
			t_start = t
	var given := t - t_start
	check(t_start > 0.0 and absf(given - window) < 0.3, "« évite » laisse le temps prévu pour son niveau (%.1f s pour %.1f s prévues)" % [given, window])

	print("Tempête")
	l = make_logic([20.0])
	p = l.player
	b = bot(l)
	var blocked := []
	l.gift_blocked.connect(func(kind): blocked.append(kind))
	p.distance = 350.0
	b.distance = 300.0
	p.gift = Gifts.STORM
	check(not l.use_gift(p) and p.gift == Gifts.STORM and blocked == [Gifts.STORM], "premier : la tempête est gardée pour plus tard")
	p.distance = 250.0
	check(l.use_gift(p) and b.storm > 0.0 and p.storm == 0.0, "deuxième : la tempête touche seulement le premier")
	run(l, 0.6)
	check(b.mult < 0.8, "le premier est ralenti")
	l = make_logic([20.0, 20.0])
	p = l.player
	b = bot(l, 0)
	var b2 = bot(l, 1)
	p.distance = 350.0
	b.distance = 300.0
	b2.distance = 250.0
	b2.gift = Gifts.STORM
	b2.gift_wait = 0.0
	p.word = "chat"
	p.typed = 0
	l.update(0.05)
	check(p.storm > 0.0 and b.storm == 0.0 and b2.storm == 0.0, "un adversaire envoie la tempête sur l'enfant quand il est premier")
	check(p.blur > 0.0, "le mot à taper devient flou")
	run(l, Gifts.STORM_BLUR_TIME + 0.2)
	check(p.blur == 0.0, "puis redevient net")

	print("Fusée")
	l = make_logic([20.0])
	p = l.player
	b = bot(l)
	p.distance = 250.0
	b.distance = 330.0
	check(l.position_of(p) == 2, "l'enfant est deuxième")
	p.gift = Gifts.ROCKET
	check(l.use_gift(p) and p.rocket > 0.0, "fusée lancée")
	run(l, Gifts.ROCKET_TIME + 0.1)
	check(l.position_of(p) == 1 and p.distance > b.distance, "une place rattrapée")
	p.gift = Gifts.ROCKET
	check(not l.use_gift(p) and p.gift == Gifts.ROCKET, "premier : personne à rattraper, la fusée est gardée")

	print("Adversaires")
	l = make_logic([20.0, 20.0])
	p = l.player
	b = bot(l, 0)
	b2 = bot(l, 1)
	b.distance = l.rows[0] - 15.0
	b.lateral = Gifts.BOX_LATERALS[0]
	b2.distance = 0.0
	p.distance = 10.0
	run(l, 1.0)
	check(b.gift != "", "un adversaire ramasse un cadeau (%s)" % b.gift)
	l = make_logic([20.0, 20.0])
	p = l.player
	b = bot(l, 0)
	b2 = bot(l, 1)
	b.distance = 300.0
	b.gift = Gifts.NAIL
	b.gift_wait = 0.1
	p.distance = 250.0
	b2.distance = 100.0
	run(l, 0.3)
	check(l.traps.size() == 1 and l.next_victim(l.traps[0]) == p, "un adversaire pose un clou devant l'enfant qui le suit")
	var used := {}
	var by_bots := {}
	l = make_logic([30.0, 30.0, 30.0])
	l.gift_used.connect(func(r, kind, _target): used[kind] = used.get(kind, 0) + 1; if not r.is_player: by_bots[r.name] = true)
	for r in l.racers:
		r.next_word_in = 1.0
	run(l, 90.0, 0.1)
	print("  cadeaux utilisés : ", used)
	check(by_bots.size() >= 2, "les adversaires utilisent leurs cadeaux (%d adversaires)" % by_bots.size())

	print("Pièges et cases désactivés")
	l = make_logic([20.0], {"gifts": false})
	p = l.player
	p.distance = 150.0
	run(l, 2.0)
	check(l.rows.is_empty() and p.gift == "", "réglage « Cases cadeau » décoché : pas de cases")
	l = make_logic([20.0])
	p = l.player
	p.distance = 300.0
	bot(l).distance = 0.0
	p.gift = Gifts.OIL
	l.use_gift(p)
	bot(l).next_word_in = 0.0
	bot(l).distance = -9000.0 # personne ne passe
	run(l, Gifts.TRAP_LIFETIME + 0.5, 0.25)
	check(l.traps.is_empty(), "un piège où personne ne passe finit par disparaître")
	completed = true
