# T001 Execution Checklist: Create/Verify Power Platform Environment

**Owner**: ⚙️ Arthur Shelby  
**Issue**: #3 [T001]  
**Estimated Time**: 30–45 min  
**Start Time**: 2026-04-24 14:00:00 UTC  
**Status**: IN PROGRESS  

---

## Overview
Create or verify a Microsoft Power Platform environment for the VA Form 10-3542 extraction pipeline.

---

## Pre-Flight Checks

### ✅ Prerequisites
- [ ] You have Microsoft 365 tenant admin access
- [ ] You have Power Platform license (Cloud Flows or AI Builder)
- [ ] You can access Power Platform Admin Center: https://admin.powerplatform.microsoft.com
- [ ] Tenant is not restricted (no environment creation block via policies)

---

## Execution Steps

### Step 1: Access Power Platform Admin Center
1. Navigate to: **https://admin.powerplatform.microsoft.com**
2. Sign in with tenant admin credentials
3. In left sidebar, select **Environments**
4. **Expected**: You see a list of existing environments

### Step 2: Check for Existing Environment
**Goal**: Determine if `VA-Form-Extraction` environment already exists

1. **Scan existing environments** for one named:
   - `VA-Form-Extraction` (preferred)
   - `VAForm` or similar variant
   
2. **If FOUND**: Skip to Step 4 (Verify Access)
3. **If NOT FOUND**: Proceed to Step 3 (Create Environment)

### Step 3: Create New Power Platform Environment
**Goal**: Provision a new environment for the VA Form extraction pipeline

#### 3a. Initiate Environment Creation
1. In **Power Platform Admin Center → Environments**
2. Click **+ New** (top-right)
3. Fill out the form:
   - **Name**: `VA-Form-Extraction`
   - **Region**: Select your primary region (e.g., United States - default)
   - **Type**: **Production** (this is the default and recommended for demo)
   - **Purpose**: `VA Form 10-3542 Extraction and Processing`
4. Click **Next** → **Create**
5. **Expected**: Environment creation initiated (takes 5-10 minutes)
6. ⏳ **Wait** for provisioning to complete (page will refresh automatically)

#### 3b: Confirm Dataverse Database
Once environment is created:
1. Open the new environment
2. Verify **Dataverse** is provisioned:
   - In the environment panel, you should see a **Dataverse** section
   - If Dataverse is not shown, click **+ Create Dataverse**
   - Fill in: Language = English, Currency = USD
   - Click **Create** (takes 2-5 minutes)
3. **Expected**: Dataverse database is active and ready

### Step 4: Verify Admin Access & Connectivity

#### 4a: Confirm You Are Admin
1. In the environment, click **Settings** (gear icon, top-right)
2. Go to **Admin** → **Users**
3. **Expected**: Your user appears in the list with role `System Administrator`
4. If not, contact your M365 tenant admin

#### 4b: Test Dataverse Access
1. Go to **Power Platform Admin Center** → Your Environment
2. Click **Dataverse** → **Tables**
3. **Expected**: You see a list of default tables (Account, Contact, etc.)
4. If you see this, Dataverse is accessible ✅

#### 4c: Test Power Automate Access
1. Navigate to **Power Automate** (https://flow.microsoft.com)
2. In top-left, select your environment from the dropdown: `VA-Form-Extraction`
3. Click **+ Create** → **Cloud flow** → **Automated**
4. **Expected**: You can start creating a flow
5. Cancel the flow (don't save)

---

## Documentation: Environment Details

### ✅ Required Details (Record These)

Once the environment is created and verified, **document and save** the following:

| Detail | Value | Location |
|--------|-------|----------|
| **Environment Name** | `VA-Form-Extraction` | Power Platform Admin Center → Environments |
| **Environment ID** | (UUID format: e.g., `12a3b4c5-d6e7-8f9g-h0i1-j2k3l4m5n6o7`) | Power Platform Admin Center → Environment Details → Environment ID |
| **Environment URL** | e.g., `https://org12a3b4c5.crm.dynamics.com` | Power Platform Admin Center → Environment Details |
| **Dataverse Org ID** | (same as or linked to Environment ID) | Dataverse → Settings → Instance Reference Information → Instance ID |
| **Tenant ID** | (UUID from Microsoft Entra ID) | Microsoft Entra admin center → Tenant info |
| **Admin User** | (your email) | Confirmed in Users list |

### 📝 Record Details in This File
Once collected, paste the values into the section below:

```yaml
VA_FORM_EXTRACTION_ENV:
  name: "VA-Form-Extraction"
  environment_id: "[ ENTER HERE ]"
  environment_url: "[ ENTER HERE ]"
  dataverse_org_id: "[ ENTER HERE ]"
  tenant_id: "[ ENTER HERE ]"
  admin_user: "[ ENTER HERE ]"
  created_at: "2026-04-24"
  dataverse_status: "[ ACTIVE or PENDING ]"
  power_automate_status: "[ ACCESSIBLE or BLOCKED ]"
```

---

## Acceptance Criteria Checklist

### ✅ AC1: Power Platform environment created or verified
- [ ] Environment `VA-Form-Extraction` exists in Power Platform Admin Center
- [ ] Environment is in **Active** state (not Disabled)

### ✅ AC2: Admin access confirmed
- [ ] You have **System Administrator** role in the environment
- [ ] You can access Power Platform Admin Center → Environments → Your Environment

### ✅ AC3: Environment details documented (environment ID, URL, tenant ID)
- [ ] Environment ID recorded (see Documentation section above)
- [ ] Environment URL recorded (see Documentation section above)
- [ ] Tenant ID recorded (see Documentation section above)

### ✅ AC4: Report — Environment is ready for connectors setup
- [ ] Dataverse database is **Active**
- [ ] You can access Power Automate without errors
- [ ] Basic connectivity test passed (can create/view flows)

---

## Readiness Indicators

### 🟢 Ready to Proceed to T002 (SharePoint Site) IF:
- [x] Environment is Active
- [x] Dataverse is provisioned and accessible
- [x] You have admin access
- [x] Power Automate is accessible
- [x] All details documented

### 🔴 Blocker — Cannot Proceed to T002 IF:
- Environment creation failed
- Dataverse provisioning failed
- Admin access denied
- Cannot connect to Power Automate

---

## Troubleshooting

### ❌ Problem: "Permission denied to create environment"
**Cause**: Tenant admin restriction or Power Platform policy block  
**Solution**:
1. Contact your M365 tenant admin
2. Confirm you have "Environment Admin" role in Power Platform
3. Check tenant policies: Power Platform Admin Center → Policies → Environment policies
4. If blocked, request exemption or use existing environment

### ❌ Problem: "Dataverse not provisioning after 15 minutes"
**Cause**: Provisioning timeout or capacity issue  
**Solution**:
1. Wait another 5 minutes and refresh
2. If still not provisioned, delete and recreate the environment
3. Contact Microsoft Support if issue persists

### ❌ Problem: "Cannot access Power Automate"
**Cause**: License issue or environment misconfiguration  
**Solution**:
1. Verify you have Cloud Flows or Power Automate license
2. Confirm you're selecting the correct environment
3. Try in incognito/private browser window
4. Contact tenant admin if license issue

### ❌ Problem: "Dataverse database is empty/no tables showing"
**Cause**: Normal behavior for new environment  
**Solution**: This is expected! Default tables are created on first access. Proceed to T002.

---

## Hand-Off Checklist

### 🎯 When T001 is Complete:
1. ✅ Paste environment details into the YAML section above
2. ✅ Confirm all AC items are checked
3. ✅ Update Status to `COMPLETE`
4. ✅ Post results to GitHub issue #3
5. ✅ Notify T002 owner (Polly? John?) that environment is ready
6. ✅ **Dependency unblocked**: All Phase 1 tasks can now proceed

### 📋 Next Step: T002 (SharePoint Site)
- Owner: Arthur Shelby
- Task: Create SharePoint site at `/sites/VAFormProcessing`
- Dependency: This (T001) ← **UNBLOCKS T002**

---

## Session Log

| Time | Step | Status | Notes |
|------|------|--------|-------|
| 2026-04-24 14:00 | Pre-Flight Checks | PENDING | Awaiting execution |
| — | Step 1: Access Admin Center | PENDING | — |
| — | Step 2: Check Existing Env | PENDING | — |
| — | Step 3a: Create Environment | PENDING | — |
| — | Step 3b: Dataverse Provision | PENDING | — |
| — | Step 4: Verify Access | PENDING | — |
| — | Documentation | PENDING | — |
| — | **COMPLETE** | — | — |

---

## Questions / Decisions

**Q: Should we use Production or Sandbox environment?**  
A: Production is recommended for demo scope (5 forms) to avoid time-limited trial features.

**Q: Do we need multiple environments?**  
A: For Phase 1 demo, one environment is sufficient. Can add dev/test later in Phase 3+.

**Q: Can we use an existing environment?**  
A: Yes! If `VA-Form-Extraction` or similar already exists and is accessible, document it and proceed to T002. No need to create a new one.

---

*End T001 Execution Checklist*
