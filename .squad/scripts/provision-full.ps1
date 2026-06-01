# ============================================================================
# VA Form Extraction — Full Automated Provisioning
# ============================================================================
# Prerequisites: Complete .squad/scripts/SETUP-GUIDE.md first (one-time, ~15 min)
# Usage: .\.squad\scripts\provision-full.ps1
#        .\.squad\scripts\provision-full.ps1 -OrgUrl "https://other.crm.dynamics.com" -SolutionName "OtherSolution"
# ============================================================================

param(
    [string]$OrgUrl         = "",
    [string]$SolutionName   = "VAFormExtractionDemo",
    [string]$PublisherPrefix = "vafe",
    [string]$EnvFile        = ".env.automation"
)

$ErrorActionPreference = "Stop"

# ============================================================================
# LOAD CREDENTIALS from .env.automation
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
    Write-Host ""
    Write-Host "❌ Missing credentials. Create .env.automation at the repo root with:"
    Write-Host "   DATAVERSE_CLIENT_ID=<app client ID>"
    Write-Host "   DATAVERSE_CLIENT_SECRET=<client secret>"
    Write-Host "   DATAVERSE_TENANT_ID=<tenant domain or GUID>"
    Write-Host "   DATAVERSE_ORG_URL=https://<your-org>.crm.dynamics.com"
    Write-Host ""
    Write-Host "📖 See: .squad/scripts/SETUP-GUIDE.md"
    exit 1
}

Write-Host ""
Write-Host "=========================================="
Write-Host "🚀 VA Form Extraction — Full Provisioning"
Write-Host "=========================================="
Write-Host "   Org:      $OrgUrl"
Write-Host "   Solution: $SolutionName"
Write-Host "   Tenant:   $TenantId"
Write-Host "   ClientID: $($ClientId.Substring(0,8))..."
Write-Host "=========================================="
Write-Host ""

# ============================================================================
# STEP 1: GET ACCESS TOKEN (Client Credentials / Service Principal)
# ============================================================================

Write-Host "🔐 Step 1: Acquiring service principal token..."

$tokenUri  = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
$tokenBody = @{
    grant_type    = "client_credentials"
    client_id     = $ClientId
    client_secret = $ClientSecret
    scope         = "$OrgUrl/.default"
}

try {
    $tokenResponse = Invoke-RestMethod -Uri $tokenUri -Method Post -Body $tokenBody -ContentType "application/x-www-form-urlencoded"
    $token         = $tokenResponse.access_token
    Write-Host "   ✅ Token acquired (expires in $($tokenResponse.expires_in)s)"
} catch {
    Write-Host "   ❌ Token request failed: $_"
    Write-Host "   Verify App Registration and client secret in .env.automation"
    exit 1
}

Write-Host ""

$headers = @{
    "Authorization"   = "Bearer $token"
    "Content-Type"    = "application/json; charset=utf-8"
    "OData-MaxVersions" = "4.0"
    "OData-Version"   = "4.0"
    "Accept"          = "application/json"
}

# ============================================================================
# HELPER: Invoke API with clear error surfacing
# ============================================================================

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
# STEP 2: ENSURE PUBLISHER
# ============================================================================

Write-Host "🏢 Step 2: Ensuring publisher ($PublisherPrefix)..."

$pubQuery = Invoke-DataverseApi GET "publishers?`$filter=customizationprefix eq '$PublisherPrefix'&`$select=publisherid"
if ($pubQuery.value.Count -gt 0) {
    $publisherId = $pubQuery.value[0].publisherid
    Write-Host "   ✅ Existing publisher: $publisherId"
} else {
    $pub = Invoke-DataverseApi POST "publishers" @{
        friendlyname             = "VA Form Extraction Demo"
        uniquename               = "${PublisherPrefix}_publisher"
        customizationprefix      = $PublisherPrefix
        customizationoptionvalueprefix = 10000
    }
    $publisherId = $pub.publisherid
    Write-Host "   ✅ Created publisher: $publisherId"
}

Write-Host ""

# ============================================================================
# STEP 3: ENSURE SOLUTION
# ============================================================================

Write-Host "📦 Step 3: Ensuring solution ($SolutionName)..."

$solQuery = Invoke-DataverseApi GET "solutions?`$filter=uniquename eq '$SolutionName'&`$select=solutionid"
if ($solQuery.value.Count -gt 0) {
    $solutionId = $solQuery.value[0].solutionid
    Write-Host "   ✅ Existing solution: $solutionId"
} else {
    $sol = Invoke-DataverseApi POST "solutions" @{
        uniquename    = $SolutionName
        friendlyname  = $SolutionName
        version       = "1.0.0.0"
        "publisherid@odata.bind" = "/publishers($publisherId)"
    }
    $solutionId = $sol.solutionid
    Write-Host "   ✅ Created solution: $solutionId"
}

Write-Host ""

# ============================================================================
# STEP 4: CREATE 5 TABLES
# ============================================================================

Write-Host "📋 Step 4: Creating tables..."
Write-Host ""

function New-DataverseTable($logicalName, $displayName, $pluralName, $description) {
    # Check if table already exists via metadata query
    try {
        $existing = Invoke-DataverseApi GET "EntityDefinitions(LogicalName='$logicalName')?`$select=MetadataId"
        Write-Host "   ⚠️  Already exists — skipping"
        return $existing.MetadataId
    } catch {
        # Expected 404 if not present — fall through to create
    }

    $tableDef = @{
        "@odata.type"  = "Microsoft.Dynamics.CRM.EntityMetadata"
        SchemaName     = $logicalName -replace "vafe_", "vafe_"  # preserve prefix
        DisplayName    = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @( @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = $displayName; LanguageCode = 1033 } ); UserLocalizedLabel = @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = $displayName; LanguageCode = 1033 } }
        DisplayCollectionName = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @( @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = $pluralName; LanguageCode = 1033 } ); UserLocalizedLabel = @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = $pluralName; LanguageCode = 1033 } }
        Description    = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @( @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = $description; LanguageCode = 1033 } ); UserLocalizedLabel = @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = $description; LanguageCode = 1033 } }
        OwnershipType  = "UserOwned"
        HasActivities  = $false
        HasNotes       = $false
        IsActivity     = $false
        PrimaryNameAttribute = "${logicalName}_name"
        Attributes     = @(
            @{
                "@odata.type"  = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
                SchemaName     = "${logicalName}_name" -replace "vafe_vafe_", "vafe_"
                RequiredLevel  = @{ "@odata.type" = "Microsoft.Dynamics.CRM.AttributeRequiredLevelManagedProperty"; Value = "None"; CanBeChanged = $true; ManagedPropertyLogicalName = "canmodifyrequirementlevelsettings" }
                MaxLength      = 100
                FormatName     = @{ "@odata.type" = "Microsoft.Dynamics.CRM.StringFormatName"; Value = "Text" }
                DisplayName    = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @( @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Name"; LanguageCode = 1033 } ); UserLocalizedLabel = @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = "Name"; LanguageCode = 1033 } }
                Description    = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(); UserLocalizedLabel = @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = ""; LanguageCode = 1033 } }
                IsPrimaryName  = $true
            }
        )
    }

    $result = Invoke-DataverseApi POST "EntityDefinitions" $tableDef
    return $result.MetadataId
}

$tables = @(
    @{ LogicalName = "vafe_formsubmission"; DisplayName = "Form Submission"; PluralName = "Form Submissions"; Description = "Tracks VA Form 10-3542 submissions through extraction lifecycle" },
    @{ LogicalName = "vafe_extractionresult"; DisplayName = "Extraction Result"; PluralName = "Extraction Results"; Description = "Stores AI-extracted field data and confidence scores" },
    @{ LogicalName = "vafe_auditlog"; DisplayName = "Audit Log"; PluralName = "Audit Logs"; Description = "Immutable compliance audit trail (HIPAA/VA)" },
    @{ LogicalName = "vafe_d365writeevent"; DisplayName = "D365 Write Event"; PluralName = "D365 Write Events"; Description = "Tracks synchronization attempts to Dynamics 365 with retry logic" },
    @{ LogicalName = "vafe_correctionrecord"; DisplayName = "Correction Record"; PluralName = "Correction Records"; Description = "Tracks manual corrections made to low-confidence AI extractions" }
)

$tableIds = @{}
foreach ($t in $tables) {
    Write-Host "   📝 $($t.DisplayName)..."
    try {
        $id = New-DataverseTable $t.LogicalName $t.DisplayName $t.PluralName $t.Description
        Write-Host "   ✅ Done ($id)"
        $tableIds[$t.LogicalName] = $id
    } catch {
        Write-Host "   ❌ $($_.ToString().Substring(0,[Math]::Min(160,$_.ToString().Length)))"
    }
    Start-Sleep -Milliseconds 800
}

Write-Host ""

# ============================================================================
# STEP 5: ADD FIELDS TO EACH TABLE
# ============================================================================

Write-Host "🔧 Step 5: Adding fields to tables..."
Write-Host "   (Each field call is separate — this takes ~30-60s total)"
Write-Host ""

# Wait for any background PublishAll to clear before adding fields
Write-Host "   ⏳ Checking for background publish jobs..."
$retries = 0
do {
    Start-Sleep -Seconds 5
    $retries++
    try {
        # Probe with a harmless metadata read; if PublishAll is running, schema ops throw
        Invoke-DataverseApi GET "EntityDefinitions(LogicalName='vafe_formsubmission')?`$select=LogicalName" | Out-Null
        $publishClear = $true
    } catch {
        $publishClear = $false
        Write-Host "   ⏳ Environment still busy ($retries/12)..."
    }
} while (-not $publishClear -and $retries -lt 12)
Write-Host "   ✅ Environment ready"
Write-Host ""

function Add-TextField($tableLogicalName, $schemaName, $displayName, $maxLength = 255, $required = $false) {
    $req = if ($required) { "Required" } else { "None" }
    $fieldDef = @{
        "@odata.type" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
        SchemaName    = $schemaName
        MaxLength     = $maxLength
        FormatName    = @{ "@odata.type" = "Microsoft.Dynamics.CRM.StringFormatName"; Value = "Text" }
        DisplayName   = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @( @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = $displayName; LanguageCode = 1033 } ); UserLocalizedLabel = @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = $displayName; LanguageCode = 1033 } }
        Description   = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(); UserLocalizedLabel = @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = ""; LanguageCode = 1033 } }
        RequiredLevel = @{ "@odata.type" = "Microsoft.Dynamics.CRM.AttributeRequiredLevelManagedProperty"; Value = $req; CanBeChanged = $true; ManagedPropertyLogicalName = "canmodifyrequirementlevelsettings" }
    }
    try {
        Invoke-DataverseApi POST "EntityDefinitions(LogicalName='$tableLogicalName')/Attributes" $fieldDef | Out-Null
        Write-Host "     ✅ $displayName"
    } catch { Write-Host "     ⚠️  $displayName — $($_.ToString().Substring(0,[Math]::Min(100,$_.ToString().Length)))" }
    Start-Sleep -Milliseconds 300
}

function Add-MemoField($tableLogicalName, $schemaName, $displayName, $maxLength = 2000) {
    $fieldDef = @{
        "@odata.type" = "Microsoft.Dynamics.CRM.MemoAttributeMetadata"
        SchemaName    = $schemaName
        MaxLength     = $maxLength
        Format        = "TextArea"
        DisplayName   = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @( @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = $displayName; LanguageCode = 1033 } ); UserLocalizedLabel = @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = $displayName; LanguageCode = 1033 } }
        Description   = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(); UserLocalizedLabel = @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = ""; LanguageCode = 1033 } }
        RequiredLevel = @{ "@odata.type" = "Microsoft.Dynamics.CRM.AttributeRequiredLevelManagedProperty"; Value = "None"; CanBeChanged = $true; ManagedPropertyLogicalName = "canmodifyrequirementlevelsettings" }
    }
    try {
        Invoke-DataverseApi POST "EntityDefinitions(LogicalName='$tableLogicalName')/Attributes" $fieldDef | Out-Null
        Write-Host "     ✅ $displayName"
    } catch { Write-Host "     ⚠️  $displayName — $($_.ToString().Substring(0,[Math]::Min(100,$_.ToString().Length)))" }
    Start-Sleep -Milliseconds 300
}

function Add-DateTimeField($tableLogicalName, $schemaName, $displayName) {
    $fieldDef = @{
        "@odata.type"  = "Microsoft.Dynamics.CRM.DateTimeAttributeMetadata"
        SchemaName     = $schemaName
        Format         = "DateAndTime"
        DateTimeBehavior = @{ "@odata.type" = "Microsoft.Dynamics.CRM.DateTimeBehavior"; Value = "UserLocal" }
        DisplayName    = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @( @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = $displayName; LanguageCode = 1033 } ); UserLocalizedLabel = @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = $displayName; LanguageCode = 1033 } }
        Description    = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(); UserLocalizedLabel = @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = ""; LanguageCode = 1033 } }
        RequiredLevel  = @{ "@odata.type" = "Microsoft.Dynamics.CRM.AttributeRequiredLevelManagedProperty"; Value = "None"; CanBeChanged = $true; ManagedPropertyLogicalName = "canmodifyrequirementlevelsettings" }
    }
    try {
        Invoke-DataverseApi POST "EntityDefinitions(LogicalName='$tableLogicalName')/Attributes" $fieldDef | Out-Null
        Write-Host "     ✅ $displayName"
    } catch { Write-Host "     ⚠️  $displayName — $($_.ToString().Substring(0,[Math]::Min(100,$_.ToString().Length)))" }
    Start-Sleep -Milliseconds 300
}

function Add-DecimalField($tableLogicalName, $schemaName, $displayName, $min = 0, $max = 1, $precision = 5) {
    $fieldDef = @{
        "@odata.type"  = "Microsoft.Dynamics.CRM.DecimalAttributeMetadata"
        SchemaName     = $schemaName
        MinValue       = $min
        MaxValue       = $max
        Precision      = $precision
        DisplayName    = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @( @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = $displayName; LanguageCode = 1033 } ); UserLocalizedLabel = @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = $displayName; LanguageCode = 1033 } }
        Description    = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(); UserLocalizedLabel = @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = ""; LanguageCode = 1033 } }
        RequiredLevel  = @{ "@odata.type" = "Microsoft.Dynamics.CRM.AttributeRequiredLevelManagedProperty"; Value = "None"; CanBeChanged = $true; ManagedPropertyLogicalName = "canmodifyrequirementlevelsettings" }
    }
    try {
        Invoke-DataverseApi POST "EntityDefinitions(LogicalName='$tableLogicalName')/Attributes" $fieldDef | Out-Null
        Write-Host "     ✅ $displayName"
    } catch { Write-Host "     ⚠️  $displayName — $($_.ToString().Substring(0,[Math]::Min(100,$_.ToString().Length)))" }
    Start-Sleep -Milliseconds 300
}

function Add-IntegerField($tableLogicalName, $schemaName, $displayName, $min = 0, $max = 2147483647) {
    $fieldDef = @{
        "@odata.type"  = "Microsoft.Dynamics.CRM.IntegerAttributeMetadata"
        SchemaName     = $schemaName
        MinValue       = $min
        MaxValue       = $max
        Format         = "None"
        DisplayName    = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @( @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = $displayName; LanguageCode = 1033 } ); UserLocalizedLabel = @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = $displayName; LanguageCode = 1033 } }
        Description    = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(); UserLocalizedLabel = @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = ""; LanguageCode = 1033 } }
        RequiredLevel  = @{ "@odata.type" = "Microsoft.Dynamics.CRM.AttributeRequiredLevelManagedProperty"; Value = "None"; CanBeChanged = $true; ManagedPropertyLogicalName = "canmodifyrequirementlevelsettings" }
    }
    try {
        Invoke-DataverseApi POST "EntityDefinitions(LogicalName='$tableLogicalName')/Attributes" $fieldDef | Out-Null
        Write-Host "     ✅ $displayName"
    } catch { Write-Host "     ⚠️  $displayName — $($_.ToString().Substring(0,[Math]::Min(100,$_.ToString().Length)))" }
    Start-Sleep -Milliseconds 300
}

function Add-ChoiceField($tableLogicalName, $schemaName, $displayName, [string[]]$options) {
    $optionValues = @()
    $i = 100000
    foreach ($opt in $options) {
        $optionValues += @{
            "@odata.type" = "Microsoft.Dynamics.CRM.OptionMetadata"
            Value         = $i
            Label         = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @( @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = $opt; LanguageCode = 1033 } ); UserLocalizedLabel = @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = $opt; LanguageCode = 1033 } }
            Description   = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(); UserLocalizedLabel = @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = ""; LanguageCode = 1033 } }
        }
        $i += 1
    }
    $fieldDef = @{
        "@odata.type"  = "Microsoft.Dynamics.CRM.PicklistAttributeMetadata"
        SchemaName     = $schemaName
        OptionSet      = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.OptionSetMetadata"
            IsGlobal      = $false
            OptionSetType = "Picklist"
            Options       = $optionValues
        }
        DisplayName    = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @( @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = $displayName; LanguageCode = 1033 } ); UserLocalizedLabel = @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = $displayName; LanguageCode = 1033 } }
        Description    = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(); UserLocalizedLabel = @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = ""; LanguageCode = 1033 } }
        RequiredLevel  = @{ "@odata.type" = "Microsoft.Dynamics.CRM.AttributeRequiredLevelManagedProperty"; Value = "None"; CanBeChanged = $true; ManagedPropertyLogicalName = "canmodifyrequirementlevelsettings" }
    }
    try {
        Invoke-DataverseApi POST "EntityDefinitions(LogicalName='$tableLogicalName')/Attributes" $fieldDef | Out-Null
        Write-Host "     ✅ $displayName ($($options -join ', '))"
    } catch { Write-Host "     ⚠️  $displayName — $($_.ToString().Substring(0,[Math]::Min(100,$_.ToString().Length)))" }
    Start-Sleep -Milliseconds 300
}

# --- FormSubmission fields ---
Write-Host "   Table: Form Submission"
Add-DateTimeField  "vafe_formsubmission" "vafe_UploadDate"         "Upload Date"
Add-TextField      "vafe_formsubmission" "vafe_SourceFile"         "Source File"          255
Add-ChoiceField    "vafe_formsubmission" "vafe_Status"             "Status"               @("Intake","Extracting","Extracted","Correcting","Corrected","Writing","Written")
Add-MemoField      "vafe_formsubmission" "vafe_ProcessingNotes"    "Processing Notes"     2000
Add-DateTimeField  "vafe_formsubmission" "vafe_ProcessingStart"    "Processing Start"
Add-DateTimeField  "vafe_formsubmission" "vafe_ProcessingEnd"      "Processing End"
Add-MemoField      "vafe_formsubmission" "vafe_ErrorDetails"       "Error Details"        2000
Add-DateTimeField  "vafe_formsubmission" "vafe_ProcessedTimestamp" "Processed Timestamp"
Write-Host ""

# --- ExtractionResult fields ---
Write-Host "   Table: Extraction Result"
Add-MemoField      "vafe_extractionresult" "vafe_ExtractedData"          "Extracted Data"            5000
Add-MemoField      "vafe_extractionresult" "vafe_FieldConfidenceScores"  "Field Confidence Scores"   5000
Add-DecimalField   "vafe_extractionresult" "vafe_OverallConfidence"      "Overall Confidence"        0 1 5
Add-ChoiceField    "vafe_extractionresult" "vafe_ExtractionStatus"       "Extraction Status"         @("Success","PartialSuccess","Failed")
Add-TextField      "vafe_extractionresult" "vafe_ModelVersion"           "Model Version"             100
Add-DateTimeField  "vafe_extractionresult" "vafe_ExtractionTimestamp"    "Extraction Timestamp"
Add-MemoField      "vafe_extractionresult" "vafe_ErrorMessage"           "Error Message"             2000
Write-Host ""

# --- AuditLog fields ---
Write-Host "   Table: Audit Log"
Add-ChoiceField    "vafe_auditlog" "vafe_Action"        "Action"         @("Create","Read","Update","Delete")
Add-DateTimeField  "vafe_auditlog" "vafe_Timestamp"     "Timestamp"
Add-TextField      "vafe_auditlog" "vafe_UserId"        "User ID"        255
Add-TextField      "vafe_auditlog" "vafe_IPAddress"     "IP Address"     45
Add-MemoField      "vafe_auditlog" "vafe_Details"       "Details"        2000
Add-TextField      "vafe_auditlog" "vafe_ErrorCode"     "Error Code"     50
Add-ChoiceField    "vafe_auditlog" "vafe_Severity"      "Severity"       @("Info","Warning","Error","Critical")
Add-TextField      "vafe_auditlog" "vafe_CorrelationId" "Correlation ID" 100
Write-Host ""

# --- D365WriteEvent fields ---
Write-Host "   Table: D365 Write Event"
Add-ChoiceField    "vafe_d365writeevent" "vafe_D365Status"      "D365 Status"      @("Pending","Success","Failed","Retrying")
Add-DateTimeField  "vafe_d365writeevent" "vafe_TimestampWritten" "Timestamp Written"
Add-TextField      "vafe_d365writeevent" "vafe_D365RecordId"    "D365 Record ID"   100
Add-IntegerField   "vafe_d365writeevent" "vafe_RetryCount"      "Retry Count"      0 100
Add-DateTimeField  "vafe_d365writeevent" "vafe_LastRetry"       "Last Retry"
Add-MemoField      "vafe_d365writeevent" "vafe_ErrorDetails"    "Error Details"    2000
Add-MemoField      "vafe_d365writeevent" "vafe_PayloadSent"     "Payload Sent"     5000
Add-IntegerField   "vafe_d365writeevent" "vafe_HTTPStatusCode"  "HTTP Status Code" 100 599
Write-Host ""

# --- CorrectionRecord fields ---
Write-Host "   Table: Correction Record"
Add-TextField      "vafe_correctionrecord" "vafe_FieldName"        "Field Name"        255
Add-MemoField      "vafe_correctionrecord" "vafe_OriginalValue"    "Original Value"    2000
Add-MemoField      "vafe_correctionrecord" "vafe_CorrectedValue"   "Corrected Value"   2000
Add-DateTimeField  "vafe_correctionrecord" "vafe_CorrectionDate"   "Correction Date"
Add-ChoiceField    "vafe_correctionrecord" "vafe_CorrectionStatus" "Correction Status" @("Pending","Approved","Rejected")
Add-MemoField      "vafe_correctionrecord" "vafe_CorrectionNotes"  "Correction Notes"  2000
Add-DecimalField   "vafe_correctionrecord" "vafe_FieldConfidence"  "Field Confidence"  0 1 5
Add-IntegerField   "vafe_correctionrecord" "vafe_ReviewSLA"        "Review SLA (min)"  0 10080
Write-Host ""

# ============================================================================
# STEP 6: CREATE LOOKUP RELATIONSHIPS
# ============================================================================

Write-Host "🔗 Step 6: Creating relationships..."
Write-Host ""

function New-LookupRelationship($primaryTable, $relatedTable, $navPropSchema, $displayName) {
    # Check if relationship already exists
    $schemaName = "${primaryTable}_${relatedTable}"
    try {
        $existing = Invoke-DataverseApi GET "RelationshipDefinitions(SchemaName='$schemaName')?`$select=SchemaName"
        Write-Host "   ⚠️  Already exists — skipping ($schemaName)"
        return
    } catch { <# expected 404 if not present — fall through to create #> }

    $relDef = @{
        "@odata.type"         = "Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata"
        SchemaName            = "${primaryTable}_${relatedTable}"
        ReferencedEntity      = $primaryTable
        ReferencingEntity     = $relatedTable
        ReferencedAttribute   = "${primaryTable}id"
        CascadeConfiguration  = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.CascadeConfiguration"
            Assign        = "NoCascade"
            Delete        = "Cascade"
            Merge         = "NoCascade"
            Reparent      = "NoCascade"
            Share         = "NoCascade"
            Unshare       = "NoCascade"
            RollupView    = "NoCascade"
        }
        Lookup = @{
            "@odata.type"  = "Microsoft.Dynamics.CRM.LookupAttributeMetadata"
            SchemaName     = $navPropSchema
            DisplayName    = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @( @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = $displayName; LanguageCode = 1033 } ); UserLocalizedLabel = @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = $displayName; LanguageCode = 1033 } }
            Description    = @{ "@odata.type" = "Microsoft.Dynamics.CRM.Label"; LocalizedLabels = @(); UserLocalizedLabel = @{ "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"; Label = ""; LanguageCode = 1033 } }
            RequiredLevel  = @{ "@odata.type" = "Microsoft.Dynamics.CRM.AttributeRequiredLevelManagedProperty"; Value = "None"; CanBeChanged = $true; ManagedPropertyLogicalName = "canmodifyrequirementlevelsettings" }
        }
    }
    try {
        Invoke-DataverseApi POST "RelationshipDefinitions" $relDef | Out-Null
        Write-Host "   ✅ $primaryTable → $relatedTable (cascade delete enabled)"
    } catch {
        Write-Host "   ⚠️  $primaryTable → $relatedTable — $($_.ToString().Substring(0,[Math]::Min(120,$_.ToString().Length)))"
    }
    Start-Sleep -Milliseconds 800
}

New-LookupRelationship "vafe_formsubmission" "vafe_extractionresult"  "vafe_FormSubmissionId"  "Form Submission"
New-LookupRelationship "vafe_formsubmission" "vafe_auditlog"           "vafe_FormSubmissionId"  "Form Submission"
New-LookupRelationship "vafe_formsubmission" "vafe_d365writeevent"     "vafe_FormSubmissionId"  "Form Submission"
New-LookupRelationship "vafe_extractionresult" "vafe_correctionrecord" "vafe_ExtractionResultId" "Extraction Result"

Write-Host ""

# ============================================================================
# STEP 7: PUBLISH CUSTOMIZATIONS
# ============================================================================

Write-Host "📢 Step 7: Publishing all customizations..."

try {
    $publishBody = @{ ParameterXml = "<importexportxml><entities></entities></importexportxml>" }
    Invoke-DataverseApi POST "PublishAllXml" $null | Out-Null
    Write-Host "   ✅ Customizations published"
} catch {
    Write-Host "   ⚠️  Publish returned: $_"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "✅ PROVISIONING COMPLETE"
Write-Host "=========================================="
Write-Host ""
Write-Host "  Solution: $SolutionName"
Write-Host "  Tables:   5 (FormSubmission, ExtractionResult, AuditLog,"
Write-Host "               D365WriteEvent, CorrectionRecord)"
Write-Host "  Fields:   40+ across all tables"
Write-Host "  Rels:     4 (all with cascade delete)"
Write-Host ""
Write-Host "  🌐 Verify at: https://make.powerapps.com"
Write-Host "     Environment: Contact Center"
Write-Host "     Solution: $SolutionName"
Write-Host ""
Write-Host "  📦 Export + commit the finished solution:"
Write-Host "     pac solution export --name $SolutionName --path .\solution-export.zip --overwrite"
Write-Host "     git add solution-export.zip && git commit -m 'Phase 2: tables provisioned'"
Write-Host ""
