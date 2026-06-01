# 🚀 Arthur Shelby — Phase 1 Quick Start Guide

**Role**: ⚙️ Environment & Infrastructure Specialist  
**Mission**: Set up Power Platform, SharePoint, and Entra ID for VA Form extraction pipeline  
**Duration**: 2–3 hours (5 sequential/parallel tasks)  
**Start Date**: 2026-04-24  

---

## 📋 Your 5 Tasks

| # | Issue | Task | Est. Time | Execution Checklist |
|---|-------|------|-----------|-------------------|
| 1 | #3 | Create/Verify Power Platform Environment | 30-45 min | [T001](T001-POWER-PLATFORM-ENV-SETUP.md) |
| 2 | #4 | Create SharePoint Site | 20-30 min | [T002](T002-SHAREPOINT-SITE-CREATION.md) |
| 3 | #5 | Create SharePoint Library | 15-20 min | [T003](T003-SHAREPOINT-LIBRARY-CREATION.md) |
| 4 | #7 | Verify Power Automate Quotas | 20-30 min | [T005](T005-POWER-AUTOMATE-QUOTAS-CONNECTORS.md) |
| 5 | #10 | Configure Entra ID Auth | 30-45 min | [T008](T008-ENTRA-ID-CONFIGURATION.md) |

---

## ✅ Getting Started NOW

### Step 1️⃣: Open T001 Checklist
Open this file: `.squad/sessions/T001-POWER-PLATFORM-ENV-SETUP.md`

**Key Sections**:
- ✅ **Pre-Flight Checks** — Verify you have permissions
- 📋 **Execution Steps** (Step 1-4) — Follow exactly
- 📝 **Documentation** — Record environment details
- ✅ **AC Checklist** — Verify all Acceptance Criteria

### Step 2️⃣: Pre-Flight Checks (5 minutes)
```
☐ I have M365 tenant admin access
☐ I have Power Platform license
☐ I can access https://admin.powerplatform.microsoft.com
☐ Tenant is not restricted (no environment creation block)
```
✅ **If all checked**: Proceed to Step 3  
❌ **If any unchecked**: Get help from your IT admin

### Step 3️⃣: Execute T001 (30-45 minutes)
Follow the 4-step process in the checklist:
1. **Step 1**: Access Power Platform Admin Center
2. **Step 2**: Check for existing environment or create new one
3. **Step 3**: Create Dataverse database
4. **Step 4**: Verify access & connectivity

⏱️ **Expected time: 45 minutes** (includes 10-15 min for provisioning)

### Step 4️⃣: Document Environment Details
In the checklist, find this section:
```yaml
VA_FORM_EXTRACTION_ENV:
  name: "VA-Form-Extraction"
  environment_id: "[ PASTE HERE ]"
  environment_url: "[ PASTE HERE ]"
  tenant_id: "[ PASTE HERE ]"
```

**Where to find these values**:
- **Environment ID**: Power Platform Admin Center → Environment Details → Environment ID
- **Environment URL**: Power Platform Admin Center → Environment Details → Environment URL
- **Tenant ID**: Microsoft Entra admin center → Dashboard → Tenant info

### Step 5️⃣: Verify Acceptance Criteria
In the checklist, check off all 4 AC items:
```
✅ AC1: Power Platform environment created or verified
✅ AC2: Admin access confirmed
✅ AC3: Environment details documented
✅ AC4: Report: Environment ready for connectors
```

### Step 6️⃣: Update Your Progress
Once T001 is complete:
- [ ] I have the checklist filled out with environment details
- [ ] All 4 AC items are checked
- [ ] I can access the environment and Dataverse

✅ **T001 is done! Proceed to T002**

---

## 🔄 Then Do T002 → T003 → T005 → T008

### Workflow for Each Task
1. Open the corresponding checklist (T002, T003, T005, T008)
2. Follow the same pattern:
   - Pre-flight checks
   - Execute steps 1-N
   - Document details
   - Verify AC items
3. Move to next task when previous one is complete

### ⏱️ Timeline (Sequential)
```
T001 (30-45 min) 
  ↓ [Unblocks]
T002 (20-30 min) → T003 (15-20 min)
  ↓ [Parallel]
T005 (20-30 min) [can start during T002-T003]
T008 (30-45 min) [can start during T002-T003]

Total: 2-3 hours (5 tasks)
```

### 💡 Pro Tips
- **Work on T005 & T008 in parallel** while waiting for T002/T003
- **Save all documentation** as you go (YAML sections in each checklist)
- **Test as you complete** each task (don't assume things work)
- **Take screenshots** of important settings (environment ID, library URL, etc.)

---

## 📞 Need Help?

### Common Questions

**Q: I don't have admin access to Power Platform**
> Contact your M365 tenant admin. Ask for "Power Platform Administrator" role.

**Q: Environment creation is taking too long (>15 minutes)**
> This is normal. Wait up to 30 minutes. If still pending, contact Microsoft Support.

**Q: I can't find the environment after creation**
> Hard refresh (Ctrl+F5) the Power Platform Admin Center page.

**Q: Where do I save client secrets for T008?**
> **NEVER** in GitHub or source code. Use Azure Key Vault or secure password manager (1Password, Bitwarden, etc.).

**Q: I'm blocked and can't proceed**
> Post to GitHub issue with:
> - What task you're on
> - What step failed
> - Any error message
> - Then contact Tommy Shelby

---

## 🎯 Success Criteria

### When ALL 5 Tasks are Complete, You Should Have:

✅ **Environment**:
- Power Platform environment named `VA-Form-Extraction`
- Dataverse database provisioned
- Environment ID, URL, tenant ID documented

✅ **SharePoint**:
- SharePoint site at `/sites/VAFormProcessing`
- Document library `FormIntake` inside
- Versioning enabled
- Site & library URLs documented

✅ **Power Automate**:
- All 4 required connectors enabled (SharePoint, Dataverse, D365, AI Builder)
- Quotas verified sufficient (≥50 flows, ≥10,000 runs/month)
- AI Builder capacity confirmed (≥100 calls/month)
- Test flow created and connectors tested

✅ **Entra ID**:
- App registration created: `VA Form Extraction Pipeline`
- Client ID and Client Secret generated (secret saved securely)
- API permissions granted (Microsoft Graph, D365, Dataverse)
- `VA Staff` security group created
- OAuth2 authentication tested and working

✅ **Documentation**:
- All environment/site/library URLs recorded
- All IDs documented (environment, client, tenant, group)
- Credentials stored securely (NOT in GitHub)
- No errors or blockers

---

## 📄 Quick File Reference

All execution checklists are in: `.squad/sessions/`

```
├── ARTHUR-PHASE1-DASHBOARD.md          [Master overview - read first]
├── T001-POWER-PLATFORM-ENV-SETUP.md    [START HERE - Task #1]
├── T002-SHAREPOINT-SITE-CREATION.md    [Task #2]
├── T003-SHAREPOINT-LIBRARY-CREATION.md [Task #3]
├── T005-POWER-AUTOMATE-QUOTAS-CONNECTORS.md [Task #4]
└── T008-ENTRA-ID-CONFIGURATION.md      [Task #5]
```

---

## 🚦 Status Dashboard

| Task | Status | Checklist | Progress |
|------|--------|-----------|----------|
| T001 | 🔴 READY | ✅ [T001](T001-POWER-PLATFORM-ENV-SETUP.md) | 0% |
| T002 | 🔴 BLOCKED (waiting for T001) | ✅ [T002](T002-SHAREPOINT-SITE-CREATION.md) | 0% |
| T003 | 🔴 BLOCKED (waiting for T002) | ✅ [T003](T003-SHAREPOINT-LIBRARY-CREATION.md) | 0% |
| T005 | 🔴 BLOCKED (waiting for T001) | ✅ [T005](T005-POWER-AUTOMATE-QUOTAS-CONNECTORS.md) | 0% |
| T008 | 🔴 BLOCKED (waiting for T001) | ✅ [T008](T008-ENTRA-ID-CONFIGURATION.md) | 0% |

---

## 🎬 Let's Go!

### Right Now:
1. Open: `.squad/sessions/T001-POWER-PLATFORM-ENV-SETUP.md`
2. Read the **Pre-Flight Checks** section
3. Verify you have permissions
4. Start **Step 1: Access Power Platform Admin Center**
5. Follow each step in order

### Remember:
- ✅ You have comprehensive checklists
- ✅ Each one has step-by-step guidance
- ✅ Troubleshooting is built-in
- ✅ Documentation templates provided
- ✅ You got this! 💪

**Estimated time to complete all 5 tasks: 2-3 hours**  
**Phase 1 gate review: Tommy Shelby (when all complete)**

---

*Good luck, Arthur! The foundation you build now enables the entire project. 🏗️*
