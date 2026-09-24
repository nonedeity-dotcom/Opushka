## Туман: без глаз видно только себя и то, что рядом. Каждый глаз раздвигает туман.
##
## Прямоугольник на весь экран с шейдером: прозрачная середина вокруг клетки, мутная вода
## дальше. Мутность чуть шевелится, чтобы туман не казался нарисованной рамкой.
extends ColorRect

const SHADER := """
shader_type canvas_item;
uniform vec2 center;
uniform float radius;
uniform float soft;
uniform vec2 rect_size;
uniform float time;
uniform vec4 fog_color : source_color;
uniform vec3 lights[8];
uniform int light_count;

void fragment() {
	vec2 p = UV * rect_size;
	float d = distance(p, center);
	float k = smoothstep(radius - soft, radius + soft * 0.6, d);
	// Светящиеся существа видны и в тумане — вокруг них своё маленькое окошко.
	for (int i = 0; i < 8; i++) {
		if (i >= light_count) { break; }
		float dl = distance(p, lights[i].xy);
		k = min(k, smoothstep(lights[i].z * 0.5, lights[i].z, dl));
	}
	float n = 0.5 + 0.5 * sin(p.x * 0.011 + time * 0.35) * sin(p.y * 0.015 - time * 0.27);
	COLOR = vec4(fog_color.rgb * (0.8 + 0.4 * n), fog_color.a * k);
}
"""

var _mat: ShaderMaterial
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("fog_color", Color(0.03, 0.08, 0.11, 0.94))
	material = _mat
	color = Color.WHITE

## center — клетка на экране, radius — сколько видно, в точках экрана.
func update(center: Vector2, radius: float, delta: float, lights: Array = []) -> void:
	var packed := PackedVector3Array()
	for l in lights.slice(0, 8):
		packed.append(l)
	while packed.size() < 8:
		packed.append(Vector3.ZERO)
	_mat.set_shader_parameter("lights", packed)
	_mat.set_shader_parameter("light_count", mini(lights.size(), 8))
	_t += delta
	_mat.set_shader_parameter("center", center)
	_mat.set_shader_parameter("radius", radius)
	_mat.set_shader_parameter("soft", maxf(40.0, radius * 0.35))
	_mat.set_shader_parameter("rect_size", size)
	_mat.set_shader_parameter("time", _t)
	# Видно дальше края экрана — тумана нет вовсе, и рисовать нечего.
	visible = radius < size.length()
