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
var _sun: DirectionalLight3D
var _sky: ProceduralSkyMaterial
var _fog_base := 0.0025
## Своё гнездо (с маяком — столбом света, видно издалека).
var _own: Node3D
var _beacon: MeshInstance3D
var _relics := {}  # номер окаменелости → Node3D
var _carcasses := {}  # uid туши → Node3D
const INTRO_LEN := 9.0
## Дальше этого существ и кости не рисуем — всё равно не видно, а телефону легче.
const DRAW_DIST := 70.0

## Камера: насколько сверху (угол), как далеко; палец справа крутит и наклоняет, двумя
## пальцами — ближе/дальше. Бежишь вперёд — сама понемногу заходит за спину.
const CAM_DIST := 9.0
const PITCH_MIN := deg_to_rad(8.0)
const PITCH_MAX := deg_to_rad(70.0)
var cam_pitch := deg_to_rad(24.0)
var cam_zoom := 1.0
## Сколько секунд назад камеру трогали пальцем.
var cam_touch_t := 99.0
var _look_ahead := Vector3.ZERO
## Деревья: для каждого — [сетка ствола, сетка кроны, номер в сетках]; качаются от ударов.
var _tree_mm := {}  # вид → {trunk: MultiMesh, crown: MultiMesh, crown2: MultiMesh}
var _tree_slot := {}  # номер дерева → номер в сетках своего вида
var _shaking := {}  # номер дерева → true, пока качается
## Кроны, которые загородили тебя от камеры, — спрятаны (стоит только ствол).
var _hidden_crowns := {}
var _fruit_mm: MultiMesh
var _fruit_slot := {}  # номер плодового дерева → первый номер его плодов в сетке
var _fruit_seen := {}  # сколько плодов было нарисовано
var _drops := {}  # uid упавшего плода → узел
var _nest_food: Array = []  # у каждого гнезда — его запасы (узлы)
var _carry := {}  # uid существа → то, что оно несёт
## Качество картинки (настройки): fast — без травы рядом, меньше всего и ближе видно;
## best — тени от солнца и видно дальше.
var quality := "normal"
var _draw := 70.0
## Своё гнездо: яйца и запасы.
var _own_eggs: Array = []
var _own_food: Array = []
## Какого размера собран каждый свой (растут — пересобираются) и когда кто жевал.
var _ally_size := {}
var _chomped := {}
## Пыль из-под ног, следы на песке, птицы, дождь, молнии, плевки, рёв.
var _dust: CPUParticles3D
var _rain: CPUParticles3D
var _prints: Array = []  # [{node, t}]
var _print_at := Vector3.INF
var _print_side := 1.0
var _birds: Array = []  # [{node, c, r, h, a, speed, wings}]
var _fx: Array = []  # [{node, t, life, kind, from, to}]
var _flash_t := 0.0
## Густая трава вокруг тебя: пятно переезжает за тобой (на весь остров столько не нужно).
var _near_grass: MultiMesh
var _grass_at := Vector3(INF, 0, INF)
const GRASS_R := 26.0
const GRASS_N := 1400

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
	_sky = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.4
	env.ambient_light_sky_contribution = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("#9fcbe6")
	env.fog_density = 0.0018
	_env = env
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(-35.0), 0.0)
	sun.light_energy = 1.0
	sun.light_color = Color("#fff4e0")
	add_child(sun)
	_sun = sun
	# Земля.
	var ground := MeshInstance3D.new()
	ground.mesh = l.terrain.build_mesh(_trample())
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
	_draw = {"fast": 45.0, "normal": 70.0, "best": 95.0}.get(quality, 70.0)
	sun.shadow_enabled = quality == "best"
	_trees()
	_decor()
	_make_birds()
	_make_particles()
	_make_bushes()
	_make_nests()
	_make_own_nest()
	# Ты — цвета своего вида. Соседи — свои цвета и ноги.
	_ground_fn = func(x: float, z: float) -> float: return land.terrain.height(x, z)
	_player = Creature3D.new()
	_player.ground = _ground_fn
	add_child(_player)
	rebuild_player()
	_sync_mobs(0.0)
	_sync_bones()
	_sync_things()
	camera = Camera3D.new()
	camera.fov = 58.0
	camera.far = 900.0
	add_child(camera)
	_camera(1.0)

## Собрать тебя заново — из тела суши (после редактора). Зрение — сколько тумана.
## Свой — как ты: то же тело и окрас, только своего размера (детёныш — маленький). Пара
## — цвета наоборот.
func _build_ally(cr: Creature3D, m: Dictionary) -> void:
	var evo := land.evo
	var pt := evo.paint()
	var c := Color(LandParts.COLORS[pt.color])
	var c2 := Color(LandParts.COLORS[pt.color2]) if pt.pattern != "none" else c.darkened(0.25)
	if m.mate:
		var t := c
		c = c2.lerp(c, 0.3)
		c2 = t
	var body: Dictionary = evo.land_body if evo.land_can_walk() else LandParts.from_sea(evo.body).body
	var shape: Dictionary = evo.land_shape if not evo.land_shape.is_empty() else LandParts.shape_from_sea(evo.shape)
	cr.build_body(c, c2, m.size, body, pt.pattern, shape)
	_ally_size[m.uid] = m.size

func rebuild_player() -> void:
	var evo := land.evo
	var pt := evo.paint()
	var c := Color(LandParts.COLORS[pt.color])
	var c2 := Color(LandParts.COLORS[pt.color2]) if pt.pattern != "none" else c.darkened(0.25)
	var body: Dictionary = evo.land_body if evo.land_can_walk() else LandParts.from_sea(evo.body).body
	var shape: Dictionary = evo.land_shape if not evo.land_shape.is_empty() else LandParts.shape_from_sea(evo.shape)
	_player.build_body(c, c2, 1.0, body, pt.pattern, shape)
	# Свои тоже меняются вместе с тобой.
	for uid in _ally_size.keys():
		_ally_size[uid] = -1.0
	var sight: float = land.st.sight
	_fog_base = 0.0018 / pow(maxf(sight, 0.3), 2.0)
	_env.fog_density = _fog_base
	_daylight()

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
	var pose := _cam_pose()
	var game: Vector3 = pose[0]
	var game_target: Vector3 = pose[1]
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
	# Где вышел на берег — там твоё гнездо (потом его можно перенести).
	land.set_nest(land.pos)
	_trees()
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
	return CAM_DIST * cam_zoom * clampf(0.85 + 0.2 * float(land.st.sight), 0.9, 1.2)

## Где земля протоптана: круг у каждого гнезда и тропы от него к ближайшей еде.
func _trample() -> Array:
	var out: Array = []
	for n in land.nests:
		var c := Vector2(n.pos.x, n.pos.z)
		out.append({"a": c, "b": c, "r": 9.0})
		# Тропы — к трём ближайшим кустам и плодовым деревьям.
		var spots: Array = []
		for b in land.bushes:
			spots.append(Vector2(b.pos.x, b.pos.z))
		for t in land.trees:
			if t.kind == "fruit":
				spots.append(Vector2(t.pos.x, t.pos.z))
		spots = spots.filter(func(q): return q.distance_to(c) < Land.FORAGE_R)
		spots.sort_custom(func(x, y): return x.distance_to(c) < y.distance_to(c))
		for q in spots.slice(0, 3):
			out.append({"a": c, "b": q, "r": 1.6})
	return out

## Деревья трёх видов: лиственные (круглая крона), ели (конусы), плодовые (светлая крона
## с плодами). Всё — сетками по виду: деревьев много, а телефону легко. Бьёшь дерево —
## оно качается (меняется только его место в сетке).
func _trees() -> void:
	if _tree_mm.is_empty():
		_build_trees()
	for t in land.trees:
		_place_tree(t, 0.0)

func _build_trees() -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.3
	trunk.height = 2.4
	trunk.radial_segments = 6
	var round_ := SphereMesh.new()
	round_.radius = 1.5
	round_.height = 2.6
	round_.radial_segments = 7
	round_.rings = 4
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.4
	cone.height = 2.6
	cone.radial_segments = 7
	var counts := {}
	for t in land.trees:
		_tree_slot[t.i] = counts.get(t.kind, 0)
		counts[t.kind] = counts.get(t.kind, 0) + 1
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	for kind in counts:
		var set := {}
		var parts := [["trunk", trunk], ["crown", cone if kind == "pine" else round_]]
		if kind == "pine":
			parts.append(["crown2", cone])
		for pair in parts:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = pair[1]
			mm.instance_count = counts[kind]
			var mi := MultiMeshInstance3D.new()
			mi.multimesh = mm
			mi.material_override = mat
			add_child(mi)
			set[pair[0]] = mm
		_tree_mm[kind] = set
	for t in land.trees:
		var set: Dictionary = _tree_mm[t.kind]
		var k: int = _tree_slot[t.i]
		var p: Vector3 = t.pos
		var shade := fposmod(p.x * 0.13 + p.z * 0.29, 1.0) * 0.25
		set.trunk.set_instance_color(k, Color("#8a6040").lightened(shade * 0.5))
		var leaf: Color = {"oak": Color("#3f8f3c"), "pine": Color("#2e6a3a"), "fruit": Color("#5aa84a")}[t.kind]
		set.crown.set_instance_color(k, leaf.lightened(shade))
		if set.has("crown2"):
			set.crown2.set_instance_color(k, leaf.lightened(shade + 0.08))
	# Плоды на плодовых деревьях — одна сетка на все; которых нет — сжаты в точку.
	var fm := SphereMesh.new()
	fm.radius = 0.2
	fm.height = 0.4
	fm.radial_segments = 8
	fm.rings = 4
	_fruit_mm = MultiMesh.new()
	_fruit_mm.transform_format = MultiMesh.TRANSFORM_3D
	_fruit_mm.mesh = fm
	var fruit_trees: Array = land.trees.filter(func(t): return t.kind == "fruit")
	_fruit_mm.instance_count = fruit_trees.size() * Land.TREE_FRUITS
	for j in fruit_trees.size():
		_fruit_slot[fruit_trees[j].i] = j * Land.TREE_FRUITS
	var fmi := MultiMeshInstance3D.new()
	fmi.multimesh = _fruit_mm
	fmi.material_override = Creature3D.mat(Color("#e8505a"), 0.4)
	add_child(fmi)

## Поставить дерево в сетку: качка shake (0 — стоит ровно). В твоём гнезде деревьев нет.
func _place_tree(t: Dictionary, shake: float) -> void:
	var set: Dictionary = _tree_mm[t.kind]
	var k: int = _tree_slot[t.i]
	var s: float = t.size
	var p: Vector3 = t.pos
	if land.has_nest and Vector2(p.x - land.home.x, p.z - land.home.z).length() < Land.NEST_R + 1.0:
		s = 0.0
	var tilt := Basis(Vector3(cos(t.i), 0, sin(t.i)).normalized(), shake * 0.12)
	var up := Vector3.UP * s
	var cs := 0.0 if _hidden_crowns.has(t.i) else s
	set.trunk.set_instance_transform(k, Transform3D(tilt * Basis().scaled(Vector3.ONE * s), p + tilt * (up * 1.2)))
	if t.kind == "pine":
		set.crown.set_instance_transform(k, Transform3D(tilt * Basis().scaled(Vector3(cs, cs * 1.1, cs)), p + tilt * (up * 2.9)))
		set.crown2.set_instance_transform(k, Transform3D(tilt * Basis().scaled(Vector3(cs, cs, cs) * 0.75), p + tilt * (up * 4.1)))
	else:
		set.crown.set_instance_transform(k, Transform3D(tilt * Basis().scaled(Vector3.ONE * cs), p + tilt * (up * 3.3)))
	if t.kind == "fruit":
		var base: int = _fruit_slot[t.i]
		for f in Land.TREE_FRUITS:
			var a: float = TAU * f / Land.TREE_FRUITS + float(t.i)
			var q := Vector3(cos(a) * 1.55, 2.7 + 0.35 * (f % 3), sin(a) * 1.55) * s
			var there := f < int(t.fruits) and cs > 0.0
			_fruit_mm.set_instance_transform(base + f, Transform3D(Basis().scaled(Vector3.ONE * (1.0 if there else 0.0)), p + tilt * q))
		_fruit_seen[t.i] = int(t.fruits)

## Камни, трава и цветы — просто для вида: мир полнее, и видно, какой он большой.
func _decor() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(land.terrain.height(13.0, 17.0) * 1000.0) + 7
	var rock := SphereMesh.new()
	rock.radius = 1.0
	rock.height = 1.4
	rock.radial_segments = 6
	rock.rings = 3
	var tuft := CylinderMesh.new()
	tuft.top_radius = 0.0
	tuft.bottom_radius = 0.08
	tuft.height = 0.4
	tuft.radial_segments = 4
	tuft.rings = 1
	var bloom := SphereMesh.new()
	bloom.radius = 0.1
	bloom.height = 0.16
	bloom.radial_segments = 6
	bloom.rings = 3
	var flower_cols := [Color("#f4d03a"), Color("#f2ead8"), Color("#e890b8"), Color("#b08ae0"), Color("#e8742a")]
	var few := 0.4 if quality == "fast" else 1.0
	for spec in [[rock, int(220 * few), 0.4, 2.2], [tuft, int(3200 * few), 0.7, 1.4], [bloom, int(700 * few), 0.8, 1.3]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = spec[0]
		mm.instance_count = spec[1]
		for i in int(spec[1]):
			var p := Vector3.ZERO
			for tries in 6:
				var a := r.randf() * TAU
				var d := sqrt(r.randf()) * Terrain.RADIUS * 0.95
				p = Vector3(cos(a) * d, 0.0, sin(a) * d)
				var h := land.terrain.height(p.x, p.z)
				if h > 1.0 and (spec[0] == rock or h < 12.5):
					break
			p.y = land.terrain.height(p.x, p.z)
			var sc := r.randf_range(spec[2], spec[3])
			var col: Color
			var xf: Transform3D
			if spec[0] == rock:
				col = Color("#8f8a7c").lightened(r.randf() * 0.2)
				xf = Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(sc * 1.3, sc * 0.8, sc)), p + Vector3(0, 0.2 * sc, 0))
			elif spec[0] == tuft:
				col = Color("#4f9a44").lerp(Color("#8ac860"), r.randf())
				xf = Transform3D(Basis(Vector3(r.randf() - 0.5, 0, r.randf() - 0.5).normalized(), r.randf() * 0.3).scaled(Vector3.ONE * sc), p + Vector3(0, 0.3 * sc, 0))
			else:
				col = flower_cols[r.randi() % flower_cols.size()]
				xf = Transform3D(Basis().scaled(Vector3.ONE * sc), p + Vector3(0, 0.25, 0))
			mm.set_instance_transform(i, xf)
			mm.set_instance_color(i, col)
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 1.0
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

## Густая трава рядом: каждая травинка стоит на своём месте сетки, так что при переезде
## пятна трава не «плывёт».
func _sync_grass() -> void:
	if quality == "fast":
		return
	if _near_grass == null:
		var tuft := CylinderMesh.new()
		tuft.top_radius = 0.0
		tuft.bottom_radius = 0.05
		tuft.height = 0.32
		tuft.radial_segments = 3
		tuft.rings = 1
		_near_grass = MultiMesh.new()
		_near_grass.transform_format = MultiMesh.TRANSFORM_3D
		_near_grass.use_colors = true
		_near_grass.mesh = tuft
		_near_grass.instance_count = GRASS_N
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = _near_grass
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 1.0
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	if Vector2(land.pos.x - _grass_at.x, land.pos.z - _grass_at.z).length() < 6.0:
		return
	_grass_at = land.pos
	var step := GRASS_R * 2.0 / sqrt(float(GRASS_N))
	var side := int(sqrt(float(GRASS_N)))
	var ox := floorf((land.pos.x - GRASS_R) / step)
	var oz := floorf((land.pos.z - GRASS_R) / step)
	for i in GRASS_N:
		var gx := ox + float(i % side)
		var gz := oz + float(i / side)
		# Своё случайное смещение у каждой клетки сетки — одно и то же всегда.
		var hsh := fposmod(sin(gx * 12.9898 + gz * 78.233) * 43758.5453, 1.0)
		var hsh2 := fposmod(sin(gx * 39.346 + gz * 11.135) * 24634.6345, 1.0)
		var p := Vector3((gx + hsh) * step, 0.0, (gz + hsh2) * step)
		var h := land.terrain.height(p.x, p.z)
		var ok := h > 1.0 and h < 12.5 and not (land.has_nest and Vector2(p.x - land.home.x, p.z - land.home.z).length() < Land.NEST_R)
		var sc := (0.6 + hsh * 0.6) if ok else 0.0
		_near_grass.set_instance_transform(i, Transform3D(Basis(Vector3(hsh2 - 0.5, 0, hsh - 0.5).normalized(), hsh * 0.35).scaled(Vector3.ONE * sc), Vector3(p.x, h + 0.2 * sc, p.z)))
		_near_grass.set_instance_color(i, Color("#6cb456").lerp(Color("#8cc866"), hsh2))

## Крона между камерой и тобой — прячется, чтобы не загораживать.
func _sync_occlusion() -> void:
	var cam := camera.global_position
	var me := land.pos + Vector3(0, 1.0, 0)
	var mid := (cam + me) / 2.0
	var hide := {}
	for t in land.trees_near(mid, cam.distance_to(me) / 2.0 + 4.0):
		var s: float = t.size
		var crown_at: Vector3 = (t.pos as Vector3) + Vector3(0, (4.1 if t.kind == "pine" else 3.3) * s * 0.85, 0)
		# Ближайшая к кроне точка на отрезке от тебя до камеры.
		var ab := cam - me
		var k := clampf((crown_at - me).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if k > 0.05 and crown_at.distance_to(me + ab * k) < 1.6 * s:
			hide[t.i] = true
	var changed := false
	for i in hide:
		if not _hidden_crowns.has(i):
			_hidden_crowns[i] = true
			_place_tree(land.trees[i], 0.0)
	for i in _hidden_crowns.keys():
		if not hide.has(i):
			_hidden_crowns.erase(i)
			_place_tree(land.trees[i], 0.0)

## Деревья, которые ударили, качаются; у плодовых — сколько плодов висит.
func _sync_trees() -> void:
	for t in land.trees:
		if t.hit > 0.0:
			_shaking[t.i] = true
	for i in _shaking.keys():
		var t: Dictionary = land.trees[i]
		_place_tree(t, sin(land.time * 30.0) * float(t.hit))
		if t.hit <= 0.0:
			_shaking.erase(i)
	for t in land.trees:
		if t.kind == "fruit" and int(_fruit_seen.get(t.i, -1)) != int(t.fruits) and not _shaking.has(t.i):
			_place_tree(t, 0.0)

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
		var node := _nest_ring(twig, twig2)
		node.position = n.pos
		add_child(node)
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
		# Запасы стаи: плоды или мясо рядом с гнездом.
		var plant: bool = LandSpecies.SPECIES[n.sp].diet == "plant"
		var fmat := Creature3D.mat(Color("#e8505a") if plant else Color("#8a3a34"), 0.5)
		var food: Array = []
		for i in Land.FOOD_MAX:
			var f := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.2 if plant else 0.26
			sm.height = sm.radius * (2.0 if plant else 1.3)
			sm.radial_segments = 8
			sm.rings = 4
			f.mesh = sm
			f.material_override = fmat
			var a := TAU * i / Land.FOOD_MAX + 1.1
			f.position = Vector3(cos(a) * 1.9, 0.2 + 0.18 * (i % 2), sin(a) * 1.9)
			node.add_child(f)
			food.append(f)
		_nest_food.append(food)

## Кольцо из веток — основа гнезда. k — во сколько раз больше.
func _nest_ring(twig: Material, twig2: Material, k := 1.0) -> Node3D:
	var node := Node3D.new()
	node.scale = Vector3.ONE * k
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
	return node

## Своё гнездо: побольше, из твоих цветов; над ним — столб света, чтобы найти издалека.
func _make_own_nest() -> void:
	var pt := land.evo.paint()
	var c := Color(LandParts.COLORS[pt.color])
	_own = _nest_ring(Creature3D.mat(c.darkened(0.35), 1.0), Creature3D.mat(Color("#8a6a44"), 1.0), 1.6)
	add_child(_own)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = Land.NEST_R - 0.15
	tm.outer_radius = Land.NEST_R + 0.15
	tm.rings = 32
	tm.ring_segments = 4
	ring.mesh = tm
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(1.0, 0.9, 0.5, 0.45)
	ring.material_override = glow
	ring.position.y = 0.1
	ring.scale = Vector3.ONE / 1.6
	_own.add_child(ring)
	_beacon = MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.5
	bm.bottom_radius = 0.9
	bm.height = 40.0
	bm.radial_segments = 10
	bm.cap_top = false
	bm.cap_bottom = false
	_beacon.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bmat.albedo_color = Color(1.0, 0.92, 0.6, 0.18)
	_beacon.material_override = bmat
	_beacon.position.y = 20.0
	add_child(_beacon)
	# Яйца и запасы своего гнезда.
	var egg := Creature3D.mat(c.lightened(0.55), 0.5)
	for i in Land.MAX_ALLY:
		var e := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.3
		em.height = 0.8
		em.radial_segments = 10
		em.rings = 6
		e.mesh = em
		e.material_override = egg
		var a := TAU * i / Land.MAX_ALLY
		e.position = Vector3(cos(a) * 0.5, 0.45, sin(a) * 0.5) / 1.6
		e.scale = Vector3.ONE / 1.6
		_own.add_child(e)
		_own_eggs.append(e)
	var fr := Creature3D.mat(Color("#e8505a"), 0.4)
	for i in Land.STASH_MAX:
		var f := MeshInstance3D.new()
		var fm := SphereMesh.new()
		fm.radius = 0.2
		fm.height = 0.4
		fm.radial_segments = 8
		fm.rings = 4
		f.mesh = fm
		f.material_override = fr
		var a := TAU * i / 7.0 + 0.3
		var rr := 2.6 + 0.45 * float(i / 7)
		f.position = Vector3(cos(a) * rr, 0.2, sin(a) * rr) / 1.6
		f.scale = Vector3.ONE / 1.6
		_own.add_child(f)
		_own_food.append(f)

## Окаменелость: камень с золотой ракушкой-спиралью, светится.
func _make_relic(r: Dictionary) -> Node3D:
	var node := Node3D.new()
	node.position = r.pos
	var inner := Node3D.new()
	inner.name = "Inner"
	node.add_child(inner)
	var stone := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 1.6
	sm.radial_segments = 7
	sm.rings = 4
	stone.mesh = sm
	stone.material_override = Creature3D.mat(Color("#8f8474"), 0.95)
	stone.position.y = 0.55
	stone.scale = Vector3(1.0, 1.0, 0.8)
	inner.add_child(stone)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("#f0c050")
	gold.emission_enabled = true
	gold.emission = Color("#ffb830")
	gold.emission_energy_multiplier = 1.2
	gold.roughness = 0.3
	# Спираль ракушки: шарики всё мельче по кругу.
	for i in 14:
		var a := i * 0.62
		var rr := 0.5 * (1.0 - i / 16.0)
		var dot := MeshInstance3D.new()
		var dm := SphereMesh.new()
		dm.radius = 0.12 * (1.0 - i / 18.0)
		dm.height = dm.radius * 2.0
		dm.radial_segments = 6
		dm.rings = 3
		dot.mesh = dm
		dot.material_override = gold
		dot.position = Vector3(cos(a) * rr, 0.6 + sin(a) * rr, 0.78)
		inner.add_child(dot)
	var col := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.15
	cm.bottom_radius = 0.35
	cm.height = 9.0
	cm.radial_segments = 8
	cm.cap_top = false
	cm.cap_bottom = false
	col.mesh = cm
	var cmat := StandardMaterial3D.new()
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cmat.albedo_color = Color(1.0, 0.75, 0.3, 0.22)
	col.material_override = cmat
	col.position.y = 5.0
	col.name = "Glow"
	node.add_child(col)
	return node

## Туша: тёмный бугор и торчащие рёбра. Чем меньше мяса — тем меньше.
func _make_carcass(cc: Dictionary) -> Node3D:
	var node := Node3D.new()
	node.position = cc.pos
	var s: float = cc.get("size", 1.0)
	var meat := MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 0.6 * s
	mm.height = 0.7 * s
	mm.radial_segments = 8
	mm.rings = 4
	meat.mesh = mm
	meat.material_override = Creature3D.mat(Color("#8a3a34"), 0.7)
	meat.position.y = 0.2 * s
	meat.scale = Vector3(1.0, 1.0, 1.5)
	meat.name = "Meat"
	node.add_child(meat)
	var bone := Creature3D.mat(Color("#ece2c8"), 0.6)
	for i in 3:
		var rib := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.04 * s
		rm.bottom_radius = 0.05 * s
		rm.height = 0.7 * s
		rm.radial_segments = 5
		rib.mesh = rm
		rib.material_override = bone
		rib.position = Vector3(0, 0.45 * s, (i - 1) * 0.3 * s)
		rib.rotation.z = 0.5
		node.add_child(rib)
	return node

## Окаменелости и туши: новые — построить, пропавшие — убрать.
func _sync_things() -> void:
	var seen := {}
	for r in land.relics:
		seen[r.i] = true
		var n: Node3D = _relics.get(r.i)
		if n == null:
			n = _make_relic(r)
			add_child(n)
			_relics[r.i] = n
		n.visible = (r.pos as Vector3).distance_to(land.pos) < DRAW_DIST + 40.0
		var inner := n.get_node("Inner") as Node3D
		inner.position.x = sin(land.time * 60.0) * 0.08 * float(r.hit)
		inner.scale = Vector3.ONE * (0.75 + 0.25 * float(r.hp) / float(r.max_hp))
	for i in _relics.keys():
		if not seen.has(i):
			(_relics[i] as Node3D).queue_free()
			_relics.erase(i)
	seen = {}
	for cc in land.carcasses:
		seen[cc.uid] = true
		var n: Node3D = _carcasses.get(cc.uid)
		if n == null:
			n = _make_carcass(cc)
			add_child(n)
			_carcasses[cc.uid] = n
		(n.get_node("Meat") as Node3D).scale = Vector3(1.0, 1.0, 1.5) * (0.4 + 0.2 * float(cc.meat))
	for u in _carcasses.keys():
		if not seen.has(u):
			(_carcasses[u] as Node3D).queue_free()
			_carcasses.erase(u)

## Упавшие плоды: новые — положить, съеденные и сгнившие — убрать.
func _sync_drops() -> void:
	var seen := {}
	for d in land.drops:
		seen[d.uid] = true
		if not _drops.has(d.uid):
			var f := MeshInstance3D.new()
			var fm := SphereMesh.new()
			fm.radius = 0.2
			fm.height = 0.4
			fm.radial_segments = 8
			fm.rings = 4
			f.mesh = fm
			f.material_override = _drop_mat()
			f.position = (d.pos as Vector3) + Vector3(0, 0.18, 0)
			add_child(f)
			_drops[d.uid] = f
	for u in _drops.keys():
		if not seen.has(u):
			(_drops[u] as Node3D).queue_free()
			_drops.erase(u)

var _dmat: StandardMaterial3D
func _drop_mat() -> StandardMaterial3D:
	if _dmat == null:
		_dmat = Creature3D.mat(Color("#e8505a"), 0.4)
	return _dmat

## Свет по времени суток: днём солнце, на закате оранжево, ночью темно-синее и туман гуще.
func _daylight() -> void:
	if _sun == null:
		return
	var l := Land.daylight(land.day)
	var dusk := 4.0 * l * (1.0 - l)
	_sun.light_energy = lerpf(0.18, 1.0, l)
	_sun.light_color = Color("#8a9ad8").lerp(Color("#fff4e0"), l).lerp(Color("#ffb070"), dusk * 0.6)
	_sky.sky_top_color = Color("#0c1630").lerp(Color("#5fa8e0"), l)
	_sky.sky_horizon_color = Color("#23304e").lerp(Color("#cfe8f0"), l).lerp(Color("#f0a070"), dusk * 0.7)
	_sky.ground_horizon_color = _sky.sky_horizon_color
	_env.ambient_light_energy = lerpf(0.22, 0.4, l)
	_env.fog_light_color = Color("#1c2844").lerp(Color("#9fcbe6"), l)
	var w := land.weather
	var gloom := {"rain": 0.25, "storm": 0.45, "fog": 0.1}.get(w, 0.0) as float
	_sun.light_energy *= 1.0 - gloom
	_sky.sky_top_color = _sky.sky_top_color.lerp(Color("#5a6470"), gloom)
	_sky.sky_horizon_color = _sky.sky_horizon_color.lerp(Color("#8a929a"), gloom)
	_env.fog_density = _fog_base * lerpf(2.2, 1.0, l) * {"fog": 4.0, "rain": 1.6, "storm": 2.0}.get(w, 1.0)
	_env.fog_light_color = _env.fog_light_color.lerp(Color("#9aa4ae"), gloom * 1.5 if w == "fog" else gloom)
	# Молния — всё вспыхивает.
	if _flash_t > 0.0:
		_env.ambient_light_energy += _flash_t * 1.5
		_sun.light_energy += _flash_t * 1.2
	if _beacon:
		(_beacon.material_override as StandardMaterial3D).albedo_color.a = lerpf(0.35, 0.16, l)

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
		if m.kind == "ally" and cr != null and absf(float(_ally_size.get(m.uid, 0.0)) - float(m.size)) > 0.07:
			cr.queue_free()
			_mobs.erase(m.uid)
			_carry.erase(m.uid)
			cr = null
		if cr == null:
			cr = Creature3D.new()
			cr.ground = _ground_fn
			add_child(cr)
			if m.kind == "ally":
				_build_ally(cr, m)
			else:
				var look := LandSpecies.look(m.sp, m.get("leader", false))
				cr.build_body(Color(m.color), Color(m.color2), m.size, look.parts, look.pattern, look.shape)
			_mobs[m.uid] = cr
		var far: bool = (m.pos as Vector3).distance_to(land.pos) > _draw * (1.6 if m.kind == "giant" else 1.0)
		cr.visible = not far
		if far:
			continue
		cr.rest_to = 1.0 if m.get("sleep", false) else 0.0
		# Жуёт — бросок головой вперёд.
		if float(m.get("chomp", 0.0)) > 0.4 and not _chomped.get(m.uid, false):
			cr.lunge()
			_chomped[m.uid] = true
		elif float(m.get("chomp", 0.0)) <= 0.4:
			_chomped.erase(m.uid)
		cr.update(delta, m.pos, m.heading, m.vel)
		cr.flash(m.hit)
		cr.health(m.hp / m.max_hp)
		# Что несёт в пасти: плод или кусок мяса.
		var c: MeshInstance3D = _carry.get(m.uid)
		if m.carry != "" and c == null:
			c = MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.2
			sm.height = 0.4
			sm.radial_segments = 8
			sm.rings = 4
			c.mesh = sm
			cr.add_child(c)
			_carry[m.uid] = c
		if c:
			c.visible = m.carry != ""
			if c.visible:
				c.material_override = _drop_mat() if m.carry == "fruit" else _meat_mat()
				c.position = (cr.anchors.get("place:mouth", Vector3(0, 0.6, 0.8)) as Vector3) + Vector3(0, -0.15, 0.25) * float(m.size)
				c.scale = Vector3.ONE * float(m.size)
	for uid in _mobs.keys():
		if not seen.has(uid):
			(_mobs[uid] as Node3D).queue_free()
			_mobs.erase(uid)
			_carry.erase(uid)

var _mmat: StandardMaterial3D
func _meat_mat() -> StandardMaterial3D:
	if _mmat == null:
		_mmat = Creature3D.mat(Color("#8a3a34"), 0.7)
	return _mmat

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
		fx_event(e)
		match e.t:
			"bite", "pick":
				_player.lunge()
			"hurt":
				# Тебя кусили: ты белеешь, а кусачий бросается вперёд.
				_player.flash(1.0)
				if _mobs.has(e.uid):
					(_mobs[e.uid] as Creature3D).lunge()
		happened.emit(e)
	_player.flash(_player._flash - delta * 3.0)
	# Прыжок — дугой вверх; копаешь — клюёшь носом землю; плывёшь — на воде.
	var hop := sin(PI * (1.0 - land.jump_t / 0.45)) * 1.4 if land.jump_t > 0.0 else 0.0
	if land.dig_t > 0.0 and fmod(land.dig_t, 0.4) < 0.05:
		_player.lunge()
	_player.update(delta, land.pos + Vector3(0, hop, 0), land.heading, land.vel)
	_sync_mobs(delta)
	_sync_bones()
	_sync_things()
	_daylight()
	_own.visible = land.has_nest
	_beacon.visible = land.has_nest
	for i in _own_eggs.size():
		_own_eggs[i].visible = i < land.eggs.size()
		if i < land.eggs.size():
			# Скоро вылупится — покачивается.
			_own_eggs[i].rotation.z = sin(land.time * 12.0 + i) * 0.25 * clampf(1.0 - float(land.eggs[i]) / 10.0, 0.0, 1.0)
	for i in _own_food.size():
		_own_food[i].visible = i < land.stash
	_effects(delta)
	if land.has_nest:
		_own.position = land.home
		_beacon.position = land.home + Vector3(0, 20.0, 0)
	for i in _nests.size():
		var eggs: Array = _nests[i].eggs
		for j in eggs.size():
			eggs[j].visible = j < int(land.nests[i].eggs)
		var food: Array = _nest_food[i]
		for j in food.size():
			food[j].visible = j < int(land.nests[i].food)
	_sync_trees()
	_sync_drops()
	_sync_grass()
	_sync_occlusion()
	for i in _bushes.size():
		var fr: Array = _bushes[i].fruits
		for j in fr.size():
			fr[j].visible = j < int(land.bushes[i].fruits)
	_camera(delta)

# --- птицы, пыль, следы, погода, вспышки ----------------------------------------------

## Что показать на событие: молния, плевок, рёв, копание.
func fx_event(e: Dictionary) -> void:
	match e.t:
		"lightning":
			_bolt(e.pos)
		"spit":
			_shot(e.pos + Vector3(0, 0.8, 0), (e.to as Vector3) + Vector3(0, 0.6, 0))
		"roar":
			_ring(e.pos, Color(1.0, 0.85, 0.4, 0.5), 14.0)
			_player.lunge()
		"dig", "dig_start":
			_puff(e.pos, Color("#8a6a44"))

## Стайки птиц кружат над островом (ночью спят).
func _make_birds() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var wing := BoxMesh.new()
	wing.size = Vector3(0.7, 0.04, 0.22)
	var m := Creature3D.mat(Color("#3a3a44"), 0.9)
	for f in (2 if quality == "fast" else 4):
		var c := Vector3(r.randf_range(-150, 150), 0, r.randf_range(-150, 150))
		for k in 6:
			var b := Node3D.new()
			add_child(b)
			var wings: Array = []
			for side in [-1.0, 1.0]:
				var w := MeshInstance3D.new()
				w.mesh = wing
				w.material_override = m
				w.position.x = side * 0.32
				b.add_child(w)
				wings.append(w)
			_birds.append({"node": b, "c": c, "r": r.randf_range(18, 34), "h": r.randf_range(20, 30), "a": r.randf() * TAU,
				"speed": r.randf_range(0.25, 0.4) * (1 if f % 2 == 0 else -1), "wings": wings, "k": k})

## Пыль из-под ног и дождь (дождь — облако капель вокруг камеры).
func _make_particles() -> void:
	if quality == "fast":
		return
	_dust = CPUParticles3D.new()
	_dust.amount = 24
	_dust.lifetime = 0.8
	_dust.emitting = false
	_dust.direction = Vector3(0, 1, 0)
	_dust.spread = 60.0
	_dust.initial_velocity_min = 0.4
	_dust.initial_velocity_max = 1.2
	_dust.gravity = Vector3(0, -0.6, 0)
	_dust.scale_amount_min = 0.25
	_dust.scale_amount_max = 0.5
	var dm := SphereMesh.new()
	dm.radius = 0.2
	dm.height = 0.4
	dm.radial_segments = 6
	dm.rings = 3
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.72, 0.62, 0.45, 0.45)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.material = dmat
	_dust.mesh = dm
	add_child(_dust)
	_rain = CPUParticles3D.new()
	_rain.amount = 500
	_rain.lifetime = 0.9
	_rain.emitting = false
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(18, 1, 18)
	_rain.direction = Vector3(0.1, -1, 0)
	_rain.spread = 3.0
	_rain.initial_velocity_min = 22.0
	_rain.initial_velocity_max = 26.0
	_rain.gravity = Vector3.ZERO
	var rm := BoxMesh.new()
	rm.size = Vector3(0.025, 0.7, 0.025)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.75, 0.85, 1.0, 0.35)
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.material = rmat
	_rain.mesh = rm
	add_child(_rain)

func _effects(delta: float) -> void:
	# Птицы.
	var night := land.is_night()
	for b in _birds:
		b.a += delta * float(b.speed)
		var a: float = float(b.a) + float(b.k) * 0.35
		var c: Vector3 = b.c
		var n: Node3D = b.node
		n.visible = not night
		n.position = c + Vector3(cos(a) * float(b.r), float(b.h) + sin(a * 3.0) * 1.5, sin(a) * float(b.r))
		n.rotation.y = -a + (PI if float(b.speed) > 0.0 else 0.0)
		var flap := sin(land.time * 10.0 + float(b.k)) * 0.5
		(b.wings[0] as Node3D).rotation.z = flap
		(b.wings[1] as Node3D).rotation.z = -flap
	# Пыль и следы, когда бежишь.
	var fast := land.vel.length() > 4.0 and not land.swimming()
	if _dust:
		_dust.emitting = fast
		_dust.position = land.pos + Vector3(0, 0.15, 0)
	var h := land.terrain.height(land.pos.x, land.pos.z)
	if h < 1.3 and not land.swimming() and land.pos.distance_to(_print_at) > 0.9:
		_print_at = land.pos
		_print_side = -_print_side
		_footprint(land.pos + Vector3(land.forward().z, 0, -land.forward().x) * 0.3 * _print_side, land.heading)
	for p in _prints:
		p.t -= delta
		(p.node.material_override as StandardMaterial3D).albedo_color.a = clampf(p.t / 20.0, 0.0, 1.0) * 0.35
	# Дождь — вокруг камеры.
	var wet := land.weather in ["rain", "storm"]
	if _rain:
		_rain.emitting = wet
		_rain.position = camera.global_position + Vector3(0, 8, 0) - Vector3(sin(cam_yaw), 0, cos(cam_yaw)) * 6.0
	# Вспышки, плевки, кольца.
	for f in _fx:
		f.t += delta
		var k: float = f.t / f.life
		var n: Node3D = f.node
		match f.kind:
			"shot":
				n.position = (f.from as Vector3).lerp(f.to, k) + Vector3(0, sin(PI * k) * 1.2, 0)
			"ring":
				n.scale = Vector3(1, 1, 1) * lerpf(0.5, float(f.r), k)
				(n.material_override as StandardMaterial3D).albedo_color.a = 0.5 * (1.0 - k)
			"bolt", "puff":
				(n.material_override as StandardMaterial3D).albedo_color.a = (1.0 - k) * (0.9 if f.kind == "bolt" else 0.6)
				if f.kind == "puff":
					n.scale = Vector3.ONE * (0.5 + k * 1.5)
		if f.t >= f.life:
			n.queue_free()
	_fx = _fx.filter(func(f): return f.t < f.life)
	_flash_t = maxf(0.0, _flash_t - delta * 3.0)

func _footprint(at: Vector3, yaw: float) -> void:
	var p: Dictionary
	if _prints.size() < 40:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.28, 0.4)
		qm.orientation = PlaneMesh.FACE_Y
		q.mesh = qm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.35, 0.28, 0.18, 0.35)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		q.material_override = m
		add_child(q)
		p = {"node": q, "t": 20.0}
		_prints.append(p)
	else:
		p = _prints.pop_front()
		_prints.append(p)
		p.t = 20.0
	(p.node as Node3D).position = Vector3(at.x, land.terrain.height(at.x, at.z) + 0.03, at.z)
	(p.node as Node3D).rotation.y = yaw

func _fx_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

## Молния: столб света с неба в точку и вспышка всего вокруг.
func _bolt(at: Vector3) -> void:
	var n := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.15
	cm.bottom_radius = 0.35
	cm.height = 60.0
	cm.radial_segments = 6
	n.mesh = cm
	n.material_override = _fx_mat(Color(0.95, 0.95, 1.0, 0.9))
	n.position = at + Vector3(0, 30, 0)
	add_child(n)
	_fx.append({"node": n, "t": 0.0, "life": 0.25, "kind": "bolt"})
	_flash_t = 1.0

## Плевок: зелёный комок летит дугой.
func _shot(from: Vector3, to: Vector3) -> void:
	var n := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.18
	sm.height = 0.36
	n.mesh = sm
	n.material_override = _fx_mat(Color(0.7, 0.95, 0.25, 0.95))
	add_child(n)
	_fx.append({"node": n, "t": 0.0, "life": 0.35, "kind": "shot", "from": from, "to": to})

## Рёв: кольцо расходится по земле.
func _ring(at: Vector3, c: Color, r: float) -> void:
	var n := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	tm.rings = 32
	tm.ring_segments = 4
	n.mesh = tm
	n.material_override = _fx_mat(c)
	n.position = at + Vector3(0, 0.3, 0)
	add_child(n)
	_fx.append({"node": n, "t": 0.0, "life": 0.6, "kind": "ring", "r": r})

## Облачко земли (копаешь).
func _puff(at: Vector3, c: Color) -> void:
	var n := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 0.6
	sm.radial_segments = 8
	sm.rings = 4
	n.mesh = sm
	n.material_override = _fx_mat(Color(c, 0.6))
	n.position = at + Vector3(0, 0.3, 0) + Vector3(sin(land.heading), 0, cos(land.heading)) * 0.8
	add_child(n)
	_fx.append({"node": n, "t": 0.0, "life": 0.6, "kind": "puff"})

func _camera(delta: float) -> void:
	cam_touch_t += delta
	# Бежишь вперёд (джойстик вверх), камеру давно не трогали — она сама заходит за спину.
	if cam_touch_t > 2.5 and input.y < -0.5 and absf(input.x) < 0.45 and land.vel.length() > 1.0:
		cam_yaw = lerp_angle(cam_yaw, land.heading + PI, 1.0 - exp(-0.9 * delta))
	var pose := _cam_pose(delta)
	camera.global_position = camera.global_position.lerp(pose[0], 1.0 - exp(-7.0 * delta))
	camera.look_at(pose[1], Vector3.UP)

## Где камера и куда смотрит: позади и чуть выше, смотрит немного вперёд по ходу; холмы
## её не закрывают (поднимается над землёй).
func _cam_pose(delta := 0.0) -> Array:
	var dist := _cam_dist()
	var lead := Vector3(land.vel.x, 0, land.vel.z) * 0.35
	_look_ahead = _look_ahead.lerp(lead, 1.0 - exp(-3.0 * delta)) if delta > 0.0 else lead
	var target := land.pos + Vector3(0, 1.1 + 0.25 * (float(_player.height()) if _player else 1.0), 0) + _look_ahead
	var back := Vector3(sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), cos(cam_yaw) * cos(cam_pitch))
	var want := target + back * dist
	var ground := land.terrain.height(want.x, want.z) + 1.0
	if want.y < ground:
		want.y = ground
	# Холм между тобой и камерой — камера поднимается, чтобы видеть.
	for k in [0.35, 0.7]:
		var q := target.lerp(want, k)
		var g := land.terrain.height(q.x, q.z) + 0.7
		if q.y < g:
			want.y += (g - q.y) / k
	return [want, target]
