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
