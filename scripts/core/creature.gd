## Одна клетка в океане — твоя или чужая: тело из частей и то, что с ней сейчас происходит.
##
## Что умеет тело, считается из частей один раз (`rebuild`): скорость, здоровье, укус, шипы,
## панцири. Углы частей — от «носа» клетки: 0 — перёд, +90° — правый бок, 180° — хвост.
class_name Creature
extends RefCounted

static var _next_uid := 1

var uid := 0
var species := ""  # "" — это ты
var is_player := false
## radius — настоящий радиус круга в драке и столкновениях; size_r — «рост» клетки, от
## него сила и здоровье. Они различаются формой: вытянутое тело чуть крупнее круглого.
var radius := 16.0
var size_r := 16.0
var shape: Array = []
var color := Color.WHITE
## Узор и второй цвет особи (у существ — случайные, у тебя — из редактора).
var pattern := "none"
var color2 := Color.WHITE
var parts: Array = []  # [{id, a — радианы, d — глубина: 1 край, 0 середина, lvl}]
## Сияющая особь: редкая, пугливая, крепче, и что-нибудь из неё выпадает всегда.
var golden := false
## Гигант: плывёт один через всю округу. Перерос его — он уже обычный и ходит стайкой.
var giant := false
var announced := false

var pos := Vector2.ZERO
var vel := Vector2.ZERO
var heading := 0.0
var hp := 10.0
var alive := true

# Что умеет — считается в rebuild().
var speed := 70.0
var turn := 3.0
var max_hp := 10.0
var sight := 190.0
var eyes := 0.0
## Сколько видно вокруг (для тумана): без глаз — только рядом.
var vision := 120.0
var mouth := {}  # {id, a, arc, bite, diet, eat_plant, eat_meat}
var spikes: Array = []  # [{a, arc, dmg}]
var shells: Array = []  # [{a, arc, armor}]
var glands: Array = []  # [{a, arc, dps}]
var zap := 0.0
var zap_targets := 0
var regen := 0.0
var dna_rate := 0.0
var dash_power := 260.0
var armor_all := 0.0  # доля урона, которую снимает броня со всех сторон
var heatproof := false
var coldproof := false
var drains: Array = []  # присоски: [{a, arc, dmg}]
var camo := 0.0  # насколько позже замечают хищники, 0–1
var thorns := 0.0  # какая доля удара возвращается обидчику
var dash_k := 1.0  # перезарядка рывка — во столько раз
## Рывок есть только с толчковым пузырём (или реактивным мешком).
var can_dash := false
var ability := ""  # умение по кнопке: ink, shield, pulse, suck
var ability_cd := 10.0
var ability_power := 1.0
## Невидимка: без глаз у игрока его почти не видно. Стая: держится вместе с такими же.
var invisible := false
var school := false
var aggro := false
## Союзник — потомок игрока из свиты.
var ally := false
## Паразит: к кому прицепился и где на нём сидит (угол от носа хозяина).
var host: Creature = null
var host_angle := 0.0
var host_t := 0.0  # сколько уже сосёт: насытившись, отпадает сам
var grabs: Array = []  # щупальца: [{a, arc, dmg}]
var glow := false  # светится — видно сквозь туман
## Покупки из магазина (только у игрока): улучшение → уровень.
var bonus := {}
## Стрелковые части: [{a, arc, kind, dmg, poison, range, reload}] и сколько до выстрела.
var guns: Array = []
var gun_cd := {}
## Светлячок: во сколько раз шире обзор в тумане.
var light := 1.0
## Прилипала: сторона, которой можно прилипнуть, и к кому прилип (только игрок).
var remora: Array = []  # [{a, arc}]
var rider_host: Creature = null
var rider_angle := 0.0
var rider_t := 0.0
## Делитель уже распался (второй раз не делится). Обманка раскрыта — сколько ещё секунд.
var split_done := false
var revealed_t := 0.0
## Подал голос, когда показался (звук каждого вида — один раз), и когда погнался.
var voiced := false
var voice_t := 0.0

# Что с ней сейчас.
var desire := Vector2.ZERO  # куда и насколько сильно хочет плыть, длина 0–1
var bite_cd := 0.0
var dash_cd := 0.0
var dash_t := 0.0
var dash_hit := {}  # uid → true: кого уже ударил этим рывком
var hit_cd := {}  # uid → секунды до следующего укола шипом
var poison_t := 0.0
var poison_dps := 0.0
var poison_from: Creature = null
var zap_cd := 1.0
var calm_t := 99.0  # сколько секунд никто не ранил
var invuln := 0.0
var last_attacker: Creature = null
var player_hit_t := 99.0  # сколько секунд назад её ранил игрок — для «чья победа»
var ai_state := "wander"
var ai_t := 0.0
var ai_goal := Vector2.ZERO
var ai_target: Creature = null
## Сколько ещё может гнаться, пока не выдохнется; отдых — пока не станет снова больше нуля.
var stamina := 1.0
var resting := 0.0
## Держат щупальцем — плывёт медленнее.
var slow_t := 0.0
var shield_t := 0.0  # щит: почти не ранят
var hidden_t := 0.0  # в чернилах: хищники не видят
var ability_t := 0.0  # до готовности умения
## Сколько секунд живёт — для появления из мути.
var age := 0.0
# Только для рисования.
var flash := 0.0
var bite_anim := 0.0
var eat_anim := 0.0
var grow_anim := 0.0
## Напуган волной роста: сколько ещё секунд плывёт прочь от тебя.
var scared_t := 0.0
## Гигант погонялся, выдохся — сколько ещё секунд ему не до тебя.
var bored_t := 0.0
var phase := 0.0
var wobble := 0.0


func _init() -> void:
	uid = _next_uid
	_next_uid += 1
	wobble = float(uid % 97) * 0.37


## size — «рост» для великанов, которые всегда во много раз больше тебя.
## lvl_bonus — на сколько уровней сильнее части (на больших размерах существа крепче).
static func of_species(id: String, size := 0.0, lvl_bonus := 0) -> Creature:
	var def: Dictionary = Content.SPECIES[id]
	var c := Creature.new()
	c.species = id
	c.invisible = def.get("invisible", false)
	c.school = def.has("school")
	c.aggro = def.get("aggro", false)
	c.size_r = size if size > 0.0 else def.radius
	c.shape = Content.shape_preset(def.get("shape", "round"))
	c.radius = c.size_r * Content.shape_scale(c.shape)
	c.color = Color(def.color)
	for p in def.parts:
		c.parts.append({"id": p[0], "a": deg_to_rad(p[1]), "d": 1.0, "lvl": mini(int(p[2]) + lvl_bonus, Content.PART_MAX_LEVEL)})
	c.rebuild()
	c.hp = c.max_hp
	return c

func make_golden() -> void:
	golden = true
	color = color.lerp(Color("#ffd86a"), 0.75)
	rebuild()
	hp = max_hp

static func of_player(evo: Evolution) -> Creature:
	var c := Creature.new()
	c.is_player = true
	c.sync_player(evo)
	c.hp = c.max_hp
	return c

## Тело игрока поменялось (редактор, рост) — перестроить, сохранив долю здоровья.
func sync_player(evo: Evolution) -> void:
	var share := hp / max_hp if max_hp > 0.0 else 1.0
	size_r = evo.radius()
	shape = evo.shape.duplicate()
	radius = size_r * Content.shape_scale(shape)
	color = Color(Content.COLORS[evo.color])
	parts = evo.body_parts()
	bonus = evo.upgrades.duplicate()
	rebuild()
	hp = clampf(max_hp * share, 1.0, max_hp)

func behavior() -> String:
	if is_player:
		return "player"
	if species == "mate":
		return "mate"
	if ally:
		return "ally"
	if golden:
		return "skittish"
	var def: Dictionary = Content.SPECIES[species]
	# Бывший гигант (ты его перерос) — мирный, плавает стайкой; тронешь — даст сдачи.
	if def.behavior == "roamer" and not giant:
		return "drifter"
	return def.behavior

func size_k() -> float:
	return size_r / 16.0

## Посчитать, что умеет тело.
## Одинаковое оружие не складывается в разы: первая стрелковая часть (электроклетка) —
## в полную силу, каждая следующая — на эту долю.
const STACK := 0.3
## Оружие потомков в стае — слабее твоего.
const ALLY_POWER := 0.5

func rebuild() -> void:
	var k := size_k()
	var zaps: Array = []
	var dmg_k := pow(k, 0.7)
	var spd := 70.0
	turn = 3.0
	var hp_bonus := 0.0
	mouth = {}
	spikes = []
	shells = []
	glands = []
	zap = 0.0
	zap_targets = 0
	armor_all = 0.0
	grabs = []
	guns = []
	remora = []
	light = 1.0
	glow = false
	heatproof = false
	coldproof = false
	drains = []
	camo = 0.0
	thorns = 0.0
	dash_k = 1.0
	can_dash = false
	ability = ""
	regen = 0.0
	dna_rate = 0.0
	eyes = 0.0
	for p in parts:
		var def: Dictionary = Content.PARTS[p.id]
		var pw := Content.power(p.lvl)
		spd += float(def.get("speed", 0.0)) * (pw if def.get("speed", 0.0) > 0.0 else 1.0)
		turn += float(def.get("turn", 0.0)) * pw
		hp_bonus += float(def.get("hp", 0.0)) * pw
		var arc := deg_to_rad(float(def.get("arc", 0)))
		match def.kind:
			"mouth":
				# Сытнее с уровнем рта — вдвое слабее, чем растёт сила: иначе прокачанный
				# фильтр съедал бы весь этап за полчаса.
				var feed := 1.0 + (pw - 1.0) * 0.5
				mouth = {"id": p.id, "a": p.a, "arc": arc, "bite": float(def.get("bite", 0.0)) * pw * dmg_k,
					"diet": def.diet, "eat_plant": float(def.get("eat_plant", 0.0)) * feed, "eat_meat": float(def.get("eat_meat", 0.0)) * feed}
		if def.has("spike"):
			spikes.append({"a": p.a, "arc": arc, "dmg": def.spike * pw * dmg_k, "rock": float(def.get("rock", 1.0))})
		if def.has("armor_all"):
			armor_all = maxf(armor_all, minf(0.6, def.armor_all * pw))
		if def.has("grab"):
			grabs.append({"a": p.a, "arc": arc, "dmg": def.grab * pw * dmg_k})
		if def.get("glow", false):
			glow = true
		if def.has("light"):
			light = maxf(light, float(def.light))
		if def.has("gun"):
			guns.append({"a": p.a, "arc": arc, "kind": def.gun, "dmg": float(def.dmg) * pw * dmg_k, "poison": float(def.get("poison", 0.0)) * pw * dmg_k,
				"range": float(def.range) * pow(k, 0.5), "reload": float(def.reload)})
		if def.get("remora", false):
			remora.append({"a": p.a, "arc": arc})
		if def.get("heatproof", false):
			heatproof = true
		if def.get("coldproof", false):
			coldproof = true
		if def.has("drain"):
			drains.append({"a": p.a, "arc": arc, "dmg": def.drain * pw * dmg_k})
		camo = maxf(camo, float(def.get("camo", 0.0)) * minf(pw, 1.6))
		thorns = maxf(thorns, float(def.get("thorns", 0.0)) * pw)
		if def.get("dash", false):
			can_dash = true
		if def.has("dash_k"):
			dash_k = minf(dash_k, float(def.dash_k) / pw)
		if def.has("ability") and ability == "":
			ability = def.ability
			ability_cd = float(def.cooldown) / (1.0 + 0.1 * (pw - 1.0) / Content.PART_LEVEL_BONUS)
			ability_power = pw * dmg_k
		if def.has("armor"):
			shells.append({"a": p.a, "arc": arc, "armor": minf(0.8, def.armor * pw)})
		if def.has("poison"):
			glands.append({"a": p.a, "arc": arc, "dps": def.poison * pw * dmg_k})
		if def.has("zap"):
			zaps.append(def.zap * pw * dmg_k)
			zap_targets += 1
		regen += float(def.get("regen", 0.0)) * pw
		dna_rate += float(def.get("dna_rate", 0.0)) * pw
		eyes += float(def.get("eyes", 0.0)) * pw
	zaps.sort()
	zaps.reverse()
	for i in zaps.size():
		zap += float(zaps[i]) * (1.0 if i == 0 else STACK)
	if guns.size() > 1:
		guns.sort_custom(func(a, b): return a.dmg + a.poison > b.dmg + b.poison)
		for i in range(1, guns.size()):
			guns[i].dmg *= STACK
			guns[i].poison *= STACK
	if ally:
		zap *= ALLY_POWER
		for g in guns:
			g.dmg *= ALLY_POWER
			g.poison *= ALLY_POWER
	speed = maxf(30.0, spd) * pow(k, 0.3)
	max_hp = 12.0 * pow(k, 1.5) + hp_bonus * k
	sight = 190.0 * sqrt(k) * (1.0 + 0.3 * minf(eyes, 4.0))
	if not is_player and behavior() == "skittish":
		sight *= 1.35
	dash_power = 260.0 * pow(k, 0.3) / sqrt(dash_k)
	# Без глаз — только рядом. С глазами обзор считает Pond.vision(): он зависит от экрана.
	vision = 95.0 + size_r * 1.6
	if golden:
		speed *= 1.15
		max_hp *= 1.5
	zap_targets = mini(zap_targets + 1, 3) if zap_targets > 0 else 0
	# Твоя форма — не только для вида: больше тело — крепче, но тяжелее; вытянутое — быстрее.
	if is_player or ally:
		var st := Content.shape_stats(shape)
		max_hp *= float(st.hp)
		speed *= float(st.speed)
	_apply_bonus()

## Покупки из магазина.
func _apply_bonus() -> void:
	if bonus.is_empty():
		return
	var lvl := func(id: String) -> int: return int(bonus.get(id, 0))
	max_hp *= 1.0 + 0.15 * lvl.call("hp")
	regen += 0.35 * lvl.call("regen") * size_k()
	camo = maxf(camo, [0.0, 0.25, 0.4, 0.55][mini(lvl.call("camo"), 3)])
	dash_k *= [1.0, 0.85, 0.72, 0.6][mini(lvl.call("dash"), 3)]
	dash_power = 260.0 * pow(size_k(), 0.3) / sqrt(dash_k)

func eats(kind: String) -> bool:
	var d: String = mouth.get("diet", "")
	return d == "both" or (kind == "plant" and d == "plant") or (kind == "meat" and d == "meat")

## Может ли вообще ранить (для «опасен ли он»).
func armed() -> bool:
	return float(mouth.get("bite", 0.0)) > 0.0 or not spikes.is_empty() or not glands.is_empty() or zap > 0.0 or not grabs.is_empty()

func heading_vec() -> Vector2:
	return Vector2.from_angle(heading)

## Угол точки относительно носа клетки, радианы от −π до π.
func rel_angle(to: Vector2) -> float:
	return wrapf((to - pos).angle() - heading, -PI, PI)

## Смотрит ли часть с углом a (и охватом arc) на точку.
func faces(a: float, arc: float, to: Vector2) -> bool:
	return absf(wrapf(rel_angle(to) - a, -PI, PI)) <= arc
