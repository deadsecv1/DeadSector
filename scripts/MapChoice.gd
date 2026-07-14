extends Control

const SmallIconScene := preload("res://scenes/SmallIcon.tscn")
const BONECLOCK_LEVEL_REQUIREMENT := 10
const VOID_TRENCH_LEVEL_REQUIREMENT := 20

@onready var overgrowth_button: Button = $VBox/MapRow/OvergrowthCard
@onready var boneclock_button: Button = $VBox/MapRow/BoneclockCard
@onready var boneclock_skull_slot: Control = $VBox/MapRow/BoneclockCard/BoneclockVBox/BoneclockTitleRow/BoneclockSkull
@onready var boneclock_lock_label: Label = $VBox/MapRow/BoneclockCard/BoneclockVBox/BoneclockLockLabel
@onready var void_trench_button: Button = $VBox/MapRow/VoidTrenchCard
@onready var void_trench_lock_label: Label = $VBox/MapRow/VoidTrenchCard/VoidTrenchVBox/VoidTrenchLockLabel
@onready var back_button: Button = $VBox/BackButton

func _input(event: InputEvent) -> void:
	if GlobalChatBox.chat_box_open:
		return
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		Transition.change_scene_instant("res://scenes/MainMenu.tscn")

func _ready() -> void:
	GameManager.set_default_cursor()
	var skull = SmallIconScene.instantiate()
	skull.icon_type = "skull"
	skull.icon_bg = Color(0.15, 0.1, 0.1, 1)
	boneclock_skull_slot.add_child(skull)

	var unlocked: bool = GameManager.player_level >= BONECLOCK_LEVEL_REQUIREMENT
	boneclock_lock_label.visible = not unlocked
	boneclock_button.modulate = Color(1, 1, 1, 1) if unlocked else Color(0.6, 0.6, 0.6, 1)

	var void_unlocked: bool = GameManager.player_level >= VOID_TRENCH_LEVEL_REQUIREMENT
	void_trench_lock_label.visible = not void_unlocked
	void_trench_button.modulate = Color(1, 1, 1, 1) if void_unlocked else Color(0.6, 0.6, 0.6, 1)

	overgrowth_button.pressed.connect(func(): _choose("overgrowth"))
	boneclock_button.pressed.connect(func(): _choose("boneclock"))
	void_trench_button.pressed.connect(func(): _choose("void_trench"))
	back_button.pressed.connect(func(): Transition.change_scene_instant("res://scenes/MainMenu.tscn"))

func _choose(map_id: String) -> void:
	if map_id == "boneclock" and GameManager.player_level < BONECLOCK_LEVEL_REQUIREMENT:
		GameManager.toast_requested.emit("Boneclock unlocks at Level %d (you're Level %d)" % [BONECLOCK_LEVEL_REQUIREMENT, GameManager.player_level])
		return
	if map_id == "void_trench" and GameManager.player_level < VOID_TRENCH_LEVEL_REQUIREMENT:
		GameManager.toast_requested.emit("Void Trench unlocks at Level %d (you're Level %d)" % [VOID_TRENCH_LEVEL_REQUIREMENT, GameManager.player_level])
		return
	GameManager.selected_map = map_id
	Transition.change_scene("res://scenes/MapSelect.tscn")
