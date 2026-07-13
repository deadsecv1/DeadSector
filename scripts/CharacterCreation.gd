extends Control

const PortraitScene := preload("res://scenes/TraderPortrait.tscn")
const PORTRAIT_CHOICES := ["portrait_1", "portrait_2", "portrait_3", "portrait_4", "portrait_5", "portrait_6"]
const BACKGROUND_ORDER := ["military", "scavenger", "mechanic", "drifter", "smuggler", "medic", "hunter"]
const TORSO_ORDER := ["sleek", "bulky", "tactical", "trench_coat"]
const BACKPACK_ORDER := ["none", "sleek_rig", "massive_pack"]
const TRAIL_ORDER := ["none", "dust", "shadow_smoke", "static"]
const TRAIT_ORDER := ["adrenaline_junkie", "second_wind", "ghost_step", "lucky_break", "loot_hound", "silver_tongued"]

@onready var name_edit: LineEdit = $MainRow/PreviewCol/NameEdit
@onready var build_slider: HSlider = $MainRow/ScrollContainer/VBox/BuildCard/BuildVBox/BuildRow/BuildSlider
@onready var build_label: Label = $MainRow/ScrollContainer/VBox/BuildCard/BuildVBox/BuildRow/BuildValueLabel
@onready var preview: Control = $MainRow/PreviewCol/PreviewPanel/Preview
@onready var portrait_row: HBoxContainer = $MainRow/ScrollContainer/VBox/PortraitCard/PortraitVBox/PortraitRow
@onready var face_preview: Control = $MainRow/ScrollContainer/VBox/FaceCard/FaceVBox/FacePreviewPanel/FacePreview
@onready var hair_row: HBoxContainer = $MainRow/ScrollContainer/VBox/FaceCard/FaceVBox/HairRow
@onready var eye_row: HBoxContainer = $MainRow/ScrollContainer/VBox/FaceCard/FaceVBox/EyeRow
@onready var mouth_row: HBoxContainer = $MainRow/ScrollContainer/VBox/FaceCard/FaceVBox/MouthRow
@onready var background_list: VBoxContainer = $MainRow/ScrollContainer/VBox/BackgroundCard/BackgroundVBox/BackgroundList
@onready var torso_row: HBoxContainer = $MainRow/ScrollContainer/VBox/BuildCard/BuildVBox/TorsoRow
@onready var skin_row: HBoxContainer = $MainRow/ScrollContainer/VBox/FaceCard/FaceVBox/SkinRow
@onready var backpack_row: HBoxContainer = $MainRow/ScrollContainer/VBox/BuildCard/BuildVBox/BackpackRow
@onready var trail_list: VBoxContainer = $MainRow/ScrollContainer/VBox/TrailCard/TrailVBox/TrailList
@onready var trait_list: VBoxContainer = $MainRow/ScrollContainer/VBox/TraitCard/TraitVBox/TraitList
@onready var bio_edit: LineEdit = $MainRow/PreviewCol/BioEdit
@onready var confirm_button: Button = $MainRow/PreviewCol/ConfirmButton

var selected_portrait: String = "portrait_1"
var selected_background: String = "drifter"
var selected_torso: String = "sleek"
var selected_backpack: String = "sleek_rig"
var selected_trait: String = "adrenaline_junkie"
var selected_trail: String = "none"
var skin_idx: int = 2
var hair_idx: int = 0
var eye_idx: int = 0
var mouth_idx: int = 0
var portrait_buttons: Dictionary = {}
var background_buttons: Dictionary = {}
var torso_buttons: Dictionary = {}
var skin_buttons: Array = []
var backpack_buttons: Dictionary = {}
var trait_buttons: Dictionary = {}
var trail_buttons: Dictionary = {}
var hair_buttons: Array = []
var eye_buttons: Array = []
var mouth_buttons: Array = []

func _ready() -> void:
	GameManager.set_default_cursor()
	name_edit.text = GameManager.player_name
	build_slider.value = GameManager.player_build
	preview.build = GameManager.player_build
	selected_portrait = GameManager.player_portrait_id if GameManager.player_portrait_id != "" else "portrait_1"
	selected_background = GameManager.player_background
	selected_torso = GameManager.player_torso_style
	selected_backpack = GameManager.player_backpack_style
	selected_trait = GameManager.player_trait
	skin_idx = GameManager.player_skin_color_idx
	hair_idx = GameManager.player_hair_color_idx
	eye_idx = GameManager.player_eye_color_idx
	mouth_idx = GameManager.player_mouth_style_idx
	selected_trail = GameManager.player_particle_trail
	bio_edit.text = GameManager.player_bio
	preview.torso_style = selected_torso
	preview.backpack_style = selected_backpack
	_update_build_label()
	_build_portrait_row()
	_build_face_pickers()
	_build_background_list()
	_build_torso_row()
	_build_skin_row()
	_build_backpack_row()
	_build_trait_list()
	_build_trail_list()
	build_slider.value_changed.connect(_on_build_changed)
	confirm_button.pressed.connect(_on_confirm)

func _on_build_changed(value: float) -> void:
	preview.build = value
	preview.queue_redraw()
	_update_build_label()

func _update_build_label() -> void:
	var v: float = build_slider.value
	if v < 0.35:
		build_label.text = "Lean"
	elif v > 0.65:
		build_label.text = "Heavy"
	else:
		build_label.text = "Average"

func _build_portrait_row() -> void:
	for c in portrait_row.get_children():
		c.queue_free()
	portrait_buttons.clear()
	for pid in PORTRAIT_CHOICES:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(46, 46)
		btn.clip_contents = true
		btn.toggle_mode = true
		btn.button_pressed = (pid == selected_portrait)
		var mini_portrait = PortraitScene.instantiate()
		mini_portrait.anchor_left = 0.0
		mini_portrait.anchor_top = 0.0
		mini_portrait.anchor_right = 1.0
		mini_portrait.anchor_bottom = 1.0
		mini_portrait.offset_left = 0.0
		mini_portrait.offset_top = 0.0
		mini_portrait.offset_right = 0.0
		mini_portrait.offset_bottom = 0.0
		mini_portrait.trader_id = pid
		mini_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(mini_portrait)
		btn.pressed.connect(func():
			selected_portrait = pid
			_refresh_portrait_selection()
		)
		portrait_row.add_child(btn)
		portrait_buttons[pid] = btn

func _refresh_portrait_selection() -> void:
	for pid in portrait_buttons:
		portrait_buttons[pid].button_pressed = (pid == selected_portrait)

func _build_face_pickers() -> void:
	hair_buttons.clear()
	for c in hair_row.get_children():
		c.queue_free()
	for i in range(GameManager.HAIR_COLORS.size()):
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(34, 34)
		swatch.toggle_mode = true
		swatch.button_pressed = (i == hair_idx)
		var sb := StyleBoxFlat.new()
		sb.bg_color = GameManager.HAIR_COLORS[i]
		sb.set_corner_radius_all(6)
		swatch.add_theme_stylebox_override("normal", sb)
		swatch.add_theme_stylebox_override("hover", sb)
		swatch.add_theme_stylebox_override("pressed", sb)
		swatch.pressed.connect(func():
			hair_idx = i
			_refresh_face_pickers()
		)
		hair_row.add_child(swatch)
		hair_buttons.append(swatch)

	eye_buttons.clear()
	for c in eye_row.get_children():
		c.queue_free()
	for i in range(GameManager.EYE_COLORS.size()):
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(34, 34)
		swatch.toggle_mode = true
		swatch.button_pressed = (i == eye_idx)
		var sb := StyleBoxFlat.new()
		sb.bg_color = GameManager.EYE_COLORS[i]
		sb.set_corner_radius_all(17)
		swatch.add_theme_stylebox_override("normal", sb)
		swatch.add_theme_stylebox_override("hover", sb)
		swatch.add_theme_stylebox_override("pressed", sb)
		swatch.pressed.connect(func():
			eye_idx = i
			_refresh_face_pickers()
		)
		eye_row.add_child(swatch)
		eye_buttons.append(swatch)

	mouth_buttons.clear()
	for c in mouth_row.get_children():
		c.queue_free()
	for i in range(GameManager.MOUTH_STYLES.size()):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 36)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		btn.button_pressed = (i == mouth_idx)
		btn.text = String(GameManager.MOUTH_STYLES[i]).capitalize()
		btn.pressed.connect(func():
			mouth_idx = i
			_refresh_face_pickers()
		)
		mouth_row.add_child(btn)
		mouth_buttons.append(btn)

	_update_face_preview()

func _refresh_face_pickers() -> void:
	for i in range(hair_buttons.size()):
		hair_buttons[i].button_pressed = (i == hair_idx)
	for i in range(eye_buttons.size()):
		eye_buttons[i].button_pressed = (i == eye_idx)
	for i in range(mouth_buttons.size()):
		mouth_buttons[i].button_pressed = (i == mouth_idx)
	_update_face_preview()

func _update_face_preview() -> void:
	face_preview.hair_color = GameManager.HAIR_COLORS[hair_idx]
	face_preview.eye_color = GameManager.EYE_COLORS[eye_idx]
	face_preview.mouth_style = GameManager.MOUTH_STYLES[mouth_idx]
	face_preview.skin_color = GameManager.SKIN_COLORS[skin_idx]
	face_preview.queue_redraw()
	preview.hair_color = GameManager.HAIR_COLORS[hair_idx]
	preview.eye_color = GameManager.EYE_COLORS[eye_idx]
	preview.mouth_style = GameManager.MOUTH_STYLES[mouth_idx]
	preview.skin_color = GameManager.SKIN_COLORS[skin_idx]
	preview.queue_redraw()

func _build_background_list() -> void:
	for c in background_list.get_children():
		c.queue_free()
	background_buttons.clear()
	for bg_id in BACKGROUND_ORDER:
		var data: Dictionary = GameManager.BACKGROUNDS.get(bg_id, {})
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 42)
		btn.toggle_mode = true
		btn.button_pressed = (bg_id == selected_background)
		btn.text = "%s - %s" % [data.get("label", bg_id), data.get("bonus_desc", "")]
		btn.pressed.connect(func():
			selected_background = bg_id
			_refresh_background_selection()
		)
		background_list.add_child(btn)
		background_buttons[bg_id] = btn

func _refresh_background_selection() -> void:
	for bg_id in background_buttons:
		background_buttons[bg_id].button_pressed = (bg_id == selected_background)

func _build_torso_row() -> void:
	for c in torso_row.get_children():
		c.queue_free()
	torso_buttons.clear()
	for style_id in TORSO_ORDER:
		var data: Dictionary = GameManager.TORSO_STYLES.get(style_id, {})
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 44)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		btn.button_pressed = (style_id == selected_torso)
		btn.text = data.get("label", style_id)
		btn.tooltip_text = data.get("desc", "")
		btn.pressed.connect(func():
			selected_torso = style_id
			preview.torso_style = style_id
			preview.queue_redraw()
			_refresh_torso_selection()
		)
		torso_row.add_child(btn)
		torso_buttons[style_id] = btn

func _refresh_torso_selection() -> void:
	for style_id in torso_buttons:
		torso_buttons[style_id].button_pressed = (style_id == selected_torso)

func _build_skin_row() -> void:
	for c in skin_row.get_children():
		c.queue_free()
	skin_buttons.clear()
	for i in range(GameManager.SKIN_COLORS.size()):
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(34, 34)
		swatch.toggle_mode = true
		swatch.button_pressed = (i == skin_idx)
		var sb := StyleBoxFlat.new()
		sb.bg_color = GameManager.SKIN_COLORS[i]
		sb.set_corner_radius_all(6)
		swatch.add_theme_stylebox_override("normal", sb)
		swatch.add_theme_stylebox_override("hover", sb)
		swatch.add_theme_stylebox_override("pressed", sb)
		swatch.pressed.connect(func():
			skin_idx = i
			_refresh_skin_selection()
			_update_face_preview()
		)
		skin_row.add_child(swatch)
		skin_buttons.append(swatch)

func _refresh_skin_selection() -> void:
	for i in range(skin_buttons.size()):
		skin_buttons[i].button_pressed = (i == skin_idx)

func _build_backpack_row() -> void:
	for c in backpack_row.get_children():
		c.queue_free()
	backpack_buttons.clear()
	for style_id in BACKPACK_ORDER:
		var data: Dictionary = GameManager.BACKPACK_STYLES.get(style_id, {})
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 42)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		btn.button_pressed = (style_id == selected_backpack)
		btn.text = data.get("label", style_id)
		btn.tooltip_text = data.get("desc", "")
		btn.pressed.connect(func():
			selected_backpack = style_id
			preview.backpack_style = style_id
			preview.queue_redraw()
			_refresh_backpack_selection()
		)
		backpack_row.add_child(btn)
		backpack_buttons[style_id] = btn

func _refresh_backpack_selection() -> void:
	for style_id in backpack_buttons:
		backpack_buttons[style_id].button_pressed = (style_id == selected_backpack)

func _build_trait_list() -> void:
	for c in trait_list.get_children():
		c.queue_free()
	trait_buttons.clear()
	for trait_id in TRAIT_ORDER:
		var data: Dictionary = GameManager.PLAYER_TRAITS.get(trait_id, {})
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 58)
		btn.toggle_mode = true
		btn.button_pressed = (trait_id == selected_trait)
		btn.text = "%s - %s" % [data.get("label", trait_id), data.get("bonus_desc", "")]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD
		btn.tooltip_text = data.get("desc", "")
		btn.pressed.connect(func():
			selected_trait = trait_id
			_refresh_trait_selection()
		)
		trait_list.add_child(btn)
		trait_buttons[trait_id] = btn

func _refresh_trait_selection() -> void:
	for trait_id in trait_buttons:
		trait_buttons[trait_id].button_pressed = (trait_id == selected_trait)

func _build_trail_list() -> void:
	for c in trail_list.get_children():
		c.queue_free()
	trail_buttons.clear()
	for trail_id in TRAIL_ORDER:
		var data: Dictionary = GameManager.PARTICLE_TRAILS.get(trail_id, {})
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 52)
		btn.toggle_mode = true
		btn.button_pressed = (trail_id == selected_trail)
		btn.text = "%s - %s" % [data.get("label", trail_id), data.get("desc", "")]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD
		btn.pressed.connect(func():
			selected_trail = trail_id
			_refresh_trail_selection()
		)
		trail_list.add_child(btn)
		trail_buttons[trail_id] = btn

func _refresh_trail_selection() -> void:
	for trail_id in trail_buttons:
		trail_buttons[trail_id].button_pressed = (trail_id == selected_trail)

func _on_confirm() -> void:
	var chosen_name := name_edit.text.strip_edges()
	if chosen_name == "":
		chosen_name = "Operative"
	GameManager.player_name = chosen_name
	GameManager.player_build = build_slider.value
	GameManager.player_portrait_id = selected_portrait
	GameManager.player_background = selected_background
	GameManager.player_bio = bio_edit.text.strip_edges()
	GameManager.player_hair_color_idx = hair_idx
	GameManager.player_eye_color_idx = eye_idx
	GameManager.player_mouth_style_idx = mouth_idx
	GameManager.player_skin_color_idx = skin_idx
	GameManager.player_torso_style = selected_torso
	GameManager.player_backpack_style = selected_backpack
	GameManager.player_trait = selected_trait
	GameManager.player_particle_trail = selected_trail
	GameManager.apply_background_bonus(selected_background)
	GameManager.apply_trait_bonus(selected_trait)
	GameManager.character_created = true
	GameManager.save_game()
	Transition.change_scene_instant("res://scenes/MainMenu.tscn")
