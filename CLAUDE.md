# Dead Sector

Godot 4.7 raid-extraction shooter. Solo-developed. This file captures durable,
repo-specific conventions — the "why" behind patterns you'll see across the
codebase, so a fresh session doesn't have to rediscover them from scratch.

## Locations

- Project source (this repo): `D:\!Godot Dead Sector`
- Build output: `C:\!Game Dead Sector\git\` (`DeadSector.exe` / `DeadSector.pck`)
- GitHub: `deadsecv1/DeadSector`
- Godot 4.7 editor binary: `C:\Users\srrwz\OneDrive\Desktop\Godot_v4.7-stable_win64.exe`
- Third-party art/asset packs (25+ licensed packs, cleared for use in this
  game): `C:\Users\srrwz\Downloads\assets\` — check here before suggesting a
  new download for any art need.

## Git workflow

- Stage files explicitly (`git add <specific files>`), never `git add -A` or
  `git add .` — this repo mixes source with generated `.import` files and
  it's easy to sweep in something unintended.
- Create new commits rather than amending, unless explicitly asked to amend.
- Standing authorization (given 2026-07-14): push to `main` whenever it's
  judged appropriate, no need to ask first each time. (Previously this said
  to treat every push as a fresh request — the user explicitly lifted that
  for pushes specifically. GitHub Release publishing is separate and still
  follows the manual hand-off workflow below.)
- When exporting a build, always explicitly confirm the exe path is rebuilt
  and ready — don't just say "boots clean."

## Testing without the editor UI

Headless Godot works fine for verification and is the default way to check
changes in this project:

```
"<godot exe path>" --headless --path . --import          # reimport assets after adding/changing them
"<godot exe path>" --headless --path . scenes/Foo.tscn    # boot a specific scene, check for errors
```

Known harmless noise to ignore when reading headless output — none of these
indicate a real problem:
- `ERROR: BUG: Unreferenced static string to 0: ...` and RID/PagedAllocator
  "leaked at exit" messages — engine teardown noise on process exit.
- Running a bare script with `-s` (not a full scene boot) produces cascading
  "Identifier not found: GameManager" (or `Sfx`, etc.) errors across many
  unrelated scripts — autoloads simply don't resolve in that harness mode.
  A real full scene boot (`--path . scenes/Foo.tscn`) is the ground truth;
  trust that over bare-script output.
- Booting `scenes/Stash.tscn` specifically throws exactly 2x
  `ERROR: Cannot set object script. Parameter should be null or a reference
  to a valid script.` during scene instantiation (before any `_ready()`
  runs). Confirmed harmless: a full post-boot tree walk shows every node
  that should have a script (all 7 `DystoBG`/`PetsBG` instances across
  Stash and its nested sub-panels, which all share the same cached
  `DystopianBackground.gd` resource) ends up with the correct script
  attached — it's a transient, self-correcting Godot engine quirk tied to
  this scene's unusually deep nested-scene structure, not a real bug. (An
  earlier session's memory wrongly attributed this to `_setup_alpha_beta_
  visuals()` existing in 3 duplicated files — verified 2026-07-14 that
  function only exists in `InventoryTile.gd`, every `set_script()` call
  in it and in `Stash.gd`'s doll-slot code succeeds, and the error still
  appears with all of that code fully instrumented and traced clean.)

A headless boot only proves the scene parses and runs without error — it says
nothing about whether a *visual* change (new icon, card styling, layout)
actually looks right, since `--headless` has no real rendering pipeline (a
`get_viewport().get_texture()` capture attempt under `--headless` silently
produces nothing). For visual/UI changes, verify with an actual rendered
screenshot instead, using a throwaway test scene:

```gdscript
# scratch_test/screenshot.gd — delete the whole scratch_test/ folder when done
extends Node
func _ready() -> void:
	get_window().size = Vector2i(1280, 800)
	var inst = load("res://scenes/Foo.tscn").instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://scratch_test/shot.png")
	get_tree().quit()
```

Run it **without** `--headless` (`"<godot exe path>" --path . scratch_test/Screenshot.tscn`) —
this is a real GPU-rendered window, not headless, so it only works because
this is a local dev machine with a display/GPU actually present. It renders
correctly and self-closes via `get_tree().quit()` without needing anyone to
interact with it. Reimport (`--import`) after adding the test scene/script
before running it. Then view the saved PNG directly with the Read tool (crop
with Pillow first if you need to zoom into a small detail).

## Persistent test suite (`tests/`)

Unlike `scratch_test/` (thrown away after one-off verification), `tests/` is
a real, repeatable regression suite that stays in the repo. Run it after
any feature work, not just when adding new tests to it:

```
"<godot exe path>" --headless --path . tests/TestRunner.tscn --quit-after 60
```

Exits with code 0 if everything passed, 1 if anything failed — safe to check
`$LASTEXITCODE` (PowerShell) / `$?` (bash) against. It boots as a real scene
(not `godot -s`) specifically so the `GameManager`/`Sfx`/etc. autoloads
actually resolve — a bare `-s` script does not initialize autoloads at all
(see the harmless-noise note above for what that failure mode looks like).

Add a new test by dropping a `tests/test_*.gd` file that `extends TestCase`
(`tests/TestCase.gd`) and defining any number of `test_*()` methods —
`TestRunner.gd` discovers and runs them automatically, no manual
registration. Assertion helpers: `assert_true/false/eq/ne/gt/gte/null/
not_null/has`. A test that needs a scene tick (e.g. waiting on a
`call_deferred()` scheduled from another script's own `_ready()`, like
Enemy.gd's `_find_player`) can just `await get_tree().process_frame` inside
the test method itself - the runner awaits every test call either way.
GDScript has no try/catch, so a genuine script error inside a test aborts
that test immediately rather than being caught - keep test bodies to
assertions and simple setup.

When you build something a future regression could silently break -
a reward table that must stay strictly increasing, a generator whose
geometry math could quietly go negative, a bug you just fixed - add a
test for it here rather than only verifying by hand once.

## Art pipeline: fallback-to-real-art convention

Most drawable entities (Enemy, Car, Barrel, Crate, DebrisStash, Wall, ...)
follow the same pattern: they're built as procedural vector shapes
(`Polygon2D`/`_draw()`), and at `_ready()` they check for a real sprite at a
conventional path (e.g. `res://assets/enemy_<type_id>.png`,
`res://assets/vehicles/car.png`, `res://assets/props/barrel_<n>.png`,
`res://assets/wall_tile.png`). If the file exists, it's loaded and the vector
shapes are hidden; if not, the vector fallback silently keeps working. This
means:
- Adding real art to an existing entity is usually just "drop the right file
  at the right path" — no code changes needed.
- When an entity has multiple instances that should look varied (parked cars,
  barrels, crates), the convention is to pick a random variant per-instance
  from a small numbered set (`car_scrap.png` / `barrel_1.png`..`barrel_4.png`
  / etc.), not one fixed asset.
- Set `CanvasItem.TEXTURE_FILTER_NEAREST` on sprites sourced from genuine
  pixel-art packs (blocky, low-res) — the project's default texture filter is
  Linear, which blurs chunky pixel art when scaled up. Sprites that are
  painted/rasterized rather than pixel art (player, enemy, NPC portraits)
  don't need this override.
- Before integrating any asset-pack sprite, verify perspective/scale/style
  actually fits by viewing it (not just trusting the filename) — a mismatch
  is easy to miss and hard to unsee once it's in.
- Don't trust old changelog entries or bug-report summaries claiming an art
  issue was "already fixed" — verify the actual file on disk (pixel content,
  dimensions, byte-for-byte diff against a suspected duplicate) before relying
  on that claim. This has been wrong before.

## Design philosophy: simulated multiplayer

Global Chat, Find a Team, Leaderboards, Arena matchmaking, and similar
"multiplayer-flavored" features are all simulated client-side — there is no
real netcode. This is intentional, not a bug or a shortcut to fix. Don't
"discover" this and try to wire up real networking unless explicitly asked.

## Save data

Single JSON file at `user://savegame.json`, which Godot maps on Windows to
`%APPDATA%\Godot\app_userdata\Dead Sector\savegame.json`. `save_game()`/
`load_game()` in GameManager.gd. A few things worth knowing before touching
either function:

- **Format version**: `SAVE_FORMAT_VERSION` (GameManager.gd) - bump this
  when a load-time migration actually needs to run, not on every field
  addition. Most new fields are read with `.get(key, default)` at load time
  and don't need a version bump at all - only bump it if an old save would
  otherwise load into a broken/inconsistent state.
- **Rotating backup**: every `save_game()` call renames the previous
  `savegame.json` to `savegame.json.bak` before writing the new one, and
  `load_game()` automatically falls back to the `.bak` file if the primary
  is missing or fails to parse (e.g. a crash mid-write). This protects
  against a corrupted *last* save, not against something several saves
  back - the single backup generation gets rotated away too.
- **Pre-wipe backup**: `reset_character()` (the in-place Delete
  Character/Wipe, see below) separately copies whatever's on disk to
  `savegame.prewipe.json` *before* changing anything in memory, specifically
  because the rotating backup above doesn't survive long enough to undo an
  accidental wipe once the player finishes Character Creation and plays a
  couple more saves. There's no in-game "restore" button for this (nobody's
  asked for one) - if the user says they wiped by mistake, the fix is
  manually copying `savegame.prewipe.json` back over `savegame.json` in
  that `app_userdata` folder (with the game closed) and confirming they
  don't already have a save newer than the backup they'd be restoring.

## Godot gotchas that have caused real bugs here

- Scene tree `_ready()` order: children ready before parents. Code that
  connects to a child's signal in the parent's own `_ready()` can miss a
  signal the child already emitted during its own `_ready()`.
- `PackedScene.instantiate()` does not trigger `_ready()` until the instance
  is actually added to a live tree.
- Anchors/offsets can read back as `0,0,0,0` at runtime instead of their
  designed values on some popup panels. Where this has been hit, the fix is
  to force the exact designed anchor + offset values in the panel's `open()`
  rather than trusting the `.tscn`-authored defaults.

## Controller/gamepad support

Full gamepad support is an ongoing, additive layer on top of the existing
keyboard/mouse-only code — every call site keeps working unmodified for
keyboard/mouse; gamepad checks are OR'd in alongside, never replacing the
original. Single local player, device 0 only, no rebind UI for gamepad
(keyboard rebinds already apply automatically — see below).

**Core gameplay input** (`GameManager.gd`): `is_action_pressed(action)` is
the drop-in replacement for `Input.is_key_pressed(get_keybind(action))` —
checks keyboard first, then falls back to `JOYPAD_BUTTON_BINDINGS[action]`
if the action has a gamepad mapping. `get_movement_vector()`,
`is_shoot_pressed()`, `is_aim_down_sights_pressed()`,
`get_gamepad_aim_direction()`, `is_hotbar_next/prev_pressed()` are bespoke
siblings for things that aren't simple button binds (analog stick,
mouse-button-as-trigger, stick-direction-as-aim-point). `_get_aim_point()`
(on `Player.gd` and `GauntletPlayer.gd`) is the aim-direction synthesis:
returns a point 1000 units out along the right stick's direction when
pushed past deadzone, else falls back to `get_global_mouse_position()` — so
every existing mouse-position-based aim/look_at/vision-cone call site works
unmodified regardless of input device.

`is_pause_pressed()` (D-pad Up) and the chat-open/close gamepad checks in
`GlobalChatBox.gd` are deliberately **not** routed through
`JOYPAD_BUTTON_BINDINGS`/`is_action_pressed()` — Escape and the chat toggle
are fixed system conventions on keyboard too (never part of the rebindable
`keybinds` dictionary), so their gamepad equivalents are kept just as fixed.

**Every popup's "Escape closes this" handler** got the same one-line
gamepad equivalent added (a project-wide sed sweep across 64 files,
2026-07 — see git history if you need the exact commit). The pattern, if
you're adding a new popup:
```gdscript
if visible and (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
```
Keep the whole OR'd expression in ONE set of parens like this — `and`
binds tighter than `or` in GDScript, so splitting it into two separately-
parenthesized clauses OR'd at the top level silently breaks whatever
prefix condition (`visible and ...`) was meant to gate both of them.

**Menu/inventory UI navigation** (`GameManager.gd`, foundation built for
Stash, rolled out panel-by-panel from there — grep any of the files below
for a template): every menu is built from plain Godot `Control`s, so
navigation reuses Godot's own focus system rather than a parallel one.
- `focus_first_control(container)` — call once when a panel/screen becomes
  visible (its `open()`, or right after `.visible = true` for panels
  toggled from outside) so a gamepad player has somewhere to start. Do
  **not** call this from an always-present raid HUD element's `_ready()`
  (`VicinityPanel`, `InGameInventory`) — that would steal focus from live
  gameplay input. Call it instead at the exact moment the containing panel
  actually opens (e.g. `HUD.gd`'s Tab-toggle and search-auto-open branches).
- Any custom `Control`-based tile/slot (not already a `Button`, which
  defaults to focusable) needs `focus_mode = Control.FOCUS_ALL` set
  explicitly, or a gamepad player can never land focus on it.
- `try_gamepad_pickup_or_place(control)` / `handle_gamepad_slot_input(event,
  control)` are the controller-friendly stand-in for drag-and-drop — they
  call a slot's own EXISTING `_get_drag_data()`/`_can_drop_data()`/
  `_drop_data()`, the same three functions a real mouse drag already uses,
  so there's no second copy of equip/move logic anywhere. Wire any new
  drag-and-drop slot with:
  ```gdscript
  func _gui_input(event: InputEvent) -> void:
      if GameManager.handle_gamepad_slot_input(event, self):
          accept_event()
  ```
  A slot's `_get_drag_data()` that builds a real drag preview must skip
  that (and the `set_drag_preview()` call) when
  `GameManager.gamepad_probing_drag_data` is true — `set_drag_preview()`
  hard-asserts the viewport is mid-mouse-drag, which is never true for a
  gamepad-driven probe, and calling it anyway both spams an engine error
  and leaks the never-parented preview Control. See `InventoryTile.gd`/
  `EquipSlot.gd`/`PocketSlot.gd`/`GauntletLootTile.gd` for the guard shape.
- A free-form Tarkov-style grid (`InventoryGrid.gd`) has no per-cell
  Control to focus, so it's made focusable AS A WHOLE (`focus_mode` +
  the same `_gui_input` hook) — a gamepad player can only drop "into this
  grid" (landing wherever the existing collision-fallback logic already
  picks, same safety net a sloppy mouse drop already relies on via
  `_next_free_cell_*`/`_move_item_in`), not choose an exact empty cell.
  This is an accepted, honest limitation, not a bug to work around.
- `cancel_gamepad_hold_if_within(container)` — call at the top of any
  `refresh()`/rebuild that frees a container's children, so a held gamepad
  pickup never dangles a reference to a freed Control.
- The "lifted" visual tint on whatever's currently held is centralized in
  `GameManager` (`GAMEPAD_HELD_TINT`/`_reset_gamepad_held_visual()`) —
  don't reimplement it per panel.

**Known test-environment limitation** (see `tests/test_gamepad_input.gd`):
`Input.parse_input_event()` for a joypad button/axis never updates
`is_joy_button_pressed()`/`get_joy_axis()` in a headless/no-controller
environment (confirmed by hand) — only keyboard simulation actually works
that way in tests. Joypad-specific code paths are instead tested for what
actually matters when no controller is connected: calm `false`/`0.0`,
never an error. Directly constructing an `InputEventJoypadButton` and
calling a node's `_unhandled_input()`/`_gui_input()` method with it
directly DOES work reliably in tests, since it bypasses the global `Input`
singleton entirely (see `tests/test_gamepad_popup_close.gd`).
