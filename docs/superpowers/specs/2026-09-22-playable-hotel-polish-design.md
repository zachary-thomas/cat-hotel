# Purrington Hotel: playable first impression and world polish

September 22, 2026 · Unity only · design for review

## Goal

Make the first playable Meadow House feel as inviting as `Assets/Resources/Art/welcome-exterior.png`, while retaining an orthographic isometric camera, visible cats, readable rooms, and the player's ability to reshape the hotel. The work covers the complete four-room starter, its garden and nearby street, and reusable parts for grown hotels and the other destinations. A new player should see what the game can become without facing a wall of choices.

## References and present state

- Visual target: the user's warm exterior image, now used in the welcome screen, plus `docs/concept-art/02-hotel-overview.png` and `06-cat-world-revision.png`.
- Current playable baseline: `docs/art/qa-shots/concept-meadow/after-desktop.png`, `docs/unity-migration/evidence/unity-first/01-hotel-390x844.png`, and the destination capture `07-map.png`.
- Current opening: `docs/art/qa-shots/welcome-ui-390x844.png`. Its live UI and new art are uncommitted work in progress; preserve them. The visual drop happens after **Open your hotel**.
- The starter already has four rooms, 54 placed objects, four known cats, and 1,000 coins. This is enough for a living showcase without granting a second demonstration profile.
- The full `2026-09-22-hotel-growth` sequence owns the continuous shell, floors, wall tool, wardrobe, and their camera/build UI. The separate Main Street plan owns the hotel gate, nearby street, shops, and town travel. This design adds finish after those features are integrated; it does not replace their rules or scenery.

## Experience decision

The new player enters a **playable showcase hotel**, as requested. After the existing welcome screen, the camera presents the live four-room Meadow House in exterior mode for a short, skippable reveal. One clear action, **Look inside**, changes to the playable cutaway. There is no mandatory cinematic, separate save, artificial showroom, or level picker before play.

The opening then offers one optional suggestion at a time: meet a cat, add a small detail, and peek at future destinations. Normal Hotel, Cats, Build, Life, and Map navigation remains available from the start. A persistent **Your journey** entry holds the wider set of possibilities for curious players; completing or dismissing the short introduction removes its prompts. Existing saves start with the introduction completed. Reset creates a fresh introduction.

The Map remains the secondary destination picker. Its layout and unlock presentation are being changed in another task, so this polish pass links to the merged Map rather than rebuilding its cards. Meadow remains the only required first playable location. The introduction never grants a destination or changes travel prices. Any preview unlocks in the merged Map must remain clearly labeled as previews and must not imply that unfinished destinations are complete.

## World art direction

1. **Warmth from sources, not a global tint.** Use cream plaster, honey timber, moss roofs, warm stone, and varied foliage. Windows, lanterns, and reception lamps emit a restrained amber glow; daylight keeps readable sun/shade contrast, while evening cools the ambient scene around those warm points. Keep cat fur and UI text true to their own colors.
2. **A complete hotel silhouette.** The continuous shell gets roof planes with ridges, eaves, gables, chimneys, corner trim, framed windows, an arched entrance, a modest cat crest, and a few flower boxes. These are reusable modules attached to shell edges and openings, not a fixed portrait facade. Every exterior shell island has a deliberate silhouette; all four starter rooms read as one hotel.
3. **Layered garden and hotel lot.** Planters, climbing vines, clustered flowers, stone variation, low fences, benches, and lanterns frame the entrance and paths inside the owned hotel lot. Decoration is deterministic from shell geometry and destination theme, does not block cat navigation, the Main Street gate/route, or player picking, and scales down at far zoom and on mobile. The Main Street task owns the square, shops, and pedestrian street scenery.
4. **Readable cutaway.** Exterior mode shows the full roof and front elevation. Interior mode hides roof sections above the active floor and lowers camera-facing walls, while keeping trim, warm windows, exterior plants, and grounded shadows where they do not obscure cats or furniture. A visible Hotel view control switches modes; Settings remains a secondary route.
5. **Isometric composition.** Keep `VoxelWorld`'s orthographic 36.59° / 315° camera. Frame the hotel and its garden closer on phones without clipping future expansions. Use depth and soft distance treatment in scenery, not a heavy blur over playable rooms. Any image-generation output is a reference or menu illustration, not a flat layer pasted into the interactive world.

## Opening flow and pacing

| Moment | Visible action | What the player learns |
| --- | --- | --- |
| Welcome | **Open your hotel** and Settings | The existing illustration promises the mood. |
| Live reveal | **Look inside** plus **Skip**; the actual starter shell and cats remain visible | This illustrated place is the playable place. |
| Suggestion 1 | **Meet a cat** opens Cats; any deliberate care action completes it | Cats are characters, not decoration. |
| Suggestion 2 | **Add a detail** opens Build on a small affordable category; any successful item placement completes it | The hotel is yours to change. |
| Suggestion 3 | **See where you can go** opens Map; closing Map completes it | The world has destinations and clear unlock goals. |
| Afterward | Compact hotel status; **Your journey** remains in Life or Map | Play freely; more systems are discoverable when wanted. |

The player can skip every suggestion and use every existing tab. Prompt completion is stored per save profile and advances only after the relevant successful action, never after a failed purchase or failed save. If saving a completed prompt fails after the gameplay action succeeded, retain the pending prompt transition in memory and let Retry finish it without requiring the action again. Reduced motion changes the exterior reveal and panel transitions to immediate state changes. Returning players and automated QA profiles do not replay the reveal. Avoid a timed demand, forced purchase, flashing highlight, or more than one instructional card at once.

## Technical boundaries

- **Art kit:** add focused Unity presentation files for facade modules, garden dressing, and light/material roles. Shell edge data is the source of wall, window, door, and roof placement. Decorations have no gameplay colliders unless the item is already an interactive object. Rebuilds are deterministic, batched where possible, and cleaned up with the current world hierarchy.
- **Camera and UI:** `VoxelWorld` exposes an exterior reveal framing action and retains user pan/zoom after the reveal. A small `HotelUI` partial handles prompts and the Hotel view control; it does not duplicate the existing welcome implementation.
- **First-run state:** add one optional version-3 save field with a completed default for legacy saves; fresh starter creation explicitly starts at reveal. State transitions go through `HotelModel` save/rollback, with the same profile and Retry behavior as the rest of the game. Do not put profile-specific progress in global PlayerPrefs.
- **Destination handoff:** the first-run suggestion opens the final merged Map. Its owning feature retains Map layout, art, and unlock controls; this plan tests the handoff and live status copy without editing `ParityMapPanel`.

## Acceptance

- The fresh opening shows a full live four-room hotel, cats, garden, entrance, and warm lights. The first play camera still supports pan, zoom, room selection, cat selection, and building.
- The appearance holds for a grown irregular shell, exterior and cutaway, day and evening, and Meadow, Seaside, Forest, and Snowcap. Growth and roof modules do not leave floating trim or cover the active floor.
- At 360×640, 390×844, 430×932, and 1280×800, controls stay inside safe areas, active cats and objects remain legible, text works at 100%, 125%, and 150%, and the world retains at least the existing 35% viewport rule when a sheet is open.
- Fresh, resumed, existing, reset, reduced-motion, and failed-save profiles behave as described. No introduction step charges coins or changes hotel capacity/income.
- Unity EditMode, the .NET domain harness, Windows build and pointer acceptance pass. Capture before/after images from the built player. Measure desktop and physical mobile frame time before calling mobile performance complete.

## Sequence and scope

Land the remaining hotel-growth work, Main Street work, and the current welcome/placement-preview edits first. Recheck their merged interfaces. Then execute the [world-art plan](../plans/2026-09-22-playable-hotel-polish-01-world-art.md), followed by the [first-run plan](../plans/2026-09-22-playable-hotel-polish-02-first-run.md). The art kit may later be reused by Main Street, but this work does not redesign its shops or routes. A new destination/level is deferred because the existing four destinations already provide a progression surface; the first impression is better served by making Meadow itself feel like the welcome image.
