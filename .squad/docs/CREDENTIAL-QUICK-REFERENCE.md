# Credential Management - Quick Reference Card

> **Print this** or bookmark it for easy access during setup and operations.

---

## 🚀 Quick Start (5 minutes)

```powershell
# Step 1: Clone repository (no secrets in history)
git clone https://github.com/bradlaw76/StandardFederalFormnrocessing.git
cd StandardFederalFormnrocessing

# Step 2: Load credentials from your source
.\.squad\scripts\load-credentials.ps1

# Step 3: Run provisioning
.\.squad\scripts\provision-full.ps1

# Done! Environment is ready
```

---

## 📍 Where Are the Files?

| Purpose | Location |
|---------|----------|
| **Credential Loader** | `.squad/scripts/load-credentials.ps1` |
| **Rotate Secrets** | `.squad/scripts/rotate-credentials.ps1` |
| **Full Setup Guide** | `.squad/docs/SECRET-MANAGEMENT.md` |
| **New Machine Checklist** | `.squad/docs/NEW-MACHINE-SETUP-CHECKLIST.md` |
| **AI Model Registration** | `.squad/scripts/provision-full.ps1` |
| **Power Automate Flows** | `.squad/generated/flow-build-kit/` |

---

## 🔐 Credential Sources (Pick One)

### Local File (Development)
```powershell
# Create .env.automation in repo root
DATAVERSE_CLIENT_ID=e79834a8-4cae-43f3-aec4-69a086fc6e79
DATAVERSE_CLIENT_SECRET=<from_admin>
DATAVERSE_TENANT_ID=ee2d62ae-191c-4c86-9137-474d8bbe0a54
DATAVERSE_ORG_URL=https://healthconnectcenter.crm.dynamics.com
```

### Azure Key Vault (Production)
```powershell
# Store in vault
Set-AzKeyVaultSecret -VaultName "StandardFedFormVault" `
  -Name "dataverse-client-secret" -SecretValue $secret

# Load in script
.\.squad\scripts\load-credentials.ps1 -VaultName "StandardFedFormVault"
```

### GitHub Secrets (CI/CD)
```yaml
# GitHub Actions workflow
env:
  DATAVERSE_CLIENT_ID: ${{ secrets.DATAVERSE_CLIENT_ID }}
  DATAVERSE_CLIENT_SECRET: ${{ secrets.DATAVERSE_CLIENT_SECRET }}
  DATAVERSE_TENANT_ID: ${{ secrets.DATAVERSE_TENANT_ID }}
  DATAVERSE_ORG_URL: ${{ secrets.DATAVERSE_ORG_URL }}
```

---

## 🔄 Annual Tasks

### Rotate Credentials (Every 12 months)
```powershell
.\.squad\scripts\rotate-credentials.ps1
# Saves new secret (copy immediately - won't show again)
# Update: .env.automation, GitHub Secrets, Key Vault
# Restart: All running applications
```

### Update Old Machines
1. Get new secret from administrator
2. Update local `.env.automation` file
3. Reload credentials: `.\.squad\scripts\load-credentials.ps1`
4. Restart provision script if needed

---

## ✅ Verification Checklist

### Before Setup
```powershell
# No secrets in git history
git log --all --oneline -- .env.automation
# Should return: [nothing]

# Secret not currently tracked
git status -- .env.automation
# Should return: [nothing]
```

### After Setup
```powershell
# Verify credentials loaded
Write-Host $env:DATAVERSE_CLIENT_ID
# Should show: e79834a8-4cae-43f3-aec4-69a086fc6e79

Write-Host $env:DATAVERSE_ORG_URL
# Should show: https://healthconnectcenter.crm.dynamics.com
```

---

## 🆘 Common Issues & Fixes

| Issue | Command | Fix |
|-------|---------|-----|
| **"File not found"** | `ls .env.automation` | Run `.squad\scripts\load-credentials.ps1` and save to file |
| **"Secrets missing"** | `.\.squad\scripts\load-credentials.ps1 -ShowSecrets` | Check each source (local, Key Vault, GitHub) |
| **"Can't authenticate"** | `Connect-AzAccount` | Authenticate to Azure first |
| **"Permission denied"** | `Unblock-File .\.squad\scripts\*.ps1` | Unblock downloaded scripts |
| **"Old credentials used"** | `$env:DATAVERSE_CLIENT_SECRET` | Reload credentials in new PowerShell window |

---

## 📊 Credential Lifecycle

```
Created (Day 1)
    ↓
Active & Usable (Months 1-11)
    ↓
Near Expiration (Month 12)
    ↓ [Run rotate-credentials.ps1]
    ↓
New Secret Created ← Store Immediately
    ↓
Rotate All Applications (within 24 hours)
    ↓
Old Secret Expires (Days 1-7 grace period)
    ↓
Verification Complete
```

---

## 🔗 When to Use Each Strategy

| When | Strategy | Why |
|------|----------|-----|
| **Development** | Local `.env.automation` | Fastest, no dependencies |
| **Production** | Azure Key Vault | Secure, rotatable, no git storage |
| **CI/CD** | GitHub Secrets | Automatic injection, environment-based |
| **Multiple Machines** | Key Vault | Centralized, no duplication |
| **Emergency** | Manual entry (load-credentials.ps1) | Works without any setup |

---

## 💾 File Locations (Always Safe)

```
✓ SAFE - Not in git:
  • .env.automation (local file)
  • Azure Key Vault (cloud storage)
  • GitHub Secrets (cloud storage)

✗ NEVER in git:
  • Client secrets
  • Credentials
  • API keys
  • Connection strings
```

---

## 📋 Standard Setup Flow

```
1. Clone repo
   ↓
2. Choose credential strategy (A/B/C)
   ↓
3. Get credentials from administrator
   ↓
4. Run load-credentials.ps1
   ↓
5. Run provision-full.ps1
   ↓
6. Create Power Automate flows
   ↓
7. Test end-to-end
   ↓
8. Document setup date & rotation schedule
```

---

## 🔔 Important Reminders

⚠️ **NEVER:**
- Commit `.env.automation` to git
- Share Client Secret via email
- Paste secret in chat/docs (except temporary in conversation)
- Hardcode credentials in code

✅ **ALWAYS:**
- Keep credentials in one of 3 approved locations
- Rotate annually
- Use .gitignore to protect local files
- Log who has credentials (admin records)
- Verify credentials aren't exposed in git history

---

## 📞 Need Help?

1. **Setup questions:** See `.squad/docs/NEW-MACHINE-SETUP-CHECKLIST.md`
2. **Credential strategies:** See `.squad/docs/SECRET-MANAGEMENT.md`
3. **Rotation procedures:** Run `.\.squad\scripts\rotate-credentials.ps1 -Help`
4. **Loading issues:** Run `.\.squad\scripts\load-credentials.ps1 -ShowSecrets`

---

**Last Updated:** 2026-04-29  
**Valid for:** All new machine setups and credential rotations
