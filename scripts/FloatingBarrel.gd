extends Area2D

# A loot barrel bobbing in the lake - only reachable by boat since it
# sits out in the water, away from any walkable shore.

@export var item_name: String = "Waterlogged Crate"
@export var base_value: int = 90
@export var slot: String = "valuable"
@export var stat_type: String = ""
@export var base_stat_value: float = 0.0
@export var icon_key: String = "duct_tape"
@export var rarity: String = "uncommon"

var searched: bool = false
var player_in_range: bool = false
var f_was_down: bool = false
var bob_phase: float = 0.0
var base_y: float = 0.0

@onready var body_poly: Polygon2D = $Body
@onready var prompt: Label = $Prompt

func _ready() -> void:
	add_to_group("floating_barrel")
	base_y = position.y
	bob_phase = randf_range(0.0, TAU)
	prompt.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and not searched:
		player_in_range = true
		prompt.visible = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		prompt.visible = false

func _process(delta: float) -> void:
	bob_phase += delta * 1.3
	position.y = base_y + sin(bob_phase) * 5.0
	rotation = sin(bob_phase * 0.7) * 0.08

	if searched or not player_in_range:
		return
	var f_down := Input.is_key_pressed(GameManager.get_keybind("interact"))
	if f_down and not f_was_down:
		_search()
	f_was_down = f_down

func _search() -> void:
	searched = true
	prompt.visible = false
	GameManager.is_searching = true
	Sfx.play_search()
	var mult := GameManager.get_rarity_multiplier(rarity)
	var rolled_item := {
		"name": item_name, "value": int(round(base_value * mult)), "slot": slot,
		"stat_type": stat_type, "stat_value": snapped(base_stat_value * mult, 0.01),
		"icon_key": icon_key, "rarity": rarity,
	}
	var duration := 1.4
	GameManager.start_search([rolled_item], duration)
	if randf() < 0.05:
		GameManager.add_currency("skill_points", 1)
	var elapsed := 0.0
	while elapsed < duration:
		await get_tree().create_timer(0.1).timeout
		if not is_instance_valid(self):
			GameManager.is_searching = false
			return
		elapsed += 0.1
		GameManager.report_search_progress(min(elapsed / duration, 1.0))
	GameManager.is_searching = false
	GameManager.add_to_vicinity(rolled_item, global_position)
	GameManager.finish_search()
	body_poly.color = Color(0.2, 0.18, 0.12, 1)
