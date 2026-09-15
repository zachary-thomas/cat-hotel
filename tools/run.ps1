param([switch]$Editor, [switch]$CommercePreview)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$godotPath = Join-Path $projectRoot '.tools\godot\Godot_v4.7.2-stable_win64.exe'
if (-not (Test-Path -LiteralPath $godotPath)) {
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if (-not $command) { $command = Get-Command godot4 -ErrorAction SilentlyContinue }
    if (-not $command) { throw 'Install Godot 4.4 or later and import project.godot, or place the portable build in .tools/godot.' }
    $godotPath = $command.Source
}
$arguments = @('--path', ('"' + $projectRoot + '"'))
if ($Editor) { $arguments += '--editor' }
if ($CommercePreview) { $arguments += @('--', '--commerce-preview') }
Start-Process -FilePath $godotPath -ArgumentList $arguments -WorkingDirectory $projectRoot -WindowStyle Hidden
