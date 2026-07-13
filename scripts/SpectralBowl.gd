extends Node2D

# A Spectral Bowl in the Graveyard - approach and press F to disturb
# it, which summons waves of shadow-beasts to defend it from. Clear
# every wave and the last beast can be pacified into a companion that
# follows you for the rest of the raid. Extract with it still alive
# and it's yours for good (see GameManager._check_pacified_extraction).

@export var pacified_pet_type: String = "shade_hound"
@export var wave_count: int = 3
@export var enemies_per_wave: int = 3
@export var spawn_radius: float = 150.0

const SHADOW_BEAST_SCENE := preload("res://scenes/RiftWraith.tscn")
const PET_SCENE := preload("res://scenes/Pet.tscn")
const SHADOW_TINT := Color(0.55, 0.4, 0.85, 1)

var activated: bool = false
var cleared: bool = false
var pacified: bool = false
var current_wave: int = 0
var alive_enemies: Array = []
var player_in_range: bool = false
var f_was_down: bool = false
var glow_phase: float = 0.0

@onready var interact_zone: Area2D = $InteractZone
@onready var prompt: Label = $Prompt
@onready var bowl_visual: Polygon2D = $BowlVisual
@onready var bowl_glow: Polygon2D = $BowlGlow

func _ready() -> void:
	interact_zone.body_entered.connect(_on_entered)
	interact_zone.body_exited.connect(_on_exited)
	prompt.visible = false
	prompt.text = "[F] Disturb the Bowl"

func _on_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		if not pacified:
			prompt.visible = true

func _on_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		prompt.visible = false

func _process(delta: float) -> void:
	glow_phase += delta * (3.0 if activated and not cleared else 1.0)
	var pulse: float = 0.4 + 0.3 * sin(glow_phase)
	bowl_glow.modulate.a = pulse
	if player_in_range and not pacified:
		var f_down := Input.is_key_pressed(GameManager.get_keybind("interact"))
		if f_down and not f_was_down:
			if not activated:
				_start_waves()
			elif cleared:
				_pacify()
		f_was_down = f_down
	else:
		f_was_down = false

func _start_waves() -> void:
	activated = true
	prompt.visible = false
	bowl_visual.color = Color(0.5, 0.15, 0.55, 1)
	current_wave = 0
	_spawn_wave()

func _spawn_wave() -> void:
	current_wave += 1
	alive_enemies.clear()
	for i in range(enemies_per_wave):
		var beast = SHADOW_BEAST_SCENE.instantiate()
		get_parent().call_deferred("add_child", beast)
		var ang := randf_range(0.0, TAU)
		var pos: Vector2 = global_position + Vector2(cos(ang), sin(ang)) * spawn_radius
		beast.set_deferred("global_position", pos)
		beast.set_deferred("modulate", SHADOW_TINT)
		alive_enemies.append(beast)
		beast.died.connect(_on_enemy_died.bind(beast))
	GameManager.toast_requested.emit("Spectral Bowl - Wave %d/%d" % [current_wave, wave_count])

func _on_enemy_died(beast: Node) -> void:
	alive_enemies.erase(beast)
	if not alive_enemies.is_empty():
		return
	if current_wave >= wave_count:
		_on_all_waves_cleared()
	else:
		await get_tree().create_timer(2.5).timeout
		if is_instance_valid(self):
			_spawn_wave()

func _on_all_waves_cleared() -> void:
	cleared = true
	bowl_visual.color = Color(0.3, 0.85, 0.7, 1)
	prompt.text = "[F] Pacify the beast"
	GameManager.toast_requested.emit("The bowl is quiet now. Something's still watching, though.")
	if player_in_range:
		prompt.visible = true

func _pacify() -> void:
	pacified = true
	prompt.visible = false
	GameManager.begin_pacifying(pacified_pet_type)
	var pet_data := GameManager.get_pet_data(pacified_pet_type)
	GameManager.toast_requested.emit("%s is pacified - keep it alive and extract to keep it." % pet_data.get("name", "The beast"))
	var companion = PET_SCENE.instantiate()
	companion.pet_id = pacified_pet_type
	get_parent().call_deferred("add_child", companion)
	companion.set_deferred("global_position", global_position)
