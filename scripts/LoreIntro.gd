extends Control

const LORE_PAGE_1 := "They stopped counting the days after the Collapse. What's left is just the Sector - a stretch of dead cities, poisoned earth, and things that used to be people. The corporations left their vaults behind when they ran, and so did whatever they were building in them. Everyone who goes in looking for salvage has the same plan: grab what you can carry, get to extraction, and don't look back. Most don't make it. The ones who do never talk about what they saw down there."

const LORE_PAGE_2 := "They call him Echo, because nobody remembers if he ever had a real name. He's been here longer than anyone - guiding operatives in, and sometimes, back out again. Some say he ran point for the corporations before the Collapse. Others say something in the rifts changed him, and he isn't entirely a person anymore. He doesn't explain either way. He just watches, and when you're about to make the mistake that gets you killed, he tells you. Listen to him. In the Sector, he's the only one who isn't trying to sell you something, or eat you."

const TYPE_SPEED := 0.018

@onready var echo_visual: Control = $EchoVisual
@onready var lore_label: RichTextLabel = $VBox/LorePanel/LoreLabel
@onready var continue_reading_button: Button = $VBox/ButtonRow/ContinueReadingButton
@onready var character_creation_button: Button = $VBox/ButtonRow/CharacterCreationButton
@onready var page_label: Label = $VBox/PageLabel

var full_text: String = ""
var shown_chars: int = 0
var type_timer: float = 0.0
var is_typing: bool = false
var page: int = 1

func _ready() -> void:
	GameManager.set_default_cursor()
	continue_reading_button.pressed.connect(_on_continue_reading)
	character_creation_button.pressed.connect(_on_character_creation)
	_start_page(1)
	GameManager.focus_first_control(self)

func _start_page(p: int) -> void:
	page = p
	full_text = LORE_PAGE_1 if p == 1 else LORE_PAGE_2
	shown_chars = 0
	is_typing = true
	lore_label.text = ""
	page_label.text = "1 / 2" if p == 1 else "2 / 2"
	continue_reading_button.visible = (p == 1)
	set_process(true)

func _process(delta: float) -> void:
	if is_typing:
		type_timer -= delta
		if type_timer <= 0.0:
			type_timer = TYPE_SPEED
			shown_chars += 1
			lore_label.text = full_text.substr(0, shown_chars)
			if shown_chars >= full_text.length():
				is_typing = false
	continue_reading_button.text = "Skip" if is_typing else "Continue Reading"
	if echo_visual.has_method("set_talking"):
		echo_visual.set_talking(is_typing)

func _on_continue_reading() -> void:
	if is_typing:
		# Skip straight to the full page instead of making them wait.
		shown_chars = full_text.length()
		lore_label.text = full_text
		is_typing = false
		return
	_start_page(2)

func _on_character_creation() -> void:
	Transition.change_scene("res://scenes/CharacterCreation.tscn", 0.0, 0.6)
