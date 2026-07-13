extends Area2D

# Gauntlet loot works differently from a normal raid - no searching,
# just walk up and it's yours. Colorful, chunky, and immediately
# obvious what rarity it is from a distance. Sits exactly where it
# dropped - no floating/bobbing, so a cluster of drops stays readable
# instead of drifting around the screen.

var item: Dictionary = {}
var collected: bool = false
var sparkle_phase: float = 0.0
var is_high_rarity: bool = false

@onready var gem: Polygon2D = $Gem
@onready var glow: Polygon2D = $Glow
@onready var weapon_type_tag: Label = $WeaponTypeTag

const HIGH_RARITIES := ["legendary", "mythic", "exotic", "multiversal"]

func setup(p_item: Dictionary) -> void:
	item = p_item
	var rarity: String = item.get("rarity", "common")
	var rarity_color := GameManager.get_rarity_color(rarity)
	gem.color = rarity_color
	glow.color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.35)
	is_high_rarity = HIGH_RARITIES.has(rarity)
	sparkle_phase = randf_range(0.0, TAU)
	# Weapon drops get a distinct MELEE WEAPON / PROJECTILE WEAPON tag
	# right on the drop itself, so it's clear before you even pick it
	# up whether equipping it makes left-click swing or shoot.
	var weapon_label: String = GameManager.get_gauntlet_weapon_type_label(item)
	if weapon_label != "":
		weapon_type_tag.visible = true
		weapon_type_tag.text = weapon_label
		weapon_type_tag.add_theme_color_override("font_color", Color(1.0, 0.6, 0.4, 1) if GameManager.is_gauntlet_item_melee(item) else Color(0.5, 0.85, 1.0, 1))
	# A quick settle-in pop on spawn only, then it stays put.
	scale = Vector2(0.3, 0.3)
	var pop_tw := create_tween()
	pop_tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _ready() -> void:
	body_entered.connect(_on_entered)

func _process(delta: float) -> void:
	if collected:
		return
	# Higher rarities get a gentle glow pulse to stand out - no
	# movement, just a brightness shimmer, so they're still readable
	# from a distance without drifting position.
	if is_high_rarity:
		sparkle_phase += delta * 3.0
		var pulse: float = 0.75 + 0.25 * sin(sparkle_phase)
		glow.modulate.a = pulse

func _on_entered(body: Node) -> void:
	if collected or not body.is_in_group("gauntlet_player"):
		return
	collected = true
	GameManager.add_loot(item.duplicate(true))
	Sfx.play_loot_pickup()
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.5, 1.5), 0.2)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	await tw.finished
	queue_free()
