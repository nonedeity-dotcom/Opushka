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


static func create() -> Evolution:
	var e := Evolution.new()
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
	return Content.slots_for(level())

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
	return int(floor(dna_total)) + Content.START_DNA - cost_used()


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
static func anchor(a: float, d: float) -> Vector2:
	return Vector2.from_angle(deg_to_rad(a)) * d

## Можно ли поставить часть на этот угол и глубину. {ok, reason}. Рот ставится вместо старого.
func can_place(id: String, angle: int, depth := 1.0) -> Dictionary:
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
func reshape(angle: float, value: float, mirror := false) -> void:
	value = clampf(value, Content.SHAPE_MIN, Content.SHAPE_MAX)
	var n := shape.size()
	for i in n:
		var ai := 360.0 * i / n
		for a in ([angle, -angle] if mirror else [angle]):
			var w := maxf(0.0, 1.0 - angle_gap(ai, a) / 40.0)
			if w > 0.0:
				shape[i] = lerpf(shape[i], value, w * w)

func set_shape(preset: String) -> void:
	shape = Content.shape_preset(preset)

## Сгладить: каждая точка — к среднему соседей.
func smooth_shape() -> void:
	var n := shape.size()
	var out: Array = []
	for i in n:
		out.append((shape[(i - 1 + n) % n] + shape[i] * 2.0 + shape[(i + 1) % n]) / 4.0)
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
			return stats.get("edits", 0) >= 1
		"diet":
			return mouth() != "" and mouth() != "filter"
		"upgrade":
			return unlocked.values().any(func(l): return l >= 2)
		"size5":
			return level() >= 5
		"parts8":
			return unlocked.size() >= 8
		"boss":
			return kills_by.get("velikan", 0) + kills_by.get("leviafan", 0) > 0
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
	}

## Прочитанное с диска. Непонятное выбрасывается по кусочку. null — сохранения нет.
static func from_dict(d: Variant) -> Evolution:
	if not d is Dictionary or not (d.get("dna_total") is float or d.get("dna_total") is int):
		return null
	var e := Evolution.create()
	e.dna_total = maxf(0.0, float(d.dna_total))
	for id in _dict(d.get("unlocked")):
		var l = d.unlocked[id]
		if Content.PARTS.has(id) and (l is int or l is float):
			e.unlocked[id] = clampi(int(l), 1, Content.PART_MAX_LEVEL)
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
		# Сломанное или слишком дорогое тело — назад к стартовому, лишь бы клетка жила.
		if e.body.size() > e.slots() or e.dna_free() < 0:
			e.body = Content.START_PARTS.duplicate(true)
	if d.get("shape") is Array and d.shape.size() == Content.SHAPE_POINTS and d.shape.all(func(v): return v is int or v is float):
		e.shape = d.shape.map(func(v): return clampf(float(v), Content.SHAPE_MIN, Content.SHAPE_MAX))
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
	if d.get("goals_done") is Array:
		for g in d.goals_done:
			if g is String:
				e.goals_done.append(g)
	return e

static func _dict(x: Variant) -> Dictionary:
	return x if x is Dictionary else {}
