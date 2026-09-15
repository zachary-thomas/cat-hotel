# Creative preview verification

Verified September 14–15, 2026, on Windows with Godot 4.7.2, using isolated test profiles.

## Results

| Check | Result |
|---|---|
| Existing regression suites | All 33 suites completed successfully |
| Creative model, content, building, maps, save integrity, services, God mode, social simulation, movement, Meadow, world, voxel polish, UI, app and dense-property suites | All 15 suites completed with zero failures |
| Actual UI captures | 55 Build/menu captures, 12 God mode Settings/Build captures and 16 hotel/garden captures; zero layout failures at 100% and 150% text |
| Pointer and simulated touch | Selection, move preview, rotation, cancel, path drag, pinch, menu exclusion, Undo/Redo, resize storage warnings and save retry passed |
| Safe areas | Synthetic inset test passed; world picking coordinates include the safe-area offset once |
| Room and template geometry | All four starter maps validated; all six arrangements placed in all four rotations on all four maps |
| Separate package | Windows pack exported; all staged creative source hashes match tested source |
| Package persistence | GPU-backed write and reopen smoke passed |
| Direct executable | Creative default scene and application identity verified; creates its own journal |
| Existing-save protection | Legacy save sentinel hash unchanged after direct launch and both package smoke passes |
| Current entry points | Project F5, standard Windows launcher and creative launcher select the redesigned game |
| God mode | Settings interaction, all-map unlocks, free construction and upgrades, normal pricing after disabling, refund protection, save rollback and persistence passed |
| Movement and collision QA | Clear diagonal routes, wall/furniture clearance, separated arrivals, oncoming guests, narrow doors, housekeeping yielding, crowded activities and physical furniture poses passed |
| Voxel QA | Cube geometry and animated spillways, reduced-motion freeze, raised counter staff, screen-space warning badges and equal-revision world replacement passed |

## Workflows covered

- Buy a parcel, copy a furnished cottage onto it, connect a two-cell path, open the cottage, break and restore access, then remove the cottage into Storage.
- Save and reopen more than eight rooms. A dense fixture has **24 operational cottages, 98 objects and 18 guests**, with income from all ready rooms and real housekeeping travel.
- Remove the last bed or reception and lose the corresponding operational capacity. Move reception to a new position and verify arriving cats target it.
- Place a milkshake counter and stool on ordinary grass; observe check-in, travel, ordering, service and reserved seating. Cottages retain constructed-access requirements.
- Check counter attendants, exclusive guest and staff positions, full venues, removed venues, sleeping, housekeeping and roster turnover. Facing counters cannot occupy the same staff position.
- Keep service upgrade income unchanged when adding another bar. Ready rooms retain furnishing-combination bonuses; unfinished rooms contribute no room bonus or guest capacity.
- Preview prices without mutating live or borrowed state. Reject insufficient funds, restore wallet and ownership after save failure, preserve elapsed income across Undo and keep failed previews available for retry.
- Validate real Unix timestamps, globally unique inventory IDs, moving starter inventory between maps, malformed nested records, inflated refund values, optional settings and restored allocation counters. Rejected saves do not damage live state or history.
- Keep a failed final save open with retry controls. Show persistent save errors and protect unreadable journals from overwrite.
- Enable God mode through the actual Settings toggle, build with an empty wallet, save and reopen, then disable it and verify normal affordability checks. Previously free rooms and paths cannot produce paid refunds. Failed toggle saves restore all unlocks and retain history.
- Inspect Settings and the Rooms catalogue with enlarged text. Long headings wrap and room buttons truncate safely without forcing panels beyond the viewport.
- Walk 18 guests through a 24-cottage property for 600 simulated seconds. Every guest checks in and completes activities; bodies remain separated and travel has no teleports. A rendered minute of activity also checks that furniture poses do not stack cats.
- Verify idle housekeeping can step aside, and a guest starting between grid points joins its route without a backward step. Avoidance excludes both occupied nodes and edges that graze another cat.
- Confirm Start fresh before replacing preview progress. A failed write keeps the previous model, history and world. Successful reset rebuilds geometry even when the old and new model revisions happen to match.

## Performance

Measured on this Windows machine with an NVIDIA RTX 4090 Laptop GPU. These are development measurements, not a mobile-device performance guarantee.

| Dense fixture measurement | Observed |
|---|---:|
| Cached simulation, 3,600 frames | Approximately 0.32–0.35 ms per frame |
| Build quote | Approximately 30–35 ms |
| Initial navigation build | Approximately 310–346 ms |
| Save validation | Approximately 0.72–0.80 seconds |
| Rendered property, 1280×800, 90 measured frames | 7.97 ms per frame |
| Draw calls in rendered dense view | 5,531 |

Navigation is reused until a layout commit. The viewport capture from this run is [dense-property.png](dense-property.png).

Latest first-visit captures, close-ups, phone room warnings and a 120-frame movement recording are in [garden-polish](garden-polish/hotel-390x844-100.png). The garden and connected main hotel replace Meadow's earlier scattered starter buildings. Existing player layouts are retained until **Settings → Start fresh** is confirmed.

## Preview boundaries

- Physical Android/iPhone touch, notches, thermal behavior and performance have not been tested. Phone layouts and touch gestures were checked through desktop rendering and simulated input.
- This is a Windows preview with the locally available Godot runner. Production export templates, code signing, live payment integrations and mobile packaging are outside this delivery.
- Preview expansion buttons are explicitly labeled tests and charge no money.
- Reception reserves a position during the approach, so a distant lobby checks in a dense arrival group progressively. Dense tests verify that all guests eventually receive service.
- The engine prints a certificate-store warning in this environment. Headless app shutdown additionally reports audio playback resources; the rendered app and packaged GPU smoke finish without those resource reports. No test run reported a script error.
- The original save format remains separate; this preview performs no save conversion. At the user's explicit request, the two existing development `hotel-save` journal files were deleted to start fresh. Other files and photos were retained.

## Repeatable checks

From the project folder, run `tools/test.ps1`, `tools/test-creative.ps1`, `tools/package.ps1` and `tools/test-creative-package.ps1 -Rendered`.

For dense rendering, run `tools/test-creative.ps1 -Rendered -Resolution 1280x800 -Suites test_creative_dense`. UI capture mode is provided by `tests/test_creative_ui.gd` with the `--capture-ui` user argument. God mode Settings/Build captures use `tests/test_creative_app.gd` with `--capture-god-mode`. Always use an isolated test profile for captures.
