extends StaticBody2D

# A searchable chest/drawer - the source of vault-room loot instead of items
# sitting on the ground. Press F to search; after a short delay the item is
# added straight to your backpack (and, for high-value vault chests, some
# Artifacts too - Artifacts only come from these).

@export var item_name: String = "Item"
@export var base_value: int = 50
@export var slot: String = "accessory"
@export var stat_type: String = "speed"
@export var base_stat_value: float = 10.0
@export var icon_key: String = "generic"
@export var rarity: String = "common"
@export var grants_artifacts: int = 0
@export var search_duration: float = 1.6
@export var quest_trigger: String = ""
@export var chest_size: Vector2 = Vector2(46, 34)

var searched: bool = false
var searching: bool = false
var player_in_range: bool = false

@onready var body_poly: Polygon2D = $Body
@onready var lid_poly: Polygon2D = $Lid
@onready var prompt: Label = $Prompt
@onready var interact_zone: Area2D = $InteractZone
@onready var interact_shape: CollisionShape2D = $InteractZone/CollisionShape2D
@onready var shape_node: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("walls")

	var shape := RectangleShape2D.new()
	shape.size = chest_size
	shape_node.shape = shape

	var izone_shape := RectangleShape2D.new()
	izone_shape.size = chest_size + Vector2(50, 50)
	interact_shape.shape = izone_shape

	var half := chest_size / 2.0
	body_poly.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y * 0.3), Vector2(half.x, -half.y * 0.3),
		Vector2(half.x, half.y), Vector2(-half.x, half.y)
	])
	lid_poly.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, -half.y * 0.3), Vector2(-half.x, -half.y * 0.3)
	])

	prompt.visible = false
	interact_zone.body_entered.connect(_on_entered)
	interact_zone.body_exited.connect(_on_exited)

func _on_entered(body: Node) -> void:
	if body.is_in_group("player") and not searched:
		player_in_range = true
		prompt.text = GameManager.format_prompt("Press F: Search")
		prompt.visible = true

func _on_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		if not searching:
			prompt.visible = false

func _process(_delta: float) -> void:
	if searched or searching or not player_in_range:
		return
	if GameManager.is_action_pressed("interact") and not GameManager.is_searching:
		_start_search()

func _start_search() -> void:
	searching = true
	GameManager.is_searching = true
	Sfx.play_chest_open()
	var effective_duration: float = max(0.4, search_duration - GameManager.get_upgrade_bonus("search_speed"))

	# Roll everything NOW, before the timer starts, so the search UI can
	# reveal what you're actually finding one piece at a time instead of
	# a blind progress bar.
	var mult := GameManager.get_rarity_multiplier(rarity)
	var rolled_items: Array = [{
		"name": item_name, "value": int(round(base_value * mult)), "slot": slot,
		"stat_type": stat_type, "stat_value": snapped(base_stat_value * mult, 0.01),
		"icon_key": icon_key, "rarity": rarity,
	}]
	var loot_hound_bonus: float = 0.08 if GameManager.player_trait == "loot_hound" else 0.0
	if randf() < 0.05 + loot_hound_bonus:
		rolled_items.append(GameManager.roll_blueprint())
	if randf() < 0.05 + loot_hound_bonus:
		var specialized_case: Dictionary = GameManager.roll_specialized_case()
		if not specialized_case.is_empty():
			rolled_items.append(specialized_case)
	if randf() < 0.5:
		rolled_items.append(GameManager.roll_attachment())
	if randf() < 0.5:
		rolled_items.append(GameManager.roll_ruble_item())
	if randf() < 0.4:
		rolled_items.append(GameManager.roll_valuable())
	if randf() < 0.25:
		rolled_items.append({"name": "Graphics Card", "value": 180, "slot": "valuable", "stat_type": "", "stat_value": 0.0, "icon_key": "gpu", "rarity": "rare"})
	if randf() < 0.2 + loot_hound_bonus:
		rolled_items.append(GameManager.roll_loot_bag_item())
	if randf() < 0.55:
		rolled_items.append(GameManager.roll_ammo())
	if randf() < 0.45:
		rolled_items.append(GameManager.roll_plushie())
	var chest_egg := GameManager.roll_pet_egg_drop(0.12)
	if not chest_egg.is_empty():
		rolled_items.append(chest_egg)
	if randf() < 0.1:
		GameManager.add_currency("skill_points", 1)

	GameManager.start_search(rolled_items, effective_duration, global_position)
	var elapsed := 0.0
	while elapsed < effective_duration:
		await get_tree().create_timer(0.1).timeout
		if not is_instance_valid(self):
			GameManager.is_searching = false
			return
		elapsed += 0.1
		var pct: float = min(elapsed / effective_duration, 1.0)
		prompt.text = "Searching... %d%%" % int(pct * 100)
		GameManager.report_search_progress(pct)
	_finish_search(rolled_items)

func _finish_search(rolled_items: Array) -> void:
	searched = true
	searching = false
	GameManager.is_searching = false
	# Each item was already added to vicinity_items as its own reveal
	# threshold was crossed (see GameManager.report_search_progress) -
	# finish_search() below also sweeps up anything the last progress
	# tick's float rounding left just short of its own threshold.
	if grants_artifacts > 0:
		GameManager.add_currency("artifacts", grants_artifacts)
	GameManager.finish_search()
	if quest_trigger != "":
		GameManager.notify_event(quest_trigger)
	lid_poly.color = Color(0.14, 0.28, 0.14, 1)
	prompt.text = "Searched"
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(self):
		prompt.visible = false
