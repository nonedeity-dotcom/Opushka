## Экран суши (пробный): джойстик, поворот камеры пальцем по правой половине, сколько
## съедено, сколько кадров в секунду (проверить, не тормозит ли) и выход в меню.
extends Control

signal back

const TouchPad := preload("res://scripts/ui/touch_pad.gd")
const RoundButton := preload("res://scripts/ui/round_button.gd")

var pad: Control
var world: LandWorld
var _info: Label
var _fps: Label
var _cam_index := -1
var _fps_t := 0.0
## Сценарий проверки ведёт клетку вместо пальца (только из командной строки).
var override := Vector2.ZERO

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad = TouchPad.new()
	pad.floating = true
	add_child(pad)
	var card := Kit.card(Kit.vbox(2), Color(0.04, 0.08, 0.11, 0.7), 20, 14)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = card.get_child(0)
	col.add_child(Kit.label("Суша · пробная версия", 22, Art.TEXT, true))
	_info = Kit.label("", 18, Art.GREEN)
	col.add_child(_info)
	_fps = Kit.label("", 16, Art.MUTED)
	col.add_child(_fps)
	card.position = Vector2(18, 18)
	add_child(card)
	var hint := Kit.muted("Джойстик — идти. Веди пальцем справа — повернуть камеру. Подойди к кусту — съешь плод.", 17)
	hint.name = "Hint"
	add_child(hint)
	var b := RoundButton.new()
	b.setup("close", "В меню", 64)
	b.caption = "В меню"
	b.floating = true
	b.pressed.connect(func(): back.emit())
	b.name = "Back"
	add_child(b)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	var d := 250.0
	pad.size = Vector2(d, d)
	pad.position = Vector2(18, size.y - d - 18)
	var b := get_node("Back") as Control
	b.position = Vector2(size.x - 64 - 22, 18)
	var hint := get_node("Hint") as Label
	hint.size = Vector2(minf(620.0, size.x - 80), 0)
	hint.position = Vector2((size.x - hint.size.x) / 2.0, size.y - 60)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _process(delta: float) -> void:
	if world == null:
		return
	world.input = override if override != Vector2.ZERO else pad.vector
	_info.text = "Съедено плодов: %d" % world.land.eaten
	_fps_t -= delta
	if _fps_t <= 0.0:
		_fps_t = 0.5
		_fps.text = "Кадров в секунду: %d" % Engine.get_frames_per_second()

## Палец справа (не на кнопке) — крутит камеру вокруг тебя.
func _input(e: InputEvent) -> void:
	if not is_visible_in_tree() or world == null:
		return
	if e is InputEventScreenTouch:
		if e.pressed and _cam_index == -1 and e.position.x > size.x * 0.4 and e.position.y > 110:
			_cam_index = e.index
		elif not e.pressed and e.index == _cam_index:
			_cam_index = -1
	elif e is InputEventScreenDrag and e.index == _cam_index:
		world.cam_yaw -= e.relative.x * 0.006
