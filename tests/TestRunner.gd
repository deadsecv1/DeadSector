extends Node

# Repeatable regression test suite. Run with:
#   "<godot exe>" --headless --path . tests/TestRunner.tscn --quit-after 60
#
# Boots as a real scene (not `godot -s`) so the GameManager/Sfx/Transition/
# GlobalChatBox autoloads actually initialize - a bare -s script doesn't
# resolve autoloads at all (see CLAUDE.md), and nearly everything worth
# testing here lives in the GameManager autoload.
#
# Discovers every tests/test_*.gd file, instances it (each extends
# TestCase.gd), calls every method on it named test_*(), and aggregates
# pass/fail. Exits with code 0 if everything passed, 1 if anything failed -
# safe to script/check `$LASTEXITCODE` (PowerShell) or `$?` (bash) against.

func _ready() -> void:
	# Must be set before any test file runs (GameManager's own _ready()
	# already ran load_game() by this point, as a normal autoload - that's
	# harmless since it only reads from disk. This flag instead guards
	# save_game()'s disk write/rotate, which plenty of real mutators
	# exercised by the tests below call directly, and which also fires
	# from the 5-second autosave timer for the whole duration of this run -
	# without it, running this suite silently overwrites the developer's
	# actual user://savegame.json and destroys its one .bak backup.
	GameManager.test_mode = true
	print("=".repeat(60))
	print("Dead Sector test suite")
	print("=".repeat(60))
	var test_files := _discover_test_files()
	if test_files.is_empty():
		print("No test_*.gd files found in res://tests/")
		get_tree().quit(1)
		return

	var total_assertions := 0
	var total_failures: Array = []
	var files_run := 0

	for file_name in test_files:
		var script: Script = load("res://tests/%s" % file_name)
		if script == null:
			total_failures.append("%s: failed to load script" % file_name)
			continue
		var instance = script.new()
		if not (instance is TestCase):
			total_failures.append("%s: does not extend TestCase" % file_name)
			if instance is Node:
				instance.queue_free()
			continue
		add_child(instance)
		files_run += 1

		var test_methods: Array = []
		for m in instance.get_method_list():
			var method_name: String = m["name"]
			if method_name.begins_with("test_"):
				test_methods.append(method_name)
		test_methods.sort()

		if instance.has_method("before_each_file"):
			instance.call("before_each_file")

		for method_name in test_methods:
			# `await` works whether or not the test itself actually awaits
			# anything internally - tests that instance a scene needing a
			# frame to settle (e.g. a deferred call scheduled from _ready())
			# can just `await get_tree().process_frame` themselves.
			await instance.call(method_name)

		var failures: Array = instance.get_failures()
		var assertions: int = instance.get_assertion_count()
		total_assertions += assertions
		if failures.is_empty():
			print("  PASS  %-45s (%d assertions across %d tests)" % [file_name, assertions, test_methods.size()])
		else:
			print("  FAIL  %-45s (%d/%d assertions failed, %d tests)" % [file_name, failures.size(), assertions, test_methods.size()])
			for f in failures:
				print("        - %s" % f)
				total_failures.append("%s: %s" % [file_name, f])

		remove_child(instance)
		instance.queue_free()

	print("-".repeat(60))
	print("%d test file(s) run, %d assertion(s), %d failure(s)" % [files_run, total_assertions, total_failures.size()])
	print("=".repeat(60))
	get_tree().quit(1 if not total_failures.is_empty() else 0)

func _discover_test_files() -> Array:
	var files: Array = []
	var dir := DirAccess.open("res://tests")
	if dir == null:
		return files
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.begins_with("test_") and file_name.ends_with(".gd"):
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	files.sort()
	return files
