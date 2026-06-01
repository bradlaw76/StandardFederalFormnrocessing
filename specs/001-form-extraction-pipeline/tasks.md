# Tasks: VA Form 10-3542 Extraction Pipeline

**Input**: Design documents from `/specs/001-form-extraction-pipeline/`  
**Prerequisites**: plan.md (v1.0.1-PowerPlatform), spec.md (v1.0.1-Ready), data-model.md, research.md  
**Platform**: Microsoft Power Platform (low-code/no-code)  
**Scope**: Demo implementation (5 VA forms), expandable to production  
**Status**: Generated 2026-04-24  

---

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files/components, no blocking dependencies)
- **[Story]**: Which user story (US1–US5); omitted for Setup/Foundational/Polish phases
- **Paths**: Power Automate flows, Dataverse tables, Power Apps apps, Power BI dashboards

---

## Phase 1: Setup (Shared Infrastructure & Environment)

**Purpose**: Power Platform environment initialization and shared infrastructure

**Duration**: ~2–3 hours  
**Owner**: Platform Admin / Solution Architect

- [ ] T001 Create or verify Power Platform environment for VA Forms project (tenant admin access required)
- [ ] T002 [P] Create SharePoint site for form intake (e.g., `/sites/VAFormProcessing/Forms`)
- [ ] T003 [P] Create SharePoint document library `FormIntake` for receiving uploaded PDFs
- [ ] T004 [P] Configure Dynamics 365 connection in Power Platform (set up D365 environment and connector)
- [ ] T005 [P] Verify Power Automate cloud flow limits and connectors enabled (AI Builder, Dataverse, D365, SharePoint, Outlook)
- [ ] T006 Create Power Platform solution container `VA-Form-Extraction` in Dataverse (will hold all flows, tables, apps)
- [ ] T007 [P] Verify AI Builder capacity and trial/license status in Power Platform environment
- [ ] T008 [P] Set up Entra ID / Microsoft Entra ID for VA staff authentication (delegated admin setup, if applicable)

**Checkpoint**: Environment ready; all services accessible; solutions created

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core Dataverse schema, AI Builder model, and infrastructure that ALL user stories depend on

**Duration**: ~6–8 hours  
**⚠️ CRITICAL**: No user story work can begin until this phase completes

### Dataverse Table Setup (Core Data Model)

- [ ] T009 Create Dataverse table `FormSubmission` with schema per data-model.md (FormID, FileHash, UploadedBy, UploadTimestamp, FileName, Status, Metadata columns)
- [ ] T010 [P] Create Dataverse table `ExtractionResult` (ExtractionID, FormID lookup, ModelVersion, ExtractionTimestamp, ExtractedFields—traveler info section, trip info section, confidence scores per field, OverallConfidenceScore)
- [ ] T011 [P] Create Dataverse table `CorrectionRecord` (CorrectionID, ExtractionID lookup, CorrectedBy, CorrectionTimestamp, ChangesLog JSON, ApprovalStatus, ApprovalTimestamp)
- [ ] T012 [P] Create Dataverse table `AuditLog` (AuditID, Timestamp, UserID, ActionType, TargetEntity, OperationDetails, Status, ImmutableHash, SystemID)
- [ ] T013 [P] Create Dataverse table `D365WriteEvent` (WriteEventID, FormID lookup, D365RecordID, WrittenBy, WriteTimestamp, WriteStatus, ErrorDetails, RetryCount)
- [ ] T014 Configure Dataverse table relationships: FormSubmission → ExtractionResult (1:many), ExtractionResult → CorrectionRecord (1:0..1), FormSubmission → AuditLog (1:many), FormSubmission → D365WriteEvent (1:1)
- [ ] T015 [P] Enable auditing on all tables (FormSubmission, ExtractionResult, CorrectionRecord, D365WriteEvent for compliance)
- [ ] T016 [P] Set up column-level encryption for PII columns (ClaimantSSN, VeteranSSN in ExtractionResult; mark as sensitive data)

### AI Builder Model Training

- [ ] T017 Collect or prepare 5 VA Form 10-3542 PDFs (mix of handwritten and typed forms per research.md guidance)
- [ ] T018 Create AI Builder "Form Processing" model in Power Automate: https://powerautomate.microsoft.com → AI Builder → Document Processing
- [ ] T019 Upload 5 forms into AI Builder training dataset
- [ ] T020 Manually annotate all key fields on each form in AI Builder UI (Claimant Name, SSN, DOB, Claimant Status, Veteran Info, Travel Dates, Methods, Address, Expenses, Treating Facility, Signature Date—per data-model.md section A, B, C)
- [ ] T021 Train AI Builder model (automatic after annotation; ~5 min training time)
- [ ] T022 Test AI Builder model on all 5 forms; document baseline accuracy (expected ~70% for 5-form dataset per research.md)
- [ ] T023 Publish AI Builder model to Dataverse (make available for use in Power Automate flows)
- [ ] T024 Document model version (e.g., "AIBuilder-v1-Demo-5forms") and store in Dataverse metadata

### Power Automate Flow Foundation & Shared Actions

- [ ] T025 [P] Create Power Automate shared flow (reusable action) `Log-Audit-Event` to write entries to AuditLog table with timestamp, UserID, ActionType, OperationDetails, Status
- [ ] T026 [P] Create Power Automate shared flow `Update-FormStatus` to transition FormSubmission status (handles state machine: Intake → Extracting → ReviewRequired/ReadyForD365 → D365Writing → Complete/WriteFailed)
- [ ] T027 Create error handling & retry logic template (Power Automate exponential backoff retry policy: 3 attempts, 60–300s delay)

### Contact Matching Setup

- [ ] T028 Document contact matching algorithm (primary: SSN match at ≥95% confidence; secondary: name + DOB at ≥85%; tertiary: name only at 60–75%, flag for review per data-model.md section 3)
- [ ] T029 Prepare contact matching reference data: Export Dataverse Contacts table (FirstName, LastName, ssn_encrypted, birthdate columns) for use in flow condition logic

**Checkpoint**: Dataverse schema complete; AI Builder model trained & published; shared flows created; foundation ready for user story implementation

---

## Phase 3: User Story 1 - VA Staff Upload & Intake (Priority: P1) 🎯 MVP

**Goal**: VA staff can upload completed VA Form 10-3542 PDFs to SharePoint; system logs intake event, validates file, and queues for extraction.

**Independent Test**: 
1. Upload 5 PDFs to SharePoint FormIntake library
2. Verify FormSubmission records created with correct metadata (FileHash, UploadedBy, UploadTimestamp, Status=Intake)
3. Confirm audit log entries written
4. Test duplicate detection (re-upload same file; confirm rejection)
5. Test malformed file handling (non-PDF; confirm error message to user)

### Implementation for User Story 1

- [ ] T030 Create Power Automate cloud flow `Intake-Form-Upload-Trigger` (triggered by SharePoint file creation event)
- [ ] T031 [US1] Implement file validation logic in Intake flow: Check file type is PDF; check file size <50MB; reject if invalid (log error to AuditLog, notify user via email)
- [ ] T032 [US1] Implement duplicate detection in Intake flow: Compute SHA256 file hash; query FormSubmission table for matching FileHash; if found, reject with "Duplicate" status + log audit event
- [ ] T033 [US1] Implement FormSubmission record creation in Intake flow: Create record with (FormID=GUID, FileHash, UploadedBy=current user, UploadTimestamp=now, FileName, Status=Intake, Metadata={SourceSystem: "SharePoint", BatchID: null})
- [ ] T034 [US1] Store PDF file in Dataverse (blob column or reference to SharePoint); implement file retrieval logic for downstream extraction flow
- [ ] T035 [US1] Call shared flow `Log-Audit-Event` to write FormIntake audit entry (ActionType="FormIntake", TargetEntity=FormID, Status="Success", OperationDetails includes FileName, FileHash)
- [ ] T036 [US1] Implement error handling in Intake flow (timeout, network error, quota exceeded → log to AuditLog, send alert email to supervisor)
- [ ] T037 [US1] Test Intake flow end-to-end: Upload PDF → Verify FormSubmission created → Verify audit logged; test error cases (malformed file, duplicate, oversized file)

**Checkpoint**: User Story 1 complete; intake mechanism working; forms queue for extraction

---

## Phase 4: User Story 2 - AI-Powered Field Extraction (Priority: P1)

**Goal**: AI Builder extracts key fields from form with confidence scores; high-confidence results auto-approve; lower-confidence results queue for manual review.

**Independent Test**:
1. Run Intake flow to create FormSubmission
2. Manually trigger Extraction flow with test FormSubmission ID
3. Verify ExtractionResult created with extracted fields + confidence scores
4. Verify contact matching completed (Contact ID stored if match found)
5. Test routing: Extract with ≥95% confidence → Status="ReadyForD365"; <95% → Status="ReviewRequired"
6. Run 5 test forms; log accuracy metrics

### Implementation for User Story 2

- [ ] T038 Create Power Automate cloud flow `Extraction-AI-Builder-Process` (called from Intake flow after successful file validation)
- [ ] T039 [US2] Retrieve FormSubmission & PDF file from Dataverse; pass PDF to AI Builder model API
- [ ] T040 [US2] Call AI Builder model with PDF; parse response (extracted fields, confidence scores per field, overall confidence)
- [ ] T041 [US2] Create ExtractionResult record in Dataverse: Store all extracted fields (Claimant Name, SSN, DOB, Status, Veteran Name/SSN/DOB, Travel Dates/Methods/Address, Expenses, Treating Facility, Signature Date per data-model.md), confidence scores for each field, ModelVersion, OverallConfidenceScore=average of all field confidences, CriticalFieldsOnly_Confidence=average of SSN, Name, DOB, Travel Dates, Facility
- [ ] T042 [US2] Call shared flow `Log-Audit-Event` to write Extraction audit entry (ActionType="Extraction", TargetEntity=ExtractionID, Status="Complete", OperationDetails includes ModelVersion, OverallConfidenceScore)
- [ ] T043 [US2] Implement contact matching logic: Query Dataverse Contacts table using algorithm from data-model.md section 3 (SSN match ≥95%, name+DOB ≥85%, name only 60–75%); store matched ContactID in ExtractionResult; if no match, leave ContactID null, log warning to AuditLog
- [ ] T044 [US2] Implement confidence-based routing decision:
  - IF OverallConfidenceScore ≥95% AND CriticalFieldsOnly_Confidence ≥95% → call shared flow `Update-FormStatus` with Status="ReadyForD365"; flag for auto-approval path (skip manual review)
  - ELSE IF OverallConfidenceScore 80–94% → Status="ReviewRequired"; queue for manual review (Power Apps correction UI)
  - ELSE (< 80%) → Status="ManualIntake"; flag entire form for manual extraction; send alert to supervisor
- [ ] T045 [US2] Implement error handling: If AI Builder timeout (>30s), log to AuditLog, mark form as "ExtractionFailed", alert supervisor
- [ ] T046 [US2] Test Extraction flow: Run on 5 test forms (mix high/low confidence); verify ExtractionResult records created; verify confidence scores recorded; verify contact matches logged; verify status routing (auto-approved vs. review-required vs. manual)

**Checkpoint**: User Story 2 complete; extraction working; confidence-based routing in place; ready for human review or auto-approval

---

## Phase 5: User Story 4 - D365 Table Write & Audit (Priority: P1)

**Goal**: Approved form data written to Dynamics 365 VA_FormSubmission table with immutable audit trail.

**Independent Test**:
1. Create test ExtractionResult with Status="ReadyForD365"
2. Trigger D365 Write flow manually
3. Verify D365 table receives record (all extracted fields written)
4. Verify D365WriteEvent record created (WriteEventID, D365RecordID, WriteStatus="Success", WriteTimestamp)
5. Verify audit log entry written
6. Test error handling: Simulate D365 connection failure → verify retry logic, error logged, supervisor alert

### Implementation for User Story 4

- [ ] T047 Configure D365 connector in Power Automate (Dynamics 365 connection, set up OAuth2 authentication with VA Entra ID)
- [ ] T048 Map Dataverse ExtractionResult columns to Dynamics 365 VA_FormSubmission table schema (BeneficiaryName → Beneficiary_Name_D365, SSN → SSN_D365, TravelFromDate → Travel_From_Date_D365, etc.; ensure data type compatibility)
- [ ] T049 Create Power Automate cloud flow `D365-Write-Approved-Form` (called after form approval; triggered by FormSubmission Status change to "ReadyForD365" OR manual approval from Power Apps correction UI)
- [ ] T050 [US4] Read FormSubmission & ExtractionResult from Dataverse (retrieve all extracted field values)
- [ ] T051 [US4] Create D365WriteEvent record in Dataverse (WriteEventID=GUID, FormID, WrittenBy=current user, WriteTimestamp=now, WriteStatus=pending, RetryCount=0)
- [ ] T052 [US4] Implement write operation to D365 via D365 connector: Create VA_FormSubmission record with extracted field values; handle response (success vs. error)
- [ ] T053 [US4] IF D365 write succeeds → Update D365WriteEvent (WriteStatus="Success", D365RecordID=returned record ID, WriteTimestamp); update FormSubmission status to "Complete"; call shared flow `Log-Audit-Event` (ActionType="D365Write", Status="Success")
- [ ] T054 [US4] IF D365 write fails → Update D365WriteEvent (WriteStatus="Failed", ErrorDetails=error message, RetryCount++); IF RetryCount < 3, schedule retry (Power Automate retry policy: exponential backoff 60–300s); ELSE mark form as "WriteFailed", alert supervisor; call shared flow `Log-Audit-Event` (ActionType="D365WriteFailed", Status="Failure", ErrorDetails)
- [ ] T055 [US4] Implement retry flow for failed D365 writes: Read D365WriteEvent with WriteStatus="Failed" AND RetryCount < 3; re-attempt D365 write; log retry attempt to AuditLog with original failure timestamp
- [ ] T056 [US4] Test D365 Write flow: Create test extraction → trigger write flow → verify D365 record created with correct field values; verify D365WriteEvent logged; verify audit trail entry written; verify status transitioned to "Complete"
- [ ] T057 [US4] Test error handling: Simulate D365 connection failure (disable connector, invalid credentials) → verify error logged, retry attempted, supervisor alert sent

**Checkpoint**: User Story 4 complete; D365 integration working; audit trail in place; ready for production write

---

## Phase 6: User Story 3 - Human Correction & Review (Priority: P2)

**Goal**: VA staff reviews AI-extracted fields in Power Apps UI, corrects errors, approves submission to D365.

**Independent Test**:
1. Create ExtractionResult with Status="ReviewRequired"
2. Open Power Apps correction form; verify fields pre-filled with AI values + confidence scores
3. Edit a field (e.g., beneficiary name) → verify old/new values logged
4. Submit form → verify CorrectionRecord created, status updated to "ReadyForD365"
5. Test validation: Try empty required field → confirm error message
6. Verify approved form triggers D365 Write flow

### Implementation for User Story 3

- [ ] T058 Create Power Apps canvas app `Form-Correction-UI` (screens: Home/List, Correction Form, Confirmation)
- [ ] T059 [US3] Implement Home screen: Gallery showing all FormSubmission records with Status="ReviewRequired" (display: FormID, FileName, UploadTimestamp, AI OverallConfidenceScore); "Review Form" button to navigate to correction screen
- [ ] T060 [US3] Implement Correction Form screen: 
  - Text inputs for each extracted field (BeneficiaryName, SSN, DOB, Claimant Status, Veteran Name/SSN/DOB, Travel From/To Dates, Travel Methods, Address, Expenses, Treating Facility, Signature Date per data-model.md)
  - Pre-fill all fields from ExtractionResult
  - Display AI confidence score label for each field (e.g., "AI Confidence: 92%")
  - Editable for staff correction
- [ ] T061 [US3] Implement validation rules in Correction Form: SSN format (999-99-9999), Date format (MM/DD/YYYY), required fields cannot be empty (Beneficiary Name, Travel Dates, Destination), email format for facility contact (if applicable)
- [ ] T062 [US3] Implement form submission handler: "Approve" button → validate all fields → IF valid:
  - Create CorrectionRecord (CorrectionID, ExtractionID, CorrectedBy=current user, CorrectionTimestamp=now, ChangesLog={for each edited field: OldValue, NewValue}, ApprovalStatus="Approved", ApprovalTimestamp=now)
  - Call shared flow `Update-FormStatus` with Status="ReadyForD365"
  - Call shared flow `Log-Audit-Event` (ActionType="Correction", TargetEntity=CorrectionID, Status="Success", OperationDetails includes ChangesLog)
  - Navigate to Confirmation screen
- [ ] T063 [US3] Implement "Reject" button: Set CorrectionRecord.ApprovalStatus="Rejected"; prompt for rejection reason; log to AuditLog; return to Home screen
- [ ] T064 [US3] Implement "Back" button: Return to Home screen without saving changes
- [ ] T065 [US3] Implement Confirmation screen: Display summary (FormID, approval status, timestamp, number of fields corrected); "Done" button to return to Home
- [ ] T066 [US3] Add error handling in Power Apps: Display error messages for validation failures, connection timeouts; log to AuditLog
- [ ] T067 [US3] Test Power Apps flow end-to-end: 
  - Create ExtractionResult with Status="ReviewRequired"
  - Open correction UI → verify fields pre-filled
  - Edit 2–3 fields
  - Click "Approve" → verify validation passes → verify CorrectionRecord created
  - Verify form status updated to "ReadyForD365"
  - Verify Audit entries logged

**Checkpoint**: User Story 3 complete; correction UI working; staff can review & approve forms

---

## Phase 7: User Story 5 - Extraction Analytics & Model Improvement (Priority: P3)

**Goal**: Capture extraction metrics (accuracy by field, confidence distribution, rejection rates) and archive failed extractions for model retraining.

**Independent Test**:
1. Process 10+ test forms through extraction pipeline
2. Query Dataverse for extraction metrics (auto-approved %, review-required %, rejection %)
3. Compute average confidence scores by field
4. Create Power BI dashboard; verify charts display correctly
5. Archive failed extractions; verify retraining dataset populated

### Implementation for User Story 5

- [ ] T068 Create Dataverse table `ExtractionMetrics` (MetricID, Date, TotalFormsProcessed, AutoApprovedCount, ReviewRequiredCount, ManualIntakeCount, AverageConfidenceScore, ConfidenceByField JSON, RejectionRate, ModelVersion)
- [ ] T069 [P] [US5] Create Power Automate scheduled flow `Daily-Metrics-Aggregation` (runs daily at 6 AM UTC):
  - Query ExtractionResult for previous 24 hours
  - Compute: Total forms processed, count by status/confidence tier, average confidence overall and by field
  - Create ExtractionMetrics record with aggregated data
  - Log to AuditLog
- [ ] T070 [US5] Create Dataverse table `FailedExtractionArchive` (ArchiveID, FormID, ExtractionID, ExtractedFieldsSnapshot JSON, ReasonForFailure, ArchivedTimestamp, FormImageLink, RetainingsDataset boolean)
- [ ] T071 [US5] Create Power Automate scheduled flow `Archive-Failed-Extractions` (daily):
  - Query ExtractionResult for forms with confidence <70% (manual intake) or AI Builder timeout errors
  - Store form image + extracted data in FailedExtractionArchive
  - Mark RetainingDataset=true if confidence <70% (flag for retraining)
  - Log archive operation to AuditLog
- [ ] T072 [US5] Create Power BI report `Extraction-Pipeline-Dashboard`:
  - Chart 1: Daily forms processed (line chart, trend over 30 days)
  - Chart 2: Auto-Approved % vs. Review-Required % vs. Manual Intake % (stacked bar chart, daily)
  - Chart 3: Average confidence score by field (bar chart, sorted descending)
  - Chart 4: Confidence score distribution (histogram, 0–100 bins)
  - Chart 5: D365 write success rate % (line chart)
  - Chart 6: Form processing latency (extraction + review + D365 write, box plot)
  - Filters: Date range, Model version, Status
- [ ] T073 [US5] Connect Power BI report to Dataverse ExtractionResult, ExtractionMetrics, D365WriteEvent tables; configure refresh schedule (daily)
- [ ] T074 [US5] Document retraining dataset generation: Query FailedExtractionArchive with RetainingDataset=true; export to CSV for model retraining team
- [ ] T075 [US5] Test analytics flow end-to-end:
  - Process 20+ test forms (mix high/low confidence)
  - Run Daily-Metrics-Aggregation manually
  - Verify ExtractionMetrics created with correct counts
  - Verify failed forms archived
  - Verify Power BI dashboard displays all charts
  - Verify metrics are accurate

**Checkpoint**: User Story 5 complete; analytics pipeline operational; retraining dataset ready

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, end-to-end testing, performance optimization, and production readiness

**Duration**: ~4–6 hours

- [ ] T076 [P] Create quickstart guide in specs/001-form-extraction-pipeline/quickstart.md (setup steps for new developers, test scenarios, FAQ)
- [ ] T077 [P] Create operational runbook: Deployment checklist, configuration steps, troubleshooting guide, escalation contacts
- [ ] T078 [P] Documentation: Add comments/descriptions to all Power Automate flows and Power Apps screens
- [ ] T079 [P] Create solution deployment package (Solution export from Power Platform for version control)
- [ ] T080 [P] Add logging & telemetry: Ensure all flows log entry/exit + performance metrics (flow execution time, step duration)
- [ ] T081 Security hardening: Verify Dataverse table permissions (role-based access), connector authentication (OAuth2), PII encryption
- [ ] T082 Performance optimization: Verify AI Builder extraction latency <5s, D365 write latency <2s, end-to-end latency <5 min for full form intake→correction→write
- [ ] T083 End-to-end test: Run 5 forms through entire pipeline (intake → extraction → correction → D365 write); verify all data correct; verify audit log complete
- [ ] T084 Error recovery test: Simulate failures (AI Builder timeout, D365 unavailable, SharePoint connection lost, network timeout); verify retry logic, alerts, recovery
- [ ] T085 Load test: Run 20 concurrent form uploads; verify flow concurrency (aim for ≥5 forms/min per plan.md)
- [ ] T086 Compliance review: Verify audit trail immutability, PII handling, data retention, access controls meet VA requirements
- [ ] T087 Update constitution.md post-implementation: Reflect actual achieved performance, test coverage, observability implementation
- [ ] T088 Create GitHub commit with all Dataverse configurations, flow definitions, Power Apps source (exported), Power BI report definitions

**Checkpoint**: System production-ready; all user stories integrated; documentation complete

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup)
  ↓
Phase 2 (Foundational: Dataverse, AI Builder, Shared Flows)
  ↓
┌─────────────────────────────────────────────────────────────┐
│  Phase 3 (US1), Phase 4 (US2), Phase 5 (US4)              │
│  Can run in PARALLEL after Phase 2                        │
│  (Each depends only on Foundational, not on each other)   │
└─────────────────────────────────────────────────────────────┘
  ↓ (Require Phase 3 & Phase 4 complete)
Phase 6 (US3: Correction UI)
  ↓ (Optional, requires other phases)
Phase 7 (US5: Analytics)
  ↓
Phase 8 (Polish & Testing)
```

### User Story Dependencies

- **US1 (Intake, P1)**: Depends on Phase 2 ✅ Can start immediately after Foundational
- **US2 (Extraction, P1)**: Depends on Phase 2 ✅ Can start immediately after Foundational; runs in parallel with US1
- **US4 (D365 Write, P1)**: Depends on Phase 2 ✅ Can start immediately after Foundational; runs in parallel with US1 & US2
- **US3 (Correction, P2)**: Depends on Phase 2 + US1 + US2 ✅ Must wait for US1 & US2 to provide ExtractionResult data
- **US5 (Analytics, P3)**: Depends on Phase 2 + US1 + US2 + US4 ✅ Must wait for extraction/write pipeline operational

### Within Each User Story

1. Core implementation first (e.g., Intake flow, Extraction flow)
2. Error handling & validation second
3. Testing & verification third
4. Documentation fourth

### Parallel Opportunities

**Parallel within Phase 2**:
- T009–T012: All Dataverse tables can be created in parallel [P]
- T025–T026: Shared flows can be created in parallel [P]
- T004, T007, T008: Environment setup tasks can run in parallel [P]

**Parallel across User Stories (after Phase 2)**:
- US1 intake flow, US2 extraction flow, US4 D365 write flow can be built simultaneously by different team members
- US3 Power Apps form can be built while US1–US2 flows are being completed
- US5 analytics can be added after any user story completes (incremental)

**Parallel within User Story 1**:
- T030, T031 can be built together (file validation)
- T032, T033 can be built in parallel (duplicate detection & record creation)
- T034–T035 can be built in parallel (file storage & audit logging)

**Parallel within User Story 2**:
- T038–T041: AI Builder integration tasks built in sequence (dependencies: flow creation → AI call → response parsing)
- T043–T044: Contact matching & routing can be built in parallel

**Parallel within User Story 3**:
- T059–T061: Power Apps screens can be built in parallel [P]
- T062–T064: Button handlers can be built in parallel [P]

**Parallel within Phase 8 (Polish)**:
- T076–T080: Documentation, deployment, logging can all be built in parallel [P]

---

## Parallel Execution Example: Multi-Team Setup (After Phase 2)

```
Team A (US1 - Intake)          Team B (US2 - Extraction)      Team C (US4 - D365 Write)
├─ T030: Intake flow           ├─ T038: Extraction flow       ├─ T047: D365 connection
├─ T031: File validation       ├─ T039: Retrieve PDF          ├─ T048: Field mapping
├─ T032: Duplicate detection   ├─ T040: Call AI Builder       ├─ T049: D365 write flow
├─ T033: Record creation       ├─ T041: Parse response        ├─ T050: Read Dataverse
├─ T034: File storage          ├─ T042: Create ExtractionRslt ├─ T051: Create D365WriteEvent
├─ T035: Audit logging         ├─ T043: Contact matching      ├─ T052: Write to D365
├─ T036: Error handling        ├─ T044: Confidence routing    ├─ T053: Success handling
└─ T037: Testing              ├─ T045: AI error handling     ├─ T054: Error handling
                              └─ T046: Testing              ├─ T055: Retry flow
                                                            ├─ T056: Testing
                                                            └─ T057: Error testing

Phase Duration: ~12 hours total (parallel execution reduces serial path)

After all three complete:
Team D (US3 - Correction UI - depends on A, B)
Team E (US5 - Analytics - depends on A, B, C)
All: Phase 8 Polish & Integration
```

---

## Implementation Strategy: MVP-First, Incremental Delivery

### MVP Scope (Minimum Viable Product)

**Recommended MVP delivery: Complete User Stories 1, 2, 4 (Phase 1–5)**

- ✅ Forms intake working (US1)
- ✅ AI extraction operational (US2)
- ✅ D365 write functional (US4)
- ⏸️ Manual correction UI (US3) – defer to Phase 2 (but still deliver before cutover; high value)
- ⏸️ Analytics dashboard (US5) – defer to Phase 2 (monitor with basic queries initially)

**Estimated MVP timeline**: 3–5 days (1 developer working through all phases)

### Incremental Delivery Plan

| Delivery | Phases Included | Features | Timeline |
|----------|-----------------|----------|----------|
| **Delivery 1 (Alpha)** | 1, 2 | Dataverse schema, AI Builder model trained, shared flows | Day 1 |
| **Delivery 2 (Beta)** | 3 | Intake flow complete, files landing in queue | Day 2 |
| **Delivery 3 (Candidate)** | 4 | Extraction flow complete, confidence routing, contact matching | Day 2–3 |
| **Delivery 4 (RC1)** | 5 | D365 write flow complete, audit logging operational | Day 3 |
| **Delivery 5 (GA)** | 1–5 + Polish | Correction UI added, analytics dashboard, end-to-end testing | Day 4–5 |

### Success Criteria Per Delivery

| Delivery | Success Metric |
|----------|---|
| Delivery 1 | All Dataverse tables created & verified; AI Builder model published |
| Delivery 2 | 5 test PDFs successfully intake'd; FormSubmission records created; duplicate detection working |
| Delivery 3 | 5 test PDFs extracted; confidence scores logged; contact matches found; routing decision correct (auto-approve vs. review) |
| Delivery 4 | Approved forms written to D365; D365 records created with correct data; audit trail complete; retry logic tested |
| Delivery 5 | Correction UI functional; staff can edit & approve; analytics dashboard displaying real-time metrics; end-to-end pipeline tested |

---

## Testing Strategy

### Test Scenarios (All Mandatory)

#### Scenario 1: Happy Path (All Confidence ≥95%)
1. Upload 1 high-quality typed form to SharePoint
2. System intake → extract (confidence ≥95%) → auto-approve → D365 write → Complete
3. **Verify**: FormSubmission status progresses: Intake → Extracting → ReadyForD365 → D365Writing → Complete
4. **Verify**: Audit log entries: FormIntake, Extraction, D365Write (all Success)
5. **Verify**: D365 record created with correct data
6. **Verify**: No CorrectionRecord created (auto-approved)

#### Scenario 2: Human Review Path (Confidence 80–94%)
1. Upload 1 form with mixed quality (some handwritten, some typed)
2. System intake → extract (confidence 85%) → review-required
3. VA staff opens correction UI, reviews AI values, edits 1 field, approves
4. System routes to D365 write → Complete
5. **Verify**: FormSubmission status: Intake → Extracting → ReviewRequired
6. **Verify**: CorrectionRecord created with edit history (OldValue, NewValue, timestamp, user)
7. **Verify**: Audit log entries: FormIntake, Extraction, Correction, D365Write
8. **Verify**: D365 record written with *corrected* value (not AI value)

#### Scenario 3: Manual Intake Path (Confidence <70%)
1. Upload 1 poor-quality form (heavily handwritten, smudged)
2. System intake → extract (confidence 45%) → manual-intake
3. **Verify**: FormSubmission status: Intake → Extracting → ManualIntake
4. **Verify**: Alert email sent to supervisor
5. **Verify**: Audit log entry: Extraction, Status=PartialFailure, Reason logged
6. **Verify**: Form archived in FailedExtractionArchive for retraining

#### Scenario 4: Duplicate Detection
1. Upload same PDF twice to SharePoint
2. First upload → Intake succeeds → FormSubmission created
3. Second upload (same file hash) → Intake flow rejects as duplicate
4. **Verify**: Second FormSubmission NOT created
5. **Verify**: Audit log entry: FormIntake, Status=Duplicate, Warning logged
6. **Verify**: User notified via email (duplicate rejection)

#### Scenario 5: Malformed File
1. Upload non-PDF file (Word doc, image, corrupted PDF)
2. Intake flow validates file type → rejects
3. **Verify**: FormSubmission NOT created
4. **Verify**: Audit log entry: FormIntake, Status=ValidationFailed, Error logged
5. **Verify**: User notified via email (clear error: "File must be PDF; received .docx")

#### Scenario 6: D365 Write Failure & Retry
1. Create ExtractionResult with Status=ReadyForD365
2. Disable D365 connection (simulate failure)
3. Trigger D365 Write flow
4. **Verify**: D365WriteEvent created with WriteStatus=Failed, ErrorDetails logged
5. **Verify**: Retry scheduled (exponential backoff)
6. **Verify**: Re-enable D365 connection
7. **Verify**: Retry succeeds; D365 record created; audit log shows retry + success

#### Scenario 7: Contact Matching
1. Upload form with Claimant info (Name + SSN)
2. Matching Contact already exists in Dataverse
3. AI extraction completes
4. **Verify**: Contact matching runs; ContactID found & stored in ExtractionResult
5. **Verify**: Audit log entry: Contact match at ≥95% confidence
6. **Verify**: If contact match fails, ContactID=null, warning logged

#### Scenario 8: Batch Processing
1. Upload 5 PDFs simultaneously to SharePoint (simulate batch intake)
2. All 5 → Intake flow triggered in parallel
3. **Verify**: All 5 FormSubmission records created within 30 seconds (per spec.md acceptance criteria)
4. **Verify**: All 5 proceed to extraction queue
5. **Verify**: No race conditions or duplicate records

#### Scenario 9: Power Apps Validation
1. Open correction UI with ExtractionResult (Status=ReviewRequired)
2. Try to submit form with invalid data:
   - SSN = "123" (invalid format)
   - Date = "13/45/2000" (invalid date)
   - Required field (Beneficiary Name) = empty
3. **Verify**: Form submission blocked; error message displayed for each invalid field
4. **Verify**: Correct all errors; form submits successfully

#### Scenario 10: Analytics & Metrics
1. Process 10 test forms (5 auto-approved, 3 review-required, 2 manual-intake)
2. Run Daily-Metrics-Aggregation flow
3. **Verify**: ExtractionMetrics record created: TotalFormsProcessed=10, AutoApprovedCount=5, ReviewRequiredCount=3, ManualIntakeCount=2
4. **Verify**: Power BI dashboard displays correct charts & metrics
5. **Verify**: Average confidence scores computed correctly by field

### Manual Testing Checklist

- [ ] T089 Test Scenario 1 (Happy Path): End-to-end verification, all data correct
- [ ] T090 Test Scenario 2 (Human Review): Correction UI working, edits logged, D365 write uses corrected value
- [ ] T091 Test Scenario 3 (Manual Intake): Low-confidence form rejected, supervisor alerted
- [ ] T092 Test Scenario 4 (Duplicate Detection): Duplicate rejected, audit logged
- [ ] T093 Test Scenario 5 (Malformed File): Non-PDF rejected, user notified
- [ ] T094 Test Scenario 6 (D365 Retry): Failure handled, retry succeeds
- [ ] T095 Test Scenario 7 (Contact Matching): Contact ID correctly matched & stored
- [ ] T096 Test Scenario 8 (Batch Processing): 5 concurrent uploads processed correctly
- [ ] T097 Test Scenario 9 (Power Apps Validation): Form validation working, errors caught
- [ ] T098 Test Scenario 10 (Analytics): Metrics aggregated correctly, dashboard updated

---

## Performance Targets & Monitoring

### SLA Targets (from plan.md + spec.md)

| Operation | Target | Acceptance Threshold |
|-----------|--------|----------------------|
| AI extraction latency (per form) | <5 seconds | ≥90% of forms meet target |
| D365 write latency (per record) | <2 seconds | ≥90% of writes meet target |
| Form processing throughput | ≥5 forms/minute concurrent | Demo scope: ≥5 forms/min |
| Extraction accuracy (AI + human) | ≥90% | Demo baseline: ~70% AI alone + human review |
| Audit log latency (event log) | <1 second | All events logged within 1s |

### Monitoring & Observability

- [ ] T099 Add flow execution telemetry: Log execution time for each flow action (intake validation, AI call, D365 write, etc.)
- [ ] T100 Create Dataverse query to report flow performance by day (average latency, percentiles, failures)
- [ ] T101 Monitor Power BI dashboard for anomalies: Spike in review-required %, drop in auto-approval %
- [ ] T102 Set up alerts: If rejection rate >30% or D365 write failure rate >10%, trigger supervisor alert

---

## Task Summary

**Total Tasks**: 102  
**Phases**: 8  
**User Stories**: 5  

| Component | Count | Status |
|-----------|-------|--------|
| Setup tasks | 8 | Phase 1 |
| Foundational tasks | 20 | Phase 2 |
| User Story 1 (Intake) tasks | 8 | Phase 3 |
| User Story 2 (Extraction) tasks | 9 | Phase 4 |
| User Story 4 (D365 Write) tasks | 11 | Phase 5 |
| User Story 3 (Correction) tasks | 9 | Phase 6 |
| User Story 5 (Analytics) tasks | 8 | Phase 7 |
| Polish & Testing tasks | 13 | Phase 8 |
| **Total** | **102** | |

**Estimated Timeline**:
- 1 developer: 4–5 days (sequential delivery)
- 3 developers: 2–3 days (parallel: US1 + US2 + US4, then US3, then US5)

**MVP Scope** (Phase 1–5): 3–4 days; covers core intake → extraction → D365 write pipeline

---

## Notes & Future Considerations

### Phase 2 Enhancements (Post-MVP)

- WCAG AA accessibility for Power Apps form (currently basic)
- Immutable audit ledger (current: Dataverse table; future: Azure Confidential Ledger or blockchain anchor)
- Advanced analytics: Anomaly detection, model drift monitoring
- AI Builder model retraining workflow (automated, triggered by low-accuracy metrics)

### Production Scale (Beyond MVP)

- Increase throughput to ≥100 forms/hour (Power Automate concurrency tuning, batching)
- Production AI Builder model (trained on 500+ forms, ≥90% accuracy)
- D365 integration expanded to full business logic (case creation, notifications, workflows)
- Compliance: FedRAMP, FISMA audit trail, retention policies
- Multi-region deployment for disaster recovery

### Known Constraints

- **AI Builder minimum training**: 5 forms (results in ~70% accuracy; acceptable for demo, insufficient for production)
- **Power Automate concurrency**: Default 50 parallel flows; for 100+ forms/hour, requires tenant-level tuning
- **Dataverse storage**: Unlimited for demo; production scale requires lifecycle policies
- **D365 write latency**: Depends on D365 environment health; target <2s achievable with connection optimization

---

**Generated**: 2026-04-24  
**Template**: `.specify/templates/tasks-template.md`  
**Spec Version**: v1.0.1-PowerPlatform  
**Plan Version**: v1.0.1-PowerPlatform  
**Data Model Version**: v1.0.0  
**Research Version**: v1.0.0-Phase0-Complete  
