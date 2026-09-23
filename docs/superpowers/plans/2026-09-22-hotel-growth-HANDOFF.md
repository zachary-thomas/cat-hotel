# Hotel Growth: Handoff (2026-09-22)

## Current status (2026-09-22)

The implementation now includes all six plans, including stairs and themed floors (`5568dd1`, `a32cddc`) and the freeform wall tool (`8dae9a6`). The user asked to keep every feature in one PR and disabled the Superpowers workflow, so the task-by-task instructions below are historical context. Work continues directly on `test/combined-screenshot-reality` from the isolated `codex/hotel-growth-fast` worktree. The remaining steps are a final branch review, push, and one PR.

The combined domain suite passed **736,573 checks** with the Godot oracle green. Unity EditMode passed **81/81** after the wall tool landed. The Windows player built, and smoke QA passed startup, camera, navigation, care, panels, zoom, layouts, and save. The final wall tool adjustment passed its focused **24-check** suite. These checks do not replace a manual end-to-end playthrough of every floor and wall gesture.

The isolated Unity import modified font, render, and ProjectSettings assets during verification. They were left unstaged. Other unrelated live edits in the shared checkout were also left untouched.

Written by the orchestrating session for the next agent. Read this first, then the [roadmap](2026-09-22-hotel-growth-00-roadmap.md). Also read `CLAUDE.md` at the repo root.

## Current continuation (supersedes the older progress sections below)

Plans **02 (continuous hotel domain), 01 (lawn), 03 (shell presentation and build tools), and 05 (cat wardrobe)** are complete, task-reviewed and verified. Work is on the user-authorized `test/combined-screenshot-reality` branch. Plan 04 Tasks 1–5 are approved; the next implementation task is **Plan 04 Task 6, stairs, climbing cats and camera**, followed by the rest of Plan 04 and Plan 06 wall tool. The execution log in the roadmap has the commit list and review outcomes.

Plan 05 Task 4 was approved at `4be565c`. The domain suite passed **676111** checks, isolated Unity EditMode passed **79/79**, and a Windows player built. Four wardrobe QA images are committed, including an actual 390×844 care view, three dressed roaming guests, and a 36-case contact sheet. Three saved outfits reloaded. All roster rigs have the same native dimensions, so the small and large contact-sheet columns are explicitly labeled QA scale probes. The task report is `.superpowers/sdd/2026-09-22-hotel-growth-05-wardrobe/task-4-report.md`.

Plan 04 Task 1 is approved through `9bf0f29`: stairwell construction, floor unlocks and object floors pass **676174** domain checks with the Godot oracle. Reviews fixed stair removal/refunds, walls through landings, and disconnected upper/basement floor islands.

Plan 04 Task 2 is approved at `0c97a2a`: navigation links stair half-cells across levels and keeps walls, furniture, venues and slots on the correct floor. A 24-room migrated hotel retained 328 blocking edges merged into 128 runs, then completed 600 simulated seconds with 225 visits/18 guests in 5.6s CPU. The full domain suite passed **736190** checks with the oracle green. Task 3's brief is `.superpowers/sdd/2026-09-22-hotel-growth-04-floors-stairs/task-3-brief.md`.

Plan 04 Task 3 is approved at `8a2bba2`: a guest climbs the stair, reaches an upstairs bed and sleeps there. The floor-life tests also cover capacity, same-coordinate staffing on two floors, and a layout edit while a guest is upstairs. The full domain suite passed **736519** checks with the oracle green. Task 4's brief is `.superpowers/sdd/2026-09-22-hotel-growth-04-floors-stairs/task-4-brief.md`.

Plan 04 Task 4 is approved at `2afd1a4`: reachable furnished sunroom, garden and spa bonuses are +15/+20/+25 once per theme. Domain PASS **736549** and oracle green. Isolated Unity EditMode passed **79/79** after the CLI was run outside the filesystem sandbox, which had hidden the existing signed-in license and caused the earlier Licensing Client IPC stall. Task 5's brief is `.superpowers/sdd/2026-09-22-hotel-growth-04-floors-stairs/task-5-brief.md`.

Plan 04 Task 5 is approved at `833151f` plus `49ededa`: levels stack and hide above the viewed floor, with roof/parapet and stairwell openings. The review found lower-floor picks could leak through an empty upstairs hallway; the fix passed a red/green Windows player mouse-release check. Four temporary floor captures were inspected, and isolated Unity EditMode passed **80/80**. Task 6's brief is `.superpowers/sdd/2026-09-22-hotel-growth-04-floors-stairs/task-6-brief.md`.

Plan 03's committed-only Unity snapshot passed 76/76 EditMode tests, a Windows build and smoke QA. Its queued mouse/touch Bedroom scenario passed 21 layout cases. A further focused run passed **25/25** checks for phone gestures, Grow and room dimensions, the three wall openings and coin notices, visible Undo, and a named sale-plot quote. That run found one real UI gap, fixed and independently approved in `8711ac5`: cheaper edge replacements now say how many coins were refunded. The focused helper is ignored in the disposable snapshot; the production fix is committed. The final report is `.superpowers/sdd/2026-09-22-hotel-growth-03-shell-presentation/deferred-task-3-4-verification-report.md`.

Gate 2 visual review approved the four Meadow shell captures in `docs/art/qa-shots/hotel-growth/`, at 1080×2340 portrait and 2340×1080 landscape. They show a continuous hotel with lobby, hall, two bedrooms and suite, hall furniture, exterior openings, roof, and a separate pavilion. Touch verification used queued Input System events in a phone-sized hidden Unity player, not the editor's Device Simulator window.

Unrelated live edits remain in `HotelUI.cs`, `VoxelWorld*.cs`, `CatSpeechOverlay.cs`, a room-status file, welcome art and screenshots, and separate main-street/playable-polish documents. Preserve them; do not stage them with hotel-growth commits. The Plan 04 Task 6 brief is in `.superpowers/sdd/2026-09-22-hotel-growth-04-floors-stairs/task-6-brief.md`.

## Continuation update (later on 2026-09-22)

The sections below preserve the original handoff at commit `cb35d1f`. This update supersedes its progress and Unity-test notes.

- Plan 02 Task 5's `8826be0` pricing fix passed scoped re-review. Tasks 6–8 are committed and task-reviewed: `7a332db` (edges), `c95adff` (lobby furniture), `6426174` and `fa4fd72` (undo/redo), plus `ec2be97` (Unity script metadata). The domain harness reached **PASS 676064 checks**.
- The open Unity editor's test runner stalled after unrelated script reloads. A disposable project snapshot from committed code ran Unity EditMode tests successfully: **69/69 passed**, no failures, errors or skips. The snapshot lives in this plan's ignored `.superpowers/sdd` workspace; it did not touch the user's open scene.
- Plan 01 lawn Tasks 1–2 are committed and reviewed: `c1f9034` and `4cd1b5b`. The same disposable Unity project, updated with these commits, passed **72/72 EditMode tests**, including all three new lawn tests. Task 3, the four-map visual QA, is in progress in a separate disposable project.
- Next after lawn QA: plan 03, then 05, 04 and 06. Plan 03's task briefs and preflight ledger are in its own ignored `.superpowers/sdd` directory.
- Additional unrelated welcome-screen edits and art appeared in the working tree (`HotelUI.cs`, welcome screenshots/content). Preserve them along with the two main-street documents listed below; they are not part of hotel growth.
- Plan 01 visual QA is now complete. The first screenshots exposed a thin dark seam from the raised owned-parcel lawn slabs. Commit `87fbe63` skips those redundant owned slabs while leaving unowned sale dressing untouched. The updated four-map captures and a normal-mode sale-sign check passed re-review; the disposable Unity run passed **73/73 EditMode tests**. Next work starts at plan 03 Task 1.

## What the user asked for

1. **Lawn fix:** owned-plot grass doesn't match the world's ground color on the first map (and others).
2. **Rework expansion.** Buying plots feels boring, the hotel sprawls flat, and space runs out. The user wants:
   - a continuous building "shell" that can be expanded, with hallways, a lobby, and open space for scratchers and windows;
   - rooms placed inside the shell, and also outdoors;
   - both a rectangle room tool (option 1) and a Sims-style wall tool (option 3);
   - stairs and extra floors, with themed floors (sunroom, rooftop garden, basement spa).
3. **Cat clothing.**
4. **Brainstorm more ideas.** The backlog is in the spec.
5. **Make it clear the repo is moving to Unity.** Done: README banner, `CLAUDE.md`, and a memory entry.
6. Plan it all with superpowers (brainstorming, writing-plans), then execute with **superpowers:subagent-driven-development**, with the main session as orchestrator.

The user approved committing and pushing on the current branch: **`test/combined-screenshot-reality`**, tracking `origin`. Work happens directly on this branch, one task at a time. There are no worktrees, because the skill forbids parallel implementers.

## Key documents

| Doc | Purpose |
|---|---|
| `docs/superpowers/specs/2026-09-22-hotel-growth-design.md` | Spec, decisions and idea backlog |
| `docs/superpowers/plans/2026-09-22-hotel-growth-00-roadmap.md` | Orchestration: lanes, roles, gates, merge order, **execution log** (uncommitted additions) |
| `…-01-lawn-color.md` | Plan 01 (Unity presentation, 3 tasks) |
| `…-02-shell-domain.md` | Plan 02 (domain, 8 tasks), **in progress** |
| `…-03-shell-presentation.md` | Plan 03 (T1 domain, T2–T6 Unity) |
| `…-04-floors-stairs.md` | Plan 04 (T1–T4 domain, T5–T8 Unity) |
| `…-05-wardrobe.md` | Plan 05 (T1 domain, T2–T4 Unity) |
| `…-06-wall-tool.md` | Plan 06 (T1 domain, T2–T4 Unity) |

Per-task extracts of plan 02 live in the session scratchpad (`…/scratchpad/tasks/p02_t*.md`), which may not survive. Re-extract any task by taking its `### Task N` section from the plan file.

**How much of the plans is proven:** during planning, every domain task in plans 02–06 was applied mechanically from the plan markdown to a scratch copy and passed the .NET harness, reaching 676,123 checks for the full stack. Unity presentation tasks were **never compiled**, because the user has the Unity editor open on this project.

## How to run and test

- **Domain tests (no Unity needed):** from the repo root, `dotnet run --project tests/unity-domain`. It takes about 1–2 minutes. The last line must read `PASS <n> checks`.
- **The "Godot oracle construction/maps" section guards parity.** Never edit the oracle to make a change pass. The user moved the project to Unity, but the oracle still fixes legacy construction semantics.
- **Unity tests:** `.\tools\unity.ps1 Test` currently **fails to start**, because the editor has the project open (`Temp/UnityLockfile`).
  - For Unity tasks, either ask the user to close the editor, or use the `unity:unity-cli` skill to drive the running editor, for example to run tests or C# in the live editor.
  - The open editor recompiles changed scripts automatically, so domain changes compile in it already.

## Progress

### Done and committed (HEAD `8826be0`, all pushed to origin)

| Commit | What |
|---|---|
| `4567722` | The user's prior Unity work in progress (committed at their request) |
| `a57a7cb` | Docs: Unity banner, `CLAUDE.md`, spec, 7 plans (**pushed**) |
| `448521c` | 02/T1: grid helpers `ShellGrid`, and the `FloorState`/`EdgeState` types |
| `e44c6aa` `b804690` `3c3533b` | 02/T2: save v3 plus lossless v2→v3 migration. Review fixes: `SyncRoomWalls` is two-pass (doors first, so touching rooms keep their doors); migration skips absurd rooms and sets floor 0; overflow-safe guards; v3 saves must carry `floors` |
| `d80281b` `0eba6b9` `5590ee7` | 02/T3: navigation walls come from shell edges; indoor cells are walkable; constructed-graph test |
| `5b39fe8` `e658dac` | 02/T4: per-tile `paint_floor`/`erase_floor` with plot auto-buy; `ValidateShell` now gates `Valid`; load-gate tamper tests; God-mode tiles are stored free |
| `deee9d6` `b357c76` | 02/T5: interior rooms at fitting price (45% of pavilion); `draw_room`. Addendum: `move_room`/`resize_room` of an interior room auto-paint the missing floor. `copy_room` onto floor is repriced to fitting; onto bare land it stays a legacy full-price pavilion, which the oracle requires |

Harness at `b357c76`: **PASS 676028**.

### Last step before handoff

`8826be0` fix(domain): price interior resizes by fitting; refuse bad drawings early. This fixes a Critical exploit found in code review: interior-room `resize_room` used the legacy 25/tile diff, so a player could draw a big room and shrink it for a free room. Interior resizes are now priced by the change in fitting, with refunds capped at what was paid. A pavilion moved into the hotel is refunded down to fitting and never charged more. `draw_room` checks `RoomShape` before building its missing-cell list. Harness: **PASS 676034**.

**It has NOT been re-reviewed.** The next agent should first dispatch a code quality re-review of `b357c76..8826be0` (it was a response to Task 5's "Changes requested"). Once that is approved, mark plan 02 Task 5 done and continue with Task 6.

### Remaining work, in order

**Merge order:** 02 → 01 → 03 → 05 → 04 → 06. Plan 01 needs Unity, so it was deferred behind 02.

1. **Plan 02**
   - T5: re-review `8826be0`.
   - T6: `set_edge` for doors, windows, walls and archways.
   - T7: furniture in hallways and lobbies.
   - T8: undo test, plus the Unity compile gate, which needs the editor closed or the live-editor route.
   - Then tick the plan's checkboxes and push.
2. **Plan 01, lawn** (Unity):
   - Root cause: owned-parcel lawns in `GodotGeometry.json` use their own swatches, which differ from each map's 400×400 world ground. Meadow `#60a830` remaps to olive `#82934D`, against sage `#83a36e`.
   - Fix: `GodotGeometry.LawnColor`/`Recolor` and `VoxelWorld.BuildOwnedPlots`.
3. **Plan 03**
   - T1 (domain): `RoomState.door` side, `ShellDraw` helpers, `RoomDraft`.
   - T2–T6 (Unity): shell rendering, touch input, Hotel build tools, pavilion wording, QA.
4. **Plan 05, wardrobe**
   - T1 (domain, independent of 03/04).
   - T2–T4 (Unity).
5. **Plan 04, floors and stairs**
   - T1–T4 (domain): floor rules and stairs, 3D navigation, life across floors, themed room income.
   - T5–T8 (Unity).
6. **Plan 06, wall tool**
   - T1 (domain).
   - T2–T4 (Unity).
7. **Finish:** update the Unity README, run a final whole-branch review, then `superpowers:finishing-a-development-branch`.

### Plan text that no longer matches the code

These review-driven changes made the plan docs stale, so the next implementers need to know about them:

- **Plan 02 T2:** `SyncRoomWalls` is now two-pass, and `Upgrade` has guards. The anchor strings later plans use are preserved: `h.rooms.Where(v=>v.floor==f.level&&IndoorKind(v.kind)&&Interior(h,v))`, `new[]{r.rotation}`, `Numbers(r,"floor",true,true);`.
- **Plan 02 T4/T5:**
  - Apply now has `RoomState r=null;`, plus a pre-switch `editedRoom`/`wasInterior` line.
  - There is a post-switch block for move/resize/copy just before `SyncRoomWalls(h);`.
  - **Plan 04 Task 1** anchors on `r.paid=cost=Price(Interior(h,r)?Fitting(r):Shell(r));h.rooms.Add(r);break;` and `case "draw_room":{int level=(int?)p["floor"]??0;`. Both still exist.
  - **Plan 04 Task 1** also adds `OpenLanding` for stairs. When plan 04 runs, check that the new resize-by-fitting logic doesn't mis-price stairs (stairs can't be resized meaningfully; consider refusing resize and move for `stairs`).
- **Plan 03 T4** registers suites after `ShellSuites.RunShellUndo`, but Program.cs has since gained `RunShellLoadGate` and `RunInteriorEdits`. Register new suites anywhere after them; order doesn't matter.

### Open review follow-ups (logged in the roadmap's execution log)

- Each shell wall edge is its own navigation solid, roughly 2.5× more solids than legacy rooms. The dense simulation clears floors, so it doesn't measure this. When plan 04 rewrites the wall-solid line, merge contiguous edges using `ShellDraw.Runs`, and add a migrated dense run.
- `ValidateShell` re-reads map scenery for every cell, about 1.4 ms per call. Cache the protected rectangles if `Quote` runs every frame during drags.
- Messages:
  - `draw_room` replaces the "Bought plot" message with "Room added".
  - A too-low "Need N more coins" can appear from the nested validation.
  - Painting under a pavilion gives a room-oriented error message.
- Plan 02 T7 will reject furniture that straddles walls. Floors painted under straddling or outdoor-only objects between T4 and T7 could fail validation on load; these are dev saves only.
- Room-owned edges pointing at missing rooms aren't cross-checked on load; `SyncRoomWalls` self-heals them on the next command.

## Process being followed (per task)

1. Extract the task text and dispatch an **implementer** (`general-purpose`, sonnet) with the task text, repo and branch context, test commands, "don't run Unity", and "stop if an anchor or the oracle breaks". Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
2. **Spec reviewer** (sonnet) verifies the diff against the task text and must not trust the report.
3. **Code quality reviewer** (opus for risky domain work) uses the `requesting-code-review` template, with base and head SHAs.
4. Send fixes back to the **same implementer** through SendMessage, then re-review. Minor items become logged follow-ups.
5. Keep the roadmap execution log updated. Don't stage the roadmap in implementer commits.

## Decisions made (and why)

| Decision | Why |
|---|---|
| Per-tile growth at 20 coins/tile; doors 20, windows 15, walls 5, archways 10 | Recommended default. The user didn't answer the per-tile vs chunks question. **Revisit at the balancing checkpoint.** |
| Interior room fitting = 45% of the pavilion price | A 4×3 bedroom plus floor costs about the old 450 |
| Floors unlock at hotel level 3 (upstairs), 5 (rooftop), 7 (basement) | Pacing default |
| Themed rooms reuse existing items (perch, planters, fireplace), +15/+20/+25 coins/min | Avoids new art for v1 |
| `copy_room` onto bare land stays a full-price pavilion | Required by the Godot oracle; not a loophole |
| Rooms keep legacy `RoomShape`; plan 03 adds a `door` side field | The legacy shape rules force doors onto the short side, and loosening them would break the oracle |

## Other things in the working tree (not ours)

`docs/superpowers/plans/2026-09-22-main-street.md` and `docs/superpowers/specs/2026-09-22-main-street-design.md` are untracked. They appeared mid-session from another session or the user. **Don't commit or modify them** unless asked.

## Notes for the user

- The task-tracker connectors (Linear, Asana, Notion and others) aren't authorized, so no tickets exist.
- The roadmap asks for a 🧑 balancing checkpoint after Gate 4 (floors), and screenshot gates 1–5 once the Unity work lands.
