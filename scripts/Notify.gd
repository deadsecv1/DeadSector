extends CanvasLayer

# Global left-side toast notifications (pickups, quest updates, etc.) that
# work from ANY scene, not just the in-run HUD - since quest completions
# can happen in the Hideout, at a Trader, or mid-run. Autoloaded as
# "Notify" so it persists across scene changes like Transition/Sfx.

const MAX_TOASTS := 5

var toast_container: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95
	toast_container = VBoxContainer.new()
	toast_container.anchor_left = 0.0
	toast_container.anchor_top = 0.0
	toast_container.offset_left = 16.0
	toast_container.offset_top = 54.0
	toast_container.custom_minimum_size = Vector2(360, 0)
	toast_container.add_theme_constant_override("separation", 6)
	add_child(toast_container)

	GameManager.toast_requested.connect(show_toast)
	GameManager.quest_toast_requested.connect(show_quest_toast)

func show_toast(text: String) -> void:
	_add_toast(text, Color(0.95, 0.95, 0.85, 1), 16, 2.4, 0.5)

func show_quest_toast(text: String) -> void:
	# Slightly bigger/greener and lingers longer than a normal pickup toast.
	_add_toast(text, Color(0.55, 0.9, 0.6, 1), 18, 3.2, 0.6)

func _add_toast(text: String, color: Color, font_size: int, hold: float, fade: float) -> void:
	if toast_container.get_child_count() >= MAX_TOASTS:
		toast_container.get_child(0).queue_free()

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 4)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_container.add_child(label)

	var tween := create_tween()
	tween.tween_interval(hold)
	tween.tween_property(label, "modulate:a", 0.0, fade)
	tween.tween_callback(label.queue_free)
