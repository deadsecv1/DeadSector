extends TestCase

# Regression coverage for controller-glyph prompts (2026-07-16) -
# GameManager.format_prompt() swaps "Press F"/"Press R"/"[F]"-style
# keyboard hints for a bracketed real button label (e.g. "[A]") whenever
# GameManager.using_gamepad is true. See GameManager.gd's "Gamepad glyph
# prompts" section.

func test_format_prompt_unchanged_when_not_using_gamepad() -> void:
	var was_gamepad: bool = GameManager.using_gamepad
	GameManager.using_gamepad = false
	assert_eq(GameManager.format_prompt("Press F: Talk to Torque"), "Press F: Talk to Torque")
	assert_eq(GameManager.format_prompt("Press R to Reload"), "Press R to Reload")
	assert_eq(GameManager.format_prompt("[F] Disturb the Bowl"), "[F] Disturb the Bowl")
	GameManager.using_gamepad = was_gamepad

func test_format_prompt_swaps_press_f_for_the_real_interact_binding() -> void:
	var was_gamepad: bool = GameManager.using_gamepad
	GameManager.using_gamepad = true
	var expected_label := GameManager.get_gamepad_button_label(GameManager.get_joypad_binding("interact"))
	assert_eq(GameManager.format_prompt("Press F: Talk to Torque"), "[%s]: Talk to Torque" % expected_label)
	GameManager.using_gamepad = was_gamepad

func test_format_prompt_swaps_press_r_for_the_real_reload_binding() -> void:
	var was_gamepad: bool = GameManager.using_gamepad
	GameManager.using_gamepad = true
	var expected_label := GameManager.get_gamepad_button_label(GameManager.get_joypad_binding("reload"))
	assert_eq(GameManager.format_prompt("Press R to Reload"), "[%s] to Reload" % expected_label)
	GameManager.using_gamepad = was_gamepad

func test_format_prompt_swaps_bracket_f_style_prompts_too() -> void:
	var was_gamepad: bool = GameManager.using_gamepad
	GameManager.using_gamepad = true
	var expected_label := GameManager.get_gamepad_button_label(GameManager.get_joypad_binding("interact"))
	assert_eq(GameManager.format_prompt("[F] Disturb the Bowl"), "[%s] Disturb the Bowl" % expected_label)
	GameManager.using_gamepad = was_gamepad

func test_format_prompt_leaves_non_matching_text_alone_even_with_gamepad_active() -> void:
	var was_gamepad: bool = GameManager.using_gamepad
	GameManager.using_gamepad = true
	assert_eq(GameManager.format_prompt("Searched"), "Searched")
	assert_eq(GameManager.format_prompt("Locked - find the matching key"), "Locked - find the matching key")
	GameManager.using_gamepad = was_gamepad

func test_gamepad_button_label_known_and_unknown() -> void:
	assert_eq(GameManager.get_gamepad_button_label(JOY_BUTTON_A), "A")
	assert_eq(GameManager.get_gamepad_button_label(JOY_BUTTON_X), "X")
	assert_eq(GameManager.get_gamepad_button_label(999), "Button 999")

func test_gamepad_button_color_face_buttons_vs_default() -> void:
	assert_ne(GameManager.get_gamepad_button_color(JOY_BUTTON_A), GameManager.JOY_BUTTON_GLYPH_DEFAULT_COLOR)
	assert_eq(GameManager.get_gamepad_button_color(JOY_BUTTON_LEFT_SHOULDER), GameManager.JOY_BUTTON_GLYPH_DEFAULT_COLOR)

func test_settings_button_name_reads_the_same_canonical_table() -> void:
	# Settings.gd used to keep its own duplicate JOY_BUTTON_NAMES dict -
	# confirms it now reads the same source as the in-world glyph prompts
	# so the two can never drift out of sync.
	var SettingsScript := load("res://scripts/Settings.gd")
	var settings = SettingsScript.new()
	assert_eq(settings._joy_button_name(JOY_BUTTON_A), GameManager.get_gamepad_button_label(JOY_BUTTON_A))
	assert_eq(settings._joy_button_name(JOY_BUTTON_START), GameManager.get_gamepad_button_label(JOY_BUTTON_START))
	settings.free()
