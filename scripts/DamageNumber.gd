extends Node2D
class_name DamageNumber

# Floating damage number that rises and fades - shown wherever the player's
# bullets land a hit, so damage output is visible at a glance.
#
# Pooled at the class level instead of instantiate()/queue_free() per hit -
# at max fire rate (~12.5 shots/sec) plus multi-pellet weapons landing on
# several enemies at once, that was a steady stream of fresh Label.new() +
# theme-override allocations during sustained fights. Callers use
# DamageNumber.get_instance(...) instead of instancing the scene directly.

const SCENE := preload("res://scenes/DamageNumber.tscn")
const POOL_MAX := 24

static var _pool: Array = []

var _label: Label
var _tween: Tween

static func get_instance(parent: Node, global_pos: Vector2, amount: int, crit: bool = false) -> void:
	var inst: Node2D = null
	while not _pool.is_empty():
		var candidate = _pool.pop_back()
		if is_instance_valid(candidate):
			inst = candidate
			break
	if inst == null:
		inst = SCENE.instantiate()
		parent.add_child(inst)
	elif inst.get_parent() != parent:
		inst.get_parent().remove_child(inst)
		parent.add_child(inst)
	inst.visible = true
	inst.global_position = global_pos
	inst._activate(amount, crit)

func _ready() -> void:
	_label = Label.new()
	add_child(_label)
	_label.position = Vector2(-10, -10)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("outline_size", 3)

func _activate(amount: int, crit: bool) -> void:
	_label.text = str(amount)
	_label.add_theme_font_size_override("font_size", 22 if crit else 18)
	_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1) if crit else Color(1, 0.95, 0.6, 1))
	_label.modulate.a = 1.0

	if _tween != null and _tween.is_valid():
		_tween.kill()

	var drift := Vector2(randf_range(-8, 8), -32)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "position", position + drift, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_label, "modulate:a", 0.0, 0.55).set_delay(0.15)

	await get_tree().create_timer(0.7).timeout
	if not is_instance_valid(self):
		return
	_return_to_pool()

func _return_to_pool() -> void:
	visible = false
	if _pool.size() < POOL_MAX:
		_pool.append(self)
	else:
		queue_free()
