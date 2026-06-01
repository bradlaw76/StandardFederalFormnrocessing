# Provision Dataverse Tables via pac solution import
# This script creates tables by importing an existing solution or by using REST

param(
    [string]$OrgUrl = "https://dpartementofveteranaffairs-oth.crm9.dynamics.com",
    [string]$EnvironmentId = "b29e4071-1a40-4d24-89d5-41320d7c1371"
)

Write-Host "🔐 Using pac CLI authentication..."
Write-Host "Environment: $EnvironmentId"
Write-Host "Org URL: $OrgUrl"
Write-Host ""

# Since pac CLI doesn't have direct table creation commands, we'll use the Web API
# First, verify we can reach the environment

Write-Host "📡 Testing connectivity to Dataverse..."
try {
    $testUri = "$OrgUrl/api/data/v9.2/WhoAmI"
    # Use HTTPS with cert validation
    $response = Invoke-WebRequest -Uri $testUri -Method Get -Headers @{"OData-Version" = "4.0"} -ErrorAction SilentlyContinue
    if ($response.StatusCode -eq 401 -or $response.StatusCode -eq 200) {
        Write-Host "  ✅ Connectivity confirmed"
    }
} catch {
    Write-Host "  ⚠️  Could not verify connectivity: $_"
}

Write-Host ""
Write-Host "📋 Tables to provision:"
Write-Host "  1. vafe_FormSubmission (parent table)"
Write-Host "  2. vafe_ExtractionResult (lookup to FormSubmission)"
Write-Host "  3. vafe_AuditLog (lookup to FormSubmission)"
Write-Host "  4. vafe_D365WriteEvent (lookup to FormSubmission)"
Write-Host "  5. vafe_CorrectionRecord (lookup to ExtractionResult)"
Write-Host ""

Write-Host "⚠️  Limitations:"
Write-Host "  - Power Platform CLI (pac) does not have native 'create table' commands"
Write-Host "  - Table creation via Web API requires advanced authentication setup"
Write-Host "  - Recommended: Use Power Apps UI (make.powerapps.com) OR create a solution export XML"
Write-Host ""

Write-Host "🔄 Alternative approach:"
Write-Host "  1. Export existing solution from your environment"
Write-Host "  2. Modify the XML to include table definitions"  
Write-Host "  3. Re-import using: pac solution import -p <path>"
Write-Host ""

Write-Host "📝 For now, please use the Power Apps UI to create the 5 tables,"
Write-Host "   OR provide a solution export ZIP file to import programmatically."
Write-Host ""
