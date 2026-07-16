extends Panel

# In-run pause menu (ESC). Has a main button row (Resume / Settings / Exit)
# and an inline settings sub-view so adjusting audio/fullscreen mid-run
# doesn't require leaving (and losing) the active run.

@onready var main_view: Control = $MainView
@onready var settings_view: Control = $SettingsView

@onready var resume_button: Button = $MainView/ResumeButton
@onready var settings_button: Button = $MainView/SettingsButton
@onready var exit_button: Button = $MainView/ExitButton

@onready var master_slider: HSlider = $SettingsView/MasterRow/MasterSlider
@onready var music_slider: HSlider = $SettingsView/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $SettingsView/SfxRow/SfxSlider
@onready var fullscreen_toggle: OptionButton = $SettingsView/FullscreenRow/FullscreenToggle
@onready var settings_back_button: Button = $SettingsView/SettingsBackButton

signal resume_requested
signal exit_requested

func _ready() -> void:
	# Matches HUD.gd, which now actually pauses the tree while this menu is
	# open - everything the player needs to interact with in here has to
	# keep processing/receiving input regardless, or the menu (including
	# its own Resume button) would freeze along with everything else.
	process_mode = Node.PROCESS_MODE_ALWAYS
	main_view.process_mode = Node.PROCESS_MODE_ALWAYS
	settings_view.process_mode = Node.PROCESS_MODE_ALWAYS
	resume_button.process_mode = Node.PROCESS_MODE_ALWAYS
	settings_button.process_mode = Node.PROCESS_MODE_ALWAYS
	exit_button.process_mode = Node.PROCESS_MODE_ALWAYS
	master_slider.process_mode = Node.PROCESS_MODE_ALWAYS
	music_slider.process_mode = Node.PROCESS_MODE_ALWAYS
	sfx_slider.process_mode = Node.PROCESS_MODE_ALWAYS
	fullscreen_toggle.process_mode = Node.PROCESS_MODE_ALWAYS
	settings_back_button.process_mode = Node.PROCESS_MODE_ALWAYS
	main_view.visible = true
	settings_view.visible = false

	resume_button.pressed.connect(func(): resume_requested.emit())
	settings_button.pressed.connect(_show_settings)
	exit_button.pressed.connect(func(): exit_requested.emit())
	settings_back_button.pressed.connect(_show_main)

	master_slider.value_changed.connect(func(v): GameManager.master_volume = v; GameManager.apply_settings())
	music_slider.value_changed.connect(func(v): GameManager.music_volume = v; GameManager.apply_settings())
	sfx_slider.value_changed.connect(func(v): GameManager.sfx_volume = v; GameManager.apply_settings())
	fullscreen_toggle.clear()
	fullscreen_toggle.add_item("Windowed")
	fullscreen_toggle.add_item("Fullscreen")
	fullscreen_toggle.add_item("Windowed Fullscreen")
	fullscreen_toggle.item_selected.connect(func(index): GameManager.window_mode_setting = ["windowed", "fullscreen", "windowed_fullscreen"][index]; GameManager.apply_settings())

func open() -> void:
	_show_main()
	master_slider.value = GameManager.master_volume
	music_slider.value = GameManager.music_volume
	sfx_slider.value = GameManager.sfx_volume
	fullscreen_toggle.select(["windowed", "fullscreen", "windowed_fullscreen"].find(GameManager.window_mode_setting))
	visible = true

func close() -> void:
	visible = false

func _show_main() -> void:
	main_view.visible = true
	settings_view.visible = false
	GameManager.focus_first_control(main_view)

func _show_settings() -> void:
	main_view.visible = false
	settings_view.visible = true
	GameManager.focus_first_control(settings_view)
