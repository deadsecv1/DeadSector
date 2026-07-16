extends TestCase

# Regression coverage for the "PRE SEASON" preview button added to
# MainMenu (2026-07-16) - the game explicitly isn't calling its current
# content "Season 1" (that's reserved for 1.0 Release, per RoadmapPanel's
# own framing), so this button just previews the nearest RoadmapPanel
# "COMING SOON" entry instead. days_until_roadmap_date() is a pure
# function specifically so this doesn't depend on the real system clock.

const MainMenuScript := preload("res://scripts/MainMenu.gd")

func test_parses_a_future_date_in_the_same_month() -> void:
	var today := {"year": 2026, "month": 7, "day": 16}
	assert_eq(MainMenuScript.days_until_roadmap_date("Jul 18", today), 2)

func test_today_is_zero_days() -> void:
	var today := {"year": 2026, "month": 7, "day": 16}
	assert_eq(MainMenuScript.days_until_roadmap_date("Jul 16", today), 0)

func test_parses_a_future_date_in_a_later_month() -> void:
	var today := {"year": 2026, "month": 7, "day": 16}
	assert_eq(MainMenuScript.days_until_roadmap_date("Aug 04", today), 19)

func test_a_past_date_returns_negative_one() -> void:
	var today := {"year": 2026, "month": 7, "day": 16}
	assert_eq(MainMenuScript.days_until_roadmap_date("Jul 03", today), -1)

func test_unparseable_date_returns_negative_one() -> void:
	var today := {"year": 2026, "month": 7, "day": 16}
	assert_eq(MainMenuScript.days_until_roadmap_date("TBD", today), -1)
	assert_eq(MainMenuScript.days_until_roadmap_date("", today), -1)

func test_every_upcoming_roadmap_entry_either_parses_or_is_tbd() -> void:
	# Guards against a future roadmap entry using a date format this
	# parser silently can't read (e.g. a typo, or a non-3-letter month
	# abbreviation) - every SECTION_UPCOMING date should either parse
	# cleanly or be the literal "TBD" placeholder.
	var today := {"year": 2026, "month": 1, "day": 1}
	var roadmap_scene: Node = load("res://scenes/MainMenu.tscn").instantiate()
	var roadmap_panel = roadmap_scene.get_node("RoadmapPanel")
	for entry in roadmap_panel.ROADMAP:
		if entry.get("section", "") != roadmap_panel.SECTION_UPCOMING:
			continue
		var date_str: String = entry.get("date", "")
		if date_str == "TBD":
			continue
		assert_ne(MainMenuScript.days_until_roadmap_date(date_str, today), -1, "Roadmap date '%s' (%s) failed to parse" % [date_str, entry.get("title", "?")])
	roadmap_scene.queue_free()
