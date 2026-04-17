#Requires -Version 5.1
<#
.SYNOPSIS
    Fits the Div 1 cutoff prediction formula from recorded COTD qualifying data
    and prints the result ready to paste into CutoffServicey.as.

.DESCRIPTION
    Runs analyze_cutoffs.js with Node.js, streams the full analysis to the
    terminal, then extracts and highlights the final AngelScript formula line
    so you can copy it straight into PredictFinalCutoff() in
    src/services/CuttofService.as.

.PARAMETER DataDir
    Path to the folder containing the .txt snapshot files written by the plugin.
    Defaults to the standard Openplanet plugin storage location.

.EXAMPLE
    .\analysis\fit-formula.ps1
    .\analysis\fit-formula.ps1 "C:\Users\Me\AppData\Local\..\OpenplanetNext\PluginStorage\COTDLiveQualifying"
#>

param(
    [Parameter(Position = 0)]
    [string]$DataDir = (Join-Path $env:LOCALAPPDATA '..\OpenplanetNext\PluginStorage\COTDLiveQualifying')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Locate Node.js ────────────────────────────────────────────────────────────

$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
    Write-Error "Node.js was not found on PATH. Install it from https://nodejs.org/ and re-run."
    exit 1
}

# ── Resolve paths ─────────────────────────────────────────────────────────────

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$analyzeJs  = Join-Path $scriptDir 'analyze_cutoffs.js'

if (-not (Test-Path $analyzeJs)) {
    Write-Error "analyze_cutoffs.js not found at: $analyzeJs"
    exit 1
}

# ── Run analysis, stream output, capture lines ────────────────────────────────

Write-Host ""
Write-Host "Running analysis - this may take a few seconds (gradient descent fitting)..." -ForegroundColor Cyan
Write-Host ""

$DataDir = (Resolve-Path $DataDir -ErrorAction Stop).Path

$allLines = & node $analyzeJs $DataDir 2>&1

# Print all lines as they would appear normally
$allLines | ForEach-Object { Write-Host $_ }

# ── Extract and highlight the formula ─────────────────────────────────────────

$formulaLine = $allLines | Where-Object { $_ -match 'float correction = 1\.0f' } | Select-Object -Last 1

if (-not $formulaLine) {
    Write-Warning "Could not extract formula line from script output. Check the full output above for errors."
    exit 1
}

# Parse a and b from the line:
#   float correction = 1.0f - 0.0553f * Math::Pow(r, 1.5717f);
$match = [regex]::Match($formulaLine, '1\.0f - (?<a>[0-9.]+)f \* Math::Pow\(r, (?<b>[0-9.]+)f\)')
if ($match.Success) {
    $a = $match.Groups['a'].Value
    $b = $match.Groups['b'].Value
} else {
    $a = '?'
    $b = '?'
}

Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Yellow
Write-Host "  FORMULA TO COPY INTO src/services/CutoffService.as" -ForegroundColor Yellow
Write-Host ("=" * 70) -ForegroundColor Yellow
Write-Host ""
Write-Host "  In PredictFinalCutoff(), replace the correction line with:" -ForegroundColor White
Write-Host ""
Write-Host "    $($formulaLine.Trim())" -ForegroundColor Green
Write-Host ""
Write-Host "  a = $a   b = $b" -ForegroundColor Cyan
Write-Host ""
