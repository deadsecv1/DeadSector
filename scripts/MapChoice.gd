extends Control

const ItemIconScene := preload("res://scenes/ItemIcon.tscn")
const BONECLOCK_LEVEL_REQUIREMENT := 10
const VOID_TRENCH_LEVEL_REQUIREMENT := 20
const IRONSCRAP_LEVEL_REQUIREMENT := 30
const FOUNDRY_LEVEL_REQUIREMENT := 40

@onready var overgrowth_button: Button = $VBox/MapRow/OvergrowthCard
@onready var overgrowth_vbox: VBoxContainer = $VBox/MapRow/OvergrowthCard/OvergrowthVBox
@onready var boneclock_button: Button = $VBox/MapRow/BoneclockCard
@onready var boneclock_vbox: VBoxContainer = $VBox/MapRow/BoneclockCard/BoneclockVBox
@onready var boneclock_lock_label: Label = $VBox/MapRow/BoneclockCard/BoneclockVBox/BoneclockLockLabel
@onready var void_trench_button: Button = $VBox/MapRow/VoidTrenchCard
@onready var void_trench_vbox: VBoxContainer = $VBox/MapRow/VoidTrenchCard/VoidTrenchVBox
@onready var void_trench_lock_label: Label = $VBox/MapRow/VoidTrenchCard/VoidTrenchVBox/VoidTrenchLockLabel
@onready var ironscrap_button: Button = $VBox/MapRow/IronscrapCard
@onready var ironscrap_vbox: VBoxContainer = $VBox/MapRow/IronscrapCard/IronscrapVBox
@onready var ironscrap_lock_label: Label = $VBox/MapRow/IronscrapCard/IronscrapVBox/IronscrapLockLabel
@onready var foundry_button: Button = $VBox/MapRow/FoundryCard
@onready var foundry_vbox: VBoxContainer = $VBox/MapRow/FoundryCard/FoundryVBox
@onready var foundry_lock_label: Label = $VBox/MapRow/FoundryCard/FoundryVBox/FoundryLockLabel
@onready var back_button: Button = $VBox/BackButton

func _input(event: InputEvent) -> void:
	if GlobalChatBox.chat_box_open:
		return
	if (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		Transition.change_scene_instant("res://scenes/MainMenu.tscn")

func _ready() -> void:
	GameManager.set_default_cursor()

	# Same icon_key already used for each map on the Data screen's Maps
	# tab, and the same accent color each card's title already used - so
	# this is purely additive polish, not a new visual language.
	_add_map_icon(overgrowth_vbox, "map_overgrowth_icon", Color(0.55, 0.85, 0.4, 1))
	_style_card(overgrowth_button, Color(0.55, 0.85, 0.4, 1))
	_add_map_icon(boneclock_vbox, "map_boneclock_icon", Color(0.85, 0.8, 0.65, 1))
	_style_card(boneclock_button, Color(0.85, 0.8, 0.65, 1))
	_add_map_icon(void_trench_vbox, "map_void_trench_icon", Color(0.75, 0.45, 1.0, 1))
	_style_card(void_trench_button, Color(0.75, 0.45, 1.0, 1))
	_add_map_icon(ironscrap_vbox, "map_ironscrap_icon", Color(0.85, 0.55, 0.25, 1))
	_style_card(ironscrap_button, Color(0.85, 0.55, 0.25, 1))
	_add_map_icon(foundry_vbox, "map_foundry_icon", Color(0.85, 0.4, 0.25, 1))
	_style_card(foundry_button, Color(0.85, 0.4, 0.25, 1))

	var unlocked: bool = GameManager.player_level >= BONECLOCK_LEVEL_REQUIREMENT
	boneclock_lock_label.visible = not unlocked
	boneclock_button.modulate = Color(1, 1, 1, 1) if unlocked else Color(0.6, 0.6, 0.6, 1)

	var void_unlocked: bool = GameManager.player_level >= VOID_TRENCH_LEVEL_REQUIREMENT
	void_trench_lock_label.visible = not void_unlocked
	void_trench_button.modulate = Color(1, 1, 1, 1) if void_unlocked else Color(0.6, 0.6, 0.6, 1)

	var ironscrap_unlocked: bool = GameManager.player_level >= IRONSCRAP_LEVEL_REQUIREMENT
	ironscrap_lock_label.visible = not ironscrap_unlocked
	ironscrap_button.modulate = Color(1, 1, 1, 1) if ironscrap_unlocked else Color(0.6, 0.6, 0.6, 1)

	var foundry_unlocked: bool = GameManager.player_level >= FOUNDRY_LEVEL_REQUIREMENT
	foundry_lock_label.visible = not foundry_unlocked
	foundry_button.modulate = Color(1, 1, 1, 1) if foundry_unlocked else Color(0.6, 0.6, 0.6, 1)

	overgrowth_button.pressed.connect(func(): _choose("overgrowth"))
	boneclock_button.pressed.connect(func(): _choose("boneclock"))
	void_trench_button.pressed.connect(func(): _choose("void_trench"))
	ironscrap_button.pressed.connect(func(): _choose("ironscrap"))
	foundry_button.pressed.connect(func(): _choose("the_foundry"))
	back_button.pressed.connect(func(): Transition.change_scene_instant("res://scenes/MainMenu.tscn"))

# Inserts a themed ItemIcon above the title on a map card - the same
# icon_key already used for this map on the Data screen's Maps tab, so a
# player who's checked the compendium recognizes it here too.
func _add_map_icon(vbox: VBoxContainer, icon_key: String, color: Color) -> void:
	var icon = ItemIconScene.instantiate()
	icon.icon_key = icon_key
	icon.icon_color = color
	icon.custom_minimum_size = Vector2(0, 72)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon)
	vbox.move_child(icon, 0)

# Same idle/hover StyleBox + centered-scale-tween treatment as
# ArenaModeChoice.gd's mode cards - matches the "polish to look like other
# recently-redone screens" ask instead of these staying plain default
# buttons with no hover feedback at all.
func _style_card(card: Button, accent: Color) -> void:
	var idle_style := StyleBoxFlat.new()
	idle_style.bg_color = Color(0.1, 0.1, 0.11, 0.5)
	idle_style.border_color = Color(accent.r, accent.g, accent.b, 0.3)
	idle_style.set_border_width_all(2)
	idle_style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("normal", idle_style)
	card.add_theme_stylebox_override("focus", idle_style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.14, 0.14, 0.15, 0.7)
	hover_style.border_color = Color(accent.r, accent.g, accent.b, 0.9)
	hover_style.set_border_width_all(2)
	hover_style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("hover", hover_style)
	card.add_theme_stylebox_override("pressed", hover_style)

	card.resized.connect(func(): card.pivot_offset = card.size / 2.0)
	card.mouse_entered.connect(func():
		var tw := card.create_tween()
		tw.tween_property(card, "scale", Vector2(1.03, 1.03), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	card.mouse_exited.connect(func():
		var tw := card.create_tween()
		tw.tween_property(card, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_QUAD)
	)

func _choose(map_id: String) -> void:
	if map_id == "boneclock" and GameManager.player_level < BONECLOCK_LEVEL_REQUIREMENT:
		GameManager.toast_requested.emit("Boneclock unlocks at Level %d (you're Level %d)" % [BONECLOCK_LEVEL_REQUIREMENT, GameManager.player_level])
		return
	if map_id == "void_trench" and GameManager.player_level < VOID_TRENCH_LEVEL_REQUIREMENT:
		GameManager.toast_requested.emit("Void Trench unlocks at Level %d (you're Level %d)" % [VOID_TRENCH_LEVEL_REQUIREMENT, GameManager.player_level])
		return
	if map_id == "ironscrap" and GameManager.player_level < IRONSCRAP_LEVEL_REQUIREMENT:
		GameManager.toast_requested.emit("Ironscrap Yard unlocks at Level %d (you're Level %d)" % [IRONSCRAP_LEVEL_REQUIREMENT, GameManager.player_level])
		return
	if map_id == "the_foundry" and GameManager.player_level < FOUNDRY_LEVEL_REQUIREMENT:
		GameManager.toast_requested.emit("The Foundry unlocks at Level %d (you're Level %d)" % [FOUNDRY_LEVEL_REQUIREMENT, GameManager.player_level])
		return
	GameManager.selected_map = map_id
	Transition.change_scene("res://scenes/MapSelect.tscn")
