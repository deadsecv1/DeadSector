extends Area2D

# Reach this after the boss is down to clear the level. If the boss is
# still alive, it just tells you so instead of letting you skip the fight.

@export var level_number: int = 1
var player_in_range: bool = false
var f_was_down: bool = false
var triggered: bool = false

@onready var prompt: Label = $Prompt
@onready var flare: Node2D = $Flare

func _ready() -> void:
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)
	prompt.visible = false

func _on_entered(body: Node) -> void:
	if body.is_in_group("gauntlet_player"):
		player_in_range = true
		prompt.visible = true

func _on_exited(body: Node) -> void:
	if body.is_in_group("gauntlet_player"):
		player_in_range = false
		prompt.visible = false

func _process(_delta: float) -> void:
	if triggered or not player_in_range:
		return
	var boss_alive: bool = not get_tree().get_nodes_in_group("gauntlet_boss").is_empty()
	prompt.text = "Defeat the boss first!" if boss_alive else "Press F: Extract"
	if boss_alive:
		return
	var f_down := Input.is_key_pressed(GameManager.get_keybind("interact"))
	if f_down and not f_was_down:
		_extract()
	f_was_down = f_down

func _extract() -> void:
	triggered = true
	prompt.visible = false
	var level_loot_count: int = GameManager.carried_loot.size()
	GameManager.complete_gauntlet_level(level_number)
	await _show_extraction_success(level_loot_count)
	if level_number >= GameManager.GAUNTLET_MAX_LEVEL:
		Transition.change_scene_instant("res://scenes/GauntletComplete.tscn")
		return
	var next_path := "res://scenes/GauntletLevel%d.tscn" % (level_number + 1)
	if not ResourceLoader.exists(next_path):
		# Later levels aren't built yet - land safely back at the Main
		# Menu instead of trying to load a scene that doesn't exist.
		GameManager.end_gauntlet_session()
		GameManager.toast_requested.emit("More Bloodline levels coming soon!")
		Transition.change_scene_instant("res://scenes/MainMenu.tscn")
		return
	var wants_menu: bool = await _show_continue_choice()
	if wants_menu:
		Transition.change_scene_instant("res://scenes/GauntletComplete.tscn")
	else:
		GameManager.gauntlet_current_level = level_number + 1
		Transition.change_scene_instant(next_path)

# After a successful extraction, let the player actually choose instead
# of always auto-continuing - bank everything and head back to the Main
# Menu (via GauntletComplete, which already handles saving carried loot
# and equipped gear to the Stash), or keep pushing into the next level
# with the run still live.
func _show_continue_choice() -> bool:
	var overlay := CanvasLayer.new()
	overlay.layer = 30
	get_tree().current_scene.add_child(overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.04, 0.85)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	overlay.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.anchor_left = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -220
	vbox.offset_top = -90
	vbox.offset_right = 220
	vbox.offset_bottom = 90
	vbox.add_theme_constant_override("separation", 12)
	overlay.add_child(vbox)

	var title := Label.new()
	title.text = "Level %d Clear" % level_number
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3, 1))
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Keep pushing deeper, or bank everything and head back now? Either way, nothing you're carrying or wearing is at risk once you choose."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	sub.add_theme_font_size_override("font_size", 12)
	sub.modulate = Color(1, 1, 1, 0.8)
	vbox.add_child(sub)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 16)
	vbox.add_child(button_row)

	var menu_btn := Button.new()
	menu_btn.text = "Return to Main Menu\n(Keep Everything)"
	menu_btn.custom_minimum_size = Vector2(190, 50)
	button_row.add_child(menu_btn)

	var continue_btn := Button.new()
	continue_btn.text = "Continue to Level %d" % (level_number + 1)
	continue_btn.custom_minimum_size = Vector2(190, 50)
	button_row.add_child(continue_btn)

	# Plain bool locals get captured BY VALUE inside a lambda in GDScript -
	# reassigning them inside func(): ... only changes the lambda's own
	# private copy, never the outer variable. That meant `done` here
	# never actually became true from the outer scope's point of view,
	# so the while loop below would spin forever and this dialog would
	# silently hang no matter which button got clicked. Single-element
	# arrays are captured by reference instead, so mutating their
	# contents from inside the lambda is actually visible out here.
	var result := [false]
	var done := [false]
	menu_btn.pressed.connect(func(): result[0] = true; done[0] = true)
	continue_btn.pressed.connect(func(): result[0] = false; done[0] = true)

	while not done[0]:
		await get_tree().process_frame
	overlay.queue_free()
	return result[0]

func _show_extraction_success(loot_count: int) -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 30
	get_tree().current_scene.add_child(overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.02, 0.02, 0)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	overlay.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.anchor_left = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -220
	vbox.offset_top = -60
	vbox.offset_right = 220
	vbox.offset_bottom = 60
	vbox.modulate.a = 0.0
	overlay.add_child(vbox)

	var title := Label.new()
	title.text = "EXTRACTED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("outline_size", 6)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Level %d cleared - %d item%s secured" % [level_number, loot_count, "" if loot_count == 1 else "s"]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	vbox.add_child(sub)

	Sfx.play_reveal()
	var tw := create_tween()
	tw.tween_property(bg, "color:a", 0.75, 0.3)
	tw.parallel().tween_property(vbox, "modulate:a", 1.0, 0.4)
	await get_tree().create_timer(1.6).timeout
	var tw2 := create_tween()
	tw2.tween_property(bg, "color:a", 0.0, 0.35)
	tw2.parallel().tween_property(vbox, "modulate:a", 0.0, 0.3)
	await tw2.finished
	overlay.queue_free()
