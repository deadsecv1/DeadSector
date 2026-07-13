extends Area2D

# The outer boundary of the radiation area - no longer deals damage
# itself (that's each individual RadiationCloud's job now). Just gives
# the player a heads-up the first time they cross into the area.

var warned: bool = false

func _ready() -> void:
	body_entered.connect(_on_entered)

func _on_entered(body: Node) -> void:
	if body.is_in_group("player") and not warned:
		warned = true
		if not GameManager.has_gas_mask():
			Notify.show_toast("Radiation zone. The gas clouds will hurt you without a Gas Mask.")
