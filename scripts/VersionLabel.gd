extends Label

# Always shows the CURRENT version, pulled directly from the last entry
# in the Changelog's own data - so this can never drift out of sync with
# reality just because someone forgot to update a second copy of the
# version number by hand.

const ChangelogScript := preload("res://scripts/ChangelogPanel.gd")

func _ready() -> void:
	var changelog: Array = ChangelogScript.get_all_entries()
	var current: String = "?"
	if not changelog.is_empty():
		current = str(changelog[changelog.size() - 1].get("version", "?"))
	text = "Release v%s - ALPHA" % current
