param(
    [string]$GodotPath,
    [string]$AndroidSdkPath = $env:ANDROID_HOME,
    [string]$JavaSdkPath = $env:JAVA_HOME,
    [string]$TemplateDirectory,
    [string]$DebugKeystorePath,
    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+[-.a-zA-Z0-9]*$')][string]$Version = '0.1.0-test.1',
    [ValidateRange(1,2100000000)][int]$VersionCode = 1
)
$ErrorActionPreference = 'Stop'
$androidRoot = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) { $GodotPath = Join-Path $androidRoot '.tools/godot/Godot_v4.7.2-stable_win64_console.exe' }
if (-not $AndroidSdkPath) { $AndroidSdkPath = $env:ANDROID_SDK_ROOT }
if (-not $TemplateDirectory) { $TemplateDirectory = Join-Path $env:APPDATA 'Godot/export_templates/4.7.2.stable' }
if (-not $DebugKeystorePath) { $DebugKeystorePath = Join-Path $env:APPDATA 'Godot/keystores/debug.keystore' }

# Reuse locally installed tools, including Unity's standard Android toolchain.
$androidUnityRoot = 'C:/Program Files/Unity/Hub/Editor'
if ((-not $AndroidSdkPath -or -not $JavaSdkPath) -and (Test-Path -LiteralPath $androidUnityRoot)) {
    foreach ($editor in Get-ChildItem -LiteralPath $androidUnityRoot -Directory | Sort-Object Name -Descending) {
        $player = Join-Path $editor.FullName 'Editor/Data/PlaybackEngines/AndroidPlayer'
        if (-not $AndroidSdkPath -and (Test-Path -LiteralPath "$player/SDK/platform-tools/adb.exe")) { $AndroidSdkPath = "$player/SDK" }
        if (-not $JavaSdkPath -and (Test-Path -LiteralPath "$player/OpenJDK/bin/java.exe")) { $JavaSdkPath = "$player/OpenJDK" }
    }
}
if (-not $AndroidSdkPath -or -not $JavaSdkPath) { throw 'Provide -AndroidSdkPath and -JavaSdkPath (OpenJDK 17 or later).' }
$androidTemplate = Join-Path $TemplateDirectory 'android_debug.apk'
foreach ($required in @($GodotPath, $androidTemplate, "$JavaSdkPath/bin/java.exe", "$AndroidSdkPath/platform-tools/adb.exe")) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required Android build file is missing: $required" }
}
$androidBuildTools = Get-ChildItem -LiteralPath "$AndroidSdkPath/build-tools" -Directory |
    Where-Object { (Test-Path -LiteralPath "$($_.FullName)/apksigner.bat") -and (Test-Path -LiteralPath "$($_.FullName)/aapt.exe") } |
    Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
if (-not $androidBuildTools) { throw 'Android SDK build-tools with apksigner and aapt are required.' }

$androidGitRoot = $androidRoot.Replace('\','/')
$androidCommit = & git -c "safe.directory=$androidGitRoot" -C $androidRoot rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Could not identify the source commit.' }
$androidSourceStatus = @(& git -c "safe.directory=$androidGitRoot" -C $androidRoot status --porcelain)
if ($LASTEXITCODE -ne 0) { throw 'Could not check the source tree.' }
$androidDirty = $androidSourceStatus.Count -gt 0
$androidRun = Join-Path $androidRoot ('.tools/android-build-' + [guid]::NewGuid().ToString('N'))
$androidSource = Join-Path $androidRun 'source'
$androidProfile = Join-Path $androidRun 'profile'
$androidDestination = Join-Path $androidRoot 'builds/android'
New-Item -ItemType Directory -Path $androidSource,"$androidProfile/Godot",$androidDestination -Force | Out-Null
foreach ($directory in @('assets','scripts','scenes')) {
    Copy-Item -LiteralPath (Join-Path $androidRoot $directory) -Destination $androidSource -Recurse
}
foreach ($file in @('project.godot','export_presets.cfg','commerce.cfg')) {
    Copy-Item -LiteralPath (Join-Path $androidRoot $file) -Destination $androidSource
}
# Disable editor plugins before the first import of this isolated source copy.
$androidProjectPath = Join-Path $androidSource 'project.godot'
$androidProjectText = Get-Content -LiteralPath $androidProjectPath -Raw
$androidProjectText = [regex]::Replace($androidProjectText, '(?ms)^\[editor_plugins\]\s*.*?(?=^\[|\z)', '')
$androidProjectText = [regex]::Replace($androidProjectText, '(?m)^locale/translations=.*addons/.*\r?\n', '')
Set-Content -LiteralPath $androidProjectPath -Value $androidProjectText -Encoding utf8

$androidEnvironmentNames = @('APPDATA','LOCALAPPDATA','JAVA_HOME','GODOT_ANDROID_KEYSTORE_DEBUG_PATH','GODOT_ANDROID_KEYSTORE_DEBUG_USER','GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD')
$androidOldEnvironment = @{}
foreach ($name in $androidEnvironmentNames) { $androidOldEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
try {
    $env:JAVA_HOME = $JavaSdkPath
    if (-not (Test-Path -LiteralPath $DebugKeystorePath)) {
        $DebugKeystorePath = Join-Path $androidRoot '.tools/android-signing/debug.keystore'
        if (-not (Test-Path -LiteralPath $DebugKeystorePath)) {
            New-Item -ItemType Directory -Path (Split-Path -Parent $DebugKeystorePath) -Force | Out-Null
            & "$JavaSdkPath/bin/keytool.exe" -genkeypair -keystore $DebugKeystorePath -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname 'CN=Android Debug,O=Android,C=US'
            if ($LASTEXITCODE -ne 0) { throw 'Could not create the persistent local test signing key.' }
        }
    }
    $env:APPDATA = $androidProfile
    $env:LOCALAPPDATA = $androidProfile
    $env:GODOT_ANDROID_KEYSTORE_DEBUG_PATH = $DebugKeystorePath
    $env:GODOT_ANDROID_KEYSTORE_DEBUG_USER = 'androiddebugkey'
    $env:GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD = 'android'
    $androidEngineVersion = (& $GodotPath --version | Select-Object -Last 1).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Could not determine Godot version.' }
    $androidTemplateVersionFile = Join-Path $TemplateDirectory 'version.txt'
    if (Test-Path -LiteralPath $androidTemplateVersionFile) {
        $androidTemplateVersion = (Get-Content -LiteralPath $androidTemplateVersionFile -Raw).Trim()
        if (-not $androidEngineVersion.StartsWith($androidTemplateVersion + '.')) { throw 'Godot and Android export template versions must match.' }
    }
    $androidEditorVersion = ($androidEngineVersion -split '\.')[0..1] -join '.'
    @"
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$($AndroidSdkPath.Replace('\','/'))"
export/android/java_sdk_path = "$($JavaSdkPath.Replace('\','/'))"
export/android/debug_keystore = "$($DebugKeystorePath.Replace('\','/'))"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
"@ | Set-Content -LiteralPath "$androidProfile/Godot/editor_settings-$androidEditorVersion.tres" -Encoding utf8

    function Invoke-AndroidGodot([string]$Step, [string[]]$Arguments) {
        $output = & $GodotPath @Arguments 2>&1
        $result = $LASTEXITCODE
        $output | Set-Content -LiteralPath (Join-Path $androidRun "$Step.log") -Encoding utf8
        if ($result -ne 0 -or ($output -join "`n") -match 'SCRIPT ERROR:|ERROR:') {
            $output | Write-Output
            throw "$Step failed; see $androidRun/$Step.log"
        }
        Write-Output "$Step passed"
    }
    Invoke-AndroidGodot 'configure' @('--headless','--path',$androidSource,'--script',"$PSScriptRoot/configure-android-test.gd",'--',$androidTemplate,$Version,"$VersionCode")
    Invoke-AndroidGodot 'import' @('--headless','--path',$androidSource,'--editor','--import')
    $androidApk = Join-Path $androidDestination "PurringtonHotel-$Version.apk"
    Invoke-AndroidGodot 'export' @('--headless','--path',$androidSource,'--export-debug','Android Test',$androidApk)
    $signature = & "$($androidBuildTools.FullName)/apksigner.bat" verify --verbose --print-certs $androidApk 2>&1
    if ($LASTEXITCODE -ne 0) { throw "APK signature verification failed: $signature" }
    $signature | Set-Content -LiteralPath "$androidDestination/signature-verification.txt" -Encoding utf8
    $badging = & "$($androidBuildTools.FullName)/aapt.exe" dump badging $androidApk 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect the APK manifest.' }
    $badging | Set-Content -LiteralPath "$androidDestination/apk-manifest.txt" -Encoding utf8
    if (($badging -join "`n") -notmatch "package: name='com.purrington.hotel.preview'" -or ($badging -join "`n") -notmatch "native-code: 'arm64-v8a'") {
        throw 'APK identity or ARM64 architecture does not match the test preset.'
    }
    $manifest = & "$($androidBuildTools.FullName)/aapt.exe" dump xmltree $androidApk AndroidManifest.xml 2>&1
    if ($LASTEXITCODE -ne 0 -or ($manifest -join "`n") -notmatch 'android.intent.category.LAUNCHER') {
        throw 'APK does not declare an Android launcher entry.'
    }
    # Exercise the exact exported scripts/resources inside the APK. This tests
    # package completeness and save/reopen behavior on the desktop Godot runner;
    # physical Android performance and lifecycle testing is still required.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $androidExtracted = Join-Path $androidRun 'apk-content'
    [IO.Compression.ZipFile]::ExtractToDirectory($androidApk, $androidExtracted)
    foreach ($mode in @('write','reopen')) {
        $smokeArgs = @('--headless','--path',"$androidExtracted/assets",'--script',"$PSScriptRoot/creative_pack_smoke.gd",'--','--android-package')
        if ($mode -eq 'reopen') { $smokeArgs += '--verify-reopen' }
        Invoke-AndroidGodot "package-$mode" $smokeArgs
        if ((Get-Content -LiteralPath "$androidRun/package-$mode.log" -Raw) -notmatch 'CREATIVE PACK: 0 failures') {
            throw "APK content $mode test did not complete."
        }
        Copy-Item -LiteralPath "$androidRun/package-$mode.log" -Destination "$androidDestination/package-$mode.txt" -Force
    }
    $androidHash = (Get-FileHash -LiteralPath $androidApk -Algorithm SHA256).Hash.ToLowerInvariant()
    "$androidHash  $(Split-Path -Leaf $androidApk)" | Set-Content -LiteralPath "$androidApk.sha256" -Encoding ascii
    Copy-Item -LiteralPath "$androidSource/assets/licenses/GODOT_NOTICES.txt" -Destination $androidDestination -Force
    Get-ChildItem -LiteralPath "$androidSource/assets/fonts" -Filter '*-OFL.txt' | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $androidDestination -Force
    }
    $androidEndCommit = & git -c "safe.directory=$androidGitRoot" -C $androidRoot rev-parse HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Could not recheck the source commit.' }
    $androidEndStatus = @(& git -c "safe.directory=$androidGitRoot" -C $androidRoot status --porcelain)
    if ($LASTEXITCODE -ne 0) { throw 'Could not recheck the source tree.' }
    if (-not $androidDirty -and ($androidEndCommit -ne $androidCommit -or $androidEndStatus.Count -gt 0)) {
        throw 'The committed source changed during the APK build. Rebuild after other work has finished.'
    }
    [ordered]@{
        version = $Version; versionCode = $VersionCode; package = 'com.purrington.hotel.preview'
        engine = $androidEngineVersion; sourceCommit = $androidCommit; sourceHasUncommittedChanges = $androidDirty
        architecture = 'arm64-v8a'; signing = 'debug'; sha256 = $androidHash
        builtAtUtc = [DateTime]::UtcNow.ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath "$androidDestination/build-info.json" -Encoding utf8
    Write-Output "Verified Android test APK: $androidApk"
} finally {
    foreach ($name in $androidEnvironmentNames) { [Environment]::SetEnvironmentVariable($name, $androidOldEnvironment[$name], 'Process') }
}
