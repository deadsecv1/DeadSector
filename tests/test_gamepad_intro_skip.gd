extends TestCase

# Regression coverage (2026-07-17 audit) - 6 boot-sequence screens
# (IntroCutscene, StudioSplash, LegalSplash, ClarityPartnerSplash,
# SteelcrestPartnerSplash, EngineSplash) gated their "press anything to
# continue" input on InputEventKey/InputEventMouseButton only, never
# InputEventJoypadButton - a gamepad-only player's button press never
# advanced past any of them. Worse, IntroCutscene.gd's own
# "PRESS ANY BUTTON TO PLAY" wait had no timeout/auto-advance fallback at
# all (unlike the other 5, which do eventually auto-advance even with zero
# input), so a controller-only player could get soft-locked there
# permanently, never reaching the Main Menu. This test exercises the
# real _input() gating directly with a synthetic gamepad event rather
# than waiting through the full real-time cutscene sequence to reach the
# waiting state naturally.

const IntroCutsceneScene := preload("res://scenes/IntroCutscene.tscn")
const StudioSplashScene := preload("res://scenes/StudioSplash.tscn")

func _make_joypad_press() -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = JOY_BUTTON_A
	e.pressed = true
	return e

func test_intro_cutscene_accepts_a_gamepad_button_press() -> void:
	var scene = IntroCutsceneScene.instantiate()
	add_child(scene)
	scene.waiting_for_start = true
	scene.start_requested = false

	scene._input(_make_joypad_press())

	assert_true(scene.start_requested, "a gamepad button press should satisfy the press-start wait, same as keyboard/mouse")

	remove_child(scene)
	scene.queue_free()

func test_studio_splash_accepts_a_gamepad_button_press() -> void:
	var scene = StudioSplashScene.instantiate()
	add_child(scene)
	scene._waiting_for_skip = true
	scene._skip_requested = false

	scene._input(_make_joypad_press())

	assert_true(scene._skip_requested, "a gamepad button press should satisfy the skip wait, same as keyboard/mouse")

	remove_child(scene)
	scene.queue_free()
