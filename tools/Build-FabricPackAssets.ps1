[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
)

$ErrorActionPreference = 'Stop'
Write-Warning "Build-FabricPackAssets.ps1 is deprecated. Redirecting to Build-ForgePackAssets.ps1."
& (Join-Path $PSScriptRoot 'Build-ForgePackAssets.ps1') @RemainingArgs
