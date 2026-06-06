[CmdletBinding()]
param(
    [string]$ClientPath = (Join-Path $env:APPDATA '.minecraft\crazy-craft-4.0-official'),
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$PackRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$DropRoot = Join-Path $PackRoot 'pack-sources\CrazyCraft4\qol-mods'
$ClientMods = Join-Path $ClientPath 'mods'

function Write-StatusLine([string]$Kind, [string]$Message) {
    switch ($Kind.ToUpperInvariant()) {
        'OK' { $label='[OK]  '; $color='Green' }
        'WARN' { $label='[WARN]'; $color='Yellow' }
        'RUN' { $label='[RUN] '; $color='Magenta' }
        'FAIL' { $label='[FAIL]'; $color='Red' }
        default { $label='[INFO]'; $color='Cyan' }
    }
    Write-Host $label -NoNewline -ForegroundColor $color
    Write-Host " $Message"
}

function Ensure-Directory([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}

function Test-ZipJar([string]$Path) {
    try {
        if (-not (Test-Path -LiteralPath $Path)) { return $false }
        if ((Get-Item -LiteralPath $Path).Length -lt 4096) { return $false }
        $stream = [IO.File]::OpenRead($Path)
        try {
            $bytes = New-Object byte[] 2
            [void]$stream.Read($bytes, 0, 2)
            return ($bytes[0] -eq 0x50 -and $bytes[1] -eq 0x4B)
        } finally { $stream.Dispose() }
    } catch { return $false }
}

function Get-JarMetadataText([string]$Path) {
    $texts = @()
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
        try {
            foreach ($entry in $zip.Entries) {
                if ($entry.FullName -match '(^|/)(mcmod\.info|mods\.toml|META-INF/mods\.toml|fabric\.mod\.json|version\.json|META-INF/MANIFEST\.MF)$') {
                    $reader = New-Object IO.StreamReader($entry.Open())
                    try { $texts += $reader.ReadToEnd() } finally { $reader.Dispose() }
                }
            }
        } finally { $zip.Dispose() }
    } catch { }
    return ($texts -join "`n")
}

function Test-Legacy1710Jar([string]$JarPath, [switch]$AllowLegacyNoVersion) {
    $name = [IO.Path]::GetFileName($JarPath)
    $lower = $name.ToLowerInvariant()
    if (-not (Test-ZipJar -Path $JarPath)) { return $false }
    if ($lower -match '(fabric|quilt|neoforge)') { return $false }
    if ($lower -match '1\.7\.10' -or $lower -match 'mc1\.7\.10') { return $true }
    if ($lower -match '(mc|minecraft|forge)[-_\. ]?1\.(8|9|10|11|12|13|14|15|16|17|18|19|20|21)(?!\d)') { return $false }
    if ($AllowLegacyNoVersion) { return $true }
    $meta = Get-JarMetadataText -Path $JarPath
    if ($meta -match '1\.7\.10' -or $meta -match 'mcversion.*1\.7\.10' -or $meta -match 'acceptedMinecraftVersions.*1\.7\.10') { return $true }
    return $false
}

function Find-QolJar([string[]]$Patterns) {
    $roots = @(
        (Join-Path $DropRoot 'both'),
        (Join-Path $DropRoot 'client'),
        (Join-Path $DropRoot 'server'),
        $DropRoot
    ) | Where-Object { Test-Path -LiteralPath $_ }

    foreach ($root in $roots) {
        foreach ($pattern in $Patterns) {
            $hits = @(Get-ChildItem -LiteralPath $root -File -Filter $pattern -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
            foreach ($hit in $hits) { return $hit.FullName }
        }
    }
    return $null
}

# These are required by the current server-side QoL set. They are installed on every client to avoid FML rejection.
$RequiredClientHandshakeQol = @(
    @{ Name='OreExcavation'; Patterns=@('OreExcavation*.jar','oreexcavation*.jar','Ore-Excavation*.jar'); AllowLegacyNoVersion=$true },
    @{ Name='LunatriusCore'; Patterns=@('LunatriusCore*.jar','lunatriuscore*.jar'); AllowLegacyNoVersion=$false },
    @{ Name='Aroma1997Core'; Patterns=@('Aroma1997Core*.jar','aroma1997core*.jar'); AllowLegacyNoVersion=$false },
    @{ Name='AromaBackup'; Patterns=@('AromaBackup*.jar','aromabackup*.jar'); AllowLegacyNoVersion=$false },
    @{ Name='Stackie'; Patterns=@('Stackie*.jar','stackie*.jar'); AllowLegacyNoVersion=$false },
    @{ Name='FastLeafDecay'; Patterns=@('FastLeafDecay*.jar','fastleafdecay*.jar','Fast-Leaf-Decay*.jar'); AllowLegacyNoVersion=$false },
    @{ Name='BetterFps'; Patterns=@('BetterFps-1.0.1.jar','betterfps-1.0.1.jar'); AllowLegacyNoVersion=$true }
)

Ensure-Directory -Path $ClientMods
Write-StatusLine -Kind 'INFO' -Message "Syncing Crazy Craft QoL/handshake client jars from $DropRoot"

$installed = @()
$missing = @()
$rejected = @()

foreach ($mod in $RequiredClientHandshakeQol) {
    $jar = Find-QolJar -Patterns ([string[]]$mod.Patterns)
    if ([string]::IsNullOrWhiteSpace($jar)) {
        $missing += $mod.Name
        continue
    }

    if (-not (Test-Legacy1710Jar -JarPath $jar -AllowLegacyNoVersion:([bool]$mod.AllowLegacyNoVersion))) {
        $rejected += "$(Split-Path -Leaf $jar)"
        continue
    }

    $dest = Join-Path $ClientMods (Split-Path -Leaf $jar)
    try {
        $srcFull = [IO.Path]::GetFullPath($jar)
        $dstFull = [IO.Path]::GetFullPath($dest)
        if ($srcFull -ieq $dstFull) {
            $installed += (Split-Path -Leaf $dest)
            continue
        }
    } catch { }

    if ((Test-Path -LiteralPath $dest) -and -not $Force) {
        $installed += (Split-Path -Leaf $dest)
        continue
    }

    Copy-Item -LiteralPath $jar -Destination $dest -Force
    Write-StatusLine -Kind 'OK' -Message "Client synced $($mod.Name): $(Split-Path -Leaf $jar)"
    $installed += (Split-Path -Leaf $dest)
}

if ($rejected.Count -gt 0) {
    Write-StatusLine -Kind 'WARN' -Message "Rejected wrong/unverified QoL jar(s): $($rejected -join ', ')"
}
if ($missing.Count -gt 0) {
    Write-StatusLine -Kind 'WARN' -Message "QoL handshake jar(s) missing from repo source folders: $($missing -join ', ')"
}
if ($installed.Count -gt 0) {
    Write-StatusLine -Kind 'OK' -Message "QoL/handshake client jars active: $($installed | Sort-Object -Unique -join ', ')"
}

# Final hard check for the known server-rejecting mod.
if (-not @(Get-ChildItem -LiteralPath $ClientMods -File -Filter 'OreExcavation*.jar' -ErrorAction SilentlyContinue).Count) {
    Write-StatusLine -Kind 'WARN' -Message 'OreExcavation is not active on this client. It will be rejected by the current server until the jar is present.'
}
