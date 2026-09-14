# Final mobile overhaul fix evidence

Current status: all final findings resolved and independently approved at source `0ab798d40fbe7bffe7c77a12e0a277421d9f439d`. The current preview hashes and repeated-event evidence are in the final residual I4 section below. Earlier descriptions and package hashes describe the preceding consolidated-fix commit and are retained as history.

This is the implementer's complete two-stage report, archived by the controller. Three descriptions of retained residual logs have been corrected to omit wrapper exit-marker strings that were not literally present in those files; their actual PASS output and observed successful commands are unchanged. No log was edited. A subsequent full 32-suite controller run on the final source passed with no test/script failure or ObjectDB/resource warning, and its retained `tmp/final-head-full-suite.log` explicitly ends `FINAL_HEAD_FULL_SUITE_EXIT=0`.

The source, tests, gallery and preview are complete; physical Android and production release checks remain open as documented in [implementation review](implementation-review.md). [Independent verdicts](final-code-review.md) provide the review trail.

# Consolidated final fix report — playful mobile overhaul

## Status and commits

Status: complete and locally verified against all four Important and both Minor findings from `final-review.md`. The controller's scoped re-review remains pending.

- Fix base: `667ce28b40505eee2ed116831a555ce031ef4480`
- Implementation commit: `b57d364f678aad383f13834adc745da345f0542b` (`fix: synchronize final mobile live states`)
- Report: this SDD scratch file is intentionally ignored and remains available in the shared worktree; the implementation has one scoped commit.
- Branch/worktree: `codex/playful-mobile-ui` at `C:/Users/zach7/Repos/Projects/cat-hotel/.worktrees/mobile-ui`

The implementation commit contains only the scoped source, tests, implementation review and curated captures. Existing `.import` and `project.godot` line-ending/stat noise remains unstaged. Rebuilt `builds/` deliverables are intentionally ignored by the repository and verified separately below.

## Implemented findings

### I1 — passive Cats and Invitations refresh

`scripts/ui/views/cat_views.gd:12-183` gives collection totals, bond values/progress and invitation statuses stable nodes, then updates values and gates in place. It detects only actual card/action membership changes. `scripts/ui/hotel_ui.gd:102-110` uses the existing sheet refresh/restoration path only when membership changes on a life revision. This retains the selected `Met`/`To meet` filter, scroll and stable focused node. Pet remains on its separate live stage and is not included in this rebuild path.

`tests/test_mobile_views.gd:235-304` restores independent fresh fixtures, uses actual `model.advance()` passive visits and ordinary route entry, then proves a new matching cat appears in the open collection and two bonds cross the invitation gate. It checks filter, scroll and focus restoration for the membership rebuild, plus action identity, scroll and focus for the in-place invitation update.

### I2 — preference disclosure follows discovery

`scripts/ui/build_panel.gd:292-297` now requires the cat to be known, eligible and have its actual `life.state.cats[cat].preference` discovery flag before naming the preference. The neutral fallback remains until then.

`tests/test_build_mode.gd:73-87` selects a perch for fresh known Miso before interaction, checks that neither `Miso loves` nor the discovery flag appears, performs Miso's real favorite Pet controller action, and then checks the positive preference copy. It also proves furniture preview did not mutate discovery.

### I3 — live selected Build affordability and durable errors

`scripts/ui/build_panel.gd:21-22,246-255,499-526` adds a stable `BuildStatusHost`. Wallet changes rerun ghost validation and replace only the status content when the error/normal surface or message changes. The selected tray and preview remain mounted. `transaction_error` stays authoritative during incidental wallet income; existing intentional retry/cancel/recovery paths continue to clear it.

`tests/test_build_mode.gd:120-135,290-314` keeps one positioned perch ghost while crossing149/150/151 coins. It proves exact shortfall, error-to-normal surface change, confirm availability and preservation of the ghost, Adjust state, selected tray identity, scroll and focus. A genuine failed save then receives incidental income and retains its exact error node, ghost and focus. Existing Build transaction/flow/recovery suites retain controller validation, rollback, immediate save and Undo/Redo behavior.

### I4 — live Life featured gathering

`scripts/ui/views/life_views.gd:37-53,108-174,296-304` binds the featured art, event name, live status and existing Events-route action caption to the current hotel's event. Running shows remaining seconds and score; completion shows cooldown and results; available state returns to the shared Nap feature. Cooldown identity is recovered from the controller-created event memory. No claim button, reward state or second completion path was added.

`tests/test_mobile_views.gd:336-393` starts Cardboard Castle Festival through `perform_action("event", ...)`, verifies the Life card at idle, running, countdown, completion/cooldown and available-again states, and asserts the controller's first trophy/reward occurs exactly once. It checks status/action containment and the48-unit action target. At normal size it also requires the complete first Garden/Manager row. The final normal composition uses a68-unit featured scene; at150% it keeps the full identity/status/action with a24-unit optional art strip.

### M1 — upward fractional font conversion

`scripts/ui/world_activity.gd:58,129-130` and `scripts/ui/build_room_stats.gd:17,20,36` use `ceili` for already-converted canvas font sizes. No second scale is applied. `tests/test_mobile_layout.gd:118-141` instantiates the actual compact/full room-stat labels and measures their physical14/16-unit minima at the390/450 fractional phone scale; it also measures the actual WorldActivity annotation calculation.

### M2 — stable unique Scrapbook focus

`scripts/ui/views/life_views.gd:288-293` names each Visit button `JournalVisit_` plus the deterministic MD5 text of the memory entry id. `tests/test_mobile_views.gd:306-334` creates two memories for Miso with distinct ids, focuses the later displayed entry, triggers a normal life revision and verifies the same unique button and scroll offset are restored.

## TDD regression evidence

The regression assertions were added before their production changes.

- `./tools/test.ps1 -Suites test_mobile_views` was RED for the stale passive collection count/new member, stale invitation gate, missing featured Life nodes/states and duplicate/default Journal Visit names.
- `./tools/test.ps1 -Suites test_build_mode` was RED because the fresh preview exposed `Miso loves` before discovery and the positioned status stayed ready after the wallet fell below150.
- `./tools/test.ps1 -Suites test_mobile_layout` was RED for the fractional WorldActivity and compact/full BuildRoomStats minima. The first focused helper run also failed because `_annotation_font_size()` did not yet exist.

After implementing each correction, the same focused suites passed. The initial RED output was observed directly and was not promoted to a passing log; all final commands and retained logs are listed below.

## Final verification

### Focused behavioral suites

- `./tools/test.ps1 -Suites test_build_mode,test_mobile_layout,test_mobile_views` — exit0. `BUILD MODE TESTS`, `MOBILE LAYOUT TESTS` and `MOBILE VIEWS TESTS` each report `PASS (0 failures)`.
- `./tools/test.ps1 -Suites test_mobile_navigation,test_build_input,test_build_flow,test_build_recovery,test_build_transactions,test_life,test_experience` — exit0. All seven suites pass; Build transactions reports `0 failures`.
- Direct bundled-Godot `--headless --verbose --script tests/test_build_mode.gd` with isolated `.tools/final-fix-build-mode-final-profile` — exit0; `tmp/final-fix-build-mode-final.log` reports `BUILD MODE TESTS: PASS (0 failures)` with no ObjectDB/resource warning. This final fixture shutdown/drain replaced a diagnostic run that identified only one AudioStreamWAV/playback pair.

These final runs preserve the existing controller-owned purchase/save/rollback/Undo paths, actual care stage, event reward uniqueness and focused/scrolling states.

### Rendered and responsive coverage

- `./tools/test.ps1 -Rendered -Resolution 360x640 -Suites test_mobile_views` — exit0, `MOBILE VIEWS TESTS: PASS (0 failures)`. The suite exercises100/125/150%, plain and simulated-inset route states and the new running/cooldown Life states.
- `./tools/test.ps1 -Rendered -Resolution 360x640 -Suites test_mobile_navigation,test_build_mode` — exit0; both suites pass and Build exercises100/150% internally.
- `./tools/test.ps1 -Rendered -Resolution 360x640 -Suites test_mobile_walkthrough` — exit0, `MOBILE WALKTHROUGH TESTS: PASS (0 failures)`. The fresh walkthrough reports Rope scratcher140, coins `1000.050927 -> 860.050927`, Miso friendship `0 -> 6`, and an isolated `fresh-walkthrough-*` save.
- Direct `tests/test_mobile_views.gd -- --matrix-only` rendered runs with isolated profiles at390x844,430x932 and1280x800 — exit0 and `MOBILE MATRIX TESTS: PASS (0 failures)`. Logs: `tmp/final-fix-matrix-390x844.log`, `tmp/final-fix-matrix-430x932.log`, `tmp/final-fix-matrix-1280x800.log`.

The known Windows `Failed to read the root certificate store` diagnostic appears in Godot invocations and remains the previously accepted runner noise. It does not change exit status or test results.

### Captures and manifest

Affected existing gallery frames05,13-16,31 and34 were refreshed from the final integrated app. New targeted Life evidence is:

- `docs/mobile-ui-redesign/after/37-life-360x640-100-cardboard-running.png`
- `docs/mobile-ui-redesign/after/38-life-360x640-150-cardboard-running.png`
- `docs/mobile-ui-redesign/after/39-life-360x640-100-cardboard-cooldown.png`
- `docs/mobile-ui-redesign/after/40-life-360x640-150-cardboard-cooldown.png`

The targeted sources remain under `tmp/task6-featured-cardboard-*-final-360x640.png`. Native-size inspection confirms full name/status/action at both scales and the complete Garden/Manager row at normal size. Starting Life05, desktop31, enlarged/inset34, Build preview13 and Build save error16 were separately inspected and accepted. `docs/mobile-ui-redesign/after/capture-manifest.json` contains40 entries; a fresh SHA-256 audit reports `GALLERY_HASH_MISMATCHES=0`. The12 chronological `Ruling:` lines in `docs/mobile-ui-redesign/implementation-review.md` compare byte-for-text with the base and remain unchanged.

## Windows package evidence

`./tools/package.ps1` was run after the final production change and ended with `Preview ready: C:\Users\zach7\Repos\Projects\cat-hotel\.worktrees\mobile-ui\builds\windows\Play.cmd`. The package was extracted to `tmp/Final Fix Preview With Spaces 20260914`.

- `builds/windows/Play.cmd`:371 bytes; SHA-256 `FC6C8BE4BA9C2988A12C4D357B51AA7C26674E91FB378B377495AB99CB5B31D4`.
- `builds/windows/PurringtonHotel.pck`:26,967,168 bytes; SHA-256 `D84C92673522B1FCE6569BE45A3F4E0F24F244213149505A8881AD470B64FD5B`.
- `builds/PurringtonHotel-WindowsPreview.zip`:112,173,077 bytes; SHA-256 `A1B73A66AACFA9807F3310064FEDDA816A92018E85457883E12E9118109F5005`.

`tmp/final-fix-package-artifacts.json` records these artifacts. `tmp/final-fix-zip-inventory.json` confirms exactly the eight allowlisted files: `PurringtonHotel.exe`, `PurringtonHotel.pck`, `Play.cmd`, `Test expansions.cmd`, `README.txt`, `GODOT_NOTICES.txt`, `FONT_NOTICES.txt`, and `MOBILE_SDK_NOTICES.txt`. No save, profile, smoke log, test, tmp file or design document is present. The extracted PCK hash equals the source PCK hash.

The extracted-pack command used the bundled Godot runner with `--headless --quit-after 1200`, `--path` set to the directory containing spaces, `--main-pack` set to its extracted PCK and `--script` set to the source `tools/pack_smoke.gd`. APPDATA and LOCALAPPDATA were isolated under `.tools/final-fix-pack-smoke-profile-recorded`. `tmp/final-fix-package-smoke.log` reports all18 imported sources loaded, design boards excluded, the gameplay smoke passed and `PACK_SMOKE_EXIT=0`.

The normal `%LOCALAPPDATA%/Purrington Playful Preview 2026-09` directory remains absent after every automated run. `Play.cmd` still points at that separate persistent profile and `user://playful-mobile-preview-save`; no ordinary player profile was read or written.

## Self-review and concerns

Self-review covered the base-to-implementation diff, every changed source/test file, the curated manifest and native-size affected captures. `git diff --check` passes for the23-file implementation scope with only Git's CRLF conversion notices. The implementation commit contains no `.import`, `project.godot`, generated profile or package output. The gallery manifest audit passes, the ZIP allowlist and PCK parity pass, and the final verbose Build fixture is clean.

No unresolved desktop/source regression is known. Physical Android notch/gesture insets, thumb reach, pinch/pan, held-pet release, physical Back, haptics, offline resume, store billing/ads/signing and iOS delivery remain the documented external release gates. The Windows preview still uses the candidly documented Godot4.7.2 editor-capable runner because export templates are unavailable. No live purchase, consent action, publish, push or merge was performed.

## Residual I4 correction — durable completed gathering identity

Status: complete and locally verified. Narrow correction base `b57d364f678aad383f13834adc745da345f0542b`; commit `0ab798d40fbe7bffe7c77a12e0a277421d9f439d` (`fix: persist completed gathering identity`). The other five accepted final-wave fixes were unchanged.

### Correction

`scripts/core/hotel_life.gd` now gives each hotel a `last_completed_event` id, records it inside `finish_event()` at the real controller completion boundary, includes it in the existing deep state serialization and validates it during restore. Missing fields safely default to the empty identity; present ids must name a real gathering valid for that hotel. The existing `last_event` timestamp and60-second cooldown are unchanged. Trophy membership still controls the first250-Cat-Coin reward, and `memory()` retains its existing deduplication.

`scripts/ui/views/life_views.gd` reads this field during cooldown and falls back to the shared Nap feature when identity is absent. It no longer infers recency from journal order, trophy order or a UI cache.

### Regression evidence

Tests were added before the production correction.

- Direct isolated `tests/test_life.gd` RED run exited1 with six expected failures: no completion-boundary identity for Cardboard/Nap/repeated Cardboard, no per-hotel identity, no JSON persistence and no invalid-id rejection. `tmp/residual-i4-red-life.log` records `LIFE TESTS: FAIL (6 failures)`.
- Direct isolated `tests/test_mobile_views.gd` RED run exited1 with three expected failures: after Cardboard, Nap and the same-medal Cardboard completion again, the cooldown used Nap art/name and serialized no Cardboard completion identity. `tmp/residual-i4-red-mobile-views.log` records `MOBILE VIEWS TESTS: FAIL (3 failures)`.

The final deterministic model regression starts and completes Cardboard, Nap and Cardboard again through `life.perform(..., "event", ...)` and `life.advance()`, resetting only the accumulated happy score before subsequent starts so both Cardboard runs retain the same medal/memory id. It proves the third completion replaces the hotel identity with Cardboard while the two journal entries stay deduplicated, the third trophy pays no new250-coin reward, a second hotel retains an independent Beach identity, invalid ids fail atomically and missing fields default safely. A JSON round trip preserves both hotels. `tests/test_store.gd` separately writes a completed Cardboard cooldown through GameStore and reloads the identity from disk.

### Final commands and results

- `./tools/test.ps1 -Suites test_life,test_mobile_views,test_model,test_store` — exit0. `tmp/residual-i4-green-focused.log` records `LIFE TESTS: PASS (0 failures)`, `MOBILE VIEWS TESTS: PASS (0 failures)`, `MODEL TESTS: PASS (0 failures)`, `STORE TESTS: PASS (0 failures)`.
- Bundled Godot with isolated APPDATA/LOCALAPPDATA, GL Compatibility, `--resolution 360x640 --script tests/test_mobile_views.gd` — exit0. `tmp/residual-i4-rendered-360x640.log` records `MOBILE VIEWS TESTS: PASS (0 failures)`. No unchanged full matrix was repeated because layout did not change.
- `./tools/package.ps1` after the final production source — exit0. `tmp/residual-i4-package.log` ends with the successful PCK export, `Preview ready: C:\Users\zach7\Repos\Projects\cat-hotel\.worktrees\mobile-ui\builds\windows\Play.cmd`.

The known Windows root-certificate-store diagnostic appears in these Godot runs and remains accepted runner noise; every final command exited0 with no script error.

### Capture and documentation evidence

`docs/mobile-ui-redesign/after/41-life-360x640-100-cardboard-repeat-cooldown.png` is the actual third cooldown after Cardboard, Nap and same-medal Cardboard again. It shows Cardboard art/name, `Gathering complete · Ready again in 60s`, the `See results · 60s` action and the full Garden/Manager row at360x640. SHA-256 is `C7092E7B046FB233AF62C7072D38E204FBB21F1CB7EEE7ECD5C9212F02EBA410`. The controller accepted the native-size frame. The41-entry manifest has zero hash mismatches; the prior40 accurate captures remain unchanged.

`docs/mobile-ui-redesign/implementation-review.md` now records this persistence correction, targeted tests/capture, final artifact hashes and the remaining physical Android gate. Its original12 chronological ruling lines compare unchanged with the base, and the controller's new13th narrow-exception ruling remains verbatim.

### Refreshed Windows package

The archive was extracted to `tmp/Residual I4 Preview With Spaces 20260914`. `tmp/residual-i4-zip-inventory.json` records exactly the same eight allowed files, and the source/extracted PCK hashes match.

- `builds/windows/Play.cmd`:371 bytes; SHA-256 `FC6C8BE4BA9C2988A12C4D357B51AA7C26674E91FB378B377495AB99CB5B31D4`.
- `builds/windows/PurringtonHotel.pck`:26,967,152 bytes; SHA-256 `7593523A51E1CDCD41545339177D156E536033510C2AAA8A1D61419B1AC062D2`.
- `builds/PurringtonHotel-WindowsPreview.zip`:112,173,096 bytes; SHA-256 `BDCFDF6FEF3B27ACE146C0ACBEF336DC9EBFF36A4D46D5051E842DD41F2191B2`.

`tmp/residual-i4-package-artifacts.json` records the artifact inventory. The actual extracted PCK smoke used isolated `.tools/residual-i4-pack-smoke-profile`, `--path` set to the extracted directory containing spaces, `--main-pack` set to its PCK and the source `tools/pack_smoke.gd`. `tmp/residual-i4-package-smoke.log` reports all18 imported sources loaded, design boards excluded, gameplay smoke passed and `PACK_SMOKE_EXIT=0`. The normal `%LOCALAPPDATA%/Purrington Playful Preview 2026-09` directory remains absent.

### Residual self-review and concerns

Self-review covered the complete base-to-commit nine-file diff. `git diff --check` passed with only the existing CRLF conversion notices. The commit contains the two production files, three focused test files, permanent review/gallery documentation and capture41; it excludes `.import`, `project.godot`, profiles, logs and ignored package outputs. Gallery hashes,13-ruling preservation, ZIP allowlist, PCK parity and preview isolation all pass.

No residual I4 issue is known. Physical Android behavior and live store/signing/iOS delivery remain the existing external release gates. The preview still uses the documented Godot4.7.2 editor-capable runner. No live purchase, consent action, publication, push, merge or ordinary profile change occurred.
