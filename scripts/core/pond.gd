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
const MEAT_DNA := 1.3
## Хищник гонится не дольше стольких секунд, потом отдыхает — от него можно оторваться.
const CHASE_TIME := 5.0
const REST_TIME := 4.0

var evo: Evolution
var player: Creature
var mobs: Array[Creature] = []
var food: Array = []  # [{pos, kind: plant/meat, value, r, t, v, eaten}]
var capsules: Array = []  # [{pos, part, t}]
var rocks: Array = []  # [{pos, r, hp, max_hp, kind, v, uid, flash}]
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
var lairs := {}
var lairs_done := {}
## Хозяин логова, который сейчас бьётся с тобой, — для полоски здоровья наверху.
var boss_active: Creature = null
var biome := ""
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

## Наполнить океан вокруг — при старте и после рождения заново.
func fill() -> void:
	var outer := _plant_outer()
	for i in _plant_target():
		_spawn_plant(60.0, outer, true)
	for i in _mob_target() / 2:
		_spawn_mob(true)
	for i in _rock_target():
		_spawn_rock(view_radius * 0.6, view_radius + 700.0)
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
		if do_dash(player):
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
	_zaps(all)
	_mate_step(dt)
	_rebuild_grid()
	_eat(all)
	_pickup()
	_age(dt)
	_deaths()
	if player.dna_rate > 0.0 and mode != "arena":
		_gain(player.dna_rate * dt)
	_biome_effects(dt)
	_bosses(dt)
	if mode == "arena":
		_arena(dt)
	if spawning:
		_manage_t -= dt
		if _manage_t <= 0.0:
			_manage_t = 0.5
			_manage()
		_directing(dt)
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
	if c.is_player and biome == "cold" and not c.coldproof:
		spd *= float(Content.BIOMES.cold.chill)
	var goal := c.desire * spd
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
	if c.dash_cd > 0.0 or not c.alive:
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
	c.age += dt
	for k in c.hit_cd.keys():
		c.hit_cd[k] -= dt
		if c.hit_cd[k] <= 0.0:
			c.hit_cd.erase(k)
	if c.poison_t > 0.0:
		c.poison_t -= dt
		_hurt(c, c.poison_dps * dt, c.poison_from, "poison", true)
	# Хозяин логова сам по себе не лечится — только дома, когда тебя давно нет.
	if c.lair != Vector2.INF:
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
	if from != null and from.lair != Vector2.INF and kind != "wave":
		dmg *= LAIR_DAMAGE
	y.hp -= dmg
	# Шипастая броня: обидчику возвращается часть удара (у хозяина логова — вдвое меньше).
	if y.thorns > 0.0 and from != null and from != y and kind in ["bite", "spike", "grab", "ram", "drain"]:
		from.hp -= dmg * y.thorns * (0.5 if y.lair != Vector2.INF else 1.0)
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
			"to_player": y.is_player, "from_player": from != null and from.is_player})
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
		c.hp = minf(c.max_hp, c.hp + 3.0)
	c.eat_anim = 1.0
	if not c.is_player:
		return
	var gain: float
	if f.kind == "plant":
		gain = f.value * c.mouth.eat_plant
		evo.count("plants")
	else:
		gain = MEAT_DNA * c.mouth.eat_meat
		evo.count("meat")
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
		if drift:
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
		for i in maxi(1, int(m.radius / 8.0)):
			var off := Vector2.from_angle(rng.randf() * TAU) * rng.randf() * m.radius * 0.8
			food.append({"pos": m.pos + off, "kind": "meat", "value": 1, "r": 5.0, "t": 0.0, "v": rng.randi() % 256, "eaten": false})
		var by_player := m.player_hit_t < KILL_CREDIT
		events.append({"t": "kill", "pos": m.pos, "species": m.species, "by_player": by_player, "radius": m.radius, "color": m.color, "golden": m.golden, "who": m})
		if def.behavior == "lair":
			lairs_done[_lair_key(m.lair)] = true
			if boss_active == m:
				boss_active = null
			if by_player:
				evo.lairs_beaten[m.species] = true
				events.append({"t": "lair_beaten", "species": m.species, "pos": m.pos})
		if mode == "arena" and by_player:
			wave_kills += 1
		if by_player:
			_kills_recent.append(time)
			evo.count("kills")
			evo.kills_by[m.species] = evo.kills_by.get(m.species, 0) + 1
			if m.golden:
				evo.count("golden")
			var bonus: float = (0.8 + 1.1 * def.tier) * (3.0 if m.golden else 1.0)
			events[-1].dna = bonus
			_gain(bonus)
			var dropped: Array = []
			for d in (def.drops if mode != "arena" else []):
				if rng.randf() < d[1] * float(evo.diff().drop):
					dropped.append(d[0])
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
	# Паразиты остаются там, где тебя съели, — не едут за новой клеткой.
	for m in mobs:
		if m.host == player:
			m.host = null
	var lost := evo.death_loss()
	events.append({"t": "death", "pos": player.pos, "lost": lost})
	# Новая клетка — поодаль и не у чужого логова.
	var away := Vector2.from_angle(rng.randf() * TAU) * (view_radius * 2.0 + 400.0)
	for i in 8:
		var at := player.pos + away
		if lairs_near_point(at, 1100.0).is_empty():
			break
		away = away.rotated(TAU / 8.0)
	player.pos += away
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
		if not o.is_player and not o.ally and Content.SPECIES[o.species].behavior in ["boss", "giant", "lair"]:
			continue
		if o.radius > m.radius * ratio:
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
	if b == "lair":
		_lair_think(m)
		return
	_mob_ability(m)
	var hunts := _hunts(m)
	var weak := m.hp < m.max_hp * 0.35
	var flee_r := m.sight * (1.0 if b == "skittish" else 0.65)
	var threat := _nearest_threat(m, flee_r)
	var runs := b == "grazer" or b == "skittish" or (hunts and weak)
	if threat != null and hunts and threat.radius >= m.radius * 1.4 and b != "boss" and b != "giant":
		runs = true
	if threat != null and runs:
		m.ai_state = "flee"
		m.desire = (m.pos - threat.pos).normalized()
		if m.school:
			m.desire = (m.desire + _school_pull(m) * 0.4).normalized()
		return
	if b == "boss" and not hunts and m.calm_t < 3.0 and m.last_attacker != null and m.last_attacker.alive:
		# Великан не гоняется — разворачивается к обидчику шипами.
		m.ai_state = "guard"
		m.desire = (m.last_attacker.pos - m.pos).normalized() * 0.25
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
		m.desire = (f.pos - m.pos).normalized() * (0.45 if b in ["drifter", "boss", "giant"] else 0.8)
		return
	if m.ai_state != "wander" or m.pos.distance_to(m.ai_goal) < m.radius or rng.randf() < 0.03:
		m.ai_state = "wander"
		m.ai_goal = m.pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(80.0, 220.0)
	m.desire = (m.ai_goal - m.pos).normalized() * (0.35 if b in ["drifter", "boss", "giant"] else 0.5)
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
	return 120

func _mob_target() -> int:
	# Кого ты только что съел, того место пустует ещё какое-то время: иначе хищник
	# ел бы без передышки, а новые приплывали бы прямо под нос.
	_kills_recent = _kills_recent.filter(func(t): return time - t < KILL_QUIET)
	return maxi(3, mini(6 + evo.level() / 3, 9) - _kills_recent.size())

## Водоросли гуще на «лугах» — пятнах плавного шума.
func _spawn_plant(inner: float, outer: float, anywhere := false) -> void:
	var lvl := evo.level()
	# Крупной клетке и водоросли попадаются крупнее — но медленнее, чем она растёт.
	var value := 1 + (lvl - 1) / 4
	for attempt in 6:
		var r := sqrt(rng.randf_range(inner * inner, outer * outer)) if anywhere else rng.randf_range(inner, outer)
		var p := player.pos + Vector2.from_angle(rng.randf() * TAU) * r
		var meadow := (_meadow.get_noise_2d(p.x, p.y) + 1.0) * 0.5
		var rich: float = Content.BIOMES[biome_at(p)].plants
		if rng.randf() < (0.2 + 0.8 * meadow * meadow) * rich:
			food.append({"pos": p, "kind": "plant", "value": value, "r": 6.0 + 2.5 * value, "t": 0.0, "v": rng.randi() % 256, "eaten": false})
			return

func _species_pool(where := "") -> Array:
	var lvl := evo.level()
	var aggro: float = evo.diff().aggro
	var boss_here := mobs.any(func(m): return Content.SPECIES[m.species].behavior == "boss")
	var giant_here := mobs.any(func(m): return Content.SPECIES[m.species].behavior == "giant")
	var pool: Array = []
	for id in Content.SPECIES:
		var def: Dictionary = Content.SPECIES[id]
		if lvl < def.levels[0] or lvl > def.levels[1]:
			continue
		if def.behavior == "boss" and boss_here:
			continue
		if def.behavior == "giant" and giant_here:
			continue
		if _safe_t > 0.0 and (def.behavior == "hunter" or def.behavior == "boss" or def.get("hunts", false)):
			continue
		if def.weight <= 0.0:
			continue
		# У каждой воды свои жители; у кого вода не указана — живут везде.
		if where != "" and def.has("biomes") and not where in def.biomes:
			continue
		var w: float = def.weight
		if def.behavior == "hunter" or def.get("aggro", false):
			w *= aggro
		pool.append([id, w])
	return pool

func _spawn_mob(anywhere := false, at := Vector2.INF) -> Creature:
	# Сначала место — ближе, чем раньше: сразу за краем видимого, — потом вода, потом кто в ней живёт.
	if at == Vector2.INF:
		var inner := maxf(player.vision * 1.15, 200.0)
		var outer := maxf(view_radius + 250.0, inner + 300.0)
		at = player.pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(inner, outer + (500.0 if anywhere else 0.0))
	var pool := _species_pool(biome_at(at))
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
	var golden: bool = not def.behavior in ["boss", "giant", "lair"] and not def.has("school") and rng.randf() < Content.GOLDEN_CHANCE
	var first := spawn(pick, at, golden)
	# Стайка появляется вся сразу, кучкой: двое или трое, не больше.
	var group := rng.randi_range(2, mini(int(def.school), 3)) if def.has("school") else 1
	for i in group - 1:
		spawn(pick, at + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(10.0, 60.0))
	return first

## Поставить клетку вида id в точку — и для проверок тоже.
func spawn(id: String, at: Vector2, golden := false) -> Creature:
	var def: Dictionary = Content.SPECIES[id]
	# Великаны всегда во много раз больше тебя, каким бы ты ни был.
	var m := Creature.of_species(id, player.size_r * float(def.scale) if def.has("scale") else 0.0)
	if golden:
		m.make_golden()
	m.pos = at
	m.heading = rng.randf() * TAU - PI
	m.ai_t = rng.randf() * 0.2
	mobs.append(m)
	return m

func _manage() -> void:
	var outer := _plant_outer()
	var far_food := outer * 1.3
	food = food.filter(func(f): return f.pos.distance_to(player.pos) < far_food)
	var plants := food.filter(func(f): return f.kind == "plant").size()
	for i in mini(_plant_target() - plants, 12):
		_spawn_plant(view_radius + 40.0, outer)
	# Кто уплыл далеко — исчезает, а рядом появляются новые: так вокруг всегда кто-то есть.
	var far := view_radius + 700.0
	# Хозяева логов дома ждут дольше, но если уплыл совсем далеко — исчезают и они
	# (вернёшься — логово снова занято, хозяин целый).
	mobs = mobs.filter(func(m): return m.pos.distance_to(player.pos) < (far if m.lair == Vector2.INF else far + 2500.0))
	capsules = capsules.filter(func(c): return c.pos.distance_to(player.pos) < far)
	if mode != "arena":
		for i in mini(_mob_target() - mobs.size(), 3):
			_spawn_mob()
		_lairs_around()
	rocks = rocks.filter(func(k): return k.pos.distance_to(player.pos) < far)
	if rocks.size() < _rock_target():
		_spawn_rock(view_radius + 60.0, view_radius + 700.0)
	for m in mobs:
		var near := m.pos.distance_to(player.pos) < player.vision + m.radius
		if near and not evo.seen.has(m.species) and not (m.invisible and player.eyes <= 0.0):
			evo.seen[m.species] = true
			events.append({"t": "seen", "species": m.species})
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
	var at := player.pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(inner, outer)
	return add_rock(kind, at)

## Поставить камень — и для проверок тоже.
func add_rock(kind: String, at: Vector2) -> Dictionary:
	var def: Dictionary = Content.ROCKS[kind]
	var k := pow(player.size_r / 16.0, 0.8)
	var rock := {"pos": at, "r": def.radius * k, "hp": def.hp * k * k, "max_hp": def.hp * k * k, "kind": kind,
		"v": rng.randi() % 1000, "uid": _rock_uid, "flash": 0.0}
	_rock_uid -= 1
	rocks.append(rock)
	return rock

## Камни не сдвинуть: кто в них упёрся — отодвигается сам. Ты можешь их крошить.
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

## Какая вода в этом месте: мелководье, глубина, горячие источники, холодное течение.
func biome_at(p: Vector2) -> String:
	if mode == "arena" or not nature:
		return "shallows"
	var t := _temp.get_noise_2d(p.x, p.y)
	if t > 0.32:
		return "hot"
	if t < -0.32:
		return "cold"
	if _depth.get_noise_2d(p.x, p.y) > 0.18:
		return "deep"
	return "shallows"

## Течение в точке: узкие полосы вдоль линий плавного шума. Вне полос — ноль.
func current_at(p: Vector2) -> Vector2:
	if mode == "arena" or not nature:
		return Vector2.ZERO
	var n := _flow.get_noise_2d(p.x, p.y)
	var band := 1.0 - absf(n) / 0.07
	if band <= 0.0:
		return Vector2.ZERO
	var e := 4.0
	var grad := Vector2(_flow.get_noise_2d(p.x + e, p.y) - _flow.get_noise_2d(p.x - e, p.y), _flow.get_noise_2d(p.x, p.y + e) - _flow.get_noise_2d(p.x, p.y - e))
	if grad.length_squared() < 1e-12:
		return Vector2.ZERO
	# Вдоль линии — поперёк уклона; сила — в середине полосы больше.
	return grad.normalized().orthogonal() * 85.0 * band * band

## Сколько видно: глаза, вода и сложность.
func vision() -> float:
	var v: float = player.vision * float(Content.BIOMES[biome if biome != "" else "shallows"].vision) * float(evo.diff().vision)
	# На арене видно весь круг — прятаться там не в чем.
	return maxf(v * 1.6, arena_radius * 1.15) if mode == "arena" else v

func _biome_effects(dt: float) -> void:
	var b := biome_at(player.pos)
	if b != biome:
		biome = b
		var first := not evo.biomes_seen.has(b)
		evo.biomes_seen[b] = true
		events.append({"t": "biome", "biome": b, "first": first})
	if biome == "hot" and not player.heatproof and player.alive and player.invuln <= 0.0:
		_hurt(player, float(Content.BIOMES.hot.burn) * player.size_k() * dt, null, "heat", true)


# --- паразиты -------------------------------------------------------------------------

func _parasite_think(m: Creature) -> void:
	if m.host != null:
		return
	var d := m.pos.distance_to(player.pos)
	var attached := mobs.filter(func(o): return o.host == player).size()
	if d < m.sight * 1.2 and attached < 4 and player.invuln <= 0.0 and player.hidden_t <= 0.0:
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
			var h := m.host
			m.pos = h.pos + Vector2.from_angle(h.heading + m.host_angle) * (h.radius + m.radius * 0.2)
			m.heading = h.heading + m.host_angle + PI
			_hurt(h, 1.2 * m.size_k() * dt * 4.0, m, "drain", true)
			m.hp = minf(m.max_hp, m.hp + dt)
		elif player.alive and m.pos.distance_to(player.pos) < player.radius + m.radius and player.invuln <= 0.0:
			m.host = player
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


# --- логова ---------------------------------------------------------------------------

const LAIR_CELL := 2600.0
## Сколько отдыхает хозяин логова после погони; бьёт он слабее своего размера.
const LAIR_REST := 3.0
const LAIR_DAMAGE := 0.35
const LAIR_BOSS := {"deep": "koroleva", "hot": "strazh", "cold": "vikhr"}

static func _lair_key(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / LAIR_CELL), floori(p.y / LAIR_CELL))

## Где в клетке сетки логово (если оно там есть) — по постоянному «случаю» клетки.
func lair_at(cell: Vector2i) -> Vector2:
	var h := hash(Vector3i(cell.x, cell.y, int(_temp.seed)))
	if h % 2 != 0:
		return Vector2.INF
	var p := (Vector2(cell) + Vector2(0.3 + 0.4 * float(h % 97) / 97.0, 0.3 + 0.4 * float(h % 89) / 89.0)) * LAIR_CELL
	return p if LAIR_BOSS.has(biome_at(p)) else Vector2.INF

## Логова поблизости: [{pos, species, done}] — для стрелок.
func lairs_near(within: float) -> Array:
	var out: Array = []
	var c := _lair_key(player.pos)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var cell := c + Vector2i(dx, dy)
			var p := lair_at(cell)
			if p != Vector2.INF and p.distance_to(player.pos) < within:
				out.append({"pos": p, "species": LAIR_BOSS[biome_at(p)], "done": lairs_done.has(cell)})
	return out

## Есть ли логово рядом с точкой (живое, не побеждённое).
func lairs_near_point(at: Vector2, within: float) -> Array:
	var out: Array = []
	var c := _lair_key(at)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var cell := c + Vector2i(dx, dy)
			var p := lair_at(cell)
			if p != Vector2.INF and p.distance_to(at) < within and not lairs_done.has(cell):
				out.append(p)
	return out

func _lairs_around() -> void:
	for l in lairs_near(view_radius + 1400.0):
		var cell := _lair_key(l.pos)
		if l.done or lairs.has(cell) and lairs[cell].alive and mobs.has(lairs[cell]):
			continue
		var def: Dictionary = Content.SPECIES[l.species]
		if evo.level() < def.levels[0]:
			continue
		var b := spawn(l.species, l.pos)
		b.lair = l.pos
		lairs[cell] = b

func _lair_think(m: Creature) -> void:
	var near := player.alive and player.pos.distance_to(m.lair) < 480.0 + m.radius and player.hidden_t <= 0.0
	if near:
		boss_active = m
		# Хозяин тоже устаёт: погонялся — стоит и отдыхает. Это окно, чтобы бить самому.
		if m.resting > 0.0 or m.stamina <= 0.0:
			if m.ai_state == "chase":
				m.resting = LAIR_REST
			m.ai_state = "rest"
			m.desire = (player.pos - m.pos).normalized() * 0.15
			return
		m.ai_state = "chase"
		m.desire = (player.pos + player.vel * 0.3 - m.pos).normalized()
		var close := m.pos.distance_to(player.pos) < (m.radius + player.radius) * 1.6
		if close and m.dash_cd <= 0.0:
			_lunge(m)
			m.dash_cd = 3.0 if m.phase_n >= 3 else 4.5
	else:
		if boss_active == m:
			boss_active = null
		m.ai_state = "home"
		var to := m.lair - m.pos
		m.desire = to.normalized() * 0.5 if to.length() > m.radius else Vector2.ZERO
		# Дома залечивается — но медленно и только когда тебя давно нет рядом: отплыл
		# подлечиться — вернулся, а бой не начинается заново.
		if m.calm_t > 8.0:
			m.hp = minf(m.max_hp, m.hp + m.max_hp * 0.004)

## Стадии боя хозяина логова: на 60% зовёт подмогу, на 30% — ярость.
func _bosses(dt: float) -> void:
	for m in mobs:
		if Content.SPECIES[m.species].behavior != "lair" or not m.alive:
			continue
		var k := m.hp / m.max_hp
		if m.phase_n == 1 and k < 0.6:
			m.phase_n = 2
			var def: Dictionary = Content.SPECIES[m.species]
			for i in 2:
				var mob := spawn(def.minions, m.pos + Vector2.from_angle(PI * i + PI / 2.0) * m.radius * 1.5)
				mob.aggro = true
			events.append({"t": "boss_phase", "phase": 2, "species": m.species, "pos": m.pos})
		elif m.phase_n == 2 and k < 0.3:
			m.phase_n = 3
			m.speed *= 1.1
			m.zap_cd = 3.0
			events.append({"t": "boss_phase", "phase": 3, "species": m.species, "pos": m.pos})
		if m.phase_n >= 3:
			# В ярости: удар волной раз в несколько секунд. За секунду до удара — вспышка,
			# чтобы успеть отплыть.
			var before := m.zap_cd
			m.zap_cd -= dt
			if before > 1.0 and m.zap_cd <= 1.0:
				events.append({"t": "boss_charge", "pos": m.pos, "r": m.radius * 2.2, "who": m})
			if m.zap_cd <= 0.0:
				m.zap_cd = 5.5
				events.append({"t": "boss_wave", "pos": m.pos, "r": m.radius * 2.2})
				if player.pos.distance_to(m.pos) < m.radius * 2.2 + player.radius:
					_hurt(player, 3.5 * pow(m.size_k(), 0.5), m, "wave")
					player.vel += (player.pos - m.pos).normalized() * 300.0


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
	var pool := _species_pool().filter(func(q): return not Content.SPECIES[q[0]].behavior in ["boss", "giant"])
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
