extends TestCase

# Regression coverage for GameManager.get_backpack_ammo_amount()/
# consume_backpack_ammo() (2026-07-16) - previously untested. Also covers
# a real gap found via user feedback: Safe Pocket ammo didn't count
# toward the usable ammo reserve at all, even though Safe Pocket items
# genuinely travel into the raid with you (see the interrupted-run drain
# logic in load_game()) - it just survives death, unlike carried_loot/
# backpack_storage. Fixed by including safe_pockets in both functions,
# consumed last (after carried_loot/backpack_storage are exhausted).
#
# before_each_file() runs once per FILE, not per test (a real gotcha -
# see CLAUDE.md/test_daily_bounties.gd) - each test resets the 3 pools
# itself at the top rather than relying on file-level setup alone.

func _ammo_item(amount: int, ammo_type: String = "light") -> Dictionary:
	return {"consumable_type": "ammo", "ammo_type": ammo_type, "ammo_amount": amount, "base_name": "Light Ammo", "name": "Light Ammo x%d" % amount, "slot": "ammo"}

func _reset_pools() -> void:
	GameManager.carried_loot = []
	GameManager.carried_value = 0
	GameManager.backpack_storage = []
	GameManager.safe_pockets = [null, null]

func before_each_file() -> void:
	_reset_pools()

func test_get_backpack_ammo_amount_sums_carried_and_backpack() -> void:
	_reset_pools()
	GameManager.carried_loot = [_ammo_item(30)]
	GameManager.backpack_storage = [_ammo_item(50)]
	assert_eq(GameManager.get_backpack_ammo_amount("light"), 80)
	_reset_pools()

func test_get_backpack_ammo_amount_includes_safe_pocket_ammo() -> void:
	_reset_pools()
	GameManager.carried_loot = [_ammo_item(10)]
	GameManager.safe_pockets = [_ammo_item(60), null]
	assert_eq(GameManager.get_backpack_ammo_amount("light"), 70, "Safe Pocket ammo should count toward the usable reserve")
	_reset_pools()

func test_get_backpack_ammo_amount_ignores_other_ammo_types() -> void:
	_reset_pools()
	GameManager.safe_pockets = [_ammo_item(60, "heavy"), null]
	assert_eq(GameManager.get_backpack_ammo_amount("light"), 0)
	_reset_pools()

func test_consume_backpack_ammo_drains_carried_loot_before_backpack_storage() -> void:
	_reset_pools()
	GameManager.carried_loot = [_ammo_item(10)]
	GameManager.backpack_storage = [_ammo_item(50)]
	var taken: int = GameManager.consume_backpack_ammo("light", 10)
	assert_eq(taken, 10)
	assert_eq(GameManager.carried_loot.size(), 0, "the fully-drained carried_loot stack should be removed")
	assert_eq(GameManager.backpack_storage[0]["ammo_amount"], 50, "backpack_storage should be untouched while carried_loot still had enough")
	_reset_pools()

func test_consume_backpack_ammo_only_touches_safe_pockets_as_a_last_resort() -> void:
	_reset_pools()
	GameManager.carried_loot = [_ammo_item(5)]
	GameManager.backpack_storage = [_ammo_item(5)]
	GameManager.safe_pockets = [_ammo_item(100), null]
	var taken: int = GameManager.consume_backpack_ammo("light", 8)
	assert_eq(taken, 8)
	assert_eq(GameManager.safe_pockets[0]["ammo_amount"], 100, "Safe Pockets should be untouched while carried_loot+backpack_storage together already covered the request")
	_reset_pools()

func test_consume_backpack_ammo_falls_through_to_safe_pockets_when_everything_else_is_exhausted() -> void:
	_reset_pools()
	GameManager.carried_loot = [_ammo_item(5)]
	GameManager.safe_pockets = [_ammo_item(100), null]
	var taken: int = GameManager.consume_backpack_ammo("light", 20)
	assert_eq(taken, 20)
	assert_eq(GameManager.carried_loot.size(), 0)
	assert_eq(GameManager.safe_pockets[0]["ammo_amount"], 85, "the remaining 15 rounds should have come out of the Safe Pocket stack")
	_reset_pools()

func test_consume_backpack_ammo_clears_a_fully_drained_safe_pocket_slot() -> void:
	_reset_pools()
	GameManager.safe_pockets = [_ammo_item(10), null]
	var taken: int = GameManager.consume_backpack_ammo("light", 10)
	assert_eq(taken, 10)
	assert_null(GameManager.safe_pockets[0], "a fully-drained Safe Pocket slot should be cleared back to null, not left as a 0-ammo stack")
	_reset_pools()

func test_consume_backpack_ammo_returns_less_than_requested_when_reserves_run_out() -> void:
	_reset_pools()
	GameManager.safe_pockets = [_ammo_item(4), null]
	var taken: int = GameManager.consume_backpack_ammo("light", 10)
	assert_eq(taken, 4, "should return only what was actually available across every pool, including Safe Pockets")
	_reset_pools()

func test_consume_backpack_ammo_never_touches_a_different_ammo_type_in_safe_pockets() -> void:
	_reset_pools()
	GameManager.safe_pockets = [_ammo_item(50, "heavy"), null]
	var taken: int = GameManager.consume_backpack_ammo("light", 10)
	assert_eq(taken, 0)
	assert_eq(GameManager.safe_pockets[0]["ammo_amount"], 50)
	_reset_pools()
