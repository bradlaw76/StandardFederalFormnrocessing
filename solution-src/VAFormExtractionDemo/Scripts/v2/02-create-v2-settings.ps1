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
$candidateDir = Join-Path $artifactRoot $config.CandidateFolder
New-Item -ItemType Directory -Path $candidateDir -Force | Out-Null

$candidateZip = Join-Path $candidateDir $config.CandidateManagedZip
$settingsOut = Join-Path $candidateDir "deployment-settings.v2.json"

if (-not (Test-Path $candidateZip)) {
    throw "Candidate zip not found: $candidateZip. Place your v2 managed solution zip there first."
}

$cmd = @("solution", "create-settings", "--solution-zip", $candidateZip, "--settings-file", $settingsOut)
Write-Host "Generating deployment settings template: $settingsOut"
& pac @cmd

Write-Host "Settings template generated. Fill connectionReferences and environmentVariables before import."
