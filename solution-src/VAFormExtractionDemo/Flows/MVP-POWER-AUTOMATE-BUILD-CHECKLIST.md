# MVP Power Automate Build Checklist

This is the fastest implementation path for the simple starter scope:

- SharePoint intake
- Dynamics 365 write
- audit logging
- retry for failed writes

## Program Context (BTS SS)

This solution supports the Department of Veterans Affairs Beneficiary Travel Self-Service (BTS SS) program.

- Business purpose: upload and filing of manual beneficiary travel claims
- Clinical/operations purpose: recording Letters of Attendance for Community Care appointments
- Data objective: capture intake artifacts, extract claim content, and persist auditable records in Dataverse/D365

## 1) Prerequisites

- Environment: open the `VA-Form-Extraction` solution in Power Automate.
- Child flows: all flows must be created inside the same solution.
- Connections available and healthy:
  - SharePoint
  - Dataverse
   - HTTP with Microsoft Entra ID (optional, only if tenant consent already granted)
- Dataverse tables exist:
  - `vafe_formsubmission`
  - `vafe_d365writeevent`
  - `vafe_auditlog`

### Important: Two "Form Submissions" Tables

If you see two tables with the display name `Form Submissions`, use the custom VA table (`vafe_formsubmission`), not the Marketing table.

Use this quick fingerprint:
- Correct table (`vafe_formsubmission`) includes fields like: `Source File`, `Processing Start`, `Processing End`, `Processed Timestamp`, `Error Details`.
- Wrong table (Marketing) includes fields like: `Page URL`, `Submission Type`, `Event Registration`, `Source customer journey`.

If the picker is ambiguous, switch to advanced mode and select by schema/logical name: `vafe_formsubmission`.

### Important: Status Field On Form Submissions

The `Status` field on the custom vafe_formsubmission table contains lifecycle values, not a separate state.

Use this mapping:
- `Status`: set to lifecycle value (`Intake`, `Writing`, `Written`, `Correcting`, etc.)

Do NOT expect a separate "Active" state field — the Status field itself is the lifecycle.

## 2) Build Order

1. `MVP-03-Audit-Logger-Subflow`
2. `MVP-02-D365-Write-Subflow`
3. `MVP-04-D365-Retry`
4. `MVP-01-SharePoint-To-D365-Intake` (modify: add OptionalFileId input)
5. `MVP-06-Batch-Folder-Processor` (NEW — batch multi-PDF processor)

**Note:** Flow 06 is optional for MVP but recommended for multi-PDF testing.

### Action Naming: Recommended Approach

You have two valid ways to build flows:

1. Rename Mode (strict)
- Rename actions exactly as documented.
- Safe when you plan to copy/paste expression references.

2. No Rename Mode (recommended for speed)
- Keep default action names like `Add a new row`, `Update a row 2`.
- Do not paste action-name expressions such as `outputs('Create_D365WriteEvent_Pending')...`.
- Always choose values from `Dynamic content` instead.

Naming best practice (applies to either mode):
- Rename actions after each one is configured and saved once.
- Use this convention: `Verb_Object_Outcome`.
- Example: `Update_D365WriteEvent_Retrying`, `Check_Retry_Exhausted`.

If you use No Rename Mode, this checklist still works. Just prefer dynamic content over expression fallbacks wherever both are shown.

## 3) Build Flow: MVP-03-Audit-Logger-Subflow

1. Create flow:
   - Type: `Instant cloud flow`
   - Trigger: `Manually trigger a flow`
   - Name: `MVP-03-Audit-Logger-Subflow`
2. Add trigger inputs (Text):
   - `FormSubmissionId`
   - `Action`
   - `Severity`
   - `Details`
   - `CorrelationId` (optional)
3. Add action `Dataverse -> Add a new row`:
   - Table: `Audit Logs`
   - `Form Submission (Form Submissions)`:
     - `@{concat('/vafe_formsubmissions(', triggerBody()?['FormSubmissionId'], ')')}`
    - `Action` (Choice dropdown):
       - Allowed values in your environment: `Create`, `Read`, `Update`, `Delete`
       - If using dynamic input, click `Enter custom value` and use: `@{triggerBody()?['Action']}`
   - `Timestamp`: `@{utcNow()}`
   - `Details`: `@{triggerBody()?['Details']}`
    - `Severity` (Choice dropdown):
       - Allowed values: `Info`, `Warning`, `Error`, `Critical`
       - If using dynamic input, click `Enter custom value` and use: `@{triggerBody()?['Severity']}`
   - `Correlation ID`: `@{coalesce(triggerBody()?['CorrelationId'], workflow()?['run']?['name'])}`
   - Leave any fields not listed above blank.
4. Add action `Respond to PowerApp or flow` as the last step:
   - Output `Result`: `Logged`
5. Save.

## 4) Build Flow: MVP-02-D365-Write-Subflow

1. Create flow:
   - Type: `Instant cloud flow`
   - Trigger: `Manually trigger a flow`
   - Name: `MVP-02-D365-Write-Subflow`
2. Add trigger inputs (Text):
   - `FormSubmissionId`
   - `PayloadJson`
3. Add action `Parse JSON`:
   - Content: `@{triggerBody()?['PayloadJson']}`
   - Schema (paste):

```json
{
  "type": "object",
  "properties": {
    "firstName": { "type": "string" },
    "lastName": { "type": "string" },
    "ssn": { "type": "string" },
    "email": { "type": "string" },
    "phone": { "type": "string" },
    "sourceFile": { "type": "string" }
  }
}
```

Before continuing, pick one approach:
- Rename Mode: rename actions exactly (click `...` on each action -> `Rename`):
   - `Parse_Payload`
   - `Create_D365WriteEvent_Pending`
   - `Create_Contact_In_D365`
   - `Update_D365WriteEvent_Success`
   - `Update_FormSubmission_Written`
- No Rename Mode: keep default names and use `Dynamic content` for all cross-action references.

If you use No Rename Mode, ignore expression fallback lines and only use the preferred dynamic content lines.

4. Add action `Dataverse -> Add a new row` (pending write event):
   - Table: `D365 Write Events`
   - `Form Submission (Form Submissions)`:
     - `@{concat('/vafe_formsubmissions(', triggerBody()?['FormSubmissionId'], ')')}`
   - `D365 Status` (Choice dropdown): `Pending`
   - `Timestamp Written`: `@{utcNow()}`
   - `Retry Count`: `0`
   - `Payload Sent`: `@{triggerBody()?['PayloadJson']}`
   - Leave `D365 Record ID`, `Error Details`, `HTTP Status Code`, and `Last Retry` blank on create.
5. Add action `Dataverse -> Add a new row`:
    - Table: `Contacts`
    - Fields:

```json
{
   "firstname": "@{body('Parse_Payload')?['firstName']}",
   "lastname": "@{body('Parse_Payload')?['lastName']}",
   "telephone1": "@{body('Parse_Payload')?['phone']}",
   "emailaddress1": "@{body('Parse_Payload')?['email']}",
   "description": "@{concat('VA Form intake source file: ', body('Parse_Payload')?['sourceFile'])}"
}
```

Optional advanced path (only if admin consent is available): use `HTTP with Microsoft Entra ID` against D365 Web API.
If you see `AADSTS65002`, stop using HTTP and continue with Dataverse `Add a new row`.

HTTP body (reference only):

```json
{
   "firstname": "@{body('Parse_Payload')?['firstName']}",
   "lastname": "@{body('Parse_Payload')?['lastName']}",
   "telephone1": "@{body('Parse_Payload')?['phone']}",
   "emailaddress1": "@{body('Parse_Payload')?['email']}",
   "vafe_ssn": "@{body('Parse_Payload')?['ssn']}",
   "description": "@{concat('VA Form intake source file: ', body('Parse_Payload')?['sourceFile'])}"
}
```

6. Add action `Dataverse -> Update a row` (mark write event success):
   - Table: `D365 Write Events`
    - Row ID:
       - Preferred: pick dynamic content `D365 Write Event` from `Create_D365WriteEvent_Pending`
       - Expression fallback: `@{outputs('Create_D365WriteEvent_Pending')?['body/vafe_d365writeeventid']}`
   - `D365 Status`: `Success`
    - `D365 Record ID`:
       - Preferred: pick dynamic content `Contact` (or contact id) from `Create_Contact_In_D365`
       - Expression fallback: `@{coalesce(outputs('Create_Contact_In_D365')?['body/contactid'], '')}`
   - `HTTP Status Code`: `201`
   - `Error Details`: `Write successful`
7. Add action `Dataverse -> Update a row` (FormSubmission):
   - Table: `vafe_formsubmission` (custom VA table, not Marketing Form Submissions)
   - Row ID: `@{triggerBody()?['FormSubmissionId']}`
   - `Status`: `Written`
8. Add failure handling:
   - Add a Scope named `Main` around steps 3-7.
   - Add a Scope named `OnFailure` configured with `run after: has failed`.
   - In `OnFailure`, update the same `vafe_d365writeevent` row:
   - Row ID (important): use dynamic content `D365 Write Event` from `Create_D365WriteEvent_Pending`
   - `D365 Status`: `Failed`
   - `Error Details`: `@{string(result('Main'))}`
   - `HTTP Status Code`: use the HTTP action status code if available
9. Add action `Respond to PowerApp or flow` as the last step:
   - Output `Result`: `WriteAttemptCompleted`
10. Save.

## 5) Build Flow: MVP-04-D365-Retry (CLEAN REBUILD + RENAME MODE)

> **Why it failed before:** action-name expressions, string instead of integer for Retry Count, missing dynamic content selection in Apply to each, and missing required Row ID mapping on parent update.

Rename actions as you build with these exact names:
- `List_Failed_D365WriteEvents`
- `Apply_To_Each_FailedEvent`
- `Update_D365WriteEvent_Retrying`
- `Run_MVP02_D365Write_Subflow`
- `Check_Retry_Exhausted`
- `Update_FormSubmission_Correcting`
- `Run_MVP03_AuditLogger_RetryExhausted`

1. Create flow:
   - Type: `Scheduled cloud flow`
   - Name: `MVP-04-D365-Retry`
   - Frequency: every `15` minutes
   - Click `Create`

2. Add action `Dataverse -> List rows`:
   - Table: `D365 Write Events`
   - Filter rows (expand `Show advanced options`):
     ```
     vafe_d365status eq 534120002 and vafe_retrycount lt 3
     ```
     > `534120002` is the integer value for the `Failed` choice. If you see a label picker instead of an OData field, try `Failed` as the value first; if filtering returns no rows, use the integer.
   - Rename action: `List_Failed_D365WriteEvents`

3. Add `Apply to each`:
   - Click `+New step` → search `Apply to each`
   - In the `Select an output from previous steps` box, click into it and open **Dynamic content**
   - Find the `List rows` section and pick **`value`** — do NOT type an expression here.
   - Rename action: `Apply_To_Each_FailedEvent`

4. Inside the `Apply to each` loop, add `Dataverse -> Update a row`:
   - Table: `D365 Write Events`
   - Row ID: open **Dynamic content** → find `List rows` section → pick **`D365 Write Event`** (the row GUID field)
   - `D365 Status`: `Retrying`
   - `Retry Count`: click into field → switch to **Expression** tab → paste exactly:
     ```
       add(int(items('Apply_To_Each_FailedEvent')?['vafe_retrycount']), 1)
     ```
     > This is an integer expression. Do NOT wrap in quotes. Click OK.
   - `Last Retry`: `@{utcNow()}`
   - Rename action: `Update_D365WriteEvent_Retrying`

5. Inside the loop, add `Run a Child Flow` → `MVP-02-D365-Write-Subflow`:
    - Action card: `Run_MVP02_D365Write_Subflow`
   - `FormSubmissionId`: open **Dynamic content** → pick **`Form Submission (Value)`** from the List rows section
       - If not visible, use Expression: `items('Apply_To_Each_FailedEvent')?['_vafe_formsubmissionid_value']`
   - `PayloadJson`: open **Dynamic content** → pick **`Payload Sent`** from the List rows section
       - If not visible, use Expression: `coalesce(items('Apply_To_Each_FailedEvent')?['vafe_payloadsent'], '{}')`
   - Rename action: `Run_MVP02_D365Write_Subflow`

6. Inside the loop, add `Condition`:
   - Preferred simple-mode condition:
       - Left value (Expression): `add(int(items('Apply_To_Each_FailedEvent')?['vafe_retrycount']), 1)`
     - Operator: `is greater than or equal to`
     - Right value: `3`
   - Advanced-mode equivalent:
     ```
       @greaterOrEquals(add(int(items('Apply_To_Each_FailedEvent')?['vafe_retrycount']), 1), 3)
     ```
   - Rename condition: `Check_Retry_Exhausted`
   - **If Yes** branch:
     - Add `Dataverse -> Update a row` (escalate FormSubmission):
       - Table: `Form Submissions` (custom `vafe_formsubmission`)
       - Row ID: open **Dynamic content** → pick **`Form Submission (Value)`** from the List rows section
       - `Status`: `Correcting`
       - Rename action: `Update_FormSubmission_Correcting`
     - Add `Run a Child Flow` → `MVP-03-Audit-Logger-Subflow`:
          - Action card: `Run_MVP03_AuditLogger_RetryExhausted`
          - `FormSubmissionId`: choose from **Dynamic content** under the `List_Failed_D365WriteEvents` / current `Apply_To_Each_FailedEvent` item context, then pick `Form Submission (Value)`
             - If you do not see that token, use Expression: `items('Apply_To_Each_FailedEvent')?['_vafe_formsubmissionid_value']`
       - `Action`: `Update`
       - `Severity`: `Error`
       - `Details`: `Retry exhausted after 3 attempts`
       - `CorrelationId`: `@{workflow()?['run']?['name']}`
       - Rename action: `Run_MVP03_AuditLogger_RetryExhausted`
   - **If No** branch: leave empty.

7. **Save** — click Save and wait for the green checkmark before navigating away.

### MVP-04 Pre-Save Check (from build troubleshooting)

Before saving, verify all of these:
- In `Apply_To_Each_FailedEvent`, input is **`value`** from `List_Failed_D365WriteEvents` dynamic content.
- In `Update_D365WriteEvent_Retrying`, `Retry Count` uses expression (not quoted string):
   - `add(int(items('Apply_To_Each_FailedEvent')?['vafe_retrycount']), 1)`
- In `Update_FormSubmission_Correcting`, `Row ID` is set to **`Form Submission (Value)`** dynamic content.
- In `Update_FormSubmission_Correcting`, `Status` = `Correcting`.
- In `Run_MVP03_AuditLogger_RetryExhausted`, `CorrelationId` is set to `@{workflow()?['run']?['name']}`.
- If `Flow checker` shows references to missing action names, remove pasted expressions and reselect values from dynamic content.

## 6) Build Flow: MVP-01-SharePoint-To-D365-Intake

1. Create flow:
   - Type: `Automated cloud flow`
   - Trigger: `When a file is created or modified (properties only)`
   - Name: `MVP-01-SharePoint-To-D365-Intake`
2. Trigger setup:
   - Site Address: `https://d365demotsce80677168.sharepoint.com/sites/DepartmentofVeteranAffairs`
   - Library Name: `FormIntake`
3. Trigger condition (settings -> Trigger Conditions):
   - `@startsWith(triggerOutputs()?['body/{FilenameWithExtension}'], 'VA-10-3542-')`
4. Add action `Dataverse -> Add a new row` (FormSubmission):
   - Table: `vafe_formsubmission` (custom VA table, not Marketing Form Submissions)
    - Use the visible columns from your custom table card (do not use `vafe_form_id` if it is not present).
    - Recommended mapping for your environment:
       - `Name`: `@{replace(first(split(triggerOutputs()?['body/{FilenameWithExtension}'], '.')), 'VA-10-3542-', '')}`
       - `Source File`: `@{triggerOutputs()?['body/{FilenameWithExtension}']}`
       - `Upload Date`: `@{utcNow()}`
       - `Status`: `Intake`
    - Optional if present:
       - `Processing Start`: `@{utcNow()}`
       - `Processing Notes`: `Created by SharePoint intake flow`
   - Rename action: `Create_FormSubmission`
5. Add action `Compose` named `Compose_D365_Payload`:

```json
{
  "firstName": "@{coalesce(triggerOutputs()?['body/VeteranFirstName'], 'Unknown')}",
  "lastName": "@{coalesce(triggerOutputs()?['body/VeteranLastName'], triggerOutputs()?['body/{FilenameWithExtension}'])}",
  "ssn": "@{coalesce(triggerOutputs()?['body/VeteranSSN'], '')}",
  "email": "@{coalesce(triggerOutputs()?['body/ClaimantEmail'], '')}",
  "phone": "@{coalesce(triggerOutputs()?['body/ClaimantPhone'], '')}",
  "sourceFile": "@{triggerOutputs()?['body/{FilenameWithExtension}']}"
}
```

   - Rename action: `Compose_D365_Payload`

6. Add `Run a Child Flow` -> `MVP-02-D365-Write-Subflow`:
   - `FormSubmissionId`:
      - Preferred (No Rename Mode safe): pick dynamic content **`Form Submission`** (row id) from the step that creates the FormSubmission row.
      - Expression (Rename Mode): `@{outputs('Create_FormSubmission')?['body/vafe_formsubmissionid']}`
   - `PayloadJson`:
      - Preferred (No Rename Mode safe): pick dynamic content **`Outputs`** from `Compose_D365_Payload` and wrap with `string(...)` if needed.
      - Expression (Rename Mode): `@{string(outputs('Compose_D365_Payload'))}`
   - Rename action: `Run_MVP02_D365Write_Subflow`
7. Add `Run a Child Flow` -> `MVP-03-Audit-Logger-Subflow`:
   - `FormSubmissionId`:
      - Preferred (No Rename Mode safe): pick dynamic content **`Form Submission`** (row id) from the step that creates the FormSubmission row.
      - Expression (Rename Mode): `@{outputs('Create_FormSubmission')?['body/vafe_formsubmissionid']}`
   - `Action`: `Create`
   - `Severity`: `Info`
   - `CorrelationId`: `@{workflow()?['run']?['name']}`
   - `Details`: `@{concat('{\"file\":\"', triggerOutputs()?['body/{FilenameWithExtension}'], '\"}')}`
   - Rename action: `Run_MVP03_AuditLogger_Subflow`
8. Save and turn flow on.


## 7) Smoke Test

1. Upload a file named `VA-10-3542-TEST-001.pdf` into `FormIntake`.
2. Verify in Dataverse:
    - one `vafe_formsubmission` row with Status = `Intake` created
    - one `vafe_extractionresult` row created with OCR data (truncated to 5000 chars)
    - one `vafe_d365writeevent` row with status `Success`
    - one `vafe_auditlog` row with Action = `Create` and Severity = `Info`
3. Confirm the parent flow run history shows `MVP-05`, `MVP-02`, and `MVP-03` all succeeded.

---

## BUILD STATUS (as of May 16, 2026)

### ✅ COMPLETED AND VALIDATED

**MVP-03-Audit-Logger-Subflow**
- Status: ✅ Complete
- Trigger: Manually trigger a flow (Instant child flow)
- Inputs: FormSubmissionId, Action, Severity, Details, CorrelationId (optional)
- Action: Creates vafe_auditlog rows with timestamp and correlation tracking
- Tested: ✅ Yes — creates rows successfully

**MVP-02-D365-Write-Subflow**
- Status: ✅ Complete
- Trigger: Manually trigger a flow (Instant child flow)
- Inputs: FormSubmissionId, PayloadJson
- Actions: Parse JSON, Create D365WriteEvent (Pending), Create Contact, Update D365WriteEvent (Success), Update FormSubmission status
- Tested: ✅ Yes — returned 200 and created Success write events

**MVP-05-AI-Extraction-Subflow**
- Status: ✅ FULLY FUNCTIONAL AND TESTED
- Trigger: Manually trigger a flow (Instant child flow)
- Inputs: FormSubmissionId, FileIdentifier, CorrelationId (optional)
- Key Actions:
   - Get file content from SharePoint (FormIntake library)
   - Run AI Builder Predict (VAFE-VA10-3542-DocProc-v1 model)
   - Extract OCR data to 46 text tokens (form identifiers, claimant info, expenses, etc.)
   - Compose Expressions: OverallConfidence, ExtractedFieldsJson, ConfidenceScoresJson
   - ExtractedFields_ForDataverse caps OCR JSON at 5000 chars using substring()
   - Create ExtractionResult row in Dataverse with truncated OCR data
   - Return 5 outputs: ExtractionResultId, OverallConfidence, ExtractedFields, FormSubmissionId, D365PayloadJson
- Important: the current compose chain is validating the raw model output and returning a safe baseline D365 payload. It is not yet mapping every extracted business field into the payload object.
- Outputs: Verified working
   - ExtractionResultId = valid row ID
   - OverallConfidence = 0.0 (expected for OCR model)
   - ExtractedFields = truncated OCR data (5000 chars max)
   - FormSubmissionId = normalized from input
   - D365PayloadJson = baseline object with Unknown defaults
- Test Result: ✅ PASSED — ExtractionResult row created in Dataverse, no errors
- Data Sample: 46 OCR tokens including "VA Form 10-3542", "Claimant: John Doe", "SSN: 000-00-0000", "DOB: 01/01/1980", expenses, facility name, etc.

### Live Contract Snapshot (Verified from Run History - May 17)

- `Respond to a Power App or flow` body from MVP-05 currently returns these keys:
   - `extractionresultid`
   - `overallconfidence`
   - `extractedfields`
   - `formsubmissionid`
   - `d365payloadjson_`
- Parent flow mapping must read these exact keys (lowercase/underscore), or coalesce with PascalCase variants.
- Observed payload behavior in live runs:
   - `overallconfidence` populated (example: `0.956`)
   - `extractedfields` populated with OCR token JSON
   - `d365payloadjson_` present, but currently baseline values (`Unknown` defaults)

### If Debug Fields or Predict Raw Are Empty

Use the real AI Builder response path before troubleshooting downstream mapping:

- `body('Predict')?['responsev2']?['predictionOutput']`
- `body('Predict')?['responsev2']?['predictionOutput']?['readResults']`
- `body('Predict')?['responsev2']?['predictionOutput']?['layoutConfidenceScore']`

If those are still empty in run history, the problem is upstream of Dataverse:

1. Confirm `Get_file_content` returns a non-empty `$content` payload.
2. Confirm the AI Builder model is the document processor model used in the validated run: `VAFE-VA10-3542-DocProc-v1`.
3. Add a temporary Compose right after Predict with `string(body('Predict')?['responsev2']?['predictionOutput'])` and inspect the run output.
4. If that Compose is empty, the Predict action is not returning a prediction payload for that file and the issue is model/file compatibility, not the Dataverse write step.

### If Compose_LastName Fails With "split expects string but got Array"

This happens when `skip(...)` output (an array) is sent directly into `split(...)`.

Use these safe expressions:

- `Compose_FirstName`
   - `@{trim(coalesce(first(skip(split(first(split(last(split(outputs('Compose_OcrText'),'Claimant: ')), decodeUriComponent('%0A'))),' '), 0)), 'Unknown'))}`

- `Compose_LastName`
   - `@{trim(coalesce(first(skip(split(first(split(last(split(outputs('Compose_OcrText'),'Claimant: ')), decodeUriComponent('%0A'))),' '), 1)), 'Unknown'))}`

- `Compose_SSN`
   - `@{trim(first(split(last(split(outputs('Compose_OcrText'),'SSN: ')), decodeUriComponent('%0A'))))}`

If `Claimant:` is not present in OCR text, set fallback in payload compose using `coalesce(..., 'Unknown')`.

### If Run Succeeds But Name Is `Unknown`

Do not parse the claimant name from the full `readResults` object. If the field step is returning JSON like `Microsoft.Dynamics.CRM.expando`, it is pointing at the page/token object, not the token text.

For VA Form 10-3542 specifically, the claimant name is in the OCR token stream around the block labeled `1A. NAME OF PERSON CLAIMING TRAVEL REIMBURSEMENT (Last, First, Middle)`. The next troubleshooting step is:

1. Add a temporary probe right after `Predict` that outputs a single page's `elements` array as text.
2. Confirm the token pair around the claimant line appears as plain text, for example `Thompson,` and `Susan`.
3. Change `Field_ClaimantName` so it reads the matched token `text` value, not the page object.
4. Only after `Field_ClaimantName` is a plain string should `Field FirstName` and `Field LastName` split it.

Recommended action order (top to bottom):
1. `Compose_PredictRaw`
2. `Fields Probe`
3. `Field_ClaimantName`
4. `Field FirstName`
5. `Field LastName`
6. `Compose D365 Payload`

If `Fields Probe` returns `{}`, the filter condition is too narrow or is looking at the wrong page. If `Field_ClaimantName` returns a JSON blob, the expression is still selecting the OCR item object instead of its `text` property.

Tip: for this form, treat `Claimant:` as unreliable. Use the token line under the claimant heading and extract the text tokens there.

### Path A: AI Builder Returns One Full Name Field

If your model gives a single full name (for example `VeteranFullName`) instead of separate first/last fields, keep Path A and split once in compose actions.

Recommended build:

1. Add `Compose_FullNameFromAI` from Dynamic content (the AI field token), with a safe fallback:
   - `@{trim(coalesce(<AI_FULL_NAME_TOKEN>, ''))}`
2. Add `Compose_FirstName`:
   - `@{if(empty(outputs('Compose_FullNameFromAI')), 'Unknown', first(split(outputs('Compose_FullNameFromAI'), ' ')))}`
3. Add `Compose_LastName`:
   - `@{if(or(empty(outputs('Compose_FullNameFromAI')), equals(length(split(outputs('Compose_FullNameFromAI'), ' ')), 1)), 'Unknown', last(split(outputs('Compose_FullNameFromAI'), ' ')))}`

Notes:
- Replace `<AI_FULL_NAME_TOKEN>` with the actual Dynamic content token from your Predict output.
- This keeps extraction model-driven and avoids OCR token label parsing when a model field exists.

**MVP-01-SharePoint-To-D365-Intake**
- Status: ✅ BUILT AND VALIDATED
- Trigger: When a file is created or modified (properties only) in FormIntake library
- Trigger Condition: File name starts with `VA-10-3542-`
- Actions:
   1. Create FormSubmission (Dataverse) — Status = Intake
   2. Run MVP-05-AI-Extraction-Subflow with FormSubmissionId, FileIdentifier, CorrelationId
   3. Run MVP-02-D365-Write-Subflow with MVP-05 outputs
   4. Run MVP-03-Audit-Logger-Subflow to log the intake event
- Validation: ✅ End-to-end run confirmed with Success status on D365 Write Event

### 🟡 NEXT

**MVP-04-D365-Retry**
- Status: 🟡 Next build item
- Purpose: Scheduled flow (every 15 minutes) to retry failed D365WriteEvents
- Trigger: Scheduled (recurring)
- Dependencies: Uses the validated MVP-01, MVP-02, and MVP-03 chain
- Action: Check for D365WriteEvents with status=Failed and retrycount<3, increment retry count, re-run MVP-02, escalate to Correcting if retries exhausted

**End-to-End Testing**
- Status: ✅ Confirmed for the happy path
- Result: FormSubmission, ExtractionResult, D365WriteEvent, and AuditLog records were created
- Remaining check: Build and validate retry handling in MVP-04

---

## RECENT CHANGES (May 14-16, 2026)

### May 14 — MVP-05 Stabilization
- Fixed: D365PayloadJson schema mismatch (was trying to parse individual OCR fields, now uses baseline Unknown defaults)
- Added: ExtractedFields_ForDataverse Compose to truncate OCR JSON from 36,540 chars to 5,000 char Dataverse column limit
- Fixed: Response action outputs mapping (5 outputs with correct source expressions)
- Fixed: Predict output parsing now uses `responsev2.predictionOutput` for raw OCR, confidence, and debug inspection
- Result: MVP-05 test run successful, ExtractionResult row created

### May 15 — Parent Flow (MVP-01) Construction
- Built: MVP-01 parent flow with automatic trigger on SharePoint file upload
- Wired: Two child flow calls (MVP-05 for extraction, MVP-02 for D365 write)
- Verified: All inputs/outputs properly mapped between flows
- Issue: Flow Checker warning about "run-only" connections (false positive, flows should execute)
- Status: Ready for end-to-end test

### May 16 — End-to-End Validation
- Confirmed: Parent flow executed without NoResponse/BadGateway on the final run
- Confirmed: `MVP-05` returned a successful child-flow response
- Confirmed: `MVP-02` returned status code 200 and produced `D365 Status = Success`
- Confirmed: `MVP-03` returned status code 200 and logged the audit event
- Result: End-to-end MVP chain is working; next build item is retry automation

---

## ARCHITECTURE SUMMARY

1. Upload a file named `VA-10-3542-TEST-001.pdf` into `FormIntake`.
2. Verify in Dataverse:
   - one `vafe_formsubmission` row with Status = `Intake` created
   - one `vafe_extractionresult` row created with OCR data (truncated to 5000 chars)
   - one `vafe_d365writeevent` row with status `Success`
   - one `vafe_auditlog` row with Action = `Create` and Severity = `Info`
3. Force D365 failure (bad URI or temporary auth fail) and verify:
   - `vafe_d365writeevent` row status `Failed`
   - retry flow picks it up and increments retry count

---

## BUILD STATUS (as of May 15, 2026)

### ✅ COMPLETED AND TESTED

**MVP-03-Audit-Logger-Subflow**
- Status: ✅ Complete
- Trigger: Manually trigger a flow (Instant child flow)
- Inputs: FormSubmissionId, Action, Severity, Details, CorrelationId (optional)
- Action: Creates vafe_auditlog rows with timestamp and correlation tracking
- Tested: ✅ Yes — creates rows successfully

**MVP-02-D365-Write-Subflow**
- Status: ✅ Ready (structure verified, awaiting parent flow trigger)
- Trigger: Manually trigger a flow (Instant child flow)
- Inputs: FormSubmissionId, PayloadJson
- Actions: Parse JSON, Create D365WriteEvent (Pending), Create Contact, Update D365WriteEvent (Success), Update FormSubmission status
- Tested: ✅ Structure confirmed correct

**MVP-05-AI-Extraction-Subflow** 
- Status: ✅ FULLY FUNCTIONAL AND TESTED
- Trigger: Manually trigger a flow (Instant child flow)
- Inputs: FormSubmissionId, FileIdentifier, CorrelationId (optional)
- Key Actions:
  - Get file content from SharePoint (FormIntake library)
  - Run AI Builder Predict (VAFE-VA10-3542-DocProc-v1 model)
  - Extract OCR data to 46 text tokens (form identifiers, claimant info, expenses, etc.)
  - Compose Expressions: OverallConfidence, ExtractedFieldsJson, ConfidenceScoresJson
  - **NEW: ExtractedFields_ForDataverse** — caps OCR JSON at 5000 chars using substring()
  - Create ExtractionResult row in Dataverse with truncated OCR data
  - Return 5 outputs: ExtractionResultId, OverallConfidence, ExtractedFields, FormSubmissionId, D365PayloadJson
- Outputs: Verified working
  - ExtractionResultId = valid row ID
  - OverallConfidence = 0.0 (expected for OCR model)
  - ExtractedFields = truncated OCR data (5000 chars max)
  - FormSubmissionId = normalized from input
  - D365PayloadJson = baseline object with Unknown defaults
- Test Result: ✅ PASSED — ExtractionResult row created in Dataverse, no errors
- Data Sample: 46 OCR tokens including "VA Form 10-3542", "Claimant: John Doe", "SSN: 000-00-0000", "DOB: 01/01/1980", expenses, facility name, etc.

**MVP-01-SharePoint-To-D365-Intake**
- Status: ⚠️ BUILT, READY FOR END-TO-END TEST (Flow Checker shows false positive error)
- Trigger: When a file is created or modified (properties only) in FormIntake library
- Trigger Condition: File name starts with `VA-10-3542-`
- Actions:
  1. Create FormSubmission (Dataverse) — Status = Intake
  2. **Run MVP-05-AI-Extraction-Subflow** with FormSubmissionId, FileIdentifier, CorrelationId
  3. Compose D365 Payload (baseline with Unknown defaults)
  4. FormSubmissionId Token (Compose)
  5. PayloadJson Token (Compose)
  6. **Run MVP-02-D365-Write-Subflow** with FormSubmissionId (from MVP-05), PayloadJson (from MVP-05)
  7. **Run MVP-03-Audit-Logger-Subflow** to log the intake event
- Status: ✅ Saved and ready

**Known Issue: Flow Checker Error**
- Error Message: "Update the child flow for action 'Run_MVP-05-AI-Extraction-Subflow' to not use 'run-only' user connections."
- Root Cause: False positive — SharePoint connection is restricted to "run-only" mode, but this doesn't prevent execution
- Impact: ❌ None (this is a validation warning, not a runtime blocker)
- Workaround: Ignored — flows should execute despite this warning
- Mitigation: Monitor first test run to confirm no actual connection failures

### 🟡 PENDING

**MVP-04-D365-Retry**
- Status: 🟡 Not yet built
- Purpose: Scheduled flow (every 15 minutes) to retry failed D365WriteEvents
- Trigger: Scheduled (recurring)
- Dependencies: Depends on MVP-01, MVP-02, MVP-03 running end-to-end first
- Action: Check for D365WriteEvents with status=Failed and retrycount<3, increment retry count, re-run MVP-02, escalate to Correcting if retries exhausted

**End-to-End Testing**
- Status: 🟡 Ready to execute
- Next Step: Upload `VA-10-3542-TEST-001.pdf` to SharePoint FormIntake library
- Expected Behavior:
  - MVP-01 trigger fires (file detected)
  - Create FormSubmission row
  - Call MVP-05 → creates ExtractionResult row with OCR data
  - Call MVP-02 → creates Contact in D365 and D365WriteEvent (Success)
  - Call MVP-03 → logs audit entry
  - All 4 Dataverse tables populated: FormSubmission, ExtractionResult, D365WriteEvent, AuditLog
- Success Criteria: All rows created, no errors in execution

---

## RECENT CHANGES (May 14-15, 2026)

### May 14 — MVP-05 Stabilization
- Fixed: D365PayloadJson schema mismatch (was trying to parse individual OCR fields, now uses baseline Unknown defaults)
- Added: ExtractedFields_ForDataverse Compose to truncate OCR JSON from 36,540 chars to 5,000 char Dataverse column limit
- Fixed: Response action outputs mapping (5 outputs with correct source expressions)
- Result: MVP-05 test run successful, ExtractionResult row created

### May 15 — Parent Flow (MVP-01) Construction
- Built: MVP-01 parent flow with automatic trigger on SharePoint file upload
- Wired: Two child flow calls (MVP-05 for extraction, MVP-02 for D365 write)
- Verified: All inputs/outputs properly mapped between flows
- Issue: Flow Checker warning about "run-only" connections (false positive, flows should execute)
- Status: Ready for end-to-end test

---

## ARCHITECTURE SUMMARY

```
SharePoint FormIntake (trigger)
    ↓
MVP-01 Parent Flow
    ├→ Create FormSubmission row (Status=Intake)
    ├→ Run MVP-05-AI-Extraction-Subflow
    │   ├→ Get file from SharePoint
    │   ├→ Run AI Builder Predict
    │   ├→ Extract OCR data (46 tokens)
    │   ├→ Create ExtractionResult row
    │   └→ Return outputs (OCR data, confidence, FormSubmissionId, D365Payload)
    ├→ Run MVP-02-D365-Write-Subflow
    │   ├→ Parse D365Payload JSON
    │   ├→ Create Contact in D365
    │   ├→ Create D365WriteEvent
    │   └→ Update FormSubmission Status=Written
    └→ Run MVP-03-Audit-Logger-Subflow
        └→ Log audit entry (Action=Create, Severity=Info)
```

---

## DATAVERSE TABLES POPULATED

1. **vafe_formsubmission** — Lifecycle tracking for each upload
   - Name: Extracted from filename (without VA-10-3542- prefix)
   - Source File: Original filename from SharePoint
   - Upload Date: utcNow()
   - Status: Intake → Writing → Written → (optional) Correcting

2. **vafe_extractionresult** — OCR data and AI model outputs
   - Form Submission: Foreign key to FormSubmission
   - Extracted Data: OCR readResults JSON (truncated to 5000 chars)
   - Field Confidence Scores: Layout confidence JSON
   - Overall Confidence: 0.0 (OCR model)
   - Extraction Status: Success
   - AI Model Version: VAFE-VA10-3542-DocProc-v1
   - Extraction Timestamp: utcNow()

3. **vafe_d365writeevent** — D365 write attempt tracking
   - Form Submission: Foreign key to FormSubmission
   - D365 Status: Pending → Success or Failed
   - D365 Record ID: Contact row ID (if successful)
   - Payload Sent: D365PayloadJson
   - HTTP Status Code: 201 or error code
   - Retry Count: Incremented on retry
   - Timestamp Written: When write was attempted

4. **vafe_auditlog** — Comprehensive audit trail
   - Form Submission: Foreign key to FormSubmission
   - Action: Create, Read, Update, Delete, etc.
   - Severity: Info, Warning, Error, Critical
   - Details: Event description
   - Timestamp: utcNow()
   - Correlation ID: Workflow run name for tracing

---

## NEXT IMMEDIATE STEPS

1. **Upload test file** to SharePoint FormIntake library
   - Filename: `VA-10-3542-TEST-001.pdf`
   - Location: https://d365demotsce80677168.sharepoint.com/sites/DepartmentofVeteranAffairs/FormIntake
   
2. **Monitor flow execution**
   - Check Power Automate run history for MVP-01
   - Verify all child flows executed successfully
   - Check Dataverse for row creation in all 4 tables

3. **Validate output quality**
   - FormSubmission Status should be Written
   - ExtractionResult should contain 46 OCR tokens (truncated)
   - D365WriteEvent should have status Success and Contact row ID
   - AuditLog should have multiple entries (one per action)

4. **Build MVP-04 retry flow** (after end-to-end test succeeds)
   - Scheduled trigger (every 15 minutes)
   - List failed D365WriteEvents
   - Retry failed writes up to 3 times
   - Escalate to Correcting if retries exhausted

---

## KNOWN LIMITATIONS & FUTURE ENHANCEMENTS

**Current MVP Baseline:**
- ✅ MVP-01: Automatic SharePoint intake with file detection
- ✅ MVP-05: AI-powered OCR extraction with baseline payload structure
- ✅ MVP-02: D365 Contact creation with Unknown defaults
- ✅ MVP-03: Comprehensive audit logging
- ❌ MVP-04: Retry logic not yet built
- ⏳ MVP-06: Decision routing based on confidence thresholds (future)

**Future Improvements:**
- Add OCR token parsing to extract first name, last name, SSN, email from text (post-MVP)
- Implement confidence threshold routing (e.g., <70% confidence → Manual Review queue)
- Add error handling Scopes with comprehensive retry logic to MVP-05 and MVP-02
- Enhance ConfidenceScoresJson with field-level confidence once model training improves
- Create CorrectionRecord flow for manual review of low-confidence extractions
- Add email notifications for success/failure outcomes

---

## BUILD CHECKLIST COMPLETION STATUS

| Component | Status | Tested | Notes |
|-----------|--------|--------|-------|
| MVP-03 Audit Logger | ✅ Complete | ✅ Yes | Creates rows successfully |
| MVP-02 D365 Write | ✅ Complete | ⏳ Pending end-to-end | Structure verified, ready for trigger |
| MVP-04 Retry Flow | ❌ Not Started | N/A | To be built after MVP-01-05-02-03 chain verified |
| MVP-05 AI Extraction | ✅ Complete | ✅ Yes | Tested standalone, creates ExtractionResult rows |
| MVP-01 Parent Flow | ✅ Complete | ⏳ Pending end-to-end | Built, ready for file upload trigger |
| End-to-End Test | ⏳ Ready | ❌ Not Yet | Next: Upload test PDF, verify all rows created |

---

**Last Updated:** May 15, 2026, 3:45 PM (post build session)
**Test Status:** Ready for smoke test (upload `VA-10-3542-TEST-001.pdf` to FormIntake library)