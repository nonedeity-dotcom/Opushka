## Океан на экране: вода, еда, находки, клетки и короткие эффекты.
##
## Всё рисуется одним узлом за один проход — клеток и крупинок много, а отдельный узел на
## каждую крупинку телефону дороже. Рисуется только то, что попадает в экран.
extends Node2D

var pond: Pond
var camera: Camera2D
var t := 0.0
var _fx: Array = []  # {k: bit/ring/zap/text/bubble, ...}
var _shake := 0.0
var _trail := 0.0
var _font: Font


func setup(p: Pond) -> void:
	pond = p
	_font = ThemeDB.fallback_font
	if camera == null:
		camera = Camera2D.new()
		add_child(camera)
	camera.position = p.player.pos
	camera.zoom = Vector2.ONE * target_zoom()
	camera.reset_smoothing()

## Чем больше клетка, тем дальше камера: ты на экране почти одного размера, а мир растёт.
## Глазки отодвигают ещё немного.
func target_zoom() -> float:
	var p := pond.player
	return 2.3 * pow(16.0 / p.size_r, 0.85) / (1.0 + 0.06 * minf(p.eyes, 4.0))

func view_rect() -> Rect2:
	var size := get_viewport_rect().size / camera.zoom
	return Rect2(camera.get_screen_center_position() - size / 2.0, size)

## Полдиагонали экрана в точках мира — океан наполняется за этим краем.
func view_radius() -> float:
	return (get_viewport_rect().size / camera.zoom).length() / 2.0

func _process(delta: float) -> void:
	if pond == null:
		return
	t += delta
	var z := lerpf(camera.zoom.x, target_zoom(), 1.0 - exp(-2.0 * delta))
	camera.zoom = Vector2(z, z)
	var p := pond.player
	camera.position = camera.position.lerp(p.pos, 1.0 - exp(-8.0 * delta))
	_shake = maxf(0.0, _shake - delta * 3.0)
	camera.offset = Vector2(randf() - 0.5, randf() - 0.5) * 10.0 * _shake / z
	# След из пузырьков, когда плывёшь быстро.
	_trail -= delta
	if p.vel.length() > p.speed * 0.7 and _trail <= 0.0:
		_trail = 0.12
		_fx.append({"k": "bubble", "pos": p.pos - p.heading_vec() * p.radius + Vector2(randf() - 0.5, randf() - 0.5) * p.radius * 0.6, "life": 1.0, "r": randf_range(1.5, 3.5) * p.size_k()})
	for f in _fx:
		f.life -= delta * f.get("speed", 1.0)
		if f.has("vel"):
			f.pos += f.vel * delta
			f.vel *= 1.0 - 2.5 * delta
		if f.k == "bubble":
			f.pos.y -= 18.0 * delta
	_fx = _fx.filter(func(f): return f.life > 0.0)
	queue_redraw()


# --- события → эффекты ----------------------------------------------------------------

func effects(events: Array) -> void:
	for e in events:
		match e.t:
			"eat":
				_bits(e.pos, Art.PLANT if e.kind == "plant" else Art.MEAT, 5, 40.0)
				_text(e.pos, "+%s" % _num(e.dna), Color("#a8f0c0"))
			"hit":
				var col := Color("#fff0d0") if e.kind == "ram" else (Color("#f0e0a0") if e.kind == "spike" else Color("#f07070"))
				_bits(e.pos, col, 7 if not e.blocked else 3, 90.0)
				if e.blocked:
					_ring(e.pos, 10.0, Color("#e0d2b0"), 0.35)
				if e.to_player:
					_shake = minf(1.0, _shake + 0.5)
			"kill":
				# Погибшая клетка не исчезает сразу: съёживается и тает.
				_fx.append({"k": "corpse", "who": e.who, "life": 1.0, "speed": 1.8})
				_bits(e.pos, e.color, 14, 120.0)
				if e.get("golden", false):
					_bits(e.pos, Art.GOLD, 24, 160.0)
					_ring(e.pos, e.radius * 3.0, Art.GOLD, 1.0)
				for i in 8:
					_fx.append({"k": "bubble", "pos": e.pos + Vector2(randf() - 0.5, randf() - 0.5) * e.radius, "life": 1.3, "r": randf_range(2.0, 5.0)})
				_ring(e.pos, e.radius * 1.6, Color(1, 1, 1, 0.8), 0.5)
				if e.by_player and e.has("dna"):
					_text(e.pos + Vector2(0, -e.radius), "+%s" % _num(e.dna), Art.GOLD)
			"drop":
				_ring(e.pos, 30.0, Art.GOLD, 0.8)
			"pickup":
				_ring(e.pos, 40.0, Art.GOLD, 0.7)
				_bits(e.pos, Art.GOLD, 12, 110.0)
				# Находка влетает в клетку.
				_fx.append({"k": "fly", "from": e.pos, "part": e.part, "life": 1.0, "speed": 2.5})
			"levelup":
				_ring(pond.player.pos, pond.player.radius * 4.0, Art.GREEN, 1.2)
				_ring(pond.player.pos, pond.player.radius * 2.5, Color.WHITE, 0.9)
			"zap":
				_fx.append({"k": "zap", "from": e.from, "to": e.to, "life": 0.25, "speed": 1.0})
			"poison":
				_bits(e.pos, Color("#8fe070"), 8, 60.0)
			"death":
				_bits(e.pos, Color("#f07070"), 20, 150.0)
				_shake = 1.0
			"rock_hit":
				_bits(e.pos, Color(Content.ROCKS[e.rock].color).lightened(0.3), 6, 110.0)
				_shake = minf(1.0, _shake + 0.15)
			"rock_break":
				var col := Color(Content.ROCKS[e.rock].color)
				for i in 10:
					_fx.append({"k": "shard", "pos": e.pos, "vel": Vector2.from_angle(randf() * TAU) * randf_range(60.0, 180.0), "life": 1.0, "speed": 1.2, "col": col, "r": e.r * randf_range(0.15, 0.3), "rot": randf() * TAU})
				_ring(e.pos, e.r * 2.0, Color(1, 1, 1, 0.7), 0.5)
				_text(e.pos + Vector2(0, -e.r), "+%s" % _num(e.dna), Color("#a8f0c0"))
				_shake = minf(1.0, _shake + 0.4)
			"mate_called":
				_ring(pond.player.pos, pond.player.radius * 3.0, Color("#f07aa8"), 0.8)
			"mated":
				for i in 10:
					_fx.append({"k": "heart", "pos": e.pos + Vector2(randf() - 0.5, randf() - 0.5) * 30.0, "vel": Vector2(randf_range(-30, 30), randf_range(-90, -40)), "life": 1.0, "speed": 0.7, "r": randf_range(6.0, 12.0)})
				_ring(e.pos, pond.player.radius * 4.0, Color("#f07aa8"), 1.0)
			"ally_lost":
				_fx.append({"k": "corpse", "who": e.who, "life": 1.0, "speed": 1.8})
				_bits(e.pos, e.color, 10, 100.0)
			"parasite":
				_bits(e.pos, Color("#8a5a6a"), 6, 60.0)
			"shaken":
				_ring(e.pos, pond.player.radius * 2.5, Color("#e89aa8"), 0.5)
			"ability":
				match e.ability:
					"ink":
						for i in 14:
							_fx.append({"k": "ink", "pos": e.pos + Vector2(randf() - 0.5, randf() - 0.5) * e.r * 3.0, "vel": Vector2.from_angle(randf() * TAU) * randf_range(10.0, 50.0), "life": 1.0, "speed": 0.35, "r": e.r * randf_range(0.8, 1.6)})
					"pulse":
						_ring(e.pos, e.r * 4.0, Color("#f2e05a"), 0.5)
						_ring(e.pos, e.r * 2.5, Color.WHITE, 0.3)
					"suck":
						_ring(e.pos, e.r * 9.0, Color("#8fe0d0"), 0.8)
					"shield":
						_ring(e.pos, e.r * 1.6, Color("#8ac8ff"), 0.4)
			"boss_phase":
				_ring(e.pos, 200.0, Color("#c080ff"), 1.0)
				_shake = 1.0
			"boss_charge":
				# Предупреждение: круг удара наливается красным за секунду до волны.
				_fx.append({"k": "charge", "who": e.who, "r": e.r, "life": 1.0, "speed": 1.0})
			"boss_wave":
				_ring(e.pos, e.r, Color("#ff9070"), 0.6)
				_shake = minf(1.0, _shake + 0.5)
			"wave":
				_ring(pond.arena_center, pond.arena_radius, Art.GOLD, 1.2)
			"dash":
				for i in 5:
					_fx.append({"k": "bubble", "pos": e.pos + Vector2(randf() - 0.5, randf() - 0.5) * 20.0, "life": 0.9, "r": randf_range(2.0, 4.0)})

static func _num(x: float) -> String:
	return str(int(round(x))) if absf(x - round(x)) < 0.05 or x >= 10.0 else "%.1f" % x

func _bits(at: Vector2, col: Color, n: int, spd: float) -> void:
	for i in n:
		_fx.append({"k": "bit", "pos": at, "vel": Vector2.from_angle(randf() * TAU) * randf_range(0.3, 1.0) * spd, "life": 1.0, "speed": 1.8, "col": col, "r": randf_range(1.5, 3.0)})

func _ring(at: Vector2, r: float, col: Color, dur: float) -> void:
	_fx.append({"k": "ring", "pos": at, "r": r, "col": col, "life": 1.0, "speed": 1.0 / dur})

func _text(at: Vector2, s: String, col: Color) -> void:
	_fx.append({"k": "text", "pos": at, "vel": Vector2(0, -40), "s": s, "col": col, "life": 1.0, "speed": 1.1})


# --- рисование ------------------------------------------------------------------------

func _draw() -> void:
	if pond == null:
		return
	var view := view_rect()
	_water(view)
	_currents(view)
	for l in pond.lairs_near(view.size.length()):
		_lair(l)
	var near := view.grow(30.0)
	for col in pond.colonies:
		if view.grow(col.r * 1.5).has_point(col.pos):
			CellArt.colony(self, col, t)
	for f in pond.food:
		if near.has_point(f.pos):
			if f.kind == "plant":
				CellArt.plant(self, f, t)
			else:
				CellArt.meat(self, f, t)
	for cap in pond.capsules:
		if near.has_point(cap.pos):
			CellArt.capsule(self, cap, t, pond.evo.unlocked.has(cap.part))
	for k in pond.rocks:
		if view.grow(k.r * 2.0).has_point(k.pos):
			CellArt.rock(self, k, t)
	for m in pond.mobs:
		if view.grow(m.radius * 3.0).has_point(m.pos):
			_creature(m)
	if pond.mate != null and view.grow(pond.mate.radius * 3.0).has_point(pond.mate.pos):
		CellArt.mate(self, pond.mate, t)
	for a in pond.allies:
		_creature(a)
		draw_arc(a.pos, a.radius * 1.3, 0, TAU, 20, Color(1, 1, 1, 0.25), 1.5, true)
	if pond.mode == "arena":
		draw_arc(pond.arena_center, pond.arena_radius, 0, TAU, 96, Color(1.0, 0.85, 0.5, 0.5), 6.0, true)
	var p := pond.player
	draw_circle(p.pos, p.radius * 1.6, Color(1, 1, 1, 0.05))
	if p.shield_t > 0.0:
		draw_circle(p.pos, p.radius * 1.5, Color(0.55, 0.8, 1.0, 0.18))
		draw_arc(p.pos, p.radius * 1.5, 0, TAU, 40, Color(0.7, 0.9, 1.0, 0.7), 3.0, true)
	if p.invuln > 0.0:
		draw_arc(p.pos, p.radius * 1.35, 0, TAU, 32, Color(1, 1, 1, 0.3 + 0.3 * sin(t * 12.0)), 2.0, true)
	_creature(p)
	_draw_fx()

func _creature(c: Creature) -> void:
	var ghost := 1.0 if c.is_player else clampf(c.age / 0.6, 0.0, 1.0)
	if c.invisible:
		# Невидимка: без глаз — лишь дрожание воды, с глазами — всё лучше.
		ghost *= clampf(0.08 + pond.player.eyes * 0.3, 0.08, 1.0)
	if c.hidden_t > 0.0:
		ghost *= 0.35
	var pattern := "none"
	var col2 := c.color
	if c.is_player or c.ally:
		pattern = pond.evo.pattern
		col2 = Color(Content.COLORS[pond.evo.color2])
	CellArt.creature(self, c.pos, c.size_r, c.heading, c.color, c.parts, c.phase, {
		"pattern": pattern, "color2": col2,
		"flash": c.flash, "bite": c.bite_anim, "poisoned": c.poison_t > 0.0, "wobble": c.wobble,
		"shape": c.shape, "golden": c.golden, "gulp": c.eat_anim, "grow": c.grow_anim,
		"stretch": clampf(c.vel.length() / maxf(c.speed, 1.0), 0.0, 1.6),
		# Новая клетка проявляется из мути, а не возникает разом.
		"ghost": ghost,
	})
	if c.invisible and ghost < 0.5:
		draw_arc(c.pos, c.radius * (1.0 + 0.05 * sin(t * 5.0)), 0, TAU, 24, Color(0.8, 0.9, 1.0, 0.12), 1.5, true)
	if c.slow_t > 0.0:
		draw_arc(c.pos, c.radius * 1.15, 0, TAU, 24, Color(0.9, 0.5, 0.8, 0.5), 2.0, true)
	if not c.is_player and c.hp < c.max_hp - 0.01:
		var w := maxf(c.radius * 1.6, 18.0)
		var at := c.pos + Vector2(-w / 2.0, -c.radius - 10.0)
		draw_rect(Rect2(at, Vector2(w, 4)), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(at, Vector2(w * c.hp / c.max_hp, 4)), Color("#8fe0a0") if c.ally else (Art.DANGER if pond._hunts(c) else Color("#e8e0c0")))

## Вода: два слоя пылинок с разной глубиной — ближние плывут быстрее дальних.
func _water(view: Rect2) -> void:
	var z := camera.zoom.x
	for layer in [[0.45, 110.0, 0.10, 1.2], [0.75, 150.0, 0.16, 1.8]]:
		var k: float = layer[0]
		var cell: float = layer[1] / z
		var shift := view.get_center() * (1.0 - k)
		var area := Rect2(view.position - shift, view.size)
		var x0 := floori(area.position.x / cell)
		var y0 := floori(area.position.y / cell)
		var x1 := floori(area.end.x / cell)
		var y1 := floori(area.end.y / cell)
		for gy in range(y0, y1 + 1):
			for gx in range(x0, x1 + 1):
				var h := _hash(gx, gy, int(k * 100.0))
				var p := Vector2(gx + (h & 255) / 255.0, gy + ((h >> 8) & 255) / 255.0) * cell + shift
				var drift := Vector2(sin(t * 0.3 + h), cos(t * 0.25 + h * 0.5)) * 6.0 / z
				draw_circle(p + drift, float(layer[3]) / z * (1.0 + ((h >> 16) & 3) * 0.4), Color(0.75, 0.9, 1.0, float(layer[2])))

static func _hash(x: int, y: int, s: int) -> int:
	var h := (x * 374761393 + y * 668265263 + s * 2246822519) & 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
	return h ^ (h >> 16)

func _draw_fx() -> void:
	for f in _fx:
		var a: float = clampf(f.life, 0.0, 1.0)
		match f.k:
			"bit":
				draw_circle(f.pos, f.r, Color(f.col, a))
			"bubble":
				draw_arc(f.pos, f.r, 0, TAU, 10, Color(0.8, 0.95, 1.0, 0.5 * a), 1.0, true)
			"ring":
				draw_arc(f.pos, f.r * (1.0 - a * 0.7), 0, TAU, 40, Color(f.col, a * 0.8), 3.0, true)
			"charge":
				var boss: Creature = f.who
				var k := 1.0 - a
				draw_circle(boss.pos, f.r, Color(1.0, 0.35, 0.25, 0.08 + 0.14 * k))
				draw_arc(boss.pos, f.r, 0, TAU, 64, Color(1.0, 0.45, 0.3, 0.4 + 0.5 * k), 3.0 + 3.0 * k, true)
			"zap":
				var pts := PackedVector2Array([f.from])
				for i in range(1, 6):
					var q: Vector2 = f.from.lerp(f.to, i / 6.0)
					pts.append(q + Vector2(randf() - 0.5, randf() - 0.5) * 14.0)
				pts.append(f.to)
				draw_polyline(pts, Color(1.0, 0.95, 0.5, a), 3.0, true)
				draw_polyline(pts, Color(1, 1, 1, a), 1.2, true)
			"corpse":
				var who: Creature = f.who
				var k := a * a
				CellArt.creature(self, who.pos, who.size_r * (0.4 + 0.6 * k), who.heading + (1.0 - a) * 0.8, who.color, who.parts, t, {
					"shape": who.shape, "ghost": a, "flash": 1.0 - a, "shadow": false})
			"fly":
				var to := pond.player.pos
				var q: float = 1.0 - a
				var at: Vector2 = f.from.lerp(to, q * q) + Vector2(0, -40.0 * sin(PI * q))
				var sz := 26.0 * (1.0 - q * 0.6)
				CellArt.part_icon(self, f.part, Rect2(at - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), Color("#c0c8d0"), t)
			"shard":
				var s := f.r as float
				var rot: float = f.rot + (1.0 - a) * 4.0
				var pts := PackedVector2Array()
				for i in 4:
					pts.append(f.pos + Vector2.from_angle(rot + i * 1.7) * s * (0.6 + 0.4 * (i % 2)))
				draw_colored_polygon(pts, Color(f.col, a))
			"ink":
				draw_circle(f.pos, f.r * (1.5 - a * 0.5), Color(0.12, 0.08, 0.2, 0.55 * a))
			"heart":
				Art.heart(self, f.pos, f.r, Color(0.95, 0.5, 0.7, a))
			"text":
				var size := int(22.0 / camera.zoom.x)
				var w := _font.get_string_size(f.s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
				draw_string_outline(_font, f.pos - Vector2(w / 2.0, 0), f.s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(2, int(4.0 / camera.zoom.x)), Color(0, 0, 0, 0.6 * a))
				draw_string(_font, f.pos - Vector2(w / 2.0, 0), f.s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(f.col, a))

## Течения — бегущие штрихи вдоль потока.
func _currents(view: Rect2) -> void:
	var z := camera.zoom.x
	var cell := 70.0 / z
	var x0 := floori(view.position.x / cell)
	var y0 := floori(view.position.y / cell)
	for gy in range(y0, floori(view.end.y / cell) + 1):
		for gx in range(x0, floori(view.end.x / cell) + 1):
			var p := Vector2(gx + 0.5, gy + 0.5) * cell
			var f := pond.current_at(p)
			var sp := f.length()
			if sp < 8.0:
				continue
			var dir := f / sp
			var k := fposmod(t * sp / cell + float(_hash(gx, gy, 3) % 100) / 100.0, 1.0)
			var a := p + dir * (k - 0.5) * cell
			draw_line(a, a + dir * cell * 0.35, Color(0.8, 0.95, 1.0, 0.18 * minf(1.0, sp / 60.0) * sin(PI * k)), 2.0 / z, true)

## Логово: тёмное пятно со светящимся кругом; пустое — если хозяина уже победили.
func _lair(l: Dictionary) -> void:
	var r := 220.0
	draw_circle(l.pos, r, Color(0.05, 0.02, 0.08, 0.35))
	var col := Color(0.6, 0.4, 0.9, 0.25 if l.done else 0.55)
	draw_arc(l.pos, r, 0, TAU, 64, col, 4.0, true)
	for i in 8:
		var a := TAU * i / 8.0 + t * 0.1
		draw_line(l.pos + Vector2.from_angle(a) * r * 0.9, l.pos + Vector2.from_angle(a) * r * 1.08, col, 3.0, true)

