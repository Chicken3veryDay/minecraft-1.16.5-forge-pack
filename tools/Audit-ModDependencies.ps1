[CmdletBinding()]
param(
    [string]$Root
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

function Read-JarEntryText {
    param(
        [string]$Path,
        [string]$EntryName
    )

    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $entry = $zip.GetEntry($EntryName)
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

function Read-JarModsToml {
    param([string]$Path)

    Read-JarEntryText -Path $Path -EntryName 'META-INF/mods.toml'
}

function Read-JarManifestVersion {
    param([string]$Path)

    $manifest = Read-JarEntryText -Path $Path -EntryName 'META-INF/MANIFEST.MF'
    if ([string]::IsNullOrWhiteSpace($manifest)) {
        return ''
    }

    foreach ($rawLine in ($manifest -split "\r?\n")) {
        $line = $rawLine.Trim()
        if ($line -match '^Implementation-Version:\s*(.+)$') {
            return $matches[1].Trim()
        }
    }

    return ''
}

function Convert-TomlScalar {
    param([string]$Value)

    $value = $Value.Trim()
    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
        ($value.StartsWith("'") -and $value.EndsWith("'"))) {
        return $value.Substring(1, $value.Length - 2)
    }

    if ($value -ieq 'true') { return $true }
    if ($value -ieq 'false') { return $false }
    return $value
}

function Get-ComparableVersionParts {
    param([string]$Version)

    if ([string]::IsNullOrWhiteSpace($Version) -or $Version.Contains('$')) {
        return @()
    }

    @([regex]::Matches($Version, '\d+') | ForEach-Object { [int]$_.Value })
}

function Compare-VersionStrings {
    param(
        [string]$Left,
        [string]$Right
    )

    $leftParts = @(Get-ComparableVersionParts -Version $Left)
    $rightParts = @(Get-ComparableVersionParts -Version $Right)
    if ($leftParts.Count -eq 0 -or $rightParts.Count -eq 0) {
        return $null
    }

    $count = [Math]::Max($leftParts.Count, $rightParts.Count)
    for ($i = 0; $i -lt $count; $i++) {
        $leftValue = if ($i -lt $leftParts.Count) { $leftParts[$i] } else { 0 }
        $rightValue = if ($i -lt $rightParts.Count) { $rightParts[$i] } else { 0 }

        if ($leftValue -lt $rightValue) { return -1 }
        if ($leftValue -gt $rightValue) { return 1 }
    }

    return 0
}

function Test-VersionInRange {
    param(
        [string]$Version,
        [string]$Range
    )

    if ([string]::IsNullOrWhiteSpace($Version) -or [string]::IsNullOrWhiteSpace($Range) -or
        $Version.Contains('$') -or $Range.Contains('$')) {
        return $true
    }

    $range = $Range.Trim()
    # Older Forge-era mods often use Maven-ish versions such as 1.16.4-53.3.
    # Comparing those correctly requires Forge's ComparableVersion semantics, so
    # this audit stays conservative and only enforces simple numeric ranges.
    if ($Version.Contains('-') -or $range.Contains('-')) {
        return $true
    }

    if ($range -match '^([\[\(])\s*([^,\]\)]*)\s*,\s*([^,\]\)]*)\s*([\]\)])$') {
        $lowerInclusive = $matches[1] -eq '['
        $lower = $matches[2].Trim()
        $upper = $matches[3].Trim()
        $upperInclusive = $matches[4] -eq ']'

        if (-not [string]::IsNullOrWhiteSpace($lower)) {
            $cmpLower = Compare-VersionStrings -Left $Version -Right $lower
            if ($null -eq $cmpLower) { return $true }
            if ($cmpLower -lt 0 -or (($cmpLower -eq 0) -and -not $lowerInclusive)) {
                return $false
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($upper)) {
            $cmpUpper = Compare-VersionStrings -Left $Version -Right $upper
            if ($null -eq $cmpUpper) { return $true }
            if ($cmpUpper -gt 0 -or (($cmpUpper -eq 0) -and -not $upperInclusive)) {
                return $false
            }
        }

        return $true
    }

    if ($range -match '^\[\s*([^\]]+)\s*\]$') {
        $cmpExact = Compare-VersionStrings -Left $Version -Right $matches[1].Trim()
        return ($null -eq $cmpExact -or $cmpExact -eq 0)
    }

    return $true
}

function Get-JarMetadata {
    param([string]$Path)

    $modsToml = Read-JarModsToml -Path $Path
    $manifestVersion = Read-JarManifestVersion -Path $Path
    $mods = [System.Collections.Generic.List[object]]::new()
    $dependencies = [System.Collections.Generic.List[object]]::new()
    $currentKind = $null
    $current = $null

    function Flush-Current {
        if ($null -eq $current) {
            return
        }

        if ($currentKind -eq 'mod') {
            $mods.Add([pscustomobject]$current) | Out-Null
        }
        elseif ($currentKind -eq 'dependency') {
            $dependencies.Add([pscustomobject]$current) | Out-Null
        }

        Set-Variable -Name currentKind -Value $null -Scope 1
        Set-Variable -Name current -Value $null -Scope 1
    }

    if ($null -ne $modsToml) {
        foreach ($rawLine in ($modsToml -split "\r?\n")) {
            $line = $rawLine.Trim()
            if ($line.Length -eq 0 -or $line.StartsWith('#')) {
                continue
            }

            if ($line -match '^\[\[mods\]\]') {
                Flush-Current
                $currentKind = 'mod'
                $current = [ordered]@{}
                continue
            }

            if ($line -match '^\[\[dependencies\.([^\]]+)\]\]') {
                Flush-Current
                $currentKind = 'dependency'
                $current = [ordered]@{ owner = $matches[1] }
                continue
            }

            if ($line -match '^\[\[') {
                Flush-Current
                continue
            }

            if ($null -ne $current -and $line -match '^([A-Za-z0-9_.-]+)\s*=\s*(.+)$') {
                $key = $matches[1]
                $value = $matches[2] -replace '\s+#.*$', ''
                $current[$key] = Convert-TomlScalar -Value $value
            }
        }

        Flush-Current
    }

    [pscustomobject]@{
        jar = [System.IO.Path]::GetFileName($Path)
        path = $Path
        hasModsToml = ($null -ne $modsToml)
        manifestVersion = $manifestVersion
        mods = @($mods)
        dependencies = @($dependencies)
    }
}

function Test-SideDependencies {
    param(
        [string]$SideName,
        [object[]]$Metadata
    )

    $modOwners = @{}
    $modVersions = @{}
    $duplicates = @()
    foreach ($meta in $Metadata) {
        foreach ($mod in @($meta.mods)) {
            if ([string]::IsNullOrWhiteSpace([string]$mod.modId)) {
                continue
            }

            $modId = ([string]$mod.modId).ToLowerInvariant()
            if ($modOwners.ContainsKey($modId)) {
                $duplicates += [pscustomobject]@{
                    modId = $modId
                    jars = @($modOwners[$modId], $meta.jar)
                }
            }
            else {
                $modOwners[$modId] = $meta.jar
                $version = [string]$mod.version
                if ($version -eq '${file.jarVersion}') {
                    $version = [string]$meta.manifestVersion
                }
                $modVersions[$modId] = $version
            }
        }
    }

    $ignoredModIds = @('forge', 'minecraft', 'java')
    $missing = @()
    $badVersions = @()
    foreach ($meta in $Metadata) {
        foreach ($dep in @($meta.dependencies)) {
            $mandatory = $false
            if ($dep.PSObject.Properties.Name -contains 'mandatory') {
                $mandatory = [bool]$dep.mandatory
            }

            if (-not $mandatory) {
                continue
            }

            $depId = ([string]$dep.modId).ToLowerInvariant()
            if ([string]::IsNullOrWhiteSpace($depId) -or $ignoredModIds -contains $depId) {
                continue
            }

            $depSide = ''
            if ($dep.PSObject.Properties.Name -contains 'side') {
                $depSide = ([string]$dep.side).ToUpperInvariant()
            }

            if ($SideName -eq 'Server' -and $depSide -eq 'CLIENT') {
                continue
            }
            if ($SideName -eq 'Client' -and $depSide -eq 'SERVER') {
                continue
            }

            if (-not $modOwners.ContainsKey($depId)) {
                $missing += [pscustomobject]@{
                    jar = $meta.jar
                    owner = $dep.owner
                    missingModId = $depId
                    versionRange = [string]$dep.versionRange
                    side = $depSide
                }
            }
            elseif ($dep.PSObject.Properties.Name -contains 'versionRange') {
                $actualVersion = [string]$modVersions[$depId]
                $versionRange = [string]$dep.versionRange
                if (-not (Test-VersionInRange -Version $actualVersion -Range $versionRange)) {
                    $badVersions += [pscustomobject]@{
                        jar = $meta.jar
                        owner = $dep.owner
                        dependencyModId = $depId
                        installedJar = $modOwners[$depId]
                        installedVersion = $actualVersion
                        requiredVersionRange = $versionRange
                        side = $depSide
                    }
                }
            }
        }
    }

    [pscustomobject]@{
        side = $SideName
        jarCount = @($Metadata).Count
        modIdCount = $modOwners.Count
        missingRequiredDependencies = @($missing | Sort-Object jar, missingModId)
        incompatibleRequiredDependencies = @($badVersions | Sort-Object jar, dependencyModId)
        duplicateModIds = @($duplicates | Sort-Object modId)
        jarsWithoutModsToml = @($Metadata | Where-Object { -not $_.hasModsToml } | Select-Object -ExpandProperty jar | Sort-Object)
    }
}

$results = foreach ($side in @('Client', 'Server')) {
    $folder = Join-Path $Root $side
    $metadata = Get-ChildItem -LiteralPath $folder -Filter '*.jar' -File |
        Sort-Object Name |
        ForEach-Object { Get-JarMetadata -Path $_.FullName }

    Test-SideDependencies -SideName $side -Metadata @($metadata)
}

$results | ConvertTo-Json -Depth 8
