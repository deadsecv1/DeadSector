extends TestCase

# Regression coverage (2026-07-17 audit) - _maybe_spawn_elite_cache_event()
# picked a center up to 1500 units from the player with no clamp against
# Graveyard.tscn's own boundary walls (WallTop/WallBottom at y=+/-2150,
# WallLeft/WallRight at x=+/-3200, each 40 units thick). Player spawns at
# (0, -650), so a large roll aimed roughly north had a real chance of
# landing the cache and its 2 elite guards embedded in WallTop's collision,
# in space the player can never reach. VoidTrench.gd/IronscrapYard.gd
# already had this exact clamp; Graveyard never got it. Fixed by clamping
# the roll into the same safe interior box those maps use.

const GraveyardScene := preload("res://scenes/Graveyard.tscn")

func test_elite_cache_never_spawns_outside_the_walls() -> void:
	var graveyard = GraveyardScene.instantiate()
	add_child(graveyard)
	# Give _ready() a beat to finish spawning its own scene content before
	# probing player.global_position.
	await get_tree().process_frame

	var found_a_spawn := false
	for i in range(60):
		var before: Array = get_tree().get_nodes_in_group("enemy").filter(func(e): return e.get("is_elite_guard") == true)
		graveyard._maybe_spawn_elite_cache_event()
		var after: Array = get_tree().get_nodes_in_group("enemy").filter(func(e): return e.get("is_elite_guard") == true)
		if after.size() > before.size():
			found_a_spawn = true
			for guard in after:
				if before.has(guard):
					continue
				assert_true(guard.global_position.x > -3180.0 and guard.global_position.x < 3180.0, "elite guard x=%s must stay inside WallLeft/WallRight" % guard.global_position.x)
				assert_true(guard.global_position.y > -2130.0 and guard.global_position.y < 2130.0, "elite guard y=%s must stay inside WallTop/WallBottom" % guard.global_position.y)
			break

	assert_true(found_a_spawn, "test setup: the elite cache event should have triggered at least once across 60 rolls (18% chance each)")

	# Enemy.gd's _find_player() is scheduled via call_deferred() from its
	# own _ready() - let it resolve before freeing the tree, or it errors
	# trying to get_tree() on an already-removed node (see CLAUDE.md's
	# note on this exact Enemy.gd pattern).
	await get_tree().process_frame
	remove_child(graveyard)
	graveyard.queue_free()
