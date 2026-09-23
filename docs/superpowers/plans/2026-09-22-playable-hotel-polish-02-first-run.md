# Playable Hotel First Run Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the polished live Meadow House into a calm first-time experience that reveals cats, building, and destinations one at a time without blocking free play.

**Architecture:** Store a small per-profile introduction stage in the version-3 hotel save. After the existing illustrated welcome screen, use the live exterior facade for a one-action reveal, then show one optional next-step card at a time. The existing five tabs remain usable; the final merged Map remains the destination picker.

**Tech Stack:** Unity 6000.3.24f1, C# 9, uGUI/TextMeshPro, Input System, Newtonsoft.Json, .NET 9 domain harness, NUnit EditMode.

**Spec:** [playable hotel polish design](../specs/2026-09-22-playable-hotel-polish-design.md). **Dependency:** integrated hotel-growth and Main Street work, landed welcome/placement-preview changes, then the [world-art plan](2026-09-22-playable-hotel-polish-01-world-art.md), including `VoxelWorld.FrameHotelReveal()`.

## Global Constraints

- Preserve the existing uncommitted welcome screen and its **Open your hotel** action. The live game, not menu art, must carry the next scene.
- Fresh starter stage is 0; a version-3 save without the new field defaults to 4 (completed); Reset returns to stage 0.
- Stage 0 reveal, 1 cat care, 2 any successful item placement, 3 Map discovery, 4 complete. Any stage can be skipped without cost. Only one prompt appears at once.
- Do not change travel prices, automatically grant future destinations, force a build purchase, or put profile progress in global PlayerPrefs.
- Keep the five tabs and Back behavior, text scaling, safe areas, reduced motion, and the 35% world viewport rule.

---

## File map and interfaces

| File | Responsibility |
| --- | --- |
| `Runtime/Domain/HotelState.cs`, `StrictSaveJson.cs`, `HotelModel.cs` | Persist `int introductionStage`; expose `AdvanceIntroduction(int expected)` and `SkipIntroduction()` with save rollback. |
| `Runtime/Presentation/HotelJourneyUI.cs` (new `HotelUI` partial) | Build the live reveal and one suggestion card, handle action completion, and show a compact **Your journey** list. |
| `Runtime/Presentation/HotelUI.cs`, `HotelParityUI.cs`, `HotelApp.cs` | Hook welcome-to-world, successful care/build, Map close, and view button into the partial; leave `ParityMapPanel` layout to the Map-owning work. |
| `Runtime/Presentation/VoxelWorld.cs` | Use `FrameHotelReveal()` and `SetCutaway()`; do not duplicate the art kit. |
| `tests/unity-domain/IntroductionSuites.cs` and `Program.cs` | Test fresh/legacy/reset stages, monotonic progress, skip, and save failure. |
| `Tests/EditMode/IntroductionUITests.cs` and `ParityInputAcceptance.cs` | Test visibility, Back, selection, screen sizes, and reduced motion. |

### Task 1: Per-profile introduction state

**Files:** Modify `HotelState.cs`, `StrictSaveJson.cs`, `HotelModel.cs`, `tests/unity-domain/Program.cs`; create `tests/unity-domain/IntroductionSuites.cs`.

**Interfaces:** `HotelState.introductionStage` is an integer in 0…4. `HotelModel.AdvanceIntroduction(int expected)` advances exactly one step when current stage equals `expected`; `SkipIntroduction()` moves any incomplete stage to 4. Both return `CommandResult` and save transactionally.

- [ ] **Step 1: Write failing domain tests** for: fresh starter 0; a serialized existing v3 save with the new JSON property removed loads at 4; stage 0→1 succeeds; a repeated or out-of-order advance fails without mutating the save; Skip moves stage 1→4; a store that rejects writes rolls back stage and returns failure; Reset restores 0. Register the suite in `Program.cs`.
- [ ] **Step 2: Run** `dotnet run --project tests/unity-domain`; expect a build failure for the missing field/methods.
- [ ] **Step 3: Add** `public int introductionStage=4;` to `HotelState`; set it to 0 only in `ParityContent.CreateState()`. `StrictSaveJson.Read` accepts the optional integer field; `HotelModel.ValidCore` requires 0…4. Add these model methods using the existing private `Transaction` method:

  ```csharp
  public CommandResult AdvanceIntroduction(int expected) {
      if(expected<0||expected>3||State.introductionStage!=expected)
          return CommandResult.Fail("This discovery is already complete.");
      return Transaction(()=>State.introductionStage=expected+1,"Discovery saved.");
  }
  public CommandResult SkipIntroduction() {
      if(State.introductionStage==4) return CommandResult.Ok("Explore at your own pace.");
      return Transaction(()=>State.introductionStage=4,"Explore at your own pace.");
  }
  ```

- [ ] **Step 4: Run** the domain harness; require its final `PASS` line with the Godot oracle unchanged. Run Unity EditMode tests to catch serialization or fresh-profile integration errors. Commit only this task's files.

### Task 2: Live hotel reveal and view control

**Files:** Create `HotelJourneyUI.cs` and `.meta`; modify `HotelUI.cs`, `HotelParityUI.cs`, `VoxelWorld.cs`; create `Tests/EditMode/IntroductionUITests.cs` and `.meta`.

**Interfaces:** `HotelUI.BeginLiveIntroduction()` enters the live stage-0 reveal after the welcome button. `HotelUI.FinishLiveReveal(bool skip)` stores stage 1 and returns to cutaway. `HotelUI.BuildJourneyCard()` renders exactly one prompt for stages 0…3. `FrameHotelReveal()` comes from world-art Task 4.

- [ ] **Step 1: Write an EditMode UI test** for a fresh model: welcome closes, the live camera is enabled and orthographic, the four-room exterior is visible, and the reveal shows **Look inside** and **Skip**. Simulate Look inside; assert stage 1 and cutaway. Reopen with the same save; assert no reveal. Test an existing save missing `introductionStage` starts in normal Hotel view.
- [ ] **Step 2: Run** `.\tools\unity.ps1 Test`; expect missing `BeginLiveIntroduction`.
- [ ] **Step 3: Change the merged welcome **Open your hotel** callback** (currently `welcome=false;settings=false;Rebuild();app.World.FitHotel();`) to call `BeginLiveIntroduction()`. Inspect the callback after the welcome task lands before changing it. For stage 0 call `app.World.SetCutaway(false)` and `app.World.FrameHotelReveal()`; show one short overlay card, with **Look inside** as primary and **Skip** as secondary. Both call `AdvanceIntroduction(0)`, restore the saved exterior preference after completion, then call `Navigate("Hotel")`. If saving fails, retain the reveal and expose the existing Retry path.
- [ ] **Step 4: Add a small Hotel View control** using `SetCutaway` for later exterior/interior exploration. Keep the current Settings switch synchronized. The reveal's automatic camera animation lasts at most 1.5 seconds and becomes instant when `settings.motion` is false; it never blocks pan/zoom after the action.
- [ ] **Step 5: Verify** a fresh profile, an existing profile, Reset, Back, and Settings from welcome at 360×640 and 390×844. Run EditMode tests and commit.

### Task 3: One-at-a-time discovery cues

**Files:** Modify `HotelJourneyUI.cs`, `HotelUI.cs`, `HotelParityUI.cs`; modify `Tests/EditMode/IntroductionUITests.cs` and `ParityInputAcceptance.cs`.

**Interfaces:** `HotelUI.OnCareSucceeded(CommandResult result)`, `OnBuildSucceeded(string action,CommandResult result)`, and `OnMapClosed()` report successful player activity to the stage machine. None grants game rewards.

- [ ] **Step 1: Add tests** for the complete sequence: stage 1 prompts **Meet a cat** and opens Cats; merely opening Cats does not advance; a successful care result with `progressChanged` advances to 2; stage 2 prompts **Add a detail** and opens Build on an affordable item category; a failed placement does not advance; successful `place_object` advances to 3; Map opens from stage 3 and closing it advances to 4. Skip at any stage hides future prompts, while the tabs keep working.
- [ ] **Step 2: Run** EditMode tests and confirm failure before adding the hooks.
- [ ] **Step 3: Implement the prompt table** in `HotelJourneyUI.cs`, one card at a time:

  ```csharp
  static readonly (string title,string action,string tab)[] Prompts = {
      ("Welcome to Meadow House","Look inside","Hotel"),
      ("Get to know a guest","Meet a cat","Cats"),
      ("Make it yours","Add a detail","Build"),
      ("There is more to discover","See destinations","Map")
  };
  ```

  Hook `HotelParityUI.OnCareAction` after `Model.Care`, both `HotelParityUI.PlaceCommand` and `HotelUI.Place` after successful `place_object` / `Model.PlaceObject`, and Map close in `HotelUI.Back`. Call `AdvanceIntroduction` only when the matching action succeeds. On stage-save failure, retain `pendingIntroductionStage` in `HotelJourneyUI`; after `HotelApp.RetrySave()` succeeds, retry `AdvanceIntroduction(pendingIntroductionStage)` and clear the pending value only on success. The prompt may be dismissed via `SkipIntroduction()`.
- [ ] **Step 4: Add Your journey** as a compact, user-opened list in Life: Cats, Build, hotel life, Main Street, and destinations. Show one recommended next item; the other entries are descriptive links, not locked tabs or invented rewards. At 150% text the list scrolls, while its close action remains visible. Link to Main Street through its merged entry action and to destinations through the existing Map tab.
- [ ] **Step 5: Run** EditMode and pointer acceptance across touch layouts. Check one prompt at a time, no input interception over live cats, and no accidental purchases. Commit.

### Task 4: Map handoff and first-run acceptance

**Files:** Modify `HotelJourneyUI.cs`, `Tests/EditMode/IntroductionUITests.cs`, `ParityInputAcceptance.cs`; add captures under `docs/art/qa-shots/playable-hotel-polish/`. Do not edit `HotelParityUI.ParityMapPanel` in this task.

**Interfaces:** Stage 3's **See destinations** action navigates to the final merged Map; the introduction neither changes `CanTravel` nor grants entitlements.

- [ ] **Step 1: Add UI tests** that stage 3's CTA opens the merged Map, closing Map completes stage 4, and normal Map actions retain their live status: Meadow **Here**, Seaside's level/coin gate, and Forest/Snowcap's honest preview state. At 360×640 and 150% text, Seaside's requirements and action must be reachable. Include a regression that the introduction never calls `Travel` or `GrantEntitlement`.
- [ ] **Step 2: Run** EditMode tests and confirm the stage-3 navigation/completion assertion fails before wiring the handoff.
- [ ] **Step 3: Wire** the stage-3 CTA and `OnMapClosed()` to the final Map's actual navigation/back API. Keep its layout, art, unlock actions, and Main Street entry owned by the other features. If the merged Map fails the live-status test, report the failing case to its owning work rather than replacing the Map in this plan.
- [ ] **Step 4: Run** the domain harness, Unity EditMode tests, Windows build, and pointer acceptance. Capture fresh stage 0–4, returning profile, Map at 100/125/150% text, reduced motion, and save failure/retry. Record the results and remaining physical-device checks beside the captures.
- [ ] **Step 5: Review** whether the first ten minutes reveal at least cats, decorating, hotel activity, and future destinations without more than one instructional card at once. Fix any blocked tap, clipping, or false unlock claim; rerun the affected gate and commit.

## Final gate

Use an isolated fresh profile and a copied established save. The fresh profile should go from welcome art to the *same live hotel*, then let the player explore freely; the established save should open as usual. Capture both. Do not call the first-run pass complete if the playable world looks substantially flatter or colder than the welcome art.
