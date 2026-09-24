## Магазин: улучшения на весь вид за ДНК. Это не части — на тело их не ставят и пара для
## них не нужна: купил — и сразу работает. ДНК за покупку уходит насовсем.
extends Control

signal closed
signal bought(id: String)

const RoundButton := preload("res://scripts/ui/round_button.gd")
const DragScroll := preload("res://scripts/ui/drag_scroll.gd")

var evo: Evolution
var landscape := true
var _sheet: PanelContainer
var _body: VBoxContainer
var _scroll_pos := 0
var _note: Label
## Какую карточку только что купили — она вспыхивает.
var _flash_id := ""


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
	_sheet.add_theme_stylebox_override("panel", Kit.box(Art.BG, 0, Color(0, 0, 0, 0), 18))
	add_child(_sheet)
	_body = Kit.vbox(12)
	_sheet.add_child(_body)
	resized.connect(_place)

func open(e: Evolution, landscape_: bool) -> void:
	evo = e
	landscape = landscape_
	visible = true
	_scroll_pos = 0
	_flash_id = ""
	rebuild()
	Kit.pop_in(_sheet)

func _place() -> void:
	if landscape:
		_sheet.position = Vector2(size.x * 0.22, 0)
		_sheet.size = Vector2(size.x * 0.78, size.y)
	else:
		_sheet.position = Vector2(0, size.y * 0.08)
		_sheet.size = Vector2(size.x, size.y * 0.92)
	_sheet.pivot_offset = _sheet.size / 2.0

func rebuild() -> void:
	var old := _body.get_child(1) as ScrollContainer if _body.get_child_count() > 1 else null
	if old:
		_scroll_pos = old.scroll_vertical
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_place()

	var head := Kit.hbox(12)
	var icon := IconBox.new()
	icon.icon = "shop"
	icon.custom_minimum_size = Vector2(46, 46)
	head.add_child(icon)
	var title := Kit.label("Магазин", 32, Art.TEXT, true)
	head.add_child(title)
	var sub := Kit.muted("Улучшения на весь вид: не части, ставить не нужно — купил и работает", 18)
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sub)
	var dna := Kit.card(Kit.label("ДНК %d" % evo.dna_free() if not evo.sandbox else "ДНК без счёта", 22, Art.GREEN, true), Art.CARD, 16, 10)
	head.add_child(dna)
	var close := RoundButton.new()
	close.setup("close", "Закрыть", 60)
	close.pressed.connect(func(): closed.emit())
	head.add_child(close)
	_body.add_child(head)

	var scroll := DragScroll.new()
	_body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2 if landscape else 1
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	scroll.set_deferred("scroll_vertical", _scroll_pos)
	for id in Content.UPGRADES:
		grid.add_child(_card(id))
	_note = Kit.muted("ДНК за покупку уходит насовсем — в отличие от частей тела, которые можно снять и вернуть ДНК.", 17)
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(_note)

func _card(id: String) -> Control:
	var def: Dictionary = Content.UPGRADES[id]
	var lvl := evo.upgrade_level(id)
	var max_lvl: int = def.costs.size()
	var cost := evo.upgrade_cost(id)
	var row := Kit.hbox(14)
	var pic := UpgradeIcon.new()
	pic.icon = def.icon
	pic.have = lvl > 0
	pic.custom_minimum_size = Vector2(72, 72)
	row.add_child(pic)
	var text := Kit.vbox(4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(Kit.label(def.name, 23, Art.TEXT, true))
	text.add_child(Kit.muted(def.hint, 17))
	var dots := Dots.new()
	dots.have = lvl
	dots.total = max_lvl
	dots.custom_minimum_size = Vector2(0, 16)
	text.add_child(dots)
	row.add_child(text)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(150, 58)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 21)
	var can := cost >= 0 and cost <= evo.dna_free()
	if cost < 0:
		b.text = "Есть"
		b.disabled = true
	else:
		b.text = "%d ДНК" % cost
	var bg := Art.GREEN if can else Art.CARD_BORDER
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, Kit.box(bg if cost >= 0 else Color(0.2, 0.3, 0.28), 18))
	var fg := Art.BG if can else Art.MUTED
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(c, fg)
	b.pressed.connect(func(): _buy(id))
	Kit.press_fx(b)
	row.add_child(b)
	var card := Kit.card(row, Art.CARD, 20, 14)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if id == _flash_id:
		# Вспышка купленного: карточка светлеет, значок подпрыгивает.
		card.modulate = Color(1.6, 1.6, 1.3)
		var tw := card.create_tween()
		tw.tween_property(card, "modulate", Color.WHITE, 0.6)
		pic.jump = 1.0
	return card

func _buy(id: String) -> void:
	var out := evo.buy(id)
	if not out.ok:
		if _note:
			_note.text = out.message
			_note.add_theme_color_override("font_color", Art.ACCENT)
		bought.emit("")
		return
	_flash_id = id
	bought.emit(id)
	rebuild()


class IconBox:
	extends Control
	var icon := ""

	func _draw() -> void:
		draw_circle(size / 2.0, size.x / 2.0, Color(0.56, 0.82, 0.7, 0.15))
		Icons.draw(self, icon, Rect2(size * 0.2, size * 0.6), Art.GREEN)

## Значок улучшения: круг, при покупке подпрыгивает и разбрасывает искры.
class UpgradeIcon:
	extends Control
	var icon := ""
	var have := false
	var jump := 0.0
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		if jump > 0.0:
			jump = maxf(0.0, jump - delta * 1.4)
			queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var k := 1.0 + 0.3 * sin(PI * jump) * jump
		var r := size.x / 2.0 * k
		draw_circle(c, r, Color(0.56, 0.82, 0.7, 0.28) if have else Color(1, 1, 1, 0.06))
		if jump > 0.0:
			for i in 10:
				var d := Vector2.from_angle(TAU * i / 10.0 + t)
				var far := r * (1.0 + (1.0 - jump) * 0.8)
				draw_circle(c + d * far, 3.0 * jump, Color(Art.GOLD, jump))
		var s := r * 1.2
		Icons.draw(self, icon, Rect2(c - Vector2(s, s) / 2.0, Vector2(s, s)), Art.GREEN if have else Art.MUTED)

## Уровни: закрашенные точки — куплено.
class Dots:
	extends Control
	var have := 0
	var total := 1

	func _draw() -> void:
		for i in total:
			var at := Vector2(8 + i * 22, size.y / 2.0)
			draw_circle(at, 6, Art.GOLD if i < have else Color(1, 1, 1, 0.15))
