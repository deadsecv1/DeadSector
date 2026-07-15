extends Control

# A single draggable item tile inside a free-form inventory grid. Works for
# BOTH the out-of-run Stash (source="stash") and the in-run Backpack
# (source="carried") by tagging its drag payload accordingly.
# Supports: click to equip, drag to reposition, or drop onto a matching
# equipment slot to equip.

signal vicinity_claim_requested(index: int)
signal context_menu_requested(index: int, source: String, item: Dictionary, at_position: Vector2)
signal quick_sell_toggled(index: int)

const CELL_CARRIED := 54.0
const CELL_STASH := 42.0
const CELL_BACKPACK_STORAGE := 42.0
const ItemIconScene := preload("res://scenes/ItemIcon.tscn")
const GlowTraceBorderScript := preload("res://scripts/GlowTraceBorder.gd")
const CaseMarkerBadgeScript := preload("res://scripts/CaseMarkerBadge.gd")
const RotatingGradientBorderScript := preload("res://scripts/RotatingGradientBorder.gd")
const TwinkleStarBorderScript := preload("res://scripts/TwinkleStarBorder.gd")
const TooltipParticlesScript := preload("res://scripts/TooltipParticles.gd")
const CASE_SLOTS := ["lootbag", "pet_case"]

const DIVINE_GOLD := Color(1.0, 0.85, 0.2, 1.0)
const DIVINE_BLACK := Color(0.05, 0.05, 0.05, 1.0)
const CHROME_WHITE := Color(1.0, 1.0, 1.0, 1.0)
const CHROME_BLACK := Color(0.05, 0.05, 0.05, 1.0)

var stash_index: int = -1
var item: Dictionary = {}
var did_drag: bool = false
var source: String = "stash"
var quick_sell_mode: bool = false
var _hover_particles: Control = null
var _hover_glow_trace: Control = null

func _cell() -> float:
	if source == "stash":
		return CELL_STASH
	if source == "backpack_storage" or source.begins_with("case_"):
		return CELL_BACKPACK_STORAGE
	return CELL_CARRIED

func setup(p_index: int, p_item: Dictionary, p_source: String = "stash") -> void:
	stash_index = p_index
	item = p_item
	source = p_source
	var gx: int = int(item.get("grid_x", 0))
	var gy: int = int(item.get("grid_y", 0))
	var fp: Vector2i = GameManager.get_item_footprint(item) if source != "vicinity" else Vector2i(1, 1)
	var cell := _cell()
	position = Vector2(gx * cell + 1, gy * cell + 1)
	custom_minimum_size = Vector2(fp.x * cell - 2, fp.y * cell - 2)
	size = Vector2(fp.x * cell - 2, fp.y * cell - 2)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pivot_offset = size / 2.0
	mouse_entered.connect(_on_hover_enter)
	mouse_exited.connect(_on_hover_exit)
	if source == "vicinity":
		tooltip_text = "%s\n%s\nClick to stow in Backpack, or drag onto a slot to equip." % [item.get("name", "?"), _stat_text()]
	else:
		tooltip_text = "%s\n%s\nClick or drag onto a slot to equip." % [item.get("name", "?"), _stat_text()]

	var item_rarity: String = item.get("rarity", "")
	var is_alpha_beta: bool = item.get("alpha_only", false) or item.get("beta_only", false)

	# Gradient background + tracer is Multiversal-only now (it used to
	# apply to Exotic and Mythic too, but those two just get the normal
	# flat rarity-colored border below like everything else). Divine and
	# Alpha/Tech-Test exclusives each get their own completely distinct
	# treatment instead of sharing this one.
	if item_rarity == "divine":
		_setup_divine_visuals()
	elif item_rarity == "multiversal":
		_setup_multiversal_visuals()
	elif is_alpha_beta:
		_setup_alpha_beta_visuals()
	else:
		var flat_border := ColorRect.new()
		flat_border.color = GameManager.get_display_color(item)
		flat_border.anchor_right = 1.0
		flat_border.anchor_bottom = 1.0
		flat_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(flat_border)

	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.14, 0.13, 0.9)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.offset_left = 2
	bg.offset_top = 2
	bg.offset_right = -2
	bg.offset_bottom = -2
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var icon = ItemIconScene.instantiate()
	icon.icon_key = item.get("icon_key", "generic")
	icon.icon_color = GameManager.get_display_color(item)
	icon.position = Vector2(3, 3)
	icon.size = Vector2(fp.x * _cell() - 6, fp.y * _cell() - 6)
	icon.stretch_to_fill = true
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_spin_for_item(item)
	icon.set_tag_for_item(item)
	add_child(icon)

	if CASE_SLOTS.has(item.get("slot", "")):
		var badge := Control.new()
		badge.set_script(CaseMarkerBadgeScript)
		badge.badge_color = Color(0.55, 0.4, 0.95, 1) if item.get("slot", "") == "pet_case" else Color(0.9, 0.75, 0.3, 1)
		badge.custom_minimum_size = Vector2(14, 14)
		badge.size = Vector2(14, 14)
		badge.position = Vector2(1, 1)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(badge)

# The full-fill gradient background + a tracer in the item's own solid
# rarity color (gold). Same correct anchoring as GameManager.
# make_gradient_border() - expand_mode + a full-rect preset set AFTER
# the texture is assigned, since without both, this renders at its raw
# 128x128 texture size instead of filling the tile (that was the actual
# Alpha Rewards gradient bug from a few updates back).
func _setup_multiversal_visuals() -> void:
	var colors: Array = GameManager.get_gradient_colors("multiversal")
	var grad := Gradient.new()
	for i in range(colors.size()):
		grad.add_point(float(i) / float(max(1, colors.size() - 1)), colors[i])
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_LINEAR
	grad_tex.fill_from = Vector2(0, 0)
	grad_tex.fill_to = Vector2(1, 1)
	grad_tex.width = 128
	grad_tex.height = 128
	var border := TextureRect.new()
	border.texture = grad_tex
	border.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.stretch_mode = TextureRect.STRETCH_SCALE
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.clip_contents = true
	add_child(border)

	var trace := Control.new()
	trace.anchor_right = 1.0
	trace.anchor_bottom = 1.0
	trace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trace.set_script(GlowTraceBorderScript)
	trace.trace_color = GameManager.get_rarity_color("multiversal")
	trace.trace_speed = 55.0
	trace.trace_segments = 8
	add_child(trace)

# Divine's whole own look: gold border, a slow rotating gold shimmer
# behind the icon, gold ambient particles, small twinkling gold stars
# along the edge, and - the one deliberately different note - a BLACK
# tracer with its own black particles, so it doesn't just read as "an
# even shinier gold rarity" next to Multiversal.
func _setup_divine_visuals() -> void:
	var flat_border := ColorRect.new()
	flat_border.color = DIVINE_GOLD
	flat_border.anchor_right = 1.0
	flat_border.anchor_bottom = 1.0
	flat_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flat_border)

	var shimmer := Control.new()
	shimmer.anchor_right = 1.0
	shimmer.anchor_bottom = 1.0
	shimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shimmer.set_script(RotatingGradientBorderScript)
	shimmer.gradient_colors = [Color(1.0, 0.85, 0.2, 0.3), Color(1.0, 0.62, 0.08, 0.2), Color(1.0, 0.95, 0.65, 0.3)]
	shimmer.rotate_speed = 0.35
	add_child(shimmer)

	var gold_particles := Control.new()
	gold_particles.anchor_right = 1.0
	gold_particles.anchor_bottom = 1.0
	gold_particles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold_particles.set_script(TooltipParticlesScript)
	gold_particles.particle_color = DIVINE_GOLD
	gold_particles.intensity = 32
	add_child(gold_particles)

	var stars := Control.new()
	stars.anchor_right = 1.0
	stars.anchor_bottom = 1.0
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars.set_script(TwinkleStarBorderScript)
	stars.star_color = DIVINE_GOLD
	stars.star_count = 5
	add_child(stars)

	var trace := Control.new()
	trace.anchor_right = 1.0
	trace.anchor_bottom = 1.0
	trace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trace.set_script(GlowTraceBorderScript)
	trace.trace_color = DIVINE_BLACK
	trace.trace_speed = 55.0
	trace.trace_segments = 8
	add_child(trace)

	var black_particles := Control.new()
	black_particles.anchor_right = 1.0
	black_particles.anchor_bottom = 1.0
	black_particles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black_particles.set_script(TooltipParticlesScript)
	black_particles.particle_color = DIVINE_BLACK
	black_particles.intensity = 16
	add_child(black_particles)

# Alpha/Tech-Test exclusives: a continuously rotating black/white
# gradient behind the icon at all times, plus a tracer that cycles
# smoothly between white and black instead of holding one color - the
# particles and the tracer's glow are hover-only (see _on_hover_enter/
# _on_hover_exit below), so the tile stays a bit calmer until you're
# actually looking at it.
func _setup_alpha_beta_visuals() -> void:
	var rotating_bg := Control.new()
	rotating_bg.anchor_right = 1.0
	rotating_bg.anchor_bottom = 1.0
	rotating_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotating_bg.set_script(RotatingGradientBorderScript)
	rotating_bg.gradient_colors = [Color(1, 1, 1, 0.3), Color(0.05, 0.05, 0.05, 0.3), Color(0.7, 0.7, 0.7, 0.3)]
	rotating_bg.rotate_speed = 0.5
	add_child(rotating_bg)

	var trace := Control.new()
	trace.anchor_right = 1.0
	trace.anchor_bottom = 1.0
	trace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trace.set_script(GlowTraceBorderScript)
	trace.trace_color = CHROME_WHITE
	trace.cycle_colors = [CHROME_WHITE, CHROME_BLACK]
	trace.cycle_speed = 0.35
	trace.trace_speed = 55.0
	trace.trace_segments = 8
	add_child(trace)
	_hover_glow_trace = trace

	var particles := Control.new()
	particles.anchor_right = 1.0
	particles.anchor_bottom = 1.0
	particles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	particles.set_script(TooltipParticlesScript)
	particles.gradient_colors = [CHROME_WHITE, CHROME_BLACK]
	particles.intensity = 26
	particles.visible = false
	add_child(particles)
	_hover_particles = particles

func _stat_text() -> String:
	var parts: Array = []
	var primary := _format_stat(item.get("stat_type", ""), item.get("stat_value", 0.0))
	if primary != "":
		parts.append(primary)
	var secondary := _format_stat(item.get("stat_type_2", ""), item.get("stat_value_2", 0.0))
	if secondary != "":
		parts.append(secondary)
	return ", ".join(parts)

func _format_stat(stat_type: String, stat_value) -> String:
	match stat_type:
		"speed":
			return "+%s Speed" % stat_value
		"max_health":
			return "+%s Health" % stat_value
		"damage":
			return "+%s Damage" % stat_value
		"fire_rate":
			return "+%s Fire Rate" % stat_value
		"loot_sense":
			return "+%s%% Loot Sense" % snapped(float(stat_value) * 100.0, 0.1)
		"crit_chance":
			return "+%s%% Crit Chance" % snapped(float(stat_value) * 100.0, 0.1)
		"vision_range":
			return "+%s Vision Range" % stat_value
		"reload_speed":
			return "+%ss Reload Speed" % stat_value
		"health_regen":
			return "+%s HP/s Regen" % stat_value
		"armor":
			return "+%s%% Armor" % stat_value
		"ammo_reserve":
			return "+%s Reserve Ammo" % stat_value
		_:
			return ""

func _make_custom_tooltip(_for_text: String) -> Control:
	return ItemTooltip.build(item)

var _last_click_time_ms: int = -999999
const DOUBLE_CLICK_WINDOW_MS := 400

func _get_drag_data(_at_position: Vector2) -> Variant:
	# Double-click detection lives here rather than on the mouse-release
	# event in _gui_input - Godot calls _get_drag_data() on essentially
	# any motion during a press, and a fast double-click's second click
	# almost always has a tiny bit of drift, which was silently
	# swallowing the release event before _gui_input ever saw it. A
	# genuine single-press drag always still returns valid data below -
	# an earlier attempt to gate that on movement distance ended up
	# blocking real drags entirely, since Godot doesn't appear to retry
	# _get_drag_data() again later in the same press-and-hold gesture
	# once it's said no. Only a confirmed double-click returns null,
	# and only after it's already done its job (see below).
	var now_ms := Time.get_ticks_msec()
	var is_double_click: bool = (now_ms - _last_click_time_ms) < DOUBLE_CLICK_WINDOW_MS
	_last_click_time_ms = now_ms
	if is_double_click and not quick_sell_mode:
		_last_click_time_ms = -999999
		_double_click_equip()
		# Equipping just triggered GameManager.equipped_changed, which
		# rebuilds the whole grid and destroys this exact tile (self) -
		# stop here instead of continuing to build a drag preview off
		# of a node/item that may no longer exist. The equip already
		# fully satisfied the gesture; there's nothing left to drag.
		return null

	did_drag = true
	var fp: Vector2i = GameManager.get_item_footprint(item) if source != "vicinity" else Vector2i(1, 1)
	var cell := _cell()
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(fp.x * cell - 4, fp.y * cell - 4)
	preview.modulate.a = 0.9
	var rarity_color: Color = GameManager.get_rarity_color(item.get("rarity", "common"))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	sb.border_color = rarity_color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	preview.add_theme_stylebox_override("panel", sb)
	var icon = ItemIconScene.instantiate()
	icon.icon_key = item.get("icon_key", "generic")
	icon.icon_color = rarity_color
	preview.add_child(icon)
	# set_drag_preview positions the preview's top-left AT the cursor by
	# default - offset it so the item appears centered under the cursor
	# instead of trailing off to the bottom-right.
	preview.position = -preview.custom_minimum_size / 2.0
	set_drag_preview(preview)
	return {"source": source, "index": stash_index}

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			did_drag = false
		else:
			if not did_drag:
				accept_event()
				if quick_sell_mode:
					quick_sell_toggled.emit(stash_index)
				elif source == "vicinity":
					vicinity_claim_requested.emit(stash_index)
				else:
					_handle_click_release(event.global_position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		accept_event()
		context_menu_requested.emit(stash_index, source, item, get_global_mouse_position())

# Double-click to equip - only makes sense for gear that actually goes
# in an equip slot (weapon/head/body/boots/backpack/accessory); other
# slot types (consumables, keys, valuables, etc.) just fall through and
# do nothing here, same as trying to drag them onto a doll slot would.
const EQUIPPABLE_SLOTS := ["weapon", "head", "body", "boots", "backpack", "accessory", "helmet_attachment"]

func _double_click_equip() -> void:
	if not EQUIPPABLE_SLOTS.has(item.get("slot", "")):
		return
	if source == "vicinity":
		GameManager.vicinity_equip(stash_index)
	elif source == "stash":
		GameManager.equip_item(stash_index)
	else:
		GameManager.equip_from_carried(stash_index)

# _get_drag_data() below catches a double-click whose SECOND press has
# enough motion for Godot to call it at all - the common case, since a fast
# double-click's second click almost always has a bit of drift. But a
# genuinely STILL double-click (no drift on either press) never triggers
# _get_drag_data() at all, so both releases land here via _gui_input()
# instead - and without handling it here too, the first release opened the
# info popup immediately, and that popup (sitting right where the cursor
# already is) ate the second click as an outside-click-to-dismiss before it
# ever had a chance to register as a double-click. This is the actual
# reason double-click-to-equip could fail regardless of the Stash refresh
# fix - it depended on luck (mouse drift) that not every click has.
#
# Fix: detect a double-click here too, off the SAME shared timestamp
# _get_drag_data() uses below, and delay the popup itself instead of
# opening it immediately - so even a click that doesn't match either check
# still can't beat a fast-arriving second click to the punch.
func _handle_click_release(at_position: Vector2) -> void:
	var now_ms := Time.get_ticks_msec()
	var is_double_click: bool = (now_ms - _last_click_time_ms) < DOUBLE_CLICK_WINDOW_MS
	_last_click_time_ms = now_ms
	if is_double_click:
		_last_click_time_ms = -999999
		_double_click_equip()
		return
	var my_stamp := now_ms
	get_tree().create_timer(DOUBLE_CLICK_WINDOW_MS / 1000.0).timeout.connect(func():
		# _last_click_time_ms only still equals my_stamp if nothing else
		# claimed this click as the first half of a double-click in the
		# meantime (that path resets it to -999999) - if a second click DID
		# arrive, skip the popup entirely instead of popping it up right as
		# (or after) the equip already happened.
		if not is_instance_valid(self) or _last_click_time_ms != my_stamp:
			return
		_show_click_popup(at_position)
	)

# Hovering already shows the tooltip via Godot's built-in system - this
# gives the same info on a click too, for anyone who'd rather click than
# hover (or is on a touch device where hovering doesn't really exist).
func _show_click_popup(at_position: Vector2) -> void:
	var popup := PopupPanel.new()
	# ItemTooltip.build() already draws its own rarity-colored bordered
	# panel - PopupPanel's default theme (dark fill + its own border) was
	# stacking behind that as a second, unwanted black frame around it.
	# Scoped to this one popup instance only, not the shared PopupPanel
	# theme type, so it doesn't affect other popups (e.g. PetDollSlot's
	# pet info popup) that actually rely on that default styling.
	popup.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	get_tree().current_scene.add_child(popup)
	var content := ItemTooltip.build(item)
	popup.add_child(content)
	popup.position = Vector2i(at_position) + Vector2i(16, 16)
	popup.popup()

	# Safety fallback in case mouse_exited never fires (e.g. the tile itself
	# gets freed/refreshed out from under the cursor, which is exactly what
	# double-click-equip does). Held in its own Callable, captured on its
	# own, so it only ever touches `popup` - never anything that could
	# already be gone by the time it fires.
	var fallback_timer := get_tree().create_timer(6.0)
	var fallback_close := func():
		if is_instance_valid(popup):
			popup.hide()
			popup.queue_free()
	fallback_timer.timeout.connect(fallback_close)

	# The common case: mouse_exited fires first, closes the popup right
	# away, AND detaches the fallback above so it's never left connected to
	# fire again later with `popup` already freed out from under it - that
	# leftover connection, not any actual crash risk, was the source of the
	# "Lambda capture ... was freed" spam, since Godot logs that the moment
	# a stale connection fires regardless of what the callback itself does.
	mouse_exited.connect(func():
		if is_instance_valid(popup):
			popup.hide()
			popup.queue_free()
		if is_instance_valid(fallback_timer) and fallback_timer.timeout.is_connected(fallback_close):
			fallback_timer.timeout.disconnect(fallback_close)
	, CONNECT_ONE_SHOT)

# A small, satisfying "pick me" hover reaction - scales up slightly and
# settles into a gentle back-and-forth wiggle for as long as the cursor
# stays over it, instead of just sitting there static.
var _hovered: bool = false
var _wiggle_time: float = 0.0

func _on_hover_enter() -> void:
	_hovered = true
	_wiggle_time = 0.0
	set_process(true)
	Sfx.play_item_hover()
	if _hover_particles != null:
		_hover_particles.visible = true
	if _hover_glow_trace != null:
		_hover_glow_trace.glow_boost = 1.0
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_hover_exit() -> void:
	_hovered = false
	set_process(false)
	if _hover_particles != null:
		_hover_particles.visible = false
	if _hover_glow_trace != null:
		_hover_glow_trace.glow_boost = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12)
	tw.tween_property(self, "rotation", 0.0, 0.12)

func _process(delta: float) -> void:
	if not _hovered:
		return
	_wiggle_time += delta * 9.0
	rotation = sin(_wiggle_time) * 0.045
