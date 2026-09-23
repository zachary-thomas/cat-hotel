# Purrington Hotel: agent guide

## Engine: Unity only

**All new work goes into Unity: `unity/PurringtonHotel`, Unity 6000.3.24f1 LTS.** The Godot project at the repository root (`project.godot`, `scenes/`, `scripts/`, `addons/`, `tests/*.gd`, `tools/*.gd`) is legacy. It is kept only as the behavior and art reference for parity. Do not add features to it or fix bugs in it. Read it when you need to know how something originally worked.

`Assets/Resources/Content/GodotReference.json` and `GodotGeometry.json` are exported from the Godot game and drive Unity content. Treat them as source data: extend them through new Unity-side content files rather than re-exporting from Godot.

## Layout

- `unity/PurringtonHotel/Assets/Purrington/Runtime/Domain`: plain C# hotel model (state, commands, validation, navigation, life simulation, saves). No UnityEngine references.
- `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation`: `HotelApp`, the voxel world, uGUI/TextMeshPro UI, input and audio.
- `unity/PurringtonHotel/Assets/Purrington/Tests/EditMode`: NUnit EditMode tests.
- `tests/unity-domain`: a .NET 9 console harness that compiles the Domain folder directly. It is the fast way to test domain changes.
- `docs/superpowers/specs` and `docs/superpowers/plans`: current designs and implementation plans. Start with the [hotel-growth roadmap](docs/superpowers/plans/2026-09-22-hotel-growth-00-roadmap.md).

## Commands (run from the repo root)

```bash
dotnet run --project tests/unity-domain
```
Domain tests, about a minute, no Unity needed. The final line must be `PASS <n> checks`.

```powershell
.\tools\unity.ps1 Test      # Unity EditMode tests -> builds/unity/test-results.xml
.\tools\unity.ps1 Windows   # Windows preview build
.\tools\unity.ps1 QA        # automated smoke captures of the built preview
```

With the Unity Editor open, `Test` and `Windows` run inside it automatically, so the project never has to be closed. You can also drive the open Editor directly:

```powershell
.\tools\unity-bridge.ps1 test [-Filter ClassName]          # EditMode tests in the open Editor
.\tools\unity-bridge.ps1 capture -Tab Life [-Minute 1380]   # Play, screenshot the Game view -> builds/unity/editor-captures
.\tools\unity-bridge.ps1 capture -Filter pop               # same, with an income pop shown just before the shot
.\tools\unity-bridge.ps1 meadow                            # open the Meadow scene with the hotel shown in the Scene view
.\tools\unity-bridge.ps1 render -Map 2 -Exterior -Zoom 2   # render any destination off screen, no Play mode, save untouched
.\tools\unity-bridge.ps1 refresh | build | play | stop | ping
```

## Conventions

- Existing C# files use dense one-line members. Match the surrounding style when editing them.
- Build actions are `HotelModel.Execute(action, JObject)` commands with a matching `Quote` preview. They are transactional: they save or roll back, and support 20-step Undo.
- Save changes need `StrictSaveJson`, `HotelModel.Valid` and migration updates, plus a domain test.
- The "Godot oracle" section of the domain harness guards parity. Never edit it just to make a change pass.
