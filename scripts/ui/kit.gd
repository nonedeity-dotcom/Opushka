## Общий вид интерфейса: тема, плашки, надписи. В одном месте, чтобы кнопки в сумке и в
## настройках не расходились по цвету и размеру.
class_name Kit
extends RefCounted

static func box(bg: Color, radius := 18, border := Color(0, 0, 0, 0), pad := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border.a > 0:
		s.border_color = border
		s.set_border_width_all(2)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.7
	s.content_margin_bottom = pad * 0.7
	s.anti_aliasing = true
	return s

static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 26
	t.set_color("font_color", "Label", Art.TEXT)
	t.set_color("font_color", "Button", Art.TEXT)
	t.set_color("font_disabled_color", "Button", Art.MUTED)
	t.set_color("font_pressed_color", "Button", Art.BG)
	t.set_color("font_hover_color", "Button", Art.TEXT)
	t.set_color("font_hover_pressed_color", "Button", Art.BG)
	t.set_color("font_focus_color", "Button", Art.TEXT)
	t.set_stylebox("normal", "Button", box(Art.CARD, 14))
	t.set_stylebox("hover", "Button", box(Art.CARD, 14))
	t.set_stylebox("pressed", "Button", box(Art.GREEN, 14))
	t.set_stylebox("hover_pressed", "Button", box(Art.GREEN, 14))
	t.set_stylebox("disabled", "Button", box(Art.CARD_BORDER, 14))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", box(Art.BG, 26, Art.CARD_BORDER, 22))
	t.set_stylebox("panel", "Panel", box(Art.BG, 26, Art.CARD_BORDER))
	t.set_color("font_color", "CheckButton", Art.TEXT)
	t.set_color("font_pressed_color", "CheckButton", Art.TEXT)
	t.set_color("font_hover_color", "CheckButton", Art.TEXT)
	t.set_color("font_hover_pressed_color", "CheckButton", Art.TEXT)
	t.set_stylebox("normal", "CheckButton", box(Art.CARD, 14))
	t.set_stylebox("pressed", "CheckButton", box(Art.CARD, 14))
	t.set_stylebox("hover", "CheckButton", box(Art.CARD, 14))
	t.set_stylebox("hover_pressed", "CheckButton", box(Art.CARD, 14))
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	# Полоса прокрутки — тонкая и тихая.
	var grab := box(Color(1, 1, 1, 0.18), 4, Color(0, 0, 0, 0), 0)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	return t

static func label(text: String, size := 26, color := Art.TEXT, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_constant_override("outline_size", 1)
		l.add_theme_color_override("font_outline_color", color)
	return l

static func muted(text: String, size := 20) -> Label:
	var l := label(text, size, Art.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

## Плашка с содержимым: цвет карточки, скругления.
static func card(child: Control, bg := Art.CARD, radius := 18, pad := 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, radius, Color(0, 0, 0, 0), pad))
	p.add_child(child)
	return p

static func hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


## Лист появляется мягко: из прозрачного и чуть меньше — к обычному, с лёгким пружинящим
## доводом.
static func pop_in(node: Control) -> void:
	node.pivot_offset = node.size / 2.0
	node.modulate.a = 0.0
	node.scale = Vector2(0.94, 0.94)
	var tw := node.create_tween().set_parallel()
	tw.tween_property(node, "modulate:a", 1.0, 0.16)
	tw.tween_property(node, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Короткий «прыжок» элемента: вырос и вернулся.
static func bounce(node: Control, k := 1.15) -> void:
	node.pivot_offset = node.size / 2.0
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(k, k), 0.09)
	tw.tween_property(node, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
