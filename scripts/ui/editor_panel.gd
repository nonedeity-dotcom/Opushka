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
## Тело можно менять только после встречи с парой; из «Атласа» — только смотреть.
var editable := true
var _sheet: PanelContainer
var _root: VBoxContainer
var _info: Label
var _info_row: HBoxContainer
var _preview: Preview
var _palette_scroll: ScrollContainer
## Пока тянул форму, упёрся: меньше нельзя — скажем, когда отпустит палец.
var _blocked := false
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
	resized.connect(_place)


func open(e: Evolution, landscape_: bool, editable_ := true) -> void:
	evo = e
	landscape = landscape_
	editable = editable_
	tab = "body" if editable else "atlas"
	selected = ""
	picked = -1
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
	var head := Kit.hbox(10)
	var icon := IconBox.new()
	icon.icon = "dna"
	icon.custom_minimum_size = Vector2(46, 46)
	head.add_child(icon)
	head.add_child(Kit.label("Поколение %d" % evo.generation if editable else {"atlas": "Атлас", "tree": "Родословная", "awards": "Достижения"}.get(tab, "Атлас"), 28, Art.TEXT, true))
	# Имя вида — прямо в заголовке, нажал и пишешь.
	var name_edit := LineEdit.new()
	name_edit.text = evo.name
	name_edit.max_length = 18
	name_edit.custom_minimum_size = Vector2(170, 0)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.add_theme_font_size_override("font_size", 22)
	name_edit.add_theme_color_override("font_color", Art.MUTED)
	name_edit.add_theme_stylebox_override("normal", Kit.box(Color(1, 1, 1, 0.04), 14, Color(0, 0, 0, 0), 10))
	name_edit.add_theme_stylebox_override("focus", Kit.box(Color(1, 1, 1, 0.08), 14, Art.GREEN_DARK, 10))
	name_edit.tooltip_text = "Имя твоего вида"
	name_edit.text_changed.connect(func(t):
		if t.strip_edges() != "":
			evo.name = t.strip_edges())
	name_edit.focus_exited.connect(func(): changed.emit())
	head.add_child(name_edit)
	var body_btn := _toggle("Тело", tab == "body", func():
		tab = "body"
		rebuild())
	body_btn.disabled = not editable
	body_btn.tooltip_text = "" if editable else "Тело меняется после встречи с парой: нажми ♥"
	head.add_child(body_btn)
	for pair in [["atlas", "Атлас"], ["tree", "Родословная"], ["awards", "Достижения"]]:
		var id: String = pair[0]
		head.add_child(_toggle(pair[1], tab == id, func():
			tab = id
			selected = ""
			picked = -1
			rebuild()))
	if tab == "body":
		head.add_child(_chip("ДНК %d" % evo.dna_free() if not evo.sandbox else "ДНК без счёта", Art.GREEN))
		head.add_child(_chip("Части %d/%d" % [evo.body.size(), evo.slots()], Art.TEXT))
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
	return b

func _chip(text: String, col: Color) -> PanelContainer:
	var c := Kit.card(Kit.label(text, 20, col, true), Art.CARD, 16, 10)
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	return c


# --- тело -----------------------------------------------------------------------------

func _body_tab() -> void:
	var cols := Kit.hbox(16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(cols)

	var left := Kit.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.85
	_preview = Preview.new()
	_preview.editor = self
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_preview)
	left.add_child(_stats())
	cols.add_child(left)

	var right := Kit.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var modes := Kit.hbox(8)
	modes.add_child(_toggle("Части", mode == "parts", func():
		mode = "parts"
		rebuild()))
	modes.add_child(_toggle("Форма и цвет", mode == "shape", func():
		mode = "shape"
		selected = ""
		picked = -1
		rebuild()))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modes.add_child(spacer)
	var mir := _toggle("Зеркально", mirror, func(): pass)
	mir.tooltip_text = "Ставить части и тянуть форму сразу с двух сторон"
	mir.toggled.connect(func(on): mirror = on)
	modes.add_child(mir)
	right.add_child(modes)
	_info = Kit.muted("", 20)
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_row = Kit.hbox(10)
	_info_row.add_child(_info)
	right.add_child(_info_row)
	if mode == "parts":
		right.add_child(_palette())
	else:
		right.add_child(_shape_tools())
	cols.add_child(right)
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
	var sight := "только рядом" if c.eyes <= 0.0 else ("почти весь экран" if c.eyes < 2.0 else "весь экран")
	flow.add_child(_chip("Обзор: " + sight, Art.TEXT if c.eyes > 0.0 else Art.MUTED))
	if c.regen > 0.0:
		flow.add_child(_chip("Свет", Color("#8ad07a")))
	return flow

func _palette() -> ScrollContainer:
	var scroll := DragScroll.new()
	_palette_scroll = scroll
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	# Сначала открытые — по порядку справочника, потом закрытые.
	var ids: Array = Content.PARTS.keys().filter(func(id): return Content.obtainable(id))
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

func _shape_tools() -> ScrollContainer:
	var scroll := DragScroll.new()
	var col := Kit.vbox(12)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	# Что даёт форма — сразу видно, куда тянуть.
	var st := Content.shape_stats(evo.shape)
	var gives := Kit.hbox(8)
	gives.add_child(_chip("Места +%d" % st.slots, Art.GOLD if st.slots > 0 else Art.MUTED))
	gives.add_child(_chip("Здоровье %s" % _pct(st.hp), Art.GREEN if st.hp > 1.001 else (Art.ACCENT if st.hp < 0.999 else Art.MUTED)))
	gives.add_child(_chip("Скорость %s" % _pct(st.speed), Art.GREEN if st.speed > 1.001 else (Art.ACCENT if st.speed < 0.999 else Art.MUTED)))
	col.add_child(gives)
	col.add_child(Kit.muted("Больше тело — больше мест под части и здоровья, но медленнее. Вытянутое вперёд — быстрее, широкое — медленнее. На большом теле частям просторнее.", 17))
	col.add_child(Kit.label("Готовые формы", 22, Art.TEXT, true))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for pr in PRESETS:
		var id: String = pr[0]
		var b := _toggle(pr[1], false, func():
			if not evo.set_shape(id):
				_say(TOO_SMALL)
				_info.add_theme_color_override("font_color", Art.ACCENT)
				return
			changed.emit()
			rebuild(), 56)
		b.toggle_mode = false
		b.icon = null
		flow.add_child(b)
	var smooth := _toggle("Сгладить", false, func():
		evo.smooth_shape()
		changed.emit()
		rebuild(), 56)
	smooth.toggle_mode = false
	flow.add_child(smooth)
	col.add_child(flow)
	col.add_child(Kit.label("Цвет", 22, Art.TEXT, true))
	var colors := HFlowContainer.new()
	colors.add_theme_constant_override("h_separation", 6)
	for i in Content.COLORS.size():
		var sw := Swatch.new()
		sw.color = Color(Content.COLORS[i])
		sw.on = evo.color == i
		sw.pressed.connect(func():
			evo.color = i
			changed.emit()
			rebuild())
		colors.add_child(sw)
	col.add_child(colors)
	col.add_child(Kit.label("Узор", 22, Art.TEXT, true))
	var pats := HFlowContainer.new()
	pats.add_theme_constant_override("h_separation", 8)
	pats.add_theme_constant_override("v_separation", 8)
	for pp in Content.PATTERNS:
		var pid: String = pp[0]
		var pb := _toggle(pp[1], evo.pattern == pid, func():
			evo.pattern = pid
			changed.emit()
			rebuild(), 52)
		pats.add_child(pb)
	col.add_child(pats)
	if evo.pattern != "none":
		col.add_child(Kit.label("Второй цвет — для узора", 22, Art.TEXT, true))
		var colors2 := HFlowContainer.new()
		colors2.add_theme_constant_override("h_separation", 6)
		for i in Content.COLORS.size():
			var sw2 := Swatch.new()
			sw2.color = Color(Content.COLORS[i])
			sw2.on = evo.color2 == i
			sw2.pressed.connect(func():
				evo.color2 = i
				changed.emit()
				rebuild())
			colors2.add_child(sw2)
		col.add_child(colors2)
	return scroll

func _update_info() -> void:
	if _info == null:
		return
	for c in _info_row.get_children():
		if c != _info:
			_info_row.remove_child(c)
			c.queue_free()
	_info.add_theme_color_override("font_color", Art.MUTED)
	if mode == "shape":
		_info.text = "Веди пальцем по клетке: наружу — край вытягивается, внутрь — втягивается. «Зеркально» — сразу с двух сторон."
		return
	if picked >= 0 and picked < evo.body.size():
		var id: String = evo.body[picked].id
		var def: Dictionary = Content.PARTS[id]
		_info.text = "%s, ур. %d — %s" % [def.name, evo.unlocked.get(id, 1), Content.lc_first(def.hint)]
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
			var where := "куда угодно на клетке, хоть в середину" if def.get("inner", false) else "на край клетки"
			_info.text = "%s (ур. %d%s) · %d ДНК — %s. Веди пальцем %s и отпусти." % [def.name, lvl, up, def.cost, Content.lc_first(def.hint), where]
		else:
			_info.text = "%s — ещё не найдена. %s" % [def.name, where_to_get(selected)]
	else:
		_info.text = "Выбери часть и веди пальцем по клетке. Нажми на часть на клетке — её можно убрать."

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
	if _info:
		_info.text = text
		_info.add_theme_color_override("font_color", Art.TEXT)

## Отпустили палец на клетке: поставить выбранную часть (угол от носа — градусы).
func place_at(angle: float, depth := 1.0) -> void:
	if selected == "" or not evo.unlocked.has(selected):
		return
	var before := evo.body.map(func(p): return "%s|%d|%.1f" % [p.id, p.a, p.get("d", 1.0)])
	var out := evo.place(selected, int(round(angle)), mirror, depth)
	if out.ok:
		for p in evo.body:
			var key := "%s|%d|%.1f" % [p.id, p.a, p.get("d", 1.0)]
			if not before.has(key):
				pops[key] = 1.0
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

func shape_done() -> void:
	changed.emit()
	rebuild()
	if _blocked:
		_blocked = false
		_say(TOO_SMALL)
		_info.add_theme_color_override("font_color", Art.ACCENT)

## «+15%» / «−5%» / «как у круга».
static func _pct(k: float) -> String:
	var p := int(round((k - 1.0) * 100.0))
	return "как у круга" if p == 0 else ("+%d%%" % p if p > 0 else "−%d%%" % -p)


# --- атлас ----------------------------------------------------------------------------

func _atlas_tab() -> void:
	var scroll := DragScroll.new()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	_root.add_child(scroll)
	var ids: Array = Content.SPECIES.keys()
	ids.sort_custom(func(a, b): return Content.SPECIES[a].levels[0] * 100 + Content.SPECIES[a].radius < Content.SPECIES[b].levels[0] * 100 + Content.SPECIES[b].radius)
	var hidden := 0
	for id in ids:
		if not evo.seen.has(id) and not evo.sandbox:
			hidden += 1
			continue
		grid.add_child(_species_card(id))
	for rid in Content.ROCKS:
		grid.add_child(_rock_card(rid))
	var total := Content.SPECIES.size()
	var line := "Встречено видов: %d из %d. Сияющих побеждено: %d. Камней разбито: %d." % [total - hidden, total, evo.stats.get("golden", 0), evo.stats.get("rocks", 0)]
	if hidden > 0:
		line += " Остальные живут глубже — подрасти, и они появятся."
	var note := Kit.muted(line, 20)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_child(note)

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
		"giant": "гигант", "lair": "хозяин логова", "parasite": "паразит", "shooter": "стрелок", "ambush": "обманка",
		"roamer": "бродячий гигант"}.get(def.behavior, "")
	if def.get("splits", false):
		kind += ", делится"
	if def.has("school"):
		kind += ", стая"
	if def.get("invisible", false):
		kind += ", невидимка"
	text.add_child(Kit.label("%s · %s" % [def.name, kind], 22, Art.DANGER if def.behavior == "hunter" or def.get("hunts", false) else Art.TEXT, true))
	text.add_child(Kit.muted(def.hint, 17))
	var waters: Array = []
	for b in def.get("biomes", []):
		waters.append(Content.BIOMES[b].name.to_lower())
	var where := " · " + ", ".join(waters) if not waters.is_empty() else ""
	text.add_child(Kit.muted("Размеры %d–%d%s · побед: %d" % [def.levels[0], def.levels[1], where, evo.kills_by.get(id, 0)], 17))
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
			["Воды", "%d/%d" % [evo.biomes_seen.size(), Content.BIOMES.size()]], ["Логова", "%d/%d" % [evo.lairs_beaten.size(), 3]],
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
	list.sort_custom(func(a, b): return int(evo.achievements.has(a.id)) > int(evo.achievements.has(b.id)))
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


## Клетка крупно. «Части»: касание — примерка выбранной части, отпустил — поставил;
## без выбора касание части выделяет её. «Форма»: палец тянет край тела.
class Preview:
	extends Control
	var editor
	var t := 0.0
	var ghost := {}  # {a — градусы, d} — куда встанет часть, пока палец на экране
	var shaping := false

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
		return minf(size.x, size.y) * 0.25

	## Угол от носа (градусы) и расстояние от середины для точки на экране.
	func _polar(p: Vector2) -> Vector2:
		var v := p - size / 2.0
		return Vector2(rad_to_deg(wrapf(v.angle() + PI / 2.0, -PI, PI)), v.length())

	func _ghost_at(p: Vector2) -> Dictionary:
		var pol := _polar(p)
		var edge := _radius() * Content.shape_at(editor.evo.shape, deg_to_rad(pol.x))
		var d := 1.0
		if pol.y < edge * 0.8:
			d = minf(pol.y / (edge * 0.72), 0.9)
		return {"a": pol.x, "d": d}

	func _gui_input(e: InputEvent) -> void:
		var evo: Evolution = editor.evo
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				if editor.mode == "shape":
					shaping = true
					_pull(e.position)
				elif editor.selected != "":
					ghost = _ghost_at(e.position)
				else:
					editor.pick(_part_at(e.position))
			else:
				if shaping:
					shaping = false
					editor.shape_done()
				elif not ghost.is_empty():
					var g := ghost
					ghost = {}
					editor.place_at(g.a, g.d)
			accept_event()
		elif e is InputEventMouseMotion:
			if shaping:
				_pull(e.position)
				accept_event()
			elif not ghost.is_empty():
				ghost = _ghost_at(e.position)
				accept_event()

	## Потянуть край туда, где палец.
	func _pull(p: Vector2) -> void:
		var pol := _polar(p)
		if not editor.evo.reshape(pol.x, pol.y / _radius(), editor.mirror):
			editor._blocked = true

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
		# Пределы формы — едва заметными кольцами.
		if editor.mode == "shape":
			draw_arc(c, r * Content.SHAPE_MIN, 0, TAU, 48, Color(1, 1, 1, 0.08), 1.5, true)
			draw_arc(c, r * Content.SHAPE_MAX, 0, TAU, 64, Color(1, 1, 1, 0.08), 1.5, true)
		var col := Color(Content.COLORS[evo.color])
		var pops := _pop_scales()
		CellArt.creature(self, c, r, -PI / 2.0, col, evo.body_parts(), t, {"pick": editor.picked, "shadow": false, "shape": evo.shape,
			"pattern": evo.pattern, "color2": Color(Content.COLORS[evo.color2]), "pop": pops})
		# Кольцо и искры вокруг только что поставленной части.
		var parts := evo.body_parts()
		for i in pops:
			var key := "%s|%d|%.1f" % [evo.body[i].id, evo.body[i].a, evo.body[i].get("d", 1.0)]
			var q := 1.0 - float(editor.pops.get(key, 0.0))
			var at := CellArt.part_anchor(parts[i], c, r, -PI / 2.0, evo.shape)
			draw_arc(at, r * (0.15 + 0.45 * q), 0, TAU, 32, Color(Art.GOLD, 1.0 - q), 3.0, true)
			for j in 6:
				var d := Vector2.from_angle(TAU * j / 6.0 + q * 2.0)
				draw_circle(at + d * r * (0.2 + 0.5 * q), 3.5 * (1.0 - q), Color(1, 1, 0.8, 1.0 - q))
		# Нос — маленькая стрелка сверху, чтобы было видно, где перёд.
		var nose := c + Vector2(0, -r * Content.shape_at(evo.shape, 0.0) - r * 0.55)
		draw_colored_polygon(PackedVector2Array([nose, nose + Vector2(-9, 16), nose + Vector2(9, 16)]), Color(1, 1, 1, 0.35))
		if not ghost.is_empty() and editor.selected != "":
			var snapped := Evolution.snap(ghost.a)
			var depth := Evolution.snap_depth(editor.selected, ghost.d)
			if depth == 0.0:
				snapped = 0
			var ok: bool = evo.can_place(editor.selected, snapped, depth).ok
			var tint := Color("#8fe0a0") if ok else Color("#e07070")
			var part := {"id": editor.selected, "a": deg_to_rad(snapped), "d": depth, "lvl": evo.unlocked.get(editor.selected, 1)}
			CellArt.part_alone(self, part, c, r, -PI / 2.0, col, t, 0.8, evo.shape)
			var at := CellArt.part_anchor(part, c, r, -PI / 2.0, evo.shape)
			draw_arc(at, r * 0.28, 0, TAU, 32, tint, 3.0, true)

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
		var fs := 18 if name.length() < 12 else 15
		var w := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
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

class Swatch:
	extends Button
	var color := Color.WHITE
	var on := false

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_PASS
		custom_minimum_size = Vector2(56, 56)

	func _draw() -> void:
		var c := size / 2.0
		draw_circle(c, 20, color)
		if on:
			draw_arc(c, 25, 0, TAU, 32, Art.GOLD, 3, true)

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
