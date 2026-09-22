# Hotel Growth Roadmap: Orchestration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver everything in [the hotel-growth spec](../specs/2026-09-22-hotel-growth-design.md): lawn color fix, a continuous building shell with hallways, lobbies and pavilions, multi-floor hotels with stairs and themed floors, a cat wardrobe, and the freeform wall tool. The work is split into six plans that subagents can execute while the main session orchestrates.

**Architecture:** Domain changes land first in pure C# (`Runtime/Domain`), where they are testable in seconds with the `tests/unity-domain` .NET harness. Presentation follows in Unity (`Runtime/Presentation`) against a stable domain API. Independent lanes run in separate git worktrees and merge in a fixed order.

**Tech Stack:** Unity 6000.3.24f1 (URP, uGUI/TextMeshPro, Input System), C# 9, Newtonsoft.Json, NUnit EditMode tests, .NET 9 console test harness, Unity CLI via `tools/unity.ps1`.

---

## Sub-plans

| # | Plan | Lane | Depends on | Size | Primary files |
|---|---|---|---|---|---|
| 01 | [Lawn color consistency](2026-09-22-hotel-growth-01-lawn-color.md) | B (art) | — | S | `GodotGeometry.cs`, `VoxelWorld.cs`, `LawnColorTests.cs` (new) |
| 02 | [Building shell domain + save v3](2026-09-22-hotel-growth-02-shell-domain.md) | A (critical path) | — | L | `HotelShell.cs` (new), `HotelModel.cs`, `HotelNavigation.cs`, `HotelState.cs`, `StrictSaveJson.cs`, `HotelValidation.cs` |
| 03 | [Shell rendering + mobile build tools](2026-09-22-hotel-growth-03-shell-presentation.md) | A | 02 | L | `VoxelWorldShell.cs` (new), `HotelShellUI.cs` (new), `VoxelWorldRooms.cs`, `VoxelWorldInput.cs`, `VoxelWorldPreview.cs` |
| 04 | [Floors, stairs, themed floors](2026-09-22-hotel-growth-04-floors-stairs.md) | A | 02, 03 | XL | `HotelShell.cs`, `HotelNavigation.cs`, `HotelLife.cs`, `HotelVisitors.cs`, `HotelState.cs`, `VoxelWorldShell.cs`, `HotelShellUI.cs` |
| 05 | [Cat wardrobe](2026-09-22-hotel-growth-05-wardrobe.md) | C | 02 Task 2 (save v3) | M | `HotelWardrobe.cs` (new), `CatOutfitView.cs` (new), `WardrobePanel.cs` (new), `Wardrobe.json` (new) |
| 06 | [Freeform wall tool](2026-09-22-hotel-growth-06-wall-tool.md) | A | 03 (04 recommended) | M | `HotelWallTool.cs` (new), `HotelShell.cs`, `HotelNavigation.cs`, `HotelShellUI.cs` |

```text
Lane B:  01 ───────────────────────────────────────────────▶ merge 1st
Lane A:  02 ──▶ 03 ──▶ 04 ──▶ 06                            ▶ merge after each plan
Lane C:        (after 02/T2) 05 domain ──▶ 05 presentation    ▶ merge after 03
```

## How far the plans were verified

Every **domain** task in plans 02–06 was applied mechanically, from the plan markdown itself, to scratch copies of `Runtime/Domain` + `tests/unity-domain` in merge order, then run in the .NET harness. Each task's test failed first as the plan says, then passed. The full stack reached `PASS 676123 checks` with the Godot oracle, life simulation and dense simulation green. Plan 05 was also verified alone on the plan-02 base (lane C's starting point).

**Unity presentation** tasks (plan 01 and the later tasks of plans 03–06) were **not** compiled during planning, because the editor was open on the user's working copy. For those, the per-task `tools/unity.ps1 Test` step and the Play-mode checks are the real gates. Reviewers should expect small signature fixes: helper names in `HotelUI`, rig axis directions, and the exact `SetCutaway` rule.

## Roles

| Role | Who | Responsibilities |
|---|---|---|
| **Orchestrator** | Main Claude session | Owns this roadmap. Creates worktrees, dispatches one fresh subagent per task with the brief below, runs the two-stage review, merges lanes, runs every gate, updates the checkboxes here and in the sub-plans, and asks the user for the decisions marked 🧑. |
| **Implementer** | `general-purpose` subagent, one per task | Executes exactly one task's steps with TDD, commits, and reports what changed plus the test output. Never edits outside the task's **Files** list without saying why. |
| **Spec reviewer** | `general-purpose` subagent | Checks the finished task against the spec section and the plan task: missing behavior, extra behavior, wrong messages or prices. |
| **Code reviewer** | `superpowers:requesting-code-review` / `code-review` skill | Correctness and code quality of the task diff; matches the file's density and idiom. |
| **Unity QA agent** | `general-purpose` subagent with the `unity:unity-cli` skill | Builds, runs the EditMode tests and QA smoke, and captures screenshots in the editor Game view or the built player. Compares against `docs/concept-art` and attaches captures under `docs/art/qa-shots/hotel-growth/`. |
| **Voxel art agent** | `general-purpose` subagent | Authors voxel part lists (wear items, themed furniture) in JSON, following `docs/art/STYLE-GUIDE.md`, and reviews them in captures. |

## Subagent brief template (orchestrator fills the brackets)

```markdown
You are implementing ONE task from a written plan in C:\Users\zach7\Repos\Projects\cat-hotel (worktree: [path]).
Plan file: [docs/superpowers/plans/…md], Task [N]: [title]. Read the whole task and the spec section it cites before editing.
Rules:
- Follow the steps in order: write the failing test, run it and confirm it fails, implement, run and confirm it passes, commit.
- Touch only the files in the task's **Files** list. If another file must change, stop and report why.
- Match surrounding code: this codebase writes dense one-line members. Keep that style in existing files; new files may be moderately formatted.
- Domain tests: `dotnet run --project tests/unity-domain` from the repo root; the final line must be `PASS <n> checks`.
- Do NOT open the Unity editor unless the task says so. If it does, use `tools/unity.ps1` (Test/Windows/QA).
- Commit with the message given in the task and end it with:
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Report back: the files changed, the exact test output tail, and anything you were unsure about.
```

## Orchestrator procedure

### Task 0: Prepare the branch 🧑

**Files:** none (git only)

- [ ] **Step 1: Ask the user how to handle the uncommitted WIP on `test/combined-screenshot-reality`**

`git status` shows 27 modified files plus untracked QA shots. Options to offer: (a) commit the WIP to that branch first (recommended), (b) stash it, (c) branch from `main` and ignore it. Don't choose for them, because the WIP touches `HotelModel.cs`, `HotelNavigation.cs` and `HotelState.cs`, which plan 02 edits.

- [ ] **Step 2: Create the integration branch**

```bash
git switch -c feature/hotel-growth
```

- [ ] **Step 3: Record the baselines**

```bash
dotnet run --project tests/unity-domain
```
Expected tail: `Building suite passed`, `God mode suite passed`, `PASS 675892 checks` (the count may differ if the WIP changed tests; record the actual number in this file).

```powershell
.\tools\unity.ps1 Test
```
Expected: exit code 0; `builds/unity/test-results.xml` written. Record failures, if any, as pre-existing.

- [ ] **Step 4: Commit this roadmap and the spec**

```bash
git add README.md CLAUDE.md docs/superpowers/specs/2026-09-22-hotel-growth-design.md docs/superpowers/plans/2026-09-22-hotel-growth-*.md
git commit -m "docs: Unity is the engine; hotel growth spec and implementation plans"
```

### Task 1: Create the lane worktrees

- [ ] **Step 1: Use the `superpowers:using-git-worktrees` skill** to create:

```bash
git worktree add ../cat-hotel-laneA -b feature/hotel-growth-shell feature/hotel-growth
git worktree add ../cat-hotel-laneB -b feature/hotel-growth-lawn feature/hotel-growth
```

Lane C (`feature/hotel-growth-wardrobe`) is created from lane A **after** plan 02 Task 2 is committed, so it inherits the v3 save types:

```bash
git worktree add ../cat-hotel-laneC -b feature/hotel-growth-wardrobe feature/hotel-growth-shell
```

Unity note: each worktree is a separate Unity project copy, and the first `tools/unity.ps1 Test` in a worktree imports `Library/` (slow, 5–15 minutes). Only one Unity process may use a given worktree at a time. Domain-only tasks never need Unity.

### Task 2: Run the lanes

- [ ] **Step 1: Lane B, plan 01.** Dispatch its tasks one by one. This lane needs Unity for captures. Gate: the plan 01 verification task.
- [ ] **Step 2: Lane A, plan 02.** Dispatch tasks 1→N sequentially; each task depends on the previous one. Gate: domain PASS after every task, plus EditMode tests at the end of the plan.
- [ ] **Step 3: Lane C, plan 05 domain tasks,** as soon as 02/T2 is committed. They run in parallel with the rest of lane A.
- [ ] **Step 4: Lane A, plan 03,** after plan 02 is merged into `feature/hotel-growth`.
- [ ] **Step 5: Lane C, plan 05 presentation tasks,** after plan 03 is merged (both edit `HotelUI` build and cat flows; this ordering avoids conflicts in `HotelUI.cs`).
- [ ] **Step 6: Lane A, plan 04,** then plan 06.

After each task, run the review loop:

1. The implementer reports.
2. Dispatch the spec reviewer with the task text and `git diff HEAD~1`.
3. Dispatch the code reviewer.
4. If either finds issues, send them back to the same implementer through `SendMessage` and repeat from step 2.
5. Tick the checkbox.

### Task 3: Merge order and conflict hotspots

- [ ] **Step 1: Merge in this order into `feature/hotel-growth`:** 01 → 02 → 03 → 05 → 04 → 06. Run the domain harness and `tools/unity.ps1 Test` after every merge.

Known textual hotspots (resolve by keeping both sides; none are semantic conflicts by design):

| File | Who touches it | Resolution rule |
|---|---|---|
| `HotelState.cs` | 02 (floors, floor fields, version 3), 05 (outfit, wardrobe) | Keep all fields. |
| `StrictSaveJson.cs` | 02, 05 | Keep both optional-field checks. |
| `HotelModel.cs` `ValidCore` | 02, 05 | Keep both null checks. |
| `tests/unity-domain/Program.cs` suite call line | 02, 04, 05 | Keep all `…Suites.Run…(Check,P,content);` calls. |
| `tests/unity-domain/Purrington.Domain.Tests.csproj` | 02, 04, 05 | Keep all `<Compile Include>` lines. |
| `HotelUI.cs` | 03 and 05 add one line each to route into new partial files | Keep both lines. |

### Task 4: Phase gates (orchestrator runs these; Unity QA agent captures)

- [ ] **Gate 1 (after 01 + 02):** domain PASS; EditMode PASS; an existing save migrates. Test this by copying a real profile save into `tmp/qa-profile`, launching the preview with `-purrington-profile tmp/qa-profile`, and checking that the hotel looks identical to before and that the lawn matches.
- [ ] **Gate 2 (after 03):** capture Meadow with a lobby, a hallway between two bedrooms, a window seat in the hallway and an outdoor pavilion, in portrait and landscape. Draw a room using touch in Device Simulator.
- [ ] **Gate 3 (after 05):** capture three dressed cats in care view and roaming; reload the save and confirm the outfits persist.
- [ ] **Gate 4 (after 04):** capture a two-floor hotel with stairs, the rooftop garden and the basement spa. Confirm a guest walks upstairs to a floor-1 bedroom (watch mode).
- [ ] **Gate 5 (after 06):** capture an L-shaped room built with the wall tool, with furniture and a guest inside.
- [ ] **Balancing checkpoint 🧑:** show the user a 10-minute play capture after Gate 4, with the constants table from plan 02 Task 2 and plan 04 Task 1. Adjust the prices only in those constants.

### Task 5: Finish

- [ ] **Step 1:** Update `unity/PurringtonHotel/README.md` "What is implemented" and "Known limits" with the shell, floors, wardrobe and wall tool.
- [ ] **Step 2:** Run the `superpowers:finishing-a-development-branch` skill (a PR from `feature/hotel-growth` to `main`).

## Idea backlog handoff

The spec's "Idea backlog" items marked **Next** each need a mini-spec (via `superpowers:brainstorming`) before planning. Suggested order once Gate 4 passes: Staff uniforms (small, reuses plan 05) → Sunbeam spots → Lobby charm score → Guest requests.

## Execution log (orchestrator)

Execution runs on `test/combined-screenshot-reality` (user's choice), one task at a time, no worktrees.

| Plan/Task | Commits | Review notes and follow-ups |
|---|---|---|
| 02/T1 | 448521c | Approved. |
| 02/T2 | e44c6aa, b804690, 3c3533b | Review caught that `SyncRoomWalls` made door edges order-dependent between touching rooms (a door lost to a neighbour's wall would make saves invalid once Task 4 lands). Fixed with doors placed first, plus migration guards (absurd sizes, overflow, v2 floor reset) and a requirement that v3 saves carry `floors`. |
| 02/T3 | d80281b, 0eba6b9 | Approved. **Follow-up for plan 04:** each shell wall edge is its own nav solid (roughly 2.5x more solids than legacy rooms), and the dense simulation clears floors, so it doesn't measure this. When plan 04 rewrites the wall-solid line, merge contiguous edges through `ShellDraw.Runs`, and add a migrated dense run. |
| 02/T4 | 5b39fe8, e658dac | Approved. The reviewer probed 3000 random v2 layouts, and every one still passes `Valid` after migration. Added load-gate tamper tests. The review found plan gaps: moving or resizing interior rooms broke, and a pricing loophole appeared (both handled in T5). |
| 02/T5 | deee9d6, b357c76, 8826be0 | Approved after scoped re-review. Move and resize carry the hotel, and a copy onto floor is repriced to fitting (a copy onto bare land stays a legacy pavilion, as the Godot oracle requires). The Critical draw-big-then-shrink pricing exploit is fixed in 8826be0. |
| 02/T6 | 7a332db | Approved. Player-editable walls, doors, windows and archways; domain suite PASS 676051 checks. |
| 02/T7 | c95adff | Approved. Hallway and lobby furniture uses indoor shell floor; wall and boundary crossing is rejected. Domain suite PASS 676060 checks. |
| 02/T8 | 6426174, fa4fd72, ec2be97 | Approved. Shell undo/redo and Unity script metadata. Domain suite PASS 676064; isolated committed-project Unity run passed 69/69 EditMode tests. |
| 01/T1–T2 | c1f9034, 4cd1b5b | Approved. World lawn swatches now drive owned parcel material colors. Isolated Unity run passed 72/72 EditMode tests, including 3/3 new lawn tests. Visual QA remains. |
