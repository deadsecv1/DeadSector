extends Area2D

# A searchable body left behind when an enemy dies - replaces the old
# instant ground-drop. ALL of that enemy's rolled loot (key, gear, rare
# blueprint, consumable, dog tags) sits inside and is handed to the player
# in one go after a short Tarkov-style search, using the same
# GameManager.start_search/report_search_progress/finish_search flow as
# Chest.gd so the Backpack screen auto-opens either way.

@export var search_duration: float = 1.8

var loot_items: Array = []
var currency_drops: Dictionary = {}
var is_real_player: bool = false

var searched: bool = false
var searching: bool = false
var player_in_range: bool = false
var glow: Polygon2D = null
var glow_tween: Tween = null

@onready var body_poly: Polygon2D = $Body
@onready var tag_mark: Polygon2D = $TagMark
@onready var prompt: Label = $Prompt

func _ready() -> void:
	add_to_group("corpse")
	body_poly.color = Color(0.14, 0.24, 0.16, 1) if is_real_player else Color(0.32, 0.11, 0.11, 1)
	tag_mark.visible = is_real_player
	prompt.visible = false
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)
	_update_prompt()
	if is_real_player and not loot_items.is_empty():
		_add_loot_glow()

# A soft pulsing gold glow so a Real Player's body - always worth the
# stop, given Dog Tags and better gear - actually stands out on the
# ground instead of blending in with a regular corpse. Removed the
# moment it's actually been searched, so an empty body stops calling
# attention to itself.
func _add_loot_glow() -> void:
	glow = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(20):
		var ang := TAU * float(i) / 20.0
		pts.append(Vector2(cos(ang), sin(ang)) * 15.0)
	glow.polygon = pts
	glow.color = Color(1.0, 0.85, 0.3, 0.3)
	glow.z_index = -1
	add_child(glow)
	move_child(glow, 0)
	glow_tween = glow.create_tween()
	glow_tween.bind_node(glow)
	glow_tween.set_loops()
	glow_tween.tween_property(glow, "scale", Vector2(1.3, 1.3), 0.9).set_trans(Tween.TRANS_SINE)
	glow_tween.parallel().tween_property(glow, "modulate:a", 0.6, 0.9).set_trans(Tween.TRANS_SINE)
	glow_tween.tween_property(glow, "scale", Vector2(0.85, 0.85), 0.9).set_trans(Tween.TRANS_SINE)
	glow_tween.parallel().tween_property(glow, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)

func _remove_loot_glow() -> void:
	if glow_tween != null:
		glow_tween.kill()
		glow_tween = null
	if glow != null and is_instance_valid(glow):
		glow.queue_free()
		glow = null

func _update_prompt() -> void:
	if searched:
		prompt.text = "Searched"
	elif loot_items.is_empty():
		prompt.text = "Nothing on the body"
	else:
		prompt.text = "Press F: Search Body"

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
	if searched or searching or not player_in_range or loot_items.is_empty():
		return
	if Input.is_key_pressed(GameManager.get_keybind("interact")) and not GameManager.is_searching:
		_start_search()

func _start_search() -> void:
	searching = true
	GameManager.is_searching = true
	Sfx.play_search()
	var effective_duration: float = max(0.4, search_duration - GameManager.get_upgrade_bonus("search_speed"))
	GameManager.start_search(loot_items, effective_duration)

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
	_finish_search()

func _finish_search() -> void:
	searched = true
	searching = false
	_remove_loot_glow()
	GameManager.is_searching = false
	for item in loot_items:
		GameManager.add_to_vicinity(item.duplicate(true), global_position)
	for cur in currency_drops:
		if cur == "tickets":
			GameManager.grant_salvaged_beasts_tickets(int(currency_drops[cur]))
		else:
			GameManager.add_currency(cur, int(currency_drops[cur]))
	GameManager.finish_search()
	prompt.text = "Searched"
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(self):
		prompt.visible = false
