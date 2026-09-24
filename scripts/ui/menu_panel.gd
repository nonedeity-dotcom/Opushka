## Главное меню: три ячейки сохранений. В пустой — новая игра с выбором сложности.
extends Control

signal play(slot: int)
signal new_game(slot: int, difficulty: String)

var t := 0.0
var _row: HBoxContainer
var _arming := -1
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
	var col := Kit.vbox(18)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 40
	col.offset_right = -40
	col.offset_top = 30
	col.offset_bottom = -30
	add_child(col)
	var title := Kit.label("Эволюция", 64, Art.TEXT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := Kit.label("от одной клетки — к своему виду", 24, Art.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	_row = Kit.hbox(18)
	_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_row)
	for slot in range(1, Saves.COUNT + 1):
		_row.add_child(_slot_card(slot))

func _slot_card(slot: int) -> PanelContainer:
	var evo := Saves.load_slot(slot)
	var box := Kit.vbox(10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(Kit.label("Ячейка %d" % slot, 20, Art.MUTED))
	if evo:
		var pic := SlotPic.new()
		pic.evo = evo
		pic.custom_minimum_size = Vector2(0, 120)
		box.add_child(pic)
		box.add_child(Kit.label(evo.name, 28, Art.TEXT, true))
		box.add_child(Kit.muted("Размер %d · поколение %d · частей %d/%d" % [evo.level(), evo.generation, evo.unlocked.size(), Content.PARTS.values().filter(func(p): return p.get("source", "") != "mob").size()], 18))
		var minutes := int(evo.played / 60.0)
		box.add_child(Kit.muted("Сложность: %s · %s" % [Content.DIFFICULTY[evo.difficulty].name.to_lower(), "%d ч %d мин" % [minutes / 60, minutes % 60] if minutes >= 60 else "%d мин" % minutes], 18))
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(spacer)
		box.add_child(_button("Играть", Art.GREEN, func(): play.emit(slot)))
		var del := _button("Точно удалить? Нажми ещё раз" if _arming == slot else "Удалить", Color(0.5, 0.2, 0.2, 0.7), func():
			if _arming == slot:
				Saves.delete_slot(slot)
				_arming = -1
			else:
				_arming = slot
			rebuild())
		del.custom_minimum_size.y = 44
		box.add_child(del)
	else:
		box.add_child(Kit.label("Пусто", 28, Art.TEXT, true))
		box.add_child(Kit.muted("Новая игра — с одной клетки. Выбери сложность:", 18))
		for d in ["easy", "normal", "hard"]:
			var def: Dictionary = Content.DIFFICULTY[d]
			var b := _button(def.name, Art.GREEN if d == "normal" else Art.CARD_BORDER, func(): new_game.emit(slot, d))
			b.tooltip_text = def.hint
			box.add_child(b)
			box.add_child(Kit.muted(def.hint, 15))
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
