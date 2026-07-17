extends Control

@onready var main_view: VBoxContainer = $MainView
@onready var keybinds_view: VBoxContainer = $KeybindsView

@onready var master_slider: HSlider = $MainView/MasterRow/MasterSlider
@onready var music_slider: HSlider = $MainView/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $MainView/SfxRow/SfxSlider
@onready var fullscreen_toggle: OptionButton = $MainView/FullscreenRow/FullscreenToggle
@onready var vsync_toggle: CheckButton = $MainView/VsyncRow/VsyncToggle
@onready var shake_toggle: CheckButton = $MainView/ShakeRow/ShakeToggle
@onready var keybinds_button: Button = $MainView/KeybindsButton
@onready var back_button: Button = $MainView/BackButton

@onready var interact_bind_button: Button = $KeybindsView/InteractRow/InteractBindButton
@onready var prone_bind_button: Button = $KeybindsView/ProneRow/ProneBindButton
@onready var jump_bind_button: Button = $KeybindsView/JumpRow/JumpBindButton
@onready var dash_bind_button: Button = $KeybindsView/DashRow/DashBindButton
@onready var nightvision_bind_button: Button = $KeybindsView/NightvisionRow/NightvisionBindButton
@onready var chat_bind_button: Button = $KeybindsView/ChatRow/ChatBindButton
@onready var inventory_bind_button: Button = $KeybindsView/InventoryRow/InventoryBindButton
@onready var reset_keybinds_button: Button = $KeybindsView/ResetKeybindsButton
@onready var keybinds_back_button: Button = $KeybindsView/KeybindsBackButton

@onready var interact_gamepad_bind_button: Button = $KeybindsView/InteractRow/InteractGamepadBindButton
@onready var prone_gamepad_bind_button: Button = $KeybindsView/ProneRow/ProneGamepadBindButton
@onready var jump_gamepad_bind_button: Button = $KeybindsView/JumpRow/JumpGamepadBindButton
@onready var dash_gamepad_bind_button: Button = $KeybindsView/DashRow/DashGamepadBindButton
@onready var nightvision_gamepad_bind_button: Button = $KeybindsView/NightvisionRow/NightvisionGamepadBindButton
@onready var chat_gamepad_bind_button: Button = $KeybindsView/ChatRow/ChatGamepadBindButton
@onready var inventory_gamepad_bind_button: Button = $KeybindsView/InventoryRow/InventoryGamepadBindButton

var rebinding_action: String = ""
var rebinding_gamepad_action: String = ""

const GamepadGlyphScript := preload("res://scripts/GamepadGlyph.gd")
# One small drawn glyph badge per gamepad-bind button, keyed by action -
# a real Xbox-colored icon next to the existing text label, rather than
# just text alone. Built at runtime (not baked into Settings.tscn) so
# adding this didn't require hand-editing 7 near-identical node blocks.
var _gamepad_glyphs: Dictionary = {}

func _setup_gamepad_glyphs() -> void:
	var buttons := {
		"interact": interact_gamepad_bind_button, "prone": prone_gamepad_bind_button,
		"jump": jump_gamepad_bind_button, "dash": dash_gamepad_bind_button,
		"nightvision": nightvision_gamepad_bind_button, "chat": chat_gamepad_bind_button,
		"inventory": inventory_gamepad_bind_button,
	}
	for action in buttons:
		var button: Button = buttons[action]
		var glyph = GamepadGlyphScript.new()
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.anchor_left = 0.0
		glyph.anchor_top = 0.5
		glyph.anchor_right = 0.0
		glyph.anchor_bottom = 0.5
		glyph.offset_left = 6
		glyph.offset_top = -12
		glyph.offset_right = 30
		glyph.offset_bottom = 12
		button.add_child(glyph)
		_gamepad_glyphs[action] = glyph

# Xbox-style naming - reads from GameManager.JOY_BUTTON_GLYPH_LABELS (the
# same canonical table the in-world "Press F"/"Press R" prompt glyphs use
# via GameManager.format_prompt()) rather than keeping a second copy.
# Godot has no built-in "get joy button string" the way
# OS.get_keycode_string() covers keyboard.
# D-Pad Up is the fixed pause/back button everywhere in the game (see
# CLAUDE.md) - reserved as this screen's gamepad-rebind cancel button
# instead of Escape, and never assignable to an action.
const GAMEPAD_REBIND_CANCEL_BUTTON := JOY_BUTTON_DPAD_UP

func _input(event: InputEvent) -> void:
	if rebinding_action != "" and event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.keycode == KEY_ESCAPE:
			# Escape cancels the rebind instead of becoming the new bind -
			# without this there was no way to back out of rebind mode
			# once you'd clicked into it.
			rebinding_action = ""
			_refresh_keybind_labels()
			return
		GameManager.set_keybind(rebinding_action, event.keycode)
		_refresh_keybind_labels()
		rebinding_action = ""
		return
	if rebinding_gamepad_action != "" and event is InputEventJoypadButton and event.pressed:
		get_viewport().set_input_as_handled()
		if event.button_index == GAMEPAD_REBIND_CANCEL_BUTTON:
			rebinding_gamepad_action = ""
			_refresh_gamepad_bind_labels()
			return
		GameManager.set_joypad_binding(rebinding_gamepad_action, event.button_index)
		_refresh_gamepad_bind_labels()
		rebinding_gamepad_action = ""
		return
	if event is InputEventKey and event.keycode == KEY_TAB and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
	if (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		if rebinding_gamepad_action != "":
			# A joypad-button press here would already have been caught
			# and returned by the gamepad-rebind block above - this only
			# still runs for a KEY_ESCAPE press while a gamepad rebind is
			# active (reaching for the keyboard mid-rebind), so cancel
			# that too instead of leaving the button stuck on "Press a
			# button...".
			rebinding_gamepad_action = ""
			_refresh_gamepad_bind_labels()
			return
		if GlobalChatBox.chat_box_open:
			return
		get_viewport().set_input_as_handled()
		if keybinds_view.visible:
			_show_main()
		else:
			_on_back()

func _ready() -> void:
	master_slider.value = GameManager.master_volume
	music_slider.value = GameManager.music_volume
	sfx_slider.value = GameManager.sfx_volume
	fullscreen_toggle.clear()
	fullscreen_toggle.add_item("Windowed")
	fullscreen_toggle.add_item("Fullscreen")
	fullscreen_toggle.add_item("Windowed Fullscreen")
	fullscreen_toggle.select(["windowed", "fullscreen", "windowed_fullscreen"].find(GameManager.window_mode_setting))
	vsync_toggle.button_pressed = GameManager.vsync_enabled
	shake_toggle.button_pressed = GameManager.screen_shake_enabled
	_setup_gamepad_glyphs()
	_refresh_keybind_labels()
	_refresh_gamepad_bind_labels()
	main_view.visible = true
	keybinds_view.visible = false
	GameManager.focus_first_control(main_view)

	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	fullscreen_toggle.item_selected.connect(_on_display_mode_selected)
	vsync_toggle.toggled.connect(_on_vsync_toggled)
	shake_toggle.toggled.connect(_on_shake_toggled)
	keybinds_button.pressed.connect(_show_keybinds)
	back_button.pressed.connect(_on_back)

	interact_bind_button.pressed.connect(func(): _start_rebind("interact", interact_bind_button))
	prone_bind_button.pressed.connect(func(): _start_rebind("prone", prone_bind_button))
	jump_bind_button.pressed.connect(func(): _start_rebind("jump", jump_bind_button))
	dash_bind_button.pressed.connect(func(): _start_rebind("dash", dash_bind_button))
	nightvision_bind_button.pressed.connect(func(): _start_rebind("nightvision", nightvision_bind_button))
	chat_bind_button.pressed.connect(func(): _start_rebind("chat", chat_bind_button))
	inventory_bind_button.pressed.connect(func(): _start_rebind("inventory", inventory_bind_button))
	reset_keybinds_button.pressed.connect(_on_reset_keybinds)
	keybinds_back_button.pressed.connect(_show_main)

	interact_gamepad_bind_button.pressed.connect(func(): _start_gamepad_rebind("interact", interact_gamepad_bind_button))
	prone_gamepad_bind_button.pressed.connect(func(): _start_gamepad_rebind("prone", prone_gamepad_bind_button))
	jump_gamepad_bind_button.pressed.connect(func(): _start_gamepad_rebind("jump", jump_gamepad_bind_button))
	dash_gamepad_bind_button.pressed.connect(func(): _start_gamepad_rebind("dash", dash_gamepad_bind_button))
	nightvision_gamepad_bind_button.pressed.connect(func(): _start_gamepad_rebind("nightvision", nightvision_gamepad_bind_button))
	chat_gamepad_bind_button.pressed.connect(func(): _start_gamepad_rebind("chat", chat_gamepad_bind_button))
	inventory_gamepad_bind_button.pressed.connect(func(): _start_gamepad_rebind("inventory", inventory_gamepad_bind_button))

	_build_controller_section()

func _show_keybinds() -> void:
	main_view.visible = false
	keybinds_view.visible = true
	GameManager.focus_first_control(keybinds_view)

func _show_main() -> void:
	keybinds_view.visible = false
	main_view.visible = true
	GameManager.focus_first_control(main_view)
	rebinding_action = ""
	rebinding_gamepad_action = ""
	# Reset any button left showing "Press a key.../Press a button..." if
	# Back was pressed mid-rebind instead of completing or Escape-cancelling
	# it (those paths already refresh labels themselves - see _input()).
	_refresh_keybind_labels()
	_refresh_gamepad_bind_labels()

func _on_reset_keybinds() -> void:
	# Cancel any rebind in progress first - otherwise the next keypress
	# after this could get captured as a rebind for whatever action was
	# mid-listen, immediately undoing the reset for that one action.
	rebinding_action = ""
	rebinding_gamepad_action = ""
	GameManager.reset_keybinds_to_defaults()
	_refresh_keybind_labels()
	_refresh_gamepad_bind_labels()
	GameManager.toast_requested.emit("Keybinds reset to defaults")

func _start_rebind(action: String, button: Button) -> void:
	rebinding_action = action
	button.text = "Press a key..."

func _refresh_keybind_labels() -> void:
	interact_bind_button.text = OS.get_keycode_string(GameManager.get_keybind("interact"))
	prone_bind_button.text = OS.get_keycode_string(GameManager.get_keybind("prone"))
	jump_bind_button.text = OS.get_keycode_string(GameManager.get_keybind("jump"))
	dash_bind_button.text = OS.get_keycode_string(GameManager.get_keybind("dash"))
	nightvision_bind_button.text = OS.get_keycode_string(GameManager.get_keybind("nightvision"))
	chat_bind_button.text = OS.get_keycode_string(GameManager.get_keybind("chat"))
	inventory_bind_button.text = OS.get_keycode_string(GameManager.get_keybind("inventory"))

func _start_gamepad_rebind(action: String, button: Button) -> void:
	rebinding_gamepad_action = action
	button.text = "Press a button..."

func _joy_button_name(button_index: int) -> String:
	return GameManager.get_gamepad_button_label(button_index)

func _refresh_gamepad_bind_labels() -> void:
	interact_gamepad_bind_button.text = _joy_button_name(GameManager.get_joypad_binding("interact"))
	prone_gamepad_bind_button.text = _joy_button_name(GameManager.get_joypad_binding("prone"))
	jump_gamepad_bind_button.text = _joy_button_name(GameManager.get_joypad_binding("jump"))
	dash_gamepad_bind_button.text = _joy_button_name(GameManager.get_joypad_binding("dash"))
	nightvision_gamepad_bind_button.text = _joy_button_name(GameManager.get_joypad_binding("nightvision"))
	chat_gamepad_bind_button.text = _joy_button_name(GameManager.get_joypad_binding("chat"))
	inventory_gamepad_bind_button.text = _joy_button_name(GameManager.get_joypad_binding("inventory"))
	for action in _gamepad_glyphs:
		_gamepad_glyphs[action].set_button(GameManager.get_joypad_binding(action))

# value_changed fires on every step of a drag, not just on release - these
# three used to call save_game() on every one of those ticks, serializing
# and writing the entire save file dozens of times in a couple of seconds
# (real, reproducible stutter). apply_settings() still applies the volume
# live so dragging still sounds instant; _on_back() below already saves
# once when leaving this screen, same as PauseMenu.gd's equivalent
# sliders never saving per-tick either.
func _on_master_changed(value: float) -> void:
	GameManager.master_volume = value
	GameManager.apply_settings()

func _on_music_changed(value: float) -> void:
	GameManager.music_volume = value
	GameManager.apply_settings()

func _on_sfx_changed(value: float) -> void:
	GameManager.sfx_volume = value
	GameManager.apply_settings()

func _on_display_mode_selected(index: int) -> void:
	GameManager.window_mode_setting = ["windowed", "fullscreen", "windowed_fullscreen"][index]
	GameManager.apply_settings()
	GameManager.save_game()

func _on_vsync_toggled(pressed: bool) -> void:
	GameManager.vsync_enabled = pressed
	GameManager.apply_settings()
	GameManager.save_game()

func _on_shake_toggled(pressed: bool) -> void:
	GameManager.screen_shake_enabled = pressed
	GameManager.save_game()

func _on_back() -> void:
	GameManager.save_game()
	Transition.change_scene_instant("res://scenes/MainMenu.tscn")

# Live connection status, since "is my controller actually being read?"
# has no other way to check in-game. The 7 rebindable actions each get
# their own gamepad-bind button right next to their keyboard one (see
# the KeybindsView rows) - this section just adds the status line plus
# a reference for the handful of gamepad inputs that aren't simple
# single-button binds (analog sticks/triggers) or are fixed system
# conventions (Pause, Hotbar), so those still have a printed reference.
var controller_status_label: Label

func _build_controller_section() -> void:
	var header := Label.new()
	header.text = "CONTROLLER"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 1))
	header.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	header.add_theme_constant_override("outline_size", 3)
	keybinds_view.add_child(header)
	keybinds_view.move_child(header, keybinds_back_button.get_index())

	controller_status_label = Label.new()
	controller_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controller_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	controller_status_label.add_theme_font_size_override("font_size", 15)
	keybinds_view.add_child(controller_status_label)
	keybinds_view.move_child(controller_status_label, keybinds_back_button.get_index())

	var map_label := Label.new()
	map_label.text = "Move: Left Stick   Aim: Right Stick   Shoot: Right Trigger   Aim Down Sights: Left Trigger\nReload: X   Pause: D-Pad Up   Hotbar Prev / Next: LB / RB   Menu Cursor: Left Stick\n(Interact/Jump/Dash/Nightvision/Prone/Chat/Inventory are rebindable above - D-Pad Up cancels a rebind)"
	map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	map_label.add_theme_font_size_override("font_size", 13)
	map_label.modulate = Color(1, 1, 1, 0.75)
	keybinds_view.add_child(map_label)
	keybinds_view.move_child(map_label, keybinds_back_button.get_index())

	Input.joy_connection_changed.connect(func(_device, _connected): _refresh_controller_status())
	GameManager.input_device_changed.connect(func(_is_gamepad): _refresh_controller_status())
	_refresh_controller_status()

func _refresh_controller_status() -> void:
	var connected: bool = Input.get_connected_joypads().size() > 0
	if not connected:
		controller_status_label.text = "No controller detected"
		controller_status_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.45, 1))
	elif GameManager.using_gamepad:
		controller_status_label.text = "Controller connected - currently active"
		controller_status_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.55, 1))
	else:
		controller_status_label.text = "Controller connected - press any button to test it"
		controller_status_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4, 1))
