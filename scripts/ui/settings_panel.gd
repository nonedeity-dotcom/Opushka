## Настройки игры. Всё меняется сразу, без кнопки «сохранить»: переключил джойстик на
## крестовину — закрыл — играешь.
extends Control

signal closed
signal changed(settings: Settings)
signal new_world

var settings: Settings
var village: Village
var landscape := false
var _arming := false

var _sheet: PanelContainer
var _body: VBoxContainer
var _scroll_pos := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			closed.emit())
	add_child(shade)
	_sheet = PanelContainer.new()
	add_child(_sheet)
	_body = Kit.vbox(12)
	_sheet.add_child(_body)
	resized.connect(_place)


func open(s: Settings, v: Village, landscape_: bool) -> void:
	settings = s
	village = v
	landscape = landscape_
	_arming = false
	visible = true
	_scroll_pos = 0
	rebuild()

func _place() -> void:
	if landscape:
		_sheet.position = Vector2(size.x * 0.4, 0)
		_sheet.size = Vector2(size.x * 0.6, size.y)
	else:
		_sheet.position = Vector2(0, size.y * 0.1)
		_sheet.size = Vector2(size.x, size.y * 0.9)

func _apply(key: String, value: Variant) -> void:
	settings.set(key, value)
	changed.emit(settings)
	rebuild()

func rebuild() -> void:
	var old := _body.get_child(1) as ScrollContainer if _body.get_child_count() > 1 else null
	if old:
		_scroll_pos = old.scroll_vertical
	# Старое убираем сразу, а не в конце кадра: иначе прежняя ширина (сетка вещей, другая
	# вкладка) ещё держит лист и не даёт ему сузиться.
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_place()

	var head := Kit.hbox(12)
	var gear := preload("res://scripts/ui/bag_panel.gd").Icon.new()
	gear.icon = "settings"
	gear.custom_minimum_size = Vector2(44, 44)
	head.add_child(gear)
	var title := Kit.label("Настройки игры", 32, Art.TEXT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := preload("res://scripts/ui/round_button.gd").new()
	close.setup("close", "Закрыть", 60)
	close.pressed.connect(func(): closed.emit())
	head.add_child(close)
	_body.add_child(head)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	var col := Kit.vbox(10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	scroll.set_deferred("scroll_vertical", _scroll_pos)

	_section(col, "Управление")
	_choice(col, "Как ходить", "control", [["stick", "Джойстик"], ["dpad", "Крестовина"], ["tap", "Касанием"]])
	var hint := {
		"stick": "Держи палец на круге и веди куда нужно — в любую сторону, чем дальше, тем быстрее. Другим пальцем можно жать «Срубить».",
		"dpad": "Четыре стрелки на одном круге: палец можно переводить со стрелки на стрелку.",
		"tap": "Кнопок для ходьбы нет: нажми на клетку карты, и персонаж дойдёт сам.",
	}
	col.add_child(Kit.muted(hint[settings.control], 20))
	if settings.control != "tap":
		_choice(col, "Где джойстик", "pad_side", [["left", "Слева"], ["right", "Справа"]])
		_toggle(col, "Ходить нажатием на карту", "Нажал на клетку — дошёл сам, нажал на дерево — подошёл к нему", "tap_to_walk")
	_choice(col, "Скорость ходьбы", "speed", [["slow", "Спокойно"], ["normal", "Обычно"], ["fast", "Быстро"]])
	_choice(col, "Размер кнопок", "buttons", [["small", "Меньше"], ["normal", "Обычные"], ["large", "Крупнее"]])

	_section(col, "Звук")
	_toggle(col, "Звуки", "Шаги, топор, ягоды, ремесло, сон", "sound")
	_toggle(col, "Звуки леса", "Днём ветер и птицы, ночью сверчки", "ambience")
	if settings.sound or settings.ambience:
		_choice(col, "Громкость", "volume", [["quiet", "Тихо"], ["normal", "Средне"], ["loud", "Громко"]])
	_toggle(col, "Вибрация", "Лёгкий отклик, когда что-то собрал или построил", "vibration")

	_section(col, "Экран")
	_choice(col, "Как держать телефон", "landscape", [[false, "Вертикально"], [true, "Горизонтально"]])
	_toggle(col, "Показывать задачу", "Строка с подсказкой, что делать дальше", "show_goal")
	_toggle(col, "Рамка перед персонажем", "Подсвечивает клетку, к которой относится кнопка действия", "show_target")

	_section(col, "Мир")
	var stats := Kit.hbox(10)
	var gathered := 0
	for k in village.gathered:
		gathered += village.gathered[k]
	for pair in [["День", str(village.day())], ["Задачи", "%d/%d" % [village.goals_done.size(), Content.GOALS.size()]], ["Собрано", str(gathered)], ["Построек", str(village.built.size())]]:
		var box := Kit.vbox(0)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		var v := Kit.label(pair[1], 30, Art.TEXT, true)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var l := Kit.label(pair[0], 18, Art.MUTED)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(v)
		box.add_child(l)
		var c := Kit.card(box)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.add_child(c)
	col.add_child(stats)

	var danger := Button.new()
	danger.focus_mode = Control.FOCUS_NONE
	danger.custom_minimum_size = Vector2(0, 64)
	danger.text = "Точно? Нажми ещё раз — этот мир пропадёт" if _arming else "Начать новый мир"
	var bg := Art.ACCENT if _arming else Color(0, 0, 0, 0)
	danger.add_theme_stylebox_override("normal", Kit.box(bg, 18, Art.ACCENT))
	danger.add_theme_stylebox_override("hover", Kit.box(bg, 18, Art.ACCENT))
	danger.add_theme_stylebox_override("pressed", Kit.box(Art.ACCENT, 18, Art.ACCENT))
	danger.add_theme_color_override("font_color", Art.BG if _arming else Art.ACCENT)
	danger.add_theme_color_override("font_hover_color", Art.BG if _arming else Art.ACCENT)
	danger.pressed.connect(func():
		if _arming:
			_arming = false
			new_world.emit()
		else:
			# Новый мир — только со второго нажатия: одним случайным касанием месяцы игры
			# не стираются.
			_arming = true
			rebuild()
			get_tree().create_timer(4.0).timeout.connect(func():
				if _arming:
					_arming = false
					rebuild()))
	col.add_child(danger)
	col.add_child(Kit.muted("Новый лес, новая поляна, пустая сумка. Настройки остаются.", 20))
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 30)
	col.add_child(pad)


func _section(col: VBoxContainer, title: String) -> void:
	var l := Kit.label(title.to_upper(), 20, Art.GREEN, true)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 14)
	m.add_child(l)
	col.add_child(m)

func _choice(col: VBoxContainer, title: String, key: String, options: Array) -> void:
	var inner := Kit.vbox(10)
	inner.add_child(Kit.label(title, 24, Art.TEXT, true))
	var seg := Kit.hbox(6)
	for opt in options:
		var b := Button.new()
		b.text = opt[1]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = settings.get(key) == opt[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 56)
		b.add_theme_stylebox_override("normal", Kit.box(Art.BG, 14))
		b.add_theme_stylebox_override("hover", Kit.box(Art.BG, 14))
		b.add_theme_stylebox_override("pressed", Kit.box(Art.GREEN, 14))
		b.add_theme_stylebox_override("hover_pressed", Kit.box(Art.GREEN, 14))
		b.add_theme_color_override("font_color", Art.MUTED)
		b.add_theme_color_override("font_pressed_color", Art.BG)
		b.add_theme_color_override("font_hover_pressed_color", Art.BG)
		var value = opt[0]
		b.pressed.connect(func(): _apply(key, value))
		seg.add_child(b)
	inner.add_child(seg)
	col.add_child(Kit.card(inner))

func _toggle(col: VBoxContainer, title: String, hint: String, key: String) -> void:
	var row := Kit.hbox(12)
	var text := Kit.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(Kit.label(title, 24, Art.TEXT, true))
	text.add_child(Kit.muted(hint, 18))
	row.add_child(text)
	var sw := Switch.new()
	sw.on = settings.get(key)
	sw.toggled_to.connect(func(v): _apply(key, v))
	row.add_child(sw)
	col.add_child(Kit.card(row))


## Переключатель — свой, в цветах игры: встроенный тёмный на тёмном почти не виден.
class Switch:
	extends Button
	signal toggled_to(on: bool)
	var on := false

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(84, 48)
		pressed.connect(func(): toggled_to.emit(not on))

	func _draw() -> void:
		var r := Rect2(Vector2(0, 6), Vector2(84, 36))
		draw_style_box(Kit.box(Art.GREEN_DARK if on else Art.CARD_BORDER, 18, Color(0, 0, 0, 0), 0), r)
		draw_circle(Vector2(66 if on else 18, 24), 15, Art.GREEN if on else Art.MUTED)
