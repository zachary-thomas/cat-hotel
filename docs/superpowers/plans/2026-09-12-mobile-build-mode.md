# Mobile Build Mode Implementation Plan

> Updated September 13: the [continuous Build revision](2026-09-13-continuous-build-mode.md) supersedes the single-room Apply/discard flow, draft-only undo, and exclusion of shared spaces and blueprints described below. This document preserves the original design/execution record.


> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Use superpowers:subagent-driven-development only if delegation is authorized for that execution. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Purrington Hotel a mobile-first furniture Build mode with movable objects, meaningful prices and room stats, reversible makeovers, and reliable saved ownership.

**Architecture:** Keep the outer room layout and existing hotel simulation. Introduce pure furniture content, interior layout, inventory, room-quality, and draft-session modules; integrate them through Main's existing save transaction boundary. Render and route to actual object instances, and route all decorating entry points into one touch workspace.

**Tech Stack:** Existing Godot 4.7.2 project, GDScript, GL Compatibility renderer, procedural voxel geometry, SceneTree behavioral tests, PowerShell tooling. No new engine/plugin dependency is required.

**Spec:** [Mobile Build mode and meaningful furniture](../specs/2026-09-12-mobile-build-mode-design.md). Read it before execution; tables and numeric rules there are part of this plan.

**Status:** Implemented after user authorization to proceed with subagents. Per-copy pricing with grandfathered reuse is active. See [implementation and validation](2026-09-12-mobile-build-mode-validation.md) for delivered behavior, verification, and remaining physical-device release checks. The original step lists below remain the design-time recipe; the validation report records execution.

## Global Constraints

- Preserve saved cats, furniture, coins, room indices, achievements, and entitlement data.
- Use earned Cat Coins only; previews, moving, rotating, and storing owned objects are free.
- Focus on building and decorating first; do not introduce a draining cat-needs simulation.
- All outer room entrances remain connected to the lobby, and every committed bedroom has a reachable bed and housekeeping point.
- Preview, undo, and discard cannot mutate committed inventory, wallet, income, visits, discoveries, or repairs.
- Apply settles live income, validates against current state, charges once, saves once, and rolls back on failed save.
- Preserve the current 450 × 900 design viewport and portrait mobile orientation unless measured layout validation establishes a necessary change.
- Controls must measure at least 48 × 48 Android dp equivalent after scaling; use 56-high primary buttons and 8-unit spacing as initial targets.
- Interior cells are 0.55 world units; regular rooms are 8 × 6 cells and suites are 8 × 10 cells before room rotation.
- Initial caps are 16 instances per regular room, 24 per suite, 256 stored instances, and 20 draft undo steps.
- Keep reduced motion, optional haptics, safe areas, and usable 150% text in Build.
- No sale/delete, arbitrary walls, room resizing, floors, stacking, outdoor editing, paint tools, blueprints, or mobile billing changes in this release.

## Delivery sequence

1. **Foundation:** Tasks 1–4 establish testable content, geometry, inventory/migration, and draft rules.
2. **Playable vertical slice:** Tasks 5–8 integrate a regular room with starter items and a scratcher through actual touch input, Apply, and save/reload. Validate on a phone before broadening content.
3. **Complete feature:** Tasks 9–11 finish real object use, all content/suites, recovery, migration cutover, and mobile quality gates.

Tasks are reviewable code units; the feature ships only after the integrated checks pass. Do not ship a partially migrated save format or a UI that still routes around the new transaction authority. There is no elapsed-time estimate: migration fixtures, device access, and geometry profiling determine the schedule.

## File map and responsibilities

| File | Change / responsibility |
| --- | --- |
| `scripts/core/furniture_catalog.gd` | New stable stat/footprint/anchor definitions, merged with existing names/prices/tags |
| `scripts/core/furniture_layout.gd` | New room-local transforms, collision, approach paths, deterministic templates |
| `scripts/core/room_quality.gd` | New pure stat report, quality income, cat fit |
| `scripts/core/furniture_inventory.gd` | New instance ownership, licenses, allocation, migration, validated patches |
| `scripts/core/build_session.gd` | New single-room draft, quote, undo/redo, conflict detection |
| `scripts/core/build_draft_store.gd` | New recovery journal for drafts, separate from committed saves |
| `scripts/core/save_journal.gd` | Extract envelope I/O only when adding draft recovery; preserve GameStore API |
| `scripts/core/hotel_model.gd` | Inventory ownership, version-3 serialize/restore, quality-income integration |
| `scripts/core/room_layout.gd` | Room creation/move inventory hooks and route ending at the outer door |
| `scripts/core/hotel_life.gd` | Instance-based tags/combos/fit, friendship licenses; no duplicate authority |
| `scripts/core/grounds_model.gd` | Reachable room housekeeping anchor and interior route bridge |
| `scripts/core/game_content.gd` | Keep existing stable IDs/prices/tags; add three new catalogue item entries |
| `scripts/core/game_store.gd` | Keep two-slot model fallback; delegate envelope I/O in recovery task |
| `scripts/world/furniture_renderer.gd` | New placed/ghost meshes, UID hit proxies, use/animation anchors |
| `scripts/world/room_builder.gd` | Shell geometry, room overlays, instance renderer, remove preset duplicates |
| `scripts/world/hotel_world.gd` | One Build input path, edited-room visibility, changed-room updates and routines |
| `scripts/ui/build_input.gd` | New pointer state machine independent of UI rendering |
| `scripts/ui/build_metrics.gd` | New safe area, UI-unit conversion, layout measurements and breakpoints |
| `scripts/ui/build_catalogue.gd` | New bounded furniture list/filter/sort/ownership presentation |
| `scripts/ui/build_room_stats.gd` | New stat bars, actual deltas, explanatory item contributions |
| `scripts/ui/build_panel.gd` | Workspace coordinator, sheet states, fixed actions and dirty-draft exits |
| `scripts/ui/hotel_ui.gd` | Decorate routes to Build; remove old three-slot purchasing sheet |
| `scripts/ui/mobile_ui.gd` | Reusable labels/settings integration only; avoid unrelated HUD refactoring |
| `scripts/ui/furniture_thumbnail.gd` | New item thumbnails and silhouette consistency |
| `scripts/main.gd` | Atomic Apply, draft lifecycle, UI routes, input cleanup, save/recovery orchestration |
| `tests/fixtures/build_mode_fixtures.gd` | Deterministic models, placements, migration inputs, pointer-event helpers |
| `tests/test_furniture_content.gd` | Catalogue/quality behavior |
| `tests/test_furniture_layout.gd` | Transform, collision, reachability and template behavior |
| `tests/test_furniture_inventory.gd` | Migration, ownership, restore and instance behavior |
| `tests/test_build_session.gd` | Draft history, quote, price and conflict behavior |
| `tests/test_build_transactions.gd` | Application Apply, failures and duplicate submissions |
| `tests/test_build_input.gd` | Touch ownership and cancellation |
| `tests/test_build_mode.gd` | Integrated rendered/editor behavior and actual InputEvent sequences |
| `tests/test_build_recovery.gd` | Process interruption and draft journal behavior |
| `tools/test.ps1` | Register new suites and optional focused `-Suites` selection |
| `README.md` | Document final player flow and ownership policy |
| `docs/build-mode-validation.md` | Execution evidence, screenshots, device and usability results |

## Shared interfaces

All modules extend `RefCounted` unless they render controls/nodes. Dictionary records below must have documented required keys; reject invalid records at boundaries. Use arrays of integer coordinates in saves, not Vector2i serialization. `model` remains dynamically typed to match existing code and avoid preload cycles.

```gdscript
# furniture_catalog.gd -- static methods
static func item(id: String) -> Dictionary
# {id, name, cost, level, tags:Array, family, stats:{comfort,entertainment,atmosphere},
#  footprint:Vector2i, layer:"floor"|"rug", interactive:bool,
#  approaches:Array[Vector2i], pose:String, animation_target:Vector3,
#  provides_sleep:bool, included_only:bool, bond:int}
static func all_items(include_fixtures: bool = false) -> Array

# furniture_layout.gd -- static methods; room has kind/x/y/rotation from RoomLayout
static func dimensions(kind: String) -> Vector2i
static func footprint(instance: Dictionary) -> Array[Vector2i]
static func local_to_world(room: Dictionary, cell: Vector2) -> Vector3
static func world_to_local(room: Dictionary, point: Vector3) -> Vector2
static func validate(room: Dictionary, instances: Array, require_bed: bool = true) -> Dictionary
# {ok:bool, code:String, message:String, blocked:Array, paths:Dictionary,
#  housekeeping:Vector2i}; paths maps interactive UID -> Array[Vector2i]
static func template(kind: String, legacy_items: Array = []) -> Array
# Array of item/x/y/rotation records, no allocated UIDs or owner fields

# room_quality.gd -- no ownership, rendering, clock, or save effects
static func summarize(instances: Array) -> Dictionary
# {comfort:int, entertainment:int, atmosphere:int, quality:int,
#  income:int, contributions:Dictionary}; only validated committed/draft arrays
static func guest_fit(report: Dictionary, tags: Array, preference: String) -> int

# furniture_inventory.gd -- stateful; model owns one instance
var state: Dictionary  # spec's version-1 furniture record, inside model save v3
func room_items(hotel: int, room: int) -> Array
func stored_items() -> Array
func migrate(legacy_model: Dictionary) -> Dictionary
# {ok:bool, state:Dictionary, message:String}; validates legacy before creating v3
func restore(raw: Variant, hotels: Array) -> bool
func serialize() -> Dictionary
func quote(model, hotel: int, room: int, draft: Array) -> Dictionary
# {ok:bool, message:String, cost_coins:int, purchases:Array,
#  stored_uids:Array, moved_uids:Array, report:Dictionary}
func apply(model, edit: Dictionary) -> Dictionary
# edit={hotel,room,edit_id,base_room_revision,base_inventory_revision,instances}
# {ok:bool, code:String, message:String, room:int, already_applied:bool}

# build_session.gd -- stateful and detached from authoritative model state
func begin(model, hotel: int, room: int, edit_id: String) -> void
func edit(command: String, payload: Dictionary) -> Dictionary
# commands: add(item,x,y,rotation), move(uid,x,y), rotate(uid,rotation),
# store(uid), place_stored(uid,x,y,rotation); validates against draft
func undo() -> bool
func redo() -> bool
func quote(model) -> Dictionary
func patch() -> Dictionary # the edit record consumed by inventory.apply
func serialize() -> Dictionary
func restore(raw: Variant, model) -> Dictionary
func dirty() -> bool

# main.gd -- the sole durable Apply path
func apply_build_session(session) -> Dictionary

# build_draft_store.gd -- separate save-path-derived two-slot journal
func save_draft(session) -> bool
func load_draft(model) -> Dictionary # {ok, status:"resume"|"applied"|"stale"|"none", data}
func clear_draft() -> bool
```

Inventory quotes use the draft's explicit hotel and room. They must not silently switch to `model.current_hotel` after a menu or travel change.

## Test and execution conventions

Use the existing `extends SceneTree`, deferred `run()`, `check(...)`, nonzero-exit pattern from `tests/test_layout.gd` and `tests/test_building.gd`. Each test body shown below is added to its named suite and called from `run()`. Reuse this harness, not a new testing dependency:

```gdscript
extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
    if not value:
        failures += 1
        push_error(message)
func run() -> void:
    test_behavior()
    quit(1 if failures else 0)
```

Every task follows: add its behavioral checks, run the focused suite and confirm the intended missing behavior fails, implement, rerun affected suites, inspect the diff, then commit only that task's reviewed paths if working in a normal initialized checkout. Never change global Git configuration, stage everything, or create an initial source commit as a side effect of this plan. Determine checkout status at execution time. Rendered runs are needed only for new visual/input concerns; no need to run every resolution after every pure-model change.

Add `-Suites` as a string-array parameter to `tools/test.ps1`, defaulting to the complete registered suite list. Validate each requested suite against the explicit allowlist and extend the rendered suite list with `test_build_mode`. Focused commands below assume this parameter has been added in Task 1. They are future implementation checks; none were run for this planning-only change.

## Task 1: Furniture definitions and room-quality calculation

**Files:** Create `scripts/core/furniture_catalog.gd`, `scripts/core/room_quality.gd`, `tests/test_furniture_content.gd`; modify `tools/test.ps1` and `scripts/core/game_content.gd`. Existing `game_content.gd` remains the source for names/prices/tags; add the three new player-facing item records here so catalogue merging has complete inputs. Included fixture definitions live in FurnitureCatalog.

**Consumes:** The spec's complete 21-definition table and stat formula.
**Produces:** `Catalog.item/all_items`, `Quality.summarize/guest_fit`, focused-suite runner.

- [ ] Add quality tests for the starter room, the worked makeover, replacement deltas, family diminishing returns, and caps. Use item-only records here; geometry and ownership are separate boundaries.

```gdscript
func test_quality() -> void:
    var starter = [{"item":"mat"},{"item":"box"},{"item":"plant"}]
    var q = Quality.summarize(starter)
    check([q.comfort,q.entertainment,q.atmosphere,q.quality] == [12,10,8,10], "Starter scores")
    var upgraded = [{"item":"heated"},{"item":"box"},{"item":"plant"},{"item":"scratch"},{"item":"rug"}]
    q = Quality.summarize(upgraded)
    check([q.comfort,q.entertainment,q.atmosphere,q.quality,q.income] == [62,34,36,46,1], "Actual makeover value")
    var plants = [{"item":"plant"},{"item":"plant"},{"item":"plant"}]
    var before = Quality.summarize(plants)
    plants.append({"item":"plant"})
    check(before.atmosphere == 14 and Quality.summarize(plants).atmosphere == 14, "Fourth plant adds zero")
```

- [ ] Run `./tools/test.ps1 -Suites test_furniture_content` and confirm failure is due to missing definitions/quality behavior.
- [ ] Implement definitions and pure summaries. Sort contributions per stat within each family, apply `[1.0,0.5,0.25]`, clamp, and round once. Contribution reports map each UID to effective values where UIDs exist; item-only test records may use a stable array-index key. Calculate hypothetical replacement by summarizing the entire replacement draft, never adding a raw item stat to the old total.

```gdscript
static func summarize_axis(instances: Array, axis: String) -> int:
    var families: Dictionary = {}
    for instance in instances:
        var definition = Catalog.item(str(instance.item))
        var family: String = definition.family
        if not families.has(family): families[family] = []
        families[family].append(float(definition.stats[axis]))
    var total := 0.0
    var weights := [1.0,0.5,0.25]
    for values in families.values():
        values.sort()
        values.reverse()
        for i in range(mini(3, values.size())):
            total += float(values[i]) * weights[i]
    return int(floor(clampf(total,0.0,100.0) + 0.5))
```

- [ ] Validate unique IDs, preserved costs and tags, positive integral footprints, supported layers, nonnegative bounded stats, defined family, nonempty approaches for interactive objects, and sleep capability. Included-only items do not appear in the shop.
- [ ] Run the focused suite; review/commit the definition and quality unit. Ensure the implementation's final rounding matches the worked example exactly.

## Task 2: Interior placement, transforms, and accessibility of objects

**Files:** Create `scripts/core/furniture_layout.gd`, `tests/test_furniture_layout.gd`, `tests/fixtures/build_mode_fixtures.gd`; read `scripts/core/room_layout.gd`.

**Consumes:** Catalogue footprints and approaches; existing shell dictionaries.
**Produces:** `FurnitureLayout` shared interfaces and fixtures `regular()`, `suite()`, `placed(item,uid,x,y,rotation=0)` returning full records with hotel=0/room=0.

- [ ] Add behavioral tests for overlap, bounds, rotated non-square footprints, rug layering, blocked apron, unreachable existing bed, missing bed at Apply, required housekeeping point, and all room rotations.

```gdscript
func test_access() -> void:
    var items = [F.placed("mat","f1",0,0), F.placed("box","f2",4,0)]
    check(Layout.validate(F.regular(),items).ok, "Reachable bedroom")
    items.append(F.placed("tower","f3",6,2))
    check(Layout.validate(F.regular(),items).code == "door_blocked", "Door apron remains clear")
    items.pop_back()
    items.append(F.placed("rug","f4",0,0))
    check(Layout.validate(F.regular(),items).ok, "Rug can lie beneath bed")
    items.append(F.placed("rug","f5",0,0))
    check(not Layout.validate(F.regular(),items).ok, "Two rugs cannot overlap")
    for rotation in range(4):
        var room = F.regular()
        room.rotation = rotation
        var local = Vector2(3.5,2.5)
        check(Layout.world_to_local(room,Layout.local_to_world(room,local)).is_equal_approx(local), "Inverse room transform")
```

- [ ] Run `./tools/test.ps1 -Suites test_furniture_layout`; verify expected failures.
- [ ] Implement footprint rotation with integer quarter-turn transforms, then BFS from apron cells over floor occupancy. Interactive approach targets and housekeeping must be reachable; validate the resulting complete draft, not just the new object.

```gdscript
# Rotating a cell within an unrotated footprint w*h, clockwise:
static func rotate_cell(cell: Vector2i, size: Vector2i, turns: int) -> Vector2i:
    match posmod(turns,4):
        0: return cell
        1: return Vector2i(size.y-1-cell.y,cell.x)
        2: return Vector2i(size.x-1-cell.x,size.y-1-cell.y)
        _: return Vector2i(cell.y,size.x-1-cell.x)
```

- [ ] Define explicit approaches: sleep objects allow a free adjacent side approach, box/perch/tower/scratcher allow perimeter approaches, tunnel uses either end, seating/table uses its front edge. Noninteractive plants/flowers/lamps/rugs/fixtures have no required path. Animation targets may lie inside the object only after approach; paths may not use occupied cells.
- [ ] Build deterministic starter and legacy templates. Test the Cartesian product of existing valid slot choices in both room types and all shell rotations. Test room caps and body clearance. Do not accept templates that hide an equipped legacy object in storage.
- [ ] Run `./tools/test.ps1 -Suites test_furniture_content,test_furniture_layout,test_layout`; review/commit the pure geometry unit.

## Task 3: Inventory, legacy conversion, and candidate validation

**Files:** Create `scripts/core/furniture_inventory.gd`, `tests/test_furniture_inventory.gd`; extend fixtures. Prepare integration seams in `hotel_model.gd` and `hotel_life.gd` without shipping the save cutover separately from Task 5.

**Consumes:** Catalogue, validated layout templates, existing version-1/2 save shapes.
**Produces:** Inventory API, migration/restore candidate records, stable UIDs, explicit pricing policy. Add fixture `legacy_v2()` that preserves real current serialized v2 fields and `model_with_inventory()` for pure draft tests.

- [ ] Save deterministic version-1 and version-2 fixtures before changing runtime serialization. Include equipped combinations, gifted blanket, suites, multiple hotels, moved rooms, pending earnings, and unused purchased type licenses.
- [ ] Test migration and rejection without mutating the input or existing inventory.

```gdscript
func test_migration() -> void:
    var old = F.legacy_v2()
    var original = old.duplicate(true)
    var result = Inventory.new().migrate(old)
    check(result.ok and old == original, "Migration builds a candidate")
    check(result.state.legacy_reuse.has("heated"), "Old ownership remains reusable")
    var restored = Inventory.new()
    check(restored.restore(result.state,old.hotels), "Migrated inventory validates")
    var before = restored.serialize()
    var bad = before.duplicate(true)
    bad.instances.append(bad.instances[0].duplicate(true))
    check(not restored.restore(bad,old.hotels) and restored.serialize() == before, "Duplicate UID rejects without mutation")
```

- [ ] Run `./tools/test.ps1 -Suites test_furniture_inventory`; implement missing behavior. Migrate equipped items only for open rooms in owned hotels; the unused default slot arrays for closed rooms are not extra purchases. Preserve all owned type licenses, including types not equipped anywhere. Add included fixtures exactly once.
- [ ] Implement finite/integer bounds, unique UIDs, allocator monotonicity, valid owner/room, paired storage sentinels, caps, bed/access validation, and room revision records. Validate all candidate submodules before swapping live fields. Normalize JSON whole-number floats only after validation.
- [ ] Price from authoritative catalogue/license state. For per-copy mode, charge each new nonlicensed copy; stored UID moves cost zero; free license creation costs zero. Reject fabricated UIDs, locked types, and attempts to borrow a placed object from another room. Budget cannot go negative.
- [ ] Verify per-copy and legacy-license cases, storage full, exact capacity, reload idempotency, corrupt IDs, fractional coordinates, unknown versions, and huge/negative numbers. Run focused inventory/layout suites; review/commit this pure state unit.

## Task 4: Room makeover drafts, pricing, and undo/redo

**Files:** Create `scripts/core/build_session.gd`, `tests/test_build_session.gd`; extend fixtures with `ready_model()` (new inventory, sufficient coins, regular room, deterministic IDs).

**Consumes:** Inventory read/quote API, layout validation with `require_bed=false` during draft edits, room quality.
**Produces:** BuildSession API; stable draft IDs and room/inventory revision-based patch.

- [ ] Add a behavior test showing purchase staging, unrelated income, undo/redo, and no committed changes.

```gdscript
func test_draft_isolation() -> void:
    var m = F.ready_model()
    var session = Session.new()
    session.begin(m,0,0,"edit-test-1")
    var inventory_before = m.furniture.serialize()
    var coins_before = m.coins_units
    check(session.edit("add",{"item":"scratch","x":4,"y":3,"rotation":0}).ok, "Stage scratcher")
    check(session.quote(m).cost_coins == 140, "Quote comes from item price")
    m.advance(5.0)
    var earned = m.coins_units
    check(earned > coins_before, "Economy continues during editing")
    check(session.undo() and session.quote(m).cost_coins == 0, "Undo pending purchase")
    check(session.redo() and session.quote(m).cost_coins == 140, "Redo pending purchase")
    check(m.furniture.serialize() == inventory_before and m.coins_units == earned, "History cannot rewind model")
```

- [ ] Run `./tools/test.ps1 -Suites test_build_session`; implement independent deep-copy draft state. A removed new draft object disappears rather than entering inventory. A stored existing object remains owned. Moving out of storage reserves its UID within the draft only.
- [ ] Accept only structurally valid edit payloads; bad ghost placement returns a reason without adding an undo entry. Allow temporarily missing a bed, but `quote.ok` for Apply requires complete-room validation. Apply blocks while a ghost has not been added or canceled.
- [ ] Use before/after furniture draft records for the bounded 20-step history. Keep original inventory/room revisions; income and `life.state.revision` do not participate in conflict detection. Never retain model.serialize() snapshots for undo.
- [ ] Test two purchases cost 280, license reuse costs 0, add/remove returns cost 0, stored item contributes no stats, 21 edits retain only 20 undo steps, new edits clear redo, and stale source storage UID is rejected on current-state quote.
- [ ] Run inventory/session/content suites; review/commit the draft unit.

## Task 5: Atomic Apply and version-3 model integration

**Files:** Modify `scripts/main.gd`, `scripts/core/hotel_model.gd`, `scripts/core/hotel_life.gd`, `scripts/core/room_layout.gd`, `scripts/core/grounds_model.gd`, `scripts/core/game_store.gd`; create `tests/test_build_transactions.gd`; extend `tests/test_store.gd`, `tests/test_life.gd`, and fixtures. Update life read call sites in `scripts/ui/hotel_ui.gd`, `scripts/ui/build_panel.gd`, `scripts/world/room_builder.gd`, and `scripts/world/hotel_world.gd` together.

**Consumes:** Session.patch(), validated Inventory.apply(), current Main prepare/commit/settle flow.
**Produces:** `Main.apply_build_session(session)`, validated save v3, `life.room_tags(model,hotel,room)` and `life.room_combos(model,hotel,room)`. Change `life.bond(index,amount,hotel)` to `life.bond(model,index,amount,hotel)` and update every call so friendship licenses reach authoritative inventory.

- [ ] Add Apply tests using the existing `FailingStore` convention and an actual app instance with isolated save path.

```gdscript
func test_apply_once() -> void:
    var session = Session.new()
    session.begin(app.model,0,0,"apply-once")
    session.edit("add",{"item":"scratch","x":4,"y":3,"rotation":0})
    app.active = false # isolate currency in this test only
    var coins = app.model.coins_units
    check(app.apply_build_session(session).ok, "Apply succeeds")
    check(app.model.coins_units == coins - 140 * app.model.UNIT, "Debited once")
    check(app.apply_build_session(session).already_applied, "Repeated edit recognized")
    check(app.model.coins_units == coins - 140 * app.model.UNIT, "No second debit")
```

- [ ] Run focused transaction tests; implement the orchestration in this order:

```gdscript
func apply_build_session(session) -> Dictionary:
    _settle()
    if not _prepare_transaction():
        return {"ok":false,"code":"save_error","message":save_error}
    var before: Dictionary = model.serialize()
    var result: Dictionary = model.furniture.apply(model,session.patch())
    if not result.ok or result.already_applied:
        return result
    if not _commit(before):
        return {"ok":false,"code":"save_error","message":save_error}
    _update_ui()
    return result
# Renderer/routes/draft cleanup subscribe after success in their integration tasks.
```

- [ ] Implement save-v3 serialize/restore as an all-candidate validation flow. Parse legacy `life` with its original strict checks before conversion. For v3, life validation no longer requires obsolete slot arrays or ownership arrays. Remove writes to them. Preserve existing `GameStore.load_model` candidate fallback and reject unsupported versions without overwriting files.
- [ ] Replace every direct life.rooms/furniture read or write with inventory access. Transitional callers may display a list of instances, but no read projection becomes a save authority. The old `furnish` command returns an **Open Build to decorate** result until the entry point is removed in Task 8; it must not remain an alternate purchasing route.
- [ ] Add `Inventory.ensure_rooms(model,hotel)->bool`: initialize starter items/revision records only for newly open rooms in an owned hotel. Invoke it from new_game, place_room, unlock_hotel, and expansion-hotel grant within the surrounding atomic transaction. Do not call it to silently repair invalid v3 saves. On move_room, reject a changed room kind, preserve all instance IDs/local coordinates, and bump the affected room/inventory revisions. Verify repeated entitlement fulfillment never duplicates fixtures.
- [ ] Keep tags/combinations computed from committed room items and use stable combo IDs once per room. On successful Apply discover only newly formed combinations; rollback must include their memories and notifications. Inventory revisions change only on committed ownership/layout edits, not on ordinary `life.touch()`.
- [ ] Test failed save restores allocator/revisions/coins/items/rewards; UI draft remains; unaffordable current balance; stale room/inventory; duplicate success after reload; corrupt newest v3 fallback; failed restore leaves every prior model field unchanged. Add quality income to `hotel_rate` once and check old income components separately.
- [ ] Run `./tools/test.ps1 -Suites test_build_transactions,test_furniture_inventory,test_build_session,test_store,test_life,test_model,test_commerce`. Update intentionally obsolete slot assertions to ownership and placed-instance behavior; preserve all unrelated assertions. Review the coordinated integration change before moving on.

## Task 6: Real object geometry, ghost preview, and picking

**Files:** Create `scripts/world/furniture_renderer.gd`; modify `scripts/world/room_builder.gd`, `scripts/world/hotel_world.gd`; begin `tests/test_build_mode.gd`.

**Consumes:** Validated instance lists and shared room-local transforms.
**Produces:** `FurnitureRenderer.sync(room,instances)`, `show_ghost(room,instance,validation)`, `clear_ghost()`, `pick(camera,screen)->Array[String]`, `use_anchor(room,instance)->Vector3`; `RoomBuilder.show_draft(room_index,instances)` and `clear_draft()`.

- [ ] Test rendered room object count/UID mapping and transformed bounds. One placed item must create one object root; rebuilding a preview must not duplicate the committed object.

```gdscript
func test_renderer_identity() -> void:
    var before = app.model.serialize()
    var session = Session.new()
    session.begin(app.model,0,0,"render-only")
    session.edit("add",{"item":"scratch","x":4,"y":3,"rotation":0})
    app.world.room_builder.show_draft(0,session.patch().instances)
    await process_frame
    check(app.model.serialize() == before, "Rendering cannot purchase")
    app.world.room_builder.clear_draft()
    check(app.model.serialize() == before, "Cancel restores committed presentation")
```

- [ ] Port mat/box/plant/scratcher first. Separate shell/walls from furniture; replace preset bed/activity/decor branches with per-instance assembly. Remove baked nightstand/sofa/table duplicates and render included fixtures from inventory.
- [ ] Add per-instance hit proxies associated with UID, floor/rug chooser results, footprint overlay, door apron marker, and clear validation cues. Visible mesh bounds stay inside the rotated footprint; animation targets may extend vertically.
- [ ] Cache immutable geometry/materials by item definition. Update ghost transform/validity in place while moving; regenerate occupancy/report only on cell/rotation/edit changes. Update only the edited room on commit. Never stringify the full model each frame to find changes.
- [ ] Hide only the edited room's actors while showing draft geometry; clear on Cancel/Apply. Keep other rooms, HUD currency, and repairs alive. Maintain unobstructed room walls/camera behavior.
- [ ] Run layout/transaction/rendered tests and inspect regular-room preview screenshots at 360×800 and 1280×800. Review/commit the renderer unit before adding all premium art.

## Task 7: Mobile gesture ownership and layout measurements

**Files:** Create `scripts/ui/build_input.gd`, `scripts/ui/build_metrics.gd`, `tests/test_build_input.gd`; modify `scripts/main.gd`, `scripts/world/hotel_world.gd`; add event helpers to fixtures.

**Consumes:** UI/world/selected-handle rectangles, viewport safe-area transform, shared world/local transform.
**Produces:** `BuildInput.feed(event,context)->Array[Dictionary]`, `reset()`, command records (`tap_world`, `pan`, `zoom`, `move_ghost`); `BuildMetrics.measure(viewport:Vector2,safe:Rect2,ui_scale:float,text_scale:float)->Dictionary` with `world_rect`, `panel_rect`, `actions_rect`, `min_target`.

- [ ] Test gestures through actual `InputEventScreenTouch`/`InputEventScreenDrag` sequences. Fixture `touch(index,position,pressed,canceled=false)` and `drag(index,position,relative)` create events; context identifies the owner on initial press.

```gdscript
func test_pinch_never_taps() -> void:
    var input = BuildInput.new()
    var commands: Array = []
    commands.append_array(input.feed(F.touch(0,Vector2(100,200),true),context))
    commands.append_array(input.feed(F.touch(1,Vector2(200,200),true),context))
    commands.append_array(input.feed(F.drag(1,Vector2(230,200),Vector2(30,0)),context))
    commands.append_array(input.feed(F.touch(1,Vector2(230,200),false),context))
    commands.append_array(input.feed(F.touch(0,Vector2(100,200),false),context))
    check(commands.any(func(c): return c.kind == "zoom"), "Two fingers zoom")
    check(not commands.any(func(c): return c.kind in ["tap_world","move_ghost"]), "Pinch releases never place")
```

- [ ] Run `./tools/test.ps1 -Suites test_build_input`; implement explicit owner and gesture states: idle, UI-owned, tap-candidate, camera-pan, object-move, multi-touch. Threshold is measured in UI logical units; capture survives crossing UI/world boundaries. Cancel/reset clears touches without synthesizing taps.
- [ ] Route Build input once. Preserve `_input` cleanup of consumed releases, ignore emulated mouse events on mobile, and suppress world tap interpretation after any multi-touch gesture until all touches release. Use command signals for camera/ghost movement, never for purchases.
- [ ] Convert screen safe area into canvas coordinates, accounting for origin and x/y scale. Recalculate all insets on resize. Measure the fixed action bar separately from scrolling content; enforce portrait world area and wide-window breakpoint from the spec.
- [ ] Add table-driven tests for UI drag entering world, object drag ending on Apply, release outside window, canceled touch, resize midgesture, three-finger input, mouse parity, 150% text, nonzero four-side safe areas, and two rapid taps. Three or more fingers freeze placement until all release.
- [ ] Run input and existing building/app suites. Verify physical target size at vertical-slice device check; unit tests cannot establish actual Android dp mapping. Review/commit.

## Task 8: Unified Build workspace and playable mobile slice

**Files:** Create `scripts/ui/build_catalogue.gd`, `scripts/ui/build_room_stats.gd`; modify `scripts/ui/build_panel.gd`, `scripts/ui/hotel_ui.gd`, `scripts/ui/mobile_ui.gd`, `scripts/main.gd`, `scripts/core/hotel_model.gd`; extend `tests/test_build_mode.gd` and `tests/test_building.gd`.

**Consumes:** Session, quote/report, renderer, input commands, BuildMetrics, Main Apply.
**Produces:** `BuildPanel.open(room=-1)`, `begin_makeover(room)`, `add_selected_to_draft()`, `request_apply()`, `confirm_apply()`, `discard_makeover()`. Existing room-shell `begin_place/rotate/confirm` remain separate operations with explicit draft resolution.

- [ ] Test that Build, Decorate, and room editing enter the same workspace and no legacy purchasing command fires. Keep current room construction/moving tests through their existing flows.

```gdscript
func test_makeover_ui() -> void:
    app.build_panel.open(0)
    app.build_panel.begin_makeover(0)
    var before = app.model.serialize()
    app.build_panel.session.edit("add",{"item":"scratch","x":4,"y":3,"rotation":0})
    app.build_panel.request_apply()
    check(app.model.serialize() == before, "Paid review has not charged")
    check(app.build_panel.review_cost == 140, "Review displays exact pending price")
    app.build_panel.confirm_apply()
    check(app.model.furniture.room_items(0,0).any(func(i): return i.item == "scratch"), "Confirmed object placed")
```

- [ ] Add test-visible `review_cost:int` read state and stable node names for catalogue cards, AddToRoom, CancelItem, Undo, Redo, ApplyMakeover, ConfirmMakeover, FitRoom, and error text. Names are automation hooks, not product copy.
- [ ] Build collapsed/browse/detail/review states. Fixed actions never live inside ScrollContainer. Show wallet and pending cost separately, before→after room stats, family saturation explanation, unlock reason, stored count, and missing coins. Preserve selected category/scroll position after edits.
- [ ] Default to tap-place; provide optional move handle, rotate, four nudge buttons, and object chooser for rug overlap. Avoid hover-dependent controls. Add Fit room and preserve manual camera position during ordinary refresh.
- [ ] Add 100%/125%/150% Build text choices. Persist `settings.build_text_scale` with a default of 1.0 and exact allowed values [1.0,1.25,1.5]. Implement `Main.change_build_text_scale(value:float)->bool` using the existing save/rollback path; keep boolean `change_setting` validation intact. Reflow BuildMetrics and text without rebuilding the draft or losing its selection/history.
- [ ] Route dirty-draft exits through Apply/Keep editing/Discard; preserve draft when Settings opens. Map Android Back and Escape in the defined order. Paid review disables Confirm while submitting; a failed save remains inline and allows retry.
- [ ] Replace `_decorate()` with Build navigation and update discoveries/room links. Remove the obsolete three-slot furnishing buttons and “buy once” copy except where legacy licensing applies. Preserve the user's chosen pricing policy in every card/review.
- [ ] Run all registered behavioral suites, then `./tools/test.ps1 -Rendered -Resolution 360x800 -Suites test_build_mode,test_building`. Use root.push_input sequences to complete a real tap/rotate/move/apply flow; direct method calls alone are insufficient.
- [ ] Inspect and try the vertical slice on a physical Android phone: visible preview above controls, measured targets, no release-triggered purchase, five-minute interaction session. Record obstacles and fix them before Task 9. Physical access can be recorded as outstanding if unavailable; it is still required for release.

## Task 9: Cat and housekeeping routes to placed objects

**Files:** Modify `scripts/world/hotel_world.gd`, `scripts/world/room_builder.gd`, `scripts/core/room_layout.gd`, `scripts/core/grounds_model.gd`, `scripts/core/hotel_life.gd`; extend `tests/test_layout_grounds.gd`, `tests/test_life.gd`, `tests/test_build_mode.gd`.

**Consumes:** Layout.paths/housekeeping, Renderer.use_anchor, inventory room records, Quality.guest_fit.
**Produces:** `FurnitureLayout.route_to(room,instances,uid)->Array[Vector3]` and `housekeeping_world(room,instances)->Vector3`; `RoomLayout.route_to_door(model,hotel,room)->Array[Vector2]`; `life.best_room(model,hotel,cat)->int`. Add these static layout helpers in this task and use the canonical shared transform.

- [ ] Test moving a bed changes its approach/animation target, a stored activity leaves no routine target, and rotated rooms keep routes connected.

```gdscript
func test_moved_bed_route() -> void:
    var room = F.regular()
    var first = [F.placed("mat","f1",0,0)]
    var moved = [F.placed("mat","f1",0,2)]
    check(Layout.validate(room,first).ok and Layout.validate(room,moved).ok, "Both layouts usable")
    var a = Layout.route_to(room,first,"f1")
    var b = Layout.route_to(room,moved,"f1")
    check(not a.is_empty() and not b.is_empty() and a[-1] != b[-1], "Approach tracks instance position")
```

- [ ] Replace fixed `bed_position/activity_position` assumptions with UID-based anchors and routes. Enter through outer lobby route, bridge to the inner apron, follow BFS to the approach point, then perform the use animation. Reverse valid walking segments for exit.
- [ ] Existing `RoomLayout.route()` appends the room center after the outer door. Implement `route_to_door()` from its existing corridor path with that final center segment omitted; furniture and housekeeping routes must use this door-ending helper. Otherwise the legacy final segment can walk straight through a newly placed object before the interior path starts.
- [ ] Use existing sleep/stretch/sniff/play poses; prioritize a newly added reachable activity once in the next routine cycle after returning to Live. If no play object exists, use existing rest/groom behavior. No need decay or new scheduling model.
- [ ] Reassign edited-room actors safely at a valid entry/approach point after commit; never spawn them inside a moved object's footprint. On discard restore original room routing. Release any temporary actor visibility state on menu change and app resume.
- [ ] Route manager/maid to a reachable housekeeping point rather than room center. Replan active jobs after a committed furniture or room move while preserving work/reward progress; reuse the existing layout_changed job-preservation pattern.
- [ ] Add deterministic best-fit selection and the additive ≤10 guest-score bonus. Preserve all current services, staff, preferences, happy threshold, memories, and offline visit caps. Test quiet/play cats choose different deliberately furnished rooms and tie-break by room index.
- [ ] Run life/grounds/layout/build suites. Visually inspect movement in a rotated suite with a narrow legal aisle; review/commit.

## Task 10: Complete catalogue, suite parity, and economy validation

**Files:** Modify `scripts/core/game_content.gd`, `scripts/core/furniture_catalog.gd`, `scripts/world/furniture_renderer.gd`, `scripts/ui/furniture_thumbnail.gd`; extend content/layout/inventory/build/life tests.

**Consumes:** The spec's 18 catalogue types plus three included fixtures, quality and pricing rules.
**Produces:** Complete furniture art/anchors/thumbnails with matched silhouettes; finished legacy and new-room templates.

- [ ] Add content completeness and geometry tests before each missing item renderer. Existing prices/tags stay unchanged; `cloud_sofa`, `adventure_tree`, and `canopy_bed` use the proposed values unless the user has revised them.

```gdscript
func test_content_scope() -> void:
    check(Catalog.all_items().size() == 18, "Complete catalogue including unlocked gift")
    check(Catalog.all_items(true).size() == 21, "Three included fixtures")
    check(Catalog.item("heated").cost == 320, "Legacy price preserved")
    check(Catalog.item("adventure_tree").stats.entertainment > Catalog.item("tower").stats.entertainment, "Premium climb improvement")
    check(Catalog.item("canopy_bed").stats.entertainment == 0, "Premium bed does not replace play")
```

- [ ] Build unmistakable silhouettes for all items and respect their footprints; inspect at actual phone camera scale. Keep paid upgrades visually distinct without relying on color alone. Included suite furniture is movable inventory, not shell decoration.
- [ ] Test all furniture under all four item rotations and all four room rotations; compare mesh bounds, pick targets, approach paths, and preview-vs-commit stats. Keep big canopy/tree items valid in a suite and explain nonfitting regular-room positions normally.
- [ ] Add economy fixtures: one-vs-two identical items, mixed functional families, 16/24-instance limits, all six combos once each, existing specialty/destination effects, additive quality income, free license saturation, and per-copy cost. Compare ten minutes of earnings before/after to expose accidental whole-hotel multipliers.
- [ ] Create two affordable regular-room layouts with different strengths (quiet vs play) and one premium suite; record costs, footprints, scores, tag fit, and earnings in the validation report. These are balance experiments, not fixed marketing claims.
- [ ] Rerun migration template permutations and all existing life/event/star assertions. Confirm new-game rooms and migrated rooms share the same included fixture rules and satisfy required bed/housekeeping constraints.
- [ ] Review/commit catalogue completeness. Tune only with documented before/after examples; if changing proposed numbers, update spec, tests, and catalogue together.

## Task 11: Draft recovery, mobile release checks, and documentation

**Files:** Create `scripts/core/build_draft_store.gd`, `scripts/core/save_journal.gd`, `tests/test_build_recovery.gd`, `docs/build-mode-validation.md`; modify `scripts/core/game_store.gd`, `scripts/main.gd`, `scripts/ui/build_panel.gd`, `tools/test.ps1`, `README.md`; extend `tests/test_store.gd`, `tests/test_app.gd`, `tests/test_startup_offline.gd`, `tests/test_build_mode.gd`.

**Consumes:** Serialized bounded draft, model's saved receipt/revisions, existing two-slot checksummed envelope and save profiles.
**Produces:** Recoverable uncharged makeovers; completed validation report with honest pass/fail/outstanding status.

- [ ] Add crash-window tests: staged draft reload; Confirm saved but draft not cleared; corrupted newest draft slot; stale inventory; both draft slots invalid; save-profile isolation. A bad draft cannot block or roll back the hotel save.

```gdscript
func test_applied_draft_is_not_replayed() -> void:
    var session = Session.new()
    session.begin(app.model,0,0,"crash-window")
    session.edit("add",{"item":"scratch","x":4,"y":3,"rotation":0})
    check(drafts.save_draft(session), "Uncharged draft journaled")
    check(app.apply_build_session(session).ok, "Hotel commit durable")
    var coins = app.model.coins_units
    var recovery = drafts.load_draft(app.model)
    check(recovery.status == "applied", "Receipt suppresses stale draft replay")
    check(app.model.coins_units == coins, "Recovery cannot spend again")
```

- [ ] Extract checksum/envelope reading and atomic slot writing behind `SaveJournal.new(path)`, `write(payload:Dictionary)->bool`, `candidates()->Array`, and `clear()->bool`; candidates return `{sequence,state}` sorted newest first. Keep schema validation and model reconciliation in GameStore, draft validation in BuildDraftStore. Preserve all existing save tests before wiring recovery.
- [ ] Journal edits after one-second debounce and on pause. On startup/resume offer Resume/Discard only for a valid unapplied draft, and suppress an already applied receipt. Cancel pointer captures before opening any recovery/offline sheet. Do not erase a good committed save when clearing drafts.
- [ ] Finish version-3 cutover audit: search all code for direct `life.state.furniture`, `.hotels[...].rooms`, obsolete `item.slot` placement, fixed bed/activity positions, and direct `furnish` purchases. Legacy-only parser references may remain with explicit comments; no live authority or UI may depend on them.
- [ ] Run `./tools/test.ps1` once after final integration. Fix genuine regressions; rerun affected suites after fixes. Repeat full suite only when changes justify it.
- [ ] Run the following rendered matrix with `test_build_mode,test_building,test_startup_offline`; record screenshots and input assertions for each:

```powershell
./tools/test.ps1 -Rendered -Resolution 360x640 -Suites test_build_mode,test_building,test_startup_offline
./tools/test.ps1 -Rendered -Resolution 360x800 -Suites test_build_mode,test_building,test_startup_offline
./tools/test.ps1 -Rendered -Resolution 390x844 -Suites test_build_mode,test_building,test_startup_offline
./tools/test.ps1 -Rendered -Resolution 430x932 -Suites test_build_mode,test_building,test_startup_offline
./tools/test.ps1 -Rendered -Resolution 768x1024 -Suites test_build_mode,test_building,test_startup_offline
./tools/test.ps1 -Rendered -Resolution 1280x800 -Suites test_build_mode,test_building,test_startup_offline
```

- [ ] Inject safe-area presets and 150% text for automated layout checks. Inspect overlap, ghost visibility, action reach, errors, locked item text, storage full, negative stat deltas, and review totals. Real touch event tests must accompany screenshots.
- [ ] Record physical Android device/OS/build and measure: eight rooms at caps, 12 visible cats, ten-minute session after warm-up, p95 frame time ≤33.3ms, preview p95 ≤100ms, and repeat-open memory growth within the spec's budget. Verify OS Back, app-switch interruption, process death, pointer cancellation, touch-target size, and reduced motion on the device. Do not claim iOS readiness from Windows or Android evidence.
- [ ] Conduct the five-player exercise in the spec and record observed issues. If unavailable, leave those release gates explicitly outstanding. Revise gesture/layout behavior before adding optional features when testers struggle.
- [ ] Update README with Build, item stats, pricing/legacy reuse, storage, makeover review, draft recovery, and desktop shortcuts. Add screenshots and measured evidence to the validation report. Rebuild Windows preview using `./tools/package.ps1` and perform the updated pack smoke only after required code checks pass.
- [ ] Review the final source/doc diff and report implemented behavior, tested evidence, and any remaining device/usability blockers. Do not label release complete with physical-device or migration gates unmet.

## Coverage check for this plan

| Spec requirement | Tasks |
| --- | --- |
| Differently priced useful items; preserved legacy prices | 1, 3, 4, 10 |
| Comfort / Entertainment / Atmosphere and honest preview | 1, 4, 8, 10 |
| Real room-local placement and object access | 2, 6, 7, 9 |
| Storage and old ownership protection | 3, 4, 5, 8 |
| Atomic Apply, rollback, duplicate protection | 4, 5, 11 |
| Undo/redo and no model rewind | 4, 8 |
| One Build entry path, existing room-shell construction retained | 5, 8 |
| Touch ownership, safe areas, large targets, readable small-phone layout | 7, 8, 11 |
| Suites, moved rooms, included fixtures | 2, 3, 6, 10 |
| Existing preferences, combos, cats, staff, income | 5, 9, 10 |
| Save migration and recoverable drafts | 3, 5, 11 |
| Mobile performance and usability evidence | 8, 11 |

## Planning self-review

- Scope follows the user's building-first answer; live needs and architectural wall editing remain separate future designs.
- Proposed pricing is labeled as an assumption rather than an approved user decision.
- The implementation extends the actual Godot codebase and existing transaction/test patterns.
- Arithmetic checked: starter quality 10, upgraded quality 37, upgraded-plus-rug quality 46, and three-plant Atmosphere 14. Spec and test examples agree.
- Checked that both documents exist, Markdown fences balance, 18 proposed catalogue rows are present, all 11 tasks have coverage, and neither document contains unfinished placeholder markers.
- This task changes documentation only. Implementation, automated gameplay checks, device measurements, and user testing remain future work.
