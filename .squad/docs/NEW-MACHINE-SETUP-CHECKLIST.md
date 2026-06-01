# New Machine/Repository Setup Checklist

Use this checklist when setting up the VA Form extraction automation on a new machine or in a new repository.

---

## ✅ Pre-Setup Verification

- [ ] Verify repository has NO secrets in git history
  ```powershell
  git log --all --oneline -- .env.automation
  # Should return nothing (no results)
  ```

- [ ] Clone repository if not already present
  ```powershell
  git clone https://github.com/bradlaw76/StandardFederalFormnrocessing.git
  cd StandardFederalFormnrocessing
  git checkout 002-form-extraction-impl
  ```

- [ ] Verify `.env.automation` is NOT tracked
  ```powershell
  git status -- .env.automation
  # Should show nothing (file is untracked)
  ```

---

## 🔐 Phase 1: Credential Setup (Choose ONE strategy)

### Strategy A: Local File (Development/Testing)
- [ ] Read `.squad/docs/SECRET-MANAGEMENT.md` → Strategy 1 section
- [ ] Contact administrator for current credentials:
  - Client ID
  - Client Secret
  - Tenant ID
  - Org URL
- [ ] Create `.env.automation` file in repo root
  ```
  DATAVERSE_CLIENT_ID=<from_admin>
  DATAVERSE_CLIENT_SECRET=<from_admin>
  DATAVERSE_TENANT_ID=<from_admin>
  DATAVERSE_ORG_URL=<from_admin>
  ```
- [ ] Verify `.env.automation` is in `.gitignore`
  ```
  echo ".env.automation" >> .gitignore
  ```
- [ ] Verify credentials work
  ```powershell
  .\.squad\scripts\load-credentials.ps1
  ```

### Strategy B: Azure Key Vault (Production/CI-CD)
- [ ] Read `.squad/docs/SECRET-MANAGEMENT.md` → Strategy 2 section
- [ ] Prerequisites:
  - [ ] Azure subscription access
  - [ ] Azure PowerShell installed: `Install-Module -Name Az -Scope CurrentUser -Force`
  - [ ] Authenticate: `Connect-AzAccount`
- [ ] Get credentials from administrator OR regenerate (see below)
- [ ] Store in Key Vault:
  ```powershell
  $secret = Read-Host -AsSecureString "Enter Client Secret"
  Set-AzKeyVaultSecret -VaultName 'StandardFedFormVault' `
    -Name 'dataverse-client-secret' `
    -SecretValue $secret
  ```
- [ ] Load credentials:
  ```powershell
  .\.squad\scripts\load-credentials.ps1 -VaultName "StandardFedFormVault"
  ```

### Strategy C: GitHub Secrets (CI/CD Workflows)
- [ ] Read `.squad/docs/SECRET-MANAGEMENT.md` → Strategy 3 section
- [ ] Prerequisites:
  - [ ] Access to GitHub repository settings
  - [ ] Admin permissions to manage secrets
- [ ] Add to GitHub repository secrets:
  - [ ] `DATAVERSE_CLIENT_ID`
  - [ ] `DATAVERSE_CLIENT_SECRET`
  - [ ] `DATAVERSE_TENANT_ID`
  - [ ] `DATAVERSE_ORG_URL`
- [ ] In workflow YAML:
  ```yaml
  env:
    DATAVERSE_CLIENT_ID: ${{ secrets.DATAVERSE_CLIENT_ID }}
    DATAVERSE_CLIENT_SECRET: ${{ secrets.DATAVERSE_CLIENT_SECRET }}
    DATAVERSE_TENANT_ID: ${{ secrets.DATAVERSE_TENANT_ID }}
    DATAVERSE_ORG_URL: ${{ secrets.DATAVERSE_ORG_URL }}
  ```

---

## 🔄 Phase 2: Credential Verification

- [ ] Load credentials using appropriate strategy
  ```powershell
  # Local file strategy:
  . .\.squad\scripts\load-credentials.ps1
  
  # Or manually:
  $env:DATAVERSE_CLIENT_ID = "..."
  $env:DATAVERSE_CLIENT_SECRET = "..."
  $env:DATAVERSE_TENANT_ID = "..."
  $env:DATAVERSE_ORG_URL = "..."
  ```

- [ ] Verify environment variables are set
  ```powershell
  Write-Host $env:DATAVERSE_CLIENT_ID
  Write-Host $env:DATAVERSE_ORG_URL
  ```

- [ ] Test connection (optional - requires Dataverse module)
  ```powershell
  # Install: Install-Module -Name Microsoft.Xrm.Data.PowerShell -Scope CurrentUser -Force
  # Then test connection with Dataverse connection string
  ```

---

## 📋 Phase 3: Environment Setup

- [ ] Install required PowerShell modules:
  ```powershell
  Install-Module -Name Az -Scope CurrentUser -Force
  Install-Module -Name Microsoft.Xrm.Data.PowerShell -Scope CurrentUser -Force
  ```

- [ ] Verify all scripts are executable:
  ```powershell
  dir .\.squad\scripts\*.ps1 | ForEach-Object { Unblock-File $_.FullName }
  ```

- [ ] Review provisioning scripts:
  - [ ] `.squad/scripts/provision-full.ps1` - Full environment provisioning
  - [ ] `.squad/scripts/load-credentials.ps1` - Credential loader
  - [ ] `.squad/scripts/rotate-credentials.ps1` - Credential rotation

---

## 🚀 Phase 4: Environment Provisioning

**Option A: Full Automated Provisioning** (Recommended)
```powershell
# This runs the complete Phase 2 setup
.\.squad\scripts\provision-full.ps1

# Verify:
# - Dataverse tables created ✓
# - AI Builder model registered ✓
# - SharePoint connection configured ✓
# - All relationships established ✓
```

**Option B: Manual Setup** (If scripting fails)
1. [ ] Create Dataverse tables manually:
   - [ ] FormSubmission
   - [ ] ExtractionResult
   - [ ] CorrectionRecord
   - [ ] D365WriteEvent
   - [ ] Custom business logic tables

2. [ ] Configure SharePoint connection to:
   - [ ] Org: https://d365demotsce80677168.sharepoint.com
   - [ ] Site: /sites/DepartmentofVeteranAffairs
   - [ ] Library: FormIntake

3. [ ] Register AI model in environment:
   - [ ] Model Name: VAFE-VA10-3542-DocProc-v1
   - [ ] Model Status: Published ✓

---

## ⚙️ Phase 5: Power Automate Flow Creation

- [ ] Access Power Automate in your environment
- [ ] Review flow templates in `.squad/generated/flow-build-kit/`:
  - [ ] `flow-01-sharepoint-intake.json`
  - [ ] `flow-02-ai-extraction.json`
  - [ ] `flow-03-decision-routing.json`
  - [ ] `flow-04-d365-write.json`
  - [ ] `flow-05-error-handling.json`

- [ ] Follow build sequence (see `flow-build-order.txt`):
  1. [ ] Flow 5: Error Handling (scheduled)
  2. [ ] Flow 4: D365 Write (manual trigger)
  3. [ ] Flow 3: Decision Routing (manual trigger)
  4. [ ] Flow 2: AI Extraction (manual trigger)
  5. [ ] Flow 1: SharePoint Intake (automated trigger)

- [ ] For each flow:
  - [ ] Copy JSON template content
  - [ ] Create "Cloud flow" → "Cloud flow from template"
  - [ ] Paste JSON and customize connections
  - [ ] Review expressions in `power-automate-expressions.txt`
  - [ ] Test flow with sample data

---

## ✅ Phase 6: End-to-End Testing

- [ ] Upload test document to SharePoint FormIntake:
  - [ ] Filename format: `VA-10-3542-{unique}.pdf`
  - [ ] Expected: Triggers Flow 1

- [ ] Verify flow execution:
  - [ ] [ ] FormSubmission record created
  - [ ] [ ] AI extraction completed
  - [ ] [ ] Confidence score evaluated
  - [ ] [ ] Routed to correct path (approve/review/reject)

- [ ] Verify data sync:
  - [ ] [ ] ExtractionResult record created
  - [ ] [ ] D365 Contact/Account created (if approved)
  - [ ] [ ] CorrectionRecord created (if reviewed)

---

## 🛡️ Phase 7: Security Review

- [ ] Verify secrets are NOT in git:
  ```powershell
  git log --all --source --remotes -S "SdU8Q" -- "*"
  # Should return nothing
  ```

- [ ] Verify .gitignore protects credentials:
  ```powershell
  cat .gitignore | findstr "\.env"
  # Should show: .env.automation
  ```

- [ ] Verify local file is NOT committed:
  ```powershell
  git ls-files -- .env.automation
  # Should return nothing
  ```

- [ ] Rotate credentials if more than 6 months old:
  ```powershell
  .\.squad\scripts\rotate-credentials.ps1
  ```

---

## 📝 Phase 8: Documentation

- [ ] Create local notes for this setup:
  ```
  Created on: [date]
  Machine: [hostname]
  Strategy: [Local/KeyVault/GitHub]
  Credentials from: [admin name]
  Last rotated: [date]
  Next rotation due: [date + 12 months]
  ```

- [ ] Document any customizations:
  - [ ] Modified field mappings?
  - [ ] Custom confidence thresholds?
  - [ ] Additional flows added?
  - [ ] Integration endpoints changed?

- [ ] Store in shared documentation or notes app (NOT in git)

---

## 🆘 Troubleshooting

### Credentials Won't Load
1. Verify `.env.automation` file exists and is readable
2. Check file format matches exactly:
   ```
   DATAVERSE_CLIENT_ID=value
   DATAVERSE_CLIENT_SECRET=value
   DATAVERSE_TENANT_ID=value
   DATAVERSE_ORG_URL=value
   ```
3. Run credential loader with verbose output:
   ```powershell
   .\.squad\scripts\load-credentials.ps1 -Verbose
   ```

### Provisioning Script Fails
1. Verify credentials are loaded:
   ```powershell
   Write-Host $env:DATAVERSE_CLIENT_ID
   ```
2. Verify Azure PowerShell is installed and updated:
   ```powershell
   Update-Module -Name Az -Force
   ```
3. Check administrator permissions on Dataverse environment
4. Review script logs in `.squad/logs/` for error details

### Power Automate Flow Fails
1. Verify all connections are created in Power Automate
2. Verify connection credentials match environment
3. Test each flow action individually
4. Check flow run history for detailed error messages
5. Review `.squad/generated/power-automate-expressions.txt` for dynamic content

### Credential Rotation Failed
1. Verify you're connected to correct Azure subscription:
   ```powershell
   Get-AzContext
   ```
2. Verify you have permissions to modify App Registrations
3. Run as administrator:
   ```powershell
   .\.squad\scripts\rotate-credentials.ps1
   ```
4. Check Azure AD audit logs for operation details

---

## 🔗 Related Documentation

- **Full Credential Strategy Guide:** `.squad/docs/SECRET-MANAGEMENT.md`
- **Flow Build Kit:** `.squad/generated/flow-build-kit/flow-build-order.txt`
- **Power Automate Expressions:** `.squad/generated/power-automate-expressions.txt`
- **Phase 2 Design:** `.squad/docs/VA-Form-Extraction-System-Design-v1.md`
- **Main README:** `README.md`

---

**Last Updated:** 2026-04-29
**Maintained by:** Brady Lawson (Coordinator)
