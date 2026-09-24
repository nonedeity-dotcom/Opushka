## Суша на экране: остров, вода, небо, деревья, кусты с плодами, гнёзда, кости, ты и
## соседи, камера. Камера — сверху под углом, следует за тобой; её можно повернуть пальцем.
class_name LandWorld
extends Node3D

## Всё, что случилось за кадр (съел, укусил, ранили, разбил кость…) — для звуков и дрожи.
signal happened(e: Dictionary)

var land: Land
var input := Vector2.ZERO  # джойстик: x — вправо, y — вниз по экрану
var cam_yaw := 0.0
var camera: Camera3D
var _player: Creature3D
var _mobs := {}  # uid → Creature3D
var _bushes: Array = []  # [{node, fruits: [MeshInstance3D]}]
var _nests: Array = []  # [{node, eggs: [MeshInstance3D]}]
var _bones := {}  # uid кости → Node3D
var _ground_fn: Callable
## Нажали «Укус» — передаётся в мир на следующем шаге.
var bite_pressed := false
## Дальше этого существ и кости не рисуем — всё равно не видно, а телефону легче.
const DRAW_DIST := 70.0

const CAM_PITCH := deg_to_rad(40.0)
const CAM_DIST := 15.0

func setup(l: Land) -> void:
	land = l
	var evo := l.evo
	# Свет и небо.
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#5fa8e0")
	sm.sky_horizon_color = Color("#cfe8f0")
	sm.ground_horizon_color = Color("#cfe8f0")
	sm.ground_bottom_color = Color("#3a7fa0")
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.4
	env.ambient_light_sky_contribution = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("#9fcbe6")
	env.fog_density = 0.0025
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(-35.0), 0.0)
	sun.light_energy = 1.0
	sun.light_color = Color("#fff4e0")
	add_child(sun)
	# Земля.
	var ground := MeshInstance3D.new()
	ground.mesh = l.terrain.build_mesh()
	var gm := StandardMaterial3D.new()
	gm.vertex_color_use_as_albedo = true
	gm.roughness = 1.0
	ground.material_override = gm
	add_child(ground)
	# Вода: полупрозрачная гладь — сквозь неё видно песчаное дно.
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1400, 1400)
	water.mesh = plane
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.2, 0.6, 0.78, 0.72)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.15
	wm.metallic_specular = 0.8
	water.material_override = wm
	water.position.y = Terrain.WATER
	add_child(water)
	_trees()
	_make_bushes()
	_make_nests()
	# Ты — цвета своего вида. Соседи — свои цвета и ноги.
	_ground_fn = func(x: float, z: float) -> float: return land.terrain.height(x, z)
	_player = Creature3D.new()
	_player.ground = _ground_fn
	add_child(_player)
	var c := Color(Content.COLORS[evo.color])
	_player.build(c, Color(Content.COLORS[evo.color2]) if evo.pattern != "none" else c.darkened(0.25), 1.0, 4)
	_sync_mobs(0.0)
	_sync_bones()
	camera = Camera3D.new()
	camera.fov = 50.0
	camera.far = 600.0
	add_child(camera)
	_camera(1.0)

func _trees() -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.3
	trunk.height = 2.4
	trunk.radial_segments = 6
	var crown := SphereMesh.new()
	crown.radius = 1.5
	crown.height = 2.6
	crown.radial_segments = 7
	crown.rings = 4
	for pair in [[trunk, Color("#8a6040"), 1.2], [crown, Color("#3f8f3c"), 3.3]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = pair[0]
		mm.instance_count = land.trees.size()
		for i in land.trees.size():
			var t: Dictionary = land.trees[i]
			var s: float = t.size
			var p: Vector3 = t.pos
			var xf := Transform3D(Basis().scaled(Vector3(s, s, s)), p + Vector3(0, float(pair[2]) * s, 0))
			mm.set_instance_transform(i, xf)
			var base: Color = pair[1]
			mm.set_instance_color(i, base.lightened(fposmod(p.x * 0.13 + p.z * 0.29, 1.0) * 0.25))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.9
		mi.material_override = m
		add_child(mi)

func _make_bushes() -> void:
	var leaf := Creature3D.mat(Color("#4fa84a"), 0.9)
	var fruit := Creature3D.mat(Color("#e8505a"), 0.4)
	for b in land.bushes:
		var node := Node3D.new()
		node.position = b.pos
		add_child(node)
		var bush := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.8
		sm.height = 1.2
		sm.radial_segments = 8
		sm.rings = 4
		bush.mesh = sm
		bush.material_override = leaf
		bush.position.y = 0.45
		node.add_child(bush)
		var fruits: Array = []
		for i in Land.FRUITS:
			var f := MeshInstance3D.new()
			var fm := SphereMesh.new()
			fm.radius = 0.16
			fm.height = 0.32
			fm.radial_segments = 8
			fm.rings = 4
			f.mesh = fm
			f.material_override = fruit
			var a := TAU * i / Land.FRUITS
			f.position = Vector3(cos(a) * 0.7, 0.55 + 0.2 * (i % 2), sin(a) * 0.7)
			node.add_child(f)
			fruits.append(f)
		_bushes.append({"node": node, "fruits": fruits})

## Гнездо: кольцо из веток и яйца в нём.
func _make_nests() -> void:
	var twig := Creature3D.mat(Color("#8a6a44"), 1.0)
	var twig2 := Creature3D.mat(Color("#6e5236"), 1.0)
	var egg := Creature3D.mat(Color("#f2ead2"), 0.5)
	var spot := Creature3D.mat(Color("#b89a70"), 0.8)
	for n in land.nests:
		var node := Node3D.new()
		node.position = n.pos
		add_child(node)
		var cm := CylinderMesh.new()
		cm.top_radius = 0.09
		cm.bottom_radius = 0.11
		cm.height = 1.5
		cm.radial_segments = 5
		cm.rings = 1
		for i in 16:
			var a := TAU * i / 16.0
			var tw := MeshInstance3D.new()
			tw.mesh = cm
			tw.material_override = twig if i % 2 == 0 else twig2
			tw.position = Vector3(cos(a) * 1.35, 0.22 + 0.12 * (i % 3), sin(a) * 1.35)
			# Ветки лежат по кругу, чуть вкось.
			tw.basis = Creature3D._basis_y(Vector3(-sin(a), 0.15 * ((i % 3) - 1), cos(a)).rotated(Vector3.UP, 0.35))
			node.add_child(tw)
		var bed := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 1.3
		bm.bottom_radius = 1.1
		bm.height = 0.25
		bm.radial_segments = 10
		bed.mesh = bm
		bed.material_override = twig2
		bed.position.y = 0.08
		node.add_child(bed)
		var eggs: Array = []
		for i in Land.EGGS:
			var e := MeshInstance3D.new()
			var em := SphereMesh.new()
			em.radius = 0.3
			em.height = 0.78
			em.radial_segments = 10
			em.rings = 6
			e.mesh = em
			e.material_override = egg
			var a := TAU * i / Land.EGGS + 0.4
			e.position = Vector3(cos(a) * 0.45, 0.5, sin(a) * 0.45)
			e.rotation.z = 0.25 * (i - 1)
			var sp := MeshInstance3D.new()
			var smm := SphereMesh.new()
			smm.radius = 0.09
			smm.height = 0.1
			smm.radial_segments = 6
			smm.rings = 3
			sp.mesh = smm
			sp.material_override = spot
			sp.position = Vector3(0.18, 0.12, 0.18)
			e.add_child(sp)
			node.add_child(e)
			eggs.append(e)
		_nests.append({"node": node, "eggs": eggs})

## Кость: большой скелет (череп, хребет, рёбра) или кучка (череп и пара костей).
func _make_bone(b: Dictionary) -> Node3D:
	var node := Node3D.new()
	node.position = b.pos
	node.rotation.y = b.yaw
	var s: float = b.size
	var m := Creature3D.mat(Color("#ece2c8"), 0.6)
	var dark := Creature3D.mat(Color("#3a3028"), 1.0)
	var inner := Node3D.new()
	inner.name = "Inner"
	node.add_child(inner)
	var sk := s * (0.55 if b.big else 0.6)
	var skull := MeshInstance3D.new()
	var skm := SphereMesh.new()
	skm.radius = sk
	skm.height = sk * 1.8
	skm.radial_segments = 12
	skm.rings = 6
	skull.mesh = skm
	skull.material_override = m
	var head_at := Vector3(0, sk * 0.75, s * (0.9 if b.big else 0.0))
	skull.position = head_at
	skull.scale = Vector3(1.0, 0.85, 1.2)
	inner.add_child(skull)
	for side in [-1.0, 1.0]:
		var hole := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = sk * 0.26
		hm.height = sk * 0.4
		hm.radial_segments = 8
		hm.rings = 4
		hole.mesh = hm
		hole.material_override = dark
		hole.position = head_at + Vector3(side * sk * 0.42, sk * 0.15, sk * 0.95)
		inner.add_child(hole)
	var rod := func(from: Vector3, to: Vector3, r: float) -> void:
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
		mi.basis = Creature3D._basis_y(to - from)
		inner.add_child(mi)
	if b.big:
		# Хребет и рёбра дугами — как выброшенный на берег великан.
		var spine_from := Vector3(0, s * 0.35, s * 0.4)
		var spine_to := Vector3(0, s * 0.2, -s * 1.6)
		rod.call(spine_from, spine_to, 0.13 * s)
		for i in 5:
			var z := lerpf(0.1, -1.3, i / 4.0) * s
			var h := s * (0.95 - i * 0.1)
			for side in [-1.0, 1.0]:
				var top := Vector3(0, s * 0.33, z)
				var mid := Vector3(side * h * 0.55, h * 0.75, z - 0.1 * s)
				var low := Vector3(side * h * 0.8, 0.05, z - 0.2 * s)
				rod.call(top, mid, 0.07 * s)
				rod.call(mid, low, 0.06 * s)
	else:
		for q in [[Vector3(-0.9, 0.12, -0.3), Vector3(0.7, 0.12, -0.8)], [Vector3(0.9, 0.15, 0.2), Vector3(0.1, 0.1, 0.9)]]:
			rod.call((q[0] as Vector3) * s, (q[1] as Vector3) * s, 0.1 * s)
			for end in q:
				var knob := MeshInstance3D.new()
				var km := SphereMesh.new()
				km.radius = 0.16 * s
				km.height = 0.32 * s
				km.radial_segments = 6
				km.rings = 3
				knob.mesh = km
				knob.material_override = m
				knob.position = (end as Vector3) * s
				inner.add_child(knob)
	return node

## Кости: новые — построить, разбитые — спрятать, вернувшиеся — снова показать.
func _sync_bones() -> void:
	var seen := {}
	for b in land.bones:
		seen[b.uid] = true
		var n: Node3D = _bones.get(b.uid)
		if n == null:
			n = _make_bone(b)
			add_child(n)
			_bones[b.uid] = n
		n.visible = b.alive and (b.pos as Vector3).distance_to(land.pos) < DRAW_DIST + 20.0
		if n.visible:
			# Удар — кость вздрагивает; побитая — поменьше.
			var inner := n.get_node("Inner") as Node3D
			inner.position.x = sin(land.time * 60.0) * 0.08 * float(b.hit) * float(b.size)
			inner.scale = Vector3.ONE * (0.7 + 0.3 * float(b.hp) / float(b.max_hp))
	for uid in _bones.keys():
		if not seen.has(uid):
			(_bones[uid] as Node3D).queue_free()
			_bones.erase(uid)

## Существа: новые — построить, умершие — убрать. Далёкие — не рисовать.
func _sync_mobs(delta: float) -> void:
	var seen := {}
	for m in land.mobs:
		seen[m.uid] = true
		var cr: Creature3D = _mobs.get(m.uid)
		if cr == null:
			cr = Creature3D.new()
			cr.ground = _ground_fn
			add_child(cr)
			var nc := Color(m.color)
			var hermit: bool = m.kind == "hermit"
			cr.build(nc, nc.darkened(0.45 if hermit else 0.3), m.size, m.legs, hermit)
			_mobs[m.uid] = cr
		var far: bool = (m.pos as Vector3).distance_to(land.pos) > DRAW_DIST
		cr.visible = not far
		if far:
			continue
		cr.update(delta, m.pos, m.heading, m.vel)
		cr.flash(m.hit)
		cr.health(m.hp / m.max_hp)
	for uid in _mobs.keys():
		if not seen.has(uid):
			(_mobs[uid] as Node3D).queue_free()
			_mobs.erase(uid)

func _process(delta: float) -> void:
	if land == null:
		return
	# Джойстик — относительно камеры: «вверх» — от камеры вглубь экрана.
	var fwd := Vector2(sin(cam_yaw), cos(cam_yaw)) * -1.0
	var right := Vector2(-fwd.y, fwd.x)
	var dir := right * input.x - fwd * input.y
	land.step(minf(delta, 0.05), dir, bite_pressed)
	bite_pressed = false
	for e in land.events:
		match e.t:
			"bite":
				_player.lunge()
			"hurt":
				# Тебя кусили: ты белеешь, а кусачий бросается вперёд.
				_player.flash(1.0)
				if _mobs.has(e.uid):
					(_mobs[e.uid] as Creature3D).lunge()
		happened.emit(e)
	_player.flash(_player._flash - delta * 3.0)
	_player.update(delta, land.pos, land.heading, land.vel)
	_sync_mobs(delta)
	_sync_bones()
	for i in _nests.size():
		var eggs: Array = _nests[i].eggs
		for j in eggs.size():
			eggs[j].visible = j < int(land.nests[i].eggs)
	for i in _bushes.size():
		var fr: Array = _bushes[i].fruits
		for j in fr.size():
			fr[j].visible = j < int(land.bushes[i].fruits)
	_camera(delta)

func _camera(delta: float) -> void:
	# Смотрим чуть вперёд от тебя — видно, куда идёшь.
	var target := land.pos + Vector3(0, 1.0, 0) - Vector3(sin(cam_yaw), 0, cos(cam_yaw)) * 3.0
	var back := Vector3(sin(cam_yaw), 0, cos(cam_yaw))
	var want := target + back * cos(CAM_PITCH) * CAM_DIST + Vector3(0, sin(CAM_PITCH) * CAM_DIST, 0)
	camera.global_position = camera.global_position.lerp(want, 1.0 - exp(-6.0 * delta))
	camera.look_at(target, Vector3.UP)
