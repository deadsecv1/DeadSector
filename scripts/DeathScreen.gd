extends Control

# The Death screen - replaces the old fleeting white "YOU DIED / Lost X
# loot" text flash with a real screen: who killed you and with what
# (GameManager.last_death_info, captured from Player.last_attacker_name/
# weapon right as the death was processed), a quick "where you got hit"
# mannequin review, and how much loot you lost. The mannequin isn't a
# real hit-log - there's no per-body-part damage tracking in this game -
# it's a fresh random roll every death, purely for flavor.

const PlayerContextMenuScript := preload("res://scripts/PlayerContextMenu.gd")

# Body part, its rough position/radius on the mannequin (drawn in
# Mannequin's local space), and how likely it is to get hit relative to
# the others - center-mass parts take the bulk of hits, like a real
# spread of gunfire would.
const HIT_PARTS := [
	{"name": "Head", "weight": 2, "pos": Vector2(0, -94), "radius": 15.0},
	{"name": "Eyes", "weight": 1, "pos": Vector2(0, -97), "radius": 5.0},
	{"name": "Thorax", "weight": 6, "pos": Vector2(0, -48), "radius": 26.0},
	{"name": "Left Arm", "weight": 3, "pos": Vector2(-32, -44), "radius": 11.0},
	{"name": "Right Arm", "weight": 3, "pos": Vector2(32, -44), "radius": 11.0},
	{"name": "Left Leg", "weight": 3, "pos": Vector2(-13, 8), "radius": 13.0},
	{"name": "Right Leg", "weight": 3, "pos": Vector2(13, 8), "radius": 13.0},
]

@onready var title_label: Label = $Panel/VBox/Title
@onready var killed_by_button: Button = $Panel/VBox/KilledByRow/KilledByButton
@onready var loot_label: Label = $Panel/VBox/LootLabel
@onready var mannequin_row: Control = $Panel/VBox/MannequinRow
@onready var mannequin: Control = $Panel/VBox/MannequinRow/MannequinHolder/Mannequin
@onready var hit_list: VBoxContainer = $Panel/VBox/MannequinRow/HitList
@onready var continue_button: Button = $Panel/VBox/ContinueButton
@onready var context_menu_host: Control = $ContextMenuHost

var _hit_marks: Array = []  # {part index, local jitter offset}
var context_menu: Control
var _killer_entry: Dictionary = {}

func _ready() -> void:
	GameManager.set_default_cursor()
	context_menu = Control.new()
	context_menu.anchor_right = 1.0
	context_menu.anchor_bottom = 1.0
	context_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	context_menu.set_script(PlayerContextMenuScript)
	context_menu_host.add_child(context_menu)

	var info: Dictionary = GameManager.last_death_info
	var was_voluntary: bool = bool(info.get("voluntary_exit", false))
	if was_voluntary:
		title_label.text = "RAID ABANDONED"
	elif bool(info.get("timed_out", false)):
		title_label.text = "TIME EXPIRED"
	else:
		title_label.text = "YOU DIED"

	var attacker: String = str(info.get("attacker_name", ""))
	var weapon: String = str(info.get("attacker_weapon", ""))
	if was_voluntary:
		killed_by_button.text = "You left the raid"
		killed_by_button.disabled = true
	elif attacker == "":
		killed_by_button.text = "Killed by the Sector itself"
		killed_by_button.disabled = true
	else:
		killed_by_button.text = "Killed by %s with %s" % [attacker, weapon] if weapon != "" else "Killed by %s" % attacker
		killed_by_button.disabled = false
		_killer_entry = {
			"name": attacker, "portrait": "portrait_1", "level": 1,
			"kills": 0, "deaths": 0, "pets": 0, "badges": [], "gear": {},
		}
		killed_by_button.pressed.connect(_on_killed_by_pressed)

	loot_label.text = "Lost %d loot." % int(info.get("loot_value", 0))

	# No real combat happened on a voluntary exit - skip the hit-location
	# mannequin entirely instead of rolling fake bullet marks for a fight
	# that never occurred.
	mannequin_row.visible = not was_voluntary
	if not was_voluntary:
		_roll_hits()
		_build_hit_list()
		mannequin.draw.connect(_draw_mannequin)
		mannequin.queue_redraw()

	continue_button.pressed.connect(_on_continue)

func _on_killed_by_pressed() -> void:
	context_menu.open_for(_killer_entry, killed_by_button.get_global_rect().position + Vector2(20, 20))

# Purely cosmetic - picks a random number of hits and scatters them
# across the body parts, weighted so center-mass parts take more.
func _roll_hits() -> void:
	_hit_marks.clear()
	var total_weight := 0
	for part in HIT_PARTS:
		total_weight += int(part["weight"])
	var hit_count := randi_range(3, 9)
	for i in range(hit_count):
		var roll := randi_range(1, total_weight)
		var acc := 0
		for pi in range(HIT_PARTS.size()):
			acc += int(HIT_PARTS[pi]["weight"])
			if roll <= acc:
				var jitter := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * float(HIT_PARTS[pi]["radius"]) * 0.5
				_hit_marks.append({"part": pi, "jitter": jitter})
				break

func _build_hit_list() -> void:
	for c in hit_list.get_children():
		c.queue_free()
	var counts := {}
	for hit in _hit_marks:
		var pi: int = hit["part"]
		counts[pi] = int(counts.get(pi, 0)) + 1
	var header := Label.new()
	header.text = "Hits Taken"
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(0.9, 0.4, 0.35, 1))
	hit_list.add_child(header)
	for pi in counts:
		var lbl := Label.new()
		lbl.text = "%s  x%d" % [str(HIT_PARTS[pi]["name"]), int(counts[pi])]
		lbl.add_theme_font_size_override("font_size", 12)
		hit_list.add_child(lbl)

func _draw_mannequin() -> void:
	var w: float = mannequin.size.x
	var h: float = mannequin.size.y
	if w <= 0.0 or h <= 0.0:
		return
	var center := Vector2(w / 2.0, h * 0.72)
	var skin := Color(0.65, 0.6, 0.55, 1)
	var dark := Color(0.4, 0.37, 0.35, 1)

	# Ground shadow.
	mannequin.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-22, 14), center + Vector2(22, 14), center + Vector2(18, 22), center + Vector2(-18, 22),
	]), Color(0, 0, 0, 0.3))

	# Legs, torso, arms, head - a plain neutral standing figure, since
	# this is a generic "you" silhouette, not any specific gear/skin.
	mannequin.draw_rect(Rect2(center + Vector2(-20, -20), Vector2(14, 42)), dark)
	mannequin.draw_rect(Rect2(center + Vector2(6, -20), Vector2(14, 42)), dark)
	mannequin.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-24, -70), center + Vector2(24, -70), center + Vector2(28, -30),
		center + Vector2(20, -14), center + Vector2(-20, -14), center + Vector2(-28, -30),
	]), skin)
	mannequin.draw_rect(Rect2(center + Vector2(-34, -66), Vector2(11, 40)), skin)
	mannequin.draw_rect(Rect2(center + Vector2(23, -66), Vector2(11, 40)), skin)
	mannequin.draw_circle(center + Vector2(0, -94), 16.0, skin)

	# Hit markers - a soft red glow plus an X, at each rolled hit's part
	# position + small random jitter so repeated hits on the same part
	# don't just stack exactly on top of each other.
	for hit in _hit_marks:
		var part: Dictionary = HIT_PARTS[hit["part"]]
		var pos: Vector2 = center + Vector2(part["pos"]) + hit["jitter"]
		mannequin.draw_circle(pos, 7.0, Color(0.95, 0.2, 0.15, 0.25))
		mannequin.draw_line(pos + Vector2(-4, -4), pos + Vector2(4, 4), Color(0.95, 0.15, 0.1, 0.95), 2.0)
		mannequin.draw_line(pos + Vector2(-4, 4), pos + Vector2(4, -4), Color(0.95, 0.15, 0.1, 0.95), 2.0)

func _on_continue() -> void:
	Transition.change_scene_instant("res://scenes/MainMenu.tscn")
