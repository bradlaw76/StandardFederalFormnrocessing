# Test Scenarios: Mode 2 — Multi-Form PDF Splitter (Phase 8 E2E)

**Feature**: 004-multi-form-pdf-splitter  
**Tasks Covered**: T057–T064 (Phase 8: End-to-End Testing)  
**Generated**: 2025-07-17  
**Version**: 1.0.0

---

## Prerequisites — Before Running Any Test

| Requirement | How to Verify |
|---|---|
| All 3 new flows are **ON** | Power Automate → Flows: Flow-01, Flow-01B, Flow-01C all show "On" |
| Existing pipeline operational | Flow 1 (VA-Form-Intake-Pipeline) shows "On"; recent runs = Succeeded |
| Muhimbi PDF connection active | Power Automate → Connections → Muhimbi PDF = Connected |
| SharePoint folders exist | `FormIntake/Batches/` and `FormIntake/Batches/Incoming/` exist |
| Dataverse schema applied | BatchSubmission table visible; FormSubmission has BatchID and FormIndexInBatch columns |
| Test PDF files prepared | See "Test File Preparation" section below |

---

## Test File Preparation

### How to Create Multi-Page Test PDFs

> **Option A — Adobe Acrobat / Adobe Reader**:  
> Open multiple 2-page PDFs → Organize Pages → Insert pages from another file → Save as a single multi-page PDF.

> **Option B — PowerShell with PDFium (if available)**:  
> Combine multiple 2-page PDFs programmatically.

> **Option C — Online tools**:  
> Use ilovepdf.com or smallpdf.com → Merge PDFs → Upload multiple copies of your 2-page test form.

> **Option D — Muhimbi PDF Connector** (if Muhimbi is configured):  
> Use the `Merge PDF` action in a one-time test flow to combine N copies of the 2-page VA form into one test file.

### Required Test Files

| File Name | Pages | Description | Used In |
|---|---|---|---|
| `test_single_form_2page.pdf` | 2 | Single 2-page VA Form 10-3542 scan | T057, T064 |
| `test_batch_6page.pdf` | 6 | 3 copies of the 2-page form combined | T058, T061 |
| `test_odd_5page.pdf` | 5 | Any 5-page PDF (to simulate odd page count) | T059 |
| `test_batch_40page.pdf` | 40 | 20 copies of the 2-page form combined | T062 |
| (oversized simulation) | — | Temporarily lower the form count limit OR use page count metadata manipulation | T060 |

---

## Test Scenario 1 — Single-Form Bypass via Batches/Incoming/ (T057)

**Spec Reference**: US1 Acceptance Scenario 2  
**Purpose**: Verify that a 2-page PDF uploaded to `Batches/Incoming/` is silently routed to the Mode 1 pipeline — no BatchSubmission record created.

### Steps

| # | Action | Expected Result |
|---|---|---|
| 1 | Upload `test_single_form_2page.pdf` to `SharePoint > FormIntake > Batches > Incoming` | File appears in the Incoming folder |
| 2 | Wait 60 seconds | Flow-01 triggers |
| 3 | Check Flow-01 run history | Status = **Succeeded**; run shows "2-page bypass" path (Mode 1 move + Terminate) |
| 4 | Check `SharePoint > FormIntake` (root folder) | `test_single_form_2page.pdf` exists in the root |
| 5 | Check `SharePoint > FormIntake > Batches > Incoming` | File is **gone** (moved out) |
| 6 | Check Flow 1 (VA-Form-Intake-Pipeline) run history | Flow 1 **triggered** on the file in `FormIntake/` root |
| 7 | Check Dataverse `FormSubmission` records | One new record for `test_single_form_2page.pdf`; `BatchID = null`; `FormIndexInBatch = null` |
| 8 | Check Dataverse `BatchSubmission` records | **No new record created** for this file |

### Pass Criteria

- ✅ File moved from `Batches/Incoming/` → `FormIntake/` root
- ✅ Flow 1 triggered on the moved file
- ✅ FormSubmission created with `BatchID = null`
- ✅ **Zero** BatchSubmission records created
- ✅ No error notifications sent to uploader

### Fail Indicators

- ❌ Flow-01 run history shows Failed or Timed Out
- ❌ BatchSubmission record created for a 2-page file
- ❌ Error notification sent to uploader for a valid single form

---

## Test Scenario 2 — Small Batch (6 Pages = 3 Forms) (T058)

**Spec Reference**: US1 Scenario 1, US2 Scenarios 1–2, US3 Scenario 1, US4 Scenario 1  
**Purpose**: Full end-to-end validation of the core Mode 2 happy path with a small batch.

### Steps

| # | Action | Expected Result |
|---|---|---|
| 1 | Upload `test_batch_6page.pdf` to `FormIntake > Batches > Incoming` | File appears in Incoming folder |
| 2 | Wait 30 seconds | Flow-01 triggers |
| 3 | Check Flow-01 run history | Status = Succeeded; page count = 6; form count = 3 |
| 4 | Check Dataverse BatchSubmission table | New record: `TotalFormCount = 3`, `BatchStatus = Splitting → SplittingComplete` |
| 5 | Note the `BatchDisplayID` (e.g., `BATCH-20260518-042`) | — |
| 6 | Check `SharePoint > FormIntake > Batches > BATCH-20260518-042` | 3 split files exist: `BATCH-20260518-042-001.pdf`, `-002.pdf`, `-003.pdf` |
| 7 | Open each split PDF and verify page count | Each file = exactly **2 pages** |
| 8 | Check `SharePoint > FormIntake > Batches > BATCH-20260518-042` for original | File `_original_test_batch_6page.pdf` exists |
| 9 | Check `SharePoint > FormIntake` (root) | 3 BATCH-prefixed PDFs deposited with ~5-second intervals |
| 10 | Check Flow 1 run history | Flow 1 triggered **3 separate times**, once per split file |
| 11 | Check Dataverse FormSubmission records | 3 new records; each has `BatchID` populated (pointing to the BatchSubmission); `FormIndexInBatch = 1, 2, 3` respectively |
| 12 | As each form processes through extraction → wait for completion | — |
| 13 | Monitor BatchSubmission.FormsCompleted | Increments from 0 → 1 → 2 → 3 as each form completes |
| 14 | Monitor BatchSubmission.CompletionPercentage | Updates: 0% → 33% → 67% → 100% |
| 15 | When all 3 forms complete | `BatchSubmission.BatchStatus = Complete`, `CompletionTimestamp` set |
| 16 | Verify notification received | Completion notification sent to supervisor + uploader |
| 17 | Check AuditLog | Entries for: `BatchUpload`, `BatchValidation`, `BatchSplitStart`, 3× `BatchFormDeposit` (split), `BatchSplitComplete`, 3× `BatchFormDeposit` (feed), `BatchStatusUpdate` (3×), `BatchComplete` |

### Pass Criteria

- ✅ Exactly 3 split PDFs created, each 2 pages
- ✅ Filenames follow format: `BATCH-{YYYYMMDD}-{NNN}-001.pdf` through `-003.pdf`
- ✅ Original retained as `_original_test_batch_6page.pdf`
- ✅ 3 FormSubmission records with `BatchID` and `FormIndexInBatch` set
- ✅ BatchSubmission progresses through statuses to `Complete`
- ✅ All 9 AuditLog action types present

### Performance Checkpoint (SC-001)

Record timestamps:
- `UploadTimestamp` from BatchSubmission
- `SplitEndTimestamp` from BatchSubmission
- Elapsed = SplitEndTimestamp - UploadTimestamp

For a 40-page (20-form) batch, elapsed must be **≤ 2 minutes**.  
For a 6-page (3-form) batch, expect ≤ 30 seconds.

---

## Test Scenario 3 — Odd Page Count Rejection (T059)

**Spec Reference**: US1 Acceptance Scenario 3  
**Purpose**: Verify that a PDF with an odd page count is rejected cleanly with an appropriate message.

### Steps

| # | Action | Expected Result |
|---|---|---|
| 1 | Upload `test_odd_5page.pdf` to `FormIntake > Batches > Incoming` | File appears in Incoming folder |
| 2 | Wait 30 seconds | Flow-01 triggers |
| 3 | Check Flow-01 run history | Status = **Succeeded** (controlled rejection, not error) |
| 4 | Check Dataverse BatchSubmission table | New record with `BatchStatus = ValidationFailed`; `ErrorDetails` contains "Odd page count (5 pages)" |
| 5 | Check AuditLog | Entry: `ActionType = BatchValidation`, `Result = Failed`, details include "Odd page count" |
| 6 | Check for notification | Uploader receives notification with message about odd page count |
| 7 | Check `SharePoint > FormIntake` root | **No BATCH-* files deposited** (no split occurred) |
| 8 | Check Dataverse FormSubmission records | **No new FormSubmission records** for this BatchID |
| 9 | Check `SharePoint > FormIntake > Batches > Incoming` | File may remain or be left in place (depending on your flow design — document actual behavior) |

### Pass Criteria

- ✅ `BatchStatus = ValidationFailed`
- ✅ `ErrorDetails` contains "Odd page count" and shows the actual page count
- ✅ Uploader notified within 60 seconds
- ✅ No split PDFs created
- ✅ No FormSubmission records created with this BatchDisplayID

### Edge Case Verification

Also verify:
- 0-page PDF (if obtainable) → rejected (page count = 0, not even, not = 2)
- 2-page PDF → NOT rejected (routed to Mode 1, not rejected) ← covered in Scenario 1

---

## Test Scenario 4 — Oversized Batch Rejection (>250 Forms) (T060)

**Spec Reference**: US1 — FR-001 "Batch exceeds 250-form limit"  
**Purpose**: Verify the 250-form maximum batch size limit is enforced.

### Test Setup (Workaround for Generating Large Test File)

Since creating a 500+ page PDF is impractical for testing, use one of these approaches:

**Option A — Temporarily lower the limit in the flow**:
1. In Flow-01, find the "Max batch size" condition (T020)
2. Temporarily change the limit from `250` to `3` (rejects batches > 3 forms = > 6 pages)
3. Upload `test_batch_6page.pdf` (3 forms = would now "exceed" the 3-form limit)
4. Verify rejection
5. Restore the limit to `250`

**Option B — Mock page count in Muhimbi response** (advanced):
- Intercept the Muhimbi output and hardcode a large page count for testing

### Steps (using Option A — lowered limit)

| # | Action | Expected Result |
|---|---|---|
| 1 | Temporarily change form limit to 3 in Flow-01 (T020 condition) | Flow saved |
| 2 | Upload `test_batch_6page.pdf` (6 pages = "exceeds 3-form limit") | File appears in Incoming |
| 3 | Wait 30 seconds | Flow-01 triggers |
| 4 | Check Dataverse BatchSubmission | `BatchStatus = ValidationFailed`; `ErrorDetails` contains "exceeds" and form count |
| 5 | Check for notification | Uploader notified with message about form count limit |
| 6 | Check `FormIntake/` root | No split PDFs deposited |
| 7 | **Restore limit to 250 in Flow-01** | Flow saved with correct limit |
| 8 | Verify normal 6-page batch upload works | Re-run Scenario 2 to confirm |

### Pass Criteria

- ✅ `BatchStatus = ValidationFailed`
- ✅ `ErrorDetails` contains form count and limit reference
- ✅ Uploader notified with clear message
- ✅ No split PDFs created

---

## Test Scenario 5 — Duplicate Batch Detection (T061)

**Spec Reference**: US1 — FR-007 "Duplicate Batch Detection" / SC-008  
**Purpose**: Verify the same file cannot be submitted twice while in progress.

### Steps

| # | Action | Expected Result |
|---|---|---|
| 1 | Upload `test_batch_6page.pdf` to `Batches/Incoming/` | Batch processes normally (from Scenario 2 run, if you have a completed batch, use a fresh file) |
| 2 | Wait for `BatchStatus = SplittingComplete` (or any non-terminal status) | — |
| 3 | Upload `test_batch_6page.pdf` **again** (same file, same name, same content) | Second upload appears in Incoming |
| 4 | Wait 30 seconds | Flow-01 triggers on second upload |
| 5 | Check Flow-01 run history (second run) | Status = Succeeded (controlled rejection) |
| 6 | Check Dataverse BatchSubmission | Second record has `BatchStatus = ValidationFailed`; `ErrorDetails` contains "Duplicate batch detected" and references the original BatchDisplayID |
| 7 | Check for notification | Uploader receives duplicate detection notification with original batch ID |
| 8 | Check `FormIntake/` root | No new BATCH-* files from the second submission |

### Duplicate After Completion Test

Additionally:
1. Wait for the first batch (from step 1) to reach `BatchStatus = Complete`
2. Upload `test_batch_6page.pdf` a third time
3. Verify: the third upload is **ALLOWED** (complete/failed batches are excluded from dedup check)
4. A new BatchSubmission record is created with a new BatchDisplayID

### Pass Criteria

- ✅ Second upload rejected with "Duplicate batch detected" message
- ✅ Original BatchDisplayID referenced in the rejection message
- ✅ No duplicate split PDFs deposited
- ✅ Third upload after completion succeeds (SC-008: "rejected before splitting begins")

---

## Test Scenario 6 — Large Batch Performance: 20 Forms (T062)

**Spec Reference**: SC-001 "20-form batch split + feed ≤ 2 minutes"  
**Purpose**: Verify the system meets the performance requirement for the baseline batch size.

### Steps

| # | Action | Expected Result |
|---|---|---|
| 1 | Prepare `test_batch_40page.pdf` (20 copies of 2-page form combined) | File ready; confirm size ≤ 150MB |
| 2 | Record the current time (T_start) | — |
| 3 | Upload `test_batch_40page.pdf` to `Batches/Incoming/` | File in Incoming folder |
| 4 | Open Dataverse → BatchSubmission table; watch for new record | New record appears within ~10 seconds |
| 5 | Note `UploadTimestamp` from the record | — |
| 6 | Monitor `BatchStatus` in real time (refresh every 15 seconds) | Progresses: Splitting → SplittingComplete |
| 7 | When `BatchStatus = SplittingComplete`, note `SplitEndTimestamp` | — |
| 8 | Calculate elapsed time: `SplitEndTimestamp - UploadTimestamp` | **Must be ≤ 2 minutes (120 seconds)** per SC-001 |
| 9 | Check `SharePoint > FormIntake > Batches > BATCH-*` folder | 20 split PDFs: `-001.pdf` through `-020.pdf` |
| 10 | Check `FormIntake/` root | 20 BATCH-prefixed PDFs deposited |
| 11 | Check Flow 1 run history | 20 separate runs, all Succeeded |
| 12 | Check FormSubmission records | 20 records with `BatchID` set; `FormIndexInBatch` = 1–20 |
| 13 | Verify FormIndexInBatch values are sequential | Each form has the correct index (no duplicates, no gaps) |

### Pass Criteria

- ✅ All 20 split PDFs created with correct naming
- ✅ All 20 FormSubmission records with correct `FormIndexInBatch` values (1–20)
- ✅ **Elapsed time from UploadTimestamp to SplittingComplete ≤ 2 minutes** (SC-001)
- ✅ No throttling errors in Muhimbi or SharePoint action history
- ✅ No dropped or missing form files

### Performance Data to Record

Document the following in team notes:

| Metric | Value |
|---|---|
| File size (MB) | |
| Total pages | 40 |
| Forms | 20 |
| UploadTimestamp | |
| SplitStartTimestamp | |
| SplitEndTimestamp | |
| Split elapsed (seconds) | |
| Feed complete time | |
| Total elapsed (seconds) | |
| SC-001 Pass? (≤ 120s) | |

---

## Test Scenario 7 — Stale Batch Alert Simulation (T063)

**Spec Reference**: FR-006, SC-006  
**Purpose**: Verify the stale batch monitoring and alerting works within the 1-hour schedule window.

### Setup: Create a Manually Aged BatchSubmission Record

1. Navigate to **Dataverse** → **Tables** → `Batch Submission`
2. Click **+ New record**
3. Fill in manually:

| Field | Value |
|---|---|
| Batch Display ID | `BATCH-STALE-TEST-001` |
| Source File Name | `stale_test_file.pdf` |
| Source File Size Bytes | `1048576` |
| Source File Page Count | `6` |
| Total Form Count | `3` |
| Upload Timestamp | `(now - 26 hours)` in ISO 8601 format |
| Batch Status | `Splitting` |
| Last Progress Timestamp | `(now - 25 hours)` in ISO 8601 format |

4. Save the record

### Steps

| # | Action | Expected Result |
|---|---|---|
| 1 | Create the manually aged BatchSubmission record (see Setup above) | Record created with `LastProgressTimestamp` = 25 hours ago |
| 2 | Navigate to **Flow-01C-Stale-Batch-Monitor** in Power Automate | Flow shows "On" |
| 3 | Click **Run** to manually trigger the flow | Flow starts executing |
| 4 | Wait for the flow run to complete (~60 seconds) | Flow run status = Succeeded |
| 5 | Check the flow run details | `List_stale_batches` result includes `BATCH-STALE-TEST-001` |
| 6 | Check supervisor's email/Teams notification | Alert notification received with batch details |
| 7 | Check AuditLog | Entry: `ActionType = StaleBatchAlert`, `EntityID = {BatchSubmission GUID}` |
| 8 | Verify non-stale batches are NOT alerted | Completed batches (`BatchStatus = Complete`) do not appear in alert |

### Automated Schedule Verification

Additionally:
1. Wait for the next hourly schedule to fire (check Power Automate run history)
2. Verify the flow ran automatically at the scheduled time
3. Verify the stale test record generates an alert again in the hourly run

### Pass Criteria

- ✅ Manual trigger finds the stale test record
- ✅ Supervisor notification received with BatchDisplayID, status, and last activity timestamp
- ✅ AuditLog entry created for `StaleBatchAlert`
- ✅ Non-stale and terminal batches are NOT alerted
- ✅ Hourly schedule runs automatically (SC-006: alerts fire within 1 hour of 24h threshold)

### Cleanup

After the test, delete the `BATCH-STALE-TEST-001` record from Dataverse (or update its `BatchStatus = Complete` to suppress future alerts).

---

## Test Scenario 8 — Mode 1 Regression: Single-Form Processing Unaffected (T064)

**Spec Reference**: Core design principle — Mode 2 is purely additive  
**Purpose**: Verify that adding Mode 2 has zero impact on existing Mode 1 single-form processing.

### Steps

| # | Action | Expected Result |
|---|---|---|
| 1 | Upload `vafe_TestReg_001.pdf` (2-page standard form) directly to `FormIntake/` root | File in FormIntake root |
| 2 | Upload `vafe_TestReg_002.pdf` directly to `FormIntake/` root | File in FormIntake root |
| 3 | Upload `vafe_TestReg_003.pdf` directly to `FormIntake/` root | File in FormIntake root |
| 4 | Upload `vafe_TestReg_004.pdf` directly to `FormIntake/` root | File in FormIntake root |
| 5 | Upload `vafe_TestReg_005.pdf` directly to `FormIntake/` root | File in FormIntake root |
| 6 | Wait for Flow 1 to process all 5 files | Flow 1 run history shows 5 Succeeded runs |
| 7 | Check Dataverse FormSubmission | 5 new records created |
| 8 | Verify each FormSubmission has `BatchID = null` | All 5 records: `Batch ID` column is empty/null |
| 9 | Verify each FormSubmission has `FormIndexInBatch = null` | All 5 records: `Form Index In Batch` column is empty/null |
| 10 | Verify Flow-01B run history | Flow-01B has **NOT triggered** for any of these 5 forms (BatchID is null, trigger filter excludes them) |
| 11 | Verify extraction pipeline runs | Flow 2 (AI-Builder-Extraction) triggered and processed each of the 5 forms |
| 12 | Verify confidence routing | Each form went through the correct approval path (same as before Mode 2 was implemented) |
| 13 | Verify D365 write | Successful write to Dynamics 365 for at least 1 form (or review queue if confidence below threshold) |
| 14 | Check for any batch-related errors in Flow 1 runs | Run history shows no errors in the new "Is this a batch-split form?" condition (False branch is empty and succeeds silently) |

### Pass Criteria

- ✅ All 5 FormSubmission records have `BatchID = null` and `FormIndexInBatch = null`
- ✅ Flow-01B does NOT trigger for any Mode 1 forms
- ✅ No BatchSubmission records created for Mode 1 uploads
- ✅ Full extraction pipeline (Flow 1 → Flow 2 → Flow 3 → Flow 4) runs identically to pre-Mode 2 behavior
- ✅ No throttling, errors, or unexpected behavior in any of the 5 runs

---

## Phase 8 Master Test Results Summary

Complete this table after running all 8 scenarios:

| Test | Scenario | Key Metric | Result | SC Coverage |
|---|---|---|---|---|
| T057 | Single-form bypass | BatchID = null; no BatchSubmission | ✅ / ❌ | US1.2 |
| T058 | 3-form small batch | All 3 forms complete; BatchStatus = Complete | ✅ / ❌ | SC-001, SC-003 |
| T059 | Odd page rejection | ValidationFailed; notification sent | ✅ / ❌ | US1.3 |
| T060 | Oversized batch | ValidationFailed; limit enforced | ✅ / ❌ | US1 FR-001 |
| T061 | Duplicate detection | Second upload rejected; first preserved | ✅ / ❌ | SC-008 |
| T062 | 20-form performance | Split + feed ≤ 2 min | ✅ / ❌ | SC-001 |
| T063 | Stale batch alert | Alert received within 1 hour | ✅ / ❌ | SC-006 |
| T064 | Mode 1 regression | 5 single forms: BatchID = null; pipeline unchanged | ✅ / ❌ | Core design |

**SC Verification Summary**:

| Success Criterion | Covered By | Status |
|---|---|---|
| SC-001: 20-form batch ≤ 2 minutes | T062 | |
| SC-002: No extraction accuracy degradation | T058 (compare extraction results with direct upload) | |
| SC-003: Status updates within 30 seconds | T058 (monitor FormsCompleted in real time) | |
| SC-004: Supports up to 500 forms | Phase 2 only (250-form Phase 1 limit; 500 = Phase 2 target) | |
| SC-005: 100% audit logging | T058, T064 (check all 9 AuditLog ActionType values) | |
| SC-006: Stale alerts within 1 hour | T063 | |
| SC-007: Failed forms identifiable in < 1 min | T058 (Batch Detail view; FormIndexInBatch identifies each form) | |
| SC-008: Duplicates rejected before splitting | T061 | |

---

**Version**: 1.0.0 | **Generated**: 2025-07-17  
**Status**: Complete test specification — ready for manual execution  
**Document phase 8 results in team notes before marking Phase 8 tasks complete.**
