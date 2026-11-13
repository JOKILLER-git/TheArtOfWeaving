# AI communication index — JOKILLER

This file is a guide to the full logs in this folder. It does **not** replace them: the complete, chronological prompts and responses are in the exported conversation file(s) next to this index.

**Tools.** Claude (claude.ai, one long conversation attached to the project "编织艺术") acted as *lead designer*: it discussed design with me, wrote design documents and task cards (T001–T009) with acceptance criteria, and reviewed results. Implementation was delegated to Claude *sub-agents* launched from that conversation. They edited the Godot project, ran it through the Godot AI editor plugin, injected mouse input, read logs and screenshots, and reported back. The dispatch prompts and the agents' reports are part of the exported conversation.

**My role.** I made the design decisions, playtested every round, accepted or rejected AI proposals, and ran all Git operations (commits, PRs, tags) myself.

## Chronology: requests → AI output → decision → evidence

| # | Date | My request / feedback | AI output | What I decided | Evidence |
|---|---|---|---|---|---|
| 1 | 11-08 | Discuss a knitting game built on stitch diagrams, style of *A Little to the Left*; my loom prototype with manual over/under selection was not fun | Proposed "the gesture is the stitch": hook through the loop's eye; over/under follows from the motion | Accepted the direction; first chapter is a tutorial | `design/chapter1_knitting_core.md` |
| 2 | 11-08 | "Make a prototype so I can see it" | Single-script prototype (wrote it without running Godot) | Accepted as a throw-away prototype | T001; tag `v0.1-knit-prototype` |
| 3 | 11-08 | Set up a designer / programmer split of AI chats | Workflow: task cards + `CLAUDE.md` rules + sub-agents | Chose sub-agents | `CLAUDE.md`, task template |
| 4 | 11-08 | Prototype never run → "run it, fix errors" | Agent found and fixed 2 type errors; listed feel problems | Asked for 4 design decisions back | T001 |
| 5 | 11-08 | Levels too long, loops too small, purl looks like knit, cannot tell which strand is in front | Auto-scaling, gap outlines, purl as a horizontal bump | Accepted; "下针像葫芦" left for art pass | T002 |
| 6 | 11-08 | Purl gesture ("press down") needs a detour; **my proposal**: make "wrap the yarn" a separate action that flips yarn side | AI agreed and proposed winding around the anchor; I proposed a tool alternative | Both built for comparison (M key) | T003 |
| 7 | 11-12 | Found course requirements → gap analysis | Listed missing Git, layered design, logs, report | Chose Route B; Git first | `planning/assignment_gap_analysis.md` |
| 8 | 11-12 | Set up GitHub | PowerShell setup script; diagnosed proxy error | Ran it myself; personal branch | tags `v0-weaving-prototype`, `v0.1-knit-prototype` |
| 9 | 11-12 | Refactor; keep **wrap** scheme | Architecture doc; core / presentation_2d split; 53 rule tests | Accepted the layering | T004, PR #1 |
| 10 | 11-12 | Full game flow; drop loom gameplay | GameApp, title/end screens | English UI accepted | T005 |
| 11 | 11-12 | Wider spacing, easier wrap, **no text UI** (pull yarn to start, scissors to restart, star screen), 11 levels from easy to hard | Diegetic UI, StarRating/LevelScore, preset-mistake level | Kept mistakes after cutting (no star farming) | T006 |
| 12 | 11-12 | "Sometimes I pass through the loop but no stitch forms"; English title; full screen | Reproduced and diagnosed **7 causes**, each with a regression test; F3 debug overlay | Accepted one known trade-off (fast curl from lower-left) | T007 |
| 13 | 11-12 | Scissors on title to quit, single-loop logo, level select that relates to yarn | Clothesline level select, PlayerProgress | Accepted | T008 |
| 14 | 11-12 | "Why are some levels already completed?" | AI explained: test runs had written to the save file | Progress per run for demos | commit `7f17290` |
| 15 | 11-12 | Freeze 2D; build 3D | KnitLevelView / FabricScreenMapper abstractions, presentation_3d; core unchanged | Accepted; asked for a 2D/3D View button | T009, PR #2 |
| 16 | 11-12 | "Why remove old code?" | Explained Class Map ↔ final code consistency | Removed legacy code | PR #3 |
| 17 | 11-12 | Check repository before submission | AI found `2d-baseline` tag on the wrong commit via `git diff` | Moved tag to `a728752` | tag `2d-baseline` |
| 18 | 11-13 | Report draft, class maps, presentation slides | Generated drafts | Reviewed and edited by us | `docs/classmap/`, report, slides |

## Examples of AI output that was corrected or rejected
- The first prototype had never been run and contained type errors (T001).
- "Press down = purl" gesture was rejected after playtesting (T003).
- A "pass between two stitches" toggle was rejected before building because it would conflict with normal hooking.
- Hook detection was not tuned blindly: failures were reproduced and diagnosed (T007).
- Persisted progress leaked test results into the demo (found by me during play).
- The `2d-baseline` tag was placed on the wrong commit; caught by checking `git diff` before submission.

## Files in this folder
- `INDEX.md` — this index
- `[exported conversation file(s)]` — full chronological prompts and responses (to be added)
- `task_cards/` — T001–T009 task cards with agents' reports (optional export from the Claude project)
