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
$ProgressPreference = 'SilentlyContinue'

$PackRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ManifestPath = Join-Path $PackRoot '.pack-manifest.json'
$MinecraftRoot = Join-Path $env:APPDATA '.minecraft'
$AssetExtractRoot = Join-Path $PackRoot '_pack-assets'

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "== $Message ==" -ForegroundColor Cyan
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

function Get-GitHubReleaseAssetFallbackUrls {
    param(
        [string]$AssetUrl,
        [string]$ArchiveName
    )

    if ([string]::IsNullOrWhiteSpace($AssetUrl) -or [string]::IsNullOrWhiteSpace($ArchiveName)) {
        return @()
    }

    $uri = [uri]$AssetUrl
    if ($uri.Host -notin @('github.com', 'www.github.com')) {
        return @()
    }

    $segments = @($uri.AbsolutePath.Trim('/') -split '/')
    if ($segments.Count -lt 2) {
        return @()
    }

    $owner = $segments[0]
    $repo = $segments[1]
    $apiUrl = "https://api.github.com/repos/$owner/$repo/releases?per_page=20"
    try {
        $releases = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing -Headers @{ 'User-Agent' = 'ForgeProjectEChaosPackInstaller' }
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
        Invoke-WebRequest -Uri $Url -OutFile $tempPath -UseBasicParsing

        if (-not [string]::IsNullOrWhiteSpace($ExpectedHash)) {
            $actual = Get-FileHashSha256 -Path $tempPath
            if ($actual -ne $ExpectedHash) {
                throw "Downloaded asset archive hash mismatch. Expected $ExpectedHash, got $actual."
            }
        }

        Move-Item -LiteralPath $tempPath -Destination $DestinationPath -Force
    }
    finally {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force
        }
    }
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
    Expand-Archive -LiteralPath $archivePath -DestinationPath $AssetExtractRoot -Force
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

function Get-PreferredJavaPath {
    $candidates = [System.Collections.Generic.List[string]]::new()

    $preferredRepoJava = Join-Path $PackRoot '_InstallCache\microsoft-jdk-17\jdk-17.0.19+10\bin\java.exe'
    if (Test-Path -LiteralPath $preferredRepoJava) {
        $candidates.Add($preferredRepoJava)
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

    foreach ($candidate in $candidates) {
        try {
            $previousErrorActionPreference = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            try {
                $versionOutput = & $candidate '-version' 2>&1
            }
            finally {
                $ErrorActionPreference = $previousErrorActionPreference
            }
            if ($LASTEXITCODE -ne 0) {
                continue
            }

            $match = [regex]::Match(($versionOutput | Out-String), 'version "?(?<major>\d+)')
            if (-not $match.Success) {
                continue
            }

            $major = [int]$match.Groups['major'].Value
            if ($major -ge 17) {
                return $candidate
            }
        }
        catch {
        }
    }

    throw "Could not find a Java runtime new enough to run the Forge installer. Install Java 17+ or keep the repo's bundled JDK cache."
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
    foreach ($item in @($Manifest.$Section)) {
        $source = Resolve-ManifestItemSource -Manifest $Manifest -Item $item
        $relative = Get-ManifestItemRelativePath -Item $item -Section $Section
        $target = Join-Path $Destination $relative
        $targetParent = Split-Path -Parent $target
        if (-not [string]::IsNullOrWhiteSpace($targetParent)) {
            Ensure-Directory -Path $targetParent
        }
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
}

function Assert-ManifestSectionTree {
    param(
        [object]$Manifest,
        [string]$Section,
        [string]$Destination
    )

    foreach ($item in @($Manifest.$Section)) {
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

$manifest = Read-Manifest
Write-Host "Forge 1.20.1 ProjectE chaos pack installer"
Write-Host "Pack root: $PackRoot"

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
