## Всё, из чего состоит мир «Опушки»: вещи, то, что растёт и лежит, постройки, рецепты,
## задачи.
##
## Здесь только справочники, без логики. Так игра и растёт: новая вещь, куст или постройка —
## новая строка здесь, а правила в village.gd про них ничего особого знать не должны.
##
## Ключи попадают в сохранение. Подпись менять можно, ключ — нет: иначе вещи в старых
## сохранениях станут ничьими.
class_name Content
extends RefCounted

const DAY := 1440

const ITEMS := {
	"stick": {"name": "Ветка", "forms": ["ветка", "ветки", "веток"], "hint": "Для инструментов и костра"},
	"stone": {"name": "Камень", "forms": ["камень", "камня", "камней"], "hint": "Для инструментов и домика"},
	"log": {"name": "Бревно", "forms": ["бревно", "бревна", "брёвен"], "hint": "Главный строительный материал"},
	"berries": {"name": "Ягоды", "forms": ["ягода", "ягоды", "ягод"], "food": 12, "hint": "Съесть — сытость +12"},
	"axe": {"name": "Топор", "tool": true, "hint": "Рубит деревья. Не тратится"},
	"pickaxe": {"name": "Кирка", "tool": true, "hint": "Разбивает валуны на камни. Не тратится"},
	"campfire": {"name": "Костёр", "places": "campfire", "hint": "Свет ночью, у него можно переночевать"},
	"workbench": {"name": "Верстак", "places": "workbench", "hint": "Рядом с ним делаются забор и домик"},
	"fence": {"name": "Забор", "places": "fence", "hint": "Огородить своё место"},
	"house": {"name": "Домик", "places": "house", "hint": "Свой дом. Ночлег лучше, чем у костра"},
}

## Что стоит на клетке само по себе. `leaves` — что остаётся, пока не отросло: пень и
## пустой куст мешают пройти, от веток не остаётся ничего.
const NATURE := {
	"tree": {"name": "Дерево", "verb": "Срубить", "needs": "axe", "gives": {"log": 2, "stick": 1}, "minutes": 40, "regrow": 3 * DAY, "leaves": "stump", "sound": "chop"},
	"bush": {"name": "Куст", "verb": "Собрать ягоды", "gives": {"berries": 3}, "minutes": 10, "regrow": DAY, "leaves": "bare", "sound": "berries"},
	"rock": {"name": "Валун", "verb": "Разбить", "needs": "pickaxe", "gives": {"stone": 4}, "minutes": 45, "regrow": 5 * DAY, "leaves": "nothing", "sound": "stone"},
	"pebble": {"name": "Камешки", "verb": "Подобрать", "gives": {"stone": 1}, "minutes": 5, "regrow": 2 * DAY, "leaves": "nothing", "sound": "pebble"},
	"branch": {"name": "Ветки", "verb": "Подобрать", "gives": {"stick": 2}, "minutes": 5, "regrow": DAY, "leaves": "nothing", "sound": "twig"},
}

## Лежит под ногами — подбирается на ходу и не мешает пройти.
const UNDERFOOT := ["branch", "pebble"]

const STRUCTURES := {
	"campfire": {"name": "Костёр", "near": "у костра", "sleep": "rough", "light": 3.2},
	"workbench": {"name": "Верстак", "near": "у верстака", "station": true},
	"fence": {"name": "Забор", "near": "у забора"},
	"house": {"name": "Домик", "near": "у домика", "sleep": "cozy", "light": 2.0},
}

const RECIPES := [
	{"id": "axe", "makes": "axe", "count": 1, "needs": {"stick": 3, "stone": 2}, "minutes": 20},
	{"id": "pickaxe", "makes": "pickaxe", "count": 1, "needs": {"stick": 3, "stone": 3}, "minutes": 25},
	{"id": "campfire", "makes": "campfire", "count": 1, "needs": {"stick": 5, "stone": 3}, "minutes": 20},
	{"id": "workbench", "makes": "workbench", "count": 1, "needs": {"log": 4}, "minutes": 30},
	{"id": "fence", "makes": "fence", "count": 2, "needs": {"stick": 3}, "at": "workbench", "minutes": 10},
	{"id": "house", "makes": "house", "count": 1, "needs": {"log": 12, "stone": 6}, "at": "workbench", "minutes": 120},
]

## Задачи — тропинка для начала, а не обязанность: мир открыт и без них.
const GOALS := [
	{"id": "sticks", "title": "Собери 5 веток", "hint": "Ветки лежат на земле — наступи на них"},
	{"id": "axe", "title": "Сделай топор", "hint": "3 ветки и 2 камня — открой «Сумку»"},
	{"id": "chop", "title": "Сруби дерево", "hint": "Подойди к дереву и нажми «Срубить»"},
	{"id": "campfire", "title": "Поставь костёр", "hint": "У костра можно переночевать"},
	{"id": "workbench", "title": "Поставь верстак", "hint": "4 бревна. У верстака делаются вещи посложнее"},
	{"id": "house", "title": "Построй домик", "hint": "12 брёвен и 6 камней, делается у верстака"},
]

static func item_for_structure(structure: String) -> String:
	for id in ITEMS:
		if ITEMS[id].get("places", "") == structure:
			return id
	return ""

static func recipe(id: String) -> Dictionary:
	for r in RECIPES:
		if r.id == id:
			return r
	return {}

## «1 ветка, 2 ветки, 5 веток».
static func plural(n: int, forms: Array) -> String:
	var m10 := n % 10
	var m100 := n % 100
	if m10 == 1 and m100 != 11:
		return forms[0]
	if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14):
		return forms[1]
	return forms[2]
