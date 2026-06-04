[CmdletBinding()]
param(
    [switch]$Server,
    [string]$ServerPath,
    [switch]$SkipForgeInstall,
    [switch]$NoShader,
    [switch]$Force,
    [switch]$VerifyOnly,
    [string]$AssetBaseUrl,
    [switch]$SkipServerEntry,
    [switch]$SkipConnectionCheck,
    [int]$ConnectionCheckTimeoutSeconds = 5,
    [string]$ServerEntryName = 'Crazy Craft Updated',
    [string]$ServerEntryAddress = '192.3.179.150:25565',
    [string]$ClientMemoryMax = '8G',
    [string]$ClientMemoryMin = '4G'
)

$ErrorActionPreference = 'Stop'

$PackRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ManifestPath = Join-Path $PackRoot '.pack-manifest.json'
$MinecraftVersion = '1.16.5'
$ForgeVersion = '36.2.35'
$ForgeProfile = "$MinecraftVersion-forge-$ForgeVersion"
$LauncherProfileName = 'Crazy Craft Updated Forge'
$ForgeInstallerName = "forge-$MinecraftVersion-$ForgeVersion-installer.jar"
$ForgeInstallerUrl = "https://maven.minecraftforge.net/net/minecraftforge/forge/$MinecraftVersion-$ForgeVersion/$ForgeInstallerName"
$DownloadCacheRoot = Join-Path $PackRoot '_DownloadCache'
$script:PackManifest = $null
$script:AssetArchiveExtractRoot = $null
$script:AssetArchiveContentVerified = $false
$script:InstallReport = New-Object System.Collections.Generic.List[object]
$script:InstallFailed = $false

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "== $Message ==" -ForegroundColor Cyan
}

function Add-InstallStatus {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Details = ''
    )

    $script:InstallReport.Add([pscustomobject]@{
        Name = $Name
        Passed = $Passed
        Details = $Details
    })
}

function Stop-RunningMinecraftProcesses {
    $stopped = New-Object System.Collections.Generic.List[string]

    try {
        $processes = Get-CimInstance Win32_Process | Where-Object {
            $name = [string]$_.Name
            $commandLine = [string]$_.CommandLine

            (($name -in @('Minecraft.exe', 'MinecraftLauncher.exe')) -and
                ($commandLine -match 'launcherui|Minecraft Launcher|Microsoft\.4297127D64EC6|MinecraftLauncher')) -or
            (($name -in @('java.exe', 'javaw.exe')) -and
                ($commandLine -match 'minecraft\.launcher|net\.minecraft|\.minecraft'))
        }

        foreach ($process in @($processes)) {
            Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
            $stopped.Add("$($process.Name)#$($process.ProcessId)") | Out-Null
        }
    }
    catch {
        return "Could not inspect running Minecraft processes: $($_.Exception.Message)"
    }

    if ($stopped.Count -gt 0) {
        Start-Sleep -Seconds 3
        return "Stopped running Minecraft processes before editing launcher files: $($stopped -join ', ')"
    }

    return 'No running Minecraft Launcher or Minecraft Java process found.'
}

function Resolve-ServerEndpoint {
    param([string]$Address)

    if ([string]::IsNullOrWhiteSpace($Address)) {
        return $null
    }

    $trimmed = $Address.Trim()
    $hostName = $trimmed
    $port = 25565

    if ($trimmed -match '^\[(?<host>[^\]]+)\](?::(?<port>\d+))?$') {
        $hostName = $Matches.host
        if ($Matches.port) {
            $port = [int]$Matches.port
        }
    }
    elseif ($trimmed -match '^(?<host>.+):(?<port>\d+)$') {
        $hostName = $Matches.host
        $port = [int]$Matches.port
    }

    [pscustomobject]@{
        Host = $hostName
        Port = $port
    }
}

function Test-TcpEndpoint {
    param(
        [string]$HostName,
        [int]$Port,
        [int]$TimeoutSeconds = 5
    )

    $client = [Net.Sockets.TcpClient]::new()
    try {
        $async = $client.BeginConnect($HostName, $Port, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne([TimeSpan]::FromSeconds($TimeoutSeconds))) {
            return [pscustomobject]@{
                Passed = $false
                Details = "Timed out connecting to ${HostName}:${Port} after ${TimeoutSeconds}s."
            }
        }

        $client.EndConnect($async)
        [pscustomobject]@{
            Passed = $true
            Details = "TCP connection succeeded to ${HostName}:${Port}."
        }
    }
    catch {
        [pscustomobject]@{
            Passed = $false
            Details = "TCP connection failed to ${HostName}:${Port}: $($_.Exception.Message)"
        }
    }
    finally {
        $client.Close()
    }
}

function Get-LauncherAccountStatus {
    param([string]$MinecraftDir)

    $accountFiles = @(
        (Join-Path $MinecraftDir 'launcher_accounts_microsoft_store.json'),
        (Join-Path $MinecraftDir 'launcher_accounts.json')
    )

    foreach ($accountPath in $accountFiles) {
        if (-not (Test-Path -LiteralPath $accountPath)) {
            continue
        }

        try {
            $data = Get-Content -LiteralPath $accountPath -Raw | ConvertFrom-Json
            $accounts = $data.accounts
            $accountCount = 0
            if ($null -ne $accounts) {
                $accountCount = @($accounts.PSObject.Properties).Count
            }

            if ($accountCount -eq 0) {
                continue
            }

            $activeAccountId = [string]$data.activeAccountLocalId
            $activeAccount = $null
            if (-not [string]::IsNullOrWhiteSpace($activeAccountId)) {
                $activeAccount = $accounts.PSObject.Properties |
                    Where-Object { $_.Name -eq $activeAccountId } |
                    Select-Object -First 1
            }

            if ($null -eq $activeAccount) {
                $activeAccount = $accounts.PSObject.Properties | Select-Object -First 1
            }

            if ($null -ne $activeAccount) {
                $profile = $activeAccount.Value.minecraftProfile
                $profileName = [string]$profile.name
                if ([string]::IsNullOrWhiteSpace($profileName)) {
                    $profileName = [string]$activeAccount.Value.username
                }
                if ([string]::IsNullOrWhiteSpace($profileName)) {
                    $profileName = $activeAccount.Name
                }

                return [pscustomobject]@{
                    Passed = $true
                    Details = "Active launcher account found in $(Split-Path -Leaf $accountPath): $profileName"
                }
            }
        }
        catch {
            return [pscustomobject]@{
                Passed = $false
                Details = "Could not read $(Split-Path -Leaf $accountPath): $($_.Exception.Message)"
            }
        }
    }

    [pscustomobject]@{
        Passed = $false
        Details = "No active Minecraft Launcher account was found. Open Minecraft Launcher, sign in, close it, then press Play on the $LauncherProfileName profile."
    }
}

function Add-ClientConnectionPrereqReport {
    param([string]$MinecraftDir)

    if ($SkipConnectionCheck) {
        Add-InstallStatus -Name 'Check connection prerequisites' -Passed $true -Details 'Skipped by -SkipConnectionCheck.'
        return
    }

    $endpoint = Resolve-ServerEndpoint -Address $ServerEntryAddress
    if ($null -ne $endpoint) {
        $serverResult = Test-TcpEndpoint -HostName $endpoint.Host -Port $endpoint.Port -TimeoutSeconds $ConnectionCheckTimeoutSeconds
        Add-InstallStatus -Name 'Reach Minecraft server' -Passed $serverResult.Passed -Details $serverResult.Details
    }

    $accountResult = Get-LauncherAccountStatus -MinecraftDir $MinecraftDir
    Add-InstallStatus -Name 'Detect launcher account' -Passed $accountResult.Passed -Details $accountResult.Details
    if (-not $accountResult.Passed) {
        Write-Host $accountResult.Details -ForegroundColor Yellow
    }
}

function Write-InstallReport {
    Write-Host ""
    Write-Host "== Install status report ==" -ForegroundColor Cyan

    if ($script:InstallReport.Count -eq 0) {
        Write-Host "[FAIL] No install steps completed." -ForegroundColor Red
        return
    }

    foreach ($item in $script:InstallReport) {
        if ($item.Passed) {
            Write-Host ("[PASS] {0}" -f $item.Name) -ForegroundColor Green
        }
        else {
            Write-Host ("[FAIL] {0}" -f $item.Name) -ForegroundColor Red
        }

        if (-not [string]::IsNullOrWhiteSpace($item.Details)) {
            Write-Host ("       {0}" -f $item.Details)
        }
    }
}

function Read-Manifest {
    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        throw "Missing .pack-manifest.json beside the installer."
    }

    Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
}

function Get-FileHashSha256 {
    param([string]$Path)
    if (Get-Command Get-FileHash -ErrorAction SilentlyContinue) {
        return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    }

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        try {
            return (($sha256.ComputeHash($stream) | ForEach-Object { $_.ToString('x2') }) -join '')
        }
        finally {
            $sha256.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Invoke-DownloadFile {
    param(
        [string]$Uri,
        [string]$OutFile,
        [string]$Label = 'file',
        [int]$Attempts = 3
    )

    $parent = Split-Path -Parent $OutFile
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        Ensure-Directory -Path $parent
    }

    $tempPath = "$OutFile.download"
    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }

        try {
            $requestArgs = @{
                Uri = $Uri
                OutFile = $tempPath
                ErrorAction = 'Stop'
            }

            if ((Get-Command Invoke-WebRequest).Parameters.ContainsKey('UseBasicParsing')) {
                $requestArgs['UseBasicParsing'] = $true
            }

            Invoke-WebRequest @requestArgs

            if (-not (Test-Path -LiteralPath $tempPath)) {
                throw 'No file was written.'
            }

            if ((Get-Item -LiteralPath $tempPath).Length -le 0) {
                throw 'Downloaded file was empty.'
            }

            Move-Item -LiteralPath $tempPath -Destination $OutFile -Force
            return
        }
        catch {
            $message = $_.Exception.Message
            if (Test-Path -LiteralPath $tempPath) {
                Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
            }

            if ($attempt -ge $Attempts) {
                throw "Could not download $Label from $Uri after $Attempts attempt(s): $message"
            }

            Write-Host "Download failed for $Label (attempt $attempt of $Attempts): $message"
            Start-Sleep -Seconds ([Math]::Min(10, 2 * $attempt))
        }
    }
}

function Get-ManifestAssetItems {
    param([object]$Manifest)

    foreach ($section in @('client', 'config', 'root', 'shaderpacks', 'server')) {
        $items = $Manifest.$section
        if ($null -ne $items) {
            foreach ($item in @($items)) {
                $item
            }
        }
    }
}

function Assert-ExtractedAssetArchiveContents {
    param([string]$ExtractRoot)

    foreach ($item in Get-ManifestAssetItems -Manifest $script:PackManifest) {
        $archivedPath = Join-Path $ExtractRoot $item.path
        if (-not (Test-Path -LiteralPath $archivedPath)) {
            throw "Hosted asset archive did not contain required file: $($item.path)."
        }

        $actual = Get-FileHashSha256 -Path $archivedPath
        if ($actual -ne $item.sha256) {
            throw "Hash mismatch for hosted asset $($item.path). Expected $($item.sha256), got $actual."
        }
    }

    $script:AssetArchiveContentVerified = $true
}

function Get-AssetDownloadUrl {
    param([object]$Item)

    if ($null -ne $Item.url -and -not [string]::IsNullOrWhiteSpace($Item.url)) {
        return $Item.url
    }

    if (-not [string]::IsNullOrWhiteSpace($AssetBaseUrl)) {
        $base = $AssetBaseUrl.TrimEnd('/')
        $segments = $Item.path.Replace('\', '/').Split('/')
        $encoded = $segments | ForEach-Object { [uri]::EscapeDataString($_) }
        return "$base/$($encoded -join '/')"
    }

    return $null
}

function Get-AssetArchiveFileName {
    param([object]$Archive)

    if ($null -ne $Archive.name -and -not [string]::IsNullOrWhiteSpace($Archive.name)) {
        return $Archive.name
    }

    try {
        $uri = [uri]$Archive.url
        $leaf = Split-Path -Leaf $uri.LocalPath
        if (-not [string]::IsNullOrWhiteSpace($leaf)) {
            return $leaf
        }
    }
    catch {
    }

    return 'pack-assets.zip'
}

function Ensure-AssetArchiveExtracted {
    $archive = $script:PackManifest.assetArchive
    if ($null -eq $archive) {
        return $null
    }

    if ($script:AssetArchiveExtractRoot -and (Test-Path -LiteralPath $script:AssetArchiveExtractRoot)) {
        return $script:AssetArchiveExtractRoot
    }

    if ([string]::IsNullOrWhiteSpace($archive.url)) {
        throw "Manifest assetArchive needs a url for fresh-PC installs."
    }

    Ensure-Directory -Path $DownloadCacheRoot
    $archiveName = Get-AssetArchiveFileName -Archive $archive
    $archivePath = Join-Path $DownloadCacheRoot $archiveName
    $extractRoot = Join-Path $DownloadCacheRoot 'assets'
    $hasExpectedArchiveHash = -not [string]::IsNullOrWhiteSpace($archive.sha256)
    $expectedArchiveHash = ''
    if ($hasExpectedArchiveHash) {
        $expectedArchiveHash = ([string]$archive.sha256).ToLowerInvariant()
    }

    $forceDownload = $false
    while ($true) {
        $downloadedThisPass = $false
        if ($forceDownload -or -not (Test-Path -LiteralPath $archivePath)) {
            Write-Host "Downloading hosted pack assets..."
            Write-Host "URL: $($archive.url)"
            Invoke-DownloadFile -Uri $archive.url -OutFile $archivePath -Label $archiveName
            $downloadedThisPass = $true
            $forceDownload = $false
        }

        $needsContentValidation = $false
        if ($hasExpectedArchiveHash) {
            $actualArchiveHash = Get-FileHashSha256 -Path $archivePath
            if ($actualArchiveHash -eq $expectedArchiveHash) {
                if ($downloadedThisPass) {
                    Write-Host "Downloaded asset archive hash verified."
                }
                else {
                    Write-Host "Using cached asset archive: $archiveName"
                }
            }
            else {
                if ($downloadedThisPass) {
                    Write-Host "Hosted asset archive byte hash mismatch. Expected $expectedArchiveHash, got $actualArchiveHash."
                }
                else {
                    Write-Host "Cached asset archive byte hash mismatch. Verifying contained files before re-downloading..."
                }
                $needsContentValidation = $true
            }
        }
        else {
            Write-Host "Manifest assetArchive has no byte hash; verifying contained files."
            $needsContentValidation = $true
        }

        if (Test-Path -LiteralPath $extractRoot) {
            Remove-Item -LiteralPath $extractRoot -Recurse -Force
        }

        Ensure-Directory -Path $extractRoot
        try {
            Expand-Archive -LiteralPath $archivePath -DestinationPath $extractRoot -Force
        }
        catch {
            if (-not $downloadedThisPass) {
                Write-Host "Cached asset archive could not be extracted. Re-downloading..."
                $forceDownload = $true
                continue
            }

            throw "Could not extract hosted asset archive '$archiveName': $($_.Exception.Message)"
        }

        $layoutRoot = $extractRoot
        if ($null -ne $archive.layoutRoot -and -not [string]::IsNullOrWhiteSpace($archive.layoutRoot)) {
            $layoutRoot = Join-Path $extractRoot $archive.layoutRoot
        }

        if (-not (Test-Path -LiteralPath $layoutRoot)) {
            throw "Hosted asset archive extracted, but layoutRoot '$($archive.layoutRoot)' was not found."
        }

        if ($needsContentValidation) {
            try {
                Assert-ExtractedAssetArchiveContents -ExtractRoot $layoutRoot
                Write-Host "Archive byte hash differed, but every contained file matched the manifest. Continuing."
            }
            catch {
                if (-not $downloadedThisPass) {
                    Write-Host "Cached asset archive contents did not match the manifest. Re-downloading..."
                    $forceDownload = $true
                    continue
                }

                throw "Hosted asset archive failed both archive and contained-file verification. $($_.Exception.Message)"
            }
        }

        $script:AssetArchiveExtractRoot = $layoutRoot
        break
    }

    return $script:AssetArchiveExtractRoot
}

function Resolve-ArchivedAssetSource {
    param([object]$Item)

    $assetRoot = Ensure-AssetArchiveExtracted
    if ($null -eq $assetRoot) {
        return $null
    }

    $archivedPath = Join-Path $assetRoot $Item.path
    if (-not (Test-Path -LiteralPath $archivedPath)) {
        throw "Hosted asset archive did not contain required file: $($Item.path)."
    }

    if (-not $script:AssetArchiveContentVerified) {
        $actual = Get-FileHashSha256 -Path $archivedPath
        if ($actual -ne $Item.sha256) {
            throw "Hash mismatch for hosted asset $($Item.path). Expected $($Item.sha256), got $actual."
        }
    }

    return $archivedPath
}

function Resolve-AssetSource {
    param([object]$Item)

    $bundledPath = Join-Path $PackRoot $Item.path
    if (Test-Path -LiteralPath $bundledPath) {
        $actual = Get-FileHashSha256 -Path $bundledPath
        if ($actual -ne $Item.sha256) {
            throw "Hash mismatch for bundled file $($Item.path). Expected $($Item.sha256), got $actual."
        }

        return $bundledPath
    }

    $archivedPath = Resolve-ArchivedAssetSource -Item $Item
    if ($null -ne $archivedPath) {
        return $archivedPath
    }

    $url = Get-AssetDownloadUrl -Item $Item
    if ($null -eq $url) {
        throw "Missing pack asset: $($Item.path). No local copy, hosted asset archive, or download URL was available."
    }

    $cachePath = Join-Path $DownloadCacheRoot $Item.path
    if (Test-Path -LiteralPath $cachePath) {
        $actual = Get-FileHashSha256 -Path $cachePath
        if ($actual -eq $Item.sha256) {
            Write-Host "Using cached download for $($Item.path)."
            return $cachePath
        }

        Write-Host "Cached file hash mismatch for $($Item.path). Re-downloading..."
    }

    Ensure-Directory -Path (Split-Path -Parent $cachePath)
    Write-Host "Downloading $($Item.path)"
    Write-Host "URL: $url"
    Invoke-DownloadFile -Uri $url -OutFile $cachePath -Label $Item.path

    $downloaded = Get-FileHashSha256 -Path $cachePath
    if ($downloaded -ne $Item.sha256) {
        throw "Download hash mismatch for $($Item.path). Expected $($Item.sha256), got $downloaded."
    }

    return $cachePath
}

function Assert-BundledFiles {
    param(
        [object]$Manifest,
        [string[]]$Sections
    )

    foreach ($section in $Sections) {
        $items = $Manifest.$section
        if ($null -eq $items) {
            throw "Manifest is missing section '$section'."
        }

        foreach ($item in $items) {
            $null = Resolve-AssetSource -Item $item
        }
    }
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Set-TextUtf8NoBom {
    param(
        [string]$Path,
        [string]$Value
    )

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Value, $encoding)
}

function Write-RestoreScripts {
    param([string]$BackupRoot)

    $restorePs1 = Join-Path $BackupRoot 'Restore-Previous-Mods-And-Configs.ps1'
    $restoreBat = Join-Path $BackupRoot 'Restore-Previous-Mods-And-Configs.bat'

    @'
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$BackupRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$MinecraftDir = Join-Path $env:APPDATA '.minecraft'

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

Ensure-Directory -Path $MinecraftDir

foreach ($folderName in @('mods', 'config', 'defaultconfigs', 'kubejs')) {
    $source = Join-Path $BackupRoot $folderName
    $target = Join-Path $MinecraftDir $folderName

    if (Test-Path -LiteralPath $target) {
        Remove-Item -LiteralPath $target -Recurse -Force
    }

    if (Test-Path -LiteralPath $source) {
        Copy-Item -LiteralPath $source -Destination $target -Recurse -Force
        Write-Host "Restored $folderName to $target"
    }
    else {
        Write-Host "No backed up $folderName folder found; removed current $folderName folder if it existed."
    }
}

Write-Host ""
Write-Host "Restore complete."
'@ | Set-Content -LiteralPath $restorePs1 -Encoding UTF8

    @'
@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Restore-Previous-Mods-And-Configs.ps1"
set EXITCODE=%ERRORLEVEL%
echo.
if not "%EXITCODE%"=="0" (
  echo Restore failed with exit code %EXITCODE%.
) else (
  echo Restore completed successfully.
)
pause
exit /b %EXITCODE%
'@ | Set-Content -LiteralPath $restoreBat -Encoding ASCII
}

function Backup-And-ClearClientState {
    param([string]$MinecraftDir)

    $backupRoot = Join-Path $MinecraftDir ("_PackBackups\backup-{0}" -f (Get-Date -Format yyyyMMdd-HHmmss))
    Ensure-Directory -Path $backupRoot

    $backedUp = New-Object System.Collections.Generic.List[string]
    foreach ($folderName in @('mods', 'config', 'defaultconfigs', 'kubejs')) {
        $source = Join-Path $MinecraftDir $folderName
        $target = Join-Path $backupRoot $folderName

        if (Test-Path -LiteralPath $source) {
            Copy-Item -LiteralPath $source -Destination $target -Recurse -Force
            Remove-Item -LiteralPath $source -Recurse -Force
            $backedUp.Add($folderName)
        }
    }

    Write-RestoreScripts -BackupRoot $backupRoot

    if ($backedUp.Count -eq 0) {
        Add-InstallStatus -Name 'Backup previous mods/configs' -Passed $true -Details "No existing mods or config folders were found. Restore command created at $backupRoot."
    }
    else {
        Add-InstallStatus -Name 'Backup previous mods/configs' -Passed $true -Details "Backed up and cleared: $($backedUp -join ', '). Restore with $backupRoot\Restore-Previous-Mods-And-Configs.bat"
    }

    return $backupRoot
}

function Backup-And-ClearServerState {
    param([string]$ServerPath)

    $backupRoot = Join-Path $ServerPath ("_PackBackups\backup-{0}" -f (Get-Date -Format yyyyMMdd-HHmmss))
    Ensure-Directory -Path $backupRoot

    $backedUp = New-Object System.Collections.Generic.List[string]
    foreach ($folderName in @('mods', 'config', 'defaultconfigs', 'kubejs', 'scripts', 'resourcepacks', 'datapacks', 'libraries')) {
        $source = Join-Path $ServerPath $folderName
        $target = Join-Path $backupRoot $folderName

        if (Test-Path -LiteralPath $source) {
            Copy-Item -LiteralPath $source -Destination $target -Recurse -Force
            Remove-Item -LiteralPath $source -Recurse -Force
            $backedUp.Add($folderName) | Out-Null
        }
    }

    foreach ($pattern in @('forge*.jar', 'minecraft_server*.jar', 'start*.bat', 'run*.sh', 'user_jvm_args.txt', 'server-icon.png')) {
        foreach ($source in @(Get-ChildItem -LiteralPath $ServerPath -Filter $pattern -File -ErrorAction SilentlyContinue)) {
            Copy-Item -LiteralPath $source.FullName -Destination (Join-Path $backupRoot $source.Name) -Force
            Remove-Item -LiteralPath $source.FullName -Force
            $backedUp.Add($source.Name) | Out-Null
        }
    }

    if ($backedUp.Count -eq 0) {
        Add-InstallStatus -Name 'Backup previous server pack files' -Passed $true -Details 'No existing server pack files were found.'
    }
    else {
        Add-InstallStatus -Name 'Backup previous server pack files' -Passed $true -Details "Backed up and cleared: $($backedUp -join ', ')"
    }

    return $backupRoot
}

function Find-Java {
    $candidates = New-Object System.Collections.Generic.List[string]

    $pathJava = Get-Command java.exe -ErrorAction SilentlyContinue
    if ($null -ne $pathJava) {
        $candidates.Add($pathJava.Source)
    }

    if (-not [string]::IsNullOrWhiteSpace($env:JAVA_HOME)) {
        $candidates.Add((Join-Path $env:JAVA_HOME 'bin\java.exe'))
    }

    $candidateRoots = New-Object System.Collections.Generic.List[string]
    function Add-JavaRoot {
        param(
            [string]$Base,
            [string]$Child
        )

        if (-not [string]::IsNullOrWhiteSpace($Base)) {
            $path = Join-Path $Base $Child
            if (Test-Path -LiteralPath $path) {
                $candidateRoots.Add($path)
            }
        }
    }

    Add-JavaRoot -Base $env:APPDATA -Child '.minecraft\runtime'
    Add-JavaRoot -Base $env:LOCALAPPDATA -Child 'Packages\Microsoft.4297127D64EC6_8wekyb3d8bbwe\LocalCache\Local\runtime'
    Add-JavaRoot -Base ${env:ProgramFiles(x86)} -Child 'Minecraft Launcher\runtime'
    Add-JavaRoot -Base $env:ProgramFiles -Child 'Minecraft Launcher\runtime'
    Add-JavaRoot -Base $env:ProgramFiles -Child 'Java'
    Add-JavaRoot -Base ${env:ProgramFiles(x86)} -Child 'Java'
    Add-JavaRoot -Base $env:ProgramFiles -Child 'Eclipse Adoptium'
    Add-JavaRoot -Base ${env:ProgramFiles(x86)} -Child 'Eclipse Adoptium'

    foreach ($root in $candidateRoots) {
        Get-ChildItem -LiteralPath $root -Filter java.exe -Recurse -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            ForEach-Object { $candidates.Add($_.FullName) }
    }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    return $null
}

function Ensure-LauncherProfiles {
    param([string]$MinecraftDir)

    $profilesPath = Join-Path $MinecraftDir 'launcher_profiles.json'
    if (Test-Path -LiteralPath $profilesPath) {
        try {
            Get-Content -LiteralPath $profilesPath -Raw | ConvertFrom-Json | Out-Null
            return
        }
        catch {
            $backupPath = "$profilesPath.broken-$(Get-Date -Format yyyyMMddHHmmss)"
            Move-Item -LiteralPath $profilesPath -Destination $backupPath -Force
            Write-Host "Backed up unreadable launcher_profiles.json to $backupPath"
        }
    }

    $clientToken = [guid]::NewGuid().ToString()
    $profiles = [ordered]@{
        profiles = [ordered]@{}
        selectedProfile = ''
        clientToken = $clientToken
        authenticationDatabase = [ordered]@{}
        launcherVersion = [ordered]@{
            name = 'CodexPackInstaller'
            format = 21
        }
    }

    Set-TextUtf8NoBom -Path $profilesPath -Value ($profiles | ConvertTo-Json -Depth 10)
    Write-Host "Created launcher_profiles.json for Forge installer compatibility."
}

function Set-ForgeLauncherProfileMemory {
    param([string]$MinecraftDir)

    $profileFileNames = @('launcher_profiles.json', 'launcher_profiles_microsoft_store.json')
    $profilePaths = @($profileFileNames | ForEach-Object { Join-Path $MinecraftDir $_ })
    $sourcePath = $profilePaths | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($null -eq $sourcePath) {
        return [pscustomobject]@{
            Details = 'Skipped memory config because no launcher profile file was found.'
            ProfileIds = @()
        }
    }

    $sourceData = Get-Content -LiteralPath $sourcePath -Raw | ConvertFrom-Json
    $details = New-Object System.Collections.Generic.List[string]
    $profileIds = New-Object System.Collections.Generic.List[string]

    foreach ($profilesPath in $profilePaths) {
        if (Test-Path -LiteralPath $profilesPath) {
            $profilesData = Get-Content -LiteralPath $profilesPath -Raw | ConvertFrom-Json
            $profileMode = 'updated'
        }
        else {
            $profilesData = $sourceData | ConvertTo-Json -Depth 100 | ConvertFrom-Json
            $profileMode = 'created profile file'
        }

        if ($null -eq $profilesData.profiles) {
            $profilesData | Add-Member -NotePropertyName 'profiles' -NotePropertyValue ([pscustomobject]@{}) -Force
        }

        $targetProfile = $null
        $targetProfileId = $null
        foreach ($profileProperty in $profilesData.profiles.PSObject.Properties) {
            $profile = $profileProperty.Value
            if (($profile.lastVersionId -eq $ForgeProfile) -or ($profile.name -eq $LauncherProfileName) -or ($profile.name -eq $ForgeProfile)) {
                $targetProfile = $profile
                $targetProfileId = $profileProperty.Name
                break
            }
        }

        if ($null -eq $targetProfile) {
            foreach ($profileProperty in $profilesData.profiles.PSObject.Properties) {
                $profile = $profileProperty.Value
                if (($profile.lastVersionId -eq 'latest-release') -or ($profile.type -eq 'latest-release')) {
                    $targetProfile = $profile
                    $targetProfileId = $profileProperty.Name
                    if ($profileMode -eq 'updated') {
                        $profileMode = 'repurposed latest-release'
                    }
                    break
                }
            }
        }

        if ($null -eq $targetProfile) {
            $targetProfileId = 'forge'
            $now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            $targetProfile = [pscustomobject]@{
                name = $LauncherProfileName
                type = 'custom'
                icon = 'Furnace'
                created = $now
                lastUsed = $now
                lastVersionId = $ForgeProfile
            }
            $profilesData.profiles | Add-Member -NotePropertyName $targetProfileId -NotePropertyValue $targetProfile -Force
            $profileMode = 'created fallback profile'
        }

        $existingArgs = [string]$targetProfile.javaArgs
        $keptArgs = @()
        if (-not [string]::IsNullOrWhiteSpace($existingArgs)) {
            $keptArgs = $existingArgs -split '\s+' | Where-Object { $_ -and ($_ -notmatch '^-Xm[sx]') }
        }

        $javaArgs = (@("-Xmx$ClientMemoryMax", "-Xms$ClientMemoryMin") + @($keptArgs)) -join ' '
        $targetProfile | Add-Member -NotePropertyName 'lastVersionId' -NotePropertyValue $ForgeProfile -Force
        $targetProfile | Add-Member -NotePropertyName 'type' -NotePropertyValue 'custom' -Force
        $targetProfile | Add-Member -NotePropertyName 'icon' -NotePropertyValue 'Furnace' -Force
        $targetProfile | Add-Member -NotePropertyName 'name' -NotePropertyValue $LauncherProfileName -Force
        $targetProfile | Add-Member -NotePropertyName 'lastUsed' -NotePropertyValue ((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')) -Force
        $targetProfile | Add-Member -NotePropertyName 'javaArgs' -NotePropertyValue $javaArgs -Force
        $profilesData | Add-Member -NotePropertyName 'selectedProfile' -NotePropertyValue $targetProfileId -Force
        Set-TextUtf8NoBom -Path $profilesPath -Value ($profilesData | ConvertTo-Json -Depth 100)

        $profileIds.Add($targetProfileId) | Out-Null
        $details.Add("$(Split-Path -Leaf $profilesPath): $targetProfileId ($profileMode)") | Out-Null
    }

    [pscustomobject]@{
        Details = "Set $LauncherProfileName launcher profiles with memory -Xmx${ClientMemoryMax} -Xms${ClientMemoryMin}: $($details -join '; ')"
        ProfileIds = @($profileIds | Select-Object -Unique)
    }
}

function Set-LauncherSafetyWarningAccepted {
    param(
        [string]$MinecraftDir,
        [string[]]$ProfileIds
    )

    $uiStatePath = Join-Path $MinecraftDir 'launcher_ui_state_microsoft_store.json'
    if (-not (Test-Path -LiteralPath $uiStatePath)) {
        return 'Skipped custom-installation warning config because launcher_ui_state_microsoft_store.json was not found.'
    }

    $raw = Get-Content -LiteralPath $uiStatePath -Raw
    $prefix = ''
    $jsonText = $raw
    $jsonStart = $raw.IndexOf('{')
    if ($jsonStart -gt 0) {
        $prefix = $raw.Substring(0, $jsonStart)
        $jsonText = $raw.Substring($jsonStart)
    }

    $state = $jsonText | ConvertFrom-Json
    if ($null -eq $state.data) {
        $state | Add-Member -NotePropertyName 'data' -NotePropertyValue ([pscustomobject]@{}) -Force
    }

    $uiEventsText = [string]$state.data.UiEvents
    if ([string]::IsNullOrWhiteSpace($uiEventsText)) {
        $uiEvents = [pscustomobject]@{}
    }
    else {
        $uiEvents = $uiEventsText | ConvertFrom-Json
    }

    if ($null -eq $uiEvents.hidePlayerSafetyDisclaimer) {
        $uiEvents | Add-Member -NotePropertyName 'hidePlayerSafetyDisclaimer' -NotePropertyValue ([pscustomobject]@{}) -Force
    }

    $idsToMark = @($ProfileIds) + @('forge', $ForgeProfile)
    foreach ($profileId in ($idsToMark | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)) {
        $key = "${ForgeProfile}_${profileId}"
        $uiEvents.hidePlayerSafetyDisclaimer | Add-Member -NotePropertyName $key -NotePropertyValue $true -Force
    }

    $state.data | Add-Member -NotePropertyName 'UiEvents' -NotePropertyValue ($uiEvents | ConvertTo-Json -Depth 100 -Compress) -Force
    Set-TextUtf8NoBom -Path $uiStatePath -Value ($state | ConvertTo-Json -Depth 100)
    "Accepted custom-installation safety warning for $ForgeProfile."
}

function Set-ForgeVersionJvmMemory {
    param([string]$MinecraftDir)

    $versionJson = Join-Path $MinecraftDir "versions\$ForgeProfile\$ForgeProfile.json"
    if (-not (Test-Path -LiteralPath $versionJson)) {
        return "Skipped version JVM memory because Forge version JSON was not found: $ForgeProfile"
    }

    $versionData = Get-Content -LiteralPath $versionJson -Raw | ConvertFrom-Json
    $standaloneDetails = 'already standalone'
    $parentVersion = [string]$versionData.inheritsFrom
    if (-not [string]::IsNullOrWhiteSpace($parentVersion)) {
        $parentJson = Join-Path $MinecraftDir "versions\$parentVersion\$parentVersion.json"
        if (Test-Path -LiteralPath $parentJson) {
            $parentData = Get-Content -LiteralPath $parentJson -Raw | ConvertFrom-Json
            $childData = $versionData
            $mergedData = $parentData | ConvertTo-Json -Depth 100 | ConvertFrom-Json

            foreach ($property in $childData.PSObject.Properties) {
                if ($property.Name -notin @('arguments', 'libraries', 'inheritsFrom')) {
                    $mergedData | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value -Force
                }
            }

            if ($null -ne $mergedData.PSObject.Properties['inheritsFrom']) {
                $mergedData.PSObject.Properties.Remove('inheritsFrom')
            }

            $mergedData | Add-Member -NotePropertyName 'id' -NotePropertyValue $ForgeProfile -Force
            $mergedData | Add-Member -NotePropertyName 'libraries' -NotePropertyValue (@($childData.libraries) + @($parentData.libraries)) -Force

            if ($null -eq $mergedData.arguments) {
                $mergedData | Add-Member -NotePropertyName 'arguments' -NotePropertyValue ([pscustomobject]@{}) -Force
            }

            $parentGameArgs = @()
            if ($null -ne $parentData.arguments -and $null -ne $parentData.arguments.game) {
                $parentGameArgs = @($parentData.arguments.game)
            }

            $childGameArgs = @()
            if ($null -ne $childData.arguments -and $null -ne $childData.arguments.game) {
                $childGameArgs = @($childData.arguments.game)
            }

            $parentJvmArgs = @()
            if ($null -ne $parentData.arguments -and $null -ne $parentData.arguments.jvm) {
                $parentJvmArgs = @($parentData.arguments.jvm)
            }

            $childJvmArgs = @()
            if ($null -ne $childData.arguments -and $null -ne $childData.arguments.jvm) {
                $childJvmArgs = @($childData.arguments.jvm)
            }

            $mergedData.arguments | Add-Member -NotePropertyName 'game' -NotePropertyValue (@($parentGameArgs) + @($childGameArgs)) -Force
            $mergedData.arguments | Add-Member -NotePropertyName 'jvm' -NotePropertyValue (@($childJvmArgs) + @($parentJvmArgs)) -Force
            $versionData = $mergedData
            $standaloneDetails = "merged parent $parentVersion"
        }
        else {
            $standaloneDetails = "parent $parentVersion not found"
        }
    }

    if ($null -eq $versionData.arguments) {
        $versionData | Add-Member -NotePropertyName 'arguments' -NotePropertyValue ([pscustomobject]@{}) -Force
    }

    $existingJvmArgs = @()
    if ($null -ne $versionData.arguments.jvm) {
        $existingJvmArgs = @($versionData.arguments.jvm) | Where-Object {
            -not (($_ -is [string]) -and ($_ -match '^-Xm[sx]'))
        }
    }

    $jvmArgs = @($existingJvmArgs) + @("-Xms$ClientMemoryMin", "-Xmx$ClientMemoryMax")
    $versionData.arguments | Add-Member -NotePropertyName 'jvm' -NotePropertyValue $jvmArgs -Force

    $defaultUserJvm = @(
        [pscustomobject]@{
            value = @(
                "-Xms$ClientMemoryMin",
                "-Xmx$ClientMemoryMax",
                '-XX:+UnlockExperimentalVMOptions',
                '-XX:+UseG1GC',
                '-XX:G1NewSizePercent=20',
                '-XX:G1ReservePercent=20',
                '-XX:MaxGCPauseMillis=50',
                '-XX:G1HeapRegionSize=32M'
            )
        }
    )
    $versionData.arguments | Add-Member -NotePropertyName 'default-user-jvm' -NotePropertyValue $defaultUserJvm -Force

    Set-TextUtf8NoBom -Path $versionJson -Value ($versionData | ConvertTo-Json -Depth 100)
    "Set Forge version JVM memory and default launcher heap ($standaloneDetails): -Xms$ClientMemoryMin -Xmx$ClientMemoryMax"
}

function New-NbtTag {
    param(
        [int]$Type,
        [string]$Name = '',
        [object]$Value = $null,
        [int]$ElemType = -1
    )

    $tag = [ordered]@{
        Type = [byte]$Type
        Name = $Name
        Value = $Value
    }

    if ($ElemType -ge 0) {
        $tag.ElemType = [byte]$ElemType
    }

    [pscustomobject]$tag
}

function Read-NbtBytes {
    param(
        [System.IO.BinaryReader]$Reader,
        [int]$Count
    )

    $bytes = $Reader.ReadBytes($Count)
    if ($bytes.Length -ne $Count) {
        throw 'Unexpected end of NBT file.'
    }
    $bytes
}

function Convert-FromBigEndian {
    param([byte[]]$Bytes)

    if ([BitConverter]::IsLittleEndian) {
        [Array]::Reverse($Bytes)
    }
    $Bytes
}

function Read-NbtInt16 {
    param([System.IO.BinaryReader]$Reader)
    [BitConverter]::ToInt16((Convert-FromBigEndian -Bytes (Read-NbtBytes -Reader $Reader -Count 2)), 0)
}

function Read-NbtInt32 {
    param([System.IO.BinaryReader]$Reader)
    [BitConverter]::ToInt32((Convert-FromBigEndian -Bytes (Read-NbtBytes -Reader $Reader -Count 4)), 0)
}

function Read-NbtInt64 {
    param([System.IO.BinaryReader]$Reader)
    [BitConverter]::ToInt64((Convert-FromBigEndian -Bytes (Read-NbtBytes -Reader $Reader -Count 8)), 0)
}

function Read-NbtFloat {
    param([System.IO.BinaryReader]$Reader)
    [BitConverter]::ToSingle((Convert-FromBigEndian -Bytes (Read-NbtBytes -Reader $Reader -Count 4)), 0)
}

function Read-NbtDouble {
    param([System.IO.BinaryReader]$Reader)
    [BitConverter]::ToDouble((Convert-FromBigEndian -Bytes (Read-NbtBytes -Reader $Reader -Count 8)), 0)
}

function Read-NbtString {
    param([System.IO.BinaryReader]$Reader)

    $length = Read-NbtInt16 -Reader $Reader
    if ($length -lt 0) {
        throw 'Invalid NBT string length.'
    }

    $bytes = Read-NbtBytes -Reader $Reader -Count $length
    [Text.Encoding]::UTF8.GetString($bytes)
}

function Read-NbtPayload {
    param(
        [System.IO.BinaryReader]$Reader,
        [int]$Type
    )

    switch ($Type) {
        1 { return [byte]$Reader.ReadByte() }
        2 { return Read-NbtInt16 -Reader $Reader }
        3 { return Read-NbtInt32 -Reader $Reader }
        4 { return Read-NbtInt64 -Reader $Reader }
        5 { return Read-NbtFloat -Reader $Reader }
        6 { return Read-NbtDouble -Reader $Reader }
        7 {
            $length = Read-NbtInt32 -Reader $Reader
            if ($length -lt 0) { throw 'Invalid NBT byte array length.' }
            return Read-NbtBytes -Reader $Reader -Count $length
        }
        8 { return Read-NbtString -Reader $Reader }
        9 {
            $elemType = [byte]$Reader.ReadByte()
            $length = Read-NbtInt32 -Reader $Reader
            if ($length -lt 0) { throw 'Invalid NBT list length.' }
            $items = @()
            for ($i = 0; $i -lt $length; $i++) {
                $items += New-NbtTag -Type $elemType -Value (Read-NbtPayload -Reader $Reader -Type $elemType)
            }
            return [pscustomobject]@{
                ElemType = $elemType
                Items = @($items)
            }
        }
        10 {
            $children = @()
            while ($true) {
                $childType = [byte]$Reader.ReadByte()
                if ($childType -eq 0) {
                    break
                }

                $childName = Read-NbtString -Reader $Reader
                $children += New-NbtTag -Type $childType -Name $childName -Value (Read-NbtPayload -Reader $Reader -Type $childType)
            }
            return @($children)
        }
        11 {
            $length = Read-NbtInt32 -Reader $Reader
            if ($length -lt 0) { throw 'Invalid NBT int array length.' }
            $items = @()
            for ($i = 0; $i -lt $length; $i++) {
                $items += Read-NbtInt32 -Reader $Reader
            }
            return @($items)
        }
        12 {
            $length = Read-NbtInt32 -Reader $Reader
            if ($length -lt 0) { throw 'Invalid NBT long array length.' }
            $items = @()
            for ($i = 0; $i -lt $length; $i++) {
                $items += Read-NbtInt64 -Reader $Reader
            }
            return @($items)
        }
        default { throw "Unsupported NBT tag type: $Type" }
    }
}

function Read-NbtFile {
    param([string]$Path)

    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        if ($stream.Length -ge 2) {
            $first = $stream.ReadByte()
            $second = $stream.ReadByte()
            $stream.Position = 0
            if ($first -eq 0x1f -and $second -eq 0x8b) {
                throw 'Compressed NBT servers.dat is not supported by this installer.'
            }
        }

        $reader = [System.IO.BinaryReader]::new($stream)
        $rootType = [byte]$reader.ReadByte()
        if ($rootType -ne 10) {
            throw "Expected NBT compound root, got tag type $rootType."
        }

        New-NbtTag -Type $rootType -Name (Read-NbtString -Reader $reader) -Value (Read-NbtPayload -Reader $reader -Type $rootType)
    }
    finally {
        $stream.Close()
    }
}

function Write-NbtBytes {
    param(
        [System.IO.BinaryWriter]$Writer,
        [byte[]]$Bytes
    )

    $Writer.Write($Bytes)
}

function Write-NbtInt16 {
    param(
        [System.IO.BinaryWriter]$Writer,
        [int]$Value
    )

    $bytes = [BitConverter]::GetBytes([int16]$Value)
    Write-NbtBytes -Writer $Writer -Bytes (Convert-FromBigEndian -Bytes $bytes)
}

function Write-NbtInt32 {
    param(
        [System.IO.BinaryWriter]$Writer,
        [int]$Value
    )

    $bytes = [BitConverter]::GetBytes([int32]$Value)
    Write-NbtBytes -Writer $Writer -Bytes (Convert-FromBigEndian -Bytes $bytes)
}

function Write-NbtInt64 {
    param(
        [System.IO.BinaryWriter]$Writer,
        [long]$Value
    )

    $bytes = [BitConverter]::GetBytes([int64]$Value)
    Write-NbtBytes -Writer $Writer -Bytes (Convert-FromBigEndian -Bytes $bytes)
}

function Write-NbtFloat {
    param(
        [System.IO.BinaryWriter]$Writer,
        [single]$Value
    )

    $bytes = [BitConverter]::GetBytes([single]$Value)
    Write-NbtBytes -Writer $Writer -Bytes (Convert-FromBigEndian -Bytes $bytes)
}

function Write-NbtDouble {
    param(
        [System.IO.BinaryWriter]$Writer,
        [double]$Value
    )

    $bytes = [BitConverter]::GetBytes([double]$Value)
    Write-NbtBytes -Writer $Writer -Bytes (Convert-FromBigEndian -Bytes $bytes)
}

function Write-NbtString {
    param(
        [System.IO.BinaryWriter]$Writer,
        [string]$Value
    )

    $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
    Write-NbtInt16 -Writer $Writer -Value $bytes.Length
    Write-NbtBytes -Writer $Writer -Bytes $bytes
}

function Write-NbtPayload {
    param(
        [System.IO.BinaryWriter]$Writer,
        [int]$Type,
        [object]$Value
    )

    switch ($Type) {
        1 { $Writer.Write([byte]$Value) }
        2 { Write-NbtInt16 -Writer $Writer -Value $Value }
        3 { Write-NbtInt32 -Writer $Writer -Value $Value }
        4 { Write-NbtInt64 -Writer $Writer -Value $Value }
        5 { Write-NbtFloat -Writer $Writer -Value $Value }
        6 { Write-NbtDouble -Writer $Writer -Value $Value }
        7 {
            $bytes = [byte[]]$Value
            Write-NbtInt32 -Writer $Writer -Value $bytes.Length
            Write-NbtBytes -Writer $Writer -Bytes $bytes
        }
        8 { Write-NbtString -Writer $Writer -Value ([string]$Value) }
        9 {
            $elemType = [byte]$Value.ElemType
            $items = @($Value.Items)
            $Writer.Write($elemType)
            Write-NbtInt32 -Writer $Writer -Value $items.Count
            foreach ($item in $items) {
                Write-NbtPayload -Writer $Writer -Type $elemType -Value $item.Value
            }
        }
        10 {
            foreach ($child in @($Value)) {
                $Writer.Write([byte]$child.Type)
                Write-NbtString -Writer $Writer -Value ([string]$child.Name)
                Write-NbtPayload -Writer $Writer -Type ([int]$child.Type) -Value $child.Value
            }
            $Writer.Write([byte]0)
        }
        11 {
            $items = @($Value)
            Write-NbtInt32 -Writer $Writer -Value $items.Count
            foreach ($item in $items) {
                Write-NbtInt32 -Writer $Writer -Value $item
            }
        }
        12 {
            $items = @($Value)
            Write-NbtInt32 -Writer $Writer -Value $items.Count
            foreach ($item in $items) {
                Write-NbtInt64 -Writer $Writer -Value $item
            }
        }
        default { throw "Unsupported NBT tag type: $Type" }
    }
}

function Write-NbtFile {
    param(
        [string]$Path,
        [object]$Root
    )

    $tempPath = "$Path.tmp"
    $stream = [System.IO.File]::Open($tempPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    try {
        $writer = [System.IO.BinaryWriter]::new($stream)
        $writer.Write([byte]$Root.Type)
        Write-NbtString -Writer $writer -Value ([string]$Root.Name)
        Write-NbtPayload -Writer $writer -Type ([int]$Root.Type) -Value $Root.Value
    }
    finally {
        $stream.Close()
    }

    Move-Item -LiteralPath $tempPath -Destination $Path -Force
}

function New-MinecraftServerEntry {
    param(
        [string]$Name,
        [string]$Address
    )

    New-NbtTag -Type 10 -Value @(
        (New-NbtTag -Type 8 -Name 'name' -Value $Name),
        (New-NbtTag -Type 8 -Name 'ip' -Value $Address)
    )
}

function Find-NbtChild {
    param(
        [object[]]$Children,
        [string]$Name,
        [int]$Type
    )

    @($Children) | Where-Object { $_.Name -eq $Name -and [int]$_.Type -eq $Type } | Select-Object -First 1
}

function Ensure-MultiplayerServerEntry {
    param([string]$MinecraftDir)

    if ([string]::IsNullOrWhiteSpace($ServerEntryAddress)) {
        return 'Skipped because ServerEntryAddress is blank.'
    }

    $serversPath = Join-Path $MinecraftDir 'servers.dat'
    $root = $null
    if (Test-Path -LiteralPath $serversPath) {
        try {
            $root = Read-NbtFile -Path $serversPath
        }
        catch {
            $backupPath = "$serversPath.broken-$(Get-Date -Format yyyyMMddHHmmss)"
            Move-Item -LiteralPath $serversPath -Destination $backupPath -Force
            Write-Host "Backed up unreadable servers.dat to $backupPath"
        }
    }

    if ($null -eq $root) {
        $root = New-NbtTag -Type 10 -Name '' -Value @()
    }

    $serversTag = Find-NbtChild -Children $root.Value -Name 'servers' -Type 9
    if ($null -eq $serversTag) {
        $serversTag = New-NbtTag -Type 9 -Name 'servers' -Value ([pscustomobject]@{
            ElemType = [byte]10
            Items = @()
        })
        $root.Value = @($root.Value) + $serversTag
    }
    elseif ([int]$serversTag.Value.ElemType -ne 10) {
        throw 'servers.dat contains a servers list with an unexpected element type.'
    }

    foreach ($server in @($serversTag.Value.Items)) {
        $ipTag = Find-NbtChild -Children $server.Value -Name 'ip' -Type 8
        if ($null -ne $ipTag -and [string]$ipTag.Value -eq $ServerEntryAddress) {
            return "Server entry already present: $ServerEntryAddress"
        }
    }

    $serversTag.Value.Items = @((New-MinecraftServerEntry -Name $ServerEntryName -Address $ServerEntryAddress)) + @($serversTag.Value.Items)
    Write-NbtFile -Path $serversPath -Root $root
    "Added multiplayer server entry: $ServerEntryName ($ServerEntryAddress)"
}

function Copy-ManifestSection {
    param(
        [object]$Manifest,
        [string]$Section,
        [string]$Destination
    )

    Ensure-Directory -Path $Destination

    foreach ($item in $Manifest.$Section) {
        $source = Resolve-AssetSource -Item $item
        $target = Join-Path $Destination $item.name
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
}

function Get-ManifestSectionFolderName {
    param([string]$Section)

    switch ($Section) {
        'client' { 'Client'; break }
        'config' { 'Config'; break }
        'root' { 'Root'; break }
        'shaderpacks' { 'Shaderpacks'; break }
        'server' { 'Server'; break }
        default { $Section; break }
    }
}

function Get-ManifestItemRelativePath {
    param(
        [object]$Item,
        [string]$Section
    )

    if (-not [string]::IsNullOrWhiteSpace([string]$Item.relativePath)) {
        return ([string]$Item.relativePath).Replace('/', [IO.Path]::DirectorySeparatorChar)
    }

    $path = ([string]$Item.path).Replace('\', '/')
    $folderName = Get-ManifestSectionFolderName -Section $Section
    $prefix = "$folderName/"
    if ($path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        return $path.Substring($prefix.Length).Replace('/', [IO.Path]::DirectorySeparatorChar)
    }

    return [string]$Item.name
}

function Copy-ManifestSectionTree {
    param(
        [object]$Manifest,
        [string]$Section,
        [string]$Destination
    )

    Ensure-Directory -Path $Destination

    foreach ($item in $Manifest.$Section) {
        $source = Resolve-AssetSource -Item $item
        $relative = Get-ManifestItemRelativePath -Item $item -Section $Section
        $target = Join-Path $Destination $relative
        $targetParent = Split-Path -Parent $target
        if (-not [string]::IsNullOrWhiteSpace($targetParent)) {
            Ensure-Directory -Path $targetParent
        }
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
}

function Format-LimitedList {
    param(
        [object[]]$Items,
        [int]$Limit = 40
    )

    $values = @($Items | Select-Object -First $Limit | ForEach-Object { [string]$_ })
    if ($Items.Count -gt $Limit) {
        $values += "+$($Items.Count - $Limit) more"
    }

    $values -join ', '
}

function Assert-InstalledManifestSection {
    param(
        [object]$Manifest,
        [string]$Section,
        [string]$Destination,
        [switch]$NoExtraJars
    )

    $items = @($Manifest.$Section)
    if ($items.Count -eq 0) {
        throw "Manifest section '$Section' has no files."
    }

    if (-not (Test-Path -LiteralPath $Destination)) {
        throw "Installed $Section folder is missing: $Destination"
    }

    $expectedNames = @{}
    $missing = New-Object System.Collections.Generic.List[string]
    $mismatched = New-Object System.Collections.Generic.List[string]

    foreach ($item in $items) {
        $name = [string]$item.name
        $expectedNames[$name.ToLowerInvariant()] = $true
        $target = Join-Path $Destination $name

        if (-not (Test-Path -LiteralPath $target)) {
            $missing.Add($name) | Out-Null
            continue
        }

        $actual = Get-FileHashSha256 -Path $target
        $expected = ([string]$item.sha256).ToLowerInvariant()
        if ($actual -ne $expected) {
            $mismatched.Add("$name expected $expected got $actual") | Out-Null
        }
    }

    $extraJars = @()
    if ($NoExtraJars) {
        $actualJars = @(Get-ChildItem -LiteralPath $Destination -Filter '*.jar' -File -ErrorAction SilentlyContinue)
        $extraJars = @($actualJars | Where-Object { -not $expectedNames.ContainsKey($_.Name.ToLowerInvariant()) } | Sort-Object Name)
    }

    if (($missing.Count -gt 0) -or ($mismatched.Count -gt 0) -or ($extraJars.Count -gt 0)) {
        $details = New-Object System.Collections.Generic.List[string]
        if ($missing.Count -gt 0) {
            $details.Add("missing ($($missing.Count)): $(Format-LimitedList -Items @($missing.ToArray()))") | Out-Null
        }
        if ($mismatched.Count -gt 0) {
            $details.Add("hash mismatch ($($mismatched.Count)): $(Format-LimitedList -Items @($mismatched.ToArray()))") | Out-Null
        }
        if ($extraJars.Count -gt 0) {
            $extraJarNames = @($extraJars | Select-Object -ExpandProperty Name)
            $details.Add("extra jars not in manifest ($($extraJars.Count)): $(Format-LimitedList -Items $extraJarNames)") | Out-Null
        }

        throw "Installed $Section files do not match the pack manifest in ${Destination}. $($details -join ' ')"
    }

    "$Section verified: $($items.Count) file(s)"
}

function Assert-ForgeLauncherProfileReady {
    param([string]$MinecraftDir)

    $versionJson = Join-Path $MinecraftDir "versions\$ForgeProfile\$ForgeProfile.json"
    if (-not (Test-Path -LiteralPath $versionJson)) {
        throw "Forge $ForgeProfile is not installed. Re-run this installer without -SkipForgeInstall."
    }

    $profilePaths = @(
        (Join-Path $MinecraftDir 'launcher_profiles.json'),
        (Join-Path $MinecraftDir 'launcher_profiles_microsoft_store.json')
    )
    $existingProfilePaths = @($profilePaths | Where-Object { Test-Path -LiteralPath $_ })
    if ($existingProfilePaths.Count -eq 0) {
        throw "No Minecraft launcher profile file was found in $MinecraftDir."
    }

    $checked = New-Object System.Collections.Generic.List[string]
    $errors = New-Object System.Collections.Generic.List[string]

    foreach ($profilesPath in $existingProfilePaths) {
        $leaf = Split-Path -Leaf $profilesPath
        try {
            $profilesData = Get-Content -LiteralPath $profilesPath -Raw | ConvertFrom-Json
        }
        catch {
            $errors.Add("${leaf}: could not parse launcher profiles JSON: $($_.Exception.Message)") | Out-Null
            continue
        }

        if ($null -eq $profilesData.profiles) {
            $errors.Add("${leaf}: missing profiles object") | Out-Null
            continue
        }

        $matchingProfileIds = New-Object System.Collections.Generic.List[string]
        foreach ($profileProperty in $profilesData.profiles.PSObject.Properties) {
            $profile = $profileProperty.Value
            if (($profile.name -eq $LauncherProfileName) -and ($profile.lastVersionId -eq $ForgeProfile)) {
                $matchingProfileIds.Add($profileProperty.Name) | Out-Null
            }
        }

        if ($matchingProfileIds.Count -eq 0) {
            $errors.Add("${leaf}: missing $LauncherProfileName profile for $ForgeProfile") | Out-Null
            continue
        }

        $selectedProfile = [string]$profilesData.selectedProfile
        if ([string]::IsNullOrWhiteSpace($selectedProfile)) {
            $errors.Add("${leaf}: selectedProfile is not set to $LauncherProfileName") | Out-Null
            continue
        }

        if (-not $matchingProfileIds.Contains($selectedProfile)) {
            $errors.Add("${leaf}: selectedProfile is '$selectedProfile', expected one of $($matchingProfileIds -join ', ')") | Out-Null
            continue
        }

        $checked.Add("${leaf}: selected $selectedProfile") | Out-Null
    }

    if ($errors.Count -gt 0) {
        throw "Forge launcher profile is not ready. $($errors -join ' ')"
    }

    "Forge profile ready: $($checked -join '; ')"
}

function Assert-ClientLaunchGate {
    param(
        [object]$Manifest,
        [string]$MinecraftDir
    )

    $details = New-Object System.Collections.Generic.List[string]
    $details.Add((Assert-ForgeLauncherProfileReady -MinecraftDir $MinecraftDir)) | Out-Null
    $details.Add((Assert-InstalledManifestSection -Manifest $Manifest -Section 'client' -Destination (Join-Path $MinecraftDir 'mods') -NoExtraJars)) | Out-Null

    $details -join '; '
}

function Install-ForgeClient {
    param([string]$MinecraftDir)

    Ensure-LauncherProfiles -MinecraftDir $MinecraftDir

    $versionJson = Join-Path $MinecraftDir "versions\$ForgeProfile\$ForgeProfile.json"
    if ((Test-Path -LiteralPath $versionJson) -and -not $Force) {
        Write-Host "Forge profile already exists: $ForgeProfile"
        return
    }

    $java = Find-Java
    if ($null -eq $java) {
        throw "Java was not found. Open Minecraft Launcher and run any Minecraft version once so the launcher installs its Java runtime, then rerun this installer."
    }
    Write-Host "Using Java: $java"

    $cacheDir = Join-Path $PackRoot '_InstallCache'
    Ensure-Directory -Path $cacheDir
    $installerPath = Join-Path $cacheDir $ForgeInstallerName

    if (-not (Test-Path -LiteralPath $installerPath)) {
        Write-Host "Downloading Forge installer..."
        Invoke-DownloadFile -Uri $ForgeInstallerUrl -OutFile $installerPath -Label $ForgeInstallerName
    }

    Write-Host "Running Forge installer..."
    Push-Location $cacheDir
    try {
        & $java -jar $installerPath --installClient $MinecraftDir
        if ($LASTEXITCODE -ne 0) {
            throw "Forge installer exited with code $LASTEXITCODE. Open Minecraft Launcher once, make sure you are logged in, close it, and rerun this installer."
        }
    }
    finally {
        Pop-Location
    }

    if (-not (Test-Path -LiteralPath $versionJson)) {
        throw "Forge installer finished but did not create $versionJson."
    }
}

function Install-ClientPack {
    param([object]$Manifest)

    $minecraftDir = Join-Path $env:APPDATA '.minecraft'
    Ensure-Directory -Path $minecraftDir

    Write-Step "Closing Minecraft Launcher"
    $closedProcessesDetails = Stop-RunningMinecraftProcesses
    Add-InstallStatus -Name 'Close running Minecraft' -Passed $true -Details $closedProcessesDetails

    Write-Step "Verifying bundled client files"
    $sections = @('client', 'config', 'root')
    if (-not $NoShader) {
        $sections += 'shaderpacks'
    }
    Assert-BundledFiles -Manifest $Manifest -Sections $sections
    Add-InstallStatus -Name 'Verify client assets' -Passed $true -Details "Verified sections: $($sections -join ', ')"

    if (-not $SkipForgeInstall) {
        Write-Step "Installing Forge $MinecraftVersion-$ForgeVersion"
        Install-ForgeClient -MinecraftDir $minecraftDir
        Add-InstallStatus -Name 'Install Forge client' -Passed $true -Details $ForgeProfile
    }
    else {
        Add-InstallStatus -Name 'Install Forge client' -Passed $true -Details 'Skipped by -SkipForgeInstall.'
    }

    Write-Step "Configuring launcher memory"
    $profileMemoryResult = Set-ForgeLauncherProfileMemory -MinecraftDir $minecraftDir
    $versionMemoryDetails = Set-ForgeVersionJvmMemory -MinecraftDir $minecraftDir
    $safetyWarningDetails = Set-LauncherSafetyWarningAccepted -MinecraftDir $minecraftDir -ProfileIds @($profileMemoryResult.ProfileIds)
    Add-InstallStatus -Name 'Configure launcher memory' -Passed $true -Details "$($profileMemoryResult.Details) $versionMemoryDetails $safetyWarningDetails"

    Write-Step "Backing up previous mods and configs"
    $backupRoot = Backup-And-ClearClientState -MinecraftDir $minecraftDir
    Write-Host "Backup folder: $backupRoot"

    Write-Step "Copying client mods"
    Copy-ManifestSection -Manifest $Manifest -Section 'client' -Destination (Join-Path $minecraftDir 'mods')
    Add-InstallStatus -Name 'Copy client mods' -Passed $true -Details "$(@($Manifest.client).Count) files copied."

    Write-Step "Copying config"
    Copy-ManifestSectionTree -Manifest $Manifest -Section 'config' -Destination (Join-Path $minecraftDir 'config')
    Add-InstallStatus -Name 'Copy config' -Passed $true -Details "$(@($Manifest.config).Count) files copied."

    Write-Step "Copying root overrides"
    Copy-ManifestSectionTree -Manifest $Manifest -Section 'root' -Destination $minecraftDir
    Add-InstallStatus -Name 'Copy root overrides' -Passed $true -Details "$(@($Manifest.root).Count) files copied."

    if (-not $NoShader) {
        Write-Step "Copying shaderpacks"
        Copy-ManifestSection -Manifest $Manifest -Section 'shaderpacks' -Destination (Join-Path $minecraftDir 'shaderpacks')
        Add-InstallStatus -Name 'Copy shaderpacks' -Passed $true -Details "$(@($Manifest.shaderpacks).Count) files copied."
    }
    else {
        Add-InstallStatus -Name 'Copy shaderpacks' -Passed $true -Details 'Skipped by -NoShader.'
    }

    if (-not $SkipServerEntry) {
        Write-Step "Adding multiplayer server"
        $serverEntryDetails = Ensure-MultiplayerServerEntry -MinecraftDir $minecraftDir
        Add-InstallStatus -Name 'Add multiplayer server' -Passed $true -Details $serverEntryDetails
    }
    else {
        Add-InstallStatus -Name 'Add multiplayer server' -Passed $true -Details 'Skipped by -SkipServerEntry.'
    }

    Write-Step "Verifying Forge profile and installed mod hashes"
    $launchGateDetails = Assert-ClientLaunchGate -Manifest $Manifest -MinecraftDir $minecraftDir
    Add-InstallStatus -Name 'Verify Forge profile and mod hashes' -Passed $true -Details $launchGateDetails

    Write-Step "Checking connection prerequisites"
    Add-ClientConnectionPrereqReport -MinecraftDir $minecraftDir

    Write-Host ""
    Write-Host "Client install complete. Launch the $LauncherProfileName profile: $ForgeProfile" -ForegroundColor Green
}

function Test-ClientPackInstall {
    param([object]$Manifest)

    $minecraftDir = Join-Path $env:APPDATA '.minecraft'

    Write-Step "Verifying installed client pack"
    $launchGateDetails = Assert-ClientLaunchGate -Manifest $Manifest -MinecraftDir $minecraftDir
    Add-InstallStatus -Name 'Verify installed client pack' -Passed $true -Details $launchGateDetails

    Write-Host ""
    Write-Host "Client pack verification passed. Launch the $LauncherProfileName profile: $ForgeProfile" -ForegroundColor Green
}

function Install-ServerPack {
    param([object]$Manifest)

    if ([string]::IsNullOrWhiteSpace($ServerPath)) {
        throw "Server mode needs -ServerPath pointing at your Forge server folder."
    }

    $resolvedServerPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ServerPath)
    Ensure-Directory -Path $resolvedServerPath

    Write-Step "Backing up previous server pack files"
    $serverBackupRoot = Backup-And-ClearServerState -ServerPath $resolvedServerPath
    Write-Host "Server backup folder: $serverBackupRoot"

    Write-Step "Verifying bundled server files"
    Assert-BundledFiles -Manifest $Manifest -Sections @('server')
    Add-InstallStatus -Name 'Verify server assets' -Passed $true -Details 'Verified section: server'

    Write-Step "Copying server files"
    Copy-ManifestSectionTree -Manifest $Manifest -Section 'server' -Destination $resolvedServerPath
    Add-InstallStatus -Name 'Copy server files' -Passed $true -Details "$(@($Manifest.server).Count) files copied."

    Write-Host ""
    Write-Host "Server files copied to: $resolvedServerPath" -ForegroundColor Green
}

try {
    Write-Host "Crazy Craft Updated $MinecraftVersion Forge Installer"
    Write-Host "Pack folder: $PackRoot"

    $manifest = Read-Manifest
    $script:PackManifest = $manifest
    Add-InstallStatus -Name 'Read manifest' -Passed $true -Details $ManifestPath

    if ([string]::IsNullOrWhiteSpace($AssetBaseUrl) -and -not [string]::IsNullOrWhiteSpace($manifest.assetBaseUrl)) {
        $AssetBaseUrl = $manifest.assetBaseUrl.TrimEnd('/')
    }

    if ($VerifyOnly -and $Server) {
        throw "-VerifyOnly is only for client installs."
    }

    if ($VerifyOnly) {
        Test-ClientPackInstall -Manifest $manifest
    }
    elseif ($Server) {
        Install-ServerPack -Manifest $manifest
    }
    else {
        Install-ClientPack -Manifest $manifest
    }

    Add-InstallStatus -Name 'Installer completed' -Passed $true
}
catch {
    $script:InstallFailed = $true
    Add-InstallStatus -Name 'Installer completed' -Passed $false -Details $_.Exception.Message
    Write-Host ""
    Write-Host "Installer failed: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    Write-InstallReport
}

if ($script:InstallFailed) {
    exit 1
}
