[CmdletBinding()]
param(
    [switch]$Client,
    [switch]$Server,
    [string]$ClientPath = (Join-Path $env:APPDATA '.minecraft\crazy-craft-4.0-official'),
    [string]$ServerPath,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$PackRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$DropRoot = Join-Path $PackRoot 'pack-sources\CrazyCraft4\qol-mods'
$CacheRoot = Join-Path $PackRoot '_InstallCache\crazy-craft-4.0\qol-mods'

$Mods = @(
    @{ Name='VeinMiner'; Side='both'; Patterns=@('VeinMiner*.jar','veinminer*.jar'); Slugs=@('veinminer'); Notes='Configure for ores/logs only; keep stone/dirt/netherrack disabled.' },
    @{ Name='OreExcavation'; Side='both'; Patterns=@('OreExcavation*.jar','oreexcavation*.jar','Ore-Excavation*.jar'); Slugs=@('ore-excavation','oreexcavation'); Notes='VeinMiner alternative. Install only if jar metadata/filename proves Minecraft 1.7.10.' },
    @{ Name='Mouse Tweaks'; Side='client'; Patterns=@('MouseTweaks*.jar','Mouse-Tweaks*.jar','mousetweaks*.jar'); Slugs=@('mouse-tweaks','mousetweaks'); Notes='Client-only inventory controls.' },
    @{ Name='Fast Leaf Decay'; Side='both'; Patterns=@('FastLeafDecay*.jar','fastleafdecay*.jar','Fast-Leaf-Decay*.jar'); Slugs=@('fast-leaf-decay','fastleafdecay'); Notes='Faster leaf cleanup after tree chopping.' },
    @{ Name='LunatriusCore'; Side='server'; Patterns=@('LunatriusCore*.jar','lunatriuscore*.jar'); Slugs=@('lunatriuscore'); Notes='Required dependency for AromaBackup on Minecraft 1.7.10.' },
    @{ Name='AromaBackup'; Side='server'; Patterns=@('AromaBackup*.jar','aromabackup*.jar'); Slugs=@('aromabackup','aromabackup-backup'); Requires=@('LunatriusCore'); Notes='Server backups. Requires a matching 1.7.10 LunatriusCore jar.' },
    @{ Name='Aroma1997Core'; Side='server'; Patterns=@('Aroma1997Core*.jar','aroma1997core*.jar'); Slugs=@('aroma1997core'); Notes='Dependency for some Aroma1997 mods.' },
    @{ Name='Morpheus'; Side='server'; Patterns=@('Morpheus*.jar','morpheus*.jar'); Slugs=@('morpheus'); Notes='Multiplayer sleep voting.' },
    @{ Name='Stackie'; Side='server'; Patterns=@('Stackie*.jar','stackie*.jar'); Slugs=@('stackie'); Notes='Stacks dropped items to reduce entity spam. Test before relying on it.' },
    @{ Name='TrashSlot'; Side='client'; Patterns=@('TrashSlot*.jar','trashslot*.jar','TrashSlot_*.jar'); Slugs=@('trashslot','trash-slot'); Notes='Client trash slot if a confirmed 1.7.10 Forge build is available.' },
    @{ Name='AutoTrash'; Side='client'; Patterns=@('AutoTrash*.jar','auto-trash*.jar','autotrash*.jar'); Slugs=@('auto-trash','autotrash'); Notes='Client auto-trash/trash filtering only if a confirmed 1.7.10 Forge build is available.' },
    @{ Name='BetterFps'; Side='client'; Patterns=@('BetterFps*.jar','betterfps*.jar'); Slugs=@('betterfps','better-fps'); Notes='Optional client FPS tweak. FastCraft is already installed, so test before keeping it.' }
)

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

function Test-Legacy1710Jar($Mod, [string]$JarPath) {
    $name = [IO.Path]::GetFileName($JarPath)
    $lower = $name.ToLowerInvariant()

    if (-not (Test-ZipJar -Path $JarPath)) {
        Write-StatusLine -Kind 'WARN' -Message "Rejected $($Mod.Name): not a valid jar/zip file: $name"
        return $false
    }

    if ($lower -match '(fabric|quilt|neoforge)') {
        Write-StatusLine -Kind 'WARN' -Message "Rejected $($Mod.Name): wrong loader: $name"
        return $false
    }

    # Accept explicit 1.7.10 filenames before any wrong-version test. Prevents false hits against mod versions.
    if ($lower -match '1\.7\.10' -or $lower -match 'mc1\.7\.10') { return $true }

    # Reject only explicit Minecraft/loader version labels, not arbitrary mod versions like OreExcavation-1.1.134.jar.
    if ($lower -match '(mc|minecraft|forge)[-_\. ]?1\.(8|9|10|11|12|13|14|15|16|17|18|19|20|21)(?!\d)') {
        Write-StatusLine -Kind 'WARN' -Message "Rejected $($Mod.Name): explicit wrong Minecraft version: $name"
        return $false
    }

    switch ($Mod.Name) {
        'BetterFps' {
            if ($lower -eq 'betterfps-1.0.1.jar') { return $true }
            Write-StatusLine -Kind 'WARN' -Message "Rejected BetterFps until proven 1.7.10: $name"
            return $false
        }
        default {
            $meta = Get-JarMetadataText -Path $JarPath
            if ($meta -match '1\.7\.10' -or $meta -match 'mcversion.*1\.7\.10' -or $meta -match 'acceptedMinecraftVersions.*1\.7\.10') { return $true }
            Write-StatusLine -Kind 'WARN' -Message "Rejected $($Mod.Name): filename/metadata does not prove Minecraft 1.7.10: $name"
            return $false
        }
    }
}

function Get-ModrinthJar([string[]]$Slugs, [string]$Name) {
    Ensure-Directory -Path $CacheRoot
    foreach ($slug in $Slugs) {
        try {
            $encoded = [Uri]::EscapeDataString($slug)
            $url = "https://api.modrinth.com/v2/project/$encoded/version?loaders=[%22forge%22]&game_versions=[%221.7.10%22]"
            $versions = Invoke-RestMethod -Method Get -Uri $url -Headers @{ 'User-Agent'='CrazyCraft4QoLInstaller/1.0' }
            if ($null -eq $versions -or $versions.Count -eq 0) { continue }
            foreach ($version in @($versions)) {
                $files = @($version.files | Where-Object { $_.filename -like '*.jar' })
                if ($files.Count -eq 0) { continue }
                $primary = @($files | Where-Object { $_.primary -eq $true } | Select-Object -First 1)
                if ($primary.Count -eq 0) { $primary = @($files | Select-Object -First 1) }
                $file = $primary[0]
                $target = Join-Path $CacheRoot $file.filename
                if (-not (Test-Path -LiteralPath $target) -or $Force) {
                    Write-StatusLine -Kind 'RUN' -Message "Downloading $Name from Modrinth slug '$slug': $($file.filename)"
                    Invoke-WebRequest -UseBasicParsing -Uri $file.url -OutFile $target -Headers @{ 'User-Agent'='CrazyCraft4QoLInstaller/1.0' }
                }
                return $target
            }
        } catch { continue }
    }
    return $null
}

function Find-LocalJar($Mod, [string]$Side) {
    $roots = @(
        (Join-Path $DropRoot 'both'),
        (Join-Path $DropRoot $Side),
        $DropRoot,
        $CacheRoot
    )
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($pattern in $Mod.Patterns) {
            $hits = @(Get-ChildItem -LiteralPath $root -File -Filter $pattern -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
            foreach ($hit in $hits) {
                if (Test-Legacy1710Jar -Mod $Mod -JarPath $hit.FullName) { return $hit.FullName }
            }
        }
    }
    return $null
}

function Install-JarToMods([string]$JarPath, [string]$TargetRoot, [string]$Name) {
    $modsRoot = Join-Path $TargetRoot 'mods'
    Ensure-Directory -Path $modsRoot
    $destination = Join-Path $modsRoot (Split-Path -Leaf $JarPath)

    try {
        $sourceFull = [IO.Path]::GetFullPath($JarPath)
        $destFull = [IO.Path]::GetFullPath($destination)
        if ($sourceFull -ieq $destFull) {
            Write-StatusLine -Kind 'OK' -Message "$Name already in target mods folder: $(Split-Path -Leaf $destination)"
            return
        }
    } catch { }

    if ((Test-Path -LiteralPath $destination) -and -not $Force) {
        Write-StatusLine -Kind 'OK' -Message "$Name already installed: $(Split-Path -Leaf $destination)"
        return
    }
    Copy-Item -LiteralPath $JarPath -Destination $destination -Force
    Write-StatusLine -Kind 'OK' -Message "Installed $Name -> $destination"
}

function Write-QoLConfigNotes([string]$TargetRoot, [string]$Side) {
    $configRoot = Join-Path $TargetRoot 'config'
    Ensure-Directory -Path $configRoot
    $notes = @(
        'Crazy Craft QoL configuration notes',
        '====================================',
        '',
        'Only jars that clearly validate as Forge/Minecraft 1.7.10 should be installed.',
        'AromaBackup requires LunatriusCore 1.7.10. If LunatriusCore is missing, keep AromaBackup disabled and use OS/systemd backups instead.',
        'VeinMiner/OreExcavation: allow ores and logs only; keep stone, dirt, sand, gravel, netherrack, and end stone disabled.',
        'FastLeafDecay: safe default behavior is fine.',
        'Morpheus: recommended sleep vote threshold is 50% for 3 players.',
        'Stackie: keep conservative stack radius/settings if installed.',
        'AutoTrash/TrashSlot: client-only convenience mods; keep server folder clean.',
        '',
        "Generated for side: $Side"
    )
    Set-Content -LiteralPath (Join-Path $configRoot 'crazycraft-qol-notes.txt') -Value $notes -Encoding ASCII
}

function Install-QoLForSide([string]$Side, [string]$TargetRoot) {
    if ([string]::IsNullOrWhiteSpace($TargetRoot)) { return }
    Ensure-Directory -Path $TargetRoot
    Write-StatusLine -Kind 'INFO' -Message "QoL target [$Side]: $TargetRoot"

    $resolved = @{}
    foreach ($mod in $Mods) {
        if ($mod.Side -ne 'both' -and $mod.Side -ne $Side) { continue }

        if ($mod.ContainsKey('Requires')) {
            $missingDeps = @($mod.Requires | Where-Object { -not $resolved.ContainsKey($_) })
            if ($missingDeps.Count -gt 0) {
                Write-StatusLine -Kind 'WARN' -Message "Skipping $($mod.Name): missing dependency jar(s): $($missingDeps -join ', '). $($mod.Notes)"
                continue
            }
        }

        $jar = Find-LocalJar -Mod $mod -Side $Side
        if ([string]::IsNullOrWhiteSpace($jar)) {
            $candidate = Get-ModrinthJar -Slugs $mod.Slugs -Name $mod.Name
            if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Legacy1710Jar -Mod $mod -JarPath $candidate)) { $jar = $candidate }
        }
        if ([string]::IsNullOrWhiteSpace($jar)) {
            Write-StatusLine -Kind 'WARN' -Message "Missing $($mod.Name). Drop a confirmed 1.7.10 Forge jar into $DropRoot\$Side or $DropRoot\both. $($mod.Notes)"
            continue
        }
        Install-JarToMods -JarPath $jar -TargetRoot $TargetRoot -Name $mod.Name
        $resolved[$mod.Name] = $jar
    }
    Write-QoLConfigNotes -TargetRoot $TargetRoot -Side $Side
}

if (-not $Client -and -not $Server) { $Client = $true }
if ($Client) { Install-QoLForSide -Side 'client' -TargetRoot $ClientPath }
if ($Server) {
    if ([string]::IsNullOrWhiteSpace($ServerPath)) { throw 'Provide -ServerPath when installing server QoL mods.' }
    Install-QoLForSide -Side 'server' -TargetRoot $ServerPath
}

Write-StatusLine -Kind 'INFO' -Message 'QoL install pass finished. Wrong-version jars and missing-dependency installs are rejected.'
