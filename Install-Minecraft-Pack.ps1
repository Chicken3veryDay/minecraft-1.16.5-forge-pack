[CmdletBinding()]
param(
    [switch]$Server,
    [string]$ClientPath = (Join-Path $env:APPDATA '.minecraft\forge-projecte-chaos-1.20.1'),
    [string]$ServerPath,
    [switch]$NoShader,
    [switch]$VerifyOnly,
    [switch]$SkipServerEntry,
    [string]$ServerEntryName = 'Forge ProjectE Chaos Pack',
    [string]$ServerEntryAddress = '',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'

$PackRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ManifestPath = Join-Path $PackRoot '.pack-manifest.json'
$MinecraftRoot = Join-Path $env:APPDATA '.minecraft'
$AssetExtractRoot = Join-Path $PackRoot '_pack-assets'
$UpdaterRoot = Join-Path $PackRoot '_pack-updater'
$InstallerBoundParameters = @{}
foreach ($key in $PSBoundParameters.Keys) {
    $InstallerBoundParameters[$key] = $PSBoundParameters[$key]
}

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "== $Message ==" -ForegroundColor Cyan
    Write-Progress -Id 1 -Activity "Forge ProjectE Chaos Pack" -Status $Message -PercentComplete 0
}

function Write-PackProgress {
    param(
        [string]$Activity,
        [string]$Status,
        [int]$PercentComplete,
        [int]$Id = 2
    )

    $percent = [Math]::Max(0, [Math]::Min(100, $PercentComplete))
    Write-Progress -Id $Id -Activity $Activity -Status $Status -PercentComplete $percent
}

function Complete-PackProgress {
    param(
        [string]$Activity,
        [int]$Id = 2
    )

    Write-Progress -Id $Id -Activity $Activity -Completed
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Remove-DirectoryIfPresent {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
}

function Stop-MinecraftLauncherProcesses {
    $processes = Get-CimInstance Win32_Process | Where-Object {
        $_.Name -eq 'Minecraft.exe' -or
        (($_.Name -in @('java.exe', 'javaw.exe')) -and [string]$_.CommandLine -match 'forge-projecte-chaos-1\.20\.1|1\.20\.1-forge-47\.\d+\.\d+')
    }

    foreach ($process in @($processes)) {
        try {
            Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
        }
        catch {
        }
    }

    if (@($processes).Count -gt 0) {
        Start-Sleep -Seconds 3
    }
}

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

function Read-Manifest {
    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        throw "Missing manifest beside installer: $ManifestPath"
    }
    Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
}

function Write-JsonFileNoBom {
    param(
        [string]$Path,
        [object]$Value,
        [int]$Depth = 10
    )

    $json = $Value | ConvertTo-Json -Depth $Depth
    $encoding = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $json, $encoding)
}

function Get-GitHubRepositoryFromAssetUrl {
    param([string]$AssetUrl)

    if ([string]::IsNullOrWhiteSpace($AssetUrl)) {
        return $null
    }

    $uri = [uri]$AssetUrl
    if ($uri.Host -notin @('github.com', 'www.github.com')) {
        return $null
    }

    $segments = @($uri.AbsolutePath.Trim('/') -split '/')
    if ($segments.Count -lt 2) {
        return $null
    }

    return [pscustomobject]@{
        owner = $segments[0]
        repo = $segments[1]
    }
}

function Invoke-GitHubApi {
    param([string]$Url)
    Invoke-RestMethod -Uri $Url -UseBasicParsing -Headers @{ 'User-Agent' = 'ForgeProjectEChaosPackInstaller' }
}

function Get-LatestGitHubRelease {
    param([object]$Manifest)

    $repo = Get-GitHubRepositoryFromAssetUrl -AssetUrl ([string]$Manifest.assetArchive.url)
    if ($null -eq $repo) {
        return $null
    }

    $releases = Invoke-GitHubApi -Url "https://api.github.com/repos/$($repo.owner)/$($repo.repo)/releases?per_page=10"
    foreach ($release in $releases) {
        if (-not [bool]$release.draft -and -not [bool]$release.prerelease) {
            return $release
        }
    }

    return $null
}

function Get-GitHubReleaseAssetFallbackUrls {
    param(
        [string]$AssetUrl,
        [string]$ArchiveName
    )

    if ([string]::IsNullOrWhiteSpace($AssetUrl) -or [string]::IsNullOrWhiteSpace($ArchiveName)) {
        return @()
    }

    $repo = Get-GitHubRepositoryFromAssetUrl -AssetUrl $AssetUrl
    if ($null -eq $repo) {
        return @()
    }

    $apiUrl = "https://api.github.com/repos/$($repo.owner)/$($repo.repo)/releases?per_page=20"
    try {
        $releases = Invoke-GitHubApi -Url $apiUrl
    }
    catch {
        Write-Warning "Could not search GitHub releases for '$ArchiveName': $($_.Exception.Message)"
        return @()
    }

    @(
        foreach ($release in @($releases)) {
            foreach ($asset in @($release.assets)) {
                if ([string]$asset.name -eq $ArchiveName -and -not [string]::IsNullOrWhiteSpace([string]$asset.browser_download_url)) {
                    [string]$asset.browser_download_url
                }
            }
        }
    ) | Select-Object -Unique
}

function Invoke-DownloadWithHashCheck {
    param(
        [string]$Url,
        [string]$DestinationPath,
        [string]$ExpectedHash
    )

    $tempPath = "$DestinationPath.download"
    if (Test-Path -LiteralPath $tempPath) {
        Remove-Item -LiteralPath $tempPath -Force
    }

    try {
        Write-Host "Downloading $Url"
        $request = [System.Net.HttpWebRequest]::Create($Url)
        $request.UserAgent = 'ForgeProjectEChaosPackInstaller'
        $response = $request.GetResponse()
        try {
            $totalBytes = [int64]$response.ContentLength
            $buffer = New-Object byte[] (1024 * 1024)
            $readBytes = [int64]0
            $stream = $response.GetResponseStream()
            $file = [System.IO.File]::Open($tempPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
            try {
                while (($count = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    $file.Write($buffer, 0, $count)
                    $readBytes += $count
                    if ($totalBytes -gt 0) {
                        $percent = [int](($readBytes * 100) / $totalBytes)
                        Write-PackProgress -Activity "Downloading pack assets" -Status ("{0:N1} / {1:N1} MB" -f ($readBytes / 1MB), ($totalBytes / 1MB)) -PercentComplete $percent
                    }
                }
            }
            finally {
                $file.Dispose()
                $stream.Dispose()
            }
        }
        finally {
            $response.Dispose()
            Complete-PackProgress -Activity "Downloading pack assets"
        }

        if (-not [string]::IsNullOrWhiteSpace($ExpectedHash)) {
            Write-PackProgress -Activity "Verifying download" -Status "Checking SHA-256" -PercentComplete 50
            $actual = Get-FileHashSha256 -Path $tempPath
            if ($actual -ne $ExpectedHash) {
                throw "Downloaded asset archive hash mismatch. Expected $ExpectedHash, got $actual."
            }
            Complete-PackProgress -Activity "Verifying download"
        }

        Move-Item -LiteralPath $tempPath -Destination $DestinationPath -Force
    }
    finally {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force
        }
    }
}

function Expand-ZipArchiveWithProgress {
    param(
        [string]$ArchivePath,
        [string]$DestinationPath,
        [string]$Activity = "Extracting archive"
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Ensure-Directory -Path $DestinationPath
    $zip = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        $entries = @($zip.Entries)
        $total = [Math]::Max(1, $entries.Count)
        for ($index = 0; $index -lt $entries.Count; $index++) {
            $entry = $entries[$index]
            $percent = [int](($index * 100) / $total)
            Write-PackProgress -Activity $Activity -Status $entry.FullName -PercentComplete $percent

            $target = Join-Path $DestinationPath ($entry.FullName.Replace('/', [IO.Path]::DirectorySeparatorChar))
            $resolvedDestination = [System.IO.Path]::GetFullPath($DestinationPath)
            $resolvedTarget = [System.IO.Path]::GetFullPath($target)
            if (-not $resolvedTarget.StartsWith($resolvedDestination, [StringComparison]::OrdinalIgnoreCase)) {
                throw "Archive entry escapes destination: $($entry.FullName)"
            }

            if ($entry.FullName.EndsWith('/')) {
                Ensure-Directory -Path $resolvedTarget
                continue
            }

            $parent = Split-Path -Parent $resolvedTarget
            if (-not [string]::IsNullOrWhiteSpace($parent)) {
                Ensure-Directory -Path $parent
            }
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $resolvedTarget, $true)
        }
    }
    finally {
        $zip.Dispose()
        Complete-PackProgress -Activity $Activity
    }
}

function Update-PackInstallerFromLatestRelease {
    param([object]$Manifest)

    if ([string]$env:FORGE_PACK_INSTALLER_SKIP_UPDATE -eq '1') {
        return $false
    }

    $latest = $null
    try {
        Write-Step "Checking for pack updates"
        $latest = Get-LatestGitHubRelease -Manifest $Manifest
    }
    catch {
        Write-Warning "Could not check for pack updates: $($_.Exception.Message)"
        return $false
    }

    if ($null -eq $latest) {
        Write-Host "No GitHub release update source found."
        return $false
    }

    $minimalAsset = @(
        $latest.assets |
            Where-Object { [string]$_.name -like 'minimal-pack-*.zip' } |
            Sort-Object { [datetime]$_.updated_at } -Descending |
            Select-Object -First 1
    )
    if ($null -eq $minimalAsset) {
        Write-Host "Latest release '$($latest.tag_name)' has no minimal installer asset."
        return $false
    }

    $statePath = Join-Path $UpdaterRoot 'last-update.json'
    $state = $null
    if (Test-Path -LiteralPath $statePath) {
        try {
            $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
        }
        catch {
            $state = $null
        }
    }

    $remoteDigest = [string]$minimalAsset.digest
    if (
        $null -ne $state -and
        [string]$state.tag -eq [string]$latest.tag_name -and
        [string]$state.asset -eq [string]$minimalAsset.name -and
        [string]$state.digest -eq $remoteDigest
    ) {
        Write-Host "Pack installer is already current: $($latest.tag_name)"
        return $false
    }

    Ensure-Directory -Path $UpdaterRoot
    $downloadPath = Join-Path $UpdaterRoot ([string]$minimalAsset.name)
    $expectedHash = ''
    if ($remoteDigest.StartsWith('sha256:', [StringComparison]::OrdinalIgnoreCase)) {
        $expectedHash = $remoteDigest.Substring('sha256:'.Length).ToLowerInvariant()
    }

    Write-Step "Downloading pack updater"
    Invoke-DownloadWithHashCheck -Url ([string]$minimalAsset.browser_download_url) -DestinationPath $downloadPath -ExpectedHash $expectedHash

    $extractPath = Join-Path $UpdaterRoot 'latest'
    Remove-DirectoryIfPresent -Path $extractPath
    Write-Step "Extracting pack updater"
    Expand-ZipArchiveWithProgress -ArchivePath $downloadPath -DestinationPath $extractPath -Activity "Extracting pack updater"

    $updated = $false
    foreach ($relative in @(
        'Install-Minecraft-Pack.bat',
        'Install-Minecraft-Pack.ps1',
        'Install-Forge-Server.sh',
        'Install-Fabric-Server.sh',
        'Install-CrazyCraft-Server.sh',
        '.pack-manifest.json',
        'README-INSTALL.txt'
    )) {
        $source = Join-Path $extractPath $relative
        if (Test-Path -LiteralPath $source) {
            Copy-Item -LiteralPath $source -Destination (Join-Path $PackRoot $relative) -Force
            $updated = $true
        }
    }

    [pscustomobject]@{
        tag = [string]$latest.tag_name
        asset = [string]$minimalAsset.name
        digest = $remoteDigest
        updatedAt = (Get-Date).ToUniversalTime().ToString('o')
    } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $statePath -Encoding UTF8

    if ($updated) {
        Write-Host "Updated portable installer files from release $($latest.tag_name)."
    }
    return $updated
}

function Restart-UpdatedInstaller {
    $env:FORGE_PACK_INSTALLER_SKIP_UPDATE = '1'
    $args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath)
    foreach ($key in $InstallerBoundParameters.Keys) {
        $value = $InstallerBoundParameters[$key]
        if ($value -is [System.Management.Automation.SwitchParameter]) {
            if ($value.IsPresent) {
                $args += "-$key"
            }
        }
        elseif ($null -ne $value) {
            $args += "-$key"
            $args += [string]$value
        }
    }

    Write-Step "Restarting updated installer"
    & powershell.exe @args
    exit $LASTEXITCODE
}

function Get-ManifestAssetArchivePath {
    param([object]$Manifest)

    $archiveName = [string]$Manifest.assetArchive.name
    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($archiveName)) {
        $candidates += (Join-Path $PackRoot $archiveName)
    }

    $expectedHash = ([string]$Manifest.assetArchive.sha256).ToLowerInvariant()
    if (-not [string]::IsNullOrWhiteSpace($expectedHash) -and $expectedHash.Length -ge 12) {
        $candidates += (Join-Path $PackRoot "pack-assets-$($expectedHash.Substring(0, 12)).zip")
    }
    $candidates += (Join-Path $PackRoot 'pack-assets.zip')

    foreach ($candidate in $candidates | Select-Object -Unique) {
        if (-not (Test-Path -LiteralPath $candidate)) {
            continue
        }

        if (-not [string]::IsNullOrWhiteSpace($expectedHash)) {
            $actual = Get-FileHashSha256 -Path $candidate
            if ($actual -ne $expectedHash) {
                throw "Asset archive hash mismatch for '$candidate'. Expected $expectedHash, got $actual."
            }
        }

        return $candidate
    }

    $assetUrl = [string]$Manifest.assetArchive.url
    if (-not [string]::IsNullOrWhiteSpace($assetUrl) -and -not [string]::IsNullOrWhiteSpace($archiveName)) {
        $downloadPath = Join-Path $PackRoot $archiveName
        Write-Step "Downloading pack assets"
        $downloadUrls = @($assetUrl) + @(Get-GitHubReleaseAssetFallbackUrls -AssetUrl $assetUrl -ArchiveName $archiveName)
        $lastError = $null
        foreach ($downloadUrl in @($downloadUrls | Select-Object -Unique)) {
            try {
                Invoke-DownloadWithHashCheck -Url $downloadUrl -DestinationPath $downloadPath -ExpectedHash $expectedHash
                return $downloadPath
            }
            catch {
                $lastError = $_
                Write-Warning "Could not download '$archiveName' from '$downloadUrl': $($_.Exception.Message)"
            }
        }

        if ($null -ne $lastError) {
            throw "Could not download pack asset archive '$archiveName'. Last error: $($lastError.Exception.Message)"
        }
    }

    $downloadHint = ''
    if (-not [string]::IsNullOrWhiteSpace($archiveName)) {
        $downloadHint = " Download '$archiveName' next to this installer."
    }
    throw "Missing pack asset archive beside installer.$downloadHint"
}

function Ensure-AssetArchiveExtracted {
    param([object]$Manifest)

    $markerPath = Join-Path $AssetExtractRoot '.pack-assets.sha256'
    $expectedHash = ([string]$Manifest.assetArchive.sha256).ToLowerInvariant()
    if ((Test-Path -LiteralPath $markerPath) -and ((Get-Content -LiteralPath $markerPath -Raw).Trim() -eq $expectedHash)) {
        return
    }

    $archivePath = Get-ManifestAssetArchivePath -Manifest $Manifest
    Write-Step "Extracting pack assets"
    Write-Host "Using asset archive: $archivePath"
    Remove-DirectoryIfPresent -Path $AssetExtractRoot
    Ensure-Directory -Path $AssetExtractRoot
    Expand-ZipArchiveWithProgress -ArchivePath $archivePath -DestinationPath $AssetExtractRoot -Activity "Extracting pack assets"
    $expectedHash | Set-Content -LiteralPath $markerPath -Encoding ASCII
}

function Get-ManifestSectionFolderName {
    param([string]$Section)
    switch ($Section) {
        'client' { 'Client' }
        'config' { 'Config' }
        'root' { 'Root' }
        'shaderpacks' { 'Shaderpacks' }
        'server' { 'Server' }
        default { $Section }
    }
}

function Get-ManifestItemRelativePath {
    param(
        [object]$Item,
        [string]$Section
    )

    if (-not [string]::IsNullOrWhiteSpace([string]$Item.relativePath)) {
        return ([string]$Item.relativePath).Replace('/', [IO.Path]::DirectorySeparatorChar)
    }

    $path = ([string]$Item.path).Replace('\', '/')
    $folderName = Get-ManifestSectionFolderName -Section $Section
    $prefix = "$folderName/"
    if ($path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        return $path.Substring($prefix.Length).Replace('/', [IO.Path]::DirectorySeparatorChar)
    }

    return [string]$Item.name
}

function Resolve-ManifestItemSource {
    param(
        [object]$Manifest,
        [object]$Item
    )

    $path = Join-Path $PackRoot $Item.path
    if (-not (Test-Path -LiteralPath $path)) {
        $rootBundledPath = Join-Path $PackRoot $Item.name
        if (Test-Path -LiteralPath $rootBundledPath) {
            $path = $rootBundledPath
        }
    }

    if (-not (Test-Path -LiteralPath $path)) {
        Ensure-AssetArchiveExtracted -Manifest $Manifest
        $archiveRelative = ([string]$Item.path).Replace('\', '/')
        if ($archiveRelative.StartsWith('pack-sources/', [StringComparison]::OrdinalIgnoreCase)) {
            $archiveRelative = $archiveRelative.Substring('pack-sources/'.Length)
        }
        $path = Join-Path $AssetExtractRoot ($archiveRelative.Replace('/', [IO.Path]::DirectorySeparatorChar))
    }

    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing bundled file: $($Item.path)"
    }

    $actual = Get-FileHashSha256 -Path $path
    $expected = ([string]$Item.sha256).ToLowerInvariant()
    if ($actual -ne $expected) {
        throw "Hash mismatch for bundled file $($Item.path). Expected $expected, got $actual."
    }
    $path
}

function Get-ManifestForgeInstallerItem {
    param([object]$Manifest)

    $expectedName = "forge-$($Manifest.minecraft)-$($Manifest.forgeVersion)-installer.jar"
    $item = @($Manifest.server) | Where-Object {
        [string]$_.name -eq $expectedName -or [string]$_.path -match [regex]::Escape($expectedName)
    } | Select-Object -First 1

    if (-not $item) {
        throw "The bundled Forge installer jar '$expectedName' is missing from the manifest server payload."
    }

    return $item
}

function Test-Java17Path {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    try {
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $versionOutput = & $Path '-version' 2>&1
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
        if ($LASTEXITCODE -ne 0) {
            return $false
        }

        $text = $versionOutput | Out-String
        $match = [regex]::Match($text, 'version "?(?<major>\d+)')
        if (-not $match.Success) {
            return $false
        }

        return ([int]$match.Groups['major'].Value -ge 17)
    }
    catch {
        return $false
    }
}

function Get-JavaCandidatePaths {
    $candidates = [System.Collections.Generic.List[string]]::new()

    $portableJavaRoot = Join-Path $PackRoot '_InstallCache\microsoft-jdk-17'
    if (Test-Path -LiteralPath $portableJavaRoot) {
        foreach ($javaPath in Get-ChildItem -Path $portableJavaRoot -Recurse -Filter 'java.exe' -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending | Select-Object -ExpandProperty FullName) {
            if (-not $candidates.Contains($javaPath)) {
                $candidates.Add($javaPath)
            }
        }
    }

    foreach ($root in @(
        (Join-Path $MinecraftRoot 'runtime'),
        (Join-Path $env:ProgramFiles 'Minecraft Launcher\runtime'),
        (Join-Path $env:ProgramFiles 'Java'),
        (Join-Path ${env:ProgramFiles(x86)} 'Java'),
        (Join-Path ${env:ProgramFiles(x86)} 'Common Files\Oracle\Java')
    )) {
        if ([string]::IsNullOrWhiteSpace($root) -or -not (Test-Path -LiteralPath $root)) {
            continue
        }

        foreach ($javaPath in Get-ChildItem -Path $root -Recurse -Filter 'java.exe' -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending | Select-Object -ExpandProperty FullName) {
            if (-not $candidates.Contains($javaPath)) {
                $candidates.Add($javaPath)
            }
        }
    }

    @($candidates | Select-Object -Unique)
}

function Install-PortableJavaRuntime {
    $javaRoot = Join-Path $PackRoot '_InstallCache\microsoft-jdk-17'
    $zipPath = Join-Path $javaRoot 'microsoft-jdk-17-windows-x64.zip'
    $javaUrl = 'https://aka.ms/download-jdk/microsoft-jdk-17-windows-x64.zip'

    Write-Step "Downloading portable Java 17"
    Write-Host "No Java 17 runtime was found. Downloading a portable Microsoft OpenJDK 17 runtime."
    Ensure-Directory -Path $javaRoot
    Invoke-DownloadWithHashCheck -Url $javaUrl -DestinationPath $zipPath -ExpectedHash ''

    Write-Step "Extracting portable Java 17"
    $extractRoot = Join-Path $javaRoot 'runtime'
    Remove-DirectoryIfPresent -Path $extractRoot
    Expand-ZipArchiveWithProgress -ArchivePath $zipPath -DestinationPath $extractRoot -Activity "Extracting portable Java 17"

    foreach ($candidate in Get-JavaCandidatePaths) {
        if (Test-Java17Path -Path $candidate) {
            return $candidate
        }
    }

    throw "Downloaded portable Java 17, but no working java.exe was found after extraction."
}

function Get-PreferredJavaPath {
    foreach ($candidate in Get-JavaCandidatePaths) {
        if (Test-Java17Path -Path $candidate) {
            return $candidate
        }
    }

    return Install-PortableJavaRuntime
}

function Ensure-MinecraftBaseVersionMetadata {
    param([object]$Manifest)

    $baseVersion = [string]$Manifest.minecraft
    $baseVersionDir = Join-Path $MinecraftRoot "versions\$baseVersion"
    $baseVersionJson = Join-Path $baseVersionDir "$baseVersion.json"
    if (Test-Path -LiteralPath $baseVersionJson) {
        return
    }

    Write-Step "Installing Minecraft $baseVersion metadata"
    Ensure-Directory -Path $baseVersionDir

    $manifestUrl = 'https://piston-meta.mojang.com/mc/game/version_manifest_v2.json'
    $versionManifest = Invoke-RestMethod -Uri $manifestUrl
    $versionInfo = @($versionManifest.versions) | Where-Object { [string]$_.id -eq $baseVersion } | Select-Object -First 1
    if (-not $versionInfo) {
        throw "Could not find Minecraft version '$baseVersion' in Mojang version manifest."
    }

    Invoke-WebRequest -Uri ([string]$versionInfo.url) -OutFile $baseVersionJson
}

function Ensure-ForgeClientVersion {
    param([object]$Manifest)

    $versionId = "$($Manifest.minecraft)-forge-$($Manifest.forgeVersion)"
    $versionDir = Join-Path $MinecraftRoot "versions\$versionId"
    $versionJson = Join-Path $versionDir "$versionId.json"
    if (Test-Path -LiteralPath $versionJson) {
        return $versionId
    }

    Write-Step "Installing Forge client into Minecraft Launcher"
    Ensure-Directory -Path $MinecraftRoot

    $installerItem = Get-ManifestForgeInstallerItem -Manifest $Manifest
    $installerPath = Resolve-ManifestItemSource -Manifest $Manifest -Item $installerItem
    $javaPath = Get-PreferredJavaPath

    Write-Host "Using Java: $javaPath"
    $forgeOutput = & $javaPath '-jar' $installerPath '--installClient' $MinecraftRoot 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Forge client installation failed.`n$($forgeOutput | Out-String)"
    }

    if (-not (Test-Path -LiteralPath $versionJson)) {
        throw "Forge installer completed but the launcher version '$versionId' was not created."
    }

    return $versionId
}

function Update-LauncherProfile {
    param(
        [object]$Manifest,
        [string]$VersionId
    )

    $profileKey = [string]$Manifest.packSlug
    if ([string]::IsNullOrWhiteSpace($profileKey)) {
        $profileKey = 'forge-projecte-chaos-pack'
    }

    $profilesPath = Join-Path $MinecraftRoot 'launcher_profiles.json'
    if (-not (Test-Path -LiteralPath $profilesPath)) {
        throw "Minecraft Launcher profile file is missing: $profilesPath. Open Minecraft Launcher once, then rerun the installer."
    }

    $profilesJson = Get-Content -LiteralPath $profilesPath -Raw | ConvertFrom-Json
    if (-not $profilesJson.profiles) {
        $profilesJson | Add-Member -NotePropertyName 'profiles' -NotePropertyValue ([pscustomobject]@{})
    }

    $recommendedXmx = [string]$Manifest.metadata.hostProfile.recommendedXmx
    if ([string]::IsNullOrWhiteSpace($recommendedXmx)) {
        $recommendedXmx = '8G'
    }

    function Set-ProfileProperty {
        param(
            [object]$Profile,
            [string]$Name,
            [object]$Value
        )

        if ($Profile.PSObject.Properties.Name -contains $Name) {
            $Profile.$Name = $Value
        }
        else {
            $Profile | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
        }
    }

    $resolvedClientPath = [System.IO.Path]::GetFullPath($ClientPath)
    $now = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $profile = [ordered]@{
        created       = $now
        gameDir       = $resolvedClientPath
        icon          = 'Furnace'
        javaArgs      = "-Xms4G -Xmx$recommendedXmx"
        lastUsed      = $now
        lastVersionId = $VersionId
        name          = [string]$Manifest.pack
        type          = 'custom'
    }

    $matchingProfileKeys = @(
        $profilesJson.profiles.PSObject.Properties |
            Where-Object { [string]$_.Value.lastVersionId -eq $VersionId } |
            Select-Object -ExpandProperty Name
    )
    $selectedProfileKey = $profileKey
    if ($matchingProfileKeys.Count -gt 0) {
        $selectedProfileKey = [string]$matchingProfileKeys[0]
    }

    if ($profilesJson.profiles.PSObject.Properties.Name -contains $profileKey) {
        $profilesJson.profiles.$profileKey = [pscustomobject]$profile
    }
    else {
        $profilesJson.profiles | Add-Member -NotePropertyName $profileKey -NotePropertyValue ([pscustomobject]$profile)
    }

    foreach ($key in $matchingProfileKeys) {
        $existing = $profilesJson.profiles.$key
        Set-ProfileProperty -Profile $existing -Name 'name' -Value ([string]$Manifest.pack)
        Set-ProfileProperty -Profile $existing -Name 'gameDir' -Value $resolvedClientPath
        Set-ProfileProperty -Profile $existing -Name 'javaArgs' -Value "-Xms4G -Xmx$recommendedXmx"
        Set-ProfileProperty -Profile $existing -Name 'icon' -Value 'Furnace'
        Set-ProfileProperty -Profile $existing -Name 'type' -Value 'custom'
        Set-ProfileProperty -Profile $existing -Name 'lastVersionId' -Value $VersionId
    }

    if ($profilesJson.PSObject.Properties.Name -contains 'selectedProfile') {
        $profilesJson.selectedProfile = $selectedProfileKey
    }
    else {
        $profilesJson | Add-Member -NotePropertyName 'selectedProfile' -NotePropertyValue $selectedProfileKey
    }
    Write-JsonFileNoBom -Path $profilesPath -Value $profilesJson -Depth 10

    return $profileKey
}

function Assert-LauncherProfile {
    param(
        [object]$Manifest,
        [string]$VersionId
    )

    $profileKey = [string]$Manifest.packSlug
    if ([string]::IsNullOrWhiteSpace($profileKey)) {
        $profileKey = 'forge-projecte-chaos-pack'
    }

    $profilesPath = Join-Path $MinecraftRoot 'launcher_profiles.json'
    if (-not (Test-Path -LiteralPath $profilesPath)) {
        throw "Missing Minecraft Launcher profiles file: $profilesPath"
    }

    $profilesJson = Get-Content -LiteralPath $profilesPath -Raw | ConvertFrom-Json
    $profileCandidates = @()
    if ($profilesJson.profiles.PSObject.Properties.Name -contains $profileKey) {
        $profileCandidates += $profilesJson.profiles.$profileKey
    }
    $profileCandidates += @(
        $profilesJson.profiles.PSObject.Properties |
            Where-Object { [string]$_.Value.lastVersionId -eq $VersionId } |
            Select-Object -ExpandProperty Value
    )

    if ($profileCandidates.Count -eq 0) {
        throw "Missing launcher profile for '$VersionId'."
    }

    $resolvedClientPath = [System.IO.Path]::GetFullPath($ClientPath)
    $badProfiles = @(
        $profilesJson.profiles.PSObject.Properties |
            Where-Object {
                [string]$_.Value.lastVersionId -eq $VersionId -and
                [string]$_.Value.gameDir -ne $resolvedClientPath
            } |
            ForEach-Object { "$($_.Name) -> '$($_.Value.gameDir)'" }
    )
    if ($badProfiles.Count -gt 0) {
        throw "Launcher has Forge profile(s) for '$VersionId' that do not point at '$resolvedClientPath': $($badProfiles -join '; ')"
    }

    $profile = $profileCandidates | Where-Object {
        [string]$_.lastVersionId -eq $VersionId -and
        [string]$_.gameDir -eq $resolvedClientPath
    } | Select-Object -First 1

    if (-not $profile) {
        throw "No launcher profile for '$VersionId' points at '$resolvedClientPath'."
    }

    if ([string]$profile.gameDir -ne $resolvedClientPath) {
        throw "Launcher profile '$profileKey' points at '$($profile.gameDir)' instead of '$resolvedClientPath'."
    }
}

function Copy-ManifestSectionTree {
    param(
        [object]$Manifest,
        [string]$Section,
        [string]$Destination
    )

    Ensure-Directory -Path $Destination
    $items = @($Manifest.$Section)
    $total = [Math]::Max(1, $items.Count)
    for ($index = 0; $index -lt $items.Count; $index++) {
        $item = $items[$index]
        $percent = [int](($index * 100) / $total)
        Write-PackProgress -Activity "Copying $Section files" -Status ([string]$item.name) -PercentComplete $percent
        $source = Resolve-ManifestItemSource -Manifest $Manifest -Item $item
        $relative = Get-ManifestItemRelativePath -Item $item -Section $Section
        $target = Join-Path $Destination $relative
        $targetParent = Split-Path -Parent $target
        if (-not [string]::IsNullOrWhiteSpace($targetParent)) {
            Ensure-Directory -Path $targetParent
        }
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
    Complete-PackProgress -Activity "Copying $Section files"
}

function Assert-ManifestSectionTree {
    param(
        [object]$Manifest,
        [string]$Section,
        [string]$Destination
    )

    $items = @($Manifest.$Section)
    $total = [Math]::Max(1, $items.Count)
    for ($index = 0; $index -lt $items.Count; $index++) {
        $item = $items[$index]
        $percent = [int](($index * 100) / $total)
        Write-PackProgress -Activity "Verifying $Section files" -Status ([string]$item.name) -PercentComplete $percent
        $relative = Get-ManifestItemRelativePath -Item $item -Section $Section
        $target = Join-Path $Destination $relative
        if (-not (Test-Path -LiteralPath $target)) {
            throw "Missing installed file for section '$Section': $relative"
        }
        $actual = Get-FileHashSha256 -Path $target
        $expected = ([string]$Item.sha256).ToLowerInvariant()
        if ($actual -ne $expected) {
            throw "Installed hash mismatch for '$relative'. Expected $expected, got $actual."
        }
    }
    Complete-PackProgress -Activity "Verifying $Section files"
}

function Write-ServerEntryNote {
    param(
        [string]$Destination,
        [string]$Name,
        [string]$Address
    )

    if ([string]::IsNullOrWhiteSpace($Address)) {
        return
    }

    $notePath = Join-Path $Destination 'server-entry.txt'
    @(
        "Suggested server entry name: $Name"
        "Suggested server address: $Address"
    ) | Set-Content -LiteralPath $notePath -Encoding UTF8
}

function Install-ClientPack {
    param([object]$Manifest)

    Write-Step "Staging Forge 1.20.1 client instance"
    if ((Test-Path -LiteralPath $ClientPath) -and -not $Force) {
        Write-Host "Reusing existing directory: $ClientPath"
    }
    Ensure-Directory -Path $ClientPath

    Remove-DirectoryIfPresent -Path (Join-Path $ClientPath 'mods\mods')
    Remove-DirectoryIfPresent -Path (Join-Path $ClientPath 'config\config')
    Remove-DirectoryIfPresent -Path (Join-Path $ClientPath 'shaderpacks\shaderpacks')

    Copy-ManifestSectionTree -Manifest $Manifest -Section 'client' -Destination $ClientPath
    Copy-ManifestSectionTree -Manifest $Manifest -Section 'config' -Destination $ClientPath
    Copy-ManifestSectionTree -Manifest $Manifest -Section 'root' -Destination $ClientPath
    if (-not $NoShader) {
        Copy-ManifestSectionTree -Manifest $Manifest -Section 'shaderpacks' -Destination $ClientPath
    }

    if (-not $SkipServerEntry) {
        Write-ServerEntryNote -Destination $ClientPath -Name $ServerEntryName -Address $ServerEntryAddress
    }

    Ensure-MinecraftBaseVersionMetadata -Manifest $Manifest
    $versionId = Ensure-ForgeClientVersion -Manifest $Manifest
    Update-LauncherProfile -Manifest $Manifest -VersionId $versionId | Out-Null

    Assert-ManifestSectionTree -Manifest $Manifest -Section 'client' -Destination $ClientPath
    Assert-ManifestSectionTree -Manifest $Manifest -Section 'config' -Destination $ClientPath
    Assert-ManifestSectionTree -Manifest $Manifest -Section 'root' -Destination $ClientPath
    if (-not $NoShader) {
        Assert-ManifestSectionTree -Manifest $Manifest -Section 'shaderpacks' -Destination $ClientPath
    }
    Assert-LauncherProfile -Manifest $Manifest -VersionId $versionId

    Write-Host ""
    Write-Host "Client staging complete: $ClientPath" -ForegroundColor Green
}

function Install-ServerPack {
    param([object]$Manifest)

    if ([string]::IsNullOrWhiteSpace($ServerPath)) {
        throw "Server mode requires -ServerPath."
    }

    Write-Step "Staging Forge 1.20.1 server payload"
    Ensure-Directory -Path $ServerPath
    foreach ($relative in @('mods', 'config', 'defaultconfigs', 'libraries', 'versions', 'run.sh', 'run.bat', 'user_jvm_args.txt')) {
        Remove-DirectoryIfPresent -Path (Join-Path $ServerPath $relative)
    }
    Get-ChildItem -LiteralPath $ServerPath -File -Filter 'forge-*-installer.jar' -ErrorAction SilentlyContinue | Remove-Item -Force
    Copy-ManifestSectionTree -Manifest $Manifest -Section 'server' -Destination $ServerPath
    Assert-ManifestSectionTree -Manifest $Manifest -Section 'server' -Destination $ServerPath

    Write-Host ""
    Write-Host "Server staging complete: $ServerPath" -ForegroundColor Green
}

function Test-Install {
    param([object]$Manifest)

    if ($Server) {
        if ([string]::IsNullOrWhiteSpace($ServerPath)) {
            throw "Server mode requires -ServerPath."
        }
        Assert-ManifestSectionTree -Manifest $Manifest -Section 'server' -Destination $ServerPath
        Write-Host "Server verification passed: $ServerPath" -ForegroundColor Green
        return
    }

    $versionId = "$($Manifest.minecraft)-forge-$($Manifest.forgeVersion)"
    Assert-ManifestSectionTree -Manifest $Manifest -Section 'client' -Destination $ClientPath
    Assert-ManifestSectionTree -Manifest $Manifest -Section 'config' -Destination $ClientPath
    Assert-ManifestSectionTree -Manifest $Manifest -Section 'root' -Destination $ClientPath
    if (-not $NoShader) {
        Assert-ManifestSectionTree -Manifest $Manifest -Section 'shaderpacks' -Destination $ClientPath
    }
    Assert-LauncherProfile -Manifest $Manifest -VersionId $versionId
    Write-Host "Client verification passed: $ClientPath" -ForegroundColor Green
}

Write-Host "Forge 1.20.1 ProjectE chaos pack installer"
Write-Host "Pack root: $PackRoot"
$manifest = Read-Manifest

if (-not $VerifyOnly) {
    $updatedInstaller = Update-PackInstallerFromLatestRelease -Manifest $manifest
    if ($updatedInstaller) {
        Restart-UpdatedInstaller
    }
    $manifest = Read-Manifest
}

if ($VerifyOnly) {
    Test-Install -Manifest $manifest
}
elseif ($Server) {
    Install-ServerPack -Manifest $manifest
}
else {
    Stop-MinecraftLauncherProcesses
    Install-ClientPack -Manifest $manifest
}
