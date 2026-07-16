extends CanvasLayer

@onready var stats_label: Label = $HudPanel/StatsLabel
@onready var loot_label: RichTextLabel = $HudPanel/LootLabel
@onready var message_label: Label = $MessageLabel
@onready var inventory_panel: Panel = $InventoryPanel
@onready var pause_menu: Panel = $PauseMenu
@onready var attachments_panel: Panel = $AttachmentsPanel
@onready var wandering_trader_panel: Panel = $WanderingTraderPanel
@onready var scope_overlay = $ScopeOverlay
@onready var night_vision_overlay: ColorRect = $NightVisionOverlay
@onready var stun_flash: ColorRect = $StunFlash
@onready var hit_flash: ColorRect = $HitFlash
const HitVignetteShader := preload("res://shaders/HitVignette.gdshader")
var _hit_flash_mat: ShaderMaterial
var _last_known_health: int = -1
@onready var ammo_label: Label = $AmmoLabel
@onready var reload_prompt: Label = $ReloadPrompt
@onready var time_label: Label = $TimeLabel
@onready var quest_panel: Control = $QuestPanel
@onready var quest_list: VBoxContainer = $QuestPanel/QuestList

var _has_active_quests: bool = false

func _update_quest_panel_visibility() -> void:
	quest_panel.visible = _has_active_quests and not inventory_panel.visible

var _wants_reload_prompt: bool = false

# Diegetic ammo peek: rather than a permanently-visible counter, the
# ammo readout pops fully opaque on every ammo_changed event (fire,
# reload, weapon swap) and fades back out a couple seconds after the
# last one - reads as "checking your mag" instead of a HUD element
# that's just always sitting there.
const AMMO_PEEK_DURATION := 2.0
var _ammo_peek_seconds_left: float = 0.0

func _update_reload_prompt_visibility() -> void:
	reload_prompt.visible = _wants_reload_prompt and not inventory_panel.visible
@onready var item_context_menu = $ItemContextMenu
@onready var tag_edit_panel = $TagEditPanel
@onready var inspect_panel = $InspectPanel
@onready var skins_panel = $SkinsPanel
@onready var open_bag_panel = $OpenLootBagPanel
@onready var vicinity_panel = $InventoryPanel/VBox/Panels/VicinityPanel

var tab_was_down: bool = false
var esc_was_down: bool = false
var cursor_is_default: bool = false
# Snapshot of tag_edit_panel.visible taken at the END of the previous
# frame - see the Escape handling below for why this has to be the OLD
# value, not a live re-check.
var _tag_edit_was_open_at_frame_start: bool = false
# Lets a parent scene with its own scene-specific panels HUD has no way
# to know about (e.g. TheGrid's Lilly panel, opened via Escape since
# there's no in-map NPC there anymore) suppress this frame's Escape
# handling - same idea as the chat_box_open/tag_edit_panel checks below,
# just for state that lives outside this script. One-shot: the parent's
# own _unhandled_input sets this (input phase, fires before this script's
# polling _process() this same frame), consumed and cleared below.
var suppress_escape_this_frame: bool = false

# Only re-format the raid timer label when the displayed mm:ss actually
# changes, instead of every frame regardless (~60x/sec for a value that
# visibly changes once a second) - same guard already used for the
# currency readout above.
var _last_time_m: int = -1
var _last_time_s: int = -1

# Cached instead of re-queried via get_first_node_in_group every _process
# frame - the player doesn't change mid-raid.
var _cached_player: Node = null

# Only re-format/re-parse the BBCode currency label when a value actually
# changed, instead of every frame regardless.
var _last_rubles: int = -1
var _last_junk: int = -1
var _last_artifacts: int = -1
var _last_alloys: int = -1

func _ready() -> void:
	# The Pause Menu is about to actually pause the tree - this HUD's own
	# _process() (which polls Tab/Esc, including the input that closes the
	# menu again) and the menu itself both need to keep running regardless,
	# or opening Pause would freeze the only way to ever close it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	message_label.visible = false
	inventory_panel.visible = false
	GameManager.inventory_tab_open = false
	pause_menu.visible = false
	attachments_panel.visible = false
	wandering_trader_panel.visible = false
	item_context_menu.visible = false
	inspect_panel.visible = false
	skins_panel.visible = false
	open_bag_panel.visible = false
	stats_label.visible = false
	ammo_label.modulate.a = 0.0
	_hit_flash_mat = ShaderMaterial.new()
	_hit_flash_mat.shader = HitVignetteShader
	_hit_flash_mat.set_shader_parameter("intensity", 0.0)
	hit_flash.material = _hit_flash_mat
	_refresh_quest_label()
	GameManager.quest_state_changed.connect(_refresh_quest_label)
	pause_menu.resume_requested.connect(_close_pause)
	pause_menu.exit_requested.connect(_on_exit_requested)
	GameManager.run_ended.connect(_on_run_ended)
	GameManager.search_started.connect(_on_search_started)
	GameManager.search_finished.connect(_on_search_finished)
	inventory_panel.item_context_menu_requested.connect(_open_context_menu)
	inventory_panel.equipped_context_menu_requested.connect(func(slot_name, item, pos): item_context_menu.open_for_equipped(slot_name, item, pos))
	inventory_panel.empty_slot_clicked.connect(func(slot_name):
		GameManager.toast_requested.emit(inventory_panel.EMPTY_SLOT_HINT.get(slot_name, "Nothing equipped here yet"))
	)
	vicinity_panel.item_context_menu_requested.connect(_open_context_menu)
	item_context_menu.inspect_requested.connect(func(item): inspect_panel.open_for(item))
	item_context_menu.attachments_requested.connect(_open_attachments)
	item_context_menu.skins_requested.connect(func(item): skins_panel.open_for(item))
	item_context_menu.open_bag_requested.connect(func(index, source, item): open_bag_panel.open_for(index, source, item))
	item_context_menu.rotate_requested.connect(_on_rotate_requested)
	item_context_menu.tag_requested.connect(func(index, source, item): tag_edit_panel.open_for(index, source, item))
	tag_edit_panel.closed.connect(func(): tag_edit_panel.visible = false)
	tag_edit_panel.saved.connect(inventory_panel.refresh)
	item_context_menu.equip_requested.connect(func(index, source, _item):
		if source == "carried":
			GameManager.equip_from_carried(index)
		elif source == "vicinity":
			GameManager.vicinity_equip(index)
		inventory_panel.refresh()
	)
	item_context_menu.unequip_requested.connect(func(slot_name: String):
		GameManager.unequip_to_carried(slot_name)
		inventory_panel.refresh()
	)
	item_context_menu.use_requested.connect(func(index, _source, _item):
		var removed := GameManager.consume_carried_item(index)
		if not removed.is_empty():
			var p = get_tree().get_first_node_in_group("player")
			if p != null and is_instance_valid(p):
				p.apply_consumable(removed)
		inventory_panel.refresh()
	)
	open_bag_panel.closed.connect(func(): open_bag_panel.visible = false)
	open_bag_panel.bag_opened.connect(inventory_panel.refresh)
	inspect_panel.closed.connect(func(): inspect_panel.visible = false)
	skins_panel.closed.connect(func(): skins_panel.visible = false)
	attachments_panel.closed.connect(_close_attachments)
	wandering_trader_panel.closed.connect(func(): wandering_trader_panel.visible = false; _set_player_locked(false))

func _refresh_quest_label() -> void:
	for c in quest_list.get_children():
		quest_list.remove_child(c)
		c.queue_free()
	var keys := GameManager.active_quest_keys()
	_has_active_quests = not keys.is_empty()
	_update_quest_panel_visibility()
	for key in keys:
		var data: Dictionary = GameManager.QUEST_DATA.get(key, {})
		if data.is_empty():
			continue
		var status: String = GameManager.quest_status_for(key)

		var box := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.07, 0.03, 0.8)
		sb.border_color = Color(1.0, 0.85, 0.4, 0.75) if status == "ready" else Color(0.75, 0.65, 0.3, 0.45)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(5)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 5
		sb.content_margin_bottom = 5
		box.add_theme_stylebox_override("panel", sb)

		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 1)
		box.add_child(entry)

		var title_lbl := Label.new()
		title_lbl.text = ("[Ready to turn in] " if status == "ready" else "") + str(data.get("title", ""))
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		title_lbl.add_theme_font_size_override("font_size", 13)
		title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 1) if status == "ready" else Color(0.95, 0.85, 0.4, 1))
		entry.add_child(title_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = str(data.get("desc", ""))
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		entry.add_child(desc_lbl)

		quest_list.add_child(box)

func _open_context_menu(index: int, source: String, item: Dictionary, at_position: Vector2) -> void:
	item_context_menu.open_for(index, source, item, at_position)

func _on_rotate_requested(index: int, source: String, _item: Dictionary) -> void:
	if GameManager.rotate_item(index, source):
		inventory_panel.refresh()
	else:
		GameManager.toast_requested.emit("Can't rotate here - not enough room")

func open_wandering_trader(trader: Node) -> void:
	wandering_trader_panel.open_for(trader)
	_set_player_locked(true)

func _open_attachments(index: int, source: String, _item: Dictionary) -> void:
	attachments_panel.open_for(index, source)

func _close_attachments() -> void:
	attachments_panel.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == GameManager.get_keybind("inventory") and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if GameManager.rubles != _last_rubles or GameManager.junk != _last_junk or GameManager.artifacts != _last_artifacts or GameManager.alloys != _last_alloys:
		_last_rubles = GameManager.rubles
		_last_junk = GameManager.junk
		_last_artifacts = GameManager.artifacts
		_last_alloys = GameManager.alloys
		loot_label.text = "[color=#d4a5a5]Rubles[/color] [b]%d[/b]    [color=#a5c9d4]Junk[/color] [b]%d[/b]    [color=#c9a5d4]Artifacts[/color] [b]%d[/b]    [color=#a5d4a8]Alloys[/color] [b]%d[/b]" % [_last_rubles, _last_junk, _last_artifacts, _last_alloys]

	if reload_prompt.visible:
		var mouse_pos := get_viewport().get_mouse_position()
		reload_prompt.position = mouse_pos + Vector2(18, 18)

	if _ammo_peek_seconds_left > 0.0:
		_ammo_peek_seconds_left -= delta
		if _ammo_peek_seconds_left <= 0.0:
			var tw := create_tween()
			tw.tween_property(ammo_label, "modulate:a", 0.0, 0.4)

	if _cached_player == null or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player")
	scope_overlay.visible = _cached_player != null and _cached_player.get("is_scoped") == true
	night_vision_overlay.visible = _cached_player != null and _cached_player.get("nightvision_active") == true

	# Polled (not event-based) so it behaves the same reliable way as the
	# player's WASD movement checks.
	var tab_down := GameManager.is_action_pressed("inventory")
	if tab_down and not tab_was_down and not pause_menu.visible:
		inventory_panel.visible = not inventory_panel.visible
		if inventory_panel.visible:
			inventory_panel.refresh()
			GameManager.focus_first_control(inventory_panel)
		_set_player_locked(inventory_panel.visible)
		GameManager.inventory_tab_open = inventory_panel.visible
		_update_quest_panel_visibility()
		_update_reload_prompt_visibility()
	tab_was_down = tab_down

	var esc_down := Input.is_key_pressed(KEY_ESCAPE) or GameManager.is_pause_pressed()
	if esc_down and not esc_was_down:
		if GlobalChatBox.chat_box_open:
			# GlobalChatBox polls Escape independently to close itself -
			# this branch just needs to exist so this chain doesn't also
			# fall through to opening the Pause Menu on the same press.
			pass
		elif suppress_escape_this_frame:
			suppress_escape_this_frame = false
		elif item_context_menu.visible:
			item_context_menu.visible = false
		elif inspect_panel.visible:
			inspect_panel.visible = false
		elif skins_panel.visible:
			skins_panel.visible = false
		elif open_bag_panel.visible:
			open_bag_panel.visible = false
		elif attachments_panel.visible:
			_close_attachments()
		elif wandering_trader_panel.visible:
			wandering_trader_panel.visible = false
			_set_player_locked(false)
		elif _tag_edit_was_open_at_frame_start:
			# TagEditPanel closes itself via its own _unhandled_input
			# (event-based), which fires before this polled _process()
			# check on the SAME Escape press - by the time we get here
			# tag_edit_panel.visible already reads false, so a live check
			# here could never actually match, and this fell through to
			# the else below and opened the Pause Menu as an unwanted side
			# effect of that close. _tag_edit_was_open_at_frame_start is a
			# snapshot from the end of last frame (before that self-close
			# happened), so it still correctly reflects "yes, it was open
			# when this Escape press landed."
			pass
		elif inventory_panel.visible:
			inventory_panel.visible = false
			_set_player_locked(false)
			GameManager.inventory_tab_open = false
			_update_quest_panel_visibility()
		elif pause_menu.visible:
			_close_pause()
		else:
			pause_menu.open()
			_set_player_locked(true)
			get_tree().paused = true
	esc_was_down = esc_down
	_tag_edit_was_open_at_frame_start = tag_edit_panel.visible

	# Keep the mouse cursor as a normal arrow whenever a menu/screen covers
	# the view, and restore the in-game crosshair the instant it's all
	# closed again - so you're never stuck with the wrong cursor.
	var want_default: bool = inventory_panel.visible or pause_menu.visible or attachments_panel.visible or item_context_menu.visible or inspect_panel.visible or skins_panel.visible or open_bag_panel.visible or wandering_trader_panel.visible or tag_edit_panel.visible
	if want_default != cursor_is_default:
		cursor_is_default = want_default
		if cursor_is_default:
			GameManager.set_default_cursor()
		else:
			GameManager.set_crosshair_cursor()

# --- Searching now shows in the separate Vicinity panel, not the
# Backpack - this just makes sure the screen is open so it's visible. ---

func _on_search_started(_items: Array, _duration: float) -> void:
	if not inventory_panel.visible:
		inventory_panel.visible = true
		inventory_panel.refresh()
		GameManager.focus_first_control(inventory_panel)
		_set_player_locked(true)
		GameManager.inventory_tab_open = true

func _on_search_finished() -> void:
	inventory_panel.refresh()
	# Stays open on purpose - you can look over what you got instead of it
	# snapping shut on you. Close it yourself with TAB or ESC when ready.

func _close_pause() -> void:
	pause_menu.close()
	_set_player_locked(false)
	get_tree().paused = false

func _on_exit_requested() -> void:
	pause_menu.close()
	get_tree().paused = false
	if GameManager.in_social_hub:
		GameManager.in_social_hub = false
		Transition.change_scene_instant("res://scenes/MainMenu.tscn")
		return
	GameManager.end_run(false, true)

func _set_player_locked(locked: bool) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("set_input_locked"):
		player.set_input_locked(locked)

func update_ammo(current_mag: int, _mag_size: int, reserve_ammo: int, ammo_type: String = "") -> void:
	ammo_label.text = "%d / %d %s" % [current_mag, reserve_ammo, ammo_type.capitalize()] if ammo_type != "" else "%d / %d" % [current_mag, reserve_ammo]
	ammo_label.modulate.a = 1.0
	_ammo_peek_seconds_left = AMMO_PEEK_DURATION
	_wants_reload_prompt = current_mag < 5 and reserve_ammo > 0
	_update_reload_prompt_visibility()

func update_time_remaining(seconds: float) -> void:
	var m := floori(seconds / 60.0)
	var s := floori(seconds) % 60
	if m == _last_time_m and s == _last_time_s:
		return
	_last_time_m = m
	_last_time_s = s
	time_label.text = "%02d:%02d" % [m, s]
	time_label.add_theme_color_override("font_color", Color(1, 0.3, 0.25, 1) if seconds <= 30.0 else Color(0.95, 0.9, 0.75, 1))

func flash_stun(duration: float) -> void:
	stun_flash.color.a = 0.9
	var tw := create_tween()
	tw.tween_property(stun_flash, "color:a", 0.0, max(0.4, duration * 0.55))

# Fires whenever the player's health drops, regardless of what's open on
# screen - a red vignette pulse at the screen edges, since the in-world
# health bar sits near the character and is completely hidden behind
# the Inventory/Stash panel, leaving no way to tell you're being shot
# at while digging through your bag.
func _on_player_health_changed(current: int, _maximum: int) -> void:
	if _last_known_health >= 0 and current < _last_known_health:
		_flash_hit_vignette()
	_last_known_health = current

func _flash_hit_vignette() -> void:
	_hit_flash_mat.set_shader_parameter("intensity", 1.0)
	var tw := create_tween()
	tw.tween_property(_hit_flash_mat, "shader_parameter/intensity", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func update_stats(_speed: float, _max_health: int, _damage: int, _shoot_cooldown: float) -> void:
	pass  # Top-left HUD now shows only currencies - stats label is hidden.

func _on_run_ended(_success: bool, _loot_value: int) -> void:
	# No message here anymore - the RaidRewards/Death screens (loaded
	# right after this) are the real summary now, for either outcome.
	pass
