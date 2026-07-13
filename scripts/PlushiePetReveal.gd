extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")
const ItemIconScene := preload("res://scenes/ItemIcon.tscn")
const TooltipParticlesScript := preload("res://scripts/TooltipParticles.gd")

# Pops up right after handing Rose a Plushie - shows what pet she made,
# with a little scale-in bounce, a burst of particles in the pet's own
# color, and the same "reveal" sound used elsewhere for reward moments.

signal closed

@onready var icon_slot: Control = $VBox/IconSlot
@onready var icon = $VBox/IconSlot/Icon
@onready var particles_holder: Control = $VBox/IconSlot/ParticlesHolder
@onready var name_label: Label = $VBox/NameLabel
@onready var rarity_label: Label = $VBox/RarityLabel
@onready var buff_label: Label = $VBox/BuffLabel
@onready var close_button: Button = $VBox/CloseButton

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
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
	var pet_color: Color = data.get("color", Color.WHITE)
	var rarity: String = data.get("rarity", "rare")

	icon.icon_key = data.get("icon_key", "pet_dog")
	icon.icon_color = pet_color
	icon.scale = Vector2(0.2, 0.2)
	icon.pivot_offset = icon.size / 2.0

	particles_holder.particle_color = pet_color
	particles_holder.gradient_colors = []
	particles_holder.intensity = 34

	name_label.text = data.get("name", "?")
	name_label.add_theme_color_override("font_color", pet_color)
	rarity_label.text = GameManager.get_rarity_label(rarity).to_upper()
	rarity_label.add_theme_color_override("font_color", pet_color)
	buff_label.text = "PLUSHIE BUFF - exceptional stats, and Rose's personal touch."

	Sfx.play_crate_open()
	var tw := create_tween()
	tw.tween_property(icon, "scale", Vector2(1.15, 1.15), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(icon, "scale", Vector2(1.0, 1.0), 0.12)
	tw.tween_callback(Sfx.play_reveal)
