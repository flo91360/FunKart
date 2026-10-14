extends SceneTree
## Contrôle des modèles et de la lisibilité du menu, sans carte graphique.

var failures := 0
var completed := false


func _initialize() -> void:
	create_timer(25.0).timeout.connect(func():
		push_error("Le contrôle graphique ne s'est pas terminé")
		quit(1))
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	if condition:
		print("  ok   ", message)
	else:
		failures += 1
		push_error(message)


func _run() -> void:
	TestUtil.reset_data(root, "user://test_graphics")
	var mesh := Mk.rounded_box(Vector3(1.4, 0.4, 2.3), 0.16)
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	check(vertices.size() > 0 and vertices.size() == normals.size(), "carrosserie : géométrie et normales présentes")
	var valid := true
	for i in vertices.size():
		valid = valid and vertices[i].is_finite() and normals[i].is_finite()
		valid = valid and is_equal_approx(normals[i].length(), 1.0)
	check(valid, "carrosserie : normales unitaires et coordonnées finies")
	var extents := mesh.get_aabb().size
	check(extents.is_equal_approx(Vector3(1.4, 0.4, 2.3)), "carrosserie : dimensions conservées après biseautage")
	for character in GameContent.get_content().characters:
		var kart := Kart.new(character)
		root.add_child(kart)
		check(kart.driver_head != null and kart.scarf != null and kart.wheels.size() == 4, "pilote complet : " + character.display_name)
		kart.free()
	check(Ui.font().has_char(233) and Ui.font().has_char(231), "police intégrée : accents et cédille disponibles")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 4:
		await process_frame
	var menu = main.menu
	var hero: Label = menu.get_node("Root/FestivalTitle")
	var bounds := hero.get_viewport_rect()
	check(bounds.encloses(hero.get_global_rect()), "titre du festival dans l'écran")
	check(not hero.get_global_rect().intersects(menu.get_node("Root/Panel").get_global_rect()), "titre du festival distinct du panneau de sélection")
	check(bounds.encloses(menu.play_button.get_global_rect()), "bouton de départ dans l'écran")
	main.race.start()
	check(main.race.hud.word_progress != null, "barre de progression de frappe créée")
	main.race.hud.show_word("kart", 2)
	check(is_equal_approx(main.race.hud.word_progress.value, 50.0), "progression de frappe : deux lettres sur quatre")
	main.race.hud.clear_word()
	check(not main.race.hud.word_progress.visible, "progression masquée entre les mots")
	completed = true
	print("OK" if failures == 0 else "ÉCHECS : %d" % failures)
	main.free()
	quit(0 if failures == 0 and completed else 1)
