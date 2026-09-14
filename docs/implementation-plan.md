# Godot Idle Hotel Implementation Plan

Implementation will proceed directly in this project, with behavioral tests for the economy and persistence and rendered checks for the game.

**Goal:** Build a playable portrait Godot prototype of the approved cat-only idle hotel journey.

**Architecture:** A deterministic RefCounted economy model is persisted by a Node service. Procedural voxel scenery and animated feline characters render independently; a Control-based mobile UI communicates by signals.

**Tech Stack:** Godot 4.7.2 (available local portable build), GDScript, Compatibility renderer, procedural BoxMesh art. No external runtime dependencies.

**Spec:** [PRD](PRD.md), version 0.3.

## Global constraints

- Mobile portrait layout; desktop preview must remain playable with the mouse.
- Cats run and inhabit the entire world. Other animal species are future events.
- Two playable hotels, four upgrade zones, Cat Coins, level gates, and persistent network income.
- Exact income independent from rendering. Offline cap eight hours with no duplicated claims.
- Preserve the source concept images; runtime art is actual geometry.
- This is a playable prototype; phone signing/export, cloud saves, final art/audio, and full production accessibility are later device-validation work.

## Interfaces and files

1. `scripts/core/hotel_model.gd`: `new_game(now:int)`, `advance(seconds:float)`, `upgrade(hotel:int, zone:int)->bool`, `unlock_hotel(index:int)->bool`, `rate()->int`, `hotel_rate(index:int)->int`, `hotel_level(index:int)->int`, `upgrade_cost(hotel:int,zone:int)->int`, `reconcile(now:int)`, `claim()->int`, `serialize()->Dictionary`, `restore(data:Dictionary)->bool`. Model state: `coins:float`, `hotels:Array`, `current_hotel:int`, `pending_coins:float`, `pending_seconds:int`, `last_seen:int`, `started:bool`, `settings:Dictionary`. Hotels contain `owned:bool`, `zones:Array[int]`, `purchases:int`.
2. `scripts/core/game_store.gd`: atomic versioned local saves and backup recovery. `save_model(model)->bool`, `load_model(model, now:int)->bool`; injectable save path for tests.
3. `scripts/world/hotel_world.gd`: extends Node3D; `show_hotel(index:int, levels:Array)`, `set_motion_enabled(enabled:bool)`, `focus_zone(index:int)`, `reset_camera()`, signal `zone_selected(index:int)`. Self-contained camera/light/geometry; occupies the screen behind the UI. Parent routes view input to it; world can expose `handle_input(event)`.
4. `scripts/ui/mobile_ui.gd`: extends Control; signals `play_requested`, `upgrade_requested(zone:int)`, `hotel_requested(index:int)`, `claim_requested`, `setting_changed(key:String,value:Variant)`, `zone_focus_requested(zone:int)`. Methods `render(snapshot:Dictionary)`, `show_toast(message:String)`, `open_upgrades(zone:int=0)`. Snapshot documented in task brief and main controller.
5. `scripts/main.gd` and `scenes/main.tscn`: composition, monotonic earning, lifecycle checkpoints, snapshot mapping, signal wiring, settings, save errors.
6. `tests/test_model.gd`, `tests/test_store.gd`, `tests/test_app.gd`: headless behavioral tests and rendered screenshot capture where supported.

## Task 1 — Economy and persistence

- [x] Add behavioral tests first: 120 coins in one minute at 120/min, level3→4 costs480, insufficient funds unchanged, 18 purchases unlock level10, second-hotel gate, 2h/10h offline awards, segmented cap, claim idempotence, fractions, clock rollback, save round-trip and corrupt-primary recovery.
- [x] Run `godot --headless --path . --script tests/test_model.gd`; record missing implementation failure.
- [x] Implement model and store. Use validated data, exact accumulated remainder, monotonic checkpointing, and atomic temporary-file replacement with backup.
- [x] Run both suites until expected behavior passes.

## Task 2 — Actual voxel hotel

- [x] Build procedural cat meshes, wooden floors, walls, beds, reception, bowls, play trees, plants, and garden props with shared materials.
- [x] Implement Meadow/Seaside palettes, visible level tiers, idle animation, zone focus, touch/mouse pan and zoom.
- [x] Validate scene construction headlessly and capture a rendered scene. Review feline silhouette and portrait framing.

## Task 3 — Mobile interface

- [x] Implement title, HUD, objective, Hotel/Upgrades/Map/Cats tabs, zone upgrade sheet, progression requirements, offline claim sheet, and settings.
- [x] Route actions through signals only. Affordable/max/locked states derive from controller snapshot, never duplicate economy logic.
- [x] Use warm ivory/sage/forest palette, large touch controls, responsive anchored layout, scrollable menus, dismissible sheets.
- [x] Verify controls against snapshots for fresh save, insufficient funds, level gate, unlocked hotel, and pending earnings.

## Task 4 — Integrate and verify

- [x] Compose scene/model/store/UI and settle earning before every mutation.
- [x] Save on purchases, claims, settings, background, quit, and timed checkpoints. Restore pending rewards on resume; suspend earning while backgrounded.
- [x] Verify tutorial and cat discovery milestones, two-location transition, game state after reload, and settings behavior.
- [x] Run headless import/parser checks, model/store suites, and app integration tests; run rendered screenshot checks and inspect the result.
- [x] Document exact launch/test commands, known prototype limits, and actual verification results in README and build report.

## Execution record

Work takes place in the existing project directory on `codex/godot-idle-prototype`; this repository began without commits, so a linked worktree cannot carry the uncommitted design package. Local runtime lives in ignored `.tools/godot`.

