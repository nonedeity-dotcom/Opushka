## Всё, что поверх океана: размер и рост, ДНК, здоровье, задача, сообщения и кнопки.
##
## Раскладка считается от размера экрана, а не якорями: джойстик может стоять слева или
## справа, экран — лежать или стоять, и одна функция расставляет всё под любой случай.
extends Control

const TouchPad := preload("res://scripts/ui/touch_pad.gd")
const DashButton := preload("res://scripts/ui/dash_button.gd")
const RoundButton := preload("res://scripts/ui/round_button.gd")
const Indicators := preload("res://scripts/ui/indicators.gd")

## Какой значок и подпись у кнопки умения.
const ABILITY_LOOK := {"ink": ["ink", "Чернила"], "shield": ["shield", "Щит"], "pulse": ["pulse", "Разряд"], "suck": ["suck", "Втянуть"]}

signal dash_pressed
signal ability_pressed
signal editor_pressed
signal atlas_pressed
signal settings_pressed
signal shop_pressed

var pad: Control
var dash: Control
## Кнопка ♥ — позвать пару; через пару меняется тело.
var editor_btn: Button
var atlas_btn: Button
var settings_btn: Button
var shop_btn: Button
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
## Вспышка находки: крупный значок части посреди экрана.
var reveal: Control
## Второе умение (чернила, щит, разряд, всасывание) — есть, только если есть такая часть.
var ability_btn: Control
var biome_chip: Control
var boss_bar: Control
var arena_pill: Control

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

	settings_btn = _round("settings", "Настройки", 64)
	settings_btn.pressed.connect(func(): settings_pressed.emit())
	atlas_btn = _round("book", "Атлас", 64)
	atlas_btn.pressed.connect(func(): atlas_pressed.emit())
	shop_btn = _round("shop", "Магазин", 64)
	shop_btn.pressed.connect(func(): shop_pressed.emit())

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
	toast_box.visible = false
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
	banner.visible = false
	add_child(banner)

	pad = TouchPad.new()
	add_child(pad)
	dash = DashButton.new()
	dash.pressed.connect(func(): dash_pressed.emit())
	add_child(dash)
	ability_btn = DashButton.new()
	ability_btn.tint = Color(0.42, 0.34, 0.62, 0.95)
	ability_btn.visible = false
	ability_btn.pressed.connect(func(): ability_pressed.emit())
	add_child(ability_btn)
	biome_chip = BiomeChip.new()
	add_child(biome_chip)
	boss_bar = BossBar.new()
	boss_bar.visible = false
	add_child(boss_bar)
	arena_pill = ArenaPill.new()
	arena_pill.visible = false
	add_child(arena_pill)
	editor_btn = _round("heart", "Позвать пару", 92)
	editor_btn.accent = true
	editor_btn.pressed.connect(func(): editor_pressed.emit())

	reveal = PartReveal.new()
	reveal.hud = self
	add_child(reveal)

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
	for n in [pad, dash, ability_btn, editor_btn, settings_btn, atlas_btn, shop_btn]:
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
	dash.visible = pond.player.can_dash
	dash.set_cooldown(pond.player.dash_cd / (Pond.DASH_CD * pond.player.dash_k))
	var ab := pond.player.ability
	if ability_btn.visible != (ab != ""):
		ability_btn.visible = ab != ""
		_layout()
	if ab != "":
		var look: Array = ABILITY_LOOK.get(ab, ["dash", ab])
		if ability_btn.icon != look[0]:
			ability_btn.icon = look[0]
			ability_btn.caption = look[1]
			ability_btn.queue_redraw()
		ability_btn.set_cooldown(pond.player.ability_t / maxf(pond.player.ability_cd, 0.1))
	var b := pond.biome if pond.biome != "" else "shallows"
	var warn := ""
	if b == "hot" and not pond.player.heatproof:
		warn = "жжёт!"
	elif b == "cold" and not pond.player.coldproof:
		warn = "холодно"
	biome_chip.visible = pond.mode != "arena"
	biome_chip.set_state(b, warn)
	var boss := pond.boss_active
	boss_bar.visible = boss != null and boss.alive
	if boss_bar.visible:
		boss_bar.set_state(Content.SPECIES[boss.species].name, boss.hp / boss.max_hp, boss.phase_n)
	arena_pill.visible = pond.mode == "arena"
	if arena_pill.visible:
		arena_pill.set_state(pond.wave, pond.evo.arena_best)
	var goal := evo.current_goal()
	goal_card.visible = _settings != null and _settings.show_goal and not goal.is_empty() and pond.mode == "normal"
	editor_btn.visible = pond.mode != "arena"
	if goal_card.visible:
		var n := Content.GOALS.find(goal) + 1
		goal_title.text = "%s  ·  %d/%d" % [goal.title, n, Content.GOALS.size()]
		goal_hint.text = goal.hint
		goal_hint.visible = not _landscape
	hurt_flash.color.a = maxf(0.0, hurt_flash.color.a - get_process_delta_time() * 0.8)


## Новая часть: значок вспыхивает посреди экрана, потом улетает к ♥.
func reveal_part(id: String, level_up := false) -> void:
	reveal.start(id, level_up)

## Вырос: плашка размера подпрыгивает, экран на миг теплеет.
func grew() -> void:
	Kit.bounce(size_pill, 1.25)
	hurt_flash.color = Color(0.5, 0.95, 0.6, 0.22)
	var tw := create_tween()
	tw.tween_property(hurt_flash, "color", Color(0.8, 0.1, 0.1, 0.0), 0.8)

func hurt() -> void:
	hurt_flash.color = Color(0.8, 0.1, 0.1, hurt_flash.color.a)
	hurt_flash.color.a = 0.22

## Пришлось ли касание на что-то из интерфейса.
func covers(p: Vector2) -> bool:
	for n in [pad, dash, ability_btn, editor_btn, settings_btn, atlas_btn, shop_btn, size_pill, dna_pill, hp_bar, goal_card]:
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
	toast_box.visible = true
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_box, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(2.6)
	_toast_tween.tween_property(toast_box, "modulate:a", 0.0, 0.5)
	# Невидимое тоже рисуется, если не спрятать: прячем, когда растаяло.
	_toast_tween.tween_callback(func(): toast_box.visible = false)

## Крупная надпись посередине: вырос, новая часть.
func announce(title: String, sub := "") -> void:
	banner_title.text = title
	banner_sub.text = sub
	_layout_banner()
	if _banner_tween:
		_banner_tween.kill()
	banner.modulate.a = 0.0
	banner.visible = true
	banner.scale = Vector2(0.9, 0.9)
	_banner_tween = create_tween().set_parallel()
	_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_property(banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.chain().tween_interval(2.0)
	_banner_tween.chain().tween_property(banner, "modulate:a", 0.0, 0.6)
	_banner_tween.chain().tween_callback(func(): banner.visible = false)


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
	biome_chip.position = Vector2(left, top + 108)
	biome_chip.size = Vector2(hp_bar.size.x, 30)
	settings_btn.position = Vector2(right - 64, top)
	atlas_btn.position = Vector2(right - 64 * 2 - 10, top)
	shop_btn.position = Vector2(right - 64 * 3 - 20, top)
	if _landscape:
		goal_card.position = Vector2(dna_pill.position.x + dna_pill.size.x + 14, top)
		goal_card.size = Vector2(minf(560.0, shop_btn.position.x - goal_card.position.x - 14), 64)
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
	# Умение — над рывком, чуть меньше его.
	var ab_d := 112.0 * scale
	ability_btn.size = Vector2(ab_d, ab_d)
	ability_btn.position = Vector2(dash.position.x + (dash_d - ab_d) / 2.0 + toward_center * dash_d * 0.35, dash.position.y - ab_d - 44)
	var bw := minf(520.0, size.x * 0.4)
	boss_bar.size = Vector2(bw, 58)
	boss_bar.position = Vector2((size.x - bw) / 2.0, top + (76 if _landscape else 190))
	arena_pill.size = Vector2(300, 64)
	arena_pill.position = Vector2((size.x - 300) / 2.0, top)
	indicators.position = Vector2.ZERO
	indicators.size = size
	# Лёжа джойстик и кнопки — по углам: стрелкам хватает низа посередине.
	var low := 60.0 if _landscape else pad_d
	indicators.margin = Rect2(Vector2(left, top + 120), Vector2(right - left, bottom - top - 120 - low))
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

## Какая вода вокруг — и предупреждение, если в ней плохо.
class BiomeChip:
	extends Control
	var biome := "shallows"
	var warn := ""
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_state(b: String, w: String) -> void:
		if w != "":
			t += get_process_delta_time()
			queue_redraw()
		if b == biome and w == warn:
			return
		biome = b
		warn = w
		queue_redraw()

	func _draw() -> void:
		var def: Dictionary = Content.BIOMES[biome]
		var font := get_theme_default_font()
		var text: String = def.name
		var col := Color(def.top).lightened(0.45)
		draw_circle(Vector2(13, 15), 8, col)
		var pos := Vector2(30, 23)
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color(0, 0, 0, 0.6))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Art.TEXT)
		if warn != "":
			var x := 30 + font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 12
			var wc := Color(Art.DANGER if biome == "hot" else Color("#9fd8ff"), 0.7 + 0.3 * sin(t * 6.0))
			draw_string_outline(font, Vector2(x, 23), warn, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color(0, 0, 0, 0.6))
			draw_string(font, Vector2(x, 23), warn, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, wc)

## Хозяин логова: имя, здоровье и стадия боя.
class BossBar:
	extends Control
	var title := ""
	var k := 1.0
	var phase := 1

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_state(n: String, hp_k: float, ph: int) -> void:
		if n == title and absf(hp_k - k) < 0.003 and ph == phase:
			return
		title = n
		k = clampf(hp_k, 0.0, 1.0)
		phase = ph
		queue_redraw()

	func _draw() -> void:
		var font := get_theme_default_font()
		Icons.draw(self, "skull", Rect2(0, 0, 26, 26), Color("#c9a0ff"))
		var text := "%s  ·  стадия %d из 3" % [title, phase]
		draw_string_outline(font, Vector2(34, 21), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color(0, 0, 0, 0.6))
		draw_string(font, Vector2(34, 21), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Art.TEXT)
		var bar := Rect2(0, 32, size.x, 16)
		draw_style_box(Kit.box(Color(0, 0, 0, 0.55), 8, Color(1, 1, 1, 0.2), 2), bar)
		var col := Color("#b07ae0") if phase < 3 else Art.DANGER
		if k > 0.0:
			draw_style_box(Kit.box(col, 8, Color(0, 0, 0, 0), 0), Rect2(bar.position, Vector2(maxf(12.0, bar.size.x * k), bar.size.y)))
		for mark in [0.6, 0.3]:
			var x: float = bar.size.x * mark
			draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), Color(1, 1, 1, 0.45), 2)

## Арена: какая волна и лучший результат.
class ArenaPill:
	extends Control
	var wave := -1
	var best := 0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_state(w: int, b: int) -> void:
		if w == wave and b == best:
			return
		wave = w
		best = b
		queue_redraw()

	func _draw() -> void:
		draw_style_box(Kit.box(Color(0.05, 0.1, 0.13, 0.78), 32), Rect2(Vector2.ZERO, size))
		Icons.draw(self, "trophy", Rect2(16, 14, 36, 36), Art.GOLD)
		var font := get_theme_default_font()
		draw_string(font, Vector2(62, 32), "Волна %d" % maxi(wave, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Art.TEXT)
		draw_string(font, Vector2(62, 54), "рекорд: %d" % best, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Art.MUTED)


## Находка крупно: лучи, пружинящий значок, потом полёт к кнопке ♥ — там её и ставят.
class PartReveal:
	extends Control
	var hud: Control
	var id := ""
	var level_up := false
	var t := -1.0
	const SHOW := 1.5
	const FLY := 0.55

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func start(part: String, up: bool) -> void:
		id = part
		level_up = up
		t = 0.0

	func _process(delta: float) -> void:
		if t < 0.0:
			return
		t += delta
		if t > SHOW + FLY:
			t = -1.0
			if hud and hud.editor_btn.visible:
				Kit.bounce(hud.editor_btn, 1.3)
		queue_redraw()

	func _draw() -> void:
		if t < 0.0 or id == "":
			return
		var center := Vector2(size.x / 2.0, size.y * 0.55)
		var target: Vector2 = center
		if hud and hud.editor_btn.visible:
			target = hud.editor_btn.position + hud.editor_btn.size / 2.0
		var at := center
		var k := 1.0
		if t < 0.35:
			# Появление с перелётом через край: 0 → 1.2 → 1.
			var q := t / 0.35
			k = q * (1.0 + 0.35 * sin(PI * q))
		elif t > SHOW:
			var q := clampf((t - SHOW) / FLY, 0.0, 1.0)
			at = center.lerp(target, q * q)
			k = 1.0 - 0.75 * q
		var r := 64.0 * k
		var fade := 1.0 if t <= SHOW else 1.0 - (t - SHOW) / FLY
		if t <= SHOW:
			# Лучи вращаются, круг светится.
			var col := Art.GOLD if not level_up else Art.GREEN
			for i in 12:
				var a := TAU * i / 12.0 + t * 0.8
				var d := Vector2.from_angle(a)
				var side := d.orthogonal() * r * 0.18
				draw_colored_polygon(PackedVector2Array([at + d * r * 0.9 + side, at + d * r * 2.3, at + d * r * 0.9 - side]), Color(col, 0.22 * fade))
			draw_circle(at, r * 1.35, Color(col, 0.12 * fade))
			for i in 8:
				var a := TAU * i / 8.0 - t * 2.0
				var sp := at + Vector2.from_angle(a) * r * (1.5 + 0.2 * sin(t * 6.0 + i))
				draw_circle(sp, 3.0 + 2.0 * sin(t * 8.0 + i), Color(1, 1, 0.8, 0.8 * fade))
		draw_circle(at, r, Color(0.06, 0.12, 0.15, 0.92 * fade))
		draw_arc(at, r, 0, TAU, 48, Color(Art.GOLD if not level_up else Art.GREEN, fade), 4.0, true)
		CellArt.part_icon(self, id, Rect2(at - Vector2(r, r) * 0.75, Vector2(r, r) * 1.5), Color("#9fd4a0"), t, fade)
		if level_up and t <= SHOW:
			var font := get_theme_default_font()
			draw_string_outline(font, at + Vector2(r * 0.55, -r * 0.55), "+1", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 6, Color(0, 0, 0, 0.6))
			draw_string(font, at + Vector2(r * 0.55, -r * 0.55), "+1", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Art.GREEN)
