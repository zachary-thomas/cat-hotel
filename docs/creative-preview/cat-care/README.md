# Hands-on cat care

Tap a visible guest in Hotel, or a known cat in Cats, to open the care room. Pet and Brush work over the cat's body; touching the room background does not award affectionate care. Feather and Yarn follow finger or mouse movement. Cushion and Box are offered by tapping the room. The **Use selected tool** button supports keyboard and single-action play.

## Screenshots

- [Petting in Meadow](petting-phone.png)
- [Brushing at 150% text on a small phone](brushing-small-phone.png)
- [Snowcap room on desktop](snowcap-desktop.png)

## Behavior

The scene preserves each cat's identity and coat and uses one of four staged hotel themes. It does not duplicate the guest's assigned furniture or alter hotel reservations. The existing collection portraits remain unchanged.

Friendship keeps its existing 12-second cooldown, 3-point normal reward, 6-point favorite reward and 100-point maximum. Gestures and purring continue during the cooldown; only changed progress is saved. Failed saves roll back progress while keeping the care screen open. Back restores the originating collection scroll or hotel camera.

The six tools share one active pointer. Leaving the scene, release outside the scene, canceled touches, opening details, backgrounding and focus loss stop affectionate contact. Purring fades on release and stops immediately on screen exit, mute or backgrounding. Animated motion off gives steady poses and disables particles and automatic toy movement.

## Verification

New suites: `test_creative_care_state` and `test_creative_care`. They cover actual touch/mouse/keyboard input, all six tools, all 18 identities, duplicate input prevention, shadow/background misses, toy bounds, known absent cats, hotel tap/pan separation, staff/hidden/roof exclusions, navigation, save rollback, unchanged-save avoidance, audio cleanup and reduced motion.

The care integration suite checks 360×640, 390×844 and 1280×800 at 100% and 150% text in all four themes, plus phone safe-area insets. Rendered verification uses the Godot Compatibility renderer. Generated full layout captures stay in ignored `tmp/care-captures`; the selected images above are retained for review.

Relevant existing creative UI, app, menu scrolling, world, gesture, life, model and save-integrity suites pass, as do shared audio and legacy mobile-view regressions. Tests use isolated profiles and temporary saves.

Physical Android touch, speaker quality, interruptions and device performance still need a device pass. Android test.4 packages this feature together with the lighting and menu-scrolling fixes.

### Reproduce

```powershell
.\tools\test-creative.ps1 -Suites test_creative_care_state,test_creative_care
.\tools\test-creative.ps1 -Rendered -Suites test_creative_care
```

For all 24 layout PNGs, run the care suite with `--capture-care` after Godot's `--` separator and an isolated test profile.
