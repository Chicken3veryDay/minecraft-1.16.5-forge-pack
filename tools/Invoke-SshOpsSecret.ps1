param(
    [Parameter(Mandatory = $true)]
    [string] $HostName,

    [string] $User = "root",

    [int] $Port = 22,

    [Parameter(Mandatory = $true)]
    [ValidateSet("exec", "put", "get")]
    [string] $Action,

    [string] $Command,

    [string] $CommandFile,

    [string[]] $Pairs = @()
)

$ErrorActionPreference = "Stop"

if ($Action -eq "exec") {
    if ([string]::IsNullOrWhiteSpace($Command) -and [string]::IsNullOrWhiteSpace($CommandFile)) {
        throw "Either -Command or -CommandFile is required for exec."
    }
    if (-not [string]::IsNullOrWhiteSpace($Command) -and -not [string]::IsNullOrWhiteSpace($CommandFile)) {
        throw "Use only one of -Command or -CommandFile for exec."
    }
} elseif ($Pairs.Count -eq 0 -or ($Pairs.Count % 2) -ne 0) {
    throw "$Action requires source/destination pairs."
}

$secure = Read-Host -AsSecureString "SSH password"
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)

try {
    $env:CODEX_SSH_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)

    $argsList = @(
        "tools\ssh_ops.py",
        $HostName,
        "-u",
        $User,
        "-p",
        [string] $Port,
        "--password-env",
        "CODEX_SSH_PASSWORD",
        $Action
    )

    if ($Action -eq "exec") {
        if (-not [string]::IsNullOrWhiteSpace($CommandFile)) {
            $argsList += "--command-file"
            $argsList += $CommandFile
        } else {
            $argsList += $Command
        }
    } else {
        $argsList += $Pairs
    }

    python @argsList
    exit $LASTEXITCODE
} finally {
    if ($bstr -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
    Remove-Item Env:CODEX_SSH_PASSWORD -ErrorAction SilentlyContinue
}
