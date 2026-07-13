extends "res://scripts/Enemy.gd"

# One of Rattles' three ghouls. Same core AI as a regular enemy, but
# leashed to its spawn point - if a chase pulls it too far from the
# pack, it gets pulled back rather than wandering off across the map.

@export var leash_radius: float = 260.0

var leash_point: Vector2 = Vector2.ZERO
var leash_set: bool = false

func _ready() -> void:
	super._ready()
	add_to_group("ghoul")
	torso.color = Color(0.85, 0.82, 0.72, 1)
	chest_strap.color = Color(0.5, 0.48, 0.4, 1)
	mask.visible = false
	if has_node("Visuals/Head"):
		$Visuals/Head.color = Color(0.88, 0.85, 0.76, 1)

func _physics_process(delta: float) -> void:
	if not leash_set:
		leash_point = global_position
		leash_set = true
	super._physics_process(delta)
	# super._physics_process() already dampens velocity toward zero while
	# stunned - without this check, the leash pull below overwrote that
	# with a full-speed snap back regardless of being "stunned".
	if Time.get_ticks_msec() >= stunned_until_ms and global_position.distance_to(leash_point) > leash_radius:
		var pull_dir: Vector2 = (leash_point - global_position).normalized()
		velocity = pull_dir * speed
		move_and_slide()
