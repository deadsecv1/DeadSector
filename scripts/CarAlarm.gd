extends Area2D

# Attach as a child of a parked car. When the player walks near, the
# alarm blares and its lights pulse red for a few seconds - a fun bit of
# environmental noise (and a risk, since it can draw enemy attention).

@export var alarm_duration: float = 1.0
@export var cooldown: float = 20.0

var triggered: bool = false
var on_cooldown: bool = false

@onready var light_l: Polygon2D = $LightL
@onready var light_r: Polygon2D = $LightR

func _ready() -> void:
	light_l.visible = false
	light_r.visible = false
	body_entered.connect(_on_entered)

func _on_entered(body: Node) -> void:
	if body.is_in_group("player") and not triggered and not on_cooldown:
		_start_alarm()

func _start_alarm() -> void:
	triggered = true
	light_l.visible = true
	light_r.visible = true
	Sfx.play_alarm()

	var elapsed := 0.0
	while elapsed < alarm_duration:
		var pulse: float = 0.4 + 0.5 * abs(sin(elapsed * 6.0))
		light_l.modulate.a = pulse
		light_r.modulate.a = pulse
		if fmod(elapsed, 1.0) < 0.05:
			Sfx.play_alarm()
		await get_tree().create_timer(0.05).timeout
		elapsed += 0.05
		if not is_instance_valid(self):
			return

	light_l.visible = false
	light_r.visible = false
	triggered = false
	on_cooldown = true
	await get_tree().create_timer(cooldown).timeout
	if is_instance_valid(self):
		on_cooldown = false
