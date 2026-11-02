extends SceneTree
## Captures des fenêtres de l'interface (réglages, historique, calcul pour
## les adultes, nouveau profil, pause), pour les vérifier sans lancer le jeu.
##
## xvfb-run godot --path . --script res://tests/ui_shots.gd -- --shots=dossier

const DATA_DIR := "user://test_ui_shots"

var main: Node
var frame := 0
var shots_dir := "user://ui_shots"
var steps: Array[Callable] = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(shots_dir)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 1:
		TestUtil.reset_data(root, DATA_DIR)
		root.get_node("AppSettings").data["fullscreen"] = false
		main = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		var menu = main.menu
		steps = [
			func(): _shot("menu"),
			func(): menu.settings_dialog.open(root.get_node("Profiles").current),
			func(): _shot("reglages"),
			func(): menu.settings_dialog.close_dialog(),
			func(): menu.history_dialog.open(root.get_node("Profiles").current),
			func(): _shot("historique"),
			func(): menu.history_dialog.visible = false,
			func(): menu._gate.open(),
			func(): _shot("calcul_adulte"),
			func(): menu._gate.visible = false,
			func(): menu._open_new_profile(),
			func(): _shot("nouveau_profil"),
		]
	if frame >= 40 and frame % 6 == 0:
		var i := (frame - 40) / 6
		if i >= steps.size():
			return true
		steps[i].call()
	return false


func _shot(name: String) -> void:
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(shots_dir.path_join(name + ".png"))
	print("capture ", name)
