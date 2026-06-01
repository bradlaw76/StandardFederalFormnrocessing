# T002 Execution Checklist: Create SharePoint Site for Form Intake

**Owner**: ⚙️ Arthur Shelby  
**Issue**: #4 [T002]  
**Estimated Time**: 20–30 min  
**Depends On**: T001 (Power Platform Environment) ✅ *Complete first*  
**Status**: READY (awaiting T001 completion)  

---

## Overview
Create a SharePoint site at `/sites/VAFormProcessing` to serve as the central intake location for VA Form 10-3542 PDFs.

---

## Pre-Flight Checks

### ✅ Prerequisites
- [ ] T001 (Power Platform Environment) is **COMPLETE** and documented
- [ ] You have SharePoint admin access (or site collection admin)
- [ ] You can access Microsoft 365 Admin Center: https://admin.microsoft.com
- [ ] Tenant has available SharePoint capacity

---

## Execution Steps

### Step 1: Access SharePoint Admin Center
1. Navigate to **Microsoft 365 Admin Center**: https://admin.microsoft.com
2. In left sidebar, go to **Admin centers** → **SharePoint**
3. **Expected**: You're in SharePoint Admin Center

### Step 2: Create New SharePoint Site

#### 2a. Initiate Site Creation
1. In **SharePoint Admin Center**, click **+ Create** (top-left)
2. Select **Team site** (not Communication site — we need full collaboration features)
3. **Expected**: Site creation dialog opens

#### 2b. Configure Site Details
Fill in the form:
- **Site Name**: `VA Form Processing`
- **Site Address**: `/sites/VAFormProcessing`
  - **Note**: Address will be: `https://[tenant].sharepoint.com/sites/VAFormProcessing`
- **Description**: `Intake site for VA Form 10-3542 extraction pipeline`
- **Classification**: Select appropriate level (e.g., "Internal Use" or "Standard")
- **Owners**: Add yourself and any other admins who need access
- **Preferred Language**: English

#### 2c. Create Site
1. Click **Next** → **Create**
2. **Expected**: Site creation queued (usually completes within 5-15 minutes)
3. ⏳ **Wait** for completion notification

### Step 3: Verify Site Created & Accessible

#### 3a. Confirm Site Exists
1. In **SharePoint Admin Center → Active sites**
2. Search for: `VAFormProcessing`
3. **Expected**: Site appears in the list with status **Active**

#### 3b. Open Site
1. Click on the site name or navigate directly to:  
   `https://[tenant].sharepoint.com/sites/VAFormProcessing`
2. **Expected**: Site homepage loads successfully

#### 3c. Verify Owner/Admin Access
1. On the site, click **Settings** (gear icon, top-right)
2. Go to **Site permissions** or **People and permissions**
3. Verify you appear as **Owner** or **Site Collection Admin**
4. **Expected**: You have admin permissions

### Step 4: Configure Site Permissions (Optional but Recommended)

#### 4a. Add VA Staff Group (for future use)
1. Go to **Settings** → **Site permissions** → **Grant permissions**
2. Add a security group: `VA Staff` or `VAFormReviewers`
3. Assign permission level: **Edit** (allows upload and modify)
4. **Expected**: Group added successfully
5. ℹ️ *Note: Can configure later when full team is added in T008*

---

## Documentation: SharePoint Site Details

### ✅ Required Details (Record These)

| Detail | Value | Location |
|--------|-------|----------|
| **Site Name** | `VA Form Processing` | SharePoint Site Settings |
| **Site URL** | `https://[tenant].sharepoint.com/sites/VAFormProcessing` | Browser address bar |
| **Site Address** | `/sites/VAFormProcessing` | Site settings |
| **Site Owner** | (your email) | Site permissions → Owners |
| **Created Date** | (today's date) | — |

### 📝 Record Details Below:
```yaml
VA_FORM_PROCESSING_SITE:
  name: "VA Form Processing"
  site_url: "[ ENTER HERE ]"  # e.g., https://contoso.sharepoint.com/sites/VAFormProcessing
  site_address: "/sites/VAFormProcessing"
  owner: "[ ENTER HERE ]"
  created_at: "2026-04-24"
  status: "[ ACTIVE or PENDING ]"
  permissions_configured: "[ true or false ]"
```

---

## Acceptance Criteria Checklist

### ✅ AC1: SharePoint site created at `/sites/VAFormProcessing`
- [ ] Site appears in SharePoint Admin Center → Active sites
- [ ] Site URL is exactly: `https://[tenant].sharepoint.com/sites/VAFormProcessing`

### ✅ AC2: Site owner/admin configured
- [ ] You have **Owner** or **Site Collection Admin** role
- [ ] You can access site settings without permission errors

### ✅ AC3: SharePoint URL documented
- [ ] Full site URL recorded in documentation section above
- [ ] URL is accessible (no 404 or permission errors)

### ✅ AC4: Report — Site ready for library setup
- [ ] Site homepage loads successfully
- [ ] You can create/modify lists and libraries
- [ ] Site is accessible from Power Platform (connectors will use this URL in T005+)

---

## Readiness Indicators

### 🟢 Ready to Proceed to T003 (SharePoint Library) IF:
- [x] Site is Active and accessible
- [x] You have admin permissions
- [x] Site URL is documented
- [x] Can navigate to site and view settings

### 🔴 Blocker — Cannot Proceed to T003 IF:
- Site creation failed
- Site not accessible (403 Forbidden)
- Admin permissions not granted
- URL recorded incorrectly

---

## Troubleshooting

### ❌ Problem: "Permission denied to create site"
**Cause**: Tenant admin restriction or SharePoint policy  
**Solution**:
1. Verify you have SharePoint admin role in Microsoft 365
2. Check if site creation is disabled: SharePoint Admin Center → Settings → Site creation
3. Request exemption from tenant admin if needed

### ❌ Problem: "Site creation timeout after 15 minutes"
**Cause**: Tenant capacity or system slowness  
**Solution**:
1. Wait another 10 minutes and refresh
2. Check SharePoint Admin Center for status updates
3. If failed, retry creation
4. Contact Microsoft Support if issue persists

### ❌ Problem: "Cannot access site — 403 Forbidden"
**Cause**: Permissions not properly configured or site not finished provisioning  
**Solution**:
1. Wait 5 more minutes and try again
2. Clear browser cache
3. Try in incognito window
4. Verify you're the site owner in Admin Center

### ❌ Problem: "Site address `/sites/VAFormProcessing` already exists"
**Cause**: Site with this address already created (possibly in past)  
**Solution**:
1. Use existing site (verify it's empty and accessible)
2. Document existing site details instead
3. If you need different site, use alternate address: `/sites/VAFormProcessing2`

---

## Hand-Off Notes

### 🎯 When T002 is Complete:
1. ✅ Document site URL and details in YAML above
2. ✅ Confirm all AC items are checked
3. ✅ Verify you can modify site (add libraries, change permissions)
4. ✅ **Dependency unblocked**: T003 can now proceed

### 📋 Next Step: T003 (SharePoint Document Library)
- Owner: Arthur Shelby
- Task: Create `FormIntake` library in this site
- Dependency: This (T002) ← **UNBLOCKS T003**

---

## Session Log

| Time | Step | Status | Notes |
|------|------|--------|-------|
| — | Pre-Flight Checks | PENDING | Awaiting T001 completion |
| — | Step 1: Access Admin Center | PENDING | — |
| — | Step 2a: Initiate Creation | PENDING | — |
| — | Step 2b: Configure Details | PENDING | — |
| — | Step 2c: Create Site | PENDING | — |
| — | Step 3: Verify Accessible | PENDING | — |
| — | Documentation | PENDING | — |
| — | **COMPLETE** | — | — |

---

*End T002 Execution Checklist*
