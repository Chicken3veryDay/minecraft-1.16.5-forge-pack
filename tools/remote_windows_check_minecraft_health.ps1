param(
    [int] $Port = 25565,
    [string[]] $SearchRoots = @(
        "$env:USERPROFILE",
        "C:\",
        "D:\"
    )
)

$ErrorActionPreference = "Continue"

Write-Host "== os =="
Get-CimInstance Win32_OperatingSystem |
    Select-Object Caption, Version, LastBootUpTime |
    Format-List

Write-Host "== user =="
whoami
whoami /groups

Write-Host "== java processes =="
Get-CimInstance Win32_Process |
    Where-Object { $_.Name -in @("java.exe", "javaw.exe") } |
    Select-Object ProcessId, Name, CommandLine |
    Format-List

Write-Host "== tcp listeners port $Port =="
Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
    Format-List

Write-Host "== firewall rules for port $Port =="
Get-NetFirewallPortFilter -ErrorAction SilentlyContinue |
    Where-Object { $_.Protocol -eq "TCP" -and $_.LocalPort -eq "$Port" } |
    ForEach-Object {
        $rule = $_ | Get-NetFirewallRule -ErrorAction SilentlyContinue
        [pscustomobject]@{
            RuleName = $rule.Name
            DisplayName = $rule.DisplayName
            Enabled = $rule.Enabled
            Direction = $rule.Direction
            Action = $rule.Action
            Profile = $rule.Profile
        }
    } |
    Format-Table -AutoSize

Write-Host "== likely services =="
Get-Service |
    Where-Object {
        $_.Name -match "minecraft|forge|java|mc" -or
        $_.DisplayName -match "minecraft|forge|java|mc"
    } |
    Select-Object Name, DisplayName, Status, StartType |
    Format-Table -AutoSize

Write-Host "== likely server directories =="
$directoryPatterns = "minecraft|forge|server|mc"
foreach ($root in $SearchRoots) {
    if (-not (Test-Path -LiteralPath $root)) {
        continue
    }

    Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match $directoryPatterns } |
        Select-Object FullName, LastWriteTime |
        Format-Table -AutoSize
}

Write-Host "== recent server logs =="
foreach ($root in $SearchRoots) {
    if (-not (Test-Path -LiteralPath $root)) {
        continue
    }

    Get-ChildItem -LiteralPath $root -Recurse -Filter latest.log -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match "\\logs\\latest\.log$|/logs/latest\.log$" } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 10 FullName, LastWriteTime, Length |
        Format-Table -AutoSize
}
