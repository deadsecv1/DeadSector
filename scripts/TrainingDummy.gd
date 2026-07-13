extends StaticBody2D

# A stationary shooting-range target. Reuses the same hit-detection Bullet.gd
# already uses for enemies (group "enemy" + take_damage), so damage numbers
# and blood-hit feedback work automatically. Never actually "dies" - it's
# an infinite target for testing your damage output.

var total_damage: int = 0

@onready var total_label: Label = $TotalLabel

func _ready() -> void:
	add_to_group("enemy")
	_refresh_label()

func take_damage(amount: int) -> void:
	total_damage += amount
	_refresh_label()

func _refresh_label() -> void:
	total_label.text = "Total: %d" % total_damage
