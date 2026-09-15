# Android test APK

Download the APK from [GitHub Releases](https://github.com/zachary-thomas/cat-hotel/releases). Choose the `.apk` asset; the source-code ZIP is not an installable app.

## Install on your phone

1. Open the release page on your Android phone and download `PurringtonHotel-0.1.0-test.1.apk`.
2. Open the downloaded file. If Android asks, allow **Install unknown apps** for the browser or file manager you used.
3. Tap **Install**, then open **Purrington Hotel Preview**.

Requires a 64-bit ARM Android device, Android 7.0/API 24 or newer, and OpenGL ES 3.0. This is a debug-signed test preview for sideloading. It is not a Google Play release. No live billing or advertising SDK is included in this APK.

The Android package is `com.purrington.hotel.preview`. It has its own saves. Updates built with the same signing key and an equal or higher version code can install over it and retain progress. Uninstalling clears its app data. Keep the test signing key outside source control for future updates.

## Things to try

- Pan the neighborhood, pinch to zoom, and check the lowered employee counters.
- Open Build → Land and expand the lot. Place, move, rotate and resize rooms; connect them to reception with paths or shared floor.
- Use Settings → God mode to try all maps and free construction.
- Watch cat conversations and furniture effects, then turn **Animated motion** off and confirm the scene settles while speech stays readable.
- Test at larger text sizes, background and reopen the app, and confirm your building changes remain saved.
- Check touch targets, audio, scrolling, frame rate and heat on your actual device.

## Rebuild on Windows

```powershell
.\tools\test-creative.ps1
.\tools\test.ps1
.\tools\package-android.ps1
```

The build script uses Godot 4.7.2 and its matching `android_debug.apk` export template. It detects `JAVA_HOME`, `ANDROID_HOME` / `ANDROID_SDK_ROOT`, or a Unity Android toolchain. Explicit paths are also supported:

```powershell
.\tools\package-android.ps1 `
  -GodotPath 'C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe' `
  -TemplateDirectory 'C:\Tools\Godot\export_templates\4.7.2.stable' `
  -JavaSdkPath 'C:\Tools\jdk-17' `
  -AndroidSdkPath 'C:\Tools\android-sdk' `
  -DebugKeystorePath 'C:\Private\debug.keystore' `
  -Version '0.1.0-test.2' -VersionCode 2
```

Use a standard Android debug keystore (`androiddebugkey` alias, `android` password). The script reuses Godot's local debug key when available; otherwise it creates and retains `.tools/android-signing/debug.keystore`. SDK setup is described in [Godot's Android export guide](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html).

The script copies the source into an isolated `.tools/android-build-*` folder, disables unused native commerce plugins in that copy, enables Android texture imports, and exports the **Android Test** preset. It verifies the APK signature, ARM64 architecture, package identity and launcher entry. It then runs the exact exported game resources through building, map travel, God mode, saving and reopening checks with the desktop Godot runner. These checks do not establish Android device performance or native lifecycle behavior.

Outputs are in `builds/android/`: the APK, SHA-256 checksum, build metadata, signature/manifest reports, package test logs and license notices. Build copies and signing material are ignored by Git. Build from a clean, committed source tree for a release so `build-info.json` identifies the released commit and reports no uncommitted changes.
