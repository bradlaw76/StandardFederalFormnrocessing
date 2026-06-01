#!/usr/bin/env pwsh
<#
.SYNOPSIS
Intelligently load Dataverse credentials from multiple sources
.DESCRIPTION
Attempts to load credentials in this priority order:
1. Local .env.automation file
2. Azure Key Vault (if authenticated)
3. GitHub Secrets (if in GitHub Actions)
4. Prompt user to enter manually

.EXAMPLE
. .\.squad\scripts\load-credentials.ps1
#>

param(
    [string]$VaultName = "StandardFedFormVault",
    [string]$EnvFile = ".env.automation",
    [switch]$ShowSecrets = $false
)

$ErrorActionPreference = "Continue"

Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Dataverse Credential Loader" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$credentials = @{
    ClientId      = $null
    ClientSecret  = $null
    TenantId      = $null
    OrgUrl        = $null
}

# Strategy 1: Local .env.automation file
Write-Host "📋 Attempting to load from local $EnvFile..." -ForegroundColor Yellow
if (Test-Path $EnvFile) {
    Write-Host "   ✓ Found $EnvFile" -ForegroundColor Green
    
    try {
        $content = Get-Content $EnvFile -Raw
        $lines = $content -split "`n"
        
        foreach ($line in $lines) {
            if ($line -match "^DATAVERSE_CLIENT_ID=(.+)$") {
                $credentials.ClientId = $matches[1]
            }
            elseif ($line -match "^DATAVERSE_CLIENT_SECRET=(.+)$") {
                $credentials.ClientSecret = $matches[1]
            }
            elseif ($line -match "^DATAVERSE_TENANT_ID=(.+)$") {
                $credentials.TenantId = $matches[1]
            }
            elseif ($line -match "^DATAVERSE_ORG_URL=(.+)$") {
                $credentials.OrgUrl = $matches[1]
            }
        }
        
        if ($credentials.ClientId -and $credentials.ClientSecret -and $credentials.TenantId -and $credentials.OrgUrl) {
            Write-Host "   ✓ Loaded all credentials from $EnvFile" -ForegroundColor Green
            Write-Host ""
        }
        else {
            Write-Host "   ⚠️  Incomplete credentials in $EnvFile" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "   ❌ Error reading $EnvFile : $_" -ForegroundColor Red
    }
}
else {
    Write-Host "   ℹ️  $EnvFile not found" -ForegroundColor Gray
}

# Strategy 2: Azure Key Vault
if (-not ($credentials.ClientSecret -and $credentials.ClientId)) {
    Write-Host "🔐 Attempting to load from Azure Key Vault '$VaultName'..." -ForegroundColor Yellow
    
    try {
        $azAccount = Get-AzContext -ErrorAction SilentlyContinue
        
        if ($azAccount) {
            Write-Host "   ✓ Azure authenticated as $($azAccount.Account.Id)" -ForegroundColor Green
            
            $kvSecrets = @(
                @{ Name = "dataverse-client-id"; VarName = "ClientId" }
                @{ Name = "dataverse-client-secret"; VarName = "ClientSecret" }
                @{ Name = "dataverse-tenant-id"; VarName = "TenantId" }
                @{ Name = "dataverse-org-url"; VarName = "OrgUrl" }
            )
            
            foreach ($secret in $kvSecrets) {
                try {
                    $value = Get-AzKeyVaultSecret -VaultName $VaultName -Name $secret.Name -AsPlainText -ErrorAction Stop
                    $credentials[$secret.VarName] = $value
                    Write-Host "   ✓ Loaded $($secret.Name)" -ForegroundColor Green
                }
                catch {
                    Write-Host "   ⚠️  Secret not found: $($secret.Name)" -ForegroundColor Yellow
                }
            }
            
            Write-Host ""
        }
        else {
            Write-Host "   ℹ️  Not authenticated to Azure" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "   ⚠️  Azure Key Vault unavailable: $_" -ForegroundColor Yellow
    }
}

# Strategy 3: GitHub Secrets (via environment variables in Actions)
if (-not ($credentials.ClientSecret -and $credentials.ClientId)) {
    Write-Host "🐙 Checking for GitHub Secrets (via environment variables)..." -ForegroundColor Yellow
    
    $ghSecrets = @(
        @{ Env = "DATAVERSE_CLIENT_ID"; VarName = "ClientId" }
        @{ Env = "DATAVERSE_CLIENT_SECRET"; VarName = "ClientSecret" }
        @{ Env = "DATAVERSE_TENANT_ID"; VarName = "TenantId" }
        @{ Env = "DATAVERSE_ORG_URL"; VarName = "OrgUrl" }
    )
    
    $foundAny = $false
    foreach ($secret in $ghSecrets) {
        $value = [System.Environment]::GetEnvironmentVariable($secret.Env)
        if ($value) {
            $credentials[$secret.VarName] = $value
            Write-Host "   ✓ Loaded $($secret.Env) from environment" -ForegroundColor Green
            $foundAny = $true
        }
    }
    
    if ($foundAny) {
        Write-Host ""
    }
    else {
        Write-Host "   ℹ️  No GitHub Secrets found in environment" -ForegroundColor Gray
    }
}

# Strategy 4: Manual entry
if (-not ($credentials.ClientSecret -and $credentials.ClientId)) {
    Write-Host "⌨️  Prompting for manual credential entry..." -ForegroundColor Yellow
    Write-Host ""
    
    $credentials.ClientId = Read-Host "Enter DATAVERSE_CLIENT_ID"
    $credentials.TenantId = Read-Host "Enter DATAVERSE_TENANT_ID"
    $credentials.OrgUrl = Read-Host "Enter DATAVERSE_ORG_URL"
    $credentials.ClientSecret = Read-Host "Enter DATAVERSE_CLIENT_SECRET" -AsSecureString | ConvertFrom-SecureString -AsPlainText
    
    Write-Host ""
}

# Set environment variables
Write-Host "🔧 Setting environment variables..." -ForegroundColor Yellow
$env:DATAVERSE_CLIENT_ID = $credentials.ClientId
$env:DATAVERSE_CLIENT_SECRET = $credentials.ClientSecret
$env:DATAVERSE_TENANT_ID = $credentials.TenantId
$env:DATAVERSE_ORG_URL = $credentials.OrgUrl

# Optional: Save to local file
if (-not (Test-Path $EnvFile)) {
    $saveToFile = Read-Host "Save credentials to local $EnvFile? (y/n)" 
    
    if ($saveToFile -eq "y") {
        $envContent = @"
DATAVERSE_CLIENT_ID=$($credentials.ClientId)
DATAVERSE_CLIENT_SECRET=$($credentials.ClientSecret)
DATAVERSE_TENANT_ID=$($credentials.TenantId)
DATAVERSE_ORG_URL=$($credentials.OrgUrl)
"@
        
        $envContent | Out-File $EnvFile -Encoding UTF8
        Write-Host "✓ Saved to $EnvFile" -ForegroundColor Green
        
        # Verify .gitignore entry
        if (-not (Select-String "\.env\.automation" .gitignore -ErrorAction SilentlyContinue)) {
            Add-Content .gitignore ".env.automation"
            Write-Host "✓ Added .env.automation to .gitignore" -ForegroundColor Green
        }
    }
}

# Summary
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "✅ Credentials Loaded" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan

if ($ShowSecrets) {
    Write-Host "Client ID:    $($credentials.ClientId)"
    Write-Host "Client Secret: $($credentials.ClientSecret)"
    Write-Host "Tenant ID:    $($credentials.TenantId)"
    Write-Host "Org URL:      $($credentials.OrgUrl)"
}
else {
    Write-Host "Client ID:    $($credentials.ClientId.Substring(0, 8))****"
    Write-Host "Tenant ID:    $($credentials.TenantId.Substring(0, 8))****"
    Write-Host "Org URL:      $($credentials.OrgUrl)"
}

Write-Host ""
Write-Host "Ready for provisioning!" -ForegroundColor Green
