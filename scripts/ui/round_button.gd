## Круглая кнопка со значком: настройки, поворот, эволюция.
extends Button

var icon_name := ""
var badge := ""
var floating := false
var accent := false
## Подпись под кнопкой (пусто — без подписи).
var caption := ""
var _t := 0.0

func _process(delta: float) -> void:
	# С меткой «!» кнопка дышит и светится — зовёт нажать.
	if badge != "":
		_t += delta
		queue_redraw()

func setup(icon_name_: String, tip: String, size_px: float) -> void:
	icon_name = icon_name_
	tooltip_text = tip
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(size_px, size_px)
	size = custom_minimum_size
	queue_redraw()
	if not button_down.is_connected(_squash):
		button_down.connect(_squash)
		button_up.connect(_unsquash)

## Под пальцем кнопка чуть проседает и пружинит обратно.
func _squash() -> void:
	pivot_offset = size / 2.0
	create_tween().tween_property(self, "scale", Vector2(0.9, 0.9), 0.06)

func _unsquash() -> void:
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	var r := size.x / 2.0
	var c := size / 2.0
	var bg := Color(0.05, 0.1, 0.13, 0.62) if floating else Art.CARD
	if accent:
		bg = Color(0.42, 0.2, 0.32, 0.92) if icon_name == "heart" else Color(0.2, 0.36, 0.3, 0.92)
	if is_pressed() and get_draw_mode() == DRAW_PRESSED:
		bg = Art.GREEN_DARK
	if badge != "":
		var glow := 0.5 + 0.5 * sin(_t * 4.0)
		draw_circle(c, r * (1.12 + 0.1 * glow), Color(Art.ACCENT, 0.18 + 0.2 * glow))
	draw_circle(c, r, bg)
	draw_arc(c, r - 1, 0, TAU, 40, Color(1, 1, 1, 0.1), 2, true)
	var inner := Rect2(c - Vector2(r, r) * 0.52, Vector2(r, r) * 1.04)
	if icon_name != "":
		var ic := Art.TEXT
		if accent:
			ic = Color("#f7a8c8") if icon_name == "heart" else Art.GREEN
		Icons.draw(self, icon_name, inner, ic)
	if caption != "":
		var font := get_theme_default_font()
		var fs := 18
		var cw := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := Vector2((size.x - cw) / 2.0, size.y + 26)
		draw_string_outline(font, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.6))
		draw_string(font, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Art.TEXT, 0.85))
	if badge != "":
		var b := Vector2(size.x - 10, 10)
		draw_circle(b, 15, Art.ACCENT)
		var font := get_theme_default_font()
		var w := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_CENTER, -1, 18).x
		draw_string(font, b + Vector2(-w / 2.0, 6), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Art.BG)
