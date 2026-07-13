extends PointLight2D

# A cone-shaped "flashlight" light that follows the player's aim direction.
# The cone texture is generated procedurally at startup (no image files
# needed) - a radial+angular falloff baked into an Image/ImageTexture.
# Pairs with a CanvasModulate in the level to create fog-of-war: everything
# outside the cone stays dim, everything inside gets lit up.

@export var cone_angle_deg: float = 34.0
@export var light_range: float = 460.0
@export var texture_size: int = 128

func _ready() -> void:
	texture = _make_cone_texture()
	texture_scale = (light_range * 2.0) / float(texture_size)
	energy = 1.5
	color = Color(1.0, 0.96, 0.86, 1)
	blend_mode = Light2D.BLEND_MODE_ADD

# Called by Player.gd when the Vision Range Skill Tree upgrade changes the
# effective range - just rescales the existing cone texture, no need to
# regenerate the image.
func set_range(new_range: float) -> void:
	light_range = new_range
	texture_scale = (light_range * 2.0) / float(texture_size)

func _make_cone_texture() -> ImageTexture:
	var img := Image.create(texture_size, texture_size, false, Image.FORMAT_RGBA8)
	var center := Vector2(texture_size / 2.0, texture_size / 2.0)
	var half_angle := deg_to_rad(cone_angle_deg)
	var max_r := texture_size / 2.0
	for y in range(texture_size):
		for x in range(texture_size):
			var p := Vector2(x, y) - center
			var dist := p.length()
			if dist > max_r:
				continue
			var angle: float = abs(p.angle())
			if angle > half_angle:
				continue
			var dist_falloff: float = clamp(1.0 - dist / max_r, 0.0, 1.0)
			var angle_falloff: float = clamp(1.0 - angle / half_angle, 0.0, 1.0)
			var a: float = dist_falloff * sqrt(angle_falloff)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
