extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		closed.emit()

const SmallIconScene := preload("res://scenes/SmallIcon.tscn")

# 10 real topics instead of one long linear ramble - Dirty will talk
# your ear off about any one of these in as much detail as you want.
const LORE_TOPICS := [
	{"id": "first_puddle", "title": "The First Puddle", "icon": "gear", "text": "Bro, before the Collapse, Dirty wasn't even dirty. Dirty was clean. Squeaky clean. Tragic, honestly, when you think about what was coming.\n\nThen one day, out past the old refinery, Dirty found a puddle. Not a special puddle. Just a puddle. And Dirty thought, and these are his words: \"what if I got IN the puddle, ong.\" That one decision is, by his own account, the whole reason any of this happened. He does not regret it, haha. He's very clear about that part."},
	{"id": "puddle_timeline", "title": "The Puddle Timeline", "icon": "compass", "text": "Turns out the first puddle was not an isolated event, bro. There is, according to Dirty, a whole documented Puddle Timeline - a personal chronology of every notable puddle, ditch, runoff channel, and \"regrettable basement\" that contributed meaningfully to his current state.\n\nHe insists this timeline is available for review \"if you ask nicely,\" ong, though nobody has ever actually seen it, and he changes the number of puddles every time he tells the story. Current count, as of this conversation: either 40 or 400, depending on his mood."},
	{"id": "dirt_prophecy", "title": "The Dirt Prophecy", "icon": "skull", "text": "There is, apparently, a prophecy, bro. Dirty swears he didn't make it up, though he also can't say who did. The gist: when Dirty reaches Maximum Dirtiness, the Sector itself will short-circuit.\n\nWhat \"short-circuit\" means in this context - environmental collapse, spontaneous combustion, something administrative - is left deliberately vague. Dirty seems less concerned with the specifics and more hyped about being, in his words, \"prophesied at all, ong.\""},
	{"id": "skin_specialists", "title": "The Skin Specialists", "icon": "medical", "text": "Justin apparently told Dirty he should \"get that looked at\" once. Dirty responded that he gets plenty looked at, thank you, by three separate skin specialists - all of whom, he'll happily tell you, eventually quit. Haha.\n\nHe considers this a point of pride rather than a red flag, bro. When pressed on what, exactly, they diagnosed before leaving, he changes the subject to the Puddle Timeline every time, without fail."},
	{"id": "great_wash", "title": "The Great Wash Incident", "icon": "medical", "text": "Once - allegedly only once - somebody tried to actually clean Dirty. Dragged him to a working shower, the old kind, with real water pressure. Dirty describes the whole thing as \"an act of violence, bro,\" and refuses to say who did it, only that \"they know what they did, ong.\"\n\nThe attempt reportedly failed, haha. Whether that's because the dirt in question is load-bearing at this point, or because Dirty simply left and found a new puddle immediately after, remains disputed depending on who's telling the story."},
	{"id": "dirty_vs_justin", "title": "Dirty vs. Justin", "icon": "cipher", "text": "Dirty and Justin have what can charitably be called a rivalry, and less charitably be called \"two guys who will not stop bringing each other up unprompted.\" Justin thinks Dirty's condition is a medical situation. Dirty thinks Justin's engrams are \"nerd puddles, but for the brain, bro.\"\n\nDespite this, they apparently split rent on the same corner of the Hideout for years before you showed up, and neither one has ever actually left. Haha."},
	{"id": "scientific_study", "title": "The Scientific Study", "icon": "tech", "text": "At some point, someone tried to actually measure how dirty Dirty is. Scientifically. With instruments. Dirty brings this up constantly and always with the exact same line: \"Scientists could not measure it, bro. They tried. Ong.\"\n\nNo further detail is ever offered - not what instruments, not who the scientists were, not what happened to them. Pressing for specifics just gets you the Puddle Timeline again, haha."},
	{"id": "what_dirty_sells", "title": "What Dirty Actually Does", "icon": "gear", "text": "Setting the bit aside for one second, bro: Dirty is, functionally, the only person in the Hideout who can take a Blueprint and turn it into something Mythic. Nobody's fully sure how - he insists it's \"a dirt thing\" - but the results speak for themselves.\n\nHe will absolutely still tell you about puddles while he does it, haha. There's no version of this transaction where that doesn't happen."},
	{"id": "dirtys_crate", "title": "The Legend of Dirty's Crate", "icon": "key", "text": "Dirty sits on a crate. Always the same crate. Nobody knows what's inside it, and Dirty has never once let anyone check, despite requests. He refers to it only as \"load-bearing\" and \"none of your business, bro,\" which are apparently interchangeable terms to him.\n\nThere's a running theory among the recruits that the crate contains either his life savings, his previous identity, or several more puddles' worth of backup dirt. Dirty has neither confirmed nor denied any of it, which he seems to find very funny. Haha."},
	{"id": "why_still_here", "title": "Why He's Still Talking", "icon": "contact", "text": "At this point in most conversations, Dirty pauses, looks around, and asks why you're still here. Then he answers his own question before you can: \"because the lore's good, bro, that's why. Ong.\" Then he keeps going anyway.\n\nBy his own admission, he's lost track of exactly how dirty he currently is - \"scientists could not measure it,\" remember - and he seems completely fine with that. If you're looking for a moral to any of this, Dirty would tell you there isn't one, and then immediately offer you one anyway if you ask twice."},
	{"id": "fourth_squad_member", "title": "The Fourth Squad Member", "icon": "squad", "text": "Here's a thing Dirty will only bring up if he thinks Justin isn't listening, bro. Turns out he knew Justin, Jay, and James back then too - used to beg to get a Trios invite bumped up to a Squad so he could fourth. Every single time, ong.\n\nProblem was, Dirty was, in his own words, \"mathematically the worst Fortnite player to ever queue,\" haha. Couldn't build, couldn't edit, died to fall damage more than actual enemies. Jay benched him so often he started just calling it \"getting Dirty'd.\" It caught on. Nobody remembers who came up with it.\n\nHe swears he's not bitter about it. He brings it up unprompted, constantly, always in the same breath as the Puddle Timeline, which - bro - is not what a guy who isn't bitter about it does. But he'll deny that if you say it to his face."},
]

@onready var title_label: Label = $VBox/Title
@onready var subtitle_label: Label = $VBox/Subtitle
@onready var menu_row: HBoxContainer = $VBox/MenuRow
@onready var research_button: Button = $VBox/MenuRow/ResearchButton
@onready var lore_button: Button = $VBox/MenuRow/LoreButton
@onready var empty_label: Label = $VBox/EmptyLabel
@onready var list_scroll: ScrollContainer = $VBox/ListScroll
@onready var blueprint_list: VBoxContainer = $VBox/ListScroll/BlueprintList
@onready var lore_topic_header: Label = $VBox/LoreTopicHeader
@onready var lore_topic_scroll: ScrollContainer = $VBox/LoreTopicScroll
@onready var lore_topic_list: VBoxContainer = $VBox/LoreTopicScroll/LoreTopicList
@onready var lore_label: Label = $VBox/LoreLabel
@onready var lore_detail_back_button: Button = $VBox/LoreDetailBackButton
@onready var back_button: Button = $VBox/BackButton
@onready var close_button: Button = $VBox/CloseButton

func _ready() -> void:
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())
	research_button.pressed.connect(_show_blueprints)
	lore_button.pressed.connect(_show_lore_topics)
	lore_detail_back_button.pressed.connect(_show_lore_topics)
	back_button.pressed.connect(_show_menu)
	visible = false

func open() -> void:
	visible = true
	_show_menu()

func _hide_all() -> void:
	subtitle_label.visible = false
	menu_row.visible = false
	empty_label.visible = false
	list_scroll.visible = false
	lore_topic_header.visible = false
	lore_topic_scroll.visible = false
	lore_label.visible = false
	lore_detail_back_button.visible = false
	back_button.visible = false

func _show_menu() -> void:
	title_label.text = "LIL DIRTY"
	_hide_all()
	subtitle_label.text = "Bring me a blueprint - I'll turn it into something Mythic. Or don't. I'll talk either way."
	subtitle_label.visible = true
	menu_row.visible = true

func _show_blueprints() -> void:
	_hide_all()
	back_button.visible = true
	list_scroll.visible = true
	refresh()

func _show_lore_topics() -> void:
	title_label.text = "LIL DIRTY"
	_hide_all()
	back_button.visible = true
	lore_topic_header.visible = true
	lore_topic_scroll.visible = true
	for c in lore_topic_list.get_children():
		lore_topic_list.remove_child(c)
		c.queue_free()
	for topic in LORE_TOPICS:
		lore_topic_list.add_child(_make_topic_row(topic))

func _make_topic_row(topic: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 46)
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.1, 0.07, 0.85)
	sb.border_color = Color(0.5, 0.8, 0.45, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	row.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	var icon_slot := Control.new()
	icon_slot.custom_minimum_size = Vector2(26, 26)
	var icon = SmallIconScene.instantiate()
	icon.icon_type = str(topic.get("icon", "star"))
	icon.icon_bg = Color(0.15, 0.2, 0.13, 1)
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon_slot.add_child(icon)
	hbox.add_child(icon_slot)

	var title_lbl := Label.new()
	title_lbl.text = str(topic.get("title", "?"))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.75, 0.95, 0.7, 1))
	hbox.add_child(title_lbl)

	var button := Button.new()
	button.flat = true
	button.anchor_right = 1.0
	button.anchor_bottom = 1.0
	button.pressed.connect(_show_topic_detail.bind(topic))
	row.add_child(button)

	return row

func _show_topic_detail(topic: Dictionary) -> void:
	_hide_all()
	lore_label.visible = true
	lore_detail_back_button.visible = true
	title_label.text = str(topic.get("title", "LIL DIRTY"))
	lore_label.text = str(topic.get("text", ""))

func refresh() -> void:
	for c in blueprint_list.get_children():
		c.queue_free()
	var found := false
	for i in range(GameManager.stash_items.size()):
		var item: Dictionary = GameManager.stash_items[i]
		if item.get("slot", "") == "blueprint":
			found = true
			blueprint_list.add_child(_make_row(i, item))
	empty_label.visible = not found

func _make_row(stash_index: int, item: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 78)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	row.add_child(hbox)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "Blueprint")
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", GameManager.get_rarity_color(item.get("rarity", "epic")))
	info.add_child(name_lbl)

	var result: Dictionary = item.get("blueprint_result", {})
	var desc_lbl := Label.new()
	desc_lbl.text = "Unlocks a Mythic %s: %s" % [String(result.get("slot", "item")).capitalize(), result.get("name", "?")]
	desc_lbl.add_theme_font_size_override("font_size", 13)
	info.add_child(desc_lbl)
	hbox.add_child(info)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150, 55)
	btn.text = "Research"
	btn.pressed.connect(_on_research.bind(stash_index))
	hbox.add_child(btn)

	return row

func _on_research(stash_index: int) -> void:
	GameManager.research_blueprint(stash_index)
	refresh()
