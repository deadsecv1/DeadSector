extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")
const ItemIconScene := preload("res://scenes/ItemIcon.tscn")
const TooltipParticlesScript := preload("res://scripts/TooltipParticles.gd")
const GodforgedAuraFXScript := preload("res://scripts/GodforgedAuraFX.gd")

# Pops up right after trading a Plushie with Rose - shows what pet she
# made, with a little scale-in bounce, a burst of particles in the
# pet's own color (plus the full Godforged aura for Ellie specifically),
# the same "reveal" sound used elsewhere for reward moments, and the
# full rarity/odds table so there's never any mystery about what you
# were actually rolling against.

signal closed

@onready var title_label: Label = $VBox/Title
@onready var icon_slot: Control = $VBox/IconSlot
@onready var icon = $VBox/IconSlot/Icon
@onready var particles_holder: Control = $VBox/IconSlot/ParticlesHolder
@onready var name_label: Label = $VBox/NameLabel
@onready var rarity_label: Label = $VBox/RarityLabel
@onready var buff_label: Label = $VBox/BuffLabel
@onready var odds_label: Label = $VBox/OddsLabel
@onready var close_button: Button = $VBox/CloseButton

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		closed.emit()

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())
	particles_holder.set_script(TooltipParticlesScript)
	# Known Godot behavior: attaching a script to a node already in the
	# tree (this one's from the .tscn) silently drops its process
	# callbacks, even though TooltipParticles.gd's own _ready() calls
	# set_process(true) - that call doesn't take effect from inside the
	# newly-attached script. Has to be called again from out here, or
	# the particles just sit still instead of drifting.
	particles_holder.set_process(true)
	particles_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_pet(instance_id: String) -> void:
	var data := GameManager.get_pet_data(instance_id)
	if data.is_empty():
		return
	visible = true
	# Same runtime anchor-collapse bug documented elsewhere (Flea Market,
	# Mail, Milestones, Plushies) - force the designed centered layout
	# back explicitly instead of trusting the .tscn-authored anchors.
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -190.0
	offset_top = -215.0
	offset_right = 190.0
	offset_bottom = 215.0
	var pet_color: Color = data.get("color", Color.WHITE)
	var rarity: String = data.get("rarity", "rare")

	# Clear any aura FX from a previous reveal before adding this one -
	# show_pet() can be called again on an already-open/reused popup.
	for c in icon_slot.get_children():
		if c != icon and c != particles_holder:
			c.queue_free()

	title_label.text = "A GODFORGED PET?!" if rarity == "godforged" else "NEW PLUSHIE PET!"
	icon.icon_key = data.get("icon_key", "pet_dog")
	icon.icon_color = pet_color
	icon.scale = Vector2(0.2, 0.2)
	icon.pivot_offset = icon.size / 2.0

	particles_holder.particle_color = pet_color
	particles_holder.gradient_colors = []
	particles_holder.intensity = 34
	if rarity == "godforged":
		GodforgedAuraFXScript.apply(icon_slot)

	name_label.text = data.get("name", "?")
	name_label.add_theme_color_override("font_color", pet_color)
	rarity_label.text = GameManager.get_rarity_label(rarity).to_upper()
	rarity_label.add_theme_color_override("font_color", pet_color)
	var instance: Dictionary = GameManager.owned_pet_instances.get(instance_id, {})
	var trait_data: Dictionary = GameManager.get_trait_data(instance.get("trait", ""))
	var stat_text := PetTooltip._pet_stat_text(data, trait_data)
	buff_label.text = "PLUSHIE BUFF - %s, and Rose's personal touch." % (stat_text if stat_text != "" else "exceptional stats")
	odds_label.text = GameManager.get_plushie_pet_odds_text()

	Sfx.play_crate_open()
	var tw := create_tween()
	tw.tween_property(icon, "scale", Vector2(1.15, 1.15), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(icon, "scale", Vector2(1.0, 1.0), 0.12)
	tw.tween_callback(Sfx.play_reveal)
