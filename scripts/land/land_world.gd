## Суша на экране: остров, вода, небо, деревья, кусты с плодами, ты и соседи, камера.
## Камера — сверху под углом, следует за тобой; её можно повернуть пальцем.
class_name LandWorld
extends Node3D

signal ate

var land: Land
var input := Vector2.ZERO  # джойстик: x — вправо, y — вниз по экрану
var cam_yaw := 0.0
var camera: Camera3D
var _player: Creature3D
var _npcs: Array = []
var _bushes: Array = []  # [{node, fruits: [MeshInstance3D]}]

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
	# Ты — цвета своего вида. Соседи — свои цвета и ноги.
	var ground_fn := func(x: float, z: float) -> float: return land.terrain.height(x, z)
	_player = Creature3D.new()
	_player.ground = ground_fn
	add_child(_player)
	var c := Color(Content.COLORS[evo.color])
	_player.build(c, Color(Content.COLORS[evo.color2]) if evo.pattern != "none" else c.darkened(0.25), 1.0, 4)
	for n in l.npcs:
		var cr := Creature3D.new()
		cr.ground = ground_fn
		add_child(cr)
		var nc := Color(n.color)
		cr.build(nc, nc.darkened(0.3), n.size, n.legs)
		_npcs.append(cr)
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

func _process(delta: float) -> void:
	if land == null:
		return
	# Джойстик — относительно камеры: «вверх» — от камеры вглубь экрана.
	var fwd := Vector2(sin(cam_yaw), cos(cam_yaw)) * -1.0
	var right := Vector2(-fwd.y, fwd.x)
	var dir := right * input.x - fwd * input.y
	land.step(minf(delta, 0.05), dir)
	for e in land.events:
		if e.t == "eat":
			ate.emit()
	_player.update(delta, land.pos, land.heading, land.vel)
	for i in _npcs.size():
		var n: Dictionary = land.npcs[i]
		(_npcs[i] as Creature3D).update(delta, n.pos, n.heading, n.vel)
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
