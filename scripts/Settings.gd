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
@onready var keybinds_back_button: Button = $KeybindsView/KeybindsBackButton

var rebinding_action: String = ""

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
	if event is InputEventKey and event.keycode == KEY_TAB and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
	if (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
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
	_refresh_keybind_labels()
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
	keybinds_back_button.pressed.connect(_show_main)

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

# Read-only reference (see CLAUDE.md's "Controller/gamepad support" - there's
# deliberately no gamepad rebind UI, keyboard rebinds already apply
# automatically) plus a live status line, since "is my controller actually
# being read?" has no other way to check in-game.
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
	map_label.text = "Move: Left Stick   Aim: Right Stick   Shoot: Right Trigger   Aim Down Sights: Left Trigger\nInteract: A   Jump: Y   Dash: B   Nightvision / Reload: X   Prone: Left Stick Click\nInventory: Start   Chat: Back   Pause: D-Pad Up   Hotbar Prev / Next: LB / RB"
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
