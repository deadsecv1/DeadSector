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

# bounds: for a panel whose root fills the whole screen (a full-rect
# Backdrop/DystopianBackground behind a smaller centered content box -
# see LorePanel/PostRaidBreakdownPanel), the drag handles need to sit on
# the visible content box's edges, not the screen's actual edges - pass
# that content box (e.g. the panel's own VBox) as bounds. Must be a
# direct child of panel, since an edge's anchors/offsets are computed
# relative to panel's rect. Omit for a panel whose root IS already the
# visible box (the common case - most panels using this).
static func apply(panel: Control, bounds: Control = null) -> void:
	var b: Control = bounds if bounds != null else panel
	var edge_color := _detect_edge_color(panel)
	_make_edge(panel, b, "top", edge_color)
	_make_edge(panel, b, "bottom", edge_color)
	_make_edge(panel, b, "left", edge_color)
	_make_edge(panel, b, "right", edge_color)

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

static func _make_edge(panel: Control, bounds: Control, side: String, edge_color: Color) -> void:
	var edge := Control.new()
	edge.set_script(DraggableEdgeScript)
	# Always drag panel as one whole cohesive unit (backdrop + content
	# together), never just bounds on its own - dragging only the inner
	# content while the backdrop/border visually stays behind looks
	# broken (confirmed against real user feedback, not just a look-and-
	# guess call). bounds only affects where the grab HITBOX sits (the
	# visible card's edges, not the full screen's), not what actually
	# moves when you drag it.
	edge.target_panel = panel
	edge.side = side
	edge.edge_color = edge_color
	edge.anchor_left = bounds.anchor_left
	edge.anchor_top = bounds.anchor_top
	edge.anchor_right = bounds.anchor_right
	edge.anchor_bottom = bounds.anchor_bottom
	match side:
		"top":
			edge.offset_left = bounds.offset_left
			edge.offset_right = bounds.offset_right
			edge.offset_top = bounds.offset_top
			edge.offset_bottom = bounds.offset_top + EDGE_THICKNESS
		"bottom":
			edge.offset_left = bounds.offset_left
			edge.offset_right = bounds.offset_right
			edge.offset_top = bounds.offset_bottom - EDGE_THICKNESS
			edge.offset_bottom = bounds.offset_bottom
		"left":
			edge.offset_top = bounds.offset_top
			edge.offset_bottom = bounds.offset_bottom
			edge.offset_left = bounds.offset_left
			edge.offset_right = bounds.offset_left + EDGE_THICKNESS
		"right":
			edge.offset_top = bounds.offset_top
			edge.offset_bottom = bounds.offset_bottom
			edge.offset_left = bounds.offset_right - EDGE_THICKNESS
			edge.offset_right = bounds.offset_right
	panel.add_child(edge)
