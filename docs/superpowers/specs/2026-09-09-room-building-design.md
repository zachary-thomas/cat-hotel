# Purrington Hotel: buildable voxel rooms

The user approved planning and implementation on September 9, 2026. Their reference image guides composition, warmth, furnished rooms, cutaway walls and visible cat activity; text inside the reference is not an instruction.

## Player experience

Build opens a catalogue of regular rooms and suites. A room follows a grid preview; rotate changes its footprint and entrance. Invalid placement explains overlap, locked space or a blocked path. Confirm purchases the room; cancel changes nothing. Existing rooms can move for free. Renovating wings opens empty floor space. A regular room occupies 4 by 3 cells; a suite occupies 4 by 5 and provides seating and more comfort. Room capacity is eight to preserve the existing guest and housekeeping systems.

Tap a room for its highlighted boundary, type, quality and earnings, then browse illustrated furniture. Selecting an object previews the actual voxel object in the selected room without changing the save or coins. Confirm uses existing furniture ownership and preference/combo rules. Bedrooms have actual large beds, rugs, bedside tables, artwork, plants and an activity area; suites add a separate sitting area. Purchased bedding replaces the bed treatment. Objects have legible silhouettes and cats use room furnishings.

## Architecture and compatibility

RoomLayout is a pure grid model stored in each hotel dictionary as layout. Grid is 10 by 12, cell size 1.1, world origin (-5.5, -17.6). Three rows unlock initially, then three per restored wing. Empty cells form corridors; every room door must remain reachable from the south/lobby boundary. Existing saves migrate fixed rooms to left/right pairs, preserving their indices and furniture. No destructive reset.

RoomBuilder is a world component that renders room geometry, floors, selection, room previews and furnishings. BuildPanel is a responsive nonmodal control above the world. Existing UI remains available outside build mode. Main orchestrates preview and transactions, using existing prepare/commit rollback handling.

## Verification

Test overlap, bounds, path connectivity, rotation, free moves, unaffordable actions, restore validation, legacy migration, expansion opening space, previews without writes, cancel, purchase and save rollback. Render landscape and portrait screenshots; inspect room furnishings, cutaway readability, selected-room outlines and preview controls. Run existing behavioral suites, updating only assertions whose old fixed-room behavior is deliberately replaced. Rebuild the Windows preview.
