## Рисует бесшовную «сетку бликов» для воды: godot --headless -s tools/make_caustics.gd
##
## Ячейки Вороного на торе: светлые тонкие линии там, где две ближайшие точки почти на
## одном расстоянии. В игре два слоя этой картинки скользят навстречу, и где они
## совпадают — вспыхивает блик, как свет сквозь рябь на дне.
extends SceneTree

const SIZE := 256
const POINTS := 22

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260924
	var pts: Array[Vector2] = []
	for i in POINTS:
		pts.append(Vector2(rng.randf(), rng.randf()) * SIZE)
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_L8)
	for y in SIZE:
		for x in SIZE:
			var p := Vector2(x + 0.5, y + 0.5)
			var d1 := 1e9
			var d2 := 1e9
			for q in pts:
				# Расстояние на торе — картинка без шва по краям.
				var dx := absf(p.x - q.x)
				var dy := absf(p.y - q.y)
				dx = minf(dx, SIZE - dx)
				dy = minf(dy, SIZE - dy)
				var d := sqrt(dx * dx + dy * dy)
				if d < d1:
					d2 = d1
					d1 = d
				elif d < d2:
					d2 = d
			# Край — по доле расстояний, чтобы линии были одной толщины: тонкая яркая
			# сердцевина и мягкое свечение вокруг.
			var edge := (d2 - d1) / (d2 + d1) * SIZE * 0.25
			var v := 0.75 * exp(-edge * edge / 6.0) + 0.25 * exp(-edge / 7.0)
			img.set_pixel(x, y, Color(v, v, v))
	img.save_png("res://art/caustics.png")
	print("art/caustics.png готово")
	quit()
