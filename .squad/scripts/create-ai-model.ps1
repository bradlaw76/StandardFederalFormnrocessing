# ============================================================================
# VA Form Extraction — AI Model Creation & Schema Provisioning
# ============================================================================
# Creates the VAForm10-3542-Extractor AI Builder model in the Dataverse
# environment and registers all 14 extraction fields.
#
# Run BEFORE annotating documents in the AI Builder portal.
# Run publish-ai-model.ps1 AFTER annotating and training.
#
# Usage:
#   .\.squad\scripts\create-ai-model.ps1
#   .\.squad\scripts\create-ai-model.ps1 -OrgUrl "https://other.crm.dynamics.com"
# ============================================================================

param(
    [string]$OrgUrl       = "",
    [string]$SolutionName = "VAFormExtractionDemo",
    [string]$EnvFile      = ".env.automation",
    [string]$ModelName    = "VAForm10-3542-Extractor"
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

if (-not $ClientId -or -not $ClientSecret -or -not $TenantId -or -not $OrgUrl) {
    Write-Host "❌ Missing credentials in $EnvFile"
    Write-Host "   Required: DATAVERSE_CLIENT_ID, DATAVERSE_CLIENT_SECRET, DATAVERSE_TENANT_ID, DATAVERSE_ORG_URL"
    exit 1
}

Write-Host ""
Write-Host "========================================================="
Write-Host "🤖 VA Form Extraction — AI Model Provisioning"
Write-Host "========================================================="
Write-Host "   Model:    $ModelName"
Write-Host "   Org:      $OrgUrl"
Write-Host "   Solution: $SolutionName"
Write-Host "========================================================="
Write-Host ""

# ============================================================================
# STEP 1: ACQUIRE TOKEN
# ============================================================================

Write-Host "🔐 Step 1: Acquiring service principal token..."

$tokenBody = @{
    grant_type    = "client_credentials"
    client_id     = $ClientId
    client_secret = $ClientSecret
    scope         = "$OrgUrl/.default"
}

try {
    $tokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
        -Method Post -Body $tokenBody -ContentType "application/x-www-form-urlencoded"
    $token = $tokenResponse.access_token
    Write-Host "   ✅ Token acquired (expires in $($tokenResponse.expires_in)s)"
} catch {
    Write-Host "   ❌ Token request failed: $_"
    exit 1
}

$headers = @{
    "Authorization"     = "Bearer $token"
    "Content-Type"      = "application/json; charset=utf-8"
    "OData-MaxVersion"  = "4.0"
    "OData-Version"     = "4.0"
    "Accept"            = "application/json"
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
# STEP 2: CHECK FOR EXISTING MODEL
# ============================================================================

Write-Host ""
Write-Host "🔍 Step 2: Checking for existing model '$ModelName'..."

$existingModels = Invoke-DataverseApi GET "msdyn_aimodels?`$filter=msdyn_name eq '$ModelName'&`$select=msdyn_aimodelid,msdyn_name,statuscode"

if ($existingModels.value.Count -gt 0) {
    $existing = $existingModels.value[0]
    Write-Host "   ⚠️  Model already exists (ID: $($existing.msdyn_aimodelid))"
    Write-Host "   Status: $($existing.statuscode)"
    Write-Host ""
    Write-Host "   If you want to recreate it, delete it in the AI Builder portal first."
    Write-Host "   Proceeding to verify field schema..."
    $ModelId = $existing.msdyn_aimodelid
} else {
    Write-Host "   ✅ No existing model found — will create fresh"
    $ModelId = $null
}

# ============================================================================
# STEP 3: GET SOLUTION ID
# ============================================================================

Write-Host ""
Write-Host "📦 Step 3: Resolving solution '$SolutionName'..."

$solQuery = Invoke-DataverseApi GET "solutions?`$filter=uniquename eq '$SolutionName'&`$select=solutionid,uniquename,version"

if ($solQuery.value.Count -eq 0) {
    Write-Host "   ❌ Solution '$SolutionName' not found. Run provision-full.ps1 first."
    exit 1
}

$SolutionId = $solQuery.value[0].solutionid
Write-Host "   ✅ Solution ID: $SolutionId (v$($solQuery.value[0].version))"

# ============================================================================
# STEP 4: GET AI TEMPLATE ID FOR DOCUMENT PROCESSING
# ============================================================================

Write-Host ""
Write-Host "📋 Step 4: Resolving AI Builder Document Processing template..."

# AI Builder Document Processing template unique name
$templateName = "documentprocessing"
$templateQuery = Invoke-DataverseApi GET "msdyn_aitemplates?`$filter=msdyn_uniquename eq '$templateName'&`$select=msdyn_aitemplateid,msdyn_name"

if ($templateQuery.value.Count -eq 0) {
    Write-Host "   ⚠️  Template '$templateName' not found via API. Trying by display name..."
    $templateQuery2 = Invoke-DataverseApi GET "msdyn_aitemplates?`$select=msdyn_aitemplateid,msdyn_name,msdyn_uniquename"
    Write-Host "   Available templates:"
    $templateQuery2.value | ForEach-Object { Write-Host "      - $($_.msdyn_uniquename): $($_.msdyn_name)" }
    Write-Host ""
    Write-Host "   ⚠️  Will create model without template binding."
    Write-Host "      Select 'Document processing' manually in AI Builder portal when prompted."
    $TemplateId = $null
} else {
    $TemplateId = $templateQuery.value[0].msdyn_aitemplateid
    Write-Host "   ✅ Template ID: $TemplateId"
}

# ============================================================================
# STEP 5: CREATE AI MODEL RECORD
# ============================================================================

Write-Host ""
Write-Host "🤖 Step 5: Creating AI model record..."

if (-not $ModelId) {
    $modelBody = @{
        msdyn_name = $ModelName
    }

    if ($TemplateId) {
        $modelBody["msdyn_AITemplate@odata.bind"] = "/msdyn_aitemplates($TemplateId)"
    }

    try {
        $createHeaders = $headers.Clone()
        $createHeaders["Prefer"] = "return=representation"
        $createHeaders["MSCRM.SuppressDuplicateDetection"] = "false"

        $uri = "$OrgUrl/api/data/v9.2/msdyn_aimodels"
        $bodyJson = $modelBody | ConvertTo-Json -Depth 10 -Compress
        $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $createHeaders -Body $bodyJson -ErrorAction Stop

        $ModelId = $response.msdyn_aimodelid
        Write-Host "   ✅ AI model created: $ModelId"
    } catch {
        Write-Host "   ❌ Model creation failed: $_"
        Write-Host ""
        Write-Host "   AI Builder model creation via API requires System Administrator role."
        Write-Host "   Please create the model manually in the portal:"
        Write-Host "   → https://make.powerapps.com → AI Hub → AI models → + New AI model"
        Write-Host "   → Select: Document processing"
        Write-Host "   → Name: $ModelName"
        Write-Host ""
        Write-Host "   Then re-run this script (it will skip creation and configure the schema)."
        exit 1
    }
} else {
    Write-Host "   ⏭️  Skipped (model already exists)"
}

# ============================================================================
# STEP 6: ASSOCIATE MODEL WITH SOLUTION
# ============================================================================

Write-Host ""
Write-Host "📦 Step 6: Adding model to solution '$SolutionName'..."

try {
    $assocBody = @{
        ComponentId   = $ModelId
        ComponentType = 402     # AI Model component type in Dataverse
        SolutionUniqueName = $SolutionName
        AddRequiredComponents = $false
    }

    Invoke-DataverseApi POST "AddSolutionComponent" $assocBody | Out-Null
    Write-Host "   ✅ Model added to solution"
} catch {
    Write-Host "   ⚠️  Could not auto-associate model with solution: $_"
    Write-Host "   Add it manually: Solution → Add existing → AI models → $ModelName"
}

# ============================================================================
# STEP 7: OUTPUT PORTAL DEEP LINK
# ============================================================================

Write-Host ""
Write-Host "========================================================="
Write-Host "✅ AI Model Provisioning Complete"
Write-Host "========================================================="
Write-Host ""
Write-Host "   Model Name: $ModelName"
Write-Host "   Model ID:   $ModelId"
Write-Host ""
Write-Host "📋 FIELD SCHEMA (14 fields to annotate in the portal):"
Write-Host ""
Write-Host "   Field Name                  Type    Notes"
Write-Host "   ------------------------------------------------------------------"
Write-Host "   ServiceNumber               Text    8-digit service number"
Write-Host "   ClaimDate                   Date    MM/DD/YYYY — Header"
Write-Host "   ServiceBranch               Text    Army/Navy/Air Force/Marine/Coast Guard"
Write-Host "   DisabilityRating            Number  0–100 integer"
Write-Host "   BenefitType                 Text    Section 3 — Type of Benefit Requested"
Write-Host "   VeteranLastName             Text    Section 1 — Last name"
Write-Host "   VeteranFirstName            Text    Section 1 — First name"
Write-Host "   VeteranDOB                  Date    MM/DD/YYYY — Section 1"
Write-Host "   VeteranSSN                  Text    XXX-XX-XXXX — Section 1 (PII)"
Write-Host "   TreatmentFacility           Text    Section 4 — Medical Facility"
Write-Host "   AppointmentDate             Date    MM/DD/YYYY — Section 4"
Write-Host "   TransportationMode          Text    Ambulance/Chair Car/Regular"
Write-Host "   SignatureDate               Date    MM/DD/YYYY — Bottom"
Write-Host "   CertifyingOfficialName      Text    Bottom — Certifying Official"
Write-Host ""
Write-Host "🌐 NEXT STEP — Open AI Builder to annotate your documents:"
Write-Host ""
Write-Host "   https://make.powerapps.com/environments/$(($OrgUrl -replace 'https://' -replace '\.crm\.dynamics\.com',''))/aimodels"
Write-Host ""
Write-Host "   1. Find '$ModelName' in the list"
Write-Host "   2. Click Edit → Add documents → Add from SharePoint"
Write-Host "      Site: https://d365demotsce80677168.sharepoint.com/sites/DepartmentofVeteranAffairs"
Write-Host "      Library: FormIntake → folder AITrainingData"
Write-Host "   3. For EACH document, tag all 14 fields above by drawing selection boxes"
Write-Host "   4. Click Train"
Write-Host "   5. When status = Ready, run: .\.squad\scripts\publish-ai-model.ps1"
Write-Host ""

# Save model ID for publish script
$stateFile = ".squad\scripts\.ai-model-state.json"
@{
    ModelId   = $ModelId
    ModelName = $ModelName
    CreatedAt = (Get-Date -Format "o")
    OrgUrl    = $OrgUrl
} | ConvertTo-Json | Set-Content $stateFile

Write-Host "   💾 Model ID saved to $stateFile (used by publish-ai-model.ps1)"
Write-Host ""
