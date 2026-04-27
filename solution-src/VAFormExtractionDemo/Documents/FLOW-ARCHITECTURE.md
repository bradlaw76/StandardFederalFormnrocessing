# Power Automate Flow Architecture
**Issue:** #18 | **Owner:** John Shelby | **Status:** Complete

---

## Overview: 3-Flow Pipeline

```
SharePoint (file upload)
        │
        ▼
┌─────────────────────┐
│  Flow 1: Intake     │  Trigger: file created in FormIntake library
│  (Trigger)          │  Creates: FormSubmission record, status = Intake
└────────┬────────────┘
         │ status → Extracting
         ▼
┌─────────────────────┐
│  Flow 2: Extraction │  Trigger: FormSubmission status = Extracting
│  (AI Invocation)    │  Calls: AI Builder VAForm10-3542-Extractor
└────────┬────────────┘  Creates: ExtractionResult record
         │               Routes: Accept / Flag / Reject per confidence
         │
    ┌────┴────┐
    │         │
    ▼         ▼
[≥80%]    [60-79%]     [<60%]
    │      Route to      Route to
    │      Review Flow   Review Flow
    ▼      (issue #31)   (issue #31)
┌─────────────────────┐
│  Flow 3: D365 Write │  Trigger: ExtractionResult status = Accepted
│  (Integration)      │  Maps: fields to D365 entities
└─────────────────────┘  Creates: D365WriteEvent record
                         Handles: retry logic, error tracking
```

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

## Shared Infrastructure

### Connector Actions Used Across All Flows
| Connector | Action | Used In |
|-----------|--------|---------|
| SharePoint | Get file content | Flow 2 |
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
