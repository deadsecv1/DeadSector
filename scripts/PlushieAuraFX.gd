class_name PlushieAuraFX
extends RefCounted

# Visually marks a Plushie-buffed pet wherever its icon shows up (the
# equip doll, My Pets, the Pet Case browser) - a tracing border and a
# drifting particle aura, both tinted to the pet's own color rather
# than a fixed rarity color, since the whole point is "this one's
# special because of what it is," not because of a rarity roll.

const GlowTraceBorderScript := preload("res://scripts/GlowTraceBorder.gd")
const RESIZE_META_KEY := "_plushie_aura_resize_callable"

static func apply(target: Control, pet_color: Color) -> void:
	# apply() can be called again on the SAME persistent target (the
	# equip doll slot, an Info popup's icon holder) every time it
	# refreshes with a different pet - without this, the OLD resize
	# closure from the previous call stays connected forever, pointing
	# at particles that get freed on the next refresh. It's harmless
	# now (see the validity check below) but Godot still logs a
	# warning every time a stale one fires, which is what kept showing
	# up. Disconnecting the previous one before adding a new one stops
	# them from piling up at all.
	if target.has_meta(RESIZE_META_KEY):
		var old_callable: Callable = target.get_meta(RESIZE_META_KEY)
		if target.resized.is_connected(old_callable):
			target.resized.disconnect(old_callable)

	var trace := Control.new()
	trace.anchor_right = 1.0
	trace.anchor_bottom = 1.0
	trace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trace.set_script(GlowTraceBorderScript)
	trace.trace_color = pet_color
	trace.trace_speed = 46.0
	trace.trace_segments = 10
	trace.trace_width = 1.5
	trace.glow_boost = 1.1
	target.add_child(trace)

	var particles := CPUParticles2D.new()
	particles.z_index = -1
	particles.emitting = true
	particles.amount = 16
	particles.lifetime = 1.5
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 6.0
	particles.initial_velocity_max = 20.0
	particles.scale_amount_min = 1.3
	particles.scale_amount_max = 2.6
	particles.color = Color(pet_color.r, pet_color.g, pet_color.b, 0.6)
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	target.add_child(particles)

	var resize := func():
		if not is_instance_valid(particles) or not is_instance_valid(target):
			return
		particles.position = target.size / 2.0
		particles.emission_sphere_radius = max(target.size.x, target.size.y) * 0.42
	resize.call()
	target.resized.connect(resize)
	target.set_meta(RESIZE_META_KEY, resize)
