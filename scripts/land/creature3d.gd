## Существо суши на экране: тело из шаров, голова с глазами и пастью, хвост, ноги из двух
## звеньев. Ноги ставятся сами: ступня стоит на земле, пока тело не ушло от неё дальше
## шага, — тогда она перешагивает вперёд дугой. Ноги ходят парами накрест.
class_name Creature3D
extends Node3D

var size := 1.0
var color := Color("#8fd07a")
var color2 := Color("#5f9a52")
var leg_count := 4
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
	var parts := {"legs": "legs2" if legs == 2 else "legs4", "mouth": "jaws", "eyes": "eyes"}
	if spikes:
		parts.back = "back_spikes"
		parts.head = "horns"
	build_body(c, c2, s, parts, "spots")

## Собрать тело из частей суши (LandParts): место → часть. pattern — узор вида,
## elong — вытянутость тела (из формы клетки). Вперёд — ось +Z.
func build_body(c: Color, c2: Color, s: float, parts: Dictionary, pattern := "spots", elong := 1.0) -> void:
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()
	_legs.clear()
	_arms.clear()
	_bar = null
	_tail = null
	color = c
	color2 = c2
	size = s
	_parts = parts
	var legs_id: String = parts.get("legs", "stubs")
	leg_count = int(LandParts.PARTS[legs_id].legs) if LandParts.PARTS.has(legs_id) else 4
	_mat = mat(color)
	_mat2 = mat(color2)
	if parts.get("skin", "") == "scales":
		_mat.roughness = 0.35
		_mat.metallic_specular = 0.8
	_leg_len = size * (1.35 if legs_id == "legs_long" else (0.62 if legs_id == "stubs" else 0.95))
	_body = Node3D.new()
	add_child(_body)
	var R := 0.5 * size
	var e := clampf(elong, 0.8, 1.5)
	# Туловище — два шара, голова, хвост.
	var front := Vector3(0, 0, 0.25 * size * e)
	var rear := Vector3(0, 0.02 * size, -0.35 * size * e)
	_sphere(R * 1.05, _mat, front, _body, Vector3(1.0, 0.9, 1.1 * e))
	_sphere(R * 0.95, _mat2 if pattern == "gradient" else _mat, rear, _body, Vector3(1.0, 0.9, 1.1 * e))
	var head := Vector3(0, 0.22 * size, 0.85 * size * e)
	_sphere(R * 0.78, _mat, head, _body)
	_pattern(pattern, e)
	_tail_part(parts.get("tail", ""), e)
	_mouth(parts.get("mouth", ""), head)
	_eyes(parts.get("eyes", ""), head)
	_head_part(parts.get("head", ""), head)
	_back(parts.get("back", ""), e)
	_skin(parts.get("skin", ""), e)
	_make_arms(parts.get("arms", ""), e)
	# Ноги: пары вдоль тела, ходят накрест.
	var hips: Array = []
	match leg_count:
		2:
			hips = [[Vector3(-0.42, -0.1, -0.1), 0], [Vector3(0.42, -0.1, -0.1), 1]]
		6:
			hips = [[Vector3(-0.42, -0.1, 0.4 * e), 0], [Vector3(0.42, -0.1, 0.4 * e), 1], [Vector3(-0.46, -0.1, -0.02), 1],
				[Vector3(0.46, -0.1, -0.02), 0], [Vector3(-0.4, -0.1, -0.45 * e), 0], [Vector3(0.4, -0.1, -0.45 * e), 1]]
		_:
			hips = [[Vector3(-0.42, -0.1, 0.3 * e), 0], [Vector3(0.42, -0.1, 0.3 * e), 1], [Vector3(-0.4, -0.1, -0.4 * e), 1], [Vector3(0.4, -0.1, -0.4 * e), 0]]
	var thick := 1.25 if parts.get("feet", "") == "hooves" else 1.0
	for h in hips:
		var leg := {"hip": (h[0] as Vector3) * size, "group": h[1], "t": -1.0, "foot": Vector3.ZERO, "from": Vector3.ZERO, "to": Vector3.ZERO,
			"a": _leg_len * 0.55, "b": _leg_len * 0.55}
		leg.upper = _limb(0.1 * size * thick, leg.a)
		leg.lower = _limb(0.085 * size * thick, leg.b)
		leg.paw = _foot(parts.get("feet", ""), parts.get("claws", ""))
		_legs.append(leg)
	# Тень-пятно под телом: дёшево, а существо «стоит» на земле.
	var shadow := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.9 * size * e
	disc.bottom_radius = 0.9 * size * e
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
	_place_feet()

## Узор вида: пятна, полоски-кольца или ничего.
func _pattern(pattern: String, e: float) -> void:
	match pattern:
		"stripes", "rings":
			# Полосы поперёк спины: сплюснутые шары, торчит только верх.
			for z in [0.5, 0.2, -0.1, -0.4, -0.65]:
				var w := 0.9 - absf(z + 0.05) * 0.35
				_sphere(0.5 * size, _mat2, Vector3(0, 0.2, z * e) * size, _body, Vector3(w, 0.52, 0.13))
		"none", "gradient":
			pass
		_:
			for q in [Vector3(0.18, 0.42, 0.3), Vector3(-0.2, 0.4, -0.05), Vector3(0.05, 0.38, -0.45), Vector3(-0.12, 0.36, 0.55)]:
				_sphere(0.5 * size * 0.28, _mat2, Vector3(q.x, q.y, q.z * e) * size, _body, Vector3(1, 0.5, 1))

func _tail_part(id: String, e: float) -> void:
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.05, -0.75 * e) * size
	_body.add_child(_tail)
	var R := 0.5 * size
	match id:
		"tail_long":
			_cone(R * 0.42, 1.5 * size, _mat, Vector3.ZERO, Vector3(0, 0.3, -1), _tail)
		"tail_club":
			_cone(R * 0.4, 0.9 * size, _mat, Vector3.ZERO, Vector3(0, 0.25, -1), _tail)
			var club := Vector3(0, 0.22, -0.9) * size
			_sphere(0.24 * size, _mat2, club, _tail)
			var bone := mat(Color("#e8dcc0"), 0.5)
			for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)]:
				_cone(0.07 * size, 0.2 * size, bone, club + d * 0.18 * size, d, _tail)
		_:
			_cone(R * 0.45, 0.8 * size, _mat, Vector3.ZERO, Vector3(0, 0.25, -1), _tail)

func _mouth(id: String, head: Vector3) -> void:
	var tooth := mat(Color("#efe6cf"), 0.4)
	match id:
		"beak":
			var horn := mat(Color("#f0b040"), 0.5)
			_cone(0.2 * size, 0.45 * size, horn, head + Vector3(0, 0.0, 0.3) * size, Vector3(0, -0.15, 1), _body)
			_cone(0.14 * size, 0.3 * size, horn, head + Vector3(0, -0.12, 0.28) * size, Vector3(0, -0.4, 1), _body)
		"fangs":
			for side in [-1.0, 1.0]:
				_cone(0.1 * size, 0.42 * size, tooth, head + Vector3(side * 0.14, -0.2, 0.3) * size, Vector3(0, -1, 0.3), _body)
				_cone(0.06 * size, 0.22 * size, tooth, head + Vector3(side * 0.26, -0.18, 0.2) * size, Vector3(0, -1, 0.2), _body)
			_sphere(0.22 * size, _mat, head + Vector3(0, -0.2, 0.18) * size, _body, Vector3(1.2, 0.6, 1.1))
		"snout":
			var tip := head + Vector3(0, -0.05, 0.3) * size
			var mid := tip + Vector3(0, -0.12, 0.35) * size
			var end := mid + Vector3(0, -0.35, 0.12) * size
			_rod(tip, mid, 0.13 * size, _mat)
			_rod(mid, end, 0.1 * size, _mat)
			_sphere(0.12 * size, _mat2, end, _body)
		"jaws":
			for side in [-1.0, 1.0]:
				_cone(0.07 * size, 0.28 * size, tooth, head + Vector3(side * 0.12, -0.2, 0.3) * size, Vector3(0, -1, 0.35), _body)
		_:
			# Рта нет — только тёмная щёлка.
			_sphere(0.08 * size, mat(Color("#2a1e22"), 1.0), head + Vector3(0, -0.12, 0.34) * size, _body, Vector3(2.2, 0.4, 0.6))

func _eyes(id: String, head: Vector3) -> void:
	var white := mat(Color("#f4f4ec"), 0.3)
	var black := mat(Color("#1e1e28"), 0.2)
	match id:
		"":
			return
		"eyes_stalk":
			for side in [-1.0, 1.0]:
				var base := head + Vector3(side * 0.16, 0.3, 0.05) * size
				var top := base + Vector3(side * 0.12, 0.42, 0.08) * size
				_rod(base, top, 0.04 * size, _mat)
				_sphere(0.12 * size, white, top, _body)
				_sphere(0.065 * size, black, top + Vector3(side * 0.02, 0.0, 0.1) * size, _body)
		_:
			var k := 1.45 if id == "eyes_big" else 1.0
			for side in [-1.0, 1.0]:
				var eye := head + Vector3(side * 0.22, 0.2, 0.28) * size
				_sphere(0.14 * size * k, white, eye, _body)
				_sphere(0.075 * size * k, black, eye + Vector3(side * 0.03, 0.02, 0.1 * k) * size, _body)

func _head_part(id: String, head: Vector3) -> void:
	match id:
		"horns":
			var horn := mat(Color("#e8dcc0"), 0.5)
			for side in [-1.0, 1.0]:
				_cone(0.08 * size, 0.42 * size, horn, head + Vector3(side * 0.25, 0.25, -0.05) * size, Vector3(side * 0.5, 1, -0.6), _body)
		"crest":
			_sphere(0.35 * size, _mat2, head + Vector3(0, 0.38, -0.15) * size, _body, Vector3(0.12, 0.9, 1.2))

func _back(id: String, e: float) -> void:
	match id:
		"back_spikes":
			var horn := mat(Color("#e8dcc0"), 0.5)
			for i in 5:
				var z := 0.55 - i * 0.28
				_cone(0.1 * size, (0.42 - absf(i - 1.5) * 0.06) * size, horn, Vector3(0, 0.36, z * e) * size, Vector3(0, 1, -0.35), _body)
		"plates":
			var plate := mat(color2.darkened(0.2), 0.6)
			for i in 5:
				var z := 0.5 - i * 0.26
				_sphere(0.24 * size, plate, Vector3(0.1 * (1 if i % 2 == 0 else -1), 0.5, z * e) * size, _body, Vector3(0.25, 1.0, 0.9))
		"sail":
			var m := mat(color2.lightened(0.15), 0.5)
			_sphere(0.6 * size, m, Vector3(0, 0.62, -0.05 * e) * size, _body, Vector3(0.08, 0.85, 1.2 * e))
			var bone := mat(Color("#e8dcc0"), 0.5)
			for i in 5:
				var z := (0.45 - i * 0.24) * e
				var hgt := 0.55 - absf(i - 2) * 0.12
				_rod(Vector3(0, 0.35, z) * size, Vector3(0, 0.35 + hgt + 0.3, z - 0.05) * size, 0.03 * size, bone)

func _skin(id: String, e: float) -> void:
	match id:
		"fur":
			var tuft := mat(color.darkened(0.15), 1.0)
			for i in 9:
				var a := -0.9 + (i % 3) * 0.9
				var z := (0.5 - int(i / 3) * 0.5) * e
				_cone(0.09 * size, 0.2 * size, tuft, Vector3(sin(a) * 0.4, cos(a) * 0.38, z) * size, Vector3(sin(a), cos(a), -0.3), _body)
		"scales":
			var sc := mat(color2.darkened(0.1), 0.3)
			for side in [-1.0, 1.0]:
				for i in 4:
					_sphere(0.12 * size, sc, Vector3(side * 0.47, 0.08 + (i % 2) * 0.12, (0.45 - i * 0.3) * e) * size, _body, Vector3(0.4, 1, 1))
		"poison_skin":
			var dot := mat(Color("#c8f040"), 0.4)
			dot.emission_enabled = true
			dot.emission = Color("#a0e020")
			dot.emission_energy_multiplier = 0.5
			for q in [Vector3(0.3, 0.32, 0.4), Vector3(-0.32, 0.3, 0.15), Vector3(0.28, 0.3, -0.3), Vector3(-0.25, 0.34, -0.5), Vector3(0.0, 0.45, 0.0)]:
				_sphere(0.08 * size, dot, Vector3(q.x, q.y, q.z * e) * size, _body)

## Руки: плечо → локоть → кисть; висят спереди и качаются на ходу.
func _make_arms(id: String, e: float) -> void:
	if id == "":
		return
	for side in [-1.0, 1.0]:
		var arm := {"side": side, "shoulder": Vector3(side * 0.42, 0.05, 0.5 * e) * size, "claw": id == "arms_claw"}
		arm.upper = _limb(0.08 * size, 0.42 * size)
		arm.lower = _limb(0.07 * size, 0.4 * size)
		var hand := Node3D.new()
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

## Ступня: лапа, копыто или перепонка; когти — поверх.
func _foot(id: String, claws: String) -> Node3D:
	var paw := Node3D.new()
	add_child(paw)
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
			paw.add_child(hoof)
		"webbed":
			_sphere(0.2 * size, mat(color2.lightened(0.1), 0.6), Vector3(0, -0.02, 0.08) * size, paw, Vector3(1.3, 0.18, 1.3))
		"paws":
			_sphere(0.16 * size, _mat2, Vector3.ZERO, paw, Vector3(1.2, 0.65, 1.3))
		_:
			_sphere(0.12 * size, _mat2, Vector3.ZERO, paw, Vector3(1.1, 0.6, 1.3))
	if claws != "":
		var k := 1.6 if claws == "claws_big" else 1.0
		var nail := mat(Color("#f0e8d8"), 0.4)
		for f in 3:
			_cone(0.03 * size * k, 0.13 * size * k, nail, Vector3((f - 1) * 0.07, 0.0, 0.12) * size, Vector3((f - 1) * 0.3, -0.3, 1), paw)
	return paw

func _rod(from: Vector3, to: Vector3, r: float, m: Material) -> MeshInstance3D:
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
	_body.add_child(mi)
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
	return mi

## Где ступне стоять, если идти не надо: под бедром, чуть в сторону.
func _rest(leg: Dictionary) -> Vector3:
	var hip: Vector3 = leg.hip
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
		_bar.position.y = _leg_len + 1.5 * size
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
	var body_y := _leg_len * 0.85 + 0.5 * size * 0.6
	_body.position = Vector3(0, body_y + 0.05 * size * sin(_phase * 2.0) * minf(speed / 3.0, 1.0), 0)
	_body.rotation.z = 0.04 * sin(_phase) * minf(speed / 3.0, 1.0)
	# Бросок: быстро вперёд и вниз, потом назад.
	_lunge = maxf(0.0, _lunge - dt * 4.0)
	var jab := sin(PI * (1.0 - _lunge)) if _lunge > 0.0 else 0.0
	_body.position.z = jab * 0.35 * size
	_body.rotation.x = jab * 0.25
	# Первый кадр или долго не рисовали (был далеко) — ноги сразу под себя.
	if first or (_legs.size() > 0 and (_legs[0].foot as Vector3).distance_to(at) > _leg_len * 3.0):
		_place_feet()
	var stride := _leg_len * 0.7
	var busy := _stepping_group
	for leg in _legs:
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
		var local := (arm.shoulder as Vector3) + Vector3(arm.side * 0.06, -0.45, 0.35 + swing + jab * 0.45) * size
		var hand: Vector3 = _body.global_transform * local
		var elbow: Vector3 = (sh + hand) / 2.0 + global_transform.basis.x * arm.side * 0.12 * size + Vector3(0, -0.05, 0) * size
		_seg(arm.upper, sh, elbow)
		_seg(arm.lower, elbow, hand)
		(arm.hand as Node3D).global_position = hand
		(arm.hand as Node3D).global_rotation = Vector3(0, global_rotation.y, 0)
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
	_seg(leg.upper, hip, knee)
	_seg(leg.lower, knee, foot)
	(leg.paw as Node3D).global_position = foot + Vector3(0, 0.04 * size, 0)
	(leg.paw as Node3D).global_rotation = Vector3(0, global_rotation.y, 0)

func _seg(mi: MeshInstance3D, p: Vector3, q: Vector3) -> void:
	mi.global_position = (p + q) / 2.0
	mi.global_basis = _basis_y(q - p)
