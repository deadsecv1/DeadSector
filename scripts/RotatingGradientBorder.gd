extends Control

# A gradient background whose fill direction continuously rotates around
# the center - used for Alpha/Tech-Test exclusive items specifically, so
# they read as genuinely animated/different from every other rarity's
# static gradient. Same correct anchoring as GameManager.
# make_gradient_border() (expand_mode + a full-rect preset set after the
# texture is assigned) so it actually fills whatever box it's given
# instead of rendering at the texture's raw pixel size.

@export var gradient_colors: Array = [Color(1, 1, 1, 1), Color(0.05, 0.05, 0.05, 1)]
@export var rotate_speed: float = 0.6

var _rect: TextureRect
var _tex: GradientTexture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	for i in range(gradient_colors.size()):
		grad.add_point(float(i) / float(max(1, gradient_colors.size() - 1)), gradient_colors[i])
	_tex = GradientTexture2D.new()
	_tex.gradient = grad
	_tex.fill = GradientTexture2D.FILL_LINEAR
	_tex.width = 128
	_tex.height = 128
	_rect = TextureRect.new()
	_rect.texture = _tex
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.clip_contents = true
	add_child(_rect)
	set_process(true)

func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var angle := t * rotate_speed
	_tex.fill_from = Vector2(0.5, 0.5) + Vector2(cos(angle), sin(angle)) * 0.5
	_tex.fill_to = Vector2(0.5, 0.5) - Vector2(cos(angle), sin(angle)) * 0.5
