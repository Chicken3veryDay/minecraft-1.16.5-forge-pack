[CmdletBinding()]
param(
    [switch]$Client,
    [switch]$Server,
    [string]$ClientPath = (Join-Path $env:APPDATA '.minecraft\crazy-craft-4.0-official'),
    [string]$ServerPath,
    [switch]$VerifyOnly,
    [switch]$DownloadOnly,
    [switch]$Force,
    [switch]$Diagnose,
    [switch]$MenuFpsSafeMode,
    [switch]$RestoreMenuFpsMods,
    [int]$MenuFpsBatch = 0,
    [switch]$NoPrompt
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'

$PackRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$MinecraftRoot = Join-Path $env:APPDATA '.minecraft'
$CacheRoot = Join-Path $PackRoot '_InstallCache\crazy-craft-4.0'
$JavaRoot = Join-Path $PackRoot '_InstallCache\temurin-jdk8'
$RequiredModsPath = Join-Path $PackRoot 'pack-sources\CrazyCraft4\mods.required.txt'
$PackName = 'Crazy Craft 4.0 Official'
$ProfileKey = 'crazy-craft-4.0-official'
$ForgeVersionId = '1.7.10-Forge10.13.4.1558-1.7.10'
$ClientFpsDisabledMods = @(
    'Controlling.jar',
    'Hats.jar',
    'HatStand.jar',
    'InventoryTweaksdev.jar',
    'journeymappunlimited.jar',
    'Waila.jar'
)
$MenuFpsDiagnosticRootName = 'mods.disabled-diagnostic'
$MenuFpsDiagnosticBatches = @(
    @{
        Id = 1
        Name = 'fastcraft-render-hook'
        Description = 'FastCraft compatibility and render-hook test'
        Mods = @('fastcraft.jar', 'FastCraft*.jar')
    },
    @{
        Id = 2
        Name = 'client-render-overlays'
        Description = 'Client-only overlays, hats, maps, inventory hooks, and iChun render toys'
        Mods = @('Controlling.jar', 'InventoryTweaksdev.jar', 'journeymappunlimited.jar', 'Waila.jar', 'Hats.jar', 'HatStand.jar', 'PortalGunbeta.jar', 'GravityGun.jar')
    },
    @{
        Id = 3
        Name = 'model-heavy-content'
        Description = 'Menu/model-heavy content suspects'
        Mods = @('Decocraft.jar', 'PTRModelLib*.jar', 'Legends.jar', 'CustomNpcs.jar', 'MobProperties.jar', 'hbmBETA.jar')
    },
    @{
        Id = 4
        Name = 'large-content-suspects'
        Description = 'Larger content/worldgen suspects for menu-only diagnosis'
        Mods = @('HardcoreEnderExpansionMCv.jar', 'TragicMC.jar', 'Origin.jar', 'OreSpawn*.jar', 'MCHeli*.jar', 'MCheli*.jar', 'WelcomeToTheJungle.jar', 'MutantCreatures.jar')
    }
)
$BrokenDownloadDisabledRootName = 'mods.disabled-broken-downloads'
$PortalGunSoundPack = @{
    Name = 'PortalGunSounds.pak'
    Url = 'https://repo.creeperhost.net/ichun/assets/pg1.7.10/PortalGunSounds.pak'
    Size = 14885449
    Md5 = '12d76a36e95288b9e2ee9146f2e20ecd'
}
$NotEnoughItemsClientMod = @{
    Name = 'NotEnoughItems-1.7.10-1.0.5.120-universal.jar'
    Url = 'https://cdn.modrinth.com/data/TmYVaklx/versions/4ZISyGrt/NotEnoughItems-1.7.10-1.0.5.120-universal.jar'
    Size = 513136
    Sha256 = '3ebbc2f82b61812aa158375005a47da4d450bec870860fcbf015a64de74cde1c'
    TargetSubdir = 'mods\1.7.10'
    TriggerMods = @('hbmBETA.jar', 'NEIAddons*.jar', 'neiIntegration*.jar', 'NEIIntegration*.jar')
}
$ForgeInstallerUrl = 'https://maven.minecraftforge.net/net/minecraftforge/forge/1.7.10-10.13.4.1558-1.7.10/forge-1.7.10-10.13.4.1558-1.7.10-installer.jar'
$ForgeUniversalUrl = 'https://maven.minecraftforge.net/net/minecraftforge/forge/1.7.10-10.13.4.1558-1.7.10/forge-1.7.10-10.13.4.1558-1.7.10-universal.jar'
$ClientZip = @{
    Name = 'CrazyCraft4ClientPayload.zip'
    Url = 'https://vl4.voidswrath.com/releases/CrazyCraft4Server.zip'
    Size = 729602057
    Sha256 = 'eae8930d4a83bafcc32681b285dc0c663faa6a4a505550b5d254031a5e377c97'
}
$ServerZip = @{
    Name = 'CrazyCraft4Server.zip'
    Url = 'https://vl4.voidswrath.com/releases/CrazyCraft4Server.zip'
    Size = 729602057
    Sha256 = 'eae8930d4a83bafcc32681b285dc0c663faa6a4a505550b5d254031a5e377c97'
}
$script:CompletionItems = @()
$script:FailureSummary = $null
$script:ProgressRenderState = @{}

function Write-Rule([string]$Title = '', [string]$Color = 'DarkCyan') {
    $width = 72
    $line = '=' * $width
    Write-Host ''
    Write-Host $line -ForegroundColor $Color
    if (-not [string]::IsNullOrWhiteSpace($Title)) {
        Write-Host $Title -ForegroundColor Cyan
        Write-Host $line -ForegroundColor $Color
    }
}

function Write-StatusLine([string]$Kind, [string]$Message) {
    switch ($Kind.ToUpperInvariant()) {
        'OK' { $label = '[OK]  '; $color = 'Green' }
        'WARN' { $label = '[WARN]'; $color = 'Yellow' }
        'FAIL' { $label = '[FAIL]'; $color = 'Red' }
        'RUN' { $label = '[RUN] '; $color = 'Magenta' }
        default { $label = '[INFO]'; $color = 'Cyan' }
    }
    Write-Host $label -NoNewline -ForegroundColor $color
    Write-Host " $Message"
}

function Write-KeyValue([string]$Name, $Value) {
    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { $text = '(not found)' }
    Write-Host ("  {0,-28} {1}" -f ($Name + ':'), $text)
}

function Write-CommandHint([string]$Command) {
    Write-StatusLine -Kind 'RUN' -Message $Command
}

function Write-InstallerHeader {
    Write-Rule -Title "$PackName installer"
    Write-KeyValue -Name 'Minecraft' -Value '1.7.10'
    Write-KeyValue -Name 'Forge' -Value "10.13.4.1558 ($ForgeVersionId)"
    Write-KeyValue -Name 'Pack root' -Value $PackRoot
    Write-Host ''
}

function Add-Completion([string]$Message) {
    if (-not [string]::IsNullOrWhiteSpace($Message)) {
        $script:CompletionItems += $Message
    }
}

function Write-CompletionSummary {
    Write-Rule -Title 'Installer summary'
    if ($script:CompletionItems.Count -eq 0) {
        Write-StatusLine -Kind 'INFO' -Message 'No install changes were completed.'
    } else {
        foreach ($item in $script:CompletionItems) {
            Write-StatusLine -Kind 'OK' -Message $item
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($script:FailureSummary)) {
        Write-StatusLine -Kind 'FAIL' -Message $script:FailureSummary
    }
    Write-Host ''
}

function Write-Step([string]$Message) {
    Write-Rule -Title $Message
    Write-Progress -Id 1 -Activity $PackName -Status $Message -PercentComplete 0
}

function Test-ConsoleProgress {
    try {
        return [Environment]::UserInteractive -and -not [Console]::IsOutputRedirected
    } catch {
        return $false
    }
}

function Format-ByteRate([double]$BytesPerSecond) {
    if ($BytesPerSecond -ge 1GB) { return ('{0:N1} GB/s' -f ($BytesPerSecond / 1GB)) }
    if ($BytesPerSecond -ge 1MB) { return ('{0:N1} MB/s' -f ($BytesPerSecond / 1MB)) }
    if ($BytesPerSecond -ge 1KB) { return ('{0:N1} KB/s' -f ($BytesPerSecond / 1KB)) }
    return ('{0:N0} B/s' -f $BytesPerSecond)
}

function Format-ShortDuration([double]$Seconds) {
    if ($Seconds -lt 0 -or [double]::IsNaN($Seconds) -or [double]::IsInfinity($Seconds)) { return '--:--' }
    $span = [TimeSpan]::FromSeconds([Math]::Max(0, $Seconds))
    if ($span.TotalHours -ge 1) { return ('{0}:{1:00}:{2:00}' -f [int]$span.TotalHours, $span.Minutes, $span.Seconds) }
    return ('{0:00}:{1:00}' -f $span.Minutes, $span.Seconds)
}

function Write-ConsoleProgressLine([string]$Activity, [string]$Status, [int]$Percent, [int]$Id, [switch]$Force) {
    if (-not (Test-ConsoleProgress)) { return }

    $now = Get-Date
    $state = $script:ProgressRenderState[$Id]
    if ($null -ne $state -and -not $Force -and (($now - $state.LastRender).TotalMilliseconds -lt 250)) {
        return
    }

    $bounded = [Math]::Max(0, [Math]::Min(100, $Percent))
    $width = 28
    $filled = [int][Math]::Floor(($bounded / 100) * $width)
    $empty = $width - $filled
    $filledText = if ($filled -gt 0) { '#' * $filled } else { '' }
    $emptyText = if ($empty -gt 0) { '-' * $empty } else { '' }
    $label = if ($Activity.Length -gt 31) { $Activity.Substring(0, 31) } else { $Activity }
    $prefix = "`r{0,-31} [" -f $label
    $suffix = "] {0,3}% {1}" -f $bounded, $Status
    $plainLength = $prefix.Length + $width + $suffix.Length
    $lastLength = if ($null -ne $state) { [int]$state.LastLength } else { 0 }
    $padding = if ($lastLength -gt $plainLength) { ' ' * ($lastLength - $plainLength) } else { '' }

    Write-Host -NoNewline $prefix
    Write-Host -NoNewline $filledText -ForegroundColor Green
    Write-Host -NoNewline $emptyText -ForegroundColor DarkGray
    Write-Host -NoNewline ($suffix + $padding)
    $script:ProgressRenderState[$Id] = [pscustomobject]@{ LastRender = $now; LastLength = [Math]::Max($plainLength, $lastLength) }
}

function Write-PackProgress([string]$Activity, [string]$Status, [int]$Percent, [int]$Id = 2) {
    $bounded = [Math]::Max(0, [Math]::Min(100, $Percent))
    Write-Progress -Id $Id -Activity $Activity -Status $Status -PercentComplete $bounded
    Write-ConsoleProgressLine -Activity $Activity -Status $Status -Percent $bounded -Id $Id
}

function Complete-PackProgress([string]$Activity, [int]$Id = 2) {
    Write-Progress -Id $Id -Activity $Activity -Completed
    if ($script:ProgressRenderState.ContainsKey($Id)) {
        Write-ConsoleProgressLine -Activity $Activity -Status 'complete' -Percent 100 -Id $Id -Force
        Write-Host ''
        $script:ProgressRenderState.Remove($Id)
    }
}

function Ensure-Directory([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Remove-DirectoryIfPresent([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
}

function Stop-MinecraftProcesses {
    $targets = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -in @('Minecraft.exe', 'MinecraftLauncher.exe') -or
        (($_.Name -in @('java.exe', 'javaw.exe')) -and ([string]$_.CommandLine -match 'crazy-craft-4\.0-official|1\.7\.10-Forge10\.13\.4\.1558'))
    })
    if ($targets.Count -eq 0) { return }
    Write-StatusLine -Kind 'WARN' -Message 'Closing Minecraft/Launcher so profile updates are applied.'
    foreach ($process in $targets) {
        try {
            Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
        } catch {
        }
    }
    Start-Sleep -Seconds 2
}

function Get-FileHashString([string]$Path, [string]$Algorithm) {
    if (Get-Command Get-FileHash -ErrorAction SilentlyContinue) {
        return (Get-FileHash -LiteralPath $Path -Algorithm $Algorithm).Hash.ToLowerInvariant()
    }

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        switch ($Algorithm.ToUpperInvariant()) {
            'MD5' { $hasher = [System.Security.Cryptography.MD5]::Create() }
            'SHA1' { $hasher = [System.Security.Cryptography.SHA1]::Create() }
            default { $hasher = [System.Security.Cryptography.SHA256]::Create() }
        }
        try {
            return (($hasher.ComputeHash($stream) | ForEach-Object { $_.ToString('x2') }) -join '')
        } finally {
            $hasher.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
}

function Test-ExpectedFile([string]$Path, [long]$Size, [string]$Sha256) {
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    if ((Get-Item -LiteralPath $Path).Length -ne $Size) { return $false }
    return (Get-FileHashString -Path $Path -Algorithm SHA256) -eq $Sha256.ToLowerInvariant()
}

function Invoke-DownloadFile {
    param(
        [string]$Url,
        [string]$DestinationPath,
        [long]$ExpectedSize = 0,
        [string]$Sha256 = '',
        [string]$Activity = 'Downloading'
    )

    if ($ExpectedSize -gt 0 -and -not [string]::IsNullOrWhiteSpace($Sha256) -and (Test-ExpectedFile -Path $DestinationPath -Size $ExpectedSize -Sha256 $Sha256)) {
        return
    }
    if ($ExpectedSize -eq 0 -and [string]::IsNullOrWhiteSpace($Sha256) -and (Test-Path -LiteralPath $DestinationPath)) {
        return
    }

    Ensure-Directory -Path (Split-Path -Parent $DestinationPath)
    $tempPath = "$DestinationPath.download"
    if (Test-Path -LiteralPath $tempPath) {
        Remove-Item -LiteralPath $tempPath -Force
    }

    Write-StatusLine -Kind 'INFO' -Message $Activity
    Write-KeyValue -Name 'URL' -Value $Url
    $request = [System.Net.HttpWebRequest]::Create($Url)
    $request.UserAgent = 'CrazyCraft4PortableInstaller'
    $response = $request.GetResponse()
    try {
        $total = [int64]$response.ContentLength
        $read = [int64]0
        $started = Get-Date
        $buffer = New-Object byte[] (1024 * 1024)
        $stream = $response.GetResponseStream()
        $file = [System.IO.File]::Open($tempPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try {
            while (($count = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $file.Write($buffer, 0, $count)
                $read += $count
                $elapsedSeconds = [Math]::Max(0.001, ((Get-Date) - $started).TotalSeconds)
                $speed = $read / $elapsedSeconds
                if ($total -gt 0) {
                    $remainingSeconds = if ($speed -gt 0) { ($total - $read) / $speed } else { -1 }
                    $status = "{0:N1} / {1:N1} MB | {2} | ETA {3}" -f ($read / 1MB), ($total / 1MB), (Format-ByteRate -BytesPerSecond $speed), (Format-ShortDuration -Seconds $remainingSeconds)
                    Write-PackProgress -Activity $Activity -Status $status -Percent ([int](($read * 100) / $total))
                } else {
                    $status = "{0:N1} MB | {1}" -f ($read / 1MB), (Format-ByteRate -BytesPerSecond $speed)
                    Write-PackProgress -Activity $Activity -Status $status -Percent 0
                }
            }
        } finally {
            $file.Dispose()
            $stream.Dispose()
        }
    } finally {
        $response.Dispose()
        Complete-PackProgress -Activity $Activity
    }

    if ($ExpectedSize -gt 0 -and (Get-Item -LiteralPath $tempPath).Length -ne $ExpectedSize) {
        throw "Size mismatch for $DestinationPath."
    }
    if (-not [string]::IsNullOrWhiteSpace($Sha256)) {
        $actual = Get-FileHashString -Path $tempPath -Algorithm SHA256
        if ($actual -ne $Sha256.ToLowerInvariant()) {
            throw "SHA-256 mismatch for $DestinationPath. Expected $Sha256, got $actual."
        }
    }
    Move-Item -LiteralPath $tempPath -Destination $DestinationPath -Force
}

function Test-Java8([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) { return $false }
    try {
        $old = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try { $output = & $Path -version 2>&1 } finally { $ErrorActionPreference = $old }
        return (($output | Out-String) -match 'version "1\.8\.|version "8\.')
    } catch {
        return $false
    }
}

function Get-Jdk8Tools {
    $candidates = @()
    foreach ($root in @($JavaRoot, $env:JAVA_HOME, (Join-Path $env:ProgramFiles 'Java'), (Join-Path ${env:ProgramFiles(x86)} 'Java'))) {
        if (-not [string]::IsNullOrWhiteSpace($root) -and (Test-Path -LiteralPath $root)) {
            $candidates += Get-ChildItem -Path $root -Recurse -Filter java.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
        }
    }
    foreach ($java in @($candidates | Select-Object -Unique)) {
        $jar = Join-Path (Split-Path -Parent $java) 'jar.exe'
        $javaw = Join-Path (Split-Path -Parent $java) 'javaw.exe'
        if (-not (Test-Path -LiteralPath $javaw)) {
            $javaw = $java
        }
        if ((Test-Java8 -Path $java) -and (Test-Path -LiteralPath $jar)) {
            return [pscustomobject]@{ Java = $java; Javaw = $javaw; Jar = $jar }
        }
    }

    Write-Step 'Downloading portable Java 8 JDK'
    Ensure-Directory -Path $JavaRoot
    $zipPath = Join-Path $JavaRoot 'temurin-jdk8-windows-x64.zip'
    Invoke-DownloadFile -Url 'https://api.adoptium.net/v3/binary/latest/8/ga/windows/x64/jdk/hotspot/normal/eclipse' -DestinationPath $zipPath -Activity 'Downloading Java 8 JDK'
    $extractPath = Join-Path $JavaRoot 'runtime'
    Remove-DirectoryIfPresent -Path $extractPath
    Expand-ZipDotNet -ArchivePath $zipPath -DestinationPath $extractPath -Activity 'Extracting Java 8 JDK'

    foreach ($java in Get-ChildItem -Path $extractPath -Recurse -Filter java.exe | Select-Object -ExpandProperty FullName) {
        $jar = Join-Path (Split-Path -Parent $java) 'jar.exe'
        $javaw = Join-Path (Split-Path -Parent $java) 'javaw.exe'
        if (-not (Test-Path -LiteralPath $javaw)) {
            $javaw = $java
        }
        if ((Test-Java8 -Path $java) -and (Test-Path -LiteralPath $jar)) {
            return [pscustomobject]@{ Java = $java; Javaw = $javaw; Jar = $jar }
        }
    }
    throw 'Portable Java 8 JDK download completed, but java.exe and jar.exe were not found.'
}

function Expand-ZipDotNet([string]$ArchivePath, [string]$DestinationPath, [string]$Activity) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Ensure-Directory -Path $DestinationPath
    $zip = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        $entries = @($zip.Entries)
        if ($entries.Count -eq 0) {
            throw 'No zip entries visible to .NET.'
        }
        $total = [Math]::Max(1, $entries.Count)
        $started = Get-Date
        for ($i = 0; $i -lt $entries.Count; $i++) {
            $entry = $entries[$i]
            if ([string]::IsNullOrWhiteSpace($entry.FullName)) {
                continue
            }
            $elapsedSeconds = [Math]::Max(0.001, ((Get-Date) - $started).TotalSeconds)
            $rate = ($i + 1) / $elapsedSeconds
            $status = "{0}/{1} files | {2:N1} files/s | {3}" -f ($i + 1), $total, $rate, $entry.FullName
            Write-PackProgress -Activity $Activity -Status $status -Percent ([int](($i * 100) / $total))
            $target = Join-Path $DestinationPath ($entry.FullName.Replace('/', [IO.Path]::DirectorySeparatorChar))
            if ($entry.FullName.EndsWith('/')) {
                Ensure-Directory -Path $target
                continue
            }
            Ensure-Directory -Path (Split-Path -Parent $target)
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
        }
    } finally {
        $zip.Dispose()
        Complete-PackProgress -Activity $Activity
    }
}

function Expand-PackArchive([string]$ArchivePath, [string]$DestinationPath, [string]$Activity) {
    try {
        Expand-ZipDotNet -ArchivePath $ArchivePath -DestinationPath $DestinationPath -Activity $Activity
    } catch {
        Write-StatusLine -Kind 'WARN' -Message ".NET zip extraction failed for $(Split-Path -Leaf $ArchivePath): $($_.Exception.Message)"
        Write-Step "Extracting with Java jar fallback"
        Ensure-Directory -Path $DestinationPath
        $tools = Get-Jdk8Tools
        Push-Location $DestinationPath
        try {
            $output = & $tools.Jar xf $ArchivePath 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "jar extraction failed: $($output | Out-String)"
            }
        } finally {
            Pop-Location
        }
    }
}

function Expand-ClientPayloadSelective([string]$ArchivePath, [string]$DestinationPath) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Ensure-Directory -Path $DestinationPath
    $presentModNames = @{}
    foreach ($rootName in @('mods', 'mods.disabled-client-fps', $MenuFpsDiagnosticRootName)) {
        $root = Join-Path $DestinationPath $rootName
        if (Test-Path -LiteralPath $root) {
            foreach ($jar in Get-ChildItem -LiteralPath $root -Recurse -Filter *.jar -ErrorAction SilentlyContinue) {
                $presentModNames[$jar.Name.ToLowerInvariant()] = $true
            }
        }
    }

    $zip = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        $entries = @($zip.Entries)
        $total = [Math]::Max(1, $entries.Count)
        $started = Get-Date
        for ($i = 0; $i -lt $entries.Count; $i++) {
            $entry = $entries[$i]
            if ([string]::IsNullOrWhiteSpace($entry.FullName)) { continue }
            $normalized = $entry.FullName.Replace('\', '/')
            $isModJar = $normalized.StartsWith('mods/') -and $normalized.ToLowerInvariant().EndsWith('.jar')
            if ($isModJar -and $presentModNames.ContainsKey((Split-Path -Leaf $normalized).ToLowerInvariant())) {
                continue
            }

            $elapsedSeconds = [Math]::Max(0.001, ((Get-Date) - $started).TotalSeconds)
            $rate = ($i + 1) / $elapsedSeconds
            $status = "{0}/{1} files | {2:N1} files/s | {3}" -f ($i + 1), $total, $rate, $entry.FullName
            Write-PackProgress -Activity 'Extracting Crazy Craft 4.0 client payload' -Status $status -Percent ([int](($i * 100) / $total))
            $target = Join-Path $DestinationPath ($normalized.Replace('/', [IO.Path]::DirectorySeparatorChar))
            if ($normalized.EndsWith('/')) {
                Ensure-Directory -Path $target
                continue
            }
            Ensure-Directory -Path (Split-Path -Parent $target)
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
        }
    } finally {
        $zip.Dispose()
        Complete-PackProgress -Activity 'Extracting Crazy Craft 4.0 client payload'
    }
}

function Ensure-ForgeInstaller {
    $path = Join-Path $CacheRoot 'forge-1.7.10-10.13.4.1558-1.7.10-installer.jar'
    Invoke-DownloadFile -Url $ForgeInstallerUrl -DestinationPath $path -Activity 'Downloading Forge 1.7.10 installer'
    $path
}

function Ensure-ForgeUniversal {
    $path = Join-Path $CacheRoot 'forge-1.7.10-10.13.4.1558-1.7.10-universal.jar'
    Invoke-DownloadFile -Url $ForgeUniversalUrl -DestinationPath $path -Activity 'Downloading Forge 1.7.10 universal'
    $path
}

function Ensure-MinecraftBaseMetadata {
    $versionDir = Join-Path $MinecraftRoot 'versions\1.7.10'
    $versionJson = Join-Path $versionDir '1.7.10.json'
    if (Test-Path -LiteralPath $versionJson) { return }
    Write-Step 'Downloading Minecraft 1.7.10 metadata'
    Ensure-Directory -Path $versionDir
    $manifest = Invoke-RestMethod -Uri 'https://piston-meta.mojang.com/mc/game/version_manifest_v2.json' -UseBasicParsing
    $version = @($manifest.versions | Where-Object id -eq '1.7.10' | Select-Object -First 1)
    Invoke-DownloadFile -Url ([string]$version.url) -DestinationPath $versionJson -Activity 'Downloading Minecraft metadata'
}

function Install-ForgeClient {
    $versionJson = Join-Path $MinecraftRoot "versions\$ForgeVersionId\$ForgeVersionId.json"
    $libraryDir = Join-Path $MinecraftRoot 'libraries\net\minecraftforge\forge\1.7.10-10.13.4.1558-1.7.10'
    $libraryJar = Join-Path $libraryDir 'forge-1.7.10-10.13.4.1558-1.7.10.jar'
    if ((Test-Path -LiteralPath $versionJson) -and (Test-Path -LiteralPath $libraryJar)) { return }
    Write-Step 'Installing Forge 1.7.10 client metadata'
    $installer = Ensure-ForgeInstaller
    $universal = Ensure-ForgeUniversal
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($installer)
    try {
        $profileEntry = $zip.GetEntry('install_profile.json')
        if (-not $profileEntry) { throw 'install_profile.json was not found in the Forge installer.' }
        $reader = [System.IO.StreamReader]::new($profileEntry.Open())
        try {
            $profile = $reader.ReadToEnd() | ConvertFrom-Json
        } finally {
            $reader.Dispose()
        }
    } finally {
        $zip.Dispose()
    }
    Ensure-Directory -Path (Split-Path -Parent $versionJson)
    Ensure-Directory -Path $libraryDir
    ($profile.versionInfo | ConvertTo-Json -Depth 64) | Set-Content -LiteralPath $versionJson -Encoding ASCII
    Copy-Item -LiteralPath $universal -Destination $libraryJar -Force
}

function Update-LauncherProfile {
    $profilesPath = Join-Path $MinecraftRoot 'launcher_profiles.json'
    if (-not (Test-Path -LiteralPath $profilesPath)) {
        throw 'Minecraft Launcher profile file is missing. Open the launcher once, then rerun.'
    }
    $profiles = Get-Content -LiteralPath $profilesPath -Raw | ConvertFrom-Json
    if (-not $profiles.profiles) {
        $profiles | Add-Member -NotePropertyName profiles -NotePropertyValue ([pscustomobject]@{})
    }
    $javaTools = Get-Jdk8Tools
    $profile = [pscustomobject]@{
        name = $PackName
        type = 'custom'
        created = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        lastUsed = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        lastVersionId = $ForgeVersionId
        gameDir = [System.IO.Path]::GetFullPath($ClientPath)
        javaDir = $javaTools.Javaw
        javaArgs = '-Xms512M -Xmx2560M -XX:+UseConcMarkSweepGC -XX:+CMSIncrementalMode -XX:-UseAdaptiveSizePolicy'
        icon = 'Grass'
    }
    if ($profiles.profiles.PSObject.Properties.Name -contains $ProfileKey) {
        $profiles.profiles.$ProfileKey = $profile
    } else {
        $profiles.profiles | Add-Member -NotePropertyName $ProfileKey -NotePropertyValue $profile
    }
    if ($profiles.PSObject.Properties.Name -contains 'selectedProfile') {
        $profiles.selectedProfile = $ProfileKey
    } else {
        $profiles | Add-Member -NotePropertyName selectedProfile -NotePropertyValue $ProfileKey
    }
    $json = $profiles | ConvertTo-Json -Depth 12
    [System.IO.File]::WriteAllText($profilesPath, $json, [System.Text.UTF8Encoding]::new($false))
}

function Get-PackZipPath($ZipInfo) {
    Join-Path $CacheRoot $ZipInfo.Name
}

function Ensure-PackZip($ZipInfo) {
    $path = Get-PackZipPath $ZipInfo
    Invoke-DownloadFile -Url $ZipInfo.Url -DestinationPath $path -ExpectedSize $ZipInfo.Size -Sha256 $ZipInfo.Sha256 -Activity "Downloading $($ZipInfo.Name)"
    $path
}

function Verify-PackZip($ZipInfo) {
    $path = Get-PackZipPath $ZipInfo
    if (-not (Test-ExpectedFile -Path $path -Size $ZipInfo.Size -Sha256 $ZipInfo.Sha256)) {
        throw "Cached file is missing or invalid: $path"
    }
    Write-StatusLine -Kind 'OK' -Message "Verified $($ZipInfo.Name)."
    Write-KeyValue -Name 'SHA-256' -Value $ZipInfo.Sha256
}

function Get-ModJarCount([string]$Path) {
    $mods = Join-Path $Path 'mods'
    if (-not (Test-Path -LiteralPath $mods)) { return 0 }
    return @(Get-ChildItem -LiteralPath $mods -Recurse -Filter *.jar -ErrorAction SilentlyContinue).Count
}

function Get-RequiredModPaths {
    if (-not (Test-Path -LiteralPath $RequiredModsPath)) {
        throw "Required mod manifest is missing: $RequiredModsPath"
    }
    @(Get-Content -LiteralPath $RequiredModsPath | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_) -and -not $_.TrimStart().StartsWith('#')
    })
}

function Test-RequiredModsPresent([string]$Path) {
    $modsRoot = Join-Path $Path 'mods'
    $disabledRoot = Join-Path $Path 'mods.disabled-client-fps'
    $diagnosticRoot = Join-Path $Path $MenuFpsDiagnosticRootName
    if (-not (Test-Path -LiteralPath $modsRoot) -and -not (Test-Path -LiteralPath $disabledRoot) -and -not (Test-Path -LiteralPath $diagnosticRoot)) {
        return $false
    }

    $presentNames = @{}
    foreach ($root in @($modsRoot, $disabledRoot, $diagnosticRoot)) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($jar in Get-ChildItem -LiteralPath $root -Recurse -Filter *.jar -ErrorAction SilentlyContinue) {
            $presentNames[$jar.Name.ToLowerInvariant()] = $true
        }
    }

    foreach ($required in Get-RequiredModPaths) {
        $relative = $required.Replace('/', [IO.Path]::DirectorySeparatorChar)
        $exactPath = Join-Path $Path $relative
        $name = Split-Path -Leaf $required
        if ((Test-Path -LiteralPath $exactPath) -or $presentNames.ContainsKey($name.ToLowerInvariant())) {
            continue
        }
        return $false
    }
    return $true
}

function Test-AnyRequiredModsPresent([string]$Path) {
    $modsRoot = Join-Path $Path 'mods'
    $disabledRoot = Join-Path $Path 'mods.disabled-client-fps'
    $diagnosticRoot = Join-Path $Path $MenuFpsDiagnosticRootName
    if (-not (Test-Path -LiteralPath $modsRoot) -and -not (Test-Path -LiteralPath $disabledRoot) -and -not (Test-Path -LiteralPath $diagnosticRoot)) {
        return $false
    }
    $presentNames = @{}
    foreach ($root in @($modsRoot, $disabledRoot, $diagnosticRoot)) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($jar in Get-ChildItem -LiteralPath $root -Recurse -Filter *.jar -ErrorAction SilentlyContinue) {
            $presentNames[$jar.Name.ToLowerInvariant()] = $true
        }
    }
    foreach ($required in Get-RequiredModPaths) {
        if ($presentNames.ContainsKey((Split-Path -Leaf $required).ToLowerInvariant())) {
            return $true
        }
    }
    return $false
}

function Write-DiagnosticValue([string]$Name, $Value) {
    Write-KeyValue -Name $Name -Value $Value
}

function Get-ObjectPropertyValue($Object, [string]$Name) {
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($property) { return $property.Value }
    return $null
}

function Get-ModJarsUnder([string]$Root) {
    if ([string]::IsNullOrWhiteSpace($Root) -or -not (Test-Path -LiteralPath $Root)) { return @() }
    @(Get-ChildItem -LiteralPath $Root -Recurse -File -Filter *.jar -ErrorAction SilentlyContinue)
}

function Get-ModFilesByPatterns([string]$ModsRoot, [string[]]$Patterns) {
    if ([string]::IsNullOrWhiteSpace($ModsRoot) -or -not (Test-Path -LiteralPath $ModsRoot)) { return @() }
    $found = @{}
    foreach ($pattern in $Patterns) {
        foreach ($jar in Get-ChildItem -LiteralPath $ModsRoot -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue) {
            $found[$jar.FullName.ToLowerInvariant()] = $jar
        }
    }
    @($found.Values)
}

function Get-MissingRequiredModPaths([string]$Path) {
    $roots = @(
        (Join-Path $Path 'mods'),
        (Join-Path $Path 'mods.disabled-client-fps'),
        (Join-Path $Path $MenuFpsDiagnosticRootName)
    )
    $presentNames = @{}
    foreach ($root in $roots) {
        foreach ($jar in Get-ModJarsUnder -Root $root) {
            $presentNames[$jar.Name.ToLowerInvariant()] = $true
        }
    }

    $missing = @()
    foreach ($required in Get-RequiredModPaths) {
        $relative = $required.Replace('/', [IO.Path]::DirectorySeparatorChar)
        $exactPath = Join-Path $Path $relative
        $name = Split-Path -Leaf $required
        if ((Test-Path -LiteralPath $exactPath) -or $presentNames.ContainsKey($name.ToLowerInvariant())) {
            continue
        }
        $missing += $required
    }
    $missing
}

function Get-BatchFolderName($Batch) {
    'batch{0:00}-{1}' -f ([int]$Batch.Id), ([string]$Batch.Name)
}

function Get-MenuFpsBatch([int]$Id) {
    @($MenuFpsDiagnosticBatches | Where-Object { [int]$_.Id -eq $Id } | Select-Object -First 1)
}

function Get-NextMenuFpsBatch {
    $modsRoot = Join-Path $ClientPath 'mods'
    foreach ($batch in $MenuFpsDiagnosticBatches) {
        $active = @(Get-ModFilesByPatterns -ModsRoot $modsRoot -Patterns ([string[]]$batch.Mods))
        if ($active.Count -gt 0) { return $batch }
    }
    return $null
}

function Move-ModsToDiagnosticFolder($Batch) {
    $modsRoot = Join-Path $ClientPath 'mods'
    if (-not (Test-Path -LiteralPath $modsRoot)) {
        throw "Active mods folder was not found: $modsRoot"
    }
    $disabledRoot = Join-Path (Join-Path $ClientPath $MenuFpsDiagnosticRootName) (Get-BatchFolderName -Batch $Batch)
    Ensure-Directory -Path $disabledRoot
    $matches = @(Get-ModFilesByPatterns -ModsRoot $modsRoot -Patterns ([string[]]$Batch.Mods))
    if ($matches.Count -eq 0) {
        Write-StatusLine -Kind 'WARN' -Message "No active jars matched batch $($Batch.Id): $($Batch.Name)."
        return 0
    }

    $modsFull = ([System.IO.Path]::GetFullPath($modsRoot)).TrimEnd([char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar))
    foreach ($match in $matches) {
        $fileFull = [System.IO.Path]::GetFullPath($match.FullName)
        $relative = $fileFull.Substring($modsFull.Length).TrimStart([char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar))
        $destination = Join-Path $disabledRoot $relative
        Ensure-Directory -Path (Split-Path -Parent $destination)
        if (Test-Path -LiteralPath $destination) {
            $destination = Join-Path (Split-Path -Parent $destination) ("{0}.{1}{2}" -f [IO.Path]::GetFileNameWithoutExtension($destination), [DateTimeOffset]::UtcNow.ToUnixTimeSeconds(), [IO.Path]::GetExtension($destination))
        }
        Move-Item -LiteralPath $match.FullName -Destination $destination -Force
        Write-StatusLine -Kind 'WARN' -Message "Diagnostic-disabled batch $($Batch.Id): $($match.Name)"
    }
    return $matches.Count
}

function Restore-MenuFpsDiagnosticMods {
    $diagnosticRoot = Join-Path $ClientPath $MenuFpsDiagnosticRootName
    if (-not (Test-Path -LiteralPath $diagnosticRoot)) {
        Write-StatusLine -Kind 'WARN' -Message 'No diagnostic-disabled mods were found to restore.'
        return
    }
    $modsRoot = Join-Path $ClientPath 'mods'
    Ensure-Directory -Path $modsRoot
    $restored = 0
    foreach ($batchFolder in Get-ChildItem -LiteralPath $diagnosticRoot -Directory -ErrorAction SilentlyContinue) {
        $batchFull = ([System.IO.Path]::GetFullPath($batchFolder.FullName)).TrimEnd([char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar))
        foreach ($jar in Get-ModJarsUnder -Root $batchFolder.FullName) {
            $fileFull = [System.IO.Path]::GetFullPath($jar.FullName)
            $relative = $fileFull.Substring($batchFull.Length).TrimStart([char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar))
            $destination = Join-Path $modsRoot $relative
            Ensure-Directory -Path (Split-Path -Parent $destination)
            if (Test-Path -LiteralPath $destination) {
                Write-StatusLine -Kind 'WARN' -Message "Restore skipped because an active jar already exists: $destination"
                continue
            }
            Move-Item -LiteralPath $jar.FullName -Destination $destination
            $restored++
        }
    }
    Write-StatusLine -Kind 'OK' -Message "Restored $restored diagnostic-disabled mod jar(s)."
    Add-Completion "Restored $restored diagnostic-disabled menu FPS mod jar(s)."
}

function Invoke-MenuFpsSafeMode {
    Write-Step 'Applying menu FPS diagnostic safe mode'
    if ($MenuFpsBatch -gt 0) {
        $batch = Get-MenuFpsBatch -Id $MenuFpsBatch
        if ($null -eq $batch) { throw "Unknown menu FPS diagnostic batch: $MenuFpsBatch" }
    } else {
        $batch = Get-NextMenuFpsBatch
        if ($null -eq $batch) {
            Write-StatusLine -Kind 'WARN' -Message 'No active jars matched any menu FPS diagnostic batch.'
            Write-CommandHint 'powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Minecraft-Pack.ps1 -RestoreMenuFpsMods'
            return
        }
    }

    Write-KeyValue -Name 'Batch' -Value ("{0}: {1}" -f $batch.Id, $batch.Description)
    $moved = Move-ModsToDiagnosticFolder -Batch $batch
    Write-Host ''
    Write-StatusLine -Kind 'OK' -Message "Moved $moved jar(s) into $MenuFpsDiagnosticRootName."
    Write-StatusLine -Kind 'INFO' -Message 'Launch the menu and compare FPS before applying another batch.'
    Write-CommandHint 'powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Minecraft-Pack.ps1 -RestoreMenuFpsMods'
    Add-Completion "Applied menu FPS diagnostic batch $($Batch.Id) ($($Batch.Name)); moved $moved jar(s)."
}

function Get-FirstMatchingLine([string[]]$Lines, [string[]]$Patterns) {
    foreach ($pattern in $Patterns) {
        foreach ($line in $Lines) {
            if ($line -match $pattern) { return $line }
        }
    }
    return ''
}

function Get-LogTimeGaps([string[]]$Lines, [int]$ThresholdSeconds = 10) {
    $gaps = @()
    $lastTime = $null
    $lastLine = ''
    foreach ($line in $Lines) {
        if ($line -match '^\[(\d{2}):(\d{2}):(\d{2})\]') {
            $current = [DateTime]::Today.AddHours([int]$matches[1]).AddMinutes([int]$matches[2]).AddSeconds([int]$matches[3])
            if ($null -ne $lastTime) {
                if ($current -lt $lastTime) { $current = $current.AddDays(1) }
                $seconds = [int]($current - $lastTime).TotalSeconds
                if ($seconds -ge $ThresholdSeconds) {
                    $gaps += [pscustomobject]@{ Seconds = $seconds; Before = $lastLine; After = $line }
                }
            }
            $lastTime = $current
            $lastLine = $line
        }
    }
    @($gaps | Sort-Object Seconds -Descending | Select-Object -First 8)
}

function Get-TopLogIssues([string[]]$Lines) {
    @($Lines |
        Where-Object { $_ -match '/(WARN|ERROR)\]|/(FATAL)\]|\b(SEVERE|Exception|Error)\b' } |
        ForEach-Object { ($_ -replace '^\[[^\]]+\]\s*', '').Trim() } |
        Group-Object |
        Sort-Object Count -Descending |
        Select-Object -First 8)
}

function Get-DiagnosticLogLines([string]$Path) {
    $item = Get-Item -LiteralPath $Path
    if ($item.Length -le 20MB) {
        return @(Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue)
    }
    $head = @(Get-Content -LiteralPath $Path -TotalCount 5000 -ErrorAction SilentlyContinue)
    $tail = @(Get-Content -LiteralPath $Path -Tail 12000 -ErrorAction SilentlyContinue)
    @($head + $tail)
}

function Get-DiagnosticLogScanDescription([string]$Path) {
    $item = Get-Item -LiteralPath $Path
    if ($item.Length -le 20MB) {
        return 'entire file'
    }
    return 'first 5000 lines plus last 12000 lines'
}

function Get-LogSearchCandidates {
    $candidates = @()
    $roots = @(
        $MinecraftRoot,
        (Join-Path $ClientPath 'logs')
    )
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $roots += Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.4297127D64EC6_8wekyb3d8bbwe\LocalCache\Local\game'
        $roots += Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.4297127D64EC6_8wekyb3d8bbwe\LocalCache\Roaming\.minecraft'
    }

    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($filter in @('launcher_log*.txt', 'native*.log', '*.log')) {
            $candidates += Get-ChildItem -LiteralPath $root -File -Filter $filter -ErrorAction SilentlyContinue
        }
    }

    $seen = @{}
    foreach ($file in @($candidates | Sort-Object LastWriteTime -Descending)) {
        if ($seen.ContainsKey($file.FullName.ToLowerInvariant())) { continue }
        $seen[$file.FullName.ToLowerInvariant()] = $true
        $file
    }
}

function Find-ErodedBadlandsMentions {
    $mentions = @()
    foreach ($file in @(Get-LogSearchCandidates | Select-Object -First 40)) {
        try {
            if ($file.Length -gt 20MB) {
                $lineNumberBase = [Math]::Max(0, ($file.Length / 80) - 8000)
                $lines = @(Get-Content -LiteralPath $file.FullName -Tail 8000 -ErrorAction SilentlyContinue)
                for ($i = 0; $i -lt $lines.Count; $i++) {
                    if ($lines[$i] -match 'Eroded Badlands|ErodedBadlands|eroded_badlands') {
                        $mentions += [pscustomobject]@{ Path = $file.FullName; LineNumber = [int]($lineNumberBase + $i + 1); Line = $lines[$i].Trim() }
                    }
                    if ($mentions.Count -ge 8) { break }
                }
            } else {
                $matches = @(Select-String -LiteralPath $file.FullName -SimpleMatch -Pattern @('Eroded Badlands', 'ErodedBadlands', 'eroded_badlands') -ErrorAction SilentlyContinue | Select-Object -First 3)
                foreach ($match in $matches) {
                    $mentions += [pscustomobject]@{ Path = $file.FullName; LineNumber = $match.LineNumber; Line = $match.Line.Trim() }
                }
            }
        } catch {
        }
        if ($mentions.Count -ge 8) { break }
    }
    $mentions
}

function Get-MinecraftProcessInfo {
    @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -in @('Minecraft', 'MinecraftLauncher', 'java', 'javaw')
    } | Select-Object @{Name = 'Name'; Expression = { $_.ProcessName } }, @{Name = 'ProcessId'; Expression = { $_.Id } })
}

function Write-MenuFpsBatchStatus {
    $modsRoot = Join-Path $ClientPath 'mods'
    $diagnosticRoot = Join-Path $ClientPath $MenuFpsDiagnosticRootName
    Write-Rule -Title 'Menu FPS diagnostic batches' -Color 'DarkGray'
    foreach ($batch in $MenuFpsDiagnosticBatches) {
        $activeCount = @(Get-ModFilesByPatterns -ModsRoot $modsRoot -Patterns ([string[]]$batch.Mods)).Count
        $disabledFolder = Join-Path $diagnosticRoot (Get-BatchFolderName -Batch $batch)
        $disabledCount = @(Get-ModJarsUnder -Root $disabledFolder).Count
        Write-KeyValue -Name ("Batch $($batch.Id)") -Value ("{0} | active={1}, diagnostic-disabled={2}" -f $batch.Name, $activeCount, $disabledCount)
    }
}

function Diagnose-Client {
    Write-Step 'Diagnosing Crazy Craft client'
    Write-DiagnosticValue 'Client path' ([System.IO.Path]::GetFullPath($ClientPath))

    $profilesPath = Join-Path $MinecraftRoot 'launcher_profiles.json'
    Write-DiagnosticValue 'Launcher profiles' $profilesPath
    $profiles = $null
    if (Test-Path -LiteralPath $profilesPath) {
        try {
            $profiles = Get-Content -LiteralPath $profilesPath -Raw | ConvertFrom-Json
        } catch {
            Write-StatusLine -Kind 'WARN' -Message "Could not parse launcher_profiles.json: $($_.Exception.Message)"
        }
    }

    if ($null -ne $profiles) {
        Write-DiagnosticValue 'Current selectedProfile' (Get-ObjectPropertyValue -Object $profiles -Name 'selectedProfile')
        $profileContainer = Get-ObjectPropertyValue -Object $profiles -Name 'profiles'
        $profile = Get-ObjectPropertyValue -Object $profileContainer -Name $ProfileKey
        if ($null -eq $profile) {
            Write-StatusLine -Kind 'WARN' -Message "Launcher profile '$ProfileKey' was not found."
        } else {
            Write-DiagnosticValue 'Profile name' (Get-ObjectPropertyValue -Object $profile -Name 'name')
            Write-DiagnosticValue 'Profile gameDir' (Get-ObjectPropertyValue -Object $profile -Name 'gameDir')
            Write-DiagnosticValue 'Profile javaDir' (Get-ObjectPropertyValue -Object $profile -Name 'javaDir')
            Write-DiagnosticValue 'Profile javaArgs' (Get-ObjectPropertyValue -Object $profile -Name 'javaArgs')
            Write-DiagnosticValue 'Profile lastVersionId' (Get-ObjectPropertyValue -Object $profile -Name 'lastVersionId')
        }
    } else {
        Write-StatusLine -Kind 'WARN' -Message 'Launcher profile data was not available.'
    }

    $running = @(Get-MinecraftProcessInfo)
    if ($running.Count -eq 0) {
        Write-DiagnosticValue 'Minecraft/Launcher running' 'No'
    } else {
        Write-DiagnosticValue 'Minecraft/Launcher running' (($running | ForEach-Object { "$($_.Name)#$($_.ProcessId)" }) -join ', ')
    }

    $activeMods = @(Get-ModJarsUnder -Root (Join-Path $ClientPath 'mods'))
    $fpsDisabled = @(Get-ModJarsUnder -Root (Join-Path $ClientPath 'mods.disabled-client-fps'))
    $diagnosticDisabled = @(Get-ModJarsUnder -Root (Join-Path $ClientPath $MenuFpsDiagnosticRootName))
    Write-DiagnosticValue 'Active mod jar count' $activeMods.Count
    Write-DiagnosticValue 'Disabled FPS mod count' $fpsDisabled.Count
    if ($fpsDisabled.Count -gt 0) {
        Write-DiagnosticValue 'Disabled FPS mods' (($fpsDisabled | Select-Object -ExpandProperty Name | Sort-Object) -join ', ')
    }
    Write-DiagnosticValue 'Diagnostic-disabled mod count' $diagnosticDisabled.Count
    $portalGunSoundPath = Join-Path (Join-Path $ClientPath 'mods') ([string]$PortalGunSoundPack.Name)
    Write-DiagnosticValue 'PortalGun sound pack' (Format-PortalGunSoundPackStatus -Status (Get-PortalGunSoundPackStatus -Path $portalGunSoundPath))
    $notEnoughItemsStatus = Get-NotEnoughItemsStatus -Path $ClientPath
    Write-DiagnosticValue 'NotEnoughItems dependency' (Format-NotEnoughItemsStatus -Status $notEnoughItemsStatus)

    $stillActive = @(Get-ModFilesByPatterns -ModsRoot (Join-Path $ClientPath 'mods') -Patterns $ClientFpsDisabledMods)
    if ($stillActive.Count -gt 0) {
        Write-DiagnosticValue 'FPS-disabled mods still active' (($stillActive | Select-Object -ExpandProperty Name | Sort-Object) -join ', ')
    } else {
        Write-DiagnosticValue 'FPS-disabled mods still active' 'No'
    }

    $missing = @(Get-MissingRequiredModPaths -Path $ClientPath)
    if ($missing.Count -eq 0) {
        Write-DiagnosticValue 'Missing required mods' 'No'
    } else {
        Write-DiagnosticValue 'Missing required mods' ($missing -join ', ')
    }

    $latestLog = Join-Path $ClientPath 'logs\latest.log'
    Write-DiagnosticValue 'latest.log' $latestLog
    if (Test-Path -LiteralPath $latestLog) {
        $latestLogItem = Get-Item -LiteralPath $latestLog
        Write-DiagnosticValue 'latest.log size MB' ('{0:N1}' -f ($latestLogItem.Length / 1MB))
        Write-DiagnosticValue 'latest.log scan window' (Get-DiagnosticLogScanDescription -Path $latestLog)
        $lines = @(Get-DiagnosticLogLines -Path $latestLog)
        Write-DiagnosticValue 'Log Java line' (Get-FirstMatchingLine -Lines $lines -Patterns @('Java is ', 'Java version', 'java\.version', 'Java VM Version'))
        Write-DiagnosticValue 'Log JVM flags' (Get-FirstMatchingLine -Lines $lines -Patterns @('JVM Flags', 'JVM Arguments', 'java arguments', 'Process arguments'))
        Write-DiagnosticValue 'Log GL renderer' (Get-FirstMatchingLine -Lines $lines -Patterns @('OpenGL:', 'GL info', 'OpenGL version', 'LWJGL'))
        Write-DiagnosticValue 'Log mod-load line' (Get-FirstMatchingLine -Lines $lines -Patterns @('Forge Mod Loader has identified', 'mods loaded', 'Loaded mods', 'Mod state'))
        $neiMissingClassHits = @($lines | Where-Object { $_ -match 'codechicken[./\\]nei[./\\]recipe[./\\]TemplateRecipeHandler|codechicken\.nei\.recipe\.TemplateRecipeHandler' }).Count
        if ($neiMissingClassHits -gt 0) {
            $neiHint = if ($notEnoughItemsStatus.Verified) { 'old log still contains pre-repair hits; relaunch Minecraft to confirm cleared' } else { 'rerun client install to repair NotEnoughItems' }
            Write-DiagnosticValue 'NEI missing-class log hits' "$neiMissingClassHits ($neiHint)"
        } else {
            Write-DiagnosticValue 'NEI missing-class log hits' 'No'
        }
        Write-DiagnosticValue 'Join client-thread timeout' (Get-FirstMatchingLine -Lines $lines -Patterns @('Timeout waiting for client thread to catch up', 'FMLClientHandler\.waitForPlayClient'))

        $gaps = @(Get-LogTimeGaps -Lines $lines -ThresholdSeconds 10)
        if ($gaps.Count -eq 0) {
            Write-DiagnosticValue '10s+ log time gaps' 'No'
        } else {
            Write-Rule -Title '10s+ log time gaps' -Color 'DarkGray'
            foreach ($gap in $gaps) {
                Write-KeyValue -Name ("Gap $($gap.Seconds)s") -Value $gap.After
            }
        }

        $issues = @(Get-TopLogIssues -Lines $lines)
        if ($issues.Count -eq 0) {
            Write-DiagnosticValue 'Repeated WARN/ERROR/Exception lines' 'No'
        } else {
            Write-Rule -Title 'Repeated WARN/ERROR/Exception lines' -Color 'DarkGray'
            foreach ($issue in $issues) {
                Write-KeyValue -Name ("x$($issue.Count)") -Value $issue.Name
            }
        }
    } else {
        Write-StatusLine -Kind 'WARN' -Message 'latest.log was not found. Launch the Crazy Craft profile once, then rerun -Diagnose.'
    }

    $eroded = @(Find-ErodedBadlandsMentions)
    if ($eroded.Count -eq 0) {
        Write-DiagnosticValue 'Eroded Badlands in detected logs' 'No'
    } else {
        Write-Rule -Title 'Eroded Badlands in detected logs' -Color 'DarkGray'
        foreach ($mention in $eroded) {
            Write-KeyValue -Name "$($mention.Path):$($mention.LineNumber)" -Value $mention.Line
        }
    }

    Write-MenuFpsBatchStatus
    Write-Rule -Title 'Next diagnostic step' -Color 'DarkGray'
    Write-StatusLine -Kind 'INFO' -Message 'If menu FPS is still extremely low after the Java/profile pin is visible in latest.log, close Minecraft and run:'
    Write-CommandHint 'powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Minecraft-Pack.ps1 -MenuFpsSafeMode'
    Write-StatusLine -Kind 'INFO' -Message 'Rerun one batch at a time, testing menu FPS after each batch. Use -RestoreMenuFpsMods to undo diagnostic moves.'
    Add-Completion 'Diagnostic report completed.'
}

function Remove-ServerRootFilesFromClient([string]$Path) {
    foreach ($name in @('eula.txt', 'Start Server.bat', 'minecraft_server.1.7.10.jar', 'forge-1.7.10-10.13.4.1558-1.7.10-universal.jar')) {
        $target = Join-Path $Path $name
        if (Test-Path -LiteralPath $target) {
            Remove-Item -LiteralPath $target -Force
        }
    }
}

function Disable-ClientFpsMods([string]$Path) {
    $modsRoot = Join-Path $Path 'mods'
    if (-not (Test-Path -LiteralPath $modsRoot)) { return }
    $disabledRoot = Join-Path $Path 'mods.disabled-client-fps'
    Ensure-Directory -Path $disabledRoot

    $disabledCount = 0
    foreach ($name in $ClientFpsDisabledMods) {
        $matches = @(Get-ChildItem -LiteralPath $modsRoot -Recurse -File -Filter $name -ErrorAction SilentlyContinue)
        foreach ($match in $matches) {
            Move-Item -LiteralPath $match.FullName -Destination (Join-Path $disabledRoot $match.Name) -Force
            Write-StatusLine -Kind 'WARN' -Message "Disabled client FPS mod: $($match.Name)"
            $disabledCount++
        }
    }
    if ($disabledCount -gt 0) {
        Add-Completion "Moved $disabledCount optional client FPS mod jar(s) into mods.disabled-client-fps."
    } else {
        Add-Completion 'Optional client FPS mods were already disabled or absent.'
    }
}

function Get-PortalGunSoundPackStatus([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{ Ok = $false; State = 'Missing'; Detail = 'file not found'; Entries = 0 }
    }

    $item = Get-Item -LiteralPath $Path
    if ($item.Length -ne [long]$PortalGunSoundPack.Size) {
        return [pscustomobject]@{ Ok = $false; State = 'Invalid'; Detail = "$($item.Length) bytes, expected $($PortalGunSoundPack.Size)"; Entries = 0 }
    }

    $md5 = Get-FileHashString -Path $Path -Algorithm MD5
    if ($md5 -ne ([string]$PortalGunSoundPack.Md5).ToLowerInvariant()) {
        return [pscustomobject]@{ Ok = $false; State = 'Invalid'; Detail = "MD5 $md5, expected $($PortalGunSoundPack.Md5)"; Entries = 0 }
    }

    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
        try {
            if ($zip.Entries.Count -lt 1) {
                return [pscustomobject]@{ Ok = $false; State = 'Invalid'; Detail = 'resource archive has no entries'; Entries = 0 }
            }
            return [pscustomobject]@{ Ok = $true; State = 'OK'; Detail = "$($item.Length) bytes, MD5 $md5, $($zip.Entries.Count) archive entries"; Entries = $zip.Entries.Count }
        } finally {
            $zip.Dispose()
        }
    } catch {
        return [pscustomobject]@{ Ok = $false; State = 'Invalid'; Detail = "resource archive could not be opened: $($_.Exception.Message)"; Entries = 0 }
    }
}

function Format-PortalGunSoundPackStatus($Status) {
    if ($null -eq $Status) { return 'unknown' }
    "$($Status.State) ($($Status.Detail))"
}

function Test-PortalGunSoundPack([string]$Path) {
    $status = Get-PortalGunSoundPackStatus -Path $Path
    return [bool]$status.Ok
}

function Get-BrokenDownloadRootForFile([string]$Path) {
    try {
        $clientFull = ([System.IO.Path]::GetFullPath($ClientPath)).TrimEnd([char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar))
        $fileFull = [System.IO.Path]::GetFullPath($Path)
        if ($fileFull.StartsWith($clientFull + [IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase) -or
            $fileFull.StartsWith($clientFull + [IO.Path]::AltDirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
            return (Join-Path $clientFull $BrokenDownloadDisabledRootName)
        }
    } catch {
    }
    $disabledRoot = Join-Path (Split-Path -Parent $Path) '..'
    [System.IO.Path]::GetFullPath((Join-Path $disabledRoot $BrokenDownloadDisabledRootName))
}

function Move-BrokenDownloadFile([string]$Path, [string]$Reason) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $disabledRoot = Get-BrokenDownloadRootForFile -Path $Path
    Ensure-Directory -Path $disabledRoot
    $destination = Join-Path $disabledRoot ("{0}.{1}" -f (Split-Path -Leaf $Path), [DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
    Move-Item -LiteralPath $Path -Destination $destination -Force
    Write-StatusLine -Kind 'WARN' -Message "Quarantined broken download: $(Split-Path -Leaf $Path) ($Reason)"
}

function Ensure-PortalGunSoundPack([string]$Path) {
    $modsRoot = Join-Path $Path 'mods'
    $portalGunJar = Join-Path $modsRoot 'PortalGunbeta.jar'
    if (-not (Test-Path -LiteralPath $portalGunJar)) {
        Add-Completion 'PortalGun sound resource check skipped because PortalGunbeta.jar is not active.'
        return
    }

    $soundPath = Join-Path $modsRoot ([string]$PortalGunSoundPack.Name)
    $md5Path = "$soundPath.md5"
    $beforeStatus = Get-PortalGunSoundPackStatus -Path $soundPath
    if ($beforeStatus.Ok) {
        [System.IO.File]::WriteAllText($md5Path, [string]$PortalGunSoundPack.Md5, [System.Text.Encoding]::ASCII)
        Add-Completion "PortalGun sound pack already verified: $(Format-PortalGunSoundPackStatus -Status $beforeStatus)."
        return
    }

    Write-Step 'Repairing PortalGun sound resource'
    Write-StatusLine -Kind 'WARN' -Message "PortalGun sound pack before repair: $(Format-PortalGunSoundPackStatus -Status $beforeStatus)"
    Move-BrokenDownloadFile -Path $soundPath -Reason 'invalid PortalGun sound pack'
    Move-BrokenDownloadFile -Path $md5Path -Reason 'invalid PortalGun sound checksum'
    try {
        Invoke-DownloadFile -Url ([string]$PortalGunSoundPack.Url) -DestinationPath $soundPath -ExpectedSize ([long]$PortalGunSoundPack.Size) -Activity 'Downloading PortalGun sound pack'
        $afterStatus = Get-PortalGunSoundPackStatus -Path $soundPath
        if (-not $afterStatus.Ok) {
            throw "Downloaded PortalGun sound pack did not verify: $(Format-PortalGunSoundPackStatus -Status $afterStatus)."
        }
        [System.IO.File]::WriteAllText($md5Path, [string]$PortalGunSoundPack.Md5, [System.Text.Encoding]::ASCII)
        Write-StatusLine -Kind 'OK' -Message "PortalGun sound pack after repair: $(Format-PortalGunSoundPackStatus -Status $afterStatus)"
        Add-Completion "PortalGun sound pack repaired and verified: $(Format-PortalGunSoundPackStatus -Status $afterStatus)."
    } catch {
        Write-StatusLine -Kind 'FAIL' -Message "PortalGun sound repair failed: $($_.Exception.Message)"
        Move-BrokenDownloadFile -Path $soundPath -Reason 'failed PortalGun sound repair'
        Set-TextReplacement -Path (Join-Path $Path 'config\PortalGun.cfg') -Pattern '^\s*I:enableSounds=1\s*$' -Replacement '        I:enableSounds=0'
        Add-Completion 'PortalGun sound repair failed; PortalGun sounds were disabled in config for safety.'
        throw 'PortalGun sound pack repair did not verify, so the installer stopped before continuing.'
    }
}

function Get-NotEnoughItemsTargetPath([string]$Path) {
    Join-Path (Join-Path $Path ([string]$NotEnoughItemsClientMod.TargetSubdir)) ([string]$NotEnoughItemsClientMod.Name)
}

function Get-NotEnoughItemsFiles([string]$Path) {
    Get-ModFilesByPatterns -ModsRoot (Join-Path $Path 'mods') -Patterns @('NotEnoughItems*.jar')
}

function Get-NotEnoughItemsStatus([string]$Path) {
    $targetPath = Get-NotEnoughItemsTargetPath -Path $Path
    if (Test-ExpectedFile -Path $targetPath -Size ([long]$NotEnoughItemsClientMod.Size) -Sha256 ([string]$NotEnoughItemsClientMod.Sha256)) {
        return [pscustomobject]@{ Verified = $true; State = 'OK'; Detail = "$([IO.Path]::GetFileName($targetPath)), $([long]$NotEnoughItemsClientMod.Size) bytes, SHA-256 $($NotEnoughItemsClientMod.Sha256)"; Path = $targetPath }
    }

    $files = @(Get-NotEnoughItemsFiles -Path $Path)
    foreach ($file in $files) {
        if (Test-ExpectedFile -Path $file.FullName -Size ([long]$NotEnoughItemsClientMod.Size) -Sha256 ([string]$NotEnoughItemsClientMod.Sha256)) {
            return [pscustomobject]@{ Verified = $true; State = 'OK'; Detail = "$($file.Name), $($file.Length) bytes, SHA-256 $($NotEnoughItemsClientMod.Sha256)"; Path = $file.FullName }
        }
    }

    if (Test-Path -LiteralPath $targetPath) {
        $item = Get-Item -LiteralPath $targetPath
        return [pscustomobject]@{ Verified = $false; State = 'Invalid'; Detail = "$($item.Name), $($item.Length) bytes, expected $($NotEnoughItemsClientMod.Size) bytes"; Path = $targetPath }
    }
    if ($files.Count -gt 0) {
        return [pscustomobject]@{ Verified = $false; State = 'PresentUnverified'; Detail = (($files | Select-Object -ExpandProperty Name | Sort-Object) -join ', '); Path = $files[0].FullName }
    }
    [pscustomobject]@{ Verified = $false; State = 'Missing'; Detail = 'no active NotEnoughItems jar found'; Path = $targetPath }
}

function Format-NotEnoughItemsStatus($Status) {
    if ($null -eq $Status) { return 'unknown' }
    "$($Status.State) ($($Status.Detail))"
}

function Test-NotEnoughItemsRepairNeeded([string]$Path) {
    $modsRoot = Join-Path $Path 'mods'
    if (-not (Test-Path -LiteralPath $modsRoot)) { return $false }
    $triggers = @(Get-ModFilesByPatterns -ModsRoot $modsRoot -Patterns ([string[]]$NotEnoughItemsClientMod.TriggerMods))
    return ($triggers.Count -gt 0)
}

function Ensure-NotEnoughItemsClientMod([string]$Path) {
    if (-not (Test-NotEnoughItemsRepairNeeded -Path $Path)) {
        Add-Completion 'NotEnoughItems client dependency check skipped because no known NEI-dependent active mods were found.'
        return
    }

    $beforeStatus = Get-NotEnoughItemsStatus -Path $Path
    if ($beforeStatus.Verified) {
        Add-Completion "NotEnoughItems client dependency already verified: $(Format-NotEnoughItemsStatus -Status $beforeStatus)."
        return
    }
    if ($beforeStatus.State -eq 'PresentUnverified') {
        Write-StatusLine -Kind 'WARN' -Message "NotEnoughItems is active but not installer-verified: $($beforeStatus.Detail)"
        Add-Completion "NotEnoughItems client dependency was already present but not installer-verified: $($beforeStatus.Detail)."
        return
    }

    Write-Step 'Repairing NotEnoughItems client dependency'
    Write-StatusLine -Kind 'WARN' -Message "NotEnoughItems before repair: $(Format-NotEnoughItemsStatus -Status $beforeStatus)"
    $targetPath = Get-NotEnoughItemsTargetPath -Path $Path
    Move-BrokenDownloadFile -Path $targetPath -Reason 'invalid NotEnoughItems client dependency'
    Invoke-DownloadFile -Url ([string]$NotEnoughItemsClientMod.Url) -DestinationPath $targetPath -ExpectedSize ([long]$NotEnoughItemsClientMod.Size) -Sha256 ([string]$NotEnoughItemsClientMod.Sha256) -Activity 'Downloading NotEnoughItems client dependency'

    $afterStatus = Get-NotEnoughItemsStatus -Path $Path
    if (-not $afterStatus.Verified) {
        throw "NotEnoughItems client dependency did not verify after repair: $(Format-NotEnoughItemsStatus -Status $afterStatus)."
    }
    Write-StatusLine -Kind 'OK' -Message "NotEnoughItems after repair: $(Format-NotEnoughItemsStatus -Status $afterStatus)"
    Add-Completion "NotEnoughItems client dependency repaired and verified: $(Format-NotEnoughItemsStatus -Status $afterStatus)."
}

function Set-TextReplacement([string]$Path, [string]$Pattern, [string]$Replacement) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $text = Get-Content -LiteralPath $Path -Raw
    $updated = [regex]::Replace($text, $Pattern, $Replacement, 'Multiline')
    if ($updated -ne $text) {
        [System.IO.File]::WriteAllText($Path, $updated, [System.Text.UTF8Encoding]::new($false))
    }
}

function Write-ClientOptions([string]$Path) {
    $optionsPath = Join-Path $Path 'options.txt'
    $defaults = [ordered]@{
        music = '0.0'
        sound = '0.7'
        invertYMouse = 'false'
        mouseSensitivity = '0.5'
        fov = '0.0'
        gamma = '0.0'
        viewDistance = '4'
        guiScale = '0'
        particles = '2'
        bobView = 'true'
        anaglyph3d = 'false'
        advancedOpengl = 'true'
        fboEnable = 'true'
        difficulty = '1'
        fancyGraphics = 'false'
        ao = 'false'
        clouds = 'false'
        resourcePacks = '[]'
        lastServer = ''
        lang = 'en_US'
        chatVisibility = '0'
        chatColors = 'true'
        chatLinks = 'true'
        chatLinksPrompt = 'true'
        chatOpacity = '1.0'
        snooperEnabled = 'false'
        fullscreen = 'false'
        enableVsync = 'false'
        useUnicodeFont = 'false'
        mipmapLevels = '0'
        forceUnicodeFont = 'false'
    }

    $existing = [ordered]@{}
    if (Test-Path -LiteralPath $optionsPath) {
        foreach ($line in Get-Content -LiteralPath $optionsPath) {
            if ($line -match '^([^:]+):(.*)$') {
                $existing[$matches[1]] = $matches[2]
            }
        }
    }
    foreach ($key in $defaults.Keys) {
        $existing[$key] = $defaults[$key]
    }
    $lines = foreach ($key in $existing.Keys) {
        "${key}:$($existing[$key])"
    }
    [System.IO.File]::WriteAllText($optionsPath, (($lines -join [Environment]::NewLine) + [Environment]::NewLine), [System.Text.UTF8Encoding]::new($false))
}

function Apply-ClientPerformanceDefaults([string]$Path) {
    Write-Step 'Applying low-FPS client defaults'
    Write-ClientOptions -Path $Path

    Set-TextReplacement -Path (Join-Path $Path 'config\DamageIndicatorsMod.cfg') -Pattern '^\s*B:Enabled=true\s*$' -Replacement '        B:Enabled=false'
    Set-TextReplacement -Path (Join-Path $Path 'config\DamageIndicatorsMod.cfg') -Pattern '^\s*B:ShowCriticalHits=true\s*$' -Replacement '        B:ShowCriticalHits=false'
    Set-TextReplacement -Path (Join-Path $Path 'config\DamageIndicatorsMod.cfg') -Pattern '^\s*I:Range=30\s*$' -Replacement '        I:Range=8'
    Set-TextReplacement -Path (Join-Path $Path 'config\DamageIndicatorsMod.cfg') -Pattern '^\s*B:Enable=true\s*$' -Replacement '        B:Enable=false'
    Set-TextReplacement -Path (Join-Path $Path 'config\DamageIndicatorsMod.cfg') -Pattern '^\s*B:"Show Potion Effects"=true\s*$' -Replacement '        B:"Show Potion Effects"=false'

    Set-TextReplacement -Path (Join-Path $Path 'config\Hats.cfg') -Pattern '^\s*I:maxHatRenders=\d+\s*$' -Replacement '    I:maxHatRenders=25'
    Set-TextReplacement -Path (Join-Path $Path 'config\Hats.cfg') -Pattern '^\s*I:randomHat=\d+\s*$' -Replacement '    I:randomHat=0'
    Set-TextReplacement -Path (Join-Path $Path 'config\Hats.cfg') -Pattern '^\s*I:renderHats=1\s*$' -Replacement '    I:renderHats=0'
    Set-TextReplacement -Path (Join-Path $Path 'config\Hats.cfg') -Pattern '^\s*I:shouldOtherPlayersHaveHats=1\s*$' -Replacement '    I:shouldOtherPlayersHaveHats=0'
    Set-TextReplacement -Path (Join-Path $Path 'config\Hats.cfg') -Pattern '^\s*I:showContributorHatsInGui=1\s*$' -Replacement '    I:showContributorHatsInGui=0'
    Set-TextReplacement -Path (Join-Path $Path 'config\Hats.cfg') -Pattern '^\s*I:modMobSupport=1\s*$' -Replacement '    I:modMobSupport=0'

    Set-TextReplacement -Path (Join-Path $Path 'config\Waila.cfg') -Pattern '^\s*B:waila\.cfg\.show=true\s*$' -Replacement '    B:waila.cfg.show=false'
    Set-TextReplacement -Path (Join-Path $Path 'config\Waila.cfg') -Pattern '^\s*B:waila\.cfg\.showmode=true\s*$' -Replacement '    B:waila.cfg.showmode=false'

    Set-TextReplacement -Path (Join-Path $Path 'config\MapWriter.cfg') -Pattern '^\s*I:enabled=1\s*$' -Replacement '    I:enabled=0'
    Set-TextReplacement -Path (Join-Path $Path 'config\MapWriter.cfg') -Pattern '^\s*I:chunksPerTick=\d+\s*$' -Replacement '    I:chunksPerTick=1'
    Set-TextReplacement -Path (Join-Path $Path 'config\MapWriter.cfg') -Pattern '^\s*I:regionFileOutputEnabledMP=1\s*$' -Replacement '    I:regionFileOutputEnabledMP=0'
    Set-TextReplacement -Path (Join-Path $Path 'config\MapWriter.cfg') -Pattern '^\s*I:regionFileOutputEnabledSP=1\s*$' -Replacement '    I:regionFileOutputEnabledSP=0'
    Set-TextReplacement -Path (Join-Path $Path 'config\MapWriter.cfg') -Pattern '^\s*I:textureSize=\d+\s*$' -Replacement '    I:textureSize=512'

    Set-TextReplacement -Path (Join-Path $Path 'config\fastcraft.ini') -Pattern '^disableAnimations = false\s*$' -Replacement 'disableAnimations = true'
    Set-TextReplacement -Path (Join-Path $Path 'config\fastcraft.ini') -Pattern '^asyncCulling = false\s*$' -Replacement 'asyncCulling = true'
    Set-TextReplacement -Path (Join-Path $Path 'config\fastcraft.ini') -Pattern '^maxViewDistance = \d+\s*$' -Replacement 'maxViewDistance = 8'
}

function Install-Client {
    Stop-MinecraftProcesses
    Ensure-Directory -Path $CacheRoot
    $modsAlreadyPresent = Test-RequiredModsPresent -Path $ClientPath
    $someRequiredModsPresent = Test-AnyRequiredModsPresent -Path $ClientPath
    if ($modsAlreadyPresent) {
        Write-StatusLine -Kind 'OK' -Message 'Required Crazy Craft mods already exist; skipping large payload download.'
        Write-KeyValue -Name 'Client path' -Value $ClientPath
        Add-Completion 'Required Crazy Craft mods are already present; large client payload download skipped.'
    } else {
        Ensure-PackZip $ClientZip | Out-Null
        Add-Completion 'Crazy Craft client payload is available in the local cache.'
    }
    Ensure-ForgeInstaller | Out-Null
    Add-Completion 'Forge 1.7.10 installer is available in the local cache.'
    if ($VerifyOnly) {
        if ($modsAlreadyPresent) {
            Write-StatusLine -Kind 'OK' -Message 'Verified existing mods folder: all required Crazy Craft mods are present.'
            Add-Completion 'Verify-only completed: all required client mods are present.'
        } else {
            Verify-PackZip $ClientZip
            Add-Completion 'Verify-only completed: cached client payload hash is valid.'
        }
        return
    }
    if ($DownloadOnly) {
        Add-Completion 'Download-only completed; no client files were staged.'
        return
    }

    Write-Step 'Staging Crazy Craft 4.0 client'
    if ($modsAlreadyPresent) {
        Remove-ServerRootFilesFromClient -Path $ClientPath
        Add-Completion 'Removed server-only root files from the existing client folder when present.'
    } else {
        if ($Force -and -not $someRequiredModsPresent) {
            Remove-DirectoryIfPresent -Path $ClientPath
        }
        Ensure-Directory -Path $ClientPath
        foreach ($dir in @('config', 'scripts', 'resources', 'resourcepacks', 'shaderpacks')) {
            Remove-DirectoryIfPresent -Path (Join-Path $ClientPath $dir)
        }
        if (-not $someRequiredModsPresent) {
            Remove-DirectoryIfPresent -Path (Join-Path $ClientPath 'mods')
        }
        Expand-ClientPayloadSelective -ArchivePath (Get-PackZipPath $ClientZip) -DestinationPath $ClientPath
        Remove-ServerRootFilesFromClient -Path $ClientPath
        Add-Completion 'Client payload staged and server-only root files removed.'
    }
    <#
    If all required mod jars are already present, do not refresh configs from the
    payload. Refreshing configs would require downloading the large archive again,
    which defeats the skip-existing-mods behavior this installer guarantees.
    #>
    $modCount = Get-ModJarCount -Path $ClientPath
    if ($modCount -lt 60) {
        throw "Client staging failed; expected Crazy Craft mod files, found only $modCount mod jar(s)."
    }
    Add-Completion "Client mod count verified: $modCount active jar(s)."
    Ensure-PortalGunSoundPack -Path $ClientPath
    Ensure-NotEnoughItemsClientMod -Path $ClientPath
    Apply-ClientPerformanceDefaults -Path $ClientPath
    Add-Completion 'Low-FPS client options and config defaults applied.'
    Disable-ClientFpsMods -Path $ClientPath
    Ensure-MinecraftBaseMetadata
    Add-Completion 'Minecraft 1.7.10 base metadata is available.'
    Install-ForgeClient
    Add-Completion 'Forge 10.13.4.1558 client metadata is installed.'
    Update-LauncherProfile
    Add-Completion "Minecraft Launcher profile '$PackName' updated and pinned to portable Java 8."
    Write-Rule -Title 'Client ready' -Color 'Green'
    Write-KeyValue -Name 'Client path' -Value $ClientPath
    Write-StatusLine -Kind 'OK' -Message "Launch the '$PackName' profile."
    Write-StatusLine -Kind 'INFO' -Message 'If menu FPS is still extremely low, close Minecraft and rerun diagnostics.'
    Write-CommandHint 'powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Minecraft-Pack.ps1 -Diagnose'
}

function Install-Server {
    if ([string]::IsNullOrWhiteSpace($ServerPath)) { throw 'Server mode requires -ServerPath.' }
    Ensure-Directory -Path $CacheRoot
    Ensure-PackZip $ServerZip | Out-Null
    Add-Completion 'Crazy Craft server payload is available in the local cache.'
    if ($VerifyOnly) {
        Verify-PackZip $ServerZip
        Add-Completion 'Verify-only completed: cached server payload hash is valid.'
        return
    }
    if ($DownloadOnly) {
        Add-Completion 'Download-only completed; no server files were staged.'
        return
    }

    Write-Step 'Staging Crazy Craft 4.0 server'
    if ($Force) { Remove-DirectoryIfPresent -Path $ServerPath }
    Ensure-Directory -Path $ServerPath
    foreach ($path in @('mods', 'config', 'libraries', 'logs', 'crash-reports', 'world', 'world_nether', 'world_the_end', 'DIM-1', 'DIM1')) {
        Remove-DirectoryIfPresent -Path (Join-Path $ServerPath $path)
    }
    Expand-PackArchive -ArchivePath (Get-PackZipPath $ServerZip) -DestinationPath $ServerPath -Activity 'Extracting Crazy Craft 4.0 server'
    Write-Host 'eula=true' | Set-Content -LiteralPath (Join-Path $ServerPath 'eula.txt') -Encoding ASCII
    Add-Completion "Server payload staged at $ServerPath."
    Add-Completion 'Server eula.txt written with eula=true.'
    Write-Rule -Title 'Server payload ready' -Color 'Green'
    Write-KeyValue -Name 'Server path' -Value $ServerPath
}

Write-InstallerHeader
try {
    if ($Client -and $Server) {
        throw 'Choose either -Client or -Server, not both.'
    }
    if ($Diagnose) {
        Diagnose-Client
    } elseif ($RestoreMenuFpsMods) {
        Restore-MenuFpsDiagnosticMods
        Diagnose-Client
    } elseif ($MenuFpsSafeMode) {
        Invoke-MenuFpsSafeMode
        Diagnose-Client
    } elseif ($Server) {
        Install-Server
    } else {
        Install-Client
    }
} catch {
    $script:FailureSummary = $_.Exception.Message
    throw
} finally {
    Write-CompletionSummary
}
