extends Area2D

# A silent trigger zone - no prompt, no interaction needed. Just walking
# into it (e.g. reaching a landmark like the lake) fires a quest event
# once per run.

@export var quest_trigger: String = ""

var fired: bool = false

func _ready() -> void:
	body_entered.connect(_on_entered)

func _on_entered(body: Node) -> void:
	if fired or quest_trigger == "":
		return
	if body.is_in_group("player"):
		fired = true
		GameManager.notify_event(quest_trigger)
