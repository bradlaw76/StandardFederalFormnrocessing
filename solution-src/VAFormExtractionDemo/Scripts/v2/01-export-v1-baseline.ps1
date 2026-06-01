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
New-Item -ItemType Directory -Path $baselineDir -Force | Out-Null

$managedPath = Join-Path $baselineDir $config.BaselineManagedZip
$unmanagedPath = Join-Path $baselineDir $config.BaselineUnmanagedZip

$commonArgs = @("solution", "export", "--name", $config.SolutionName, "--overwrite", "true", "--async", "true", "--max-async-wait-time", "$($config.MaxAsyncWaitMinutes)")
if ($config.EnvironmentUrl) {
    $commonArgs += @("--environment", $config.EnvironmentUrl)
}

Write-Host "Exporting unmanaged baseline to $unmanagedPath"
& pac @commonArgs --path $unmanagedPath --managed false

Write-Host "Exporting managed baseline to $managedPath"
& pac @commonArgs --path $managedPath --managed true

Write-Host "Baseline export complete."
