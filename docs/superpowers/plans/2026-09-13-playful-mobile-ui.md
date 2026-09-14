# Playful Mobile UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Purrington Hotel feel like a friendly mobile game through larger visible cats, illustrated activities and consistent, accessible controls across its existing features.

**Architecture:** Use the Godot project as the starting point for the approved fresh-version overhaul. Introduce shared phone-space layout, native game components and focused view modules, and improve the playable world's art. Existing controllers and data can be reused where they serve the new experience or replaced when needed; live UI actions use coherent controller transactions. Build the shell/navigation first, then each redesigned activity.

**Tech Stack:** Godot 4.7.2, GDScript, GL Compatibility, existing Fredoka/Nunito fonts, native Control nodes and existing 3D thumbnails.

**Spec:** [Playful mobile UI design](../specs/2026-09-13-playful-mobile-ui-design.md)

**Review assets:** [12 screen concepts and current-game evidence](../../mobile-ui-redesign/README.md)

**Status:** Approved for full implementation using subagents, including every feature shown in the concept screens.

**User steering during implementation:** This is a complete fresh-version overhaul; current game data does not need to be kept. Existing data, IDs, economy and save schema are starting points rather than compatibility requirements. The spec's implementation-steering paragraph and the execution constraints supersede older preservation wording in task examples. The playable hotel's visual presentation is included in the overhaul.

## Global Constraints

- Keep Godot 4.7.2, GDScript and the existing GL Compatibility renderer.
- Add no new runtime dependencies or external fonts; use the bundled Fredoka and Nunito.
- Every hotel worker, guest and neighborhood resident is a cat.
- This is a fresh-version overhaul. Current game data does not need to be kept. Existing economy, content IDs, progression and save schema are starting points, not compatibility requirements; replace them where the approved design benefits. Keep the resulting game coherent and transactional.
- Earned currency remains Cat Coins; add no gems, energy, loot boxes or new daily-reward system.
- Primary navigation is Hotel, Cats, Build, Life, Map, in that order.
- Build is a contextual workspace: Place saves immediately; Undo refunds the action; Play exits immediately; Cancel discards only the unpurchased preview.
- Every interactive target is at least 48×48 phone units; primary action height is at least 56 phone units.
- Body text is at least 16 phone units; essential secondary text is at least 14 phone units; navigation labels are at least 12 phone units.
- Support text sizes 100%, 125% and 150%, preserving access to every action through reflow or scrolling.
- Respect all four safe-area insets and provide keyboard/controller focus and Android Back behavior.
- Test 360×640, 360×800, 390×844, 430×932 and 1280×800, with additional simulated safe-area insets.
- Use dark pine text on mint, coral and gold controls; small white text on these light fills is not acceptable.
- Generated mockup text, prices and statistics are illustrative. Use live, coherent game data in native UI. The concept boards define the playful visual experience across the app, including the playable hotel.
- Keep normal player saves and live commerce untouched during verification.

---

## Repository map and implementation order

`scripts/ui/hotel_ui.gd` extends `mobile_ui.gd`; `scripts/main.gd` owns their model, world and signal connections. `build_panel.gd` already implements immediate transactions and uses `build_metrics.gd` for density-aware geometry. Its layout logic should be extended, not replaced with a second builder. `hotel_world.gd` owns camera behavior; `world_activity.gd` owns repair markers and grounds labels. UI commands already reach real gameplay through `command`, `grounds_button` and the controller's connected signals.

| File | Responsibility |
| --- | --- |
| Create `scripts/ui/phone_layout.gd` | Pure geometry in canvas units, parameterized by safe area, phone scale and text scale |
| Create `scripts/ui/playful_theme.gd` | Palette and native button/panel styles; no model access |
| Create `scripts/ui/game_sheet.gd` | Pinned header, scrollable content, pinned action and Back signal |
| Create `scripts/ui/game_tile.gd` | Whole-card accessible button containing art, title and detail |
| Modify `scripts/ui/mobile_ui.gd` | Shared factories, chrome, sheet compatibility and route state |
| Modify `scripts/ui/hotel_ui.gd` | Existing routes/signals; delegate screen bodies to modules |
| Create `scripts/ui/views/cat_views.gd` | Cat collection, profile and invitation content |
| Create `scripts/ui/views/life_views.gd` | Life hub, gatherings, staff, discoveries and scrapbook |
| Create `scripts/ui/views/grounds_views.gd` | Garden, amenities, manager and Paw Mart |
| Create `scripts/ui/views/travel_views.gd` | Map, selected destination and expansion shop |
| Create `scripts/ui/views/home_views.gd` | Upgrades, welcome, offline reward and settings |
| Modify `scripts/ui/build_panel.gd`, `build_catalogue.gd`, `build_room_stats.gd`, `build_metrics.gd` | Existing builder's new presentation and scaling compatibility |
| Modify `scripts/ui/game_icon.gd`, `menu_art.gd`, `cat_badge.gd` | Consistent icons, distinct destination art and cat portraits |
| Modify `scripts/world/hotel_world.gd`, `scripts/ui/world_activity.gd` | Active-hotel camera framing and limited contextual labels |
| Modify `scripts/main.gd`, `scripts/core/hotel_model.gd` | Camera/view signals, Back forwarding and global text-size setting |
| Create `tests/test_mobile_layout.gd`, `test_mobile_navigation.gd`, `test_mobile_views.gd` | Geometry, real input/navigation and screen state coverage |
| Modify `tools/test.ps1` and affected existing suites | Register new suites; replace superseded visual expectations |

Do not move all methods at once. Each view extraction preserves its route and moves its existing command wiring with it. Use existing test harness conventions: isolated `res://tmp/...` saves, `check(condition, message)`, two layout frames before reading control bounds, and `root.push_input` for meaningful click tests. Assertions below are inserted into the named suite's `run()` or helper, where `app`, `check` and `process_frame` already exist; they are not a new test framework.

Suggested reviewable sequence: Tasks 1–3 establish an independently usable shell; Task 4 modernizes Build; Tasks 5–8 replace the remaining screens; Task 9 completes the device matrix and documentation. Commit only the task's named files, never `git add .`—the repository currently reports all project files as untracked in this checkout.

## Task 1: Shared phone geometry, theme and text preferences

**Files:** Create `phone_layout.gd`, `playful_theme.gd`, `tests/test_mobile_layout.gd`; modify `mobile_ui.gd`, `build_panel.gd`, `build_catalogue.gd`, `build_room_stats.gd`, `hotel_model.gd`, `main.gd`, `tools/test.ps1`. Reuse `build_metrics.gd` safe-area/phone-scale conversion; modifying that file is necessary only if this integration requires a behavior change.

**Interfaces:**
- `PhoneLayout.measure(viewport: Vector2, safe: Rect2, phone_scale: float, text_scale: float) -> Dictionary` returns `unit`, `font_scale`, `target`, `safe_rect`, `header_rect`, `footer_rect`, `objective_rect`, `world_rect`, `content_rect`.
- `PlayfulTheme.panel(fill: Color, unit: float, radius: float = 20) -> StyleBoxFlat` and `PlayfulTheme.button_style(fill: Color, unit: float, pressed: bool = false) -> StyleBoxFlat`.
- Preserve existing `ui.label(text, font_size, color)`/`paragraph`/`button` APIs, with sizes interpreted as phone units. Add `canvas_label(text: String, pixels: int, color: Color) -> Label` and `canvas_paragraph(text: String, pixels: int, color: Color) -> Label` for Build's already-converted values. Replace Build's calls to the old helpers with these raw variants to prevent double scaling. Add `var metrics: Dictionary = {}` to MobileUI; populate it before building chrome, then recalculate on viewport/safe-area/text-setting changes.

- [ ] **1. Add the failing layout suite and register it in `tools/test.ps1`.** Use a SceneTree harness and these cases. A 450-unit canvas at scale 0.8 represents a 360-wide phone; all returned rectangles must remain inside the supplied safe rectangle.

```gdscript
var Layout = load("res://scripts/ui/phone_layout.gd")
for phone in [Vector2(360,640), Vector2(360,800), Vector2(390,844), Vector2(430,932)]:
    var scale: float = phone.x / 450.0
    var viewport: Vector2 = phone / scale
    for text_scale in [1.0, 1.25, 1.5]:
        var safe := Rect2(Vector2(12,32) / scale, (phone - Vector2(24,56)) / scale)
        var m: Dictionary = Layout.measure(viewport, safe, scale, text_scale)
        check(m.target * scale >= 48.0, "Minimum target measured in phone units")
        for key in ["header_rect", "footer_rect", "objective_rect", "world_rect", "content_rect"]:
            check(safe.encloses(m[key]), "Safe-area containment: " + key)
        check(not m.world_rect.intersects(m.footer_rect), "World excludes dock")
```

Run `./tools/test.ps1 -Suites test_mobile_layout`; expected failure because the resource does not yet exist. The suite must count missing resources and exit 1 instead of dereferencing a null script.

- [ ] **2. Implement the pure layout calculation and theme tokens.** Use this geometry as the shell contract:

```gdscript
extends RefCounted
static func measure(viewport: Vector2, safe: Rect2, phone_scale: float, text_scale: float) -> Dictionary:
    var unit := 1.0 / clampf(phone_scale, 0.1, 10.0)
    var font_scale := clampf(text_scale, 1.0, 1.5)
    var gap := 8.0 * unit
    var header_h := (80.0 if font_scale > 1.0 else 64.0) * unit
    var dock_h := 80.0 * unit
    var objective_h := (80.0 if font_scale > 1.0 else 64.0) * unit
    var header := Rect2(safe.position, Vector2(safe.size.x, header_h))
    var footer := Rect2(Vector2(safe.position.x, safe.end.y-dock_h), Vector2(safe.size.x,dock_h))
    var objective := Rect2(Vector2(safe.position.x,footer.position.y-gap-objective_h),Vector2(safe.size.x,objective_h))
    var world := Rect2(Vector2(safe.position.x,header.end.y+gap),Vector2(safe.size.x,objective.position.y-header.end.y-gap*2))
    var content := Rect2(Vector2(safe.position.x,header.end.y+gap),Vector2(safe.size.x,footer.position.y-header.end.y-gap*2))
    return {"unit":unit,"font_scale":font_scale,"target":48.0*unit,"safe_rect":safe,"header_rect":header,"footer_rect":footer,"objective_rect":objective,"world_rect":world,"content_rect":content}
```

Use the spec's exact colors. Keep dark ink for normal, hover and pressed button labels. A pressed button reduces its lower shadow/edge from 3 to 1 phone units; a focused button receives a 3-unit dark-pine outline. `button()` must set `custom_minimum_size = Vector2(48, 56 if primary else 48) * metrics.unit` and assign an accessibility name. The title helper uses Fredoka; paragraphs use Nunito regardless of size. Decorative art ignores mouse input.

- [ ] **3. Extend setting migration and transaction validation.** Add `ui_text_scale: 1.0` to defaults. Keep the existing `build_text_scale` validation. After it, restore the global value:

```gdscript
var scale_value = saved_settings.get("ui_text_scale", settings.build_text_scale)
if not (scale_value is float or scale_value is int) or scale_value not in [1.0,1.25,1.5]:
    return false
settings.ui_text_scale = float(scale_value)
```

Place the migration code within the existing Dictionary guard for saved_settings. In `main.gd::change_setting`, treat `ui_text_scale` and `build_text_scale` as numeric exceptions to boolean validation. When the global setting changes, update both values in the same `before`/`_commit` transaction; a legacy Build-only update need not change the global value. After success relayout the UI and visible builder. Test old saves with no scale, old saves with Build scale 1.5, rejected values 0/2/NaN/true/string, successful reload and failed-save rollback.

- [ ] **4. Verify and commit.** Run `./tools/test.ps1 -Suites test_mobile_layout,test_model,test_store,test_build_input,test_build_mode`. Expect PASS and existing Build target tests unchanged. Capture the unchanged Build flow at 360×640 to confirm the raw helper migration did not double-scale controls. Commit message: `feat: share mobile layout and accessible theme tokens`.

## Task 2: Five-destination dock and reusable detail sheets

**Files:** Create `game_sheet.gd`, `game_tile.gd`, `tests/test_mobile_navigation.gd`; modify `mobile_ui.gd`, `hotel_ui.gd`, `main.gd`, `game_icon.gd`, `tools/test.ps1`.

**Visual target:** Inspect the actual first and second PNG boards in docs/mobile-ui-redesign before designing the shared chrome. Build a bright, friendly toy-like shell, with chunky illustrated dock icons and visible selected states. The user approved a complete fresh-version overhaul; legacy UI layouts are not constraints. Updated constraints.md takes precedence over older preservation wording.

**Interfaces:**
- `GameSheet.configure(ui: Control, title: String, bounds: Rect2) -> VBoxContainer` returns its scroll body; public `scroll: ScrollContainer`, `primary: Button`; `set_primary(text: String, callback: Callable, disabled: bool = false) -> Button`; signal `back_requested`.
- `GameTile.configure(ui: Control, title: String, detail: String, art: Control, callback: Callable) -> void`; extends Button; entire tile is a target.
- `ui.go_back() -> void`, `ui.open_route(route: String, parent_route: String = "Hotel") -> void`, `ui.parent_tab(route: String) -> String`, `ui.set_primary_action(text: String, callback: Callable, disabled: bool = false) -> Button`.
- Preserve `_base_sheet(title, height) -> VBoxContainer`, `close_sheet`, `_navigate`, existing UI signals, `sheet`, `sheet_content`, `live_buttons`, `purchase_buttons` and test-visible control names. `GameSheet` becomes the instance held in `sheet`.

- [ ] **1. Add actual-input navigation regressions before changing routes.** Copy the existing click helper from `test_app.gd`, instantiate an isolated app and start it. Verify:

```gdscript
check(app.ui.nav_buttons.keys() == ["Hotel","Cats","Build","Life","Map"], "Five stable destinations")
await click(app.ui.nav_buttons["Cats"])
app.ui.open_cat(0)
app.ui.go_back()
check(app.ui.tab == "Cats", "Profile returns to collection")
await click(app.ui.nav_buttons["Life"])
app.ui.open_route("Staff", "Life")
app.ui.go_back()
check(app.ui.tab == "Life", "Staff returns to Life")
await click(app.ui.nav_buttons["Build"])
check(app.build_panel.visible and not app.ui.footer.visible, "Build enters contextual workspace")
```

Run `./tools/test.ps1 -Suites test_mobile_navigation`; expect failure before the new dock/API exists.

- [ ] **2. Build sheets and whole-card tiles from native containers.** `GameSheet` has a VBox containing an HBox title/Back row, an expanding ScrollContainer with body VBox, then a separate primary-action Button. Only the body scrolls. `set_primary` disconnects the previous callable before connecting another. Clip the body, not the outer focus ring. `GameTile` contains one ignored-mouse VBox with art, wrapped title and detail. Give each tile a stable name and accessibility name equal to its title plus actionable state; do not create nested clickable buttons.

Route-to-dock mapping:

```gdscript
const DOCK = ["Hotel","Cats","Build","Life","Map"]
func parent_tab(route: String) -> String:
    if route in ["Cats","Pet","Invitations"]: return "Cats"
    if route in ["Life","Events","Staff","Journal","Discoveries","Grounds","Amenity","Manager","Kiosk"]: return "Life"
    if route in ["Map","Shop"]: return "Map"
    if route == "Build": return "Build"
    return "Hotel"
```

`open_route` records its actual parent rather than deriving every Back target from this mapping. Capture scroll value and focus-owner name before rebuilding a sheet and restore after two layout frames. On model tick, update labels/buttons in place whenever possible; do not recreate the petting viewport every second. Dismissing shade must consume the input event.

- [ ] **3. Replace the quick bar and wire Back.** Move Build to the dock, Hotel life to Life, Shop to Map → expansions, and Inside/Outside to View. Preserve `view_button` as the current inside/outside action within View. Keep `quick_bar` as an empty hidden compatibility node only until existing tests are migrated, then remove it in Task 9. `_navigate("Build")` emits `build_requested`; it must not create a modal sheet. `_navigate("Hotel")` calls `close_sheet()` without emitting camera reset. Update `main.gd` to forward Android Back to `ui.go_back()` for non-Build detail screens; keep existing Build cancel/close rules first. Escape follows the same route.

- [ ] **4. Verify and commit.** Run `./tools/test.ps1 -Suites test_mobile_navigation,test_app,test_experience,test_startup_offline,test_build_flow`. Replace only obsolete assertions about quick-bar presence and old tab labels, preserving their real behavior checks. Manually inspect dock labels and sheet close/focus targets at 360×640 and 150% text. Commit: `feat: simplify mobile navigation and detail sheets`.

## Task 3: Make the active hotel visible and its objective useful

**Files:** Modify `hotel_world.gd`, `world_activity.gd`, `mobile_ui.gd`, `hotel_ui.gd`, `main.gd`, `tests/test_mobile_navigation.gd`, `tests/test_app.gd`, `tests/test_views.gd`.

**Approved overhaul addition:** Improve the playable hotel's visual presentation against the approved first concept board, beyond camera framing: warm cream architecture, mint/coral/honey room accents, cozy furniture/materials and welcoming light, recognizable expressive cats, less empty floor. Inspect the current generated geometry/material helpers and make a coherent focused improvement. New data/progression may be replaced if helpful; legacy save compatibility is not required. Keep the playable 3D world and building interactions, and record before/after rendered evidence. Additional world/material helper files may be changed as required. The full generated backdrop is an illustration for welcome, not a substitute for the interactive world.

**Interfaces:**
- `ui.world_rect_changed(rect: Rect2)` signal and `world.set_ui_world_rect(rect: Rect2) -> void`; `world_input_contains(point)` reads the same rectangle.
- Keep `world.focus_hotel()`, `reset_camera()` (explicit Fit all), `focus_zone(index)`, and property bounds.
- `ui.next_action(data: Dictionary) -> Dictionary` returns `{"title": String, "detail": String, "route": String, "payload": Dictionary}`.

- [ ] **1. Add a regression for the observed return-camera bug.** Retain this test after implementation:

```gdscript
app.world.focus_zone(0)
var target: Vector3 = app.world.camera_target
var zoom: float = app.world.camera.size
await click(app.ui.nav_buttons["Cats"])
await click(app.ui.nav_buttons["Hotel"])
check(app.world.camera_target.is_equal_approx(target), "Returning from Cats preserves target")
check(is_equal_approx(app.world.camera.size, zoom), "Returning from Cats preserves zoom")
app.ui.reset_camera_requested.emit()
check(app.world.overview, "Explicit Fit all still enters overview")
```

Add starter-state checks that both bed positions project into the world rectangle and the first cat's rendered screen bounds are at least 28 phone units high. Fit-all containment tests remain separate; do not require the default close view to show every future wing.

- [ ] **2. Fit current rooms instead of the entire grounds.** Calculate points from `room_builder.room_nodes` visible MeshInstance3D AABBs transformed to world space, plus reception/service extents. Exclude hidden ghost/grid/label/locked-wing geometry. Project bounds along `ISO_RIGHT`/`ISO_UP`; use the UI-provided available world rectangle to calculate orthographic size:

```gdscript
# projected_size is in world units along the camera's ground-plane axes.
var width_fit: float = projected_size.x * viewport_size.x / (world_rect.size.x * 0.92)
var height_fit: float = projected_size.y * viewport_size.x / (world_rect.size.y * 0.88)
camera.size = clampf(maxf(width_fit, height_fit), 8.0, overview_zoom)
overview = false
```

Center the projected bounds in `world_rect`, retaining `_clamp_camera`'s property constraints. On resize, recompute explicit overview framing only when `overview` is true; otherwise preserve the user's target/zoom as far as bounds permit. At 360-wide starter state, adjust the active-frame set to the two bedrooms and reception if unused public floor would shrink cats below the 28-unit acceptance threshold. Explicit Hotel view recenters; normal dock navigation does not.

- [ ] **3. Reduce world labels and restore an actionable objective.** Collect candidate repair/ground/cat labels before drawing, stable-sort by selected object → current job/repair → nearest available action → ambient cat message, then accept nonintersecting rectangles inside the world region until three are placed. Provide at least 48-unit hit regions where labels are clickable. Keep underlying world selection independent of label visibility. Test crowded full-hotel state and all hidden marker hit regions.

Replace `_update_grounds`' unconditional generic neighborhood copy with the spec's objective priority: pending earnings, running job/repair, pinned discovery, available service upgrade. Each route uses existing methods/signals; e.g. an upgrade payload `{"zone": index}` dispatches `open_upgrades(index)`. Do not invent reward-bearing quests. For unaffordable upgrades, show the real shortfall and permit opening details.

- [ ] **4. Verify and commit.** Run `./tools/test.ps1 -Suites test_mobile_navigation,test_app,test_views,test_layout_grounds,test_grounds`. Render starter, full hotel, inside/outside, manager and returned-from-Cats states. Confirm clipping/hit areas use shared geometry. Commit: `feat: bring cats into focus on the mobile hotel screen`.

## Task 4: Illustrated Build catalogue and compact placement tray

**Files:** Modify `build_panel.gd`, `build_catalogue.gd`, `build_metrics.gd`, `build_room_stats.gd`, `furniture_thumbnail.gd`, `scripts/world/furniture_renderer.gd` (matching furniture art), `scripts/world/room_builder.gd` (standalone integration guard), `tests/test_furniture_preview.gd` as relevant, `tests/test_build_mode.gd`, `tests/test_build_flow.gd`, `tests/test_build_input.gd`.

**Visual target:** Inspect board 1. Give the actual catalogue a warm illustrated toy-shop feel with mint/coral/honey furniture art, cream whole-card tiles, clear selected states and a generous preview. Update the existing native FurnitureThumbnail palette/details; keep item silhouettes paired correctly with live catalogue data. In particular, the Window perch should read as a warm-wood, mint-cushioned perch/bench in both its thumbnail and actual FurnitureRenderer, rather than the previous plain-table silhouette; retain placement dimensions and price semantics. The world and preview stay genuinely interactive.

**Interfaces:** Keep `BuildCatalogue.populate(ui, model, hotel, category, target, text_scale, affordable, sort_by, available)` and `item_selected(item: String, uid: String)`. Keep every public panel operation, session, ghost/validity field and transaction path. Add `set_filter_panel_visible(visible: bool) -> void` only as presentation state; existing affordability/sort fields remain authoritative.

- [ ] **1. Extend the existing rendered Build test.** Add physical-coordinate checks at 360×640, 100% and 150%. Verify Play, Place/Paste, Cancel and Rotate remain visible; placement world area is at least 50% of safe height; expanded browse allows scrolling to every item; selecting a card collapses browse and does not charge coins.

```gdscript
panel.open()
var before: Dictionary = app.model.serialize()
panel.preview_item("perch")
await process_frame
check(app.model.serialize() == before, "Selecting a catalogue card never purchases")
check(not panel.browse, "Selection collapses browse into placement")
check(panel.confirm_button.text.contains("150"), "Place displays the actual perch quote")
check(panel.find_child("CloseBuilder",true,false).is_visible_in_tree(), "Play remains visible")
```

Run the existing Build suites before changing their layout. New collapse/geometry assertions must fail against the old presentation; transaction assertions should already pass.

- [ ] **2. Replace catalogue rows with whole-card tiles.** Keep the existing item collection, free-reuse/lock checks, sort and price logic. Render a two-column grid at normal text, one column at 150%, with large `FurnitureThumbnail` art, wrapped item name and price/ownership state. Preserve `FurnitureCard_<id-or-uid>` names. Put detailed Comfort/Entertainment/Atmosphere and footprint in the selected-item tray. Preserve access to filters, sorting and empty storage/filter copy. Expanded browse may use more vertical space than placement; at 360×640 normal text show at least the first complete furniture row including prices without initial scrolling. Selection still collapses browse and gives at least half the safe height back to placement.

Use the existing `preview_item` path, then set `browse = false` and refresh. Do not instantiate thumbnails on each income tick; cache by item ID and only update affordability text/states.

- [ ] **3. Recompose placement without changing its transaction.** Keep wallet/Play pinned at top and history immediately below. Compact tray contains name, known preference hint, validity copy and Rotate/Adjust. Footer contains labelled Cancel and the price action. Replace icon-only final labels with:

```gdscript
var cost: int = _ghost_cost()
var caption: String = "Move · Free" if ghost_intent == "move" else ("Place · Free" if cost == 0 else "Place · %s" % ui.number(cost))
confirm_button.text = caption
confirm_button.accessibility_name = caption + " Cat Coins" if cost > 0 else caption
confirm_button.disabled = not validity.get("ok",false)
```

Place that code inside `_update_action`'s ghost branch after `_check_ghost()`. For room blueprints use `blueprint_cost` and `Paste`. A save failure must allow retry; do not permanently disable a valid preview because the previous save failed. Keep the same error/rollback machinery, nudge directions, Store object, Copy room, Move room, Restore previous makeover and all 20 history actions.

**Integration regression:** The required standalone room-blueprint suite exposes a null world access in RoomBuilder.sync after the recent world-art visibility changes. Guard standalone use coherently (without requiring a HotelWorld), keep hotel/Build visibility correct, and include focused blueprint regression coverage. SCRIPT ERROR output must be fixed, even if the suite prints PASS.

- [ ] **4. Verify and commit.** Run `./tools/test.ps1 -Suites test_build_mode,test_build_input,test_build_flow,test_build_history,test_build_recovery,test_room_blueprint,test_furniture_inventory,test_build_transactions`. Update the old assertion requiring text exactly `140 coins` to require the new readable `Place · 140` caption and same accessibility semantics. Render invalid and unaffordable states at 360×640. Commit: `feat: make mobile building visual and thumb friendly`.

## Task 5: Collectible cats and focused care

**Files:** Create `scripts/ui/views/cat_views.gd`, `tests/test_mobile_views.gd`; modify `hotel_ui.gd`, `cat_interaction.gd`, `cat_badge.gd`, `game_icon.gd` (or a focused atlas/toy-art helper), `tools/test.ps1`, `tests/test_experience.gd`.

**Visual target:** Inspect boards 1 and 3 in docs/mobile-ui-redesign. Make collectible cat cards expressive and colorful. The live care stage should feel like the cozy cushion/room setting in the concept, not a cat floating in a blank viewport: add a lightweight warm cushion/ground and a few friendly room details using runtime geometry. Let the cat fill the stage and preserve held petting/toy reactions. The user approved a complete fresh-version overhaul; legacy data/UI are not compatibility constraints.

**Prepared portrait artwork:** Read production-art-handoff.md beside this brief. Use cats-01.png, cats-02.png and cats-03.png as eighteen correctly indexed AtlasTexture portraits in collection/album UI; keep unknown portraits hidden with a native silhouette. The handoff specifies row-major mapping. Cache textures/regions and commit the consumed PNG/import pairs. Keep the live care stage in 3D.

**Interfaces:** Static `CatViews.collection(ui: Control) -> void`, `profile(ui: Control, cat_index: int) -> void`, `invitations(ui: Control, cat_index: int) -> void`. Preserve `selected_cat`, `pet_view`, `bond_label`, `preference_label`, `open_cat(index)`, `command(action,payload)` and `Interact_<kind>` names. Add transient `cat_filter: String = "Met"` to HotelUI.

- [ ] **1. Add real-input regressions and run them before migration.** Use the existing isolated SceneTree harness and click helper:

```gdscript
app.ui.open_cat(0)
await process_frame
var stage = app.ui.pet_view
var bond: int = app.model.life.state.cats[0].bond
await click(app.ui.sheet.find_child("Interact_pet",true,false))
check(app.model.life.state.cats[0].bond > bond, "Pet changes real friendship")
check(app.ui.pet_view == stage, "Friendship refresh preserves petting stage")
app.ui.go_back()
check(app.ui.tab == "Cats", "Care returns to collection")
```

Add held-gesture release outside the stage, unknown cat, unowned expansion cat, locked playdate and 150% text cases. Run `./tools/test.ps1 -Suites test_mobile_views,test_experience`; new Back/geometry assertions must fail against the old UI.

- [ ] **2. Build collectible whole-card buttons.** Iterate all 18 Content indices, filter by existing `known`, and use `CatCard_<index>` names. Known cards contain portrait/name/trait/friendship; unknown cards use a silhouette and the existing discovery or expansion hint. Two columns at normal text, one at 150% when wrapping cannot fit. Store filter and scroll in UI presentation state; returning from Pet restores both. Never introduce rarity or a second ownership model.

- [ ] **3. Extract care and invitation views.** Create one live PetView in `profile`, using the existing `interacted` signal. Its 220-phone-unit stage remains in the scroll body so small phones can reach actions. Below it, build a GridContainer named `toys`, three columns normally and two at 150%:

```gdscript
for item in [["Pet","pet"],["Brush","brush"],["Feather","wand"],["Yarn","yarn"],["Cushion","cushion"],["Box","box"]]:
    var action = ui.button(item[0],func(): ui.pet_view.play(item[1]))
    action.name = "Interact_" + item[1]
    toys.add_child(action)
```

Give all six native toy buttons distinct large illustrations using the reviewed care-toys.png atlas: paw, brush, feather, yarn, cushion and box. The handoff specifies exact cell order. Cache the texture/regions, keep text and controls native, and commit the PNG/import pair; a focused atlas helper is suitable. Keep labels and actions native with the required target sizes and readable large-text layout. Keep friendship and discovered-preference labels live without recreating PetView. Favorite emits `command("favorite",{"cat":cat_index})`. Invitations is a child route of Pet: hotel invite emits `invite`; playdate emits `playdate` with `cat` and `other`. Carry over the lounge and both-bonds-at-least-10 requirements. Unknown preferences stay unknown.

**Care-content consistency:** Existing Content.FAVORITE_ACTIONS includes an unreachable bell favorite for Biscuit, while the approved care UI has six actions without Bell. The user removed legacy-data constraints. Align every guest favorite with one of the six available care actions (adjust content and focused life coverage as needed) so no guest has an unreachable favorite bonus. Keep the six illustrated actions and coherent existing reward validation.

**Controller visual refinement:** Use a soft-looking gold cushion and a relaxed resting pose in the live care room where existing animation supports it, preserving actual toy reactions. Give the live friendship value a native heart/progress treatment matching the collection and Board 1; update it in place without rebuilding PetView. This adds visual feedback, not another reward mechanic.

- [ ] **4. Verify and commit.** Run `./tools/test.ps1 -Suites test_mobile_views,test_mobile_navigation,test_experience,test_life,test_audio`. Inspect six toys and invitation scrolling at 360×640/150%. Commit: `feat: give cats a collectible album and focused care view`.

## Task 6: Illustrated Life, gatherings, staff, garden and memories

**Files:** Create `scripts/ui/views/life_views.gd`, `grounds_views.gd`; modify `hotel_ui.gd`, `menu_art.gd`, `game_icon.gd`, `tests/test_mobile_views.gd`, `tests/test_experience.gd`, `tests/test_grounds.gd`.

**Visual target and prepared art:** Inspect boards 2 and 3. Read production-art-handoff.md in this brief's directory and use the reviewed gathering, staff, garden, scrapbook and Paw Mart PNGs in the new views. Commit the art files you consume. Use clear distinct native illustrations for remaining cards, without generic bed fallbacks. The user approved a complete fresh-version overhaul, so old data and UI layout are not compatibility constraints. Specialty should expose all currently supported choices (the actual content has Balanced plus three themed choices; the older 'three options' wording is shorthand).

**Interfaces:** Static LifeViews methods `hub(ui: Control)`, `events(ui: Control)`, `staff(ui: Control)`, `discoveries(ui: Control)`, `journal(ui: Control)`, all return void. GroundsViews methods `garden(ui: Control)`, `amenity(ui: Control)`, `manager(ui: Control)`, `kiosk(ui: Control)`, all return void. Preserve `event_label`, `job_status`, `maid_status`, `grounds_buttons` and command IDs. Add transient `selected_staff: int = 0`.

- [ ] **1. Add reachability and state-refresh tests.** Run this after starting an isolated app:

```gdscript
app.ui._navigate("Life")
for route in ["Grounds","Manager","Staff","Journal","Discoveries","Kiosk"]:
    var tile = app.ui.sheet.find_child("Life_"+route,true,false)
    check(tile != null, "Life exposes " + route)
    if tile == null: continue
    await click(tile)
    check(app.ui.tab == route, "Tile opens existing route")
    app.ui.go_back()
    check(app.ui.tab == "Life", "Detail returns to hub")
```

Also retain staff selection/scroll across state updates and verify reopening an event result does not grant its reward twice. Use the current event fixture from `test_experience.gd`. Run `./tools/test.ps1 -Suites test_mobile_views,test_experience,test_grounds` before migration.

- [ ] **2. Build the six-tile hub and one featured event.** Create a GridContainer named `grid` with two columns (one at 150%), and wire exact routes:

```gdscript
var routes = {"Garden":"Grounds","Manager":"Manager","Staff":"Staff","Scrapbook":"Journal","Discoveries":"Discoveries","Paw Mart":"Kiosk"}
for title in routes:
    var route: String = routes[title]
    var tile = preload("res://scripts/ui/game_tile.gd").new()
    tile.name = "Life_" + route
    grid.add_child(tile)
    tile.configure(ui,title,"",ui.art(route.to_lower(),88*ui.metrics.unit),func(): ui.open_route(route,"Life"))
```

Extend MenuArt for these six lowercase art kinds. Reuse cat/room geometry and the new palette. The featured gathering opens Events. Watch closes the sheet and changes the existing watch setting. Specialty exposes Balanced and the three themed options, with the existing level-3 gate.

- [ ] **3. Recompose events, staff and discoveries around existing state.** Event cards use Content.EVENTS, event_scores, active event, trophy and cooldown data. Give each of the three shared and three destination gatherings a recognizable illustration: use the reviewed nap/cardboard/lantern/beach/trail/spa PNGs listed in production-art-handoff.md. All six finished illustrations are already available; preserve their distinct scenes and native live event details. Keep Event_<id> names. Host calls `command("event",{"id":id})`; show actual readiness, duration and first-trophy reward, with running/cooldown updates in place. Do not create a separate reward claim.

Staff uses three distinct portraits (appropriate AtlasTexture regions of staff.png are suitable) and shows one selected Pippin/Saffron/Buttons card, training 0–3, next cost `250*(h.staff[index]+1)`, and existing skill choices. Preserve train/skill commands and service-open/max-trained restrictions. Discoveries uses star_checks, review, InviteInspector and Content.COMBOS; pin/inspect commands remain unchanged. Concrete requirements remain readable.

Carry the selected staff index through the world entry path as well: the existing `world.staff_selected(index)` connection in `scripts/main.gd` currently discards the index because the old screen listed everyone. Update that focused connection so tapping a worker opens that worker's selected card, and cover the emitted index in an integration check.

- [ ] **4. Recompose grounds and album.** Garden cards use Grounds.AMENITIES and the existing grounds_button helper for price/level/owned state. Manager shows one current job, job cards and Daisy's hire/work states. Keep hire_maid, trim, chase, clean and treats IDs and current eligibility checks. Paw Mart explicitly uses Cat Coins and the existing 30-coin picnic/cooldown.

Keep a native Take a hotel photo action in both empty and populated Journal states, wired to the existing photo_requested signal; capture a real current-hotel photo and verify the resulting local album entry through the existing app path. Journal uses actual local entry.photo when available, otherwise the correct indexed cat portrait from Task 5; keep title/text/day/hotel and Visit cat. Empty state links to Cats or the existing photo signal. Retain the 80-entry limit; cache display-size photo thumbnails rather than keeping all full-resolution files loaded. No sharing/upload flow is added.

- [ ] **5. Verify and commit.** Run `./tools/test.ps1 -Suites test_mobile_views,test_mobile_navigation,test_experience,test_grounds,test_life`. Capture event ready/running/complete, staff 0/3 and 3/3, unknown/found combo, empty/populated album, amenity locked/owned and Daisy before/after hire at normal/large text. Commit: `feat: turn hotel life into illustrated game activities`.

## Task 7: Hotel journey and expansion states

**Files:** Create `scripts/ui/views/travel_views.gd`; modify `hotel_ui.gd`, `menu_art.gd`, `tests/test_mobile_views.gd`, `tests/test_app.gd`; retain `tests/test_commerce.gd`.

**Visual target and prepared art:** Inspect board 2. Read production-art-handoff.md in this brief's directory and use assets/ui/mobile/world-map.png as the text-free illustrated journey with native destination controls; the handoff gives actual building positions. You can use AtlasTexture regions as four distinct destination postcards. Preserve aspect ratio and account for image bounds when positioning controls. At large text reflow into an accessible illustrated destination list if pins would overlap. Commit consumed art. The user approved a fresh-version overhaul; prices/IDs from old data are defaults, not legacy compatibility requirements. Keep resulting costs/restrictions coherent and surfaced live.

**Interfaces:** Static `TravelViews.map(ui: Control) -> void`, `shop(ui: Control) -> void`; transient `selected_destination: int = 1`. Preserve hotel/purchase/restore/privacy signals, UnlockHotel, Purchase_<product_id-with-underscores>, purchase_buttons, commerce dictionary and live_buttons.

- [ ] **1. Add state-distinction tests.** Against an isolated desktop fixture:

```gdscript
app.ui._navigate("Map")
check(app.ui.sheet.find_child("Destination_0",true,false) != null, "Meadow is navigable")
check(app.ui.sheet.find_child("Destination_3",true,false) != null, "Snowcap is discoverable")
check(app.ui.sheet.find_child("UnlockHotel",true,false).disabled, "Seaside keeps its gate")
app.ui._navigate("Shop")
check(app.ui.purchase_buttons.all(func(b): return b.disabled), "Unavailable store cannot buy")
```

Extend with an owned Forest entitlement, pending/cancelled/failed purchase and exact localized price supplied by the existing commerce fixture. Run `./tools/test.ps1 -Suites test_mobile_views,test_app,test_commerce` before changing presentation.

Include a partial catalogue fixture: a ready store may return a price for only some products. A non-preview product without its own returned localized price must remain disabled as Store unavailable even when another product is available. Preview purchases retain their explicit test labels and behavior.

- [ ] **2. Build the visual journey with native buttons.** Distinct MenuArt kinds are hotel_meadow, hotel_seaside, hotel_forest, hotel_snowcap. Decorative path ignores input. Each Destination_<index> button selects the pinned details card. The primary Button returned by set_primary_action uses these state rules:

```gdscript
if ui.snapshot.owned[index]:
    action.text = "You're here" if index == ui.snapshot.hotel else "Visit hotel"
    action.disabled = index == ui.snapshot.hotel
elif index == 1:
    action.text = "Open Seaside · 10,000" if ui.snapshot.can_unlock else ("Reach Meadow level 10" if ui.snapshot.meadow_level < 10 else "Save %s more coins" % ui.number(maxf(0,10000-ui.snapshot.coins)))
    action.disabled = not ui.snapshot.can_unlock or ui.snapshot.save_error != ""
else:
    action.text = "View expansion"
    action.disabled = false
```

Define `index` as selected_destination and `action` as the returned primary Button. Rebind its callback on selection. Owned/Seaside actions emit hotel_requested(index); paid locations open Shop and focus the matching product. Keep both level and coin requirements visible. Use the live balance, never mockup values.

Use visible destination names on the native map controls, matching Board 2, rather than unexplained numeric markers. Pin the selected hotel's name and live requirements together with its primary action. At large text, the illustrated destination list should begin below the title; omit a redundant full-map thumbnail or introductory paragraph when they hide all destination choices. Keep native targets non-overlapping and preserve scroll access to every destination.

- [ ] **3. Restyle products without changing commerce.** Use Content.PRODUCTS, life.entitlements and commerce.prices/ready/busy/preview. Each card has included content, actual localized price or Store unavailable, ad-removal note and purchase action. Preserve test-purchase labels. Restore is a separate 48-unit target. Keep consent/privacy reachable. Update pending product state in place to preserve focus.

- [ ] **4. Verify and commit.** Run `./tools/test.ps1 -Suites test_mobile_views,test_mobile_navigation,test_app,test_commerce,test_store,test_experience`. Capture Seaside with neither/one/both requirements met, and unavailable/pending/owned expansions. Commit: `feat: make hotel travel a clear visual journey`.

## Task 8: Welcome, upgrades, rewards, preferences and feedback

**Files:** Create `scripts/ui/views/home_views.gd`; modify `mobile_ui.gd`, `hotel_ui.gd`, `menu_art.gd`, `tests/test_mobile_views.gd`, `tests/test_startup_offline.gd`, `tests/test_app.gd`.

**Visual target and prepared art:** Inspect board 4 and production-art-handoff.md beside this brief. Use assets/ui/mobile/welcome-hotel.png for the welcome illustration with authored native title and actions; choose crop/contain so cats and reception remain recognizable. This supersedes the original plan's keep-background wording. Use reward.png for welcome-back earnings and upgrade-lounge.png for the lounge upgrade; use distinct runtime 3D or native art for the other service upgrades. Commit consumed art. The user approved a complete fresh-version overhaul; current data need not be preserved, but the new game's rewards and saves must remain correct.

**Shared header finish:** Compare the actual Hotel header with Board 1: include a small distinct hotel illustration at normal text size where space permits, retain live name/level/rooms/wallet/income, and use dark readable income text on cream. At 150% text reduce optional art before shrinking essential labels or clipping the balance; use shared PhoneLayout geometry. The Task8 integration ruling permits112 phone units for larger text while retaining64 at normal size, keeping full labels and the large-wallet fixture readable. Update the shared measure centrally and verify affected mobile layout/navigation/world checks. Include a 360×640 large-text header capture and physical text/target checks.

**Interfaces:** Static HomeViews methods `welcome(ui: Control)`, `upgrades(ui: Control)`, `offline(ui: Control)`, `settings(ui: Control)`, all return void. Preserve PlayButton, PurchaseUpgrade, CollectEarnings, Setting_<key>, pending_button and selected_zone. Add LaterEarnings and `ui.show_inline_error(message: String) -> void`, using a persistent label above the sheet action.

- [ ] **1. Add reward dismiss/reopen and scale tests.** Use test_startup_offline's pending-reward fixture and freeze ordinary ticking with app.active=false:

```gdscript
var pending: int = app.model.pending_units
var wallet: int = app.model.coins_units
await click(app.ui.sheet.find_child("LaterEarnings",true,false))
check(app.model.pending_units == pending and app.model.coins_units == wallet, "Later does not claim")
app.ui.show_offline()
await click(app.ui.sheet.find_child("CollectEarnings",true,false))
check(app.model.pending_units == 0, "Claim clears pending once")
var claimed: int = app.model.coins_units
app.ui.show_offline()
check(app.model.coins_units == claimed, "Reopening cannot claim twice")
```

Add failed-save rollback/retry with the existing FailingStore fixture and 150%-text settings reachability. Run `./tools/test.ps1 -Suites test_mobile_views,test_startup_offline`; new Later/geometry checks fail before implementation.

Cover the new Welcome → Settings → Back path before the game has started: changing a preference or text size there must return to the welcome screen with Play still available, then Play starts the actual game.

- [ ] **2. Recompose welcome, upgrades and rewards.** Welcome uses the reviewed welcome-hotel.png illustration with an authored title, short subtitle, Play and Settings. Play emits play_requested with a paw icon, not a coin. Upgrade has four existing service tabs, real level/income progression, one illustration and pinned PurchaseUpgrade wired to upgrade_requested(selected_zone). Keep all live affordability/max-level/save-error conditions.

Offline shows pending, away_seconds, pending_seconds and the eight-hour cap. Later/close only dismiss. Collect emits claim_requested and closes only after the updated state confirms success; on failed save keep the reward and inline error visible. Never change wallet/pending units from UI code.

- [ ] **3. Group settings and expose the global scale.** Music→music; Sound effects→sound; Gentle animations→motion; Touch feedback→haptics; Evening lighting→evening; Seasonal weather→weather. Create scale_row as an HBox, or VBox if large text cannot fit three targets:

```gdscript
for scale in [1.0,1.25,1.5]:
    var choice = ui.button("%d%%" % int(scale*100),func(): ui.setting_changed.emit("ui_text_scale",scale))
    choice.name = "TextScale_%d" % int(scale*100)
    choice.accessibility_name = "Text size %d percent" % int(scale*100)
    scale_row.add_child(choice)
```

Selected state uses fill and an accessible description. Purchases & privacy exposes current restore/consent controls. Save status derives from save_error, never hard-coded success. Preserve focus across resizing.

Match Board 4's friendly preference rows with distinct small music/sound/cat/paw/evening/weather illustrations and clear native on/off treatment. Extend GameIcon or another focused native helper where needed; keep the controls accessible, touch-sized and reflowable rather than leaving unstyled default checkboxes.

- [ ] **4. Add restrained feedback, verify and commit.** Native pressed styles are immediate. Success-only sheet/coin/heart reactions last 160–220 ms; use zero transition duration when motion is false. Existing audio/haptics remains authoritative. Kill tweens on sheet replacement; toast sits above the dock/pinned action, while long save errors remain inline.

Connect success feedback at the existing successful controller action boundary (including a focused `scripts/main.gd` change if needed), rather than inferring success from toast wording. Failed validation or saving must not trigger the success reaction.

Run `./tools/test.ps1 -Suites test_mobile_views,test_startup_offline,test_app,test_audio,test_store,test_model`. Capture title, upgrade max/poor/affordable, reward dismissed/reopened/error, all text sizes and reduced motion. Commit: `feat: unify welcoming moments rewards and preferences`.


**Root first-capture refinements:** Welcome's native title should use weighted Fredoka around600 and a small native paw/sign treatment; tighten blank spacing around the contained hotel hero while preserving native Play/Settings. At360x640 normal text, the selected upgrade's actual level/income benefit should be visible above the fold; reduce optional hero height first. Settings evidence must include the initial top of the screen as well as scrolled scale/privacy controls.

## Task 9: Final visual and device verification

**Files:** Modify `tools/test.ps1`, the three new mobile suites, obsolete visual assertions and `README.md`; create `docs/mobile-ui-redesign/implementation-review.md`, `assets/ui/mobile/README.md`; add reviewed production assets only where consumed.

**Interfaces:** Keep suite registration, isolated saves and nonzero failure exits. Capture filenames include viewport, scale, route and state.

**Playable handoff:** Update tools/package.ps1's player instructions to the redesigned navigation and controls, then build the Windows preview and smoke-test the exported pack using tools/pack_smoke.gd. Use a fresh preview profile for the new overhaul so opening the review build does not load or modify a normal player save. Deliver builds/windows/Play.cmd and the zipped preview; keep launch commands usable from directories with spaces. Record the actual output paths in the implementation review. No publishing, real purchases, or signed mobile release is required.

**Final playthrough:** Run a short fresh-save rendered pointer-input walkthrough through Play, Cats/care, Build/select/place/return, Life, Map and Settings/text size. Use normal starting currency/progression for this walkthrough and record real resulting friendship/coin changes, with captures of the actual app. Separate this evidence from seeded fixtures that cover later-game locked/owned states. Keep all walkthrough saves in the isolated preview/test profile.

**Prepared artwork:** Read .superpowers/sdd/2026-09-13-playful-mobile-ui/production-art-handoff.md. Every selected production illustration is already copied under assets/ui/mobile; earlier view tasks should consume them. Consolidate the prompt provenance from production-art-prompts.md into the deliverable art manifest and remove/archive any unconsumed asset from the runtime package. Include controller-owned spec/plan steering edits, design README, final implementation review, exact production prompts, dimension/hash inventory and final asset manifest in this documentation commit. Commit generated .gd.uid files paired with the new source/test scripts where appropriate; exclude unrelated editor/import stat noise. Copy every chronological Ruling line from the SDD ledger into the implementation review before scratch cleanup. Do not delete the SDD ledger/reports: root still needs them for the final whole-branch review.

- [ ] **1. Remove compatibility chrome after all callers migrate.** Remove empty quick_bar and obsolete fixed UI/world offsets. Include the Task 5 review's unused HotelUI PetView preload in this cleanup if it remains after the other extractions. Find remaining callers:

```powershell
rg -n 'quick_bar|offset_bottom = -90|size.y - 150|size.y-165' scripts/ui scripts/main.gd tests
```

Replace quick-bar tests with shared geometry/physical-target checks, preserving Fit-all and transaction coverage. Every remaining fixed boundary must be justified in the implementation review.

Address the Task 6 review's full-album thumbnail eviction boundary during this cleanup: inserting a new photo into a full newest-first album must preserve cached textures for the other displayed photos, rather than cascading through synchronous reloads. Prune no-longer-displayed paths or otherwise protect the current album set, keep the existing cache cap, and add a focused capacity/reuse case in the mobile views suite. Full finding: `.superpowers/sdd/2026-09-13-playful-mobile-ui/task-6-review.md`.

- [ ] **2. Run one complete behavioral pass and the rendered matrix.** Register the navigation/views suites as rendered suites in tools/test.ps1. View tests iterate text scales through the real setting and use fresh fixtures for independent states:

```powershell
./tools/test.ps1
foreach ($resolution in @('360x640','360x800','390x844','430x932','1280x800')) {
    ./tools/test.ps1 -Rendered -Resolution $resolution -Suites test_mobile_navigation,test_mobile_views
}
```

At desktop widths constrain detail panels to a centered reading column or side tray. Record exit codes, failures, captures and safe-area fixtures.

Preserve a curated set of final actual captures under `docs/mobile-ui-redesign/after/`, covering the twelve primary concept screens and representative large-text/error states. Link these stable before/after artifacts from the implementation review; keep the complete exploratory matrix in ignored tmp rather than committing every intermediate image. Exported runtime packages continue to exclude design documentation.

Generate the curated Hotel and Build/error captures from the final integrated code too. The focused rendered `test_views,test_build_mode,test_build_flow` run at 360x640 can supply these alongside the mobile matrix and fresh pointer walkthrough, so the final after set does not depend on pre-header-polish screenshots.

- [ ] **3. Inspect every captured screen at actual phone size.** Verify target sizes after phone_scale multiplication, no overflow/clipped prices, reachable actions, contrast/focus, selection, scroll preservation and no label overlap. Inspect Build invalid/save-failure cases, rewards failed-save recovery and unknown/paid cats. Rerun only checks affected by subsequent fixes.

The production asset manifest lists 5 dock icons; coin/settings/view/back/close/rotate/undo/redo/adjust; 6 toy icons; 6 Life illustrations; 4 destination postcards; 3 shared and 3 destination gathering illustrations; 3 staff portraits; welcome/reward art; empty/locked states. Reuse runtime 3D illustrations where suitable. New assets are text-free and document intended display/import size. Never ship the composite concept boards as game screens.

- [ ] **4. Validate on a physical device and hand off.** On Android check notch/gesture inset, thumb reach, pinch/pan, held-pet release, Back, focus after interruption, haptics and offline resume. If no device is available, record this as an open release gate rather than a passed check. Purchases use platform test products only. Update README navigation/preferences and the implementation review with actual before/after evidence. Commit: `test: verify playful mobile UI across phone sizes`.






**Focused remaining fixed-control check:** HotelUI's Watch exit still sets position(16,20) and size(160,52) directly, while current Experience coverage only checks visibility. During compatibility-geometry cleanup, place that exit through shared safe/unit geometry and verify its full label and touch target at150% with four-edge insets and a real Back-to-hotel input. Review the pending-button legacy initial offsets at the same time; remove or justify them against the final shared relayout.

**Responsive Map integration ruling:** At enlarged text, selected destination details may scroll to avoid minimum-size overflow, while the primary action remains pinned. Normal text retains the pinned details card. Keep selected identity clear, deliberately reveal both live Seaside requirements after selection, and preserve coherent focus/scroll rather than burying the details below all four rows. Capture both the initial large-text list and selected Seaside requirements/action with insets. This supersedes Task7's always-pinned detail instruction only for enlarged text.
