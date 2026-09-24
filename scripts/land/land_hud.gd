## Экран суши (пробный): джойстик, «Укус», поворот камеры пальцем по правой половине,
## здоровье и ДНК, сколько кадров в секунду (проверить, не тормозит ли) и выход в меню.
extends Control

signal back
signal edit

const TouchPad := preload("res://scripts/ui/touch_pad.gd")
const RoundButton := preload("res://scripts/ui/round_button.gd")
const DashButton := preload("res://scripts/ui/dash_button.gd")

var pad: Control
var world: LandWorld
var _info: Label
var _fps: Label
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
	col.add_child(Kit.label("Суша · пробная версия", 22, Art.TEXT, true))
	_hp = HpLine.new()
	_hp.custom_minimum_size = Vector2(260, 16)
	col.add_child(_hp)
	_info = Kit.label("", 18, Art.GREEN)
	col.add_child(_info)
	_fps = Kit.label("", 16, Art.MUTED)
	col.add_child(_fps)
	card.position = Vector2(18, 18)
	add_child(card)
	var hint := Kit.muted("Кусай кости — будет ДНК. Яйца в гнёздах вкусные, но стая их стережёт. Большие с шипами — отшельники: сильные, держись подальше", 17)
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
	body.pressed.connect(func(): edit.emit())
	body.name = "Body"
	add_child(body)
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

func _layout() -> void:
	var d := 250.0
	pad.size = Vector2(d, d)
	pad.position = Vector2(18, size.y - d - 18)
	var b := get_node("Back") as Control
	b.position = Vector2(size.x - 64 - 22, 18)
	(get_node("Body") as Control).position = Vector2(size.x - 2 * (64 + 22) - 10, 18)
	var hint := get_node("Hint") as Label
	hint.size = Vector2(minf(620.0, size.x - 640), 0)
	hint.position = Vector2((size.x - hint.size.x) / 2.0, size.y - 90)
	var bd := 132.0
	bite_btn.size = Vector2(bd, bd)
	bite_btn.position = Vector2(size.x - bd - 60, size.y - bd - 70)
	_skip.size = Vector2(size.x, 30)
	_skip.position = Vector2(0, size.y - 50)
	_say.size = Vector2(size.x, 40)
	_say.position = Vector2(0, 110)
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
	_info.text = "ДНК: %d · здесь добыто %d" % [l.evo.land_free(), int(l.dna)]
	_hp.k = l.hp / l.max_hp
	_hp.queue_redraw()
	bite_btn.set_cooldown(l.bite_cd / Land.BITE_CD)
	_fps_t -= delta
	if _fps_t <= 0.0:
		_fps_t = 0.5
		_fps.text = "Кадров в секунду: %d" % Engine.get_frames_per_second()

## Палец справа (не на кнопке) — крутит камеру вокруг тебя.
func _input(e: InputEvent) -> void:
	if not is_visible_in_tree() or world == null:
		return
	if _intro:
		if e is InputEventScreenTouch and e.pressed:
			world.finish_intro()
		return
	if e is InputEventScreenTouch:
		var on_bite: bool = e.position.distance_to(bite_btn.get_global_rect().get_center()) < bite_btn.size.x * 0.7
		if e.pressed and _cam_index == -1 and e.position.x > size.x * 0.4 and e.position.y > 110 and not on_bite:
			_cam_index = e.index
		elif not e.pressed and e.index == _cam_index:
			_cam_index = -1
	elif e is InputEventScreenDrag and e.index == _cam_index:
		world.cam_yaw -= e.relative.x * 0.006

## Полоска здоровья: красная, по краю — тёмная подложка.
class HpLine:
	extends Control
	var k := 1.0

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0, 0, 0, 0.4))
		var c := Color("#e0484a") if k < 0.35 else Color("#6fcf6a")
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * clampf(k, 0.0, 1.0), size.y)), c)
