# Modification Guide: VA-Form-Intake-Pipeline (Flow 1)

**Feature**: 004-multi-form-pdf-splitter  
**Tasks Covered**: T034–T038 (Phase 5: US3 — Existing Flow Modification)  
**Estimated Build Time**: 1–1.5 hours (including testing)  
**Generated**: 2025-07-17  
**Version**: 1.0.0

---

## ⚠️ CRITICAL WARNINGS — READ BEFORE PROCEEDING

> **This document describes changes to a live production flow. Follow ALL safety steps. Do not skip the Mode 1 regression test (T038).**

1. **Take a backup before ANY change** — Export the flow as a `.zip` before editing
2. **Work in a dev/test environment if possible** — Apply changes there first, verify, then apply to production
3. **The True branch of the new condition MUST NOT affect the existing logic** — The new conditional is appended AFTER all existing steps
4. **The False branch (Mode 1 path) must be completely empty** — No logic, no variables, no actions on the False side
5. **Mode 1 single-form processing must work identically after this change** — Verify with T038 before enabling any Mode 2 flows

---

## Overview: What Changes and Why

### Why Flow 1 Needs a Change

When Flow-01 deposits split PDFs into `FormIntake/` root, each filename follows the pattern `BATCH-{YYYYMMDD}-{NNN}-{FormIndex}.pdf`. The existing Flow 1 will create a `FormSubmission` record for each file as it normally does — but without knowing about its parent batch.

To enable batch-level tracking (SC-003, US4), Flow 1 needs to detect when a file is a batch-split form and populate the `BatchID` and `FormIndexInBatch` columns on the newly created `FormSubmission`.

### What Changes

| Location | Change | Impact on Mode 1 |
|---|---|---|
| Last step of `VA-Form-Intake-Pipeline` | Append a new `Condition` action | **Zero** — Mode 1 PDFs never have "BATCH-" filenames; the False branch is empty |
| True branch of new Condition | Parse BatchDisplayID and FormIndex from filename; look up BatchSubmission; update FormSubmission | Only fires for Mode 2 batch-split forms |
| False branch of new Condition | Empty | Mode 1 path is completely unchanged |

### What Does NOT Change

- ✅ The existing trigger configuration (unchanged)
- ✅ All existing validation and processing steps (unchanged)
- ✅ The FormSubmission record creation logic (unchanged)
- ✅ Extraction pipeline hand-off (unchanged)
- ✅ Flow 2, Flow 3, Flow 4, all subflows (not touched)

---

## Part 1: Pre-Change Safety Steps (T034)

### Step 1.1 — Verify Flow 1 is Operational
1. Power Automate → Flows → `VA-Form-Intake-Pipeline`
2. Confirm status: **On** (green); recent runs show **Succeeded**

### Step 1.2 — Export the Flow as Backup
1. Click **Export** → **Package (.zip)**
2. Save to: `SharePoint / Team Documents / Flow Backups / VA-Form-Intake-Pipeline_BEFORE_Mode2_{YYYYMMDD}.zip`

### Step 1.3 — Confirm Prerequisites
- ✅ Azure Function deployed and reachable (see AZURE-FUNCTION-RUNBOOK.md)
- ✅ Azure Function URL + function key recorded
- ✅ `Flow-01-Batch-PDF-Splitter` child flow exists (can be in Draft/Off until Mode 1 test passes)

### Step 1.4 — Open in Edit Mode
1. Navigate to `VA-Form-Intake-Pipeline` → **Edit**
2. ⚠️ Do NOT save until all steps in this runbook are complete and reviewed

---

## Part 2: Insert Page Count Check at the TOP (T035)

> **All new steps go IMMEDIATELY AFTER the trigger and BEFORE any existing actions.**

### Step 2.1 — Add "Get file content" (SharePoint)

Insert as the **first action after the trigger**:

| Field | Value |
|---|---|
| **Action** | SharePoint → **Get file content** |
| **Site Address** | (same as the trigger) |
| **File Identifier** | dynamic content: **Identifier** (from trigger) |
| **Rename** | `Get_PDF_File_Content` |

### Step 2.2 — Add HTTP Action → Azure Function `getPageCount`

Insert immediately after Step 2.1:

| Field | Value |
|---|---|
| **Action** | **HTTP** (built-in) |
| **Method** | `POST` |
| **URI** | `https://{your-function-app}.azurewebsites.net/api/pdf?action=getPageCount&code={function-key}` |
| **Headers** | `Content-Type: application/json` |
| **Body** | `{ "fileContent": "@{body('Get_PDF_File_Content')['$content']}" }` |
| **Rename** | `Get_Page_Count_From_Azure_Function` |

> **The Azure Function returns**: `{ "pageCount": 2 }` (or 4, 6, 40, etc.)
> See AZURE-FUNCTION-RUNBOOK.md for the function contract.

### Step 2.3 — Add the Routing Condition

Insert immediately after Step 2.2:

| Field | Value |
|---|---|
| **Action** | **Condition** |
| **Rename** | `Is multi-form batch PDF?` |
| **Left** (Expression) | `int(body('Get_Page_Count_From_Azure_Function')?['pageCount'])` |
| **Operator** | `is greater than` |
| **Right** (value) | `2` |

---

## Part 3: True Branch — Call Mode 2 Child Flow (T036)

> **Everything in this section goes in the TRUE branch of the condition from Step 2.3.**

### Step 3.1 — Call the Child Flow

| Field | Value |
|---|---|
| **Action** | **Run a Child Flow** |
| **Child Flow** | `Flow-01-Batch-PDF-Splitter` |
| **Input: fileContent** | `body('Get_PDF_File_Content')['$content']` |
| **Input: fileName** | `triggerOutputs()?['body/Name']` |
| **Input: fileSizeBytes** | `triggerOutputs()?['body/Size']` |
| **Input: pageCount** | `int(body('Get_Page_Count_From_Azure_Function')?['pageCount'])` |
| **Input: uploadedBy** | `triggerOutputs()?['body/Editor/Email']` (or your existing uploader expression) |
| **Input: sharePointFileId** | `triggerOutputs()?['body/{Identifier}']` |

### Step 3.2 — Terminate (Success)

After the child flow call, add:

| Field | Value |
|---|---|
| **Action** | **Terminate** |
| **Status** | `Succeeded` |
| **Rename** | `Mode 2 batch handed off — end Flow 1 instance` |

> **Why terminate?** The child flow takes over processing. It splits the original PDF into N individual 2-page files and deposits them back into `FormIntake/` with the `vafe_BATCH-` prefix. Each deposited file re-triggers Flow 1 — that re-trigger has `pageCount = 2` and flows through the False branch (Mode 1 path) normally.

---

## Part 4: False Branch — Existing Mode 1 Path

> **CRITICAL: The False branch must contain ALL existing Flow 1 actions, moved inside the branch.**

### Step 4.1 — Move Existing Actions into the False Branch

There are two acceptable approaches:

**Approach A — Move actions (preferred for clarity):**
1. Use the designer to drag/cut every existing post-trigger action into the False branch of the new condition
2. Re-validate references — dynamic content from the trigger still resolves correctly inside the branch

**Approach B — Use a parallel Scope (simpler):**
1. In the False branch, add a **Scope** action named `Mode1_Original_Logic`
2. Move all existing actions inside this scope

Either way, the False branch must end with whatever your flow's original final action was.

### Step 4.2 — Do NOT Duplicate the Get_PDF_File_Content Action

If any existing Mode 1 step calls `Get file content` again, leave it — it is harmless. Or, optimize by removing the duplicate and referencing `body('Get_PDF_File_Content')['$content']` from the new top-of-flow action.

---

## Part 5: Save and Publish

1. Click **Save** at the top of the flow editor
2. Wait for the green checkmark
3. Status remains **On**
4. Verify the new top-of-flow steps appear in the flow diagram

---

## Part 6: Mode 1 Regression Test — MANDATORY (T038)

> ⚠️ **Do not skip. Run immediately after saving.**

### Test Procedure
1. Upload a 2-page single-form PDF to `FormIntake/` root
   - Filename example: `vafe_TestForm_Regression001.pdf`
2. Wait ~60 seconds for Flow 1 to complete

| Check | Expected | ✓/✗ |
|---|---|---|
| Flow 1 run | **Succeeded** | |
| Azure Function HTTP action | Returned `pageCount: 2` | |
| Routing condition | **False** branch taken | |
| Child flow `Flow-01-Batch-PDF-Splitter` | **Not** called | |
| FormSubmission record | Created normally | |
| `BatchID` column | **NULL** | |
| Flow 2 (Extraction) | Triggered | |

If ANY check fails: roll back via Part 8.

---

## Part 7: Mode 2 Functional Test (after Flow-01 child flow is enabled)

1. Upload a 4-page PDF (2 forms scanned together) to `FormIntake/` root
2. Wait ~30 seconds

| Check | Expected |
|---|---|
| Flow 1 run | **Succeeded**; terminated after child flow call |
| Azure Function | Returned `pageCount: 4` |
| Routing condition | **True** branch |
| Child flow | Invoked with correct inputs |
| BatchSubmission record | Created with status `FeedComplete` |
| `FormIntake/` root | Contains 2 new files: `vafe_BATCH-{YYYYMMDD}-NNN-001.pdf`, `vafe_BATCH-{YYYYMMDD}-NNN-002.pdf` |
| Each split file re-trigger | New Flow 1 runs, both routed to False (Mode 1) branch |
| Original 4-page PDF | Moved to `FormIntake/Batches/{BatchDisplayID}/_original_*.pdf` |

---

## Quick Expression Cheat Sheet

```
Page count from Azure Function:
  int(body('Get_Page_Count_From_Azure_Function')?['pageCount'])

Trigger filename:
  triggerOutputs()?['body/Name']

File content for child flow input:
  body('Get_PDF_File_Content')['$content']
```

---

## Part 8: Rollback Procedure

If Mode 1 regression fails:
1. Power Automate → Flows → `VA-Form-Intake-Pipeline` → **Edit**
2. Delete the `Is multi-form batch PDF?` condition (this also removes the True branch)
3. Move the actions from the False branch back to the top level (or delete the Scope wrapper if you used Approach B)
4. Delete `Get_PDF_File_Content` and `Get_Page_Count_From_Azure_Function` actions
5. Click **Save** → re-run Mode 1 regression
6. If still broken: **Import** the backup `.zip` from Step 1.2

---

**Version**: 1.1.0 | **Architecture**: Child flow pattern, Azure Function for PDF ops  
**⚠️ Mode 1 regression test (T038) is MANDATORY before enabling Flow-01-Batch-PDF-Splitter.**
