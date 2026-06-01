#!/usr/bin/env pwsh
<#
.SYNOPSIS
Regenerate Dataverse credentials programmatically
.DESCRIPTION
Creates a new client secret in Azure AD and outputs the new credentials.
Requires Azure PowerShell and permissions to manage App Registrations.

.PARAMETER ClientId
The Azure AD Application (Client) ID - defaults to the standard value

.PARAMETER TenantId
The Azure AD Tenant ID - defaults to the standard value

.EXAMPLE
.\.squad\scripts\rotate-credentials.ps1
# Prompts for confirmation, then creates new secret

.EXAMPLE
.\.squad\scripts\rotate-credentials.ps1 -Confirm:$false
# Skips confirmation, rotates immediately
#>

param(
    [string]$ClientId = "e79834a8-4cae-43f3-aec4-69a086fc6e79",
    [string]$TenantId = "ee2d62ae-191c-4c86-9137-474d8bbe0a54",
    [int]$ExpirationMonths = 12
)

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Dataverse Credential Rotation" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Verify Azure PowerShell is installed
Write-Host "🔍 Checking Azure PowerShell..." -ForegroundColor Yellow
try {
    $azModule = Get-Module -Name "Az.Accounts" -ListAvailable -ErrorAction Stop
    Write-Host "✓ Azure PowerShell installed (v$($azModule.Version))" -ForegroundColor Green
}
catch {
    Write-Host "❌ Azure PowerShell not found. Install with:" -ForegroundColor Red
    Write-Host "   Install-Module -Name Az -Scope CurrentUser -Force" -ForegroundColor Yellow
    exit 1
}

# Connect to Azure
Write-Host ""
Write-Host "🔐 Authenticating to Azure..." -ForegroundColor Yellow
try {
    $context = Get-AzContext -ErrorAction SilentlyContinue
    
    if (-not $context) {
        Connect-AzAccount -Tenant $TenantId | Out-Null
        $context = Get-AzContext
    }
    
    Write-Host "✓ Authenticated as $($context.Account.Id)" -ForegroundColor Green
    Write-Host "  Tenant: $($context.Tenant.Id)" -ForegroundColor Gray
}
catch {
    Write-Host "❌ Failed to authenticate: $_" -ForegroundColor Red
    exit 1
}

# Get the application
Write-Host ""
Write-Host "📱 Looking up application..." -ForegroundColor Yellow
try {
    $app = Get-AzADApplication -ApplicationId $ClientId -ErrorAction Stop
    Write-Host "✓ Found: $($app.DisplayName)" -ForegroundColor Green
    Write-Host "  Application ID: $($app.AppId)" -ForegroundColor Gray
}
catch {
    Write-Host "❌ Application not found with ID: $ClientId" -ForegroundColor Red
    Write-Host "   Verify the Client ID is correct" -ForegroundColor Yellow
    exit 1
}

# Show current secrets
Write-Host ""
Write-Host "🔓 Current credentials:" -ForegroundColor Yellow
$currentSecrets = Get-AzADAppCredential -ApplicationId $ClientId
if ($currentSecrets) {
    foreach ($secret in $currentSecrets) {
        $remaining = ([DateTime]$secret.EndDate - (Get-Date)).Days
        $status = if ($remaining -lt 0) { "EXPIRED" } elseif ($remaining -lt 30) { "⚠️  EXPIRING SOON" } else { "✓ Active" }
        Write-Host "  • $($secret.DisplayName ?? 'Default'): $status ($remaining days)" -ForegroundColor Gray
    }
}

# Confirm rotation
Write-Host ""
Write-Host "⚠️  This will create a NEW client secret." -ForegroundColor Yellow
Write-Host "   Applications using the OLD secret must be updated." -ForegroundColor Yellow
$confirm = Read-Host "Continue with credential rotation? (type 'yes' to confirm)"

if ($confirm -ne "yes") {
    Write-Host "❌ Rotation cancelled" -ForegroundColor Red
    exit 0
}

# Create new secret
Write-Host ""
Write-Host "🔄 Creating new client secret..." -ForegroundColor Yellow
try {
    $expirationDate = (Get-Date).AddMonths($ExpirationMonths)
    $secretName = "Rotated-$(Get-Date -Format 'yyyy-MM-dd-HHmm')"
    
    $newCredential = New-AzADAppCredential `
        -ApplicationId $ClientId `
        -DisplayName $secretName `
        -EndDate $expirationDate `
        -ErrorAction Stop
    
    Write-Host "✓ New secret created" -ForegroundColor Green
    Write-Host "  Display Name: $secretName" -ForegroundColor Gray
    Write-Host "  Expires: $($expirationDate.ToString('yyyy-MM-dd'))" -ForegroundColor Gray
}
catch {
    Write-Host "❌ Failed to create credential: $_" -ForegroundColor Red
    exit 1
}

# Output new credentials
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  🎉 NEW CREDENTIALS" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "⚠️  COPY THESE VALUES IMMEDIATELY - You will not see the secret again!" -ForegroundColor Red
Write-Host ""
Write-Host "Update your .env.automation file:" -ForegroundColor Cyan
Write-Host ""
Write-Host "DATAVERSE_CLIENT_ID=$ClientId" -ForegroundColor White
Write-Host "DATAVERSE_CLIENT_SECRET=$($newCredential.SecretText)" -ForegroundColor White
Write-Host "DATAVERSE_TENANT_ID=$TenantId" -ForegroundColor White
Write-Host "DATAVERSE_ORG_URL=https://healthconnectcenter.crm.dynamics.com" -ForegroundColor White
Write-Host ""
Write-Host "Or store in Azure Key Vault:" -ForegroundColor Cyan
Write-Host ""
Write-Host "Set-AzKeyVaultSecret -VaultName 'StandardFedFormVault' ``" -ForegroundColor Gray
Write-Host "  -Name 'dataverse-client-secret' ``" -ForegroundColor Gray
Write-Host "  -SecretValue ('$($newCredential.SecretText)' | ConvertTo-SecureString -AsPlainText -Force)" -ForegroundColor Gray
Write-Host ""

# Cleanup old secrets (optional)
Write-Host "🧹 Old credentials:" -ForegroundColor Yellow
$allSecrets = Get-AzADAppCredential -ApplicationId $ClientId
$oldCount = ($allSecrets | Where-Object { $_.EndDate -lt (Get-Date).AddDays(1) }).Count
Write-Host "  $($allSecrets.Count) total | $oldCount expired" -ForegroundColor Gray

if ($oldCount -gt 0) {
    $removeOld = Read-Host "Remove expired credentials? (y/n)"
    if ($removeOld -eq "y") {
        $allSecrets | Where-Object { $_.EndDate -lt (Get-Date) } | ForEach-Object {
            Remove-AzADAppCredential -ApplicationId $ClientId -KeyId $_.KeyId -Force -ErrorAction SilentlyContinue
            Write-Host "  ✓ Removed expired credential" -ForegroundColor Green
        }
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "✅ Credential rotation complete" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Update .env.automation with the new secret" -ForegroundColor White
Write-Host "2. Update any CI/CD secrets (GitHub, Azure DevOps, etc.)" -ForegroundColor White
Write-Host "3. Restart running applications to use the new credential" -ForegroundColor White
Write-Host "4. Verify all services connect successfully" -ForegroundColor White
