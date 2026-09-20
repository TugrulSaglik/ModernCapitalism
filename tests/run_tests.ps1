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
$m2Output = & $Godot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot/m2-tests.log') --script res://tests/milestone2_tests.gd 2>&1
$m2Exit = $LASTEXITCODE
$m2Output | ForEach-Object { Write-Host $_ }
if ($m2Exit -ne 0 -or ($m2Output -match 'SCRIPT ERROR:|Parse Error:|FAIL:') -or -not ($m2Output -match 'M2 TEST RESULT: \d+ checks, 0 failures')) {
    exit 1
}
$smokeOutput = & $Godot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot/game-smoke.log') --script res://tests/game_smoke.gd 2>&1
$smokeExit = $LASTEXITCODE
$smokeOutput | ForEach-Object { Write-Host $_ }
if ($smokeExit -ne 0 -or ($smokeOutput -match 'SCRIPT ERROR:|Parse Error:|FAIL:') -or -not ($smokeOutput -match 'GAME SMOKE RESULT: \d+ checks, 0 failures')) {
    exit 1
}
$debugOutput = & $Godot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.godot/debug-smoke.log') --script res://tests/debug_smoke.gd 2>&1
$debugExit = $LASTEXITCODE
$debugOutput | ForEach-Object { Write-Host $_ }
if ($debugExit -ne 0 -or ($debugOutput -match 'SCRIPT ERROR:|Parse Error:|FAIL:') -or -not ($debugOutput -match 'DEBUG SMOKE: scene loaded and advanced 30 days successfully')) {
    exit 1
}
foreach ($suite in @(
    @{ Script = 'milestone3_tests.gd'; Marker = 'M3 TEST RESULT' },
    @{ Script = 'construction_smoke.gd'; Marker = 'M3 VISUAL RESULT' },
    @{ Script = 'milestone4_tests.gd'; Marker = 'M4 TEST RESULT' },
    @{ Script = 'logistics_smoke.gd'; Marker = 'M4 VISUAL RESULT' },
    @{ Script = 'milestone5_tests.gd'; Marker = 'M5 TEST RESULT' },
    @{ Script = 'city_smoke.gd'; Marker = 'M5 VISUAL RESULT' },
    @{ Script = 'milestone6_tests.gd'; Marker = 'M6 TEST RESULT' },
    @{ Script = 'market_smoke.gd'; Marker = 'M6 VISUAL RESULT' },
    @{ Script = 'milestone7a_tests.gd'; Marker = 'M7A TEST RESULT' },
    @{ Script = 'research_smoke.gd'; Marker = 'M7A VISUAL RESULT' },
    @{ Script = 'milestone7b1_tests.gd'; Marker = 'M7B1 TEST RESULT' },
    @{ Script = 'quality_smoke.gd'; Marker = 'M7B1 VISUAL RESULT' },
    @{ Script = 'milestone7b2_tests.gd'; Marker = 'M7B2 TEST RESULT' },
    @{ Script = 'local_market_smoke.gd'; Marker = 'M7B2 VISUAL RESULT' },
    @{ Script = 'milestone7b3a_tests.gd'; Marker = 'M7B3A TEST RESULT' },
    @{ Script = 'quality_research_smoke.gd'; Marker = 'M7B3A VISUAL RESULT' }
)) {
    $suiteOutput = & $Godot --headless --path $projectRoot --log-file (Join-Path $projectRoot ('.godot/' + $suite.Script + '.log')) --script ('res://tests/' + $suite.Script) 2>&1
    $suiteExit = $LASTEXITCODE
    $suiteOutput | ForEach-Object { Write-Host $_ }
    if ($suiteExit -ne 0 -or ($suiteOutput -match 'SCRIPT ERROR:|Parse Error:|FAIL:') -or -not ($suiteOutput -match ($suite.Marker + ': \d+ checks, 0 failures'))) {
        exit 1
    }
}
exit 0
