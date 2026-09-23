# Playable Hotel World Art Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the full playable Meadow hotel and surrounding lot approach the warmth and detail of its welcome illustration, with reusable isometric art for expanded hotels and all destinations.

**Architecture:** Keep the procedural voxel world and orthographic camera. Add emission and scene grading through existing URP materials, then a facade kit driven by shell edges and deterministic garden dressing driven by the lot footprint. Keep exterior and cutaway rendering as separate views of the same live hotel.

**Tech Stack:** Unity 6000.3.24f1, URP, C# 9, Newtonsoft.Json, NUnit EditMode, Windows QA captures.

**Spec:** [playable hotel polish design](../specs/2026-09-22-playable-hotel-polish-design.md). **Dependency:** integrate the full [hotel growth roadmap](2026-09-22-hotel-growth-00-roadmap.md), [Main Street plan](2026-09-22-main-street.md), and current welcome/placement-preview work before this plan edits shared presentation files. Recheck the final `ShellDraw`, floor visibility, town gate, and camera APIs at that point.

## Global Constraints

- Unity only: `unity/PurringtonHotel`; do not edit the legacy Godot game or exported `GodotGeometry.json`.
- Retain the orthographic 36.59° / 315° gameplay camera and player pan/zoom.
- The kit must cover all four starter rooms and arbitrary shell footprints; it cannot be a single fixed facade.
- Decorative pieces cannot block pathfinding, taps, construction, or cats; honor reduced motion.
- Main Street owns the square, shops, and pedestrian route. Garden dressing stays on hotel-owned land and leaves the town gate approach clear.
- Capture 360×640, 390×844, 430×932, and 1280×800; measure physical mobile performance before declaring mobile complete.

---

## File map and interfaces

| File | Responsibility |
| --- | --- |
| `Runtime/Presentation/GodotGeometry.cs` | Cache lit and emissive URP materials; expose `WindowGlow(bool evening)`. |
| `Runtime/Presentation/ConceptTheme.cs` | Destination-specific material roles, preserving the existing authored-color remap. |
| `Runtime/Presentation/VoxelWorldFacade.cs` (new partial) | Build roof, gable, eave, entrance, crest, window frame, and flower-box modules from shell edge runs. `BuildFacade(Transform root, int destination)` is the sole entry point. |
| `Runtime/Presentation/VoxelWorldGarden.cs` (new partial) | Build decorative planting/path-edge clusters inside the owned hotel lot from a deterministic seed and clear-space rules. `BuildGarden(Transform root, int destination)` is the sole entry point. |
| `Runtime/Presentation/VoxelWorld.cs`, `VoxelWorldShell.cs`, `VoxelWorldRooms.cs` | Call and show the modules, change their visibility with cutaway/exterior, and set day/evening light. |
| `Editor/ProjectSetup.cs` | Configure restrained URP bloom/tonemapping and mobile renderer quality. |
| `Tests/EditMode/FacadeArtTests.cs` (new) | Assert facade placement and collision-free decorative hierarchy for representative shells. |

Use Unity `.meta` files for every new Unity script. Keep these helpers focused; do not expand the already large `HotelUI.cs` or exported geometry JSON.

### Task 1: Warm material and lighting roles

**Files:** Modify `GodotGeometry.cs`, `ConceptTheme.cs`, `VoxelWorld.cs`, `Editor/ProjectSetup.cs`; create `Tests/EditMode/WorldLightTests.cs` and its `.meta`.

**Interfaces:** Produces `GodotGeometry.WindowGlow(bool evening)`; `Material("glow|#HEX")` returns an emissive URP material. Existing `Material("#HEX")` behavior stays unchanged.

- [ ] **Step 1: Write an EditMode test** that creates `GodotGeometry`, checks ordinary material color, checks `Material("glow|#FFD590")` has `_EMISSION`, calls `WindowGlow(true/false)`, and verifies emission intensity changes while the base color does not. Dispose the geometry.
- [ ] **Step 2: Run** `.\tools\unity.ps1 Test`; expect the new test to fail because the glow material is unsupported.
- [ ] **Step 3: Add one material role branch** in `GodotGeometry.Material` using a cache key that includes `glow|`. Set `_EmissionColor`, enable `_EMISSION`, and keep a list of window materials so `WindowGlow` updates their emission without creating a material every frame. Add `WindowGlow` near `Material`:

  ```csharp
  public void WindowGlow(bool evening) {
      foreach(var m in windowMaterials)
          m.SetColor("_EmissionColor", m.color * (evening ? 2.4f : .65f));
  }
  ```

  Use URP Lit for the material, `Color.linear` for HDR emission, and keep the water material branch independent.
- [ ] **Step 4: Call** `geometry.WindowGlow(value)` in `VoxelWorld.SetEvening`. Keep the existing warm sun/cream fill; in `ProjectSetup.ConfigureRendering`, add subtle `Bloom` with a high threshold and low scatter, and check the mobile renderer profile does not use desktop-only SSAO. Use the current `ParityGrading.asset` rather than creating a second global volume.
- [ ] **Step 5: Run** Unity EditMode tests, Windows build, and capture the same hotel at day/evening. Accept when light sources glow without blowing out cream walls or obscuring cat faces. Commit only this task's files.

### Task 2: Reusable hotel facade and roof kit

**Files:** Create `VoxelWorldFacade.cs` and `.meta`, `Tests/EditMode/FacadeArtTests.cs` and `.meta`; modify `VoxelWorldShell.cs`, `VoxelWorldRooms.cs`, `VoxelWorld.cs`.

**Interfaces:** Consumes `ShellDraw.Runs(floor)` from hotel-growth plan 03. Produces `BuildFacade(Transform root,int destination)` and view groups named `FacadeRoof`, `FacadeTrim`, `FacadeGlow`; `SetCutaway` toggles roof only, retaining safe edge detail. No gameplay state changes.

- [ ] **Step 1: Write a test** with a 4×3 rectangular shell, an L-shaped shell, and a two-floor shell. Count exterior wall edges and assert roof/trim geometry stays within their footprint plus the planned overhang; assert no collider is added to decorative descendants; assert an entrance module is created only at an exterior door and windows receive frames. Check the starter has at least one accessible exterior door and that the active floor is unobscured.
- [ ] **Step 2: Run** `.\tools\unity.ps1 Test`; expect missing `BuildFacade` or missing named view groups.
- [ ] **Step 3: Build modular geometry** from edge runs. Roof pieces attach to contiguous exterior shell segments with a small overhang; exposed corners receive posts; doors receive an arch and awning; windows receive a sill, two frame colors, and optional box. Use this placement rule in the new partial:

  ```csharp
  void BuildFacade(Transform root,int destination) {
      foreach(var floor in model.Hotel().floors) {
          foreach(var run in ShellDraw.Runs(floor)) {
              if(run.inward==0) continue;
              BuildExteriorRun(root,floor.level,run,destination);
          }
          if(floor.level!=2) BuildRoofIslands(root,floor,destination);
      }
  }
  ```

  Reuse `Box`, `Foliage`, `Bake`, and `ConceptTheme` colors. `WallRun` has `axis`, `x`, `z`, `length`, `inward`, and `kind` in plan 03. Pass `glow|#FFD590` into `GodotGeometry.Material` for exterior window glass and lantern cores.
- [ ] **Step 4: Replace the simple per-room roof only for interior rooms.** Pavilion rooms keep their independent roof. `VoxelWorldShell` calls `BuildFacade` after wall runs. `SetCutaway` disables `FacadeRoof`, keeps low edge trim and planter detail, and ensures active-floor cats stay unobscured. Do not add decorative colliders.
- [ ] **Step 5: Inspect** built-player screenshots of starter exterior and cutaway, a grown rectangle, and an L-shaped hotel at portrait and desktop sizes. Check no roof floats over removed cells or blocks an active floor. Run EditMode tests and commit this task.

### Task 3: Dress the complete lot and destination edges

**Files:** Create `VoxelWorldGarden.cs` and `.meta`; modify `VoxelWorld.cs`, `ConceptTheme.cs`, and `Tests/EditMode/FacadeArtTests.cs`.

**Interfaces:** Consumes the current hotel's shell footprint, paths, owned plots, and destination index; produces `BuildGarden(Transform root,int destination)`. Decorations are visual only.

- [ ] **Step 1: Write tests** for two saved footprints: starter Meadow and an enlarged lot. The garden builder must be deterministic, avoid cells occupied by rooms, objects, hotel entrance approaches, Main Street's hotel-gate route, and constructed paths, and add no colliders. For the same state, a second build returns the same decoration anchors.
- [ ] **Step 2: Run** Unity EditMode tests and confirm the determinism/clearance test fails.
- [ ] **Step 3: Add seeded clusters** around free hotel-lot boundaries and authored entry points: low shrubs, cream/pink flowers, vines on safe facade edges, pots, paving shade variants, two entrance lanterns, and a small cat crest. Enumerate owned lot cells in sorted `(x,z)` order; reject a candidate if it overlaps a shell cell, object footprint, path cell, the two-cell approach to an exterior door, or a two-cell corridor around the merged Main Street hotel-gate route. Select one of four small clusters using a fixed integer hash of `(destination,x,z)`, with at most one cluster per three free cells and a hard cap of 120 clusters per destination. Use no `UnityEngine.Random` global state. Keep clusters below the camera-facing cutaway walls.
- [ ] **Step 4: Give Seaside, Forest, and Snowcap distinct role palettes** through `ConceptTheme` (stone/sand, timber/evergreen, pale stone/snow) while keeping shared geometry. Do not cover playable surfaces with decorative overlays. Batch static meshes and use lower-detail clusters at far zoom/mobile quality.
- [ ] **Step 5: Capture** all four destinations in exterior and cutaway, both day and evening, using an isolated God-mode QA profile for unavailable destinations; review starter entrance, garden edges, paths, town gate clearance, shop approach, and cat visibility. Run EditMode tests and commit.

### Task 4: Game-view composition and performance gate

**Files:** Modify `VoxelWorld.cs`, `VoxelWorldShell.cs`, `PreviewVerification.cs`; add captures and a short report under `docs/art/qa-shots/playable-hotel-polish/`.

**Interfaces:** Produces `FrameHotelReveal()` for the first-run plan. Existing `FitHotel`, manual pan, and zoom remain intact.

- [ ] **Step 1: Add a camera composition test** in the current acceptance harness that calls `FrameHotelReveal()`, checks an orthographic camera and visible bounds for the whole starter shell and entrance, then pans/zooms to confirm control is returned to the player. Include an expanded footprint regression.
- [ ] **Step 2: Run** the input/visual acceptance harness; expect the new framing assertion to fail before implementation.
- [ ] **Step 3: Implement** `FrameHotelReveal()` using the existing bounds fit plus a garden/entrance margin, not a hard-coded camera transform. Preserve the last user focus when switching exterior/cutaway after the reveal. Keep the 36.59°/315° camera angle.
- [ ] **Step 4: Build Windows and run QA** at 360×640, 390×844, 430×932, and 1280×800, 100/125/150% text; capture day/evening and exterior/cutaway. Record before/after images, visible cats, roof clipping, click targets, draw calls, and frame time. Run `.\tools\unity.ps1 Test`, `.\tools\unity.ps1 Windows`, `.\tools\unity.ps1 QA`, and `dotnet run --project tests/unity-domain`.
- [ ] **Step 5: Fix any visual obstruction or regression discovered in Step 4**, rerun only the affected capture/test, write the results in the report, and commit. Physical Android/iOS measurement remains a release gate; desktop timing is not labeled mobile performance.

## Review gate

Compare the new playable captures side by side with `docs/art/qa-shots/welcome-ui-390x844.png` and the user's source image. Review the entire four-room hotel and an expanded hotel, not merely the front entrance. Proceed to the first-run plan only when the live hotel sustains that visual promise and remains readable in cutaway.
