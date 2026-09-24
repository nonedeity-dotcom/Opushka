## Сохранения: три ячейки, в каждой — свой вид со своей сложностью.
class_name Saves
extends RefCounted

const COUNT := 3
const LAST := "user://last_slot.txt"

static func path(slot: int) -> String:
	return "user://slot_%d.json" % slot

static func load_slot(slot: int) -> Evolution:
	if not FileAccess.file_exists(path(slot)):
		return null
	return Evolution.from_dict(JSON.parse_string(FileAccess.get_file_as_string(path(slot))))

static func save_slot(slot: int, evo: Evolution) -> void:
	var f := FileAccess.open(path(slot), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(evo.to_dict()))
	var l := FileAccess.open(LAST, FileAccess.WRITE)
	if l and slot > 0:
		l.store_string(str(slot))

static func delete_slot(slot: int) -> void:
	if FileAccess.file_exists(path(slot)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path(slot)))

static func last_slot() -> int:
	if not FileAccess.file_exists(LAST):
		return 0
	return clampi(int(FileAccess.get_file_as_string(LAST)), 0, COUNT)

## Прежняя игра жила в одном файле — переносим её в первую ячейку.
static func migrate() -> void:
	var old := "user://evolution.json"
	if FileAccess.file_exists(old) and not FileAccess.file_exists(path(1)):
		var e := Evolution.from_dict(JSON.parse_string(FileAccess.get_file_as_string(old)))
		if e:
			save_slot(1, e)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(old))
