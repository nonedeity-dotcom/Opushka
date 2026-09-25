## Остров для второго этапа: высота суши в любой точке. Один и тот же сид — один и тот
## же остров. Середина — нагорье с каменистыми вершинами, вокруг — холмы, к краям — песок
## и мелководье, дальше — море.
class_name Terrain
extends RefCounted

## Радиус острова (метры мира) и уровень воды.
const RADIUS := 260.0
const WATER := 0.0
## Размер сетки для картинки и шаг между её точками.
const SIZE := 640.0
const STEP := 5.0

var _hills := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _shore := FastNoiseLite.new()

func _init(seed := 1) -> void:
	_hills.seed = seed
	_hills.frequency = 0.009
	_detail.seed = seed + 7
	_detail.frequency = 0.05
	_shore.seed = seed + 13
	_shore.frequency = 0.02

## Высота суши в точке (x, z). Ниже нуля — вода.
func height(x: float, z: float) -> float:
	var d := Vector2(x, z).length()
	# Край острова неровный — заливы и мысы.
	var edge := RADIUS * (1.0 + 0.18 * _shore.get_noise_2d(x, z))
	var k := clampf(1.0 - d / edge, -1.0, 1.0)
	var land := 1.0 + 3.0 * k
	var hills := (_hills.get_noise_2d(x, z) + 0.3) * 8.0 * clampf(k * 2.0, 0.0, 1.0)
	# Нагорье посередине: дальние вершины видно издалека — остров кажется большим.
	var high := 7.0 * smoothstep(0.0, 1.0, clampf((k - 0.45) / 0.4, 0.0, 1.0)) * (0.6 + 0.4 * _hills.get_noise_2d(z * 0.7, x * 0.7))
	var bumps := _detail.get_noise_2d(x, z) * 0.6
	return land + maxf(hills, -1.0) + maxf(high, 0.0) + bumps - 4.0 * (1.0 - clampf(k * 3.0, 0.0, 1.0))

func is_water(x: float, z: float) -> bool:
	return height(x, z) < WATER + 0.15

## Склон: насколько круто (0 — ровно).
func slope(x: float, z: float) -> float:
	var e := 0.8
	return Vector2(height(x + e, z) - height(x - e, z), height(x, z + e) - height(x, z - e)).length() / (2.0 * e)

## Цвет земли по высоте: песок у воды, трава, выше — тёмная трава и камень.
static func ground_color(h: float, steep: float) -> Color:
	var c: Color
	if h < 0.9:
		c = Color("#e2cf92")
	elif h < 1.6:
		c = Color("#e2cf92").lerp(Color("#7cc25a"), (h - 0.9) / 0.7)
	elif h < 9.0:
		c = Color("#7cc25a").lerp(Color("#4f9a44"), (h - 1.6) / 7.4)
	elif h < 13.0:
		c = Color("#4f9a44").lerp(Color("#5a8a4a"), (h - 9.0) / 4.0)
	else:
		# Вершины нагорья — камень.
		c = Color("#5a8a4a").lerp(Color("#8f8a7c"), clampf((h - 13.0) / 2.5, 0.0, 1.0))
	if steep > 0.9:
		c = c.lerp(Color("#8a8070"), clampf((steep - 0.9) * 1.5, 0.0, 0.7))
	return c

## Сетка для картинки: треугольники с плоскими гранями (низкополигональный вид) и цветом
## в вершинах. Подводная часть тоже есть — сквозь воду видно дно. trample — где земля
## протоптана (у гнёзд и тропы к еде): [{a, b, r}] — отрезок от a до b шириной r
## (a == b — круг).
func build_mesh(trample: Array = []) -> ArrayMesh:
	var n := int(SIZE / STEP)
	var half := SIZE / 2.0
	var hs := PackedFloat32Array()
	hs.resize((n + 1) * (n + 1))
	for iz in n + 1:
		for ix in n + 1:
			hs[iz * (n + 1) + ix] = height(ix * STEP - half, iz * STEP - half)
	# Насколько протоптано в каждой точке сетки: считаем только рядом с каждой тропой.
	var worn := PackedFloat32Array()
	worn.resize((n + 1) * (n + 1))
	for t in trample:
		var a: Vector2 = t.a
		var b: Vector2 = t.b
		var r: float = t.r
		var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(r, r)
		var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(r, r)
		for iz in range(maxi(0, int((lo.y + half) / STEP)), mini(n, int((hi.y + half) / STEP) + 1) + 1):
			for ix in range(maxi(0, int((lo.x + half) / STEP)), mini(n, int((hi.x + half) / STEP) + 1) + 1):
				var q := Vector2(ix * STEP - half, iz * STEP - half)
				var ab := b - a
				var k := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
				var d := q.distance_to(a + ab * k)
				var w := clampf(1.0 - d / r, 0.0, 1.0)
				var i := iz * (n + 1) + ix
				worn[i] = maxf(worn[i], w)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for iz in n:
		for ix in n:
			var x0 := ix * STEP - half
			var z0 := iz * STEP - half
			var p00 := Vector3(x0, hs[iz * (n + 1) + ix], z0)
			var p10 := Vector3(x0 + STEP, hs[iz * (n + 1) + ix + 1], z0)
			var p01 := Vector3(x0, hs[(iz + 1) * (n + 1) + ix], z0 + STEP)
			var p11 := Vector3(x0 + STEP, hs[(iz + 1) * (n + 1) + ix + 1], z0 + STEP)
			for tri in [[p00, p11, p10], [p00, p01, p11]]:
				var a: Vector3 = tri[0]
				var b: Vector3 = tri[1]
				var c: Vector3 = tri[2]
				var nrm := (b - a).cross(c - a).normalized()
				var h := (a.y + b.y + c.y) / 3.0
				var col := ground_color(h, 1.0 - nrm.y) if h > -0.5 else Color("#c8b880").darkened(clampf(-h / 6.0, 0.0, 0.6))
				var wi := (worn[iz * (n + 1) + ix] + worn[(iz + 1) * (n + 1) + ix + 1] + worn[iz * (n + 1) + ix + 1] + worn[(iz + 1) * (n + 1) + ix]) / 4.0
				if wi > 0.0 and h > 0.9:
					# Протоптано: трава вытерта до земли, по краю — пятнами.
					var spot := fposmod(a.x * 0.53 + a.z * 0.31, 1.0) * 0.35
					col = col.lerp(Color("#a8875a"), clampf(wi * 1.5 - spot, 0.0, 0.9))
				# Лёгкая пестрота — чтобы поле не было ровной заливкой.
				col = col.lightened(fposmod(a.x * 0.37 + a.z * 0.61, 1.0) * 0.06)
				# Godot считает лицевой ту сторону, где вершины идут по часовой стрелке.
				for v in [a, c, b]:
					verts.append(v)
					normals.append(nrm)
					colors.append(col)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh
