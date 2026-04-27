# ============================================================================
# VA Form Extraction — Publish AI Model After Training
# ============================================================================
# Run this AFTER you have:
#   1. Run create-ai-model.ps1
#   2. Annotated all documents in the AI Builder portal
#   3. Clicked Train and waited for status = Ready
#
# Usage:
#   .\.squad\scripts\publish-ai-model.ps1
#   .\.squad\scripts\publish-ai-model.ps1 -ModelId "00000000-0000-0000-0000-000000000000"
# ============================================================================

param(
    [string]$ModelId  = "",
    [string]$OrgUrl   = "",
    [string]$EnvFile  = ".env.automation"
)

$ErrorActionPreference = "Stop"

# ============================================================================
# LOAD CREDENTIALS
# ============================================================================

function Read-EnvFile($path) {
    $vars = @{}
    if (-not (Test-Path $path)) { return $vars }
    Get-Content $path | Where-Object { $_ -match "^\s*[^#]" -and $_ -match "=" } | ForEach-Object {
        $parts = $_ -split "=", 2
        $vars[$parts[0].Trim()] = $parts[1].Trim()
    }
    return $vars
}

$env = Read-EnvFile $EnvFile
$ClientId     = $env["DATAVERSE_CLIENT_ID"]
$ClientSecret = $env["DATAVERSE_CLIENT_SECRET"]
$TenantId     = $env["DATAVERSE_TENANT_ID"]
if (-not $OrgUrl) { $OrgUrl = $env["DATAVERSE_ORG_URL"] }

# Load model ID from state file if not provided
$stateFile = ".squad\scripts\.ai-model-state.json"
if (-not $ModelId -and (Test-Path $stateFile)) {
    $state   = Get-Content $stateFile | ConvertFrom-Json
    $ModelId = $state.ModelId
    Write-Host "   📋 Loaded Model ID from state file: $ModelId"
}

if (-not $ModelId) {
    Write-Host "❌ No Model ID provided. Pass -ModelId or run create-ai-model.ps1 first."
    exit 1
}

Write-Host ""
Write-Host "========================================================="
Write-Host "📤 VA Form Extraction — AI Model Publish"
Write-Host "========================================================="
Write-Host "   Model ID: $ModelId"
Write-Host "   Org:      $OrgUrl"
Write-Host "========================================================="
Write-Host ""

# ============================================================================
# ACQUIRE TOKEN
# ============================================================================

Write-Host "🔐 Acquiring service principal token..."

$tokenBody = @{
    grant_type    = "client_credentials"
    client_id     = $ClientId
    client_secret = $ClientSecret
    scope         = "$OrgUrl/.default"
}

$tokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
    -Method Post -Body $tokenBody -ContentType "application/x-www-form-urlencoded"
$token = $tokenResponse.access_token
Write-Host "   ✅ Token acquired"

$headers = @{
    "Authorization"    = "Bearer $token"
    "Content-Type"     = "application/json; charset=utf-8"
    "OData-MaxVersion" = "4.0"
    "OData-Version"    = "4.0"
    "Accept"           = "application/json"
}

function Invoke-DataverseApi($method, $relPath, $body = $null) {
    $uri = "$OrgUrl/api/data/v9.2/$relPath"
    $params = @{ Uri = $uri; Method = $method; Headers = $headers; ErrorAction = "Stop" }
    if ($body) { $params["Body"] = ($body | ConvertTo-Json -Depth 20 -Compress) }
    try {
        return Invoke-RestMethod @params
    } catch {
        $msg = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($msg) { throw $msg.error.message }
        throw $_
    }
}

# ============================================================================
# CHECK MODEL STATUS
# ============================================================================

Write-Host ""
Write-Host "🔍 Checking model training status..."

$model = Invoke-DataverseApi GET "msdyn_aimodels($ModelId)?`$select=msdyn_name,msdyn_trainingstatus,statuscode,statecode"

Write-Host "   Name:            $($model.msdyn_name)"
Write-Host "   Training Status: $($model.msdyn_trainingstatus)"
Write-Host "   Status Code:     $($model.statuscode)"

# msdyn_trainingstatus values: 0=NotTrained, 1=Training, 2=Trained, 3=PublishFailed, 4=Published
$trainingStatus = $model.msdyn_trainingstatus

if ($trainingStatus -eq 1) {
    Write-Host ""
    Write-Host "   ⏳ Model is still training. Wait for it to complete in the AI Builder portal,"
    Write-Host "   then re-run this script."
    exit 0
}

if ($trainingStatus -eq 0) {
    Write-Host ""
    Write-Host "   ⚠️  Model has not been trained yet."
    Write-Host "   Complete annotation in the AI Builder portal and click Train first."
    Write-Host "   → https://make.powerapps.com → AI Hub → AI models → VAForm10-3542-Extractor"
    exit 1
}

if ($trainingStatus -eq 4) {
    Write-Host "   ✅ Model is already published!"
    Write-Host "   You can use it in Power Automate flows now."
    exit 0
}

if ($trainingStatus -ne 2) {
    Write-Host "   ⚠️  Unexpected training status: $trainingStatus"
    Write-Host "   Check the AI Builder portal for details."
}

# ============================================================================
# PUBLISH MODEL
# ============================================================================

Write-Host ""
Write-Host "📤 Publishing model..."

try {
    Invoke-DataverseApi POST "msdyn_PublishAIModel" @{ msdyn_AIModelId = $ModelId } | Out-Null
    Write-Host "   ✅ Publish request sent"
} catch {
    Write-Host "   ❌ Publish via API failed: $_"
    Write-Host ""
    Write-Host "   Publish manually in the portal:"
    Write-Host "   → https://make.powerapps.com → AI Hub → AI models → VAForm10-3542-Extractor → Publish"
    exit 1
}

# ============================================================================
# WAIT FOR PUBLISH TO COMPLETE (up to 3 min)
# ============================================================================

Write-Host ""
Write-Host "⏳ Waiting for model to reach Published state (up to 3 min)..."

$maxWait = 180
$waited  = 0
$interval = 10

while ($waited -lt $maxWait) {
    Start-Sleep -Seconds $interval
    $waited += $interval

    $check = Invoke-DataverseApi GET "msdyn_aimodels($ModelId)?`$select=msdyn_trainingstatus,statuscode"
    if ($check.msdyn_trainingstatus -eq 4) {
        Write-Host "   ✅ Model published! ($waited s elapsed)"
        break
    }
    Write-Host "   ... still publishing ($waited/$maxWait s) — status: $($check.msdyn_trainingstatus)"
}

if ($waited -ge $maxWait) {
    Write-Host "   ⚠️  Timeout waiting for publish. Check status in the AI Builder portal."
}

# ============================================================================
# OUTPUT NEXT STEPS
# ============================================================================

Write-Host ""
Write-Host "========================================================="
Write-Host "✅ Model published — VAForm10-3542-Extractor is ready"
Write-Host "========================================================="
Write-Host ""
Write-Host "📋 NEXT STEP — Build Power Automate flows:"
Write-Host ""
Write-Host "   Run: .\.squad\scripts\create-flows.ps1"
Write-Host ""
Write-Host "   This will create all 5 flows and connect them to the published model:"
Write-Host "     Flow 1: VAFE-Flow-01-SharePointIntake"
Write-Host "     Flow 2: VAFE-Flow-02-AIExtraction"
Write-Host "     Flow 3: VAFE-Flow-03-D365Write"
Write-Host "     Flow 4: VAFE-Flow-04-ManualReview"
Write-Host "     Flow 5: VAFE-Flow-05-ErrorHandler"
Write-Host ""
