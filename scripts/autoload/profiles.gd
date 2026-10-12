extends Node
## Gestion des profils d'enfants (autoload « Profiles ») : création, choix,
## enregistrement, historique des courses, export CSV.
##
## <données>/profiles/<id>/profile.json  : le profil (voir Profile)
## <données>/profiles/<id>/history.json  : ses courses

signal current_changed

var profiles: Array[Profile] = []
var current: Profile


func _ready() -> void:
	reload()


func _dir() -> String:
	return AppSettings.path("profiles")


func reload() -> void:
	profiles.clear()
	DirAccess.make_dir_recursive_absolute(_dir())
	for sub in DirAccess.get_directories_at(_dir()):
		var d: Variant = AppSettings.read_json(_dir().path_join(sub).path_join("profile.json"))
		if d is Dictionary:
			var p := Profile.from_dict(d)
			if p.id != "":
				profiles.append(p)
	if profiles.is_empty():
		_migrate_legacy()
	if profiles.is_empty():
		var p := Profile.create("Joueur 1")
		profiles.append(p)
		save_profile(p)
	profiles.sort_custom(func(a, b): return a.name.naturalnocasecmp_to(b.name) < 0)
	var last := String(AppSettings.get_value("last_profile"))
	current = find(last) if find(last) else profiles[0]
	current_changed.emit()


func find(id: String) -> Profile:
	for p in profiles:
		if p.id == id:
			return p
	return null


func select(p: Profile) -> void:
	current = p
	AppSettings.set_value("last_profile", p.id)
	current_changed.emit()


func create(p_name: String) -> Profile:
	var p := Profile.create(p_name)
	profiles.append(p)
	save_profile(p)
	select(p)
	return p


func delete(p: Profile) -> void:
	if profiles.size() <= 1:
		return
	var dir := _dir().path_join(p.id)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
	profiles.erase(p)
	if current == p:
		select(profiles[0])


func save_profile(p: Profile = null) -> void:
	if p == null:
		p = current
	var dir := _dir().path_join(p.id)
	DirAccess.make_dir_recursive_absolute(dir)
	AppSettings.write_json(dir.path_join("profile.json"), p.to_dict())


# ---------------- Historique ----------------

func history(p: Profile = null) -> Array:
	if p == null:
		p = current
	var d: Variant = AppSettings.read_json(_dir().path_join(p.id).path_join("history.json"))
	return d if d is Array else []


func add_history(entry: Dictionary, p: Profile = null) -> void:
	if p == null:
		p = current
	var all := history(p)
	all.append(entry)
	DirAccess.make_dir_recursive_absolute(_dir().path_join(p.id))
	AppSettings.write_json(_dir().path_join(p.id).path_join("history.json"), all)


func clear_history(p: Profile = null) -> void:
	if p == null:
		p = current
	AppSettings.write_json(_dir().path_join(p.id).path_join("history.json"), [])


## Exporte l'historique de tous les profils en CSV (Excel / LibreOffice), par
## défaut dans le dossier Documents. Renvoie le chemin du fichier, ou "" en cas d'échec.
func export_csv(dir := "") -> String:
	if dir == "":
		dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if dir == "" or not DirAccess.dir_exists_absolute(dir):
		dir = OS.get_user_data_dir()
	var file_path := dir.path_join("FunKart_historique.csv")
	var f := FileAccess.open(file_path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_buffer(PackedByteArray([0xEF, 0xBB, 0xBF]))
	f.store_line("profil;date;pilote;place;participants;tours;frappes_par_minute;precision_pct;mots;erreurs;temps_moyen_par_mot_s;temps_course_s;adversaires_frappes_par_minute;listes_de_mots")
	for p in profiles:
		for h in history(p):
			var cols := [p.name, h.get("date", ""), h.get("character", ""), h.get("place", 0),
				h.get("total", 0), h.get("laps", 0), "%.1f" % float(h.get("kpm", 0)),
				"%.1f" % (float(h.get("accuracy", 0)) * 100.0), h.get("words", 0), h.get("errors", 0),
				"%.2f" % float(h.get("avg_word_time", 0)), "%.1f" % float(h.get("time", 0)),
				" / ".join(PackedStringArray(Array(h.get("bot_kpm", [])).map(func(v): return str(int(v))))),
				h.get("word_lists", "")]
			var cells := PackedStringArray()
			for c in cols:
				cells.append("\"%s\"" % str(c).replace("\"", "\"\""))
			f.store_line(";".join(cells))
	return file_path


# ---------------- Reprise des données de l'ancienne version ----------------

## Avant les profils, les réglages étaient dans settings.json et l'historique
## dans history.json. On en fait un premier profil ; les anciens fichiers sont
## renommés en *.old.json (rien n'est supprimé).
func _migrate_legacy() -> void:
	var old: Variant = AppSettings.read_json(AppSettings.path("settings.json"))
	if not (old is Dictionary):
		return
	var p_name := String(old.get("player_name", "")).strip_edges()
	var p := Profile.create(p_name if p_name != "" else "Joueur 1")
	p.character_id = String(old.get("character", "chat"))
	for key in Profile.DEFAULT_SETTINGS:
		if old.has(key):
			p.settings[key] = old[key]
	if old.has("words"):
		var old_words := WordList.parse(String(old.words))
		if not old_words.is_empty() and old_words != GameContent.get_content().default_word_list().words:
			p.active_lists = [p.add_list("Ma liste", old_words).id]
	profiles.append(p)
	save_profile(p)

	var hist: Variant = AppSettings.read_json(AppSettings.path("history.json"))
	if hist is Array:
		AppSettings.write_json(_dir().path_join(p.id).path_join("history.json"), hist)
		DirAccess.rename_absolute(AppSettings.path("history.json"), AppSettings.path("history.old.json"))

	# Réglages de l'ordinateur ; avant la version 2, le plein écran n'était pas le défaut.
	AppSettings.data["fullscreen"] = true if int(old.get("version", 1)) < 2 else bool(old.get("fullscreen", true))
	AppSettings.data["sound"] = bool(old.get("sound", true))
	AppSettings.data["music"] = bool(old.get("music", true))
	AppSettings.data["last_profile"] = p.id
	AppSettings.save()
	DirAccess.rename_absolute(AppSettings.path("settings.json"), AppSettings.path("settings.old.json"))
