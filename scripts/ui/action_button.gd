## Большая круглая кнопка действия со значком того, что перед тобой: топор у дерева, ягоды
## у куста, луна у костра ночью. Ловит свои касания сама — её можно жать, не отпуская
## джойстик.
extends Control

signal pressed

var label := ""
var icon_id := ""
var floating := false
var _index := -1
var _down := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_action(label_: String, icon_: String) -> void:
	if label_ == label and icon_ == icon_id:
		return
	label = label_
	icon_id = icon_
	queue_redraw()

func _circle() -> Vector2:
	var r := get_global_rect()
	return r.position + Vector2(r.size.x / 2.0, r.size.x / 2.0)

func _input(e: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if e is InputEventScreenTouch:
		var inside: bool = e.position.distance_to(_circle()) <= size.x * 0.56
		if e.pressed and _index == -1 and inside:
			_index = e.index
			_down = true
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif not e.pressed and e.index == _index:
			_index = -1
			_down = false
			queue_redraw()
			get_viewport().set_input_as_handled()
			if inside and label != "":
				pressed.emit()

func _draw() -> void:
	var d := size.x
	var c := Vector2(d / 2.0, d / 2.0)
	var r := d / 2.0 * (0.94 if _down else 1.0)
	var on := label != ""
	var bg := Art.GREEN if on else (Color(0.07, 0.08, 0.1, 0.55) if floating else Art.CARD)
	draw_circle(c + Vector2(0, 4), r, Color(0, 0, 0, 0.25))
	draw_circle(c, r, bg)
	draw_arc(c, r - 2, 0, TAU, 64, Color(1, 1, 1, 0.2), 4, true)
	var inner := Rect2(c - Vector2(r, r) * 0.52, Vector2(r, r) * 1.04)
	Art.item_icon(self, icon_id if icon_id != "" else "hand", inner)
	var font := get_theme_default_font()
	var text := label if on else "Подойди ближе"
	var fs := 24
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	# Подпись шире кнопки: у края экрана сдвигаем её внутрь, чтобы не обрезалась.
	var screen_w := get_viewport_rect().size.x
	var gx := clampf(global_position.x + c.x - w / 2.0, 10.0, screen_w - w - 10.0)
	var pos := Vector2(gx - global_position.x, d + 30)
	if floating:
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.7))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.TEXT if on else Art.MUTED)
