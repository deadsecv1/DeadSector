extends Control

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		closed.emit()

const PortraitScene := preload("res://scenes/QuestNPCPortrait.tscn")
const SmallIconScene := preload("res://scenes/SmallIcon.tscn")
const NPC_ORDER := ["echo", "warden", "tinkerer", "cartographer", "reaper"]
const NPC_MODELS := {"echo": "echo", "warden": "warden", "tinkerer": "sprocket", "cartographer": "atlas", "reaper": "reaper"}

@onready var portrait_row: HBoxContainer = $VBox/PortraitRow
@onready var close_button: Button = $VBox/TopRow/CloseButton
@onready var active_count_label: Label = $VBox/ActiveCountLabel
@onready var detail_popup: PanelContainer = $DetailPopup
@onready var detail_bg: ColorRect = $DetailBackdrop
@onready var detail_title: Label = $DetailPopup/Margin/VBox/NPCTitle
@onready var detail_blurb: Label = $DetailPopup/Margin/VBox/NPCBlurb
@onready var detail_list: VBoxContainer = $DetailPopup/Margin/VBox/Scroll/List
@onready var detail_close: Button = $DetailPopup/Margin/VBox/DetailCloseButton

var current_npc: String = ""

func _ready() -> void:
	GameManager.set_default_cursor()
	close_button.pressed.connect(func(): closed.emit())
	detail_close.pressed.connect(_close_detail)
	detail_bg.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			_close_detail()
	)
	detail_popup.visible = false
	detail_bg.visible = false
	GameManager.quest_state_changed.connect(_on_quest_state_changed)

func open() -> void:
	visible = true
	_build_portraits()
	_refresh_active_count()
	GameManager.focus_first_control(self)

func _on_quest_state_changed() -> void:
	if not visible:
		return
	_build_portraits()
	_refresh_active_count()
	if detail_popup.visible:
		_refresh_detail_list()

func _refresh_active_count() -> void:
	active_count_label.text = "Active Contracts: %d / %d" % [GameManager.active_quest_count(), GameManager.MAX_ACTIVE_QUESTS]

func _build_portraits() -> void:
	for c in portrait_row.get_children():
		c.queue_free()
	for npc_id in NPC_ORDER:
		var data: Dictionary = GameManager.QUEST_NPC_CATALOG.get(npc_id, {})
		var portrait = PortraitScene.instantiate()
		portrait.glow_color = data.get("glow_color", Color.WHITE)
		portrait.npc_name = data.get("name", npc_id)
		portrait.model = NPC_MODELS.get(npc_id, "echo")
		portrait.teaser = _teaser_for_npc(npc_id)
		portrait.has_active_quest = _npc_has_active_quest(npc_id)
		portrait.clicked.connect(func(): _open_detail(npc_id))
		portrait_row.add_child(portrait)

func _npc_has_active_quest(npc_id: String) -> bool:
	for key in _quests_for_npc(npc_id):
		var status := GameManager.quest_status_for(key)
		if status == "active" or status == "ready":
			return true
	return false

func _npc_has_available_quest(npc_id: String) -> bool:
	for key in _quests_for_npc(npc_id):
		if GameManager.is_quest_available(key):
			return true
	return false

func _teaser_for_npc(npc_id: String) -> String:
	if _npc_has_active_quest(npc_id):
		for key in _quests_for_npc(npc_id):
			var status := GameManager.quest_status_for(key)
			if status == "ready":
				return "\"Finished already? Come collect, then.\""
			if status == "active":
				return "\"%s? Yeah, still waiting on that.\"" % GameManager.QUEST_DATA[key].get("title", "")
	if _npc_has_available_quest(npc_id):
		return "\"Got a job for you, if you're interested.\""
	var any_locked := false
	for key in _quests_for_npc(npc_id):
		if GameManager.is_quest_locked(key):
			any_locked = true
	if any_locked:
		return "\"Nothing for you yet. Come back later.\""
	return "\"Nothing else for you right now.\""

func _quests_for_npc(npc_id: String) -> Array:
	var result: Array = []
	for key in GameManager.QUEST_ORDER:
		if GameManager.QUEST_DATA.get(key, {}).get("npc", "") == npc_id:
			result.append(key)
	return result

func _open_detail(npc_id: String) -> void:
	current_npc = npc_id
	var data: Dictionary = GameManager.QUEST_NPC_CATALOG.get(npc_id, {})
	detail_title.text = "%s - %s" % [data.get("name", npc_id), data.get("title", "")]
	detail_title.add_theme_color_override("font_color", data.get("glow_color", Color.WHITE))
	detail_blurb.text = data.get("blurb", "")
	_refresh_detail_list()
	detail_popup.visible = true
	detail_bg.visible = true
	GameManager.focus_first_control(detail_popup)

func _close_detail() -> void:
	detail_popup.visible = false
	detail_bg.visible = false
	_build_portraits()

func _refresh_detail_list() -> void:
	for c in detail_list.get_children():
		c.queue_free()
	for key in _quests_for_npc(current_npc):
		detail_list.add_child(_make_quest_row(key))

func _make_quest_row(key: String) -> Control:
	var data: Dictionary = GameManager.QUEST_DATA.get(key, {})
	var status: String = GameManager.quest_status_for(key)
	var is_done: bool = status == "done"
	var is_ready: bool = status == "ready"
	var is_active: bool = status == "active"
	var is_locked: bool = GameManager.is_quest_locked(key)
	var is_available: bool = GameManager.is_quest_available(key)

	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(1)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	if is_locked:
		sb.bg_color = Color(0.07, 0.07, 0.08, 0.75)
		sb.border_color = Color(1, 1, 1, 0.08)
	elif is_done:
		sb.bg_color = Color(0.06, 0.11, 0.07, 0.8)
		sb.border_color = Color(0.4, 0.75, 0.45, 0.5)
	else:
		sb.bg_color = Color(0.1, 0.08, 0.12, 0.9)
		var npc_color: Color = GameManager.QUEST_NPC_CATALOG.get(current_npc, {}).get("glow_color", Color.WHITE)
		sb.border_color = npc_color
	row.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	row.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	vbox.add_child(top_row)

	var icon_slot := Control.new()
	icon_slot.custom_minimum_size = Vector2(28, 28)
	var icon = SmallIconScene.instantiate()
	icon.icon_type = data.get("icon", "star") if not is_locked else "key"
	icon.icon_bg = Color(0.15, 0.1, 0.1, 1)
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon_slot.add_child(icon)
	top_row.add_child(icon_slot)

	var title_lbl := Label.new()
	title_lbl.text = data.get("title", key) if not is_locked else "???"
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	if is_done:
		title_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6, 1))
	elif is_locked:
		title_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	top_row.add_child(title_lbl)

	if is_done:
		var done_lbl := Label.new()
		done_lbl.text = "DONE"
		done_lbl.add_theme_font_size_override("font_size", 11)
		done_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5, 1))
		top_row.add_child(done_lbl)

	if not is_locked:
		var desc_lbl := Label.new()
		desc_lbl.text = data.get("desc", "")
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(desc_lbl)

		var lore_lbl := Label.new()
		lore_lbl.text = data.get("lore", "")
		lore_lbl.add_theme_font_size_override("font_size", 11)
		lore_lbl.add_theme_color_override("font_color", Color(0.75, 0.7, 0.85, 0.85))
		lore_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(lore_lbl)

		var reward_lbl := Label.new()
		reward_lbl.text = "Reward: %s" % data.get("reward_text", "")
		reward_lbl.add_theme_font_size_override("font_size", 11)
		reward_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.4, 1))
		vbox.add_child(reward_lbl)

	if is_available:
		var accept_btn := Button.new()
		accept_btn.text = "Accept"
		accept_btn.custom_minimum_size = Vector2(90, 34)
		accept_btn.pressed.connect(func():
			GameManager.accept_quest(key)
			_refresh_detail_list()
			_build_portraits()
			_refresh_active_count()
		)
		vbox.add_child(accept_btn)
	elif is_active or is_ready:
		var btn_row := HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 8)
		vbox.add_child(btn_row)
		if is_ready:
			var turn_in_btn := Button.new()
			turn_in_btn.text = "Turn In"
			turn_in_btn.custom_minimum_size = Vector2(90, 34)
			turn_in_btn.pressed.connect(func():
				GameManager.turn_in_quest(key)
				_refresh_detail_list()
				_build_portraits()
				_refresh_active_count()
			)
			btn_row.add_child(turn_in_btn)
		else:
			var active_lbl := Label.new()
			active_lbl.text = "● IN PROGRESS"
			active_lbl.add_theme_font_size_override("font_size", 12)
			active_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
			btn_row.add_child(active_lbl)
		var abandon_btn := Button.new()
		abandon_btn.text = "Abandon"
		abandon_btn.custom_minimum_size = Vector2(90, 34)
		abandon_btn.pressed.connect(func():
			GameManager.abandon_quest(key)
			_refresh_detail_list()
			_build_portraits()
			_refresh_active_count()
		)
		btn_row.add_child(abandon_btn)

	return row
