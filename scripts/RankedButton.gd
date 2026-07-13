extends Button

# A small button overlapping the top-right corner of Play. Leads into
# the same PMC/Scav -> deploy flow as regular Play, but detours through
# RankPreview.tscn first (the rank ladder screen) and flags the run as
# ranked so the Searching screen can call it out.

const TwinkleStarBorderScript := preload("res://scripts/TwinkleStarBorder.gd")
const REQUIRED_LEVEL := 5

var glow_alpha: float = 0.0

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_on_hover_start)
	mouse_exited.connect(_on_hover_end)
	pressed.connect(_on_pressed)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.25, 0.2, 0.05, 0.85)
	sb.border_color = Color(0.95, 0.8, 0.3, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	add_theme_stylebox_override("normal", sb)
	var hover_sb := sb.duplicate()
	hover_sb.bg_color = Color(0.35, 0.28, 0.08, 0.95)
	add_theme_stylebox_override("hover", hover_sb)
	add_theme_stylebox_override("pressed", hover_sb)

	var stars := Control.new()
	stars.anchor_right = 1.0
	stars.anchor_bottom = 1.0
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars.set_script(TwinkleStarBorderScript)
	stars.star_color = Color(1.0, 0.9, 0.5, 1.0)
	stars.star_count = 4
	stars.min_size = 2.0
	stars.max_size = 3.5
	add_child(stars)

	_update_lock_state()

func _update_lock_state() -> void:
	var locked: bool = GameManager.player_level < REQUIRED_LEVEL
	modulate = Color(1, 1, 1, 0.4) if locked else Color(1, 1, 1, 1)
	tooltip_text = ("Ranked unlocks at Level %d" % REQUIRED_LEVEL) if locked else ""

func _on_hover_start() -> void:
	# A sword-swing sting instead of the standard coin-chime hover sound -
	# this button is the door into PvP, so it should sound like a fight is
	# about to start, not like every other menu button.
	Sfx.play_sword_swing()
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.08, 1.08), 0.12).set_trans(Tween.TRANS_QUAD)

func _on_hover_end() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_QUAD)

func _on_pressed() -> void:
	if GameManager.player_level < REQUIRED_LEVEL:
		GameManager.toast_requested.emit("Ranked unlocks at Level %d - you're Level %d" % [REQUIRED_LEVEL, GameManager.player_level])
		return
	Transition.change_scene("res://scenes/RankPreview.tscn")
