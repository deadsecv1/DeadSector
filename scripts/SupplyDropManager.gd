extends Node2D

# A big helicopter delivers a supply crate at a random point within the
# first ~5 minutes of the raid, landing somewhere random that's never on
# top of (or inside) a house or other POI structure.

const HELICOPTER_SCENE := preload("res://scenes/Helicopter.tscn")
const CRATE_SCENE := preload("res://scenes/Chest.tscn")

@export var map_half_size: Vector2 = Vector2(2150, 1450)
@export var min_delay: float = 30.0
@export var max_delay: float = 260.0

# Generous exclusion boxes around houses/POIs - position is the min
# corner, size is (width, height). Each map instance sets its own to
# match its actual layout (see Main.tscn vs Boneclock.tscn).
@export var exclusion_zone_positions: Array[Vector2] = [
	Vector2(-950, -1000), Vector2(400, 50), Vector2(1700, -1600),
	Vector2(1500, 950), Vector2(-1200, 700), Vector2(-550, 750),
]
@export var exclusion_zone_sizes: Array[Vector2] = [
	Vector2(1000, 750), Vector2(750, 600), Vector2(600, 550),
	Vector2(800, 700), Vector2(800, 800), Vector2(700, 550),
]

var timer: float = 0.0
var fired: bool = false

func _ready() -> void:
	timer = randf_range(min_delay, max_delay)

func _process(delta: float) -> void:
	if fired or GameManager.run_over:
		return
	timer -= delta
	if timer <= 0.0:
		fired = true
		_trigger()

func _pick_landing_spot() -> Vector2:
	for _attempt in range(30):
		var pos := Vector2(randf_range(-map_half_size.x, map_half_size.x), randf_range(-map_half_size.y, map_half_size.y))
		var blocked := false
		for i in range(exclusion_zone_positions.size()):
			var rect := Rect2(exclusion_zone_positions[i], exclusion_zone_sizes[i])
			if rect.has_point(pos):
				blocked = true
				break
		if not blocked:
			return pos
	return Vector2.ZERO

func _trigger() -> void:
	var pos := _pick_landing_spot()
	Notify.show_quest_toast("Supply drop inbound - watch the sky.")
	var heli = HELICOPTER_SCENE.instantiate()
	get_tree().current_scene.add_child(heli)
	heli.start_approach(pos)
	heli.arrived.connect(func():
		_drop_crate(pos)
		await get_tree().create_timer(1.2).timeout
		if is_instance_valid(heli):
			heli.depart()
	)

func _drop_crate(pos: Vector2) -> void:
	var crate = CRATE_SCENE.instantiate()
	# A real reason to detour for one of these: a guaranteed Mythic-tier
	# weapon (was a single fixed Epic rifle) with its type randomized
	# for variety, on top of Chest.gd's usual bonus rolls (attachments,
	# valuables, loot bag chance, etc.) that every container already gets.
	const SUPPLY_DROP_WEAPON_TYPES := [
		{"icon_key": "rifle", "stat_value": 40.0},
		{"icon_key": "sniper", "stat_value": 46.0},
		{"icon_key": "shotgun", "stat_value": 50.0},
		{"icon_key": "railgun", "stat_value": 42.0},
	]
	var picked: Dictionary = SUPPLY_DROP_WEAPON_TYPES[randi() % SUPPLY_DROP_WEAPON_TYPES.size()]
	crate.item_name = "Supply Drop Weapon"
	crate.base_value = 480
	crate.slot = "weapon"
	crate.stat_type = "damage"
	crate.base_stat_value = picked["stat_value"]
	crate.icon_key = picked["icon_key"]
	crate.rarity = "mythic"
	get_tree().current_scene.add_child(crate)
	crate.global_position = pos
	# Distinct look so it doesn't blend in with regular containers - a
	# bright military-orange tint, a parachute still draped over it, and
	# a tall flare visible from across the map, day or night.
	if crate.has_node("Body"):
		crate.get_node("Body").color = Color(0.75, 0.4, 0.1, 1)
	if crate.has_node("Lid"):
		crate.get_node("Lid").color = Color(0.85, 0.5, 0.15, 1)
	_spawn_parachute(pos)
	var beacon = preload("res://scenes/FlareBeacon.tscn").instantiate()
	beacon.flare_color = Color(1.0, 0.55, 0.1, 1)
	get_tree().current_scene.add_child(beacon)
	beacon.global_position = pos + Vector2(40, -10)
	Notify.show_quest_toast("Supply crate has landed!")

func _spawn_parachute(pos: Vector2) -> void:
	var chute := Node2D.new()
	chute.z_index = 8
	get_tree().current_scene.add_child(chute)
	chute.global_position = pos + Vector2(0, -55)
	var canopy := Polygon2D.new()
	canopy.color = Color(0.85, 0.75, 0.2, 0.9)
	canopy.polygon = PackedVector2Array([
		Vector2(-38, 6), Vector2(-26, -18), Vector2(-10, -26), Vector2(10, -26),
		Vector2(26, -18), Vector2(38, 6), Vector2(20, -4), Vector2(0, 2), Vector2(-20, -4),
	])
	chute.add_child(canopy)
	for dx in [-24, -8, 8, 24]:
		var line := Line2D.new()
		line.points = PackedVector2Array([Vector2(dx, 0), Vector2(0, 55)])
		line.width = 1.2
		line.default_color = Color(0.7, 0.65, 0.5, 0.8)
		chute.add_child(line)
