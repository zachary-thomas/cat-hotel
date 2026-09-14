# Mobile Build mode — implementation and validation

> Updated September 13: the [continuous Build revision](2026-09-13-continuous-build-mode.md) supersedes the single-room Apply/discard flow, draft-only undo, and exclusion of shared spaces and blueprints described below. This document preserves the original design/execution record.


Implemented September 12, 2026, after authorization to proceed with subagents. This report records execution of the [implementation plan](2026-09-12-mobile-build-mode.md) and its [design](../specs/2026-09-12-mobile-build-mode-design.md).

## Delivered experience

Open **Build**, choose a room, and **Browse** furniture or storage. A selected item appears as a ghost; tap the room, rotate, or use the four nudge controls, then **Place** it in the makeover. Moving a selected object also has a visible drag handle. Scrollable details stay separate from fixed Place/Cancel and Apply/Done actions.

The room reports Comfort, Entertainment, Atmosphere, quality income, matching combinations, and its best guest matches. Items have distinct prices, footprints, and stat contributions. Repeating a family has diminishing returns. Eighteen catalogue items and three included room fixtures have geometry and thumbnails, including when fixtures are stored.

Nothing is purchased by browsing or placing a draft object. Paid Apply shows quantities, item totals, remaining coins, storage changes, and room effects. Confirm saves the wallet and furniture together; failure restores both and retains the draft. Free moves, rotations, storage transfers, undo, and redo remain available. Draft history contains furniture state only, so income and repairs keep progressing.

Existing type ownership becomes a free-reuse license. New purchases use per-copy pricing. Starter recipes and the friendship blanket remain reusable. Included fixtures are granted once per room. Save version 3 contains one authoritative inventory, while versions 1 and 2 migrate from their actual saved rooms and licenses. The old three-slot purchase route opens Build instead of purchasing directly.

Cats select a suitable room and route through its doorway to actual furniture approaches and animation anchors. Housekeeping uses a reachable room location. Build keeps the cutaway and camera under player control and hides residents of the edited room. Other rooms continue operating.

Drafts use an independent two-slot checksummed journal, saved after a one-second editing pause and on application suspension. Recovery validates ownership, geometry, history, and object counters. Durable edit receipts prevent an already-applied makeover from charging again after a crash. Ordinary and commerce-preview saves have separate draft paths.

## Execution record

| Plan tasks | Result |
| --- | --- |
| 1: Catalogue and quality | Complete; independent content review approved. |
| 2: Interior layout | Complete; rotation, layer overlap, doorway, reachability, templates, and guarded routes covered. |
| 3: Ownership and migration | Complete; strict legacy validation, canonical IDs, fixture grants, per-copy quoting, and atomic patches independently approved. |
| 4: Draft sessions | Complete; bounded history, combined move/rotation, corrupt recovery, and ownership checks independently approved. |
| 5: Model/Main integration | Complete; version 3 authority, income/fit integration, transaction rollback, and unified decorating entry points. |
| 6: Instance rendering | Complete; shared immutable mesh resources, stable object IDs, per-room revision caching, and isolated ghosts. |
| 7: Input and metrics | Complete; pointer ownership, cancellation, UI boundaries, two-finger gestures, safe-area conversion, and text scaling. |
| 8: Mobile Build screen | Complete; catalogue, storage, stat previews, review, fixed actions, and six-size rendered checks. |
| 9: Cat and housekeeping routes | Complete; canonical doorway bridge, approaches, furniture targets, and structural-route invalidation. |
| 10: Full content | Complete; all catalogue items, included fixtures, thumbnails, suites, and support-height anchors. |
| 11: Recovery and delivery | Locally executable work complete; journals, migrations, regression coverage, documentation, and Windows preview package. Physical release checks below remain open. |

## Verification evidence

- All **22 behavioral suites passed** through `tools/test.ps1`, including all 14 original suites. Output: `tmp/build-mode-full-test.log`.
- Rendered Build and existing building flows passed. The Build flow resized the actual running window to **360×640, 360×800, 390×844, 430×932, 768×1024, and 1280×800**, each at **150% Build text**. Checks cover action bounds, minimum touch size, panel width, and visible world area. Screenshots are in `tmp/build-*-150.png`; the smallest catalogue is `tmp/build-catalogue-360x640-150.png`.
- The rendered screenshots were inspected. Follow-up fixes removed overlapping hotel controls, kept all three room scores visible on the smallest screen, improved category/filter layout, and corrected fractional action-bar sizing.
- Focused regressions cover no-charge previews, paid review, failed-save rollback, replayed Apply, corrupted latest-draft fallback, profile isolation, same-room taps preserving drafts, Android Back preserving unsaved work, cancelled ghost cleanup, Watch mode camera priority, and valid guarded actor transitions.
- Real pre-change version 1 and 2 save fixtures verify wallet/offline-envelope preservation, licenses, actual room contents, unique IDs, and one-time fixture grants.
- Independent reviews approved content, inventory, sessions, input, and final integration after fixes. Review records remain under `.superpowers/sdd/2026-09-12-mobile-build-mode/`.
- Windows packaging succeeded. `builds/windows/Play.cmd`, `PurringtonHotel.pck`, and `builds/PurringtonHotel-WindowsPreview.zip` were refreshed. The packaged PCK passed a headless startup smoke check. Export log: `tmp/build-mode-package.log`.
- Source/test comparison against the pre-change backup passed whitespace checking with Windows line endings recognized.

The Godot runtime reports its existing Windows root-certificate-store warning. A forced five-frame package shutdown can also report two remaining audio playback resources; the normal close path already shuts audio down. Neither produced a script error or a failing behavioral assertion.

## Implementation decisions

- The repository has no initial commit. Work stayed in the existing checkout, with a pre-change source backup in `tmp/build-mode-baseline`, instead of creating a wholesale initial commit or a worktree without a base. No commit was made.
- Life keeps a weak reference to its owning model to preserve existing tag/combo method signatures while reading the authoritative inventory. Serialized and bound live Life data no longer contain the obsolete furniture arrays.
- Existing cat scale and cat-to-cat collision spacing were preserved. Interior movement uses the planned small navigation footprint plus clearance when guarding swept movement against furniture; visible bodies retain their existing stylized proportions. Physical-device and animation review should include apparent body overlap in tight layouts.
- The compact phone summary shows the three numeric scores first, with room quality, combinations, guest fit, and object controls further down the same scroll area. The purchase review provides the fuller stat comparison.
- A saved draft is offered inside Build; startup announces that it is available. Leaving for another menu preserves a dirty draft, and returning from another hotel explicitly offers to resume its original room.

## Remaining mobile release checks

This is a playable implementation with desktop-rendered mobile-layout evidence. It is not yet a measured Android release.

- Run the documented frame-time, memory, input-latency, thermal, pause/resume, interruption, and safe-area checks on the target Android phones. Check sustained dense-room play, rapid gestures, text scaling, and resident animation fit.
- Run the planned five-person usability exercise: find an affordable object, explain the stat change, place it, move it, cancel a purchase, and recover a makeover without coaching.
- Produce and validate the intended signed Android build using the existing mobile release setup. No physical phone measurements, signed Android package, iOS build, or user-study results are claimed here.
