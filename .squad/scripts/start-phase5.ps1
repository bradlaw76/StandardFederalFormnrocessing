# ============================================================================
# VA Form Extraction — Start Phase 5 Helper
# ============================================================================
# Convenience wrapper to generate the flow build kit with standard values.
# ============================================================================

param(
    [string]$ModelName = "VAFE-VA10-3542-DocProc-v1"
)

$ErrorActionPreference = "Stop"

Write-Host "Starting Phase 5 flow preparation..."
Write-Host "Model: $ModelName"

& ".\.squad\scripts\create-flows.ps1" `
    -ModelName $ModelName `
    -SolutionName "VA-Form-Extraction" `
    -SharePointSiteUrl "https://d365demotsce80677168.sharepoint.com/sites/DepartmentofVeteranAffairs" `
    -SharePointLibrary "FormIntake" `
    -FilePrefix "VA-10-3542-" `
    -AcceptThreshold 0.95 `
    -ReviewThreshold 0.80

Write-Host ""
Write-Host "Phase 5 prep complete. Open .squad/generated/flow-build-kit and follow the checklist."
