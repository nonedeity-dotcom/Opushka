## Редактор тела для суши. Слева — твоё существо в 3D: его можно крутить пальцем, оно
## дышит, машет хвостом и, когда меняешь ноги, проходится по кругу. Справа — места тела
## (рот, глаза, ноги…) и части для выбранного места: нажал — поставил, ДНК списалась;
## «Снять» — вернулась. Сверху — сколько ДНК свободно и что умеет тело.
##
## Лепка: на существе — кружки для выбранного места. Тянешь кружок — меняется форма:
## на «Теле» — толщина в пяти местах по спине, длина с концов, голова (шея) и её размер;
## на ногах, руках, хвосте — длина, наклон и толщина; на остальных — размер части.
## Зелёный кружок двигают куда угодно, жёлтый — вверх больше / вниз меньше, синий —
## вправо или вверх толще.
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
var slot := "torso"
## Выбранная касанием часть: torso, head, mouth, eyes, horns, back, tail, leg0…, arm0/1.
var sel := "torso"
## Менять пару вместе: левую и правую ногу (руку) одинаково.
var mirror := true
var _press_at := Vector2.ZERO
var _tap := false
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
var _start_shape := {}
var _start_paint := {}
var _done_btn: Button
## Лепка: какой кружок держат, каким пальцем, пора ли пересобрать существо.
var _grab := ""
var _grab_index := -1
var _dirty := false
var _rebuild_in := 0.0
var _yaw_to := PI / 2.0
var _handles: HandleLayer
## Панель свёрнута — видно только существо.
var collapsed := false
var _expand_btn: Control
var _done_float: Button
var _arming_clear := false

## Кружки лепки: место → [[ручка, вид]]. Вид: move — тянуть куда угодно, girth — толщина
## туловища, len — длина туловища, size — размер, thick — толщина, updown — выше/ниже.
const HANDLES := {
	"torso": [["g0", "girth"], ["g1", "girth"], ["g2", "girth"], ["g3", "girth"], ["g4", "girth"],
		["len_back", "len"], ["len_front", "len"], ["width", "thick"], ["head", "move"], ["head_size", "size"]],
	"legs": [["legs", "updown"], ["legs_back", "updown"], ["leg_thick", "thick"]],
	"feet": [["feet", "size"]],
	"claws": [["claws", "size"]],
	"arms": [["arms", "move"], ["arm_thick", "thick"]],
	"tail": [["tail", "move"], ["tail_base", "thick"]],
	"back": [["back", "size"]],
	"head": [["horns", "size"]],
	"mouth": [["mouth", "size"]],
	"eyes": [["eyes", "size"]],
	"skin": [],
	"paint": [],
}
## С какой стороны смотреть на место: сбоку или вполоборота спереди.
const VIEW_YAW := {"torso": PI / 2.0, "legs": PI / 2.0, "tail": PI / 2.0 + 0.5, "back": PI / 2.0,
	"mouth": 0.8, "eyes": 0.6, "head": 0.8, "arms": 0.9, "feet": 0.9, "claws": 0.7, "skin": 0.9, "paint": 0.9}
## Заготовки тела: что меняют в форме.
const PRESETS := [
	["Ящерица", {"len": 1.8, "girth": [0.6, 0.75, 0.8, 0.75, 0.6], "leg_len": 0.6, "leg_len_f": 0.6, "tail_len": 2.2, "tail_pitch": 0.05, "head": 0.9, "neck_z": 0.1, "neck_y": 0.0}],
	["Толстяк", {"len": 0.8, "girth": [1.3, 1.6, 1.7, 1.5, 1.1], "leg_len": 0.8, "leg_len_f": 0.8, "leg_thick": 1.6, "leg_thick_f": 1.6, "head": 1.1, "neck_z": 0.0, "neck_y": 0.0}],
	["Жираф", {"len": 1.1, "girth": [0.8, 0.9, 0.95, 0.9, 0.7], "leg_len": 2.0, "leg_len_f": 2.2, "leg_thick": 0.8, "leg_thick_f": 0.8, "neck_y": 1.2, "neck_z": 0.5, "head": 0.8}],
	["Змей", {"len": 2.4, "girth": [0.45, 0.55, 0.6, 0.55, 0.5], "leg_len": 0.5, "leg_len_f": 0.5, "leg_thick": 0.6, "leg_thick_f": 0.6, "tail_len": 3.0, "tail_pitch": 0.0, "head": 0.8, "neck_z": 0.0, "neck_y": 0.0}],
	["Горилла", {"len": 1.0, "girth": [0.9, 1.1, 1.35, 1.6, 1.3], "leg_len": 0.9, "leg_len_f": 1.5, "leg_thick": 1.3, "leg_thick_f": 1.7, "arm_len": 1.8, "arm_thick": 1.8, "head": 1.1, "tail_len": 0.3, "neck_z": 0.0, "neck_y": 0.2}],
	["Крошка", {"len": 0.7, "girth": [0.7, 0.8, 0.8, 0.8, 0.7], "head": 1.6, "leg_len": 0.7, "leg_len_f": 0.7, "tail_len": 0.6, "neck_z": 0.0, "neck_y": 0.0}],
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)

## Открыть редактор. conv — что стало с частями клетки (только в первый раз).
func open(e: Evolution, is_first: bool, conv := {}) -> void:
	evo = e
	first = is_first
	_start_body = evo.land_body.duplicate()
	if evo.land_shape.is_empty():
		evo.land_shape = LandParts.shape_from_sea(evo.shape)
	evo.land_shape = LandParts.fix_shape(evo.land_shape)
	_start_shape = evo.land_shape.duplicate(true)
	if evo.land_paint.is_empty():
		evo.land_paint = evo.paint().duplicate()
	_start_paint = evo.land_paint.duplicate()
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
	_handles = HandleLayer.new()
	_handles.ed = self
	add_child(_handles)

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

func _process(delta: float) -> void:
	if not visible or _creature == null:
		return
	_idle += delta
	# Пока лепят — пересобирать не чаще 20 раз в секунду.
	_rebuild_in -= delta
	if _dirty and _rebuild_in <= 0.0:
		_dirty = false
		_rebuild_in = 0.05
		_rebuild_creature(false)
		_refresh_stats()
	# Выбрал место — камера сама поворачивается, откуда его лучше видно.
	if _drag == -1 and _yaw_to < 100.0:
		_yaw = lerp_angle(_yaw, _yaw_to, 1.0 - exp(-4.0 * delta))
		if absf(angle_difference(_yaw, _yaw_to)) < 0.01:
			_yaw_to = 1000.0
	# Походка: пару кругов по полянке, потом снова стоит.
	var vel := Vector3.ZERO
	if _walk_t > 0.0:
		_walk_t -= delta
		var spd := 2.2 * float(LandParts.stats(evo.land_body, evo.land_shape).speed)
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
	# Камера — чтобы существо было целиком, каким бы длинным или высоким его ни слепили.
	var ext := _creature.extent()
	var dist := (7.5 if _walk_t > 0.0 or _pos.length() > 0.3 else 3.0) + ext * 1.5
	var target := Vector3(0, clampf(ext * 0.35, 0.6, 2.2), 0)
	var want := target + Vector3(sin(_yaw) * dist, 0.6 + dist * 0.2, cos(_yaw) * dist)
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
			# Попал в кружок — лепим, мимо — крутим существо.
			_grab = _handle_at(e.position - _box.global_position)
			_press_at = e.position
			_tap = true
			if _grab != "":
				_walk_t = 0.0
				changed.emit(true, false)
		elif not e.pressed and e.index == _drag:
			_drag = -1
			if _grab != "" and not _tap:
				_grab = ""
				_dirty = true
				_refresh.call_deferred()
			elif _tap:
				_grab = ""
				# Коснулся и отпустил, не ведя, — выбрать часть под пальцем.
				var key := pick(e.position - _box.global_position)
				if key != "":
					select(key)
					changed.emit(true, false)
					_refresh.call_deferred()
	elif e is InputEventScreenDrag and e.index == _drag:
		_idle = 0.0
		if _tap and e.position.distance_to(_press_at) > 14.0:
			_tap = false
		if _grab != "":
			# Кружок: лепим, как только палец сдвинулся (короткое касание — выбор части).
			if not _tap:
				_sculpt(_grab, e.relative)
		else:
			_yaw -= e.relative.x * 0.01
			_yaw_to = 1000.0

# --- выбор части ----------------------------------------------------------------------

## Выбрать часть: подсветить на существе, открыть её место.
func select(key: String) -> void:
	sel = key
	var s := _slot_of(key)
	if s != "":
		slot = s
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
	return {"torso": "torso", "head": "torso", "mouth": "mouth", "eyes": "eyes", "horns": "head", "back": "back", "tail": "tail"}.get(key, "")

## Какую часть выбрать, когда открыли место: у ног — переднюю левую, у рук — правую…
func _default_sel(s: String) -> String:
	match s:
		"legs", "feet", "claws":
			return "leg0" if evo.land_body.has("legs") else ""
		"arms":
			return "arm1" if evo.land_body.has("arms") else ""
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
		var side := "левая" if i % 2 == 0 else "правая"
		if n <= 2:
			return "Нога — " + side
		var row: String = ["передняя", "средняя" if n == 6 else "задняя", "задняя"][i / 2]
		return "Нога — %s %s" % [row, side]
	if key.begins_with("arm"):
		return "Рука — левая" if key == "arm0" else "Рука — правая"
	return {"torso": "Туловище", "head": "Голова", "mouth": "Рот", "eyes": "Глаза", "horns": "Рога и гребень", "back": "Спина", "tail": "Хвост"}.get(key, key)

## Блок выбранной части: название, ползунки, для пары — «обе стороны», для ног — «всем».
func _sel_block() -> void:
	if sel == "" or not _creature.groups.has(sel):
		if evo.land_body.has("torso"):
			var tip := Kit.label("Нажми на часть существа, чтобы менять её длину, ширину, высоту", 17, Art.GOLD)
			tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_list.add_child(tip)
		return
	var head := Kit.hbox(8)
	var t := Kit.label("Выбрано: " + sel_name(sel), 21, Art.TEXT, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_list.add_child(head)
	var rows: Array
	if sel == "torso":
		rows = [["Длина", "len"], ["Ширина", "width"], ["Высота", "height"], ["Размер", "torso"]]
	else:
		rows = [["Длина", "dim:%s:0" % sel], ["Ширина", "dim:%s:1" % sel], ["Высота", "dim:%s:2" % sel], ["Размер", "dim:%s:3" % sel]]
		if sel == "head":
			rows += [["Шея вперёд", "neck_z"], ["Шея вверх", "neck_y"]]
		if sel.begins_with("arm"):
			rows.append(["Наклон рук", "arm_pitch"])
		if sel == "tail":
			rows.append(["Наклон", "tail_pitch"])
	_add_sliders(rows)
	if sel.begins_with("leg") or sel.begins_with("arm"):
		var row := Kit.hbox(8)
		var m := _button("Обе стороны одинаково: " + ("да" if mirror else "нет"), Art.CARD_BORDER if mirror else Art.CARD, func():
			mirror = not mirror
			_refresh.call_deferred())
		m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m.custom_minimum_size.y = 46
		m.add_theme_font_size_override("font_size", 17)
		row.add_child(m)
		if sel.begins_with("leg") and _creature.leg_count > 2:
			var all := _button("Всем ногам так же", Art.CARD_BORDER, func():
				var d: Array = LandParts.dim(evo.land_shape, sel).duplicate()
				for i in _creature.leg_count:
					evo.land_shape.dims["leg%d" % i] = d.duplicate()
				_after_change.call_deferred("Все ноги одинаковые"))
			all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			all.custom_minimum_size.y = 46
			all.add_theme_font_size_override("font_size", 17)
			row.add_child(all)
		_list.add_child(row)
	var norm := _button("Эта часть — как обычно", Art.CARD_BORDER, func():
		if sel == "torso":
			for k in ["len", "width", "height", "torso"]:
				evo.land_shape[k] = LandParts.SHAPE[k][0]
		else:
			evo.land_shape.dims.erase(sel)
			if mirror:
				evo.land_shape.dims.erase(_pair(sel))
		_after_change.call_deferred("Как обычно"))
	norm.custom_minimum_size.y = 44
	norm.add_theme_font_size_override("font_size", 17)
	_list.add_child(norm)

## Пара части: левая ↔ правая нога того же ряда, левая ↔ правая рука.
func _pair(key: String) -> String:
	if key.begins_with("leg"):
		return "leg%d" % (int(key.substr(3)) ^ 1)
	if key.begins_with("arm"):
		return "arm1" if key == "arm0" else "arm0"
	return ""

## «Готово» — только если есть на чём ходить.
func try_done() -> void:
	if not evo.land_can_walk():
		changed.emit(false, false)
		_after_change("Нужны туловище и ноги — иначе на суше не походишь")
		return
	done.emit()

# --- лепка ----------------------------------------------------------------------------

## Кружки выбранного места, которые сейчас есть на существе: [[ручка, вид, точка на экране]].
func handles() -> Array:
	var out: Array = []
	if _creature == null or _walk_t > 0.0 or _pos.length() > 0.3 or (_overlay and _overlay.visible):
		return out
	for h in HANDLES.get(slot, []):
		var id: String = h[0]
		if not _creature.anchors.has(id):
			continue
		if h[1] == "size" and slot != "torso" and slot != "feet" and not evo.land_body.has(slot):
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

# --- правая панель --------------------------------------------------------------------

func _build_panel() -> void:
	_panel = Kit.vbox(10)
	add_child(_panel)
	var head := Kit.hbox(10)
	var fold := RoundButton.new()
	fold.setup("expand", "Свернуть — видно только существо", 48)
	fold.pressed.connect(func(): set_collapsed.call_deferred(true))
	head.add_child(fold)
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
	_done_btn = _button("Выйти на сушу" if first else "Готово", Art.GREEN, try_done)
	_done_btn.custom_minimum_size.y = 60
	_done_btn.add_theme_font_size_override("font_size", 25)
	var bottom := Kit.hbox(10)
	var reset := _button("Как было", Art.CARD_BORDER, func():
		evo.land_body = _start_body.duplicate()
		evo.land_shape = _start_shape.duplicate(true)
		evo.land_paint = _start_paint.duplicate()
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
	# Свёрнуто: только кнопка «Части» и «Готово» поверх витрины.
	_expand_btn = RoundButton.new()
	_expand_btn.setup("shrink", "Показать части", 64)
	_expand_btn.caption = "Части"
	_expand_btn.floating = true
	_expand_btn.visible = false
	_expand_btn.pressed.connect(func(): set_collapsed.call_deferred(false))
	add_child(_expand_btn)
	_done_float = _button("Выйти на сушу" if first else "Готово", Art.GREEN, try_done)
	_done_float.custom_minimum_size = Vector2(220, 56)
	_done_float.visible = false
	add_child(_done_float)

## Свернуть панель — видно только существо (и кружки лепки), или развернуть обратно.
func set_collapsed(on: bool) -> void:
	collapsed = on
	_panel.visible = not on
	_expand_btn.visible = on
	_done_float.visible = on
	_layout()

func _layout() -> void:
	if _box == null:
		return
	var landscape := size.x >= size.y
	if collapsed:
		_box.position = Vector2.ZERO
		_box.size = size
	elif landscape:
		var w := minf(size.x * 0.46, 700.0)
		_box.position = Vector2.ZERO
		_box.size = Vector2(size.x - w - 12, size.y)
		_panel.position = Vector2(size.x - w, 16)
		_panel.size = Vector2(w - 18, size.y - 32)
		_tabs.columns = 6
	else:
		var h := size.y * 0.42
		_box.position = Vector2.ZERO
		_box.size = Vector2(size.x, h)
		_panel.position = Vector2(16, h + 8)
		_panel.size = Vector2(size.x - 32, size.y - h - 24)
		_tabs.columns = 6
	_stats.size = Vector2(_box.size.x - 32, 0)
	_stats.position = Vector2(16, _box.size.y - 60)
	_expand_btn.size = Vector2(64, 64)
	_expand_btn.position = Vector2(size.x - 64 - 24, 18)
	_done_float.size = _done_float.custom_minimum_size
	_done_float.position = size - _done_float.size - Vector2(24, 24)
	_handles.position = _box.position
	_handles.size = _box.size
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
	var cc := _colors()
	for s in LandParts.SLOTS + [["paint", "Окрас", ""]]:
		var id: String = s[0]
		var t := SlotTab.new()
		t.part = evo.land_body.get(id, LandIcons.SLOT_ICON.get(id, "body"))
		t.empty = id != "paint" and not evo.land_body.has(id)
		t.c = cc[0]
		t.c2 = cc[1]
		t.text = s[1]
		t.on = id == slot
		t.filled = evo.land_body.has(id) and not (id == "legs" and evo.land_body[id] == "stubs")
		t.custom_minimum_size = Vector2(0, 74)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Перестраивать список — после касания, не посреди него (иначе кнопка уже вне дерева).
		t.pressed.connect(func():
			slot = id
			select(_default_sel(id))
			_arming_clear = false
			_scroll.scroll_vertical = 0
			_yaw_to = VIEW_YAW.get(id, 0.9)
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
	# Выбранная часть — сверху: её длина, ширина, высота, размер.
	_sel_block()
	if slot == "torso":
		_body_list()
		_refresh_stats()
		return
	if slot == "paint":
		_paint_list()
		_refresh_stats()
		return
	var sz_key := "head" if slot == "head" else slot

	if HANDLES.get(slot, []).size() > 0 and (cur != "" or slot == "feet" or slot == "tail"):
		var how := Kit.label(_sculpt_hint(slot), 17, Art.GOLD)
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(how)
		if not _shape_is_default(slot, sz_key):
			var norm := _button("Обычный размер", Art.CARD_BORDER, func():
				_reset_shape(slot, sz_key)
				changed.emit(true, true)
				_after_change.call_deferred("Размер как обычно"))
			norm.custom_minimum_size.y = 44
			norm.add_theme_font_size_override("font_size", 18)
			_list.add_child(norm)
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
	_refresh_stats()

## Что умеет тело — плашки над витриной.
func _refresh_stats() -> void:
	_dna.text = "ДНК: %d" % evo.land_free()
	for ch in _stats.get_children():
		_stats.remove_child(ch)
		ch.queue_free()
	if not evo.land_body.has("torso"):
		return
	var st := LandParts.stats(evo.land_body, evo.land_shape)
	var chips := [["dash", "Скорость %d%%" % int(round(st.speed * 100.0))], ["bite", "Укус %d" % int(st.bite)],
		["heart", "Здоровье %d" % int(st.hp)], ["eye", "Зрение %d%%" % int(round(st.sight * 100.0))]]
	if st.armor > 0.0:
		chips.append(["shield", "Броня %d%%" % int(round(st.armor * 100.0))])
	if not st.mouth:
		chips.append(["close", "Без рта не ешь"])
	for c in chips:
		_stats.add_child(Kit.info_chip(c[0], c[1]))

## Вкладка «Тело»: как лепить, заготовки, сгладить, как было в воде.
func _body_list() -> void:
	if not evo.land_body.has("torso"):
		var empty := Kit.label("Пусто. Начни с туловища — к нему крепится всё остальное.", 19, Art.GOLD)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(empty)
		_list.add_child(_part_card("torso", false))
		return
	var how := Kit.label("Тяни кружки на существе: по спине — толще или тоньше, с концов — длиннее или короче, зелёный на голове — шея (выше, дальше), жёлтый над головой — голова больше.", 17, Art.GOLD)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(how)
	var st := LandParts.stats(evo.land_body, evo.land_shape)
	var base := LandParts.stats(evo.land_body, LandParts.default_shape())
	var eff := Kit.label("Форма даёт: здоровье ×%s · скорость ×%s" % [LandParts._num(snappedf(st.hp / base.hp, 0.01)), LandParts._num(snappedf(st.speed / base.speed, 0.01))], 18, Art.GREEN)
	_list.add_child(eff)
	_list.add_child(Kit.label("Заготовки", 20, Art.TEXT, true))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for pr in PRESETS:
		var b := _button(pr[0], Art.CARD, func():
			var sh: Dictionary = evo.land_shape.duplicate(true)
			for k in pr[1]:
				sh[k] = pr[1][k]
			evo.land_shape = LandParts.fix_shape(sh)
			_walk_t = 3.0
			changed.emit(true, false)
			_after_change.call_deferred(pr[0]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 50
		b.add_theme_font_size_override("font_size", 19)
		grid.add_child(b)
	_list.add_child(grid)
	var row := Kit.hbox(8)
	for pair in [["Сгладить", func():
			var g: Array = evo.land_shape.girth
			var out: Array = []
			for i in g.size():
				var a: float = g[maxi(i - 1, 0)]
				var b: float = g[mini(i + 1, g.size() - 1)]
				out.append((a + float(g[i]) * 2.0 + b) / 4.0)
			evo.land_shape.girth = out
			_after_change.call_deferred("Сгладил")],
		["Как в воде", func():
			var keep: Dictionary = evo.land_shape.sizes
			evo.land_shape = LandParts.shape_from_sea(evo.shape)
			evo.land_shape.sizes = keep
			_after_change.call_deferred("Как клетка в воде")]]:
		var b := _button(pair[0], Art.CARD_BORDER, pair[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 48
		b.add_theme_font_size_override("font_size", 19)
		row.add_child(b)
	_list.add_child(row)
	_list.add_child(_clear_button())

## С нуля — совсем пусто: со второго нажатия, чтобы не стереть всё случайно.
func _clear_button() -> Button:
	var clear := _button("Точно? Убрать всё существо" if _arming_clear else "С нуля — убрать всё, совсем пусто",
		Color(0.62, 0.2, 0.22) if _arming_clear else Color(0.4, 0.2, 0.22), func():
			if not _arming_clear:
				_arming_clear = true
				_refresh.call_deferred()
				return
			_arming_clear = false
			var r := evo.land_clear()
			changed.emit(true, true)
			_after_change.call_deferred(r.message))
	clear.custom_minimum_size.y = 50
	clear.add_theme_font_size_override("font_size", 19)
	return clear

## Ползунки для места: [подпись, ключ формы]. «size:место» — размер части.
func _slider_rows(s: String, cur: String) -> Array:
	match s:
		"body":
			return [["Размер туловища", "torso"], ["Длина", "len"], ["Ширина", "width"], ["Высота", "height"],
				["Голова", "head"], ["Шея вперёд", "neck_z"], ["Шея вверх", "neck_y"]]
		"legs":
			if _creature.leg_count > 2:
				return [["Размер ног", "leg_size"], ["Передние — длина", "leg_len_f"], ["Передние — ширина", "leg_thick_f"],
					["Задние — длина", "leg_len"], ["Задние — ширина", "leg_thick"], ["Ступни", "size:feet"]]
			return [["Размер ног", "leg_size"], ["Длина", "leg_len"], ["Ширина", "leg_thick"], ["Ступни", "size:feet"]]
		"arms":
			if cur == "":
				return []
			return [["Размер рук", "arm_size"], ["Длина", "arm_len"], ["Ширина", "arm_thick"], ["Наклон", "arm_pitch"], ["Кисти", "size:arms"]]
		"tail":
			return [["Размер хвоста", "tail_size"], ["Длина", "tail_len"], ["Ширина", "tail_thick"], ["Наклон", "tail_pitch"]]
		"feet":
			return [["Размер ступней", "size:feet"]]
		"skin", "paint":
			return []
	if cur == "":
		return []
	return [["Размер", "size:" + s]]

func shape_value(key: String) -> float:
	if key.begins_with("dim:"):
		var q := key.split(":")
		return float(LandParts.dim(evo.land_shape, q[1])[int(q[2])])
	if key.begins_with("size:"):
		return LandParts.part_size(evo.land_shape, key.substr(5))
	return float(evo.land_shape.get(key, 1.0))

func set_shape_value(key: String, v: float) -> void:
	var sh: Dictionary = evo.land_shape
	if key.begins_with("dim:"):
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

func _add_sliders(rows: Array) -> void:
	var box := Kit.vbox(4)
	for r in rows:
		var key: String = r[1]
		var sl := ValueSlider.new()
		sl.text = r[0]
		sl.ed = self
		sl.key = key
		var lim: Array
		if key.begins_with("dim:"):
			lim = LandParts.DIM_SIZE_LIMITS if key.ends_with(":3") else LandParts.DIM_LIMITS
		elif key.begins_with("size:"):
			lim = LandParts.SIZE_LIMITS
		else:
			lim = [LandParts.SHAPE[key][1], LandParts.SHAPE[key][2]]
		sl.lo = lim[0]
		sl.hi = lim[1]
		sl.angle = key.ends_with("pitch") or key.begins_with("neck")
		sl.custom_minimum_size = Vector2(0, 62)
		box.add_child(sl)
	_list.add_child(Kit.card(box, Color(1, 1, 1, 0.04), 14, 10))

## Вкладка «Окрас»: основной цвет, цвет узора, узор. Бесплатно.
func _paint_list() -> void:
	var pt := evo.paint()
	for pair in [["Основной цвет", "color"], ["Цвет узора", "color2"]]:
		_list.add_child(Kit.label(pair[0], 20, Art.TEXT, true))
		var grid := GridContainer.new()
		grid.columns = 7
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		for i in LandParts.COLORS.size():
			var sw := Swatch.new()
			sw.col = Color(LandParts.COLORS[i])
			sw.on = int(pt[pair[1]]) == i
			sw.custom_minimum_size = Vector2(0, 46)
			sw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var key: String = pair[1]
			sw.pressed.connect(func(): _set_paint.call_deferred(key, i))
			grid.add_child(sw)
		_list.add_child(grid)
	_list.add_child(Kit.label("Узор", 20, Art.TEXT, true))
	var pg := GridContainer.new()
	pg.columns = 3
	pg.add_theme_constant_override("h_separation", 8)
	pg.add_theme_constant_override("v_separation", 8)
	var cc := _colors()
	for q in LandParts.PATTERNS:
		var tile := PatternTile.new()
		tile.pattern = q[0]
		tile.text = q[1]
		tile.c = cc[0]
		tile.c2 = Color(LandParts.COLORS[pt.color2])
		tile.on = pt.pattern == q[0]
		tile.custom_minimum_size = Vector2(0, 92)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = q[0]
		tile.pressed.connect(func(): _set_paint.call_deferred("pattern", id))
		pg.add_child(tile)
	_list.add_child(pg)

func _set_paint(key: String, v: Variant) -> void:
	var pt := evo.paint().duplicate()
	pt[key] = v
	evo.land_paint = LandParts.fix_paint(pt)
	changed.emit(true, false)
	_after_change("")

func _sculpt_hint(s: String) -> String:
	match s:
		"legs":
			return "Тяни кружок у бедра вверх — ноги длиннее, вниз — короче. Синий на ноге — толще или тоньше."
		"arms":
			return "Тяни кисть — руки длиннее и выше или ниже. Синий у локтя — толще."
		"tail":
			return "Тяни кончик хвоста — длиннее, выше или ниже. Синий у основания — толще."
	return "Тяни жёлтый кружок вверх или вправо — часть больше, вниз или влево — меньше."

func _shape_is_default(s: String, key: String) -> bool:
	var sh: Dictionary = evo.land_shape
	var d := LandParts.default_shape()
	match s:
		"legs", "arms", "tail":
			var pre: String = {"legs": "leg_", "arms": "arm_", "tail": "tail_"}[s]
			for k in sh:
				if String(k).begins_with(pre) and sh[k] is float and not is_equal_approx(sh[k], d[k]):
					return false
			return true
	return not sh.sizes.has(key)

func _reset_shape(s: String, key: String) -> void:
	var d := LandParts.default_shape()
	var keys: Array = {"legs": ["leg_size", "leg_len", "leg_thick", "leg_len_f", "leg_thick_f"], "arms": ["arm_size", "arm_len", "arm_thick", "arm_pitch"],
		"tail": ["tail_size", "tail_len", "tail_thick", "tail_pitch"]}.get(s, [])
	for k in keys:
		evo.land_shape[k] = d[k]
	evo.land_shape.sizes.erase(key)

func _slot_hint(s: String) -> String:
	match s:
		"torso":
			return "Нажми на любую часть существа — выберешь её, и здесь появятся её длина, ширина, высота и размер. От формы зависят здоровье и скорость: толще — крепче, но медленнее."
		"paint":
			return "Цвета и узор — бесплатно. Узор рисуется вторым цветом."
		"mouth":
			return "Рот решает, что тебе вкуснее: плоды или мясо с яйцами, и как больно кусаешь."
		"eyes":
			return "Без глаз вокруг туман. Чем лучше глаза, тем дальше видно."
		"legs":
			return "Ноги — это скорость. Без ног на суше не походишь. Нажми на ногу на существе — у каждой свои длина, ширина, высота."
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
	var can := (on or cost <= free) and (id == "torso" or evo.land_body.has("torso"))
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
	if id != "torso" and not evo.land_body.has("torso"):
		sum = "Сначала туловище"
	if sum != "":
		var s := Kit.label(sum, 17, Art.GREEN if can else Art.MUTED)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(s)
	var h := Kit.muted(p.hint, 16)
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(h)
	var cc := _colors()
	var icon := PartIcon.new()
	icon.part = id
	icon.c = cc[0] if can else Color(cc[0], 0.45)
	icon.c2 = cc[1] if can else Color(cc[1], 0.45)
	icon.custom_minimum_size = Vector2(70, 70)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := Kit.hbox(12)
	line.add_child(icon)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(col)
	var card := Kit.card(line, Color(0.16, 0.3, 0.26, 0.95) if on else Art.CARD, 16, 12)
	if on:
		card.add_theme_stylebox_override("panel", Kit.box(Color(0.16, 0.3, 0.26, 0.95), 16, Art.GREEN, 12))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(ev: InputEvent):
		var tap: bool = (ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT)
		if tap and not on and not _scroll.get("_dragging"):
			card.accept_event()
			put.call_deferred(id))
	return card

## Подпись у кружка, пока его держат: что меняется и насколько.
func handle_label(id: String) -> String:
	var sh: Dictionary = evo.land_shape
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

## Плитка места тела: значок того, что там стоит (или бледный — если пусто), подпись;
## точка — место занято.
class SlotTab:
	extends Control
	signal pressed
	var part := ""
	var empty := false
	var c := Color.WHITE
	var c2 := Color.WHITE
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
		var s := 38.0
		var fade := 0.35 if empty else 1.0
		LandIcons.draw(self, part, Rect2(size.x / 2.0 - s / 2.0, 6, s, s), Color(c, fade), Color(c2, fade))
		var font := get_theme_default_font()
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(font, Vector2((size.x - w) / 2.0, size.y - 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Art.TEXT if on else Art.MUTED)
		if filled:
			draw_circle(Vector2(size.x - 10, 10), 5, Art.GOLD)

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
				# Список под ползунком не листать, пока его тянут.
				ed._scroll.cancel()
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
		var num := ("%+.1f" % v).replace(".", ",") if angle else "×" + LandParts._num(snappedf(v, 0.05))
		var w := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		draw_string(font, Vector2(size.x - 16 - w, 24), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Art.GOLD)
		var t := _track()
		draw_style_box(Kit.box(Color(1, 1, 1, 0.12), 4, Color(0, 0, 0, 0), 0), t)
		var k := clampf((v - lo) / (hi - lo), 0.0, 1.0)
		draw_style_box(Kit.box(Art.GREEN_DARK, 4, Color(0, 0, 0, 0), 0), Rect2(t.position, Vector2(t.size.x * k, t.size.y)))
		# Отметка «обычное».
		var d: float = LandParts.SHAPE[key][0] if LandParts.SHAPE.has(key) else 1.0
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
