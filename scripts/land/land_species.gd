## Кто живёт на острове. Три размера — и у каждого свои виды:
## - стаи — твоего размера и всегда вместе, у своего гнезда. Травоядные ходят за плодами и
##   носят их в гнездо, хищные охотятся на чужих сборщиков и носят домой мясо;
## - отшельники — одиночки вдвое крупнее тебя, сильные;
## - гиганты — огромные и очень сильные, каждый стережёт свои места.
##
## Тело каждого вида собрано из тех же частей, что и твоё (LandParts), — поэтому все
## выглядят по-разному: кто с клювом и на двух ногах, кто в панцире, кто с парусом.
class_name LandSpecies
extends RefCounted

## tier — pack / hermit / giant. diet — plant (носят плоды) или meat (охотятся).
## size — [от, до] (ты — 1). hp, bite, speed — множители к обычным для этого размера.
## night — ходят ночью, днём спят в гнезде. skittish — пугливые: удирают, а не
## нападают (кроме защиты гнезда). tree — достают плоды прямо с деревьев. poison — яд
## в укусе (в секунду, 4 с). parts, shape, pattern — как выглядят. colors — пары цветов.
const SPECIES := {
	# --- стаи: твоего размера -------------------------------------------------------------
	"grazer": {"name": "Пасуны", "tier": "pack", "diet": "plant", "size": [0.9, 1.05], "hp": 1.0, "bite": 1.0, "speed": 0.8,
		"parts": {"torso": "torso", "legs": "legs4", "mouth": "beak", "eyes": "eyes", "tail": "tail_long", "skin": "fur"},
		"shape": {"len": 1.1, "girth": [0.85, 1.05, 1.15, 1.05, 0.85], "tail_len": 0.6},
		"pattern": "spots", "colors": [["#c8a070", "#8a6a44"], ["#e0b060", "#a07030"]]},
	"longneck": {"name": "Длинношеи", "tier": "pack", "diet": "plant", "size": [0.95, 1.1], "hp": 1.1, "bite": 0.8, "speed": 0.75, "tree": true,
		"parts": {"torso": "torso", "legs": "legs4", "mouth": "snout", "eyes": "eyes", "tail": "tail_long"},
		"shape": {"neck_y": 1.1, "neck_z": 0.5, "head": 0.8, "leg_len": 1.45, "leg_len_f": 1.6, "girth": [0.8, 1.0, 1.05, 1.0, 0.8]},
		"pattern": "leopard", "colors": [["#e8c070", "#8a5a3a"], ["#d8b080", "#6e5236"]]},
	"hopper": {"name": "Прыгуны", "tier": "pack", "diet": "plant", "size": [0.85, 1.0], "hp": 0.8, "bite": 0.8, "speed": 1.0, "skittish": true,
		"parts": {"torso": "torso", "legs": "legs2", "mouth": "beak", "eyes": "eyes_big", "tail": "tail_long", "feet": "paws"},
		"shape": {"torso_pitch": 0.55, "len": 0.8, "tail_len": 1.7, "tail_pitch": 0.1, "leg_len": 1.3, "head": 1.15},
		"pattern": "belly", "colors": [["#b8d88a", "#f2ead8"], ["#9ac8e0", "#f2ead8"]]},
	"shellback": {"name": "Панцирники", "tier": "pack", "diet": "plant", "size": [0.95, 1.1], "hp": 1.7, "bite": 1.0, "speed": 0.6,
		"parts": {"torso": "torso", "legs": "legs6", "mouth": "jaws", "eyes": "eyes", "back": "plates", "tail": "tail_club"},
		"shape": {"width": 1.35, "height": 0.8, "len": 1.2, "leg_len": 0.6, "leg_len_f": 0.6, "tail_len": 0.5},
		"pattern": "rings", "colors": [["#7a8a5a", "#4a5a3a"], ["#8a7a6a", "#5e4a3a"]]},
	"fangpack": {"name": "Клыкачи", "tier": "pack", "diet": "meat", "size": [0.9, 1.05], "hp": 1.0, "bite": 1.3, "speed": 0.95,
		"parts": {"torso": "torso", "legs": "legs4", "mouth": "fangs", "eyes": "eyes", "claws": "claws", "tail": "tail_long"},
		"shape": {"len": 1.3, "girth": [0.75, 0.95, 1.0, 0.9, 0.8], "leg_len": 1.15, "leg_len_f": 1.15, "tail_len": 1.2},
		"pattern": "tiger", "colors": [["#c8683e", "#3a3a44"], ["#b04a2a", "#2e2a2a"]]},
	"nightstalker": {"name": "Ночники", "tier": "pack", "diet": "meat", "size": [0.9, 1.05], "hp": 0.9, "bite": 1.2, "speed": 1.0, "night": true,
		"parts": {"torso": "torso", "legs": "legs6", "mouth": "jaws", "eyes": "eyes_big", "claws": "claws", "skin": "scales"},
		"shape": {"eye_n": 4.0, "height": 0.85, "len": 1.1},
		"pattern": "dots", "colors": [["#3a3a54", "#5ac8e8"], ["#2e3a4a", "#b08ae0"]]},
	# --- отшельники: вдвое крупнее ------------------------------------------------------
	"hornback": {"name": "Рогач", "tier": "hermit", "diet": "meat", "size": [1.9, 2.3], "hp": 1.0, "bite": 1.0, "speed": 0.8,
		"parts": {"torso": "torso", "legs": "legs4", "mouth": "jaws", "eyes": "eyes", "head": "horns", "back": "back_spikes", "skin": "fur"},
		"shape": {"girth": [0.9, 1.1, 1.3, 1.2, 1.0]},
		"pattern": "back", "colors": [["#5a4a6a", "#2e2a2a"], ["#6a3a3a", "#2e2a2a"]]},
	"clubtail": {"name": "Булавохвост", "tier": "hermit", "diet": "plant", "size": [2.0, 2.4], "hp": 1.3, "bite": 0.9, "speed": 0.65,
		"parts": {"torso": "torso", "legs": "legs4", "mouth": "beak", "eyes": "eyes", "tail": "tail_club", "back": "plates"},
		"shape": {"width": 1.2, "height": 0.9, "tail_len": 1.4, "leg_len": 0.8, "leg_len_f": 0.8},
		"pattern": "stripes", "colors": [["#6a7a4a", "#3a4a2a"], ["#8a6a4a", "#4a3a2a"]]},
	"venomer": {"name": "Ядозуб", "tier": "hermit", "diet": "meat", "size": [1.8, 2.1], "hp": 0.9, "bite": 0.8, "speed": 0.9, "poison": 3.0,
		"parts": {"torso": "torso", "legs": "legs6", "mouth": "fangs", "eyes": "eyes_stalk", "skin": "poison_skin", "tail": "tail_long"},
		"shape": {"len": 1.4, "height": 0.8, "leg_len": 0.7, "leg_len_f": 0.7},
		"pattern": "spots", "colors": [["#4a6a3a", "#c8f040"], ["#3a5a4a", "#e8742a"]]},
	"clawer": {"name": "Клешнерук", "tier": "hermit", "diet": "meat", "size": [1.9, 2.2], "hp": 1.1, "bite": 1.1, "speed": 0.75,
		"parts": {"torso": "torso", "legs": "legs2", "mouth": "jaws", "eyes": "eyes", "arms": "arms_claw", "skin": "scales"},
		"shape": {"torso_pitch": 0.9, "arm_pairs": 2.0, "arm_len": 1.3, "arm_thick": 1.5, "tail_len": 0.6},
		"pattern": "gradient", "colors": [["#a8323a", "#e8742a"], ["#6a3a5a", "#c8683e"]]},
	# --- гиганты: огромные ---------------------------------------------------------------
	"titan": {"name": "Рогатый великан", "tier": "giant", "diet": "meat", "size": [3.9, 4.4], "hp": 1.0, "bite": 1.0, "speed": 0.75,
		"parts": {"torso": "torso", "legs": "legs4", "mouth": "fangs", "eyes": "eyes", "head": "horns", "back": "plates", "claws": "claws_big", "tail": "tail_club"},
		"shape": {"girth": [0.9, 1.1, 1.25, 1.15, 1.0]},
		"pattern": "back", "colors": [["#6a5a7a", "#2e2a3a"]]},
	"sailback": {"name": "Парусный великан", "tier": "giant", "diet": "plant", "size": [4.1, 4.6], "hp": 1.1, "bite": 0.85, "speed": 0.7,
		"parts": {"torso": "torso", "legs": "legs4", "mouth": "snout", "eyes": "eyes", "back": "sail", "tail": "tail_long", "claws": "claws_big"},
		"shape": {"len": 1.4, "tail_len": 1.6, "leg_len": 0.9, "leg_len_f": 0.9},
		"pattern": "stripes", "colors": [["#4a6a6a", "#e8742a"]]},
	"strider": {"name": "Долгоног", "tier": "giant", "diet": "meat", "size": [3.6, 4.0], "hp": 0.9, "bite": 1.1, "speed": 0.9,
		"parts": {"torso": "torso", "legs": "legs_long", "mouth": "fangs", "eyes": "eyes_stalk", "claws": "claws_big", "tail": "tail_long"},
		"shape": {"leg_len": 1.9, "leg_len_f": 1.9, "len": 0.9, "girth": [0.8, 1.0, 1.1, 1.0, 0.8]},
		"pattern": "leopard", "colors": [["#7a5a3a", "#2e2a2a"]]},
}

## Виды одного размера (pack / hermit / giant), по порядку.
static func of_tier(tier: String) -> Array:
	return SPECIES.keys().filter(func(k): return SPECIES[k].tier == tier)

## Как выглядит существо этого вида: {parts, shape, pattern}. Вожак — с гребнем и когтями.
static func look(id: String, leader := false) -> Dictionary:
	var sp: Dictionary = SPECIES[id]
	var parts: Dictionary = sp.parts.duplicate()
	if leader:
		parts.head = "crest"
		if not parts.has("claws"):
			parts.claws = "claws"
	var shape := LandParts.default_shape()
	for k in sp.shape:
		shape[k] = sp.shape[k]
	return {"parts": parts, "shape": LandParts.fix_shape(shape), "pattern": sp.pattern}
