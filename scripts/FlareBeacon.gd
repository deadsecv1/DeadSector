extends Node2D

# A pulsing flare/beacon marker with real light emission (works with the
# world-darkness/flashlight system) - marks the extraction zone visually
# from a distance even without the player's flashlight pointed at it.

@export var flare_color: Color = Color(0.15, 0.95, 0.35, 1)

var time: float = 0.0

@onready var light: PointLight2D = $PointLight2D
@onready var glow: Polygon2D = $Glow

func _ready() -> void:
	light.texture = _make_glow_texture()
	light.texture_scale = 5.0
	light.color = flare_color
	light.energy = 1.6
	light.blend_mode = Light2D.BLEND_MODE_ADD
	glow.color = flare_color

func _process(delta: float) -> void:
	time += delta
	var pulse: float = 0.75 + 0.25 * sin(time * 3.0)
	glow.scale = Vector2.ONE * pulse
	light.energy = 1.3 + 0.5 * pulse

func _make_glow_texture() -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	for y in range(size):
		for x in range(size):
			var d: float = Vector2(x, y).distance_to(center) / (size / 2.0)
			var a: float = clamp(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)
