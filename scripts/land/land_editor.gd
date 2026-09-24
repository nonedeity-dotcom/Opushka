## Редактор тела для суши. Слева — твоё существо в 3D: его можно крутить пальцем, оно
## дышит, машет хвостом и, когда меняешь ноги, проходится по кругу. Справа — места тела
## (рот, глаза, ноги…) и части для выбранного места: нажал — поставил, ДНК списалась;
## «Снять» — вернулась. Сверху — сколько ДНК свободно и что умеет тело.
##
## В первый раз поверх — «Выход на сушу»: что из клетки осталось (и во что превратилось),
## а что ушло — с ДНК, которая за это вернулась.
extends Control

signal done
## Для звука: ok — поставилось, false — не хватило ДНК; removed — сняли.
signal changed(ok: bool, removed: bool)

const DragScroll := preload("res://scripts/ui/drag_scroll.gd")

var evo: Evolution
var first := false
var slot := "legs"
var _view: SubViewport
var _box: SubViewportContainer
var _cam: Camera3D
var _creature: Creature3D
var _yaw := 0.6
var _walk_t := 0.0
var _walk_a := 0.0
var _pos := Vector3.ZERO
var _heading := 0.0
var _drag := -1
var _idle := 0.0
var _panel: VBoxContainer
var _tabs: GridContainer
var _list: VBoxContainer
var _scroll: ScrollContainer
var _dna: Label
var _stats: HFlowContainer
var _msg: Label
var _msg_tw: Tween
var _overlay: Control
var _start_body := {}
var _done_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)

## Открыть редактор. conv — что стало с частями клетки (только в первый раз).
func open(e: Evolution, is_first: bool, conv := {}) -> void:
	evo = e
	first = is_first
	_start_body = evo.land_body.duplicate()
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()
	_build_preview()
	_build_panel()
	_layout()
	_rebuild_creature()
	_refresh()
	if not conv.is_empty():
		_show_overlay(conv)
	visible = true

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0e1a20"))

# --- 3D-витрина -----------------------------------------------------------------------

func _build_preview() -> void:
	_box = SubViewportContainer.new()
	_box.stretch = true
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_2X
	_box.add_child(_view)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#9fd0e8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#cfe6f0")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("#9fd0e8")
	env.fog_density = 0.02
	var we := WorldEnvironment.new()
	we.environment = env
	_view.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(-30.0), 0.0)
	sun.light_color = Color("#fff4e0")
	_view.add_child(sun)
	# Полянка: травяной круг, по краю песок, пара кустиков.
	var sand := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 7.0
	sm.bottom_radius = 7.2
	sm.height = 0.3
	sm.radial_segments = 40
	sand.mesh = sm
	sand.material_override = Creature3D.mat(Color("#e2cf92"), 1.0)
	sand.position.y = -0.16
	_view.add_child(sand)
	var grass := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = 5.2
	gm.bottom_radius = 5.2
	gm.height = 0.3
	gm.radial_segments = 40
	grass.mesh = gm
	grass.material_override = Creature3D.mat(Color("#7cc25a"), 1.0)
	grass.position.y = -0.14
	_view.add_child(grass)
	for q in [Vector3(-3.6, 0.4, -2.6), Vector3(3.2, 0.35, -3.2), Vector3(-2.8, 0.3, 3.4)]:
		var b := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 0.7
		bm.height = 1.0
		bm.radial_segments = 10
		bm.rings = 5
		b.mesh = bm
		b.material_override = Creature3D.mat(Color("#4fa84a"), 0.9)
		b.position = q
		_view.add_child(b)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_view.add_child(_cam)
	_creature = Creature3D.new()
	_creature.ground = func(_x: float, _z: float) -> float: return 0.0
	_view.add_child(_creature)

func _rebuild_creature() -> void:
	var c := Color(Content.COLORS[evo.color])
	var c2 := Color(Content.COLORS[evo.color2]) if evo.pattern != "none" else c.darkened(0.25)
	_creature.build_body(c, c2, 1.0, evo.land_body, evo.pattern, Content.shape_stats(evo.shape).elong)
	_creature.scale = Vector3.ONE * 0.85
	var tw := _creature.create_tween()
	tw.tween_property(_creature, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if not visible or _creature == null:
		return
	_idle += delta
	if _drag == -1 and _idle > 2.0:
		_yaw += delta * 0.25
	# Походка: пару кругов по полянке, потом снова стоит.
	var vel := Vector3.ZERO
	if _walk_t > 0.0:
		_walk_t -= delta
		var spd := 2.2 * float(LandParts.stats(evo.land_body).speed)
		_walk_a += delta * spd / 2.2
		var next := Vector3(sin(_walk_a) * 2.2, 0.0, cos(_walk_a) * 2.2 - 0.0)
		vel = (next - _pos) / maxf(delta, 0.001)
		_pos = next
		_heading = atan2(vel.x, vel.z)
	elif _pos.length() > 0.05:
		# Вернуться в середину.
		var to := -_pos
		var step := minf(to.length(), delta * 2.0)
		vel = to.normalized() * 2.0
		_pos += to.normalized() * step
		_heading = lerp_angle(_heading, atan2(to.x, to.z), 1.0 - exp(-6.0 * delta))
	else:
		_heading = lerp_angle(_heading, 0.0, 1.0 - exp(-3.0 * delta))
	_creature.update(delta, _pos, _heading, vel)
	# Плашки свойств — у нижнего края витрины, в одну или две строки.
	_stats.position.y = _box.size.y - _stats.get_combined_minimum_size().y - 16
	var dist := 7.5 if _walk_t > 0.0 or _pos.length() > 0.3 else 5.2
	var target := Vector3(0, 0.75, 0)
	var want := target + Vector3(sin(_yaw) * dist, 2.4 + dist * 0.12, cos(_yaw) * dist)
	_cam.position = _cam.position.lerp(want, 1.0 - exp(-5.0 * delta)) if _cam.position != Vector3.ZERO else want
	_cam.look_at(target, Vector3.UP)

## Палец по витрине — повернуть существо.
func _input(e: InputEvent) -> void:
	if not is_visible_in_tree() or _box == null or (_overlay and _overlay.visible):
		return
	if e is InputEventScreenTouch:
		if e.pressed and _drag == -1 and _box.get_global_rect().has_point(e.position):
			_drag = e.index
			_idle = 0.0
		elif not e.pressed and e.index == _drag:
			_drag = -1
	elif e is InputEventScreenDrag and e.index == _drag:
		_yaw -= e.relative.x * 0.01
		_idle = 0.0

# --- правая панель --------------------------------------------------------------------

func _build_panel() -> void:
	_panel = Kit.vbox(10)
	add_child(_panel)
	var head := Kit.hbox(10)
	var title := Kit.label("Тело для суши", 30, Art.TEXT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_dna = Kit.label("", 22, Art.GREEN, true)
	_dna.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_dna)
	_panel.add_child(head)
	_tabs = GridContainer.new()
	_tabs.columns = 5
	_tabs.add_theme_constant_override("h_separation", 6)
	_tabs.add_theme_constant_override("v_separation", 6)
	_panel.add_child(_tabs)
	_scroll = DragScroll.new()
	_list = Kit.vbox(8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_panel.add_child(_scroll)
	_done_btn = _button("Выйти на сушу" if first else "Готово", Art.GREEN, func(): done.emit())
	_done_btn.custom_minimum_size.y = 60
	_done_btn.add_theme_font_size_override("font_size", 25)
	var bottom := Kit.hbox(10)
	var reset := _button("Как было", Art.CARD_BORDER, func():
		evo.land_body = _start_body.duplicate()
		changed.emit(true, true)
		_after_change.call_deferred("Вернул, как было"))
	reset.custom_minimum_size = Vector2(150, 60)
	reset.add_theme_font_size_override("font_size", 20)
	bottom.add_child(reset)
	_done_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_done_btn)
	_panel.add_child(bottom)
	# Что умеет тело — поверх витрины, снизу.
	_stats = HFlowContainer.new()
	_stats.add_theme_constant_override("h_separation", 8)
	_stats.add_theme_constant_override("v_separation", 8)
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stats)
	_msg = Kit.label("", 22, Art.TEXT, true)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.add_theme_constant_override("outline_size", 8)
	_msg.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	_msg.modulate.a = 0.0
	add_child(_msg)

func _layout() -> void:
	if _box == null:
		return
	var landscape := size.x >= size.y
	if landscape:
		var w := minf(size.x * 0.46, 700.0)
		_box.position = Vector2.ZERO
		_box.size = Vector2(size.x - w - 12, size.y)
		_panel.position = Vector2(size.x - w, 16)
		_panel.size = Vector2(w - 18, size.y - 32)
		_tabs.columns = 5
	else:
		var h := size.y * 0.42
		_box.position = Vector2.ZERO
		_box.size = Vector2(size.x, h)
		_panel.position = Vector2(16, h + 8)
		_panel.size = Vector2(size.x - 32, size.y - h - 24)
		_tabs.columns = 5
	_stats.size = Vector2(_box.size.x - 32, 0)
	_stats.position = Vector2(16, _box.size.y - 60)
	_msg.position = Vector2(0, 24)
	_msg.size = Vector2(_box.size.x, 40)
	if _overlay:
		_overlay.size = size

func _refresh() -> void:
	_dna.text = "ДНК: %d" % evo.land_free()
	_dna.add_theme_color_override("font_color", Art.GREEN if evo.land_free() >= 0 else Art.DANGER)
	# Места тела.
	for ch in _tabs.get_children():
		_tabs.remove_child(ch)
		ch.queue_free()
	for s in LandParts.SLOTS:
		var id: String = s[0]
		var t := SlotTab.new()
		t.icon = s[2]
		t.text = s[1]
		t.on = id == slot
		t.filled = evo.land_body.has(id) and not (id == "legs" and evo.land_body[id] == "stubs")
		t.custom_minimum_size = Vector2(0, 74)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Перестраивать список — после касания, не посреди него (иначе кнопка уже вне дерева).
		t.pressed.connect(func():
			slot = id
			_scroll.scroll_vertical = 0
			_refresh.call_deferred())
		_tabs.add_child(t)
	# Части для места.
	for ch in _list.get_children():
		_list.remove_child(ch)
		ch.queue_free()
	var cur: String = evo.land_body.get(slot, "")
	var hint := Kit.muted(_slot_hint(slot), 17)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(hint)
	if cur != "" and not (slot == "legs" and cur == "stubs"):
		var off := _button("Снять: %s  (+%d ДНК)" % [String(LandParts.PARTS[cur].name).to_lower(), int(LandParts.PARTS[cur].cost)], Color(0.4, 0.2, 0.22), func():
			var r := evo.land_take(slot)
			changed.emit(r.ok, true)
			_after_change.call_deferred(r.message))
		off.custom_minimum_size.y = 48
		off.add_theme_font_size_override("font_size", 19)
		_list.add_child(off)
	var ids := LandParts.in_slot(slot)
	ids.sort_custom(func(a, b): return int(LandParts.PARTS[a].cost) < int(LandParts.PARTS[b].cost))
	for id in ids:
		_list.add_child(_part_card(id, id == cur))
	# Статы.
	for ch in _stats.get_children():
		_stats.remove_child(ch)
		ch.queue_free()
	var st := LandParts.stats(evo.land_body)
	var chips := [["dash", "Скорость %d%%" % int(round(st.speed * 100.0))], ["bite", "Укус %d" % int(st.bite)],
		["heart", "Здоровье %d" % int(st.hp)], ["eye", "Зрение %d%%" % int(round(st.sight * 100.0))]]
	if st.armor > 0.0:
		chips.append(["shield", "Броня %d%%" % int(round(st.armor * 100.0))])
	if not st.mouth:
		chips.append(["close", "Без рта не ешь"])
	for c in chips:
		_stats.add_child(Kit.info_chip(c[0], c[1]))

func _slot_hint(s: String) -> String:
	match s:
		"mouth":
			return "Рот решает, что тебе вкуснее: плоды или мясо с яйцами, и как больно кусаешь."
		"eyes":
			return "Без глаз вокруг туман. Чем лучше глаза, тем дальше видно."
		"legs":
			return "Ноги — это скорость. Без ног никак: снимешь — останутся короткие лапки."
		"feet":
			return "Ступни: тише, быстрее или по воде."
		"claws":
			return "Когти — на каждой ноге: бьёшь сильнее, кости крошатся быстрее."
		"arms":
			return "Руки спереди: дотягиваешься дальше и бьёшь сильнее."
		"back":
			return "Спина: шипы дают сдачи, пластины защищают, парус лечит."
		"tail":
			return "Хвост: равновесие или булава."
		"head":
			return "Голова: рога бодают, гребень пугает бродяг."
		"skin":
			return "Кожа: мех — здоровье, чешуя — броня, яд — отравляет кусачих."
	return ""

func _part_card(id: String, on: bool) -> Control:
	var p: Dictionary = LandParts.PARTS[id]
	var cost: int = p.cost
	var free := evo.land_free()
	var cur: String = evo.land_body.get(slot, "")
	if cur != "":
		free += int(LandParts.PARTS[cur].cost)
	var can := on or cost <= free
	var col := Kit.vbox(4)
	var row := Kit.hbox(8)
	var name := Kit.label(p.name, 23, Art.TEXT if can else Art.MUTED, true)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	var price := Kit.label("стоит" if on else ("даром" if cost == 0 else "%d ДНК" % cost), 20,
		Art.GREEN if on else (Art.GOLD if can else Art.DANGER), true)
	row.add_child(price)
	col.add_child(row)
	var sum := LandParts.summary(id)
	if sum != "":
		var s := Kit.label(sum, 17, Art.GREEN if can else Art.MUTED)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(s)
	var h := Kit.muted(p.hint, 16)
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(h)
	var card := Kit.card(col, Color(0.16, 0.3, 0.26, 0.95) if on else Art.CARD, 16, 12)
	if on:
		card.add_theme_stylebox_override("panel", Kit.box(Color(0.16, 0.3, 0.26, 0.95), 16, Art.GREEN, 12))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(ev: InputEvent):
		var tap: bool = (ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT)
		if tap and not on and not _scroll.get("_dragging"):
			card.accept_event()
			put.call_deferred(id))
	return card

## Поставить часть (кнопкой или из сценария проверки).
func put(id: String) -> void:
	var r := evo.land_put(id)
	changed.emit(r.ok, false)
	if r.ok and LandParts.PARTS[id].slot in ["legs", "feet", "claws", "tail", "arms"]:
		_walk_t = 4.0
	_after_change(r.message)

func _after_change(message: String) -> void:
	_rebuild_creature()
	_refresh()
	if message == "":
		return
	_msg.text = message
	if _msg_tw:
		_msg_tw.kill()
	_msg.modulate.a = 1.0
	_msg_tw = create_tween()
	_msg_tw.tween_interval(1.5)
	_msg_tw.tween_property(_msg, "modulate:a", 0.0, 0.5)

# --- первый выход: что стало с частями клетки -----------------------------------------

func _show_overlay(conv: Dictionary) -> void:
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.size = size
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.06, 0.08, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var col := Kit.vbox(10)
	var t := Kit.label("Выход на сушу", 34, Art.TEXT, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var sub := Kit.muted("%s готовится выйти из воды. Тело придётся перестроить: плавать больше не нужно, нужно ходить." % evo.name, 19)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var cols := Kit.hbox(18)
	var left := Kit.vbox(6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(Kit.label("Остаётся", 22, Art.GREEN, true))
	if conv.kept.is_empty():
		left.add_child(Kit.muted("ничего", 18))
	for k in conv.kept:
		var l := Kit.label("%s → %s" % [Content.PARTS[k[0]].name, LandParts.PARTS[k[1]].name], 19)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		left.add_child(l)
	left.add_child(Kit.label("+ короткие лапки — даром", 19, Art.MUTED))
	cols.add_child(left)
	var right := Kit.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(Kit.label("Уходит — ДНК возвращается", 22, Art.GOLD, true))
	if conv.gone.is_empty():
		right.add_child(Kit.muted("ничего", 18))
	for g in conv.gone:
		var l := Kit.label("%s — %s  +%d" % [Content.PARTS[g[0]].name, g[1], int(Content.PARTS[g[0]].cost)], 19)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		right.add_child(l)
	cols.add_child(right)
	col.add_child(cols)
	var total := Kit.label("Свободно ДНК: %d — трать на ноги, когти, руки…" % evo.land_free(), 22, Art.TEXT, true)
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(total)
	var go := _button("Собрать тело", Art.GREEN, close_overlay)
	go.custom_minimum_size = Vector2(320, 60)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(go)
	var card := Kit.card(col, Color(0.08, 0.14, 0.18, 0.97), 26, 24)
	card.custom_minimum_size.x = minf(size.x - 40, 980)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_overlay.add_child(card)
	Kit.pop_in(card)

func close_overlay() -> void:
	if _overlay:
		_overlay.visible = false
		_overlay.queue_free()
		_overlay = null
		_walk_t = 3.0

func _button(text: String, bg: Color, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_font_size_override("font_size", 22)
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, Kit.box(bg, 16))
	var fg := Art.BG if bg == Art.GREEN else Art.TEXT
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, fg)
	b.pressed.connect(action)
	Kit.press_fx(b)
	return b

## Плитка места тела: значок, подпись; точка — если на месте что-то стоит.
class SlotTab:
	extends Control
	signal pressed
	var icon := ""
	var text := ""
	var on := false
	var filled := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			accept_event()
			pressed.emit()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(Kit.box(Color(0.16, 0.3, 0.26, 1.0) if on else Art.CARD, 14, Art.GREEN if on else Art.CARD_BORDER, 0), r)
		var s := 30.0
		Icons.draw(self, icon, Rect2(size.x / 2.0 - s / 2.0, 8, s, s), Art.GREEN if on else Art.TEXT)
		var font := get_theme_default_font()
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(font, Vector2((size.x - w) / 2.0, size.y - 12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Art.TEXT if on else Art.MUTED)
		if filled:
			draw_circle(Vector2(size.x - 12, 12), 5, Art.GOLD)
