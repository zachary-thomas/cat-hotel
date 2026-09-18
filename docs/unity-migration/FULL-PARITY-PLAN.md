# Full Godot-to-Unity parity implementation

Authority: user-approved plan, September 18 2026. Restore AND enhance the current default Godot creative hotel. This is a complete migration, not another reduced slice. Unity 6000.3.24f1, orthographic voxel 3D, Windows QA and Android/iOS targets. Preserve Godot source/builds/saves. Archive prototype Unity journals, then use a new parity-v2 profile and complete starter maps. No live commerce.

## Required scope

- Export a revision/hash-pinned manifest from actual Godot definitions: four complete maps/neighborhoods/care rooms, full catalogue, six arrangements, 18 cats, progression, services, staff, starter state, geometry and test references. Import geometry recipes preserving transforms/colors/animation pivots; no approximate placeholder models.
- Native resolution and 4x MSAA, separate desktop/mobile URP profiles, soft shadows, warm depth, desktop SSAO and restrained grading. Preserve crisp flat voxel normals, fit/focus/zoom/cutaway/evening.
- Full construction: regular/suite/cottage, copy/move/rotate/resize/remove, individually editable arrangements, half-cell furniture, storage, parcels, three path styles/erase, access/readiness and diagnostics, no eight-room cap. Quotes do not mutate. Transactions roll back on failed save. Twenty-step history preserves earned progress and correct paid refunds.
- Full economy/progression: exact source prices/rates/bonuses/levels/capacities, service upgrades/staff/housekeeping, known cats/friendship/playdates, all destination unlocks/travel, preview entitlements/Cat Club/God mode, offline eight-hour cap and claim.
- Full authoritative life: check-in/roster, reserved activities/staff/seats, order/serve/drink, sleep/rest, dirt/housekeeping, body-safe navigation/avoidance/yielding/replanning, no rewards from presentation. Paired contextual speech/gestures preserve activity timers and cooldowns.
- Six independent sidewalk cats per map; geometry-safe and separated routes, editing does not reset them, reduced motion freezes them, no progress/income effects.
- Source voxel cat poses and fountain spillways/splashes/fire/embers/foliage/lamps/cafe/toy/furniture/litter effects, stable activity tokens and elapsed times, static batching excludes moving parts.
- Six actual care interactions: stroke/hold pet, brush, drag wand (Feather display name), flick yarn, cushion placement/rest, box placement/peek. Favorite +6/ordinary +3, 12s cooldown, cap100; hotel continues and back restores view/selection/scroll.
- All native Hotel/Cats/Build/Life/Map/Settings controls, warnings, illustrations, income/rate/status, staff/upgrades, reset and recovery. Destination/context audio, independent toggles, lifecycle, persistent save errors, failed-exit choices, confirmed reset rollback.

## Architecture and contracts

Pure C# authoritative domain consumes exported JSON content (Newtonsoft is already installed); Unity views only project state/events. Domain must preserve existing presentation-facing convenience methods while adding complete multi-map commands and life snapshots. Domain lead owns and publishes contract details immediately. Godot lot(x,y) -> Unity(x,z), rendered at1.1 scale once.

Root owns exporter, reference manifest and geometry JSON, editor rendering/import/build tooling, integration, save-profile archive, verification and ledger. Domain agent owns Runtime/Domain and domain tests. World agent owns VoxelWorld and new world/geometry/animation presentation files. UI agent owns HotelUI, HotelApp, HotelAudio and new UI/care input files. No cross-owned edits without coordination. Runtime load must consume exported manifest rather than obsolete prototype ScriptableObject seed.

## Acceptance

Ledger rows each have Godot source, Unity implementation, behavioral test and visual/input evidence; statuses missing/implemented/verified/blocked. Cover ALL current creative suites (not just an outdated count). Compare deterministic fixtures, exact content/rules/rewards, tolerances only movement/rendering. Record matching screenshots AND motion clips.

Required: four maps, six templates x four rotations; complete construction/save/reopen loop; moved/removed/full venues, reservations/housekeeping/roster; 24 cottages98objects18guests600s dense fixture; all care/social/progression/God-mode/offline/corruption/retry/reset scenarios; 300s sidewalk clearance/separation on each map.

Input/layout sizes360x640,360x800,390x844,430x932,640x480,800x760,1280x800 x text100/125/150 plus safe insets. Actual pointer/simulated touch, no world leakage, placement>=50%world and browse>=35%world height. Profile dense populated/effects-enabled Windows60FPS/mobile30FPS targets. Windows+Android build and iOS export; device/signing explicitly blocked without hardware. NEVER mark complete with missing features/placeholders/compile-only claims.
