## «Эволюция»: редактор твоей клетки и атлас видов.
##
## Тело: выбираешь часть внизу, ведёшь пальцем по краю клетки — видно, куда она встанет, —
## отпускаешь. Нажал на часть на клетке — её можно убрать, ДНК вернётся. Цвет, зеркальная
## установка, имя вида.
## Атлас: кого встречал, кто чем опасен и что роняет — с шансами.
extends Control

signal closed
signal changed

const RoundButton := preload("res://scripts/ui/round_button.gd")

var evo: Evolution
var landscape := false
var tab := "body"
var selected := ""
var picked := -1
var mirror := false
var _sheet: PanelContainer
var _root: VBoxContainer
var _info: Label
var _info_row: HBoxContainer
var _preview: Preview


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet = PanelContainer.new()
	_sheet.add_theme_stylebox_override("panel", Kit.box(Art.BG, 0, Color(0, 0, 0, 0), 20))
	add_child(_sheet)
	_root = Kit.vbox(12)
	_sheet.add_child(_root)
	resized.connect(_place)


func open(e: Evolution, landscape_: bool) -> void:
	evo = e
	landscape = landscape_
	selected = ""
	picked = -1
	visible = true
	rebuild()

func _place() -> void:
	_sheet.position = Vector2.ZERO
	_sheet.size = size

func rebuild() -> void:
	if evo == null:
		return
	for c in _root.get_children():
		_root.remove_child(c)
		c.queue_free()
	_place()
	_root.add_child(_header())
	var tabs := Kit.hbox(10)
	tabs.add_child(_tab("Тело", "body"))
	tabs.add_child(_tab("Атлас", "atlas"))
	var chips := Kit.hbox(8)
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.alignment = BoxContainer.ALIGNMENT_END
	chips.add_child(_chip("ДНК %d" % evo.dna_free(), Art.GREEN))
	chips.add_child(_chip("Части %d/%d" % [evo.body.size(), evo.slots()], Art.TEXT))
	tabs.add_child(chips)
	_root.add_child(tabs)
	if tab == "body":
		_body_tab()
	else:
		_atlas_tab()


func _header() -> HBoxContainer:
	var head := Kit.hbox(12)
	var icon := IconBox.new()
	icon.icon = "dna"
	icon.custom_minimum_size = Vector2(48, 48)
	head.add_child(icon)
	var title := Kit.label("Эволюция", 32, Art.TEXT, true)
	head.add_child(title)
	# Имя вида — прямо в заголовке, нажал и пишешь.
	var name_edit := LineEdit.new()
	name_edit.text = evo.name
	name_edit.max_length = 18
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.add_theme_font_size_override("font_size", 22)
	name_edit.add_theme_color_override("font_color", Art.MUTED)
	name_edit.add_theme_stylebox_override("normal", Kit.box(Color(1, 1, 1, 0.04), 14, Color(0, 0, 0, 0), 10))
	name_edit.add_theme_stylebox_override("focus", Kit.box(Color(1, 1, 1, 0.08), 14, Art.GREEN_DARK, 10))
	name_edit.tooltip_text = "Имя твоего вида"
	name_edit.text_changed.connect(func(t):
		if t.strip_edges() != "":
			evo.name = t.strip_edges()
			changed.emit())
	head.add_child(name_edit)
	var done := RoundButton.new()
	done.setup("check", "Готово", 64)
	done.accent = true
	done.pressed.connect(func(): closed.emit())
	head.add_child(done)
	return head

func _tab(text: String, id: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = tab == id
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(140, 54)
	b.add_theme_stylebox_override("normal", Kit.box(Art.CARD, 27))
	b.add_theme_stylebox_override("hover", Kit.box(Art.CARD, 27))
	b.add_theme_stylebox_override("pressed", Kit.box(Art.GREEN, 27))
	b.add_theme_stylebox_override("hover_pressed", Kit.box(Art.GREEN, 27))
	b.add_theme_color_override("font_pressed_color", Art.BG)
	b.add_theme_color_override("font_hover_pressed_color", Art.BG)
	b.pressed.connect(func():
		tab = id
		selected = ""
		picked = -1
		rebuild())
	return b

func _chip(text: String, col: Color) -> PanelContainer:
	return Kit.card(Kit.label(text, 20, col, true), Art.CARD, 16, 10)


# --- тело -----------------------------------------------------------------------------

func _body_tab() -> void:
	_preview = Preview.new()
	_preview.editor = self
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info = Kit.muted("", 20)
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_row = Kit.hbox(10)
	_info_row.add_child(_info)
	var palette := _palette()
	var tools := _tools()
	var stats := _stats()
	if landscape:
		var cols := Kit.hbox(16)
		cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var left := Kit.vbox(10)
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.size_flags_stretch_ratio = 0.9
		left.add_child(_preview)
		left.add_child(stats)
		var right := Kit.vbox(10)
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.add_child(_info_row)
		right.add_child(tools)
		right.add_child(palette)
		cols.add_child(left)
		cols.add_child(right)
		_root.add_child(cols)
	else:
		_preview.custom_minimum_size = Vector2(0, size.y * 0.3)
		_preview.size_flags_vertical = Control.SIZE_FILL
		_root.add_child(_preview)
		_root.add_child(stats)
		_root.add_child(_info_row)
		_root.add_child(tools)
		_root.add_child(palette)
	_update_info()

## Что умеет тело сейчас — в цифрах, чтобы было видно, что даёт каждая часть.
func _stats() -> HFlowContainer:
	var c := Creature.of_player(evo)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	var diet: String = {"plant": "Травоядный", "meat": "Хищник", "both": "Всеядный", "": "Не ест!"}[evo.diet()]
	flow.add_child(_chip(diet, Art.DANGER if evo.diet() == "" else Art.GOLD))
	flow.add_child(_chip("Скорость %d" % c.speed, Art.TEXT))
	flow.add_child(_chip("Здоровье %d" % c.max_hp, Art.TEXT))
	var attack := float(c.mouth.get("bite", 0.0))
	for s in c.spikes:
		attack = maxf(attack, s.dmg)
	if attack > 0.0:
		flow.add_child(_chip("Урон %.0f" % attack if attack >= 10.0 else "Урон %.1f" % attack, Art.TEXT))
	var armor := 0.0
	for s in c.shells:
		armor = maxf(armor, s.armor)
	if armor > 0.0:
		flow.add_child(_chip("Защита %d%%" % int(armor * 100.0), Art.TEXT))
	if not c.glands.is_empty():
		flow.add_child(_chip("Яд", Color("#8fe070")))
	if c.zap > 0.0:
		flow.add_child(_chip("Ток", Color("#f2e05a")))
	if c.eyes > 0.0:
		flow.add_child(_chip("Зрение +%d%%" % int(minf(c.eyes, 4.0) * 30.0), Art.TEXT))
	if c.regen > 0.0:
		flow.add_child(_chip("Свет", Color("#8ad07a")))
	return flow

func _tools() -> HBoxContainer:
	var row := Kit.hbox(10)
	var mir := Button.new()
	mir.toggle_mode = true
	mir.button_pressed = mirror
	mir.focus_mode = Control.FOCUS_NONE
	mir.text = "Зеркально"
	mir.custom_minimum_size = Vector2(0, 52)
	mir.add_theme_font_size_override("font_size", 20)
	mir.add_theme_stylebox_override("normal", Kit.box(Art.CARD, 26))
	mir.add_theme_stylebox_override("hover", Kit.box(Art.CARD, 26))
	mir.add_theme_stylebox_override("pressed", Kit.box(Art.GREEN_DARK, 26))
	mir.add_theme_stylebox_override("hover_pressed", Kit.box(Art.GREEN_DARK, 26))
	mir.tooltip_text = "Ставить часть сразу с двух сторон"
	mir.toggled.connect(func(on): mirror = on)
	row.add_child(mir)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	for i in Content.COLORS.size():
		var sw := Swatch.new()
		sw.color = Color(Content.COLORS[i])
		sw.on = evo.color == i
		sw.pressed.connect(func():
			evo.color = i
			changed.emit()
			rebuild())
		row.add_child(sw)
	return row

func _palette() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	# Сначала открытые — по порядку справочника, потом закрытые.
	var ids: Array = Content.PARTS.keys()
	ids.sort_custom(func(a, b): return int(evo.unlocked.has(a)) > int(evo.unlocked.has(b)))
	for id in ids:
		var tile := PartTile.new()
		tile.id = id
		tile.level = evo.unlocked.get(id, 0)
		tile.progress = float(evo.shards.get(id, 0)) / Evolution.copies_for(tile.level) if tile.level > 0 else 0.0
		tile.color = Color(Content.COLORS[evo.color])
		tile.picked = selected == id
		tile.cheap = int(Content.PARTS[id].cost) <= evo.dna_free()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.pressed.connect(func():
			selected = "" if selected == id else id
			picked = -1
			for t in grid.get_children():
				t.picked = t.id == selected
				t.queue_redraw()
			_update_info())
		grid.add_child(tile)
	return scroll

func _update_info() -> void:
	if _info == null:
		return
	for c in _info_row.get_children():
		if c != _info:
			_info_row.remove_child(c)
			c.queue_free()
	_info.add_theme_color_override("font_color", Art.MUTED)
	if picked >= 0 and picked < evo.body.size():
		var id: String = evo.body[picked].id
		var def: Dictionary = Content.PARTS[id]
		_info.text = "%s, ур. %d — %s" % [def.name, evo.unlocked.get(id, 1), def.hint.to_lower()]
		var off := Button.new()
		off.text = "Убрать +%d" % def.cost
		off.focus_mode = Control.FOCUS_NONE
		off.custom_minimum_size = Vector2(0, 52)
		off.add_theme_font_size_override("font_size", 20)
		off.add_theme_stylebox_override("normal", Kit.box(Color(0.5, 0.2, 0.2, 0.6), 16))
		off.add_theme_stylebox_override("hover", Kit.box(Color(0.5, 0.2, 0.2, 0.6), 16))
		off.pressed.connect(func():
			var out := evo.remove(picked)
			picked = -1
			changed.emit()
			rebuild()
			_say(out.message))
		_info_row.add_child(off)
	elif selected != "":
		var def: Dictionary = Content.PARTS[selected]
		if evo.unlocked.has(selected):
			var lvl: int = evo.unlocked[selected]
			var up := "" if lvl >= Content.PART_MAX_LEVEL else ", копий к следующему %d/%d" % [evo.shards.get(selected, 0), Evolution.copies_for(lvl)]
			_info.text = "%s (ур. %d%s) · %d ДНК — %s. Веди пальцем по краю клетки и отпусти." % [def.name, lvl, up, def.cost, def.hint.to_lower()]
		else:
			_info.text = "%s — ещё не найдена. %s" % [def.name, where_to_get(selected)]
	else:
		_info.text = "Выбери часть внизу и веди пальцем по краю клетки. Нажми на часть на клетке — её можно убрать."

## «Выпадает из: Колючка (30%)» — только из тех, кого уже встречал.
func where_to_get(id: String) -> String:
	var known: Array = []
	var unknown := 0
	for src in Content.sources(id):
		if evo.seen.has(src[0]):
			known.append("%s (%d%%)" % [Content.SPECIES[src[0]].name, int(round(src[1] * 100.0))])
		else:
			unknown += 1
	if known.is_empty():
		return "Выпадает из тех, кого ты ещё не встречал."
	return "Выпадает из: %s%s." % [", ".join(known), " и не только" if unknown > 0 else ""]

func _say(text: String) -> void:
	if _info:
		_info.text = text
		_info.add_theme_color_override("font_color", Art.TEXT)

## Нажали на край клетки в редакторе (угол от носа, градусы).
func place_at(angle: float) -> void:
	if selected == "" or not evo.unlocked.has(selected):
		return
	var out := evo.place(selected, int(round(angle)), mirror)
	if out.ok:
		changed.emit()
		rebuild()
	_say(out.message)
	if not out.ok and _info:
		_info.add_theme_color_override("font_color", Art.ACCENT)

func pick(index: int) -> void:
	picked = index
	selected = ""
	_update_info()
	if _preview:
		_preview.queue_redraw()


# --- атлас ----------------------------------------------------------------------------

func _atlas_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var col := Kit.vbox(10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	_root.add_child(scroll)
	var ids: Array = Content.SPECIES.keys()
	ids.sort_custom(func(a, b): return Content.SPECIES[a].levels[0] * 100 + Content.SPECIES[a].radius < Content.SPECIES[b].levels[0] * 100 + Content.SPECIES[b].radius)
	var hidden := 0
	for id in ids:
		if not evo.seen.has(id):
			hidden += 1
			continue
		col.add_child(_species_card(id))
	var total := Content.SPECIES.size()
	var line := "Встречено видов: %d из %d." % [total - hidden, total]
	if hidden > 0:
		line += " Остальные живут глубже — подрасти, и они появятся."
	col.add_child(Kit.muted(line, 20))

func _species_card(id: String) -> PanelContainer:
	var def: Dictionary = Content.SPECIES[id]
	var row := Kit.hbox(14)
	var mini := Mini.new()
	mini.species = id
	mini.custom_minimum_size = Vector2(96, 96)
	row.add_child(mini)
	var text := Kit.vbox(4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var kind: String = {"grazer": "мирный", "skittish": "пугливый", "drifter": "дрейфует", "hunter": "хищник", "boss": "великан"}[def.behavior]
	text.add_child(Kit.label("%s · %s" % [def.name, kind], 24, Art.DANGER if def.behavior == "hunter" or def.get("hunts", false) else Art.TEXT, true))
	text.add_child(Kit.muted(def.hint, 18))
	text.add_child(Kit.muted("Размеры %d–%d · побед: %d" % [def.levels[0], def.levels[1], evo.kills_by.get(id, 0)], 18))
	var drops := HFlowContainer.new()
	drops.add_theme_constant_override("h_separation", 8)
	drops.add_theme_constant_override("v_separation", 6)
	for d in def.drops:
		var chip := DropChip.new()
		chip.part = d[0]
		chip.chance = d[1]
		chip.have = evo.unlocked.has(d[0])
		drops.add_child(chip)
	text.add_child(drops)
	row.add_child(text)
	return Kit.card(row, Art.CARD, 20, 12)


# --- мелкие части ---------------------------------------------------------------------

## Клетка крупно. Касание края — поставить выбранную часть; касание части — выбрать её.
class Preview:
	extends Control
	var editor
	var t := 0.0
	var ghost := INF  # угол, куда встанет часть, пока палец на экране

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _radius() -> float:
		return minf(size.x, size.y) * 0.27

	func _angle_at(p: Vector2) -> float:
		# Нос клетки смотрит вверх: угол от носа = угол точки + 90°.
		return rad_to_deg(wrapf((p - size / 2.0).angle() + PI / 2.0, -PI, PI))

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				if editor.selected != "":
					ghost = _angle_at(e.position)
				else:
					editor.pick(_part_at(e.position))
			elif ghost != INF:
				var a := ghost
				ghost = INF
				editor.place_at(a)
			accept_event()
		elif e is InputEventMouseMotion and ghost != INF:
			ghost = _angle_at(e.position)
			accept_event()

	func _part_at(p: Vector2) -> int:
		var r := _radius()
		var best := -1
		var best_d := r * 0.5
		for i in editor.evo.body.size():
			var a := deg_to_rad(editor.evo.body[i].a) - PI / 2.0
			var d := p.distance_to(size / 2.0 + Vector2.from_angle(a) * r)
			if d < best_d:
				best_d = d
				best = i
		return best

	func _draw() -> void:
		var evo: Evolution = editor.evo
		var c := size / 2.0
		var r := _radius()
		draw_circle(c, r * 1.9, Color(0.07, 0.13, 0.17))
		if editor.selected != "":
			for i in 24:
				var a := TAU * i / 24.0
				draw_circle(c + Vector2.from_angle(a) * r * 1.02, 2.0, Color(1, 1, 1, 0.25))
		var col := Color(Content.COLORS[evo.color])
		CellArt.creature(self, c, r, -PI / 2.0, col, evo.body_parts(), t, {"pick": editor.picked, "shadow": false})
		# Нос — маленькая стрелка сверху, чтобы было видно, где перёд.
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 1.75), c + Vector2(-9, -r * 1.55), c + Vector2(9, -r * 1.55)]), Color(1, 1, 1, 0.35))
		if ghost != INF and editor.selected != "":
			var snapped := Evolution.snap(ghost)
			var ok: bool = evo.can_place(editor.selected, snapped).ok
			var tint := Color("#8fe0a0") if ok else Color("#e07070")
			CellArt.creature(self, c, r, -PI / 2.0, Color(tint, 0.0), [{"id": editor.selected, "a": deg_to_rad(snapped), "lvl": evo.unlocked.get(editor.selected, 1)}], t, {"ghost": 0.75, "shadow": false})
			var at := c + Vector2.from_angle(deg_to_rad(snapped) - PI / 2.0) * r * 1.35
			draw_circle(at, 8, tint)

## Плитка части в палитре: значок, имя, цена, уровень.
class PartTile:
	extends Button
	var id := ""
	var level := 0
	var color := Color.WHITE
	var picked := false
	var cheap := true
	var progress := 0.0  # копии к следующему уровню, 0–1

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(150, 156)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var have := level > 0
		draw_style_box(Kit.box(Art.CARD if have else Color(0.08, 0.1, 0.12), 20, Art.GOLD if picked else Color(0, 0, 0, 0)), r)
		var icon := Rect2(size.x / 2.0 - 40, 8, 80, 80)
		CellArt.part_icon(self, id, icon, color if have else Color("#3a4450"), 0.0, 1.0 if have else 0.35)
		var font := get_theme_default_font()
		var def: Dictionary = Content.PARTS[id]
		var name: String = def.name
		var fs := 18 if name.length() < 12 else 15
		var w := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2((size.x - w) / 2.0, 108), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.TEXT if have else Art.MUTED)
		if have:
			var cost := "%d ДНК" % def.cost
			var cw := font.get_string_size(cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(font, Vector2((size.x - cw) / 2.0, 130), cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Art.GREEN if cheap else Art.ACCENT)
			for i in Content.PART_MAX_LEVEL:
				var x := size.x / 2.0 + (i - 2) * 13.0
				draw_circle(Vector2(x, 144), 4, Art.GOLD if i < level else Color(1, 1, 1, 0.15))
				# Следующая точка заполняется по мере того, как копятся копии.
				if i == level and progress > 0.0:
					draw_circle(Vector2(x, 144), 4.0 * progress, Color(Art.GOLD, 0.7))
		else:
			Icons.draw(self, "lock", Rect2(size.x / 2.0 - 11, 120, 22, 22), Art.MUTED)

class Swatch:
	extends Button
	var color := Color.WHITE
	var on := false

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(44, 52)

	func _draw() -> void:
		var c := size / 2.0
		draw_circle(c, 17, color)
		if on:
			draw_arc(c, 21, 0, TAU, 32, Art.GOLD, 3, true)

class IconBox:
	extends Control
	var icon := ""

	func _draw() -> void:
		draw_circle(size / 2.0, size.x / 2.0, Color(0.56, 0.82, 0.7, 0.15))
		Icons.draw(self, icon, Rect2(size * 0.2, size * 0.6), Art.GREEN)

## Маленький портрет вида для атласа.
class Mini:
	extends Control
	var species := ""
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var def: Dictionary = Content.SPECIES[species]
		var parts: Array = []
		for p in def.parts:
			parts.append({"id": p[0], "a": deg_to_rad(p[1]), "lvl": p[2]})
		draw_circle(size / 2.0, size.x / 2.0, Color(0.07, 0.13, 0.17))
		var r := size.x * 0.24
		CellArt.creature(self, size / 2.0 + Vector2(r * 0.25, 0), r, PI, Color(def.color), parts, t, {"shadow": false})

## «шип 30%» — часть, которую роняет вид, и шанс.
class DropChip:
	extends Control
	var part := ""
	var chance := 0.0
	var have := false

	func _text() -> String:
		return "%s %d%%" % [Content.PARTS[part].name, int(round(chance * 100.0))]

	func _ready() -> void:
		var w := get_theme_default_font().get_string_size(_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		custom_minimum_size = Vector2(56 + w, 40)

	func _draw() -> void:
		draw_style_box(Kit.box(Art.BG, 20, Art.GREEN_DARK if have else Color(0, 0, 0, 0), 0), Rect2(Vector2.ZERO, size))
		CellArt.part_icon(self, part, Rect2(6, 4, 32, 32), Color("#9aa4b0"))
		draw_string(get_theme_default_font(), Vector2(44, 27), _text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Art.GREEN if have else Art.GOLD)
