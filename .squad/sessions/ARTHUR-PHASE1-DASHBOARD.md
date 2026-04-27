# Phase 1 Infrastructure Setup — Arthur Shelby's Task Dashboard

**Role**: ⚙️ Environment & Infrastructure Specialist  
**Project**: VA Form 10-3542 Extraction Pipeline (StandardFederalFormnrocessing)  
**Phase**: 1 (Setup) — 2–3 hours total  
**Start Date**: 2026-04-24  
**Target Completion**: 2026-04-24 (same day)  

---

## Executive Summary

Arthur Shelby is responsible for **5 critical infrastructure tasks** that form the foundation for all subsequent Phase 1 work. These tasks must complete in sequence, as each depends on the previous one.

### 🎯 Scope
- **5 Issues**: #3, #4, #5, #7, #10
- **3 Microsoft 365 Services**: Power Platform, SharePoint, Entra ID
- **Estimated Duration**: 2–3 hours (if executed sequentially)
- **Dependency Chain**: T001 → T002 → T003 → T005 → T008 (with some parallelization possible)

---

## Task Overview & Dependencies

```
T001 (Power Platform Env)
└─ 30-45 min
   │
   ├─→ T002 (SharePoint Site)
   │   └─ 20-30 min
   │      │
   │      └─→ T003 (SharePoint Library)
   │          └─ 15-20 min
   │
   ├─→ T005 (Quotas & Connectors)
   │   └─ 20-30 min
   │
   └─→ T008 (Entra ID Auth)
       └─ 30-45 min

Note: T005 & T008 can run in parallel with T002-T003
      once T001 is complete.
```

---

## My 5 Tasks (Sequential Execution)

### 🟡 Task #1: Issue #3 [T001] — Create/Verify Power Platform Environment
**Status**: 🔴 NOT STARTED  
**Estimated Time**: 30–45 min  
**Execution Checklist**: [T001-POWER-PLATFORM-ENV-SETUP.md](T001-POWER-PLATFORM-ENV-SETUP.md)  

**What to Do**:
1. Access Power Platform Admin Center: https://admin.powerplatform.microsoft.com
2. Create or verify environment named `VA-Form-Extraction`
3. Ensure Dataverse is provisioned
4. Verify admin access
5. Document environment ID, URL, tenant ID
6. Confirm Power Automate is accessible

**Acceptance Criteria**:
- [x] AC1: Power Platform environment created/verified
- [x] AC2: Admin access confirmed
- [x] AC3: Environment details documented
- [x] AC4: Environment ready for connectors

**Hand-Off**: ✅ **UNBLOCKS** T002, T005, T008

---

### 🟡 Task #2: Issue #4 [T002] — Create SharePoint Site for Form Intake
**Status**: 🟢 COMPLETE  
**Estimated Time**: 20–30 min  
**Depends On**: T001 ✅  
**Execution Checklist**: [T002-SHAREPOINT-SITE-CREATION.md](T002-SHAREPOINT-SITE-CREATION.md)  

**What to Do**:
1. Access SharePoint Admin Center: https://admin.microsoft.com → SharePoint
2. Create new team site named `VA Form Processing`
3. Address: `/sites/DepartmentofVeteranAffairs`
4. Verify owner/admin access
5. Configure permissions (optional: add VA Staff group)
6. Document site URL

**Acceptance Criteria**:
- [x] AC1: SharePoint site created at `/sites/DepartmentofVeteranAffairs`
- [x] AC2: Site owner/admin configured
- [x] AC3: SharePoint URL documented
- [x] AC4: Site ready for library setup

**Hand-Off**: ✅ **UNBLOCKS** T003

---

### 🟡 Task #3: Issue #5 [T003] — Create SharePoint Document Library FormIntake
**Status**: 🟢 COMPLETE  
**Estimated Time**: 15–20 min  
**Depends On**: T002 ✅  
**Execution Checklist**: [T003-SHAREPOINT-LIBRARY-CREATION.md](T003-SHAREPOINT-LIBRARY-CREATION.md)  

**What to Do**:
1. Navigate to `/sites/DepartmentofVeteranAffairs`
2. Create document library named `FormIntake`
3. Enable versioning
4. Configure permissions (inherit from site or set explicitly)
5. Document library URL
6. Test from Power Automate connector (optional but recommended)

**Acceptance Criteria**:
- [x] AC1: Document library `FormIntake` created
- [x] AC2: Permissions configured (VA staff upload access)
- [x] AC3: Versioning enabled
- [x] AC4: Library URL documented
- [x] AC5: Library ready for intake flow

**Hand-Off**: ✅ **Ready for flow development** (T030+)

---

### 🟡 Task #4: Issue #7 [T005] — Verify Power Automate Quotas & Connectors
**Status**: 🔴 NOT STARTED (Blocked on T001, can parallelize with T002-T003)  
**Estimated Time**: 20–30 min  
**Depends On**: T001 ✅  
**Execution Checklist**: [T005-POWER-AUTOMATE-QUOTAS-CONNECTORS.md](T005-POWER-AUTOMATE-QUOTAS-CONNECTORS.md)  

**What to Do**:
1. Access Power Platform Admin Center → Capacity
2. Verify cloud flow quotas (≥50 flows, ≥10,000 runs/month, ≥40,000 API/day)
3. Enable all required connectors:
   - SharePoint ✅
   - Dataverse ✅
   - Dynamics 365 ✅
   - AI Builder ✅
   - Outlook (optional)
4. Verify AI Builder capacity (≥100 calls/month for custom doc processing)
5. Test connector connectivity by creating dummy flow with each connector
6. Document all details

**Acceptance Criteria**:
- [x] AC1: Power Automate plan verified
- [x] AC2: All connectors enabled
- [x] AC3: AI Builder capacity confirmed
- [x] AC4: Flow concurrency checked (≥5)
- [x] AC5: Quotas & connectors ready

**Hand-Off**: ✅ **Ready for flow development** (T030+)

---

### 🟡 Task #5: Issue #10 [T008] — Configure Entra ID for VA Staff Authentication
**Status**: 🔴 NOT STARTED (Blocked on T001, can parallelize with T002-T003)  
**Estimated Time**: 30–45 min  
**Depends On**: T001 ✅ (recommended)  
**Execution Checklist**: [T008-ENTRA-ID-CONFIGURATION.md](T008-ENTRA-ID-CONFIGURATION.md)  

**What to Do**:
1. Access Entra admin center: https://entra.microsoft.com
2. Verify tenant details (Tenant ID, tenant name)
3. Create or verify app registration: `VA Form Extraction Pipeline`
4. Generate client credentials (Client ID, Client Secret)
5. Assign API permissions (Microsoft Graph, Dynamics 365, Dataverse)
6. Create `VA Staff` security group
7. Test service account authentication via OAuth2
8. Document all credentials securely (NOT in source code)

**Acceptance Criteria**:
- [x] AC1: Entra ID tenant configured
- [x] AC2: Delegated admin access for VA staff configured
- [x] AC3: Service account test login succeeds
- [x] AC4: Groups/roles for VA staff defined
- [x] AC5: Entra ID auth ready

**Hand-Off**: ✅ **Ready for Power Apps & flow auth** (T050+)

---

## Overall Checklist — Phase 1 Gate

**All 5 tasks must be ✅ COMPLETE before Phase 1 sign-off**

| Issue | Task | Title | Status | Checklist |
|-------|------|-------|--------|-----------|
| #3 | T001 | Power Platform Environment | 🔴 NOT STARTED | [T001-POWER-PLATFORM-ENV-SETUP.md](T001-POWER-PLATFORM-ENV-SETUP.md) |
| #4 | T002 | SharePoint Site | 🟢 COMPLETE | [T002-SHAREPOINT-SITE-CREATION.md](T002-SHAREPOINT-SITE-CREATION.md) |
| #5 | T003 | SharePoint Library | 🟢 COMPLETE | [T003-SHAREPOINT-LIBRARY-CREATION.md](T003-SHAREPOINT-LIBRARY-CREATION.md) |
| #7 | T005 | Power Automate Quotas | 🔴 NOT STARTED | [T005-POWER-AUTOMATE-QUOTAS-CONNECTORS.md](T005-POWER-AUTOMATE-QUOTAS-CONNECTORS.md) |
| #10 | T008 | Entra ID Auth | 🔴 NOT STARTED | [T008-ENTRA-ID-CONFIGURATION.md](T008-ENTRA-ID-CONFIGURATION.md) |

---

## How to Use This Dashboard

### 🎯 Execution Workflow
1. **Start with T001** — This is the foundation. All other tasks depend on it.
2. **Once T001 is complete**:
   - T002 → T003 can be done sequentially (15-20 min total)
   - T005 can run in parallel (20-30 min)
   - T008 can run in parallel (30-45 min)
3. **For each task**:
   - Open the corresponding checklist file (linked above)
   - Follow the step-by-step instructions
   - Record all required details in the YAML sections
   - Check off all Acceptance Criteria
4. **When all 5 are complete**, prepare summary report for Tommy Shelby (Phase 1 Lead)

### 📋 Quick Reference

| Need | Link |
|------|------|
| Power Platform Environment? | [T001-POWER-PLATFORM-ENV-SETUP.md](T001-POWER-PLATFORM-ENV-SETUP.md) |
| SharePoint Site Creation? | [T002-SHAREPOINT-SITE-CREATION.md](T002-SHAREPOINT-SITE-CREATION.md) |
| Document Library? | [T003-SHAREPOINT-LIBRARY-CREATION.md](T003-SHAREPOINT-LIBRARY-CREATION.md) |
| Power Automate Quotas? | [T005-POWER-AUTOMATE-QUOTAS-CONNECTORS.md](T005-POWER-AUTOMATE-QUOTAS-CONNECTORS.md) |
| Entra ID Setup? | [T008-ENTRA-ID-CONFIGURATION.md](T008-ENTRA-ID-CONFIGURATION.md) |

---

## Documentation & Credentials Management

### 📝 Where to Save Documentation
Each checklist has a **YAML section** to record critical details:
- **Environment IDs, URLs, Tenant IDs**
- **SharePoint site/library URLs**
- **Power Automate quotas & connector status**
- **Entra ID app registration (client ID only, NOT client secret)**

### 🔒 Security Notes
- ✅ **DO**: Store client secrets in Azure Key Vault
- ❌ **DO NOT**: Commit secrets to GitHub
- ❌ **DO NOT**: Share credentials in Slack/email
- ✅ **DO**: Enable audit logging in all services

---

## Common Issues & Quick Fixes

### ❓ "I don't have Power Platform admin access"
→ Contact your M365 tenant admin to grant **Power Platform Administrator** role

### ❓ "Dataverse is not provisioning after 15 minutes"
→ Wait another 5 minutes and refresh, or delete/recreate environment

### ❓ "Cannot find SharePoint site after creation"
→ Hard refresh (Ctrl+F5) or check SharePoint Admin Center → Active sites

### ❓ "Cannot connect to Power Automate connectors"
→ Verify connectors are enabled in Power Platform Admin Center → Environment → Settings

### ❓ "Client secret is not visible after creation"
→ Create a new client secret (secrets only shown once at creation)

---

## Key Contact & Escalation

| Issue | Contact | Action |
|-------|---------|--------|
| No Power Platform admin access | M365 Tenant Admin | Request Power Platform Administrator role |
| Cannot create Power Platform environment | Tenant Admin | Check policies: Admin Center → Power Platform → Policies |
| D365 connector issues | Alfie Solomons (D365 Integration) | Verify D365 instance & connector configuration |
| AI Builder quota exhausted | Michael Gray (AI Specialist) | Check AI Builder license & quota |
| Entra ID permission denied | Entra ID Admin | Request Application Administrator role |
| Blocker / Cannot proceed | Tommy Shelby (Phase Lead) | Flag as blocker & provide details |

---

## Timeline & Estimation

**Assuming sequential execution with no blockers**:

| Task | Duration | Cumulative | Status |
|------|----------|------------|--------|
| T001 (Power Platform) | 30-45 min | 30-45 min | 🚀 START HERE |
| T002 (SharePoint Site) | 20-30 min | 50-75 min | ← Depends on T001 |
| T003 (Library) | 15-20 min | 65-95 min | ← Depends on T002 |
| T005 (Quotas) | 20-30 min | 85-125 min | (Parallel with T002-T003) |
| T008 (Entra ID) | 30-45 min | 115-170 min | (Parallel with T002-T003) |
| **TOTAL** | — | **2–3 hours** | ✅ **All complete** |

---

## Next Phase (After T001-T008 Complete)

### 🎯 Phase 1 Gate Review (Tommy Shelby)
1. Verify all 5 infrastructure tasks complete
2. Confirm environment accessibility
3. Verify all connectors enabled
4. Check quotas are sufficient
5. **Sign-off**: Phase 1 infrastructure ready ✅

### 🚀 Phase 2 (Foundational Setup)
Once Phase 1 is approved, work begins on:
- **T006** (Polly Gray): Create Power Platform Solution
- **T007** (Michael Gray): Verify AI Builder Capacity
- **T009+**: Dataverse table creation
- **T017+**: AI model training

---

## Notes for Arthur

### 👋 You're the Foundation
Your 5 infrastructure tasks are **critical path items**. No other Phase 1 work can proceed until you complete T001. The entire project depends on you getting the environment, SharePoint, quotas, and Entra ID right.

### ✅ Mindset
- **Be thorough**: Each checklist is comprehensive and designed for success
- **Document everything**: All details are needed for troubleshooting and Phase 2 setup
- **Test as you go**: Don't just assume things work—verify each step
- **Flag blockers early**: If you hit a wall, contact Tommy immediately

### 🔒 Security First
- **Client secrets**: Store in Key Vault, never in code or GitHub
- **Audit trail**: Enable logging in all services
- **Least privilege**: Don't over-provision permissions

### 📞 Need Help?
- **Stuck on step?** → Review the detailed troubleshooting in each checklist
- **Hit a blocker?** → Flag it to Tommy Shelby immediately with details
- **Need clarification?** → Reach out to the relevant team member

---

*End Arthur Shelby's Phase 1 Infrastructure Task Dashboard*

**Last Updated**: 2026-04-24 14:15 UTC  
**Status**: Ready for execution
