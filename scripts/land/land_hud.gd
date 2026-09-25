## Экран суши: джойстик, «Укус», поворот камеры пальцем по правой половине, сила и путь
## до следующей, здоровье, ДНК, день или ночь, стрелка к своему гнезду, полоса гиганта,
## «Тело» (только в гнезде), «Гнездо сюда» и выход в меню.
extends Control

signal back
signal edit
## Открыли атлас видов (мир на паузе).
signal atlas

const TouchPad := preload("res://scripts/ui/touch_pad.gd")
const RoundButton := preload("res://scripts/ui/round_button.gd")
const DashButton := preload("res://scripts/ui/dash_button.gd")

var pad: Control
var world: LandWorld
var _info: Label
var _fps: Label
var _lvl: Label
var _xp: HpLine
var _time: Label
var _arrow: NestArrow
var _boss: Control
var _boss_line: HpLine
var _boss_name: Label
var _near: Label
var _nest_btn: Control
var _body_btn: Control
## «Гнездо сюда» нажали один раз — ждём второго касания (секунды).
var _nest_confirm := 0.0
var _nest_info: Label
var pick_btn: Control
var eat_btn: Control
## Кнопки умений: умение → кнопка.
var _ab_btns := {}
const AB_LOOK := {"jump": ["dash", "Прыжок"], "roar": ["pulse", "Рёв"], "spit": ["ink", "Плевок"], "dig": ["leaf", "Копать"]}
var _hp: HpLine
var bite_btn: Control
var _red: ColorRect
var _say: Label
var _say_tw: Tween
var _skip: Label
var _intro := false
var _cam_index := -1
var _fps_t := 0.0
## Сценарий проверки ведёт клетку вместо пальца (только из командной строки).
var override := Vector2.ZERO

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_red = ColorRect.new()
	_red.color = Color(0.8, 0.1, 0.1, 0.0)
	_red.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_red.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_red)
	pad = TouchPad.new()
	pad.floating = true
	add_child(pad)
	var card := Kit.card(Kit.vbox(2), Color(0.04, 0.08, 0.11, 0.7), 20, 14)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = card.get_child(0)
	_lvl = Kit.label("Сила 1", 22, Art.GOLD, true)
	col.add_child(_lvl)
	_xp = HpLine.new()
	_xp.gold = true
	_xp.custom_minimum_size = Vector2(260, 8)
	col.add_child(_xp)
	_hp = HpLine.new()
	_hp.custom_minimum_size = Vector2(260, 16)
	col.add_child(_hp)
	_info = Kit.label("", 18, Art.GREEN)
	col.add_child(_info)
	_time = Kit.label("", 17, Art.TEXT)
	col.add_child(_time)
	_nest_info = Kit.label("", 16, Art.GOLD)
	col.add_child(_nest_info)
	_fps = Kit.label("", 14, Art.MUTED)
	col.add_child(_fps)
	card.position = Vector2(18, 18)
	add_child(card)
	var hint := Kit.muted("Добывай ДНК — станешь сильнее. Светящиеся камни — окаменелости: в них новые части. Тело меняют в гнезде — туда ведёт стрелка", 17)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.name = "Hint"
	add_child(hint)
	var b := RoundButton.new()
	b.setup("close", "В меню", 64)
	b.caption = "В меню"
	b.floating = true
	b.pressed.connect(func(): back.emit())
	b.name = "Back"
	add_child(b)
	var body := RoundButton.new()
	body.setup("dna", "Тело", 64)
	body.caption = "Тело"
	body.floating = true
	body.pressed.connect(_on_body)
	body.name = "Body"
	add_child(body)
	_body_btn = body
	var nb := RoundButton.new()
	nb.setup("nest", "Гнездо сюда", 64)
	nb.caption = "Гнездо сюда"
	nb.floating = true
	nb.pressed.connect(_on_nest)
	nb.name = "NestHere"
	add_child(nb)
	_nest_btn = nb
	_arrow = NestArrow.new()
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arrow)
	_near = Kit.label("", 18, Color("#ffd27a"), true)
	_near.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_near.add_theme_constant_override("outline_size", 6)
	_near.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_near.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_near)
	var bc := Kit.card(Kit.vbox(4), Color(0.12, 0.04, 0.05, 0.75), 16, 10)
	bc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_name = Kit.label("Гигант", 18, Color("#ffb0a0"), true)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bc.get_child(0).add_child(_boss_name)
	_boss_line = HpLine.new()
	_boss_line.red = true
	_boss_line.custom_minimum_size = Vector2(380, 14)
	bc.get_child(0).add_child(_boss_line)
	bc.visible = false
	add_child(bc)
	_boss = bc
	_skip = Kit.label("Нажми, чтобы пропустить", 18, Color(1, 1, 1, 0.7))
	_skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip.add_theme_constant_override("outline_size", 6)
	_skip.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	_skip.visible = false
	add_child(_skip)
	bite_btn = DashButton.new()
	bite_btn.icon = "bite"
	bite_btn.caption = "Укус"
	bite_btn.floating = true
	bite_btn.tint = Color(0.62, 0.3, 0.28, 0.95)
	bite_btn.pressed.connect(func(): world.bite_pressed = true)
	add_child(bite_btn)
	pick_btn = _small_btn("suck", "Взять", Color(0.3, 0.5, 0.35, 0.95), func():
		if world.land.pick():
			world.happened.emit({"t": "pick", "pos": world.land.pos}))
	eat_btn = _small_btn("leaf", "Съесть ношу", Color(0.5, 0.4, 0.25, 0.95), func():
		world.land.eat_carry()
		for e in world.land.events:
			world.happened.emit(e)
		world.land.events.clear())
	for id in AB_LOOK:
		var abtn := _small_btn(AB_LOOK[id][0], AB_LOOK[id][1], Color(0.35, 0.32, 0.55, 0.95), func():
			if world.land.use_ability(id):
				for e in world.land.events:
					world.happened.emit(e)
					world.fx_event(e)
				world.land.events.clear())
		_ab_btns[id] = abtn
	var ab := RoundButton.new()
	ab.setup("book", "Атлас", 64)
	ab.caption = "Атлас"
	ab.floating = true
	ab.pressed.connect(func(): atlas.emit())
	ab.name = "Atlas"
	add_child(ab)
	# Подсказка сама тает через полминуты — дальше и так понятно.
	var tw := hint.create_tween()
	tw.tween_interval(25.0)
	tw.tween_property(hint, "modulate:a", 0.0, 1.5)
	_say = Kit.label("", 26, Art.TEXT, true)
	_say.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_say.add_theme_constant_override("outline_size", 8)
	_say.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_say.modulate.a = 0.0
	add_child(_say)
	resized.connect(_layout)
	_layout()

## Тебя ранили — края экрана краснеют.
func hurt() -> void:
	_red.color.a = 0.16

## Короткая надпись посередине сверху.
func say(text: String) -> void:
	_say.text = text
	if _say_tw:
		_say_tw.kill()
	_say.modulate.a = 1.0
	_say_tw = create_tween()
	_say_tw.tween_interval(1.6)
	_say_tw.tween_property(_say, "modulate:a", 0.0, 0.6)

func _small_btn(icon: String, caption: String, tint: Color, action: Callable) -> Control:
	var b := DashButton.new()
	b.icon = icon
	b.caption = caption
	b.floating = true
	b.tint = tint
	b.pressed.connect(action)
	b.visible = false
	add_child(b)
	return b

func _layout() -> void:
	var d := 250.0
	pad.size = Vector2(d, d)
	pad.position = Vector2(18, size.y - d - 18)
	var b := get_node("Back") as Control
	b.position = Vector2(size.x - 64 - 22, 18)
	(get_node("Body") as Control).position = Vector2(size.x - 2 * (64 + 22) - 10, 18)
	_nest_btn.position = Vector2(size.x - 3 * (64 + 22) - 20, 18)
	_arrow.size = Vector2(360, 64)
	_arrow.position = Vector2((size.x - _arrow.size.x) / 2.0, 14)
	_near.size = Vector2(size.x, 30)
	_near.position = Vector2(0, 158)
	_boss.position = Vector2((size.x - 412) / 2.0, 84)
	var hint := get_node("Hint") as Label
	hint.size = Vector2(minf(620.0, size.x - 640), 0)
	hint.position = Vector2((size.x - hint.size.x) / 2.0, size.y - 90)
	var bd := 132.0
	bite_btn.size = Vector2(bd, bd)
	bite_btn.position = Vector2(size.x - bd - 60, size.y - bd - 70)
	var sd := 92.0
	pick_btn.size = Vector2(sd, sd)
	pick_btn.position = bite_btn.position + Vector2(-sd - 36, bd - sd + 20)
	eat_btn.size = Vector2(sd, sd)
	eat_btn.position = pick_btn.position + Vector2(-sd - 24, 0)
	for id in _ab_btns:
		(_ab_btns[id] as Control).size = Vector2(sd, sd)
	(get_node("Atlas") as Control).position = Vector2(size.x - 4 * (64 + 22) - 30, 18)
	_skip.size = Vector2(size.x, 30)
	_skip.position = Vector2(0, size.y - 50)
	_say.size = Vector2(size.x, 40)
	_say.position = Vector2(0, 196)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _process(delta: float) -> void:
	if world == null:
		return
	world.input = override if override != Vector2.ZERO else pad.vector
	# Пока идёт сцена выхода из воды — кнопок нет, только «пропустить».
	var intro := world.intro_t >= 0.0
	if intro != _intro:
		_intro = intro
		for ch in get_children():
			if ch != _say and ch != _red:
				(ch as CanvasItem).visible = not intro
		_skip.visible = intro
	_red.color.a = maxf(0.0, _red.color.a - delta * 0.6)
	var l := world.land
	var lv := l.evo.land_level()
	var pr := LandParts.level_progress(l.evo.land_xp)
	_lvl.text = "Сила %d" % lv + ("" if lv < LandParts.LEVELS.size() else " — наибольшая")
	_xp.k = pr[1]
	_xp.queue_redraw()
	_info.text = "ДНК: %d" % l.evo.land_free() + (" · до силы %d: %d" % [lv + 1, int(ceil(pr[0]))] if lv < LandParts.LEVELS.size() else "")
	_hp.k = l.hp / l.max_hp
	_hp.queue_redraw()
	_time.text = ("Ночь" if l.is_night() else ("Закат" if Land.daylight(l.day) < 1.0 and l.day < 0.7 else ("Рассвет" if Land.daylight(l.day) < 1.0 else "День"))) \
		+ {"clear": "", "rain": " · дождь", "fog": " · туман", "storm": " · гроза"}[l.weather]
	var own := l.allies().size()
	_nest_info.text = ("Гнездо: запасы %d · своих %d" % [l.stash, own] + (" · яиц %d" % l.eggs.size() if not l.eggs.is_empty() else "")) if l.has_nest else ""
	# Взять, съесть ношу, умения: только то, что можно сейчас.
	pick_btn.visible = not intro and l.can_pick()
	eat_btn.visible = not intro and not l.carry.is_empty()
	eat_btn.caption = "Съесть ношу (%d)" % l.carry.size() if l.carry.size() > 1 else "Съесть ношу"
	var have := l.abilities()
	var k := 0
	for id in _ab_btns:
		var b: Control = _ab_btns[id]
		b.visible = not intro and have.has(id)
		if b.visible:
			b.position = bite_btn.position + Vector2(bite_btn.size.x - b.size.x + 10 - (b.size.x + 18) * (k / 2), -b.size.y - 30 - (b.size.y + 30) * (k % 2))
			b.set_cooldown(float(l.cd.get(id, 0.0)) / float(Land.ABILITY_CD[id]))
			k += 1
	# Стрелка к гнезду: куда идти относительно камеры и сколько метров.
	_arrow.visible = l.has_nest and not intro
	if l.has_nest:
		var to := Vector2(l.home.x - l.pos.x, l.home.z - l.pos.z)
		var yaw := world.cam_yaw
		var fwd := Vector2(-sin(yaw), -cos(yaw))
		var right := Vector2(cos(yaw), -sin(yaw))
		_arrow.angle = atan2(to.dot(right), to.dot(fwd))
		_arrow.dist = to.length()
		_arrow.home = l.safe()
		_arrow.queue_redraw()
	_body_btn.modulate.a = 1.0 if l.at_nest() or not l.has_nest else 0.55
	_nest_confirm = maxf(0.0, _nest_confirm - delta)
	_nest_btn.visible = not intro and l.has_nest and (l.pos - l.home).length() > 25.0 and not _danger(l)
	# Гигант рядом — его полоса здоровья.
	var g = null
	for m in l.mobs:
		if m.kind == "giant" and (m.pos as Vector3).distance_to(l.pos) < 26.0:
			g = m
	_boss.visible = g != null and not intro
	if g != null:
		_boss_name.text = LandSpecies.SPECIES[g.sp].name
		_boss_line.k = g.hp / g.max_hp
		_boss_line.queue_redraw()
	# Окаменелость рядом — подсказка.
	var near := false
	for r in l.relics:
		if (r.pos as Vector3).distance_to(l.pos) < 22.0:
			near = true
	_near.text = "Рядом окаменелость — разбей её, внутри находка" if near and not intro else ""
	bite_btn.set_cooldown(l.bite_cd / Land.BITE_CD)
	_fps_t -= delta
	if _fps_t <= 0.0:
		_fps_t = 0.5
		_fps.text = "Кадров в секунду: %d" % Engine.get_frames_per_second()

## Рядом кто-то злой (тогда гнездо не перенести).
func _danger(l: Land) -> bool:
	for m in l.mobs:
		if m.angry > 0.0 and (m.pos as Vector3).distance_to(l.pos) < 20.0:
			return true
	return false

## «Тело»: менять тело можно только в своём гнезде.
func _on_body() -> void:
	var l := world.land
	if l.at_nest() or not l.has_nest:
		edit.emit()
	else:
		say("Тело меняют в гнезде — иди по стрелке (%d м)" % int(Vector2(l.home.x - l.pos.x, l.home.z - l.pos.z).length()))
		_arrow.pulse = 1.0

## «Гнездо сюда»: второе касание переносит гнездо туда, где стоишь.
func _on_nest() -> void:
	if _nest_confirm <= 0.0:
		_nest_confirm = 3.0
		say("Нажми ещё раз — гнездо будет здесь")
		return
	_nest_confirm = 0.0
	world.land.set_nest(world.land.pos)
	world._trees()
	world.happened.emit({"t": "nest_moved", "pos": world.land.pos})

## Палец справа (не на кнопке) — крутит камеру вокруг тебя (вбок) и наклоняет (вверх-вниз).
## Второй палец рядом — щипок: ближе или дальше.
var _cam_fingers := {}  # номер пальца → где он
var _pinch_d := 0.0
var _pinch_zoom := 1.0

func _input(e: InputEvent) -> void:
	if not is_visible_in_tree() or world == null:
		return
	if _intro:
		if e is InputEventScreenTouch and e.pressed:
			world.finish_intro()
		return
	if e is InputEventScreenTouch:
		var on_bite: bool = e.position.distance_to(bite_btn.get_global_rect().get_center()) < bite_btn.size.x * 0.7
		if e.pressed and e.position.x > size.x * 0.4 and e.position.y > 110 and not on_bite and not _on_button(e.position):
			_cam_fingers[e.index] = e.position
			_cam_index = e.index
			_pinch_start()
		elif not e.pressed and _cam_fingers.has(e.index):
			_cam_fingers.erase(e.index)
			_cam_index = _cam_fingers.keys()[0] if not _cam_fingers.is_empty() else -1
			_pinch_start()
	elif e is InputEventScreenDrag and _cam_fingers.has(e.index):
		_cam_fingers[e.index] = e.position
		world.cam_touch_t = 0.0
		if _cam_fingers.size() >= 2:
			var ps: Array = _cam_fingers.values()
			var d: float = (ps[0] as Vector2).distance_to(ps[1])
			if _pinch_d > 10.0:
				world.cam_zoom = clampf(_pinch_zoom * _pinch_d / maxf(d, 1.0), 0.55, 2.2)
		else:
			world.cam_yaw -= e.relative.x * 0.006
			world.cam_pitch = clampf(world.cam_pitch + e.relative.y * 0.004, LandWorld.PITCH_MIN, LandWorld.PITCH_MAX)

func _pinch_start() -> void:
	if _cam_fingers.size() >= 2:
		var ps: Array = _cam_fingers.values()
		_pinch_d = (ps[0] as Vector2).distance_to(ps[1])
		_pinch_zoom = world.cam_zoom
	else:
		_pinch_d = 0.0

func _on_button(p: Vector2) -> bool:
	for b in [get_node("Back"), _body_btn, _nest_btn]:
		if (b as Control).visible and (b as Control).get_global_rect().grow(10).has_point(p):
			return true
	return false

## Полоска здоровья: красная, по краю — тёмная подложка.
class HpLine:
	extends Control
	var k := 1.0
	## Полоса силы — золотая, гиганта — красная.
	var gold := false
	var red := false

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0, 0, 0, 0.4))
		var c := Color("#e0484a") if k < 0.35 or red else Color("#6fcf6a")
		if gold:
			c = Art.GOLD
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * clampf(k, 0.0, 1.0), size.y)), c)

## Стрелка к своему гнезду: круг со стрелкой (куда идти, если смотреть с камеры) и
## сколько метров. В гнезде — «Ты в гнезде».
class NestArrow:
	extends Control
	var angle := 0.0
	var dist := 0.0
	var home := false
	## Мигнуть (нажали «Тело» вдали от гнезда).
	var pulse := 0.0

	func _process(delta: float) -> void:
		if pulse > 0.0:
			pulse = maxf(0.0, pulse - delta * 0.7)
			queue_redraw()

	func _draw() -> void:
		var font := get_theme_default_font()
		var text := "Ты в гнезде: тут лечишься и меняешь тело" if home else "Гнездо · %d м" % int(dist)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		var total := w + (0.0 if home else 52.0) + 28.0
		var x0 := (size.x - total) / 2.0
		var glow := 0.5 + 0.5 * sin(pulse * 18.0) if pulse > 0.0 else 0.0
		draw_style_box(Kit.box(Color(0.04, 0.08, 0.11, 0.7).lerp(Color(0.5, 0.4, 0.1, 0.9), glow), 20, Color(0, 0, 0, 0), 0), Rect2(x0, 6, total, 46))
		var tx := x0 + 14.0
		if not home:
			var c := Vector2(x0 + 34, 29)
			draw_circle(c, 17, Color(1, 1, 1, 0.12))
			var d := Vector2(sin(angle), -cos(angle))
			var side := Vector2(-d.y, d.x)
			draw_colored_polygon(PackedVector2Array([c + d * 14, c - d * 9 + side * 9, c - d * 4, c - d * 9 - side * 9]), Art.GOLD)
			tx = x0 + 60.0
		draw_string(font, Vector2(tx, 36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Art.GOLD if home else Art.TEXT)
