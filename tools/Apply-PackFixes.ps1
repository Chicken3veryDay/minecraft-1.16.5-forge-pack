[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$PackRoot = Split-Path -Parent $PSScriptRoot
$ClientDir = Join-Path $PackRoot 'Client'
$ServerDir = Join-Path $PackRoot 'Server'
$BackupDir = Join-Path $PackRoot '_InstallCache\pack-fix-backups'
$CurseForgeCache = Join-Path $PackRoot '_InstallCache\CurseForge'

$serverRequiredClientMods = @(
    'AI-Improvements-1.16.5-0.5.0.jar',
    'chunksending-1.16.5-2.5.jar',
    'Chunky-1.2.123.jar',
    'connectivity-2.3-1.16.5.jar',
    'FastFurnace-1.16.5-4.5.0.jar',
    'FastSuite-1.16.4-1.1.1.jar',
    'FastWorkbench-1.16.5-4.6.2.jar',
    'letmedespawn-forge-1.3.2b.jar',
    'smoothchunk1.16.5-2.0.jar',
    'spark-1.9.1-forge.jar',
    'treeharvester_1.16.5-5.9.jar'
)

$clientRequiredServerMods = @(
    'inventorysorter-1.16.1-18.1.0.jar'
)

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Move-ToBackupIfPresent {
    param(
        [string]$Path,
        [string]$Reason
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    Ensure-Directory -Path $BackupDir
    $leaf = Split-Path -Leaf $Path
    $parent = Split-Path -Leaf (Split-Path -Parent $Path)
    $stamp = Get-Date -Format yyyyMMdd-HHmmss
    $target = Join-Path $BackupDir "$stamp-$Reason-$parent-$leaf"
    Move-Item -LiteralPath $Path -Destination $target -Force
    Write-Host "Moved $leaf to $target"
}

function Copy-RequiredJar {
    param(
        [string]$Source,
        [string]$DestinationDir
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        throw "Missing required jar: $Source"
    }

    Copy-Item -LiteralPath $Source -Destination (Join-Path $DestinationDir (Split-Path -Leaf $Source)) -Force
}

# Forge's server compatibility warning was previously hidden by this client-only
# mod. Keep the actual required jars in Client instead so everyone receives the
# same playable pack through the minimal installer.
Move-ToBackupIfPresent -Path (Join-Path $ClientDir 'MyServerIsCompatible-1.16.5-1.0.jar') -Reason 'removed-client-compat-hack'

foreach ($name in $serverRequiredClientMods) {
    Copy-RequiredJar -Source (Join-Path $ServerDir $name) -DestinationDir $ClientDir
}

foreach ($name in $clientRequiredServerMods) {
    Copy-RequiredJar -Source (Join-Path $ClientDir $name) -DestinationDir $ServerDir
}

$mowzieNew = Join-Path $CurseForgeCache 'mowziesmobs-1.5.27.jar'
$needsMowzieSource = $false
foreach ($folder in @($ClientDir, $ServerDir)) {
    if ((Test-Path -LiteralPath (Join-Path $folder 'mowziesmobs-1.5.25.jar')) -or
        -not (Test-Path -LiteralPath (Join-Path $folder 'mowziesmobs-1.5.27.jar'))) {
        $needsMowzieSource = $true
    }
}

if ($needsMowzieSource -and -not (Test-Path -LiteralPath $mowzieNew)) {
    throw "Missing Mowzie's Mobs 1.5.27 cache jar: $mowzieNew"
}

foreach ($folder in @($ClientDir, $ServerDir)) {
    Move-ToBackupIfPresent -Path (Join-Path $folder 'mowziesmobs-1.5.25.jar') -Reason 'mowzie-geckolib-crash'
    if ($needsMowzieSource) {
        Copy-RequiredJar -Source $mowzieNew -DestinationDir $folder
    }
}

Write-Host 'Applied combined pack fixes.'
