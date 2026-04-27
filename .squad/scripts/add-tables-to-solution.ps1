# ============================================================================
# Add existing Dataverse tables into the VAFormExtractionDemo solution
# ============================================================================
# Run this if tables were created but the solution is still empty.
# Usage: .\.squad\scripts\add-tables-to-solution.ps1
# ============================================================================

param(
    [string]$OrgUrl       = "",
    [string]$SolutionName = "VAFormExtractionDemo",
    [string]$EnvFile      = ".env.automation"
)

$ErrorActionPreference = "Stop"

# Load credentials
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

Write-Host ""
Write-Host "========================================"
Write-Host "🔗 Add Tables to Solution: $SolutionName"
Write-Host "========================================"
Write-Host ""

# Get token
$tokenUri  = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
$tokenBody = @{
    grant_type    = "client_credentials"
    client_id     = $ClientId
    client_secret = $ClientSecret
    scope         = "$OrgUrl/.default"
}
$tokenResponse = Invoke-RestMethod -Uri $tokenUri -Method Post -Body $tokenBody -ContentType "application/x-www-form-urlencoded"
$token = $tokenResponse.access_token
Write-Host "✅ Token acquired"

$headers = @{
    "Authorization"     = "Bearer $token"
    "Content-Type"      = "application/json; charset=utf-8"
    "OData-MaxVersions" = "4.0"
    "OData-Version"     = "4.0"
    "Accept"            = "application/json"
}

function Invoke-DataverseApi($method, $relPath, $body = $null) {
    $uri    = "$OrgUrl/api/data/v9.2/$relPath"
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

# Get the solution's uniquename (needed for AddSolutionComponent)
Write-Host "📦 Looking up solution '$SolutionName'..."
$solQuery = Invoke-DataverseApi GET "solutions?`$filter=uniquename eq '$SolutionName'&`$select=solutionid,uniquename"
if ($solQuery.value.Count -eq 0) {
    Write-Host "❌ Solution '$SolutionName' not found. Run provision-full.ps1 first."
    exit 1
}
$solutionId = $solQuery.value[0].solutionid
Write-Host "   ✅ Solution found: $solutionId"
Write-Host ""

# Component type 1 = Entity (table)
# AddSolutionComponent action adds a component to a solution
function Add-TableToSolution($logicalName, $displayName) {
    Write-Host "   🔗 Adding $displayName to solution..."

    # Get the entity metadata ID
    try {
        $entity = Invoke-DataverseApi GET "EntityDefinitions(LogicalName='$logicalName')?`$select=MetadataId"
        $metadataId = $entity.MetadataId
    } catch {
        Write-Host "     ❌ Table not found: $logicalName"
        return
    }

    # AddSolutionComponent: ComponentType 1 = Entity
    try {
        $body = @{
            ComponentId            = $metadataId
            ComponentType          = 1        # Entity
            SolutionUniqueName     = $SolutionName
            AddRequiredComponents  = $true
            DoNotIncludeSubcomponents = $false
            IncludedComponentSettingsValues = $null
        }
        Invoke-DataverseApi POST "AddSolutionComponent" $body | Out-Null
        Write-Host "     ✅ $displayName added"
    } catch {
        Write-Host "     ⚠️  $displayName — $($_.ToString().Substring(0,[Math]::Min(120,$_.ToString().Length)))"
    }
    Start-Sleep -Milliseconds 500
}

Write-Host "📋 Adding 5 tables to solution '$SolutionName'..."
Write-Host ""

Add-TableToSolution "vafe_formsubmission"   "Form Submission"
Add-TableToSolution "vafe_extractionresult" "Extraction Result"
Add-TableToSolution "vafe_auditlog"         "Audit Log"
Add-TableToSolution "vafe_d365writeevent"   "D365 Write Event"
Add-TableToSolution "vafe_correctionrecord" "Correction Record"

Write-Host ""
Write-Host "📢 Publishing customizations..."
try {
    Invoke-DataverseApi POST "PublishAllXml" $null | Out-Null
    Write-Host "   ✅ Published"
} catch {
    Write-Host "   ⚠️  Publish: $_"
}

Write-Host ""
Write-Host "========================================"
Write-Host "✅ Done. Export the solution to verify:"
Write-Host "   pac solution export --name $SolutionName --path .\solution-export.zip --overwrite"
Write-Host ""
Write-Host "   Then verify at: https://make.powerapps.com"
Write-Host "   Environment: Contact Center → Solutions → $SolutionName"
Write-Host "========================================"
Write-Host ""
