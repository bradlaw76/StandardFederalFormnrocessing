# Power Automate Flow Architecture
**Issue:** #18 | **Owner:** John Shelby | **Status:** Complete

> Design lock reference (2026-05-18): `docs/FLOW-DESIGN-BASELINE-LOCK.md`.
> Use the baseline lock before proposing flow changes to avoid rework against already validated behavior.
> Version registry and rollback source: `docs/DESIGN-VERSION-REGISTRY.md`.

---

## Overview: 4-Flow Pipeline

```
SharePoint (file upload)          Manual Batch Trigger
        │                                  │
        ▼                                  ▼
┌─────────────────────┐        ┌────────────────────────┐
│ Flow 6: Batch       │        │  Flow 1: Intake        │
│ Processor           │◄───────│  (Trigger or Child)    │
│ (Manual trigger)    │        │  Creates: FormSubmission
└────────┬────────────┘        └────────┬───────────────┘
         │                              │ status → Extracting
         │ (per file)                   ▼
         │ List & Loop         ┌─────────────────────┐
         └────────────────────►│ Flow 2: Extraction  │
                               │ (AI Invocation)     │
                               └────────┬────────────┘
                                        │ Routes per confidence:
                                   ┌────┴────┐
                                   │         │
                                   ▼         ▼
                              [≥80%]    [60-79%/etc]
                                   │      Route to
                                   │      Review Flow
                                   ▼      (issue #31)
                              ┌─────────────────────┐
                              │ Flow 3: D365 Write  │
                              │ (Integration)       │
                              │ Creates: Contact,   │
                              │ ExtractionResult    │
                              └─────────────────────┘
```

**Flow 1 (MVP-01)** — Trigger on single file upload OR called by Flow 6  
**Flow 2 (MVP-02)** — Extract data from PDF via AI Builder  
**Flow 3 (MVP-03)** — Write extracted data to D365 + Dataverse  
**Flow 6 (MVP-06)** — NEW: Batch processor for multiple PDFs

---

## Flow 1 — SharePoint Intake Trigger (Issue #29)

**Name:** `VAFE-Flow-01-SharePointIntake`

| Property | Value |
|----------|-------|
| Trigger | SharePoint — When a file is created in a folder |
| Site | https://d365demotsce80677168.sharepoint.com/sites/DepartmentofVeteranAffairs |
| Library | `FormIntake` |
| Filter | File name matches pattern: `VA-10-3542-*.pdf` |

**Actions:**
1. Initialize variables: `formStatus`, `correlationId` (GUID)
2. Create `vafe_formsubmission` record:
   - `vafe_SourceFile` = file name
   - `vafe_UploadDate` = trigger timestamp
   - `vafe_Status` = `100000` (Intake)
   - `vafe_CorrelationId` = GUID
3. Write AuditLog: Action=Create, UserId=flow service account
4. Update `vafe_formsubmission` status → `100001` (Extracting)
5. Trigger Flow 2 (via HTTP or child flow)

**Error handling:**
- On failure: set status = Error, write AuditLog (Severity=Error), send alert email

---

## Flow 2 — AI Extraction Invocation (Issue #30)

**Name:** `VAFE-Flow-02-AIExtraction`

| Property | Value |
|----------|-------|
| Trigger | Dataverse — When a row is modified (vafe_formsubmission, Status = Extracting) |
| Or | Called as child flow from Flow 1 |

**Actions:**
1. Get file content from SharePoint (using `vafe_SourceFile`)
2. Set `vafe_ProcessingStart` timestamp
3. Call **AI Builder** — `VAForm10-3542-Extractor`
4. Parse results — extract all 14 fields + per-field confidence scores
5. Calculate `OverallConfidence` = average of all field confidence scores
6. Create `vafe_extractionresult` record with all extracted fields
7. Confidence routing:
   - **≥ 80%**: Set `ExtractionStatus = Success`, update FormSubmission status → `Extracted` (100002)
   - **60–79%**: Set `ExtractionStatus = PartialSuccess`, create `CorrectionRecord` per flagged field, update FormSubmission status → `Correcting` (100003)
   - **< 60%**: Set `ExtractionStatus = Failed`, create high-priority `CorrectionRecord`, update FormSubmission status → `Correcting` (100003)
8. Set `vafe_ProcessingEnd` timestamp
9. Write AuditLog

**Variables/Config (environment variables):**
- `CONFIDENCE_ACCEPT_THRESHOLD` = 0.80
- `CONFIDENCE_FLAG_THRESHOLD` = 0.60

---

## Flow 3 — D365 Write Trigger (Issue #32)

**Name:** `VAFE-Flow-03-D365Write`

| Property | Value |
|----------|-------|
| Trigger | Dataverse — When a row is modified (vafe_formsubmission, Status = Extracted) |

**Actions:**
1. Get linked `vafe_extractionresult` record
2. Map extracted fields to D365 target entities (see issue #36 — field mapping)
3. Create/update D365 record via Dynamics 365 connector
4. Create `vafe_d365writeevent` record:
   - `vafe_D365Status` = Pending → Success or Failed
   - `vafe_D365RecordId` = created record ID
   - `vafe_HTTPStatusCode` = response status
   - `vafe_PayloadSent` = JSON payload (logged for audit)
5. On success: update FormSubmission status → `Written` (100006)
6. On failure:
   - Increment `vafe_RetryCount`
   - If `RetryCount` < 3: set `vafe_D365Status = Retrying`, re-queue
   - If `RetryCount` ≥ 3: set `vafe_D365Status = Failed`, write to dead-letter queue (issue #33)

---

## Flow 6 — Batch Folder Processor (NEW — Issue #34)

**Name:** `MVP-06-Batch-Folder-Processor`

| Property | Value |
|----------|-------|
| Trigger | Manual (Button) — triggered by user |
| Processing | Loop through all VA-10-3542-*.pdf in FormIntake, process each |

**Actions:**
1. List files in SharePoint FormIntake library
2. Filter for files matching `VA-10-3542-*.pdf` pattern
3. **For each file in list:**
   - Get file properties (ID, name)
   - Get file content
   - Call **Flow 1 (MVP-01)** as child flow with FileId parameter
   - Delay 5 seconds (throttle SharePoint API)
4. Compose summary: "Batch processing complete. X files processed."

**Output:**
- Each file processed independently
- Creates separate FormSubmission + ExtractionResult + Contact records per file
- No deduplication (yet) — if file processed twice, creates duplicate records

**Use Cases:**
- Backfill: Upload 10 historical PDFs, trigger Flow 06 once
- Batch entry: Staff uploads 5 claims, runs batch processor instead of waiting for single-file trigger
- Manual reprocessing: Reprocess failed PDFs by re-uploading to FormIntake and running Flow 06

**Vs. Scheduled Flow (Phase 3):**
- Flow 06 (manual): immediate, synchronous, good for demo/backfill
- Phase 3 (scheduled): runs every 15 min, parallel, better for high-volume production

**Full Setup Guide:** `Flows/MVP-06-BATCH-PROCESSOR-SETUP.md`

---

## Shared Infrastructure

### Connector Actions Used Across All Flows
| Connector | Action | Used In |
|-----------|--------|---------|
| SharePoint | Get file content | Flow 2, Flow 6 |
| SharePoint | List files in folder | Flow 6 |
| AI Builder | Process and save information from documents | Flow 2 |
| Microsoft Dataverse | Create a new row | Flow 1, 2, 3 |
| Microsoft Dataverse | Update a row | Flow 1, 2, 3 |
| Microsoft Dataverse | List rows | Flow 2, 3 |
| Dynamics 365 | Create record | Flow 3 |
| Office 365 Outlook | Send email | All (error alerts) |

### Environment Variables (set once per environment)
```
CONFIDENCE_ACCEPT_THRESHOLD = 0.80
CONFIDENCE_FLAG_THRESHOLD = 0.60
SHAREPOINT_SITE_URL = https://d365demotsce80677168.sharepoint.com/sites/DepartmentofVeteranAffairs
SHAREPOINT_LIBRARY = FormIntake
D365_ENVIRONMENT_URL = https://healthconnectcenter.crm.dynamics.com
ALERT_EMAIL = admin@D365DemoTSCE80677168.onmicrosoft.com
```

### Correlation ID Pattern
Every form submission gets a GUID correlation ID set in Flow 1. All AuditLog entries and D365WriteEvent records reference this ID, enabling end-to-end tracing.

---

## 2026-06-02 Live Expense Mapping Patch

This section captures live updates applied in the `VAFormExtractionDemo` solution to persist monetary fields.

### Dataverse Table Fields (Extraction Result)

Configured currency fields:
1. Expense A Amount
2. Expense B Amount
3. Expense C Amount
4. Expense D Amount
5. Total Amount Claimed

### Canonical Flow Mapping Points

1. `MVP-05-AI-Extraction-Subflow`
   - Action: `Create ExtractionResult`
   - Maps expense A/B/C/D and total into Dataverse currency columns.
2. `MVP-02-D365-Write-Subflow` (optional downstream write)
   - Action: write/create target D365 record
   - Uses same payload values when business table write-through is required.

### Mapping Guidance

1. Compose actions for expense fields are optional; direct expression mapping in `Create ExtractionResult` is supported and used.
2. Total amount must use null-safe fallback logic when any expense line is blank.
3. Blank all-expense scenarios should resolve to `null` for total, not zeroed string values.

---

## Error Handling & Dead-Letter Queue (Issue #33)

**Dead-letter queue:** SharePoint folder `FormIntake/FormIntakeErrors` (or list `FormIntakeErrors`) with columns/metadata:
- `CorrelationId`, `FormFileName`, `FailureStage` (Intake/Extraction/D365Write), `ErrorMessage`, `Timestamp`, `RetryCount`, `Status` (Open/Resolved)

**Retry strategy:**
- Flow 2 (Extraction): 1 automatic retry after 2 minutes
- Flow 3 (D365 Write): up to 3 retries with exponential backoff (2m, 5m, 10m)
- After max retries: write to dead-letter queue, send alert email

---

## Manual Review & Correction Flow (Issue #31)

**Name:** `VAFE-Flow-04-ManualReview`

Triggered when `CorrectionRecord` rows exist with Status = Pending. Routes to a Power Apps canvas app (or Teams Adaptive Card) for human reviewer to approve/reject each flagged field. On approval, updates `ExtractionResult` and triggers Flow 3.
