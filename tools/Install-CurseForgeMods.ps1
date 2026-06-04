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

$ApiBase = 'https://api.curse.tools/v1/cf'
$CacheRoot = Join-Path $Root '_InstallCache\CurseForge'
$ClientDir = Join-Path $Root 'Client'
$ServerDir = Join-Path $Root 'Server'
New-Item -ItemType Directory -Force -Path $CacheRoot | Out-Null

Add-Type -AssemblyName System.IO.Compression.FileSystem

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

function Get-InstalledModIds {
    $ids = @{}
    foreach ($folder in @($ClientDir, $ServerDir)) {
        if (-not (Test-Path -LiteralPath $folder)) {
            continue
        }

        foreach ($jar in Get-ChildItem -LiteralPath $folder -Filter '*.jar' -File) {
            foreach ($modId in Get-JarModIds -Path $jar.FullName) {
                if (-not $ids.ContainsKey($modId)) {
                    $ids[$modId] = [System.Collections.Generic.List[string]]::new()
                }
                $ids[$modId].Add($jar.FullName) | Out-Null
            }
        }
    }

    $ids
}

function Resolve-Project {
    param(
        [string]$Name,
        [string[]]$Slugs
    )

    foreach ($slug in @($Slugs)) {
        if ([string]::IsNullOrWhiteSpace($slug)) {
            continue
        }

        $encoded = [System.Uri]::EscapeDataString($slug)
        $search = Invoke-CurseApi -Path "mods/search?gameId=432&slug=$encoded"
        $matches = @($search.data | Where-Object { $_.classId -eq 6 -and $_.slug -eq $slug })
        if ($matches.Count -gt 0) {
            return $matches[0]
        }
    }

    $encodedName = [System.Uri]::EscapeDataString($Name)
    $fallback = Invoke-CurseApi -Path "mods/search?gameId=432&classId=6&searchFilter=$encodedName"
    $projects = @($fallback.data | Where-Object { $_.classId -eq 6 })
    if ($projects.Count -eq 0) {
        return $null
    }

    $exact = @($projects | Where-Object { $_.name -eq $Name })
    if ($exact.Count -gt 0) {
        return $exact[0]
    }

    return $projects[0]
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

function Test-CompatibleFile {
    param([object]$File)

    $versions = @($File.gameVersions)
    if (-not ($versions -contains '1.16.5')) {
        return $false
    }
    if ($versions -contains 'Fabric' -or $versions -contains 'Quilt' -or $versions -contains 'NeoForge') {
        return $false
    }
    if ($versions -contains 'Forge') {
        return $true
    }

    # Many older Forge-era CurseForge files only list the Minecraft version.
    return $true
}

function Select-CompatibleFile {
    param(
        [int]$ProjectId,
        [string]$Name
    )

    $files = @(Get-AllFiles -ProjectId $ProjectId | Where-Object { $_.isAvailable -and (Test-CompatibleFile -File $_) })
    if ($files.Count -eq 0) {
        return $null
    }

    $releaseOrder = if ($IncludeAlphaFallback) { @(1, 2, 3) } else { @(1, 2) }
    foreach ($releaseType in $releaseOrder) {
        $typed = @($files | Where-Object { [int]$_.releaseType -eq $releaseType } | Sort-Object {[datetime]$_.fileDate} -Descending)
        if ($typed.Count -gt 0) {
            return $typed[0]
        }
    }

    return @($files | Sort-Object {[datetime]$_.fileDate} -Descending)[0]
}

function Get-InstallSides {
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

function Download-File {
    param([object]$File)

    if ([string]::IsNullOrWhiteSpace([string]$File.downloadUrl)) {
        throw "No download URL for $($File.fileName)"
    }

    $path = Join-Path $CacheRoot $File.fileName
    if (-not (Test-Path -LiteralPath $path)) {
        Invoke-WebRequest -Uri $File.downloadUrl -OutFile $path -UseBasicParsing
    }

    $item = Get-Item -LiteralPath $path
    if ([int64]$File.fileLength -gt 0 -and [int64]$item.Length -ne [int64]$File.fileLength) {
        Remove-Item -LiteralPath $path -Force
        Invoke-WebRequest -Uri $File.downloadUrl -OutFile $path -UseBasicParsing
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

$seeds = @(
    @{ Name = 'Corpse'; Slugs = @('corpse') },
    @{ Name = 'Pick Up Notifier'; Slugs = @('pick-up-notifier') },
    @{ Name = 'Goblin Traders'; Slugs = @('goblin-traders') },
    @{ Name = 'Client Crafting'; Slugs = @('client-crafting') },
    @{ Name = 'Max Health Fix'; Slugs = @('max-health-fix') },
    @{ Name = 'Chunky'; Slugs = @('chunky-pregenerator', 'chunky') },
    @{ Name = 'Gateways to Eternity'; Slugs = @('gateways-to-eternity') },
    @{ Name = 'Inventory Sorter'; Slugs = @('inventory-sorter') },
    @{ Name = 'Farsight'; Slugs = @('farsight') },
    @{ Name = 'Smarter Farmers'; Slugs = @('smarter-farmers-farmers-replant', 'smarter-farmers') },
    @{ Name = 'Bosses of Mass Destruction'; Slugs = @('bosses-of-mass-destruction-forge-neoforge', 'bosses-of-mass-destruction') },
    @{ Name = 'Aquamirae'; Slugs = @('ob-aquamirae', 'aquamirae-forge', 'aquamirae') },
    @{ Name = 'Silent Gear'; Slugs = @('silent-gear') },
    @{ Name = 'Item Collectors'; Slugs = @('item-collectors') },
    @{ Name = 'All the Ores'; Slugs = @('all-the-ores', 'ato') },
    @{ Name = 'Bygone Nether'; Slugs = @('bygonenether') },
    @{ Name = 'Realm RPG: Fallen Adventurers'; Slugs = @('realm-rpg-fallen-adventurers') },
    @{ Name = 'The Hordes'; Slugs = @('the-hordes') },
    @{ Name = 'It Takes a Pillage'; Slugs = @('it-takes-a-pillage') },
    @{ Name = 'Chunk Sending'; Slugs = @('chunk-sending-forge-fabric', 'chunk-sending') },
    @{ Name = 'Better Fps - Render Distance'; Slugs = @('better-fps-render-distance') },
    @{ Name = 'Relics'; Slugs = @('relics') },
    @{ Name = 'Legendary Tooltips'; Slugs = @('legendary-tooltips') },
    @{ Name = 'Mobs Properties Randomness'; Slugs = @('mobs-properties-randomness') },
    @{ Name = 'Remodifier'; Slugs = @('remodifier') },
    @{ Name = 'Dungeons Dimensions: Nether'; Slugs = @('dungeons-dimensions-nether') },
    @{ Name = 'ImmediatelyFast'; Slugs = @('immediatelyfast') }
)

$installedModIds = Get-InstalledModIds
$processedProjects = @{}
$queue = [System.Collections.Queue]::new()
$results = [System.Collections.Generic.List[object]]::new()

foreach ($seed in $seeds) {
    $queue.Enqueue([pscustomobject]@{
        name = $seed.Name
        slugs = $seed.Slugs
        dependencyOf = ''
        projectId = 0
    })
}

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
        $project = Resolve-Project -Name $item.name -Slugs @($item.slugs)
        if ($null -eq $project) {
            $results.Add([pscustomobject]@{
                name = $item.name
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

    if ([int]$project.classId -ne 6) {
        $results.Add([pscustomobject]@{
            name = $project.name
            slug = $project.slug
            status = 'skipped'
            reason = "Project classId $($project.classId) is not a Minecraft mod."
            dependencyOf = $item.dependencyOf
        }) | Out-Null
        continue
    }

    $file = Select-CompatibleFile -ProjectId ([int]$project.id) -Name $project.name
    if ($null -eq $file) {
        $results.Add([pscustomobject]@{
            name = $project.name
            slug = $project.slug
            projectId = $project.id
            status = 'incompatible'
            reason = 'No 1.16.5 Forge-compatible file found.'
            dependencyOf = $item.dependencyOf
        }) | Out-Null
        continue
    }

    foreach ($dep in @($file.dependencies | Where-Object { [int]$_.relationType -eq 3 })) {
        $queue.Enqueue([pscustomobject]@{
            name = "dependency:$($dep.modId)"
            slugs = @()
            dependencyOf = $project.name
            projectId = [int]$dep.modId
        })
    }

    $cachePath = Download-File -File $file
    $modIds = @(Get-JarModIds -Path $cachePath)
    if ($modIds.Count -eq 0) {
        $results.Add([pscustomobject]@{
            name = $project.name
            slug = $project.slug
            projectId = $project.id
            file = $file.fileName
            status = 'skipped'
            reason = 'Downloaded file did not contain META-INF/mods.toml.'
            dependencyOf = $item.dependencyOf
        }) | Out-Null
        continue
    }

    $existing = @($modIds | Where-Object { $_ -notin @('minecraft', 'forge', 'java') -and $installedModIds.ContainsKey($_) })
    if ($existing.Count -gt 0) {
        $results.Add([pscustomobject]@{
            name = $project.name
            slug = $project.slug
            projectId = $project.id
            file = $file.fileName
            modIds = $modIds
            status = 'already-installed'
            reason = "Existing mod ID(s): $($existing -join ', ')"
            dependencyOf = $item.dependencyOf
        }) | Out-Null
        continue
    }

    $sides = @(Get-InstallSides -File $file)
    foreach ($side in $sides) {
        $destDir = if ($side -eq 'Server') { $ServerDir } else { $ClientDir }
        Copy-Item -LiteralPath $cachePath -Destination (Join-Path $destDir $file.fileName) -Force
    }

    foreach ($modId in $modIds) {
        if (-not $installedModIds.ContainsKey($modId)) {
            $installedModIds[$modId] = [System.Collections.Generic.List[string]]::new()
        }
        foreach ($side in $sides) {
            $sideDir = $ClientDir
            if ($side -eq 'Server') {
                $sideDir = $ServerDir
            }
            $installedModIds[$modId].Add((Join-Path $sideDir $file.fileName)) | Out-Null
        }
    }

    $results.Add([pscustomobject]@{
        name = $project.name
        slug = $project.slug
        projectId = $project.id
        file = $file.fileName
        modIds = $modIds
        sides = $sides
        status = 'installed'
        dependencyOf = $item.dependencyOf
        sha256 = Get-FileHashString -Path $cachePath -Algorithm SHA256
    }) | Out-Null
}

$results | ConvertTo-Json -Depth 8
