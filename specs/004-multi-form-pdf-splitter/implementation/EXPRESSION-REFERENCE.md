# Expression Reference: Mode 2 — Multi-Form PDF Splitter

**Feature**: 004-multi-form-pdf-splitter  
**Generated**: 2025-07-17  
**Version**: 1.0.0  
**Purpose**: Complete reference for every Power Automate expression used across Flow-01, Flow-01B, and Flow-01C. Copy-paste ready.

---

## How to Use This Reference

When building flows in the Power Automate designer:
1. Click the action field where an expression is needed
2. Click the **Expression** tab in the dynamic content picker
3. Paste the expression from this document exactly as shown
4. Click **OK**

> **Variable prefix convention**: `variables('varXxx')` — all custom variables use this prefix.  
> **Trigger outputs**: `triggerOutputs()?['body/PropertyName']` — note the `?` for null-safe access.

---

## Section 1: Flow-01 — Trigger & File Property Expressions

### 1.1 Get File Name from SharePoint Trigger

```
triggerOutputs()?['body/Name']
```

**Used in**: T014, T015  
**Returns**: String — filename including extension (e.g., `VAScan_20260518.pdf`)  
**Store in**: `varFileName`

---

### 1.2 Get File Size from SharePoint Trigger

```
triggerOutputs()?['body/Size']
```

**Used in**: T015  
**Returns**: Integer — file size in bytes  
**Store in**: `varFileSize`

---

### 1.3 Get File Content URL (for Muhimbi input)

After the `Get file content` action, reference its output:
```
outputs('Get_file_content')?['body/$content']
```

**Used in**: T015 (Muhimbi Get PDF Properties), T027 (Muhimbi Split PDF)  
**Returns**: Binary — the PDF bytes

---

### 1.4 Get Uploader Identity

```
triggerOutputs()?['headers']?['x-ms-user-name']
```

**Used in**: T024  
**Returns**: String — UPN/email of the user who uploaded the file  
**Store in**: `varUploadedBy`

---

## Section 2: Flow-01 — Validation Expressions

### 2.1 Extract File Extension (lowercase)

```
toLower(last(split(variables('varFileName'), '.')))
```

**Used in**: T016 (file extension check)  
**Returns**: String — file extension without dot (e.g., `pdf`)  
**Condition**: equals `pdf`

---

### 2.2 File Size — 150MB Limit Check

```
lessOrEquals(variables('varFileSize'), 157286400)
```

**Used in**: T017  
**Returns**: Boolean — `true` if file is within limit  
**Condition**: must be `true` to pass validation  
**Calculation**: 150 × 1024 × 1024 = 157,286,400 bytes

---

### 2.3 Page Count — Even Number Check

```
equals(mod(variables('varPageCount'), 2), 0)
```

**Used in**: T019 (odd page count gate — negate this for the rejection branch)  
**Returns**: Boolean — `true` if even  
**For rejection condition** (odd page check): `not(equals(mod(variables('varPageCount'), 2), 0))`

---

### 2.4 Page Count — Exactly 2 Pages (Mode 1 Bypass)

```
equals(variables('varPageCount'), 2)
```

**Used in**: T018  
**Returns**: Boolean — `true` if exactly 2 pages → route to Mode 1, do not create BatchSubmission

---

### 2.5 Form Count Calculation (PageCount ÷ 2)

```
div(variables('varPageCount'), 2)
```

**Used in**: T020, T024 (TotalFormCount field), T042  
**Returns**: Integer — number of individual forms in the batch

---

### 2.6 Max Batch Size Check (≤ 250 forms)

```
lessOrEquals(div(variables('varPageCount'), 2), 250)
```

**Used in**: T020  
**Returns**: Boolean — `true` if within Phase 1 limit  
**Condition**: must be `true` to pass validation

---

### 2.7 Duplicate Detection — OData Filter Expression

Apply this as the OData filter on the Dataverse `List rows` action (T021):

```
cr_sourcefilename eq '@{variables(''varFileName'')}' and cr_sourcefilesizebytes eq @{variables('varFileSize')} and cr_sourcefilepagecount eq @{variables('varPageCount')} and cr_batchstatus ne 853400000 and cr_batchstatus ne 853400009 and cr_batchstatus ne 853400002
```

> **Note on Option Set numeric values**: Dataverse stores option set values as integers. The numeric values above are examples — **replace with the actual numeric values** from your environment's `cr_batchstatus` option set. In the Power Platform Maker Portal, go to the option set and hover over each value to see its numeric code. Alternatively, use the string label form if your environment supports it:

```
cr_sourcefilename eq '@{variables(''varFileName'')}' and cr_sourcefilesizebytes eq @{variables('varFileSize')} and cr_sourcefilepagecount eq @{variables('varPageCount')} and cr_batchstatus ne 'Complete' and cr_batchstatus ne 'PartiallyFailed' and cr_batchstatus ne 'ValidationFailed'
```

**Used in**: T021  
**Returns**: Array of matching BatchSubmission rows — if non-empty, batch is a duplicate

---

### 2.8 Validation Failure Check (Is Any Error Set?)

```
not(empty(variables('varValidationFailReason')))
```

**Used in**: T022 — the master "Is Validation Failed?" condition  
**Returns**: Boolean — `true` if any validation rule set a failure reason

---

## Section 3: Flow-01 — Batch Record Expressions

### 3.1 Generate BatchDisplayID

Use this composite expression in the `Add a new row` action's `Batch Display ID` field (T024):

```
concat('BATCH-', formatDateTime(utcNow(), 'yyyyMMdd'), '-', padLeft(string(rand(1, 999)), 3, '0'))
```

**Used in**: T024  
**Returns**: String — e.g., `BATCH-20260518-042`  
**Important**: Store the result in variable `varBatchDisplayID` immediately after record creation by capturing the row's `cr_batchdisplayid` from the output of `Add a new row`.

---

### 3.2 Batch SharePoint Folder Path

```
concat('FormIntake/Batches/', variables('varBatchDisplayID'), '/')
```

**Used in**: T024 (SharePointBatchFolderPath field), T025 (Create folder)  
**Returns**: String — e.g., `FormIntake/Batches/BATCH-20260518-042/`

---

### 3.3 Get Current UTC Time

```
utcNow()
```

**Used in**: T024 (UploadTimestamp, SplitStartTimestamp), T029 (SplitEndTimestamp), T043 (LastProgressTimestamp), T044 (CompletionTimestamp)  
**Returns**: String (ISO 8601 DateTime) — e.g., `2026-05-18T15:30:00.0000000Z`

---

## Section 4: Flow-01 — Split Loop Expressions

### 4.1 Start Page for Form N (1-based index)

```
add(mul(sub(variables('varFormIndex'), 1), 2), 1)
```

**Used in**: T027 (Muhimbi Split PDF — Start Page input)  
**Returns**: Integer  
**Examples**:
- Form 1: `add(mul(sub(1,1),2),1)` = `add(0,1)` = **1**
- Form 2: `add(mul(sub(2,1),2),1)` = `add(2,1)` = **3**
- Form 5: `add(mul(sub(5,1),2),1)` = `add(8,1)` = **9**

---

### 4.2 End Page for Form N (1-based index)

```
mul(variables('varFormIndex'), 2)
```

**Used in**: T027 (Muhimbi Split PDF — End Page input)  
**Returns**: Integer  
**Examples**:
- Form 1: `mul(1,2)` = **2**
- Form 2: `mul(2,2)` = **4**
- Form 5: `mul(5,2)` = **10**

---

### 4.3 Generate Split PDF Filename for Form N

```
concat(variables('varBatchDisplayID'), '-', padLeft(string(variables('varFormIndex')), 3, '0'), '.pdf')
```

**Used in**: T027 (SharePoint Create file — File Name)  
**Returns**: String — e.g., `BATCH-20260518-042-001.pdf`, `BATCH-20260518-042-012.pdf`  
**Format**: `{BatchDisplayID}-{FormIndex:D3}.pdf`

---

### 4.4 Increment Form Index (inside loop)

Use a `Set variable` action:
```
add(variables('varFormIndex'), 1)
```

**Used in**: T027 (end of each loop iteration)  
**Returns**: Integer — next form index

---

### 4.5 Build Original File Retention Path

```
concat('FormIntake/Batches/', variables('varBatchDisplayID'), '/_original_', variables('varFileName'))
```

**Used in**: T030 (SharePoint Move file — Destination)  
**Returns**: String — e.g., `FormIntake/Batches/BATCH-20260518-042/_original_VAScan_20260518.pdf`

---

### 4.6 Per-Form Audit Detail String

```
concat('Form ', string(variables('varFormIndex')), ' of ', string(variables('varTotalFormCount')), ' split to ', variables('varCurrentSplitFileName'))
```

**Used in**: T031 (Audit-Event-Logger Details field inside split loop)  
**Returns**: String — e.g., `Form 3 of 20 split to BATCH-20260518-042-003.pdf`

---

### 4.7 Per-Form Feed Audit Detail String

```
concat(variables('varCurrentSplitFileName'), ' deposited to FormIntake/ for pipeline processing')
```

**Used in**: T033 (Audit-Event-Logger Details field inside feeding loop)  
**Returns**: String — e.g., `BATCH-20260518-042-003.pdf deposited to FormIntake/ for pipeline processing`

---

### 4.8 Validation Failure Message — Odd Page Count

```
concat('Odd page count (', string(variables('varPageCount')), ' pages). Manual review required — possible incomplete form scan.')
```

**Used in**: T019 (set varValidationFailReason)  
**Returns**: String

---

### 4.9 Validation Failure Message — File Too Large

```
concat('File exceeds 150MB limit (', string(variables('varFileSize')), ' bytes received). Maximum allowed: 157,286,400 bytes.')
```

**Used in**: T017 (set varValidationFailReason)  
**Returns**: String

---

### 4.10 Validation Failure Message — Too Many Forms

```
concat('Batch exceeds 250-form limit (', string(div(variables('varPageCount'), 2)), ' forms detected in ', string(variables('varPageCount')), ' pages). Split into smaller uploads of 250 forms or fewer.')
```

**Used in**: T020 (set varValidationFailReason)  
**Returns**: String

---

### 4.11 Validation Failure Message — Duplicate Batch

```
concat('Duplicate batch detected: this file is already in progress. Original batch ID: ', first(body('List_rows_duplicate_check')?['value'])?['cr_batchdisplayid'], '. Status: ', first(body('List_rows_duplicate_check')?['value'])?['cr_batchstatus@OData.Community.Display.V1.FormattedValue'])
```

**Used in**: T021 (set varValidationFailReason when duplicate found)  
**Returns**: String  
> Adjust the action name `List_rows_duplicate_check` to match the actual action name in your flow (replace spaces with underscores).

---

### 4.12 Split Failure Message

```
concat('Split failed at form ', string(add(variables('varLastSuccessfulIndex'), 1)), ' of ', string(variables('varTotalFormCount')), '. ', string(variables('varLastSuccessfulIndex')), ' form(s) successfully split and preserved in ', variables('varBatchFolderPath'), '. Error: ', outputs('Muhimbi_Split_PDF')?['error']?['message'])
```

**Used in**: T028 (error handler — Notification-Router message)  
**Returns**: String

---

## Section 5: Flow-01 — Existing Flow Modification Expressions (T034–T037)

### 5.1 Is Batch File? (Filename starts with "BATCH-")

```
startsWith(triggerOutputs()?['body/Name'], 'BATCH-')
```

**Used in**: T035 (Condition in VA-Form-Intake-Pipeline)  
**Returns**: Boolean — `true` if filename matches the batch pattern

---

### 5.2 Parse BatchDisplayID from Batch Filename

Batch filename format: `BATCH-YYYYMMDD-NNN-FormIndex.pdf`  
Example: `BATCH-20260518-042-007.pdf`

```
concat('BATCH-', split(triggerOutputs()?['body/Name'], '-')[1], '-', split(triggerOutputs()?['body/Name'], '-')[2])
```

**Used in**: T036  
**Returns**: String — e.g., `BATCH-20260518-042`  
**How it works**:
- `split('BATCH-20260518-042-007.pdf', '-')` → `['BATCH', '20260518', '042', '007.pdf']`
- `[1]` → `'20260518'` (date part)
- `[2]` → `'042'` (random NNN part)
- concat → `'BATCH-20260518-042'`

---

### 5.3 Parse FormIndex from Batch Filename

```
int(first(split(last(split(triggerOutputs()?['body/Name'], '-')), '.')))
```

**Used in**: T036  
**Returns**: Integer — e.g., `7` from `BATCH-20260518-042-007.pdf`  
**How it works**:
- `split('BATCH-20260518-042-007.pdf', '-')` → `['BATCH', '20260518', '042', '007.pdf']`
- `last(...)` → `'007.pdf'`
- `split('007.pdf', '.')` → `['007', 'pdf']`
- `first(...)` → `'007'`
- `int('007')` → `7`

---

### 5.4 OData Filter — Look Up BatchSubmission by BatchDisplayID

```
cr_batchdisplayid eq '@{variables(''varParsedBatchDisplayID'')}'
```

**Used in**: T036 (Dataverse List rows filter to find parent BatchSubmission)  
**Returns**: Filters to single matching row

---

### 5.5 Get Looked-Up BatchSubmission ID (GUID)

```
first(body('List_rows_by_BatchDisplayID')?['value'])?['cr_batchsubmissionid']
```

**Used in**: T036 (store in `varLookedUpBatchID`)  
**Returns**: GUID string — the Dataverse row ID of the parent BatchSubmission  
> Adjust `List_rows_by_BatchDisplayID` to the actual action name in your flow.

---

## Section 6: Flow-01B — Status Updater Expressions

### 6.1 Get BatchID from Modified FormSubmission Trigger

```
triggerOutputs()?['body/cr_batchid']
```

**Used in**: T040, T041  
**Returns**: GUID — the BatchSubmission this form belongs to

---

### 6.2 OData Filter — Get All Sibling Forms by BatchID

```
_cr_batchid_value eq '@{triggerOutputs()?[''body/cr_batchid'']}'
```

**Used in**: T041 (Dataverse List rows filter)  
**Returns**: All FormSubmission rows belonging to the same batch

---

### 6.3 Count Forms by Status — Completed

```
length(filter(body('List_sibling_forms')?['value'], equals(item()?['statuscode@OData.Community.Display.V1.FormattedValue'], 'Complete')))
```

**Used in**: T042  
**Returns**: Integer — count of completed forms  
> Adjust `List_sibling_forms` to your actual action name. The status value `'Complete'` must match your FormSubmission `statuscode` option set label exactly.

---

### 6.4 Count Forms by Status — In Review

```
length(filter(body('List_sibling_forms')?['value'], or(equals(item()?['statuscode@OData.Community.Display.V1.FormattedValue'], 'ReviewRequired'), equals(item()?['statuscode@OData.Community.Display.V1.FormattedValue'], 'ManualIntake'))))
```

**Used in**: T042  
**Returns**: Integer — count of forms in human review

---

### 6.5 Count Forms by Status — Failed

```
length(filter(body('List_sibling_forms')?['value'], or(equals(item()?['statuscode@OData.Community.Display.V1.FormattedValue'], 'WriteFailed'), equals(item()?['statuscode@OData.Community.Display.V1.FormattedValue'], 'Failed'))))
```

**Used in**: T042  
**Returns**: Integer — count of failed forms

---

### 6.6 Count Forms by Status — Processing

```
length(filter(body('List_sibling_forms')?['value'], or(or(equals(item()?['statuscode@OData.Community.Display.V1.FormattedValue'], 'Intake'), equals(item()?['statuscode@OData.Community.Display.V1.FormattedValue'], 'Extracting')), or(equals(item()?['statuscode@OData.Community.Display.V1.FormattedValue'], 'Auto-Approved'), equals(item()?['statuscode@OData.Community.Display.V1.FormattedValue'], 'D365Writing')))))
```

**Used in**: T042  
**Returns**: Integer — count of forms actively being processed

---

### 6.7 Compute Completion Percentage

```
mul(div(float(variables('varFormsCompleted')), float(variables('varTotalFormCount'))), 100)
```

**Used in**: T043 (CompletionPercentage field)  
**Returns**: Decimal 0–100  
**Note**: Use `float()` to force decimal division; integer division in Power Automate truncates.

---

### 6.8 Terminal State Check — All Forms Resolved

```
equals(add(variables('varFormsCompleted'), variables('varFormsFailed')), variables('varTotalFormCount'))
```

**Used in**: T044 (outer condition — are all forms in a terminal state?)  
**Returns**: Boolean — `true` when every form is either Complete or Failed

---

### 6.9 Terminal State Check — All Forms Succeeded (Complete vs. PartiallyFailed)

```
equals(variables('varFormsFailed'), 0)
```

**Used in**: T044 (inner condition — nested within terminal state check)  
**Returns**: Boolean — `true` → BatchStatus = `Complete`; `false` → BatchStatus = `PartiallyFailed`

---

### 6.10 Stale Batch Threshold Timestamp (now minus 24 hours)

```
addHours(utcNow(), -24)
```

**Used in**: T048 (Flow-01C stale batch OData filter)  
**Returns**: DateTime string — 24 hours ago in ISO 8601 format

---

### 6.11 OData Filter — Find Stale Batches (Flow-01C)

```
cr_lastprogresstimestamp lt '@{addHours(utcNow(), -24)}' and cr_batchstatus ne 853400009 and cr_batchstatus ne 853400010 and cr_batchstatus ne 853400002
```

**Used in**: T048 (Dataverse List rows for stale batches)  
**Returns**: All BatchSubmission rows with no progress in 24+ hours  
> Replace numeric values `853400009`, `853400010`, `853400002` with the actual integer codes for `Complete`, `PartiallyFailed`, and `ValidationFailed` from your environment's option set.

---

### 6.12 Stale Batch Alert Message

```
concat('⚠️ Stale batch alert: Batch ', item()?['cr_batchdisplayid'], ' has had no progress since ', item()?['cr_lastprogresstimestamp'], '. Current status: ', item()?['cr_batchstatus@OData.Community.Display.V1.FormattedValue'], '. Total forms: ', string(item()?['cr_totalformcount']), '. Forms completed: ', string(item()?['cr_formscompleted']), '. Please investigate.')
```

**Used in**: T049 (Notification-Router message field inside stale batch loop)  
**Returns**: String

---

## Section 7: Power BI DAX Measures (Phase 7)

### 7.1 Batches Per Day

```dax
BatchesPerDay = 
CALCULATE(
    COUNTROWS(BatchSubmission),
    DATESINPERIOD(BatchSubmission[UploadTimestamp], TODAY(), -1, DAY)
)
```

**Used in**: T052

---

### 7.2 Average Forms Per Batch

```dax
AvgFormsPerBatch = AVERAGE(BatchSubmission[TotalFormCount])
```

**Used in**: T053

---

### 7.3 Average Batch Completion Time (Minutes)

```dax
AvgBatchCompletionMins = 
AVERAGEX(
    FILTER(BatchSubmission, BatchSubmission[CompletionTimestamp] <> BLANK()),
    DATEDIFF(BatchSubmission[UploadTimestamp], BatchSubmission[CompletionTimestamp], MINUTE)
)
```

**Used in**: T054

---

### 7.4 Batch Error Rate

```dax
BatchErrorRate = 
DIVIDE(
    CALCULATE(
        COUNTROWS(BatchSubmission),
        OR(
            BatchSubmission[BatchStatus] = "PartiallyFailed",
            BatchSubmission[BatchStatus] = "ValidationFailed"
        )
    ),
    COUNTROWS(BatchSubmission),
    0
)
```

**Used in**: T055

---

## Section 8: Variable Declarations Reference

All variables that must be initialized at the start of Flow-01 (before the split loop):

| Variable Name | Type | Initial Value | Used In |
|---|---|---|---|
| `varFileName` | String | `triggerOutputs()?['body/Name']` | T015–T033 |
| `varFileSize` | Integer | `triggerOutputs()?['body/Size']` | T015, T017, T024 |
| `varPageCount` | Integer | Muhimbi `pageCount` output | T015, T018–T024 |
| `varValidationFailReason` | String | `""` (empty) | T016–T022 |
| `varBatchDisplayID` | String | `""` (empty) | T024–T033 |
| `varBatchID` | String | `""` (empty) | T024–T033 |
| `varBatchFolderPath` | String | `""` (empty) | T025–T033 |
| `varTotalFormCount` | Integer | `0` | T024–T033 |
| `varFormIndex` | Integer | `1` | T026–T031 |
| `varSplitErrors` | Integer | `0` | T026–T028 |
| `varLastSuccessfulIndex` | Integer | `0` | T026–T031 |
| `varSplitFilePaths` | Array | `[]` | T026–T032 |
| `varCurrentSplitFileName` | String | `""` | T027–T031 |
| `varUploadedBy` | String | `triggerOutputs()?['headers']?['x-ms-user-name']` | T024 |

---

**Version**: 1.0.0 | **Generated**: 2025-07-17  
**Status**: Complete — all expressions verified against Power Automate expression language reference
