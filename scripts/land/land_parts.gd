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

## Что умеет тело: всё, что нужно правилам суши.
static func stats(body: Dictionary) -> Dictionary:
	var s := {"speed": 1.0, "bite": 2.0, "hp": 30.0, "armor": 0.0, "thorns": 0.0, "poison": 0.0, "regen": 0.8,
		"sight": 0.55, "fruit": 1.0, "meat": 1.0, "bone": 1.0, "reach": 0.0, "stealth": 1.0, "wade": false,
		"legs": 4, "turn": 1.0, "scare": false, "mouth": false, "long": false}
	for slot in body:
		var id: String = body[slot]
		if not PARTS.has(id):
			continue
		var p: Dictionary = PARTS[id]
		if slot == "mouth":
			s.mouth = true
		if slot == "eyes":
			s.sight = p.sight
		for k in ["speed", "fruit", "meat", "bone", "stealth", "turn"]:
			if p.has(k):
				s[k] *= float(p[k])
		for k in ["bite", "hp", "regen", "reach", "poison"]:
			if p.has(k):
				s[k] += float(p[k])
		for k in ["armor", "thorns"]:
			if p.has(k):
				s[k] = 1.0 - (1.0 - s[k]) * (1.0 - float(p[k]))
		for k in ["wade", "scare", "long"]:
			if p.has(k):
				s[k] = true
		if p.has("legs"):
			s.legs = p.legs
	return s

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
