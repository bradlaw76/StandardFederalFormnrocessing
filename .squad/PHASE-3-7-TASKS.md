# Phases 3–7: User Stories & Implementation

**Duration**: ~4–5 weeks total  
**Status**: Queued (awaiting Phase 2 completion)  
**Lead**: 🎨 Tommy Shelby  
**Team**: All agents (Polly, Arthur, John, Michael, Grace, etc.)

**Gate**: All Phase 2 issues must close before Phase 3 starts.

---

## Overview

Phases 3–7 represent the full build & delivery cycle:
- **Phase 3**: Form Classification & Field Extraction Preparation
- **Phase 4**: AI Model Training & Optimization Pipeline
- **Phase 5**: Power Automate Flow Implementation & Orchestration
- **Phase 6**: D365 Integration & Data Write-Back Testing
- **Phase 7**: End-to-End Testing, UAT, & Deployment

---

# Phase 3: Form Classification & Field Extraction (2–3 days)

**Duration**: 2–3 days  
**Status**: Queued (Phase 2 → Phase 3)  
**Lead**: 🔹 Michael Gray (AI Lead)  
**Team**: Michael (AI), John (Flows), Polly (Data)

**Gate**: All Phase 2 tasks complete.

---

## P3-01: Configure Document Type Detection

**Owner**: 🔹 Michael Gray  
**Estimated Time**: 2–4 hours  
**Depends On**: P08 (Flow architecture), AI Builder capacity ready

**Description**:
Set up AI Builder's document type classification to detect and categorize VA Form 10-3542 vs. other form types (rejection logic for non-target forms).

**Acceptance Criteria**:
- [ ] AI Builder classifier model created: "VAForm10-3542-Detector"
- [ ] Training data: 20+ examples of target forms + 10+ examples of non-target forms
- [ ] Classifier accuracy >90% validated on test set
- [ ] Rejection rule: If confidence <85%, route to manual review queue
- [ ] Integration with flow: IF classifier rejects → mark Dataverse FormSubmission.Status = "RejectedType"
- [ ] Report: Document type detection ready for intake flow

---

## P3-02: Set Up OCR & Document Preprocessing

**Owner**: 🔹 Michael Gray  
**Estimated Time**: 3–5 hours  
**Depends On**: P3-01 (Document type detection working)

**Description**:
Configure AI Builder's form processing capabilities for OCR and form field layout recognition. Prepare image preprocessing (contrast, rotation, skew correction).

**Acceptance Criteria**:
- [ ] AI Builder form processor configured for VA Form 10-3542 layout
- [ ] OCR engine tested on 10+ sample forms (handwritten + printed)
- [ ] Field layout zones identified: ServiceNumber, ClaimDate, ServiceBranch, DisabilityRating, BenefitType, etc.
- [ ] Preprocessing rules documented: image enhancement, rotation detection, deskew
- [ ] Confidence scoring calibrated (expected accuracy rates documented)
- [ ] Report: OCR pipeline ready for training

---

## P3-03: Map Field Extraction Rules

**Owner**: 🔹 Michael Gray  
**Estimated Time**: 2–3 hours  
**Depends On**: P3-02 (OCR preprocessing ready)

**Description**:
Define extraction rules for each target field on VA Form 10-3542, including validation patterns and confidence thresholds.

**Acceptance Criteria**:
- [ ] Field mapping created for: ServiceNumber (format: NNN-NN-NNNN), ClaimDate (MM/DD/YYYY), ServiceBranch (enum), DisabilityRating (0-100%), BenefitType (enum)
- [ ] Validation rules for each field: format, length, allowed values
- [ ] Confidence thresholds: >80% auto-accept, 60-80% flag for review, <60% reject
- [ ] Field extraction rules exported to AI model
- [ ] Report: Field mapping rules finalized

---

## P3-04: Create Extraction Test Dataset

**Owner**: 🔹 Michael Gray  
**Estimated Time**: 4–6 hours  
**Depends On**: P06 (Training data collected)

**Description**:
Prepare and annotate test dataset for AI model validation. Includes edge cases (handwritten, partial forms, poor quality scans).

**Acceptance Criteria**:
- [ ] Test dataset created: 30+ diverse VA Form 10-3542 examples
- [ ] Categories: handwritten text, printed text, mixed, poor quality, partial completion, various layouts
- [ ] Ground truth annotations completed: expected field values for each sample
- [ ] Test set uploaded to SharePoint ModelTesting folder
- [ ] Report: Test dataset ready (30+ samples, fully annotated)

---

## P3-05: Build Form Intake Handler (Power Apps)

**Owner**: ⚛️ Lizzie Stark (UI/Apps)  
**Estimated Time**: 4–6 hours  
**Depends On**: P01-P05 (Dataverse schema ready), Phase 1 complete

**Description**:
Create Power Apps canvas app for form intake: file upload, metadata entry, form preview, submission confirmation.

**Acceptance Criteria**:
- [ ] Power Apps canvas app created: "FormIntakePortal"
- [ ] Features: File upload (drag & drop), Form preview, Metadata form (optional tags, urgency), Submit button
- [ ] On submit: Create Dataverse FormSubmission record, upload file to SharePoint
- [ ] Form validation: File size <10MB, PDF only, filename validation
- [ ] Success message: "Form submitted successfully" + FormID
- [ ] Styling: VA.gov-compliant colors (dark blue, white), responsive design
- [ ] Report: Form intake app ready for Phase 4 testing

---

# Phase 4: AI Model Training & Optimization (2–3 days)

**Duration**: 2–3 days  
**Status**: Queued (Phase 3 complete → Phase 4)  
**Lead**: 🔹 Michael Gray (AI Lead)  
**Team**: Michael (AI), Grace (Testing), Polly (Data validation)

**Gate**: All Phase 3 tasks complete, test dataset ready.

---

## P4-01: Annotate Training Dataset

**Owner**: 🧪 Grace Burgess (QA/Testing)  
**Estimated Time**: 6–8 hours  
**Depends On**: P06 (Training samples collected)

**Description**:
Hand-annotate training dataset with ground truth field values for AI model training. VA staff or contractor performs detailed annotation.

**Acceptance Criteria**:
- [ ] All 5–10 training samples annotated with ground truth values
- [ ] Fields annotated: ServiceNumber, ClaimDate, ServiceBranch, DisabilityRating, BenefitType, etc.
- [ ] Confidence flags noted: unclear handwriting, ambiguous values documented
- [ ] Annotations uploaded to AI Builder training workspace
- [ ] QA check: 100% of annotations reviewed for accuracy
- [ ] Report: Training dataset fully annotated and validated

---

## P4-02: Train AI Model (AI Builder)

**Owner**: 🔹 Michael Gray  
**Estimated Time**: 1–2 hours (active training time)  
**Depends On**: P4-01 (Training dataset annotated), P3-04 (Test dataset ready)

**Description**:
Execute AI Builder training on the annotated VA Form 10-3542 dataset. Model: "VAForm10-3542-Extractor".

**Acceptance Criteria**:
- [ ] AI model training initiated in AI Builder
- [ ] Training completed successfully (AI Builder status: Ready)
- [ ] Model version: v1.0 created and published
- [ ] Model performance metrics captured: Accuracy >85%, Precision >80%, Recall >80%
- [ ] Model published and endpoint available for integration
- [ ] Report: AI model trained and ready for testing

---

## P4-03: Test AI Model Accuracy

**Owner**: 🧪 Grace Burgess (QA/Testing)  
**Estimated Time**: 4–6 hours  
**Depends On**: P4-02 (AI model trained)

**Description**:
Execute comprehensive testing of trained AI model against test dataset. Validate accuracy, false positive/negative rates, edge case handling.

**Acceptance Criteria**:
- [ ] Test execution: AI model inference on all 30+ test samples
- [ ] Accuracy calculated: (CorrectExtractions / TotalSamples) >= 85%
- [ ] Per-field accuracy tracked: ServiceNumber >95%, ClaimDate >90%, etc.
- [ ] Edge cases tested: handwritten text, poor quality scans, partial forms
- [ ] Error log created: Failed extractions documented with root cause
- [ ] Confidence threshold validation: >80% confidence produces <5% error rate
- [ ] Report: Model accuracy validated, edge cases documented, confidence thresholds confirmed

---

## P4-04: Optimize Model & Tune Thresholds

**Owner**: 🔹 Michael Gray  
**Estimated Time**: 2–3 hours  
**Depends On**: P4-03 (Test results analyzed)

**Description**:
Tune model confidence thresholds based on test results. Optimize for business tradeoffs: accuracy vs. manual review volume.

**Acceptance Criteria**:
- [ ] Confidence threshold analysis: <60% = manual review, 60-80% = flag for review, >80% = auto-accept
- [ ] Threshold tuning: Adjust to minimize false positives while maintaining coverage
- [ ] Retrained if needed: If accuracy <85%, retrain with additional data
- [ ] Final confidence thresholds documented and approved
- [ ] Model updated to production version
- [ ] Report: Model optimized and thresholds finalized

---

## P4-05: Create AI Model Monitoring Dashboard

**Owner**: 🔹 Michael Gray  
**Estimated Time**: 3–4 hours  
**Depends On**: P4-04 (Model deployed)

**Description**:
Create Power BI dashboard to monitor AI model performance in production: accuracy trends, field extraction success rates, manual review queue.

**Acceptance Criteria**:
- [ ] Power BI dashboard created: "AI Model Performance"
- [ ] Metrics tracked: Daily extraction volume, accuracy %, error rate %, manual review %, model version
- [ ] Charts: Accuracy over time, field-level success rates, error distribution
- [ ] Alerts configured: If accuracy drops <80%, alert Tommy Shelby
- [ ] Data source: Power BI connected to Dataverse ExtractionResult + AuditLog
- [ ] Report: Monitoring dashboard ready

---

# Phase 5: Power Automate Flow Implementation (3–4 days)

**Duration**: 3–4 days  
**Status**: Queued (Phase 4 complete → Phase 5)  
**Lead**: 🔹 John Shelby (Flow Orchestration)  
**Team**: John (Flows), Michael (AI config), Polly (Data), Alfie (D365)

**Gate**: All Phase 4 tasks complete, AI model in production.

---

## P5-01: Build SharePoint Intake Trigger Flow

**Owner**: 🔹 John Shelby  
**Estimated Time**: 3–4 hours  
**Depends On**: P08 (Flow architecture designed), Phase 1 complete

**Description**:
Create Power Automate flow triggered by SharePoint file upload. Flow validates file, creates Dataverse FormSubmission, and triggers AI extraction.

**Acceptance Criteria**:
- [ ] Flow name: "OnFormUpload-StartExtraction"
- [ ] Trigger: SharePoint FormIntake library, file created
- [ ] Actions: Extract file metadata, validate file type (PDF), create Dataverse FormSubmission record
- [ ] Extract fields from filename if possible (FormID, submission date)
- [ ] Set FormSubmission.Status = "Submitted", ExtractionStatus = "Pending"
- [ ] Call next flow: P5-02 (AI Extraction) synchronously
- [ ] Error handling: If validation fails, set Status = "Invalid" + log error
- [ ] Report: Intake flow deployed and tested

---

## P5-02: Build AI Extraction Invocation Flow

**Owner**: 🔹 John Shelby  
**Estimated Time**: 4–5 hours  
**Depends On**: P5-01 (Intake flow deployed), P4-02 (AI model ready)

**Description**:
Create Power Automate flow that invokes AI Builder model for form field extraction. Processes result, creates ExtractionResult records, handles confidence scoring.

**Acceptance Criteria**:
- [ ] Flow name: "ExtractFormFields-AIBuilder"
- [ ] Trigger: Called from P5-01 (Intake flow)
- [ ] Actions: Retrieve file from SharePoint, invoke AI Builder model, parse extraction results
- [ ] For each extracted field: Create Dataverse ExtractionResult record with ConfidenceScore
- [ ] Update FormSubmission.ExtractionStatus = "Complete"
- [ ] Flag fields with confidence <80% for manual review: Create flag in Dataverse
- [ ] Error handling: If AI fails, retry 2x, then set Status = "ExtractionFailed"
- [ ] Report: AI extraction flow deployed and tested

---

## P5-03: Build Manual Review & Correction Flow

**Owner**: 🔹 John Shelby  
**Estimated Time**: 3–4 hours  
**Depends On**: P5-02 (AI extraction deployed)

**Description**:
Create Power Automate flow for manual review of flagged extractions. Route to human reviewer, capture corrections, create CorrectionRecord.

**Acceptance Criteria**:
- [ ] Flow name: "ManualReview-FlaggedExtractions"
- [ ] Trigger: When ExtractionResult.ConfidenceScore < 80%
- [ ] Actions: Send email to Polly Gray (Data Validator) with flagged fields + image preview
- [ ] Reviewer updates Dataverse CorrectionRecord with corrected value + reason
- [ ] On correction: Update ExtractionResult with corrected value, set Status = "Corrected"
- [ ] Audit trail: Log review action in AuditLog table
- [ ] Error handling: If no response within 24h, escalate to Tommy Shelby
- [ ] Report: Manual review flow deployed and tested

---

## P5-04: Build D365 Write Trigger Flow

**Owner**: 🔹 John Shelby  
**Estimated Time**: 4–5 hours  
**Depends On**: P5-03 (Manual review flow), P6-01 (D365 connector ready)

**Description**:
Create Power Automate flow that writes extracted data to Dynamics 365. Triggered when ExtractionStatus = "Complete" and all corrections done.

**Acceptance Criteria**:
- [ ] Flow name: "WriteToD365-ClaimData"
- [ ] Trigger: When FormSubmission.ExtractionStatus = "Complete" AND no pending CorrectionRecords
- [ ] Actions: Map extracted fields to D365 entity (e.g., ServiceClaimRecord)
- [ ] Invoke D365 connector: Create or update record based on ServiceNumber
- [ ] Capture D365 response: RecordID, status, error details
- [ ] Create Dataverse D365WriteEvent: Log write attempt with status (Success/Failed)
- [ ] Error handling: If D365 write fails, retry 3x with exponential backoff, then alert Alfie Solomons
- [ ] Success: Set FormSubmission.Status = "WrittenToD365"
- [ ] Report: D365 write flow deployed and tested

---

## P5-05: Build Error Handling & Dead-Letter Queue

**Owner**: 🔹 John Shelby  
**Estimated Time**: 3–4 hours  
**Depends On**: All P5 flows deployed

**Description**:
Create error handling infrastructure: dead-letter queue for failed forms, retry logic, escalation rules.

**Acceptance Criteria**:
- [ ] Dead-letter queue created: Dataverse table "ErrorQueue" with fields: ErrorID, FormSubmissionID, ErrorType, ErrorMessage, RetryCount, Status
- [ ] Retry logic implemented: Automatic retry on transient failures (connection timeouts, throttling)
- [ ] Max retries: 3 for D365 writes, 5 for AI extraction (backoff 60s, 120s, 240s)
- [ ] Escalation configured: After max retries, escalate to Tommy Shelby via email
- [ ] Monitoring dashboard: Power BI chart showing error queue volume, retry success rate, escalations
- [ ] Report: Error handling infrastructure deployed

---

## P5-06: Build End-to-End Flow Integration Test

**Owner**: 🧪 Grace Burgess (QA/Testing)  
**Estimated Time**: 2–3 hours  
**Depends On**: All P5 flows deployed

**Description**:
Execute end-to-end integration test of all flows working together. Upload test form, verify Dataverse records, check D365 write.

**Acceptance Criteria**:
- [ ] Test execution: Upload 5 sample forms to SharePoint FormIntake
- [ ] Verify flow chain: Intake → Extraction → Manual Review → D365 Write triggered
- [ ] Check Dataverse: FormSubmission, ExtractionResult, CorrectionRecord, D365WriteEvent all created
- [ ] Verify D365: Check that claim data appears in D365 (if connected)
- [ ] Measure latency: End-to-end processing time <5 min for high-confidence forms
- [ ] Error scenarios tested: Invalid file, AI extraction failure, D365 timeout
- [ ] Report: End-to-end flow integration successful

---

# Phase 6: D365 Integration & Data Write-Back (1–2 days)

**Duration**: 1–2 days  
**Status**: Queued (Phase 5 complete → Phase 6)  
**Lead**: 🔧 Alfie Solomons (D365 Integration)  
**Team**: Alfie (D365), John (Flows), Polly (Data mapping)

**Gate**: All Phase 5 flows complete and tested.

---

## P6-01: Configure D365 Connector & Authentication

**Owner**: 🔧 Alfie Solomons  
**Estimated Time**: 2–3 hours  
**Depends On**: Phase 1 complete (D365 connector set up)

**Description**:
Configure D365 connection in Power Automate: service principal authentication, permissions, rate limits.

**Acceptance Criteria**:
- [ ] D365 connector configured in Power Automate with service principal
- [ ] Service principal: va-form-extractor (already created in Phase 1)
- [ ] Permissions validated: Can create/update ServiceClaimRecord entities
- [ ] Rate limit: 100 requests/min (verify D365 limits not exceeded)
- [ ] Connection tested: Test API call to D365 successful
- [ ] Credentials stored securely: Service principal key in Key Vault
- [ ] Report: D365 connector ready for flows

---

## P6-02: Map Extracted Fields to D365 Entities

**Owner**: 🔧 Alfie Solomons  
**Estimated Time**: 3–4 hours  
**Depends On**: P3-03 (Field extraction rules finalized)

**Description**:
Create field mapping document: Extracted VA Form fields → D365 ServiceClaimRecord entity fields.

**Acceptance Criteria**:
- [ ] Mapping document created: ExtractionResult fields → D365 entity fields
- [ ] Example mappings: ServiceNumber → ExternalID, ClaimDate → SubmissionDate, DisabilityRating → RatingPercentage, BenefitType → ClaimType
- [ ] Handle missing/null values: Default values or skip logic defined
- [ ] Handle edge cases: Invalid dates, out-of-range ratings, unmapped values
- [ ] Data transformation rules: E.g., DisabilityRating "50%" → 50 (numeric)
- [ ] Validation rules: Ensure mapped data passes D365 entity validation
- [ ] Report: Field mapping finalized and approved

---

## P6-03: Build D365 Record Creation Logic

**Owner**: 🔧 Alfie Solomons  
**Estimated Time**: 2–3 hours  
**Depends On**: P6-02 (Field mapping ready)

**Description**:
Implement D365 record creation logic: Create new ServiceClaimRecord if ServiceNumber not found, update if exists.

**Acceptance Criteria**:
- [ ] Logic: IF ServiceNumber exists in D365 → update; ELSE → create new record
- [ ] Create: Populate all mapped fields with extracted values
- [ ] Update: Preserve existing D365 data, merge new extracted data (extracted data takes priority)
- [ ] Duplicate detection: Check for duplicate claims within last 30 days
- [ ] Owner field: Assign D365 record to appropriate VA staff based on ClaimType
- [ ] Related records: Link to existing Veteran record if ServiceNumber known
- [ ] Report: D365 record creation logic finalized

---

## P6-04: Implement Error & Validation Handling (D365)

**Owner**: 🔧 Alfie Solomons  
**Estimated Time**: 2–3 hours  
**Depends On**: P6-03 (Record creation logic ready)

**Description**:
Add validation & error handling for D365 writes: data validation, D365 constraint checks, rollback logic.

**Acceptance Criteria**:
- [ ] Validation rules: Check mapped data against D365 entity schema before write
- [ ] Field constraints: Validate length, format, required fields, enum values
- [ ] D365 errors caught: Handle 400/403/429/500 errors with retry logic
- [ ] Partial update handling: If some fields fail validation, don't write any field (atomic transaction logic)
- [ ] Rollback: If D365 write fails after 3 retries, create ErrorQueue entry + alert
- [ ] Audit trail: Log all D365 writes to AuditLog (who wrote, what, when, outcome)
- [ ] Report: D365 error handling implemented

---

## P6-05: Test D365 Integration End-to-End

**Owner**: 🧪 Grace Burgess (QA/Testing)  
**Estimated Time**: 3–4 hours  
**Depends On**: All P6 logic deployed

**Description**:
Execute comprehensive D365 integration testing: create, update, error scenarios, data validation.

**Acceptance Criteria**:
- [ ] Test scenarios: Create new claim, update existing claim, duplicate detection, invalid data handling
- [ ] Data accuracy: Verify extracted data matches D365 record fields
- [ ] Latency: D365 write completes within 10 seconds
- [ ] Error scenarios: Service connectivity loss, D365 throttling, invalid data → proper error handling
- [ ] Audit trail: Verify AuditLog entries created for all writes
- [ ] Rollback testing: Failed writes don't leave partial data in D365
- [ ] Report: D365 integration fully tested and validated

---

# Phase 7: End-to-End Testing, UAT & Deployment (3–5 days)

**Duration**: 3–5 days  
**Status**: Queued (Phase 6 complete → Phase 7)  
**Lead**: 🧪 Grace Burgess (QA Lead)  
**Team**: Grace (Testing), Michael (AI validation), John (Flow validation), Tommy (Lead signoff)

**Gate**: All Phase 6 tasks complete and passed integration testing.

---

## P7-01: Execute Unit Tests (All Components)

**Owner**: 🧪 Grace Burgess  
**Estimated Time**: 4–6 hours  
**Depends On**: All components deployed (Phases 3-6)

**Description**:
Execute unit tests for all Power Automate flows, Power Apps, AI model, and Dataverse logic.

**Acceptance Criteria**:
- [ ] Power Automate flows: Unit tests for all actions, error paths, edge cases
- [ ] Power Apps: Form validation tests, UI interaction tests, data binding tests
- [ ] AI model: Unit tests for inference engine, confidence scoring, edge case handling
- [ ] Dataverse: Table operations (create, read, update, delete), relationship integrity, validation rules
- [ ] Code coverage: Minimum 80% code coverage on all custom logic
- [ ] Test results: All tests passing, no critical issues
- [ ] Report: Unit test report with coverage metrics

---

## P7-02: Execute Integration Tests

**Owner**: 🧪 Grace Burgess  
**Estimated Time**: 6–8 hours  
**Depends On**: P7-01 (Unit tests pass)

**Description**:
Execute comprehensive integration tests: all components working together end-to-end.

**Acceptance Criteria**:
- [ ] Happy path: Upload form → extraction → manual review (if needed) → D365 write (complete flow)
- [ ] Edge cases: Handwritten forms, poor quality scans, partial forms, invalid data
- [ ] Error paths: File validation failures, AI extraction failures, D365 connectivity issues, manual review escalation
- [ ] Data consistency: Verify Dataverse + D365 data matches, no orphaned records
- [ ] Performance: End-to-end latency <5 min (high confidence), <10 min (manual review)
- [ ] Concurrency: Test 5 simultaneous form uploads
- [ ] Report: Integration test report with results

---

## P7-03: Execute Performance & Load Testing

**Owner**: 🧪 Grace Burgess  
**Estimated Time**: 4–6 hours  
**Depends On**: P7-02 (Integration tests pass)

**Description**:
Load test the system: simulate realistic volume, measure throughput, identify bottlenecks.

**Acceptance Criteria**:
- [ ] Load test scenario: 50 forms/hour sustained, 100 forms/hour peak
- [ ] Metrics tracked: Throughput (forms/min), latency (avg/p95/p99), error rate, AI model inference time
- [ ] Bottleneck analysis: Identify resource constraints (CPU, memory, API limits)
- [ ] Scaling recommendation: Determine scaling needs for production volume
- [ ] Dataverse limits: Verify not hitting API throttling limits
- [ ] D365 connector limits: Verify not hitting D365 rate limits
- [ ] Report: Performance report with scaling recommendations

---

## P7-04: Execute Security & Compliance Testing

**Owner**: 🧪 Grace Burgess  
**Estimated Time**: 3–4 hours  
**Depends On**: All components deployed

**Description**:
Security testing: authentication, authorization, data protection, compliance (HIPAA, VA data handling).

**Acceptance Criteria**:
- [ ] Authentication: Verify Entra ID authentication required for all access
- [ ] Authorization: Verify RBAC enforced (VA staff can only see own forms)
- [ ] Data protection: Verify sensitive data encrypted at rest + in transit
- [ ] Audit logging: Verify all data access logged in AuditLog
- [ ] Compliance checklist: HIPAA requirements met (if applicable), VA data handling policy met
- [ ] Penetration testing: Verify no obvious vulnerabilities (OWASP top 10 check)
- [ ] Report: Security & compliance report

---

## P7-05: Execute User Acceptance Testing (UAT)

**Owner**: 🧪 Grace Burgess  
**Estimated Time**: 5–8 hours  
**Depends On**: P7-04 (Security testing pass)

**Description**:
UAT with VA staff: test with real VA users in staging environment, validate requirements met.

**Acceptance Criteria**:
- [ ] UAT participants: 3-5 VA staff (VA.gov/Benefits staff involved in form processing)
- [ ] Test scenarios: Intake forms, review extracted data, correct if needed, verify D365 write
- [ ] User feedback: Collect usability feedback on Power Apps form intake UI
- [ ] Requirement verification: Verify all Phase 1-6 requirements met from user perspective
- [ ] Sign-off: UAT sign-off from VA stakeholder (e.g., Service Officer or equivalent)
- [ ] Issues logged: Any critical issues = P1, must fix before go-live
- [ ] Report: UAT report with sign-off

---

## P7-06: Final Deployment Preparation

**Owner**: 🔧 Arthur Shelby (Infrastructure Lead)  
**Estimated Time**: 2–3 hours  
**Depends On**: P7-05 (UAT pass)

**Description**:
Prepare production environment: copy solutions to production, verify connections, document runbooks.

**Acceptance Criteria**:
- [ ] Production Power Automate solution: Copy from staging to production
- [ ] Production Power Apps: Published to production tenant
- [ ] Production Dataverse: Schema replicated, data migration plan (if needed)
- [ ] Production D365 connector: Test connectivity to production D365 instance
- [ ] Runbooks created: Deployment runbook, rollback runbook, incident response runbook
- [ ] Monitoring configured: Power BI dashboards, alert rules, health checks
- [ ] Backup strategy: Verified backup of Dataverse, D365 data
- [ ] Report: Production deployment checklist complete

---

## P7-07: Execute Go-Live Deployment

**Owner**: 🔧 Arthur Shelby  
**Estimated Time**: 1–2 hours  
**Depends On**: P7-06 (Deployment prep complete)

**Description**:
Execute go-live: deploy to production, verify all systems operational, prepare for support.

**Acceptance Criteria**:
- [ ] Deployment executed: All production components deployed & verified
- [ ] Health checks passed: Power Automate flows active, Power Apps accessible, Dataverse operational, D365 connected
- [ ] Smoke tests: Upload 1 test form → verify extraction → verify D365 write succeeds
- [ ] Monitoring active: Power BI dashboards live, alerts configured, log monitoring active
- [ ] Support team briefed: Incident response team ready for escalations
- [ ] Go-live announcement: Notify VA staff system is live
- [ ] Report: Go-live deployment successful

---

## P7-08: Post-Deployment Monitoring & Support (Day 1)

**Owner**: 🧪 Grace Burgess  
**Estimated Time**: 4–8 hours  
**Depends On**: P7-07 (Go-live deployment)

**Description**:
24-hour post-deployment monitoring and support: track issues, validate system stability, provide user support.

**Acceptance Criteria**:
- [ ] Monitoring active: Track form intake volume, extraction accuracy, error rates
- [ ] Issues tracked: Log any issues reported by VA staff or monitoring alerts
- [ ] Critical issues: Any system-breaking issue → immediate investigation + fix
- [ ] User support: Respond to VA staff questions about system usage within 1 hour
- [ ] Stability confirmed: System processing forms successfully with <2% error rate
- [ ] Success metrics: First 50 forms processed successfully, D365 writes verified
- [ ] Report: Day 1 post-deployment report, lessons learned, action items for Phase 8

---

## Phase 7 Checkpoint (Gate)

**Go-Live Confirmation:**
- [ ] All testing complete: Unit, Integration, Performance, Security, UAT passed
- [ ] Production deployment successful
- [ ] System processing forms end-to-end
- [ ] Error rate <2%, latency <5 min average
- [ ] VA staff trained and using system
- [ ] Go-live signoff from Tommy Shelby

**Checkpoint Sign-Off**: 🎨 Tommy Shelby + 🧪 Grace Burgess

---

## Future Phase 8: Optimization & Iterations (Post-Go-Live)

**Planned (not included in Phase 7)**:
- Monitor AI model accuracy over time, retrain with real production data
- Collect user feedback, implement UI/UX improvements
- Optimize latency, scale for higher volumes
- Implement additional form types (future expansion)
- Auto-remediation of common errors

---

## Summary: All Phases Roadmap

| Phase | Focus | Duration | Status |
|-------|-------|----------|--------|
| 1 | Environment Setup | 2–3h | ✅ ACTIVE |
| 2 | Schema & Data Prep | 6–8h | 📋 QUEUED |
| 3 | Form Classification & Extraction | 2–3d | 📋 QUEUED |
| 4 | AI Model Training | 2–3d | 📋 QUEUED |
| 5 | Flow Implementation | 3–4d | 📋 QUEUED |
| 6 | D365 Integration | 1–2d | 📋 QUEUED |
| 7 | Testing, UAT, Go-Live | 3–5d | 📋 QUEUED |
| **Total** | **Full Delivery** | **~3–4 weeks** | **On Track** |

---

## How to Use This Document

1. **After Phase 2 completes**, convert each Phase 3-7 task to a GitHub issue
2. **Run Squad triage** to auto-assign to team members
3. **Monitor progress** via `gh issue list --label "squad:*"`
4. **Track checkpoints** at end of each phase before proceeding to next

---

**Next Action**: Create GitHub issues for Phases 3-7 tasks when you're ready to queue them.
