extends Control

# Draws a small vector icon for an item based on icon_key. If real art
# exists at res://assets/icons/<icon_key>.png, that's used instead -
# drop art in any time, no code changes needed. Falls back to the
# built-in vector icon otherwise.
# Works for any Control size since all points are normalized (0..1) then
# scaled to the control's actual size.

@export var icon_key: String = "generic"
@export var icon_color: Color = Color(0.12, 0.12, 0.12, 1)
# Slowly rotates the icon a full 360 - opt in for the handful of tiers
# that deserve to stand out at a glance: Multiversal, Divine, and
# Alpha/Tech Test exclusives. Call set_spin_for_item() with the item
# dict instead of setting this directly where possible.
@export var spin: bool = false
const SPIN_SPEED := 0.6 # radians/sec - a full rotation every ~10.5s

# A short player-set label shown in small letters at the bottom of the
# icon (Loot Bags / Pet Cases only) - see set_tag_for_item().
@export var tag_text: String = ""
@export var tag_color: Color = Color(1, 1, 1, 1)

var _art_rect: TextureRect = null

func _ready() -> void:
	resized.connect(_on_resized)
	pivot_offset = size / 2.0
	_check_external_art()

func _process(_delta: float) -> void:
	if not spin:
		return
	pivot_offset = size / 2.0
	# Driven from the global clock rather than accumulated per-instance -
	# dragging an item triggers a full grid rebuild elsewhere (every
	# tile gets destroyed and recreated to reflect the new layout),
	# which was resetting rotation to 0 every time since a brand new
	# node always starts unrotated. Computing straight from elapsed
	# time means a freshly recreated icon picks up mid-spin exactly
	# where it should be instead of restarting.
	rotation = fmod(Time.get_ticks_msec() * 0.001 * SPIN_SPEED, TAU)

# Convenience for callers that already have the full item dict on hand -
# figures out spin-eligibility the same way everywhere instead of each
# call site re-deriving its own rule.
func set_spin_for_item(item: Dictionary) -> void:
	var rarity: String = str(item.get("rarity", "common"))
	spin = rarity in ["multiversal", "divine"] or item.get("alpha_only", false) or item.get("beta_only", false)

# Same convenience pattern as set_spin_for_item() - reads the item's
# saved tag (if any) rather than each call site re-deriving it.
func set_tag_for_item(item: Dictionary) -> void:
	tag_text = str(item.get("tag_text", ""))
	var col = item.get("tag_color", null)
	tag_color = col if col is Color else Color(1, 1, 1, 1)

func _on_resized() -> void:
	if _art_rect != null:
		_art_rect.size = size
	queue_redraw()

func _check_external_art() -> void:
	var path := "res://assets/icons/%s.png" % icon_key
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	if tex == null:
		return
	if _art_rect == null:
		_art_rect = TextureRect.new()
		_art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_art_rect.anchor_right = 1.0
		_art_rect.anchor_bottom = 1.0
		add_child(_art_rect)
	_art_rect.texture = tex

@export var stretch_to_fill: bool = false

func _p(nx: float, ny: float) -> Vector2:
	# By default, uses a centered SQUARE drawing area sized to the
	# smaller dimension, so icons don't stretch and distort whenever
	# their container isn't square by accident (e.g. the Gamble result
	# box, which is wider than it is tall due to layout, not design).
	# Multi-cell inventory tiles opt into stretch_to_fill instead, since
	# there the non-square shape is intentional (a 1x3 weapon slot) and
	# the icon should actually fill it, the way real loot-tile UIs do.
	if stretch_to_fill:
		return Vector2(nx, ny) * size
	var s: float = min(size.x, size.y)
	var offset := Vector2((size.x - s) / 2.0, (size.y - s) / 2.0)
	return offset + Vector2(nx, ny) * s

func _draw() -> void:
	if _art_rect != null:
		return
	match icon_key:
		"pistol":
			_draw_pistol()
		"egg":
			_draw_egg()
		"pet_case":
			_draw_pet_case()
		"raider_icon":
			_draw_raider_icon()
		"ghost_icon":
			_draw_ghost_icon()
		"wisp_icon":
			_draw_wisp_icon()
		"ghoul_icon":
			_draw_ghoul_icon()
		"bat_icon":
			_draw_bat_icon()
		"goblin_icon":
			_draw_goblin_icon()
		"rose_icon":
			_draw_rose_icon()
		"plushie":
			_draw_plushie_icon()
		"stalker_icon":
			_draw_stalker_icon()
		"sniper_enemy_icon":
			_draw_sniper_enemy_icon()
		"warden_icon":
			_draw_warden_icon()
		"blossom_icon":
			_draw_blossom_icon()
		"rust_shard_icon":
			_draw_rust_shard_icon()
		"static_mote_icon":
			_draw_static_mote_icon()
		"void_shard_icon":
			_draw_void_shard_icon()
		"spectral_ash_icon":
			_draw_spectral_ash_icon()
		"map_overgrowth_icon":
			_draw_map_overgrowth_icon()
		"map_boneclock_icon":
			_draw_map_boneclock_icon()
		"map_void_trench_icon":
			_draw_map_void_trench_icon()
		"map_graveyard_icon":
			_draw_map_graveyard_icon()
		"visor":
			_draw_visor()
		"headset":
			_draw_headset()
		"nightvision_goggles":
			_draw_nightvision_goggles()
		"sentinel_icon":
			_draw_sentinel_icon()
		"rift_wraith_icon":
			_draw_rift_wraith_icon()
		"pet_lizard":
			_draw_pet_lizard()
		"pet_bird":
			_draw_pet_bird()
		"pet_teddy":
			_draw_pet_teddy()
		"pet_bunny":
			_draw_pet_bunny()
		"pet_elephant":
			_draw_pet_elephant()
		"sword":
			_draw_sword()
		"chestplate":
			_draw_chestplate()
		"helmet":
			_draw_helmet()
		"ring":
			_draw_ring()
		"watch":
			_draw_watch()
		"medkit":
			_draw_medkit()
		"bandage":
			_draw_bandage()
		"mre_pouch":
			_draw_mre_pouch()
		"grenade":
			_draw_grenade()
		"ammo_light":
			_draw_ammo_box(1)
		"ammo_medium":
			_draw_ammo_box(2)
		"ammo_heavy":
			_draw_ammo_box(3)
		"smoke_grenade":
			_draw_smoke_grenade()
		"stun_grenade":
			_draw_stun_grenade()
		"molotov":
			_draw_molotov()
		"flare":
			_draw_flare()
		"rifle":
			_draw_rifle()
		"shotgun":
			_draw_shotgun()
		"sniper":
			_draw_sniper()
		"flamethrower":
			_draw_flamethrower()
		"thorn":
			_draw_thorn()
		"railgun":
			_draw_railgun()
		"alpha_cannon":
			_draw_alpha_cannon()
		"pet_dog":
			_draw_pet_dog()
		"pet_cat":
			_draw_pet_cat()
		"pet_drone":
			_draw_pet_drone()
		"pet_crow":
			_draw_pet_crow()
		"pet_spider":
			_draw_pet_spider()
		"scope":
			_draw_scope()
		"mag":
			_draw_mag()
		"barrel":
			_draw_barrel()
		"grip":
			_draw_grip()
		"laser":
			_draw_laser()
		"boots":
			_draw_boots()
		"backpack":
			_draw_backpack()
		"key":
			_draw_key()
		"rubles_item":
			_draw_rubles_item()
		"artifacts_item":
			_draw_artifacts_item()
		"alloys_item":
			_draw_alloys_item()
		"skill_points_item":
			_draw_skill_points_item()
		"canned_food":
			_draw_canned_food()
		"batteries":
			_draw_batteries()
		"soap":
			_draw_soap()
		"chlorine":
			_draw_chlorine()
		"toothpaste":
			_draw_toothpaste()
		"mil_filter":
			_draw_mil_filter()
		"paracord":
			_draw_paracord()
		"screws":
			_draw_screws()
		"hard_plate":
			_draw_hard_plate()
		"duct_tape":
			_draw_duct_tape()
		"cloth":
			_draw_cloth()
		"antiseptic":
			_draw_antiseptic()
		"lootbag":
			_draw_lootbag()
		"gas_mask":
			_draw_gas_mask()
		"gpu":
			_draw_gpu()
		"gpcoin":
			_draw_gpcoin()
		"dogtag":
			_draw_dogtag()
		"blueprint":
			_draw_blueprint()
		_:
			_draw_generic()
	if tag_text != "":
		_draw_tag_label()

# Small text label in the corner for a player-named/colored tag (Loot
# Bags, Pet Cases). Drawn with a dark backing strip so it stays
# readable over any icon color.
func _draw_tag_label() -> void:
	var font := ThemeDB.fallback_font
	var fsize: int = max(7, int(size.y * 0.16))
	var text_size: Vector2 = font.get_string_size(tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
	var pad := Vector2(3, 1)
	var strip_h: float = text_size.y + pad.y * 2.0
	draw_rect(Rect2(Vector2(0, size.y - strip_h), Vector2(size.x, strip_h)), Color(0, 0, 0, 0.72))
	var pos := Vector2((size.x - text_size.x) / 2.0, size.y - pad.y - 1.5)
	draw_string(font, pos, tag_text, HORIZONTAL_ALIGNMENT_LEFT, size.x, fsize, tag_color)

func _draw_pistol() -> void:
	var pts := PackedVector2Array([
		_p(0.05, 0.38), _p(0.92, 0.38), _p(0.92, 0.50), _p(0.34, 0.50),
		_p(0.34, 0.56), _p(0.30, 0.88), _p(0.16, 0.88), _p(0.18, 0.56),
		_p(0.05, 0.50)
	])
	draw_colored_polygon(pts, icon_color)
	# A slim top-edge highlight and bottom-edge shadow turn the flat
	# silhouette into a lightly beveled, more metallic-looking shape.
	draw_line(_p(0.07, 0.395), _p(0.90, 0.395), icon_color.lightened(0.4), max(1.0, size.y * 0.025))
	draw_line(_p(0.19, 0.865), _p(0.28, 0.865), icon_color.darkened(0.4), max(1.0, size.y * 0.025))
	draw_circle(_p(0.62, 0.44), size.x * 0.025, icon_color.darkened(0.3))

func _draw_egg() -> void:
	var pts := PackedVector2Array([
		_p(0.5, 0.08), _p(0.72, 0.2), _p(0.85, 0.48), _p(0.82, 0.72),
		_p(0.66, 0.9), _p(0.5, 0.94), _p(0.34, 0.9), _p(0.18, 0.72),
		_p(0.15, 0.48), _p(0.28, 0.2)
	])
	draw_colored_polygon(pts, icon_color)
	var speckle_col := Color(icon_color.r * 0.6, icon_color.g * 0.6, icon_color.b * 0.6, 0.6)
	draw_circle(_p(0.4, 0.4), 2.5, speckle_col)
	draw_circle(_p(0.6, 0.55), 2.0, speckle_col)
	draw_circle(_p(0.45, 0.68), 1.8, speckle_col)

func _draw_sword() -> void:
	var blade := PackedVector2Array([_p(0.5, 0.05), _p(0.60, 0.55), _p(0.40, 0.55)])
	draw_colored_polygon(blade, icon_color)
	var guard := PackedVector2Array([_p(0.26, 0.55), _p(0.74, 0.55), _p(0.74, 0.63), _p(0.26, 0.63)])
	draw_colored_polygon(guard, icon_color)
	var handle := PackedVector2Array([_p(0.45, 0.63), _p(0.55, 0.63), _p(0.55, 0.85), _p(0.45, 0.85)])
	draw_colored_polygon(handle, icon_color)
	draw_circle(_p(0.5, 0.90), size.x * 0.05, icon_color)

func _draw_chestplate() -> void:
	var pts := PackedVector2Array([
		_p(0.28, 0.15), _p(0.72, 0.15), _p(0.85, 0.35),
		_p(0.72, 0.88), _p(0.28, 0.88), _p(0.15, 0.35)
	])
	draw_colored_polygon(pts, icon_color)
	draw_line(_p(0.5, 0.20), _p(0.5, 0.85), Color(0, 0, 0, 0.35), max(1.0, size.x * 0.02))
	draw_circle(_p(0.28, 0.20), size.x * 0.06, icon_color)
	draw_circle(_p(0.72, 0.20), size.x * 0.06, icon_color)

func _draw_helmet() -> void:
	draw_circle(_p(0.5, 0.42), size.x * 0.32, icon_color)
	var brim := PackedVector2Array([_p(0.18, 0.45), _p(0.82, 0.45), _p(0.82, 0.58), _p(0.18, 0.58)])
	draw_colored_polygon(brim, icon_color)
	draw_rect(Rect2(_p(0.30, 0.46), Vector2(size.x * 0.40, size.y * 0.05)), Color(0, 0, 0, 0.5))

func _draw_ring() -> void:
	draw_arc(_p(0.5, 0.65), size.x * 0.20, 0, TAU, 24, icon_color, size.x * 0.07, true)
	var gem := PackedVector2Array([_p(0.5, 0.24), _p(0.60, 0.34), _p(0.5, 0.44), _p(0.40, 0.34)])
	draw_colored_polygon(gem, Color(0.5, 0.85, 0.95, 1))

func _draw_watch() -> void:
	draw_rect(Rect2(_p(0.42, 0.03), Vector2(size.x * 0.16, size.y * 0.20)), icon_color)
	draw_rect(Rect2(_p(0.42, 0.60), Vector2(size.x * 0.16, size.y * 0.32)), icon_color)
	draw_circle(_p(0.5, 0.40), size.x * 0.22, icon_color)
	draw_circle(_p(0.5, 0.40), size.x * 0.15, Color(0.9, 0.9, 0.9, 1))

func _draw_generic() -> void:
	var pts := PackedVector2Array([_p(0.5, 0.1), _p(0.9, 0.5), _p(0.5, 0.9), _p(0.1, 0.5)])
	draw_colored_polygon(pts, icon_color)

func _draw_raider_icon() -> void:
	# A simple armed humanoid silhouette - head, torso, and a raised arm
	# holding a weapon, reading clearly as "hostile person" at a glance.
	draw_circle(_p(0.5, 0.22), size.x * 0.11, icon_color)
	var torso := PackedVector2Array([_p(0.36, 0.36), _p(0.64, 0.36), _p(0.7, 0.78), _p(0.3, 0.78)])
	draw_colored_polygon(torso, icon_color)
	var arm := PackedVector2Array([_p(0.62, 0.4), _p(0.9, 0.3), _p(0.92, 0.4), _p(0.68, 0.52)])
	draw_colored_polygon(arm, icon_color)
	draw_rect(Rect2(_p(0.36, 0.78), Vector2(size.x * 0.1, size.y * 0.16)), icon_color)
	draw_rect(Rect2(_p(0.54, 0.78), Vector2(size.x * 0.1, size.y * 0.16)), icon_color)

func _draw_ghost_icon() -> void:
	# Classic rounded-top, wavy-bottom ghost shape.
	var pts := PackedVector2Array()
	var segs := 16
	for i in range(segs + 1):
		var t: float = float(i) / segs
		var ang: float = PI + t * PI
		pts.append(_p(0.5 + cos(ang) * 0.34, 0.42 + sin(ang) * 0.32))
	pts.append(_p(0.84, 0.42))
	var wave_points := [0.84, 0.72, 0.6, 0.5, 0.4, 0.28, 0.16]
	for i in range(wave_points.size()):
		var wy: float = 0.82 if i % 2 == 0 else 0.7
		pts.append(_p(wave_points[i], wy))
	draw_colored_polygon(pts, Color(icon_color.r, icon_color.g, icon_color.b, 0.75))
	draw_circle(_p(0.4, 0.44), size.x * 0.045, Color(0.05, 0.05, 0.05, 0.8))
	draw_circle(_p(0.6, 0.44), size.x * 0.045, Color(0.05, 0.05, 0.05, 0.8))

func _draw_wisp_icon() -> void:
	# A glowing drifting orb with a soft trailing tail.
	draw_circle(_p(0.5, 0.42), size.x * 0.16, Color(icon_color.r, icon_color.g, icon_color.b, 0.4))
	draw_circle(_p(0.5, 0.42), size.x * 0.09, icon_color)
	var tail := PackedVector2Array([_p(0.44, 0.5), _p(0.56, 0.5), _p(0.52, 0.86), _p(0.48, 0.86)])
	draw_colored_polygon(tail, Color(icon_color.r, icon_color.g, icon_color.b, 0.4))

func _draw_ghoul_icon() -> void:
	# A hunched, shambling humanoid silhouette - rounded head, arched
	# back, one arm reaching forward.
	draw_circle(_p(0.42, 0.22), size.x * 0.11, icon_color)
	var torso := PackedVector2Array([_p(0.28, 0.32), _p(0.56, 0.28), _p(0.7, 0.5), _p(0.6, 0.72), _p(0.32, 0.74), _p(0.22, 0.5)])
	draw_colored_polygon(torso, icon_color)
	var arm_front := PackedVector2Array([_p(0.58, 0.42), _p(0.82, 0.5), _p(0.8, 0.6), _p(0.56, 0.56)])
	draw_colored_polygon(arm_front, icon_color)
	var arm_back := PackedVector2Array([_p(0.26, 0.4), _p(0.14, 0.56), _p(0.2, 0.64), _p(0.32, 0.5)])
	draw_colored_polygon(arm_back, icon_color)
	draw_rect(Rect2(_p(0.32, 0.74), Vector2(size.x * 0.09, size.y * 0.16)), icon_color)
	draw_rect(Rect2(_p(0.5, 0.74), Vector2(size.x * 0.09, size.y * 0.16)), icon_color)

# A bat silhouette - wide pointed wings, a small round body, and two
# short ears - distinct from the Goblin's icon below, since they used
# to share the same generic gas mask icon. Always renders in its own
# dark slate color regardless of icon_color, the same way the Goblin
# always renders green - a bat rendered in whatever flat tint a screen
# happens to be using (gold in the Data panel, for instance) just reads
# as a shapeless blob instead of a bat.
func _draw_bat_icon() -> void:
	var bat_col := Color(0.22, 0.2, 0.28, icon_color.a)
	var left_wing := PackedVector2Array([
		_p(0.5, 0.46), _p(0.28, 0.3), _p(0.1, 0.34), _p(0.24, 0.42),
		_p(0.06, 0.5), _p(0.26, 0.5), _p(0.16, 0.62), _p(0.5, 0.55),
	])
	draw_colored_polygon(left_wing, bat_col)
	var right_wing := PackedVector2Array([
		_p(0.5, 0.46), _p(0.72, 0.3), _p(0.9, 0.34), _p(0.76, 0.42),
		_p(0.94, 0.5), _p(0.74, 0.5), _p(0.84, 0.62), _p(0.5, 0.55),
	])
	draw_colored_polygon(right_wing, bat_col)
	draw_circle(_p(0.5, 0.48), size.x * 0.1, bat_col)
	var ear1 := PackedVector2Array([_p(0.42, 0.4), _p(0.4, 0.28), _p(0.46, 0.38)])
	draw_colored_polygon(ear1, bat_col)
	var ear2 := PackedVector2Array([_p(0.58, 0.4), _p(0.6, 0.28), _p(0.54, 0.38)])
	draw_colored_polygon(ear2, bat_col)

# A green goblin head - round face, pointed ears, a grinning mouth with
# two small tusks. Always reads as green regardless of icon_color (the
# way a rarity-tinted goblin doesn't really make sense), same way the
# Ring icon always shows its gem in a fixed color.
func _draw_goblin_icon() -> void:
	var green := Color(0.35, 0.75, 0.25, icon_color.a)
	var dark := Color(0.05, 0.05, 0.05, icon_color.a)
	var tusk := Color(0.95, 0.95, 0.85, icon_color.a)
	draw_circle(_p(0.5, 0.46), size.x * 0.26, green)
	var ear1 := PackedVector2Array([_p(0.26, 0.44), _p(0.12, 0.34), _p(0.28, 0.56)])
	draw_colored_polygon(ear1, green)
	var ear2 := PackedVector2Array([_p(0.74, 0.44), _p(0.88, 0.34), _p(0.72, 0.56)])
	draw_colored_polygon(ear2, green)
	draw_circle(_p(0.4, 0.42), size.x * 0.035, dark)
	draw_circle(_p(0.6, 0.42), size.x * 0.035, dark)
	var grin := PackedVector2Array([_p(0.34, 0.56), _p(0.66, 0.56), _p(0.6, 0.66), _p(0.4, 0.66)])
	draw_colored_polygon(grin, dark)
	draw_rect(Rect2(_p(0.39, 0.56), Vector2(size.x * 0.045, size.y * 0.06)), tusk)
	draw_rect(Rect2(_p(0.565, 0.56), Vector2(size.x * 0.045, size.y * 0.06)), tusk)

# Rose - brown hair framing a round face, a pink collar visible at the
# shoulders. A simple, friendly portrait, not tied to icon_color like
# most icons since a person's portrait shouldn't re-tint by rarity.
func _draw_rose_icon() -> void:
	var skin := Color(0.85, 0.68, 0.55, 1)
	var hair := Color(0.35, 0.22, 0.14, 1)
	var pink := Color(0.95, 0.55, 0.75, 1)
	# Pink collar/shoulders first, behind the head.
	var shoulders := PackedVector2Array([_p(0.2, 0.78), _p(0.8, 0.78), _p(0.72, 1.0), _p(0.28, 1.0)])
	draw_colored_polygon(shoulders, pink)
	# Hair behind the face (wider than the face itself, framing it).
	draw_circle(_p(0.5, 0.42), size.x * 0.32, hair)
	# Face.
	draw_circle(_p(0.5, 0.45), size.x * 0.25, skin)
	# A side-swept fringe and two shoulder-length locks.
	var fringe := PackedVector2Array([_p(0.28, 0.32), _p(0.5, 0.2), _p(0.72, 0.32), _p(0.62, 0.36), _p(0.5, 0.28), _p(0.38, 0.36)])
	draw_colored_polygon(fringe, hair)
	var lock_l := PackedVector2Array([_p(0.22, 0.4), _p(0.3, 0.38), _p(0.26, 0.68), _p(0.18, 0.64)])
	draw_colored_polygon(lock_l, hair)
	var lock_r := PackedVector2Array([_p(0.78, 0.4), _p(0.7, 0.38), _p(0.74, 0.68), _p(0.82, 0.64)])
	draw_colored_polygon(lock_r, hair)
	# Simple friendly eyes and a smile.
	draw_circle(_p(0.42, 0.46), size.x * 0.025, Color(0.2, 0.12, 0.1, 1))
	draw_circle(_p(0.58, 0.46), size.x * 0.025, Color(0.2, 0.12, 0.1, 1))
	draw_arc(_p(0.5, 0.53), size.x * 0.08, 0.15 * PI, 0.85 * PI, 12, Color(0.75, 0.4, 0.35, 1), size.x * 0.015, true)

# A soft teddy-bear-style plushie - round ears, a round head, a rounder
# body, an X-stitch for one eye (the well-loved, slightly-worn look).
func _draw_plushie_icon() -> void:
	var fur := icon_color
	var fur_dark := icon_color.darkened(0.12)
	draw_circle(_p(0.28, 0.28), size.x * 0.13, fur)
	draw_circle(_p(0.72, 0.28), size.x * 0.13, fur)
	draw_circle(_p(0.5, 0.38), size.x * 0.22, fur)
	var body := PackedVector2Array([_p(0.28, 0.55), _p(0.72, 0.55), _p(0.8, 0.82), _p(0.5, 0.94), _p(0.2, 0.82)])
	draw_colored_polygon(body, fur_dark)
	draw_circle(_p(0.42, 0.36), size.x * 0.03, Color(0.15, 0.1, 0.08, icon_color.a))
	draw_line(_p(0.55, 0.33), _p(0.63, 0.39), Color(0.15, 0.1, 0.08, icon_color.a), size.x * 0.015)
	draw_line(_p(0.63, 0.33), _p(0.55, 0.39), Color(0.15, 0.1, 0.08, icon_color.a), size.x * 0.015)
	draw_line(_p(0.5, 0.42), _p(0.5, 0.47), Color(0.3, 0.2, 0.15, icon_color.a), size.x * 0.012)

func _draw_stalker_icon() -> void:
	# A hunched, crouched humanoid - reads distinctly from the upright
	# raider silhouette so the two enemy types are visually separate.
	draw_circle(_p(0.44, 0.3), size.x * 0.1, icon_color)
	var torso := PackedVector2Array([_p(0.3, 0.4), _p(0.6, 0.44), _p(0.66, 0.7), _p(0.24, 0.72)])
	draw_colored_polygon(torso, icon_color)
	var arm := PackedVector2Array([_p(0.56, 0.46), _p(0.82, 0.58), _p(0.78, 0.68), _p(0.52, 0.58)])
	draw_colored_polygon(arm, icon_color)
	draw_rect(Rect2(_p(0.28, 0.72), Vector2(size.x * 0.1, size.y * 0.14)), icon_color)
	draw_rect(Rect2(_p(0.5, 0.72), Vector2(size.x * 0.1, size.y * 0.14)), icon_color)

func _draw_sniper_enemy_icon() -> void:
	# An upright humanoid holding a long rifle shape out to one side.
	draw_circle(_p(0.4, 0.22), size.x * 0.1, icon_color)
	var torso := PackedVector2Array([_p(0.28, 0.34), _p(0.54, 0.34), _p(0.58, 0.74), _p(0.24, 0.74)])
	draw_colored_polygon(torso, icon_color)
	draw_rect(Rect2(_p(0.5, 0.36), Vector2(size.x * 0.44, size.y * 0.05)), icon_color)
	draw_rect(Rect2(_p(0.24, 0.74), Vector2(size.x * 0.1, size.y * 0.18)), icon_color)
	draw_rect(Rect2(_p(0.42, 0.74), Vector2(size.x * 0.1, size.y * 0.18)), icon_color)

func _draw_warden_icon() -> void:
	# A large, hulking silhouette with wide shoulders - reads as "boss"
	# at a glance, distinct from the regular armored/hard_plate icon.
	draw_circle(_p(0.5, 0.2), size.x * 0.13, icon_color)
	var torso := PackedVector2Array([_p(0.2, 0.36), _p(0.8, 0.36), _p(0.88, 0.5), _p(0.74, 0.86), _p(0.26, 0.86), _p(0.12, 0.5)])
	draw_colored_polygon(torso, icon_color)
	var glow_col := Color(1, 0.3, 0.25, 0.9)
	draw_circle(_p(0.4, 0.46), size.x * 0.04, glow_col)
	draw_circle(_p(0.6, 0.46), size.x * 0.04, glow_col)

func _draw_blossom_icon() -> void:
	# A simple 5-petal flower with a glowing center.
	for i in range(5):
		var ang: float = TAU * float(i) / 5.0 - PI / 2.0
		var petal_center: Vector2 = _p(0.5, 0.5) + Vector2(cos(ang), sin(ang)) * size.x * 0.2
		draw_circle(petal_center, size.x * 0.16, Color(icon_color.r, icon_color.g, icon_color.b, 0.85))
	draw_circle(_p(0.5, 0.5), size.x * 0.11, Color(1, 1, 0.85, 0.95))

func _draw_rust_shard_icon() -> void:
	# A jagged, angular fragment of corroded metal.
	var pts := PackedVector2Array([
		_p(0.5, 0.08), _p(0.68, 0.32), _p(0.9, 0.4), _p(0.7, 0.56),
		_p(0.78, 0.9), _p(0.5, 0.68), _p(0.22, 0.9), _p(0.3, 0.56),
		_p(0.1, 0.4), _p(0.32, 0.32),
	])
	draw_colored_polygon(pts, icon_color)
	draw_colored_polygon(PackedVector2Array([_p(0.5, 0.08), _p(0.68, 0.32), _p(0.5, 0.4), _p(0.32, 0.32)]),
		Color(icon_color.r * 1.2, icon_color.g * 1.1, icon_color.b, 0.5))

func _draw_static_mote_icon() -> void:
	# A small crackling spark - a lightning-bolt core with a soft glow ring.
	draw_circle(_p(0.5, 0.5), size.x * 0.32, Color(icon_color.r, icon_color.g, icon_color.b, 0.25))
	var bolt := PackedVector2Array([_p(0.56, 0.14), _p(0.36, 0.52), _p(0.48, 0.52), _p(0.42, 0.86), _p(0.66, 0.42), _p(0.54, 0.42)])
	draw_colored_polygon(bolt, icon_color)

func _draw_void_shard_icon() -> void:
	# A jagged crystal shard, fractured like the rift it's pulled from,
	# with a bright inner core hinting at the energy still trapped in it.
	var pts := PackedVector2Array([
		_p(0.5, 0.06), _p(0.72, 0.34), _p(0.62, 0.4), _p(0.88, 0.56),
		_p(0.58, 0.58), _p(0.68, 0.94), _p(0.42, 0.62), _p(0.3, 0.7),
		_p(0.36, 0.42), _p(0.14, 0.44), _p(0.4, 0.3),
	])
	draw_colored_polygon(pts, Color(icon_color.r, icon_color.g, icon_color.b, 0.85))
	draw_circle(_p(0.5, 0.48), size.x * 0.1, Color(1.0, 0.95, 1.0, 0.9))

func _draw_spectral_ash_icon() -> void:
	# Drifting wisps of pale ash, curling upward - the residue the
	# Graveyard's shadow-beasts leave behind.
	for i in range(3):
		var bx: float = 0.3 + float(i) * 0.2
		var wisp := PackedVector2Array([
			_p(bx, 0.9), _p(bx - 0.06, 0.55), _p(bx + 0.05, 0.3), _p(bx - 0.02, 0.1),
		])
		draw_polyline(wisp, Color(icon_color.r, icon_color.g, icon_color.b, 0.75), size.x * 0.05)
	draw_circle(_p(0.5, 0.5), size.x * 0.3, Color(icon_color.r, icon_color.g, icon_color.b, 0.15))

# Overgrowth - a simple leaf/plant silhouette on a stem, matching the
# overgrown-suburb theme.
func _draw_map_overgrowth_icon() -> void:
	var green := Color(0.35, 0.7, 0.35, icon_color.a)
	draw_line(_p(0.5, 0.9), _p(0.5, 0.35), Color(0.3, 0.5, 0.25, icon_color.a), size.x * 0.03)
	var leaf_l := PackedVector2Array([_p(0.5, 0.55), _p(0.2, 0.45), _p(0.22, 0.25), _p(0.5, 0.3)])
	draw_colored_polygon(leaf_l, green)
	var leaf_r := PackedVector2Array([_p(0.5, 0.45), _p(0.8, 0.35), _p(0.78, 0.15), _p(0.5, 0.2)])
	draw_colored_polygon(leaf_r, green)

# Boneclock - a clock face with an X-shaped crack and crossed bones
# below it, matching Rattles' Bone Clocktower.
func _draw_map_boneclock_icon() -> void:
	draw_arc(_p(0.5, 0.4), size.x * 0.26, 0, TAU, 24, icon_color, size.x * 0.035, true)
	draw_line(_p(0.5, 0.4), _p(0.5, 0.24), icon_color, size.x * 0.03)
	draw_line(_p(0.5, 0.4), _p(0.62, 0.44), icon_color, size.x * 0.03)
	var bone := Color(0.85, 0.82, 0.75, icon_color.a)
	draw_line(_p(0.32, 0.78), _p(0.68, 0.68), bone, size.x * 0.045)
	draw_line(_p(0.32, 0.68), _p(0.68, 0.78), bone, size.x * 0.045)
	for pt in [_p(0.32, 0.78), _p(0.68, 0.68), _p(0.32, 0.68), _p(0.68, 0.78)]:
		draw_circle(pt, size.x * 0.03, bone)

# Void Trench - a jagged purple rift tear with a faint glow, matching
# the map's Unstable Rifts.
func _draw_map_void_trench_icon() -> void:
	var purple := Color(0.55, 0.3, 0.9, icon_color.a)
	draw_circle(_p(0.5, 0.5), size.x * 0.32, Color(purple.r, purple.g, purple.b, 0.2))
	var rift := PackedVector2Array([
		_p(0.5, 0.16), _p(0.58, 0.38), _p(0.78, 0.42), _p(0.6, 0.54),
		_p(0.68, 0.82), _p(0.5, 0.64), _p(0.32, 0.82), _p(0.4, 0.54),
		_p(0.22, 0.42), _p(0.42, 0.38),
	])
	draw_colored_polygon(rift, purple)

# The Graveyard - a simple headstone silhouette with a small cross.
func _draw_map_graveyard_icon() -> void:
	var stone := Color(0.55, 0.58, 0.6, icon_color.a)
	var headstone := PackedVector2Array([
		_p(0.3, 0.85), _p(0.3, 0.4), _p(0.5, 0.22), _p(0.7, 0.4), _p(0.7, 0.85),
	])
	draw_colored_polygon(headstone, stone)
	draw_line(_p(0.5, 0.42), _p(0.5, 0.58), Color(0.3, 0.32, 0.34, icon_color.a), size.x * 0.025)
	draw_line(_p(0.42, 0.5), _p(0.58, 0.5), Color(0.3, 0.32, 0.34, icon_color.a), size.x * 0.025)

func _draw_visor() -> void:
	# A slim curved tactical visor strip.
	var pts := PackedVector2Array([
		_p(0.1, 0.42), _p(0.9, 0.42), _p(0.86, 0.62), _p(0.14, 0.62),
	])
	draw_colored_polygon(pts, icon_color)
	var lens := PackedVector2Array([_p(0.2, 0.46), _p(0.8, 0.46), _p(0.78, 0.56), _p(0.22, 0.56)])
	draw_colored_polygon(lens, Color(0.6, 0.9, 1.0, 0.6))
	var strap := PackedVector2Array([_p(0.08, 0.44), _p(0.12, 0.44), _p(0.12, 0.6), _p(0.08, 0.6)])
	draw_colored_polygon(strap, icon_color)
	var strap2 := PackedVector2Array([_p(0.88, 0.44), _p(0.92, 0.44), _p(0.92, 0.6), _p(0.88, 0.6)])
	draw_colored_polygon(strap2, icon_color)

func _draw_headset() -> void:
	# Over-ear comms headset - an arc band with two ear cups.
	draw_arc(_p(0.5, 0.5), size.x * 0.32, PI * 1.1, PI * 1.9, 16, icon_color, size.x * 0.06, true)
	draw_circle(_p(0.2, 0.42), size.x * 0.11, icon_color)
	draw_circle(_p(0.8, 0.42), size.x * 0.11, icon_color)
	var mic := PackedVector2Array([_p(0.24, 0.5), _p(0.28, 0.5), _p(0.4, 0.72), _p(0.36, 0.74)])
	draw_colored_polygon(mic, icon_color)

func _draw_nightvision_goggles() -> void:
	# Bulky dual-lens NVG unit with a head strap - reads distinctly
	# bulkier and more mechanical than the slim visor.
	var body_shape := PackedVector2Array([
		_p(0.14, 0.4), _p(0.86, 0.4), _p(0.86, 0.66), _p(0.14, 0.66),
	])
	draw_colored_polygon(body_shape, icon_color)
	draw_circle(_p(0.32, 0.53), size.x * 0.12, Color(0.3, 1.0, 0.4, 0.85))
	draw_circle(_p(0.68, 0.53), size.x * 0.12, Color(0.3, 1.0, 0.4, 0.85))
	draw_circle(_p(0.32, 0.53), size.x * 0.12, Color(0.05, 0.05, 0.05, 1), false, size.x * 0.015)
	draw_circle(_p(0.68, 0.53), size.x * 0.12, Color(0.05, 0.05, 0.05, 1), false, size.x * 0.015)
	var strap := PackedVector2Array([_p(0.1, 0.42), _p(0.14, 0.42), _p(0.14, 0.64), _p(0.1, 0.64)])
	draw_colored_polygon(strap, Color(icon_color.r * 0.7, icon_color.g * 0.7, icon_color.b * 0.7, 1))
	var strap2 := PackedVector2Array([_p(0.86, 0.42), _p(0.9, 0.42), _p(0.9, 0.64), _p(0.86, 0.64)])
	draw_colored_polygon(strap2, Color(icon_color.r * 0.7, icon_color.g * 0.7, icon_color.b * 0.7, 1))

func _draw_sentinel_icon() -> void:
	# A wide, squat armored silhouette with a shielded stance - reads
	# as defensive and heavy rather than mobile.
	var legs := PackedVector2Array([_p(0.32, 0.72), _p(0.68, 0.72), _p(0.72, 0.9), _p(0.28, 0.9)])
	draw_colored_polygon(legs, icon_color)
	var torso_shape := PackedVector2Array([_p(0.2, 0.32), _p(0.8, 0.32), _p(0.86, 0.5), _p(0.78, 0.74), _p(0.22, 0.74), _p(0.14, 0.5)])
	draw_colored_polygon(torso_shape, icon_color)
	draw_circle(_p(0.5, 0.2), size.x * 0.1, icon_color)
	var visor := Color(0.2, 0.7, 0.9, 0.9)
	draw_rect(Rect2(_p(0.32, 0.44), Vector2(size.x * 0.36, size.y * 0.08)), visor)

func _draw_rift_wraith_icon() -> void:
	# A jagged, torn silhouette - a ghost shape ripped open at the edges
	# like a hole in reality, rather than a clean rounded ghost.
	var pts := PackedVector2Array([
		_p(0.5, 0.1), _p(0.68, 0.28), _p(0.86, 0.24), _p(0.78, 0.44),
		_p(0.9, 0.58), _p(0.7, 0.6), _p(0.76, 0.82), _p(0.56, 0.68),
		_p(0.5, 0.9), _p(0.44, 0.68), _p(0.24, 0.82), _p(0.3, 0.6),
		_p(0.1, 0.58), _p(0.22, 0.44), _p(0.14, 0.24), _p(0.32, 0.28),
	])
	draw_colored_polygon(pts, Color(icon_color.r, icon_color.g, icon_color.b, 0.75))
	draw_circle(_p(0.4, 0.45), size.x * 0.05, Color(0.9, 0.6, 1.0, 0.9))
	draw_circle(_p(0.6, 0.45), size.x * 0.05, Color(0.9, 0.6, 1.0, 0.9))

func _draw_pet_lizard() -> void:
	# A low, long-tailed reptile silhouette with a curved back and frill.
	var body_shape := PackedVector2Array([
		_p(0.2, 0.62), _p(0.3, 0.42), _p(0.55, 0.36), _p(0.7, 0.44), _p(0.72, 0.6), _p(0.5, 0.68), _p(0.28, 0.66),
	])
	draw_colored_polygon(body_shape, icon_color)
	var tail := PackedVector2Array([_p(0.18, 0.6), _p(0.02, 0.72), _p(0.06, 0.78), _p(0.22, 0.68)])
	draw_colored_polygon(tail, icon_color)
	draw_circle(_p(0.68, 0.42), size.x * 0.08, icon_color)
	var frill := PackedVector2Array([_p(0.5, 0.36), _p(0.46, 0.24), _p(0.54, 0.26), _p(0.58, 0.36)])
	draw_colored_polygon(frill, Color(icon_color.r * 1.2, icon_color.g * 0.9, icon_color.b, 0.8))
	draw_circle(_p(0.72, 0.4), size.x * 0.02, Color(0.05, 0.05, 0.05, 0.9))
	for lx in [0.32, 0.44, 0.58]:
		var leg := PackedVector2Array([_p(lx, 0.62), _p(lx + 0.04, 0.62), _p(lx + 0.02, 0.74)])
		draw_colored_polygon(leg, icon_color)

func _draw_pet_spider() -> void:
	# A round-bodied spider with 10 thin legs radiating in two fanned
	# rows (5 per side) - the Loom-weaver's signature silhouette, even
	# at icon size.
	draw_circle(_p(0.5, 0.56), size.x * 0.16, icon_color)
	draw_circle(_p(0.5, 0.36), size.x * 0.1, icon_color)
	for i in range(5):
		var t: float = float(i) / 4.0
		var ang_l: float = lerp(-0.55, 0.75, t) + PI
		var ang_r: float = lerp(-0.55, 0.75, t)
		var base := _p(0.5, 0.56)
		var mid_l := base + Vector2(cos(ang_l), sin(ang_l)) * size.x * 0.22
		var end_l := mid_l + Vector2(cos(ang_l + 0.5), sin(ang_l + 0.5)) * size.x * 0.16
		var mid_r := base + Vector2(cos(ang_r), sin(ang_r)) * size.x * 0.22
		var end_r := mid_r + Vector2(cos(ang_r - 0.5), sin(ang_r - 0.5)) * size.x * 0.16
		draw_line(base, mid_l, icon_color, size.x * 0.025)
		draw_line(mid_l, end_l, icon_color, size.x * 0.02)
		draw_line(base, mid_r, icon_color, size.x * 0.025)
		draw_line(mid_r, end_r, icon_color, size.x * 0.02)
	draw_circle(_p(0.46, 0.34), size.x * 0.02, Color(0.85, 0.2, 0.25, 0.9))
	draw_circle(_p(0.54, 0.34), size.x * 0.02, Color(0.85, 0.2, 0.25, 0.9))

func _draw_pet_bird() -> void:
	# A small perched songbird - round body, angled wing, pointed beak.
	draw_circle(_p(0.48, 0.5), size.x * 0.22, icon_color)
	draw_circle(_p(0.62, 0.36), size.x * 0.13, icon_color)
	var beak := PackedVector2Array([_p(0.74, 0.36), _p(0.85, 0.33), _p(0.74, 0.42)])
	draw_colored_polygon(beak, Color(0.9, 0.7, 0.2, 1))
	var wing := PackedVector2Array([_p(0.38, 0.44), _p(0.22, 0.5), _p(0.3, 0.62), _p(0.44, 0.58)])
	draw_colored_polygon(wing, Color(icon_color.r * 0.75, icon_color.g * 0.75, icon_color.b * 0.75, 1))
	draw_circle(_p(0.66, 0.32), size.x * 0.025, Color(0.05, 0.05, 0.05, 0.9))
	var tail := PackedVector2Array([_p(0.28, 0.56), _p(0.14, 0.62), _p(0.16, 0.68), _p(0.32, 0.62)])
	draw_colored_polygon(tail, icon_color)

# Plushie-exclusive: a small living teddy bear - round ears, round
# head/body, a happy little smile instead of the item version's stitched
# X-eye, since this one's alive and looking pleased about it.
func _draw_pet_teddy() -> void:
	draw_circle(_p(0.3, 0.32), size.x * 0.12, icon_color)
	draw_circle(_p(0.7, 0.32), size.x * 0.12, icon_color)
	draw_circle(_p(0.5, 0.44), size.x * 0.24, icon_color)
	var body := PackedVector2Array([_p(0.3, 0.6), _p(0.7, 0.6), _p(0.76, 0.86), _p(0.5, 0.96), _p(0.24, 0.86)])
	draw_colored_polygon(body, Color(icon_color.r * 0.85, icon_color.g * 0.85, icon_color.b * 0.85, 1))
	draw_circle(_p(0.42, 0.42), size.x * 0.028, Color(0.15, 0.1, 0.08, 1))
	draw_circle(_p(0.58, 0.42), size.x * 0.028, Color(0.15, 0.1, 0.08, 1))
	draw_circle(_p(0.5, 0.5), size.x * 0.02, Color(0.2, 0.13, 0.1, 1))
	draw_arc(_p(0.5, 0.53), size.x * 0.07, 0.1 * PI, 0.9 * PI, 10, Color(0.35, 0.22, 0.15, 1), size.x * 0.014, true)

# Plushie-exclusive: a small living bunny - tall soft ears, round body,
# a little cotton tail.
func _draw_pet_bunny() -> void:
	var ear_l := PackedVector2Array([_p(0.36, 0.4), _p(0.3, 0.06), _p(0.42, 0.06), _p(0.44, 0.4)])
	draw_colored_polygon(ear_l, icon_color)
	var ear_r := PackedVector2Array([_p(0.56, 0.4), _p(0.58, 0.06), _p(0.7, 0.06), _p(0.64, 0.4)])
	draw_colored_polygon(ear_r, icon_color)
	draw_colored_polygon(PackedVector2Array([_p(0.34, 0.36), _p(0.38, 0.1), _p(0.4, 0.1), _p(0.38, 0.36)]), Color(0.95, 0.75, 0.8, icon_color.a))
	draw_colored_polygon(PackedVector2Array([_p(0.6, 0.36), _p(0.62, 0.1), _p(0.64, 0.1), _p(0.62, 0.36)]), Color(0.95, 0.75, 0.8, icon_color.a))
	draw_circle(_p(0.5, 0.5), size.x * 0.24, icon_color)
	draw_circle(_p(0.5, 0.78), size.x * 0.2, Color(icon_color.r * 0.9, icon_color.g * 0.9, icon_color.b * 0.9, 1))
	draw_circle(_p(0.42, 0.46), size.x * 0.026, Color(0.15, 0.1, 0.08, 1))
	draw_circle(_p(0.58, 0.46), size.x * 0.026, Color(0.15, 0.1, 0.08, 1))
	draw_circle(_p(0.5, 0.53), size.x * 0.02, Color(0.85, 0.55, 0.55, 1))
	draw_circle(_p(0.86, 0.8), size.x * 0.06, Color(0.96, 0.96, 0.96, icon_color.a))
	var legs := PackedVector2Array([_p(0.45, 0.7), _p(0.47, 0.7), _p(0.47, 0.78), _p(0.45, 0.78)])
	draw_colored_polygon(legs, Color(0.9, 0.7, 0.2, 1))

# Plushie-exclusive, Godforged tier only: a small living elephant -
# big round ears, small ivory tusks, a curled trunk, round body, tinted
# with Ellie's own pink/gold color rather than a natural grey since
# she's meant to stand out from every other plushie pet on sight.
func _draw_pet_elephant() -> void:
	draw_circle(_p(0.24, 0.42), size.x * 0.17, Color(icon_color.r * 0.9, icon_color.g * 0.9, icon_color.b * 0.9, 1))
	draw_circle(_p(0.76, 0.42), size.x * 0.17, Color(icon_color.r * 0.9, icon_color.g * 0.9, icon_color.b * 0.9, 1))
	draw_circle(_p(0.5, 0.46), size.x * 0.26, icon_color)
	var body := PackedVector2Array([_p(0.28, 0.6), _p(0.72, 0.6), _p(0.78, 0.88), _p(0.5, 0.98), _p(0.22, 0.88)])
	draw_colored_polygon(body, Color(icon_color.r * 0.85, icon_color.g * 0.85, icon_color.b * 0.85, 1))
	var tusk_color := Color(0.98, 0.95, 0.88, 1)
	var tusk_l := PackedVector2Array([_p(0.4, 0.58), _p(0.35, 0.66), _p(0.38, 0.68), _p(0.43, 0.6)])
	draw_colored_polygon(tusk_l, tusk_color)
	var tusk_r := PackedVector2Array([_p(0.6, 0.58), _p(0.65, 0.66), _p(0.62, 0.68), _p(0.57, 0.6)])
	draw_colored_polygon(tusk_r, tusk_color)
	var trunk := PackedVector2Array([_p(0.46, 0.56), _p(0.54, 0.56), _p(0.58, 0.72), _p(0.52, 0.88), _p(0.4, 0.9), _p(0.36, 0.84), _p(0.46, 0.82), _p(0.5, 0.7), _p(0.42, 0.66)])
	draw_colored_polygon(trunk, icon_color)
	draw_circle(_p(0.42, 0.42), size.x * 0.026, Color(0.15, 0.1, 0.08, 1))
	draw_circle(_p(0.58, 0.42), size.x * 0.026, Color(0.15, 0.1, 0.08, 1))

func _draw_key() -> void:
	draw_arc(_p(0.32, 0.32), size.x * 0.15, 0, TAU, 20, icon_color, size.x * 0.06, true)
	var shaft := PackedVector2Array([_p(0.42, 0.42), _p(0.82, 0.82), _p(0.76, 0.88), _p(0.36, 0.48)])
	draw_colored_polygon(shaft, icon_color)
	var tooth1 := PackedVector2Array([_p(0.62, 0.62), _p(0.72, 0.62), _p(0.72, 0.72), _p(0.66, 0.72)])
	draw_colored_polygon(tooth1, icon_color)
	var tooth2 := PackedVector2Array([_p(0.72, 0.72), _p(0.8, 0.72), _p(0.8, 0.8), _p(0.76, 0.8)])
	draw_colored_polygon(tooth2, icon_color)

func _draw_sniper() -> void:
	# A long, thin bolt-action silhouette with a raised scope on top.
	var pts := PackedVector2Array([
		_p(0.0, 0.46), _p(0.96, 0.46), _p(0.96, 0.52), _p(0.72, 0.52),
		_p(0.72, 0.60), _p(0.58, 0.60), _p(0.58, 0.52), _p(0.28, 0.52),
		_p(0.28, 0.62), _p(0.18, 0.82), _p(0.10, 0.82), _p(0.14, 0.58),
		_p(0.0, 0.52)
	])
	draw_colored_polygon(pts, icon_color)
	var scope_body := PackedVector2Array([_p(0.45, 0.24), _p(0.78, 0.24), _p(0.78, 0.34), _p(0.45, 0.34)])
	draw_colored_polygon(scope_body, icon_color)
	draw_circle(_p(0.45, 0.29), size.x * 0.045, icon_color)
	draw_circle(_p(0.78, 0.29), size.x * 0.045, icon_color)
	draw_line(_p(0.55, 0.34), _p(0.55, 0.46), icon_color, max(1.0, size.x * 0.025))
	draw_line(_p(0.02, 0.465), _p(0.94, 0.465), icon_color.lightened(0.4), max(1.0, size.y * 0.02))
	draw_circle(_p(0.45, 0.29), size.x * 0.02, icon_color.lightened(0.5))
	draw_circle(_p(0.78, 0.29), size.x * 0.02, icon_color.lightened(0.5))

func _draw_scope() -> void:
	# A cylindrical scope tube seen from the side, with lens glints.
	draw_rect(Rect2(_p(0.15, 0.42), Vector2(size.x * 0.70, size.y * 0.18)), icon_color)
	draw_circle(_p(0.15, 0.51), size.x * 0.11, icon_color)
	draw_circle(_p(0.85, 0.51), size.x * 0.11, icon_color)
	draw_circle(_p(0.85, 0.51), size.x * 0.06, Color(0.55, 0.85, 0.95, 1))
	draw_rect(Rect2(_p(0.44, 0.24), Vector2(size.x * 0.10, size.y * 0.18)), icon_color)

func _draw_mag() -> void:
	# A curved rifle magazine.
	var pts := PackedVector2Array([
		_p(0.38, 0.14), _p(0.62, 0.14), _p(0.68, 0.5),
		_p(0.60, 0.88), _p(0.42, 0.88), _p(0.34, 0.5)
	])
	draw_colored_polygon(pts, icon_color)
	for i in range(3):
		var y: float = 0.28 + float(i) * 0.16
		draw_line(_p(0.38, y), _p(0.62, y), Color(0, 0, 0, 0.3), max(1.0, size.y * 0.015))

func _draw_barrel() -> void:
	# A long cylindrical barrel with cooling vents.
	draw_rect(Rect2(_p(0.08, 0.44), Vector2(size.x * 0.84, size.y * 0.14)), icon_color)
	for i in range(4):
		var x: float = 0.22 + float(i) * 0.18
		draw_rect(Rect2(_p(x, 0.40), Vector2(size.x * 0.05, size.y * 0.22)), Color(0, 0, 0, 0.35))
	draw_circle(_p(0.92, 0.51), size.x * 0.07, icon_color)

func _draw_grip() -> void:
	# An angled vertical foregrip.
	var pts := PackedVector2Array([
		_p(0.38, 0.20), _p(0.62, 0.20), _p(0.68, 0.85), _p(0.32, 0.85)
	])
	draw_colored_polygon(pts, icon_color)
	for i in range(3):
		var y: float = 0.40 + float(i) * 0.14
		draw_line(_p(0.36, y), _p(0.64, y), Color(0, 0, 0, 0.25), max(1.0, size.y * 0.015))

func _draw_laser() -> void:
	# A small laser module firing a bright red beam.
	draw_rect(Rect2(_p(0.15, 0.42), Vector2(size.x * 0.30, size.y * 0.16)), icon_color)
	draw_circle(_p(0.45, 0.5), size.x * 0.03, Color(1, 0.2, 0.2, 1))
	draw_line(_p(0.48, 0.5), _p(0.92, 0.5), Color(1, 0.15, 0.15, 0.85), max(1.0, size.y * 0.02))
	draw_circle(_p(0.92, 0.5), size.x * 0.025, Color(1, 0.5, 0.5, 1))

func _draw_rubles_item() -> void:
	# A small stack of coins/bills.
	draw_colored_polygon(PackedVector2Array([_p(0.2, 0.62), _p(0.8, 0.62), _p(0.8, 0.78), _p(0.2, 0.78)]), Color(0.25, 0.55, 0.3, 1))
	draw_colored_polygon(PackedVector2Array([_p(0.22, 0.46), _p(0.78, 0.46), _p(0.78, 0.62), _p(0.22, 0.62)]), Color(0.3, 0.62, 0.35, 1))
	draw_colored_polygon(PackedVector2Array([_p(0.24, 0.3), _p(0.76, 0.3), _p(0.76, 0.46), _p(0.24, 0.46)]), Color(0.35, 0.7, 0.4, 1))
	draw_circle(_p(0.5, 0.38), size.x * 0.08, Color(0.9, 0.85, 0.4, 0.9))

func _draw_artifacts_item() -> void:
	# A glowing salvaged shard - matches the HUD's purple Artifacts color.
	var shard := PackedVector2Array([
		_p(0.5, 0.14), _p(0.68, 0.4), _p(0.6, 0.5), _p(0.7, 0.6),
		_p(0.5, 0.88), _p(0.34, 0.58), _p(0.42, 0.48), _p(0.32, 0.38),
	])
	draw_colored_polygon(shard, Color(0.63, 0.53, 0.78, 1))
	draw_colored_polygon(PackedVector2Array([_p(0.5, 0.14), _p(0.6, 0.5), _p(0.5, 0.88)]), Color(0.78, 0.68, 0.9, 0.55))
	draw_circle(_p(0.5, 0.4), size.x * 0.05, Color(0.95, 0.9, 1.0, 0.85))

func _draw_alloys_item() -> void:
	# A stamped metal ingot - matches the HUD's green Alloys color.
	var ingot := PackedVector2Array([
		_p(0.24, 0.66), _p(0.32, 0.36), _p(0.68, 0.36), _p(0.76, 0.66),
	])
	draw_colored_polygon(ingot, Color(0.55, 0.72, 0.58, 1))
	draw_line(_p(0.34, 0.6), _p(0.66, 0.6), Color(0.3, 0.45, 0.32, 0.7), max(1.0, size.y * 0.03))
	draw_circle(_p(0.5, 0.48), size.x * 0.05, Color(0.85, 0.95, 0.85, 0.8))

func _draw_skill_points_item() -> void:
	# A small glowing node with radiating spokes, echoing the Skill
	# Tree's own hub-and-branch look so it reads as unmistakably "skill
	# tree currency" at a glance.
	var center_col := Color(0.55, 0.78, 1.0, 1)
	for i in range(6):
		var ang: float = TAU * float(i) / 6.0
		var inner: Vector2 = _p(0.5, 0.5) + Vector2(cos(ang), sin(ang)) * size.x * 0.16
		var outer: Vector2 = _p(0.5, 0.5) + Vector2(cos(ang), sin(ang)) * size.x * 0.42
		draw_line(inner, outer, Color(0.4, 0.6, 0.85, 0.9), max(1.5, size.x * 0.05))
		draw_circle(outer, size.x * 0.05, Color(0.7, 0.85, 1.0, 1))
	draw_circle(_p(0.5, 0.5), size.x * 0.18, Color(0.18, 0.24, 0.32, 1))
	draw_arc(_p(0.5, 0.5), size.x * 0.18, 0.0, TAU, 20, center_col, max(1.5, size.x * 0.04), true)
	draw_circle(_p(0.5, 0.5), size.x * 0.08, center_col)

func _draw_canned_food() -> void:
	draw_rect(Rect2(_p(0.28, 0.22), Vector2(size.x * 0.44, size.y * 0.6)), Color(0.6, 0.55, 0.15, 1))
	draw_rect(Rect2(_p(0.28, 0.2), Vector2(size.x * 0.44, size.y * 0.06)), Color(0.75, 0.75, 0.75, 1))
	draw_rect(Rect2(_p(0.28, 0.76), Vector2(size.x * 0.44, size.y * 0.06)), Color(0.75, 0.75, 0.75, 1))
	draw_line(_p(0.3, 0.4), _p(0.7, 0.4), Color(0.9, 0.85, 0.6, 0.7), max(1.0, size.y * 0.02))

# A sealed foil ration pouch for the MRE - a deliberately different
# silhouette from Ration Pack's tin can above (_draw_canned_food), since
# the two used to share one icon despite being different items. An MRE
# is a pouch, not a can, in real life too.
func _draw_mre_pouch() -> void:
	var pouch := PackedVector2Array([_p(0.26, 0.22), _p(0.74, 0.22), _p(0.78, 0.3), _p(0.78, 0.78), _p(0.22, 0.78), _p(0.22, 0.3)])
	draw_colored_polygon(pouch, Color(0.35, 0.42, 0.32, 1))
	draw_rect(Rect2(_p(0.26, 0.2), Vector2(size.x * 0.48, size.y * 0.06)), Color(0.55, 0.6, 0.5, 1))
	draw_colored_polygon(PackedVector2Array([_p(0.72, 0.22), _p(0.78, 0.22), _p(0.75, 0.28)]), Color(0.15, 0.15, 0.15, 0.6))
	draw_rect(Rect2(_p(0.32, 0.42), Vector2(size.x * 0.36, size.y * 0.05)), Color(0.85, 0.8, 0.6, 0.85))
	draw_line(_p(0.32, 0.56), _p(0.68, 0.56), Color(0.85, 0.8, 0.6, 0.6), max(1.0, size.y * 0.02))
	draw_line(_p(0.32, 0.63), _p(0.6, 0.63), Color(0.85, 0.8, 0.6, 0.6), max(1.0, size.y * 0.02))

func _draw_batteries() -> void:
	for i in range(2):
		var x0: float = 0.28 + float(i) * 0.24
		draw_rect(Rect2(_p(x0, 0.24), Vector2(size.x * 0.18, size.y * 0.52)), Color(0.15, 0.55, 0.25, 1))
		draw_rect(Rect2(_p(x0 + 0.055, 0.18), Vector2(size.x * 0.07, size.y * 0.08)), Color(0.75, 0.7, 0.2, 1))

func _draw_soap() -> void:
	draw_colored_polygon(PackedVector2Array([_p(0.24, 0.4), _p(0.76, 0.36), _p(0.78, 0.62), _p(0.22, 0.66)]), Color(0.75, 0.85, 0.85, 1))
	draw_line(_p(0.32, 0.5), _p(0.68, 0.47), Color(0.5, 0.65, 0.65, 0.6), max(1.0, size.y * 0.015))

func _draw_chlorine() -> void:
	draw_rect(Rect2(_p(0.32, 0.2), Vector2(size.x * 0.14, size.y * 0.12)), Color(0.4, 0.4, 0.4, 1))
	draw_colored_polygon(PackedVector2Array([_p(0.24, 0.32), _p(0.76, 0.32), _p(0.8, 0.86), _p(0.2, 0.86)]), Color(0.75, 0.85, 0.35, 0.85))
	draw_rect(Rect2(_p(0.3, 0.5), Vector2(size.x * 0.4, size.y * 0.18)), Color(0.9, 0.9, 0.9, 0.85))

func _draw_toothpaste() -> void:
	draw_colored_polygon(PackedVector2Array([_p(0.34, 0.18), _p(0.66, 0.18), _p(0.66, 0.32), _p(0.74, 0.4), _p(0.7, 0.82), _p(0.3, 0.82), _p(0.26, 0.4), _p(0.34, 0.32)]), Color(0.85, 0.85, 0.85, 1))
	draw_rect(Rect2(_p(0.4, 0.12), Vector2(size.x * 0.2, size.y * 0.08)), Color(0.5, 0.75, 0.85, 1))
	draw_line(_p(0.3, 0.55), _p(0.7, 0.55), Color(0.3, 0.6, 0.75, 0.8), max(1.0, size.y * 0.03))

func _draw_mil_filter() -> void:
	draw_rect(Rect2(_p(0.3, 0.18), Vector2(size.x * 0.4, size.y * 0.14)), Color(0.3, 0.35, 0.25, 1))
	var body := PackedVector2Array([_p(0.24, 0.32), _p(0.76, 0.32), _p(0.72, 0.84), _p(0.28, 0.84)])
	draw_colored_polygon(body, Color(0.35, 0.42, 0.3, 1))
	for i in range(3):
		draw_line(_p(0.3, 0.42 + float(i) * 0.12), _p(0.7, 0.42 + float(i) * 0.12), Color(0.15, 0.18, 0.13, 0.7), max(1.0, size.y * 0.015))

func _draw_paracord() -> void:
	draw_arc(_p(0.5, 0.5), size.x * 0.28, 0.0, TAU, 24, Color(0.55, 0.42, 0.2, 1), max(2.0, size.x * 0.09), true)
	draw_arc(_p(0.5, 0.5), size.x * 0.16, 0.0, TAU, 20, Color(0.65, 0.5, 0.25, 1), max(2.0, size.x * 0.07), true)

func _draw_screws() -> void:
	for i in range(3):
		var ang: float = float(i) * TAU / 3.0
		var cx: float = 0.5 + cos(ang) * 0.18
		var cy: float = 0.5 + sin(ang) * 0.18
		draw_line(_p(cx, cy - 0.1), _p(cx, cy + 0.1), Color(0.6, 0.6, 0.65, 1), max(1.5, size.x * 0.05))
		draw_circle(_p(cx, cy - 0.1), size.x * 0.035, Color(0.75, 0.75, 0.8, 1))

func _draw_hard_plate() -> void:
	var plate := PackedVector2Array([_p(0.22, 0.2), _p(0.78, 0.2), _p(0.82, 0.5), _p(0.7, 0.86), _p(0.3, 0.86), _p(0.18, 0.5)])
	draw_colored_polygon(plate, Color(0.28, 0.3, 0.32, 1))
	draw_colored_polygon(PackedVector2Array([_p(0.3, 0.28), _p(0.7, 0.28), _p(0.73, 0.48), _p(0.62, 0.7), _p(0.38, 0.7), _p(0.27, 0.48)]), Color(0.4, 0.43, 0.46, 1))

func _draw_duct_tape() -> void:
	draw_circle(_p(0.5, 0.5), size.x * 0.32, Color(0.7, 0.68, 0.55, 1))
	draw_circle(_p(0.5, 0.5), size.x * 0.14, Color(0.15, 0.14, 0.13, 1))
	draw_arc(_p(0.5, 0.5), size.x * 0.32, 0.0, TAU, 24, Color(0.3, 0.28, 0.22, 0.6), 1.5, true)

func _draw_cloth() -> void:
	var cloth := PackedVector2Array([_p(0.22, 0.24), _p(0.78, 0.22), _p(0.74, 0.78), _p(0.26, 0.8)])
	draw_colored_polygon(cloth, Color(0.65, 0.6, 0.5, 1))
	draw_line(_p(0.3, 0.36), _p(0.68, 0.34), Color(0.5, 0.46, 0.38, 0.7), max(1.0, size.y * 0.015))
	draw_line(_p(0.28, 0.55), _p(0.68, 0.53), Color(0.5, 0.46, 0.38, 0.7), max(1.0, size.y * 0.015))

func _draw_antiseptic() -> void:
	draw_rect(Rect2(_p(0.4, 0.14), Vector2(size.x * 0.2, size.y * 0.1)), Color(0.6, 0.6, 0.6, 1))
	draw_colored_polygon(PackedVector2Array([_p(0.28, 0.24), _p(0.72, 0.24), _p(0.76, 0.84), _p(0.24, 0.84)]), Color(0.85, 0.9, 0.9, 0.9))
	draw_line(_p(0.5, 0.42), _p(0.5, 0.62), Color(0.85, 0.2, 0.15, 0.9), max(1.5, size.y * 0.035))
	draw_line(_p(0.4, 0.52), _p(0.6, 0.52), Color(0.85, 0.2, 0.15, 0.9), max(1.5, size.y * 0.035))

func _draw_pet_case() -> void:
	# A small travel carrier - a rounded box with a wire-mesh window.
	var body := PackedVector2Array([_p(0.12, 0.3), _p(0.88, 0.3), _p(0.88, 0.85), _p(0.12, 0.85)])
	draw_colored_polygon(body, icon_color)
	var handle := PackedVector2Array([_p(0.32, 0.3), _p(0.4, 0.14), _p(0.6, 0.14), _p(0.68, 0.3)])
	draw_colored_polygon(handle, Color(icon_color.r * 0.7, icon_color.g * 0.7, icon_color.b * 0.7, 1))
	var window_col := Color(0.1, 0.1, 0.12, 0.85)
	draw_circle(_p(0.5, 0.58), size.x * 0.18, window_col)
	for i in range(3):
		var y: float = 0.46 + i * 0.12
		draw_line(_p(0.36, y), _p(0.64, y), Color(0.6, 0.6, 0.6, 0.7), 1.0)

func _draw_lootbag() -> void:
	# A cinched sack with a drawstring - reads clearly as "mystery loot".
	var sack := PackedVector2Array([_p(0.22, 0.32), _p(0.78, 0.32), _p(0.86, 0.62), _p(0.74, 0.86), _p(0.26, 0.86), _p(0.14, 0.62)])
	draw_colored_polygon(sack, Color(0.55, 0.35, 0.15, 1))
	draw_colored_polygon(PackedVector2Array([_p(0.34, 0.18), _p(0.66, 0.18), _p(0.7, 0.32), _p(0.3, 0.32)]), Color(0.4, 0.25, 0.1, 1))
	draw_arc(_p(0.5, 0.22), size.x * 0.06, PI, TAU, 12, Color(0.3, 0.18, 0.08, 1), 2.0, true)
	draw_circle(_p(0.5, 0.58), size.x * 0.05, Color(0.95, 0.8, 0.3, 0.9))

func _draw_gas_mask() -> void:
	draw_circle(_p(0.5, 0.5), size.x * 0.36, Color(0.15, 0.16, 0.14, 1))
	draw_circle(_p(0.36, 0.44), size.x * 0.13, Color(0.55, 0.75, 0.6, 0.9))
	draw_circle(_p(0.64, 0.44), size.x * 0.13, Color(0.55, 0.75, 0.6, 0.9))
	draw_rect(Rect2(_p(0.44, 0.66), Vector2(size.x * 0.12, size.y * 0.16)), Color(0.2, 0.22, 0.18, 1))
	draw_line(_p(0.18, 0.5), _p(0.08, 0.44), Color(0.25, 0.26, 0.22, 1), max(2.0, size.x * 0.05))

func _draw_gpu() -> void:
	draw_rect(Rect2(_p(0.16, 0.36), Vector2(size.x * 0.68, size.y * 0.34)), Color(0.12, 0.14, 0.12, 1))
	draw_rect(Rect2(_p(0.2, 0.4), Vector2(size.x * 0.6, size.y * 0.26)), Color(0.2, 0.55, 0.3, 1))
	draw_circle(_p(0.35, 0.53), size.x * 0.075, Color(0.08, 0.08, 0.08, 1))
	draw_circle(_p(0.6, 0.53), size.x * 0.075, Color(0.08, 0.08, 0.08, 1))
	draw_rect(Rect2(_p(0.12, 0.7), Vector2(size.x * 0.76, size.y * 0.06)), Color(0.75, 0.75, 0.7, 1))

func _draw_gpcoin() -> void:
	draw_circle(_p(0.5, 0.5), size.x * 0.34, Color(0.35, 0.65, 0.9, 1))
	draw_arc(_p(0.5, 0.5), size.x * 0.34, 0.0, TAU, 24, Color(0.15, 0.35, 0.55, 1), 2.0, true)
	draw_circle(_p(0.5, 0.5), size.x * 0.2, Color(0.55, 0.8, 1.0, 1))

func _draw_dogtag() -> void:
	# Two stacked military dog tags on a chain.
	draw_line(_p(0.5, 0.08), _p(0.5, 0.22), Color(0.6, 0.6, 0.62, 1), max(1.0, size.x * 0.03))
	var tag1 := PackedVector2Array([
		_p(0.32, 0.22), _p(0.68, 0.22), _p(0.68, 0.55),
		_p(0.5, 0.64), _p(0.32, 0.55)
	])
	draw_colored_polygon(tag1, icon_color)
	var tag2 := PackedVector2Array([
		_p(0.36, 0.40), _p(0.72, 0.40), _p(0.72, 0.73),
		_p(0.54, 0.82), _p(0.36, 0.73)
	])
	draw_colored_polygon(tag2, Color(icon_color.r, icon_color.g, icon_color.b, 0.75))
	draw_circle(_p(0.5, 0.27), size.x * 0.025, Color(0, 0, 0, 0.4))

func _draw_blueprint() -> void:
	# A rolled schematic - pale rectangle with corner-fold and grid lines,
	# reads clearly as "paperwork" rather than a physical item.
	var page := PackedVector2Array([_p(0.18, 0.12), _p(0.68, 0.12), _p(0.82, 0.26), _p(0.82, 0.88), _p(0.18, 0.88)])
	draw_colored_polygon(page, Color(0.22, 0.42, 0.55, 1))
	var fold := PackedVector2Array([_p(0.68, 0.12), _p(0.82, 0.26), _p(0.68, 0.26)])
	draw_colored_polygon(fold, Color(0.14, 0.28, 0.38, 1))
	for i in range(3):
		var y: float = 0.42 + float(i) * 0.14
		draw_line(_p(0.28, y), _p(0.72, y), Color(0.85, 0.92, 0.95, 0.7), max(1.0, size.y * 0.018))
	draw_circle(_p(0.30, 0.62), size.x * 0.03, Color(0.9, 0.4, 0.2, 0.9))

func _draw_boots() -> void:
	# A simple side-profile combat boot silhouette.
	var pts := PackedVector2Array([
		_p(0.35, 0.15), _p(0.62, 0.15), _p(0.62, 0.55), _p(0.85, 0.62),
		_p(0.85, 0.78), _p(0.20, 0.78), _p(0.20, 0.62), _p(0.35, 0.55)
	])
	draw_colored_polygon(pts, icon_color)
	draw_line(_p(0.35, 0.28), _p(0.62, 0.28), Color(1, 1, 1, 0.25), max(1.0, size.y * 0.02))
	draw_line(_p(0.35, 0.40), _p(0.62, 0.40), Color(1, 1, 1, 0.25), max(1.0, size.y * 0.02))
	draw_rect(Rect2(_p(0.20, 0.72), Vector2(size.x * 0.65, size.y * 0.06)), Color(0, 0, 0, 0.35))

func _draw_backpack() -> void:
	# A rounded backpack body with a front pocket and two shoulder straps.
	var body_pts := PackedVector2Array([
		_p(0.25, 0.2), _p(0.75, 0.2), _p(0.8, 0.35), _p(0.78, 0.85),
		_p(0.22, 0.85), _p(0.2, 0.35)
	])
	draw_colored_polygon(body_pts, icon_color)
	var pocket_pts := PackedVector2Array([_p(0.32, 0.5), _p(0.68, 0.5), _p(0.68, 0.75), _p(0.32, 0.75)])
	draw_colored_polygon(pocket_pts, Color(0, 0, 0, 0.25))
	draw_line(_p(0.35, 0.2), _p(0.3, 0.05), icon_color, max(1.0, size.x * 0.05))
	draw_line(_p(0.65, 0.2), _p(0.7, 0.05), icon_color, max(1.0, size.x * 0.05))

# A simpler rolled gauze bandage for Field Bandage - a deliberately
# smaller, plainer shape than the full medkit case below (_draw_medkit,
# now Trauma Kit only), since the two used to share one icon despite
# being different tiers of heal-type consumable.
func _draw_bandage() -> void:
	draw_circle(_p(0.42, 0.5), size.x * 0.22, Color(0.92, 0.9, 0.85, 1))
	draw_arc(_p(0.42, 0.5), size.x * 0.22, 0.0, TAU, 20, Color(0.75, 0.72, 0.65, 0.6), max(1.0, size.x * 0.015), true)
	draw_arc(_p(0.42, 0.5), size.x * 0.13, 0.0, TAU, 16, Color(0.75, 0.72, 0.65, 0.5), max(1.0, size.x * 0.012), true)
	var tail := PackedVector2Array([_p(0.58, 0.56), _p(0.86, 0.68), _p(0.84, 0.78), _p(0.56, 0.66)])
	draw_colored_polygon(tail, Color(0.88, 0.85, 0.78, 1))
	draw_rect(Rect2(_p(0.36, 0.44), Vector2(size.x * 0.04, size.y * 0.12)), Color(0.8, 0.15, 0.15, 1))
	draw_rect(Rect2(_p(0.32, 0.48), Vector2(size.x * 0.12, size.y * 0.04)), Color(0.8, 0.15, 0.15, 1))

func _draw_medkit() -> void:
	# White case with a red cross - classic medical icon.
	var case_pts := PackedVector2Array([_p(0.15, 0.28), _p(0.85, 0.28), _p(0.85, 0.78), _p(0.15, 0.78)])
	draw_colored_polygon(case_pts, Color(0.92, 0.92, 0.9, 1))
	draw_line(_p(0.15, 0.28), _p(0.85, 0.28), icon_color, max(1.0, size.y * 0.02))
	draw_line(_p(0.15, 0.78), _p(0.85, 0.78), icon_color, max(1.0, size.y * 0.02))
	draw_line(_p(0.15, 0.28), _p(0.15, 0.78), icon_color, max(1.0, size.x * 0.02))
	draw_line(_p(0.85, 0.28), _p(0.85, 0.78), icon_color, max(1.0, size.x * 0.02))
	var handle := PackedVector2Array([_p(0.38, 0.18), _p(0.62, 0.18), _p(0.62, 0.28), _p(0.38, 0.28)])
	draw_colored_polygon(handle, icon_color)
	var cross_v := PackedVector2Array([_p(0.44, 0.36), _p(0.56, 0.36), _p(0.56, 0.70), _p(0.44, 0.70)])
	draw_colored_polygon(cross_v, Color(0.8, 0.15, 0.15, 1))
	var cross_h := PackedVector2Array([_p(0.30, 0.46), _p(0.70, 0.46), _p(0.70, 0.58), _p(0.30, 0.58)])
	draw_colored_polygon(cross_h, Color(0.8, 0.15, 0.15, 1))

# An open ammo crate with a row of cartridges - tier diverges sharply on
# BOTH count and height (light=4 short thin rounds, medium=3 mid rounds,
# heavy=1 single tall fat round) so the three ammo types read as
# distinct silhouettes at a glance, even at small Stash-grid sizes,
# rather than needing the border/rarity color to tell them apart.
func _draw_ammo_box(tier: int) -> void:
	var crate := PackedVector2Array([_p(0.18, 0.55), _p(0.82, 0.55), _p(0.78, 0.82), _p(0.22, 0.82)])
	draw_colored_polygon(crate, Color(icon_color.r * 0.55, icon_color.g * 0.55, icon_color.b * 0.55, 1))
	draw_line(_p(0.18, 0.55), _p(0.82, 0.55), Color(0, 0, 0, 0.4), max(1.0, size.y * 0.02))
	var count: int = 1 if tier == 3 else (3 if tier == 2 else 4)
	var cart_w: float = 0.26 if tier == 3 else (0.12 if tier == 2 else 0.075)
	var cart_top: float = 0.08 if tier == 3 else (0.16 if tier == 2 else 0.24)
	var start_x: float = 0.5 - (float(count) * cart_w) / 2.0
	for i in range(count):
		var cx: float = start_x + float(i) * cart_w + cart_w / 2.0
		var body := PackedVector2Array([
			_p(cx - cart_w * 0.32, 0.5), _p(cx + cart_w * 0.32, 0.5),
			_p(cx + cart_w * 0.32, cart_top), _p(cx - cart_w * 0.32, cart_top),
		])
		draw_colored_polygon(body, icon_color)
		var tip := PackedVector2Array([
			_p(cx - cart_w * 0.32, cart_top), _p(cx + cart_w * 0.32, cart_top), _p(cx, cart_top - 0.1),
		])
		draw_colored_polygon(tip, Color(0.75, 0.6, 0.35, 1))

func _draw_grenade() -> void:
	# Round body with a ribbed pattern, a top cap, and a safety lever/pin.
	draw_circle(_p(0.5, 0.58), size.x * 0.28, icon_color)
	draw_line(_p(0.24, 0.50), _p(0.76, 0.50), Color(0, 0, 0, 0.35), max(1.0, size.y * 0.02))
	draw_line(_p(0.24, 0.66), _p(0.76, 0.66), Color(0, 0, 0, 0.35), max(1.0, size.y * 0.02))
	var cap := PackedVector2Array([_p(0.42, 0.22), _p(0.58, 0.22), _p(0.58, 0.34), _p(0.42, 0.34)])
	draw_colored_polygon(cap, icon_color)
	var lever := PackedVector2Array([_p(0.58, 0.20), _p(0.78, 0.14), _p(0.80, 0.22), _p(0.60, 0.30)])
	draw_colored_polygon(lever, Color(0.75, 0.65, 0.15, 1))
	draw_circle(_p(0.78, 0.18), size.x * 0.04, Color(0.85, 0.85, 0.85, 1))

func _draw_smoke_grenade() -> void:
	draw_circle(_p(0.5, 0.58), size.x * 0.28, Color(0.55, 0.55, 0.5, 1))
	draw_line(_p(0.24, 0.50), _p(0.76, 0.50), Color(0, 0, 0, 0.3), max(1.0, size.y * 0.02))
	var cap := PackedVector2Array([_p(0.42, 0.22), _p(0.58, 0.22), _p(0.58, 0.34), _p(0.42, 0.34)])
	draw_colored_polygon(cap, Color(0.55, 0.55, 0.5, 1))
	draw_circle(_p(0.68, 0.24), size.x * 0.07, Color(0.85, 0.85, 0.82, 0.6))
	draw_circle(_p(0.74, 0.16), size.x * 0.05, Color(0.85, 0.85, 0.82, 0.5))

func _draw_stun_grenade() -> void:
	draw_circle(_p(0.5, 0.58), size.x * 0.28, Color(0.78, 0.78, 0.2, 1))
	draw_line(_p(0.24, 0.50), _p(0.76, 0.50), Color(0, 0, 0, 0.3), max(1.0, size.y * 0.02))
	var cap := PackedVector2Array([_p(0.42, 0.22), _p(0.58, 0.22), _p(0.58, 0.34), _p(0.42, 0.34)])
	draw_colored_polygon(cap, Color(0.78, 0.78, 0.2, 1))
	for i in range(4):
		var ang: float = float(i) * PI / 2.0
		draw_line(_p(0.5, 0.58), _p(0.5 + cos(ang) * 0.1, 0.58 + sin(ang) * 0.1), Color(1, 1, 0.85, 0.9), max(1.0, size.x * 0.025))

func _draw_molotov() -> void:
	# A glass bottle silhouette with a lit rag on top and a flame flicker.
	var bottle := PackedVector2Array([_p(0.4, 0.4), _p(0.6, 0.4), _p(0.66, 0.62), _p(0.5, 0.78), _p(0.34, 0.62)])
	draw_colored_polygon(bottle, Color(0.3, 0.45, 0.25, 0.85))
	draw_rect(Rect2(_p(0.44, 0.26), Vector2(size.x * 0.12, size.y * 0.16)), Color(0.75, 0.65, 0.4, 1))
	var flame := PackedVector2Array([_p(0.5, 0.1), _p(0.58, 0.2), _p(0.5, 0.28), _p(0.42, 0.2)])
	draw_colored_polygon(flame, Color(0.95, 0.55, 0.15, 1))
	draw_circle(_p(0.5, 0.19), size.x * 0.03, Color(1.0, 0.85, 0.3, 1))

func _draw_flare() -> void:
	# A handheld flare tube with a bright burst of light at the top.
	var tube := PackedVector2Array([_p(0.42, 0.45), _p(0.58, 0.45), _p(0.58, 0.85), _p(0.42, 0.85)])
	draw_colored_polygon(tube, icon_color)
	draw_line(_p(0.42, 0.60), _p(0.58, 0.60), Color(1, 1, 1, 0.3), max(1.0, size.y * 0.015))
	var star_color := Color(1, 0.55, 0.15, 1)
	for i in range(8):
		var ang := TAU * float(i) / 8.0
		var inner := _p(0.5, 0.32) + Vector2(cos(ang), sin(ang)) * size.x * 0.05
		var outer := _p(0.5, 0.32) + Vector2(cos(ang), sin(ang)) * size.x * 0.20
		draw_line(inner, outer, star_color, max(1.0, size.x * 0.025))
	draw_circle(_p(0.5, 0.32), size.x * 0.08, Color(1, 0.85, 0.4, 1))

func _draw_rifle() -> void:
	# Longer barrel + stock than the pistol, for a "bigger gun" silhouette.
	var pts := PackedVector2Array([
		_p(0.02, 0.42), _p(0.95, 0.42), _p(0.95, 0.50), _p(0.70, 0.50),
		_p(0.70, 0.58), _p(0.55, 0.58), _p(0.55, 0.50), _p(0.30, 0.50),
		_p(0.30, 0.60), _p(0.22, 0.80), _p(0.12, 0.80), _p(0.16, 0.58),
		_p(0.02, 0.50)
	])
	draw_colored_polygon(pts, icon_color)
	var stock := PackedVector2Array([_p(0.80, 0.42), _p(0.95, 0.38), _p(0.95, 0.42)])
	draw_colored_polygon(stock, icon_color)
	draw_line(_p(0.04, 0.43), _p(0.93, 0.43), icon_color.lightened(0.4), max(1.0, size.y * 0.02))
	draw_rect(Rect2(_p(0.32, 0.51), Vector2(size.x * 0.06, size.y * 0.07)), icon_color.darkened(0.35))

func _draw_shotgun() -> void:
	# Short, thick double barrel with a pump grip underneath - reads as
	# distinctly stubbier and heavier than the rifle silhouette.
	var barrel := PackedVector2Array([
		_p(0.06, 0.38), _p(0.9, 0.38), _p(0.9, 0.48), _p(0.06, 0.48),
	])
	draw_colored_polygon(barrel, icon_color)
	var barrel2 := PackedVector2Array([
		_p(0.06, 0.5), _p(0.78, 0.5), _p(0.78, 0.58), _p(0.06, 0.58),
	])
	draw_colored_polygon(barrel2, icon_color)
	var pump := PackedVector2Array([
		_p(0.3, 0.58), _p(0.52, 0.58), _p(0.52, 0.66), _p(0.3, 0.66),
	])
	draw_colored_polygon(pump, icon_color)
	var stock := PackedVector2Array([_p(0.78, 0.4), _p(0.94, 0.34), _p(0.94, 0.5), _p(0.78, 0.48)])
	draw_colored_polygon(stock, icon_color)
	var grip := PackedVector2Array([_p(0.14, 0.58), _p(0.22, 0.58), _p(0.18, 0.82), _p(0.1, 0.82)])
	draw_colored_polygon(grip, icon_color)
	draw_line(_p(0.08, 0.385), _p(0.88, 0.385), icon_color.lightened(0.4), max(1.0, size.y * 0.02))
	draw_line(_p(0.08, 0.505), _p(0.76, 0.505), icon_color.lightened(0.25), max(1.0, size.y * 0.015))

func _draw_flamethrower() -> void:
	# A bulky tank on the back with a short wide nozzle and a flame jet.
	var tank := PackedVector2Array([_p(0.08, 0.3), _p(0.32, 0.3), _p(0.32, 0.62), _p(0.08, 0.62)])
	draw_colored_polygon(tank, icon_color)
	draw_rect(Rect2(_p(0.1, 0.32), Vector2(size.x * 0.03, size.y * 0.28)), icon_color.lightened(0.4))
	var nozzle := PackedVector2Array([_p(0.32, 0.44), _p(0.68, 0.4), _p(0.68, 0.52), _p(0.32, 0.5)])
	draw_colored_polygon(nozzle, icon_color.darkened(0.15))
	var flame := PackedVector2Array([
		_p(0.68, 0.34), _p(0.82, 0.4), _p(0.95, 0.32), _p(0.9, 0.46),
		_p(0.98, 0.5), _p(0.82, 0.52), _p(0.7, 0.6),
	])
	draw_colored_polygon(flame, Color(0.95, 0.5, 0.1, 0.95))
	draw_colored_polygon(PackedVector2Array([_p(0.72, 0.42), _p(0.85, 0.44), _p(0.78, 0.5)]), Color(1.0, 0.85, 0.3, 1))

func _draw_thorn() -> void:
	# A gnarled, vine-like weapon silhouette with small thorn spurs and a
	# sickly green glow, hinting at the poison it deals.
	var body := PackedVector2Array([
		_p(0.05, 0.5), _p(0.4, 0.44), _p(0.55, 0.5), _p(0.85, 0.42),
		_p(0.85, 0.5), _p(0.55, 0.58), _p(0.4, 0.54), _p(0.05, 0.58),
	])
	draw_colored_polygon(body, icon_color)
	draw_line(_p(0.08, 0.485), _p(0.82, 0.455), icon_color.lightened(0.3), max(1.0, size.y * 0.015))
	for i in range(4):
		var bx: float = 0.15 + float(i) * 0.16
		var spur := PackedVector2Array([_p(bx, 0.44), _p(bx + 0.03, 0.34), _p(bx + 0.06, 0.44)])
		draw_colored_polygon(spur, Color(0.35, 0.75, 0.2, 1))
	draw_circle(_p(0.85, 0.46), size.x * 0.035, Color(0.55, 0.95, 0.35, 0.9))

func _draw_railgun() -> void:
	# A long, sleek rail-barrel with energy coils along its length.
	var body := PackedVector2Array([_p(0.05, 0.44), _p(0.9, 0.42), _p(0.9, 0.5), _p(0.05, 0.52)])
	draw_colored_polygon(body, icon_color)
	draw_line(_p(0.06, 0.445), _p(0.88, 0.425), icon_color.lightened(0.4), max(1.0, size.y * 0.015))
	for cx in [0.25, 0.45, 0.65]:
		draw_rect(Rect2(_p(cx, 0.38), Vector2(size.x * 0.04, size.y * 0.18)), Color(1.0, 0.9, 0.3, 0.9))
	var tip := PackedVector2Array([_p(0.88, 0.4), _p(0.98, 0.46), _p(0.88, 0.52)])
	draw_colored_polygon(tip, Color(1.0, 0.95, 0.5, 1))
	var stock := PackedVector2Array([_p(0.05, 0.44), _p(0.05, 0.52), _p(-0.03, 0.5), _p(-0.03, 0.46)])
	draw_colored_polygon(stock, icon_color.darkened(0.2))

func _draw_alpha_cannon() -> void:
	# An ornate, prismatic weapon unlike anything else in the game -
	# gold body, a faceted crystal core, and a small halo ring around
	# the barrel tip, meant to read as "there is exactly one of these
	# and you're holding it" at a glance.
	var body := PackedVector2Array([_p(0.05, 0.42), _p(0.82, 0.38), _p(0.86, 0.46), _p(0.82, 0.54), _p(0.05, 0.5)])
	draw_colored_polygon(body, Color(0.85, 0.7, 0.25, 1))
	draw_line(_p(0.06, 0.43), _p(0.8, 0.4), Color(1.0, 0.92, 0.6, 0.9), max(1.0, size.y * 0.014))
	# Faceted crystal core, mid-barrel.
	var core := PackedVector2Array([_p(0.42, 0.3), _p(0.5, 0.38), _p(0.42, 0.5), _p(0.34, 0.38)])
	draw_colored_polygon(core, Color(0.95, 0.5, 0.85, 0.9))
	draw_colored_polygon(PackedVector2Array([_p(0.42, 0.3), _p(0.46, 0.38), _p(0.42, 0.46)]), Color(1.0, 0.85, 0.95, 0.7))
	# Halo ring at the tip.
	draw_arc(_p(0.86, 0.46), size.x * 0.09, 0.0, TAU, 16, Color(1.0, 0.85, 0.4, 0.9), max(1.0, size.x * 0.02), true)
	draw_circle(_p(0.86, 0.46), size.x * 0.035, Color(1.0, 0.95, 0.7, 1))
	var stock := PackedVector2Array([_p(0.05, 0.42), _p(0.05, 0.5), _p(-0.04, 0.48), _p(-0.04, 0.44)])
	draw_colored_polygon(stock, Color(0.6, 0.48, 0.15, 1))

func _draw_pet_dog() -> void:
	# Body with a soft belly-shade underneath for depth.
	var body := PackedVector2Array([_p(0.15, 0.55), _p(0.7, 0.55), _p(0.7, 0.7), _p(0.15, 0.7)])
	draw_colored_polygon(body, icon_color)
	draw_colored_polygon(PackedVector2Array([_p(0.15, 0.63), _p(0.7, 0.63), _p(0.7, 0.7), _p(0.15, 0.7)]), icon_color.darkened(0.18))
	var head := PackedVector2Array([_p(0.62, 0.35), _p(0.85, 0.4), _p(0.85, 0.6), _p(0.62, 0.6)])
	draw_colored_polygon(head, icon_color)
	var snout := PackedVector2Array([_p(0.8, 0.46), _p(0.92, 0.48), _p(0.92, 0.56), _p(0.8, 0.56)])
	draw_colored_polygon(snout, icon_color.lightened(0.12))
	draw_circle(_p(0.9, 0.51), size.x * 0.018, Color(0.05, 0.05, 0.05, 1))
	var ear := PackedVector2Array([_p(0.65, 0.32), _p(0.72, 0.2), _p(0.76, 0.36)])
	draw_colored_polygon(ear, icon_color.darkened(0.25))
	for lx in [0.2, 0.35, 0.5, 0.62]:
		draw_rect(Rect2(_p(lx, 0.68), Vector2(size.x * 0.05, size.y * 0.14)), icon_color.darkened(0.3))
	draw_circle(_p(0.8, 0.44), size.x * 0.025, Color(0.05, 0.05, 0.05, 1))
	draw_circle(_p(0.79, 0.43), size.x * 0.008, Color(1, 1, 1, 0.7))
	var tail := PackedVector2Array([_p(0.15, 0.58), _p(0.04, 0.48), _p(0.08, 0.44), _p(0.18, 0.53)])
	draw_colored_polygon(tail, icon_color.darkened(0.08))

func _draw_pet_cat() -> void:
	var body := PackedVector2Array([_p(0.2, 0.5), _p(0.62, 0.5), _p(0.62, 0.68), _p(0.2, 0.68)])
	draw_colored_polygon(body, icon_color)
	draw_colored_polygon(PackedVector2Array([_p(0.2, 0.6), _p(0.62, 0.6), _p(0.62, 0.68), _p(0.2, 0.68)]), icon_color.darkened(0.18))
	var head := PackedVector2Array([_p(0.55, 0.3), _p(0.8, 0.32), _p(0.8, 0.55), _p(0.55, 0.55)])
	draw_colored_polygon(head, icon_color)
	var ear1 := PackedVector2Array([_p(0.58, 0.3), _p(0.6, 0.18), _p(0.68, 0.3)])
	var ear2 := PackedVector2Array([_p(0.7, 0.3), _p(0.76, 0.16), _p(0.8, 0.3)])
	draw_colored_polygon(ear1, icon_color)
	draw_colored_polygon(ear2, icon_color)
	draw_colored_polygon(PackedVector2Array([_p(0.605, 0.28), _p(0.615, 0.22), _p(0.655, 0.28)]), Color(icon_color.r * 0.7, icon_color.g * 0.55, icon_color.g * 0.55, 1))
	var tail := PackedVector2Array([_p(0.2, 0.55), _p(0.06, 0.38), _p(0.11, 0.34), _p(0.25, 0.5)])
	draw_colored_polygon(tail, icon_color.lightened(0.05))
	draw_circle(_p(0.76, 0.42), size.x * 0.02, Color(0.05, 0.05, 0.05, 1))
	draw_circle(_p(0.755, 0.415), size.x * 0.007, Color(1, 1, 1, 0.7))
	# Whiskers - a small detail that reads clearly even at icon size.
	draw_line(_p(0.78, 0.46), _p(0.9, 0.44), Color(1, 1, 1, 0.4), 1.0)
	draw_line(_p(0.78, 0.49), _p(0.9, 0.5), Color(1, 1, 1, 0.4), 1.0)

func _draw_pet_drone() -> void:
	# Central hull with a subtle metallic highlight, four rotor arms.
	draw_circle(_p(0.5, 0.5), size.x * 0.17, icon_color.darkened(0.1))
	draw_circle(_p(0.47, 0.47), size.x * 0.15, icon_color)
	for ang in [0.0, PI * 0.5, PI, PI * 1.5]:
		var arm_end := _p(0.5, 0.5) + Vector2(cos(ang), sin(ang)) * size.x * 0.32
		draw_line(_p(0.5, 0.5), arm_end, icon_color.darkened(0.15), max(1.2, size.x * 0.035))
		draw_circle(arm_end, size.x * 0.07, icon_color.darkened(0.05))
		draw_circle(arm_end, size.x * 0.045, Color(0.35, 0.7, 0.95, 0.85))
	draw_circle(_p(0.5, 0.5), size.x * 0.06, Color(0.3, 0.9, 1.0, 1))
	draw_circle(_p(0.46, 0.46), size.x * 0.02, Color(1, 1, 1, 0.6))

func _draw_pet_crow() -> void:
	var body := PackedVector2Array([_p(0.35, 0.35), _p(0.65, 0.4), _p(0.6, 0.65), _p(0.4, 0.65)])
	draw_colored_polygon(body, icon_color)
	draw_colored_polygon(PackedVector2Array([_p(0.4, 0.52), _p(0.6, 0.52), _p(0.6, 0.65), _p(0.4, 0.65)]), icon_color.darkened(0.25))
	var wing := PackedVector2Array([_p(0.35, 0.42), _p(0.1, 0.33), _p(0.16, 0.5), _p(0.2, 0.48), _p(0.22, 0.57), _p(0.38, 0.55)])
	draw_colored_polygon(wing, icon_color.lightened(0.15))
	var wing_shade := PackedVector2Array([_p(0.16, 0.5), _p(0.2, 0.48), _p(0.22, 0.57), _p(0.2, 0.56)])
	draw_colored_polygon(wing_shade, icon_color.darkened(0.1))
	var beak := PackedVector2Array([_p(0.62, 0.42), _p(0.8, 0.44), _p(0.62, 0.5)])
	draw_colored_polygon(beak, Color(0.85, 0.65, 0.2, 1))
	draw_circle(_p(0.58, 0.4), size.x * 0.022, Color(0.9, 0.85, 0.3, 1))
	draw_circle(_p(0.575, 0.395), size.x * 0.008, Color(0.1, 0.1, 0.1, 1))
	var tail := PackedVector2Array([_p(0.4, 0.63), _p(0.32, 0.76), _p(0.4, 0.72), _p(0.46, 0.65)])
	draw_colored_polygon(tail, icon_color.darkened(0.05))
