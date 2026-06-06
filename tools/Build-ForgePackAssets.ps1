[CmdletBinding()]
param(
    [string]$Root
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}

$Root = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Root)
$SourceRoot = Join-Path $Root 'pack-sources'
$BlueprintPath = Join-Path $SourceRoot 'pack-blueprint.json'
$ManifestPath = Join-Path $Root '.pack-manifest.json'
$AssetArchivePath = Join-Path $Root 'pack-assets.zip'

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

function Get-PackFiles {
    param(
        [string]$RepoRoot,
        [string]$RootPath,
        [string]$SectionName
    )

    $folder = Join-Path $RootPath $SectionName
    if (-not (Test-Path -LiteralPath $folder)) {
        return @()
    }

    $repoPrefix = ($RepoRoot.TrimEnd('\') + '\')
    $sectionPrefix = ($folder.TrimEnd('\') + '\')
    Get-ChildItem -LiteralPath $folder -File -Recurse | Sort-Object FullName | ForEach-Object {
        $relative = $_.FullName.Substring($repoPrefix.Length).Replace('\', '/')
        $sectionRelative = $_.FullName.Substring($sectionPrefix.Length).Replace('\', '/')
        [ordered]@{
            name = $_.Name
            path = $relative
            relativePath = $sectionRelative
            size = $_.Length
            sha256 = Get-FileHashSha256 -Path $_.FullName
        }
    }
}

if (-not (Test-Path -LiteralPath $BlueprintPath)) {
    throw "Missing blueprint: $BlueprintPath"
}

$blueprint = Get-Content -LiteralPath $BlueprintPath -Raw | ConvertFrom-Json

Compress-Archive -LiteralPath @(
    (Join-Path $SourceRoot 'Client'),
    (Join-Path $SourceRoot 'Config'),
    (Join-Path $SourceRoot 'Root'),
    (Join-Path $SourceRoot 'Server'),
    (Join-Path $SourceRoot 'Shaderpacks')
) -DestinationPath $AssetArchivePath -CompressionLevel Optimal -Force

$assetHash = Get-FileHashSha256 -Path $AssetArchivePath
$assetInfo = Get-Item -LiteralPath $AssetArchivePath

$manifest = [ordered]@{
    pack = $blueprint.packName
    packSlug = $blueprint.packSlug
    minecraft = $blueprint.minecraft
    platform = $blueprint.platform
    forgeVersion = $blueprint.forgeVersion
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    assetArchive = [ordered]@{
        name = 'pack-assets.zip'
        size = $assetInfo.Length
        sha256 = $assetHash
        layoutRoot = ''
    }
    metadata = $blueprint
    client = @(Get-PackFiles -RepoRoot $Root -RootPath $SourceRoot -SectionName 'Client')
    config = @(Get-PackFiles -RepoRoot $Root -RootPath $SourceRoot -SectionName 'Config')
    root = @(Get-PackFiles -RepoRoot $Root -RootPath $SourceRoot -SectionName 'Root')
    shaderpacks = @(Get-PackFiles -RepoRoot $Root -RootPath $SourceRoot -SectionName 'Shaderpacks')
    server = @(Get-PackFiles -RepoRoot $Root -RootPath $SourceRoot -SectionName 'Server')
}

$manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8

Write-Host "Built $AssetArchivePath"
Write-Host "Manifest: $ManifestPath"
