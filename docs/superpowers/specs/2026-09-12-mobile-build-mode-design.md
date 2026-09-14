# Purrington Hotel: mobile Build mode and meaningful furniture

> Updated September 13: the [continuous Build revision](../plans/2026-09-13-continuous-build-mode.md) supersedes the single-room Apply/discard flow, draft-only undo, and exclusion of shared spaces and blueprints described below. This document preserves the original design/execution record.


**Status:** Implemented after user authorization with subagents. See the [implementation and validation report](../plans/2026-09-12-mobile-build-mode-validation.md); physical Android performance and the usability study remain release checks.
**Date:** September 12, 2026.
**User direction:** Make decorating feel like entering The Sims' Build mode, with differently priced objects that improve room satisfaction. Prioritize mobile. Follow-up: **focus on building and decorating first**.
**Implementation plan:** [Mobile Build mode](../plans/2026-09-12-mobile-build-mode.md).

## 1. The experience we want

The player notices that a room could be better, enters Build, tries a more comfortable bed, places a climbing tower, rearranges the room, sees what improved, and returns to watching cats enjoy it. The pleasure comes from both making a space their own and understanding why a furnishing is useful.

Build is a distinct workspace with a focused room, a furniture catalogue, placement controls, an itemized budget, undo/redo, and a clear return to Live. Rooms have **Comfort, Entertainment, and Atmosphere**, each scored from 0 to 100. These are persistent properties of the furnished room, not needs that drain over time. Existing personality tags explain which cats appreciate a room.

The first release does not introduce hunger, bladder, energy decay, new care chores, illness, unhappy-away penalties, or a new autonomous needs simulation. Existing guest visits, preferences, housekeeping, offline earnings, and object-use animations remain the foundation. A later simulation feature can consume the room and object data created here.

**Success moment:** A new player can place a new object and move an existing one on a small phone without learning a hidden gesture, and can explain why the room became better.

## 2. What exists and what must change

Checked against the source and existing portrait screenshot, rather than treating older planning documents as current behavior.

| Current implementation | Consequence for this feature |
| --- | --- |
| `room_layout.gd`: 10 × 12 building grid, 4 × 3 regular rooms, 4 × 5 suites, four entrance rotations, eight rooms maximum | Keep the outer room system. Add a separate grid inside rooms. |
| `game_content.gd`: 15 furniture types, existing prices, preference tags, six two-item combinations | Enrich stable item IDs with stats, footprints, functional families, and use anchors. |
| `hotel_life.gd`: three item IDs per room; bought types reusable in every room | Replace slot-based placement with instances and explicitly migrate ownership. |
| `build_panel.gd`: room builder plus single-object preview; confirmation inside scrolling content | Retain room construction and build a furniture editor with fixed actions outside the catalogue scroll. |
| `hotel_ui.gd::_decorate()`: a second decorator that buys immediately | Route both decorating entry points to the same Build workspace. |
| `room_builder.gd`: preset bed, activity, and decor positions; extra suite props are baked in | Render placed objects independently; stop drawing duplicate preset furniture. |
| `hotel_world.gd`: room visits and cat routines use fixed bed/activity positions | Use real reachable object anchors; extend existing routines without a needs system. |
| `grounds_model.gd`: cleaning targets the room center | Choose a reachable housekeeping anchor after furniture changes. |
| `main.gd`: settle income, prepare, mutate, save, rollback on failure | Commit an entire room makeover through this transaction boundary. |
| `hotel_model.gd`: save version 2, fractional currency, offline earnings; `game_store.gd`: two checksummed save slots | Introduce version 3 without losing wallet, rooms, cats, rewards, or recovery behavior. |
| 450 × 900 design viewport, portrait mobile setting, responsive desktop; 13 behavioral suites | Validate final on-device dimensions and touch gestures, not screenshots alone. |

The checkout currently has no commits and its source files are untracked. Planning adds only the linked specification and plan; a future implementation must avoid accidentally committing the entire checkout.

## 3. Approaches considered

| Approach | Strength | Cost / weakness | Decision |
| --- | --- | --- | --- |
| **Room-local snapping grid with independent objects** | Creative placement, understandable footprints, predictable touch input, testable paths | Requires instances, migration, and real object anchors | **Recommended.** Best fit for this request. |
| Unrestricted placement, wall drawing, resizing, arbitrary angles | Maximum architectural freedom | Precision gestures, wall intersections, navigation, and editing complexity expand the project substantially | A separate future feature. |
| More preset slots with stronger upgrades | Fastest extension of existing code | Still feels like selecting upgrades from a menu; limited room composition | Insufficient as the main direction. |

Keep room shells and their current prices. Within them, the player can arrange furniture freely on a fine grid. Do not add arbitrary room resizing, floors, stairs, plumbing, object stacking, outdoor editing, or new service rooms to this release.

## 4. Live → Build → Live

1. Tap **Build**, **Decorate**, or an existing room's **Edit room** action. Existing room construction remains available under **Rooms**.
2. Select a room. Camera frames it in the area above the furniture sheet, cuts away obstructing walls, and displays its room stats.
3. Browse **Sleep, Play, Decor, Storage**. Item cards show the actual object, price, footprint, strongest stats, and a readable unlock reason when locked. An **Affordable** filter and sorting by price or the selected stat support small budgets.
4. Select an item. Catalogue collapses, a ghost appears at a valid suggested position, and the item details show **raw item stats** separately from **this room's actual change**.
5. Tap a floor cell, rotate, or nudge the ghost. **Add to room** adds it to the makeover draft. **Cancel item** removes only the ghost. Neither action spends coins.
6. Tap a placed object for **Move, Rotate, Store**. Stored items can be reused. Undo/redo traverses the last 20 accepted draft edits, including adding, storing, rotating, and moving; a new edit clears redo.
7. **Apply · 440 coins** opens a compact review showing purchases, free moves, before/after stats, and final wallet. **Confirm · 440 coins** saves and charges exactly once. A zero-cost makeover uses **Apply changes · Free** with no second review step.
8. Return to Live. The edited room reveals the committed arrangement, cats choose updated use points, and a short factual message explains the improvement. A room with a new reachable play object can visibly use it in the next routine cycle.

One room makeover is drafted at a time. Room selection, room construction/moving, hotel travel, and leaving Build resolve a dirty draft with **Apply / Keep editing / Discard changes**. Settings may open over Build and return to the draft. Android Back / Escape cancels the active ghost first, then closes details, then resolves the draft, then exits Build. No paid action is attached to Back, closing a sheet, releasing a drag, or tapping the room.

Existing hotel income, repairs, events, and housekeeping continue against committed data. Draft objects do not produce income, discoveries, happiness, or cat interactions. The edited room's actors are temporarily hidden while its draft is displayed; other rooms stay lively. They resume with updated routes after Apply, or their original room after Discard. Build never sets the entire SceneTree or economy to paused.

## 5. Furniture prices and ownership

**Proposed default, awaiting the optional pricing preference:** Buy individual copies with earned Cat Coins. Move, rotate, and store an owned copy for free. The user has confirmed building-first scope but has not yet selected a pricing model at the time this draft was written.

Existing costs and level gates remain unchanged. New premium items provide stronger effects in their specialty, with larger footprints or higher prices. A premium bed does not replace the need for play objects. No real-money furniture currency, timer, durability, paid placement, or randomized stat rolls.

Account-wide storage keeps every owned instance at exactly one location: one room in one owned hotel, or storage. Moving from another hotel's room requires storing it there first. No item can contribute to two rooms simultaneously. There is no sell/delete action in the first release; this keeps purchases recoverable and eliminates resale exploits. Canceling an uncommitted purchase simply removes its cost from the draft.

**Honor old purchases:** Every type in a version-2 save's `life.furniture` becomes a permanent legacy reuse license. Each old placed furnishing becomes an instance. Licensed types can still create free copies after migration, with clear **Previously owned · Free reuse** copy. Types bought after the update cost per copy. Starter `mat`, `box`, and `plant` remain free for all players; the friendship blanket remains freely reusable after its existing bond unlock. Free copies obey the same placement and stat rules.

The alternative is to retain buy-once reuse for everyone: keep the same placed-instance/grid/editor design, but let the first purchase add a permanent type license. Only the price calculation and catalogue copy change; the user-facing ownership policy must be resolved consistently before implementation.

### Initial furniture balance proposal

Values below are proposed tuning, not measured balance. `C/E/A` means Comfort / Entertainment / Atmosphere. Dimensions are interior cells, each 0.55 world units. Preserve recognizable silhouettes; resize existing meshes deliberately to their declared footprints rather than letting visuals overhang into neighbors.

| ID / object | Coins | Level | C / E / A | Footprint | Family / layer | Existing preference tags |
| --- | ---: | ---: | --- | --- | --- | --- |
| `mat` / Linen mat | 0 | 1 | 12 / 0 / 0 | 3 × 4 | sleep / floor | none |
| `sun_cushion` / Sunshine cushion | 120 | 1 | 28 / 0 / 8 | 3 × 4 | sleep / floor | sunny |
| `cave` / Sheltered cat bed | 180 | 1 | 38 / 0 / 4 | 3 × 4 | sleep / floor | quiet |
| `heated` / Heated cloud bed | 320 | 2 | 52 / 0 / 10 | 3 × 4 | sleep / floor | warm |
| `blanket` / Friendship blanket | Gift | 1 + existing bond gate | 38 / 0 / 10 | 3 × 4 | sleep / floor | quiet, warm |
| `box` / Delivery box | 0 | 1 | 0 / 10 / 0 | 2 × 2 | hide_play / floor | explore |
| `perch` / Window perch | 150 | 1 | 8 / 20 / 8 | 2 × 2 | climb / floor | sunny |
| `tunnel` / Play tunnel | 190 | 1 | 0 / 32 / 0 | 3 × 2 | hide_play / floor | play |
| `tower` / Climbing tower | 260 | 2 | 6 / 42 / 6 | 2 × 2 | climb / floor | explore, play |
| `table` / Picnic table | 250 | 2 | 8 / 18 / 10 | 2 × 3 | social / floor | food, social |
| `plant` / Leafy planter | 0 | 1 | 0 / 0 / 8 | 1 × 1 | greenery / floor | none |
| `rug` / Whisper-soft rug | 110 | 1 | 10 / 0 / 18 | 4 × 2 | textile / rug | quiet |
| `scratch` / Rope scratcher | 140 | 1 | 0 / 24 / 0 | 1 × 2 | scratch / floor | play |
| `lamp` / Amber lantern | 230 | 2 | 4 / 0 / 30 | 1 × 1 | lighting / floor | warm |
| `flowers` / Welcome flowers | 160 | 1 | 0 / 0 / 24 | 1 × 1 | greenery / floor | social |
| `cloud_sofa` / Cloud sofa, new | 420 | 3 | 32 / 8 / 14 | 3 × 2 | seating / floor | social, warm |
| `adventure_tree` / Adventure tree, new | 650 | 4 | 10 / 62 / 14 | 3 × 3 | climb / floor | explore, play |
| `canopy_bed` / Canopy bed, new | 900 | 5 | 72 / 0 / 24 | 4 × 4 | sleep / floor | quiet |

Limit the initial catalogue to these 18 player-purchasable/unlockable types. Regular-room nightstands and suite seating/table that were baked into older rooms become separate included fixture instances during migration and new-room creation: `room_nightstand` (1 × 1, 0/0/0, fixture), `suite_sofa` (3 × 2, 18/4/6, seating, social), and `suite_table` (2 × 2, 0/0/4, fixture). These three included fixture types may be stored and reused but cannot be purchased or minted freely. They bring the total definition count to 21. Remove surplus baked-in plants/books/side tables as visual assembly details of the associated object; do not leave invisible obstacles or hidden stat bonuses.

## 6. Room stats that reward useful variety

The same pure calculation powers preview, room details, guest fit, and committed income. Do not save a second authoritative copy of derived scores.

For each stat, group usable placed items by functional family. Sort the contributions within each family descending, then apply weights **1.0, 0.5, 0.25, 0, ...**. Add contributions across families and clamp to 100. Round once, at the end, to the nearest integer using `floor(value + 0.5)`. Rugs can add stats while under furniture; rug-on-rug overlap is invalid.

```
stat = clamp(round(sum over families(v1 + 0.5*v2 + 0.25*v3)), 0, 100)
room_quality = round(0.40*Comfort + 0.35*Entertainment + 0.25*Atmosphere)
quality_income = floor(max(0, room_quality - 25) / 15)  # 0..5 coins/min
```

No base points from empty floor area; suites benefit from more usable space and their included seating. Three starter plants give Atmosphere 14; a fourth gives zero, so filling a room with free plants cannot max the score. A stronger item in the same family can still replace the leading contribution. The preview explains this: **“Atmosphere +0: more plants won't improve this room.”** A rug contributes Comfort and Atmosphere, but does not provide a sleep action or count as a bed.

**Worked example:** `mat + box + plant` gives C12 / E10 / A8 and quality 10. Replacing the mat with `heated` and adding `scratch` gives C52 / E34 / A18 and quality 37. The exact incremental cost is 460 coins in a new save, quality increases by 27, and the quality income is still 0 until quality 40. The UI must show the actual threshold, not promise income for every purchase. The old replacement mat goes to storage. Adding `rug` gives C62 / E34 / A36, quality 46, and +1 coin/min from quality.

Keep the six existing combination IDs, discovery memories, +8/min effects, specialty bonuses, staff bonuses, and destination bonuses. Each combination applies once per room even if its component items repeat. All applicable combinations can coexist now that slots are gone; test this expanded economy explicitly. Stored and draft objects contribute nothing. Legacy tags and combinations use the committed instance list, so migration preserves them.

Room labels: **Simple** 0–24, **Inviting** 25–49, **Lovely** 50–74, **Exceptional** 75–100. Display the three stat bars before the overall quality; one aggregate number should not hide what a room lacks. A room is allowed to specialize. Maximum scores in every category are not required for ordinary guest rewards or hotel progression.

**Cat fit, without a needs rewrite:** Use fixed C/E/A percentage weights by existing preference: sunny 45/15/40, explore 20/60/20, play 15/70/15, quiet 65/10/25, food 30/30/40, social 25/45/30, warm 60/10/30. Fit is the weighted score plus 10 if the room has the cat's existing preference tag, capped at 100. Select the highest-fit room, with lower room index as deterministic tie-breaker. Add at most 10 points (`floor(best_fit/10)`) to the current hotel-level `preference_score`, then cap at 100; preserve its other components and the existing happy-visit threshold of 65. This creates an additive improvement without making existing guests harder to please. Preview may show a known cat's fit; undiscovered preferences remain hidden.

Cleanliness stays a separate housekeeping state and does not reduce these persistent furnishing stats. Food and social contact remain supported by existing services and tags. More live needs can be designed later.

## 7. Placement, access, and spatial rules

- The building grid stays 1.1 units per tile. Interior coordinates use 0.55-unit cells: **8 × 6 regular**, **8 × 10 suite** in canonical, unrotated room-local space.
- Room-local +x points east, +y points south. At rotation 0 the entrance is on the east wall. Reserve a 2 × 2 inside door apron: x=6..7, y=2..3 for regular rooms and y=4..5 for suites. The entire room transform rotates that apron with the shell.
- Instance placement stores integer `x`, `y`, and `rotation` 0..3 relative to the canonical interior. Rotate the footprint before collision checks. Rotate render geometry and use anchors through exactly the same transform.
- Floor objects cannot overlap floor objects. Rugs are nonblocking and may lie beneath floor objects; rugs cannot overlap other rugs. No wall attachments or surface stacking in this release.
- Keep visible geometry within the declared footprint with a small edge inset. Definitions include interaction approach cells and separate animation targets, so a cat approaches a bed from a free tile before settling onto it.
- Use four-neighbor flood fill from the door apron over walkable interior cells. A proposed placement cannot block the apron or make any existing interactive object's approach cells unreachable. Navigation accounts for a cat body radius of 0.18 world units and clearance of 0.04; a single 0.55-unit cell is the minimum aisle.
- Applying a makeover requires at least one reachable sleep object and one reachable housekeeping point. A temporary draft may have no bed while replacing it; Apply stays disabled with **“Add a bed cats can reach.”** The catalogue always offers the free starter bed.
- Blocking decor may be valid even though it has no interaction. Passive stat contributors need valid placement but do not need their own approach point.
- Placement rejection shows one actionable primary reason plus a marked cell/route: **Outside this room**, **Another object is here**, **Keep the doorway clear**, **Cats can't reach the bed**, or **Room is full**. Use text/icon and patterned footprint, not color alone.
- Room move/rotation keeps local furnishings, room indices, ownership, and stats intact. Reconnect the inside apron to the existing outer lobby route. Never use a straight-line shortcut through furniture.
- Initial caps: **16 instances per regular room, 24 per suite**, including rugs and fixtures. Account storage cap: **256 instances**, with a visible full-storage message; reject any transaction that exceeds it. A new purchased instance staged then removed simply vanishes from the draft and cannot fill storage for free. Live room changes do not destroy objects.

Template generation is deterministic and validated with these same rules. Place the 3 × 4 starter bed at (0,0), box at (4,0), plant at (7,0), and nightstand at (3,0); use the bed's east-side approach at (3,2). Suites additionally place sofa at (0,7), table at (4,7), with the sofa approached from (1,6). Reserve the connecting walk cells. For migrated, larger activity footprints, fit all legacy items by deterministic first-fit search (y, then x, then rotation), backtracking over the small set rather than greedily losing an item. All 3-slot combinations and room rotations must have a valid template or the geometry/content must be adjusted before release. Migration must not silently put a previously equipped item into storage and change its tags/combos.

## 8. Mobile interaction contract

### Portrait composition

The following is a layout wireframe, not rendered proof. Heights are design targets for a 360 × 800 logical-phone test after safe-area conversion.

```text
┌──────────────────────────────────┐
│ Build · Room 02       1,000 coins │  48 high, within safe area
│ Comfort 52  Play 34  Atmosphere18 │  compact, tap for full labels
│                                  │
│       FOCUSED ROOM + GHOST        │  usable floor stays visible
│       grid + clear entrance      │
│                                  │
├──────────────────────────────────┤
│ Sleep  Play  Decor  Storage       │  scrollable category row
│ Item / price / footprint         │  catalogue OR selected details
│ Comfort 12 → 52   Play 10 → 34    │
│ Rotate    Nudge     Cancel item  │  selection controls
│       Add to room                │  during active ghost
├──────────────────────────────────┤
│ Undo   Redo       Apply · 460     │  fixed action bar
└──────────────────────────────────┘
              bottom safe area
```

Catalogue sheet has collapsed and browsing states, with explicit **Browse / Back to room** controls; dragging its handle is optional. Browsing uses at most 45% of safe height. Selecting an object collapses it to at most 30%; keep at least 50% of safe height available for world interaction. At larger text sizes use one-column rows and scroll item detail, never the primary action bar. Do not shrink type to fit. Camera fits the selected room into the actual unobscured rectangle and respects manual pan/zoom until explicit **Fit room**; do not refocus after every stat refresh.

On sufficiently wide windows, use a 320–360 logical-unit right panel only if at least 480 logical units remain for the world. Landscape and tablets rearrange panels; they do not merely shrink portrait controls. Mobile portrait remains the default supported orientation; landscape validation covers desktop/tablets and future rotation support, without promising an iOS export.

### Gestures

| Input | Result |
| --- | --- |
| Tap catalogue card | Select and preview; never purchase |
| Tap free floor while ghost active | Position ghost at the nearest valid-or-invalid snapped cell and explain validity |
| Tap object without ghost | Select object; overlapping rug/furniture offers a small chooser or select it through room contents |
| One-finger drag starting on empty world | Pan camera |
| One-finger drag starting on selected object's move handle | Move ghost; lift does not apply or buy |
| Two fingers anywhere in world | Pinch zoom and centroid pan; freeze object placement for the entire gesture |
| Finger begins on catalogue/panel | That UI owns it until release, even if it crosses into world |
| Finger moves from world onto UI | End world gesture without activating the underlying UI button |
| Rotate button / desktop R | Rotate 90 degrees with validation; no precision rotation gesture |
| Nudge control | Four labeled directional buttons move one cell; desktop arrow equivalents |
| Canceled touch, focus loss, OS interruption | Release every pointer capture; keep draft; no tap, move confirmation, or purchase |

Use an 8-logical-unit movement threshold for tap versus drag. Once a second finger joins, neither release can become a tap until all fingers lift. Ignore emulated mouse input on mobile in Build just as normal play does. Reuse one gesture owner; do not leave both `main.gd` and `hotel_world.gd` independently selecting objects from the same event. Touch cleanup must run even when UI consumes a release. Offset the optional move handle/ghost indicator above the finger and keep tap-to-place plus nudge as fully capable alternatives.

### Size, accessibility, and interruption

- Controls must measure at least 48 × 48 Android dp equivalent after scaling; use 56-high primary buttons and 8-unit spacing as initial targets. Android's official recommendation is a minimum 48dp touch target. [Android accessibility guidance](https://developer.android.com/guide/topics/ui/accessibility/views/apps-views).
- Godot viewport units are not automatically physical pixels or Android dp. Compute one UI coordinate conversion, then verify the final size on a device. Keep the existing stretch setup until testing shows a necessary change; do not globally change it just to fix Build. [Godot multiple-resolution documentation](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html).
- Recompute all four safe-area insets on viewport/window changes. Apply them to the Build panel, fixed actions, and camera's available rectangle, rather than relying on `mobile_ui.gd`'s initial top/bottom adjustment. [Godot DisplayServer](https://docs.godotengine.org/en/stable/classes/class_displayserver.html#class-displayserver-method-get-display-safe-area).
- Handle the touch event's `canceled` property and pointer index explicitly. [Godot screen-touch events](https://docs.godotengine.org/en/stable/classes/class_inputeventscreentouch.html).
- Essential labels target 16 logical units, supplemental text 14, normal text contrast 4.5:1 as a project acceptance target. Test a 150% in-game text setting for this workspace; no information may rely on hover or a long press.
- Add a Build text-size setting with 100%, 125%, and 150% choices. Persist `settings.build_text_scale` as exactly 1.0, 1.25, or 1.5; legacy saves default to 1.0. Validate this numeric setting separately from the existing boolean settings path. It adjusts text and panel layout in Build, without shrinking the world or unrelated HUD controls.
- Include readable labels on icon controls, visible focus, non-color validation cues, reduced-motion transitions, and optional haptics. Screen-reader support must be physically tested before claiming it; labeled custom Godot controls alone are not evidence.
- Persist a recoverable draft after a one-second edit debounce and on app pause. Saving a draft spends nothing. Reopening offers **Resume makeover** or **Discard draft**. Confirmed purchases survive process death even if clearing the draft file did not finish.

## 9. State and transaction architecture

Keep new logic in focused modules. The existing outer `RoomLayout` remains authoritative for hotel footprints. `FurnitureLayout` validates interiors; `RoomQuality` calculates derived stats; `FurnitureInventory` owns instances and prices; `BuildSession` stages one room's changes; `BuildInput` owns gestures; `FurnitureRenderer` renders definitions and selection; `BuildPanel` presents state. `Main` remains the only save/transaction orchestrator.

### Version-3 data shape

```json
{
  "furniture": {
    "version": 1,
    "next_instance": 9,
    "revision": 0,
    "legacy_reuse": ["mat", "box", "plant"],
    "instances": [
      {"uid":"f1","item":"mat","hotel":0,"room":0,"x":0,"y":0,"rotation":0},
      {"uid":"f8","item":"scratch","hotel":-1,"room":-1,"x":0,"y":0,"rotation":0}
    ],
    "rooms": [
      {"hotel":0,"room":0,"revision":0,"last_edit_id":""}
    ]
  }
}
```

This is a partial example of the new top-level `furniture` field inside `HotelModel.serialize()` version 3. Existing `life`, `grounds`, wallet, hotel layout, settings, and progress remain alongside it. Include a room revision record for every open room in every owned hotel. UIDs are stable, account-unique monotonic strings; allocate purchased UIDs only during successful transaction preparation and roll back their allocator on failed commit. Draft-only objects use `draft:<edit-id>:<counter>` IDs. Storage always uses hotel=-1 and room=-1; mixed sentinels are invalid.

Version 3 stops writing `life.hotels[*].rooms` and stops using `life.furniture` as purchase authority. Preserve their version-2 parsing only for migration. For existing life consumers, change `room_tags` and `room_combos` to take `model` and read the authoritative inventory. Update all call sites in the same task. Friendship rewards update the new license data through the model; no parallel ownership array may drift from inventory. New game, room purchase, earned hotel unlock, and expansion-hotel entitlement each initialize missing starter room inventories exactly once inside their existing transaction. Moving a room preserves its kind and instances, increments its revision, and never grants starter furnishings again.

Restore must validate a complete candidate model before replacing any live field, including invalid furniture checks. Validate finite whole numbers, IDs, references, owned hotel, open room, footprint, anchors, duplicate UIDs, revision/allocator bounds, storage capacity, room capacity, and required beds. Unknown/corrupt version-3 content rejects the candidate so `GameStore` can try its other slot. Unsupported future versions are preserved and not rewritten as an older format.

### Applying a draft

`BuildSession` holds original room revision, account inventory revision, edit ID, draft instances, source storage UIDs, pending new objects, undo history, and preview report. It does **not** hold an authoritative wallet or whole-model snapshot.

1. Settle current income and run existing `_prepare_transaction()`.
2. If this edit ID matches the room's saved `last_edit_id`, return its committed result without reapplying or charging.
3. Reject stale room/inventory revisions, unowned storage UIDs, or changed room shape; offer **Reload room** while keeping an inspectable draft. Ordinary income, events, friendship, or finished wing repair do not invalidate a draft unless relevant ownership/room geometry changed.
4. Rebuild a furniture-only candidate from current committed state plus the draft patch. Revalidate layout, unlocks, license rules, caps, and the current wallet. Recompute price from definitions; do not trust a UI-supplied cost or stats.
5. Capture `before = model.serialize()` after settling; debit integer currency units, update inventory/revisions and receipt, recalculate affected discovery effects, and save once.
6. On write failure, existing `_commit(before)` restores wallet, inventory, UIDs, revisions, and discoveries. Keep the editable draft and persistent inline error. Retry does not duplicate items or charges.
7. On success, clear recovery draft, rebuild only the changed room and routes, and update UI from the committed model.

Whole-model serialization remains appropriate for the short transaction rollback. Undo/redo and discarded makeovers must never restore a whole-model snapshot: doing that would rewind income, visits, repairs, or purchases that occurred while editing.

Recoverable drafts use a separate checksummed two-slot journal tied to the save-path profile. It stores draft state and base revisions, not charged transactions. Reuse/refactor the envelope algorithm from `GameStore`, not its model restoration API. On resume, suppress an already committed edit ID; reject a stale/corrupt draft without blocking the real save. Persist history up to 20 edits and enough pending-item metadata to reprice from definitions. Revision conflict is intentionally conservative for changes to shared inventory.

## 10. Rollout and validation

**Vertical slice first:** One regular room, existing mat/box/plant plus purchasable scratcher, portrait tap placement, room-quality preview, Apply, rollback, and save/reload. This proves the high-risk transaction/input/geometry combination before filling out the catalogue.

**Complete release:** All 18 catalogue types and three fixtures, suites, all rotations, storage, undo/redo, migration, old combinations, reachable cat and staff routines, accessible controls, recoverable drafts, and phone validation. Build and Decorate must converge on this one editor before the feature ships.

**Future work:** Freeform walls, additional floors, wall/surface attachments, whole-room blueprints, finish/paint tools, outdoor decorating, household schedules, and live cat needs each require separate designs. No empty tabs or locked promises for these in this release.

| Release gate | Required evidence |
| --- | --- |
| First-use usability | Five new testers: at least four place, rotate, move, undo, and apply a room improvement without help in three minutes; all five identify the price before confirmation. Record observations, not just completion. |
| Meaningful stats | At least four testers can explain one stat change and why a fourth plant adds no improvement after reading the preview. Compare a budget quiet room and budget play room. |
| Touch correctness | Automated real InputEvent sequences plus physical phone checks for tap, drag, pinch, UI crossing, canceled touch, Back, rapid confirmation, and resume; zero accidental purchases. |
| Layout | 360×640, 360×800, 390×844, 430×932, 768×1024, and 1280×800; safe-area presets and 150% text. Inspect actual screenshots and verify focused object/action-bar hit rectangles. |
| Persistence | v1/v2 migration, all rotations, old equipped combos, reusable licenses, version-3 round trip, corrupt-newest fallback, interrupted Apply, failed write, stale draft, and process-death recovery. |
| Economy | Exact preview/commit price and stat equality; free moves/storage; no rewards from drafts; duplicate Apply costs once; old earnings components preserved; no duplicate combo stacking. |
| Navigation | Cats and housekeeping can reach all required anchors in every starter/migration template; blocked replacements rejected; rotated room preserves local positions. |
| Performance | On a recorded midrange Android device, eight rooms at legal furniture caps, 12 visible cats, 30-second warm-up then ten minutes: p95 frame time ≤33.3ms; preview feedback ≤100ms p95; no repeatable growth >10MB after 50 open/edit/cancel cycles and settled cleanup. Record device, OS, build, and profiler evidence. 60fps is a stretch target, not a measured claim. |
| Regression | Existing 13 behavioral suites plus the new suites; obsolete slot assertions replaced with behavior checks, never simply deleted. Rebuild Windows preview only during implementation release validation. |

The five-person usability exercise and physical-device measurements are release checks to perform later, not claims of validation in this planning task. If 360×640 placement does not fit, simplify the active item panel before reducing touch targets or text. If geometry is too heavy, reduce procedural detail and update only changed objects/rooms before lowering visual legibility.
