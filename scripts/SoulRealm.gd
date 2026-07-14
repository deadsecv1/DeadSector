extends Node2D

const WISP_SCENE := preload("res://scenes/Wisp.tscn")
const GHOST_PASSER_SCENE := preload("res://scenes/GhostPasserBy.tscn")
const PET_SCENE := preload("res://scenes/Pet.tscn")
const MAX_WAVE := 20

@onready var player = $Player
@onready var hud = $HUD
@onready var statue_station = $StatueStation
@onready var wave_label: Label = $WaveUI/WaveLabel
@onready var prompt_label: Label = $WaveUI/PromptLabel
@onready var victory_overlay: Panel = $VictoryOverlay
@onready var victory_continue_button: Button = $VictoryOverlay/VBox/ContinueButton

var wave_number: int = 0
var started: bool = false
var wisps_alive: int = 0
var wave_cleared_all: bool = false
var ghost_timer: float = 0.0
var next_ghost_time: float = 3.0

func _ready() -> void:
	GameManager.set_crosshair_cursor()
	hud.time_label.visible = false
	player.stats_ready.connect(hud.update_stats)
	player.ammo_changed.connect(hud.update_ammo)
	player._update_ammo_display()
	player.stunned.connect(hud.flash_stun)
	player.health_changed.connect(hud._on_player_health_changed)
	statue_station.interacted.connect(_on_statue_interact)
	_spawn_pet()
	wave_label.text = ""
	prompt_label.text = "Approach the Statue of the Great Harvester and press F to begin."
	Notify.show_toast("Welcome to the Soul Realm. The Harvester is waiting.")
	victory_overlay.visible = false
	victory_continue_button.pressed.connect(func():
		victory_overlay.visible = false
		player.set_input_locked(false)
	)

func _spawn_pet() -> void:
	if GameManager.equipped_pet == "":
		return
	var pet = PET_SCENE.instantiate()
	pet.pet_id = GameManager.equipped_pet
	add_child(pet)
	pet.global_position = player.global_position + Vector2(-40, 30)

func _process(delta: float) -> void:
	ghost_timer += delta
	if ghost_timer >= next_ghost_time:
		ghost_timer = 0.0
		next_ghost_time = randf_range(4.0, 9.0)
		_spawn_passing_ghost()

func _spawn_passing_ghost() -> void:
	var ghost = GHOST_PASSER_SCENE.instantiate()
	add_child(ghost)
	var side := randi() % 2
	var y := randf_range(-700.0, 700.0)
	if side == 0:
		ghost.position = Vector2(-1300.0, y)
		ghost.drift_direction = Vector2(1, randf_range(-0.15, 0.15))
	else:
		ghost.position = Vector2(1300.0, y)
		ghost.drift_direction = Vector2(-1, randf_range(-0.15, 0.15))
	ghost.travel_distance = 2600.0

func _on_statue_interact() -> void:
	if started:
		return
	started = true
	prompt_label.text = ""
	_start_wave(1)

func _start_wave(n: int) -> void:
	wave_number = n
	wave_label.text = "Wave %d / %d" % [wave_number, MAX_WAVE]
	Notify.show_toast("Wave %d begins..." % wave_number)
	var count: int = 2 + int(wave_number * 1.4)
	var health_mult: float = 1.0 + float(wave_number - 1) * 0.12
	var damage_mult: float = 1.0 + float(wave_number - 1) * 0.08
	wisps_alive = count
	for i in range(count):
		var wisp = WISP_SCENE.instantiate()
		wisp.max_health = int(wisp.max_health * health_mult)
		wisp.attack_damage = int(wisp.attack_damage * damage_mult)
		add_child(wisp)
		var ang: float = randf_range(0.0, TAU)
		var dist: float = randf_range(250.0, 420.0)
		wisp.global_position = Vector2(cos(ang), sin(ang)) * dist
		wisp.wisp_died.connect(_on_wisp_died)

func _on_wisp_died() -> void:
	wisps_alive -= 1
	if wisps_alive <= 0:
		_on_wave_cleared()

func _on_wave_cleared() -> void:
	if wave_number >= MAX_WAVE:
		_on_final_wave_cleared()
		return
	Notify.show_toast("Wave %d cleared!" % wave_number)
	prompt_label.text = "Wave %d cleared. Next wave incoming..." % wave_number
	await get_tree().create_timer(4.0).timeout
	prompt_label.text = ""
	_start_wave(wave_number + 1)

func _on_final_wave_cleared() -> void:
	wave_label.text = "ALL WAVES CLEARED"
	prompt_label.text = "The Harvester is satisfied. Head to extraction when ready."
	var bonus_souls := 800
	GameManager.add_currency("souls", bonus_souls)
	GameManager.grant_battle_pass_xp(300)
	GameManager.notify_event("survive_wave_20_commune")
	Notify.show_quest_toast("Wave 20 cleared! +%d Souls" % bonus_souls)
	victory_overlay.visible = true
	player.set_input_locked(true)
