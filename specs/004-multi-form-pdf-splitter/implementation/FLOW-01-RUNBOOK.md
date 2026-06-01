# Runbook: Flow-01-Batch-PDF-Splitter

**Feature**: 004-multi-form-pdf-splitter  
**Tasks Covered**: T013–T033 (Phase 3: US1 + Phase 4: US2 + Phase 5: US3)  
**Estimated Build Time**: 4–5 hours  
**Generated**: 2025-07-17  
**Version**: 1.0.0

---

## Prerequisites — Must Complete Before Starting

| Requirement | Verification |
|---|---|
| Phase 1 (Setup) complete | SharePoint `Batches/Incoming/` folder exists; Azure Function app deployed |
| Phase 2 (Schema) complete | `BatchSubmission` table in Dataverse; `FormSubmission` has `BatchID` and `FormIndexInBatch` nullable columns |
| `VA-Form-Intake-Pipeline` (Flow 1) is **ON** | Verified via Power Automate → Flows list |
| Azure Function app deployed and accessible | Function base URL and key documented (see [FLOW-01-AZURE-FUNCTION-RUNBOOK.md](FLOW-01-AZURE-FUNCTION-RUNBOOK.md)) |
| Reference values documented | SharePoint site URL, `FormIntake` library internal name, `Batches/Incoming/` folder path from T005 |

---

## Flow Overview

```
TRIGGER: SharePoint file created in FormIntake/Batches/Incoming/
  │
  ├─ STEP 0: Initialize variables
  │
  ├─ STEP 1: Get file content (binary PDF)
  │
  ├─ STEP 2: HTTP — Azure Function GetPageCount → varPageCount
  │
  ├─ STEP 2 (Validation):
  │   ├─ 2a. Extension check (.pdf only)
  │   ├─ 2b. File size check (≤ 150MB)
  │   ├─ 2c. Page count = 2 → Mode 1 Bypass (Move to FormIntake/ → Terminate)
  │   ├─ 2d. Odd page count → set varValidationFailReason
  │   ├─ 2e. Max batch size ≤ 250 forms
  │   └─ 2f. Duplicate detection (Dataverse query)
  │
  ├─ STEP 2 Error Handler: Is varValidationFailReason empty?
  │   └─ TRUE (failed): Create ValidationFailed BatchSubmission → Notify → Audit → Terminate
  │
  ├─ STEP 2 Success: Audit log (BatchValidation success)
  │
  ├─ STEP 3: Create BatchSubmission record (BatchStatus = Splitting)
  │
  ├─ STEP 4a: Create SharePoint batch subfolder
  │
  ├─ STEP 4b: Initialize split loop variables
  │
  ├─ STEP 4c: SPLIT LOOP (Do Until varFormIndex > TotalFormCount)
  │   ├─ Calculate StartPage / EndPage
  │   ├─ HTTP — Azure Function SplitPDF
  │   ├─ SharePoint Create file (split PDF in batch subfolder)
  │   ├─ Append filename to varSplitFilePaths
  │   ├─ Audit log: BatchFormDeposit (per form, satisfies SC-005)
  │   ├─ Increment varFormIndex
  │   └─ ERROR HANDLER: SplitFailed → Notify → Audit → Terminate (partial files preserved)
  │
  ├─ STEP 4e: Update BatchSubmission (BatchStatus = SplittingComplete)
  │
  ├─ STEP 5: Move original to batch subfolder (_original_ prefix)
  │
  └─ STEP 6: FEEDING LOOP (Apply to each in varSplitFilePaths)
      ├─ Move split PDF from batch subfolder → FormIntake/ root
      ├─ Delay 5 seconds
      └─ Audit log: BatchFormDeposit (fed to pipeline)
```

---

## Part 1: Create the Flow

### Action: Create Flow Canvas (T013)

1. Navigate to **Power Automate** → **+ Create** → **Automated cloud flow**
2. Set name: `Flow-01-Batch-PDF-Splitter`
3. Choose trigger: Search for **SharePoint** → select **When a file is created (properties only)**
4. Click **Create**
5. ⚠️ **DO NOT ENABLE** the flow yet. Keep it in Draft/Off state until T022 is complete and fully tested.

---

## Part 2: Configure the Trigger (T014)

### Action: SharePoint — When a file is created (properties only)

Configure the trigger that was added in Part 1:

| Field | Value |
|---|---|
| **Site Address** | `{Your SharePoint site URL}` (from T005 reference notes) |
| **Library Name** | `FormIntake` |
| **Folder** | `/Batches/Incoming` |

> ⚠️ **Critical**: The folder must be exactly `/Batches/Incoming` (not `/FormIntake/Batches/Incoming`). The folder path in the SharePoint trigger is relative to the library root. If your SharePoint library is named differently, use the internal name from T005.

**Verification**: Save and test the trigger by uploading a dummy file to `Batches/Incoming/`. The trigger should fire. Then delete the test file.

---

### Action: SharePoint — Get file content

Immediately after the trigger, add a **Get file content** action:

1. Click **+ New step** → search **SharePoint** → select **Get file content**
2. Configure:

| Field | Value |
|---|---|
| **Site Address** | `{Your SharePoint site URL}` |
| **File Identifier** | Select from dynamic content: **Identifier** (from the trigger output) |

This loads the binary PDF content that will be passed to the Azure Function.

---

## Part 3: Initialize Variables (Step 0)

Add the following **Initialize variable** actions **before** the Azure Function HTTP action. Add each as a separate step:

> In Power Automate, add via **+ New step** → **Variables** → **Initialize variable**

| Variable Name | Type | Initial Value | Expression to Use |
|---|---|---|---|
| `varFileName` | String | (expression) | `triggerOutputs()?['body/Name']` |
| `varFileSize` | Integer | (expression) | `triggerOutputs()?['body/Size']` |
| `varPageCount` | Integer | `0` | (set to 0; will be overwritten by Azure Function) |
| `varValidationFailReason` | String | `""` | (empty string) |
| `varBatchDisplayID` | String | `""` | (empty string) |
| `varBatchID` | String | `""` | (empty string) |
| `varBatchFolderPath` | String | `""` | (empty string) |
| `varTotalFormCount` | Integer | `0` | (set to 0) |
| `varFormIndex` | Integer | `1` | (start at 1) |
| `varLastSuccessfulIndex` | Integer | `0` | (start at 0) |
| `varSplitFilePaths` | Array | `[]` | (empty array — use `[]` in Expression tab) |
| `varCurrentSplitFileName` | String | `""` | (empty string) |
| `varUploadedBy` | String | (expression) | `triggerOutputs()?['headers']?['x-ms-user-name']` |

---

## Part 4: Azure Function — Get PDF Page Count (T015)

### Action: HTTP — Call Azure Function (GetPageCount)

1. Click **+ New step** → search **HTTP** → select **HTTP** action
2. Name it: `Call Azure Function GetPageCount`
3. Configure:

| Field | Value |
|---|---|
| **Method** | `POST` |
| **URI** | `@{parameters('AzureFunctionBaseUrl')}/api/pdf/page-count` |
| **Headers** | `Content-Type: application/json` |
| **Headers** | `x-functions-key: @{parameters('AzureFunctionKey')}` |
| **Body** | `{ "fileName": "@{variables('varFileName')}", "fileContent": "@{outputs('Get_file_content')?['body/$content']}" }` |

> **Parameters**: Add `AzureFunctionBaseUrl` and `AzureFunctionKey` as flow parameters (or environment variables). See [FLOW-01-AZURE-FUNCTION-RUNBOOK.md](FLOW-01-AZURE-FUNCTION-RUNBOOK.md) for deployment steps and how to obtain these values.
> **Response**: The Azure Function returns `{ "pageCount": N }` where N is the total page count of the uploaded PDF.

3. After the HTTP action, add a **Set variable** action:
   - Variable: `varPageCount`
   - Value (Expression): `body('Call_Azure_Function_GetPageCount')?['pageCount']`

4. Add a **Set variable** action:
   - Variable: `varTotalFormCount`
   - Value (Expression): `div(variables('varPageCount'), 2)`

---

## Part 5: Validation Rules (T016–T021)

> Add all validation conditions as sequential **Condition** actions. Each failed condition sets `varValidationFailReason` and then execution continues to the master error check (Part 6). Do NOT use nested conditions for validation — keep them flat and sequential.

### 5.1 — File Extension Check (T016)

1. Add **Condition** action
2. **Left side** (Expression): `toLower(last(split(variables('varFileName'), '.')))`
3. **Operator**: `is equal to`
4. **Right side** (value): `pdf`
5. **True branch**: Empty (do nothing — file is valid PDF)
6. **False branch**: Add **Set variable**:
   - Variable: `varValidationFailReason`
   - Value: `Invalid file type: only PDF files are accepted. Please upload a .pdf file.`

---

### 5.2 — File Size Check (T017)

1. Add **Condition** action
2. **Left side** (Expression): `variables('varFileSize')`
3. **Operator**: `is less than or equal to`
4. **Right side** (value): `157286400`
5. **True branch**: Empty
6. **False branch**: Add **Set variable**:
   - Variable: `varValidationFailReason`
   - Value (Expression): `concat('File exceeds 150MB limit (', string(variables('varFileSize')), ' bytes received). Maximum allowed: 157,286,400 bytes.')`

---

### 5.3 — Mode 1 Bypass: Exactly 2 Pages (T018)

1. Add **Condition** action
2. **Left side** (Expression): `variables('varPageCount')`
3. **Operator**: `is equal to`
4. **Right side** (value): `2`
5. **True branch** (2-page PDF → route to Mode 1):
   - Add **SharePoint — Move file** action:
     - **Site**: `{Your SharePoint site URL}`
     - **File to Move** (Expression): `triggerOutputs()?['body/{Path}']`  
       *(or use the server-relative URL: `concat('/sites/{site}/FormIntake/Batches/Incoming/', variables('varFileName'))`)*
     - **Destination Site**: `{Your SharePoint site URL}`
     - **Destination Folder**: `FormIntake` (root of the library, not a subfolder)
   - Add **Terminate** action:
     - Status: `Succeeded`
     - *(No BatchSubmission record is created for Mode 1 bypass — this is correct)*
6. **False branch**: Empty (continue validation for multi-form batches)

---

### 5.4 — Odd Page Count Rejection (T019)

> Add this AFTER the Mode 1 bypass (T018). At this point we know pageCount > 2.

1. Add **Condition** action
2. **Left side** (Expression): `mod(variables('varPageCount'), 2)`
3. **Operator**: `is equal to`
4. **Right side** (value): `0`
5. **True branch**: Empty (even page count — valid batch)
6. **False branch**: Add **Set variable**:
   - Variable: `varValidationFailReason`
   - Value (Expression): `concat('Odd page count (', string(variables('varPageCount')), ' pages). Manual review required — possible incomplete form scan or cover sheet included.')`

---

### 5.5 — Max Batch Size (T020)

1. Add **Condition** action
2. **Left side** (Expression): `div(variables('varPageCount'), 2)`
3. **Operator**: `is less than or equal to`
4. **Right side** (value): `250`
5. **True branch**: Empty (within limit)
6. **False branch**: Add **Set variable**:
   - Variable: `varValidationFailReason`
   - Value (Expression): `concat('Batch exceeds 250-form limit (', string(div(variables('varPageCount'), 2)), ' forms detected). Please split into smaller uploads of 250 forms or fewer.')`

---

### 5.6 — Duplicate Detection (T021)

1. Add **Dataverse — List rows** action
2. Configure:

| Field | Value |
|---|---|
| **Table Name** | `Batch Submissions` |
| **Filter rows** (OData) | `cr_sourcefilename eq '@{variables(''varFileName'')}' and cr_sourcefilesizebytes eq @{variables('varFileSize')} and cr_sourcefilepagecount eq @{variables('varPageCount')}` |
| **Top count** | `1` |

3. After the List rows action, add a **Condition**:
   - **Left side** (Expression): `length(body('List_rows_duplicate_check')?['value'])`  
     *(Replace `List_rows_duplicate_check` with the actual action name)*
   - **Operator**: `is greater than`
   - **Right side**: `0`
   - **True branch** (duplicate found): Add **Set variable**:
     - Variable: `varValidationFailReason`
     - Value (Expression): `concat('Duplicate batch detected. This file is already in progress as Batch ', first(body('List_rows_duplicate_check')?['value'])?['cr_batchdisplayid'], '. If this is a new upload, rename the file and try again.')`
   - **False branch**: Empty

---

## Part 6: Validation Failure Handler (T022)

### Action: Condition — Is Validation Failed?

1. Add **Condition** action
2. **Left side** (Expression): `empty(variables('varValidationFailReason'))`
3. **Operator**: `is equal to`
4. **Right side**: `false` (i.e., varValidationFailReason is NOT empty)
5. **True branch** (validation failed — take these actions):

   a. **Dataverse — Add a new row** on `Batch Submissions`:
   
   | Field | Value |
   |---|---|
   | Batch Display ID | `BATCH-FAILED-@{formatDateTime(utcNow(),'yyyyMMddHHmmss')}` |
   | Source File Name | `@{variables('varFileName')}` |
   | Source File Size Bytes | `@{variables('varFileSize')}` |
   | Source File Page Count | `@{variables('varPageCount')}` |
   | Total Form Count | `0` |
   | Upload Timestamp | `@{utcNow()}` |
   | Batch Status | `ValidationFailed` |
   | Error Details | `@{variables('varValidationFailReason')}` |
   | Uploaded By | `@{variables('varUploadedBy')}` |
   | Last Progress Timestamp | `@{utcNow()}` |

   b. **Call child flow / HTTP action — Notification-Router subflow**:
   - Recipient: `@{variables('varUploadedBy')}`
   - Subject: `Batch Upload Rejected — Action Required`
   - Message: `Your batch PDF upload was rejected. Reason: @{variables('varValidationFailReason')}`
   - Severity: `Warning`

   c. **Call child flow — Audit-Event-Logger subflow**:
   - ActionType: `BatchValidation`
   - EntityID: *(output row ID from the Add a new row action above)*
   - Result: `Failed`
   - Details: `@{variables('varValidationFailReason')}`

   d. **Terminate** action:
   - Status: `Succeeded`  
     *(Use Succeeded, not Failed — this is an expected business outcome, not an error)*

6. **False branch** (validation passed — continue to T023):
   - Empty *(do nothing here; flow continues)*

---

## Part 7: Validation Success Audit Log (T023)

1. Add **Call child flow — Audit-Event-Logger**:
   - ActionType: `BatchValidation`
   - Result: `Success`
   - Details (Expression): `concat('Validation passed. PageCount=', string(variables('varPageCount')), ', FormCount=', string(div(variables('varPageCount'), 2)), ', FileName=', variables('varFileName'))`

---

## Part 8: Create BatchSubmission Record (T024)

### Action: Dataverse — Add a new row on Batch Submissions

| Field | Expression / Value |
|---|---|
| **Batch Display ID** | `@{concat('BATCH-', formatDateTime(utcNow(),'yyyyMMdd'), '-', padLeft(string(rand(1,999)),3,'0'))}` |
| **Source File Name** | `@{variables('varFileName')}` |
| **Source File Size Bytes** | `@{variables('varFileSize')}` |
| **Source File Page Count** | `@{variables('varPageCount')}` |
| **Total Form Count** | `@{div(variables('varPageCount'), 2)}` |
| **Uploaded By** | `@{variables('varUploadedBy')}` |
| **Upload Timestamp** | `@{utcNow()}` |
| **Batch Status** | `Splitting` |
| **Split Start Timestamp** | `@{utcNow()}` |
| **Last Progress Timestamp** | `@{utcNow()}` |
| **SharePoint Batch Folder Path** | `@{concat('FormIntake/Batches/PLACEHOLDER/')}` *(update after T025)* |

After the action completes:
- Add **Set variable** → `varBatchID` → Expression: `outputs('Add_a_new_row_BatchSubmission')?['body/cr_batchsubmissionid']`
- Add **Set variable** → `varBatchDisplayID` → Expression: `outputs('Add_a_new_row_BatchSubmission')?['body/cr_batchdisplayid']`
- Add **Set variable** → `varTotalFormCount` → Expression: `div(variables('varPageCount'), 2)`

Then **Call child flow — Audit-Event-Logger**:
- ActionType: `BatchUpload`
- EntityID: `@{variables('varBatchID')}`
- Details: `Batch upload received: @{variables('varFileName')}, @{variables('varPageCount')} pages, @{variables('varTotalFormCount')} forms`

---

## Part 9: Create SharePoint Batch Subfolder (T025)

### Action: SharePoint — Create new folder

| Field | Value |
|---|---|
| **Site Address** | `{Your SharePoint site URL}` |
| **List or Library Name** | `FormIntake` |
| **Folder Path** | `@{concat('Batches/', variables('varBatchDisplayID'))}` |

After the action:
- Add **Set variable** → `varBatchFolderPath` → Value: `@{concat('FormIntake/Batches/', variables('varBatchDisplayID'), '/')}`
- Add **Dataverse — Update a row** to update `SharePointBatchFolderPath` on the BatchSubmission record:
  - Row ID: `@{variables('varBatchID')}`
  - SharePoint Batch Folder Path: `@{variables('varBatchFolderPath')}`

---

## Part 10: Initialize Split Loop Variables (T026)

> These variables were already initialized in Part 3 with correct initial values (`varFormIndex = 1`, `varLastSuccessfulIndex = 0`, `varSplitFilePaths = []`). No additional initialization needed here.

### Action: Audit-Event-Logger — BatchSplitStart

Call the Audit-Event-Logger subflow:
- ActionType: `BatchSplitStart`
- EntityID: `@{variables('varBatchID')}`
- Details (Expression): `concat('Splitting ', string(variables('varTotalFormCount')), ' forms from file: ', variables('varFileName'))`

---

## Part 11: Split Loop — Azure Function Split PDF Per Form (T027)

### Action: Do Until Loop

1. Add **Do Until** action
2. **Condition**: `varFormIndex` **is greater than** `varTotalFormCount`
   - Expression: `greater(variables('varFormIndex'), variables('varTotalFormCount'))`

Inside the loop, add the following actions in order:

#### 11.1 — Calculate Page Range

Add **Compose** action (or Scope):
- Name it: `Calculate Page Range`
- No output needed — calculate inline in subsequent actions

#### 11.2 — Call Azure Function: Split PDF

Add **HTTP** action:

- Name it: `Call Azure Function SplitPDF`

| Field | Expression |
|---|---|
| **Method** | `POST` |
| **URI** | `@{parameters('AzureFunctionBaseUrl')}/api/pdf/split` |
| **Headers** | `Content-Type: application/json` |
| **Headers** | `x-functions-key: @{parameters('AzureFunctionKey')}` |
| **Body** | `{ "fileName": "@{variables('varFileName')}", "fileContent": "@{outputs('Get_file_content')?['body/$content']}", "startPage": @{add(mul(sub(variables('varFormIndex'), 1), 2), 1)}, "endPage": @{mul(variables('varFormIndex'), 2)} }` |

> **Response**: The Azure Function returns `{ "fileContent": "<base64-encoded PDF>" }` containing the 2-page split PDF. See [FLOW-01-AZURE-FUNCTION-RUNBOOK.md](FLOW-01-AZURE-FUNCTION-RUNBOOK.md) for the full request/response contract.

#### 11.3 — Build Split Filename

Add **Set variable** → `varCurrentSplitFileName`:
- Expression: `concat(variables('varBatchDisplayID'), '-', padLeft(string(variables('varFormIndex')), 3, '0'), '.pdf')`

#### 11.4 — Save Split PDF to Batch Subfolder

Add **SharePoint — Create file** action:

| Field | Expression / Value |
|---|---|
| **Site Address** | `{Your SharePoint site URL}` |
| **Folder Path** | `@{concat('/FormIntake/Batches/', variables('varBatchDisplayID'))}` |
| **File Name** | `@{variables('varCurrentSplitFileName')}` |
| **File Content** | Expression: `base64ToBinary(body('Call_Azure_Function_SplitPDF')?['fileContent'])` |

#### 11.5 — Track Split File Path

Add **Append to array variable** → `varSplitFilePaths`:
- Value: `@{variables('varCurrentSplitFileName')}`

#### 11.6 — Update Last Successful Index

Add **Set variable** → `varLastSuccessfulIndex`:
- Expression: `variables('varFormIndex')`

#### 11.7 — Audit Log: Per-Form Split

Add **Call child flow — Audit-Event-Logger**:
- ActionType: `BatchFormDeposit`
- EntityID: `@{variables('varBatchID')}`
- Details (Expression): `concat('Form ', string(variables('varFormIndex')), ' of ', string(variables('varTotalFormCount')), ' split to ', variables('varCurrentSplitFileName'))`

#### 11.8 — Increment Form Index

Add **Set variable** → `varFormIndex`:
- Expression: `add(variables('varFormIndex'), 1)`

---

## Part 12: Split Loop Error Handling (T028)

### Configure Run After for the Split PDF HTTP Action

1. In the split loop, right-click (or use the `...` menu) on the **Call Azure Function SplitPDF** action
2. Select **Configure run after**
3. Enable: **has failed** and **has timed out**
4. This creates an error branch that runs when the Split PDF HTTP action fails

Inside the error branch:

a. **Dataverse — Update a row** on Batch Submissions:
   - Row ID: `@{variables('varBatchID')}`
   - Batch Status: `SplitFailed`
   - Error Details (Expression): `concat('Split failed at form ', string(add(variables('varLastSuccessfulIndex'),1)), ' of ', string(variables('varTotalFormCount')), '. Error: ', actions('Call_Azure_Function_SplitPDF')?['error']?['message'])`
   - Last Successful Split Index: `@{variables('varLastSuccessfulIndex')}`
   - Split End Timestamp: `@{utcNow()}`

b. **Call child flow — Notification-Router**:
   - Recipients: supervisor email AND `@{variables('varUploadedBy')}`
   - Subject: `⚠️ Batch Split Failed — Operator Action Required`
   - Message (Expression): `concat('Split failed at form ', string(add(variables('varLastSuccessfulIndex'),1)), ' of ', string(variables('varTotalFormCount')), '. ', string(variables('varLastSuccessfulIndex')), ' form(s) have been preserved in SharePoint folder: ', variables('varBatchFolderPath'), '. Batch ID: ', variables('varBatchDisplayID'), '. Please investigate and retry.')`
   - Severity: `Error`

c. **Call child flow — Audit-Event-Logger**:
   - ActionType: `BatchSplitFailed`
   - EntityID: `@{variables('varBatchID')}`
   - Details: (same error message as above)

d. **Terminate**:
   - Status: `Failed`
   - Message: (same error message)

> ⚠️ **Preservation guarantee**: The files already saved to `FormIntake/Batches/{BatchDisplayID}/` in previous loop iterations are NOT deleted. The error handler only updates the BatchSubmission status — it does not remove any files.

---

## Part 13: Update BatchSubmission — SplittingComplete (T029)

Add after the Do Until loop (on the success path):

### Action: Dataverse — Update a row

- Row ID: `@{variables('varBatchID')}`
- Batch Status: `SplittingComplete`
- Split End Timestamp: `@{utcNow()}`
- Last Progress Timestamp: `@{utcNow()}`

### Action: Audit-Event-Logger — BatchSplitComplete

- ActionType: `BatchSplitComplete`
- EntityID: `@{variables('varBatchID')}`
- Details (Expression): `concat(string(variables('varTotalFormCount')), ' forms split successfully from ', variables('varFileName'), '. Files saved to ', variables('varBatchFolderPath'))`

---

## Part 14: Retain Original PDF (T030)

### Action: SharePoint — Move file

| Field | Expression / Value |
|---|---|
| **Current site address** | `{Your SharePoint site URL}` |
| **File to move** | Server-relative URL of the original file in `Batches/Incoming/` |
| **Destination site address** | `{Your SharePoint site URL}` |
| **Destination folder** | `@{concat('/FormIntake/Batches/', variables('varBatchDisplayID'))}` |
| **Destination file name** | `@{concat('_original_', variables('varFileName'))}` |

After the move succeeds:

### Action: Dataverse — Update a row

- Row ID: `@{variables('varBatchID')}`
- Original File SharePoint ID: *(output of the Move file action — the new SharePoint item ID)*

---

## Part 15: Pipeline Feeding Loop (T032–T033)

### Action: Dataverse — Update a row (set Feeding status)

- Row ID: `@{variables('varBatchID')}`
- Batch Status: `Feeding`
- Last Progress Timestamp: `@{utcNow()}`

### Action: Apply to each — over varSplitFilePaths

1. Add **Apply to each** action
2. Select output from: `varSplitFilePaths`

Inside the loop:

#### 15.1 — Move Split PDF to FormIntake/ Root

Add **SharePoint — Move file** action:

| Field | Expression / Value |
|---|---|
| **File to move** | Server-relative URL: `@{concat('/FormIntake/Batches/', variables('varBatchDisplayID'), '/', items('Apply_to_each'))}` |
| **Destination folder** | `/FormIntake` (the library root, NOT a subfolder) |
| **Destination file name** | `@{items('Apply_to_each')}` |

> **Why move and not copy?** Moving avoids duplicate files. The file is removed from the batch subfolder and placed in `FormIntake/` root, where the existing Flow 1 trigger will detect it.

#### 15.2 — 5-Second Delay

Add **Delay** action:
- Unit: `Second`
- Count: `5`

> **Do not remove this delay.** It prevents multiple split PDFs from hitting the SharePoint trigger polling window simultaneously and overwhelming the existing pipeline queue.

#### 15.3 — Audit Log: BatchFormDeposit (Fed to Pipeline)

Add **Call child flow — Audit-Event-Logger**:
- ActionType: `BatchFormDeposit`
- EntityID: `@{variables('varBatchID')}`
- Details (Expression): `concat(items('Apply_to_each'), ' deposited to FormIntake/ root for pipeline processing')`

---

## Part 16: Final Cleanup and Activation

After the Apply to each loop:

### Update Final BatchSubmission Status

Add **Dataverse — Update a row**:
- Row ID: `@{variables('varBatchID')}`
- Batch Status: `SplittingComplete`  
  *(Note: status moves from Feeding back to SplittingComplete to indicate the feed is done; Flow-01B will update this further as child forms process)*
- Last Progress Timestamp: `@{utcNow()}`

### Enable the Flow (After T022 is Verified)

1. Navigate to **Power Automate** → **Flows** → `Flow-01-Batch-PDF-Splitter`
2. Click **Turn on**
3. Perform the Phase 3 checkpoint test before proceeding to Phase 4 tasks

---

## Phase 3 Checkpoint Test (After T023)

Upload test files to `FormIntake/Batches/Incoming/` and verify:

| Test | Upload | Expected Result |
|---|---|---|
| Mode 1 Bypass | 2-page PDF | File moved to `FormIntake/` root; no BatchSubmission created; Flow 1 triggers |
| Valid Batch | 6-page PDF | Validation passes; BatchSubmission created with `Splitting` status |
| Odd Pages | 5-page PDF | `ValidationFailed` BatchSubmission; uploader notified; no split files |
| Oversized | File > 150MB | `ValidationFailed`; uploader notified with file size in message |

## Phase 4 Checkpoint Test (After T031)

| Test | Upload | Expected Result |
|---|---|---|
| 10-page PDF (5 forms) | Valid batch | 5 files: `BATCH-*-001.pdf` through `BATCH-*-005.pdf` in batch subfolder |
| Check file count | — | Exactly 5 split PDFs, each 2 pages (verify by opening) |
| Check original | — | `_original_*.pdf` in batch subfolder |
| Check status | — | `BatchSubmission.BatchStatus = SplittingComplete` |

## Phase 5 Checkpoint Test (After T037)

| Test | Upload | Expected Result |
|---|---|---|
| 6-page batch | Valid batch | 3 split PDFs moved to `FormIntake/` root with 5-second intervals |
| Flow 1 triggers | — | 3 `FormSubmission` records created; each has `BatchID` and `FormIndexInBatch` set |
| Mode 1 regression | Direct single-form upload to `FormIntake/` | `FormSubmission.BatchID = null`; pipeline runs normally |

---

**Version**: 1.0.0 | **Generated**: 2025-07-17  
**Status**: Complete runbook — ready for manual implementation  
**Next**: After enabling Flow-01, proceed to [FLOW-01B-RUNBOOK.md](FLOW-01B-RUNBOOK.md) for status aggregation.
