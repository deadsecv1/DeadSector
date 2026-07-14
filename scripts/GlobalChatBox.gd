extends CanvasLayer

# Global chat box - works from ANY scene (Main Menu, Hideout, Traders,
# Stash, raids, Arena, Social Place, ...) except the opening cutscene
# chain, same "works everywhere, autoloaded so it survives scene
# changes" pattern Notify.gd already uses for toasts. Previously this
# lived only on the in-raid HUD (scripts/HUD.gd) - moved here so it's
# not tied to one specific scene's HUD instance.
#
# In a world scene with a "player" group node (raids, Arena, Social
# Place, Hideout), sending a message also shows a speech bubble over
# the player, same as before. In a pure UI scene (Main Menu, Traders,
# Stash, ...) there's no player to bubble over, so it just shows here
# and fades - Player.gd's chat methods are all null-guarded already.

const CUTSCENE_SCENES := [
	"res://scenes/AutoUpdater.tscn",
	"res://scenes/StudioSplash.tscn",
	"res://scenes/ClarityPartnerSplash.tscn",
	"res://scenes/SteelcrestPartnerSplash.tscn",
	"res://scenes/EngineSplash.tscn",
	"res://scenes/LegalSplash.tscn",
	"res://scenes/IntroCutscene.tscn",
	"res://scenes/LoreIntro.tscn",
	"res://scenes/CharacterCreation.tscn",
]

const CHAT_BOX_OPACITY := 0.5
const CHAT_BOX_HOLD_SECONDS := 3.0
const CHAT_BOX_FADE_SECONDS := 1.0

var chat_box: LineEdit
var chat_box_open: bool = false
var _chat_opened_at_ms: int = 0
var _chat_fade_tween: Tween = null
var _esc_was_down: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 96

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.85)
	style.border_color = Color(0.6, 0.6, 0.7, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8

	chat_box = LineEdit.new()
	chat_box.anchor_left = 1.0
	chat_box.anchor_top = 0.5
	chat_box.anchor_right = 1.0
	chat_box.anchor_bottom = 0.5
	chat_box.offset_left = -280.0
	chat_box.offset_top = -20.0
	chat_box.offset_right = -20.0
	chat_box.offset_bottom = 20.0
	chat_box.add_theme_stylebox_override("normal", style)
	chat_box.add_theme_stylebox_override("focus", style)
	chat_box.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0, 1))
	chat_box.add_theme_color_override("font_placeholder_color", Color(0.8, 0.8, 0.85, 0.7))
	chat_box.add_theme_font_size_override("font_size", 15)
	chat_box.placeholder_text = "Press Enter to send..."
	chat_box.max_length = 100
	chat_box.visible = false
	chat_box.modulate.a = CHAT_BOX_OPACITY
	chat_box.text_submitted.connect(_on_chat_submitted)
	add_child(chat_box)

func _is_cutscene_active() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path in CUTSCENE_SCENES

# Skips opening chat if some OTHER text field already has focus (a
# rename box, a search field, the Settings keybind-capture row, ...) -
# without this, Enter would get hijacked away from whatever the player
# was actually typing into.
func _other_text_field_focused() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus != null and focus != chat_box and (focus is LineEdit or focus is TextEdit)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == GameManager.get_keybind("chat"):
		if not chat_box_open and not _is_cutscene_active() and not _other_text_field_focused():
			get_viewport().set_input_as_handled()
			_open_chat_box()

func _process(_delta: float) -> void:
	var esc_down := Input.is_key_pressed(KEY_ESCAPE)
	if esc_down and not _esc_was_down and chat_box_open:
		_close_chat_box()
	_esc_was_down = esc_down

func _set_player_locked(locked: bool) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("set_input_locked"):
		player.set_input_locked(locked)

func _open_chat_box() -> void:
	if _chat_fade_tween != null and _chat_fade_tween.is_valid():
		_chat_fade_tween.kill()
	chat_box_open = true
	chat_box.editable = true
	chat_box.text = ""
	chat_box.visible = true
	chat_box.modulate.a = CHAT_BOX_OPACITY
	chat_box.grab_focus()
	_chat_opened_at_ms = Time.get_ticks_msec()
	_set_player_locked(true)
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("show_chat_typing_bubble"):
		player.show_chat_typing_bubble()

func _on_chat_submitted(text: String) -> void:
	if not chat_box_open:
		return
	# The same Enter press that opens the box (or a fast OS key-repeat of
	# it) was sometimes also landing on the now-focused LineEdit as an
	# Enter-to-submit a frame or two later - submitting an empty message
	# and closing the box again before you could type anything. A player
	# genuinely sending a real message within a quarter second of opening
	# chat isn't realistic, so this only ever blocks that false trigger.
	if Time.get_ticks_msec() - _chat_opened_at_ms < 250:
		return
	var trimmed := text.strip_edges()
	chat_box_open = false
	_set_player_locked(false)
	var player = get_tree().get_first_node_in_group("player")
	if trimmed == "":
		if player != null and player.has_method("cancel_chat_typing"):
			player.cancel_chat_typing()
		chat_box.visible = false
		chat_box.modulate.a = CHAT_BOX_OPACITY
		return
	if player != null and player.has_method("send_chat_message"):
		player.send_chat_message(trimmed)
	# Stays fully readable for CHAT_BOX_HOLD_SECONDS after actually
	# sending a message, THEN fades away.
	chat_box.editable = false
	_chat_fade_tween = create_tween()
	_chat_fade_tween.tween_interval(CHAT_BOX_HOLD_SECONDS)
	_chat_fade_tween.tween_property(chat_box, "modulate:a", 0.0, CHAT_BOX_FADE_SECONDS)
	_chat_fade_tween.tween_callback(func():
		chat_box.visible = false
		chat_box.text = ""
		chat_box.editable = true
		chat_box.modulate.a = CHAT_BOX_OPACITY
	)

# Called when Escape cancels the chat box instead of sending it.
func _close_chat_box() -> void:
	if _chat_fade_tween != null and _chat_fade_tween.is_valid():
		_chat_fade_tween.kill()
	chat_box_open = false
	chat_box.visible = false
	chat_box.text = ""
	chat_box.editable = true
	chat_box.modulate.a = CHAT_BOX_OPACITY
	_set_player_locked(false)
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("cancel_chat_typing"):
		player.cancel_chat_typing()
