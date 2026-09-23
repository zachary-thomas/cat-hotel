param(
    [ValidateSet('ping','refresh','meadow','test','build','capture','play','stop')][string]$Action='ping',
    [string]$Filter='',          # test: a namespace or class name to run only those tests
    [string]$Tab='',             # capture: Hotel, Cats, Build, Life or Map
    [double]$Minute=-1,          # capture: pin the lighting to this minute of the day (e.g. 750 noon, 1380 night)
    [double]$Wait=4,             # capture: seconds in Play mode before the shot
    [int]$Timeout=900
)
# Drives the Unity Editor that is already open (see Assets/Purrington/Editor/EditorBridge.cs), so it never has to be closed.
$ErrorActionPreference='Stop'
$bridge=Join-Path (Split-Path -Parent $PSScriptRoot) 'unity/PurringtonHotel/Temp/ClaudeBridge'
$alive=Join-Path $bridge 'alive'
if (-not (Test-Path -LiteralPath $alive) -or ((Get-Date).ToUniversalTime()-[datetime]::Parse((Get-Content -LiteralPath $alive -Raw).Trim()).ToUniversalTime()).TotalSeconds -gt 20) {
    Write-Output 'The Unity Editor bridge is not running. Open the project in Unity (tools/unity.ps1 Open) and let it finish importing.'
    exit 3
}
$id=[guid]::NewGuid().ToString('N')
$response=Join-Path $bridge 'response.json'
if (Test-Path -LiteralPath $response) { Remove-Item -LiteralPath $response -Force }
$body=@{id=$id;action=$Action;filter=$Filter;tab=$Tab;minute=$Minute;wait=$Wait} | ConvertTo-Json -Compress
$temp=Join-Path $bridge 'request.tmp'
Set-Content -LiteralPath $temp -Value $body -Encoding utf8
Move-Item -LiteralPath $temp -Destination (Join-Path $bridge 'request.json') -Force
$deadline=(Get-Date).AddSeconds($Timeout)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 400
    if (-not (Test-Path -LiteralPath $response)) { continue }
    try { $result=Get-Content -LiteralPath $response -Raw | ConvertFrom-Json } catch { continue }
    if ($result.id -ne $id) { continue }
    Write-Output ("{0}: {1}" -f $result.status.ToUpper(),$result.message)
    if ($result.file) { Write-Output ("Screenshot: {0}" -f $result.file) }
    foreach ($failure in $result.failures) { Write-Output ("  - {0}" -f $failure) }
    if ($result.status -eq 'ok') { exit 0 } else { exit 1 }
}
Write-Output "No reply from the Editor within $Timeout seconds. Is a modal dialog open in Unity?"
exit 2
