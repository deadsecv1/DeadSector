extends TestCase

# Regression coverage (2026-07-17 audit) - _on_join_pressed() only checked
# player_joined on the ONE group being joined, so nothing stopped clicking
# Join on a second, different group before the first one's countdown
# finished - registering the player on two rosters at once (and, if both
# later independently completed, calling Transition.change_scene() twice).
# Same bug ArenaFindTeamPanel.gd already had fixed via
# _player_has_joined_a_team; FindTeamPanel.gd never got the equivalent.

const FindTeamPanelScene := preload("res://scenes/FindTeamPanel.tscn")

func _make_joinable_group(panel, id: int) -> Dictionary:
	var g := {
		"id": id, "leader": {"name": "Leader %d" % id, "portrait": "portrait_1"},
		"map_id": GameManager.MAP_CATALOG.keys()[0],
		"max": 4, "members": [{"name": "Leader %d" % id, "portrait": "portrait_1"}],
		"joining_countdown": 0, "player_joined": false,
	}
	panel._groups.append(g)
	panel._add_row(g)
	return g

func test_joining_a_second_group_is_rejected_once_already_in_one() -> void:
	var panel = FindTeamPanelScene.instantiate()
	add_child(panel)
	panel.open()
	panel._clear_all()

	var group_a := _make_joinable_group(panel, 101)
	var group_b := _make_joinable_group(panel, 102)

	panel._on_join_pressed(101)
	assert_true(group_a.get("player_joined", false), "joining the first group should succeed")
	assert_eq(group_a["members"].size(), 2, "the player should actually be added to group A's roster")

	panel._on_join_pressed(102)
	assert_false(group_b.get("player_joined", false), "joining a second group while already in one must be rejected")
	assert_eq(group_b["members"].size(), 1, "the player must not be added to group B's roster")

	remove_child(panel)
	panel.queue_free()

func test_reopening_the_panel_resets_the_joined_flag() -> void:
	var panel = FindTeamPanelScene.instantiate()
	add_child(panel)
	panel.open()
	panel._clear_all()
	var group_a := _make_joinable_group(panel, 201)
	panel._on_join_pressed(201)
	assert_true(panel._player_has_joined_a_group)

	panel.open()
	assert_false(panel._player_has_joined_a_group, "a fresh open() should let the player join a new group again")

	remove_child(panel)
	panel.queue_free()
