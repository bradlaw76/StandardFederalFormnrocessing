# Phase 1: Setup — Parallel Task Checklist

**Duration**: 2–3 hours  
**Status**: Ready to begin  
**Lead**: 🎨 Tommy Shelby  
**Team**: All 8 agents (8 parallel tasks)

---

## Instructions

1. **Convert each task below to a GitHub issue** with label `squad`
2. **Run squad triage** to auto-assign to team members
3. **Run squad loop** to watch for work and track completion
4. **Mark complete** as each team member finishes their task

---

## Phase 1 Parallel Tasks (T001–T008)

### T001: Create/Verify Power Platform Environment
**Owner**: ⚙️ Arthur Shelby (Environment & Infrastructure)  
**Estimated Time**: 30–45 min

**Description**:
Create or verify a Microsoft Power Platform environment for the VA Form extraction project. Verify tenant admin access, environment creation permissions, and basic Power Platform access.

**Acceptance Criteria**:
- [ ] Power Platform environment created or verified
- [ ] Admin access confirmed
- [ ] Environment details documented (environment ID, URL, tenant ID)
- [ ] Report: Environment is ready for connectors setup

**GitHub Issue Title**: `[T001] Create/Verify Power Platform Environment`

---

### T002: Create SharePoint Site for Form Intake
**Owner**: ⚙️ Arthur Shelby (Environment & Infrastructure)  
**Estimated Time**: 20–30 min  
**Depends On**: T001 (can run in parallel)

**Description**:
Create a SharePoint site (`/sites/VAFormProcessing`) to serve as the intake location for VA Form 10-3542 PDFs.

**Acceptance Criteria**:
- [ ] SharePoint site created at `/sites/VAFormProcessing`
- [ ] Site owner/admin configured
- [ ] SharePoint URL documented
- [ ] Report: Site ready for library setup

**GitHub Issue Title**: `[T002] Create SharePoint Site for Form Intake`

---

### T003: Create SharePoint Document Library
**Owner**: ⚙️ Arthur Shelby (Environment & Infrastructure)  
**Estimated Time**: 15–20 min  
**Depends On**: T002 (can run in parallel)

**Description**:
Create a SharePoint document library named `FormIntake` within the VAFormProcessing site to receive uploaded PDFs.

**Acceptance Criteria**:
- [ ] Document library `FormIntake` created in `/sites/VAFormProcessing`
- [ ] Permissions configured (VA staff upload access)
- [ ] Versioning enabled (recommended)
- [ ] Library URL documented
- [ ] Report: Library ready for intake flow

**GitHub Issue Title**: `[T003] Create SharePoint Document Library FormIntake`

---

### T004: Configure D365 Connector
**Owner**: 🔹 Alfie Solomons (Dynamics Integration)  
**Estimated Time**: 30–45 min

**Description**:
Set up the Dynamics 365 connector in Power Platform for the VA Form extraction project. Verify OAuth2 authentication, permissions, and connectivity to the D365 environment.

**Acceptance Criteria**:
- [ ] D365 connector created/configured in Power Platform
- [ ] OAuth2 authentication working
- [ ] Service account or app registration configured
- [ ] Test query to D365 succeeds
- [ ] Report: D365 connector ready for flow integration

**GitHub Issue Title**: `[T004] Configure Dynamics 365 Connector`

---

### T005: Verify Power Automate Quotas & Connectors
**Owner**: ⚙️ Arthur Shelby (Environment & Infrastructure)  
**Estimated Time**: 20–30 min

**Description**:
Verify that all required Power Automate connectors are enabled and quotas are sufficient for the project:
- Power Automate cloud flows
- AI Builder (custom document processing)
- Dataverse
- SharePoint
- D365
- Outlook (notifications)

**Acceptance Criteria**:
- [ ] Power Automate plan verified (sufficient for demo scope)
- [ ] All connectors enabled in environment
- [ ] AI Builder capacity/quota confirmed
- [ ] Flow concurrency checked (≥5 concurrent flows for demo)
- [ ] Report: Quotas & connectors ready

**GitHub Issue Title**: `[T005] Verify Power Automate Quotas & Connectors`

---

### T006: Create Power Platform Solution Container
**Owner**: 📊 Polly Gray (Dataverse Schema Design)  
**Estimated Time**: 15–20 min

**Description**:
Create a Power Platform solution container named `VA-Form-Extraction` in Dataverse. This solution will hold all flows, custom tables, Power Apps, and related components.

**Acceptance Criteria**:
- [ ] Solution `VA-Form-Extraction` created in Dataverse
- [ ] Solution uniquely named (no conflicts)
- [ ] Solution settings documented
- [ ] Solution visible in Power Platform admin center
- [ ] Report: Solution ready for component setup

**GitHub Issue Title**: `[T006] Create Power Platform Solution Container`

---

### T007: Verify AI Builder Capacity
**Owner**: 🔹 Michael Gray (AI Builder Specialist)  
**Estimated Time**: 15–20 min

**Description**:
Verify AI Builder license/trial availability and capacity in the Power Platform environment. Confirm custom document processing models can be created.

**Acceptance Criteria**:
- [ ] AI Builder license/trial active in environment
- [ ] Custom document processing option available
- [ ] Quota for model training documented (≥5 forms minimum)
- [ ] Report: AI Builder ready for model training

**GitHub Issue Title**: `[T007] Verify AI Builder Capacity`

---

### T008: Configure Entra ID for VA Staff Authentication
**Owner**: ⚙️ Arthur Shelby (Environment & Infrastructure)  
**Estimated Time**: 30–45 min

**Description**:
Configure Microsoft Entra ID (Azure AD) authentication for VA staff users. Verify delegated admin setup, user provisioning, and basic authentication flow.

**Acceptance Criteria**:
- [ ] Entra ID tenant configured/verified
- [ ] Delegated admin access for VA staff configured
- [ ] Test user login succeeds
- [ ] Groups/roles for VA staff defined
- [ ] Report: Entra ID auth ready

**GitHub Issue Title**: `[T008] Configure Entra ID for VA Staff Authentication`

---

## Phase 1 Checkpoint (Gate)

**All tasks must complete before Phase 2 starts. Verify:**

- [ ] T001: Power Platform environment ready
- [ ] T002–T003: SharePoint site & library accessible
- [ ] T004: D365 connector callable
- [ ] T005: All connectors enabled, AI Builder quota confirmed
- [ ] T006: Solution container created
- [ ] T007: AI Builder ready
- [ ] T008: Entra ID auth working

**Checkpoint Sign-Off**: 🎨 Tommy Shelby

---

## How to Use This Checklist

### Step 1: Create GitHub Issues
For each task above (T001–T008), create a GitHub issue with:
- **Title**: Copy the "GitHub Issue Title" from above
- **Body**: Copy the "Description" and "Acceptance Criteria"
- **Label**: Add `squad` label
- **Assign**: Leave unassigned (Squad will triage)

### Step 2: Run Squad Triage
```bash
squad triage --filter "label:squad"
```

This will auto-assign each task to the correct team member based on routing rules.

### Step 3: Start Phase 1
```bash
squad loop --interval 5
```

Squad will monitor GitHub for new issues and track completion. As each team member completes their task, Squad logs the completion and monitors for blockers.

### Step 4: Checkpoint
Once all 8 tasks are marked complete (GitHub issues closed), Phase 1 is complete and Phase 2 can begin.

---

## Team Assignment Summary

| Task | Owner | Role |
|------|-------|------|
| T001 | ⚙️ Arthur Shelby | Environment & Infrastructure |
| T002 | ⚙️ Arthur Shelby | Environment & Infrastructure |
| T003 | ⚙️ Arthur Shelby | Environment & Infrastructure |
| T004 | 🔹 Alfie Solomons | Dynamics Integration |
| T005 | ⚙️ Arthur Shelby | Environment & Infrastructure |
| T006 | 📊 Polly Gray | Dataverse Schema Design |
| T007 | 🔹 Michael Gray | AI Builder Specialist |
| T008 | ⚙️ Arthur Shelby | Environment & Infrastructure |

**Note**: Arthur Shelby has 5 tasks (infrastructure heavy), others have 1 each. All run in parallel with no blocking dependencies.

---

## Next Steps

1. ✅ **You are here**: Phase 1 task definitions ready
2. **Convert to GitHub issues** (if using GitHub workflow)
3. **Run `squad triage`** to auto-assign
4. **Run `squad loop`** to monitor and track
5. **Checkpoint complete** → Proceed to Phase 2

**Ready to start?** 🎩
