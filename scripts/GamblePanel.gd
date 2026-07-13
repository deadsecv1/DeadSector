extends Panel

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		closed.emit()

const ItemIconScene := preload("res://scenes/ItemIcon.tscn")
const SkinTextureOverlayScript := preload("res://scripts/SkinTextureOverlay.gd")

const TIER_ORDER := ["common", "rare", "legendary", "mythic", "exotic", "multiversal", "divine"]

@onready var vbox: VBoxContainer = $VBox
@onready var title_label: Label = $VBox/GambleTitle
@onready var rubles_label: Label = $VBox/RublesLabel
@onready var odds_label: Label = $VBox/OddsLabel
@onready var crate_area: Control = $VBox/CrateArea
@onready var crate_icon: Panel = $VBox/CrateArea/CrateIcon
@onready var buy_button: Button = $VBox/BuyButton
@onready var result_box: PanelContainer = $VBox/ResultBox
@onready var result_particles: Control = $VBox/ResultBox/ResultParticles
@onready var result_icon_slot: Control = $VBox/ResultBox/VBox/IconSlot
@onready var result_name: Label = $VBox/ResultBox/VBox/ResultName
@onready var result_rarity: Label = $VBox/ResultBox/VBox/ResultRarity
@onready var close_button: Button = $VBox/CloseButton

var opening: bool = false
var mode: String = "gamble"
var lore_page: int = 0

# The Undertow's backstory - told first-person, revealed one page at a
# time via the Talk to the Undertow option. Also the only one of the
# three Hideout regulars who doesn't have his act together.
const LORE_PAGES := [
	"I run the crates because somebody has to, and because I'm better at reading odds than anyone else down here. That's the story I tell people. The real one's simpler: I like the shake before the box opens more than I like almost anything else in my life, and that should probably worry me more than it does.\n\nJustin and Dirty think it's funny. It stops being funny around the fourth crate in a row that pays out in scrap.",
	"I wasn't always the guy with the boxes. Before, I did math - real math, the kind with a desk and a chair and a reason to show up. Turns out knowing the odds cold doesn't stop you from betting against them. If anything it makes it worse. I always know exactly how bad an idea it is. I open the crate anyway.",
	"There was a night - I don't even remember what tier I was chasing, Mythic maybe, Exotic if I'm being honest with myself - where I opened crates until the Rubles ran dry, then opened a few more I definitely didn't have covered. Justin found me at 4 AM still shaking the last empty box like it owed me something. He didn't say a word. Just sat down next to me until the sun came up.\n\nI paid him back. Eventually. He never brought it up again, which somehow made it worse.",
	"The mystery box isn't actually mysterious to me. I know the weights. I know the tiers. I could recite the odds table in my sleep - I have, apparently, according to Dirty, who says I talk in my sleep about crate percentages like it's a bedtime story. It doesn't help. Knowing the trick doesn't make the trick stop working on you.",
	"People assume the good pulls are what keep me doing this. They're not. The good pulls are almost disappointing - it's over too fast, the shake's already done its job. It's the bad ones that keep me coming back, weirdly. Something about needing the next one to make up for the last one. I know how that sounds.",
	"Dirty tried to get me to switch to just watching him do research instead, said it was \"the same rush, but productive.\" It is not the same rush. I sat there for ten minutes and then went and opened three crates just to feel normal again.",
	"I keep a little tally somewhere of my worst nights. Not to torture myself - well, maybe a little - but because it's the only thing that's ever actually made me stop for more than a week at a time. Doesn't work as well as I'd like. The tally's gotten long.",
	"Justin asked me once why I don't just stop selling crates if it's this bad for me. Told him if I stopped, someone worse at reading odds would do it instead, and at least I make sure nobody gets fully wiped out on my table. That's not really why. It's a good enough reason to say out loud, though.",
	"Most nights it's the three of us - me, Justin, Dirty - crowded around whatever's still got a working screen, playing Tarkov until someone rage-quits over a Scav kill. Dirty always extracts too early. Justin never extracts early enough. I mostly just die to the first footstep I hear and blame lag.\n\nIt's the closest thing to a break any of us get.",
	"I'd tell you to come find the three of us sometime, but honestly? Probably safer if you don't see how competitive it gets. Or how loud Dirty gets when he loses his kit. Or how long Justin argues that positioning, not luck, is what matters - coming from the guy who spends his nights staring at engrams looking for patterns in noise. We're all working something out down here. Mine just comes in a box.",
]

func _ready() -> void:
	visible = false
	# Full-screen panel (fills the whole viewport) - no draggable edges here, unlike the smaller centered popups.
	close_button.pressed.connect(func(): closed.emit())
	buy_button.pressed.connect(_on_buy)
	result_box.visible = false
	result_particles.set_script(load("res://scripts/TooltipParticles.gd"))
	# Same known Godot quirk as PlushiePetReveal.gd - attaching a script
	# to an already-in-tree node drops process callbacks even though
	# the script's own _ready() calls set_process(true).
	result_particles.set_process(true)
	_build_mode_row()
	_build_lore_view()

func _build_mode_row() -> void:
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var gamble_btn := Button.new()
	gamble_btn.text = "Gamble"
	gamble_btn.custom_minimum_size = Vector2(170, 34)
	gamble_btn.pressed.connect(func(): _set_mode("gamble"))
	mode_row.add_child(gamble_btn)
	var talk_btn := Button.new()
	talk_btn.text = "Talk to the Undertow"
	talk_btn.custom_minimum_size = Vector2(170, 34)
	talk_btn.pressed.connect(func(): _set_mode("lore"))
	mode_row.add_child(talk_btn)
	vbox.add_child(mode_row)
	vbox.move_child(mode_row, title_label.get_index() + 1)

func _build_lore_view() -> void:
	var lore_scroll := ScrollContainer.new()
	lore_scroll.name = "LoreScroll"
	lore_scroll.custom_minimum_size = Vector2(0, 300)
	lore_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var lore_label := RichTextLabel.new()
	lore_label.name = "LoreLabel"
	lore_label.fit_content = true
	lore_label.add_theme_font_size_override("normal_font_size", 15)
	lore_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lore_scroll.add_child(lore_label)
	vbox.add_child(lore_scroll)

	var lore_nav := HBoxContainer.new()
	lore_nav.name = "LoreNav"
	lore_nav.add_theme_constant_override("separation", 10)
	var prev_btn := Button.new()
	prev_btn.name = "PrevButton"
	prev_btn.text = "< Back"
	prev_btn.custom_minimum_size = Vector2(90, 36)
	prev_btn.pressed.connect(func(): _turn_lore_page(-1))
	lore_nav.add_child(prev_btn)
	var page_label := Label.new()
	page_label.name = "PageLabel"
	page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.modulate = Color(1, 1, 1, 0.6)
	lore_nav.add_child(page_label)
	var next_btn := Button.new()
	next_btn.name = "NextButton"
	next_btn.text = "Next >"
	next_btn.custom_minimum_size = Vector2(90, 36)
	next_btn.pressed.connect(func(): _turn_lore_page(1))
	lore_nav.add_child(next_btn)
	vbox.add_child(lore_nav)

	lore_scroll.visible = false
	lore_nav.visible = false
	vbox.move_child(lore_scroll, close_button.get_index())
	vbox.move_child(lore_nav, close_button.get_index())

func _set_mode(new_mode: String) -> void:
	mode = new_mode
	var lore_scroll: ScrollContainer = vbox.get_node("LoreScroll")
	var lore_nav: HBoxContainer = vbox.get_node("LoreNav")
	var gamble_nodes := [rubles_label, odds_label, crate_area, buy_button]
	if mode == "lore":
		title_label.text = "THE UNDERTOW"
		for n in gamble_nodes:
			n.visible = false
		result_box.visible = false
		lore_scroll.visible = true
		lore_nav.visible = true
		lore_page = 0
		_refresh_lore_page()
	else:
		title_label.text = "GAMBLE"
		for n in gamble_nodes:
			n.visible = true
		lore_scroll.visible = false
		lore_nav.visible = false
		refresh()

func _turn_lore_page(delta: int) -> void:
	lore_page = clamp(lore_page + delta, 0, LORE_PAGES.size() - 1)
	_refresh_lore_page()

func _refresh_lore_page() -> void:
	var lore_label: RichTextLabel = vbox.get_node("LoreScroll/LoreLabel")
	var page_label: Label = vbox.get_node("LoreNav/PageLabel")
	var prev_btn: Button = vbox.get_node("LoreNav/PrevButton")
	var next_btn: Button = vbox.get_node("LoreNav/NextButton")
	lore_label.text = LORE_PAGES[lore_page]
	page_label.text = "Page %d / %d" % [lore_page + 1, LORE_PAGES.size()]
	prev_btn.disabled = lore_page <= 0
	next_btn.disabled = lore_page >= LORE_PAGES.size() - 1

func open() -> void:
	visible = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	opening = false
	result_box.visible = false
	crate_area.visible = true
	buy_button.disabled = false
	crate_icon.rotation = 0.0
	crate_icon.scale = Vector2(1.0, 1.0)
	_build_odds_text()
	_set_mode("gamble")

func refresh() -> void:
	rubles_label.text = "Rubles: %d" % GameManager.rubles
	buy_button.text = "Buy & Open Crate (%d Rubles)" % GameManager.CRATE_COST
	buy_button.disabled = opening or GameManager.rubles < GameManager.CRATE_COST

func _build_odds_text() -> void:
	var lines: Array = []
	for tier in TIER_ORDER:
		var pct: float = GameManager.CRATE_ODDS.get(tier, 0.0)
		lines.append("%s: %.2f%%" % [GameManager.get_rarity_label(tier), pct])
	odds_label.text = " | ".join(lines)

func _on_buy() -> void:
	if opening:
		return
	if GameManager.rubles < GameManager.CRATE_COST:
		GameManager.toast_requested.emit("Not enough Rubles")
		return
	opening = true
	buy_button.disabled = true
	# Reset for a fresh opening - the crate and result panel from the
	# last purchase (if any) need to be hidden/reset first so you can
	# keep gambling on this same screen instead of having to leave and
	# come back.
	result_box.visible = false
	crate_area.visible = true
	crate_icon.rotation = 0.0
	crate_icon.scale = Vector2(1.0, 1.0)
	crate_icon.modulate.a = 1.0
	crate_icon.position = Vector2.ZERO
	await _play_open_animation()
	var item := GameManager.purchase_crate()
	opening = false
	refresh()
	if item.is_empty():
		return
	_show_result(item)

func _play_open_animation() -> void:
	Sfx.play_crate_open()
	var shake_tw := create_tween()
	for i in range(8):
		var offset := Vector2(randf_range(-6.0, 6.0), randf_range(-4.0, 4.0))
		shake_tw.tween_property(crate_icon, "position", offset, 0.05)
	shake_tw.tween_property(crate_icon, "position", Vector2.ZERO, 0.05)
	await shake_tw.finished

	var burst_tw := create_tween()
	burst_tw.tween_property(crate_icon, "scale", Vector2(1.6, 1.6), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	burst_tw.parallel().tween_property(crate_icon, "modulate:a", 0.0, 0.25)
	Sfx.play_reveal()
	await burst_tw.finished
	crate_area.visible = false

func _show_result(item: Dictionary) -> void:
	for c in result_icon_slot.get_children():
		result_icon_slot.remove_child(c)
		c.queue_free()
	var rarity: String = item.get("rarity", "common")
	var rarity_color: Color = GameManager.get_rarity_color(rarity)
	var gradient_colors: Array = GameManager.get_gradient_colors(rarity)
	var is_top_tier: bool = gradient_colors.size() > 0

	# A fixed-size square box, centered in the (wide, short) slot - keeps
	# the icon and its border a normal square shape instead of stretching
	# to fill the panel's full width.
	var box_size: float = result_icon_slot.size.y
	var icon_box := Control.new()
	icon_box.custom_minimum_size = Vector2(box_size, box_size)
	icon_box.anchor_left = 0.5
	icon_box.anchor_right = 0.5
	icon_box.anchor_top = 0.0
	icon_box.anchor_bottom = 0.0
	icon_box.offset_left = -box_size / 2.0
	icon_box.offset_right = box_size / 2.0
	icon_box.offset_bottom = box_size
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_icon_slot.add_child(icon_box)

	if is_top_tier:
		var border = GameManager.make_gradient_border(rarity)
		if border != null:
			icon_box.add_child(border)
	else:
		var flat_border := ColorRect.new()
		flat_border.color = rarity_color
		flat_border.anchor_right = 1.0
		flat_border.anchor_bottom = 1.0
		flat_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_box.add_child(flat_border)

	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.1, 0.92)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.offset_left = 3
	bg.offset_top = 3
	bg.offset_right = -3
	bg.offset_bottom = -3
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.add_child(bg)

	var icon = ItemIconScene.instantiate()
	icon.icon_key = item.get("icon_key", "generic")
	icon.icon_color = rarity_color
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.offset_left = 6
	icon.offset_top = 6
	icon.offset_right = -6
	icon.offset_bottom = -6
	icon_box.add_child(icon)

	if is_top_tier:
		var overlay := Control.new()
		overlay.anchor_right = 1.0
		overlay.anchor_bottom = 1.0
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.set_script(SkinTextureOverlayScript)
		overlay.skin_color = gradient_colors[1]
		icon_box.add_child(overlay)

	result_name.text = str(item.get("name", "?"))
	result_name.add_theme_color_override("font_color", gradient_colors[1] if is_top_tier else rarity_color)
	result_rarity.text = GameManager.get_rarity_label(rarity).to_upper()
	result_rarity.add_theme_color_override("font_color", gradient_colors[2] if is_top_tier else rarity_color)

	result_particles.gradient_colors = gradient_colors
	result_particles.particle_color = rarity_color
	result_particles.intensity = 30 if is_top_tier else 10
	result_particles._init_particles()

	result_box.visible = true
	result_box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(result_box, "modulate:a", 1.0, 0.3)

	if rarity == "divine":
		GameManager.toast_requested.emit("DIVINE! A 1-in-10,000 drop - the rarest thing in Dead Sector!")
	elif rarity == "multiversal":
		GameManager.toast_requested.emit("MULTIVERSAL! The rarest drop in the game!")
