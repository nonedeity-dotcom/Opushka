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
## Сцена выхода из воды: время от начала; < 0 — не идёт.
var intro_t := -1.0
signal intro_done
var _intro_from := Vector3.ZERO
var _intro_to := Vector3.ZERO
var _splashed := false
var _bubbles: CPUParticles3D
var _drips: CPUParticles3D
var _ripples: Array = []
var _env: Environment
const INTRO_LEN := 9.0
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
	_env = env
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
	rebuild_player()
	_sync_mobs(0.0)
	_sync_bones()
	camera = Camera3D.new()
	camera.fov = 50.0
	camera.far = 600.0
	add_child(camera)
	_camera(1.0)

## Собрать тебя заново — из тела суши (после редактора). Зрение — сколько тумана.
func rebuild_player() -> void:
	var evo := land.evo
	var c := Color(Content.COLORS[evo.color])
	var c2 := Color(Content.COLORS[evo.color2]) if evo.pattern != "none" else c.darkened(0.25)
	var body: Dictionary = evo.land_body if not evo.land_body.is_empty() else LandParts.from_sea(evo.body).body
	_player.build_body(c, c2, 1.0, body, evo.pattern, Content.shape_stats(evo.shape).elong)
	var sight: float = land.st.sight
	_env.fog_density = 0.0025 / pow(maxf(sight, 0.3), 2.0)

## Где выходить из воды: луч от середины острова в сторону дома — от глубины к берегу.
func _shore_path() -> void:
	var a := atan2(land.home.z, land.home.x)
	var best := []
	for k in 12:
		var ang := a + (k * 0.5 if k % 2 == 0 else -k * 0.5)
		var dir := Vector3(cos(ang), 0, sin(ang))
		var shore := -1.0
		var deep := -1.0
		for r in range(60, 300):
			var p := dir * r
			var h := land.terrain.height(p.x, p.z)
			if shore < 0.0 and h < Terrain.WATER + 0.15:
				shore = r
			if shore > 0.0 and h < -2.3:
				deep = r
				break
		if shore < 0.0 or deep < 0.0 or deep - shore > 36.0:
			continue
		var end := dir * (shore - 9.0)
		if land.terrain.height(end.x, end.z) < 0.8:
			continue
		best = [dir * deep, end]
		break
	if best.is_empty():
		best = [land.home + Vector3(0, 0, 20), land.home]
	_intro_from = Vector3(best[0].x, 0, best[0].z)
	_intro_to = Vector3(best[1].x, 0, best[1].z)

## Сцена выхода из воды: по дну к берегу, из воды — брызги, встряхнуться, и камера
## поднимается к обычному виду.
func start_intro() -> void:
	_shore_path()
	intro_t = 0.0
	_splashed = false
	land.scripted = true
	land.pos = Vector3(_intro_from.x, land.terrain.height(_intro_from.x, _intro_from.z), _intro_from.z)
	land.heading = atan2(_intro_to.x - _intro_from.x, _intro_to.z - _intro_from.z)
	cam_yaw = land.heading + PI
	_player.update(0.0, land.pos, land.heading, Vector3.ZERO)
	# Пузыри поднимаются над тобой, пока идёшь под водой.
	_bubbles = CPUParticles3D.new()
	_bubbles.amount = 40
	_bubbles.lifetime = 1.4
	var bm := SphereMesh.new()
	bm.radius = 0.07
	bm.height = 0.14
	bm.radial_segments = 6
	bm.rings = 3
	_bubbles.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.9, 0.97, 1.0, 0.7)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bubbles.material_override = bmat
	_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_bubbles.emission_sphere_radius = 0.6
	_bubbles.direction = Vector3.UP
	_bubbles.spread = 15.0
	_bubbles.gravity = Vector3(0, 1.5, 0)
	_bubbles.initial_velocity_min = 0.5
	_bubbles.initial_velocity_max = 1.2
	add_child(_bubbles)
	happened.emit({"t": "intro_start"})

func _splash(at: Vector3) -> void:
	var sp := CPUParticles3D.new()
	sp.one_shot = true
	sp.explosiveness = 0.95
	sp.amount = 70
	sp.lifetime = 1.2
	var dm := SphereMesh.new()
	dm.radius = 0.09
	dm.height = 0.18
	dm.radial_segments = 6
	dm.rings = 3
	sp.mesh = dm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.95, 1.0, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sp.material_override = m
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sp.emission_sphere_radius = 0.8
	sp.direction = Vector3.UP
	sp.spread = 50.0
	sp.initial_velocity_min = 2.5
	sp.initial_velocity_max = 5.5
	sp.gravity = Vector3(0, -9.8, 0)
	sp.scale_amount_min = 0.6
	sp.scale_amount_max = 1.4
	sp.position = Vector3(at.x, Terrain.WATER + 0.2, at.z)
	add_child(sp)
	sp.emitting = true
	sp.finished.connect(sp.queue_free)
	# Круги по воде.
	for i in 3:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.85
		tm.outer_radius = 1.0
		tm.rings = 24
		tm.ring_segments = 4
		ring.mesh = tm
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(1, 1, 1, 0.6)
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = rm
		ring.position = Vector3(at.x, Terrain.WATER + 0.03, at.z)
		ring.scale = Vector3(0.5, 0.2, 0.5)
		add_child(ring)
		_ripples.append({"node": ring, "t": -0.35 * i})
	# Капли с тела ещё пару секунд.
	_drips = CPUParticles3D.new()
	_drips.amount = 24
	_drips.lifetime = 0.6
	_drips.mesh = dm
	_drips.material_override = m
	_drips.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_drips.emission_box_extents = Vector3(0.5, 0.2, 0.8)
	_drips.direction = Vector3.DOWN
	_drips.gravity = Vector3(0, -9.8, 0)
	_drips.initial_velocity_min = 0.2
	_drips.initial_velocity_max = 0.6
	_drips.scale_amount_min = 0.4
	_drips.scale_amount_max = 0.8
	add_child(_drips)
	happened.emit({"t": "intro_splash"})

func _intro(delta: float) -> void:
	intro_t += delta
	var t := intro_t
	# 0–1,2 с: стоишь на дне; 1,2–6,5: идёшь к берегу (всё быстрее); 6,5–7,5: встряхнулся.
	var walk := clampf((t - 1.2) / 5.3, 0.0, 1.0)
	var k := walk * walk * (3.0 - 2.0 * walk)
	var flat := _intro_from.lerp(_intro_to, k)
	var prev := land.pos
	land.pos = Vector3(flat.x, land.terrain.height(flat.x, flat.z), flat.z)
	land.vel = (land.pos - prev) / maxf(delta, 0.001)
	land.vel.y = 0.0
	land.step(minf(delta, 0.05), Vector2.ZERO)
	for e in land.events:
		happened.emit(e)
	_player.update(delta, land.pos, land.heading, land.vel)
	# Встряхнуться, как собака, — брызги летят.
	if t > 6.6 and t < 7.6:
		var q := (t - 6.6) / 1.0
		_player._body.rotation.z = sin(q * TAU * 5.0) * 0.35 * (1.0 - q)
	var under: bool = land.pos.y + 0.9 < Terrain.WATER
	if _bubbles:
		_bubbles.position = land.pos + Vector3(0, 0.8, 0)
		_bubbles.emitting = under
	if not _splashed and land.pos.y + 0.5 > Terrain.WATER and t > 1.5:
		_splashed = true
		_splash(land.pos)
	if _drips:
		_drips.position = land.pos + Vector3(0, 0.9, 0)
		_drips.emitting = t < 7.8
	for r in _ripples:
		r.t += delta
		var n: MeshInstance3D = r.node
		n.visible = r.t > 0.0
		if r.t > 0.0:
			var sc: float = 0.6 + r.t * 3.2
			n.scale = Vector3(sc, 0.2, sc)
			(n.material_override as StandardMaterial3D).albedo_color.a = maxf(0.0, 0.6 * (1.0 - r.t / 1.8))
	# Камера: низко сбоку у воды, потом плавно поднимается в обычное место.
	var rise := clampf((t - 5.0) / 3.5, 0.0, 1.0)
	rise = rise * rise * (3.0 - 2.0 * rise)
	var side := Vector3(cos(land.heading), 0, -sin(land.heading))
	var low := land.pos + side * 6.5 + Vector3(0, 1.4, 0) + Vector3(sin(land.heading), 0, cos(land.heading)) * 2.5
	# Камера — над водой: снизу гладь не видна, и казалось бы, что воды нет.
	low.y = maxf(low.y, Terrain.WATER + 1.1)
	var target := land.pos + Vector3(0, 0.8, 0)
	var back := Vector3(sin(cam_yaw), 0, cos(cam_yaw))
	var game_target := land.pos + Vector3(0, 1.0, 0) - back * 3.0
	var game := game_target + back * cos(CAM_PITCH) * _cam_dist() + Vector3(0, sin(CAM_PITCH) * _cam_dist(), 0)
	camera.global_position = low.lerp(game, rise)
	camera.look_at(target.lerp(game_target, rise), Vector3.UP)
	if t >= INTRO_LEN:
		finish_intro()

## Закончить сцену (или пропустить её касанием): ты на берегу, это теперь твой дом.
func finish_intro() -> void:
	if intro_t < 0.0:
		return
	intro_t = -1.0
	var p := _intro_to
	land.pos = Vector3(p.x, land.terrain.height(p.x, p.z), p.z)
	land.home = land.pos
	land.vel = Vector3.ZERO
	land.scripted = false
	_player._body.rotation.z = 0.0
	for r in _ripples:
		(r.node as Node3D).queue_free()
	_ripples.clear()
	if _bubbles:
		_bubbles.queue_free()
		_bubbles = null
	if _drips:
		_drips.queue_free()
		_drips = null
	intro_done.emit()

func _cam_dist() -> float:
	return CAM_DIST * clampf(0.85 + 0.2 * float(land.st.sight), 0.9, 1.2)

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
	if intro_t >= 0.0:
		_intro(delta)
		_sync_mobs(delta)
		_sync_bones()
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
	var want := target + back * cos(CAM_PITCH) * _cam_dist() + Vector3(0, sin(CAM_PITCH) * _cam_dist(), 0)
	camera.global_position = camera.global_position.lerp(want, 1.0 - exp(-6.0 * delta))
	camera.look_at(target, Vector3.UP)
