[CmdletBinding()]
param(
    [switch]$Client,
    [switch]$Server,
    [string]$ClientPath = (Join-Path $env:APPDATA '.minecraft\crazy-craft-4.0-official'),
    [switch]$SkipShaders,
    [string]$ShaderPackUrl,
    [string]$ShaderPackName
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$DefaultOptiFineName = 'OptiFine_1.7.10_HD_U_E7.jar'
$OptiFineMirrorPage = 'https://optifine.net/adloadx?f=OptiFine_1.7.10_HD_U_E7.jar'
$DefaultShaderName = "Sildur's Vibrant Shaders v1.283 Lite.zip"
$DefaultShaderPage = 'https://www.mediafire.com/file/qctxcwq5vvdv867/Sildur%2527s_Vibrant_Shaders_v1.283_Lite.zip/file'
$CacheRoot = Join-Path (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)) '_InstallCache\crazy-craft-4.0\shaders'

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

function Ensure-Directory([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Invoke-TextRequest([string]$Url) {
    $request = [System.Net.HttpWebRequest]::Create($Url)
    $request.UserAgent = 'Mozilla/5.0 CrazyCraft4PortableInstaller'
    $request.AllowAutoRedirect = $true
    $response = $request.GetResponse()
    try {
        $stream = $response.GetResponseStream()
        $reader = [System.IO.StreamReader]::new($stream)
        try { return $reader.ReadToEnd() }
        finally {
            $reader.Dispose()
            $stream.Dispose()
        }
    } finally {
        $response.Dispose()
    }
}

function Resolve-OptiFineDownloadUrl {
    $html = Invoke-TextRequest -Url $OptiFineMirrorPage
    $pattern = 'href=["''](?<href>downloadx\?f=OptiFine_1\.7\.10_HD_U_E7\.jar[^"'']+)["'']'
    $match = [regex]::Match($html, $pattern)
    if (-not $match.Success) {
        throw "Could not resolve OptiFine mirror link. Manual fallback: download OptiFine 1.7.10 HD U E7 from https://optifine.net/downloads and place it in $ClientPath\mods."
    }
    $href = [System.Net.WebUtility]::HtmlDecode($match.Groups['href'].Value)
    return ([Uri]::new([Uri]'https://optifine.net/', $href)).AbsoluteUri
}

function Resolve-MediaFireDirectDownloadUrl([string]$PageUrl) {
    $html = Invoke-TextRequest -Url $PageUrl
    $patterns = @(
        'href=["''](?<href>https?://download[^"'']+?\.zip[^"'']*)["'']',
        '"(?<href>https?://download[^"'']+?\.zip[^"'']*)"'
    )
    foreach ($pattern in $patterns) {
        $match = [regex]::Match($html, $pattern)
        if ($match.Success) {
            return [System.Net.WebUtility]::HtmlDecode($match.Groups['href'].Value)
        }
    }
    throw "Could not resolve a direct MediaFire zip link from $PageUrl."
}

function Get-SafeShaderFileName([string]$Url, [string]$FallbackName) {
    if (-not [string]::IsNullOrWhiteSpace($ShaderPackName)) { return $ShaderPackName }
    try {
        $uri = [Uri]$Url
        $leaf = [System.Net.WebUtility]::UrlDecode((Split-Path -Leaf $uri.AbsolutePath))
        if (-not [string]::IsNullOrWhiteSpace($leaf) -and $leaf.ToLowerInvariant().EndsWith('.zip')) { return $leaf }
    } catch { }
    return $FallbackName
}

function Invoke-CachedDownload([string]$Url, [string]$DestinationPath, [string]$Activity) {
    if (Test-Path -LiteralPath $DestinationPath) {
        Write-StatusLine -Kind 'OK' -Message "$Activity already cached."
        return
    }
    Ensure-Directory -Path (Split-Path -Parent $DestinationPath)
    Write-StatusLine -Kind 'RUN' -Message $Activity
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $DestinationPath -Headers @{ 'User-Agent' = 'Mozilla/5.0 CrazyCraft4PortableInstaller' }
}

function Ensure-OptiFineClientMod {
    $modsRoot = Join-Path $ClientPath 'mods'
    Ensure-Directory -Path $modsRoot
    $target = Join-Path $modsRoot $DefaultOptiFineName
    if (Test-Path -LiteralPath $target) {
        Write-StatusLine -Kind 'OK' -Message "OptiFine already present: $DefaultOptiFineName"
        return
    }

    try {
        $url = Resolve-OptiFineDownloadUrl
        $cachePath = Join-Path $CacheRoot $DefaultOptiFineName
        Invoke-CachedDownload -Url $url -DestinationPath $cachePath -Activity 'Downloading OptiFine 1.7.10 HD U E7'
        Copy-Item -LiteralPath $cachePath -Destination $target -Force
        Write-StatusLine -Kind 'OK' -Message "Installed OptiFine client-side only: $DefaultOptiFineName"
    } catch {
        Write-StatusLine -Kind 'WARN' -Message "OptiFine auto-install skipped: $($_.Exception.Message)"
    }
}

function Ensure-ShaderPack {
    $shaderpacksRoot = Join-Path $ClientPath 'shaderpacks'
    Ensure-Directory -Path $shaderpacksRoot

    $pageOrDirectUrl = $ShaderPackUrl
    if ([string]::IsNullOrWhiteSpace($pageOrDirectUrl)) { $pageOrDirectUrl = $DefaultShaderPage }

    try {
        $downloadUrl = $pageOrDirectUrl
        if ($pageOrDirectUrl -match '^https?://(www\.)?mediafire\.com/') {
            $downloadUrl = Resolve-MediaFireDirectDownloadUrl -PageUrl $pageOrDirectUrl
        }
        $shaderName = Get-SafeShaderFileName -Url $downloadUrl -FallbackName $DefaultShaderName
        $cachePath = Join-Path $CacheRoot $shaderName
        $target = Join-Path $shaderpacksRoot $shaderName
        Invoke-CachedDownload -Url $downloadUrl -DestinationPath $cachePath -Activity "Downloading shader pack $shaderName"
        Copy-Item -LiteralPath $cachePath -Destination $target -Force
        Write-StatusLine -Kind 'OK' -Message "Installed shader pack: $shaderName"
        return $shaderName
    } catch {
        Write-StatusLine -Kind 'WARN' -Message "Shader auto-install skipped: $($_.Exception.Message)"
        Write-StatusLine -Kind 'INFO' -Message "Manual fallback: put a shader .zip in $shaderpacksRoot, then select it in Options > Video Settings > Shaders."
        return $null
    }
}

function Write-ShaderOptions([string]$SelectedShaderPackName) {
    if ([string]::IsNullOrWhiteSpace($SelectedShaderPackName)) { return }
    $optionsPath = Join-Path $ClientPath 'optionsshaders.txt'
    $lines = @(
        "shaderPack=$SelectedShaderPackName",
        'antialiasingLevel=0',
        'normalMapEnabled=false',
        'specularMapEnabled=false',
        'renderResMul=1.0',
        'shadowResMul=0.5',
        'oldLighting=false'
    )
    Set-Content -LiteralPath $optionsPath -Value $lines -Encoding ASCII
    Write-StatusLine -Kind 'OK' -Message "Auto-selected shader in optionsshaders.txt: $SelectedShaderPackName"
}

if ($SkipShaders) {
    Write-StatusLine -Kind 'INFO' -Message 'Shader setup skipped by -SkipShaders.'
    exit 0
}

if ($Server -and -not $Client) {
    Write-StatusLine -Kind 'INFO' -Message 'Server install detected; shaders are client-side only, so shader setup is skipped.'
    exit 0
}

Write-StatusLine -Kind 'INFO' -Message "Client shader target: $ClientPath"
Ensure-Directory -Path $ClientPath
Ensure-OptiFineClientMod
$selectedShader = Ensure-ShaderPack
Write-ShaderOptions -SelectedShaderPackName $selectedShader
exit 0
