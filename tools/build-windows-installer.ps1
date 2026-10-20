[CmdletBinding()]
param(
    # the folder tools/build-windows.ps1 installed into, with bin\swiftify.exe
    [Parameter(Mandatory)]
    [string]$Source,
    [string]$Out = 'dist',
    [string]$Makensis,
    [string]$Icon
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

function Find-Makensis {
    param([string]$Requested)

    if ($Requested) {
        if (-not (Test-Path -LiteralPath $Requested -PathType Leaf)) {
            throw "No makensis at $Requested."
        }
        return (Resolve-Path -LiteralPath $Requested).Path
    }
    foreach ($candidate in @(
        "${env:ProgramFiles(x86)}\NSIS\makensis.exe",
        "$env:ProgramFiles\NSIS\makensis.exe"
    )) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }
    $command = Get-Command 'makensis.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) {
        return $command.Source
    }
    throw 'Cannot find makensis. Install NSIS (choco install nsis) and add it to PATH, or pass -Makensis.'
}

$Source = (Resolve-Path -LiteralPath $Source).Path
$executable = Join-Path $Source 'bin\swiftify.exe'
if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
    throw "$Source has no bin\swiftify.exe. Pass the folder tools/build-windows.ps1 installed into."
}

$repository = Split-Path -Parent $PSScriptRoot
if (-not $Icon) {
    $Icon = Join-Path $repository 'packaging\icons\swiftify.ico'
}
if (-not (Test-Path -LiteralPath $Icon -PathType Leaf)) {
    throw "No installer icon at $Icon."
}
$Icon = (Resolve-Path -LiteralPath $Icon).Path

$cmake = Get-Content -LiteralPath (Join-Path $repository 'CMakeLists.txt') -Raw
$version = [regex]::Match($cmake, '(?m)^\s*VERSION\s+([0-9]+\.[0-9]+\.[0-9]+)').Groups[1].Value
if (-not $version) {
    throw 'Could not read the version from CMakeLists.txt.'
}

$outDirectory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)
New-Item -ItemType Directory -Path $outDirectory -Force | Out-Null
$output = Join-Path $outDirectory "swiftify-$version-windows-x86_64-setup.exe"
Remove-Item -LiteralPath $output -ErrorAction SilentlyContinue

$makensis = Find-Makensis $Makensis
$script = Join-Path $repository 'packaging\windows\installer.nsi'
Write-Host "makensis: $makensis"
Write-Host "source:   $Source"
Write-Host "output:   $output"

& $makensis `
    "/DAPP_VERSION=$version" `
    "/DSOURCE_DIR=$Source" `
    "/DOUT_FILE=$output" `
    "/DICON_FILE=$Icon" `
    $script
if ($LASTEXITCODE -ne 0) {
    throw "makensis failed with exit code $LASTEXITCODE."
}
if (-not (Test-Path -LiteralPath $output -PathType Leaf)) {
    throw 'makensis reported success but wrote no installer.'
}
Write-Host "built $output"
