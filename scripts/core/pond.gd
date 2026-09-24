## Первичный океан: ты, другие клетки, еда и выпавшие части — и всё, что между ними
## происходит за один шаг времени.
##
## Океан бесконечный и не сохраняется: водоросли и клетки появляются вокруг тебя за краем
## экрана и исчезают, когда уплываешь далеко. Сохраняется только твой вид (Evolution).
##
## Каждый шаг складывает в `events` то, что стоит показать и озвучить: съел, укусили,
## победил, выпала часть, вырос. Экран сам ничего не решает — только читает события.
class_name Pond
extends RefCounted

const FOOD_CELL := 128.0
const MEAT_LIFE := 45.0
const CAPSULE_LIFE := 75.0
const BITE_CD := 0.55
const SPIKE_CD := 0.5
const DASH_TIME := 0.35
const DASH_CD := 1.6
const RAM_DAMAGE := 4.0
const POISON_TIME := 3.0
const ZAP_CD := 2.2
## Сколько секунд после твоего удара победа засчитывается тебе (яд тоже считается).
const KILL_CREDIT := 3.0
const REGEN_DELAY := 4.0
## Хищник гонится за теми, кто не больше него во столько раз.
const PREY_RATIO := 1.3
const MEAT_DNA := 1.25
## Хищник гонится не дольше стольких секунд, потом отдыхает — от него можно оторваться.
const CHASE_TIME := 5.0
const REST_TIME := 4.0

var evo: Evolution
var player: Creature
var mobs: Array[Creature] = []
var food: Array = []  # [{pos, kind: plant/meat, value, r, t, v, eaten}]
var capsules: Array = []  # [{pos, part, t}]
var rocks: Array = []  # [{pos, r, hp, max_hp, kind, v, uid, flash, vel, drift}]
## Круги водорослей: сам круг не съесть, еда растёт по его краю и отрастает. Плывут.
var colonies: Array = []  # [{pos, r, vel, drift, spin, v, uid, regrow}]
var _colony_uid := 1
const COLONY_BITS := 10
const COLONY_REGROW := 4.5
## Пара: зовёшь кнопкой ♥, доплываешь — и можно менять тело. null — не звал.
var mate: Creature = null
var _rock_uid := -1
var events: Array = []
var rng := RandomNumberGenerator.new()
## Полдиагонали экрана в точках мира: за этим краем появляются новые клетки.
var view_radius := 600.0
## Можно выключить в проверках — тогда океан не наполняется сам.
var spawning := true
## Воды и течения; в проверках правил — выключены, чтобы им не мешать.
var nature := true
var time := 0.0
var _manage_t := 0.0
var _safe_t := 25.0
var _grid := {}
var _meadow := FastNoiseLite.new()
var _temp := FastNoiseLite.new()
var _depth := FastNoiseLite.new()
var _flow := FastNoiseLite.new()
## Режим: normal — обычная игра, arena — волны существ, sandbox — песочница.
var mode := "normal"
## Свита: потомки, что плавают рядом и помогают.
var allies: Array[Creature] = []
var _ally_t := 0.0
## Логова: клетка сетки → хозяин, если он сейчас здесь; побеждённые в этот раз.
## Хозяин логова, который сейчас бьётся с тобой, — для полоски здоровья наверху.
var boss_active: Creature = null
var _director_t := 2.5
var _kills_recent: Array = []
## Сколько секунд место съеденного пустует.
const KILL_QUIET := 20.0
var _food_drift := 0
## Арена: середина, радиус, номер волны, сколько побед, пауза перед следующей волной.
var arena_center := Vector2.ZERO
var arena_radius := 650.0
var wave := 0
var wave_kills := 0
var _wave_t := 3.0
var arena_over := false
## Сверхсложность: вид вымер — мир замирает.
var extinct := false

## Событие в океане (Content.EVENTS): "" — обычная вода. event_k — насколько оно в силе
## (0–1, нарастает и спадает плавно); event_look — что показывать, пока спадает.
var event := ""
var event_t := 0.0
var event_k := 0.0
var event_look := ""
var storm_dir := Vector2.RIGHT
var _event_cd := 0.0
var _event_last := ""
var _spawn_wave_t := 0.0
var _event_rng := RandomNumberGenerator.new()


func _init(e: Evolution, seed := 0) -> void:
	evo = e
	rng.seed = seed if seed != 0 else randi()
	_meadow.seed = rng.randi()
	_meadow.frequency = 0.0022
	# Воды и течения зависят от места, а не от случая: одно место — одна вода.
	_temp.seed = rng.randi()
	_temp.frequency = 0.00035
	_depth.seed = rng.randi()
	_depth.frequency = 0.0004
	_flow.seed = rng.randi()
	_flow.frequency = 0.0009
	player = Creature.of_player(evo)
	if evo.sandbox:
		mode = "sandbox"
	# У событий свой счёт случайностей — чтобы не сдвигать всё остальное в мире.
	_event_rng.seed = rng.seed + 97
	# Первое событие — через несколько минут: сначала надо освоиться.
	_event_cd = _event_rng.randf_range(200.0, 320.0)

## Наполнить океан вокруг — при старте и после рождения заново.
func fill() -> void:
	var outer := _plant_outer()
	for i in _plant_target():
		_spawn_plant(60.0, outer, true)
	for i in _mob_target() / 2:
		_spawn_mob(true)
	for i in _rock_target():
		_spawn_rock(view_radius * 0.6, view_radius + 700.0)
	for i in _colony_target():
		# Первый круг — недалеко, чтобы было видно, что это такое.
		_spawn_colony(vision() * 1.3 if i == 0 else view_radius * 0.6, view_radius * (0.8 if i == 0 else 1.0) + (0.0 if i == 0 else 700.0))
	for i in evo.brood:
		_spawn_ally()


# --- шаг ------------------------------------------------------------------------------

## Один шаг. input — куда плыть (длина 0–1), dash — нажат «Рывок».
func step(dt: float, input: Vector2, dash := false) -> void:
	events.clear()
	# Бой на арене окончен или вид вымер — дальше ничего не происходит.
	if arena_over or extinct:
		return
	time += dt
	_safe_t -= dt
	player.desire = input.limit_length(1.0)
	if dash:
		if player.rider_host != null:
			_unride()
		elif do_dash(player):
			_shake_off()
	for m in mobs:
		_think(m, dt)
	for a in allies:
		_ally_think(a, dt)
	var all := everyone()
	for c in all:
		_move(c, dt)
		_timers(c, dt)
	_parasites(dt)
	_collide(all)
	_rock_contacts(all)
	_colony_contacts(all)
	_riding(dt)
	_guns()
	_shots(dt)
	_zaps(all)
	_mate_step(dt)
	_floating(dt)
	_rebuild_grid()
	_eat(all)
	_pickup()
	_age(dt)
	_do_splits()
	_deaths()
	if player.dna_rate > 0.0 and mode != "arena":
		_gain(player.dna_rate * dt)
	if mode == "arena":
		_arena(dt)
	if spawning:
		_manage_t -= dt
		if _manage_t <= 0.0:
			_manage_t = 0.5
			_manage()
		_directing(dt)
		_roamers(dt)
		_world_events(dt)
		_ally_t -= dt
		if allies.size() < evo.brood and _ally_t <= 0.0:
			_ally_t = 45.0
			_spawn_ally()
	for g in evo.check_goals():
		events.append({"t": "goal", "goal": g})

func everyone() -> Array[Creature]:
	var all: Array[Creature] = [player]
	all.append_array(allies)
	all.append_array(mobs.filter(func(m): return m.host == null))
	return all

## Свои: ты и твоя свита.
static func friendly(a: Creature, b: Creature) -> bool:
	return (a.is_player or a.ally) and (b.is_player or b.ally)


# --- движение -------------------------------------------------------------------------

func _move(c: Creature, dt: float) -> void:
	var spd := c.speed
	if c.ai_state == "flee" and not c.is_player and c.species != "mate" and c.behavior() == "skittish":
		spd *= 1.25
	if c.ai_state == "chase":
		spd *= float(evo.diff().hunt)
	if c.slow_t > 0.0:
		spd *= 0.6
	var want_dir := c.desire if c.is_player else avoid(c, c.desire)
	var goal := want_dir * spd
	# Во время рывка вода тормозит слабее — разгон доносит до цели.
	var k := 0.8 if c.dash_t > 0.0 else 4.0
	c.vel = c.vel.lerp(goal, 1.0 - exp(-k * dt))
	c.pos += (c.vel + current_at(c.pos)) * dt
	var want := c.desire if c.desire.length() > 0.05 else (c.vel if c.vel.length() > 8.0 else Vector2.ZERO)
	if want != Vector2.ZERO:
		var diff := wrapf(want.angle() - c.heading, -PI, PI)
		var most := c.turn * 1.5 * dt
		c.heading = wrapf(c.heading + clampf(diff, -most, most), -PI, PI)
	c.phase += dt * (1.0 + c.vel.length() / 40.0)

func do_dash(c: Creature) -> bool:
	if c.dash_cd > 0.0 or not c.alive or (c.is_player and not c.can_dash):
		return false
	var dir := c.desire.normalized() if c.desire.length() > 0.1 else c.heading_vec()
	c.vel += dir * c.dash_power
	c.heading = dir.angle()
	c.dash_t = DASH_TIME
	c.dash_cd = DASH_CD * c.dash_k
	c.dash_hit.clear()
	if c.is_player:
		evo.count("dashes")
		events.append({"t": "dash", "pos": c.pos})
	return true

func _timers(c: Creature, dt: float) -> void:
	c.bite_cd -= dt
	c.dash_cd -= dt
	c.dash_t -= dt
	c.zap_cd -= dt
	c.invuln -= dt
	c.calm_t += dt
	c.player_hit_t += dt
	c.flash = maxf(0.0, c.flash - dt * 4.0)
	c.bite_anim = maxf(0.0, c.bite_anim - dt * 3.0)
	c.eat_anim = maxf(0.0, c.eat_anim - dt * 4.0)
	c.grow_anim = maxf(0.0, c.grow_anim - dt * 1.2)
	c.slow_t -= dt
	c.shield_t -= dt
	c.hidden_t -= dt
	c.ability_t -= dt
	c.revealed_t -= dt
	c.voice_t -= dt
	for k in c.gun_cd.keys():
		c.gun_cd[k] -= dt
	c.age += dt
	for k in c.hit_cd.keys():
		c.hit_cd[k] -= dt
		if c.hit_cd[k] <= 0.0:
			c.hit_cd.erase(k)
	if c.poison_t > 0.0:
		c.poison_t -= dt
		_hurt(c, c.poison_dps * dt, c.poison_from, "poison", true)
	# Хозяин логова сам по себе не лечится — только дома, когда тебя давно нет.
	if is_giant(c):
		return
	var heal := c.regen
	if c.calm_t > REGEN_DELAY:
		heal += 0.3 * c.size_k()
	c.hp = minf(c.max_hp, c.hp + heal * dt)


# --- столкновения и драка -------------------------------------------------------------

func _collide(all: Array[Creature]) -> void:
	for i in all.size():
		var a := all[i]
		if not a.alive:
			continue
		for j in range(i + 1, all.size()):
			var b := all[j]
			if not b.alive:
				continue
			var d := b.pos - a.pos
			var min_d := a.radius + b.radius
			var dist2 := d.length_squared()
			if dist2 >= min_d * min_d:
				continue
			var dist := sqrt(dist2)
			var n := d / dist if dist > 0.001 else Vector2.RIGHT
			# Раздвинуть: лёгкого сдвигает сильнее.
			var ma := a.radius * a.radius
			var mb := b.radius * b.radius
			var overlap := min_d - dist
			a.pos -= n * overlap * mb / (ma + mb)
			b.pos += n * overlap * ma / (ma + mb)
			# Свои своих не трогают.
			if a.species != "" and a.species == b.species:
				continue
			if friendly(a, b):
				continue
			_contact(a, b, n)
			_contact(b, a, -n)

## x касается y (n — направление от x к y): кусает, колет, травит, таранит.
func _contact(x: Creature, y: Creature, n: Vector2) -> void:
	if not x.alive or not y.alive:
		return
	# Кто везёт прилипалу, её не кусает.
	if y.is_player and y.rider_host == x:
		return
	var boost := 1.5 if x.dash_t > 0.0 else 1.0
	var bite: float = x.mouth.get("bite", 0.0)
	if bite > 0.0 and x.bite_cd <= 0.0 and x.faces(x.mouth.a, x.mouth.arc, y.pos) and _wants_bite(x, y):
		x.bite_cd = BITE_CD
		x.bite_anim = 1.0
		_hurt(y, bite * boost, x, "bite")
	for s in x.spikes:
		if x.hit_cd.get(y.uid, 0.0) <= 0.0 and x.faces(s.a, s.arc, y.pos):
			x.hit_cd[y.uid] = SPIKE_CD
			_hurt(y, s.dmg * boost, x, "spike")
			break
	for g in x.drains:
		if x.faces(g.a, g.arc, y.pos) and x.hit_cd.get(-y.uid - 500000, 0.0) <= 0.0:
			# Присоска: тянет здоровье и лечит хозяина.
			x.hit_cd[-y.uid - 500000] = 0.6
			var before := y.hp
			_hurt(y, g.dmg, x, "drain")
			x.hp = minf(x.max_hp, x.hp + maxf(0.0, before - y.hp))
			break
	for g in x.grabs:
		if x.faces(g.a, g.arc, y.pos) and x.hit_cd.get(-y.uid, 0.0) <= 0.0:
			# Щупальце хватает: немного ранит и держит — жертва плывёт медленнее.
			x.hit_cd[-y.uid] = 0.8
			y.slow_t = 1.5
			_hurt(y, g.dmg, x, "grab")
			break
	for g in x.glands:
		if x.faces(g.a, g.arc, y.pos) and y.invuln <= 0.0:
			if y.poison_t <= 0.0 and (y.is_player or x.is_player):
				events.append({"t": "poison", "pos": y.pos, "to_player": y.is_player})
			y.poison_dps = maxf(y.poison_dps if y.poison_t > 0.0 else 0.0, g.dps)
			y.poison_t = POISON_TIME
			y.poison_from = x
	if x.is_player and x.dash_t > 0.0 and not x.dash_hit.has(y.uid):
		x.dash_hit[y.uid] = true
		var dmg := RAM_DAMAGE * pow(x.size_k(), 0.7) * pow(x.radius / y.radius, 0.3)
		_hurt(y, dmg, x, "ram")
		y.vel += n * 220.0 * clampf(x.radius / y.radius, 0.3, 2.0)

func _wants_bite(x: Creature, y: Creature) -> bool:
	if x.is_player or x.ally:
		return true
	var def: Dictionary = Content.SPECIES[x.species]
	if def.behavior == "roamer" and not x.giant:
		return _hunts(x) or y == x.last_attacker
	return def.behavior == "hunter" or def.get("hunts", false) or y == x.last_attacker

## Ранить y. Панцирь со стороны удара снимает часть урона.
func _hurt(y: Creature, dmg: float, from: Creature, kind: String, silent := false) -> void:
	if not y.alive or y.invuln > 0.0 or dmg <= 0.0:
		return
	var mult := 1.0
	# Яд уже внутри — панцирь от него не спасает.
	if from != null and from != y and kind != "poison":
		for s in y.shells:
			if y.faces(s.a, s.arc, from.pos):
				mult = minf(mult, 1.0 - s.armor)
	if kind != "poison":
		mult *= 1.0 - y.armor_all
	if y.shield_t > 0.0:
		mult *= 0.2
	dmg *= mult
	if y.is_player:
		dmg *= float(evo.diff().hurt)
	if from != null and is_giant(from):
		dmg *= GIANT_DAMAGE
	elif from != null and not from.is_player and Content.SPECIES.get(from.species, {}).get("behavior", "") == "roamer":
		dmg *= FORMER_GIANT_DAMAGE
	y.hp -= dmg
	if not y.is_player and not y.ally and not y.split_done and y.species != "mate" and Content.SPECIES[y.species].get("splits", false) \
			and y.hp > 0.0 and y.hp < y.max_hp * 0.5 and y.size_r >= 8.0 and not _to_split.has(y):
		y.split_done = true
		_to_split.append(y)
	# Шипастая броня: обидчику возвращается часть удара (у хозяина логова — вдвое меньше).
	if y.thorns > 0.0 and from != null and from != y and kind in ["bite", "spike", "grab", "ram", "drain"]:
		from.hp -= dmg * y.thorns * (0.5 if is_giant(y) else 1.0)
		from.flash = 1.0
		if from.hp <= 0.0:
			from.hp = 0.0
			from.alive = false
		if y.is_player:
			from.player_hit_t = 0.0
	y.calm_t = 0.0
	if from != null:
		y.last_attacker = from
		if from.is_player or from.ally:
			y.player_hit_t = 0.0
		if from.is_player:
			player.ai_target = y
	if not silent:
		y.flash = 1.0
		var at := y.pos if from == null else y.pos + (from.pos - y.pos).normalized() * y.radius
		events.append({"t": "hit", "kind": kind, "pos": at, "dmg": dmg, "blocked": mult < 1.0,
			"to_player": y.is_player, "from_player": from != null and from.is_player,
			"giant": from != null and from.giant, "share": dmg / maxf(y.max_hp, 0.1)})
	if y.hp <= 0.0:
		y.hp = 0.0
		y.alive = false

func _zaps(all: Array[Creature]) -> void:
	for c in all:
		if not c.alive or c.zap <= 0.0 or c.zap_cd > 0.0:
			continue
		var near: Array = []
		for o in all:
			if o == c or not o.alive or (c.species != "" and o.species == c.species) or friendly(c, o):
				continue
			var d := c.pos.distance_to(o.pos) - o.radius
			if d < c.radius * 3.0:
				near.append([d, o])
		if near.is_empty():
			continue
		near.sort_custom(func(p, q): return p[0] < q[0])
		c.zap_cd = ZAP_CD
		for i in mini(c.zap_targets, near.size()):
			var o: Creature = near[i][1]
			events.append({"t": "zap", "from": c.pos, "to": o.pos, "by_player": c.is_player, "to_player": o.is_player})
			_hurt(o, c.zap, c, "zap", true)
			o.flash = 1.0


# --- еда и находки --------------------------------------------------------------------

func _rebuild_grid() -> void:
	_grid.clear()
	for i in food.size():
		var k := Vector2i(floori(food[i].pos.x / FOOD_CELL), floori(food[i].pos.y / FOOD_CELL))
		if not _grid.has(k):
			_grid[k] = []
		_grid[k].append(i)

func _eat(all: Array[Creature]) -> void:
	var any := false
	for c in all:
		if not c.alive or c.mouth.is_empty():
			continue
		var cell := Vector2i(floori(c.pos.x / FOOD_CELL), floori(c.pos.y / FOOD_CELL))
		var reach := ceili((c.radius + 12.0) / FOOD_CELL)
		for gy in range(cell.y - reach, cell.y + reach + 1):
			for gx in range(cell.x - reach, cell.x + reach + 1):
				for i in _grid.get(Vector2i(gx, gy), []):
					var f: Dictionary = food[i]
					if f.eaten or not c.eats(f.kind):
						continue
					if c.pos.distance_to(f.pos) > c.radius + f.r:
						continue
					if not c.faces(c.mouth.a, c.mouth.arc + 0.3, f.pos):
						continue
					f.eaten = true
					any = true
					_fed(c, f)
	if any:
		food = food.filter(func(f): return not f.eaten)

func _fed(c: Creature, f: Dictionary) -> void:
	if f.kind == "plant":
		c.hp = minf(c.max_hp, c.hp + f.value)
	else:
		c.hp = minf(c.max_hp, c.hp + 3.0 * f.value)
	c.eat_anim = 1.0
	if not c.is_player:
		return
	var gain: float
	if f.kind == "plant":
		gain = f.value * c.mouth.eat_plant
		evo.count("plants")
	else:
		gain = MEAT_DNA * f.value * c.mouth.eat_meat
		evo.count("meat")
	# Большой желудок из магазина: +10% за уровень.
	gain *= 1.0 + 0.1 * evo.upgrade_level("stomach")
	events.append({"t": "eat", "kind": f.kind, "pos": f.pos, "dna": gain})
	_gain(gain)

func _pickup() -> void:
	if not player.alive:
		return
	var keep: Array = []
	for cap in capsules:
		if player.pos.distance_to(cap.pos) < player.radius + 14.0:
			var got := evo.collect(cap.part)
			var ev := {"t": "pickup", "part": cap.part, "pos": cap.pos}
			ev.merge(got)
			events.append(ev)
			player.sync_player(evo)
		else:
			keep.append(cap)
	capsules = keep

func _age(dt: float) -> void:
	# Течения несут и еду — раз в три шага, этого хватает.
	_food_drift = (_food_drift + 1) % 3
	var drift := _food_drift == 0
	for f in food:
		f.t += dt
		if drift and not f.has("col"):
			f.pos += current_at(f.pos) * dt * 3.0
		if f.get("suck", 0.0) > 0.0:
			f.suck -= dt
			f.pos = f.pos.move_toward(player.pos, 320.0 * dt)
	if food.any(func(f): return f.kind == "meat" and f.t > MEAT_LIFE):
		food = food.filter(func(f): return f.kind != "meat" or f.t <= MEAT_LIFE)
	for cap in capsules:
		cap.t += dt
	if capsules.any(func(c): return c.t > CAPSULE_LIFE):
		capsules = capsules.filter(func(c): return c.t <= CAPSULE_LIFE)

func _gain(amount: float) -> void:
	# Арена — просто бой на счёт: расти и собирать части там нельзя.
	if mode == "arena":
		return
	if evo.add_dna(amount):
		player.sync_player(evo)
		player.hp = player.max_hp
		player.grow_anim = 1.0
		events.append({"t": "levelup", "level": evo.level()})


# --- победы и гибель ------------------------------------------------------------------

func _deaths() -> void:
	var dead := mobs.filter(func(m): return not m.alive)
	for m: Creature in dead:
		var def: Dictionary = Content.SPECIES[m.species]
		# Мясо — по размеру того, кто погиб: с мелочи — крошка, с крупного — большие куски.
		var total := maxf(1.0, m.radius / 8.0)
		var pieces := clampi(ceili(sqrt(total)), 1, 5)
		var piece_r := clampf(m.radius * 0.55 / sqrt(float(pieces)), 4.0, 70.0)
		for i in pieces:
			var off := Vector2.from_angle(rng.randf() * TAU) * rng.randf() * m.radius * 0.6
			food.append({"pos": m.pos + off, "kind": "meat", "value": total / pieces, "r": piece_r, "t": 0.0, "v": rng.randi() % 256, "eaten": false})
		var by_player := m.player_hit_t < KILL_CREDIT
		events.append({"t": "kill", "pos": m.pos, "species": m.species, "by_player": by_player, "radius": m.radius, "color": m.color, "golden": m.golden, "who": m})
		if m.giant:
			if boss_active == m:
				boss_active = null
			if by_player:
				evo.lairs_beaten[m.species] = true
				events.append({"t": "giant_beaten", "species": m.species, "pos": m.pos})
		if mode == "arena" and by_player:
			wave_kills += 1
		if by_player:
			_kills_recent.append(time)
			evo.count("kills")
			evo.kills_by[m.species] = evo.kills_by.get(m.species, 0) + 1
			if m.golden:
				evo.count("golden")
			var bonus: float = (0.6 + 0.9 * def.tier) * (3.0 if m.golden else 1.0)
			events[-1].dna = bonus
			_gain(bonus)
			var dropped: Array = []
			for d in (def.drops if mode != "arena" else []):
				if rng.randf() < d[1] * float(evo.diff().drop):
					dropped.append(d[0])
			# С гиганта его главная часть выпадает всегда — победа трудная.
			if m.giant and not def.drops.is_empty() and mode != "arena" and not dropped.has(def.drops[0][0]):
				dropped.append(def.drops[0][0])
			# Из сияющей что-нибудь выпадает всегда.
			if m.golden and dropped.is_empty() and not def.drops.is_empty() and mode != "arena":
				dropped.append(def.drops[rng.randi() % def.drops.size()][0])
			for part in dropped:
				var at: Vector2 = m.pos + Vector2.from_angle(rng.randf() * TAU) * m.radius * 0.5
				capsules.append({"pos": at, "part": part, "t": 0.0})
				events.append({"t": "drop", "part": part, "pos": at})
	if not dead.is_empty():
		mobs = mobs.filter(func(m): return m.alive)
	var gone := allies.filter(func(a): return not a.alive)
	for a: Creature in gone:
		events.append({"t": "ally_lost", "pos": a.pos, "who": a, "color": a.color, "radius": a.radius, "species": "ally", "by_player": false, "golden": false})
	if not gone.is_empty():
		allies = allies.filter(func(a): return a.alive)
		_ally_t = 45.0
	if not player.alive:
		_reborn()

## Тебя съели: новая клетка того же вида появляется поодаль, целая и на пару секунд
## неуязвимая. Всё найденное и накопленное остаётся.
func _reborn() -> void:
	if mode == "arena":
		# На арене гибель — конец боя: счёт — сколько волн продержался.
		arena_over = true
		player.alive = true
		player.hp = player.max_hp
		evo.arena_best = maxi(evo.arena_best, wave - 1)
		events.append({"t": "arena_over", "wave": wave, "kills": wave_kills})
		return
	if evo.diff().get("permadeath", false):
		player.alive = true
		extinct = true
		events.append({"t": "permadeath", "pos": player.pos})
		return
	evo.count("deaths")
	player.rider_host = null
	# Паразиты остаются там, где тебя съели, — не едут за новой клеткой.
	for m in mobs:
		if m.host == player:
			m.host = null
	var lost := evo.death_loss()
	events.append({"t": "death", "pos": player.pos, "lost": lost})
	# Новая клетка — поодаль; гиганта рядом с ней нет.
	var away := Vector2.from_angle(rng.randf() * TAU) * (view_radius * 2.0 + 400.0)
	player.pos += away
	mobs = mobs.filter(func(m): return not is_giant(m) or m.pos.distance_to(player.pos) > view_radius * 1.5)
	player.vel = Vector2.ZERO
	player.alive = true
	player.hp = player.max_hp
	player.poison_t = 0.0
	player.invuln = 3.0
	mobs = mobs.filter(func(m): return m.pos.distance_to(player.pos) > view_radius * 1.2 or not _hunts(m))
	_safe_t = 12.0


# --- поведение ------------------------------------------------------------------------

func _hunts(m: Creature) -> bool:
	if m.is_player or m.ally or m.species == "mate":
		return false
	var def: Dictionary = Content.SPECIES[m.species]
	# Бывший гигант мирный, но если ты его ранил — даёт сдачи.
	if def.behavior == "roamer" and not m.giant:
		return m.player_hit_t < 6.0
	return def.behavior == "hunter" or def.get("hunts", false)

## Опасен ли o для m: охотник или ты (тебе хватит и рывка), и не мелочь.
func _threat_to(m: Creature, o: Creature) -> bool:
	if o == m or not o.alive or (o.species != "" and o.species == m.species) or friendly(m, o):
		return false
	if o.ally:
		return o.radius >= m.radius * 0.9
	if o.is_player:
		return o.invuln <= 0.0 and o.radius >= m.radius * 0.7
	return _hunts(o) and o.radius >= m.radius * 0.8

func _nearest_threat(m: Creature, within: float) -> Creature:
	var best: Creature = null
	var best_d := within
	for o in everyone():
		if not _threat_to(m, o):
			continue
		var d := m.pos.distance_to(o.pos) - o.radius
		if d < best_d:
			best_d = d
			best = o
	return best

func _nearest_prey(m: Creature) -> Creature:
	var best: Creature = null
	var best_d := m.sight * (1.3 if m.aggro else 1.0)
	var ratio := 1.7 if m.aggro else PREY_RATIO
	for o in everyone():
		if o == m or not o.alive or o.species == m.species or o.invuln > 0.0 or o.hidden_t > 0.0:
			continue
		if is_giant(o):
			continue
		# Хищники чужих видов — соперники: сцепляются, даже если соперник чуть крупнее.
		var rival := not o.is_player and not o.ally and _hunts(o)
		if o.radius > m.radius * (maxf(ratio, 1.6) if rival else ratio):
			continue
		var d := m.pos.distance_to(o.pos)
		# Маскировка: замечают позже.
		if o.camo > 0.0 and d > best_d * (1.0 - o.camo):
			continue
		if d < best_d:
			best_d = d
			best = o
	return best

func _nearest_food(m: Creature, within: float) -> Dictionary:
	var best := {}
	var best_d := within
	for f in food:
		if f.eaten or not m.eats(f.kind):
			continue
		var d := m.pos.distance_to(f.pos)
		if d < best_d:
			best_d = d
			best = f
	return best

func _think(m: Creature, dt: float) -> void:
	m.resting = maxf(0.0, m.resting - dt)
	if m.ai_state == "chase":
		m.stamina -= dt / CHASE_TIME
	else:
		m.stamina = minf(1.0, m.stamina + dt / REST_TIME)
	m.ai_t -= dt
	if m.ai_t > 0.0:
		return
	m.ai_t = 0.18 + rng.randf() * 0.12
	var b := m.behavior()
	if b == "parasite":
		_parasite_think(m)
		return
	if b == "shooter":
		_shooter_think(m)
		return
	if b == "roamer":
		_roamer_think(m)
		return
	if b == "ambush" and m.revealed_t <= 0.0:
		_ambush_wait(m)
		return
	_mob_ability(m)
	var hunts := _hunts(m)
	var weak := m.hp < m.max_hp * 0.35
	# Дать сдачи: вооружённого укусил чужой (не ты) — не бежит, а дерётся, пока силы есть.
	var foe := m.last_attacker
	if foe != null and foe.alive and not foe.is_player and not foe.ally and foe.species != m.species and m.calm_t < 3.0 \
			and not weak and m.armed() and foe.radius < m.radius * 1.8 and m.pos.distance_to(foe.pos) < m.sight:
		m.ai_state = "fight"
		m.ai_target = foe
		m.desire = (foe.pos - m.pos).normalized()
		return
	var flee_r := m.sight * (1.0 if b == "skittish" else 0.65)
	var threat := _nearest_threat(m, flee_r)
	var runs := b == "grazer" or b == "skittish" or (hunts and weak)
	if threat != null and hunts and threat.radius >= m.radius * 1.4:
		runs = true
	if threat != null and runs:
		m.ai_state = "flee"
		m.desire = (m.pos - threat.pos).normalized()
		if m.school:
			m.desire = (m.desire + _school_pull(m) * 0.4).normalized()
		return
	if hunts and m.ai_state == "chase" and m.stamina <= 0.0:
		# Выдохся: отстаёт и отдыхает — от хищника можно оторваться.
		m.resting = REST_TIME
		m.ai_state = "rest"
		m.desire = m.desire * 0.2
		return
	if hunts and m.resting <= 0.0:
		var prey := _nearest_prey(m)
		if prey != null:
			if prey == player and m.ai_state != "chase" and m.voice_t <= 0.0:
				m.voice_t = 10.0
				events.append({"t": "voice", "kind": voice_of(m), "pos": m.pos, "size": m.size_r})
			m.ai_state = "chase"
			m.ai_target = prey
			m.desire = (prey.pos + prey.vel * 0.3 - m.pos).normalized()
			var close := m.pos.distance_to(prey.pos) < (m.radius + prey.radius) * 2.2
			if close and m.dash_cd <= 0.0 and m.faces(m.mouth.get("a", 0.0), 0.45, prey.pos):
				_lunge(m)
			return
	var f := _nearest_food(m, m.sight)
	if not f.is_empty():
		m.ai_state = "feed"
		m.desire = (f.pos - m.pos).normalized() * (0.45 if b == "drifter" else 0.8)
		return
	if m.ai_state != "wander" or m.pos.distance_to(m.ai_goal) < m.radius or rng.randf() < 0.03:
		m.ai_state = "wander"
		m.ai_goal = m.pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(80.0, 220.0)
	m.desire = (m.ai_goal - m.pos).normalized() * (0.35 if b == "drifter" else 0.5)
	if m.school:
		m.desire = (m.desire + _school_pull(m)).limit_length(0.7)

## Бросок хищника на добычу.
func _lunge(m: Creature) -> void:
	m.vel += m.heading_vec() * m.dash_power * 0.8
	m.dash_t = 0.3
	m.dash_cd = 2.5


# --- наполнение океана ----------------------------------------------------------------

func _plant_outer() -> float:
	return view_radius * 1.8 + 200.0

func _plant_target() -> int:
	# Отдельных водорослей немного — основная еда травоядных растёт по краям кругов.
	# В цветение их втрое больше, в мёртвой зоне — вдвое меньше.
	return int(45.0 * _event_mult("bloom", 3.0) * _event_mult("dead", 0.5))

func _mob_target() -> int:
	# Кого ты только что съел, того место пустует ещё какое-то время: иначе хищник
	# ел бы без передышки, а новые приплывали бы прямо под нос.
	_kills_recent = _kills_recent.filter(func(t): return time - t < KILL_QUIET)
	var n := maxi(4, mini(8 + evo.level() / 2, 14) - _kills_recent.size())
	# В мёртвой зоне живых вдвое меньше.
	return maxi(2, int(n * _event_mult("dead", 0.5)))

## Водоросли гуще на «лугах» — пятнах плавного шума.
func _spawn_plant(inner: float, outer: float, anywhere := false) -> void:
	var lvl := evo.level()
	# Крупной клетке и водоросли попадаются крупнее — но медленнее, чем она растёт.
	var value := 1 + (lvl - 1) / 4
	for attempt in 6:
		var r := sqrt(rng.randf_range(inner * inner, outer * outer)) if anywhere else rng.randf_range(inner, outer)
		var p := player.pos + Vector2.from_angle(rng.randf() * TAU if anywhere else _spawn_angle()) * r
		var meadow := (_meadow.get_noise_2d(p.x, p.y) + 1.0) * 0.5
		if rng.randf() < (0.2 + 0.8 * meadow * meadow) * 1.15:
			food.append({"pos": p, "kind": "plant", "value": value, "r": 6.0 + 2.5 * value, "t": 0.0, "v": rng.randi() % 256, "eaten": false})
			return

func _species_pool() -> Array:
	var lvl := evo.level()
	var aggro: float = evo.diff().aggro
	var pool: Array = []
	for id in Content.SPECIES:
		var def: Dictionary = Content.SPECIES[id]
		if lvl < def.levels[0] or lvl > def.levels[1]:
			continue
		if _safe_t > 0.0 and (def.behavior == "hunter" or def.get("hunts", false)):
			continue
		# Бывшие гиганты: ты их перерос — плавают стайками, как все.
		var former_giant: bool = def.behavior == "roamer" and not is_giant_now(def)
		if def.weight <= 0.0 and not former_giant:
			continue
		if def.behavior == "roamer" and not former_giant:
			continue
		# Совсем мелкие для тебя — уже не встречаются (кроме паразитов: они мелкие нарочно).
		var est: float = giant_size(def) if def.behavior == "roamer" else float(def.radius) * grow_k(def)
		if est < player.size_r * 0.3 and def.behavior != "parasite":
			continue
		var w: float = 0.3 if former_giant else def.weight
		if def.behavior == "hunter" or def.get("aggro", false):
			w *= aggro
		pool.append([id, w])
	return pool

## Куда ставить новое: плывёшь быстро — чаще впереди по ходу (иначе впереди пусто).
func _spawn_angle() -> float:
	if player.vel.length() > 40.0 and rng.randf() < 0.7:
		return player.vel.angle() + rng.randf_range(-1.1, 1.1)
	return rng.randf() * TAU

func _spawn_mob(anywhere := false, at := Vector2.INF) -> Creature:
	# Сначала место — ближе, чем раньше: сразу за краем видимого, — потом вода, потом кто в ней живёт.
	if at == Vector2.INF:
		var inner := maxf(vision() * 1.15, 200.0)
		var outer := maxf(view_radius + 600.0, inner + 400.0)
		at = player.pos + Vector2.from_angle(_spawn_angle()) * rng.randf_range(inner, outer + (500.0 if anywhere else 0.0))
	var pool := _species_pool()
	if pool.is_empty():
		return null
	var total := 0.0
	for p in pool:
		total += p[1]
	var roll := rng.randf() * total
	var pick: String = pool[-1][0]
	for p in pool:
		roll -= p[1]
		if roll <= 0.0:
			pick = p[0]
			break
	var def: Dictionary = Content.SPECIES[pick]
	var golden: bool = def.behavior != "roamer" and not def.has("school") and rng.randf() < Content.GOLDEN_CHANCE * _event_mult("dead", 4.0)
	var first := spawn(pick, at, golden)
	# Стайка появляется вся сразу, кучкой: двое или трое, не больше.
	var group := rng.randi_range(2, mini(int(def.school), 3)) if def.has("school") else (rng.randi_range(2, 3) if def.behavior == "roamer" else 1)
	for i in group - 1:
		spawn(pick, at + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(10.0, 60.0))
	return first

## Поставить клетку вида id в точку — и для проверок тоже.
func spawn(id: String, at: Vector2, golden := false, size := 0.0) -> Creature:
	var def: Dictionary = Content.SPECIES[id]
	# Великаны всегда во много раз больше тебя, каким бы ты ни был. Остальные растут вместе
	# с тобой, но медленнее: хищники остаются опасными, а мелочь — мелочью.
	var giant := false
	if size <= 0.0:
		if def.behavior == "roamer":
			size = giant_size(def) * rng.randf_range(0.95, 1.05)
			giant = is_giant_now(def)
		elif def.has("scale"):
			size = player.size_r * float(def.scale)
		else:
			size = float(def.radius) * grow_k(def) * rng.randf_range(0.9, 1.1)
	var bonus := 0 if def.has("scale") else clampi((evo.level() - int(def.levels[0])) / 3, 0, 2)
	var m := Creature.of_species(id, size, bonus)
	m.giant = giant
	_vary(m, def)
	if golden:
		m.make_golden()
	m.pos = at
	m.heading = rng.randf() * TAU - PI
	m.ai_t = rng.randf() * 0.2
	mobs.append(m)
	return m

## Каждая особь чуть своя: оттенок, форма, у некоторых — узор. Вид узнаётся, но стайка
## не выглядит одинаковыми копиями.
func _vary(m: Creature, def: Dictionary) -> void:
	if def.has("scale") or def.behavior == "ambush":
		return
	var h := m.color.h + rng.randf_range(-0.035, 0.035)
	m.color = Color.from_hsv(fposmod(h, 1.0), clampf(m.color.s * rng.randf_range(0.85, 1.15), 0.0, 1.0), clampf(m.color.v * rng.randf_range(0.88, 1.1), 0.0, 1.0))
	var shape: Array = m.shape.duplicate()
	for i in shape.size():
		shape[i] = clampf(float(shape[i]) * rng.randf_range(0.93, 1.07), Content.SHAPE_MIN, Content.SHAPE_MAX)
	m.shape = shape
	var roll := rng.randf()
	m.pattern = "spots" if roll < 0.18 else ("stripes" if roll < 0.3 else ("rings" if roll < 0.38 else "none"))
	m.color2 = m.color.darkened(0.3) if rng.randf() < 0.6 else m.color.lightened(0.35)

## Сколько уровней после своего вид ещё остаётся гигантом.
const GIANT_LEVELS := 2

## Размер бродячего вида сейчас. Пока он гигант — во много раз больше тебя, но с каждым твоим
## уровнем на четверть меньше (не меньше 1,8 раза). Перерос — он уже с тебя ростом,
## дальше мельчает (до 0,6 тебя), зато плавает стайкой.
func giant_size(def: Dictionary) -> float:
	var steps := evo.level() - int(def.levels[0])
	if is_giant_now(def):
		return player.size_r * maxf(1.8, float(def.get("scale", 2.0)) * pow(0.75, maxi(steps, 0)))
	return player.size_r * maxf(0.6, 1.0 - 0.12 * (steps - GIANT_LEVELS - 1))

## Гигант ли вид сейчас (для тебя): на своём уровне и ещё двух следующих.
func is_giant_now(def: Dictionary) -> bool:
	return evo.level() <= int(def.levels[0]) + GIANT_LEVELS

## Во сколько раз вид крупнее своего обычного: каким он задуман на размере, с которого
## появляется, таким и встречается; перерастаешь его — он подрастает, но медленнее тебя.
func grow_k(def: Dictionary) -> float:
	return maxf(1.0, pow(player.size_r / Content.radius_for(int(def.levels[0])), 0.6))

func _manage() -> void:
	var outer := _plant_outer()
	var far_food := outer * 1.3
	food = food.filter(func(f): return f.pos.distance_to(player.pos) < far_food)
	var plants := food.filter(func(f): return f.kind == "plant" and not f.has("col")).size()
	for i in mini(_plant_target() - plants, 12):
		_spawn_plant(view_radius + 40.0, outer)
	# Кто уплыл далеко — исчезает, а рядом появляются новые: так вокруг всегда кто-то есть.
	var far := view_radius + 900.0
	# Хозяева логов дома ждут дольше, но если уплыл совсем далеко — исчезают и они
	# (вернёшься — логово снова занято, хозяин целый).
	# Хозяева логов и бродячие гиганты уплывают из памяти позже остальных.
	mobs = mobs.filter(func(m): return m.pos.distance_to(player.pos) < (far if not is_giant(m) else far + 3000.0))
	capsules = capsules.filter(func(c): return c.pos.distance_to(player.pos) < far)
	if mode != "arena":
		for i in mini(_mob_target() - mobs.size(), 5):
			_spawn_mob()
	rocks = rocks.filter(func(k): return k.pos.distance_to(player.pos) < far)
	if rocks.size() < _rock_target():
		_spawn_rock(view_radius + 60.0, view_radius + 700.0)
	if mode != "arena":
		var gone := colonies.filter(func(k): return k.pos.distance_to(player.pos) >= far)
		for k in gone:
			food = food.filter(func(f): return f.get("col", 0) != k.uid)
		colonies = colonies.filter(func(k): return k.pos.distance_to(player.pos) < far)
		if colonies.size() < _colony_target():
			_spawn_colony(view_radius + 40.0, view_radius + 500.0)
	for m in mobs:
		var near := m.pos.distance_to(player.pos) < vision() + m.radius
		# Обманку, пока она притворяется водорослью, узнаёшь только с двумя глазами.
		var disguised := m.behavior() == "ambush" and m.revealed_t <= 0.0 and player.eyes < 2.0
		if near and not evo.seen.has(m.species) and not (m.invisible and player.eyes <= 0.0) and not disguised:
			evo.seen[m.species] = true
			events.append({"t": "seen", "species": m.species})
		if near and not m.voiced and not disguised and not (m.invisible and player.eyes <= 0.0):
			m.voiced = true
			var v := voice_of(m)
			if v != "":
				events.append({"t": "voice", "kind": v, "pos": m.pos, "size": m.size_r})
		if near and m.golden and not m.announced:
			m.announced = true
			events.append({"t": "golden", "species": m.species, "pos": m.pos})


# --- камни ----------------------------------------------------------------------------

func _rock_target() -> int:
	return 5 + evo.level() / 2

## Камень подходящего размера — чуть в стороне, не на тебе.
func _spawn_rock(inner: float, outer: float, kind := "") -> Dictionary:
	var lvl := evo.level()
	if kind == "":
		var pool: Array = []
		var total := 0.0
		for id in Content.ROCKS:
			var def: Dictionary = Content.ROCKS[id]
			if lvl >= def.levels[0] and lvl <= def.levels[1]:
				pool.append([id, def.weight])
				total += def.weight
		var roll := rng.randf() * total
		kind = pool[-1][0]
		for p in pool:
			roll -= p[1]
			if roll <= 0.0:
				kind = p[0]
				break
	var at := player.pos + Vector2.from_angle(_spawn_angle()) * rng.randf_range(inner, outer)
	return add_rock(kind, at)

## Поставить камень — и для проверок тоже.
func add_rock(kind: String, at: Vector2) -> Dictionary:
	var def: Dictionary = Content.ROCKS[kind]
	var k := pow(player.size_r / 16.0, 0.8)
	var drift := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(4.0, 10.0) * sqrt(k)
	var rock := {"pos": at, "r": def.radius * k, "hp": def.hp * k * k, "max_hp": def.hp * k * k, "kind": kind,
		"v": rng.randi() % 1000, "uid": _rock_uid, "flash": 0.0, "vel": drift, "drift": drift}
	_rock_uid -= 1
	rocks.append(rock)
	return rock

## Камни тяжёлые: кто упёрся — отодвигается сам, а камень лишь чуть подаётся. Ты можешь
## их крошить.
func _rock_contacts(all: Array[Creature]) -> void:
	var broken: Array = []
	for rock in rocks:
		rock.flash = maxf(0.0, rock.flash - 0.08)
		for c in all:
			if not c.alive:
				continue
			var d: Vector2 = c.pos - rock.pos
			var min_d: float = c.radius + rock.r
			if d.length_squared() >= min_d * min_d:
				continue
			var dist := d.length()
			var n := d / dist if dist > 0.001 else Vector2.RIGHT
			c.pos = rock.pos + n * min_d
			var into := c.vel.dot(-n)
			if c.is_player:
				_hit_rock(rock, c, into)
			if into > 0.0:
				c.vel += n * into
				_nudge(rock, -n * into, c.radius)
		if rock.hp <= 0.0:
			broken.append(rock)
	for rock in broken:
		rocks.erase(rock)
		_rock_broken(rock)

func _hit_rock(rock: Dictionary, c: Creature, into: float) -> void:
	var dmg := 0.0
	if c.dash_t > 0.0 and not c.dash_hit.has(rock.uid):
		c.dash_hit[rock.uid] = true
		dmg += RAM_DAMAGE * 1.5 * pow(c.size_k(), 0.7)
	var bite: float = c.mouth.get("bite", 0.0)
	if bite > 0.0 and c.bite_cd <= 0.0 and c.faces(c.mouth.a, c.mouth.arc, rock.pos):
		c.bite_cd = BITE_CD
		c.bite_anim = 1.0
		dmg += bite
	for sp in c.spikes:
		if c.hit_cd.get(rock.uid, 0.0) <= 0.0 and c.faces(sp.a, sp.arc, rock.pos):
			c.hit_cd[rock.uid] = SPIKE_CD
			dmg += sp.dmg * sp.rock
			break
	if dmg <= 0.0:
		return
	rock.hp -= dmg
	rock.flash = 1.0
	events.append({"t": "rock_hit", "pos": rock.pos + (c.pos - rock.pos).normalized() * rock.r, "dmg": dmg, "rock": rock.kind})

func _rock_broken(rock: Dictionary) -> void:
	var def: Dictionary = Content.ROCKS[rock.kind]
	evo.count("rocks")
	var bonus: float = def.dna * pow(player.size_r / 16.0, 0.5)
	events.append({"t": "rock_break", "pos": rock.pos, "r": rock.r, "rock": rock.kind, "dna": bonus})
	_gain(bonus)
	for d in def.drops:
		if rng.randf() < d[1] * float(evo.diff().drop):
			var at: Vector2 = rock.pos + Vector2.from_angle(rng.randf() * TAU) * rock.r * 0.4
			capsules.append({"pos": at, "part": d[0], "t": 0.0})
			events.append({"t": "drop", "part": d[0], "pos": at})


# --- круги водорослей и всё, что плывёт само ---------------------------------------------

func _colony_target() -> int:
	return 0 if mode == "arena" else 4 + evo.level() / 4

func _spawn_colony(inner: float, outer: float) -> Dictionary:
	var at := player.pos + Vector2.from_angle(_spawn_angle()) * rng.randf_range(inner, outer)
	return add_colony(at)

## Круг: растёт вместе с тобой, по краю — места под еду, сначала все заняты.
func add_colony(at: Vector2) -> Dictionary:
	var k := pow(player.size_r / 16.0, 0.8)
	var drift := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(6.0, 14.0) * sqrt(k)
	var col := {"pos": at, "r": rng.randf_range(38.0, 60.0) * k, "vel": drift, "drift": drift,
		"spin": rng.randf() * TAU, "v": rng.randi() % 1000, "uid": _colony_uid, "regrow": COLONY_REGROW}
	_colony_uid += 1
	colonies.append(col)
	for i in COLONY_BITS:
		_grow_bit(col, i)
	return col

## Кусочек еды на краю круга, на месте slot.
func _grow_bit(col: Dictionary, slot: int) -> void:
	var lvl := evo.level()
	var value := 1 + (lvl - 1) / 4
	var f := {"pos": col.pos, "kind": "plant", "value": value, "r": 6.0 + 2.5 * value, "t": 0.0,
		"v": rng.randi() % 256, "eaten": false, "col": col.uid, "slot": slot}
	food.append(f)
	_place_bit(col, f)

func _place_bit(col: Dictionary, f: Dictionary) -> void:
	var a: float = col.spin + TAU * float(f.slot) / COLONY_BITS
	f.pos = col.pos + Vector2.from_angle(a) * (col.r + f.r * 0.55)

## Всё, что плывёт само: круги и камни. Течение несёт, толчок сдвигает, потом снова
## своим ходом. Еда на кругах едет вместе с ними и отрастает.
func _floating(dt: float) -> void:
	for thing in colonies + rocks:
		thing.vel = thing.vel.lerp(thing.drift, minf(1.0, dt * 0.6))
		thing.pos += (thing.vel + current_at(thing.pos) * 0.4) * dt
	if colonies.is_empty():
		return
	var by_uid := {}
	for col in colonies:
		col.spin += dt * 0.08
		col.regrow -= dt
		by_uid[col.uid] = {"col": col, "taken": {}}
	for f in food:
		if f.has("col") and by_uid.has(f.col):
			var entry: Dictionary = by_uid[f.col]
			_place_bit(entry.col, f)
			entry.taken[f.slot] = true
	for uid in by_uid:
		var entry: Dictionary = by_uid[uid]
		var col: Dictionary = entry.col
		if col.regrow > 0.0:
			continue
		col.regrow = COLONY_REGROW
		for i in COLONY_BITS:
			if not entry.taken.has(i):
				_grow_bit(col, i)
				break

## Толчок: чем крупнее толкающий относительно предмета, тем сильнее сдвиг.
func _nudge(thing: Dictionary, push: Vector2, pusher_r: float) -> void:
	var k := clampf(pow(pusher_r / float(thing.r), 2.0) * 0.35, 0.0, 0.8)
	thing.vel += push * k

## Круги плотные: через них не проплыть, их можно лишь чуть подвинуть. Круги и камни не
## наезжают друг на друга.
func _colony_contacts(all: Array[Creature]) -> void:
	for col in colonies:
		# Круг плотный — через него не проплыть; упрёшься — он чуть отплывёт.
		for c in all:
			if not c.alive or c == player and player.rider_host != null:
				continue
			var d: Vector2 = c.pos - col.pos
			var min_d: float = c.radius + col.r
			if d.length_squared() >= min_d * min_d:
				continue
			var dist := d.length()
			var n := d / dist if dist > 0.001 else Vector2.RIGHT
			c.pos = col.pos + n * min_d
			var into := c.vel.dot(-n)
			if into > 0.0:
				c.vel += n * into
				_nudge(col, -n * into, c.radius)
		for rock in rocks:
			var d2: Vector2 = col.pos - rock.pos
			var gap: float = col.r + rock.r
			if d2.length_squared() < gap * gap and d2.length() > 0.001:
				col.pos = rock.pos + d2.normalized() * gap


# --- выстрелы: плевки ядом и иглы -----------------------------------------------------

## Снаряды в полёте: [{pos, vel, kind, dmg, poison, from, r, t}].
var shots: Array = []
const SHOT_LIFE := 1.6

## Кто может стрелять — стреляет: ты и потомки — в ближайшего врага впереди, существа —
## в свою цель (поворачиваются к ней).
func _guns() -> void:
	for c in everyone():
		if c.guns.is_empty() or not c.alive:
			continue
		for i in c.guns.size():
			if float(c.gun_cd.get(i, 0.0)) > 0.0:
				continue
			var g: Dictionary = c.guns[i]
			var target: Creature = null
			if c.is_player or c.ally:
				var best: float = g.range
				for m in mobs:
					if not m.alive or m.host != null or m.species == "mate" or (m.behavior() == "ambush" and m.revealed_t <= 0.0):
						continue
					var d := c.pos.distance_to(m.pos) - m.radius
					if d < best and c.faces(g.a, g.arc, m.pos):
						best = d
						target = m
			else:
				var t: Creature = c.ai_target
				if t != null and t.alive and c.pos.distance_to(t.pos) - t.radius < float(g.range) and t.hidden_t <= 0.0:
					c.heading = (t.pos - c.pos).angle() - float(g.a)
					target = t
			if target == null:
				continue
			c.gun_cd[i] = float(g.reload)
			var dir := (target.pos + target.vel * 0.25 - c.pos).normalized()
			var spd := 430.0 * pow(c.size_k(), 0.25)
			shots.append({"pos": c.pos + dir * c.radius, "vel": dir * spd, "kind": g.kind, "dmg": g.dmg, "poison": g.poison,
				"from": c, "r": 4.0 * sqrt(c.size_k()), "t": 0.0})
			events.append({"t": "shot", "kind": g.kind, "pos": c.pos, "by_player": c.is_player})

func _shots(dt: float) -> void:
	if shots.is_empty():
		return
	var all := everyone()
	var left: Array = []
	for s in shots:
		s.t += dt
		s.pos += s.vel * dt
		var hit: bool = s.t > SHOT_LIFE
		# Камни и круги заслоняют — за ними можно спрятаться.
		for k in rocks + colonies:
			if not hit and s.pos.distance_to(k.pos) < float(k.r):
				hit = true
		var from: Creature = s.from
		for o in all:
			if hit:
				break
			if o == from or not o.alive or friendly(from, o) or (not from.is_player and not from.ally and o.species == from.species):
				continue
			if s.pos.distance_to(o.pos) < o.radius + float(s.r):
				hit = true
				_hurt(o, float(s.dmg), from, "shot")
				if float(s.poison) > 0.0 and o.invuln <= 0.0:
					o.poison_dps = maxf(o.poison_dps if o.poison_t > 0.0 else 0.0, float(s.poison))
					o.poison_t = POISON_TIME
					o.poison_from = from
				events.append({"t": "shot_hit", "kind": s.kind, "pos": s.pos})
		if not hit:
			left.append(s)
	shots = left

## Стрелок: держится на расстоянии выстрела, подплывёшь вплотную — отплывает.
func _shooter_think(m: Creature) -> void:
	var target: Creature = null
	if player.alive and player.hidden_t <= 0.0 and player.pos.distance_to(m.pos) < m.sight * 1.3 and player.radius < m.radius * 2.5:
		target = player
	else:
		target = _nearest_prey(m)
	if target == null:
		m.ai_target = null
		m.ai_state = "wander"
		if m.pos.distance_to(m.ai_goal) < m.radius or rng.randf() < 0.03:
			m.ai_goal = m.pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(80.0, 200.0)
		m.desire = (m.ai_goal - m.pos).normalized() * 0.45
		return
	m.ai_target = target
	m.ai_state = "aim"
	var to := target.pos - m.pos
	var d := to.length()
	var want := 230.0 * pow(m.size_k(), 0.4)
	if d < (m.radius + target.radius) * 1.8 or d < want * 0.7:
		m.desire = -to.normalized()
	elif d > want * 1.3:
		m.desire = to.normalized() * 0.8
	else:
		m.desire = to.normalized().orthogonal() * (0.5 if m.uid % 2 == 0 else -0.5)
	if m.voice_t <= 0.0 and target == player:
		m.voice_t = 10.0
		events.append({"t": "voice", "kind": "growl", "pos": m.pos, "size": m.size_r})


# --- обманка, делитель ------------------------------------------------------------------

## Обманка ждёт, притворившись водорослью; подплыл близко — кусает.
func _ambush_wait(m: Creature) -> void:
	m.desire = Vector2.ZERO
	m.ai_state = "wait"
	var reach := m.radius * 2.2 + 50.0
	for o in everyone():
		if o == m or not o.alive or o.species == m.species or o.hidden_t > 0.0 or friendly(m, o):
			continue
		if o.radius > m.radius * 2.0 or m.pos.distance_to(o.pos) > reach + o.radius:
			continue
		m.revealed_t = 6.0
		m.ai_target = o
		m.ai_state = "chase"
		m.heading = (o.pos - m.pos).angle()
		_lunge(m)
		events.append({"t": "ambush", "pos": m.pos, "to_player": o.is_player})
		return

## Делитель: ранили до половины — распался на двоих поменьше (они уже не делятся).
var _to_split: Array = []

func _do_splits() -> void:
	for m: Creature in _to_split:
		if not m.alive or not mobs.has(m):
			continue
		var size := m.size_r * 0.72
		var side := Vector2.from_angle(m.heading).orthogonal()
		for s in [-1.0, 1.0]:
			var kid := spawn(m.species, m.pos + side * s * m.radius * 0.6, false, size)
			kid.split_done = true
			kid.hp = kid.max_hp * 0.8
			kid.vel = side * s * 160.0
			kid.player_hit_t = m.player_hit_t
			kid.last_attacker = m.last_attacker
			kid.age = 1.0
		mobs.erase(m)
		events.append({"t": "split", "pos": m.pos, "color": m.color})
	_to_split.clear()


# --- бродячие гиганты -----------------------------------------------------------------

var _roam_t := 45.0

## Гиганты плавают поодиночке: вокруг не больше одного. Раз в минуту-две проплывает новый —
## чаще тот, что появился на твоём размере, реже старые знакомые.
func _roamers(dt: float) -> void:
	if mode == "arena":
		return
	if mobs.any(func(m): return is_giant(m)):
		return
	_roam_t -= dt
	if _roam_t > 0.0:
		return
	_roam_t = rng.randf_range(60.0, 120.0)
	var pick := pick_giant()
	if pick == "":
		return
	var dir := Vector2.from_angle(rng.randf() * TAU)
	var m := spawn(pick, player.pos + dir * (view_radius + 500.0))
	# Путь — мимо тебя и дальше, на другой край.
	m.ai_goal = player.pos - dir.rotated(rng.randf_range(-0.4, 0.4)) * (view_radius + 3000.0)
	events.append({"t": "roamer", "species": pick, "pos": m.pos})

## Какой гигант проплывёт: новые для твоего размера — втрое чаще.
func pick_giant() -> String:
	var lvl := evo.level()
	var pool: Array = []
	var total := 0.0
	for id in Content.SPECIES:
		var def: Dictionary = Content.SPECIES[id]
		if def.behavior != "roamer" or lvl < int(def.levels[0]) or lvl > int(def.levels[1]) or not is_giant_now(def):
			continue
		var w := 3.0 if int(def.levels[0]) == lvl else (2.0 if int(def.levels[0]) == lvl - 1 else 1.0)
		pool.append([id, w])
		total += w
	if pool.is_empty():
		return ""
	var roll := rng.randf() * total
	for q in pool:
		roll -= q[1]
		if roll <= 0.0:
			return q[0]
	return pool[-1][0]

func _roamer_think(m: Creature) -> void:
	var def: Dictionary = Content.SPECIES[m.species]
	var close := player.alive and player.hidden_t <= 0.0 and player.pos.distance_to(m.pos) < m.sight * 1.1
	# Полоса здоровья сверху — пока гигант бьётся с тобой.
	var engaged := close and (m.ai_state == "chase" or (m.last_attacker == player and m.calm_t < 6.0))
	if engaged:
		boss_active = m
	elif boss_active == m:
		boss_active = null
	if (def.get("hunts", false) or m.aggro) and close and m.resting <= 0.0:
		if m.stamina <= 0.0:
			m.resting = REST_TIME
			m.ai_state = "rest"
			m.desire *= 0.2
			return
		m.ai_state = "chase"
		m.ai_target = player
		m.desire = (player.pos + player.vel * 0.3 - m.pos).normalized()
		if m.pos.distance_to(player.pos) < (m.radius + player.radius) * 1.6 and m.dash_cd <= 0.0:
			_lunge(m)
			m.dash_cd = 4.0
		if m.voice_t <= 0.0:
			m.voice_t = 12.0
			events.append({"t": "voice", "kind": "boom", "pos": m.pos, "size": m.size_r})
		return
	if m.calm_t < 4.0 and m.last_attacker != null and m.last_attacker.alive:
		# Мирного разозлили — разворачивается и отбивается.
		m.ai_state = "guard"
		m.desire = (m.last_attacker.pos - m.pos).normalized() * 0.5
		return
	m.ai_state = "travel"
	if m.pos.distance_to(m.ai_goal) < m.radius * 2.0:
		m.ai_goal = m.pos + Vector2.from_angle(rng.randf() * TAU) * 3000.0
	m.desire = (m.ai_goal - m.pos).normalized() * 0.45


# --- прилипала ------------------------------------------------------------------------

var _away_t := 0.0

## Прилип к крупному: едешь с ним, ешь крохи (ДНК и лечение), он тебя не кусает.
## Отцепиться — рывком, ходом прочь; или сам отпадёшь, если он погибнет.
func _riding(dt: float) -> void:
	var p := player
	if p.rider_host != null:
		var h := p.rider_host
		if not h.alive or not mobs.has(h) or p.rider_t > 30.0:
			_unride()
			return
		p.rider_t += dt
		var dir := Vector2.from_angle(h.heading + p.rider_angle)
		p.pos = h.pos + dir * (h.radius + p.radius)
		p.vel = h.vel
		var side: float = p.remora[0].a if not p.remora.is_empty() else 0.0
		p.heading = wrapf((-dir).angle() - side, -PI, PI)
		if mode != "arena":
			_gain(0.4 * sqrt(p.size_k()) * dt)
		p.hp = minf(p.max_hp, p.hp + 0.5 * p.size_k() * dt)
		if p.desire.length() > 0.7 and p.desire.dot(dir) > 0.4:
			_away_t += dt
		else:
			_away_t = 0.0
		if _away_t > 0.35:
			_unride()
		return
	if p.remora.is_empty() or not p.alive or p.dash_t > 0.0:
		return
	for m in mobs:
		if not m.alive or m.radius < p.radius * 1.3 or m.host != null:
			continue
		if p.pos.distance_to(m.pos) > p.radius + m.radius + 4.0:
			continue
		for r in p.remora:
			if p.faces(r.a, r.arc, m.pos):
				p.rider_host = m
				p.rider_angle = wrapf((p.pos - m.pos).angle() - m.heading, -PI, PI)
				p.rider_t = 0.0
				_away_t = 0.0
				evo.count("rides")
				events.append({"t": "remora_on", "species": m.species, "pos": p.pos})
				return

func _unride() -> void:
	var p := player
	if p.rider_host == null:
		return
	var away := (p.pos - p.rider_host.pos).normalized()
	p.rider_host = null
	p.vel += away * 180.0
	p.invuln = maxf(p.invuln, 0.5)
	events.append({"t": "remora_off", "pos": p.pos})


# --- обход кругов и камней, голоса ------------------------------------------------------

## Существа огибают круги и камни, а не упираются в них.
func avoid(c: Creature, desire: Vector2) -> Vector2:
	if desire.length() < 0.05:
		return desire
	var dir := desire.normalized()
	for k in colonies + rocks:
		var to: Vector2 = k.pos - c.pos
		var reach: float = float(k.r) + c.radius + 70.0
		if to.length_squared() > reach * reach:
			continue
		var along := to.dot(dir)
		if along <= 0.0:
			continue
		var side := to - dir * along
		if side.length() > float(k.r) + c.radius:
			continue
		# Обходим с той стороны, куда ближе.
		var turn := -side.normalized() if side.length() > 0.001 else dir.orthogonal()
		dir = (dir + turn * 1.3).normalized()
	return dir * desire.length()

## Какой голос у вида: мирные щебечут, хищники рычат, гиганты гудят.
static func voice_of(m: Creature) -> String:
	match m.behavior():
		"grazer", "skittish", "drifter":
			return "chirp"
		"parasite":
			return "hiss"
		"roamer":
			return "whale" if m.species == "kit" else "boom"
		"mate", "ally":
			return ""
	return "growl"


# --- пара -----------------------------------------------------------------------------

## Позвать пару: она появляется поодаль, стрелка покажет, где. false — уже зовёшь.
func call_mate() -> bool:
	if mate != null:
		return false
	var m := Creature.new()
	m.species = "mate"
	m.size_r = player.size_r
	m.shape = player.shape.duplicate()
	m.radius = player.radius
	m.color = player.color.lerp(Color("#f0a0c8"), 0.25)
	m.parts = player.parts.duplicate(true)
	m.rebuild()
	var dist := (view_radius * 0.9 + 250.0) * rng.randf_range(0.9, 1.2)
	m.pos = player.pos + Vector2.from_angle(rng.randf() * TAU) * dist
	m.heading = rng.randf() * TAU - PI
	m.ai_goal = m.pos
	mate = m
	events.append({"t": "mate_called", "pos": m.pos})
	return true

## Пара плавает неспешно рядом со своим местом. Коснулся — новое поколение.
func _mate_step(dt: float) -> void:
	if mate == null:
		return
	mate.age += dt
	if mate.pos.distance_to(mate.ai_goal) < mate.radius or rng.randf() < 0.01:
		mate.ai_goal = mate.pos + Vector2.from_angle(rng.randf() * TAU) * 60.0
	mate.desire = (mate.ai_goal - mate.pos).normalized() * 0.25
	_move(mate, dt)
	if player.alive and player.pos.distance_to(mate.pos) < player.radius + mate.radius + 4.0:
		evo.generation += 1
		evo.count("mates")
		# Каждое поколение — ещё один потомок в свите, до трёх.
		if mode == "normal":
			evo.brood = mini(3, evo.brood + 1)
			if allies.size() < evo.brood:
				_spawn_ally()
		events.append({"t": "mated", "pos": (player.pos + mate.pos) / 2.0, "generation": evo.generation})
		mate = null


# --- воды и течения -------------------------------------------------------------------

## Течение в точке: узкие полосы вдоль линий плавного шума. Вне полос — ноль.
func current_at(p: Vector2) -> Vector2:
	if mode == "arena" or not nature:
		return Vector2.ZERO
	# Буря: везде сносит в одну сторону.
	var storm := storm_dir * STORM_FORCE * event_k if event_look == "storm" else Vector2.ZERO
	var n := _flow.get_noise_2d(p.x, p.y)
	var band := 1.0 - absf(n) / 0.07
	if band <= 0.0:
		return storm
	var e := 4.0
	var grad := Vector2(_flow.get_noise_2d(p.x + e, p.y) - _flow.get_noise_2d(p.x - e, p.y), _flow.get_noise_2d(p.x, p.y + e) - _flow.get_noise_2d(p.x, p.y - e))
	if grad.length_squared() < 1e-12:
		return Vector2.ZERO
	# Вдоль линии — поперёк уклона; сила — в середине полосы больше.
	return grad.normalized().orthogonal() * 85.0 * band * band + storm

## Сколько видно: глаза, вода и сложность.
func vision() -> float:
	# Глаз разгоняет туман по-настоящему: один — видно почти весь экран, два — весь.
	var k := clampf(player.eyes / 2.0, 0.0, 1.0)
	var v := lerpf(player.vision, maxf(player.vision, view_radius * 1.1), k) * player.light
	v *= float(evo.diff().vision)
	# Мёртвая зона — темно.
	v *= _event_mult("dead", 0.7)
	# На арене видно весь круг — прятаться там не в чем.
	return maxf(v * 1.6, arena_radius * 1.15) if mode == "arena" else v


# --- паразиты -------------------------------------------------------------------------

func _parasite_think(m: Creature) -> void:
	if m.host != null:
		return
	var d := m.pos.distance_to(player.pos)
	var attached := mobs.filter(func(o): return o.host == player).size()
	if d < m.sight * 1.2 and attached < 4 and player.invuln <= 0.0 and player.hidden_t <= 0.0 and m.resting <= 0.0:
		m.ai_state = "chase"
		m.desire = (player.pos - m.pos).normalized()
	else:
		m.ai_state = "wander"
		if m.pos.distance_to(m.ai_goal) < m.radius or rng.randf() < 0.05:
			m.ai_goal = m.pos + Vector2.from_angle(rng.randf() * TAU) * 120.0
		m.desire = (m.ai_goal - m.pos).normalized() * 0.5

## Прицепившиеся едут на хозяине и пьют здоровье; свободные цепляются при касании.
func _parasites(dt: float) -> void:
	for m in mobs:
		if Content.SPECIES[m.species].behavior != "parasite" or not m.alive:
			continue
		if m.host != null:
			if not m.host.alive:
				m.host = null
				continue
			m.host_t += dt
			if m.host_t > PARASITE_FULL:
				# Насытился и отвалился — отдыхает, потом снова ищет, к кому прицепиться.
				m.host = null
				m.resting = 8.0
				m.vel = Vector2.from_angle(m.heading) * 120.0
				continue
			var h := m.host
			m.pos = h.pos + Vector2.from_angle(h.heading + m.host_angle) * (h.radius + m.radius * 0.2)
			m.heading = h.heading + m.host_angle + PI
			_hurt(h, 1.2 * m.size_k() * dt * 4.0, m, "drain", true)
			m.hp = minf(m.max_hp, m.hp + dt)
		elif player.alive and m.resting <= 0.0 and m.pos.distance_to(player.pos) < player.radius + m.radius and player.invuln <= 0.0:
			m.host = player
			m.host_t = 0.0
			m.host_angle = player.rel_angle(m.pos)
			events.append({"t": "parasite", "pos": m.pos})

## Рывок стряхивает всех паразитов — они отлетают и получают своё.
func _shake_off() -> void:
	var n := 0
	for m in mobs:
		if m.host == player:
			m.host = null
			var away := (m.pos - player.pos).normalized()
			m.pos += away * 12.0
			m.vel = away * 260.0
			m.player_hit_t = 0.0
			m.hp -= m.max_hp * 0.6
			if m.hp <= 0.0:
				m.alive = false
			m.resting = 3.0
			n += 1
	if n > 0:
		evo.count("shaken", n)
		events.append({"t": "shaken", "n": n, "pos": player.pos})


# --- гиганты: сила --------------------------------------------------------------------

## Через сколько секунд паразит насыщается и отпадает сам (рывком — сразу).
const PARASITE_FULL := 12.0
## Гиганты бьют слабее своего размера — иначе одолеть их было бы нельзя.
const GIANT_DAMAGE := 0.35
## Бывшие гиганты (ты их перерос) — стаей, но бьют слабее обычного.
const FORMER_GIANT_DAMAGE := 0.6

## Гигант ли это (бродячий, один на всю округу).
static func is_giant(m: Creature) -> bool:
	return m.giant


# --- свита ----------------------------------------------------------------------------

## Потомок: твоя клетка поменьше, плавает рядом и помогает драться.
func _spawn_ally() -> Creature:
	var a := Creature.new()
	a.ally = true
	a.species = "ally"
	a.size_r = player.size_r * 0.5
	a.shape = player.shape.duplicate()
	a.radius = player.radius * 0.5
	a.color = player.color.lightened(0.15)
	a.parts = player.parts.duplicate(true)
	a.rebuild()
	a.speed = maxf(a.speed, player.speed * 1.15)
	a.hp = a.max_hp
	a.pos = player.pos + Vector2.from_angle(rng.randf() * TAU) * player.radius * 2.5
	a.invuln = 1.5
	allies.append(a)
	return a

func _ally_think(a: Creature, dt: float) -> void:
	a.ai_t -= dt
	if a.ai_t > 0.0:
		return
	a.ai_t = 0.2
	var target: Creature = null
	var t := player.ai_target
	if t != null and t.alive and not t.ally and t.pos.distance_to(player.pos) < 500.0:
		target = t
	elif player.last_attacker != null and player.last_attacker.alive and player.calm_t < 4.0 and not player.last_attacker.ally:
		target = player.last_attacker
	if target != null and target.host == null:
		a.ai_state = "chase"
		a.desire = (target.pos - a.pos).normalized()
		if a.pos.distance_to(target.pos) < (a.radius + target.radius) * 2.0 and a.dash_cd <= 0.0:
			_lunge(a)
		return
	# Держится рядом, каждый на своём месте позади.
	var i := allies.find(a)
	var spot := player.pos - player.heading_vec().rotated((i - 1) * 0.7) * player.radius * 2.6
	var to := spot - a.pos
	a.ai_state = "follow"
	a.desire = to.normalized() * clampf(to.length() / 80.0, 0.0, 1.0)
	if a.pos.distance_to(player.pos) > view_radius * 2.0:
		a.pos = spot


## Тело игрока поменялось — потомки в свите тоже.
func resync_allies() -> void:
	for a in allies:
		a.size_r = player.size_r * 0.5
		a.shape = player.shape.duplicate()
		a.radius = player.radius * 0.5
		a.color = player.color.lightened(0.15)
		a.parts = player.parts.duplicate(true)
		var share := a.hp / a.max_hp
		a.rebuild()
		a.speed = maxf(a.speed, player.speed * 1.15)
		a.hp = a.max_hp * share


# --- умения ---------------------------------------------------------------------------

## Умение по кнопке. false — нет умения или ещё не готово.
func use_ability() -> bool:
	var p := player
	if p.ability == "" or p.ability_t > 0.0 or not p.alive:
		return false
	p.ability_t = p.ability_cd
	evo.count("abilities")
	_do_ability(p)
	return true

func _do_ability(c: Creature) -> void:
	match c.ability:
		"ink":
			c.hidden_t = 2.5
			for m in mobs:
				if m.ai_target == c and m.pos.distance_to(c.pos) < 500.0:
					m.ai_target = null
					m.ai_state = "rest"
					m.resting = 3.0
		"shield":
			c.shield_t = 3.0
		"pulse":
			for o in everyone():
				if o == c or friendly(c, o) or (c.species != "" and o.species == c.species):
					continue
				var d := o.pos.distance_to(c.pos) - o.radius
				if d < c.radius * 4.0:
					_hurt(o, 8.0 * c.ability_power, c, "zap")
					o.vel += (o.pos - c.pos).normalized() * 280.0
		"suck":
			for f in food:
				if f.pos.distance_to(c.pos) < c.radius * 9.0:
					f.suck = 2.0
	events.append({"t": "ability", "ability": c.ability, "pos": c.pos, "r": c.radius, "by_player": c.is_player})

## Существа с умениями тоже ими пользуются: чернильник — удирая, броненосец — когда бьют,
## искрун — когда рядом враг.
func _mob_ability(m: Creature) -> void:
	if m.ability == "" or m.ability_t > 0.0:
		return
	var use := false
	match m.ability:
		"ink":
			use = m.ai_state == "flee"
		"shield":
			use = m.calm_t < 0.5
		"pulse":
			use = player.pos.distance_to(m.pos) < m.radius * 3.5
	if use:
		m.ability_t = m.ability_cd * 1.5
		_do_ability(m)


# --- чтобы океан не пустел ------------------------------------------------------------

## Если рядом давно никого — кто-нибудь приплывёт сам.
func _directing(dt: float) -> void:
	if mode == "arena":
		return
	# Пока рядом кто-то есть — ждём; стало пусто — через пару секунд кто-нибудь покажется.
	var seen_r := vision() * 2.5
	if mobs.any(func(m): return m.pos.distance_to(player.pos) < seen_r):
		_director_t = 2.5
		return
	_director_t -= dt
	if _director_t > 0.0:
		return
	_director_t = 2.5
	# Впереди по ходу: сзади новенький не догнал бы.
	var dir := player.vel.angle() + rng.randf_range(-0.8, 0.8) if player.vel.length() > 20.0 else rng.randf() * TAU
	var at := player.pos + Vector2.from_angle(dir) * (vision() + 60.0)
	var m := _spawn_mob(false, at)
	if m != null:
		m.ai_state = "wander"
		m.ai_goal = player.pos


# --- арена ----------------------------------------------------------------------------

func start_arena() -> void:
	mode = "arena"
	spawning = false
	arena_center = player.pos
	arena_radius = 370.0 * pow(player.size_k(), 0.6)
	mobs.clear()
	rocks.clear()
	colonies.clear()
	shots.clear()
	food.clear()
	allies.clear()
	for i in 40:
		_spawn_plant(40.0, arena_radius * 0.9, true)
	wave = 0
	_wave_t = 2.0

func _arena(dt: float) -> void:
	if arena_over:
		return
	# Стенки: никто не выплывает за круг.
	for c in everyone():
		var off := c.pos - arena_center
		var lim := arena_radius - c.radius
		if off.length() > lim:
			c.pos = arena_center + off.normalized() * lim
			c.vel = c.vel.slide(off.normalized())
	if food.filter(func(f): return f.kind == "plant").size() < 20:
		_spawn_plant(40.0, arena_radius * 0.9, true)
	if not mobs.is_empty():
		return
	_wave_t -= dt
	if _wave_t > 0.0:
		return
	wave += 1
	_wave_t = 3.0
	evo.arena_best = maxi(evo.arena_best, wave - 1)
	# Великаны и боссы — только в каждой пятой волне, первым.
	var pool := _species_pool()
	var count := 1 + wave
	for i in count:
		var pick: String = pool[rng.randi() % pool.size()][0]
		if wave % 5 == 0 and i == 0:
			pick = ["velikan", "pozhiratel", "gigant"][rng.randi() % 3]
		var at := arena_center + Vector2.from_angle(rng.randf() * TAU) * arena_radius * 0.85
		var m := spawn(pick, at)
		m.aggro = true
		m.ai_goal = player.pos
	events.append({"t": "wave", "wave": wave})


## Стая: тянет к середине своих и выравнивает по их ходу.
func _school_pull(m: Creature) -> Vector2:
	var center := Vector2.ZERO
	var heading := Vector2.ZERO
	var n := 0
	for o in mobs:
		if o != m and o.species == m.species and o.pos.distance_to(m.pos) < 160.0:
			center += o.pos
			heading += o.vel
			n += 1
	if n == 0:
		return Vector2.ZERO
	center /= n
	var pull := (center - m.pos) / 120.0
	return (pull + heading.normalized() * 0.5).limit_length(1.0)


# --- события в океане ------------------------------------------------------------------

## Как сильно буря сносит (точек в секунду).
const STORM_FORCE := 55.0

## Множитель от события: пока идёт событие id — плавно тянется к k, иначе 1.
func _event_mult(id: String, k: float) -> float:
	return lerpf(1.0, k, event_k) if event_look == id else 1.0

## Раз в несколько минут — событие; держится свой срок и плавно спадает.
func _world_events(dt: float) -> void:
	if mode == "arena":
		return
	event_k = move_toward(event_k, 1.0 if event != "" else 0.0, dt / 4.0)
	if event == "" and event_k <= 0.0:
		event_look = ""
	if event != "":
		event_t -= dt
		if event == "storm":
			storm_dir = storm_dir.rotated(0.03 * dt * sin(time * 0.1))
		if event == "spawn":
			_spawn_wave_t -= dt
			if _spawn_wave_t <= 0.0:
				_spawn_wave_t = 15.0
				_spawn_brood()
		if event_t <= 0.0:
			events.append({"t": "world_event_end", "id": event})
			event = ""
			_event_cd = _event_rng.randf_range(280.0, 420.0)
		return
	_event_cd -= dt
	if _event_cd <= 0.0:
		var ids: Array = Content.EVENTS.keys().filter(func(id): return id != _event_last)
		start_event(ids[_event_rng.randi() % ids.size()])

## Начать событие сейчас (и для проверок).
func start_event(id: String) -> void:
	event = id
	event_look = id
	_event_last = id
	event_t = float(Content.EVENTS[id].len)
	if id == "storm":
		storm_dir = Vector2.from_angle(_event_rng.randf() * TAU)
	if id == "spawn":
		_spawn_wave_t = 15.0
		_spawn_brood()
	events.append({"t": "world_event", "id": id})

## Нерест: две-три стайки малышей мирного вида — впереди и по сторонам.
func _spawn_brood() -> void:
	var calm: Array = _species_pool().map(func(x): return x[0]).filter(func(id):
		var b: String = Content.SPECIES[id].behavior
		return (b == "grazer" or b == "skittish") and not Content.SPECIES[id].has("scale"))
	if calm.is_empty():
		calm = ["kroshka"]
	for g in rng.randi_range(2, 3):
		var id: String = calm[rng.randi() % calm.size()]
		var at := player.pos + Vector2.from_angle(_spawn_angle()) * rng.randf_range(vision() * 0.9, view_radius + 200.0)
		for i in rng.randi_range(3, 5):
			var m := spawn(id, at + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 50.0), false, player.size_r * rng.randf_range(0.35, 0.5))
			m.school = true
