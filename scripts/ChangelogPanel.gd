extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		closed.emit()

# Each version lists what changed, in the style of a real changelog -
# Added/Changed/Fixed prefixes so it reads as an actual dev log rather
# than a single marketing line per version. The list had grown long
# enough to be unwieldy, so everything up through 3.51.0 got moved into
# CHANGELOG_ARCHIVE (behind its own tab) and CHANGELOG_CURRENT starts
# fresh from here - version numbers keep counting up from where the
# archive left off, this is just about keeping the visible list short.
const CHANGELOG_ARCHIVE := [
	{"version": "0.1", "title": "First Prototype", "notes": [
		"Added the core extraction loop: raid a sector, loot houses, fight raiders, extract.",
	]},
	{"version": "0.2", "title": "Gear & Progression", "notes": [
		"Added rarity tiers (Common through Mythic) affecting item stats and value.",
	]},
	{"version": "0.3", "title": "The Hideout", "notes": [
		"Added a persistent Hideout base to visit between raids.",
	]},
	{"version": "0.4", "title": "Blueprints & Lil Dirty", "notes": [
		"Added rare Blueprint drops that unlock Mythic-tier gear.",
	]},
	{"version": "0.5", "title": "Loadout Overhaul", "notes": [
		"Added a 5-slot Hotbar for the equipped weapon and consumables.",
	]},
	{"version": "0.6", "title": "Corpses & Real Players", "notes": [
		"Added searchable enemy corpses, replacing instant loot drops.",
	]},
	{"version": "0.7", "title": "Spike & the Bats", "notes": [
		"Added Spike, a boss enemy with a spinning spike aura and grenades.",
	]},
	{"version": "0.8", "title": "Contracts", "notes": [
		"Added a full 17-quest chain with unique objectives and triggers.",
	]},
	{"version": "0.9", "title": "Day & Night", "notes": [
		"Added a Raid Select screen - choose a Day or Night Raid before deploying.",
	]},
	{"version": "0.10", "title": "Vicinity", "notes": [
		"Added the Vicinity panel - a dedicated area for search results.",
	]},
	{"version": "0.11", "title": "Right-Click Menu", "notes": [
		"Added a right-click context menu for every inventory item.",
	]},
	{"version": "0.12", "title": "Safe Pockets & Rubles", "notes": [
		"Added 2 Safe Pocket slots that survive character death.",
	]},
	{"version": "0.13", "title": "Loot Bags & Crafting", "notes": [
		"Added Loot Bags - a case-opening style reward with a particle reveal.",
	]},
	{"version": "0.14", "title": "Living Economy", "notes": [
		"Added automatic Trader stock rotation every 10 minutes.",
	]},
	{"version": "0.15", "title": "Polish Pass", "notes": [
		"Fixed several UI overlap issues across the HUD.",
	]},
	{"version": "0.16", "title": "Character & Economy", "notes": [
		"Added a full Character screen: level/XP (max Level 500), lifetime stats, editable name/bio, profile pictures.",
	]},
	{"version": "0.17", "title": "Boneclock", "notes": [
		"Added a second map: Boneclock, a dead town with Skeletons, Ghosts, and a locked Gas Station.",
	]},
	{"version": "0.18", "title": "Depth Pass", "notes": [
		"Character Creation expanded: portraits, 4 Backgrounds with real starting bonuses, a bio field.",
	]},
	{"version": "0.19", "title": "Recruits", "notes": [
		"Added hireable Recruits (Clarity, Sorrow, Glenn, Big Crax) who fight alongside you in a raid.",
	]},
	{"version": "0.20", "title": "Rattles", "notes": [
		"Added Rattles, a tougher second boss guarding the Bone Clocktower in Boneclock, with 3 Bonedogs.",
	]},
	{"version": "0.21", "title": "Spectral Tide", "notes": [
		"New limited-time event: a 200-tier Battle Pass, the Souls currency, and new ghost-themed gear.",
	]},
	{"version": "0.22", "title": "The Store", "notes": [
		"Added the Store: 4 purchase packs, a Monthly Pass, permanent Double XP, and premium weapon skins.",
	]},
	{"version": "0.23", "title": "Atmosphere Pass", "notes": [
		"Added a black, dystopian drifting-particle background to Stash, Traders, Skill Tree, Settings, the Hideout stations, and more.",
	]},
	{"version": "0.23.1", "title": "Hotfix", "notes": [
		"Fixed a crash on launch caused by a missing variable declaration from a previous edit.",
	]},
	{"version": "0.23.2", "title": "Polish", "notes": [
		"Fixed the Event and Store buttons (and others) staying visible behind the Changelog, Roadmap, and Character panels.",
	]},
	{"version": "0.23.3", "title": "Store Polish", "notes": [
		"Skin previews now show a textured pattern (stripes + sheen) instead of a flat color, so they read as real skins.",
	]},
	{"version": "0.23.4", "title": "Bugfixes", "notes": [
		"Fixed the Store's Back button being pushed off-screen by overflowing content - couldn't be reached before.",
	]},
	{"version": "0.23.5", "title": "Store Back Button - Real Fix", "notes": [
		"The previous fix wasn't enough - the Monthly Pass/Double XP buttons still grew taller than expected and pushed Back off-panel again.",
	]},
	{"version": "0.23.6", "title": "Store Cards", "notes": [
		"Store pack and skin cards are no longer clickable/hoverable as a whole - only the actual Purchase button responds now.",
	]},
	{"version": "0.23.7", "title": "Hotfix", "notes": [
		"Fixed hover-sound setup code that had ended up in the wrong function, causing it to spam reconnect errors every time a Main Menu panel opened.",
	]},
	{"version": "0.24", "title": "Attachments & Layout Fixes", "notes": [
		"Attachments can now be equipped straight from your Backpack or Stash by right-clicking any weapon - no longer requires it to be on your doll first.",
	]},
	{"version": "0.25", "title": "Loot Variety", "notes": [
		"Every gear drop now rolls its stat within a range instead of a fixed number - no two drops of the same item are identical anymore.",
	]},
	{"version": "0.26", "title": "Presentation Pass", "notes": [
		"Item tooltips now show a drifting particle background - Exotic and Multiversal items get noticeably more particles.",
	]},
	{"version": "0.27", "title": "Menu Audio", "notes": [
		"Added a soft, ghostly wind hover sound to the New Event button, and a bright coin-chime hover sound to the Store button.",
	]},
	{"version": "0.28", "title": "Menu Polish", "notes": [
		"Added black dystopian-style particle hover effects to Play, Quests, Traders, Skill Tree, Hideout, Stash, Settings, and Exit.",
	]},
	{"version": "0.29", "title": "Hover Tuning", "notes": [
		"New Event hover sound is louder; Store hover sound is quieter.",
	]},
	{"version": "0.30", "title": "Part 2: Quests, Time of Day, Grenades", "notes": [
		"Added 3 new quests: Silence the Bones (kill Rattles), Soul Collector (earn 500 Souls), Favored by the Harvester (survive Wave 20 in Commune).",
	]},
	{"version": "0.31", "title": "Recruits Gated, New Weapons", "notes": [
		"Recruits are now locked behind quests: Quest 5 unlocks talking to them at the Hideout, Quest 6 unlocks bringing one on a raid.",
	]},
	{"version": "0.32", "title": "Part 3: Search Overhaul & Supply Drops", "notes": [
		"Removed the search progress bar entirely - the Vicinity panel now shows locked tiles that reveal one by one as you search, Tarkov-style.",
	]},
	{"version": "0.33", "title": "Gamble", "notes": [
		"Added the Gamble screen: buy a crate for 500 Rubles, watch it shake and burst open, and see what you got with rarity-matched particles.",
	]},
	{"version": "0.34", "title": "Bugfixes", "notes": [
		"Fixed Vicinity items not disappearing after being claimed - a leftover flag from the search rework could get stuck and block the display from refreshing.",
	]},
	{"version": "0.35", "title": "Pets", "notes": [
		"Added the Pet system: a new Pet Shop in the Hideout sells 4 pets (Rex, Whiskers, Sparky, Shadow), each granting a real passive stat bonus.",
	]},
	{"version": "0.36", "title": "High-Effort Pass", "notes": [
		"Fixed the real cause of Stash items stacking in the top-left tile: a full grid was silently defaulting new items to (0,0) instead of rejecting them.",
	]},
	{"version": "0.37", "title": "Boneclock Polish", "notes": [
		"Added 3 abandoned cars with working alarms scattered along Boneclock's roads, matching Overgrowth's atmosphere.",
	]},
	{"version": "0.38", "title": "Social (Profile)", "notes": [
		"Added a Social button and panel: your profile picture, name, level, and bio now live here instead of on Character.",
	]},
	{"version": "0.39", "title": "Audit Pass", "notes": [
		"Found and fixed one real gap while auditing: Trader shop items showed a flat pink tint for Exotic/Multiversal gear instead of the real gradient.",
	]},
	{"version": "0.40", "title": "Real Title Screen", "notes": [
		"The intro cutscene now holds on \"DEAD SECTOR\" with a blinking \"Press Any Button to Play\" prompt and waits there instead of auto-continuing.",
	]},
	{"version": "0.40.1", "title": "Hotfix", "notes": [
		"Fixed a crash on launch - a fallback loop I added for the Stash overflow fix used a pattern Godot's parser couldn't verify always returns a value.",
	]},
	{"version": "0.41", "title": "Real Fixes This Time", "notes": [
		"Gamble: found the actual bug this time - the Buy button was being disabled a split second after being re-enabled, permanently, on every opening.",
	]},
	{"version": "0.42", "title": "Cutscene Fix, Prone, Keybinds", "notes": [
		"Fixed spamming a button at launch skipping past the cutscenes entirely - input is now ignored until \"PRESS ANY BUTTON TO PLAY\" genuinely appears.",
	]},
	{"version": "0.43", "title": "Data Screen", "notes": [
		"Added the Data button and screen: three tabs covering Enemies, Collectibles, and Maps.",
	]},
	{"version": "0.44", "title": "Bloodline - The Gauntlet is Playable", "notes": [
		"Found and resumed unfinished Bloodline work - the button, progression panel, and player controller existed but nothing was actually playable until now.",
	]},
	{"version": "0.44.1", "title": "Hotfix", "notes": [
		"Fixed a crash opening the Bloodline panel - a strict-typing error where max()'s return type couldn't be inferred automatically.",
	]},
	{"version": "0.45", "title": "Justin & The Leaderboard", "notes": [
		"Added Justin at his own Decompilation Rig in the Hideout - a genuinely huge NPC (2.4x scale) surrounded by an anvil and clutter.",
	]},
	{"version": "0.46", "title": "Bloodline - All 5 Levels", "notes": [
		"Added a new enemy type: the Refuge Sniper, a ranged Gauntlet enemy that holds its ground and shoots instead of charging - first appears on Level 2.",
	]},
	{"version": "0.47", "title": "Critical Gauntlet Fixes + Polish", "notes": [
		"Fixed the Gauntlet attack not working at all - rebuilt hit detection to track enemies in range via signals instead of a timing-fragile check.",
	]},
	{"version": "0.48", "title": "Hotfix + PMC/Scav, Weather, Directional Sound", "notes": [
		"Fixed a crash on startup caused by a for-loop variable named 'name' shadowing every Node's built-in name property.",
	]},
	{"version": "0.49", "title": "Salvaged Beasts", "notes": [
		"Redesigned the top-left currency HUD - no more orange lines, more compact, with drifting ember particles behind the text.",
	]},
	{"version": "0.50", "title": "Real Assets - Round 1", "notes": [
		"Installed real fonts project-wide (Rajdhani) - every menu, label, and button in the game now uses a real typeface instead of Godot's default.",
	]},
	{"version": "0.51", "title": "Bloodline Overhaul + Bug Fixes", "notes": [
		"Removed the directional sound indicator (the red pulsing rings) entirely, per feedback - gone from the code, not just hidden.",
	]},
	{"version": "0.52", "title": "Real Assets - Round 2 + Pet Case + Store", "notes": [
		"Added the Pet Case: a lootable item that opens into a grid of every pet you own, 1 tile each - click to equip.",
	]},
	{"version": "0.53", "title": "Sound Overhaul + Bloodline Loot Polish", "notes": [
		"Fixed a real problem: 7 unrelated actions (chests, corpses, debris, barrels, gamble crates, Gauntlet loot, Justin's decipher) were all sharing one sound.",
	]},
	{"version": "0.54", "title": "Hotfix + Bloodline Sword", "notes": [
		"Fixed two GDScript shadowing errors: a sprite-animator parameter named 'texture' and a local variable both shadowed built-in engine properties.",
	]},
	{"version": "0.55", "title": "Fixed Missing Guns and Armor", "notes": [
		"Found and fixed a real regression from the player art swap a few builds back: switching to real player art had accidentally hidden the gun and armor layers.",
	]},
	{"version": "0.56", "title": "1.0 Polish Pass", "notes": [
		"Full project-wide integrity sweep ahead of 1.0: verified every save/load field round-trips correctly and caught several silent data-loss bugs.",
	]},
	{"version": "0.57", "title": "Hotfix", "notes": [
		"Fixed a strict-mode parse error in the loot bag egg-chance lookup, where an untyped Dictionary.get() call broke Godot's strict checker.",
	]},
	{"version": "0.58", "title": "Critical Hotfix - Stack Overflow", "notes": [
		"Fixed a genuine infinite recursion bug in the dynamic gun sprite update - the function accidentally called itself at the end of every run.",
	]},
	{"version": "0.59", "title": "Sfx.gd Fix + Bloodline Pause Menu", "notes": [
		"Actually fixed Sfx.gd this time - the gunshot and reload WAV files still had a metadata chunk sitting between the format and audio data, corrupting playback.",
	]},
	{"version": "0.60", "title": "Tickets as a Real Currency + Salvaged Beasts Visual Pass", "notes": [
		"Tickets are now a first-class currency alongside Rubles, Souls, and Blood Shards, usable anywhere the game already handles currency generically.",
	]},
	{"version": "1.0", "title": "1.0 RELEASED", "notes": [
		"Dead Sector is officially live.",
	]},
	{"version": "1.0.1", "title": "1.0 Badge Fix + Repositioned", "notes": [
		"Found why the 1.0 Released text wasn't showing up: a full-screen background element placed right after it in the scene was painting over it.",
	]},
	{"version": "1.0.2", "title": "Critical Fix - Vicinity Panel Unresponsive", "notes": [
		"Found and fixed a genuine ordering bug affecting every lootable container in the game - chests, corpses, debris, and floating barrels.",
	]},
	{"version": "1.0.3", "title": "Boss Fixes + Pet Drops Everywhere", "notes": [
		"Found the real cause of the oversized, one-shot-killable enemy: Spike and Rattles don't have dedicated sprite art yet, so they were falling back incorrectly.",
	]},
	{"version": "1.0.4", "title": "Data Screen Icons, Bloodline Gunplay, Positioning Fixes", "notes": [
		"Fixed a real bug in the Data screen: several enemies (the Stalker, the Raider, Ghost, Wisp, Bonedog, the Gauntlet Sniper, and both bosses) were showing the wrong icon.",
	]},
	{"version": "1.1.0", "title": "Salvaged Beasts Overhaul + Major Fixes", "notes": [
		"Found and fixed the gamble 'giant circle covering everything' bug - the gradient texture for high-rarity reveals never explicitly set its fill mode.",
	]},
	{"version": "1.2.0", "title": "Tetris Inventory Rotation, New Cursors, Menu Polish", "notes": [
		"Found a serious latent bug during this pass: GameManager.gd had the exact same variable declared twice in two different places.",
	]},
	{"version": "1.3.0", "title": "Pet Traits, My Pets Screen, Skill Tree Expansion", "notes": [
		"Corrected the Salvaged Beasts/Bloodline hover text from the previous pass - each button now reveals its own real name on hover instead of a generic label.",
	]},
	{"version": "1.4.0", "title": "Elemental Weapons, Pet Overhaul, New Keybinds", "notes": [
		"Fixed the real cause of the pet blocking your movement - it was sitting on the exact same physics collision layer as the player.",
	]},
	{"version": "1.5.0", "title": "Void Trench, More Enemies, Vicinity Overhaul", "notes": [
		"Fixed a real Vicinity bug: freshly-searched loot was being stacked along the wrong axis in a single-row-tall panel that only shows one row.",
	]},
	{"version": "1.6.0", "title": "Character Creation Overhaul, Lore Intro, Enemy Nametags", "notes": [
		"Redesigned the crosshair - black instead of white, no center dot cluttering the aim point, with small ink drips trailing off it.",
	]},
	{"version": "1.7.0", "title": "Void Trench Finished", "notes": [
		"Built out the 3 remaining Void Trench hazard types that were still missing, rounding out the map's environmental danger.",
	]},
	{"version": "1.7.1", "title": "Audit Pass - Data Sync + Held-Off Items", "notes": [
		"Updated the Void Trench description specifically, since it was still only mentioning Irradiated Puddles from before the other 3 hazards existed.",
	]},
	{"version": "1.7.2", "title": "Hotfix - Real Parse Error in InventoryTile.gd", "notes": [
		"Found a genuine bug: an earlier edit left a stray, misindented line sitting outside of any function at the bottom of InventoryTile.gd, breaking the parser.",
	]},
	{"version": "1.7.3", "title": "New Menu Cursor", "notes": [
		"Swapped the black ink-drip menu cursor for the Jolt cursor set you provided - a clean, modern white arrow, used everywhere outside of a raid.",
	]},
	{"version": "1.7.4", "title": "Crosshair Redesign, Sound Fix, Cursor Swap on Popups", "notes": [
		"Redesigned the crosshair to match the reference sent in - a white open gap-cross with four short thick dashes and no center dot.",
	]},
	{"version": "1.7.5", "title": "Trader Icon Sizing, Quest Icons, Deliver Button", "notes": [
		"Found the real cause of The Butcher's Toll (and other long-named items) looking oversized at the Wandering Trader specifically - its icon box wasn't scaling with the name.",
	]},
	{"version": "1.8.0", "title": "Bloodline Overhaul + New Contracts Screen", "notes": [
		"Fixed a real bug: Tab wasn't closing the Bloodline inventory a second time because pausing the game tree also froze the HUD's own _process() function.",
	]},
	{"version": "1.8.1", "title": "Icon Sizing Fixed for Multi-Cell Items", "notes": [
		"Found the actual cause of Butcher's Toll (and every other long weapon - rifles, shotguns, snipers, railguns) looking tiny inside its own tile: the icon wasn't scaling to the item's real cell footprint.",
	]},
	{"version": "1.8.2", "title": "Left-Click No Longer Auto-Equips or Auto-Unequips", "notes": [
		"Left-click on an item in your Stash or Backpack no longer instantly equips it - it just shows the info popup now, same as clicking anything else.",
	]},
	{"version": "1.9.0", "title": "Weapon Rework, Real Difficulty, Meaningful Armor", "notes": [
		"Item popups now close the instant your cursor leaves the item instead of sitting on screen for a couple seconds, matching what was actually asked for.",
	]},
	{"version": "1.9.1", "title": "My Pets Context Menu, Better Pet Icons, Earlier Enemy Detection", "notes": [
		"Fixed the My Pets screen the same way the Stash/Backpack were fixed - right-click no longer instantly equips a pet.",
	]},
	{"version": "1.9.2", "title": "Full Project Audit", "notes": [
		"Ran a complete technical sweep of the entire project - every script checked for balance and duplicate declarations, every scene checked for broken node paths.",
	]},
	{"version": "2.0.0", "title": "Save Wipe for This Update", "notes": [
		"Old save files won't load anymore as of this build - too much has changed underneath to keep them compatible.",
	]},
	{"version": "2.0.1", "title": "Store Rework - Rubles Only", "notes": [
		"Fixed a real warning spamming the console on every reload - a leftover unsuppressed integer division in the crosshair's dash-thickness calculation.",
	]},
	{"version": "2.0.2", "title": "Right-Click Consistency + a Real Bug Fix", "notes": [
		"Right-click on gear you have equipped now opens the same small context menu as everything else (Info/Unequip/etc.) instead of instantly unequipping it.",
	]},
	{"version": "2.1.0", "title": "Bloodline Combat Overhaul", "notes": [
		"The Bloodline boss now actually fights back - it telegraphs a windup, then fires a 3-shot spread you have to dodge, on top of its existing melee chase.",
	]},
	{"version": "2.1.1", "title": "Bloodline Visuals & Loot", "notes": [
		"Reworked the Bloodline background - darker, near-black sky band, per-spire color variance, drifting black fog patches, and low-opacity red silhouettes in the distance.",
	]},
	{"version": "2.1.2", "title": "Real Bugs: Bat/Toxic Waste, Loot Grid, Save Wipe", "notes": [
		"Found and fixed the actual cause of the 'giant green bat' bug - the Noxious Bat and Toxic Waste enemies had their sprite scale and tint swapped between each other.",
	]},
	{"version": "2.2.0", "title": "The Wandering Ghost", "notes": [
		"The drifting ghost seen in raids is now interactable - approach and press F for an encounter with the option to recruit him as a following companion.",
	]},
	{"version": "2.2.1", "title": "Hideout & Menu Polish", "notes": [
		"Added lore to Justin (his Fortnite-grinding backstory with Jay and James), plus lore for the Undertow and Lil Dirty, all now several entries deep.",
	]},
	{"version": "2.3.0", "title": "The Graveyard", "notes": [
		"Added a new map: The Graveyard - a foggy pet cemetery at midnight, with headstones, shattered angel statues, and rusted gates.",
	]},
	{"version": "2.4.0", "title": "Achievements & Leaderboard Categories", "notes": [
		"Added a full Achievements screen (new button, bottom-left above Character) with a drifting particle background - 26 achievements covering kills, loot, and more.",
	]},
	{"version": "2.4.1", "title": "Parse Error Fix + Particle Background Audit", "notes": [
		"Fixed a real parse error that broke the whole game (GameManager.gd failed to load): a loop variable from an untyped const Array had no inferable type.",
	]},
	{"version": "2.5.0", "title": "Real Art Pass", "notes": [
		"Swapped in real sprite art from the uploaded asset packs where it was a clean fit: the Sentinel now uses a proper stone golem sprite, and the Marauder got a matching upgrade.",
	]},
	{"version": "2.5.1", "title": "Startup Crash Fix", "notes": [
		"Fixed a real parse error that broke the whole game on launch (GameManager.gd failed to load): the achievements-check function had a leftover invalid return.",
	]},
	{"version": "2.5.2", "title": "Event Button Glow Fix", "notes": [
		"Fixed the Spectral Tide event button's ambient glow border drifting toward the bottom-right instead of sitting evenly around the button.",
	]},
	{"version": "2.5.3", "title": "Graveyard Shortcut Relocated", "notes": [
		"Moved the 'Enter the Graveyard' button out of the My Pets sub-screen and onto the main Salvaged Beasts screen, right above the Hatchery list.",
	]},
	{"version": "2.6.0", "title": "Social Screen Overhaul", "notes": [
		"Rebuilt the Social screen from a flat list into a proper Operative ID layout, led by a featured profile card.",
	]},
	{"version": "2.7.0", "title": "Main Menu Polish, Store Fix, Weapon Pass", "notes": [
		"Main Menu buttons were quietly using 4 different competing fonts (BlackOpsOne, Wallpoet, and two different Rajdhani weights) in full letter-spaced caps.",
	]},
	{"version": "3.0.0", "title": "Contracts Overhaul, Navigation, Bigger Stash", "notes": [
		"Fixed the Mini Games and Companions buttons' ambient glow drifting off-center - same root cause and fix as the earlier Spectral Tide fix.",
	]},
	{"version": "3.0.1", "title": "Stash Grid Flipped, Trader Screen Overhaul", "notes": [
		"Flipped the Stash grid from 20 columns x 11 rows to 11 columns x 20 rows - tall and scrollable instead of wide, freeing up space in the middle of the screen.",
	]},
	{"version": "3.0.2", "title": "Store Crop Fix, Skill Tree & Stash Polish", "notes": [
		"Fixed the Store screen getting cropped top and bottom, hiding the title and Back button - the panel was 760px tall but the game only renders at 720p.",
	]},
	{"version": "3.0.3", "title": "Title Styling Sweep", "notes": [
		"Fixed inconsistent title styling across 20+ screens: Roadmap, Changelog, Character/Stats, Quests' contact detail popup, the Gym, Lil Dirty, Workbench, and Mining.",
	]},
	{"version": "3.0.4", "title": "Leaderboard Overhaul, Sector Crop Fix, Thinner Health Bars", "notes": [
		"The Leaderboard wasn't actually reading your real stats for 2 of its 4 categories.",
	]},
	{"version": "3.0.5", "title": "Quest Reorder", "notes": [
		"Moved Echo's 'New Faces' contract to be his 2nd quest instead of his 5th, ahead of 'First Blood', so recruits become available to talk to sooner.",
	]},
	{"version": "3.1.0", "title": "Content Expansion + Real Bug Fixes", "notes": [
		"Fixed a real, systemic bug: every interactable station in the Hideout (recruits, Gym, Workbench, Bitcoin Farm, Lil Dirty, Justin, the Pet Shop) checked the wrong unlock condition.",
	]},
	{"version": "3.2.0", "title": "Flea Market, Mail, and Matchmaking Screen", "notes": [
		"Lowered the search sound effect (searching Vicinity loot) and the in-raid/Graveyard ambience tracks - all were louder than they needed to be.",
	]},
	{"version": "3.2.1", "title": "Real Mail Badge + Much Better Welcome Gift", "notes": [
		"Replaced the '(N)' text stuffed into the Mail button with a real notification badge - a small red circle in the corner showing your unread count.",
	]},
	{"version": "3.3.0", "title": "Tech Test Wrap-Up, Titles & Badges, Alpha Rewards", "notes": [
		"Buffed every quest's Rubles reward by 2.5x across all 42 contracts - they were paying out far too little for the effort.",
	]},
	{"version": "3.4.0", "title": "Lil Dirty Lore, Pet Shop, Store, New Character Model", "notes": [
		"Reworked Lil Dirty's lore from one long linear ramble into a real menu: 'Which lore would you like to know about Dirty?' with 10 distinct topics.",
	]},
	{"version": "3.5.0", "title": "Bloodline Gauntlet: Drag-to-Equip and Real Difficulty", "notes": [
		"Carried loot in the Bloodline Gauntlet can now be dragged straight onto the equipment doll to equip it, instead of only working through the right-click menu.",
	]},
	{"version": "3.5.1", "title": "Review Pass", "notes": [
		"Found and fixed two real bugs: badges on the Social screen were missing a size setup and would've rendered invisible, and the Flea Market's browse tab had a sorting bug.",
	]},
	{"version": "3.6.0", "title": "Backpack Storage, the Graveyard Key, and Midnight Bones", "notes": [
		"Added Backpack Storage: your equipped Backpack now has its own real 7x7 grid, separate from the Stash, visible right on the Stash screen.",
	]},
	{"version": "3.6.1", "title": "Full Project Audit", "notes": [
		"Did a genuinely comprehensive pass this time, not just spot checks: cross-referenced every single node path in every script against its actual scene.",
	]},
	{"version": "3.6.2", "title": "Hotfix: Social Screen Parse Error", "notes": [
		"Fixed a real parse error that broke the whole game on launch (SocialPanel.gd failed to load): the SmallIcon preload got declared twice by accident.",
	]},
	{"version": "3.6.3", "title": "Hotfix: Scene Load Failure on Startup", "notes": [
		"Found the real cause of the 'FleaMarketPanel cannot specify a parent node' error on launch: 5 recently-built scene files had a broken reference.",
	]},
	{"version": "3.7.0", "title": "Mail Redesign, Drag Previews, Quest Tracker Polish", "notes": [
		"Rebuilt Mail as a real list-and-detail screen: it now shows just subjects (with a GIFT tag for anything with an unclaimed reward), and clicking one opens the full message.",
	]},
	{"version": "3.8.0", "title": "Health Bars, Filters, Font, and a Real Bug Hunt", "notes": [
		"Moved every enemy health bar (all 12 types) further above the character so it no longer clips into the sprite, and thinned it out on top of that.",
	]},
	{"version": "3.9.0", "title": "What's New Popup, Alpha Chest, and a Sprite Rollback", "notes": [
		"Added a real 'What's New' popup - shows automatically 0.5 seconds after reaching the Main Menu the very first time, with a welcome/alpha explainer.",
	]},
	{"version": "3.9.1", "title": "Hotfix: Freeze/Crash When Navigating Menus Fast", "notes": [
		"Fixed the freeze/crash that happened when clicking Traders and then Back (or any two menu buttons) in quick succession.",
	]},
	{"version": "3.9.2", "title": "New Player Model and 3 Weapon Icons from the Top-Down Shooter Pack", "notes": [
		"Swapped the player character art for a new one built from the Top-down_shooter_asset_pack's skin sheet, plus 3 new weapon icons from the same pack.",
	]},
	{"version": "3.9.3", "title": "Hotfix: Variable Shadowing Warning on Equip Slots", "notes": [
		"Fixed the 'local variable icon is shadowing an already-declared property in the base class Button' warning shown on launch.",
	]},
	{"version": "3.9.4", "title": "Reverted Player/Weapon Art, Fixed Enemies Not Facing You", "notes": [
		"Reverted the player model and the Thorn/Flamethrower/Railgun weapon icons back to the originals from before the Top-down_shooter_asset_pack swap.",
	]},
	{"version": "3.9.5", "title": "New Title Font", "notes": [
		"Changed the DEAD SECTOR title on the Main Menu and the intro cutscene to use Galiver Sans (Bold) instead of the engine's plain fallback font.",
	]},
	{"version": "3.9.6", "title": "Removed Enemy Health Bars, Fixed Drifting Name Tags, New Player Model", "notes": [
		"Removed enemy health bars entirely (regular enemies and bosses) - name tags are now the only thing shown above an enemy.",
	]},
	{"version": "3.9.7", "title": "Removed Close-Up View, Mail Screen Icons and Claim Effects", "notes": [
		"Removed Close-Up View entirely - the toggleable zoomed-in camera mode and its keybind (V) are gone from Settings, along with the big weapon viewmodel it used.",
	]},
	{"version": "3.9.8", "title": "Big Bug/Polish Pass: Doll Slots, Flea Market, Mail Clicks, and More", "notes": [
		"Fixed the reload prompt ('Press R to reload') following your mouse around even while the Stash/Backpack (Tab) screen was open.",
	]},
	{"version": "3.9.9", "title": "Multiplayer Question, Inspect Icon Fix, 3rd Safe Pocket", "notes": [
		"On multiplayer/friends: there's genuinely nothing there yet to fix - it's real.",
	]},
	{"version": "3.10.0", "title": "Safe Pocket + Graveyard Key Interaction", "notes": [
		"Confirmed Safe Pocket contents already survive death correctly no matter how a run ends (success, death, or timing out) - all 3 paths were verified.",
	]},
	{"version": "3.10.1", "title": "Skill Points, Free Starter Pack, Alpha Rewards Overhaul", "notes": [
		"Added Skill Points - a new currency that can upgrade Skill Tree nodes as an alternative to Artifacts, earned from loot, mail, and the Battle Pass.",
	]},
	{"version": "3.11.0", "title": "Character Creation Overhaul, More Alpha Rewards, Roadmap Update", "notes": [
		"Character Creation: fixed the Face Details preview being visibly stretched out of proportion with the rest of the character.",
	]},
	{"version": "3.12.0", "title": "Dynamic Gear, Menu Music, Skill Tree Overhaul, Bloodline Pass", "notes": [
		"On the Tech Tester's Sidearm: it wasn't a Hideout bug - it just shares its art with every other Pistol, since gun appearance is keyed by weapon type, not by individual item.",
	]},
	{"version": "3.13.0", "title": "Leaderboard Overhaul, Ranked, Season Rewards", "notes": [
		"Leaderboard: added a profile picture next to every name, and expanded the roster from 28 names to 100 for more realistic depth.",
	]},
	{"version": "3.13.1", "title": "Bloodline: Quitting Loses Your Run, Extraction Gives You a Choice", "notes": [
		"Fixed Bloodline (Esc -> Exit to Main Menu, including from the death screen) keeping everything you'd picked up and equipped that run.",
	]},
	{"version": "3.13.2", "title": "Bloodline Exit - Verified, Plus One More Gap Closed", "notes": [
		"Confirmed the 3.13.1 fix is solid - Esc to Menu (including from the death screen) already correctly forfeits carried loot and equipped gear before exiting.",
	]},
	{"version": "3.13.3", "title": "Hotfix: Alpha Rewards Crash", "notes": [
		"Fixed the crash on opening Alpha Rewards - the script was looking for its reward icon grid at the wrong path, missing a folder level in between.",
	]},
	{"version": "3.14.0", "title": "Real Rank Points + a Real Post-Raid Rewards Screen", "notes": [
		"Added Rank Points: a real progression track for Ranked, separate from Level.",
	]},
	{"version": "3.14.1", "title": "Real Player Look Fixed + a Real Layering Bug", "notes": [
		"Replaced the Real Player enemy's art - it was a separate, lower-quality 40x46 placeholder sprite that didn't match the player model's actual dimensions.",
	]},
	{"version": "3.15.0", "title": "Rewards Screen Overhaul, Ranked Leaderboard, Tougher Operators", "notes": [
		"Rewards screen now shows Scav Run status, a small full loot list, and an animated Level/XP bar - both it and the Rank Points bar now fill slower so you can actually watch them.",
		"Shotgun pellets nerfed from 0.6x to 0.32x damage each - was nearly 3x a normal shot at point-blank, now a more reasonable 1.6x.",
		"Real Player operators: doubled HP, more damage, faster fire rate, a dash every 4-7 seconds, and a distinct electric-blue projectile with a particle trail.",
		"All enemies now have a 50% chance to pop a short hit reaction speech bubble when they take damage.",
		"Real Player corpses now glow softly on the ground while unlooted, and stop the moment they're actually searched.",
		"Spike and Rattles both had their HP doubled (5000->10000 and 5500->11000).",
		"Added a Ranked tab to the Leaderboard screen: top 100 standings by Rank Points, each with their real rank icon, same right-click-style context menu as the regular tabs.",
		"Top 1/2/3 Leaderboard badges are now actually granted at season's end instead of just sitting unused, and added a new badge for reaching Syndicate 1.",
		"Added 6 new achievements covering Ranked progress and Scav runs, and 3 new Store packs.",
		"Added more roads, bushes, cars, and lootable containers to both maps.",
		"Condensed the entire changelog to one line per version - same history, far less scrolling.",
	]},
	{"version": "3.15.1", "title": "Priority Badges + a Real Tech Test Veteran Title", "notes": [
		"Founder and Ranked-podium badges (Tech Test, Alpha Pioneer, Top 1/2/3, Syndicate) now get a gold pulsing border and always sort to the right end of the row - on your own Social screen and on other players' info popups alike.",
		"The Tech Test Veteran title now has its own presentation: a blue-to-purple gradient across the words, a soft glow, a thin tracing line around it, and a few small drifting particles - text stays fully readable throughout.",
	]},
	{"version": "3.15.2", "title": "Real Enemy Nametag Bug Found + Fixed, Menu Music, Hit Bubbles", "notes": [
		"Found and fixed a real, systemic bug: every typed enemy (Noxious Bat, Goblin, Marauder, Sentinel, Rift Wraith, Skeleton, Bonedog, Ghost) was reading its own nametag BEFORE the code that identifies its type had actually run, so every single one displayed as generic 'RAIDER' instead of its real name. All of them show correctly now.",
		"Noxious Bat and the enemy now named Goblin (formerly Toxic Waste) were also using broken/mismatched art - Goblin's file was an accidental byte-for-byte duplicate of the Ghost sprite. Both now correctly show their real, distinct, hand-tinted look (purple for the Bat, green for the Goblin) instead.",
		"Fixed Goblin never actually being able to unlock in the Data screen no matter how many you killed - its death code skipped the discovery call entirely.",
		"Hit-reaction speech bubbles are now Real Player operators only (not every enemy), and only ever roll once, on the first hit of a fight - not a fresh 50/50 every single hit.",
		"Main Menu music now stops the moment a raid actually starts, and resumes when you're back at the Main Menu.",
	]},
	{"version": "3.15.3", "title": "Character Bound Gear, Bubble Overlap, a Real Freed-Tween Crash Fixed", "notes": [
		"Fixed a real crash-adjacent bug: clicking Continue on the Rewards screen while the Level or Rank bar was still mid-animation could fire that animation's callback against an already-freed screen, throwing a 'Lambda capture was freed' error. Both animations are now cleanly stopped the moment you continue.",
		"Alpha/Tech Test exclusive gear (Tech Tester's Sidearm, Veteran's Plate, Early Access Visor, Founder's Boots, Alpha Pioneer's Rig, The Prototype) now stays equipped through death instead of being stripped with everything else - added a 'Character Bound' note to their Info popup and tooltip to make that explicit.",
		"Fixed Real Player hit-reaction speech bubbles rendering almost on top of their own nametag - moved further up for real clearance.",
	]},
	{"version": "3.15.4", "title": "Bloodline Button Renamed", "notes": [
		"Main Menu's Bloodline button now reads \"Dead Sector's Side Scroller\" by default instead of \"Mini Games!\" - shrunk and wrapped the font so the longer text actually fits the button (still reveals \"Bloodline\" on hover, same as before).",
	]},
	{"version": "3.15.5", "title": "Ranked Button Sparkle", "notes": [
		"Added small twinkling stars that appear and shine along the border of the Ranked button (the small gold button on Play's corner) - each fades in, holds, and fades out at a new random spot on a loop.",
	]},
	{"version": "3.15.6", "title": "Shiny Tracing Border on Alpha/Tech Test Rewards", "notes": [
		"Added a shiny tracing line that continuously loops around the border of every card on the Alpha Rewards screen, and around each reward icon on the Tech Test founder mail specifically - not applied to regular mail rewards.",
	]},
	{"version": "3.15.7", "title": "Tracing Border Extended to Stash/Backpack", "notes": [
		"Alpha/Tech Test exclusive gear now shows the same shiny tracing border wherever it actually sits in your inventory - the Stash grid, Backpack Storage, and the in-run Backpack alike - not just on the Rewards/Mail screens.",
	]},
	{"version": "3.15.8", "title": "Hotfix: Mail Reward Trace Border Was Tracing the Wrong Shape", "notes": [
		"Found the real cause of the tracing border looking way off on Mail's reward icons: the icon box wasn't locked to a fixed size, so the HBoxContainer row was stretching it taller than intended - the trace was accurately tracing that stretched shape, not the actual icon. Locked the box to a real fixed 28x28 square, and applied the same safeguard to the Alpha Rewards cards in case they had the same latent issue.",
	]},
	{"version": "3.15.9", "title": "Multiversal Gradient Opacity Lowered", "notes": [
		"Lowered the Exotic/Multiversal gradient background's opacity (was fully opaque, including a near-pure-white point) so item names actually stay readable over it - fixes the two Multiversal items on the Alpha Rewards screen plus the same gradient in the Stash/Backpack, and everywhere else this shared gradient shows up (Battle Pass, Gamble, Trader shops, and more).",
	]},
	{"version": "3.16.0", "title": "Real Fix for the Main Menu Music Glitch", "notes": [
		"Found the real cause of the music popping/glitching right after the second cutscene hands off to the Main Menu: the ambient music's audio buffer was only 0.6 seconds, and Main Menu is a genuinely heavy scene to load - the load hitch was long enough to fully drain the buffer, causing the pop. Buffer is now 1.5 seconds, and the music now keeps filling even through any paused-tree moment (like extraction/death), so both causes of the same underrun are covered. Audited the rest of the project for the same pattern (a live audio generator with a small buffer) - this was the only one.",
		"Lowered the searching sound effect further - it's only ever heard in-raid (corpses, debris, floating barrels), so this is a direct in-raid volume reduction.",
	]},
	{"version": "3.16.1", "title": "Wipe Button + This Update Wipes Saves", "notes": [
		"Added a Wipe button - small, half-opacity, right under Exit. Confirming it deletes your save completely and closes the game; open it again and you get Character Creation and every cutscene fresh, same as a brand new install, and every claimable reward (Welcome mail, Tech Test mail, Alpha Rewards) is claimable again.",
		"This update also wipes existing saves on its own (a real save-format bump, same mechanism the Wipe button uses) - since a fresh start was specifically requested, next launch starts clean without needing to touch the new button at all.",
	]},
	{"version": "3.16.2", "title": "Leaderboard Polish + a New Ranks Screen", "notes": [
		"The Leaderboard's right-click-style context menu now closes when your cursor moves off it, not just on another click.",
		"The Ranked tab now shows each player's actual point total next to their rank.",
		"Added a new Ranks button next to Rewards on the Leaderboard: a full showcase of all 18 ranks, each with its icon and roughly how many operatives actually reach it - Syndicate 1 is genuinely rare (0.001%), the lower ranks make up the bulk of the population. Highlights your own current rank.",
	]},
	{"version": "3.17.0", "title": "Title Screen Overhaul + a Lil Dirty Cameo", "notes": [
		"The \"PRESS ANY BUTTON TO PLAY\" title card now slowly, smoothly cycles its background between black and grey forever (until you press something), with the tagline/prompt text color shifting between white and black in sync so it always stays readable.",
		"The tagline now rotates through 6 different lines every 2 seconds with a smooth crossfade, instead of sitting on \"The Sector Does Not Forgive\" the whole time.",
		"Added a denser drifting particle field and a shiny tracing line around the title logo during this hold.",
		"Added a tiny Lil Dirty cameo that follows your cursor on this screen - wiggles harder the faster you move the mouse, and if you drag him into a screen edge he yelps (a blood splatter and a \"Please dont hurt me bro\" speech bubble, on a cooldown). He fades away the moment you actually press start.",
	]},
	{"version": "3.17.1", "title": "Hotfix: Lil Dirty Wasn't Rendering, Trace Border Too Big, Monster Washed Out", "notes": [
		"Found the real reason Lil Dirty never showed up at all: his polygon shapes were built with flat number lists, which only works inside .tscn resource files, not in actual GDScript code - it needs real Vector2 objects, so his whole body silently failed to build every time. Fixed, and swept every other script from this pass for the same mistake - nothing else had it.",
		"The title's tracing border was sized to its full 800x130 layout box (mostly empty padding around the actual text) instead of the text itself - now computes the real rendered text size and hugs that instead, much smaller and tighter.",
		"Fixed the prowling monster silhouette on this same title screen washing out to almost nothing (just its eye glow) at the lighter end of the new background color cycle - it was a low-alpha near-black fill, which only worked against the old always-dark background. Made it fully opaque with a bright outline so it reads clearly no matter what shade the background is at.",
	]},
	{"version": "3.17.2", "title": "Title Trace Goes Black/White + Twinkling Stars", "notes": [
		"The title's tracing border is now black/white instead of purple, and switches live with the background cycle - white when the background is dark, black when it's light - so it's always readable instead of blending in half the time.",
		"Boosted the trace's glow (wider, brighter halo pass) and added a ring of small twinkling stars around the title that follow the same black/white contrast logic.",
	]},
	{"version": "3.18.0", "title": "Meteor Shower on the Title Screen", "notes": [
		"Added a subtle, low-opacity meteor shower falling from the top of the title screen, colored black/white in sync with the background cycle like everything else there.",
		"Meteors actually collide with the real title text and the skyline's rooftops - they stop and burst into a small particle explosion right on impact instead of passing through. Disappears the moment you press start, same as the rest of this screen's extras.",
	]},
	{"version": "3.18.1", "title": "Character Creation Text Cutoffs Fixed", "notes": [
		"First attempt at fixing \"Enter the Sector\" clipping and the Silver-Tongued trait cutoff - turned out incomplete once actually re-checked against the running game.",
	]},
	{"version": "3.18.2", "title": "Hotfix: The Real Fix for Both Character Creation Cutoffs", "notes": [
		"Found the real cause of \"Enter the Sector\" clipping: the left column's fixed-height elements (title, hint, name/bio fields, button) plus the preview panel's old 500px minimum simply didn't fit within the column's actual height - no font size was involved. Freed up real space by trimming the preview panel's minimum instead.",
		"Found the real cause of the Silver-Tongued cutoff: a Button's reported minimum size doesn't automatically grow to fit word-wrapped multi-line text, so longer entries had their second line clipped by the button's own bounds regardless of autowrap being on. Increased trait button height for real headroom, fixed the same latent gap in the Particle Trail buttons (which didn't even have autowrap on), and doubled the scroll column's bottom spacer.",
	]},
	{"version": "3.19.0", "title": "Welcome Mail Rework + Real Mail Item Tooltips", "notes": [
		"Rewrote the Welcome mail: dropped the Alpha-specific language and the every-Multiversal-item grant (that text didn't match what was actually being sent, and giving out the game's rarest tier for free undercut the whole point of that rarity) - moved the Alpha thank-you framing to the Alpha Rewards screen itself, where it belongs.",
		"Renamed the 'Day One' badge to 'Early Supporter' - every player gets it from the Welcome mail, so 'Day One' was misleading. Removed 'permanently' from badge descriptions in mail text; everything you earn is already yours for good, no special caveat needed.",
		"Mail now shows the actual badge (and title, if one's attached) as a real icon in the reward row, not just something granted silently in the background.",
		"Hovering a gear/item icon in a mail's reward row now shows the same real tooltip (name, rarity, stats) as everywhere else loot shows up - not just a bare icon.",
		"Alpha Rewards screen: removed the redundant-looking 'Alpha Tester' title card (same star icon and styling as the Alpha Pioneer badge card, right next to it) - the title itself is still granted when you claim, just no longer double-shown as if it were a second badge.",
	]},
	{"version": "3.19.1", "title": "Leaderboard Context Menu Fixed for Real, Profile Pictures Now Clickable", "notes": [
		"Found the real cause of the Leaderboard's context menu opening nowhere near your cursor: it was positioning itself off the ROW's location instead of where you actually clicked. Now opens right next to your cursor - which also fixes it disappearing while you tried to move toward it, since that was really just the mouse leaving a menu that was never near it to begin with.",
		"Found the real cause of profile pictures not being clickable: the small wrapper Control around each portrait had no mouse filter set, so it defaulted to blocking clicks outright instead of passing them through to the row underneath. Fixed on every Leaderboard tab.",
	]},
	{"version": "3.19.2", "title": "Season Rewards Item Tooltips", "notes": [
		"Every reward on the Season Rewards screen can now be hovered for a real inspect-style tooltip - name, rarity, and everything else, same as loot everywhere else in the game. Closes automatically the moment your cursor leaves it, just Godot's normal tooltip behavior.",
	]},
	{"version": "3.20.0", "title": "Real Fix: The Hatchery Couldn't Actually Receive Eggs", "notes": [
		"Found the real cause of the Hatchery not working: the function that moves an egg from your Stash into the Hatchery's queue existed and worked fine, but nothing in the game actually called it - there was no button, no drag-and-drop, no path at all to trigger it. Added a real 'Deposit to Hatchery' option to the right-click menu on any egg sitting in your Stash.",
		"Salvaged Beasts tier track now shows a real icon per reward (eggs, gear, Rubles, Tickets) instead of plain text, with a rarity-accented border/background, a clear NEXT tag on the upcoming tier, and a claimed tag on every tier you've already cleared.",
	]},
	{"version": "3.20.1", "title": "Hatchery Empty-State Message Was Still Misleading", "notes": [
		"The Hatchery's egg list reads a separate 'deposited' queue, not your actual Stash - so if you had Eggs sitting in your Stash but hadn't right-clicked \"Deposit to Hatchery\" on them yet (the fix from the last update), the screen still said \"No Eggs in your Stash,\" which reads as broken even though it isn't. It now tells you exactly how many Eggs are waiting in your Stash and exactly what to do with them.",
	]},
	{"version": "3.21.0", "title": "Walkable Roads, More Road Network, Moving Cars, Wipe Button Fixed", "notes": [
		"Audited every road on both maps for collision and found none - roads were never solid to begin with. If they still feel blocking, let me know exactly where so I can track down what's actually there (likely a nearby building's wall, not the road itself).",
		"Added small stone clusters along the road network on both maps, plus a few street lights with a soft glow.",
		"Added moving cars that actually drive back and forth along two of the longer roads, each with a small trail of exhaust puffs from the back - no collision, same as every other decoration.",
		"Fixed the Wipe button actually just closing the game instead of restarting it - it now quits and automatically relaunches itself, landing right back on the very first cutscene (Character Creation, Echo's lore intro, all of it) with zero manual steps. Updated the warning text to say so, and to clarify the Welcome mail, Tech Test mail, and Alpha Rewards all become claimable again.",
	]},
	{"version": "3.21.1", "title": "Second Free Extraction on Every Map, Randomized Enemy Spawns", "notes": [
		"Added a second free extraction zone to every raid map (Overgrowth, Boneclock, Void Trench, the Graveyard), positioned opposite the existing one so there's a genuinely different option depending on where you end up.",
		"Enemies no longer spawn in the exact same spot every single raid - each one now scatters a bit from its designed position at spawn, so the map plays differently each time instead of being memorizable. Bosses are excluded, since their position is built around a dedicated arena.",
	]},
	{"version": "3.22.0", "title": "Windowed Fullscreen, Global Chat, Ambient Popups", "notes": [
		"Display Mode in Settings (and the in-raid pause menu) is now a real 3-way choice - Windowed, Fullscreen, or Windowed Fullscreen - instead of a single on/off toggle.",
		"Added Global Chat, accessible from a new button on the Social screen: a simulated live feed of other operatives partying up, arguing about loadouts, asking what Alpha Tester even means, flexing badges and titles, bragging about Rubles, calling their shot for #1 this reset, and occasionally getting into it with each other. Every name is clickable (their profile picture too) for the same Info/Add Friend/Party/Whisper/Block menu as the Leaderboard.",
		"Added small ambient popups that appear near a few buttons on the Main Menu even when you're not looking: near the Store every 20-60 seconds when someone buys a pack, near the Leaderboard whenever someone new reaches the top 3, and a tiny \"...\" near Social when a chat message lands elsewhere. All small, quiet, and easy to miss on purpose.",
	]},
	{"version": "3.23.0", "title": "In-Raid Chat Box + Speech Bubble", "notes": [
		"Press Enter mid-raid to open a small chat box on the middle-right of the screen. The moment you start typing, your character shows a \"...\" speech bubble above their head. Press Enter again to send - the box fades out over 2 seconds immediately, and your character's bubble swaps to your actual message, holds for 2 seconds, then fades over 2 seconds. Press Escape instead to cancel without sending - the \"...\" bubble fades over 2 seconds. Movement locks while typing, same as the Inventory or any other panel.",
	]},
	{"version": "3.23.1", "title": "Hotfix: Real Parse Error in the Leaderboard", "notes": [
		"Found and fixed a genuine parse error in the Leaderboard's regular (non-Ranked) tabs: a name label was declared but never actually set up, and the following lines referenced a completely different, never-declared variable - the kind of bug Godot reports as a flat \"Parse error\" with no further detail. Swept the rest of the project for the exact same pattern (declare one variable, immediately use a different undeclared one) and found nothing else like it.",
	]},
	{"version": "3.23.2", "title": "Title Screen Effects Start Instantly", "notes": [
		"The background black/grey color cycle, the particles, the title's tracing border and twinkling stars, the meteor shower, and the cursor Lil Dirty cameo all now start the instant the title screen loads, instead of waiting for the buildup animation (skyline rising, title bouncing in, tagline typing out) to finish first. The tagline's own typed-out reveal still plays uninterrupted - only the rotating quotes wait for that to finish, since starting those any earlier would talk over it.",
	]},
	{"version": "3.24.0", "title": "Hotfix: Global Chat Crash + Loot Bag Overhaul", "notes": [
		"Found and fixed the real cause of Global Chat failing to open: the script was pointing at the wrong node path for the message list (missing a folder in the path), so the whole panel failed to load. Verified every other new node path this session against its actual scene file - nothing else like it.",
		"Moved the ambient chat popup ('...') to the right of the Social button instead of above it, where it was overlapping the Changelog button.",
		"The 'sealed Loot Bag, open it?' screen now actually shows the bag - common/rare are a plain sackcloth brown, legendary and up use the real rarity color, and Mythic/Exotic/Multiversal additionally get a shimmering gradient border. Mythic items now get that same gradient treatment everywhere else in the game too, joining Exotic and Multiversal.",
		"Fixed loot bag contents running off the edge of the screen on bags with a lot of items (the Alpha Chest's 20 items were mostly invisible) - items now wrap into a proper grid instead of one ever-growing row, and the result area scrolls if there's still more than fits.",
		"Added a claim sound the moment 'All loot collected into your Backpack!' appears.",
		"Global Chat now swallows the Enter key outright while it's open, so it can never trigger the in-raid chat box or anything else listening for it.",
	]},
	{"version": "3.25.0", "title": "Global Chat: Real Text Input, Conversations, Reactions, Context Menu Fixed for Real", "notes": [
		"Found the real cause of the player-click context menu (Leaderboard, Global Chat) opening nowhere near the cursor and closing the instant you moved toward it: it was using fragile position math relative to a nested Control's own transform. Replaced it with the exact same approach the Stash's item context menu already uses correctly - absolute viewport-space positioning, and closing on a click outside the menu instead of on mouse-exit. Applied to both places that had it.",
		"Ambient popups (Store purchases, Leaderboard podium, chat pings) no longer appear while Social or Global Chat is open - they were showing up over/behind those screens.",
		"Added a real chat box at the bottom of Global Chat, above the Close button - click it, type, press Enter to send, and your message shows up in the chat under your own name and rank. Other operatives reply to you about 75% of the time.",
		"Global Chat now actually reads like people talking to each other - bots sometimes reply directly to whatever the last message said, not just posting unrelated lines into the void. The same message won't repeat within about a minute of real time.",
		"Added message reactions: left-click any message for a small \"React\" menu, pick an emoji from the picker, and it shows up as a little pill under the message with a count that pops on every increment - other operatives react to messages on their own over time too, same gradual build-up as a real chat instead of landing all at once.",
	]},
	{"version": "3.26.0", "title": "Ambient Popups Fully Scoped, Flea Market Overhaul", "notes": [
		"Ambient popups (Store, Leaderboard, chat) now check every panel on the Main Menu, not just Social/Global Chat - they were still showing up over the Flea Market and anywhere else too.",
		"The chat popup now follows you: on the raw Main Menu it appears by Social like before, but once Social is open it relocates to the Global Chat button inside it instead of vanishing behind the panel. Whichever button it lands on gives a small wiggle when it appears.",
		"Flea Market listings no longer say \"selling in ~X\" - they show a real ticking \"Expires in HH:MM\" countdown instead. Under the hood, listings now have a genuine 75% chance to sell (at a random point across a real 24-hour window) and a 25% chance to actually expire unsold and mail the item back - laying real groundwork for this to become an actual multiplayer market later instead of a guaranteed sale every time.",
		"Browse Market now has a Sort button (by rarity) and a gear-type filter row (Weapon, Chestplate, Helmet, Boots, Backpack, Tactical Accessory, Pet Eggs) - sorting works together with an active filter, not just on the unfiltered list.",
	]},
	{"version": "3.27.0", "title": "Global Chat Polish + Ranked Level Gate", "notes": [
		"Fixed Global Chat sometimes not scrolling down fast enough when a new message landed - it now waits for layout to actually finish settling before scrolling, instead of assuming one frame was always enough.",
		"Global Chat feels more alive: bots reply to each other roughly half the time now (was about a third), and they'll occasionally address you by name unprompted instead of only replying after you speak.",
		"Reaction pills under a message are now clickable themselves - click an existing one to add another reaction to it, same as picking it fresh from the emoji picker.",
		"The message React menu now stays open until you actually pick React or hit the new Close option, instead of closing the moment your cursor left it.",
		"The Ranked button was never actually gated behind Level 5 like intended - it's now visibly muted with a tooltip until you hit Level 5, and clicking it early explains the requirement instead of just letting you in.",
		"Moved the Store popup closer to the Store button so it reads more clearly as coming from it.",
	]},
	{"version": "3.28.0", "title": "Slower Leaderboards, New Names, Hideout Music Off, More Global Chat", "notes": [
		"Found the real cause of ambient popups still being visible after opening Changelog or Roadmap: the suppression check only ran once, right when a popup started - if you opened a panel while one was already mid-animation, it just kept playing out regardless. It now checks continuously and fades out early the instant a panel opens over it.",
		"Wiping your save now also explicitly clears the Leaderboard's rival stats (on top of the fresh restart already doing this naturally) - a real guarantee, not just relying on the restart.",
		"Leaderboard and Ranked scores were quietly drifting upward on every single screen refresh, popup check, or Global Chat open, which added up fast. Rival stats now only update at most once every 45 real seconds, with smaller nudges each time - climbs at a normal pace now instead of visibly racing upward.",
		"Renamed every rival name across the Leaderboard and Global Chat to actual gamertag-style usernames, including a few that reference the game's own NPCs and dev.",
		"Global Chat now talks about Data screen completion, events, Bloodline Gauntlet wave records, feature requests aimed at the dev, and generally hypes the dev up.",
		"Menu music now stops the moment you enter the Hideout, and resumes automatically when you head back to the Main Menu.",
		"Locked the Mail claim button to a real fixed size so it can't stretch or shrink in any layout context.",
	]},
	{"version": "3.28.1", "title": "Hotfix: Open Loot Bag Was Only Half-Fixed", "notes": [
		"Found the real cause of the Loot Bag preview breaking with a wall of \"Node not found\" errors specifically from the Stash: the sealed-bag redesign a few versions back only got applied to the copy of this screen inside the in-raid HUD - the Stash has its own separate copy of the exact same panel, still on the old structure. Applied the identical fix there too and verified both copies now match.",
		"Cleaned up a harmless but noisy \"integer division\" warning from the Flea Market's countdown timer.",
	]},
	{"version": "3.28.2", "title": "Hotfix: Escape From Stash Always Went to the Main Menu", "notes": [
		"Found the real cause: Tab already correctly remembered where you opened the Stash from (Main Menu or the Hideout) and returned you there, but Escape was hardcoded to always go straight to the Main Menu regardless. Escape now uses the exact same tracked return point as Tab - opening the Stash from the Hideout and hitting Escape takes you back to the Hideout, right where you left off.",
	]},
	{"version": "3.29.0", "title": "Global Chat: Reaction Limits, Livelier Reactions, Visible Ranks, Rank Clowning", "notes": [
		"You can now only react to a given message once - picking React (or clicking an existing reaction pill) after that just lets you know you've already reacted instead of stacking more.",
		"Reactions land faster and sometimes arrive in little bursts of 2-3 at once, and a handful land immediately when you open the chat instead of it starting completely empty - reads a lot livelier.",
		"Everyone's actual rank name now shows next to their username in the message list, not just as a tooltip on the small rank icon.",
		"People in chat now clown on each other over rank - and specifically target someone with a genuinely lower rank than the person talking, not just a random name.",
	]},
	{"version": "3.30.0", "title": "Mail Layout Fixed for Real + Random Social Mail", "notes": [
		"Found the real cause of the Claim button landing in a different spot depending on the mail: the reward icons and \"Attached:\" text lived in the same fixed row as the button, so a mail with a lot of rewards (like the Tech Test founder mail) made that row taller and pushed the button around. Moved the icons/text into the scrollable body area and gave the Claim button its own dedicated row - it now sits in the exact same spot for every mail, no matter how much is attached.",
		"You'll now occasionally get mail from a random operative out of nowhere - asking to party up, LFG, wanting to link up on Discord and VC, or asking for gear/build advice. Purely social, no rewards attached, roughly every 60-120 real minutes.",
	]},
	{"version": "3.30.1", "title": "Global Chat Scrollbar Updates Faster", "notes": [
		"Global Chat now snaps to the bottom on a deferred call instead of waiting two full frames - resolves within the same frame right after layout settles, so new messages and reactions land at the bottom noticeably faster.",
	]},
	{"version": "3.30.2", "title": "Reaction Limit Is Now Per-Emoji", "notes": [
		"Changed the reaction limit from one reaction total per message to one per emoji per message - you can now react to the same message with several different emojis, just not stack the same one over and over.",
	]},
	{"version": "3.30.3", "title": "React Menu Closes on Click-Away Again", "notes": [
		"The message React menu now closes when you click off of it, on top of the React and Close options already there.",
	]},
	{"version": "3.31.0", "title": "Global Chat Gets a Brainrot Injection", "notes": [
		"Added a whole new pool of pure Gen Z brainrot chatter to Global Chat (sigma, gyatt, ohio, fanum tax, the rizzler, and more) mixed in alongside the regular gameplay chat, plus more slang sprinkled into the quick acknowledgment replies.",
	]},
	{"version": "3.32.0", "title": "Real Rebindable Keybinds + a Tech Test Chat Background", "notes": [
		"Open Chat and Inventory/Stash are now real rebindable keybinds in Settings (defaulting to Enter and Tab), the same rebinding system Interact and Prone already use - rewrote the underlying input handling for both while I was in there, which should also resolve Enter not registering to open chat for some people.",
		"Added a Tech Test Prism chat background - a shifting gradient particle backdrop behind your own Global Chat messages, gated behind actually holding the Tech Test Veteran title. Equip it from a new button on the Social screen.",
	]},
	{"version": "3.33.0", "title": "Weapons & Keys Database, Bigger Flea Market", "notes": [
		"Added a Weapons tab to the Data screen - every gun in the game, one entry each (no duplicate rarity variants), with its real icon, full stats, and a right-click Inspect popup showing a close-up, the description, and a preview of what its projectile actually looks like.",
		"Added a Keys tab right next to it, covering every door key in the game the same way.",
		"Every tab on the Data screen - Enemies, Collectibles, Maps, Pets, Contracts, and Traders - can now be right-clicked for that same Inspect popup, not just Weapons and Keys.",
		"Added 100 new items into circulation on the Flea Market's other-player listings, and gave sellers real pricing quirks - most list fairly, some panic-sell for a steal, a few price like they think it's a Multiversal drop.",
		"Ranked now plays a sword-swing sting on hover instead of the standard coin chime, so it actually sounds like the door into PvP.",
		"Gave the Global Chat button on the Social screen a real visible outline - it was using no button styling at all before and was easy to miss.",
		"Enlarged the Changelog panel and tightened its row spacing so noticeably more entries are visible on screen at once, and cleaned up 77 older entries that had been left mid-sentence by a previous editing pass.",
		"Removed the 'Meaningful Traits' entry from the Roadmap's Live Now section now that it's just part of the game rather than a recent addition.",
	]},
	{"version": "3.33.1", "title": "Flea Market Variety Fix + Skill Tree Drag Finally Works", "notes": [
		"Fixed the Flea Market only ever showing a couple dozen listings with almost no Helmets or Backpacks: the new items from 3.33.0 had two armor slots mislabeled internally, which hid them from those categories, and the pool was too weapon-heavy on top of that. Rebalanced it to an even ~45 items per gear category and raised the live listing count so every category (Weapon, Chestplate, Helmet, Boots, Backpack, Tactical Accessory) shows around 30 at once.",
		"Fixed the Skill Tree not being draggable - the pan-on-drag code was already written, it just never received the click because the canvas area was silently swallowing every mouse press before it got there. Hold left or right click and drag now actually pans the tree around.",
	]},
	{"version": "3.33.2", "title": "Chat Keybind Fix + Editor Warnings Cleaned Up", "notes": [
		"Fixed the Open Chat keybind (Enter by default) - the same press that opened the chat box could also get read by the box itself as an immediate Enter-to-submit a moment later, sending nothing and closing it again before you got a chance to type. It now ignores that false trigger.",
		"Fixed Global Chat's scroll-to-bottom sometimes stopping short of the real bottom - it was reading the scrollbar's height one layout pass too early. Now waits for layout to fully settle first, so it reliably lands at the true bottom every time, still effectively instant.",
		"Some other operatives in Global Chat now also show the Tech Test Prism background behind their messages, not just yours if you have it equipped - and its opacity is now half of what it was, so it reads as a subtle accent instead of a loud background.",
		"Cleaned up two engine warnings that were showing up on script reload: a local variable was accidentally named the same as a built-in engine function, and a grid-row calculation was missing the annotation that tells the engine its integer math is intentional.",
	]},
	{"version": "3.33.3", "title": "Message Menu Click-Away Fix + Badge Order", "notes": [
		"Fixed the React/Close menu on a Global Chat message not closing when you clicked away from it - clicking almost anything else (like another message) was silently swallowing that click before it ever reached the code that closes the menu. Now closes reliably no matter what you click, the same way the username context menu already did.",
		"Pulsing badges (Tech Test Veteran, Alpha Pioneer, Leaderboard podium finishes, Peak of the Sector) now sort to the front of the badge row instead of the back, everywhere badges are shown.",
	]},
	{"version": "3.33.4", "title": "Chat Background Polish", "notes": [
		"Fixed operatives shown with the Tech Test Prism chat background not actually having the Tech Test Veteran title or badge if you checked their Info - it was an unrelated random roll before. It's now tied to the same real flag, so the background and their profile always match.",
		"The chat background's corners are now smoothly rounded instead of a hard rectangle.",
		"Its particles are now blue and purple only, instead of also carrying the warmer orange tone from the background gradient.",
	]},
	{"version": "3.34.0", "title": "Skill Tree Drag + Chat Keybind, Actually Fixed This Time + Auto-Deposit Eggs", "notes": [
		"Found the real remaining blocker on the Skill Tree: its own VBox container was still swallowing the click one level above the canvas area, even after last update's fix to the canvas itself. Left or right click and drag now genuinely pans the tree.",
		"Rebuilt the Open Chat keybind from a polling check to a direct key-press event, the same reliable approach already used for Inventory - the old version's extra conditions could quietly get stuck and block it from ever opening. Enter now reliably opens a small chat box on the right side of the screen, vertically centered, ready to type in.",
		"Eggs no longer sit in your Stash waiting to be manually deposited - any Egg you pick up now goes straight to the Hatchery automatically, ready to click Hatch on the spot. Existing Eggs already sitting in a Stash from before this update get swept over automatically too.",
	]},
	{"version": "3.35.0", "title": "Real Fix for Layout Glitches, Ammo, Divine Rarity, and a Lot More", "notes": [
		"Found the real cause of the Flea Market, Alpha Rewards, Mail, and Global Chat screens rendering wrong (sometimes pinned to a corner, sometimes stretched) for some players but not others: the project never explicitly set an aspect ratio to preserve, so any window that wasn't exactly the same shape as the game's design resolution got stretched unevenly - which is exactly why it only ever showed up in an exported build and never inside the editor's own game window. Locked it to always preserve the correct shape now, letterboxing instead of distorting.",
		"Added a Weapons tab's worth of detail to item tooltips and the right-click Info popup: full stats (including a second stat if the item has one), what a weapon's projectile actually does (poison/chill/pierce/burn/spread), a callout when a weapon is rare enough to fire a multi-shot burst, and the item's real description text where one exists - not just a generic category blurb.",
		"Trader Shop and Flea Market items never had a hover tooltip at all before - they do now, matching the Stash.",
		"Enemies now fire a 3-shot burst instead of a single round, and hit harder - both bumped up along with a straight increase to enemy HP across the board.",
		"Halved all weapon damage output (Skill Tree, Hideout, and pet damage bonuses are untouched - just the guns themselves).",
		"Extraction now grants noticeably more XP, and Night Raids grant 50% more on top of that.",
		"Supply Drop crates now guarantee a Mythic-tier weapon (was a single fixed Epic rifle) with its type randomized for variety.",
		"Fixed Spike's (and Rattles') nametag showing the generic 'RAIDER' label instead of their real name - a setup-order bug that also meant their spawn position was getting the same random jitter regular Raiders get, which their fixed boss arenas were never built to account for.",
		"Grenades no longer sit around after exploding, and the explosion itself is a real event now - a bright flash, a burst of fire-colored debris particles, and a couple of hanging smoke puffs, instead of just a single fading ring.",
		"Fixed Multiversal items sinking to the BOTTOM of a sorted Stash instead of the top - they were missing from the sort order entirely, which silently treated them as the lowest priority there is.",
		"Added Divine - a new rarity above Multiversal, a 0.01% roll from the Undertow's crates. 5 Divine items now exist (3 weapons, 2 armor pieces), each built around the flashiest projectile behavior already in the game (piercing, chaining, or the Alpha Cannon's sparkle trail) rather than just being a bigger number.",
		"Added a real Ammo system: Light, Medium, and Heavy, with each weapon type pulling from the matching pool (pistols/Thorns use Light; rifles/shotguns use Medium; snipers/railguns/flamethrowers/the Alpha Cannon use Heavy). Reserve ammo is now persistent per type instead of resetting to full every time you switch weapons, and running dry no longer means you're done shooting for the raid - Light/Medium/Heavy Ammo now drops from both enemies and containers, used straight from the Hotbar like a heal item.",
		"Added a hit indicator - a red vignette pulse at the screen edges whenever you take damage, regardless of what's open. This was the actual fix needed for not being able to tell you're getting shot while in the Inventory/Stash screen, since the normal health bar sits in the world and is completely hidden behind that panel.",
		"Leaderboard category labels now say '(Season)' where they mean season-relative progress, not lifetime totals - this was never a bug (the Stats screen's lifetime kill count and the Leaderboard's seasonal kill count are two different, correctly-tracked numbers), just an unlabeled distinction that read as broken.",
	]},
	{"version": "3.36.0", "title": "Radiation Fix, Smarter Enemies, Divine Items Now Spin", "notes": [
		"Fixed Radiation Clouds not dealing damage - they were being repositioned (for the drift animation) from a per-frame visual update instead of the physics tick, which was desyncing the actual collision detection against the player. Clouds are also much bigger now, genuinely wander around instead of just wobbling in place, and have a real particle effect instead of just a plain colored shape.",
		"Bushes now only hide you while you're actually being quiet - firing your gun from inside one gives away your position just like it should, instead of bushes granting unconditional stealth even while shooting.",
		"Fixed enemies/bosses sometimes shooting straight into a wall or fence at point-blank range: their line-of-sight check was measuring from their body's center, but the bullet actually fires from the gun muzzle, which swings to a different spot as they aim - so a shot could get 'confirmed' as clear and then immediately clip the fence it swung behind. Checked from the muzzle now, so what they check matches what they actually fire.",
		"Confirmed Rattles and Midnight Bones are both genuinely present in Boneclock - Midnight Bones specifically only appears on a Night raid there by design, and Rattles' spawn position bug from a couple updates back (the same is_boss ordering issue that broke Spike's nametag) is already fixed. Also went through Void Trench end to end - Pulse Spires, Spore Clouds, Irradiated Puddles, Unstable Rifts, Rift Wraiths, Marauders, and all 3 named areas (Neon Plaza, the Research Bio-Dome, the Smuggling Bay) are all there and populated.",
		"Multiversal, Divine, and Alpha/Tech Test exclusive item icons now slowly rotate a full 360 wherever they show up - the Stash, your equipped gear, and Alpha Rewards.",
		"Fixed the Alpha Rewards screen's shimmering item border covering the entire card instead of just hugging the item icon like it does everywhere else (the Stash, Traders, Flea Market, and so on) - it's sized to the actual icon now.",
	]},
	{"version": "3.36.1", "title": "Hotfix", "notes": [
		"Fixed a crash opening Alpha Rewards - the last update's border-sizing fix accidentally deleted the line that actually creates the badge icon, leaving the code right after it referencing something that no longer existed.",
	]},
	{"version": "3.37.0", "title": "Real Weapon/Armor Detail, Tween Warnings Cleaned Up", "notes": [
		"The weapon detail added a couple updates back only actually covered a handful of weapon types - Pistols and Rifles (the two most common ones you'll actually find) fell through to nothing, and Armor never got any equivalent detail at all. Every weapon type and every armor slot now has a real one-line description on both hover and the right-click Info popup, not just the rarer weapon types.",
		"Fixed a real bug behind the 'Infinite loop detected' / 'Lambda capture was freed' warnings some of you were seeing: several pulsing glow/icon animations were bound to a container that stays alive across refreshes, while actually animating a child icon that gets replaced and freed on that same refresh - so the old animation kept running against something that no longer existed. Every looping animation in the game (badges, pet icons, corpse glow, menu flicker effects) is now correctly tied to the exact thing it's animating, so it dies cleanly instead of running against a freed node.",
	]},
	{"version": "3.38.0", "title": "Enter the Gauntlet & Commune Now Demand Attention", "notes": [
		"The Enter the Gauntlet and Commune buttons now have a red tracing line running around their border, a slow breathing pulse, and a drifting particle aura around them - hard to miss, the way a button that starts a real event should be.",
	]},
	{"version": "3.38.1", "title": "The Real Tooltip Sizing Fix", "notes": [
		"Found the actual cause of the oversized item tooltip with a big dead area at the bottom: Godot sizes the tooltip popup before the tooltip's own text has actually been laid out, so it couldn't tell yet how tall the new weapon/armor description text would end up being once word-wrapped, and fell back to reserving way more room than needed. The tooltip now calculates its own real height from its actual content as it's built and hands that to Godot directly - a short item's tooltip is noticeably more compact than a long one's now, instead of every tooltip reserving the same oversized block regardless of what's actually in it.",
	]},
	{"version": "3.38.2", "title": "Hotfix: Export-Blocking Scene Error", "notes": [
		"Fixed the 'incoming node's name clashes with StreetLight1' errors blocking export - Overgrowth had two completely separate sets of streetlights (an older hand-built one and a newer prefab-based one) that ended up using the exact same names. Renamed the older set so there's no collision - nothing was deleted, both sets of streetlights are still there. Checked every other map for the same issue and this was the only one.",
	]},
	{"version": "3.38.3", "title": "Export Now Produces One Self-Contained File", "notes": [
		"Likely found the real reason a friend testing an exported build kept seeing old bugs that were already fixed on your end: the export settings were producing two separate files (a .exe and a matching .pck with the actual game data) instead of one - if only the .exe ever got resent without also replacing the .pck next to it, the game would keep loading old data no matter how many times the .exe itself changed. Exports now embed everything into a single .exe, so there's no second file to forget.",
	]},
	{"version": "3.38.4", "title": "No More Black Bars in Fullscreen/Windowed Fullscreen", "notes": [
		"Fixed black bars showing up top and bottom in Fullscreen and Windowed Fullscreen - the aspect setting from a couple updates back (which fixed the stretched/distorted layout bug) locked the game to its exact original shape and letterboxed anything extra instead of filling it. Switched to a mode that still keeps everything correctly proportioned - no more distortion - but actually extends to fill the screen instead of leaving black space.",
	]},
	{"version": "3.39.0", "title": "Goblin/Bat Icons, More Real Players, Double-Click to Equip", "notes": [
		"Fixed the Goblin sharing its Data panel icon with the Noxious Bat (both were using a placeholder gas mask icon) - Goblin now has its own green goblin-head icon, Noxious Bat has its own bat-silhouette icon. Checked the rest of the Data panel for the same issue - the only other shared icons found (Raider/Marauder, and Spike/Rattles/Refuge Warden) are intentional archetype icons, not bugs.",
		"Fixed the equip doll showing an oversized colored background behind an equipped item instead of a normal border matching the icon - equip slots now clip their contents so nothing can render outside the slot's actual box.",
		"More Real Players out in the field: Overgrowth went from 2 to 4, and Void Trench has its first one (also fixed a bug where a Real Player Marauder would immediately get recolored back to a normal Marauder right after spawning, undoing the whole point).",
		"Eased enemy damage back down slightly - between the HP/damage increase and the 3-shot burst added at the same time, enemies ended up landing more total damage than intended. HP and the burst are untouched, just the per-hit damage.",
		"Double-click any piece of gear to equip it instantly - works in the Stash, the in-raid Backpack, and Vicinity, since they all share the same tile code under the hood.",
	]},
	{"version": "3.40.0", "title": "Rose, Draggable Windows, and a Smaller Hit Flash", "notes": [
		"The hit flash is noticeably smaller now - a thinner ring right at the screen edges instead of creeping halfway across the view - but bumped up in intensity so it's still an unmistakable 'you got hit' cue.",
		"Re-verified Global Chat, Feedback, What's New, Alpha Rewards, Ranks, and Rewards - all five are already centered in the source code, and a full project-wide scan turned up zero panels anywhere with a positioning bug. If it's still showing top-left, it means the running .exe predates the centering and single-file export fixes from a couple updates back - a completely fresh export should resolve it for good.",
		"Every popup window in the game (Stash, Traders, Flea Market, Leaderboard, Social, Global Chat, Mail, Roadmap, Changelog, Alpha Rewards, and everywhere else with a close button) can now be dragged around by clicking and holding anywhere on its background - not its buttons or list items, just the empty space and borders. Context menus were deliberately left out of this, since those are meant to be quick and disposable.",
		"Added Rose to the Hideout - pink top, brown hair, over by the west side. Talk to her and she'll go off about whatever new bag she's buying, boba, League (she mains support), Nessa Barrett, or her plushie collection - never the same thing twice in a row.",
		"Your own row on the Leaderboard has a much stronger highlight now - a solid gold background and a thicker border instead of a subtle tint - so it actually stands out while scrolling through a long list instead of blending in.",
	]},
	{"version": "3.41.0", "title": "Tags, Bigger Tiles, and a Real Double-Click Fix", "notes": [
		"Fixed double-click to equip/unequip for real this time - it was relying on Godot's own double-click detection, which doesn't fire reliably on anything that also supports dragging (which every item tile does). Rebuilt it to track clicks manually instead, and added the equivalent for equipped gear on the doll - double-click now unequips straight back to wherever it belongs.",
		"Fixed the 360 spin on Multiversal/Divine/Alpha/Tech Test icons resetting every time you dragged an item - dragging triggers a full grid rebuild elsewhere (every tile gets destroyed and recreated), so a fresh icon always started unrotated. Spin is now driven off the clock instead of counting up per-instance, so a recreated icon picks up exactly where it should be.",
		"Loot Bags and Pet Cases now show a small marker badge in the corner wherever they appear (Stash, Backpack, Vicinity) so they're distinguishable from regular gear at a glance.",
		"Added a Tag system for cases - right-click a Loot Bag or Pet Case, choose Tag, name it and pick a color, and that label shows in small letters right on the icon everywhere it appears.",
		"Every inventory tile (Stash, in-raid Backpack, Backpack Storage, Vicinity) is bigger now, same tile counts as before - scrolling picks up the slack anywhere a grid no longer fits in view.",
		"The Alpha/Tech Test tracing border was only ever showing up in the Stash grid, never on the equip doll - added it there too, both out-of-raid and in-raid.",
		"Stash Expansion now adds 2 rows per level instead of 1 (to both the Stash and the in-raid Backpack, since they share the upgrade) - noticeably more space per point spent.",
		"Fixed the Noxious Bat rendering as a flat yellow blob in the Data panel - its icon was using whatever tint the screen happens to apply (gold, in that panel), same mistake the Goblin's icon avoided by having its own fixed color. Bat now always renders in its own dark slate tone, the same way the Goblin always renders green. Scanned the rest of the Data panel for the same issue and found nothing else affected.",
		"Collectibles and Maps now show real icons in the Data panel instead of a flat color dot (Collectibles) or nothing at all (Maps) - each of the 4 maps has its own new icon.",
	]},
	{"version": "3.42.0", "title": "Rose: Plushies, Lore, and a Bigger Hideout", "notes": [
		"Expanded the Hideout and moved Rose out to the west side, well clear of the middle.",
		"Rose now properly introduces herself, and has two real things to do: Give Plushie and Lore.",
		"Added Plushies - a new universal drop, common from any enemy on any map. Bring one to Rose and she'll turn it into a real pet with a guaranteed Plushie Buff (excellent stats) - added 2 new Plushie-exclusive pets (Cuddles, Bunbun) on top of the usual pool, all with their own rarities. Handing one over shows a proper reveal - particles, a claim sound, and a popup telling you exactly what she made. Needs an actual Plushie sitting in your Stash or Backpack Storage to work.",
		"Plushie-buffed pets are visually distinct wherever they show up (the equip doll, My Pets, their Info popup) - a tracing border and a drifting particle aura, both colored to match the pet itself rather than a fixed rarity color.",
		"Added Lore to Rose - 5 topics (bags, boba, League, Nessa Barrett, plushies), each a proper in-depth ramble in her own voice, with her portrait alongside it.",
		"Ammo and Plushie drops are both genuinely common now from enemies and containers.",
		"Radiation Clouds deal twice the damage they did before.",
		"Commune's tracing border now matches its actual text color (a green/teal) instead of red.",
	]},
	{"version": "3.43.0", "title": "Real Double-Click Fix, Edge-Only Dragging", "notes": [
		"Found the actual cause of the double-click weirdness (clicks doing nothing, then a batch of them suddenly all equipping at once after an unrelated drag): Godot treats almost any mouse movement during a click - including the tiny natural tremor from just clicking a mouse - as the start of a drag attempt, which was quietly hijacking click and double-click detection and leaving Godot's own drag state stuck until a real drag-and-drop somewhere else cleared it. Fixed by requiring a real minimum distance before a drag is allowed to start at all, in both the inventory grid and the equip doll.",
		"Clicking an equipped item on the doll no longer opens the Info window - that's now only available through the right-click context menu's Info option, same as everywhere else.",
		"Your row on the Leaderboard now auto-scrolls into view when the list opens, so the highlight is actually visible instead of possibly sitting off-screen in a long list.",
		"Rebuilt window dragging entirely - every draggable window (Mail, Global Chat, Leaderboard and its Ranks/Rewards windows, Stash, Traders, Flea Market, Alpha Rewards, Feedback, What's New, Roadmap, Changelog, Character, Achievements, and everywhere else with a close button) now only drags from a thin black border right at the edge of the window, never the middle - clicking a button or list item never has to compete with dragging again. The border itself is the visual indicator - if you see the black line, that's exactly where you can click and hold.",
		"Rose's opening line now actually mentions the Plushie system - that she'll turn one into a real, equippable pet you can take with you into a raid.",
	]},
	{"version": "3.44.0", "title": "Real Shooting-Direction Fix, More Ammo, Bigger Mags", "notes": [
		"Fixed shooting backwards when the cursor is close to your character - bullet direction was being calculated from the muzzle's position (which sits some distance forward of you along the barrel) to the cursor, so whenever the cursor was closer to you than that forward offset, the math could point the other way entirely, firing opposite of where you were actually aiming. Now driven directly from the gun's own aim rotation, which doesn't have this problem regardless of cursor distance. Fixed the identical bug on enemies too, since they had the exact same math.",
		"Bigger magazines across every weapon (roughly 50% more per mag), more reserve ammo at the start of a raid, and more ammo per pickup.",
		"Ammo and Plushies are both now part of the Battle Pass tier reward rotation, not just raid drops.",
		"Added Ammo Crates (3 sizes) and Rose's Plushie Pack (3 sizes) to the Store.",
		"Removed a line from Rose's Bag Situation lore that referenced her nan.",
	]},
	{"version": "3.44.1", "title": "Hotfix: Crash, Dragging, and Double-Click", "notes": [
		"Fixed a real crash when interacting with the Pet Case - a Plushie-buffed pet's aura effect was leaving a stale connection behind on the equip doll slot every time it refreshed, and that connection firing later (after the aura's particles had already been cleaned up) is what was throwing the errors and taking the game down with it.",
		"Fixed dragging items being broken entirely and double-click only working for unequipping - the previous attempt at fixing double-click added a minimum-distance check before a drag was allowed to start, which seemed reasonable but turned out to permanently block dragging altogether once Godot said no to a drag attempt once, since it doesn't ask again during the same click-and-hold. Reworked to never block a real drag while still reliably catching double-clicks.",
		"Removed the draggable black border from the item Info/Inspect popup - that one's meant to be a quick reference card, not a window you reposition.",
	]},
	{"version": "3.45.0", "title": "Hideout/Stash Navigation Fixes", "notes": [
		"Fixed the Stash screen's Back button always returning to the Main Menu even when you opened it from the Hideout - it now goes back to wherever you actually came from, same as Tab/Esc already correctly did.",
		"The cursor now switches to normal the moment you open the Stash from the Hideout, and back to the crosshair the moment you return - it was staying as a crosshair the whole time before.",
		"Spaced the crosshair out a tiny bit more.",
		"Fixed the Feedback window's Close button getting cropped off the bottom - the content inside was taller than the window, so it enlarged.",
	]},
	{"version": "3.46.0", "title": "Better Gear, New Stats, More Achievements", "notes": [
		"Fixed the actual remaining cause of the Pet Case crash/error spam - the previous fix stopped the crash but left stale connections quietly piling up every time a Plushie-buffed pet's slot refreshed, and each one still logged a warning when it fired even though it was harmless. Now the old connection is properly cleaned up before a new one is added, so nothing accumulates at all.",
		"Fixed double-click to equip - it was calling the equip action and then continuing to build a drag preview off a tile that the equip itself had just destroyed by refreshing the grid. Applied the same fix to double-click-to-unequip on the doll.",
		"Swapped the Weapon and Backpack slots on the character doll.",
		"All gear across every loot pool in the game now gives noticeably better stats (roughly +35%).",
		"Added 2 new gear stats: Armor (flat percentage damage reduction, capped at 60%) and Ammo Reserve (more reserve ammo carried into a raid) - a handful of new items using them added to the Loot Bag pool.",
		"Fixed a real gap where gear granting Loot Sense, Crit Chance, Vision Range, Reload Speed, or Health Regen had no effect at all - those bonuses were only ever being read from the Skill Tree and Hideout, never from equipped items. All five now actually work when they roll on gear.",
		"Fixed item tooltips and the Stash showing a blank stat line for anything that wasn't Speed/Health/Damage/Fire Rate - Loot Sense, Crit Chance, Vision Range, Reload Speed, Health Regen, and the two new stats all display properly now.",
		"The Character screen has a new Utility section showing every stat that was missing from it before, gear-sourced or otherwise.",
		"Added 5 new achievements for Rose, Plushies, Tags, and the new Armor stat.",
		"Updated the Roadmap with the major features added recently - Divine rarity, the Ammo system, Rose & Plushies, Tags, and draggable windows.",
	]},
	{"version": "3.46.1", "title": "Hotfix: Double-Click to Equip Not Updating the Stash", "notes": [
		"Fixed double-click to equip doing nothing (or throwing an error on the next click) from the Stash screen. The 3.46.0 fix was real, but it only ever got exercised on the in-run Backpack - equipping via drag-drop or the right-click menu already told the Stash screen to redraw itself afterward, but double-click skipped that step entirely. The item WAS being equipped correctly under the hood, but the grid on screen never refreshed, so the leftover tile's remembered position quietly drifted out of sync with the Stash underneath it - the very next click on that tile (or any tile after it) could then hit the wrong item, or an item that wasn't there anymore, which is what threw the error. The Stash now listens for the same signal the Backpack already does, so every equip or unequip - drag, right-click, or double-click - keeps it in sync no matter which one triggered it.",
	]},
	{"version": "3.46.2", "title": "Hotfix: The Actual Reason Double-Click to Equip Kept Failing", "notes": [
		"Root-caused the double-click-to-equip failures for real this time. It only ever registered when the second click had a tiny bit of mouse drift - that's what Godot needs to even consider it a drag attempt, which is where the detection lived. A precise, still double-click (steady hand, some mice, most trackpads) never triggers that at all, so the FIRST click's info popup would open right where the cursor already was and eat the second click as a dismiss-by-clicking-outside before it ever had a chance to register as a double-click. Detecting a still double-click directly now too, and delaying the popup itself by the same window, so a fast second click can't get beaten to the punch either way.",
		"Fixed the 'Lambda capture ... was freed' error spam on that same item info popup - its 6-second safety timer (for when the tile gets yanked out from under the cursor instead of the mouse just leaving normally) was staying connected even after the popup had already closed the normal way, so it fired again later against a popup that no longer existed. It now detaches itself the moment the popup closes normally, instead of sitting around waiting to misfire.",
	]},
	{"version": "3.46.3", "title": "Hotfix: Tooltip Frame and the Real Alpha Rewards Gradient Fix", "notes": [
		"Removed an extra black frame that was showing up around item tooltips (both the hover one and the click popup), sitting just outside the item's own rarity-colored border. Godot wraps both of those in its own default-themed panel behind the scenes, invisibly, and that wrapper was drawing its own dark background and border on top of everything - the tooltip itself was never the problem. Stripped out just that wrapper's styling, scoped narrowly enough that no other popup in the game is affected.",
		"Actually found the Alpha Rewards gradient issue this time, by rendering the exact screen and measuring it directly instead of guessing again: the shimmering border on The Prototype and Exclusive Alpha Chest was rendering at a fixed 128x128 - its raw texture size - completely ignoring the 44x44 icon box it was supposed to hug, because of how Godot sizes a texture that gets assigned before it has a parent. This lives in the one function shared by the Stash, Traders, Battle Pass, Gamble, and everywhere else a gradient border shows up, so this fixes it everywhere at once, not just here.",
	]},
	{"version": "3.46.4", "title": "Hotfix: Alpha Rewards Shimmer Was Too Faint to Actually See", "notes": [
		"The gradient border fix last update was correctly sized, but correctly sized turned out to mean 'basically invisible' - Multiversal's gradient is deliberately semi-transparent (it used to cover the whole card, back when a lower alpha was needed to keep text readable over it), and at the properly-fixed 3px ring that shows around just the icon, that transparency blended down to almost nothing. Widened the icon box and the ring itself so the same border is now actually visible as a shimmer again, without going back to covering the whole card.",
	]},
	{"version": "3.46.5", "title": "Hotfix: Alpha Rewards Shimmer, For Real This Time", "notes": [
		"Turns out a wider ring was never going to fix this - a static, semi-transparent tint just isn't what 'shimmer' means, no matter how thick it is. Added actual movement: the same animated tracing line already used around the card's own edge (and around Alpha/Tech-Test-exclusive items in the Stash) now also loops around The Prototype and Exclusive Alpha Chest's icons specifically, in the item's real Multiversal gold, at full opacity - on top of the gradient ring rather than replacing it.",
	]},
	{"version": "3.46.6", "title": "Alpha Rewards: White & Black", "notes": [
		"Reskinned the Alpha Rewards screen from gold to a white-and-black theme, start to finish: The Prototype and Exclusive Alpha Chest's icon backgrounds now go edge-to-edge in a white/black gradient instead of a colored ring, with a white tracing line looping around them instead of gold. The ambient sparkle field, the claim burst, the ALPHA REWARDS title glow, and the background particle wash all switched from gold to white/black too - same for the Alpha Rewards button on the Main Menu and the sparkles orbiting it. Item names and card text are untouched and still read exactly as clearly as before.",
	]},
	{"version": "3.46.7", "title": "Alpha Rewards: White & Black, Part 2", "notes": [
		"The Main Menu's Alpha Rewards button text (in all three states - idle, 'Claim Now!', and 'Already Claimed') is now a genuine white-to-black gradient instead of a flat color - Godot buttons only support one flat font color natively, so this is hand-drawn per letter now instead of using the built-in text rendering.",
		"The Prototype and Exclusive Alpha Chest's own card borders (not just their icons) switched from a flat gold line to a white/black gradient ring, with two trace lines - one white, one black - looping around them in opposite directions instead of one gold one. Added a second, concentrated white/black particle field around just these two cards, on top of the screen-wide one.",
	]},
	{"version": "3.46.8", "title": "Alpha Rewards: Neutral Card Backgrounds", "notes": [
		"Every reward card's background was a warm brown, not a true dark gray - swapped it for a neutral charcoal (still soft, not pure black) across all 8 cards, matching the rest of the white/black reskin.",
	]},
	{"version": "3.46.9", "title": "Alpha Rewards: No More Scrolling", "notes": [
		"The reward grid no longer sits in a scrollable area - the window is bigger now (700x600, up from 680x520) so all 8 cards, the claim button, and everything else fit on screen at once with room to spare, in both the claimed and not-yet-claimed states.",
	]},
	{"version": "3.46.10", "title": "Hotfix: Social Was Staying Open Behind Global Chat", "notes": [
		"Opening Global Chat from inside the Social panel left Social itself still fully open underneath it the whole time - closing Global Chat now correctly closes that path cleanly too, instead of leaving the Main Menu buttons stuck hidden behind it.",
	]},
	{"version": "3.46.11", "title": "Bug & Polish Pass", "notes": [
		"Double-click to unequip now works from the character doll, not just the Stash/Backpack grid - same fix as the grid got a few updates ago (a perfectly still double-click never triggered the old detection at all).",
		"Backpack Storage no longer scrolls - it's a fixed 7x7 grid that already fit the window, it just never needed to be in a scrollable area in the first place.",
		"Every draggable window's edge frame now has smoothly rounded corners instead of square ones, and picks its own color from that specific window's background (darkened), instead of the same flat black everywhere.",
		"Fixed the Leaderboard's own-row highlight - it was configured correctly (solid gold background, thicker border) but never actually rendering, because Godot doesn't draw a flat button's custom style overrides at all. Your row now actually stands out like it was always supposed to.",
		"Added a Rarity option to the Stash's filter menu, and shrunk every filter button down - same options, noticeably more compact grid.",
		"Added a very quiet tick when hovering items in your inventory - tuned deliberately subtle with a touch of random pitch variation, since it fires constantly while browsing a full Stash.",
	]},
	{"version": "3.46.12", "title": "Rarity Visuals: Multiversal, Divine, and Alpha/Tech-Test Are Distinct Now", "notes": [
		"The shimmering gradient background and tracer are Multiversal-only now - Exotic and Mythic go back to a plain flat rarity-colored border like every other tier, so Multiversal actually reads as the standout it's supposed to be instead of one of four rarities all doing the same thing.",
		"Divine items get their own completely distinct look: a gold border, a slow rotating gold shimmer, ambient gold particles, and small twinkling gold stars along the edge - with one deliberate exception, a black tracer with its own black particles, so it doesn't just blur into 'a shinier gold rarity' next to Multiversal.",
		"Alpha/Tech-Test exclusive items now get a continuously rotating black-and-white gradient background and a tracer that smoothly cycles between white and black instead of a single fixed color - hovering adds a burst of black/white particles and a stronger glow on the tracer, both of which settle back down once you move on.",
	]},
	{"version": "3.46.13", "title": "Global Chat: Real Talk", "notes": [
		"Fixed two things people flagged as bugs, and they were right - bot chat could claim someone had a specific badge count or leaderboard rank that wasn't actually true, since those lines were just flavor text handed to a random name. Badge and rank callouts now only ever reference someone's real numbers, pulled from their actual profile - if nobody in chat happens to have a priority badge or a top-10 spot at that moment, it just skips to something else instead of making something up.",
		"Bots now chain-reply to each other noticeably more often, and sometimes a third message lands on top of that too - short threads of people actually going back and forth instead of isolated one-liners.",
		"Added a big batch of new brainrot/slang lines to the general chatter pool for more variety.",
	]},
	{"version": "3.46.14", "title": "Hotfix: Shadowed Variable Warning in Global Chat", "notes": [
		"Fixed a 'local function parameter shadowing a base class property' warning from last update - a helper function used a plain 'name' parameter, which every Node already has built in. Harmless (just a warning, nothing was actually broken), but renamed it to stop it from showing up in the debugger.",
	]},
	{"version": "3.47.0", "title": "Find a Team", "notes": [
		"New button next to Global Chat - Find a Team shows a live list of other squads looking for people right now: their map, their leader's level and Rank, a preview of their loadout, and everyone currently in the group. Group sizes and fill levels are random (a 2/2 and a 3/4 can both show up), and the list actually moves on its own - squads gain and lose members over time, some give up and vanish before ever filling, and a squad that hits full shows 'Joining raid...' with a 5-second countdown before it heads out and disappears from the list. Join Group adds you to whichever one you pick.",
	]},
	{"version": "3.46.15", "title": "Doll Slots, Flea Market, and Spike", "notes": [
		"The Multiversal/Divine/Alpha-Tech-Test rarity treatments (gradient, gold shimmer, tracers, particles) from a couple updates ago only ever made it to the Stash and Backpack grids, not the character doll slots themselves - equipping one of those items now shows the exact same effect on the doll as it does sitting in your inventory.",
		"Fixed the Flea Market opening tiny and stuck in the corner of the screen - it's a full-screen panel and had a draggable frame applied to it like the small popups get, which doesn't make sense for something that already fills the whole screen. Found the same mistake on 7 other full-screen panels (Battle Pass, Bloodline, Data, Gamble, My Pets, Salvaged Beasts, Store) and removed it from all of them.",
		"Spike was holding back at a comfortable shooting distance instead of closing in - the default 'stop advancing' distance every enemy uses is tuned for ranged combat, but Spike's whole kit (the spinning ring around him) only matters up close. He actually presses the attack now instead of just sniping from a safe range.",
		"The Tech Tester's Sidearm was firing the exact same plain bullet as a basic starter pistol despite being a rare beta-exclusive - it now has its own quick electric-blue streak, sized down from the Alpha Cannon's trail to stay cheap at this weapon's absurd fire rate.",
	]},
	{"version": "3.47.1", "title": "Plushies", "notes": [
		"Pets now actually level up - they gain XP from successful extractions and turned-in Contracts, with a real curve that keeps climbing well past the first few raids. Fixed a real bug in the process: Plushie pets (and pacified Graveyard pets) were never getting their trait bonus applied at all, only hatched Egg pets were - a Plushie's signature +32 Health/+14 Damage buff genuinely wasn't doing anything until now.",
		"Added a hover tooltip for pets - stats, aura (if it has one), level and XP progress, where you met it, and its rarity alongside the actual odds of pulling that rarity. Shows up on the doll and in My Pets.",
		"Rose's 'Give Plushie' button is 'Plushies' now, and opens its own window instead of handing one over immediately - see the real rarity odds (Multiversal and Divine are genuinely reachable this way now, at meaningfully better odds than a crate roll), give a Plushie from there, and browse every Plushie pet you've gotten so far.",
	]},
	{"version": "3.47.2", "title": "Tech Tester's Sidearm + Alpha Rewards Borders", "notes": [
		"The Tech Tester's Sidearm now fires 3 projectiles per shot in a tight spread instead of one - damage per projectile is scaled down to keep the already-fastest fire rate in the game from becoming flatly overpowered on top of it. Its trail also got a pass: a brighter two-layer glow (a hot core plus a soft blue halo) instead of just more particles, trimmed slightly further since there are now 3x as many bullets flying at this fire rate.",
		"Added a white border around The Prototype, Alpha Pioneer's Rig, and Exclusive Alpha Chest on the Alpha Rewards screen - same treatment Skill Points already had, just white instead of blue.",
	]},
	{"version": "3.47.3", "title": "Hotfix: Crash When Firing With No Weapon Equipped", "notes": [
		"Found and fixed the crash people were hitting mid-raid - shooting (or anything that tried to) with no weapon equipped threw an engine-level error and took the game down with it. This was a bug from the Tech Tester's Sidearm bullet-color update two versions back, not a pre-existing issue. Verified with a direct repro: confirmed it crashed on the old code with the exact same error message, confirmed it no longer does on the fix.",
	]},
	{"version": "3.48.0", "title": "Studio Splash + Photosensitivity Warning", "notes": [
		"The game now opens with a brief Sapphire Signal Studio logo card - an animated faceted gem with a pulsing signal-ping ring - followed by the standard photosensitivity warning every commercial game ships with, before dropping into the existing title sequence. Both screens hold for a minimum time before they can be skipped, same as the title card already did.",
	]},
	{"version": "3.48.1", "title": "Rotating Main Menu Backgrounds", "notes": [
		"The Main Menu background is no longer a single static scene - it now rotates between three: the original city skyline with the prowling creature, a raider walking through foggy woods with a sweeping flashlight cone, and the extraction chopper hovering with its rotor spinning and searchlight sweeping the ground. One is picked at random when you reach the menu, and every 30-55 seconds it quietly crossfades to a different one (never immediately repeating), so sitting at the menu for a while doesn't feel static.",
	]},
	{"version": "3.48.2", "title": "Sapphire Signal Rework + a Real Animation Bug Fix", "notes": [
		"Reworked the studio splash entirely: the crystal now falls from off-screen, cracks and shatters on impact, and reveals a signal light that was inside it - which is what actually lights the studio name up. The screen starts genuinely dark (the name is barely readable beforehand), the letters fade in one at a time as the light hits them, and there's a switch to a new font (Chakra Petch) for the name so it doesn't just look like every other bit of UI text in the game.",
		"Fixed the monster during the 'DEAD SECTOR - press any button to play' screen only showing its eye - its body color was fixed and nearly identical to the darkest point of the background's color cycle, so it was blending away almost completely and only the small glowing eye stayed visible. It now derives its color from whatever currently contrasts with the background, same as the title text already did.",
		"Found and fixed a real, previously invisible bug while building the new splash screen: attaching a script to a node that's already in the scene tree silently drops its per-frame animation in Godot, even though the script's own code tries to enable it. This was quietly breaking the ambient particle effects on 5 existing screens - Achievements, Salvaged Beasts (egg hatching), Justin's engram deciphering, the Undertow's crate opening, and the Plushie pet reveal - all of them have been sitting completely frozen instead of drifting since before this update. All five now actually animate.",
	]},
	{"version": "3.48.3", "title": "Hotfix: Duplicate Menu Music", "notes": [
		"Found the cause of the doubled/changing music - the intro cutscene had its own separate copy of the menu music playing on top of the real one (the global track that's been running continuously since the game boots), instead of just letting that one keep playing through. Removed the duplicate, so it's now one unbroken track from the splash screen all the way through to the Main Menu.",
	]},
	{"version": "3.48.4", "title": "Splash Pacing, Music Gaps, and the Title Screen Monster (For Real This Time)", "notes": [
		"The crystal now holds still, fully intact, for a couple extra seconds after it lands before it cracks and breaks - long enough to actually see it before it's gone.",
		"The signal light revealed inside the crystal is noticeably smaller now, instead of ballooning out to nearly the size of the crystal itself.",
		"Fixed the monster on the Title Screen ('DEAD SECTOR - press any button to play') actually being a plain smooth blob shape with no tail, legs, spikes, or reliable eye-glow - once you weren't looking right at it, there was nothing left that read as a creature. It now uses the same detailed silhouette (tail, jagged spine, jaw, clawed feet) the Main Menu's own version already had.",
		"Increased the music buffer significantly and made every scene transition top it off right beforehand, to close the gap where the music briefly cut out and resumed during a transition - that was a genuine buffer running dry during a heavy scene load, not intentional.",
	]},
	{"version": "3.48.5", "title": "Engine + Legal Splash Screens", "notes": [
		"Added two more screens to the opening sequence, right after the Sapphire Signal logo and before the Title Screen: a brief 'Made with Godot Engine' credit, then a standard copyright/legal screen. Both are skippable the same way the others are, after a short minimum hold.",
	]},
	{"version": "3.48.6", "title": "Partner Splash Screens: Clarity Interactive + Steelcrest Games", "notes": [
		"Added two partner credit screens, right after the Sapphire Signal logo and before the Engine credit: Clarity Interactive - the name drops in from above letter by letter, each one on its own randomized delay and fall speed so they land at staggered moments instead of all at once, settling with a small bounce - and Steelcrest Games, which gets its own different treatment: a hard scale-down slam with a flash and a screen shake on impact, so the two don't feel like reskins of each other. Both have their own gradient background and drifting particles instead of a flat black screen.",
	]},
	{"version": "3.48.7", "title": "Menu Confirm Sound", "notes": [
		"Added a subtle confirm click that plays whenever you hit Play, skip a cutscene or splash screen, or navigate between menus - the understated kind of blip a well-produced menu plays, not an arcade beep. Wired it into the same lock that already prevents a spam-clicked Play button (or a mashed skip key) from double-triggering a transition, so it's guaranteed to only ever play once per action no matter how many times it's pressed.",
	]},
	{"version": "3.48.8", "title": "Hotfix: Confirm Sound Was Playing Late", "notes": [
		"Fixed the confirm click from the last update feeling delayed on the skip prompts specifically (Play itself was always instant) - it was waiting until the screen's own fade-out finished before playing, which could be half a second or more after the actual button press. It now plays the moment the input happens, with the later scene-change skipping a second play so it still can't double up.",
	]},
	{"version": "3.49.0", "title": "Performance Audit: Memory Leaks, Per-Frame Waste, Pooling", "notes": [
		"Corpses never actually despawned - every enemy kill left a live, permanently-running node behind for the rest of the raid with no cap. Corpses are now capped at 40 live at once (oldest already-searched ones culled first) and clean themselves up a short while after being searched, or immediately if there was nothing to loot.",
		"Fixed the Bloodline Gauntlet's projectile impact particles (player shots, enemy shots, boss shots) never being freed after their burst finished - every shot fired in a Gauntlet run was leaking one dead node, permanently, for the rest of the run.",
		"The Hotbar was rebuilding all 5 slots from scratch every single frame regardless of whether anything changed. It now refreshes instantly when your gear or Safe Pockets actually change, with a light safety-net poll underneath for the couple of pickup/drop paths that don't fire a signal.",
		"Hired Recruits were doing a full scan of every enemy on the map every physics tick just to find their nearest target - now retargets on a short timer instead (immediately if their current target dies early), matching how Pets already handle the same check.",
		"Every enemy was checking every active smoke cloud on the map every physics tick, regardless of how far away they actually were from the player - now skipped entirely for any enemy already further away than its own detection range allows.",
		"The HUD's currency readout was re-parsing its text every frame even when Rubles/Junk/Artifacts/Alloys hadn't changed, and re-looked-up the player node the same way - both now only do real work when something's actually different.",
		"Damage numbers (the floating combat text over a hit enemy) now come from a small reused pool instead of building a brand new label with fresh style overrides on every single hit - matters most during sustained automatic fire against a crowd.",
		"Health regen's stat total was being recalculated from scratch every physics tick instead of once when your gear/upgrades actually change, same as your other stats already do.",
		"The achievement check that runs on every save was scanning your whole Stash twice over for two checks that could share one pass, and was needlessly duplicating the entire Stash array just to check for Mythic/Exotic ownership.",
		"Blood decals were unintentionally all sharing one shader material, so spawning a new one silently changed the random pattern on every OTHER decal already on the ground too - each one now genuinely keeps its own distinct pattern like it was supposed to.",
		"Mail now caps at 100 messages, trimming the oldest ones you've already read and claimed - previously grew forever on a long-running save, with every mail action scanning the whole list.",
		"Radiation Clouds were re-finding the player via a map-wide lookup every physics tick while you stood in one, instead of just using the reference they already got the moment you walked in.",
		"Removed 14 unreferenced leftover sprite files from earlier art swaps (old player/weapon art, a pre-recolor enemy sprite) that were still being bundled into every build despite nothing in the game using them.",
	]},
	{"version": "3.49.1", "title": "Menu Navigation Lag", "notes": [
		"Found the real cause of the noticeable hitch opening Stash and several other screens: switching screens re-reads and re-parses that screen's whole scene file from scratch every single time, even if you'd already opened it moments ago - nothing was keeping it in memory in between visits. Frequently-visited screens now stay cached for the rest of the session after their first load, so returning to one skips straight to building it instead of loading it all over again.",
	]},
	{"version": "3.50.0", "title": "Full Bug Audit: 22 Real Bugs Found and Fixed", "notes": [
		"The big one: any save from an older version of the game was being wiped outright on load instead of actually upgrading - the code that migrates old quest/hatchery/settings data existed and was correct, it just sat AFTER an unconditional \"delete anything old\" check that ran first, so it could never actually be reached. Older saves now genuinely carry forward instead of getting deleted.",
		"Boss grenade throws (Spike, Rattles) were dealing zero damage to you - the explosion only ever checked for enemies to hurt, never the player, so getting caught in one only ever shook the camera.",
		"Stunning Spike or Rattles didn't actually stop them - their spinning damage ring kept hurting you and they kept throwing grenades/bones on schedule regardless, only their movement and gunfire were actually interrupted.",
		"A stunned Bonedog that had wandered past its leash range still snapped back at full speed, completely ignoring the stun.",
		"Standing across two overlapping ice patches and stepping out of just one ended your slide early, even while still standing on the other.",
		"Multiple bullets landing on a nearly-dead enemy in the same instant (shotgun pellets, multi-shot weapons) could kill it twice over, double-counting the kill and spawning two corpses worth of loot.",
		"In the Bloodline Gauntlet: swapping gear mid-run spawned an extra copy of your pet every single time, on top of quietly piling up duplicate event listeners - a mistake in how the code was structured meant pet-spawning logic was re-running on every equip instead of just once at the start.",
		"Also in the Gauntlet: an enemy or boss that took two near-simultaneous hits (like your own attack landing the same instant as your pet's) could die twice over and duplicate its loot drop - worst case on a boss kill, which drops a full 14-item haul plus a guaranteed engram.",
		"Dragging an item between the Stash and Backpack Storage grids could drop it directly on top of another item with no overlap check, making the covered item invisible and unreachable even though it was still there.",
		"A rare inventory-repositioning edge case was using the wrong grid dimensions internally, which could shove an item into unreachable overflow space in the Stash while real, visible slots sat empty.",
		"The Attachments panel could install a different attachment than the one actually shown, if you sorted the Stash while the panel was still open.",
		"Quick Sell could sell the wrong item if you sorted, filtered, or equipped something else while items were still selected - those actions are now blocked until you finish or cancel the sale.",
		"Escape inside the Stash always exited the whole screen, even when what you actually wanted to close was a smaller panel on top of it (Tag Editor, Inspect, Skins, and others) - it now closes just that panel first, like it should have all along.",
		"There was no way to cancel rebinding a key in Settings - pressing Escape to back out actually bound Escape itself to that action instead.",
		"Closing the Tag Editor mid-raid with Escape could also pop open the Pause Menu as an unwanted side effect of the same keypress.",
		"The Flea Market's \"My Listings\" tab could keep showing a live countdown and a working-looking Cancel button for a listing that had already sold or expired in the background.",
		"Three achievement-unlocking moments (a Multiversal item drop, a sub-50-HP extraction, talking to Rose) weren't actually being saved - if the game closed before the very next save, the game forgot they'd happened and the achievement could be missed for good.",
		"\"Full Docket\" (all 3 contracts active at once) only ever got checked during a save, which only happens periodically - it now unlocks the instant you actually hit 3 active contracts.",
		"\"Well Traveled\" was missing its actual Overgrowth check and unlocking off an unrelated stat instead, so it was possible to earn it without ever having fought an Overgrowth enemy, despite what the achievement description promises.",
		"Pacified pets (tamed in the Graveyard) were missing their glow/pulse trait effects and full info popup in the equipped Pet slot - only hatched and Plushie pets were getting that treatment.",
		"Recruit stations in the Hideout showed a normal, fully-usable prompt even before their unlock quest was done, with nothing indicating they wouldn't actually work yet - they're now visibly greyed out until unlocked, matching what happens the moment that quest completes.",
	]},
	{"version": "3.50.1", "title": "Flea Market Fullscreen Fix, Windowed Fullscreen Default", "notes": [
		"Fixed the Flea Market opening as a small shrunken box in the corner of the screen instead of filling it, no matter the window size - its layout wasn't resolving correctly, so it's now forced to the correct full-screen size directly the moment it opens.",
		"New installs now start in Windowed Fullscreen by default instead of a small window - same as before if you'd already picked a Display Mode in Settings, that choice is untouched.",
	]},
	{"version": "3.51.0", "title": "Real Art Pass: Player, Pistol, and a New Enemy", "notes": [
		"Your character and the base Pistol now use real sprite art instead of the old flat-shape placeholder look.",
		"With no weapon equipped, your character now correctly shows empty hands instead of still holding a pistol you don't have - and you can no longer fire while unarmed either, both of which used to slip through.",
		"The Prototype's gun model is a real sprite now too - small, thin, and gold-yellow, matching its icon.",
		"Replaced the Bonedog with a new enemy: the Ghoul. Same role guarding the Bone Clocktower alongside Rattles, same stats, but a real sprite instead of the old placeholder, plus a matching new Data screen entry, name tag, and achievement (\"Fresh Rot\", swapping out \"Good Boy?\").",
	]},
]

# Starts empty - the next real entry logged here should continue the
# version number from wherever CHANGELOG_ARCHIVE's last entry left off
# (3.51.0 as of the archive above), not reset to 1.0.
const CHANGELOG_CURRENT := [
	{"version": "3.52.0", "title": "Arena Mode, Death Screen, and a Major Ammo Overhaul", "notes": [
		"Added Arena: a 1v1/2v2 mode on a new close-quarters map called The Grid, with matchmaking, a Current Teams roster, a Find a Team panel, a Leaderboard, Rewards, 6 new ranks with their own icons, and an NPC (Lilly) in the Hideout.",
		"Replaced the flash \"YOU DIED\" text with a full Death Screen - who killed you, with what weapon, a hit-location mannequin review, and the loot you lost.",
		"Reworked ammo: it's no longer a Hotbar consumable - it's a stacking Backpack item, and reloading pulls straight from your Backpack ammo stacks.",
		"Added small safe pocket slots under the pet icon on your character doll, working consistently in both the Stash and in-raid.",
		"Trying to deploy with no reserve ammo for your equipped weapon now blocks you with a clear popup instead of a toast warning you could ignore and go in defenseless anyway.",
		"Global Chat and Find a Team's Close button now returns to the Social screen instead of the Main Menu.",
		"Every button in the game now shares one consistent click sound. Hover sounds on the 15 main menu buttons, Ranked, Alpha Rewards, and Companions were also redone or differentiated, and Leaderboard now has one too.",
		"Added a Claim All button to Mail, more teams in Find a Team, and a changelog archive tab so this list doesn't grow forever.",
		"Removed Seasons (not ready yet) and the Backpack Storage scrollbar. Added ammo to the Scavenger's starting loadout.",
		"Fixed the leaderboard countdown timer not ticking, a stale ammo count briefly showing before switching to the correct type on your first shot, and a phantom click sound after the \"Searching for Players\" screen finished.",
		"Reverted your character back to the Survivor sprite.",
		"Left-clicking your equipped pet slot now opens a full collection window of every pet you own, including Plushies.",
	]},
	{"version": "3.53.0", "title": "Real Art Pass: Vehicles, Enemies, Props, and Ground Decoration", "notes": [
		"Vehicles: the extraction pickup car and the many parked wrecks scattered around the maps now use real weathered sprite art instead of a flat colored shape.",
		"Enemies: added a sprite for the Rift Wraith, which had none before. Also fixed the Goblin and Noxious Bat, which were both quietly broken - the Goblin's art file was an exact duplicate of the Ghost sprite, and the Bat's was a malformed fragment.",
		"Barrels, crates, and rubble piles scattered around the maps now use real art instead of plain vector shapes.",
		"Every wall - and every building, since they're all built from the same wall piece - now uses a real brick texture.",
		"Boneclock's ground is no longer just scattered abstract bone shapes - real bone piles, rocks, dead trees, gravestones, and rare skull piles now dress the map.",
	]},
	{"version": "3.53.1", "title": "Ammo and Backpacks Join the General Loot Pool", "notes": [
		"Loot Bags can now contain Ammo, not just gear.",
		"Rotating Trader stock (Medic, Quartermaster, Scavenger) can now include Ammo alongside gear.",
		"Added a Backpack Pack to the Store, and contract rewards can now include Ammo as well as gear - \"Bring Backup\" now hands over a Ranger Pack, and \"Fire in the Hole\" now includes Heavy Ammo.",
	]},
	{"version": "3.54.0", "title": "Full Release-Readiness Audit", "notes": [
		"Flea Market listing prices are now clamped to the same 0.5x-3x band the UI already suggested - closes a real exploit where junk could be listed at an absurd price and the sell-chance system would pay it out in full.",
		"Scav Run/Arena Loadout temp gear now survives a quit or crash instead of permanently overwriting your real loadout - it recovers automatically the next time you load.",
		"Safe Pockets now actually survive an interrupted raid, not just a normal win or loss, by persisting to disk and draining into your Stash the next time you load.",
		"Save files now write through a temp file and atomic rename with a rotating backup, instead of overwriting the real save directly - a corrupted or interrupted write can no longer wipe 100% of your progress with zero warning.",
		"Delete Character now actually clears everything its own confirmation promises - Stones, Skill/Rank/Arena Rank points, Bloodline, Battle Pass, Milestones, pets, titles, badges, achievements, mail, Flea listings, and Backpack Storage all used to quietly survive a \"wipe.\"",
		"Recruit chat invites can no longer leak a party into a later, unrelated raid, and the join countdown is finally cancellable.",
		"Opening a Loot Bag mid-raid with a near-full Backpack now routes overflow into Vicinity instead of silently deleting it.",
		"Arena Rank Rewards now actually pay out (Rubles/Artifacts/Alloys/Skill Points/Loot Bags) when you cross a new rank tier, instead of just listing rewards that never arrived.",
		"Added a real \"epic\" Loot Bag tier - Milestones and Arena Rewards had both referenced it for a while, but it silently downgraded to common every time since it was never actually defined.",
		"The in-raid Pause Menu now genuinely pauses the game (enemies and the extraction timer freeze) instead of just covering the screen while everything kept running behind it.",
		"Unequipping a healing item mid-raid can no longer drop you to 0 HP without actually killing you.",
		"Unclaimed Vicinity loot now counts toward extraction XP, Rank Points, and the Rewards Screen's Rubles Secured total, same as everything else you bank.",
		"Settings volume sliders no longer write a full save on every drag tick - fixes a real, reproducible stutter while adjusting them.",
		"Around 20 permanently-hidden Main Menu background panels were animating a full particle system every single frame even while invisible - they now skip that work entirely until actually shown.",
		"Global Chat no longer desyncs its reaction tracking from what's on screen after a few minutes of traffic and a reopen.",
		"Escape now correctly closes just the panel you meant to close, not the whole screen behind it, in several more places this pass missed the first time - Hideout's 11 station panels, Social Place, and Arena's Current Teams/Lilly panels.",
		"Ammo that overflows a stack's cap while merging now spills into a new stack instead of vanishing.",
		"The in-raid timer and Hideout's currency label stopped reformatting their text every single frame regardless of whether the number actually changed.",
		"Plus a dozen smaller fixes: Bloodline equip/unequip grid glitches, joining two Arena teams at once, a few popup panels not resetting their anchors correctly, and hunger no longer decaying while you're safe in the Hideout.",
	]},
	{"version": "3.55.0", "title": "Loadout Presets, Guilds, Prestige, Elite Caches, and Ironscrap Yard", "notes": [
		"Added PMC Loadout Presets: save up to 3 full gear builds from the Stash and re-apply any of them in one click before a raid.",
		"Added a real Guild system - join one of 4 existing guilds or found your own, with a simulated roster and a dedicated Guild chat channel that unlocks the moment you're in one.",
		"Added a rare mid-raid event: some raids now spawn a heavily-guarded cache defended by 2 tougher, red-tinted Elite Guards, with genuinely good loot for anyone who can kill them.",
		"Added Prestige: once you hit the level cap, reset back to Level 1 in exchange for a real one-time Rubles and Skill Point bonus, so there's still somewhere to climb after 500.",
		"Added a 5th raid map: Ironscrap Yard, an industrial scrapyard sector unlocking at Level 30, with its own guarded vault crate, extraction spread, and layout distinct from the other 4 sectors.",
	]},
	{"version": "3.56.0", "title": "Deeper Inventory, Clan System, and The Foundry", "notes": [
		"Added real item footprints and 4 Specialized Cases (Medical, Gun, Armor, Key) for more deliberate Stash organization.",
		"Added the Clan System: guildmates now visibly share your Hideout, and extraction grants a real loot-split bonus if you're in a guild.",
		"Added a 6th raid map: The Foundry, unlocking at Level 40.",
		"Dropped the autosave backstop timer from 60 seconds to 5 - the game already saves on every meaningful action, this just closes the gap faster if one's somehow missed.",
	]},
	{"version": "3.57.0", "title": "Guild Overhaul: Roles, Clan Wars, Battle Pass, and Guild Hall", "notes": [
		"Guild is now a direct Main Menu button, not just tucked inside Social.",
		"Guild members now show real Leader/Co-Leader/Member roles - founding your own guild makes you its Leader.",
		"Added Clan Wars: a real 8v8 guild-vs-guild battle, unlocking once a day at 8 PM.",
		"Added the Guild Battle Pass: a 20-tier reward track earned through Honor from Clan Wars, win or lose.",
		"Added the Guild Hall: a no-damage hangout hub populated by your actual named guildmates.",
		"Arena opponents no longer fixate on just you when you've got a teammate - they'll engage whoever's closest, same as your allies already do to them.",
		"Arena opponents, allies, and Social Place NPCs now all show real character art instead of sometimes falling back to a plain vector body.",
		"Fixed the Hunger bar rendering as what looked like a second Health bar - it now only shows once hunger's actually dropped.",
		"Fixed Marketplace and Skill Tree sometimes silently doing nothing when clicked.",
		"Removed the redundant Global Chat / Find a Team buttons from the Social screen - Enter-to-chat already covers this.",
		"Double-clicking ammo or consumables in the Stash now sends them to Backpack Storage, and double-clicking them there sends them back.",
	]},
	{"version": "3.57.1", "title": "Bug Fixes and Polish Pass", "notes": [
		"DeathScreen no longer shows fake bullet-hit markers when you voluntarily exit to Main Menu - that's now clearly labeled as leaving the raid, not dying.",
		"The \"no ammo\" popup now tells you exactly which ammo type your weapon needs.",
		"Fixed the Guild Hall's Escape key also popping open the Pause Menu underneath.",
		"Fixed Social Place and Guild Hall NPCs standing frozen near the center of the map instead of actually wandering around - also gave them idle look-around, a random weapon, occasional cosmetic gunfire, and speech bubbles when you get close.",
		"The Hunger bar no longer floats above your head during a raid - check it in the Stash instead, next to your HP.",
		"Removed the hover scale-up bounce from every button except the Main Menu's own - it was pushing buttons outside their panel in tighter windows like Rose's.",
		"Plushies now opens centered and closes Rose's window behind it instead of stacking on top; trading shows the result in the same spot instead of a second popup, shows your latest Plushie Pet's icon and the full rarity odds, and the reveal now lists its real stat bonuses.",
	]},
	{"version": "3.57.2", "title": "Critical Fix: Pre-Raid Ammo Check", "notes": [
		"Fixed a real bug that could block deployment entirely with a \"find ammo for your gun\" popup regardless of how much ammo you actually owned - the check was only ever looking at ammo picked up so far during the current raid, not what's sitting in your Stash or Backpack Storage.",
		"Fixed Heavy Ammo sometimes showing green instead of purple - older Heavy Ammo saved before a past recolor never got its color corrected retroactively. It's fixed automatically the next time you load.",
	]},
	{"version": "3.57.3", "title": "Wipe, Ammo Gate Revision, Pause Menu, and Safe Pockets", "notes": [
		"Fixed Wipe not actually resetting anything - it deleted your save but not its backup copy, which silently restored your whole character (including every Alpha/Beta reward claim) on the next launch. Wipe now genuinely restarts you like a fresh install, Character Creation and the Echo intro included.",
		"The pre-raid ammo check now specifically requires the right ammo type in your Backpack Storage, not just anywhere you own it - equipping ammo into your Backpack Storage before deploying now actually matters.",
		"Guild Hall's Escape key now opens the real Resume/Settings/Main Menu pause screen instead of jumping straight to Main Menu - and leaving a hangout that way no longer strips your equipped gear.",
		"Safe Pockets now accept drags from the Stash and Backpack Storage, not just the in-raid Backpack.",
		"Removed the 2 random guildmate NPCs that wandered the Hideout.",
		"Global Chat background is more transparent now (30% opacity).",
	]},
	{"version": "3.57.4", "title": "Instant Backpack Storage Refresh, Tech Test Mail, Pistol Icon", "notes": [
		"Fixed double-clicking ammo/consumables into or out of Backpack Storage not visually updating until you dragged something else - the move always worked, the screen just didn't redraw until now.",
		"The one-time Tech Test veteran reward mail now reaches every character, including a freshly wiped one - it was only ever intended for existing saves before.",
		"Pistol-family weapons (including the Tech Tester's Sidearm) now show a real gun icon in your inventory instead of a plain vector shape.",
	]},
	{"version": "3.58.0", "title": "Backpack Storage Now Comes With You, Delete Character Is a Full Restart", "notes": [
		"Backpack Storage now actually travels with you into a raid - anything in it shows up in your in-raid Backpack, and if you die, you lose it, same as everything else you're carrying. Safe Pockets are still the one place that's always protected no matter what.",
		"Delete Character now acts as a complete wipe, done instantly without restarting the game - it drops you right back at Echo's opening cutscene and Character Creation, and the Welcome, Tech Test, and Alpha Rewards mail all become claimable again.",
		"Removed the separate Wipe button from the Main Menu - Delete Character now covers the exact same ground.",
		"More Safe Pocket fixes: moving an item into a pocket from the in-raid Backpack, or from the Stash screen, now updates every affected grid instantly instead of leaving a ghost tile behind.",
	]},
	{"version": "3.59.0", "title": "Armor Compendium, Pocket Drag-Out, and Mail/Icon Fixes", "notes": [
		"The \"real gun icon\" pistol-family weapons got in 3.57.4 turned out to be a nearly blank rectangle, not an actual gun - reverted to the existing hand-drawn vector pistol icon, which reads far more clearly at inventory size. Fixes the Tech Tester's Sidearm and every other pistol-type weapon, in both the inventory grid and the equipped weapon doll.",
		"Fixed Delete Character's mail regrant from 3.58.0 not actually taking effect without restarting the game - the Welcome/Tech Test/Newsletter mail only ever re-sent at the next full launch, so a freshly wiped character's mailbox stayed empty (and the newsletter stayed blocked until the next calendar day) until then. Now regrants immediately, no restart needed.",
		"Safe Pockets can now be dragged OUT onto the Stash, Backpack Storage, or in-raid Backpack, landing at the exact cell you drop them on - previously the only way out was a single click. That click now requires a double-click instead, matching the double-click-to-move convention used everywhere else in the inventory.",
		"Added Ironscrap Yard and The Foundry to the Data screen's Maps tab - both have existed as real raid destinations since 3.55.0/3.56.0 but were never added to the compendium.",
		"Added a full Armor tab to the Data screen - every named piece of head/body/boots/backpack/accessory/attachment gear in the game, the same reference treatment Weapons already had.",
	]},
	{"version": "3.60.0", "title": "Map Select Polish", "notes": [
		"The Select Sector screen's 5 map cards now each show a real icon (matching the same one used on the Data screen's Maps tab) and a themed bordered card with hover feedback, instead of plain unstyled buttons with colored text only.",
		"The Day/Night raid screen now actually shows which Sector you're about to deploy into - it used to just say \"SELECT RAID\" with no indication at all of the map you'd already chosen.",
	]},
	{"version": "3.61.0", "title": "Balance Pass: Top-Tier Weapon Burst, Boss Damage Scaling", "notes": [
		"Exotic/Multiversal/Divine weapons (The Prototype among them) fire 3-5 projectiles per trigger pull, and each one used to hit for a near-full 85% of the weapon's damage regardless of how many fired - meaning the burst alone dealt 2.55x-4.25x a single shot's damage before an alpha_cannon/railgun's own pierce-and-chain stacked another 1-2x on top in a crowd. Rebalanced so the burst's total damage stays fixed at 1.6x a single shot (matching the same ceiling shotguns and the Tech Tester's Sidearm were already tuned to) regardless of how many projectiles the burst happens to roll - still hits noticeably harder than a normal weapon, just no longer 3-4x on top of everything else stacking in.",
		"Spike's and Rattles' boss-specific attacks (spike/bone aura, thrown grenades, their custom bullets) never scaled with player progression at all, unlike their own HP (which already scales up to 4.15x) and every regular enemy's damage - fixed so their damage now scales at the same rate everything else does, since a maxed-out character was taking a trivial fraction of their max HP per hit from either boss by the time their HP pools got big enough to actually take a while to kill.",
		"The Noxious Bat's bullet damage was hardcoded and ignored its own (correctly-scaling) attack stat entirely, so it stopped mattering at all past the earliest levels - fixed to use the same scaling stat every other regular enemy already does.",
	]},
	{"version": "3.62.0", "title": "Item Stat Fixes and a Full Rebalance Pass", "notes": [
		"40+ named gear pieces (helmets, backpacks, accessories, attachments) with a Loot Sense or Fire Rate stat had a literal +0.00 placeholder value across every loot pool in the game - equipping any of them provided exactly zero of their advertised effect. Every one now carries a real value scaled by its own rarity.",
		"Several quest rewards (Combat Boots, Reinforced Plate, Vanguard Helmet, a mythic Aegis Plate, and others) were stuck at roughly 74% of the value the same named item rolls at everywhere else in the game - fixed to match their canonical stats, and several more one-time rewards (Night Ops Boots, Sprocket's Rig, Warlord Rig, Reaper's Mark, Veteran's Plate) that were tuned well below their own stated rarity got a real boost to match.",
		"The Prototype Rifle and Bloodfang Blade were both weaker than plain Epic-tier drops despite being Legendary - raised both, along with a genuinely stale Legendary weapon tier average across several other sources.",
		"Found and fixed a duplicated-value copy-paste pair in the Loot Bag reward pool (a Head-slot Wraithbone Helm carrying an exact Body-slot item's numbers, and two differently-named Legendary rifles sharing identical stats), and a compressed Exotic tier that only cleared its own Mythic ceiling by 10-22% instead of the intended ~50%.",
		"Rebalanced ~20 pricing outliers in the Flea Market's extra listings pool where an item's Ruble cost didn't track its own stat value the way every comparable item around it did.",
		"The Weapon Data tab was quietly showing every event/Alpha/Blueprint-exclusive weapon's damage at about 74% of its real in-game value (a stale compendium copy that never tracked a past balance change) - now shows the real number.",
	]},
	{"version": "3.63.0", "title": "Progression Rewards Overhaul", "notes": [
		"Doubled the Battle Pass's currency/XP payout formula across all 200 tiers, and doubled the Guild Battle Pass's hand-authored 20-tier reward list (Rubles, XP, Skill Points, and several tiers' Loot Bags bumped up a full rarity step).",
		"Doubled the Battle Pass XP and bonus Souls granted for clearing all 20 Soul Realm waves - the only source of Battle Pass XP in the game.",
		"Doubled every Milestone tier's Ruble/XP/Skill Point payout across all 24 tiers, with several tiers' Loot Bags raised a full rarity step.",
		"Doubled Arena Rank rewards (Rubles, Artifacts, Alloys, Skill Points) across all 6 ranks, with most ranks' Loot Bags raised a rarity step.",
		"Doubled Bloodline's and Salvaged Beasts' Ruble/Blood Shard/Ticket reward formulas, the Gauntlet's per-level Blood Shard grant and its level-5 finale payout, and the Bitcoin Farm's per-cycle payout.",
	]},
	{"version": "3.64.0", "title": "Gear Now Actually Shows Up On Your Character (and Theirs)", "notes": [
		"Equipping a Helmet, Backpack, or Accessory now shows a real icon for that specific item (a gas mask looks like a gas mask, a watch looks like a watch, a grenade rig looks like a grenade rig) instead of the same flat colored blob every time - the same art already used for that item in your inventory grid, just worn on the character.",
		"Body armor and Boots previously showed no visual change at all once real player art shipped (assets/player.png quietly made the old torso/leg recoloring dead code) - fixed: Body now tints your whole character toward its rarity color, and Boots gets the same real per-item icon treatment as the other slots.",
		"Real Player enemies (raid operators and Arena opponents) now visibly wear a rolled-up gear loadout of their own - helmet, body tint, backpack, accessory, boots, and a real weapon (correctly scaled and using the same weapon sprite art you get) instead of every single one looking like an identical fixed green-vest raider. Arena opponents specifically wear the same loadout already shown for them on the Current Teams panel.",
		"Real Player enemies also now sometimes bring a cosmetic pet along - purely for looks, no stat effect either way.",
	]},
]

# Combined timeline, oldest to newest - for anything that needs "the
# real latest version" or "the most recent entries" regardless of which
# of the two lists (archive vs. current) it actually lives in right now.
static func get_all_entries() -> Array:
	return CHANGELOG_ARCHIVE + CHANGELOG_CURRENT

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var close_button: Button = $Margin/VBox/CloseButton
@onready var tab_row: HBoxContainer = $Margin/VBox/TabRow

var _showing_archive: bool = false
var _tab_buttons: Dictionary = {}

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())
	var current_btn := Button.new()
	current_btn.text = "Current"
	current_btn.custom_minimum_size = Vector2(110, 32)
	current_btn.toggle_mode = true
	current_btn.add_theme_font_size_override("font_size", 12)
	current_btn.pressed.connect(func(): _switch_view(false))
	tab_row.add_child(current_btn)
	_tab_buttons[false] = current_btn

	var archive_btn := Button.new()
	archive_btn.text = "July 8 - 13"
	archive_btn.custom_minimum_size = Vector2(110, 32)
	archive_btn.toggle_mode = true
	archive_btn.add_theme_font_size_override("font_size", 12)
	archive_btn.pressed.connect(func(): _switch_view(true))
	tab_row.add_child(archive_btn)
	_tab_buttons[true] = archive_btn

	_switch_view(false)

func _switch_view(show_archive: bool) -> void:
	_showing_archive = show_archive
	for is_archive in _tab_buttons:
		_tab_buttons[is_archive].button_pressed = (is_archive == show_archive)
	_build_list()

func _build_list() -> void:
	for c in list.get_children():
		c.queue_free()
	var source: Array = CHANGELOG_ARCHIVE if _showing_archive else CHANGELOG_CURRENT
	if source.is_empty():
		var lbl := Label.new()
		lbl.text = "Nothing logged here yet - check back soon."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.modulate = Color(1, 1, 1, 0.6)
		list.add_child(lbl)
		return
	for entry in source:
		list.add_child(_make_row(entry))

func _make_row(entry: Dictionary) -> Control:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.1, 0.09, 0.7)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	row.add_theme_stylebox_override("panel", sb)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 2)
	row.add_child(outer)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	outer.add_child(header)

	var ver_lbl := Label.new()
	ver_lbl.text = "v%s" % entry.get("version", "")
	ver_lbl.custom_minimum_size = Vector2(52, 0)
	ver_lbl.add_theme_font_size_override("font_size", 14)
	ver_lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 0.95, 1))
	header.add_child(ver_lbl)

	var title_lbl := Label.new()
	title_lbl.text = entry.get("title", "")
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	header.add_child(title_lbl)

	for note in entry.get("notes", []):
		var note_lbl := Label.new()
		note_lbl.text = "  •  %s" % note
		note_lbl.add_theme_font_size_override("font_size", 11)
		note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		note_lbl.modulate = Color(1, 1, 1, 0.8)
		outer.add_child(note_lbl)

	return row

func open() -> void:
	visible = true
