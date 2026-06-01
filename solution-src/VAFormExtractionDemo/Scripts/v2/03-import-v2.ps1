param(
    [string]$ConfigPath = "./v2-config.psd1",
    [switch]$SkipLowerVersion
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
$candidateDir = Join-Path $artifactRoot $config.CandidateFolder
$candidateZip = Join-Path $candidateDir $config.CandidateManagedZip

if (-not (Test-Path $candidateZip)) {
    throw "Candidate managed zip not found: $candidateZip"
}

$cmd = @("solution", "import", "--path", $candidateZip, "--async", "true", "--max-async-wait-time", "$($config.MaxAsyncWaitMinutes)")

if ($config.EnvironmentUrl) {
    $cmd += @("--environment", $config.EnvironmentUrl)
}
if ($config.PublishChangesOnImport) {
    $cmd += @("--publish-changes", "true")
}
if ($config.ForceOverwriteOnImport) {
    $cmd += @("--force-overwrite", "true")
}
if ($config.ActivatePluginsOnImport) {
    $cmd += @("--activate-plugins", "true")
}
if ($SkipLowerVersion) {
    $cmd += @("--skip-lower-version", "true")
}
if ($config.SettingsFile -and (Test-Path $config.SettingsFile)) {
    $cmd += @("--settings-file", $config.SettingsFile)
}

Write-Host "Importing v2 candidate package: $candidateZip"
& pac @cmd

Write-Host "v2 import completed. Run smoke test before promoting as active."
