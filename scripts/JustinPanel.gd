extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		closed.emit()

const ItemIconScene := preload("res://scenes/ItemIcon.tscn")

@onready var vbox: VBoxContainer = $VBox
@onready var title_label: Label = $VBox/Title
@onready var subtitle_label: Label = $VBox/Subtitle
@onready var list_scroll: ScrollContainer = $VBox/ListScroll
@onready var engram_list: VBoxContainer = $VBox/ListScroll/EngramList
@onready var result_box: PanelContainer = $VBox/ResultBox
@onready var result_particles: Control = $VBox/ResultBox/ResultParticles
@onready var result_icon_slot: Control = $VBox/ResultBox/VBox/IconSlot
@onready var result_name: Label = $VBox/ResultBox/VBox/ResultName
@onready var result_rarity: Label = $VBox/ResultBox/VBox/ResultRarity
@onready var close_button: Button = $VBox/CloseButton

var deciphering: bool = false
var mode: String = "decipher"
var lore_page: int = 0

# Justin's backstory - a couple of pages, told first-person, revealed
# one page at a time via the Talk to Justin option. You can close the
# window at any point, no need to read through all of it in one go.
const LORE_PAGES := [
	"Bro, before all this, I was seventeen and my whole life was a couch, a headset, and two idiots named Jay and James. Ong that was the whole world back then.\n\nWe queued Duos when it was just us, Trios when James's connection wasn't garbage, and we had a rule - nobody logs off before at least one Victory Royale, even if it's 4 A.M. and someone's mom is yelling up the stairs. Non-negotiable, bro.\n\nJay called rotations. Always. Even when he was wrong - especially when he was wrong - he'd call it with so much confidence me and James just went along with it, haha. Half our wins were pure accident dressed up as a plan.",
	"There was this one game, bro, I still think about it ong. Storm's closing, we're third-partying a fight we had no business being anywhere near, and James panic-builds a 1x1 in the open instead of taking the high ground like a person with functioning eyes.\n\nJay's screaming rotations at both of us. I'm out of mats, down to a gray pump and a prayer, and somehow - somehow - we clip the last squad with like four seconds of storm left. James still swears it was skill. Bro it was NOT skill. It was three idiots too stubborn to disconnect, haha.\n\nWe never got that clip saved. Of course we didn't. The one that actually mattered and none of us hit record. Classic.",
	"James had this bit where he'd call every single rotation \"the last one\" and then immediately call another one, bro, every time. Jay kept a tally at one point - forty-one \"last rotations\" in a single session, ong, I'm not exaggerating. We still bring it up. Well. I still bring it up. Out loud. To nobody. Haha.",
	"Jay's setup was held together with duct tape and spite, bro - a chair with one working wheel, a monitor that flickered if you looked at it wrong. Never upgraded anything either. Said if he got better gear he'd lose his edge, like the lag was load-bearing for his whole personality. Ngl he might've been right though, he was scary good on a bad connection.",
	"We had a whole ranking system for how embarrassing a death was, this was serious business bro. Fall damage was the worst - automatic week of mockery. Getting third-partied was forgivable, everyone gets third-partied. But getting knocked by a bot? Career-ending. No appeals process. Screenshot mandatory or it didn't happen, haha.",
	"James quit builder pro for like two weeks once because he swore it was \"rigged.\" Bro it was not rigged, he just kept forgetting the keybind. Me and Jay let him believe it was rigged way longer than we should've ong, because watching him rage-quit turtle fights was funnier than just telling him the truth.",
	"There's a version of that year where none of it mattered - just three kids yelling about rotations until someone's parents told them to go to bed, haha. I didn't know yet that I'd remember every single detail of it. You don't, when you're in it, bro. You just think there's gonna be more of it.",
	"I don't build anymore. Nothing left standing worth building on, and honestly my hands remember the muscle memory more than my head does at this point. But the reflexes stuck. The pattern-reading stuck ong. Figuring out an engram's structure isn't that different from reading a fight - you're just looking for the shape underneath the noise until it clicks, bro.",
	"Some nights, working late on the rig, I catch myself narrating what I'm doing like I'm calling a rotation, haha. Old habit. Don't even notice until I hear my own voice doing it. Nobody's listening. That's kind of the point, bro, and kind of the problem.",
	"I don't know where Jay ended up, or James. Ong I like to think Jay's still calling rotations somewhere, still wrong half the time, still somehow making it work. If either of them ever walks through that door - tell them the rig's got a spare chair and I'm still not logging off before a win, bro.",
]

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())
	result_particles.set_script(load("res://scripts/TooltipParticles.gd"))
	# Same known Godot quirk as PlushiePetReveal.gd - attaching a script
	# to an already-in-tree node drops process callbacks even though
	# the script's own _ready() calls set_process(true).
	result_particles.set_process(true)
	result_box.visible = false
	_build_mode_row()
	_build_lore_view()

# --- Mode toggle: Decipher Engrams (the original functionality) vs
# Talk to Justin (his lore). Built in code so the existing scene file
# doesn't need hand-edited node trees.
func _build_mode_row() -> void:
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var decipher_btn := Button.new()
	decipher_btn.text = "Decipher Engrams"
	decipher_btn.custom_minimum_size = Vector2(170, 36)
	decipher_btn.pressed.connect(func(): _set_mode("decipher"))
	mode_row.add_child(decipher_btn)
	var talk_btn := Button.new()
	talk_btn.text = "Talk to Justin"
	talk_btn.custom_minimum_size = Vector2(170, 36)
	talk_btn.pressed.connect(func(): _set_mode("lore"))
	mode_row.add_child(talk_btn)
	vbox.add_child(mode_row)
	vbox.move_child(mode_row, subtitle_label.get_index() + 1)

func _build_lore_view() -> void:
	var lore_scroll := ScrollContainer.new()
	lore_scroll.name = "LoreScroll"
	lore_scroll.custom_minimum_size = Vector2(0, 200)
	lore_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var lore_label := RichTextLabel.new()
	lore_label.name = "LoreLabel"
	lore_label.fit_content = true
	lore_label.bbcode_enabled = false
	lore_label.add_theme_font_size_override("normal_font_size", 15)
	lore_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lore_scroll.add_child(lore_label)
	vbox.add_child(lore_scroll)
	vbox.move_child(lore_scroll, list_scroll.get_index() + 1)

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
	vbox.move_child(lore_nav, lore_scroll.get_index() + 1)

	lore_scroll.visible = false
	lore_nav.visible = false

func _set_mode(new_mode: String) -> void:
	mode = new_mode
	var lore_scroll: ScrollContainer = vbox.get_node("LoreScroll")
	var lore_nav: HBoxContainer = vbox.get_node("LoreNav")
	if mode == "lore":
		title_label.text = "JUSTIN"
		subtitle_label.text = "\"Bro, before all this, I was seventeen...\""
		list_scroll.visible = false
		result_box.visible = false
		lore_scroll.visible = true
		lore_nav.visible = true
		lore_page = 0
		_refresh_lore_page()
	else:
		title_label.text = "JUSTIN'S DECOMPILATION RIG"
		subtitle_label.text = "Bring him Engrams from the Bloodline Gauntlet and he'll decipher them."
		list_scroll.visible = true
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
	result_box.visible = false
	_set_mode("decipher")
	GameManager.focus_first_control(self)
	PanelOpenFX.animate_open(self)

func refresh() -> void:
	for c in engram_list.get_children():
		engram_list.remove_child(c)
		c.queue_free()
	if GameManager.engrams.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No Engrams yet - find them in the Bloodline Gauntlet."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		engram_list.add_child(empty_lbl)
		return
	for i in range(GameManager.engrams.size()):
		engram_list.add_child(_make_engram_row(i))

func _make_engram_row(index: int) -> Control:
	var engram: Dictionary = GameManager.engrams[index]
	var rarity: String = engram.get("rarity", "common")
	var rarity_color: Color = GameManager.get_rarity_color(rarity)

	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 62)
	row.tooltip_text = "Bring this to Justin at the Hideout to decipher."
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.1, 0.85)
	sb.border_color = rarity_color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	row.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)

	var name_lbl := Label.new()
	name_lbl.text = str(engram.get("name", "Engram"))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", rarity_color)
	hbox.add_child(name_lbl)

	var decipher_btn := Button.new()
	decipher_btn.custom_minimum_size = Vector2(130, 0)
	decipher_btn.text = "Decipher"
	decipher_btn.disabled = deciphering
	decipher_btn.pressed.connect(func(): _on_decipher(index))
	hbox.add_child(decipher_btn)

	return row

func _on_decipher(index: int) -> void:
	if deciphering:
		return
	deciphering = true
	result_box.visible = false
	await _play_decipher_animation()
	var result := GameManager.decipher_engram(index)
	deciphering = false
	refresh()
	if not result.is_empty():
		_show_result(result)

func _play_decipher_animation() -> void:
	Sfx.play_engram_decipher()
	var flash := ColorRect.new()
	flash.color = Color(0.7, 0.15, 0.9, 0.0)
	flash.anchor_right = 1.0
	flash.anchor_bottom = 1.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.35, 0.15)
	tw.tween_property(flash, "color:a", 0.0, 0.35)
	await tw.finished
	Sfx.play_reveal()
	flash.queue_free()

func _show_result(item: Dictionary) -> void:
	for c in result_icon_slot.get_children():
		result_icon_slot.remove_child(c)
		c.queue_free()
	var rarity: String = item.get("rarity", "legendary")
	var rarity_color: Color = GameManager.get_rarity_color(rarity)
	var gradient_colors: Array = GameManager.get_gradient_colors(rarity)
	var is_top_tier: bool = gradient_colors.size() > 0

	if is_top_tier:
		var border = GameManager.make_gradient_border(rarity)
		if border != null:
			result_icon_slot.add_child(border)
	else:
		var flat_border := ColorRect.new()
		flat_border.color = rarity_color
		flat_border.anchor_right = 1.0
		flat_border.anchor_bottom = 1.0
		flat_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		result_icon_slot.add_child(flat_border)

	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.1, 0.92)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.offset_left = 3
	bg.offset_top = 3
	bg.offset_right = -3
	bg.offset_bottom = -3
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_icon_slot.add_child(bg)

	var icon = ItemIconScene.instantiate()
	icon.icon_key = item.get("icon_key", "generic")
	icon.icon_color = rarity_color
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.offset_left = 6
	icon.offset_top = 6
	icon.offset_right = -6
	icon.offset_bottom = -6
	result_icon_slot.add_child(icon)

	result_name.text = str(item.get("name", "?"))
	result_name.add_theme_color_override("font_color", rarity_color)
	result_rarity.text = GameManager.get_rarity_label(rarity).to_upper()
	result_rarity.add_theme_color_override("font_color", rarity_color)

	result_particles.gradient_colors = gradient_colors
	result_particles.particle_color = rarity_color
	result_particles.intensity = 26
	result_particles._init_particles()

	result_box.visible = true
	result_box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(result_box, "modulate:a", 1.0, 0.3)
