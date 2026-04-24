# Feature Specification: VA Form 10-3542 Extraction Pipeline

**Feature Branch**: `001-form-extraction-pipeline`  
**Created**: 2026-04-24  
**Status**: Draft  
**Input**: User description: "VA Form 10-3542 document processing: Extract field data from completed forms (handwritten or typed PDFs) using Microsoft AI Builder custom document model, then write extracted data into Dynamics 365 table structure for BTSSS program."

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - VA Staff Upload & Intake (Priority: P1)

VA administrative staff receives completed VA Form 10-3542 (beneficiary travel authorizations) and needs to submit them to the processing system. Staff may have a batch of 1–500 forms from a day's intake.

**Why this priority**: Without a working intake mechanism, no forms reach the extraction pipeline. This is the critical first step.

**Independent Test**: Can be tested by simulating form uploads → verifying files land in intake queue with correct metadata (date, file name, user ID) → confirming downstream extraction sees them.

**Acceptance Scenarios**:

1. **Given** a VA staff member has completed PDF forms (handwritten or typed), **When** they upload forms via SharePoint or email attachment, **Then** the system logs each form intake event with timestamp, user ID, and file hash (for audit).
2. **Given** a batch of 50 forms is uploaded, **When** intake processes them, **Then** all 50 forms enter the extraction queue within 30 seconds.
3. **Given** a malformed file (not PDF, corrupted), **When** intake validation runs, **Then** the file is rejected and logged; VA staff receives clear error message.
4. **Given** a duplicate form (same file hash uploaded twice), **When** intake detects it, **Then** the system logs a warning and rejects the duplicate.

---

### User Story 2 - AI-Powered Field Extraction (Priority: P1)

Once a form enters the system, the AI Builder custom document model extracts key fields from the form (beneficiary name, SSN, travel dates, destination, etc.) with confidence scores for each field.

**Why this priority**: This is the core value—automating manual data entry. Extraction must work reliably before human review or D365 write can be trusted.

**Independent Test**: Can be tested with ground-truth annotated forms → AI model extracts fields → output validated against expected values → confidence scores logged → model accuracy metrics computed.

**Acceptance Scenarios**:

1. **Given** a completed VA Form 10-3542 (PDF, handwritten or typed), **When** AI extraction runs, **Then** extracted fields include: Claimant Name, Claimant SSN, Claimant DOB, Claimant Status, Veteran Name/SSN/DOB (if different), Travel Dates (From/To), Travel Methods, Travel Address, Other Expenses, Treating Facility, Signature Date (see data-model.md for complete list).
2. **Given** extraction completes with confidence ≥95% (overall) AND ≥95% (critical fields), **When** contact matching completes, **Then** system stores matched Contact ID (if found) and queues form for auto-approval to D365 write (no human review).
3. **Given** extraction completes with confidence 80–94%, **When** extraction completes, **Then** form marked as "Review Required" and queued for human correction step; contact match result displayed to user.
4. **Given** confidence score is <80%, **When** extraction fails, **Then** entire form sent to manual review queue; human corrects all fields before D365 write.
5. **Given** AI extraction cannot process a form (OCR-only fallback), **When** AI model fails, **Then** form logged for manual intake; alert sent to supervisor.
6. **Given** contact matching finds no match, **When** extraction completes, **Then** Contact ID left null; form may still auto-approve (if confidence high enough); flag in dashboard for duplicate contact review (Phase 2).

---

### User Story 3 - Human Correction & Review (Priority: P2)

Fields requiring review are presented to VA staff in a simple web UI. Staff reviews AI-extracted values, corrects any errors, and approves submission to D365.

**Why this priority**: Ensures data accuracy before permanent D365 write; builds confidence in the pipeline.

**Independent Test**: Can be tested by presenting pre-populated correction forms → staff edits fields → validation rules applied → submission logged → tracked for analytics.

**Acceptance Scenarios**:

1. **Given** a form with "Review Required" fields, **When** VA staff opens the correction UI, **Then** extracted values are pre-filled and editable; staff sees confidence scores alongside each field.
2. **Given** staff corrects a field (e.g., beneficiary name), **When** they submit, **Then** the correction is logged with timestamp, user ID, old value, new value.
3. **Given** required field is empty or invalid (e.g., invalid SSN format), **When** staff tries to submit, **Then** field validation fails; clear error message prompts staff to correct it.
4. **Given** staff completes correction, **When** they click "Approve", **Then** form transitions to "Ready for D365 Write"; approval event logged.

---

### User Story 4 - D365 Table Write & Audit (Priority: P1)

Approved form data is written to a Dynamics 365 table. All write events are logged with timestamp, user, extracted fields, and validation status for compliance audit.

**Why this priority**: Data must reach D365 reliably; audit trail is non-negotiable for VA compliance.

**Independent Test**: Can be tested by writing test data to D365 table → querying table for expected records → verifying audit log entries → confirming data matches extracted values.

**Acceptance Scenarios**:

1. **Given** a form approved for D365 write, **When** the write process executes, **Then** all extracted fields (Beneficiary Name, SSN, Travel Dates, Destination, etc.) are written to the VA_FormSubmission D365 table.
2. **Given** D365 write completes, **When** the operation succeeds, **Then** form status marked "Complete"; audit log entry created with write timestamp, user, and record ID.
3. **Given** D365 write fails (network timeout, duplicate key, etc.), **When** error occurs, **Then** form transitions to "Write Failed" status; error details logged; alert sent to supervisor; form queued for retry.
4. **Given** a retry attempt after a previous failure, **When** retry succeeds, **Then** audit log entry notes retry attempt with original failure timestamp and new success timestamp.

---

### User Story 5 - Extraction Analytics & Model Improvement (Priority: P3)

System captures extraction metrics (accuracy by field, confidence score distribution, rejection rates) and stores failed extractions in an archive. This data feeds model retraining.

**Why this priority**: Long-term system health. Analytics enable continuous model improvement; captures edge cases for retraining.

**Independent Test**: Can be tested by running extraction on 100+ forms → computing accuracy metrics → querying archive → verifying retraining dataset populated.

**Acceptance Scenarios**:

1. **Given** extraction pipeline processes 100 forms, **When** completion runs, **Then** daily dashboard shows: total forms processed, auto-approved %, review-required %, rejection %, average confidence scores by field.
2. **Given** extraction fails on a form, **When** failure logged, **Then** form image + extracted data (if partial) stored in immutable archive for retraining analysis.
3. **Given** retraining trigger (monthly or on-demand), **When** archive is queried, **Then** retraining dataset includes: failed extractions, low-confidence fields, edge case forms.

---

### Edge Cases

- What happens when a form is received in a non-PDF format (Word doc, image)?
- How does the system handle forms submitted for the same beneficiary multiple times in one day (valid for multiple trips)?
- What if the D365 table connection drops mid-write? (partial data in D365)
- Can the AI model handle heavily redacted or watermarked forms?
- What is the maximum file size accepted (PDF size limit)?

---

## Requirements *(mandatory)*

### Functional Requirements

**FR-1: Form Intake & Validation**
- System must accept PDF files (handwritten or typed) from SharePoint upload or email attachment
- All intake events logged with file hash, user ID, timestamp
- Duplicate detection: reject files with matching hash (same file uploaded twice)
- Malformed files rejected with clear error message to user
- Batch intake supported (≥500 forms per submission)

**FR-2: AI-Powered Field Extraction**
- AI Builder custom document model extracts all VA Form 10-3542 fields:
  - **Section A (Traveler Information)**: Claimant Name, Claimant SSN, Claimant DOB, Claimant Status (Veteran/Caregiver/Attendant/Donor/Other), Veteran Name (if different), Veteran SSN (if different), Veteran DOB (if different)
  - **Section B (Trip Information)**: Travel From Address, Travel Begin Date, Travel Method Outbound, Return to Same Address (Y/N), Travel End Date, Travel Method Return, Other Expenses Claimed (Y/N), Expense Descriptions & Amounts (up to 4 lines), Treating Facility Name, Treating Facility Address
  - **Section C (Certifications)**: Signature Date
- Each extracted field includes confidence score (0–100%)
- **Contact Matching** (NEW): System attempts to match Claimant and Veteran to existing Dataverse Contacts table:
  - If SSN confidence ≥90%: Query Contacts by SSN hash
  - Else if Name + DOB confidence ≥90%: Query Contacts by name + DOB
  - Store matched Contact ID and match confidence score
- Confidence ≥95% (overall) AND ≥95% (critical fields: Name, SSN, DOB, Dates, Facility): Auto-approved
- Confidence 80–94%: Sent to human review
- Confidence <80%: Entire form sent to manual intake
- OCR-only fallback available if AI model cannot process

**FR-3: Human Correction UI**
- Web form presents extracted fields with confidence scores
- Fields editable by VA staff
- Validation rules enforced (e.g., SSN format, date ranges)
- All corrections logged with user, timestamp, before/after values
- "Approve" button transitions form to "Ready for D365 Write"

**FR-4: D365 Table Write**
- Approved form data written to VA_FormSubmission D365 table
- Write includes all extracted fields + metadata (intake timestamp, extraction confidence, extraction user, correction user)
- D365 write failures trigger retry queue (max 3 retries over 24 hours)
- On success, form marked "Complete"; on final failure, form marked "Write Failed" and alert sent to supervisor

**FR-5: Audit & Compliance Logging**
- Every operation (intake, extraction, correction, D365 write) logged with: timestamp, user ID, action type, field values (if data operation), success/failure status
- Audit log immutable and queryable via Azure Monitor KQL
- Failed extractions archived for model retraining (retained 2 years)
- Completed forms retained in audit log 7 years per VA policy

**FR-6: Analytics & Reporting**
- Daily dashboard: forms processed, auto-approved %, review-required %, rejection %, avg confidence by field
- Monthly retraining dataset compiled from failed extractions and low-confidence forms
- SLA tracking: extraction time, D365 write latency, human review resolution time

---

## Success Criteria *(mandatory)*

**Quantitative Metrics**:

1. **Extraction Accuracy**: AI model achieves ≥90% accuracy on ground-truth test set (50+ annotated forms per field type)
2. **Throughput**: System processes ≥100 forms/hour in batch mode (500+ form batch ingestion)
3. **Latency**: 
   - Single form extraction completes within 5 seconds
   - D365 write completes within 2 seconds
   - Form intake to completion (auto-approved path) ≤10 seconds end-to-end
4. **Human Review SLA**: Forms in "Review Required" state resolved within 4 business hours
5. **Error Handling**: Failed D365 writes recover on retry with ≥95% success rate after 3 attempts
6. **Audit Coverage**: 100% of operations logged; zero audit gaps in compliance audit

**Qualitative Metrics**:

1. **User Experience**: VA staff successfully uses correction UI without help; confidence scores clearly communicate extraction reliability
2. **Data Integrity**: Extracted data matches original form intent; no silent data corruption
3. **System Reliability**: No unplanned downtime during business hours; graceful degradation when AI model unavailable (fallback to manual intake)

**Compliance & Safety**:

1. **PII Protection**: All SSN/beneficiary data encrypted at rest (AES-256) and in transit (TLS 1.3)
2. **Audit Trail Immutability**: Audit log tamper-proof; every write event includes cryptographic hash
3. **Retention Compliance**: 7-year retention for completed forms; 2-year retention for failed extractions

---

## Entities & Data Model *(mandatory)*

### Primary Entities

**FormSubmission**
- FormID (UUID)
- UploadedBy (UserID)
- UploadTimestamp (DateTime)
- FileName (string)
- FileHash (SHA256)
- Status (Enum: Intake, Extracting, ReviewRequired, ReadyForD365, D365Writing, Complete, WriteFailed, ManualIntake)

**ExtractionResult**
- ExtractionID (UUID)
- FormID (FK to FormSubmission)
- ExtractedFields (JSON: {FieldName: {Value, ConfidenceScore, IsAutoApproved}})
- ExtractionTimestamp (DateTime)
- ExtractionModel (string, e.g., "AIBuilder-v2.1")

**CorrectionRecord**
- CorrectionID (UUID)
- ExtractionID (FK to ExtractionResult)
- CorrectedBy (UserID)
- CorrectionTimestamp (DateTime)
- ChangesLog (JSON: {FieldName: {OldValue, NewValue}})
- ApprovalStatus (Enum: Pending, Approved, Rejected)

**D365WriteEvent**
- WriteEventID (UUID)
- FormID (FK to FormSubmission)
- D365TableRecord (D365 table key)
- WrittenBy (UserID)
- WriteTimestamp (DateTime)
- WriteStatus (Enum: Success, Failed, Retry)

**AuditLog**
- AuditID (UUID)
- Timestamp (DateTime)
- UserID (string)
- ActionType (string, e.g., "FormIntake", "Extraction", "Correction", "D365Write")
- TargetEntity (FormID or ExtractionID)
- OperationDetails (JSON)
- Status (string, e.g., "Success", "Failure")
- ImmutableHash (SHA256)

---

## Clarifications

### Session 2026-04-24

- Q1: AI Model Training Data → A: Using existing VA Form 10-3542 dataset (official form: https://www.va.gov/vaforms/medical/pdf/VA%20Form%2010-3542.pdf); annotation team will source completed examples from BTSSS
- Q2: Multiple Forms Per Beneficiary → A: Both forms valid and independent; each gets own D365 record; no same-day conflict; duplicate detection remains hash-based

---

## Assumptions *(mandatory)*

1. **D365 Environment**: Assumed on Azure Commercial (not Government); if Gov, encryption and network isolation requirements escalate
2. **Form Schema**: VA Form 10-3542 field structure is stable (official template available); significant schema changes will require AI model retraining
3. **Data Ownership**: D365 is the system-of-record; all form data reconciles against D365 after write
4. **Compliance Baseline**: HIPAA applies (beneficiary SSN + travel info is sensitive); FedRAMP not required unless D365 environment is in Government
5. **Intake Mechanism**: Forms arrive via SharePoint or email; batch processing via API not in scope for Phase 1
6. **Human Review SLA**: 4 business hours is feasible given VA staff availability; if staffing changes, SLA may require adjustment
7. **AI Model Training**: Using official VA Form 10-3542 template; training dataset to be sourced from BTSSS completed forms; no pre-existing annotated dataset assumed
8. **Multi-Form Per Beneficiary**: Same beneficiary can submit multiple forms same day (valid for multiple trips); each form independent, no conflict detection required; D365 allows multiple records per beneficiary SSN
9. **Scale**: Initial scale ≤1,000 forms/day; if BTSSS volume exceeds this, caching/performance tuning required
10. **Accessibility (Phase 2)**: WCAG AA compliance deferred to Phase 2; demo focuses on extraction accuracy and D365 write

---

## Quality Checklist

- [ ] All user stories independently testable
- [ ] Functional requirements testable without implementation details
- [ ] Success criteria measurable and technology-agnostic
- [ ] Edge cases identified and addressed
- [ ] No [NEEDS CLARIFICATION] markers remain
- [ ] Data entities documented with clear ownership
- [ ] Compliance requirements explicit (PII, audit, retention)
- [ ] Assumptions documented for stakeholder review

---

**Version**: 1.0.1-Ready | **Created**: 2026-04-24 | **Clarified**: 2026-04-24 | **Status**: Ready for Planning
