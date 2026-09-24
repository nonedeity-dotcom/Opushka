## Всё, что поверх океана: размер и рост, ДНК, здоровье, задача, сообщения и кнопки.
##
## Раскладка считается от размера экрана, а не якорями: джойстик может стоять слева или
## справа, экран — лежать или стоять, и одна функция расставляет всё под любой случай.
extends Control

const TouchPad := preload("res://scripts/ui/touch_pad.gd")
const DashButton := preload("res://scripts/ui/dash_button.gd")
const RoundButton := preload("res://scripts/ui/round_button.gd")
const Indicators := preload("res://scripts/ui/indicators.gd")

signal dash_pressed
signal editor_pressed
signal settings_pressed
signal rotate_pressed

var pad: Control
var dash: Control
var editor_btn: Button
var rotate_btn: Button
var settings_btn: Button
var size_pill: Control
var dna_pill: Control
var hp_bar: Control
var goal_card: PanelContainer
var goal_title: Label
var goal_hint: Label
var toast_box: PanelContainer
var toast_label: Label
var banner: VBoxContainer
var banner_title: Label
var banner_sub: Label
var indicators: Control
var hurt_flash: ColorRect

var _settings: Settings
var _landscape := false
var _toast_tween: Tween
var _banner_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	hurt_flash = ColorRect.new()
	hurt_flash.color = Color(0.8, 0.1, 0.1, 0.0)
	hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hurt_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(hurt_flash)

	indicators = Indicators.new()
	add_child(indicators)

	size_pill = SizePill.new()
	add_child(size_pill)
	dna_pill = DnaPill.new()
	add_child(dna_pill)
	hp_bar = HpBar.new()
	add_child(hp_bar)

	rotate_btn = _round("rotate", "Повернуть экран", 64)
	rotate_btn.pressed.connect(func(): rotate_pressed.emit())
	settings_btn = _round("settings", "Настройки", 64)
	settings_btn.pressed.connect(func(): settings_pressed.emit())

	goal_title = Kit.label("", 22, Art.TEXT, true)
	goal_hint = Kit.label("", 18, Art.MUTED)
	goal_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var goal_text := Kit.vbox(0)
	goal_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goal_text.add_child(goal_title)
	goal_text.add_child(goal_hint)
	var goal_row := Kit.hbox(12)
	var flag := IconBox.new()
	flag.icon = "flag"
	flag.custom_minimum_size = Vector2(34, 34)
	goal_row.add_child(flag)
	goal_row.add_child(goal_text)
	goal_card = Kit.card(goal_row, Color(0.06, 0.1, 0.13, 0.82), 18, 14)
	goal_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(goal_card)

	toast_label = Kit.label("", 22)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_box = Kit.card(toast_label, Color(0.04, 0.07, 0.09, 0.88), 20, 16)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.modulate.a = 0.0
	add_child(toast_box)

	banner = Kit.vbox(4)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_title = Kit.label("", 48, Art.GOLD, true)
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub = Kit.label("", 24, Art.TEXT)
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for l in [banner_title, banner_sub]:
		l.add_theme_constant_override("outline_size", 8)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	banner.add_child(banner_title)
	banner.add_child(banner_sub)
	banner.modulate.a = 0.0
	add_child(banner)

	pad = TouchPad.new()
	add_child(pad)
	dash = DashButton.new()
	dash.pressed.connect(func(): dash_pressed.emit())
	add_child(dash)
	editor_btn = _round("dna", "Эволюция", 92)
	editor_btn.accent = true
	editor_btn.pressed.connect(func(): editor_pressed.emit())

	resized.connect(_layout)


func _round(icon: String, tip: String, px: float) -> Button:
	var b := RoundButton.new()
	b.setup(icon, tip, px)
	add_child(b)
	return b


func apply_settings(s: Settings, landscape: bool) -> void:
	_settings = s
	_landscape = landscape
	pad.visible = s.control == "stick"
	if not pad.visible:
		pad.release()
	for n in [pad, dash, editor_btn, rotate_btn, settings_btn]:
		n.floating = true
	indicators.enabled = s.arrows
	pad.queue_redraw()
	_layout()


## Показать то, что сейчас в океане.
func refresh(pond: Pond) -> void:
	var evo := pond.evo
	size_pill.set_state(evo.level(), evo.growth())
	dna_pill.set_value(evo.dna_free())
	hp_bar.set_state(pond.player.hp, pond.player.max_hp, pond.player.poison_t > 0.0)
	dash.set_cooldown(pond.player.dash_cd / Pond.DASH_CD)
	var goal := evo.current_goal()
	goal_card.visible = _settings != null and _settings.show_goal and not goal.is_empty()
	if goal_card.visible:
		var n := Content.GOALS.find(goal) + 1
		goal_title.text = "%s  ·  %d/%d" % [goal.title, n, Content.GOALS.size()]
		goal_hint.text = goal.hint
		goal_hint.visible = not _landscape
	hurt_flash.color.a = maxf(0.0, hurt_flash.color.a - get_process_delta_time() * 0.8)


func hurt() -> void:
	hurt_flash.color.a = 0.22

## Пришлось ли касание на что-то из интерфейса.
func covers(p: Vector2) -> bool:
	for n in [pad, dash, editor_btn, rotate_btn, settings_btn, size_pill, dna_pill, hp_bar, goal_card]:
		if n.visible and n.get_global_rect().grow(10).has_point(p):
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

## Крупная надпись посередине: вырос, новая часть.
func announce(title: String, sub := "") -> void:
	banner_title.text = title
	banner_sub.text = sub
	_layout_banner()
	if _banner_tween:
		_banner_tween.kill()
	banner.modulate.a = 0.0
	banner.scale = Vector2(0.9, 0.9)
	_banner_tween = create_tween().set_parallel()
	_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_property(banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.chain().tween_interval(2.0)
	_banner_tween.chain().tween_property(banner, "modulate:a", 0.0, 0.6)


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

	size_pill.position = Vector2(left, top)
	dna_pill.position = Vector2(left + size_pill.size.x + 10, top)
	hp_bar.position = Vector2(left, top + 74)
	hp_bar.size = Vector2(size_pill.size.x + 10 + dna_pill.size.x, 26)
	settings_btn.position = Vector2(right - 64, top)
	rotate_btn.position = Vector2(right - 64 * 2 - 10, top)
	if _landscape:
		goal_card.position = Vector2(dna_pill.position.x + dna_pill.size.x + 14, top)
		goal_card.size = Vector2(minf(560.0, rotate_btn.position.x - goal_card.position.x - 14), 64)
	else:
		goal_card.position = Vector2(left, top + 112)
		goal_card.size = Vector2(right - left, 0)

	var pad_d := (250.0 if _landscape else 270.0) * scale
	var dash_d := 150.0 * scale
	pad.size = Vector2(pad_d, pad_d)
	dash.size = Vector2(dash_d, dash_d)
	var pad_right := _settings.pad_side == "right"
	pad.position = Vector2(right - pad_d if pad_right else left, bottom - pad_d)
	dash.position = Vector2(left if pad_right else right - dash_d, bottom - dash_d - 40)
	var e := 92.0 * scale
	editor_btn.custom_minimum_size = Vector2(e, e)
	editor_btn.size = editor_btn.custom_minimum_size
	var toward_center := 1.0 if dash.position.x < size.x / 2.0 else -1.0
	editor_btn.position = Vector2(dash.position.x + (dash_d + 20 if toward_center > 0 else -e - 20), dash.position.y + dash_d - e)
	indicators.position = Vector2.ZERO
	indicators.size = size
	indicators.margin = Rect2(Vector2(left, top + 120), Vector2(right - left, bottom - top - 120 - pad_d))
	_layout_toast()
	_layout_banner()

func _layout_toast() -> void:
	var w := minf(size.x - 60, 600.0)
	toast_label.custom_minimum_size.x = w - 32
	toast_box.reset_size()
	var above := dash.position.y - 30.0 if dash else size.y - 300.0
	toast_box.position = Vector2((size.x - w) / 2.0, above - toast_box.size.y - 16)

func _layout_banner() -> void:
	var w := minf(size.x - 40, 680.0)
	banner_sub.custom_minimum_size.x = w
	banner.reset_size()
	banner.size.x = w
	banner.pivot_offset = banner.size / 2.0
	banner.position = Vector2((size.x - w) / 2.0, size.y * (0.2 if _landscape else 0.26))


# --- части ----------------------------------------------------------------------------

## «Размер 3» и полоска роста до следующего.
class SizePill:
	extends Control
	var level := 0
	var growth := -1.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(210, 64)

	func set_state(l: int, g: float) -> void:
		if l == level and absf(g - growth) < 0.004:
			return
		level = l
		growth = g
		queue_redraw()

	func _draw() -> void:
		draw_style_box(Kit.box(Color(0.05, 0.1, 0.13, 0.72), 32), Rect2(Vector2.ZERO, size))
		var font := get_theme_default_font()
		draw_string(font, Vector2(22, 34), "Размер %d" % level, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Art.TEXT)
		var bar := Rect2(22, 44, size.x - 44, 8)
		draw_style_box(Kit.box(Color(1, 1, 1, 0.1), 4, Color(0, 0, 0, 0), 0), bar)
		if growth > 0.0:
			draw_style_box(Kit.box(Art.GREEN, 4, Color(0, 0, 0, 0), 0), Rect2(bar.position, Vector2(maxf(8.0, bar.size.x * growth), bar.size.y)))

## Свободная ДНК.
class DnaPill:
	extends Control
	var value := -99999

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(150, 64)

	func set_value(v: int) -> void:
		if v != value:
			value = v
			queue_redraw()

	func _draw() -> void:
		draw_style_box(Kit.box(Color(0.05, 0.1, 0.13, 0.72), 32), Rect2(Vector2.ZERO, size))
		Icons.draw(self, "dna", Rect2(16, 14, 36, 36), Art.GREEN)
		draw_string(get_theme_default_font(), Vector2(62, 42), str(value), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Art.TEXT)

## Здоровье: сердечко и полоса. Отравлен — полоса зеленеет.
class HpBar:
	extends Control
	var hp := -1.0
	var max_hp := 1.0
	var poisoned := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_state(h: float, m: float, p: bool) -> void:
		if absf(h - hp) < 0.05 and m == max_hp and p == poisoned:
			return
		hp = h
		max_hp = m
		poisoned = p
		queue_redraw()

	func _draw() -> void:
		Icons.draw(self, "heart", Rect2(0, 0, 26, 26), Art.DANGER)
		var bar := Rect2(34, 7, size.x - 34, 12)
		draw_style_box(Kit.box(Color(0, 0, 0, 0.45), 6, Color(0, 0, 0, 0), 0), bar)
		var k := clampf(hp / max_hp, 0.0, 1.0)
		var col := Color("#8fe070") if poisoned else (Art.DANGER if k < 0.3 else Color("#e8a0a0"))
		if k > 0.0:
			draw_style_box(Kit.box(col, 6, Color(0, 0, 0, 0), 0), Rect2(bar.position, Vector2(maxf(10.0, bar.size.x * k), bar.size.y)))

class IconBox:
	extends Control
	var icon := ""

	func _draw() -> void:
		draw_circle(size / 2.0, size.x / 2.0, Color(0.56, 0.82, 0.7, 0.15))
		Icons.draw(self, icon, Rect2(size * 0.22, size * 0.56), Art.GREEN)
