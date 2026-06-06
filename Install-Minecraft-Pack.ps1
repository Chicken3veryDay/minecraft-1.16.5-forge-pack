[CmdletBinding()]
param(
    [switch]$Client,
    [switch]$Server,
    [string]$ClientPath,
    [string]$ServerPath,
    [switch]$VerifyOnly,
    [switch]$DownloadOnly,
    [switch]$Force,
    [switch]$Diagnose,
    [switch]$MenuFpsSafeMode,
    [switch]$RestoreMenuFpsMods,
    [int]$MenuFpsBatch = 0,
    [switch]$NoPrompt,
    [switch]$SkipSelfUpdate
)

$ErrorActionPreference = 'Stop'

$PackRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRawBase = 'https://raw.githubusercontent.com/Chicken3veryDay/minecraft-1.16.5-forge-pack/main'

function Get-ForwardArgs([switch]$IncludeSkipSelfUpdate) {
    $forward = @()
    if ($Client) { $forward += '-Client' }
    if ($Server) { $forward += '-Server' }
    if ($VerifyOnly) { $forward += '-VerifyOnly' }
    if ($DownloadOnly) { $forward += '-DownloadOnly' }
    if ($Force) { $forward += '-Force' }
    if ($Diagnose) { $forward += '-Diagnose' }
    if ($MenuFpsSafeMode) { $forward += '-MenuFpsSafeMode' }
    if ($RestoreMenuFpsMods) { $forward += '-RestoreMenuFpsMods' }
    if ($MenuFpsBatch -gt 0) {
        $forward += '-MenuFpsBatch'
        $forward += $MenuFpsBatch
    }
    if ($NoPrompt) { $forward += '-NoPrompt' }
    if ($IncludeSkipSelfUpdate) { $forward += '-SkipSelfUpdate' }
    if (-not [string]::IsNullOrWhiteSpace($ClientPath)) {
        $forward += '-ClientPath'
        $forward += $ClientPath
    }
    if (-not [string]::IsNullOrWhiteSpace($ServerPath)) {
        $forward += '-ServerPath'
        $forward += $ServerPath
    }
    $forward
}

function Test-InteractiveHost {
    try {
        if (-not [Environment]::UserInteractive) { return $false }
        if ([Console]::IsInputRedirected) { return $false }
        if ($Host.Name -eq 'ServerRemoteHost') { return $false }
        return $true
    } catch {
        return $false
    }
}

function Select-InstallMode {
    Write-Host ''
    Write-Host 'Crazy Craft 4.0 Official installer' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '1. Client install (recommended)'
    Write-Host '   Downloads/stages the Crazy Craft client payload when required, installs Forge 1.7.10, pins Java 8, and creates the launcher profile.'
    Write-Host '2. Server staging'
    Write-Host '   Downloads/stages the official CrazyCraft4Server.zip into a server folder. This does not update your client launcher profile.'
    Write-Host '3. Verify/diagnose existing client install'
    Write-Host '   No large pack download. Prints profile/runtime/log/mod diagnostics for the current client folder.'
    Write-Host ''
    while ($true) {
        $choice = Read-Host 'Choose 1, 2, or 3 [1]'
        if ([string]::IsNullOrWhiteSpace($choice)) { $choice = '1' }
        switch ($choice.Trim()) {
            '1' { $script:Client = $true; return }
            '2' {
                $script:Server = $true
                if ([string]::IsNullOrWhiteSpace($script:ServerPath)) {
                    $defaultServerPath = Join-Path $script:PackRoot 'crazy-craft-4.0-server'
                    $entered = Read-Host "Server staging folder [$defaultServerPath]"
                    if ([string]::IsNullOrWhiteSpace($entered)) {
                        $script:ServerPath = $defaultServerPath
                    } else {
                        $script:ServerPath = $entered
                    }
                }
                return
            }
            '3' { $script:Diagnose = $true; return }
            default { Write-Host 'Please enter 1, 2, or 3.' -ForegroundColor Yellow }
        }
    }
}

function Invoke-SelfUpdate {
    $files = @(
        'Install-Minecraft-Pack.ps1',
        'tools/Install-CrazyCraft4.ps1',
        'pack-sources/CrazyCraft4/mods.required.txt'
    )
    $updated = $false
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('mc-pack-update-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    try {
        foreach ($relative in $files) {
            $cacheBuster = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            $url = "$RepoRawBase/$relative`?v=$cacheBuster"
            $local = Join-Path $PackRoot ($relative.Replace('/', [IO.Path]::DirectorySeparatorChar))
            $temp = Join-Path $tempRoot ($relative.Replace('/', [IO.Path]::DirectorySeparatorChar))
            New-Item -ItemType Directory -Path (Split-Path -Parent $temp) -Force | Out-Null
            Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $temp

            $isDifferent = $true
            if (Test-Path -LiteralPath $local) {
                $oldHash = [System.BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash([IO.File]::ReadAllBytes($local)))
                $newHash = [System.BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash([IO.File]::ReadAllBytes($temp)))
                $isDifferent = $oldHash -ne $newHash
            }
            if ($isDifferent) {
                New-Item -ItemType Directory -Path (Split-Path -Parent $local) -Force | Out-Null
                Copy-Item -LiteralPath $temp -Destination $local -Force
                $updated = $true
                Write-Host "Updated $relative" -ForegroundColor Cyan
            }
        }
    }
    catch {
        Write-Warning "Auto-update skipped: $($_.Exception.Message)"
        return $false
    }
    finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    $updated
}

if (-not $SkipSelfUpdate) {
    Write-Host 'Checking for installer updates...'
    if (Invoke-SelfUpdate) {
        Write-Host 'Installer updated. Relaunching updated installer...' -ForegroundColor Green
        $relaunchArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $MyInvocation.MyCommand.Path) + (Get-ForwardArgs -IncludeSkipSelfUpdate)
        & powershell.exe @relaunchArgs
        exit $LASTEXITCODE
    }
}

if ($Client -and $Server) {
    throw 'Choose either -Client or -Server, not both.'
}

$hasExplicitMode = $Client -or $Server -or $VerifyOnly -or $DownloadOnly -or $Diagnose -or $MenuFpsSafeMode -or $RestoreMenuFpsMods
if (-not $hasExplicitMode -and -not $NoPrompt) {
    if (Test-InteractiveHost) {
        Select-InstallMode
    } else {
        $Client = $true
    }
}

$script = Join-Path $PackRoot 'tools\Install-CrazyCraft4.ps1'
$argsList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script)
if ($Client) { $argsList += '-Client' }
if ($Server) { $argsList += '-Server' }
if ($VerifyOnly) { $argsList += '-VerifyOnly' }
if ($DownloadOnly) { $argsList += '-DownloadOnly' }
if ($Force) { $argsList += '-Force' }
if ($Diagnose) { $argsList += '-Diagnose' }
if ($MenuFpsSafeMode) { $argsList += '-MenuFpsSafeMode' }
if ($RestoreMenuFpsMods) { $argsList += '-RestoreMenuFpsMods' }
if ($MenuFpsBatch -gt 0) {
    $argsList += '-MenuFpsBatch'
    $argsList += $MenuFpsBatch
}
if ($NoPrompt) { $argsList += '-NoPrompt' }
if (-not [string]::IsNullOrWhiteSpace($ClientPath)) {
    $argsList += '-ClientPath'
    $argsList += $ClientPath
}
if (-not [string]::IsNullOrWhiteSpace($ServerPath)) {
    $argsList += '-ServerPath'
    $argsList += $ServerPath
}

& powershell.exe @argsList
exit $LASTEXITCODE
