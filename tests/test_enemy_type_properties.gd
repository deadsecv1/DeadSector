extends TestCase

# Regression coverage for a real, subtle .tscn authoring bug found this
# session: several enemy scenes declared enemy_type_id/use_external_sprite
# BEFORE their script= line in the node's property block. Godot applies
# .tscn property overrides in file order, and a custom @export var isn't
# recognized as settable until AFTER the script is actually attached -
# so any property listed before script= silently fails to apply and the
# script's own default takes over instead, with no warning printed.
#
# This mattered a lot here: it silently forced enemy_type_id back to ""
# and use_external_sprite back to true for 7 different typed enemies,
# meaning every one of them rendered as the plain generic human sprite
# (assets/enemy.png) instead of either their own already-correct dedicated
# art, or (for NoxiousBat/Wisp) the custom vector redesign meant to hide
# every human-shaped part. Checking the actual runtime property values
# here, not just re-reading the .tscn text, is the point - a future edit
# that moves script= back below these properties should fail this test
# the same way the earlier ordering silently broke the real game.

func _check(scene_path: String, expected_type_id: String, expected_use_external: bool, label: String) -> void:
	var inst = load(scene_path).instantiate()
	assert_eq(inst.enemy_type_id, expected_type_id, "%s: enemy_type_id should be '%s'" % [label, expected_type_id])
	assert_eq(inst.use_external_sprite, expected_use_external, "%s: use_external_sprite should be %s" % [label, expected_use_external])
	inst.queue_free()

func test_typed_enemies_with_dedicated_external_art_keep_their_type_id() -> void:
	_check("res://scenes/Ghost.tscn", "ghost", true, "Ghost")
	_check("res://scenes/Ghoul.tscn", "ghoul", true, "Ghoul")
	_check("res://scenes/Marauder.tscn", "marauder", true, "Marauder")
	_check("res://scenes/RiftWraith.tscn", "rift_wraith", true, "RiftWraith")
	_check("res://scenes/Sentinel.tscn", "sentinel", true, "Sentinel")
	_check("res://scenes/Skeleton.tscn", "skeleton", true, "Skeleton")

func test_typed_enemies_forced_onto_the_vector_path_stay_forced() -> void:
	_check("res://scenes/NoxiousBat.tscn", "bat", false, "NoxiousBat")
	_check("res://scenes/ToxicWaste.tscn", "toxic_waste", false, "ToxicWaste")
	_check("res://scenes/Wisp.tscn", "wisp", false, "Wisp")

func test_noxious_bat_hides_every_human_specific_part() -> void:
	var inst = load("res://scenes/NoxiousBat.tscn").instantiate()
	add_child(inst)
	await get_tree().process_frame
	assert_false(inst.mask.visible, "Bat should not show the human mask")
	assert_false(inst.cap.visible, "Bat should not show the human cap")
	assert_false(inst.chest_strap.visible, "Bat should not show a human chest strap")
	assert_false(inst.left_leg.visible, "Bat should not show human legs")
	assert_false(inst.right_leg.visible, "Bat should not show human legs")
	assert_false(inst.gun_visual.visible, "Bat should not show a hand gripping a pistol")
	remove_child(inst)
	inst.queue_free()

func test_wisp_hides_every_human_specific_part() -> void:
	var inst = load("res://scenes/Wisp.tscn").instantiate()
	add_child(inst)
	await get_tree().process_frame
	assert_false(inst.mask.visible, "Wisp should not show the human mask")
	assert_false(inst.cap.visible, "Wisp should not show the human cap")
	assert_false(inst.chest_strap.visible, "Wisp should not show a human chest strap")
	assert_false(inst.left_leg.visible, "Wisp should not show human legs")
	assert_false(inst.right_leg.visible, "Wisp should not show human legs")
	assert_false(inst.gun_visual.visible, "Wisp should not show a hand gripping a pistol")
	assert_false(inst.torso_outline.visible, "Wisp should not have a hard human silhouette outline")
	assert_false(inst.head_outline.visible, "Wisp should not have a hard human silhouette outline")
	remove_child(inst)
	inst.queue_free()
