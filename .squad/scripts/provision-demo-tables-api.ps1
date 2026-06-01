# REST API Table Provisioning for Demo Environment
# Uses Azure CLI token generation + Dataverse Web API

param(
    [string]$OrgUrl = "https://healthconnectcenter.crm.dynamics.com",
    [string]$EnvironmentId = "3516f962-1f59-e81b-8df1-5b52add15d0d",
    [string]$SolutionName = "VAFormExtractionDemo",
    [string]$Tenant = "d365demotsce80677168.onmicrosoft.com"
)

$ErrorActionPreference = "Stop"

Write-Host "=========================================="
Write-Host "🚀 Provisioning Tables via Web API"
Write-Host "=========================================="
Write-Host ""
Write-Host "Target: $OrgUrl"
Write-Host "Solution: $SolutionName"
Write-Host ""

# ============================================================================
# STEP 1: Get Token via Azure CLI
# ============================================================================

Write-Host "🔐 Step 1: Acquiring auth token via Azure CLI..."
Write-Host ""

try {
    # Get token for Dataverse scope
    $tokenOutput = az account get-access-token `
        --resource "https://healthconnectcenter.crm.dynamics.com" `
        --scope "admin_api" 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ⚠️  Azure CLI token failed. Trying alternative scope..."
        $tokenOutput = az account get-access-token `
            --resource "https://org.crm.dynamics.com" 2>&1
    }
    
    $tokenData = $tokenOutput | ConvertFrom-Json
    $accessToken = $tokenData.accessToken
    
    if ($accessToken) {
        Write-Host "  ✅ Token acquired: $(${accessToken}.Substring(0,20))..."
    } else {
        throw "Failed to get access token"
    }
} catch {
    Write-Host "  ❌ Failed: $_"
    Write-Host ""
    Write-Host "  📋 Prerequisites:"
    Write-Host "     1. Install Azure CLI: https://aka.ms/azcli"
    Write-Host "     2. Login: az login"
    Write-Host "     3. Ensure your account has Power Platform admin role"
    Write-Host ""
    exit 1
}

Write-Host ""

# ============================================================================
# STEP 2: Create Tables via Web API
# ============================================================================

Write-Host "📋 Step 2: Creating tables in Dataverse..."
Write-Host ""

$headers = @{
    "Authorization" = "Bearer $accessToken"
    "Content-Type" = "application/json; charset=utf-8"
    "OData-MaxVersions" = "4.0"
    "OData-Version" = "4.0"
}

# Define all 5 tables
$tables = @(
    @{
        Name = "vafe_FormSubmission"
        DisplayName = "Form Submission"
        PluralName = "Form Submissions"
        Description = "Tracks VA Form 10-3542 submissions through extraction lifecycle"
    },
    @{
        Name = "vafe_ExtractionResult"
        DisplayName = "Extraction Result"
        PluralName = "Extraction Results"
        Description = "Stores AI-extracted field data and confidence scores"
    },
    @{
        Name = "vafe_AuditLog"
        DisplayName = "Audit Log"
        PluralName = "Audit Logs"
        Description = "Immutable compliance audit trail (HIPAA/VA)"
    },
    @{
        Name = "vafe_D365WriteEvent"
        DisplayName = "D365 Write Event"
        PluralName = "D365 Write Events"
        Description = "Tracks synchronization attempts to Dynamics 365"
    },
    @{
        Name = "vafe_CorrectionRecord"
        DisplayName = "Correction Record"
        PluralName = "Correction Records"
        Description = "Tracks manual corrections to low-confidence AI extractions"
    }
)

$successCount = 0
$skipCount = 0
$errorCount = 0

foreach ($table in $tables) {
    Write-Host "  📝 Creating: $($table.DisplayName)..."
    
    # Minimal OData payload - only required properties
    $tableDefinition = @{
        Name = $table.Name
        DisplayName = @{ 
            LocalizedLabels = @( @{ 
                Label = $table.DisplayName
                LanguageCode = 1033 
            } ) 
        }
        PluralName = @{ 
            LocalizedLabels = @( @{ 
                Label = $table.PluralName
                LanguageCode = 1033 
            } ) 
        }
        Description = @{ 
            LocalizedLabels = @( @{ 
                Label = $table.Description
                LanguageCode = 1033 
            } ) 
        }
        OwnershipType = $table.OwnershipType
    }
    
    try {
        $uri = "$OrgUrl/api/data/v9.2/EntityDefinitions"
        $body = ConvertTo-Json $tableDefinition -Depth 10 -Compress
        
        Write-Host "      📤 Sending request..."
        $response = Invoke-RestMethod -Uri $uri `
            -Method Post `
            -Headers $headers `
            -Body $body `
            -ErrorAction Stop
        
        Write-Host "      ✅ Created: $($response.MetadataId)"
        $successCount++
    } catch {
        $errorMsg = $_.Exception.Message
        
        # Check for specific errors
        if ($errorMsg -match "already exists" -or $errorMsg -match "409") {
            Write-Host "      ⚠️  Already exists (skipped)"
            $skipCount++
        } elseif ($errorMsg -match "401" -or $errorMsg -match "Unauthorized") {
            Write-Host "      ❌ Authorization error: Check token validity"
            $errorCount++
        } else {
            # Print shorter error for readability
            $shortError = $errorMsg.Substring(0, [Math]::Min(120, $errorMsg.Length))
            Write-Host "      ❌ $shortError"
            $errorCount++
        }
    }
    
    Start-Sleep -Milliseconds 500
}

Write-Host ""
Write-Host "=========================================="
Write-Host "✅ PROVISIONING SUMMARY"
Write-Host "=========================================="
Write-Host "  Created: $successCount"
Write-Host "  Skipped: $skipCount"
Write-Host "  Errors: $errorCount"
Write-Host ""

if ($successCount -gt 0 -or $skipCount -gt 0) {
    Write-Host "✅ Tables provisioned successfully!"
    Write-Host ""
    Write-Host "📝 Next Steps:"
    Write-Host "  1. Go to: https://make.powerapps.com/environments/$EnvironmentId"
    Write-Host "  2. Select solution: $SolutionName"
    Write-Host "  3. Add columns to each table (per PROVISIONING-RUNBOOK.md)"
    Write-Host "  4. Create relationships between tables"
    Write-Host "  5. Configure business rules"
    Write-Host ""
} else {
    Write-Host "❌ No tables created. Check credentials and try again."
}

Write-Host ""
