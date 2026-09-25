## Тело для суши: переход из клетки, цены и возврат ДНК, сохранение, и что части правда
## меняют игру.
extends RefCounted

func _evo() -> Evolution:
	var e := Evolution.create()
	e.dna_total = 100.0
	e.body = [{"id": "jaws", "a": 0, "d": 1.0}, {"id": "flagellum", "a": 180, "d": 1.0}, {"id": "cilia", "a": 135, "d": 1.0},
		{"id": "eye", "a": 0, "d": 0.3}, {"id": "spike", "a": 90, "d": 1.0}, {"id": "spike2", "a": -90, "d": 1.0}]
	return e

func test_переход(c) -> void:
	var e := _evo()
	var free_sea := e.dna_free()
	var conv := e.land_start()
	c.eq("челюсти остались челюстями", e.land_body.get("mouth"), "jaws")
	c.eq("глазок стал глазами", e.land_body.get("eyes"), "eyes")
	c.eq("ноги — даром лапки", e.land_body.get("legs"), "stubs")
	c.eq("два шипа — одни шипы на спине", e.land_body.get("back"), "back_spikes")
	var gone: Array = conv.gone.map(func(g): return g[0])
	c.ok("жгутик и реснички ушли", gone.has("flagellum") and gone.has("cilia") and gone.size() == 2)
	c.eq("за ушедшие вернулась ДНК", conv.back, 18 + 6)
	c.ok("на суше свободной ДНК больше (%d > %d)" % [e.land_free(), free_sea], e.land_free() > free_sea)
	c.eq("тело клетки не тронуто", e.body.size(), 6)

func test_первый_раз_с_нуля(c) -> void:
	var e := Evolution.create()
	e.land_start()
	c.eq("стартовый фильтр — клюв", e.land_body.get("mouth"), "beak")
	c.ok("ДНК хватает (%d)" % e.land_free(), e.land_free() >= 0)

func test_поставить_и_снять(c) -> void:
	var e := _evo()
	e.land_start()
	var free := e.land_free()
	c.ok("поставил ноги", e.land_put("legs4").ok)
	c.eq("списалось", e.land_free(), free - 20)
	c.ok("сменил на шесть — старые вернулись", e.land_put("legs6").ok and e.land_free() == free - 34)
	c.ok("снял ноги — ног нет, ДНК вернулась", e.land_take("legs").ok and not e.land_body.has("legs") and e.land_free() == free)
	c.ok("без ног на сушу не выйти", not e.land_can_walk())
	c.ok("лапки даром", e.land_put("stubs").ok and e.land_can_walk())
	e.land_put("claws")
	c.ok("снял когти — места нет", e.land_take("claws").ok and not e.land_body.has("claws"))
	e.dna_total = 0.0
	var r := e.land_put("claws_big")
	c.ok("не хватает — не ставится: %s" % r.message, not r.ok and not e.land_body.has("claws"))

func test_сохранение(c) -> void:
	var e := _evo()
	e.land_start()
	e.land_put("legs_long")
	e.land_put("arms")
	e.land_ready = true
	var back := Evolution.from_dict(JSON.parse_string(JSON.stringify(e.to_dict())))
	c.eq("тело суши на месте", back.land_body, e.land_body)
	c.ok("вышел на сушу — помнит", back.land_ready)
	var bad := e.to_dict()
	bad.land_body = {"legs": "wings", "mouth": "eyes", "arms": "arms"}
	var b2 := Evolution.from_dict(bad)
	c.eq("чужое выброшено; старому телу — туловище и лапки", b2.land_body, {"arms": "arms", "torso": "torso", "legs": "stubs"})
	var old := e.to_dict()
	old.erase("land_body")
	old.erase("land_ready")
	var b3 := Evolution.from_dict(old)
	c.ok("старое сохранение — ещё не выходил", b3.land_body.is_empty() and not b3.land_ready)

func test_свойства(c) -> void:
	var base := LandParts.stats({"legs": "stubs"})
	c.ok("без глаз — плохо видно", base.sight < 1.0)
	c.ok("без рта не ест", not base.mouth)
	c.ok("длинные ноги быстрее лапок", LandParts.stats({"legs": "legs_long"}).speed > base.speed * 1.4)
	c.ok("пластины замедляют и защищают", LandParts.stats({"legs": "stubs", "back": "plates"}).speed < base.speed and LandParts.stats({"back": "plates"}).armor > 0.2)
	var st := LandParts.stats({"mouth": "fangs", "claws": "claws_big", "arms": "arms_claw", "head": "horns"})
	c.eq("укус складывается", st.bite, 2.0 + 10.0 + 6.0 + 5.0 + 4.0)
	var both := LandParts.stats({"back": "plates", "skin": "scales"})
	c.ok("броня не больше 100%% (%.2f)" % both.armor, both.armor < 0.5 and both.armor > 0.3)
	for id in LandParts.PARTS:
		var slot: String = LandParts.PARTS[id].slot
		if not LandParts.SLOTS.any(func(s): return s[0] == slot):
			c.ok("место части %s есть" % id, false)
	for id in LandParts.FROM_SEA:
		c.ok("часть клетки %s есть" % id, Content.PARTS.has(id) and LandParts.PARTS.has(LandParts.FROM_SEA[id]))

func _land(body: Dictionary) -> Land:
	var e := Evolution.create()
	e.land_body = body.duplicate()
	e.land_body.torso = "torso"
	var l := Land.new(e, 5)
	l.mobs = []
	return l

func test_ноги_на_суше(c) -> void:
	var slow := _land({"legs": "stubs"})
	var fast := _land({"legs": "legs_long", "feet": "hooves"})
	var a := slow.pos
	var b := fast.pos
	for i in 60:
		slow.step(1.0 / 30.0, Vector2(1, 0))
		fast.step(1.0 / 30.0, Vector2(1, 0))
	c.ok("длинные ноги с копытами уходят дальше (%.1f против %.1f)" % [b.distance_to(fast.pos), a.distance_to(slow.pos)],
		b.distance_to(fast.pos) > a.distance_to(slow.pos) * 1.4)

func test_броня_и_сдача(c) -> void:
	var soft := _land({"legs": "stubs"})
	var hard := _land({"legs": "stubs", "back": "back_spikes", "skin": "poison_skin"})
	var dmg := {}
	for l in [soft, hard]:
		var h: Dictionary = l._add_mob("hermit", l.pos + Vector3(2.5, 0, 0), 2.0, "#555555", 4)
		h.hp = 1000.0
		h.max_hp = 1000.0
		var got := 0.0
		for i in 30 * 3:
			l.hp = l.max_hp
			l.step(1.0 / 30.0, Vector2.ZERO)
			for e in l.events:
				if e.t == "hurt":
					got += e.dmg
		dmg[l] = [got, 1000.0 - h.hp]
	c.ok("отшельник кусал обоих", dmg[soft][0] > 0.0 and dmg[hard][0] > 0.0)
	c.ok("шипы и яд ранят кусачего (%.0f)" % dmg[hard][1], dmg[hard][1] > 10.0 and dmg[soft][1] == 0.0)
	var armored := _land({"legs": "stubs", "back": "plates"})
	var h: Dictionary = armored._add_mob("hermit", armored.pos + Vector3(2.5, 0, 0), 2.0, "#555555", 4)
	var first := 0.0
	for i in 30 * 3:
		armored.step(1.0 / 30.0, Vector2.ZERO)
		for e in armored.events:
			if e.t == "hurt" and first == 0.0:
				first = e.dmg
	c.ok("пластины: укус слабее (%.1f < %.1f)" % [first, h.bite], first > 0.0 and first < float(h.bite) * 0.75)

func test_без_рта_не_ест(c) -> void:
	var l := _land({"legs": "stubs"})
	var b: Dictionary = l.bushes[0]
	l.pos = b.pos + Vector3(1.0, 0, 0)
	for i in 30:
		l.step(1.0 / 30.0, Vector2.ZERO)
	c.eq("плоды целы", b.fruits, Land.FRUITS)
	var l2 := _land({"legs": "stubs", "mouth": "beak"})
	var b2: Dictionary = l2.bushes[0]
	l2.pos = b2.pos + Vector3(1.0, 0, 0)
	var before := l2.evo.dna_total
	l2.step(1.0 / 30.0, Vector2.ZERO)
	c.eq("клюв: с плода вдвое больше, и в общую ДНК", l2.evo.dna_total - before, 2.0)

func test_перепонки(c) -> void:
	var dry := _land({"legs": "stubs"})
	var wet := _land({"legs": "stubs", "feet": "webbed"})
	var deepest := {}
	for l in [dry, wet]:
		for i in 30 * 90:
			l.step(1.0 / 30.0, Vector2(0.7, 0.7))
		deepest[l] = l.terrain.height(l.pos.x, l.pos.z)
	c.ok("с перепонками заходишь глубже (%.2f < %.2f)" % [deepest[wet], deepest[dry]], deepest[wet] < deepest[dry] - 0.5)
	c.ok("но не тонешь", deepest[wet] > Terrain.WATER - 1.35)

func test_смерть_на_суше(c) -> void:
	var l := _land({"legs": "stubs"})
	l.bushes = []
	l.dna = 50.0
	l.evo.dna_total = 300.0
	l.hp = 0.0
	l.step(1.0 / 30.0, Vector2.ZERO)
	c.eq("теряешь пятую часть добытого здесь", l.evo.dna_total, 290.0)

func test_форма_проверка(c) -> void:
	var d := LandParts.fix_shape({"len": 99, "girth": [5, 0, 1, 1, 1], "head": "big", "sizes": {"eyes": 9.0, "wings": 2.0}, "leg_len": -3})
	c.eq("длина — в пределах", d.len, LandParts.SHAPE.len[2])
	c.eq("толщина — в пределах", d.girth[0], LandParts.GIRTH_LIMITS[1])
	c.eq("непонятное — обычное", d.head, 1.0)
	c.ok("чужих мест нет, размер в пределах", not d.sizes.has("wings") and d.sizes.eyes == LandParts.SIZE_LIMITS[1])
	c.eq("мусор — обычная форма", LandParts.fix_shape("x"), LandParts.default_shape())

func test_форма_из_воды(c) -> void:
	var round := LandParts.shape_from_sea(Content.shape_preset("round"))
	var long := LandParts.shape_from_sea(Content.shape_preset("oval"))
	c.ok("круглая клетка — обычное туловище (%.2f)" % round.len, absf(round.len - 1.0) < 0.15)
	var fat: Array = []
	for i in Content.SHAPE_POINTS:
		fat.append(1.5)
	var f := LandParts.shape_from_sea(fat)
	c.ok("толстая клетка — толстое туловище (%.2f)" % f.girth[2], f.girth[2] > round.girth[2] + 0.3)
	c.ok("вытянутая клетка — длиннее (%.2f > %.2f)" % [long.len, round.len], long.len > round.len + 0.2)

func test_форма_и_свойства(c) -> void:
	var body := {"legs": "legs4", "mouth": "jaws", "eyes": "eyes"}
	var base := LandParts.stats(body, LandParts.default_shape())
	c.eq("обычная форма ничего не меняет — здоровье", base.hp, LandParts.stats(body).hp)
	var fat := LandParts.default_shape()
	fat.girth = [1.6, 1.8, 1.9, 1.8, 1.5]
	var st := LandParts.stats(body, fat)
	c.ok("толще — крепче (%.0f > %.0f)" % [st.hp, base.hp], st.hp > base.hp * 1.4)
	c.ok("но медленнее", st.speed < base.speed)
	var legs := LandParts.default_shape()
	legs.leg_len = 2.0
	legs.leg_len_f = 2.0
	c.ok("длинные ноги — быстрее", LandParts.stats(body, legs).speed > base.speed * 1.2)
	var one := LandParts.default_shape()
	one.leg_len_f = 2.0
	var half: float = LandParts.stats(body, one).speed
	c.ok("только передние длинные — быстрее, но меньше (%.2f)" % half, half > base.speed and half < LandParts.stats(body, legs).speed)
	var big := LandParts.default_shape()
	big.sizes = {"mouth": 2.0}
	c.ok("большая пасть кусает сильнее", LandParts.stats(body, big).bite > base.bite + 1.0)
	big.sizes = {"eyes": 2.0}
	c.ok("большие глаза видят дальше", LandParts.stats(body, big).sight > base.sight)
	var fast := LandParts.default_shape()
	fast.leg_len = 2.4
	c.ok("быстрее предела не бегает", LandParts.stats({"legs": "legs_long", "feet": "hooves", "tail": "tail_long"}, fast).speed <= 1.9)

func test_форма_сохраняется(c) -> void:
	var e := _evo()
	e.land_start()
	e.land_shape.girth = [0.5, 1.2, 1.8, 1.2, 0.5]
	e.land_shape.neck_y = 1.0
	e.land_shape.sizes = {"eyes": 1.6}
	var back := Evolution.from_dict(JSON.parse_string(JSON.stringify(e.to_dict())))
	c.eq("толщина по спине", back.land_shape.girth, e.land_shape.girth)
	c.eq("шея", back.land_shape.neck_y, 1.0)
	c.eq("размер глаз", back.land_shape.sizes.eyes, 1.6)
	var fat_land := Evolution.create()
	fat_land.land_body = {"legs": "stubs"}
	var thin := Land.new(fat_land, 5).max_hp
	fat_land.land_shape = e.land_shape
	fat_land.land_shape.girth = [1.8, 1.9, 2.0, 1.9, 1.8]
	c.ok("на суше толстое тело крепче", Land.new(fat_land, 5).max_hp > thin * 1.3)

func test_размеры_целиком(c) -> void:
	var body := {"legs": "legs4", "mouth": "jaws", "arms": "arms"}
	var base := LandParts.stats(body, LandParts.default_shape())
	var big := LandParts.default_shape()
	big.torso = 1.5
	c.ok("туловище крупнее — крепче", LandParts.stats(body, big).hp > base.hp * 1.5)
	var wide := LandParts.default_shape()
	wide.width = 1.6
	c.ok("шире — крепче", LandParts.stats(body, wide).hp > base.hp * 1.1)
	var arms := LandParts.default_shape()
	arms.arm_size = 1.8
	c.ok("руки крупнее — достают дальше", LandParts.stats(body, arms).reach > base.reach + 0.4)
	var sp := LandParts.spine(wide, 1.0)
	c.ok("ширина — вбок, высота — прежняя", sp[2].rx > sp[2].ry * 1.5)

func test_старые_ноги(c) -> void:
	var d := LandParts.fix_shape({"leg_len": 1.8, "leg_thick": 1.4})
	c.ok("старое сохранение: передние — как задние", d.leg_len_f == 1.8 and d.leg_thick_f == 1.4)

func test_с_нуля(c) -> void:
	var e := _evo()
	e.land_start()
	e.land_put("legs6")
	e.land_put("arms")
	var free := e.land_free()
	var r := e.land_clear()
	c.ok("совсем пусто: " + r.message, e.land_body.is_empty() and not e.land_can_walk())
	c.ok("без туловища ничего не поставить", not e.land_put("legs4").ok)
	c.ok("туловище — даром", e.land_put("torso").ok and e.land_put("legs4").ok and e.land_can_walk())
	c.ok("ДНК вернулась", e.land_free() > free + 40)
	c.eq("туловище простое", e.land_shape.len, LandParts.blank_shape().len)

func test_окрас(c) -> void:
	var e := _evo()
	e.color = 3
	e.color2 = 7
	e.pattern = "stripes"
	e.land_start()
	c.eq("окрас с клетки", e.paint(), {"color": 3, "color2": 7, "pattern": "stripes"})
	e.land_paint = {"color": 20, "color2": 25, "pattern": "leopard"}
	var back := Evolution.from_dict(JSON.parse_string(JSON.stringify(e.to_dict())))
	c.eq("окрас сохраняется", back.paint(), {"color": 20, "color2": 25, "pattern": "leopard"})
	c.eq("мусор — обычный окрас", LandParts.fix_paint({"color": 99, "pattern": "zebra"}), {"color": 0, "color2": 5, "pattern": "spots"})
	c.eq("старое сохранение без окраса — как клетка", Evolution.from_dict(_old(e)).paint().pattern, "stripes")

func _old(e: Evolution) -> Dictionary:
	var d := JSON.parse_string(JSON.stringify(e.to_dict())) as Dictionary
	d.erase("land_paint")
	return d

func test_размеры_каждой_части(c) -> void:
	var sh := LandParts.fix_shape({"dims": {"leg0": [2.0, 1.5, 1.2, 1.3], "wings": [1, 1, 1, 1], "arm1": [9, 0, 1, 1]}})
	c.eq("своя длина у ноги", sh.dims.leg0[0], 2.0)
	c.ok("чужой части нет", not sh.dims.has("wings"))
	c.eq("в пределах", sh.dims.arm1, [LandParts.DIM_LIMITS[1], LandParts.DIM_LIMITS[0], 1.0, 1.0])
	var body := {"torso": "torso", "legs": "legs4", "mouth": "jaws"}
	var base := LandParts.stats(body, LandParts.default_shape())
	var long := LandParts.default_shape()
	for i in 4:
		long.dims["leg%d" % i] = [2.0, 1.0, 1.0, 1.0]
	c.ok("все ноги длиннее — быстрее", LandParts.stats(body, long).speed > base.speed * 1.15)
	var one := LandParts.default_shape()
	one.dims["leg0"] = [2.0, 1.0, 1.0, 1.0]
	var s1: float = LandParts.stats(body, one).speed
	c.ok("одна длинная нога — прибавка меньше", s1 > base.speed and s1 < LandParts.stats(body, long).speed)
	var mouth := LandParts.default_shape()
	mouth.dims["mouth"] = [1.5, 1.5, 1.5, 1.2]
	c.ok("большой рот кусает сильнее", LandParts.stats(body, mouth).bite > base.bite + 1.0)
	c.ok("без ног ползает", LandParts.stats({"torso": "torso"}, LandParts.default_shape()).speed < 0.5)
	var e := _evo()
	e.land_start()
	e.land_shape.dims = {"leg3": [1.4, 1.1, 0.9, 1.2]}
	var back := Evolution.from_dict(JSON.parse_string(JSON.stringify(e.to_dict())))
	c.eq("размеры ноги сохраняются", back.land_shape.dims.leg3, [1.4, 1.1, 0.9, 1.2])

func test_прямоходящий(c) -> void:
	var sh := LandParts.fix_shape({"torso_pitch": 9.0})
	c.eq("поднять можно до стоймя, не больше", sh.torso_pitch, LandParts.SHAPE.torso_pitch[2])
	var body := {"torso": "torso", "legs": "legs2", "eyes": "eyes"}
	var up := LandParts.default_shape()
	up.torso_pitch = 1.3
	c.ok("голова выше — видно дальше", LandParts.stats(body, up).sight > LandParts.stats(body, LandParts.default_shape()).sight)
	var e := Evolution.create()
	e.land_body = body.duplicate()
	e.land_shape = up
	var back := Evolution.from_dict(JSON.parse_string(JSON.stringify(e.to_dict())))
	c.eq("наклон сохраняется", back.land_shape.torso_pitch, 1.3)

func test_много_рук(c) -> void:
	var e := _evo()
	e.dna_total = 400.0
	e.land_start()
	c.ok("без рук пар не прибавить", not e.land_set_arms(2).ok)
	e.land_put("arms")
	var free := e.land_free()
	c.ok("четыре руки", e.land_set_arms(2).ok)
	c.eq("вторая пара стоит как руки", e.land_free(), free - int(LandParts.PARTS.arms.cost))
	c.eq("цена рук — за обе пары", LandParts.part_cost("arms", e.land_shape), 2 * int(LandParts.PARTS.arms.cost))
	var one := LandParts.stats(e.land_body, LandParts.default_shape())
	c.ok("больше рук — сильнее бьёшь", LandParts.stats(e.land_body, e.land_shape).bite > one.bite)
	var before := e.land_free()
	c.ok("сменил на клешни — цена за обе пары", e.land_put("arms_claw").ok and e.land_free() == before + 2 * int(LandParts.PARTS.arms.cost) - 2 * int(LandParts.PARTS.arms_claw.cost))
	e.land_take("arms")
	c.eq("убрал руки — пары сбросились", LandParts.arm_pairs(e.land_shape), 1)
	e.land_put("arms")
	e.dna_total = 0.0
	var r := e.land_set_arms(3)
	c.ok("шесть рук не по карману — не ставятся: " + r.message, not r.ok and LandParts.arm_pairs(e.land_shape) == 1)

func test_место_рук_и_ног(c) -> void:
	var sh := LandParts.fix_shape({"place": {"leg2": [0.9, 0.5, 0.0], "arm3": [5, -9, 0.2], "head": [0, 0, 0], "leg0": [1, 2]}})
	c.eq("своё место у ноги", sh.place.leg2, [0.9, 0.5, 0.0])
	c.eq("в пределах", sh.place.arm3, [1.0, LandParts.PLACE_LIMITS[1][0], 0.2])
	c.ok("у головы места нет, кривое — выброшено", not sh.place.has("head") and not sh.place.has("leg0"))
	c.eq("по умолчанию — как раньше", LandParts.place(sh, "leg0", 4)[0], 0.78)
	var e := _evo()
	e.land_start()
	e.land_shape.place = {"arm1": [0.4, 0.8, -0.3]}
	var back := Evolution.from_dict(JSON.parse_string(JSON.stringify(e.to_dict())))
	c.eq("место сохраняется", back.land_shape.place.arm1, [0.4, 0.8, -0.3])

func test_число_ног_и_глаз(c) -> void:
	var e := _evo()
	e.dna_total = 400.0
	e.land_start()
	e.land_put("legs4")
	var free := e.land_free()
	c.ok("пять ног", e.land_set_count("legs", 5).ok and LandParts.leg_count(e.land_body, e.land_shape) == 5)
	c.eq("пятая нога — за свою цену", e.land_free(), free - (int(round(20.0 * 5 / 4)) - 20))
	c.eq("непарная — посередине", LandParts.leg_side(4, 5), 0.0)
	c.ok("одна нога — прыгает медленнее", LandParts.stats({"torso": "torso", "legs": "legs2"}, {"leg_n": 1.0}).speed < LandParts.stats({"torso": "torso", "legs": "legs2"}, {}).speed)
	e.land_put("legs6")
	c.eq("сменил вид ног — число обычное", LandParts.leg_count(e.land_body, e.land_shape), 6)
	c.ok("три глаза", e.land_set_count("eyes", 3).ok and LandParts.eye_count(e.land_body, e.land_shape) == 3)
	c.ok("больше глаз — видно дальше", LandParts.stats(e.land_body, e.land_shape).sight > LandParts.stats(e.land_body, LandParts.default_shape()).sight)
	e.dna_total = 0.0
	c.ok("восемь ног не по карману", not e.land_set_count("legs", 8).ok)
	var back := Evolution.from_dict(JSON.parse_string(JSON.stringify(e.to_dict())))
	c.eq("число глаз сохраняется", LandParts.eye_count(back.land_body, back.land_shape), 3)

func test_поворот_и_изгиб(c) -> void:
	var sh := LandParts.fix_shape({"rot": {"horns": 5.0, "wings": 1.0}, "torso_bend": 0.8, "tail_curl": 9.0,
		"place": {"eye2": [0.3, 1.2, 1.5], "eye9": [0, 0, 1]}})
	c.eq("поворот в пределах", sh.rot.horns, 1.2)
	c.ok("чужого поворота нет", not sh.rot.has("wings"))
	c.eq("изгиб хвоста в пределах", sh.tail_curl, LandParts.SHAPE.tail_curl[2])
	c.eq("место глаза", sh.place.eye2, [0.3, 1.2, 1.5])
	c.ok("чужого глаза нет", not sh.place.has("eye9"))
	var sp := LandParts.spine(sh, 1.0)
	c.ok("горб: середина выше концов", float(sp[2].y) > float(sp[0].y) + 0.2 and absf(float(sp[0].y)) < 0.01)
