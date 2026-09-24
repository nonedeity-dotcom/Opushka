## Эволюция — этап клетки.
##
## Этот узел связывает всё: правила (Pond, Evolution), океан на экране (PondView),
## интерфейс (Hud, редактор, настройки), звуки и сохранение. Сам он ничего не решает —
## только передаёт.
extends Node2D

const PondView := preload("res://scripts/view/pond_view.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const EditorPanel := preload("res://scripts/ui/editor_panel.gd")
const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")
const SoundBank := preload("res://scripts/sound_bank.gd")

const SAVE_PATH := "user://evolution.json"

var evo: Evolution
var pond: Pond
var settings: Settings
var view: Node2D
var hud: Control
var editor: Control
var setup: Control
var sound: Node
var backdrop: Control
var fog: ColorRect
var landscape := true

var _seed := 0
var _dash := false
var _dirty := false
var _save_in := 0.0
var _fingers := {}  # номер пальца → точка: для «плыть за пальцем»
var _script: Array = []  # сценарий для проверки — только из командной строки
var _script_wait := 0
var _script_pad := Vector2.ZERO
var _spawns: Array = []


func _ready() -> void:
	settings = Settings.load_saved()
	evo = _load()
	var fresh := evo == null
	if fresh:
		evo = Evolution.create()
	_apply_debug_args()

	var back := CanvasLayer.new()
	back.layer = -1
	add_child(back)
	backdrop = preload("res://scripts/view/backdrop.gd").new()
	back.add_child(backdrop)

	view = PondView.new()
	add_child(view)
	_new_pond()

	var shade := CanvasLayer.new()
	shade.layer = 1
	add_child(shade)
	fog = preload("res://scripts/view/fog.gd").new()
	shade.add_child(fog)
	shade.add_child(_vignette())

	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var ui := Control.new()
	ui.theme = Kit.theme()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)

	hud = Hud.new()
	ui.add_child(hud)
	hud.dash_pressed.connect(func(): _dash = true)
	hud.editor_pressed.connect(_open_editor)
	hud.settings_pressed.connect(_open_settings)

	editor = EditorPanel.new()
	editor.visible = false
	ui.add_child(editor)
	editor.closed.connect(func():
		editor.visible = false
		sound.play("ui")
		pond.player.sync_player(evo)
		_save())
	editor.changed.connect(func():
		sound.play("place")
		pond.player.sync_player(evo)
		_dirty = true)

	setup = SettingsPanel.new()
	setup.visible = false
	ui.add_child(setup)
	setup.closed.connect(func(): setup.visible = false)
	setup.changed.connect(_settings_changed)
	setup.new_world.connect(_start_over)

	sound = SoundBank.new()
	add_child(sound)
	sound.configure(settings)

	_orient()
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()
	if fresh:
		hud.toast("Ты — крошечная клетка без глаз: видно только то, что рядом. Плыви к зелёным крупинкам — это еда")

func _new_pond() -> void:
	pond = Pond.new(evo, _seed)
	view.setup(pond)
	pond.view_radius = view.view_radius()
	pond.fill()
	for s in _spawns:
		var gold: bool = s[0].begins_with("*")
		pond.spawn(s[0].trim_prefix("*"), pond.player.pos + s[1], gold)

## Затемнение по краям: глубина, и взгляд сам собирается к середине.
func _vignette() -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0.0, 0.02, 0.04, 0.55))
	g.add_point(0.55, Color(0, 0, 0, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 0.5)
	tex.width = 256
	tex.height = 256
	var r := TextureRect.new()
	r.texture = tex
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return r


# --- кадр -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	_run_script()
	var paused: bool = editor.visible or setup.visible
	if not paused:
		pond.view_radius = view.view_radius()
		pond.step(minf(delta, 0.05), _steer(), _dash)
		_dash = false
		view.effects(pond.events)
		_handle(pond.events)
	hud.refresh(pond)
	backdrop.drift = pond.player.pos
	var xf: Transform2D = view.get_canvas_transform()
	fog.update(xf * pond.player.pos, pond.player.vision * view.camera.zoom.x, delta)
	_update_arrows()
	if _save_in > 0.0:
		_save_in -= delta
		if _save_in <= 0.0:
			_save()
	elif _dirty:
		_dirty = false
		_save_in = 3.0

## Куда плыть: джойстик, палец на экране или сценарий проверки.
func _steer() -> Vector2:
	if _script_pad != Vector2.ZERO:
		return _script_pad
	if settings.control == "stick":
		return hud.pad.vector
	if _fingers.is_empty():
		return Vector2.ZERO
	var finger: Vector2 = _fingers.values()[-1]
	var me: Vector2 = view.get_canvas_transform() * pond.player.pos
	var to := finger - me
	return to.normalized() * clampf(to.length() / 140.0, 0.25, 1.0) if to.length() > 12.0 else Vector2.ZERO

func _unhandled_input(e: InputEvent) -> void:
	if settings.control != "follow":
		return
	if e is InputEventScreenTouch:
		if e.pressed and not hud.covers(e.position):
			_fingers[e.index] = e.position
		elif not e.pressed:
			_fingers.erase(e.index)
	elif e is InputEventScreenDrag and _fingers.has(e.index):
		_fingers[e.index] = e.position


# --- события --------------------------------------------------------------------------

func _handle(events: Array) -> void:
	var near: float = view.view_radius()
	for e in events:
		match e.t:
			"eat":
				sound.play("eat" if e.kind == "plant" else "eat_meat", randf_range(0.9, 1.15))
				_dirty = true
			"hit":
				if e.to_player:
					sound.play("hurt")
					hud.hurt()
					_buzz(30)
				elif e.from_player:
					sound.play("bite" if e.kind == "bite" else "hit", randf_range(0.9, 1.1))
					_buzz(12)
			"kill":
				if e.by_player:
					sound.play("kill")
					_buzz(25)
				elif e.pos.distance_to(pond.player.pos) < near:
					sound.play("kill", 1.3)
			"drop":
				sound.play("drop")
				var name: String = Content.PARTS[e.part].name
				if evo.unlocked.has(e.part):
					hud.toast("Выпала часть: %s — подбери, станет сильнее" % name.to_lower())
				else:
					hud.toast("Выпала новая часть: %s! Подбери её" % name.to_lower())
			"pickup":
				_dirty = true
				var def: Dictionary = Content.PARTS[e.part]
				if e.new:
					sound.play("newpart")
					hud.announce("Новая часть!", "%s — %s. Поставь её в «Эволюции»" % [def.name, Content.lc_first(def.hint)])
					hud.editor_btn.badge = "!"
					hud.editor_btn.queue_redraw()
					_buzz(40)
				elif e.dna > 0:
					sound.play("pickup")
					hud.toast("%s уже на пятом уровне: +%d ДНК" % [def.name, e.dna])
				elif e.up:
					sound.play("newpart", 1.2)
					hud.announce("%s: уровень %d" % [def.name, e.level], "Сильнее на %d%%, чем в начале" % int(round((Content.power(e.level) - 1.0) * 100.0)))
					_buzz(30)
				else:
					sound.play("pickup")
					hud.toast("%s: копия %d из %d до уровня %d" % [def.name, e.have, e.need, e.level + 1])
			"levelup":
				sound.play("levelup")
				_dirty = true
				_buzz(50)
				hud.editor_btn.badge = "!"
				hud.editor_btn.queue_redraw()
				if e.level >= Content.LEVELS.size():
					hud.announce("Многоклеточный!", "Этап клетки пройден. Можно жить дальше: собирать и улучшать части")
				else:
					hud.announce("Размер %d" % e.level, "Места на теле больше: %d. Вокруг появятся новые клетки" % evo.slots())
			"zap":
				if e.by_player or e.to_player:
					sound.play("zap")
			"poison":
				sound.play("poison")
				if e.to_player:
					hud.toast("Отравлен! Яд жжёт ещё три секунды")
			"death":
				sound.play("death")
				_buzz(80)
				_dirty = true
				hud.announce("Тебя съели", "Новая клетка твоего вида появилась неподалёку. Всё найденное осталось")
			"dash":
				sound.play("dash")
			"goal":
				_dirty = true
				var g: Dictionary = e.goal
				get_tree().create_timer(0.4).timeout.connect(func():
					sound.play("goal")
					hud.toast("Задача выполнена: %s" % g.title.to_lower()))
			"seen":
				_dirty = true
				hud.toast("Новый вид: %s. Он теперь в «Атласе»" % Content.SPECIES[e.species].name)
			"golden":
				sound.play("drop", 0.8)
				hud.toast("Сияющая особь — %s! Из неё обязательно что-то выпадет. Она пугливая" % Content.SPECIES[e.species].name.to_lower())

func _buzz(ms: int) -> void:
	if settings.vibration:
		Input.vibrate_handheld(ms)

## Стрелки к находкам за краем экрана и — с глазками — к хищникам.
func _update_arrows() -> void:
	var list: Array = []
	var xf: Transform2D = view.get_canvas_transform()
	for cap in pond.capsules:
		list.append({"at": xf * cap.pos, "kind": "part", "part": cap.part})
	var p := pond.player
	if p.eyes > 0.0:
		for m in pond.mobs:
			if pond._hunts(m) and m.radius >= p.radius * 0.8 and m.pos.distance_to(p.pos) < p.sight * 2.0:
				list.append({"at": xf * m.pos, "kind": "danger"})
	hud.indicators.targets = list


# --- панели ---------------------------------------------------------------------------

func _open_editor() -> void:
	sound.play("ui")
	hud.pad.release()
	_fingers.clear()
	hud.editor_btn.badge = ""
	hud.editor_btn.queue_redraw()
	editor.open(evo, landscape)

func _open_settings() -> void:
	sound.play("ui")
	hud.pad.release()
	_fingers.clear()
	setup.open(settings, evo, landscape)

func _settings_changed(s: Settings) -> void:
	settings = s
	settings.save()
	sound.configure(settings)
	_orient()
	_on_resize()

func _start_over() -> void:
	evo = Evolution.create()
	setup.visible = false
	_new_pond()
	sound.play("levelup", 0.8)
	hud.toast("Снова крошечная клетка. Плыви к зелёным крупинкам: это еда")
	_save()


# --- экран ----------------------------------------------------------------------------

## Игра всегда лёжа — и так, и эдак перевёрнутый телефон подходит.
func _orient() -> void:
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)

func _on_resize() -> void:
	var s := get_viewport().get_visible_rect().size
	landscape = s.x > s.y
	hud.apply_settings(settings, landscape)
	if editor.visible:
		editor.landscape = landscape
		editor.rebuild()
	if setup.visible:
		setup.landscape = landscape
		setup.rebuild()


# --- сохранение -----------------------------------------------------------------------

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if evo:
			_save()

func _save() -> void:
	_save_in = 0.0
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(evo.to_dict()))

func _load() -> Evolution:
	if not FileAccess.file_exists(SAVE_PATH):
		return null
	return Evolution.from_dict(JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH)))


# --- проверка из командной строки -----------------------------------------------------
#
# godot --path . -- --fresh --seed=42 --dna=120 --unlock=jaws:1,spike:2 \
#   --body=jaws@0,spike@90,spike@-90,cilia@180 --color=3 --spawn=kusaka@120,0 \
#   --do="pad:1,0:40 dash wait:20 open:editor select:spike print"
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
	if args.has("fresh"):
		evo = Evolution.create()
	_seed = int(args.get("seed", "0"))
	if args.has("dna"):
		evo.dna_total = float(args.dna)
	if args.has("unlock"):
		for pair in args.unlock.split(","):
			var p: PackedStringArray = pair.split(":")
			evo.unlocked[p[0]] = int(p[1]) if p.size() > 1 else 1
	if args.has("body"):
		evo.body = []
		for item in args.body.split(","):
			var p: PackedStringArray = item.split("@")
			evo.unlocked[p[0]] = evo.unlocked.get(p[0], 1)
			evo.body.append({"id": p[0], "a": int(p[1]), "d": float(p[2]) if p.size() > 2 else 1.0})
	if args.has("color"):
		evo.color = int(args.color)
	if args.has("seen"):
		for s in args.seen.split(","):
			evo.seen[s] = true
	if args.has("spawn"):
		for item in args.spawn.split(";"):
			var p: PackedStringArray = item.split("@")
			var xy: PackedStringArray = p[1].split(",")
			_spawns.append([p[0], Vector2(float(xy[0]), float(xy[1]))])
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
		"dash":
			_dash = true
		"open":
			if p[1] == "settings":
				_open_settings()
			else:
				_open_editor()
				if p[1] == "atlas":
					editor.tab = "atlas"
					editor.rebuild()
		"select":
			editor.selected = p[1]
			editor.rebuild()
		"placeat":
			var ad := p[1].split(",")
			editor.place_at(float(ad[0]), float(ad[1]) if ad.size() > 1 else 1.0)
		"pick":
			editor.pick(int(p[1]))
		"ghost":
			var ad := p[1].split(",")
			editor._preview.ghost = {"a": float(ad[0]), "d": float(ad[1]) if ad.size() > 1 else 1.0}
		"mode":
			editor.mode = p[1]
			editor.rebuild()
		"pull":
			var ad := p[1].split(",")
			editor.evo.reshape(float(ad[0]), float(ad[1]), editor.mirror)
			editor.shape_done()
		"shape":
			evo.set_shape(p[1])
			pond.player.sync_player(evo)
		"close":
			editor.visible = false
			setup.visible = false
			pond.player.sync_player(evo)
		"swipe":
			# Провести пальцем: x,y — откуда, dy — насколько вверх/вниз (точки экрана).
			var q := p[1].split(",")
			var from := Vector2(float(q[0]), float(q[1]))
			var down := InputEventScreenTouch.new()
			down.position = from
			down.pressed = true
			Input.parse_input_event(down)
			for i in range(1, 9):
				var mv := InputEventScreenDrag.new()
				mv.position = from + Vector2(0, float(q[2]) * i / 8.0)
				mv.relative = Vector2(0, float(q[2]) / 8.0)
				mv.velocity = Vector2(0, float(q[2]) * 4.0)
				Input.parse_input_event(mv)
			var up := InputEventScreenTouch.new()
			up.position = from + Vector2(0, float(q[2]))
			up.pressed = false
			Input.parse_input_event(up)
		"banner":
			hud.announce("Размер 3", "Места на теле больше: 5. Вокруг появятся новые клетки")
		"print":
			print("СОСТОЯНИЕ: размер ", evo.level(), " ДНК ", evo.dna_free(), "/", int(evo.dna_total), " клеток ", pond.mobs.size(), " еды ", pond.food.size(), " поз ", pond.player.pos)
