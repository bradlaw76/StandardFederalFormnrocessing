# T005 Execution Checklist: Verify Power Automate Quotas & Connectors

**Owner**: ⚙️ Arthur Shelby  
**Issue**: #7 [T005]  
**Estimated Time**: 20–30 min  
**Depends On**: T001 (Power Platform Environment) ✅ *Complete first*  
**Status**: READY (awaiting T001 completion)  

---

## Overview
Verify that all required Power Automate connectors are enabled in the `VA-Form-Extraction` environment and that cloud flow quotas are sufficient for the VA Form extraction pipeline.

---

## Pre-Flight Checks

### ✅ Prerequisites
- [ ] T001 (Power Platform Environment) is **COMPLETE**
- [ ] Environment `VA-Form-Extraction` is accessible
- [ ] You have admin access to Power Platform admin center
- [ ] You know your environment ID from T001

---

## Execution Steps

### Step 1: Verify Cloud Flow Quotas

#### 1a. Access Cloud Flow Quota Information
1. Go to **Power Platform Admin Center**: https://admin.powerplatform.microsoft.com
2. Select **Environments** → `VA-Form-Extraction`
3. Click **Resources** → **Capacity**
4. **Expected**: You see a capacity dashboard showing:
   - Cloud flows quota
   - API requests per day
   - Per-flow run count

#### 1b: Document Cloud Flow Limits
Check for the following information and record:

| Metric | Expected Value | Actual Value | Status |
|--------|-----------------|--------------|--------|
| **Cloud flows per tenant** | ≥ 50 | [ ] | Verify ≥ 50 |
| **Runs per user per month** | ≥ 10,000 | [ ] | Verify ≥ 10,000 |
| **Daily API request quota** | ≥ 40,000 | [ ] | Verify sufficient |
| **Concurrent cloud flows** | ≥ 5 | [ ] | Verify ≥ 5 |

**Expected**: All metrics should be sufficient for demo scope (5 forms, ~10 test runs)

### Step 2: Enable All Required Connectors

#### 2a. Navigate to Connector Settings
1. In **Power Platform Admin Center** → `VA-Form-Extraction` environment
2. Click **Settings** → **Product features** or **Connectors**
3. **Alternative**: Go to **Power Automate** → `VA-Form-Extraction` → **Create** → **Cloud flow**
4. When creating a flow, you'll see **All connectors** list

#### 2b: Verify These Connectors are Enabled

**Connector**: AI Builder (AI Builder Processing)
- [ ] **Status**: Enabled
- [ ] **Action**: If disabled, enable immediately
- [ ] **Verification**: Can create "AI Builder" actions in flows

**Connector**: SharePoint
- [ ] **Status**: Enabled
- [ ] **Action**: If disabled, enable immediately
- [ ] **Verification**: Can select SharePoint trigger/action in flows

**Connector**: Dataverse
- [ ] **Status**: Enabled
- [ ] **Action**: If disabled, enable immediately
- [ ] **Verification**: Can add "Add a row" Dataverse actions

**Connector**: Dynamics 365
- [ ] **Status**: Enabled
- [ ] **Action**: If disabled, enable immediately
- [ ] **Verification**: Can add "Create a new record" D365 actions

**Connector**: Outlook/Office 365 Mail
- [ ] **Status**: Enabled (for notifications)
- [ ] **Action**: If disabled, enable (optional but recommended)
- [ ] **Verification**: Can add "Send an email" action

#### 2c: Enable Missing Connectors (if needed)
1. In connector list, find any disabled connector
2. Click the connector name
3. Look for **Enable** button or toggle
4. Click **Enable** and wait for confirmation (usually instant)
5. **Expected**: Connector moves to "Enabled" list

### Step 3: Verify AI Builder Capacity

#### 3a. Check AI Builder License/Trial
1. In **Power Platform Admin Center** → `VA-Form-Extraction` environment
2. Go to **Resources** → **Capacity** or **Add-ons**
3. Look for **AI Builder** section
4. **Expected**: AI Builder license or trial is active

#### 3b: Verify Custom Document Processing Quota
1. In **AI Builder section**, check:
   - **Custom document processing calls per month**: ≥ 100 (demo scope needs ~50-100)
   - **Status**: Active or "Trial - Days remaining: X"
2. **Expected**: Quota is sufficient and not depleted

#### 3c: Record AI Builder Details
```yaml
AI_BUILDER_CAPACITY:
  license_type: "[ Trial or Premium ]"
  custom_doc_processing_quota: "[ Number of calls/month ]"
  status: "[ Active or Trial (X days) ]"
  calls_used: "[ X out of Y ]"
```

### Step 4: Test Connector Connectivity

#### 4a: Create Test Flow
1. In **Power Automate**: https://flow.microsoft.com
2. Select environment: `VA-Form-Extraction`
3. Click **+ Create** → **Cloud flow** → **Automated**
4. **Trigger**: Select **SharePoint** → **When a file is created**
5. **Expected**: SharePoint trigger appears and can be selected

#### 4b: Configure Test Trigger
1. In trigger, select:
   - **Site Address**: Paste the SharePoint site URL from T002
   - **List**: `FormIntake` library (from T003)
2. **Expected**: Can successfully select both without errors

#### 4c: Add Test Actions (One of Each Connector)
1. Click **+ New step**
2. Add action: **Dataverse** → **Add a new row**
   - **Expected**: Dataverse action available and can connect
3. Click **+ New step**
4. Add action: **Dynamics 365** → **Create a new record**
   - **Expected**: D365 action available and can connect
5. Click **+ New step**
6. Add action: **AI Builder** → **Process and save information from forms**
   - **Expected**: AI Builder action appears
7. **Do NOT save this flow** — we're just testing connectors
8. Click **Discard** when done

### Step 5: Document Connector Status & Readiness

### 📋 Connector Verification Table

| Connector | Required | Enabled | Tested | Notes |
|-----------|----------|---------|--------|-------|
| **SharePoint** | ✅ Yes | [ ] | [ ] | Intake trigger requires this |
| **Dataverse** | ✅ Yes | [ ] | [ ] | Store form data & results |
| **Dynamics 365** | ✅ Yes | [ ] | [ ] | Write final records |
| **AI Builder** | ✅ Yes | [ ] | [ ] | Extract form fields |
| **Outlook/Mail** | ⚠️ Optional | [ ] | [ ] | Send notifications (nice-to-have) |

### 📝 Summary to Record:
```yaml
POWER_AUTOMATE_QUOTA_VERIFICATION:
  environment: "VA-Form-Extraction"
  cloud_flows_enabled: "[ true/false ]"
  cloud_flow_quota_status: "[ Sufficient/Warning/Exceeded ]"
  daily_api_quota: "[ Remaining or Limit ]"
  concurrent_flows_allowed: "[ Number ]"
  connectors_enabled:
    sharepoint: "[ true/false ]"
    dataverse: "[ true/false ]"
    dynamics_365: "[ true/false ]"
    ai_builder: "[ true/false ]"
    outlook: "[ true/false ]"
  ai_builder_quota:
    license_type: "[ Trial/Premium ]"
    custom_doc_processing_calls_per_month: "[ Number ]"
    status: "[ Active/Trial ]"
  verification_date: "2026-04-24"
```

---

## Acceptance Criteria Checklist

### ✅ AC1: Power Automate plan verified (sufficient for demo scope)
- [ ] Cloud flows per tenant: ≥ 50
- [ ] Runs per user per month: ≥ 10,000
- [ ] Daily API quota: ≥ 40,000
- [ ] All quotas are within acceptable limits

### ✅ AC2: All connectors enabled in environment
- [ ] ✅ SharePoint — Enabled
- [ ] ✅ Dataverse — Enabled
- [ ] ✅ Dynamics 365 — Enabled
- [ ] ✅ AI Builder — Enabled
- [ ] ✅ Outlook (optional) — Enabled or N/A

### ✅ AC3: AI Builder capacity/quota confirmed
- [ ] AI Builder license or trial is active
- [ ] Custom document processing quota: ≥ 100 calls/month
- [ ] Quota not approaching depletion

### ✅ AC4: Flow concurrency checked (≥5 concurrent flows for demo)
- [ ] Concurrent flow limit verified: ≥ 5
- [ ] Platform can handle multiple simultaneous flow runs

### ✅ AC5: Report — Quotas & connectors ready
- [ ] All connectors tested and working
- [ ] No connection errors or warnings
- [ ] Documentation complete
- [ ] Ready to proceed with T006+ (flow creation)

---

## Readiness Indicators

### 🟢 Ready to Proceed to T006+ (Flow Creation) IF:
- [x] All 4 required connectors enabled
- [x] Quotas verified sufficient
- [x] AI Builder capacity confirmed
- [x] Test actions created without errors

### 🔴 Blocker — Cannot Proceed IF:
- Any required connector disabled and cannot be enabled
- Quota exceeded or near limit
- AI Builder trial expired or license missing
- Connection errors when testing actions

---

## Troubleshooting

### ❌ Problem: "Connector disabled and cannot enable"
**Cause**: Tenant policy or license issue  
**Solution**:
1. Check if tenant policy blocks connectors: Power Platform Admin Center → Policies
2. Verify license includes required connectors
3. Contact tenant admin if policy is blocking
4. For AI Builder: Verify trial hasn't expired

### ❌ Problem: "Cloud flow quota exceeded"
**Cause**: Too many flows already created in tenant  
**Solution**:
1. Delete unused flows to free up quota
2. Request quota increase via Power Platform Admin Center
3. Consider consolidating into fewer flows
4. Contact Microsoft if quota limit is too low

### ❌ Problem: "AI Builder custom document processing quota depleted"
**Cause**: Too many model calls made in current month  
**Solution**:
1. Wait for monthly quota reset (next calendar month)
2. Verify AI model isn't being called unnecessarily
3. Upgrade to higher AI Builder license (if available)
4. Contact Microsoft for emergency quota increase

### ❌ Problem: "Cannot select SharePoint site in test trigger"
**Cause**: SharePoint connector not properly enabled or T002/T003 not complete  
**Solution**:
1. Verify T002 and T003 are complete
2. Verify SharePoint connector is enabled
3. Refresh Power Automate page
4. Re-authenticate SharePoint connector: Settings → Cloud connections → Disconnect/reconnect

### ❌ Problem: "Test flow creation fails with authentication error"
**Cause**: User credentials or permission issue  
**Solution**:
1. Verify you have access to the `VA-Form-Extraction` environment
2. Log out and log back in
3. Try in incognito/private browser window
4. Contact Power Platform admin if access is blocked

---

## Hand-Off Notes

### 🎯 When T005 is Complete:
1. ✅ Document all quota and connector details in YAML above
2. ✅ Confirm all AC items are checked
3. ✅ Verify all 4 required connectors enabled and tested
4. ✅ **Dependency unblocked**: T006 (Power Platform Solution) and T030+ (flows) can proceed
5. ✅ Power Automate infrastructure ready for flow development

### 📋 Next Steps:
- **T006** (Polly Gray): Create Power Platform Solution Container
- **T007** (Michael Gray): Verify AI Builder Capacity
- **T030+** (John Shelby): Build Power Automate flows

---

## Session Log

| Time | Step | Status | Notes |
|------|------|--------|-------|
| — | Pre-Flight Checks | PENDING | Awaiting T001 completion |
| — | Step 1: Cloud Flow Quotas | PENDING | — |
| — | Step 2: Enable Connectors | PENDING | — |
| — | Step 3: AI Builder Capacity | PENDING | — |
| — | Step 4: Test Connectivity | PENDING | — |
| — | Step 5: Document Status | PENDING | — |
| — | **COMPLETE** | — | — |

---

*End T005 Execution Checklist*
