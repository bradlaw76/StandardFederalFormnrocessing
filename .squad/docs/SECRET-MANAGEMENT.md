# Secret Management Guide

## Overview

The `.env.automation` file contains sensitive credentials (Azure AD Client Secret, Tenant ID, etc.) and is **intentionally removed from git history**. This guide explains how to safely manage these credentials on any machine or repository.

## Secure Credential Management Strategies

### Strategy 1: Manual Local File (Development/Testing)

**Most Secure for Local Development**

Create the `.env.automation` file ONLY on your local machine—never commit it to git.

```bash
# 1. Create .gitignore entry (already exists)
echo ".env.automation" >> .gitignore
git add .gitignore && git commit -m "Ensure .env.automation is never committed"

# 2. Create local credentials file
cat > .env.automation <<EOF
DATAVERSE_CLIENT_ID=e79834a8-4cae-43f3-aec4-69a086fc6e79
DATAVERSE_CLIENT_SECRET=YOUR_SECRET_HERE
DATAVERSE_TENANT_ID=ee2d62ae-191c-4c86-9137-474d8bbe0a54
DATAVERSE_ORG_URL=https://healthconnectcenter.crm.dynamics.com
EOF

# 3. Load in your scripts
source .env.automation  # bash
. .env.automation       # PowerShell
```

### Strategy 2: Azure Key Vault (Production/CI-CD)

**Recommended for Automated Deployments**

Store credentials in Azure Key Vault and retrieve them at runtime.

```powershell
# Connect to Azure
Connect-AzAccount

# Retrieve secrets from Key Vault
$clientId = Get-AzKeyVaultSecret -VaultName "StandardFedFormVault" -Name "dataverse-client-id" -AsPlainText
$clientSecret = Get-AzKeyVaultSecret -VaultName "StandardFedFormVault" -Name "dataverse-client-secret" -AsPlainText

# Use in scripts
$env:DATAVERSE_CLIENT_ID = $clientId
$env:DATAVERSE_CLIENT_SECRET = $clientSecret
```

### Strategy 3: GitHub Secrets (CI/CD Workflows)

**For GitHub Actions Automation**

```yaml
# .github/workflows/deploy.yml
name: Deploy Flows

on:
  push:
    branches: [main, 002-form-extraction-impl]

env:
  DATAVERSE_CLIENT_ID: ${{ secrets.DATAVERSE_CLIENT_ID }}
  DATAVERSE_CLIENT_SECRET: ${{ secrets.DATAVERSE_CLIENT_SECRET }}
  DATAVERSE_TENANT_ID: ${{ secrets.DATAVERSE_TENANT_ID }}
  DATAVERSE_ORG_URL: ${{ secrets.DATAVERSE_ORG_URL }}

jobs:
  deploy:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run provisioning script
        run: .\.squad\scripts\provision-full.ps1
```

**To add secrets to GitHub:**

```bash
# Add each secret via GitHub CLI
gh secret set DATAVERSE_CLIENT_ID --body "e79834a8-4cae-43f3-aec4-69a086fc6e79"
gh secret set DATAVERSE_CLIENT_SECRET --body "<DATAVERSE_CLIENT_SECRET>"
gh secret set DATAVERSE_TENANT_ID --body "ee2d62ae-191c-4c86-9137-474d8bbe0a54"
gh secret set DATAVERSE_ORG_URL --body "https://healthconnectcenter.crm.dynamics.com"
```

### Strategy 4: Environment-Based Configuration (Flexible)

**Create a helper script that loads credentials from multiple sources**

See `.squad/scripts/load-credentials.ps1` (included below) for a smart loader.

---

## How to Regenerate Credentials

### Option A: Azure Portal (Manual)

1. Go to **Azure Portal** → **Azure Active Directory**
2. Select **App registrations**
3. Find your app (search for the Client ID: `e79834a8-4cae-43f3-aec4-69a086fc6e79`)
4. Go to **Certificates & secrets**
5. Click **+ New client secret**
6. Copy the new secret value immediately
7. Update your `.env.automation` file or Key Vault with the new value

### Option B: PowerShell Script (Automated)

```powershell
# .squad/scripts/rotate-credentials.ps1
param(
    [string]$ClientId = "e79834a8-4cae-43f3-aec4-69a086fc6e79",
    [string]$TenantId = "ee2d62ae-191c-4c86-9137-474d8bbe0a54"
)

# Connect to Azure AD
Connect-AzureAD -TenantId $TenantId

# Get the app
$app = Get-AzureADApplication -Filter "AppId eq '$ClientId'"

# Create new credential
$credential = New-AzureADApplicationPasswordCredential -ObjectId $app.ObjectId -Value (New-Guid).Guid

Write-Host "New Client Secret: $($credential.Value)"
Write-Host "Valid from: $($credential.StartDate)"
Write-Host "Valid until: $($credential.EndDate)"
Write-Host ""
Write-Host "Update .env.automation with the secret above"
Write-Host "DATAVERSE_CLIENT_SECRET=$($credential.Value)"
```

---

## Setup Checklist for New Machine/Repository

### Step 1: Clone Repository
```bash
git clone https://github.com/bradlaw76/StandardFederalFormnrocessing.git
cd StandardFederalFormnrocessing
```

### Step 2: Verify `.env.automation` is NOT in git
```bash
git log --all --oneline -- .env.automation
# Should show no results (or only deletion commits)
```

### Step 3: Create Local `.env.automation`
```powershell
# Option A: Manually create
cat > .env.automation <<EOF
DATAVERSE_CLIENT_ID=e79834a8-4cae-43f3-aec4-69a086fc6e79
DATAVERSE_CLIENT_SECRET=[GET_FROM_VAULT_OR_PORTAL]
DATAVERSE_TENANT_ID=ee2d62ae-191c-4c86-9137-474d8bbe0a54
DATAVERSE_ORG_URL=https://healthconnectcenter.crm.dynamics.com
EOF

# Option B: Use credential loader (loads from Azure Key Vault if available)
.\.squad\scripts\load-credentials.ps1
```

### Step 4: Verify Credentials Work
```powershell
# Load credentials
. .env.automation

# Test connection to Dataverse
$tokenRequest = @{
    Method = "POST"
    Uri = "https://login.microsoftonline.com/$env:DATAVERSE_TENANT_ID/oauth2/v2.0/token"
    Body = @{
        client_id     = $env:DATAVERSE_CLIENT_ID
        client_secret = $env:DATAVERSE_CLIENT_SECRET
        scope         = "$env:DATAVERSE_ORG_URL/.default"
        grant_type    = "client_credentials"
    }
}

$token = Invoke-RestMethod @tokenRequest
Write-Host "✓ Authentication successful"
Write-Host "Token expires in: $($token.expires_in) seconds"
```

### Step 5: Run Provisioning Scripts
```powershell
.\.squad\scripts\provision-full.ps1
```

---

## Security Best Practices

| Practice | Why | How |
|----------|-----|-----|
| **Never commit secrets** | Prevents exposure in history | Use `.gitignore`, verify with `git log` |
| **Use `.gitignore`** | Prevent accidental commits | Already configured in repo |
| **Rotate credentials regularly** | Minimize exposure window | Monthly via Portal or script |
| **Use strong secrets** | Harder to brute-force | Azure AD generates cryptographically strong values |
| **Audit access** | Track who accessed secrets | Enable Azure AD audit logs |
| **Use separate credentials per environment** | Limit blast radius if one is compromised | Dev / Staging / Production credentials |
| **Store in secure vault** | Not in text files | Azure Key Vault, GitHub Secrets, 1Password, etc. |

---

## Troubleshooting

### "Secret not found" error

```powershell
# Check if .env.automation exists
Test-Path ".env.automation"

# Check if it's loaded
$env:DATAVERSE_CLIENT_SECRET

# If missing, create it manually
```

### "Authentication failed" error

```powershell
# Verify credentials are correct
Write-Host "Client ID: $env:DATAVERSE_CLIENT_ID"
Write-Host "Tenant ID: $env:DATAVERSE_TENANT_ID"
Write-Host "Org URL: $env:DATAVERSE_ORG_URL"

# If credentials are old, regenerate via Azure Portal or script
.\.squad\scripts\rotate-credentials.ps1
```

### Secret was accidentally committed

```powershell
# Run the removal script
python .\.squad\scripts\remove-secret-python.py

# Force-push cleaned history
git push origin --all --force-with-lease

# Notify team and rotate credentials immediately
```

---

## Summary

For a new machine/repository:

1. **Clone** the repo (no secrets in git ✓)
2. **Create `.env.automation`** locally using credentials from Azure Portal or Key Vault
3. **Never commit it** (`.gitignore` prevents accidents)
4. **Rotate credentials** monthly or if exposed
5. **Use vaults/secrets** for automation (CI/CD pipelines)

**Your `.env.automation` is local-only and secure by design.**
