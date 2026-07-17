extends TestCase

# Regression coverage (2026-07-17 audit) for several popups that never
# called GameManager.focus_first_control() on themselves after opening -
# a gamepad player landing on any of them had no initial focus to
# navigate stick/d-pad from, breaking the established convention every
# comparable popup already follows.

const MainMenuScene := preload("res://scenes/MainMenu.tscn")
const RankPreviewScene := preload("res://scenes/RankPreview.tscn")

func test_leaderboard_profile_popup_focuses_itself() -> void:
	var main_menu = MainMenuScene.instantiate()
	add_child(main_menu)
	var panel = main_menu.leaderboard_panel
	panel._open_profile_popup({"name": "Test Operative", "level": 10})
	assert_not_null(panel.profile_popup, "the profile popup should have been built")
	assert_true(panel.profile_popup.get_viewport().gui_get_focus_owner() != null, "opening the profile popup should focus something inside it")
	remove_child(main_menu)
	main_menu.queue_free()

func test_rank_preview_focuses_itself_on_ready() -> void:
	var rank_preview = RankPreviewScene.instantiate()
	add_child(rank_preview)
	assert_true(rank_preview.get_viewport().gui_get_focus_owner() != null, "RankPreview should focus something on _ready()")
	remove_child(rank_preview)
	rank_preview.queue_free()

func test_data_panel_context_menu_and_inspect_popup_focus_themselves() -> void:
	var main_menu = MainMenuScene.instantiate()
	add_child(main_menu)
	var panel = main_menu.data_panel
	panel._open_context_menu({"title": "Test Entry", "lines": []}, Vector2(100, 100))
	assert_true(panel.context_menu.get_viewport().gui_get_focus_owner() != null, "opening the context menu should focus something inside it")

	panel._open_inspect_popup({"title": "Test Entry", "lines": []})
	assert_true(panel.inspect_popup.get_viewport().gui_get_focus_owner() != null, "opening the inspect popup should focus something inside it")

	remove_child(main_menu)
	main_menu.queue_free()

# Regression coverage for DataPanel.refresh() leaving a stale context menu
# floating over a newly-switched tab's rows.
func test_data_panel_refresh_hides_a_stale_context_menu() -> void:
	var main_menu = MainMenuScene.instantiate()
	add_child(main_menu)
	var panel = main_menu.data_panel
	panel._open_context_menu({"title": "Test Entry", "lines": []}, Vector2(100, 100))
	assert_true(panel.context_menu.visible, "test setup: context menu should be open")
	panel.refresh()
	assert_false(panel.context_menu.visible, "refresh() (e.g. switching tabs) should hide a still-open context menu")
	remove_child(main_menu)
	main_menu.queue_free()
