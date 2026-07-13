extends Area2D

# A generic interactable station in the Hideout (Gym, Bedroom, etc).
# Shows a prompt when the player is near and emits "interacted" on E.

@export var prompt_text: String = "Press F: Interact"
@export var zone_size: Vector2 = Vector2(80, 80)

var player_in_range: bool = false
var _key_was_down: bool = false
var _locked: bool = false
var _locked_text: String = "Locked"
signal interacted

@onready var prompt: Label = $Prompt
@onready var shape_node: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = zone_size
	shape_node.shape = shape
	prompt.visible = false
	prompt.text = prompt_text
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)

# Used by stations that exist in the world before they're actually usable
# (e.g. recruits before their unlock quest) - previously these showed a
# fully normal "Press F: Interact" prompt with nothing indicating they
# wouldn't actually do anything, even though the real gate was already
# correctly enforced wherever "interacted" gets handled.
func set_locked(value: bool, locked_text: String = "Locked") -> void:
	_locked = value
	_locked_text = locked_text
	if player_in_range:
		prompt.text = _locked_text if _locked else prompt_text
		prompt.modulate = Color(1, 1, 1, 0.5) if _locked else Color(1, 1, 1, 1)

func _on_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		prompt.visible = true
		prompt.text = _locked_text if _locked else prompt_text
		prompt.modulate = Color(1, 1, 1, 0.5) if _locked else Color(1, 1, 1, 1)

func _on_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		prompt.visible = false

func _process(_delta: float) -> void:
	# Edge-detected: fires once per press, not once per frame the key is
	# held. It used to check is_key_pressed() directly every frame, which
	# fired "interacted" (and whatever toast/panel that triggers) dozens
	# of times for a single normal-length key press.
	var key_down: bool = player_in_range and not _locked and Input.is_key_pressed(GameManager.get_keybind("interact"))
	if key_down and not _key_was_down:
		interacted.emit()
	_key_was_down = key_down
