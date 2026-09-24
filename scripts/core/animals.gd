## Звери «Опушки»: зайцы, куры и птицы.
##
## Живут в настоящем времени, а не в игровом: заяц прыгает, пока ты стоишь, но часы мира от
## этого не идут. В сохранение звери не попадают — только сколько зайцев приручено.
##
## Заяц пуглив: побежишь к нему — удерёт. Постоишь тихо с морковкой — подойдёт сам, и его
## можно покормить; после этого он ходит следом. Куры бродят у своего курятника. Птицы
## сидят на траве и вспархивают, когда подходишь.
class_name Animals
extends RefCounted

## Зайцев в лесу — столько, сколько нашлось мест для нор, но не больше.
const HARES := 10
const BIRDS := 6
## Ближе этого на бегу — заяц пугается. «На бегу» — быстрее этой скорости, клеток в секунду.
const SCARE_DISTANCE := 2.6
const SCARE_SPEED := 1.2
## Сколько секунд стоять тихо, чтобы заяц решился подойти.
const CALM_TIME := 1.2

class Animal:
	var kind := ""
	var pos := Vector2.ZERO
	var home := Vector2.ZERO
	var goal := Vector2.ZERO
	var speed := 0.0
	var wait := 0.0
	var tame := false
	var facing := Vector2.RIGHT
	var moving := false
	var phase := 0.0
	var state := "idle"
	## Птица: высота в воздухе (0 — сидит) и пропала ли совсем.
	var lift := 0.0
	var gone := false
	var coop := ""

var list: Array[Animal] = []
var rng: WorldGen.Rng
var _calm := 0.0
var _last_player := Vector2.ZERO


func _init(v: Village) -> void:
	rng = WorldGen.Rng.new(v.seed ^ 0xA11)
	_last_player = v.pos
	var w := v.world()
	# Норы — на траве у кромки леса, по «случайному» числу клетки: у каждого мира свои.
	var spots: Array[Vector2i] = []
	for y in range(3, WorldGen.SIZE - 3):
		for x in range(3, WorldGen.SIZE - 3):
			var i := y * WorldGen.SIZE + x
			if w.ground[i] != WorldGen.Ground.GRASS or w.nature[i] != "":
				continue
			if Vector2(x, y).distance_to(Vector2(w.start)) < 6.0:
				continue
			if WorldGen.variant(v.seed ^ 0x4A2E, x, y) < 9:
				spots.append(Vector2i(x, y))
	for i in mini(HARES, spots.size()):
		var a := _make("hare", Vector2(spots[i]) + Vector2(0.5, 0.5))
		list.append(a)
	# Прирученные — рядом с тобой.
	for i in v.pets:
		var a := _make("hare", v.pos + Vector2(0.7 * (i + 1), 0.4))
		a.tame = true
		list.append(a)
	for i in BIRDS:
		list.append(_bird(v))
	sync_chickens(v)


func _make(kind: String, at: Vector2) -> Animal:
	var a := Animal.new()
	a.kind = kind
	a.pos = at
	a.home = at
	a.goal = at
	a.wait = rng.next() * 2.0
	return a

func _bird(v: Village) -> Animal:
	# Садится где-нибудь рядом с тобой, но не под ноги.
	for tries in 20:
		var ang := rng.next() * TAU
		var dist := 4.0 + rng.next() * 5.0
		var at := v.pos + Vector2(cos(ang), sin(ang)) * dist
		if not v.blocks(v.tile_of(at)):
			var b := _make("bird", at)
			b.phase = rng.next()
			return b
	var b := _make("bird", v.pos + Vector2(6, 0))
	b.gone = true
	return b

## По две курицы на курятник: поставил — появились, разобрал — ушли вместе с ним.
func sync_chickens(v: Village) -> void:
	var want := {}
	for k in v.built:
		if v.built[k] == "coop":
			want[k] = 2
	var keep: Array[Animal] = []
	for a in list:
		if a.kind == "chicken":
			if want.get(a.coop, 0) <= 0:
				continue
			want[a.coop] -= 1
		keep.append(a)
	list = keep
	for k in want:
		var p: PackedStringArray = k.split(":")
		var c := Vector2(int(p[0]), int(p[1])) + Vector2(0.5, 1.3)
		for i in want[k]:
			var a := _make("chicken", c + Vector2(-0.5 + i, 0.1))
			a.home = c
			a.coop = k
			list.append(a)


## Один шаг жизни. `delta` — секунды настоящего времени.
func step(delta: float, v: Village) -> void:
	var player_speed := v.pos.distance_to(_last_player) / maxf(delta, 0.0001)
	_last_player = v.pos
	_calm = _calm + delta if player_speed < 0.05 else 0.0
	for a in list:
		match a.kind:
			"hare":
				_hare(a, delta, v, player_speed)
			"chicken":
				_wander(a, delta, v, 2.0, 0.9, 1.5, 4.0)
			"bird":
				_bird_step(a, delta, v, player_speed)

func _hare(a: Animal, delta: float, v: Village, player_speed: float) -> void:
	var to_player := v.pos - a.pos
	var d := to_player.length()
	if a.tame:
		# Ручной — держится рядом, чуть позади; отстал — догоняет вприпрыжку.
		if d > 1.8:
			a.state = "follow"
			_go(a, v.pos - to_player.normalized() * 1.2, maxf(3.4, d * 1.6), delta, v, true)
			if d > 9.0:
				a.pos = v.pos - v.facing * 1.2
		else:
			_wander(a, delta, v, 1.0, 1.4, 0.8, 3.0, v.pos)
		return
	if a.state == "flee":
		a.wait -= delta
		_go(a, a.goal, 4.5, delta, v)
		if a.wait <= 0.0 or a.pos.distance_to(a.goal) < 0.1:
			a.state = "idle"
			a.wait = 1.0 + rng.next() * 2.0
		return
	if d < SCARE_DISTANCE and player_speed > SCARE_SPEED:
		a.state = "flee"
		a.wait = 1.0
		a.goal = _escape(v, a, -to_player.normalized())
		return
	if v.bag.get("carrot", 0) > 0 and d < 6.0 and _calm > CALM_TIME:
		# Тихо стоишь с морковкой — любопытство сильнее страха.
		a.state = "come"
		if d > 1.0:
			_go(a, v.pos - to_player.normalized() * 0.9, 1.3, delta, v)
		else:
			a.moving = false
			a.facing = to_player.normalized()
		return
	# Далеко ушёл от норы — возвращается.
	_wander(a, delta, v, 3.0, 1.3, 1.0, 3.5)

## Бродить вокруг дома: постоял, выбрал точку неподалёку, дошёл.
func _wander(a: Animal, delta: float, v: Village, radius: float, speed: float, wait_min: float, wait_max: float, center := Vector2.INF) -> void:
	var home := a.home if center == Vector2.INF else center
	if a.state != "walk":
		a.state = "idle"
		a.moving = false
		a.wait -= delta
		if a.wait <= 0.0:
			var ang := rng.next() * TAU
			var r := radius * (0.3 + rng.next() * 0.7)
			a.goal = _free_point(v, home + Vector2(cos(ang), sin(ang)) * r, a.pos)
			a.state = "walk"
		return
	if not _go(a, a.goal, speed, delta, v):
		a.state = "idle"
		a.wait = wait_min + rng.next() * (wait_max - wait_min)

## Шагнуть к точке. false — дошёл или упёрся.
func _go(a: Animal, goal: Vector2, speed: float, delta: float, v: Village, ghost := false) -> bool:
	var to := goal - a.pos
	if to.length() < 0.05:
		a.moving = false
		return false
	var stepv := to.limit_length(speed * delta)
	var next := a.pos + stepv
	if not ghost and v.blocks(v.tile_of(next)):
		a.moving = false
		return false
	a.pos = next
	a.facing = stepv.normalized()
	a.moving = true
	a.phase = fmod(a.phase + stepv.length() * 1.8, 1.0)
	return true

## Куда удрать: прочь от тебя, а если там лес или вода — вбок; первая дорога, где ничто
## не мешает бежать.
func _escape(v: Village, a: Animal, away: Vector2) -> Vector2:
	for turn in [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5]:
		var dir := away.rotated(turn)
		for dist in [3.5, 2.5, 1.5]:
			var clear := true
			var k := 0.25
			while k <= dist and clear:
				clear = not v.blocks(v.tile_of(a.pos + dir * k))
				k += 0.25
			if clear:
				return a.pos + dir * dist
	return a.pos

## Точка, куда можно встать: сама или, если она занята, та, откуда шли.
func _free_point(v: Village, p: Vector2, fallback: Vector2) -> Vector2:
	var c := v.tile_of(p)
	if v.inside(c) and not v.blocks(c):
		return Vector2(c) + Vector2(0.2 + rng.next() * 0.6, 0.2 + rng.next() * 0.6)
	return fallback

func _bird_step(a: Animal, delta: float, v: Village, player_speed: float) -> void:
	if a.gone:
		a.wait -= delta
		if a.wait <= 0.0:
			var b := _bird(v)
			a.pos = b.pos
			a.home = b.pos
			a.lift = 0.0
			a.gone = b.gone
			a.state = "idle"
			a.wait = 15.0 if a.gone else 0.0
		return
	if a.state == "fly":
		a.lift += delta * 3.0
		a.pos += a.facing * delta * 5.0
		a.phase = fmod(a.phase + delta * 6.0, 1.0)
		if a.lift > 6.0:
			a.gone = true
			a.wait = 12.0 + rng.next() * 12.0
		return
	var d := a.pos.distance_to(v.pos)
	if d < 2.2 or (d < 3.5 and player_speed > 2.5):
		a.state = "fly"
		a.facing = (a.pos - v.pos).normalized().rotated((rng.next() - 0.5) * 0.8)
		a.moving = true
		return
	# Клюёт: переступает на месте.
	a.moving = false
	a.wait -= delta
	if a.wait <= 0.0:
		a.wait = 0.8 + rng.next() * 2.0
		a.facing = Vector2(-a.facing.x, 0).normalized() if absf(a.facing.x) > 0.01 else Vector2.RIGHT
		a.phase = rng.next()
	# Далеко отстал от тебя — перелетит поближе, когда ты не видишь.
	if d > 14.0:
		a.gone = true
		a.wait = 3.0
