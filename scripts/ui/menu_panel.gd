## Главное меню: три ячейки сохранений. В пустой — новая игра с выбором сложности.
## Под ними — песочница; у заполненной ячейки — ещё и арена для этого вида.
extends Control

const RoundButton := preload("res://scripts/ui/round_button.gd")

signal play(slot: int)
signal new_game(slot: int, difficulty: String)
signal arena(slot: int)
signal sandbox

var t := 0.0
var _row: HBoxContainer
var _arming := -1
## Какую сложность выбрали в пустой ячейке (до «Начать»).
var _diff := {}
var _cells: Array = []  # для живого фона: [{pos, vel, species, a}]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var r := RandomNumberGenerator.new()
	r.seed = 11
	var kinds: Array = Content.SPECIES.keys().filter(func(k): return not Content.SPECIES[k].has("scale"))
	for i in 14:
		_cells.append({"pos": Vector2(r.randf(), r.randf()), "vel": Vector2.from_angle(r.randf() * TAU) * r.randf_range(0.004, 0.012),
			"species": kinds[r.randi() % kinds.size()], "a": r.randf() * TAU, "k": r.randf_range(0.6, 1.3)})
	resized.connect(rebuild)

func open() -> void:
	visible = true
	_arming = -1
	rebuild()

func _process(delta: float) -> void:
	if not visible:
		return
	t += delta
	for c in _cells:
		c.pos = (c.pos + c.vel * delta).posmod(1.0)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0b1c26"))
	draw_circle(Vector2(size.x * 0.5, -size.y * 0.6), size.y * 1.3, Color(0.12, 0.3, 0.36, 0.5))
	for c in _cells:
		var def: Dictionary = Content.SPECIES[c.species]
		var parts: Array = []
		for p in def.parts:
			parts.append({"id": p[0], "a": deg_to_rad(p[1]), "d": 1.0, "lvl": 1})
		var at: Vector2 = c.pos * size
		CellArt.creature(self, at, def.radius * 1.3 * c.k, c.vel.angle(), Color(def.color, 1.0), parts, t + c.a,
			{"shape": Content.shape_preset(def.get("shape", "round")), "ghost": 0.35, "shadow": false, "stretch": 0.5})

func rebuild() -> void:
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()
	var col := Kit.vbox(12)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 40
	col.offset_right = -40
	col.offset_top = 20
	col.offset_bottom = -20
	add_child(col)
	var title := Kit.label("Эволюция", 44, Art.TEXT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := Kit.label("от одной клетки — к своему виду", 22, Art.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	_row = Kit.hbox(18)
	_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_row)
	for slot in range(1, Saves.COUNT + 1):
		_row.add_child(_slot_card(slot))
	var bottom := Kit.hbox(14)
	var sb := _button("Песочница", Color("#6a5a9a"), func(): sandbox.emit())
	sb.custom_minimum_size = Vector2(240, 50)
	bottom.add_child(sb)
	var sand := Saves.load_slot(Saves.SANDBOX)
	var note := Kit.muted("Все части открыты, ДНК без счёта: собери любое тело и призови любого врага, чтобы проверить его" + (" · поколение %d" % sand.generation if sand else ""), 17)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(note)
	col.add_child(bottom)

func _slot_card(slot: int) -> PanelContainer:
	var evo := Saves.load_slot(slot)
	var box := Kit.vbox(10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := Kit.hbox(8)
	var cap := Kit.label("Ячейка %d" % slot, 18, Art.MUTED)
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(cap)
	if evo:
		# Удалить — маленькой кнопкой в углу, и только со второго нажатия.
		if _arming == slot:
			var sure := _button("Удалить насовсем?", Color(0.62, 0.2, 0.22), func():
				Saves.delete_slot(slot)
				_arming = -1
				rebuild())
			sure.custom_minimum_size = Vector2(0, 44)
			sure.add_theme_font_size_override("font_size", 18)
			head.add_child(sure)
			var no := _button("Нет", Art.CARD_BORDER, func():
				_arming = -1
				rebuild())
			no.custom_minimum_size = Vector2(70, 44)
			no.add_theme_font_size_override("font_size", 18)
			head.add_child(no)
		else:
			var del := RoundButton.new()
			del.setup("trash", "Удалить", 44)
			del.pressed.connect(func():
				_arming = slot
				rebuild())
			head.add_child(del)
	else:
		head.custom_minimum_size.y = 44
	box.add_child(head)
	if evo:
		var pic := SlotPic.new()
		pic.evo = evo
		pic.custom_minimum_size = Vector2(0, 110)
		box.add_child(pic)
		var name := Kit.label(evo.name, 30, Art.TEXT, true)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(name)
		var minutes := int(evo.played / 60.0)
		var facts := Kit.muted("Размер %d · поколение %d · частей %d/%d\n%s · %s" % [evo.level(), evo.generation, evo.unlocked.size(),
			Content.PARTS.values().filter(func(p): return p.get("source", "") != "mob").size(),
			Content.DIFFICULTY[evo.difficulty].name, "%d ч %d мин" % [minutes / 60, minutes % 60] if minutes >= 60 else "%d мин" % minutes], 17)
		facts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(facts)
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(spacer)
		if evo.arena_best > 0:
			var rec := Kit.muted("Рекорд арены: %d волн" % evo.arena_best, 16)
			rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(rec)
		var row := Kit.hbox(10)
		var go := _button("Играть", Art.GREEN, func(): play.emit(slot))
		go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		go.custom_minimum_size.y = 60
		go.add_theme_font_size_override("font_size", 25)
		row.add_child(go)
		var ar := _button("Арена", Color("#8a6a2a"), func(): arena.emit(slot))
		ar.custom_minimum_size = Vector2(110, 60)
		row.add_child(ar)
		box.add_child(row)
	else:
		# Новая игра: сначала выбрать сложность, потом «Начать» — случайно не начнёшь.
		var plus := PlusMark.new()
		plus.custom_minimum_size = Vector2(0, 76)
		box.add_child(plus)
		var title := Kit.label("Новая игра", 28, Art.TEXT, true)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(title)
		var d: String = _diff.get(slot, "normal")
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		for id: String in ["easy", "normal", "hard", "insane"]:
			var on: bool = id == d
			var bg := (Color("#a8334a") if id == "insane" else Art.GREEN) if on else Color(1, 1, 1, 0.05)
			var b := _button(Content.DIFFICULTY[id].name, bg, func():
				_diff[slot] = id
				rebuild())
			if on and id == "insane":
				for c in ["font_color", "font_hover_color", "font_pressed_color"]:
					b.add_theme_color_override(c, Art.TEXT)
			b.custom_minimum_size.y = 46
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.add_theme_font_size_override("font_size", 18)
			grid.add_child(b)
		box.add_child(grid)
		var hint := Kit.muted(Content.DIFFICULTY[d].hint, 16)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(hint)
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(spacer)
		var start := _button("Начать", Color("#a8334a") if d == "insane" else Art.GREEN, func(): new_game.emit(slot, d))
		if d == "insane":
			for c in ["font_color", "font_hover_color", "font_pressed_color"]:
				start.add_theme_color_override(c, Art.TEXT)
		start.custom_minimum_size.y = 60
		start.add_theme_font_size_override("font_size", 25)
		box.add_child(start)
	var card := Kit.card(box, Color(0.08, 0.14, 0.18, 0.92), 24, 18)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return card

func _button(text: String, bg: Color, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_font_size_override("font_size", 22)
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, Kit.box(bg, 18))
	var fg := Art.BG if bg == Art.GREEN else Art.TEXT
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.pressed.connect(action)
	Kit.press_fx(b)
	return b

## Портрет сохранённого вида.
class SlotPic:
	extends Control
	var evo: Evolution
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.26
		CellArt.creature(self, size / 2.0, r, -PI / 2.0, Color(Content.COLORS[evo.color]), evo.body_parts(), t, {"shape": evo.shape, "shadow": false})

## Большой плюс в круге — «здесь можно начать».
class PlusMark:
	extends Control

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) * 0.46
		draw_circle(c, r, Color(Art.GREEN, 0.1))
		draw_arc(c, r, 0, TAU, 48, Color(Art.GREEN, 0.35), 2.0, true)
		Icons.draw(self, "plus", Rect2(c - Vector2(r, r) * 0.55, Vector2(r, r) * 1.1), Art.GREEN)
