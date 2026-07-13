extends Node2D

@onready var player = $Player
@onready var gym_station = $GymStation
@onready var bedroom_station = $BedroomStation
@onready var lildirty_station = $LilDirtyStation
@onready var workbench_station = $WorkbenchStation
@onready var bitcoin_farm_station = $BitcoinFarmStation
@onready var clarity_station = $ClarityStation
@onready var sorrow_station = $SorrowStation
@onready var glenn_station = $GlennStation
@onready var big_crax_station = $BigCraxStation
@onready var pet_shop_station = $PetShopStation
@onready var justin_station = $JustinStation
@onready var ghost_station = $GhostStation
@onready var rose_station = $RoseStation
@onready var hideout_ghost = $HideoutGhost
@onready var undertow_station = $UndertowStation
@onready var gamble_panel = $HideoutUI/GamblePanel
@onready var gym_panel = $HideoutUI/GymPanel
@onready var lildirty_panel = $HideoutUI/LilDirtyPanel
@onready var workbench_panel = $HideoutUI/WorkbenchPanel
@onready var bitcoin_farm_panel = $HideoutUI/BitcoinFarmPanel
@onready var recruit_doll_panel = $HideoutUI/RecruitDollPanel
@onready var pet_shop_panel = $HideoutUI/PetShopPanel
@onready var justin_panel = $HideoutUI/JustinPanel
@onready var rose_panel = $HideoutUI/RosePanel
@onready var plushie_reveal = $HideoutUI/PlushiePetReveal
@onready var plushies_panel = $HideoutUI/PlushiesPanel
@onready var currency_label: Label = $HideoutUI/CurrencyLabel
@onready var reload_prompt: Label = $HideoutUI/ReloadPrompt
@onready var pause_overlay: Panel = $HideoutUI/PauseOverlay
@onready var resume_button: Button = $HideoutUI/PauseOverlay/VBox/ResumeButton
@onready var main_menu_button: Button = $HideoutUI/PauseOverlay/VBox/MainMenuButton
@onready var sleeping_label: Label = $HideoutUI/SleepingLabel
@onready var sleep_confirm: Panel = $HideoutUI/SleepConfirmPanel
@onready var sleep_yes: Button = $HideoutUI/SleepConfirmPanel/VBox/YesButton
@onready var sleep_no: Button = $HideoutUI/SleepConfirmPanel/VBox/NoButton

var sleeping: bool = false
var esc_was_down: bool = false
var cursor_is_default: bool = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == GameManager.get_keybind("inventory") and event.pressed and not event.echo:
		if sleeping or _any_panel_open():
			return
		get_viewport().set_input_as_handled()
		GameManager.save_game()
		GameManager.stash_return_scene = "res://scenes/Hideout.tscn"
		GameManager.hideout_player_position = player.global_position
		GameManager.hideout_position_saved = true
		Transition.change_scene_instant("res://scenes/Stash.tscn")

func _ready() -> void:
	GameManager.set_crosshair_cursor()
	MenuMusic.stop_menu_music()
	sleeping_label.visible = false
	sleep_confirm.visible = false
	reload_prompt.visible = false
	pause_overlay.visible = false
	if GameManager.hideout_position_saved:
		player.global_position = GameManager.hideout_player_position
		GameManager.hideout_position_saved = false
	resume_button.pressed.connect(_close_pause)
	main_menu_button.pressed.connect(func():
		GameManager.save_game()
		Transition.change_scene_instant("res://scenes/MainMenu.tscn")
	)
	if player.has_signal("ammo_changed"):
		player.ammo_changed.connect(_on_ammo_changed)
	gym_station.interacted.connect(_open_gym)
	bedroom_station.interacted.connect(_sleep)
	lildirty_station.interacted.connect(_open_lildirty)
	workbench_station.interacted.connect(_open_workbench)
	bitcoin_farm_station.interacted.connect(_open_bitcoin_farm)
	clarity_station.interacted.connect(func(): _open_recruit_doll("clarity"))
	sorrow_station.interacted.connect(func(): _open_recruit_doll("sorrow"))
	glenn_station.interacted.connect(func(): _open_recruit_doll("glenn"))
	big_crax_station.interacted.connect(func(): _open_recruit_doll("big_crax"))
	pet_shop_station.interacted.connect(_open_pet_shop)
	justin_station.interacted.connect(_open_justin)
	rose_station.interacted.connect(_open_rose)
	ghost_station.interacted.connect(_open_ghost_chat)
	undertow_station.interacted.connect(_open_gamble)
	# The Ghost only actually exists in the Hideout once he's been
	# recruited during a raid and successfully extracted with - before
	# that, hide both the visual and the interact zone entirely.
	ghost_station.visible = GameManager.ghost_recruited
	ghost_station.monitoring = GameManager.ghost_recruited
	hideout_ghost.visible = GameManager.ghost_recruited
	gym_panel.closed.connect(_close_gym)
	lildirty_panel.closed.connect(_close_lildirty)
	workbench_panel.closed.connect(_close_workbench)
	bitcoin_farm_panel.closed.connect(_close_bitcoin_farm)
	recruit_doll_panel.closed.connect(_close_recruit_doll)
	pet_shop_panel.closed.connect(_close_pet_shop)
	justin_panel.closed.connect(_close_justin)
	rose_panel.closed.connect(_close_rose)
	rose_panel.plushies_requested.connect(_open_plushies)
	plushies_panel.closed.connect(_close_plushies)
	plushies_panel.plushie_given.connect(func(instance_id: String): plushie_reveal.show_pet(instance_id))
	plushie_reveal.closed.connect(func(): plushie_reveal.visible = false)
	gamble_panel.closed.connect(_close_gamble)
	sleep_yes.pressed.connect(_on_sleep_confirm_yes)
	sleep_no.pressed.connect(_on_sleep_confirm_no)

func _process(_delta: float) -> void:
	currency_label.text = "Rubles %d   //   Junk %d   //   Artifacts %d   //   Alloys %d" % [
		GameManager.rubles, GameManager.junk, GameManager.artifacts, GameManager.alloys
	]
	if reload_prompt.visible:
		var mouse_pos := get_viewport().get_mouse_position()
		reload_prompt.position = mouse_pos + Vector2(18, 18)
	var esc_down := Input.is_key_pressed(KEY_ESCAPE)
	if esc_down and not esc_was_down:
		if gym_panel.visible:
			_close_gym()
		elif lildirty_panel.visible:
			_close_lildirty()
		elif workbench_panel.visible:
			_close_workbench()
		elif bitcoin_farm_panel.visible:
			_close_bitcoin_farm()
		elif recruit_doll_panel.visible:
			_close_recruit_doll()
		elif pet_shop_panel.visible:
			_close_pet_shop()
		elif justin_panel.visible:
			_close_justin()
		elif rose_panel.visible:
			_close_rose()
		elif plushies_panel.visible:
			_close_plushies()
		elif plushie_reveal.visible:
			plushie_reveal.visible = false
		elif gamble_panel.visible:
			_close_gamble()
		elif ghost_chat_open:
			_close_ghost_chat()
		elif pause_overlay.visible:
			_close_pause()
		elif not sleeping:
			_open_pause()
	esc_was_down = esc_down

	# Any popup that needs mouse interaction (talking to Justin, opening
	# a station panel, and so on) swaps to the normal pointer - swaps
	# back to the crosshair the instant everything's closed again.
	var want_default: bool = _any_panel_open() or sleep_confirm.visible
	if want_default != cursor_is_default:
		cursor_is_default = want_default
		if cursor_is_default:
			GameManager.set_default_cursor()
		elif not sleeping:
			GameManager.set_crosshair_cursor()

func _on_ammo_changed(current_mag: int, _mag_size: int, reserve_ammo: int, _ammo_type: String = "") -> void:
	reload_prompt.visible = current_mag < 5 and reserve_ammo > 0

func _any_panel_open() -> bool:
	return gym_panel.visible or lildirty_panel.visible or workbench_panel.visible or bitcoin_farm_panel.visible or recruit_doll_panel.visible or pet_shop_panel.visible or justin_panel.visible or rose_panel.visible or plushies_panel.visible or plushie_reveal.visible or gamble_panel.visible or pause_overlay.visible or ghost_chat_open

func _open_pause() -> void:
	pause_overlay.visible = true
	player.set_input_locked(true)

func _close_pause() -> void:
	pause_overlay.visible = false
	player.set_input_locked(false)

func _open_gym() -> void:
	if sleeping or _any_panel_open():
		return
	gym_panel.open()
	player.set_input_locked(true)

func _close_gym() -> void:
	gym_panel.visible = false
	player.set_input_locked(false)

func _open_lildirty() -> void:
	if sleeping or _any_panel_open():
		return
	GameManager.notify_event("meet_lil_dirty")
	lildirty_panel.open()
	player.set_input_locked(true)

func _close_lildirty() -> void:
	lildirty_panel.visible = false
	player.set_input_locked(false)

func _open_workbench() -> void:
	if sleeping or _any_panel_open():
		return
	workbench_panel.open()
	player.set_input_locked(true)

func _close_workbench() -> void:
	workbench_panel.visible = false
	player.set_input_locked(false)

func _open_bitcoin_farm() -> void:
	if sleeping or _any_panel_open():
		return
	bitcoin_farm_panel.open()
	player.set_input_locked(true)

func _close_bitcoin_farm() -> void:
	bitcoin_farm_panel.visible = false
	player.set_input_locked(false)

func _open_recruit_doll(recruit_id: String) -> void:
	if sleeping or _any_panel_open():
		return
	if not GameManager.recruits_hideout_unlocked():
		GameManager.toast_requested.emit("Finish a quest to unlock")
		return
	GameManager.notify_event("talk_to_recruits")
	recruit_doll_panel.open_for(recruit_id)
	player.set_input_locked(true)

func _close_recruit_doll() -> void:
	recruit_doll_panel.visible = false
	player.set_input_locked(false)

func _open_pet_shop() -> void:
	if sleeping or _any_panel_open():
		return
	pet_shop_panel.open()
	player.set_input_locked(true)

func _close_pet_shop() -> void:
	pet_shop_panel.visible = false
	player.set_input_locked(false)

func _open_justin() -> void:
	if sleeping or _any_panel_open():
		return
	justin_panel.open()
	player.set_input_locked(true)

func _open_rose() -> void:
	if sleeping or _any_panel_open():
		return
	rose_panel.open()
	player.set_input_locked(true)

# Opened from the "Plushies" button INSIDE Rose's own panel, not from a
# fresh world interaction - closes Rose behind it (same pattern as
# Global Chat closing Social) rather than leaving both open at once.
# Input was already locked when Rose opened, so this doesn't need to
# lock it again - closing Plushies is what actually returns control.
func _open_plushies() -> void:
	rose_panel.visible = false
	plushies_panel.open()

func _close_plushies() -> void:
	plushies_panel.visible = false
	player.set_input_locked(false)

func _open_gamble() -> void:
	if sleeping or _any_panel_open():
		return
	gamble_panel.open()
	player.set_input_locked(true)

func _close_gamble() -> void:
	gamble_panel.visible = false
	player.set_input_locked(false)

const GHOST_CHAT_LINES := [
	"\"Thanks for not walking past me like everyone else does.\"",
	"\"The Hideout's quieter than where I used to drift. I don't mind that.\"",
	"\"I don't remember much from before. Just... a lot of walking.\"",
	"\"You'll see me out there again sometime. I always come back around.\"",
	"\"Some nights I still forget I'm allowed to stay in one place now.\"",
]

var ghost_chat_open: bool = false
var _ghost_chat_layer: CanvasLayer = null

func _open_ghost_chat() -> void:
	if sleeping or _any_panel_open():
		return
	ghost_chat_open = true
	player.set_input_locked(true)

	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	_ghost_chat_layer = layer

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.5)
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -170
	panel.offset_top = -100
	panel.offset_right = 170
	panel.offset_bottom = 100
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.06, 0.97)
	sb.border_color = Color(0.55, 0.85, 0.95, 0.75)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "THE GHOST"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0, 1))
	vbox.add_child(title)

	var line_lbl := Label.new()
	line_lbl.text = GHOST_CHAT_LINES[randi() % GHOST_CHAT_LINES.size()]
	line_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	line_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line_lbl.add_theme_font_size_override("font_size", 13)
	line_lbl.modulate = Color(1, 1, 1, 0.85)
	vbox.add_child(line_lbl)

	var close_btn := Button.new()
	close_btn.text = "Leave him be"
	close_btn.custom_minimum_size = Vector2(0, 36)
	close_btn.pressed.connect(_close_ghost_chat)
	vbox.add_child(close_btn)

func _close_ghost_chat() -> void:
	ghost_chat_open = false
	if _ghost_chat_layer != null and is_instance_valid(_ghost_chat_layer):
		_ghost_chat_layer.queue_free()
	_ghost_chat_layer = null
	player.set_input_locked(false)

func _close_justin() -> void:
	justin_panel.visible = false
	player.set_input_locked(false)

func _close_rose() -> void:
	rose_panel.visible = false
	player.set_input_locked(false)

# Sleeping in bed is now the ONLY way back to the Main Menu - no standalone
# "Back" button. Press F near the bed to sleep; once the rest animation
# finishes, you're asked whether to head back to the Main Menu or stay.
func _sleep() -> void:
	if sleeping or _any_panel_open():
		return
	sleeping = true
	player.set_input_locked(true)
	sleeping_label.visible = true
	await Transition.fade_out(1.0)
	await get_tree().create_timer(1.4).timeout
	await Transition.fade_in(1.0)
	sleeping_label.visible = false
	sleeping = false
	sleep_confirm.visible = true
	GameManager.set_default_cursor()

func _on_sleep_confirm_yes() -> void:
	sleep_confirm.visible = false
	GameManager.set_default_cursor()
	Transition.change_scene("res://scenes/MainMenu.tscn")

func _on_sleep_confirm_no() -> void:
	sleep_confirm.visible = false
	GameManager.set_crosshair_cursor()
	player.set_input_locked(false)
