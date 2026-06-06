[CmdletBinding()]
param(
    [switch]$Server,
    [string]$ClientPath,
    [string]$ServerPath,
    [switch]$VerifyOnly,
    [switch]$DownloadOnly,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$script = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'tools\Install-CrazyCraft4.ps1'
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
