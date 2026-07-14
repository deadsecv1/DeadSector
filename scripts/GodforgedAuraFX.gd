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
	var shimmer := Control.new()
	shimmer.anchor_right = 1.0
	shimmer.anchor_bottom = 1.0
	shimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shimmer.set_script(RotatingGradientBorderScript)
	shimmer.gradient_colors = [GODFORGED_PINK, GODFORGED_GOLD, GODFORGED_PINK]
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
