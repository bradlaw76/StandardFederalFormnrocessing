# Phase 2: Foundational — Design & Data Prep

**Duration**: 6–8 hours  
**Status**: Queued (awaiting Phase 1 completion)  
**Lead**: 🎨 Tommy Shelby  
**Team**: Polly (schema), Michael (AI data), John (flow foundation), Alfie (D365 mapping)

**Gate**: All Phase 1 issues must close before Phase 2 starts.

---

## Instructions

1. **Prerequisite**: Verify Phase 1 completion
   - [ ] Power Platform environment ready
   - [ ] SharePoint site & library ready
   - [ ] D365 connector working
   - [ ] AI Builder capacity confirmed
   - [ ] Entra ID authentication ready

2. **Convert each Phase 2 task below to a GitHub issue** with label `squad`
3. **Run squad triage** to auto-assign
4. **Track completion** as tasks finish
5. **Checkpoint**: All Phase 2 tasks must complete before Phase 3 kicks off

---

## Phase 2 Parallel Tasks (P01–P08)

### P01: Design Dataverse Schema — FormSubmission Table
**Owner**: 📊 Polly Gray (Dataverse Schema Design)  
**Estimated Time**: 45–60 min  
**Depends On**: Phase 1 checkpoint

**Description**:
Design and create the FormSubmission table in Dataverse to store VA form submission metadata and extraction status. This is the core source-of-truth table for all form intake and tracking.

**Acceptance Criteria**:
- [ ] FormSubmission table created in Dataverse
- [ ] Fields defined: FormID, SubmissionDate, FormName, FileURI, Status, ExtractionStatus, SubmittedBy, LastModified
- [ ] Primary name field set to FormID
- [ ] Relationships designed (will link to ExtractionResult, D365WriteEvent)
- [ ] Field validation rules documented
- [ ] Report: FormSubmission table ready for data ingestion

**Acceptance Criteria (Extended)**:
- [ ] Audit logging enabled on table
- [ ] Owner-based sharing model configured
- [ ] Power Apps can read/write FormSubmission

---

### P02: Design Dataverse Schema — ExtractionResult Table
**Owner**: 📊 Polly Gray (Dataverse Schema Design)  
**Estimated Time**: 45–60 min  
**Depends On**: P01 (parallel OK)

**Description**:
Design and create the ExtractionResult table to store AI-extracted field data and confidence scores for each form submission.

**Acceptance Criteria**:
- [ ] ExtractionResult table created in Dataverse
- [ ] Fields defined: ExtractionID, FormSubmissionID (lookup), FieldName, ExtractedValue, ConfidenceScore, ModelVersion, ExtractionTimestamp
- [ ] Lookup relationship to FormSubmission created
- [ ] Cascade delete configured (if FormSubmission deleted, ExtractionResults deleted too)
- [ ] Report: ExtractionResult table ready

---

### P03: Design Dataverse Schema — CorrectionRecord Table
**Owner**: 📊 Polly Gray (Dataverse Schema Design)  
**Estimated Time**: 30–45 min  
**Depends On**: P02 (parallel OK)

**Description**:
Design and create the CorrectionRecord table to store user corrections and feedback to AI extraction.

**Acceptance Criteria**:
- [ ] CorrectionRecord table created in Dataverse
- [ ] Fields defined: CorrectionID, ExtractionResultID (lookup), OriginalValue, CorrectedValue, CorrectionReason, CorrectedBy, CorrectionTimestamp
- [ ] Lookup relationship to ExtractionResult created
- [ ] Report: CorrectionRecord table ready

---

### P04: Design Dataverse Schema — AuditLog Table
**Owner**: 📊 Polly Gray (Dataverse Schema Design)  
**Estimated Time**: 30–45 min  
**Depends On**: P03 (parallel OK)

**Description**:
Design and create the AuditLog table for compliance tracking of all form processing and extraction events.

**Acceptance Criteria**:
- [ ] AuditLog table created in Dataverse
- [ ] Fields defined: AuditID, FormSubmissionID (lookup), EventType (Submitted, Extracted, Corrected, Written to D365), EventTimestamp, User, ChangeDetails (JSON or text)
- [ ] Report: AuditLog table ready

---

### P05: Design Dataverse Schema — D365WriteEvent Table
**Owner**: 📊 Polly Gray (Dataverse Schema Design)  
**Estimated Time**: 30–45 min  
**Depends On**: P04 (parallel OK)

**Description**:
Design and create the D365WriteEvent table to track all writes to Dynamics 365 with status and error tracking.

**Acceptance Criteria**:
- [ ] D365WriteEvent table created in Dataverse
- [ ] Fields defined: WriteEventID, FormSubmissionID (lookup), D365EntityType, D365RecordID, WriteStatus (Success, Failed, Pending), ErrorDetails, WriteTimestamp, RetryCount
- [ ] Lookup relationship to FormSubmission created
- [ ] Report: D365WriteEvent table ready

---

### P06: Prepare AI Training Data — Collect Sample VA Forms
**Owner**: 🔹 Michael Gray (AI Builder Specialist)  
**Estimated Time**: 60–90 min  
**Depends On**: Phase 1 checkpoint (parallel with schema design)

**Description**:
Collect and prepare sample VA Form 10-3542 PDFs for AI model training. Extract or create at least 5 annotated examples covering variations in form quality, handwriting, and completeness.

**Acceptance Criteria**:
- [ ] 5–10 representative VA Form 10-3542 samples collected
- [ ] Samples cover: good quality scans, handwritten entries, partial form completions, varied layouts
- [ ] Forms uploaded to SharePoint FormIntake library
- [ ] Metadata documented: form name, variation type, expected field values
- [ ] Report: Training data ready for AI Builder annotation

---

### P07: Design AI Model Training Strategy
**Owner**: 🔹 Michael Gray (AI Builder Specialist)  
**Estimated Time**: 45–60 min  
**Depends On**: P06 (parallel OK)

**Description**:
Design the AI Builder custom document processing model strategy, including field extraction targets, confidence thresholds, and validation rules.

**Acceptance Criteria**:
- [ ] Model name: "VAForm10-3542-Extractor"
- [ ] Extraction fields defined: ServiceNumber, ClaimDate, ServiceBranch, DisabilityRating, BenefitType, etc.
- [ ] Confidence threshold strategy documented (e.g., accept >80%, flag 60-80%, reject <60%)
- [ ] Validation rules documented (e.g., ServiceNumber format, dates valid)
- [ ] Report: AI model strategy ready for training

---

### P08: Design Power Automate Flow Architecture
**Owner**: 🔹 John Shelby (Flow Orchestration)  
**Estimated Time**: 45–60 min  
**Depends On**: Phase 1 checkpoint (parallel)

**Description**:
Design the foundational Power Automate flow architecture covering intake, extraction trigger, AI invocation, and D365 write trigger points. Document flow triggers, actions, error handlers, and shared connector actions.

**Acceptance Criteria**:
- [ ] Flow architecture diagram documented (3 main flows: Intake, AI Extraction, D365 Write)
- [ ] Trigger strategy defined (SharePoint file upload, document name pattern matching)
- [ ] Shared connector actions identified (D365 write, AI invoke, Dataverse create)
- [ ] Error handling strategy documented (retry logic, dead-letter queue approach)
- [ ] Flow variable/configuration parameters defined
- [ ] Report: Flow architecture ready for build

---

## Phase 2 Checkpoint (Gate)

**All tasks must complete before Phase 3 starts. Verify:**

- [ ] P01–P05: All 5 Dataverse tables created and relationships configured
- [ ] P06: Training data collected and uploaded
- [ ] P07: AI model strategy finalized
- [ ] P08: Flow architecture documented

**Checkpoint Sign-Off**: 🎨 Tommy Shelby (Lead reviews schema + architecture)

---

## How to Use This Checklist

### Step 1: Create GitHub Issues (after Phase 1 gates)
For each task (P01–P08), create a GitHub issue with:
- **Title**: Copy the task name
- **Body**: Copy the "Description" and "Acceptance Criteria"
- **Label**: Add `squad` label
- **Assign**: Leave unassigned (Squad will triage)

### Step 2: Run Squad Triage
```bash
squad triage --filter "label:squad"
```

### Step 3: Monitor Phase 2 Completion
```bash
gh issue list --label "squad:*" --state open
```

### Step 4: Checkpoint
Once all 8 tasks are marked complete (GitHub issues closed), Phase 2 is complete and Phase 3 can begin.

---

## Team Assignment Summary

| Task | Owner | Role | Parallel Group |
|------|-------|------|-----------------|
| P01 | 📊 Polly Gray | Dataverse Schema Design | Schema (P01–P05) |
| P02 | 📊 Polly Gray | Dataverse Schema Design | Schema (P01–P05) |
| P03 | 📊 Polly Gray | Dataverse Schema Design | Schema (P01–P05) |
| P04 | 📊 Polly Gray | Dataverse Schema Design | Schema (P01–P05) |
| P05 | 📊 Polly Gray | Dataverse Schema Design | Schema (P01–P05) |
| P06 | 🔹 Michael Gray | AI Builder Specialist | Data & Flow (P06–P08) |
| P07 | 🔹 Michael Gray | AI Builder Specialist | Data & Flow (P06–P08) |
| P08 | 🔹 John Shelby | Flow Orchestration | Data & Flow (P06–P08) |

**Note**: Two parallel streams:
- **Schema Stream** (Polly): P01–P05 can all run in parallel (5 tasks, 3–4 hours total if parallelized)
- **Data & Flow Stream** (Michael + John): P06–P08 can run in parallel with schema design

---

## Next Steps

1. ✅ **Phase 1**: Environment setup (2–3h)
2. **Phase 2**: Schema + Data Prep (6–8h) ← YOU ARE HERE
3. **Phase 3–6**: User Stories 1–4 + implementation
4. **Phase 7**: Polish & deployment

**Ready to start Phase 2 when Phase 1 gates pass!** 🚀
