# Dropping in your own art

The game currently draws everything with code (vector shapes). If you want
to use real art (from Kenney.nl, itch.io, OpenGameArt, or anywhere else),
just drop image files into this folder with these exact names. The game
checks for them automatically at startup - no code changes needed. If a
file isn't here, the game falls back to the current vector art.

| File                  | Used for                          | Notes |
|------------------------|------------------------------------|-------|
| `player.png`           | Your character                     | Single top-down image, facing right (0°). It rotates automatically when you aim, and moves/bobs with the existing animation. |
| `enemy.png`             | Enemies                            | Same as above - single top-down image facing right. |
| `wall_tile.png`         | Walls / obstacles / house walls    | A small square texture (e.g. 32x32 or 64x64) that tiles seamlessly - it repeats to fill each wall regardless of size. |
| `ground_tile.png`       | The ground / floor                 | Same idea - a small seamless tile that repeats across the whole map. |

## Tips
- Kenney.nl's "Topdown Shooter" or "Top-Down Tanks Redux" packs have exactly
  this style of asset and are free/public domain.
- For `player.png`/`enemy.png`, a plain PNG with transparency works best -
  no need for a full animated spritesheet to get started (that's a bigger
  follow-up feature if you want it later).
- For `wall_tile.png`/`ground_tile.png`, make sure the edges of the image
  tile seamlessly (the right edge should visually continue into the left
  edge, same for top/bottom) or you'll see visible seams.
- Recommended path: put files directly in this `assets/` folder, i.e.
  `res://assets/player.png`, `res://assets/wall_tile.png`, etc.
