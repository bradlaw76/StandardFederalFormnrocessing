# T003 Execution Checklist: Create SharePoint Document Library FormIntake

**Owner**: ⚙️ Arthur Shelby  
**Issue**: #5 [T003]  
**Estimated Time**: 15–20 min  
**Depends On**: T002 (SharePoint Site Creation) ✅ *Complete first*  
**Status**: READY (awaiting T002 completion)  

---

## Overview
Create a SharePoint document library named `FormIntake` within the `/sites/VAFormProcessing` site to receive uploaded VA Form 10-3542 PDFs.

---

## Pre-Flight Checks

### ✅ Prerequisites
- [ ] T002 (SharePoint Site) is **COMPLETE** and documented
- [ ] You have access to `/sites/VAFormProcessing`
- [ ] You have **Owner** or **Edit** permission on the site
- [ ] You know the site URL from T002

---

## Execution Steps

### Step 1: Navigate to SharePoint Site

1. Open the site URL from T002:  
   `https://[tenant].sharepoint.com/sites/VAFormProcessing`
2. **Expected**: Site homepage loads

### Step 2: Create New Document Library

#### 2a. Access Library Creation
1. On site homepage, click **+ New** (top-left)
2. From dropdown, select **Document library**
3. **Alternative path**: Click **Site contents** → **+ New** → **Document library**
4. **Expected**: Library creation dialog opens

#### 2b. Configure Library Details
Fill in the form:
- **Name**: `FormIntake`
- **Description**: `Intake library for VA Form 10-3542 PDFs`
- **Advanced settings** (click if available):
  - **Create with sample content**: No
  - **Versioning**: Enable (✅ recommended)
  - **Check-in/Check-out**: Not required
- Click **Create**

#### 2c: Wait for Library Creation
- **Expected**: Library is created (usually instant, but may take 10-15 seconds)
- **Result**: Redirected to the new `FormIntake` library

### Step 3: Configure Library Permissions & Settings

#### 3a. Verify Versioning is Enabled
1. In the `FormIntake` library, click **Settings** (gear icon)
2. Go to **List settings** or **Library settings**
3. Click **Versioning settings**
4. Confirm:
   - **Create a version each time you edit a file in this library**: **Yes** ✅
   - Keep version history depth as desired (default: unlimited)
5. Click **OK**

#### 3b. Set Permissions (Upload Access)
1. In library, click **Settings** → **Share** or **Permissions**
2. Current permissions: Inherited from site (already configured in T002)
3. **Expected**: Permissions inherited from parent site `/sites/VAFormProcessing`
4. ℹ️ *Note: Can modify per-library permissions later if needed*

#### 3c. Configure Upload Restrictions (Optional)
1. In **Library settings** → **Advanced settings**
2. Optional: Set file upload limits or allowed file types
   - **Recommended for demo**: Allow only `.pdf` files
3. Look for **File upload limit** or **Allowed content types**
4. If modifying, save changes

### Step 4: Verify Library is Accessible & Ready

#### 4a. Test Library Access
1. In the `FormIntake` library, verify you see:
   - An empty library (no files yet — expected)
   - Upload button accessible
   - Settings gear icon accessible
2. Click **Upload** to verify button works (don't actually upload)
3. **Expected**: Upload dialog appears, then cancel

#### 4b. Get Library URL
1. In `FormIntake` library, click on the library name or settings
2. Note the library URL (usually: `https://[tenant].sharepoint.com/sites/VAFormProcessing/Shared%20Documents/FormIntake`)
3. **Expected**: URL is accessible and points to the library

#### 4c. Verify from Power Platform Connector (Optional but Recommended)
1. Open **Power Automate**: https://flow.microsoft.com
2. Select the `VA-Form-Extraction` environment (from T001)
3. Create a test flow: **Automated** → when file is created (SharePoint trigger)
4. In trigger, select:
   - **Site Address**: `https://[tenant].sharepoint.com/sites/VAFormProcessing`
   - **List**: `FormIntake`
5. **Expected**: Library appears as an option
6. Cancel the flow (don't save)

---

## Documentation: SharePoint Library Details

### ✅ Required Details (Record These)

| Detail | Value | Location |
|--------|-------|----------|
| **Library Name** | `FormIntake` | SharePoint Site → Document Libraries |
| **Library URL** | `https://[tenant].sharepoint.com/sites/VAFormProcessing/Shared%20Documents/FormIntake` | Browser address bar |
| **Versioning** | Enabled | Library Settings → Versioning |
| **Parent Site** | `/sites/VAFormProcessing` | Library settings |

### 📝 Record Details Below:
```yaml
FORM_INTAKE_LIBRARY:
  name: "FormIntake"
  library_url: "[ ENTER HERE ]"  # e.g., https://[tenant].sharepoint.com/sites/VAFormProcessing/Shared Documents/FormIntake
  parent_site_url: "https://[tenant].sharepoint.com/sites/VAFormProcessing"
  versioning_enabled: true
  created_at: "2026-04-24"
  status: "[ ACTIVE or PENDING ]"
  power_automate_discoverable: "[ true or false ]"
```

---

## Acceptance Criteria Checklist

### ✅ AC1: Document library `FormIntake` created in `/sites/VAFormProcessing`
- [ ] Library named exactly `FormIntake` (case-sensitive for internal reference)
- [ ] Library is visible in site contents
- [ ] No conflicts with existing libraries

### ✅ AC2: Permissions configured (VA staff upload access)
- [ ] Permissions inherited from parent site (or explicitly set)
- [ ] VA staff group can upload (if group assigned in T002)
- [ ] At minimum: Site owners can manage library

### ✅ AC3: Versioning enabled (recommended)
- [ ] Versioning is **Yes** in Library Settings
- [ ] Users will see version history when files are modified

### ✅ AC4: Library URL documented
- [ ] Full library URL recorded in documentation section above
- [ ] URL is accessible and points to the library

### ✅ AC5: Report — Library ready for intake flow
- [ ] Library is empty (no test files lingering)
- [ ] Upload button works
- [ ] Library is discoverable from Power Automate (test in Step 4c)

---

## Readiness Indicators

### 🟢 Ready to Proceed to T005 (Quotas & Connectors) IF:
- [x] Library is created and accessible
- [x] Versioning is enabled
- [x] URL is documented
- [x] Power Automate can discover the library

### 🔴 Blocker — Cannot Proceed IF:
- Library creation failed
- Library not accessible (403 Forbidden)
- Versioning cannot be enabled
- Power Automate cannot find the library

---

## Troubleshooting

### ❌ Problem: "Permission denied to create library"
**Cause**: Insufficient permissions on parent site  
**Solution**:
1. Verify you're **Owner** of the parent site `/sites/VAFormProcessing`
2. Request admin access if needed
3. Try using **Site contents** instead of **+ New** button

### ❌ Problem: "Library created but not appearing in site contents"
**Cause**: Cache issue or permission inherited incorrectly  
**Solution**:
1. Refresh the page (Ctrl+F5 hard refresh)
2. Clear browser cache
3. Check Site contents → All lists and libraries
4. Library should appear even if not on homepage

### ❌ Problem: "Versioning option not appearing in settings"
**Cause**: Library type doesn't support versioning (rare)  
**Solution**:
1. Verify library is type **Document Library** (not Forms library or other type)
2. Check if versioning is disabled by tenant policy
3. Contact SharePoint admin if issue persists

### ❌ Problem: "Power Automate cannot find the library"
**Cause**: Connector cache or URL mismatch  
**Solution**:
1. In Power Automate, disconnect and reconnect SharePoint connector
2. Verify site URL exactly matches T002 documentation
3. Wait 5 minutes for connector to sync
4. Try in new browser window

---

## Hand-Off Notes

### 🎯 When T003 is Complete:
1. ✅ Document library URL and details in YAML above
2. ✅ Confirm all AC items are checked
3. ✅ Verify versioning is enabled
4. ✅ **Dependency unblocked**: T005 (Quotas) can now proceed
5. ✅ SharePoint infrastructure ready for T030+ (intake flows)

### 📋 Next Step: T005 (Verify Power Automate Quotas & Connectors)
- Owner: Arthur Shelby
- Task: Verify all connectors enabled and quotas sufficient
- Dependency: T002 & T003 ready → **UNBLOCKS T005**

---

## Session Log

| Time | Step | Status | Notes |
|------|------|--------|-------|
| — | Pre-Flight Checks | PENDING | Awaiting T002 completion |
| — | Step 1: Navigate to Site | PENDING | — |
| — | Step 2a-c: Create Library | PENDING | — |
| — | Step 3: Configure Settings | PENDING | — |
| — | Step 4: Verify & Test | PENDING | — |
| — | Documentation | PENDING | — |
| — | **COMPLETE** | — | — |

---

*End T003 Execution Checklist*
