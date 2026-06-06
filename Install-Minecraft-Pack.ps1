[CmdletBinding()]
param(
    [switch]$Server,
    [string]$ClientPath,
    [string]$ServerPath,
    [switch]$VerifyOnly,
    [switch]$DownloadOnly,
    [switch]$Force,
    [switch]$SkipSelfUpdate
)

$ErrorActionPreference = 'Stop'

$PackRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRawBase = 'https://raw.githubusercontent.com/Chicken3veryDay/minecraft-1.16.5-forge-pack/main'

function Get-ForwardArgs([switch]$IncludeSkipSelfUpdate) {
    $forward = @()
    if ($Server) { $forward += '-Server' }
    if ($VerifyOnly) { $forward += '-VerifyOnly' }
    if ($DownloadOnly) { $forward += '-DownloadOnly' }
    if ($Force) { $forward += '-Force' }
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

$script = Join-Path $PackRoot 'tools\Install-CrazyCraft4.ps1'
$argsList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script)
if ($Server) { $argsList += '-Server' }
if ($VerifyOnly) { $argsList += '-VerifyOnly' }
if ($DownloadOnly) { $argsList += '-DownloadOnly' }
if ($Force) { $argsList += '-Force' }
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
