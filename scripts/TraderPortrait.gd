extends Control

# Draws a stylized bust portrait for a trader, themed to their specialty.
# No external images - built from simple shapes, distinct per trader_id.

@export var trader_id: String = "medic"

func _ready() -> void:
	resized.connect(queue_redraw)

func _p(nx: float, ny: float) -> Vector2:
	return Vector2(nx, ny) * size

# Only the named trader/Hideout-NPC identities below get the glow-ring/
# rim-light treatment (see the end of _draw()) - this component is also
# reused everywhere a small simulated-player avatar shows up (Leaderboard
# rows at 34x34, chat/social avatars, etc, via "portrait_1".."portrait_6")
# where those effects would just render as mud at that size. The Traders
# screen instances these at 140x140, big enough for it to actually read.
const NAMED_TRADER_IDS := ["medic", "quartermaster", "scavenger", "scrapper", "alloy_dealer", "barterer", "clarity", "sorrow", "glenn", "big_crax"]
const TRADER_ACCENT_COLORS := {
	"medic": Color(0.85, 0.25, 0.25, 1),
	"quartermaster": Color(0.55, 0.75, 0.4, 1),
	"scavenger": Color(0.75, 0.6, 0.25, 1),
	"scrapper": Color(0.9, 0.6, 0.2, 1),
	"alloy_dealer": Color(0.55, 0.7, 0.85, 1),
	"barterer": Color(0.85, 0.7, 0.25, 1),
	"clarity": Color(0.75, 0.4, 0.85, 1),
	"sorrow": Color(0.4, 0.45, 0.65, 1),
	"glenn": Color(0.55, 0.75, 0.35, 1),
	"big_crax": Color(0.85, 0.5, 0.15, 1),
}

func _draw() -> void:
	var is_named: bool = trader_id in NAMED_TRADER_IDS
	var accent: Color = TRADER_ACCENT_COLORS.get(trader_id, Color(0.6, 0.65, 0.7, 1))
	# Shared base: shoulders + head, background circle. Named traders get a
	# soft themed glow halo behind the disc instead of a flat dark backing.
	if is_named:
		draw_circle(_p(0.5, 0.5), size.x * 0.5, Color(accent.r, accent.g, accent.b, 0.3))
	draw_circle(_p(0.5, 0.5), size.x * 0.48, Color(0.08, 0.09, 0.1, 1))

	var skin := Color(0.78, 0.6, 0.47, 1)
	var shoulders_pts := PackedVector2Array([
		_p(0.18, 0.95), _p(0.82, 0.95), _p(0.72, 0.62), _p(0.28, 0.62)
	])

	match trader_id:
		"medic":
			_draw_medic(skin, shoulders_pts)
		"quartermaster":
			_draw_quartermaster(skin, shoulders_pts)
		"scavenger":
			_draw_scavenger(skin, shoulders_pts)
		"scrapper":
			_draw_scrapper(skin, shoulders_pts)
		"alloy_dealer":
			_draw_alloy_dealer(skin, shoulders_pts)
		"barterer":
			_draw_barterer(skin, shoulders_pts)
		"clarity":
			_draw_clarity(skin, shoulders_pts)
		"sorrow":
			_draw_sorrow(skin, shoulders_pts)
		"glenn":
			_draw_glenn(skin, shoulders_pts)
		"big_crax":
			_draw_big_crax(skin, shoulders_pts)
		"portrait_1":
			_draw_person(Color(0.78, 0.6, 0.47, 1), Color(0.15, 0.12, 0.1, 1), Color(0.25, 0.3, 0.22, 1), shoulders_pts)
		"portrait_2":
			_draw_person(Color(0.35, 0.24, 0.16, 1), Color(0.05, 0.04, 0.03, 1), Color(0.5, 0.15, 0.12, 1), shoulders_pts)
		"portrait_3":
			_draw_person(Color(0.9, 0.75, 0.62, 1), Color(0.65, 0.5, 0.15, 1), Color(0.2, 0.24, 0.35, 1), shoulders_pts)
		"portrait_4":
			_draw_person(Color(0.55, 0.4, 0.28, 1), Color(0.1, 0.08, 0.07, 1), Color(0.35, 0.3, 0.1, 1), shoulders_pts)
		"portrait_5":
			_draw_person(Color(0.85, 0.68, 0.55, 1), Color(0.75, 0.72, 0.68, 1), Color(0.15, 0.15, 0.16, 1), shoulders_pts)
		"portrait_6":
			_draw_person(Color(0.42, 0.3, 0.22, 1), Color(0.2, 0.16, 0.12, 1), Color(0.55, 0.25, 0.08, 1), shoulders_pts)
		_:
			_draw_generic(skin, shoulders_pts)

	if is_named:
		# Cheap uniform "lit from above" pass - works regardless of which
		# trader's draw function just ran, so it doesn't need touching
		# every individual _draw_*() above. A bright rim along the top
		# edge, a soft dark one along the bottom, then a crisp themed
		# accent ring framing the whole bust like the rarity-gradient
		# borders used elsewhere on item icons.
		draw_arc(_p(0.5, 0.5), size.x * 0.46, deg_to_rad(200), deg_to_rad(340), 24, Color(1, 1, 1, 0.1), size.x * 0.018, true)
		draw_arc(_p(0.5, 0.5), size.x * 0.46, deg_to_rad(20), deg_to_rad(160), 24, Color(0, 0, 0, 0.22), size.x * 0.03, true)
		draw_arc(_p(0.5, 0.5), size.x * 0.48, 0.0, TAU, 48, Color(accent.r, accent.g, accent.b, 0.35), size.x * 0.05, true)
		draw_arc(_p(0.5, 0.5), size.x * 0.48, 0.0, TAU, 48, accent, size.x * 0.018, true)

func _draw_person(skin: Color, hair: Color, clothing: Color, shoulders: PackedVector2Array) -> void:
	draw_colored_polygon(shoulders, clothing)
	draw_circle(_p(0.5, 0.4), size.x * 0.22, skin)
	# Hair - a cap over the top of the head.
	var hair_pts := PackedVector2Array([
		_p(0.29, 0.36), _p(0.71, 0.36), _p(0.68, 0.22), _p(0.5, 0.16), _p(0.32, 0.22)
	])
	draw_colored_polygon(hair_pts, hair)

func _draw_medic(skin: Color, shoulders: PackedVector2Array) -> void:
	var coat := Color(0.85, 0.85, 0.82, 1)
	draw_colored_polygon(shoulders, coat)
	draw_circle(_p(0.5, 0.4), size.x * 0.22, skin)
	draw_circle(_p(0.5, 0.28), size.x * 0.15, Color(0.2, 0.13, 0.09, 1))
	# Red cross badge on the chest.
	draw_rect(Rect2(_p(0.465, 0.72), Vector2(size.x * 0.07, size.y * 0.16)), Color(0.8, 0.15, 0.15, 1))
	draw_rect(Rect2(_p(0.42, 0.765), Vector2(size.x * 0.16, size.y * 0.07)), Color(0.8, 0.15, 0.15, 1))
	# Glasses.
	draw_arc(_p(0.44, 0.4), size.x * 0.04, 0, TAU, 16, Color(0.1, 0.1, 0.1, 1), 1.5, true)
	draw_arc(_p(0.56, 0.4), size.x * 0.04, 0, TAU, 16, Color(0.1, 0.1, 0.1, 1), 1.5, true)

func _draw_quartermaster(skin: Color, shoulders: PackedVector2Array) -> void:
	var jacket := Color(0.28, 0.32, 0.24, 1)
	draw_colored_polygon(shoulders, jacket)
	draw_circle(_p(0.5, 0.4), size.x * 0.22, skin)
	# Helmet.
	draw_circle(_p(0.5, 0.3), size.x * 0.24, Color(0.2, 0.22, 0.18, 1))
	draw_rect(Rect2(_p(0.28, 0.3), Vector2(size.x * 0.44, size.y * 0.05)), Color(0.12, 0.13, 0.1, 1))
	# Scar / stern brow line.
	draw_line(_p(0.58, 0.34), _p(0.66, 0.42), Color(0.4, 0.2, 0.15, 0.8), 2.0)
	# Rifle strap diagonal across chest.
	draw_line(_p(0.3, 0.65), _p(0.68, 0.9), Color(0.15, 0.12, 0.08, 1), size.x * 0.035)

func _draw_scavenger(skin: Color, shoulders: PackedVector2Array) -> void:
	var vest := Color(0.32, 0.26, 0.14, 1)
	draw_colored_polygon(shoulders, vest)
	draw_circle(_p(0.5, 0.4), size.x * 0.22, skin)
	# Gas-mask-ish goggles + strap.
	draw_rect(Rect2(_p(0.3, 0.35), Vector2(size.x * 0.4, size.y * 0.1)), Color(0.15, 0.15, 0.15, 1))
	draw_circle(_p(0.4, 0.4), size.x * 0.045, Color(0.5, 0.75, 0.55, 0.85))
	draw_circle(_p(0.6, 0.4), size.x * 0.045, Color(0.5, 0.75, 0.55, 0.85))
	draw_line(_p(0.28, 0.4), _p(0.72, 0.4), Color(0.1, 0.1, 0.1, 1), 2.0)
	# Bandana.
	draw_rect(Rect2(_p(0.3, 0.5), Vector2(size.x * 0.4, size.y * 0.06)), Color(0.5, 0.15, 0.12, 1))

func _draw_generic(skin: Color, shoulders: PackedVector2Array) -> void:
	draw_colored_polygon(shoulders, Color(0.3, 0.3, 0.3, 1))
	draw_circle(_p(0.5, 0.4), size.x * 0.22, skin)

func _draw_scrapper(skin: Color, shoulders: PackedVector2Array) -> void:
	var apron := Color(0.35, 0.3, 0.15, 1)
	draw_colored_polygon(shoulders, apron)
	draw_circle(_p(0.5, 0.4), size.x * 0.22, skin)
	# Welding goggles pushed up on forehead.
	draw_rect(Rect2(_p(0.35, 0.26), Vector2(size.x * 0.3, size.y * 0.07)), Color(0.15, 0.15, 0.15, 1))
	draw_circle(_p(0.42, 0.295), size.x * 0.035, Color(0.9, 0.6, 0.2, 0.8))
	draw_circle(_p(0.58, 0.295), size.x * 0.035, Color(0.9, 0.6, 0.2, 0.8))
	# Grease smudge on cheek.
	draw_circle(_p(0.62, 0.44), size.x * 0.03, Color(0.1, 0.1, 0.1, 0.4))
	# Wrench slung over shoulder.
	draw_line(_p(0.25, 0.7), _p(0.4, 0.5), Color(0.5, 0.5, 0.55, 1), size.x * 0.03)

func _draw_alloy_dealer(skin: Color, shoulders: PackedVector2Array) -> void:
	var coat := Color(0.25, 0.27, 0.32, 1)
	draw_colored_polygon(shoulders, coat)
	draw_circle(_p(0.5, 0.4), size.x * 0.22, skin)
	# Metallic-sheen visor.
	draw_rect(Rect2(_p(0.32, 0.34), Vector2(size.x * 0.36, size.y * 0.09)), Color(0.55, 0.65, 0.7, 0.85))
	draw_line(_p(0.32, 0.34), _p(0.68, 0.43), Color(0.85, 0.9, 0.95, 0.4), 1.5)
	# Alloy pendant.
	draw_circle(_p(0.5, 0.78), size.x * 0.045, Color(0.75, 0.8, 0.85, 1))
	draw_line(_p(0.5, 0.66), _p(0.5, 0.75), Color(0.6, 0.6, 0.65, 1), 1.5)

func _draw_barterer(skin: Color, shoulders: PackedVector2Array) -> void:
	var coat := Color(0.4, 0.32, 0.15, 1)
	draw_colored_polygon(shoulders, coat)
	draw_circle(_p(0.5, 0.4), size.x * 0.22, skin)
	# Layered trade-cloak collar.
	draw_colored_polygon(PackedVector2Array([_p(0.3, 0.6), _p(0.7, 0.6), _p(0.62, 0.72), _p(0.38, 0.72)]), Color(0.55, 0.42, 0.2, 1))
	# A coin held up near the chest.
	draw_circle(_p(0.62, 0.78), size.x * 0.05, Color(0.85, 0.7, 0.25, 1))
	draw_arc(_p(0.62, 0.78), size.x * 0.05, 0.0, TAU, 12, Color(0.5, 0.4, 0.1, 1), 1.2, true)
	# Weathered, squinting eyes.
	draw_line(_p(0.4, 0.4), _p(0.46, 0.4), Color(0.15, 0.1, 0.05, 1), 1.5)
	draw_line(_p(0.54, 0.4), _p(0.6, 0.4), Color(0.15, 0.1, 0.05, 1), 1.5)

func _draw_clarity(skin: Color, shoulders: PackedVector2Array) -> void:
	var jacket := Color(0.42, 0.2, 0.48, 1)
	draw_colored_polygon(shoulders, jacket)
	draw_circle(_p(0.5, 0.4), size.x * 0.22, skin)
	# Sleek hair pulled back.
	draw_colored_polygon(PackedVector2Array([_p(0.3, 0.36), _p(0.7, 0.36), _p(0.66, 0.2), _p(0.5, 0.15), _p(0.34, 0.2)]), Color(0.15, 0.1, 0.12, 1))
	# Calm, focused visor-like glasses.
	draw_rect(Rect2(_p(0.34, 0.38), Vector2(size.x * 0.32, size.y * 0.06)), Color(0.6, 0.85, 0.95, 0.6))
	draw_line(_p(0.34, 0.41), _p(0.66, 0.41), Color(0.1, 0.1, 0.1, 0.8), 1.2)
	# A focus-mark tattoo.
	draw_line(_p(0.42, 0.55), _p(0.42, 0.6), Color(0.7, 0.35, 0.8, 0.8), 1.5)

func _draw_sorrow(skin: Color, shoulders: PackedVector2Array) -> void:
	var coat := Color(0.22, 0.24, 0.3, 1)
	draw_colored_polygon(shoulders, coat)
	draw_circle(_p(0.5, 0.4), size.x * 0.22, skin)
	# A raised hood, casting the upper face in shadow.
	draw_colored_polygon(PackedVector2Array([_p(0.26, 0.42), _p(0.74, 0.42), _p(0.68, 0.16), _p(0.5, 0.1), _p(0.32, 0.16)]), Color(0.16, 0.18, 0.24, 1))
	draw_circle(_p(0.5, 0.42), size.x * 0.19, Color(0, 0, 0, 0.35))
	# Downcast eyes.
	draw_line(_p(0.42, 0.44), _p(0.47, 0.46), Color(0.05, 0.05, 0.06, 1), 1.3)
	draw_line(_p(0.53, 0.46), _p(0.58, 0.44), Color(0.05, 0.05, 0.06, 1), 1.3)

func _draw_glenn(skin: Color, shoulders: PackedVector2Array) -> void:
	var vest := Color(0.28, 0.36, 0.18, 1)
	draw_colored_polygon(shoulders, vest)
	draw_circle(_p(0.5, 0.4), size.x * 0.22, skin)
	# Scruffy hair + stubble.
	draw_colored_polygon(PackedVector2Array([_p(0.3, 0.34), _p(0.7, 0.34), _p(0.66, 0.2), _p(0.5, 0.16), _p(0.34, 0.2)]), Color(0.35, 0.28, 0.15, 1))
	draw_colored_polygon(PackedVector2Array([_p(0.38, 0.5), _p(0.62, 0.5), _p(0.58, 0.58), _p(0.42, 0.58)]), Color(0.3, 0.24, 0.15, 0.55))
	# A bandana tied around the head.
	draw_rect(Rect2(_p(0.3, 0.28), Vector2(size.x * 0.4, size.y * 0.06)), Color(0.55, 0.15, 0.12, 1))

func _draw_big_crax(skin: Color, shoulders: PackedVector2Array) -> void:
	var armor := Color(0.42, 0.24, 0.08, 1)
	draw_colored_polygon(shoulders, armor)
	# A noticeably wider, heavier head/jaw for a bulky read.
	draw_circle(_p(0.5, 0.42), size.x * 0.27, skin)
	draw_colored_polygon(PackedVector2Array([_p(0.32, 0.5), _p(0.68, 0.5), _p(0.62, 0.62), _p(0.38, 0.62)]), skin.darkened(0.1))
	# Small, deep-set eyes and a heavy brow.
	draw_line(_p(0.36, 0.38), _p(0.44, 0.38), Color(0.15, 0.08, 0.02, 1), 2.5)
	draw_line(_p(0.56, 0.38), _p(0.64, 0.38), Color(0.15, 0.08, 0.02, 1), 2.5)
	draw_circle(_p(0.4, 0.42), size.x * 0.025, Color(0.1, 0.1, 0.1, 1))
	draw_circle(_p(0.6, 0.42), size.x * 0.025, Color(0.1, 0.1, 0.1, 1))
	# Studded shoulder plating.
	draw_circle(_p(0.24, 0.75), size.x * 0.03, Color(0.7, 0.65, 0.55, 1))
	draw_circle(_p(0.76, 0.75), size.x * 0.03, Color(0.7, 0.65, 0.55, 1))
