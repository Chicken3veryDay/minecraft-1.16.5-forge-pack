[CmdletBinding()]
param(
    [string]$Root,
    [string]$ClientPackZip,
    [string]$ServerPackZip
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}

$Root = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Root)
$DownloadRoot = Join-Path $Root '_DownloadCache\crazycraft-0.12.9'
$ClientPackUrl = 'https://edge.forgecdn.net/files/8069/957/Crazy%20Craft%20Updated-0.12.9.zip'
$ServerPackUrl = 'https://edge.forgecdn.net/files/8070/007/CCU%20Server%20Pack%20Bat%20-%200.12.9.zip'
$ClientPackSha256 = '6940b0862291366a0f5d102f5dc1dc9e64dcedbb72024ff26bed0b867ca9fe1b'
$ServerPackSha256 = '0c7b14464dd659f2d11166822b146f2ab755d3992b4fb0ea029bd1a097991ad3'
$ApiBase = 'https://api.curse.tools/v1/cf'

if ([string]::IsNullOrWhiteSpace($ClientPackZip)) {
    $ClientPackZip = Join-Path $DownloadRoot 'Crazy Craft Updated-0.12.9.zip'
}
if ([string]::IsNullOrWhiteSpace($ServerPackZip)) {
    $ServerPackZip = Join-Path $DownloadRoot 'CCU Server Pack Bat - 0.12.9.zip'
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Reset-Directory {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Get-FileHashString {
    param(
        [string]$Path,
        [ValidateSet('SHA1', 'SHA256')]
        [string]$Algorithm
    )

    if (Get-Command Get-FileHash -ErrorAction SilentlyContinue) {
        return (Get-FileHash -LiteralPath $Path -Algorithm $Algorithm).Hash.ToLowerInvariant()
    }

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $hasher = if ($Algorithm -eq 'SHA1') {
            [System.Security.Cryptography.SHA1]::Create()
        }
        else {
            [System.Security.Cryptography.SHA256]::Create()
        }

        try {
            return (($hasher.ComputeHash($stream) | ForEach-Object { $_.ToString('x2') }) -join '')
        }
        finally {
            $hasher.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Invoke-WithRetry {
    param(
        [scriptblock]$ScriptBlock,
        [string]$Label,
        [int]$Attempts = 4
    )

    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        try {
            return & $ScriptBlock
        }
        catch {
            if ($attempt -ge $Attempts) {
                throw
            }

            Write-Host "$Label failed (attempt $attempt of $Attempts): $($_.Exception.Message)"
            Start-Sleep -Seconds ([Math]::Min(12, 2 * $attempt))
        }
    }
}

function Invoke-DownloadFile {
    param(
        [string]$Uri,
        [string]$OutFile,
        [string]$Label,
        [int64]$ExpectedLength = 0
    )

    $parent = Split-Path -Parent $OutFile
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        Ensure-Directory -Path $parent
    }

    $needsDownload = -not (Test-Path -LiteralPath $OutFile)
    if (-not $needsDownload -and $ExpectedLength -gt 0) {
        $needsDownload = ([int64](Get-Item -LiteralPath $OutFile).Length -ne $ExpectedLength)
    }

    if ($needsDownload) {
        $tempPath = "$OutFile.download"
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force
        }

        Invoke-WithRetry -Label "Download $Label" -ScriptBlock {
            Invoke-WebRequest -Uri $Uri -OutFile $tempPath -UseBasicParsing
        } | Out-Null

        Move-Item -LiteralPath $tempPath -Destination $OutFile -Force
    }

    if ($ExpectedLength -gt 0) {
        $actualLength = [int64](Get-Item -LiteralPath $OutFile).Length
        if ($actualLength -ne $ExpectedLength) {
            throw "Downloaded size mismatch for ${Label}: expected $ExpectedLength, got $actualLength."
        }
    }
}

function Ensure-Archive {
    param(
        [string]$Path,
        [string]$Url,
        [string]$Sha256,
        [string]$Label
    )

    Ensure-Directory -Path (Split-Path -Parent $Path)
    $download = -not (Test-Path -LiteralPath $Path)
    if (-not $download) {
        $download = (Get-FileHashString -Path $Path -Algorithm SHA256) -ne $Sha256
    }

    if ($download) {
        Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
        Invoke-DownloadFile -Uri $Url -OutFile $Path -Label $Label
    }

    $actual = Get-FileHashString -Path $Path -Algorithm SHA256
    if ($actual -ne $Sha256) {
        throw "$Label SHA-256 mismatch. Expected $Sha256, got $actual."
    }
}

function Expand-ZipFresh {
    param(
        [string]$ZipPath,
        [string]$Destination
    )

    Reset-Directory -Path $Destination
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $Destination)
}

function Copy-DirectoryContents {
    param(
        [string]$Source,
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        return
    }

    Ensure-Directory -Path $Destination
    Get-ChildItem -LiteralPath $Source -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $Destination -Recurse -Force
    }
}

function Get-CurseFileMetadata {
    param(
        [int]$ProjectId,
        [int]$FileId
    )

    $uri = "$ApiBase/mods/$ProjectId/files/$FileId"
    $response = Invoke-WithRetry -Label "Curse metadata $ProjectId/$FileId" -ScriptBlock {
        Invoke-RestMethod -Uri $uri -UseBasicParsing
    }
    $response.data
}

function Get-ExpectedSha1 {
    param([object]$File)

    $hash = @($File.hashes | Where-Object { [int]$_.algo -eq 1 } | Select-Object -First 1)
    if ($hash.Count -eq 0) {
        return ''
    }

    ([string]$hash[0].value).ToLowerInvariant()
}

function Test-FileMatchesMetadata {
    param(
        [string]$Path,
        [object]$File
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    $item = Get-Item -LiteralPath $Path
    if ([int64]$File.fileLength -gt 0 -and [int64]$item.Length -ne [int64]$File.fileLength) {
        return $false
    }

    $sha1 = Get-ExpectedSha1 -File $File
    if (-not [string]::IsNullOrWhiteSpace($sha1)) {
        return (Get-FileHashString -Path $Path -Algorithm SHA1) -eq $sha1
    }

    return $true
}

function Copy-VerifiedModFile {
    param(
        [object]$File,
        [hashtable]$ServerModsByName,
        [string]$CacheRoot,
        [string]$ClientDir
    )

    $fileName = [string]$File.fileName
    if ([string]::IsNullOrWhiteSpace($fileName)) {
        throw "Curse file metadata did not include fileName for file ID $($File.id)."
    }

    $targetPath = Join-Path $ClientDir $fileName
    if (Test-FileMatchesMetadata -Path $targetPath -File $File) {
        return [pscustomobject]@{ Name = $fileName; Source = 'existing' }
    }

    if ($ServerModsByName.ContainsKey($fileName)) {
        $serverPath = [string]$ServerModsByName[$fileName]
        if (Test-FileMatchesMetadata -Path $serverPath -File $File) {
            Copy-Item -LiteralPath $serverPath -Destination $targetPath -Force
            return [pscustomobject]@{ Name = $fileName; Source = 'server-pack' }
        }
    }

    if ([string]::IsNullOrWhiteSpace([string]$File.downloadUrl)) {
        throw "No download URL for $fileName."
    }

    $cacheName = "$($File.modId)-$($File.id)-$fileName"
    $cachePath = Join-Path $CacheRoot $cacheName
    if (-not (Test-FileMatchesMetadata -Path $cachePath -File $File)) {
        Remove-Item -LiteralPath $cachePath -Force -ErrorAction SilentlyContinue
        Invoke-DownloadFile -Uri ([string]$File.downloadUrl) -OutFile $cachePath -Label $fileName -ExpectedLength ([int64]$File.fileLength)
    }

    if (-not (Test-FileMatchesMetadata -Path $cachePath -File $File)) {
        throw "Downloaded file did not match metadata: $fileName"
    }

    Copy-Item -LiteralPath $cachePath -Destination $targetPath -Force
    [pscustomobject]@{ Name = $fileName; Source = 'download' }
}

Ensure-Archive -Path $ClientPackZip -Url $ClientPackUrl -Sha256 $ClientPackSha256 -Label 'Crazy Craft Updated client pack'
Ensure-Archive -Path $ServerPackZip -Url $ServerPackUrl -Sha256 $ServerPackSha256 -Label 'Crazy Craft Updated server pack'

$clientDir = Join-Path $Root 'Client'
$configDir = Join-Path $Root 'Config'
$rootDir = Join-Path $Root 'Root'
$serverDir = Join-Path $Root 'Server'
$shaderpacksDir = Join-Path $Root 'Shaderpacks'
$tempClientDir = Join-Path $DownloadRoot 'client-expanded'
$cacheRoot = Join-Path $Root '_InstallCache\CurseForgeExact'

Reset-Directory -Path $clientDir
Reset-Directory -Path $configDir
Reset-Directory -Path $rootDir
Reset-Directory -Path $serverDir
Reset-Directory -Path $shaderpacksDir
Ensure-Directory -Path $cacheRoot

Write-Host "Extracting official Crazy Craft server pack..."
Expand-ZipFresh -ZipPath $ServerPackZip -Destination $serverDir

$serverIncompatibleMods = @(
    'enhanced_boss_bars-1.16.5-1.0.0.jar'
)
foreach ($modName in $serverIncompatibleMods) {
    $modPath = Join-Path (Join-Path $serverDir 'mods') $modName
    if (Test-Path -LiteralPath $modPath) {
        Remove-Item -LiteralPath $modPath -Force
        Write-Host "Removed server-incompatible mod from Server payload: $modName"
    }
}

$serverIncompatibleConfigs = @(
    'enhanced_boss_bars-common.toml'
)
foreach ($configName in $serverIncompatibleConfigs) {
    $configPath = Join-Path (Join-Path $serverDir 'config') $configName
    if (Test-Path -LiteralPath $configPath) {
        Remove-Item -LiteralPath $configPath -Force
        Write-Host "Removed server-incompatible config from Server payload: $configName"
    }
}

Write-Host "Extracting client overrides..."
Expand-ZipFresh -ZipPath $ClientPackZip -Destination $tempClientDir
$overridesDir = Join-Path $tempClientDir 'overrides'
Copy-DirectoryContents -Source (Join-Path $overridesDir 'config') -Destination $configDir
foreach ($folderName in @('defaultconfigs', 'kubejs', 'mods')) {
    $source = Join-Path $overridesDir $folderName
    if (Test-Path -LiteralPath $source) {
        Copy-Item -LiteralPath $source -Destination (Join-Path $rootDir $folderName) -Recurse -Force
    }
}

$manifestPath = Join-Path $tempClientDir 'manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ([string]$manifest.minecraft.version -ne '1.16.5') {
    throw "Unexpected Minecraft version in client manifest: $($manifest.minecraft.version)"
}

$loader = @($manifest.minecraft.modLoaders | Where-Object { $_.primary } | Select-Object -First 1)
if ($loader.Count -eq 0 -or [string]$loader[0].id -ne 'forge-36.2.35') {
    throw "Unexpected mod loader in client manifest: $($loader | ConvertTo-Json -Compress)"
}

$serverModsByName = @{}
foreach ($jar in @(Get-ChildItem -LiteralPath (Join-Path $serverDir 'mods') -Filter '*.jar' -File -ErrorAction Stop)) {
    $serverModsByName[$jar.Name] = $jar.FullName
}

Write-Host "Resolving and copying exact client mod files..."
$results = [System.Collections.Generic.List[object]]::new()
$seenTargets = @{}
$index = 0
$manifestFiles = @($manifest.files)
foreach ($manifestFile in $manifestFiles) {
    $index++
    $projectId = [int]$manifestFile.projectID
    $fileId = [int]$manifestFile.fileID
    $file = Get-CurseFileMetadata -ProjectId $projectId -FileId $fileId
    $targetKey = ([string]$file.fileName).ToLowerInvariant()
    if ($seenTargets.ContainsKey($targetKey)) {
        throw "Duplicate client target file name in manifest: $($file.fileName)"
    }
    $seenTargets[$targetKey] = $true

    $result = Copy-VerifiedModFile -File $file -ServerModsByName $serverModsByName -CacheRoot $cacheRoot -ClientDir $clientDir
    $results.Add([pscustomobject]@{
        Index = $index
        ProjectId = $projectId
        FileId = $fileId
        Name = $result.Name
        Source = $result.Source
    }) | Out-Null

    if (($index % 25) -eq 0 -or $index -eq $manifestFiles.Count) {
        Write-Host "Processed $index / $($manifestFiles.Count) client files..."
    }
}

$metadataPath = Join-Path $DownloadRoot 'resolved-client-files.json'
$results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $metadataPath -Encoding UTF8

$sourceCounts = $results | Group-Object Source | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }
Write-Host ""
Write-Host "Crazy Craft asset folders rebuilt."
Write-Host "Client files: $(@(Get-ChildItem -LiteralPath $clientDir -File).Count)"
Write-Host "Server files: $(@(Get-ChildItem -LiteralPath $serverDir -Recurse -File).Count)"
Write-Host "Sources: $($sourceCounts -join ', ')"
Write-Host "Resolved metadata: $metadataPath"
