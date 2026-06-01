# Dataverse Schema: Mode 2 — Multi-Form PDF Splitter

**Feature**: 004-multi-form-pdf-splitter  
**Branch**: 004-multi-form-pdf-splitter  
**Tasks**: T006–T012  
**Generated**: 2025-07-17  
**Version**: 1.0.0

---

## Overview

This document provides the complete Dataverse schema specification for Mode 2. It covers:

1. **New Table**: `BatchSubmission` — tracks the lifecycle of every multi-form PDF batch upload
2. **Extended Table**: `FormSubmission` — 2 new nullable columns linking individual forms to their parent batch
3. **New Global Option Set**: `BatchStatus` — 12-state lifecycle option set

Apply changes in this order:
```
T006 → (T007, T008, T009, T010 in parallel) → T011 → T012
```

---

## Section 1: New Global Option Set — BatchStatus

**Tasks**: T008  
**Type**: Global Option Set (reusable across tables)  
**Internal Name**: `cr_batchstatus`  
**Display Name**: Batch Status

### Build Steps

1. Navigate to **Power Platform Maker Portal** → **Dataverse** → **Option Sets** → **+ New option set**
2. Set Display Name = `Batch Status`
3. Set External Name = `cr_batchstatus`
4. Add all values below exactly as specified (including spacing and casing):

### Option Set Values

| Value Label | Description | Terminal? |
|---|---|---|
| `Uploaded` | Batch PDF received by SharePoint; not yet validated | No |
| `Validating` | Checking page count, file size, duplicate detection | No |
| `ValidationFailed` | Invalid file (odd pages, too large, duplicate, corrupt) | **Yes** |
| `Splitting` | Muhimbi PDF split operation in progress | No |
| `SplitFailed` | Split failed mid-process; partial results preserved | No |
| `RetryPending` | Operator requested retry of failed split | No |
| `SplittingComplete` | All individual PDFs created; pipeline feeding complete | No |
| `Feeding` | Split PDFs being moved to FormIntake/ root | No |
| `Complete` | All child forms reached terminal state successfully | **Yes** |
| `PartiallyFailed` | All child forms terminal but some failed | **Yes** |
| `Processing` | Child forms are actively being extracted/reviewed | No |
| `FeedComplete` | All split PDFs have been deposited to pipeline intake | No |

> **Note on terminal states**: `ValidationFailed`, `Complete`, and `PartiallyFailed` are terminal. The stale-batch monitor query must exclude all three: `BatchStatus ne 'Complete' and BatchStatus ne 'PartiallyFailed' and BatchStatus ne 'ValidationFailed'`.

4. Click **Save**

---

## Section 2: New Table — BatchSubmission

**Task**: T006 (base), T007, T009, T010 (columns)  
**Table Display Name**: `Batch Submission`  
**Table Internal Name**: `cr_batchsubmission`  
**Primary Column**: `BatchDisplayID`

### 2.1 — Create Table (T006)

1. Navigate to **Dataverse** → **Tables** → **+ New table** → **Set advanced properties**
2. Set Display Name = `Batch Submission`
3. Set Plural Display Name = `Batch Submissions`
4. Primary column:
   - Display Name = `Batch Display ID`
   - Internal Name = `cr_batchdisplayid`
   - Data Type = `Text`
   - Max Length = `30`
   - Required = `Business Required`
   - Format: `BATCH-YYYYMMDD-NNN` (enforced by flow logic, not Dataverse constraint)
5. Click **Save and Exit**

---

### 2.2 — Core Metadata Columns (T007)

Add each column via **Dataverse** → **Tables** → `Batch Submission` → **Columns** → **+ Add column**:

| Display Name | Internal Name | Type | Max Length / Precision | Required | Default | Notes |
|---|---|---|---|---|---|---|
| Source File Name | `cr_sourcefilename` | Text | 255 | Required | — | Original uploaded filename |
| Source File Size Bytes | `cr_sourcefilesizebytes` | Whole Number | — | Required | — | File size in bytes; used for dedup |
| Source File Page Count | `cr_sourcefilepagecount` | Whole Number | — | Required | — | Total pages in the batch PDF |
| Source File Hash | `cr_sourcefilehash` | Text | 64 | Optional | — | SHA-256 hash; nullable for Phase 1 |
| Total Form Count | `cr_totalformcount` | Whole Number | — | Required | — | Computed: PageCount ÷ 2 |
| Uploaded By | `cr_uploadedby` | Lookup → User | — | Optional | — | Entra ID of uploading user |
| Upload Timestamp | `cr_uploadtimestamp` | Date and Time | — | Required | — | UTC; set at record creation; immutable |

---

### 2.3 — BatchStatus Column (T008)

| Display Name | Internal Name | Type | Option Set | Required | Default |
|---|---|---|---|---|---|
| Batch Status | `cr_batchstatus` | Choice (Option Set) | `cr_batchstatus` (global) | Required | `Uploaded` |

---

### 2.4 — Counter and Timestamp Columns (T009)

| Display Name | Internal Name | Type | Precision | Required | Default | Notes |
|---|---|---|---|---|---|---|
| Forms Completed | `cr_formscompleted` | Whole Number | — | Optional | `0` | Rollup count updated by Flow-01B |
| Forms In Review | `cr_formsinreview` | Whole Number | — | Optional | `0` | Rollup count |
| Forms Failed | `cr_formsfailed` | Whole Number | — | Optional | `0` | Rollup count |
| Forms Processing | `cr_formsprocessing` | Whole Number | — | Optional | `0` | Rollup count |
| Completion Percentage | `cr_completionpercentage` | Decimal Number | 2 decimal places, min 0, max 100 | Optional | `0` | Computed: FormsCompleted / TotalFormCount × 100 |
| Split Start Timestamp | `cr_splitstarttimestamp` | Date and Time | — | Optional | — | Set when Splitting begins |
| Split End Timestamp | `cr_splitendtimestamp` | Date and Time | — | Optional | — | Set when SplittingComplete |
| Completion Timestamp | `cr_completiontimestamp` | Date and Time | — | Optional | — | Set when terminal state reached |
| Last Progress Timestamp | `cr_lastprogresstimestamp` | Date and Time | — | Optional | — | Updated on every child status change; used by stale-batch monitor |

---

### 2.5 — Operational Columns (T010)

| Display Name | Internal Name | Type | Max Length | Required | Default | Notes |
|---|---|---|---|---|---|---|
| Error Details | `cr_errordetails` | Multiline Text | 4000 | Optional | — | Error message if split failed or validation failed |
| Last Successful Split Index | `cr_lastsuccessfulsplitindex` | Whole Number | — | Optional | — | Index of last successfully split form (for resume-on-failure) |
| SharePoint Batch Folder Path | `cr_sharepointbatchfolderpath` | Text | 500 | Optional | — | Full path: `FormIntake/Batches/{BatchDisplayID}/` |
| Original File SharePoint ID | `cr_originalfilesharepointid` | Text | 255 | Optional | — | SharePoint item ID of the retained original batch PDF |

---

### 2.6 — Complete BatchSubmission Column Inventory

| # | Display Name | Internal Name | Type | Required | Default |
|---|---|---|---|---|---|
| 1 | Batch Display ID | `cr_batchdisplayid` | Text (Primary) | Required | — |
| 2 | Source File Name | `cr_sourcefilename` | Text 255 | Required | — |
| 3 | Source File Size Bytes | `cr_sourcefilesizebytes` | Whole Number | Required | — |
| 4 | Source File Page Count | `cr_sourcefilepagecount` | Whole Number | Required | — |
| 5 | Source File Hash | `cr_sourcefilehash` | Text 64 | Optional | — |
| 6 | Total Form Count | `cr_totalformcount` | Whole Number | Required | — |
| 7 | Uploaded By | `cr_uploadedby` | Lookup → User | Optional | — |
| 8 | Upload Timestamp | `cr_uploadtimestamp` | Date and Time | Required | — |
| 9 | Batch Status | `cr_batchstatus` | Choice | Required | Uploaded |
| 10 | Forms Completed | `cr_formscompleted` | Whole Number | Optional | 0 |
| 11 | Forms In Review | `cr_formsinreview` | Whole Number | Optional | 0 |
| 12 | Forms Failed | `cr_formsfailed` | Whole Number | Optional | 0 |
| 13 | Forms Processing | `cr_formsprocessing` | Whole Number | Optional | 0 |
| 14 | Completion Percentage | `cr_completionpercentage` | Decimal | Optional | 0 |
| 15 | Split Start Timestamp | `cr_splitstarttimestamp` | Date and Time | Optional | — |
| 16 | Split End Timestamp | `cr_splitendtimestamp` | Date and Time | Optional | — |
| 17 | Completion Timestamp | `cr_completiontimestamp` | Date and Time | Optional | — |
| 18 | Last Progress Timestamp | `cr_lastprogresstimestamp` | Date and Time | Optional | — |
| 19 | Error Details | `cr_errordetails` | Multiline Text | Optional | — |
| 20 | Last Successful Split Index | `cr_lastsuccessfulsplitindex` | Whole Number | Optional | — |
| 21 | SharePoint Batch Folder Path | `cr_sharepointbatchfolderpath` | Text 500 | Optional | — |
| 22 | Original File SharePoint ID | `cr_originalfilesharepointid` | Text 255 | Optional | — |
| 23 | Created On | `createdon` | Date and Time | Auto | — |
| 24 | Modified On | `modifiedon` | Date and Time | Auto | — |

---

## Section 3: Extended Table — FormSubmission

**Tasks**: T011 (BatchID lookup), T012 (FormIndexInBatch integer)  
**CRITICAL**: Both new columns are **NULLABLE**. Existing Mode 1 FormSubmission records must remain unaffected with NULL values in both columns.

### 3.1 — Add BatchID Lookup Column (T011)

1. Navigate to **Dataverse** → **Tables** → `Form Submission` → **Columns** → **+ Add column**
2. Configure:

| Field | Value |
|---|---|
| Display Name | `Batch ID` |
| Internal Name | `cr_batchid` |
| Data Type | `Lookup` |
| Related Table | `Batch Submission` (`cr_batchsubmission`) |
| Required | **Optional (nullable)** |
| Description | "Links this form to its parent batch. NULL for Mode 1 single-form uploads; populated for Mode 2 batch-split forms." |

3. Click **Save**
4. **VERIFY**: In **Dataverse** → **Tables** → `Form Submission` → **Views** → open default view → confirm existing records show blank (null) for `Batch ID`
5. **VERIFY**: In **Power Automate**, run the existing `VA-Form-Intake-Pipeline` (Flow 1) on a test single-form PDF → confirm it runs without errors → FormSubmission record created with `Batch ID = null`

### 3.2 — Add FormIndexInBatch Column (T012)

1. Navigate to **Dataverse** → **Tables** → `Form Submission` → **Columns** → **+ Add column**
2. Configure:

| Field | Value |
|---|---|
| Display Name | `Form Index In Batch` |
| Internal Name | `cr_formindexinbatch` |
| Data Type | `Whole Number` |
| Min Value | 1 |
| Max Value | 500 |
| Required | **Optional (nullable)** |
| Description | "Sequential 1-based position of this form within its parent batch. NULL for Mode 1 uploads. Example: Form 3 of 20 → value = 3." |

3. Click **Save** and **Publish table**
4. **VERIFY**:
   - Open any existing `FormSubmission` record → both `Batch ID` and `Form Index In Batch` should be blank/null
   - Run the existing pipeline on a test single-form PDF → confirm both new columns remain null
   - Confirm Flow 1, Flow 2, Flow 3, Flow 4 all complete without errors

---

## Section 4: Relationships

### BatchSubmission → FormSubmission (One-to-Many)

| Property | Value |
|---|---|
| Relationship Type | One-to-Many (1:N) |
| Primary Table | `BatchSubmission` (the "one") |
| Related Table | `FormSubmission` (the "many") |
| Foreign Key Column | `FormSubmission.cr_batchid` |
| Cascade Delete | **None** (batch deletion must NOT cascade to forms; forms are independent records) |
| Cascade Assign | None |
| Description | One batch upload produces 0 to N individual form submissions. Mode 1 FormSubmissions have no parent batch. |

> **Important**: The relationship is created automatically when the Lookup column is added to FormSubmission in T011. No manual relationship creation is needed.

---

## Section 5: AuditLog ActionType Extensions

The existing `AuditLog` table requires no schema changes. The new `ActionType` values below are string constants passed by the new flows to the existing `Audit-Event-Logger` subflow.

| ActionType Value | Emitted By | When |
|---|---|---|
| `BatchUpload` | Flow-01 | Batch PDF first received and validated |
| `BatchValidation` | Flow-01 | On both validation success and failure |
| `BatchSplitStart` | Flow-01 | Before first Muhimbi split call |
| `BatchSplitComplete` | Flow-01 | After all forms split successfully |
| `BatchSplitFailed` | Flow-01 | When split fails mid-loop |
| `BatchFormDeposit` | Flow-01 | Each individual split PDF moved to pipeline |
| `BatchStatusUpdate` | Flow-01B | Each time BatchSubmission counters are updated |
| `BatchComplete` | Flow-01B | When all child forms reach terminal state |
| `StaleBatchAlert` | Flow-01C | When a batch exceeds 24 hours with no progress |

---

## Section 6: Validation Checklist

After completing T006–T012, verify all of the following before starting Phase 3 (flow building):

```
Schema Verification — Phase 2 Exit Checklist:
[ ] BatchStatus option set created with exactly 12 values (exact spelling)
[ ] BatchSubmission table exists with 22+ columns (all from §2.6)
[ ] BatchSubmission.cr_batchstatus default = Uploaded
[ ] FormSubmission.cr_batchid column is Lookup type → BatchSubmission, nullable
[ ] FormSubmission.cr_formindexinbatch column is Whole Number, nullable
[ ] Both FormSubmission columns are published
[ ] Existing FormSubmission records show null for both new columns
[ ] Mode 1 test run (single-form PDF) completes without errors
[ ] Flow 1, Flow 2, Flow 3, Flow 4 all show "On" and no schema errors
```

---

**Status**: Specification complete — ready for manual implementation  
**Estimated build time**: 2–3 hours (including parallel T007/T008/T009/T010)  
**Version**: 1.0.0 | **Generated**: 2025-07-17
