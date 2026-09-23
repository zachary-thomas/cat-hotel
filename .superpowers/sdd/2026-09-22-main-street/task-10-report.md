# Main Street Task 10 — integrated acceptance report

Date: 2026-09-22. Worktree: `C:/Users/zach7/.codex/worktrees/main-street/cat-hotel`; branch: `codex/main-street`. Base: `1df3a65`. The original checkout and its uncommitted hotel-growth work were not edited.

## Implemented fixes

- Restored the prior town Follow state when leaving either store (regression covers both true and false).
- Fit interiors to the available world viewport instead of a fixed zoom; floor bounds remain in view on phone layouts.
- Replaced two corrupted clothing separators with readable middle dots.
- Made VoxelWorld/motion collider cleanup safe during EditMode; repaired clothing content setup and pause dispatch in two test fixtures.
- Market Day timer now updates smoothly each tick but journals at one-second intervals, saving completion immediately. Explicit Save and pause save current state immediately. This was approved after a measured ~31.8 ms event frame average. An abrupt crash can replay under one second; failed completion cannot duplicate its durable reaction token. Seven new domain checks cover cadence, smooth remaining time, explicit flush/reload, failed checkpoint rollback and idempotent completion.
- Acceptance now genuinely opens room placement before navigating to Main Street and compares camera position/orthographic size after Back.
- Shop camera faces display fronts; only the near side wall is cut away. Added timber cashier steps to show faces above the checkout counters.
- Wardrobe boxes: moved neck pieces below the oversized head; expanded sweater/raincoat coverage and moved the cape onto the rear silhouette. Prices, rewards, colors and catalogue count are unchanged.
- Added opt-in Main Street acceptance/art fixtures. Pointer navigation uses queued Input System mouse/touch states, not Button.onClick. It disables native pointer devices inside that test player and ignores hidden-window focus so host cursor movement cannot contaminate the test. Rename text is fixture-assigned after selecting the field. Placement-to-town uses the public navigation boundary because placement has no Explore button.

## Commands and evidence

All Unity actions ran outside the sandbox against the isolated project, sequentially, checking for an existing Editor first. No second Editor was intentionally started. The test Editor briefly lingered after CLI return; a build guard refused to launch and was retried after it exited. Global Editor.log also contained another checkout's build during the session, so own output paths and DLL timestamps were used rather than attributing that log to this project.

| Command | Observed output |
| --- | --- |
| `dotnet run --project tests/unity-domain` | Final `PASS 676240 checks`; Godot oracle, building, god mode, wardrobe and shell suites passed. Latest dense 600s simulation: 209 visits, 18 cleaned, 18 guests, 4405 ms CPU. |
| `tools/unity.ps1 Test` | Unity 6000.3.24f1: 94 tests, 0 failures, 0 errors, 0 skipped; 39.699s. `builds/unity/test-results.xml`. |
| `tools/unity.ps1 Windows` | Development player build succeeded, exit 0. Output `builds/unity/Windows/PurringtonHotel.exe`. |
| `tools/unity.ps1 QA` | Startup, orthographic camera, navigation, care stage, panel bounds, wheel zoom, layouts and save passed. Final rerun recorded below. |

Initial actual Unity run: 92 tests, 87 pass, five failures. The failures exposed delayed Destroy in EditMode, missing TownContent initialization, and EditMode SendMessage usage. CLI also printed misleading license diagnostics; the actual XML identified test failures. Adding Follow tests produced 94 tests with the true Follow case red; fixes yielded 94/94. Initial domain count was 676233; the cadence assertion was observed red before implementation, then 676240 passed.

## Acceptance method

Each case configures a real player window and UI text scale with simulated safe insets. Fresh fixtures supply coins; actions thereafter navigate buttons, scroll, tap a storefront sign, drag/pinch, approach cashiers, buy, accept/complete quests, try/buy/wear clothing, start Market Day, save, reload through a separate real journal-backed model and return to Hotel. At each first basket/bundle purchase, quest reward/ribbon grant, clothing purchase and event start, both isolated journal temporary files are held exclusively, then the same real button is clicked. The check requires a failure notice and exact unchanged serialized state; locks are released and Retry is clicked. Repeated matrix cases share earned inventory, so the first case carries the blocked-write checks. Legacy uses v3 state with optional town/manager/wardrobe/outfit fields removed and exercises the same flow.

Event ended-state captures fast-forward the domain clock by 95 seconds, explicitly labeled fixture. Art matrix uses programmatic setup to freeze and show every scene, separately from pointer acceptance. Hidden player backbuffers were intermittently black; retained renders use the actual camera, scene and Canvas through URP SingleCameraRequest to a RenderTexture at the requested resolution. This is a real render, not a mocked screenshot, but does not prove a physical display or touchscreen.

## Investigations and rejected runs

- First input player exited unexpectedly (-1) with no logged runtime exception. Parent confirmed they did not close it. It is not counted as a pass.
- Early sign tap hit a still-visible toast; waiting for toast expiry fixed the harness.
- Skip walk could disappear after natural arrival; the harness now accepts an already-arrived manager.
- The first scrolling helper dragged in the wrong direction for an offscreen category; it now finds the actual target and drags toward it.
- A full matrix completed six portrait cases with zero failed checks (44/41/40/40/40/40); desktop camera probes collided with natural shop arrival and the later wardrobe body probe threw. That overall run is not a pass. Probe travel is now ended before testing the outdoor camera.
- A desktop-only rerun was contaminated by native pointer events and failed from the first Explore, causing 123 downstream failures. Exclusive synthetic pointers fixed this: `desktop-reviewed` completed 56 and 53 checks, zero failures/errors, ~16.92/16.91 ms average event frames, worst ~31.23/31.40 ms over 60 frames each.
- Blocked-save acceptance was tightened from matching any `save` message to requiring `Couldn't save`; a successful `Hotel saved` notice cannot satisfy it.

## Art review and limitations

All 13 pieces (12 shared items plus Store ribbon) were captured and inspected at 390x844 on three actual cat recipes with explicit .75x, 1x, 1.25x scale fixtures. The live roster recipes all share the same body dimensions, so these are not a real kitten/Miso/largest-cat gate. Contact sheets expose all 39 results; original selected captures are retained. Back pieces use a rear view to inspect leg/tail clearance. Neck accessories are intentionally small but visible below the chin; hats cover ears naturally or sit between them; backwear clears the legs. Three dressed guest outfits are saved and reloaded, plus care portrait/landscape and roaming captures.

Physical Android and iOS testing was not available and remains a release gate. No mobile performance, device lifecycle, OS keyboard, thermal or GPU compatibility pass is claimed. Short Windows frame samples are diagnostic only. Existing imported scenery emits negative-scale BoxCollider warnings; no runtime exceptions were accepted as a pass. The independent shared wardrobe plan's literal varied live-roster age/size requirement remains limited by the current same-size roster.

## Final results and retained files

Fresh-save pointer run: **completed, 409 checks, zero failures and runtime errors**. Each performance sample contains 60 frames during Market Day; these short Windows samples are not device benchmarks.

| Viewport / text | Checks | Failed | Average ms | Worst ms |
| --- | ---: | ---: | ---: | ---: |
| 360x640-text100 | 56 | 0 | 16.91 | 31.38 |
| 360x640-text150 | 53 | 0 | 16.92 | 32.04 |
| 390x844-text100 | 50 | 0 | 16.93 | 32.39 |
| 390x844-text150 | 50 | 0 | 16.9 | 30.51 |
| 430x932-text100 | 50 | 0 | 16.9 | 30.14 |
| 430x932-text150 | 50 | 0 | 16.9 | 30.56 |
| 1280x800-text100 | 50 | 0 | 17.06 | 40.33 |
| 1280x800-text150 | 50 | 0 | 16.96 | 34.25 |

Parent image review confirmed distinct stores and visible cashiers. Investigated the pale bands in narrow boutique try-on: neighboring 120×textScale Info panels are partially masked while the action row is centered; labels are present in the landscape capture. Town lower rows are within the masked ScrollRect and reachable by real drags, as exercised by Square/Manager/destination/Back actions. Record this small-screen scrolling behavior rather than claiming every catalogue label is visible simultaneously.

## Implementation commits

- `5bf8a7e` — integrated camera, persistence, domain regression and Unity test fixes.
- `e4cede1` — shop visibility, wardrobe tuning, opt-in acceptance/art harness and retained wardrobe captures.
- QA/documentation commit recorded in the final handoff.

Incidental Fredoka/Nunito font serialization, URP asset rewrites and ProjectSettings changes were reviewed and restored. The only non-format project-settings diff was the build's APP_UI_EDITOR_ONLY scripting define; it was not required as a source change. Source `.meta` files are retained; builds/profiles/Library remain ignored. `git diff --check` passed. No PR was opened or merged; parent final spec/code review is still required.

## Owning files

- `Runtime/Domain/TownEvent.cs`, `tests/unity-domain/TownEventSuites.cs`: checkpoint implementation and regression.
- `Runtime/Presentation/VoxelWorld.cs`, `VoxelWorldTown.cs`, `GodotObjectMotion.cs`: responsive camera/Follow and EditMode-safe cleanup.
- `Runtime/Presentation/HotelTownUI.cs`: readable clothing separators.
- `Runtime/Presentation/StoreInteriorView.cs`: near wall cutaway and cashier steps.
- `Runtime/Presentation/MainStreetAcceptance.cs` (+ `.meta`), `ParityInputAcceptance.cs`: explicit opt-in player acceptance and capture fixture; no normal-startup execution.
- `Assets/Resources/Content/Wardrobe.json`: box-only wear geometry tuning.
- `Tests/EditMode/ClothingStoreTests.cs`, `ShoppingCartTests.cs`, `StoreInteriorTests.cs`: repaired initialization/dispatch, Follow regression and bounds assertions.
- `Runtime/Domain/HotelShell.cs.meta`: missing Unity source metadata retained.
- `unity/PurringtonHotel/README.md`, `docs/unity-migration/QA.md`, `docs/art/qa-shots/{main-street,hotel-growth}`: controls, evidence and honest limits.

Paths beginning Runtime/Tests/Assets above are under `unity/PurringtonHotel/Assets/Purrington` except Assets/Resources, which is under `unity/PurringtonHotel`.

## Reproduce the opt-in player check

Build with `tools/unity.ps1 Windows`, then launch the executable with these arguments and an isolated fresh profile directory:

```
-purrington-input-acceptance <output> -purrington-main-street -purrington-offscreen-capture -purrington-input-only -purrington-profile <profile> -logFile <log>
```

Add `-purrington-legacy` for the single legacy 390x844/100% case, or replace `-purrington-input-only` with `-purrington-art-matrix` for all scene/wardrobe fixtures. `-purrington-desktop-only` filters to the two landscape cases. Never reuse a normal player profile for the fixture harness. The player writes `input-acceptance.json`, records failures/errors and exits; the orchestration checks status and counts, not just process exit.

Legacy v3 fresh-field migration journey: completed at 390x844/100%, 56 checks, zero failed checks and zero runtime errors. Retained JSON: docs/art/qa-shots/main-street/legacy-results.json. Final source domain suite: PASS 676240. No physical device tests were run.

Final art run (`art-reviewed`): completed, 124 checks, zero failures/errors, 122 actual nonblank renders (80 scene-matrix + 39 item/size + 3 dressed care/roaming); saved/reloaded three guest outfits passed. All eight scene contact sheets were inspected, and selected original phone/landscape cashier, cart, boutique and market views were reviewed. Parent also inspected representative captures. Clean event heading/timer is retained in the landscape running-state image; narrow event captures preserve their scrolled state.

Final smoke rerun: `PASS: startup, orthographic camera, navigation, care stage, panel bounds, wheel zoom, layouts, save. Screenshots require visual review.` Retained under `docs/art/qa-shots/main-street/smoke-{result,performance}.txt`.

Selected screenshot locations: `docs/art/qa-shots/main-street/README.md` links the eight matrix sheets and thirteen full-resolution art originals plus three real input catalogue views. `docs/art/qa-shots/hotel-growth/README.md` links the three all-item grids, 39 originals and three outfit/care/roaming captures. The raw local runs are `builds/unity/main-street/{input-reviewed,legacy-reviewed,art-reviewed}`. Retained JSON contains the complete named checks and source screenshot paths. Builds and QA profiles remain untracked.
Final committed-source EditMode rerun: 94 tests, 0 failures, 0 errors, 0 skipped, 39.699 seconds. Final smoke: 180 frames / 3.00 seconds, 60.0 FPS, worst 16.8 ms.
