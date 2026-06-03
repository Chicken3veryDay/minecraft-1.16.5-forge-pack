[CmdletBinding()]
param(
    [string]$Owner = 'Chicken3veryDay',
    [string]$Repo = 'minecraft-1.16.5-forge-pack',
    [string]$Tag = "v$(Get-Date -Format yyyy.MM.dd)",
    [string]$PackName = 'Minecraft 1.16.5 Forge Pack',
    [string]$MinecraftVersion = '1.16.5',
    [string]$ForgeVersion = '36.2.42',
    [switch]$SkipMinimalZip,
    [switch]$Upload,
    [switch]$VerifyHostedRelease,
    [switch]$StaticAssetNames
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$PackRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ManifestPath = Join-Path $PackRoot '.pack-manifest.json'
$AssetArchiveName = 'pack-assets.zip'
$MinimalZipName = 'minimal-pack.zip'
$AssetArchivePath = Join-Path $PackRoot $AssetArchiveName
$MinimalZipPath = Join-Path $PackRoot $MinimalZipName
$ReleaseAssetArchiveName = $AssetArchiveName
$ReleaseAssetArchivePath = $AssetArchivePath
$ReleaseMinimalZipName = $MinimalZipName
$ReleaseMinimalZipPath = $MinimalZipPath
$AssetArchiveUrl = $null

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "== $Message ==" -ForegroundColor Cyan
}

function Get-FileHashSha256 {
    param([string]$Path)
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-PackFiles {
    param(
        [string]$Section,
        [string]$FolderName
    )

    $folder = Join-Path $PackRoot $FolderName
    if (-not (Test-Path -LiteralPath $folder)) {
        throw "Missing required folder: $FolderName"
    }

    $rootPrefix = $PackRoot.TrimEnd('\') + '\'
    Get-ChildItem -LiteralPath $folder -File -Recurse | Sort-Object FullName | ForEach-Object {
        $relative = $_.FullName.Substring($rootPrefix.Length).Replace('\', '/')
        [ordered]@{
            name = $_.Name
            path = $relative
            size = $_.Length
            sha256 = Get-FileHashSha256 -Path $_.FullName
        }
    }
}

function Remove-ExistingFile {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Force
    }
}

function Invoke-CompressArchiveWithRetry {
    param(
        [string[]]$LiteralPath,
        [string]$DestinationPath,
        [int]$Attempts = 3
    )

    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        try {
            Remove-ExistingFile -Path $DestinationPath
            Compress-Archive -LiteralPath $LiteralPath -DestinationPath $DestinationPath -CompressionLevel Optimal
            return
        }
        catch {
            $message = $_.Exception.Message
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()

            if ($attempt -ge $Attempts) {
                throw "Could not build archive '$DestinationPath' after $Attempts attempt(s): $message"
            }

            Write-Host "Archive build failed for '$DestinationPath' (attempt $attempt of $Attempts): $message"
            Start-Sleep -Seconds ([Math]::Min(10, 2 * $attempt))
        }
    }
}

function Assert-GitHubCli {
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if ($null -eq $gh) {
        throw "GitHub CLI ('gh') was not found in PATH. Install gh or rerun without -Upload/-VerifyHostedRelease."
    }
}

function Get-GitHubReleaseAssets {
    Assert-GitHubCli

    $output = & gh release view $Tag --repo "$Owner/$Repo" --json assets 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Could not read GitHub Release '$Tag': $($output | Out-String)"
    }

    $release = ($output | Out-String) | ConvertFrom-Json
    $assets = @{}
    foreach ($asset in @($release.assets)) {
        $assets[[string]$asset.name] = $asset
    }

    return $assets
}

function Assert-HostedAssetMatchesLocal {
    param(
        [hashtable]$Assets,
        [string]$Name,
        [string]$Path,
        [string]$Sha256
    )

    if (-not $Assets.ContainsKey($Name)) {
        throw "GitHub Release '$Tag' does not contain asset '$Name'."
    }

    $localInfo = Get-Item -LiteralPath $Path
    $asset = $Assets[$Name]
    if ([int64]$asset.size -ne [int64]$localInfo.Length) {
        throw "Hosted '$Name' size mismatch. Expected $($localInfo.Length), got $($asset.size)."
    }

    $digest = [string]$asset.digest
    if ([string]::IsNullOrWhiteSpace($digest)) {
        Write-Host "Hosted '$Name' has no GitHub digest; verified size only."
        return
    }

    if (-not $digest.StartsWith('sha256:', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Hosted '$Name' used unsupported digest format: $digest"
    }

    $hostedHash = $digest.Substring('sha256:'.Length).ToLowerInvariant()
    if ($hostedHash -ne $Sha256) {
        throw "Hosted '$Name' SHA-256 mismatch. Expected $Sha256, got $hostedHash."
    }

    Write-Host "Verified hosted $Name ($Sha256)"
}

function Remove-GitHubReleaseAssetIfPresent {
    param(
        [hashtable]$Assets,
        [string]$Name
    )

    if (-not $Assets.ContainsKey($Name)) {
        return
    }

    Write-Host "Deleting stale hosted asset $Name"
    $output = & gh release delete-asset $Tag $Name --repo "$Owner/$Repo" -y 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Could not delete stale GitHub Release asset '$Name': $($output | Out-String)"
    }

    $Assets.Remove($Name)
}

function Remove-StaleGitHubReleaseAssetsByPattern {
    param(
        [hashtable]$Assets,
        [string]$Prefix,
        [string]$CurrentName
    )

    $staleAssetNames = @(
        $Assets.Keys |
            Where-Object { $_ -like "$Prefix-*.zip" -and $_ -ne $CurrentName } |
            Sort-Object
    )

    foreach ($name in $staleAssetNames) {
        Remove-GitHubReleaseAssetIfPresent -Assets $Assets -Name $name
    }
}

$combinedFixScript = Join-Path $PackRoot 'tools\Apply-PackFixes.ps1'
if (Test-Path -LiteralPath $combinedFixScript) {
    Write-Step "Applying pack fixes"
    & $combinedFixScript
}

Write-Step "Building hosted asset archive"
Invoke-CompressArchiveWithRetry -LiteralPath @(
    (Join-Path $PackRoot 'Client'),
    (Join-Path $PackRoot 'Config'),
    (Join-Path $PackRoot 'Server'),
    (Join-Path $PackRoot 'Shaderpacks')
) -DestinationPath $AssetArchivePath

$assetArchiveInfo = Get-Item -LiteralPath $AssetArchivePath
$assetArchiveHash = Get-FileHashSha256 -Path $AssetArchivePath

if (-not $StaticAssetNames) {
    $ReleaseAssetArchiveName = "pack-assets-$($assetArchiveHash.Substring(0, 12)).zip"
    $ReleaseAssetArchivePath = Join-Path $PackRoot $ReleaseAssetArchiveName
    Copy-Item -LiteralPath $AssetArchivePath -Destination $ReleaseAssetArchivePath -Force
}

$AssetArchiveUrl = "https://github.com/$Owner/$Repo/releases/download/$Tag/$ReleaseAssetArchiveName"

Write-Step "Regenerating manifest"
$manifest = [ordered]@{
    pack = $PackName
    minecraft = $MinecraftVersion
    forge = $ForgeVersion
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    assetArchive = [ordered]@{
        name = $ReleaseAssetArchiveName
        url = $AssetArchiveUrl
        size = $assetArchiveInfo.Length
        sha256 = $assetArchiveHash
        layoutRoot = ''
    }
    client = @(Get-PackFiles -Section 'client' -FolderName 'Client')
    config = @(Get-PackFiles -Section 'config' -FolderName 'Config')
    shaderpacks = @(Get-PackFiles -Section 'shaderpacks' -FolderName 'Shaderpacks')
    server = @(Get-PackFiles -Section 'server' -FolderName 'Server')
}

if ([string]::IsNullOrWhiteSpace($manifest.assetArchive.url)) {
    throw "Manifest assetArchive.url cannot be blank."
}

$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8

$minimalInfo = $null
$minimalHash = $null
if (-not $SkipMinimalZip) {
    Write-Step "Building minimal installer zip"
    Invoke-CompressArchiveWithRetry -LiteralPath @(
        (Join-Path $PackRoot 'Install-Minecraft-Pack.bat'),
        (Join-Path $PackRoot 'Install-Minecraft-Pack.ps1'),
        $ManifestPath,
        (Join-Path $PackRoot 'README-INSTALL.txt')
    ) -DestinationPath $MinimalZipPath

    $minimalInfo = Get-Item -LiteralPath $MinimalZipPath
    $minimalHash = Get-FileHashSha256 -Path $MinimalZipPath

    if (-not $StaticAssetNames) {
        $ReleaseMinimalZipName = "minimal-pack-$($minimalHash.Substring(0, 12)).zip"
        $ReleaseMinimalZipPath = Join-Path $PackRoot $ReleaseMinimalZipName
        Copy-Item -LiteralPath $MinimalZipPath -Destination $ReleaseMinimalZipPath -Force
    }
}

if ($Upload) {
    Write-Step "Uploading GitHub Release assets"
    Assert-GitHubCli

    if (-not $StaticAssetNames) {
        $existingAssets = Get-GitHubReleaseAssets
        if ($ReleaseAssetArchiveName -ne $AssetArchiveName) {
            Remove-GitHubReleaseAssetIfPresent -Assets $existingAssets -Name $AssetArchiveName
            Remove-StaleGitHubReleaseAssetsByPattern -Assets $existingAssets -Prefix 'pack-assets' -CurrentName $ReleaseAssetArchiveName
        }
        if ((-not $SkipMinimalZip) -and $ReleaseMinimalZipName -ne $MinimalZipName) {
            Remove-GitHubReleaseAssetIfPresent -Assets $existingAssets -Name $MinimalZipName
            Remove-StaleGitHubReleaseAssetsByPattern -Assets $existingAssets -Prefix 'minimal-pack' -CurrentName $ReleaseMinimalZipName
        }
    }

    $uploadFiles = @($ReleaseAssetArchivePath)
    if (-not $SkipMinimalZip) {
        $uploadFiles += $ReleaseMinimalZipPath
    }

    $output = & gh release upload $Tag $uploadFiles --repo "$Owner/$Repo" --clobber 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "GitHub Release upload failed: $($output | Out-String)"
    }

    $VerifyHostedRelease = $true
}

if ($VerifyHostedRelease) {
    Write-Step "Verifying hosted release assets"
    $hostedAssets = Get-GitHubReleaseAssets
    Assert-HostedAssetMatchesLocal -Assets $hostedAssets -Name $ReleaseAssetArchiveName -Path $ReleaseAssetArchivePath -Sha256 $assetArchiveHash

    if (-not $SkipMinimalZip) {
        Assert-HostedAssetMatchesLocal -Assets $hostedAssets -Name $ReleaseMinimalZipName -Path $ReleaseMinimalZipPath -Sha256 $minimalHash
    }
}

Write-Host ""
Write-Host "Built $AssetArchiveName ($($assetArchiveInfo.Length) bytes)"
Write-Host "Asset archive SHA-256: $assetArchiveHash"
if ($ReleaseAssetArchiveName -ne $AssetArchiveName) {
    Write-Host "Release asset archive: $ReleaseAssetArchiveName"
}
if (-not $SkipMinimalZip) {
    Write-Host "Built $MinimalZipName ($($minimalInfo.Length) bytes)"
    Write-Host "Minimal package SHA-256: $minimalHash"
    if ($ReleaseMinimalZipName -ne $MinimalZipName) {
        Write-Host "Release minimal package: $ReleaseMinimalZipName"
    }
}
Write-Host "Release URL: $AssetArchiveUrl"
