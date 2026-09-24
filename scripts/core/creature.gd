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
var radius := 16.0
var color := Color.WHITE
var parts: Array = []  # [{id, a — радианы, lvl}]

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
var mouth := {}  # {id, a, arc, bite, diet, eat_plant, eat_meat}
var spikes: Array = []  # [{a, arc, dmg}]
var shells: Array = []  # [{a, arc, armor}]
var glands: Array = []  # [{a, arc, dps}]
var zap := 0.0
var zap_targets := 0
var regen := 0.0
var dna_rate := 0.0
var dash_power := 260.0

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
# Только для рисования.
var flash := 0.0
var bite_anim := 0.0
var phase := 0.0
var wobble := 0.0


func _init() -> void:
	uid = _next_uid
	_next_uid += 1
	wobble = float(uid % 97) * 0.37


static func of_species(id: String) -> Creature:
	var def: Dictionary = Content.SPECIES[id]
	var c := Creature.new()
	c.species = id
	c.radius = def.radius
	c.color = Color(def.color)
	for p in def.parts:
		c.parts.append({"id": p[0], "a": deg_to_rad(p[1]), "lvl": p[2]})
	c.rebuild()
	c.hp = c.max_hp
	return c

static func of_player(evo: Evolution) -> Creature:
	var c := Creature.new()
	c.is_player = true
	c.sync_player(evo)
	c.hp = c.max_hp
	return c

## Тело игрока поменялось (редактор, рост) — перестроить, сохранив долю здоровья.
func sync_player(evo: Evolution) -> void:
	var share := hp / max_hp if max_hp > 0.0 else 1.0
	radius = evo.radius()
	color = Color(Content.COLORS[evo.color])
	parts = evo.body_parts()
	rebuild()
	hp = clampf(max_hp * share, 1.0, max_hp)

func behavior() -> String:
	return "player" if is_player else Content.SPECIES[species].behavior

func size_k() -> float:
	return radius / 16.0

## Посчитать, что умеет тело.
func rebuild() -> void:
	var k := size_k()
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
			spikes.append({"a": p.a, "arc": arc, "dmg": def.spike * pw * dmg_k})
		if def.has("armor"):
			shells.append({"a": p.a, "arc": arc, "armor": minf(0.8, def.armor * pw)})
		if def.has("poison"):
			glands.append({"a": p.a, "arc": arc, "dps": def.poison * pw * dmg_k})
		if def.has("zap"):
			zap += def.zap * pw * dmg_k
			zap_targets += 1
		regen += float(def.get("regen", 0.0)) * pw
		dna_rate += float(def.get("dna_rate", 0.0)) * pw
		eyes += float(def.get("eyes", 0.0)) * pw
	speed = maxf(30.0, spd) * pow(k, 0.3)
	max_hp = 12.0 * pow(k, 1.5) + hp_bonus * k
	sight = 190.0 * sqrt(k) * (1.0 + 0.3 * minf(eyes, 4.0))
	if not is_player and behavior() == "skittish":
		sight *= 1.35
	dash_power = 260.0 * pow(k, 0.3)
	zap_targets = mini(zap_targets + 1, 3) if zap_targets > 0 else 0

func eats(kind: String) -> bool:
	var d: String = mouth.get("diet", "")
	return d == "both" or (kind == "plant" and d == "plant") or (kind == "meat" and d == "meat")

## Может ли вообще ранить (для «опасен ли он»).
func armed() -> bool:
	return float(mouth.get("bite", 0.0)) > 0.0 or not spikes.is_empty() or not glands.is_empty() or zap > 0.0

func heading_vec() -> Vector2:
	return Vector2.from_angle(heading)

## Угол точки относительно носа клетки, радианы от −π до π.
func rel_angle(to: Vector2) -> float:
	return wrapf((to - pos).angle() - heading, -PI, PI)

## Смотрит ли часть с углом a (и охватом arc) на точку.
func faces(a: float, arc: float, to: Vector2) -> bool:
	return absf(wrapf(rel_angle(to) - a, -PI, PI)) <= arc
