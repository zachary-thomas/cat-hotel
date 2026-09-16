# Sunlit surface stripes

The creative world's directional light used a normal bias of 0.35. With the
Compatibility renderer, this produced dense self-shadow stripes on lit turf,
walls and foliage. Increasing only the normal bias to 1.5 removes the reproduced
pattern while retaining cast shadows, the existing materials and depth bias.
Godot describes this artifact and the normal-bias correction in its
[lighting documentation](https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html#tweaking-shadow-bias).

## Verification

- `tools/test-creative.ps1 -Rendered -Suites test_creative_lighting` measures
  adjacent-pixel luminance variation on empty sunlit lawn and verifies that a
  tree's cast shadow remains visible. The old setting measured 0.041550 and
  failed the 0.008 limit; the corrected setting measured 0.000000 and passed.
- Rendered close and far views of all four maps using desktop OpenGL Compatibility.
- World, voxel polish, counter/camera and neighborhood regression suites passed.
- Built `builds/android/PurringtonHotel-0.1.0-test.2.apk` with version code 2 and
  the existing preview signing key. Signature, manifest, exported-resource
  gameplay and save/reopen checks passed.

This is a local APK build, not a published release. No physical Android device
was connected; phone rendering still needs confirmation. The rendered regression
is separate from the default headless suites because it needs a graphics device.
