extends CanvasLayer

# Global chat - works from ANY scene except the opening cutscene chain,
# same "works everywhere, autoloaded" pattern Notify.gd uses for toasts.
# MMO-style docked window: a scrollable message log (simulated players
# talking - same flavor/text pools as GlobalChatPanel.gd's Social >
# Global Chat popup, reused directly rather than duplicated) sitting
# directly above a single-line input, both inside one connected panel.
# Opens on the chat keybind, stays open (log keeps updating, you can
# keep sending messages) until Escape closes the whole thing.

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

const PortraitScene := preload("res://scenes/TraderPortrait.tscn")
const SmallIconScene := preload("res://scenes/SmallIcon.tscn")
const PlayerContextMenuScript := preload("res://scripts/PlayerContextMenu.gd")
# Reuses GlobalChatPanel's own message pools (MESSAGES/MESSAGES_BRAINROT/
# MESSAGES_WITH_OTHER/etc.) instead of duplicating ~200 lines of flavor
# text - same simulated "server population," just rendered in this
# docked window instead of the Social > Global Chat popup.
const GlobalChatPanelScript := preload("res://scripts/GlobalChatPanel.gd")

const WINDOW_WIDTH := 340.0
const WINDOW_HEIGHT := 360.0
const INPUT_HEIGHT := 38.0
const MAX_LOG_ROWS := 60
const ACCENT_COLOR := Color(0.55, 0.65, 1.0, 1.0)

var chat_root: PanelContainer
var chat_input: LineEdit
var log_scroll: ScrollContainer
var log_list: VBoxContainer
var context_menu: Control

var chat_box_open: bool = false
var _chat_opened_at_ms: int = 0
var _chat_pool: Array = []
var _seeded: bool = false
var _msg_timer: float = 0.0
var _next_msg_delay: float = 3.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 96
	_build_ui()

func _build_ui() -> void:
	chat_root = PanelContainer.new()
	chat_root.anchor_left = 1.0
	chat_root.anchor_right = 1.0
	chat_root.anchor_top = 0.5
	chat_root.anchor_bottom = 0.5
	chat_root.offset_left = -(WINDOW_WIDTH + 20.0)
	chat_root.offset_right = -20.0
	chat_root.offset_bottom = 40.0
	chat_root.offset_top = 40.0 - WINDOW_HEIGHT
	chat_root.visible = false
	chat_root.mouse_filter = Control.MOUSE_FILTER_STOP
	var root_style := StyleBoxFlat.new()
	root_style.bg_color = Color(0.04, 0.05, 0.09, 0.9)
	root_style.border_color = Color(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b, 0.55)
	root_style.set_border_width_all(2)
	root_style.set_corner_radius_all(10)
	root_style.content_margin_left = 10
	root_style.content_margin_right = 10
	root_style.content_margin_top = 8
	root_style.content_margin_bottom = 8
	root_style.shadow_color = Color(0, 0, 0, 0.35)
	root_style.shadow_size = 6
	chat_root.add_theme_stylebox_override("panel", root_style)
	add_child(chat_root)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	chat_root.add_child(vbox)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 6)
	vbox.add_child(header_row)
	var header_dot := ColorRect.new()
	header_dot.custom_minimum_size = Vector2(6, 6)
	header_dot.color = Color(0.4, 0.95, 0.55, 1)
	header_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_row.add_child(header_dot)
	var header := Label.new()
	header.text = "GLOBAL CHAT"
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", ACCENT_COLOR)
	header.add_theme_constant_override("outline_size", 2)
	header.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	header_row.add_child(header)

	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b, 0.3)
	sep_style.content_margin_top = 1
	sep_style.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	log_scroll = ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(log_scroll)

	log_list = VBoxContainer.new()
	log_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_list.add_theme_constant_override("separation", 7)
	log_scroll.add_child(log_list)

	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color(0.08, 0.09, 0.15, 0.92)
	input_style.border_color = Color(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b, 0.5)
	input_style.set_border_width_all(1)
	input_style.set_corner_radius_all(6)
	input_style.content_margin_left = 8
	input_style.content_margin_right = 8

	chat_input = LineEdit.new()
	chat_input.custom_minimum_size = Vector2(0, INPUT_HEIGHT)
	chat_input.add_theme_stylebox_override("normal", input_style)
	chat_input.add_theme_stylebox_override("focus", input_style)
	chat_input.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0, 1))
	chat_input.add_theme_color_override("font_placeholder_color", Color(0.7, 0.75, 0.85, 0.65))
	chat_input.add_theme_font_size_override("font_size", 13)
	chat_input.placeholder_text = "Press Enter to send..."
	chat_input.max_length = 140
	chat_input.text_submitted.connect(_on_chat_submitted)
	vbox.add_child(chat_input)

	context_menu = Control.new()
	context_menu.anchor_right = 1.0
	context_menu.anchor_bottom = 1.0
	context_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	context_menu.set_script(PlayerContextMenuScript)
	add_child(context_menu)

func _is_cutscene_active() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path in CUTSCENE_SCENES

# Skips opening chat if some OTHER text field already has focus (a
# rename box, a search field, the Settings keybind-capture row, ...) -
# without this, Enter would get hijacked away from whatever the player
# was actually typing into.
func _other_text_field_focused() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus != null and focus != chat_input and (focus is LineEdit or focus is TextEdit)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == GameManager.get_keybind("chat"):
		if not chat_box_open and not _is_cutscene_active() and not _other_text_field_focused():
			get_viewport().set_input_as_handled()
			_open_chat_box()
	# Event-based (not polled) and specifically in _input() - this runs
	# BEFORE _unhandled_input(), so marking it handled here means every
	# panel/screen using the standard _unhandled_input Escape pattern
	# (the vast majority in this codebase) automatically never sees this
	# Escape press at all while chat is open, closing chat first with no
	# per-screen changes needed. The handful of screens that instead poll
	# Input.is_key_pressed(KEY_ESCAPE) or use their own _input() (Stash,
	# Traders, SkillTree, Settings, Hideout, the various "choice" screens,
	# ...) don't respect "handled" automatically and each check
	# GlobalChatBox.chat_box_open explicitly before acting on Escape.
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo and chat_box_open:
		get_viewport().set_input_as_handled()
		_close_chat_box()

func _process(delta: float) -> void:
	if not chat_box_open:
		return
	_msg_timer += delta
	if _msg_timer >= _next_msg_delay:
		_msg_timer = 0.0
		_next_msg_delay = randf_range(2.5, 6.0)
		_add_bot_message()

func _set_player_locked(locked: bool) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("set_input_locked"):
		player.set_input_locked(locked)

func _open_chat_box() -> void:
	chat_box_open = true
	chat_input.editable = true
	chat_input.text = ""
	chat_root.visible = true
	chat_input.grab_focus()
	_chat_opened_at_ms = Time.get_ticks_msec()
	_set_player_locked(true)
	_ensure_chat_pool()
	_seed_log()
	_msg_timer = 0.0
	_next_msg_delay = randf_range(2.0, 4.0)
	_scroll_log_to_bottom()
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
	chat_input.text = ""
	if trimmed == "":
		return
	var player_entry := {
		"name": GameManager.player_name if GameManager.player_name != "" else "You",
		"portrait": GameManager.player_portrait_id if GameManager.player_portrait_id != "" else "portrait_1",
		"rank_full_idx": GameManager.get_rank_full_index(), "is_player": true,
		"title": "", "badges": GameManager.owned_badges, "gear": GameManager.equipped_items,
		"level": GameManager.player_level, "kills": GameManager.stat_enemies_killed,
		"deaths": GameManager.stat_deaths, "pets": GameManager.owned_pet_instances.size(),
	}
	_add_log_row(player_entry, trimmed)
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("send_chat_message"):
		player.send_chat_message(trimmed)
	chat_input.grab_focus()

	# Other operatives are pretty likely to actually reply to you.
	_ensure_chat_pool()
	if not _chat_pool.is_empty() and randf() < 0.65:
		var replier: Dictionary = _chat_pool[randi() % _chat_pool.size()]
		var reply_text: String = GlobalChatPanelScript.REPLY_TO_PLAYER[randi() % GlobalChatPanelScript.REPLY_TO_PLAYER.size()]
		await get_tree().create_timer(randf_range(0.8, 2.2)).timeout
		if not chat_box_open:
			return
		_add_log_row(replier, reply_text)

func _close_chat_box() -> void:
	chat_box_open = false
	chat_root.visible = false
	chat_input.text = ""
	_set_player_locked(false)
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("cancel_chat_typing"):
		player.cancel_chat_typing()

# ------------------------------------------------------------------
# Simulated crowd chatter - reuses GlobalChatPanel's own text pools.
# ------------------------------------------------------------------

func _ensure_chat_pool() -> void:
	if _chat_pool.is_empty():
		_chat_pool = GameManager.get_ranked_leaderboard().filter(func(e): return not e.get("is_player", false))

func _seed_log() -> void:
	if _seeded or _chat_pool.is_empty():
		return
	_seeded = true
	for i in range(5):
		var sender: Dictionary = _chat_pool[randi() % _chat_pool.size()]
		_add_log_row(sender, _roll_bot_message(sender))

func _roll_bot_message(sender: Dictionary) -> String:
	if randf() < 0.12:
		var pname: String = GameManager.player_name if GameManager.player_name != "" else "operative"
		var t: String = GlobalChatPanelScript.MESSAGES_TO_PLAYER_BY_NAME[randi() % GlobalChatPanelScript.MESSAGES_TO_PLAYER_BY_NAME.size()]
		return t.replace("{player}", pname)
	var roll := randf()
	if roll < 0.3 and _chat_pool.size() > 1:
		var other: Dictionary = sender
		var tries := 0
		while other.get("name", "") == sender.get("name", "") and tries < 6:
			other = _chat_pool[randi() % _chat_pool.size()]
			tries += 1
		var t: String = GlobalChatPanelScript.MESSAGES_WITH_OTHER[randi() % GlobalChatPanelScript.MESSAGES_WITH_OTHER.size()]
		return t.replace("{other}", str(other.get("name", "someone")))
	elif roll < 0.65:
		return GlobalChatPanelScript.MESSAGES_BRAINROT[randi() % GlobalChatPanelScript.MESSAGES_BRAINROT.size()]
	else:
		return GlobalChatPanelScript.MESSAGES[randi() % GlobalChatPanelScript.MESSAGES.size()]

func _add_bot_message() -> void:
	_ensure_chat_pool()
	if _chat_pool.is_empty():
		return
	var sender: Dictionary = _chat_pool[randi() % _chat_pool.size()]
	_add_log_row(sender, _roll_bot_message(sender))
	if _chat_pool.size() > 1 and randf() < 0.45:
		var replier: Dictionary = sender
		var tries := 0
		while replier.get("name", "") == sender.get("name", "") and tries < 6:
			replier = _chat_pool[randi() % _chat_pool.size()]
			tries += 1
		await get_tree().create_timer(randf_range(0.9, 2.0)).timeout
		if not chat_box_open:
			return
		var ack: String = GlobalChatPanelScript.REPLY_ACKS[randi() % GlobalChatPanelScript.REPLY_ACKS.size()]
		_add_log_row(replier, ack)

# ------------------------------------------------------------------
# Message rows - portrait, rank icon, clickable username, level, rank
# label, then the message text. Clicking the portrait or name opens
# the same PlayerContextMenu the Social > Global Chat popup uses.
# ------------------------------------------------------------------

func _add_log_row(entry: Dictionary, text: String) -> void:
	log_list.add_child(_make_log_row(entry, text))
	while log_list.get_child_count() > MAX_LOG_ROWS:
		var oldest: Node = log_list.get_child(0)
		log_list.remove_child(oldest)
		oldest.queue_free()
	_scroll_log_to_bottom()

func _make_log_row(entry: Dictionary, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var rank_full_idx: int = int(entry.get("rank_full_idx", 0))
	var tier: Dictionary = GameManager.get_rank_tier(rank_full_idx)
	var tier_color: Color = tier.get("color", Color.WHITE)

	var portrait_btn := Button.new()
	portrait_btn.custom_minimum_size = Vector2(26, 26)
	portrait_btn.flat = true
	portrait_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	portrait_btn.pressed.connect(func(): context_menu.open_for(entry, get_viewport().get_mouse_position()))
	var portrait = PortraitScene.instantiate()
	portrait.anchor_right = 1.0
	portrait.anchor_bottom = 1.0
	portrait.trader_id = str(entry.get("portrait", "portrait_1"))
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_btn.add_child(portrait)
	row.add_child(portrait_btn)

	var rank_icon_box := Control.new()
	rank_icon_box.custom_minimum_size = Vector2(16, 16)
	rank_icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var rank_icon = SmallIconScene.instantiate()
	rank_icon.icon_type = tier.get("icon", "star")
	rank_icon.icon_bg = Color(tier_color.r * 0.3, tier_color.g * 0.3, tier_color.b * 0.3, 1)
	rank_icon.anchor_right = 1.0
	rank_icon.anchor_bottom = 1.0
	rank_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rank_icon.tooltip_text = GameManager.get_rank_display_name(rank_full_idx)
	rank_icon_box.add_child(rank_icon)
	row.add_child(rank_icon_box)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 0)
	row.add_child(text_col)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 5)
	text_col.add_child(name_row)

	var name_btn := Button.new()
	name_btn.text = str(entry.get("name", "?")) + (" (You)" if entry.get("is_player", false) else "")
	name_btn.flat = true
	name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	name_btn.add_theme_font_size_override("font_size", 12)
	name_btn.add_theme_color_override("font_color", tier_color)
	name_btn.add_theme_color_override("font_color_hover", tier_color.lightened(0.3))
	name_btn.pressed.connect(func(): context_menu.open_for(entry, get_viewport().get_mouse_position()))
	name_row.add_child(name_btn)

	var level_lbl := Label.new()
	level_lbl.text = "Lv.%d" % int(entry.get("level", 1))
	level_lbl.add_theme_font_size_override("font_size", 10)
	level_lbl.modulate = Color(0.75, 0.8, 0.9, 0.85)
	name_row.add_child(level_lbl)

	var rank_name_lbl := Label.new()
	rank_name_lbl.text = GameManager.get_rank_display_name(rank_full_idx)
	rank_name_lbl.add_theme_font_size_override("font_size", 10)
	rank_name_lbl.modulate = Color(tier_color.r, tier_color.g, tier_color.b, 0.8)
	name_row.add_child(rank_name_lbl)

	var msg_lbl := Label.new()
	msg_lbl.text = text
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg_lbl.add_theme_font_size_override("font_size", 12)
	msg_lbl.modulate = Color(1, 1, 1, 0.92)
	text_col.add_child(msg_lbl)

	return row

func _scroll_log_to_bottom() -> void:
	_do_scroll_log_to_bottom.call_deferred()

func _do_scroll_log_to_bottom() -> void:
	# One deferred call isn't always enough - a wrapped-text row sometimes
	# needs a second layout pass before the ScrollContainer's max_value
	# reflects its real final height.
	await get_tree().process_frame
	await get_tree().process_frame
	var bar: VScrollBar = log_scroll.get_v_scroll_bar()
	if bar != null:
		log_scroll.scroll_vertical = int(bar.max_value)
