class_name DraggablePanel
extends RefCounted

# Makes a popup Panel draggable, but ONLY by its outer edges - a thin
# frame (drawn by DraggableEdge.gd) marks exactly where you can click
# and hold to drag, same as a real window's border. The middle of the
# panel (buttons, lists, everything else) is left completely alone -
# dragging never competes with normal clicks there.
#
# Each edge strip handles its own input directly instead of relying on
# the panel's own gui_input, since a full-rect background child
# (nearly every panel has one) would otherwise intercept every click
# before the panel itself ever sees it.

const DraggableEdgeScript := preload("res://scripts/DraggableEdge.gd")
const EDGE_THICKNESS := 5.0

static func apply(panel: Control) -> void:
	var edge_color := _detect_edge_color(panel)
	_make_edge(panel, "top", edge_color)
	_make_edge(panel, "bottom", edge_color)
	_make_edge(panel, "left", edge_color)
	_make_edge(panel, "right", edge_color)

# The frame used to just be flat black everywhere, regardless of what
# panel it was on - tries the panel's own Backdrop child (most panels
# have one) or its own "panel" stylebox override (the rest mostly use
# this instead) and darkens whichever it finds, so the frame reads as
# "this window's background, but a shade darker" instead of a fixed
# color that doesn't relate to the window it's on. Falls back to a
# plain dark neutral for the few panels that use neither.
static func _detect_edge_color(panel: Control) -> Color:
	var base := Color(0.08, 0.08, 0.08, 1.0)
	var backdrop := panel.get_node_or_null("Backdrop")
	if backdrop != null and backdrop is ColorRect:
		base = backdrop.color
	else:
		var sb := panel.get_theme_stylebox("panel")
		if sb != null and sb is StyleBoxFlat:
			base = sb.bg_color
	return Color(base.r, base.g, base.b, 1.0).darkened(0.55)

static func _make_edge(panel: Control, side: String, edge_color: Color) -> void:
	var edge := Control.new()
	edge.set_script(DraggableEdgeScript)
	edge.target_panel = panel
	edge.side = side
	edge.edge_color = edge_color
	match side:
		"top":
			edge.anchor_right = 1.0
			edge.offset_bottom = EDGE_THICKNESS
		"bottom":
			edge.anchor_top = 1.0
			edge.anchor_right = 1.0
			edge.anchor_bottom = 1.0
			edge.offset_top = -EDGE_THICKNESS
		"left":
			edge.anchor_bottom = 1.0
			edge.offset_right = EDGE_THICKNESS
		"right":
			edge.anchor_left = 1.0
			edge.anchor_right = 1.0
			edge.anchor_bottom = 1.0
			edge.offset_left = -EDGE_THICKNESS
	panel.add_child(edge)
