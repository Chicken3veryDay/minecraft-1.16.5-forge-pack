[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$PackRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$DropRoot = Join-Path $PackRoot 'pack-sources\CrazyCraft4\qol-mods'
$CacheRoot = Join-Path $PackRoot '_InstallCache\crazy-craft-4.0\qol-mods-autodownload'

$Mods = @(
    @{ Name='VeinMiner'; Side='both'; Patterns=@('VeinMiner*.jar','veinminer*.jar'); Modrinth=@('veinminer'); Curse=@('veinminer') },
    @{ Name='Mouse Tweaks'; Side='client'; Patterns=@('MouseTweaks*.jar','Mouse-Tweaks*.jar','mousetweaks*.jar'); Modrinth=@('mouse-tweaks','mousetweaks'); Curse=@('mouse-tweaks') },
    @{ Name='Fast Leaf Decay'; Side='both'; Patterns=@('FastLeafDecay*.jar','fastleafdecay*.jar','Fast-Leaf-Decay*.jar'); Modrinth=@('fast-leaf-decay','fastleafdecay'); Curse=@('fast-leaf-decay') },
    @{ Name='Morpheus'; Side='server'; Patterns=@('Morpheus*.jar','morpheus*.jar'); Modrinth=@('morpheus'); Curse=@('morpheus') },
    @{ Name='AromaBackup'; Side='server'; Patterns=@('AromaBackup*.jar','aromabackup*.jar'); Modrinth=@('aromabackup','aromabackup-backup'); Curse=@('aromabackup') },
    @{ Name='Aroma1997Core'; Side='server'; Patterns=@('Aroma1997Core*.jar','aroma1997core*.jar'); Modrinth=@('aroma1997core'); Curse=@('aroma1997core') },
    @{ Name='Stackie'; Side='server'; Patterns=@('Stackie*.jar','stackie*.jar'); Modrinth=@('stackie'); Curse=@('stackie') },
    @{ Name='TrashSlot'; Side='client'; Patterns=@('TrashSlot*.jar','trashslot*.jar','TrashSlot_*.jar'); Modrinth=@('trashslot','trash-slot'); Curse=@('trashslot') },
    @{ Name='BetterFps'; Side='client'; Patterns=@('BetterFps*.jar','betterfps*.jar'); Modrinth=@('betterfps','better-fps'); Curse=@('betterfps') },
    @{ Name='AutoTrash'; Side='client'; Patterns=@('AutoTrash*.jar','auto-trash*.jar','autotrash*.jar'); Modrinth=@('auto-trash','autotrash'); Curse=@('auto-trash','autotrash','auto-trash-slot') }
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

function Test-Jar([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    if ((Get-Item -LiteralPath $Path).Length -lt 4096) { return $false }
    $fs = [IO.File]::OpenRead($Path)
    try {
        $bytes = New-Object byte[] 4
        [void]$fs.Read($bytes,0,4)
        return ($bytes[0] -eq 0x50 -and $bytes[1] -eq 0x4B)
    } finally { $fs.Dispose() }
}

function Find-ExistingJar($Mod) {
    $destRoot = Join-Path $DropRoot $Mod.Side
    $bothRoot = Join-Path $DropRoot 'both'
    foreach ($root in @($destRoot,$bothRoot,$CacheRoot)) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($pattern in $Mod.Patterns) {
            $hit = @(Get-ChildItem -LiteralPath $root -File -Filter $pattern -ErrorAction SilentlyContinue | Select-Object -First 1)
            if ($hit.Count -gt 0 -and (Test-Jar $hit[0].FullName)) { return $hit[0].FullName }
        }
    }
    return $null
}

function Copy-ToDrop($Mod, [string]$JarPath) {
    $side = $Mod.Side
    if ($side -eq 'both') { $side = 'both' }
    $destDir = Join-Path $DropRoot $side
    Ensure-Directory -Path $destDir
    $dest = Join-Path $destDir (Split-Path -Leaf $JarPath)
    Copy-Item -LiteralPath $JarPath -Destination $dest -Force
    Write-StatusLine -Kind 'OK' -Message "Saved $($Mod.Name) to $dest"
}

function Download-File([string]$Url, [string]$Target) {
    Ensure-Directory -Path (Split-Path -Parent $Target)
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Target -MaximumRedirection 10 -Headers @{ 'User-Agent'='Mozilla/5.0 CrazyCraft4QoLInstaller' }
    return (Test-Jar $Target)
}

function Try-Modrinth($Mod) {
    foreach ($slug in $Mod.Modrinth) {
        try {
            $encoded = [Uri]::EscapeDataString($slug)
            $url = "https://api.modrinth.com/v2/project/$encoded/version?loaders=[%22forge%22]&game_versions=[%221.7.10%22]"
            $versions = Invoke-RestMethod -Method Get -Uri $url -Headers @{ 'User-Agent'='CrazyCraft4QoLInstaller/1.0' }
            if ($null -eq $versions -or @($versions).Count -eq 0) { continue }
            foreach ($version in @($versions)) {
                $files = @($version.files | Where-Object { $_.filename -like '*.jar' })
                if ($files.Count -eq 0) { continue }
                $primary = @($files | Where-Object { $_.primary -eq $true } | Select-Object -First 1)
                if ($primary.Count -eq 0) { $primary = @($files | Select-Object -First 1) }
                $file = $primary[0]
                $target = Join-Path $CacheRoot $file.filename
                if ((-not (Test-Path -LiteralPath $target)) -or $Force) {
                    Write-StatusLine -Kind 'RUN' -Message "Downloading $($Mod.Name) from Modrinth: $($file.filename)"
                    if (-not (Download-File -Url $file.url -Target $target)) { Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue; continue }
                }
                return $target
            }
        } catch { }
    }
    return $null
}

function Get-CurseFileIds([string]$Slug) {
    $urls = @(
        "https://www.curseforge.com/minecraft/mc-mods/$Slug/files/all?page=1&pageSize=50&version=1.7.10",
        "https://www.curseforge.com/minecraft/mc-mods/$Slug/files?version=1.7.10"
    )
    foreach ($url in $urls) {
        try {
            $html = (Invoke-WebRequest -UseBasicParsing -Uri $url -Headers @{ 'User-Agent'='Mozilla/5.0 CrazyCraft4QoLInstaller' }).Content
            $matches = [regex]::Matches($html, "/minecraft/mc-mods/$([regex]::Escape($Slug))/files/(?<id>\d+)")
            $ids = @($matches | ForEach-Object { $_.Groups['id'].Value } | Select-Object -Unique)
            if ($ids.Count -gt 0) { return $ids }
        } catch { }
    }
    return @()
}

function Try-CurseDownloadEndpoint([string]$Slug, [string]$FileId, [string]$Target) {
    $urls = @(
        "https://www.curseforge.com/minecraft/mc-mods/$Slug/download/$FileId",
        "https://www.curseforge.com/minecraft/mc-mods/$Slug/files/$FileId/download"
    )
    foreach ($url in $urls) {
        try {
            if (Download-File -Url $url -Target $Target) { return $true }
            Remove-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue
        } catch {
            Remove-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue
        }
    }
    return $false
}

function Try-CurseForge($Mod) {
    foreach ($slug in $Mod.Curse) {
        $ids = @(Get-CurseFileIds -Slug $slug)
        foreach ($id in $ids) {
            $target = Join-Path $CacheRoot ("$slug-$id.jar")
            if ((Test-Path -LiteralPath $target) -and -not $Force -and (Test-Jar $target)) { return $target }
            Write-StatusLine -Kind 'RUN' -Message "Trying CurseForge $($Mod.Name): $slug file $id"
            if (Try-CurseDownloadEndpoint -Slug $slug -FileId $id -Target $target) { return $target }
        }
    }
    return $null
}

Ensure-Directory -Path $CacheRoot
Ensure-Directory -Path (Join-Path $DropRoot 'both')
Ensure-Directory -Path (Join-Path $DropRoot 'client')
Ensure-Directory -Path (Join-Path $DropRoot 'server')

foreach ($mod in $Mods) {
    $existing = Find-ExistingJar -Mod $mod
    if ($existing -and -not $Force) {
        Write-StatusLine -Kind 'OK' -Message "$($mod.Name) already present: $(Split-Path -Leaf $existing)"
        continue
    }
    $jar = Try-Modrinth -Mod $mod
    if (-not $jar) { $jar = Try-CurseForge -Mod $mod }
    if ($jar) { Copy-ToDrop -Mod $mod -JarPath $jar }
    else { Write-StatusLine -Kind 'WARN' -Message "Could not auto-download a verified Forge 1.7.10 jar for $($mod.Name)." }
}

Write-StatusLine -Kind 'INFO' -Message 'Autodownload pass complete. Anything still missing likely needs a manual legacy CurseForge download.'
