class_name GodforgedAuraFX
extends RefCounted

# The Godforged tier's own look, wherever a Godforged pet's icon shows up
# (the equip doll, My Pets, the Plushies panel) - same building blocks as
# InventoryTile.gd's _setup_divine_visuals() (one tier below this one),
# just re-tinted to the pink/gold GODFORGED_GRADIENT instead of Divine's
# gold/black, so the two top tiers read as distinct at a glance.

const RotatingGradientBorderScript := preload("res://scripts/RotatingGradientBorder.gd")
const TooltipParticlesScript := preload("res://scripts/TooltipParticles.gd")
const TwinkleStarBorderScript := preload("res://scripts/TwinkleStarBorder.gd")
const GlowTraceBorderScript := preload("res://scripts/GlowTraceBorder.gd")

const GODFORGED_PINK := Color(1.0, 0.55, 0.85, 1.0)
const GODFORGED_GOLD := Color(1.0, 0.8, 0.35, 1.0)

static func apply(target: Control) -> void:
	# target's existing children (almost always the pet/item icon itself)
	# were added before this call - without re-sorting, the shimmer below
	# is a fully opaque full-rect fill that would render on top of them
	# and hide the icon completely. Push every new effect node behind
	# whatever's already there so the icon stays visible in front.
	var original_count := target.get_child_count()
	var shimmer := Control.new()
	shimmer.anchor_right = 1.0
	shimmer.anchor_bottom = 1.0
	shimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shimmer.set_script(RotatingGradientBorderScript)
	# Lower alpha than GODFORGED_PINK/GOLD's own full-strength versions
	# (used as-is below for the particles/stars/trace) - this is a
	# full-rect fill, not a small accent, so it needs its own dimmer
	# copies to stay a background behind the icon rather than a wash.
	shimmer.gradient_colors = [
		Color(GODFORGED_PINK.r, GODFORGED_PINK.g, GODFORGED_PINK.b, 0.3),
		Color(GODFORGED_GOLD.r, GODFORGED_GOLD.g, GODFORGED_GOLD.b, 0.3),
		Color(GODFORGED_PINK.r, GODFORGED_PINK.g, GODFORGED_PINK.b, 0.3),
	]
	shimmer.rotate_speed = 0.3
	target.add_child(shimmer)

	var particles := Control.new()
	particles.anchor_right = 1.0
	particles.anchor_bottom = 1.0
	particles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	particles.set_script(TooltipParticlesScript)
	particles.particle_color = GODFORGED_GOLD
	particles.intensity = 28
	target.add_child(particles)

	var stars := Control.new()
	stars.anchor_right = 1.0
	stars.anchor_bottom = 1.0
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars.set_script(TwinkleStarBorderScript)
	stars.star_color = GODFORGED_PINK
	stars.star_count = 5
	target.add_child(stars)

	var trace := Control.new()
	trace.anchor_right = 1.0
	trace.anchor_bottom = 1.0
	trace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trace.set_script(GlowTraceBorderScript)
	trace.trace_color = GODFORGED_GOLD
	trace.trace_speed = 50.0
	trace.trace_segments = 8
	target.add_child(trace)

	for i in range(original_count):
		target.move_child(target.get_child(0), target.get_child_count() - 1)
