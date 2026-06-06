[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$BlueprintPath = Join-Path $Root 'pack-sources\pack-blueprint.json'
$OutputPath = Join-Path $Root 'MODLIST.md'

if (-not (Test-Path -LiteralPath $BlueprintPath)) {
    throw "Missing blueprint: $BlueprintPath"
}

$blueprint = Get-Content -LiteralPath $BlueprintPath -Raw | ConvertFrom-Json
$lines = @()

$lines += '# Forge 1.20.1 ProjectE Chaos Pack'
$lines += ''
$lines += ('Generated inventory date: `{0}`' -f (Get-Date -Format yyyy-MM-dd))
$lines += ''
$lines += '## Pack Identity'
$lines += ''
$lines += ('- Project: ' + $blueprint.packName)
$lines += ('- Loader default: `' + $blueprint.platform + '`')
$lines += ('- Minecraft version: `' + $blueprint.minecraft + '`')
$lines += ('- Forge version: `' + $blueprint.forgeVersion + '`')
$lines += ('- Audience: ' + $blueprint.audience)
$lines += ('- World policy: ' + $blueprint.worldPolicy)
$lines += ('- Required identity: `' + $blueprint.requiredIdentity + '`')
$lines += ('- Content strategy: ' + $blueprint.contentStrategy)
$lines += ('- Disallowed pack pillars: `' + ($blueprint.disallowedPackPillars -join '`, `') + '`')
$lines += ('- Host target: dedicated Linux + NVMe + `' + $blueprint.hostProfile.hostRam + '` RAM + `' + $blueprint.hostProfile.cpu + '`')
$lines += ''
$lines += '## Resolver Workflow'
$lines += ''
$lines += ('- Resolver: ' + $blueprint.sourceWorkflow.resolver)
$lines += ('- Why not packwiz here: ' + $blueprint.sourceWorkflow.reason)
$lines += ''
$lines += '## Required Baseline Mods'
$lines += ''
$lines += '| Mod / Tool | Side | Status | Purpose |'
$lines += '|---|---|---|---|'
foreach ($item in @($blueprint.optimizationBaseline)) {
    $lines += ('| `' + $item.name + '` | ' + $item.side + ' | ' + $item.status + ' | ' + $item.purpose + ' |')
}
$lines += ''
$lines += '## Installed Mods'
$lines += ''
$lines += '| Name | Category | Installed sides | File | Role |'
$lines += '|---|---|---|---|---|'
foreach ($item in @($blueprint.resolvedMods | Sort-Object category, name)) {
    $lines += ('| `' + $item.name + '` | ' + $item.category + ' | ' + ($item.installedSides -join ', ') + ' | `' + $item.fileName + '` | ' + $item.role + ' |')
}
$lines += ''
$lines += '## Forge Server Bootstrap'
$lines += ''
if ($null -ne $blueprint.serverBootstrap -and $null -ne $blueprint.serverBootstrap.forgeInstaller) {
    $installer = $blueprint.serverBootstrap.forgeInstaller
    $lines += ('- Bundled installer: `' + $installer.fileName + '`')
    $lines += ('- Source: ' + $installer.source)
    $lines += ('- URL: ' + $installer.url)
}
else {
    $lines += '- Forge installer not yet resolved.'
}
$lines += ''
$lines += '## Notes'
$lines += ''
$lines += '- Shared mods are copied into both client and server deliverables.'
$lines += '- Client-only mods stay out of the dedicated server staging path.'
$lines += '- No large automation pillars such as Create, Mekanism, Applied Energistics, or Refined Storage are seeded in this pack.'

$lines | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host ('Updated ' + $OutputPath)
