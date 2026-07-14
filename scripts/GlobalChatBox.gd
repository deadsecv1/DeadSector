extends CanvasLayer

# Global chat - works from ANY scene except the opening cutscene chain,
# same "works everywhere, autoloaded" pattern Notify.gd uses for toasts.
# MMO-style docked window: a scrollable message log sitting directly
# above a single-line input, one connected panel, with a clickable
# channel switcher (Global/Party/Guild/Market/Recruit) in the header.
# Opens on the chat keybind; closes on Escape, on clicking outside the
# window, or a few seconds after YOU send a message.

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
# Reuses GlobalChatPanel's own Global-channel message pools (MESSAGES/
# MESSAGES_BRAINROT/MESSAGES_WITH_OTHER/etc.) instead of duplicating
# ~200 lines of flavor text - same simulated "server population," just
# rendered in this docked window instead of the Social > Global Chat
# popup. Market/Recruit are their own new pools below (no equivalent
# exists in GlobalChatPanel).
const GlobalChatPanelScript := preload("res://scripts/GlobalChatPanel.gd")

const WINDOW_WIDTH := 320.0
const WINDOW_HEIGHT := 360.0
const INPUT_HEIGHT := 38.0
const MAX_LOG_ROWS := 60
# Same blue identity as GlobalChatPanel.tscn's title (0.6, 0.8, 1.0) - this
# used to be its own unrelated gray, making the two chat surfaces look
# like different features despite being the same one.
const ACCENT_COLOR := Color(0.6, 0.8, 1.0, 1.0)
# Background-only alpha now (see root_style below) - this used to fade
# the WHOLE window including message text via chat_root.modulate, the
# only panel in the game that washed out its own text like that.
const WINDOW_BG_ALPHA := 0.94
const SEND_HOLD_SECONDS := 3.0
const SEND_FADE_SECONDS := 1.0

const CHANNELS := ["Global", "Party", "Guild", "Market", "Recruit"]
# Channels with no simulated crowd - Party because the user genuinely
# has nobody in it yet (no real multiplayer, nothing to fake here
# either), Guild because there's no guild system in this game at all.
const CHANNELS_NO_SIM := ["Party", "Guild"]

const RAID_INVITE_MAPS := [
	{"name": "Overgrowth", "scene": "res://scenes/Main.tscn"},
	{"name": "Boneclock", "scene": "res://scenes/Boneclock.tscn"},
	{"name": "Void Trench", "scene": "res://scenes/VoidTrench.tscn"},
]

var chat_root: PanelContainer
var chat_input: LineEdit
var log_scroll: ScrollContainer
var log_list: VBoxContainer
var guild_placeholder: Label
var context_menu: Control
var channel_btn: Button
var channel_menu: PanelContainer
var join_overlay: PanelContainer
var join_overlay_label: Label
var join_overlay_spinner: Control

var chat_box_open: bool = false
var _chat_opened_at_ms: int = 0
var _chat_pool: Array = []
var _current_channel: String = "Global"
var _channel_rows: Dictionary = {}
var _channel_seeded: Dictionary = {}
var _channel_recent_uses: Dictionary = {}
var _msg_timer: float = 0.0
var _next_msg_delay: float = 3.0
var _send_fade_tween: Tween = null

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
	chat_root.offset_left = -(WINDOW_WIDTH + 8.0)
	chat_root.offset_right = -8.0
	chat_root.offset_top = -(WINDOW_HEIGHT / 2.0)
	chat_root.offset_bottom = WINDOW_HEIGHT / 2.0
	chat_root.visible = false
	chat_root.mouse_filter = Control.MOUSE_FILTER_STOP
	var root_style := StyleBoxFlat.new()
	root_style.bg_color = Color(0.09, 0.09, 0.1, WINDOW_BG_ALPHA)
	root_style.border_color = Color(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b, 0.6)
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
	header_dot.color = ACCENT_COLOR
	header_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_row.add_child(header_dot)

	channel_btn = Button.new()
	channel_btn.text = "GLOBAL CHAT  ▾"
	channel_btn.flat = true
	channel_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	channel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	channel_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	channel_btn.add_theme_font_size_override("font_size", 13)
	channel_btn.add_theme_color_override("font_color", ACCENT_COLOR)
	channel_btn.add_theme_color_override("font_color_hover", ACCENT_COLOR.lightened(0.3))
	channel_btn.add_theme_constant_override("outline_size", 2)
	channel_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	channel_btn.pressed.connect(_toggle_channel_menu)
	header_row.add_child(channel_btn)

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

	guild_placeholder = Label.new()
	guild_placeholder.text = "Create or join a guild to chat here."
	guild_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guild_placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD
	guild_placeholder.add_theme_font_size_override("font_size", 12)
	guild_placeholder.modulate = Color(1, 1, 1, 0.6)
	guild_placeholder.visible = false
	guild_placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	guild_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vbox.add_child(guild_placeholder)

	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color(0.13, 0.13, 0.14, 1.0)
	input_style.border_color = Color(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b, 0.55)
	input_style.set_border_width_all(1)
	input_style.set_corner_radius_all(6)
	input_style.content_margin_left = 8
	input_style.content_margin_right = 8

	chat_input = LineEdit.new()
	chat_input.custom_minimum_size = Vector2(0, INPUT_HEIGHT)
	chat_input.add_theme_stylebox_override("normal", input_style)
	chat_input.add_theme_stylebox_override("focus", input_style)
	chat_input.add_theme_color_override("font_color", Color(0.95, 0.95, 0.96, 1))
	chat_input.add_theme_color_override("font_placeholder_color", Color(0.72, 0.72, 0.75, 0.65))
	chat_input.add_theme_font_size_override("font_size", 12)
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

	_build_channel_menu()
	_build_join_overlay()

func _build_channel_menu() -> void:
	channel_menu = PanelContainer.new()
	channel_menu.visible = false
	channel_menu.z_index = 200
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.11, 0.98)
	sb.border_color = Color(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(4)
	channel_menu.add_theme_stylebox_override("panel", sb)
	add_child(channel_menu)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	channel_menu.add_child(vbox)
	for ch in CHANNELS:
		var btn := Button.new()
		btn.text = ch
		btn.flat = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(140, 28)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(func(): _select_channel(ch))
		vbox.add_child(btn)

func _build_join_overlay() -> void:
	join_overlay = PanelContainer.new()
	join_overlay.visible = false
	join_overlay.z_index = 250
	join_overlay.anchor_right = 1.0
	join_overlay.anchor_bottom = 1.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.07, 0.95)
	sb.set_corner_radius_all(10)
	join_overlay.add_theme_stylebox_override("panel", sb)
	chat_root.add_child(join_overlay)

	# Same "orbiting dot" spinner technique as ArenaMatchmaking.gd's
	# equivalent wait beat - this used to be a plain static label with
	# no motion at all for the whole countdown.
	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	join_overlay.add_child(vbox)

	join_overlay_spinner = Control.new()
	join_overlay_spinner.custom_minimum_size = Vector2(0, 32)
	join_overlay_spinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	join_overlay_spinner.draw.connect(_draw_join_spinner)
	vbox.add_child(join_overlay_spinner)

	join_overlay_label = Label.new()
	join_overlay_label.text = "Joining game in 3..."
	join_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	join_overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	join_overlay_label.add_theme_font_size_override("font_size", 18)
	join_overlay_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 1))
	vbox.add_child(join_overlay_label)

func _draw_join_spinner() -> void:
	var t := Time.get_ticks_msec() * 0.001
	var center: Vector2 = join_overlay_spinner.size / 2.0
	var radius := 13.0
	var segments := 8
	for i in range(segments):
		var ang: float = t * 3.2 + TAU * float(i) / float(segments)
		var alpha: float = 0.15 + 0.75 * (float(i) / float(segments))
		var pos := center + Vector2(cos(ang), sin(ang)) * radius
		join_overlay_spinner.draw_circle(pos, 3.2, Color(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b, alpha))

# ------------------------------------------------------------------
# Channel switching
# ------------------------------------------------------------------

func _toggle_channel_menu() -> void:
	channel_menu.visible = not channel_menu.visible
	if channel_menu.visible:
		channel_menu.position = channel_btn.global_position + Vector2(0, channel_btn.size.y + 4.0)

func _select_channel(ch: String) -> void:
	channel_menu.visible = false
	if ch == _current_channel:
		return
	_current_channel = ch
	channel_btn.text = "%s CHAT  ▾" % ch.to_upper()
	var locked: bool = ch in CHANNELS_NO_SIM and ch == "Guild"
	guild_placeholder.visible = locked
	log_scroll.visible = not locked
	chat_input.editable = not locked
	chat_input.placeholder_text = "Guilds aren't available yet..." if locked else "Press Enter to send..."
	_rebuild_log_view()
	if not (ch in CHANNELS_NO_SIM):
		_ensure_chat_pool()
		_seed_channel(ch)
	_msg_timer = 0.0
	_next_msg_delay = randf_range(2.0, 4.0)

func _rebuild_log_view() -> void:
	for c in log_list.get_children():
		log_list.remove_child(c)
	for row in _channel_rows.get(_current_channel, []):
		log_list.add_child(row)
	_scroll_log_to_bottom()

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
	if event is InputEventMouseButton and event.pressed and chat_box_open:
		var pos: Vector2 = event.global_position
		var in_chat: bool = chat_root.get_global_rect().has_point(pos)
		var in_menu: bool = channel_menu.visible and channel_menu.get_global_rect().has_point(pos)
		if not in_chat and not in_menu:
			_close_chat_box()
		elif channel_menu.visible and not in_menu:
			channel_menu.visible = false

func _process(delta: float) -> void:
	if join_overlay.visible:
		join_overlay_spinner.queue_redraw()
	if not chat_box_open or _current_channel in CHANNELS_NO_SIM:
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
	if _send_fade_tween != null and _send_fade_tween.is_valid():
		_send_fade_tween.kill()
	chat_box_open = true
	chat_input.editable = _current_channel != "Guild"
	chat_input.text = ""
	chat_root.visible = true
	chat_root.modulate.a = 1.0
	chat_input.grab_focus()
	_chat_opened_at_ms = Time.get_ticks_msec()
	_set_player_locked(true)
	if not (_current_channel in CHANNELS_NO_SIM):
		_ensure_chat_pool()
		_seed_channel(_current_channel)
	_msg_timer = 0.0
	_next_msg_delay = randf_range(2.0, 4.0)
	_scroll_log_to_bottom()
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("show_chat_typing_bubble"):
		player.show_chat_typing_bubble()

func _on_chat_submitted(text: String) -> void:
	if not chat_box_open or not chat_input.editable:
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
	Sfx.play_menu_confirm()
	var player_entry := {
		"name": GameManager.player_name if GameManager.player_name != "" else "You",
		"portrait": GameManager.player_portrait_id if GameManager.player_portrait_id != "" else "portrait_1",
		"rank_full_idx": GameManager.get_rank_full_index(), "is_player": true,
		"title": "", "badges": GameManager.owned_badges, "gear": GameManager.equipped_items,
		"level": GameManager.player_level, "kills": GameManager.stat_enemies_killed,
		"deaths": GameManager.stat_deaths, "pets": GameManager.owned_pet_instances.size(),
	}
	_add_log_row(_current_channel, player_entry, trimmed)
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("send_chat_message"):
		player.send_chat_message(trimmed)
	chat_input.grab_focus()
	_start_send_fade()

	# Other operatives are pretty likely to actually reply to you.
	if not (_current_channel in CHANNELS_NO_SIM):
		_ensure_chat_pool()
		if not _chat_pool.is_empty() and randf() < 0.65:
			var replier: Dictionary = _chat_pool[randi() % _chat_pool.size()]
			var reply_text: String = GlobalChatPanelScript.REPLY_TO_PLAYER[randi() % GlobalChatPanelScript.REPLY_TO_PLAYER.size()]
			var reply_channel := _current_channel
			await get_tree().create_timer(randf_range(0.8, 2.2)).timeout
			if not chat_box_open or _current_channel != reply_channel:
				return
			_add_log_row(reply_channel, replier, reply_text)

# Holds the window fully visible for SEND_HOLD_SECONDS after the player
# sends a message, then fades it away - restarted (not stacked) if
# another message is sent before the previous hold/fade finishes.
# Ambient bot chatter does NOT touch this timer, only the player's own
# sends do, per the explicit "when I send a message" request.
func _start_send_fade() -> void:
	if _send_fade_tween != null and _send_fade_tween.is_valid():
		_send_fade_tween.kill()
	_send_fade_tween = create_tween()
	_send_fade_tween.tween_interval(SEND_HOLD_SECONDS)
	_send_fade_tween.tween_property(chat_root, "modulate:a", 0.0, SEND_FADE_SECONDS)
	_send_fade_tween.tween_callback(_close_chat_box)

func _close_chat_box() -> void:
	if _send_fade_tween != null and _send_fade_tween.is_valid():
		_send_fade_tween.kill()
	channel_menu.visible = false
	chat_box_open = false
	chat_input.text = ""
	_set_player_locked(false)
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("cancel_chat_typing"):
		player.cancel_chat_typing()
	# A quick fade instead of an instant snap - Escape/click-away used to
	# hard-cut while the auto-close-after-send path faded gracefully;
	# this brings both up to the same standard.
	var tw := create_tween()
	tw.tween_property(chat_root, "modulate:a", 0.0, 0.12)
	tw.tween_callback(func():
		chat_root.visible = false
		chat_root.modulate.a = 1.0
	)

# ------------------------------------------------------------------
# Simulated crowd chatter
# ------------------------------------------------------------------

func _ensure_chat_pool() -> void:
	if _chat_pool.is_empty():
		_chat_pool = GameManager.get_ranked_leaderboard().filter(func(e): return not e.get("is_player", false))

func _seed_channel(ch: String) -> void:
	if _channel_seeded.get(ch, false) or _chat_pool.is_empty():
		return
	_channel_seeded[ch] = true
	for i in range(5):
		var sender: Dictionary = _chat_pool[randi() % _chat_pool.size()]
		_add_channel_entry(ch, sender)

# Single shared path for "one more line of chatter in this channel" -
# used by both the initial seed burst and the ongoing ambient timer, so
# Recruit's invite-card roll (and any future per-channel special case)
# only has to be handled in one place instead of being duplicated (and
# drifting out of sync) between seeding and steady-state chatter.
func _add_channel_entry(ch: String, sender: Dictionary) -> void:
	if ch == "Recruit" and randf() < 0.3:
		_add_invite_row(ch, sender)
		return
	_add_log_row(ch, sender, _roll_message(ch, sender))

func _roll_message(ch: String, sender: Dictionary) -> String:
	match ch:
		"Market":
			return _roll_no_repeat(ch, MARKET_MESSAGES)
		"Recruit":
			return _roll_no_repeat(ch, RECRUIT_MESSAGES)
		_:
			return _roll_global_message(sender)

func _roll_no_repeat(ch: String, pool: Array) -> String:
	var used: Dictionary = _channel_recent_uses.get(ch, {})
	for attempt in range(8):
		var candidate: String = pool[randi() % pool.size()]
		var now_ms: int = Time.get_ticks_msec()
		var last_used: int = int(used.get(candidate, -999999))
		if float(now_ms - last_used) / 1000.0 >= 45.0:
			used[candidate] = now_ms
			_channel_recent_uses[ch] = used
			return candidate
	return pool[randi() % pool.size()]

func _roll_global_message(sender: Dictionary) -> String:
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
		return _roll_no_repeat("Global", GlobalChatPanelScript.MESSAGES_BRAINROT)
	else:
		return _roll_no_repeat("Global", GlobalChatPanelScript.MESSAGES)

func _add_bot_message() -> void:
	_ensure_chat_pool()
	if _chat_pool.is_empty():
		return
	var ch := _current_channel
	var sender: Dictionary = _chat_pool[randi() % _chat_pool.size()]
	_add_channel_entry(ch, sender)
	if ch == "Global" and _chat_pool.size() > 1 and randf() < 0.45:
		var replier: Dictionary = sender
		var tries := 0
		while replier.get("name", "") == sender.get("name", "") and tries < 6:
			replier = _chat_pool[randi() % _chat_pool.size()]
			tries += 1
		await get_tree().create_timer(randf_range(0.9, 2.0)).timeout
		if not chat_box_open or _current_channel != ch:
			return
		var ack: String = GlobalChatPanelScript.REPLY_ACKS[randi() % GlobalChatPanelScript.REPLY_ACKS.size()]
		_add_log_row(ch, replier, ack)

# ------------------------------------------------------------------
# Market / Recruit flavor text
# ------------------------------------------------------------------

const MARKET_MESSAGES := [
	"WTS legendary chestplate, 400k or best offer",
	"anyone buying heavy ammo in bulk rn, got way too much",
	"lowballers gonna lowball but that railgun is worth way more than 50k lol",
	"WTB a decent sniper, budget is like 100k",
	"is 200k fair for a mythic backpack or am i getting robbed",
	"selling loot bags cheap, need rubles fast",
	"anyone trading skins? got a spare inferno skin nobody wants",
	"quick sell prices are actual robbery ngl, market's way better",
	"WTT epic helmet for epic chestplate, same rarity swap",
	"who's got spare artifacts, paying well",
	"just sold my exotic for way less than i wanted, lesson learned",
	"stop lowballing every single listing i post challenge",
	"looking for a legit trade, not another 10k offer on a 100k item",
	"anyone selling attachments, need a scope for my sniper",
	"got 3 loot bags for sale, common tier but still worth something",
	"multiversal item just dropped for me, not selling but had to flex",
	"is the flea market tax worth it or should i just trade direct",
	"WTB alloys, got rubles ready",
	"selling a stack of medium ammo, dm me",
	"why do people list junk for legendary prices smh",
	"finally got a fair trade done, appreciate the honest sellers out there",
	"anyone got a spare backpack with loot_sense, willing to pay well",
	"flea market's been dead today, nobody's buying",
	"just flipped a common item into a small fortune, market's wild",
	"selling my whole stash, doing a full inventory reset",
	"WTB rare ring, any stat type, just need the slot filled",
	"that price is criminal, i've seen better deals from a scav",
	"anyone want to trade eggs, got a spare rare tier",
	"posted a legendary weapon, getting nothing but lowballs so far",
	"market prices this reset are actually insane compared to last one",
]

const RECRUIT_MESSAGES := [
	"LFG normal raid, got decent gear, just need one more",
	"anyone recruiting for void trench, im down whenever",
	"looking for a squad, i run medium armor and a rifle",
	"solo queue is rough, someone take me on a raid please",
	"got a full loadout ready, just need people to actually raid with",
	"anyone else trying to farm boneclock tonight",
	"team up for arena? i run a marksman-style loadout",
	"need one more for a spectral tide run, bring your own gear",
	"who's trying to hit overgrowth, i know a good extraction route",
	"looking for consistent raid partners, not just one-off runs",
	"my gear's mid but i pull my weight, LFG",
	"recruiting for a void trench push, bring heavy ammo",
	"anyone want to arena queue together, i can flex any loadout",
	"need backup for boneclock, that place is no joke solo",
	"LFG spectral tide, almost done with this event's rewards",
	"squad up for overgrowth, i know where the good loot spawns",
	"looking for a mic'd up team, tired of silent runs",
	"anyone free right now for a quick raid, in and out",
	"i've got a sniper build, need someone to draw aggro",
	"forming a team for arena ranked, need 2 more",
	"who wants to try void trench blind, never been but heard its good loot",
	"LFG anything honestly, just want to play with people",
	"looking for a scav run partner, low stakes just for fun",
	"need a medic-style loadout on my team, i run pure damage",
	"anyone recruiting right now or should i just solo queue",
]

func _roll_recruit_invite() -> Dictionary:
	var map: Dictionary = RAID_INVITE_MAPS[randi() % RAID_INVITE_MAPS.size()]
	return {
		"map_name": map.get("name", "Overgrowth"),
		"map_scene": map.get("scene", "res://scenes/Main.tscn"),
		"level_req": [1, 5, 10, 15, 20, 25][randi() % 6],
		"mic_req": randf() < 0.5,
		"party_size": randi_range(2, 4),
	}

# ------------------------------------------------------------------
# Message rows
# ------------------------------------------------------------------

func _add_log_row(ch: String, entry: Dictionary, text: String) -> void:
	if text == "":
		return
	var row := _make_log_row(entry, text)
	_append_row(ch, row)

func _append_row(ch: String, row: Control) -> void:
	if not _channel_rows.has(ch):
		_channel_rows[ch] = []
	var rows: Array = _channel_rows[ch]
	rows.append(row)
	while rows.size() > MAX_LOG_ROWS:
		var oldest: Control = rows.pop_front()
		if oldest.get_parent() != null:
			oldest.get_parent().remove_child(oldest)
		oldest.queue_free()
	if ch == _current_channel:
		log_list.add_child(row)
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

# A Recruit-channel "invite card" - same header row as a normal message
# (portrait/name/level/rank), but the body is a small bordered card
# with the map/level/mic requirements and a Join button instead of
# plain text.
func _add_invite_row(ch: String, entry: Dictionary) -> void:
	var invite := _roll_recruit_invite()
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 3)

	var header := _make_log_row(entry, "is looking for a group:")
	row.add_child(header)

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.14, 0.16, 0.95)
	sb.border_color = Color(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", sb)
	row.add_child(card)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 4)
	card.add_child(card_vbox)

	var title_lbl := Label.new()
	title_lbl.text = "Join %s" % str(invite.get("map_name", "Overgrowth"))
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 1))
	card_vbox.add_child(title_lbl)

	var req_lbl := Label.new()
	var mic_text: String = "Mic required" if invite.get("mic_req", false) else "Mic optional"
	req_lbl.text = "Lvl %d+ required  •  %s  •  %d players" % [int(invite.get("level_req", 1)), mic_text, int(invite.get("party_size", 2))]
	req_lbl.add_theme_font_size_override("font_size", 10)
	req_lbl.modulate = Color(1, 1, 1, 0.7)
	card_vbox.add_child(req_lbl)

	var join_btn := Button.new()
	join_btn.text = "Join"
	join_btn.custom_minimum_size = Vector2(0, 26)
	join_btn.add_theme_font_size_override("font_size", 12)
	join_btn.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 1))
	join_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var join_btn_style := StyleBoxFlat.new()
	join_btn_style.bg_color = Color(0.15, 0.22, 0.32, 0.9)
	join_btn_style.border_color = Color(0.6, 0.8, 1.0, 0.8)
	join_btn_style.set_border_width_all(1)
	join_btn_style.set_corner_radius_all(5)
	join_btn.add_theme_stylebox_override("normal", join_btn_style)
	join_btn.add_theme_stylebox_override("hover", join_btn_style)
	join_btn.pressed.connect(func(): _start_recruit_join(invite))
	card_vbox.add_child(join_btn)

	_append_row(ch, row)

# ------------------------------------------------------------------
# Recruit join flow - fills a simulated party, counts down, then
# loads the invite's map. See TASK 16 (RaidParty spawn on the map
# side) for how the party actually shows up and follows the player.
# ------------------------------------------------------------------

func _start_recruit_join(invite: Dictionary) -> void:
	_ensure_chat_pool()
	join_overlay.visible = true
	join_overlay_label.text = "Filling party..."
	await get_tree().create_timer(randf_range(0.8, 1.6)).timeout
	if not is_instance_valid(join_overlay):
		return
	# Closing chat (or any scene change already in flight) doubles as
	# canceling the join - checked after every wait below, not just the
	# final one, so dismissing early during "Filling party..." stops this
	# immediately instead of continuing to visibly count down regardless.
	if not chat_box_open or Transition._is_transitioning:
		join_overlay.visible = false
		return
	for i in [3, 2, 1]:
		join_overlay_label.text = "Joining game in %d..." % i
		await get_tree().create_timer(1.0).timeout
		if not chat_box_open or Transition._is_transitioning:
			join_overlay.visible = false
			return
	# Last-resort safety net for the sliver of time between the loop above
	# finishing and here - without this, pending_raid_party could leak into
	# a later, unrelated raid the player starts some other way entirely.
	if not chat_box_open or Transition._is_transitioning:
		join_overlay.visible = false
		return
	var party_size: int = int(invite.get("party_size", 2)) - 1
	var party_members: Array = []
	for i in range(party_size):
		if not _chat_pool.is_empty():
			party_members.append(_chat_pool[randi() % _chat_pool.size()])
	GameManager.pending_raid_party = party_members
	_close_chat_box()
	join_overlay.visible = false
	Transition.change_scene(str(invite.get("map_scene", "res://scenes/Main.tscn")))

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
