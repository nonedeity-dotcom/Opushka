extends Node2D

func _draw() -> void:
	draw_rect(Rect2(0, 0, 720, 1440), Color("#34503a"))
	draw_circle(Vector2(360, 600), 120, Color("#3a6a44"))
	draw_string(ThemeDB.fallback_font, Vector2(180, 900), "Опушка — проверка", HORIZONTAL_ALIGNMENT_LEFT, -1, 48)
