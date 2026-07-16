extends TestCase

# Regression coverage for the Broadcast alert (2026-07-16) - the rare
# mid-raid "guarded cache" event (see each map's own
# _maybe_spawn_elite_cache_event()) now pairs its spawn with a distinct
# radio-chatter toast via GameManager.broadcast_alert_requested ->
# Notify.show_broadcast_alert(), so the event is actually discoverable
# instead of a silent random encounter. See Notify.gd/GameManager.gd.

func test_notify_show_broadcast_alert_adds_a_toast() -> void:
	var before: int = Notify.toast_container.get_child_count()
	Notify.show_broadcast_alert("Test broadcast")
	assert_eq(Notify.toast_container.get_child_count(), before + 1)

func test_game_manager_signal_reaches_notify() -> void:
	# Notify._ready() connects GameManager.broadcast_alert_requested to its
	# own show_broadcast_alert() - confirms that wiring, not just the
	# function in isolation, actually works end to end.
	var before: int = Notify.toast_container.get_child_count()
	GameManager.broadcast_alert_requested.emit("Test broadcast via signal")
	assert_eq(Notify.toast_container.get_child_count(), before + 1)
