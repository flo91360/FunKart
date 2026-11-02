extends SceneTree
## Recrée ui/theme.tres à partir de Ui.build_theme() (après avoir modifié le
## thème dans scripts/ui/ui.gd).
##
## godot --headless --path . --script res://tests/make_theme.gd

func _initialize() -> void:
	var err := ResourceSaver.save(Ui.build_theme(), Ui.THEME_PATH)
	print("ui/theme.tres : ", "OK" if err == OK else "erreur %d" % err)
	quit(0 if err == OK else 1)
