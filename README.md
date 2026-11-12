# 织间 · The Art of Weaving

A small, calm knitting game. You pull a strand of yarn across the screen and hook it through the loops of the row below, one stitch at a time. Whether a stitch becomes a **knit** or a **purl** depends on which side of the fabric your yarn is on, so the only extra move you need is to **wrap** the yarn to the other side. Inspired by the tactile, no-fail feel of *A Little to the Left*.

AP6412 group assignment · **Route B** (one game, 2D and 3D versions).

| | |
|---|---|
| Engine | Godot **4.7** (GL Compatibility renderer) |
| Language | GDScript (statically typed) |
| Dependencies | None at runtime. `addons/godot_ai` is an editor-only development plugin and is not used by game code. |
| Repository | https://github.com/JOKILLER-git/TheArtOfWeaving |

## How to run

1. Install Godot 4.7.
2. Open Godot → **Import** → select `project.godot` in this folder.
3. Press **F5**. The game starts at the title screen (`scenes/app/game_app.tscn`).

## How to play

The game uses almost no text: every action is done with an object on screen.

| Action | How |
|---|---|
| Start | On the title screen, drag the yarn end on the left to the glowing spool on the right (or press **Enter**) |
| Pick up the yarn | Press and hold the left mouse button on the yarn tip |
| Make a stitch | Drag the tip **upward through the glowing eye** of the next loop |
| Move the yarn to the other side of the fabric | Drag the tip **around** the point where the yarn leaves the fabric (about three quarters of a turn) |
| Restart the level | Drag the **scissors** (bottom left) onto the yarn or fabric (shortcut **R**) |
| Hint | Appears automatically when idle, or press **H** |
| Choose a level | Pull down the little yarn loop hanging from the progress beads at the top: the beads unfold into a clothesline of level cards (finished swatch + best stars, or a pencil sketch). Click a card to play it; push the loop back up, click empty space or press **Esc** to close |
| Quit | On the title screen, drag the **scissors** onto the yarn |
| Back to title | **Esc** |
| Fullscreen / window | **F11** (the game starts fullscreen) |
| Gesture debug overlay | **F3** (hit zones, wrap guard, last ignored/rejected hook) |

Rules:
- Yarn **behind** the fabric (dark, thin) → hooking makes a **knit** stitch (V).
- Yarn **in front** (bright, thick) → hooking makes a **purl** stitch (horizontal bump).
- The chart card (top right) shows the target: `V` = knit, `—` = purl. Rows alternate direction, like real flat knitting.
- When a level is finished, 1–3 stars are knitted on screen (0 mistakes = 3 stars, up to 2 mistakes = 2 stars, otherwise 1), then the next level starts automatically. The beads at the top show progress.
- There is no failure state. Invalid actions are rejected gently:
  - wrong yarn side → the loop forms, slips off, a pencil hint appears, and it counts as a mistake;
  - hooking the wrong loop → the correct next eye flashes;
  - a level that starts with a mistake (level 3) → hooking is blocked, the wrong loop is circled and the scissors wiggle until you cut;
  - acting after a level is complete → ignored.

Levels (11): First Stitch → A Row → Snip (fix a mistake with the scissors) → First Purl → Purl Row → Turn (two rows) → Rib Row → Rib → Seed → Ridges → Basket. The end screen shows every finished swatch; pull the yarn again to replay.

## Project structure

```
scripts/core/              Game rules and data. RefCounted/Resource only; no Node, input or drawing.
  stitch_type.gd           abstract StitchType; knit_stitch.gd, purl_stitch.gd
  stitch_registry.gd       stitch lookup; which stitch a yarn side produces
  yarn.gd, fabric.gd       working-yarn side; grid of finished stitches
  knit_session.gd          rule state machine for one level; hook_result.gd
  fabric_layout.gd         geometry in "fabric coordinates" (columns/rows)
  data/                    PatternChart, LevelDefinition, LevelCatalog (Resources)
  gesture/                 GestureRecognizer (abstract), HookGesture, WrapGesture
scripts/presentation_2d/   2D rendering, mouse input, sound, chart card
scripts/app/               GameApp flow: title → levels → end screen; LevelSequence
resources/levels/          the four levels and the catalog (.tres)
scenes/app/                game_app.tscn (main scene), title/end screens
scenes/knit/               knit_level_2d.tscn (one level; runnable alone with F6)
tests/core/, tests/app/    rule and flow tests
```

Dependencies only point downward: `app` → `presentation_2d` → `core`. Gestures are recognised in fabric coordinates, so a 3D version only needs to project the mouse ray onto the fabric plane; the rules and recognisers are reused unchanged.

## Tests

Run from a running game (e.g. Godot's debugger / remote expression) or headless:

```
godot --headless --path . --script res://tests/core/run_core_tests.gd
godot --headless --path . --script res://tests/app/run_app_tests.gd
```

Last recorded result: core 174/174, app 131/131 passed.

Best stars per level are kept for the current run only, so every launch starts with all levels unlocked and none completed (demo-friendly). `ProgressStore` can persist them to `user://progress.json` by constructing it with its default path in `GameApp`.

## Versions (Git tags)

| Tag | Content |
|---|---|
| `v0-weaving-prototype` | Early loom-weaving gameplay (abandoned direction, kept as history) |
| `v0.1-knit-prototype` | Single-script knitting gesture prototype |
| `2d-baseline` | Frozen 2D version (core / presentation_2d / app layers) |
| `3d-final` | 3D version reusing the same core |

## Team and AI logs

| Member | Personal branch | AI log location |
|---|---|---|
| JOKILLER | `member/jokiller` | `ai-logs/jokiller/` |

AI (Claude) was used as a design partner and as implementation agents. Each implementation task is specified as a task card with acceptance criteria; agent reports were reviewed against screenshots and tests before merging. Full logs are in the folder above.
