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

var evo: Evolution
var first := false
var slot := "body"
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
var _done_btn: Button
## Лепка: какой кружок держат, каким пальцем, пора ли пересобрать существо.
var _grab := ""
var _grab_index := -1
var _dirty := false
var _rebuild_in := 0.0
var _yaw_to := PI / 2.0
var _handles: HandleLayer

## Кружки лепки: место → [[ручка, вид]]. Вид: move — тянуть куда угодно, girth — толщина
## туловища, len — длина туловища, size — размер, thick — толщина, updown — выше/ниже.
const HANDLES := {
	"body": [["g0", "girth"], ["g1", "girth"], ["g2", "girth"], ["g3", "girth"], ["g4", "girth"],
		["len_back", "len"], ["len_front", "len"], ["head", "move"], ["head_size", "size"]],
	"legs": [["legs", "updown"], ["leg_thick", "thick"]],
	"feet": [["feet", "size"]],
	"claws": [["claws", "size"]],
	"arms": [["arms", "move"], ["arm_thick", "thick"]],
	"tail": [["tail", "move"], ["tail_base", "thick"]],
	"back": [["back", "size"]],
	"head": [["horns", "size"]],
	"mouth": [["mouth", "size"]],
	"eyes": [["eyes", "size"]],
	"skin": [],
}
## С какой стороны смотреть на место: сбоку или вполоборота спереди.
const VIEW_YAW := {"body": PI / 2.0, "legs": PI / 2.0, "tail": PI / 2.0 + 0.5, "back": PI / 2.0,
	"mouth": 0.8, "eyes": 0.6, "head": 0.8, "arms": 0.9, "feet": 0.9, "claws": 0.7, "skin": 0.9}
## Заготовки тела: что меняют в форме.
const PRESETS := [
	["Ящерица", {"len": 1.8, "girth": [0.6, 0.75, 0.8, 0.75, 0.6], "leg_len": 0.6, "tail_len": 2.2, "tail_pitch": 0.05, "head": 0.9, "neck_z": 0.1, "neck_y": 0.0}],
	["Толстяк", {"len": 0.8, "girth": [1.3, 1.6, 1.7, 1.5, 1.1], "leg_len": 0.8, "leg_thick": 1.6, "head": 1.1, "neck_z": 0.0, "neck_y": 0.0}],
	["Жираф", {"len": 1.1, "girth": [0.8, 0.9, 0.95, 0.9, 0.7], "leg_len": 2.1, "leg_thick": 0.8, "neck_y": 1.2, "neck_z": 0.5, "head": 0.8}],
	["Змей", {"len": 2.4, "girth": [0.45, 0.55, 0.6, 0.55, 0.5], "leg_len": 0.5, "leg_thick": 0.6, "tail_len": 3.0, "tail_pitch": 0.0, "head": 0.8, "neck_z": 0.0, "neck_y": 0.0}],
	["Горилла", {"len": 1.0, "girth": [0.9, 1.1, 1.35, 1.6, 1.3], "leg_len": 1.1, "leg_thick": 1.6, "arm_len": 1.8, "arm_thick": 1.8, "head": 1.1, "tail_len": 0.3, "neck_z": 0.0, "neck_y": 0.2}],
	["Крошка", {"len": 0.7, "girth": [0.7, 0.8, 0.8, 0.8, 0.7], "head": 1.6, "leg_len": 0.7, "tail_len": 0.6, "neck_z": 0.0, "neck_y": 0.0}],
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
	var c := Color(Content.COLORS[evo.color])
	return [c, Color(Content.COLORS[evo.color2]) if evo.pattern != "none" else c.darkened(0.25)]

func _rebuild_creature(bounce := true) -> void:
	var cc := _colors()
	_creature.build_body(cc[0], cc[1], 1.0, evo.land_body, evo.pattern, evo.land_shape)
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
			if _grab != "":
				_walk_t = 0.0
				changed.emit(true, false)
		elif not e.pressed and e.index == _drag:
			_drag = -1
			if _grab != "":
				_grab = ""
				_dirty = true
				_refresh.call_deferred()
	elif e is InputEventScreenDrag and e.index == _drag:
		_idle = 0.0
		if _grab != "":
			_sculpt(_grab, e.relative)
		else:
			_yaw -= e.relative.x * 0.01
			_yaw_to = 1000.0

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
		if h[1] == "size" and slot != "body" and slot != "feet" and not evo.land_body.has(slot):
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
		"legs":
			sh.leg_len = float(sh.leg_len) + d.y / (0.85 * _creature.leg_base())
		"leg_thick":
			sh.leg_thick = float(sh.leg_thick) + grow
		"arm_thick":
			sh.arm_thick = float(sh.arm_thick) + grow
		"tail_base":
			sh.tail_thick = float(sh.tail_thick) + grow
		"arms":
			var v: Vector3 = (_creature.anchors.arms as Vector3) + d - _creature.arm_shoulder()
			sh.arm_len = v.length() / 0.74
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
		evo.land_shape = _start_shape.duplicate(true)
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
	for s in [["body", "Тело", ""]] + LandParts.SLOTS:
		var id: String = s[0]
		var t := SlotTab.new()
		t.part = evo.land_body.get(id, LandIcons.SLOT_ICON.get(id, "body"))
		t.empty = id != "body" and not evo.land_body.has(id)
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
	if slot == "body":
		_body_list()
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
		"legs":
			return is_equal_approx(sh.leg_len, d.leg_len) and is_equal_approx(sh.leg_thick, d.leg_thick)
		"arms":
			return is_equal_approx(sh.arm_len, d.arm_len) and is_equal_approx(sh.arm_thick, d.arm_thick) and is_equal_approx(sh.arm_pitch, d.arm_pitch)
		"tail":
			return is_equal_approx(sh.tail_len, d.tail_len) and is_equal_approx(sh.tail_thick, d.tail_thick) and is_equal_approx(sh.tail_pitch, d.tail_pitch)
	return not sh.sizes.has(key)

func _reset_shape(s: String, key: String) -> void:
	var d := LandParts.default_shape()
	var keys: Array = {"legs": ["leg_len", "leg_thick"], "arms": ["arm_len", "arm_thick", "arm_pitch"], "tail": ["tail_len", "tail_thick", "tail_pitch"]}.get(s, [])
	for k in keys:
		evo.land_shape[k] = d[k]
	evo.land_shape.sizes.erase(key)

func _slot_hint(s: String) -> String:
	match s:
		"body":
			return "Тело целиком: длина, толщина, шея и голова. От формы зависят здоровье и скорость: толще — крепче, но медленнее."
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
			return "ноги " + n.call(sh.leg_len)
		"leg_thick":
			return "толщина ног " + n.call(sh.leg_thick)
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
