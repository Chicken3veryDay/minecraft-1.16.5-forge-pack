[CmdletBinding()]
param(
    [switch]$Server,
    [string]$ClientPath = (Join-Path $env:APPDATA '.minecraft\crazy-craft-4.0-official'),
    [string]$ServerPath,
    [switch]$VerifyOnly,
    [switch]$DownloadOnly,
    [switch]$Force
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

function Write-Step([string]$Message) {
    Write-Host ''
    Write-Host "== $Message ==" -ForegroundColor Cyan
    Write-Progress -Id 1 -Activity $PackName -Status $Message -PercentComplete 0
}

function Write-PackProgress([string]$Activity, [string]$Status, [int]$Percent, [int]$Id = 2) {
    Write-Progress -Id $Id -Activity $Activity -Status $Status -PercentComplete ([Math]::Max(0, [Math]::Min(100, $Percent)))
}

function Complete-PackProgress([string]$Activity, [int]$Id = 2) {
    Write-Progress -Id $Id -Activity $Activity -Completed
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
    Write-Host 'Closing Minecraft/Launcher so profile updates are applied...' -ForegroundColor Yellow
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
        $hasher = if ($Algorithm -eq 'SHA1') {
            [System.Security.Cryptography.SHA1]::Create()
        } else {
            [System.Security.Cryptography.SHA256]::Create()
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

    Write-Host "Downloading $Url"
    $request = [System.Net.HttpWebRequest]::Create($Url)
    $request.UserAgent = 'CrazyCraft4PortableInstaller'
    $response = $request.GetResponse()
    try {
        $total = [int64]$response.ContentLength
        $read = [int64]0
        $buffer = New-Object byte[] (1024 * 1024)
        $stream = $response.GetResponseStream()
        $file = [System.IO.File]::Open($tempPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try {
            while (($count = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $file.Write($buffer, 0, $count)
                $read += $count
                if ($total -gt 0) {
                    Write-PackProgress -Activity $Activity -Status ("{0:N1} / {1:N1} MB" -f ($read / 1MB), ($total / 1MB)) -Percent ([int](($read * 100) / $total))
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
        for ($i = 0; $i -lt $entries.Count; $i++) {
            $entry = $entries[$i]
            if ([string]::IsNullOrWhiteSpace($entry.FullName)) {
                continue
            }
            Write-PackProgress -Activity $Activity -Status $entry.FullName -Percent ([int](($i * 100) / $total))
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
        Write-Warning ".NET zip extraction failed for $(Split-Path -Leaf $ArchivePath): $($_.Exception.Message)"
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
    foreach ($rootName in @('mods', 'mods.disabled-client-fps')) {
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
        for ($i = 0; $i -lt $entries.Count; $i++) {
            $entry = $entries[$i]
            if ([string]::IsNullOrWhiteSpace($entry.FullName)) { continue }
            $normalized = $entry.FullName.Replace('\', '/')
            $isModJar = $normalized.StartsWith('mods/') -and $normalized.ToLowerInvariant().EndsWith('.jar')
            if ($isModJar -and $presentModNames.ContainsKey((Split-Path -Leaf $normalized).ToLowerInvariant())) {
                continue
            }

            Write-PackProgress -Activity 'Extracting Crazy Craft 4.0 client payload' -Status $entry.FullName -Percent ([int](($i * 100) / $total))
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
    Write-Host "Verified $($ZipInfo.Name): $($ZipInfo.Sha256)" -ForegroundColor Green
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
    if (-not (Test-Path -LiteralPath $modsRoot) -and -not (Test-Path -LiteralPath $disabledRoot)) {
        return $false
    }

    $presentNames = @{}
    foreach ($root in @($modsRoot, $disabledRoot)) {
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
    if (-not (Test-Path -LiteralPath $modsRoot) -and -not (Test-Path -LiteralPath $disabledRoot)) {
        return $false
    }
    $presentNames = @{}
    foreach ($root in @($modsRoot, $disabledRoot)) {
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

    foreach ($name in $ClientFpsDisabledMods) {
        $matches = @(Get-ChildItem -LiteralPath $modsRoot -Recurse -File -Filter $name -ErrorAction SilentlyContinue)
        foreach ($match in $matches) {
            Move-Item -LiteralPath $match.FullName -Destination (Join-Path $disabledRoot $match.Name) -Force
            Write-Host "Disabled client FPS mod: $($match.Name)" -ForegroundColor Yellow
        }
    }
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
        Write-Host "Required Crazy Craft mods already exist in $ClientPath\mods; skipping payload download." -ForegroundColor Green
    } else {
        Ensure-PackZip $ClientZip | Out-Null
    }
    Ensure-ForgeInstaller | Out-Null
    if ($VerifyOnly) {
        if ($modsAlreadyPresent) {
            Write-Host "Verified existing mods folder: all required Crazy Craft mods are present." -ForegroundColor Green
        } else {
            Verify-PackZip $ClientZip
        }
        return
    }
    if ($DownloadOnly) { return }

    Write-Step 'Staging Crazy Craft 4.0 client'
    if ($modsAlreadyPresent) {
        Remove-ServerRootFilesFromClient -Path $ClientPath
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
    Apply-ClientPerformanceDefaults -Path $ClientPath
    Disable-ClientFpsMods -Path $ClientPath
    Ensure-MinecraftBaseMetadata
    Install-ForgeClient
    Update-LauncherProfile
    Write-Host ''
    Write-Host "Client ready: $ClientPath" -ForegroundColor Green
}

function Install-Server {
    if ([string]::IsNullOrWhiteSpace($ServerPath)) { throw 'Server mode requires -ServerPath.' }
    Ensure-Directory -Path $CacheRoot
    Ensure-PackZip $ServerZip | Out-Null
    if ($VerifyOnly) {
        Verify-PackZip $ServerZip
        return
    }
    if ($DownloadOnly) { return }

    Write-Step 'Staging Crazy Craft 4.0 server'
    if ($Force) { Remove-DirectoryIfPresent -Path $ServerPath }
    Ensure-Directory -Path $ServerPath
    foreach ($path in @('mods', 'config', 'libraries', 'logs', 'crash-reports', 'world', 'world_nether', 'world_the_end', 'DIM-1', 'DIM1')) {
        Remove-DirectoryIfPresent -Path (Join-Path $ServerPath $path)
    }
    Expand-PackArchive -ArchivePath (Get-PackZipPath $ServerZip) -DestinationPath $ServerPath -Activity 'Extracting Crazy Craft 4.0 server'
    Write-Host 'eula=true' | Set-Content -LiteralPath (Join-Path $ServerPath 'eula.txt') -Encoding ASCII
    Write-Host ''
    Write-Host "Server payload ready: $ServerPath" -ForegroundColor Green
}

Write-Host "$PackName downloader"
Write-Host "Minecraft: 1.7.10"
Write-Host "Forge: 10.13.4.1558 ($ForgeVersionId)"
Write-Host "Pack root: $PackRoot"
if ($Server) { Install-Server } else { Install-Client }
