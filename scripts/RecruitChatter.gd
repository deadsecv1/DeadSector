extends Area2D

@export var lines: PackedStringArray = []

var showing: bool = false
var cooldown: float = 0.0

@onready var bubble_bg: PanelContainer = $BubbleBox
@onready var bubble: Label = $BubbleBox/Bubble

func _ready() -> void:
	bubble_bg.visible = false
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)

func _on_entered(body: Node) -> void:
	if body.is_in_group("player") and not showing and cooldown <= 0.0:
		_say_something()

func _on_exited(body: Node) -> void:
	if body.is_in_group("player"):
		bubble_bg.visible = false
		showing = false

func _process(delta: float) -> void:
	if cooldown > 0.0:
		cooldown -= delta

func _say_something() -> void:
	if lines.is_empty():
		return
	showing = true
	bubble.text = lines[randi() % lines.size()]
	bubble_bg.visible = true
	await get_tree().create_timer(3.5).timeout
	if is_instance_valid(bubble_bg):
		bubble_bg.visible = false
	showing = false
	cooldown = 2.0
