extends Sprite2D

# A small, hand-rolled animation player for horizontal-strip sprite
# sheets (each animation is its own PNG, N frames side by side).
# Simpler to drive from code than building full SpriteFrames resources
# by hand, and just as functional.

@export var frame_rate: float = 8.0

var animations: Dictionary = {}
var current_anim: String = ""
var current_frame: int = 0
var frame_timer: float = 0.0
var one_shot_finished := false

signal animation_finished

func add_animation(anim_name: String, anim_texture: Texture2D, frame_count: int) -> void:
	animations[anim_name] = {"texture": anim_texture, "frame_count": frame_count}

func play(anim_name: String, restart_if_same: bool = false) -> void:
	if not animations.has(anim_name):
		return
	if current_anim == anim_name and not restart_if_same:
		return
	current_anim = anim_name
	current_frame = 0
	frame_timer = 0.0
	one_shot_finished = false
	_apply_frame()

func _process(delta: float) -> void:
	if current_anim == "" or one_shot_finished:
		return
	frame_timer += delta
	if frame_timer >= 1.0 / frame_rate:
		frame_timer = 0.0
		var data: Dictionary = animations[current_anim]
		var count: int = data["frame_count"]
		if current_frame + 1 >= count:
			animation_finished.emit()
		current_frame = (current_frame + 1) % count
		_apply_frame()

func _apply_frame() -> void:
	var data: Dictionary = animations[current_anim]
	texture = data["texture"]
	hframes = data["frame_count"]
	vframes = 1
	frame = current_frame
