param([string]$Godot = 'Godot_v4.7.2-stable_win64_console.exe')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
# Editor import registers global GDScript classes on a fresh checkout.
$importOutput = & $Godot --headless --path $projectRoot --editor --quit 2>&1
$importExit = $LASTEXITCODE
if ($importExit -ne 0 -or ($importOutput -match 'SCRIPT ERROR:|Parse Error:')) {
    $importOutput | ForEach-Object { Write-Host $_ }
    exit 1
}
$logPath = Join-Path $projectRoot '.godot/test-run.log'
$testOutput = & $Godot --headless --path $projectRoot --log-file $logPath --script res://tests/run_tests.gd 2>&1
$testExit = $LASTEXITCODE
$testOutput | ForEach-Object { Write-Host $_ }
# Godot can return zero after a runtime script error: inspect output as well.
if ($testExit -ne 0 -or ($testOutput -match 'SCRIPT ERROR:|Parse Error:|FAIL:') -or -not ($testOutput -match 'TEST RESULT: \d+ checks, 0 failures')) {
    exit 1
}
exit 0
