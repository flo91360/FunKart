extends SceneTree
## Tests des données : reprise des anciennes données, profils, historique,
## contenu du jeu (personnages, circuit).
##
## godot --headless --path . --script res://tests/test_profiles.gd

const DATA_DIR := "user://test_profiles"

var failures := 0
var completed := false
var frame := 0


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 1:
		_run()
		# Une erreur d'exécution interrompt _run sans compter d'échec : on le détecte.
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


## Points du circuit tous les 5 m.
func track_points(tr: Track) -> Array:
	var pts := []
	var d := 0.0
	while d < tr.length:
		pts.append(tr.curve.sample_baked(d))
		d += 5.0
	return pts


## Plus petite distance (vue de dessus) entre deux portions de route éloignées
## de plus de 60 m le long du circuit : la route ne doit pas se toucher.
func track_separation(tr: Track) -> float:
	var pts := track_points(tr)
	var n := pts.size()
	var best := INF
	for i in n:
		for j in range(i + 1, n):
			if mini(j - i, n - (j - i)) * 5.0 > 60.0:
				var a: Vector3 = pts[i]
				var b: Vector3 = pts[j]
				best = minf(best, Vector2(a.x - b.x, a.z - b.z).length())
	return best


## Hauteur la plus basse de la surface de la route (le sol est à y = 0).
func lowest_road(tr: Track) -> float:
	var lowest := INF
	var d := 0.0
	while d < tr.length:
		lowest = minf(lowest, tr.frame_at(d).origin.y)
		d += 1.0
	return lowest


## Distance du centre de la tribune aux portions de route qui ne la longent pas.
func stand_clearance(tr: Track) -> float:
	var pts := track_points(tr)
	var center: Vector3 = tr._grandstand_center()
	var i0 := int(tr.grandstand_distance / 5.0)
	var n := pts.size()
	var best := INF
	for i in n:
		if mini(absi(i - i0), n - absi(i - i0)) * 5.0 > 50.0:
			var pt: Vector3 = pts[i]
			best = minf(best, Vector2(pt.x - center.x, pt.z - center.z).length())
	return best


func _run() -> void:
	var app = root.get_node("AppSettings")
	var profiles = root.get_node("Profiles")

	print("Reprise des données de l'ancienne version")
	TestUtil.remove_dir(DATA_DIR)
	DirAccess.make_dir_recursive_absolute(DATA_DIR)
	app.write_json(DATA_DIR.path_join("settings.json"), {
		"player_name": "Lou", "character": "panda", "laps": 2, "bot_count": 2,
		"bot_kpm": [11, 12, 13, 14, 15], "words": "pomme\nkart 🏎️\n\n", "fullscreen": false,
		"sound": false, "music": true, "uppercase": true,
	})
	app.write_json(DATA_DIR.path_join("history.json"), [{"date": "2026-10-01", "kpm": 20.0}, {"date": "2026-10-02", "kpm": 25.0}])
	app.data_dir = DATA_DIR
	app.reload()
	profiles.reload()
	check(profiles.profiles.size() == 1, "un seul profil créé")
	var lou: Profile = profiles.current
	check(lou.name == "Lou", "prénom repris")
	check(lou.character_id == "panda", "pilote repris")
	check(int(lou.get_setting("laps")) == 2 and int(lou.get_setting("bot_count")) == 2, "réglages repris")
	check(bool(lou.get_setting("uppercase")), "option majuscules reprise")
	check(Array(lou.words()) == ["pomme", "kart"], "liste de mots reprise")
	check(profiles.history(lou).size() == 2, "historique repris")
	check(not FileAccess.file_exists(DATA_DIR.path_join("settings.json")) and FileAccess.file_exists(DATA_DIR.path_join("settings.old.json")), "ancien fichier renommé, pas supprimé")
	check(bool(app.get_value("fullscreen")), "plein écran activé (ancienne version)")
	check(not bool(app.get_value("sound")), "réglage du son repris")

	print("Création, sélection, rechargement")
	var max_p: Profile = profiles.create("Max")
	check(profiles.profiles.size() == 2 and profiles.current == max_p, "nouveau profil sélectionné")
	check(max_p.words().size() == GameContent.get_content().default_word_list().words.size(), "liste de mots par défaut")
	max_p.settings["laps"] = 5
	profiles.save_profile(max_p)
	profiles.add_history({"date": "2026-10-03", "kpm": 30.0}, max_p)
	app.reload()
	profiles.reload()
	check(profiles.profiles.size() == 2, "profils rechargés")
	check(profiles.current.name == "Max", "dernier profil utilisé retrouvé")
	check(int(profiles.current.get_setting("laps")) == 5, "réglage du profil enregistré")
	check(profiles.history(profiles.current).size() == 1, "historique séparé par profil")

	print("Export CSV")
	var csv_path: String = profiles.export_csv(ProjectSettings.globalize_path(DATA_DIR))
	var csv := FileAccess.get_file_as_string(csv_path)
	check(csv.count("\n") == 4, "en-tête + 3 courses")
	check(csv.contains("\"Lou\"") and csv.contains("\"Max\""), "les deux profils exportés")

	print("Suppression")
	profiles.delete(profiles.find(lou.id))
	check(profiles.profiles.size() == 1 and profiles.current.name == "Max", "profil supprimé")
	check(not DirAccess.dir_exists_absolute(DATA_DIR.path_join("profiles").path_join(lou.id)), "dossier du profil supprimé")
	profiles.delete(profiles.current)
	check(profiles.profiles.size() == 1, "le dernier profil ne peut pas être supprimé")

	print("Fichiers de profil")
	var d := {"id": "x", "name": "Zoé", "settings": {"laps": 4, "inconnu": 1}, "futur": true}
	var p := Profile.from_dict(d)
	check(p.name == "Zoé" and int(p.get_setting("laps")) == 4, "lecture d'un profil")
	check(not p.settings.has("inconnu") and float(p.get_setting("word_gap")) == 2.5, "réglages inconnus ignorés, manquants par défaut")
	check(Profile.from_dict(p.to_dict()).to_dict() == p.to_dict(), "aller-retour JSON")

	print("Listes de mots")
	check(Array(WordList.parse("chat, chien;  lapin\npomme 🍎 12 l’eau -tiret- Chat chat")) == ["chat", "chien", "lapin", "pomme", "l'eau", "tiret", "Chat"],
		"découpage d'un texte en mots (séparateurs, emojis, chiffres, doublons)")
	var content0 := GameContent.get_content()
	var ids := []
	for wl in content0.word_lists:
		ids.append(wl.id)
	check(ids.size() == 8 and ids[0] == "base" and ids.has("lettres") and ids.has("syllabes"), "8 listes livrées avec le jeu")
	var base_words: PackedStringArray = content0.default_word_list().words
	var v1 := Profile.from_dict({"version": 1, "id": "a", "name": "A", "active_word_list": 0,
		"word_lists": [{"title": "Mots de base", "words": Array(base_words)}]})
	check(v1.active_lists == ["base"] and v1.word_lists.is_empty(), "ancien profil : copie de la liste de base -> liste du jeu")
	var v1b := Profile.from_dict({"version": 1, "id": "b", "name": "B", "active_word_list": 1,
		"word_lists": [{"title": "Mots de base", "words": Array(base_words)}, {"title": "Perso", "words": ["zut", "flute"]}]})
	check(v1b.word_lists.size() == 1 and v1b.active_lists.size() == 1 and Array(v1b.words()) == ["zut", "flute"], "ancien profil : liste personnelle reprise et choisie")
	var lp := Profile.create("Lisa")
	check(lp.words() == base_words, "nouveau profil : liste de base")
	lp.set_active("animaux", true)
	lp.set_active("fruits", true)
	var expected := []
	for w in Array(base_words) + Array(content0.word_list("animaux").words) + Array(content0.word_list("fruits").words):
		if not expected.has(w):
			expected.append(w)
	check(Array(lp.words()) == expected, "plusieurs listes : mots réunis sans doublon (%d mots)" % expected.size())
	var mine := lp.add_list("Ma liste", PackedStringArray(["vroum", "tut"]))
	lp.set_active("base", false)
	lp.set_active("animaux", false)
	lp.set_active("fruits", false)
	lp.set_active(mine.id, true)
	check(Array(lp.words()) == ["vroum", "tut"], "liste personnelle seule")
	lp.update_list(mine.id, "Bruits", PackedStringArray(["bip"]))
	check(Array(lp.active_titles()) == ["Bruits"] and Array(lp.words()) == ["bip"], "liste personnelle modifiée")
	var round_trip := Profile.from_dict(lp.to_dict())
	check(round_trip.active_lists == lp.active_lists and round_trip.word_lists == lp.word_lists, "listes enregistrées (aller-retour JSON)")
	lp.remove_list(mine.id)
	check(lp.active_lists == ["base"] and lp.word_lists.is_empty(), "liste supprimée : retour à la liste de base")

	check(Array(WordList.parse("cœur Œuf ex æquo")) == ["coeur", "Oeuf", "ex", "aequo"], "œ et æ remplacés par des lettres du clavier")
	var bad_settings := Profile.from_dict({"id": "y", "name": "Y", "settings": {"bot_kpm": "vite", "laps": "deux", "word_gap": 3}})
	check(bad_settings.get_setting("bot_kpm") is Array and int(bad_settings.get_setting("laps")) == 3 and float(bad_settings.get_setting("word_gap")) == 3.0,
		"réglages du mauvais type ignorés")

	print("Règles de la course")
	check(RaceLogic.normalize_char("É", true) == "e" and RaceLogic.normalize_char("É", false) == "é", "accents facultatifs")
	var logic := RaceLogic.new(Profile.DEFAULT_SETTINGS.duplicate(true), PackedStringArray(["cœur"]), 600.0,
		{"name": "Test", "character": "chat"}, [])
	check(Array(logic.words) == ["coeur"], "mot avec œ : se tape « coeur »")
	logic.state = "running"
	logic.update(2.0)
	check(logic.player.word == "coeur", "un mot apparaît")
	for ch in "coeur":
		logic.handle_char(ch)
	check(logic.player.word == "" and logic.player.boost > 0.0 and logic.stats.words.size() == 1, "mot tapé : turbo")
	logic.player.next_word_in = 0.0
	for i in 10:
		logic.update(0.1)
	check(logic.player.word != "" and logic.player.mult > 1.2, "le turbo continue quand le mot suivant est déjà affiché")
	for i in 200:
		logic.update(0.1)
	check(logic.stats.skipped == 1 and logic.stats.words.size() == 1, "mot passé après %d s sans bonne lettre" % int(RaceLogic.SKIP_AFTER))

	print("Statistiques par lettre")
	var lg := RaceLogic.new(Profile.DEFAULT_SETTINGS.duplicate(true), PackedStringArray(["bob"]), 600.0,
		{"name": "Test", "character": "chat"}, [])
	lg.state = "running"
	lg.update(2.0)
	lg.handle_char("b")
	lg.update(0.5)
	lg.handle_char("x")
	lg.handle_char("o")
	lg.update(0.3)
	lg.handle_char("b")
	var lb: Array = lg.stats.letters.get("b", [])
	var lo: Array = lg.stats.letters.get("o", [])
	check(lb.size() == 4 and lb[0] == 2 and lb[1] == 0 and lb[3] == 1 and absf(lb[2] - 0.3) < 0.01, "lettre b : 2 bonnes frappes, temps sans la première lettre")
	check(lo.size() == 4 and lo[0] == 1 and lo[1] == 1 and absf(lo[2] - 0.5) < 0.01, "lettre o : l'erreur est comptée sur la lettre attendue")
	var total := {"b": [10, 0, 5.0, 10], "n": [6, 4, 6.0, 6], "e": [10, 0, 20.0, 10], "z": [1, 1, 0.0, 0]}
	var hard := LetterStats.difficult(total)
	check(Array(LetterStats.letters_of(hard)) == ["n", "e"], "lettres à travailler : erreurs puis lenteur, lettres trop rares ignorées")
	check(LetterStats.describe(hard) == "n (40 % d'erreurs), e (lente : 2,0 s)", "description des lettres à travailler")
	var hist := [{"letters": {"n": [1, 1, 0.5, 1]}}, {"letters": {"n": [1, 0, 0.5, 1]}}, {"kpm": 3.0}]
	var agg := LetterStats.from_history(hist)
	check(agg.has("n") and int(agg.n[0]) == 2 and int(agg.n[1]) == 1 and LetterStats.from_history(hist, 1).is_empty(),
		"total des dernières courses (anciennes courses sans lettres acceptées)")
	check(Array(LetterStats.practice_words(PackedStringArray(["banane", "nez", "chat", "Nana", "nana"]), PackedStringArray(["n"])))
		== ["Nana", "banane", "nez", "n"], "liste d'entraînement : mots avec le plus de lettres à travailler")

	print("Adversaires automatiques")
	var runs := [{"kpm": 99.0, "words": 1}, {"kpm": 10.0, "words": 5}, {"kpm": 30.0, "words": 5}, {"kpm": 20.0, "words": 5},
		{"kpm": 40.0, "words": 5}, {"kpm": 20.0, "words": 5}, {"kpm": 25.0, "words": 5}]
	check(AutoLevel.reference_kpm(runs) == 25.0, "niveau : médiane des 5 dernières courses (course trop courte ignorée)")
	check(AutoLevel.reference_kpm([]) == -1.0 and AutoLevel.reference_kpm([{"kpm": 30.0, "words": 1}]) == -1.0, "pas de niveau sans course utilisable")
	check(AutoLevel.reference_kpm([{"kpm": 20.0, "words": 5}, {"kpm": 30.0, "words": 5}]) == 25.0, "médiane d'un nombre pair de courses")
	check(AutoLevel.bot_kpm([{"kpm": 20.0, "words": 5}], 3, [11, 12, 13]) == [17.0, 20.0, 23.0], "adversaires autour du niveau de l'enfant")
	check(AutoLevel.bot_kpm([], 2, [11, 12, 13]) == [11.0, 12.0], "sans historique : valeurs réglées à la main")
	check(AutoLevel.bot_kpm([{"kpm": 2.0, "words": 5}], 1, []) == [AutoLevel.MIN_KPM], "vitesse minimale")
	check(not bool(Profile.new().get_setting("bot_auto")), "adversaires automatiques désactivés par défaut")

	print("Progression et records")
	var courses := [{"kpm": 15.0, "words": 5}, {"kpm": 40.0, "words": 1}, {"kpm": 12.0, "words": 5},
		{"kpm": 18.0, "words": 6, "accuracy": 0.9}, {"kpm": 18.0, "words": 6}, {"kpm": 22.0, "words": 6}]
	check(Progress.best_kpm(courses) == 22.0 and Progress.best_kpm([]) == -1.0, "record : course trop courte ignorée")
	var pts := Progress.series(courses)
	check(pts.size() == 5 and pts.map(func(pt): return pt.record) == [false, false, true, false, true],
		"courbe : records quand une course bat toutes les précédentes (pas la première, pas une égalité)")
	check(Progress.series(courses, 2).size() == 2 and float(pts[2].accuracy) == 0.9, "courbe : dernières courses et précision")
	check(Progress.is_record(20.0, 25.0, 5) and not Progress.is_record(-1.0, 25.0, 5) and not Progress.is_record(20.0, 25.0, 1),
		"nouveau record : il faut une course d'avant et assez de mots")

	print("Réglages réservés aux adultes")
	var gate_rng := RandomNumberGenerator.new()
	gate_rng.seed = 42
	var in_range := true
	for i in 50:
		var q: Array = ParentGate.make_question(gate_rng)
		if q[0] < ParentGate.MIN_FACTOR or q[0] > ParentGate.MAX_FACTOR or q[1] < ParentGate.MIN_FACTOR or q[1] > ParentGate.MAX_FACTOR:
			in_range = false
	check(in_range, "calcul : deux nombres de 6 à 9")
	check(ParentGate.is_correct("56", 7, 8) and ParentGate.is_correct(" 56 ", 7, 8), "bonne réponse acceptée")
	check(not ParentGate.is_correct("54", 7, 8) and not ParentGate.is_correct("", 7, 8) and not ParentGate.is_correct("5a", 7, 8),
		"mauvaise réponse refusée")
	check(bool(app.DEFAULTS.parent_lock), "réglages protégés par défaut")

	print("Leçons du clavier")
	var lessons := KeyboardLessons.lists()
	check(lessons.size() == 4 and lessons[0].id == "lecon_1" and lessons[3].id == "lecon_4", "4 leçons, rangée par rangée")
	var lesson_ok := true
	for i in lessons.size():
		var spec: Dictionary = KeyboardLessons.LESSONS[i]
		if lessons[i].words.size() < 15:
			lesson_ok = false
		for w in lessons[i].words:
			if not KeyboardLessons.uses_only(w, spec.letters) or not KeyboardLessons.uses_any(w, spec.new):
				lesson_ok = false
	check(lesson_ok, "chaque leçon : au moins 15 mots, seulement les rangées vues, au moins une touche de la nouvelle rangée")
	check(KeyboardLessons.uses_only("fjdk", KeyboardLessons.ROW_HOME) and not KeyboardLessons.uses_only("fja", KeyboardLessons.ROW_HOME),
		"leçon 1 : rangée du milieu seulement")
	var lp2 := Profile.create("Leçons")
	check(lp2.find_list("lecon_3").get("builtin", false) and lp2.find_list("lecon_3").words.has("banane"), "leçons proposées avec les listes du jeu")
	lp2.set_active("base", false)
	lp2.set_active("lecon_1", true)
	check(lp2.words() == lessons[0].words, "leçon cochée : ses mots en course")

	print("Circuits et musiques")
	var tracks_content := GameContent.get_content()
	check(tracks_content.tracks.size() == 4, "4 circuits")
	var circuits_ok := true
	for i in tracks_content.tracks.size():
		var tr: Track = tracks_content.tracks[i].instantiate()
		root.add_child(tr)
		var th: TrackTheme = tr.track_theme
		var sep := track_separation(tr)
		var stand := stand_clearance(tr)
		var lowest := lowest_road(tr)
		print("  %s : %.0f m, portions éloignées à %.0f m au moins, tribune à %.0f m, route au plus bas à %.2f m du sol, musique « %s »" % [tr.title, tr.length, sep, stand, lowest, th.music])
		if tr.length < 450.0 or tr.length > 900.0 or sep < 2.0 * (tr.road_half_width + Track.CURB) + 5.0 or stand < 30.0:
			circuits_ok = false
		if lowest < 0.05:
			circuits_ok = false
		if not MusicSynth.SONGS.has(th.music) or tracks_content.track_title(i) != tr.title or tracks_content.track_theme(i) != th:
			circuits_ok = false
		tr.free()
	check(circuits_ok, "circuits : longueur, route qui ne se touche pas ni ne passe sous le sol, tribune dégagée, titre et musique")
	var songs_ok := true
	for song_name in MusicSynth.SONGS:
		var song: Dictionary = MusicSynth.SONGS[song_name]
		for part in song.sections:
			var sec: Dictionary = song.sections[part]
			if sec.melody.size() != 32 or sec.chords.size() != 4:
				songs_ok = false
			for chord in sec.chords:
				if MusicSynth.chord_tones(chord).size() != 3:
					songs_ok = false
		for item in song.form:
			if not song.sections.has(String(item).trim_suffix("+")):
				songs_ok = false
		var samples := MusicSynth.new(song_name).render(int(MusicSynth.RATE))
		var sum := 0.0
		for sv in samples:
			if not is_finite(sv) or absf(sv) > 1.0:
				songs_ok = false
			sum += sv * sv
		var rms := sqrt(sum / samples.size())
		print("  musique « %s » : %.0f s avant de recommencer, volume moyen %.3f" % [song_name, MusicSynth.song_seconds(song_name), rms])
		if rms < 0.01 or MusicSynth.song_seconds(song_name) < 30.0:
			songs_ok = false
	check(songs_ok, "musiques : parties complètes, plus de 30 s avant de recommencer, son audible sans saturation")
	check(MusicSynth.chord_tones("Am") == [57, 60, 64] and MusicSynth.chord_tones("Bb") == [58, 62, 65]
		and absf(MusicSynth.midi_freq(69) - 440.0) < 0.01, "accords et notes")

	print("Clavier à l'écran")
	var missing := []
	for ch in "abcdefghijklmnopqrstuvwxyzéèçàù'-":
		if KeyboardView.keys_for(ch).size() != 1:
			missing.append(ch)
	check(missing.is_empty(), "toutes les lettres sont sur le clavier AZERTY %s" % str(missing))
	check(KeyboardView.keys_for("F") == ["f"] and KeyboardView.finger_hint("f") == "index gauche" and KeyboardView.finger_hint("j") == "index droit",
		"doigts : f = index gauche, j = index droit")
	check(KeyboardView.finger_hint("a") == "auriculaire gauche" and KeyboardView.finger_hint("m") == "auriculaire droit" and KeyboardView.finger_hint("e") == "majeur gauche",
		"doigts : a, m, e")
	check(KeyboardView.keys_for("ê") == ["^", "e"] and KeyboardView.finger_hint("ê") == "^ puis e (majeur gauche)" and KeyboardView.finger_hint("ï") == "Maj + ^ puis i (majeur droit)",
		"accents circonflexe et tréma : deux touches")
	check(KeyboardView.keys_for("€").is_empty() and KeyboardView.finger_hint("€") == "", "caractère absent du clavier")
	check(bool(Profile.new().get_setting("keyboard")), "clavier affiché par défaut")

	print("Fichiers abîmés")
	var jp := DATA_DIR.path_join("essai.json")
	app.write_json(jp, ["a"])
	app.write_json(jp, ["a", "b"])
	check(app.read_json(jp) == ["a", "b"] and FileAccess.file_exists(jp + ".bak") and not FileAccess.file_exists(jp + ".tmp"), "enregistrement avec copie de secours")
	var broken := FileAccess.open(jp, FileAccess.WRITE)
	broken.store_string("[\"a\", \"b")
	broken.close()
	check(app.read_json(jp) == ["a"], "fichier abîmé : la copie de secours est relue")
	app.write_json(jp, ["a", "c"])
	check(app.read_json(jp) == ["a", "c"] and app.read_json(jp + ".bak") == ["a"] and FileAccess.file_exists(jp + ".abime"),
		"fichier abîmé gardé à part, copie de secours conservée")
	var hist_path := DATA_DIR.path_join("profiles").path_join(profiles.current.id).path_join("history.json")
	var before_runs: int = profiles.history().size()
	profiles.add_history({"date": "2026-11-01", "kpm": 12.0})
	var broken_hist := FileAccess.open(hist_path, FileAccess.WRITE)
	broken_hist.store_string("")
	broken_hist.close()
	profiles.add_history({"date": "2026-11-02", "kpm": 13.0})
	# La course enregistrée au moment de la coupure est dans le fichier abîmé
	# (gardé en .abime) ; toutes les courses d'avant sont retrouvées.
	check(profiles.history().size() == before_runs + 1 and FileAccess.file_exists(hist_path + ".abime"),
		"historique abîmé : les anciennes courses ne sont pas perdues")

	print("Éditeur de liste")
	var cur: Profile = profiles.current
	# Chargé à l'exécution : le script utilise l'autoload Profiles.
	var editor: Control = load("res://scripts/ui/word_list_editor.gd").new()
	root.add_child(editor)
	editor.open_new(cur, "  ", "")
	editor.save()
	check(editor.visible and cur.word_lists.is_empty(), "liste vide refusée")
	editor.open_new(cur, "Couleurs", "rouge, vert;bleu\njaune 3")
	editor.save()
	check(not editor.visible and cur.word_lists.size() == 1, "nouvelle liste enregistrée")
	var saved_list: Dictionary = cur.word_lists[0]
	check(saved_list.title == "Couleurs" and Array(saved_list.words) == ["rouge", "vert", "bleu", "jaune"] and cur.is_active(saved_list.id), "nouvelle liste : mots découpés et liste cochée")
	editor.open_list(cur, cur.find_list(saved_list.id), false)
	editor._text.text = "rose"
	editor.save()
	check(Array(cur.find_list(saved_list.id).words) == ["rose"], "liste modifiée")
	app.reload()
	profiles.reload()
	check(profiles.current.find_list(saved_list.id).title == "Couleurs", "liste retrouvée après rechargement")
	editor.free()

	print("Réglages de l'ordinateur : son et graphismes")
	app.set_value("volume_music", 0.5)
	var music_bus := AudioServer.get_bus_index("Musique")
	check(music_bus != -1 and AudioServer.get_bus_index("Effets") != -1, "bus audio Musique et Effets créés")
	check(absf(AudioServer.get_bus_volume_db(music_bus) - linear_to_db(0.5)) < 0.01, "volume de la musique appliqué")
	app.set_value("volume_effects", 0.0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Effets")), "volume à 0 : effets coupés")
	app.reload()
	check(absf(float(app.get_value("volume_music")) - 0.5) < 0.001, "volume enregistré")
	var had_override := FileAccess.file_exists(app.OVERRIDE_PATH)
	var saved_override := FileAccess.get_file_as_string(app.OVERRIDE_PATH) if had_override else ""
	app.set_value("graphics", 2)
	var cfg := ConfigFile.new()
	check(cfg.load(app.OVERRIDE_PATH) == OK and cfg.get_value("rendering", "renderer/rendering_method", "") == "forward_plus", "mode Beau : moteur avancé demandé au prochain lancement")
	check(app.graphics_status() == "restart", "mode Beau : relance demandée")
	app.set_value("graphics", 0)
	check(not FileAccess.file_exists(app.OVERRIDE_PATH), "mode Simple : moteur avancé retiré")
	check(app.graphics_status() == "", "mode Simple : pas de relance (rendu simple déjà actif)")
	if had_override:
		var f := FileAccess.open(app.OVERRIDE_PATH, FileAccess.WRITE)
		f.store_string(saved_override)

	print("Contenu du jeu")
	var content := GameContent.get_content()
	check(content.characters.size() == 13, "13 personnages")
	check(content.playable_characters().size() == 8 and content.bot_characters().size() == 5, "8 jouables, 5 adversaires")
	var c := content.character("licorne")
	check(CharacterData.from_dict(c.to_dict()).to_dict() == c.to_dict(), "personnage : aller-retour JSON")
	var track: Track = content.tracks[0].instantiate()
	root.add_child(track)
	check(track.length > 500.0 and track.length < 800.0, "circuit construit (%.0f m)" % track.length)
	check(track.get_node("Generated").get_child_count() > 10, "décor généré")
	var before: float = track.length
	var path: Path3D = track.get_node("Path")
	path.curve.set_point_position(3, path.curve.get_point_position(3) + Vector3(0, 0, -40))
	track.rebuild()
	check(track.length > before + 20.0, "point déplacé : circuit reconstruit (%.0f m)" % track.length)
	track.free()
	TestUtil.remove_dir(DATA_DIR)
	completed = true
