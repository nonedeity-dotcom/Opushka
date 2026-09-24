## Твой вид: сколько ДНК накоплено, какие части открыты, как собрано тело. Это и есть
## сохранение — сам океан не сохраняется, он каждый раз новый вокруг тебя.
##
## ДНК копится за еду и победы. Всё накопленное — рост: от него размер клетки. Свободная
## ДНК — то, что не потрачено на части: поставил шип — 8 ДНК ушло, убрал — вернулось.
## Так пробовать разные тела ничего не стоит, а ставить всё сразу — не хватит.
class_name Evolution
extends RefCounted

const VERSION := 2

var dna_total := 0.0
## Части: id, a — угол в градусах от носа, d — глубина: 1 — на краю, 0 — в середине.
## Внутрь ставятся только «внутренние» части (глаз, хлоропласт, электроклетка).
var body: Array = []
## Форма тела: радиус в Content.SHAPE_POINTS направлениях, 1 — круг.
var shape: Array = []
var color := 0
var name := "Клеточка"
var unlocked := {}  # часть → уровень 1–5
var shards := {}  # часть → сколько копий уже собрано к следующему уровню
var seen := {}  # вид → true
var stats := {}  # plants, meat, kills, deaths, parts_found, edits, dashes
var kills_by := {}  # вид → сколько
var goals_done: Array = []
var difficulty := "normal"
## Второй цвет и узор тела.
var color2 := 5
var pattern := "none"
## Родословная: каким было тело в каждом поколении.
var history: Array = []
## Свита: сколько потомков плавает с тобой (растёт с поколениями, до трёх).
var brood := 0
var arena_best := 0
## Песочница: все части открыты, ДНК сколько угодно, пара не нужна.
var sandbox := false
var biomes_seen := {}
var lairs_beaten := {}
var achievements := {}
## Поколение: сколько раз находил пару и менял тело.
var generation := 1
## Сколько секунд сыграно — для меню сохранений.
var played := 0.0
## Покупки в магазине: улучшение → уровень. Это не части — на тело не ставятся.
var upgrades := {}
## Уровни, полученные даром (за части, которые раньше были на теле) — ДНК за них не списана.
var gifts := {}


static func create(diff := "normal") -> Evolution:
	var e := Evolution.new()
	e.difficulty = diff if Content.DIFFICULTY.has(diff) else "normal"
	e.body = Content.START_PARTS.duplicate(true)
	e.unlocked = Content.START_UNLOCKED.duplicate()
	e.shape = Content.shape_preset("round")
	return e


# --- рост -----------------------------------------------------------------------------

func level() -> int:
	return Content.level_for(dna_total)

func radius() -> float:
	return Content.radius_for(level())

func slots() -> int:
	return (12 if sandbox else Content.slots_for(level())) + upgrade_level("room") + int(Content.shape_stats(shape).slots)

## Доля пути до следующего размера, 0–1. На последнем — 1.
func growth() -> float:
	var lvl := level()
	if lvl >= Content.LEVELS.size():
		return 1.0
	var from: float = Content.LEVELS[lvl - 1].dna
	var to: float = Content.LEVELS[lvl].dna
	return clampf((dna_total - from) / (to - from), 0.0, 1.0)

## Добавить ДНК. true — клетка выросла.
func add_dna(amount: float) -> bool:
	var before := level()
	dna_total += maxf(0.0, amount)
	return level() > before

func cost_used() -> int:
	var sum := 0
	for p in body:
		sum += int(Content.PARTS[p.id].cost)
	return sum

func dna_free() -> int:
	return int(floor(dna_total)) + Content.START_DNA + (100000 if sandbox else 0) - cost_used() - shop_spent()


# --- магазин --------------------------------------------------------------------------

func upgrade_level(id: String) -> int:
	return int(upgrades.get(id, 0))

## Цена следующего уровня; -1 — уже всё куплено.
func upgrade_cost(id: String) -> int:
	var costs: Array = Content.UPGRADES[id].costs
	var lvl := upgrade_level(id)
	return int(costs[lvl]) if lvl < costs.size() else -1

## Сколько ДНК ушло в магазин — навсегда (в отличие от частей, её не вернуть).
func shop_spent() -> int:
	var sum := 0
	for id in upgrades:
		if Content.UPGRADES.has(id):
			var costs: Array = Content.UPGRADES[id].costs
			for i in range(int(gifts.get(id, 0)), mini(int(upgrades[id]), costs.size())):
				sum += int(costs[i])
	return sum

func buy(id: String) -> Dictionary:
	if not Content.UPGRADES.has(id):
		return {"ok": false, "message": "Такого нет"}
	var cost := upgrade_cost(id)
	if cost < 0:
		return {"ok": false, "message": "Уже куплено полностью"}
	if cost > dna_free():
		return {"ok": false, "message": "Не хватает ДНК: нужно %d, свободно %d" % [cost, dna_free()]}
	upgrades[id] = upgrade_level(id) + 1
	count("bought")
	return {"ok": true, "message": "%s: уровень %d" % [Content.UPGRADES[id].name, upgrades[id]]}


# --- тело -----------------------------------------------------------------------------

func mouth() -> String:
	for p in body:
		if Content.is_mouth(p.id):
			return p.id
	return ""

## Чем питаешься: plant, meat, both или "" — рта нет.
func diet() -> String:
	var m := mouth()
	return Content.PARTS[m].diet if m != "" else ""

static func snap(angle: float) -> int:
	var a := int(round(angle / Content.ANGLE_STEP)) * Content.ANGLE_STEP
	a = ((a + 180) % 360 + 360) % 360 - 180
	# От −180 не отличить 180 — пусть хвост всегда будет 180.
	return 180 if a == -180 else a

static func angle_gap(a: float, b: float) -> float:
	return absf(wrapf(a - b, -180.0, 180.0))

## Глубина по сетке; у самой середины — ровно середина. Краевые части — всегда на краю.
static func snap_depth(id: String, depth: float) -> float:
	if not Content.PARTS[id].get("inner", false):
		return 1.0
	if depth < 0.2:
		return 0.0
	return clampf(round(depth / Content.DEPTH_STEP) * Content.DEPTH_STEP, 0.0, 1.0)

## Где часть сидит на теле — в радиусах тела, без учёта формы.
## Где на теле стоит часть — по настоящей форме: на растянутом теле частям просторнее.
func anchor(a: float, d: float) -> Vector2:
	return Vector2.from_angle(deg_to_rad(a)) * d * Content.shape_at(shape, deg_to_rad(a))

## Можно ли поставить часть на этот угол и глубину. {ok, reason}. Рот ставится вместо старого.
func can_place(id: String, angle: int, depth := 1.0) -> Dictionary:
	if not Content.obtainable(id):
		return {"ok": false, "reason": "Эту часть не добыть — она есть только у существ"}
	if not unlocked.has(id):
		return {"ok": false, "reason": "Эта часть ещё не найдена"}
	var cost: int = Content.PARTS[id].cost
	var free := dna_free()
	var count := body.size()
	var old_mouth := mouth() if Content.is_mouth(id) else ""
	if old_mouth != "":
		free += int(Content.PARTS[old_mouth].cost)
		count -= 1
	if count >= slots():
		return {"ok": false, "reason": "Нет места: подрасти, чтобы поместилось больше частей"}
	if cost > free:
		return {"ok": false, "reason": "Не хватает ДНК: нужно %d, свободно %d" % [cost, free]}
	var here := anchor(angle, snap_depth(id, depth))
	for p in body:
		if p.id == old_mouth:
			continue
		if anchor(p.a, p.get("d", 1.0)).distance_to(here) < Content.PART_GAP - 0.001:
			return {"ok": false, "reason": "Тесно: рядом уже есть часть"}
	return {"ok": true, "reason": ""}

## Поставить часть. mirror — заодно и с другой стороны, если место и ДНК позволяют.
func place(id: String, angle: int, mirror := false, depth := 1.0) -> Dictionary:
	angle = snap(angle)
	depth = snap_depth(id, depth)
	if depth == 0.0:
		angle = 0
	var check := can_place(id, angle, depth)
	if not check.ok:
		return {"ok": false, "message": check.reason}
	if Content.is_mouth(id):
		for i in body.size():
			if Content.is_mouth(body[i].id):
				body.remove_at(i)
				break
	body.append({"id": id, "a": angle, "d": depth})
	stats.edits = stats.get("edits", 0) + 1
	var twin := false
	if mirror and not Content.is_mouth(id) and angle != 0 and absi(angle) != 180 and depth > 0.0:
		if can_place(id, -angle, depth).ok:
			body.append({"id": id, "a": -angle, "d": depth})
			twin = true
	var name_: String = Content.PARTS[id].name
	return {"ok": true, "message": ("Поставлено: %s ×2" if twin else "Поставлено: %s") % name_.to_lower()}

## Убрать часть — ДНК возвращается. Рот убрать можно: тогда клетка не ест, пока не
## поставишь новый.
func remove(index: int) -> Dictionary:
	if index < 0 or index >= body.size():
		return {"ok": false, "message": ""}
	var p: Dictionary = body[index]
	body.remove_at(index)
	return {"ok": true, "message": "Убрано: %s (+%d ДНК)" % [Content.PARTS[p.id].name.to_lower(), Content.PARTS[p.id].cost]}

## Части тела с уровнями и углами в радианах — для настоящей клетки.
func body_parts() -> Array:
	var out: Array = []
	for p in body:
		out.append({"id": p.id, "a": deg_to_rad(p.a), "d": float(p.get("d", 1.0)), "lvl": unlocked.get(p.id, 1)})
	return out


# --- форма ----------------------------------------------------------------------------

## Потянуть край тела в направлении angle (градусы от носа) до value радиусов. Соседние
## точки подтягиваются мягче — край получается плавным, без зубцов.
## Поменять форму можно, только если все стоящие части в новом теле поместятся.
func _shape_fits(new_shape: Array) -> bool:
	var old := shape
	shape = new_shape
	var ok := body.size() <= slots()
	shape = old
	return ok

func reshape(angle: float, value: float, mirror := false) -> bool:
	var before := shape.duplicate()
	_reshape(angle, value, mirror)
	if not _shape_fits(shape):
		shape = before
		return false
	return true

func _reshape(angle: float, value: float, mirror := false) -> void:
	value = clampf(value, Content.SHAPE_MIN, Content.SHAPE_MAX)
	var n := shape.size()
	for i in n:
		var ai := 360.0 * i / n
		for a in ([angle, -angle] if mirror else [angle]):
			var w := maxf(0.0, 1.0 - angle_gap(ai, a) / 40.0)
			if w > 0.0:
				shape[i] = lerpf(shape[i], value, w * w)

func set_shape(preset: String) -> bool:
	var s := Content.shape_preset(preset)
	if not _shape_fits(s):
		return false
	shape = s
	return true

## Сгладить: каждая точка — к среднему соседей.
func smooth_shape() -> void:
	var n := shape.size()
	var out: Array = []
	for i in n:
		out.append((shape[(i - 1 + n) % n] + shape[i] * 2.0 + shape[(i + 1) % n]) / 4.0)
	if _shape_fits(out):
		shape = out


# --- находки --------------------------------------------------------------------------

## Сколько копий нужно, чтобы часть этого уровня поднялась на следующий: 1, 2, 3, 4.
static func copies_for(level: int) -> int:
	return level

## Подобрал выпавшую часть. {new, level, up — поднялся ли уровень, have/need — копии к
## следующему, dna — бонус, если часть уже на пятом}.
func collect(part: String) -> Dictionary:
	stats.parts_found = stats.get("parts_found", 0) + 1
	if not unlocked.has(part):
		unlocked[part] = 1
		return {"new": true, "level": 1, "up": false, "have": 0, "need": copies_for(1), "dna": 0}
	var lvl: int = unlocked[part]
	if lvl >= Content.PART_MAX_LEVEL:
		add_dna(10)
		return {"new": false, "level": lvl, "up": false, "have": 0, "need": 0, "dna": 10}
	var have: int = shards.get(part, 0) + 1
	if have >= copies_for(lvl):
		unlocked[part] = lvl + 1
		shards.erase(part)
		return {"new": false, "level": lvl + 1, "up": true, "have": 0, "need": copies_for(lvl + 1), "dna": 0}
	shards[part] = have
	return {"new": false, "level": lvl, "up": false, "have": have, "need": copies_for(lvl), "dna": 0}

func count(stat: String, n := 1) -> void:
	stats[stat] = stats.get(stat, 0) + n


# --- задачи ---------------------------------------------------------------------------

func _goal_met(id: String) -> bool:
	match id:
		"eat":
			return stats.get("plants", 0) + stats.get("meat", 0) >= 10
		"grow":
			return level() >= 2
		"kill":
			return stats.get("kills", 0) >= 1
		"part":
			return unlocked.size() > Content.START_UNLOCKED.size()
		"edit":
			return body.any(func(p): return Content.PARTS[p.id].get("dash", false))
		"diet":
			return mouth() != "" and mouth() != "filter"
		"upgrade":
			return unlocked.values().any(func(l): return l >= 2)
		"size5":
			return level() >= 5
		"parts8":
			return unlocked.size() >= 8
		"boss":
			return kills_by.get("velikan", 0) + kills_by.get("leviafan", 0) + kills_by.get("titan", 0) > 0
		"lair":
			return not lairs_beaten.is_empty()
		"size10":
			return level() >= Content.LEVELS.size()
	return false

## Отметить выполненные. Возвращает только что выполненные задачи.
func check_goals() -> Array:
	var fresh: Array = []
	for g in Content.GOALS:
		if not goals_done.has(g.id) and _goal_met(g.id):
			goals_done.append(g.id)
			fresh.append(g)
	return fresh

func current_goal() -> Dictionary:
	for g in Content.GOALS:
		if not goals_done.has(g.id):
			return g
	return {}


# --- сохранение -----------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"dna_total": dna_total,
		"body": body.duplicate(true),
		"shape": shape.duplicate(),
		"color": color,
		"name": name,
		"unlocked": unlocked.duplicate(),
		"shards": shards.duplicate(),
		"seen": seen.duplicate(),
		"stats": stats.duplicate(),
		"kills_by": kills_by.duplicate(),
		"goals_done": goals_done.duplicate(),
		"difficulty": difficulty,
		"generation": generation,
		"played": played,
		"color2": color2,
		"pattern": pattern,
		"history": history.duplicate(true),
		"brood": brood,
		"arena_best": arena_best,
		"sandbox": sandbox,
		"biomes_seen": biomes_seen.duplicate(),
		"lairs_beaten": lairs_beaten.duplicate(),
		"achievements": achievements.duplicate(),
		"upgrades": upgrades.duplicate(),
		"gifts": gifts.duplicate(),
	}

## Прочитанное с диска. Непонятное выбрасывается по кусочку. null — сохранения нет.
static func from_dict(d: Variant) -> Evolution:
	if not d is Dictionary or not (d.get("dna_total") is float or d.get("dna_total") is int):
		return null
	var e := Evolution.create()
	e.dna_total = maxf(0.0, float(d.dna_total))
	for id in _dict(d.get("unlocked")):
		var l = d.unlocked[id]
		if Content.PARTS.has(id) and Content.obtainable(id) and (l is int or l is float):
			e.unlocked[id] = clampi(int(l), 1, Content.PART_MAX_LEVEL)
	# Форма и покупки — до тела: от них зависит, сколько частей на нём помещается.
	if d.get("shape") is Array and d.shape.size() == Content.SHAPE_POINTS and d.shape.all(func(v): return v is int or v is float):
		e.shape = d.shape.map(func(v): return clampf(float(v), Content.SHAPE_MIN, Content.SHAPE_MAX))
	e.sandbox = d.get("sandbox", false) == true
	for id in _dict(d.get("upgrades")):
		var n = d.upgrades[id]
		if Content.UPGRADES.has(id) and (n is int or n is float) and int(n) > 0:
			e.upgrades[id] = mini(int(n), Content.UPGRADES[id].costs.size())
	for id in _dict(d.get("gifts")):
		var n = d.gifts[id]
		if e.upgrades.has(id) and (n is int or n is float):
			e.gifts[id] = clampi(int(n), 0, int(e.upgrades[id]))
	# Термооболочка, жировая капля и хроматофоры раньше были частями — теперь это покупки.
	# Кто их уже добыл, получает их даром.
	var raw_unlocked := _dict(d.get("unlocked"))
	for pair in [["thermo", "heat"], ["fat", "cold"], ["camo", "camo"]]:
		if raw_unlocked.has(pair[0]) and not e.upgrades.has(pair[1]):
			e.upgrades[pair[1]] = 1
			e.gifts[pair[1]] = 1
	for id in _dict(d.get("shards")):
		var n = d.shards[id]
		if e.unlocked.has(id) and (n is int or n is float) and int(n) > 0:
			e.shards[id] = mini(int(n), copies_for(e.unlocked[id]) - 1)
	if d.get("body") is Array:
		e.body = []
		for p in d.body:
			if p is Dictionary and e.unlocked.has(str(p.get("id", ""))) and (p.get("a") is int or p.get("a") is float):
				var dep = p.get("d", 1.0)
				e.body.append({"id": str(p.id), "a": snap(float(p.a)), "d": snap_depth(str(p.id), float(dep) if (dep is int or dep is float) else 1.0)})
		# Лишнее не помещается или не по карману — снимаем последние части; совсем сломанное
		# тело — назад к стартовому, лишь бы клетка жила.
		while e.body.size() > 0 and (e.body.size() > e.slots() or e.dna_free() < 0):
			e.body.pop_back()
		if e.body.is_empty():
			e.body = Content.START_PARTS.duplicate(true)
	# Сохранение времён, когда рывок был у всех: ставим толчковый пузырь сами, если есть
	# место и ДНК, — чтобы рывок не пропал.
	if not _dict(d.get("unlocked")).has("sac") and not e.body.any(func(p): return Content.PARTS[p.id].get("dash", false)):
		for a in [180, 150, -150, 120, -120, 90, -90, 135, -135, 165, -165, 60, -60, 45, -45]:
			if e.can_place("sac", a).ok:
				e.body.append({"id": "sac", "a": a, "d": 1.0})
				break
	var c = d.get("color")
	if (c is int or c is float) and int(c) >= 0 and int(c) < Content.COLORS.size():
		e.color = int(c)
	if d.get("name") is String and d.name.strip_edges() != "":
		e.name = d.name.strip_edges().left(18)
	for s in _dict(d.get("seen")):
		if Content.SPECIES.has(s):
			e.seen[s] = true
	for k in _dict(d.get("stats")):
		var n = d.stats[k]
		if n is int or n is float:
			e.stats[k] = int(n)
	for s in _dict(d.get("kills_by")):
		var n = d.kills_by[s]
		if Content.SPECIES.has(s) and (n is int or n is float):
			e.kills_by[s] = int(n)
	if Content.DIFFICULTY.has(str(d.get("difficulty", ""))):
		e.difficulty = str(d.difficulty)
	var gen = d.get("generation")
	if gen is int or gen is float:
		e.generation = maxi(1, int(gen))
	var c2 = d.get("color2")
	if (c2 is int or c2 is float) and int(c2) >= 0 and int(c2) < Content.COLORS.size():
		e.color2 = int(c2)
	if Content.PATTERNS.any(func(pp): return pp[0] == str(d.get("pattern", ""))):
		e.pattern = str(d.pattern)
	if d.get("history") is Array:
		for h in d.history:
			if h is Dictionary:
				e.history.append(h)
		e.history = e.history.slice(-60)
	for key in ["brood", "arena_best"]:
		var n = d.get(key)
		if n is int or n is float:
			e.set(key, clampi(int(n), 0, 3 if key == "brood" else 9999))
	for b in _dict(d.get("biomes_seen")):
		if Content.BIOMES.has(b):
			e.biomes_seen[b] = true
	for b in _dict(d.get("lairs_beaten")):
		if Content.SPECIES.has(b):
			e.lairs_beaten[b] = true
	for a in _dict(d.get("achievements")):
		e.achievements[a] = true
	var pl = d.get("played")
	if pl is int or pl is float:
		e.played = maxf(0.0, float(pl))
	if d.get("goals_done") is Array:
		for g in d.goals_done:
			if g is String:
				e.goals_done.append(g)
	return e

static func _dict(x: Variant) -> Dictionary:
	return x if x is Dictionary else {}

func diff() -> Dictionary:
	return Content.DIFFICULTY[difficulty]

## На тяжёлой сложности гибель отнимает часть пути до следующего размера.
func death_loss() -> float:
	var k: float = diff().death
	if k <= 0.0:
		return 0.0
	var floor_dna: float = Content.LEVELS[level() - 1].dna
	var lost := (dna_total - floor_dna) * k
	dna_total -= lost
	return lost


# --- песочница, родословная, достижения -----------------------------------------------

static func create_sandbox() -> Evolution:
	var e := Evolution.create("easy")
	e.sandbox = true
	e.name = "Песочница"
	for id in Content.PARTS:
		if Content.obtainable(id):
			e.unlocked[id] = Content.PART_MAX_LEVEL
	e.brood = 3
	return e

## Запомнить нынешнее тело в родословной (после встречи с парой и правки).
func remember() -> void:
	var snap := {"gen": generation, "level": level(), "body": body.duplicate(true), "shape": shape.duplicate(),
		"color": color, "color2": color2, "pattern": pattern}
	if not history.is_empty() and history[-1].gen == generation:
		history[-1] = snap
	else:
		history.append(snap)
	history = history.slice(-60)

## Прогресс достижения: [сколько есть, сколько нужно].
func achievement_progress(a: Dictionary) -> Array:
	var need: int = a.need
	var have := 0
	match a.stat:
		"@parts":
			have = unlocked.size()
			if need < 0:
				need = Content.PARTS.keys().filter(func(p): return Content.obtainable(p)).size()
		"@maxed":
			have = unlocked.values().filter(func(l): return l >= Content.PART_MAX_LEVEL).size()
		"@biomes":
			have = biomes_seen.size()
		"@lairs":
			have = lairs_beaten.size()
		"@generation":
			have = generation
		"@brood":
			have = brood
		"@level":
			have = level()
		"@arena":
			have = arena_best
		_:
			have = int(stats.get(a.stat, 0))
	return [mini(have, need), need]

## Отметить полученные достижения. Возвращает только что полученные.
func check_achievements() -> Array:
	var fresh: Array = []
	for a in Content.ACHIEVEMENTS:
		if achievements.has(a.id):
			continue
		var pr := achievement_progress(a)
		if pr[0] >= pr[1]:
			achievements[a.id] = true
			fresh.append(a)
	return fresh

