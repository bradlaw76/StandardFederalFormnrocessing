# Create Solution + Tables via Dataverse Web API
# Step 1: Create solution container
# Step 2: Create 5 tables within solution

param(
    [string]$OrgUrl = "https://healthconnectcenter.crm.dynamics.com",
    [string]$PublisherPrefix = "vafe",
    [string]$PublisherName = "VA Form Extraction Demo",
    [string]$SolutionName = "VAFormExtractionDemo",
    [string]$SolutionUniqueName = "VAFormExtractionDemo"
)

$ErrorActionPreference = "Stop"

Write-Host "=========================================="
Write-Host "🚀 Create Solution + Tables"
Write-Host "=========================================="
Write-Host ""

# Get fresh token
Write-Host "🔐 Getting auth token..."
$tokenOutput = az account get-access-token --resource "https://healthconnectcenter.crm.dynamics.com" 2>&1
$tokenData = $tokenOutput | ConvertFrom-Json
$accessToken = $tokenData.accessToken
Write-Host "  ✅ Token acquired"
Write-Host ""

$headers = @{
    "Authorization" = "Bearer $accessToken"
    "Content-Type" = "application/json; charset=utf-8"
    "OData-MaxVersions" = "4.0"
    "OData-Version" = "4.0"
}

# ============================================================================
# STEP 1: Create Publisher
# ============================================================================

Write-Host "📝 Step 1: Creating Publisher..."

$publisherDef = @{
    friendlyname = $PublisherName
    uniquename = "${PublisherPrefix}_publisher"
    customizationprefix = $PublisherPrefix
}

try {
    $publisherResponse = Invoke-RestMethod `
        -Uri "$OrgUrl/api/data/v9.2/publishers" `
        -Method Post `
        -Headers $headers `
        -Body (ConvertTo-Json $publisherDef -Compress) `
        -ErrorAction Stop
    
    $publisherId = $publisherResponse.publisherid
    Write-Host "  ✅ Publisher created: $publisherId"
} catch {
    if ($_ -match "already exists") {
        Write-Host "  ⚠️  Publisher already exists"
        # Query for existing publisher
        $publisherQuery = Invoke-RestMethod `
            -Uri "$OrgUrl/api/data/v9.2/publishers?`$filter=customizationprefix eq '$PublisherPrefix'" `
            -Method Get `
            -Headers $headers
        $publisherId = $publisherQuery.value[0].publisherid
        Write-Host "  ℹ️  Using existing: $publisherId"
    } else {
        Write-Host "  ❌ Error: $_"
        exit 1
    }
}

Write-Host ""

# ============================================================================
# STEP 2: Create Solution
# ============================================================================

Write-Host "📝 Step 2: Creating Solution..."

$solutionDef = @{
    uniquename = $SolutionUniqueName
    friendlyname = $SolutionName
    publisherid = "/publishers($publisherId)"
    version = "1.0.0.0"
}

try {
    $solutionResponse = Invoke-RestMethod `
        -Uri "$OrgUrl/api/data/v9.2/solutions" `
        -Method Post `
        -Headers $headers `
        -Body (ConvertTo-Json $solutionDef -Compress) `
        -ErrorAction Stop
    
    $solutionId = $solutionResponse.solutionid
    Write-Host "  ✅ Solution created: $solutionId"
} catch {
    if ($_ -match "already exists") {
        Write-Host "  ⚠️  Solution already exists"
        $solutionQuery = Invoke-RestMethod `
            -Uri "$OrgUrl/api/data/v9.2/solutions?`$filter=uniquename eq '$SolutionUniqueName'" `
            -Method Get `
            -Headers $headers
        $solutionId = $solutionQuery.value[0].solutionid
        Write-Host "  ℹ️  Using existing: $solutionId"
    } else {
        Write-Host "  ❌ Error: $_"
        exit 1
    }
}

Write-Host ""

# ============================================================================
# STEP 3: Create 5 Tables
# ============================================================================

Write-Host "📝 Step 3: Creating Tables..."
Write-Host ""

$tables = @(
    @{ LogicalName = "vafe_formsubmission"; DisplayName = "Form Submission"; Description = "Tracks VA Form 10-3542 submissions" },
    @{ LogicalName = "vafe_extractionresult"; DisplayName = "Extraction Result"; Description = "Stores AI-extracted data" },
    @{ LogicalName = "vafe_auditlog"; DisplayName = "Audit Log"; Description = "Compliance audit trail" },
    @{ LogicalName = "vafe_d365writeevent"; DisplayName = "D365 Write Event"; Description = "D365 sync tracking" },
    @{ LogicalName = "vafe_correctionrecord"; DisplayName = "Correction Record"; Description = "Manual correction tracking" }
)

$successCount = 0

foreach ($table in $tables) {
    Write-Host "  📋 $($table.DisplayName)..."
    
    $tableDef = @{
        LogicalName = $table.LogicalName
        DisplayName = @{ LocalizedLabels = @( @{ Label = $table.DisplayName; LanguageCode = 1033 } ) }
        PluralName = @{ LocalizedLabels = @( @{ Label = "$($table.DisplayName)s"; LanguageCode = 1033 } ) }
        Description = @{ LocalizedLabels = @( @{ Label = $table.Description; LanguageCode = 1033 } ) }
        OwnershipType = "UserOwned"
        SolutionId = "/solutions($solutionId)"
    }
    
    try {
        $tableResponse = Invoke-RestMethod `
            -Uri "$OrgUrl/api/data/v9.2/EntityDefinitions" `
            -Method Post `
            -Headers $headers `
            -Body (ConvertTo-Json $tableDef -Depth 5 -Compress) `
            -ErrorAction Stop
        
        Write-Host "      ✅ Created"
        $successCount++
    } catch {
        Write-Host "      ❌ $($_ | ConvertFrom-Json | Select-Object -ExpandProperty 'error' | Select-Object -ExpandProperty 'message')"
    }
}

Write-Host ""
Write-Host "=========================================="
Write-Host "✅ Summary: $successCount/$($tables.Count) tables created"
Write-Host "=========================================="
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Go to: https://make.powerapps.com"
Write-Host "  2. Select solution: $SolutionName"
Write-Host "  3. Add columns per PROVISIONING-RUNBOOK.md"
Write-Host ""
