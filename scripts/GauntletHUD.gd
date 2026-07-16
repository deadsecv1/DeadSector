extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthBar
@onready var health_label: Label = $HealthLabel
@onready var level_label: Label = $LevelLabel
@onready var death_screen: Control = $DeathScreen
@onready var retry_button: Button = $DeathScreen/Panel/VBox/RetryButton
@onready var menu_button: Button = $DeathScreen/Panel/VBox/MenuButton
@onready var inventory_panel: Control = $InventoryPanel
@onready var pause_overlay: Control = $PauseOverlay
@onready var resume_button: Button = $PauseOverlay/VBox/ResumeButton
@onready var pause_menu_button: Button = $PauseOverlay/VBox/PauseMenuButton

var player: Node = null
var tab_was_down: bool = false
var esc_was_down: bool = false

func _ready() -> void:
	# The root HUD node itself needs to keep processing even while the
	# tree is paused - otherwise _process() (which is what actually
	# detects the Tab/Esc key presses to close the inventory again)
	# freezes the moment the pause takes effect, and Tab stops working
	# after the first press.
	process_mode = Node.PROCESS_MODE_ALWAYS
	death_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	death_screen.visible = false
	retry_button.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_button.process_mode = Node.PROCESS_MODE_ALWAYS
	retry_button.pressed.connect(_on_retry)
	menu_button.pressed.connect(_on_menu)
	inventory_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	inventory_panel.visible = false
	pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_overlay.visible = false
	resume_button.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu_button.process_mode = Node.PROCESS_MODE_ALWAYS
	resume_button.pressed.connect(_close_pause)
	pause_menu_button.pressed.connect(_on_menu)
	player = get_tree().get_first_node_in_group("gauntlet_player")
	if player != null:
		player.health_changed.connect(_on_health_changed)
		_on_health_changed(player.health, player.max_health)
		player.died.connect(_on_player_died)
	level_label.text = "BLOODLINE - Level %d / %d" % [GameManager.gauntlet_current_level, GameManager.GAUNTLET_MAX_LEVEL]

func _process(_delta: float) -> void:
	if death_screen.visible:
		return
	var tab_down := GameManager.is_action_pressed("inventory")
	if tab_down and not tab_was_down and not pause_overlay.visible:
		inventory_panel.visible = not inventory_panel.visible
		if inventory_panel.visible:
			inventory_panel.refresh()
			GameManager.focus_first_control(inventory_panel)
		get_tree().paused = inventory_panel.visible
	tab_was_down = tab_down

	var esc_down := Input.is_key_pressed(KEY_ESCAPE) or GameManager.is_pause_pressed()
	if esc_down and not esc_was_down:
		if GlobalChatBox.chat_box_open:
			# GlobalChatBox polls Escape independently to close itself -
			# this branch just needs to exist so this chain doesn't also
			# toggle the Pause overlay on the same press.
			pass
		elif inventory_panel.visible:
			inventory_panel.visible = false
			get_tree().paused = false
		else:
			pause_overlay.visible = not pause_overlay.visible
			get_tree().paused = pause_overlay.visible
	esc_was_down = esc_down

func _close_pause() -> void:
	pause_overlay.visible = false
	get_tree().paused = false

func _on_retry() -> void:
	get_tree().paused = false
	# Retrying after a death is still a death - carried loot and
	# equipped gear should be forfeit same as if you'd gone to the
	# Main Menu, not carried into the new attempt for free.
	GameManager.carried_loot.clear()
	GameManager.carried_value = 0
	GameManager.gauntlet_session_loot.clear()
	GameManager.gauntlet_session_engrams.clear()
	GameManager.reset_gauntlet_equipment()
	get_tree().reload_current_scene()

func _on_menu() -> void:
	get_tree().paused = false
	GameManager.abandon_gauntlet_session()
	Transition.change_scene_instant("res://scenes/MainMenu.tscn")

func _on_health_changed(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "%d / %d" % [current, maximum]

func _on_player_died() -> void:
	get_tree().paused = true
	death_screen.visible = true
