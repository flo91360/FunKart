extends SceneTree
## Vitrine : photographie les modèles 3D (karts, pilotes, formes) sous une
## lumière de studio, pour les vérifier sans lancer le jeu.
##
## godot --path . --script res://tests/showroom.gd -- --out=dossier [--what=shapes|karts|heads] [--only=chat] [--theme=N]
## (avec un écran : xvfb-run pour la CI.)

var out_dir := "user://showroom"
var what := "karts"
var only := ""
var theme_index := 0
var frame := 0
var jobs: Array = [] # [nom, Node3D, position caméra, point visé]
var job := -1
var stage: Node3D
var cam: Camera3D


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.get_slice("=", 1)
		elif arg.begins_with("--what="):
			what = arg.get_slice("=", 1)
		elif arg.begins_with("--only="):
			only = arg.get_slice("=", 1)
		elif arg.begins_with("--theme="):
			theme_index = int(arg.get_slice("=", 1))
	DirAccess.make_dir_recursive_absolute(out_dir)


func _setup() -> void:
	root.size = Vector2i(900, 700)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	root.add_child(sun)
	var th: TrackTheme = GameContent.get_content().track_theme(theme_index)
	Ambience.apply(env, sun, th, AppSettings.Graphics.NORMAL, false)
	sun.directional_shadow_max_distance = 30.0
	for arg in OS.get_cmdline_user_args():
		if arg == "--noshadow":
			sun.shadow_enabled = false
		elif arg.begins_with("--tonemap="):
			env.tonemap_mode = int(arg.get_slice("=", 1)) as Environment.ToneMapper
		elif arg.begins_with("--exposure="):
			env.tonemap_exposure = float(arg.get_slice("=", 1))
		elif arg.begins_with("--sun="):
			sun.light_energy = float(arg.get_slice("=", 1))
		elif arg.begins_with("--ambient="):
			env.ambient_light_energy = float(arg.get_slice("=", 1))
		elif arg == "--plain":
			env.glow_enabled = false
			env.adjustment_enabled = false
		elif arg.begins_with("--sat="):
			env.adjustment_saturation = float(arg.get_slice("=", 1))
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = th.grass_a
	gm.roughness = 1.0
	ground.material_override = gm
	root.add_child(ground)
	cam = Camera3D.new()
	cam.fov = 35.0
	root.add_child(cam)
	stage = Node3D.new()
	root.add_child(stage)
	match what:
		"shapes":
			_shapes()
		"karts", "heads", "faces":
			var content := GameContent.get_content()
			for c in content.characters:
				if only != "" and c.id != only:
					continue
				var k := Kart.new(c, c.display_name)
				k.animated = false # pose fixe
				if what == "karts":
					jobs.append([c.id, k, Vector3(4.6, 2.6, -5.6), Vector3(0, 1.0, 0)])
					jobs.append([c.id + "_dos", k, Vector3(-2.2, 3.4, 7.5), Vector3(0, 1.0, 0)])
				elif what == "faces":
					jobs.append([c.id + "_face", k, Vector3(0.0, 2.5, -2.3), Vector3(0, 2.42, 0.1)])
				else:
					jobs.append([c.id + "_tete", k, Vector3(1.1, 2.8, -3.4), Vector3(0, 2.45, 0.1)])


func _shapes() -> void:
	var mb := MeshBuilder.new()
	mb.sphere(Vector3(-2.4, 0.6, 0), 0.5, "paint", Color("#e63946"))
	mb.ellipsoid(Vector3(-1.2, 0.6, 0), Vector3(0.45, 0.4, 0.5), "fur", Color("#f4a340"), Basis(),
		[[Vector3(0, -0.3, -1).normalized(), 0.35, 6.0], [Vector3(0.7, -0.2, -0.7).normalized(), 0.15, 4.0], [Vector3(-0.7, -0.2, -0.7).normalized(), 0.15, 4.0]], 20, 32)
	mb.rbox(Vector3(0, 0.5, 0), Vector3(0.4, 0.3, 0.6), "plastic", Color("#2d7ff9"))
	mb.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.3, 0.05), Vector2(0.35, 0.4), Vector2(0.2, 0.9), Vector2(0, 1.0)]), "chrome", Color.WHITE, Transform3D(Basis(), Vector3(1.2, 0, 0)))
	mb.tube(MeshBuilder.smooth_path(PackedVector3Array([Vector3(2.2, 0.1, 0), Vector3(2.4, 0.8, 0.2), Vector3(2.0, 1.4, 0.0)]), 6),
		MeshBuilder.taper(19, 0.15, 0.04), "fur", Color("#8b5a2b"), 12)
	mb.loft([[-0.6, 0.3, 0.1, 0.3, 4.0], [0.0, 0.4, 0.2, 0.4, 4.0], [0.6, 0.3, 0.15, 0.35, 3.0]], "paint", func(p: Vector3) -> Color:
		return Color.WHITE if absf(p.x) < 0.08 else Color("#17b169"), 28, 0.1, 0.1)
	mb.cap(Vector3(-2.4, 0.6, 0), 0.505, Vector3(0, 0, 1), 0.5, "eye", Color("#202020"))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.commit()
	var holder := Node3D.new()
	holder.add_child(mi)
	jobs.append(["formes", holder, Vector3(0, 2.6, 6.5), Vector3(0, 0.5, 0)])
	print("sommets : ", mb.vertex_count())


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 1:
		_setup()
		return false
	if job == -1 or frame % 4 == 0:
		if job >= 0:
			var img := root.get_viewport().get_texture().get_image()
			img.save_png(out_dir.path_join("%s.png" % jobs[job][0]))
			print("vu ", jobs[job][0])
		job += 1
		if job >= jobs.size():
			return true
		for c in stage.get_children():
			stage.remove_child(c)
		var node: Node3D = jobs[job][1]
		stage.add_child(node)
		cam.look_at_from_position(jobs[job][2], jobs[job][3])
	return false
