## «Опушка» — спокойная игра про лес и деревню.
##
## Этот узел связывает всё: правила (Village), мир на экране (WorldView), интерфейс (Hud,
## сумка, настройки), звуки и сохранение. Сам он ничего не решает — только передаёт.
##
## Время идёт только от действий: пока стоишь, в мире ничего не происходит. Сохраняется само,
## через пару секунд после перемен и при сворачивании игры.
extends Node2D

const WorldView := preload("res://scripts/world/world_view.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const BagPanel := preload("res://scripts/ui/bag_panel.gd")
const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")
const SoundBank := preload("res://scripts/sound_bank.gd")

const SAVE_PATH := "user://save.json"
## Как далеко идти между звуками шагов, в клетках.
const STEP_SOUND_EVERY := 0.55
## Короче этого (в точках и секундах) касание считается нажатием, а не мазком.
const TAP_SLOP := 24.0
const TAP_TIME := 0.4

var village: Village
var settings: Settings
var world: Node2D
var hud: Control
var bag: Control
var setup: Control
var sound: Node
var landscape := false

var _route: Array[Vector2i] = []
var _route_face := Vector2i.ZERO
var _stuck := 0.0
var _step_acc := 0.0
var _was_night := false
var _dirty := false
var _save_in := 0.0
var _regrow_in := 1.0
var _touch_start := {}
var _script: Array = []  # сценарий для проверки — только из командной строки
var _script_wait := 0
var _script_pad := Vector2.ZERO


func _ready() -> void:
	settings = Settings.load_saved()
	var fresh := false
	village = _load()
	if village == null:
		village = Village.create(randi() & 0x7FFFFFFF)
		fresh = true
	_apply_debug_args()

	world = WorldView.new()
	add_child(world)
	world.build(village)

	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.theme = Kit.theme()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)

	hud = Hud.new()
	ui.add_child(hud)
	hud.act_pressed.connect(_act)
	hud.bag_pressed.connect(_open_bag)
	hud.settings_pressed.connect(_open_settings)
	hud.rotate_pressed.connect(func():
		settings.landscape = not landscape
		_settings_changed(settings))
	hud.eat_pressed.connect(func(): _handle(village.eat("berries")))
	hud.pickup_pressed.connect(func(): _handle(village.pick_up()))

	bag = BagPanel.new()
	bag.visible = false
	ui.add_child(bag)
	bag.closed.connect(func(): bag.visible = false)
	bag.eat.connect(func(id):
		_handle(village.eat(id))
		bag.rebuild())
	bag.place.connect(func(id):
		bag.visible = false
		_handle(village.place(id)))
	bag.craft.connect(func(id):
		_handle(village.craft(id))
		bag.rebuild())

	setup = SettingsPanel.new()
	setup.visible = false
	ui.add_child(setup)
	setup.closed.connect(func(): setup.visible = false)
	setup.changed.connect(_settings_changed)
	setup.new_world.connect(_new_world)

	sound = SoundBank.new()
	add_child(sound)
	sound.configure(settings)

	_orient()
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()
	_was_night = village.is_night()
	sound.set_ambience("night" if _was_night else "day")
	if fresh:
		hud.toast("Утро на опушке. Ветки и камешки лежат рядом — наступи на них")


# --- кадр -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	_run_script()
	var moved := 0.0
	var panels := bag.visible or setup.visible
	var v: Vector2 = hud.pad.vector if _script_pad == Vector2.ZERO else _script_pad
	if not panels and v.length() > 0.01:
		_route.clear()
		var out := village.walk(v * Settings.SPEED[settings.speed] * delta)
		moved = out.get("moved", 0.0)
		_handle(out)
	elif not panels and not _route.is_empty():
		moved = _follow(delta)

	world.update_view(moved)
	if moved > 0.0:
		_dirty = true
		_step_acc += moved
		if _step_acc >= STEP_SOUND_EVERY:
			_step_acc = 0.0
			sound.play("step")

	var night := village.is_night()
	if night != _was_night:
		_was_night = night
		world.sync_all()
		sound.set_ambience("night" if night else "day")

	_regrow_in -= delta
	if _regrow_in <= 0.0:
		_regrow_in = 1.0
		world.sync_regrowth()

	hud.refresh(village)

	if _dirty:
		_save_in = 2.0
		_dirty = false
	if _save_in > 0.0:
		_save_in -= delta
		if _save_in <= 0.0:
			_save()

## Идти по дороге, проложенной касанием: к середине следующей клетки, потом дальше.
func _follow(delta: float) -> float:
	var goal := Vector2(_route[0]) + Vector2(0.5, 0.5)
	var to := goal - village.pos
	var step: float = Settings.SPEED[settings.speed] * delta
	var out := village.walk(to.limit_length(step))
	var moved: float = out.get("moved", 0.0)
	_handle(out)
	if village.pos.distance_to(goal) < 0.08:
		_route.pop_front()
		_stuck = 0.0
	elif moved < 0.0001:
		# Упёрся — дорога устарела (что-то выросло или построено). Бросаем, а не топчемся.
		_stuck += delta
		if _stuck > 0.4:
			_route.clear()
			_stuck = 0.0
	if _route.is_empty() and _route_face != Vector2i.ZERO:
		village.face(Vector2(_route_face))
		_route_face = Vector2i.ZERO
	return moved


# --- касания карты --------------------------------------------------------------------

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			_touch_start[e.index] = [e.position, Time.get_ticks_msec()]
		elif _touch_start.has(e.index):
			var start: Array = _touch_start[e.index]
			_touch_start.erase(e.index)
			var quick: bool = (Time.get_ticks_msec() - start[1]) / 1000.0 < TAP_TIME
			if quick and e.position.distance_to(start[0]) < TAP_SLOP and not hud.covers(e.position):
				_tap(e.position)

func _tap(screen: Vector2) -> void:
	if bag.visible or setup.visible:
		return
	var c: Vector2i = world.cell_at_screen(screen)
	if c == village.target() and village.action_label() != "":
		_route.clear()
		_act()
		return
	if not settings.can_tap_walk() or c == village.tile_of(village.pos):
		return
	var road := village.path_to(c)
	if road.is_empty():
		sound.play("nope")
		var info := village.cell(c)
		hud.toast("Туда вплавь не добраться" if not info.is_empty() and info.ground == WorldGen.Ground.WATER else "Туда не пройти")
		return
	_route.assign(road.cells)
	_route_face = road.face
	_stuck = 0.0


# --- действия -------------------------------------------------------------------------

func _act() -> void:
	if bag.visible or setup.visible:
		return
	_handle(village.act())

func _handle(out: Dictionary) -> void:
	if out.is_empty():
		return
	var said: String = out.get("message", "")
	if said != "":
		hud.toast(said)
	var s: String = out.get("sound", "")
	if s != "":
		sound.play(s)
		var buzz: int = {"chop": 22, "stone": 26, "craft": 16, "place": 22, "pickup": 12, "berries": 10, "twig": 8, "pebble": 8}.get(s, 0)
		if buzz > 0 and settings.vibration:
			Input.vibrate_handheld(buzz)
	if out.has("cell"):
		world.sync_cell(out.cell)
		world.burst(out.cell, s)
	if out.get("slept", false):
		world.sync_all()
	if out.get("goal", false):
		get_tree().create_timer(0.3).timeout.connect(func():
			sound.play("goal")
			world.burst(village.tile_of(village.pos), "goal"))
	_dirty = true


func _open_bag() -> void:
	sound.play("bag")
	_route.clear()
	hud.pad.release()
	bag.open(village, landscape)

func _open_settings() -> void:
	sound.play("ui")
	_route.clear()
	hud.pad.release()
	setup.open(settings, village, landscape)

func _settings_changed(s: Settings) -> void:
	settings = s
	settings.save()
	sound.configure(settings)
	_orient()
	_on_resize()

func _new_world() -> void:
	village = Village.create(randi() & 0x7FFFFFFF)
	setup.visible = false
	world.build(village)
	_route.clear()
	_was_night = village.is_night()
	sound.set_ambience("day")
	sound.play("sleep")
	hud.toast("Новый мир. Утро на опушке — ветки и камешки рядом")
	_save()


# --- экран ----------------------------------------------------------------------------

## Лечь набок или встать — по настройке. На компьютере не делает ничего.
func _orient() -> void:
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE if settings.landscape else DisplayServer.SCREEN_PORTRAIT)

func _on_resize() -> void:
	var s := get_viewport().get_visible_rect().size
	landscape = s.x > s.y
	hud.apply_settings(settings, landscape)
	world.show_target = settings.show_target
	if bag.visible:
		bag.landscape = landscape
		bag.rebuild()
	if setup.visible:
		setup.landscape = landscape
		setup.rebuild()


# --- сохранение -----------------------------------------------------------------------

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if village:
			_save()

func _save() -> void:
	_save_in = 0.0
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"village": village.to_dict()}))

func _load() -> Village:
	if not FileAccess.file_exists(SAVE_PATH):
		return null
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary:
		return null
	return Village.from_dict(data.get("village"))


# --- проверка из командной строки -----------------------------------------------------
#
# godot --path . -- --fresh --seed=42 --time=1230 --bag=stick:12,axe:1 \
#   --built=32:33:campfire --do="pad:1,0:40 act wait:20 open:bag"
#
# Нужна, чтобы прогнать настоящую игру без телефона и снять кадры. В обычной игре этих
# аргументов нет, и всё это не делает ничего.

func _apply_debug_args() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	if args.is_empty():
		return
	if args.has("fresh") or args.has("seed"):
		village = Village.create(int(args.get("seed", "42")))
	if args.has("time"):
		village.time = float(args.time)
	if args.has("food"):
		village.food = float(args.food)
	if args.has("bag"):
		for pair in args.bag.split(","):
			var p: PackedStringArray = pair.split(":")
			village.bag[p[0]] = int(p[1])
	if args.has("built"):
		for item in args.built.split(","):
			var p: PackedStringArray = item.split(":")
			village.built["%s:%s" % [p[0], p[1]]] = p[2]
	if args.has("settings"):
		for pair in args.settings.split(","):
			var p: PackedStringArray = pair.split(":")
			var v: Variant = p[1]
			if p[1] == "true" or p[1] == "false":
				v = p[1] == "true"
			settings.set(p[0], v)
	if args.has("do"):
		_script = Array(args.do.split(" ", false))

func _run_script() -> void:
	if _script_wait > 0:
		_script_wait -= 1
		if _script_wait == 0:
			_script_pad = Vector2.ZERO
		return
	if _script.is_empty():
		return
	var step: String = _script.pop_front()
	var p := step.split(":")
	match p[0]:
		"pad":
			var xy := p[1].split(",")
			_script_pad = Vector2(float(xy[0]), float(xy[1]))
			_script_wait = int(p[2])
		"wait":
			_script_wait = int(p[1])
		"act":
			_act()
		"tap":
			var c := p[1].split(",")
			var cell := village.tile_of(village.pos) + Vector2i(int(c[0]), int(c[1]))
			_tap(world.get_canvas_transform() * ((Vector2(cell) + Vector2(0.5, 0.5)) * Art.TILE))
		"craft":
			_handle(village.craft(p[1]))
		"place":
			_handle(village.place(p[1]))
		"goto":
			# Дойти до ближайшего дерева, куста, камня — той же дорогой, что и по касанию.
			var here := village.tile_of(village.pos)
			var best := {}
			var best_d := INF
			for y in range(here.y - 12, here.y + 13):
				for x in range(here.x - 12, here.x + 13):
					var c := Vector2i(x, y)
					var info := village.cell(c)
					if info.is_empty() or info.nature != p[1] or info.depleted:
						continue
					var d := Vector2(c).distance_to(Vector2(here))
					if d < best_d:
						var road := village.path_to(c)
						if not road.is_empty():
							best_d = d
							best = road
			if not best.is_empty():
				_route.assign(best.cells)
				_route_face = best.face
		"face":
			var d := p[1].split(",")
			village.face(Vector2(float(d[0]), float(d[1])))
		"open":
			if p[1] == "bag":
				_open_bag()
			elif p[1] == "craft":
				_open_bag()
				bag.tab = "craft"
				bag.rebuild()
			else:
				_open_settings()
		"dump":
			var stack: Array = [bag]
			while not stack.is_empty():
				var n = stack.pop_back()
				if n is Control and n.size.x > 300:
					print("MIN ", n.get_class(), " ", n.position, n.size, " min ", n.get_combined_minimum_size())
				stack.append_array(n.get_children())
		"print":
			print("СОСТОЯНИЕ: ", village.clock(), " ", village.pos, " ", village.bag, " ", village.action_label())
			print("ЭКРАН: ", hud.size, " джойстик ", hud.pad.position, hud.pad.size, " день ", hud.day_pill.position, hud.day_pill.size, " задача ", hud.goal_card.position, hud.goal_card.size)
