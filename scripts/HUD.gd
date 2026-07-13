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
@onready var chat_box: LineEdit = $ChatBox
@onready var quest_panel: Control = $QuestPanel
@onready var quest_list: VBoxContainer = $QuestPanel/QuestList

var _has_active_quests: bool = false

func _update_quest_panel_visibility() -> void:
	quest_panel.visible = _has_active_quests and not inventory_panel.visible

var _wants_reload_prompt: bool = false

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
var chat_box_open: bool = false
var cursor_is_default: bool = false
var _chat_opened_at_ms: int = 0

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
	message_label.visible = false
	inventory_panel.visible = false
	GameManager.inventory_tab_open = false
	pause_menu.visible = false
	attachments_panel.visible = false
	wandering_trader_panel.visible = false
	item_context_menu.visible = false
	inspect_panel.visible = false
	skins_panel.visible = false
	chat_box.visible = false
	chat_box.text_submitted.connect(_on_chat_submitted)
	open_bag_panel.visible = false
	stats_label.visible = false
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
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == GameManager.get_keybind("chat"):
		if not chat_box_open and not pause_menu.visible and not inventory_panel.visible:
			get_viewport().set_input_as_handled()
			_open_chat_box()

func _process(_delta: float) -> void:
	if GameManager.rubles != _last_rubles or GameManager.junk != _last_junk or GameManager.artifacts != _last_artifacts or GameManager.alloys != _last_alloys:
		_last_rubles = GameManager.rubles
		_last_junk = GameManager.junk
		_last_artifacts = GameManager.artifacts
		_last_alloys = GameManager.alloys
		loot_label.text = "[color=#d4a5a5]Rubles[/color] [b]%d[/b]    [color=#a5c9d4]Junk[/color] [b]%d[/b]    [color=#c9a5d4]Artifacts[/color] [b]%d[/b]    [color=#a5d4a8]Alloys[/color] [b]%d[/b]" % [_last_rubles, _last_junk, _last_artifacts, _last_alloys]

	if reload_prompt.visible:
		var mouse_pos := get_viewport().get_mouse_position()
		reload_prompt.position = mouse_pos + Vector2(18, 18)

	if _cached_player == null or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player")
	scope_overlay.visible = _cached_player != null and _cached_player.get("is_scoped") == true
	night_vision_overlay.visible = _cached_player != null and _cached_player.get("nightvision_active") == true

	# Polled (not event-based) so it behaves the same reliable way as the
	# player's WASD movement checks.
	var tab_down := Input.is_key_pressed(GameManager.get_keybind("inventory"))
	if tab_down and not tab_was_down and not pause_menu.visible:
		inventory_panel.visible = not inventory_panel.visible
		if inventory_panel.visible:
			inventory_panel.refresh()
		_set_player_locked(inventory_panel.visible)
		GameManager.inventory_tab_open = inventory_panel.visible
		_update_quest_panel_visibility()
		_update_reload_prompt_visibility()
	tab_was_down = tab_down

	var esc_down := Input.is_key_pressed(KEY_ESCAPE)
	if esc_down and not esc_was_down:
		if chat_box_open:
			_close_chat_box(true)
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
		elif tag_edit_panel.visible:
			# TagEditPanel already closes itself via its own
			# _unhandled_input (event-based) on this same Escape press -
			# this branch just needs to exist so THIS polled check doesn't
			# fall through to the else below and open the Pause Menu as
			# an unwanted side effect of that close.
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
	esc_was_down = esc_down

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
		_set_player_locked(true)
		GameManager.inventory_tab_open = true

func _on_search_finished() -> void:
	inventory_panel.refresh()
	# Stays open on purpose - you can look over what you got instead of it
	# snapping shut on you. Close it yourself with TAB or ESC when ready.

func _close_pause() -> void:
	pause_menu.close()
	_set_player_locked(false)

func _on_exit_requested() -> void:
	pause_menu.close()
	GameManager.end_run(false)

func _set_player_locked(locked: bool) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("set_input_locked"):
		player.set_input_locked(locked)

func _open_chat_box() -> void:
	chat_box_open = true
	chat_box.text = ""
	chat_box.visible = true
	chat_box.modulate.a = 1.0
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
	var tw := create_tween()
	tw.tween_property(chat_box, "modulate:a", 0.0, 2.0)
	tw.tween_callback(func():
		chat_box.visible = false
		chat_box.text = ""
	)
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("send_chat_message"):
		if trimmed != "":
			player.send_chat_message(trimmed)
		elif player.has_method("cancel_chat_typing"):
			player.cancel_chat_typing()

# Called when Escape cancels the chat box instead of sending it.
func _close_chat_box(cancelled: bool) -> void:
	chat_box_open = false
	chat_box.visible = false
	chat_box.text = ""
	chat_box.modulate.a = 1.0
	_set_player_locked(false)
	if cancelled:
		var player = get_tree().get_first_node_in_group("player")
		if player != null and player.has_method("cancel_chat_typing"):
			player.cancel_chat_typing()

func update_ammo(current_mag: int, _mag_size: int, reserve_ammo: int, ammo_type: String = "") -> void:
	ammo_label.text = "%d / %d %s" % [current_mag, reserve_ammo, ammo_type.capitalize()] if ammo_type != "" else "%d / %d" % [current_mag, reserve_ammo]
	_wants_reload_prompt = current_mag < 5 and reserve_ammo > 0
	_update_reload_prompt_visibility()

func update_time_remaining(seconds: float) -> void:
	var m := floori(seconds / 60.0)
	var s := floori(seconds) % 60
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

func _on_run_ended(success: bool, loot_value: int) -> void:
	if success:
		# No message here anymore - the RaidRewards screen (loaded right
		# after this) is the real summary now.
		return
	message_label.visible = true
	if GameManager.run_timed_out:
		message_label.text = "TIME EXPIRED\nLost %d loot." % loot_value
	else:
		message_label.text = "YOU DIED\nLost %d loot." % loot_value
