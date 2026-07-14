extends Control
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

# The curated "what's new" spotlight - separate from WelcomePanel (which
# is first-launch-only onboarding). This one shows every time the Main
# Menu loads, highlighting the most recent update in player-facing
# terms: what it's called, why it matters, and what's coming next -
# not a raw changelog dump (see ChangelogPanel for the full history).

signal closed

const ChangelogScript := preload("res://scripts/ChangelogPanel.gd")
const SmallIconScene := preload("res://scenes/SmallIcon.tscn")
const MAX_RECENT := 5

# --- Curated spotlight content for the current update. Update this by
# hand each time a new update ships - deliberately not auto-generated
# from the changelog, since that's full of implementation-detail bug
# fixes players don't care about (see ChangelogPanel for that).
const UPDATE_NAME := "The Arena Update"
const UPDATE_VERSION := "v3.53"
const HEADLINE_FEATURE := "Arena is live"
const HEADLINE_BODY := "Jump into 1v1 or 2v2 fights on a brand new close-quarters map, The Grid, with its own ranks, rewards, and leaderboard - a completely different way to test your gear against real threats without a full extraction run."
const SHORT_SUMMARY := "This update adds a whole new way to play alongside the usual raid loop - Arena is built for quick, repeatable fights instead of long extraction runs, so there's finally something to jump into when you don't have time for a full raid."
const BIG_ADDITIONS := [
	"Arena mode: 1v1/2v2 matches, 6 new ranks with their own icons, Matchmaking, Find a Team, a dedicated Leaderboard, and Rewards.",
	"A real Death Screen - see exactly who killed you, with what weapon, and a hit-location review of where it landed.",
	"Ammo overhaul: ammo now stacks in your Backpack instead of eating a Hotbar slot, and reloading pulls straight from it.",
	"A full art pass: vehicles, several enemies, and world props (barrels, crates, walls, ground debris) all got real sprite art instead of placeholder shapes.",
]
const QOL_ITEMS := [
	"Claim All button in Mail.",
	"The changelog now archives older entries instead of growing forever.",
	"One consistent click sound on every button, plus reworked menu hover sounds.",
	"Fixed the leaderboard countdown timer, a stale ammo count flicker, and a phantom click sound after matchmaking.",
]
const UPCOMING_ITEMS := [
	"A new Sniper Rifle - real one-shot long-range power, at the cost of a slow reload.",
	"An Arena \"Social Place\" hub to hang out and meet other operators between matches.",
]

@onready var box: Panel = $Box
@onready var icon_holder: Control = $Box/VBox/HeaderRow/IconHolder
@onready var update_name_label: Label = $Box/VBox/HeaderRow/HeaderTextVBox/UpdateNameLabel
@onready var version_label: Label = $Box/VBox/HeaderRow/HeaderTextVBox/VersionLabel
@onready var content: VBoxContainer = $Box/VBox/Scroll/Content
@onready var hero_banner = $Box/VBox/Scroll/Content/HeroBanner
@onready var close_button: Button = $Box/VBox/CloseButton

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		closed.emit()

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(box)
	close_button.pressed.connect(func(): closed.emit())

	var icon = SmallIconScene.instantiate()
	icon.icon_type = "arena"
	icon.icon_bg = Color(0.14, 0.1, 0.18, 1)
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.add_child(icon)

	update_name_label.text = UPDATE_NAME.to_upper()
	version_label.text = "Update %s" % UPDATE_VERSION
	hero_banner.hero_color = Color(0.65, 0.4, 0.95, 1)
	hero_banner.hero_label = "ARENA"

	_add_section_header("★ " + HEADLINE_FEATURE, Color(1.0, 0.85, 0.4, 1))
	_add_body_label(HEADLINE_BODY)
	_add_section_header("BIG ADDITIONS", Color(0.6, 0.9, 0.65, 1))
	for line in BIG_ADDITIONS:
		_add_bullet(line, Color(0.88, 0.95, 0.88, 1))
	_add_section_header("THE SHORT VERSION", Color(0.6, 0.8, 1.0, 1))
	_add_body_label(SHORT_SUMMARY, true)
	_add_section_header("QUALITY OF LIFE", Color(0.75, 0.85, 0.95, 1))
	for line in QOL_ITEMS:
		_add_bullet(line, Color(0.85, 0.9, 0.95, 1))
	_add_section_header("COMING SOON", Color(0.95, 0.75, 0.5, 1))
	for line in UPCOMING_ITEMS:
		_add_bullet(line, Color(0.95, 0.85, 0.7, 0.9))
	_add_section_header("RECENT UPDATES", Color(0.7, 0.7, 0.75, 1))
	_add_recent_updates()

func _add_section_header(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", color)
	content.add_child(lbl)

func _add_body_label(text: String, italic: bool = false) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.modulate = Color(1, 1, 1, 0.9 if not italic else 0.8)
	content.add_child(lbl)

func _add_bullet(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = "  •  %s" % text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	content.add_child(lbl)

func _add_recent_updates() -> void:
	var shown := 0
	var entries: Array = ChangelogScript.get_all_entries().duplicate()
	entries.reverse()
	for entry in entries:
		if shown >= MAX_RECENT:
			break
		var title: String = str(entry.get("title", ""))
		if title.begins_with("Hotfix"):
			continue
		_add_bullet(title, Color(0.8, 0.8, 0.85, 0.85))
		shown += 1

func open() -> void:
	visible = true
	# Same runtime anchor-collapse bug as other centered popups - force
	# both the full-screen root and the centered inner Box explicitly.
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	box.anchor_left = 0.5
	box.anchor_top = 0.5
	box.anchor_right = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -300.0
	box.offset_top = -290.0
	box.offset_right = 300.0
	box.offset_bottom = 290.0
