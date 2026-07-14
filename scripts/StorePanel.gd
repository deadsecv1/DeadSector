extends Panel

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		closed.emit()

const SmallIconScene := preload("res://scenes/SmallIcon.tscn")
const ItemIconScene := preload("res://scenes/ItemIcon.tscn")
const SkinTextureOverlayScript := preload("res://scripts/SkinTextureOverlay.gd")
const GodforgedAuraFXScript := preload("res://scripts/GodforgedAuraFX.gd")

@onready var pack_row: GridContainer = $VBox/MainScroll/ContentVBox/PackRow
@onready var free_pack_row: GridContainer = $VBox/MainScroll/ContentVBox/FreePackRow
@onready var starter_pack_container: Control = $VBox/MainScroll/ContentVBox/StarterPackContainer
@onready var skill_point_pack_row: GridContainer = $VBox/MainScroll/ContentVBox/SkillPointPackRow
@onready var monthly_button: Button = $VBox/MainScroll/ContentVBox/PermRow/MonthlyButton
@onready var double_xp_button: Button = $VBox/MainScroll/ContentVBox/PermRow/DoubleXpButton
@onready var premium_pet_button: Button = $VBox/MainScroll/ContentVBox/PermRow/PremiumPetButton
@onready var fast_hatching_button: Button = $VBox/MainScroll/ContentVBox/PermRow/FastHatchingButton
@onready var pet_pack_row: GridContainer = $VBox/MainScroll/ContentVBox/PetPackRow
@onready var skin_row: GridContainer = $VBox/MainScroll/ContentVBox/SkinRow
@onready var skin_rotation_label: Label = $VBox/MainScroll/ContentVBox/SkinRotationLabel
@onready var close_button: Button = $VBox/CloseButton

func _ready() -> void:
	visible = false
	# Full-screen panel (fills the whole viewport) - no draggable edges here, unlike the smaller centered popups.
	close_button.pressed.connect(func(): closed.emit())
	GameManager.traders_rotated.connect(refresh)

func _process(_delta: float) -> void:
	if not visible:
		return
	var secs := int(GameManager.get_trader_rotation_seconds_left())
	skin_rotation_label.text = "Featured skins refresh in %d:%02d" % [int(secs / 60.0), secs % 60]
	_update_starter_pack_card()

func open() -> void:
	visible = true
	refresh()

func refresh() -> void:
	_build_starter_pack_card()
	for c in pack_row.get_children():
		pack_row.remove_child(c)
		c.queue_free()
	for pack in GameManager.STORE_PACKS:
		if not pack.get("free", false):
			pack_row.add_child(_make_pack_card(pack))

	for c in free_pack_row.get_children():
		free_pack_row.remove_child(c)
		c.queue_free()
	for pack in GameManager.STORE_PACKS:
		if pack.get("free", false):
			free_pack_row.add_child(_make_pack_card(pack))

	for c in skill_point_pack_row.get_children():
		skill_point_pack_row.remove_child(c)
		c.queue_free()
	for sp_pack in GameManager.SKILL_POINT_PACKS:
		skill_point_pack_row.add_child(_make_skill_point_pack_card(sp_pack))

	_ensure_real_money_placeholder(monthly_button, "MonthlyMoneyButton", "$9.99")
	monthly_button.disabled = GameManager.monthly_pass_owned
	monthly_button.text = "Monthly Pass\n%s Rubles - one-time (absurdly priced)\n%s" % [
		_format_big_number(GameManager.MONTHLY_PASS_RUBLES_COST),
		"[Owned]" if GameManager.monthly_pass_owned else "[ Purchase with Rubles ]",
	]
	monthly_button.tooltip_text = "This pass grants Rubles/Souls itself, so buying it with Rubles is circular by nature - priced absurdly high on purpose."
	if not monthly_button.pressed.is_connected(_on_monthly):
		monthly_button.pressed.connect(_on_monthly)

	var double_xp_cost: int = GameManager.dollar_price_to_rubles("$14.99")
	_ensure_real_money_placeholder(double_xp_button, "DoubleXpMoneyButton", "$14.99")
	_style_perm_button(double_xp_button, GameManager.double_xp_owned,
		"Permanent Double XP\n%d Rubles - one-time" % double_xp_cost)
	if not double_xp_button.pressed.is_connected(_on_double_xp):
		double_xp_button.pressed.connect(_on_double_xp)

	var owns_pet: bool = GameManager.owned_pets.has(GameManager.PREMIUM_PET_ID)
	var pet_cost: int = GameManager.dollar_price_to_rubles(str(GameManager.PREMIUM_PET_DATA.get("cost", "$9.99")))
	_ensure_real_money_placeholder(premium_pet_button, "PremiumPetMoneyButton", str(GameManager.PREMIUM_PET_DATA.get("cost", "$9.99")))
	_style_perm_button(premium_pet_button, owns_pet,
		"Onyx (Premium Pet)\n%d Rubles - +5 Damage, +10 Speed" % pet_cost)
	if not premium_pet_button.pressed.is_connected(_on_premium_pet):
		premium_pet_button.pressed.connect(_on_premium_pet)

	var fast_hatch_cost: int = GameManager.dollar_price_to_rubles("$6.99")
	_ensure_real_money_placeholder(fast_hatching_button, "FastHatchingMoneyButton", "$6.99")
	_style_perm_button(fast_hatching_button, GameManager.fast_hatching_owned,
		"Fast Hatching\n%d Rubles one-time - Eggs hatch 40%% quicker, forever" % fast_hatch_cost)
	if not fast_hatching_button.pressed.is_connected(_on_fast_hatching):
		fast_hatching_button.pressed.connect(_on_fast_hatching)

	for c in pet_pack_row.get_children():
		pet_pack_row.remove_child(c)
		c.queue_free()
	for pack in GameManager.PET_STORE_PACKS:
		pet_pack_row.add_child(_make_pet_pack_card(pack))

	for c in skin_row.get_children():
		skin_row.remove_child(c)
		c.queue_free()
	for featured in GameManager.featured_premium_skins:
		var weapon_type: String = featured.get("weapon_type", "pistol")
		var skin := GameManager._find_skin(featured.get("id", ""), weapon_type)
		if not skin.is_empty():
			skin_row.add_child(_make_skin_card(skin, weapon_type))

func _style_perm_button(btn: Button, owned: bool, label: String) -> void:
	btn.disabled = owned
	btn.text = label + ("\n[Owned]" if owned else "\n[ Purchase with Rubles ]")

# Inserts a disabled real-money button right before the given Rubles
# button, matching the pattern used everywhere else in the store (a
# greyed real-money option alongside an active Rubles one). Guarded so
# repeated refresh() calls don't stack duplicates.
func _ensure_real_money_placeholder(rubles_btn: Button, placeholder_name: String, price_text: String) -> void:
	var parent := rubles_btn.get_parent()
	if parent.has_node(placeholder_name):
		return
	var placeholder := Button.new()
	placeholder.name = placeholder_name
	placeholder.custom_minimum_size = rubles_btn.custom_minimum_size
	placeholder.text = "%s\n[ Purchase ]" % price_text
	placeholder.disabled = true
	placeholder.tooltip_text = "Real-money purchases aren't available - use Purchase with Rubles instead."
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.35, 0.15, 0.9)
	sb.border_color = Color(0.5, 0.9, 0.5, 1)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	placeholder.add_theme_stylebox_override("normal", sb)
	placeholder.add_theme_stylebox_override("disabled", sb)
	placeholder.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85, 1))
	placeholder.add_theme_color_override("font_disabled_color", Color(0.6, 0.7, 0.6, 0.7))
	parent.add_child(placeholder)
	parent.move_child(placeholder, rubles_btn.get_index())

func _make_pack_card(pack: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(190, 320)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.12, 0.1, 0.06, 0.85)
	card_sb.border_color = Color(0.5, 0.42, 0.2, 0.7)
	card_sb.set_border_width_all(1)
	card_sb.set_corner_radius_all(8)
	card_sb.content_margin_left = 12
	card_sb.content_margin_right = 12
	card_sb.content_margin_top = 14
	card_sb.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", card_sb)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	var price_lbl := Label.new()
	price_lbl.text = str(pack.get("price", "?"))
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_lbl.add_theme_font_size_override("font_size", 26)
	price_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1))
	vbox.add_child(price_lbl)

	var name_lbl := Label.new()
	name_lbl.text = str(pack.get("label", "Pack"))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_lbl)

	var contents_lbl := Label.new()
	var lines: Array = []
	if int(pack.get("rubles", 0)) > 0:
		lines.append("%d Rubles" % int(pack.get("rubles", 0)))
	if int(pack.get("souls", 0)) > 0:
		lines.append("%d Souls" % int(pack.get("souls", 0)))
	if int(pack.get("item_count", 0)) > 0:
		lines.append("%d %s item(s)" % [int(pack.get("item_count", 0)), String(pack.get("item_rarity", "epic")).capitalize()])
	if int(pack.get("bonus_exotic", 0)) > 0:
		lines.append("+%d Exotic item(s)" % int(pack.get("bonus_exotic", 0)))
	if int(pack.get("bonus_multiversal", 0)) > 0:
		lines.append("+%d MULTIVERSAL item(s)!" % int(pack.get("bonus_multiversal", 0)))
	if int(pack.get("lootbags", 0)) > 0:
		lines.append("%d Loot Bags" % int(pack.get("lootbags", 0)))
	if int(pack.get("ammo_count", 0)) > 0:
		lines.append("%d Ammo pickups (mixed types)" % int(pack.get("ammo_count", 0)))
	if int(pack.get("plushie_count", 0)) > 0:
		lines.append("%d Plushies" % int(pack.get("plushie_count", 0)))
	if int(pack.get("backpack_count", 0)) > 0:
		lines.append("%d Backpack(s)" % int(pack.get("backpack_count", 0)))
	if pack.get("grants_ellie", false):
		lines.append("Grants Ellie (Godforged Pet)")
	contents_lbl.text = "\n".join(lines)
	contents_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contents_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	contents_lbl.add_theme_font_size_override("font_size", 12)
	contents_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(contents_lbl)

	if pack.get("grants_ellie", false):
		var ellie_holder := Control.new()
		ellie_holder.custom_minimum_size = Vector2(0, 56)
		ellie_holder.clip_contents = true
		ellie_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(ellie_holder)
		var ellie_icon = ItemIconScene.instantiate()
		ellie_icon.icon_key = "pet_elephant"
		ellie_icon.icon_color = Color(1.0, 0.65, 0.9, 1)
		ellie_icon.anchor_right = 1.0
		ellie_icon.anchor_bottom = 1.0
		ellie_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ellie_holder.add_child(ellie_icon)
		GodforgedAuraFXScript.apply(ellie_holder)

	var pack_id: String = pack.get("id", "")

	if pack.get("free", false):
		var claimed: bool = GameManager.claimed_free_store_packs.has(pack_id)
		var claim_btn := Button.new()
		claim_btn.custom_minimum_size = Vector2(0, 36)
		claim_btn.text = "Claimed" if claimed else "Claim"
		claim_btn.disabled = claimed
		claim_btn.add_theme_font_size_override("font_size", 14)
		var claim_sb := StyleBoxFlat.new()
		claim_sb.bg_color = Color(0.15, 0.35, 0.15, 0.9)
		claim_sb.border_color = Color(0.5, 0.9, 0.5, 1)
		claim_sb.set_border_width_all(1)
		claim_sb.set_corner_radius_all(5)
		claim_btn.add_theme_stylebox_override("normal", claim_sb)
		claim_btn.add_theme_stylebox_override("disabled", claim_sb)
		claim_btn.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85, 1))
		claim_btn.add_theme_color_override("font_disabled_color", Color(0.6, 0.7, 0.6, 0.7))
		if not claimed:
			claim_btn.pressed.connect(_on_claim_free_pack.bind(pack_id))
		vbox.add_child(claim_btn)

		if pack_id == "rose_free_pack":
			_style_rose_free_pack_card(card, vbox)

		return card

	var buy_btn := Button.new()
	buy_btn.custom_minimum_size = Vector2(0, 36)
	buy_btn.text = "Purchase"
	buy_btn.disabled = true
	buy_btn.tooltip_text = "Real-money purchases aren't available - use Purchase with Rubles above instead."
	buy_btn.add_theme_font_size_override("font_size", 14)
	var buy_sb := StyleBoxFlat.new()
	buy_sb.bg_color = Color(0.15, 0.35, 0.15, 0.9)
	buy_sb.border_color = Color(0.5, 0.9, 0.5, 1)
	buy_sb.set_border_width_all(1)
	buy_sb.set_corner_radius_all(5)
	buy_btn.add_theme_stylebox_override("normal", buy_sb)
	buy_btn.add_theme_stylebox_override("disabled", buy_sb)
	buy_btn.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85, 1))
	buy_btn.add_theme_color_override("font_disabled_color", Color(0.6, 0.7, 0.6, 0.7))

	# A "buy it with Rubles instead" option - absurdly priced on
	# purpose (25x the Rubles the pack itself grants), since spending
	# Rubles to buy a pack that mostly just gives you Rubles back is a
	# joke option, not a real economic choice.
	var rubles_cost: int = GameManager.get_store_pack_rubles_cost(pack_id)
	var rubles_btn := Button.new()
	rubles_btn.custom_minimum_size = Vector2(0, 36)
	rubles_btn.text = "Purchase with Rubles\n(%s Rubles)" % _format_big_number(rubles_cost)
	rubles_btn.add_theme_font_size_override("font_size", 11)
	rubles_btn.tooltip_text = "An absurdly expensive Rubles alternative, for anyone who'd rather burn Rubles than spend real money."
	var rubles_sb := StyleBoxFlat.new()
	rubles_sb.bg_color = Color(0.3, 0.24, 0.08, 0.9)
	rubles_sb.border_color = Color(1.0, 0.85, 0.4, 1)
	rubles_sb.set_border_width_all(1)
	rubles_sb.set_corner_radius_all(5)
	rubles_btn.add_theme_stylebox_override("normal", rubles_sb)
	var rubles_sb_hover := rubles_sb.duplicate()
	rubles_sb_hover.bg_color = Color(0.38, 0.3, 0.1, 0.95)
	rubles_btn.add_theme_stylebox_override("hover", rubles_sb_hover)
	rubles_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7, 1))
	rubles_btn.pressed.connect(_on_buy_pack_with_rubles.bind(pack_id))
	vbox.add_child(rubles_btn)
	vbox.add_child(buy_btn)

	return card

# Formats a big number with thousands separators (e.g. 125000 ->
# "125,000") so absurd Rubles costs are actually readable at a glance.
func _format_big_number(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i != 0:
			out = "," + out
	return out

func _make_skin_card(skin: Dictionary, weapon_type: String) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(130, 232)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.08, 0.08, 0.1, 0.85)
	card_sb.border_color = Color(0.4, 0.4, 0.45, 0.6)
	card_sb.set_border_width_all(1)
	card_sb.set_corner_radius_all(8)
	card_sb.content_margin_left = 8
	card_sb.content_margin_right = 8
	card_sb.content_margin_top = 10
	card_sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", card_sb)

	var skin_id: String = skin.get("id", "")
	var already_owned: bool = GameManager.owned_skins.has(skin_id)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 5)
	card.add_child(vbox)

	# Live preview: the weapon icon tinted with this skin's color, plus a
	# texture overlay (stripes + sheen) so it reads as an actual skin
	# rather than a flat color swap.
	var icon_box := Control.new()
	icon_box.custom_minimum_size = Vector2(0, 70)
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var skin_color: Color = skin.get("color", Color.WHITE)
	var icon = ItemIconScene.instantiate()
	icon.icon_key = weapon_type
	icon.icon_color = skin_color
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.add_child(icon)
	var overlay := Control.new()
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_script(SkinTextureOverlayScript)
	overlay.skin_color = skin_color
	icon_box.add_child(overlay)
	vbox.add_child(icon_box)

	var weapon_lbl := Label.new()
	weapon_lbl.text = weapon_type.capitalize()
	weapon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_lbl.add_theme_font_size_override("font_size", 10)
	weapon_lbl.modulate = Color(1, 1, 1, 0.6)
	vbox.add_child(weapon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = str(skin.get("name", "Skin"))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_lbl)

	var buy_btn := Button.new()
	buy_btn.custom_minimum_size = Vector2(0, 30)
	buy_btn.add_theme_font_size_override("font_size", 11)
	buy_btn.disabled = true
	buy_btn.text = "Owned" if already_owned else str(skin.get("premium_price", ""))
	if not already_owned:
		buy_btn.tooltip_text = "Real-money purchases aren't available - use Purchase with Rubles below instead."
	var buy_sb := StyleBoxFlat.new()
	buy_sb.bg_color = Color(0.15, 0.35, 0.15, 0.9) if already_owned else Color(0.1, 0.3, 0.5, 0.9)
	buy_sb.border_color = Color(0.5, 0.9, 0.5, 1) if already_owned else Color(0.5, 0.75, 1.0, 1)
	buy_sb.set_border_width_all(1)
	buy_sb.set_corner_radius_all(5)
	buy_btn.add_theme_stylebox_override("normal", buy_sb)
	buy_btn.add_theme_stylebox_override("disabled", buy_sb)
	buy_btn.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 1))
	buy_btn.add_theme_color_override("font_disabled_color", Color(0.75, 1.0, 0.75, 1) if already_owned else Color(0.7, 0.82, 0.95, 0.75))
	vbox.add_child(buy_btn)

	if not already_owned:
		var rubles_cost: int = GameManager.dollar_price_to_rubles(str(skin.get("premium_price", "$4.99")))
		var rubles_btn := Button.new()
		rubles_btn.custom_minimum_size = Vector2(0, 30)
		rubles_btn.add_theme_font_size_override("font_size", 11)
		rubles_btn.text = "Buy: %d Rubles" % rubles_cost
		rubles_btn.pressed.connect(_on_buy_skin_with_rubles.bind(skin_id, weapon_type, rubles_cost))
		var rubles_sb := StyleBoxFlat.new()
		rubles_sb.bg_color = Color(0.3, 0.24, 0.08, 0.9)
		rubles_sb.border_color = Color(1.0, 0.85, 0.4, 1)
		rubles_sb.set_border_width_all(1)
		rubles_sb.set_corner_radius_all(5)
		rubles_btn.add_theme_stylebox_override("normal", rubles_sb)
		var rubles_sb_hover := rubles_sb.duplicate()
		rubles_sb_hover.bg_color = Color(0.38, 0.3, 0.1, 0.95)
		rubles_btn.add_theme_stylebox_override("hover", rubles_sb_hover)
		rubles_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7, 1))
		vbox.add_child(rubles_btn)

	return card

func _on_buy_skin_with_rubles(skin_id: String, weapon_type: String, cost: int) -> void:
	GameManager.purchase_skin_with_rubles(skin_id, weapon_type, cost)
	Sfx.play_reveal()
	refresh()

func _on_buy_pack(pack_id: String) -> void:
	GameManager.purchase_store_pack(pack_id)
	Sfx.play_reveal()
	refresh()

func _on_buy_pack_with_rubles(pack_id: String) -> void:
	GameManager.purchase_store_pack_with_rubles(pack_id)
	Sfx.play_reveal()
	refresh()

func _on_claim_free_pack(pack_id: String) -> void:
	if GameManager.claim_free_store_pack(pack_id):
		Sfx.play_reveal()
		refresh()

# --- Rose's Free Pack: a pink-tinted card with a few small procedural
# boba tea cups drawn via draw_circle/draw_rect on custom Control nodes,
# each fading modulate:a in and out on its own randomized-delay loop
# (same "bind_node + set_loops + tween_property(modulate:a)" pattern
# used everywhere else in this codebase for ambient loops - see
# GhostPasserBy.gd's flicker_tw / Corpse.gd's glow_tween) so the handful
# of copies don't all pulse in sync.
func _style_rose_free_pack_card(card: PanelContainer, vbox: VBoxContainer) -> void:
	var sb := card.get_theme_stylebox("panel") as StyleBoxFlat
	if sb:
		var pink_sb := sb.duplicate()
		pink_sb.bg_color = Color(0.35, 0.14, 0.24, 0.88)
		pink_sb.border_color = Color(1.0, 0.55, 0.8, 0.85)
		card.add_theme_stylebox_override("panel", pink_sb)

	# A plain (non-Container) overlay sized to fill the card - its own
	# rect gets managed by the PanelContainer like any other child, but
	# ITS children keep whatever manual position/size we give them,
	# unlike direct children of the PanelContainer itself.
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	card.add_child(overlay)

	var boba_count := 4
	for i in range(boba_count):
		var boba := Control.new()
		boba.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boba.size = Vector2(16, 20)
		boba.position = Vector2(randf_range(10, 160), randf_range(20, 280))
		boba.z_index = 5
		boba.modulate.a = 0.0
		boba.draw.connect(_draw_boba_cup.bind(boba))
		overlay.add_child(boba)
		boba.queue_redraw()

		var boba_tw := boba.create_tween()
		boba_tw.bind_node(boba)
		boba_tw.set_loops()
		boba_tw.tween_interval(randf_range(0.0, 2.0))
		boba_tw.tween_property(boba, "modulate:a", 0.8, randf_range(1.4, 2.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		boba_tw.tween_property(boba, "modulate:a", 0.0, randf_range(1.4, 2.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		boba_tw.tween_interval(randf_range(0.3, 1.2))

func _draw_boba_cup(boba: Control) -> void:
	# Simple rounded cup shape + a few "pearl" dots at the bottom.
	var cup_color := Color(0.95, 0.75, 0.85, 0.9)
	var tea_color := Color(0.65, 0.35, 0.25, 0.85)
	var pearl_color := Color(0.15, 0.08, 0.06, 0.9)
	boba.draw_rect(Rect2(1, 4, 14, 16), cup_color, true)
	boba.draw_rect(Rect2(2, 8, 12, 12), tea_color, true)
	boba.draw_rect(Rect2(0, 2, 16, 3), cup_color, true)
	for px in [4, 8, 12]:
		boba.draw_circle(Vector2(px, 18), 1.6, pearl_color)

func _on_monthly() -> void:
	if GameManager.purchase_monthly_pass_with_rubles():
		Sfx.play_reveal()
		refresh()

func _on_double_xp() -> void:
	if GameManager.purchase_double_xp():
		Sfx.play_reveal()
		refresh()

func _on_fast_hatching() -> void:
	if GameManager.purchase_fast_hatching():
		Sfx.play_reveal()
		refresh()

func _make_pet_pack_card(pack: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(170, 180)
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.08, 0.1, 0.08, 0.85)
	card_sb.border_color = Color(0.3, 0.55, 0.35, 0.7)
	card_sb.set_border_width_all(1)
	card_sb.set_corner_radius_all(8)
	card_sb.content_margin_left = 10
	card_sb.content_margin_right = 10
	card_sb.content_margin_top = 10
	card_sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", card_sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	var title := Label.new()
	title.text = str(pack.get("label", "Pack"))
	title.add_theme_font_size_override("font_size", 14)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(title)

	var eggs: Dictionary = pack.get("eggs", {})
	var desc_bits: Array = []
	for rarity in eggs:
		desc_bits.append("%dx %s Egg" % [int(eggs[rarity]), GameManager.get_rarity_label(rarity)])
	if pack.get("grants_pet_case", false):
		desc_bits.append("Grid storage for every pet you own")
	if pack.has("grants_pet_rarity"):
		desc_bits.append("1x Guaranteed %s Pet" % GameManager.get_rarity_label(pack["grants_pet_rarity"]))
	var desc := Label.new()
	desc.text = "\n".join(desc_bits)
	desc.add_theme_font_size_override("font_size", 11)
	desc.modulate = Color(1, 1, 1, 0.8)
	vbox.add_child(desc)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var buy_btn := Button.new()
	buy_btn.text = str(pack.get("price", "$0.99"))
	buy_btn.custom_minimum_size = Vector2(0, 32)
	buy_btn.disabled = true
	buy_btn.tooltip_text = "Real-money purchases aren't available - use Purchase with Rubles below instead."
	vbox.add_child(buy_btn)

	var rubles_cost: int = GameManager.dollar_price_to_rubles(str(pack.get("price", "$0.99")))
	var rubles_btn := Button.new()
	rubles_btn.text = "Buy: %d Rubles" % rubles_cost
	rubles_btn.custom_minimum_size = Vector2(0, 32)
	rubles_btn.add_theme_font_size_override("font_size", 12)
	var rb_sb := StyleBoxFlat.new()
	rb_sb.bg_color = Color(0.3, 0.24, 0.08, 0.9)
	rb_sb.border_color = Color(1.0, 0.85, 0.4, 1)
	rb_sb.set_border_width_all(1)
	rb_sb.set_corner_radius_all(5)
	rubles_btn.add_theme_stylebox_override("normal", rb_sb)
	rubles_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7, 1))
	rubles_btn.pressed.connect(func():
		GameManager.purchase_pet_pack_with_rubles(pack.get("id", ""), rubles_cost)
		Sfx.play_reveal()
		refresh()
	)
	vbox.add_child(rubles_btn)
	return card

func _make_skill_point_pack_card(pack: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(170, 130)
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.08, 0.1, 0.14, 0.85)
	card_sb.border_color = Color(0.4, 0.65, 0.95, 0.8)
	card_sb.set_border_width_all(1)
	card_sb.set_corner_radius_all(8)
	card_sb.content_margin_left = 10
	card_sb.content_margin_right = 10
	card_sb.content_margin_top = 10
	card_sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", card_sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	var icon_box := Control.new()
	icon_box.custom_minimum_size = Vector2(0, 40)
	var icon = ItemIconScene.instantiate()
	icon.icon_key = "skill_points_item"
	icon.icon_color = Color(0.55, 0.78, 1.0, 1)
	icon.custom_minimum_size = Vector2(40, 40)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_box.add_child(icon)
	vbox.add_child(icon_box)

	var title := Label.new()
	title.text = "%d Skill Points" % int(pack.get("amount", 0))
	title.add_theme_font_size_override("font_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var buy_btn := Button.new()
	buy_btn.text = "%d Rubles" % int(pack.get("cost", 0))
	buy_btn.custom_minimum_size = Vector2(0, 32)
	buy_btn.add_theme_font_size_override("font_size", 12)
	buy_btn.pressed.connect(func():
		if GameManager.purchase_skill_point_pack(str(pack.get("id", ""))):
			Sfx.play_reveal()
			refresh()
	)
	vbox.add_child(buy_btn)
	return card

func _on_premium_pet() -> void:
	if GameManager.purchase_premium_pet():
		Sfx.play_reveal()
		refresh()

# --- Free Starter Pack: rebuilt each refresh() so the button always
# reflects the current state, then just has its countdown text updated
# every frame via _update_starter_pack_card() while open.
var _starter_pack_claim_button: Button = null
var _starter_pack_status_label: Label = null

func _build_starter_pack_card() -> void:
	for c in starter_pack_container.get_children():
		starter_pack_container.remove_child(c)
		c.queue_free()

	var card := PanelContainer.new()
	card.anchor_right = 1.0
	card.anchor_bottom = 1.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.16, 0.09, 0.92)
	sb.border_color = Color(0.5, 0.95, 0.55, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)
	starter_pack_container.add_child(card)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	card.add_child(hbox)

	var icon_box := Control.new()
	icon_box.custom_minimum_size = Vector2(64, 64)
	var icon = ItemIconScene.instantiate()
	icon.icon_key = "lootbag"
	icon.icon_color = Color(0.55, 0.95, 0.6, 1)
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon_box.add_child(icon)
	hbox.add_child(icon_box)

	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(text_vbox)

	var title := Label.new()
	title.text = "FREE Starter Pack"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.65, 1.0, 0.7, 1))
	text_vbox.add_child(title)

	var desc := Label.new()
	desc.text = "1,500 Rubles - 2 Skill Points - a gear piece, a material, and a Common Pet Egg"
	desc.add_theme_font_size_override("font_size", 12)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.modulate = Color(1, 1, 1, 0.85)
	text_vbox.add_child(desc)

	_starter_pack_status_label = Label.new()
	_starter_pack_status_label.add_theme_font_size_override("font_size", 11)
	_starter_pack_status_label.modulate = Color(1, 1, 1, 0.6)
	text_vbox.add_child(_starter_pack_status_label)

	_starter_pack_claim_button = Button.new()
	_starter_pack_claim_button.custom_minimum_size = Vector2(120, 44)
	_starter_pack_claim_button.add_theme_font_size_override("font_size", 14)
	_starter_pack_claim_button.pressed.connect(_on_claim_starter_pack)
	hbox.add_child(_starter_pack_claim_button)

	_update_starter_pack_card()

func _update_starter_pack_card() -> void:
	if _starter_pack_claim_button == null or not is_instance_valid(_starter_pack_claim_button):
		return
	if GameManager.starter_pack_available():
		_starter_pack_claim_button.text = "Claim"
		_starter_pack_claim_button.disabled = false
		_starter_pack_status_label.text = "Ready to claim!"
	else:
		var secs := int(GameManager.starter_pack_seconds_left())
		_starter_pack_claim_button.text = "Claim"
		_starter_pack_claim_button.disabled = true
		_starter_pack_status_label.text = "Next one in %d:%02d" % [int(secs / 60.0), secs % 60]

func _on_claim_starter_pack() -> void:
	if GameManager.claim_starter_pack():
		Sfx.play_reveal()
		refresh()
