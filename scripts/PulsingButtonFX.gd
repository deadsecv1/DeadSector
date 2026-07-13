class_name PulsingButtonFX
extends RefCounted

# Drop-in "this button matters" treatment: a comet-trail line tracing
# the button's outline (reusing GlowTraceBorder.gd), a gentle breathing
# scale pulse, and a drifting particle aura around it. One call from
# any panel's _ready() - used for Enter the Gauntlet and Commune so far,
# but built generically so any other button can get the same treatment
# later without re-deriving all of this.

const GlowTraceBorderScript := preload("res://scripts/GlowTraceBorder.gd")

static func apply(button: Button, color: Color) -> void:
	button.pivot_offset = button.size / 2.0
	button.resized.connect(func(): button.pivot_offset = button.size / 2.0)

	# Tracing outline - a brighter, faster trace than the Alpha/Tech Test
	# item treatment since this needs to read clearly from across a menu,
	# not just up close on a small icon.
	var trace := Control.new()
	trace.anchor_right = 1.0
	trace.anchor_bottom = 1.0
	trace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trace.set_script(GlowTraceBorderScript)
	trace.trace_color = color
	trace.trace_speed = 70.0
	trace.trace_segments = 10
	trace.trace_width = 2.0
	trace.glow_boost = 1.4
	button.add_child(trace)

	# Breathing scale pulse - bound to the button itself so it can never
	# outlive it (see the tween lifetime fix from last update).
	var pulse_tw := button.create_tween()
	pulse_tw.bind_node(button)
	pulse_tw.set_loops()
	pulse_tw.tween_property(button, "scale", Vector2(1.035, 1.035), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tw.tween_property(button, "scale", Vector2(1.0, 1.0), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Drifting particle aura around the button - sized to match once the
	# button has its real layout size, not whatever it starts at.
	var particles := CPUParticles2D.new()
	particles.z_index = -1
	particles.emitting = true
	particles.amount = 22
	particles.lifetime = 1.6
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 8.0
	particles.initial_velocity_max = 26.0
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.0
	particles.color = Color(color.r, color.g, color.b, 0.55)
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	button.add_child(particles)

	var size_particles := func():
		particles.position = button.size / 2.0
		particles.emission_rect_extents = Vector2(max(button.size.x * 0.5, 4.0), max(button.size.y * 0.5, 4.0))
	size_particles.call()
	button.resized.connect(size_particles)
