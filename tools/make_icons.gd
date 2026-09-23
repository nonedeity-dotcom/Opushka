## Рисует иконки приложения из SVG: godot --headless -s tools/make_icons.gd
## Растеризатора SVG в системе нет, а у Godot он свой — им и пользуемся.
extends SceneTree

const TREE := """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <ellipse cx="50" cy="86" rx="30" ry="6" fill="#000" opacity="0.25"/>
  <rect x="45" y="56" width="10" height="30" rx="3" fill="#6b4b2e"/>
  <circle cx="50" cy="42" r="28" fill="#3a6a44"/>
  <circle cx="38" cy="38" r="17" fill="#44794e"/>
  <circle cx="62" cy="31" r="14" fill="#4f8a59"/>
  <circle cx="45" cy="26" r="9" fill="#5a9663"/>
  <circle cx="36" cy="46" r="3.4" fill="#d86a4a"/>
  <circle cx="60" cy="48" r="3.4" fill="#d86a4a"/>
  <path d="M74 84 L74 66 L86 58 L98 66 L98 84 Z" fill="#b08a5a"/>
  <path d="M70 67 L86 54 L102 67 Z" fill="#8e4f3a"/>
  <rect x="83" y="72" width="6" height="12" fill="#5a3a24"/>
</svg>
"""

func _init() -> void:
	var bg := "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><rect width='100' height='100' fill='#2a4231'/><circle cx='50' cy='120' r='70' fill='#34503a'/></svg>"
	var full := "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><rect width='100' height='100' rx='22' fill='#2a4231'/><circle cx='50' cy='120' r='70' fill='#34503a'/>" + TREE.get_slice(">", 1).substr(0, 0) + _inner(TREE, 0.78) + "</svg>"
	_save(full, 192, "res://art/icon_192.png")
	_save(bg, 432, "res://art/icon_bg_432.png")
	# Передний план адаптивной иконки: всё важное — в середине, края система обрежет.
	_save("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'>" + _inner(TREE, 0.6) + "</svg>", 432, "res://art/icon_fg_432.png")
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
