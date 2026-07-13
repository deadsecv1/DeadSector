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
- Don't push unless explicitly asked, even if a previous message in the same
  session asked for a push — treat each push as a fresh request.
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
