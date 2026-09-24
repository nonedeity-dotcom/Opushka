## Правила «Опушки»: состояние мира и всё, что с ним можно сделать.
##
## Экран только рисует и зовёт эти функции. Каждое действие меняет состояние и возвращает
## «исход» — что сказать, каким звуком отозваться, выполнена ли задача. Так правила
## проверяются без экрана, одним прогоном тестов.
##
## Время идёт только от действий: шаг, сбор, ремесло. Отложил телефон — мир замер, и ничего
## не случится без тебя.
class_name Village
extends RefCounted

const VERSION := 2
## Первый день начинается утром, а не в полночь.
const START_TIME := 8 * 60
## Сколько игровых минут стоит пройти одну клетку.
const MINUTES_PER_TILE := 2.0
const FOOD_PER_MINUTE := 1.0 / 15.0
## Персонаж — круг такого радиуса в клетках. Меньше половины клетки: между двумя деревьями
## через клетку он проходит.
const RADIUS := 0.3

var seed: int
var time: float
## Положение в клетках: (10.5, 7.5) — середина клетки (10, 7).
var pos: Vector2
## Куда смотрит — единичный вектор.
var facing := Vector2.DOWN
## Сытость, 0–100. На нуле всё делается вдвое дольше — и только.
var food: float
var bag := {}
## Когда клетку последний раз собрали: "x:y" → игровая минута. От этого — отросло ли.
var used := {}
## Что построено: "x:y" → постройка.
var built := {}
## Сколько чего собрано за всё время.
var gathered := {}
var goals_done: Array = []
## Воды в лейке, 0–CAN_SIZE.
var water := 0
## Грядки: "x:y" → {crop, g — сколько минут уже росло, last — с какой минуты считать,
## wet — до какой минуты земля влажная}. Пустая сухая грядка записи не имеет.
var beds := {}
## Курятники: "x:y" → {fed — в какой день насыпали семечек, eggs — сколько яиц лежит}.
var coops := {}
## Сколько зайцев приручено: они ходят следом.
var pets := 0
## Звери вокруг — живут на экране, в сохранение не идут. null — зверей нет (в тестах правил).
var animals: Animals = null


static func create(seed_: int) -> Village:
	var v := Village.new()
	v.seed = seed_
	v.time = START_TIME
	var start: Vector2i = v.world().start
	v.pos = Vector2(start) + Vector2(0.5, 0.5)
	v.food = 80.0
	return v


func world() -> Dictionary:
	return WorldGen.make(seed)


static func key(c: Vector2i) -> String:
	return "%d:%d" % [c.x, c.y]


# --- время ----------------------------------------------------------------------------

func day() -> int:
	return int(time / Content.DAY) + 1

func minute_of_day() -> float:
	return fmod(time, Content.DAY)

func hour() -> int:
	return int(minute_of_day() / 60.0)

func clock() -> String:
	var m := int(minute_of_day())
	return "%d:%02d" % [m / 60, m % 60]

func is_night() -> bool:
	var h := hour()
	return h >= 21 or h < 6

## Насколько темно, 0–1: сумерки с 19 до 21, рассвет с 5 до 7 — плавные.
func darkness() -> float:
	var h := minute_of_day() / 60.0
	if h >= 21.0 or h < 5.0:
		return 1.0
	if h >= 19.0:
		return (h - 19.0) / 2.0
	if h < 7.0:
		return 1.0 - (h - 5.0) / 2.0
	return 0.0

func _pass(minutes: float) -> void:
	time += minutes
	food = maxf(0.0, food - minutes * FOOD_PER_MINUTE)


# --- клетки ---------------------------------------------------------------------------

func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < WorldGen.SIZE and c.y < WorldGen.SIZE

## Что на клетке: земля, что растёт (и не собрано ли), что построено. {} — за краем мира.
func cell(c: Vector2i) -> Dictionary:
	if not inside(c):
		return {}
	var w := world()
	var i := c.y * WorldGen.SIZE + c.x
	var k := key(c)
	var structure: String = built.get(k, "")
	# Под постройкой ничего не растёт — иначе через день из-под костра вылезли бы ветки.
	var nature: String = "" if structure != "" else w.nature[i]
	var depleted := false
	if nature != "" and used.has(k):
		depleted = time - float(used[k]) < float(Content.NATURE[nature].regrow)
	var look := ""
	if structure == "bed":
		var b := bed(c)
		look = "%s:%d:%d" % [b.crop, b.stage, 1 if b.wet else 0]
	elif structure == "coop":
		look = "eggs:%d" % coop_eggs(c)
	return {"ground": w.ground[i], "nature": nature, "depleted": depleted, "built": structure, "look": look}

## Мешает ли клетка пройти.
func blocks(c: Vector2i) -> bool:
	var info := cell(c)
	if info.is_empty() or info.ground == WorldGen.Ground.WATER:
		return true
	if info.built != "":
		return not Content.STRUCTURES[info.built].get("walk", false)
	if info.nature == "":
		return false
	if not info.depleted:
		return not Content.UNDERFOOT.has(info.nature)
	return Content.NATURE[info.nature].leaves != "nothing"

func tile_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x), floori(p.y))

## Упирается ли круг персонажа, поставленный в точку p, во что-нибудь.
func _collides(p: Vector2) -> bool:
	var lo := tile_of(p - Vector2(RADIUS, RADIUS))
	var hi := tile_of(p + Vector2(RADIUS, RADIUS))
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var c := Vector2i(x, y)
			if not blocks(c):
				continue
			# Ближайшая к центру точка клетки — дальше ли она радиуса.
			var nearest := Vector2(clampf(p.x, x, x + 1), clampf(p.y, y, y + 1))
			if nearest.distance_squared_to(p) < RADIUS * RADIUS - 0.0001:
				return true
	return false


# --- ходьба ---------------------------------------------------------------------------

## Пройти на вектор delta (в клетках). Упёрся — скользит вдоль препятствия, а не встаёт
## как вкопанный: оси проверяются по отдельности, мелкими шажками, чтобы не проскочить
## сквозь тонкое.
func walk(delta: Vector2) -> Dictionary:
	if delta.length() < 0.0001:
		return {}
	facing = delta.normalized()
	var start := pos
	var steps := ceili(delta.length() / 0.2)
	var part := delta / steps
	for i in steps:
		var tx := pos + Vector2(part.x, 0)
		if not _collides(tx):
			pos = tx
		var ty := pos + Vector2(0, part.y)
		if not _collides(ty):
			pos = ty
	var moved := pos.distance_to(start)
	if moved > 0.0:
		_pass(moved * MINUTES_PER_TILE)
	# Ветки и камешки подбираются, когда на них наступаешь.
	var here := tile_of(pos)
	var info := cell(here)
	if info.get("nature", "") in Content.UNDERFOOT and not info.depleted:
		var out := _gather(here, info.nature)
		out.moved = moved
		return out
	return {"moved": moved}

## Повернуться, не двигаясь.
func face(dir: Vector2) -> void:
	if dir.length() > 0.0001:
		facing = dir.normalized()

## Направление взгляда по главной оси — к какой из четырёх соседних клеток он повёрнут.
func facing4() -> Vector2i:
	if absf(facing.x) >= absf(facing.y):
		return Vector2i(1 if facing.x > 0 else -1, 0)
	return Vector2i(0, 1 if facing.y > 0 else -1)

## Клетка, к которой относится кнопка действия.
##
## Сначала — соседняя клетка по направлению взгляда. Если там делать нечего, а впереди
## наискосок, в пределах шага, что-то есть, — берётся это: при плавной ходьбе стоишь не
## ровно напротив дерева, и кнопка не должна требовать встать по линейке.
func target() -> Vector2i:
	var here := tile_of(pos)
	var straight := here + facing4()
	if _actionable(straight):
		return straight
	var ahead := tile_of(pos + facing * 0.9)
	if ahead != here and _actionable(ahead) and (ahead - here).length_squared() <= 2:
		return ahead
	return straight

func _actionable(c: Vector2i) -> bool:
	var info := cell(c)
	if info.is_empty():
		return false
	return info.built != "" or (info.nature != "" and not info.depleted) or info.ground == WorldGen.Ground.WATER


# --- что сделает кнопка ---------------------------------------------------------------

func action_label() -> String:
	var a := _animal_for_button()
	if a != null:
		return _animal_label(a)
	return _cell_label()

func _cell_label() -> String:
	var info := cell(target())
	if info.is_empty():
		return ""
	if info.built == "bed":
		return _bed_label(target())
	if info.built == "coop":
		var eggs := coop_eggs(target())
		if eggs > 0:
			return "Собрать яйца"
		return "Насыпать семечек" if coops.get(key(target()), {}).get("fed", 0) != day() else "Курятник"
	if info.built != "":
		var s: Dictionary = Content.STRUCTURES[info.built]
		if s.has("sleep") and is_night():
			return "Спать"
		return s.name
	if info.nature != "" and not info.depleted:
		return Content.NATURE[info.nature].verb
	if info.ground == WorldGen.Ground.WATER:
		return "Набрать воды" if bag.get("can", 0) > 0 and water < Content.CAN_SIZE else "Вода"
	return ""

## Значок для кнопки: вещь, которая нужна или получится, «sleep» или «water».
func action_icon() -> String:
	var a := _animal_for_button()
	if a != null:
		return "carrot" if a.kind == "hare" and not a.tame and bag.get("carrot", 0) > 0 else "heart"
	var info := cell(target())
	if info.is_empty():
		return ""
	if info.built == "bed":
		var b := bed(target())
		if b.crop == "":
			var sd := _first_seed()
			return sd if sd != "" else "bed"
		if b.ripe:
			return Content.CROPS[b.crop].gives.keys()[0]
		return "sprout" if b.wet else "can"
	if info.built == "coop":
		return "egg" if coop_eggs(target()) > 0 else "sunflower_seed"
	if info.built != "":
		if Content.STRUCTURES[info.built].has("sleep") and is_night():
			return "sleep"
		return Content.item_for_structure(info.built)
	if info.nature != "" and not info.depleted:
		var def: Dictionary = Content.NATURE[info.nature]
		return def.get("needs", def.gives.keys()[0])
	if info.ground == WorldGen.Ground.WATER:
		return "water"
	return ""


# --- действия -------------------------------------------------------------------------

static func _out(message: String, sound := "", goal := false) -> Dictionary:
	return {"message": message, "sound": sound, "goal": goal}

func act() -> Dictionary:
	var a := _animal_for_button()
	if a != null:
		return _act_animal(a)
	var c := target()
	var info := cell(c)
	if info.is_empty():
		return {}
	if info.built == "bed":
		return _act_bed(c)
	if info.built == "coop":
		return _act_coop(c)
	if info.built != "":
		var s: Dictionary = Content.STRUCTURES[info.built]
		if s.has("sleep"):
			return _sleep(s.sleep)
		if s.get("station", false):
			return _out("%s рядом — в «Сумке» открылись новые рецепты" % s.name, "ui")
		return _out(s.name, "ui")
	if info.ground == WorldGen.Ground.WATER and info.nature == "":
		if bag.get("can", 0) <= 0:
			return _out("Тихая вода. Будет лейка — будет чем поливать грядки", "water")
		if water >= Content.CAN_SIZE:
			return _out("Лейка и так полная", "water")
		water = Content.CAN_SIZE
		_pass(3)
		return _out("Лейка полная — хватит на %d грядок" % Content.CAN_SIZE, "water")
	if info.nature == "":
		return {}
	var def: Dictionary = Content.NATURE[info.nature]
	if info.depleted:
		if def.leaves == "stump":
			return _out("Пень. Дерево отрастёт через пару дней", "nope")
		return _out("%s: ещё не выросло" % def.name, "nope")
	if def.has("needs") and bag.get(def.needs, 0) <= 0:
		return _out("Нужен инструмент: %s" % Content.ITEMS[def.needs].name.to_lower(), "nope")
	return _gather(c, info.nature)

func _gather(c: Vector2i, id: String) -> Dictionary:
	var def: Dictionary = Content.NATURE[id]
	# Голодному всё даётся вдвое дольше. Не наказание — просто повод поесть.
	var minutes: float = def.minutes * (2.0 if food <= 0.0 else 1.0)
	_add(def.gives)
	used[key(c)] = time
	gathered[id] = gathered.get(id, 0) + 1
	_pass(minutes)
	var out := _with_goals(_describe(def.gives), def.sound)
	out.gathered = id
	out.cell = c
	return out

func _add(gives: Dictionary) -> void:
	for id in gives:
		bag[id] = bag.get(id, 0) + gives[id]

static func _describe(gives: Dictionary) -> String:
	var parts: Array[String] = []
	for id in gives:
		var n: int = gives[id]
		var item: Dictionary = Content.ITEMS[id]
		var word: String = Content.plural(n, item.forms) if item.has("forms") else item.name.to_lower()
		parts.append("+%d %s" % [n, word])
	return ", ".join(parts)

func _sleep(kind: String) -> Dictionary:
	if not is_night():
		return _out("Спать ещё рано — ночь начнётся в 21:00", "nope")
	var day_start := time - minute_of_day()
	var morning := day_start + Content.DAY + 7 * 60 if hour() >= 21 else day_start + 7 * 60
	time = morning
	# Во сне голод идёт медленнее — иначе после каждой ночи просыпался бы пустым.
	food = maxf(0.0, food - 10.0)
	var out := _out("Выспался в домике. Доброе утро" if kind == "cozy" else "Переночевал у костра. Утро", "sleep")
	out.slept = true
	return out

func eat(id: String) -> Dictionary:
	var item: Dictionary = Content.ITEMS.get(id, {})
	if not item.has("food") or bag.get(id, 0) <= 0:
		return {}
	bag[id] -= 1
	food = minf(100.0, food + item.food)
	_pass(2)
	return _out("Съел: %s" % item.name.to_lower(), "eat")

## Что съесть по кнопке «съесть»: сначала то, что не нужно больше ни для чего. Семечки
## не едим — они для грядок и кур.
func snack() -> String:
	for id in ["berries", "egg", "carrot"]:
		if bag.get(id, 0) > 0:
			return id
	return ""

## Стоит ли рядом (в соседней клетке, включая углы) такая постройка.
func near(structure: String) -> bool:
	var here := tile_of(pos)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if built.get(key(here + Vector2i(dx, dy)), "") == structure:
				return true
	return false

## {ok: true} или {ok: false, reason: "..."}.
func can_craft(r: Dictionary) -> Dictionary:
	if r.has("at") and not near(r.at):
		return {"ok": false, "reason": "Нужно стоять %s" % Content.STRUCTURES[r.at].near}
	for id in r.needs:
		if bag.get(id, 0) < r.needs[id]:
			return {"ok": false, "reason": "Не хватает"}
	if Content.ITEMS[r.makes].get("tool", false) and bag.get(r.makes, 0) > 0:
		return {"ok": false, "reason": "Уже есть"}
	return {"ok": true, "reason": ""}

func craft(recipe_id: String) -> Dictionary:
	var r := Content.recipe(recipe_id)
	if r.is_empty():
		return {}
	var check := can_craft(r)
	if not check.ok:
		return _out(check.reason, "nope")
	for id in r.needs:
		bag[id] -= r.needs[id]
	bag[r.makes] = bag.get(r.makes, 0) + r.count
	_pass(r.minutes)
	return _with_goals("Сделано: %s" % Content.ITEMS[r.makes].name.to_lower(), "craft")

## Поставить постройку из сумки на клетку, к которой повернулся.
func place(item_id: String) -> Dictionary:
	var structure: String = Content.ITEMS.get(item_id, {}).get("places", "")
	if structure == "" or bag.get(item_id, 0) <= 0:
		return {}
	var c := tile_of(pos) + facing4()
	var info := cell(c)
	if info.is_empty() or blocks(c) or (info.nature != "" and not info.depleted):
		return _out("Здесь не поставить — повернись к свободной земле", "nope")
	bag[item_id] -= 1
	built[key(c)] = structure
	_pass(15)
	var said := "Поставлено: %s" % Content.STRUCTURES[structure].name.to_lower()
	if structure == "coop":
		said = "Курятник готов — в нём поселились две курицы"
	var out := _with_goals(said, "place")
	out.cell = c
	if animals:
		animals.sync_chickens(self)
	return out

## Разобрать постройку перед собой — она вернётся в сумку целиком.
func pick_up() -> Dictionary:
	var c := target()
	var k := key(c)
	if not built.has(k):
		return {}
	var structure: String = built[k]
	built.erase(k)
	beds.erase(k)
	coops.erase(k)
	var item := Content.item_for_structure(structure)
	bag[item] = bag.get(item, 0) + 1
	_pass(10)
	var out := _out("Разобрано: %s" % Content.STRUCTURES[structure].name.to_lower(), "pickup")
	out.cell = c
	if animals:
		animals.sync_chickens(self)
	return out


# --- огород ---------------------------------------------------------------------------

## Что на грядке сейчас: {crop, stage 0–3, wet, ripe, grown}. Рост считается от времени:
## сколько минут из прошедших земля была влажной.
func bed(c: Vector2i) -> Dictionary:
	var b: Dictionary = beds.get(key(c), {})
	var crop: String = b.get("crop", "")
	var wet: bool = time < float(b.get("wet", -1.0))
	var out := {"crop": crop, "stage": 0, "wet": wet, "ripe": false, "grown": 0.0}
	if crop == "":
		return out
	var grown := _grown(b)
	var need: float = Content.CROPS[crop].grow
	out.grown = grown
	out.ripe = grown >= need
	out.stage = 3 if out.ripe else (2 if grown >= need * 0.5 else (1 if grown >= need * 0.15 else 0))
	return out

func _grown(b: Dictionary) -> float:
	var from: float = b.get("last", time)
	var until: float = minf(time, float(b.get("wet", -1.0)))
	return float(b.get("g", 0.0)) + maxf(0.0, until - from)

func _first_seed() -> String:
	for id in ["carrot_seed", "sunflower_seed"]:
		if bag.get(id, 0) > 0:
			return id
	return ""

func _bed_label(c: Vector2i) -> String:
	var b := bed(c)
	if b.crop == "":
		return "Посадить" if _first_seed() != "" else "Грядка"
	if b.ripe:
		return "Собрать урожай"
	return "Растёт" if b.wet else "Полить"

func _act_bed(c: Vector2i) -> Dictionary:
	var b := bed(c)
	if b.crop == "":
		var sd := _first_seed()
		if sd == "":
			return _out("Нужны семена: дикая морковь и подсолнухи растут на полянах", "nope")
		return plant(sd)
	if b.ripe:
		return _harvest(c)
	if b.wet:
		var left := int(ceil((Content.CROPS[b.crop].grow - b.grown) / 60.0))
		return _out("%s растёт. Земля влажная — до урожая ещё %d ч" % [Content.CROPS[b.crop].name, maxi(left, 1)], "ui")
	return _water(c)

## Посадить семя на грядку, к которой повернулся.
func plant(seed_id: String) -> Dictionary:
	var crop: String = Content.ITEMS.get(seed_id, {}).get("seed", "")
	if crop == "" or bag.get(seed_id, 0) <= 0:
		return {}
	var c := target()
	if built.get(key(c), "") != "bed":
		return _out("Повернись к грядке — сажают в неё", "nope")
	if bed(c).crop != "":
		return _out("Здесь уже растёт %s" % Content.CROPS[bed(c).crop].name.to_lower(), "nope")
	bag[seed_id] -= 1
	var old: Dictionary = beds.get(key(c), {})
	beds[key(c)] = {"crop": crop, "g": 0.0, "last": time, "wet": float(old.get("wet", -1.0))}
	gathered.planted = gathered.get("planted", 0) + 1
	_pass(5)
	var said := "Посажено: %s" % Content.CROPS[crop].name.to_lower()
	if not bed(c).wet:
		said += ". Теперь полей"
	var out := _with_goals(said, "plant")
	out.cell = c
	return out

func _water(c: Vector2i) -> Dictionary:
	if bag.get("can", 0) <= 0:
		return _out("Нужна лейка: 2 бревна и 2 ветки", "nope")
	if water <= 0:
		return _out("Лейка пустая — набери воды у пруда", "nope")
	var k := key(c)
	var b: Dictionary = beds.get(k, {"crop": ""})
	# Сначала записать, сколько уже выросло, потом начать новый отсчёт.
	b.g = _grown(b) if b.get("crop", "") != "" else 0.0
	b.last = time
	b.wet = time + Content.WET_MINUTES
	beds[k] = b
	water -= 1
	gathered.watered = gathered.get("watered", 0) + 1
	_pass(3)
	var out := _with_goals("Полито. В лейке осталось: %d" % water, "pour")
	out.cell = c
	return out

func _harvest(c: Vector2i) -> Dictionary:
	var k := key(c)
	var def: Dictionary = Content.CROPS[beds[k].crop]
	_add(def.gives)
	beds[k] = {"crop": "", "g": 0.0, "last": time, "wet": float(beds[k].get("wet", -1.0))}
	gathered.harvest = gathered.get("harvest", 0) + 1
	_pass(5)
	var out := _with_goals("Урожай! " + _describe(def.gives), "harvest")
	out.cell = c
	return out


# --- курятник -------------------------------------------------------------------------

## Сколько яиц лежит: если кур кормили в какой-то из прошлых дней — наутро они снеслись.
func coop_eggs(c: Vector2i) -> int:
	var cp: Dictionary = coops.get(key(c), {})
	var eggs: int = cp.get("eggs", 0)
	var fed: int = cp.get("fed", 0)
	if fed > 0 and day() > fed:
		eggs += Content.COOP_EGGS
	return mini(eggs, Content.COOP_MAX_EGGS)

func _act_coop(c: Vector2i) -> Dictionary:
	var k := key(c)
	var eggs := coop_eggs(c)
	var fed_today: bool = coops.get(k, {}).get("fed", 0) == day()
	if eggs > 0:
		bag.egg = bag.get("egg", 0) + eggs
		coops[k] = {"fed": day() if fed_today else 0, "eggs": 0}
		gathered.eggs = gathered.get("eggs", 0) + eggs
		_pass(3)
		var out := _with_goals("+%d %s" % [eggs, Content.plural(eggs, Content.ITEMS.egg.forms)], "cluck")
		out.cell = c
		return out
	if fed_today:
		return _out("Куры сыты. Яйца будут завтра утром", "cluck")
	if bag.get("sunflower_seed", 0) < Content.COOP_FEED:
		return _out("Курам нужны семечки: %d штуки. Подсолнухи растут на полянах" % Content.COOP_FEED, "nope")
	bag.sunflower_seed -= Content.COOP_FEED
	coops[k] = {"fed": day(), "eggs": coop_eggs(c)}
	_pass(3)
	var out := _out("Насыпал семечек. Утром будут яйца", "cluck")
	out.cell = c
	return out


# --- звери ----------------------------------------------------------------------------

## Зверь рядом, к которому относится кнопка: совсем близко — в любую сторону, чуть дальше —
## только тот, на кого смотришь.
func animal_near() -> Animals.Animal:
	if animals == null:
		return null
	var best: Animals.Animal = null
	var best_d := INF
	for a in animals.list:
		if a.kind == "bird":
			continue
		var to: Vector2 = a.pos - pos
		var d := to.length()
		var ok := d <= 1.1 or (d <= 1.6 and to.normalized().dot(facing) > 0.5)
		if ok and d < best_d:
			best = a
			best_d = d
	return best

## Зверь забирает кнопку себе, только если его можно покормить или перед тобой больше
## ничего нет: ручной заяц вертится рядом и не должен мешать поливать грядку.
func _animal_for_button() -> Animals.Animal:
	var a := animal_near()
	if a == null:
		return null
	if a.kind == "hare" and not a.tame and bag.get("carrot", 0) > 0:
		return a
	return a if _cell_label() == "" else null

func _animal_label(a: Animals.Animal) -> String:
	if a.kind == "hare" and not a.tame:
		return "Покормить" if bag.get("carrot", 0) > 0 else "Заяц"
	return "Погладить"

func _act_animal(a: Animals.Animal) -> Dictionary:
	face(a.pos - pos)
	var out: Dictionary
	if a.kind == "hare" and not a.tame:
		if bag.get("carrot", 0) <= 0:
			out = _out("Заяц принюхивается. Зайцы любят морковку", "nope")
		else:
			bag.carrot -= 1
			a.tame = true
			pets += 1
			gathered.hare = gathered.get("hare", 0) + 1
			_pass(2)
			out = _with_goals("Заяц взял морковку и теперь ходит за тобой", "pet")
			out.hearts = a.pos
		return out
	if a.kind == "hare":
		out = _out("Заяц жмурится от удовольствия", "pet")
	else:
		out = _out("Курица довольно квохчет", "cluck")
	out.hearts = a.pos
	return out


# --- дорога по касанию ----------------------------------------------------------------

## Дорога до клетки, по которой нажали: список клеток, по которым идти, без своей.
##
## Если на клетке что-то стоит (дерево, костёр), дорога ведёт к соседней свободной, а
## `face` говорит, куда потом повернуться. Поиск в ширину: мир маленький, 64×64, и самая
## короткая дорога находится мгновенно. {} — не дойти.
func path_to(goal: Vector2i) -> Dictionary:
	var here := tile_of(pos)
	if not inside(goal) or goal == here:
		return {}
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var ends := {}
	if not blocks(goal):
		ends[goal] = Vector2i.ZERO
	else:
		for d in dirs:
			var stand: Vector2i = goal - d
			if stand == here or not blocks(stand):
				ends[stand] = d
	if ends.is_empty():
		return {}
	var prev := {here: here}
	var queue: Array[Vector2i] = [here]
	var found := Vector2i(-1, -1)
	if ends.has(here):
		found = here
	var head := 0
	while head < queue.size() and found == Vector2i(-1, -1):
		var cur: Vector2i = queue[head]
		head += 1
		for d in dirs:
			var n: Vector2i = cur + d
			if prev.has(n) or blocks(n):
				continue
			prev[n] = cur
			if ends.has(n):
				found = n
				break
			queue.append(n)
	if found == Vector2i(-1, -1):
		return {}
	var cells: Array[Vector2i] = []
	var k := found
	while k != here:
		cells.push_front(k)
		k = prev[k]
	return {"cells": cells, "face": ends[found]}


# --- задачи ---------------------------------------------------------------------------

func _has_built(s: String) -> bool:
	return built.values().has(s)

func _goal_met(id: String) -> bool:
	match id:
		"sticks":
			return bag.get("stick", 0) >= 5 or gathered.get("branch", 0) >= 3
		"axe":
			return bag.get("axe", 0) > 0
		"chop":
			return gathered.get("tree", 0) > 0
		"campfire", "workbench", "house", "bed", "coop":
			return _has_built(id)
		"seeds":
			return bag.get("carrot_seed", 0) > 0 or bag.get("sunflower_seed", 0) > 0 or gathered.has("wildcarrot") or gathered.has("sunflower")
		"plant", "water", "harvest", "hare", "eggs":
			var stat: String = {"plant": "planted", "water": "watered"}.get(id, id)
			return gathered.get(stat, 0) > 0
	return false

## Отметить выполненные задачи. Выполненная остаётся выполненной, даже если костёр потом
## разобрали.
func _with_goals(message: String, sound: String) -> Dictionary:
	var fresh: Array = []
	for g in Content.GOALS:
		if not goals_done.has(g.id) and _goal_met(g.id):
			fresh.append(g)
	if fresh.is_empty():
		return _out(message, sound)
	for g in fresh:
		goals_done.append(g.id)
	return _out("%s · Задача выполнена: %s" % [message, fresh[-1].title.to_lower()], sound, true)

func current_goal() -> Dictionary:
	for g in Content.GOALS:
		if not goals_done.has(g.id):
			return g
	return {}


# --- сохранение -----------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"seed": seed,
		"time": time,
		"x": pos.x,
		"y": pos.y,
		"fx": facing.x,
		"fy": facing.y,
		"food": food,
		"bag": bag.duplicate(),
		"used": used.duplicate(),
		"built": built.duplicate(),
		"gathered": gathered.duplicate(),
		"goals_done": goals_done.duplicate(),
		"water": water,
		"beds": beds.duplicate(true),
		"coops": coops.duplicate(true),
		"pets": pets,
	}

## Сохранение, прочитанное с диска. Непонятное выбрасывается по кусочку: сломанная запись о
## пне не должна стоить всей деревни. null — сохранения нет или оно совсем не читается.
static func from_dict(d: Variant) -> Village:
	if typeof(d) != TYPE_DICTIONARY or not (d.get("seed") is float or d.get("seed") is int):
		return null
	var v := Village.create(int(d.seed))
	v.time = maxf(0.0, _num(d.get("time"), v.time))
	var p := Vector2(_num(d.get("x"), v.pos.x), _num(d.get("y"), v.pos.y))
	if v.inside(v.tile_of(p)):
		v.pos = p
	var f := Vector2(_num(d.get("fx"), 0.0), _num(d.get("fy"), 1.0))
	if f.length() > 0.0001:
		v.facing = f.normalized()
	v.food = clampf(_num(d.get("food"), v.food), 0.0, 100.0)
	for id in _dict(d.get("bag")):
		var n = d.bag[id]
		if Content.ITEMS.has(id) and (n is int or n is float) and n >= 0:
			v.bag[id] = int(n)
	for k in _dict(d.get("used")):
		var t = d.used[k]
		if t is int or t is float:
			v.used[k] = float(t)
	for k in _dict(d.get("built")):
		if Content.STRUCTURES.has(str(d.built[k])):
			v.built[k] = str(d.built[k])
	for id in _dict(d.get("gathered")):
		var n = d.gathered[id]
		if (Content.NATURE.has(id) or Content.STATS.has(id)) and (n is int or n is float):
			v.gathered[id] = int(n)
	if d.get("goals_done") is Array:
		for g in d.goals_done:
			if g is String:
				v.goals_done.append(g)
	v.water = clampi(int(_num(d.get("water"), 0)), 0, Content.CAN_SIZE)
	v.pets = clampi(int(_num(d.get("pets"), 0)), 0, 20)
	for k in _dict(d.get("beds")):
		var b = d.beds[k]
		if v.built.get(k, "") != "bed" or not b is Dictionary:
			continue
		var crop := str(b.get("crop", ""))
		if crop != "" and not Content.CROPS.has(crop):
			continue
		v.beds[k] = {"crop": crop, "g": _num(b.get("g"), 0.0), "last": _num(b.get("last"), v.time), "wet": _num(b.get("wet"), -1.0)}
	for k in _dict(d.get("coops")):
		var cp = d.coops[k]
		if v.built.get(k, "") != "coop" or not cp is Dictionary:
			continue
		v.coops[k] = {"fed": int(_num(cp.get("fed"), 0)), "eggs": clampi(int(_num(cp.get("eggs"), 0)), 0, Content.COOP_MAX_EGGS)}
	# Встал на занятую клетку (мир поменялся между версиями) — вернуть на поляну.
	if v._collides(v.pos):
		v.pos = Vector2(v.world().start) + Vector2(0.5, 0.5)
	return v

static func _num(x: Variant, fallback: float) -> float:
	return float(x) if (x is int or x is float) and is_finite(float(x)) else fallback

static func _dict(x: Variant) -> Dictionary:
	return x if x is Dictionary else {}
