extends TestCase

# Regression coverage for the diegetic ammo peek (2026-07-16) - the
# permanent AmmoLabel counter was replaced with a "pops in on every ammo
# change, fades out ~2s after the last one" peek. See HUD.gd's
# update_ammo() / _process().

const HUDScene := preload("res://scenes/HUD.tscn")

func test_ammo_label_starts_hidden() -> void:
	var hud = HUDScene.instantiate()
	add_child(hud)
	assert_eq(hud.ammo_label.modulate.a, 0.0, "the ammo readout should not be visible before any shot/reload has happened")
	remove_child(hud)
	hud.queue_free()

func test_ammo_change_pops_the_label_fully_visible() -> void:
	var hud = HUDScene.instantiate()
	add_child(hud)
	hud.update_ammo(8, 30, 60, "medium")
	assert_eq(hud.ammo_label.modulate.a, 1.0, "an ammo change should immediately show the peek at full opacity")
	assert_eq(hud.ammo_label.text, "8 / 60 Medium")
	assert_eq(hud._ammo_peek_seconds_left, hud.AMMO_PEEK_DURATION)
	remove_child(hud)
	hud.queue_free()

func test_peek_timer_counts_down_and_reaches_zero() -> void:
	var hud = HUDScene.instantiate()
	add_child(hud)
	hud.update_ammo(8, 30, 60, "medium")
	hud._process(hud.AMMO_PEEK_DURATION + 1.0)
	assert_true(hud._ammo_peek_seconds_left <= 0.0, "the peek timer should have expired after simulating more time than its duration")
	remove_child(hud)
	hud.queue_free()

func test_repeated_shots_keep_resetting_the_timer() -> void:
	# Sustained fire should keep the peek visible rather than letting it
	# fade mid-fight - each new ammo_changed event resets the countdown.
	var hud = HUDScene.instantiate()
	add_child(hud)
	hud.update_ammo(8, 30, 60, "medium")
	hud._process(hud.AMMO_PEEK_DURATION - 0.5)
	assert_gt(hud._ammo_peek_seconds_left, 0.0, "should still be counting down, not yet expired")
	hud.update_ammo(7, 30, 60, "medium")
	assert_eq(hud._ammo_peek_seconds_left, hud.AMMO_PEEK_DURATION, "a fresh shot should reset the countdown back to full duration")
	remove_child(hud)
	hud.queue_free()
