# Purrington Hotel: playful mobile UI

**Status:** Approved for full implementation with subagents. The user explicitly requested the complete app overhaul and all features shown in the new screenshots.

**Implementation steering:** The user confirmed that current game data does not need to be kept. Existing economy, content IDs, progression and save schema are starting points, not compatibility requirements. Replace them where the new experience benefits; ensure the resulting game remains coherent and purchases/actions save correctly. The concepts define the visual target throughout the app, including the playable hotel. Legacy preservation statements below describe the original proposal and are superseded by this instruction. Normal player saves and live commerce are still excluded from automated verification.

**Requested outcome:** A better mobile UI throughout the game, informed by the original concepts and playing the existing game. The interface should feel playful, friendly and unmistakably like a game.

**Visual package:** [Concept boards and review](../../mobile-ui-redesign/README.md).

## Evidence and scope

Reviewed all six original images in `docs/concept-art`, the historical 360×800 prototype screenshots, the later room-building screenshots, current UI/controller code and current rendered gameplay. The earlier concept documents are historical; the current README and implemented content determine the available features.

Ran the actual Godot 4.7.2 game with isolated saves:

- `tests/test_app.gd` at 360×800: PASS, zero failures. Includes pointer clicks, upgrade purchase, camera/navigation, travel, settings and offline rewards.
- `tests/test_experience.gd` at 360×800: PASS, zero failures. Exercises petting, furnishings, staff training, a completed gathering, inspection, scrapbook and expansion states. Some progression is seeded or advanced through the controller.
- `tests/test_build_flow.gd` at 360×640: PASS, zero failures. Exercises immediate placement, cross-room moves, storage, copy/paste, undo/redo, rollback and leaving Build.
- An additional pointer-driven design walkthrough: Play → Cats → Miso → Pet → Brush → Hotel → Build → Play → Hotel life. Miso reached 6 friendship. The entry view, return view and catalogue were captured separately.

This is a desktop-rendered phone-size inspection with scripted input, not a physical-phone or human usability study. The runtime logged an OS root-certificate-store error; all three suites and the pointer walkthrough completed. No network purchase or normal player save was used.

### Findings

| Observation | Evidence | Design response |
| --- | --- | --- |
| The normal hotel view spends much of the phone on empty background and distant grounds; cats are difficult to distinguish. | `current/00-normal-play-camera.png` | Frame the inhabited hotel for normal play. Keep the whole-property view available explicitly. |
| Returning through Hotel makes the property smaller again. | `current/00-return-hotel-camera.png`; `_navigate("Hotel")` emits `reset_camera_requested` | Returning to Hotel closes a menu without resetting the camera. |
| Nine top/bottom navigation buttons compete, plus the objective row and world labels. | `current/02-hotel.png` | Five stable destinations; move contextual actions into their destination or a View control. |
| Build opens with instructions, category/filter controls and only about one furniture card visible. | `current/00-build-catalogue.png` | An image-first catalogue with compact categories; filters behind a labelled control. |
| Hotel life is a long list of nearly identical text buttons. | `current/22-hotel-life.png` | An illustrated activity hub with six tiles and one featured event. |
| Petting, friendship and playdate controls share one long scrolling sheet. | `current/20-petting.png` | A large petting stage and six immediate toy actions; put invitations/playdates in a secondary view. |
| Map destinations largely reuse one building illustration; event and staff screens have little character. | `current/04-map.png`, `24-events.png`, `23-staff.png` | Distinct destination postcards, gathering dioramas and cat staff portraits. |
| Most controls use logical-pixel sizes despite a 450-wide canvas shrinking to a 360-wide window. | `mobile_ui.gd`, `build_metrics.gd` | Share Build's existing phone-unit conversion throughout the UI. A 48-unit control at 0.8 scale is only 38.4 screen pixels. |
| Existing UI tests pass while the visual experience remains cramped. | Three passing rendered suites | Add physical-size, focus, camera and scroll-preservation assertions; include visual review gates. |

## Direction and alternatives

1. **Minimal recolor:** inexpensive, but keeps the navigation and long-menu problems.
2. **Playful diorama interface — recommended:** retain the voxel hotel, make cats and furniture prominent, use rounded toy-like controls, and reorganize existing features into five destinations.
3. **Full illustrated storybook replacement:** strong visual shift, but much larger art scope and a weaker connection to the playable 3D hotel.

Use option 2 as the foundation for the user's approved complete overhaul. The original references contribute warm light, Cat Coins, cat-run hotels, material warmth and expressive little scenes. The new UI adds brighter mint, peach and lilac accents, clearer thumb-sized actions, and fewer competing surfaces. The playable hotel also receives a coherent visual rework in geometry, materials, lighting and framing within the existing renderer; separately generated illustrations support menu moments rather than replacing the interactive 3D world.

## Global constraints

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

## Visual system

| Token | Value / treatment |
| --- | --- |
| Ink | `#24483E`; primary labels and button text |
| Secondary ink | `#53635B`; secondary copy on cream |
| Cream | `#FFF8E9`; panels and paper |
| Mint | `#5CC8A1`; selected states and primary actions with dark ink |
| Coral | `#F5A18F`; Build accent and warm details |
| Gold | `#FFCC68`; coins, reward badges, progress |
| Lilac | `#DCD2F3`; cat care and gentle moments |
| Error ink | `#9C3F3F` on `#FFF0EC`; icon plus concise explanation |
| Display face | Fredoka, weight approximately 600; headings 24–28 phone units |
| Body face | Nunito, weight approximately 650; body 16 phone units |
| Spacing | 4, 8, 12, 16, 24 phone units |
| Panel shape | 20–24-unit corners, small warm shadow; minimal border detail |
| Buttons | 16–20-unit corners, 3-unit lower edge, obvious pressed and focus states |
| Icons | Consistent chunky illustrated objects; 24–32-unit dock icons, 64–88-unit tile art |

No decorative text on in-world signs beyond authored, readable copy. Use paw emblems where tiny signage would become visual noise. Never bake dynamic UI labels or prices into an image. Keep illustrations separate from native controls and text.

Full-scene illustrations in welcome, journey, featured-event, upgrade and activity-scene cards use responsive image areas sized to match the concept composition. Keep their aspect ratio and reduce optional artwork before shrinking controls. The 64–88-unit icon token governs regular object-icon and portrait slots; the live care stage follows its separate dimensions.

## Layout and navigation

All geometry is calculated in phone units then converted to Godot canvas units. Reuse the conversion already documented in `build_metrics.gd`; do not assume a 450-unit canvas equals the physical phone width.

Normal play has a 64-unit top status region, an optional 64-unit objective card, an 80-unit bottom dock and 8-unit gaps, all inside the safe area. Secondary views replace the center content and keep the dock. Detail views use a pinned header, independently scrolling content and a pinned primary-action region where necessary. At large text or short height, reduce optional art before shrinking controls. Build keeps at least half the safe height for the world during placement; its expanded browse tray is temporary and collapses on selection.

The dock uses five equal targets. Build has a coral accent without increasing the dock's obstruction. Selection has a filled background, icon and text change, not color alone.

| Destination | What it contains |
| --- | --- |
| Hotel | Live world, actionable next step, Upgrades, View, settings, away earnings |
| Cats | Collection, profile, interactions, favorite, invitations, playdates |
| Build | Furniture, Rooms, Storage, object actions, room copy/move, wing expansion |
| Life | Gatherings, Garden, Manager, Staff, Scrapbook, Discoveries, Paw Mart, Watch, specialty |
| Map | Hotel journey, destination requirements, visit/unlock, expansion details |

Preserve existing internal route names such as `Pet`, `Events`, `Journal`, `Grounds`, `Manager`, `Kiosk`, `Discoveries`, `Shop`, `Upgrades` and `Rooms`. Map them to their owning dock destination. `Rooms` continues to mean the wing-repair sheet for existing callers; the Build room chooser remains inside `build_panel.gd`.

Returning to Hotel preserves camera target/zoom. The explicit View palette provides Inside/Outside, Hotel view and Fit all. A fresh game and hotel travel frame the active rooms plus reception. World-space labels use a shared collision/priority pass and a maximum of three at once during ordinary play; mandatory objects remain selectable even when their labels are not displayed. Manager mode may show its active job instead of the general objective.

Back behavior: profile → collection, Life detail → Life, expansion detail → Map or its actual caller, Settings → its caller, Build preview → cancel preview, Build without preview → Play. Closing away earnings leaves the pending balance available. Tap-away must not accidentally activate the world behind a dismissed sheet.

## Screen designs

### 01 Hotel

Top: hotel name, level badge, coin balance, income rate and Settings. Center: active rooms with large visible cats. Bottom: one next-step card and dock. Tapping the next-step card opens a concrete existing action: pending reward, running job/repair, pinned discovery, or an available service upgrade in that priority. A large-text setting may put the balance on a separate line without adding another full navigation strip. The integrated large-text header may use112 phone units (normal64) for three readable rows; all world and sheet bounds must use this shared measurement.

Keep the camera bounded by the property. The goal is a closer active-hotel frame, not unrestricted movement or removing Fit all. At the starter state, room beds and at least one resident cat should be recognizable at 360 pixels wide without zooming. Returning from a sheet must not recenter. Labels should not obscure the selected cat or object.

### 02 Build

Top: Build, wallet, Play. Below it: Undo/Redo. Browse: Furniture, Rooms, Storage tabs; Sleep/Play/Decor category chips within Furniture; large thumbnails; an explicit Filters control containing affordability and sort choices. Preserve all 18 catalogue items and owned/free-reuse distinctions.

Selection collapses browsing to a shallow object tray. Show object name, real price, preference chip, preview validity and an optional relevant known cat. The pinned footer reads `Place · <cost>`, `Move · Free`, or `Paste · <cost>` as appropriate. Put Rotate and Cancel in reachable labelled targets. Nudge controls remain accessible in an Adjust subsection; do not silently remove them.

Valid preview: mint outline plus check and “Ready to place.” Invalid: red outline plus blocked icon and the actual validity message; purchase disabled. Not enough coins: exact shortfall. Save failure: keep the preview, show the error beside Retry/Place, keep Play/Cancel reachable. Copy room shows shell + furniture = total and previews the complete footprint. Existing storage, transfer, undo/redo and recovery behaviors remain unchanged.

### 03 Cat care

Miso and other cats get a large live 3D stage, name/trait, persistent favorite control, one friendship meter and one preference note. The six toy buttons are Pet, Brush, Feather, Yarn, Cushion, Box and map to the existing interaction IDs. Direct stroke/hold remains available; button alternatives remain equally capable.

Invite to hotel and Invite a friend open a small secondary view, preserving the known-cat, lounge and friendship requirements. The collection remembers its scroll position when returning. Unknown cats show existing discovery hints or expansion ownership requirements; do not reveal a preference before it is discovered.

### 04 Upgrades

Four service tabs: Suites, Kitchen, Lounge, Desk. One illustrated service hero, current → next level, current → next income, one sentence of benefit, a pinned Upgrade button using the model quote. Show max level, locked, insufficient funds, save failure and purchased states explicitly. Upgrade from a focused room/service preserves the relevant camera. “Build & decorate” enters Build; it is not an additional purchase option in the upgrade transaction.

### 05 Hotel life

Featured active/available gathering at the top. Six illustrated tiles: Garden, Manager, Staff, Scrapbook, Discoveries, Paw Mart. Watch your favorite and Hotel specialty are secondary actions. Preserve all three specialties and the level-3 requirement.

Garden uses illustrated amenity cards for pool, litter nook, playpen and picnic garden with actual price, level and income. Manager shows the coral-vested cat, one current job, available jobs, room tidying and Daisy's hire/working states. Paw Mart stays visibly labelled as an earned-coin shop, including the 30-coin treat picnic and its cooldown. These screens use the same full-page detail layout as gatherings.

### 06 Map and expansions

Scrollable illustrated journey with clearly distinct Meadow, Seaside, Forest and Snowcap postcards and a paw path. Tapping a destination reveals its live details and a pinned primary action. At normal text, the details card is pinned too; at enlarged text it may scroll to preserve safe bounds and full-size controls. Selection must deliberately reveal both Seaside requirements with coherent focus/scroll rather than burying them below the destination list. The map is a navigation surface rather than a dense statistical overview; accessible destination buttons duplicate any decorative path hit areas.

Meadow opens with the base game. Seaside requires Meadow level 10 and 10,000 earned Cat Coins. Forest Lodge and Snowcap Spa are expansion products; the Traveling Cat Club is available in the expansion shop. Display owned/active/locked/paid-expansion states distinctly. Never relabel these implemented products “Coming later.”

Expansion shop: one illustrated product card per existing product, cats/content included, localized store-supplied price, ad-removal note and Restore purchases. Store unavailable, pending, cancelled, failed and owned states remain explicit. No invented prices, urgency timers, surprise upsell on reward collection, or coin-to-cash ambiguity. Purchases & privacy links the existing restore/consent controls.

### 07 Cat collection

Two-column portrait cards showing four known starter cats without an excessive introductory paragraph. The whole card is a button. Met/To meet filters operate on existing `known` data, without introducing rarity. Each card has a large portrait, name, short trait and friendship indication where known. At 150% text the layout can become one column. Preserve all 18 cats, including six expansion cats and their distinct ownership states.

### 08 Gatherings

Use each existing event as an illustrated activity card. Event details show readiness out of 100, duration, one concrete preparation hint and the existing trophy/first-win reward. Host uses `command("event", {"id": ...})`. Running: timer and progress; cooldown: remaining wait and actionable preparation; complete: medal and actual reward. First trophy awards 250 coins according to the existing model, without a second reward-claim transaction. Destination-specific events remain gated by location.

### 09 Scrapbook, discoveries and staff

Scrapbook: paperlike album, actual saved photo or cat portrait, short memory title, date/hotel and Visit cat. Camera action stays obvious. Empty state points to petting or taking a photo. No social posting flow is added.

Discoveries: illustrated combination cards, two or three furniture silhouettes/items, found/clue state, Pin. Hotel stars: a Whisker Guide card with actual inspection requirements and Invite inspector, plus progress state. Do not replace concrete requirements with a generic star progress percentage.

Staff: Pippin, Saffron and Buttons each get a character portrait, role, training 0–3, exact next cost and skill choice. Only the selected member's details need to be expanded at once. Keep Daisy in Manager/housekeeping with a link, since she uses a different existing hire model.

### 10 Welcome

Cat-run hotel vignette, Purrington Hotel title, “Cozy stays. Happy cats.”, Open your hotel and Settings. No wallet before the game starts. Return loading/save failures must remain visible and must not falsely claim progress has been saved.

### 11 Welcome back and feedback

Visible close button, friendly cat-and-coins hero, pending amount, actual away duration and credited duration, eight-hour cap, Collect and Later. Both close and Later dismiss without claiming; reopening shows the same pending reward. Claim is disabled on save error, and a failed save keeps recovery available. Keep collection exactly-once semantics in the existing controller.

For ordinary actions: 80-ms pressed feedback, 160–220-ms sheet transition, short coin/heart reaction only after success. Respect reduced motion; no looping attention pulse or screen-wide celebration. Toasts sit above the dock and never cover the current primary action. Long errors become persistent inline content rather than an expiring toast.

### 12 Settings

Group Music/Sound effects, comfort preferences (animations, touch feedback, evening lighting, seasonal weather), Text size and Purchases & privacy. Add a global `ui_text_scale` with values 1.0/1.25/1.5; legacy saves inherit their existing `build_text_scale`. Retain the independent `build_text_scale` value for old saves and existing tests, and synchronize both through the new global Text size control. Reflect actual saved/error status. Restore purchases and ad-privacy controls remain accessible when applicable.

## Required states and acceptance

| Area | Required states |
| --- | --- |
| Shell | fresh title, normal play, each active tab, nested detail/back, safe area, long text, large balance |
| Camera | starter, full hotel, returned from Cats/Life, inside/outside, explicit Fit all, Build, Watch |
| Build | browse, valid/invalid preview, unaffordable, moving, stored/free-reuse, copy/paste, save failure, undo/redo |
| Cats | known/unknown, discovered/undiscovered preference, favorite, friendship milestone, locked playdate, expansion ownership |
| Life | empty/active/cooldown/completed event, dirty/tidy room, Daisy locked/hired, amenity locked/owned, staff locked/trained/max |
| Map/shop | owned, active, level-locked, coin-locked, expansion unavailable, pending, failed, restored |
| Rewards | none, pending, dismissed, reopened, claimed, capped, failed save |
| Settings | default, 125%, 150%, reduced motion, saved/error, legacy settings migration |

Acceptance requires: no viewport overflow; no clipped essential copy; all actions reachable; all target sizes measured after canvas-to-phone conversion; visible focus; clear selected/disabled/error states; no world clicks through overlays; preserved scroll and focus on state refresh; no unintended camera reset; existing economic and persistence suites still passing. Physical Android testing of safe areas, Back, haptics and pinch remains a release gate.

## Implementation boundaries

Retain `hotel_model.gd`/`hotel_life.gd`/commerce as the source of truth. UI constructs controls and emits existing commands. Extract reusable layout/theme/components and focused view modules as the plan describes; avoid rewriting the simulation or introducing a second route/economy model. New global text-size persistence is the only planned model extension.

Generated boards are review references, not shipping sprite sheets. First implement layout with existing runtime thumbnails and cat scenes; then create/export clean text-free production icons and illustrations that match the approved direction. Prices and accessibility text always remain native UI.
