extends TestCase

# Regression coverage (2026-07-17 audit) - 8 draggable Hideout/Stash popups
# (SkinsPanel, RosePanel, WhisperPanel, HarmonPanel, JustinPanel,
# LilDirtyPanel, BitcoinFarmPanel, GymPanel) never forced their designed
# centered rect back in open()/open_for(), unlike every comparable
# draggable popup elsewhere in the game (DailyBountiesPanel, SeasonPass,
# Lore, PostRaidBreakdown, etc.) - DraggableEdge.gd's drag directly mutates
# .position (and, with anchors set, that means offset_left/top too), and
# since these nodes stay alive (just hidden) between opens, a drag from a
# previous visit persisted indefinitely and could leave the panel
# off-screen the next time it was opened. Fixed by forcing anchor_*/
# offset_* back to the .tscn-authored values at the top of open().

const HideoutScene := preload("res://scenes/Hideout.tscn")
const StashScene := preload("res://scenes/Stash.tscn")

func _simulate_a_stale_drag(panel: Control) -> void:
	panel.offset_left = 900.0
	panel.offset_top = 900.0
	panel.offset_right = 1200.0
	panel.offset_bottom = 1200.0

func test_rose_panel_resets_position_on_open() -> void:
	var hideout = HideoutScene.instantiate()
	add_child(hideout)
	var panel = hideout.rose_panel
	_simulate_a_stale_drag(panel)
	panel.open()
	assert_eq(panel.offset_left, -230.0)
	assert_eq(panel.offset_top, -260.0)
	assert_eq(panel.offset_right, 230.0)
	assert_eq(panel.offset_bottom, 260.0)
	remove_child(hideout)
	hideout.queue_free()

func test_whisper_panel_resets_position_on_open() -> void:
	var hideout = HideoutScene.instantiate()
	add_child(hideout)
	var panel = hideout.whisper_panel
	_simulate_a_stale_drag(panel)
	panel.open()
	assert_eq(panel.offset_left, -260.0)
	assert_eq(panel.offset_top, -200.0)
	remove_child(hideout)
	hideout.queue_free()

func test_harmon_panel_resets_position_on_open() -> void:
	var hideout = HideoutScene.instantiate()
	add_child(hideout)
	var panel = hideout.harmon_panel
	_simulate_a_stale_drag(panel)
	panel.open()
	assert_eq(panel.offset_left, -260.0)
	assert_eq(panel.offset_top, -190.0)
	remove_child(hideout)
	hideout.queue_free()

func test_justin_panel_resets_position_on_open() -> void:
	var hideout = HideoutScene.instantiate()
	add_child(hideout)
	var panel = hideout.justin_panel
	_simulate_a_stale_drag(panel)
	panel.open()
	assert_eq(panel.offset_left, -270.0)
	assert_eq(panel.offset_top, -260.0)
	remove_child(hideout)
	hideout.queue_free()

func test_lildirty_panel_resets_position_on_open() -> void:
	var hideout = HideoutScene.instantiate()
	add_child(hideout)
	var panel = hideout.lildirty_panel
	_simulate_a_stale_drag(panel)
	panel.open()
	assert_eq(panel.offset_left, -260.0)
	assert_eq(panel.offset_top, -220.0)
	remove_child(hideout)
	hideout.queue_free()

func test_bitcoin_farm_panel_resets_position_on_open() -> void:
	var hideout = HideoutScene.instantiate()
	add_child(hideout)
	var panel = hideout.bitcoin_farm_panel
	_simulate_a_stale_drag(panel)
	panel.open()
	assert_eq(panel.offset_left, -260.0)
	assert_eq(panel.offset_top, -240.0)
	remove_child(hideout)
	hideout.queue_free()

func test_gym_panel_resets_position_on_open() -> void:
	var hideout = HideoutScene.instantiate()
	add_child(hideout)
	var panel = hideout.gym_panel
	_simulate_a_stale_drag(panel)
	panel.open()
	assert_eq(panel.offset_left, -230.0)
	assert_eq(panel.offset_top, -220.0)
	remove_child(hideout)
	hideout.queue_free()

func test_skins_panel_resets_position_on_open() -> void:
	var stash = StashScene.instantiate()
	add_child(stash)
	var panel = stash.skins_panel
	_simulate_a_stale_drag(panel)
	panel.open_for({"icon_key": "rifle", "name": "Test Weapon"})
	assert_eq(panel.offset_left, -220.0)
	assert_eq(panel.offset_top, -220.0)
	remove_child(stash)
	stash.queue_free()
