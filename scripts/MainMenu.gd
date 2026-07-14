extends Control

@onready var vbox_container: VBoxContainer = $VBoxContainer
@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var quests_button: Button = $VBoxContainer/QuestsButton
@onready var traders_button: Button = $VBoxContainer/TradersButton
@onready var skill_tree_button: Button = $VBoxContainer/SkillTreeButton
@onready var hideout_button: Button = $VBoxContainer/HideoutButton
@onready var stash_button: Button = $VBoxContainer/StashButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var exit_button: Button = $VBoxContainer/ExitButton
@onready var exit_confirm_panel: Panel = $ExitConfirmPanel
@onready var exit_confirm_button: Button = $ExitConfirmPanel/VBox/ButtonRow/ConfirmButton
@onready var exit_cancel_button: Button = $ExitConfirmPanel/VBox/ButtonRow/CancelButton
@onready var tagline_label: Label = $VBoxContainer/Tagline
@onready var quest_panel: Control = $QuestPanel
@onready var roadmap_button: Button = $RoadmapButton
@onready var roadmap_panel: Panel = $RoadmapPanel
@onready var stats_button: Button = $StatsButton
@onready var stats_panel: Panel = $StatsPanel
@onready var achievements_button: Button = $AchievementsButton
@onready var achievements_panel: Panel = $AchievementsPanel
@onready var event_button: Button = $EventButton
@onready var battle_pass_panel: Panel = $BattlePassPanel
@onready var store_button: Button = $StoreButton
@onready var store_panel: Panel = $StorePanel
@onready var social_button: Button = $SocialButton
@onready var social_panel: Panel = $SocialPanel
@onready var global_chat_panel: Panel = $GlobalChatPanel
@onready var find_team_panel: Panel = $FindTeamPanel
@onready var guild_panel: Panel = $GuildPanel
@onready var data_button: Button = $DataButton
@onready var data_panel: Panel = $DataPanel
@onready var leaderboard_button: Button = $LeaderboardButton
@onready var leaderboard_panel: Panel = $LeaderboardPanel
@onready var leaderboard_rewards_panel: Panel = $LeaderboardRewardsPanel
@onready var rank_percentiles_panel: Panel = $RankPercentilesPanel
@onready var salvaged_beasts_button: Button = $SalvagedBeastsButton
@onready var salvaged_beasts_panel: Panel = $SalvagedBeastsPanel
@onready var my_pets_panel: Panel = $MyPetsPanel
@onready var bloodline_button: Button = $BloodlineButton
@onready var bloodline_panel: Panel = $BloodlinePanel
@onready var delete_character_button: Button = $StatsPanel/Margin/VBox/DeleteCharacterButton
@onready var delete_confirm_panel: Panel = $DeleteConfirmPanel
@onready var delete_confirm_button: Button = $DeleteConfirmPanel/VBox/ButtonRow/ConfirmButton
@onready var delete_cancel_button: Button = $DeleteConfirmPanel/VBox/ButtonRow/CancelButton
@onready var wipe_button: Button = $VBoxContainer/WipeButton
@onready var wipe_confirm_panel: Panel = $WipeConfirmPanel
@onready var wipe_confirm_button: Button = $WipeConfirmPanel/VBox/ButtonRow/ConfirmButton
@onready var wipe_cancel_button: Button = $WipeConfirmPanel/VBox/ButtonRow/CancelButton
@onready var changelog_button: Button = $ChangelogButton
@onready var changelog_panel: Panel = $ChangelogPanel
@onready var flea_market_button: Button = $VBoxContainer/FleaMarketButton
@onready var flea_market_panel: Panel = $FleaMarketPanel
@onready var mail_button: Button = $MailButton
@onready var mail_badge: PanelContainer = $MailButton/Badge
@onready var mail_badge_label: Label = $MailButton/Badge/BadgeLabel
@onready var mail_panel: Panel = $MailPanel
@onready var alpha_rewards_button: Button = $AlphaRewardsButton
@onready var alpha_rewards_panel: Panel = $AlphaRewardsPanel
@onready var arena_button: Button = $ArenaButton
@onready var arena_panel: Panel = $ArenaPanel
@onready var arena_find_team_panel: Panel = $ArenaFindTeamPanel
@onready var arena_rewards_panel: Panel = $ArenaRewardsPanel
@onready var arena_rank_rewards_panel: Panel = $ArenaRankRewardsPanel
@onready var milestones_button: Button = $MilestonesButton
@onready var milestones_panel: Panel = $MilestonesPanel
@onready var feedback_button: Button = $FeedbackButton
@onready var feedback_panel: Panel = $FeedbackPanel
@onready var whats_new_button: Button = $WhatsNewButton
@onready var welcome_panel: Control = $WelcomePanel
@onready var update_spotlight_panel: Control = $UpdateSpotlightPanel

# --- Ambient background popups: small, easy-to-miss notifications that
# make the world feel like it's happening even when you're just sitting
# on the Main Menu - someone buying a pack, someone hitting the podium,
# a chat message landing. Purely cosmetic, no real simulation behind
# them beyond picking a random name from the same rival pool everything
# else uses.
var _store_popup_timer: float = 0.0
var _store_popup_next: float = 0.0
var _leaderboard_popup_timer: float = 0.0
var _leaderboard_popup_next: float = 0.0
var _chat_popup_timer: float = 0.0
var _chat_popup_next: float = 0.0
var _last_top3_names: Array = []
# leaderboard_panel is shared between the direct Leaderboard button and
# Arena's "Leaderboard" entry point - its closed handler needs to know
# which one to return to (bare Main Menu vs back to the Arena panel).
var _leaderboard_opened_from_arena: bool = false

const QUOTES := [
	"THE SECTOR DOES NOT FORGIVE",
	"EVERY EXTRACTION HAS A PRICE",
	"NOBODY COMES BACK THE SAME",
	"TRUST NOTHING THAT STILL BREATHES",
	"THE DARK OWES YOU NOTHING",
	"LOOT IT OR LOSE IT FOREVER",
	"SURVIVAL IS NOT GUARANTEED",
	"THE HIDEOUT REMEMBERS THE MISSING",
	"SOMEONE ELSE WANTS WHAT YOU FOUND",
	"THE SECTOR WAS NEVER YOURS",
]

func _ready() -> void:
	GameManager.set_default_cursor()
	MenuMusic.resume_menu_music()
	play_button.pressed.connect(_on_play)
	quests_button.pressed.connect(func(): _open_panel(quest_panel))
	quest_panel.closed.connect(func(): _close_panel(quest_panel))
	roadmap_button.pressed.connect(func(): _open_panel(roadmap_panel))
	roadmap_panel.closed.connect(func(): _close_panel(roadmap_panel))
	stats_button.pressed.connect(func(): _open_panel(stats_panel))
	stats_panel.closed.connect(func(): _close_panel(stats_panel))
	event_button.pressed.connect(func(): _open_panel(battle_pass_panel))
	battle_pass_panel.closed.connect(func(): _close_panel(battle_pass_panel))
	store_button.pressed.connect(func(): _open_panel(store_panel))
	store_panel.closed.connect(func(): _close_panel(store_panel))
	delete_character_button.pressed.connect(func(): delete_confirm_panel.visible = true)
	delete_cancel_button.pressed.connect(func(): delete_confirm_panel.visible = false)
	delete_confirm_button.pressed.connect(func():
		GameManager.reset_character()
		delete_confirm_panel.visible = false
		Transition.change_scene_instant("res://scenes/CharacterCreation.tscn")
	)
	wipe_button.pressed.connect(func(): wipe_confirm_panel.visible = true)
	wipe_cancel_button.pressed.connect(func(): wipe_confirm_panel.visible = false)
	wipe_confirm_button.pressed.connect(func():
		GameManager.wipe_everything()
		OS.set_restart_on_exit(true)
		get_tree().quit()
	)
	changelog_button.pressed.connect(func(): _open_panel(changelog_panel))
	changelog_panel.closed.connect(func(): _close_panel(changelog_panel))
	achievements_button.pressed.connect(func(): _open_panel(achievements_panel))
	achievements_panel.closed.connect(func(): _close_panel(achievements_panel))
	social_button.pressed.connect(func(): _open_panel(social_panel))
	social_panel.closed.connect(func(): _close_panel(social_panel))
	social_panel.global_chat_requested.connect(func():
		_close_panel(social_panel)
		_open_panel(global_chat_panel)
	)
	global_chat_panel.closed.connect(func():
		global_chat_panel.visible = false
		_open_panel(social_panel)
	)
	social_panel.find_team_requested.connect(func():
		_close_panel(social_panel)
		_open_panel(find_team_panel)
	)
	find_team_panel.closed.connect(func():
		find_team_panel.visible = false
		_open_panel(social_panel)
	)
	social_panel.guild_requested.connect(func():
		_close_panel(social_panel)
		_open_panel(guild_panel)
	)
	guild_panel.closed.connect(func():
		guild_panel.visible = false
		_open_panel(social_panel)
	)
	data_button.pressed.connect(func(): _open_panel(data_panel))
	data_panel.closed.connect(func(): _close_panel(data_panel))
	leaderboard_button.pressed.connect(func():
		_leaderboard_opened_from_arena = false
		_open_panel(leaderboard_panel)
	)
	leaderboard_panel.closed.connect(func():
		leaderboard_panel.visible = false
		if _leaderboard_opened_from_arena:
			_open_panel(arena_panel)
		else:
			_set_main_buttons_visible(true)
	)
	leaderboard_panel.rewards_requested.connect(func(): leaderboard_rewards_panel.open())
	leaderboard_rewards_panel.closed.connect(func(): leaderboard_rewards_panel.visible = false)
	leaderboard_panel.ranks_requested.connect(func(): rank_percentiles_panel.open())
	rank_percentiles_panel.closed.connect(func(): rank_percentiles_panel.visible = false)
	salvaged_beasts_button.pressed.connect(func(): _open_panel(salvaged_beasts_panel))
	salvaged_beasts_panel.closed.connect(func(): _close_panel(salvaged_beasts_panel))
	salvaged_beasts_panel.my_pets_requested.connect(func(): my_pets_panel.open())
	salvaged_beasts_panel.graveyard_requested.connect(_on_graveyard_requested)
	my_pets_panel.closed.connect(func(): my_pets_panel.visible = false)
	bloodline_button.pressed.connect(func(): _open_panel(bloodline_panel))
	bloodline_panel.closed.connect(func(): _close_panel(bloodline_panel))
	bloodline_panel.enter_gauntlet_requested.connect(func():
		GameManager.gauntlet_current_level = 1
		GameManager.start_gauntlet_session()
		GameManager.notify_event("play_bloodline_event")
		Transition.change_scene_instant("res://scenes/GauntletIntro.tscn")
	)
	traders_button.pressed.connect(_on_traders)
	skill_tree_button.pressed.connect(_on_skill_tree)
	hideout_button.pressed.connect(_on_hideout)
	stash_button.pressed.connect(_on_stash)
	settings_button.pressed.connect(_on_settings)
	exit_button.pressed.connect(func(): exit_confirm_panel.visible = true)
	exit_cancel_button.pressed.connect(func(): exit_confirm_panel.visible = false)
	exit_confirm_button.pressed.connect(_on_exit)

	for btn in [play_button, quests_button, traders_button, skill_tree_button, hideout_button, stash_button, settings_button, exit_button, roadmap_button, stats_button, changelog_button, social_button, achievements_button, flea_market_button, mail_button, feedback_button, whats_new_button, leaderboard_button, milestones_button]:
		btn.mouse_entered.connect(_play_hover)

	flea_market_button.pressed.connect(func(): _open_panel(flea_market_panel))
	flea_market_panel.closed.connect(func(): _close_panel(flea_market_panel))
	mail_button.pressed.connect(func(): _open_panel(mail_panel))
	mail_panel.closed.connect(func():
		_close_panel(mail_panel)
		_refresh_mail_button()
	)
	alpha_rewards_button.pressed.connect(func(): _open_panel(alpha_rewards_panel))
	alpha_rewards_panel.closed.connect(func(): _close_panel(alpha_rewards_panel))
	arena_button.pressed.connect(func(): _open_panel(arena_panel))
	arena_panel.closed.connect(func(): _close_panel(arena_panel))
	arena_panel.matchmake_requested.connect(func():
		_close_panel(arena_panel)
		Transition.change_scene("res://scenes/ArenaMatchmaking.tscn")
	)
	arena_panel.find_team_requested.connect(func():
		_close_panel(arena_panel)
		_open_panel(arena_find_team_panel)
	)
	arena_find_team_panel.closed.connect(func():
		arena_find_team_panel.visible = false
		_open_panel(arena_panel)
	)
	arena_panel.social_place_requested.connect(func():
		_close_panel(arena_panel)
		Transition.change_scene("res://scenes/SocialPlace.tscn")
	)
	arena_panel.leaderboard_requested.connect(func():
		_leaderboard_opened_from_arena = true
		_close_panel(arena_panel)
		_open_panel(leaderboard_panel)
		leaderboard_panel._switch_category("arena")
	)
	arena_panel.ranks_requested.connect(func():
		_close_panel(arena_panel)
		_open_panel(arena_rewards_panel)
	)
	arena_rewards_panel.closed.connect(func():
		arena_rewards_panel.visible = false
		_open_panel(arena_panel)
	)
	arena_panel.rewards_requested.connect(func():
		_close_panel(arena_panel)
		_open_panel(arena_rank_rewards_panel)
	)
	arena_rank_rewards_panel.closed.connect(func():
		arena_rank_rewards_panel.visible = false
		_open_panel(arena_panel)
	)
	milestones_button.pressed.connect(func(): _open_panel(milestones_panel))
	milestones_panel.closed.connect(func(): _close_panel(milestones_panel))
	feedback_button.pressed.connect(func(): _open_panel(feedback_panel))
	feedback_panel.closed.connect(func(): _close_panel(feedback_panel))
	# WhatsNewButton manually reopens the Update Spotlight (the curated
	# recent-update summary) - the Welcome window is first-launch-only
	# and has no manual reopen path.
	whats_new_button.pressed.connect(func(): _open_panel(update_spotlight_panel))
	update_spotlight_panel.closed.connect(func(): _close_panel(update_spotlight_panel))
	welcome_panel.closed.connect(func():
		_close_panel(welcome_panel)
		GameManager.has_seen_welcome = true
		GameManager.save_game()
		_open_panel(update_spotlight_panel)
	)
	# Welcome only ever shows once, the very first time the game is ever
	# launched. The Update Spotlight shows once per launch (chained after
	# Welcome that first time, standalone on every launch after) - NOT
	# once per Main Menu load, which is what has_shown_update_spotlight_
	# this_session guards against, since returning from Stash/Traders/
	# Skill Tree reloads this whole scene from scratch.
	if not GameManager.has_shown_update_spotlight_this_session:
		get_tree().create_timer(0.5).timeout.connect(func():
			if not is_instance_valid(self):
				return
			GameManager.has_shown_update_spotlight_this_session = true
			if not GameManager.has_seen_welcome:
				_open_panel(welcome_panel)
			else:
				_open_panel(update_spotlight_panel)
		)
	GameManager.mail_received.connect(_refresh_mail_button)
	_refresh_mail_button()

	_show_random_quote()

	_store_popup_next = randf_range(20.0, 60.0)
	_leaderboard_popup_next = randf_range(15.0, 35.0)
	_chat_popup_next = randf_range(6.0, 16.0)
	_last_top3_names = GameManager.get_ranked_leaderboard().slice(0, 3).map(func(e): return str(e.get("name", "")))
	set_process(true)

func _process(delta: float) -> void:
	_store_popup_timer += delta
	if _store_popup_timer >= _store_popup_next:
		_store_popup_timer = 0.0
		_store_popup_next = randf_range(20.0, 60.0)
		_show_store_purchase_popup()

	_leaderboard_popup_timer += delta
	if _leaderboard_popup_timer >= _leaderboard_popup_next:
		_leaderboard_popup_timer = 0.0
		_leaderboard_popup_next = randf_range(15.0, 35.0)
		_check_leaderboard_podium_popup()

	_chat_popup_timer += delta
	if _chat_popup_timer >= _chat_popup_next:
		_chat_popup_timer = 0.0
		_chat_popup_next = randf_range(6.0, 16.0)
		_show_chat_ping_popup()

# Ambient popups have no business appearing while a panel is already
# open over them - especially Social/Global Chat, where the "..." popup
# and the Store/Leaderboard ones were showing up on top of (or behind)
# the panel itself.
# Ambient popups have no business appearing while ANY panel is open
# over the Main Menu - they were only checking Social/Global Chat
# before, which meant they'd still show up over the Flea Market, Store,
# Leaderboard, or anything else.
func _ambient_popups_suppressed() -> bool:
	var panels: Array = [
		quest_panel, roadmap_panel, stats_panel, achievements_panel, battle_pass_panel,
		store_panel, social_panel, global_chat_panel, find_team_panel, data_panel, leaderboard_panel,
		leaderboard_rewards_panel, rank_percentiles_panel, salvaged_beasts_panel, my_pets_panel,
		bloodline_panel, delete_confirm_panel, wipe_confirm_panel, changelog_panel,
		flea_market_panel, mail_panel, alpha_rewards_panel, feedback_panel, welcome_panel, update_spotlight_panel,
		milestones_panel, guild_panel,
	]
	for p in panels:
		if is_instance_valid(p) and p.visible:
			return true
	return false

# A small notification near the Store button - someone (a name from the
# same rival pool as everywhere else) just bought a random pack.
func _show_store_purchase_popup() -> void:
	if _ambient_popups_suppressed():
		return
	var pool: Array = GameManager.get_ranked_leaderboard().filter(func(e): return not e.get("is_player", false))
	if pool.is_empty():
		return
	var buyer: Dictionary = pool[randi() % pool.size()]
	var pack: Dictionary = GameManager.STORE_PACKS[randi() % GameManager.STORE_PACKS.size()]
	_show_ambient_popup(store_button, "%s just bought the %s" % [str(buyer.get("name", "Someone")), str(pack.get("label", "a pack"))], Color(0.95, 0.8, 0.3, 1))

# Recomputes the Ranked leaderboard's top 3 and announces whichever
# name(s) are newly there since the last check - only fires when the
# podium actually changed, not on a fixed schedule regardless.
func _check_leaderboard_podium_popup() -> void:
	var top3: Array = GameManager.get_ranked_leaderboard().slice(0, 3)
	var top3_names: Array = top3.map(func(e): return str(e.get("name", "")))
	if _ambient_popups_suppressed():
		_last_top3_names = top3_names
		return
	for i in range(top3.size()):
		var entry: Dictionary = top3[i]
		var name_here: String = str(entry.get("name", ""))
		if entry.get("is_player", false):
			continue
		if not _last_top3_names.has(name_here):
			_show_ambient_popup(leaderboard_button, "%s just reached #%d on the Leaderboard!" % [name_here, i + 1], Color(0.9, 0.75, 0.3, 1))
			break
	_last_top3_names = top3_names

# A tiny "..." near the Global Chat entry point - the Social button on
# the raw Main Menu, or the Global Chat button INSIDE the Social panel
# once that's open (the Social button itself is covered by then). Never
# shows at all while Global Chat itself is already open, or while any
# other panel is covering the screen.
func _show_chat_ping_popup() -> void:
	if global_chat_panel.visible:
		return
	if not GameManager.has_shown_chat_keybind_hint:
		GameManager.has_shown_chat_keybind_hint = true
		GameManager.toast_requested.emit("Tip: press %s anytime for the full multi-channel chat" % OS.get_keycode_string(GameManager.get_keybind("chat")))
	if social_panel.visible:
		var target: Button = social_panel.global_chat_button
		_show_ambient_popup(target, "...", Color(0.6, 0.8, 1.0, 1), "right")
		_wiggle_button(target)
		return
	if _ambient_popups_suppressed():
		return
	_show_ambient_popup(social_button, "...", Color(0.6, 0.8, 1.0, 1), "right")
	_wiggle_button(social_button)

# A quick side-to-side wiggle to draw the eye toward a button right as
# its notification pops up.
func _wiggle_button(button: Control) -> void:
	if not is_instance_valid(button):
		return
	button.pivot_offset = button.size / 2.0
	var base_rot: float = button.rotation
	var tw := create_tween()
	tw.tween_property(button, "rotation", base_rot + deg_to_rad(8.0), 0.08)
	tw.tween_property(button, "rotation", base_rot - deg_to_rad(8.0), 0.08)
	tw.tween_property(button, "rotation", base_rot + deg_to_rad(5.0), 0.07)
	tw.tween_property(button, "rotation", base_rot, 0.07)

# Shared small fading popup, anchored near whichever button it's
# announcing - deliberately tiny and easy to miss rather than a big
# attention-grabbing toast. side "above" (default) sits over the top of
# the button; side "right" sits beside it instead, for buttons (like
# Social) that already have something else directly above them.
func _show_ambient_popup(near_control: Control, text: String, accent: Color, side: String = "above") -> void:
	if not is_instance_valid(near_control):
		return
	var popup := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.06, 0.9)
	sb.border_color = accent
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	popup.add_theme_stylebox_override("panel", sb)
	popup.z_index = 250
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.modulate.a = 0.0

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.modulate = Color(1, 1, 1, 0.9)
	popup.add_child(lbl)

	add_child(popup)
	await get_tree().process_frame
	var button_rect: Rect2 = near_control.get_global_rect()
	var target_pos: Vector2
	var start_offset: Vector2
	if side == "right":
		target_pos = button_rect.position + Vector2(button_rect.size.x + 6.0, button_rect.size.y * 0.5 - popup.size.y * 0.5)
		start_offset = Vector2(-6.0, 0.0)
	else:
		target_pos = button_rect.position + Vector2(button_rect.size.x * 0.5 - popup.size.x * 0.5, -popup.size.y - 2.0)
		start_offset = Vector2(0.0, 6.0)
	popup.global_position = target_pos + start_offset

	var tw := create_tween()
	tw.tween_property(popup, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(popup, "global_position", target_pos, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished

	# Hold, but bail out early the instant a panel opens over the popup
	# instead of always finishing the full hold regardless - this is
	# what actually fixes it lingering visible after you've opened
	# Changelog, Roadmap, or anything else mid-animation.
	var held := 0.0
	while held < 2.6:
		if not is_instance_valid(popup):
			return
		if _ambient_popups_suppressed():
			break
		await get_tree().create_timer(0.15).timeout
		held += 0.15

	if not is_instance_valid(popup):
		return
	var tw2 := create_tween()
	tw2.tween_property(popup, "modulate:a", 0.0, 0.3)
	tw2.tween_callback(func():
		if is_instance_valid(popup):
			popup.queue_free()
	)

func _refresh_mail_button() -> void:
	var unread := GameManager.unread_mail_count()
	mail_badge.visible = unread > 0
	mail_badge_label.text = str(unread)

func _open_panel(panel) -> void:
	panel.open()
	_set_main_buttons_visible(false)

func _close_panel(panel) -> void:
	panel.visible = false
	_set_main_buttons_visible(true)

func _set_main_buttons_visible(vis: bool) -> void:
	vbox_container.visible = vis
	roadmap_button.visible = vis
	stats_button.visible = vis
	event_button.visible = vis
	store_button.visible = vis
	changelog_button.visible = vis
	social_button.visible = vis
	achievements_button.visible = vis
	data_button.visible = vis
	bloodline_button.visible = vis
	leaderboard_button.visible = vis
	salvaged_beasts_button.visible = vis
	mail_button.visible = vis
	alpha_rewards_button.visible = vis
	feedback_button.visible = vis
	whats_new_button.visible = vis
	arena_button.visible = vis
	milestones_button.visible = vis

func _show_random_quote() -> void:
	var idx := randi() % QUOTES.size()
	if QUOTES.size() > 1:
		while idx == GameManager.last_quote_index:
			idx = randi() % QUOTES.size()
	GameManager.last_quote_index = idx
	tagline_label.text = _letter_spaced(QUOTES[idx])

# Matches the existing "T H E   S E C T O R" letter-spaced style: each
# character gets a trailing space, and word-boundary spaces get an extra
# one so words read as visibly separated groups.
func _letter_spaced(s: String) -> String:
	var out := ""
	for c in s:
		if c == " ":
			out += "  "
		else:
			out += c + " "
	return out.strip_edges()

func _play_hover() -> void:
	Sfx.play_item_hover()

func _on_play() -> void:
	GameManager.is_ranked_match = false
	Transition.change_scene("res://scenes/PmcScavChoice.tscn")

func _on_graveyard_requested() -> void:
	if not GameManager.has_graveyard_key():
		GameManager.toast_requested.emit("You need the Graveyard Key in your Backpack Storage to get through the gate. Midnight Bones has it - find him in Boneclock, at night.")
		return
	GameManager.selected_map = "graveyard"
	Transition.change_scene("res://scenes/MapSelect.tscn")

func _on_traders() -> void:
	Transition.change_scene_instant("res://scenes/Traders.tscn")

func _on_skill_tree() -> void:
	Transition.change_scene_instant("res://scenes/SkillTree.tscn")

func _on_hideout() -> void:
	Transition.change_scene("res://scenes/Hideout.tscn")

func _on_settings() -> void:
	Transition.change_scene_instant("res://scenes/Settings.tscn")

func _on_stash() -> void:
	GameManager.stash_return_scene = "res://scenes/MainMenu.tscn"
	Transition.change_scene_instant("res://scenes/Stash.tscn")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_TAB and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		_on_stash()

func _on_exit() -> void:
	get_tree().quit()
