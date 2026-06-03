[CmdletBinding()]
param(
    [string]$Root,
    [string]$OutputPath,
    [string]$CraftingFix = 'Polymorph remains removed from client and server because it changes recipe selection/workbench result synchronization and matched the earlier ghost/empty crafting-result symptom.',
    [string]$RestoreNote = 'Combined server-join fix: MyServerIsCompatible was removed from Client because it only hides Forge incompatible-server warnings. The server-required utility/gameplay jars that were previously server-only are now also included in Client: AI Improvements, Chunk Sending, Chunky, Connectivity, FastFurnace, FastSuite, FastWorkbench, Let Me Despawn, SmoothChunk, Spark, and Tree Harvester. Mowzie''s Mobs was updated from 1.5.25 to 1.5.27 on Client and Server to fix the GeckoLib 3.0.106 startup crash: NoSuchFieldError children.',
    [string]$ValidationNote = 'Dependency audit reads each jar META-INF/mods.toml and manifest Implementation-Version. Latest audit: no missing required dependencies, no incompatible required dependency ranges, no duplicate mod IDs, no Polymorph jar present, no MyServerIsCompatible jar present in Client, and Mowzie''s Mobs 1.5.27 present on both sides.',
    [string[]]$AdditionalNotes = @()
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $Root 'MODLIST.md'
}

$manifestPath = Join-Path $Root '.pack-manifest.json'
$minimalZipPath = Join-Path $Root 'minimal-pack.zip'
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Missing manifest: $manifestPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$minimalHash = if (Test-Path -LiteralPath $minimalZipPath) {
    (Get-FileHash -LiteralPath $minimalZipPath -Algorithm SHA256).Hash.ToLowerInvariant()
}
else {
    ''
}
$minimalName = if ($minimalHash) { "minimal-pack-$($minimalHash.Substring(0, 12)).zip" } else { 'minimal-pack.zip' }

function Add-FileTable {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [string]$Title,
        [object[]]$Files
    )

    $Lines.Add('') | Out-Null
    $Lines.Add("## $Title ($(@($Files).Count))") | Out-Null
    $Lines.Add('') | Out-Null
    $Lines.Add('| File | Size | SHA-256 |') | Out-Null
    $Lines.Add('|---|---:|---|') | Out-Null
    foreach ($file in @($Files | Sort-Object name)) {
        $Lines.Add("| ``$($file.name)`` | $($file.size) | ``$($file.sha256)`` |") | Out-Null
    }
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('# Minecraft 1.16.5 Forge Pack Mod List') | Out-Null
$lines.Add('') | Out-Null
$lines.Add("Generated: $((Get-Date).ToUniversalTime().ToString('o'))") | Out-Null
$lines.Add('') | Out-Null
$lines.Add('## Release') | Out-Null
$lines.Add('') | Out-Null
$lines.Add("- Minecraft: $($manifest.minecraft)") | Out-Null
$lines.Add("- Forge: $($manifest.forge)") | Out-Null
$lines.Add("- Asset archive: ``$($manifest.assetArchive.name)``") | Out-Null
$lines.Add("- Asset SHA-256: ``$($manifest.assetArchive.sha256)``") | Out-Null
$lines.Add("- Asset URL: <$($manifest.assetArchive.url)>") | Out-Null
$lines.Add("- Minimal installer: ``$minimalName``") | Out-Null
if ($minimalHash) {
    $lines.Add("- Minimal installer SHA-256: ``$minimalHash``") | Out-Null
}
$lines.Add("- Crafting fix: $CraftingFix") | Out-Null
$lines.Add("- Previous-version restore: $RestoreNote") | Out-Null
$lines.Add("- Validation: $ValidationNote") | Out-Null
foreach ($note in @($AdditionalNotes)) {
    if (-not [string]::IsNullOrWhiteSpace($note)) {
        $lines.Add("- Note: $note") | Out-Null
    }
}

Add-FileTable -Lines $lines -Title 'Client Mods' -Files @($manifest.client)
Add-FileTable -Lines $lines -Title 'Server Mods' -Files @($manifest.server)

if (@($manifest.config).Count -gt 0) {
    Add-FileTable -Lines $lines -Title 'Config Files' -Files @($manifest.config)
}

if (@($manifest.shaderpacks).Count -gt 0) {
    Add-FileTable -Lines $lines -Title 'Shaderpacks' -Files @($manifest.shaderpacks)
}

Set-Content -LiteralPath $OutputPath -Value $lines -Encoding UTF8
Write-Host "Updated $OutputPath"
