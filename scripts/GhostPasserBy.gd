extends Node2D

# A ghost drifting across the Soul Realm - used to be pure atmosphere,
# now interactable. Walk up and press F for an encounter: recruit him
# and he follows you for the rest of the raid, and if you extract
# with him still following, he becomes a permanent Hideout resident.

@export var drift_speed: float = 40.0
@export var drift_direction: Vector2 = Vector2.RIGHT
@export var travel_distance: float = 1400.0

const GHOST_COMPANION_SCENE := preload("res://scenes/GhostCompanion.tscn")

var start_pos: Vector2
var traveled: float = 0.0
var bob_phase: float = 0.0
var player_in_range: bool = false
var f_was_down: bool = false
var popup_open: bool = false
var recruited: bool = false

@onready var interact_zone: Area2D = $InteractZone
@onready var prompt: Label = $Prompt

func _ready() -> void:
	start_pos = position
	bob_phase = randf_range(0.0, TAU)
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.22, 1.5)
	interact_zone.body_entered.connect(_on_entered)
	interact_zone.body_exited.connect(_on_exited)

func _on_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		if not popup_open:
			prompt.visible = true

func _on_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		prompt.visible = false

func _process(delta: float) -> void:
	if recruited:
		return
	if player_in_range and not popup_open:
		var f_down := Input.is_key_pressed(GameManager.get_keybind("interact"))
		if f_down and not f_was_down:
			_open_encounter()
		f_was_down = f_down
	if popup_open:
		return
	traveled += drift_speed * delta
	bob_phase += delta * 1.2
	position = start_pos + drift_direction.normalized() * traveled + Vector2(0, sin(bob_phase) * 12.0)
	if traveled > travel_distance:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 1.0)
		tw.tween_callback(queue_free)
		set_process(false)

# --- The encounter itself: a spooky full-screen popup, built in code
# and added as a CanvasLayer so it renders in screen space regardless
# of where the ghost is in the world.
func _open_encounter() -> void:
	popup_open = true
	prompt.visible = false
	GameManager.discover_wandering_ghost()

	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.02, 0.0)
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)
	var fade_tw := backdrop.create_tween()
	fade_tw.tween_property(backdrop, "color:a", 0.75, 0.4)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -190
	panel.offset_top = -140
	panel.offset_right = 190
	panel.offset_bottom = 140
	panel.modulate.a = 0.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.04, 0.97)
	sb.border_color = Color(0.5, 0.85, 0.95, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(18)
	sb.shadow_size = 24
	sb.shadow_color = Color(0.3, 0.7, 0.9, 0.35)
	panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(panel)
	var panel_tw := panel.create_tween()
	panel_tw.tween_property(panel, "modulate:a", 1.0, 0.5)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "S O M E T H I N G   S T O P P E D"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0, 1))
	vbox.add_child(title)
	# A slow, uneven flicker on the title - unsettling rather than a
	# clean pulse, like the light's about to go out.
	var flicker_tw := title.create_tween()
	flicker_tw.bind_node(title)
	flicker_tw.set_loops()
	flicker_tw.tween_property(title, "modulate:a", 0.4, 0.12)
	flicker_tw.tween_property(title, "modulate:a", 1.0, 0.6)
	flicker_tw.tween_property(title, "modulate:a", 0.7, 0.08)
	flicker_tw.tween_property(title, "modulate:a", 1.0, 1.1)

	var body_lbl := Label.new()
	body_lbl.text = "The drifting light you've seen a dozen times before finally turns toward you. It doesn't speak. It just... waits. Like it's asking permission."
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_lbl.add_theme_font_size_override("font_size", 13)
	body_lbl.modulate = Color(1, 1, 1, 0.85)
	vbox.add_child(body_lbl)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer)

	var recruit_btn := Button.new()
	recruit_btn.text = "Let it follow you"
	recruit_btn.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(recruit_btn)

	var leave_btn := Button.new()
	leave_btn.text = "Walk away"
	leave_btn.custom_minimum_size = Vector2(0, 36)
	vbox.add_child(leave_btn)

	var closed := [false]
	var close_popup := func():
		if closed[0]:
			return
		closed[0] = true
		popup_open = false
		if is_instance_valid(layer):
			layer.queue_free()
		if player_in_range and not recruited:
			prompt.visible = true

	recruit_btn.pressed.connect(func():
		recruited = true
		GameManager.recruit_wandering_ghost_for_raid()
		GameManager.toast_requested.emit("The Ghost is following you now.")
		var companion = GHOST_COMPANION_SCENE.instantiate()
		get_parent().call_deferred("add_child", companion)
		companion.set_deferred("global_position", global_position)
		close_popup.call()
		queue_free()
	)
	leave_btn.pressed.connect(close_popup)

func _draw() -> void:
	var col := Color(0.7, 0.9, 0.95, 1)
	draw_circle(Vector2(0, -10), 9.0, col)
	var wisp_tail := PackedVector2Array([
		Vector2(-9, -6), Vector2(9, -6), Vector2(7, 10), Vector2(3, 4), Vector2(0, 12),
		Vector2(-3, 4), Vector2(-7, 10),
	])
	draw_colored_polygon(wisp_tail, col)
	draw_circle(Vector2(-3, -12), 1.4, Color(0.05, 0.1, 0.1, 0.8))
	draw_circle(Vector2(3, -12), 1.4, Color(0.05, 0.1, 0.1, 0.8))
