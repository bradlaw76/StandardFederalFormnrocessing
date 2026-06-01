---
description: "Implementation tasks for Mode 2: Multi-Form PDF Splitter"
feature: "004-multi-form-pdf-splitter"
branch: "004-multi-form-pdf-splitter"
generated: "2025-07-17"
status: "Implementation Artifacts Generated"
implementation_generated: "2025-07-17"
implementation_artifacts:
  - specs/004-multi-form-pdf-splitter/implementation/FLOW-01-RUNBOOK.md
  - specs/004-multi-form-pdf-splitter/implementation/FLOW-01B-RUNBOOK.md
  - specs/004-multi-form-pdf-splitter/implementation/FLOW-01C-RUNBOOK.md
  - specs/004-multi-form-pdf-splitter/implementation/FLOW-1-MODIFICATION.md
  - specs/004-multi-form-pdf-splitter/implementation/DATAVERSE-SCHEMA.md
  - specs/004-multi-form-pdf-splitter/implementation/EXPRESSION-REFERENCE.md
  - specs/004-multi-form-pdf-splitter/implementation/TEST-SCENARIOS.md
  - specs/004-multi-form-pdf-splitter/implementation/IMPLEMENTATION-CHECKLIST.md
---

# Tasks: Mode 2 — Multi-Form PDF Splitter

> **📋 Implementation Artifacts Generated**: All 8 implementation runbooks, schema documents, expression references, and test scenarios have been generated in `specs/004-multi-form-pdf-splitter/implementation/`. See [IMPLEMENTATION-CHECKLIST.md](implementation/IMPLEMENTATION-CHECKLIST.md) for the master task tracker with all 70 tasks and progress tracking checkboxes.

**Input**: Design documents from `specs/004-multi-form-pdf-splitter/`  
**Platform**: Microsoft Power Platform (Power Automate · Dataverse · SharePoint · Power BI)  
**PDF Splitting**: Azure Function (HTTP) — see [FLOW-01-AZURE-FUNCTION-RUNBOOK.md](implementation/FLOW-01-AZURE-FUNCTION-RUNBOOK.md)  
**Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md) | **Data Model**: [data-model.md](data-model.md)  
**Estimated total effort**: 14–18 hours (1 person, 2–3 days)

> **Tests**: Test tasks are included in a dedicated Phase 8.  
> **⚠️ MODIFY EXISTING FLOW**: Tasks that touch the existing `VA-Form-Intake-Pipeline` (Flow 1) are clearly marked and must be handled with extra care — Mode 1 single-form processing must remain unaffected.

---

## Format: `[ID] [P?] [Story?] Description → Artifact`

- **[P]**: Can be executed in parallel with other [P]-tagged tasks in the same phase
- **[Story]**: Maps to user story from spec.md (US1–US5)
- **Artifact path** replaces file path for Power Platform: `PowerAutomate > Flows > {FlowName}`, `Dataverse > Tables > {TableName}`, `SharePoint > FormIntake > {Path}`

---

## Phase 1: Setup (Environment & Prerequisites)

**Purpose**: Validate the environment and confirm the Azure Function is deployed and reachable. The Azure Function integrates into the **existing** SharePoint/Flow 1 structure — no new SharePoint folders required.

**⚠️ CRITICAL**: All tasks in this phase are sequential prerequisites. Do not begin Phase 2 (Dataverse schema) until T005 is verified complete.

| Task | Title | Effort | Dependencies | Acceptance Criteria |
|------|-------|--------|--------------|---------------------|
| T001 | Verify existing pipeline is operational | 15 min | None | **✅ DONE** — All 5 flows confirmed On: MVP-01-SharePoint-To-D365-Intake, MVP-02-D365-Write-Subflow, MVP-03-Audit-Logger-Subflow, MVP-04-D365-Retry, MVP-05-AI-Extraction-Subflow (VAFormExtractionDemo solution, owner: Bradley Law). |
| T002 | Deploy Azure Function app for PDF splitting | 45 min | T001 | **✅ DONE** — `va-pdf-splitter-dev` deployed (Flex Consumption, eastus2). Both endpoints (`/api/pdf/page-count`, `/api/pdf/split`) live. |
| T003 | Smoke-test Azure Function endpoints and document URL + key | 20 min | T002 | **✅ DONE** — Endpoints confirmed live. `AzureFunctionBaseUrl` and `AzureFunctionKey` recorded in `quickstart.md`. |
| T004 | Create SharePoint folder structure for batch intake | 15 min | T001 | In SharePoint → `FormIntake` document library: (1) Create folder `Batches/`. (2) Create subfolder `Batches/Incoming/`. Verify `FormIntake/` root is still the only folder that triggers existing Flow 1 — confirm `Batches/` and `Batches/Incoming/` do NOT trigger Flow 1. |
| T005 | Document environment variable values for Flow-01 | 15 min | T003 | Create a reference note (in the Power Automate solution or a team wiki) capturing: `AzureFunctionBaseUrl`, `AzureFunctionKey`, SharePoint site URL, `FormIntake` library internal name, `Batches/Incoming/` folder path. These values will be used in every flow built in Phases 3–6. |

### Checklist — Phase 1

- [x] T001 Verify existing pipeline is operational → All 5 flows confirmed **On**: MVP-01-SharePoint-To-D365-Intake, MVP-02-D365-Write-Subflow, MVP-03-Audit-Logger-Subflow, MVP-04-D365-Retry, MVP-05-AI-Extraction-Subflow
- [x] T002 Deploy Azure Function app for PDF splitting → `va-pdf-splitter-dev` live at `https://va-pdf-splitter-dev.azurewebsites.net`
- [x] T003 Smoke-test Azure Function and document URL + key → both endpoints confirmed; values in `quickstart.md`
- [x] ~~T004~~ SKIPPED — No SharePoint folder changes needed; Azure Function is additive to existing flow
- [x] T005 Document environment variable values → `quickstart.md` updated with AzureFunctionBaseUrl + AzureFunctionKey

**✅ Phase 1 COMPLETE** — All tasks done. Azure Function live, all 5 flows On. → **Phase 2 may begin.**

---

## Phase 2: Foundational — Dataverse Schema (Blocking Prerequisites)

**Purpose**: Create the `BatchSubmission` Dataverse table and extend `FormSubmission` with two new nullable columns. All three new flows depend on this schema. **No flow building until this phase is complete.**

**⚠️ CRITICAL**: `FormSubmission` schema changes require careful publishing — verify existing records are unaffected before proceeding to flow building.

| Task | Title | Effort | Dependencies | Acceptance Criteria |
|------|-------|--------|--------------|---------------------|
| T006 | Create `BatchSubmission` Dataverse table — base structure | 20 min | T001 | In `Power Platform Maker Portal > Dataverse > Tables > + New table`: Name = `BatchSubmission`, Display Name = `Batch Submission`. Primary column type = Text, name = `BatchDisplayID`, format = "BATCH-YYYYMMDD-NNN". Table saved and visible in Dataverse. |
| T007 | Add core metadata columns to `BatchSubmission` table | 30 min | T006 | Add all columns per `data-model.md §1`: `SourceFileName` (Text 255), `SourceFileSizeBytes` (Whole Number), `SourceFilePageCount` (Whole Number), `SourceFileHash` (Text 64, nullable), `TotalFormCount` (Whole Number), `UploadedBy` (Lookup to User), `UploadTimestamp` (DateTime, required). All columns visible on the table form. |
| T008 | Add `BatchStatus` Option Set with 10-state values | 20 min | T006 | Create a new Option Set (Global or local to table): Values = `Uploaded`, `Validating`, `ValidationFailed`, `Splitting`, `SplitFailed`, `RetryPending`, `SplittingComplete`, `Feeding`, `Complete`, `PartiallyFailed`. Add `BatchStatus` column (Option Set type) to `BatchSubmission` table with default = `Uploaded`. |
| T009 | Add counter and timestamp columns to `BatchSubmission` table | 20 min | T006 | Add: `FormsCompleted` (Whole Number, default 0), `FormsInReview` (Whole Number, default 0), `FormsFailed` (Whole Number, default 0), `FormsProcessing` (Whole Number, default 0), `CompletionPercentage` (Decimal, 0–100), `SplitStartTimestamp` (DateTime, nullable), `SplitEndTimestamp` (DateTime, nullable), `CompletionTimestamp` (DateTime, nullable), `LastProgressTimestamp` (DateTime). |
| T010 | Add operational columns to `BatchSubmission` table | 15 min | T006 | Add: `ErrorDetails` (Multiline Text, 4000 chars), `LastSuccessfulSplitIndex` (Whole Number, nullable), `SharePointBatchFolderPath` (Text 500), `OriginalFileSharePointID` (Text 255). Table has all 20+ columns per `data-model.md §1`. |
| T011 | Add `BatchID` lookup column to `FormSubmission` table | 15 min | T006 | In `Dataverse > Tables > FormSubmission > Columns > + Add column`: Name = `BatchID`, Type = Lookup, Related table = `BatchSubmission`. **Nullable** — no existing records should be affected. Publish FormSubmission table. Verify existing FormSubmission records still show correctly in all views. |
| T012 | Add `FormIndexInBatch` column to `FormSubmission` table | 10 min | T011 | Add column to `FormSubmission`: Name = `FormIndexInBatch`, Type = Whole Number, **Nullable**. Publish table. Verify: (a) Existing FormSubmission records have NULL for both new columns. (b) Flow 1, Flow 2, Flow 3, Flow 4 still run without error on a test single-form PDF. |

### Checklist — Phase 2

- [X] T006 Create `BatchSubmission` Dataverse table — base structure → `Dataverse > Tables > BatchSubmission`
- [X] T007 [P] Add core metadata columns to `BatchSubmission` table → `Dataverse > Tables > BatchSubmission > Columns`
- [X] T008 [P] Add `BatchStatus` Option Set with 10-state values → `Dataverse > Option Sets > BatchStatus`
- [X] T009 [P] Add counter and timestamp columns to `BatchSubmission` table → `Dataverse > Tables > BatchSubmission > Columns`
- [X] T010 [P] Add operational columns to `BatchSubmission` table → `Dataverse > Tables > BatchSubmission > Columns`
- [X] T011 Add `BatchID` lookup column to `FormSubmission` table → `Dataverse > Tables > FormSubmission > Columns`
- [X] T012 Add `FormIndexInBatch` column to `FormSubmission` table → `Dataverse > Tables > FormSubmission > Columns`

**Checkpoint**: Both Dataverse schema changes published. Existing Mode 1 flow run succeeds on a test PDF without errors. Phase 3 user story implementation may now begin.

---

## Phase 3: User Story 1 — Batch PDF Upload & Detection (Priority: P1) 🎯 MVP Start

**Goal**: Build `Flow-01-Batch-PDF-Splitter` from trigger through validation. A PDF uploaded to `Batches/Incoming/` is inspected, page count extracted via Muhimbi, and routed correctly — 2-page PDFs bypass to Mode 1, even-page batches continue, odd-page batches are rejected with notification.

**Independent Test**: Upload a 6-page PDF to `FormIntake/Batches/Incoming/` → flow triggers → Muhimbi returns page count 6 → validation passes → `BatchSubmission` record created with `BatchStatus = Splitting`. Upload a 5-page PDF → flow triggers → validation fails → `BatchStatus = ValidationFailed` → operator notified. Upload a 2-page PDF → flow moves it to `FormIntake/` root → no `BatchSubmission` record created.

| Task | Title | Effort | Dependencies | Acceptance Criteria |
|------|-------|--------|--------------|---------------------|
| T013 | Create `Flow-01-Batch-PDF-Splitter` cloud flow — blank canvas | 10 min | T005, T008, T011 | In `Power Automate > + Create > Automated cloud flow`, name = `Flow-01-Batch-PDF-Splitter`. Flow visible in Power Automate flows list. Do not enable until T022 is complete. |
| T014 | Configure SharePoint trigger for `Batches/Incoming/` folder | 15 min | T013 | Add trigger: `SharePoint > When a file is created (properties only)`. Site = {your SharePoint site}, Library = `FormIntake`, Folder = `/Batches/Incoming`. Add a `Get file content` action immediately after to load the binary PDF content. Verify trigger fires when a test file is uploaded to `Batches/Incoming/` (test with flow disabled on production). |
| T015 | Add Muhimbi `Get PDF Properties` action → extract `PageCount` | 20 min | T014 | Add action: `Muhimbi PDF > Get PDF Properties`. Input: file content from trigger. Initialize variable `varPageCount` = output `pageCount` field from Muhimbi response. Initialize variable `varFileSize` = trigger body `Size`. Initialize variable `varFileName` = trigger body `Name`. Log output: `PageCount` returns correct integer for a test PDF. |
| T016 | Add validation rule — file extension check | 10 min | T015 | Add Condition: `toLower(last(split(varFileName, '.')))` equals `pdf`. On False branch: set `varValidationFailReason = 'Invalid file type: only PDF files are accepted'`. |
| T017 | Add validation rule — file size limit (≤ 150 MB) | 10 min | T015 | Add Condition: `varFileSize` is less than or equal to `157286400` (150 × 1024 × 1024). On False branch: set `varValidationFailReason = 'File exceeds 150MB limit ({varFileSize} bytes received)'`. |
| T018 | Add validation rule — page count routing (2-page → Mode 1 bypass) | 15 min | T015 | Add Condition: `varPageCount` equals `2`. On True branch: use SharePoint `Move file` action to move the uploaded PDF from `FormIntake/Batches/Incoming/{FileName}` to `FormIntake/{FileName}`. Then `Terminate` the flow with status = Succeeded (no BatchSubmission created). This is the Mode 1 single-form bypass path. |
| T019 | Add validation rule — odd page count rejection | 10 min | T018 | After the 2-page check, Add Condition: `mod(varPageCount, 2)` is not equal to `0`. On True branch: set `varValidationFailReason = 'Odd page count ({varPageCount} pages). Manual review required — possible incomplete form scan.'`. |
| T020 | Add validation rule — max batch size (≤ 250 forms) | 10 min | T019 | Add Condition: `div(varPageCount, 2)` is less than or equal to `250`. On False branch: set `varValidationFailReason = 'Batch exceeds 250-form limit ({div(varPageCount,2)} forms detected). Split into smaller uploads.'`. |
| T021 | Add duplicate batch detection — Dataverse query | 20 min | T020 | Add `Dataverse > List rows` action on `BatchSubmission` table. Filter: `SourceFileName eq '{varFileName}' and SourceFileSizeBytes eq {varFileSize} and SourceFilePageCount eq {varPageCount} and BatchStatus ne 'Complete' and BatchStatus ne 'PartiallyFailed' and BatchStatus ne 'ValidationFailed'`. If any rows returned: set `varValidationFailReason = 'Duplicate batch detected: this file is already in progress (Batch {first(body/value)/BatchDisplayID})'`. |
| T022 | Add validation failure branch — notify + log + reject | 25 min | T016, T017, T019, T020, T021 | Consolidate all failure conditions into a single "Is Validation Failed?" check (`varValidationFailReason` is not empty). On True branch: (1) `Dataverse > Add a new row` in `BatchSubmission` with `BatchStatus = ValidationFailed`, `ErrorDetails = varValidationFailReason`, all file metadata fields. (2) Call `Notification-Router` subflow with recipient = uploader, message = `varValidationFailReason`, severity = Warning. (3) Call `Audit-Event-Logger` subflow with `ActionType = BatchValidation`, `EntityID = {new BatchID}`, `Details = {varValidationFailReason}`. (4) `Terminate` flow. On the True branch, the batch must be fully logged and the uploader must receive a notification within 60 seconds of the failure. |
| T023 | Add success audit log on validation pass | 10 min | T022 | On the validation-passed path: Call `Audit-Event-Logger` subflow with `ActionType = BatchValidation`, `Result = Success`, `PageCount = {varPageCount}`, `FormCount = {div(varPageCount,2)}`. Initialize variable `varBatchDisplayID` for use in Phase 4. |

### Checklist — Phase 3

- [ ] T013 [US1] Create `Flow-01-Batch-PDF-Splitter` cloud flow — blank canvas → `Power Automate > Flows > Flow-01-Batch-PDF-Splitter`
- [ ] T014 [US1] Configure SharePoint trigger for `Batches/Incoming/` + `Get file content` action → `Power Automate > Flow-01 > Trigger`
- [ ] T015 [US1] Add Muhimbi `Get PDF Properties` action → extract `PageCount`, `FileSize`, `FileName` variables → `Power Automate > Flow-01 > Step 1`
- [ ] T016 [P] [US1] Add validation rule — file extension check (.pdf) → `Power Automate > Flow-01 > Step 2a`
- [ ] T017 [P] [US1] Add validation rule — file size limit ≤ 150 MB → `Power Automate > Flow-01 > Step 2b`
- [ ] T018 [US1] Add validation rule — page count = 2 → Mode 1 bypass (move to `FormIntake/` root + Terminate) → `Power Automate > Flow-01 > Step 2c`
- [ ] T019 [US1] Add validation rule — odd page count → set rejection reason → `Power Automate > Flow-01 > Step 2d`
- [ ] T020 [US1] Add validation rule — max batch size ≤ 250 forms → `Power Automate > Flow-01 > Step 2e`
- [ ] T021 [US1] Add duplicate batch detection — Dataverse `List rows` query on `BatchSubmission` → `Power Automate > Flow-01 > Step 2f`
- [ ] T022 [US1] Add validation failure branch — notify via `Notification-Router` + log via `Audit-Event-Logger` + create `ValidationFailed` record + Terminate → `Power Automate > Flow-01 > Step 2 Error Handler`
- [ ] T023 [US1] Add success audit log entry (`ActionType = BatchValidation, Result = Success`) → `Power Automate > Flow-01 > Step 2 Success`

**Checkpoint**: User Story 1 independently testable. Upload 2-page PDF → Mode 1 bypass. Upload 6-page even PDF → validation passes. Upload 5-page odd PDF → `ValidationFailed` + operator notification. Upload oversized PDF → rejected with clear message.

---

## Phase 4: User Story 2 — PDF Splitting into Individual Forms (Priority: P1)

**Goal**: Extend `Flow-01-Batch-PDF-Splitter` with the batch record creation, split loop, and original file retention. After this phase, a valid multi-form PDF upload produces N individual 2-page PDFs stored in `FormIntake/Batches/{BatchDisplayID}/`.

**Independent Test**: Upload a 10-page test PDF (5 forms) to `Batches/Incoming/` → verify exactly 5 files named `BATCH-{date}-{NNN}-001.pdf` through `BATCH-{date}-{NNN}-005.pdf` exist in `FormIntake/Batches/{BatchDisplayID}/` → verify each is exactly 2 pages (re-inspect with Muhimbi or manual open) → verify `BatchSubmission.BatchStatus = SplittingComplete` → verify `_original_` file retained in batch subfolder.

| Task | Title | Effort | Dependencies | Acceptance Criteria |
|------|-------|--------|--------------|---------------------|
| T024 | Add Step 3 — Create `BatchSubmission` record in Dataverse | 20 min | T023 | Add `Dataverse > Add a new row` action on `BatchSubmission` table. Set: `BatchDisplayID = concat('BATCH-', formatDateTime(utcNow(),'yyyyMMdd'), '-', padLeft(string(rand(1,999)),3,'0'))`, `SourceFileName = varFileName`, `SourceFileSizeBytes = varFileSize`, `SourceFilePageCount = varPageCount`, `TotalFormCount = div(varPageCount,2)`, `UploadedBy = triggerOutputs()?['headers']?['x-ms-user-name']`, `UploadTimestamp = utcNow()`, `BatchStatus = Splitting`, `SplitStartTimestamp = utcNow()`, `SharePointBatchFolderPath = concat('FormIntake/Batches/', varBatchDisplayID, '/')`. Store the returned row ID in `varBatchID`. Call `Audit-Event-Logger` with `ActionType = BatchUpload`. |
| T025 | Add Step 4a — Create batch subfolder in SharePoint | 15 min | T024 | Add `SharePoint > Create new folder` action. Path = `FormIntake/Batches/{varBatchDisplayID}`. Verify: folder exists before split loop begins. Store the folder path in `varBatchFolderPath`. |
| T026 | Add Step 4b — Initialize split loop variables | 10 min | T025 | Initialize variables: `varFormIndex` = 1 (Integer), `varSplitErrors` = 0 (Integer), `varLastSuccessfulIndex` = 0 (Integer), `varSplitFilePaths` = [] (Array). Call `Audit-Event-Logger` with `ActionType = BatchSplitStart`, `EntityID = varBatchID`, `Details = concat('Splitting ', string(div(varPageCount,2)), ' forms')`. |
| T027 | Add Step 4c — Split loop: Muhimbi `Split PDF` action per form | 45 min | T026 | Add `Apply to each` / `Do until` loop iterating `varFormIndex` from 1 to `TotalFormCount`. Inside loop: (1) Calculate `varStartPage = (varFormIndex - 1) * 2 + 1` and `varEndPage = varFormIndex * 2`. (2) Add `Muhimbi PDF > Split PDF` action with Source File = (original PDF binary content), Start Page = `varStartPage`, End Page = `varEndPage`. (3) Output file name = `concat(varBatchDisplayID, '-', padLeft(string(varFormIndex), 3, '0'), '.pdf')`. (4) Add `SharePoint > Create file` action: path = `FormIntake/Batches/{varBatchDisplayID}/{outputFileName}`, content = Muhimbi split output. (5) Append output file path to `varSplitFilePaths`. (6) Update `varLastSuccessfulIndex = varFormIndex`. (7) Increment `varFormIndex`. |
| T028 | Add Step 4d — Split loop error handling (partial failure preservation) | 30 min | T027 | Wrap the split loop body in a Scope with a Configure Run After set to catch failures. On error in any split iteration: (1) `Dataverse > Update row` on `BatchSubmission`: `BatchStatus = SplitFailed`, `ErrorDetails = {error message}`, `LastSuccessfulSplitIndex = varLastSuccessfulIndex`, `SplitEndTimestamp = utcNow()`. (2) Call `Notification-Router` subflow: recipient = supervisor + uploader, message = `'Split failed at form {varLastSuccessfulIndex + 1} of {TotalFormCount}. {varLastSuccessfulIndex} forms preserved in {varBatchFolderPath}.'`, severity = Error. (3) Call `Audit-Event-Logger` with `ActionType = BatchSplitFailed`. (4) `Terminate` flow with Failed status. Files already saved to `FormIntake/Batches/{BatchDisplayID}/` are NOT deleted. |
| T029 | Add Step 4e — Update `BatchSubmission` after successful split | 15 min | T027 | After loop completes (all forms split without error): `Dataverse > Update row` on `BatchSubmission`: `BatchStatus = SplittingComplete`, `SplitEndTimestamp = utcNow()`. Call `Audit-Event-Logger` with `ActionType = BatchSplitComplete`, `Details = concat(string(TotalFormCount), ' forms split successfully')`. |
| T030 | Add Step 5 — Retain original PDF in batch subfolder | 20 min | T025 | Add `SharePoint > Move file` action: Source = `FormIntake/Batches/Incoming/{varFileName}`, Destination = `FormIntake/Batches/{varBatchDisplayID}/_original_{varFileName}`. After move: `Dataverse > Update row` on `BatchSubmission`: `OriginalFileSharePointID = {SharePoint item ID from move result}`. This ensures the original batch PDF is retained for audit and is no longer in `Incoming/`. |
| T031 | Add split loop per-form audit log entry | 15 min | T027 | Inside the split loop (after each successful `SharePoint > Create file`): Call `Audit-Event-Logger` subflow with `ActionType = BatchFormDeposit`, `EntityID = varBatchID`, `Details = concat('Form ', string(varFormIndex), ' of ', string(TotalFormCount), ' split to ', outputFileName)`. This satisfies SC-005 (100% of batch operations logged). |

### Checklist — Phase 4

- [ ] T024 [US2] Create `BatchSubmission` record in Dataverse (`BatchStatus = Splitting`, all metadata fields) → `Power Automate > Flow-01 > Step 3`
- [ ] T025 [US2] Create batch subfolder in SharePoint (`FormIntake/Batches/{BatchDisplayID}/`) → `Power Automate > Flow-01 > Step 4a`
- [ ] T026 [US2] Initialize split loop variables (`varFormIndex`, `varSplitErrors`, `varSplitFilePaths`) → `Power Automate > Flow-01 > Step 4b`
- [ ] T027 [US2] Add split loop — Muhimbi `Split PDF` per form (page range calculation + `SharePoint > Create file`) → `Power Automate > Flow-01 > Step 4c`
- [ ] T028 [US2] Add split loop error handling — partial failure preservation + `SplitFailed` status + operator notification → `Power Automate > Flow-01 > Step 4d`
- [ ] T029 [US2] Update `BatchSubmission.BatchStatus = SplittingComplete` after loop + `BatchSplitComplete` audit log → `Power Automate > Flow-01 > Step 4e`
- [ ] T030 [US2] Retain original PDF in batch subfolder (`_original_{filename}`) + update `OriginalFileSharePointID` → `Power Automate > Flow-01 > Step 5`
- [ ] T031 [US2] Add per-form `BatchFormDeposit` audit log entry inside split loop → `Power Automate > Flow-01 > Step 4c (inner)`

**Checkpoint**: User Story 2 independently testable. Upload 10-page PDF → 5 files in batch subfolder → each 2 pages → `BatchStatus = SplittingComplete` → original retained as `_original_*.pdf`. Simulate mid-split failure → partial files preserved → `BatchStatus = SplitFailed` → operator notified.

---

## Phase 5: User Story 3 — Feeding Split Forms to Existing Pipeline (Priority: P1)

**Goal**: Complete `Flow-01-Batch-PDF-Splitter` by sequentially moving split PDFs into `FormIntake/` root (triggering existing Flow 1). Then add the single conditional branch to the existing `VA-Form-Intake-Pipeline` (Flow 1) that parses batch filenames and populates `FormSubmission.BatchID` + `FormIndexInBatch`.

> ⚠️ **MODIFY EXISTING FLOW** tasks (T034–T037) touch the live `VA-Form-Intake-Pipeline`. Work in a solution copy or dev environment. Verify Mode 1 single-form processing is fully unaffected before saving changes.

**Independent Test**: Upload a 6-page batch PDF → 3 split PDFs deposited to `FormIntake/` root with 5-second delays → Flow 1 triggers on each → 3 `FormSubmission` records created → each has `BatchID` and `FormIndexInBatch` populated → each enters extraction pipeline identically to a Mode 1 upload. Then upload a standard single-form PDF directly to `FormIntake/` root → verify it processes without any batch-related logic triggering.

| Task | Title | Effort | Dependencies | Acceptance Criteria |
|------|-------|--------|--------------|---------------------|
| T032 | Add Step 6 — Pipeline feeding loop (move split PDFs to `FormIntake/` root) | 30 min | T029 | After `BatchStatus = SplittingComplete`: Update `BatchSubmission.BatchStatus = Feeding`. Add `Apply to each` over `varSplitFilePaths` array. Inside loop: (1) `SharePoint > Move file`: source = `FormIntake/Batches/{varBatchDisplayID}/{fileName}`, destination = `FormIntake/{fileName}`. (2) `Delay` action: 5 seconds (avoids overwhelming existing pipeline). Each moved file triggers existing Flow 1 via SharePoint polling. After all files moved: `Dataverse > Update row` on `BatchSubmission`: `BatchStatus = SplittingComplete` (feeding complete — pipeline now owns each form). |
| T033 | Add per-form feed audit log entry inside feeding loop | 10 min | T032 | Inside the feeding loop (after each `SharePoint > Move file`): Call `Audit-Event-Logger` with `ActionType = BatchFormDeposit`, `Details = concat(fileName, ' deposited to FormIntake/ for pipeline processing')`, `EntityID = varBatchID`. This completes the Flow 01 audit trail per SC-005. |
| T034 | ⚠️ MODIFY EXISTING FLOW — Open `VA-Form-Intake-Pipeline` (Flow 1) in edit mode | 10 min | T012, T032 | Navigate to `Power Automate > Flows > VA-Form-Intake-Pipeline > Edit`. Take a screenshot or export the flow as a backup before making any changes. Identify the final step of the existing flow (the last action before the flow ends). This is where the new conditional branch will be appended. DO NOT modify any existing steps. |
| T035 | ⚠️ MODIFY EXISTING FLOW — Add conditional branch: detect batch filename pattern | 20 min | T034 | After the existing flow's last action, add a `Condition` step: `startsWith(triggerOutputs()?['body/Name'], 'BATCH-')` equals `true`. On **True** branch: proceed to T036. On **False** branch: `Do nothing` (empty — Mode 1 path is completely unchanged). The condition must be the very last step and must not wrap or interfere with any existing steps. |
| T036 | ⚠️ MODIFY EXISTING FLOW — Parse `BatchDisplayID` and `FormIndex` from filename | 20 min | T035 | On the True branch of T035: Parse filename `BATCH-{YYYYMMDD}-{NNN}-{FormIndex}.pdf`. Use `split()` expressions: `varParsedBatchDisplayID = concat('BATCH-', split(triggerBody()/Name, '-')[1], '-', split(triggerBody()/Name, '-')[2])`. `varParsedFormIndex = int(first(split(last(split(triggerBody()/Name, '-')), '.')))`. Add `Dataverse > List rows` on `BatchSubmission` where `BatchDisplayID eq '{varParsedBatchDisplayID}'`. Store the first result's `BatchID` (GUID) in `varLookedUpBatchID`. |
| T037 | ⚠️ MODIFY EXISTING FLOW — Update `FormSubmission` with `BatchID` and `FormIndexInBatch` | 15 min | T036 | Still on the True branch: Add `Dataverse > Update a row` on `FormSubmission` (the row created earlier in Flow 1 for this file). Set: `BatchID = varLookedUpBatchID`, `FormIndexInBatch = varParsedFormIndex`. Save and publish the updated flow. Run a test: upload a BATCH-prefixed PDF → verify FormSubmission has BatchID and FormIndexInBatch set. Run Mode 1 test: upload a non-BATCH PDF → verify FormSubmission.BatchID is null and flow works exactly as before. |
| T038 | Verify Mode 1 is unaffected — regression test | 20 min | T037 | Upload a standard single-form PDF (named `vafe_TestForm001.pdf`) directly to `FormIntake/` root. Verify: (1) Flow 1 triggers. (2) FormSubmission created with `BatchID = null`, `FormIndexInBatch = null`. (3) Extraction pipeline runs normally. (4) No batch-related errors in flow run history. Document test result in team notes. |

### Checklist — Phase 5

- [ ] T032 [US3] Add feeding loop — sequentially move split PDFs from `FormIntake/Batches/{BatchDisplayID}/` to `FormIntake/` root with 5-second `Delay` between moves → `Power Automate > Flow-01 > Step 6`
- [ ] T033 [US3] Add per-form `BatchFormDeposit` audit log entry inside feeding loop → `Power Automate > Flow-01 > Step 6 (inner)`
- [ ] T034 [US3] ⚠️ MODIFY EXISTING FLOW — Open `VA-Form-Intake-Pipeline` (Flow 1), export backup → `Power Automate > Flows > VA-Form-Intake-Pipeline`
- [ ] T035 [US3] ⚠️ MODIFY EXISTING FLOW — Add terminal `Condition`: `startsWith(FileName, 'BATCH-')` → True/False branches → `Power Automate > VA-Form-Intake-Pipeline > Last Step`
- [ ] T036 [US3] ⚠️ MODIFY EXISTING FLOW — Parse `BatchDisplayID` + `FormIndex` from filename → Dataverse `List rows` to look up `BatchSubmission` → `Power Automate > VA-Form-Intake-Pipeline > Batch True Branch`
- [ ] T037 [US3] ⚠️ MODIFY EXISTING FLOW — `Dataverse > Update a row` on `FormSubmission`: set `BatchID` + `FormIndexInBatch` → Save and publish → `Power Automate > VA-Form-Intake-Pipeline > Batch True Branch`
- [ ] T038 [US3] Regression test — upload Mode 1 single-form PDF → verify `FormSubmission.BatchID = null` + full pipeline runs normally → `SharePoint > FormIntake > vafe_TestForm001.pdf`

**Checkpoint**: User Story 3 independently testable. 6-page batch upload → 3 split PDFs → 3 FormSubmission records each with BatchID set → extraction runs on each form → Mode 1 single-form upload still works identically to before.

---

## Phase 6: User Story 4 — Batch Tracking & Status Visibility (Priority: P2)

**Goal**: Build `Flow-01B-Batch-Status-Updater` (triggered on FormSubmission status change) and `Flow-01C-Stale-Batch-Monitor` (hourly scheduled). After this phase, batch counters update in near-real-time and stale batch alerts fire within 1 hour of the 24-hour threshold.

**Independent Test**: Process a batch of 5 forms → as each form's Status changes (Intake → Extracting → Complete) → verify `BatchSubmission.FormsCompleted` increments → verify `CompletionPercentage` updates → when all 5 complete → `BatchStatus = Complete` → `CompletionTimestamp` set. Verify: stale batch query correctly identifies a batch whose `LastProgressTimestamp` is > 24 hours old.

| Task | Title | Effort | Dependencies | Acceptance Criteria |
|------|-------|--------|--------------|---------------------|
| T039 | Create `Flow-01B-Batch-Status-Updater` cloud flow — blank canvas | 10 min | T012, T037 | In `Power Automate > + Create > Automated cloud flow`, name = `Flow-01B-Batch-Status-Updater`. Flow visible in flows list. Do not enable until T046 is complete. |
| T040 | Configure Dataverse trigger on `FormSubmission` row modification | 20 min | T039 | Add trigger: `Dataverse > When a row is modified`. Table = `FormSubmission`. Column filter = `Status,BatchID` (only fire when Status or BatchID column changes). Add an OData filter on trigger: `BatchID ne null`. This ensures the flow only triggers for Mode 2 batch-member forms — Mode 1 forms with `BatchID = null` never trigger this flow. |
| T041 | Add Step 1 — Query all sibling `FormSubmission` rows by `BatchID` | 15 min | T040 | Add `Dataverse > List rows` on `FormSubmission`. OData filter: `BatchID eq '{triggerOutputs()?[body/BatchID]}'`. Select columns: `FormID, Status`. Store results in `varSiblingForms`. |
| T042 | Add Step 2 — Compute status aggregate counts | 20 min | T041 | Using `filter()` expressions over `varSiblingForms`: `varFormsCompleted = length(filter(varSiblingForms, item()/Status eq 'Complete'))`. `varFormsInReview = length(filter(varSiblingForms, or(item()/Status eq 'ReviewRequired', item()/Status eq 'ManualIntake')))`. `varFormsFailed = length(filter(varSiblingForms, or(item()/Status eq 'WriteFailed', item()/Status eq 'Failed')))`. `varFormsProcessing = length(filter(varSiblingForms, or(or(item()/Status eq 'Intake', item()/Status eq 'Extracting'), or(item()/Status eq 'Auto-Approved', item()/Status eq 'D365Writing'))))`. |
| T043 | Add Step 3 — Update `BatchSubmission` counters and timestamp | 15 min | T042 | Add `Dataverse > Update a row` on `BatchSubmission`. Row ID = `{triggerOutputs()?[body/BatchID/BatchID]}`. Set: `FormsCompleted = varFormsCompleted`, `FormsInReview = varFormsInReview`, `FormsFailed = varFormsFailed`, `FormsProcessing = varFormsProcessing`, `CompletionPercentage = div(mul(varFormsCompleted, 100), {BatchSubmission.TotalFormCount})`, `LastProgressTimestamp = utcNow()`. Call `Audit-Event-Logger` with `ActionType = BatchStatusUpdate`. |
| T044 | Add Step 4 — Terminal state detection and batch completion | 25 min | T043 | Add `Condition`: `add(varFormsCompleted, varFormsFailed)` equals `{BatchSubmission.TotalFormCount}`. On True branch: (1) Add nested `Condition`: `varFormsFailed` equals `0`. (a) If all complete: `Dataverse > Update a row` on `BatchSubmission`: `BatchStatus = Complete`, `CompletionTimestamp = utcNow()`. Call `Audit-Event-Logger` `ActionType = BatchComplete`. (b) If some failed: `BatchStatus = PartiallyFailed`, `CompletionTimestamp = utcNow()`. Call `Audit-Event-Logger` `ActionType = BatchComplete` with details = `{varFormsFailed} forms failed`. (2) In both terminal cases: Call `Notification-Router` to notify supervisor + uploader of batch completion status. |
| T045 | Add concurrency guard — optimistic concurrency + retry | 20 min | T043 | Configure the flow's `Settings > Concurrency Control` to limit concurrent runs to 1 per BatchID. Alternative: wrap the `Update a row` in a retry policy. If Dataverse returns a 409 Conflict (concurrency violation): wait 2 seconds and retry up to 3 times using a `Do Until` loop around the update action. This prevents race conditions when multiple child FormSubmission status changes fire simultaneously for the same batch. |
| T046 | Enable and test `Flow-01B-Batch-Status-Updater` | 15 min | T044, T045 | Enable flow. Process a test batch of 3 forms. As each form's Status changes → verify `BatchSubmission.FormsCompleted` increments in Dataverse within 30 seconds (SC-003). When all 3 complete → verify `BatchStatus = Complete` and `CompletionTimestamp` is set. |
| T047 | Create `Flow-01C-Stale-Batch-Monitor` scheduled flow | 15 min | T009 | In `Power Automate > + Create > Scheduled cloud flow`, name = `Flow-01C-Stale-Batch-Monitor`, recurrence = every 1 hour. |
| T048 | Configure stale batch detection query | 20 min | T047 | Add `Dataverse > List rows` on `BatchSubmission`. OData filter: `LastProgressTimestamp lt {addHours(utcNow(), -24)} and BatchStatus ne 'Complete' and BatchStatus ne 'PartiallyFailed' and BatchStatus ne 'ValidationFailed'`. Store results in `varStaleBatches`. |
| T049 | Add stale batch alert loop — notify and audit log | 20 min | T048 | Add `Apply to each` over `varStaleBatches`. Inside loop: (1) Call `Notification-Router` subflow: recipient = supervisor, message = `'Stale batch alert: Batch {item()/BatchDisplayID} has had no progress since {item()/LastProgressTimestamp}. Current status: {item()/BatchStatus}.'`, severity = Warning. (2) Call `Audit-Event-Logger` with `ActionType = StaleBatchAlert`, `EntityID = {item()/BatchID}`. This satisfies FR-006 and SC-006 (alerts fire within 1 hour of the 24-hour threshold). |

### Checklist — Phase 6

- [ ] T039 [US4] Create `Flow-01B-Batch-Status-Updater` cloud flow — blank canvas → `Power Automate > Flows > Flow-01B-Batch-Status-Updater`
- [ ] T040 [US4] Configure Dataverse trigger on `FormSubmission` modified — filter `BatchID ne null` → `Power Automate > Flow-01B > Trigger`
- [ ] T041 [US4] Add Step 1 — `Dataverse > List rows` for all sibling `FormSubmission` rows by `BatchID` → `Power Automate > Flow-01B > Step 1`
- [ ] T042 [US4] Add Step 2 — Compute `FormsCompleted`, `FormsInReview`, `FormsFailed`, `FormsProcessing` via `filter()` expressions → `Power Automate > Flow-01B > Step 2`
- [ ] T043 [US4] Add Step 3 — `Dataverse > Update a row` on `BatchSubmission` counters + `LastProgressTimestamp` + `BatchStatusUpdate` audit log → `Power Automate > Flow-01B > Step 3`
- [ ] T044 [US4] Add Step 4 — Terminal state detection (`Complete` / `PartiallyFailed`) + `CompletionTimestamp` + completion notification → `Power Automate > Flow-01B > Step 4`
- [ ] T045 [US4] Add concurrency guard — optimistic concurrency retry (3 attempts, 2-second backoff) → `Power Automate > Flow-01B > Settings + Update Row`
- [ ] T046 [US4] Enable `Flow-01B-Batch-Status-Updater` + verify counters update within 30 seconds per SC-003 → `Power Automate > Flow-01B`
- [ ] T047 [US4] Create `Flow-01C-Stale-Batch-Monitor` — scheduled every 1 hour → `Power Automate > Flows > Flow-01C-Stale-Batch-Monitor`
- [ ] T048 [US4] Configure stale batch `Dataverse > List rows` query (`LastProgressTimestamp < now-24h`, non-terminal status) → `Power Automate > Flow-01C > Step 1`
- [ ] T049 [US4] Add stale batch alert loop — `Notification-Router` + `StaleBatchAlert` audit log per stale batch → `Power Automate > Flow-01C > Step 2`

**Checkpoint**: User Story 4 independently testable. Batch of 5 forms → counters update in near-real-time → terminal state triggers completion status + notification. Stale batch with `LastProgressTimestamp > 24h` → alert sent within 1 hour.

---

## Phase 7: User Story 5 — Batch-Level Reporting & Audit (Priority: P3)

**Goal**: Extend the existing Power BI extraction dashboard with batch metrics. VA supervisors can see batches/day, average forms/batch, batch completion time, and error rate. A drill-through page shows the full lifecycle for any specific batch.

**Independent Test**: Process 3 batches of varying sizes (3 forms, 7 forms, 10 forms) → open Power BI dashboard → verify each metric (batches/day, avg forms/batch, completion time, error rate) reflects the processed batches correctly.

**Prerequisite**: Access to the existing Power BI report and its Dataverse data source. US4 must be complete (BatchSubmission populated with real data).

| Task | Title | Effort | Dependencies | Acceptance Criteria |
|------|-------|--------|--------------|---------------------|
| T050 | Identify existing Power BI dataset and Dataverse connection | 15 min | T046 | Open Power BI Desktop / Power BI Service → find existing `Extraction-Dashboard` report. Identify the Dataverse connection used. Confirm the Power BI dataset refresh service account has read access to the new `BatchSubmission` table. If access is missing, grant Dataverse read permission to the service account. |
| T051 | Add `BatchSubmission` table to Power BI dataset | 20 min | T050 | In Power BI Desktop: `Home > Transform data > Get Data > Dataverse`. Connect to `BatchSubmission` table. Define relationship: `BatchSubmission[BatchID]` → `FormSubmission[BatchID]` (1:N). Refresh dataset and verify `BatchSubmission` rows appear in the data model. |
| T052 | Create "Batches Per Day" measure and visual | 20 min | T051 | Add DAX measure: `BatchesPerDay = COUNTROWS(FILTER(BatchSubmission, BatchSubmission[UploadTimestamp] >= TODAY()))` (or suitable time-intelligence measure). Add a Line chart or Card visual to the existing dashboard page. Label: "Batches Processed Today". |
| T053 | Create "Average Forms Per Batch" measure and visual | 15 min | T051 | Add DAX measure: `AvgFormsPerBatch = AVERAGE(BatchSubmission[TotalFormCount])`. Add a Card or KPI visual. Label: "Avg Forms / Batch". |
| T054 | Create "Batch Completion Time" measure and visual | 20 min | T051 | Add DAX measure: `AvgBatchCompletionMins = AVERAGEX(FILTER(BatchSubmission, BatchSubmission[CompletionTimestamp] <> BLANK()), DATEDIFF(BatchSubmission[UploadTimestamp], BatchSubmission[CompletionTimestamp], MINUTE))`. Add a Card visual. Label: "Avg Batch Completion Time (min)". |
| T055 | Create "Batch Error Rate" measure and visual | 15 min | T051 | Add DAX measure: `BatchErrorRate = DIVIDE(COUNTROWS(FILTER(BatchSubmission, OR(BatchSubmission[BatchStatus] = "PartiallyFailed", BatchSubmission[BatchStatus] = "ValidationFailed"))), COUNTROWS(BatchSubmission), 0)`. Add a Gauge or Card visual formatted as percentage. Label: "Batch Error Rate". |
| T056 | Create Batch Detail drill-through page | 25 min | T051, T052, T053, T054, T055 | Add a new Power BI report page: "Batch Detail". Add drill-through filter on `BatchSubmission[BatchDisplayID]`. Add visuals: (1) Batch lifecycle timeline (UploadTimestamp → SplitStartTimestamp → SplitEndTimestamp → CompletionTimestamp). (2) Table of child `FormSubmission` records with FormIndex, Status, ExtractionConfidence. (3) Batch status badge (BatchStatus option set value). Satisfy SC-007: supervisor can identify failed forms within 1 minute. |

### Checklist — Phase 7

- [ ] T050 [US5] Identify Power BI dataset + verify `BatchSubmission` Dataverse read access for service account → `Power BI Service > Extraction-Dashboard > Dataset Settings`
- [ ] T051 [US5] Add `BatchSubmission` table to Power BI dataset + define relationship to `FormSubmission` → `Power BI Desktop > Transform Data`
- [ ] T052 [P] [US5] Create "Batches Per Day" DAX measure + Card/Line visual → `Power BI Desktop > Extraction-Dashboard > Batch Metrics Page`
- [ ] T053 [P] [US5] Create "Average Forms Per Batch" DAX measure + Card visual → `Power BI Desktop > Extraction-Dashboard > Batch Metrics Page`
- [ ] T054 [P] [US5] Create "Batch Completion Time" DAX measure + Card visual → `Power BI Desktop > Extraction-Dashboard > Batch Metrics Page`
- [ ] T055 [P] [US5] Create "Batch Error Rate" DAX measure + Gauge visual → `Power BI Desktop > Extraction-Dashboard > Batch Metrics Page`
- [ ] T056 [US5] Create "Batch Detail" drill-through page (lifecycle timeline + child form table + status badge) → `Power BI Desktop > Extraction-Dashboard > Batch Detail Page`

**Checkpoint**: User Story 5 independently testable. After processing 3 test batches: all 4 metrics display correctly. Drill-through from Batch Metrics → Batch Detail shows full lifecycle + individual form statuses.

---

## Phase 8: End-to-End Testing

**Purpose**: Validate the complete Mode 2 pipeline across all specified test scenarios per `quickstart.md` and `spec.md`. All flows (Flow 01, Flow 01B, Flow 01C) must be enabled. Mode 1 must remain fully functional.

| Task | Title | Effort | Dependencies | Acceptance Criteria |
|------|-------|--------|--------------|---------------------|
| T057 | E2E Test 1 — Single-form bypass via `Batches/Incoming/` | 20 min | T038 | Upload a 2-page VA Form 10-3542 PDF to `FormIntake/Batches/Incoming/`. Expected: Flow 01 detects 2 pages → moves file to `FormIntake/` root → Flow 1 (VA-Form-Intake-Pipeline) triggers → FormSubmission created with `BatchID = null`. No `BatchSubmission` record created. Full extraction pipeline runs normally. |
| T058 | E2E Test 2 — Small batch (6 pages = 3 forms) | 30 min | T037, T046 | Concatenate 3 copies of the 2-page VA Form 10-3542 to create a 6-page test PDF. Upload to `FormIntake/Batches/Incoming/`. Expected: (1) `BatchSubmission` created with `TotalFormCount = 3`, `BatchStatus = Splitting`. (2) 3 split PDFs saved to batch subfolder. (3) 3 PDFs moved to `FormIntake/` root with 5-second delays. (4) Flow 1 triggers 3 times → 3 FormSubmission records, each with `BatchID` and `FormIndexInBatch = 1, 2, 3`. (5) Each form processes through extraction. (6) Flow 01B updates counters in real-time. (7) When all 3 complete → `BatchStatus = Complete`. Full flow within 2 minutes for 20 forms (SC-001 baseline). |
| T059 | E2E Test 3 — Odd-page rejection (5 pages) | 15 min | T022 | Create or obtain a 5-page test PDF. Upload to `FormIntake/Batches/Incoming/`. Expected: Flow 01 detects odd page count → `BatchSubmission` created with `BatchStatus = ValidationFailed`, `ErrorDetails` contains "Odd page count". Notification-Router sends notification to uploader. No split PDFs created. No FormSubmission records created with this BatchID. |
| T060 | E2E Test 4 — Oversized batch rejection (>250 forms) | 15 min | T020 | Create a test PDF with page count indicating >250 forms (can simulate by temporarily lowering the limit or using metadata). Expected: `BatchStatus = ValidationFailed`, `ErrorDetails` contains "exceeds 250-form limit". Operator notified. |
| T061 | E2E Test 5 — Duplicate batch detection | 20 min | T021 | Upload a 6-page batch PDF. Wait for it to be processed (Status = SplittingComplete or later). Upload the exact same file again (same name, same content). Expected: Second upload results in `BatchStatus = ValidationFailed`, `ErrorDetails` contains "Duplicate batch detected" with the original batch's ID referenced. Uploader notified. |
| T062 | E2E Test 6 — Large batch performance (20+ forms = 40+ pages) | 45 min | T058 | Create a 40-page test PDF (20 copies of the 2-page VA form). Upload to `FormIntake/Batches/Incoming/`. Expected: (1) All 20 forms split and deposited within **2 minutes** (SC-001). (2) All 20 `FormSubmission` records created with correct `BatchID` and `FormIndexInBatch` values 1–20. (3) `BatchSubmission.BatchStatus = SplittingComplete` within 2 minutes. Record actual elapsed time. |
| T063 | E2E Test 7 — Stale batch alert simulation | 30 min | T049 | Create a `BatchSubmission` record manually in Dataverse with `BatchStatus = Splitting` and `LastProgressTimestamp = utcNow() - 25 hours`. Wait for `Flow-01C-Stale-Batch-Monitor` to run (or manually trigger it). Expected: Notification-Router sends stale batch alert to supervisor within 1 hour of the hourly schedule firing (SC-006). `AuditLog` contains a `StaleBatchAlert` entry for this batch. |
| T064 | E2E Test 8 — Mode 1 regression (single-form upload unaffected) | 20 min | T038 | Upload 5 single-form PDFs directly to `FormIntake/` root (Mode 1 path). Verify: (1) Each creates a `FormSubmission` with `BatchID = null`. (2) Each processes through extraction, confidence routing, and D365 write without any batch-related errors. (3) Flow 01B does NOT trigger for any of these (filter on `BatchID ne null` holds). (4) No `BatchSubmission` records created. Mode 1 is completely unchanged from pre-feature behavior. |

### Checklist — Phase 8

- [ ] T057 E2E Test 1 — Single-form bypass via `Batches/Incoming/` (2-page PDF → Mode 1 route) → `SharePoint > FormIntake > Batches/Incoming/`
- [ ] T058 E2E Test 2 — Small batch (6-page / 3-form PDF → full split → extraction → BatchStatus = Complete) → `SharePoint > FormIntake > Batches/Incoming/`
- [ ] T059 E2E Test 3 — Odd-page rejection (5-page PDF → ValidationFailed + notification) → `SharePoint > FormIntake > Batches/Incoming/`
- [ ] T060 E2E Test 4 — Oversized batch rejection (>250 forms → ValidationFailed) → `SharePoint > FormIntake > Batches/Incoming/`
- [ ] T061 E2E Test 5 — Duplicate batch detection (same PDF uploaded twice → second rejected) → `SharePoint > FormIntake > Batches/Incoming/`
- [ ] T062 E2E Test 6 — Large batch performance (40-page/20-form PDF → split + deposit ≤ 2 minutes per SC-001) → `SharePoint > FormIntake > Batches/Incoming/`
- [ ] T063 E2E Test 7 — Stale batch alert simulation (manually aged record → alert within 1 hour per SC-006) → `Dataverse > Tables > BatchSubmission`
- [ ] T064 E2E Test 8 — Mode 1 regression (5 single-form PDFs → all process without batch interference) → `SharePoint > FormIntake`

**Checkpoint**: All 8 test scenarios pass. SC-001 through SC-008 verified. Document results in team notes.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Audit trail completeness, operational documentation, and solution packaging. No new features — only hardening and documentation.

| Task | Title | Effort | Dependencies | Acceptance Criteria |
|------|-------|--------|--------------|---------------------|
| T065 | Verify all 9 AuditLog `ActionType` values are emitted end-to-end | 20 min | T058, T064 | After running E2E Tests 2 and 8: Query `AuditLog` table in Dataverse. Confirm entries exist for all 9 new `ActionType` values: `BatchUpload`, `BatchValidation`, `BatchSplitStart`, `BatchSplitComplete`, `BatchSplitFailed` (from failure test), `BatchFormDeposit`, `BatchStatusUpdate`, `BatchComplete`, `StaleBatchAlert`. Each entry includes `EntityID`, `ActionType`, `Details`, and `Timestamp`. |
| T066 | Update `SharePoint > FormIntake > Batches/Incoming/` folder permissions | 15 min | T004 | Verify that VA staff who currently have access to `FormIntake/` also have access to upload to `Batches/Incoming/`. Confirm that `Batches/{BatchDisplayID}/` subfolders are restricted (read-only for staff, write for the Power Automate service account). Document permission model in `specs/004-multi-form-pdf-splitter/quickstart.md`. |
| T067 | Create operator runbook for `SplitFailed` recovery | 20 min | T028 | Document the recovery procedure for a split failure: (1) Identify the failing batch in Dataverse (`BatchStatus = SplitFailed`). (2) Note `LastSuccessfulSplitIndex` (partial results already split). (3) Options: (a) Re-upload the original batch PDF to `Batches/Incoming/` — duplicate detection will block if same file; rename or use different subfolder. (b) Manually trigger a retry by updating `BatchStatus = RetryPending` (if retry flow built). Save runbook in `specs/004-multi-form-pdf-splitter/` or team wiki. |
| T068 | [P] Review Power Automate flow run history and error rates | 15 min | T064 | In `Power Automate > Flow run history` for all 3 new flows: confirm no unexpected errors in runs. Document any throttling warnings. Set up flow run failure alerts (Power Automate `Monitor > Alerts`) for all 3 new flows. |
| T069 | [P] Performance verification — 20-form batch ≤ 2 minutes per SC-001 | 15 min | T062 | Review timing data from E2E Test 6 (T062). Calculate elapsed time from `UploadTimestamp` to `SplittingComplete` timestamp on `BatchSubmission`. Confirm ≤ 2 minutes for a 20-form (40-page) batch. If > 2 minutes, investigate Muhimbi response times and SharePoint move operation latency. Document result. |
| T070 | [P] Export and version control all new Power Automate flows as solutions | 20 min | T064 | In `Power Platform Maker Portal > Solutions`: Export `Flow-01-Batch-PDF-Splitter`, `Flow-01B-Batch-Status-Updater`, `Flow-01C-Stale-Batch-Monitor`, and the updated `VA-Form-Intake-Pipeline` as a managed or unmanaged solution package. Store the `.zip` export in the team SharePoint or note the export location in `specs/004-multi-form-pdf-splitter/quickstart.md`. This supports version control and deployment repeatability. |

### Checklist — Phase 9

- [ ] T065 Verify all 9 `AuditLog` `ActionType` values emitted end-to-end → `Dataverse > Tables > AuditLog`
- [ ] T066 Update `Batches/Incoming/` folder permissions + document permission model → `SharePoint > FormIntake > Batches/Incoming/ > Permissions`
- [X] T067 Create operator runbook for `SplitFailed` recovery procedure → `specs/004-multi-form-pdf-splitter/runbook-split-failed.md`
- [ ] T068 [P] Review flow run history + set up failure alerts for all 3 new flows → `Power Automate > Monitor > Alerts`
- [ ] T069 [P] Performance verification — confirm 20-form batch ≤ 2 minutes (SC-001) → `Dataverse > Tables > BatchSubmission > SplittingComplete timestamp`
- [ ] T070 [P] Export new flows as Power Platform solution package → `Power Platform Maker Portal > Solutions`

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1: Setup
  └─▶ Phase 2: Foundational — Dataverse Schema  (BLOCKS all flow phases)
       ├─▶ Phase 3: US1 — Batch Detection (Flow 01, Steps 1–2)
       │    └─▶ Phase 4: US2 — PDF Splitting (Flow 01, Steps 3–5)
       │         └─▶ Phase 5: US3 — Pipeline Feeding (Flow 01, Step 6 + ⚠️ Flow 1 modification)
       │              └─▶ Phase 6: US4 — Batch Tracking (Flow 01B + Flow 01C)
       │                   └─▶ Phase 7: US5 — Reporting (Power BI)
       │                        └─▶ Phase 8: End-to-End Testing
       │                             └─▶ Phase 9: Polish
```

### User Story Dependencies

| Story | Priority | Depends On | Can Start After |
|-------|----------|-----------|-----------------|
| **US1** — Batch PDF Upload & Detection | P1 | Phase 2 complete (schema ready) | T012 |
| **US2** — PDF Splitting | P1 | US1 complete (T023) | T023 |
| **US3** — Feeding Split Forms to Pipeline | P1 | US2 complete (T031) + ⚠️ Schema ready (T012) | T031 |
| **US4** — Batch Tracking & Status Visibility | P2 | US3 complete (T038) + Schema ready | T038 |
| **US5** — Batch-Level Reporting & Audit | P3 | US4 complete (T046) — needs real data | T046 |

**Note**: US1 → US2 → US3 are tightly coupled within `Flow-01-Batch-PDF-Splitter` and should be built sequentially on the same flow canvas. US4 and US5 are separate flows/artifacts and can be built in parallel with US3 by a second team member once the schema (Phase 2) is done.

### Parallel Opportunities

**Within Phase 2** (all can be done in parallel after T006):
- T007, T008, T009, T010 are independent column groups on `BatchSubmission`

**Within Phase 3** (after T015):
- T016, T017 are independent validation conditions

**Within Phase 7** (after T051):
- T052, T053, T054, T055 are independent DAX measures and visuals

**Within Phase 9**:
- T068, T069, T070 can all run in parallel

**Two-person team split** (after Phase 2 completes):
- **Person A**: Phase 3 → Phase 4 → Phase 5 (Flow 01 build)
- **Person B**: Phase 6 (Flow 01B + Flow 01C) — only needs T012 (schema), not the completed Flow 01

---

## Parallel Execution Examples

### Phase 2 Parallel — Dataverse Schema Columns

```
After T006 (BatchSubmission table created), launch in parallel:
  → T007: Add core metadata columns
  → T008: Create BatchStatus option set
  → T009: Add counter and timestamp columns
  → T010: Add operational columns
Then sequentially:
  → T011: Add BatchID to FormSubmission (depends on T006)
  → T012: Add FormIndexInBatch to FormSubmission (depends on T011)
```

### Phase 7 Parallel — Power BI Measures

```
After T051 (BatchSubmission added to dataset), launch in parallel:
  → T052: Batches Per Day visual
  → T053: Avg Forms Per Batch visual
  → T054: Batch Completion Time visual
  → T055: Batch Error Rate visual
Then:
  → T056: Batch Detail drill-through page (uses all 4 measures)
```

---

## Implementation Strategy

### MVP First — User Stories 1, 2, 3 Only

Complete the core split-and-feed pipeline before any tracking or reporting:

1. ✅ Complete Phase 1: Setup
2. ✅ Complete Phase 2: Foundational (CRITICAL — blocks everything)
3. ✅ Complete Phase 3: US1 — Batch Detection
4. ✅ Complete Phase 4: US2 — PDF Splitting
5. ✅ Complete Phase 5: US3 — Pipeline Feeding
6. **STOP and VALIDATE**: Run E2E Tests T057, T058, T059, T064
7. **Demo if ready** — the complete Mode 2 split-and-process pipeline works

### Incremental Delivery

| Increment | Phases | Delivers | Testable? |
|-----------|--------|---------|-----------|
| **MVP** | 1–5 | Batch upload → split → pipeline feed → Mode 1 bypass | ✅ T057–T059, T064 |
| **Tracking** | 1–6 | + Real-time batch status, stale batch alerts | ✅ T058, T063 |
| **Reporting** | 1–7 | + Power BI batch metrics + audit drill-through | ✅ Manual report review |
| **Complete** | 1–9 | + E2E tested, documented, solution exported | ✅ All T057–T064 |

### Key Constraints (Do Not Forget)

1. **Never trigger Flow 01 before `BatchSubmission` schema exists** — Task T013 (create flow) must come after T012 (schema complete).
2. **Never save Flow 1 changes without Mode 1 regression testing** — T037 must be followed immediately by T038.
3. **Keep `Batches/Incoming/` isolated** — Flow 1 must NOT trigger on files in `Batches/Incoming/`. Verify the SharePoint trigger folder filter is exact (T014).
4. **Sequential deposit delay** — The 5-second delay in T032 is not optional. Removing it may overwhelm the existing pipeline's SharePoint polling window.
5. **`FormSubmission.BatchID` is nullable** — Existing Mode 1 records must remain NULL. Any query of FormSubmission without a `BatchID ne null` filter will include Mode 1 records — always filter in Flow 01B.

---

## Summary

| Metric | Value |
|--------|-------|
| **Total tasks** | 70 (T001–T070) |
| **Phase 1 — Setup** | 5 tasks |
| **Phase 2 — Foundational (Schema)** | 7 tasks |
| **Phase 3 — US1 Batch Detection (P1)** | 11 tasks |
| **Phase 4 — US2 PDF Splitting (P1)** | 8 tasks |
| **Phase 5 — US3 Pipeline Feeding (P1)** | 7 tasks |
| **Phase 6 — US4 Batch Tracking (P2)** | 11 tasks |
| **Phase 7 — US5 Reporting & Audit (P3)** | 7 tasks |
| **Phase 8 — End-to-End Testing** | 8 tasks |
| **Phase 9 — Polish** | 6 tasks |
| **Estimated effort (1 person)** | 14–18 hours |
| **Estimated effort (2 people)** | 8–10 hours |
| **Parallel opportunities** | 14 tasks marked [P] |
| **Existing flow modifications** | 4 tasks marked ⚠️ (T034–T037, all in Flow 1) |
| **MVP scope** | Phases 1–5 (US1+US2+US3) = 38 tasks |
| **New Power Automate flows** | 3 new (Flow-01, Flow-01B, Flow-01C) |
| **Modified flows** | 1 (VA-Form-Intake-Pipeline — 1 conditional branch added at end) |
| **New Dataverse tables** | 1 (BatchSubmission) |
| **Extended Dataverse tables** | 1 (FormSubmission — 2 nullable columns) |
| **New SharePoint folders** | 2 (`Batches/`, `Batches/Incoming/`) |

---

**Version**: 1.0.0 | **Generated**: 2025-07-17 | **Branch**: `004-multi-form-pdf-splitter`  
**Status**: Ready for Execution | **Next Step**: Begin Phase 1 → T001 (verify existing pipeline)


