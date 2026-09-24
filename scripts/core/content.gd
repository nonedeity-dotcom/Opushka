## Всё, из чего состоит первичный океан: части тела, виды клеток, размеры, задачи.
##
## Здесь только справочники, без логики. Новая часть или новый вид — новая строка здесь.
## Ключи попадают в сохранение: подпись менять можно, ключ — нет.
class_name Content
extends RefCounted

## Сколько ДНК даётся на старте — ровно на стартовые фильтр и реснички.
const START_DNA := 10
## Уровень части растёт от повторных находок: +20% силы за уровень, до пятого.
const PART_MAX_LEVEL := 5
const PART_LEVEL_BONUS := 0.2
## Части на теле стоят не теснее этого (градусы), и углы — по сетке через столько же.
const PART_SPACING := 25
const ANGLE_STEP := 15

## Размеры клетки: сколько ДНК нужно накопить за всё время и какой становится радиус.
const LEVELS := [
	{"dna": 0, "radius": 16.0},
	{"dna": 40, "radius": 18.0},
	{"dna": 120, "radius": 21.0},
	{"dna": 250, "radius": 24.0},
	{"dna": 440, "radius": 27.0},
	{"dna": 700, "radius": 31.0},
	{"dna": 1050, "radius": 35.0},
	{"dna": 1500, "radius": 40.0},
	{"dna": 2050, "radius": 45.0},
	{"dna": 2800, "radius": 51.0},
]

## Части тела. kind: mouth — рот (один на тело, он и решает, чем питаться), move, weapon,
## defense, sense, special. Числа — на первом уровне части.
##   diet: plant / meat / both — что ест рот; eat_plant / eat_meat — сколько ДНК с еды (доля);
##   bite — укус; spike — укол шипом; arc — в пределах скольки градусов от части она
##   действует; speed, turn — скорость и поворот; armor — какую долю урона панцирь снимает
##   со своей стороны; hp — здоровье; regen — лечение в секунду; dna_rate — ДНК в секунду;
##   poison — урон ядом в секунду; zap — удар током; eyes — зрение.
const PARTS := {
	"filter": {"name": "Фильтр", "kind": "mouth", "cost": 4, "diet": "plant", "eat_plant": 1.0, "arc": 75,
		"hint": "Травоядный рот: ест водоросли"},
	"jaws": {"name": "Челюсти", "kind": "mouth", "cost": 16, "diet": "meat", "eat_meat": 1.0, "bite": 5.0, "arc": 55,
		"hint": "Хищный рот: кусает и ест мясо"},
	"fangs": {"name": "Клыки", "kind": "mouth", "cost": 40, "diet": "meat", "eat_meat": 1.2, "bite": 9.0, "arc": 55,
		"hint": "Хищный рот посильнее: кусает больно"},
	"proboscis": {"name": "Хоботок", "kind": "mouth", "cost": 20, "diet": "both", "eat_plant": 0.6, "eat_meat": 0.6, "bite": 2.0, "arc": 60,
		"hint": "Всеядный: понемногу ест и водоросли, и мясо"},
	"cilia": {"name": "Реснички", "kind": "move", "cost": 6, "speed": 10.0, "turn": 1.2,
		"hint": "Немного быстрее и вертлявее"},
	"flagellum": {"name": "Жгутик", "kind": "move", "cost": 18, "speed": 28.0,
		"hint": "Плывёшь заметно быстрее"},
	"flagellum2": {"name": "Мощный жгутик", "kind": "move", "cost": 50, "speed": 50.0,
		"hint": "Очень быстро"},
	"spike": {"name": "Шип", "kind": "weapon", "cost": 14, "spike": 4.0, "arc": 35,
		"hint": "Колет того, кто коснулся с этой стороны"},
	"spike2": {"name": "Большой шип", "kind": "weapon", "cost": 40, "spike": 8.0, "arc": 40,
		"hint": "Колет сильнее и шире"},
	"shell": {"name": "Панцирь", "kind": "defense", "cost": 22, "armor": 0.5, "arc": 55, "speed": -8.0,
		"hint": "Удары с этой стороны вдвое слабее. Чуть медленнее"},
	"membrane": {"name": "Толстая мембрана", "kind": "defense", "cost": 18, "hp": 8.0,
		"hint": "Больше здоровья"},
	"poison": {"name": "Ядовитая железа", "kind": "weapon", "cost": 35, "poison": 2.0, "arc": 70,
		"hint": "Кто коснулся — отравлен на 3 секунды"},
	"electro": {"name": "Электроклетка", "kind": "special", "cost": 60, "zap": 5.0,
		"hint": "Бьёт током двоих ближайших врагов"},
	"eye": {"name": "Глазок", "kind": "sense", "cost": 12, "eyes": 1.0,
		"hint": "Видишь дальше и замечаешь хищников заранее"},
	"chloroplast": {"name": "Хлоропласт", "kind": "special", "cost": 28, "regen": 0.6, "dna_rate": 0.08,
		"hint": "Питается светом: лечит и понемногу даёт ДНК"},
}

## С чего начинает каждая новая клетка.
const START_PARTS := [{"id": "filter", "a": 0}, {"id": "cilia", "a": 180}]
const START_UNLOCKED := {"filter": 1, "cilia": 1}

## Виды клеток. behavior: grazer — мирный, ест водоросли, убегает от опасных; skittish —
## пугливый, удирает издалека; drifter — медленно дрейфует и защищается; hunter — хищник,
## гоняется за теми, кто меньше; boss — огромный, разворачивается к обидчику.
## parts: [часть, угол в градусах (0 — перёд, 90 — правый бок), уровень].
## levels: на каких размерах игрока встречается. drops: [часть, шанс] — только из того, что
## у вида есть: клыки выпадают из того, у кого клыки.
const SPECIES := {
	"kroshka": {"name": "Крошка", "behavior": "grazer", "radius": 7.0, "color": "#9fd4a0", "tier": 0,
		"parts": [["cilia", 180, 1]], "levels": [1, 10], "weight": 3.0, "drops": [["cilia", 0.08]],
		"hint": "Совсем кроха. Еда для хищников"},
	"zelenka": {"name": "Зелёнка", "behavior": "grazer", "radius": 11.0, "color": "#7fbf6a", "tier": 1,
		"parts": [["filter", 0, 1], ["cilia", 180, 1], ["membrane", 120, 1]], "levels": [1, 5], "weight": 5.0,
		"drops": [["membrane", 0.2], ["cilia", 0.25], ["filter", 0.2]],
		"hint": "Мирная травоядная клетка. Лёгкая добыча"},
	"zhivchik": {"name": "Живчик", "behavior": "skittish", "radius": 10.0, "color": "#6fb0d8", "tier": 1,
		"parts": [["filter", 0, 1], ["flagellum", 180, 1]], "levels": [1, 6], "weight": 3.0,
		"drops": [["flagellum", 0.3]],
		"hint": "Быстрый и пугливый: уплывает, едва заметит"},
	"kolyuchka": {"name": "Колючка", "behavior": "drifter", "radius": 15.0, "color": "#c9a24a", "tier": 2,
		"parts": [["spike", 0, 1], ["spike", 180, 1], ["filter", 90, 1]], "levels": [1, 6], "weight": 3.0,
		"drops": [["spike", 0.3]],
		"hint": "Медленная, с шипами спереди и сзади. Толкай сбоку"},
	"kusaka": {"name": "Кусака", "behavior": "hunter", "radius": 14.0, "color": "#d86a5a", "tier": 2,
		"parts": [["jaws", 0, 1], ["cilia", 150, 1], ["cilia", -150, 1]], "levels": [2, 7], "weight": 3.0,
		"drops": [["jaws", 0.3], ["cilia", 0.2]],
		"hint": "Хищник: гоняется за теми, кто меньше"},
	"glazun": {"name": "Глазун", "behavior": "skittish", "radius": 14.0, "color": "#e0c070", "tier": 2,
		"parts": [["eye", -40, 1], ["eye", 40, 1], ["filter", 0, 1], ["flagellum", 180, 1]], "levels": [2, 8], "weight": 2.0,
		"drops": [["eye", 0.35], ["flagellum", 0.15]],
		"hint": "Видит издалека и сразу удирает"},
	"pantsirnik": {"name": "Панцирник", "behavior": "grazer", "radius": 19.0, "color": "#8f7fbf", "tier": 3,
		"parts": [["filter", 0, 1], ["shell", 120, 1], ["shell", -120, 1], ["cilia", 180, 1]], "levels": [3, 8], "weight": 2.5,
		"drops": [["shell", 0.3]],
		"hint": "Сзади прикрыт панцирем. Бей спереди"},
	"hobotnik": {"name": "Хоботник", "behavior": "hunter", "radius": 20.0, "color": "#d88aa8", "tier": 3,
		"parts": [["proboscis", 0, 1], ["cilia", 180, 1], ["membrane", 90, 1]], "levels": [3, 8], "weight": 2.0,
		"drops": [["proboscis", 0.3], ["membrane", 0.2]],
		"hint": "Всеядный: ест и водоросли, и мелких"},
	"yadovik": {"name": "Ядовик", "behavior": "drifter", "radius": 22.0, "color": "#9a6ad0", "tier": 3,
		"parts": [["poison", 0, 1], ["poison", 180, 1], ["filter", 90, 1], ["cilia", -90, 1]], "levels": [4, 9], "weight": 2.0,
		"drops": [["poison", 0.25]],
		"hint": "Не нападает, но касаться его — яд"},
	"listik": {"name": "Листик", "behavior": "grazer", "radius": 22.0, "color": "#5aa86a", "tier": 3,
		"parts": [["chloroplast", 90, 1], ["chloroplast", -90, 1], ["filter", 0, 1], ["cilia", 180, 1]], "levels": [4, 9], "weight": 2.0,
		"drops": [["chloroplast", 0.3]],
		"hint": "Питается светом. Мирный"},
	"klykach": {"name": "Клыкач", "behavior": "hunter", "radius": 26.0, "color": "#b8504a", "tier": 4,
		"parts": [["fangs", 0, 1], ["flagellum", 180, 1], ["cilia", 120, 1]], "levels": [5, 10], "weight": 2.0,
		"drops": [["fangs", 0.2], ["flagellum", 0.2]],
		"hint": "Опасный хищник с клыками"},
	"iskrun": {"name": "Искрун", "behavior": "drifter", "radius": 26.0, "color": "#e8d84a", "tier": 4,
		"parts": [["electro", 0, 1], ["electro", 180, 1], ["filter", 90, 1], ["cilia", -90, 1]], "levels": [6, 10], "weight": 1.5,
		"drops": [["electro", 0.2]],
		"hint": "Бьёт током всех, кто рядом"},
	"strizh": {"name": "Стриж", "behavior": "hunter", "radius": 22.0, "color": "#5a8ad8", "tier": 4,
		"parts": [["jaws", 0, 2], ["flagellum2", 180, 1]], "levels": [6, 10], "weight": 1.5,
		"drops": [["flagellum2", 0.25], ["jaws", 0.2]],
		"hint": "Очень быстрый хищник"},
	"velikan": {"name": "Шипастый великан", "behavior": "boss", "radius": 44.0, "color": "#a08a50", "tier": 6,
		"parts": [["spike2", 0, 1], ["spike2", 120, 1], ["spike2", -120, 1], ["shell", 60, 1], ["shell", -60, 1], ["shell", 180, 1]],
		"levels": [6, 10], "weight": 0.6, "drops": [["spike2", 0.3], ["shell", 0.3]],
		"hint": "Огромный и колючий. Ищи щель между шипами"},
	"leviafan": {"name": "Левиафан", "behavior": "boss", "radius": 60.0, "color": "#4a5a8a", "tier": 8, "hunts": true,
		"parts": [["fangs", 0, 2], ["flagellum", 180, 1], ["spike2", 90, 1], ["spike2", -90, 1], ["eye", 30, 1], ["eye", -30, 1], ["membrane", 150, 2], ["membrane", -150, 2]],
		"levels": [8, 10], "weight": 0.4, "drops": [["fangs", 0.5], ["spike2", 0.3], ["eye", 0.3], ["membrane", 0.3]],
		"hint": "Гроза первичного океана"},
}

## Цвета тела на выбор в редакторе.
const COLORS := ["#8fd07a", "#6fc0e0", "#e0b060", "#e07a6a", "#b08ae0", "#e890b8", "#7ad0b0", "#d8d8c8"]

## Задачи — тропинка для начала, а не обязанность.
const GOALS := [
	{"id": "eat", "title": "Съешь 10 водорослей", "hint": "Плыви к зелёным крупинкам — это еда"},
	{"id": "grow", "title": "Подрасти", "hint": "Еда даёт ДНК. Наберёшь 40 — клетка вырастет"},
	{"id": "kill", "title": "Одолей другую клетку", "hint": "«Рывок» — удар с разгона. Им можно сбить мелкую клетку"},
	{"id": "part", "title": "Добудь новую часть", "hint": "Части выпадают из тех, у кого они есть. Не всегда!"},
	{"id": "edit", "title": "Поставь часть на тело", "hint": "Кнопка «Эволюция» — выбери часть и нажми на край клетки"},
	{"id": "diet", "title": "Выбери, кем быть", "hint": "Челюсти — хищник, фильтр — травоядный, хоботок — всеядный"},
	{"id": "upgrade", "title": "Улучши часть", "hint": "Та же часть ещё раз — и она становится сильнее"},
	{"id": "size5", "title": "Вырасти до 5-го размера", "hint": "Чем больше, тем крупнее соседи"},
	{"id": "parts8", "title": "Собери 8 разных частей", "hint": "Загляни в «Атлас»: кто что роняет"},
	{"id": "boss", "title": "Одолей великана", "hint": "Шипастый великан или Левиафан — с 6-го размера"},
	{"id": "size10", "title": "Стань многоклеточным", "hint": "10-й размер — вершина этого этапа"},
]

static func level_for(dna_total: float) -> int:
	var lvl := 1
	for i in LEVELS.size():
		if dna_total >= LEVELS[i].dna:
			lvl = i + 1
	return lvl

static func radius_for(level: int) -> float:
	return LEVELS[clampi(level, 1, LEVELS.size()) - 1].radius

## Сколько частей помещается на тело этого размера.
static func slots_for(level: int) -> int:
	return 2 + level

static func is_mouth(id: String) -> bool:
	return PARTS.get(id, {}).get("kind", "") == "mouth"

## Множитель силы части её уровня.
static func power(level: int) -> float:
	return 1.0 + PART_LEVEL_BONUS * (clampi(level, 1, PART_MAX_LEVEL) - 1)

## Виды, у которых эта часть выпадает, — для подсказки «где взять».
static func sources(part: String) -> Array:
	var out: Array = []
	for sid in SPECIES:
		for d in SPECIES[sid].drops:
			if d[0] == part:
				out.append([sid, d[1]])
	return out

## «Удары вдвое слабее. Чуть медленнее» → «удары вдвое слабее. Чуть медленнее»: строчной
## делается только первая буква, чтобы подсказку можно было вставить в середину фразы.
static func lc_first(text: String) -> String:
	return text.left(1).to_lower() + text.substr(1)

