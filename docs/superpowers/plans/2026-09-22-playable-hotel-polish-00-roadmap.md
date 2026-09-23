# Playable Hotel Polish: Review Roadmap

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the entire playable hotel closer to the warm, detailed welcome art and give new players a compelling, calm first ten minutes.

**Architecture:** Integrate hotel growth, Main Street, and the current welcome/placement-preview work first. Then apply a reusable world-art kit to the live isometric hotel. After the art gate, add a per-profile live reveal and optional discovery cues that link to the merged Map.

**Tech Stack:** Unity 6000.3.24f1, URP, C# 9, uGUI/TextMeshPro, Input System, .NET 9, NUnit.

**Spec:** [playable hotel polish design](../specs/2026-09-22-playable-hotel-polish-design.md).

## Global Constraints

- Unity only; preserve the existing welcome-screen changes and the ongoing hotel-growth work.
- The first playable place is the real four-room Meadow House. No separate showroom or mandatory level picker.
- Exterior and cutaway must both work for expanded, irregular hotels and all four destinations.
- Existing saves bypass the new introduction; save failure cannot advance it.
- The other feature work owns Map layout/unlocks, Main Street scenery/routes, and shell/floor/build rules. This plan integrates with those results after merge.

---

## What the screenshots say

| Reference | Current observation | Planned response |
| --- | --- | --- |
| [Welcome screen](../../art/qa-shots/welcome-ui-390x844.png) | Rich facade, glowing windows, vines, flowers, entrance cats already sell the promise. | Preserve its UI and art. Reveal a matching *live* facade after Play. |
| [Current playable hotel](../../art/qa-shots/concept-meadow/after-desktop.png) | Four detailed rooms, but little facade presence; broad flat lawn, simple roof shapes and scarce light sources. | Detail the continuous shell, gardens, stone and lighting across the whole starter and future footprints. |
| [Portrait gameplay](../../unity-migration/evidence/unity-first/01-hotel-390x844.png) | Cats and furniture are legible; the room cluster fills most of the phone. | Retain readable cutaway and interaction; use exterior as a brief first reveal and available View mode. |
| [Map](../../unity-migration/evidence/unity-first/07-map.png) | The destinations exist, but the screenshot predates ongoing Map work. | Link the introduction to the final merged Map and verify its live unlock status; leave its layout to the Map-owning task. |

## Concurrent-work check (September 22)

The active tasks **Complete hotel growth handoff** and **Brainstorm game improvements** are implementing hotel growth and Main Street. Main Street is isolated in `codex/main-street`; hotel growth is updating the shared checkout. The smaller **Add voxel placement preview** task is also editing shared `VoxelWorld` code, and the welcome-screen work has uncommitted `HotelUI.cs` and art changes.

At this review, the committed hotel-growth branch and Main Street branch already both changed **nine files** since their common base: `Program.cs`, `HotelModel.cs`, `HotelState.cs`, `StrictSaveJson.cs`, `HotelApp.cs`, `HotelParityUI.cs`, `HotelUI.cs`, `VoxelWorld.cs`, and `VoxelWorldInput.cs`. These are overlap risks, not proof of a textual merge conflict; they require an integration review before this plan starts.

| Overlap | Other work | This plan's resolution |
| --- | --- | --- |
| `VoxelWorld.cs`, `VoxelWorldShell.cs`, `VoxelWorldRooms.cs`, camera/floor visibility | Growth adds shell, floors, stairs, wall tool, wardrobe; Main Street adds town camera and shop modes. | Start facade/camera work after both land. Build on the final floor and town mode APIs; check exterior and cutaway in every mode. |
| `HotelState.cs`, `StrictSaveJson.cs`, `HotelModel.cs` | Growth adds floor/wardrobe save fields; Main Street adds manager, route, quest, and event fields. | Add the optional introduction field after their save changes merge. Run old-save and failed-save tests against the combined schema. |
| `HotelUI.cs`, `HotelParityUI.cs`, `HotelApp.cs` | Growth adds build/floor/wardrobe UI; Main Street adds Explore, stores, and quest UI; welcome changes the Play callback. | Keep most new UI in `HotelJourneyUI.cs`; add only small hooks in shared files after the others settle. |
| Map layout and unlock controls | Ongoing Map work may replace the current `ParityMapPanel`. | Remove the planned Map redesign from this pass. The introduction links to and tests the merged Map; its owner keeps layout and unlock logic. |
| Hotel gate, street, shops, decoration | Main Street owns the route and storefront scenery. | Garden art stays on hotel-owned land, excludes the gate corridor, and never replaces town assets. |
| `VoxelWorldPreview.cs` and world input | Placement-preview work is active in the same checkout. | Avoid preview/input edits in the art pass; retest placement after facade additions. |

This is a sequencing conflict, not a reason to abandon the visual direction. Parallel edits to the shared files above would create avoidable merge and behavior conflicts.

### Independent work completed

Commit `9e94310` on isolated branch `codex/hotel-polish-art` adds cached emissive window materials and a day/evening intensity control to `GodotGeometry`, plus an EditMode test. All 77 EditMode tests passed in that checkout. This is the material foundation for Gate A; it does not yet place glowing windows in the hotel or change the live scene. Connect it to the final facade and `SetEvening` after the growth and Main Street work settles, then review day/evening captures before merging the visible art pass.

## Delivery sequence

| Gate | Plan/tasks | Independently reviewable result |
| --- | --- | --- |
| Dependency | [Full hotel growth roadmap](2026-09-22-hotel-growth-00-roadmap.md), [Main Street](2026-09-22-main-street.md), welcome and placement-preview changes | Integrated shell/floors/wardrobe/build tools, town gate and shops, stable opening callback. |
| A | [World art Tasks 1–2](2026-09-22-playable-hotel-polish-01-world-art.md) | Warm lamps/windows and a reusable roof/facade covering the entire starter. |
| B | [World art Tasks 3–4](2026-09-22-playable-hotel-polish-01-world-art.md) | Layered lot, destination color identities, usable camera composition, before/after captures. |
| C | [First run Tasks 1–2](2026-09-22-playable-hotel-polish-02-first-run.md) | Per-profile intro state and live exterior → cutaway reveal. |
| D | [First run Tasks 3–4](2026-09-22-playable-hotel-polish-02-first-run.md) | Optional prompts for cats/building/Main Street/destinations and a verified handoff to the merged Map. |

The visual gate precedes the reveal: introducing players to a flat world immediately after showing the new welcome art would weaken the opening. The domain-only introduction state can be built earlier if useful, but it should not ship by itself. Before starting Task A, compare the merged API and file ownership against these plans once more; the other tasks are still active.

## Suggested review checkpoints

1. **After Gate A:** Compare the live exterior with the welcome reference. Does it feel like the same hotel at isometric distance? Check full starter and an L-shaped expansion.
2. **After Gate B:** Review day/evening, exterior/cutaway, 360×640 and desktop captures. Approve readability before adding prompts.
3. **After Gate C:** Watch the fresh opening once at normal and reduced motion speed. It should take one action to enter play.
4. **After Gate D:** Try a ten-minute fresh profile and an established save. Check whether Cats, Build, Life, Main Street, and Map are discoverable without forced detours.

## Approximate effort

For one developer with the current procedural art approach: about **1–2 weeks for a convincing full-hotel art pass**, then **about 1 week for the first-run flow and Map handoff**, plus mobile performance/device review. Custom 3D assets of the reference's fidelity can expand the art pass substantially. This estimate starts **after** hotel growth and Main Street integrate; it is a planning range, not a delivery promise.

## Review decision

The main choice for this review is the opening sequence: existing illustrated welcome → short live exterior reveal → playable cutaway → optional Cats/Build/Map suggestions. The Map remains the place to choose destinations. A new level or first-screen level picker is outside this pass because Meadow already has enough content to introduce the game and the other destinations already have progression gates.
