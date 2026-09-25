## Части тела для суши. Тело на суше — не россыпь частей по краю, как у клетки, а места:
## рот, глаза, ноги, ступни, когти, руки, спина, хвост, голова, кожа. В каждом месте —
## одна часть или ничего. Так тело легко собрать пальцем и понятно, что за что отвечает.
##
## ДНК — та же, что в океане: у суши своё тело, и платишь за его части из общей ДНК.
## Поэтому части клетки, не нужные на суше (жгутик, реснички…), просто не переходят —
## и ДНК за них освобождается.
##
## Числа частей:
##   bite — прибавка к укусу; speed — множитель скорости; hp — прибавка к здоровью;
##   armor — какую долю укуса по тебе снимает; thorns — какую долю укуса возвращает
##   кусачему; poison — яд в секунду тому, кто тебя укусил (3 с); regen — лечение в
##   секунду; sight — зрение (1 — обычное): дальше видно, реже туман; fruit, meat —
##   множитель ДНК с плодов и с мяса и яиц; bone — во сколько раз сильнее бьёшь кости;
##   reach — насколько дальше достаёшь; stealth — во сколько раз ближе тебя замечают;
##   wade — можно заходить в воду по брюхо; legs — сколько ног.
class_name LandParts
extends RefCounted

const SLOTS := [
	["mouth", "Рот", "bite"],
	["eyes", "Глаза", "eye"],
	["legs", "Ноги", "dash"],
	["feet", "Ступни", "leaf"],
	["claws", "Когти", "skull"],
	["arms", "Руки", "suck"],
	["back", "Спина", "shield"],
	["tail", "Хвост", "pulse"],
	["head", "Голова", "trophy"],
	["skin", "Кожа", "ink"],
]

const PARTS := {
	# Рот.
	"beak": {"slot": "mouth", "name": "Клюв", "cost": 10, "bite": 3.0, "fruit": 2.0, "meat": 0.6,
		"hint": "Травоядный: с плодов вдвое больше ДНК, кусает слабо"},
	"jaws": {"name": "Челюсти", "slot": "mouth", "cost": 16, "bite": 6.0, "fruit": 0.7, "meat": 1.3,
		"hint": "Хищный рот: кусает и ест мясо и яйца"},
	"fangs": {"name": "Клыки", "slot": "mouth", "cost": 36, "bite": 10.0, "fruit": 0.6, "meat": 1.5,
		"hint": "Хищный рот посильнее: кусает больно"},
	"snout": {"name": "Хобот", "slot": "mouth", "cost": 18, "bite": 4.0, "fruit": 1.3, "meat": 1.0, "reach": 0.6,
		"hint": "Всеядный: ест всё понемногу и достаёт дальше"},
	# Глаза.
	"eyes": {"name": "Глаза", "slot": "eyes", "cost": 10, "sight": 1.0,
		"hint": "Пара обычных глаз: без глаз вокруг сплошной туман"},
	"eyes_big": {"name": "Большие глаза", "slot": "eyes", "cost": 26, "sight": 1.5,
		"hint": "Видно далеко: камера выше, тумана почти нет"},
	"eyes_stalk": {"name": "Глаза на стебельках", "slot": "eyes", "cost": 20, "sight": 1.25, "stealth": 0.85,
		"hint": "Видно дальше, а сам замечаешь врага раньше, чем он тебя"},
	# Ноги.
	"stubs": {"name": "Короткие лапки", "slot": "legs", "cost": 0, "legs": 4,
		"hint": "Даром: первые ноги, простые"},
	"legs2": {"name": "Две ноги", "slot": "legs", "cost": 12, "speed": 1.1, "legs": 2,
		"hint": "Ходишь на двух: быстрее лапок"},
	"legs4": {"name": "Четыре ноги", "slot": "legs", "cost": 20, "speed": 1.2, "legs": 4, "hp": 4.0,
		"hint": "Устойчиво и быстро"},
	"legs6": {"name": "Шесть ног", "slot": "legs", "cost": 34, "speed": 1.3, "legs": 6, "hp": 6.0,
		"hint": "Как жук: быстро и крепко"},
	"legs_long": {"name": "Длинные ноги", "slot": "legs", "cost": 40, "speed": 1.5, "legs": 4, "long": true,
		"hint": "Бегаешь быстрее всех — никто не догонит"},
	# Ступни.
	"paws": {"name": "Мягкие лапы", "slot": "feet", "cost": 14, "stealth": 0.7,
		"hint": "Ходишь тихо: стаи и отшельники замечают тебя ближе"},
	"hooves": {"name": "Копыта", "slot": "feet", "cost": 16, "speed": 1.12,
		"hint": "Бегаешь быстрее"},
	"webbed": {"name": "Перепонки", "slot": "feet", "cost": 12, "wade": true,
		"hint": "Можно заходить в воду по брюхо — там никто не достанет"},
	# Когти.
	"claws": {"name": "Когти", "slot": "claws", "cost": 16, "bite": 3.0, "bone": 1.5,
		"hint": "Бьёшь сильнее, кости крошатся быстрее"},
	"claws_big": {"name": "Большие когти", "slot": "claws", "cost": 34, "bite": 6.0, "bone": 2.0,
		"hint": "Бьёшь намного сильнее, кости — вдвое быстрее"},
	# Руки.
	"arms": {"name": "Руки", "slot": "arms", "cost": 18, "bite": 2.0, "reach": 1.0,
		"hint": "Достаёшь дальше: плоды и яйца — издалека, враги — тоже"},
	"arms_claw": {"name": "Руки-клешни", "slot": "arms", "cost": 30, "bite": 5.0, "reach": 0.6,
		"hint": "Щиплют больно и достают дальше"},
	# Спина.
	"back_spikes": {"name": "Шипы", "slot": "back", "cost": 20, "thorns": 0.35,
		"hint": "Кто кусает тебя — получает треть укуса обратно"},
	"plates": {"name": "Костяные пластины", "slot": "back", "cost": 24, "armor": 0.3, "speed": 0.92,
		"hint": "Укусы слабее на треть, но чуть медленнее"},
	"sail": {"name": "Парус", "slot": "back", "cost": 22, "regen": 1.2,
		"hint": "Греется на солнце: раны заживают быстрее"},
	# Хвост.
	"tail_long": {"name": "Длинный хвост", "slot": "tail", "cost": 10, "speed": 1.06, "turn": 1.3,
		"hint": "Держит равновесие: чуть быстрее и поворачиваешь резче"},
	"tail_club": {"name": "Хвост-булава", "slot": "tail", "cost": 26, "thorns": 0.25, "hp": 6.0,
		"hint": "Отмахивается: кусачий получает четверть укуса обратно"},
	# Голова.
	"horns": {"name": "Рога", "slot": "head", "cost": 24, "bite": 4.0, "bone": 1.3,
		"hint": "Бодаешь вместе с укусом: сильнее бьёшь и существ, и кости"},
	"crest": {"name": "Гребень", "slot": "head", "cost": 14, "hp": 5.0, "stealth": 1.2, "scare": true,
		"hint": "Бродяги пугаются и не мешают, но стаи замечают тебя раньше"},
	# Кожа.
	"fur": {"name": "Мех", "slot": "skin", "cost": 16, "hp": 12.0,
		"hint": "Больше здоровья"},
	"scales": {"name": "Чешуя", "slot": "skin", "cost": 22, "armor": 0.15, "hp": 4.0,
		"hint": "Укусы чуть слабее и здоровья чуть больше"},
	"poison_skin": {"name": "Ядовитая кожа", "slot": "skin", "cost": 30, "poison": 3.0,
		"hint": "Кто тебя укусил — отравлен на 3 секунды"},
}

## Что стало с частями клетки на суше: часть океана → часть суши. Кого здесь нет — на суше
## не нужен (жгутик, реснички, пузыри…): уходит, ДНК за него освобождается.
const FROM_SEA := {
	"filter": "beak", "jaws": "jaws", "fangs": "fangs", "proboscis": "snout", "baleen": "snout",
	"eye": "eyes", "crystal": "eyes_big", "firefly": "eyes_big", "lantern": "eyes_big",
	"spike": "back_spikes", "spike2": "back_spikes", "needle": "back_spikes", "thorn_armor": "back_spikes",
	"drill": "horns", "horn": "horns",
	"shell": "plates", "plates": "plates", "stone_skin": "scales",
	"membrane": "fur", "fat": "fur",
	"poison": "poison_skin", "spit": "poison_skin",
	"claw": "arms_claw", "tentacle": "arms", "sucker": "arms",
	"chloroplast": "sail", "life_core": "sail",
	"serpent": "tail_long",
}

## Почему часть клетки не нужна на суше — коротко, для экрана перехода.
static func why_gone(id: String) -> String:
	var kind: String = Content.PARTS[id].kind if Content.PARTS.has(id) else ""
	match kind:
		"move":
			return "на суше ходят, а не плывут"
		"ability":
			return "умение для воды"
	return "на суше не нужна"

## Сделать тело для суши из тела клетки. {body: место → часть, kept: [[часть клетки,
## часть суши]], gone: [[часть клетки, почему]]}. Ноги даются даром — короткие лапки.
static func from_sea(sea_body: Array) -> Dictionary:
	var body := {"legs": "stubs"}
	var kept: Array = []
	var gone: Array = []
	for p in sea_body:
		var id: String = p.id
		if not FROM_SEA.has(id):
			gone.append([id, why_gone(id)])
			continue
		var land_id: String = FROM_SEA[id]
		var slot: String = PARTS[land_id].slot
		# В одно место — одна часть: остаётся лучшая (дороже).
		if body.has(slot) and slot != "legs":
			var old: String = body[slot]
			if int(PARTS[old].cost) >= int(PARTS[land_id].cost):
				kept.append([id, old])
				continue
		body[slot] = land_id
		kept.append([id, land_id])
	return {"body": body, "kept": kept, "gone": gone}

static func cost(body: Dictionary) -> int:
	var sum := 0
	for slot in body:
		if PARTS.has(body[slot]):
			sum += int(PARTS[body[slot]].cost)
	return sum

static func slot_name(slot: String) -> String:
	for s in SLOTS:
		if s[0] == slot:
			return s[1]
	return slot

static func in_slot(slot: String) -> Array:
	return PARTS.keys().filter(func(id): return PARTS[id].slot == slot)

## Что умеет тело: всё, что нужно правилам суши. shape — вылепленная форма: толще —
## крепче, но медленнее; длинные ноги — быстрее; большая часть — сильнее.
static func stats(body: Dictionary, shape := {}) -> Dictionary:
	var sh := fix_shape(shape)
	var s := {"speed": 1.0, "bite": 2.0, "hp": 30.0, "armor": 0.0, "thorns": 0.0, "poison": 0.0, "regen": 0.8,
		"sight": 0.55, "fruit": 1.0, "meat": 1.0, "bone": 1.0, "reach": 0.0, "stealth": 1.0, "wade": false,
		"legs": 4, "turn": 1.0, "scare": false, "mouth": false, "long": false}
	var heavy := 0.0
	for slot in body:
		var id: String = body[slot]
		if not PARTS.has(id):
			continue
		var p: Dictionary = PARTS[id]
		var ps := part_size(sh, slot)
		var k := 0.75 + 0.25 * ps
		heavy += maxf(0.0, ps - 1.0)
		if slot == "mouth":
			s.mouth = true
		if slot == "eyes":
			s.sight = float(p.sight) * (0.85 + 0.15 * ps)
		for key in ["speed", "fruit", "meat", "bone", "stealth", "turn"]:
			if p.has(key):
				s[key] *= float(p[key])
		for key in ["bite", "hp", "regen", "reach", "poison"]:
			if p.has(key):
				s[key] += float(p[key]) * k
		for key in ["armor", "thorns"]:
			if p.has(key):
				s[key] = 1.0 - (1.0 - s[key]) * (1.0 - minf(float(p[key]) * k, 0.6))
		for key in ["wade", "scare", "long"]:
			if p.has(key):
				s[key] = true
		if p.has("legs"):
			s.legs = p.legs
	# Форма тела.
	var bulk := bulk_of(sh)
	s.hp *= clampf(sqrt(bulk), 0.6, 1.8)
	var ls := float(sh.leg_size)
	var leg_len := (float(sh.leg_len) + float(sh.leg_len_f)) / 2.0 * ls
	var leg_thick := (float(sh.leg_thick) + float(sh.leg_thick_f)) / 2.0 * ls
	s.hp += (leg_thick - 1.0) * 6.0
	s.speed /= clampf(pow(bulk, 0.15), 0.85, 1.25)
	s.speed *= clampf(0.75 + 0.25 * leg_len, 0.7, 1.35) * (1.0 - 0.05 * (leg_thick - 1.0))
	s.speed /= 1.0 + 0.03 * heavy
	s.bite += (float(sh.head) - 1.0) * 3.0
	if body.has("arms"):
		s.reach += (float(sh.arm_len) * float(sh.arm_size) - 1.0) * 0.8
		s.bite += (float(sh.arm_thick) * float(sh.arm_size) - 1.0) * 1.5
	s.turn *= clampf(0.85 + 0.15 * float(sh.tail_len) * float(sh.tail_size), 0.8, 1.4)
	# Быстрее двух обычных не бегает никто — иначе ни стая, ни отшельник не страшны.
	s.speed = minf(s.speed, 1.9)
	s.hp = maxf(s.hp, 10.0)
	s.bite = maxf(s.bite, 1.0)
	return s

# --- форма тела -----------------------------------------------------------------------
#
# Туловище — позвоночник из SPINE точек от хвоста к голове, у каждой своя толщина
# (girth); ещё длина, голова и шея, ноги, руки, хвост и размер каждой части. Всё это
# лепится пальцем в редакторе. Числа — в долях обычного.

const SPINE := 5
## ключ → [обычное, меньше некуда, больше некуда]
##   torso — размер туловища целиком, width / height — ширина и высота туловища;
##   leg_* — задние ноги (у двуногих — обе), leg_*_f — передние; *_size — размер
##   целиком (длина, толщина и ступня вместе).
const SHAPE := {
	"len": [1.0, 0.6, 2.4], "head": [1.0, 0.5, 2.0], "neck_z": [0.0, -0.2, 1.4], "neck_y": [0.0, -0.4, 1.4],
	"torso": [1.0, 0.5, 2.0], "width": [1.0, 0.5, 2.0], "height": [1.0, 0.5, 2.0],
	"leg_size": [1.0, 0.5, 2.0], "leg_len": [1.0, 0.45, 2.4], "leg_thick": [1.0, 0.5, 2.5],
	"leg_len_f": [1.0, 0.45, 2.4], "leg_thick_f": [1.0, 0.5, 2.5],
	"arm_size": [1.0, 0.5, 2.0], "arm_len": [1.0, 0.5, 2.5], "arm_thick": [1.0, 0.5, 2.5], "arm_pitch": [0.0, -1.2, 1.4],
	"tail_size": [1.0, 0.5, 2.0], "tail_len": [1.0, 0.2, 3.5], "tail_pitch": [0.25, -0.8, 1.3], "tail_thick": [1.0, 0.5, 2.2],
}
const GIRTH := [0.9, 1.0, 1.05, 1.0, 0.9]
const GIRTH_LIMITS := [0.35, 2.0]
const SIZE_LIMITS := [0.5, 2.2]
## Обычная «масса» туловища — от неё считается, толще ты или тоньше.
const BULK_BASE := 0.9445

static func default_shape() -> Dictionary:
	var d := {"girth": GIRTH.duplicate(), "sizes": {}}
	for k in SHAPE:
		d[k] = SHAPE[k][0]
	return d

## Форма с проверкой: чего нет — обычное, лишнее — в пределах.
static func fix_shape(v: Variant) -> Dictionary:
	var d := default_shape()
	if not v is Dictionary:
		return d
	for k in SHAPE:
		var x = v.get(k)
		if x is float or x is int:
			d[k] = clampf(float(x), SHAPE[k][1], SHAPE[k][2])
	# Раньше ноги были одни на всех: передние — как задние.
	if not v.has("leg_len_f"):
		d.leg_len_f = d.leg_len
	if not v.has("leg_thick_f"):
		d.leg_thick_f = d.leg_thick
	var g = v.get("girth")
	if g is Array and g.size() == SPINE and g.all(func(x): return x is float or x is int):
		d.girth = g.map(func(x): return clampf(float(x), GIRTH_LIMITS[0], GIRTH_LIMITS[1]))
	var sz = v.get("sizes")
	if sz is Dictionary:
		for slot in sz:
			var x = sz[slot]
			if slot is String and SLOTS.any(func(s): return s[0] == slot) and (x is float or x is int):
				d.sizes[slot] = clampf(float(x), SIZE_LIMITS[0], SIZE_LIMITS[1])
	return d

static func part_size(shape: Dictionary, slot: String) -> float:
	return float(shape.get("sizes", {}).get(slot, 1.0))

static func bulk_of(shape: Dictionary) -> float:
	var g: Array = shape.get("girth", GIRTH)
	var sum := 0.0
	for x in g:
		sum += float(x) * float(x)
	var t := float(shape.get("torso", 1.0))
	return float(shape.get("len", 1.0)) * t * t * t * float(shape.get("width", 1.0)) * float(shape.get("height", 1.0)) * sum / g.size() / BULK_BASE

## Чистый лист: простое круглое туловище, всё остальное — обычное.
static func blank_shape() -> Dictionary:
	var d := default_shape()
	d.len = 0.8
	d.girth = [0.85, 0.95, 1.0, 0.95, 0.85]
	d.tail_len = 0.5
	return d

## Форма с первого этапа: длина — от вытянутости клетки, толщина по длине — от её
## очертания (где клетка была шире, там и туловище толще).
static func shape_from_sea(sea: Array) -> Dictionary:
	var d := default_shape()
	if sea.size() < 3:
		return d
	var st := Content.shape_stats(sea)
	d.len = clampf(float(st.elong), 0.8, 1.7)
	var pts: Array = []
	for i in sea.size():
		var a := TAU * i / sea.size()
		pts.append(Vector2.from_angle(a) * float(sea[i]))
	var back := -Content.shape_at(sea, PI)
	var front := Content.shape_at(sea, 0.0)
	for i in SPINE:
		var x := lerpf(back, front, 0.12 + 0.76 * i / (SPINE - 1.0))
		var lo := INF
		var hi := -INF
		for j in pts.size():
			var p: Vector2 = pts[j]
			var q: Vector2 = pts[(j + 1) % pts.size()]
			if (p.x - x) * (q.x - x) <= 0.0 and absf(q.x - p.x) > 0.0001:
				var y := lerpf(p.y, q.y, (x - p.x) / (q.x - p.x))
				lo = minf(lo, y)
				hi = maxf(hi, y)
		if hi > lo:
			d.girth[i] = clampf((hi - lo) / 2.0 * 1.05, 0.5, 1.6)
	return d

## Точки позвоночника в метрах (s — размер существа): [{z, r}] от хвоста к голове.
## rx, ry — полуширина и полувысота в этом месте.
static func spine(shape: Dictionary, s: float) -> Array:
	var t := float(shape.get("torso", 1.0))
	var L := 1.2 * s * float(shape.len) * t
	var out: Array = []
	for i in SPINE:
		var r := 0.475 * s * float(shape.girth[i]) * t
		out.append({"z": -L / 2.0 + L * i / (SPINE - 1.0), "r": r, "rx": r * float(shape.get("width", 1.0)), "ry": r * float(shape.get("height", 1.0))})
	return out

## Толщина и место на позвоночнике в доле t (0 — хвост, 1 — голова).
static func spine_at(sp: Array, t: float) -> Dictionary:
	var f := clampf(t, 0.0, 1.0) * (sp.size() - 1)
	var i := mini(int(f), sp.size() - 2)
	var k := f - i
	return {"z": lerpf(sp[i].z, sp[i + 1].z, k), "r": lerpf(sp[i].r, sp[i + 1].r, k),
		"rx": lerpf(sp[i].rx, sp[i + 1].rx, k), "ry": lerpf(sp[i].ry, sp[i + 1].ry, k)}

# --- окрас ----------------------------------------------------------------------------
#
# Цвета на суше: первые 16 — те же, что у клетки (номер переносится как есть), дальше —
# земляные, тёмные и светлые. Окрас бесплатный — ДНК не тратит.

const COLORS := ["#8fd07a", "#6fc0e0", "#e0b060", "#e07a6a", "#b08ae0", "#e890b8", "#7ad0b0", "#d8d8c8",
	"#5a8ee0", "#f0dc6a", "#c8683e", "#7a62c8", "#b4e05a", "#f4b0a0", "#3e9a96", "#9a8878",
	"#8a5a3a", "#5e4a3a", "#c89a6a", "#f2ead8", "#3a3a44", "#6a6e78", "#a8323a", "#2e6a3a",
	"#1e4a7a", "#e8742a", "#f4d03a", "#5ac8e8"]
## Узоры: [ключ, подпись]. Первые пять — как у клетки.
const PATTERNS := [["none", "Без узора"], ["spots", "Пятна"], ["stripes", "Полосы"], ["rings", "Кольца"],
	["gradient", "Переход"], ["belly", "Брюшко"], ["leopard", "Леопард"], ["tiger", "Тигр"],
	["dots", "Крапинки"], ["back", "Полоса по спине"]]

static func default_paint(evo_color := 0, evo_color2 := 5, evo_pattern := "none") -> Dictionary:
	return fix_paint({"color": evo_color, "color2": evo_color2, "pattern": evo_pattern})

static func fix_paint(v: Variant) -> Dictionary:
	var d := {"color": 0, "color2": 5, "pattern": "spots"}
	if not v is Dictionary:
		return d
	for k in ["color", "color2"]:
		var x = v.get(k)
		if (x is int or x is float) and int(x) >= 0 and int(x) < COLORS.size():
			d[k] = int(x)
	var p = v.get("pattern")
	if p is String and PATTERNS.any(func(q): return q[0] == p):
		d.pattern = p
	return d

## Коротко, что даёт часть: «+6 укус · ×1,3 мясо».
static func summary(id: String) -> String:
	var p: Dictionary = PARTS[id]
	var out: Array = []
	if p.has("bite"):
		out.append("+%d укус" % int(p.bite))
	if p.has("speed"):
		out.append("скорость ×%s" % _num(p.speed))
	if p.has("hp"):
		out.append("+%d здоровья" % int(p.hp))
	if p.has("armor"):
		out.append("броня %d%%" % int(round(p.armor * 100.0)))
	if p.has("thorns"):
		out.append("сдача %d%%" % int(round(p.thorns * 100.0)))
	if p.has("poison"):
		out.append("яд %d/с" % int(p.poison))
	if p.has("regen"):
		out.append("лечение +%s/с" % _num(p.regen))
	if p.has("sight"):
		out.append("зрение ×%s" % _num(p.sight))
	if p.has("fruit") and float(p.fruit) != 1.0:
		out.append("плоды ×%s" % _num(p.fruit))
	if p.has("meat") and float(p.meat) != 1.0:
		out.append("мясо ×%s" % _num(p.meat))
	if p.has("reach"):
		out.append("+%s м досягаемость" % _num(p.reach))
	if p.has("bone"):
		out.append("кости ×%s" % _num(p.bone))
	if p.has("stealth"):
		out.append("тише" if float(p.stealth) < 1.0 else "заметнее")
	if p.get("wade", false):
		out.append("ходишь по воде")
	return " · ".join(out)

static func _num(v: float) -> String:
	var t := ("%.2f" % v).rstrip("0").rstrip(".")
	return t.replace(".", ",")
