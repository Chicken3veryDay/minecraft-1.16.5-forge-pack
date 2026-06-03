[CmdletBinding()]
param(
    [string] $HostName = '100.86.27.44',
    [string] $User = 'brandon',
    [int] $Port = 22,
    [string] $IdentityFile = (Join-Path $HOME '.ssh\brandon_admin_ed25519'),
    [string] $PackZip,
    [string] $RemoteRoot = 'C:\Users\Brandon\Downloads\codex-minecraft-pack',
    [string] $ServerAddress = '192.3.179.150:25565',
    [switch] $SkipUpload,
    [switch] $SkipInstall,
    [switch] $NoForce
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($PackZip)) {
    $scriptPath = $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($scriptPath)) {
        $scriptPath = $MyInvocation.MyCommand.Path
    }
    $repoRoot = Split-Path -Parent (Split-Path -Parent $scriptPath)
    $PackZip = Join-Path $repoRoot 'minimal-pack.zip'
}

function ConvertTo-EncodedRemoteCommand {
    param([string] $Script)
    [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Script))
}

function Invoke-RemotePowerShell {
    param([string] $Script)

    $wrappedScript = "`$ProgressPreference = 'SilentlyContinue'`n$Script"
    $encoded = ConvertTo-EncodedRemoteCommand -Script $wrappedScript
    & ssh @script:SshArgs $script:RemoteTarget "powershell -NoProfile -NonInteractive -OutputFormat Text -ExecutionPolicy Bypass -EncodedCommand $encoded"
    if ($LASTEXITCODE -ne 0) {
        throw "Remote PowerShell command failed with exit code $LASTEXITCODE."
    }
}

function ConvertTo-RemoteScpPath {
    param([string] $Path)
    $Path -replace '\\', '/'
}

function Split-ServerAddress {
    param([string] $Address)

    if ($Address -match '^(?<host>.+):(?<port>\d+)$') {
        return [pscustomobject]@{
            Host = $Matches.host
            Port = [int]$Matches.port
        }
    }

    [pscustomobject]@{
        Host = $Address
        Port = 25565
    }
}

if (-not (Test-Path -LiteralPath $IdentityFile)) {
    throw "Missing SSH identity file: $IdentityFile"
}

if (-not $SkipUpload -and -not (Test-Path -LiteralPath $PackZip)) {
    throw "Missing pack zip: $PackZip"
}

$script:RemoteTarget = "${User}@${HostName}"
$script:SshArgs = @(
    '-i', $IdentityFile,
    '-p', "$Port",
    '-o', 'BatchMode=yes',
    '-o', 'StrictHostKeyChecking=accept-new'
)

Write-Host "== Checking SSH access =="
Invoke-RemotePowerShell -Script @'
Write-Output "remote-user: $(whoami)"
Write-Output "remote-computer: $env:COMPUTERNAME"
'@

if (-not $SkipUpload) {
    Write-Host ""
    Write-Host "== Uploading current minimal pack =="
    Invoke-RemotePowerShell -Script @"
New-Item -ItemType Directory -Path '$RemoteRoot' -Force | Out-Null
"@

    $remoteZipPath = (ConvertTo-RemoteScpPath -Path (Join-Path $RemoteRoot 'minimal-pack.zip'))
    & scp -i $IdentityFile -P $Port -o BatchMode=yes -o StrictHostKeyChecking=accept-new $PackZip "${RemoteTarget}:$remoteZipPath"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP upload failed with exit code $LASTEXITCODE."
    }
}

if (-not $SkipInstall) {
    Write-Host ""
    Write-Host "== Running remote installer =="
    $forceFlag = if ($NoForce) { '' } else { '-Force' }
    Invoke-RemotePowerShell -Script @"
`$ErrorActionPreference = 'Stop'
`$remoteRoot = '$RemoteRoot'
`$zipPath = Join-Path `$remoteRoot 'minimal-pack.zip'
if (-not (Test-Path -LiteralPath `$zipPath)) {
    throw "Missing remote pack zip: `$zipPath"
}
Expand-Archive -LiteralPath `$zipPath -DestinationPath `$remoteRoot -Force
`$installer = Join-Path `$remoteRoot 'Install-Minecraft-Pack.ps1'
if (-not (Test-Path -LiteralPath `$installer)) {
    throw "Missing remote installer: `$installer"
}
& powershell -NoProfile -ExecutionPolicy Bypass -File `$installer $forceFlag -ServerEntryAddress '$ServerAddress' -ConnectionCheckTimeoutSeconds 10
if (`$LASTEXITCODE -ne 0) {
    throw "Installer exited with code `$LASTEXITCODE"
}
"@
}

Write-Host ""
Write-Host "== Remote client connection state =="
$endpoint = Split-ServerAddress -Address $ServerAddress
Invoke-RemotePowerShell -Script @"
`$minecraftDir = Join-Path `$env:APPDATA '.minecraft'
Write-Output "minecraft-dir: `$minecraftDir"
if (Test-Path -LiteralPath (Join-Path `$minecraftDir 'mods')) {
    `$mods = Get-ChildItem -LiteralPath (Join-Path `$minecraftDir 'mods') -Filter '*.jar' -File
    Write-Output "mods-count: `$(`$mods.Count)"
    `$required = @(
        'AI-Improvements-1.16.5-0.5.0.jar',
        'chunksending-1.16.5-2.5.jar',
        'connectivity-2.3-1.16.5.jar',
        'mowziesmobs-1.5.27.jar',
        'spark-1.9.1-forge.jar'
    )
    foreach (`$name in `$required) {
        `$path = Join-Path (Join-Path `$minecraftDir 'mods') `$name
        Write-Output "required-mod:$name present=`$(Test-Path -LiteralPath `$path)"
    }
}
`$accountFiles = @(
    (Join-Path `$minecraftDir 'launcher_accounts_microsoft_store.json'),
    (Join-Path `$minecraftDir 'launcher_accounts.json')
)
`$hasAccount = `$false
foreach (`$accountFile in `$accountFiles) {
    if (-not (Test-Path -LiteralPath `$accountFile)) { continue }
    try {
        `$data = Get-Content -LiteralPath `$accountFile -Raw | ConvertFrom-Json
        if (`$null -ne `$data.accounts -and @(`$data.accounts.PSObject.Properties).Count -gt 0) {
            `$hasAccount = `$true
            Write-Output "launcher-account: present in `$(Split-Path -Leaf `$accountFile)"
        }
    }
    catch {
        Write-Output "launcher-account-read-error: `$(Split-Path -Leaf `$accountFile): `$(`$_.Exception.Message)"
    }
}
if (-not `$hasAccount) {
    Write-Output "launcher-account: missing active account; sign in through Minecraft Launcher before joining."
}
`$tcp = Test-NetConnection -ComputerName '$($endpoint.Host)' -Port $($endpoint.Port)
Write-Output "server-tcp: `$(`$tcp.TcpTestSucceeded) $ServerAddress"
"@
