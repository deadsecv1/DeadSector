extends Control

# Ambient menu vignette: Rose in her Hideout alcove, fidgeting at a shelf
# of plushies while a couple of plushie pets amble around near her,
# idly drifting toward the cursor (see WanderingPlushie.gd's
# follow_cursor) - reuses the real Rose sprite and the WanderingPlushie
# scene (see scenes/WanderingPlushie.tscn and scenes/Hideout.tscn)
# instead of redrawing them from scratch, so this matches exactly what's
# already in the Hideout. Only the shelf/room backdrop below is drawn
# procedurally, same technique as the other vignettes (see
# ExtractionChopperVignette.gd).

const ROSE_TEXTURE := preload("res://assets/npcs/rose.png")
const PLUSHIE_SCENE := preload("res://scenes/WanderingPlushie.tscn")
const PLUSHIE_COLORS := [Color(0.85, 0.55, 0.65, 1), Color(0.55, 0.7, 0.9, 1), Color(0.95, 0.8, 0.4, 1)]

var time: float = 0.0
var rose_sprite: Sprite2D
var rose_base_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Clips anything drawn by this vignette (Rose, the plushies) to its
	# own rect - a hard guarantee nothing here can ever render over the
	# main menu buttons, on top of whatever position bug caused that.
	clip_contents = true
	rose_sprite = Sprite2D.new()
	rose_sprite.texture = ROSE_TEXTURE
	rose_sprite.scale = Vector2(2.6, 2.6)
	add_child(rose_sprite)
	await get_tree().process_frame
	_layout()
	set_process(true)

# Plushies are instantiated (and positioned) here, AFTER size is known,
# instead of in _ready() before this vignette even had a real size -
# WanderingPlushie captures its own wander anchor from global_position
# the instant it enters the tree, so adding it to the tree before it
# had a real position meant its anchor locked onto the wrong spot
# entirely (near the vignette's top-left corner). It would then spend
# forever walking toward that stale anchor across the whole screen -
# which is what actually caused it to wander off past the edges and
# through the main menu buttons instead of staying near the shelf.
func _layout() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	rose_base_pos = Vector2(w * 0.64, h * 0.7)
	rose_sprite.position = rose_base_pos
	for i in range(PLUSHIE_COLORS.size()):
		var p = PLUSHIE_SCENE.instantiate()
		p.body_color = PLUSHIE_COLORS[i]
		# Slower and smaller-radius than the Hideout default, and each
		# starts on its own short delay so they don't all set off the
		# instant the vignette appears - reads as idly milling around
		# the shelf rather than briskly patrolling it.
		p.speed = 14.0
		p.wander_radius = 36.0
		p.start_delay = float(i) * 1.3
		p.follow_cursor = true
		p.follow_lag = 2.0 + float(i) * 0.5
		p.position = Vector2(w * 0.64 + float(i - 1) * 55.0, h * 0.9)
		add_child(p)

func _process(delta: float) -> void:
	time += delta
	if rose_sprite != null and rose_base_pos != Vector2.ZERO:
		# A small idle fidget - a gentle rocking tilt and bob, as if
		# she's reaching to straighten something on the shelf.
		rose_sprite.rotation = sin(time * 1.1) * 0.035
		rose_sprite.position = rose_base_pos + Vector2(0, sin(time * 1.1) * -2.0)
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return

	# Warm dim room backdrop - a cozy lit corner rather than an outdoor
	# night sky, so this reads as distinctly indoors/Hideout next to the
	# other (all-outdoor) vignettes.
	var top_color := Color(0.09, 0.06, 0.05, 1)
	var mid_color := Color(0.16, 0.1, 0.08, 1)
	var bottom_color := Color(0.06, 0.045, 0.04, 1)
	var steps := 20
	for i in range(steps):
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		var c: Color
		if t0 < 0.6:
			c = top_color.lerp(mid_color, t0 / 0.6)
		else:
			c = mid_color.lerp(bottom_color, (t0 - 0.6) / 0.4)
		draw_rect(Rect2(0, h * t0, w, h * (t1 - t0) + 1.5), c)

	# Soft warm lamp glow behind Rose.
	var glow_center: Vector2 = rose_base_pos + Vector2(0, -h * 0.12) if rose_base_pos != Vector2.ZERO else Vector2(w * 0.64, h * 0.5)
	for r in [140.0, 100.0, 65.0]:
		draw_circle(glow_center, r, Color(1.0, 0.85, 0.55, 0.05))

	# Floor.
	draw_rect(Rect2(0, h * 0.86, w, h * 0.14), Color(0.05, 0.035, 0.03, 1))

	# Wooden shelf unit - 3 stacked planks, right beside Rose so she
	# reads as standing at it.
	var shelf_x0 := w * 0.06
	var shelf_x1 := w * 0.42
	var plank_color := Color(0.32, 0.2, 0.11, 1)
	var plank_dark := Color(0.22, 0.13, 0.07, 1)
	var shelf_ys: Array[float] = [h * 0.42, h * 0.58, h * 0.74]
	for sy in shelf_ys:
		draw_rect(Rect2(shelf_x0, sy, shelf_x1 - shelf_x0, 8.0), plank_color)
		draw_rect(Rect2(shelf_x0, sy + 8.0, shelf_x1 - shelf_x0, 3.0), plank_dark)
	draw_rect(Rect2(shelf_x0 - 6.0, shelf_ys[0], 6.0, shelf_ys[2] - shelf_ys[0] + 11.0), plank_dark)
	draw_rect(Rect2(shelf_x1, shelf_ys[0], 6.0, shelf_ys[2] - shelf_ys[0] + 11.0), plank_dark)

	# Static plushies sitting on the shelves themselves (distinct from
	# the ones wandering the floor below) - simple rounded blobs with
	# small ears, a couple per shelf.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var plushie_palette := [Color(0.8, 0.5, 0.6, 1), Color(0.5, 0.65, 0.85, 1), Color(0.9, 0.75, 0.4, 1), Color(0.6, 0.8, 0.6, 1)]
	var shelf_i := 0
	for sy in shelf_ys:
		var count := 2 + (shelf_i % 2)
		var spacing := (shelf_x1 - shelf_x0) / float(count + 1)
		for i in range(count):
			var px := shelf_x0 + spacing * float(i + 1)
			var py := sy - 9.0
			var col: Color = plushie_palette[(i + shelf_i) % plushie_palette.size()]
			draw_circle(Vector2(px, py), 9.0, col)
			draw_circle(Vector2(px, py - 8.0), 6.0, col)
			draw_circle(Vector2(px - 4.0, py - 13.0), 2.2, col)
			draw_circle(Vector2(px + 4.0, py - 13.0), 2.2, col)
		shelf_i += 1

	# Vignette darkening top/bottom, matching the other vignettes.
	var vig := Color(0, 0, 0, 0.4)
	draw_rect(Rect2(0, 0, w, h * 0.1), vig)
	draw_rect(Rect2(0, h * 0.9, w, h * 0.1), vig)
