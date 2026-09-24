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
const MenuPanel := preload("res://scripts/ui/menu_panel.gd")
const ShopPanel := preload("res://scripts/ui/shop_panel.gd")
const PausePanel := preload("res://scripts/ui/pause_panel.gd")

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
var menu: Control
var shop: Control
var pause: Control
var landscape := true
## Ячейка сохранения, в которую играем. 0 — проверочный запуск: не сохраняется.
var slot := 0
var _debug := false
var _show_menu := false

var _seed := 0
var _dash := false
var _dirty := false
var _save_in := 0.0
var _fingers := {}  # номер пальца → точка: для «плыть за пальцем»
var _script: Array = []  # сценарий для проверки — только из командной строки
var _script_wait := 0
var _script_pad := Vector2.ZERO
var _spawns: Array = []
## Тело правили после встречи с парой — запомнить его в родословной, когда закроют редактор.
var _after_mate := false
var _ach_t := 1.0
## Сколько секунд назад было опасно — пока недавно, играет музыка боя.
var _danger_t := 99.0
## Голоса существ — не чаще раза в столько секунд, чтобы не сливались в гам.
var _voice_gap := 0.0
## Замер времени частей кадра (только с --profile): имя → [сумма мкс, раз].
var _prof := {}
var _prof_on := false
var _prof_frames := 0
## Атмосфера: когда следующий далёкий звук, когда можно снова «зов из глубины», стук сердца.
var _amb_t := 6.0
var _moan_gap := 0.0
var _heart_t := 0.0
## Удар с весом: мир на миг замирает (секунды настоящего времени).
var _freeze := 0.0
var _depth_level := -1
## Затемнение: тень гиганта и мёртвая зона. Красные края — когда мало здоровья.
var _dim: ColorRect
var _low_hp: TextureRect


func _ready() -> void:
	settings = Settings.load_saved()
	Saves.migrate()
	_apply_debug_args()

	var back := CanvasLayer.new()
	back.layer = -1
	add_child(back)
	backdrop = preload("res://scripts/view/backdrop.gd").new()
	back.add_child(backdrop)

	view = PondView.new()
	add_child(view)

	var shade := CanvasLayer.new()
	shade.layer = 1
	add_child(shade)
	fog = preload("res://scripts/view/fog.gd").new()
	shade.add_child(fog)
	shade.add_child(_vignette())
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.02, 0.05, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(_dim)
	_low_hp = _vignette(Color(0.55, 0.02, 0.04, 0.75))
	_low_hp.modulate.a = 0.0
	shade.add_child(_low_hp)
	backdrop.ghost_appeared.connect(_ghost_moan)

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
	hud.ability_pressed.connect(func():
		if pond and not pond.use_ability():
			sound.play("nope"))
	hud.editor_pressed.connect(_call_mate)
	hud.atlas_pressed.connect(func():
		sound.play("ui")
		hud.pad.release()
		_fingers.clear()
		editor.open(evo, landscape, false))
	hud.settings_pressed.connect(_open_settings)
	hud.shop_pressed.connect(_open_shop)
	hud.pause_pressed.connect(_pause)

	editor = EditorPanel.new()
	editor.visible = false
	ui.add_child(editor)
	editor.closed.connect(func():
		editor.visible = false
		sound.play("ui")
		if pond == null:
			return
		pond.player.sync_player(evo)
		if _after_mate:
			_after_mate = false
			evo.remember()
		pond.resync_allies()
		_save())
	editor.summon.connect(func(id):
		if pond:
			editor.visible = false
			pond.spawn(id, pond.player.pos + Vector2.from_angle(randf() * TAU) * (pond.player.radius * 4.0 + 120.0))
			hud.toast("%s — рядом" % Content.SPECIES[id].name))
	editor.changed.connect(func():
		sound.play("place")
		pond.player.sync_player(evo)
		_dirty = true)

	setup = SettingsPanel.new()
	setup.visible = false
	ui.add_child(setup)
	setup.closed.connect(func(): setup.visible = false)
	setup.changed.connect(_settings_changed)
	setup.new_world.connect(_to_menu)
	pause = PausePanel.new()
	pause.visible = false
	ui.add_child(pause)
	pause.resume.connect(func():
		sound.play("ui")
		pause.visible = false)
	pause.settings.connect(func():
		pause.visible = false
		_open_settings())
	pause.to_menu.connect(func():
		pause.visible = false
		_to_menu())
	setup.test_sound.connect(func(id): sound.play(id))

	shop = ShopPanel.new()
	shop.visible = false
	ui.add_child(shop)
	shop.closed.connect(func():
		shop.visible = false
		sound.play("ui")
		_save())
	shop.bought.connect(func(id):
		if id == "":
			sound.play("nope")
			return
		sound.play("levelup", 1.2)
		_buzz(40)
		pond.player.sync_player(evo)
		hud.dna_gain()
		_dirty = true)

	menu = MenuPanel.new()
	menu.visible = false
	ui.add_child(menu)
	menu.play.connect(func(s):
		sound.play("ui")
		evo = Saves.load_slot(s)
		if evo:
			_begin(s, false))
	menu.new_game.connect(func(s, d):
		sound.play("levelup", 0.8)
		evo = Evolution.create(d)
		_begin(s, true))
	menu.arena.connect(func(s):
		sound.play("wave")
		evo = Saves.load_slot(s)
		if evo:
			_begin(s, false, "arena"))
	menu.sandbox.connect(func():
		sound.play("levelup", 0.8)
		evo = Saves.load_slot(Saves.SANDBOX)
		var fresh := evo == null
		if fresh:
			evo = Evolution.create_sandbox()
		_begin(Saves.SANDBOX, fresh, "sandbox"))

	sound = SoundBank.new()
	add_child(sound)
	sound.configure(settings)

	_orient()
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()
	if _debug and not _show_menu:
		_begin(0, false)
	else:
		_to_menu()

## Начать игру в ячейке: океан вокруг, интерфейс, первое сохранение.
func _begin(s: int, fresh: bool, mode := "normal") -> void:
	slot = s
	_new_pond()
	menu.visible = false
	hud.visible = true
	fog.visible = true
	_after_mate = false
	_danger_t = 99.0
	evo.check_achievements()
	if evo.history.is_empty():
		evo.remember()
	if mode == "arena":
		pond.start_arena()
		hud.announce("Арена", "Волны врагов — продержись как можно дольше. Рекорд: %d" % evo.arena_best)
	elif evo.sandbox:
		pond.mode = "sandbox"
		if fresh:
			hud.announce("Песочница", "Все части открыты, ДНК сколько угодно. ♥ — сразу к телу, в «Атласе» можно призвать любого")
	_save()
	if fresh and not evo.sandbox:
		hud.toast("Ты — крошечная клетка без глаз: видно только то, что рядом. Плыви к зелёным крупинкам — это еда")

## В меню: сохранить, убрать океан, показать ячейки.
func _to_menu() -> void:
	if pond:
		_save()
	pond = null
	view.pond = null
	sound.set_music("")
	setup.visible = false
	editor.visible = false
	shop.visible = false
	pause.visible = false
	hud.visible = false
	fog.visible = false
	menu.open()

func _new_pond() -> void:
	pond = Pond.new(evo, _seed)
	view.setup(pond)
	pond.view_radius = view.view_radius()
	pond.fill()
	for s in _spawns:
		var gold: bool = s[0].begins_with("*")
		pond.spawn(s[0].trim_prefix("*"), pond.player.pos + s[1], gold)

## Затемнение по краям: глубина, и взгляд сам собирается к середине.
func _vignette(edge := Color(0.0, 0.02, 0.04, 0.55)) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, edge)
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
	if pond == null:
		return
	if _prof_on:
		_prof_frames += 1
		_prof_add("кадр целиком (delta)", int(delta * 1_000_000.0))
		for k in view.prof:
			_prof_add("рисование: " + k, view.prof[k])
		view.prof.clear()
		if _prof_frames % 300 == 0:
			var keys := _prof.keys()
			keys.sort_custom(func(a, b): return _prof[a][0] > _prof[b][0])
			for k in keys:
				print("ЗАМЕР %-28s %7.2f мс" % [k, float(_prof[k][0]) / maxf(1.0, float(_prof[k][1])) / 1000.0])
			print("ЗАМЕР клеток %d еды %d кругов %d камней %d fps %d" % [pond.mobs.size(), pond.food.size(), pond.colonies.size(), pond.rocks.size(), Engine.get_frames_per_second()])
			print("ЗАМЕР вызовов рисования %d, примитивов %d, объектов %d, скрипты %.1f мс" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
			_prof.clear()
	var t0 := Time.get_ticks_usec()
	evo.played += delta
	var paused: bool = editor.visible or setup.visible or shop.visible or pause.visible
	# Удар с весом: мир на миг замер (эффекты и камера живут дальше).
	if _freeze > 0.0 and not paused:
		_freeze -= delta
		pond.events.clear()
	elif not paused:
		pond.view_radius = view.view_radius()
		pond.step(minf(delta, 0.05), _steer(), _dash)
		_prof_add("pond.step", Time.get_ticks_usec() - t0)
		t0 = Time.get_ticks_usec()
		_dash = false
		view.effects(pond.events)
		_handle(pond.events)
		_prof_add("события", Time.get_ticks_usec() - t0)
	t0 = Time.get_ticks_usec()
	hud.refresh(pond)
	_prof_add("hud.refresh", Time.get_ticks_usec() - t0)
	if pond == null:
		return
	backdrop.drift = pond.player.pos
	backdrop.level = evo.level()
	backdrop.zoom = view.camera.zoom.x
	backdrop.player_r = pond.player.size_r
	t0 = Time.get_ticks_usec()
	_music(delta)
	_atmosphere(delta, paused)
	_voice_gap -= delta
	_ach_t -= delta
	if _ach_t <= 0.0:
		_ach_t = 1.0
		for a in evo.check_achievements():
			_achieved(a)
	var xf: Transform2D = view.get_canvas_transform()
	var lights: Array = []
	var z: float = view.camera.zoom.x
	for m in pond.mobs:
		if m.glow and lights.size() < 8:
			lights.append(Vector3((xf * m.pos).x, (xf * m.pos).y, m.radius * 3.0 * z))
	var fog_r := pond.vision() * (1.25 if pond.player.glow else 1.0) * z
	# Обзор шире экрана — тумана не видно, и незачем считать его на каждом пикселе.
	var screen_r := get_viewport().get_visible_rect().size.length() / 2.0
	fog.visible = not paused and fog_r < screen_r * 1.15
	if fog.visible:
		fog.update(xf * pond.player.pos, fog_r, delta, lights)
	_update_arrows()
	_prof_add("музыка, туман, стрелки", Time.get_ticks_usec() - t0)
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
					# Гигант или очень сильный удар — мир на миг замирает, экран вздрагивает.
					if e.get("giant", false) or float(e.get("share", 0.0)) > 0.25:
						_heavy(0.07, 0.7)
						_buzz(70)
				elif e.from_player:
					sound.play("bite" if e.kind == "bite" else "hit", randf_range(0.9, 1.1))
					_buzz(12)
			"kill":
				if e.by_player and e.get("dna", 0.0) >= 5.0:
					hud.dna_gain()
				if e.by_player:
					sound.play("kill")
					_buzz(25)
					if float(e.radius) >= pond.player.radius * 0.8:
						_heavy(0.06, 0.4)
				elif e.pos.distance_to(pond.player.pos) < near:
					sound.play("kill", 1.3, _far(e.pos))
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
					hud.announce("Новая часть!", "%s — %s. Нажми ♥ и найди пару, чтобы поставить её" % [def.name, Content.lc_first(def.hint)])
					hud.reveal_part(e.part)
					hud.editor_btn.badge = "!"
					hud.editor_btn.queue_redraw()
					_buzz(40)
				elif e.dna > 0:
					sound.play("pickup")
					hud.toast("%s уже на пятом уровне: +%d ДНК" % [def.name, e.dna])
				elif e.up:
					sound.play("newpart", 1.2)
					hud.announce("%s: уровень %d" % [def.name, e.level], "Сильнее на %d%%, чем в начале" % int(round((Content.power(e.level) - 1.0) * 100.0)))
					hud.reveal_part(e.part, true)
					_buzz(30)
				else:
					sound.play("pickup")
					hud.toast("%s: копия %d из %d до уровня %d" % [def.name, e.have, e.need, e.level + 1])
			"levelup":
				sound.play("levelup")
				# Миг тишины: мир замирает, клетка светится — и сбрасывает оболочку.
				_heavy(0.3, 0.25)
				hud.grew()
				_dirty = true
				_buzz(50)
				hud.editor_btn.badge = "!"
				hud.editor_btn.queue_redraw()
				if e.level >= Content.LEVELS.size():
					hud.announce("Многоклеточный!", "Этап клетки пройден. Можно жить дальше: собирать и улучшать части")
				else:
					hud.announce("Размер %d" % e.level, "Места на теле больше: %d. Вокруг появятся новые клетки — их тени уже видны в глубине" % evo.slots())
			"zap":
				if e.by_player or e.to_player:
					sound.play("zap")
			"poison":
				sound.play("poison")
				if e.to_player:
					hud.toast("Отравлен! Яд жжёт ещё три секунды")
			"death":
				sound.play("death")
				_heavy(0.12, 0.8)
				_buzz(80)
				_dirty = true
				if e.get("lost", 0.0) > 0.5:
					hud.announce("Тебя съели", "Тяжёлая сложность: потеряно %d ДНК роста. Части остались" % int(e.lost))
				else:
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
			"rock_hit":
				sound.play("rock", randf_range(1.2, 1.5))
				_buzz(10)
			"rock_break":
				sound.play("rock")
				_buzz(35)
				_dirty = true
			"mate_called":
				sound.play("mate")
			"mated":
				sound.play("mate", 1.25)
				_buzz(60)
				_dirty = true
				hud.announce("Поколение %d" % e.generation, "Потомство можно изменить: части, форма, цвет. В свите потомков: %d" % evo.brood)
				_after_mate = true
				hud.editor_btn.badge = ""
				hud.editor_btn.queue_redraw()
				get_tree().create_timer(0.9).timeout.connect(_open_editor)
			"voice":
				if _voice_gap <= 0.0 and e.pos.distance_to(pond.player.pos) < near:
					_voice_gap = 0.7
					# Голос по размеру: крупные — ниже.
					sound.play(e.kind, clampf(1.5 - float(e.size) / 70.0, 0.55, 1.5), _far(e.pos))
			"shot":
				if e.by_player or e.pos.distance_to(pond.player.pos) < near:
					sound.play("spit", randf_range(0.9, 1.15) if e.kind == "spit" else randf_range(1.4, 1.6), 0.0 if e.by_player else _far(e.pos))
			"split":
				sound.play("split", 1.0, _far(e.pos))
				if int(evo.stats.get("splits_seen", 0)) < 2:
					evo.count("splits_seen")
					hud.toast("Делитель распался на двоих — добивай по одному")
			"ambush":
				sound.play("growl", 1.2)
				if e.to_player:
					_buzz(30)
					hud.toast("Это была не водоросль — обманка! С двумя глазами их видно")
			"roamer":
				sound.play("whale" if e.species == "kit" else "boom", 1.0, 0.5)
				hud.announce(Content.SPECIES[e.species].name, "Бродячий гигант проплывает рядом. " + Content.SPECIES[e.species].hint)
			"remora_on":
				sound.play("place")
				hud.toast("Прилип к «%s» — ешь с него крохи. Рывок или ход прочь — отцепиться" % Content.SPECIES[e.species].name.to_lower())
			"remora_off":
				sound.play("remove")
			"golden":
				sound.play("drop", 0.8)
				hud.toast("Сияющая особь — %s! Из неё обязательно что-то выпадет. Она пугливая" % Content.SPECIES[e.species].name.to_lower())
			"parasite":
				sound.play("parasite")
				_buzz(20)
				if int(evo.stats.get("shaken", 0)) < 3:
					hud.toast("Прицепился паразит — пьёт здоровье. Стряхни его рывком!")
			"shaken":
				sound.play("dash", 0.8)
			"ability":
				if e.by_player:
					sound.play("ability")
					_buzz(20)
				elif e.pos.distance_to(pond.player.pos) < near:
					sound.play("ability", 0.8, _far(e.pos))
			"giant_beaten":
				sound.play("levelup")
				_heavy(0.18, 1.0)
				_buzz(80)
				_dirty = true
				hud.announce("Гигант побеждён!", "%s — забери награду" % Content.SPECIES[e.species].name)
			"wave":
				sound.play("wave")
				hud.announce("Волна %d" % e.wave, "Врагов: %d" % (1 + e.wave))
			"arena_over":
				sound.play("death")
				_save()
				hud.announce("Арена окончена", "Продержался волн: %d · рекорд: %d" % [e.wave - 1, evo.arena_best])
				get_tree().create_timer(3.0).timeout.connect(_to_menu)
			"permadeath":
				sound.play("death")
				_buzz(120)
				var gens := evo.generation
				if slot > 0:
					Saves.delete_slot(slot)
				slot = 0
				hud.announce("Вид вымер", "Суперсложность: одна жизнь. Поколений прожито: %d" % gens)
				pond.spawning = false
				get_tree().create_timer(3.5).timeout.connect(_to_menu)
			"ally_lost":
				hud.toast("Потомок погиб. Новый подрастёт через некоторое время")
			"world_event":
				var ev: Dictionary = Content.EVENTS[e.id]
				sound.play("swell")
				_buzz(40)
				hud.announce(ev.name, ev.hint)
			"world_event_end":
				hud.toast(Content.EVENTS[e.id].end)

func _achieved(a: Dictionary) -> void:
	sound.play("goal")
	hud.toast("Достижение: %s" % a.title)
	_dirty = true

## Музыка боя — пока за тобой гонятся или тебя недавно ранили.
func _music(delta: float) -> void:
	var p := pond.player
	var danger := pond.boss_active != null or p.calm_t < 3.0 or pond.mode == "arena" and not pond.mobs.is_empty()
	if not danger:
		for m in pond.mobs:
			if m.ai_target == p and m.ai_state == "chase" and m.pos.distance_to(p.pos) < pond.vision() * 1.5:
				danger = true
				break
	_danger_t = 0.0 if danger else _danger_t + delta
	sound.set_music("fight" if _danger_t < 4.0 else "calm")

## Насколько далеко точка: 0 — рядом, 1 — у края видимого. Для звуков.
func _far(at: Vector2) -> float:
	return clampf((at.distance_to(pond.player.pos) / maxf(pond.view_radius, 1.0) - 0.25) / 0.75, 0.0, 1.0)

## Удар с весом: замереть на миг и тряхнуть камеру.
func _heavy(sec: float, shake: float) -> void:
	_freeze = maxf(_freeze, sec)
	view.shake(shake)

## Атмосфера: глубина в звуке, далёкие звуки, сердце при малом здоровье, тень гиганта,
## вода в событиях.
func _atmosphere(delta: float, paused: bool) -> void:
	var p := pond.player
	if evo.level() != _depth_level:
		_depth_level = evo.level()
		sound.set_depth(_depth_level)
	# Далёкие звуки океана: пузырьки, скрип, изредка — зов из глубины.
	_moan_gap -= delta
	_amb_t -= delta
	if _amb_t <= 0.0 and not paused:
		_amb_t = randf_range(7.0, 16.0)
		var pick: String = ["bubbles", "bubbles", "creak", "deep"][randi() % 4]
		if pick == "deep" and _moan_gap > 0.0:
			pick = "bubbles"
		if pick == "deep":
			_moan_gap = 30.0
		sound.play(pick, randf_range(0.8, 1.15), randf_range(0.6, 1.0))
	# Сердце: мало здоровья — стучит, края экрана краснеют в такт.
	var low: bool = p.alive and p.hp < p.max_hp * 0.3 and not paused and pond.mode != "sandbox"
	_heart_t -= delta
	if low and _heart_t <= 0.0:
		_heart_t = lerpf(0.65, 1.0, clampf(p.hp / (p.max_hp * 0.3), 0.0, 1.0))
		sound.play("heart")
		_low_hp.modulate.a = 1.0
	_low_hp.modulate.a = maxf(0.0, _low_hp.modulate.a - delta * (1.6 if low else 3.0))
	# Гигант рядом — его тень закрывает свет.
	var giant := 0.0
	for m in pond.mobs:
		if Pond.is_giant(m):
			var d := m.pos.distance_to(p.pos) - m.radius
			giant = maxf(giant, clampf(1.0 - d / (pond.view_radius * 0.9), 0.0, 1.0))
	backdrop.shade = giant
	backdrop.event = pond.event_look
	backdrop.event_k = pond.event_k
	var dark := 0.3 * giant + (0.3 * pond.event_k if pond.event_look == "dead" else 0.0)
	_dim.color.a = lerpf(_dim.color.a, dark, 1.0 - exp(-2.0 * delta))
	hud.set_event(pond.event, pond.event_t)

## Тень гиганта выплыла в глубине — изредка слышен её далёкий зов.
func _ghost_moan(scale: float) -> void:
	if pond == null or _moan_gap > 0.0 or editor.visible:
		return
	_moan_gap = 25.0
	sound.play("deep", clampf(1.3 - scale * 0.12, 0.7, 1.1), 0.8)

func _prof_add(name: String, us: int) -> void:
	if not _prof_on:
		return
	var e: Array = _prof.get(name, [0, 0])
	e[0] += us
	e[1] += 1
	_prof[name] = e

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
	if pond.mate != null:
		list.append({"at": xf * pond.mate.pos, "kind": "mate", "hidden": pond.mate.pos.distance_to(p.pos) > pond.vision()})
	if p.eyes > 0.0:
		for m in pond.mobs:
			if m.invisible and p.eyes < 1.0:
				continue
			if pond._hunts(m) and m.radius >= p.radius * 0.8 and m.pos.distance_to(p.pos) < p.sight * 2.0:
				list.append({"at": xf * m.pos, "kind": "danger"})
	hud.indicators.targets = list
	_update_minimap()

## Мини-карта: всё, что вокруг, в круге радиусом в два с половиной экрана.
func _update_minimap() -> void:
	if not hud.minimap.visible:
		return
	var p := pond.player
	var reach := pond.view_radius * 2.5
	var dots: Array = []
	var put := func(at: Vector2, col: Color, r: float) -> void:
		var rel := (at - p.pos) / reach
		if rel.length() < 1.15:
			dots.append({"at": rel, "col": col, "r": r})
	for k in pond.rocks:
		put.call(k.pos, Color(0.55, 0.6, 0.65, 0.6), 2.0)
	for col in pond.colonies:
		put.call(col.pos, Color(0.45, 0.85, 0.45, 0.9), 4.0)
	for m in pond.mobs:
		if (m.invisible and p.eyes < 1.0) or (m.behavior() == "ambush" and m.revealed_t <= 0.0 and p.eyes < 2.0):
			continue
		# Гигантов на карте нет — их замечаешь сам, по теням и голосу.
		if Pond.is_giant(m):
			continue
		if pond._hunts(m) and m.radius >= p.radius * 0.8:
			put.call(m.pos, Art.DANGER, 3.5)
		else:
			put.call(m.pos, Color(0.85, 0.85, 0.8, 0.7), 2.5)
	for cap in pond.capsules:
		put.call(cap.pos, Art.GOLD, 3.5)
	if pond.mate != null:
		put.call(pond.mate.pos, Color("#f07aa8"), 4.5)
	hud.minimap.set_data(dots, p.heading, get_process_delta_time())


# --- панели ---------------------------------------------------------------------------

func _open_editor() -> void:
	if pond == null:
		return
	sound.play("ui")
	hud.pad.release()
	_fingers.clear()
	editor.open(evo, landscape, true)

## Кнопка ♥: позвать пару. Тело меняется только после встречи с ней.
func _call_mate() -> void:
	if pond == null:
		return
	if evo.sandbox:
		_after_mate = true
		_open_editor()
		return
	if pond.mode == "arena":
		sound.play("nope")
		hud.toast("На арене не до пары — сначала продержись")
		return
	if pond.call_mate():
		hud.toast("Пара где-то рядом — плыви по розовой стрелке")
	else:
		sound.play("ui")
		hud.toast("Пара уже ждёт — плыви по розовой стрелке")

func _open_shop() -> void:
	if pond == null:
		return
	sound.play("ui")
	hud.pad.release()
	_fingers.clear()
	shop.open(evo, landscape)

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
	if shop.visible:
		shop.landscape = landscape
		shop.rebuild()


# --- сохранение -----------------------------------------------------------------------

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if pond:
			_save()
			# Свернул игру — вернёшься на паузу, а не в самую гущу.
			if what != NOTIFICATION_WM_CLOSE_REQUEST and not (editor.visible or setup.visible or shop.visible):
				_pause()

## Пауза.
func _pause() -> void:
	if pond == null or pause.visible:
		return
	sound.play("ui")
	hud.pad.release()
	_fingers.clear()
	pause.open()

## Сохранить в свою ячейку. Проверочный запуск (ячейка 0) не сохраняется.
func _save() -> void:
	_save_in = 0.0
	if slot > 0 and evo:
		Saves.save_slot(slot, evo)


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
	_debug = true
	_show_menu = args.has("menu")
	_prof_on = args.has("profile")
	evo = Evolution.create(args.get("difficulty", "normal"))
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
	if args.has("brood"):
		evo.brood = int(args.brood)
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
		"mate":
			pond.call_mate()
		"mated":
			pond.mate.pos = pond.player.pos + Vector2(pond.player.radius + pond.mate.radius, 0)
		"rock":
			var q := p[1].split(",")
			pond.add_rock(q[0], pond.player.pos + Vector2(float(q[1]), float(q[2])))
		"open":
			if p[1] == "settings":
				_open_settings()
			elif p[1] == "shop":
				_open_shop()
			elif p[1] == "atlas":
				editor.open(evo, landscape, false)
			else:
				_open_editor()
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
			editor._preview.ghost_id = editor.selected
			editor._refresh_stats()
		"mode":
			editor.mode = p[1]
			editor.parts_shown = p[1] == "parts"
			editor.rebuild()
		"pull":
			var ad := p[1].split(",")
			var before: Array = editor.evo.shape.duplicate()
			editor.evo.reshape(float(ad[0]), float(ad[1]), editor.mirror, editor.brush)
			editor.shape_done(before)
		"grab":
			# Показать взятую ручку формы (для снимков): номер точки.
			editor._preview.grab = int(p[1])
			editor._preview._before = editor.evo.shape.duplicate()
		"big":
			editor.big = true
			editor.rebuild()
		"hideparts":
			editor.parts_shown = false
			editor.rebuild()
		"carry":
			# Тащим часть из списка (для снимков): id,x,y — точка экрана.
			var q := p[1].split(",")
			editor._select(q[0])
			editor.carrying = true
			editor._carry_id = q[0]
			editor.carry_pos = Vector2(float(q[1]), float(q[2]))
			var local: Vector2 = editor.carry_pos - editor._preview.global_position
			editor._preview.ghost = editor._preview._ghost_at(local)
			editor._preview.ghost_id = q[0]
			editor._refresh_stats()
			editor._carry_layer.queue_redraw()
		"shape":
			evo.set_shape(p[1])
			pond.player.sync_player(evo)
		"reveal":
			hud.reveal_part(p[1], p.size() > 2)
			hud.editor_btn.badge = "!"
		"buy":
			shop._buy(p[1])
		"close":
			editor.visible = false
			setup.visible = false
			shop.visible = false
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
		"giant":
			# Позвать гиганта рядом (для снимков).
			var g := pond.spawn(p[1], pond.player.pos + Vector2(320, 0))
			g.ai_goal = pond.player.pos - Vector2(3000, 0)
		"hp":
			for m in pond.mobs:
				if Pond.is_giant(m):
					m.hp = m.max_hp * float(p[1])
		"ability":
			pond.use_ability()
		"grow":
			# Дорасти до следующего размера (для снимков).
			var lv := evo.level()
			if lv < Content.LEVELS.size():
				pond._gain(float(Content.LEVELS[lv].dna) - evo.dna_total + 0.5)
				view.effects(pond.events)
				_handle(pond.events)
		"pause":
			_pause()
		"drag":
			# Провести пальцем от точки к точке (x0,y0,x1,y1) — как настоящее касание.
			var q := p[1].split(",")
			var a0 := Vector2(float(q[0]), float(q[1]))
			var a1 := Vector2(float(q[2]), float(q[3]))
			var down := InputEventScreenTouch.new()
			down.position = a0
			down.pressed = true
			Input.parse_input_event(down)
			var steps := 12
			for i in range(1, steps + 1):
				var mv := InputEventScreenDrag.new()
				mv.position = a0.lerp(a1, float(i) / steps)
				mv.relative = (a1 - a0) / steps
				Input.parse_input_event(mv)
			var up := InputEventScreenTouch.new()
			up.position = a1
			up.pressed = false
			Input.parse_input_event(up)
		"body":
			print("ТЕЛО: ", evo.body.map(func(b): return "%s@%d" % [b.id, b.a]), " ДНК ", evo.dna_free(), " нос %.2f бок %.2f" % [evo.shape[0], evo.shape[4]])
		"undo":
			editor._undo_step(-1)
		"sounds":
			setup._sounds_open = true
			setup.rebuild()
			var to := int(p[1]) if p.size() > 1 else 0
			get_tree().create_timer(0.3).timeout.connect(func(): setup._body.get_child(1).scroll_vertical = to)
		"myhp":
			pond.player.hp = pond.player.max_hp * float(p[1])
		"event":
			pond.start_event(p[1])
			pond.event_k = 1.0
			backdrop.event = p[1]
			backdrop.event_k = 1.0
		"kill":
			# Все рядом погибают — посмотреть, какое остаётся мясо (для снимков).
			for m in pond.mobs:
				if m.pos.distance_to(pond.player.pos) < 400.0:
					m.alive = false
		"gen":
			# Запомнить нынешнее тело как новое поколение (для снимков родословной).
			evo.remember()
			evo.generation += 1
		"part":
			var q := p[1].split(",")
			evo.unlocked[q[0]] = evo.unlocked.get(q[0], 1)
			evo.body.append({"id": q[0], "a": int(q[1]), "d": float(q[2]) if q.size() > 2 else 1.0})
			pond.player.sync_player(evo)
		"pattern":
			var q := p[1].split(",")
			evo.pattern = q[0]
			if q.size() > 1:
				evo.color2 = int(q[1])
			if q.size() > 2:
				evo.color = int(q[2])
		"arena":
			pond.start_arena()
		"sandbox":
			menu.sandbox.emit()
		"tab":
			editor.tab = p[1]
			editor.rebuild()
		"menu":
			_to_menu()
		"banner":
			hud.announce("Размер 3", "Места на теле больше: 5. Вокруг появятся новые клетки")
		"print":
			if pond == null:
				print("СОСТОЯНИЕ: меню")
				return
			print("СОСТОЯНИЕ: размер ", evo.level(), " ДНК ", evo.dna_free(), "/", int(evo.dna_total), " клеток ", pond.mobs.size(), " еды ", pond.food.size(), " поз ", pond.player.pos)
