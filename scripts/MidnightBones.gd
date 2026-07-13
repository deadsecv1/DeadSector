extends Node2D

# A stationary, quest-relevant NPC found only during a Boneclock NIGHT
# raid - a massive skeleton at his own small POI. Walk up and press F
# to talk; the first time, he hands over the Graveyard Key (completing
# the "find_midnight_bones" contract) and unlocks the Graveyard as a
# destination from the Salvaged Beasts screen. Talking again afterward
# just gets you a line of flavor text, no repeat rewards.

var player_in_range: bool = false
var f_was_down: bool = false
var pulse_phase: float = 0.0

const FIRST_TIME_LINES := [
	"...",
	"You're not the first to wander this deep into Boneclock at night. Most don't make it back out.",
	"I've been waiting a long time for someone worth talking to. Here - you'll need this where you're going.",
]
const REPEAT_LINES := [
	"The Graveyard's still there. It isn't going anywhere. Neither am I.",
	"Keep the key close. Lose it and you'll be back here asking nicely.",
]

@onready var prompt: Label = $Prompt
@onready var interact_zone: Area2D = $InteractZone
@onready var glow: Polygon2D = $Glow

func _ready() -> void:
	if not GameManager.is_night_raid:
		queue_free()
		return
	prompt.visible = false
	interact_zone.body_entered.connect(_on_entered)
	interact_zone.body_exited.connect(_on_exited)

func _on_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		prompt.visible = true

func _on_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		prompt.visible = false

func _process(delta: float) -> void:
	pulse_phase += delta * 1.1
	glow.modulate.a = 0.3 + 0.15 * sin(pulse_phase)

	if not player_in_range:
		return
	var f_down := Input.is_key_pressed(GameManager.get_keybind("interact"))
	if f_down and not f_was_down:
		_talk()
	f_was_down = f_down

func _talk() -> void:
	var already_done: bool = GameManager.is_quest_done("find_midnight_bones")
	var lines: Array = REPEAT_LINES if already_done else FIRST_TIME_LINES
	for line in lines:
		Notify.show_toast("Midnight Bones: %s" % line)
		await get_tree().create_timer(1.6).timeout
	if not already_done:
		GameManager.grant_graveyard_key()
		GameManager.notify_event("find_midnight_bones")
