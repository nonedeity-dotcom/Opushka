## Существо суши на экране: тело из шаров, голова с глазами и пастью, хвост, ноги из двух
## звеньев. Ноги ставятся сами: ступня стоит на земле, пока тело не ушло от неё дальше
## шага, — тогда она перешагивает вперёд дугой. Ноги ходят парами накрест.
class_name Creature3D
extends Node3D

var size := 1.0
var color := Color("#8fd07a")
var color2 := Color("#5f9a52")
var leg_count := 4
var eye_count := 2
## Земля: высота в точке (x, z).
var ground: Callable

var _body: Node3D
var _legs: Array = []  # {hip, foot, from, to, t, group, a, b, upper, lower}
var _phase := 0.0
var _mat: StandardMaterial3D
var _mat2: StandardMaterial3D
var _leg_len := 1.0
var _stepping_group := -1
## Бросок вперёд при укусе: 1 — только что кусил, тает к 0.
var _lunge := 0.0
var _flash := 0.0
var _bar: Node3D
var _bar_fill: MeshInstance3D
var _arms: Array = []  # {side, shoulder, upper, lower, hand, claw}
var _tail: Node3D
var _parts := {}
var _shape := {}
var _sp: Array = []
var _leg_base := 1.0
var _body_y := 1.0
## Наклон туловища (передние ноги длиннее задних — нос кверху).
var _pitch := 0.0
var _top := 1.5
var _head_at := Vector3.ZERO
var _tail_dir := Vector3.BACK
var _tail_len := 0.8
var _tail_r := 0.2
var _tail_tip := Vector3.ZERO
## Точки для лепки в редакторе — в осях существа (стоит в нуле, смотрит вперёд).
var anchors := {}
## Из чего собрана каждая часть: ключ (torso, head, mouth, leg0…) → её меши.
var groups := {}
var _grp := ""
var _hl := ""
var _hl_mat: StandardMaterial3D
var _head_node: Node3D

static func mat(c: Color, rough := 0.75) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

func _sphere(r: float, m: Material, at: Vector3, parent: Node3D, squash := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	mi.scale = squash
	parent.add_child(mi)
	_tag(mi)
	return mi

func _cone(r: float, h: float, m: Material, at: Vector3, dir: Vector3, parent: Node3D) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = r
	mesh.height = h
	mesh.radial_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	parent.add_child(mi)
	mi.position = at + dir.normalized() * h * 0.5
	mi.basis = _basis_y(dir)
	_tag(mi)
	return mi

## Базис, у которого ось Y смотрит вдоль dir (цилиндры и капсулы вытянуты по Y).
static func _basis_y(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := Vector3.UP.cross(y)
	if x.length() < 0.01:
		x = Vector3.RIGHT.cross(y)
	x = x.normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)

## Собрать простое существо (соседи на суше): ноги 2 или 4, челюсти, глаза; spikes —
## шипы по спине и рога (отшельники).
func build(c: Color, c2: Color, s: float, legs: int, spikes := false) -> void:
	var parts := {"torso": "torso", "legs": "legs2" if legs == 2 else "legs4", "mouth": "jaws", "eyes": "eyes"}
	if spikes:
		parts.back = "back_spikes"
		parts.head = "horns"
	build_body(c, c2, s, parts, "spots")

## Собрать тело из частей суши (LandParts): место → часть. pattern — узор, shape —
## вылепленная форма (LandParts.fix_shape). Вперёд — ось +Z. Без туловища — пусто.
##
## Заодно запоминаются «ручки» (anchors) — точки для лепки, и из чего собрана каждая
## часть (groups) — чтобы в редакторе часть можно было найти касанием и подсветить.
func build_body(c: Color, c2: Color, s: float, parts: Dictionary, pattern := "spots", shape := {}) -> void:
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()
	_legs.clear()
	_arms.clear()
	_bar = null
	_tail = null
	_head_node = null
	anchors.clear()
	groups.clear()
	_grp = ""
	color = c
	color2 = c2
	size = s
	_parts = parts
	_shape = LandParts.fix_shape(shape)
	var sh := _shape
	_body = Node3D.new()
	add_child(_body)
	_sp = []
	_pitch = 0.0
	_body_y = 0.5 * size
	_top = 0.8 * size
	_mat = mat(color)
	_mat2 = mat(color2)
	if not parts.has("torso"):
		leg_count = 0
		return
	var legs_id: String = parts.get("legs", "")
	leg_count = LandParts.leg_count(parts, sh)
	eye_count = LandParts.eye_count(parts, sh)
	if parts.get("skin", "") == "scales":
		_mat.roughness = 0.35
		_mat.metallic_specular = 0.8
	_leg_base = size * (1.35 if legs_id == "legs_long" else (0.62 if legs_id == "stubs" else 0.95))
	_sp = LandParts.spine(sh, size)
	var sp := _sp
	# Туловище — шары вдоль позвоночника, каждый своей толщины, внахлёст.
	_grp = "torso"
	var gap: float = (sp[1].z - sp[0].z)
	var rmax := 0.0
	for i in sp.size():
		var r: float = sp[i].r
		rmax = maxf(rmax, sp[i].ry)
		var m := _mat2 if pattern == "gradient" and i < 2 else _mat
		_sphere(r, m, Vector3(0, sp[i].y, sp[i].z), _body, Vector3(float(sh.width), 0.92 * float(sh.height), maxf(1.0, gap * 0.85 / r)))
	_pattern(pattern)
	_skin(parts.get("skin", ""))
	var front: Dictionary = sp[sp.size() - 1]
	# Ноги: сперва где бёдра и какой длины ноги — от этого наклон и высота туловища.
	# Пары вдоль туловища, ходят накрест; у каждой свои длина, ширина, высота.
	var tilt := float(sh.torso_pitch)
	var hips: Array = []
	var ls := float(sh.leg_size)
	if leg_count > 0:
		# Где каждая нога — своё место на теле (передвинули) или по умолчанию: пары вдоль
		# туловища; двуногий, поднявший туловище, стоит на его нижнем конце — как человек.
		var len_b := _leg_base * float(sh.leg_len) * ls
		var len_f := _leg_base * float(sh.leg_len_f) * ls if leg_count > 2 else len_b
		var rows := int(ceil(leg_count / 2.0))
		for i in leg_count:
			var key := "leg%d" % i
			var side := LandParts.leg_side(i, leg_count)
			var pl := LandParts.place(sh, key, leg_count)
			var pair := i / 2
			# Доля «передности» по ряду: 1 — передние, 0 — задние.
			var fk := 0.0 if rows <= 1 else 1.0 - float(pair) / (rows - 1)
			var th := lerpf(float(sh.leg_thick), float(sh.leg_thick_f) if leg_count > 2 else float(sh.leg_thick), fk) * ls
			var d := LandParts.dim(sh, key)
			hips.append({"hip": _surf(float(pl[0]), float(pl[1]), side), "group": (pair + (1 if side > 0 else 0)) % 2,
				"len": lerpf(len_b, len_f, fk) * float(d[0]) * float(d[3]), "th": th * float(d[3]), "xs": float(d[1]), "zs": float(d[2]), "key": key})
	# Наклон туловища: сколько подняли (прямоходящее — почти стоймя) плюс разница передних и
	# задних ног. Нос вверх — поворот «назад».
	var leg_pitch := 0.0
	var fi := 0
	var ri := 0
	for i in hips.size():
		if hips[i].hip.z > hips[fi].hip.z:
			fi = i
		if hips[i].hip.z < hips[ri].hip.z:
			ri = i
	if leg_count > 2:
		# Самая передняя и самая задняя нога: разница длины — наклон.
		var dz: float = hips[fi].hip.z - hips[ri].hip.z
		if absf(dz) > 0.05:
			leg_pitch = asin(clampf(-0.85 * (float(hips[fi].len) - float(hips[ri].len)) / dz, -0.65, 0.65))
	_pitch = clampf(-tilt + leg_pitch, -1.55, 0.7)
	var B := Basis(Vector3.RIGHT, _pitch)
	var U := B.inverse()
	var cs := cos(_pitch)
	var sn := sin(_pitch)
	# Высота: опорные (задние) ноги стоят на земле; туловище и голова — не в земле.
	var need := 0.0
	for p in sp:
		need = maxf(need, p.z * sn - p.y * cs + 0.8 * (p.ry * absf(cs) + p.r * absf(sn)))
	_body_y = need + 0.08 * size if leg_count == 0 else maxf(need + 0.08 * size, 0.0)
	if leg_count > 0:
		# Стоит на самой задней ноге (у двуногого — на обеих).
		var hb: Vector3 = hips[ri].hip
		var lb: float = hips[ri].len
		_body_y = maxf(0.85 * lb - (hb.y * cs - hb.z * sn), need + 0.08 * size)
	elif need <= 0.0:
		_body_y = rmax * 0.85
	# Голова — впереди, на шее. Шея и голова — «по-земному»: как бы ни стояло туловище,
	# морда смотрит вперёд, «вверх» у шеи — к небу. У головы свои длина, ширина, высота;
	# всё, что на ней, растягивается вместе с ней.
	var hd := LandParts.dim(sh, "head")
	var hsc := Vector3(float(hd[1]), float(hd[2]), float(hd[0])) * float(hd[3]) * float(sh.head)
	var hr := 0.39 * size
	var reach_z := hr * hsc.z
	var neck_base := Vector3(0, 0.1 * size + front.y, front.z + front.r * 0.55)
	var head := neck_base + U * Vector3(0, 0.12 * size + float(sh.neck_y) * size, reach_z * 0.8 + float(sh.neck_z) * size)
	_head_at = B * head
	_grp = "head"
	var n := neck_base.distance_to(head)
	var hmin := hr * minf(hsc.x, hsc.y)
	if n > reach_z * 0.9:
		var nr := minf(front.r, hmin) * 0.55
		var steps := int(ceil(n / (nr * 1.2)))
		for k in range(1, steps):
			_sphere(nr, _mat, neck_base.lerp(head, float(k) / steps), _body)
	_head_node = Node3D.new()
	_head_node.transform = Transform3D(U * Basis.from_scale(hsc), head)
	_body.add_child(_head_node)
	_sphere(hr, _mat, Vector3.ZERO, _head_node)
	_grp = "mouth"
	var mp := _pivot(_head_node, "mouth", "mouth")
	mp.rotation.x = float(sh.rot.get("mouth", 0.0))
	_mouth(parts.get("mouth", ""), mp)
	_grp = "eyes"
	_eyes(parts.get("eyes", ""), _pivot(_head_node, "eyes", "eyes"))
	_grp = "horns"
	var hp := _pivot(_head_node, "horns", "head")
	hp.rotation.x = -float(sh.rot.get("horns", 0.0))
	_head_part(parts.get("head", ""), hp)
	_grp = "tail"
	_tail_part(parts.get("tail", ""))
	_grp = "back"
	_back(parts.get("back", ""))
	_make_arms(parts.get("arms", ""))
	var hooves := 1.25 if parts.get("feet", "") == "hooves" else 1.0
	for h in hips:
		_grp = h.key
		var L: float = h.len
		var leg := {"hip": h.hip, "group": h.group, "t": -1.0, "foot": Vector3.ZERO, "from": Vector3.ZERO, "to": Vector3.ZERO,
			"a": L * 0.55, "b": L * 0.55, "len": L, "xs": h.xs, "zs": h.zs, "key": h.key}
		leg.upper = _limb(0.1 * size * h.th * hooves, leg.a)
		leg.lower = _limb(0.085 * size * h.th * hooves, leg.b)
		leg.paw = _foot(parts.get("feet", ""), parts.get("claws", ""), LandParts.part_size(sh, "feet") * sqrt(h.th * sqrt(h.xs * h.zs)), LandParts.part_size(sh, "claws") * sqrt(ls))
		_legs.append(leg)
	_grp = ""
	_leg_len = 0.6 * size
	for leg in _legs:
		_leg_len = maxf(_leg_len, float(leg.len))
	# Ручки для лепки — с учётом высоты и наклона туловища.
	for i in sp.size():
		anchors["g%d" % i] = _b(Vector3(0, sp[i].ry * 0.92 + sp[i].y, sp[i].z))
	anchors.len_back = _b(Vector3(0, 0, sp[0].z - sp[0].r))
	anchors.len_front = _b(Vector3(0, -front.ry * 0.4, front.z + front.r * 0.3))
	anchors.width = _b(Vector3(LandParts.spine_at(sp, 0.5).rx * 0.95, 0, LandParts.spine_at(sp, 0.5).z))
	anchors.head = _b(head)
	anchors.head_size = _b(head + U * Vector3(0, hr * hsc.y + 0.12 * size, 0))
	anchors.tilt = _b(Vector3(0, front.ry * 0.7, front.z + front.r * 0.5))
	anchors.mouth = _b(head + _head_node.basis * Vector3(0, -0.15, hr + 0.25 * size))
	anchors.eyes = _b(head + _head_node.basis * Vector3(0.25, 0.25, 0.3) * size)
	anchors.horns = _b(head + _head_node.basis * Vector3(0.3, 0.45, -0.1) * size)
	# У каждой ноги: место (у бедра), длина (у колена), толщина, ступня.
	for h in hips:
		var hw := _b(h.hip as Vector3)
		var k: String = h.key
		var gy := maxf(hw.y - float(h.len) * 0.85, 0.0)
		anchors["place:" + k] = hw
		anchors["len:" + k] = Vector3(hw.x * 1.1, lerpf(hw.y, gy, 0.5), hw.z)
		anchors["thick:" + k] = Vector3(hw.x * 1.1 + signf(hw.x) * 0.2, lerpf(hw.y, gy, 0.72), hw.z)
		anchors["feet:" + k] = Vector3(hw.x * 1.2, gy + 0.05, hw.z + 0.15 * size)
	var mid := LandParts.spine_at(sp, 0.5)
	anchors.back = _b(Vector3(0, mid.ry + mid.y + 0.45 * size * LandParts.part_size(sh, "back"), mid.z))
	anchors.skin = _b(Vector3(mid.rx * 0.9, mid.ry * 0.5 + mid.y, mid.z))
	if _tail:
		anchors.tail_base = _b(_tail.position + Vector3(0, _tail_r * 1.4, 0))
		anchors.tail = _b(_tail.position + _tail_tip)
	# У каждой руки: место (у плеча), кисть (длина и наклон), толщина (у локтя).
	for arm in _arms:
		var k: String = arm.key
		anchors["place:" + k] = _b(arm.shoulder as Vector3)
		anchors["hand:" + k] = _b((arm.shoulder as Vector3) + (arm.dir as Vector3) * float(arm.reach))
		anchors["thick:" + k] = _b((arm.shoulder as Vector3) + (arm.dir as Vector3) * float(arm.reach) * 0.45 + Vector3(0.15 * arm.side, 0, 0))
	# Тень-пятно под телом: дёшево, а существо «стоит» на земле.
	var shadow := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	var sr := maxf((sp[sp.size() - 1].z - sp[0].z) * 0.6 + rmax * 0.5, rmax * 1.3)
	disc.top_radius = sr
	disc.bottom_radius = sr
	disc.height = 0.02
	disc.radial_segments = 16
	shadow.mesh = disc
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0, 0, 0, 0.28)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = sm
	shadow.name = "Shadow"
	add_child(shadow)
	_top = _body_y + (B * head).y + hr * hsc.y
	for p in sp:
		_top = maxf(_top, _body_y + (B * Vector3(0, p.ry + p.y, p.z)).y)
	_place_feet()

## Точка на поверхности туловища: t — вдоль (0 хвост … 1 голова), a — по кругу (0 — сбоку
## посередине, + выше, − ниже), side — левый бок (−1) или правый (+1).
func _surf(t: float, a: float, side: float) -> Vector3:
	var at := LandParts.spine_at(_sp, t)
	return Vector3(side * at.rx * cos(a) * 0.92, at.ry * sin(a) * 0.92 + at.y, at.z)

## Точка туловища (в его осях) → в осях существа: с высотой и наклоном.
func _b(v: Vector3) -> Vector3:
	return Vector3(0, _body_y, 0) + Basis(Vector3.RIGHT, _pitch) * v

## Для лепки: плечо правой руки, основание хвоста и длина «обычного» хвоста, высота ног,
## и насколько существо велико (чтобы камера его целиком видела).
func arm_shoulder(key := "arm1") -> Vector3:
	for arm in _arms:
		if arm.key == key:
			return _b(arm.shoulder as Vector3)
	return Vector3.ZERO

func tail_base() -> Vector3:
	return _b(_tail.position if _tail else Vector3.ZERO)

func tail_unit() -> float:
	return _tail_len / maxf(float(_shape.get("tail_len", 1.0)), 0.01)

func leg_base() -> float:
	return _leg_base

func extent() -> float:
	if _sp.is_empty():
		return 1.2
	var L: float = _sp[_sp.size() - 1].z - _sp[0].z
	return maxf(_top, L + _tail_len * 0.6 + absf(_head_at.z) * 0.5)

## Подсветить часть (редактор: её выбрали касанием). "" — снять подсветку.
func highlight(key: String) -> void:
	_hl = key
	if _hl_mat == null:
		_hl_mat = StandardMaterial3D.new()
		_hl_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_hl_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_hl_mat.albedo_color = Color(1.0, 0.95, 0.55, 0.35)
	for k in groups:
		for mi in groups[k]:
			if is_instance_valid(mi):
				(mi as GeometryInstance3D).material_overlay = _hl_mat if k == key else null

## Узел для части на голове: растёт с размером места и со своими длиной, шириной,
## высотой (dims).
func _pivot(parent: Node3D, dim_key: String, slot: String) -> Node3D:
	var d := LandParts.dim(_shape, dim_key)
	var n := Node3D.new()
	n.scale = Vector3(float(d[1]), float(d[2]), float(d[0])) * float(d[3]) * LandParts.part_size(_shape, slot)
	parent.add_child(n)
	return n

func _tag(mi: Node3D) -> void:
	if _grp == "":
		return
	if not groups.has(_grp):
		groups[_grp] = []
	groups[_grp].append(mi)

## Узор: по настоящей толщине туловища. Пятна, полосы поперёк спины, кольца вокруг,
## переход (зад другого цвета), светлое брюшко, леопард (пятна с «дыркой»), тигр (частые
## узкие полосы), крапинки, полоса по спине.
func _pattern(pattern: String) -> void:
	match pattern:
		"none", "gradient":
			pass
		"stripes", "tiger":
			var n := 9 if pattern == "tiger" else 5
			var thin := 0.035 if pattern == "tiger" else 0.065
			for i in n:
				var at := LandParts.spine_at(_sp, 0.92 - i * 0.84 / (n - 1))
				_sphere(at.r, _mat2, Vector3(0, at.ry * 0.35, at.z) + Vector3(0, at.y, 0), _body, Vector3(0.9 * at.rx / at.r, 0.66 * at.ry / at.r, thin * size / at.r))
		"rings":
			for t in [0.25, 0.5, 0.75]:
				var at := LandParts.spine_at(_sp, t)
				_sphere(at.r, _mat2, Vector3(0, 0, at.z) + Vector3(0, at.y, 0), _body, Vector3(1.03 * at.rx / at.r, 0.95 * at.ry / at.r, 0.07 * size / at.r))
		"belly":
			for i in _sp.size():
				var at: Dictionary = _sp[i]
				_sphere(at.r * 0.96, _mat2, Vector3(0, -at.ry * 0.3, at.z) + Vector3(0, at.y, 0), _body, Vector3(at.rx / at.r, 0.7 * at.ry / at.r, 1.0))
		"back":
			for i in 7:
				var at := LandParts.spine_at(_sp, 0.95 - i * 0.15)
				_sphere(0.1 * size, _mat2, Vector3(0, at.ry * 0.9, at.z) + Vector3(0, at.y, 0), _body, Vector3(1.0, 0.5, 2.2))
		"dots":
			for i in 16:
				var at := LandParts.spine_at(_sp, fmod(i * 0.37, 1.0) * 0.9 + 0.05)
				var a := -1.6 + fmod(i * 1.13, 3.2)
				_sphere(0.045 * size, _mat2, Vector3(sin(a) * at.rx * 0.97, cos(a) * at.ry * 0.9, at.z) + Vector3(0, at.y, 0), _body)
		"leopard":
			var hole := mat(color.lightened(0.1))
			for i in 10:
				var at := LandParts.spine_at(_sp, fmod(i * 0.41, 1.0) * 0.85 + 0.08)
				var a := -1.4 + fmod(i * 1.37, 2.8)
				var q := Vector3(sin(a) * at.rx * 0.93, cos(a) * at.ry * 0.87 + at.y, at.z)
				_sphere(0.1 * size, _mat2, q, _body, Vector3(1, 0.45, 1))
				_sphere(0.055 * size, hole, q * 1.03, _body, Vector3(1, 0.45, 1))
		_:
			for q in [[0.85, 0.35], [0.6, -0.4], [0.35, 0.2], [0.12, -0.1]]:
				var at := LandParts.spine_at(_sp, q[0])
				var a: float = q[1]
				_sphere(at.r * 0.3, _mat2, Vector3(sin(a) * at.rx * 0.9, cos(a) * at.ry * 0.85, at.z) + Vector3(0, at.y, 0), _body, Vector3(1, 0.5, 1))

func _tail_part(id: String) -> void:
	var sh := _shape
	var rear: Dictionary = _sp[0]
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.05 * size + float(rear.get("y", 0.0)), rear.z - rear.r * 0.7)
	_body.add_child(_tail)
	var p := float(sh.tail_pitch)
	# Наклон хвоста — от земли, а не от туловища: у прямоходящего хвост не в землю.
	var U := Basis(Vector3.RIGHT, _pitch).inverse()
	_tail_dir = U * Vector3(0, sin(p), -cos(p))
	var td := LandParts.dim(sh, "tail")
	_tail_r = rear.r * 0.5 * float(sh.tail_thick) * float(sh.tail_size) * float(td[3])
	var base := {"tail_long": 1.5, "tail_club": 0.9}.get(id, 0.8) as float
	_tail_len = base * size * float(sh.tail_len) * float(sh.tail_size) * float(td[0]) * float(td[3])
	# Хвост — из звеньев, всё тоньше к кончику; изгиб закручивает его вверх (+) или вниз.
	var curl := float(sh.get("tail_curl", 0.0))
	var n := 6
	var at := Vector3.ZERO
	var ang := p
	var r := _tail_r
	for i in n:
		var d := U * Vector3(0, sin(ang), -cos(ang))
		var seg := _tail_len / n
		var nr := _tail_r * (1.0 - float(i + 1) / n) + 0.01 * size
		var mi := _rod(at, at + d * seg * 1.08, (r + nr) / 2.0, _mat, _tail)
		mi.basis = mi.basis * Basis.from_scale(Vector3(float(td[1]), 1.0, float(td[2])))
		(mi.mesh as CylinderMesh).top_radius = nr
		(mi.mesh as CylinderMesh).bottom_radius = r
		at += d * seg
		r = nr
		ang += curl / n
	_tail_tip = at
	_tail_dir = (at / maxf(at.length(), 0.001))
	if id == "tail_club":
		var k := LandParts.part_size(sh, "tail") * float(sh.tail_thick) * float(sh.tail_size) * float(td[3])
		_sphere(0.24 * size * k, _mat2, at, _tail)
		var bone := mat(Color("#e8dcc0"), 0.5)
		for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), _tail_dir]:
			_cone(0.07 * size * k, 0.2 * size * k, bone, at + d * 0.18 * size * k, d, _tail)

func _mouth(id: String, pv: Node3D) -> void:
	var tooth := mat(Color("#efe6cf"), 0.4)
	var o := Vector3(0, 0, 0.39 * size) * 0.8
	match id:
		"beak":
			var horn := mat(Color("#f0b040"), 0.5)
			_cone(0.2 * size, 0.45 * size, horn, o + Vector3(0, 0.0, 0.0) * size, Vector3(0, -0.15, 1), pv)
			_cone(0.14 * size, 0.3 * size, horn, o + Vector3(0, -0.12, -0.02) * size, Vector3(0, -0.4, 1), pv)
		"fangs":
			for side in [-1.0, 1.0]:
				_cone(0.1 * size, 0.42 * size, tooth, o + Vector3(side * 0.14, -0.2, 0.0) * size, Vector3(0, -1, 0.3), pv)
				_cone(0.06 * size, 0.22 * size, tooth, o + Vector3(side * 0.26, -0.18, -0.1) * size, Vector3(0, -1, 0.2), pv)
			_sphere(0.22 * size, _mat, o + Vector3(0, -0.2, -0.12) * size, pv, Vector3(1.2, 0.6, 1.1))
		"snout":
			var tip := o + Vector3(0, -0.05, 0.0) * size
			var mid := tip + Vector3(0, -0.12, 0.35) * size
			var end := mid + Vector3(0, -0.35, 0.12) * size
			_rod(tip, mid, 0.13 * size, _mat, pv)
			_rod(mid, end, 0.1 * size, _mat, pv)
			_sphere(0.12 * size, _mat2, end, pv)
		"jaws":
			for side in [-1.0, 1.0]:
				_cone(0.07 * size, 0.28 * size, tooth, o + Vector3(side * 0.12, -0.2, 0.0) * size, Vector3(0, -1, 0.35), pv)
		_:
			# Рта нет — только тёмная щёлка.
			_sphere(0.08 * size, mat(Color("#2a1e22"), 1.0), o + Vector3(0, -0.12, 0.04) * size, pv, Vector3(2.2, 0.4, 0.6))

## Глаза — каждый на своём месте головы: вокруг (0 — прямо вперёд), выше/ниже, размер.
func _eyes(id: String, pv: Node3D) -> void:
	if id == "":
		return
	var white := mat(Color("#f4f4ec"), 0.3)
	var black := mat(Color("#1e1e28"), 0.2)
	var hr := 0.39 * size
	var k := 1.45 if id == "eyes_big" else 1.0
	for e in eye_count:
		_grp = "eye%d" % e
		var pl := LandParts.place(_shape, _grp, leg_count, eye_count)
		var yaw := float(pl[0])
		var pitch := float(pl[1])
		var ek := float(pl[2])
		var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
		if id == "eyes_stalk":
			var base := dir * hr * 0.85
			var top := base + (dir * 0.45 + Vector3.UP).normalized() * 0.42 * size * ek
			_rod(base, top, 0.04 * size * ek, _mat, pv)
			_sphere(0.12 * size * ek, white, top, pv)
			_sphere(0.065 * size * ek, black, top + Vector3(dir.x, 0, dir.z).normalized() * 0.1 * size * ek, pv)
		else:
			var eye := dir * hr * 0.9
			_sphere(0.14 * size * k * ek, white, eye, pv)
			_sphere(0.075 * size * k * ek, black, eye + dir * 0.1 * size * k * ek, pv)
	_grp = "eyes"

func _head_part(id: String, pv: Node3D) -> void:
	match id:
		"horns":
			var horn := mat(Color("#e8dcc0"), 0.5)
			for side in [-1.0, 1.0]:
				_cone(0.08 * size, 0.42 * size, horn, Vector3(side * 0.25, 0.25, -0.05) * size, Vector3(side * 0.5, 1, -0.6), pv)
		"crest":
			_sphere(0.35 * size, _mat2, Vector3(0, 0.38, -0.15) * size, pv, Vector3(0.12, 0.9, 1.2))

## Спина: вдоль позвоночника, по верху туловища; размер части растит каждый шип и пластину.
func _back(id: String) -> void:
	var bd := LandParts.dim(_shape, "back")
	var k := LandParts.part_size(_shape, "back") * float(bd[3])
	var from: int = (groups.get("back", []) as Array).size()
	match id:
		"back_spikes":
			var horn := mat(Color("#e8dcc0"), 0.5)
			for i in 5:
				var at := LandParts.spine_at(_sp, 0.88 - i * 0.18)
				_cone(0.1 * size * k, (0.42 - absf(i - 1.5) * 0.06) * size * k, horn, Vector3(0, at.ry * 0.78 + at.y, at.z), Vector3(0, 1, -0.35), _body)
		"plates":
			var plate := mat(color2.darkened(0.2), 0.6)
			for i in 5:
				var at := LandParts.spine_at(_sp, 0.86 - i * 0.18)
				_sphere(0.24 * size * k, plate, Vector3(0.1 * (1 if i % 2 == 0 else -1) * size, at.ry * 0.95 + 0.04 * size * k, at.z) + Vector3(0, at.y, 0), _body, Vector3(0.25, 1.0, 0.9))
		"sail":
			var m := mat(color2.lightened(0.15), 0.5)
			var bone := mat(Color("#e8dcc0"), 0.5)
			var L: float = _sp[_sp.size() - 1].z - _sp[0].z
			var mid := LandParts.spine_at(_sp, 0.5)
			_sphere(0.6 * size, m, Vector3(0, mid.ry * 0.8 + mid.y + 0.25 * size * k, mid.z), _body, Vector3(0.08, 0.85 * k, maxf(L / (1.2 * size), 0.6)))
			for i in 5:
				var at := LandParts.spine_at(_sp, 0.85 - i * 0.175)
				var hgt := (0.85 - absf(i - 2) * 0.12) * k
				_rod(Vector3(0, at.ry * 0.7 + at.y, at.z), Vector3(0, at.ry * 0.7 + at.y + hgt * size, at.z - 0.05 * size), 0.03 * size, bone)
	# Длина — вдоль спины, ширина — вбок, высота — вверх: каждой шипине и пластине;
	# поворот наклоняет их вперёд или назад.
	var els: Array = groups.get("back", [])
	var tilt := Basis(Vector3.RIGHT, float(_shape.rot.get("back", 0.0)))
	for i in range(from, els.size()):
		var mi: Node3D = els[i]
		mi.basis = tilt * mi.basis * Basis.from_scale(Vector3(float(bd[1]), float(bd[2]), float(bd[0])))

func _skin(id: String) -> void:
	match id:
		"fur":
			var tuft := mat(color.darkened(0.15), 1.0)
			for i in 12:
				var a := -1.0 + (i % 3) * 1.0
				var at := LandParts.spine_at(_sp, 0.9 - int(i / 3) * 0.25)
				_cone(0.08 * size, 0.16 * size, tuft, Vector3(sin(a) * at.rx * 0.92, cos(a) * at.ry * 0.85 + at.y, at.z), Vector3(sin(a), cos(a), -0.4), _body)
		"scales":
			var sc := mat(color2.darkened(0.1), 0.3)
			for side in [-1.0, 1.0]:
				for i in 5:
					var at := LandParts.spine_at(_sp, 0.9 - i * 0.2)
					_sphere(0.12 * size, sc, Vector3(side * at.rx * 0.95, (0.1 + (i % 2) * 0.2) * at.ry, at.z) + Vector3(0, at.y, 0), _body, Vector3(0.4, 1, 1))
		"poison_skin":
			var dot := mat(Color("#c8f040"), 0.4)
			dot.emission_enabled = true
			dot.emission = Color("#a0e020")
			dot.emission_energy_multiplier = 0.5
			for q in [[0.85, 0.7], [0.65, -0.8], [0.45, 0.3], [0.25, -0.4], [0.1, 0.9], [0.55, 0.0]]:
				var at := LandParts.spine_at(_sp, q[0])
				var a: float = q[1]
				_sphere(0.08 * size, dot, Vector3(sin(a) * at.rx * 0.95, cos(a) * at.ry * 0.88, at.z) + Vector3(0, at.y, 0), _body)

## Руки: плечо → локоть → кисть. Длина, толщина и наклон — из формы; качаются на ходу.
func _make_arms(id: String) -> void:
	if id == "":
		return
	var sh := _shape
	var asz := float(sh.arm_size)
	for i in LandParts.arm_pairs(sh) * 2:
		var side := -1.0 if i % 2 == 0 else 1.0
		# У каждой руки своё место, длина, ширина, высота, размер и наклон.
		var key := "arm%d" % i
		_grp = key
		var d := LandParts.dim(sh, key)
		var pl := LandParts.place(sh, key, leg_count)
		var ln := float(sh.arm_len) * asz * float(d[0]) * float(d[3])
		var th := float(sh.arm_thick) * asz * float(d[3])
		# Руки висят вниз по-земному, как бы ни стояло туловище.
		var dir := Basis(Vector3.RIGHT, _pitch).inverse() * Vector3(side * 0.1, -0.75, 0.6).normalized().rotated(Vector3.RIGHT, -float(sh.arm_pitch) - float(pl[2]))
		var arm := {"side": side, "shoulder": _surf(float(pl[0]), float(pl[1]), side), "dir": dir, "reach": 0.74 * size * ln,
			"claw": id == "arms_claw", "xs": float(d[1]), "zs": float(d[2]), "key": key}
		var seg := 0.43 * size * ln
		arm.seg = seg
		arm.upper = _limb(0.08 * size * th, seg)
		arm.lower = _limb(0.07 * size * th, seg)
		var hand := Node3D.new()
		hand.scale = Vector3.ONE * sqrt(th * sqrt(float(d[1]) * float(d[2]))) * LandParts.part_size(sh, "arms")
		add_child(hand)
		if id == "arms_claw":
			var pin := mat(color2.darkened(0.15), 0.5)
			_cone(0.1 * size, 0.3 * size, pin, Vector3(0.04 * side, 0.04, 0) * size, Vector3(0.2 * side, 0.3, 1), hand)
			_cone(0.08 * size, 0.25 * size, pin, Vector3(0.04 * side, -0.04, 0) * size, Vector3(0.1 * side, -0.3, 1), hand)
			_sphere(0.12 * size, pin, Vector3.ZERO, hand)
		else:
			_sphere(0.1 * size, _mat2, Vector3.ZERO, hand)
			for f in 3:
				_cone(0.035 * size, 0.14 * size, _mat2, Vector3((f - 1) * 0.05, 0, 0.06) * size, Vector3((f - 1) * 0.3, -0.2, 1), hand)
		arm.hand = hand
		_arms.append(arm)

## Ступня: лапа, копыто или перепонка; когти — поверх. k — размер ступни, ck — когтей.
func _foot(id: String, claws: String, k := 1.0, ck := 1.0) -> Node3D:
	var paw := Node3D.new()
	add_child(paw)
	var pv := Node3D.new()
	pv.scale = Vector3.ONE * k
	paw.add_child(pv)
	match id:
		"hooves":
			var hoof := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.1 * size
			cm.bottom_radius = 0.14 * size
			cm.height = 0.14 * size
			cm.radial_segments = 8
			hoof.mesh = cm
			hoof.material_override = mat(Color("#3a2e28"), 0.5)
			pv.add_child(hoof)
		"webbed":
			_sphere(0.2 * size, mat(color2.lightened(0.1), 0.6), Vector3(0, -0.02, 0.08) * size, pv, Vector3(1.3, 0.18, 1.3))
		"paws":
			_sphere(0.16 * size, _mat2, Vector3.ZERO, pv, Vector3(1.2, 0.65, 1.3))
		_:
			_sphere(0.12 * size, _mat2, Vector3.ZERO, pv, Vector3(1.1, 0.6, 1.3))
	if claws != "":
		var kk := (1.6 if claws == "claws_big" else 1.0) * ck
		var nail := mat(Color("#f0e8d8"), 0.4)
		for f in 3:
			_cone(0.03 * size * kk, 0.13 * size * kk, nail, Vector3((f - 1) * 0.07 * k, 0.0, 0.12 * k) * size, Vector3((f - 1) * 0.3, -0.3, 1), paw)
	return paw

func _rod(from: Vector3, to: Vector3, r: float, m: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = from.distance_to(to)
	cm.radial_segments = 6
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.position = (from + to) / 2.0
	mi.basis = _basis_y(to - from)
	(parent if parent else _body).add_child(mi)
	_tag(mi)
	return mi

func _limb(r: float, h: float) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = r
	mesh.height = h + r * 2.0
	mesh.radial_segments = 8
	mesh.rings = 2
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat
	add_child(mi)
	_tag(mi)
	return mi

## Где ступне стоять, если идти не надо: под бедром, чуть в сторону.
func _rest(leg: Dictionary) -> Vector3:
	var hip := _b(leg.hip as Vector3)
	var local := Vector3(hip.x * 1.25, 0.0, hip.z)
	var w := global_transform * local
	return Vector3(w.x, _ground_at(w.x, w.z), w.z)

func _ground_at(x: float, z: float) -> float:
	return float(ground.call(x, z)) if ground.is_valid() else 0.0

func _place_feet() -> void:
	if not is_inside_tree():
		return
	for leg in _legs:
		leg.foot = _rest(leg)
		leg.t = -1.0

## Укусил — тело бросается вперёд.
func lunge() -> void:
	_lunge = 1.0

## Вспышка: 1 — только что ранен (белеет), 0 — обычный.
func flash(k: float) -> void:
	k = clampf(k, 0.0, 1.0)
	if absf(k - _flash) < 0.02 and (k == 0.0) == (_flash == 0.0):
		return
	_flash = k
	for m in [_mat, _mat2]:
		m.emission_enabled = k > 0.0
		m.emission = Color(1, 0.85, 0.8)
		m.emission_energy_multiplier = k * 0.9

## Полоска здоровья над головой; frac ≥ 1 — спрятать.
func health(frac: float) -> void:
	if frac >= 0.999:
		if _bar:
			_bar.visible = false
		return
	if _bar == null:
		_bar = Node3D.new()
		add_child(_bar)
		for i in 2:
			var q := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(1.2, 0.16) * maxf(size, 0.9)
			q.mesh = qm
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			m.billboard_keep_scale = true
			m.no_depth_test = true
			m.render_priority = i
			m.albedo_color = Color(0.1, 0.05, 0.05, 0.8) if i == 0 else Color("#e0484a")
			if i == 0:
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			q.material_override = m
			_bar.add_child(q)
			if i == 1:
				_bar_fill = q
		_bar.position.y = _top + 0.5 * size
	_bar.visible = true
	_bar_fill.scale.x = clampf(frac, 0.02, 1.0)

## Кадр: где стоит (на земле), куда смотрит, как быстро идёт.
func update(dt: float, at: Vector3, heading: float, vel: Vector3) -> void:
	var first := _legs.size() > 0 and (_legs[0].foot as Vector3) == Vector3.ZERO
	global_position = at
	rotation.y = heading
	var speed := Vector3(vel.x, 0, vel.z).length()
	_phase += dt * (2.0 + speed * 2.2)
	# Тело держится на высоте ног и чуть покачивается на ходу.
	var body_y := _body_y
	if _hl != "" and _hl_mat:
		_hl_mat.albedo_color.a = 0.28 + 0.14 * sin(Time.get_ticks_msec() / 160.0)
	_body.position = Vector3(0, body_y + 0.05 * size * sin(_phase * 2.0) * minf(speed / 3.0, 1.0), 0)
	_body.rotation.z = 0.04 * sin(_phase) * minf(speed / 3.0, 1.0)
	# Бросок: быстро вперёд и вниз, потом назад.
	_lunge = maxf(0.0, _lunge - dt * 4.0)
	var jab := sin(PI * (1.0 - _lunge)) if _lunge > 0.0 else 0.0
	_body.position.z = jab * 0.35 * size
	_body.rotation.x = _pitch + jab * 0.25
	# Первый кадр или долго не рисовали (был далеко) — ноги сразу под себя.
	if first or (_legs.size() > 0 and (_legs[0].foot as Vector3).distance_to(at) > _leg_len * 3.0):
		_place_feet()
	var stride := _leg_len * 0.7
	var busy := _stepping_group
	for leg in _legs:
		# Нога не достаёт до земли (туловище подняли) — висит, как рука, и не шагает.
		var hip_w: Vector3 = _body.global_transform * (leg.hip as Vector3)
		var reach: float = float(leg.a) + float(leg.b)
		if hip_w.y - _ground_at(hip_w.x, hip_w.z) > reach * 0.97:
			leg.t = -1.0
			leg.foot = hip_w + Vector3(0, -reach * 0.92, 0) + global_transform.basis.z * 0.12 * size
			continue
		var rest := _rest(leg)
		if leg.t >= 0.0:
			leg.t += dt / float(leg.get("dur", 0.2))
			var q: float = minf(leg.t, 1.0)
			var p: Vector3 = (leg.from as Vector3).lerp(leg.to, q)
			p.y += sin(PI * q) * _leg_len * 0.3
			leg.foot = p
			if leg.t >= 1.0:
				leg.t = -1.0
				leg.foot = leg.to
		elif (leg.foot as Vector3).distance_to(rest) > stride and (busy == -1 or busy == leg.group or (leg.foot as Vector3).distance_to(rest) > stride * 2.0):
			# Перешагнуть: цель — впереди, по ходу. Бежит — шаг быстрее и дальше, иначе
			# ноги не поспевают за телом.
			var dur := clampf(stride / maxf(speed, 0.1) * 0.6, 0.08, 0.2)
			leg.dur = dur
			leg.from = leg.foot
			var ahead := rest + Vector3(vel.x, 0, vel.z) * dur * 1.6
			leg.to = Vector3(ahead.x, _ground_at(ahead.x, ahead.z), ahead.z)
			leg.t = 0.0
			busy = leg.group
	_stepping_group = -1
	for leg in _legs:
		if leg.t >= 0.0:
			_stepping_group = leg.group
	for leg in _legs:
		_pose_leg(leg)
	# Руки качаются в такт шагам, при укусе — тянутся вперёд. Хвост виляет.
	var walk := minf(speed / 3.0, 1.0)
	for arm in _arms:
		var sh: Vector3 = _body.global_transform * (arm.shoulder as Vector3)
		var swing: float = sin(_phase + (0.0 if arm.side < 0 else PI)) * 0.18 * walk
		var reach: float = arm.reach
		var local: Vector3 = (arm.shoulder as Vector3) + (arm.dir as Vector3) * reach + Vector3(0, 0, swing + jab * 0.45) * size
		var hand: Vector3 = _body.global_transform * local
		# Локоть — вбок и чуть вниз, чтобы оба звена были своей длины.
		var seg: float = arm.seg
		var half := sh.distance_to(hand) / 2.0
		var out := sqrt(maxf(seg * seg - half * half, 0.0))
		var elbow: Vector3 = (sh + hand) / 2.0 + (global_transform.basis.x * arm.side * 0.8 + Vector3(0, -0.6, 0)).normalized() * out
		_seg(arm.upper, sh, elbow, arm.xs, arm.zs)
		_seg(arm.lower, elbow, hand, arm.xs, arm.zs)
		(arm.hand as Node3D).global_position = hand
		(arm.hand as Node3D).global_rotation = Vector3(0, global_rotation.y, float(_shape.rot.get("hands", 0.0)) * arm.side)
	if _tail:
		_tail.rotation.y = sin(_phase * 0.5) * (0.15 + 0.2 * walk)
	var sh := get_node_or_null("Shadow") as Node3D
	if sh:
		sh.global_position = Vector3(at.x, _ground_at(at.x, at.z) + 0.04, at.z)

## Нога по двум звеньям: бедро → колено → ступня. Колено — вбок и вверх.
func _pose_leg(leg: Dictionary) -> void:
	var hip: Vector3 = _body.global_transform * (leg.hip as Vector3)
	var foot: Vector3 = leg.foot
	var a: float = leg.a
	var b: float = leg.b
	var d := clampf(hip.distance_to(foot), 0.01, a + b - 0.001)
	var dir := (foot - hip).normalized()
	var side := global_transform.basis.x * signf((leg.hip as Vector3).x)
	var bend := (side * 0.6 + Vector3.UP).normalized()
	bend = (bend - dir * bend.dot(dir)).normalized()
	var x := (a * a - b * b + d * d) / (2.0 * d)
	var y := sqrt(maxf(a * a - x * x, 0.0))
	var knee := hip + dir * x + bend * y
	_seg(leg.upper, hip, knee, leg.xs, leg.zs)
	_seg(leg.lower, knee, foot, leg.xs, leg.zs)
	(leg.paw as Node3D).global_position = foot + Vector3(0, 0.04 * size, 0)
	var toe := float(_shape.rot.get("feet", 0.0)) * signf((leg.hip as Vector3).x)
	(leg.paw as Node3D).global_rotation = Vector3(0, global_rotation.y - toe, 0)

func _seg(mi: MeshInstance3D, p: Vector3, q: Vector3, xs := 1.0, zs := 1.0) -> void:
	mi.global_position = (p + q) / 2.0
	mi.global_basis = _basis_y(q - p) * Basis.from_scale(Vector3(xs, 1.0, zs))
