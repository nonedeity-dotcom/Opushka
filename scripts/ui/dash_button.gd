## Большая круглая кнопка «Рывок». Ловит свои касания сама — её можно жать, не отпуская
## джойстик. Пока рывок перезаряжается, по краю идёт дуга.
extends Control

signal pressed

var floating := false
## 0 — готов, 1 — только что сделан.
var cooldown := 0.0
var _index := -1
var _down := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_cooldown(k: float) -> void:
	k = clampf(k, 0.0, 1.0)
	if absf(k - cooldown) > 0.01 or (k == 0.0) != (cooldown == 0.0):
		cooldown = k
		queue_redraw()

func _center() -> Vector2:
	var r := get_global_rect()
	return r.position + Vector2(r.size.x / 2.0, r.size.x / 2.0)

func _input(e: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if e is InputEventScreenTouch:
		var inside: bool = e.position.distance_to(_center()) <= size.x * 0.58
		if e.pressed and _index == -1 and inside:
			_index = e.index
			_down = true
			queue_redraw()
			get_viewport().set_input_as_handled()
			# Жмётся сразу при касании, а не при отпускании: рывок нужен в ту же секунду.
			pressed.emit()
		elif not e.pressed and e.index == _index:
			_index = -1
			_down = false
			queue_redraw()
			get_viewport().set_input_as_handled()

func _draw() -> void:
	var d := size.x
	var c := Vector2(d / 2.0, d / 2.0)
	var r := d / 2.0 * (0.94 if _down else 1.0)
	var ready := cooldown <= 0.0
	var bg := Color(0.3, 0.55, 0.47, 0.95) if ready else (Color(0.05, 0.1, 0.13, 0.6) if floating else Art.CARD)
	draw_circle(c + Vector2(0, 4), r, Color(0, 0, 0, 0.25))
	draw_circle(c, r, bg)
	if not ready:
		draw_arc(c, r - 5, -PI / 2, -PI / 2 + TAU * (1.0 - cooldown), 48, Art.GREEN, 6, true)
	draw_arc(c, r - 2, 0, TAU, 64, Color(1, 1, 1, 0.18), 3, true)
	Icons.draw(self, "dash", Rect2(c - Vector2(r, r) * 0.5, Vector2(r, r)), Art.TEXT if ready else Art.MUTED)
	var font := get_theme_default_font()
	var text := "Рывок"
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var pos := Vector2(c.x - w / 2.0, d + 28)
	if floating:
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color(0, 0, 0, 0.7))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Art.TEXT)
