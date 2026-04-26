# Automated Solution + Table Provisioning
# Using Microsoft.Xrm.Data.Powershell SDK

param(
    [string]$OrgUrl = "https://healthconnectcenter.crm.dynamics.com",
    [string]$SolutionName = "VAFormExtractionDemo",
    [string]$SolutionUniqueName = "VAFormExtractionDemo",
    [string]$PublisherPrefix = "vafe"
)

$ErrorActionPreference = "Stop"

Write-Host "=========================================="
Write-Host "🚀 Automated Solution + Table Provisioning"
Write-Host "=========================================="
Write-Host ""

# ============================================================================
# STEP 1: Import Module + Connect
# ============================================================================

Write-Host "📦 Step 1: Loading Microsoft.Xrm.Data.Powershell..."

try {
    Import-Module Microsoft.Xrm.Data.Powershell -Force
    Write-Host "  ✅ Module loaded"
} catch {
    Write-Host "  ❌ Failed to load module: $_"
    Write-Host "  Install: Install-Module -Name Microsoft.Xrm.Data.Powershell -Force"
    exit 1
}

Write-Host ""
Write-Host "🔐 Step 2: Connecting to $OrgUrl..."

try {
    $conn = Get-CrmConnection -InteractiveMode -OrgServiceUri $OrgUrl -MaxCrmConnectionTimeOutSeconds 300
    Write-Host "  ✅ Connected as: $($conn.ConnectedOrgFriendlyName)"
} catch {
    Write-Host "  ❌ Connection failed: $_"
    exit 1
}

Write-Host ""

# ============================================================================
# STEP 3: Create/Get Publisher
# ============================================================================

Write-Host "🏢 Step 3: Creating/Getting Publisher..."

$publisherQuery = @{
    EntityLogicalName = "publisher"
    FilterExpression = "<filter><condition attribute='customizationprefix' operator='eq' value='$PublisherPrefix'/></filter>"
}

try {
    $existingPublisher = Get-CrmRecordsByFetch -conn $conn -Fetch $publisherQuery -WarningAction SilentlyContinue
    
    if ($existingPublisher.CrmRecords.Count -gt 0) {
        $publisherId = $existingPublisher.CrmRecords[0].publisherid
        Write-Host "  ✅ Using existing publisher: $publisherId"
    } else {
        $publisherData = @{
            friendlyname = "VA Form Extraction Demo"
            uniquename = "${PublisherPrefix}_publisher"
            customizationprefix = $PublisherPrefix
        }
        
        $publisherId = New-CrmRecord -conn $conn -EntityLogicalName "publisher" -Fields $publisherData
        Write-Host "  ✅ Publisher created: $publisherId"
    }
} catch {
    Write-Host "  ❌ Error: $_"
    exit 1
}

Write-Host ""

# ============================================================================
# STEP 4: Create/Get Solution
# ============================================================================

Write-Host "📦 Step 4: Creating/Getting Solution..."

$solutionQuery = @{
    EntityLogicalName = "solution"
    FilterExpression = "<filter><condition attribute='uniquename' operator='eq' value='$SolutionUniqueName'/></filter>"
}

try {
    $existingSolution = Get-CrmRecordsByFetch -conn $conn -Fetch $solutionQuery -WarningAction SilentlyContinue
    
    if ($existingSolution.CrmRecords.Count -gt 0) {
        $solutionId = $existingSolution.CrmRecords[0].solutionid
        Write-Host "  ✅ Using existing solution: $solutionId"
    } else {
        $solutionData = @{
            uniquename = $SolutionUniqueName
            friendlyname = $SolutionName
            publisherid = @{ Value = $publisherId; LogicalName = "publisher" }
            version = "1.0.0.0"
        }
        
        $solutionId = New-CrmRecord -conn $conn -EntityLogicalName "solution" -Fields $solutionData
        Write-Host "  ✅ Solution created: $solutionId"
    }
} catch {
    Write-Host "  ❌ Error: $_"
    exit 1
}

Write-Host ""

# ============================================================================
# STEP 5: Create 5 Tables
# ============================================================================

Write-Host "📋 Step 5: Creating Tables..."
Write-Host ""

$tables = @(
    @{
        DisplayName = "Form Submission"
        LogicalName = "vafe_formsubmission"
        PluralName = "Form Submissions"
        Description = "Tracks VA Form 10-3542 submissions through extraction lifecycle"
        PrimaryAttrName = "vafe_name"
        PrimaryAttrDisplayName = "Form Submission"
    },
    @{
        DisplayName = "Extraction Result"
        LogicalName = "vafe_extractionresult"
        PluralName = "Extraction Results"
        Description = "Stores AI-extracted field data and confidence scores"
        PrimaryAttrName = "vafe_name"
        PrimaryAttrDisplayName = "Extraction Result ID"
    },
    @{
        DisplayName = "Audit Log"
        LogicalName = "vafe_auditlog"
        PluralName = "Audit Logs"
        Description = "Immutable compliance audit trail (HIPAA/VA)"
        PrimaryAttrName = "vafe_name"
        PrimaryAttrDisplayName = "Audit Log ID"
    },
    @{
        DisplayName = "D365 Write Event"
        LogicalName = "vafe_d365writeevent"
        PluralName = "D365 Write Events"
        Description = "Tracks synchronization attempts to Dynamics 365 with retry logic"
        PrimaryAttrName = "vafe_name"
        PrimaryAttrDisplayName = "Write Event ID"
    },
    @{
        DisplayName = "Correction Record"
        LogicalName = "vafe_correctionrecord"
        PluralName = "Correction Records"
        Description = "Tracks manual corrections made to low-confidence AI extractions"
        PrimaryAttrName = "vafe_name"
        PrimaryAttrDisplayName = "Correction ID"
    }
)

$successCount = 0

foreach ($table in $tables) {
    Write-Host "  📝 Creating: $($table.DisplayName)..."
    
    try {
        # Check if table already exists
        $existingTableQuery = @{
            EntityLogicalName = "entity"
            FilterExpression = "<filter><condition attribute='logicalname' operator='eq' value='$($table.LogicalName)'/></filter>"
        }
        
        $existingTable = Get-CrmRecordsByFetch -conn $conn -Fetch $existingTableQuery -WarningAction SilentlyContinue
        
        if ($existingTable.CrmRecords.Count -gt 0) {
            Write-Host "      ✅ Already exists"
            $successCount++
            continue
        }
        
        # Create new table
        $tableData = @{
            LogicalName = $table.LogicalName
            DisplayName = @{ LocalizedLabels = @( @{ Label = $table.DisplayName; LanguageCode = 1033 } ) }
            PluralName = @{ LocalizedLabels = @( @{ Label = $table.PluralName; LanguageCode = 1033 } ) }
            Description = @{ LocalizedLabels = @( @{ Label = $table.Description; LanguageCode = 1033 } ) }
            OwnershipType = "UserOwned"
            PrimaryNameAttribute = "vafe_name"
            PrimaryIdAttribute = "${($table.LogicalName)}_id"
        }
        
        # This is a simplified approach - the SDK handles the complex OData formatting
        $tableId = New-CrmRecord -conn $conn -EntityLogicalName "entity" -Fields $tableData
        
        Write-Host "      ✅ Created: $tableId"
        $successCount++
        
    } catch {
        Write-Host "      ⚠️  $($_.Exception.Message.Substring(0, 100))"
    }
}

Write-Host ""
Write-Host "=========================================="
Write-Host "✅ SUMMARY"
Write-Host "=========================================="
Write-Host "  Tables: $successCount/$($tables.Count) created/verified"
Write-Host "  Solution ID: $solutionId"
Write-Host ""

if ($successCount -gt 0) {
    Write-Host "📝 Next steps:"
    Write-Host "  1. Go to: https://make.powerapps.com"
    Write-Host "  2. Verify 5 tables in solution: $SolutionName"
    Write-Host "  3. Add columns per PROVISIONING-RUNBOOK.md"
    Write-Host ""
} else {
    Write-Host "⚠️  No tables were created. Check output above."
}
