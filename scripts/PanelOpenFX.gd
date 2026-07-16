class_name PanelOpenFX
extends RefCounted

# A quick, reusable "pop in" entrance for popup panels - scale up from
# slightly-small + fade in, so a panel appearing reads as an animated
# event instead of an instant visibility flip. Neither ChangelogPanel
# nor LeaderboardPanel (the two panels the user singled out as feeling
# "juiced up") actually have an entrance animation - their felt juice is
# the ambient DystopianBackground particle backdrop plus (Leaderboard
# only) the bespoke LeaderboardTrophyBanner.gd header - so this fills a
# gap that's genuinely missing everywhere, not just on the "plain" panels.
#
# Call at the END of a panel's own open(), AFTER visible = true is
# already set (so the panel's real layout/size is resolved before the
# tween starts touching scale/modulate).
static func animate_open(panel: Control) -> void:
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.92, 0.92)
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
