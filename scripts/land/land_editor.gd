## Редактор тела для суши.
##
## Как устроен экран — чтобы существо было главным и его было видно целиком:
## - вся витрина — 3D-полянка с твоим существом. Палец по пустому месту — повернуть,
##   двумя пальцами — приблизить или отдалить;
## - сверху тонкая полоса: «Отменить» (по шагу), ДНК, что умеет тело, «Готово»;
## - снизу — разделы значками (тело, рот, глаза, ноги…). Нажал раздел — над ним выезжает
##   ряд карточек частей (листается пальцем вбок). Нажал карточку — часть встала;
## - нажал на часть самого существа — она мерцает, справа выезжает её панель: длина,
##   ширина, высота, размер (и что ещё есть у этой части), а на существе — кружки только
##   этой части: тяни их, чтобы лепить. Нажал мимо — панель уходит.
##
## В первый раз поверх — «Выход на сушу»: что из клетки осталось (и во что превратилось),
## а что ушло — с ДНК, которая за это вернулась.
extends Control

signal done
## Для звука: ok — поставилось, false — не хватило ДНК; removed — сняли.
signal changed(ok: bool, removed: bool)

const DragScroll := preload("res://scripts/ui/drag_scroll.gd")
const RoundButton := preload("res://scripts/ui/round_button.gd")

var evo: Evolution
var first := false
## Открытый раздел снизу ("" — ряд карточек спрятан).
var slot := ""
## Выбранная часть существа ("" — ничего, панель справа спрятана): torso, head, mouth,
## eyes, horns, back, tail, leg0…leg5, arm0, arm1.
var sel := ""
## Менять пару вместе: левую и правую ногу (руку) одинаково.
var mirror := true
var collapsed := false

var _view: SubViewport
var _box: SubViewportContainer
var _cam: Camera3D
var _creature: Creature3D
var _yaw := PI / 2.0
var _yaw_to := 1000.0
var _zoom := 1.0
var _walk_t := 0.0
var _walk_a := 0.0
var _pos := Vector3.ZERO
var _heading := 0.0
var _hofs := 0.0
var _vofs := 0.0
## Пальцы на витрине: номер → где. Один — поворот или лепка, два — приблизить.
var _fingers := {}
var _pinch_d := 0.0
var _drag := -1
var _press_at := Vector2.ZERO
var _tap := false
var _grab := ""
var _dirty := false
var _rebuild_in := 0.0
var _handles: Control

var _top: PanelContainer
var _undo_btn: Button
var _dna: Label
var _stats: HBoxContainer
var _done_btn: Button
var _catbar: PanelContainer
var _cats: HBoxContainer
var _drawer: PanelContainer
var _drawer_box: VBoxContainer
var _insp: PanelContainer
var _insp_icon: Control
var _insp_title: Label
var _insp_sub: Label
var _insp_list: VBoxContainer
## Прокрутка панели выбранной части (ползунок, пока его тянут, её останавливает).
var _scroll: ScrollContainer
var _msg: Label
var _msg_tw: Tween
var _overlay: Control
var _start_body := {}
var _start_shape := {}
var _start_paint := {}
var _undo: Array = []
var _redo: Array = []
var _redo_btn: Button
## Наклон камеры: 0 — вровень с землёй, ~1,35 — сверху.
var _elev := 0.28
## Ряд кнопок под верхней полосой: виды, приближение, анимации.
var _tools: HFlowContainer
## Анимация в витрине: бег (шаг быстрее), прыжок, укусы.
var _run := false
var _jump_t := -1.0
var _bites := 0
var _bite_in := 0.0
## Несём часть с карточки на существо: что, где палец, каким пальцем.
var _carry := ""
var _carry_at := Vector2.ZERO
var _finger_at := Vector2.ZERO
var _arming_clear := false

const TOP_H := 70.0
const CAT_H := 96.0
const INSP_W := 360.0

## Кружки лепки у выбранной части: [ручка, вид]. Вид: move — тянуть куда угодно,
## girth — толщина туловища, len — длина туловища, size — размер, thick — толщина,
## updown — выше/ниже.
const SEL_HANDLES := {
	"torso": [["g0", "girth"], ["g1", "girth"], ["g2", "girth"], ["g3", "girth"], ["g4", "girth"],
		["len_back", "len"], ["len_front", "len"], ["width", "thick"], ["tilt", "move"]],
	"head": [["head", "move"], ["head_size", "size"]],
	"leg": [["legs", "updown"], ["legs_back", "updown"], ["leg_thick", "thick"], ["feet", "size"]],
	"arm": [["arms", "move"], ["arm_thick", "thick"]],
	"tail": [["tail", "move"], ["tail_base", "thick"]],
	"mouth": [["mouth", "size"]],
	"eyes": [["eyes", "size"]],
	"horns": [["horns", "size"]],
	"back": [["back", "size"]],
}
## С какой стороны смотреть на место: сбоку или вполоборота спереди.
const VIEW_YAW := {"torso": PI / 2.0, "legs": PI / 2.0, "tail": PI / 2.0 + 0.5, "back": PI / 2.0,
	"mouth": 0.8, "eyes": 0.6, "head": 0.8, "arms": 0.9, "feet": 0.9, "claws": 0.7, "skin": 0.9, "paint": 0.9}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)

## Открыть редактор. conv — что стало с частями клетки (только в первый раз).
func open(e: Evolution, is_first: bool, conv := {}) -> void:
	evo = e
	first = is_first
	if evo.land_shape.is_empty():
		evo.land_shape = LandParts.shape_from_sea(evo.shape)
	evo.land_shape = LandParts.fix_shape(evo.land_shape)
	if evo.land_paint.is_empty():
		evo.land_paint = evo.paint().duplicate()
	_start_body = evo.land_body.duplicate()
	_start_shape = evo.land_shape.duplicate(true)
	_start_paint = evo.land_paint.duplicate()
	_undo.clear()
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()
	_build_preview()
	_build_ui()
	slot = "" if evo.land_body.has("torso") else "torso"
	sel = ""
	_rebuild_creature()
	_refresh()
	visible = true
	if not conv.is_empty():
		_show_overlay(conv)
	else:
		_toast("Нажми на часть существа — появятся её размеры. Внизу — части")

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0e1a20"))

# --- интерфейс ------------------------------------------------------------------------

func _panel(bg: Color, radius := 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.box(bg, radius, Color(1, 1, 1, 0.06), 10))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p

func _build_ui() -> void:
	_handles = HandleLayer.new()
	_handles.ed = self
	add_child(_handles)
	# Сверху: отменить, ДНК, что умеет тело, готово.
	_top = _panel(Color(0.04, 0.08, 0.1, 0.86), 22)
	add_child(_top)
	var row := Kit.hbox(12)
	_top.add_child(row)
	_undo_btn = RoundButton.new()
	_undo_btn.setup("undo", "Отменить", 50)
	_undo_btn.pressed.connect(undo)
	row.add_child(_undo_btn)
	_redo_btn = RoundButton.new()
	_redo_btn.setup("redo", "Вернуть", 50)
	_redo_btn.pressed.connect(redo)
	row.add_child(_redo_btn)
	_dna = Kit.label("", 24, Art.GREEN, true)
	_dna.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_dna)
	_stats = Kit.hbox(8)
	_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stats.clip_contents = true
	row.add_child(_stats)
	_done_btn = _button("Выйти на сушу" if first else "Готово", Art.GREEN, try_done)
	_done_btn.custom_minimum_size = Vector2(210, 50)
	row.add_child(_done_btn)
	# Под полосой — виды камеры, приближение и анимации.
	_tools = HFlowContainer.new()
	_tools.add_theme_constant_override("h_separation", 6)
	_tools.add_theme_constant_override("v_separation", 6)
	add_child(_tools)
	for t in [["Сбоку", func(): view(PI / 2.0, 0.12)], ["Спереди", func(): view(0.0, 0.12)], ["Сверху", func(): view(_yaw, 1.35)],
			["+", func(): _zoom = clampf(_zoom / 1.25, 0.45, 2.2)], ["−", func(): _zoom = clampf(_zoom * 1.25, 0.45, 2.2)],
			["Шаг", func(): anim("walk")], ["Бег", func(): anim("run")], ["Укус", func(): anim("bite")], ["Прыжок", func(): anim("jump")]]:
		var b := _button(t[0], Color(0.04, 0.08, 0.1, 0.78), t[1])
		b.custom_minimum_size = Vector2(56 if t[0].length() <= 1 else 0, 42)
		b.add_theme_font_size_override("font_size", 17)
		_tools.add_child(b)
	# Снизу: разделы значками.
	_catbar = _panel(Color(0.04, 0.08, 0.1, 0.9), 22)
	add_child(_catbar)
	var cs := TouchHScroll.new()
	_catbar.add_child(cs)
	_cats = Kit.hbox(6)
	cs.add_child(_cats)
	# Над разделами — ряд карточек открытого раздела.
	_drawer = _panel(Color(0.06, 0.1, 0.13, 0.94))
	add_child(_drawer)
	_drawer_box = Kit.vbox(6)
	_drawer.add_child(_drawer_box)
	# Справа — панель выбранной части.
	_insp = _panel(Color(0.06, 0.1, 0.13, 0.94))
	add_child(_insp)
	var col := Kit.vbox(6)
	_insp.add_child(col)
	var head := Kit.hbox(8)
	_insp_icon = PartIcon.new()
	_insp_icon.custom_minimum_size = Vector2(48, 48)
	head.add_child(_insp_icon)
	var names := Kit.vbox(0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_insp_title = Kit.label("", 19, Art.TEXT, true)
	# Длинное имя («Рука — правая, 2-я пара») переносится, а не обрезается.
	_insp_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(_insp_title)
	_insp_sub = Kit.label("", 16, Art.MUTED)
	_insp_sub.clip_text = true
	names.add_child(_insp_sub)
	head.add_child(names)
	var close := RoundButton.new()
	close.setup("close", "Закрыть", 42)
	close.pressed.connect(func():
		select("")
		_refresh.call_deferred())
	head.add_child(close)
	col.add_child(head)
	_scroll = DragScroll.new()
	_insp_list = Kit.vbox(4)
	_insp_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_insp_list)
	col.add_child(_scroll)
	_msg = Kit.label("", 22, Art.TEXT, true)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.add_theme_constant_override("outline_size", 8)
	_msg.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg.modulate.a = 0.0
	add_child(_msg)

func _drawer_h() -> float:
	return 262.0 if slot == "paint" else 206.0

## Вырез камеры и закруглённые углы: безопасная зона экрана, переведённая в наши точки
## (как у экрана океана) — плашки не уходят под них.
func _safe() -> Rect2:
	var win := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if win.x <= 0 or safe.size.x <= 0:
		return Rect2(Vector2.ZERO, size)
	var k := size / win
	return Rect2(safe.position * k, safe.size * k).intersection(Rect2(Vector2.ZERO, size))

func _layout() -> void:
	if _box == null or _top == null:
		return
	# Поля: от края экрана (и выреза) — как у остального интерфейса игры.
	var safe := _safe()
	var m := 12.0
	var x0 := safe.position.x + m
	var y0 := safe.position.y + m
	var w := safe.size.x - 2.0 * m
	var yb := safe.end.y - m
	_box.position = Vector2.ZERO
	_box.size = size
	_handles.position = Vector2.ZERO
	_handles.size = size
	_top.position = Vector2(x0, y0)
	_top.size = Vector2(w, TOP_H)
	_catbar.position = Vector2(x0, yb - CAT_H)
	_catbar.size = Vector2(w, CAT_H)
	var h := yb
	var narrow := w < 1000.0
	var ins_on := sel != "" and not collapsed
	var dr_on := slot != "" and not collapsed and not (narrow and ins_on)
	_insp.visible = ins_on
	_drawer.visible = dr_on
	var iw := minf(INSP_W, w)
	var top_end := y0 + TOP_H + 8.0
	if ins_on:
		if narrow:
			_insp.position = Vector2(x0, h - CAT_H - 338)
			_insp.size = Vector2(w, 330)
		else:
			_insp.position = Vector2(x0 + w - iw, top_end)
			_insp.size = Vector2(iw, h - CAT_H - 8.0 - top_end)
	if dr_on:
		var dh := _drawer_h()
		var dw := w - (iw + 8.0 if ins_on and not narrow else 0.0)
		_drawer.position = Vector2(x0, h - CAT_H - dh - 8)
		_drawer.size = Vector2(dw, dh)
	_tools.position = Vector2(x0, top_end)
	_tools.size = Vector2(w - (iw + 8.0 if ins_on and not narrow else 0.0), 0)
	_msg.position = Vector2(x0 + 10, top_end + maxf(_tools.get_combined_minimum_size().y, 42.0) + 10)
	_msg.size = Vector2(w - 20 - (iw + 8.0 if ins_on and not narrow else 0.0), 40)
	if _overlay:
		_overlay.size = size

## Куда на экране не падает интерфейс — там и держать существо.
func _free_rect() -> Rect2:
	var top := _tools.position.y + maxf(_tools.get_combined_minimum_size().y, 42.0)
	var r := Rect2(0, top, size.x, _catbar.position.y - top)
	if _drawer.visible:
		r.size.y -= _drawer.size.y + 8
	if _insp.visible and _insp.size.y > 340.0:
		r.size.x -= _insp.size.x + 10
	return r

## Касание пришлось на интерфейс (не на витрину).
func _ui_hit(p: Vector2) -> bool:
	for n in [_top, _catbar, _drawer, _insp, _tools]:
		if n.visible and n.get_global_rect().has_point(p):
			return true
	return _overlay != null and _overlay.visible

func _refresh() -> void:
	if _top == null:
		return
	_refresh_stats()
	_undo_btn.disabled = _undo.is_empty()
	_undo_btn.modulate.a = 0.4 if _undo.is_empty() else 1.0
	_redo_btn.disabled = _redo.is_empty()
	_redo_btn.modulate.a = 0.4 if _redo.is_empty() else 1.0
	# Разделы.
	for ch in _cats.get_children():
		_cats.remove_child(ch)
		ch.queue_free()
	var cc := _colors()
	for s in LandParts.SLOTS + [["paint", "Окрас", ""]]:
		var id: String = s[0]
		var t := CatButton.new()
		t.part = evo.land_body.get(id, LandIcons.SLOT_ICON.get(id, "body"))
		t.empty = id != "paint" and not evo.land_body.has(id)
		t.c = cc[0]
		t.c2 = cc[1]
		t.text = s[1]
		t.on = id == slot
		t.custom_minimum_size = Vector2(98, CAT_H - 16)
		t.pressed.connect(func(): open_slot.call_deferred(id))
		_cats.add_child(t)
	_fill_drawer()
	_fill_insp()
	_layout()

## Открыть раздел (или закрыть, если он уже открыт). Если в разделе что-то стоит — оно
## сразу выбирается, и справа видны его размеры.
func open_slot(id: String) -> void:
	_arming_clear = false
	if slot == id:
		slot = ""
		_refresh()
		return
	slot = id
	var d := _default_sel(id)
	select(d, true)
	changed.emit(true, false)
	_refresh()

## Что умеет тело — в полосе сверху.
func _refresh_stats() -> void:
	if _dna == null:
		return
	_dna.text = "ДНК %d" % evo.land_free()
	_dna.add_theme_color_override("font_color", Art.GREEN if evo.land_free() >= 0 else Art.DANGER)
	for ch in _stats.get_children():
		_stats.remove_child(ch)
		ch.queue_free()
	if not evo.land_body.has("torso"):
		_stats.add_child(Kit.info_chip("", "Пусто — начни с туловища", Art.GOLD))
		return
	var st := LandParts.stats(evo.land_body, evo.land_shape)
	var chips := [["dash", "%d%%" % int(round(st.speed * 100.0))], ["bite", "%d" % int(st.bite)],
		["heart", "%d" % int(st.hp)], ["eye", "%d%%" % int(round(st.sight * 100.0))]]
	if st.armor > 0.0:
		chips.append(["shield", "%d%%" % int(round(st.armor * 100.0))])
	if not evo.land_body.has("legs"):
		chips.append(["close", "нет ног"])
	elif not st.mouth:
		chips.append(["close", "нет рта"])
	for c in chips:
		_stats.add_child(Kit.info_chip(c[0], c[1]))

# --- ряд карточек ---------------------------------------------------------------------

func _fill_drawer() -> void:
	for ch in _drawer_box.get_children():
		_drawer_box.remove_child(ch)
		ch.queue_free()
	if slot == "":
		return
	if slot == "paint":
		_paint_drawer()
		return
	var head := Kit.hbox(10)
	var title := Kit.label(LandParts.slot_name(slot) if slot != "torso" else "Тело", 21, Art.TEXT, true)
	head.add_child(title)
	var hint := Kit.label(_slot_hint(slot), 16, Art.MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.clip_text = true
	head.add_child(hint)
	_drawer_box.add_child(head)
	var sc := TouchHScroll.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var row := Kit.hbox(10)
	sc.add_child(row)
	_drawer_box.add_child(sc)
	var cc := _colors()
	if slot == "torso":
		if not evo.land_body.has("torso"):
			row.add_child(_part_tile("torso", cc))
			var l := Kit.label("Пусто. Начни с туловища —\nк нему крепится всё остальное", 19, Art.GOLD)
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(l)
			return
		for i in PRESETS.size():
			var pr: Array = PRESETS[i]
			var pt := _action_tile(pr[0], "заготовка", "", func(): apply_preset(i))
			pt.part = "torso"
			pt.c = cc[0]
			pt.c2 = cc[1]
			row.add_child(pt)
		row.add_child(_action_tile("Сгладить", "толщину по спине", "check", func():
			_snap()
			var g: Array = evo.land_shape.girth
			var out: Array = []
			for i in g.size():
				var a: float = g[maxi(i - 1, 0)]
				var b: float = g[mini(i + 1, g.size() - 1)]
				out.append((a + float(g[i]) * 2.0 + b) / 4.0)
			evo.land_shape.girth = out
			_after_change.call_deferred("Сгладил")))
		row.add_child(_action_tile("Как в воде", "форма клетки", "dna", func():
			_snap()
			var keep: Dictionary = evo.land_shape.sizes
			var dims: Dictionary = evo.land_shape.dims
			evo.land_shape = LandParts.shape_from_sea(evo.shape)
			evo.land_shape.sizes = keep
			evo.land_shape.dims = dims
			_after_change.call_deferred("Как клетка в воде")))
		row.add_child(_action_tile("Как было", "в начале", "undo", func():
			_snap()
			evo.land_body = _start_body.duplicate()
			evo.land_shape = _start_shape.duplicate(true)
			evo.land_paint = _start_paint.duplicate()
			changed.emit(true, true)
			_after_change.call_deferred("Вернул, как было")))
		row.add_child(_action_tile("Точно? Убрать всё" if _arming_clear else "С нуля", "совсем пусто", "trash", func():
			if not _arming_clear:
				_arming_clear = true
				_refresh.call_deferred()
				return
			_arming_clear = false
			_snap()
			var r := evo.land_clear()
			select("")
			changed.emit(true, true)
			_after_change.call_deferred(r.message), _arming_clear))
		return
	var cur: String = evo.land_body.get(slot, "")
	if cur != "":
		row.add_child(_action_tile("Снять", "+%d ДНК" % LandParts.part_cost(cur, evo.land_shape), "trash", func():
			_snap()
			var r := evo.land_take(slot)
			select("")
			changed.emit(r.ok, true)
			_after_change.call_deferred(r.message)))
	var ids := LandParts.in_slot(slot)
	ids.sort_custom(func(a, b): return int(LandParts.PARTS[a].cost) < int(LandParts.PARTS[b].cost))
	for id in ids:
		row.add_child(_part_tile(id, cc))
	# Ноги и глаза: сколько — по одной (или парой, если «обе стороны»).
	if slot in ["legs", "eyes"] and cur != "":
		var n := _creature.leg_count if slot == "legs" else _creature.eye_count
		var step := 2 if mirror else 1
		var word := "ноги" if slot == "legs" else "глаза"
		var tm := _action_tile("− %s" % ("пара" if step == 2 else ("нога" if slot == "legs" else "глаз")), "сейчас %d" % n, "trash", func(): set_count(slot, n - step))
		tm.dim = n - step < 1
		row.add_child(tm)
		row.add_child(_action_tile("+ %s" % ("пара" if step == 2 else ("нога" if slot == "legs" else "глаз")), "или тяни карточку " + word + " на тело", "plus", func(): set_count(slot, n + step)))
	# Руки: сколько их — 2, 4 или 6.
	if slot == "arms" and cur != "":
		var one := int(LandParts.PARTS[cur].cost)
		var was := LandParts.arm_pairs(evo.land_shape)
		for n in [1, 2, 3]:
			var t := _action_tile("%d %s" % [n * 2, "руки" if n < 3 else "рук"], "стоит" if n == was else "%+d ДНК" % (one * (n - was)), "plus", func(): set_arms(n), false)
			t.on = n == was
			row.add_child(t)

## Карточка части: значок, название, цена или «стоит», одна строка — что даёт.
func _part_tile(id: String, cc: Array) -> Control:
	var p: Dictionary = LandParts.PARTS[id]
	var s: String = p.slot
	var cur: String = evo.land_body.get(s, "")
	var on := cur == id
	var free := evo.land_free() + (LandParts.part_cost(cur, evo.land_shape) if cur != "" else 0)
	# Другой вид ног или глаз ставится с обычным числом — и цена обычная.
	var price := LandParts.part_cost(id, evo.land_shape if (on or s == "arms") else {})
	var need_torso := id != "torso" and not evo.land_body.has("torso")
	var t := Tile.new()
	t.ed = self
	t.part = id
	t.c = cc[0]
	t.c2 = cc[1]
	t.title = p.name
	var sum := LandParts.summary(id)
	t.sub = "сначала туловище" if need_torso else (sum.split(" · ")[0] if sum != "" else "")
	t.price = "стоит" if on else ("даром" if price == 0 else "%d ДНК" % price)
	t.on = on
	t.dim = not on and (need_torso or price > free)
	t.custom_minimum_size = Vector2(168, 146)
	t.pressed.connect(func():
		if on:
			select(_default_sel(s), true)
			_toast(p.name + ": " + (sum if sum != "" else p.hint))
			_refresh.call_deferred()
		else:
			put.call_deferred(id))
	return t

## Карточка действия: заготовка, сгладить, снять…
func _action_tile(title: String, sub: String, icon: String, action: Callable, warn := false) -> Control:
	var t := Tile.new()
	t.ui_icon = icon
	t.title = title
	t.sub = sub
	t.warn = warn
	t.custom_minimum_size = Vector2(150, 146)
	t.pressed.connect(func(): action.call())
	return t

## «Окрас»: основной цвет, цвет узора, узор — три ряда, каждый листается вбок.
func _paint_drawer() -> void:
	var pt := evo.paint()
	for pair in [["Цвет", "color"], ["Узор цветом", "color2"]]:
		var line := Kit.hbox(10)
		var l := Kit.label(pair[0], 18, Art.TEXT, true)
		l.custom_minimum_size.x = 118
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(l)
		var sc := TouchHScroll.new()
		sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.custom_minimum_size.y = 50
		var row := Kit.hbox(6)
		sc.add_child(row)
		line.add_child(sc)
		for i in LandParts.COLORS.size():
			var sw := Swatch.new()
			sw.col = Color(LandParts.COLORS[i])
			sw.on = int(pt[pair[1]]) == i
			sw.custom_minimum_size = Vector2(46, 46)
			var key: String = pair[1]
			sw.pressed.connect(func(): _set_paint.call_deferred(key, i))
			row.add_child(sw)
		_drawer_box.add_child(line)
	var sc2 := TouchHScroll.new()
	sc2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pr := Kit.hbox(8)
	sc2.add_child(pr)
	var cc := _colors()
	for q in LandParts.PATTERNS:
		var tile := PatternTile.new()
		tile.pattern = q[0]
		tile.text = q[1]
		tile.c = cc[0]
		tile.c2 = Color(LandParts.COLORS[pt.color2])
		tile.on = pt.pattern == q[0]
		tile.custom_minimum_size = Vector2(130, 100)
		var id: String = q[0]
		tile.pressed.connect(func(): _set_paint.call_deferred("pattern", id))
		pr.add_child(tile)
	_drawer_box.add_child(sc2)

func _slot_hint(s: String) -> String:
	match s:
		"torso":
			return "Заготовки формы. Нажми на туловище — его длина, ширина, высота, наклон"
		"mouth":
			return "Что вкуснее: плоды или мясо, и как больно кусаешь"
		"eyes":
			return "Без глаз вокруг туман"
		"legs":
			return "Скорость. Нажми на ногу — у каждой свои размеры"
		"feet":
			return "Тише, быстрее или по воде"
		"claws":
			return "Бьёшь сильнее, кости крошатся быстрее"
		"arms":
			return "Дотягиваешься дальше и бьёшь сильнее"
		"back":
			return "Сдача, броня или лечение"
		"tail":
			return "Равновесие или булава"
		"head":
			return "Рога бодают, гребень пугает бродяг"
		"skin":
			return "Здоровье, броня или яд"
	return ""

# --- панель выбранной части -----------------------------------------------------------

func _fill_insp() -> void:
	for ch in _insp_list.get_children():
		_insp_list.remove_child(ch)
		ch.queue_free()
	if sel == "":
		return
	var s := _slot_of(sel)
	var cc := _colors()
	_insp_icon.part = evo.land_body.get(s, "torso") if s != "torso" or sel == "torso" else "torso"
	if sel == "head":
		_insp_icon.part = "torso"
	if sel.begins_with("eye"):
		_insp_icon.part = evo.land_body.get("eyes", "eyes")
	_insp_icon.c = cc[0]
	_insp_icon.c2 = cc[1]
	_insp_icon.queue_redraw()
	_insp_title.text = sel_name(sel)
	_insp_sub.text = String(LandParts.PARTS[evo.land_body[s]].name) if evo.land_body.has(s) and s != "torso" else ""
	_insp_sub.visible = _insp_sub.text != ""
	var rows: Array
	if sel == "torso":
		rows = [["Поднять туловище", "torso_pitch"], ["Горб / прогиб", "torso_bend"], ["Длина", "len"], ["Ширина", "width"], ["Высота", "height"], ["Размер", "torso"]]
	elif sel.begins_with("eye"):
		rows = [["Вокруг головы", "place:%s:0" % sel], ["Выше / ниже", "place:%s:1" % sel], ["Размер", "place:%s:2" % sel],
			["Все глаза — длина", "dim:eyes:0"], ["Все глаза — ширина", "dim:eyes:1"]]
	else:
		rows = [["Длина", "dim:%s:0" % sel], ["Ширина", "dim:%s:1" % sel], ["Высота", "dim:%s:2" % sel], ["Размер", "dim:%s:3" % sel]]
		if sel == "head":
			rows += [["Шея вперёд", "neck_z"], ["Шея вверх", "neck_y"]]
		if sel.begins_with("leg") or sel.begins_with("arm"):
			rows += [["Вдоль тела", "place:%s:0" % sel], ["Выше / ниже", "place:%s:1" % sel]]
		if sel.begins_with("arm"):
			rows += [["Наклон", "place:%s:2" % sel], ["Поворот кистей", "rot:hands"]]
		if sel.begins_with("leg"):
			rows += [["Ступни", "size:feet"], ["Носки врозь", "rot:feet"]]
		if sel == "tail":
			rows += [["Наклон", "tail_pitch"], ["Изгиб", "tail_curl"]]
		if sel in ["mouth", "horns", "back"]:
			rows.append(["Наклон", "rot:" + sel])
	for r in rows:
		var key: String = r[1]
		var sl := ValueSlider.new()
		sl.text = r[0]
		sl.ed = self
		sl.key = key
		var lim: Array
		if key.begins_with("dim:"):
			lim = LandParts.DIM_SIZE_LIMITS if key.ends_with(":3") else LandParts.DIM_LIMITS
		elif key.begins_with("place:eye"):
			lim = LandParts.EYE_LIMITS[int(key.substr(key.length() - 1))]
		elif key.begins_with("place:"):
			lim = LandParts.PLACE_LIMITS[int(key.substr(key.length() - 1))]
		elif key.begins_with("rot:"):
			lim = [-1.2, 1.2]
		elif key.begins_with("size:"):
			lim = LandParts.SIZE_LIMITS
		else:
			lim = [LandParts.SHAPE[key][1], LandParts.SHAPE[key][2]]
		sl.lo = lim[0]
		sl.hi = lim[1]
		sl.angle = key.ends_with("pitch") or key.begins_with("neck") or key.begins_with("rot:") or key.ends_with("curl") or key.ends_with("bend")
		sl.custom_minimum_size = Vector2(0, 60)
		_insp_list.add_child(sl)
	var small := func(text: String, bg: Color, action: Callable) -> Button:
		var b := _button(text, bg, action)
		b.custom_minimum_size.y = 44
		b.add_theme_font_size_override("font_size", 17)
		return b
	for pair in [["leg", "legs", "Сколько ног", _creature.leg_count, 8], ["eye", "eyes", "Сколько глаз", _creature.eye_count, 6]]:
		if sel.begins_with(pair[0]) and evo.land_body.has(pair[1]):
			var line := Kit.hbox(8)
			var l := Kit.label("%s: %d" % [pair[2], pair[3]], 18, Art.TEXT, true)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(l)
			var step := 2 if mirror else 1
			var sl: String = pair[1]
			var n: int = pair[3]
			var minus := _button("−", Art.CARD_BORDER, func(): set_count.call_deferred(sl, n - step))
			minus.custom_minimum_size = Vector2(56, 44)
			minus.disabled = n - step < 1
			line.add_child(minus)
			var plus := _button("+", Art.CARD_BORDER, func(): set_count.call_deferred(sl, n + step))
			plus.custom_minimum_size = Vector2(56, 44)
			plus.disabled = n + step > int(pair[4])
			line.add_child(plus)
			_insp_list.add_child(line)
			_insp_list.add_child(small.call("Убрать " + ("эту ногу" if pair[0] == "leg" else "этот глаз") + (" (и парную)" if mirror and _pair(sel) != "" else ""),
				Art.CARD_BORDER, func(): remove_one.call_deferred(sel)))
	if sel.begins_with("arm") and evo.land_body.has("arms"):
		# Сколько рук: каждая пара стоит как руки целиком.
		var one := int(LandParts.PARTS[evo.land_body.arms].cost)
		var was := LandParts.arm_pairs(evo.land_shape)
		_insp_list.add_child(Kit.label("Сколько рук (пара — %d ДНК)" % one, 17, Art.TEXT, true))
		_insp_list.add_child(Kit.segmented([["1", "2"], ["2", "4"], ["3", "6"]], str(was), func(id):
			set_arms.call_deferred(int(id)), 19, 50))
	if sel.begins_with("leg") or sel.begins_with("arm") or sel.begins_with("eye"):
		_insp_list.add_child(small.call("Обе стороны одинаково: " + ("да" if mirror else "нет"), Art.CARD_BORDER if mirror else Art.CARD, func():
			mirror = not mirror
			_refresh.call_deferred()))
		if sel.begins_with("leg") and _creature.leg_count > 2:
			_insp_list.add_child(small.call("Всем ногам так же", Art.CARD_BORDER, func():
				_snap()
				var d: Array = LandParts.dim(evo.land_shape, sel).duplicate()
				for i in _creature.leg_count:
					evo.land_shape.dims["leg%d" % i] = d.duplicate()
				_after_change.call_deferred("Все ноги одинаковые")))
	_insp_list.add_child(small.call("Как обычно", Art.CARD_BORDER, func():
		_snap()
		if sel == "torso":
			for k in ["len", "width", "height", "torso", "torso_pitch", "torso_bend"]:
				evo.land_shape[k] = LandParts.SHAPE[k][0]
		elif sel == "tail":
			evo.land_shape.dims.erase("tail")
			evo.land_shape.tail_curl = 0.0
			evo.land_shape.tail_pitch = LandParts.SHAPE.tail_pitch[0]
		elif sel in ["mouth", "horns", "back"]:
			evo.land_shape.dims.erase(sel)
			evo.land_shape.rot.erase(sel)
		else:
			evo.land_shape.dims.erase(sel)
			evo.land_shape.place.erase(sel)
			if mirror:
				evo.land_shape.dims.erase(_pair(sel))
				evo.land_shape.place.erase(_pair(sel))
			if sel == "head":
				evo.land_shape.neck_z = 0.0
				evo.land_shape.neck_y = 0.0
		_after_change.call_deferred("Как обычно")))
	if s != "torso" and evo.land_body.has(s):
		_insp_list.add_child(small.call("Убрать: %s (+%d ДНК)" % [String(LandParts.PARTS[evo.land_body[s]].name).to_lower(), LandParts.part_cost(evo.land_body[s], evo.land_shape)], Color(0.4, 0.2, 0.22), func():
			_snap()
			var r := evo.land_take(s)
			select("")
			changed.emit(r.ok, true)
			_after_change.call_deferred(r.message)))

# --- действия -------------------------------------------------------------------------

## Запомнить, как было, — для «Отменить».
func _state() -> Dictionary:
	return {"b": evo.land_body.duplicate(), "s": evo.land_shape.duplicate(true), "p": evo.land_paint.duplicate()}

func _snap() -> void:
	_undo.append(_state())
	_redo.clear()
	if _undo.size() > 60:
		_undo.pop_front()
	if _undo_btn:
		_undo_btn.disabled = false
		_undo_btn.modulate.a = 1.0

## Отменить последний шаг.
func undo() -> void:
	if _undo.is_empty():
		return
	_redo.append(_state())
	_restore(_undo.pop_back())
	changed.emit(true, true)
	_after_change("Отменил")

## Вернуть отменённое.
func redo() -> void:
	if _redo.is_empty():
		return
	_undo.append(_state())
	_restore(_redo.pop_back())
	changed.emit(true, false)
	_after_change("Вернул")

func _restore(u: Dictionary) -> void:
	evo.land_body = u.b
	evo.land_shape = u.s
	evo.land_paint = u.p
	if not _creature.groups.has(sel):
		sel = ""

## Вид камеры: откуда смотреть (угол вокруг) и как высоко.
func view(yaw: float, elev: float) -> void:
	_yaw_to = yaw
	_elev = elev

## Показать, как существо двигается: шаг, бег, укус, прыжок.
func anim(kind: String) -> void:
	match kind:
		"walk":
			_run = false
			_walk_t = 4.0
		"run":
			_run = true
			_walk_t = 3.0
		"bite":
			_bites = 3
			_bite_in = 0.0
		"jump":
			_jump_t = 0.0
	changed.emit(true, false)

## Сколько ног или глаз. Ноги и глаза по одному — каждый со своим местом.
func set_count(s_: String, n: int) -> void:
	_snap()
	var r := evo.land_set_count(s_, n)
	changed.emit(r.ok, false)
	if not r.ok:
		_undo.pop_back()
	_after_change(r.message)
	if r.ok and not _creature.groups.has(sel):
		select(_default_sel(s_))
		_refresh()

## Убрать одну ногу или глаз (и парную, если «обе стороны»): следующие сдвигаются.
func remove_one(key: String) -> void:
	var s_ := _slot_of(key)
	var pre := "leg" if s_ == "legs" else "eye"
	var n := _creature.leg_count if s_ == "legs" else _creature.eye_count
	var gone := [int(key.substr(3))]
	var pk := _pair(key)
	if mirror and pk != "" and int(pk.substr(3)) < n:
		gone.append(int(pk.substr(3)))
	if n - gone.size() < 1:
		_toast("Хотя бы одна должна остаться — или сними целиком")
		return
	_snap()
	var sh: Dictionary = evo.land_shape
	var keep_dims := []
	var keep_place := []
	for i in n:
		if gone.has(i):
			continue
		keep_dims.append(sh.dims.get("%s%d" % [pre, i]))
		keep_place.append(sh.place.get("%s%d" % [pre, i]))
	for i in n:
		sh.dims.erase("%s%d" % [pre, i])
		sh.place.erase("%s%d" % [pre, i])
	for j in keep_dims.size():
		if keep_dims[j] != null:
			sh.dims["%s%d" % [pre, j]] = keep_dims[j]
		if keep_place[j] != null:
			sh.place["%s%d" % [pre, j]] = keep_place[j]
	sh["leg_n" if s_ == "legs" else "eye_n"] = float(n - gone.size())
	evo.land_shape = LandParts.fix_shape(sh)
	select("")
	changed.emit(true, true)
	_after_change("Убрано")

## Сколько пар рук (1–3).
func set_arms(pairs: int) -> void:
	_snap()
	var r := evo.land_set_arms(pairs)
	changed.emit(r.ok, false)
	if not r.ok:
		_undo.pop_back()
	elif not sel.begins_with("arm") or int(sel.substr(3)) >= pairs * 2:
		sel = "arm1"
	_after_change(r.message)

func apply_preset(i: int) -> void:
	_snap()
	var pr: Array = PRESETS[i]
	var sh: Dictionary = evo.land_shape.duplicate(true)
	for k in pr[1]:
		sh[k] = pr[1][k]
	evo.land_shape = LandParts.fix_shape(sh)
	_walk_t = 3.0
	changed.emit(true, false)
	_after_change(pr[0])

## Поставить часть (кнопкой или из сценария проверки). Встала — сразу выбрана.
func put(id: String) -> void:
	_snap()
	var r := evo.land_put(id)
	changed.emit(r.ok, false)
	if not r.ok:
		_undo.pop_back()
	else:
		if LandParts.PARTS[id].slot in ["legs", "feet", "claws", "tail", "arms"]:
			_walk_t = 3.0
		_rebuild_creature(false)
		select(_default_sel(LandParts.PARTS[id].slot))
	_after_change(r.message)

func _after_change(message: String) -> void:
	_rebuild_creature()
	_refresh()
	if message != "":
		_toast(message)

func _toast(message: String) -> void:
	if _msg == null:
		return
	_msg.text = message
	if _msg_tw:
		_msg_tw.kill()
	_msg.modulate.a = 1.0
	_msg_tw = create_tween()
	_msg_tw.tween_interval(2.0)
	_msg_tw.tween_property(_msg, "modulate:a", 0.0, 0.5)

func _set_paint(key: String, v: Variant) -> void:
	_snap()
	var pt := evo.paint().duplicate()
	pt[key] = v
	evo.land_paint = LandParts.fix_paint(pt)
	changed.emit(true, false)
	_after_change("")

## Спрятать всё, кроме существа (или вернуть).
func set_collapsed(on: bool) -> void:
	collapsed = on
	if on:
		slot = ""
		select("")
	_refresh()

## «Готово» — только если есть на чём ходить.
func try_done() -> void:
	if not evo.land_can_walk():
		changed.emit(false, false)
		_toast("Нужны туловище и ноги — иначе на суше не походишь")
		return
	done.emit()

# --- витрина: касания и камера --------------------------------------------------------

func _input(e: InputEvent) -> void:
	if not is_visible_in_tree() or _box == null or (_overlay and _overlay.visible):
		return
	if e is InputEventScreenTouch or e is InputEventScreenDrag:
		_finger_at = e.position
	# Несут часть с карточки — следим за пальцем, отпустили — ставим.
	if _carry != "":
		if e is InputEventScreenDrag:
			_carry_at = e.position
		elif e is InputEventScreenTouch and not e.pressed:
			drop_carry.call_deferred(e.position)
			_fingers.clear()
			_drag = -1
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			if _ui_hit(e.position) or _fingers.has(e.index):
				return
			_fingers[e.index] = e.position
			if _fingers.size() == 2:
				# Второй палец — приближаем, лепку и поворот бросаем.
				_tap = false
				_grab = ""
				_pinch_d = _finger_gap()
				return
			_drag = e.index
			_grab = _handle_at(e.position - _box.global_position)
			_press_at = e.position
			_tap = true
		elif _fingers.has(e.index):
			_fingers.erase(e.index)
			if e.index != _drag:
				return
			_drag = -1
			if _grab != "" and not _tap:
				_grab = ""
				_dirty = true
				_refresh.call_deferred()
			elif _tap:
				_grab = ""
				# Коснулся и отпустил, не ведя, — выбрать часть под пальцем (мимо — снять выбор).
				var key := pick(e.position - _box.global_position)
				if key != sel:
					select(key)
					changed.emit(true, false)
					_refresh.call_deferred()
	elif e is InputEventScreenDrag and _fingers.has(e.index):
		_fingers[e.index] = e.position
		if _fingers.size() >= 2:
			var g := _finger_gap()
			if _pinch_d > 1.0 and g > 1.0:
				_zoom = clampf(_zoom * _pinch_d / g, 0.45, 2.2)
			_pinch_d = g
			return
		if e.index != _drag:
			return
		if _tap and e.position.distance_to(_press_at) > 14.0:
			_tap = false
			if _grab != "":
				_snap()
				_walk_t = 0.0
				changed.emit(true, false)
		if _grab != "":
			if not _tap:
				_sculpt(_grab, e.relative)
		elif not _tap:
			# Вбок — повернуть, вверх-вниз — посмотреть выше или ниже.
			_yaw -= e.relative.x * 0.01
			_elev = clampf(_elev + e.relative.y * 0.006, -0.05, 1.4)
			_yaw_to = 1000.0

func _finger_gap() -> float:
	var ps: Array = _fingers.values()
	return (ps[0] as Vector2).distance_to(ps[1]) if ps.size() >= 2 else 0.0

func _process(delta: float) -> void:
	if not visible or _creature == null:
		return
	# Пока лепят — пересобирать не чаще 20 раз в секунду.
	_rebuild_in -= delta
	if _dirty and _rebuild_in <= 0.0:
		_dirty = false
		_rebuild_in = 0.05
		_rebuild_creature(false)
		_refresh_stats()
	# Выбрал раздел — камера сама поворачивается, откуда его лучше видно.
	if _drag == -1 and _yaw_to < 100.0:
		_yaw = lerp_angle(_yaw, _yaw_to, 1.0 - exp(-4.0 * delta))
		if absf(angle_difference(_yaw, _yaw_to)) < 0.01:
			_yaw_to = 1000.0
	# Походка: пару кругов по полянке, потом снова стоит.
	var vel := Vector3.ZERO
	if _walk_t > 0.0:
		_walk_t -= delta
		var spd := 2.2 * float(LandParts.stats(evo.land_body, evo.land_shape).speed) * (2.2 if _run else 1.0)
		_walk_a += delta * spd / 2.2
		var next := Vector3(sin(_walk_a) * 2.2, 0.0, cos(_walk_a) * 2.2)
		vel = (next - _pos) / maxf(delta, 0.001)
		_pos = next
		_heading = atan2(vel.x, vel.z)
	elif _pos.length() > 0.05:
		var to := -_pos
		var step := minf(to.length(), delta * 2.0)
		vel = to.normalized() * 2.0
		_pos += to.normalized() * step
		_heading = lerp_angle(_heading, atan2(to.x, to.z), 1.0 - exp(-6.0 * delta))
	else:
		_heading = lerp_angle(_heading, 0.0, 1.0 - exp(-3.0 * delta))
	# Прыжок — дважды, радостно; укус — три броска подряд.
	var jy := 0.0
	if _jump_t >= 0.0:
		_jump_t += delta
		var q := fmod(_jump_t, 0.7) / 0.7
		jy = 4.0 * 0.7 * q * (1.0 - q)
		if _jump_t >= 1.4:
			_jump_t = -1.0
	if _bites > 0:
		_bite_in -= delta
		if _bite_in <= 0.0:
			_bites -= 1
			_bite_in = 0.35
			_creature.lunge()
	_creature.update(delta, _pos + Vector3(0, jy, 0), _heading, vel)
	# Камера — чтобы существо было целиком и там, где его не закрывает интерфейс.
	var free := _free_rect()
	# Свободного места меньше — чуть отъехать, но не так, чтобы существо стало крошкой:
	# оно вытянуто вбок, а свободное место по ширине почти всё.
	var fit := clampf(sqrt(size.y / maxf(free.size.y, 1.0)), 1.0, 1.45)
	var ext := _creature.extent()
	var dist := ((6.0 if _walk_t > 0.0 or _pos.length() > 0.3 else 2.6) + ext * 1.45) * fit * _zoom
	var target := Vector3(0, clampf(ext * 0.35, 0.5, 2.4), 0)
	var want := target + Vector3(sin(_yaw) * cos(_elev), sin(_elev), cos(_yaw) * cos(_elev)) * dist
	_cam.position = _cam.position.lerp(want, 1.0 - exp(-5.0 * delta)) if _cam.position != Vector3.ZERO else want
	_cam.look_at(target, Vector3.UP)
	# Сдвиг кадра: центр существа — в середину свободного места.
	var per_px := 2.0 * dist * tan(deg_to_rad(_cam.fov) / 2.0) / maxf(size.y, 1.0)
	var want_h := -(free.get_center().x - size.x / 2.0) * per_px
	var want_v := (free.get_center().y - size.y / 2.0) * per_px
	_hofs = lerpf(_hofs, want_h, 1.0 - exp(-6.0 * delta))
	_vofs = lerpf(_vofs, want_v, 1.0 - exp(-6.0 * delta))
	_cam.h_offset = _hofs
	_cam.v_offset = _vofs

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

func _colors() -> Array:
	var pt := evo.paint()
	var c := Color(LandParts.COLORS[pt.color])
	return [c, Color(LandParts.COLORS[pt.color2]) if pt.pattern != "none" else c.darkened(0.25)]

func _rebuild_creature(bounce := true) -> void:
	var cc := _colors()
	_creature.build_body(cc[0], cc[1], 1.0, evo.land_body, evo.paint().pattern, evo.land_shape)
	if not _creature.groups.has(sel):
		sel = _default_sel(slot)
	_creature.highlight(sel)
	if not bounce:
		_creature.update(0.0, _pos, _heading, Vector3.ZERO)
		return
	_creature.scale = Vector3.ONE * 0.85
	var tw := _creature.create_tween()
	tw.tween_property(_creature, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# --- выбор части и лепка --------------------------------------------------------------

## Выбрать часть: подсветить на существе, открыть её место.
func select(key: String, turn := false) -> void:
	sel = key
	var s := _slot_of(key)
	# Открыт ряд карточек — он переходит на место выбранной части.
	if s != "" and slot != "" and slot != "paint":
		slot = s
	if turn and s != "":
		_yaw_to = VIEW_YAW.get(s, 0.9)
	if _creature:
		_creature.highlight(sel)

## Какая часть под точкой витрины: из всех, чьи меши накрывают точку, — самая мелкая
## (глаз на голове важнее головы).
func pick(p: Vector2) -> String:
	var best := ""
	var best_r := INF
	for key in _creature.groups:
		for mi in _creature.groups[key]:
			if not is_instance_valid(mi) or not (mi as Node3D).is_visible_in_tree():
				continue
			var gi := mi as MeshInstance3D
			if gi == null:
				continue
			var c: Vector3 = gi.global_transform * gi.get_aabb().get_center()
			if _cam.is_position_behind(c):
				continue
			var sc: Vector3 = gi.global_basis.get_scale()
			var r := gi.get_aabb().size.length() / 2.0 * maxf(sc.x, maxf(sc.y, sc.z)) * 0.75
			var dist := _cam.global_position.distance_to(c)
			var per_px := 2.0 * dist * tan(deg_to_rad(_cam.fov) / 2.0) / maxf(_box.size.y, 1.0)
			var r_px := maxf(r / per_px, 16.0)
			if _cam.unproject_position(c).distance_to(p) < r_px and r_px < best_r:
				best_r = r_px
				best = key
	return best

func _slot_of(key: String) -> String:
	if key.begins_with("leg"):
		return "legs"
	if key.begins_with("arm"):
		return "arms"
	if key.begins_with("eye"):
		return "eyes"
	return {"torso": "torso", "head": "torso", "mouth": "mouth", "eyes": "eyes", "horns": "head", "back": "back", "tail": "tail"}.get(key, "")

## Обычное значение ползунка — для отметки на дорожке.
func default_value(key: String) -> float:
	if key.begins_with("place:"):
		var q := key.split(":")
		return float(LandParts.default_place(q[1], _creature.leg_count, float(evo.land_shape.get("torso_pitch", 0.0)), _creature.eye_count)[int(q[2])])
	if key.begins_with("rot:"):
		return 0.0
	if LandParts.SHAPE.has(key):
		return float(LandParts.SHAPE[key][0])
	return 1.0

## Какую часть выбрать, когда открыли место: у ног — переднюю левую, у рук — правую…
func _default_sel(s: String) -> String:
	match s:
		"legs", "feet", "claws":
			return "leg0" if evo.land_body.has("legs") else ""
		"arms":
			return "arm1" if evo.land_body.has("arms") else ""
		"eyes":
			return "eye1" if _creature.eye_count > 1 else ("eye0" if _creature.eye_count == 1 else "")
		"head":
			return "horns" if evo.land_body.has("head") else ""
		"skin", "paint":
			return ""
		"torso":
			return "torso" if evo.land_body.has("torso") else ""
	return s if evo.land_body.has(s) or s == "tail" else ""

## Как назвать выбранную часть.
func sel_name(key: String) -> String:
	if key.begins_with("leg"):
		var i := int(key.substr(3))
		var n := _creature.leg_count
		var sd := LandParts.leg_side(i, n)
		var side := "посередине" if sd == 0.0 else ("левая" if sd < 0.0 else "правая")
		if n <= 2:
			return "Нога — " + side
		return "Нога %d из %d — %s" % [i + 1, n, side]
	if key.begins_with("eye"):
		var i := int(key.substr(3))
		var n := _creature.eye_count
		if n % 2 == 1 and i == n - 1:
			return "Глаз — средний"
		return "Глаз — %s%s" % ["левый" if i % 2 == 0 else "правый", "" if n <= 2 else ", %d-я пара" % (i / 2 + 1)]
	if key.begins_with("arm"):
		var i := int(key.substr(3))
		var side := "левая" if i % 2 == 0 else "правая"
		if LandParts.arm_pairs(evo.land_shape) == 1:
			return "Рука — " + side
		return "Рука — %s, %d-я пара" % [side, i / 2 + 1]
	return {"torso": "Туловище", "head": "Голова", "mouth": "Рот", "eyes": "Глаза", "horns": "Рога и гребень", "back": "Спина", "tail": "Хвост"}.get(key, key)

## Пара части: левая ↔ правая нога того же ряда, левая ↔ правая рука.
func _pair(key: String) -> String:
	if key.begins_with("leg"):
		var i := int(key.substr(3))
		var n := _creature.leg_count
		if LandParts.leg_side(i, n) == 0.0 or (i ^ 1) >= n:
			return ""
		return "leg%d" % (i ^ 1)
	if key.begins_with("arm"):
		return "arm%d" % (int(key.substr(3)) ^ 1)
	if key.begins_with("eye"):
		var i := int(key.substr(3))
		var n := _creature.eye_count
		if n % 2 == 1 and i == n - 1:
			return ""
		return "eye%d" % (i ^ 1) if (i ^ 1) < n else ""
	return ""

## Точка на поверхности туловища под пальцем: {t, a, side} или пусто (мимо).
func surface_hit(p: Vector2) -> Dictionary:
	if _creature._sp.is_empty():
		return {}
	var best := {}
	var best_d := 90.0
	var cam_side := signf((_creature.global_transform.affine_inverse() * _cam.global_position).x)
	for side in [cam_side if cam_side != 0.0 else 1.0, -cam_side if cam_side != 0.0 else -1.0]:
		for ti in 26:
			var t := ti / 25.0
			for ai in 21:
				var a := -1.45 + ai * 0.145
				var w: Vector3 = _creature.global_transform * _creature._b(_creature._surf(t, a, side))
				if _cam.is_position_behind(w):
					continue
				var dd := _cam.unproject_position(w).distance_to(p)
				if dd < best_d:
					best_d = dd
					best = {"t": t, "a": a, "side": side}
		if not best.is_empty():
			return best
	return best

## Точка на голове под пальцем: {yaw, pitch} или пусто.
func head_hit(p: Vector2) -> Dictionary:
	var hn: Node3D = _creature._head_node
	if hn == null:
		return {}
	var best := {}
	var best_d := 80.0
	var hr := 0.39 * _creature.size * 0.9
	for yi in 33:
		var yaw := -2.4 + yi * 0.15
		for pi_ in 21:
			var pitch := -1.0 + pi_ * 0.115
			var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
			var w := hn.global_transform * (dir * hr)
			var toward_cam := (_cam.global_position - w).dot(hn.global_transform.basis * dir) > 0.0
			if not toward_cam or _cam.is_position_behind(w):
				continue
			var dd := _cam.unproject_position(w).distance_to(p)
			if dd < best_d:
				best_d = dd
				best = {"yaw": yaw, "pitch": pitch}
	return best

## Начали нести часть с карточки (повели пальцем вверх из ряда).
func begin_carry(id: String, at: Vector2) -> void:
	_carry = id
	_carry_at = at
	changed.emit(true, false)

## Отпустили часть над существом: ставится туда. Ноги, руки, глаза — ещё одна (или пара)
## прямо в это место.
func drop_carry(at: Vector2) -> void:
	var id := _carry
	_carry = ""
	if id == "" or _ui_hit(at):
		return
	var s_: String = LandParts.PARTS[id].slot
	var local := at - _box.global_position
	var had: bool = evo.land_body.get(s_, "") == id
	_snap()
	var msg := ""
	if not had:
		var r := evo.land_put(id)
		if not r.ok:
			_undo.pop_back()
			changed.emit(false, false)
			_toast(r.message)
			return
		msg = r.message
		_rebuild_creature(false)
	var sh: Dictionary = evo.land_shape
	match s_:
		"legs", "arms":
			var hit := surface_hit(local)
			if not hit.is_empty():
				var add := 2 if mirror else 1
				var key := ""
				if s_ == "legs":
					var n := _creature.leg_count
					if had and n + add <= 8:
						sh.leg_n = float(n + add)
						key = "leg%d" % n
					elif not had:
						sh.leg_n = float(add)
						key = "leg0"
				else:
					var pairs := LandParts.arm_pairs(sh)
					if had and pairs < 3:
						sh.arm_pairs = float(pairs + 1)
						key = "arm%d" % (pairs * 2)
					elif not had:
						key = "arm0"
				if key != "":
					var i := int(key.substr(3))
					var side_key := key if (float(hit.side) < 0.0) == (i % 2 == 0) else "%s%d" % [key.substr(0, 3), i + 1]
					sh.place[side_key] = [hit.t, hit.a, 0.0]
					var other := "%s%d" % [key.substr(0, 3), i ^ 1 if side_key == key else i]
					if add == 2:
						sh.place[other] = [hit.t, hit.a, 0.0]
					evo.land_shape = LandParts.fix_shape(sh)
					if evo.land_free() < 0:
						_restore(_undo.pop_back())
						changed.emit(false, false)
						_after_change("Не хватает ДНК")
						return
					msg = "Поставлено сюда"
					sel = side_key
		"eyes":
			var hh := head_hit(local)
			if not hh.is_empty():
				var n := _creature.eye_count if had else 0
				var add := 1 if (not mirror or absf(float(hh.yaw)) < 0.15) else 2
				if n + add <= 6:
					sh.eye_n = float(n + add)
					sh.place["eye%d" % n] = [hh.yaw, hh.pitch, 1.0]
					if add == 2:
						sh.place["eye%d" % (n + 1)] = [-float(hh.yaw), hh.pitch, 1.0]
					evo.land_shape = LandParts.fix_shape(sh)
					if evo.land_free() < 0:
						_restore(_undo.pop_back())
						changed.emit(false, false)
						_after_change("Не хватает ДНК")
						return
					msg = "Глаз — сюда"
					sel = "eye%d" % n
	changed.emit(true, false)
	_rebuild_creature(false)
	if not _creature.groups.has(sel):
		select(_default_sel(s_))
	else:
		select(sel)
	_after_change(msg)

## Кружки выбранной части, которые сейчас есть на существе: [[ручка, вид, точка на экране]].
func handles() -> Array:
	var out: Array = []
	if _creature == null or _walk_t > 0.0 or _pos.length() > 0.3 or (_overlay and _overlay.visible):
		return out
	var list: Array = SEL_HANDLES.get(sel, [])
	if sel.begins_with("leg"):
		list = [["place:" + sel, "move"], ["len:" + sel, "updown"], ["thick:" + sel, "thick"], ["feet:" + sel, "size"]]
	elif sel.begins_with("arm"):
		list = [["place:" + sel, "move"], ["hand:" + sel, "move"], ["thick:" + sel, "thick"]]
	elif sel.begins_with("eye") and _creature.groups.has(sel):
		# Глаз: кружок на нём самом — тянешь по голове.
		var ms: Array = _creature.groups[sel]
		var c := Vector3.ZERO
		for mi in ms:
			c += (mi as Node3D).global_position
		c /= maxf(ms.size(), 1)
		if not _cam.is_position_behind(c):
			out.append(["place:" + sel, "move", _cam.unproject_position(c), c])
		return out
	for h in list:
		var id: String = h[0]
		if not _creature.anchors.has(id):
			continue
		var world: Vector3 = _creature.global_transform * (_creature.anchors[id] as Vector3)
		if _cam.is_position_behind(world):
			continue
		out.append([id, h[1], _cam.unproject_position(world), world])
	return out

func _handle_at(p: Vector2) -> String:
	var best := ""
	var best_d := 46.0
	for h in handles():
		var d: float = (h[2] as Vector2).distance_to(p)
		if d < best_d:
			best_d = d
			best = h[0]
	return best

## Потянули кружок на rel точек экрана — поменять форму.
func _sculpt(id: String, rel: Vector2) -> void:
	var sh: Dictionary = evo.land_shape
	var world_at: Vector3 = _creature.global_transform * (_creature.anchors.get(id, Vector3.ZERO) as Vector3)
	# Сдвиг пальца → сдвиг в мире (в плоскости экрана) → в осях существа.
	var dist := _cam.global_position.distance_to(world_at)
	var per_px := 2.0 * dist * tan(deg_to_rad(_cam.fov) / 2.0) / maxf(_box.size.y, 1.0)
	var wd := (_cam.global_basis.x * rel.x - _cam.global_basis.y * rel.y) * per_px
	var d: Vector3 = _creature.global_basis.inverse() * wd
	var grow := (rel.x - rel.y) / 150.0
	# Ноги и руки: у каждой свои кружки — «вид:часть».
	if ":" in id:
		var q := id.split(":")
		var kind: String = q[0]
		var key: String = q[1]
		for part in [key, _pair(key) if mirror else ""]:
			if part == "":
				continue
			var dm: Array = LandParts.dim(sh, part).duplicate()
			match kind:
				"place":
					# Основание едет по телу за пальцем (глаз — по голове). Парная часть —
					# зеркально.
					if part != key:
						continue
					var pl: Array = LandParts.place(sh, key, _creature.leg_count, _creature.eye_count).duplicate()
					if key.begins_with("eye"):
						var hh := head_hit(_finger_at - _box.global_position)
						if hh.is_empty():
							continue
						pl[0] = hh.yaw
						pl[1] = hh.pitch
					else:
						var hit := surface_hit(_finger_at - _box.global_position)
						if hit.is_empty():
							continue
						pl[0] = hit.t
						pl[1] = hit.a
					sh.place[key] = pl
					var pk := _pair(key)
					if mirror and pk != "":
						var pp: Array = LandParts.place(sh, pk, _creature.leg_count, _creature.eye_count).duplicate()
						pp[0] = -float(pl[0]) if key.begins_with("eye") else float(pl[0])
						pp[1] = pl[1]
						sh.place[pk] = pp
				"len":
					var base := 1.0
					for leg in _creature._legs:
						if leg.key == key:
							base = float(leg.len) / maxf(float(LandParts.dim(sh, key)[0]), 0.01)
					dm[0] = float(dm[0]) + d.y / (0.85 * maxf(base, 0.1))
				"thick":
					dm[1] = float(dm[1]) + grow
					dm[2] = float(dm[2]) + grow
				"feet":
					sh.sizes.feet = LandParts.part_size(sh, "feet") + grow / 2.0
				"hand":
					var v: Vector3 = (_creature.anchors["hand:" + key] as Vector3) + d - _creature.arm_shoulder(key)
					var unit := 0.74 * float(sh.arm_len) * float(sh.arm_size) * float(dm[3])
					dm[0] = v.length() / maxf(unit, 0.05)
					var rest := Vector3(0.1, -0.75, 0.6).normalized()
					var pl: Array = LandParts.place(sh, part, _creature.leg_count).duplicate()
					pl[2] = wrapf(atan2(v.y, v.z) - atan2(rest.y, rest.z), -PI, PI) - float(sh.arm_pitch)
					sh.place[part] = pl
			if kind in ["len", "thick", "hand"]:
				sh.dims[part] = dm
		evo.land_shape = LandParts.fix_shape(sh)
		_dirty = true
		return
	match id:
		"g0", "g1", "g2", "g3", "g4":
			# Как в лепке клетки: соседние места подтягиваются мягче — без ступенек.
			var i := int(id.substr(1))
			var dg := d.y / (0.475 * 0.92)
			for j in sh.girth.size():
				var k: float = [1.0, 0.35, 0.1][mini(absi(j - i), 2)]
				sh.girth[j] = float(sh.girth[j]) + dg * k
		"len_back":
			sh.len = float(sh.len) - d.z / 0.6
		"len_front":
			sh.len = float(sh.len) + d.z / 0.6
		"head":
			sh.neck_z = float(sh.neck_z) + d.z
			sh.neck_y = float(sh.neck_y) + d.y
		"head_size":
			sh.head = float(sh.head) + d.y / 0.39
		"legs", "legs_back":
			var key := "leg_len_f" if id == "legs" and _creature.leg_count > 2 else "leg_len"
			sh[key] = float(sh[key]) + d.y / (0.85 * _creature.leg_base() * float(sh.leg_size))
		"leg_thick":
			sh.leg_thick = float(sh.leg_thick) + grow
			sh.leg_thick_f = float(sh.leg_thick_f) + grow
		"width":
			sh.width = float(sh.width) + grow
		"tilt":
			# Тянешь перёд туловища вверх — оно поднимается, до стоймя.
			var half := maxf((_creature.extent()) * 0.35, 0.3)
			sh.torso_pitch = float(sh.torso_pitch) + d.y / half
		"arm_thick":
			sh.arm_thick = float(sh.arm_thick) + grow
		"tail_base":
			sh.tail_thick = float(sh.tail_thick) + grow
		"arms":
			var v: Vector3 = (_creature.anchors.arms as Vector3) + d - _creature.arm_shoulder()
			sh.arm_len = v.length() / (0.74 * float(sh.arm_size))
			var rest := Vector3(0.1, -0.75, 0.6).normalized()
			sh.arm_pitch = wrapf(atan2(v.y, v.z) - atan2(rest.y, rest.z), -PI, PI)
		"tail":
			var v: Vector3 = (_creature.anchors.tail as Vector3) + d - _creature.tail_base()
			sh.tail_len = v.length() / maxf(_creature.tail_unit(), 0.01)
			sh.tail_pitch = atan2(v.y, -v.z)
		_:
			# Размер части: тянешь вверх или вправо — больше.
			var key: String = {"mouth": "mouth", "eyes": "eyes", "horns": "head", "back": "back", "feet": "feet", "claws": "claws"}.get(id, "")
			if key != "":
				sh.sizes[key] = LandParts.part_size(sh, key) + grow
	evo.land_shape = LandParts.fix_shape(sh)
	# Ручку держат — её точка переезжает вместе с формой, существо пересобирается.
	_dirty = true

func shape_value(key: String) -> float:
	if key.begins_with("place:"):
		var q := key.split(":")
		return float(LandParts.place(evo.land_shape, q[1], _creature.leg_count, _creature.eye_count)[int(q[2])])
	if key.begins_with("rot:"):
		return float(evo.land_shape.rot.get(key.substr(4), 0.0))
	if key.begins_with("dim:"):
		var q := key.split(":")
		return float(LandParts.dim(evo.land_shape, q[1])[int(q[2])])
	if key.begins_with("size:"):
		return LandParts.part_size(evo.land_shape, key.substr(5))
	return float(evo.land_shape.get(key, 1.0))

func set_shape_value(key: String, v: float) -> void:
	var sh: Dictionary = evo.land_shape
	if key.begins_with("place:"):
		var q := key.split(":")
		for part in [q[1], _pair(q[1]) if mirror else ""]:
			if part == "":
				continue
			var pl: Array = LandParts.place(sh, part, _creature.leg_count, _creature.eye_count).duplicate()
			# У глаз «вокруг головы» зеркалится: левый — влево, правый — вправо.
			var flip: bool = part != q[1] and part.begins_with("eye") and q[2] == "0"
			pl[int(q[2])] = -v if flip else v
			sh.place[part] = pl
	elif key.begins_with("rot:"):
		sh.rot[key.substr(4)] = v
	elif key.begins_with("dim:"):
		var q := key.split(":")
		for part in [q[1], _pair(q[1]) if mirror else ""]:
			if part == "":
				continue
			var d: Array = LandParts.dim(sh, part).duplicate()
			d[int(q[2])] = v
			sh.dims[part] = d
	elif key.begins_with("size:"):
		sh.sizes[key.substr(5)] = v
	else:
		sh[key] = v
	evo.land_shape = LandParts.fix_shape(sh)
	_dirty = true

## Подпись у кружка, пока его держат: что меняется и насколько.
func handle_label(id: String) -> String:
	var sh: Dictionary = evo.land_shape
	if ":" in id:
		var q := id.split(":")
		var nn := func(v: float) -> String: return "×" + LandParts._num(snappedf(v, 0.05))
		match q[0]:
			"place":
				return "переставить"
			"len":
				return "длина " + nn.call(LandParts.dim(sh, q[1])[0])
			"thick":
				return "толщина " + nn.call(LandParts.dim(sh, q[1])[1])
			"feet":
				return "ступни " + nn.call(LandParts.part_size(sh, "feet"))
			"hand":
				return "рука " + nn.call(LandParts.dim(sh, q[1])[0])
	var n := func(v: float) -> String: return "×" + LandParts._num(snappedf(v, 0.05))
	match id:
		"g0", "g1", "g2", "g3", "g4":
			return "толщина " + n.call(sh.girth[int(id.substr(1))])
		"len_back", "len_front":
			return "длина " + n.call(sh.len)
		"head":
			return "шея"
		"head_size":
			return "голова " + n.call(sh.head)
		"legs":
			return "передние ноги " + n.call(sh.leg_len_f) if _creature.leg_count > 2 else "ноги " + n.call(sh.leg_len)
		"legs_back":
			return "задние ноги " + n.call(sh.leg_len)
		"width":
			return "ширина " + n.call(sh.width)
		"tilt":
			return "поднять %d°" % int(round(rad_to_deg(float(sh.torso_pitch))))
		"leg_thick":
			return "толщина ног " + n.call((float(sh.leg_thick) + float(sh.leg_thick_f)) / 2.0)
		"arms":
			return "руки " + n.call(sh.arm_len)
		"arm_thick":
			return "толщина рук " + n.call(sh.arm_thick)
		"tail":
			return "хвост " + n.call(sh.tail_len)
		"tail_base":
			return "толщина хвоста " + n.call(sh.tail_thick)
	var key: String = {"mouth": "mouth", "eyes": "eyes", "horns": "head", "back": "back", "feet": "feet", "claws": "claws"}.get(id, "")
	return "размер " + n.call(LandParts.part_size(sh, key))

## Сценарий проверки: потянуть кружок id на (dx, dy) точек экрана.
func sculpt(id: String, rel: Vector2) -> void:
	for i in 10:
		_sculpt(id, rel / 10.0)
		_rebuild_creature(false)

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

## Заготовки тела: что меняют в форме.
const PRESETS := [
	["Ящерица", {"torso_pitch": 0.0, "len": 1.8, "girth": [0.6, 0.75, 0.8, 0.75, 0.6], "leg_len": 0.6, "leg_len_f": 0.6, "tail_len": 2.2, "tail_pitch": 0.05, "head": 0.9, "neck_z": 0.1, "neck_y": 0.0}],
	["Толстяк", {"torso_pitch": 0.0, "len": 0.8, "girth": [1.3, 1.6, 1.7, 1.5, 1.1], "leg_len": 0.8, "leg_len_f": 0.8, "leg_thick": 1.6, "leg_thick_f": 1.6, "head": 1.1, "neck_z": 0.0, "neck_y": 0.0}],
	["Жираф", {"torso_pitch": 0.0, "len": 1.1, "girth": [0.8, 0.9, 0.95, 0.9, 0.7], "leg_len": 2.0, "leg_len_f": 2.2, "leg_thick": 0.8, "leg_thick_f": 0.8, "neck_y": 1.2, "neck_z": 0.5, "head": 0.8}],
	["Змей", {"torso_pitch": 0.0, "len": 2.4, "girth": [0.45, 0.55, 0.6, 0.55, 0.5], "leg_len": 0.5, "leg_len_f": 0.5, "leg_thick": 0.6, "leg_thick_f": 0.6, "tail_len": 3.0, "tail_pitch": 0.0, "head": 0.8, "neck_z": 0.0, "neck_y": 0.0}],
	["Горилла", {"torso_pitch": 0.35, "len": 1.0, "girth": [0.9, 1.1, 1.35, 1.6, 1.3], "leg_len": 0.9, "leg_len_f": 1.5, "leg_thick": 1.3, "leg_thick_f": 1.7, "arm_len": 1.8, "arm_thick": 1.8, "head": 1.1, "tail_len": 0.3, "neck_z": 0.0, "neck_y": 0.2}],
	["Прямоходящий", {"torso_pitch": 1.35, "len": 1.1, "girth": [0.95, 1.0, 0.95, 0.9, 0.85], "leg_len": 1.5, "leg_len_f": 1.5, "tail_len": 0.7, "tail_pitch": -0.35, "arm_pitch": 0.0, "neck_z": 0.0, "neck_y": 0.05}],
	["Крошка", {"len": 0.7, "girth": [0.7, 0.8, 0.8, 0.8, 0.7], "head": 1.6, "leg_len": 0.7, "leg_len_f": 0.7, "tail_len": 0.6, "neck_z": 0.0, "neck_y": 0.0}],
]


## Значок части в карточке: кружок-подложка и рисунок.
class PartIcon:
	extends Control
	var part := ""
	var c := Color.WHITE
	var c2 := Color.WHITE

	func _draw() -> void:
		var r := minf(size.x, size.y) / 2.0
		draw_circle(size / 2.0, r, Color(1, 1, 1, 0.06))
		LandIcons.draw(self, part, Rect2(size / 2.0 - Vector2(r, r) * 0.78, Vector2(r, r) * 1.56), c, c2)

## Кружки лепки поверх витрины. Зелёный — тянуть куда угодно, жёлтый — размер,
## синий — толщина. Держишь кружок — рядом подпись, что меняется.
class HandleLayer:
	extends Control
	var ed: Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if ed == null:
			return
		var font := get_theme_default_font()
		var t := Time.get_ticks_msec() / 1000.0
		if ed._carry != "":
			# Несомая часть под пальцем.
			var at: Vector2 = ed._carry_at + Vector2(0, -60)
			draw_circle(at, 46, Color(0.05, 0.08, 0.1, 0.8))
			draw_arc(at, 46, 0, TAU, 40, Art.GREEN, 3, true)
			var cc: Array = ed._colors()
			LandIcons.draw(self, ed._carry, Rect2(at - Vector2(32, 32), Vector2(64, 64)), cc[0], cc[1])
			var hint := "Отпусти на существе"
			var w := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			draw_string_outline(font, at + Vector2(-w / 2.0, 72), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 6, Color(0, 0, 0, 0.6))
			draw_string(font, at + Vector2(-w / 2.0, 72), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Art.TEXT)
			return
		for h in ed.handles():
			var p: Vector2 = h[2]
			var kind: String = h[1]
			var held: bool = ed._grab == h[0]
			var col: Color = {"move": Color("#7ee0a0"), "size": Art.GOLD, "thick": Color("#78b8f0")}.get(kind, Color("#f0f0e8"))
			var r := 17.0 if held else 13.0 + sin(t * 3.0) * 1.2
			draw_circle(p + Vector2(0, 2), r + 3, Color(0, 0, 0, 0.3))
			draw_circle(p, r + 3, Color(1, 1, 1, 0.95))
			draw_circle(p, r, col)
			# Стрелочки: куда тянуть.
			var arrow := Color(0.1, 0.12, 0.14, 0.85)
			match kind:
				"girth", "updown", "size":
					draw_line(p + Vector2(0, -7), p + Vector2(0, 7), arrow, 2.5)
					draw_polyline(PackedVector2Array([p + Vector2(-4, -3), p + Vector2(0, -8), p + Vector2(4, -3)]), arrow, 2.5)
					draw_polyline(PackedVector2Array([p + Vector2(-4, 3), p + Vector2(0, 8), p + Vector2(4, 3)]), arrow, 2.5)
				"len", "thick":
					draw_line(p + Vector2(-7, 0), p + Vector2(7, 0), arrow, 2.5)
					draw_polyline(PackedVector2Array([p + Vector2(-3, -4), p + Vector2(-8, 0), p + Vector2(-3, 4)]), arrow, 2.5)
					draw_polyline(PackedVector2Array([p + Vector2(3, -4), p + Vector2(8, 0), p + Vector2(3, 4)]), arrow, 2.5)
				_:
					draw_circle(p, 3.5, arrow)
			if held:
				var text: String = ed.handle_label(h[0])
				var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
				var at := p + Vector2(-w / 2.0, -28)
				draw_style_box(Kit.box(Color(0.05, 0.08, 0.1, 0.85), 10, Color(0, 0, 0, 0), 0), Rect2(at + Vector2(-8, -22), Vector2(w + 16, 30)))
				draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Art.TEXT)

## Ползунок: подпись и число сверху, дорожка и шарик снизу. Тянешь пальцем вбок.
class ValueSlider:
	extends Control
	var ed: Control
	var key := ""
	var text := ""
	var lo := 0.5
	var hi := 2.0
	## Наклон и шея — в метрах и градусах, а не «во сколько раз».
	var angle := false
	var _held := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _track() -> Rect2:
		return Rect2(16, size.y - 22, size.x - 32, 8)

	func _gui_input(e: InputEvent) -> void:
		var set_x := false
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			_held = e.pressed
			set_x = e.pressed
			if e.pressed:
				# Список под ползунком не листать, пока его тянут; запомнить для «Отменить».
				ed._scroll.cancel()
				ed._snap()
			else:
				ed._refresh_stats()
		elif e is InputEventMouseMotion and _held:
			set_x = true
		if set_x:
			var t := _track()
			var k := clampf((e.position.x - t.position.x) / t.size.x, 0.0, 1.0)
			ed.set_shape_value(key, lerpf(lo, hi, k))
			queue_redraw()
			accept_event()

	func _draw() -> void:
		var v: float = ed.shape_value(key)
		var font := get_theme_default_font()
		draw_string(font, Vector2(16, 24), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Art.TEXT)
		var num := "×" + LandParts._num(snappedf(v, 0.05))
		if key.begins_with("place:eye") and key.ends_with(":2"):
			num = "×" + LandParts._num(snappedf(v, 0.05))
		elif key.begins_with("place:") and key.ends_with(":0") and not key.begins_with("place:eye"):
			num = "%d%%" % int(round(v * 100.0))
		elif key.begins_with("place:"):
			num = "%d°" % int(round(rad_to_deg(v)))
		elif key.begins_with("rot:") or key.ends_with("curl") or key.ends_with("pitch"):
			num = "%d°" % int(round(rad_to_deg(v)))
		elif angle:
			num = ("%+.1f" % v).replace(".", ",")
		var w := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		draw_string(font, Vector2(size.x - 16 - w, 24), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Art.GOLD)
		var t := _track()
		draw_style_box(Kit.box(Color(1, 1, 1, 0.12), 4, Color(0, 0, 0, 0), 0), t)
		var k := clampf((v - lo) / (hi - lo), 0.0, 1.0)
		draw_style_box(Kit.box(Art.GREEN_DARK, 4, Color(0, 0, 0, 0), 0), Rect2(t.position, Vector2(t.size.x * k, t.size.y)))
		# Отметка «обычное».
		var d: float = ed.default_value(key)
		var dk := clampf((d - lo) / (hi - lo), 0.0, 1.0)
		draw_line(Vector2(t.position.x + t.size.x * dk, t.position.y - 5), Vector2(t.position.x + t.size.x * dk, t.end.y + 5), Color(1, 1, 1, 0.35), 2)
		var c := Vector2(t.position.x + t.size.x * k, t.get_center().y)
		draw_circle(c, 15 if _held else 13, Color.WHITE)
		draw_circle(c, 9 if _held else 8, Art.GREEN)

## Цвет-кружок для «Окраса».
class Swatch:
	extends Control
	signal pressed
	var col := Color.WHITE
	var on := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			accept_event()
			pressed.emit()

	func _draw() -> void:
		var r := minf(size.x, size.y) / 2.0 - 3.0
		if on:
			draw_circle(size / 2.0, r + 3.0, Color.WHITE)
		draw_circle(size / 2.0, r, col)

## Плитка узора: существо-капля сбоку с этим узором и подпись.
class PatternTile:
	extends Control
	signal pressed
	var pattern := ""
	var text := ""
	var c := Color.WHITE
	var c2 := Color.WHITE
	var on := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			accept_event()
			pressed.emit()

	func _draw() -> void:
		draw_style_box(Kit.box(Color(0.16, 0.3, 0.26, 1.0) if on else Art.CARD, 14, Art.GREEN if on else Art.CARD_BORDER, 0), Rect2(Vector2.ZERO, size))
		var ctr := Vector2(size.x / 2.0, 34)
		var rx := minf(size.x * 0.3, 52.0)
		var ry := 20.0
		Art.ellipse(self, ctr, rx, ry, c)
		match pattern:
			"spots":
				for q in [Vector2(-0.4, -0.4), Vector2(0.1, -0.6), Vector2(0.5, -0.2), Vector2(-0.1, 0.1)]:
					draw_circle(ctr + Vector2(q.x * rx, q.y * ry), 5, c2)
			"stripes", "tiger":
				var n := 7 if pattern == "tiger" else 4
				for i in n:
					var x := lerpf(-0.7, 0.7, float(i) / (n - 1)) * rx
					draw_line(ctr + Vector2(x, -ry * 0.9), ctr + Vector2(x - 3, ry * 0.2), c2, 5 if n == 4 else 3)
			"rings":
				for x in [-0.45, 0.0, 0.45]:
					draw_line(ctr + Vector2(x * rx, -ry * 0.95), ctr + Vector2(x * rx, ry * 0.95), c2, 5)
			"gradient":
				Art.ellipse(self, ctr + Vector2(-rx * 0.45, 0), rx * 0.55, ry * 0.95, c2)
			"belly":
				Art.ellipse(self, ctr + Vector2(0, ry * 0.45), rx * 0.85, ry * 0.5, c2)
			"back":
				draw_line(ctr + Vector2(-rx * 0.8, -ry * 0.75), ctr + Vector2(rx * 0.8, -ry * 0.75), c2, 5)
			"dots":
				for i in 12:
					draw_circle(ctr + Vector2(fmod(i * 0.37, 1.0) * 1.4 - 0.7, fmod(i * 0.61, 1.0) * 1.2 - 0.6) * Vector2(rx, ry), 2.5, c2)
			"leopard":
				for i in 6:
					var q := ctr + Vector2(fmod(i * 0.41, 1.0) * 1.3 - 0.65, fmod(i * 0.67, 1.0) * 1.0 - 0.5) * Vector2(rx, ry)
					draw_circle(q, 5, c2)
					draw_circle(q, 2.5, c.lightened(0.1))
		draw_circle(ctr + Vector2(rx * 0.95, -ry * 0.2), 8, c)
		var font := get_theme_default_font()
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(font, Vector2((size.x - w) / 2.0, size.y - 12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Art.TEXT if on else Art.MUTED)


## Раздел внизу: значок того, что стоит (бледный — если пусто), подпись.
class CatButton:
	extends Control
	signal pressed
	var part := ""
	var empty := false
	var c := Color.WHITE
	var c2 := Color.WHITE
	var text := ""
	var on := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			var sc := get_parent().get_parent() as ScrollContainer
			if sc and sc.get("_dragging"):
				return
			accept_event()
			pressed.emit()

	func _draw() -> void:
		var r := Rect2(Vector2(2, 2), size - Vector2(4, 4))
		draw_style_box(Kit.box(Color(0.16, 0.3, 0.26, 1.0) if on else Color(1, 1, 1, 0.04), 16, Art.GREEN if on else Color(0, 0, 0, 0), 0), r)
		var s := 42.0
		var fade := 0.35 if empty else 1.0
		LandIcons.draw(self, part, Rect2(size.x / 2.0 - s / 2.0, 8, s, s), Color(c, fade), Color(c2, fade))
		var font := get_theme_default_font()
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(font, Vector2((size.x - w) / 2.0, size.y - 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Art.TEXT if on else Art.MUTED)
		if not empty and part != "paint":
			draw_circle(Vector2(size.x - 12, 12), 4, Art.GOLD)

## Карточка в ряду: значок (часть или действие), название, строка пояснения, цена.
class Tile:
	extends Control
	signal pressed
	var ed: Control
	var _press := Vector2.ZERO
	var _carried := false
	var part := ""
	var ui_icon := ""
	var c := Color.WHITE
	var c2 := Color.WHITE
	var title := ""
	var sub := ""
	var price := ""
	var on := false
	var dim := false
	var warn := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(e: InputEvent) -> void:
		var sc := get_parent().get_parent() as ScrollContainer
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			_press = e.position
			_carried = false
		elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) and not _carried and ed and part != "" and part != "torso":
			# Повёл карточку вверх — несёшь часть на существо.
			var dv: Vector2 = e.position - _press
			if -dv.y > 28.0 and absf(dv.y) > absf(dv.x) and not (sc and sc.get("_dragging")):
				_carried = true
				ed.begin_carry(part, get_global_mouse_position())
		elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			if _carried:
				_carried = false
				return
			if sc and sc.get("_dragging"):
				return
			accept_event()
			pressed.emit()

	func _draw() -> void:
		var bg := Color(0.16, 0.3, 0.26, 1.0) if on else (Color(0.4, 0.16, 0.18, 1.0) if warn else Art.CARD)
		draw_style_box(Kit.box(bg, 16, Art.GREEN if on else Art.CARD_BORDER, 0), Rect2(Vector2.ZERO, size))
		var a := 0.45 if dim else 1.0
		var s := minf(62.0, size.y * 0.42)
		var ir := Rect2(size.x / 2.0 - s / 2.0, 10, s, s)
		if part != "":
			draw_circle(ir.get_center(), s * 0.62, Color(1, 1, 1, 0.05))
			LandIcons.draw(self, part, ir, Color(c, a), Color(c2, a))
		elif ui_icon != "":
			Icons.draw(self, ui_icon, ir.grow(-8), Color(Art.TEXT, 0.85 * a))
		var font := get_theme_default_font()
		var y := ir.end.y + 24
		_line(font, title, y, 18, Color(Art.TEXT, a))
		if sub != "":
			_line(font, sub, y + 21, 14, Color(Art.GREEN if not dim else Art.MUTED, a))
		if price != "":
			var col := Art.GREEN if on else (Art.DANGER if dim else Art.GOLD)
			_line(font, price, size.y - 10, 16, col)

	## Строка по центру; не влезла — с многоточием.
	func _line(font: Font, text: String, y: float, fs: int, col: Color) -> void:
		var t := text
		var maxw := size.x - 14
		while t.length() > 3 and font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > maxw:
			t = t.substr(0, t.length() - 2) + "…"
			t = t.substr(0, t.length() - 1).strip_edges() + "…" if t.ends_with("…") and t.length() > 4 else t
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2((size.x - w) / 2.0, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

## Ряд, который листается пальцем вбок. Повёл вбок больше чем на 14 точек — это
## прокрутка, и карточка под пальцем уже не нажмётся.
class TouchHScroll:
	extends ScrollContainer
	var _index := -1
	var _from := Vector2.ZERO
	var _start := 0
	var _dragging := false
	var _speed := 0.0

	func _ready() -> void:
		vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		size_flags_horizontal = Control.SIZE_EXPAND_FILL

	func _input(e: InputEvent) -> void:
		if not is_visible_in_tree():
			return
		if e is InputEventScreenTouch:
			if e.pressed and _index == -1 and get_global_rect().has_point(e.position):
				_index = e.index
				_from = e.position
				_start = scroll_horizontal
				_dragging = false
				_speed = 0.0
			elif not e.pressed and e.index == _index:
				_index = -1
				if _dragging:
					get_viewport().set_input_as_handled()
					# Отпустили — карточка под пальцем ещё успеет проверить _dragging.
					set_deferred("_dragging", false)
		elif e is InputEventScreenDrag and e.index == _index:
			var dx: float = e.position.x - _from.x
			var dy: float = e.position.y - _from.y
			if not _dragging and absf(dx) > 14.0 and absf(dx) > absf(dy):
				_dragging = true
			if _dragging:
				scroll_horizontal = int(_start - (e.position.x - _from.x))
				_speed = -e.velocity.x
				get_viewport().set_input_as_handled()

	func _process(delta: float) -> void:
		if _index == -1 and absf(_speed) > 20.0:
			scroll_horizontal += int(_speed * delta)
			_speed *= exp(-4.0 * delta)
