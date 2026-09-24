## «Эволюция»: редактор твоей клетки и атлас видов.
##
## Два режима тела:
## «Части» — выбираешь часть справа, ведёшь пальцем по клетке — видно, куда она встанет, —
## отпускаешь. Шипы, рты, жгутики встают на край; глаз, хлоропласт и электроклетку можно
## поставить куда угодно внутрь, хоть в самую середину. Нажал на часть на клетке — её можно
## убрать, ДНК вернётся.
## «Форма» — ведёшь пальцем по клетке: тянешь наружу — край вытягивается, внутрь —
## втягивается. Готовые формы, сглаживание, цвет.
## Атлас: кого встречал, кто чем опасен и что роняет — с шансами.
## Родословная: каким был вид в каждом поколении. Достижения: что уже получено и сколько
## осталось, и вся коллекция.
extends Control

signal closed
signal changed
## Песочница: призвать существо этого вида рядом.
signal summon(species: String)

const RoundButton := preload("res://scripts/ui/round_button.gd")
const DragScroll := preload("res://scripts/ui/drag_scroll.gd")

const TOO_SMALL := "Меньше не сжать: стоящие части в таком теле не поместятся. Сначала сними лишние."
const PRESETS := [["round", "Круг"], ["oval", "Овал"], ["drop", "Капля"], ["wide", "Широкий"], ["star", "Звезда"], ["bean", "Боб"], ["blob", "Клякса"]]

var evo: Evolution
var landscape := true
var tab := "body"
var mode := "parts"
var selected := ""
var picked := -1
var mirror := true
## Что показывать в атласе: all, calm, danger, giant, rock.
var atlas_filter := "all"
## Тело можно менять только после встречи с парой; из «Атласа» — только смотреть.
var editable := true
var _sheet: PanelContainer
var _root: VBoxContainer
var _info: Label
var _info_title: Label
var _info_row: HBoxContainer
var _preview: Preview
var _palette_scroll: ScrollContainer
## Пока тянул форму, упёрся: меньше нельзя — скажем, когда отпустит палец.
var _blocked := false
## Список частей: какой вид показывать и только ли найденные.
var part_kind := "all"
var only_found := false
## Кисть формы (градусы), видны ли части на клетке, клетка крупно (без панели справа).
var brush := 40.0
var parts_shown := true
var big := false
## Отмена и возврат: снимки тела до изменений.
var _undo: Array = []
var _redo: Array = []
var _stats_box: HFlowContainer
var _palette_grid: GridContainer
var _clear_arm := false
## Перетаскивание из списка: номер пальца, откуда, что тащим, где сейчас.
var _carry_idx := -1
var _carry_from := Vector2.ZERO
var _carry_id := ""
var carrying := false
var carry_pos := Vector2.ZERO
var _carry_layer: Control
## Только что поставленные части: «id|угол|глубина» → сколько ещё длится их появление (0–1).
var pops := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet = PanelContainer.new()
	_sheet.add_theme_stylebox_override("panel", Kit.box(Art.BG, 0, Color(0, 0, 0, 0), 18))
	add_child(_sheet)
	_root = Kit.vbox(10)
	_sheet.add_child(_root)
	_carry_layer = CarryLayer.new()
	_carry_layer.editor = self
	add_child(_carry_layer)
	resized.connect(_place)


func open(e: Evolution, landscape_: bool, editable_ := true) -> void:
	evo = e
	landscape = landscape_
	editable = editable_
	tab = "body" if editable else "atlas"
	selected = ""
	picked = -1
	_undo.clear()
	_redo.clear()
	_clear_arm = false
	carrying = false
	_carry_idx = -1
	big = false
	parts_shown = mode == "parts"
	visible = true
	rebuild()
	Kit.pop_in(_sheet)

func _place() -> void:
	_sheet.position = Vector2.ZERO
	_sheet.size = size

func rebuild() -> void:
	if evo == null:
		return
	var keep_scroll := _palette_scroll.scroll_vertical if is_instance_valid(_palette_scroll) else 0
	for c in _root.get_children():
		_root.remove_child(c)
		c.queue_free()
	_palette_scroll = null
	_place()
	_root.add_child(_header())
	match tab:
		"body":
			_body_tab()
			if _palette_scroll:
				_palette_scroll.set_deferred("scroll_vertical", keep_scroll)
		"tree":
			_tree_tab()
		"awards":
			_awards_tab()
		_:
			_atlas_tab()


func _header() -> HBoxContainer:
	var head := Kit.hbox(12)
	var icon := IconBox.new()
	icon.icon = "dna"
	icon.custom_minimum_size = Vector2(48, 48)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(icon)
	# Имя вида — как заголовок: нажал и пишешь. Под ним — поколение.
	var names := Kit.vbox(0)
	var name_edit := LineEdit.new()
	name_edit.text = evo.name
	name_edit.max_length = 18
	name_edit.placeholder_text = "Имя вида"
	name_edit.custom_minimum_size = Vector2(250, 40)
	name_edit.add_theme_font_size_override("font_size", 26)
	name_edit.add_theme_color_override("font_color", Art.TEXT)
	name_edit.add_theme_stylebox_override("normal", Kit.box(Color(1, 1, 1, 0.0), 12, Color(0, 0, 0, 0), 6))
	name_edit.add_theme_stylebox_override("focus", Kit.box(Color(1, 1, 1, 0.08), 12, Art.GREEN_DARK, 6))
	name_edit.tooltip_text = "Имя твоего вида — нажми, чтобы сменить"
	name_edit.text_changed.connect(func(t):
		if t.strip_edges() != "":
			evo.name = t.strip_edges())
	name_edit.focus_exited.connect(func(): changed.emit())
	names.add_child(name_edit)
	var sub := Kit.label("поколение %d · размер %d · нажми на имя, чтобы сменить" % [evo.generation, evo.level()], 15, Art.MUTED)
	sub.add_theme_constant_override("line_spacing", 0)
	names.add_child(sub)
	head.add_child(names)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var tabs := Kit.segmented([["body", "Тело"], ["atlas", "Атлас"], ["tree", "Родословная"], ["awards", "Достижения"]], tab, func(id):
		tab = id
		selected = ""
		picked = -1
		rebuild(), 21, 56)
	tabs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tabs)
	var done := RoundButton.new()
	done.setup("check", "Готово", 60)
	done.accent = true
	done.pressed.connect(func(): closed.emit())
	head.add_child(done)
	return head

func _toggle(text: String, on: bool, action: Callable, h := 52.0) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = on
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_font_size_override("font_size", 22)
	for st in ["normal", "hover"]:
		b.add_theme_stylebox_override(st, Kit.box(Art.CARD, 26, Color(0, 0, 0, 0), 18))
	for st in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, Kit.box(Art.GREEN, 26, Color(0, 0, 0, 0), 18))
	b.add_theme_color_override("font_pressed_color", Art.BG)
	b.add_theme_color_override("font_hover_pressed_color", Art.BG)
	b.pressed.connect(action)
	Kit.press_fx(b)
	return b

func _chip(text: String, col: Color) -> PanelContainer:
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", Kit.box(Color(1, 1, 1, 0.05), 18, Color(1, 1, 1, 0.08), 12))
	c.add_child(Kit.label(text, 19, col, true))
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	return c


# --- тело -----------------------------------------------------------------------------

## Ширина кисти формы в градусах: узкая тянет почти одну точку, широкая — полбока.
const BRUSHES := [["22", "Узкая"], ["40", "Средняя"], ["70", "Широкая"]]
const KINDS := [["all", "Все"], ["mouth", "Рот"], ["weapon", "Оружие"], ["defense", "Защита"], ["move", "Движение"], ["sense", "Чувства"], ["special", "Особое"]]

func _body_tab() -> void:
	var cols := Kit.hbox(16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(cols)

	var left := Kit.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.85
	var top := Kit.hbox(8)
	top.add_child(Kit.info_chip("dna", "%d ДНК" % evo.dna_free() if not evo.sandbox else "ДНК без счёта", Art.GREEN))
	var free_slots := evo.slots() - evo.body.size()
	top.add_child(Kit.info_chip("plus", "Места %d/%d" % [evo.body.size(), evo.slots()], Art.GOLD if free_slots > 0 else Art.MUTED))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	if editable:
		var undo := _small_round("undo", "Отменить", func(): _undo_step(-1))
		undo.disabled = _undo.is_empty()
		undo.modulate.a = 0.4 if undo.disabled else 1.0
		top.add_child(undo)
		var redo := _small_round("redo", "Вернуть", func(): _undo_step(1))
		redo.disabled = _redo.is_empty()
		redo.modulate.a = 0.4 if redo.disabled else 1.0
		top.add_child(redo)
	var eye := _small_round("eye" if parts_shown else "eye_off", "Части: видно" if parts_shown else "Части скрыты", func():
		parts_shown = not parts_shown
		rebuild())
	top.add_child(eye)
	top.add_child(_small_round("shrink" if big else "expand", "Обычно" if big else "Крупно", func():
		big = not big
		rebuild()))
	left.add_child(top)
	_preview = Preview.new()
	_preview.editor = self
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_preview)
	_stats_box = HFlowContainer.new()
	_stats_box.add_theme_constant_override("h_separation", 8)
	_stats_box.add_theme_constant_override("v_separation", 8)
	# Крупно — только клетка; для формы — узкая колонка инструментов справа.
	if not big:
		left.add_child(_stats_box)
	cols.add_child(left)

	if big:
		if mode == "shape" and editable:
			var side := _shape_quick(true)
			side.custom_minimum_size.x = 330
			cols.add_child(side)
		_update_info()
		return
	var right := Kit.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var modes := Kit.hbox(8)
	modes.add_child(Kit.segmented([["parts", "Части"], ["shape", "Форма и цвет"]], mode, func(id):
		mode = id
		selected = ""
		picked = -1
		# Форму удобнее тянуть без частей — они прячутся; вернулся к частям — видны.
		parts_shown = id == "parts"
		rebuild()))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modes.add_child(spacer)
	var mir := _toggle("Зеркально", mirror, func(): pass)
	mir.tooltip_text = "Ставить части и тянуть форму сразу с двух сторон"
	mir.toggled.connect(func(on):
		mirror = on
		if _preview:
			_preview.queue_redraw())
	modes.add_child(mir)
	right.add_child(modes)
	_info = Kit.muted("", 19)
	_info_row = Kit.hbox(12)
	var info_card := Kit.card(_info_row, Color(1, 1, 1, 0.035), 18, 12)
	info_card.custom_minimum_size = Vector2(0, 78)
	right.add_child(info_card)
	if not editable:
		right.add_child(Kit.muted("Сейчас — только посмотреть. Менять тело можно после встречи с парой: нажми ♥ в игре.", 17))
	if mode == "parts":
		var kinds := Kit.segmented(KINDS, part_kind, func(id):
			part_kind = id
			rebuild(), 16, 44)
		right.add_child(kinds)
		var row := Kit.hbox(8)
		var found := _toggle("Только найденные", only_found, func(): pass, 44)
		found.add_theme_font_size_override("font_size", 17)
		found.toggled.connect(func(on):
			only_found = on
			rebuild())
		row.add_child(found)
		var sp2 := Control.new()
		sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sp2)
		if editable and not evo.body.is_empty():
			var clear := _toggle("Снять всё?" if _clear_arm else "Снять всё", _clear_arm, func(): pass, 44)
			clear.add_theme_font_size_override("font_size", 17)
			for st in ["pressed", "hover_pressed"]:
				clear.add_theme_stylebox_override(st, Kit.box(Color(0.62, 0.22, 0.22), 22, Color(0, 0, 0, 0), 18))
			clear.toggled.connect(func(_on):
				if _clear_arm:
					_remember()
					var out := evo.clear_body()
					_clear_arm = false
					picked = -1
					changed.emit()
					rebuild()
					_say(out.message)
				else:
					_clear_arm = true
					rebuild()
					_say("Нажми ещё раз — снимутся все части, ДНК вернётся. Передумал — «↶» вернёт всё обратно."))
			row.add_child(clear)
		right.add_child(row)
		right.add_child(_palette())
	elif editable:
		right.add_child(_shape_tools())
	cols.add_child(right)
	_update_info()

func _small_round(icon: String, tip: String, action: Callable) -> Button:
	var b := RoundButton.new()
	b.setup(icon, tip, 46)
	b.pressed.connect(action)
	return b

## Что умеет тело — в цифрах. Если выбрана часть — сразу «было → станет».
func _numbers(body_: Array) -> Dictionary:
	var keep: Array = evo.body
	evo.body = body_
	var c := Creature.of_player(evo)
	var diet := evo.diet()
	evo.body = keep
	var attack := float(c.mouth.get("bite", 0.0))
	for s in c.spikes:
		attack = maxf(attack, s.dmg)
	var armor := 0.0
	for s in c.shells:
		armor = maxf(armor, s.armor)
	return {"diet": diet, "speed": c.speed, "hp": c.max_hp, "attack": attack, "armor": armor, "eyes": c.eyes,
		"poison": not c.glands.is_empty(), "zap": c.zap > 0.0, "light": c.regen > 0.0}

## Каким стало бы тело: с выбранной частью (на месте примерки или сбоку) или без взятой.
func _what_if() -> Array:
	if picked >= 0 and picked < evo.body.size():
		var out: Array = evo.body.duplicate(true)
		out.remove_at(picked)
		return out
	if selected == "" or not evo.unlocked.has(selected):
		return []
	var a := 90
	var d := 1.0
	if _preview and not _preview.ghost.is_empty():
		a = Evolution.snap(_preview.ghost.a)
		d = Evolution.snap_depth(selected, _preview.ghost.d)
	var out: Array = evo.body.duplicate(true)
	if Content.is_mouth(selected):
		out = out.filter(func(p): return not Content.is_mouth(p.id))
		a = 0
	out.append({"id": selected, "a": a, "d": d})
	if mirror and not Content.is_mouth(selected) and a != 0 and absi(a) != 180 and d > 0.0:
		out.append({"id": selected, "a": -a, "d": d})
	return out

func _refresh_stats() -> void:
	if _stats_box == null or not is_instance_valid(_stats_box):
		return
	for ch in _stats_box.get_children():
		_stats_box.remove_child(ch)
		ch.queue_free()
	var now := _numbers(evo.body)
	var alt := _what_if()
	var then := _numbers(alt) if not alt.is_empty() or picked >= 0 else now
	var names := {"plant": "Травоядный", "meat": "Хищник", "both": "Всеядный", "": "Не ест!"}
	var diet_text: String = names[now.diet]
	if then.diet != now.diet:
		diet_text += " → " + names[then.diet]
	_stats_box.add_child(_chip(diet_text, Art.DANGER if then.diet == "" else Art.GOLD))
	for row in [["Скорость", "speed", "%d"], ["Здоровье", "hp", "%d"], ["Урон", "attack", "%.1f"], ["Защита", "armor", "pct"]]:
		var a: float = now[row[1]]
		var b: float = then[row[1]]
		if a <= 0.0 and b <= 0.0:
			continue
		var fmt := func(v: float) -> String:
			return "%d%%" % int(v * 100.0) if row[2] == "pct" else (row[2] % v)
		var text: String = "%s %s" % [row[0], fmt.call(a)]
		var col := Art.TEXT
		if absf(b - a) > 0.05:
			text += " → " + fmt.call(b)
			col = Color("#8fe0a0") if b > a else Art.ACCENT
		_stats_box.add_child(_chip(text, col))
	var sight := func(e: float) -> String:
		return "только рядом" if e <= 0.0 else ("почти весь экран" if e < 2.0 else "весь экран")
	var s_text: String = "Обзор: " + sight.call(now.eyes)
	if sight.call(then.eyes) != sight.call(now.eyes):
		s_text += " → " + sight.call(then.eyes)
	_stats_box.add_child(_chip(s_text, Art.TEXT if now.eyes > 0.0 else Art.MUTED))
	for extra in [["poison", "Яд", Color("#8fe070")], ["zap", "Ток", Color("#f2e05a")], ["light", "Свет", Color("#8ad07a")]]:
		if now[extra[0]] or then[extra[0]]:
			var gone: bool = now[extra[0]] and not then[extra[0]]
			var new: bool = then[extra[0]] and not now[extra[0]]
			_stats_box.add_child(_chip(extra[1] + (" → нет" if gone else (" (будет)" if new else "")), Art.ACCENT if gone else extra[2]))

## Список частей: фильтр по виду и «только найденные».
func _palette() -> ScrollContainer:
	var scroll := DragScroll.new()
	_palette_scroll = scroll
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	_palette_grid = grid
	# Сначала открытые — по порядку справочника, потом закрытые.
	var ids: Array = Content.PARTS.keys().filter(func(id): return Content.obtainable(id))
	ids = ids.filter(func(id):
		var k: String = Content.PARTS[id].get("kind", "special")
		if k == "ability":
			k = "special"
		return (part_kind == "all" or k == part_kind) and (not only_found or evo.unlocked.has(id)))
	ids.sort_custom(func(a, b): return int(evo.unlocked.has(a)) > int(evo.unlocked.has(b)))
	for id in ids:
		var tile := PartTile.new()
		tile.id = id
		tile.level = evo.unlocked.get(id, 0)
		tile.progress = float(evo.shards.get(id, 0)) / Evolution.copies_for(tile.level) if tile.level > 0 else 0.0
		tile.color = Color(Content.COLORS[evo.color])
		tile.picked = selected == id
		tile.cheap = int(Content.PARTS[id].cost) <= evo.dna_free()
		tile.on_body = evo.body.filter(func(p): return p.id == id).size()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.pressed.connect(func(): _select(id))
		grid.add_child(tile)
	if ids.is_empty():
		grid.add_child(Kit.muted("Таких частей пока нет.", 18))
	return scroll

func _select(id: String) -> void:
	selected = "" if selected == id else id
	picked = -1
	if _palette_grid and is_instance_valid(_palette_grid):
		for t in _palette_grid.get_children():
			if t is PartTile:
				t.picked = t.id == selected
				t.queue_redraw()
	_update_info()

## Инструменты формы: кисть, всё тело разом, готовые формы, цвет, узор.
func _shape_tools() -> ScrollContainer:
	var scroll := DragScroll.new()
	var col := Kit.vbox(12)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	col.add_child(_shape_quick())
	col.add_child(Kit.label("Готовые формы", 21, Art.TEXT, true))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for pr in PRESETS:
		var id: String = pr[0]
		var th := Thumb.new()
		th.caption = pr[1]
		th.shape = Content.shape_preset(id)
		th.color = Color(Content.COLORS[evo.color])
		th.pressed.connect(func():
			_remember()
			if not evo.set_shape(id):
				_forget()
				_say(TOO_SMALL)
				_info.add_theme_color_override("font_color", Art.ACCENT)
				return
			changed.emit()
			rebuild())
		flow.add_child(th)
	col.add_child(flow)
	col.add_child(Kit.label("Цвет", 21, Art.TEXT, true))
	col.add_child(_swatches(evo.color, func(i):
		_remember()
		evo.color = i
		changed.emit()
		rebuild()))
	col.add_child(Kit.label("Узор", 21, Art.TEXT, true))
	var pats := HFlowContainer.new()
	pats.add_theme_constant_override("h_separation", 8)
	pats.add_theme_constant_override("v_separation", 8)
	for pp in Content.PATTERNS:
		var pid: String = pp[0]
		var th := Thumb.new()
		th.caption = pp[1]
		th.shape = evo.shape
		th.color = Color(Content.COLORS[evo.color])
		th.color2 = Color(Content.COLORS[evo.color2])
		th.pattern = pid
		th.on = evo.pattern == pid
		th.pressed.connect(func():
			_remember()
			evo.pattern = pid
			changed.emit()
			rebuild())
		pats.add_child(th)
	col.add_child(pats)
	if evo.pattern != "none":
		col.add_child(Kit.label("Второй цвет — для узора", 21, Art.TEXT, true))
		col.add_child(_swatches(evo.color2, func(i):
			_remember()
			evo.color2 = i
			changed.emit()
			rebuild()))
	return scroll

## Кисть и «всё тело разом» — одним блоком (и под клеткой в режиме «Крупно»).
func _shape_quick(narrow := false) -> Control:
	var box := Kit.vbox(8)
	var gives: Container = Kit.vbox(6) if narrow else Kit.hbox(8)
	var st := Content.shape_stats(evo.shape)
	gives.add_child(_chip("Места +%d" % st.slots, Art.GOLD if st.slots > 0 else Art.MUTED))
	gives.add_child(_chip("Здоровье %s" % _pct(st.hp), Art.GREEN if st.hp > 1.001 else (Art.ACCENT if st.hp < 0.999 else Art.MUTED)))
	gives.add_child(_chip("Скорость %s" % _pct(st.speed), Art.GREEN if st.speed > 1.001 else (Art.ACCENT if st.speed < 0.999 else Art.MUTED)))
	box.add_child(gives)
	var brush_row: Container = Kit.vbox(6) if narrow else Kit.hbox(10)
	var bl := Kit.label("Кисть", 19, Art.MUTED)
	bl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brush_row.add_child(bl)
	brush_row.add_child(Kit.segmented(BRUSHES, str(int(brush)), func(id):
		brush = float(id)
		if _preview:
			_preview.queue_redraw()
		rebuild(), 17, 44))
	box.add_child(brush_row)
	var whole := HFlowContainer.new()
	whole.add_theme_constant_override("h_separation", 8)
	whole.add_theme_constant_override("v_separation", 8)
	for tr in [["bigger", "Больше"], ["smaller", "Меньше"], ["longer", "Длиннее"], ["wider", "Шире"], ["smooth", "Сгладить"]]:
		var kind: String = tr[0]
		var b := _toggle(tr[1], false, func():
			_remember()
			var ok := true
			if kind == "smooth":
				evo.smooth_shape()
			else:
				ok = evo.transform_shape(kind)
			if not ok:
				_forget()
				_say(TOO_SMALL)
				_info.add_theme_color_override("font_color", Art.ACCENT)
				return
			changed.emit()
			rebuild(), 46)
		b.toggle_mode = false
		b.add_theme_font_size_override("font_size", 18)
		whole.add_child(b)
	box.add_child(whole)
	return box

func _swatches(current: int, pick_: Callable) -> HFlowContainer:
	var colors := HFlowContainer.new()
	colors.add_theme_constant_override("h_separation", 4)
	colors.add_theme_constant_override("v_separation", 4)
	for i in Content.COLORS.size():
		var sw := Swatch.new()
		sw.color = Color(Content.COLORS[i])
		sw.on = current == i
		sw.pressed.connect(func(): pick_.call(i))
		colors.add_child(sw)
	return colors

# --- отмена ---------------------------------------------------------------------------

func _snap() -> Dictionary:
	return {"body": evo.body.duplicate(true), "shape": evo.shape.duplicate(), "color": evo.color, "color2": evo.color2, "pattern": evo.pattern}

## Запомнить, каким было тело, — перед изменением.
func _remember() -> void:
	_undo.append(_snap())
	if _undo.size() > 40:
		_undo.pop_front()
	_redo.clear()

## Изменение не удалось — последний снимок не нужен.
func _forget() -> void:
	if not _undo.is_empty():
		_undo.pop_back()

func _undo_step(dir: int) -> void:
	var from: Array = _undo if dir < 0 else _redo
	var to: Array = _redo if dir < 0 else _undo
	if from.is_empty():
		return
	to.append(_snap())
	var s: Dictionary = from.pop_back()
	evo.body = s.body
	evo.shape = s.shape
	evo.color = s.color
	evo.color2 = s.color2
	evo.pattern = s.pattern
	picked = -1
	changed.emit()
	rebuild()
	_say("Отменено" if dir < 0 else "Возвращено")

func _update_info() -> void:
	_refresh_stats()
	if _info_row == null or not is_instance_valid(_info_row):
		return
	for c in _info_row.get_children():
		_info_row.remove_child(c)
		c.queue_free()
	_info = Kit.muted("", 18)
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var icon_id := ""
	var title := ""
	var action: Button = null
	if mode == "shape":
		title = "Хватай точку на краю и тяни"
		_info.text = "Наружу — больше, внутрь — меньше. Кисть — сколько края тянется вместе с точкой. Больше тело — больше мест и здоровья, но медленнее; вытянутое вперёд — быстрее."
	elif picked >= 0 and picked < evo.body.size():
		var id: String = evo.body[picked].id
		var def: Dictionary = Content.PARTS[id]
		icon_id = id
		title = "%s · ур. %d" % [def.name, evo.unlocked.get(id, 1)]
		_info.text = def.hint + (". Зажми её на клетке и тащи — переставишь." if editable else "")
		if editable:
			action = Button.new()
			action.text = "Убрать  +%d ДНК" % def.cost
			action.focus_mode = Control.FOCUS_NONE
			action.custom_minimum_size = Vector2(0, 52)
			action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			action.add_theme_font_size_override("font_size", 20)
			for st in ["normal", "hover", "pressed", "hover_pressed"]:
				action.add_theme_stylebox_override(st, Kit.box(Color(0.55, 0.22, 0.22, 0.8), 18, Color(0, 0, 0, 0), 16))
			Kit.press_fx(action)
			action.pressed.connect(func():
				_remember()
				var out := evo.remove(picked)
				picked = -1
				changed.emit()
				rebuild()
				_say(out.message))
	elif selected != "":
		var def: Dictionary = Content.PARTS[selected]
		icon_id = selected
		if evo.unlocked.has(selected):
			var lvl: int = evo.unlocked[selected]
			var up := "" if lvl >= Content.PART_MAX_LEVEL else " · копий к ур. %d: %d/%d" % [lvl + 1, evo.shards.get(selected, 0), Evolution.copies_for(lvl)]
			var where := "куда угодно на клетку" if def.get("inner", false) else "на край клетки"
			title = "%s · ур. %d · %d ДНК%s" % [def.name, lvl, def.cost, up]
			_info.text = "%s. Перетащи её %s — или веди пальцем по клетке и отпусти." % [def.hint, where] if editable else def.hint
		else:
			title = "%s — ещё не найдена" % def.name
			_info.text = where_to_get(selected)
	else:
		title = "Перетащи часть на клетку"
		_info.text = "Тяни плитку из списка прямо на клетку. Нажми на часть на клетке — её можно убрать, зажми и тащи — переставить." if editable else "Нажми на часть — узнаешь, что она делает."
	if icon_id != "":
		var pic := PartPic.new()
		pic.id = icon_id
		pic.have = evo.unlocked.has(icon_id)
		pic.color = Color(Content.COLORS[evo.color])
		pic.custom_minimum_size = Vector2(56, 56)
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_info_row.add_child(pic)
	var text := Kit.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_info_title = Kit.label(title, 21, Art.TEXT, true)
	_info_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(_info_title)
	text.add_child(_info)
	_info_row.add_child(text)
	if action:
		_info_row.add_child(action)

## «Выпадает из: Колючка (30%)» — только из тех, кого уже встречал.
func where_to_get(id: String) -> String:
	if Content.PARTS[id].get("source", "") == "rock":
		var rocks: Array = []
		for src in Content.rock_sources(id):
			rocks.append("%s (%d%%)" % [Content.ROCKS[src[0]].name, int(round(src[1] * 100.0))])
		return "Только из камней: %s. Разбей рывком, укусом или шипом." % ", ".join(rocks)
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
	if _info and is_instance_valid(_info) and text != "":
		_info.text = text
		_info.add_theme_color_override("font_color", Art.TEXT)

## Отпустили палец на клетке: поставить выбранную часть (угол от носа — градусы).
func place_at(angle: float, depth := 1.0) -> void:
	if not editable or selected == "" or not evo.unlocked.has(selected):
		return
	var before := evo.body.map(func(p): return "%s|%d|%.1f" % [p.id, p.a, p.get("d", 1.0)])
	_remember()
	var out := evo.place(selected, int(round(angle)), mirror, depth)
	if out.ok:
		for p in evo.body:
			var key := "%s|%d|%.1f" % [p.id, p.a, p.get("d", 1.0)]
			if not before.has(key):
				pops[key] = 1.0
		changed.emit()
		_rebuild_soon()
	else:
		_forget()
	_say(out.message)
	if not out.ok and _info:
		_info.add_theme_color_override("font_color", Art.ACCENT)

## Перетащили стоящую часть на новое место.
func move_part(index: int, angle: float, depth := 1.0) -> void:
	if not editable:
		return
	_remember()
	var out := evo.move(index, angle, depth)
	if out.ok and out.message != "":
		var p: Dictionary = evo.body[index]
		pops["%s|%d|%.1f" % [p.id, p.a, p.get("d", 1.0)]] = 1.0
		picked = index
		changed.emit()
		_rebuild_soon()
	else:
		_forget()
		if _preview:
			_preview.queue_redraw()
	_say(out.message)
	if not out.ok and _info:
		_info.add_theme_color_override("font_color", Art.ACCENT)

## Пересобрать после того, как обработаются все касания этого кадра: иначе касание
## приходит в узел, которого уже нет.
var _rebuild_queued := false
func _rebuild_soon() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	(func():
		_rebuild_queued = false
		rebuild()).call_deferred()

func pick(index: int) -> void:
	picked = index
	selected = ""
	_update_info()
	if _preview:
		_preview.queue_redraw()

## Отпустили край: если форма поменялась — это шаг для «отменить».
func shape_done(before: Array) -> void:
	if before != evo.shape:
		_undo.append({"body": evo.body.duplicate(true), "shape": before, "color": evo.color, "color2": evo.color2, "pattern": evo.pattern})
		_redo.clear()
	changed.emit()
	_rebuild_soon()
	if _blocked:
		_blocked = false
		_say(TOO_SMALL)
		_info.add_theme_color_override("font_color", Art.ACCENT)

## «+15%» / «−5%» / «как у круга».
static func _pct(k: float) -> String:
	var p := int(round((k - 1.0) * 100.0))
	return "как у круга" if p == 0 else ("+%d%%" % p if p > 0 else "−%d%%" % -p)

# --- перетаскивание из списка -----------------------------------------------------------

## Палец на плитке и повёл вбок, к клетке, — тащим часть (вверх-вниз — это прокрутка).
func _input(e: InputEvent) -> void:
	if not visible or tab != "body" or mode != "parts" or not editable or big:
		return
	if e is InputEventScreenTouch:
		if e.pressed and _carry_idx == -1 and _palette_scroll and is_instance_valid(_palette_scroll) and _palette_scroll.get_global_rect().has_point(e.position):
			var id := _tile_at(e.position)
			if id != "" and evo.unlocked.has(id):
				_carry_idx = e.index
				_carry_from = e.position
				_carry_id = id
				carrying = false
		elif not e.pressed and e.index == _carry_idx:
			if carrying:
				_drop(e.position)
				get_viewport().set_input_as_handled()
			_carry_idx = -1
			carrying = false
			_carry_layer.queue_redraw()
	elif e is InputEventScreenDrag and e.index == _carry_idx:
		var d: Vector2 = e.position - _carry_from
		if not carrying and absf(d.x) > 22.0 and absf(d.x) > absf(d.y) * 1.3:
			carrying = true
			_palette_scroll.cancel()
			if selected != _carry_id:
				_select(_carry_id)
		if carrying:
			carry_pos = e.position
			if _preview and _preview.get_global_rect().has_point(e.position):
				_preview.ghost = _preview._ghost_at(e.position - _preview.global_position)
			elif _preview:
				_preview.ghost = {}
			_preview.queue_redraw()
			_carry_layer.queue_redraw()
			get_viewport().set_input_as_handled()

func _tile_at(p: Vector2) -> String:
	if _palette_grid == null or not is_instance_valid(_palette_grid):
		return ""
	for t in _palette_grid.get_children():
		if t is PartTile and t.get_global_rect().has_point(p):
			return t.id
	return ""

## Отпустили тащимую часть: над клеткой — ставим, мимо — ничего.
func _drop(p: Vector2) -> void:
	if _preview and _preview.get_global_rect().has_point(p) and not _preview.ghost.is_empty():
		var g: Dictionary = _preview.ghost
		_preview.ghost = {}
		place_at(g.a, g.d)
	else:
		if _preview:
			_preview.ghost = {}
			_preview.queue_redraw()
		_say("Отпусти часть над клеткой — тогда встанет")

## Слой над всем: тащимая часть под пальцем.
class CarryLayer:
	extends Control
	var editor

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if editor == null or not editor.carrying or editor._carry_id == "":
			return
		var over: bool = editor._preview != null and not editor._preview.ghost.is_empty()
		var r := 34.0 if not over else 24.0
		var at: Vector2 = editor.carry_pos - get_global_rect().position + Vector2(0, -50)
		draw_circle(at, r * 1.25, Color(0, 0, 0, 0.35))
		CellArt.part_icon(self, editor._carry_id, Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), Color(Content.COLORS[editor.evo.color]), 0.0, 0.85 if over else 1.0)


# --- атлас ----------------------------------------------------------------------------

func _atlas_tab() -> void:
	var ids: Array = Content.SPECIES.keys()
	ids.sort_custom(func(a, b): return Content.SPECIES[a].levels[0] * 100 + Content.SPECIES[a].radius < Content.SPECIES[b].levels[0] * 100 + Content.SPECIES[b].radius)
	var total := ids.size()
	var met := ids.filter(func(id): return evo.seen.has(id) or evo.sandbox).size()
	# Сверху: фильтр и сколько встречено.
	var bar := Kit.hbox(12)
	bar.add_child(Kit.segmented([["all", "Все"], ["calm", "Мирные"], ["danger", "Опасные"], ["giant", "Гиганты"], ["rock", "Камни"]], atlas_filter, func(id):
		atlas_filter = id
		rebuild(), 19, 50))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(sp)
	bar.add_child(Kit.info_chip("book", "Встречено %d из %d" % [met, total], Art.GREEN))
	if evo.stats.get("golden", 0) > 0:
		bar.add_child(Kit.info_chip("trophy", "Сияющих %d" % evo.stats.get("golden", 0), Art.GOLD))
	_root.add_child(bar)
	var scroll := DragScroll.new()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	_root.add_child(scroll)
	# Сначала встреченные, потом тени тех, кого ещё не видел, — по размеру, с которого они живут.
	var unseen: Array = []
	if atlas_filter != "rock":
		for id in ids:
			if not _atlas_fits(id):
				continue
			if evo.seen.has(id) or evo.sandbox:
				grid.add_child(_species_card(id))
			else:
				unseen.append(id)
		for id in unseen:
			grid.add_child(_unknown_card(id))
	if atlas_filter == "all" or atlas_filter == "rock":
		for rid in Content.ROCKS:
			grid.add_child(_rock_card(rid))

func _atlas_fits(id: String) -> bool:
	var def: Dictionary = Content.SPECIES[id]
	var danger: bool = def.behavior == "hunter" or def.get("hunts", false) or def.behavior == "shooter" or def.behavior == "parasite" or def.behavior == "ambush"
	match atlas_filter:
		"calm":
			return not danger and def.behavior != "roamer" and def.behavior != "colossus"
		"danger":
			return danger and def.behavior != "roamer" and def.behavior != "colossus"
		"giant":
			return def.behavior == "roamer" or def.behavior == "colossus"
	return true

## Кого ещё не встречал: тёмный силуэт и с какого размера он водится.
func _unknown_card(id: String) -> PanelContainer:
	var def: Dictionary = Content.SPECIES[id]
	var row := Kit.hbox(14)
	var mini := Mini.new()
	mini.species = id
	mini.custom_minimum_size = Vector2(96, 96)
	mini.modulate = Color(0.14, 0.2, 0.25)
	row.add_child(mini)
	var text := Kit.vbox(4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_child(Kit.label("???", 22, Art.MUTED, true))
	var lvl: int = int(def.levels[0])
	var when := "Живёт рядом — поищи" if lvl <= evo.level() else "Встречается с размера %d" % lvl
	if def.behavior == "roamer":
		when = ("Бродячий гигант · " + when.to_lower())
	elif def.behavior == "colossus":
		when = "Колосс — проплывает изредка, на любом размере"
	text.add_child(Kit.muted(when, 17))
	row.add_child(text)
	var card := Kit.card(row, Color(0.07, 0.09, 0.11), 20, 12)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return card

func _species_card(id: String) -> PanelContainer:
	var def: Dictionary = Content.SPECIES[id]
	var row := Kit.hbox(14)
	var mini := Mini.new()
	mini.species = id
	mini.custom_minimum_size = Vector2(96, 96)
	row.add_child(mini)
	var text := Kit.vbox(4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var kind: String = {"grazer": "мирный", "skittish": "пугливый", "drifter": "дрейфует", "hunter": "хищник", "boss": "великан",
		"giant": "гигант", "parasite": "паразит", "shooter": "стрелок", "ambush": "обманка",
		"roamer": "бродячий гигант", "colossus": "колосс — не ранить"}.get(def.behavior, "")
	if def.get("splits", false):
		kind += ", делится"
	if def.has("school"):
		kind += ", стая"
	if def.get("invisible", false):
		kind += ", невидимка"
	text.add_child(Kit.label("%s · %s" % [def.name, kind], 22, Art.DANGER if def.behavior == "hunter" or def.get("hunts", false) else Art.TEXT, true))
	text.add_child(Kit.muted(def.hint, 17))
	text.add_child(Kit.muted("Размеры %d–%d · побед: %d" % [def.levels[0], def.levels[1], evo.kills_by.get(id, 0)], 17))
	var drops := HFlowContainer.new()
	drops.add_theme_constant_override("h_separation", 8)
	drops.add_theme_constant_override("v_separation", 6)
	for d in def.drops:
		var chip := DropChip.new()
		chip.part = d[0]
		chip.chance = d[1]
		chip.have = evo.unlocked.has(d[0])
		drops.add_child(chip)
	# Части, которых не выбить, — тоже видно, но без шанса.
	var seen_mob := {}
	for p in def.parts:
		if not Content.obtainable(p[0]) and not seen_mob.has(p[0]):
			seen_mob[p[0]] = true
			var chip := DropChip.new()
			chip.part = p[0]
			chip.chance = -1.0
			drops.add_child(chip)
	text.add_child(drops)
	if evo.sandbox:
		var call := Button.new()
		call.text = "Призвать"
		call.focus_mode = Control.FOCUS_NONE
		call.custom_minimum_size = Vector2(150, 46)
		call.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		call.add_theme_font_size_override("font_size", 20)
		for st in ["normal", "hover", "pressed"]:
			call.add_theme_stylebox_override(st, Kit.box(Color("#6a5a9a"), 16))
		call.pressed.connect(func(): summon.emit(id))
		text.add_child(call)
	row.add_child(text)
	var card := Kit.card(row, Art.CARD, 20, 12)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return card


func _rock_card(rid: String) -> PanelContainer:
	var def: Dictionary = Content.ROCKS[rid]
	var row := Kit.hbox(14)
	var pic := RockPic.new()
	pic.kind = rid
	pic.custom_minimum_size = Vector2(96, 96)
	row.add_child(pic)
	var text := Kit.vbox(4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(Kit.label("%s · камень" % def.name, 22, Art.TEXT, true))
	text.add_child(Kit.muted("Разбивается рывком, укусом, шипом, а буром — втрое быстрее. С размера %d" % def.levels[0], 17))
	var drops := HFlowContainer.new()
	drops.add_theme_constant_override("h_separation", 8)
	for d in def.drops:
		var chip := DropChip.new()
		chip.part = d[0]
		chip.chance = d[1]
		chip.have = evo.unlocked.has(d[0])
		drops.add_child(chip)
	text.add_child(drops)
	row.add_child(text)
	var card := Kit.card(row, Color("#1a2228"), 20, 12)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return card


# --- родословная ---------------------------------------------------------------------

func _tree_tab() -> void:
	var scroll := DragScroll.new()
	var grid := GridContainer.new()
	grid.columns = 4 if landscape else 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	_root.add_child(scroll)
	var list := evo.history.duplicate()
	list.reverse()
	for h in list:
		var box := Kit.vbox(4)
		var pic := Ancestor.new()
		pic.snap = h
		pic.custom_minimum_size = Vector2(0, 150)
		pic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(pic)
		var now: bool = h.gen == evo.generation
		box.add_child(Kit.label("Поколение %d%s" % [h.gen, " · сейчас" if now else ""], 21, Art.GOLD if now else Art.TEXT, true))
		box.add_child(Kit.muted("Размер %d · частей %d" % [h.level, h.body.size()], 17))
		var card := Kit.card(box, Art.CARD, 20, 12)
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
	var note := Kit.muted("Каждая встреча с парой — новое поколение. Здесь видно, как менялся твой вид. Потомков в свите: %d из 3." % evo.brood, 20)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_child(note)


# --- достижения -----------------------------------------------------------------------

func _awards_tab() -> void:
	var scroll := DragScroll.new()
	var col := Kit.vbox(10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	_root.add_child(scroll)
	# Коллекция: сколько всего собрано.
	var parts_all: Array = Content.PARTS.keys().filter(func(p): return Content.obtainable(p))
	var got_parts := parts_all.filter(func(p): return evo.unlocked.has(p)).size()
	var maxed := parts_all.filter(func(p): return int(evo.unlocked.get(p, 0)) >= Content.PART_MAX_LEVEL).size()
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for pair in [["Достижения", "%d/%d" % [evo.achievements.size(), Content.ACHIEVEMENTS.size()]], ["Части", "%d/%d" % [got_parts, parts_all.size()]],
			["На 5 уровне", str(maxed)], ["Виды", "%d/%d" % [evo.seen.size(), Content.SPECIES.size()]],
			["Гиганты", "%d/%d" % [evo.lairs_beaten.size(), Content.SPECIES.values().filter(func(d): return d.behavior == "roamer").size()]],
			["Поколений", str(evo.generation)], ["Арена", "%d волн" % evo.arena_best]]:
		flow.add_child(_chip("%s  %s" % pair, Art.TEXT))
	col.add_child(flow)
	var grid := GridContainer.new()
	grid.columns = 2 if landscape else 1
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(grid)
	var list: Array = Content.ACHIEVEMENTS.duplicate()
	# Сначала полученные, потом — у кого больше сделано.
	var score := func(a) -> float:
		var pr := evo.achievement_progress(a)
		return (10.0 if evo.achievements.has(a.id) else 0.0) + float(pr[0]) / maxf(1.0, float(pr[1]))
	list.sort_custom(func(a, b): return score.call(a) > score.call(b))
	for a in list:
		var row := AwardRow.new()
		row.title = a.title
		row.hint = a.get("hint", "")
		var pr := evo.achievement_progress(a)
		row.have = pr[0]
		row.need = pr[1]
		row.done = evo.achievements.has(a.id)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(row)


# --- мелкие части ---------------------------------------------------------------------

## Предок в родословной — каким было тело в том поколении.
class Ancestor:
	extends Control
	var snap := {}
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var parts: Array = []
		for p in snap.body:
			parts.append({"id": p.id, "a": deg_to_rad(float(p.a)), "d": float(p.get("d", 1.0)), "lvl": 1})
		var r := minf(size.x, size.y) * 0.24
		CellArt.creature(self, size / 2.0, r, -PI / 2.0, Color(Content.COLORS[int(snap.color)]), parts, t,
			{"shape": snap.shape, "shadow": false, "pattern": snap.get("pattern", "none"), "color2": Color(Content.COLORS[int(snap.get("color2", 0))])})

## Строка достижения: кубок, название, полоса прогресса.
class AwardRow:
	extends Control
	var title := ""
	var hint := ""
	var have := 0
	var need := 1
	var done := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		custom_minimum_size = Vector2(0, 84)

	func _draw() -> void:
		draw_style_box(Kit.box(Art.CARD if done else Color(0.08, 0.1, 0.12), 20, Art.GOLD if done else Color(0, 0, 0, 0), 0), Rect2(Vector2.ZERO, size))
		Icons.draw(self, "trophy", Rect2(16, 20, 44, 44), Art.GOLD if done else Color("#3a4450"))
		var font := get_theme_default_font()
		draw_string(font, Vector2(76, 30), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 190, 21, Art.TEXT if done else Art.MUTED)
		var count := "%d / %d" % [have, need]
		var cw := font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(font, Vector2(size.x - cw - 18, 30), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Art.GOLD if done else Art.MUTED)
		if hint != "":
			draw_string(font, Vector2(76, 54), hint, HORIZONTAL_ALIGNMENT_LEFT, size.x - 94, 15, Art.MUTED)
		var bar := Rect2(76, 66, size.x - 94, 8)
		draw_style_box(Kit.box(Color(1, 1, 1, 0.1), 4, Color(0, 0, 0, 0), 0), bar)
		var k := clampf(float(have) / maxf(1.0, float(need)), 0.0, 1.0)
		if k > 0.0:
			draw_style_box(Kit.box(Art.GOLD if done else Art.GREEN, 4, Color(0, 0, 0, 0), 0), Rect2(bar.position, Vector2(maxf(8.0, bar.size.x * k), bar.size.y)))

class RockPic:
	extends Control
	var kind := ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		draw_circle(size / 2.0, size.x / 2.0, Color(0.07, 0.13, 0.17))
		CellArt.rock(self, {"pos": size / 2.0, "r": size.x * 0.3, "hp": 1.0, "max_hp": 1.0, "kind": kind, "v": 7, "flash": 0.0}, 0.0)


## Клетка крупно. «Части»: примерка выбранной части пальцем, отпустил — поставил; без
## выбора касание части выделяет её, а зажал и повёл — переносишь. «Форма»: на краю —
## точки-ручки; хватаешь ближайшую и тянешь — она ходит от того места, где взял (без
## скачка к пальцу), вместе с ней — соседи в пределах кисти.
class Preview:
	extends Control
	var editor
	var t := 0.0
	var ghost := {}  # {a — градусы, d} — куда встанет часть, пока палец на экране
	var ghost_id := ""  # какую часть примеряем (при переносе — ту, что тащим)
	## Форма: какая точка взята (-1 — никакая), каким был её радиус и где был палец.
	var grab := -1
	var _grab_val := 0.0
	var _grab_dist := 0.0
	var _before: Array = []
	## Перенос части: какая взята и где нажали.
	var _move := -1
	var _press := Vector2.ZERO
	var _moving := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _process(delta: float) -> void:
		t += delta
		for key in editor.pops.keys():
			editor.pops[key] -= delta * 1.6
			if editor.pops[key] <= 0.0:
				editor.pops.erase(key)
		queue_redraw()

	## Номер части на теле → множитель размера, пока она «вырастает»: 0 → 1,2 → 1.
	func _pop_scales() -> Dictionary:
		var out := {}
		var body: Array = editor.evo.body
		for i in body.size():
			var key := "%s|%d|%.1f" % [body[i].id, body[i].a, body[i].get("d", 1.0)]
			if editor.pops.has(key):
				var q := 1.0 - float(editor.pops[key])
				out[i] = (1.0 - pow(1.0 - q, 3.0)) + 0.3 * sin(PI * q)
		return out

	func _radius() -> float:
		return minf(size.x, size.y) * (0.3 if editor.big else 0.25)

	## Угол от носа (градусы) и расстояние от середины для точки на экране.
	func _polar(p: Vector2) -> Vector2:
		var v := p - size / 2.0
		return Vector2(rad_to_deg(wrapf(v.angle() + PI / 2.0, -PI, PI)), v.length())

	## Направление на экране для угла от носа (радианы).
	static func _dir(th: float) -> Vector2:
		return Vector2.from_angle(-PI / 2.0 + th)

	func _ghost_at(p: Vector2) -> Dictionary:
		var pol := _polar(p)
		var edge := _radius() * Content.shape_at(editor.evo.shape, deg_to_rad(pol.x))
		var d := 1.0
		if pol.y < edge * 0.8:
			d = minf(pol.y / (edge * 0.72), 0.9)
		return {"a": pol.x, "d": d}

	## Ближайшая к пальцу точка края (по углу).
	func _nearest_point(p: Vector2) -> int:
		var n: int = editor.evo.shape.size()
		var a := fposmod(_polar(p).x, 360.0)
		return int(round(a / 360.0 * n)) % n

	func _gui_input(e: InputEvent) -> void:
		var evo: Evolution = editor.evo
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			# Сначала — «касание наше»: дальше редактор может пересобраться, и этого узла
			# в дереве уже не будет.
			accept_event()
			if e.pressed:
				if editor.mode == "shape":
					if editor.editable:
						grab = _nearest_point(e.position)
						_before = evo.shape.duplicate()
						_grab_val = evo.shape[grab]
						_grab_dist = (e.position - size / 2.0).dot(_dir(TAU * grab / evo.shape.size()))
				elif editor.selected != "" and editor.editable and evo.unlocked.has(editor.selected):
					ghost_id = editor.selected
					ghost = _ghost_at(e.position)
				else:
					var i := _part_at(e.position)
					editor.pick(i)
					if i >= 0 and editor.editable:
						_move = i
						_press = e.position
						_moving = false
			else:
				if grab >= 0:
					grab = -1
					editor.shape_done(_before)
				elif _moving and not ghost.is_empty():
					var g := ghost
					ghost = {}
					_moving = false
					var i := _move
					_move = -1
					editor.move_part(i, g.a, g.d)
				elif not ghost.is_empty():
					var g := ghost
					ghost = {}
					editor.place_at(g.a, g.d)
				_move = -1
				_moving = false
		elif e is InputEventMouseMotion:
			if grab >= 0:
				# Тянем вдоль направления точки: вбок палец может гулять — форма не дёрнется.
				var along: float = (e.position - size / 2.0).dot(_dir(TAU * grab / evo.shape.size()))
				var value := _grab_val + (along - _grab_dist) / _radius()
				var ang := 360.0 * grab / evo.shape.size()
				if ang > 180.0:
					ang -= 360.0
				if not evo.reshape(ang, value, editor.mirror, editor.brush):
					editor._blocked = true
				accept_event()
			elif _move >= 0:
				if not _moving and e.position.distance_to(_press) > 12.0:
					_moving = true
					ghost_id = evo.body[_move].id
				if _moving:
					ghost = _ghost_at(e.position)
					editor._refresh_stats()
				accept_event()
			elif not ghost.is_empty():
				ghost = _ghost_at(e.position)
				editor._refresh_stats()
				accept_event()

	func _part_at(p: Vector2) -> int:
		var evo: Evolution = editor.evo
		var r := _radius()
		var best := -1
		var best_d := r * 0.4
		var parts := evo.body_parts()
		for i in parts.size():
			var at := CellArt.part_anchor(parts[i], size / 2.0, r, -PI / 2.0, evo.shape)
			var d := p.distance_to(at)
			if d < best_d:
				best_d = d
				best = i
		return best

	func _draw() -> void:
		var evo: Evolution = editor.evo
		var c := size / 2.0
		var r := _radius()
		draw_circle(c, minf(size.x, size.y) * 0.49, Color(0.07, 0.13, 0.17))
		var shaping: bool = editor.mode == "shape"
		# Пределы формы — едва заметными кольцами.
		if shaping:
			draw_arc(c, r * Content.SHAPE_MIN, 0, TAU, 48, Color(1, 1, 1, 0.08), 1.5, true)
			draw_arc(c, r * Content.SHAPE_MAX, 0, TAU, 64, Color(1, 1, 1, 0.08), 1.5, true)
		var col := Color(Content.COLORS[evo.color])
		var pops := _pop_scales()
		var parts: Array = evo.body_parts() if editor.parts_shown else []
		# Переносимую часть на старом месте не рисуем — она «в руке».
		if _moving and _move >= 0 and editor.parts_shown:
			parts = parts.duplicate()
			parts.remove_at(_move)
		CellArt.creature(self, c, r, -PI / 2.0, col, parts, t, {"pick": editor.picked if editor.parts_shown and not _moving else -1, "shadow": false, "shape": evo.shape,
			"pattern": evo.pattern, "color2": Color(Content.COLORS[evo.color2]), "pop": pops if editor.parts_shown and not _moving else {}})
		if not editor.parts_shown and not evo.body.is_empty():
			# Части скрыты — лишь бледные точки, где они стоят.
			for p in evo.body_parts():
				draw_circle(CellArt.part_anchor(p, c, r, -PI / 2.0, evo.shape), 4.0, Color(1, 1, 1, 0.25))
		# Кольцо и искры вокруг только что поставленной части.
		var all_parts := evo.body_parts()
		if editor.parts_shown and not _moving:
			for i in pops:
				var key := "%s|%d|%.1f" % [evo.body[i].id, evo.body[i].a, evo.body[i].get("d", 1.0)]
				var q := 1.0 - float(editor.pops.get(key, 0.0))
				var at := CellArt.part_anchor(all_parts[i], c, r, -PI / 2.0, evo.shape)
				draw_arc(at, r * (0.15 + 0.45 * q), 0, TAU, 32, Color(Art.GOLD, 1.0 - q), 3.0, true)
				for j in 6:
					var d := Vector2.from_angle(TAU * j / 6.0 + q * 2.0)
					draw_circle(at + d * r * (0.2 + 0.5 * q), 3.5 * (1.0 - q), Color(1, 1, 0.8, 1.0 - q))
		# Нос — маленькая стрелка сверху, чтобы было видно, где перёд.
		var nose := c + Vector2(0, -r * Content.shape_at(evo.shape, 0.0) - r * 0.55)
		draw_colored_polygon(PackedVector2Array([nose, nose + Vector2(-9, 16), nose + Vector2(9, 16)]), Color(1, 1, 1, 0.35))
		if shaping:
			_draw_handles(c, r)
		if not ghost.is_empty() and ghost_id != "":
			var snapped := Evolution.snap(ghost.a)
			var depth := Evolution.snap_depth(ghost_id, ghost.d)
			if depth == 0.0:
				snapped = 0
			var ok: bool
			if _moving and _move >= 0:
				var keep: Dictionary = evo.body[_move]
				evo.body.remove_at(_move)
				ok = evo.can_place(ghost_id, snapped, depth).ok
				evo.body.insert(_move, keep)
			else:
				ok = evo.can_place(ghost_id, snapped, depth).ok
			var tint := Color("#8fe0a0") if ok else Color("#e07070")
			var part := {"id": ghost_id, "a": deg_to_rad(snapped), "d": depth, "lvl": evo.unlocked.get(ghost_id, 1)}
			CellArt.part_alone(self, part, c, r, -PI / 2.0, col, t, 0.8, evo.shape)
			var at := CellArt.part_anchor(part, c, r, -PI / 2.0, evo.shape)
			draw_arc(at, r * 0.28, 0, TAU, 32, tint, 3.0, true)
			if editor.mirror and not _moving and not Content.is_mouth(ghost_id) and snapped != 0 and absi(snapped) != 180 and depth > 0.0:
				var twin := {"id": ghost_id, "a": deg_to_rad(-snapped), "d": depth, "lvl": part.lvl}
				CellArt.part_alone(self, twin, c, r, -PI / 2.0, col, t, 0.4, evo.shape)

	## Ручки формы: точки на краю; взятая — крупная, те, что тянутся с ней, — светятся
	## по силе кисти. Пока тянешь — прежний край пунктиром и что даёт форма.
	func _draw_handles(c: Vector2, r: float) -> void:
		var evo: Evolution = editor.evo
		var n: int = evo.shape.size()
		if grab >= 0 and not _before.is_empty():
			var pts := PackedVector2Array()
			for k in 65:
				var th := TAU * k / 64.0
				pts.append(c + _dir(th) * r * Content.shape_at(_before, th))
			for k in range(0, 64, 2):
				draw_line(pts[k], pts[k + 1], Color(1, 1, 1, 0.35), 2.0, true)
		var grab_a := 360.0 * grab / n
		for i in n:
			var th := TAU * i / n
			var at := c + _dir(th) * r * float(evo.shape[i])
			var w := 0.0
			if grab >= 0:
				var ai := 360.0 * i / n
				for a in ([grab_a, -grab_a] if editor.mirror else [grab_a]):
					w = maxf(w, maxf(0.0, 1.0 - Evolution.angle_gap(ai, a) / editor.brush))
			var big_one: bool = grab >= 0 and (i == grab or (editor.mirror and i == (n - grab) % n))
			if big_one:
				draw_line(c, at, Color(Art.GREEN, 0.35), 2.0, true)
				draw_circle(at, 13.0, Color(Art.GREEN, 0.3))
				draw_circle(at, 9.0, Art.GREEN)
			else:
				draw_circle(at, 7.0, Color(0, 0, 0, 0.35))
				draw_circle(at, 5.5, Color(1, 1, 1, 0.55).lerp(Art.GREEN, w))
		if grab >= 0:
			var st := Content.shape_stats(evo.shape)
			var text := "Места +%d · Здоровье %s · Скорость %s" % [st.slots, editor._pct(st.hp), editor._pct(st.speed)]
			var font := get_theme_default_font()
			var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			var pos := Vector2((size.x - tw) / 2.0, 28)
			draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Color(0, 0, 0, 0.7))
			draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Art.TEXT)
			if editor._blocked:
				var warn := "Меньше нельзя: части не поместятся"
				var ww := font.get_string_size(warn, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
				draw_string_outline(font, Vector2((size.x - ww) / 2.0, 54), warn, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 6, Color(0, 0, 0, 0.7))
				draw_string(font, Vector2((size.x - ww) / 2.0, 54), warn, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Art.ACCENT)

## Миниатюра формы или узора: клетка без частей и подпись.
class Thumb:
	extends Button
	var caption := ""
	var shape: Array = []
	var color := Color.WHITE
	var color2 := Color.WHITE
	var pattern := "none"
	var on := false

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_PASS
		custom_minimum_size = Vector2(96, 104)
		Kit.press_fx(self)

	func _draw() -> void:
		draw_style_box(Kit.box(Art.CARD, 18, Art.GOLD if on else Color(0, 0, 0, 0), 0), Rect2(Vector2.ZERO, size))
		CellArt.creature(self, Vector2(size.x / 2.0, 42), 22.0, -PI / 2.0, color, [], 0.0, {"shape": shape, "shadow": false, "pattern": pattern, "color2": color2})
		var font := get_theme_default_font()
		var fs := 16
		var w := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		while w > size.x - 8 and fs > 11:
			fs -= 1
			w = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2((size.x - w) / 2.0, size.y - 12), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.TEXT)


## Плитка части в палитре: значок, имя, цена, уровень.
class PartTile:
	extends Button
	var id := ""
	var level := 0
	var color := Color.WHITE
	var picked := false
	var cheap := true
	var progress := 0.0  # копии к следующему уровню, 0–1
	var on_body := 0  # сколько таких уже стоит на теле

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_PASS
		custom_minimum_size = Vector2(140, 150)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var have := level > 0
		draw_style_box(Kit.box(Art.CARD if have else Color(0.08, 0.1, 0.12), 20, Art.GOLD if picked else Color(0, 0, 0, 0)), r)
		var icon := Rect2(size.x / 2.0 - 38, 6, 76, 76)
		CellArt.part_icon(self, id, icon, color if have else Color("#3a4450"), 0.0, 1.0 if have else 0.35)
		var font := get_theme_default_font()
		var def: Dictionary = Content.PARTS[id]
		var name: String = def.name
		# Длинное имя — мельче, чтобы влезло в плитку целиком.
		var fs := 18
		var w := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		while w > size.x - 14 and fs > 12:
			fs -= 1
			w = font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2((size.x - w) / 2.0, 102), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.TEXT if have else Art.MUTED)
		if have:
			var cost := "%d ДНК" % def.cost
			var cw := font.get_string_size(cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(font, Vector2((size.x - cw) / 2.0, 124), cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Art.GREEN if cheap else Art.ACCENT)
			for i in Content.PART_MAX_LEVEL:
				var x := size.x / 2.0 + (i - 2) * 13.0
				draw_circle(Vector2(x, 138), 4, Art.GOLD if i < level else Color(1, 1, 1, 0.15))
				# Следующая точка заполняется по мере того, как копятся копии.
				if i == level and progress > 0.0:
					draw_circle(Vector2(x, 138), 4.0 * progress, Color(Art.GOLD, 0.7))
		else:
			Icons.draw(self, "lock", Rect2(size.x / 2.0 - 11, 114, 22, 22), Art.MUTED)
		# Уже на теле — зелёная метка в углу: «×2».
		if on_body > 0:
			var b := Vector2(size.x - 22, 22)
			draw_circle(b, 15, Art.GREEN_DARK)
			var txt := "×%d" % on_body if on_body > 1 else "✓"
			var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			if on_body > 1:
				draw_string(font, b + Vector2(-tw / 2.0, 6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Art.BG)
			else:
				Icons.draw(self, "check", Rect2(b - Vector2(9, 9), Vector2(18, 18)), Art.BG)

## Значок части крупно — в строке сведений.
class PartPic:
	extends Control
	var id := ""
	var have := true
	var color := Color.WHITE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		CellArt.part_icon(self, id, Rect2(Vector2.ZERO, size), color if have else Color("#3a4450"), 0.0, 1.0 if have else 0.4)

class Swatch:
	extends Button
	var color := Color.WHITE
	var on := false

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_PASS
		custom_minimum_size = Vector2(50, 50)

	func _draw() -> void:
		var c := size / 2.0
		draw_circle(c, 18, color)
		if on:
			draw_arc(c, 23, 0, TAU, 32, Art.GOLD, 3, true)

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

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var def: Dictionary = Content.SPECIES[species]
		var parts: Array = []
		for p in def.parts:
			parts.append({"id": p[0], "a": deg_to_rad(p[1]), "d": 1.0, "lvl": p[2]})
		draw_circle(size / 2.0, size.x / 2.0, Color(0.07, 0.13, 0.17))
		var r := size.x * 0.22
		CellArt.creature(self, size / 2.0 + Vector2(r * 0.25, 0), r, PI, Color(def.color), parts, t, {"shadow": false, "shape": Content.shape_preset(def.get("shape", "round"))})

## «шип 30%» — часть, которую роняет вид, и шанс.
class DropChip:
	extends Control
	var part := ""
	var chance := 0.0
	var have := false

	func _text() -> String:
		if chance < 0.0:
			return "%s — не выбить" % Content.PARTS[part].name
		return "%s %d%%" % [Content.PARTS[part].name, int(round(chance * 100.0))]

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		var w := get_theme_default_font().get_string_size(_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		custom_minimum_size = Vector2(56 + w, 40)

	func _draw() -> void:
		draw_style_box(Kit.box(Art.BG, 20, Art.GREEN_DARK if have else Color(0, 0, 0, 0), 0), Rect2(Vector2.ZERO, size))
		CellArt.part_icon(self, part, Rect2(6, 4, 32, 32), Color("#9aa4b0"))
		var col := Art.MUTED if chance < 0.0 else (Art.GREEN if have else Art.GOLD)
		draw_string(get_theme_default_font(), Vector2(44, 27), _text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
