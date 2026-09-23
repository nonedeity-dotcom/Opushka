extends RefCounted

## Поставить персонажа на свободную клетку лицом к клетке с нужным. Ближайшее к старту —
## дальние могут стоять в глухой чаще, куда не дойти.
func _face(v: Village, id: String) -> Village:
	var w := v.world()
	var start: Vector2i = w.start
	var best := Vector2i(-1, -1)
	var best_d := INF
	for i in WorldGen.SIZE * WorldGen.SIZE:
		if w.nature[i] != id:
			continue
		var c := Vector2i(i % WorldGen.SIZE, i / WorldGen.SIZE)
		if c.x < 3 or c.y < 3 or c.x > WorldGen.SIZE - 4 or c.y > WorldGen.SIZE - 4:
			continue
		var d := Vector2(c).distance_to(Vector2(start))
		if d < best_d and not v.path_to(c).is_empty():
			best_d = d
			best = c
	if best.x < 0:
		return null
	var road := v.path_to(best)
	var cells: Array = road.cells
	var stand: Vector2i = cells[-1] if not cells.is_empty() else v.tile_of(v.pos)
	v.pos = Vector2(stand) + Vector2(0.5, 0.5)
	v.face(Vector2(road.face))
	return v

func test_мир(c) -> void:
	for seed in [1, 7, 42, 2026, 99991]:
		var w := WorldGen.make(seed)
		var v := Village.create(seed)
		var start: Vector2i = w.start
		c.ok("зерно %d: старт свободен" % seed, not v.blocks(start))
		c.ok("зерно %d: край — лес" % seed, w.nature[0] == "tree" and w.nature[WorldGen.SIZE * WorldGen.SIZE - 1] == "tree")
		c.ok("зерно %d: есть вода" % seed, Array(w.ground).has(WorldGen.Ground.WATER))
		var counts := {}
		for n in w.nature:
			counts[n] = counts.get(n, 0) + 1
		c.ok("зерно %d: всего хватает" % seed, ["tree", "bush", "rock", "pebble", "branch"].all(func(id): return counts.get(id, 0) > 5))
	c.eq("одно зерно — один мир", WorldGen.make(5).nature, WorldGen.make(5).nature)
	c.ok("разные зёрна — разные миры", WorldGen.make(5).nature != WorldGen.make(6).nature)

func test_ходьба_и_столкновения(c) -> void:
	var v := Village.create(42)
	var t0 := v.time
	v.walk(Vector2(0, -1))
	c.eq("прошёл клетку вверх", v.pos, Vector2(v.world().start) + Vector2(0.5, -0.5))
	c.eq("клетка стоит двух минут", v.time - t0, 2.0)
	c.eq("смотрит вверх", v.facing4(), Vector2i(0, -1))
	# Упереться в дерево: сколько ни иди — не пройдёшь.
	var at_tree := _face(Village.create(42), "tree")
	var tree := at_tree.tile_of(at_tree.pos) + at_tree.facing4()
	var before := at_tree.pos
	for i in 10:
		at_tree.walk(Vector2(at_tree.facing4()) * 0.3)
	c.ok("в дерево не войти", at_tree.tile_of(at_tree.pos) != tree)
	c.ok("но подойти вплотную можно", at_tree.pos.distance_to(Vector2(tree) + Vector2(0.5, 0.5)) <= before.distance_to(Vector2(tree) + Vector2(0.5, 0.5)))
	c.eq("и кнопка — «Срубить»", at_tree.action_label(), "Срубить")
	c.eq("значок — топор", at_tree.action_icon(), "axe")
	# Скольжение вдоль стены: наискосок в препятствие — вдоль него всё равно едет.
	var s := Village.create(42)
	s.pos = Vector2(1.5, 30.5) + Vector2(1, 0)  # у самого края, слева сплошной лес
	var y0 := s.pos.y
	s.walk(Vector2(-1, 1).normalized() * 2.0)
	c.ok("вдоль леса скользит", s.pos.y > y0 + 0.5)

func test_ветки_на_ходу(c) -> void:
	var v := Village.create(42)
	var w := v.world()
	var start: Vector2i = w.start
	# Ветка лежит в [2, -1] от старта.
	v.walk(Vector2(0, -1))
	v.walk(Vector2(1, 0))
	var out := v.walk(Vector2(1, 0))
	c.eq("стоит на ветке", v.tile_of(v.pos), start + Vector2i(2, -1))
	c.eq("ветки в сумке", v.bag.get("stick", 0), 2)
	c.eq("и сказано по-русски", out.message, "+2 ветки")
	c.eq("звук — треск", out.sound, "twig")

func test_собрать_и_ждать(c) -> void:
	var v := _face(Village.create(42), "bush")
	var t := v.target()
	var out := v.act()
	c.eq("ягоды", v.bag.get("berries", 0), 3)
	c.eq("звук ягод", out.sound, "berries")
	c.ok("куст пустой", v.cell(t).depleted)
	c.eq("второй раз — ничего", v.act().sound, "nope")
	v.time += Content.NATURE.bush.regrow
	c.ok("через день ягоды снова", not v.cell(t).depleted)

	var tree := _face(Village.create(42), "tree")
	c.eq("без топора не срубить", tree.act().sound, "nope")
	c.eq("и нет брёвен", tree.bag.get("log", 0), 0)
	tree.bag["axe"] = 1
	var chop := tree.act()
	c.eq("с топором — брёвна", tree.bag.get("log", 0), 2)
	c.eq("удар топора", chop.sound, "chop")
	c.ok("пень не пускает", tree.blocks(tree.target()))

	var hungry := _face(Village.create(42), "bush")
	hungry.food = 0
	var fed := _face(Village.create(42), "bush")
	var h0 := hungry.time
	var f0 := fed.time
	hungry.act()
	fed.act()
	c.ok("голодному дольше", hungry.time - h0 > fed.time - f0)

func test_ремесло_и_постройки(c) -> void:
	var axe := Content.recipe("axe")
	var v := Village.create(42)
	v.bag = {"stick": 3, "stone": 1}
	c.eq("не хватает", v.can_craft(axe).ok, false)
	v.bag.stone = 2
	var out := v.craft("axe")
	c.eq("топор сделан, ветки потрачены", [v.bag.axe, v.bag.stick, v.bag.stone], [1, 0, 0])
	c.eq("звук молотка", out.sound, "craft")
	c.ok("и задача «топор»", out.goal)
	v.bag.stick = 9
	v.bag.stone = 9
	c.eq("второй топор не нужен", v.can_craft(axe).reason, "Уже есть")

	var house := Content.recipe("house")
	var r := Village.create(42)
	r.bag = {"log": 20, "stone": 20, "workbench": 1}
	c.eq("домик — только у верстака", r.can_craft(house).ok, false)
	r.face(Vector2.DOWN)
	var put := r.place("workbench")
	c.eq("верстак стоит", r.built.values(), ["workbench"])
	c.eq("звук постройки", put.sound, "place")
	c.ok("у верстака домик делается", r.can_craft(house).ok)
	var back := r.pick_up()
	c.eq("разобрал — вернулся в сумку", [r.bag.workbench, r.built.size()], [1, 0])
	c.eq("звук разбора", back.sound, "pickup")

	var on_tree := _face(Village.create(42), "tree")
	on_tree.bag = {"campfire": 1}
	c.eq("на дерево не поставить", on_tree.place("campfire").sound, "nope")

func test_ночь_еда_задачи(c) -> void:
	var v := Village.create(42)
	v.bag = {"campfire": 1, "berries": 2}
	v.food = 50
	v.face(Vector2.DOWN)
	var put := v.place("campfire")
	c.ok("костёр отмечает задачу", v.goals_done.has("campfire") and put.goal)
	c.eq("днём спать рано", v.act().sound, "nope")
	v.time = 23 * 60
	var sleep := v.act()
	c.eq("проснулся в 7 утра следующего дня", v.time, float(Content.DAY + 7 * 60))
	c.eq("звук сна", sleep.sound, "sleep")
	var f0 := v.food
	v.eat("berries")
	c.ok("поел — сытнее", v.food > f0 and v.bag.berries == 1)
	c.eq("первая задача — ветки", Village.create(42).current_goal().id, "sticks")
	c.eq("полночь — темно", _at(0).darkness(), 1.0)
	c.eq("полдень — светло", _at(12 * 60).darkness(), 0.0)
	c.eq("в 20:00 — сумерки наполовину", _at(20 * 60).darkness(), 0.5)

func _at(minute: int) -> Village:
	var v := Village.create(1)
	v.time = minute
	return v

func test_дорога_по_касанию(c) -> void:
	var v := Village.create(42)
	var here := v.tile_of(v.pos)
	var road := v.path_to(here + Vector2i(1, 1))
	c.eq("до свободной клетки — два шага", road.cells.size(), 2)
	c.eq("пришли, куда просили", road.cells[-1], here + Vector2i(1, 1))
	c.eq("своя клетка — идти некуда", v.path_to(here), {})
	c.eq("за краем мира — некуда", v.path_to(Vector2i(-1, 5)), {})
	var near := _face(Village.create(42), "tree")
	c.ok("к дереву — дорога и поворот", near != null)
	var prev: Vector2i = v.tile_of(v.pos)
	var all_free := true
	for cell in road.cells:
		all_free = all_free and not v.blocks(cell) and (cell - prev).length_squared() == 1
		prev = cell
	c.ok("дорога только по свободным соседним клеткам", all_free)

func test_сохранение(c) -> void:
	var v := _face(Village.create(42), "bush")
	v.act()
	v.bag.axe = 1
	var copy := Village.from_dict(JSON.parse_string(JSON.stringify(v.to_dict())))
	c.eq("туда-обратно без потерь", copy.to_dict(), v.to_dict())
	c.eq("мусор — ничего", Village.from_dict("x"), null)
	c.eq("без зерна — ничего", Village.from_dict({"time": 5}), null)
	var odd := Village.from_dict({"seed": 3, "bag": {"stick": 4, "rocket": 1, "stone": -2}, "built": {"1:1": "castle", "2:2": "fence"}})
	c.eq("чужие вещи и постройки выброшены", [odd.bag, odd.built], [{"stick": 4}, {"2:2": "fence"}])

func test_слова(c) -> void:
	c.eq("1", Content.plural(1, ["ветка", "ветки", "веток"]), "ветка")
	c.eq("3", Content.plural(3, ["ветка", "ветки", "веток"]), "ветки")
	c.eq("11", Content.plural(11, ["ветка", "ветки", "веток"]), "веток")
	c.eq("22", Content.plural(22, ["ветка", "ветки", "веток"]), "ветки")
