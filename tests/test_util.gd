class_name TestUtil
## Outils communs aux tests.


## Fait pointer AppSettings et Profiles vers un dossier de test vide.
static func reset_data(root: Window, data_dir: String) -> void:
	remove_dir(data_dir)
	DirAccess.make_dir_recursive_absolute(data_dir)
	var app = root.get_node("AppSettings")
	app.data_dir = data_dir
	app.reload()
	root.get_node("Profiles").reload()


static func remove_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		remove_dir(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)
