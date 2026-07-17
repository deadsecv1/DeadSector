extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")
const PortraitScene := preload("res://scenes/TraderPortrait.tscn")
const SmallIconScene := preload("res://scenes/SmallIcon.tscn")

# Arena's version of Social's Find a Team - same "simulated, ever-moving
# list of groups" spirit (see FindTeamPanel.gd), sized to Arena's
# 4v4-7v7 squads and showing each leader's Arena Rank instead of the
# normal Rank.

signal closed

const MAX_VISIBLE_TEAMS := 10
const TICK_SECONDS := 1.0

@onready var team_list: VBoxContainer = $VBox/TeamScroll/TeamList
@onready var close_button: Button = $VBox/CloseButton

var _teams: Array = []
var _rows: Dictionary = {}
var _next_id: int = 1
var _tick_accum: float = 0.0
var _spawn_timer: float = 0.0
var _next_spawn_delay: float = 2.0
# player_joined is tracked per-team, so nothing stopped clicking Join on
# a second, different row before the first team filled up and
# transitioned - registering the player on two rosters at once.
var _player_has_joined_a_team: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		closed.emit()

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())

func open() -> void:
	visible = true
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -320.0
	offset_top = -260.0
	offset_right = 320.0
	offset_bottom = 260.0
	_clear_all()
	_player_has_joined_a_team = false
	_next_spawn_delay = randf_range(1.0, 2.0)
	_spawn_timer = 0.0
	_tick_accum = 0.0
	for i in range(randi_range(5, 8)):
		_spawn_team()
	set_process(true)
	GameManager.focus_first_control(self)

func _exit_tree() -> void:
	set_process(false)

func _clear_all() -> void:
	for c in team_list.get_children():
		c.queue_free()
	_teams.clear()
	_rows.clear()

func _process(delta: float) -> void:
	if not visible:
		set_process(false)
		return
	_spawn_timer += delta
	if _spawn_timer >= _next_spawn_delay:
		_spawn_timer = 0.0
		_next_spawn_delay = randf_range(2.0, 5.0)
		if _teams.size() < MAX_VISIBLE_TEAMS:
			_spawn_team()
	_tick_accum += delta
	if _tick_accum >= TICK_SECONDS:
		_tick_accum -= TICK_SECONDS
		_tick()

func _tick() -> void:
	var to_remove: Array = []
	for t in _teams:
		if t["joining_countdown"] > 0:
			t["joining_countdown"] -= 1
			if t["joining_countdown"] <= 0:
				if t.get("player_joined", false):
					# Previously just emitted a toast and stopped - never
					# actually built a match or transitioned, so "Heading
					# into The Grid" never happened. Build the match from
					# THIS specific team (not a fresh random roll) and go.
					GameManager.generate_arena_match_from_team(t["members"], t["max"])
					GameManager.toast_requested.emit("Team ready! Heading into The Grid...")
					Transition.change_scene("res://scenes/ArenaLoadoutChoice.tscn")
					return
				to_remove.append(t)
				continue
			_refresh_row_status(t)
			continue
		var roll := randf()
		if roll < 0.18 and t["members"].size() < t["max"]:
			_team_gain_member(t)
			if t["members"].size() >= t["max"]:
				t["joining_countdown"] = 4
			_refresh_row(t)
		elif roll < 0.24 and not t.get("player_joined", false):
			to_remove.append(t)
	for t in to_remove:
		_remove_team(t)

func _team_gain_member(t: Dictionary) -> void:
	var pool: Array = GameManager.get_ranked_leaderboard().filter(func(e): return not e.get("is_player", false))
	var existing_names: Array = t["members"].map(func(m): return m.get("name", ""))
	pool.shuffle()
	for cand in pool:
		if not existing_names.has(cand.get("name", "")):
			t["members"].append({"name": cand.get("name", "?"), "portrait": cand.get("portrait", "portrait_1")})
			return

func _spawn_team() -> void:
	var pool: Array = GameManager.get_leaderboard("arena").filter(func(e): return not e.get("is_player", false))
	if pool.is_empty():
		return
	var leader: Dictionary = pool[randi() % pool.size()]
	var max_size: int = randi_range(4, 7)
	var t := {
		"id": _next_id, "leader": leader, "max": max_size,
		"members": [{"name": leader.get("name", "?"), "portrait": leader.get("portrait", "portrait_1")}],
		"joining_countdown": 0, "player_joined": false,
	}
	_next_id += 1
	_teams.append(t)
	_add_row(t)

func _remove_team(t: Dictionary) -> void:
	var row: Dictionary = _rows.get(t["id"], {})
	if row.has("card") and is_instance_valid(row["card"]):
		team_list.remove_child(row["card"])
		row["card"].queue_free()
	_rows.erase(t["id"])
	_teams.erase(t)

func _on_join_pressed(team_id: int) -> void:
	var t: Dictionary = {}
	for candidate in _teams:
		if candidate["id"] == team_id:
			t = candidate
			break
	if t.is_empty() or t.get("player_joined", false) or t["members"].size() >= t["max"] or _player_has_joined_a_team:
		return
	_player_has_joined_a_team = true
	t["player_joined"] = true
	t["members"].append({"name": GameManager.player_name if GameManager.player_name != "" else "You", "portrait": GameManager.player_portrait_id if GameManager.player_portrait_id != "" else "portrait_1", "is_player": true})
	Sfx.play_coin_hover()
	if t["members"].size() >= t["max"]:
		t["joining_countdown"] = 4
	_refresh_row(t)

func _add_row(t: Dictionary) -> void:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.1, 0.85)
	sb.border_color = Color(0.6, 0.35, 0.85, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	vbox.add_child(header)

	var mode_lbl := Label.new()
	mode_lbl.text = "%dv%d" % [t["max"], t["max"]]
	mode_lbl.add_theme_font_size_override("font_size", 13)
	mode_lbl.add_theme_color_override("font_color", Color(0.75, 0.5, 0.95, 1))
	header.add_child(mode_lbl)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)

	var leader: Dictionary = t["leader"]
	var arena_idx: int = GameManager.get_arena_rank_index_for_points(int(leader.get("value", 0)))
	var tier: Dictionary = GameManager.get_arena_rank_tier(arena_idx)
	var rank_lbl := Label.new()
	rank_lbl.text = str(tier.get("label", "?"))
	rank_lbl.add_theme_font_size_override("font_size", 12)
	rank_lbl.add_theme_color_override("font_color", tier.get("color", Color.WHITE))
	header.add_child(rank_lbl)

	var name_lbl := Label.new()
	name_lbl.text = "%s's Team" % str(leader.get("name", "?"))
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95, 1))
	vbox.add_child(name_lbl)

	var mid_row := HBoxContainer.new()
	mid_row.add_theme_constant_override("separation", 3)
	vbox.add_child(mid_row)
	var member_holder := HBoxContainer.new()
	member_holder.add_theme_constant_override("separation", 3)
	mid_row.add_child(member_holder)

	var status_row := HBoxContainer.new()
	vbox.add_child(status_row)
	var status_lbl := Label.new()
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(status_lbl)
	var join_btn := Button.new()
	join_btn.text = "Join Team"
	join_btn.custom_minimum_size = Vector2(100, 28)
	join_btn.add_theme_font_size_override("font_size", 11)
	var tid: int = t["id"]
	join_btn.pressed.connect(func(): _on_join_pressed(tid))
	status_row.add_child(join_btn)

	team_list.add_child(card)
	_rows[t["id"]] = {"card": card, "member_holder": member_holder, "status_label": status_lbl, "join_button": join_btn}
	_refresh_row(t)

func _refresh_row(t: Dictionary) -> void:
	var row = _rows.get(t["id"], null)
	if row == null:
		return
	var member_holder: HBoxContainer = row["member_holder"]
	for c in member_holder.get_children():
		# queue_free() alone defers freeing to end-of-frame, so a stale
		# child is still a real member_holder child for the rest of this
		# call - remove_child() first so the immediately-following rebuild
		# below never briefly renders duplicate/stale member portraits.
		member_holder.remove_child(c)
		c.queue_free()
	for i in range(t["max"]):
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(20, 20)
		if i < t["members"].size():
			var m: Dictionary = t["members"][i]
			var portrait = PortraitScene.instantiate()
			portrait.trader_id = str(m.get("portrait", "portrait_1"))
			portrait.anchor_right = 1.0
			portrait.anchor_bottom = 1.0
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(portrait)
			slot.tooltip_text = str(m.get("name", "?")) + (" (You)" if m.get("is_player", false) else "")
		else:
			var empty := ColorRect.new()
			empty.color = Color(1, 1, 1, 0.08)
			empty.anchor_right = 1.0
			empty.anchor_bottom = 1.0
			empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(empty)
		member_holder.add_child(slot)
	_refresh_row_status(t)

func _refresh_row_status(t: Dictionary) -> void:
	var row = _rows.get(t["id"], null)
	if row == null:
		return
	var status_lbl: Label = row["status_label"]
	var join_btn: Button = row["join_button"]
	var current: int = t["members"].size()
	var maxc: int = t["max"]
	if t["joining_countdown"] > 0:
		status_lbl.text = "%d/%d - Heading into The Grid in %d..." % [current, maxc, int(t["joining_countdown"])]
		status_lbl.add_theme_color_override("font_color", Color(0.7, 0.5, 1.0, 1))
		join_btn.visible = false
	else:
		status_lbl.text = "%d/%d - Waiting for others to join..." % [current, maxc]
		status_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
		join_btn.visible = not t.get("player_joined", false) and current < maxc
