## Пауза: мир стоит, пока не нажмёшь «Продолжить». Сюда же попадаешь, если свернул игру.
extends Control

signal resume
signal settings
signal to_menu

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.03, 0.06, 0.62)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := Kit.vbox(14)
	box.custom_minimum_size = Vector2(420, 0)
	var title := Kit.label("Пауза", 44, Art.TEXT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Kit.muted("Океан ждёт — никто не двигается", 19)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(_button("Продолжить", Art.GREEN, Art.BG, 68, func(): resume.emit()))
	box.add_child(_button("Настройки", Art.CARD, Art.TEXT, 56, func(): settings.emit()))
	box.add_child(_button("Выйти в меню", Color(0, 0, 0, 0), Art.GREEN, 56, func(): to_menu.emit()))
	center.add_child(box)

func _button(text: String, bg: Color, fg: Color, h: float, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_font_size_override("font_size", 26 if h > 60 else 22)
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, Kit.box(bg, 20, Art.GREEN_DARK if bg.a == 0.0 else Color(0, 0, 0, 0)))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, fg)
	b.pressed.connect(action)
	Kit.press_fx(b)
	return b

func open() -> void:
	visible = true
	Kit.pop_in(get_child(1))
