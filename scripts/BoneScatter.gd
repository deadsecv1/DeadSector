extends Node2D

# Scatters ground decoration across the whole map: bone piles, rocks,
# dead trees, gravestones, and a few rare skull piles. Deterministic
# seeds per category so it looks the same every raid. Falls back to a
# purely procedural bone scatter (no art) if the external decoration
# set isn't present, same convention as the other props.

@export var area_size: Vector2 = Vector2(3800, 2600)
@export var bone_count: int = 160
@export var rock_count: int = 22
@export var dead_tree_count: int = 10
@export var grave_count: int = 8
@export var skull_pile_count: int = 3

const DECOR_DIR := "res://assets/props/boneclock/"

const BONE_FILES := ["bones_shadow1_1.png", "bones_shadow1_4.png", "bones_shadow1_7.png", "bones_shadow1_10.png", "bones_shadow1_13.png", "bones_shadow1_16.png", "bones_shadow2_2.png", "bones_shadow2_8.png", "bones_shadow3_3.png", "bones_shadow3_9.png"]
const ROCK_FILES := ["rock_shadow1_1.png", "rock_shadow1_3.png", "rock_shadow1_5.png", "rock_shadow2_2.png", "rock_shadow2_4.png"]
const DEAD_TREE_FILES := ["dead_tree_shadow1_1.png", "dead_tree_shadow1_2.png", "dead_tree_shadow1_3.png", "dead_tree_shadow3_1.png", "dead_tree_shadow3_2.png", "dead_tree_shadow3_3.png"]
const GRAVE_FILES := ["grave_shadow1_1.png", "grave_shadow1_5.png", "grave_shadow1_9.png", "grave_shadow1_13.png", "grave_shadow1_17.png", "grave_shadow2_3.png", "grave_shadow2_11.png"]
const SKULL_PILE_FILES := ["pile_sculls_shadow1.png", "pile_sculls_shadow2.png", "pile_sculls_shadow3.png"]

var _bone_textures: Array[Texture2D] = []
var _rock_textures: Array[Texture2D] = []
var _dead_tree_textures: Array[Texture2D] = []
var _grave_textures: Array[Texture2D] = []
var _skull_pile_textures: Array[Texture2D] = []
var _use_external_art: bool = false

func _ready() -> void:
	z_index = -1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_use_external_art = _load_textures()
	queue_redraw()

func _load_textures() -> bool:
	if not ResourceLoader.exists(DECOR_DIR + BONE_FILES[0]):
		return false
	for f in BONE_FILES:
		_bone_textures.append(load(DECOR_DIR + f))
	for f in ROCK_FILES:
		_rock_textures.append(load(DECOR_DIR + f))
	for f in DEAD_TREE_FILES:
		_dead_tree_textures.append(load(DECOR_DIR + f))
	for f in GRAVE_FILES:
		_grave_textures.append(load(DECOR_DIR + f))
	for f in SKULL_PILE_FILES:
		_skull_pile_textures.append(load(DECOR_DIR + f))
	return true

func _draw() -> void:
	var half := area_size / 2.0
	if not _use_external_art:
		_draw_vector_bones(half)
		return
	# target_size is the desired on-screen width in pixels - each texture
	# is scaled individually to hit it since the source variants range
	# from 16x16 to 128x128 and would otherwise render wildly inconsistent
	# sizes next to each other.
	_scatter_textures(_bone_textures, bone_count, 555, half, 26.0, true)
	_scatter_textures(_rock_textures, rock_count, 556, half, 34.0, true)
	_scatter_textures(_dead_tree_textures, dead_tree_count, 557, half, 110.0, false)
	_scatter_textures(_grave_textures, grave_count, 558, half, 30.0, false)
	_scatter_textures(_skull_pile_textures, skull_pile_count, 559, half, 95.0, false)

func _scatter_textures(textures: Array[Texture2D], count: int, seed_value: int, half: Vector2, target_size: float, allow_rotation: bool) -> void:
	if textures.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(count):
		var x := rng.randf_range(-half.x, half.x)
		var y := rng.randf_range(-half.y, half.y)
		var rot := rng.randf_range(0.0, TAU) if allow_rotation else rng.randf_range(-0.06, 0.06)
		var variance := rng.randf_range(0.85, 1.2)
		var tex: Texture2D = textures[rng.randi() % textures.size()]
		var scale_f: float = (target_size / tex.get_size().x) * variance
		draw_set_transform(Vector2(x, y), rot, Vector2(scale_f, scale_f))
		draw_texture(tex, -tex.get_size() / 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_vector_bones(half: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 555
	for i in range(bone_count):
		var x := rng.randf_range(-half.x, half.x)
		var y := rng.randf_range(-half.y, half.y)
		var rot := rng.randf_range(0.0, TAU)
		var scale_f := rng.randf_range(0.7, 1.3)
		_draw_bone(Vector2(x, y), rot, scale_f)

func _draw_bone(pos: Vector2, rot: float, s: float) -> void:
	var dir := Vector2(cos(rot), sin(rot))
	var a := pos - dir * 9.0 * s
	var b := pos + dir * 9.0 * s
	var bone_color := Color(0.82, 0.79, 0.7, 0.6)
	draw_line(a, b, bone_color, 3.0 * s)
	draw_circle(a, 3.2 * s, bone_color)
	draw_circle(b, 3.2 * s, bone_color)
