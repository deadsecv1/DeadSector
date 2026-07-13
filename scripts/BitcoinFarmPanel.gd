extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		closed.emit()

const SmallIconScene := preload("res://scenes/SmallIcon.tscn")
@onready var gpu_count_label: Label = $VBox/GpuCountLabel
@onready var slot_list: VBoxContainer = $VBox/ListScroll/SlotList
@onready var close_button: Button = $VBox/CloseButton

var refresh_timer: float = 0.0

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())

func _process(delta: float) -> void:
	if not visible:
		return
	refresh_timer -= delta
	if refresh_timer <= 0.0:
		refresh_timer = 1.0
		refresh()

func open() -> void:
	visible = true
	refresh()

func refresh() -> void:
	gpu_count_label.text = "Graphics Cards in Stash: %d" % GameManager.count_carried_graphics_cards()
	for c in slot_list.get_children():
		c.queue_free()
	for i in range(GameManager.BITCOIN_SLOT_COUNT):
		slot_list.add_child(_make_row(i))

func _make_row(index: int) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 76)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	row.add_child(vbox)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	var icon = SmallIconScene.instantiate()
	icon.icon_type = "tech"
	icon.custom_minimum_size = Vector2(30, 30)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icon)

	var label := Label.new()
	var slot_data = GameManager.bitcoin_gpu_slots[index]
	label.text = "GPU Slot %d" % (index + 1)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 15)
	hbox.add_child(label)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150, 42)

	if slot_data == null:
		btn.text = "Insert GPU"
		btn.disabled = GameManager.count_carried_graphics_cards() <= 0
		btn.pressed.connect(func():
			GameManager.insert_graphics_card(index)
			refresh()
		)
	else:
		var progress: float = GameManager.get_gpu_progress(index)
		if progress >= 1.0:
			btn.text = "Claim %d Rubles" % GameManager.BITCOIN_REWARD
			btn.pressed.connect(func():
				GameManager.claim_gpu(index)
				refresh()
			)
		else:
			var pct := int(progress * 100.0)
			var remaining: float = GameManager.BITCOIN_MINE_DURATION * (1.0 - progress)
			var hrs := int(remaining / 3600.0)
			var mins := int(fmod(remaining, 3600.0) / 60.0)
			btn.text = "Mining %d%% (%dh %dm left)" % [pct, hrs, mins]
			btn.disabled = true
	hbox.add_child(btn)
	vbox.add_child(hbox)

	if slot_data != null:
		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.value = GameManager.get_gpu_progress(index) * 100.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 12)
		vbox.add_child(bar)

	return row
