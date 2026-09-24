## Суша: остров, ходьба, берег, плоды, соседи.
extends RefCounted

func _land() -> Land:
	return Land.new(Evolution.create(), 5)

func test_остров(c) -> void:
	var t := Terrain.new(5)
	c.ok("середина — суша", not t.is_water(0.0, 0.0))
	c.ok("далеко — море", t.is_water(Terrain.RADIUS * 1.4, 0.0) and t.is_water(0.0, -Terrain.RADIUS * 1.4))
	c.eq("один сид — один остров", Terrain.new(5).height(37.0, -12.0), t.height(37.0, -12.0))
	var m := t.build_mesh()
	c.ok("сетка с цветом", m.get_surface_count() == 1 and not (m.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray).is_empty())

func test_ходьба(c) -> void:
	var l := _land()
	var start := l.pos
	for i in 60:
		l.step(1.0 / 30.0, Vector2(1, 0))
	c.ok("идёт (%.1f м за 2 с)" % start.distance_to(l.pos), start.distance_to(l.pos) > Land.SPEED * 1.2)
	c.ok("стоит на земле", absf(l.pos.y - l.terrain.height(l.pos.x, l.pos.z)) < 0.01)
	c.ok("смотрит, куда идёт", absf(wrapf(l.heading - PI / 2.0, -PI, PI)) < 0.3)

func test_в_море_не_уйти(c) -> void:
	var l := _land()
	for i in 30 * 90:
		l.step(1.0 / 30.0, Vector2(0.7, 0.7))
	c.ok("упёрся в берег и не утонул", l.terrain.height(l.pos.x, l.pos.z) > Terrain.WATER - 0.25)

func test_плоды(c) -> void:
	var l := _land()
	var b: Dictionary = l.bushes[0]
	l.pos = b.pos + Vector3(1.0, 0, 0)
	l.step(1.0 / 30.0, Vector2.ZERO)
	c.ok("съел плод", l.eaten == 1 and b.fruits == Land.FRUITS - 1 and l.events.any(func(e): return e.t == "eat"))
	l.step(1.0 / 30.0, Vector2.ZERO)
	c.eq("не всё разом", l.eaten, 1)
	for i in 30 * 3:
		l.step(1.0 / 30.0, Vector2.ZERO)
	c.eq("стоишь у куста — съешь все", b.fruits, 0)
	l.pos = b.pos + Vector3(30.0, 0, 0)
	for i in 30 * int(Land.REGROW + 1.0):
		l.step(1.0 / 30.0, Vector2.ZERO)
	c.ok("плоды отрастают", b.fruits >= 1)

func test_соседи(c) -> void:
	var l := _land()
	var starts: Array = l.npcs.map(func(n): return n.pos)
	for i in 30 * 60:
		l.step(1.0 / 30.0, Vector2.ZERO)
	c.ok("бродят", range(l.npcs.size()).any(func(i): return (l.npcs[i].pos as Vector3).distance_to(starts[i]) > 5.0))
	c.ok("и не лезут в море", l.npcs.all(func(n): return not l.terrain.is_water(n.pos.x, n.pos.z)))
