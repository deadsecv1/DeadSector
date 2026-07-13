extends Control

# Shows a large weapon icon at the bottom of the screen while Close-Up
# View is active - meant to evoke the "gun in your hand" feel of a
# first-person shooter's viewmodel. This is still fundamentally a 2D
# top-down game - true first-person isn't something this engine can
# produce - but this is the closest honest approximation: your weapon,
# large, in view, reacting slightly as you move.

const ItemIconScene := preload("res://scenes/ItemIcon.tscn")

@export var icon_key: String = "pistol": set = _set_icon_key

var bob_phase: float = 0.0
var current_icon: Control = null

@onready var icon_holder: Control = $IconHolder

func _set_icon_key(value: String) -> void:
	if value == icon_key and current_icon != null:
		return
	icon_key = value
	_rebuild_icon()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rebuild_icon()
	set_process(true)

func _rebuild_icon() -> void:
	if current_icon != null:
		current_icon.queue_free()
	current_icon = ItemIconScene.instantiate()
	current_icon.icon_key = icon_key
	current_icon.icon_color = Color(0.75, 0.75, 0.78, 1)
	current_icon.anchor_right = 1.0
	current_icon.anchor_bottom = 1.0
	current_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.add_child(current_icon)

func _process(delta: float) -> void:
	bob_phase += delta * 2.0
	icon_holder.position.y = sin(bob_phase) * 3.0
