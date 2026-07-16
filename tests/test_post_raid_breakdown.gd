extends TestCase

# Regression coverage for the Post-Raid Breakdown system (2026-07-16) -
# real per-raid kill/damage/net-worth logs (GameManager.raid_kill_log/
# raid_damage_log/raid_value_samples), snapshotted into
# last_raid_breakdown by end_run() before the live arrays reset for the
# next raid. See GameManager.gd's "Post-Raid Breakdown" section.

func test_body_part_roll_always_returns_a_known_part() -> void:
	var valid_parts := []
	for entry in GameManager.BODY_PART_WEIGHTS:
		valid_parts.append(entry["part"])
	for i in range(30):
		var part: String = GameManager._roll_body_part()
		assert_true(part in valid_parts, "rolled an unexpected body part: %s" % part)

func test_record_kill_appends_to_the_log() -> void:
	var log_before: Array = GameManager.raid_kill_log.duplicate(true)
	GameManager.record_kill("Test Raider")
	assert_eq(GameManager.raid_kill_log.size(), log_before.size() + 1)
	var last_entry: Dictionary = GameManager.raid_kill_log[GameManager.raid_kill_log.size() - 1]
	assert_eq(last_entry.get("enemy"), "Test Raider")
	assert_true(last_entry.has("time"))
	assert_true(last_entry.has("weapon"))
	GameManager.raid_kill_log = log_before

func test_record_damage_taken_appends_to_the_log_with_a_body_part() -> void:
	var log_before: Array = GameManager.raid_damage_log.duplicate(true)
	GameManager.record_damage_taken(15, "An Enemy", "Grenade")
	assert_eq(GameManager.raid_damage_log.size(), log_before.size() + 1)
	var last_entry: Dictionary = GameManager.raid_damage_log[GameManager.raid_damage_log.size() - 1]
	assert_eq(last_entry.get("amount"), 15)
	assert_eq(last_entry.get("attacker"), "An Enemy")
	assert_eq(last_entry.get("weapon"), "Grenade")
	assert_true(last_entry.has("body_part"))
	GameManager.raid_damage_log = log_before

func test_record_damage_taken_falls_back_to_unknown_for_blank_attacker_weapon() -> void:
	var log_before: Array = GameManager.raid_damage_log.duplicate(true)
	GameManager.record_damage_taken(5, "", "")
	var last_entry: Dictionary = GameManager.raid_damage_log[GameManager.raid_damage_log.size() - 1]
	assert_eq(last_entry.get("attacker"), "Unknown")
	assert_eq(last_entry.get("weapon"), "Unknown")
	GameManager.raid_damage_log = log_before

func test_recording_a_kill_or_hit_also_samples_net_worth() -> void:
	var samples_before: Array = GameManager.raid_value_samples.duplicate(true)
	GameManager.record_kill("Test Raider")
	assert_eq(GameManager.raid_value_samples.size(), samples_before.size() + 1)
	var sample: Dictionary = GameManager.raid_value_samples[GameManager.raid_value_samples.size() - 1]
	assert_eq(sample.get("value"), GameManager.carried_value)
	GameManager.raid_value_samples = samples_before

func test_player_take_damage_flows_through_to_the_real_log() -> void:
	var PlayerScene := load("res://scenes/Player.tscn")
	var player = PlayerScene.instantiate()
	add_child(player)
	player.health = 100
	player.max_health = 100
	player.alive = true
	var log_before: Array = GameManager.raid_damage_log.duplicate(true)
	player.take_damage(7, "Test Enemy", "Test Weapon")
	assert_eq(GameManager.raid_damage_log.size(), log_before.size() + 1)
	var last_entry: Dictionary = GameManager.raid_damage_log[GameManager.raid_damage_log.size() - 1]
	assert_eq(last_entry.get("attacker"), "Test Enemy")
	GameManager.raid_damage_log = log_before
	remove_child(player)
	player.queue_free()

func test_death_screen_maps_real_body_parts_to_known_mannequin_indices() -> void:
	var DeathScreenScript := load("res://scripts/DeathScreen.gd")
	var mannequin_part_names := []
	for entry in DeathScreenScript.HIT_PARTS:
		mannequin_part_names.append(entry["name"])
	for entry in GameManager.BODY_PART_WEIGHTS:
		assert_true(entry["part"] in mannequin_part_names, "GameManager body part '%s' has no matching DeathScreen mannequin position" % entry["part"])
