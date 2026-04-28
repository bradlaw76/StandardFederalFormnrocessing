# ============================================================================
# VA Form Extraction — Phase 5 Flow Build Kit Generator
# ============================================================================
# Purpose:
#   Generates a concrete build kit for all 5 required Power Automate flows,
#   using the currently published AI Builder model and environment settings.
#
# Usage:
#   .\.squad\scripts\create-flows.ps1
#   .\.squad\scripts\create-flows.ps1 -ModelName "VAFE-VA10-3542-DocProc-v1"
# ============================================================================

param(
    [string]$ModelName = "VAFE-VA10-3542-DocProc-v1",
    [string]$SolutionName = "VA-Form-Extraction",
    [string]$SharePointSiteUrl = "https://d365demotsce80677168.sharepoint.com/sites/DepartmentofVeteranAffairs",
    [string]$SharePointLibrary = "FormIntake",
    [string]$FilePrefix = "VA-10-3542-",
    [double]$AcceptThreshold = 0.95,
    [double]$ReviewThreshold = 0.80,
    [string]$OutDir = ".squad\generated\flow-build-kit"
)

$ErrorActionPreference = "Stop"

function Write-Section($title) {
    Write-Host ""
    Write-Host "========================================================="
    Write-Host " $title"
    Write-Host "========================================================="
}

Write-Section "VA Form Extraction — Create Flow Build Kit"
Write-Host "Model:            $ModelName"
Write-Host "Solution:         $SolutionName"
Write-Host "SharePoint Site:  $SharePointSiteUrl"
Write-Host "Library:          $SharePointLibrary"
Write-Host "File Prefix:      $FilePrefix"
Write-Host "Accept Threshold: $AcceptThreshold"
Write-Host "Review Threshold: $ReviewThreshold"

if ($AcceptThreshold -le $ReviewThreshold) {
    throw "AcceptThreshold must be greater than ReviewThreshold."
}

if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}

$flowPlan = @{
    generatedAt = (Get-Date -Format "o")
    solutionName = $SolutionName
    modelName = $ModelName
    sharePoint = @{
        siteUrl = $SharePointSiteUrl
        library = $SharePointLibrary
        filePrefix = $FilePrefix
    }
    thresholds = @{
        autoApprove = $AcceptThreshold
        manualReview = $ReviewThreshold
    }
    flows = @(
        @{
            order = 1
            name = "VAFE-Flow-01-SharePointIntake"
            type = "Automated cloud flow"
            trigger = "SharePoint.WhenFileCreated"
            triggerConfig = @{
                site = $SharePointSiteUrl
                library = $SharePointLibrary
                triggerCondition = "@startsWith(triggerOutputs()?['body/{FilenameWithExtension}'], '$FilePrefix')"
            }
            actions = @(
                "Initialize variables: FormId, FileName, FileUrl, SubmittedUtc",
                "Dataverse Add row: vafe_formsubmission (Status=Intake)",
                "Dataverse Add row: vafe_auditlog (Event=FileValidated)",
                "Run child flow: VAFE-Flow-02-AIExtraction"
            )
            outputs = @("FormSubmissionId", "SharePointFileId", "FileContent")
        },
        @{
            order = 2
            name = "VAFE-Flow-02-AIExtraction"
            type = "Instant cloud flow (child)"
            trigger = "Flow.RunChildFlow"
            childInputs = @("FormSubmissionId", "SharePointFileId")
            actions = @(
                "SharePoint Get file content",
                "AI Builder Predict using model '$ModelName'",
                "Transform extracted fields + confidence to JSON",
                "Dataverse Add row: vafe_extractionresult",
                "Run child flow: VAFE-Flow-03-DecisionRouting"
            )
            outputs = @("ExtractionResultId", "OverallConfidence")
        },
        @{
            order = 3
            name = "VAFE-Flow-03-DecisionRouting"
            type = "Instant cloud flow (child)"
            trigger = "Flow.RunChildFlow"
            childInputs = @("FormSubmissionId", "ExtractionResultId", "OverallConfidence")
            conditions = @(
                "if OverallConfidence >= $AcceptThreshold => ReadyForD365Write",
                "if OverallConfidence >= $ReviewThreshold and < $AcceptThreshold => ManualReview",
                "if OverallConfidence < $ReviewThreshold => Failed"
            )
            actions = @(
                "Dataverse Update row: vafe_formsubmission status",
                "On ManualReview: create vafe_correctionrecord entries for low-confidence fields",
                "On ReadyForD365Write: run child flow VAFE-Flow-04-D365Write",
                "On Failed: run child flow VAFE-Flow-05-ErrorHandling"
            )
            outputs = @("FinalRoute")
        },
        @{
            order = 4
            name = "VAFE-Flow-04-D365Write"
            type = "Instant cloud flow (child)"
            trigger = "Flow.RunChildFlow"
            childInputs = @("FormSubmissionId", "ExtractionResultId")
            actions = @(
                "Parse extraction JSON",
                "Map fields to D365/Dataverse schema",
                "Dataverse Add row: vafe_d365writeevent (Status=Pending)",
                "Write target records",
                "Dataverse Update row: vafe_d365writeevent (Success/Failed)",
                "Dataverse Add row: vafe_auditlog"
            )
            outputs = @("WriteStatus", "WriteEventId")
        },
        @{
            order = 5
            name = "VAFE-Flow-05-ErrorHandling"
            type = "Scheduled cloud flow"
            trigger = "Recurrence.Every15Minutes"
            actions = @(
                "List failed/pending vafe_d365writeevent rows",
                "Retry transient failures (max 3)",
                "Escalate hard failures to manual review queue",
                "Log all retries/escalations to vafe_auditlog"
            )
            outputs = @("RetryCount", "EscalationCount")
        }
    )
}

$flowPlanPath = Join-Path $OutDir "flow-plan.json"
$flowPlan | ConvertTo-Json -Depth 12 | Set-Content -Path $flowPlanPath -Encoding UTF8

$checklistPath = Join-Path $OutDir "flow-build-checklist.txt"
@(
    "VA Form Extraction — Flow Build Checklist",
    "Generated: $(Get-Date -Format 'u')",
    "",
    "Preflight",
    "- [ ] Model published: $ModelName",
    "- [ ] SharePoint site reachable: $SharePointSiteUrl",
    "- [ ] Library exists: $SharePointLibrary",
    "- [ ] Dataverse tables ready: formsubmission, extractionresult, correctionrecord, auditlog, d365writeevent",
    "",
    "Build Order",
    "1. [ ] VAFE-Flow-01-SharePointIntake",
    "2. [ ] VAFE-Flow-02-AIExtraction",
    "3. [ ] VAFE-Flow-03-DecisionRouting",
    "4. [ ] VAFE-Flow-04-D365Write",
    "5. [ ] VAFE-Flow-05-ErrorHandling",
    "",
    "Validation",
    "- [ ] Good sample auto-routes to D365 write",
    "- [ ] Medium confidence routes to manual review",
    "- [ ] Low confidence routes to failure queue",
    "- [ ] Audit log entry exists for each stage",
    "- [ ] D365 write events include retry metadata"
) | Set-Content -Path $checklistPath -Encoding UTF8

$expressionsPath = Join-Path $OutDir "power-automate-expressions.txt"
@(
    "# Trigger condition (Flow 1)",
    "@startsWith(triggerOutputs()?['body/{FilenameWithExtension}'], '$FilePrefix')",
    "",
    "# Confidence route (Flow 3)",
    "@greaterOrEquals(float(triggerBody()?['OverallConfidence']), $AcceptThreshold)",
    "@and(greaterOrEquals(float(triggerBody()?['OverallConfidence']), $ReviewThreshold), less(float(triggerBody()?['OverallConfidence']), $AcceptThreshold))",
    "@less(float(triggerBody()?['OverallConfidence']), $ReviewThreshold)",
    "",
    "# Retry filter (Flow 5)",
    "vafe_status eq 'Failed' and vafe_retry_count lt 3"
) | Set-Content -Path $expressionsPath -Encoding UTF8

Write-Section "Build Kit Created"
Write-Host "✅ $flowPlanPath"
Write-Host "✅ $checklistPath"
Write-Host "✅ $expressionsPath"
Write-Host ""
Write-Host "Next action in Power Automate:"
Write-Host "1. Open solution '$SolutionName'"
Write-Host "2. Build flows in the listed order"
Write-Host "3. Use flow-plan.json + expressions.txt as source of truth"
Write-Host ""
