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
$PackName = 'Crazy Craft 4.0 Official'
$ProfileKey = 'crazy-craft-4.0-official'
$ForgeVersionId = '1.7.10-Forge10.13.4.1558-1.7.10'
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
        if ((Test-Java8 -Path $java) -and (Test-Path -LiteralPath $jar)) {
            return [pscustomobject]@{ Java = $java; Jar = $jar }
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
        if ((Test-Java8 -Path $java) -and (Test-Path -LiteralPath $jar)) {
            return [pscustomobject]@{ Java = $java; Jar = $jar }
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
    $profile = [pscustomobject]@{
        name = $PackName
        type = 'custom'
        created = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        lastUsed = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        lastVersionId = $ForgeVersionId
        gameDir = [System.IO.Path]::GetFullPath($ClientPath)
        javaArgs = '-Xms2G -Xmx4G -XX:+UseConcMarkSweepGC'
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

function Remove-ServerRootFilesFromClient([string]$Path) {
    foreach ($name in @('eula.txt', 'Start Server.bat', 'minecraft_server.1.7.10.jar', 'forge-1.7.10-10.13.4.1558-1.7.10-universal.jar')) {
        $target = Join-Path $Path $name
        if (Test-Path -LiteralPath $target) {
            Remove-Item -LiteralPath $target -Force
        }
    }
}

function Install-Client {
    Ensure-Directory -Path $CacheRoot
    Ensure-PackZip $ClientZip | Out-Null
    Ensure-ForgeInstaller | Out-Null
    if ($VerifyOnly) {
        Verify-PackZip $ClientZip
        return
    }
    if ($DownloadOnly) { return }

    Write-Step 'Staging Crazy Craft 4.0 client'
    if ($Force) { Remove-DirectoryIfPresent -Path $ClientPath }
    Ensure-Directory -Path $ClientPath
    foreach ($dir in @('mods', 'config', 'scripts', 'resources', 'resourcepacks', 'shaderpacks')) {
        Remove-DirectoryIfPresent -Path (Join-Path $ClientPath $dir)
    }
    Expand-PackArchive -ArchivePath (Get-PackZipPath $ClientZip) -DestinationPath $ClientPath -Activity 'Extracting Crazy Craft 4.0 client payload'
    Remove-ServerRootFilesFromClient -Path $ClientPath
    $modCount = Get-ModJarCount -Path $ClientPath
    if ($modCount -lt 60) {
        throw "Client staging failed; expected Crazy Craft mod files, found only $modCount mod jar(s)."
    }
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
Write-Host "Pack root: $PackRoot"
if ($Server) { Install-Server } else { Install-Client }
