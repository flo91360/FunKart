class_name Ui
## Thème et petites fonctions pour construire l'interface : boutons
## « bonbons » en relief, panneaux arrondis avec une ombre douce, polices
## livrées avec le jeu.

const INK := Color("#1f2433")
const ORANGE := Color("#ff6b35")
const YELLOW := Color("#ffd60a")
const GREEN := Color("#27ae60")
const RED := Color("#e63946")
const NAVY := Color("#1d3557")

static var _font: Font
static var _bold_font: Font
static var _title_font: Font
static var _word_font: Font
static var _theme: Theme

## Polices livrées avec le jeu (ui/fonts, licence libre OFL).
const FONT_TEXT := "res://ui/fonts/Fredoka.ttf"
const FONT_TITLE := "res://ui/fonts/LilitaOne.ttf"
const FONT_WORD := "res://ui/fonts/Andika-Bold.ttf"


## Police de l'interface : ronde et bien lisible (Fredoka, demi-gras).
static func font() -> Font:
	if _font == null:
		_font = _variation(FONT_TEXT, 560)
	return _font


## Même police, en gras (boutons).
static func bold_font() -> Font:
	if _bold_font == null:
		_bold_font = _variation(FONT_TEXT, 680)
	return _bold_font


## Police des titres et des grands chiffres (Lilita One).
static func title_font() -> Font:
	if _title_font == null:
		_title_font = load(FONT_TITLE)
	return _title_font


## Police du mot à taper : lettres simples et bien espacées (Andika, conçue
## pour les enfants qui apprennent à lire).
static func word_font() -> Font:
	if _word_font == null:
		var v := FontVariation.new()
		v.base_font = load(FONT_WORD)
		v.spacing_glyph = 4
		_word_font = v
	return _word_font


static func _variation(path: String, weight: int) -> Font:
	var v := FontVariation.new()
	v.base_font = load(path)
	# axe « wght » (graisse) de la police variable, désigné par son étiquette OpenType
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return v


static func flat(color: Color, radius := 16, border_color := Color.TRANSPARENT, border := 0, pad := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
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


## Construit le thème par défaut (sert à recréer ui/theme.tres : voir
## tests/make_theme.gd).
static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 24
	_button_styles(t, "Button", ORANGE)
	_button_styles(t, "OptionButton", Color.WHITE)
	_button_styles(t, "MenuButton", Color.WHITE)
	for type in ["OptionButton", "MenuButton"]:
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			t.set_color(c, type, INK)
	t.set_font("font", "Button", bold_font())
	t.set_font("font", "OptionButton", bold_font())
	t.set_stylebox("focus", "Button", flat(Color.TRANSPARENT, 18, Color(1, 1, 1, 0.9), 4, 10))
	t.set_stylebox("focus", "OptionButton", flat(Color.TRANSPARENT, 18, ORANGE, 4, 10))
	for type in ["CheckBox", "CheckButton"]:
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			t.set_stylebox(st, type, StyleBoxEmpty.new())
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			t.set_color(c, type, INK)
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())
	t.set_color("font_color", "Label", INK)
	# liste déroulante (choix du profil…)
	var popup := flat(Color.WHITE, 18, Color("#dde2ec"), 2, 10)
	popup.shadow_color = Color(0, 0, 0, 0.25)
	popup.shadow_size = 12
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_stylebox("hover", "PopupMenu", flat(Color("#ffe1d4"), 12, Color.TRANSPARENT, 0, 6))
	for c in ["font_color", "font_hover_color"]:
		t.set_color(c, "PopupMenu", INK)
	t.set_font("font", "PopupMenu", bold_font())
	t.set_font_size("font_size", "PopupMenu", 26)
	t.set_constant("v_separation", "PopupMenu", 10)
	# champs de texte
	for type in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", type, flat(Color.WHITE, 14, Color("#cdd4e2"), 3, 10))
		t.set_stylebox("focus", type, flat(Color.TRANSPARENT, 14, ORANGE, 3, 10))
		t.set_color("font_color", type, INK)
		t.set_color("caret_color", type, ORANGE)
		t.set_color("selection_color", type, Color(1.0, 0.42, 0.21, 0.3))
	# curseurs
	var track := flat(Color("#d8dde8"), 8, Color.TRANSPARENT, 0, 0)
	track.content_margin_top = 7
	track.content_margin_bottom = 7
	t.set_stylebox("slider", "HSlider", track)
	var filled := flat(ORANGE, 8, Color.TRANSPARENT, 0, 0)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	# barres de défilement
	for type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", type, flat(Color(0, 0, 0, 0.06), 8, Color.TRANSPARENT, 0, 4))
		t.set_stylebox("grabber", type, flat(Color("#b9c1d0"), 8, Color.TRANSPARENT, 0, 4))
		t.set_stylebox("grabber_highlight", type, flat(Color("#9aa4b8"), 8, Color.TRANSPARENT, 0, 4))
		t.set_stylebox("grabber_pressed", type, flat(ORANGE, 8, Color.TRANSPARENT, 0, 4))
	# fenêtres de confirmation et d'aide
	t.set_stylebox("panel", "AcceptDialog", panel_style())
	t.set_stylebox("panel", "TooltipPanel", flat(Color("#1f2433"), 10, Color.TRANSPARENT, 0, 8))
	t.set_color("font_color", "TooltipLabel", Color.WHITE)
	return t


## Panneau blanc arrondi, légèrement transparent, avec une ombre douce.
static func panel_style(alpha := 0.94, radius := 28, pad := 22) -> StyleBoxFlat:
	var s := flat(Color(1, 1, 1, alpha), radius, Color(1, 1, 1, 0.75), 3, pad)
	s.shadow_color = Color(0.05, 0.08, 0.2, 0.28)
	s.shadow_size = 18
	s.shadow_offset = Vector2(0, 6)
	return s


## Styles d'un bouton « bonbon » : couleur vive, bord inférieur plus foncé
## (relief), il s'enfonce quand on appuie. border : contour (bouton choisi).
static func candy(color: Color, radius := 18, depth := 6, border := Color.TRANSPARENT, pad := 12) -> Dictionary:
	var dark := color.darkened(0.28)
	if color.get_luminance() > 0.85:
		dark = Color("#c8cfdd")
	var out := {}
	for state in ["normal", "hover", "pressed", "disabled"]:
		var c := color
		var d := depth
		match state:
			"hover":
				c = color.lightened(0.1)
			"pressed":
				c = color.darkened(0.06)
				d = 2
			"disabled":
				c = color.lerp(Color("#c9ced8"), 0.7)
		var s := flat(c, radius, dark, 0, pad)
		s.border_width_bottom = d
		s.border_color = dark if state != "disabled" else c.darkened(0.15)
		if border != Color.TRANSPARENT:
			s.border_width_left = 4
			s.border_width_top = 4
			s.border_width_right = 4
			s.border_width_bottom = d + 4
			s.border_color = border
		s.content_margin_bottom = pad + d - 2
		if state == "pressed":
			s.content_margin_top = pad + depth - 2
			s.content_margin_bottom = pad
		s.shadow_color = Color(0.05, 0.08, 0.2, 0.22 if state != "pressed" else 0.12)
		s.shadow_size = 6 if state != "pressed" else 3
		s.shadow_offset = Vector2(0, 3)
		s.anti_aliasing_size = 0.8
		out[state] = s
	return out


static func _button_styles(t: Theme, type: String, color: Color) -> void:
	var st := candy(color)
	for state in st:
		t.set_stylebox(state, type, st[state])
	var text := INK if color.get_luminance() > 0.6 else Color.WHITE
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, type, text)


## Grand titre (police Lilita One), avec un contour et une ombre portée.
static func title(text: String, size := 48, color := Color.WHITE, outline := 14, outline_color := NAVY) -> Label:
	var l := label(text, size, color, outline, outline_color)
	l.add_theme_font_override("font", title_font())
	if outline > 0:
		l.add_theme_color_override("font_shadow_color", Color(0.05, 0.08, 0.2, 0.45))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", maxi(3, size / 14))
		l.add_theme_constant_override("shadow_outline_size", outline)
	return l


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


static func set_button_color(b: Button, color: Color, border := Color.TRANSPARENT, radius := 18) -> void:
	var st := candy(color, radius, 6, border)
	for state in st:
		b.add_theme_stylebox_override(state, st[state])
	var text_color := INK if color.get_luminance() > 0.6 else Color.WHITE
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, text_color)


## Petit rebond quand la souris passe sur un bouton (et quand on le choisit).
static func bounce_on_hover(c: Control, amount := 1.05) -> void:
	c.resized.connect(func(): c.pivot_offset = c.size / 2.0)
	c.mouse_entered.connect(func():
		c.pivot_offset = c.size / 2.0
		c.create_tween().tween_property(c, "scale", Vector2.ONE * amount, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	c.mouse_exited.connect(func():
		c.create_tween().tween_property(c, "scale", Vector2.ONE, 0.15))


static func pop(c: Control, amount := 1.12) -> void:
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE * amount, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, 0.18)


## Calque plein écran (fond assombri) avec un panneau centré.
static func overlay(parent: Node, size: Vector2) -> Array:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.06, 0.16, 0.6)
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
