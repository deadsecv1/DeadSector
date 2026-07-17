extends TestCase

# Regression coverage (2026-07-17) - the net-worth graph used to only ever
# sample on combat events (record_kill/record_damage_taken), plus the one
# t=0 point end_run() seeds. A raid spent entirely looting quietly with no
# combat produced a flat/near-empty graph even though carried_value genuinely
# moved. GameManager._tick_networth_sampler() (called from _process()) now
# also ticks a periodic sample independent of combat, gated on a real
# "player" group node actually being present so it doesn't spam samples
# while sitting in the Hideout/menus between raids. Tests call
# _tick_networth_sampler() directly rather than the full _process() so they
# don't also trip _process()'s unrelated sibling timers (autosave writing
# the real save file, trader rotation, flea market checks).

func test_tick_samples_net_worth_after_the_interval_with_no_combat() -> void:
	var PlayerScene := load("res://scenes/Player.tscn")
	var player = PlayerScene.instantiate()
	add_child(player)
	await get_tree().process_frame

	var samples_before: Array = GameManager.raid_value_samples.duplicate(true)
	var timer_before: float = GameManager._networth_sample_timer
	var run_over_before: bool = GameManager.run_over
	GameManager.run_over = false
	GameManager._networth_sample_timer = 0.0

	GameManager._tick_networth_sampler(GameManager.NETWORTH_SAMPLE_INTERVAL + 0.1)

	assert_eq(GameManager.raid_value_samples.size(), samples_before.size() + 1, "a long enough tick with no combat should still append a sample")
	assert_eq(GameManager._networth_sample_timer, 0.0, "the timer should reset back to 0 after firing")

	GameManager.raid_value_samples = samples_before
	GameManager._networth_sample_timer = timer_before
	GameManager.run_over = run_over_before
	remove_child(player)
	player.queue_free()

func test_tick_does_not_sample_before_the_interval_elapses() -> void:
	var samples_before: Array = GameManager.raid_value_samples.duplicate(true)
	var timer_before: float = GameManager._networth_sample_timer
	GameManager._networth_sample_timer = 0.0

	GameManager._tick_networth_sampler(GameManager.NETWORTH_SAMPLE_INTERVAL - 5.0)

	assert_eq(GameManager.raid_value_samples.size(), samples_before.size(), "should not sample until the full interval has elapsed")
	assert_gt(GameManager._networth_sample_timer, 0.0, "the timer should still be accumulating")

	GameManager.raid_value_samples = samples_before
	GameManager._networth_sample_timer = timer_before

func test_tick_does_not_sample_when_no_player_is_present() -> void:
	# TestRunner's own scene tree has no "player" group node by default -
	# confirms the gate actually gates, not just that the timer fires blindly.
	assert_null(get_tree().get_first_node_in_group("player"), "test setup assumption: no stray player node in the tree")
	var samples_before: Array = GameManager.raid_value_samples.duplicate(true)
	var timer_before: float = GameManager._networth_sample_timer
	GameManager._networth_sample_timer = 0.0

	GameManager._tick_networth_sampler(GameManager.NETWORTH_SAMPLE_INTERVAL + 0.1)

	assert_eq(GameManager.raid_value_samples.size(), samples_before.size(), "no player in the tree means no raid in progress - should not sample")

	GameManager.raid_value_samples = samples_before
	GameManager._networth_sample_timer = timer_before

func test_begin_raid_session_resets_the_periodic_sample_timer() -> void:
	var timer_before: float = GameManager._networth_sample_timer
	var quests_before: Array = GameManager.raid_quests_completed.duplicate()
	GameManager._networth_sample_timer = 9.5

	GameManager.begin_raid_session()

	assert_eq(GameManager._networth_sample_timer, 0.0)

	GameManager._networth_sample_timer = timer_before
	GameManager.raid_quests_completed = quests_before
