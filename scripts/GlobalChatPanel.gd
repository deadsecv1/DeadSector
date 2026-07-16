extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

signal closed

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		if GlobalChatBox.chat_box_open:
			return
		get_viewport().set_input_as_handled()
		closed.emit()
		return
	if context_menu != null and context_menu.visible and event is InputEventMouseButton and event.pressed:
		if not context_menu.get_global_rect().has_point(event.global_position):
			context_menu.visible = false
	if message_menu != null and message_menu.visible and event is InputEventMouseButton and event.pressed:
		if not message_menu.get_global_rect().has_point(event.global_position):
			message_menu.visible = false
	if emoji_picker != null and emoji_picker.visible and event is InputEventMouseButton and event.pressed:
		if not emoji_picker.get_global_rect().has_point(event.global_position):
			emoji_picker.visible = false

const PortraitScene := preload("res://scenes/TraderPortrait.tscn")
const SmallIconScene := preload("res://scenes/SmallIcon.tscn")
const PlayerContextMenuScript := preload("res://scripts/PlayerContextMenu.gd")
const TooltipParticlesScript := preload("res://scripts/TooltipParticles.gd")
const RoundedCornersShader := preload("res://shaders/RoundedCorners.gdshader")

@onready var message_list: VBoxContainer = $VBox/MessageScroll/MessageList
@onready var message_scroll: ScrollContainer = $VBox/MessageScroll
@onready var chat_input: LineEdit = $VBox/ChatInput
@onready var close_button: Button = $VBox/CloseButton
@onready var context_menu_host: Control = $ContextMenuHost

var context_menu: Control
var message_menu: PanelContainer
var emoji_picker: PanelContainer
var _message_menu_target: Dictionary = {}

var _chat_pool: Array = []
var _msg_timer: float = 0.0
var _next_msg_delay: float = 3.0
var _reaction_timer: float = 0.0
var _next_reaction_delay: float = 4.0
var _recent_message_uses: Dictionary = {}
var _message_rows: Array = []

const EMOJI_POOL := ["😂", "❤️", "👍", "🔥", "😮", "😭", "💀", "🎉"]
const NO_REPEAT_SECONDS := 60.0

# General chatter - no name reference, just the vibe of a busy lobby:
# party requests, gear questions, alpha/tech-test confusion, badge and
# rubles flexing, reset predictions, and plain banter.
const MESSAGES := [
	"anyone tryna party up for a boneclock run? need 1 more",
	"LFG void trench, got 2 already",
	"party check 2/3, need a scav for the last spot",
	"who's down to raid the graveyard rn",
	"is the railgun actually good or is it just for looks",
	"shotgun or smg for close range, need opinions",
	"what's the best budget loadout rn, im broke",
	"anyone know if thorn weapons are actually worth crafting",
	"flamethrower slaps way more than people give it credit for",
	"wait what does the alpha tester title even do",
	"how do you even get the alpha pioneer badge, is it still up",
	"someone explain the alpha vs tech test thing to me",
	"is alpha rewards still claimable or did i miss it",
	"just unlocked tech test veteran, feels good bro",
	"check my alpha pioneer badge lol been grinding for this",
	"finally got peak of the sector let's gooo",
	"just hit 500k rubles from one raid, insane",
	"sold a multiversal for so many rubles just now",
	"rubles farm is actually crazy rn if you know where to loot",
	"broke my personal best on stash worth today",
	"getting rank 1 this reset, calling it now",
	"syndicate or bust this season lol",
	"watch me hit top 3 by friday, screenshotting this",
	"this game is way too addicting ngl",
	"salvaged beasts event is actually so good",
	"gl everyone on the leaderboard reset",
	"anyone else obsessed with the bloodline gauntlet rn",
	"just hatched a multiversal egg im crying",
	"the wipe/rewards system is actually pretty generous ngl",
	"anyone selling a spare legendary chestplate",
	"scav runs are so underrated for early rubles",
	"real players are so much scarier than regular raiders lol",
	"why is the goblin so much tankier than i remember",
	"anyone else think the flea market is slept on",
	"my pet just leveled up and it's actually kind of built now",
	"anyone got a good build for the void trench sentinels",
	"anyone want to duo the mechanic shop area",
	"anyone know when the next season starts",
	"anyone else farming skill points rn",
	# Dev praise
	"ngl the dev is actually goated for this update",
	"shoutout the dev for actually listening to feedback fr",
	"dev really said let's add global chat, respect",
	"the dev cooked with this patch ngl",
	"unpopular opinion but the dev undersells how good this game actually is",
	"the dev patching stuff this fast is actually crazy",
	"say what you want, the dev actually cares about this game",
	# Feature requests
	"dev if you're reading this we need clan support fr",
	"someone tell the dev we need more weapon skins",
	"dev pls add trading between players someday",
	"wish the dev would add a spectator mode ngl",
	"dev add controller support pls im begging",
	"can the dev add more maps, just a thought",
	"dev we need a replay system fr fr",
	# Data screen / discoveries
	"just hit 80% on the data screen, almost there",
	"anyone actually 100%'d the enemy discoveries yet",
	"still missing like 3 enemies on my data screen",
	"finally discovered the rift wraith, that thing is rare",
	"data screen completion is way harder than people think",
	# Events
	"salvaged beasts event ends soon right?",
	"bloodline gauntlet is actually the best event ngl",
	"anyone else grinding the current event hard",
	"when's the next event dropping does anyone know",
	"event rewards this time around are actually solid",
	# Wave progress (Bloodline Gauntlet)
	"got to wave 14 in the gauntlet last night",
	"anyone beat wave 20 yet, its brutal out there",
	"died on wave 9 again bro im cooked",
	"new pb wave 17 in bloodline lets goooo",
	"wave 12 enemies hit different fr",
	# Loot/economy chatter
	"anyone else feel like ammo drops way less than it used to",
	"just found a full set of matching legendary gear, never happens",
	"selling everything before the next wipe, might as well",
	"why do keys always drop for houses i already looted",
	"artifacts feel way more useful now than a few patches ago",
	"junk to alloys conversion rate still feels rough ngl",
	"anyone actually track their stash worth over time, im curious",
	"got my first divine drop today, hands were shaking fr",
	"still haven't seen a godforged item drop, does anyone even have one",
	# Raid stories
	"got sandwiched between two real players and somehow survived",
	"extraction chopper left without me again, story of my life",
	"the mechanic shop always has someone camping it lately",
	"finally found the lake on overgrowth after all this time",
	"boneclock's skeleton cave still creeps me out ngl",
	"anyone else think the gas station fight is way harder than it should be",
	"the boss arena on overgrowth still humbles me every time",
	"just barely escaped a 3-man squad with one hp, insane run",
	# Progression / meta talk
	"prestige reset hits different once you actually understand the bonus",
	"skill points changed the whole meta honestly",
	"anyone maxed their skill tree yet or still grinding",
	"the level cap grind is real but worth it eventually",
	"still trying to figure out the best build for solo queue",
]

# Templates that mention another random player - referencing someone
# from the same pool by name, both positive and negative.
const MESSAGES_WITH_OTHER := [
	"{other} better watch out, im coming for #1",
	"gg {other} that was a close extraction",
	"shoutout {other} for the clutch save earlier",
	"bro {other} literally camped extraction the entire raid",
	"why would {other} third party me like that smh",
	"reported {other} for camping lol not funny",
	"{other} you're actually so toxic rn chill",
	"can we not do this every single raid {other}",
	"{other} just outran a whole squad, respect",
	"lmao {other} got cooked by a goblin of all things",
	"{other} carry me through boneclock next raid please",
	"{other} clutched that 1v3 like it was nothing, respect",
	"not {other} extracting with 30 seconds left, heart attack material",
	"{other} keeps stealing my kills and i love it honestly",
	"someone tell {other} to stop running solo into everything",
	"{other} really said trust me and it worked, wild",
	"watching {other} climb the leaderboard is actually inspiring ngl",
	"{other} owes me a rematch after that arena loss",
	"{other} pulled the exact loadout i wanted, jealous",
	"props to {other} for actually reviving me mid raid",
	"{other} disappeared the second loot dropped, typical",
	"{other} and i almost died laughing at that goblin encounter",
	"did {other} really just walk past a legendary chest, unreal",
	"{other} carried that whole raid and said nothing about it",
	"{other} needs to stop baiting me into bad fights lol",
	"shoutout {other} for the free ammo drop earlier",
	"{other} somehow finds loot i never even see",
	"{other} out here soloing bosses like its nothing",
	"{other} why do you always extract right as i spawn in",
	"{other} you're the reason i still play this honestly",
	"{other} keeps calling dibs on loot before it even drops",
	"{other} just tanked a whole squad's worth of damage, insane",
	"can {other} teach a class on not dying to goblins please",
	"{other} really thought that was a safe fight, it was not",
	"{other} has the worst luck with loot bags i swear",
	"{other} somehow always has better ammo than me",
]

# Genuine "you're doing great" callouts about someone's ACTUAL leaderboard
# placement - {other} and {rank} only ever get filled in with a real bot
# that's genuinely sitting in the top 10 right now (see _roll_message()),
# never a random name with a made-up number. This used to be a flat
# "is that really you at #2" line that fired for anyone - which is
# exactly the kind of thing that reads as a bug the moment someone
# checks the board and the name they got called out for isn't there.
const MESSAGES_RANK_CALLOUT := [
	"{other} is that really you at #{rank} right now",
	"wait {other} you're actually #{rank}?? insane",
	"{other} sitting at #{rank} and just casually chatting, humble",
	"not {other} pulling #{rank} like it's nothing",
	"{other} #{rank} on the board AND active in chat, we don't deserve you",
]

# Genuine badge flexes - {count} is always the sender's REAL number of
# priority badges (here_from_the_start / alpha_pioneer / rank_1_champion
# / rank_2_elite / rank_3_podium / peak_of_the_sector - the ones that
# actually pulse), never a made-up number. Only fires for someone who
# actually has at least one (see _roll_message()).
const MESSAGES_BADGE_FLEX := [
	"{count} priority badge{plural} now, getting there",
	"just hit {count} priority badge{plural}, feels good",
	"{count} priority badge{plural} and counting ngl",
	"sitting at {count} priority badge{plural}, not bad not bad",
]

# Short acknowledgment replies - used when one bot replies directly to
# whatever the previous message (bot or player) just said, so the chat
# reads like people actually talking instead of shouting into a void.
const REPLY_ACKS := [
	"fr", "lol true", "based", "exactly this", "no cap", "ong",
	"same tbh", "real talk", "facts", "this", "lmaooo true", "bro said it",
	"ratio", "mid take ngl", "gyatt", "he's so back", "sigma", "goated take",
	"understood the assignment", "certified", "bro cooked", "not the ratio",
	"real", "actual facts", "say less", "this is the way", "cooked take ngl",
	"L take but okay", "hard agree", "not lying", "spitting fr", "period",
]
const REPLY_TO_PLAYER := [
	"welcome lol", "real", "same energy honestly", "wait fr?",
	"gl with that", "lmaooo", "based take", "facts no printer",
	"o7", "W",
	"real talk", "lowkey true", "no shot", "actually real", "big if true",
	"L take ngl", "hard agree", "wait that's actually smart",
]

# People clowning on each other over rank - always references another
# name from the pool, never the player themselves.
const MESSAGES_MOCK_RANK := [
	"{other} still stuck in stray? embarrassing ngl",
	"imagine being {other} and still not syndicate",
	"{other} down bad in the ranks fr",
	"{other} hasn't moved a rank in weeks lol",
	"we get it {other}, not everyone can be top 500",
	"{other} still scavenger while the rest of us moved on",
	"laughing at {other}'s rank tbh no offense",
	"{other} needs to actually play ranked instead of talking about it",
	"{other} peaked in stray and never left",
]

# Pure chaotic Gen Z / brainrot noise - not really about anything, just
# the vibe of a chat that's a little too online. Mixed in sparingly so
# it's a seasoning, not the whole conversation.
const MESSAGES_BRAINROT := [
	"not the goblin fanum taxing my loot bag again",
	"this raid was so skibidi ngl no cap",
	"bro really said sigma grindset and camped extraction the whole time",
	"the way i just got cooked by a ghoul, im in ohio rn fr",
	"chat is this real, i just found a multiversal",
	"gyatt that loadout is actually unreal",
	"he has the sauce, certified sigma raider behavior",
	"not me mewing while waiting for extraction to open up",
	"bro's npc behavior camping the same corner every single raid",
	"no because why did a goblin just send me to ohio",
	"certified hood classic type raid honestly",
	"bro is so back after that clutch extraction ngl",
	"girl math says this loot bag was basically free",
	"im not an npc i swear i just afk'd for a sec",
	"the rizzler has entered the chat and the raid",
	"understood the assignment fr, extracted with literally everything",
	"let him cook, hes about to hit rank 1 im calling it",
	"very demure very mindful extraction if i do say so myself",
	"6 raiders pulled up on me at once, im so cooked",
	"this update is bussin fr no cap, dev ate",
	"skill issue but make it ohio",
	"the sector is so unserious sometimes ong",
	"caught in 4k camping extraction, thats crazy behavior",
	"nah cause the goblin really said not today and cooked me",
	"this game has me acting unwise ngl",
	"lowkey the sigma of extraction shooters fr",
	"bro has negative aura for looting my corpse that fast",
	"the loot goblin ratio in this game is unreal, free real estate",
	"not me getting the ick from my own loadout, respec incoming",
	"extraction camper aura is actually diabolical behavior fr",
	"i'm gonna be so fr, that legendary drop cured my depression",
	"bro's inventory management skills are giving npc energy",
	"the delulu is the solulu, i am getting rank 1 this reset",
	"caught the ghoul slander in 4k, that thing ate and left no crumbs",
	"my aura went to negative numbers after that goblin clip honestly",
	"we are NOT going to talk about how mid that extraction was",
	"bro really pulled up with zero ammo, absolute npc arc",
	"this loot pool is straight up bed rotting material, so good",
	"the glaze in this chat for the dev is actually deserved ngl",
	"i'm built different after that clutch 1v3 extraction fr fr",
	"nah the multiversal drop rate got me tweaking rn",
	"that was the most mewing extraction of my entire life",
	"bro said he's him after one (1) good raid, sit down",
	"the raid was giving very cinematic, very demure honestly",
	"caught myself glazing my own loadout in the mirror ngl",
	"this stash worth grind is unemployed behavior and i love it",
	"bro's gear check gave straight up ohio energy, respectfully",
	"the syndicate grind is not for the weak, im him though",
	"low taper fade but for my extraction timing, chef's kiss",
	"certified extraction goblin, no thoughts just loot",
	"the aura points i lost dying to a goblin cannot be recovered",
	"ts pmo when the loot bag despawns right before extraction",
	"real ones know the flamethrower is actually top tier no cap",
	"npc dialogue but it's just me narrating my own raid out loud",
	"the loot bag was mid but the vibes were immaculate honestly",
	"bro really said one more raid at 2am, we are not the same",
	"extraction music hits different when you're actually about to make it",
	"caught myself talking to my pet like it understands me, it doesn't",
	"the girlboss energy of extracting solo with a full stash cannot be replicated",
	"not the raid ending in a goblin standoff, peak comedy",
	"this chat has more personality than the actual npcs ngl",
	"bro treats every raid like its the chip finals, respect the dedication",
	"the loot goblins really said no thoughts head empty just vibes",
	"i said let him cook and he burned the whole kitchen down, 10/10",
	"extraction anxiety is a real disorder and this game gave it to me",
	"the way i flinched at my own shadow in boneclock, embarrassing",
	"certified npc moment walking into my own claymore",
	"this update lowkey fixed my sleep schedule, worse in every way",
	"the aura farming in this chat alone could power a small city",
]

# Bots occasionally address the player by name unprompted, not just as
# a reply after the player says something - reads as the chat actually
# noticing you're there.
const MESSAGES_TO_PLAYER_BY_NAME := [
	"yo {player} you still around?",
	"{player} wanna party up for a raid?",
	"hey {player} nice level by the way",
	"{player} you ever run void trench?",
	"anyone seen {player} pull a multiversal yet lol",
	"{player} carry me next raid please",
	"{player} what's your loadout rn",
	"{player} you still grinding or did you finally take a break",
	"yo {player} what's your stash worth rn",
	"{player} teach me your extraction timing please",
	"anyone know if {player} is still active, haven't seen them post",
	"{player} your last raid clip was actually insane",
	"{player} you free to squad up later tonight",
	"not gonna lie {player} your loadout choices are always solid",
	"{player} did you actually hit the leaderboard yet",
	"{player} drop your build, i wanna copy it ngl",
	"{player} you ever miss a wipe or do you always come back stacked",
	"{player} i see you lurking in chat, say something",
	"{player} what map you running tonight",
	"{player} your name's been coming up a lot lately, good stuff",
	"{player} you selling anything rn or are you hoarding it all",
	"{player} how's the grind going, worth it?",
	"{player} you ever get tired of this game, asking for a friend",
	"{player} your stats looked rough last i checked, everything good?",
	"{player} you're either really good or really lucky, which is it",
]

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())
	chat_input.text_submitted.connect(_on_chat_submitted)

	context_menu = Control.new()
	context_menu.anchor_right = 1.0
	context_menu.anchor_bottom = 1.0
	context_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	context_menu.set_script(PlayerContextMenuScript)
	context_menu_host.add_child(context_menu)

	_build_message_menu()
	_build_emoji_picker()

func open() -> void:
	visible = true
	# Same runtime anchor-collapse bug as Flea Market/Mail - force the
	# designed centered layout back explicitly.
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -300.0
	offset_top = -320.0
	offset_right = 300.0
	offset_bottom = 320.0
	_chat_pool = GameManager.get_ranked_leaderboard().filter(func(e): return not e.get("is_player", false))
	# remove_child() before queue_free(), not queue_free() alone - the
	# latter only defers to end-of-frame, so these rows were still real
	# children of message_list while the 6 new ones below got added right
	# after. If the >60 row cap in _add_message_row() happened to fire
	# during that window (after 4+ min of ambient traffic, i.e. exactly
	# when a reopen was likely), it evicted one of these stale-but-still-
	# present ghost rows while _message_rows.pop_front() popped a
	# brand-new entry instead - desyncing the two until reactions had
	# nothing valid left to attach to for the rest of the session.
	for c in message_list.get_children():
		message_list.remove_child(c)
		c.queue_free()
	_message_rows.clear()
	_recent_message_uses.clear()
	for i in range(6):
		_add_bot_message(true)
	for i in range(4):
		_add_random_bot_reaction()
	_msg_timer = 0.0
	_next_msg_delay = randf_range(2.5, 5.0)
	_reaction_timer = 0.0
	_next_reaction_delay = randf_range(1.0, 2.2)
	set_process(true)
	_scroll_to_bottom()
	GameManager.focus_first_control(self)

func _exit_tree() -> void:
	set_process(false)

func _process(delta: float) -> void:
	if not visible:
		set_process(false)
		return
	_msg_timer += delta
	if _msg_timer >= _next_msg_delay:
		_msg_timer = 0.0
		_next_msg_delay = randf_range(2.5, 6.0)
		_add_bot_message(false)

	_reaction_timer += delta
	if _reaction_timer >= _next_reaction_delay:
		_reaction_timer = 0.0
		_next_reaction_delay = randf_range(1.0, 2.8)
		# Most ticks fire one reaction, but there's a real chance of a
		# little burst landing at once - reads like several people
		# reacting to something funny in the same few seconds, instead
		# of one lonely reaction trickling in every so often.
		var burst: int = 1
		if randf() < 0.35:
			burst = randi_range(2, 3)
		for i in range(burst):
			_add_random_bot_reaction()

# ------------------------------------------------------------------
# Sending
# ------------------------------------------------------------------

func _on_chat_submitted(text: String) -> void:
	var trimmed := text.strip_edges()
	chat_input.text = ""
	if trimmed == "":
		return
	Sfx.play_menu_confirm()
	var player_entry: Dictionary = {
		"name": GameManager.player_name if GameManager.player_name != "" else "You",
		"portrait": GameManager.player_portrait_id if GameManager.player_portrait_id != "" else "portrait_1",
		"rank_full_idx": GameManager.get_rank_full_index(), "is_player": true,
		"title": "", "badges": GameManager.owned_badges, "gear": GameManager.equipped_items,
		"level": GameManager.player_level, "kills": GameManager.stat_enemies_killed,
		"deaths": GameManager.stat_deaths, "pets": GameManager.owned_pet_instances.size(),
	}
	_add_message_row(player_entry, trimmed)
	_scroll_to_bottom()

	# Other operatives are pretty likely to actually respond to you.
	if not _chat_pool.is_empty() and randf() < 0.75:
		var delay := randf_range(0.8, 2.4)
		await get_tree().create_timer(delay).timeout
		# is_instance_valid() first, always - this whole panel is a plain
		# scene child (freed on any scene change), not an autoload, so a
		# scene change during the wait above can free self before this
		# resumes. Reading `visible` on an already-freed instance is
		# itself the failing operation, not just a stale read.
		if not is_instance_valid(self) or not visible:
			return
		var replier: Dictionary = _chat_pool[randi() % _chat_pool.size()]
		var reply_text: String = REPLY_TO_PLAYER[randi() % REPLY_TO_PLAYER.size()]
		_add_message_row(replier, reply_text)
		_scroll_to_bottom()

# ------------------------------------------------------------------
# Bot chatter
# ------------------------------------------------------------------

func _add_bot_message(silent: bool) -> void:
	if _chat_pool.is_empty():
		return
	var sender: Dictionary = _chat_pool[randi() % _chat_pool.size()]
	var text: String = _roll_message(sender)
	_add_message_row(sender, text)
	if not silent:
		_scroll_to_bottom()
		_maybe_chain_reply(sender)

# With some probability, a DIFFERENT bot replies to the message that was
# just sent shortly after - short generic acknowledgments most of the
# time, so it reads like people actually talking rather than a wall of
# unrelated isolated lines. Sometimes a second reply lands on top of
# that too, so a thread occasionally reads as three people genuinely
# going back and forth instead of always capping at one ack.
func _maybe_chain_reply(previous_sender: Dictionary) -> void:
	if _chat_pool.size() < 2 or randf() >= 0.6:
		return
	var replier: Dictionary = previous_sender
	var tries := 0
	while replier.get("name", "") == previous_sender.get("name", "") and tries < 6:
		replier = _chat_pool[randi() % _chat_pool.size()]
		tries += 1
	await get_tree().create_timer(randf_range(0.9, 2.2)).timeout
	# See the matching comment in _send_message()'s reply above - this
	# panel can be freed by a scene change while suspended here.
	if not is_instance_valid(self) or not visible:
		return
	var text: String = REPLY_ACKS[randi() % REPLY_ACKS.size()]
	_add_message_row(replier, text)
	_scroll_to_bottom()

	if _chat_pool.size() >= 2 and randf() < 0.4:
		var second_replier: Dictionary = replier
		var tries2 := 0
		while second_replier.get("name", "") == replier.get("name", "") and tries2 < 6:
			second_replier = _chat_pool[randi() % _chat_pool.size()]
			tries2 += 1
		await get_tree().create_timer(randf_range(0.8, 2.0)).timeout
		if not is_instance_valid(self) or not visible:
			return
		var text2: String = REPLY_ACKS[randi() % REPLY_ACKS.size()]
		_add_message_row(second_replier, text2)
		_scroll_to_bottom()

# This bot's TRUE 1-based leaderboard placement, counting the player
# too - _chat_pool has the player filtered OUT, so a bot's own index
# there doesn't necessarily match their real placement on the board
# (it shifts depending on where the player themselves ranks in the
# middle of it). Returns -1 if not found for any reason.
func _true_rank_of(bot_name: String) -> int:
	var full_board: Array = GameManager.get_ranked_leaderboard()
	for i in range(full_board.size()):
		if str(full_board[i].get("name", "")) == bot_name:
			return i + 1
	return -1

# Picks a random bot (other than sender) that's genuinely in the top 10
# right now, with their real rank attached - empty Dictionary if none
# qualify this round. Builds the name->rank lookup from a single
# get_ranked_leaderboard() call rather than calling _true_rank_of() per
# candidate, which would rebuild and re-sort the whole board each time.
func _find_top10_candidate(sender: Dictionary) -> Dictionary:
	var full_board: Array = GameManager.get_ranked_leaderboard()
	var rank_by_name: Dictionary = {}
	for i in range(full_board.size()):
		rank_by_name[str(full_board[i].get("name", ""))] = i + 1
	var candidates: Array = []
	for e in _chat_pool:
		if e.get("name", "") == sender.get("name", ""):
			continue
		var r: int = int(rank_by_name.get(str(e.get("name", "")), -1))
		if r > 0 and r <= 10:
			var picked: Dictionary = e.duplicate()
			picked["true_rank"] = r
			candidates.append(picked)
	if candidates.is_empty():
		return {}
	return candidates[randi() % candidates.size()]

func _priority_badge_count(entry: Dictionary) -> int:
	var badges: Array = entry.get("badges", [])
	var count := 0
	for b in badges:
		if GameManager.PRIORITY_BADGE_IDS.has(b):
			count += 1
	return count

func _roll_message(sender: Dictionary) -> String:
	if randf() < 0.12:
		var pname: String = GameManager.player_name if GameManager.player_name != "" else "operative"
		var t2: String = MESSAGES_TO_PLAYER_BY_NAME[randi() % MESSAGES_TO_PLAYER_BY_NAME.size()]
		return t2.replace("{player}", pname)
	for attempt in range(8):
		var candidate: String
		var roll := randf()
		if roll < 0.08 and _chat_pool.size() > 1:
			# Only ever calls out someone GENUINELY sitting in the top 10
			# of the real leaderboard right now (not just their position
			# within this chat's own bot list, which shifts around
			# depending on where the player themselves ranks) - falls
			# back to brainrot on a round with no one that high up.
			var pick := _find_top10_candidate(sender)
			if pick.is_empty():
				candidate = MESSAGES_BRAINROT[randi() % MESSAGES_BRAINROT.size()]
			else:
				var t4: String = MESSAGES_RANK_CALLOUT[randi() % MESSAGES_RANK_CALLOUT.size()]
				candidate = t4.replace("{other}", str(pick.get("name", "someone"))).replace("{rank}", str(pick.get("true_rank", 1)))
		elif roll < 0.16:
			# First-person, about the SENDER's own real badges - never a
			# made-up count, and never fires for someone with zero.
			var pcount := _priority_badge_count(sender)
			if pcount <= 0:
				candidate = MESSAGES_BRAINROT[randi() % MESSAGES_BRAINROT.size()]
			else:
				var t5: String = MESSAGES_BADGE_FLEX[randi() % MESSAGES_BADGE_FLEX.size()]
				candidate = t5.replace("{count}", str(pcount)).replace("{plural}", "" if pcount == 1 else "s")
		elif roll < 0.28 and _chat_pool.size() > 1:
			# Mock someone with an actually lower rank than the sender,
			# when one exists, rather than a random target regardless of
			# rank - reads like a real dig instead of a non sequitur.
			var sender_rank: int = int(sender.get("rank_full_idx", 0))
			var lower_ranked: Array = _chat_pool.filter(func(e): return int(e.get("rank_full_idx", 0)) < sender_rank and e.get("name", "") != sender.get("name", ""))
			var target: Dictionary = lower_ranked[randi() % lower_ranked.size()] if not lower_ranked.is_empty() else _chat_pool[randi() % _chat_pool.size()]
			var t3: String = MESSAGES_MOCK_RANK[randi() % MESSAGES_MOCK_RANK.size()]
			candidate = t3.replace("{other}", str(target.get("name", "someone")))
		elif roll < 0.4 and _chat_pool.size() > 1:
			var other: Dictionary = sender
			var tries := 0
			while other.get("name", "") == sender.get("name", "") and tries < 6:
				other = _chat_pool[randi() % _chat_pool.size()]
				tries += 1
			var t: String = MESSAGES_WITH_OTHER[randi() % MESSAGES_WITH_OTHER.size()]
			candidate = t.replace("{other}", str(other.get("name", "someone")))
		elif roll < 0.65:
			candidate = MESSAGES_BRAINROT[randi() % MESSAGES_BRAINROT.size()]
		else:
			candidate = MESSAGES[randi() % MESSAGES.size()]
		var now_ms: int = Time.get_ticks_msec()
		var last_used: int = int(_recent_message_uses.get(candidate, -999999))
		if float(now_ms - last_used) / 1000.0 >= NO_REPEAT_SECONDS:
			_recent_message_uses[candidate] = now_ms
			return candidate
	# Every candidate we tried was on cooldown - just use the last roll anyway.
	return MESSAGES[randi() % MESSAGES.size()]

func _scroll_to_bottom() -> void:
	_do_scroll_to_bottom.call_deferred()

func _do_scroll_to_bottom() -> void:
	# One deferred call isn't always enough - a message row with wrapped
	# text sometimes needs a second layout pass before the ScrollContainer's
	# max_value reflects its real final height, which was why this sometimes
	# stopped short of the real bottom. Waiting two full process frames
	# guarantees layout has settled (still well under a frame's worth of
	# visible delay, so it still reads as instant).
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	var bar: VScrollBar = message_scroll.get_v_scroll_bar()
	if bar != null:
		message_scroll.scroll_vertical = int(bar.max_value)

# ------------------------------------------------------------------
# Message rows
# ------------------------------------------------------------------

func _add_message_row(entry: Dictionary, text: String) -> void:
	var row_data := _make_message_row(entry, text)
	message_list.add_child(row_data["outer"])
	_message_rows.append(row_data)
	while message_list.get_child_count() > 60:
		var oldest: Node = message_list.get_child(0)
		message_list.remove_child(oldest)
		oldest.queue_free()
		_message_rows.pop_front()

func _make_message_row(entry: Dictionary, text: String) -> Dictionary:
	var wrapper := PanelContainer.new()
	wrapper.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 2)

	# The equipped chat background (currently just the Tech Test Prism)
	# shows behind the player's own messages whenever it's equipped, and
	# behind any simulated operative who's a genuine Tech Test Veteran in
	# their own data (see _ensure_leaderboard_seeds() in GameManager) -
	# so checking their Info always shows the matching title and badge,
	# never just a background with nothing behind it.
	var show_bg: bool = false
	var bg_id: String = ""
	if entry.get("is_player", false):
		show_bg = GameManager.equipped_chat_background != ""
		bg_id = GameManager.equipped_chat_background
	elif entry.get("is_tech_test_veteran", false):
		show_bg = true
		bg_id = "tech_test_prism"
	if show_bg and bg_id != "":
		var bg_data: Dictionary = GameManager.CHAT_BACKGROUND_CATALOG.get(bg_id, {})
		var gradient_colors: Array = bg_data.get("gradient", [])
		if not gradient_colors.is_empty():
			var grad := Gradient.new()
			for i in range(gradient_colors.size()):
				var c: Color = gradient_colors[i]
				grad.add_point(float(i) / float(max(1, gradient_colors.size() - 1)), Color(c.r, c.g, c.b, 0.11))
			var grad_tex := GradientTexture2D.new()
			grad_tex.gradient = grad
			grad_tex.fill_from = Vector2(0, 0)
			grad_tex.fill_to = Vector2(1, 1)
			var bg_rect := TextureRect.new()
			bg_rect.texture = grad_tex
			bg_rect.stretch_mode = TextureRect.STRETCH_SCALE
			bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var rounded_mat := ShaderMaterial.new()
			rounded_mat.shader = RoundedCornersShader
			rounded_mat.set_shader_parameter("radius", 10.0)
			bg_rect.material = rounded_mat
			bg_rect.resized.connect(func(): rounded_mat.set_shader_parameter("rect_size", bg_rect.size))
			wrapper.add_child(bg_rect)

			# Particles stay to the blue/purple half of the gradient
			# (skipping the warmer orange point) so they read as a
			# distinct cool-toned sparkle rather than just echoing
			# the full background sweep.
			var particle_colors: Array = gradient_colors.slice(0, 2) if gradient_colors.size() >= 2 else gradient_colors
			var particles := Control.new()
			particles.mouse_filter = Control.MOUSE_FILTER_IGNORE
			particles.set_script(TooltipParticlesScript)
			particles.particle_color = particle_colors[0]
			particles.gradient_colors = particle_colors
			particles.intensity = 10
			wrapper.add_child(particles)

	wrapper.add_child(outer)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	outer.add_child(row)

	var rank_full_idx: int = int(entry.get("rank_full_idx", 0))
	var tier: Dictionary = GameManager.get_rank_tier(rank_full_idx)
	var tier_color: Color = tier.get("color", Color.WHITE)

	var portrait_btn := Button.new()
	portrait_btn.custom_minimum_size = Vector2(34, 34)
	portrait_btn.flat = true
	portrait_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	portrait_btn.pressed.connect(func(): context_menu.open_for(entry, get_global_mouse_position()))
	var portrait = PortraitScene.instantiate()
	portrait.anchor_right = 1.0
	portrait.anchor_bottom = 1.0
	portrait.trader_id = str(entry.get("portrait", "portrait_1"))
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_btn.add_child(portrait)
	row.add_child(portrait_btn)

	var rank_icon_box := Control.new()
	rank_icon_box.custom_minimum_size = Vector2(22, 22)
	rank_icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var rank_icon = SmallIconScene.instantiate()
	rank_icon.icon_type = tier.get("icon", "star")
	rank_icon.icon_bg = Color(tier_color.r * 0.3, tier_color.g * 0.3, tier_color.b * 0.3, 1)
	rank_icon.anchor_right = 1.0
	rank_icon.anchor_bottom = 1.0
	rank_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rank_icon.tooltip_text = GameManager.get_rank_display_name(rank_full_idx)
	rank_icon_box.add_child(rank_icon)
	row.add_child(rank_icon_box)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text_col)

	var name_btn := Button.new()
	name_btn.text = str(entry.get("name", "?")) + ("  (You)" if entry.get("is_player", false) else "")
	name_btn.flat = true
	name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	name_btn.add_theme_font_size_override("font_size", 13)
	name_btn.add_theme_color_override("font_color", tier_color)
	name_btn.add_theme_color_override("font_color_hover", tier_color.lightened(0.3))
	name_btn.pressed.connect(func(): context_menu.open_for(entry, get_global_mouse_position()))

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	name_row.add_child(name_btn)
	var rank_name_lbl := Label.new()
	rank_name_lbl.text = GameManager.get_rank_display_name(rank_full_idx)
	rank_name_lbl.add_theme_font_size_override("font_size", 10)
	rank_name_lbl.modulate = Color(tier_color.r, tier_color.g, tier_color.b, 0.75)
	name_row.add_child(rank_name_lbl)
	text_col.add_child(name_row)

	var msg_lbl := Label.new()
	msg_lbl.text = text
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg_lbl.add_theme_font_size_override("font_size", 13)
	msg_lbl.modulate = Color(1, 1, 1, 0.9)
	msg_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	msg_lbl.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	text_col.add_child(msg_lbl)

	var reactions_row := HBoxContainer.new()
	reactions_row.add_theme_constant_override("separation", 4)
	outer.add_child(reactions_row)

	var row_data := {"outer": wrapper, "reactions_row": reactions_row, "reactions": {}, "pills": {}, "entry": entry, "text": text, "player_reacted_emojis": []}

	msg_lbl.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_open_message_menu(row_data, event.global_position)
	)

	return row_data

# ------------------------------------------------------------------
# Message context menu (React) + emoji picker
# ------------------------------------------------------------------

func _build_message_menu() -> void:
	message_menu = PanelContainer.new()
	message_menu.visible = false
	message_menu.z_index = 300
	message_menu.custom_minimum_size = Vector2(110, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.09, 0.98)
	sb.border_color = Color(0.9, 0.75, 0.3, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(6)
	message_menu.add_theme_stylebox_override("panel", sb)
	var vbox := VBoxContainer.new()
	message_menu.add_child(vbox)
	var react_btn := Button.new()
	react_btn.text = "React"
	react_btn.flat = true
	react_btn.custom_minimum_size = Vector2(0, 32)
	react_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	react_btn.add_theme_font_size_override("font_size", 13)
	react_btn.pressed.connect(func():
		message_menu.visible = false
		_open_emoji_picker(_message_menu_target, message_menu.global_position)
	)
	vbox.add_child(react_btn)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.flat = true
	close_btn.custom_minimum_size = Vector2(0, 32)
	close_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	close_btn.add_theme_font_size_override("font_size", 13)
	close_btn.pressed.connect(func(): message_menu.visible = false)
	vbox.add_child(close_btn)
	context_menu_host.add_child(message_menu)

func _open_message_menu(row_data: Dictionary, click_pos: Vector2) -> void:
	_message_menu_target = row_data
	var vp := get_viewport_rect().size
	var menu_size := Vector2(110, 44)
	message_menu.global_position = Vector2(
		clamp(click_pos.x + 8.0, 0.0, max(0.0, vp.x - menu_size.x)),
		clamp(click_pos.y + 8.0, 0.0, max(0.0, vp.y - menu_size.y))
	)
	message_menu.visible = true
	GameManager.focus_first_control(message_menu)

func _build_emoji_picker() -> void:
	emoji_picker = PanelContainer.new()
	emoji_picker.visible = false
	emoji_picker.z_index = 300
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.09, 0.98)
	sb.border_color = Color(0.9, 0.75, 0.3, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(6)
	emoji_picker.add_theme_stylebox_override("panel", sb)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	emoji_picker.add_child(grid)
	for emoji in EMOJI_POOL:
		var btn := Button.new()
		btn.text = emoji
		btn.flat = true
		btn.custom_minimum_size = Vector2(34, 34)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(func():
			emoji_picker.visible = false
			if not _message_menu_target.is_empty():
				_add_reaction(_message_menu_target, emoji, true, true)
		)
		grid.add_child(btn)
	context_menu_host.add_child(emoji_picker)

func _open_emoji_picker(row_data: Dictionary, near_pos: Vector2) -> void:
	_message_menu_target = row_data
	var vp := get_viewport_rect().size
	var menu_size := Vector2(160, 90)
	emoji_picker.global_position = Vector2(
		clamp(near_pos.x + 8.0, 0.0, max(0.0, vp.x - menu_size.x)),
		clamp(near_pos.y + 8.0, 0.0, max(0.0, vp.y - menu_size.y))
	)
	emoji_picker.visible = true
	GameManager.focus_first_control(emoji_picker)

# ------------------------------------------------------------------
# Reactions
# ------------------------------------------------------------------

# Adds one to the given emoji's count on this message and pops the pill
# to draw the eye to it - same small satisfying bump Discord does on an
# increment, rather than an instant flat number change.
func _add_reaction(row_data: Dictionary, emoji: String, animate: bool, is_player: bool = false) -> void:
	if not is_instance_valid(row_data.get("outer")):
		return
	if is_player:
		var reacted_emojis: Array = row_data.get("player_reacted_emojis", [])
		if reacted_emojis.has(emoji):
			GameManager.toast_requested.emit("You've already reacted with that emoji")
			return
		reacted_emojis.append(emoji)
		row_data["player_reacted_emojis"] = reacted_emojis
	var reactions: Dictionary = row_data["reactions"]
	reactions[emoji] = int(reactions.get(emoji, 0)) + 1
	var pills: Dictionary = row_data["pills"]
	var reactions_row: HBoxContainer = row_data["reactions_row"]

	if pills.has(emoji) and is_instance_valid(pills[emoji]):
		var pill: PanelContainer = pills[emoji]
		var lbl: Label = pill.get_node("HBox/Count")
		lbl.text = str(reactions[emoji])
		if animate:
			var tw := pill.create_tween()
			tw.tween_property(pill, "scale", Vector2(1.25, 1.25), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(pill, "scale", Vector2(1.0, 1.0), 0.15)
	else:
		var pill := PanelContainer.new()
		pill.pivot_offset = Vector2(20, 12)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.15, 0.15, 0.17, 0.9)
		sb.border_color = Color(0.9, 0.75, 0.3, 0.6)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 1
		sb.content_margin_bottom = 1
		pill.add_theme_stylebox_override("panel", sb)
		var hbox := HBoxContainer.new()
		hbox.name = "HBox"
		hbox.add_theme_constant_override("separation", 3)
		pill.add_child(hbox)
		var emoji_lbl := Label.new()
		emoji_lbl.text = emoji
		emoji_lbl.add_theme_font_size_override("font_size", 11)
		hbox.add_child(emoji_lbl)
		var count_lbl := Label.new()
		count_lbl.name = "Count"
		count_lbl.text = str(reactions[emoji])
		count_lbl.add_theme_font_size_override("font_size", 11)
		count_lbl.modulate = Color(1, 1, 1, 0.85)
		hbox.add_child(count_lbl)
		reactions_row.add_child(pill)
		pills[emoji] = pill
		pill.mouse_filter = Control.MOUSE_FILTER_STOP
		pill.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		pill.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_add_reaction(row_data, emoji, true, true)
		)
		if animate:
			pill.scale = Vector2(0.3, 0.3)
			pill.modulate.a = 0.0
			var tw := pill.create_tween()
			tw.set_parallel(true)
			tw.tween_property(pill, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(pill, "modulate:a", 1.0, 0.15)

# Reactions trickle in from other operatives over real time rather than
# all landing at once - picks a random recent message and adds one
# reaction from a random emoji, same slow build-up feel as a real chat.
func _add_random_bot_reaction() -> void:
	if _message_rows.is_empty():
		return
	var recent: Array = _message_rows.slice(max(0, _message_rows.size() - 15), _message_rows.size())
	var row_data: Dictionary = recent[randi() % recent.size()]
	if not is_instance_valid(row_data.get("outer")):
		return
	var emoji: String = EMOJI_POOL[randi() % EMOJI_POOL.size()]
	_add_reaction(row_data, emoji, true)
