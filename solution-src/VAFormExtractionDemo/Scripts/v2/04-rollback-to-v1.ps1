param(
    [string]$ConfigPath = "./v2-config.psd1"
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command pac -ErrorAction SilentlyContinue)) {
    throw "Power Platform CLI (pac) is not installed or not on PATH."
}

if (-not (Test-Path $ConfigPath)) {
    throw "Config file not found: $ConfigPath. Copy v2-config.example.psd1 to v2-config.psd1 first."
}

$config = Import-PowerShellDataFile -Path $ConfigPath

$artifactRoot = Join-Path $PSScriptRoot $config.ArtifactRoot
$baselineDir = Join-Path $artifactRoot $config.BaselineFolder
$baselineZip = Join-Path $baselineDir $config.BaselineManagedZip

if (-not (Test-Path $baselineZip)) {
    throw "Baseline managed zip not found: $baselineZip. Run 01-export-v1-baseline.ps1 first."
}

$cmd = @("solution", "import", "--path", $baselineZip, "--async", "true", "--max-async-wait-time", "$($config.MaxAsyncWaitMinutes)", "--force-overwrite", "true", "--publish-changes", "true")
if ($config.EnvironmentUrl) {
    $cmd += @("--environment", $config.EnvironmentUrl)
}

Write-Host "Rolling back to v1 baseline package: $baselineZip"
& pac @cmd

Write-Host "Rollback import complete. Re-run smoke tests and set version registry active version to v1.x-pre-lock if needed."
