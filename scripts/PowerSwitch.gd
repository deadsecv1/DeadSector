extends Area2D

# An interactable power switch. Press F to turn it on - fires `activated`
# so whatever owns the lights (Main.gd) can fade them in, and completes
# the "Turn on the power" quest.

signal activated

@export var quest_event: String = "ashen_house_power"

var player_in_range: bool = false
var powered: bool = false

@onready var prompt: Label = $Prompt
@onready var switch_poly: Polygon2D = $Polygon2D

func _ready() -> void:
	prompt.visible = false
	switch_poly.color = Color(0.5, 0.1, 0.1, 1)
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)

func _on_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		if not powered:
			prompt.visible = true

func _on_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		prompt.visible = false

func _process(_delta: float) -> void:
	if powered or not player_in_range:
		return
	if GameManager.is_action_pressed("interact"):
		_activate()

func _activate() -> void:
	powered = true
	prompt.visible = false
	switch_poly.color = Color(0.2, 0.9, 0.3, 1)
	Sfx.play_door()
	GameManager.notify_event(quest_event)
	GameManager.toast_requested.emit("Power restored.")
	activated.emit()
