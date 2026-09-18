# Purrington Hotel — Unity migration

**Non-negotiable: Purrington remains a voxel 3D, orthographic isometric cat-hotel tycoon.** Cats, furnishings, architecture, gardens, and neighborhood scenery retain block-built silhouettes. Better lighting, materials, animation, and UI must reinforce that identity. This is not a switch to a flat 2D game, perspective camera, or smooth character art.

The Unity project lives at [`unity/PurringtonHotel`](../../unity/PurringtonHotel). Android and iOS are the product targets; Windows is the main development and QA platform. Preserve the existing Godot project, launchers, saves, and tests as the migration reference.

## Start here

- [Implementation plan and staged parity backlog](IMPLEMENTATION-PLAN.md)
- [Acceptance and verification checklist](QA.md)
- [Current Godot game guide](../creative-preview/README.md)
- [Current reference captures](../creative-preview/neighborhood-polish/README.md)

The first Unity milestone is a complete Meadow loop: welcome a cat, earn Cat Coins, furnish a room, care for the cat, and save and resume. Later milestones restore the full creative game's construction, hotel life, and destinations.

## Project decisions

| Area | Decision |
|---|---|
| Engine | Installed and pinned 6000.3.24f1 LTS |
| Rendering | URP, 3D voxel geometry, orthographic isometric camera, mobile quality settings |
| UI | Native uGUI/TextMeshPro; bright toy-like controls over the voxel world |
| Platforms | Android/iOS first; Windows preview and QA; macOS/Xcode for final iOS compilation/signing |
| Saves | Fresh Unity saves under a separate application identity; no automatic Godot import |
| Commerce | No live billing, advertising, accounts, or cloud saves in this migration slice |
| Reference | `scripts/creative` and `tests/test_creative_*`; retained legacy scenes are not the parity target |

## Implementation status

The Unity project and runtime source now exist. They include a procedural voxel Meadow, orthographic camera, mobile uGUI navigation/catalogue/care, room and furniture editing/storage, basic hotel income, and fresh journaled saves. This is the first migration slice, not full parity with the current Godot game.

The project is upgraded to installed **Unity 6000.3.24f1 LTS**, including Unity-managed rendering, input, and test package upgrades.

Configuration and the **Windows development build succeeded** on Unity 6.3. **13 Unity EditMode tests passed** with no failures or errors. A programmatic runtime smoke check passed startup, orthographic camera, navigation, care stage, layouts, and save, producing 18 captures without exceptions. This is not an actual pointer-driven or physical-device walkthrough. Representative [screenshots and test results](evidence/README.md) are retained in the docs.

An independent .NET harness also reported **97 domain assertions passed**; that remains separate from Unity testing. An Android development APK build succeeded (approximately 94 MB); no device or iOS result is claimed. The existing APK was built with 6.0 and predates the 6.3 zoom/layout update. Milestones 1 and 2 remain open for complete interaction/layout acceptance, and remaining first-slice behavior. See [QA.md](QA.md) for the evidence boundary.

## Commands

Run from the repository root with the official Unity CLI installed. These are supported commands, not a claim that their outputs have already passed validation.

```powershell
.\tools\unity.ps1 Open       # Open the pinned Unity project
.\tools\unity.ps1 Configure  # Generate runtime scenes, content, fonts, and setup assets
.\tools\unity.ps1 Test       # Run Unity EditMode tests
.\tools\unity.ps1 Windows    # Build the Windows preview
.\tools\unity.ps1 Android    # Build a development APK; Android module required
.\tools\unity.ps1 iOS        # Export an Xcode project; iOS module required
.\tools\unity.ps1 Play       # Launch an already-built Windows preview
```

`Play` requires a successful Windows build first. Test output is written to `builds/unity/test-results.xml`; Windows output is `builds/unity/Windows/PurringtonHotel.exe`. Final iOS compilation/signing requires macOS/Xcode. See the [project README](../../unity/PurringtonHotel/README.md) for architecture and current simplifications.

Opening or building the Unity project must not replace the existing Godot entrypoint. Use the Unity project's pinned editor version. Keep generated Library, Temp, Logs, and build output out of version control; commit asset metadata and resolved package versions.

Existing portraits, Fredoka/Nunito fonts, and audio may be reused with their license notices. Godot-specific geometry and shaders need Unity implementations. Original asset notices remain applicable.
