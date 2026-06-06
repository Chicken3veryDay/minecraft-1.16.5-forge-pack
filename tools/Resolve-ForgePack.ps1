[CmdletBinding()]
param(
    [string]$Root,
    [switch]$IncludeAlphaFallback
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}

$Root = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Root)
$ApiBase = 'https://api.curse.tools/v1/cf'
$SourceRoot = Join-Path $Root 'pack-sources'
$BlueprintPath = Join-Path $SourceRoot 'pack-blueprint.json'
$CacheRoot = Join-Path $Root '_InstallCache\CurseForge'
$ClientModsDir = Join-Path $SourceRoot 'Client\mods'
$ServerModsDir = Join-Path $SourceRoot 'Server\mods'
$ResultsPath = Join-Path $Root '_InstallCache\resolve-forge-pack-results.json'

New-Item -ItemType Directory -Force -Path $CacheRoot, $ClientModsDir, $ServerModsDir | Out-Null

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "== $Message ==" -ForegroundColor Cyan
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

function Invoke-CurseApi {
    param([string]$Path)
    $uri = if ($Path.StartsWith('http')) { $Path } else { "$ApiBase/$Path" }
    Invoke-RestMethod -Uri $uri -UseBasicParsing
}

function Read-JarModsToml {
    param([string]$Path)

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $entry = $zip.GetEntry('META-INF/mods.toml')
        if ($null -eq $entry) {
            return $null
        }

        $stream = $entry.Open()
        try {
            $reader = [System.IO.StreamReader]::new($stream)
            try {
                return $reader.ReadToEnd()
            }
            finally {
                $reader.Dispose()
            }
        }
        finally {
            $stream.Dispose()
        }
    }
    finally {
        $zip.Dispose()
    }
}

function Get-JarModIds {
    param([string]$Path)

    $modsToml = Read-JarModsToml -Path $Path
    if ([string]::IsNullOrWhiteSpace($modsToml)) {
        return @()
    }

    $modIds = [System.Collections.Generic.List[string]]::new()
    $inModBlock = $false
    foreach ($rawLine in ($modsToml -split "\r?\n")) {
        $line = $rawLine.Trim()
        if ($line -match '^\[\[mods\]\]') {
            $inModBlock = $true
            continue
        }
        if ($line -match '^\[\[') {
            $inModBlock = $false
            continue
        }
        if ($inModBlock -and $line -match '^modId\s*=\s*["'']([^"'']+)["'']') {
            $id = $matches[1].ToLowerInvariant()
            if ($id -notin @('minecraft', 'forge', 'java')) {
                $modIds.Add($id) | Out-Null
            }
        }
    }

    @($modIds | Sort-Object -Unique)
}

function Get-AllFiles {
    param([int]$ProjectId)

    $all = [System.Collections.Generic.List[object]]::new()
    $pageSize = 50
    $index = 0
    do {
        $page = Invoke-CurseApi -Path "mods/$ProjectId/files?pageSize=$pageSize&index=$index"
        foreach ($file in @($page.data)) {
            $all.Add($file) | Out-Null
        }

        $total = [int]$page.pagination.totalCount
        $index += $pageSize
    } while ($index -lt $total)

    @($all)
}

function Get-RequestedSides {
    param([string]$Side)

    switch ($Side) {
        'client' { @('Client') }
        'server' { @('Server') }
        default { @('Client', 'Server') }
    }
}

function Get-FileSides {
    param([object]$File)

    $versions = @($File.gameVersions)
    $hasClient = $versions -contains 'Client'
    $hasServer = $versions -contains 'Server'

    if ($hasClient -and -not $hasServer) {
        return @('Client')
    }
    if ($hasServer -and -not $hasClient) {
        return @('Server')
    }

    return @('Client', 'Server')
}

function Get-EffectiveSides {
    param(
        [string[]]$RequestedSides,
        [string[]]$AllowedSides
    )

    $effective = @($RequestedSides | Where-Object { $_ -in $AllowedSides } | Select-Object -Unique)
    if ($effective.Count -gt 0) {
        return $effective
    }

    return @($AllowedSides | Select-Object -Unique)
}

function Test-CompatibleFile {
    param(
        [object]$File,
        [string]$MinecraftVersion,
        [string]$Loader
    )

    $versions = @($File.gameVersions)
    if (-not $File.isAvailable) {
        return $false
    }
    if (-not ($versions -contains $MinecraftVersion)) {
        return $false
    }
    if ($Loader -eq 'Forge' -and ($versions -contains 'Forge')) {
        return $true
    }
    if ($versions -contains 'Fabric' -or $versions -contains 'Quilt' -or $versions -contains 'NeoForge') {
        return $false
    }

    # Some CurseForge files for Forge-compatible projects only tag the
    # Minecraft version and omit the loader string. Treat those as Forge
    # candidates unless they explicitly advertise a conflicting loader.
    return $true
}

function Select-CompatibleFile {
    param(
        [int]$ProjectId,
        [string]$MinecraftVersion,
        [string]$Loader
    )

    $files = @(Get-AllFiles -ProjectId $ProjectId | Where-Object { Test-CompatibleFile -File $_ -MinecraftVersion $MinecraftVersion -Loader $Loader })
    if ($files.Count -eq 0) {
        return $null
    }

    $releaseOrder = if ($IncludeAlphaFallback) { @(1, 2, 3) } else { @(1, 2) }
    foreach ($releaseType in $releaseOrder) {
        $typed = @(
            $files |
                Where-Object { [int]$_.releaseType -eq $releaseType } |
                Sort-Object { [datetime]$_.fileDate } -Descending
        )
        if ($typed.Count -gt 0) {
            return $typed[0]
        }
    }

    @($files | Sort-Object { [datetime]$_.fileDate } -Descending)[0]
}

function Resolve-Project {
    param(
        [string]$Name,
        [string]$Slug
    )

    if (-not [string]::IsNullOrWhiteSpace($Slug)) {
        $search = Invoke-CurseApi -Path ("mods/search?gameId=432&slug=" + [System.Uri]::EscapeDataString($Slug))
        $matches = @($search.data | Where-Object { $_.classId -eq 6 -and $_.slug -eq $Slug })
        if ($matches.Count -gt 0) {
            return $matches[0]
        }
    }

    $fallback = Invoke-CurseApi -Path ("mods/search?gameId=432&classId=6&searchFilter=" + [System.Uri]::EscapeDataString($Name))
    $projects = @($fallback.data | Where-Object { $_.classId -eq 6 })
    if ($projects.Count -eq 0) {
        return $null
    }

    $exact = @($projects | Where-Object { $_.name -eq $Name })
    if ($exact.Count -gt 0) {
        return $exact[0]
    }

    $slugMatch = @($projects | Where-Object { $_.slug -eq $Slug })
    if ($slugMatch.Count -gt 0) {
        return $slugMatch[0]
    }

    return $projects[0]
}

function Download-File {
    param([object]$File)

    if ([string]::IsNullOrWhiteSpace([string]$File.downloadUrl)) {
        throw "No download URL for $($File.fileName)"
    }

    $path = Join-Path $CacheRoot $File.fileName
    $downloadToCache = {
        $tempPath = Join-Path $CacheRoot ("download-{0}.tmp" -f ([guid]::NewGuid().ToString('n')))
        try {
            Invoke-WebRequest -Uri $File.downloadUrl -OutFile $tempPath -UseBasicParsing
            if (Test-Path -LiteralPath $path) {
                Remove-Item -LiteralPath $path -Force
            }
            [System.IO.File]::Move($tempPath, $path)
        }
        finally {
            if (Test-Path -LiteralPath $tempPath) {
                Remove-Item -LiteralPath $tempPath -Force
            }
        }
    }

    if (-not (Test-Path -LiteralPath $path)) {
        & $downloadToCache
    }

    $item = Get-Item -LiteralPath $path
    if ([int64]$File.fileLength -gt 0 -and [int64]$item.Length -ne [int64]$File.fileLength) {
        Remove-Item -LiteralPath $path -Force
        & $downloadToCache
        $item = Get-Item -LiteralPath $path
    }

    if ([int64]$File.fileLength -gt 0 -and [int64]$item.Length -ne [int64]$File.fileLength) {
        throw "Downloaded size mismatch for $($File.fileName). Expected $($File.fileLength), got $($item.Length)."
    }

    $sha1 = @($File.hashes | Where-Object { [int]$_.algo -eq 1 } | Select-Object -First 1).value
    if (-not [string]::IsNullOrWhiteSpace([string]$sha1)) {
        $actual = Get-FileHashString -Path $path -Algorithm SHA1
        if ($actual -ne ([string]$sha1).ToLowerInvariant()) {
            throw "SHA-1 mismatch for $($File.fileName). Expected $sha1, got $actual."
        }
    }

    $path
}

function Reset-ModDirectories {
    foreach ($dir in @($ClientModsDir, $ServerModsDir)) {
        Get-ChildItem -LiteralPath $dir -File -Filter '*.jar' -ErrorAction SilentlyContinue | Remove-Item -Force
        Get-ChildItem -LiteralPath $dir -File -Filter 'README*' -ErrorAction SilentlyContinue | Remove-Item -Force
    }
    Get-ChildItem -LiteralPath (Join-Path $SourceRoot 'Server') -File -Filter 'forge-*-installer.jar' -ErrorAction SilentlyContinue | Remove-Item -Force
    foreach ($path in @(
        (Join-Path $SourceRoot 'Config\README.md'),
        (Join-Path $SourceRoot 'Root\README.md'),
        (Join-Path $SourceRoot 'Shaderpacks\README.md')
    )) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force
        }
    }
}

function Save-Blueprint {
    param([object]$Blueprint)
    $Blueprint | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $BlueprintPath -Encoding UTF8
}

function Set-BlueprintProperty {
    param(
        [object]$Blueprint,
        [string]$Name,
        [object]$Value
    )

    $existing = $Blueprint.PSObject.Properties[$Name]
    if ($null -ne $existing) {
        $existing.Value = $Value
        return
    }

    $Blueprint | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
}

if (-not (Test-Path -LiteralPath $BlueprintPath)) {
    throw "Missing blueprint: $BlueprintPath"
}

$blueprint = Get-Content -LiteralPath $BlueprintPath -Raw | ConvertFrom-Json
Reset-ModDirectories

$installedModIds = @{}
$processedProjects = @{}
$queue = [System.Collections.Queue]::new()
$results = [System.Collections.Generic.List[object]]::new()

foreach ($seed in @($blueprint.modSeeds)) {
    $queue.Enqueue([pscustomobject]@{
        name = $seed.name
        slug = $seed.slug
        dependencyOf = ''
        projectId = 0
        requestedSides = @(Get-RequestedSides -Side ([string]$seed.side))
        seedCategory = $seed.category
        seedRole = $seed.role
        seedRequired = [bool]$seed.required
    })
}

Write-Step "Resolving and downloading Forge 1.20.1 mods"
while ($queue.Count -gt 0) {
    $item = $queue.Dequeue()
    $project = $null

    if ([int]$item.projectId -gt 0) {
        if ($processedProjects.ContainsKey([string]$item.projectId)) {
            continue
        }
        $project = (Invoke-CurseApi -Path "mods/$($item.projectId)").data
    }
    else {
        $project = Resolve-Project -Name $item.name -Slug $item.slug
        if ($null -eq $project) {
            $results.Add([pscustomobject]@{
                name = $item.name
                slug = $item.slug
                status = 'not-found'
                reason = 'No CurseForge Minecraft mod project was found.'
                dependencyOf = $item.dependencyOf
            }) | Out-Null
            continue
        }
    }

    $projectKey = [string]$project.id
    if ($processedProjects.ContainsKey($projectKey)) {
        continue
    }
    $processedProjects[$projectKey] = $true

    $file = Select-CompatibleFile -ProjectId ([int]$project.id) -MinecraftVersion ([string]$blueprint.minecraft) -Loader ([string]$blueprint.platform)
    if ($null -eq $file) {
        $results.Add([pscustomobject]@{
            name = $project.name
            slug = $project.slug
            projectId = $project.id
            status = 'incompatible'
            reason = "No $($blueprint.minecraft) $($blueprint.platform)-compatible file found."
            dependencyOf = $item.dependencyOf
        }) | Out-Null
        continue
    }

    foreach ($dep in @($file.dependencies | Where-Object { [int]$_.relationType -eq 3 })) {
        $queue.Enqueue([pscustomobject]@{
            name = "dependency:$($dep.modId)"
            slug = ''
            dependencyOf = $project.name
            projectId = [int]$dep.modId
            requestedSides = @($item.requestedSides)
            seedCategory = $item.seedCategory
            seedRole = 'dependency'
            seedRequired = $true
        })
    }

    $cachePath = Download-File -File $file
    $modIds = @(Get-JarModIds -Path $cachePath)
    $allowedSides = @(Get-FileSides -File $file)
    $effectiveSides = @(Get-EffectiveSides -RequestedSides @($item.requestedSides) -AllowedSides $allowedSides)

    foreach ($side in $effectiveSides) {
        $destDir = if ($side -eq 'Server') { $ServerModsDir } else { $ClientModsDir }
        Copy-Item -LiteralPath $cachePath -Destination (Join-Path $destDir $file.fileName) -Force
    }

    foreach ($modId in $modIds) {
        if (-not $installedModIds.ContainsKey($modId)) {
            $installedModIds[$modId] = [System.Collections.Generic.List[string]]::new()
        }
        foreach ($side in $effectiveSides) {
            $sideDir = if ($side -eq 'Server') { $ServerModsDir } else { $ClientModsDir }
            $installedModIds[$modId].Add((Join-Path $sideDir $file.fileName)) | Out-Null
        }
    }

    $results.Add([pscustomobject]@{
        name = $project.name
        slug = $project.slug
        projectId = $project.id
        fileName = $file.fileName
        fileDate = $file.fileDate
        releaseType = $file.releaseType
        versionDisplay = $file.displayName
        modIds = $modIds
        requestedSides = @($item.requestedSides)
        installedSides = $effectiveSides
        category = $item.seedCategory
        role = $item.seedRole
        required = [bool]$item.seedRequired
        dependencyOf = $item.dependencyOf
        source = 'CurseForge API via curse.tools'
        downloadUrl = $file.downloadUrl
        sha256 = Get-FileHashString -Path $cachePath -Algorithm SHA256
        status = 'installed'
    }) | Out-Null
}

Write-Step "Downloading Forge server installer"
$forgeVersion = [string]$blueprint.forgeVersion
$forgeInstallerName = "forge-$($blueprint.minecraft)-$forgeVersion-installer.jar"
$forgeInstallerPath = Join-Path (Join-Path $SourceRoot 'Server') $forgeInstallerName
$forgeInstallerUrl = "https://maven.minecraftforge.net/net/minecraftforge/forge/$($blueprint.minecraft)-$forgeVersion/$forgeInstallerName"
Invoke-WebRequest -Uri $forgeInstallerUrl -OutFile $forgeInstallerPath -UseBasicParsing
$forgeInstallerSha256 = Get-FileHashString -Path $forgeInstallerPath -Algorithm SHA256

Set-BlueprintProperty -Blueprint $blueprint -Name 'serverBootstrap' -Value ([pscustomobject]@{
    forgeInstaller = [pscustomobject]@{
        minecraft = $blueprint.minecraft
        forgeVersion = $forgeVersion
        fileName = $forgeInstallerName
        url = $forgeInstallerUrl
        sha256 = $forgeInstallerSha256
        source = 'Forge Maven'
    }
})
Set-BlueprintProperty -Blueprint $blueprint -Name 'lastResolvedAt' -Value ((Get-Date).ToUniversalTime().ToString('o'))
Set-BlueprintProperty -Blueprint $blueprint -Name 'resolvedMods' -Value (@($results | Where-Object { $_.status -eq 'installed' } | Sort-Object category, name))
Save-Blueprint -Blueprint $blueprint
$results | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ResultsPath -Encoding UTF8

$installed = @($results | Where-Object { $_.status -eq 'installed' })
$problems = @($results | Where-Object { $_.status -ne 'installed' })
Write-Host "Installed $($installed.Count) projects."
if ($problems.Count -gt 0) {
    Write-Warning "Encountered $($problems.Count) non-installed project result(s). See $ResultsPath"
}
Write-Host "Updated blueprint: $BlueprintPath"
Write-Host "Results: $ResultsPath"
