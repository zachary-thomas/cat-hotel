# Creative social preview — independent code review

Date: 2026-09-15

## Scope and method

Reviewed `creative_app.gd`, `package-creative.ps1`, `creative_pack_smoke.gd`, and `social_simulation.gd` against the approved creative-hotel contract. Read the relevant project/export configuration, model venue definitions, and existing app/social tests to check the boundaries between them. This pass was read-only; the integration owner runs the complete creative suites and packaged smoke tests.

The review concentrated on save failures, isolation from existing saves, test expansion progression, service capacity, and guest reservations. The findings below identify reproducible behavior rather than style preferences.

## Important findings

### P1 — Direct executable launch bypasses the isolated creative launcher

**Location:** `tools/package-creative.ps1`, export and runtime-copy steps; `project.godot`, `run/main_scene`.

The reviewed package exported the existing Windows preset and placed `CreativeHotel.exe` beside a matching `CreativeHotel.pck`. The exported project still named the legacy main scene. The `.cmd` launcher supplies the creative scene and a separate profile, but double-clicking the executable directly supplies neither. Godot can therefore auto-load the adjacent pack, start the legacy game, and use its default `user://hotel-save` in the normal application profile.

**Reproduction:** Build the package, then launch `CreativeHotel.exe` directly, without the `.cmd` file and without a scene argument. Observe the loaded main scene and save prefix in an isolated verification profile containing a sentinel legacy journal.

**Required correction:** Export an independent staged project whose default main scene is the creative scene and whose application identity/profile differs from the legacy game. Verify both direct executable launch and the documented launcher. Do not change the original project's defaults.

**Resolved:** Export now stages an independent project with `creative_hotel.tscn` as its default scene and `Purrington Creative Social Preview` as its application identity. The final rendered package write/reopen smoke and direct-executable test pass; the legacy sentinel hash remains unchanged.

**Later authorized integration:** The user subsequently requested merging all branches into main and making the changes visible in normal Play. The source project's default scene and standard Windows launcher now also select the creative game. Its save prefix remains separate from the original format.

### P2 — Failed autosaves are invisible and failed final saves still close the game

**Location:** `scripts/creative/creative_app.gd`, `_ready()`, `_process()`, and `_notification()`; reviewed lines 26, 113, and 118.

The initial save and timed autosave ignore a `false` result. The window-close branch calls `save()` and then unconditionally quits. Although construction transactions roll back correctly, passive income and completed guest interactions after the last successful journal write can disappear when a write fails and the user closes the window. The reviewed UI did not display `save_error` or the blocked-load state.

**Reproduction:** Substitute a store that returns `false` from `save_model()`, advance the simulation to earn income or friendship, and trigger `NOTIFICATION_WM_CLOSE_REQUEST`. The game exits despite the failed final save. A failed timed save also produces no visible recovery action.

**Required correction:** Surface save failures. Retain the running session when a final save fails and provide a retry or explicit exit choice. Handle an initial-save failure through the same recovery state.

**Resolved:** Persistent UI feedback exposes failed saves and retry. `request_close()` retains the session when the final write fails, with retry, continued play and explicit discard actions. The app test substitutes a rejecting store and verifies recovery; the UI suite verifies error and protected-journal banners.

### P2 — Nearby counters can reserve the same attendant position

**Location:** `scripts/creative/social_simulation.gd`, `_sync_staff()`; reviewed lines 269–271. The model's `venues()` chooses each counter's staff position independently.

Staff synchronization writes `reservations[staff_slot.key]` without checking whether another attendant owns that physical position. Every attendant is then placed at its assigned coordinates. Two valid counters facing away from a shared narrow gap can select the same point; the second assignment replaces the first reservation while both actors remain stacked there. Existing tests covered multiple counters with separated staff positions.

**Reproduction:** In a clear shared room, place one 3 × 1 milkshake counter at `(0, 0)`, rotation 0, and another at `(0, -1.5)`, rotation 2. Their footprints have a 0.5-cell gap, and both rear approaches can resolve to the same point. Advance staff synchronization and compare actor positions and reservation ownership.

**Required correction:** Allocate distinct staff positions across counters, or leave a counter unavailable when no safe staff position exists. Never replace another actor's reservation. Add a fixture with adjacent facing counters, including a subsequent edit while guests are active.

**Resolved:** The model allocates distinct staff positions across venues and excludes them from every guest slot. The simulation also refuses to overwrite an occupied staff reservation. Facing-counter and duplicate-station regressions pass in the services and social suites.

## Boundaries that were checked

- The creative app itself uses a distinct journal prefix and does not invoke legacy save conversion. The package's default entry point was the isolation gap above.
- Test expansions use known product IDs, are clearly presented as preview unlocks, and roll back entitlement/guest changes when saving fails. Seaside's earned-coin and level gate remains in the model.
- Guest activities use model venues and route data. Reservations are released on activity completion and rebuilt after construction changes. Completed visits originate in the simulation, not rendering.
- Milkshake seating stays in its source room, with a distance limit for outdoor counters. The existing social suite covers check-in, order/service/seating, invalidation, guest-slot exclusivity, and automatic attendants on separate counters.

## Verification handoff

All three findings are closed. The complete 11-suite creative run, 55 UI captures and final packaged write/reopen tests pass. Direct executable launch without a scene override also passes. Details and platform limits are recorded in `verification.md`.

The earlier model/save review was handled separately: `test_creative_save_integrity.gd` passed with zero failures after correcting borrowed quote references, globally unique starter inventory IDs, nested save validation, purchase-price caps, safe optional defaults, real Unix timestamps, and the restored ID sequence. No already-passing suites were repeated during this final read-only review.

## God mode follow-up review

A separate read-only review checked the new model, app, Settings UI and God mode regression suite. No important concrete bugs were found. It covered free purchase values and refund protection, permanent unlocks, bond and staff gate bypasses, Undo reset, failed-save rollback and persisted settings. The integration pass completed all 12 current suites, all 33 retained legacy suites, enlarged-text captures and packaged write/reopen checks.
