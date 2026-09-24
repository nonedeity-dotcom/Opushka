## Настройки этого телефона: управление, звук, экран. Хранятся в user://.
class_name Settings
extends RefCounted

const PATH := "user://settings.json"

## Джойстик или «плыть за пальцем»: держишь палец на экране — клетка плывёт к нему.
var control := "stick"
var pad_side := "left"
var buttons := "normal"
var sound := true
var volume := "normal"
var ambience := true
var vibration := true
var landscape := false
var show_goal := true
## Стрелки у края экрана: к выпавшим частям, а с глазками — и к хищникам.
var arrows := true

const BUTTON_SCALE := {"small": 0.85, "normal": 1.0, "large": 1.18}
## Громкость в децибелах: эффекты и фон. Фон заметно тише — он не должен спорить с делом.
const VOLUME := {"quiet": [-14.0, -24.0], "normal": [-6.0, -16.0], "loud": [0.0, -10.0]}

const CHOICES := {
	"control": ["stick", "follow"],
	"pad_side": ["left", "right"],
	"buttons": ["small", "normal", "large"],
	"volume": ["quiet", "normal", "loud"],
}
const FLAGS := ["sound", "ambience", "vibration", "landscape", "show_goal", "arrows"]

func to_dict() -> Dictionary:
	var d := {}
	for k in CHOICES:
		d[k] = get(k)
	for k in FLAGS:
		d[k] = get(k)
	return d

## Прочитать. Непонятное — по умолчанию.
static func from_dict(raw: Variant) -> Settings:
	var s := Settings.new()
	if not raw is Dictionary:
		return s
	for k in CHOICES:
		if raw.get(k) in CHOICES[k]:
			s.set(k, raw[k])
	for k in FLAGS:
		if raw.get(k) is bool:
			s.set(k, raw[k])
	return s

static func load_saved() -> Settings:
	if not FileAccess.file_exists(PATH):
		return Settings.new()
	return from_dict(JSON.parse_string(FileAccess.get_file_as_string(PATH)))

func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict()))
