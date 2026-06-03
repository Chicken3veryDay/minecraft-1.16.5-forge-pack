[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$combinedFix = Join-Path $PSScriptRoot 'Apply-PackFixes.ps1'
& $combinedFix
