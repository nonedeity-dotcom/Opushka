## Рисует иконки приложения из SVG: godot --headless -s tools/make_icons.gd
## Растеризатора SVG в системе нет, а у Godot он свой — им и пользуемся.
extends SceneTree

const CELL := """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <path d="M22 60 Q14 52 8 58 Q2 64 -4 56" stroke="#3f8a5a" stroke-width="4" fill="none" stroke-linecap="round"/>
  <path d="M22 60 Q14 52 8 58 Q2 64 -4 56" stroke="#a8e8b8" stroke-width="1.6" fill="none" stroke-linecap="round"/>
  <polygon points="50,14 54,28 46,28" fill="#efdfa8"/>
  <polygon points="50,86 54,72 46,72" fill="#efdfa8"/>
  <ellipse cx="54" cy="52" rx="32" ry="30" fill="#8fd07a"/>
  <ellipse cx="54" cy="52" rx="32" ry="30" fill="none" stroke="#3f6a38" stroke-width="3"/>
  <ellipse cx="62" cy="44" rx="17" ry="12" fill="#ffffff" opacity="0.18"/>
  <circle cx="46" cy="56" r="10" fill="#5f9a52"/>
  <circle cx="47" cy="54" r="3.4" fill="#3d6a36"/>
  <circle cx="74" cy="44" r="6.5" fill="#f4f4ec"/>
  <circle cx="76" cy="44" r="3.2" fill="#1e1e28"/>
  <path d="M84 56 L94 51 L92 58 L94 64 L84 60 Z" fill="#e9dcc6"/>
</svg>
"""

func _init() -> void:
	var bg := "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><rect width='100' height='100' fill='#123a48'/><circle cx='50' cy='-20' r='70' fill='#1d5566'/></svg>"
	var full := "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><rect width='100' height='100' rx='22' fill='#123a48'/><circle cx='50' cy='-20' r='70' fill='#1d5566'/>" + CELL.get_slice(">", 1).substr(0, 0) + _inner(CELL, 0.78) + "</svg>"
	_save(full, 192, "res://art/icon_192.png")
	_save(bg, 432, "res://art/icon_bg_432.png")
	# Передний план адаптивной иконки: всё важное — в середине, края система обрежет.
	_save("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'>" + _inner(CELL, 0.6) + "</svg>", 432, "res://art/icon_fg_432.png")
	quit()

## Содержимое SVG, уменьшенное к центру.
func _inner(svg: String, k: float) -> String:
	var body := svg.substr(svg.find(">", svg.find("<svg")) + 1)
	body = body.substr(0, body.rfind("</svg>"))
	var off := 50.0 * (1.0 - k)
	return "<g transform='translate(%f %f) scale(%f)'>%s</g>" % [off, off, k, body]

func _save(svg: String, size: int, path: String) -> void:
	var img := Image.new()
	var err := img.load_svg_from_string(svg, size / 100.0)
	if err != OK:
		push_error("svg: %s" % path)
		return
	img.save_png(path)
	print("%s %dx%d" % [path, img.get_width(), img.get_height()])
