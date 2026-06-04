[CmdletBinding()]
param(
    [string]$Root,
    [string]$OutputPath,
    [string]$SourceNote = 'Client files are resolved from the exact Crazy Craft Updated 0.12.9 CurseForge manifest file IDs. Server files come from the official Crazy Craft Updated 0.12.9 server pack with enhanced_boss_bars removed because it loads client Minecraft classes on a dedicated server.',
    [string]$ValidationNote = 'Release assets are generated from verified source ZIPs and checked by SHA-256 before upload. The client contains 331 exact manifest jars; the server payload is the official server pack tree minus the VPS-proven server-incompatible Enhanced Boss Bars jar.',
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

function Get-FileHashSha256 {
    param([string]$Path)
    if (Get-Command Get-FileHash -ErrorAction SilentlyContinue) {
        return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    }

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        try {
            return (($sha256.ComputeHash($stream) | ForEach-Object { $_.ToString('x2') }) -join '')
        }
        finally {
            $sha256.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

$minimalHash = if (Test-Path -LiteralPath $minimalZipPath) {
    Get-FileHashSha256 -Path $minimalZipPath
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
$lines.Add('# Crazy Craft Updated 0.12.9 File List') | Out-Null
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
$lines.Add("- Source: $SourceNote") | Out-Null
$lines.Add("- Validation: $ValidationNote") | Out-Null
foreach ($note in @($AdditionalNotes)) {
    if (-not [string]::IsNullOrWhiteSpace($note)) {
        $lines.Add("- Note: $note") | Out-Null
    }
}

Add-FileTable -Lines $lines -Title 'Client Mods' -Files @($manifest.client)

if (@($manifest.config).Count -gt 0) {
    Add-FileTable -Lines $lines -Title 'Config Files' -Files @($manifest.config)
}

if (@($manifest.root).Count -gt 0) {
    Add-FileTable -Lines $lines -Title 'Root Override Files' -Files @($manifest.root)
}

if (@($manifest.shaderpacks).Count -gt 0) {
    Add-FileTable -Lines $lines -Title 'Shaderpacks' -Files @($manifest.shaderpacks)
}

Add-FileTable -Lines $lines -Title 'Server Files' -Files @($manifest.server)

Set-Content -LiteralPath $OutputPath -Value $lines -Encoding UTF8
Write-Host "Updated $OutputPath"
