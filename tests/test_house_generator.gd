extends TestCase

# Regression coverage for House.gd (v3.66.0) - this generates a full
# lootable house (walls/doors/vault/chest/roof) from ~10 exported params
# at runtime, used by the 4 new Sector houses. A geometry mistake here
# silently produces a broken/unreachable house rather than an error, so
# this checks the actual built structure, not just that it runs.

const HouseScene := preload("res://scenes/House.tscn")

func _build_house(house_size: Vector2, vault_width: float, key_id: String) -> Node:
	var house = HouseScene.instantiate()
	house.house_size = house_size
	house.vault_width = vault_width
	house.key_id = key_id
	house.key_label = "Test Key"
	add_child(house)
	return house

func test_house_builds_expected_structure() -> void:
	var house = _build_house(Vector2(380, 280), 140.0, "test_key")

	var walls: Array = []
	var doors: Array = []
	var chests := 0
	for child in house.get_children():
		if child.get("wall_color") != null and child.has_method("_try_load_external_texture"):
			walls.append(child)
		elif child.has_method("_try_open"):
			doors.append(child)
		elif child.name.begins_with("Chest") or child.get("chest_size") != null:
			chests += 1

	assert_eq(walls.size(), 9, "House should build exactly 9 wall segments (main top/bottom x2/left, inner x2, vault top/bottom/right)")
	assert_eq(doors.size(), 2, "House should build exactly 2 doors (front + locked vault)")
	assert_eq(chests, 1, "House should build exactly 1 vault chest")

	var locked_doors := doors.filter(func(d): return d.locked)
	var unlocked_doors := doors.filter(func(d): return not d.locked)
	assert_eq(locked_doors.size(), 1, "Exactly one door should be locked")
	assert_eq(unlocked_doors.size(), 1, "Exactly one door should be the unlocked front door")
	assert_eq(locked_doors[0].key_id, "test_key", "Locked door's key_id should match the House's key_id")

	assert_not_null(house.get_node_or_null("Roof"), "House should have a child named 'Roof' (RoofFade.gd looks for this exact sibling name)")
	var izone = house.get_node_or_null("InteriorZone")
	assert_not_null(izone, "House should have a child named 'InteriorZone'")
	if izone != null:
		assert_eq(izone.get_parent(), house, "InteriorZone's parent must be the House itself so RoofFade.gd's get_parent().get_node_or_null(\"Roof\") resolves")

	remove_child(house)
	house.queue_free()

func test_house_front_door_gap_does_not_overlap_walls() -> void:
	# The bottom wall is split in two (left of the door, right of the
	# door) - the gap between them must be exactly door_width, not
	# overlapping (player stuck) or gapped wider/narrower than the door
	# object that fills it.
	var house = _build_house(Vector2(400, 300), 150.0, "k")
	# The vault room has its own bottom wall at the same y as the main
	# room's (both sit at +half.y) - restrict to x < inner_x so only the
	# 2 main-room segments flanking the door match, not the vault's.
	var inner_x: float = house.house_size.x / 2.0 - house.vault_width
	var bottom_walls: Array = []
	for child in house.get_children():
		if child.get("wall_color") != null and child.has_method("_try_load_external_texture") and absf(child.position.y - 150.0) < 0.01 and child.position.x < inner_x:
			bottom_walls.append(child)
	assert_eq(bottom_walls.size(), 2, "Expected exactly 2 bottom-wall segments flanking the front door")
	if bottom_walls.size() == 2:
		bottom_walls.sort_custom(func(a, b): return a.position.x < b.position.x)
		var left_edge: float = bottom_walls[0].position.x + bottom_walls[0].size.x / 2.0
		var right_edge: float = bottom_walls[1].position.x - bottom_walls[1].size.x / 2.0
		var gap: float = right_edge - left_edge
		assert_true(gap > 0.0, "Front door gap must be positive (walls should not overlap)")
		assert_true(absf(gap - house.door_width) < 1.0, "Front door gap (%.1f) should match door_width (%.1f)" % [gap, house.door_width])
	remove_child(house)
	house.queue_free()

func test_house_handles_the_4_real_map_configs_without_negative_geometry() -> void:
	# Exact params used by the 4 real houses added this session - if any
	# of these ever produces a non-positive main_width/vault split, walls
	# would overlap or invert instead of erroring.
	var configs := [
		{"size": Vector2(380, 280), "vault": 140.0}, # Trench Bunker
		{"size": Vector2(360, 260), "vault": 130.0}, # Foreman's Shack
		{"size": Vector2(200, 320), "vault": 90.0},  # Foundry Office
		{"size": Vector2(320, 240), "vault": 120.0}, # Caretaker's Cottage
	]
	for config in configs:
		var house = _build_house(config["size"], config["vault"], "k")
		var main_width: float = config["size"].x - config["vault"]
		assert_gt(main_width, 0.0, "main_width must stay positive for size=%s vault=%s" % [config["size"], config["vault"]])
		for child in house.get_children():
			if child.get("wall_color") != null and child.has_method("_try_load_external_texture"):
				assert_gt(child.size.x, 0.0, "wall width must be positive")
				assert_gt(child.size.y, 0.0, "wall height must be positive")
		remove_child(house)
		house.queue_free()
