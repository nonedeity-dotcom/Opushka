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
	["torso", "Тело", "body"],
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
	# Основа.
	"torso": {"slot": "torso", "name": "Туловище", "cost": 0,
		"hint": "Основа: к нему крепятся голова, ноги и всё остальное. Даром"},
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

## Части, которые есть сразу. Остальные находятся на острове: в окаменелостях, у гигантов
## и у вожаков стай. Части, пришедшие из океана (FROM_SEA), тоже есть сразу.
const BASE := ["torso", "stubs", "legs2", "legs4", "jaws", "beak", "eyes", "tail_long"]

## Сила на суше: существо не растёт, а крепнет. LEVELS — сколько ДНК надо добыть на суше
## (за всё время, гибель её не отнимает), чтобы стать сильнее: первая сила — с нуля.
const LEVELS := [0, 30, 80, 150, 250, 380, 550, 760, 1020, 1350]

## Какая сила при стольких добытых ДНК (1…10).
static func level_of(xp: float) -> int:
	var l := 1
	for i in LEVELS.size():
		if xp >= float(LEVELS[i]):
			l = i + 1
	return l

## Сколько ДНК до следующей силы и какая доля пути пройдена: [осталось, доля]. На последней
## силе — [0, 1].
static func level_progress(xp: float) -> Array:
	var l := level_of(xp)
	if l >= LEVELS.size():
		return [0.0, 1.0]
	var a := float(LEVELS[l - 1])
	var b := float(LEVELS[l])
	return [b - xp, clampf((xp - a) / (b - a), 0.0, 1.0)]

## Во сколько раз сила прибавляет: здоровье +15%, укус +12%, скорость +1,5% за ступень.
static func power(level: int) -> Dictionary:
	var k := float(clampi(level, 1, LEVELS.size()) - 1)
	return {"hp": 1.0 + 0.15 * k, "bite": 1.0 + 0.12 * k, "speed": 1.0 + 0.015 * k}

## Какие части есть сразу у этого тела клетки: основа и всё, что пришло из океана.
static func start_found(sea_body: Array) -> Dictionary:
	var out := {}
	for id in BASE:
		out[id] = true
	for p in sea_body:
		if FROM_SEA.has(p.id):
			out[FROM_SEA[p.id]] = true
	return out

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
	var body := {"torso": "torso", "legs": "stubs"}
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

## Цена тела. Руки — за каждую пару (4 руки — вдвое, 6 — втрое).
static func cost(body: Dictionary, shape := {}) -> int:
	var sum := 0
	for slot in body:
		if PARTS.has(body[slot]):
			sum += part_cost(body[slot], shape)
	return sum

static func part_cost(id: String, shape := {}) -> int:
	var c := int(PARTS[id].cost)
	match PARTS[id].slot:
		"arms":
			c *= arm_pairs(shape)
		"legs":
			# Ноги — за каждую: своё число ног дороже или дешевле обычного набора.
			var n := int(round(float(shape.get("leg_n", 0.0))))
			if n > 0:
				c = int(round(float(c) * n / int(PARTS[id].legs)))
		"eyes":
			var n := int(round(float(shape.get("eye_n", 0.0))))
			if n > 0:
				c = int(round(float(c) * n / 2.0))
	return c

## Сколько пар рук: 1–3.
static func arm_pairs(shape: Dictionary) -> int:
	return clampi(int(round(float(shape.get("arm_pairs", 1.0)))), 1, 3)

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
		var ps := part_size(sh, slot) * dim_k(sh, dim_key(slot))
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
			s.legs = leg_count(body, sh)
	# Форма тела.
	var bulk := bulk_of(sh)
	s.hp *= clampf(sqrt(bulk), 0.6, 1.8)
	var ls := float(sh.leg_size)
	var leg_len := (float(sh.leg_len) + float(sh.leg_len_f)) / 2.0 * ls
	var leg_thick := (float(sh.leg_thick) + float(sh.leg_thick_f)) / 2.0 * ls
	# У каждой ноги свои длина, ширина, высота и размер — берём в среднем.
	if int(s.legs) > 0:
		var sl := 0.0
		var st := 0.0
		for i in int(s.legs):
			var d := dim(sh, "leg%d" % i)
			sl += float(d[0]) * float(d[3])
			st += sqrt(float(d[1]) * float(d[2])) * float(d[3])
		leg_len *= sl / int(s.legs)
		leg_thick *= st / int(s.legs)
	s.hp += (leg_thick - 1.0) * 6.0
	s.speed /= clampf(pow(bulk, 0.15), 0.85, 1.25)
	s.speed *= clampf(0.75 + 0.25 * leg_len, 0.7, 1.35) * (1.0 - 0.05 * (leg_thick - 1.0))
	s.speed /= 1.0 + 0.03 * heavy
	s.bite += (float(sh.head) * dim_k(sh, "head") - 1.0) * 3.0
	if body.has("arms") and PARTS.has(body.arms):
		# Каждая лишняя пара рук бьёт и достаёт ещё немного.
		var extra := arm_pairs(sh) - 1
		s.bite += float(PARTS[body.arms].get("bite", 0.0)) * 0.6 * extra
		s.reach += 0.2 * extra
	if body.has("arms"):
		var a0 := dim(sh, "arm0")
		var a1 := dim(sh, "arm1")
		var al := (float(a0[0]) * float(a0[3]) + float(a1[0]) * float(a1[3])) / 2.0
		var at := (sqrt(float(a0[1]) * float(a0[2])) * float(a0[3]) + sqrt(float(a1[1]) * float(a1[2])) * float(a1[3])) / 2.0
		s.reach += (float(sh.arm_len) * float(sh.arm_size) * al - 1.0) * 0.8
		s.bite += (float(sh.arm_thick) * float(sh.arm_size) * at - 1.0) * 1.5
	s.turn *= clampf(0.85 + 0.15 * float(sh.tail_len) * float(sh.tail_size) * float(dim(sh, "tail")[0]), 0.8, 1.4)
	# Без ног — только ползать.
	if not body.has("legs"):
		s.legs = 0
		s.speed *= 0.3
	# Число ног: на одной — прыгаешь медленнее; лишние ноги — чуть крепче.
	if body.has("legs") and PARTS.has(body.legs):
		var n := int(s.legs)
		var base_n := int(PARTS[body.legs].legs)
		if n == 1:
			s.speed *= 0.75
		s.hp += maxf(0.0, n - base_n) * 1.5
	# Больше глаз — видишь лучше (и наоборот).
	if body.has("eyes"):
		s.sight *= clampf(1.0 + 0.08 * (eye_count(body, sh) - 2), 0.8, 1.35)
	# Поднял туловище — голова выше, видно дальше.
	s.sight *= 1.0 + 0.15 * clampf(float(sh.torso_pitch), 0.0, 1.5) / 1.5
	# Высоко над землёй на длинных ногах — тоже.
	if body.has("legs"):
		s.sight *= 1.0 + 0.06 * clampf(float(sh.get("lift", 0.0)), 0.0, 2.5)
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
##   torso_pitch — насколько туловище поднято (0 — лежит, 1,5 — стоймя, прямоходящее);
##   leg_* — задние ноги (у двуногих — обе), leg_*_f — передние; *_size — размер
##   целиком (длина, толщина и ступня вместе).
const SHAPE := {
	"len": [1.0, 0.6, 2.4], "head": [1.0, 0.5, 2.0], "neck_z": [0.0, -0.2, 1.4], "neck_y": [0.0, -0.4, 1.4],
	"torso": [1.0, 0.5, 2.0], "width": [1.0, 0.5, 2.0], "height": [1.0, 0.5, 2.0], "torso_pitch": [0.0, -0.4, 1.5],
	"leg_size": [1.0, 0.5, 2.0], "leg_len": [1.0, 0.45, 2.4], "leg_thick": [1.0, 0.5, 2.5],
	"leg_len_f": [1.0, 0.45, 2.4], "leg_thick_f": [1.0, 0.5, 2.5],
	"arm_size": [1.0, 0.5, 2.0], "arm_pairs": [1.0, 1.0, 3.0],
	"leg_n": [0.0, 0.0, 8.0], "eye_n": [0.0, 0.0, 6.0], "torso_bend": [0.0, -1.0, 1.0], "tail_curl": [0.0, -2.5, 2.5],
	"lift": [0.0, 0.0, 2.5], "head_on": [1.0, 0.0, 1.0], "tail_on": [1.0, 0.0, 1.0], "arm_len": [1.0, 0.5, 2.5], "arm_thick": [1.0, 0.5, 2.5], "arm_pitch": [0.0, -1.2, 1.4],
	"tail_size": [1.0, 0.5, 2.0], "tail_len": [1.0, 0.2, 3.5], "tail_pitch": [0.25, -0.8, 1.3], "tail_thick": [1.0, 0.5, 2.2],
}
const GIRTH := [0.9, 1.0, 1.05, 1.0, 0.9]
## У каждой части своя длина, ширина, высота и размер: dims[часть] = [Д, Ш, В, Р].
## Части: голова, рот, глаза, рога (всё, что на голове), спина, хвост, каждая нога
## (leg0…leg5: 0-1 — передние, дальше — к хвосту; чётные — левые) и каждая рука.
const DIM_KEYS := ["head", "mouth", "eyes", "horns", "back", "tail", "leg0", "leg1", "leg2", "leg3", "leg4", "leg5", "leg6", "leg7",
	"arm0", "arm1", "arm2", "arm3", "arm4", "arm5"]
## Глаза по одному: где на голове — [вокруг головы (0 — прямо вперёд, ± — в стороны),
## выше/ниже, размер этого глаза].
const EYE_KEYS := ["eye0", "eye1", "eye2", "eye3", "eye4", "eye5"]
## Поворот частей: наклон рта, рогов и гребня, шипов и пластин, кистей, ступней.
const ROT_KEYS := ["mouth", "horns", "back", "hands", "feet"]
## Где часть сидит — любую можно поставить куда угодно, на туловище или на голову:
## place[часть] = [на чём: 0 — туловище, 1 — голова, u, v, ещё].
##   туловище: u — вдоль (0 — зад, 1 — перёд; −0,25 и 1,25 — самые кончики), v — угол по
##   кругу туловища (0 — правый бок, π/2 — спина, π — левый бок, −π/2 — брюхо);
##   голова: u — вокруг (0 — прямо вперёд), v — выше/ниже.
##   «ещё» — у рук наклон, у глаз размер.
## Нет записи — место по умолчанию.
const PLACE_KEYS := ["leg0", "leg1", "leg2", "leg3", "leg4", "leg5", "leg6", "leg7", "arm0", "arm1", "arm2", "arm3", "arm4", "arm5",
	"eye0", "eye1", "eye2", "eye3", "eye4", "eye5", "mouth", "horns", "back", "tail", "head"]
const DIM_LIMITS := [0.3, 3.0]
const DIM_SIZE_LIMITS := [0.4, 2.5]
const GIRTH_LIMITS := [0.35, 2.0]
const SIZE_LIMITS := [0.5, 2.2]
## Обычная «масса» туловища — от неё считается, толще ты или тоньше.
const BULK_BASE := 0.9445

static func default_shape() -> Dictionary:
	var d := {"girth": GIRTH.duplicate(), "sizes": {}, "dims": {}, "place": {}, "rot": {}}
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
	var dm = v.get("dims")
	if dm is Dictionary:
		for k in dm:
			var a = dm[k]
			if k is String and DIM_KEYS.has(k) and a is Array and a.size() == 4 and a.all(func(x): return x is float or x is int):
				d.dims[k] = [clampf(float(a[0]), DIM_LIMITS[0], DIM_LIMITS[1]), clampf(float(a[1]), DIM_LIMITS[0], DIM_LIMITS[1]),
					clampf(float(a[2]), DIM_LIMITS[0], DIM_LIMITS[1]), clampf(float(a[3]), DIM_SIZE_LIMITS[0], DIM_SIZE_LIMITS[1])]
	var pl = v.get("place")
	if pl is Dictionary:
		for k in pl:
			var a = pl[k]
			if not (k is String and PLACE_KEYS.has(k) and a is Array and a.all(func(x): return x is float or x is int)):
				continue
			if a.size() == 3:
				# Старый вид: у ног и рук [вдоль, выше/ниже по своему боку, наклон], у глаз
				# [вокруг головы, выше/ниже, размер].
				if k.begins_with("eye"):
					a = [1.0, a[0], a[1], a[2]]
				else:
					var right := int(k.substr(3)) % 2 == 1
					a = [0.0, a[0], float(a[1]) if right else PI - float(a[1]), a[2]]
			if a.size() != 4:
				continue
			d.place[k] = fix_place(k, a)
	var rt = v.get("rot")
	if rt is Dictionary:
		for k in rt:
			if k is String and ROT_KEYS.has(k) and (rt[k] is float or rt[k] is int):
				d.rot[k] = clampf(float(rt[k]), -1.2, 1.2)
	var sz = v.get("sizes")
	if sz is Dictionary:
		for slot in sz:
			var x = sz[slot]
			if slot is String and SLOTS.any(func(s): return s[0] == slot) and (x is float or x is int):
				d.sizes[slot] = clampf(float(x), SIZE_LIMITS[0], SIZE_LIMITS[1])
	return d

## Длина, ширина, высота и размер части (обычные — единицы).
## Место в пределах: у головы — угол вокруг и вверх, у туловища — вдоль с кончиками и
## угол по кругу.
static func fix_place(key: String, a: Array) -> Array:
	var on := 1.0 if float(a[0]) >= 0.5 else 0.0
	var extra := clampf(float(a[3]), 0.4, 2.5) if key.begins_with("eye") else clampf(float(a[3]), -1.5, 1.5)
	if on == 1.0:
		return [1.0, wrapf(float(a[1]), -PI, PI), clampf(float(a[2]), -1.45, 1.45), extra]
	return [0.0, clampf(float(a[1]), -0.25, 1.25), wrapf(float(a[2]), -PI, PI), extra]

## Пределы у ползунка места: i — 1 (вдоль тела / вокруг головы), 2 (угол по кругу тела /
## выше-ниже на голове), 3 (наклон руки / размер глаза).
static func place_limits(key: String, pl: Array, i: int) -> Array:
	if i == 3:
		return [0.4, 2.5] if key.begins_with("eye") else [-1.5, 1.5]
	if float(pl[0]) >= 0.5:
		return [-PI, PI] if i == 1 else [-1.45, 1.45]
	return [-0.25, 1.25] if i == 1 else [-PI, PI]

## Место на голове → на переднем кончике туловища (когда головы нет): [u, v].
static func head_to_body(yaw: float, pitch: float) -> Array:
	var d := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var rad := Vector2(d.x, d.y).length()
	var phi := atan2(maxf(d.z, 0.0), rad)
	return [1.0 + 0.25 * phi / (PI / 2.0), atan2(d.y, d.x) if rad > 0.001 else 0.0]

## С какой стороны место: больше 0 — правая, меньше — левая, около 0 — посередине.
static func place_side(pl: Array) -> float:
	return sin(float(pl[1])) if float(pl[0]) >= 0.5 else cos(float(pl[2]))

## То же место на другой стороне (левое ↔ правое).
static func mirror_place(a: Array) -> Array:
	if float(a[0]) >= 0.5:
		return [1.0, -float(a[1]), a[2], a[3]]
	return [0.0, a[1], wrapf(PI - float(a[2]), -PI, PI), a[3]]

## Место по умолчанию. head_on — есть ли голова: без неё рот, глаза и рога садятся на
## перёд туловища.
static func default_place(key: String, legs: int, tilt := 0.0, eyes := 2, head_on := true) -> Array:
	match key:
		"mouth":
			return [1.0, 0.0, -0.1, 0.0] if head_on else [0.0, 1.25, 0.0, 0.0]
		"horns":
			return [1.0, PI, 1.3, 0.0] if head_on else [0.0, 1.0, PI / 2.0, 0.0]
		"back":
			return [0.0, 0.5, PI / 2.0, 0.0]
		"tail":
			return [0.0, -0.25, 0.0, 0.0]
		"head":
			return [0.0, 1.25, 0.0, 0.0]
	if key.begins_with("eye"):
		var e := int(key.substr(3))
		var center := eyes % 2 == 1 and e == eyes - 1
		if not head_on:
			if center:
				return [0.0, 1.12, PI / 2.0, 1.0]
			var a: float = [0.55, 0.15, 1.0][mini(e / 2, 2)]
			return [0.0, [1.1, 1.0, 1.15][mini(e / 2, 2)], a if e % 2 == 1 else PI - a, 1.0]
		if center:
			# Непарный глаз — посередине лба.
			return [1.0, 0.0, 0.55 if eyes == 1 else 0.9, 1.15 if eyes == 1 else 0.85]
		var side := -1.0 if e % 2 == 0 else 1.0
		var row: Array = [[0.62, 0.5], [0.95, 0.05], [0.35, 1.0]][mini(e / 2, 2)]
		return [1.0, side * float(row[0]), row[1], 1.0]
	var i := int(key.substr(3))
	if key.begins_with("arm"):
		var a: float = [0.0, -0.25, -0.45][i / 2]
		return [0.0, [0.86, 0.7, 0.55][i / 2], a if i % 2 == 1 else PI - a, 0.0]
	var up := clampf(tilt / 1.3, 0.0, 1.0)
	var rows := int(ceil(legs / 2.0))
	var ts: Array = {1: [lerpf(0.5, 0.08, up)], 2: [0.78, 0.22], 3: [0.82, 0.5, 0.18], 4: [0.85, 0.62, 0.38, 0.15]}.get(rows, [0.5])
	var t: float = ts[mini(i / 2, ts.size() - 1)]
	# Непарная нога — посередине под брюхом.
	if legs % 2 == 1 and i == legs - 1:
		return [0.0, t, -PI / 2.0, 0.0]
	return [0.0, t, -0.32 if i % 2 == 1 else -(PI - 0.32), 0.0]

## Сколько ног: своё число или сколько положено этому виду ног (0 — без ног).
static func leg_count(body: Dictionary, shape: Dictionary) -> int:
	if not body.has("legs") or not PARTS.has(body.legs):
		return 0
	var n := int(round(float(shape.get("leg_n", 0.0))))
	return n if n > 0 else int(PARTS[body.legs].legs)

## Сколько глаз: своё число или два (0 — без глаз).
static func eye_count(body: Dictionary, shape: Dictionary) -> int:
	if not body.has("eyes"):
		return 0
	var n := int(round(float(shape.get("eye_n", 0.0))))
	return n if n > 0 else 2

## Какой бок у ноги: чётные — левые, нечётные — правые, последняя при нечётном
## числе — посередине (0).
static func leg_side(i: int, n: int) -> float:
	if n % 2 == 1 and i == n - 1:
		return 0.0
	return -1.0 if i % 2 == 0 else 1.0

## Где нога или рука на самом деле (своё место или по умолчанию).
static func place(shape: Dictionary, key: String, legs: int, eyes := 2) -> Array:
	var p = shape.get("place", {}).get(key)
	return p if p is Array else default_place(key, legs, float(shape.get("torso_pitch", 0.0)), eyes, float(shape.get("head_on", 1.0)) >= 0.5)

static func dim(shape: Dictionary, key: String) -> Array:
	return shape.get("dims", {}).get(key, [1.0, 1.0, 1.0, 1.0])

## Во сколько раз часть больше обычной — по объёму (для силы).
static func dim_k(shape: Dictionary, key: String) -> float:
	var d := dim(shape, key)
	return pow(float(d[0]) * float(d[1]) * float(d[2]), 1.0 / 3.0) * float(d[3])

## Какой кусочек размеров у места: у рта — рот, у головы (рога, гребень) — рога…
static func dim_key(slot: String) -> String:
	return {"head": "horns", "mouth": "mouth", "eyes": "eyes", "back": "back", "tail": "tail"}.get(slot, "")

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
		# Изгиб: горб (+) или прогиб (−) — середина выше или ниже концов.
		var y := float(shape.get("torso_bend", 0.0)) * sin(PI * i / (SPINE - 1.0)) * L * 0.28
		out.append({"z": -L / 2.0 + L * i / (SPINE - 1.0), "y": y, "r": r, "rx": r * float(shape.get("width", 1.0)), "ry": r * float(shape.get("height", 1.0))})
	return out

## Толщина и место на позвоночнике в доле t (0 — хвост, 1 — голова).
static func spine_at(sp: Array, t: float) -> Dictionary:
	var f := clampf(t, 0.0, 1.0) * (sp.size() - 1)
	var i := mini(int(f), sp.size() - 2)
	var k := f - i
	return {"z": lerpf(sp[i].z, sp[i + 1].z, k), "y": lerpf(sp[i].get("y", 0.0), sp[i + 1].get("y", 0.0), k), "r": lerpf(sp[i].r, sp[i + 1].r, k),
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
