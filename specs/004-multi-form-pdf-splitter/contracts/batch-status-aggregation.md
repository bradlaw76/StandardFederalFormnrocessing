# Contract: Batch Status Aggregation Flow

**Feature**: 004-multi-form-pdf-splitter  
**Date**: 2025-07-17  
**Type**: Power Automate Cloud Flow (supplementary)

---

## Flow Overview

**Name**: `Flow-01B-Batch-Status-Updater`  
**Trigger**: Dataverse — When a row is modified in `FormSubmission` table (filter: `BatchID IS NOT NULL` and `Status` changed)  
**Purpose**: Aggregate child form statuses to update parent BatchSubmission record.

---

## Trigger Contract

### Input (FormSubmission Modified)

| Field | Type | Filter |
|-------|------|--------|
| FormID | GUID | The modified FormSubmission |
| BatchID | GUID | Must be non-null (only batch-member forms) |
| Status | Option Set | Must have changed (old value ≠ new value) |

---

## Processing Steps

### Step 1: Query All Sibling Forms

```
Query: FormSubmission WHERE BatchID = {triggerRow.BatchID}
Return: Array of { FormID, Status }
```

### Step 2: Compute Aggregates

```
Aggregation {
  FormsCompleted: COUNT(Status = 'Complete'),
  FormsInReview: COUNT(Status IN ('ReviewRequired', 'ManualIntake')),
  FormsFailed: COUNT(Status IN ('WriteFailed', 'Failed')),
  FormsProcessing: COUNT(Status IN ('Intake', 'Extracting', 'Auto-Approved', 'D365Writing')),
  TotalFormCount: {BatchSubmission.TotalFormCount}
}
```

### Step 3: Update BatchSubmission

```
Update BatchSubmission WHERE BatchID = {triggerRow.BatchID}:
  FormsCompleted = {computed},
  FormsInReview = {computed},
  FormsFailed = {computed},
  FormsProcessing = {computed},
  CompletionPercentage = (FormsCompleted / TotalFormCount) × 100,
  LastProgressTimestamp = NOW()
```

### Step 4: Check Terminal State

```
IF (FormsCompleted + FormsFailed) = TotalFormCount THEN:
  IF FormsFailed = 0 THEN:
    BatchStatus = 'Complete'
  ELSE:
    BatchStatus = 'PartiallyFailed'
  CompletionTimestamp = NOW()
  Log AuditLog: ActionType = 'BatchComplete' or 'BatchPartiallyFailed'
  Notify via Notification-Router
```

---

## Output Contract

### BatchSubmission Update

```
BatchStatusUpdate {
  BatchID: GUID,
  FormsCompleted: Integer,
  FormsInReview: Integer,
  FormsFailed: Integer,
  FormsProcessing: Integer,
  CompletionPercentage: Decimal,
  BatchStatus: Text (if changed to terminal),
  CompletionTimestamp: DateTime (if terminal)
}
```

---

## Concurrency Guard

- Use Dataverse row-level locking (optimistic concurrency) to prevent race conditions when multiple FormSubmission status changes trigger simultaneously
- If concurrency conflict detected, retry the aggregation (up to 3 attempts with 2-second backoff)

---

**Status**: ✅ Complete | **Date**: 2025-07-17
