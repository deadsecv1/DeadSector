extends StaticBody2D

# A stationary shooting-range target. Reuses the same hit-detection Bullet.gd
# already uses for enemies (group "enemy" + take_damage), so damage numbers
# and blood-hit feedback work automatically. Never actually "dies" - it's
# an infinite target for testing your damage output.

var total_damage: int = 0

# Real Enemy.gd instances expose `health` and an optional `weapon_name`
# param on take_damage() (for kill-log/kill-credit checks) - being in group
# "enemy" without matching that contract crashed both Grenade.gd's
# `enemy.health <= damage` read and FireGrenade.gd's/Grenade.gd's 2-arg
# `enemy.take_damage(damage, "Grenade")` call the moment a thrown grenade
# landed near this dummy. A huge, never-actually-depleting health value
# keeps "never actually dies" true while satisfying that contract.
var health: int = 999999

@onready var total_label: Label = $TotalLabel

func _ready() -> void:
	add_to_group("enemy")
	_refresh_label()

func take_damage(amount: int, _weapon_name: String = "") -> void:
	total_damage += amount
	_refresh_label()

func _refresh_label() -> void:
	total_label.text = "Total: %d" % total_damage
