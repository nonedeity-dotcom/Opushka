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

	## Числа — численно и с допуском (2 и 2.0, 31.5 и 31.4999… — одно и то же), векторы,
	## списки и словари — поэлементно, остальное — только при одинаковом типе: сравнение
	## разных типов в GDScript не «ложь», а ошибка.
	static func same(a: Variant, b: Variant) -> bool:
		var na := typeof(a) == TYPE_INT or typeof(a) == TYPE_FLOAT
		var nb := typeof(b) == TYPE_INT or typeof(b) == TYPE_FLOAT
		if na and nb:
			return absf(float(a) - float(b)) <= 1e-4 * maxf(1.0, absf(float(b)))
		if typeof(a) != typeof(b):
			return false
		match typeof(a):
			TYPE_VECTOR2, TYPE_VECTOR2I:
				return same(a.x, b.x) and same(a.y, b.y)
			TYPE_ARRAY:
				if a.size() != b.size():
					return false
				for i in a.size():
					if not same(a[i], b[i]):
						return false
				return true
			TYPE_DICTIONARY:
				if a.size() != b.size():
					return false
				for k in a:
					if not b.has(k) or not same(a[k], b[k]):
						return false
				return true
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
		# Файл проверок не собрался — это провал, а не повод зависнуть.
		if script == null or not script.can_instantiate():
			check.failed += 1
			print("  ✗ файл не собрался: ", f)
			continue
		var suite = script.new()
		for m in suite.get_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			check.current = name.substr(5).replace("_", " ")
			suite.call(name, check)
	print("\nВсё сошлось: %d." % check.passed if check.failed == 0 else "\nНе сошлось: %d из %d." % [check.failed, check.passed + check.failed])
	quit(0 if check.failed == 0 else 1)
