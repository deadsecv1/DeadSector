extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")
const SmallIconScene := preload("res://scenes/SmallIcon.tscn")
const ItemIconScene := preload("res://scenes/ItemIcon.tscn")
const GodforgedAuraFXScript := preload("res://scripts/GodforgedAuraFX.gd")

const TOPIC_ICON_TYPES := {
	"bags": "bags_topic",
	"boba": "boba_topic",
	"league": "league_topic",
	"nessa": "nessa_topic",
	"plushies": "plushies_topic",
}

signal closed
signal plushies_requested
# Emitted whenever _show_menu() runs (including from the Back button) -
# Hideout.gd listens so the plushie trade window/reveal popup close
# alongside Rose stepping back to her main menu, instead of lingering
# on screen after she's moved on.
signal menu_shown

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		closed.emit()

const GREETING := "Hi! I'm Rose. I'm mostly just here for the bags, the boba, and the vibes, not necessarily in that order. If you ever find a stray Plushie out there, bring it to me - I'll turn it into a real, equippable pet you can take with you into a raid. If you ever want to hear me actually go off about any of it, hit Lore below - fair warning, it's a lot."

const PLUSHIE_TALK_LINE := "Ooh, go on then! Trade window's just popped up on the side there - hand one over and I'll see what we can turn it into. No idea what you'll get 'til it happens, that's half the fun of it."

# 5 topics, written like an actual 20-year-old from the UK talking your
# ear off about her interests - long, in-depth, and (hopefully) funny.
const LORE_TOPICS := [
	{"id": "bags", "title": "The Bag Situation", "text": "Okay so. The bags. I need everyone to understand this is not a hobby, it's a lifestyle, there's a difference.\n\nIt started with one (1) little crossbody bag, proper innocent, just needed something for my phone and my lip balm, completely normal girl behaviour. Now I own, conservatively, more bags than I own actual reasons to leave the house. I've got a bag for \"going out out,\" a bag for \"just popping to the shop but I want to look put together in case I see someone,\" a bag that's purely decorative and has never once left my room, and one that I bought purely because the little clasp made a satisfying click. That's it. That's the whole reason. The click sold it.\n\nMy mates have staged what they called \"an intervention\" twice. Both times I let them finish talking and then showed them the new one I'd got that morning and both times they went dead quiet and then asked where I got it from. So. Make of that what you will. That's not an intervention working, that's called converting people.\n\nHonestly the maddest part is I'll go proper hungry-broke by like the 20th of the month because I saw a bag online at 2am and my brain just went \"yeah go on then\" before my thumb had even properly decided. Zero negotiation happened internally. It's basically a reflex at this point, like blinking, except blinking doesn't cost £45 and take a week to arrive.\n\nAnyway if you ever see me eyeing up something in your Stash that's giving \"bag-shaped,\" no you didn't."},
	{"id": "boba", "title": "Boba Is Not A Phase", "text": "Right, people keep calling it a phase and I need to correct that on record: it has been over two years, that is not a phase, that is a personality trait with a receipt trail.\n\nBrown sugar boba specifically. Not the fruity ones, don't @ me about the fruity ones, they're fine for what they are but they're not doing anything for my soul the way a proper brown sugar milk tea does. There's a place near the Hideout - well, near where the Hideout used to connect to before everything went a bit mental - and I would, genuinely, walk further than is medically advisable for one of theirs.\n\nI've got a whole ranking system. Tapioca has to have a bit of chew left, if it's gone mushy that's an instant deduction, I don't care how good the tea itself is, texture matters, I don't make the rules, well I do actually, it's my ranking system, but you know what I mean. Ice level is a whole negotiation depending on the weather. Sweetness percentage is non-negotiable and it's 50%, anyone doing 100% is playing a different game to the rest of us and I fear for them.\n\nMy card details are basically memorised by that app at this point, it just goes straight through, no thinking required, which some people would call a problem and I would call efficient. I've had days where boba was, unironically, the only thing keeping the whole operation running. Rough raid, bad drop, whatever - straw in, world's fine again, at least for twenty minutes.\n\nIf you ever bring me one unprompted I will remember it forever and possibly tell this whole story to you again just to make sure you understand the honour you've been given."},
	{"id": "league", "title": "Support Or Die", "text": "So I main support, which already tells you everything about my personality, but let me elaborate anyway because apparently I have a lot to say about it, who knew.\n\nEveryone always wants to lane carry, everyone wants the kill feed, and meanwhile I'm the one keeping the actual team alive while getting zero credit and somehow also getting flamed when the carry I peeled for walks into three abilities anyway. That's not on me. I did my job. You made a choice. I'll ward for it, I'll shield for it, I will not, however, take the blame for it.\n\nI've got a whole theory that support mains are just built different, like, psychologically. You have to be a little bit selfless and a LOT strategic and also completely fine with 90% of your job being invisible to everyone except the enemy jungler who's about to make your entire evening worse. There's an art to it. People sleep on it constantly and then wonder why their lane's 0 and 8.\n\nI will say the actual peak of my gaming career, and I stand by this, was the day I learned to properly hard-engage instead of just sitting back playing it safe the whole game. Changed everything. My mates still bring it up. It's basically a core memory for the group chat at this point, there's a screenshot, it's been sent probably forty times since.\n\nAnyway if you ever need someone to third or fourth for a squad, I'm free, I've got wards, I've got a shield, and I have got absolutely no patience for someone who doesn't ping before they dive."},
	{"id": "nessa", "title": "The Nessa Pipeline", "text": "Okay so I need to talk about Nessa Barrett because it's been a whole situation in my head recently and somebody needs to hear about it, might as well be you.\n\nI got into it properly through one song and then just fell straight down the pipeline, the way you do, where one minute you're just having a listen and the next minute it's 1am and you know every lyric off by heart and you're doing the whole emotional-damage voice-crack bit in the mirror like it's a performance for an audience of exactly nobody.\n\nThere's just something about the whole moody-slash-messy-feelings vibe that hits different when you've had a day, do you know what I mean. Like the lyrics are basically just my group chat messages except with better production values and someone actually mixed the vocals properly, unlike half the voice notes I send at 2am that nobody can understand anyway.\n\nI've had it on repeat so much this week my mates have started doing the intro riff as a bit whenever I walk in, which, fair, I'd probably do the same to them, I'm not even mad about it, it means it's landed, it means it's a whole moment. When a new one drops I genuinely clear my evening. Not being dramatic. Just accurate.\n\nAnyway if you ever hear me humming something moody and slightly unhinged while I'm sorting my stash, that's what that is. No further context needed."},
	{"id": "plushies", "title": "The Plushie Shelf", "text": "Right, the plushie shelf. This is a big one so settle in, I've got A Lot to say.\n\nIt started small, obviously, they always do. One little one, dead cute, basically an accident, I saw it and I simply had no choice in the matter. Now the shelf is at what I'd call \"structurally concerning\" capacity and I've started a second shelf, which my flatmate has POINTS about, but I don't make the rules of my own heart, do I.\n\nEvery single one has a name. Every single one. I will not be taking questions about whether that's normal, I've made my peace with it and you should too. There is a whole social hierarchy on that shelf that I've never fully explained to anyone because honestly it's a bit much even for me to say out loud, but the point is - it matters, there's a system, it's not chaos, it's curated chaos.\n\nHonestly there's something proper grounding about it, especially out here where everything's a bit mad and everyone's covered in dirt and running from something. Coming back to a shelf full of soft little faces that are just happy to see you, no questions, no drama, no flaming you for a bad team fight - it's just nice, isn't it. Sue me for wanting something soft in a world that's mostly sharp edges and bad vibes.\n\nWhich is actually the whole reason I've started doing this - if you ever find a stray plushie out there and bring it to me, I promise you it will not just sit on a shelf being sad and unloved. I've worked out how to properly bring them to life, give them a bit of a glow-up, turn them into something that'll actually watch your back out there. Consider it a professional service. Bring me one and find out."},
]

@onready var title_label: Label = $VBox/Title
@onready var icon_slot: Control = $VBox/IconSlot
@onready var icon = $VBox/IconSlot/Icon
@onready var greeting_label: Label = $VBox/GreetingLabel
@onready var menu_row: HBoxContainer = $VBox/MenuRow
@onready var give_plushie_button: Button = $VBox/MenuRow/GivePlushieButton
@onready var lore_button: Button = $VBox/MenuRow/LoreButton
@onready var lore_topic_scroll: ScrollContainer = $VBox/LoreTopicScroll
@onready var lore_topic_list: VBoxContainer = $VBox/LoreTopicScroll/LoreTopicList
@onready var lore_detail_scroll: ScrollContainer = $VBox/LoreDetailScroll
@onready var lore_detail_icon: Control = $VBox/LoreDetailScroll/LoreDetailVBox/LoreDetailIcon
@onready var lore_label: Label = $VBox/LoreDetailScroll/LoreDetailVBox/LoreLabel
@onready var lore_back_button: Button = $VBox/LoreBackButton
@onready var back_button: Button = $VBox/BackButton
@onready var close_button: Button = $VBox/CloseButton

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())
	give_plushie_button.pressed.connect(func():
		_show_plushie_talk()
		plushies_requested.emit()
	)
	lore_button.pressed.connect(_show_lore_topics)
	lore_back_button.pressed.connect(_show_lore_topics)
	back_button.pressed.connect(_show_menu)
	icon.icon_key = "rose_icon"
	icon.icon_color = Color(1, 1, 1, 1)
	lore_detail_icon.icon_key = "rose_icon"
	lore_detail_icon.icon_color = Color(1, 1, 1, 1)
	_build_ellie_corner()

# A small piece of ambient life in the corner of Rose's whole window
# (sits outside VBox/_hide_all() on purpose, so it stays put across
# menu/lore/detail views instead of flickering out and back with every
# navigation) - Ellie, slowly spinning via ItemIcon's own built-in spin
# (reused rather than hand-rolling a second rotation timer), with her
# full Godforged aura (stars/particles/gradient shimmer) from
# GodforgedAuraFX. Purely decorative flavor, not tied to actually
# owning her.
func _build_ellie_corner() -> void:
	var holder := Control.new()
	holder.anchor_left = 1.0
	holder.anchor_right = 1.0
	holder.offset_left = -66.0
	holder.offset_right = -10.0
	holder.offset_top = 10.0
	holder.offset_bottom = 66.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

	var ellie_icon = ItemIconScene.instantiate()
	ellie_icon.icon_key = "pet_elephant"
	ellie_icon.icon_color = GameManager.ELLIE_ICON_COLOR
	ellie_icon.spin = true
	ellie_icon.anchor_right = 1.0
	ellie_icon.anchor_bottom = 1.0
	ellie_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(ellie_icon)
	GodforgedAuraFXScript.apply(holder)

func open() -> void:
	visible = true
	GameManager.rose_talked_to = true
	_show_menu()
	GameManager.focus_first_control(self)

func _hide_all() -> void:
	icon_slot.visible = false
	greeting_label.visible = false
	menu_row.visible = false
	lore_topic_scroll.visible = false
	lore_detail_scroll.visible = false
	lore_back_button.visible = false
	back_button.visible = false

func _show_menu() -> void:
	title_label.text = "ROSE"
	_hide_all()
	icon_slot.visible = true
	greeting_label.text = GREETING
	greeting_label.visible = true
	menu_row.visible = true
	give_plushie_button.disabled = false
	give_plushie_button.text = "Plushies"
	menu_shown.emit()

# Shown when "Plushies" is pressed - Rose's own window stays open and
# just switches to this line instead of being hidden in favor of a
# separate panel, so there's no caller state to forget to restore later.
func _show_plushie_talk() -> void:
	title_label.text = "ROSE"
	_hide_all()
	icon_slot.visible = true
	greeting_label.text = PLUSHIE_TALK_LINE
	greeting_label.visible = true
	back_button.visible = true

func _show_lore_topics() -> void:
	title_label.text = "ROSE - LORE"
	_hide_all()
	back_button.visible = true
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
	sb.bg_color = Color(0.13, 0.06, 0.1, 0.85)
	sb.border_color = Color(0.95, 0.6, 0.75, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	row.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	var icon_box := Control.new()
	icon_box.custom_minimum_size = Vector2(28, 28)
	var icon := SmallIconScene.instantiate()
	icon.icon_type = TOPIC_ICON_TYPES.get(topic.get("id", ""), "star")
	icon.icon_bg = Color(0.3, 0.15, 0.22, 1)
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon_box.add_child(icon)
	hbox.add_child(icon_box)

	var title_lbl := Label.new()
	title_lbl.text = str(topic.get("title", "?"))
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.75, 0.85, 1))
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
	lore_detail_scroll.visible = true
	lore_back_button.visible = true
	title_label.text = str(topic.get("title", "ROSE"))
	lore_label.text = str(topic.get("text", ""))
