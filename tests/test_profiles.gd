extends SceneTree
## Tests des données : reprise des anciennes données, profils, historique,
## contenu du jeu (personnages, circuit).
##
## godot --headless --path . --script res://tests/test_profiles.gd

const DATA_DIR := "user://test_profiles"

var failures := 0
var frame := 0


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 1:
		_run()
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
