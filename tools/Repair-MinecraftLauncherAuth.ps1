[CmdletBinding()]
param(
    [switch]$DiagnoseOnly,
    [switch]$SkipSystemRepair
)

$ErrorActionPreference = 'Stop'
$script:CompletionItems = @()
$script:WarningItems = @()
$script:FailureSummary = $null

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

function Add-Completion([string]$Message) {
    if (-not [string]::IsNullOrWhiteSpace($Message)) {
        $script:CompletionItems += $Message
    }
}

function Add-RepairWarning([string]$Message) {
    if (-not [string]::IsNullOrWhiteSpace($Message)) {
        $script:WarningItems += $Message
    }
}

function Write-RepairSummary {
    Write-Rule -Title 'Launcher auth repair summary'
    if ($script:CompletionItems.Count -eq 0) {
        Write-StatusLine -Kind 'INFO' -Message 'No repair actions completed.'
    } else {
        foreach ($item in $script:CompletionItems) {
            Write-StatusLine -Kind 'OK' -Message $item
        }
    }
    foreach ($item in $script:WarningItems) {
        Write-StatusLine -Kind 'WARN' -Message $item
    }
    if (-not [string]::IsNullOrWhiteSpace($script:FailureSummary)) {
        Write-StatusLine -Kind 'FAIL' -Message $script:FailureSummary
    }
    Write-Host ''
}

function Test-IsAdministrator {
    $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-SafeAction([string]$Name, [scriptblock]$Action) {
    try {
        & $Action
        Add-Completion $Name
        Write-StatusLine -Kind 'OK' -Message $Name
        return $true
    } catch {
        $message = "$Name failed: $($_.Exception.Message)"
        Add-RepairWarning $message
        Write-StatusLine -Kind 'WARN' -Message $message
        return $false
    }
}

function Get-ActivationStatusText {
    try {
        $licensed = @(Get-CimInstance -ClassName SoftwareLicensingProduct -ErrorAction Stop | Where-Object {
            $_.PartialProductKey -and $_.LicenseStatus -eq 1 -and $_.Name -match 'Windows'
        })
        if ($licensed.Count -gt 0) { return 'Licensed' }
        return 'Not licensed or not detected'
    } catch {
        return "Could not query activation: $($_.Exception.Message)"
    }
}

function Get-PackageStatus([string[]]$Names) {
    foreach ($name in $Names) {
        $pkg = @(Get-AppxPackage -Name $name -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($pkg.Count -gt 0) {
            return [pscustomobject]@{ Found = $true; Name = $pkg[0].Name; Version = $pkg[0].Version; InstallLocation = $pkg[0].InstallLocation }
        }
    }
    return [pscustomobject]@{ Found = $false; Name = ($Names -join ' or '); Version = ''; InstallLocation = '' }
}

function Repair-AppxPackageByName([string[]]$Names, [string]$DisplayName) {
    $packages = @()
    foreach ($name in $Names) {
        $packages += @(Get-AppxPackage -Name $name -ErrorAction SilentlyContinue)
    }
    $packages = @($packages | Sort-Object PackageFullName -Unique)
    if ($packages.Count -eq 0) {
        throw "$DisplayName package was not found."
    }

    foreach ($pkg in $packages) {
        $manifest = Join-Path $pkg.InstallLocation 'AppxManifest.xml'
        if (-not (Test-Path -LiteralPath $manifest)) {
            throw "$DisplayName manifest missing: $manifest"
        }
        Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ErrorAction Stop
    }
}

function Start-RepairService([string]$Name) {
    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $service) {
        throw "Service not found: $Name"
    }
    if ($service.Status -ne 'Running') {
        Start-Service -Name $Name -ErrorAction Stop
    }
}

function Find-ErodedBadlandsMentions {
    $roots = @(
        (Join-Path $env:APPDATA '.minecraft'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.4297127D64EC6_8wekyb3d8bbwe\LocalCache\Local\game'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.4297127D64EC6_8wekyb3d8bbwe\LocalCache\Roaming\.minecraft')
    )
    $mentions = @()
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $logs = @(Get-ChildItem -LiteralPath $root -File -Filter '*.log' -ErrorAction SilentlyContinue)
        $logs += @(Get-ChildItem -LiteralPath $root -File -Filter 'launcher_log*.txt' -ErrorAction SilentlyContinue)
        foreach ($log in @($logs | Sort-Object LastWriteTime -Descending | Select-Object -First 20)) {
            try {
                $lines = if ($log.Length -gt 10MB) {
                    @(Get-Content -LiteralPath $log.FullName -Tail 4000 -ErrorAction SilentlyContinue)
                } else {
                    @(Get-Content -LiteralPath $log.FullName -ErrorAction SilentlyContinue)
                }
                for ($i = 0; $i -lt $lines.Count; $i++) {
                    if ($lines[$i] -match 'Eroded Badlands|0x80004005|Windows Product Activation|\bWPA\b|WPA requires') {
                        $mentions += [pscustomobject]@{ Path = $log.FullName; Line = $lines[$i].Trim() }
                    }
                    if ($mentions.Count -ge 12) { return $mentions }
                }
            } catch {
            }
        }
    }
    return $mentions
}

function Run-ExternalRepair([string]$Name, [string]$FilePath, [string[]]$Arguments) {
    Write-StatusLine -Kind 'INFO' -Message $Name
    $process = Start-Process -FilePath $FilePath -ArgumentList $Arguments -Wait -PassThru -WindowStyle Hidden
    if ($process.ExitCode -eq 0) {
        Add-Completion "$Name completed."
        Write-StatusLine -Kind 'OK' -Message "$Name completed."
    } else {
        Add-RepairWarning "$Name exited with code $($process.ExitCode)."
        Write-StatusLine -Kind 'WARN' -Message "$Name exited with code $($process.ExitCode)."
    }
}

Write-Rule -Title 'Minecraft Launcher auth repair'
Write-StatusLine -Kind 'INFO' -Message 'This repairs the official Launcher/Microsoft Store/Xbox/Gaming Services path.'
Write-StatusLine -Kind 'WARN' -Message 'It does not bypass Microsoft account ownership or Launcher authentication.'
Write-KeyValue -Name 'Running as admin' -Value (Test-IsAdministrator)
$activationStatus = Get-ActivationStatusText
Write-KeyValue -Name 'Windows activation' -Value $activationStatus
if ($activationStatus -ne 'Licensed') {
    Add-RepairWarning "Windows activation is not healthy: $activationStatus"
}

Write-Rule -Title 'Detected packages' -Color 'DarkGray'
$packageChecks = @(
    @{ Label = 'Minecraft Launcher'; Names = @('Microsoft.4297127D64EC6') },
    @{ Label = 'Gaming Services'; Names = @('Microsoft.GamingServices') },
    @{ Label = 'Xbox app'; Names = @('Microsoft.GamingApp') },
    @{ Label = 'Xbox Identity Provider'; Names = @('Microsoft.XboxIdentityProvider') },
    @{ Label = 'Microsoft Store'; Names = @('Microsoft.WindowsStore') }
)
foreach ($check in $packageChecks) {
    $status = Get-PackageStatus -Names ([string[]]$check.Names)
    if ($status.Found) {
        Write-KeyValue -Name $check.Label -Value "$($status.Name) $($status.Version)"
    } else {
        Write-KeyValue -Name $check.Label -Value 'missing'
        Add-RepairWarning "$($check.Label) package is missing."
    }
}

$mentions = @(Find-ErodedBadlandsMentions)
Write-Rule -Title 'Detected launcher errors' -Color 'DarkGray'
if ($mentions.Count -eq 0) {
    Write-StatusLine -Kind 'INFO' -Message 'No Eroded Badlands/WPA mentions found in detected launcher logs.'
} else {
    foreach ($mention in $mentions) {
        Write-KeyValue -Name $mention.Path -Value $mention.Line
    }
    Add-Completion 'Detected Eroded Badlands/WPA evidence in launcher logs.'
}

if ($DiagnoseOnly) {
    Add-Completion 'Diagnose-only mode completed; no repairs were run.'
    Write-RepairSummary
    exit 0
}

Write-Rule -Title 'Repair actions'
foreach ($service in @('ClipSVC', 'LicenseManager', 'InstallService', 'GamingServices', 'GamingServicesNet', 'XblAuthManager', 'XblGameSave', 'XboxGipSvc')) {
    Invoke-SafeAction -Name "Start service $service" -Action { Start-RepairService -Name $service } | Out-Null
}

foreach ($check in $packageChecks) {
    Invoke-SafeAction -Name "Re-register $($check.Label)" -Action {
        Repair-AppxPackageByName -Names ([string[]]$check.Names) -DisplayName ([string]$check.Label)
    } | Out-Null
}

Invoke-SafeAction -Name 'Reset Microsoft Store cache with wsreset' -Action {
    $wsreset = Join-Path $env:WINDIR 'System32\wsreset.exe'
    if (-not (Test-Path -LiteralPath $wsreset)) { throw 'wsreset.exe was not found.' }
    $process = Start-Process -FilePath $wsreset -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "wsreset exited with code $($process.ExitCode)." }
} | Out-Null

if ((Test-IsAdministrator) -and -not $SkipSystemRepair) {
    Write-Rule -Title 'Windows component repair' -Color 'DarkGray'
    Run-ExternalRepair -Name 'DISM RestoreHealth' -FilePath (Join-Path $env:WINDIR 'System32\dism.exe') -Arguments @('/Online', '/Cleanup-Image', '/RestoreHealth')
    Run-ExternalRepair -Name 'SFC scan' -FilePath (Join-Path $env:WINDIR 'System32\sfc.exe') -Arguments @('/scannow')
} elseif (-not $SkipSystemRepair) {
    Add-RepairWarning 'Windows WPA/component repair needs admin. Right-click Install-Minecraft-Pack.bat and choose Run as administrator if Eroded Badlands persists.'
    Write-StatusLine -Kind 'WARN' -Message 'Windows WPA/component repair needs admin for DISM/SFC.'
}

Write-Rule -Title 'Next steps' -Color 'DarkGray'
Write-StatusLine -Kind 'INFO' -Message 'Restart the PC after these repairs.'
Write-StatusLine -Kind 'INFO' -Message 'Open Microsoft Store, Xbox app, and Minecraft Launcher with the same Microsoft account.'
Write-StatusLine -Kind 'INFO' -Message 'If the Xbox app asks to repair Gaming Services, let it.'
Write-StatusLine -Kind 'RUN' -Message 'https://support.xbox.com/en-US/help/games-apps/troubleshooting/gaming-services-repair-tool'

Write-RepairSummary
