## Атлас суши: все виды острова. Встретил — видно, какой он, что ест, где живёт и чем
## опасен; не встречал — тёмный силуэт и подсказка, где искать. Существо крутится в окне
## справа.
extends Control

signal closed

var evo: Evolution
var _list: VBoxContainer
var _title: Label
var _name: Label
var _text: Label
var _view: SubViewport
var _cr: Creature3D
var _sel := ""

func open(e: Evolution) -> void:
	evo = e
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.06, 0.08, 0.94)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := Kit.hbox(18)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24
	root.offset_right = -24
	root.offset_top = 18
	root.offset_bottom = -18
	add_child(root)
	# Слева — список.
	var left := Kit.vbox(8)
	left.custom_minimum_size.x = 330
	root.add_child(left)
	var top := Kit.hbox(10)
	var close := _button("✕", Art.CARD_BORDER, func(): closed.emit())
	close.custom_minimum_size = Vector2(56, 52)
	top.add_child(close)
	_title = Kit.label("", 22, Art.GOLD, true)
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_title)
	left.add_child(top)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(sc)
	_list = Kit.vbox(6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	# Справа — существо и описание.
	var right := Kit.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(right)
	var box := SubViewportContainer.new()
	box.stretch = true
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(box)
	_view = SubViewport.new()
	_view.own_world_3d = true
	box.add_child(_view)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#1c3a44")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.75, 0.8)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	_view.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-30), 0)
	_view.add_child(sun)
	var ground := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 6.0
	disc.bottom_radius = 6.0
	disc.height = 0.1
	ground.mesh = disc
	ground.material_override = Creature3D.mat(Color("#5a8a4a"), 1.0)
	ground.position.y = -0.05
	_view.add_child(ground)
	var cam := Camera3D.new()
	cam.name = "Cam"
	cam.fov = 40.0
	_view.add_child(cam)
	_name = Kit.label("", 26, Art.TEXT, true)
	right.add_child(_name)
	_text = Kit.label("", 18, Art.MUTED)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.y = 130
	right.add_child(_text)
	_fill()
	var first := ""
	for sid in LandSpecies.SPECIES:
		if evo.land_seen.has(sid):
			first = sid
			break
	show_species(first if first != "" else LandSpecies.SPECIES.keys()[0])

func _button(text: String, bg: Color, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", 20)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, Kit.box(bg, 14))
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Art.TEXT)
	b.pressed.connect(action)
	Kit.press_fx(b)
	return b

func _fill() -> void:
	var seen := 0
	for tier in [["pack", "Стаи — твоего размера"], ["hermit", "Отшельники — вдвое крупнее"], ["giant", "Гиганты — огромные"]]:
		_list.add_child(Kit.label(tier[1], 17, Art.GOLD, true))
		for sid in LandSpecies.of_tier(tier[0]):
			var known: bool = evo.land_seen.has(sid)
			if known:
				seen += 1
			var b := _button(LandSpecies.SPECIES[sid].name if known else "???", Art.CARD if known else Color(0.1, 0.12, 0.14), func(): show_species(sid))
			b.custom_minimum_size.y = 48
			_list.add_child(b)
	_title.text = "Атлас суши: %d из %d" % [seen, LandSpecies.SPECIES.size()]

## Показать вид: крутящееся существо (не встречал — тёмное) и описание.
func show_species(sid: String) -> void:
	_sel = sid
	var sp: Dictionary = LandSpecies.SPECIES[sid]
	var known: bool = evo.land_seen.has(sid)
	if _cr:
		_cr.queue_free()
	_cr = Creature3D.new()
	_view.add_child(_cr)
	var look := LandSpecies.look(sid)
	var c: Color = Color(sp.colors[0][0]) if known else Color("#15181c")
	var c2: Color = Color(sp.colors[0][1]) if known else Color("#15181c")
	_cr.build_body(c, c2, 1.0, look.parts, look.pattern if known else "none", look.shape)
	_cr.update(0.0, Vector3.ZERO, 0.6, Vector3.ZERO)
	var cam := _view.get_node("Cam") as Camera3D
	var ext := _cr.extent()
	cam.position = Vector3(0, ext * 0.55 + 0.6, ext * 1.9 + 2.2)
	cam.look_at(Vector3(0, _cr.height() * 0.45, 0), Vector3.UP)
	_name.text = sp.name if known else "??? — ещё не встречал"
	_text.text = describe(sid) if known else hint(sid)
	_name.add_theme_color_override("font_color", Art.TEXT if known else Art.MUTED)

func _process(delta: float) -> void:
	if _cr:
		_cr.rotation.y += delta * 0.5

## Что за вид — простыми словами.
static func describe(sid: String) -> String:
	var sp: Dictionary = LandSpecies.SPECIES[sid]
	var out: Array = []
	match sp.tier:
		"pack":
			out.append("Стая твоего размера, живёт у своего гнезда, есть вожак.")
		"hermit":
			out.append("Отшельник: одиночка вдвое крупнее тебя. Подойдёшь — бросится, пока не выдохнется.")
		"giant":
			out.append("Гигант: огромный и очень сильный, стережёт свои места. Побеждённый оставляет находку.")
	if sp.diet == "plant":
		out.append("Ест плоды" + (" — достаёт прямо с деревьев." if sp.get("tree", false) else ": носит их с кустов и из-под деревьев в гнездо." if sp.tier == "pack" else "."))
	else:
		out.append("Хищник" + (": охотится на чужих сборщиков и носит мясо домой." if sp.tier == "pack" else "."))
	if sp.get("night", false):
		out.append("Выходит ночью, днём спит в гнезде.")
	if sp.get("skittish", false):
		out.append("Пугливый: удирает издалека.")
	if sp.has("poison"):
		out.append("Укус ядовитый.")
	if sp.tier == "pack" and sp.diet == "plant":
		out.append("С ним можно подружиться: носи плоды в его гнездо.")
	out.append("Опасность: " + {"pack": "средняя — нападает всей стаей", "hermit": "большая", "giant": "очень большая"}[sp.tier] + ".")
	return " ".join(out)

## Где искать того, кого ещё не встречал.
static func hint(sid: String) -> String:
	match LandSpecies.SPECIES[sid].tier:
		"pack":
			return "Живёт стаей у своего гнезда — ищи протоптанные места." + (" Выходит только ночью." if LandSpecies.SPECIES[sid].get("night", false) else "")
		"hermit":
			return "Бродит один, подальше от середины острова."
	return "Стережёт свои места где-то на острове — огромного видно издалека."
