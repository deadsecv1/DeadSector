extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		closed.emit()

const ChangelogScript := preload("res://scripts/ChangelogPanel.gd")
const SmallIconScene := preload("res://scenes/SmallIcon.tscn")
const MAX_HIGHLIGHTS := 5

@onready var icon_holder: Control = $VBox/IconHolder
@onready var welcome_body: Label = $VBox/Scroll/VBox/WelcomeBody
@onready var highlights_list: VBoxContainer = $VBox/Scroll/VBox/HighlightsList
@onready var close_button: Button = $VBox/CloseButton

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())
	var icon = SmallIconScene.instantiate()
	icon.icon_type = "event"
	icon.icon_bg = Color(0.15, 0.12, 0.05, 1)
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.add_child(icon)

	welcome_body.text = "Welcome to Dead Sector! This is a real Alpha - the core loop is here (raid, loot, extract, gear up, come back harder) but you'll run into rough edges, unfinished corners, and things that still need balancing. That's expected at this stage.\n\nThe short version: pick a Sector, gear up from your Stash before you go, extract before your time runs out or you don't keep what you found. Contacts around the Hideout hand out contracts for real rewards. Spend what you earn on Skill Tree upgrades, Hideout training, and better gear. Everything you build up carries forward raid to raid - that's the whole point.\n\nFound something broken? There's a Feedback button right on this screen for exactly that."

	for c in highlights_list.get_children():
		highlights_list.remove_child(c)
		c.queue_free()
	var shown := 0
	var entries: Array = ChangelogScript.get_all_entries().duplicate()
	entries.reverse()
	for entry in entries:
		if shown >= MAX_HIGHLIGHTS:
			break
		var title: String = str(entry.get("title", ""))
		if title.begins_with("Hotfix"):
			continue
		var lbl := Label.new()
		lbl.text = "  •  %s" % title
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85, 1))
		highlights_list.add_child(lbl)
		shown += 1

func open() -> void:
	visible = true
	# Same runtime anchor-collapse bug as Flea Market/Mail - force the
	# designed centered layout back explicitly.
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -260.0
	offset_top = -240.0
	offset_right = 260.0
	offset_bottom = 240.0
