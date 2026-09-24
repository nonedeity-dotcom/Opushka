## Мир на экране: земля, то, что на ней стоит, персонаж, ночь, свет и частицы.
##
## Правила живут в Village; этот узел только показывает их и ничего не решает сам.
extends Node2D

const GroundChunk := preload("res://scripts/world/ground_chunk.gd")
const CellObject := preload("res://scripts/world/cell_object.gd")
const PlayerView := preload("res://scripts/world/player_view.gd")
const AnimalView := preload("res://scripts/world/animal_view.gd")
const Critters := preload("res://scripts/world/critters.gd")

var village: Village
var objects: Node2D
var player: Node2D
var camera: Camera2D
var night_tint: CanvasModulate
var marker: Node2D
var _nodes := {}  # Vector2i → узел клетки
var _lights := {}  # Vector2i → PointLight2D
var _animals := {}  # Animals.Animal → AnimalView
var critters: Node2D
var _light_texture: Texture2D
var show_target := true


func build(v: Village) -> void:
	village = v
	for child in get_children():
		child.queue_free()
	_nodes.clear()
	_lights.clear()
	_animals.clear()
	var w := v.world()

	var ground := Node2D.new()
	ground.name = "Ground"
	add_child(ground)
	for cy in range(0, WorldGen.SIZE, GroundChunk.CHUNK):
		for cx in range(0, WorldGen.SIZE, GroundChunk.CHUNK):
			var chunk := GroundChunk.new()
			chunk.setup(w, Vector2i(cx, cy))
			ground.add_child(chunk)

	marker = Marker.new()
	add_child(marker)

	objects = Node2D.new()
	objects.name = "Objects"
	objects.y_sort_enabled = true
	add_child(objects)
	for y in WorldGen.SIZE:
		for x in WorldGen.SIZE:
			var c := Vector2i(x, y)
			if w.nature[y * WorldGen.SIZE + x] != "" or v.built.has(Village.key(c)):
				_node_at(c)

	player = PlayerView.new()
	objects.add_child(player)

	# Светлячки и бабочки — на своём слое, который движется вместе с миром: ночное
	# затемнение их не касается, и светлячки светятся в темноте.
	var glow := CanvasLayer.new()
	glow.layer = 1
	glow.follow_viewport_enabled = true
	add_child(glow)
	critters = Critters.new()
	glow.add_child(critters)

	night_tint = CanvasModulate.new()
	add_child(night_tint)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	# Чуть ближе, чем один к одному: около девяти клеток по ширине телефона.
	camera.zoom = Vector2(1.2, 1.2)
	camera.limit_left = int(-Art.TILE * 2)
	camera.limit_top = int(-Art.TILE * 2)
	camera.limit_right = int(Art.TILE * (WorldGen.SIZE + 2))
	camera.limit_bottom = int(Art.TILE * (WorldGen.SIZE + 2))
	add_child(camera)

	var grad := Gradient.new()
	grad.set_color(0, Color(1, 0.85, 0.6, 1))
	grad.set_color(1, Color(1, 0.6, 0.3, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	_light_texture = tex

	sync_all()
	player.place_at(v.pos, v.facing, 0.0)
	camera.position = player.position
	camera.reset_smoothing()


func _node_at(c: Vector2i) -> Node2D:
	if _nodes.has(c):
		return _nodes[c]
	var n := CellObject.new()
	n.setup(c, WorldGen.variant(village.seed, c.x, c.y))
	objects.add_child(n)
	_nodes[c] = n
	return n

## Привести одну клетку к тому, что говорят правила.
func sync_cell(c: Vector2i) -> void:
	var info := village.cell(c)
	if info.is_empty():
		return
	var night := village.is_night()
	if info.nature == "" and info.built == "":
		if _nodes.has(c):
			_nodes[c].queue_free()
			_nodes.erase(c)
	else:
		_node_at(c).sync(info, night)
	_sync_light(c, info)

func _sync_light(c: Vector2i, info: Dictionary) -> void:
	var s: String = info.get("built", "")
	var wants: bool = s != "" and Content.STRUCTURES[s].has("light")
	if wants and not _lights.has(c):
		var l := PointLight2D.new()
		l.texture = _light_texture
		l.position = (Vector2(c) + Vector2(0.5, 0.5)) * Art.TILE
		# Текстура — круг радиусом 128 точек; нужен радиус в столько-то клеток.
		l.texture_scale = float(Content.STRUCTURES[s].light) * Art.TILE / 128.0
		l.color = Color(1, 0.8, 0.55)
		add_child(l)
		_lights[c] = l
	elif not wants and _lights.has(c):
		_lights[c].queue_free()
		_lights.erase(c)

## Всё сразу: после сна, загрузки, смены дня и ночи. Мир маленький — это быстро.
func sync_all() -> void:
	for k in village.built:
		var p: PackedStringArray = k.split(":")
		sync_cell(Vector2i(int(p[0]), int(p[1])))
	for c in _nodes.keys():
		sync_cell(c)

## Раз в секунду: не отросло ли что-нибудь. Смотрим только собранные клетки — их немного.
func sync_regrowth() -> void:
	# Грядки и курятники меняются со временем сами: растёт, несутся.
	for k in village.built:
		if village.built[k] == "bed" or village.built[k] == "coop":
			var p: PackedStringArray = k.split(":")
			var c := Vector2i(int(p[0]), int(p[1]))
			if _nodes.has(c):
				_nodes[c].sync(village.cell(c), village.is_night())
	for k in village.used:
		var p: PackedStringArray = k.split(":")
		var c := Vector2i(int(p[0]), int(p[1]))
		if _nodes.has(c):
			_nodes[c].sync(village.cell(c), village.is_night())


func update_view(moved: float) -> void:
	player.place_at(village.pos, village.facing, moved)
	camera.position = player.position
	var d := village.darkness()
	night_tint.color = Color(1, 1, 1).lerp(Color(0.32, 0.36, 0.55), d * 0.9)
	for c in _lights:
		_lights[c].energy = d * 1.1
		_lights[c].visible = d > 0.02
	var label := village.action_label()
	var animal := village._animal_for_button()
	marker.visible = show_target and label != "" and animal == null
	if marker.visible:
		marker.position = Vector2(village.target()) * Art.TILE
	_sync_animals(animal)
	critters.update(village, camera.get_screen_center_position(), d)


func _sync_animals(near: Animals.Animal) -> void:
	if village.animals == null:
		return
	var alive := {}
	for a in village.animals.list:
		alive[a] = true
		var view: Node2D = _animals.get(a)
		if view == null:
			view = AnimalView.new()
			view.animal = a
			objects.add_child(view)
			_animals[a] = view
		view.refresh(a == near)
	for a in _animals.keys():
		if not alive.has(a):
			_animals[a].queue_free()
			_animals.erase(a)

## Сердечки над зверем — покормил или погладил.
func hearts(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = at * Art.TILE + Vector2(0, -Art.TILE * 0.6)
	p.one_shot = true
	p.explosiveness = 0.6
	p.amount = 5
	p.lifetime = 1.2
	p.direction = Vector2(0, -1)
	p.spread = 35.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 60.0
	p.gravity = Vector2.ZERO
	var img := Image.create(24, 22, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 22:
		for x in 24:
			var u := (x - 12) / 9.5
			var w := (y - 11.5) / 9.5
			# Сердце по формуле: (x²+y²−1)³ − x²y³ ≤ 0.
			var q := u * u + w * w - 1.0
			if q * q * q - u * u * (-w) * (-w) * (-w) <= 0.0:
				img.set_pixel(x, y, Color("#e0788a"))
	p.texture = ImageTexture.create_from_image(img)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	p.z_index = 6
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Мир под пальцем: из точки экрана в клетку.
func cell_at_screen(screen: Vector2) -> Vector2i:
	var world_point := get_canvas_transform().affine_inverse() * screen
	return Vector2i(floori(world_point.x / Art.TILE), floori(world_point.y / Art.TILE))


## Щепки, листья, ягодный сок, искры — короткая россыпь на клетке.
func burst(c: Vector2i, kind: String) -> void:
	if _nodes.has(c):
		_nodes[c].hit()
	var colors: Array
	var amount := 14
	match kind:
		"chop":
			colors = [Color("#a5845a"), Color("#6b4b2e"), Color("#4f8a59")]
			amount = 18
		"stone":
			colors = [Color("#999ea5"), Color("#747980")]
			amount = 20
		"berries":
			colors = [Color("#c9566a"), Color("#4a8756")]
		"twig", "pebble":
			colors = [Color("#8a6440"), Color("#8f949b")]
			amount = 8
		"dig", "plant":
			colors = [Color("#6b4b2e"), Color("#4f9a55")]
			amount = 12
		"pour":
			colors = [Color("#a9cfe0"), Color("#4d7d94")]
			amount = 16
		"harvest":
			colors = [Color("#e8873a"), Color("#f2c23a"), Color("#5fae62")]
			amount = 18
		"cluck":
			colors = [Color("#f2ece0"), Color("#e0c070")]
			amount = 8
		"place", "craft", "pickup":
			colors = [Color("#e8e6e0"), Color("#a5845a")]
			amount = 12
		"sleep", "goal":
			colors = [Art.GOLD, Color("#fff4d6")]
			amount = 24
		_:
			return
	var p := CPUParticles2D.new()
	p.position = (Vector2(c) + Vector2(0.5, 0.45)) * Art.TILE
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = 0.7
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 150.0
	p.gravity = Vector2(0, 320)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	var g := Gradient.new()
	g.set_color(0, colors[0])
	g.set_color(1, Color(colors[-1], 0.0))
	p.color_ramp = g
	p.z_index = 5
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Рамка вокруг клетки, к которой относится кнопка действия.
class Marker:
	extends Node2D

	func _draw() -> void:
		var r := Rect2(Vector2(3, 3), Vector2(Art.TILE - 6, Art.TILE - 6))
		draw_rect(r, Color(0.95, 0.76, 0.42, 0.08))
		draw_rect(r, Color(0.95, 0.76, 0.42, 0.75), false, 2.5)
