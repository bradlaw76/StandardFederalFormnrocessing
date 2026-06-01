# Implementation Plan: VA Form 10-3542 Extraction Pipeline

**Feature Branch**: `001-form-extraction-pipeline` | **Date**: 2026-04-24 | **Spec**: [spec.md](spec.md)  
**Input**: Feature specification from `/specs/001-form-extraction-pipeline/spec.md` (v1.0.1-Ready)

---

## Summary

**Objective**: Build an end-to-end document processing pipeline that extracts data from VA Form 10-3542 (beneficiary travel authorizations) using Microsoft AI Builder, applies human validation logic, and writes approved records to Dynamics 365 for the BTSSS program.

**Core Value Proposition**: Automate manual data entry on VA forms, reducing beneficiary processing time from days to hours while maintaining 100% compliance audit trail and ≥90% extraction accuracy.

**Approach**: 
1. Ingest PDF forms (handwritten or typed) via SharePoint/email intake
2. Run AI Builder custom document model to extract 7 key fields with confidence scores
3. Route high-confidence extractions (≥95%) directly to D365 write
4. Route lower-confidence fields (80–94%) to human review UI for correction
5. Write approved data to D365 with immutable audit log
6. Capture failed extractions for model retraining

---

## Technical Context

## Technical Context

**Platform**: Microsoft Power Platform (low-code/no-code)

**Primary Components**: 
- Azure AI Builder (custom document extraction model)
- Power Automate (orchestration + workflows)
- Dataverse (data storage + audit)
- Dynamics 365 (destination table, integrated via Dataverse)
- Power Apps (optional correction UI)
- Power BI (analytics dashboard)

**Storage**: 
- Dataverse tables (FormSubmission, ExtractionResult, CorrectionRecord, AuditLog)
- SharePoint (PDF intake location)

**Testing**: 
- Power Automate cloud flow testing (built-in)
- Power Apps canvas testing
- Manual end-to-end testing (flow → Dataverse → D365)

**Target Platform**: Microsoft Power Platform (cloud SaaS)

**Project Type**: Configuration-driven automation (no custom code)

**Performance Goals** (from constitution + spec):
- Extraction latency: <5 seconds per form
- D365 write latency: <2 seconds per record
- Throughput: ≥5 forms/minute concurrent (Power Automate default concurrency)
- Human review queue processing: <4 hours per form

**Constraints**:
- Demo scope: 5 forms for AI Builder training (not production volume)
- Power Automate flow concurrency: 50 parallel flows (adjustable in tenant settings)
- Dataverse storage: Unlimited for demo (storage limits apply at production scale)
- PII handling: Dataverse encryption at rest; Power Automate connections use OAuth2

**Scale/Scope**:
- Demo: ≤100 forms/day
- Training data: 5 annotated VA forms (minimum for AI Builder)
- No retention requirements (demo; not compliance-driven)

---

## Constitution Check

**Gate: Must pass before Phase 0 research**

From `.specify/memory/constitution.md` (v1.0.0):

| Principle | Requirement | Status |
|-----------|-------------|--------|
| **I. Test-First Quality** | 80% code coverage; AI extraction validated against ground truth; failed tests block merge | ⏸️ Deferred to Phase 2 (demo uses manual testing) |
| **II. Code Quality & Maintainability** | SOLID principles; cyclomatic complexity <5; pair review for non-trivial changes | ✅ Power Automate flows are low-code; review via flow designer |
| **III. User Experience Consistency** | Single pattern for form intake → review → submit; WCAG AA (Phase 2) | ✅ Correction UI (Power Apps) follows single pattern; accessibility Phase 2 |
| **IV. Performance & Scale** | 5s extraction, <2s D365 write, ≥500 batch, Redis caching | ✅ Achievable with Power Platform services; demo scope limits batch size to 5 forms |
| **V. Observability & Audit** | Immutable event log; every operation timestamped + user; confidence scores logged | ⏸️ Basic Dataverse table logging (no immutable ledger for demo) |

**Re-check after Phase 1 design**: Post-design, verify that:
- Power Automate flow logic is clear and documented
- Error handling in flows is implemented for common failure modes
- Dataverse schema is locked and versioned
- UI pattern in Power Apps is consistent

---

## Phase 0: Research & Unknowns Resolution

### Technical Unknowns to Resolve

| Unknown | Research Task | Deliverable |
|---------|---------------|-------------|
| AI Builder model setup | How to train custom document model on 5 VA forms; expected accuracy from minimal dataset | AI Builder configuration guide; model training workflow |
| Dataverse schema design | How to model FormSubmission, ExtractionResult, CorrectionRecord, and D365 sync | Dataverse entity design; relationships + fields |
| Power Automate flow orchestration | How to connect AI Builder → Dataverse → D365 using flows; error handling patterns | Main flow diagram; error handling strategy |
| Power Apps correction form | How to build canvas app for manual field correction; validation logic | Power Apps design mockup; validation rules |
| D365 integration via Dataverse | How to sync corrected data from Dataverse to Dynamics 365 table | D365 connector configuration + sync mapping |

### Best Practices Research

| Topic | Research Task | Deliverable |
|-------|---------------|-------------|
| AI Builder accuracy with small dataset | What accuracy is achievable with 5 training forms? | Accuracy expectations + remediation strategy |
| Power Platform naming conventions | Team standards for flows, tables, apps, fields | Naming convention guide |
| Dataverse audit logging | Built-in audit trail vs. custom audit table | Decision: Use Dataverse audit feature or custom table |

**Output**: `research.md` (due end of Phase 0)

---

## Phase 1: Design & Contracts

### 1. Data Model

**Primary Entities** (from spec, refined):

```
FormSubmission
├─ FormID (UUID, primary key)
├─ FileHash (SHA256, unique constraint)
├─ UploadedBy (Entra ID user ID)
├─ UploadTimestamp (DateTime, immutable)
├─ FileName (string)
├─ Status (Enum: Intake → Extracting → ReviewRequired/ReadyForD365 → D365Writing → Complete/WriteFailed/ManualIntake)
└─ Metadata (JSON: {SourceSystem, BatchID, etc.})

ExtractionResult
├─ ExtractionID (UUID, primary key)
├─ FormID (FK to FormSubmission)
├─ ExtractedFields (JSON: {
│   BeneficiaryName: {Value, ConfidenceScore, IsAutoApproved},
│   SSN: {Value, ConfidenceScore, IsAutoApproved},
│   TravelFromDate: {...},
│   TravelToDate: {...},
│   Destination: {...},
│   ReasonForTravel: {...},
│   AuthorizedBy: {...},
│   BenefitType: {...}
│ })
├─ ModelVersion (string, e.g., "AIBuilder-v2.1")
├─ ExtractionTimestamp (DateTime, immutable)
└─ OverallConfidenceScore (float, 0–100)

CorrectionRecord
├─ CorrectionID (UUID, primary key)
├─ ExtractionID (FK to ExtractionResult)
├─ CorrectedBy (Entra ID user ID)
├─ CorrectionTimestamp (DateTime, immutable)
├─ ChangesLog (JSON: {
│   BeneficiaryName: {OldValue, NewValue, Reason},
│   SSN: {...},
│   ...
│ })
├─ ApprovalStatus (Enum: Pending → Approved/Rejected)
└─ ApprovalTimestamp (DateTime, nullable)

D365WriteEvent
├─ WriteEventID (UUID, primary key)
├─ FormID (FK to FormSubmission)
├─ D365RecordID (string, D365 table row key)
├─ WrittenBy (Entra ID user ID)
├─ WriteTimestamp (DateTime, immutable)
├─ WriteStatus (Enum: Success/Failed/Retry)
├─ ErrorDetails (string, if failed)
└─ RetryCount (int, 0–3)

AuditLog
├─ AuditID (UUID, primary key)
├─ Timestamp (DateTime, immutable)
├─ UserID (Entra ID user ID)
├─ ActionType (string: FormIntake, Extraction, Correction, D365Write, D365WriteFailed, Retry, etc.)
├─ TargetEntity (FormID or ExtractionID or WriteEventID)
├─ OperationDetails (JSON: {Description, OldValues, NewValues, etc.})
├─ Status (string: Success/Failure)
├─ ImmutableHash (SHA256, for tamper detection)
└─ SystemID (string, e.g., "FormProcessingV1")
```

**Output**: `data-model.md` (due end of Phase 1)

### 2. Service Contracts & APIs

**Contract 1: AI Builder → Extraction Service**

```
POST /api/extraction/submit
Input: {
  FormID: UUID,
  PdfFileStream: binary,
  FormType: "VA-Form-10-3542",
  ModelVersion: "AIBuilder-v2.1"
}

Output: ExtractionResult {
  ExtractionID: UUID,
  ExtractedFields: JSON,
  OverallConfidenceScore: 0–100,
  Status: "Complete" | "PartialFailure",
  FailureReason: string (if PartialFailure)
}

Error Cases:
- 400: Invalid form type or file
- 413: File too large (>50MB)
- 504: AI Builder timeout (>30s)
```

**Contract 2: Extraction Service → Correction UI**

```
GET /api/forms/{FormID}/correction-view
Output: CorrectionFormView {
  FormID: UUID,
  ExtractedFields: [
    {
      FieldName: string,
      Value: string,
      ConfidenceScore: 0–100,
      IsAutoApproved: boolean,
      ValidationRules: { Pattern, Min, Max, AllowedValues }
    }
  ],
  Status: "ReviewRequired" | "ReadyForD365" | "D365Writing" | "Complete"
}

POST /api/forms/{FormID}/approve
Input: {
  ApprovalStatus: "Approved" | "Rejected",
  CorrectionChanges: { FieldName: NewValue },
  Reason: string
}
Output: { Status: "Success" | "Failure", ErrorMessage: string (if Failure) }
```

**Contract 3: Correction Service → D365 Write**

```
POST /api/d365/submit-record
Input: {
  FormID: UUID,
  ExtractedData: { BeneficiaryName, SSN, TravelFromDate, TravelToDate, Destination, ReasonForTravel, AuthorizedBy, BenefitType },
  IdempotencyKey: UUID (for deduplication),
  WrittenBy: UserID
}

Output: D365WriteResult {
  WriteEventID: UUID,
  D365RecordID: string,
  Status: "Success" | "Retry" | "Failure",
  Message: string
}
```

**Output**: `contracts/` directory (API schemas in OpenAPI 3.0 or async message schemas)

### 3. Quickstart

**Output**: `quickstart.md` — Setup guide for developers to run extraction pipeline locally

---

## Phase 2: Architecture & Implementation Strategy

### High-Level Architecture (Power Platform)

```
SharePoint Form Intake (PDF Upload)
        ↓
Power Automate Trigger (file created)
├─ Store PDF in Dataverse (blob column)
├─ Call AI Builder model API
├─ Parse AI Builder response (extracted fields + confidence scores)
├─ Log to Dataverse AuditLog table
└─ Route decision:
   ├─ IF confidence ≥95%: Auto-approve → D365 Write flow
   └─ IF confidence <95%: Queue for manual review (set status = "ReviewRequired")

Human Correction (Power Apps Canvas App)
├─ Display extracted fields from Dataverse
├─ Staff edits + approves
├─ Update Dataverse record (set status = "Approved")
└─ Trigger D365 Write flow

D365 Write Flow (Power Automate)
├─ Read approved record from Dataverse
├─ Call D365 connector to create record
├─ Update Dataverse status to "Complete"
├─ Log result to AuditLog
└─ Handle errors (retry via Power Automate)

Analytics Dashboard (Power BI)
├─ Connect to Dataverse
├─ Show: forms processed, auto-approved %, review-required %, extraction accuracy
└─ Real-time refresh
```

### Technology Stack Decisions

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| **Document Extraction** | AI Builder custom model | VA Form-specific; train on 5 forms |
| **Orchestration** | Power Automate cloud flows | Low-code, serverless, built-in error handling |
| **Storage (Metadata)** | Dataverse tables | Native to Power Platform; audit logging built-in |
| **Storage (PDF)** | Dataverse blob column or SharePoint | Blob in Dataverse for demo; production would use Azure Blob Storage |
| **Correction UI** | Power Apps canvas app (optional) | Low-code form builder; can use Dataverse form view if minimal |
| **D365 Integration** | D365 connector in Power Automate | Native connector; OAuth2 authentication |
| **Analytics** | Power BI | Native Power Platform dashboards; real-time Dataverse connection |
| **Testing** | Manual end-to-end testing | No automated test framework for demo |

### Implementation Strategy by User Story

| Story | Approach | Effort | Dependencies |
|-------|----------|--------|--------------|
| **US1 (Intake)** | SharePoint folder + Power Automate trigger; validate PDF format + store in Dataverse | 2–3 hours | SharePoint site + Dataverse access |
| **US2 (Extraction + Contact Match)** | AI Builder model trained on 5 forms; extract 20+ fields with confidence scores; Power Automate calls AI Builder API + Contacts query; confidence routing logic + contact match logging | 6–8 hours | AI Builder model training complete; Contacts table populated with test data |
| **US3 (Correction)** | Power Apps canvas form with 20+ editable fields; validation rules; approval button; display matched contact (if found) | 4–5 hours | Dataverse schema locked; contact match results flowing |
| **US4 (D365 Write)** | Power Automate D365 connector; write approved data + Contact ID to Dynamics table | 2–3 hours | D365 environment + table schema; Contact ID mapping |
| **US5 (Analytics)** | Power BI dashboard connecting to Dataverse; show daily metrics (forms processed, confidence distribution, contact match rate) | 2 hours | Power BI license + Dataverse data populated |
| **Total** | **Low-code configuration** | **~18–24 hours** | **1 person, 2–3 days** |

### Dataverse Schema (Demo Scope)

**FormSubmission Table**:
- FormID (Primary key, GUID)
- FileName (String)
- FileBlob (Image/blob, stores PDF)
- UploadedBy (Lookup to User)
- UploadTimestamp (DateTime)
- Status (Option set: Intake → Extracting → ReviewRequired/Auto-Approved → D365Writing → Complete/Failed)
- CreatedOn, ModifiedOn (auto-tracked by Dataverse)

**ExtractionResult Table** (EXPANDED for all form fields):
- ExtractionID (Primary key, GUID)
- FormID (Lookup to FormSubmission)
- **Section A: Traveler Information**
  - ClaimantFullName (String) + Confidence (0–100)
  - ClaimantSSN (String, encrypted) + Confidence
  - ClaimantDateOfBirth (Date) + Confidence
  - ClaimantStatus (Option set: Veteran/Caregiver/Attendant/Donor/Other) + Confidence
  - VeteranFullName (String, if different) + Confidence
  - VeteranSSN (String, encrypted, if different) + Confidence
  - VeteranDateOfBirth (Date, if different) + Confidence
- **Section B: Trip Information**
  - TravelFromAddress (String) + Confidence
  - TravelBeginDate (Date) + Confidence
  - TravelMethodOutbound (Option set: Car/Train/Bus/Taxi/Air/Other) + Confidence
  - ReturnToSameAddress (Boolean) + Confidence
  - TravelEndDate (Date) + Confidence
  - TravelMethodReturn (Option set: Car/Train/Bus/Taxi/Air/Other) + Confidence
  - HasOtherExpenses (Boolean) + Confidence
  - ExpenseA–D_Description (String × 4) + Confidence
  - ExpenseA–D_Amount (Decimal × 4) + Confidence
  - TreatingFacilityName (String) + Confidence
  - TreatingFacilityAddress (String) + Confidence
- **Section C: Certifications**
  - SignatureDate (Date) + Confidence
- **Contact Matching** (NEW)
  - ClaimantContactID (Lookup to Contacts table)
  - VeteranContactID (Lookup to Contacts table)
  - ContactMatchConfidence (0–100, indicates how certain the match is)
- **Metadata**
  - OverallConfidenceScore (Decimal 0–100, average of all fields)
  - CriticalFieldsOnly_Confidence (Decimal 0–100, average of: SSN, Name, DOB, Dates, Facility)
  - ModelVersion (String, e.g., "AIBuilder-v1")
  - ExtractionTimestamp (DateTime)

**CorrectionRecord Table**:
- CorrectionID (Primary key, GUID)
- ExtractionID (Lookup to ExtractionResult)
- CorrectedBy (Lookup to User)
- CorrectionTimestamp (DateTime)
- [Corrected field columns for any fields edited by user]
- ApprovalStatus (Option set: Pending / Approved / Rejected)
- ApprovalTimestamp (DateTime)

**AuditLog Table**:
- AuditID (Primary key, GUID)
- Timestamp (DateTime)
- UserID (String)
- ActionType (String: FormIntake, Extraction, ContactMatch, Correction, D365Write, etc.)
- TargetEntity (String: FormID or ExtractionID)
- Details (Text, JSON with operation details including contact match results)
- Status (String: Success / Failure)

**ContactMatchLog Table** (Optional, for compliance auditing):
- MatchLogID (Primary key, GUID)
- ExtractionID (Lookup to ExtractionResult)
- SearchCriteria (JSON: SSN/Name/DOB used for query)
- MatchResult (JSON: matched ContactID or "NoMatch")
- MatchConfidence (Decimal 0–100)
- Timestamp (DateTime)
- PerformedBy (User ID)

---

### Power Automate Flows (3–4 Required)

**Flow 1: Intake Trigger**
```
Trigger: File created in SharePoint folder
├─ Validate file type (must be PDF)
├─ Create FormSubmission record in Dataverse (set Status = "Extracting")
├─ Store PDF blob in Dataverse
├─ Trigger Flow 2 (call AI Builder)
```

**Flow 2: AI Builder Extraction + Contact Matching**
```
Trigger: Called from Flow 1
├─ Call AI Builder model via REST API or connector
├─ Parse response (extracted fields + confidence scores for all 20+ form fields)
├─ **NEW: Contact Matching Logic**
│  ├─ IF ClaimantSSN confidence ≥90% THEN
│  │  └─ Query Contacts table WHERE ssn_hashed = hash(ClaimantSSN)
│  │  └─ Store matched ClaimantContactID
│  ├─ ELSE IF ClaimantFullName + DOB confidence ≥90% THEN
│  │  └─ Query Contacts table WHERE name FUZZY_MATCH + dob = exact
│  │  └─ Store matched ClaimantContactID
│  └─ Log contact match attempt to AuditLog (success or no-match)
├─ Create ExtractionResult record in Dataverse
│  ├─ Store all extracted fields + confidence scores
│  ├─ Store ClaimantContactID + VeteranContactID (if matched)
│  └─ Store ContactMatchConfidence
├─ Decision: IF OverallConfidenceScore ≥90% AND CriticalFieldsOnly_Confidence ≥95%
│  └─ Set FormSubmission.Status = "Auto-Approved"
│  └─ Trigger Flow 4 (D365 Write)
└─ ELSE
   └─ Set FormSubmission.Status = "ReviewRequired"
   └─ Notify user (email or Power Apps notification)
```

**Flow 3: Approval Workflow** (triggered by Power Apps)
```
Trigger: Power Apps button "Approve" clicked
├─ Read CorrectionRecord from Dataverse
├─ Update ExtractionResult with corrected values
├─ Set ApprovalStatus = "Approved"
├─ Trigger Flow 4 (D365 Write)
```

**Flow 4: D365 Write**
```
Trigger: Called from Flow 2 (auto-approved) or Flow 3 (manual approval)
├─ Read ExtractionResult from Dataverse
├─ Call D365 connector to create record in VA_FormSubmission table
├─ IF success: 
│  └─ Set FormSubmission.Status = "Complete"
│  └─ Log success to AuditLog
└─ IF error:
   └─ Set FormSubmission.Status = "Failed"
   └─ Log error to AuditLog
   └─ Send alert email to supervisor
```

### Power Apps Canvas App (Optional)

**Purpose**: Let VA staff correct extracted fields before D365 write

**Screens**:
1. **Home** — List of forms with Status = "ReviewRequired"
2. **Correction Form** — Editable fields (BeneficiaryName, SSN, TravelDates, etc.) with validation
3. **Confirmation** — Summary of changes before approval

**Validation Logic**:
- SSN: Format check (###-##-####)
- Dates: Must be valid dates, TravelToDate ≥ TravelFromDate
- Name: Required, max 100 chars
- Destination: Required

---

## Project Structure

### Documentation

```
specs/001-form-extraction-pipeline/
├── spec.md                          # Feature specification (v1.0.1-Ready)
├── plan.md                          # Implementation plan (v1.0.1, Power Platform)
├── research.md                      # Phase 0 research (AI Builder, Dataverse, flows)
├── data-model.md                    # Dataverse entity schema
├── quickstart.md                    # Power Platform setup guide (SharePoint + AI Builder + flows)
├── contracts/
│   └── dataverse-schema.json        # Entity definitions + relationships
└── checklists/
    └── requirements.md              # Quality validation
```

### Power Platform Artifacts (No Code Repository)

```
Power Platform Environment:
├── AI Builder
│   └── VA-Form-10-3542-Model       # Custom extraction model (trained on 5 forms)
├── Dataverse
│   ├── FormSubmission table
│   ├── ExtractionResult table
│   ├── CorrectionRecord table
│   └── AuditLog table
├── Power Automate
│   ├── Intake-Trigger flow
│   ├── AI-Builder-Extraction flow
│   ├── Approval-Workflow flow
│   └── D365-Write flow
├── Power Apps
│   └── Correction-Form canvas app
├── Power BI
│   └── Extraction-Dashboard
└── Dynamics 365
    └── VA_FormSubmission table (destination)
```

---

## Complexity Tracking

No violations. Power Platform is deliberately simple:
- Zero custom code = reduced complexity
- Configuration-driven automation = easy to audit + modify
- Built-in error handling in Power Automate
- Dataverse audit trail sufficient for demo

---

## Summary: Power Platform Demo Ready

**Updated for Full VA Form 10-3542 Scope**:
- ✅ **20+ form fields** extracted (not just 7 key fields): Traveler info, trip details, expenses, facility, certifications
- ✅ **Contact matching** integrated: Automatic lookup of claimant/veteran in Dataverse Contacts table
- ✅ **Confidence scoring** per field: Route high-confidence to auto-approval; low-confidence to human review
- ✅ **Audit compliance**: All contact match attempts logged to AuditLog

**Next Steps**:

1. ✅ **Phase 0**: Research AI Builder accuracy on 5 forms, Dataverse schema finalization, contact matching strategy → produce `research.md`
2. ✅ **Phase 1**: Finalize data model (complete), design flows (complete), write quickstart → produce `data-model.md`, `quickstart.md`
3. ⏭️ **Phase 2**: Generate `tasks.md` with Power Platform setup steps (via `/speckit.tasks`)
4. ⏭️ **Phase 3**: Execute tasks in sequence (single person, 2–3 days)

---

**Version**: 1.0.1-PowerPlatform | **Created**: 2026-04-24 | **Status**: Ready for Phase 0 Research
