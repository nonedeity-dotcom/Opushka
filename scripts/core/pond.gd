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
const MEAT_DNA := 3.0
## Хищник гонится не дольше стольких секунд, потом отдыхает — от него можно оторваться.
const CHASE_TIME := 5.0
const REST_TIME := 4.0

var evo: Evolution
var player: Creature
var mobs: Array[Creature] = []
var food: Array = []  # [{pos, kind: plant/meat, value, r, t, v, eaten}]
var capsules: Array = []  # [{pos, part, t}]
var events: Array = []
var rng := RandomNumberGenerator.new()
## Полдиагонали экрана в точках мира: за этим краем появляются новые клетки.
var view_radius := 600.0
## Можно выключить в проверках — тогда океан не наполняется сам.
var spawning := true
var time := 0.0
var _manage_t := 0.0
var _safe_t := 25.0
var _grid := {}
var _meadow := FastNoiseLite.new()


func _init(e: Evolution, seed := 0) -> void:
	evo = e
	rng.seed = seed if seed != 0 else randi()
	_meadow.seed = rng.randi()
	_meadow.frequency = 0.0022
	player = Creature.of_player(evo)

## Наполнить океан вокруг — при старте и после рождения заново.
func fill() -> void:
	var outer := _plant_outer()
	for i in _plant_target():
		_spawn_plant(60.0, outer, true)
	for i in _mob_target() / 2:
		_spawn_mob(true)


# --- шаг ------------------------------------------------------------------------------

## Один шаг. input — куда плыть (длина 0–1), dash — нажат «Рывок».
func step(dt: float, input: Vector2, dash := false) -> void:
	events.clear()
	time += dt
	_safe_t -= dt
	player.desire = input.limit_length(1.0)
	if dash:
		do_dash(player)
	for m in mobs:
		_think(m, dt)
	var all := everyone()
	for c in all:
		_move(c, dt)
		_timers(c, dt)
	_collide(all)
	_zaps(all)
	_rebuild_grid()
	_eat(all)
	_pickup()
	_age(dt)
	_deaths()
	if player.dna_rate > 0.0:
		_gain(player.dna_rate * dt)
	if spawning:
		_manage_t -= dt
		if _manage_t <= 0.0:
			_manage_t = 0.5
			_manage()
	for g in evo.check_goals():
		events.append({"t": "goal", "goal": g})

func everyone() -> Array[Creature]:
	var all: Array[Creature] = [player]
	all.append_array(mobs)
	return all


# --- движение -------------------------------------------------------------------------

func _move(c: Creature, dt: float) -> void:
	var spd := c.speed
	if c.ai_state == "flee" and not c.is_player and c.behavior() == "skittish":
		spd *= 1.25
	var goal := c.desire * spd
	# Во время рывка вода тормозит слабее — разгон доносит до цели.
	var k := 0.8 if c.dash_t > 0.0 else 4.0
	c.vel = c.vel.lerp(goal, 1.0 - exp(-k * dt))
	c.pos += c.vel * dt
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
	c.dash_cd = DASH_CD
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
	for k in c.hit_cd.keys():
		c.hit_cd[k] -= dt
		if c.hit_cd[k] <= 0.0:
			c.hit_cd.erase(k)
	if c.poison_t > 0.0:
		c.poison_t -= dt
		_hurt(c, c.poison_dps * dt, c.poison_from, "poison", true)
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
	if x.is_player:
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
	dmg *= mult
	y.hp -= dmg
	y.calm_t = 0.0
	if from != null:
		y.last_attacker = from
		if from.is_player:
			y.player_hit_t = 0.0
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
			if o == c or not o.alive or (c.species != "" and o.species == c.species):
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
	for f in food:
		f.t += dt
	if food.any(func(f): return f.kind == "meat" and f.t > MEAT_LIFE):
		food = food.filter(func(f): return f.kind != "meat" or f.t <= MEAT_LIFE)
	for cap in capsules:
		cap.t += dt
	if capsules.any(func(c): return c.t > CAPSULE_LIFE):
		capsules = capsules.filter(func(c): return c.t <= CAPSULE_LIFE)

func _gain(amount: float) -> void:
	if evo.add_dna(amount):
		player.sync_player(evo)
		player.hp = player.max_hp
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
		events.append({"t": "kill", "pos": m.pos, "species": m.species, "by_player": by_player, "radius": m.radius, "color": m.color, "golden": m.golden})
		if by_player:
			evo.count("kills")
			evo.kills_by[m.species] = evo.kills_by.get(m.species, 0) + 1
			if m.golden:
				evo.count("golden")
			var bonus: float = (1.0 + 1.5 * def.tier) * (3.0 if m.golden else 1.0)
			events[-1].dna = bonus
			_gain(bonus)
			var dropped: Array = []
			for d in def.drops:
				if rng.randf() < d[1]:
					dropped.append(d[0])
			# Из сияющей что-нибудь выпадает всегда.
			if m.golden and dropped.is_empty() and not def.drops.is_empty():
				dropped.append(def.drops[rng.randi() % def.drops.size()][0])
			for part in dropped:
				var at: Vector2 = m.pos + Vector2.from_angle(rng.randf() * TAU) * m.radius * 0.5
				capsules.append({"pos": at, "part": part, "t": 0.0})
				events.append({"t": "drop", "part": part, "pos": at})
	if not dead.is_empty():
		mobs = mobs.filter(func(m): return m.alive)
	if not player.alive:
		_reborn()

## Тебя съели: новая клетка того же вида появляется поодаль, целая и на пару секунд
## неуязвимая. Всё найденное и накопленное остаётся.
func _reborn() -> void:
	evo.count("deaths")
	events.append({"t": "death", "pos": player.pos})
	var away := Vector2.from_angle(rng.randf() * TAU) * (view_radius * 2.0 + 400.0)
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
	if m.is_player:
		return false
	var def: Dictionary = Content.SPECIES[m.species]
	return def.behavior == "hunter" or def.get("hunts", false)

## Опасен ли o для m: охотник или ты (тебе хватит и рывка), и не мелочь.
func _threat_to(m: Creature, o: Creature) -> bool:
	if o == m or not o.alive or (o.species != "" and o.species == m.species):
		return false
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
	var best_d := m.sight
	for o in everyone():
		if o == m or not o.alive or o.species == m.species or o.invuln > 0.0:
			continue
		if not o.is_player and Content.SPECIES[o.species].behavior == "boss":
			continue
		if o.radius > m.radius * PREY_RATIO:
			continue
		var d := m.pos.distance_to(o.pos)
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
	var hunts := _hunts(m)
	var weak := m.hp < m.max_hp * 0.35
	var flee_r := m.sight * (1.0 if b == "skittish" else 0.65)
	var threat := _nearest_threat(m, flee_r)
	var runs := b == "grazer" or b == "skittish" or (hunts and weak)
	if threat != null and hunts and threat.radius >= m.radius * 1.4 and b != "boss":
		runs = true
	if threat != null and runs:
		m.ai_state = "flee"
		m.desire = (m.pos - threat.pos).normalized()
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
		m.desire = (f.pos - m.pos).normalized() * (0.45 if b == "drifter" or b == "boss" else 0.8)
		return
	if m.ai_state != "wander" or m.pos.distance_to(m.ai_goal) < m.radius or rng.randf() < 0.03:
		m.ai_state = "wander"
		m.ai_goal = m.pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(80.0, 220.0)
	m.desire = (m.ai_goal - m.pos).normalized() * (0.35 if b == "drifter" or b == "boss" else 0.5)

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
	return mini(10 + evo.level(), 22)

## Водоросли гуще на «лугах» — пятнах плавного шума.
func _spawn_plant(inner: float, outer: float, anywhere := false) -> void:
	var lvl := evo.level()
	# Крупной клетке и водоросли попадаются крупнее — но медленнее, чем она растёт.
	var value := 1 + (lvl - 1) / 4
	for attempt in 6:
		var r := sqrt(rng.randf_range(inner * inner, outer * outer)) if anywhere else rng.randf_range(inner, outer)
		var p := player.pos + Vector2.from_angle(rng.randf() * TAU) * r
		var meadow := (_meadow.get_noise_2d(p.x, p.y) + 1.0) * 0.5
		if rng.randf() < 0.2 + 0.8 * meadow * meadow:
			food.append({"pos": p, "kind": "plant", "value": value, "r": 6.0 + 2.5 * value, "t": 0.0, "v": rng.randi() % 256, "eaten": false})
			return

func _species_pool() -> Array:
	var lvl := evo.level()
	var boss_here := mobs.any(func(m): return Content.SPECIES[m.species].behavior == "boss")
	var pool: Array = []
	for id in Content.SPECIES:
		var def: Dictionary = Content.SPECIES[id]
		if lvl < def.levels[0] or lvl > def.levels[1]:
			continue
		if def.behavior == "boss" and boss_here:
			continue
		if _safe_t > 0.0 and (def.behavior == "hunter" or def.behavior == "boss"):
			continue
		pool.append([id, def.weight])
	return pool

func _spawn_mob(anywhere := false) -> Creature:
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
	var inner := view_radius + 60.0
	var r := rng.randf_range(inner, inner + (900.0 if anywhere else 600.0))
	var golden: bool = Content.SPECIES[pick].behavior != "boss" and rng.randf() < Content.GOLDEN_CHANCE
	return spawn(pick, player.pos + Vector2.from_angle(rng.randf() * TAU) * r, golden)

## Поставить клетку вида id в точку — и для проверок тоже.
func spawn(id: String, at: Vector2, golden := false) -> Creature:
	var m := Creature.of_species(id)
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
	var far := view_radius + 1200.0
	mobs = mobs.filter(func(m): return m.pos.distance_to(player.pos) < far)
	capsules = capsules.filter(func(c): return c.pos.distance_to(player.pos) < far)
	for i in mini(_mob_target() - mobs.size(), 3):
		_spawn_mob()
	for m in mobs:
		var near := m.pos.distance_to(player.pos) < player.vision + m.radius
		if near and not evo.seen.has(m.species):
			evo.seen[m.species] = true
			events.append({"t": "seen", "species": m.species})
		if near and m.golden and not m.announced:
			m.announced = true
			events.append({"t": "golden", "species": m.species, "pos": m.pos})
