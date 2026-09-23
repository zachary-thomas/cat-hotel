# Main Street final-review fix wave

Worktree: `C:/Users/zach7/.codex/worktrees/main-street/cat-hotel`, branch `codex/main-street`.
FIX_BASE: `4fa1be1a81dcb4a57d38791a8084e21ddd66d896`.

This is the one authorized final-review fix wave. The original checkout was not edited.

## Fixes

1. Care wardrobe try-on copies the committed outfit and replaces the requested slot. An occupied slot cannot throw a duplicate-key exception. The regression uses the real beanie catalogue id and verifies the original head/neck outfit stays unchanged.
2. Explicit shop Leave calls transactional `LeaveTownShop`, clears saved shop identity without moving the street-door position, and hides the view only after success. Failed persistence retains the visible interior. Town suspension uses a separate view-only path, preserving a genuinely saved interior for reopening. Repeated view exits and successful travel that already cleared the shop remain safe no-ops/view cleanup.
3. The Market Day sheet retains its status label and start control. The existing model Changed/RefreshValues path updates both each real tick without rebuilding the sheet. Status distinguishes a pending hotel welcome from a delivered one.
4. The Welcome Basket completion record is a durable invitation. Newly discovered and already known Biscuit both receive a six-second hotel welcome. The already-known 40-coin reward remains the existing one-time atomic quest reward. If Biscuit is already a guest, his existing actor reacts without changing his room, route, or reservations. Otherwise a temporary welcome actor appears at safe hotel arrival space, independently of guest-room capacity. A crowded entrance postpones the welcome rather than displacing guests.
5. Each Market Day completion queues an actual hotel welcome, using an existing matching guest or temporary cat actor with speech and a happy gesture. The square board remains supplementary. Pending serials, delivered serial count, Basket acknowledgement, active scene identity, and remaining scene time survive normal save/reload. Scenes advance only while the Meadow hotel world is shown (not Town or care), and resume after interruptions. An acknowledgement is saved before the temporary actor is removed; save failure leaves delivery pending. Existing legacy completion records queue the missing welcome once. The new fields are optional in v3 saves and validated. No rooms, furniture, money, or reservations are claimed by welcome scenes.
6. Town routes always retain the actual saved start point, even within 0.001 of a node, so movement's Skip(1) cannot skip the destination and strand a near-node trip.

## Coverage and commands

Commands run in the isolated worktree with escalated filesystem permission. Unity Editor launches are sequential and guarded with `Get-Process Unity ... Path -like '*Editor*'`; the persistent Unity CLI service is not an Editor.

- `dotnet run --project tests/unity-domain -- town`: initial fixed run **195 checks**, expanded run **198 checks**, all passed.
- `dotnet run --project tests/unity-domain`: first fixed run **676256 checks**, expanded run **676262 checks**, all passed. Latest full dense 600-second simulation: 209 visits, 18 cleaned, 18 guests, 4372 ms CPU. All existing construction, Godot oracle, wardrobe, shell and navigation suites passed.
- `./tools/unity.ps1 Test`: first attempt stopped on missing `Unity.TextMeshPro` test-assembly reference. Added the required UI assembly references. Subsequent runs **98 tests, 0 failures, 0 errors, 0 skipped**. XML: `builds/unity/test-results.xml`.
- New domain assertions cover failed Leave rollback, door preservation/reload, near-node travel, new/known/already-active Biscuit, preserved reservations, interrupted and failed-acknowledgement welcomes, durable/idempotent delivery, actual Market Day actors after reload, and Basket queueing during an active Market welcome.
- Four new EditMode tests cover occupied care slot preview, Leave/suspension/reload/failed save, actual Changed-driven event label and action state after Tick, and a live rendered welcome cat that waits while Town is shown.

## Limits

The welcome is intentionally a short optional arrival/reaction, not a room booking or guaranteed long hotel stay. A crash before autosave can replay part of an unfinished welcome; the durable acknowledgement prevents completed welcomes from replaying after reload. Physical Android/iOS verification remains the existing release gate. This wave does not rerun the entire earlier multi-resolution pointer/art matrix.

Final player build, smoke result, cleanup and commit are recorded below.

## Final verification and cleanup

- Latest `./tools/unity.ps1 Test` XML: **98 tests, 0 failures, 0 errors, 0 skipped, 40.868 seconds**. After this test run, the explicit view exit gained a no-op guard for an already-hidden view or a shop already cleared by successful travel; the resulting source compiled and passed the Windows smoke check below.
- Final `dotnet run --project tests/unity-domain`: **PASS 676262 checks** (22 more than FIX_BASE). Dense simulation: 209 visits, 18 cleaned, 18 guests, 4372 ms CPU.
- `./tools/unity.ps1 Windows`: succeeded, exit 0. The first launch guard refused while the prior test Editor was briefly still exiting; it was retried only after exit. Development player: `builds/unity/Windows/PurringtonHotel.exe`.
- `./tools/unity.ps1 QA`: succeeded, exit 0, **PASS: startup, orthographic camera, navigation, care stage, panel bounds, wheel zoom, layouts, save**. Smoke output is under `builds/unity/captures`; new screenshots were not claimed as a new full art review.
- `git -c safe.directory=C:/Users/zach7/.codex/worktrees/main-street/cat-hotel diff --check`: passed.
- Inspected and restored incidental font/URP/Graphics/EditorBuildSettings serialization and the build-generated APP_UI_EDITOR_ONLY define. No generated builds are committed.
- No unresolved final-review finding, no new PR, and no merge. The parent owns the final independent review.
