## Настройки игры. Всё меняется сразу, без кнопки «сохранить»: переключил управление —
## закрыл — играешь.
extends Control

signal closed
signal changed(settings: Settings)
signal new_world

var settings: Settings
var evo: Evolution
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


func open(s: Settings, e: Evolution, landscape_: bool) -> void:
	settings = s
	evo = e
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
	var gear := Gear.new()
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

	var scroll := preload("res://scripts/ui/drag_scroll.gd").new()
	_body.add_child(scroll)
	var col := Kit.vbox(10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	scroll.set_deferred("scroll_vertical", _scroll_pos)

	_section(col, "Управление")
	_choice(col, "Как плыть", "control", [["stick", "Джойстик"], ["follow", "За пальцем"]])
	var hint := {
		"stick": "Держи палец на круге и веди куда нужно — чем дальше от середины, тем быстрее. Другим пальцем жми «Рывок».",
		"follow": "Держи палец где угодно на экране — клетка плывёт к нему. «Рывок» — другим пальцем.",
	}
	col.add_child(Kit.muted(hint[settings.control], 20))
	if settings.control == "stick":
		_choice(col, "Где джойстик", "pad_side", [["left", "Слева"], ["right", "Справа"]])
	else:
		_choice(col, "Где «Рывок»", "pad_side", [["left", "Справа"], ["right", "Слева"]])
	_choice(col, "Размер кнопок", "buttons", [["small", "Меньше"], ["normal", "Обычные"], ["large", "Крупнее"]])

	_section(col, "Звук")
	_toggle(col, "Звуки", "Еда, укусы, находки, рост", "sound")
	_toggle(col, "Звуки воды", "Тихий гул глубины", "ambience")
	if settings.sound or settings.ambience:
		_choice(col, "Громкость", "volume", [["quiet", "Тихо"], ["normal", "Средне"], ["loud", "Громко"]])
	_toggle(col, "Вибрация", "Отклик на укусы, победы и находки", "vibration")

	_section(col, "Экран")
	_toggle(col, "Показывать задачу", "Строка с подсказкой, что делать дальше", "show_goal")
	_toggle(col, "Стрелки к находкам", "У края экрана — куда уплыла выпавшая часть; с глазками — откуда плывёт хищник", "arrows")

	_section(col, "Твой вид")
	var stats := Kit.hbox(10)
	for pair in [["Размер", str(evo.level())], ["Частей", "%d/%d" % [evo.unlocked.size(), Content.PARTS.size()]], ["Побед", str(evo.stats.get("kills", 0))], ["Задачи", "%d/%d" % [evo.goals_done.size(), Content.GOALS.size()]]]:
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
	danger.text = "Выйти в меню"
	danger.add_theme_stylebox_override("normal", Kit.box(Color(0, 0, 0, 0), 18, Art.GREEN_DARK))
	danger.add_theme_stylebox_override("hover", Kit.box(Color(0, 0, 0, 0), 18, Art.GREEN_DARK))
	danger.add_theme_stylebox_override("pressed", Kit.box(Art.GREEN_DARK, 18, Art.GREEN_DARK))
	danger.add_theme_color_override("font_color", Art.GREEN)
	danger.pressed.connect(func(): new_world.emit())
	col.add_child(danger)
	col.add_child(Kit.muted("Игра сохранится. В меню — три ячейки: можно начать новый вид с другой сложностью.", 20))
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

class Gear:
	extends Control

	func _draw() -> void:
		Icons.draw(self, "settings", Rect2(Vector2.ZERO, size), Art.GREEN)

