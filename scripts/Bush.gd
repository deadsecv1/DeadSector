extends Area2D

# Walkable cover. While the player is inside, enemies detect them from much
# closer range (see Enemy.gd's effective_range calculation). Also sways
# gently and independently so the map doesn't feel static.

var sway_phase: float = 0.0
var sway_speed: float = 0.0

const VARIANT_COUNT := 4
# bush_1/bush_3 are the round, narrow variant (~15x13 source) and need a
# bigger scale to match bush_2/bush_4's wider clump (~28x13 source) at a
# similar on-screen footprint - one flat multiplier made the round ones
# look like an afterthought next to the wide ones.
const VARIANT_SCALE := {1: 3.4, 2: 1.9, 3: 3.4, 4: 1.9}

func _ready() -> void:
	add_to_group("bushes")
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)
	sway_phase = randf() * TAU
	sway_speed = randf_range(0.6, 1.1)
	_try_load_external_sprite()

# --- Optional external art: picks a random weathered variant
# (res://assets/props/bush_<1-4>.png) for visual variety across the many
# bushes scattered around the maps, same convention as Barrel.gd/Crate.gd.
# Falls back to the procedural blobs if none of the 4 files exist.
func _try_load_external_sprite() -> void:
	var variant := randi() % VARIANT_COUNT + 1
	var path := "res://assets/props/bush_%d.png" % variant
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	if tex == null:
		return
	for n in ["Blob1", "Blob2", "Blob3", "Blob4"]:
		var node = get_node_or_null(n)
		if node:
			node.visible = false
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * VARIANT_SCALE.get(variant, 2.5)
	add_child(sprite)

func _process(delta: float) -> void:
	sway_phase += delta * sway_speed
	rotation = sin(sway_phase) * 0.05

func _on_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("set_in_bush"):
		body.set_in_bush(true)

func _on_exited(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("set_in_bush"):
		body.set_in_bush(false)
