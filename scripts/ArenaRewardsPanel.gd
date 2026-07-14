extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")
const SmallIconScene := preload("res://scenes/SmallIcon.tscn")

# Arena's "Ranks" screen (formerly this panel's own "Rewards" button,
# renamed once a real Rewards screen was added - see
# ArenaRankRewardsPanel.gd) - purely descriptive flavor per Arena Rank
# tier, built from GameManager.ARENA_RANK_TIERS. For what each tier
# actually grants, see ArenaRankRewardsPanel.gd/ARENA_REWARD_TIERS.

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		closed.emit()

@onready var tier_list: VBoxContainer = $VBox/TierScroll/TierList
@onready var close_button: Button = $VBox/CloseButton

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())
	_build_tiers()

func open() -> void:
	visible = true
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -300.0
	offset_top = -280.0
	offset_right = 300.0
	offset_bottom = 280.0

func _build_tiers() -> void:
	for c in tier_list.get_children():
		c.queue_free()
	for tier in GameManager.ARENA_RANK_TIERS:
		tier_list.add_child(_make_tier_card(tier))

func _make_tier_card(tier: Dictionary) -> Control:
	var card := PanelContainer.new()
	var color: Color = tier.get("color", Color.WHITE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.1, 0.9)
	sb.border_color = color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	var icon_box := Control.new()
	icon_box.custom_minimum_size = Vector2(36, 36)
	var icon = SmallIconScene.instantiate()
	icon.icon_type = str(tier.get("icon", "star"))
	icon.icon_bg = color * 0.3
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon_box.add_child(icon)
	hbox.add_child(icon_box)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(vbox)

	var label_lbl := Label.new()
	label_lbl.text = str(tier.get("label", "?"))
	label_lbl.add_theme_font_size_override("font_size", 18)
	label_lbl.add_theme_color_override("font_color", color)
	vbox.add_child(label_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = str(tier.get("desc", ""))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.modulate = Color(1, 1, 1, 0.8)
	vbox.add_child(desc_lbl)

	return card
