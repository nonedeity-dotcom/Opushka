## Всё, что поверх мира: день и время, сытость, задача, сообщения, вещи и кнопки.
##
## Раскладка считается от размера экрана, а не якорями: джойстик может стоять слева или
## справа, экран — лежать или стоять, и одна функция расставляет всё под любой случай.
extends Control

const TouchPad := preload("res://scripts/ui/touch_pad.gd")
const ActionButton := preload("res://scripts/ui/action_button.gd")
const RoundButton := preload("res://scripts/ui/round_button.gd")

signal act_pressed
signal bag_pressed
signal settings_pressed
signal rotate_pressed
signal eat_pressed
signal pickup_pressed
signal pad_moved(vector: Vector2)

var pad: Control
var action: Control
var bag_btn: Button
var eat_btn: Button
var pickup_btn: Button
var rotate_btn: Button
var settings_btn: Button
var day_pill: Control
var food_pill: Control
var goal_card: PanelContainer
var goal_title: Label
var goal_hint: Label
var toast_box: PanelContainer
var toast_label: Label
var hotbar: Button

var _settings: Settings
var _landscape := false
var _toast_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	day_pill = DayPill.new()
	add_child(day_pill)
	food_pill = FoodPill.new()
	add_child(food_pill)

	rotate_btn = _round("rotate", "Повернуть экран", 64)
	rotate_btn.pressed.connect(func(): rotate_pressed.emit())
	settings_btn = _round("settings", "Настройки", 64)
	settings_btn.pressed.connect(func(): settings_pressed.emit())

	goal_title = Kit.label("", 22, Art.TEXT, true)
	goal_hint = Kit.label("", 18, Art.MUTED)
	var goal_text := Kit.vbox(0)
	goal_text.add_child(goal_title)
	goal_text.add_child(goal_hint)
	var goal_row := Kit.hbox(12)
	var flag := IconBox.new()
	flag.icon = "flag"
	flag.color = Art.GREEN
	flag.custom_minimum_size = Vector2(34, 34)
	goal_row.add_child(flag)
	goal_row.add_child(goal_text)
	goal_card = Kit.card(goal_row, Color(0.11, 0.125, 0.157, 0.9), 18, 14)
	goal_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(goal_card)

	toast_label = Kit.label("", 22)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_box = Kit.card(toast_label, Color(0.07, 0.08, 0.1, 0.88), 20, 16)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.modulate.a = 0.0
	add_child(toast_box)

	hotbar = Hotbar.new()
	hotbar.pressed.connect(func(): bag_pressed.emit())
	add_child(hotbar)

	pad = TouchPad.new()
	pad.moved.connect(func(v): pad_moved.emit(v))
	add_child(pad)

	action = ActionButton.new()
	action.pressed.connect(func(): act_pressed.emit())
	add_child(action)

	bag_btn = _round("bag", "Сумка", 76)
	bag_btn.pressed.connect(func(): bag_pressed.emit())
	eat_btn = _round("", "Съесть ягоды", 76)
	eat_btn.item = "berries"
	eat_btn.pressed.connect(func(): eat_pressed.emit())
	pickup_btn = _round("undo", "Разобрать", 76)
	pickup_btn.pressed.connect(func(): pickup_pressed.emit())

	resized.connect(_layout)


func _round(icon: String, tip: String, px: float) -> Button:
	var b := RoundButton.new()
	b.setup(icon, tip, px)
	add_child(b)
	return b


func apply_settings(s: Settings, landscape: bool) -> void:
	_settings = s
	_landscape = landscape
	pad.mode = "dpad" if s.control == "dpad" else "stick"
	pad.visible = s.control != "tap"
	if not pad.visible:
		pad.release()
	for n in [pad, action, bag_btn, eat_btn, pickup_btn, rotate_btn, settings_btn]:
		n.floating = landscape
	pad.queue_redraw()
	_layout()


## Показать то, что сейчас в мире.
func refresh(v: Village) -> void:
	day_pill.set_time(v.day(), v.clock(), v.is_night(), _landscape)
	food_pill.set_food(v.food, _landscape)
	action.floating = _landscape
	action.set_action(v.action_label(), v.action_icon())
	var goal := v.current_goal()
	goal_card.visible = _settings != null and _settings.show_goal and not goal.is_empty()
	if goal_card.visible:
		var n := Content.GOALS.find(goal) + 1
		goal_title.text = "%s  ·  %d/%d" % [goal.title, n, Content.GOALS.size()]
		goal_hint.text = goal.hint
		goal_hint.visible = not _landscape
	var berries: int = v.bag.get("berries", 0)
	eat_btn.visible = berries > 0 and v.food < 90.0
	eat_btn.badge = str(berries)
	eat_btn.queue_redraw()
	var target_cell := v.cell(v.target())
	pickup_btn.visible = not target_cell.is_empty() and target_cell.built != ""
	hotbar.set_items(v.bag, _landscape)
	_layout_side()


## Пришлось ли касание на что-то из интерфейса — тогда это не касание карты.
func covers(p: Vector2) -> bool:
	for n in [pad, action, bag_btn, eat_btn, pickup_btn, rotate_btn, settings_btn, day_pill, food_pill, goal_card, hotbar]:
		if n.visible and n.get_global_rect().grow(8).has_point(p):
			return true
	return false


func toast(text: String) -> void:
	if text == "":
		return
	toast_label.text = text
	_layout_toast()
	if _toast_tween:
		_toast_tween.kill()
	toast_box.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_box, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(2.6)
	_toast_tween.tween_property(toast_box, "modulate:a", 0.0, 0.5)


# --- раскладка ------------------------------------------------------------------------

func _safe() -> Rect2:
	# Вырез камеры и закруглённые углы: безопасная зона экрана, переведённая в наши точки.
	var win := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if win.x <= 0 or safe.size.x <= 0:
		return Rect2(Vector2.ZERO, size)
	var k := size / win
	return Rect2(safe.position * k, safe.size * k)

func _layout() -> void:
	if _settings == null or size.x <= 0:
		return
	var safe := _safe()
	var m := 18.0
	var left := maxf(safe.position.x, 0) + m
	var right := minf(safe.end.x, size.x) - m
	var top := maxf(safe.position.y, 0) + m
	var bottom := minf(safe.end.y, size.y) - m
	var scale: float = Settings.BUTTON_SCALE[_settings.buttons]

	# Верх: день, сытость; справа — поворот и настройки.
	day_pill.position = Vector2(left, top)
	food_pill.position = Vector2(left + day_pill.size.x + 10, top)
	settings_btn.position = Vector2(right - 64, top)
	rotate_btn.position = Vector2(right - 64 * 2 - 10, top)
	var goal_w := minf(size.x - left * 2, 560.0)
	if _landscape:
		goal_card.position = Vector2(food_pill.position.x + food_pill.size.x + 14, top)
		goal_card.size = Vector2(minf(goal_w, rotate_btn.position.x - goal_card.position.x - 14), 64)
	else:
		goal_card.position = Vector2(left, top + 76)
		goal_card.size = Vector2(right - left, 0)

	# Низ: джойстик с одной стороны, кнопка действия — с другой.
	var pad_d := (260.0 if _landscape else 280.0) * scale
	var act_d := 150.0 * scale
	pad.size = Vector2(pad_d, pad_d)
	action.size = Vector2(act_d, act_d)
	var pad_right := _settings.pad_side == "right"
	var pad_x := right - pad_d if pad_right else left
	var act_x := left if pad_right else right - act_d
	pad.position = Vector2(pad_x, bottom - pad_d)
	action.position = Vector2(act_x, bottom - act_d - 44)
	if _settings.control == "tap":
		action.position.x = right - act_d if not pad_right else left
	for b in [bag_btn, eat_btn, pickup_btn]:
		b.custom_minimum_size = Vector2(76, 76) * scale
		b.size = b.custom_minimum_size
	_layout_side()

	_layout_toast()

## Маленькие кнопки — столбиком рядом с кнопкой действия, со стороны середины экрана.
func _layout_side() -> void:
	if _settings == null:
		return
	var toward_center := 1.0 if action.position.x < size.x / 2.0 else -1.0
	var d := bag_btn.size.x
	var x := action.position.x + (action.size.x + 18 if toward_center > 0 else -d - 18)
	var y := action.position.y + action.size.y - d
	var top := minf(pad.position.y if pad.visible else size.y, action.position.y)
	for b in [bag_btn, eat_btn, pickup_btn]:
		if not b.visible:
			continue
		b.position = Vector2(x, y)
		top = minf(top, y)
		y -= d + 14

	# Вещи — посередине: лёжа — у нижнего края, стоя — над всеми кнопками. Ширина полоски
	# меняется с каждой новой вещью, поэтому место считается здесь, каждый кадр.
	var bottom := size.y - 18
	var y_bar := bottom - hotbar.size.y if _landscape else top - hotbar.size.y - 20
	var new_pos := Vector2(roundf((size.x - hotbar.size.x) / 2.0), y_bar)
	if new_pos != hotbar.position:
		hotbar.position = new_pos
		_layout_toast()

func _layout_toast() -> void:
	var w := minf(size.x - 60, 600.0)
	# Перенос строк считается от ширины подписи: без неё каждое слово встало бы в свою строку.
	toast_label.custom_minimum_size.x = w - 32
	toast_box.reset_size()
	var above := hotbar.position.y if hotbar.visible and hotbar.position.y > 0 else size.y - 360
	toast_box.position = Vector2((size.x - w) / 2.0, above - toast_box.size.y - 16)


# --- части ----------------------------------------------------------------------------

## Плашка «солнце/луна · День 3 · 14:20».
class DayPill:
	extends Control
	var day := 1
	var clock := ""
	var night := false
	var floating := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(230, 64)

	func set_time(d: int, c: String, n: bool, f: bool) -> void:
		if d == day and c == clock and n == night and f == floating:
			return
		day = d
		clock = c
		night = n
		floating = f
		queue_redraw()

	func _draw() -> void:
		var bg := Color(0.07, 0.08, 0.1, 0.62) if floating else Art.CARD
		draw_style_box(Kit.box(bg, 32), Rect2(Vector2.ZERO, size))
		Icons.draw(self, "moon" if night else "sun", Rect2(18, 18, 28, 28), Color("#b9c4e8") if night else Art.GOLD)
		var font := get_theme_default_font()
		draw_string(font, Vector2(58, 42), "День %d" % day, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Art.TEXT)
		draw_string(font, Vector2(152, 42), clock, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Art.MUTED)

## Плашка сытости: ягода и полоска.
class FoodPill:
	extends Control
	var food := 100.0
	var floating := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(150, 64)

	func set_food(f: float, fl: bool) -> void:
		if absf(f - food) < 0.5 and fl == floating:
			return
		food = f
		floating = fl
		queue_redraw()

	func _draw() -> void:
		var bg := Color(0.07, 0.08, 0.1, 0.62) if floating else Art.CARD
		draw_style_box(Kit.box(bg, 32), Rect2(Vector2.ZERO, size))
		Art.item_icon(self, "berries", Rect2(14, 16, 32, 32))
		var bar := Rect2(56, 28, 78, 10)
		draw_style_box(Kit.box(Color(1, 1, 1, 0.1), 5, Color(0, 0, 0, 0), 0), bar)
		var fill := Rect2(bar.position, Vector2(maxf(6.0, bar.size.x * food / 100.0), bar.size.y))
		draw_style_box(Kit.box(Art.ACCENT if food < 25 else Art.GREEN, 5, Color(0, 0, 0, 0), 0), fill)

## Значок в строке — для флажка задачи.
class IconBox:
	extends Control
	var icon := ""
	var color := Art.TEXT

	func _draw() -> void:
		draw_circle(size / 2.0, size.x / 2.0, Color(0.56, 0.72, 0.6, 0.15))
		Icons.draw(self, icon, Rect2(size * 0.22, size * 0.56), color)

## Полоска вещей из сумки: значки с числами. Нажатие открывает сумку.
class Hotbar:
	extends Button
	var items: Array = []
	var floating := false

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		visible = false

	func set_items(bag: Dictionary, f: bool) -> void:
		var list: Array = []
		for id in bag:
			if bag[id] > 0:
				list.append([id, bag[id]])
		floating = f
		if str(list) == str(items):
			return
		items = list
		visible = not items.is_empty()
		var shown := mini(items.size(), 7)
		custom_minimum_size = Vector2(shown * 86 + 24, 64)
		size = custom_minimum_size
		queue_redraw()

	func _draw() -> void:
		var bg := Color(0.07, 0.08, 0.1, 0.62) if floating else Art.CARD
		draw_style_box(Kit.box(bg, 32), Rect2(Vector2.ZERO, size))
		var font := get_theme_default_font()
		var x := 18.0
		for i in mini(items.size(), 7):
			var id: String = items[i][0]
			Art.item_icon(self, id, Rect2(x, 14, 36, 36))
			if not Content.ITEMS[id].get("tool", false):
				draw_string(font, Vector2(x + 40, 42), str(items[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Art.TEXT)
			x += 86
