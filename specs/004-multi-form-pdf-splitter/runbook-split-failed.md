# Operator Runbook: SplitFailed Recovery

**Feature**: 004-multi-form-pdf-splitter  
**Artifact Task**: T067  
**Date**: 2025-07-17  
**Version**: 1.0.0

---

## Purpose

This runbook provides step-by-step instructions for operators to recover from a `SplitFailed` batch status. A `SplitFailed` batch means the PDF split operation started but encountered an error mid-process. Partial results (forms already split) are preserved and must not be deleted.

---

## Symptoms

- A `BatchSubmission` record in Dataverse has `BatchStatus = SplitFailed`
- An operator or supervisor received a notification: *"Split failed at form N of M. N forms preserved in FormIntake/Batches/{BatchDisplayID}/."*
- Power Automate → Flow run history for `Flow-01-Batch-PDF-Splitter` shows a run with status **Failed**

---

## Step 1 — Identify the Failing Batch

1. Navigate to **Power Platform Maker Portal** → **Dataverse** → **Tables** → `BatchSubmission`
2. Filter by `BatchStatus = SplitFailed`
3. Open the failing record and note:
   - `BatchDisplayID` (e.g., `BATCH-20250717-001`)
   - `LastSuccessfulSplitIndex` — the last form that was successfully split (e.g., `7` means forms 1–7 are already saved)
   - `TotalFormCount` — total number of forms in the batch
   - `ErrorDetails` — the specific error message from the split failure
   - `SharePointBatchFolderPath` — the SharePoint path where partial splits are stored
   - `UploadedBy` — the original uploader

4. Record these values for use in the recovery steps below.

---

## Step 2 — Assess Partial Results

1. Navigate to **SharePoint** → `FormIntake` library → `Batches` → `{BatchDisplayID}` folder
2. Verify the partial split files exist:
   - Files named `BATCH-{YYYYMMDD}-{NNN}-001.pdf` through `BATCH-{YYYYMMDD}-{NNN}-{LastSuccessfulSplitIndex:000}.pdf` should be present
   - The original file `_original_{FileName}` should also be present (retained per T030)
3. Count the files to confirm alignment with `LastSuccessfulSplitIndex`
4. **Do NOT delete any files** — the partial results are preserved for recovery

---

## Step 3 — Diagnose the Error

Review `ErrorDetails` on the `BatchSubmission` record. Common causes:

| Error Pattern | Likely Cause | Resolution |
|---|---|---|
| `HTTP 429 Too Many Requests` | Azure Function or SharePoint rate limiting | Wait 5–10 minutes, then retry |
| `HTTP 504 Gateway Timeout` | Large page range timeout in Azure Function | Try smaller batch (fewer forms) or contact admin to adjust function timeout |
| `File size exceeded` | Split PDF output exceeded SharePoint upload limit | Contact admin; may require chunking |
| `SharePoint: File already exists` | Filename collision in batch subfolder | Rename the batch subfolder manually, or re-upload with different filename |
| `Connection timeout` | Transient network error | Retry the upload |
| `Dataverse: 409 Conflict` | Concurrent write collision | Retry; concurrency guard should handle this automatically |

---

## Step 4 — Recovery Options

### Option A: Full Re-Upload (Recommended for <10 forms lost)

Use this option when the failure occurred early (e.g., `LastSuccessfulSplitIndex` is small relative to `TotalFormCount`) or when the original batch PDF is readily available.

1. **Update the failing `BatchSubmission` record**:
   - Set `BatchStatus = ValidationFailed` (to exclude it from active queries)
   - Add a note in `ErrorDetails`: `"Superseded by re-upload on {date} — see {new BatchDisplayID}"`
2. **Rename the original PDF** to avoid duplicate detection:
   - Example: `BatchForms_Scan_2025-07-17_retry.pdf`
3. **Upload the renamed PDF** to `FormIntake/Batches/Incoming/`
4. Monitor the new batch in Dataverse — it will receive a new `BatchDisplayID`

> **Why rename?** The duplicate detection filter matches on `SourceFileName + SourceFileSizeBytes + SourceFilePageCount`. Same filename with same size will be rejected as a duplicate unless you rename the file.

---

### Option B: Partial Recovery — Manually Feed Remaining Forms

Use this option when `LastSuccessfulSplitIndex` is close to `TotalFormCount` (e.g., only 1–3 forms were not split).

1. **Identify which forms are missing**:
   - Forms 1 through `LastSuccessfulSplitIndex` are already in the batch subfolder
   - Forms `LastSuccessfulSplitIndex + 1` through `TotalFormCount` need to be created manually

2. **Extract the missing pages from the original batch PDF**:
   - Open `_original_{FileName}` from the batch subfolder in SharePoint
   - Use a PDF tool (Adobe Acrobat, PDFsam, etc.) to extract pages:
     - Missing form N: pages `(N-1)*2 + 1` through `N*2`
   - Save each extracted 2-page segment as a PDF named `{BatchDisplayID}-{FormIndex:000}.pdf`
     - Example for form 8 of batch BATCH-20250717-001: `BATCH-20250717-001-008.pdf`

3. **Upload the manually-extracted PDFs to the batch subfolder** in SharePoint:
   - Path: `FormIntake/Batches/{BatchDisplayID}/`

4. **Manually move all unsent split PDFs to `FormIntake/` root** (one by one, with 5-second pauses):
   - Move `{BatchDisplayID}-{LastSuccessfulSplitIndex+1}.pdf` … `{BatchDisplayID}-{TotalFormCount}.pdf`
   - Each file moved to `FormIntake/` root will trigger `VA-Form-Intake-Pipeline` (Flow 1)
   - Wait 5 seconds between each move to avoid pipeline overload

5. **Update the `BatchSubmission` record** in Dataverse:
   - Set `BatchStatus = SplittingComplete`
   - Update `SplitEndTimestamp = now`
   - Update `ErrorDetails` to note the manual recovery: `"Partial failure recovered manually on {date} by {operator}. Forms {LastSuccessfulSplitIndex+1}–{TotalFormCount} extracted manually."`

6. **Verify** the recovered forms appear in Dataverse as `FormSubmission` records with `BatchID` populated correctly.

---

### Option C: Retry via RetryPending (If Retry Flow Deployed)

> **Note**: The automatic retry flow is scheduled for Phase 2 (not yet built in Phase 1). This option is not available until the retry mechanism is deployed.

If the retry flow is deployed:
1. In Dataverse, update `BatchSubmission.BatchStatus = RetryPending`
2. The retry flow will detect this, re-run the split from `LastSuccessfulSplitIndex + 1`, and resume where it left off

---

## Step 5 — Notify the Uploader

1. Contact the original uploader (`UploadedBy` field on the `BatchSubmission` record)
2. Inform them of:
   - Which batch failed (`BatchDisplayID`)
   - How many forms were successfully processed (if any)
   - Which recovery option was taken
   - Whether they need to re-upload any forms

---

## Step 6 — Document the Incident

1. Add a note to the `BatchSubmission` record's `ErrorDetails` field summarizing:
   - Date/time of failure
   - Root cause
   - Recovery option used
   - Operator who performed recovery
2. Log a manual entry in the `AuditLog` Dataverse table:
   - `ActionType = BatchSplitFailed`
   - `EntityID = {BatchID GUID}`
   - `Details = "Manual recovery performed by {operator}: {recovery option taken}"`
3. If the error suggests a systemic issue (e.g., repeated timeouts, connector failures), escalate to the platform admin team

---

## Quick Reference

| Scenario | Recommended Option |
|---|---|
| Failure at form 1 (nothing split) | Option A (re-upload, rename file) |
| Failure at form 3 of 20 | Option A (re-upload) |
| Failure at form 18 of 20 | Option B (manually extract and feed 2 remaining forms) |
| Transient network error | Option A (re-upload after 5 minutes) |
| Retry flow deployed | Option C (set RetryPending) |

---

## Related Documents

- [FLOW-01-RUNBOOK.md](FLOW-01-RUNBOOK.md) — Full Flow 01 build runbook
- [IMPLEMENTATION-CHECKLIST.md](IMPLEMENTATION-CHECKLIST.md) — Master task tracker
- [data-model.md](../data-model.md) — BatchSubmission schema reference
- [quickstart.md](../quickstart.md) — Setup and test guide

---

**Version**: 1.0.0 | **Task**: T067 | **Created**: 2025-07-17
