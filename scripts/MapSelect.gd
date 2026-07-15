extends Control

@onready var day_button: Button = $VBox/DayButton
@onready var night_button: Button = $VBox/NightButton
@onready var day_time_label: Label = $VBox/DayTimeLabel
@onready var night_time_label: Label = $VBox/NightTimeLabel
@onready var back_button: Button = $VBox/BackButton

func _input(event: InputEvent) -> void:
	if GlobalChatBox.chat_box_open:
		return
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		Transition.change_scene_instant("res://scenes/MapChoice.tscn")

func _ready() -> void:
	GameManager.set_default_cursor()
	day_button.pressed.connect(func(): _start_raid(false))
	night_button.pressed.connect(func(): _start_raid(true))
	back_button.pressed.connect(func(): Transition.change_scene_instant("res://scenes/MapChoice.tscn"))
	_update_time()

func _process(_delta: float) -> void:
	_update_time()

func _update_time() -> void:
	day_time_label.text = "Currently %s" % GameManager.format_hour(GameManager.get_day_display_hour())
	night_time_label.text = "Currently %s" % GameManager.format_hour(GameManager.get_night_display_hour())

func _start_raid(is_night: bool) -> void:
	var weapon = GameManager.equipped_items.get("weapon")
	if weapon != null:
		var ammo_type: String = GameManager.get_ammo_type_for_weapon_item(weapon)
		if GameManager.get_backpack_ammo_amount(ammo_type) <= 0:
			_show_no_ammo_popup(ammo_type)
			return
	GameManager.is_night_raid = is_night
	GameManager.selected_raid_hour = GameManager.get_night_display_hour() if is_night else GameManager.get_day_display_hour()
	Transition.change_scene_instant("res://scenes/SearchingForPlayers.tscn")

# A real blocking popup instead of a toast - deploying with zero reserve
# ammo for your equipped weapon isn't just a warning anymore, it stops
# you from queuing at all until you've actually gone and equipped some.
func _show_no_ammo_popup(ammo_type: String) -> void:
	var popup := PopupPanel.new()
	add_child(popup)
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(320, 0)
	vbox.add_theme_constant_override("separation", 12)
	popup.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "No Ammo"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.35, 0.3, 1))
	vbox.add_child(title_lbl)

	var msg_lbl := Label.new()
	msg_lbl.text = "Your equipped weapon needs %s Ammo in your Backpack Storage - go back to the Stash and move some in first." % ammo_type.capitalize()
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(msg_lbl)

	var close_btn := Button.new()
	close_btn.text = "OK"
	close_btn.custom_minimum_size = Vector2(0, 36)
	close_btn.pressed.connect(func():
		popup.hide()
		popup.queue_free()
	)
	vbox.add_child(close_btn)

	popup.popup_centered()
