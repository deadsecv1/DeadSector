extends Camera2D

# Simple decaying camera shake. Call shake(strength) to trigger/add to it.

var shake_strength: float = 0.0
var shake_decay: float = 5.0

func shake(strength: float) -> void:
	if not GameManager.screen_shake_enabled:
		return
	shake_strength = max(shake_strength, strength)

func _process(delta: float) -> void:
	if shake_strength > 0.05:
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_strength
		shake_strength = lerp(shake_strength, 0.0, delta * shake_decay)
	else:
		shake_strength = 0.0
		offset = Vector2.ZERO
