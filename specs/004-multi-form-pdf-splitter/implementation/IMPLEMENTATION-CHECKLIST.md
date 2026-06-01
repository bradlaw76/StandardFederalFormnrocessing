# Implementation Checklist: Mode 2 — Multi-Form PDF Splitter

**Feature**: 004-multi-form-pdf-splitter  
**Branch**: 004-multi-form-pdf-splitter  
**Tasks**: T001–T070 (70 total)  
**Generated**: 2025-07-17  
**Version**: 1.0.0  
**Status**: Ready for execution

---

## How to Use This Checklist

- Check off each task `[ ]` → `[x]` as you complete it in Power Platform
- Record actual completion times where noted
- **Gate checkpoints** (marked ⛔) must pass before the next phase begins
- **⚠️ MODIFY EXISTING FLOW** tasks require extra care — follow [FLOW-1-MODIFICATION.md](FLOW-1-MODIFICATION.md)
- **[P]** tasks can be executed in parallel with other [P] tasks in the same phase

---

## Phase 1: Setup (Environment & Prerequisites)

**Purpose**: Validate environment and confirm Azure Function is deployed. No SharePoint changes required — Azure Function integrates additively into existing flow.

> ⛔ **GATE**: All Phase 1 tasks must complete before Phase 2 begins.

| Task | Story | [P] | Description | Artifact | Status |
|---|---|---|---|---|---|
| T001 | — | | Verify existing pipeline is operational | All 5 MVP flows On (VAFormExtractionDemo) | ✅ |
| T002 | — | | Deploy Azure Function app for PDF splitting | `va-pdf-splitter-dev` live at `https://va-pdf-splitter-dev.azurewebsites.net` | ✅ |
| T003 | — | | Smoke-test Azure Function endpoints; document `AzureFunctionBaseUrl` + `AzureFunctionKey` | Values recorded in `quickstart.md` | ✅ |
| ~~T004~~ | — | | ~~Create SharePoint folder structure~~ | **SKIPPED** — additive integration, no SP changes needed | ⏭ |
| T005 | — | | Document environment variable values for Flow-01 | `quickstart.md` updated | ✅ |

### Phase 1 Checklist

- [x] **T001** — All 5 flows confirmed **On** ✅: MVP-01-SharePoint-To-D365-Intake, MVP-02-D365-Write-Subflow, MVP-03-Audit-Logger-Subflow, MVP-04-D365-Retry, MVP-05-AI-Extraction-Subflow
- [x] **T002** — `va-pdf-splitter-dev` deployed; both endpoints return HTTP 200 ✅
- [x] **T003** — Endpoints confirmed live; `AzureFunctionBaseUrl` and `AzureFunctionKey` documented in `quickstart.md` ✅
- [x] ~~**T004**~~ — **SKIPPED**: No SharePoint changes required; Azure Function is additive ⏭
- [x] **T005** — `quickstart.md` updated with all env values ✅

**✅ Phase 1 Gate: PASSED** — All flows On, Azure Function deployed & smoke-tested → **Phase 2 may begin**

---

## Phase 2: Foundational — Dataverse Schema (Blocking Prerequisites)

**Purpose**: Create `BatchSubmission` table and extend `FormSubmission`. All flow phases depend on this.

> ⛔ **GATE**: All Phase 2 tasks must complete and Mode 1 must be verified unaffected before Phase 3 begins.  
> 📋 **Reference**: [DATAVERSE-SCHEMA.md](DATAVERSE-SCHEMA.md)

| Task | Story | [P] | Description | Artifact | Status |
|---|---|---|---|---|---|
| T006 | — | | Create `BatchSubmission` Dataverse table — base structure | `Dataverse > Tables > BatchSubmission` | [ ] |
| T007 | — | [P] | Add core metadata columns (SourceFileName, FileSize, PageCount, Hash, TotalFormCount, UploadedBy, UploadTimestamp) | `Dataverse > Tables > BatchSubmission > Columns` | [ ] |
| T008 | — | [P] | Add `BatchStatus` Option Set with 12 values; add column to BatchSubmission | `Dataverse > Option Sets > BatchStatus` | [ ] |
| T009 | — | [P] | Add counter and timestamp columns (FormsCompleted, FormsInReview, FormsFailed, FormsProcessing, CompletionPercentage, timestamps) | `Dataverse > Tables > BatchSubmission > Columns` | [ ] |
| T010 | — | [P] | Add operational columns (ErrorDetails, LastSuccessfulSplitIndex, SharePointBatchFolderPath, OriginalFileSharePointID) | `Dataverse > Tables > BatchSubmission > Columns` | [ ] |
| T011 | — | | Add `BatchID` lookup column to `FormSubmission` → BatchSubmission; NULLABLE | `Dataverse > Tables > FormSubmission > Columns` | [ ] |
| T012 | — | | Add `FormIndexInBatch` whole number column to `FormSubmission`; NULLABLE; publish | `Dataverse > Tables > FormSubmission > Columns` | [ ] |

### Phase 2 Checklist

- [ ] **T006** — `BatchSubmission` table created; visible in Dataverse tables list; `BatchDisplayID` as primary column (Text, required)
- [ ] **T007** — [P] All 7 metadata columns added and saved
- [ ] **T008** — [P] `BatchStatus` option set created with exactly 12 values (exact spelling per DATAVERSE-SCHEMA.md §1); added to BatchSubmission; default = `Uploaded`
- [ ] **T009** — [P] All 9 counter/timestamp columns added (FormsCompleted default=0, CompletionPercentage, etc.)
- [ ] **T010** — [P] All 4 operational columns added (ErrorDetails 4000 chars, etc.)
- [ ] **T011** — `FormSubmission.BatchID` lookup column added; NULLABLE; existing records show null; Flow 1 test run succeeds with no schema errors
- [ ] **T012** — `FormSubmission.FormIndexInBatch` whole number column added; NULLABLE; table published; Mode 1 test run (Flow 1+2+3+4) completes without errors; both new columns null on existing records

**⛔ Phase 2 Gate**: `[ ]` Schema changes published `[ ]` Mode 1 single-form test succeeds `[ ]` No errors on existing records → **Phase 3 may begin**

---

## Phase 3: US1 — Batch PDF Upload & Detection (P1 MVP)

**Goal**: Build `Flow-01-Batch-PDF-Splitter` trigger through validation steps.  
📋 **Reference**: [FLOW-01-RUNBOOK.md](FLOW-01-RUNBOOK.md) Parts 1–7  
🔗 **Expressions**: [EXPRESSION-REFERENCE.md](EXPRESSION-REFERENCE.md) Sections 1–3

| Task | Story | [P] | Description | Artifact | Status |
|---|---|---|---|---|---|
| T013 | US1 | | Create `Flow-01-Batch-PDF-Splitter` — blank canvas; leave disabled | `Power Automate > Flows > Flow-01-Batch-PDF-Splitter` | [ ] |
| T014 | US1 | | Configure SharePoint trigger (`Batches/Incoming/`) + `Get file content` action | `Power Automate > Flow-01 > Trigger` | [ ] |
| T015 | US1 | | Muhimbi `Get PDF Properties` → initialize `varPageCount`, `varFileSize`, `varFileName` variables | `Power Automate > Flow-01 > Step 1` | [ ] |
| T016 | US1 | [P] | Validation: file extension check (.pdf only) | `Power Automate > Flow-01 > Step 2a` | [ ] |
| T017 | US1 | [P] | Validation: file size ≤ 150MB (157,286,400 bytes) | `Power Automate > Flow-01 > Step 2b` | [ ] |
| T018 | US1 | | Validation: page count = 2 → Mode 1 bypass (Move to `FormIntake/` + Terminate; no BatchSubmission) | `Power Automate > Flow-01 > Step 2c` | [ ] |
| T019 | US1 | | Validation: odd page count → set varValidationFailReason | `Power Automate > Flow-01 > Step 2d` | [ ] |
| T020 | US1 | | Validation: max batch ≤ 250 forms (`div(varPageCount,2) ≤ 250`) | `Power Automate > Flow-01 > Step 2e` | [ ] |
| T021 | US1 | | Duplicate detection: Dataverse `List rows` on BatchSubmission (FileName + Size + PageCount filter) | `Power Automate > Flow-01 > Step 2f` | [ ] |
| T022 | US1 | | Validation failure handler: create ValidationFailed BatchSubmission + Notification-Router + Audit-Event-Logger + Terminate | `Power Automate > Flow-01 > Step 2 Error Handler` | [ ] |
| T023 | US1 | | Success audit log: `ActionType = BatchValidation, Result = Success` | `Power Automate > Flow-01 > Step 2 Success` | [ ] |

### Phase 3 Checklist

- [ ] **T013** — Flow created; visible in flows list; status = Off (disabled)
- [ ] **T014** — Trigger configured for `FormIntake/Batches/Incoming` folder only; `Get file content` action returns binary PDF
- [ ] **T015** — Muhimbi returns `pageCount` integer; variables initialized: `varPageCount`, `varFileSize`, `varFileName`, `varUploadedBy`, `varValidationFailReason = ""`, array/index variables
- [ ] **T016** — [P] Extension check: `.pdf` passes; `.xlsx` sets varValidationFailReason
- [ ] **T017** — [P] Size check: ≤150MB passes; >150MB sets varValidationFailReason with actual byte count
- [ ] **T018** — 2-page PDF: moved to `FormIntake/` root; flow Terminates Succeeded; no BatchSubmission created
- [ ] **T019** — 5-page PDF: varValidationFailReason set with "Odd page count (5 pages)"
- [ ] **T020** — Batch > 250 forms: varValidationFailReason set with form count
- [ ] **T021** — Dataverse query returns matching in-progress batch; varValidationFailReason set with original BatchDisplayID
- [ ] **T022** — ValidationFailed: BatchSubmission record created with correct status and error details; notification sent to uploader; audit log written; flow terminates
- [ ] **T023** — Validation success path: audit log entry created before batch record creation

**⛔ Phase 3 Checkpoint**: 
`[ ]` 2-page upload → Mode 1 bypass  
`[ ]` 6-page upload → validation passes  
`[ ]` 5-page upload → ValidationFailed + notification  
`[ ]` >150MB upload → ValidationFailed with size message  
→ **Phase 4 may begin**

---

## Phase 4: US2 — PDF Splitting into Individual Forms (P1 MVP)

**Goal**: Extend Flow-01 with batch record creation, split loop, error handling, original retention.  
📋 **Reference**: [FLOW-01-RUNBOOK.md](FLOW-01-RUNBOOK.md) Parts 8–14

| Task | Story | [P] | Description | Artifact | Status |
|---|---|---|---|---|---|
| T024 | US2 | | Step 3: Create `BatchSubmission` record (BatchStatus=Splitting; all metadata; store varBatchID, varBatchDisplayID) | `Power Automate > Flow-01 > Step 3` | [ ] |
| T025 | US2 | | Step 4a: Create SharePoint batch subfolder `Batches/{BatchDisplayID}/` | `Power Automate > Flow-01 > Step 4a` | [ ] |
| T026 | US2 | | Step 4b: Initialize split loop variables (varFormIndex=1, varLastSuccessfulIndex=0, varSplitFilePaths=[]) | `Power Automate > Flow-01 > Step 4b` | [ ] |
| T027 | US2 | | Step 4c: Split loop — `Do Until varFormIndex > TotalFormCount`; Muhimbi Split PDF; SharePoint Create file; append to varSplitFilePaths; increment index | `Power Automate > Flow-01 > Step 4c` | [ ] |
| T028 | US2 | | Step 4d: Split loop error handler — SplitFailed status; Notification-Router; Audit-Event-Logger; Terminate (preserve partial files) | `Power Automate > Flow-01 > Step 4d` | [ ] |
| T029 | US2 | | Step 4e: Update BatchSubmission → SplittingComplete + SplitEndTimestamp + BatchSplitComplete audit log | `Power Automate > Flow-01 > Step 4e` | [ ] |
| T030 | US2 | | Step 5: Move original to `Batches/{BatchDisplayID}/_original_{FileName}`; update OriginalFileSharePointID | `Power Automate > Flow-01 > Step 5` | [ ] |
| T031 | US2 | | Inside split loop: `BatchFormDeposit` audit log per form (SC-005: 100% operations logged) | `Power Automate > Flow-01 > Step 4c (inner)` | [ ] |

### Phase 4 Checklist

- [ ] **T024** — BatchSubmission created with BatchDisplayID format `BATCH-YYYYMMDD-NNN`; varBatchID populated; BatchStatus = Splitting; BatchUpload audit logged
- [ ] **T025** — SharePoint folder `FormIntake/Batches/{BatchDisplayID}/` created; varBatchFolderPath set; BatchSubmission.SharePointBatchFolderPath updated
- [ ] **T026** — Split loop variables initialized; BatchSplitStart audit logged with form count
- [ ] **T027** — Split loop produces correct files: `{BatchDisplayID}-001.pdf`, `002.pdf`, ..., `{N}.pdf`; each file = 2 pages; page ranges correct; all files in batch subfolder
- [ ] **T028** — Split failure: partial files preserved in batch subfolder; BatchStatus = SplitFailed; LastSuccessfulSplitIndex updated; supervisor + uploader notified; flow terminates (not crashes)
- [ ] **T029** — BatchStatus = SplittingComplete after successful loop; SplitEndTimestamp set; BatchSplitComplete audit logged
- [ ] **T030** — Original file moved to `_original_{FileName}` in batch subfolder; OriginalFileSharePointID updated on BatchSubmission
- [ ] **T031** — AuditLog entry per form: ActionType = BatchFormDeposit; EntityID = varBatchID; Details includes form index and filename

**⛔ Phase 4 Checkpoint**:  
`[ ]` 10-page upload → 5 split PDFs in batch subfolder (each 2 pages)  
`[ ]` Original retained as `_original_*.pdf`  
`[ ]` BatchStatus = SplittingComplete  
`[ ]` Simulated mid-split failure → partial files preserved → SplitFailed status  
→ **Phase 5 may begin**

---

## Phase 5: US3 — Feeding Split Forms to Existing Pipeline (P1 MVP)

**Goal**: Complete Flow-01 feeding loop; modify VA-Form-Intake-Pipeline (Flow 1) with conditional batch metadata enrichment.  
📋 **Reference**: [FLOW-01-RUNBOOK.md](FLOW-01-RUNBOOK.md) Parts 15–16; [FLOW-1-MODIFICATION.md](FLOW-1-MODIFICATION.md)  
> ⚠️ **T034–T037**: Modify existing live flow. Export backup FIRST.

| Task | Story | [P] | Description | Artifact | Status |
|---|---|---|---|---|---|
| T032 | US3 | | Step 6: Feeding loop — `Apply to each` over varSplitFilePaths; Move each to `FormIntake/` root; 5-second Delay between each | `Power Automate > Flow-01 > Step 6` | [ ] |
| T033 | US3 | | Inside feeding loop: `BatchFormDeposit` audit log per fed form | `Power Automate > Flow-01 > Step 6 (inner)` | [ ] |
| T034 | US3 | | ⚠️ MODIFY FLOW — Open `VA-Form-Intake-Pipeline`; export `.zip` backup; screenshot last step | `Power Automate > VA-Form-Intake-Pipeline` | [ ] |
| T035 | US3 | | ⚠️ MODIFY FLOW — Add `Condition`: `startsWith(filename, 'BATCH-')` as final step; True/False branches | `Power Automate > VA-Form-Intake-Pipeline > Last Step` | [ ] |
| T036 | US3 | | ⚠️ MODIFY FLOW — True branch: parse BatchDisplayID + FormIndex; Dataverse List rows to look up BatchSubmission | `Power Automate > VA-Form-Intake-Pipeline > Batch True Branch` | [ ] |
| T037 | US3 | | ⚠️ MODIFY FLOW — True branch: `Dataverse > Update a row` on FormSubmission: set BatchID + FormIndexInBatch; save + publish | `Power Automate > VA-Form-Intake-Pipeline > Batch True Branch` | [ ] |
| T038 | US3 | | Regression test: 1 single-form PDF to `FormIntake/` root → FormSubmission.BatchID = null; full pipeline runs normally | `SharePoint > FormIntake > vafe_TestForm001.pdf` | [ ] |

### Phase 5 Checklist

- [ ] **T032** — Feeding loop moves each split PDF from batch subfolder to `FormIntake/` root; 5-second delay between each move; BatchStatus updated to Feeding; then SplittingComplete after all moved
- [ ] **T033** — AuditLog entry per fed form inside feeding loop
- [ ] **T034** — ⚠️ Backup `.zip` downloaded and saved; last step of Flow 1 identified and screenshotted; edit mode open
- [ ] **T035** — ⚠️ New `Condition` added as **last step** only; does not wrap existing steps; False branch = empty
- [ ] **T036** — ⚠️ True branch: `Parse_BatchDisplayID` and `Parse_FormIndex` Compose actions work correctly for `BATCH-20260518-042-007.pdf` → `BATCH-20260518-042` and `7`
- [ ] **T037** — ⚠️ FormSubmission updated with BatchID (GUID lookup) and FormIndexInBatch (integer); flow saved and published
- [ ] **T038** — **MODE 1 REGRESSION PASS**: single-form PDF → FormSubmission.BatchID = null, FormIndexInBatch = null; Flow 2, 3, 4 run normally; no batch-related errors

**⛔ Phase 5 Gate**:  
`[ ]` 6-page batch → 3 FormSubmission records with BatchID + FormIndexInBatch set  
`[ ]` Mode 1 single-form regression test passes (T038)  
`[ ]` No errors in modified Flow 1 run history  
→ **MVP COMPLETE — Phases 1–5 done. Run T057, T058, T059, T064 before Phase 6.**

---

## Phase 6: US4 — Batch Tracking & Status Visibility (P2)

**Goal**: Build `Flow-01B-Batch-Status-Updater` and `Flow-01C-Stale-Batch-Monitor`.  
📋 **Reference**: [FLOW-01B-RUNBOOK.md](FLOW-01B-RUNBOOK.md); [FLOW-01C-RUNBOOK.md](FLOW-01C-RUNBOOK.md)

| Task | Story | [P] | Description | Artifact | Status |
|---|---|---|---|---|---|
| T039 | US4 | | Create `Flow-01B-Batch-Status-Updater` — blank canvas; leave disabled | `Power Automate > Flows > Flow-01B-Batch-Status-Updater` | [ ] |
| T040 | US4 | | Dataverse trigger: `FormSubmission` modified; column filter = Status + BatchID; OData filter = `BatchID ne null` | `Power Automate > Flow-01B > Trigger` | [ ] |
| T041 | US4 | | Step 1: Dataverse `List rows` — all FormSubmission with same BatchID (sibling forms) | `Power Automate > Flow-01B > Step 1` | [ ] |
| T042 | US4 | | Step 2: Compute FormsCompleted, FormsInReview, FormsFailed, FormsProcessing via `filter()` expressions | `Power Automate > Flow-01B > Step 2` | [ ] |
| T043 | US4 | | Step 3: `Dataverse > Update a row` on BatchSubmission — counters + CompletionPercentage + LastProgressTimestamp; BatchStatusUpdate audit log | `Power Automate > Flow-01B > Step 3` | [ ] |
| T044 | US4 | | Step 4: Terminal state detection — Complete vs. PartiallyFailed; CompletionTimestamp; BatchComplete audit log; completion notification | `Power Automate > Flow-01B > Step 4` | [ ] |
| T045 | US4 | | Concurrency guard: flow concurrency = 1 in settings; Do Until retry (3 attempts, 2-second backoff) for 409 Conflict on update | `Power Automate > Flow-01B > Settings + Update Row` | [ ] |
| T046 | US4 | | Enable `Flow-01B` + verify counters update within 30 seconds per SC-003 | `Power Automate > Flow-01B` | [ ] |
| T047 | US4 | | Create `Flow-01C-Stale-Batch-Monitor` — scheduled every 1 hour | `Power Automate > Flows > Flow-01C-Stale-Batch-Monitor` | [ ] |
| T048 | US4 | | Stale batch query: `LastProgressTimestamp < now-24h` AND non-terminal BatchStatus | `Power Automate > Flow-01C > Step 1` | [ ] |
| T049 | US4 | | Stale batch alert loop: `Notification-Router` + `StaleBatchAlert` audit log per stale batch | `Power Automate > Flow-01C > Step 2` | [ ] |

### Phase 6 Checklist

- [ ] **T039** — Flow-01B created; visible in flows list; status = Off
- [ ] **T040** — Trigger configured: FormSubmission modified; column filter includes `cr_batchid`; OData filter `_cr_batchid_value ne null`; verified Mode 1 forms do not trigger
- [ ] **T041** — List rows returns all sibling forms; varTotalFormCount correctly populated
- [ ] **T042** — All 4 counter variables computed correctly; status labels match FormSubmission statuscode option set values
- [ ] **T043** — BatchSubmission counters update; CompletionPercentage correct (use float division); LastProgressTimestamp = utcNow(); BatchStatusUpdate audit logged
- [ ] **T044** — Terminal detection works: when all forms done → Complete (0 failed) or PartiallyFailed (some failed); CompletionTimestamp set; notification sent
- [ ] **T045** — Flow concurrency = 1; Do Until retry wraps the Update a row; 2-second delay between retries; max 3 attempts
- [ ] **T046** — Flow-01B enabled; test batch of 3 forms: FormsCompleted increments within 30 seconds as each form completes; BatchStatus = Complete when all 3 done (SC-003)
- [ ] **T047** — Flow-01C created as scheduled flow; recurrence = 1 hour; verified in flows list
- [ ] **T048** — Stale batch OData filter correct: LastProgressTimestamp < 24h ago AND excludes Complete/PartiallyFailed/ValidationFailed
- [ ] **T049** — Alert loop: supervisor notification includes BatchDisplayID, status, and last activity; StaleBatchAlert audit log entry created per stale batch

**⛔ Phase 6 Checkpoint**:  
`[ ]` Batch tracking updates in near-real-time (SC-003 ≤ 30s)  
`[ ]` Terminal state detected → completion notification sent  
`[ ]` Stale batch test triggers alert within 1 hourly run  
→ **Phase 7 may begin**

---

## Phase 7: US5 — Batch-Level Reporting & Audit (P3)

**Goal**: Extend existing Power BI Extraction-Dashboard with batch metrics.

| Task | Story | [P] | Description | Artifact | Status |
|---|---|---|---|---|---|
| T050 | US5 | | Identify Power BI dataset; verify BatchSubmission Dataverse read access for service account | `Power BI Service > Extraction-Dashboard > Dataset Settings` | [ ] |
| T051 | US5 | | Add `BatchSubmission` to Power BI dataset; define 1:N relationship to `FormSubmission` | `Power BI Desktop > Transform Data` | [ ] |
| T052 | US5 | [P] | DAX measure: `BatchesPerDay` + Card/Line visual | `Power BI Desktop > Extraction-Dashboard > Batch Metrics Page` | [ ] |
| T053 | US5 | [P] | DAX measure: `AvgFormsPerBatch` + Card visual | `Power BI Desktop > Extraction-Dashboard > Batch Metrics Page` | [ ] |
| T054 | US5 | [P] | DAX measure: `AvgBatchCompletionMins` + Card visual | `Power BI Desktop > Extraction-Dashboard > Batch Metrics Page` | [ ] |
| T055 | US5 | [P] | DAX measure: `BatchErrorRate` + Gauge visual (formatted as percentage) | `Power BI Desktop > Extraction-Dashboard > Batch Metrics Page` | [ ] |
| T056 | US5 | | Batch Detail drill-through page: lifecycle timeline + child form table + batch status badge | `Power BI Desktop > Extraction-Dashboard > Batch Detail Page` | [ ] |

### Phase 7 Checklist

- [ ] **T050** — Power BI service account has Dataverse read access to BatchSubmission; existing dashboard connection confirmed
- [ ] **T051** — BatchSubmission table visible in Power BI data model; relationship to FormSubmission on BatchID (1:N); refresh shows actual batch data
- [ ] **T052** — [P] BatchesPerDay measure working; visual displays correct count
- [ ] **T053** — [P] AvgFormsPerBatch measure working; visual displays correct average
- [ ] **T054** — [P] AvgBatchCompletionMins measure working; only includes batches with CompletionTimestamp set
- [ ] **T055** — [P] BatchErrorRate measure working; shows percentage of ValidationFailed + PartiallyFailed batches
- [ ] **T056** — Drill-through page created; lifecycle timeline shows all 4 timestamps; child form table shows FormIndex + Status + ExtractionConfidence; supervisor can identify failed forms within 1 minute (SC-007)

---

## Phase 8: End-to-End Testing

**Goal**: Validate all 8 E2E scenarios. All 3 new flows must be enabled.  
📋 **Reference**: [TEST-SCENARIOS.md](TEST-SCENARIOS.md)

| Task | [P] | Test Description | Input | Pass Criteria |
|---|---|---|---|---|
| T057 | | Single-form bypass via `Batches/Incoming/` | 2-page PDF | Routed to Mode 1; no BatchSubmission; FormSubmission.BatchID = null |
| T058 | | Small batch (6 pages = 3 forms) | 6-page PDF | 3 split PDFs; 3 FormSubmission records with BatchID; BatchStatus = Complete |
| T059 | | Odd-page rejection (5 pages) | 5-page PDF | ValidationFailed + notification; no split PDFs |
| T060 | | Oversized batch rejection (>250 forms) | >500-page PDF or lowered limit simulation | ValidationFailed with form count message |
| T061 | | Duplicate batch detection | Same 6-page PDF twice | Second upload: ValidationFailed "Duplicate batch detected" |
| T062 | | Large batch performance (20 forms, 40 pages) | 40-page PDF | Split + feed ≤ 2 minutes per SC-001; all 20 forms with correct FormIndexInBatch |
| T063 | | Stale batch alert simulation | Manually aged BatchSubmission record | Alert sent to supervisor; StaleBatchAlert audit log entry |
| T064 | | Mode 1 regression (5 single-form PDFs) | 5 direct FormIntake/ uploads | All 5: BatchID = null; full pipeline runs; Flow-01B NOT triggered |

### Phase 8 Checklist

- [ ] **T057** — Single-form bypass: file moved to `FormIntake/`; no BatchSubmission; FormSubmission.BatchID = null; Flow 1 runs normally
- [ ] **T058** — Small batch: 3 split PDFs; 3 FormSubmission records with BatchID + FormIndexInBatch = 1,2,3; BatchStatus = Complete; counters updated in real-time; all AuditLog entries present
- [ ] **T059** — Odd page: ValidationFailed; "Odd page count (5 pages)" in ErrorDetails; uploader notified; no split PDFs created
- [ ] **T060** — Oversized: ValidationFailed with form count limit message; no split PDFs
- [ ] **T061** — Duplicate: second upload rejected; original BatchDisplayID referenced in rejection; no duplicate PDFs
- [ ] **T062** — Large batch: **elapsed time ≤ 120 seconds** (SC-001); all 20 FormSubmission records with FormIndexInBatch 1–20; no throttling errors
- [ ] **T063** — Stale alert: supervisor notification received; StaleBatchAlert in AuditLog; non-terminal filter correct (terminal batches excluded)
- [ ] **T064** — Mode 1 regression: 5 single forms; BatchID = null on all; extraction pipeline runs normally; Flow-01B NOT triggered for any

**SC Verification:**

| Success Criterion | Test | Pass |
|---|---|---|
| SC-001: 20-form batch ≤ 2 min | T062 — record elapsed time: ______s | [ ] |
| SC-002: No extraction accuracy degradation | T058 — compare extraction result with direct upload | [ ] |
| SC-003: Status updates within 30 seconds | T058 — time FormsCompleted increment: ______s | [ ] |
| SC-005: 100% audit logging | T058 — verify all 9 AuditLog ActionTypes present | [ ] |
| SC-006: Stale alert within 1 hour | T063 — alert received at: ______ | [ ] |
| SC-007: Failed forms identifiable < 1 min | T058 — batch detail view; FormIndexInBatch visible | [ ] |
| SC-008: Duplicates rejected before splitting | T061 — no duplicate split PDFs created | [ ] |

---

## Phase 9: Polish & Cross-Cutting Concerns

| Task | [P] | Description | Artifact | Status |
|---|---|---|---|---|
| T065 | | Verify all 9 AuditLog ActionType values emitted end-to-end after T058 + T064 | `Dataverse > Tables > AuditLog` | [ ] |
| T066 | | Update `Batches/Incoming/` SharePoint folder permissions (VA staff: upload; service account: full; batch subfolders: read-only for staff) | `SharePoint > FormIntake > Batches/Incoming/ > Permissions` | [ ] |
| T067 | | Create `SplitFailed` operator recovery runbook | `specs/004-multi-form-pdf-splitter/runbook-split-failed.md` | [x] |
| T068 | [P] | Review Flow run history for all 3 new flows; set up failure alerts (Power Automate Monitor > Alerts) | `Power Automate > Monitor > Alerts` | [ ] |
| T069 | [P] | Performance verification: confirm 20-form batch ≤ 2 min from T062 data (SC-001) | `Dataverse > BatchSubmission > SplittingComplete timestamp` | [ ] |
| T070 | [P] | Export all new flows as Power Platform solution package (.zip); store in SharePoint | `Power Platform Maker Portal > Solutions` | [ ] |

### Phase 9 Checklist

- [ ] **T065** — AuditLog query confirms all 9 ActionType values: BatchUpload, BatchValidation, BatchSplitStart, BatchSplitComplete, BatchSplitFailed, BatchFormDeposit, BatchStatusUpdate, BatchComplete, StaleBatchAlert
- [ ] **T066** — Permissions documented and applied; VA staff can upload to Incoming; cannot write to batch subfolders; service account has full access
- [x] **T067** — Recovery runbook written: how to identify stale split, options for retry vs. re-upload, how to update RetryPending status
- [ ] **T068** — [P] Flow run failure alerts configured for all 3 new flows; run history reviewed; no unexpected errors
- [ ] **T069** — [P] SC-001 documented: elapsed time = ____s for 20-form batch; pass/fail recorded
- [ ] **T070** — [P] Solution package exported; .zip stored in SharePoint team documents; location documented in quickstart.md

---

## Overall Progress Summary

| Phase | Tasks | Completed | % |
|---|---|---|---|
| Phase 1: Setup | 5 | 0 | 0% |
| Phase 2: Schema | 7 | 0 | 0% |
| Phase 3: US1 Detection | 11 | 0 | 0% |
| Phase 4: US2 Splitting | 8 | 0 | 0% |
| Phase 5: US3 Feeding | 7 | 0 | 0% |
| Phase 6: US4 Tracking | 11 | 0 | 0% |
| Phase 7: US5 Reporting | 7 | 0 | 0% |
| Phase 8: Testing | 8 | 0 | 0% |
| Phase 9: Polish | 6 | 1 | 17% |
| **TOTAL** | **70** | **1** | **1%** |

---

## Implementation Artifacts Index

| Artifact | Description | Status |
|---|---|---|
| [DATAVERSE-SCHEMA.md](DATAVERSE-SCHEMA.md) | Complete BatchSubmission schema + FormSubmission extensions (T006–T012) | ✅ Generated |
| [FLOW-01-RUNBOOK.md](FLOW-01-RUNBOOK.md) | Step-by-step build guide for Flow-01-Batch-PDF-Splitter (T013–T033) | ✅ Generated |
| [FLOW-01B-RUNBOOK.md](FLOW-01B-RUNBOOK.md) | Build guide for Flow-01B-Batch-Status-Updater (T039–T046) | ✅ Generated |
| [FLOW-01C-RUNBOOK.md](FLOW-01C-RUNBOOK.md) | Build guide for Flow-01C-Stale-Batch-Monitor (T047–T049) | ✅ Generated |
| [FLOW-1-MODIFICATION.md](FLOW-1-MODIFICATION.md) | Modification instructions for VA-Form-Intake-Pipeline (T034–T038) | ✅ Generated |
| [EXPRESSION-REFERENCE.md](EXPRESSION-REFERENCE.md) | All Power Automate expressions + DAX measures used across all flows | ✅ Generated |
| [TEST-SCENARIOS.md](TEST-SCENARIOS.md) | All 8 E2E test scenarios (T057–T064) with exact steps and pass criteria | ✅ Generated |
| [IMPLEMENTATION-CHECKLIST.md](IMPLEMENTATION-CHECKLIST.md) | This file — master checklist of all 70 tasks | ✅ Generated |

---

**Version**: 1.0.0 | **Generated**: 2025-07-17  
**Branch**: 004-multi-form-pdf-splitter  
**Status**: Implementation artifacts generated — ready for manual Power Platform implementation


