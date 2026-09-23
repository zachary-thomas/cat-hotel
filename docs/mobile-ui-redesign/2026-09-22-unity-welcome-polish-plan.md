# Unity welcome screen polish

## Goal

Bring the Unity opening screen closer to the welcome concept in `04-welcome-rewards-settings.png`: a large, welcoming hotel image, strong Purrington identity, and clear actions that remain readable on small phones.

## Plan

1. Add a text-free portrait illustration of the hotel exterior. Keep branding and buttons as live Unity UI.
2. Replace the small landscape illustration card with a full-height, aspect-preserving image. Center the phone composition on wider displays.
3. Add a warm timber-and-cream title plaque, a high-contrast subtitle ribbon, and a rounded action surface. Keep Play and Settings as native buttons with adequate touch areas.
4. Preserve the welcome → Settings → Back and welcome → Meadow flows. Hide the world camera while the full-screen welcome art is displayed, then restore it when entering the hotel.
5. Verify compilation and inspect Unity captures at 360×640 and 390×844. Check that artwork, copy, and actions remain within the safe area.
6. Animate the live UI with a brief plaque/action entrance, a gentle paw wiggle and button pulse, slow illustration drift, and small warm glints. Use unscaled time for the menu and honor the existing Animated motion setting.

## Result

- Unity implementation: `Assets/Purrington/Runtime/Presentation/HotelUI.cs`.
- Project art: `Assets/Resources/Art/welcome-exterior.png`.
- Captures: `docs/art/qa-shots/welcome-ui-360x640.png` and `docs/art/qa-shots/welcome-ui-390x844.png`.

## Verification

- The Unity presentation project compiled with no warnings or errors through `dotnet build`.
- Both portrait captures were reviewed for title, image crop, subtitle contrast, and button visibility.
- The welcome animation and its motion toggle compile with no warnings or errors. The glints do not receive input, and the illustration moves within its existing UV frame.
- The open Unity editor timed out during the final button click-through check. The Play and Settings callbacks are wired in `HotelUI.cs`, but that last live interaction check is still pending.
- The Editor also timed out while attempting a live preview after the animation change, so animation timing and appearance still need a Play mode review.

## Art provenance

Created with the built-in image generation tool as a text-free production illustration. Prompt: “A premium portrait isometric miniature cat hotel exterior for a cozy mobile game: cream plaster, moss-green tiled roofs, honey timber, glowing windows, flowering vines, stone steps, fountain, and two friendly cats at the entrance. Soft beveled voxel and polished clay style, warm morning light, calm cream sky above and quiet foreground below for live UI. No text, logo, buttons, frame, or watermark.” A second pass enlarged the cats and made the geometry more clearly voxel while preserving the composition.
