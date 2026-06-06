[CmdletBinding()]
param(
    [switch]$Client,
    [switch]$Server,
    [string]$ClientPath,
    [string]$ServerPath,
    [switch]$VerifyOnly,
    [switch]$DownloadOnly,
    [switch]$SkipShaders,
    [string]$ShaderPackUrl,
    [string]$ShaderPackName,
    [switch]$Force,
    [switch]$Diagnose,
    [switch]$RepairLauncherAuth,
    [switch]$MenuFpsSafeMode,
    [switch]$RestoreMenuFpsMods,
    [int]$MenuFpsBatch = 0,
    [switch]$NoPrompt,
    [switch]$SkipSelfUpdate
)

$ErrorActionPreference = 'Stop'

$PackRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRawBase = 'https://raw.githubusercontent.com/Chicken3veryDay/minecraft-1.16.5-forge-pack/main'

function Write-Rule([string]$Title = '', [string]$Color = 'DarkCyan') {
    $line = '=' * 72
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
        'RUN' { $label = '[RUN] '; $color = 'Magenta' }
        default { $label = '[INFO]'; $color = 'Cyan' }
    }
    Write-Host $label -NoNewline -ForegroundColor $color
    Write-Host " $Message"
}

function Get-ForwardArgs([switch]$IncludeSkipSelfUpdate) {
    $forward = @()
    if ($Client) { $forward += '-Client' }
    if ($Server) { $forward += '-Server' }
    if ($VerifyOnly) { $forward += '-VerifyOnly' }
    if ($DownloadOnly) { $forward += '-DownloadOnly' }
    if ($SkipShaders) { $forward += '-SkipShaders' }
    if (-not [string]::IsNullOrWhiteSpace($ShaderPackUrl)) {
        $forward += '-ShaderPackUrl'
        $forward += $ShaderPackUrl
    }
    if (-not [string]::IsNullOrWhiteSpace($ShaderPackName)) {
        $forward += '-ShaderPackName'
        $forward += $ShaderPackName
    }
    if ($Force) { $forward += '-Force' }
    if ($Diagnose) { $forward += '-Diagnose' }
    if ($RepairLauncherAuth) { $forward += '-RepairLauncherAuth' }
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
    Write-Rule -Title 'Crazy Craft 4.0 Official installer'
    Write-StatusLine -Kind 'OK' -Message '1. Client install (recommended)'
    Write-Host '      Downloads/stages the client payload when required, installs Forge 1.7.10, pins Java 8, and creates the launcher profile.'
    Write-StatusLine -Kind 'INFO' -Message '2. Server staging'
    Write-Host '      Downloads/stages the official CrazyCraft4Server.zip into a server folder. This does not update the client launcher profile.'
    Write-StatusLine -Kind 'INFO' -Message '3. Verify/diagnose existing client install'
    Write-Host '      No large pack download. Prints profile/runtime/log/mod diagnostics for the current client folder.'
    Write-StatusLine -Kind 'INFO' -Message '4. Repair Launcher auth / Eroded Badlands'
    Write-Host '      Repairs official Minecraft Launcher, Microsoft Store, Xbox, Gaming Services, and Windows auth components where possible.'
    Write-Host ''
    while ($true) {
        $choice = Read-Host 'Choose 1, 2, 3, or 4 [1]'
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
            '4' { $script:RepairLauncherAuth = $true; return }
            default { Write-StatusLine -Kind 'WARN' -Message 'Please enter 1, 2, 3, or 4.' }
        }
    }
}

function Invoke-SelfUpdate {
    $files = @(
        'Install-Minecraft-Pack.ps1',
        'Install-Minecraft-Pack.bat',
        'tools/Install-CrazyCraft4.ps1',
        'tools/Repair-MinecraftLauncherAuth.ps1',
        'tools/Enable-CrazyCraftShaders.ps1',
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
                Write-StatusLine -Kind 'OK' -Message "Updated $relative"
            }
        }
    }
    catch {
        Write-StatusLine -Kind 'WARN' -Message "Auto-update skipped: $($_.Exception.Message)"
        return $false
    }
    finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    $updated
}

function Ensure-RepairLauncherAuthScript {
    $relative = 'tools/Repair-MinecraftLauncherAuth.ps1'
    $local = Join-Path $PackRoot ($relative.Replace('/', [IO.Path]::DirectorySeparatorChar))
    if (Test-Path -LiteralPath $local) { return $local }

    Write-StatusLine -Kind 'INFO' -Message 'Downloading launcher auth repair tool...'
    $cacheBuster = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $url = "$RepoRawBase/$relative`?v=$cacheBuster"
    New-Item -ItemType Directory -Path (Split-Path -Parent $local) -Force | Out-Null
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $local
    Write-StatusLine -Kind 'OK' -Message 'Launcher auth repair tool downloaded.'
    return $local
}

if (-not $SkipSelfUpdate) {
    Write-Rule -Title 'Self update'
    Write-StatusLine -Kind 'INFO' -Message 'Checking for installer updates...'
    if (Invoke-SelfUpdate) {
        Write-StatusLine -Kind 'OK' -Message 'Installer updated. Relaunching updated installer...'
        $relaunchArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $MyInvocation.MyCommand.Path) + (Get-ForwardArgs -IncludeSkipSelfUpdate)
        & powershell.exe @relaunchArgs
        exit $LASTEXITCODE
    }
}

if ($Client -and $Server) {
    throw 'Choose either -Client or -Server, not both.'
}

$hasExplicitMode = $Client -or $Server -or $VerifyOnly -or $DownloadOnly -or $Diagnose -or $RepairLauncherAuth -or $MenuFpsSafeMode -or $RestoreMenuFpsMods
if (-not $hasExplicitMode -and -not $NoPrompt) {
    if (Test-InteractiveHost) {
        Select-InstallMode
    } else {
        $Client = $true
    }
}

$script = Join-Path $PackRoot 'tools\Install-CrazyCraft4.ps1'
if ($RepairLauncherAuth) {
    $repairScript = Ensure-RepairLauncherAuthScript
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $repairScript
    exit $LASTEXITCODE
}

$argsList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script)
if ($Client) { $argsList += '-Client' }
if ($Server) { $argsList += '-Server' }
if ($VerifyOnly) { $argsList += '-VerifyOnly' }
if ($DownloadOnly) { $argsList += '-DownloadOnly' }
if ($Force) { $argsList += '-Force' }
if ($Diagnose) { $argsList += '-Diagnose' }
if ($RepairLauncherAuth) { $argsList += '-RepairLauncherAuth' }
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
$mainExitCode = $LASTEXITCODE

if ($mainExitCode -eq 0 -and $Client) {
    $shaderScript = Join-Path $PackRoot 'tools\Enable-CrazyCraftShaders.ps1'
    if (Test-Path -LiteralPath $shaderScript) {
        $shaderArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $shaderScript, '-Client')
        if ($SkipShaders) { $shaderArgs += '-SkipShaders' }
        if (-not [string]::IsNullOrWhiteSpace($ClientPath)) {
            $shaderArgs += '-ClientPath'
            $shaderArgs += $ClientPath
        }
        if (-not [string]::IsNullOrWhiteSpace($ShaderPackUrl)) {
            $shaderArgs += '-ShaderPackUrl'
            $shaderArgs += $ShaderPackUrl
        }
        if (-not [string]::IsNullOrWhiteSpace($ShaderPackName)) {
            $shaderArgs += '-ShaderPackName'
            $shaderArgs += $ShaderPackName
        }
        & powershell.exe @shaderArgs
        $shaderExitCode = $LASTEXITCODE
        if ($shaderExitCode -ne 0) {
            Write-StatusLine -Kind 'WARN' -Message "Shader helper exited with code $shaderExitCode. The core installer already succeeded."
        }
    } else {
        Write-StatusLine -Kind 'WARN' -Message "Shader helper not found at $shaderScript. Run self-update or download tools/Enable-CrazyCraftShaders.ps1."
    }
}

exit $mainExitCode
