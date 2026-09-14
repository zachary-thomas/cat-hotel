# Mobile overhaul implementation review

Status: implemented and locally verified; Task9 and whole-branch independent review remain with the controller. Physical Android validation is an open release gate, not a passed check. Work is on `codex/playful-mobile-ui` in `.worktrees/mobile-ui`; Task9 starts at `9f31b43776f6d4041ae466f59dde4ab92e2dd624`.

The approved overhaul now has the five Hotel/Cats/Build/Life/Map destinations, live care, immediate saved building, illustrated activities and destinations, native reward recovery and global preferences. The user explicitly authorized a fresh version; normal player profiles were excluded from all automated work. Every hotel worker, guest and resident remains a cat.

## Before and after

Compare the [original running hotel](current/00-normal-play-camera.png), [original interface capture inventory](current/), and [four approved concept boards](README.md) with the [36-image final gallery](after/README.md). The gallery covers all 12 primary concept screens, large text, actual invalid/save-failure states, unknown/paid guests and desktop detail framing. [Capture hashes and original paths](after/capture-manifest.json) make the final set traceable.

The live Hotel uses a close 3D view with readable cats, native wallet/status, nonoverlapping world annotations and a whole-card next step. Cats uses indexed portraits, hidden silhouettes and a live 220-unit care stage. Life/gatherings/Staff/Garden/Manager/Discoveries/Paw Mart/Scrapbook preserve their controller transactions and real state. Map uses the reviewed world illustration/postcards and both Seaside gates; at enlarged text its details scroll and selecting a destination deliberately reveals/focuses those details, while its action stays pinned. Reward Later/Back preserve the pending amount; failed saves preserve retry and only successful Collect credits once.

## Final cleanup and responsive fixes

Removed the empty quick bar and all remaining callers, the unused HotelUI PetView preload, and obsolete pending-control startup offsets. The search for `quick_bar`, `offset_bottom = -90`, `size.y - 150` and `size.y-165` returns no matches in scripts/UI, main or tests. Fit-all, world input exclusion and immediate/rollback/Undo transaction checks remain covered.

Watch's Back to hotel uses shared safe geometry, a measured full label and at least 48-unit target. Its150% four-edge-inset fixture clicks the actual button and returns to Hotel. Pending earnings uses the shared header geometry and scaled margins/minimum target.

The album keeps its 80-entry cache and 640-pixel thumbnails. Before a newest-first render it prunes paths absent from the displayed 80 entries, protecting all 79 remaining textures when a new photo arrives. A focused81-photo fixture verifies reuse by texture identity and the cache cap.

Font conversion now rounds upward so physical12/14/16-unit minima survive fractional phone scaling, including390px widths; Build's already-converted canvas fonts follow the same minimum rule. Sheets cap their width at 620 phone units for centered desktop reading. Purchases & privacy wraps at large text/insets. Care toy grids use two columns for enlarged text or widths too narrow for three80-unit art slots with padding; containment checks cover every toy image and caption.

Remaining numeric geometry is intentional and shared: PhoneLayout's64/112-unit header,80-unit dock,64/80-unit objective and8-unit gaps; GameSheet's620-unit maximum column and16-unit total outer inset; Watch's12-unit safe inset/160-unit preferred minimum width; BuildMetrics'336-unit desktop tray,48-unit history,56-unit actions and phone world-space reservation; and the220-unit live care stage. These are phone-scaled layout tokens or world framing, not old fixed screen boundaries. Build's catalogue-to-placement overview deliberately stays at camera size 20 while the player positions furniture; the settled walkthrough confirms that framing and preserves it through Place.

## Verification

One complete `./tools/test.ps1` pass ran all 32 registered behavioral suites and exited0: `tmp/task9-full-suite.log`. It covers economy/save/model/life/commerce test fixtures, audio, collision, app/experience/grounds/views/layout, all three mobile suites plus the walkthrough, building/rewards, and all 14 Build transaction/input/history/layout/preview suites. Tests use isolated APPDATA/LOCALAPPDATA and unique saves; no normal save or live commerce adapter operation was used.

The required rendered command `./tools/test.ps1 -Rendered -Resolution <size> -Suites test_mobile_navigation,test_mobile_views` passed at 360x640,360x800,390x844,430x932 and1280x800, each exit0. Logs are `tmp/task9-matrix-<size>.log`. Views exercise100/125/150% through the real preference command, and independent fixture resets prevent one scale's transactions leaking into the next. The final route matrix covers Hotel, Cats, Pet, Life, Events, Journal, Upgrades, Map, Settings, Staff, Grounds and Shop at all three scales, with and without simulated left12/top24/right18/bottom20 phone-unit insets. Shared geometry checks validate safe bounds, dock reachability, physical Back/primary targets, desktop columns and selected Seaside requirements. Navigation also verifies focused Back/Escape/Android routing, scrolling, world rectangle, Fit-all, camera preservation and live care persistence.

After the initial full pass, only affected verification was repeated for final focus/reveal, toy reflow, strict fonts and fixture teardown. The final rendered matrix-only runs at all five sizes are recorded in `tmp/task9-final-matrix-<size>.log`; they use `--script tests/test_mobile_views.gd -- --matrix-only`. The focused rendered360x640 run of `test_views,test_build_mode,test_build_flow,test_mobile_walkthrough,test_startup_offline,test_mobile_layout` passed: `tmp/task9-final-focused.log`. It generated the final integrated Hotel, Build invalid/save-error and reward-error captures. Reward failures are exercised at 125/150% through real preference commands and actual failed Collect/retry input; both enlarged error labels and pinned retry actions remain visible. The final settled pointer walkthrough is recorded separately in `tmp/task9-walkthrough-final.log`.

All 36 curated captures were visually inspected at native phone size (unscaled contact sheets and individual frames), including normal/large header, catalogue/placement/invalid/save-failure, live care/toys, unknown/paid cats, activities, Map/inset reveal, reward error/retry, Settings bottom actions and desktop columns. Scrolling deliberately exposes content beyond the viewport; essential actions remain reachable. The complete exploratory matrix stays in ignored tmp rather than the runtime package.

## Normal-start pointer walkthrough

`tests/test_mobile_walkthrough.gd` starts without a save, uses actual press/release input for Play, Cats, Miso care, Build/category/item/floor/Place/Play, Life, Map and Settings150%, then returns to Hotel. It never seeds coins, ownership or progression. Passive model time is paused after Play so the action delta is exact; natural startup income is recorded. The paid item is Rope scratcher,140 Cat Coins, and Miso friendship increases0→6. The latest settled rendered log records the exact wallet values and isolated save path.0.6-second capture settling confirms Build's wide framing is stable, not a transition.

Walkthrough saves live only under the test profile's Godot/Purrington Hotel directory with unique `fresh-walkthrough-*` names. They are separate from the user's fresh preview profile and are not distributed. The starting-photo/gallery evidence is explicitly separate from seeded later-game fixtures.

## Windows playable handoff

Outputs in this worktree:

- `builds/windows/Play.cmd`
- `builds/windows/PurringtonHotel.exe`
- `builds/windows/PurringtonHotel.pck`
- `builds/PurringtonHotel-WindowsPreview.zip`

The package also includes Test expansions.cmd, the redesigned control instructions and engine/font/mobile-plugin notices. Its ZIP has exactly 8 intended deliverables; `tmp/task9-zip-inventory.json` records them. An explicit allowlist excludes saves, smoke data, profiles, logs and documentation.

Play.cmd sets APPDATA and LOCALAPPDATA to a new persistent `%LOCALAPPDATA%/Purrington Playful Preview 2026-09` profile (using the caller's original Windows LOCALAPPDATA), then launches `user://playful-mobile-preview-save`. Normal game saves remain separate; repeat launches retain preview progress. The launcher quotes its executable, working path and PCK, and it was run from an extracted `tmp/Preview With Spaces` directory. A first/second-launch smoke creates only a separate launcher-test profile and verifies fresh entry then retained 125% preference. The real preview starts without any automated fixture.

The actual exported PCK smoke runs from the extracted package directory with isolated APPDATA/LOCALAPPDATA, not the source project's resource root. It verifies 18 imported illustrations, excluded design boards, construction, placed furniture, amenities, manager work, housekeeping, doors, audio and care. The old smoke's obsolete `life.hotels[].rooms` assertion was replaced with the canonical furniture inventory; no gameplay economy changed. Final build and smoke logs are `tmp/task9-package-final.log` and `tmp/task9-package-final-smoke.log`.

The runner is the bundled Godot 4.7.2 editor-capable Windows binary because desktop export templates are unavailable. The preview instructions state that distinction. No signed mobile release, push, publication or real purchase is included.

## Diagnostics and release gates

The full pass contained the known Windows root-certificate-store diagnostic. It also exposed two actual intermittent teardown warnings that were investigated separately: Experience retained 12 AudioStreamWAV/AudioStreamPlaybackWAV instances referencing ui_tap.wav, hotel_open.wav and cat_purr.wav; Building retained an unnamed AudioStreamWAV/Playback pair. Verbose evidence is in `tmp/task9-experience-diagnostic-3.log`/`-4.log` and `tmp/task9-building-diagnostic-3.log`. Both fixtures now shut down their soundscape and drain queued audio before freeing the app. Their focused final verbose runs passed without ObjectDB/resource warnings: `tmp/task9-experience-final.log` and `tmp/task9-building-final.log`. The earlier Task8 mobile-views warning was not assumed to explain these; the actual final diagnostics established the audio-only references.

One initial pack-smoke attempt used the source working directory, allowing FileAccess to see excluded source docs; rerunning from the extracted package proved the export exclusion. A following smoke found the obsolete furniture field and was stopped, corrected and rerun. Failed attempts are retained in tmp and are not presented as passing evidence. The export also prints its editor-embedded ICU text-server notice; the shipped runner is the same Godot version.

Physical Android checks remain open: actual notch/gesture insets, thumb reach, pinch/pan, held-pet release, physical Back, interruption focus, haptics and offline resume. No device/ADB was available. Simulated insets and desktop pointer input do not establish those device checks. Mobile billing, ads, signing and iOS delivery remain outside this preview handoff.

## Artwork and provenance

All 18 reviewed text-free illustrations are consumed. [Exact prompts](production-art-prompts.md), [source dimensions/SHA-256 inventory](production-art-inventory.json) and the [runtime manifest](../../assets/ui/mobile/README.md) map the five dock icons; coin/settings/view/back/close/rotate/undo/redo/adjust controls; six toys; six Life cards; four postcards; six gatherings; three staff portraits; Welcome/reward; and empty/locked states. The final hash audit matches every source. Imported longest dimension is capped at 1024, cached atlases use imported dimensions, and decorative art ignores input. The live hotel/care remain 3D; composite concept boards never enter gameplay. No artwork was regenerated.

## Chronological implementation rulings

The following lines are copied verbatim from the controller's final SDD ledger. The ledger and every task report remain in place for independent Task9 and whole-branch review.

- Ruling: Use an isolated linked worktree from a local baseline commit — the original project had no commits and every source file was untracked — cost if wrong: the extra local baseline/worktree can be removed after preserving finished changes.
- Ruling: Include all functional affordances shown in the boards, using real game data and separately produced art — user explicitly authorized screenshot features; illustrative prices/signs are not new economy requirements — cost if wrong: art or presentation choices may need revision.
- Ruling: Port the supplied SDD bookkeeping scripts to equivalent PowerShell extraction — the bundled bash lacks basename/dirname even with its normal paths — cost if wrong: task boundaries are checked against headings before dispatch.
- Ruling: Native helper raw sizes remain available to Build during shared-scale migration; full legacy chrome geometry migrates in Task 2 — prevents double scaling and keeps commits reviewable — cost if wrong: transient layout defects need correction at the next gate.
- Ruling: Quote snippets are examples to implement against the current controller, not permission to duplicate economy logic; preserve controller validation and rollback — cost if wrong: none to saved economy; UI binding may need correction.
- Ruling: Keep sound existing gameplay transactions as useful foundations, while allowing replacement of any data/model presentation that limits the redesign — no user requirement demands arbitrary price changes or live-save deletion — cost if wrong: progression may need a separate rebalance after visual review.
- Ruling: Task 1 may reuse unchanged BuildMetrics.safe_area/phone_scale instead of making an artificial edit to build_metrics.gd — spec line 87 requires reuse, which mobile_ui.gd relayout already does; corrected the brief file list — cost if wrong: a shared conversion defect would require a follow-up helper change, covered by integration tests.
- Ruling: The 64–88-unit art token governs regular object-icon/portrait slots; full scene illustrations may fill responsive scene cards — the approved welcome/map/event/upgrade/activity concepts require large scenes and the token is in the Icons row — cost if wrong: scene/card proportions need adjustment during visual review. Clarified spec and constraints; Task 2's regular portrait-slot fix remains unchanged.
- Ruling: Align every favorite interaction to the approved six care actions, replacing Biscuit's unreachable legacy bell favorite — game_content.gd names bell while no care button exposes it, and the user authorized fresh data — cost if wrong: Biscuit's chosen favorite can be changed without altering the six-button UI.
- Ruling: Task 4 fixes the standalone RoomBuilder null-world access exposed by its required blueprint suite — full baseline passed before Task 1, and the recent visibility integration must not leave SCRIPT ERROR output; guard plus focused coverage is within the app overhaul — cost if wrong: adjust the standalone visibility default in a later integration fix.
- Ruling: Allow the shared large-text header to grow to112 phone units while keeping the normal header64 — full live hotel identity, level/rooms, large wallet, income and48-unit Settings cannot fit the old80-unit region at minimum text tokens; the spec permits a separate balance line and prioritizes readable controls — cost if wrong: large-text world/detail space is32 units shorter and may require a more compact composition after final visual review. Update PhoneLayout centrally and cover shared geometry/navigation/world integration; Build keeps its separate half-height placement contract.
- Ruling: At enlarged text, Map destination details may scroll while the selected action stays pinned — the final safe-inset matrix showed the fully pinned details card overflowing the shorter space after readable header/text integration; safe bounds and reachable full-size controls take priority — cost if wrong: requirements are not continuously visible while browsing other destinations, so selection must deliberately reveal the selected hotel's live requirements with coherent focus/scroll, and the large-text flow may need refinement after visual review. Normal text retains the pinned card.
