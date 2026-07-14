extends Control
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

# First-launch-only onboarding window - just the welcome/how-to-play text.
# Recent-update content lives in its own separate UpdateSpotlightPanel now.

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		closed.emit()

const SmallIconScene := preload("res://scenes/SmallIcon.tscn")

@onready var box: Panel = $Box
@onready var icon_holder: Control = $Box/VBox/IconHolder
@onready var title_holder: Control = $Box/VBox/TitleHolder
@onready var title_label: Label = $Box/VBox/TitleHolder/TitleLabel
@onready var welcome_body: Label = $Box/VBox/Scroll/WelcomeBody
@onready var close_button: Button = $Box/VBox/CloseButton

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(box)
	close_button.pressed.connect(func(): closed.emit())
	var icon = SmallIconScene.instantiate()
	icon.icon_type = "event"
	icon.icon_bg = Color(0.15, 0.12, 0.05, 1)
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.add_child(icon)
	_build_title_fx()

	welcome_body.text = "Welcome to Dead Sector! This is a real Alpha - the core loop is here (raid, loot, extract, gear up, come back harder) but you'll run into rough edges, unfinished corners, and things that still need balancing. That's expected at this stage.\n\nThe short version: pick a Sector, gear up from your Stash before you go, extract before your time runs out or you don't keep what you found. Contacts around the Hideout hand out contracts for real rewards. Spend what you earn on Skill Tree upgrades, Hideout training, and better gear. Everything you build up carries forward raid to raid - that's the whole point.\n\nFound something broken? There's a Feedback button right on this screen for exactly that."

# A slow warm shimmer sweeping across the title's color/glow, a gentle
# breathing scale pulse, and a handful of drifting gold sparks behind
# it - meant to make the very first thing a new player reads feel like
# an event, not just another label.
func _build_title_fx() -> void:
	title_label.pivot_offset = Vector2(130, 16)

	var shimmer_tw := title_label.create_tween()
	shimmer_tw.bind_node(title_label)
	shimmer_tw.set_loops()
	shimmer_tw.tween_property(title_label, "modulate", Color(1.35, 1.2, 0.75, 1), 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	shimmer_tw.tween_property(title_label, "modulate", Color(0.95, 0.8, 0.55, 1), 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var pulse_tw := title_label.create_tween()
	pulse_tw.bind_node(title_label)
	pulse_tw.set_loops()
	pulse_tw.tween_property(title_label, "scale", Vector2(1.025, 1.025), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tw.tween_property(title_label, "scale", Vector2(1.0, 1.0), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var sparks := CPUParticles2D.new()
	sparks.z_index = -1
	sparks.emitting = true
	sparks.amount = 14
	sparks.lifetime = 2.0
	sparks.direction = Vector2.UP
	sparks.spread = 100.0
	sparks.gravity = Vector2(0, -4.0)
	sparks.initial_velocity_min = 4.0
	sparks.initial_velocity_max = 14.0
	sparks.scale_amount_min = 1.2
	sparks.scale_amount_max = 2.4
	sparks.color = Color(1.0, 0.85, 0.45, 0.65)
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparks.emission_rect_extents = Vector2(130, 4)
	sparks.position = Vector2(130, 16)
	title_holder.add_child(sparks)

func open() -> void:
	visible = true
	# Runtime anchor-collapse bug (same one Flea Market/Mail hit) - force
	# the designed layout back explicitly every time this opens, for both
	# the full-screen root AND the centered inner Box. Previously only
	# Box was being re-forced, which wasn't enough - the whole panel was
	# showing pinned to the top-left instead of centered.
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	box.anchor_left = 0.5
	box.anchor_top = 0.5
	box.anchor_right = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -260.0
	box.offset_top = -240.0
	box.offset_right = 260.0
	box.offset_bottom = 240.0
