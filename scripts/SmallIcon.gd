extends Control

# A small themed icon badge used in Quest and Roadmap rows - a colored
# circle with a simple shape inside, purely procedural (no image assets).

@export var icon_type: String = "star"
@export var icon_bg: Color = Color(0.18, 0.2, 0.18, 1)

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	var r: float = size.x / 2.0
	if r <= 0.0:
		return
	var c := Vector2(r, r)
	draw_circle(c, r, icon_bg)
	draw_arc(c, r, 0.0, TAU, 20, Color(1, 1, 1, 0.15), 1.5, true)

	match icon_type:
		"combat":
			draw_line(c + Vector2(-r, -r) * 0.55, c + Vector2(r, r) * 0.55, Color(0.9, 0.3, 0.25, 1), max(2.0, r * 0.18))
			draw_line(c + Vector2(r, -r) * 0.55, c + Vector2(-r, r) * 0.55, Color(0.9, 0.3, 0.25, 1), max(2.0, r * 0.18))
		"money":
			draw_circle(c, r * 0.55, Color(0.85, 0.75, 0.3, 1))
			draw_circle(c, r * 0.55, Color(0.5, 0.4, 0.1, 0.5))
		"boss":
			draw_circle(c, r * 0.5, Color(0.75, 0.12, 0.12, 1))
			draw_circle(c + Vector2(-r * 0.22, -r * 0.12), r * 0.1, Color(1, 1, 1, 0.9))
			draw_circle(c + Vector2(r * 0.22, -r * 0.12), r * 0.1, Color(1, 1, 1, 0.9))
		"skull":
			draw_circle(c + Vector2(0, -r * 0.12), r * 0.5, Color(0.92, 0.9, 0.85, 1))
			draw_circle(c + Vector2(-r * 0.2, -r * 0.15), r * 0.13, Color(0.15, 0.15, 0.15, 1))
			draw_circle(c + Vector2(r * 0.2, -r * 0.15), r * 0.13, Color(0.15, 0.15, 0.15, 1))
			draw_rect(Rect2(c + Vector2(-r * 0.06, r * 0.05), Vector2(r * 0.12, r * 0.2)), Color(0.15, 0.15, 0.15, 1))
			for i in range(3):
				var tx: float = c.x - r * 0.22 + r * 0.22 * float(i)
				draw_rect(Rect2(Vector2(tx, c.y + r * 0.32), Vector2(r * 0.12, r * 0.14)), Color(0.75, 0.72, 0.68, 1))
		"tech":
			draw_rect(Rect2(c - Vector2(r, r) * 0.5, Vector2(r, r)), Color(0.3, 0.6, 0.85, 1))
			draw_rect(Rect2(c - Vector2(r, r) * 0.5, Vector2(r, r)), Color(0.15, 0.35, 0.55, 1), false, 1.5)
		"stealth":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.6), c + Vector2(r * 0.55, r * 0.5), c + Vector2(-r * 0.55, r * 0.5)]), Color(0.3, 0.5, 0.35, 1))
		"medical":
			draw_line(c + Vector2(0, -r * 0.5), c + Vector2(0, r * 0.5), Color(0.85, 0.25, 0.2, 1), max(2.5, r * 0.2))
			draw_line(c + Vector2(-r * 0.5, 0), c + Vector2(r * 0.5, 0), Color(0.85, 0.25, 0.2, 1), max(2.5, r * 0.2))
		"vehicle":
			draw_rect(Rect2(c + Vector2(-r * 0.6, -r * 0.15), Vector2(r * 1.2, r * 0.55)), Color(0.4, 0.45, 0.5, 1))
			draw_circle(c + Vector2(-r * 0.3, r * 0.35), r * 0.14, Color(0.1, 0.1, 0.1, 1))
			draw_circle(c + Vector2(r * 0.3, r * 0.35), r * 0.14, Color(0.1, 0.1, 0.1, 1))
		"event":
			draw_arc(c, r * 0.55, 0.0, TAU, 16, Color(0.9, 0.6, 0.2, 1), max(2.0, r * 0.16), true)
		"key":
			draw_circle(c + Vector2(-r * 0.2, 0), r * 0.3, Color(0.85, 0.7, 0.3, 1))
			draw_line(c + Vector2(0.05 * r, 0), c + Vector2(r * 0.6, 0), Color(0.85, 0.7, 0.3, 1), max(2.0, r * 0.14))
		"gear":
			draw_circle(c, r * 0.5, Color(0.55, 0.65, 0.75, 1))
			for i in range(6):
				var ang: float = TAU * float(i) / 6.0
				draw_circle(c + Vector2(cos(ang), sin(ang)) * r * 0.55, r * 0.1, Color(0.55, 0.65, 0.75, 1))
		"contact":
			# A small speech bubble - a first-meeting/introduction quest.
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 0.5, -r * 0.35), c + Vector2(r * 0.5, -r * 0.35),
				c + Vector2(r * 0.5, r * 0.15), c + Vector2(-r * 0.1, r * 0.15),
				c + Vector2(-r * 0.25, r * 0.45), c + Vector2(-r * 0.2, r * 0.15),
				c + Vector2(-r * 0.5, r * 0.15),
			]), Color(0.75, 0.7, 0.9, 1))
		"recruits":
			# Two overlapping head silhouettes - a "meet the people" icon.
			draw_circle(c + Vector2(-r * 0.22, -r * 0.05), r * 0.28, Color(0.7, 0.6, 0.85, 1))
			draw_circle(c + Vector2(r * 0.22, -r * 0.05), r * 0.28, Color(0.55, 0.45, 0.75, 1))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.45, r * 0.5), c + Vector2(0, r * 0.15), c + Vector2(-r * 0.05, r * 0.5)]), Color(0.7, 0.6, 0.85, 1))
			draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.05, r * 0.5), c + Vector2(0, r * 0.15), c + Vector2(r * 0.45, r * 0.5)]), Color(0.55, 0.45, 0.75, 1))
		"squad":
			# Two figures side by side - bringing backup into a raid.
			for dx in [-0.28, 0.28]:
				draw_circle(c + Vector2(r * dx, -r * 0.3), r * 0.18, Color(0.4, 0.55, 0.4, 1))
				draw_colored_polygon(PackedVector2Array([c + Vector2(r * (dx - 0.2), r * 0.5), c + Vector2(r * dx, r * 0.0), c + Vector2(r * (dx + 0.2), r * 0.5)]), Color(0.4, 0.55, 0.4, 1))
		"ghost_kill":
			# A ghost silhouette with a strike-through - distinct from
			# plain combat since this is specifically about the undead.
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 0.35, r * 0.4), c + Vector2(-r * 0.35, -r * 0.1),
				c + Vector2(0, -r * 0.5), c + Vector2(r * 0.35, -r * 0.1), c + Vector2(r * 0.35, r * 0.4),
				c + Vector2(r * 0.2, r * 0.2), c + Vector2(0, r * 0.4), c + Vector2(-r * 0.2, r * 0.2),
			]), Color(0.75, 0.8, 0.85, 0.85))
			draw_line(c + Vector2(-r * 0.5, -r * 0.45), c + Vector2(r * 0.5, r * 0.45), Color(0.85, 0.25, 0.2, 0.9), max(1.5, r * 0.12))
		"compass":
			# A compass needle - exploration/discovery quests.
			draw_circle(c, r * 0.5, Color(0.35, 0.4, 0.3, 1))
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.4), c + Vector2(r * 0.14, 0), c + Vector2(0, r * 0.1)]), Color(0.85, 0.3, 0.25, 1))
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, r * 0.4), c + Vector2(-r * 0.14, 0), c + Vector2(0, -r * 0.1)]), Color(0.85, 0.85, 0.8, 1))
		"soul_wisp":
			# A small drifting wisp with a soft trailing glow.
			draw_circle(c + Vector2(0, -r * 0.1), r * 0.3, Color(0.75, 0.55, 0.95, 0.9))
			draw_circle(c + Vector2(-r * 0.15, r * 0.25), r * 0.16, Color(0.75, 0.55, 0.95, 0.5))
			draw_circle(c + Vector2(r * 0.2, r * 0.32), r * 0.1, Color(0.75, 0.55, 0.95, 0.3))
		"harvester":
			# A jagged reaper-like silhouette for the Commune boss.
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -r * 0.5), c + Vector2(r * 0.35, -r * 0.1), c + Vector2(r * 0.2, r * 0.5),
				c + Vector2(-r * 0.2, r * 0.5), c + Vector2(-r * 0.35, -r * 0.1),
			]), Color(0.5, 0.15, 0.15, 1))
			draw_line(c + Vector2(-r * 0.3, -r * 0.2), c + Vector2(r * 0.3, r * 0.2), Color(0.9, 0.7, 0.2, 0.9), max(1.5, r * 0.1))
		"refuge":
			# A simple gate/portal arch - the Bloodline Refuge event.
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 0.4, r * 0.45), c + Vector2(-r * 0.4, -r * 0.1), c + Vector2(0, -r * 0.5),
				c + Vector2(r * 0.4, -r * 0.1), c + Vector2(r * 0.4, r * 0.45), c + Vector2(r * 0.22, r * 0.45),
				c + Vector2(r * 0.22, 0), c + Vector2(-r * 0.22, 0), c + Vector2(-r * 0.22, r * 0.45),
			]), Color(0.35, 0.3, 0.6, 1))
		"cipher":
			# A small circuit-lock pattern - decoding an engram.
			draw_circle(c, r * 0.45, Color(0.2, 0.7, 0.55, 1), false, max(1.5, r * 0.1))
			draw_line(c + Vector2(-r * 0.2, 0), c + Vector2(r * 0.2, 0), Color(0.2, 0.7, 0.55, 1), max(1.5, r * 0.1))
			draw_line(c + Vector2(0, -r * 0.2), c + Vector2(0, r * 0.2), Color(0.2, 0.7, 0.55, 1), max(1.5, r * 0.1))
		"spike_crown":
			# A crown of spikes - Spike's boss quest specifically.
			draw_circle(c, r * 0.42, Color(0.75, 0.12, 0.12, 1))
			for i in range(5):
				var ang: float = -PI / 2.0 + TAU * float(i) / 5.0
				var base: Vector2 = c + Vector2(cos(ang), sin(ang)) * r * 0.42
				var tip: Vector2 = c + Vector2(cos(ang), sin(ang)) * r * 0.68
				draw_line(base, tip, Color(0.75, 0.12, 0.12, 1), max(1.5, r * 0.1))
		"bone_crown":
			# A ring of small bones - Rattles' boss quest specifically.
			draw_circle(c, r * 0.32, Color(0.85, 0.82, 0.72, 1))
			for i in range(6):
				var ang: float = TAU * float(i) / 6.0
				var pos: Vector2 = c + Vector2(cos(ang), sin(ang)) * r * 0.55
				draw_rect(Rect2(pos - Vector2(r * 0.06, r * 0.12), Vector2(r * 0.12, r * 0.24)), Color(0.85, 0.82, 0.72, 1))
		# --- Arena rank icons (6 total) - a simple visual progression:
		# a single mark, then crossed blades that get more ornate, ending
		# in a crown, echoing the same "climbing tiers" shape language as
		# the normal Rank ladder's icons above.
		"arena_initiate":
			draw_circle(c, r * 0.22, Color(0.75, 0.7, 0.8, 1))
		"arena_rival":
			draw_line(c + Vector2(-r * 0.4, -r * 0.4), c + Vector2(r * 0.4, r * 0.4), Color(0.55, 0.6, 0.9, 1), max(2.0, r * 0.16))
		"arena_duelist":
			draw_line(c + Vector2(-r * 0.4, -r * 0.4), c + Vector2(r * 0.4, r * 0.4), Color(0.65, 0.45, 0.9, 1), max(2.0, r * 0.16))
			draw_line(c + Vector2(r * 0.4, -r * 0.4), c + Vector2(-r * 0.4, r * 0.4), Color(0.65, 0.45, 0.9, 1), max(2.0, r * 0.16))
		"arena_gladiator":
			draw_line(c + Vector2(-r * 0.42, -r * 0.42), c + Vector2(r * 0.42, r * 0.42), Color(0.8, 0.3, 0.85, 1), max(2.0, r * 0.16))
			draw_line(c + Vector2(r * 0.42, -r * 0.42), c + Vector2(-r * 0.42, r * 0.42), Color(0.8, 0.3, 0.85, 1), max(2.0, r * 0.16))
			draw_circle(c, r * 0.16, Color(0.9, 0.55, 0.95, 1))
		"arena_champion":
			draw_line(c + Vector2(-r * 0.42, -r * 0.42), c + Vector2(r * 0.42, r * 0.42), Color(0.85, 0.55, 0.3, 1), max(2.0, r * 0.16))
			draw_line(c + Vector2(r * 0.42, -r * 0.42), c + Vector2(-r * 0.42, r * 0.42), Color(0.85, 0.55, 0.3, 1), max(2.0, r * 0.16))
			for i in range(5):
				var star_ang2: float = -PI / 2.0 + TAU * float(i) / 5.0
				draw_circle(c + Vector2(cos(star_ang2), sin(star_ang2)) * r * 0.55, r * 0.06, Color(0.95, 0.8, 0.4, 1))
		"arena_grandmaster":
			# A small ornate crown, prismatic-tier top rank.
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 0.42, r * 0.32), c + Vector2(-r * 0.42, r * 0.05), c + Vector2(-r * 0.2, r * 0.28),
				c + Vector2(0, -r * 0.15), c + Vector2(r * 0.2, r * 0.28), c + Vector2(r * 0.42, r * 0.05),
				c + Vector2(r * 0.42, r * 0.32),
			]), Color(1.0, 0.85, 0.3, 1))
			draw_circle(c + Vector2(0, -r * 0.15), r * 0.08, Color(0.9, 0.4, 0.9, 1))
		"arena":
			# A purple ring with a small star core - the Arena feature
			# itself (distinct from the per-rank icons above).
			draw_arc(c, r * 0.5, 0.0, TAU, 20, Color(0.7, 0.45, 0.95, 1), max(2.0, r * 0.14), true)
			for i in range(5):
				var star_ang3: float = -PI / 2.0 + TAU * float(i) / 5.0
				draw_circle(c + Vector2(cos(star_ang3), sin(star_ang3)) * r * 0.24, r * 0.07, Color(0.85, 0.65, 1.0, 1))
		# --- Rose's 5 Lore topics - each gets its own small icon in the
		# topic list instead of all 5 rows looking identical.
		"bags_topic":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.4, -r * 0.35), c + Vector2(r * 0.4, -r * 0.35), c + Vector2(r * 0.35, r * 0.45), c + Vector2(-r * 0.35, r * 0.45)]), Color(0.85, 0.55, 0.65, 1))
			draw_arc(c + Vector2(0, -r * 0.4), r * 0.22, PI, TAU, 12, Color(0.6, 0.35, 0.45, 1), max(1.5, r * 0.1), false)
		"boba_topic":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.32, -r * 0.15), c + Vector2(r * 0.32, -r * 0.15), c + Vector2(r * 0.24, r * 0.5), c + Vector2(-r * 0.24, r * 0.5)]), Color(0.85, 0.65, 0.45, 1))
			draw_line(c + Vector2(r * 0.08, -r * 0.55), c + Vector2(r * 0.14, -r * 0.15), Color(0.95, 0.9, 0.85, 1), max(1.5, r * 0.08))
			for i in range(3):
				draw_circle(c + Vector2(-r * 0.16 + float(i) * r * 0.16, r * 0.35), r * 0.06, Color(0.2, 0.12, 0.08, 1))
		"league_topic":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.5), c + Vector2(r * 0.38, -r * 0.25), c + Vector2(r * 0.32, r * 0.2), c + Vector2(0, r * 0.5), c + Vector2(-r * 0.32, r * 0.2), c + Vector2(-r * 0.38, -r * 0.25)]), Color(0.55, 0.7, 0.95, 1))
		"nessa_topic":
			draw_circle(c + Vector2(-r * 0.22, r * 0.32), r * 0.16, Color(0.85, 0.6, 0.9, 1))
			draw_rect(Rect2(c + Vector2(-r * 0.08, -r * 0.4), Vector2(r * 0.08, r * 0.72)), Color(0.85, 0.6, 0.9, 1))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.08, -r * 0.4), c + Vector2(r * 0.28, -r * 0.25), c + Vector2(r * 0.28, -r * 0.05), c + Vector2(-r * 0.08, -r * 0.2)]), Color(0.85, 0.6, 0.9, 1))
		"plushies_topic":
			draw_circle(c + Vector2(-r * 0.32, -r * 0.38), r * 0.16, Color(0.8, 0.6, 0.4, 1))
			draw_circle(c + Vector2(r * 0.32, -r * 0.38), r * 0.16, Color(0.8, 0.6, 0.4, 1))
			draw_circle(c + Vector2(0, r * 0.05), r * 0.42, Color(0.85, 0.65, 0.45, 1))
			draw_circle(c + Vector2(-r * 0.14, -r * 0.02), r * 0.05, Color(0.15, 0.1, 0.08, 1))
			draw_circle(c + Vector2(r * 0.14, -r * 0.02), r * 0.05, Color(0.15, 0.1, 0.08, 1))
		_:
			var pts := PackedVector2Array()
			for i in range(5):
				var star_ang: float = -PI / 2.0 + TAU * float(i) / 5.0
				pts.append(c + Vector2(cos(star_ang), sin(star_ang)) * r * 0.55)
			draw_colored_polygon(pts, Color(0.9, 0.8, 0.4, 1))
