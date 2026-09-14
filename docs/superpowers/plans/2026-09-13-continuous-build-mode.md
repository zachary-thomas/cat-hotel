# Continuous Build mode — September 13 revision

The user requested immediate, intuitive building: decorate any room, include the lobby and shared spaces, remove Apply/discard/exit confirmation, provide Undo, and copy complete rooms when affordable. This revision supersedes the September 12 checkout flow. Building and decorating remain the priority; it does not introduce draining cat needs.

## Decisions and delivered flow

Choose furniture first, then tap its destination. The target space follows the pointer across guest rooms and shared floor. Existing objects can be selected directly in the world and moved between spaces with the same UID. Changing spaces preserves the camera rather than snapping it back to a selected bedroom.

One **Place** action purchases and saves the object at the price on its button. **Play** exits immediately. Android Back or Escape cancels an unfinished preview first, otherwise exits. An unfinished ghost is free. There is no new Apply, purchase-review, exit, or discard dialog. Failed writes restore the wallet and ownership together, retain the positioned preview, and show the error in Build.

Undo/Redo covers the last 20 saved building actions, including purchases, furniture transfers, storage, room moves, and room copies. Undo refunds only that action's cost; neither direction restores an old wallet or erases intervening income, visits, or repairs. Redo checks current funds. New actions clear Redo. History is available during the running game and is not persisted across restarts. If another system changes the edited ownership or layout, a stale history step is rejected rather than overwriting it.

Copy room captures its type and exact furniture layout. A movable, translucent blueprint shows shell and furniture before purchase. Its price is the room shell plus every paid furniture copy; free-reuse licenses apply. Paste charges once and saves shell, instances, and wallet together. Copies have distinct UIDs, leave the source untouched, do not consume storage, and cannot mint extra included fixtures. The clipboard lasts for the running game. Room caps, restored floor, geometry, and reachability still apply.

Shared furniture uses the existing catalogue, ownership, rotation, storage, and stat rules. Its Comfort/Entertainment/Atmosphere score provides one quality-income bonus per hotel. Bedroom combinations and guest fit stay associated with guest rooms. The existing lounge/service assemblies remain fixed scenery; floor alongside them is editable. Shared validation protects authored walls, fixed fixtures including future service extensions, entrance routes, and public actor paths. New room placement also checks shared furniture, so the preview cannot advertise a blocked placement as valid.


Mobile placement feedback refinement: furniture uses large vector checkmark and X actions, with the exact coin cost beside the checkmark. The checkmark saves immediately and disables for invalid placements; X cancels only the preview. A valid preview retains the furniture’s original colors over a filled green footprint. Invalid previews and footprints turn red. Preview feedback stays visible through foreground room geometry; committed objects and shared mesh resources are unchanged.

The refinement passed the furniture-preview, Build-mode, continuous-flow, room-building, shared-layout, and blueprint suites. Rendered checks inspected valid/invalid states at 360×640 with 150% text, along with the existing multi-size layout checks. Icon actions retain accessibility names. The preview suite verifies color restoration, full footprint fill and rotation, visibility through foreground walls, and isolation from committed materials.

## Implementation boundaries

| Area | Implementation |
| --- | --- |
| Continuous UI | `build_panel.gd`: furniture-first catalogue, automatic target space, Play, explicit priced Place, room Copy/Paste, fixed actions and 100/125/150% text |
| Save boundary | Main settles income, executes one operation, saves, then records successful history; a failed Undo/Redo save also restores its history checkpoint |
| Ownership | `furniture_inventory.gd`: atomic cross-space transfer; shared area is hotel-owned room `-2`, storage remains `-1/-1`; old version-3 saves need no new required fields |
| History | `build_history.gd`: semantic state comparison, bounded undo/redo, inverse cost deltas, monotonically increasing instance counters and room revisions |
| Shared floor | `shared_layout.gd`, interior transform adapter, shared renderer and hit testing; 0.55-unit cells, cap 48 shared instances |
| Room copies | `room_blueprint.gd`: immutable captured layout, authoritative quote and atomic placement; `room_builder.gd` renders exact furniture ghosts |
| Compatibility | Old model migration stays intact. Previously saved single-room drafts remain recoverable through an optional legacy restore action under Rooms; new edits do not create such drafts |

Every committed bedroom still needs a reachable bed. This makes immediate saving safe while rearranging; place a replacement bed before storing the last one. Outer room resizing, custom walls, outdoor furnishing, and a saved blueprint library remain outside this revision.

## Acceptance and verification

- [x] Place saves once; changing rooms and Play need no checkout.
- [x] Choose an item before any room; place on lobby floor; transfer existing furniture directly between rooms; store and reuse a shared object.
- [x] Undo/Redo restores the intended object or complete copied room and preserves earned coins; funds, stale state, save failures, and UID reuse are covered.
- [x] Copy previews exact furniture and shell; total includes paid copies; failed or unaffordable copies leave source, wallet, and ownership unchanged.
- [x] Shared floor rejects furniture on rooms, locked wings, walls, fixed service scenery, circulation paths, and outside the front boundary; room moves and blueprints validate existing shared furniture.
- [x] Mobile rendering checks cover 360×640, 360×800, 390×844, 430×932, 768×1024, and 1280×800 at 150% text. Play stays on one line; placement validity and fixed actions remain visible; placement retains at least half the phone height for the world.

Final verification on September 13: all **27 behavioral suites** passed through `tools/test.ps1`. The rendered Build-mode and continuous-flow suites passed at 360×640, including the multi-size 150% checks. Placement, catalogue, large-wallet, and furnished-blueprint screenshots were inspected. Cross-hotel Undo replans only affected hotels' housekeeping; shared manager routes avoid complete furniture footprints with body clearance. The Windows preview and ZIP were rebuilt and the exported pack passed its startup smoke check. The environment continues to emit its pre-existing Windows root-certificate-store warning.

Automated desktop rendering does not establish real-device frame time, thermals, touch feel, or accessibility-service behavior. Physical Android testing and the existing signed mobile release setup remain release checks.
