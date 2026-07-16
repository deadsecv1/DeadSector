extends Area2D

# A two-step lootable: first clear the debris pile on top (Press F), then
# search the stash revealed underneath (Press F again, takes a moment).

@export var item_name: String = "Hidden Stash"
@export var base_value: int = 80
@export var slot: String = "valuable"
@export var stat_type: String = ""
@export var base_stat_value: float = 0.0
@export var icon_key: String = "duct_tape"
@export var rarity: String = "uncommon"
@export var search_duration: float = 2.2

var cleared: bool = false
var searched: bool = false
var searching: bool = false
var player_in_range: bool = false

@onready var debris_poly: Polygon2D = $Debris
@onready var prompt: Label = $Prompt
@onready var debris_visual: CanvasItem = $Debris

func _ready() -> void:
	prompt.visible = false
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)
	_update_prompt()
	_try_load_external_sprite()

# --- Optional external art: if res://assets/props/debris.png exists, use
# it in place of the vector rubble pile. debris_visual is repointed to
# whichever node is actually on screen so _clear_debris() fades the
# right one.
func _try_load_external_sprite() -> void:
	var path := "res://assets/props/debris.png"
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	if tex == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(2.5, 2.5)
	add_child(sprite)
	debris_poly.visible = false
	debris_visual = sprite

func _update_prompt() -> void:
	if searched:
		prompt.text = "Searched"
	elif not cleared:
		prompt.text = "Press F: Clear Debris"
	else:
		prompt.text = "Press F: Search Stash"

func _on_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		prompt.visible = true

func _on_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		if not searching:
			prompt.visible = false

func _process(_delta: float) -> void:
	if searched or searching or not player_in_range:
		return
	if GameManager.is_action_pressed("interact"):
		if not cleared:
			_clear_debris()
		elif not GameManager.is_searching:
			_start_search()

func _clear_debris() -> void:
	cleared = true
	var tw := debris_visual.create_tween()
	tw.tween_property(debris_visual, "modulate:a", 0.0, 0.6)
	Sfx.play_door()
	_update_prompt()

func _start_search() -> void:
	searching = true
	GameManager.is_searching = true
	Sfx.play_search()
	var mult := GameManager.get_rarity_multiplier(rarity)
	var rolled_item := {
		"name": item_name, "value": int(round(base_value * mult)), "slot": slot,
		"stat_type": stat_type, "stat_value": snapped(base_stat_value * mult, 0.01),
		"icon_key": icon_key, "rarity": rarity,
	}
	GameManager.start_search([rolled_item], search_duration)
	if randf() < 0.05:
		GameManager.add_currency("skill_points", 1)
	var elapsed := 0.0
	while elapsed < search_duration:
		await get_tree().create_timer(0.1).timeout
		if not is_instance_valid(self):
			GameManager.is_searching = false
			return
		elapsed += 0.1
		var pct: float = min(elapsed / search_duration, 1.0)
		prompt.text = "Searching... %d%%" % int(pct * 100)
		GameManager.report_search_progress(pct)
	_finish_search(rolled_item)

func _finish_search(rolled_item: Dictionary) -> void:
	searched = true
	searching = false
	GameManager.is_searching = false
	GameManager.add_to_vicinity(rolled_item, global_position)
	GameManager.finish_search()
	prompt.text = "Searched"
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(self):
		prompt.visible = false
