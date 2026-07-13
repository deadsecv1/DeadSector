extends Control

# One thin strip along a single edge of a draggable window - handles
# its own drag input directly (rather than relying on the window's
# gui_input, which can get blocked by a full-rect background child
# intercepting clicks first) and draws the line that marks it as the
# part of the window you can actually grab.

var target_panel: Control = null
var side: String = ""
var edge_color: Color = Color(0.08, 0.08, 0.08, 0.85)
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

const CORNER_RADIUS := 4

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	gui_input.connect(_on_input)

func _on_input(event: InputEvent) -> void:
	if target_panel == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_offset = target_panel.position - target_panel.get_global_mouse_position()
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		target_panel.position = target_panel.get_global_mouse_position() + _drag_offset

func _draw() -> void:
	# Only the two corners that land on the window's ACTUAL corner get
	# rounded - the other two sit against the flat middle of the next
	# edge over and would just look like a notch if rounded too.
	var sb := StyleBoxFlat.new()
	sb.bg_color = edge_color
	sb.corner_radius_top_left = CORNER_RADIUS if side == "top" or side == "left" else 0
	sb.corner_radius_top_right = CORNER_RADIUS if side == "top" or side == "right" else 0
	sb.corner_radius_bottom_left = CORNER_RADIUS if side == "bottom" or side == "left" else 0
	sb.corner_radius_bottom_right = CORNER_RADIUS if side == "bottom" or side == "right" else 0
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
