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
	c.ok("снял ноги — лапки", e.land_take("legs").ok and e.land_body.legs == "stubs" and e.land_free() == free)
	c.ok("лапки не снять", not e.land_take("legs").ok)
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
	c.eq("чужое выброшено, ноги — лапки", b2.land_body, {"arms": "arms", "legs": "stubs"})
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
	e.land_body = body
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
