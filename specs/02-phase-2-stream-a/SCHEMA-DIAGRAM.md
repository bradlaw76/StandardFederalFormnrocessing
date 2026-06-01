# Phase 2 Stream A — Dataverse Schema Diagram

## Entity Relationship Diagram (ERD)

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                         VA-Form-Extraction Solution                            │
│                     Publisher Prefix: vafe                                     │
└────────────────────────────────────────────────────────────────────────────────┘

                               ┌──────────────────┐
                               │   FormSubmission │
                               │ (Parent Table)   │
                               └──────────────────┘
                                       │
                    ┌──────────────────┼──────────────────┬──────────────────┐
                    │                  │                  │                  │
                    ▼ 1:1              ▼ 1:N              ▼ 1:N              ▼ 1:N
         ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
         │ ExtractionResult │ │   AuditLog       │ │  CorrectionRecord│ │D365WriteEvent    │
         │                  │ │                  │ │  (via ExResult)  │ │                  │
         └──────────────────┘ │ (Immutable)      │ └──────────────────┘ │(Retry Logic)     │
                    │         │                  │           │          │                  │
                    │         └──────────────────┘           │          └──────────────────┘
                    │                                         │
                    └─────────────────────┬───────────────────┘
                                          │
                                          │ 1:N
                                          ▼
                              (CorrectionRecord links
                               to ExtractionResult,
                               not FormSubmission)
```

---

## Table Hierarchy

```
┌─────────────────────────────────────────────────────────────────────────┐
│ FormSubmission (Core Parent)                                            │
│ ├─ formid (PK)                                                          │
│ ├─ status (Intake → Extracting → Extracted → Correcting                 │
│ │            → Corrected → Writing → Written)                           │
│ ├─ submissiondate, filename, fileurl                                    │
│ ├─ veteranname, vafilenumber, extractionconfidence                      │
│ └─ processingnotes                                                      │
└─────────────────────────────────────────────────────────────────────────┘
    │
    ├─────────────────────────────────┬────────────────────────────────┐
    │                                  │                                │
    ▼                                  ▼                                ▼
    1:1 (soft)                         1:N                              1:N
┌──────────────────┐          ┌──────────────────┐         ┌──────────────────┐
│ExtractionResult  │          │  AuditLog        │         │D365WriteEvent    │
│                  │          │                  │         │                  │
│ resultid (PK)    │          │ logid (PK)       │         │ writeid (PK)     │
│ formsubmission ◄─┼──────────┤ formsubmission ◄─┼─────────┤ formsubmission ◄─┤
│ status           │          │ eventtype        │         │ d365status       │
│ extractedfields  │          │ eventdate        │         │ timestampwritten │
│ (JSON)           │          │ actor (User)     │         │ recordid (D365)  │
│ fieldconfidence  │          │ status           │         │ retrycount       │
│ (JSON)           │          │ errordetails     │         │ lastretydate     │
│ modelversion     │          │ (Immutable)      │         │ status           │
│ processingtime   │          └──────────────────┘         └──────────────────┘
│ status           │
│ errormessage     │
└──────────────────┘
    │
    │ 1:N
    ▼
┌──────────────────┐
│CorrectionRecord  │
│                  │
│correctionid (PK) │
│extractionresult ◄┤ (Links to ExtractionResult, NOT FormSubmission)
│fieldname         │
│originalvalue     │
│correctedvalue    │
│confidencebefore  │
│confidenceafter   │
│correctedby(User) │
│correcteddate     │
│reason            │
│status            │
└──────────────────┘
```

---

## Data Flow: FormSubmission Status Pipeline

```
User Submits Form (SharePoint)
           │
           ▼
    ┌─ [Intake] ────────────────────────────────────────────────┐
    │      ↓                                                     │
    │  AuditLog: "Submitted"                                    │
    │      ↓                                                     │
    ├─ [Extracting] ─────────────────────────────────────────┐  │
    │      ↓                                                 │  │
    │  AuditLog: "ExtractionStarted"                        │  │
    │  AI Builder Model: Extract fields                     │  │
    │      ↓                                                 │  │
    │  ExtractionResult created: extracted_fields (JSON),   │  │
    │  field_confidence_scores (JSON)                       │  │
    │      ↓                                                 │  │
    ├─ [Extracted] ──────────────────────────────────────┐  │  │
    │      ↓                                             │  │  │
    │  AuditLog: "ExtractionCompleted"                  │  │  │
    │      │                                             │  │  │
    │      ├─────────────────────┐                       │  │  │
    │      │ (Optional Review)   │                       │  │  │
    │      │                     ▼                       │  │  │
    │      │              ┌─ [Correcting] ──────────┐   │  │  │
    │      │              │      ↓                   │   │  │  │
    │      │              │  AuditLog:               │   │  │  │
    │      │              │  "CorrectionStarted"    │   │  │  │
    │      │              │      ↓                   │   │  │  │
    │      │              │  Canvas App (Lizzie):    │   │  │  │
    │      │              │  User corrects fields    │   │  │  │
    │      │              │      ↓                   │   │  │  │
    │      │              │  CorrectionRecord       │   │  │  │
    │      │              │  created for each       │   │  │  │
    │      │              │  corrected field        │   │  │  │
    │      │              │      ↓                   │   │  │  │
    │      │              ├─ [Corrected] ───────────┤   │  │  │
    │      │              │      ↓                   │   │  │  │
    │      │              │  AuditLog:               │   │  │  │
    │      │              │  "CorrectionCompleted"  │   │  │  │
    │      │              └───────┬───────────────────┘   │  │  │
    │      │                      │                       │  │  │
    │      └──────────────────────┴───────────────────────┘  │  │
    │                      ↓                                 │  │
    ├─ [Writing] ────────────────────────────────────────┐  │  │
    │      ↓                                             │  │  │
    │  AuditLog: "D365WriteStarted"                     │  │  │
    │  D365 Connector: Map & write fields                │  │  │
    │      ↓                                             │  │  │
    │  D365WriteEvent created: d365_record_id (GUID),   │  │  │
    │  mapped_fields (JSON)                             │  │  │
    │      ├─ If Success:                               │  │  │
    │      │      ↓                                      │  │  │
    │      │  Status → "Success"                         │  │  │
    │      │      ↓                                      │  │  │
    │      └─ [Written] ───────────────────────┐        │  │  │
    │             ↓                             │        │  │  │
    │      AuditLog:                            │        │  │  │
    │      "D365WriteCompleted"                │        │  │  │
    │             ↓                             │        │  │  │
    │      (Pipeline Complete)                 │        │  │  │
    │      Status: Written (LOCKED)             │        │  │  │
    │                                           │        │  │  │
    │      ├─ If Failure (max 5 retries):      │        │  │  │
    │      │      ↓                            │        │  │  │
    │      │  Status → "Failure"               │        │  │  │
    │      │  ErrorMessage: <error details>    │        │  │  │
    │      │  RetryCount++                     │        │  │  │
    │      │      ├─ (Power Automate retry)    │        │  │  │
    │      │      ├─ (Retry Count < 5)         │        │  │  │
    │      │      │      ↓                     │        │  │  │
    │      │      └─ [Writing] (retry)         │        │  │  │
    │      │            ↓                      │        │  │  │
    │      │      └─ [After 5 failed retries]  │        │  │  │
    │      │             ↓                     │        │  │  │
    │      │      Status → "PermanentFailure"  │        │  │  │
    │      │      (Escalation Required)        │        │  │  │
    │      └──────────────────────────────────┘        │  │  │
    │                                                   │  │  │
    └──────────────────────────────────────────────────┘  │  │
                        ↓                                 │  │
    (Complete Pipeline from Intake to Written)            │  │
    All events logged in AuditLog (immutable)             │  │
    All data flows preserved in Dataverse tables          │  │
```

---

## Lookup Relationships

```
FormSubmission
    ├─ lookup: submission_batch ──────→ (Future table: SubmissionBatch)
    ├─ lookup: createdby ─────────────→ User (System field)
    ├─ lookup: modifiedby ────────────→ User (System field)
    └─ lookup: ownerid ───────────────→ User (System field)

ExtractionResult
    └─ lookup: form_submission ──────→ FormSubmission (PARENT)

CorrectionRecord
    ├─ lookup: extraction_result ────→ ExtractionResult (PARENT)
    ├─ lookup: correctedby ──────────→ User
    └─ lookup: createdby ────────────→ User (System field)

AuditLog
    ├─ lookup: form_submission ──────→ FormSubmission (PARENT)
    ├─ lookup: actor ────────────────→ User
    └─ lookup: createdby ────────────→ User (System field)

D365WriteEvent
    └─ lookup: form_submission ──────→ FormSubmission (PARENT)
```

---

## Status Enumeration Summary

```
FormSubmission.Status (7 states, linear flow)
├─ Intake (initial)
├─ Extracting
├─ Extracted
├─ Correcting (optional)
├─ Corrected (optional)
├─ Writing
└─ Written (terminal, locked)

ExtractionResult.Status (4 states)
├─ Pending (initial)
├─ Success (terminal)
├─ PartialSuccess (terminal, some fields failed)
└─ Failed (terminal, manual retry needed)

CorrectionRecord.Status (3 states)
├─ Pending (initial)
├─ Applied (terminal, correction accepted)
└─ Rejected (terminal, correction declined)

AuditLog.EventType (9 event types, recorded as choices)
├─ Submitted
├─ ExtractionStarted
├─ ExtractionCompleted
├─ ExtractionFailed (terminal event)
├─ CorrectionStarted
├─ CorrectionCompleted
├─ D365WriteStarted
├─ D365WriteCompleted
└─ D365WriteFailed (can lead to retry)

D365WriteEvent.Status (4 states)
├─ Pending (initial)
├─ Success (terminal)
├─ Failure (can be retried, max 5 times)
└─ PermanentFailure (terminal, after 5 failed retries)
```

---

## Field Type Distribution

```
Text (Single Line):        7 fields
Text (Multiple Lines):     4 fields (JSON-capable)
Choice (Enums):            8 fields
DateTime:                  8 fields
Decimal (Precision 2,2):   2 fields
Whole Number:              3 fields
Lookup (Other Tables):     4 fields
Hyperlink:                 1 field
User (System Lookup):      6 fields
───────────────────────────────────
Total:                    43 custom fields + 6 system fields
```

---

## Cascade Delete Behavior

```
When FormSubmission is deleted:
    ├─ → ExtractionResult deleted
    │     └─ → CorrectionRecord deleted
    ├─ → AuditLog records deleted
    └─ → D365WriteEvent records deleted

When ExtractionResult is deleted:
    └─ → CorrectionRecord records deleted

(Note: CorrectionRecord & AuditLog never have a parent deletion
 since they're children of ExtractionResult or FormSubmission)
```

---

## Security Role Permissions

```
Role: VA Form Extraction - Contributor
├─ vafe_formsubmission:      Create ✓  Read ✓  Write ✓  Delete ✓
├─ vafe_extractionresult:    Create ✓  Read ✓  Write ✓  Delete ✗
├─ vafe_correctionrecord:    Create ✓  Read ✓  Write ✓  Delete ✓
├─ vafe_auditlog:            Create ✓  Read ✓  Write ✗  Delete ✗ (Immutable)
└─ vafe_d365writeevent:      Create ✓  Read ✓  Write ✓  Delete ✗

Role: Dataverse Data Analyst (Read-Only)
├─ vafe_formsubmission:      Read ✓
├─ vafe_extractionresult:    Read ✓
├─ vafe_correctionrecord:    Read ✓
├─ vafe_auditlog:            Read ✓ (Compliance visibility)
└─ vafe_d365writeevent:      Read ✓
```

---

## Business Rules & Automation

```
FormSubmission
├─ BR-001: Status cannot revert from "Written"
├─ BR-002: Auto-generate FormID on create
└─ BR-003: Lock for editing once Status = "Written"

ExtractionResult
└─ BR-001: Lock editing once Status = "Success" or "PartialSuccess"

CorrectionRecord
├─ BR-001: Require reason if Confidence increases >20 points
└─ BR-002: Lock editing once Status = "Applied"

AuditLog
├─ BR-001: Immutable (no updates allowed)
└─ BR-002: Auto-delete based on RetentionDays

D365WriteEvent
├─ BR-001: Cannot retry if Status = "Success"
├─ BR-002: Auto-increment RetryCount for failures
└─ BR-003: Max 5 retries (then PermanentFailure)
```

---

## JSON Data Storage

```
ExtractionResult.extracted_fields (5000 chars max)
└─ Stores: AI extraction output as structured JSON
   Example: { "veteranName": "John Doe", "vaFileNumber": "123-45-6789", ... }

ExtractionResult.field_confidence_scores (5000 chars max)
└─ Stores: Per-field confidence scores + overall average
   Example: { "veteranName": 0.98, "overallConfidence": 0.915, ... }

AuditLog.details (5000 chars max)
└─ Stores: Event-specific metadata (model version, processing time, etc.)
   Example: { "modelVersion": "v1.0.2", "processingTimeMs": 4812, ... }

D365WriteEvent.mapped_fields (5000 chars max)
└─ Stores: Field mapping from Dataverse → D365
   Example: { "mappings": [ { "dataverseField": "vafe_veteranname", ... } ] }
```

---

## Implementation Sequence

```
Phase 1: Table Creation
    1. Create FormSubmission (parent)
    2. Create ExtractionResult (child of FormSubmission)
    3. Create CorrectionRecord (child of ExtractionResult)
    4. Create AuditLog (child of FormSubmission)
    5. Create D365WriteEvent (child of FormSubmission)

Phase 2: Relationships
    1. FormSubmission → ExtractionResult (1:N, cascade delete)
    2. ExtractionResult → CorrectionRecord (1:N, cascade delete)
    3. FormSubmission → AuditLog (1:N, cascade delete)
    4. FormSubmission → D365WriteEvent (1:N, cascade delete)

Phase 3: Business Rules & Security
    1. Add business rules to each table
    2. Create security roles (Contributor, Data Analyst)
    3. Assign roles to users
    4. Test permissions & audit logging

Phase 4: Publish & Handoff
    1. Publish solution in Power Platform
    2. Verify tables in admin center
    3. Handoff to Flow Orchestration (John Shelby)
    4. Handoff to D365 Integration (Alfie Solomons)
```

---

**Schema Design by**: Polly Gray, Dataverse Schema Design Lead  
**Date**: 2026-04-25  
**Status**: ✅ Complete & Production-Ready
