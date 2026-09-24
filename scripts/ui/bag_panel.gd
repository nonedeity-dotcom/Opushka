## Сумка: вещи плиткой и ремесло.
##
## Две вкладки, а не один длинный список: вещи смотрят часто и мельком, а ремесло — когда
## уже решил что-то делать. В рецепте у каждого ингредиента своя цифра «есть / нужно» и
## цвет — видно, чего именно не хватает, а не просто «мало».
extends Control

signal closed
signal eat(id: String)
signal place(id: String)
signal craft(id: String)
signal plant(id: String)

var village: Village
var landscape := false
var tab := "items"
var picked := ""

var _sheet: PanelContainer
var _body: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			closed.emit())
	add_child(shade)
	_sheet = PanelContainer.new()
	add_child(_sheet)
	_body = Kit.vbox(14)
	_sheet.add_child(_body)
	resized.connect(_place)


func open(v: Village, landscape_: bool) -> void:
	village = v
	landscape = landscape_
	visible = true
	rebuild()

func _place() -> void:
	if landscape:
		_sheet.position = Vector2(size.x * 0.46, 0)
		_sheet.size = Vector2(size.x * 0.54, size.y)
	else:
		_sheet.position = Vector2(0, size.y * 0.34)
		_sheet.size = Vector2(size.x, size.y * 0.66)

func rebuild() -> void:
	if village == null:
		return
	# Старое убираем сразу, а не в конце кадра: иначе прежняя ширина (сетка вещей, другая
	# вкладка) ещё держит лист и не даёт ему сузиться.
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_place()

	var head := Kit.hbox(10)
	var craftable := 0
	for r in Content.RECIPES:
		if village.can_craft(r).ok:
			craftable += 1
	head.add_child(_tab("Вещи", "items", ""))
	head.add_child(_tab("Ремесло", "craft", str(craftable) if craftable > 0 else ""))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var close := preload("res://scripts/ui/round_button.gd").new()
	close.setup("close", "Закрыть", 60)
	close.pressed.connect(func(): closed.emit())
	head.add_child(close)
	_body.add_child(head)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	if tab == "items":
		_items(scroll)
	else:
		_crafts(scroll)

func _tab(text: String, id: String, badge: String) -> Button:
	var b := Button.new()
	b.text = text + ("  " + badge if badge != "" else "")
	b.toggle_mode = true
	b.button_pressed = tab == id
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(170, 60)
	b.add_theme_stylebox_override("normal", Kit.box(Art.CARD, 30))
	b.add_theme_stylebox_override("pressed", Kit.box(Art.GREEN, 30))
	b.add_theme_stylebox_override("hover", Kit.box(Art.CARD, 30))
	b.add_theme_stylebox_override("hover_pressed", Kit.box(Art.GREEN, 30))
	b.add_theme_color_override("font_pressed_color", Art.BG)
	b.add_theme_color_override("font_hover_pressed_color", Art.BG)
	b.pressed.connect(func():
		tab = id
		rebuild())
	return b


# --- вещи -----------------------------------------------------------------------------

func _items(scroll: ScrollContainer) -> void:
	var col := Kit.vbox(14)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	var ids: Array = []
	for id in village.bag:
		if village.bag[id] > 0:
			ids.append(id)
	if ids.is_empty():
		col.add_child(Kit.muted("Пусто. Наступи на ветки и камешки на поляне — они сами лягут в сумку.", 22))
		return
	var grid := GridContainer.new()
	# Сколько плиток по 148 точек влезает в лист.
	grid.columns = maxi(2, int((_sheet.size.x - 44 + 12) / 160))
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	col.add_child(grid)
	for id in ids:
		var t := ItemTile.new()
		t.id = id
		t.count = village.water if id == "can" else village.bag[id]
		t.picked = id == picked
		t.pressed.connect(func():
			picked = "" if picked == id else id
			rebuild())
		grid.add_child(t)
	if picked != "" and village.bag.get(picked, 0) > 0:
		var item: Dictionary = Content.ITEMS[picked]
		var row := Kit.hbox(14)
		var icon := Icon.new()
		icon.item = picked
		icon.custom_minimum_size = Vector2(64, 64)
		row.add_child(icon)
		var text := Kit.vbox(2)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(Kit.label(item.name, 26, Art.TEXT, true))
		text.add_child(Kit.muted(item.hint, 20))
		row.add_child(text)
		if item.has("seed"):
			row.add_child(_button("Посадить", func(): plant.emit(picked)))
		if item.has("food"):
			row.add_child(_button("Съесть", func(): eat.emit(picked)))
		if item.has("places"):
			row.add_child(_button("Поставить", func(): place.emit(picked)))
		col.add_child(Kit.card(row, Art.CARD, 20, 14))
	else:
		col.add_child(Kit.muted("Нажми на вещь — там можно съесть, поставить или посадить. Постройка встаёт на клетку, к которой ты повернулся, семена — в грядку перед тобой.", 20))

func _button(text: String, on_press: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(0, 58)
	b.add_theme_stylebox_override("normal", Kit.box(Art.GREEN, 16))
	b.add_theme_stylebox_override("hover", Kit.box(Art.GREEN, 16))
	b.add_theme_stylebox_override("pressed", Kit.box(Art.GREEN_DARK, 16))
	b.add_theme_color_override("font_color", Art.BG)
	b.add_theme_color_override("font_hover_color", Art.BG)
	b.pressed.connect(on_press)
	return b


# --- ремесло --------------------------------------------------------------------------

func _crafts(scroll: ScrollContainer) -> void:
	var col := Kit.vbox(10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	for r in Content.RECIPES:
		var check := village.can_craft(r)
		var owned: bool = Content.ITEMS[r.makes].get("tool", false) and village.bag.get(r.makes, 0) > 0
		var row := Kit.hbox(14)
		var icon := Icon.new()
		icon.item = r.makes
		icon.custom_minimum_size = Vector2(72, 72)
		icon.plate = true
		row.add_child(icon)
		var text := Kit.vbox(8)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name: String = Content.ITEMS[r.makes].name
		if r.count > 1:
			name += " × %d" % r.count
		text.add_child(Kit.label(name, 26, Art.MUTED if owned else Art.TEXT, true))
		var needs := HFlowContainer.new()
		needs.add_theme_constant_override("h_separation", 8)
		needs.add_theme_constant_override("v_separation", 6)
		for id in r.needs:
			var chip := Chip.new()
			chip.item = id
			chip.text = "%d/%d" % [mini(village.bag.get(id, 0), 99), r.needs[id]]
			chip.color = Art.GREEN if village.bag.get(id, 0) >= r.needs[id] else Art.ACCENT
			needs.add_child(chip)
		if r.has("at"):
			var chip := Chip.new()
			chip.icon = "pin"
			chip.text = Content.STRUCTURES[r.at].near
			chip.color = Art.GREEN if village.near(r.at) else Art.MUTED
			needs.add_child(chip)
		text.add_child(needs)
		row.add_child(text)
		if owned:
			var done := Icon.new()
			done.icon = "check"
			done.custom_minimum_size = Vector2(44, 44)
			row.add_child(done)
		else:
			var rid: String = r.id
			row.add_child(_button("Сделать", func(): craft.emit(rid), check.ok))
		var bg := Art.CARD
		var c := Kit.card(row, bg, 20, 12)
		if check.ok:
			c.add_theme_stylebox_override("panel", Kit.box(bg, 20, Color(0.56, 0.72, 0.6, 0.45), 12))
		col.add_child(c)
	col.add_child(Kit.muted("Постройку ставят из «Вещей» — на клетку, к которой ты повернулся.", 20))


# --- мелкие части ---------------------------------------------------------------------

class ItemTile:
	extends Button
	var id := ""
	var count := 0
	var picked := false

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(148, 150)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(Kit.box(Art.CARD, 22, Art.GREEN if picked else Color(0, 0, 0, 0)), r)
		Art.item_icon(self, id, Rect2(size.x / 2 - 34, 20, 68, 68))
		var font := get_theme_default_font()
		var name: String = Content.ITEMS[id].name
		var w := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(font, Vector2((size.x - w) / 2, size.y - 20), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Art.MUTED)
		if id == "can" or not Content.ITEMS[id].get("tool", false):
			var t := "%d/%d" % [count, Content.CAN_SIZE] if id == "can" else str(count)
			var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			draw_style_box(Kit.box(Art.BG, 14, Color(0, 0, 0, 0), 0), Rect2(size.x - tw - 24, 8, tw + 16, 28))
			draw_string(font, Vector2(size.x - tw - 16, 29), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Art.TEXT)

class Icon:
	extends Control
	var item := ""
	var icon := ""
	var plate := false

	func _draw() -> void:
		if plate:
			draw_style_box(Kit.box(Art.BG, 16), Rect2(Vector2.ZERO, size))
		var inner := Rect2(size * 0.12, size * 0.76)
		if item != "":
			Art.item_icon(self, item, inner)
		elif icon != "":
			Icons.draw(self, icon, inner, Art.GREEN)

## «ветка 3/5» — значок и цифры, зелёные, если хватает.
class Chip:
	extends Control
	var item := ""
	var icon := ""
	var text := ""
	var color := Art.TEXT

	func _ready() -> void:
		var font := get_theme_default_font()
		custom_minimum_size = Vector2(44 + font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x, 36)

	func _draw() -> void:
		draw_style_box(Kit.box(Art.BG, 18, Color(0, 0, 0, 0), 0), Rect2(Vector2.ZERO, size))
		if item != "":
			Art.item_icon(self, item, Rect2(6, 5, 26, 26))
		else:
			Icons.draw(self, icon, Rect2(9, 8, 20, 20), color)
		draw_string(get_theme_default_font(), Vector2(36, 26), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color)
