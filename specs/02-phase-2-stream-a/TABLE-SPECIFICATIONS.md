# Phase 2 Stream A — Dataverse Table Specifications

**Phase**: Phase 2 (Foundational)  
**Stream**: A — Dataverse Schema Design  
**Assigned To**: Polly Gray (Dataverse Schema Design Lead)  
**Issues**: #11, #12, #13, #14, #15  
**Status**: Complete & Documented  
**Solution**: VA-Form-Extraction (Publisher Prefix: `vafe`)  
**Date Created**: 2026-04-25

---

## Executive Summary

This document specifies the complete Dataverse schema for the VA Form 10-3542 extraction pipeline. Five core tables are defined with full field specifications, data types, validation rules, relationships, and business rules.

---

## Table 1: FormSubmission (Primary Entity)

**Table Name (API)**: `vafe_formsubmission`  
**Display Name**: Form Submission  
**Purpose**: Track each VA Form 10-3542 upload through the entire processing pipeline  
**Ownership**: User  
**Access**: Read/Write

### Fields

| Field Name | API Name | Type | Length | Required | Unique | Description |
|------------|----------|------|--------|----------|--------|-------------|
| **Form ID** | `vafe_formid` | Text (Single Line) | 100 | Yes | Yes | Unique identifier: `VA-3542-{YYYY-MM-DD-HHmm}-{UUID}` |
| **Submission Date** | `vafe_submissiondate` | Date and Time | — | Yes | No | When form was uploaded to SharePoint FormIntake |
| **File Name** | `vafe_filename` | Text (Single Line) | 256 | Yes | No | Original PDF filename (e.g., `VA-3542-Doe-John-2026-04-25.pdf`) |
| **File URL** | `vafe_fileurl` | Hyperlink | — | Yes | No | Direct link to file in SharePoint FormIntake library |
| **Status** | `vafe_status` | Choice | — | Yes | No | **Choice Values:** Intake → Extracting → Extracted → Correcting → Corrected → Writing → Written |
| **Veteran Name** | `vafe_veteranname` | Text (Single Line) | 256 | No | No | Extracted from form by AI (can be corrected) |
| **VA File Number** | `vafe_vafilenumber` | Text (Single Line) | 50 | No | No | VA file number from form (can be corrected) |
| **Extraction Confidence** | `vafe_extractionconfidence` | Decimal | Precision: 2, Scale: 2 | No | No | Overall extraction confidence 0.00–100.00 |
| **Submission Batch** | `vafe_submissionbatch` | Lookup (SubmissionBatch) | — | No | No | Groups multiple forms in single batch for processing |
| **Created By** | `createdby` | Lookup (User) | — | Yes | No | System field: Who submitted the form |
| **Created On** | `createdon` | Date and Time | — | Yes | No | System field: Timestamp of record creation |
| **Processing Notes** | `vafe_processingnotes` | Text (Multiple Lines) | 2000 | No | No | Internal notes about processing |

### Validations & Business Rules

**BR-FormSubmission-001**: Status cannot change from Written back to earlier states  
```
Trigger: On Change of Status
Condition: IF Status = "Written" AND previous Status != "Written" 
Action: Lock status field from further changes
```

**BR-FormSubmission-002**: Form ID auto-generation  
```
Trigger: On Create
Action: Generate Form ID as "VA-3542-{current date/time}-{GUID}" if not provided
```

---

## Table 2: ExtractionResult

**Table Name (API)**: `vafe_extractionresult`  
**Display Name**: Extraction Result  
**Purpose**: Store AI extraction results with field-level confidence scores  
**Ownership**: User  
**Access**: Read/Write

### Fields

| Field Name | API Name | Type | Length | Required | Description |
|------------|----------|------|--------|----------|-------------|
| **Result ID** | `vafe_resultid` | Text (Single Line) | 100 | Yes | Unique identifier (UUID) |
| **Form Submission** | `vafe_formsubmission` | Lookup (FormSubmission) | — | Yes | Reference to parent form |
| **Extraction Date** | `vafe_extractiondate` | Date and Time | — | Yes | When AI extraction completed |
| **Extracted Fields** | `vafe_extractedfields` | Text (Multiple Lines) | 5000 | Yes | JSON object with all extracted fields and values |
| **Field Confidence Scores** | `vafe_fieldconfidencescores` | Text (Multiple Lines) | 5000 | No | JSON object with per-field confidence scores |
| **AI Model Version** | `vafe_aimodelversion` | Text (Single Line) | 50 | No | Document model version used (e.g., "v1.0.2") |
| **Processing Time (ms)** | `vafe_processingtimems` | Whole Number | — | No | Milliseconds taken for extraction |
| **Status** | `vafe_status` | Choice | — | Yes | **Choice Values:** Pending → Success → PartialSuccess → Failed |
| **Error Message** | `vafe_errormessage` | Text (Multiple Lines) | 2000 | No | If Status = Failed, details of the error |

### Example JSON Structure (Extracted Fields)

```json
{
  "veteranName": "John Michael Doe",
  "vaFileNumber": "123-45-6789",
  "serviceNumber": "N/A",
  "dateOfBirth": "1960-05-15",
  "placeOfBirth": "Chicago, IL",
  "dateOfEntryOnActiveDuty": "1982-06-01",
  "serviceExit": "1985-08-31",
  "branchOfService": "Army",
  "formCompletionDate": "2026-04-25"
}
```

### Example Confidence Scores

```json
{
  "veteranName": 0.98,
  "vaFileNumber": 0.95,
  "serviceNumber": 0.00,
  "dateOfBirth": 0.92,
  "placeOfBirth": 0.87,
  "dateOfEntryOnActiveDuty": 0.91,
  "serviceExit": 0.89,
  "branchOfService": 0.96,
  "formCompletionDate": 0.94,
  "overallConfidence": 0.915
}
```

### Validations & Business Rules

**BR-ExtractionResult-001**: Cannot edit if Status = Success or PartialSuccess  
```
Trigger: On Update
Condition: IF Status = "Success" OR Status = "PartialSuccess"
Action: Block all field updates except Status
```

---

## Table 3: CorrectionRecord

**Table Name (API)**: `vafe_correctionrecord`  
**Display Name**: Correction Record  
**Purpose**: Track user corrections to AI extraction results  
**Ownership**: User  
**Access**: Read/Write

### Fields

| Field Name | API Name | Type | Length | Required | Description |
|------------|----------|------|--------|----------|-------------|
| **Correction ID** | `vafe_correctionid` | Text (Single Line) | 100 | Yes | UUID |
| **Extraction Result** | `vafe_extractionresult` | Lookup (ExtractionResult) | — | Yes | Reference to extraction being corrected |
| **Field Name** | `vafe_fieldname` | Text (Single Line) | 256 | Yes | Name of field corrected (e.g., "veteranName") |
| **Original Value** | `vafe_originalvalue` | Text (Multiple Lines) | 2000 | No | AI-extracted value before correction |
| **Corrected Value** | `vafe_correctedvalue` | Text (Multiple Lines) | 2000 | Yes | User-corrected value |
| **Confidence Before** | `vafe_confidencebefore` | Decimal | Precision: 2, Scale: 2 | No | AI confidence before correction (0.00–100.00) |
| **Confidence After** | `vafe_confidenceafter` | Decimal | Precision: 2, Scale: 2 | No | Expected confidence after correction (0.00–100.00) |
| **Corrected By** | `vafe_correctedby` | Lookup (User) | — | Yes | Who made the correction |
| **Corrected Date** | `vafe_correcteddate` | Date and Time | — | Yes | When correction was made |
| **Reason** | `vafe_reason` | Choice | — | No | **Choice Values:** OCR Error, Unclear, Logic Error, Other |
| **Status** | `vafe_status` | Choice | — | Yes | **Choice Values:** Pending → Applied → Rejected |

### Validations & Business Rules

**BR-CorrectionRecord-001**: Reason required if Confidence increased significantly  
```
Trigger: On Create/Update
Condition: IF ConfidenceAfter - ConfidenceBefore > 20 AND Reason = NULL
Action: Show error "Reason required for significant confidence change"
```

**BR-CorrectionRecord-002**: Cannot edit once Status = Applied  
```
Trigger: On Update
Condition: IF Status = "Applied"
Action: Block field updates
```

---

## Table 4: AuditLog

**Table Name (API)**: `vafe_auditlog`  
**Display Name**: Audit Log  
**Purpose**: Compliance and security audit trail for all form processing events  
**Ownership**: User  
**Access**: Read/Create (Delete only by system/admin)

### Fields

| Field Name | API Name | Type | Length | Required | Description |
|------------|----------|------|--------|----------|-------------|
| **Log ID** | `vafe_logid` | Text (Single Line) | 100 | Yes | UUID |
| **Form Submission** | `vafe_formsubmission` | Lookup (FormSubmission) | — | Yes | Reference to form being logged |
| **Event Type** | `vafe_eventtype` | Choice | — | Yes | **Choice Values:** Submitted, ExtractionStarted, ExtractionCompleted, CorrectionStarted, CorrectionCompleted, D365WriteStarted, D365WriteCompleted, ExtractionFailed, D365WriteFailed |
| **Event Date** | `vafe_eventdate` | Date and Time | — | Yes | When event occurred |
| **Actor** | `vafe_actor` | Lookup (User) | — | Yes | Who triggered the event (user or system) |
| **Details** | `vafe_details` | Text (Multiple Lines) | 5000 | No | Event-specific details (JSON recommended) |
| **Status** | `vafe_status` | Choice | — | Yes | **Choice Values:** Success, Failure |
| **Error Details** | `vafe_errordetails` | Text (Multiple Lines) | 2000 | No | If Status = Failure, error stack trace |
| **Retention Days** | `vafe_retentiondays` | Whole Number | — | Yes | Days to retain this log (90 days default) |
| **IP Address** | `vafe_ipaddress` | Text (Single Line) | 50 | No | Source IP if user-initiated |

### Audit Event Examples

```
Event: Submitted
Actor: User (john.smith@va.gov)
Details: { "fileName": "VA-3542-Doe-John-2026-04-25.pdf", "fileSize": "2.3 MB" }
Status: Success

Event: ExtractionCompleted
Actor: System (AI Builder Service Account)
Details: { "modelVersion": "v1.0.2", "processingTime": "4812 ms", "confidence": "91.5%" }
Status: Success

Event: CorrectionStarted
Actor: User (jane.reviewer@va.gov)
Details: { "fieldsCorrected": 2, "fieldsReviewed": 18 }
Status: Success

Event: D365WriteFailed
Actor: System (Power Automate Flow)
Details: { "d365Table": "VA_FormSubmission", "reason": "Connection timeout" }
Status: Failure
Error Details: "Connection to D365 timed out after 30 seconds. Retry queued."
```

### Validations & Business Rules

**BR-AuditLog-001**: Immutable audit records  
```
Trigger: On Update
Condition: ALWAYS
Action: Block all updates (audit logs are immutable)
```

**BR-AuditLog-002**: Retention policy enforcement  
```
Trigger: Scheduled (Daily)
Condition: IF EventDate + RetentionDays < TODAY
Action: Mark record for archival/deletion
```

---

## Table 5: D365WriteEvent

**Table Name (API)**: `vafe_d365writeevent`  
**Display Name**: D365 Write Event  
**Purpose**: Track writes to Dynamics 365 for form data integration  
**Ownership**: User  
**Access**: Read/Write

### Fields

| Field Name | API Name | Type | Length | Required | Description |
|------------|----------|------|--------|----------|-------------|
| **Write ID** | `vafe_writeid` | Text (Single Line) | 100 | Yes | UUID |
| **Form Submission** | `vafe_formsubmission` | Lookup (FormSubmission) | — | Yes | Reference to form being written |
| **D365 Table** | `vafe_d365table` | Text (Single Line) | 100 | Yes | D365 table being written (e.g., "VA_FormSubmission", "contact") |
| **D365 Record ID** | `vafe_d365recordid` | Text (Single Line) | 100 | Yes | GUID of created/updated record in D365 |
| **Write Date** | `vafe_writedate` | Date and Time | — | Yes | When write occurred |
| **Mapped Fields** | `vafe_mappedfields` | Text (Multiple Lines) | 5000 | No | JSON mapping of Dataverse → D365 field values |
| **Status** | `vafe_status` | Choice | — | Yes | **Choice Values:** Pending → Success → Failure |
| **Error Message** | `vafe_errormessage` | Text (Multiple Lines) | 2000 | No | If Status = Failure, error details |
| **Retry Count** | `vafe_retrycount` | Whole Number | — | No | Number of retry attempts (0 = first attempt) |
| **Last Retry Date** | `vafe_lastretydate` | Date and Time | — | No | When last retry occurred |

### Example Mapped Fields JSON

```json
{
  "mappings": [
    { "dataverseField": "vafe_veteranname", "dataverseValue": "John Michael Doe", "d365Field": "cr_veteranname", "status": "mapped" },
    { "dataverseField": "vafe_vafilenumber", "dataverseValue": "123-45-6789", "d365Field": "cr_vafilenumber", "status": "mapped" },
    { "dataverseField": "vafe_extractionconfidence", "dataverseValue": "91.5", "d365Field": "cr_confidence", "status": "mapped" }
  ],
  "d365RecordType": "contact",
  "createMode": true
}
```

### Validations & Business Rules

**BR-D365WriteEvent-001**: Cannot retry if Status = Success  
```
Trigger: On Update
Condition: IF Status = "Success" AND RetryCount updated
Action: Block retry operation
```

**BR-D365WriteEvent-002**: Auto-increment retry count  
```
Trigger: On Create (when Status = "Failure")
Condition: ALWAYS
Action: Auto-populate RetryCount = 0
```

**BR-D365WriteEvent-003**: Maximum 5 retries  
```
Trigger: On Update
Condition: IF RetryCount >= 5 AND Status = "Failure"
Action: Block further retries, set to "PermanentFailure"
```

---

## Relationships

### 1:N Relationships Matrix

| Parent Table | Child Table | Lookup Field | Relationship Name | Cascade Behavior | Purpose |
|--------------|-------------|--------------|-------------------|------------------|---------|
| **FormSubmission** | **ExtractionResult** | `vafe_formsubmission` | `vafe_formsubmission_extractionresult` | Cascade Delete | One form can have one extraction result |
| **ExtractionResult** | **CorrectionRecord** | `vafe_extractionresult` | `vafe_extractionresult_correctionrecord` | Cascade Delete | One extraction can have multiple corrections |
| **FormSubmission** | **AuditLog** | `vafe_formsubmission` | `vafe_formsubmission_auditlog` | Cascade Delete | One form has many audit events |
| **FormSubmission** | **D365WriteEvent** | `vafe_formsubmission` | `vafe_formsubmission_d365writeevent` | Cascade Delete | One form tracked in multiple D365 writes |

### Cardinality & Dependencies

```
FormSubmission (1)
  ├─ ExtractionResult (0..1)
  │  └─ CorrectionRecord (0..*)
  ├─ AuditLog (0..*)
  └─ D365WriteEvent (0..*)
```

---

## Security & RBAC

### Default Security Roles

**Dataverse Security Role**: `VA Form Extraction - Contributor`
- **Organization-owned**: Read/Write all tables
- **Default Members**: VA Form Extraction team members
- **Permissions**:
  - `vafe_formsubmission`: Create, Read, Write, Delete
  - `vafe_extractionresult`: Create, Read, Write
  - `vafe_correctionrecord`: Create, Read, Write, Delete
  - `vafe_auditlog`: Create, Read (no Write/Delete — immutable)
  - `vafe_d365writeevent`: Create, Read, Write

**Dynamics 365 Data Analyst Role**
- **Permissions**: Read-only access to all tables for reporting
- **Use Case**: Analytics, audit reports, compliance validation

---

## Data Flow & Status Transitions

### FormSubmission Status Flow

```
┌─ [Intake] (initial)
│      ↓
├─ [Extracting] (AI flow running)
│      ↓
├─ [Extracted] (AI completed)
│      ├─→ [Correcting] (optional, user review)
│      │      ↓
│      ├─ [Corrected] (corrections applied)
│      ↓
├─ [Writing] (D365 flow running)
│      ↓
└─ [Written] (D365 update complete, FINAL)
```

### ExtractionResult Status Flow

```
[Pending] → [Success] (or [PartialSuccess] if some fields failed)
[Pending] → [Failed] (if extraction entirely failed)
```

### CorrectionRecord Status Flow

```
[Pending] → [Applied] (user correction accepted)
[Pending] → [Rejected] (user correction declined)
```

### D365WriteEvent Status Flow

```
[Pending] → [Success] (first-attempt write succeeded)
[Pending] → [Failure] → [Pending] (retry via Power Automate)
[Failure] after 5 retries → [PermanentFailure] (archived)
```

---

## Field Type Reference

| Type | Dataverse API | Use Case | Example |
|------|---------------|----------|---------|
| **Text (Single Line)** | String | Names, IDs, codes | `VA-3542-2026-04-25-12:30-{UUID}` |
| **Text (Multiple Lines)** | Memo | Large text, JSON, notes | Extracted fields JSON object |
| **Choice** | OptionSet | Fixed values | Status: Intake, Extracting, etc. |
| **Date and Time** | DateTime | Timestamps | 2026-04-25 14:30:00Z |
| **Decimal** | Decimal | Confidence scores, percentages | 91.50 |
| **Whole Number** | Integer | Counts, retention days | 90 |
| **Lookup** | Lookup | References to other tables | FormSubmission, User |
| **Hyperlink** | String | URLs | SharePoint file link |

---

## Implementation Checklist

- [ ] All 5 tables created in `VA-Form-Extraction` solution
- [ ] Field names match API names exactly (with `vafe_` prefix)
- [ ] All lookups created with correct parent tables
- [ ] Cascade delete configured for all relationships
- [ ] Business rules created and tested
- [ ] Security roles assigned and tested
- [ ] Status choices populated
- [ ] Solution published
- [ ] Verified in Power Platform Admin Center
- [ ] Documentation handed to John Shelby (Flow Orchestration) for Flow integration

---

## Handoff Deliverables

1. ✅ **Table Specifications** (this document)
2. ✅ **Relationships Diagram** (see relationships section above)
3. ✅ **Business Rules** (embedded in each table section)
4. ✅ **Security Role Configuration**
5. ✅ **Status Transition Diagrams** (see data flow section)
6. ✅ **JSON Schema Examples** (see extracted fields examples)

**Ready for**: Phase 2 Data Flow (Power Automate Flow Design)  
**Next Owner**: John Shelby (Flow Orchestration)

---

**Created by**: Polly Gray, Dataverse Schema Design Lead  
**Date**: 2026-04-25  
**Confidence**: Production-ready  
**Status**: ✅ COMPLETE
