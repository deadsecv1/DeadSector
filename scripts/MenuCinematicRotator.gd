extends Control

# Rotates between several ambient background vignettes behind the Main
# Menu - picks one at random on load, then periodically crossfades to
# a different randomly-picked one (never immediately repeating) while
# the player sits at the menu, so a long session doesn't just stare at
# one static scene the whole time. Each vignette is a full-rect child
# Control added in MainMenu.tscn - this script only manages which one
# is visible, the vignettes themselves don't know about each other.

const ROTATE_MIN_SECONDS := 32.0
const ROTATE_MAX_SECONDS := 55.0
const CROSSFADE_SECONDS := 2.2

var _vignettes: Array = []
var _current_index: int = -1
var _timer: float = 0.0
var _next_rotate: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in get_children():
		if child is Control:
			_vignettes.append(child)
			child.modulate.a = 0.0
	if _vignettes.is_empty():
		return
	_current_index = randi() % _vignettes.size()
	_vignettes[_current_index].modulate.a = 1.0
	_next_rotate = randf_range(ROTATE_MIN_SECONDS, ROTATE_MAX_SECONDS)
	set_process(true)

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= _next_rotate:
		_timer = 0.0
		_next_rotate = randf_range(ROTATE_MIN_SECONDS, ROTATE_MAX_SECONDS)
		_rotate_to_next()

func _rotate_to_next() -> void:
	if _vignettes.size() < 2:
		return
	var new_index := _current_index
	while new_index == _current_index:
		new_index = randi() % _vignettes.size()
	var old_vignette = _vignettes[_current_index]
	var new_vignette = _vignettes[new_index]
	_current_index = new_index
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(old_vignette, "modulate:a", 0.0, CROSSFADE_SECONDS)
	tw.tween_property(new_vignette, "modulate:a", 1.0, CROSSFADE_SECONDS)
