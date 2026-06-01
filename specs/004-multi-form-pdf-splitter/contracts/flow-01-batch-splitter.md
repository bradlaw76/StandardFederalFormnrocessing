# Contract: Flow 01 — Batch PDF Intake & Splitter

**Feature**: 004-multi-form-pdf-splitter  
**Date**: 2025-07-17  
**Type**: Power Automate Cloud Flow

---

## Flow Overview

**Name**: `Flow-01-Batch-PDF-Splitter`  
**Trigger**: SharePoint — When a file is created in `FormIntake/Batches/Incoming/`  
**Purpose**: Detect multi-form PDFs, validate, split into individual 2-page PDFs, and deposit into the existing pipeline intake folder.

---

## Trigger Contract

### Input (SharePoint File Created)

| Field | Type | Source |
|-------|------|--------|
| FileID | Text | SharePoint item ID |
| FileName | Text | SharePoint file name |
| FilePath | Text | SharePoint file server-relative URL |
| FileContent | Binary | SharePoint file content (PDF bytes) |
| FileSize | Integer | File size in bytes |
| CreatedBy | Text | Entra ID of uploading user |
| CreatedTimestamp | DateTime | File creation timestamp |

### Trigger Filter

- File must be in `FormIntake/Batches/Incoming/` folder (NOT `FormIntake/` root)
- File extension must be `.pdf` (case-insensitive)

---

## Processing Steps

### Step 1: File Validation

**Input**: FileContent, FileName, FileSize  
**Output**: ValidationResult

```
ValidationResult {
  IsValid: Boolean,
  PageCount: Integer,
  FormCount: Integer (PageCount ÷ 2),
  FailureReason: Text (nullable),
  IsDuplicate: Boolean
}
```

**Validation Rules**:
1. File extension = `.pdf` → else reject ("Invalid file type")
2. File size ≤ 150MB → else reject ("File exceeds 150MB limit")
3. PDF is readable (not corrupt) → else reject ("Corrupt or unreadable PDF")
4. Page count > 2 → else route to Mode 1 (move to `FormIntake/` root; exit flow)
5. Page count is even → else reject ("Odd page count: {n} pages. Manual review required.")
6. Form count ≤ 250 → else reject ("Batch exceeds 250-form limit")
7. No existing BatchSubmission with same FileName + FileSize + PageCount in active status → else reject ("Duplicate batch detected")

### Step 2: Batch Record Creation

**Output**: BatchSubmission record in Dataverse

```
BatchSubmission {
  BatchDisplayID: "BATCH-{YYYYMMDD}-{NNN}",
  SourceFileName: {FileName},
  SourceFileSizeBytes: {FileSize},
  SourceFilePageCount: {PageCount},
  TotalFormCount: {PageCount ÷ 2},
  UploadedBy: {CreatedBy},
  UploadTimestamp: {CreatedTimestamp},
  BatchStatus: "Splitting",
  SplitStartTimestamp: NOW(),
  SharePointBatchFolderPath: "FormIntake/Batches/{BatchDisplayID}/"
}
```

### Step 3: PDF Splitting

**Input**: FileContent, TotalFormCount, BatchDisplayID  
**Output**: Individual 2-page PDFs in SharePoint

For `i = 1` to `TotalFormCount`:
```
SplitOperation {
  PageRange: "{(i-1)*2 + 1} to {i*2}",
  OutputFileName: "{BatchDisplayID}-{i:000}.pdf",
  OutputPath: "FormIntake/Batches/{BatchDisplayID}/{OutputFileName}",
  Status: "Success" | "Failed"
}
```

**Error handling**: If split fails at index `i`:
1. Preserve all successfully split files (indices 1 to i-1)
2. Update BatchSubmission: Status = "SplitFailed", ErrorDetails = "{error}", LastSuccessfulSplitIndex = i-1
3. Log to AuditLog: ActionType = "BatchSplitFailed"
4. Notify operator via Notification-Router
5. EXIT flow

### Step 4: Pipeline Feeding

**Input**: List of split PDF files, BatchDisplayID  
**Output**: Files moved to `FormIntake/` root to trigger existing Flow 1

For each split PDF (sequential, with 5-second delay):
```
FeedOperation {
  SourcePath: "FormIntake/Batches/{BatchDisplayID}/{FileName}",
  DestinationPath: "FormIntake/{FileName}",
  Status: "Moved" | "Failed"
}
```

After all files moved:
1. Update BatchSubmission: Status = "Feeding" → "SplittingComplete"
2. Log to AuditLog: ActionType = "BatchSplitComplete"

### Step 5: Retain Original

Move original batch PDF to batch subfolder:
```
OriginalRetention {
  SourcePath: "FormIntake/Batches/Incoming/{FileName}",
  DestinationPath: "FormIntake/Batches/{BatchDisplayID}/_original_{FileName}",
  OriginalFileSharePointID: {SharePoint item ID}
}
```

---

## Output Contract

### Success

```
FlowResult {
  BatchID: GUID,
  BatchDisplayID: Text,
  TotalFormCount: Integer,
  SplitFilePaths: Array<Text>,
  BatchStatus: "SplittingComplete",
  Duration: TimeSpan
}
```

### Failure (Validation)

```
FlowResult {
  BatchID: null,
  FailureReason: Text,
  OriginalFileName: Text,
  Action: "Rejected" | "RoutedToMode1" | "ManualReview"
}
```

### Failure (Split Error)

```
FlowResult {
  BatchID: GUID,
  BatchDisplayID: Text,
  BatchStatus: "SplitFailed",
  LastSuccessfulSplitIndex: Integer,
  ErrorDetails: Text,
  PreservedFiles: Array<Text>
}
```

---

## Subflow Reuse

| Existing Subflow | Used In Flow 01? | Purpose |
|-----------------|-------------------|---------|
| Audit-Event-Logger | ✅ Yes | Log all batch events (upload, validate, split, feed) |
| Notification-Router | ✅ Yes | Alert on validation failure, split failure, stale batch |
| Manual-Correction-Queue | ❌ No | Not applicable (no extraction in Flow 01) |
| D365-Retry-Logic | ❌ No | Not applicable (no D365 write in Flow 01) |

---

## Performance Expectations

| Metric | Target | Basis |
|--------|--------|-------|
| Validation time | < 5 seconds | Page count + size check |
| Split time per form | < 2 seconds | Muhimbi/Adobe connector benchmark |
| 20-form batch (total) | < 2 minutes | Spec SC-001 |
| 100-form batch (total) | < 10 minutes | Linear scaling |
| 250-form batch (total) | < 25 minutes | Linear scaling with connector overhead |

---

**Status**: ✅ Complete | **Date**: 2025-07-17
