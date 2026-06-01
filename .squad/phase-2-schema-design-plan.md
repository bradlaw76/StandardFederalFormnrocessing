# Polly Gray — Phase 2 Dataverse Schema Design Plan

**Status**: Ready to begin  
**Depends On**: T006 (Solution Container) ✅ COMPLETE  
**Assigned To**: Polly Gray (Dataverse Schema Design)  
**Estimated Duration**: Phase 2 (6–8 hours total)  
**Created**: 2026-04-24

---

## Overview

Phase 2 foundational work focuses on creating the Dataverse schema that will support the VA Form extraction pipeline. This document outlines the table structure, relationships, and constraints needed for:

1. Form intake and tracking (FormSubmission)
2. Extraction results from AI (ExtractionResult)
3. User corrections and validation (CorrectionRecord)
4. Audit and compliance logging (AuditLog)
5. D365 integration events (D365WriteEvent)

---

## Tables to Create (in order)

### 1. FormSubmission (Primary Table)
**Purpose**: Track each submitted VA Form 10-3542

**Fields**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `form_id` | Text (Primary Key) | Yes | Unique identifier: `VA-3542-{YYYY-MM-DD-HHmm}-{UUID}` |
| `submitted_date` | DateTime | Yes | When form was uploaded |
| `file_name` | Text | Yes | Original PDF filename |
| `file_url` | Hyperlink | Yes | SharePoint FormIntake library URL |
| `status` | Choice | Yes | Intake → Extracting → Extracted → Correcting → Corrected → Writing → Written |
| `veteran_name` | Text | No | Extracted veteran name |
| `va_file_number` | Text | No | Extracted VA file number |
| `extraction_confidence` | Decimal | No | Overall extraction confidence 0-100 |
| `submission_batch` | Lookup | No | Group multiple forms in single batch |
| `created_by` | User | Yes | Who submitted |
| `notes` | Memo | No | Internal notes |

---

### 2. ExtractionResult (N:1 from FormSubmission)
**Purpose**: Store AI extraction results with field-level confidence

**Fields**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `result_id` | Text (Primary Key) | Yes | UUID |
| `form_submission` | Lookup | Yes | Reference to FormSubmission |
| `extraction_date` | DateTime | Yes | When extraction occurred |
| `extracted_fields` | JSON | Yes | Structured extraction: {field_name: value, confidence: score} |
| `field_confidence_scores` | Decimal | No | Average confidence across all fields |
| `ai_model_version` | Text | No | Version of document model used |
| `processing_time_ms` | Int | No | Time taken for extraction |
| `status` | Choice | Yes | Pending → Success → PartialSuccess → Failed |
| `error_message` | Memo | No | If status = Failed |

---

### 3. CorrectionRecord (N:1 from ExtractionResult)
**Purpose**: Track user corrections and quality feedback

**Fields**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `correction_id` | Text (Primary Key) | Yes | UUID |
| `extraction_result` | Lookup | Yes | Reference to ExtractionResult |
| `field_name` | Text | Yes | Which field was corrected |
| `original_value` | Text | No | AI extracted value |
| `corrected_value` | Text | Yes | User corrected value |
| `confidence_before` | Decimal | No | AI confidence before correction |
| `confidence_after` | Decimal | No | Expected confidence after correction |
| `corrected_by` | User | Yes | Who made the correction |
| `corrected_date` | DateTime | Yes | When correction was made |
| `reason` | Choice | No | Why correction was needed: OCR Error | Unclear | Logic | Other |
| `status` | Choice | Yes | Pending → Applied → Rejected |

---

### 4. AuditLog (N:1 from FormSubmission)
**Purpose**: Compliance and audit trail logging

**Fields**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `log_id` | Text (Primary Key) | Yes | UUID |
| `form_submission` | Lookup | Yes | Reference to FormSubmission |
| `event_type` | Choice | Yes | Submitted → ExtractionStarted → ExtractionCompleted → CorrectionStarted → CorrectionCompleted → D365WriteStarted → D365WriteCompleted |
| `event_date` | DateTime | Yes | When event occurred |
| `actor` | User | Yes | Who triggered the event |
| `details` | Memo | No | Event details |
| `status` | Choice | Yes | Success → Failure |
| `error_details` | Memo | No | If status = Failure |
| `retention_days` | Int | Yes | How long to retain (90 days default) |

---

### 5. D365WriteEvent (N:1 from FormSubmission)
**Purpose**: Track writes to Dynamics 365

**Fields**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `write_id` | Text (Primary Key) | Yes | UUID |
| `form_submission` | Lookup | Yes | Reference to FormSubmission |
| `d365_table` | Text | Yes | D365 table being written to (e.g., `VA_FormSubmission`) |
| `d365_record_id` | Text | Yes | ID of created/updated record in D365 |
| `write_date` | DateTime | Yes | When write occurred |
| `mapped_fields` | JSON | No | Mapping of Dataverse → D365 fields |
| `status` | Choice | Yes | Pending → Success → Failure |
| `error_message` | Memo | No | If status = Failure |
| `retry_count` | Int | No | Number of retry attempts |
| `last_retry_date` | DateTime | No | When last retry occurred |

---

## Relationships to Create

### 1:N Relationships

| Parent | Child | Behavior | Purpose |
|--------|-------|----------|---------|
| FormSubmission | ExtractionResult | Cascade delete | One form has one extraction result |
| ExtractionResult | CorrectionRecord | Cascade delete | One extraction can have multiple corrections |
| FormSubmission | AuditLog | Cascade delete | One form has many audit events |
| FormSubmission | D365WriteEvent | Cascade delete | One form tracked in multiple D365 writes |

---

## Business Rules to Create

### FormSubmission Status Flow
```
Intake (initial)
  ↓
Extracting (flow running)
  ↓
Extracted (AI completed)
  ↓
Correcting (optional, user reviewing)
  ↓
Corrected (optional, corrections applied)
  ↓
Writing (D365 flow running)
  ↓
Written (D365 update complete)
```

### Validation Rules
- FormSubmission.form_id must be unique
- ExtractionResult.field_confidence_scores cannot exceed 100
- CorrectionRecord.corrected_date must be after ExtractionResult.extraction_date
- D365WriteEvent.status cannot change from Success to Failure

---

## Security & Permissions

| Table | Permission | Roles |
|-------|-----------|-------|
| FormSubmission | Read/Create/Update | VA Staff, Admin |
| ExtractionResult | Read | VA Staff, Admin, Manager |
| CorrectionRecord | Read/Create/Update | VA Staff, Manager |
| AuditLog | Read | Manager, Compliance Officer |
| D365WriteEvent | Read | Admin, D365 Admin |

---

## Success Criteria for Phase 2

- ✅ All 5 tables created in Dataverse
- ✅ All relationships configured correctly
- ✅ All business rules implemented
- ✅ Security roles assigned
- ✅ Schema validation testing passed
- ✅ Schema locked (ready for flows)
- ✅ Tables added to `VA-Form-Extraction` solution

---

## Timeline Estimate

- **Table Creation**: 45–60 min (1–2 min per table)
- **Relationships**: 15–20 min
- **Business Rules**: 20–30 min
- **Security Configuration**: 15–20 min
- **Testing & Verification**: 30–45 min
- **Buffer/Review**: 20–30 min

**Total Phase 2**: 2.5–3.5 hours

---

## Blocked By
- T006: Create Power Platform Solution Container ✅ **COMPLETE**

## Blocks
- Flow Orchestration (John Shelby) — needs schema locked
- Canvas App Development (Lizzie Stark) — needs schema locked
- D365 Integration (Alfie Solomons) — needs D365WriteEvent table

---

**Ready to start Phase 2 schema design** ✅
