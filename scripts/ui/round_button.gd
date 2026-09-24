## Круглая кнопка со значком: сумка, настройки, поворот, «съесть», «разобрать».
extends Button

var icon_name := ""
var item := ""  # если задано — рисуется значок вещи
var badge := ""
var floating := false

func setup(icon_name_: String, tip: String, size_px: float) -> void:
	icon_name = icon_name_
	tooltip_text = tip
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(size_px, size_px)
	size = custom_minimum_size
	queue_redraw()

func _draw() -> void:
	var r := size.x / 2.0
	var c := size / 2.0
	var bg := Color(0.07, 0.08, 0.1, 0.62) if floating else Art.CARD
	if button_pressed or is_pressed() and get_draw_mode() == DRAW_PRESSED:
		bg = Art.GREEN_DARK
	draw_circle(c, r, bg)
	draw_arc(c, r - 1, 0, TAU, 40, Color(1, 1, 1, 0.08), 2, true)
	var inner := Rect2(c - Vector2(r, r) * 0.55, Vector2(r, r) * 1.1)
	if item != "":
		Art.item_icon(self, item, inner.grow(r * 0.1))
	elif icon_name != "":
		Icons.draw(self, icon_name, inner, Art.TEXT)
	if badge != "":
		var b := Vector2(size.x - 8, 8)
		draw_circle(b, 15, Art.ACCENT)
		var font := get_theme_default_font()
		var w := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_CENTER, -1, 18).x
		draw_string(font, b + Vector2(-w / 2.0, 6), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Art.BG)
