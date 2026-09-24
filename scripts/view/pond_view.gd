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
## Волны от рывков и ударов: {pos, t — сколько секунд идёт, power}. Расталкивают взвесь.
var _waves: Array = []
## Когда в поле зрения со дна поднимется новая стайка пузырьков.
var _bubbles_t := 1.0
## Рост: сколько секунд прошло с него (-1 — не растём) и каким был зум до него.
var _grow_t := -1.0
var _grow_from := 1.0


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
	var z := 2.3 * pow(16.0 / p.size_r, 0.85) / (1.0 + 0.06 * minf(p.eyes, 4.0))
	# Колосс рядом — камера отъезжает, чтобы он влез в кадр и было видно, какой он большой.
	var c := pond.colossus
	if c != null:
		var near := clampf(1.0 - (c.pos.distance_to(p.pos) - c.radius) / (view_radius_at(z) * 1.2), 0.0, 1.0)
		# Чем больше он для тебя, тем дальше отъезд (маленькому — почти вдвое).
		var k := clampf(c.radius / (p.radius * 8.0), 0.45, 1.1)
		z /= 1.0 + k * near
	return z

## Полдиагонали экрана в точках мира при таком зуме.
func view_radius_at(z: float) -> float:
	return (get_viewport_rect().size / z).length() / 2.0

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
	# Рост: камера на миг подаётся к клетке, потом рывком отъезжает — чуть дальше, чем
	# надо, — и мягко возвращается. Мир вокруг заметно «уменьшается».
	if _grow_t >= 0.0:
		_grow_t += delta
		if _grow_t < 0.35:
			z = lerpf(camera.zoom.x, _grow_from * 1.1, 1.0 - exp(-10.0 * delta))
		elif _grow_t < 1.9:
			z = lerpf(camera.zoom.x, target_zoom() * 0.86, 1.0 - exp(-3.5 * delta))
		elif _grow_t < 4.0:
			z = lerpf(camera.zoom.x, target_zoom(), 1.0 - exp(-1.2 * delta))
		else:
			_grow_t = -1.0
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
			f.pos.y -= f.get("rise", 18.0) * delta
			if f.has("wob"):
				f.pos.x += sin(t * 3.0 + f.wob) * 6.0 * delta / camera.zoom.x
	_fx = _fx.filter(func(f): return f.life > 0.0)
	for w in _waves:
		w.t += delta
	_waves = _waves.filter(func(w): return w.t < 1.2)
	# Со дна то тут, то там поднимаются цепочки пузырьков.
	_bubbles_t -= delta
	if _bubbles_t <= 0.0:
		_bubbles_t = randf_range(0.8, 2.2)
		var v := view_rect()
		var at := v.position + Vector2(randf(), randf()) * v.size
		var n := randi_range(3, 6)
		for i in n:
			_fx.append({"k": "bubble", "pos": at + Vector2(randf_range(-6, 6), i * 9.0) / z, "life": 1.6 + i * 0.15, "speed": 0.55,
				"r": randf_range(1.2, 2.6) / z * 2.0, "rise": 26.0 / z, "wob": randf() * TAU})
	queue_redraw()

## Тряхнуть камеру (0–1).
func shake(k: float) -> void:
	_shake = minf(1.0, _shake + k)

## Волна от точки: расталкивает взвесь в воде.
func wave(at: Vector2, power := 1.0) -> void:
	_waves.append({"pos": at, "t": 0.0, "power": power})


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
				if e.radius >= pond.player.radius * 0.7:
					wave(e.pos, 0.6)
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
				var me := pond.player
				_grow_t = 0.0
				_grow_from = camera.zoom.x
				# Линька: старая оболочка лопается кусками и тает позади.
				_fx.append({"k": "molt", "pos": me.pos, "r": e.get("old_r", me.size_r * 0.85), "heading": me.heading, "shape": me.shape,
					"col": me.color, "life": 1.0, "speed": 0.55})
				for i in 10:
					_fx.append({"k": "shard", "pos": me.pos + Vector2.from_angle(randf() * TAU) * me.radius * 0.8, "vel": Vector2.from_angle(randf() * TAU) * randf_range(40.0, 120.0),
						"life": 1.0, "speed": 0.9, "col": me.color.lightened(0.45), "r": me.radius * randf_range(0.08, 0.16), "rot": randf() * TAU})
				_ring(me.pos, me.radius * 4.0, Art.GREEN, 1.2)
				_ring(me.pos, me.radius * 7.0, Color(Art.GREEN, 0.5), 1.6)
				wave(me.pos, 2.2)
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
			"shot":
				_bits(e.pos, Color("#b8f070") if e.kind == "spit" else Color("#f0e6c8"), 3, 50.0)
			"shot_hit":
				_bits(e.pos, Color("#b8f070") if e.kind == "spit" else Color("#f0e6c8"), 6, 80.0)
			"split":
				_ring(e.pos, 50.0, e.color, 0.5)
				_bits(e.pos, e.color, 12, 120.0)
			"ambush":
				_ring(e.pos, 60.0, Art.DANGER, 0.5)
			"remora_on", "remora_off":
				_ring(e.pos, pond.player.radius * 2.0, Color("#dfe6ee"), 0.5)
			"wave":
				_ring(pond.arena_center, pond.arena_radius, Art.GOLD, 1.2)
			"dash":
				wave(e.pos, 1.0)
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

## Замер рисования (читает main при --profile): часть → мкс за кадр.
var prof := {}
var _pt := 0

func _mark(name: String) -> void:
	var now := Time.get_ticks_usec()
	prof[name] = prof.get(name, 0) + now - _pt
	_pt = now

func _draw() -> void:
	if pond == null:
		return
	_pt = Time.get_ticks_usec()
	var view := view_rect()
	_water(view)
	_mark("вода")
	_currents(view)
	_mark("течения")
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
	_mark("логова, круги, еда")
	for cap in pond.capsules:
		if near.has_point(cap.pos):
			CellArt.capsule(self, cap, t, pond.evo.unlocked.has(cap.part))
	for k in pond.rocks:
		if view.grow(k.r * 2.0).has_point(k.pos):
			CellArt.rock(self, k, t)
	_mark("находки, камни")
	for m in pond.mobs:
		if view.grow(m.radius * 3.0).has_point(m.pos):
			# Обманка, пока ждёт, выглядит водорослью; с двумя глазами её видно.
			if m.behavior() == "ambush" and m.revealed_t <= 0.0 and pond.player.eyes < 2.0:
				CellArt.plant(self, {"pos": m.pos, "r": m.radius * 0.95, "v": m.uid}, t)
				continue
			_creature(m)
	for s in pond.shots:
		var dir: Vector2 = s.vel.normalized()
		if s.kind == "spit":
			draw_circle(s.pos, s.r * 1.6, Color(0.7, 0.95, 0.4, 0.25))
			draw_circle(s.pos, s.r, Color("#b8f070"))
		else:
			draw_line(s.pos - dir * s.r * 3.0, s.pos + dir * s.r, Color("#f0e6c8"), s.r * 0.7)
	_mark("существа")
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
	_mark("ты и свита")
	_draw_fx()
	_mark("эффекты")

func _creature(c: Creature) -> void:
	var ghost := 1.0 if c.is_player else clampf(c.age / 0.6, 0.0, 1.0)
	if c.invisible:
		# Невидимка: без глаз — лишь дрожание воды, с глазами — всё лучше.
		ghost *= clampf(0.08 + pond.player.eyes * 0.3, 0.08, 1.0)
	if c.hidden_t > 0.0:
		ghost *= 0.35
	var pattern := c.pattern
	var col2 := c.color2
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
		"simple": not c.is_player and not c.ally and c.size_r * camera.zoom.x < 24.0,
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
	# Пылинки воды: два слоя с разной глубиной. Каждый слой — одна команда рисования
	# (короткие толстые штрихи вместо кружков): кружков были сотни, и на телефоне лагало.
	var z := camera.zoom.x
	var me := pond.player
	var reach := me.radius * 4.5
	var col := Color(0.75, 0.9, 1.0)
	var glow := 1.0
	# Цветение: взвесь — светящийся планктон; мёртвая зона — почти ничего.
	if pond.event_look == "bloom":
		col = col.lerp(Color(0.6, 1.0, 0.55), pond.event_k)
		glow = 1.0 + 1.6 * pond.event_k
	elif pond.event_look == "dead":
		glow = 1.0 - 0.7 * pond.event_k
	# Буря: взвесь несётся по ветру.
	var storm := pond.storm_dir * pond.event_k if pond.event_look == "storm" else Vector2.ZERO
	for layer in [[0.45, 110.0, 0.10, 1.2], [0.75, 150.0, 0.16, 1.8]]:
		var k: float = layer[0]
		var cell: float = layer[1] / z
		var shift := view.get_center() * (1.0 - k)
		var area := Rect2(view.position - shift, view.size)
		var x0 := floori(area.position.x / cell)
		var y0 := floori(area.position.y / cell)
		var x1 := floori(area.end.x / cell)
		var y1 := floori(area.end.y / cell)
		var w := float(layer[3]) * 2.2 / z
		var near := k > 0.5
		var pts := PackedVector2Array()
		for gy in range(y0, y1 + 1):
			for gx in range(x0, x1 + 1):
				var h := _hash(gx, gy, int(k * 100.0))
				var at := Vector2(gx + (h & 255) / 255.0, gy + ((h >> 8) & 255) / 255.0) * cell + shift
				at += Vector2(sin(t * 0.3 + h), cos(t * 0.25 + h * 0.5)) * 6.0 / z
				if storm != Vector2.ZERO:
					at += storm * (fposmod(t * 90.0 * k / z + float(h % 997), cell) - cell * 0.5)
				# Ближний слой живой: клетка расталкивает взвесь и закручивает её за собой,
				# волна от рывка отбрасывает её кольцом.
				if near:
					at += _stir(at, me.pos, me.vel, reach)
				var len := w * (1.0 + ((h >> 16) & 3) * 0.4)
				var along := Vector2(1, 0)
				if storm != Vector2.ZERO:
					# В бурю пылинки вытягиваются чёрточками по ветру.
					along = Vector2(1, 0).lerp(storm.normalized(), storm.length())
					len *= 1.0 + 3.0 * storm.length()
				pts.append(at - along * len * 0.5)
				pts.append(at + along * len * 0.5)
		if not pts.is_empty():
			draw_multiline(pts, Color(col, minf(1.0, float(layer[2]) * glow)), w)

## Насколько сдвинуть пылинку в точке at: клетка рядом и волны от рывков.
func _stir(at: Vector2, center: Vector2, vel: Vector2, reach: float) -> Vector2:
	var out := Vector2.ZERO
	var d := at - center
	var dist2 := d.length_squared()
	if dist2 < reach * reach and dist2 > 1.0:
		var dist := sqrt(dist2)
		var f := 1.0 - dist / reach
		var dir := d / dist
		# Расступается перед клеткой и закручивается по бокам — в сторону хода.
		out += dir * f * f * reach * 0.35
		var side := signf(vel.cross(d))
		out += dir.orthogonal() * side * f * minf(vel.length(), 240.0) * 0.18
	for wv in _waves:
		var r: float = wv.t * 520.0 / camera.zoom.x
		var dd: Vector2 = at - wv.pos
		var l := dd.length()
		var band := 1.0 - absf(l - r) / (60.0 / camera.zoom.x)
		if band > 0.0 and l > 1.0:
			out += dd / l * band * (1.0 - wv.t / 1.2) * 26.0 * float(wv.power) / camera.zoom.x
	return out

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
				draw_arc(f.pos, f.r, 0, TAU, 8, Color(0.8, 0.95, 1.0, 0.5 * a), maxf(1.0, 1.2 / camera.zoom.x), true)
			"ring":
				draw_arc(f.pos, f.r * (1.0 - a * 0.7), 0, TAU, 40, Color(f.col, a * 0.8), 3.0, true)
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
			"molt":
				_molt(f, a)
			"heart":
				Art.heart(self, f.pos, f.r, Color(0.95, 0.5, 0.7, a))
			"text":
				var size := int(22.0 / camera.zoom.x)
				var w := _font.get_string_size(f.s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
				draw_string_outline(_font, f.pos - Vector2(w / 2.0, 0), f.s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(2, int(4.0 / camera.zoom.x)), Color(0, 0, 0, 0.6 * a))
				draw_string(_font, f.pos - Vector2(w / 2.0, 0), f.s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(f.col, a))

## Сброшенная оболочка: сначала светится вокруг клетки, потом трескается на куски, они
## расходятся, поворачиваются и тают.
func _molt(f: Dictionary, a: float) -> void:
	var q := 1.0 - a  # 0 → 1 за время жизни
	var r: float = f.r
	var col: Color = f.col.lightened(0.5)
	if q < 0.3:
		draw_circle(f.pos, r * (1.2 + q), Color(1.0, 1.0, 0.9, 0.25 * (1.0 - q / 0.3)))
	var pieces := 7
	var crack := 0.0 if q < 0.18 else minf(1.0, (q - 0.18) / 0.5)
	var w := maxf(2.5, r * 0.2)
	for i in pieces:
		var a0 := TAU * i / pieces + 0.05 * crack
		var a1 := TAU * (i + 1) / pieces - 0.05 * crack
		var mid := (a0 + a1) / 2.0
		var out := Vector2.from_angle(f.heading + mid) * r * 1.8 * (1.0 - pow(1.0 - crack, 2.0))
		var spin := (0.4 if i % 2 == 0 else -0.4) * crack
		var pts := PackedVector2Array()
		for j in 7:
			var th := lerpf(a0, a1, j / 6.0)
			var rr := r * (1.0 + 0.12 * q) * Content.shape_at(f.shape, th)
			pts.append(f.pos + out + Vector2.from_angle(f.heading + th + spin) * rr)
		draw_polyline(pts, Color(f.col.darkened(0.35), 0.8 * a), w * 1.35, true)
		draw_polyline(pts, Color(col, 0.9 * a), w, true)

## Течения — бегущие штрихи вдоль потока.
func _currents(view: Rect2) -> void:
	# Все штрихи течений — одной командой: по отдельности их сотни, и телефон лагал.
	var z := camera.zoom.x
	var cell := 70.0 / z
	var storm_k := pond.event_k if pond.event_look == "storm" else 0.0
	var x0 := floori(view.position.x / cell)
	var y0 := floori(view.position.y / cell)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
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
			pts.append(a)
			pts.append(a + dir * cell * (0.35 + 0.3 * storm_k))
			cols.append(Color(0.8, 0.95, 1.0, (0.18 + 0.12 * storm_k) * minf(1.0, sp / 60.0) * sin(PI * k)))
	if not pts.is_empty():
		draw_multiline_colors(pts, cols, 2.0 / z)


