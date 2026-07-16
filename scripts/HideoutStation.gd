extends Area2D

# A generic interactable station in the Hideout (Gym, Bedroom, etc).
# Shows a prompt when the player is near and emits "interacted" on E.

@export var prompt_text: String = "Press F: Interact"
@export var zone_size: Vector2 = Vector2(80, 80)

# Optional flavor lines for NPC stations (Rose, Lil Dirty, Justin, the
# Ghost) - if set, one line pops up in a speech bubble above the
# character (see speech_bubble_offset) the moment the player comes into
# range, and disappears the moment they leave. Only ever one bubble
# alive at a time per station (_bubble guards against re-triggering
# while already showing) - non-NPC stations (Gym, Workbench, etc.) just
# leave this empty and get no bubble at all.
@export var speech_lines: Array[String] = []
@export var speech_bubble_offset: Vector2 = Vector2(0, -100)

var player_in_range: bool = false
var _key_was_down: bool = false
var _locked: bool = false
var _locked_text: String = "Locked"
var _bubble: Label = null
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
		_show_speech_bubble()

func _on_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		prompt.visible = false
		_hide_speech_bubble()

func _show_speech_bubble() -> void:
	if speech_lines.is_empty() or _bubble != null:
		return
	_bubble = Label.new()
	_bubble.text = speech_lines[randi() % speech_lines.size()]
	_bubble.add_theme_font_size_override("font_size", 13)
	_bubble.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_bubble.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_bubble.add_theme_constant_override("outline_size", 3)
	_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD
	_bubble.custom_minimum_size = Vector2(160, 0)
	_bubble.position = speech_bubble_offset + Vector2(-80, 0)
	_bubble.modulate.a = 0.0
	add_child(_bubble)
	var tw := create_tween()
	tw.tween_property(_bubble, "modulate:a", 1.0, 0.25)

func _hide_speech_bubble() -> void:
	if _bubble == null:
		return
	var b := _bubble
	_bubble = null
	var tw := create_tween()
	tw.tween_property(b, "modulate:a", 0.0, 0.2)
	tw.tween_callback(b.queue_free)

func _process(_delta: float) -> void:
	# Edge-detected: fires once per press, not once per frame the key is
	# held. It used to check is_key_pressed() directly every frame, which
	# fired "interacted" (and whatever toast/panel that triggers) dozens
	# of times for a single normal-length key press.
	var key_down: bool = player_in_range and not _locked and GameManager.is_action_pressed("interact")
	if key_down and not _key_was_down:
		interacted.emit()
	_key_was_down = key_down
