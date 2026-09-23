## Проверки: godot --headless -s tests/run.gd
##
## Без сторонних библиотек: проверкам нужны две функции, а зависимость — это то, что
## однажды перестанет ставиться. Каждый файл tests/test_*.gd — класс с методами test_*,
## у каждого метода свой объект Check.
extends SceneTree

class Check:
	var failed := 0
	var passed := 0
	var current := ""

	## Числа — численно (2 и 2.0 одно и то же), остальное — только при одинаковом типе:
	## сравнение разных типов в GDScript не «ложь», а ошибка.
	static func same(a: Variant, b: Variant) -> bool:
		var na := typeof(a) == TYPE_INT or typeof(a) == TYPE_FLOAT
		var nb := typeof(b) == TYPE_INT or typeof(b) == TYPE_FLOAT
		if na and nb:
			return is_equal_approx(float(a), float(b))
		if typeof(a) != typeof(b):
			return false
		return a == b

	func eq(label: String, got: Variant, want: Variant) -> void:
		if same(got, want):
			passed += 1
			return
		failed += 1
		print("  ✗ %s → %s\n      получено %s\n      ждали   %s" % [current, label, var_to_str(got), var_to_str(want)])

	func ok(label: String, cond: bool) -> void:
		eq(label, cond, true)

func _init() -> void:
	var check := Check.new()
	var dir := DirAccess.open("res://tests")
	var files := Array(dir.get_files()).filter(func(f): return f.begins_with("test_") and f.ends_with(".gd"))
	files.sort()
	for f in files:
		print(f.get_basename())
		var script: GDScript = load("res://tests/" + f)
		var suite = script.new()
		for m in suite.get_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			check.current = name.substr(5).replace("_", " ")
			suite.call(name, check)
	print("\nВсё сошлось: %d." % check.passed if check.failed == 0 else "\nНе сошлось: %d из %d." % [check.failed, check.passed + check.failed])
	quit(0 if check.failed == 0 else 1)
