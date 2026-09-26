param(
    [string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { 'godot' }),
    [switch]$Zip
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildDir = Join-Path $projectRoot 'dist/ModernCapitalism-Windows'
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
& $Godot --headless --path $projectRoot --export-release 'Windows Desktop' (Join-Path $buildDir 'ModernCapitalism.exe')
if ($LASTEXITCODE -ne 0) { throw "Godot export failed ($LASTEXITCODE). Install matching export templates in the Godot editor." }
if (-not (Test-Path -LiteralPath (Join-Path $buildDir 'ModernCapitalism.exe'))) { throw 'No Windows executable produced.' }
if ($Zip) {
    Compress-Archive -Path (Join-Path $buildDir '*') -DestinationPath (Join-Path $projectRoot 'dist/ModernCapitalism-Windows.zip') -Force
}
Write-Output "Build ready: $buildDir"
