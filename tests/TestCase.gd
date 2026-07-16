extends Node
class_name TestCase

# Base class for a test file: extend this, define any number of test_*()
# methods, and TestRunner.gd will discover and call them automatically
# (via get_method_list(), by name prefix - no manual registration needed).
# GDScript has no try/catch, so a genuine script error inside a test_*()
# method aborts that test immediately rather than being caught - keep
# test bodies to assertions and simple setup, not code that could itself
# throw. Extends Node (not RefCounted) so a test that needs to instance a
# scene has a valid tree to add it under (TestRunner adds each TestCase
# as its own child before calling into it).

var _failures: Array = []
var _assertion_count: int = 0

func assert_true(condition: bool, message: String = "") -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(message if message != "" else "expected true, got false")

func assert_false(condition: bool, message: String = "") -> void:
	assert_true(not condition, message if message != "" else "expected false, got true")

func assert_eq(actual, expected, message: String = "") -> void:
	_assertion_count += 1
	if actual != expected:
		var prefix := "%s: " % message if message != "" else ""
		_failures.append("%sexpected %s, got %s" % [prefix, str(expected), str(actual)])

func assert_ne(actual, expected, message: String = "") -> void:
	_assertion_count += 1
	if actual == expected:
		var prefix := "%s: " % message if message != "" else ""
		_failures.append("%sexpected something other than %s" % [prefix, str(expected)])

func assert_gt(actual, expected, message: String = "") -> void:
	_assertion_count += 1
	if not (actual > expected):
		var prefix := "%s: " % message if message != "" else ""
		_failures.append("%s%s is not > %s" % [prefix, str(actual), str(expected)])

func assert_gte(actual, expected, message: String = "") -> void:
	_assertion_count += 1
	if not (actual >= expected):
		var prefix := "%s: " % message if message != "" else ""
		_failures.append("%s%s is not >= %s" % [prefix, str(actual), str(expected)])

func assert_null(value, message: String = "") -> void:
	assert_true(value == null, message if message != "" else "expected null")

func assert_not_null(value, message: String = "") -> void:
	assert_true(value != null, message if message != "" else "expected non-null")

func assert_has(container, key, message: String = "") -> void:
	_assertion_count += 1
	var has_it: bool = container.has(key) if (container is Dictionary or container is Array) else false
	if not has_it:
		var prefix := "%s: " % message if message != "" else ""
		_failures.append("%sexpected %s to contain %s" % [prefix, str(container), str(key)])

func get_failures() -> Array:
	return _failures

func get_assertion_count() -> int:
	return _assertion_count
