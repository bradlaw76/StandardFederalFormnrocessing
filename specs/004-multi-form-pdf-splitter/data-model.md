# Data Model: Multi-Form PDF Splitter (Mode 2)

**Feature**: 004-multi-form-pdf-splitter  
**Date**: 2025-07-17  
**Scope**: New Dataverse table + extension to existing FormSubmission table

---

## 1. New Entity: BatchSubmission

Tracks the lifecycle of a multi-form PDF batch upload.

### Schema

```
BatchSubmission (Dataverse Table — NEW)
├─ BatchID (Primary Key, GUID, auto-generated)
├─ BatchDisplayID (Text, unique, auto-generated: "BATCH-YYYYMMDD-NNN")
├─ SourceFileName (Text, 255 chars — original uploaded filename)
├─ SourceFileSizeBytes (Whole Number — file size for dedup)
├─ SourceFilePageCount (Whole Number — total pages in batch PDF)
├─ SourceFileHash (Text, 64 chars — SHA-256 hash, nullable for Phase 1)
├─ TotalFormCount (Whole Number — computed: PageCount ÷ 2)
├─ UploadedBy (Lookup to User / Entra ID)
├─ UploadTimestamp (DateTime, immutable)
├─ BatchStatus (Option Set — see state machine below)
├─ FormsCompleted (Whole Number, default 0 — rollup count)
├─ FormsInReview (Whole Number, default 0 — rollup count)
├─ FormsFailed (Whole Number, default 0 — rollup count)
├─ FormsProcessing (Whole Number, default 0 — rollup count)
├─ CompletionPercentage (Decimal 0–100 — computed: FormsCompleted / TotalFormCount × 100)
├─ SplitStartTimestamp (DateTime, nullable)
├─ SplitEndTimestamp (DateTime, nullable)
├─ CompletionTimestamp (DateTime, nullable — when all forms reach terminal state)
├─ LastProgressTimestamp (DateTime — updated on each child form status change)
├─ ErrorDetails (Text, 4000 chars — error message if split failed)
├─ LastSuccessfulSplitIndex (Whole Number, nullable — for resume-on-failure)
├─ SharePointBatchFolderPath (Text, 500 chars — path to batch subfolder)
├─ OriginalFileSharePointID (Text — SharePoint item ID of retained original)
├─ CreatedOn (DateTime, auto)
├─ ModifiedOn (DateTime, auto)
```

### BatchStatus State Machine

```
Uploaded → Validating → Splitting → SplittingComplete → Feeding → Complete
                │              │                              │
                └→ ValidationFailed   └→ SplitFailed         └→ PartiallyFailed
                      │                     │                       │
                      └→ (terminal)        └→ RetryPending         └→ (terminal)
                                                  │
                                                  └→ Splitting (retry)
```

| Status | Description |
|--------|-------------|
| `Uploaded` | Batch PDF received; not yet validated |
| `Validating` | Checking page count, file size, duplicate detection |
| `ValidationFailed` | Invalid file (odd pages, too large, duplicate, corrupt) |
| `Splitting` | PDF split operation in progress |
| `SplitFailed` | Split operation failed mid-process; partial results preserved |
| `RetryPending` | Operator requested retry of failed split |
| `SplittingComplete` | All individual PDFs created; ready to feed pipeline |
| `Feeding` | Split PDFs being moved to intake folder for pipeline processing |
| `Complete` | All child forms reached terminal state (all Complete) |
| `PartiallyFailed` | All child forms reached terminal state but some failed |

### Validation Rules

| Field | Rule |
|-------|------|
| SourceFilePageCount | Must be > 2 and even; odd count → ValidationFailed |
| SourceFileSizeBytes | Must be ≤ 150MB (157,286,400 bytes) |
| TotalFormCount | Must be ≤ 250 (Phase 1 limit) |
| SourceFileName | Must end with `.pdf` (case-insensitive) |
| Duplicate check | No existing BatchSubmission with same SourceFileName + SourceFileSizeBytes + SourceFilePageCount in non-terminal status |

---

## 2. Extended Entity: FormSubmission (Existing — 2 New Columns)

Add optional batch reference columns to the existing FormSubmission table.

### New Columns

```
FormSubmission (Dataverse Table — EXISTING, extended)
├─ ... (all existing columns unchanged) ...
├─ BatchID (Lookup to BatchSubmission, NULLABLE)  ← NEW
│   • NULL for Mode 1 single-form uploads
│   • Set for Mode 2 split forms
├─ FormIndexInBatch (Whole Number, NULLABLE)       ← NEW
│   • Sequential position within the batch (1-based)
│   • NULL for Mode 1 single-form uploads
│   • Example: Form 3 of 20 → FormIndexInBatch = 3
```

### Impact on Existing Flows

- **Flow 1 (Intake Trigger)**: No modification needed. BatchID and FormIndexInBatch are set by Flow 01 when creating the FormSubmission record — or left NULL when Flow 1 creates it for Mode 1 uploads.
- **Flow 2 (Extraction)**: No modification needed. Extraction operates on individual FormSubmission records regardless of batch membership.
- **Correction/D365 flows**: No modification needed. Operate on individual records.

**Note**: Flow 01 creates the FormSubmission record in Dataverse *before* depositing the split PDF into SharePoint. When Flow 1 triggers on the file, it should check if a FormSubmission already exists for that filename and update it rather than creating a duplicate. **Alternative**: Flow 01 only deposits PDFs to SharePoint and lets Flow 1 create the FormSubmission — then a separate step links BatchID after creation.

**Chosen approach**: Flow 01 deposits split PDFs into SharePoint. Flow 1 creates FormSubmission as usual. Flow 01 then updates the FormSubmission record with BatchID + FormIndexInBatch after Flow 1 has created it (via a polling/waiting step or a secondary trigger).

**Simpler alternative (recommended)**: Embed batch metadata in the split PDF filename. Flow 1 parses the filename and populates BatchID + FormIndexInBatch if the filename matches the batch pattern (`BATCH-*-NNN.pdf`). This requires a **minor conditional addition** to Flow 1 — but it's a simple "if filename starts with BATCH- then parse and set batch fields" branch that doesn't change the core logic.

**Final decision**: Use the filename-embedding approach. This is the least invasive change — Flow 1 gets a single conditional step at the end of its existing logic to populate batch fields from the filename pattern.

---

## 3. Entity Relationship Diagram

```
BatchSubmission (1) ──────── (0..N) FormSubmission
     │                                   │
     │ BatchID (PK)              BatchID (FK, nullable)
     │                           FormIndexInBatch
     │
     └── Aggregated status computed from child FormSubmission statuses

FormSubmission (1) ──────── (1) ExtractionResult
                                    │
                                    └── (existing relationship, unchanged)

FormSubmission (1) ──────── (0..N) CorrectionRecord
                                    │
                                    └── (existing relationship, unchanged)

FormSubmission (1) ──────── (0..N) D365WriteEvent
                                    │
                                    └── (existing relationship, unchanged)
```

---

## 4. Batch Status Aggregation Logic

The BatchSubmission status counters are updated whenever a child FormSubmission changes status.

### Update Trigger

A Power Automate flow (or Dataverse plugin) triggers on `FormSubmission.Status` change where `BatchID IS NOT NULL`:

```
ON FormSubmission.Status CHANGED WHERE BatchID IS NOT NULL:
  1. Query all FormSubmission WHERE BatchID = {this.BatchID}
  2. Count by status:
     - FormsCompleted = COUNT(Status = 'Complete')
     - FormsInReview = COUNT(Status IN ('ReviewRequired', 'ManualIntake'))
     - FormsFailed = COUNT(Status IN ('WriteFailed', 'Failed'))
     - FormsProcessing = COUNT(Status IN ('Extracting', 'Auto-Approved', 'D365Writing'))
  3. Update BatchSubmission:
     - FormsCompleted, FormsInReview, FormsFailed, FormsProcessing
     - CompletionPercentage = FormsCompleted / TotalFormCount × 100
     - LastProgressTimestamp = NOW()
  4. Check terminal state:
     - IF FormsCompleted + FormsFailed = TotalFormCount THEN
       - IF FormsFailed = 0 THEN BatchStatus = 'Complete'
       - ELSE BatchStatus = 'PartiallyFailed'
       - Set CompletionTimestamp = NOW()
```

---

## 5. Stale Batch Detection

### Scheduled Flow (runs every 1 hour)

```
Query BatchSubmission WHERE:
  BatchStatus NOT IN ('Complete', 'PartiallyFailed', 'ValidationFailed')
  AND LastProgressTimestamp < NOW() - 24 hours

For each stale batch:
  1. Log to AuditLog (ActionType = 'StaleBatchAlert')
  2. Send notification via Notification-Router subflow
  3. Update BatchSubmission.BatchStatus comment/notes field
```

---

## 6. AuditLog Extensions

New `ActionType` values for batch operations:

| ActionType | Description |
|------------|-------------|
| `BatchUpload` | Batch PDF uploaded to SharePoint |
| `BatchValidation` | Page count/size/duplicate validation result |
| `BatchSplitStart` | PDF split operation started |
| `BatchSplitComplete` | All individual PDFs created |
| `BatchSplitFailed` | Split operation failed (includes error + last index) |
| `BatchFormDeposit` | Individual split PDF deposited to intake folder |
| `BatchStatusUpdate` | Batch status aggregation updated |
| `BatchComplete` | All child forms processed |
| `StaleBatchAlert` | Stale batch alert triggered |

---

**Status**: ✅ Complete | **Date**: 2025-07-17
