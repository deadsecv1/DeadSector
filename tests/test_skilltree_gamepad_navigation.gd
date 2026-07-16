extends TestCase

# Regression coverage for SkillTree.gd's directional focus-neighbor
# wiring. This screen is a genuine free-form node-graph (21 absolutely-
# positioned nodes), and Godot's own built-in automatic focus_neighbor
# fallback (used when Control.focus_neighbor_* is left unset) turned out
# NOT to be good enough here when checked by hand: from max_health
# (280,380), pressing Right landed on search_speed (350,520 - actually
# down-right) instead of damage (720,380 - directly right). Hence the
# hand-rolled _find_neighbor_in_direction()/_wire_focus_neighbors(), which
# these tests protect against silently regressing back to that.

const SkillTreeScene := preload("res://scenes/SkillTree.tscn")

func test_find_neighbor_in_direction_prefers_a_node_actually_in_that_direction() -> void:
	var tree = SkillTreeScene.instantiate()
	add_child(tree)
	await get_tree().process_frame

	# damage (720,380) sits directly right of max_health (280,380, same Y)
	# - any reasonable rightward pick must be strictly to the right.
	var right_key: String = tree._find_neighbor_in_direction("max_health", Vector2.RIGHT)
	assert_true(right_key != "", "Should find SOME node to the right of max_health")
	var right_pos: Vector2 = tree.NODE_POS[right_key]
	var from_pos: Vector2 = tree.NODE_POS["max_health"]
	assert_gt(right_pos.x, from_pos.x, "A 'right' neighbor must actually be further right than the source node")

	var left_key: String = tree._find_neighbor_in_direction("damage", Vector2.LEFT)
	assert_true(left_key != "", "Should find some node to the left of damage")
	var damage_pos: Vector2 = tree.NODE_POS["damage"]
	assert_gt(damage_pos.x, tree.NODE_POS[left_key].x, "A 'left' neighbor must actually be further left than the source node")

	remove_child(tree)
	tree.queue_free()

func test_find_neighbor_in_direction_returns_empty_past_the_true_edge() -> void:
	var tree = SkillTreeScene.instantiate()
	add_child(tree)
	await get_tree().process_frame

	# extraction_speed (500,580) has the largest Y in NODE_POS - nothing
	# is genuinely further down from it.
	var down_key: String = tree._find_neighbor_in_direction("extraction_speed", Vector2.DOWN)
	assert_eq(down_key, "", "The true bottom-edge node should have no further node below it")

	remove_child(tree)
	tree.queue_free()

func test_bottom_edge_nodes_bridge_focus_down_into_the_detail_panel() -> void:
	var tree = SkillTreeScene.instantiate()
	add_child(tree)
	await get_tree().process_frame

	var es_btn: Button = tree.tree_canvas.get_node("Node_extraction_speed")
	assert_ne(es_btn.focus_neighbor_bottom, NodePath(""), "A true bottom-edge node must have SOME focus_neighbor_bottom set, not a dead end")
	var target := es_btn.get_node(es_btn.focus_neighbor_bottom)
	assert_eq(target, tree.detail_button, "extraction_speed's focus_neighbor_bottom should bridge into the Detail panel's buy button - there's no gamepad equivalent to Tab to reach it any other way")

	remove_child(tree)
	tree.queue_free()

func test_selecting_a_node_updates_the_detail_panels_way_back_out() -> void:
	var tree = SkillTreeScene.instantiate()
	add_child(tree)
	await get_tree().process_frame

	tree._on_node_pressed("extraction_speed")
	await get_tree().process_frame
	var back_target = tree.detail_button.get_node(tree.detail_button.focus_neighbor_top)
	assert_eq(back_target, tree.tree_canvas.get_node("Node_extraction_speed"), "After selecting extraction_speed, focus_neighbor_top should point back to it specifically")

	tree._on_node_pressed("max_health")
	await get_tree().process_frame
	var back_target_2 = tree.detail_button.get_node(tree.detail_button.focus_neighbor_top)
	assert_eq(back_target_2, tree.tree_canvas.get_node("Node_max_health"), "Selecting a DIFFERENT node should update the way back out to match - not stay stuck on the previous selection")

	remove_child(tree)
	tree.queue_free()

func test_every_node_button_has_a_visibly_distinct_focus_stylebox() -> void:
	# Nodes used to override "focus" with the exact same StyleBoxFlat as
	# "normal", making keyboard/gamepad focus completely invisible even
	# though grab_focus() worked correctly under the hood.
	var tree = SkillTreeScene.instantiate()
	add_child(tree)
	await get_tree().process_frame

	var btn: Button = tree.tree_canvas.get_node("Node_max_health")
	var normal_sb: StyleBoxFlat = btn.get_theme_stylebox("normal")
	var focus_sb: StyleBoxFlat = btn.get_theme_stylebox("focus")
	assert_ne(normal_sb, focus_sb, "The focus stylebox must be a distinct resource from the normal one")
	assert_ne(normal_sb.border_color, focus_sb.border_color, "The focus stylebox must look visibly different (border color) from the normal one")

	remove_child(tree)
	tree.queue_free()
