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
3. Press **F5**. The game starts at the title screen of the **3D version** (`scenes/app/game_app_3d.tscn`, the project's main scene).

### 2D and 3D versions

Both versions are the same game (same 11 levels, rules, gestures, stars, scissors, level select, title and end screens) and share `scripts/core/` unchanged. Only the presentation layer differs.

| Version | Scene | How to run |
|---|---|---|
| 3D | `scenes/app/game_app_3d.tscn` | **F5** (main scene) |
| 2D | `scenes/app/game_app.tscn` | Open the scene in the editor and press **F6** (Run Current Scene) |

Single levels can also be run alone with F6: `scenes/knit/knit_level_3d.tscn`, `scenes/knit/knit_level_2d.tscn`.
In 3D, the yarn really passes in front of / behind the fabric. **Right-drag** tilts the camera a little (up to ±20°); it springs back when released.
`GameApp` only knows the `KnitLevelView` interface; which version is played is chosen by its exported `level_view_scene` (the two app scenes differ only in that property).

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
| Switch 2D / 3D | On the title screen, click the **View** button (top right) before starting |
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
scripts/presentation_shared/  interfaces shared by 2D and 3D: FabricScreenMapper, KnitLevelView, YarnHandle
scripts/presentation_2d/   2D rendering, mouse input, sound, chart card (overlays are reused by 3D)
scripts/presentation_3d/   3D rendering: KnitLevel3D, CameraMapper3D, FabricView3D, WorkingYarn3D, TubeMesh3D
scripts/app/               GameApp flow: title → levels → end screen; LevelSequence
resources/levels/          the four levels and the catalog (.tres)
scenes/app/                game_app_3d.tscn (main scene, 3D), game_app.tscn (2D), title/end screens
scenes/knit/               knit_level_3d.tscn, knit_level_2d.tscn (one level; runnable alone with F6)
tests/core/, tests/app/, tests/presentation_3d/   rule, flow and 3D tests
```

Dependencies only point downward: `app` depends on the interfaces in `presentation_shared`; `presentation_2d` and `presentation_3d` implement them; everything depends on `core`, and `core` depends on nothing above it. Gestures are recognised in fabric coordinates, so a 3D version only needs to project the mouse ray onto the fabric plane; the rules and recognisers are reused unchanged.

## Tests

Run from a running game (e.g. Godot's debugger / remote expression) or headless:

```
godot --headless --path . --script res://tests/core/run_core_tests.gd
godot --headless --path . --script res://tests/app/run_app_tests.gd
godot --path . --script res://tests/presentation_3d/run_presentation_3d_tests.gd   # needs a window (camera projection)
```

Last recorded result: core 174/174, app 131/131, presentation_3d 168/168 passed (the 3D suite also re-runs every GameApp flow check against the 3D scene).

Best stars per level are kept for the current run only, so every launch starts with all levels unlocked and none completed (demo-friendly). `ProgressStore` can persist them to `user://progress.json` by constructing it with its default path in `GameApp`.

## Versions (Git tags)

| Tag | Content | Link |
|---|---|---|
| `v0-weaving-prototype` | Early loom-weaving gameplay (abandoned direction, kept as history) | https://github.com/JOKILLER-git/TheArtOfWeaving/tree/v0-weaving-prototype |
| `v0.1-knit-prototype` | Single-script knitting gesture prototype | https://github.com/JOKILLER-git/TheArtOfWeaving/tree/v0.1-knit-prototype |
| `2d-baseline` | **Runnable 2D version** (frozen; main scene `scenes/app/game_app.tscn`) | https://github.com/JOKILLER-git/TheArtOfWeaving/tree/2d-baseline |
| `3d-final` | **Runnable 3D version** reusing the same core (main scene `scenes/app/game_app_3d.tscn`; the 2D version is also included and selectable with the title-screen View button) | https://github.com/JOKILLER-git/TheArtOfWeaving/tree/3d-final |

All tags: https://github.com/JOKILLER-git/TheArtOfWeaving/tags

## GitHub evidence

| What | Link |
|---|---|
| 2D → 3D comparison | https://github.com/JOKILLER-git/TheArtOfWeaving/compare/2d-baseline...3d-final |
| Core rules unchanged in that comparison | `git diff 2d-baseline 3d-final -- scripts/core` (empty) |
| Pull request / merge history | https://github.com/JOKILLER-git/TheArtOfWeaving/pulls?q=is%3Apr |
| Commit history | https://github.com/JOKILLER-git/TheArtOfWeaving/commits/main |
| Personal branch (JOKILLER) | https://github.com/JOKILLER-git/TheArtOfWeaving/tree/member/jokiller |
| Personal branch ([Member 2]) | https://github.com/JOKILLER-git/TheArtOfWeaving/tree/member/[name] |
| Class maps | `docs/classmap/` (2D baseline and 3D final) |

## Team and AI logs

| Member | Personal branch | AI log location |
|---|---|---|
| JOKILLER | `member/jokiller` | `ai-logs/jokiller/` (index: `ai-logs/jokiller/INDEX.md`) |
| [Member 2] | `member/[name]` | `ai-logs/[name]/` (or a declaration that AI was not used) |

AI (Claude) was used as a design partner and as implementation agents. Each implementation task was specified as a task card with acceptance criteria; agent reports were reviewed against screenshots and tests before merging. Full chronological logs are in the folders above.
