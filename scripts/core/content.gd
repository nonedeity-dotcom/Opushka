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

## Редкие события в океане: на минуту-другую меняют всё вокруг. len — сколько длится (с).
const EVENTS := {
	"bloom": {"name": "Цветение", "hint": "Вода светится, водорослей втрое больше — ешь, пока есть", "len": 70.0, "end": "Цветение кончилось", "icon": "leaf", "color": "#9fe08a"},
	"storm": {"name": "Буря", "hint": "Сильное течение сносит всех. Плыви поперёк или пережди", "len": 45.0, "end": "Буря утихла", "icon": "dash", "color": "#9fc8e8"},
	"dead": {"name": "Мёртвая зона", "hint": "Темно и тихо, живых мало — зато сияющие попадаются чаще", "len": 60.0, "end": "Мёртвая зона позади", "icon": "eye_off", "color": "#b09ad0"},
	"spawn": {"name": "Нерест", "hint": "Приплыли стайки малышей — лёгкая добыча", "len": 50.0, "end": "Нерест кончился", "icon": "heart", "color": "#f0b8a0"},
}

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
	"electro": {"name": "Электроклетка", "kind": "special", "cost": 60, "zap": 4.0, "inner": true,
		"hint": "Бьёт током двоих ближайших врагов, но не больше трети их здоровья за раз. Ещё одна электроклетка — +1 цель и лишь чуть сильнее"},
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
	# Для разных вод.
	"thermo": {"name": "Термооболочка", "kind": "defense", "cost": 20, "heatproof": true, "source": "mob",
		"hint": "Часть огневиков и пузырников. Не выбить"},
	"fat": {"name": "Жировая капля", "kind": "defense", "cost": 16, "coldproof": true, "hp": 5.0, "inner": true, "source": "mob",
		"hint": "Часть ледянок и морозников. Не выбить"},
	"sucker": {"name": "Присоска", "kind": "weapon", "cost": 24, "drain": 3.0, "arc": 40,
		"hint": "Тянет здоровье из того, кого коснулась, и лечит тебя"},
	"camo": {"name": "Хроматофоры", "kind": "special", "cost": 30, "camo": 0.45, "inner": true, "source": "mob",
		"hint": "Маскировка: хищники замечают позже. Тебе — в магазине: «Маскировка»"},
	# Умения — по отдельной кнопке. Работает одно: первое на теле.
	"ink": {"name": "Чернильный мешок", "kind": "ability", "cost": 22, "ability": "ink", "cooldown": 12.0, "inner": true,
		"hint": "Умение: облако чернил — враги теряют тебя из виду"},
	"shield_gland": {"name": "Щит-железа", "kind": "ability", "cost": 30, "ability": "shield", "cooldown": 16.0, "inner": true,
		"hint": "Умение: три секунды почти не ранят"},
	"pulse": {"name": "Импульсник", "kind": "ability", "cost": 40, "ability": "pulse", "cooldown": 10.0, "inner": true,
		"hint": "Умение: удар током по всем вокруг и отброс"},
	"suction": {"name": "Всасыватель", "kind": "ability", "cost": 18, "ability": "suck", "cooldown": 8.0, "inner": true,
		"hint": "Умение: вся еда вокруг сама плывёт к тебе"},
	# Награды хозяев логов.
	"life_core": {"name": "Ядро жизни", "kind": "special", "cost": 45, "regen": 2.0, "inner": true,
		"hint": "Быстро лечит. Награда Королевы глубин"},
	"thorn_armor": {"name": "Шипастая броня", "kind": "defense", "cost": 40, "thorns": 0.35, "armor_all": 0.1,
		"hint": "Кто бьёт тебя — получает треть удара обратно. Награда Колючего стража"},
	"sac": {"name": "Толчковый пузырь", "kind": "move", "cost": 8, "dash": true,
		"hint": "Даёт рывок — удар с разгона: сбить мелкую клетку, разбить камень, стряхнуть паразита"},
	# Стреляют сами, когда впереди (в пределах дуги) враг: плевок ядом и игла.
	"spit": {"name": "Плевательная железа", "kind": "weapon", "cost": 30, "arc": 35, "gun": "spit", "range": 270.0, "reload": 2.4, "dmg": 2.0, "poison": 2.0,
		"hint": "Плюётся ядом во врага впереди — сама, издалека. Каждая следующая стрелковая часть — лишь на треть силы. У плевунов"},
	"needle": {"name": "Игломёт", "kind": "weapon", "cost": 34, "arc": 30, "gun": "needle", "range": 300.0, "reload": 1.8, "dmg": 5.0,
		"hint": "Стреляет иглами во врага впереди — сама, издалека. Каждая следующая стрелковая часть — лишь на треть силы. У иглострелов"},
	"claw": {"name": "Клешня", "kind": "weapon", "cost": 28, "spike": 7.0, "grab": 1.5, "arc": 35,
		"hint": "Щиплет и держит: схваченный плывёт медленнее. У клешнецов"},
	"firefly": {"name": "Светлячок", "kind": "sense", "cost": 20, "glow": true, "light": 1.35, "inner": true,
		"hint": "Светится: туман вокруг расступается шире. У фонарщиков и удильщиков"},
	"remora": {"name": "Прилипала", "kind": "special", "cost": 22, "remora": true, "arc": 55,
		"hint": "Коснись этой стороной крупного — прилипнешь и будешь есть с него крохи. Рывок или ход прочь — отцепиться"},
	"baleen": {"name": "Китовый ус", "kind": "mouth", "cost": 45, "diet": "both", "eat_plant": 1.4, "eat_meat": 1.2, "bite": 4.0, "arc": 70,
		"hint": "Лучший рот для всеядных. Только со Старого кита"},
	"serpent": {"name": "Змеиный хвост", "kind": "move", "cost": 45, "speed": 55.0, "turn": 1.5, "dash_k": 0.75, "dash": true,
		"hint": "Очень быстрый и с сильным рывком. Только с Морского змея"},
	"jet": {"name": "Реактивный мешок", "kind": "move", "cost": 35, "dash_k": 0.6, "dash": true,
		"hint": "Рывок сильнее и перезаряжается быстрее. Награда Ледяного вихря"},
}

## Цвет воды по размеру: на каждом размере — свой оттенок (бирюза, синева, зелень…),
## яркость одна и та же. Только вид — на игру не влияет. [верх, низ] на каждый размер.
const WATER := [["#30808c", "#0a2b30"], ["#305e8c", "#0a1d30"], ["#308c6d", "#0a3024"], ["#303f8c", "#0a1030"], ["#308c4f", "#0a3017"], ["#3f308c", "#100a30"], ["#308c89", "#0a302f"], ["#306d8c", "#0a2430"], ["#308c5e", "#0a301d"], ["#304f8c", "#0a1730"]]

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
## размера теряешь, если съели. Дальше — повадки хищников, а не только сила удара:
## sight — издалека ли тебя замечают, chase — сколько гонятся не выдыхаясь, grow — как
## быстро хищники растут вместе с тобой (степень; у мирных всегда 0,6), regen — как быстро
## заживают твои раны, pack — шанс, что хищник приплывёт вдвоём.
const DIFFICULTY := {
	"easy": {"name": "Лёгкая", "hurt": 0.6, "drop": 1.3, "hunt": 0.85, "death": 0.0, "aggro": 0.6, "vision": 1.1,
		"sight": 0.85, "chase": 0.8, "grow": 0.55, "regen": 1.3, "pack": 0.0,
		"hint": "Хищников меньше, кусают слабее, части выпадают чаще"},
	"normal": {"name": "Обычная", "hurt": 1.0, "drop": 1.0, "hunt": 1.0, "death": 0.0, "aggro": 1.0, "vision": 1.0,
		"sight": 1.0, "chase": 1.0, "grow": 0.6, "regen": 1.0, "pack": 0.0,
		"hint": "Как задумано"},
	"hard": {"name": "Тяжёлая", "hurt": 1.5, "drop": 0.8, "hunt": 1.12, "death": 0.25, "aggro": 1.4, "vision": 1.0,
		"sight": 1.25, "chase": 1.5, "grow": 0.72, "regen": 0.65, "pack": 0.3,
		"hint": "Хищники замечают издалека, гонятся дольше, ходят парами и растут вместе с тобой; раны заживают медленно; гибель отнимает часть роста"},
	"insane": {"name": "Сверхсложная", "hurt": 2.0, "drop": 0.7, "hunt": 1.25, "death": 0.0, "aggro": 2.2, "vision": 0.85, "permadeath": true,
		"sight": 1.5, "chase": 2.0, "grow": 0.8, "regen": 0.4, "pack": 0.6,
		"hint": "Одна жизнь: съели — вид исчезнет навсегда. Хищников вдвое больше, туман гуще"},
}

## С чего начинает каждая новая клетка.
const START_PARTS := [{"id": "filter", "a": 0, "d": 1.0}, {"id": "cilia", "a": 180, "d": 1.0}]
## Толчковый пузырь открыт сразу, но не стоит: рывок появится, когда поставишь его сам.
const START_UNLOCKED := {"filter": 1, "cilia": 1, "sac": 1}

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
		"parts": [["filter", 0, 1], ["flagellum", 180, 1], ["sac", 150, 1]], "levels": [1, 6], "weight": 3.0,
		"drops": [["flagellum", 0.3], ["sac", 0.25]],
		"hint": "Быстрый и пугливый: уплывает, едва заметит"},
	"kolyuchka": {"name": "Колючка", "behavior": "drifter", "radius": 15.0, "color": "#c9a24a", "shape": "star", "tier": 2,
		"parts": [["spike", 0, 1], ["spike", 180, 1], ["filter", 90, 1]], "levels": [1, 6], "weight": 3.0,
		"drops": [["spike", 0.3]],
		"hint": "Медленная, с шипами спереди и сзади. Толкай сбоку"},
	"kusaka": {"name": "Кусака", "behavior": "hunter", "radius": 14.0, "color": "#d86a5a", "tier": 2,
		"parts": [["jaws", 0, 1], ["cilia", 150, 1], ["cilia", -150, 1]], "levels": [2, 7], "weight": 3.0,
		"drops": [["jaws", 0.3], ["cilia", 0.2]],
		"hint": "Хищник: гоняется за теми, кто меньше"},
	"glazun": {"name": "Глазун", "behavior": "grazer", "radius": 14.0, "color": "#e0c070", "shape": "wide", "tier": 2,
		"parts": [["eye", -40, 1], ["eye", 40, 1], ["filter", 0, 1], ["cilia", 180, 1]], "levels": [1, 8], "weight": 3.5,
		"drops": [["eye", 0.5], ["cilia", 0.15]],
		"hint": "Видит издалека, но плавает медленно — догнать можно. Глаз выпадает часто"},
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
		"parts": [["electro", 0, 1], ["electro", 180, 1], ["filter", 90, 1], ["cilia", -90, 1], ["pulse", 45, 1]], "levels": [6, 10], "weight": 1.5,
		"drops": [["electro", 0.2], ["pulse", 0.15]],
		"hint": "Бьёт током всех, кто рядом"},
	"strizh": {"name": "Стриж", "behavior": "hunter", "radius": 22.0, "color": "#5a8ad8", "shape": "drop", "tier": 4,
		"parts": [["jaws", 0, 2], ["flagellum2", 180, 1]], "levels": [6, 10], "weight": 1.5,
		"drops": [["flagellum2", 0.25], ["jaws", 0.2]],
		"hint": "Очень быстрый хищник"},
	"velikan": {"name": "Шипастый великан", "behavior": "roamer", "radius": 16.0, "scale": 2.6, "color": "#a08a50", "shape": "star", "tier": 6,
		"parts": [["horn", 0, 1], ["spike2", 120, 1], ["spike2", -120, 1], ["shell", 60, 1], ["shell", -60, 1], ["shell", 180, 1]],
		"levels": [6, 10], "weight": 0.0, "drops": [["spike2", 0.5], ["shell", 0.4]],
		"hint": "Бродячий гигант, огромный и колючий. Сам не нападает. Ищи щель между шипами"},
	"leviafan": {"name": "Левиафан", "behavior": "roamer", "radius": 16.0, "scale": 3.0, "color": "#4a5a8a", "shape": "oval", "tier": 8, "hunts": true,
		"parts": [["fangs", 0, 2], ["flagellum", 180, 1], ["spike2", 90, 1], ["spike2", -90, 1], ["eye", 30, 1], ["eye", -30, 1], ["membrane", 150, 2], ["membrane", -150, 2]],
		"levels": [8, 10], "weight": 0.0, "drops": [["fangs", 0.6], ["spike2", 0.4], ["eye", 0.4], ["membrane", 0.4]],
		"hint": "Бродячий гигант, гроза первичного океана: охотится на всех"},
	# С частями, которых не выбить.
	"fonarshik": {"name": "Фонарщик", "behavior": "drifter", "radius": 17.0, "color": "#5a6ab0", "shape": "drop", "tier": 2,
		"parts": [["lantern", 0, 1], ["filter", 60, 1], ["cilia", 180, 1], ["eye", -40, 1], ["firefly", 40, 1]], "levels": [2, 9], "weight": 2.0,
		"drops": [["eye", 0.25], ["firefly", 0.2], ["filter", 0.2], ["cilia", 0.2]],
		"hint": "Светится — видно даже в тумане. Фонарик не выбить"},
	"shchupalets": {"name": "Щупальцевик", "behavior": "hunter", "radius": 23.0, "color": "#a05a8a", "shape": "bean", "tier": 4,
		"parts": [["tentacle", 0, 1], ["tentacle", 45, 1], ["tentacle", -45, 1], ["jaws", 180, 1], ["cilia", 120, 1]], "levels": [4, 10], "weight": 1.5,
		"drops": [["jaws", 0.25], ["cilia", 0.25]],
		"hint": "Хватает щупальцами и держит. Щупальца не выбить"},
	"bronenosets": {"name": "Броненосец", "behavior": "grazer", "radius": 27.0, "color": "#8a8a70", "shape": "oval", "tier": 4,
		"parts": [["plates", 90, 1], ["plates", -90, 1], ["filter", 0, 1], ["cilia", 180, 1], ["shield_gland", 45, 1]], "levels": [5, 10], "weight": 1.5,
		"drops": [["filter", 0.25], ["cilia", 0.25], ["shield_gland", 0.15]],
		"hint": "В броне со всех сторон. Пластины не выбить"},
	# Великаны — всегда во много раз больше тебя.
	"gigant": {"name": "Гигантская амёба", "behavior": "roamer", "radius": 16.0, "scale": 4.0, "color": "#6a9a8a", "shape": "blob", "tier": 5,
		"parts": [["filter", 0, 1], ["cilia", 120, 1], ["cilia", -120, 1], ["membrane", 180, 2], ["suction", 60, 1]], "levels": [1, 10], "weight": 0.0,
		"drops": [["membrane", 0.5], ["cilia", 0.3], ["suction", 0.3]],
		"hint": "Огромная и мирная. Плывёт по своим делам"},
	"pozhiratel": {"name": "Пожиратель", "behavior": "roamer", "hunts": true, "radius": 16.0, "scale": 3.2, "color": "#6a3a4a", "shape": "drop", "tier": 7,
		"parts": [["jaws", 0, 2], ["tentacle", 40, 1], ["tentacle", -40, 1], ["cilia", 180, 1], ["plates", 150, 1], ["plates", -150, 1]],
		"levels": [3, 10], "weight": 0.0, "drops": [["jaws", 0.6], ["cilia", 0.4]],
		"hint": "Великан-хищник. Медленный — от него можно уплыть. Щупальца и пластины не выбить"},
	# Стаи: плавают косяком. school — сколько в стае.
	"malki": {"name": "Мальки", "behavior": "grazer", "radius": 7.0, "color": "#bfe8a0", "shape": "oval", "tier": 0, "school": 3,
		"parts": [["filter", 0, 1], ["cilia", 180, 1]], "levels": [1, 10], "weight": 2.0,
		"drops": [["cilia", 0.1]], "hint": "Плавают стайкой по двое-трое и разбегаются веером"},
	"zubastiki": {"name": "Зубастики", "behavior": "hunter", "radius": 9.0, "color": "#e07070", "shape": "drop", "tier": 1, "school": 3, "aggro": true,
		"parts": [["jaws", 0, 1], ["cilia", 180, 1]], "levels": [3, 9], "weight": 1.3,
		"drops": [["jaws", 0.12]], "hint": "Охотятся по двое-трое — одного не боятся, стайки бойся"},
	# Агрессивные: бросаются даже на тех, кто крупнее.
	"ostrozub": {"name": "Острозуб", "behavior": "hunter", "radius": 12.0, "color": "#e0806a", "shape": "drop", "tier": 2, "aggro": true,
		"parts": [["jaws", 0, 1], ["flagellum", 180, 1]], "levels": [2, 6], "weight": 2.2,
		"drops": [["jaws", 0.25], ["flagellum", 0.15]], "hint": "Злой и быстрый: кидается даже на тех, кто больше"},
	"zhalilshik": {"name": "Жалильщик", "behavior": "hunter", "radius": 18.0, "color": "#c060a0", "tier": 3, "aggro": true,
		"parts": [["spike", 0, 1], ["poison", 90, 1], ["poison", -90, 1], ["flagellum", 180, 1]], "levels": [4, 10], "weight": 1.6,
		"drops": [["poison", 0.2], ["spike", 0.2]], "hint": "Жалит с разгона и травит"},
	# Паразит: цепляется и тянет здоровье, пока не стряхнёшь рывком.
	"piyavka": {"name": "Пиявка", "behavior": "parasite", "radius": 6.0, "color": "#8a5a6a", "shape": "oval", "tier": 1,
		"parts": [["sucker", 0, 1], ["cilia", 180, 1]], "levels": [2, 10], "weight": 1.8,
		"drops": [["sucker", 0.2]], "hint": "Цепляется и пьёт здоровье. Стряхни рывком"},
	# Невидимка: без глаз его почти не видно.
	"prizrak": {"name": "Призрак", "behavior": "hunter", "radius": 20.0, "color": "#b0c8e0", "shape": "drop", "tier": 4, "invisible": true, "aggro": true,
		"parts": [["fangs", 0, 1], ["camo", 180, 1], ["cilia", 150, 1], ["cilia", -150, 1]], "levels": [3, 10], "weight": 1.6,
		"drops": [["fangs", 0.2], ["cilia", 0.15]], "hint": "Прозрачный хищник глубин. Без глаз его почти не видно"},
	"chernilnik": {"name": "Чернильник", "behavior": "skittish", "radius": 16.0, "color": "#5a4a7a", "shape": "bean", "tier": 2,
		"parts": [["ink", 90, 1], ["filter", 0, 1], ["flagellum", 180, 1], ["eye", -30, 1]], "levels": [3, 10], "weight": 1.5,
		"drops": [["ink", 0.3], ["eye", 0.2], ["flagellum", 0.1]], "hint": "Удирая, пускает чернила"},
	"udilshik": {"name": "Удильщик", "behavior": "hunter", "radius": 24.0, "color": "#3a4a70", "shape": "wide", "tier": 4,
		"parts": [["fangs", 0, 1], ["lantern", -30, 1], ["cilia", 150, 1], ["cilia", -150, 1], ["eye", 30, 1], ["firefly", 60, 1]], "levels": [4, 10], "weight": 1.2,
		"drops": [["fangs", 0.2], ["eye", 0.25], ["firefly", 0.2]], "hint": "Светится огоньком во тьме. Огонёк не выбить"},
	# Горячие источники.
	"puzyrnik": {"name": "Пузырник", "behavior": "grazer", "radius": 14.0, "color": "#e8a060", "tier": 1,
		"parts": [["filter", 0, 1], ["thermo", 180, 1], ["cilia", 90, 1]], "levels": [1, 8], "weight": 3.0,
		"drops": [["filter", 0.2], ["cilia", 0.2]], "hint": "Мирная, в плотной термооболочке"},
	"ognevik": {"name": "Огневик", "behavior": "hunter", "radius": 19.0, "color": "#e06a3a", "shape": "star", "tier": 3, "aggro": true,
		"parts": [["jaws", 0, 1], ["thermo", 180, 1], ["cilia", 120, 1], ["cilia", -120, 1]], "levels": [2, 10], "weight": 2.0,
		"drops": [["jaws", 0.25], ["cilia", 0.15]], "hint": "Злой огненный хищник"},
	# Холодные течения.
	"ledyanka": {"name": "Ледянка", "behavior": "grazer", "radius": 15.0, "color": "#a8d8f0", "shape": "oval", "tier": 1,
		"parts": [["filter", 0, 1], ["fat", 180, 1], ["cilia", 180, 1]], "levels": [1, 9], "weight": 3.0,
		"drops": [["filter", 0.2], ["cilia", 0.2]], "hint": "Мирная и пухлая, с жировой каплей"},
	"moroznik": {"name": "Морозник", "behavior": "hunter", "radius": 22.0, "color": "#7aa8d8", "shape": "star", "tier": 4, "aggro": true,
		"parts": [["fangs", 0, 1], ["fat", 180, 1], ["spike", 120, 1], ["spike", -120, 1], ["cilia", 180, 1]], "levels": [3, 10], "weight": 1.6,
		"drops": [["spike", 0.25], ["fangs", 0.1]], "hint": "Хищник с ледяными шипами"},
	# Стрелки: держатся поодаль и бьют издалека.
	"plevun": {"name": "Плевун", "behavior": "shooter", "radius": 15.0, "color": "#9ac060", "shape": "bean", "tier": 3, "hunts": true,
		"parts": [["spit", 0, 1], ["cilia", 150, 1], ["cilia", -150, 1], ["membrane", 180, 1]], "levels": [3, 10], "weight": 1.4,
		"drops": [["spit", 0.25], ["cilia", 0.15]], "hint": "Держится поодаль и плюётся ядом. Подплыви вплотную — он удирает"},
	"iglostrel": {"name": "Иглострел", "behavior": "shooter", "radius": 18.0, "color": "#c0a060", "shape": "star", "tier": 4, "hunts": true,
		"parts": [["needle", 0, 1], ["flagellum", 180, 1], ["shell", 120, 1], ["shell", -120, 1]], "levels": [5, 10], "weight": 1.2,
		"drops": [["needle", 0.25], ["shell", 0.15]], "hint": "Стреляет иглами издалека. Прячься за кругами и камнями"},
	# Делитель: ранишь — распадается на двоих поменьше.
	"delitel": {"name": "Делитель", "behavior": "hunter", "radius": 16.0, "color": "#d09ad0", "shape": "blob", "tier": 3, "splits": true,
		"parts": [["jaws", 0, 1], ["membrane", 120, 1], ["membrane", -120, 1], ["cilia", 180, 1]], "levels": [2, 10], "weight": 1.3,
		"drops": [["membrane", 0.2], ["jaws", 0.15]], "hint": "Ранишь — распадается на двоих. Добивай по одному"},
	# Обманка: притворяется водорослью, пока не подплывёшь.
	"obmanka": {"name": "Обманка", "behavior": "ambush", "radius": 13.0, "color": "#7ccf6a", "tier": 3, "hunts": true,
		"parts": [["fangs", 0, 1], ["cilia", 180, 1]], "levels": [2, 10], "weight": 1.2,
		"drops": [["fangs", 0.2], ["cilia", 0.15]], "hint": "Выглядит как водоросль и кусает, если подплыть. С двумя глазами её видно"},
	"kleshnets": {"name": "Клешнец", "behavior": "hunter", "radius": 20.0, "color": "#d07a50", "shape": "wide", "tier": 4,
		"parts": [["claw", 50, 1], ["claw", -50, 1], ["shell", 180, 1], ["cilia", 130, 1], ["cilia", -130, 1]], "levels": [4, 10], "weight": 1.3,
		"drops": [["claw", 0.3], ["shell", 0.1]], "hint": "Хватает клешнями и держит"},
	"prilipalo": {"name": "Прилипало", "behavior": "grazer", "radius": 10.0, "color": "#a0b0c0", "shape": "oval", "tier": 1,
		"parts": [["filter", 0, 1], ["remora", 180, 1], ["cilia", 120, 1]], "levels": [3, 10], "weight": 1.5,
		"drops": [["remora", 0.3], ["cilia", 0.1]], "hint": "Ездит на крупных и ест с них крохи"},
	# Бродячие гиганты: плывут через весь океан, а не сидят в логове. Награда — особая часть.
	"kit": {"name": "Старый кит", "behavior": "roamer", "radius": 16.0, "scale": 3.4, "color": "#6a90b0", "shape": "oval", "tier": 8,
		"parts": [["baleen", 0, 2], ["membrane", 90, 3], ["membrane", -90, 3], ["flagellum2", 180, 2]], "levels": [5, 10], "weight": 0.0,
		"drops": [["baleen", 1.0], ["membrane", 0.5]], "hint": "Мирный бродячий гигант. Разозлишь — отобьётся. Награда — китовый ус"},
	"zmei": {"name": "Морской змей", "behavior": "roamer", "radius": 16.0, "scale": 2.4, "color": "#3a8a7a", "shape": "oval", "tier": 8, "hunts": true,
		"parts": [["fangs", 0, 2], ["serpent", 180, 1], ["spike2", 120, 1], ["spike2", -120, 1], ["membrane", 90, 1], ["membrane", -90, 1]], "levels": [6, 10], "weight": 0.0,
		"drops": [["serpent", 1.0], ["spike2", 0.4]], "hint": "Злой бродячий гигант: охотится на всех. Награда — змеиный хвост"},
	# Бывшие хозяева логов — теперь тоже бродячие гиганты. Награда — особая часть.
	"koroleva": {"name": "Королева глубин", "behavior": "roamer", "radius": 16.0, "scale": 2.3, "color": "#6a4a9a", "shape": "blob", "tier": 9, "hunts": true,
		"parts": [["fangs", 0, 1], ["life_core", 180, 1], ["tentacle", 60, 1], ["tentacle", -60, 1], ["membrane", 150, 2], ["membrane", -150, 2], ["eye", 30, 1], ["eye", -30, 1]],
		"levels": [4, 10], "weight": 0.0, "drops": [["life_core", 1.0], ["fangs", 0.4]],
		"hint": "Бродячая хищница с щупальцами. Награда — ядро жизни"},
	"strazh": {"name": "Колючий страж", "behavior": "roamer", "radius": 16.0, "scale": 2.3, "color": "#b0603a", "shape": "star", "tier": 9, "hunts": true,
		"parts": [["horn", 0, 1], ["thorn_armor", 90, 1], ["thorn_armor", -90, 1], ["spike2", 150, 1], ["spike2", -150, 1], ["thermo", 180, 1]],
		"levels": [5, 10], "weight": 0.0, "drops": [["thorn_armor", 1.0], ["spike2", 0.4]],
		"hint": "Бродячий гигант в шипастой броне: кто его бьёт, сам ранится. Награда — шипастая броня"},
	"vikhr": {"name": "Ледяной вихрь", "behavior": "roamer", "radius": 16.0, "scale": 2.2, "color": "#9ad0f0", "shape": "drop", "tier": 9, "hunts": true,
		"parts": [["jaws", 0, 2], ["jet", 180, 1], ["flagellum2", 150, 1], ["flagellum2", -150, 1], ["fat", 0, 1], ["membrane", 90, 2], ["membrane", -90, 2]],
		"levels": [6, 10], "weight": 0.0, "drops": [["jet", 1.0], ["flagellum2", 0.3]],
		"hint": "Очень быстрый бродячий хищник. Награда — реактивный мешок"},
	# Новые гиганты — чтобы на каждом размере появлялся свой.
	"meduza": {"name": "Великанская медуза", "behavior": "roamer", "radius": 16.0, "scale": 3.0, "color": "#c090e0", "tier": 5,
		"parts": [["poison", 150, 1], ["poison", -150, 1], ["poison", 180, 1], ["tentacle", 120, 1], ["tentacle", -120, 1], ["membrane", 0, 1]], "levels": [2, 10], "weight": 0.0,
		"drops": [["poison", 0.6], ["membrane", 0.4]], "hint": "Мирная, но жжётся ядом, если коснуться сзади"},
	"titan": {"name": "Панцирный титан", "behavior": "roamer", "radius": 16.0, "scale": 3.2, "color": "#8a8a70", "shape": "wide", "tier": 8,
		"parts": [["jaws", 0, 2], ["plates", 90, 1], ["plates", -90, 1], ["plates", 180, 1], ["shell", 45, 2], ["shell", -45, 2], ["cilia", 150, 1], ["cilia", -150, 1]], "levels": [7, 10], "weight": 0.0,
		"drops": [["shell", 0.7], ["jaws", 0.5]], "hint": "Медленный, в броне со всех сторон. Сам не нападает, но отбивается"},
	"kalmar": {"name": "Глубинный кальмар", "behavior": "roamer", "radius": 16.0, "scale": 3.0, "color": "#8a4a6a", "shape": "drop", "tier": 9, "hunts": true,
		"parts": [["fangs", 0, 2], ["tentacle", 40, 1], ["tentacle", -40, 1], ["tentacle", 80, 1], ["tentacle", -80, 1], ["ink", 180, 1], ["eye", 25, 1], ["eye", -25, 1]], "levels": [9, 10], "weight": 0.0,
		"drops": [["ink", 0.7], ["fangs", 0.5], ["eye", 0.5]], "hint": "Хватает щупальцами и прячется в чернилах"},
	"drevniy": {"name": "Древний", "behavior": "roamer", "radius": 16.0, "scale": 4.2, "color": "#5a7a6a", "shape": "blob", "tier": 10,
		"parts": [["baleen", 0, 3], ["spike2", 60, 2], ["spike2", -60, 2], ["spike2", 120, 2], ["spike2", -120, 2], ["membrane", 90, 3], ["membrane", -90, 3], ["life_core", 180, 1]], "levels": [10, 10], "weight": 0.0,
		"drops": [["life_core", 1.0], ["baleen", 0.5], ["spike2", 0.5]], "hint": "Самый большой в океане. Мирный, пока его не тронешь"},
	# Ещё гиганты — чтобы на каждом размере их было несколько разных.
	"tolstun": {"name": "Толстун", "behavior": "roamer", "radius": 16.0, "scale": 3.6, "color": "#b0a070", "shape": "bean", "tier": 5,
		"parts": [["filter", 0, 1], ["membrane", 90, 3], ["membrane", -90, 3], ["cilia", 180, 2], ["cilia", 150, 2], ["cilia", -150, 2]], "levels": [1, 10], "weight": 0.0,
		"drops": [["membrane", 1.0], ["cilia", 0.5]], "hint": "Мирный толстяк: медленный, мягкий, дерётся только с другими гигантами"},
	"rogach": {"name": "Рогач", "behavior": "roamer", "radius": 16.0, "scale": 3.0, "color": "#a06a4a", "shape": "drop", "tier": 6, "hunts": true,
		"parts": [["horn", 0, 2], ["shell", 60, 2], ["shell", -60, 2], ["flagellum2", 180, 2], ["eye", 30, 1]], "levels": [2, 10], "weight": 0.0,
		"drops": [["shell", 1.0], ["flagellum2", 0.4]], "hint": "Бодается рогом с разгона. Панцирь спереди — бей сзади"},
	"iglobryukh": {"name": "Иглобрюх", "behavior": "roamer", "radius": 16.0, "scale": 3.2, "color": "#c8b060", "shape": "round", "tier": 6,
		"parts": [["thorn_armor", 0, 2], ["spike", 45, 3], ["spike", -45, 3], ["spike", 135, 3], ["spike", -135, 3], ["spike", 90, 3], ["spike", -90, 3], ["cilia", 180, 2]], "levels": [3, 10], "weight": 0.0,
		"drops": [["thorn_armor", 1.0], ["spike", 0.6]], "hint": "Весь в колючках: сам не нападает, но трогать больно"},
	"svetoch": {"name": "Светоч глубин", "behavior": "roamer", "radius": 16.0, "scale": 2.8, "color": "#3a4a6a", "shape": "wide", "tier": 7, "hunts": true,
		"parts": [["fangs", 0, 3], ["lantern", 0, 2], ["firefly", 90, 2], ["firefly", -90, 2], ["flagellum", 180, 3]], "levels": [4, 10], "weight": 0.0,
		"drops": [["firefly", 1.0], ["fangs", 0.4]], "hint": "Приманивает огоньком и хватает клыками. В темноте светится"},
	"tokoskat": {"name": "Токоскат", "behavior": "roamer", "radius": 16.0, "scale": 3.0, "color": "#5a7ab0", "shape": "wide", "tier": 7, "hunts": true,
		"parts": [["jaws", 0, 2], ["electro", 45, 2], ["electro", -45, 2], ["membrane", 90, 2], ["membrane", -90, 2], ["serpent", 180, 2]], "levels": [5, 10], "weight": 0.0,
		"drops": [["electro", 1.0], ["serpent", 0.4]], "hint": "Бьёт током всех вокруг — держись подальше, пока он не выдохнется"},
	"kleshnerug": {"name": "Клешнерук", "behavior": "roamer", "radius": 16.0, "scale": 2.9, "color": "#c05a4a", "shape": "wide", "tier": 8, "hunts": true,
		"parts": [["jaws", 0, 3], ["claw", 35, 3], ["claw", -35, 3], ["shell", 120, 3], ["shell", -120, 3], ["flagellum2", 180, 2]], "levels": [7, 10], "weight": 0.0,
		"drops": [["claw", 1.0], ["shell", 0.5]], "hint": "Хватает клешнями и не отпускает. Сзади — мягкий"},
	"sprut": {"name": "Спрут", "behavior": "roamer", "radius": 16.0, "scale": 3.1, "color": "#8a4a7a", "shape": "drop", "tier": 8, "hunts": true,
		"parts": [["proboscis", 0, 3], ["tentacle", 150, 3], ["tentacle", -150, 3], ["tentacle", 120, 3], ["tentacle", -120, 3], ["ink", 0, 2], ["eye", 40, 2], ["eye", -40, 2]], "levels": [8, 10], "weight": 0.0,
		"drops": [["ink", 1.0], ["eye", 0.5]], "hint": "Щупальцами держит, чернилами прячется. Сам ищет драки"},
	"yadozub": {"name": "Ядозуб", "behavior": "roamer", "radius": 16.0, "scale": 2.8, "color": "#5a8a3a", "shape": "oval", "tier": 9, "hunts": true,
		"parts": [["fangs", 0, 4], ["poison", 30, 3], ["poison", -30, 3], ["spit", 60, 3], ["spit", -60, 3], ["flagellum2", 180, 3]], "levels": [9, 10], "weight": 0.0,
		"drops": [["poison", 1.0], ["spit", 0.6]], "hint": "Плюётся ядом издалека и травит укусом"},
	"past": {"name": "Пасть бездны", "behavior": "roamer", "radius": 16.0, "scale": 3.8, "color": "#2a2a3a", "shape": "round", "tier": 10, "hunts": true,
		"parts": [["jaws", 0, 5], ["spike2", 60, 4], ["spike2", -60, 4], ["plates", 120, 4], ["plates", -120, 4], ["jet", 180, 3]], "levels": [10, 10], "weight": 0.0,
		"drops": [["jet", 1.0], ["spike2", 0.6], ["jaws", 0.5]], "hint": "Одна огромная пасть. Глотает всех, кто зазевался"},
	# Колоссы: огромные, их не ранить. Проплывают мимо — посмотреть и удивиться. Размер
	# свой, не от тебя: растёшь — они для тебя «уменьшаются».
	"bezdonny_kit": {"name": "Бездонный кит", "behavior": "colossus", "radius": 16.0, "size": 300.0, "color": "#4f6f92", "shape": "oval", "tier": 0,
		"parts": [["eye", 35, 3], ["eye", -35, 3], ["membrane", 90, 5], ["membrane", -90, 5], ["flagellum2", 180, 5], ["firefly", 140, 3], ["firefly", -140, 3]],
		"levels": [1, 10], "weight": 0.0, "drops": [], "hint": "Колосс. Проплывает раз в несколько минут — его не ранить и не догнать. Можно прилипнуть и прокатиться"},
	"pramatka": {"name": "Праматерь медуз", "behavior": "colossus", "radius": 16.0, "size": 250.0, "color": "#9a70cc", "shape": "round", "tier": 0,
		"parts": [["eye", 0, 3], ["cilia", 150, 5], ["cilia", -150, 5], ["cilia", 120, 5], ["cilia", -120, 5], ["firefly", 60, 3], ["firefly", -60, 3], ["firefly", 180, 3]],
		"levels": [1, 10], "weight": 0.0, "drops": [], "hint": "Колосс. Светится в темноте, плывёт медленно и никого не трогает"},
	"spyashchiy_ostrov": {"name": "Спящий остров", "behavior": "colossus", "radius": 16.0, "size": 380.0, "color": "#5f7f62", "shape": "blob", "tier": 0,
		"parts": [["membrane", 45, 5], ["membrane", -45, 5], ["membrane", 135, 5], ["membrane", -135, 5], ["cilia", 180, 5], ["eye", 0, 2]],
		"levels": [1, 10], "weight": 0.0, "drops": [], "hint": "Колосс. Такой большой, что кажется островом. Спит на ходу"},
}

## Узоры тела — поверх основного цвета вторым цветом.
const PATTERNS := [["none", "Без узора"], ["stripes", "Полоски"], ["spots", "Пятна"], ["rings", "Кольца"], ["gradient", "Переход"]]

## Достижения: что считается и сколько нужно.
const ACHIEVEMENTS := [
	{"id": "first_kill", "title": "Первая победа", "stat": "kills", "need": 1, "hint": "Победи любое существо"},
	{"id": "kills100", "title": "Гроза океана", "stat": "kills", "need": 100, "hint": "Сто побед"},
	{"id": "plants1000", "title": "Травоед", "stat": "plants", "need": 1000, "hint": "Съешь тысячу водорослей"},
	{"id": "meat300", "title": "Мясоед", "stat": "meat", "need": 300, "hint": "Съешь триста кусочков мяса"},
	{"id": "rocks10", "title": "Камнедробилка", "stat": "rocks", "need": 10, "hint": "Разбей десять камней"},
	{"id": "golden5", "title": "Золотоискатель", "stat": "golden", "need": 5, "hint": "Победи пять сияющих"},
	{"id": "parasites20", "title": "Чистюля", "stat": "shaken", "need": 20, "hint": "Стряхни рывком двадцать паразитов"},
	{"id": "parts10", "title": "Коллекционер", "stat": "@parts", "need": 10, "hint": "Найди десять разных частей"},
	{"id": "parts_all", "title": "Полная коллекция", "stat": "@parts", "need": -1, "hint": "Найди все части, какие можно выбить"},
	{"id": "maxed", "title": "Мастер части", "stat": "@maxed", "need": 1, "hint": "Прокачай любую часть до пятого уровня"},
	{"id": "lairs", "title": "Покоритель гигантов", "stat": "@lairs", "need": 3, "hint": "Победи трёх разных бродячих гигантов"},
	{"id": "gen10", "title": "Десять поколений", "stat": "@generation", "need": 10, "hint": "Проживи десять поколений"},
	{"id": "brood3", "title": "Большая семья", "stat": "@brood", "need": 3, "hint": "Собери свиту из трёх потомков"},
	{"id": "size10", "title": "Многоклеточный", "stat": "@level", "need": 10, "hint": "Дорасти до последнего размера"},
	{"id": "dash500", "title": "Рывок за рывком", "stat": "dashes", "need": 500, "hint": "Сделай пятьсот рывков"},
	{"id": "arena10", "title": "Гладиатор", "stat": "@arena", "need": 10, "hint": "Продержись на арене десять волн"},
	{"id": "abilities", "title": "Умелец", "stat": "abilities", "need": 50, "hint": "Используй умение пятьдесят раз"},
]

## Цвета тела на выбор в редакторе.
## Новые цвета — только в конец: в сохранениях цвет хранится номером.
const COLORS := ["#8fd07a", "#6fc0e0", "#e0b060", "#e07a6a", "#b08ae0", "#e890b8", "#7ad0b0", "#d8d8c8",
	"#5a8ee0", "#f0dc6a", "#c8683e", "#7a62c8", "#b4e05a", "#f4b0a0", "#3e9a96", "#9a8878"]

## Задачи — тропинка для начала, а не обязанность.
const GOALS := [
	{"id": "eat", "title": "Съешь 10 водорослей", "hint": "Плыви к зелёным крупинкам — это еда"},
	{"id": "grow", "title": "Подрасти", "hint": "Еда даёт ДНК. Наберёшь 40 — клетка вырастет"},
	{"id": "edit", "title": "Поставь толчковый пузырь", "hint": "Нажми ♥ — стрелка покажет пару. Доплыви до неё и поставь пузырь: он даёт рывок"},
	{"id": "kill", "title": "Одолей другую клетку", "hint": "«Рывок» — удар с разгона. Им можно сбить мелкую клетку"},
	{"id": "part", "title": "Добудь новую часть", "hint": "Части выпадают из тех, у кого они есть. Не всегда!"},
	{"id": "diet", "title": "Выбери, кем быть", "hint": "Челюсти — хищник, фильтр — травоядный, хоботок — всеядный"},
	{"id": "upgrade", "title": "Улучши часть", "hint": "Та же часть ещё раз — и она становится сильнее"},
	{"id": "size5", "title": "Вырасти до 5-го размера", "hint": "Чем больше, тем крупнее соседи"},
	{"id": "parts8", "title": "Собери 8 разных частей", "hint": "Загляни в «Атлас»: кто что роняет"},
	{"id": "boss", "title": "Одолей великана", "hint": "Шипастый великан, Левиафан или Панцирный титан"},
	{"id": "lair", "title": "Победи бродячего гиганта", "hint": "Гиганты плавают поодиночке, на каждом размере — новый. Их тени видны в глубине"},
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
	return 3 + level

## Что даёт форма тела: площадь (1 — круг), обвод (1 — круг) и вытянутость вперёд.
## Больше тело — больше места под части и здоровья, но тяжелее; вытянутое — быстрее.
static func shape_stats(shape: Array) -> Dictionary:
	if shape.is_empty():
		return {"area": 1.0, "perim": 1.0, "elong": 1.0, "slots": 0, "hp": 1.0, "speed": 1.0}
	var area := 0.0
	var perim := 0.0
	var n := shape.size()
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		area += float(shape[i]) * float(shape[i])
		perim += (Vector2.from_angle(a0) * float(shape[i])).distance_to(Vector2.from_angle(a1) * float(shape[(i + 1) % n]))
	area /= n
	perim /= 2.0 * n * sin(PI / n)
	var along := shape_at(shape, 0.0) + shape_at(shape, PI)
	var across := shape_at(shape, PI / 2.0) + shape_at(shape, -PI / 2.0)
	var elong := along / maxf(across, 0.1)
	return {"area": area, "perim": perim, "elong": elong,
		"slots": clampi(int(floor((perim - 1.0) / 0.1)), 0, 4),
		"hp": clampf(sqrt(area), 0.75, 1.4),
		"speed": clampf((1.0 + 0.18 * clampf(elong - 1.0, -0.6, 1.2)) / pow(area, 0.12), 0.8, 1.25)}

## Магазин: улучшения на весь вид, не части тела. Цена — за каждый следующий уровень.
const UPGRADES := {
	"room": {"name": "Лишнее место", "icon": "plus", "costs": [50, 120, 240], "hint": "+1 место под часть тела"},
	"hp": {"name": "Крепкая оболочка", "icon": "heart", "costs": [30, 70, 140], "hint": "+15% здоровья"},
	"regen": {"name": "Заживление", "icon": "leaf", "costs": [30, 70, 140], "hint": "Раны затягиваются быстрее"},
	"stomach": {"name": "Большой желудок", "icon": "dna", "costs": [40, 100, 200], "hint": "+10% ДНК с любой еды"},
	"camo": {"name": "Маскировка", "icon": "eye_off", "costs": [40, 90, 160], "hint": "Хищники замечают тебя позже"},
	"dash": {"name": "Сильный рывок", "icon": "dash", "costs": [30, 70, 140], "hint": "Рывок перезаряжается быстрее (нужен толчковый пузырь)"},
}

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

