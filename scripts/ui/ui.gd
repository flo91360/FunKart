class_name Ui
## Thème et petites fonctions pour construire l'interface.

const INK := Color("#183a37")
const ORANGE := Color("#325a55")
const YELLOW := Color("#ffcf76")
const GREEN := Color("#269779")
const RED := Color("#db6869")
const NAVY := Color("#123735")

static var _font: Font
static var _word_font: Font
static var _theme: Theme


static func font() -> Font:
	if _font == null:
		_font = load("res://ui/fonts/NunitoBold.ttf")
	return _font


## Police du mot à taper : lettres simples et bien espacées.
static func word_font() -> Font:
	if _word_font == null:
		var f := font()
		var v := FontVariation.new()
		v.base_font = f
		v.spacing_glyph = 6
		_word_font = v
	return _word_font


static func flat(color: Color, radius := 16, border_color := Color.TRANSPARENT, border := 0, pad := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	if color.a > 0.5:
		s.shadow_color = Color(0.04, 0.15, 0.19, 0.17)
		s.shadow_size = 6
		s.shadow_offset = Vector2(0, 3)
	if border > 0:
		s.border_color = border_color
		s.set_border_width_all(border)
	return s


const THEME_PATH := "res://ui/theme.tres"


## Thème de l'interface (ui/theme.tres, modifiable dans l'éditeur Godot).
static func theme() -> Theme:
	if _theme == null:
		_theme = load(THEME_PATH) if ResourceLoader.exists(THEME_PATH) else build_theme()
	return _theme


## Construit le thème par défaut (sert à recréer ui/theme.tres).
static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 24
	t.set_stylebox("normal", "Button", flat(ORANGE, 14, Color.TRANSPARENT, 0, 10))
	t.set_stylebox("hover", "Button", flat(ORANGE.lightened(0.12), 14, Color.TRANSPARENT, 0, 10))
	t.set_stylebox("pressed", "Button", flat(ORANGE.darkened(0.2), 14, Color.TRANSPARENT, 0, 10))
	t.set_stylebox("disabled", "Button", flat(Color("#a7b9b8"), 14, Color.TRANSPARENT, 0, 10))
	t.set_stylebox("focus", "Button", flat(Color.TRANSPARENT, 14, NAVY, 4, 10))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", Color.WHITE)
	for type in ["CheckBox", "CheckButton"]:
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			t.set_stylebox(st, type, StyleBoxEmpty.new())
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			t.set_color(c, type, INK)
	t.set_stylebox("panel", "PanelContainer", flat(Color("#fff5e5"), 24, Color.TRANSPARENT, 0, 24))
	t.set_stylebox("panel", "Panel", flat(Color("#fff5e5"), 24))
	t.set_color("font_color", "Label", INK)
	t.set_stylebox("normal", "LineEdit", flat(Color.WHITE, 12, Color("#c9ccd6"), 3, 10))
	t.set_stylebox("focus", "LineEdit", flat(Color.TRANSPARENT, 12, ORANGE, 3, 10))
	t.set_color("font_color", "LineEdit", INK)
	t.set_stylebox("normal", "TextEdit", flat(Color.WHITE, 12, Color("#c9ccd6"), 3, 10))
	t.set_stylebox("focus", "TextEdit", flat(Color.TRANSPARENT, 12, ORANGE, 3, 10))
	t.set_color("font_color", "TextEdit", INK)
	var track := flat(Color("#d5d8e0"), 8, Color.TRANSPARENT, 0, 0)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", track)
	var filled := flat(ORANGE, 8, Color.TRANSPARENT, 0, 0)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	return t


static func label(text: String, size := 24, color := INK, outline := 0, outline_color := Color.BLACK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", outline_color)
	return l


static func button(text: String, size := 24, color := ORANGE) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	if color != ORANGE:
		set_button_color(b, color)
	return b


static func set_button_color(b: Button, color: Color, border := Color.TRANSPARENT) -> void:
	var bw := 2 if border != Color.TRANSPARENT else 0
	b.add_theme_stylebox_override("focus", flat(Color.TRANSPARENT, 16, Color("#f1ddb6"), 2, 10))
	b.add_theme_stylebox_override("normal", flat(color, 16, border, bw, 10))
	b.add_theme_stylebox_override("hover", flat(color.lightened(0.12), 16, border, bw, 10))
	b.add_theme_stylebox_override("pressed", flat(color.darkened(0.2), 16, border, bw, 10))
	var text_color := INK if color.get_luminance() > 0.5 else Color("#f3ead4")
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, text_color)


## Calque plein écran (fond assombri) avec un panneau centré.
static func overlay(parent: Node, size: Vector2) -> Array:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = size
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	return [dim, box]


static func place_text(place: int) -> String:
	return "1er" if place == 1 else "%de" % place


static func format_time(s: float) -> String:
	if s == INF or s < 0.0:
		return "—"
	var m := int(s / 60.0)
	return "%d:%04.1f" % [m, s - m * 60.0]


## Voile doux sur le fond 3D, sans intercepter les clics.
static func backdrop(parent: Control) -> void:
	var veil := ColorRect.new()
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(veil)
	parent.move_child(veil, 0)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	float left = 1.0 - smoothstep(0.16, 0.65, UV.x);
	float bottom = smoothstep(0.62, 0.92, UV.y);
	float edge = smoothstep(0.45, 0.9, distance(UV, vec2(0.64, 0.42)));
	COLOR = vec4(0.025, 0.085, 0.083, clamp(left * 0.76 + bottom * 0.82 + edge * 0.16, 0.0, 0.94));
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	veil.material = material


## Portrait 3D calculé une seule fois : les cartes montrent les vrais modèles.
static func portrait(character_id: String) -> SubViewportContainer:
	var holder := SubViewportContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.stretch = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(96, 96)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.msaa_3d = Viewport.MSAA_2X
	holder.add_child(viewport)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.TRANSPARENT
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c8d6c7")
	env.ambient_light_energy = 0.75
	world.environment = env
	viewport.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -35, 0)
	light.light_energy = 0.8
	viewport.add_child(light)
	var path := "res://assets/models/%s.glb" % character_id
	if not ResourceLoader.exists(path):
		path = "res://assets/models/chat.glb"
	var character: Node3D = load(path).instantiate()
	viewport.add_child(character)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.9
	viewport.add_child(camera)
	camera.position = Vector3(0, 2.14, -3.0)
	camera.rotation.y = PI
	return holder
