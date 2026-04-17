# Build and deploy COTDLiveQualifying plugin
$ErrorActionPreference = "Stop"

$ProjectRoot = $PSScriptRoot
$PluginDest  = Join-Path $env:USERPROFILE "OpenplanetNext\Plugins\COTDLiveQualifying.op"

Write-Host "Building plugin..."
& (Join-Path $ProjectRoot "buildPlugin.ps1")

$BuiltFile = Join-Path $ProjectRoot "distribution\COTDLiveQualifying.op"
if (-not (Test-Path $BuiltFile)) {
    Write-Error "Build failed - $BuiltFile not found."
    exit 1
}

Write-Host "Copying to $PluginDest ..."

# Use stream-based copy to overwrite even if the file is locked by Openplanet
$src  = [System.IO.File]::Open($BuiltFile,  [System.IO.FileMode]::Open,   [System.IO.FileAccess]::Read,  [System.IO.FileShare]::ReadWrite)
$dest = [System.IO.File]::Open($PluginDest, [System.IO.FileMode]::Create,  [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
try {
    $src.CopyTo($dest)
} finally {
    $dest.Close()
    $src.Close()
}

Write-Host "Done. Plugin deployed to $PluginDest"
