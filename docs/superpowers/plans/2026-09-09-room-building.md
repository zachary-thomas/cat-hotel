# Buildable Voxel Rooms Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development for the independent layout model and tests while the main worker implements and integrates rendering and controls. Track completion here.

**Goal:** Let players place regular rooms and suites and preview visible furnishing upgrades in a lively isometric hotel.

**Architecture:** A pure RoomLayout module owns grid rules and migration. Separate RoomBuilder and BuildPanel components own visuals and interaction; Main applies paid actions through existing save transactions.

**Tech Stack:** Godot 4.7.2, GDScript, existing procedural voxel geometry.

**Spec:** docs/superpowers/specs/2026-09-09-room-building-design.md

## Global constraints

- Preserve saved cats, furniture, coins and entitlement data.
- Use earned coins only; previews and rearranging owned objects are free.
- Preserve touch support and reduced motion; keep controls clear of the visible preview.
- All room entrances must connect to the lobby through empty grid cells.

## Task 1: Saved room layout and economy

Files: scripts/core/room_layout.gd, hotel_model.gd; tests/test_layout.gd.

- [x] Add static entries(model, hotel), dimensions(kind, rotation), door_cell(room), center(room), validate(model, hotel, candidate, moving=-1), perform(model, action, payload), migrate(hotel), valid_saved(layout, wings), route(model, hotel, room).
- [x] Use dictionaries with kind, x, y, rotation. Room array indices remain furniture indices. Regular rooms cost 450; suites cost 1200. Purchased rooms add income and hotel purchase progression; moving is free.
- [x] Test rejection leaves wallet/layout untouched, rotated room overlap, blocked entrances, locked rows, successful placement/move, and JSON save round trips.
- [x] Integrate migration before layout use and validated restoration. Expansion opens floor without creating rooms. Keep legacy income contribution plus new room income.

## Task 2: Room rendering and motion

Files: scripts/world/room_builder.gd, hotel_world.gd, hotel_shell.gd.

- [x] Replace old fixed bedroom wing visuals with buildable floor and furnished room modules, retaining neighborhood and public services.
- [x] Build distinct regular/suite geometry, furniture silhouettes, wall pictures, plants, lanterns and cutaway doorways; show mint selection borders and translucent placement.
- [x] Route cats through reachable entrances, show furniture use, animate purchased rooms with a short construction reveal; respect reduced motion.

## Task 3: Controls and transactions

Files: scripts/ui/build_panel.gd, hotel_ui.gd, scripts/main.gd.

- [x] Add Build entry and room hit testing. Expose room catalogue, placement rotate/confirm/cancel, free move and furnishings through a responsive world-visible panel.
- [x] Preview objects using real room models, with explicit price, preference and ownership before confirmation. Cancel has no save or economy effects.
- [x] Connect layout actions to prepare/commit and rebuild; failed writes restore prior state. Existing furniture action remains the purchase authority.

## Task 4: Verification and deliverables

- [x] Add rendered build flow tests, including previews/cancel and successful purchases, moves and save/reload. Capture landscape and portrait.
- [x] Run tools/test.ps1 and inspect failures before revising obsolete fixed-room assertions.
- [x] Inspect screenshots, correct layout/visual issues and run affected checks again.
- [x] Update README and package instructions; run tools/package.ps1 and verify packaged startup.

## Execution notes

- Ruling: execute directly in the existing codex/godot-idle-prototype checkout (unborn branch), because there is no commit from which to create a worktree. No global Git settings changed.
- Ruling: the user explicitly approved planning and implementation; no additional design approval gate is needed.

## Verification and review results

- All twelve behavioral suites passed with zero failures after final gameplay changes.
- Rendered building flow passed at 360 × 800 and 1280 × 800. Screenshots were visually inspected and retained in docs/room-building-screenshots.
- Windows preview and ZIP rebuilt successfully. Pack smoke exercised purchased room placement and furniture preview/confirm, in addition to doors, repairs, housekeeping, audio and petting.
- Independent review findings addressed: obsolete walls/shelf cleared from entrances; Settings and offline sheets exit builder; save errors persist; repair completion restores active previews; incoming guests use door routes; room income and upgrade progress are displayed.
- Preview meshes reuse their geometry while unchanged; reduced motion skips construction tweens. Furniture catalogue has original illustrated thumbnails for all 15 objects.
- Scope: regular rooms and suites use preset furnishing positions, eight-room capacity, existing three furnishing categories and permanent reusable ownership. Public service rooms remain the existing hotel facilities.
- Legacy rooms gain the new accommodation income bonus in addition to existing wing income; this is a player-positive migration change.
- Environment note: the local Godot runtime reports an OS root-certificate-store error at startup, including before this change. Offline gameplay and all verification complete successfully.
