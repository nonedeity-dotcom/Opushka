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

## Собрать тело. Вперёд — ось +Z. spikes — гребень шипов по спине (отшельники).
func build(c: Color, c2: Color, s: float, legs: int, spikes := false) -> void:
	for ch in get_children():
		ch.queue_free()
	_legs.clear()
	color = c
	color2 = c2
	size = s
	leg_count = legs
	_mat = mat(color)
	_mat2 = mat(color2)
	_leg_len = 0.95 * size
	_body = Node3D.new()
	add_child(_body)
	var R := 0.5 * size
	# Туловище — три шара, голова, хвост.
	_sphere(R * 1.05, _mat, Vector3(0, 0, 0.25 * size), _body, Vector3(1.0, 0.9, 1.1))
	_sphere(R * 0.95, _mat, Vector3(0, 0.02 * size, -0.35 * size), _body, Vector3(1.0, 0.9, 1.1))
	var head := Vector3(0, 0.22 * size, 0.85 * size)
	_sphere(R * 0.78, _mat, head, _body)
	_cone(R * 0.45, 0.8 * size, _mat, Vector3(0, 0.05 * size, -0.75 * size), Vector3(0, 0.25, -1), _body)
	# Пятна второго цвета на спине.
	for q in [Vector3(0.18, 0.42, 0.3), Vector3(-0.2, 0.4, -0.05), Vector3(0.05, 0.38, -0.45)]:
		_sphere(R * 0.28, _mat2, q * size, _body, Vector3(1, 0.5, 1))
	if spikes:
		var horn := mat(Color("#e8dcc0"), 0.5)
		for i in 5:
			var z := 0.55 - i * 0.28
			_cone(0.1 * size, (0.42 - absf(i - 1.5) * 0.06) * size, horn, Vector3(0, 0.36, z) * size, Vector3(0, 1, -0.35), _body)
		for side in [-1.0, 1.0]:
			_cone(0.07 * size, 0.35 * size, horn, head + Vector3(side * 0.25, 0.25, -0.05) * size, Vector3(side * 0.5, 1, -0.6), _body)
	# Глаза: белок и зрачок, чуть навыкате.
	var white := mat(Color("#f4f4ec"), 0.3)
	var black := mat(Color("#1e1e28"), 0.2)
	for side in [-1.0, 1.0]:
		var eye := head + Vector3(side * 0.22, 0.2, 0.28) * size
		_sphere(0.14 * size, white, eye, _body)
		_sphere(0.075 * size, black, eye + Vector3(side * 0.03, 0.02, 0.1) * size, _body)
	# Пасть: две челюсти-клыка вниз-вперёд.
	var tooth := mat(Color("#efe6cf"), 0.4)
	for side in [-1.0, 1.0]:
		_cone(0.07 * size, 0.28 * size, tooth, head + Vector3(side * 0.12, -0.2, 0.3) * size, Vector3(0, -1, 0.35), _body)
	# Ноги.
	var hips: Array = []
	if legs == 2:
		hips = [[Vector3(-0.42, -0.1, -0.1), 0], [Vector3(0.42, -0.1, -0.1), 1]]
	else:
		hips = [[Vector3(-0.42, -0.1, 0.3), 0], [Vector3(0.42, -0.1, 0.3), 1], [Vector3(-0.4, -0.1, -0.4), 1], [Vector3(0.4, -0.1, -0.4), 0]]
	for h in hips:
		var leg := {"hip": (h[0] as Vector3) * size, "group": h[1], "t": -1.0, "foot": Vector3.ZERO, "from": Vector3.ZERO, "to": Vector3.ZERO,
			"a": _leg_len * 0.55, "b": _leg_len * 0.55}
		leg.upper = _limb(0.1 * size, leg.a)
		leg.lower = _limb(0.085 * size, leg.b)
		leg.paw = _sphere(0.12 * size, _mat2, Vector3.ZERO, self, Vector3(1.1, 0.6, 1.3))
		_legs.append(leg)
	# Тень-пятно под телом: дёшево, а существо «стоит» на земле.
	var shadow := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.9 * size
	disc.bottom_radius = 0.9 * size
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
