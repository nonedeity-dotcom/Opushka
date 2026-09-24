## Список, который листается пальцем.
##
## Встроенная прокрутка Godot ловит касание, только если оно дошло до самого списка, а
## кнопки-плитки внутри его перехватывают — и список на телефоне не листался. Здесь касания
## слушаются напрямую: палец сдвинулся больше чем на 14 точек — это прокрутка, и кнопка под
## пальцем уже не нажмётся. Отпустил на ходу — список ещё немного едет по инерции.
extends ScrollContainer

const DEADZONE := 14.0

var _index := -1
var _from := Vector2.ZERO
var _start := 0.0
var _dragging := false
var _speed := 0.0


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL

func _input(e: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if e is InputEventScreenTouch:
		if e.pressed and _index == -1 and get_global_rect().has_point(e.position):
			_index = e.index
			_from = e.position
			_start = scroll_vertical
			_dragging = false
			_speed = 0.0
		elif not e.pressed and e.index == _index:
			_index = -1
			if _dragging:
				_dragging = false
				get_viewport().set_input_as_handled()
	elif e is InputEventScreenDrag and e.index == _index:
		var dy: float = e.position.y - _from.y
		if not _dragging and absf(dy) > DEADZONE:
			_dragging = true
			_from = e.position
			_start = scroll_vertical
			# Кнопка под пальцем узнаёт, что это прокрутка, и не нажмётся.
			propagate_notification(NOTIFICATION_SCROLL_BEGIN)
		if _dragging:
			scroll_vertical = int(_start - (e.position.y - _from.y))
			_speed = -e.velocity.y
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _index == -1 and absf(_speed) > 20.0:
		scroll_vertical += int(_speed * delta)
		_speed *= exp(-4.0 * delta)
