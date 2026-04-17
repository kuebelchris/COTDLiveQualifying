# Build COTDLiveQualifying plugin
$ErrorActionPreference = "Stop"

$ProjectRoot = $PSScriptRoot
$OutputDir   = Join-Path $ProjectRoot "distribution"
$OutputFile  = Join-Path $OutputDir "COTDLiveQualifying.op"

Write-Host "Building plugin..."
Push-Location $ProjectRoot

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

# tar auto-detects format from extension — must use .zip so it produces a valid ZIP archive
$ZipFile = Join-Path $OutputDir "COTDLiveQualifying.zip"
tar.exe -a -c -f "$ZipFile" src info.toml

Pop-Location

if (-not (Test-Path $ZipFile)) {
    Write-Error "Build failed - $ZipFile was not created."
    exit 1
}

# Copy the zip as .op (Openplanet plugin format is just a renamed zip)
Copy-Item -Path $ZipFile -Destination $OutputFile -Force

Write-Host "Build succeeded: $OutputFile (zip kept at $ZipFile)"
