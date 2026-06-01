# Implementation Guide: VA Form 10-3542 Extraction Pipeline

**Status**: Active Implementation  
**Date**: 2026-04-24  
**Platform**: Microsoft Power Platform (Power Automate, Dataverse, Power Apps, AI Builder)  
**Feature Branch**: `002-form-extraction-impl`  
**Test Coverage Target**: 10 manual test scenarios (T089–T098)

---

## Quick Navigation

- **[Phase Overview](#phase-overview)** — 8 phases, 102 tasks, 4–5 days for 1 developer
- **[Phase 1: Setup](#phase-1-setup)** — Environment initialization (T001–T008)
- **[Phase 2: Foundational](#phase-2-foundational)** — Dataverse schema + AI Builder + shared flows (T009–T029)
- **[Phase 3–5: Core Features](#phase-3-5-core-features)** — Intake, Extraction, D365 Write (parallel, T030–T057)
- **[Phase 6–7: Extended Features](#phase-6-7-extended-features)** — Correction UI, Analytics (T058–T075)
- **[Phase 8: Polish](#phase-8-polish)** — Documentation, testing, deployment (T076–T088)

---

## Phase Overview

| Phase | Tasks | Duration | Blocking | Deliverable |
|-------|-------|----------|----------|-------------|
| **1. Setup** | T001–T008 | 2–3 hrs | Start here | Power Platform env ready |
| **2. Foundational** | T009–T029 | 6–8 hrs | Blocks all | Dataverse schema, AI Builder model |
| **3. Intake (US1)** | T030–T037 | 2–3 hrs | Needs Phase 2 | SharePoint intake flow |
| **4. Extraction (US2)** | T038–T046 | 3–4 hrs | Needs Phase 2 | AI Builder extraction flow |
| **5. D365 Write (US4)** | T047–T057 | 2–3 hrs | Needs Phase 2 | D365 integration flow |
| **6. Correction (US3)** | T058–T067 | 3–4 hrs | Needs Phases 3–4 | Power Apps correction UI |
| **7. Analytics (US5)** | T068–T075 | 2–3 hrs | Needs Phases 3–5 | Power BI dashboard |
| **8. Polish** | T076–T088 | 2–3 hrs | Final | Documentation, testing |

**Total**: ~27–31 hours (1 developer); ~10–14 hours (3 developers parallel)

---

## Phase 1: Setup (Environment Initialization)

**Owner**: Platform Admin  
**Duration**: 2–3 hours  
**Dependencies**: None (start here)  
**Deliverable**: Fully initialized Power Platform environment

### Tasks

#### T001: Create or Verify Power Platform Environment
**Description**: Provision a Power Platform environment for VA Forms project

**Steps**:
1. Navigate to https://admin.powerplatform.microsoft.com
2. Click **"New environment"**
3. Configure:
   - **Name**: `VA-FormProcessing` (or similar)
   - **Type**: `Production` (or `Sandbox` for demo)
   - **Region**: `United States` (or appropriate VA region)
   - **Language**: `English`
4. Enable **Dataverse** (required for tables + Power Apps)
5. Wait for provisioning (~5–10 min)
6. Note the environment URL (e.g., `https://org12345.crm.dynamics.com`)

**Acceptance**: Environment created; URL accessible in Power Automate

---

#### T002: Create SharePoint Site for Form Intake
**Description**: Provision a SharePoint site to receive uploaded PDFs

**Steps**:
1. Navigate to https://microsoft.sharepoint.com
2. Click **"Create site"**
3. Choose **Team site**
4. Configure:
   - **Site name**: `VA Form Processing`
   - **Site address**: `/sites/VAFormProcessing`
   - **Owner**: Your account
5. Wait for provisioning (~2–3 min)
6. Copy the site URL (e.g., `https://tenant.sharepoint.com/sites/VAFormProcessing`)

**Acceptance**: SharePoint site created; admin can access

---

#### T003: Create SharePoint Document Library for Form Intake
**Description**: Create document library to receive uploaded form PDFs

**Steps**:
1. In SharePoint site, click **"New"** → **"List"**
2. Choose **Document library**
3. Name: `FormIntake`
4. Click **"Create"**
5. In library settings, enable **Versioning** (optional, for audit trail)
6. Copy library URL (e.g., `https://tenant.sharepoint.com/sites/VAFormProcessing/FormIntake`)

**Acceptance**: Document library created; upload test PDF (verify success)

---

#### T004: Configure Dynamics 365 Connection
**Description**: Set up D365 connector in Power Platform

**Steps**:
1. Navigate to Power Automate (https://powerautomate.microsoft.com)
2. Click **"My cloud flows"** → **"Cloud flows"**
3. Look for **Dynamics 365** connector in "Connections" section
4. If not present, click **"+ New connection"** → search **"Dynamics 365"**
5. Authenticate with your Entra ID account (VA staff credentials)
6. Verify connection works (should show "Connected")
7. Note the D365 environment name

**Acceptance**: D365 connector available in Power Automate

---

#### T005: Verify Power Automate Connectors & AI Builder
**Description**: Verify required connectors are enabled in tenant

**Steps**:
1. In Power Platform admin center (https://admin.powerplatform.microsoft.com), go to **Environments**
2. Select your environment
3. Click **Settings** → **Manage features** → **Connectors**
4. Verify enabled:
   - ✅ AI Builder
   - ✅ Dataverse
   - ✅ Dynamics 365
   - ✅ SharePoint
   - ✅ Outlook (for email notifications)
5. If disabled, request tenant admin to enable

**Acceptance**: All connectors enabled

---

#### T006: Create Power Platform Solution Container
**Description**: Create solution to hold all flows, tables, apps

**Steps**:
1. Navigate to Power Automate → **Solutions**
2. Click **"New solution"**
3. Configure:
   - **Display name**: `VA-Form-Extraction`
   - **Name**: `va_form_extraction`
   - **Publisher**: `VA Forms (custom)`
   - **Version**: `1.0.0`
4. Click **"Create"**
5. Wait for creation (~1 min)

**Acceptance**: Solution created; can see in solutions list

---

#### T007: Verify AI Builder Capacity
**Description**: Check AI Builder availability and capacity

**Steps**:
1. In Power Platform admin center, go to **Resources** → **Capacity**
2. Look for **AI Builder** section
3. Verify:
   - ✅ AI Builder credits available (show current balance)
   - ✅ Form processing license assigned to your user
4. If no credits, request trial or license allocation

**Acceptance**: AI Builder capacity confirmed

---

#### T008: Set Up Entra ID Authentication
**Description**: Configure Microsoft Entra ID for VA staff access

**Steps**:
1. Verify all users have Entra ID accounts in your tenant (VA staff)
2. In Power Platform environment settings, verify OAuth2 is default
3. Test login with a VA staff account:
   - Open Power Automate → verify signed in as VA staff
   - Open Power Apps → verify signed in as VA staff
4. Document user emails for role assignment later

**Acceptance**: VA staff can sign in to Power Platform

---

### Phase 1 Checkpoint

✅ **Environment initialized**
- [ ] Power Platform environment created & accessible
- [ ] SharePoint site + FormIntake library created
- [ ] D365 connector configured
- [ ] AI Builder enabled
- [ ] Solution container created
- [ ] Entra ID authentication working

**Next**: Proceed to Phase 2 (Foundational)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Owner**: Data Architect + AI Builder specialist  
**Duration**: 6–8 hours  
**Dependencies**: Phase 1 complete  
**Deliverable**: Dataverse schema, trained AI Builder model, shared flows

### Part A: Dataverse Table Setup

#### T009: Create FormSubmission Table
**Description**: Core table for tracking form uploads

**Steps**:

1. Navigate to Power Apps (https://make.powerapps.com)
2. Select your environment
3. Click **"Tables"** → **"New table"**
4. Configure:
   - **Display name**: `Form Submission`
   - **Plural display name**: `Form Submissions`
   - **Name**: `va_formsubmission` (auto-generated)
5. Add columns:

| Column Name | Display Name | Type | Required | Notes |
|-------------|--------------|------|----------|-------|
| FormID | Form ID | GUID (Primary Key) | Yes | Auto-generated |
| FileHash | File Hash | Text (200 chars) | Yes | SHA256 of PDF |
| UploadedBy | Uploaded By | Lookup (Users) | Yes | Entra ID user |
| UploadTimestamp | Upload Timestamp | Date Time | Yes | Immutable |
| FileName | File Name | Text (200 chars) | Yes | PDF filename |
| Status | Status | Choice | Yes | Intake, Extracting, ReviewRequired, ReadyForD365, D365Writing, Complete, WriteFailed, ManualIntake |
| Metadata | Metadata | JSON (unlimited) | No | {SourceSystem, BatchID, etc.} |
| FileBlob | File Blob | File (unlimited) | No | PDF file (optional; prefer SharePoint) |

6. Click **"Save and close"**

**Acceptance**: Table created; columns visible in table designer

---

#### T010–T013: Create ExtractionResult, CorrectionRecord, AuditLog, D365WriteEvent Tables

**T010: ExtractionResult Table**
**Description**: Stores AI-extracted fields + confidence scores

**Steps**:
1. In Power Apps → Tables → **New table**
2. **Display name**: `Extraction Result`; **Name**: `va_extractionresult`
3. Add columns (see data-model.md for full schema):

| Column Name | Type | Required |
|-------------|------|----------|
| ExtractionID | GUID | Yes (primary key) |
| FormID | Lookup (FormSubmission) | Yes |
| ModelVersion | Text (50) | Yes |
| ExtractionTimestamp | DateTime | Yes |
| ClaimantFullName | Text (200) | No |
| ClaimantFullName_Confidence | Decimal (0–100) | No |
| ClaimantSSN | Text (11, encrypted) | No |
| ClaimantSSN_Confidence | Decimal (0–100) | No |
| ... (40+ fields per data-model.md) | ... | ... |
| OverallConfidenceScore | Decimal (0–100) | Yes |
| CriticalFieldsOnly_Confidence | Decimal (0–100) | No |
| ClaimantContactID | Lookup (Contacts) | No |
| VeteranContactID | Lookup (Contacts) | No |

4. Save

**Acceptance**: Table created with ≥40 columns

---

**T011: CorrectionRecord Table**

**Steps**:
1. New table: `Correction Record` → `va_correctionrecord`
2. Add columns:

| Column Name | Type | Required |
|-------------|------|----------|
| CorrectionID | GUID | Yes |
| ExtractionID | Lookup (ExtractionResult) | Yes |
| CorrectedBy | Lookup (Users) | Yes |
| CorrectionTimestamp | DateTime | Yes |
| ChangesLog | JSON | No |
| ApprovalStatus | Choice (Pending, Approved, Rejected) | Yes |
| ApprovalTimestamp | DateTime | No |

3. Save

---

**T012: AuditLog Table**

**Steps**:
1. New table: `Audit Log` → `va_auditlog`
2. Add columns:

| Column Name | Type | Required |
|-------------|------|----------|
| AuditID | GUID | Yes |
| Timestamp | DateTime | Yes |
| UserID | Lookup (Users) | Yes |
| ActionType | Text (50) | Yes |
| TargetEntity | Text (100) | Yes |
| OperationDetails | JSON | No |
| Status | Choice (Success, Failure) | Yes |
| ErrorMessage | Text (500) | No |
| ImmutableHash | Text (64, encrypted) | No |
| SystemID | Text (50) | No |

3. Save

---

**T013: D365WriteEvent Table**

**Steps**:
1. New table: `D365 Write Event` → `va_d365writeevent`
2. Add columns:

| Column Name | Type | Required |
|-------------|------|----------|
| WriteEventID | GUID | Yes |
| FormID | Lookup (FormSubmission) | Yes |
| D365RecordID | Text (100) | No |
| WrittenBy | Lookup (Users) | Yes |
| WriteTimestamp | DateTime | Yes |
| WriteStatus | Choice (Success, Failed, Retry) | Yes |
| ErrorDetails | Text (500) | No |
| RetryCount | Number (int) | Yes, default 0 |

3. Save

---

#### T014: Configure Dataverse Table Relationships
**Description**: Set up lookups and 1:many relationships

**Steps**:
1. In Dataverse table designer, configure:
   - FormSubmission → ExtractionResult (1:many)
   - ExtractionResult → CorrectionRecord (1:0..1)
   - FormSubmission → AuditLog (1:many)
   - FormSubmission → D365WriteEvent (1:1)
2. For each relationship, set cascade delete = "Restrict" (keep audit trail)
3. Save all tables

**Acceptance**: All relationships configured in table designer

---

#### T015–T016: Enable Auditing & PII Encryption
**Steps**:
1. For each table (FormSubmission, ExtractionResult, CorrectionRecord, D365WriteEvent):
   - Open table → **Settings**
   - Enable **Audit changes** ✅
   - For PII columns (ClaimantSSN, VeteranSSN): Mark as **Confidential**
2. Save

**Acceptance**: Auditing & PII flags enabled on all tables

---

### Part B: AI Builder Model Training

#### T017: Collect 5 VA Form 10-3542 PDFs
**Description**: Gather sample forms for training dataset

**Steps**:
1. Create folder: `training-data/` in project repo
2. Collect or create 5 sample VA Form 10-3542 PDFs:
   - Mix of handwritten + typed forms
   - Quality: 1 high-quality, 1 medium-quality, 3 lower-quality (to test edge cases)
   - Anonymize or use test data (no real beneficiary SSNs)
3. Save as: `VA-Form-10-3542-01.pdf` through `VA-Form-10-3542-05.pdf`
4. Commit to repo

**Acceptance**: 5 PDFs in training-data/ folder

---

#### T018: Create AI Builder Form Processing Model
**Description**: Initialize AI Builder custom document model

**Steps**:
1. Navigate to Power Automate → **AI Builder** (left sidebar)
2. Click **"Models"** → **"Document processing"** → **"+ New"**
3. Configure:
   - **Model name**: `VA-Form-10-3542-Extraction-v1`
   - **Model description**: Extract beneficiary travel form fields
4. Click **"Create"**
5. Follow wizard:
   - **Step 1 – Document upload**: Upload your 5 training PDFs (or drag-and-drop)
   - Wait for document analysis (~2 min)
6. Click **"Next"**

**Acceptance**: Model created in AI Builder; documents uploaded & analyzed

---

#### T019: Upload 5 Forms to AI Builder Training Dataset
**Description**: Prepare training data for model

**Steps**:
1. In AI Builder document processing model:
2. For each of your 5 PDFs:
   - Upload and preview
   - AI Builder will show field detection preview
3. Confirm all 5 documents are visible in training set
4. Document count should show: **5 documents**

**Acceptance**: All 5 documents visible in training dataset

---

#### T020: Manually Annotate All Key Fields
**Description**: Train AI model by labeling form fields

**Steps**:
1. In AI Builder model, start **Manual annotation**:
2. For **each of the 5 documents**, manually label these fields:
   - Section A (Traveler Info):
     - Claimant Full Name
     - Claimant SSN
     - Claimant Date of Birth
     - Claimant Status
     - Veteran Full Name (if applicable)
     - Veteran SSN (if applicable)
     - Veteran Date of Birth (if applicable)
   - Section B (Trip Info):
     - Travel From Address
     - Travel Begin Date
     - Travel Method (Outbound)
     - Travel End Date
     - Travel Method (Return)
     - Has Other Expenses (Y/N)
   - Section C (Statements):
     - Treating Facility Name
     - Treating Facility Address
     - Signature Date

3. For each document-field pair:
   - Click the field region on the PDF
   - Verify AI selection is correct (or adjust)
   - Click **"Confirm"**
   - Move to next field

4. After annotating all fields on first document, click **"Next document"**

5. Repeat for all 5 documents (~15–20 min total)

**Acceptance**: All 5 documents annotated; model shows "Ready to train"

---

#### T021: Train AI Builder Model
**Description**: Run model training on annotated dataset

**Steps**:
1. In AI Builder model, click **"Train"**
2. AI Builder will:
   - Analyze annotations
   - Build extraction rules
   - Test accuracy on training set
3. Wait for training to complete (~5–10 min)
4. Review training results:
   - Expected accuracy: 60–75% (5-form dataset is small)
   - Each field shows confidence score
5. If accuracy < 50%:
   - Review annotations for errors
   - Retrain if needed

**Acceptance**: Model training complete; accuracy > 50%

---

#### T022: Test AI Builder Model on All 5 Forms
**Description**: Validate model accuracy before publishing

**Steps**:
1. In AI Builder model, click **"Test"**
2. For each of your 5 training documents:
   - AI Builder will extract fields
   - Review extracted values
   - Log actual accuracy (% correct fields)
   - Document any mismatches (for troubleshooting)
3. Create test results log in `training-data/model-accuracy-log.txt`:

```
VA-Form-10-3542-01.pdf:
  - Claimant Name: ✓ Correct
  - SSN: ✓ Correct
  - DOB: ✗ Incorrect (extracted: 01/15/1960, actual: 01/15/1961)
  - Overall: 12/15 fields correct = 80%

VA-Form-10-3542-02.pdf:
  ...
```

4. Calculate **average accuracy** across all 5 forms
5. Document in test results

**Acceptance**: All 5 forms tested; accuracy logged (expected 60–75%)

---

#### T023: Publish AI Builder Model
**Description**: Make model available for use in Power Automate

**Steps**:
1. In AI Builder model, click **"Publish"**
2. Model status changes to **"Published"**
3. Copy model ID (shown in model details)
4. Verify model appears in Power Automate connector:
   - Open Power Automate
   - Create new cloud flow
   - Search for "AI Builder" action
   - Verify "Extract information from documents" shows your model

**Acceptance**: Model published; visible in Power Automate

---

#### T024: Document Model Version
**Description**: Record model metadata for audit trail

**Steps**:
1. Create `training-data/MODEL_METADATA.txt`:

```
Model Name: VA-Form-10-3542-Extraction-v1
Model ID: [copy from AI Builder]
Publication Date: 2026-04-24
Training Dataset Size: 5 documents
Accuracy: [from T022 test results]
Fields Extracted: 15 (Claimant info, trip info, facility, signature)
Confidence Threshold: 90% for auto-approval, 80% for manual review

Known Limitations:
- Handwritten forms: ~70% accuracy
- Typed forms: ~85% accuracy
- SSN extraction: 95% accuracy
```

2. Commit to repo

**Acceptance**: Model metadata documented

---

### Part C: Power Automate Shared Flows

#### T025: Create Shared Flow "Log-Audit-Event"
**Description**: Reusable action to write audit log entries

**Steps**:
1. Power Automate → **Cloud flows** → **Shared cloud flows** → **New**
2. Choose **Shared flow** → Name: `Log-Audit-Event`
3. Click **"Create"**
4. Add **Input parameters** (inputs):

| Name | Type | Required | Default |
|------|------|----------|---------|
| ActionType | String | Yes | — |
| TargetEntity | String | Yes | — |
| OperationDetails | String | No | — |
| Status | String | Yes | "Success" |
| ErrorMessage | String | No | — |

5. Add **Output** (output):

| Name | Type | Value |
|------|------|-------|
| AuditID | String | {generated GUID} |

6. Add flow actions:
   - **Initialize variable**: `AuditID` = `generateUUID()`
   - **Create a record** (Dataverse):
     - Table: `Audit Log`
     - Populate:
       - AuditID: `variables('AuditID')`
       - Timestamp: `now()`
       - UserID: `user('id')`
       - ActionType: `inputs('ActionType')`
       - TargetEntity: `inputs('TargetEntity')`
       - OperationDetails: `inputs('OperationDetails')`
       - Status: `inputs('Status')`
       - ErrorMessage: `inputs('ErrorMessage')`
   - **Return output**: `AuditID` = `variables('AuditID')`

7. **Save**

**Acceptance**: Shared flow created; can be called from other flows

---

#### T026: Create Shared Flow "Update-FormStatus"
**Description**: Reusable action to update FormSubmission status

**Steps**:
1. Power Automate → **Shared cloud flows** → **New**
2. Name: `Update-FormStatus`
3. Add **Input parameters**:

| Name | Type | Required |
|------|------|----------|
| FormID | String | Yes |
| NewStatus | String | Yes |
| Notes | String | No |

4. Add flow actions:
   - **Update a record** (Dataverse):
     - Table: `Form Submission`
     - Record ID: `inputs('FormID')`
     - Update:
       - Status: `inputs('NewStatus')`
       - Metadata: `addProperty(outputs('Get_current_metadata'), 'LastStatusUpdate', now())` (append timestamp)
   - **Return success**

5. **Save**

---

#### T027: Create Error Handling & Retry Logic Template
**Description**: Document retry policy for flows

**Steps**:
1. Create file: `docs/RETRY_POLICY.md`:

```markdown
# Retry Policy for VA Form Processing

## Exponential Backoff Strategy

For transient failures (timeouts, connection errors):

| Attempt | Delay | Max Wait |
|---------|-------|----------|
| 1st retry | 60 seconds | 60s |
| 2nd retry | 120 seconds | 120s |
| 3rd retry | 300 seconds | 300s |
| 4th+ | Fail & Alert | — |

## Configuration in Power Automate

For each HTTP action or connector call:
1. Click action → **Settings**
2. Set **Retry policy**:
   - **Type**: Exponential
   - **Interval**: 60
   - **Maximum retries**: 3
   - **Multiplier**: 2.0

## Audit Logging for Retries

Log each retry attempt to AuditLog:
- ActionType: "RetryAttempt"
- OperationDetails: {OriginalError, RetryCount, NextRetryTime}
- Status: "Retry"
```

2. Commit to repo

**Acceptance**: Retry policy documented

---

#### T028: Document Contact Matching Algorithm
**Steps**:
1. Create file: `docs/CONTACT_MATCHING_ALGORITHM.md`:

```markdown
# Contact Matching Algorithm

## Logic

### Primary Match (SSN)
IF ClaimantSSN confidence ≥90%:
  QUERY Contacts WHERE ssn_encrypted = hash(ClaimantSSN)
  CONFIDENCE: 95%+ (SSN is globally unique)

### Secondary Match (Name + DOB)
ELSE IF ClaimantFullName confidence ≥90% AND ClaimantDateOfBirth confidence ≥90%:
  QUERY Contacts WHERE FirstName + LastName FUZZY_MATCH ClaimantFullName
    AND birthdate = ClaimantDateOfBirth
  CONFIDENCE: 85–90%

### Tertiary Match (Name only)
ELSE IF ClaimantFullName confidence ≥80%:
  QUERY Contacts WHERE FirstName + LastName CONTAINS ClaimantFullName
  CONFIDENCE: 60–75% (high false positive risk)
  → FLAG FOR MANUAL REVIEW

## Implementation in Power Automate

Use "Compose" actions + conditions:
1. Extract ClaimantSSN from ExtractionResult
2. IF ClaimantSSN exists:
   a. Query Contacts by SSN (hash comparison)
   b. IF match found: Store ContactID
3. ELSE IF ClaimantFullName exists:
   a. Query Contacts by name (fuzzy match)
   b. IF match found: Store ContactID
4. ELSE: Set ContactID = null, flag "UnmatchedContact"
```

2. Commit

**Acceptance**: Algorithm documented

---

#### T029: Prepare Contact Matching Reference Data
**Steps**:
1. In Dataverse, verify **Contacts** table exists (should be built-in)
2. Create reference data (test contacts for demo):
   - Export or create 5–10 test contact records with:
     - FirstName, LastName
     - Email
     - ssn_encrypted (placeholder)
     - birthdate
3. Document in `training-data/TEST_CONTACTS.csv`:

```
FirstName, LastName, Email, SSN_Placeholder, BirthDate
John, Smith, john.smith@va.gov, 123-45-6789, 1960-01-15
Mary, Johnson, mary.johnson@va.gov, 234-56-7890, 1965-03-22
...
```

4. Commit

**Acceptance**: Test contacts created; reference data ready

---

### Phase 2 Checkpoint

✅ **Foundational systems ready**
- [ ] All 5 Dataverse tables created (FormSubmission, ExtractionResult, CorrectionRecord, AuditLog, D365WriteEvent)
- [ ] Table relationships configured
- [ ] Auditing enabled on all tables
- [ ] AI Builder model trained & published (60–75% accuracy confirmed)
- [ ] Shared flows created (`Log-Audit-Event`, `Update-FormStatus`)
- [ ] Error handling policy documented
- [ ] Contact matching algorithm documented
- [ ] Test contacts created

**Next**: Proceed to Phase 3–5 (Core features can now be built in parallel)

---

## Phase 3–5: Core Features (Parallel Implementation)

After Phase 2 completes, Teams can work in parallel:
- **Team A**: Phase 3 - Intake flow (T030–T037)
- **Team B**: Phase 4 - Extraction flow (T038–T046)
- **Team C**: Phase 5 - D365 Write flow (T047–T057)

Each phase follows the same structure:
1. Create Power Automate cloud flow
2. Add steps (connectors, conditions, loops)
3. Implement error handling
4. Test end-to-end

### Phase 3: User Story 1 - Intake Flow (T030–T037)

**[Detailed steps for T030–T037 available in tasks.md]**

### Phase 4: User Story 2 - Extraction Flow (T038–T046)

**[Detailed steps for T038–T046 available in tasks.md]**

### Phase 5: User Story 4 - D365 Write Flow (T047–T057)

**[Detailed steps for T047–T057 available in tasks.md]**

---

## Phase 6–7: Extended Features (Sequential after Core)

### Phase 6: User Story 3 - Correction UI (T058–T067)
**Description**: Power Apps canvas app for manual field correction

### Phase 7: User Story 5 - Analytics (T068–T075)
**Description**: Power BI dashboard for extraction metrics

---

## Phase 8: Polish & Testing (T076–T088)

### Manual Test Scenarios

All tests defined in tasks.md (T089–T098):
1. Happy path (auto-approve)
2. Human review path
3. Manual intake path
4. Duplicate detection
5. Malformed file handling
6. D365 write failure & retry
7. Contact matching
8. Batch processing
9. Power Apps validation
10. Analytics metrics

---

## Success Metrics

| Metric | Target | Status |
|--------|--------|--------|
| **AI Extraction Accuracy** | ≥90% | ⏳ To be tested in Phase 4 |
| **Extraction Latency** | <5s per form | ⏳ To be tested |
| **D365 Write Latency** | <2s per record | ⏳ To be tested |
| **Intake Throughput** | ≥5 forms/min | ⏳ To be tested |
| **Manual Review SLA** | <4 hours per form | ⏳ To be measured |
| **Audit Coverage** | 100% of operations | ⏳ To be verified |
| **Test Scenario Pass Rate** | 10/10 (100%) | ⏳ To be tested in Phase 8 |

---

## Support & Troubleshooting

**Common Issues**:

1. **AI Builder Model Not Appearing in Power Automate**
   - Verify model is **published** (not just saved as draft)
   - Refresh Power Automate page
   - Verify AI Builder connector is enabled in tenant

2. **Dataverse Connection Fails**
   - Verify environment URL is correct
   - Verify user has Dataverse access
   - Check Power Automate connector settings

3. **Flow Execution Timeout**
   - Reduce batch size (process fewer forms at once)
   - Optimize queries (add filters to reduce data volume)
   - Check for infinite loops in conditions

4. **Contact Matching Returns No Results**
   - Verify Contacts table has test data
   - Check SSN/name formatting matches expected values
   - Verify query conditions in flow

---

## Next Steps

1. ✅ **Phase 1**: Complete environment setup (2–3 hrs)
2. ✅ **Phase 2**: Build Dataverse schema + train AI Builder (6–8 hrs)
3. 🔄 **Phase 3–5**: Implement core flows in parallel (8–10 hrs)
4. ⏳ **Phase 6–7**: Add correction UI + analytics (5–7 hrs)
5. ⏳ **Phase 8**: Polish + end-to-end testing (2–3 hrs)

**Total Estimated Time**: 27–31 hours (1 developer); 10–14 hours (3 developers parallel)

---

**Document Version**: 1.0.0  
**Last Updated**: 2026-04-24  
**Status**: Implementation In Progress  
**Next Update**: After Phase 1 completion
