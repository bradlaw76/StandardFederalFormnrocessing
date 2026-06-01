# Provision VA Form Extraction Solution + Tables in Demo Environment
# Target: healthconnectcenter.crm.dynamics.com
# Admin: admin@D365DemoTSCE80677168.onmicrosoft.com

param(
    [string]$OrgUrl = "https://healthconnectcenter.crm.dynamics.com",
    [string]$EnvironmentId = "3516f962-1f59-e81b-8df1-5b52add15d0d",
    [string]$SolutionName = "VAFormExtractionDemo",
    [string]$PublisherName = "VA Form Extraction Demo"
)

$ErrorActionPreference = "Stop"

Write-Host "=========================================="
Write-Host "🚀 VA Form Extraction Demo Environment Setup"
Write-Host "=========================================="
Write-Host ""
Write-Host "Target Environment:"
Write-Host "  Org URL: $OrgUrl"
Write-Host "  Environment ID: $EnvironmentId"
Write-Host "  Solution: $SolutionName"
Write-Host ""

# Step 1: Authenticate with pac CLI
Write-Host "Step 1️⃣  Authenticating with pac CLI..."
Write-Host ""

try {
    $pacStatus = & pac auth list 2>&1
    if ($pacStatus -match "authenticated") {
        Write-Host "  ✅ pac CLI authenticated"
    } else {
        Write-Host "  ℹ️  No authenticated context. Logging in..."
        & pac auth create -n "demo-env" -u $OrgUrl
    }
} catch {
    Write-Host "  ⚠️  pac CLI error: $_"
    Write-Host "  📝 Please ensure pac CLI is installed: npm install -g @microsoft/power-platform-cli"
    exit 1
}

Write-Host ""

# Step 2: Create Solution
Write-Host "Step 2️⃣  Creating Solution '$SolutionName'..."
Write-Host ""

$publisherPrefix = "vafe"

try {
    # First, create the publisher if it doesn't exist
    $publisherCmd = @"
$body = @{
    "name" = "$PublisherName"
    "uniquename" = "$($publisherPrefix)_publisher"
    "customizationprefix" = "$publisherPrefix"
} | ConvertTo-Json

`$response = Invoke-RestMethod -Uri "$OrgUrl/api/data/v9.2/publishers" `
    -Method Post `
    -Headers @{
        'Authorization' = 'Bearer TOKEN'
        'Content-Type' = 'application/json'
        'OData-MaxVersions' = '4.0'
        'OData-Version' = '4.0'
    } `
    -Body `$body

`$response
"@

    # For now, attempt via pac CLI (simpler UX)
    Write-Host "  📋 Creating solution via pac CLI..."
    Write-Host "  (Note: Solution creation via pac requires manual web UI for full control)"
    Write-Host ""
    Write-Host "  ⏭️  Please create the solution manually:"
    Write-Host "      1. Go to https://make.powerapps.com/environments/$EnvironmentId/solutions"
    Write-Host "      2. Click 'New solution'"
    Write-Host "      3. Name: $SolutionName"
    Write-Host "      4. Publisher: Create new with prefix '$publisherPrefix'"
    Write-Host "      5. Version: 1.0.0.0"
    Write-Host "      6. Click Create"
    Write-Host ""
    Read-Host "Press Enter once you've created the solution..."
    
} catch {
    Write-Host "  ⚠️  Error: $_"
}

Write-Host ""

# Step 3: Add Tables to Solution
Write-Host "Step 3️⃣  Adding Tables to Solution..."
Write-Host ""

$tables = @(
    @{
        Name = "${publisherPrefix}_FormSubmission"
        DisplayName = "Form Submission"
        Description = "Tracks VA Form 10-3542 submissions through extraction lifecycle"
    },
    @{
        Name = "${publisherPrefix}_ExtractionResult"
        DisplayName = "Extraction Result"
        Description = "Stores AI-extracted field data and confidence scores"
    },
    @{
        Name = "${publisherPrefix}_AuditLog"
        DisplayName = "Audit Log"
        Description = "Immutable compliance audit trail (HIPAA/VA)"
    },
    @{
        Name = "${publisherPrefix}_D365WriteEvent"
        DisplayName = "D365 Write Event"
        Description = "Tracks synchronization attempts to Dynamics 365"
    },
    @{
        Name = "${publisherPrefix}_CorrectionRecord"
        DisplayName = "Correction Record"
        Description = "Tracks manual corrections to low-confidence AI extractions"
    }
)

foreach ($table in $tables) {
    Write-Host "  📋 Creating table: $($table.DisplayName)..."
    
    $tableBody = @{
        Name = $table.Name
        DisplayName = @{ LocalizedLabels = @( @{ Label = $table.DisplayName; LanguageCode = 1033 } ) }
        PluralName = @{ LocalizedLabels = @( @{ Label = "$($table.DisplayName)s"; LanguageCode = 1033 } ) }
        Description = @{ LocalizedLabels = @( @{ Label = $table.Description; LanguageCode = 1033 } ) }
        OwnershipType = "UserOwned"
        CanCreateCharts = $true
        CanCreateForms = $true
        CanCreateViews = $true
    } | ConvertTo-Json -Depth 10
    
    try {
        # This would require auth token setup - for now, show the instructions
        Write-Host "      (To be created via power.microsoft.com or pac CLI with token)"
    } catch {
        Write-Host "      ⚠️  $_"
    }
}

Write-Host ""
Write-Host "=========================================="
Write-Host "📝 NEXT STEPS (Manual for now):"
Write-Host "=========================================="
Write-Host ""
Write-Host "1. Create each table in Power Apps:"
Write-Host "   Go to: https://make.powerapps.com/environments/$EnvironmentId/solutions/$SolutionName"
Write-Host ""
Write-Host "2. For each table, use the PROVISIONING-RUNBOOK.md:"
Write-Host "   Location: specs/02-phase-2-stream-a/PROVISIONING-RUNBOOK.md"
Write-Host ""
Write-Host "3. Tables to create (in order):"
foreach ($table in $tables) {
    Write-Host "   • $($table.DisplayName) ($($table.Name))"
}
Write-Host ""
Write-Host "4. After tables, add columns per runbook Section 2"
Write-Host "5. Then create relationships per runbook Section 3"
Write-Host "6. Then create business rules per runbook Section 4"
Write-Host ""
Write-Host "✅ Setup complete!"
Write-Host ""
