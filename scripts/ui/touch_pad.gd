## Джойстик или крестовина — один круг, который сам ловит свои касания.
##
## Касание запоминается по номеру пальца: пока этот палец на круге, круг его ведёт, а
## остальные пальцы свободны — ими жмут «Срубить», не отпуская джойстик. Этого и не хватало
## в версии из Core, где на весь экран было одно касание.
##
## Джойстик аналоговый: идти можно в любую сторону, не только по четырём, и чем дальше палец
## от середины — тем быстрее. Крестовина — четыре стороны и одна скорость.
extends Control

signal moved(vector: Vector2)

var mode := "stick"
var floating := false
## Куда и насколько сильно: длина 0–1.
var vector := Vector2.ZERO
var _index := -1
var _knob := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _center() -> Vector2:
	return get_global_rect().get_center()

func _input(e: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if e is InputEventScreenTouch:
		if e.pressed and _index == -1 and e.position.distance_to(_center()) <= size.x * 0.58:
			_index = e.index
			_track(e.position)
			get_viewport().set_input_as_handled()
		elif not e.pressed and e.index == _index:
			release()
			get_viewport().set_input_as_handled()
	elif e is InputEventScreenDrag and e.index == _index:
		_track(e.position)
		get_viewport().set_input_as_handled()

func release() -> void:
	_index = -1
	_knob = Vector2.ZERO
	_emit(Vector2.ZERO)
	queue_redraw()

func _track(p: Vector2) -> void:
	var local := p - _center()
	var r := size.x / 2.0
	var reach := r * 0.6
	var dead := r * 0.12
	_knob = local.limit_length(reach)
	var out := Vector2.ZERO
	var dist := local.length()
	if dist > dead:
		if mode == "stick":
			out = local.normalized() * clampf((dist - dead) / (reach - dead), 0.35, 1.0)
		elif absf(local.x) > absf(local.y):
			out = Vector2(signf(local.x), 0)
		else:
			out = Vector2(0, signf(local.y))
	_emit(out)
	queue_redraw()

func _emit(v: Vector2) -> void:
	if v.is_equal_approx(vector):
		return
	vector = v
	moved.emit(v)

func _draw() -> void:
	var c := size / 2.0
	var r := size.x / 2.0
	draw_circle(c, r, Color(0.07, 0.08, 0.1, 0.5) if floating else Art.CARD)
	draw_arc(c, r - 1, 0, TAU, 64, Color(1, 1, 1, 0.1), 2, true)
	if mode == "stick":
		for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var on := vector.length() > 0.01 and vector.normalized().dot(d) > 0.7
			draw_circle(c + d * r * 0.8, 5, Art.GREEN if on else Color(1, 1, 1, 0.22))
		var knob_on := _index != -1
		draw_circle(c + _knob, r * 0.4, Color(0.56, 0.72, 0.6, 0.55) if knob_on else Color(1, 1, 1, 0.14))
		draw_arc(c + _knob, r * 0.4, 0, TAU, 48, Art.GREEN if knob_on else Color(1, 1, 1, 0.3), 3, true)
	else:
		var a := r * 0.34
		for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var on := vector.normalized().is_equal_approx(d)
			var p: Vector2 = c + d * (r - a - 4)
			draw_circle(p, a, Art.GREEN if on else Color(1, 1, 1, 0.07))
			# Стрелка-шеврон в сторону d.
			var side := Vector2(-d.y, d.x)
			var tip: Vector2 = p + d * a * 0.35
			var col := Art.BG if on else Art.TEXT
			draw_polyline(PackedVector2Array([tip - d * a * 0.45 + side * a * 0.45, tip, tip - d * a * 0.45 - side * a * 0.45]), col, 5, true)
