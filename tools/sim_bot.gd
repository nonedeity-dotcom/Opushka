## Бот для проверки баланса: играет сам, без экрана, и пишет, когда вырос, сколько раз
## погиб, что нашёл. godot --headless -s tools/sim_bot.gd -- --minutes=40 --seed=1 --diet=meat
extends SceneTree

var evo: Evolution
var pond: Pond
var diet_goal := "plant"

func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var minutes := float(args.get("minutes", "30"))
	diet_goal = args.get("diet", "plant")
	evo = Evolution.create()
	pond = Pond.new(evo, int(args.get("seed", "1")))
	pond.view_radius = 480.0
	pond.fill()
	var dt := 1.0 / 30.0
	var t := 0.0
	var next_edit := 0.0
	var report := 60.0
	var levels := {}
	while t < minutes * 60.0:
		var dash := false
		var steer := _steer()
		if steer.length() > 1.5:
			dash = true
			steer = steer.normalized()
		pond.view_radius = 400.0 * pow(pond.player.radius / 16.0, 0.85) * 1.2
		pond.step(dt, steer, dash)
		for e in pond.events:
			if e.t == "levelup":
				levels[e.level] = t
				print("%5.1f мин: размер %d (смертей %d, побед %d, частей %d)" % [t / 60.0, e.level, evo.stats.get("deaths", 0), evo.stats.get("kills", 0), evo.unlocked.size()])
			elif e.t == "pickup" and e.new:
				print("%5.1f мин: новая часть %s" % [t / 60.0, e.part])
			elif e.t == "death":
				print("%5.1f мин: погиб" % [t / 60.0])
		if t >= next_edit:
			next_edit = t + 20.0
			_edit()
		t += dt
		if t >= report:
			report += 300.0
	print("Итог за %d мин: размер %d, ДНК %d, смертей %d, побед %d, частей %d/%d, уровни частей %s" % [minutes, evo.level(), evo.dna_total, evo.stats.get("deaths", 0), evo.stats.get("kills", 0), evo.unlocked.size(), Content.PARTS.size(), evo.unlocked])
	print("съедено водорослей %d, мяса %d; тело: %s" % [evo.stats.get("plants", 0), evo.stats.get("meat", 0), evo.body.map(func(p): return "%s@%d" % [p.id, p.a])])
	quit()

## Куда плыть: убегать от опасных, иначе к еде или добыче. Длина > 1.5 — «рывок».
func _steer() -> Vector2:
	var p := pond.player
	var danger := Vector2.ZERO
	for m in pond.mobs:
		if pond._hunts(m) and m.radius > p.radius * 0.85 and m.pos.distance_to(p.pos) < 200.0:
			danger += (p.pos - m.pos).normalized()
	if danger != Vector2.ZERO:
		return danger.normalized()
	var carnivore := p.eats("meat")
	# Добыча: мельче себя. Хищник гоняется всегда, травоядный — если есть чем бить или ради частей.
	var prey: Creature = null
	var best := 350.0
	for m in pond.mobs:
		if m.radius < p.radius * 0.9 and Content.SPECIES[m.species].behavior != "boss":
			var d := m.pos.distance_to(p.pos)
			if d < best and (carnivore or m.species in ["zelenka", "kolyuchka", "zhivchik", "kusaka", "glazun", "pantsirnik"]):
				best = d
				prey = m
	# Сначала подобрать выпавшее.
	for cap in pond.capsules:
		if cap.pos.distance_to(p.pos) < 500.0:
			return (cap.pos - p.pos).normalized()
	if prey != null and (carnivore or randf() < 0.9):
		var to := prey.pos - p.pos
		if to.length() < p.radius * 3.5 and p.dash_cd <= 0.0:
			return to.normalized() * 2.0
		return to.normalized()
	var f := pond._nearest_food(p, 600.0)
	if not f.is_empty():
		return (f.pos - p.pos).normalized()
	return Vector2.from_angle(pond.time * 0.1)

## Жадная сборка тела: рот по выбранной диете, потом всё полезное, на что хватает.
func _edit() -> void:
	var want_mouth := "filter"
	if diet_goal == "meat":
		for m in ["fangs", "jaws", "proboscis"]:
			if evo.unlocked.has(m):
				want_mouth = m
				break
	elif diet_goal == "both" and evo.unlocked.has("proboscis"):
		want_mouth = "proboscis"
	if evo.mouth() != want_mouth:
		evo.place(want_mouth, 0)
	var order := ["flagellum2", "flagellum", "spike2", "spike", "shell", "membrane", "electro", "poison", "chloroplast", "eye", "cilia"]
	var angles := [180, 90, -90, 135, -135, 45, -45, 60, -60, 150, -150, 30, -30, 120, -120, 105, -105, 165, -165, 75, -75]
	for id in order:
		if not evo.unlocked.has(id):
			continue
		for a in angles:
			if evo.body.size() >= evo.slots():
				break
			if evo.can_place(id, a).ok and evo.body.filter(func(p): return p.id == id).size() < 2:
				evo.place(id, a)
	pond.player.sync_player(evo)
