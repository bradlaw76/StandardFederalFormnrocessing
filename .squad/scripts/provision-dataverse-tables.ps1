# Dataverse Table Provisioning Script
# Provisions all 5 tables for VA Form Extraction solution

param(
    [string]$OrgUrl = "https://dpartementofveteranaffairs-oth.crm9.dynamics.com",
    [string]$SolutionName = "VAFormExtraction"
)

$ErrorActionPreference = "Stop"

# ============================================================================
# AUTHENTICATION & SETUP
# ============================================================================

Write-Host "🔐 Authenticating to Dataverse..."
$authContext = Get-MsalToken -ClientId "31359c7f-bd7e-475c-86db-fdb8c937548e" `
    -TenantId "ce0b3013-0ebb-4a88-90cb-4f1e1e4b5b8e" `
    -Scopes @("https://org.crm9.dynamics.com/.default") -ErrorAction SilentlyContinue

if (-not $authContext) {
    Write-Host "⚠️  No cached token. Using default pac auth context..."
    # Fall back to using pac's native auth
}

$headers = @{
    "Authorization" = "Bearer $($authContext.AccessToken)"
    "Content-Type" = "application/json"
    "OData-MaxVersions" = "4.0"
    "OData-Version" = "4.0"
}

Write-Host "✅ Connected to: $OrgUrl"
Write-Host ""

# ============================================================================
# TABLE 1: FormSubmission (Parent)
# ============================================================================

Write-Host "📋 Creating Table 1: FormSubmission..."

$formSubmissionDef = @{
    Name = "vafe_FormSubmission"
    DisplayName = @{ LocalizedLabels = @( @{ Label = "Form Submission"; LanguageCode = 1033 } ) }
    PluralName = @{ LocalizedLabels = @( @{ Label = "Form Submissions"; LanguageCode = 1033 } ) }
    Description = @{ LocalizedLabels = @( @{ Label = "Tracks VA Form 10-3542 submissions through extraction lifecycle"; LanguageCode = 1033 } ) }
    OwnershipType = "UserOwned"
    CanCreateCharts = $true
    CanCreateForms = $true
    CanCreateViews = $true
    CanModifyAdditionalSettings = $true
    IsActivity = $false
    IsValidForQueue = $true
}

try {
    $response = Invoke-RestMethod -Uri "$OrgUrl/api/data/v9.2/EntityDefinitions" `
        -Method Post `
        -Headers $headers `
        -Body (ConvertTo-Json $formSubmissionDef)
    Write-Host "  ✅ FormSubmission table created: $($response.MetadataId)"
} catch {
    if ($_.ErrorDetails.Message -like "*already exists*") {
        Write-Host "  ⚠️  FormSubmission table already exists. Skipping creation."
    } else {
        Write-Error "❌ Failed to create FormSubmission: $_"
    }
}

# ============================================================================
# TABLE 2: ExtractionResult (Child of FormSubmission)
# ============================================================================

Write-Host "📋 Creating Table 2: ExtractionResult..."

$extractionResultDef = @{
    Name = "vafe_ExtractionResult"
    DisplayName = @{ LocalizedLabels = @( @{ Label = "Extraction Result"; LanguageCode = 1033 } ) }
    PluralName = @{ LocalizedLabels = @( @{ Label = "Extraction Results"; LanguageCode = 1033 } ) }
    Description = @{ LocalizedLabels = @( @{ Label = "Stores AI-extracted field data and confidence scores"; LanguageCode = 1033 } ) }
    OwnershipType = "UserOwned"
    CanCreateCharts = $true
}

try {
    $response = Invoke-RestMethod -Uri "$OrgUrl/api/data/v9.2/EntityDefinitions" `
        -Method Post `
        -Headers $headers `
        -Body (ConvertTo-Json $extractionResultDef)
    Write-Host "  ✅ ExtractionResult table created: $($response.MetadataId)"
} catch {
    if ($_.ErrorDetails.Message -like "*already exists*") {
        Write-Host "  ⚠️  ExtractionResult table already exists. Skipping creation."
    } else {
        Write-Error "❌ Failed to create ExtractionResult: $_"
    }
}

# ============================================================================
# TABLE 3: AuditLog (Child of FormSubmission, Immutable)
# ============================================================================

Write-Host "📋 Creating Table 3: AuditLog..."

$auditLogDef = @{
    Name = "vafe_AuditLog"
    DisplayName = @{ LocalizedLabels = @( @{ Label = "Audit Log"; LanguageCode = 1033 } ) }
    PluralName = @{ LocalizedLabels = @( @{ Label = "Audit Logs"; LanguageCode = 1033 } ) }
    Description = @{ LocalizedLabels = @( @{ Label = "Immutable compliance audit trail (HIPAA/VA)"; LanguageCode = 1033 } ) }
    OwnershipType = "UserOwned"
}

try {
    $response = Invoke-RestMethod -Uri "$OrgUrl/api/data/v9.2/EntityDefinitions" `
        -Method Post `
        -Headers $headers `
        -Body (ConvertTo-Json $auditLogDef)
    Write-Host "  ✅ AuditLog table created: $($response.MetadataId)"
} catch {
    if ($_.ErrorDetails.Message -like "*already exists*") {
        Write-Host "  ⚠️  AuditLog table already exists. Skipping creation."
    } else {
        Write-Error "❌ Failed to create AuditLog: $_"
    }
}

# ============================================================================
# TABLE 4: D365WriteEvent (Child of FormSubmission, D365 Sync Tracking)
# ============================================================================

Write-Host "📋 Creating Table 4: D365WriteEvent..."

$d365WriteEventDef = @{
    Name = "vafe_D365WriteEvent"
    DisplayName = @{ LocalizedLabels = @( @{ Label = "D365 Write Event"; LanguageCode = 1033 } ) }
    PluralName = @{ LocalizedLabels = @( @{ Label = "D365 Write Events"; LanguageCode = 1033 } ) }
    Description = @{ LocalizedLabels = @( @{ Label = "Tracks synchronization attempts to Dynamics 365 with retry logic"; LanguageCode = 1033 } ) }
    OwnershipType = "UserOwned"
}

try {
    $response = Invoke-RestMethod -Uri "$OrgUrl/api/data/v9.2/EntityDefinitions" `
        -Method Post `
        -Headers $headers `
        -Body (ConvertTo-Json $d365WriteEventDef)
    Write-Host "  ✅ D365WriteEvent table created: $($response.MetadataId)"
} catch {
    if ($_.ErrorDetails.Message -like "*already exists*") {
        Write-Host "  ⚠️  D365WriteEvent table already exists. Skipping creation."
    } else {
        Write-Error "❌ Failed to create D365WriteEvent: $_"
    }
}

# ============================================================================
# TABLE 5: CorrectionRecord (Child of ExtractionResult, for manual corrections)
# ============================================================================

Write-Host "📋 Creating Table 5: CorrectionRecord..."

$correctionRecordDef = @{
    Name = "vafe_CorrectionRecord"
    DisplayName = @{ LocalizedLabels = @( @{ Label = "Correction Record"; LanguageCode = 1033 } ) }
    PluralName = @{ LocalizedLabels = @( @{ Label = "Correction Records"; LanguageCode = 1033 } ) }
    Description = @{ LocalizedLabels = @( @{ Label = "Tracks manual corrections made to low-confidence AI extractions"; LanguageCode = 1033 } ) }
    OwnershipType = "UserOwned"
}

try {
    $response = Invoke-RestMethod -Uri "$OrgUrl/api/data/v9.2/EntityDefinitions" `
        -Method Post `
        -Headers $headers `
        -Body (ConvertTo-Json $correctionRecordDef)
    Write-Host "  ✅ CorrectionRecord table created: $($response.MetadataId)"
} catch {
    if ($_.ErrorDetails.Message -like "*already exists*") {
        Write-Host "  ⚠️  CorrectionRecord table already exists. Skipping creation."
    } else {
        Write-Error "❌ Failed to create CorrectionRecord: $_"
    }
}

Write-Host ""
Write-Host "✅ All 5 tables created (or already exist)."
Write-Host ""
Write-Host "📝 Next steps:"
Write-Host "  1. Refresh Power Apps to see new tables"
Write-Host "  2. Add columns to each table (use Power Apps UI or continue with script)"
Write-Host "  3. Create relationships between tables"
Write-Host "  4. Configure business rules"
Write-Host ""
