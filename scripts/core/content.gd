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
## Углы частей — по сетке через столько градусов, глубина внутрь тела — через столько
## долей радиуса. Части стоят не теснее PART_GAP (в радиусах тела).
const ANGLE_STEP := 15
const DEPTH_STEP := 0.1
const PART_GAP := 0.42
## Форма тела: радиус в SHAPE_POINTS направлениях (0 — нос), от SHAPE_MIN до SHAPE_MAX.
const SHAPE_POINTS := 16
const SHAPE_MIN := 0.6
const SHAPE_MAX := 1.6
## Сияющая особь: редкая, пугливая, крепче обычной, и часть из неё выпадает всегда.
const GOLDEN_CHANCE := 0.03

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
##   poison — урон ядом в секунду; zap — удар током; eyes — зрение; armor_all — какую долю
##   урона снимает со всех сторон; rock — во сколько раз сильнее бьёт по камням; grab —
##   щупальце: держит и замедляет; glow — светится, видно даже в тумане.
##   source: rock — добывается только из камней; mob — есть только у существ, не выбить.
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
	"electro": {"name": "Электроклетка", "kind": "special", "cost": 60, "zap": 5.0, "inner": true,
		"hint": "Бьёт током двоих ближайших врагов"},
	"eye": {"name": "Глазок", "kind": "sense", "cost": 12, "eyes": 1.0, "inner": true,
		"hint": "Раздвигает туман: без глаз видно только то, что рядом"},
	"chloroplast": {"name": "Хлоропласт", "kind": "special", "cost": 28, "regen": 0.6, "dna_rate": 0.08, "inner": true,
		"hint": "Питается светом: лечит и понемногу даёт ДНК"},
	# Только из камней.
	"drill": {"name": "Бур", "kind": "weapon", "cost": 30, "spike": 6.0, "arc": 30, "rock": 3.0, "source": "rock",
		"hint": "Колет спереди и крошит камни втрое быстрее. Только из камней"},
	"stone_skin": {"name": "Каменная кожа", "kind": "defense", "cost": 26, "armor_all": 0.2, "speed": -10.0, "source": "rock",
		"hint": "Любой удар слабее на пятую часть. Только из камней"},
	"crystal": {"name": "Кристалл", "kind": "sense", "cost": 34, "eyes": 1.6, "glow": true, "inner": true, "source": "rock",
		"hint": "Светится изнутри и раздвигает туман сильнее глаза. Только из камней"},
	# Есть только у существ — выбить нельзя.
	"tentacle": {"name": "Щупальце", "kind": "weapon", "cost": 0, "grab": 3.0, "arc": 45, "source": "mob",
		"hint": "Хватает и замедляет. Не выбить"},
	"lantern": {"name": "Фонарик", "kind": "sense", "cost": 0, "glow": true, "source": "mob",
		"hint": "Светится — видно даже в тумане. Не выбить"},
	"plates": {"name": "Пластины", "kind": "defense", "cost": 0, "armor_all": 0.35, "source": "mob",
		"hint": "Броня со всех сторон. Не выбить"},
	"horn": {"name": "Рог", "kind": "weapon", "cost": 0, "spike": 11.0, "arc": 25, "source": "mob",
		"hint": "Бьёт с разгона. Не выбить"},
}

## Камни: их можно разбить — рывком, укусом, шипом. Из них — части, которых нет ни у кого.
## Радиус и прочность растут вместе с тобой.
const ROCKS := {
	"stone": {"name": "Камень", "radius": 20.0, "hp": 28.0, "levels": [1, 10], "weight": 3.0, "dna": 3.0,
		"color": "#7d8690", "drops": [["stone_skin", 0.12], ["drill", 0.05]]},
	"boulder": {"name": "Валун", "radius": 34.0, "hp": 80.0, "levels": [3, 10], "weight": 2.0, "dna": 9.0,
		"color": "#6f757d", "drops": [["drill", 0.18], ["stone_skin", 0.15]]},
	"crystal": {"name": "Кристальная глыба", "radius": 28.0, "hp": 120.0, "levels": [5, 10], "weight": 1.0, "dna": 16.0,
		"color": "#7fb8d8", "drops": [["crystal", 0.25], ["drill", 0.1]]},
}

## Сложность выбирается при новой игре. hurt — во сколько раз больнее тебе; drop — шанс
## выпадения частей; hunt — скорость хищников; death — какую долю пути до следующего
## размера теряешь, если съели.
const DIFFICULTY := {
	"easy": {"name": "Лёгкая", "hurt": 0.6, "drop": 1.3, "hunt": 0.85, "death": 0.0,
		"hint": "Хищники медленнее и кусают слабее, части выпадают чаще"},
	"normal": {"name": "Обычная", "hurt": 1.0, "drop": 1.0, "hunt": 1.0, "death": 0.0,
		"hint": "Как задумано"},
	"hard": {"name": "Тяжёлая", "hurt": 1.5, "drop": 0.8, "hunt": 1.12, "death": 0.25,
		"hint": "Больнее, быстрее, реже выпадает; гибель отнимает часть роста"},
}

## С чего начинает каждая новая клетка.
const START_PARTS := [{"id": "filter", "a": 0, "d": 1.0}, {"id": "cilia", "a": 180, "d": 1.0}]
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
	"zhivchik": {"name": "Живчик", "behavior": "skittish", "radius": 10.0, "color": "#6fb0d8", "shape": "oval", "tier": 1,
		"parts": [["filter", 0, 1], ["flagellum", 180, 1]], "levels": [1, 6], "weight": 3.0,
		"drops": [["flagellum", 0.3]],
		"hint": "Быстрый и пугливый: уплывает, едва заметит"},
	"kolyuchka": {"name": "Колючка", "behavior": "drifter", "radius": 15.0, "color": "#c9a24a", "shape": "star", "tier": 2,
		"parts": [["spike", 0, 1], ["spike", 180, 1], ["filter", 90, 1]], "levels": [1, 6], "weight": 3.0,
		"drops": [["spike", 0.3]],
		"hint": "Медленная, с шипами спереди и сзади. Толкай сбоку"},
	"kusaka": {"name": "Кусака", "behavior": "hunter", "radius": 14.0, "color": "#d86a5a", "tier": 2,
		"parts": [["jaws", 0, 1], ["cilia", 150, 1], ["cilia", -150, 1]], "levels": [2, 7], "weight": 3.0,
		"drops": [["jaws", 0.3], ["cilia", 0.2]],
		"hint": "Хищник: гоняется за теми, кто меньше"},
	"glazun": {"name": "Глазун", "behavior": "skittish", "radius": 14.0, "color": "#e0c070", "shape": "wide", "tier": 2,
		"parts": [["eye", -40, 1], ["eye", 40, 1], ["filter", 0, 1], ["flagellum", 180, 1]], "levels": [2, 8], "weight": 2.0,
		"drops": [["eye", 0.35], ["flagellum", 0.15]],
		"hint": "Видит издалека и сразу удирает"},
	"pantsirnik": {"name": "Панцирник", "behavior": "grazer", "radius": 19.0, "color": "#8f7fbf", "shape": "bean", "tier": 3,
		"parts": [["filter", 0, 1], ["shell", 120, 1], ["shell", -120, 1], ["cilia", 180, 1]], "levels": [3, 8], "weight": 2.5,
		"drops": [["shell", 0.3]],
		"hint": "Сзади прикрыт панцирем. Бей спереди"},
	"hobotnik": {"name": "Хоботник", "behavior": "hunter", "radius": 20.0, "color": "#d88aa8", "shape": "bean", "tier": 3,
		"parts": [["proboscis", 0, 1], ["cilia", 180, 1], ["membrane", 90, 1]], "levels": [3, 8], "weight": 2.0,
		"drops": [["proboscis", 0.3], ["membrane", 0.2]],
		"hint": "Всеядный: ест и водоросли, и мелких"},
	"yadovik": {"name": "Ядовик", "behavior": "drifter", "radius": 22.0, "color": "#9a6ad0", "shape": "blob", "tier": 3,
		"parts": [["poison", 0, 1], ["poison", 180, 1], ["filter", 90, 1], ["cilia", -90, 1]], "levels": [4, 9], "weight": 2.0,
		"drops": [["poison", 0.25]],
		"hint": "Не нападает, но касаться его — яд"},
	"listik": {"name": "Листик", "behavior": "grazer", "radius": 22.0, "color": "#5aa86a", "tier": 3,
		"parts": [["chloroplast", 90, 1], ["chloroplast", -90, 1], ["filter", 0, 1], ["cilia", 180, 1]], "levels": [4, 9], "weight": 2.0,
		"drops": [["chloroplast", 0.3]],
		"hint": "Питается светом. Мирный"},
	"klykach": {"name": "Клыкач", "behavior": "hunter", "radius": 26.0, "color": "#b8504a", "shape": "drop", "tier": 4,
		"parts": [["fangs", 0, 1], ["flagellum", 180, 1], ["cilia", 120, 1]], "levels": [5, 10], "weight": 2.0,
		"drops": [["fangs", 0.2], ["flagellum", 0.2]],
		"hint": "Опасный хищник с клыками"},
	"iskrun": {"name": "Искрун", "behavior": "drifter", "radius": 26.0, "color": "#e8d84a", "tier": 4,
		"parts": [["electro", 0, 1], ["electro", 180, 1], ["filter", 90, 1], ["cilia", -90, 1]], "levels": [6, 10], "weight": 1.5,
		"drops": [["electro", 0.2]],
		"hint": "Бьёт током всех, кто рядом"},
	"strizh": {"name": "Стриж", "behavior": "hunter", "radius": 22.0, "color": "#5a8ad8", "shape": "drop", "tier": 4,
		"parts": [["jaws", 0, 2], ["flagellum2", 180, 1]], "levels": [6, 10], "weight": 1.5,
		"drops": [["flagellum2", 0.25], ["jaws", 0.2]],
		"hint": "Очень быстрый хищник"},
	"velikan": {"name": "Шипастый великан", "behavior": "boss", "radius": 44.0, "color": "#a08a50", "shape": "star", "tier": 6,
		"parts": [["horn", 0, 1], ["spike2", 120, 1], ["spike2", -120, 1], ["shell", 60, 1], ["shell", -60, 1], ["shell", 180, 1]],
		"levels": [6, 10], "weight": 0.6, "drops": [["spike2", 0.3], ["shell", 0.3]],
		"hint": "Огромный и колючий. Ищи щель между шипами"},
	"leviafan": {"name": "Левиафан", "behavior": "boss", "radius": 60.0, "color": "#4a5a8a", "shape": "oval", "tier": 8, "hunts": true,
		"parts": [["fangs", 0, 2], ["flagellum", 180, 1], ["spike2", 90, 1], ["spike2", -90, 1], ["eye", 30, 1], ["eye", -30, 1], ["membrane", 150, 2], ["membrane", -150, 2]],
		"levels": [8, 10], "weight": 0.4, "drops": [["fangs", 0.5], ["spike2", 0.3], ["eye", 0.3], ["membrane", 0.3]],
		"hint": "Гроза первичного океана"},
	# С частями, которых не выбить.
	"fonarshik": {"name": "Фонарщик", "behavior": "drifter", "radius": 17.0, "color": "#5a6ab0", "shape": "drop", "tier": 2,
		"parts": [["lantern", 0, 1], ["filter", 60, 1], ["cilia", 180, 1]], "levels": [2, 9], "weight": 2.0,
		"drops": [["filter", 0.2], ["cilia", 0.2]],
		"hint": "Светится — видно даже в тумане. Фонарик не выбить"},
	"shchupalets": {"name": "Щупальцевик", "behavior": "hunter", "radius": 23.0, "color": "#a05a8a", "shape": "bean", "tier": 4,
		"parts": [["tentacle", 0, 1], ["tentacle", 45, 1], ["tentacle", -45, 1], ["jaws", 180, 1], ["cilia", 120, 1]], "levels": [4, 10], "weight": 1.5,
		"drops": [["jaws", 0.25], ["cilia", 0.25]],
		"hint": "Хватает щупальцами и держит. Щупальца не выбить"},
	"bronenosets": {"name": "Броненосец", "behavior": "grazer", "radius": 27.0, "color": "#8a8a70", "shape": "oval", "tier": 4,
		"parts": [["plates", 90, 1], ["plates", -90, 1], ["filter", 0, 1], ["cilia", 180, 1]], "levels": [5, 10], "weight": 1.5,
		"drops": [["filter", 0.25], ["cilia", 0.25]],
		"hint": "В броне со всех сторон. Пластины не выбить"},
	# Великаны — всегда во много раз больше тебя.
	"gigant": {"name": "Гигантская амёба", "behavior": "giant", "radius": 16.0, "scale": 4.0, "color": "#6a9a8a", "shape": "blob", "tier": 5,
		"parts": [["filter", 0, 1], ["cilia", 120, 1], ["cilia", -120, 1], ["membrane", 180, 2]], "levels": [1, 10], "weight": 0.5,
		"drops": [["membrane", 0.5], ["cilia", 0.3]],
		"hint": "Огромная и мирная. Плывёт по своим делам"},
	"pozhiratel": {"name": "Пожиратель", "behavior": "giant", "hunts": true, "radius": 16.0, "scale": 3.2, "color": "#6a3a4a", "shape": "drop", "tier": 7,
		"parts": [["jaws", 0, 2], ["tentacle", 40, 1], ["tentacle", -40, 1], ["cilia", 180, 1], ["plates", 150, 1], ["plates", -150, 1]],
		"levels": [3, 10], "weight": 0.25, "drops": [["jaws", 0.6], ["cilia", 0.4]],
		"hint": "Великан-хищник. Медленный — от него можно уплыть. Щупальца и пластины не выбить"},
}

## Цвета тела на выбор в редакторе.
const COLORS := ["#8fd07a", "#6fc0e0", "#e0b060", "#e07a6a", "#b08ae0", "#e890b8", "#7ad0b0", "#d8d8c8"]

## Задачи — тропинка для начала, а не обязанность.
const GOALS := [
	{"id": "eat", "title": "Съешь 10 водорослей", "hint": "Плыви к зелёным крупинкам — это еда"},
	{"id": "grow", "title": "Подрасти", "hint": "Еда даёт ДНК. Наберёшь 40 — клетка вырастет"},
	{"id": "kill", "title": "Одолей другую клетку", "hint": "«Рывок» — удар с разгона. Им можно сбить мелкую клетку"},
	{"id": "part", "title": "Добудь новую часть", "hint": "Части выпадают из тех, у кого они есть. Не всегда!"},
	{"id": "edit", "title": "Поставь часть на тело", "hint": "Нажми ♥ — стрелка покажет, где пара. Доплыви до неё — и меняй тело"},
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

## Форма по названию — для видов и для кнопок редактора. 1.0 — круг.
static func shape_preset(name: String) -> Array:
	var out: Array = []
	for i in SHAPE_POINTS:
		var a := TAU * i / SHAPE_POINTS  # 0 — нос
		var v := 1.0
		match name:
			"oval":
				v = 0.78 + 0.42 * cos(a) * cos(a)
			"wide":
				v = 0.78 + 0.42 * sin(a) * sin(a)
			"drop":
				# Тупой нос, хвост вытянут назад.
				v = 1.0 - 0.18 * cos(a) + 0.2 * maxf(0.0, -cos(a)) * maxf(0.0, -cos(a))
			"star":
				v = 1.0 + 0.22 * cos(4.0 * a)
			"bean":
				v = 1.0 + 0.16 * cos(2.0 * a) - 0.12 * sin(a)
			"blob":
				v = 1.0 + 0.1 * sin(3.0 * a + 0.7) + 0.07 * cos(5.0 * a)
		out.append(clampf(v, SHAPE_MIN, SHAPE_MAX))
	return out

## Радиус формы в направлении a (радианы от носа): плавно между опорными точками.
static func shape_at(shape: Array, a: float) -> float:
	if shape.is_empty():
		return 1.0
	var n := shape.size()
	var x := fposmod(a / TAU * n, n)
	var i := int(floor(x))
	var t := x - i
	var p0: float = shape[(i - 1 + n) % n]
	var p1: float = shape[i % n]
	var p2: float = shape[(i + 1) % n]
	var p3: float = shape[(i + 2) % n]
	# Катмулл — Ром: кривая проходит через все точки и не ломается на стыках.
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)

## Во сколько раз тело этой формы «весит» против круга: от средней величины, в пределах.
static func shape_scale(shape: Array) -> float:
	if shape.is_empty():
		return 1.0
	var sum := 0.0
	for v in shape:
		sum += v
	return clampf(sum / shape.size(), 0.8, 1.25)

## Можно ли вообще получить эту часть (а не только увидеть у существ).
static func obtainable(id: String) -> bool:
	return PARTS[id].get("source", "") != "mob"

## Камни, из которых выпадает часть, — для подсказки «где взять».
static func rock_sources(part: String) -> Array:
	var out: Array = []
	for rid in ROCKS:
		for d in ROCKS[rid].drops:
			if d[0] == part:
				out.append([rid, d[1]])
	return out

