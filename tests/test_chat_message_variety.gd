extends TestCase

# Regression coverage for the 2026-07-16 chat variety pass. The user's
# reported complaint ("same message every couple minutes") traced to
# MESSAGES_WITH_OTHER and MESSAGES_TO_PLAYER_BY_NAME having NO repeat
# protection at all (unlike every other pool, which already ran through
# _roll_no_repeat) - fixed alongside a big expansion of every pool and
# a per-sender typing-style transform (some senders type properly,
# some strip punctuation entirely, some are left as-authored).

const GlobalChatBoxScript := preload("res://scripts/GlobalChatBox.gd")
const GlobalChatPanelScript := preload("res://scripts/GlobalChatPanel.gd")

func _make_box() -> Node:
	var box: Node = GlobalChatBoxScript.new()
	add_child(box)
	return box

func test_typing_style_is_deterministic_per_sender_name() -> void:
	var box := _make_box()
	var sender := {"name": "SomeTestSender"}
	var first: String = box._stylize_for_sender("hello world", sender)
	var second: String = box._stylize_for_sender("hello world", sender)
	assert_eq(first, second, "Same sender should always get the same typing-style transform")
	remove_child(box)
	box.queue_free()

func test_proper_style_capitalizes_and_punctuates() -> void:
	var box := _make_box()
	# hash()-based style selection isn't something we pick directly, so
	# call the transform functions directly to verify their own behavior
	# in isolation, rather than hunting for a name that happens to land
	# on a particular style bucket.
	var result: String = box._make_proper("hello there")
	assert_eq(result, "Hello there.")
	var already_punctuated: String = box._make_proper("wait really?")
	assert_eq(already_punctuated, "Wait really?")
	remove_child(box)
	box.queue_free()

func test_sloppy_style_strips_punctuation_and_lowercases() -> void:
	var box := _make_box()
	var result: String = box._make_sloppy("Hello, World! Really?")
	assert_eq(result, "hello world really")
	remove_child(box)
	box.queue_free()

func test_empty_text_is_left_alone() -> void:
	var box := _make_box()
	assert_eq(box._stylize_for_sender("", {"name": "Anyone"}), "")
	remove_child(box)
	box.queue_free()

func test_message_with_other_pool_has_real_variety() -> void:
	# The exact pool that had zero repeat-protection before this fix -
	# guard against it ever shrinking back down accidentally.
	assert_gt(GlobalChatPanelScript.MESSAGES_WITH_OTHER.size(), 20)

func test_message_to_player_by_name_pool_has_real_variety() -> void:
	assert_gt(GlobalChatPanelScript.MESSAGES_TO_PLAYER_BY_NAME.size(), 15)

func test_no_duplicate_entries_within_each_expanded_pool() -> void:
	for pool in [GlobalChatPanelScript.MESSAGES, GlobalChatPanelScript.MESSAGES_WITH_OTHER, GlobalChatPanelScript.MESSAGES_BRAINROT, GlobalChatPanelScript.MESSAGES_TO_PLAYER_BY_NAME, GlobalChatPanelScript.REPLY_ACKS, GlobalChatPanelScript.REPLY_TO_PLAYER]:
		var seen: Dictionary = {}
		for line in pool:
			assert_false(seen.has(line), "Duplicate chat line: %s" % line)
			seen[line] = true
