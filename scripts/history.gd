class_name History
## Historique des courses (suivi de l'enfant), enregistré dans user://history.json.

const PATH := "user://history.json"


static func load_all() -> Array:
	if not FileAccess.file_exists(PATH):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return parsed if parsed is Array else []


static func add(entry: Dictionary) -> void:
	var all := load_all()
	all.append(entry)
	_save(all)


static func clear() -> void:
	_save([])


static func _save(all: Array) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(all, "\t"))


## Exporte l'historique en CSV (lisible par Excel / LibreOffice) dans le dossier Documents.
## Renvoie le chemin du fichier, ou "" en cas d'échec.
static func export_csv() -> String:
	var dir := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if dir == "" or not DirAccess.dir_exists_absolute(dir):
		dir = OS.get_user_data_dir()
	var path := dir.path_join("FunKart_historique.csv")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_buffer(PackedByteArray([0xEF, 0xBB, 0xBF]))
	f.store_line("date;prenom;pilote;place;participants;tours;frappes_par_minute;precision_pct;mots;erreurs;temps_moyen_par_mot_s;temps_course_s;adversaires_frappes_par_minute")
	for h in load_all():
		var cols := [h.get("date", ""), h.get("name", ""), h.get("character", ""), h.get("place", 0),
			h.get("total", 0), h.get("laps", 0), "%.1f" % float(h.get("kpm", 0)),
			"%.1f" % (float(h.get("accuracy", 0)) * 100.0), h.get("words", 0), h.get("errors", 0),
			"%.2f" % float(h.get("avg_word_time", 0)), "%.1f" % float(h.get("time", 0)),
			" / ".join(PackedStringArray(Array(h.get("bot_kpm", [])).map(func(v): return str(int(v)))))]
		var cells := PackedStringArray()
		for c in cols:
			cells.append("\"%s\"" % str(c).replace("\"", "\"\""))
		f.store_line(";".join(cells))
	return path
