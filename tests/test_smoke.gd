extends RefCounted

func test_проект_запускается(c) -> void:
	c.eq("имя", ProjectSettings.get_setting("application/config/name"), "Опушка")
