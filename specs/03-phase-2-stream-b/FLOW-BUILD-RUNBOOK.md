# VA Form Extraction — Power Automate Flow Build Runbook

**Prepared by**: John Shelby, Power Automate Flow Orchestration Lead  
**Date**: April 26, 2026  
**Phase**: 2 → 3 (Phase Gate APPROVED by Tommy Shelby)  
**Estimated Build Time**: 2–3 days for a human operator  

---

## PRE-FLIGHT CHECKLIST

Before building any flows, confirm ALL of the following:

- [ ] Power Platform environment open: **"Département of Veteran Affairs - OTH" (GCC)**
- [ ] Solution **VA-Form-Extraction** is open and ready (all new flows must be created inside this solution)
- [ ] All 5 Dataverse tables provisioned by **Polly Gray** — required before any Dataverse CRUD steps can be configured:
  - `vafe_FormSubmission`
  - `vafe_ExtractionResult`
  - `vafe_CorrectionRecord`
  - `vafe_AuditLog`
  - `vafe_D365WriteEvent`
- [ ] AI Builder model **`VAForm10-3542-Extractor`** published and available (from **Michael Gray**)
- [ ] All 6 connections created (see Step 1 below)

> ⚠️ **DO NOT begin flow configuration until all pre-flight items are checked.** Incomplete prerequisites will cause broken references that are painful to fix after the fact.

---

## STEP 1: CREATE CONNECTIONS

**Navigation**: Power Automate → Connections (left sidebar) → + New connection

Create each connection below in order. Name them exactly as shown — these names are referenced throughout this runbook.

| # | Connector | Connection Name | Auth Type | Notes |
|---|-----------|-----------------|-----------|-------|
| 1 | SharePoint | `VA-SharePoint-FormIntake` | OAuth — your M365 account | Must have read access to the FormIntake library |
| 2 | Microsoft Dataverse | `VA-Dataverse-Prod` | OAuth — service account | Use the GCC service account, not personal credentials |
| 3 | AI Builder | `VA-AIBuilder` | OAuth — your M365 account | Must have AI Builder maker role |
| 4 | HTTP with Azure AD | `VA-D365-HTTP` | OAuth → D365 endpoint | Base URL: `https://[org].crm.dynamics.com` |
| 5 | Microsoft Teams | `VA-Teams-Notifications` | OAuth — your M365 account | Must be a member of all 4 notification channels |
| 6 | HTTP | `VA-HTTP-Generic` | No auth | Used for webhook POSTs |

**Verify**: After creating all 6 connections, confirm each shows a green checkmark (Connected) before proceeding.

---

## TEAMS NOTIFICATION CHANNELS: WEBHOOK SETUP

Before building flows, set up incoming webhooks for all 4 notification channels. This must be done by a Teams channel owner.

**For each channel below, follow these steps:**
1. Open the channel in Microsoft Teams
2. Click **...** (More options) → **Connectors** → **Incoming Webhook** → **Configure**
3. Name the webhook (e.g., `VA Flow Alerts`) and click **Create**
4. Copy the webhook URL
5. Store the URL in **Azure Key Vault** as a secret using the name in the table below

| Channel | Purpose | Trigger Event | Key Vault Secret Name |
|---------|---------|---------------|----------------------|
| `#va-form-extraction-reviews` | Manual review requests | Low-confidence forms | `teams-webhook-reviews` |
| `#va-form-extraction-alerts` | Error notifications | AI timeout, flow failures | `teams-webhook-alerts` |
| `#va-form-extraction-admin` | Escalations | D365 max retries reached | `teams-webhook-admin` |
| `#va-form-extraction-success` | Success confirmations (optional) | Form written to D365 | `teams-webhook-success` |

**In flows**: Reference webhook URLs via **Azure Key Vault → Get secret** action. Never hardcode webhook URLs in flow expressions.

---

## FLOW BUILD ORDER

Build flows in this sequence. Subflows must exist before the main flow can call them.

```
1. VA-Audit-Logger          (utility — used by all other flows)
2. VA-D365-Write-Subflow    (called by main flow and correction queue)
3. VA-Manual-Correction-Queue (called by main flow on low confidence)
4. VA-D365-Retry-Logic      (scheduled — independent)
5. VA-Form-Intake-Pipeline  (main flow — calls all of the above)
```

---

## FLOW 1: VA-Audit-Logger (Utility Subflow)

Build this first. Every other flow depends on it.

**Navigation**: VA-Form-Extraction solution → **+ New** → **Instant cloud flow** (manually triggered)  
**Name**: `VA-Audit-Logger`  
**Trigger**: Power Apps or flow

### Input Parameters
Click **+ Add an input** for each:

| Parameter Name | Type |
|----------------|------|
| `FormSubmissionID` | Text |
| `Action` | Text |
| `Details` | Text |
| `Severity` | Text |

### Actions

**Action 1 — Add a new row (Dataverse)**
- Connection: `VA-Dataverse-Prod`
- Table name: `AuditLog` (`vafe_AuditLog`)
- Set fields:
  - **Form Submission (Lookup)**: `triggerBody()?['text']` → `FormSubmissionID` parameter
  - **Action**: `triggerBody()?['text_1']` → `Action` parameter  
    *(Use dynamic content picker to select the Action input)*
  - **Timestamp**: `utcNow()`
  - **Details**: `triggerBody()?['text_2']` → `Details` parameter
  - **Severity**: `triggerBody()?['text_3']` → `Severity` parameter

**Save and test**: Run manually with sample values. Verify a row appears in the AuditLog table in Dataverse before proceeding.

---

## FLOW 2: VA-D365-Write-Subflow

**Navigation**: VA-Form-Extraction solution → **+ New** → **Instant cloud flow** (manually triggered)  
**Name**: `VA-D365-Write-Subflow`  
**Trigger**: Power Apps or flow

### Input Parameter
Click **+ Add an input**:
- `FormSubmissionID` (Text)

### STEP 1 — Get ExtractionResult for this FormSubmission

**Action**: List rows (Dataverse)
- Connection: `VA-Dataverse-Prod`
- Table name: `ExtractionResult` (`vafe_ExtractionResult`)
- Filter rows: `vafe_FormSubmissionId eq '@{triggerBody()?['text']}'`
  - *(Type this expression manually in the Filter rows field)*
- Top count: `1`

### STEP 2 — Parse Extracted JSON Data

**Action**: Parse JSON
- Content: `first(outputs('List_rows')?['body/value'])?['vafe_ExtractedData']`
- Schema: Click **Generate from sample** and paste this sample JSON:
```json
{
  "veteranFirstName": "John",
  "veteranLastName": "Doe",
  "veteranSSN": "123-45-6789",
  "veteranDOB": "1950-01-15",
  "claimantPhone": "555-867-5309",
  "claimantEmail": "claimant@example.com",
  "burialExpenses": "2500.00",
  "transportationExpenses": "450.00",
  "claimantRelationship": "Spouse"
}
```

### STEP 3 — Search D365 for Existing Account

**Action**: HTTP (using `VA-D365-HTTP` connection)
- Method: **GET**
- URI: `https://[org].crm.dynamics.com/api/data/v9.2/contacts?$filter=vafe_ssn eq '@{body('Parse_JSON')?['veteranSSN']}'&$select=contactid,fullname`
  - Replace `[org]` with your actual D365 org name
- Headers:
  - `OData-MaxVersion`: `4.0`
  - `OData-Version`: `4.0`
  - `Accept`: `application/json`
  - `Content-Type`: `application/json`
- Authentication: Use `VA-D365-HTTP` connection (OAuth is handled automatically)

### STEP 4 — Branch: Create or Update D365 Account

**Action**: Condition
- Left value: `length(body('HTTP')?['value'])`
- Operator: `is greater than`
- Right value: `0`

**TRUE branch — Update existing account (HTTP PATCH)**:

Add **HTTP** action:
- Method: **PATCH**
- URI: `concat('https://[org].crm.dynamics.com/api/data/v9.2/contacts(', body('HTTP')?['value'][0]?['contactid'], ')')`
- Headers: *(same as Step 3)*
- Body:
```json
{
  "firstname": "@{body('Parse_JSON')?['veteranFirstName']}",
  "lastname": "@{body('Parse_JSON')?['veteranLastName']}",
  "telephone1": "@{body('Parse_JSON')?['claimantPhone']}",
  "emailaddress1": "@{body('Parse_JSON')?['claimantEmail']}",
  "description": "VA Form 10-3542 — Burial Benefit Claim — Updated @{utcNow()}"
}
```

**FALSE branch — Create new account (HTTP POST)**:

Add **HTTP** action:
- Method: **POST**
- URI: `https://[org].crm.dynamics.com/api/data/v9.2/contacts`
- Headers: *(same as Step 3)*
- Body:
```json
{
  "firstname": "@{body('Parse_JSON')?['veteranFirstName']}",
  "lastname": "@{body('Parse_JSON')?['veteranLastName']}",
  "telephone1": "@{body('Parse_JSON')?['claimantPhone']}",
  "emailaddress1": "@{body('Parse_JSON')?['claimantEmail']}",
  "description": "VA Form 10-3542 — Burial Benefit Claim",
  "vafe_ssn": "@{body('Parse_JSON')?['veteranSSN']}",
  "birthdate": "@{body('Parse_JSON')?['veteranDOB']}"
}
```

### STEP 5 — Create D365WriteEvent Record (Dataverse)

After the condition (runs on both paths):

**Action**: Add a new row (Dataverse)
- Table: `D365WriteEvent` (`vafe_D365WriteEvent`)
- Fields:
  - **Form Submission (Lookup)**: `triggerBody()?['text']` (FormSubmissionID input)
  - **D365 Status**: `Success`
    - *(Use condition output to set this — see note below)*
  - **D365 Record ID**: 
    - If updated: `body('HTTP')?['value'][0]?['contactid']`  
    - If created: parse from response header `OData-EntityId`
  - **Timestamp Written**: `utcNow()`
  - **Payload Sent**: `substring(string(body('Parse_JSON')), 0, min(5000, length(string(body('Parse_JSON')))))`
  - **HTTP Status Code**: `outputs('HTTP')?['statusCode']`

> 📝 **Note on D365 Status**: Place this "Add a new row" inside a condition that checks `outputs('HTTP')?['statusCode']`. If 200 or 204 → Status = `Success` (value: 534,120,001). If other → Status = `Failed` (value: 534,120,002) and set `vafe_RetryCount` = 0 for pickup by the retry flow.

### STEP 6 — Update FormSubmission Status → Written

**Action**: Update a row (Dataverse)
- Table: `FormSubmission` (`vafe_FormSubmission`)
- Row ID: `triggerBody()?['text']` (FormSubmissionID input)
- Status: `Written` (value: 534,120,005)

### STEP 7 — Log D365WriteSuccess to AuditLog

**Action**: Run a child flow → `VA-Audit-Logger`
- FormSubmissionID: `triggerBody()?['text']`
- Action: `D365WriteSuccess`
- Details: `concat('D365 record written. Status: ', outputs('HTTP')?['statusCode'])`
- Severity: `Info`

### STEP 8 — Send Teams Success Notification (Optional)

**Action**: Get secret (Azure Key Vault)
- Secret name: `teams-webhook-success`

**Action**: HTTP
- Method: POST
- URI: `body('Get_secret')?['value']`
- Body:
```json
{
  "@type": "MessageCard",
  "@context": "http://schema.org/extensions",
  "summary": "D365 Write Success",
  "themeColor": "00AA00",
  "title": "✅ Form Written to D365",
  "text": "Form **@{triggerBody()?['text']}** successfully written to Dynamics 365."
}
```

**Save the flow** before continuing.

---

## FLOW 3: VA-Manual-Correction-Queue

**Navigation**: VA-Form-Extraction solution → **+ New** → **Automated cloud flow**  
**Name**: `VA-Manual-Correction-Queue`  
**Trigger**: Microsoft Dataverse — **When a row is added** → Table: `CorrectionRecord` (`vafe_CorrectionRecord`)

### STEP 1 — Get Parent FormSubmission Details

**Action**: Get a row by ID (Dataverse)
- Table: `FormSubmission` (`vafe_FormSubmission`)
- Row ID: `triggerOutputs()?['body/vafe_FormSubmissionId']`

### STEP 2 — Get Teams Webhook URL from Key Vault

**Action**: Get secret (Azure Key Vault)
- Secret name: `teams-webhook-reviews`

### STEP 3 — Post Teams Adaptive Card to #va-form-extraction-reviews

**Action**: HTTP
- Method: POST
- URI: `body('Get_secret')?['value']`
- Body:
```json
{
  "@type": "MessageCard",
  "@context": "http://schema.org/extensions",
  "summary": "Form Requires Review",
  "themeColor": "FF8C00",
  "title": "🔍 Form Requires Manual Review",
  "sections": [
    {
      "facts": [
        { "name": "Form ID", "value": "@{triggerOutputs()?['body/vafe_FormSubmissionId']}" },
        { "name": "Field", "value": "@{triggerOutputs()?['body/vafe_FieldName']}" },
        { "name": "AI Extracted Value", "value": "@{triggerOutputs()?['body/vafe_OriginalValue']}" },
        { "name": "Confidence Score", "value": "@{triggerOutputs()?['body/vafe_FieldConfidence']}" },
        { "name": "SLA", "value": "30 minutes" }
      ]
    }
  ],
  "potentialAction": [
    {
      "@type": "OpenUri",
      "name": "Open Correction Form",
      "targets": [
        { "os": "default", "uri": "https://make.powerapps.com/[your-correction-app-url]" }
      ]
    }
  ]
}
```
> 📝 Replace the Power Apps correction URL with the actual URL once Lizzie Stark's UI is built.

### STEP 4 — Post Approval Request (Teams — Post an Adaptive Card and wait for a response)

**Action**: Post an adaptive card and wait for a response (Teams)
- Post in: Channel
- Team: VA Form Extraction
- Channel: va-form-extraction-reviews
- Message: *(Adaptive card with Approve/Skip buttons)*
- Timeout: `PT30M` (30 minutes)
- Update message: `Review completed by @{body('Post_an_Adaptive_Card_and_wait_for_a_response')?['responder/displayName']}`

Adaptive card body for the wait action:
```json
{
  "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
  "type": "AdaptiveCard",
  "version": "1.4",
  "body": [
    {
      "type": "TextBlock",
      "text": "Correction Required",
      "weight": "Bolder",
      "size": "Medium"
    },
    {
      "type": "FactSet",
      "facts": [
        { "title": "Field", "value": "@{triggerOutputs()?['body/vafe_FieldName']}" },
        { "title": "AI Value", "value": "@{triggerOutputs()?['body/vafe_OriginalValue']}" }
      ]
    },
    {
      "type": "Input.Text",
      "id": "correctedValue",
      "placeholder": "Enter corrected value",
      "label": "Corrected Value"
    }
  ],
  "actions": [
    { "type": "Action.Submit", "title": "Submit Correction", "data": { "action": "approve" } },
    { "type": "Action.Submit", "title": "Skip / Escalate", "data": { "action": "skip" } }
  ]
}
```

### STEP 5 — Process Corrector Response

**Action**: Condition
- Left value: `body('Post_an_Adaptive_Card_and_wait_for_a_response')?['data/action']`
- Operator: `is equal to`
- Right value: `approve`

**TRUE branch (correction submitted)**:

**Action**: Update a row (Dataverse)
- Table: `CorrectionRecord` (`vafe_CorrectionRecord`)
- Row ID: `triggerOutputs()?['body/vafe_CorrectionRecordId']`
- Fields:
  - **Corrected Value**: `body('Post_an_Adaptive_Card_and_wait_for_a_response')?['data/correctedValue']`
  - **Reviewed By**: `body('Post_an_Adaptive_Card_and_wait_for_a_response')?['responder/displayName']`
  - **Correction Date**: `utcNow()`
  - **Status**: `Corrected` (value: 534,120,001)

**Action**: Run a child flow → `VA-D365-Write-Subflow`
- FormSubmissionID: `triggerOutputs()?['body/vafe_FormSubmissionId']`

**FALSE branch (skip/escalate)**:

**Action**: Get secret (Azure Key Vault)
- Secret name: `teams-webhook-admin`

**Action**: HTTP POST to admin webhook with escalation message

**Save the flow** before continuing.

---

## FLOW 4: VA-D365-Retry-Logic (Scheduled)

**Navigation**: VA-Form-Extraction solution → **+ New** → **Scheduled cloud flow**  
**Name**: `VA-D365-Retry-Logic`  
**Schedule**: Repeat every **5 minutes**

### STEP 1 — List Pending D365WriteEvents

**Action**: List rows (Dataverse)
- Table: `D365WriteEvent` (`vafe_D365WriteEvent`)
- Filter rows: `vafe_D365Status eq 534120002 and vafe_RetryCount lt 5`
  - *(534120002 = Failed/Pending status)*
- Top count: `10`
- Order by: `createdon asc`

### STEP 2 — Apply to Each (Process Each Pending Event)

**Action**: Apply to each
- Input: `value` from List rows output

Inside the loop:

**Action 2a — Calculate exponential backoff delay**

**Action**: Compose
- Inputs: `mul(pow(2, item()?['vafe_RetryCount']), 100)`
- Name this action: `Calculate_Delay`

**Action 2b — Delay**

**Action**: Delay
- Count: `outputs('Calculate_Delay')`
- Unit: Milliseconds

> 📝 Power Automate minimum delay is 1 second. If the calculated delay is under 1000 ms, the platform will round up automatically.

**Action 2c — Retry: Call VA-D365-Write-Subflow**

**Action**: Run a child flow → `VA-D365-Write-Subflow`
- FormSubmissionID: `item()?['vafe_FormSubmissionId']`

**Action 2d — Increment Retry Count**

**Action**: Update a row (Dataverse)
- Table: `D365WriteEvent` (`vafe_D365WriteEvent`)
- Row ID: `item()?['vafe_D365WriteEventId']`
- Retry Count: `add(item()?['vafe_RetryCount'], 1)`

**Action 2e — Check if Max Retries Reached**

**Action**: Condition
- Left value: `add(item()?['vafe_RetryCount'], 1)`
- Operator: `is greater than or equal to`
- Right value: `5`

**TRUE (max retries reached)**:

**Action**: Update a row (Dataverse)
- Table: `D365WriteEvent`
- Row ID: `item()?['vafe_D365WriteEventId']`
- D365 Status: `Failed` (permanent — value: 534,120,003)

**Action**: Get secret (Azure Key Vault) — secret: `teams-webhook-admin`

**Action**: HTTP POST to admin webhook:
```json
{
  "@type": "MessageCard",
  "themeColor": "FF0000",
  "title": "🚨 D365 Write Max Retries Reached",
  "text": "Form **@{item()?['vafe_FormSubmissionId']}** has exhausted all 5 retry attempts. Manual intervention required.",
  "sections": [
    {
      "facts": [
        { "name": "D365WriteEvent ID", "value": "@{item()?['vafe_D365WriteEventId']}" },
        { "name": "Retry Count", "value": "5" },
        { "name": "Last Attempt", "value": "@{utcNow()}" }
      ]
    }
  ]
}
```

**Save the flow.** Turn it **ON** after saving — scheduled flows start in the Off state by default.

---

## FLOW 5: VA-Form-Intake-Pipeline (Main Flow)

Build this last. It calls all subflows built above.

**Navigation**: VA-Form-Extraction solution → **+ New** → **Automated cloud flow**  
**Name**: `VA-Form-Intake-Pipeline`  
**Trigger**: SharePoint — **When a file is created or modified (properties only)**
- Site: `https://uspsgcctenant.sharepoint.com/sites/DpartementofVeteranAffairs`
- Library: `FormIntake`
- Folder: `/` *(root)*

### STEP 1 — Initialize Variables

Add **6 "Initialize variable"** actions immediately after the trigger. Each must be a separate action (Power Automate does not support multiple variables in one action).

| Action Name | Variable Name | Type | Initial Value |
|-------------|---------------|------|---------------|
| `Init_FormID` | `var_FormID` | String | *(empty)* |
| `Init_FileContent` | `var_FileContent` | String | *(empty)* |
| `Init_Confidence` | `var_Confidence` | Float | `0` |
| `Init_AIOutput` | `var_AIOutput` | Object | `{}` |
| `Init_D365RecordID` | `var_D365RecordID` | String | *(empty)* |
| `Init_RetryCount` | `var_RetryCount` | Integer | `0` |
| `Init_StepStart` | `var_StepStart` | String | `utcNow()` |

> 📝 `var_StepStart` is used for SLA timing instrumentation (see SLA section below).

### STEP 2 — Validate File Type

**Action**: Condition
- Left value: `or(endsWith(triggerOutputs()?['body/{FilenameWithExtension}'], '.pdf'), endsWith(triggerOutputs()?['body/{FilenameWithExtension}'], '.tiff'), endsWith(triggerOutputs()?['body/{FilenameWithExtension}'], '.png'), endsWith(triggerOutputs()?['body/{FilenameWithExtension}'], '.jpg'), endsWith(triggerOutputs()?['body/{FilenameWithExtension}'], '.jpeg'))`
  - *(Enter this as an expression in the condition field)*
- Operator: `is equal to`
- Right value: `true`

**FALSE branch**:

**Action**: Add a new row (Dataverse) → `AuditLog`
- Action: `ErrorOccurred`
- Details: `concat('Invalid file type: ', triggerOutputs()?['body/{FilenameWithExtension}'])`
- Severity: `Warning`

**Action**: Terminate
- Status: Cancelled
- Code: `InvalidFileType`
- Message: `concat('Unsupported file extension. Only PDF, TIFF, PNG, JPG, JPEG are accepted. File: ', triggerOutputs()?['body/{FilenameWithExtension}'])`

**TRUE branch**: Continue with Step 3.

### STEP 3 — Create FormSubmission Record

**Action**: Add a new row (Dataverse)
- Table: `FormSubmission` (`vafe_FormSubmission`)
- Fields:
  - **Source File**: `triggerOutputs()?['body/{FilenameWithExtension}']`
  - **Source File URL**: `triggerOutputs()?['body/{Link}']`
  - **Status**: `Intake` (value: `534120000`)
  - **Upload Date**: `utcNow()`

**Action**: Set variable
- Name: `var_FormID`
- Value: `outputs('Add_a_new_row')?['body/vafe_FormSubmissionId']`

> 📝 The exact dynamic content name for the row ID depends on the action name you gave the Dataverse add action. Use the dynamic content picker to select the ID output.

### STEP 4 — Log Intake Event

**Action**: Run a child flow → `VA-Audit-Logger`
- FormSubmissionID: `variables('var_FormID')`
- Action: `FormIntake`
- Details: `concat('File received: ', triggerOutputs()?['body/{FilenameWithExtension}'])`
- Severity: `Info`

### STEP 5 — Update Status to Extracting

**Action**: Update a row (Dataverse)
- Table: `FormSubmission` (`vafe_FormSubmission`)
- Row ID: `variables('var_FormID')`
- Status: `Extracting` (value: `534120001`)

### STEP 6 — AI Extraction Scope (Wrap Steps 6–9 in a Scope)

**Action**: Scope (click + New step → search "Scope")
- Rename scope to: `AI Extraction Scope`

All actions in Steps 6a through 9 below go **inside** this Scope action.

#### STEP 6a — Record Step Start Time

**Action**: Set variable
- Name: `var_StepStart`
- Value: `utcNow()`

#### STEP 6b — Get File Content

**Action**: Get file content (SharePoint)
- Site: `https://uspsgcctenant.sharepoint.com/sites/DpartementofVeteranAffairs`
- File identifier: `triggerOutputs()?['body/{Id}']`

**Action**: Set variable
- Name: `var_FileContent`
- Value: `body('Get_file_content')?['$content']`

#### STEP 6c — Call AI Builder Model

**Action**: Extract information from documents (AI Builder)
- Model: `VAForm10-3542-Extractor`
- Form type: PDF/Image
- Document: `variables('var_FileContent')`

**Action**: Set variable
- Name: `var_AIOutput`
- Value: `body('Extract_information_from_documents')?['responsev2']?['predictionOutput']`

**Action**: Set variable
- Name: `var_Confidence`
- Value: `body('Extract_information_from_documents')?['responsev2']?['predictionOutput']?['labels']?['overallConfidence']`

#### STEP 6d — Log SLA Timing

**Action**: Compose (for SLA instrumentation)
- Name this action: `SLA_AI_Extraction`
- Inputs:
```
{
  "step": "AI Extraction",
  "startTime": "@{variables('var_StepStart')}",
  "endTime": "@{utcNow()}",
  "durationTicks": "@{sub(ticks(utcNow()), ticks(variables('var_StepStart')))}",
  "threshold": 10000,
  "note": "Threshold is 10 seconds (10000 ms)"
}
```

**Action**: Run a child flow → `VA-Audit-Logger`
- FormSubmissionID: `variables('var_FormID')`
- Action: `ExtractionStarted`
- Details: `string(outputs('SLA_AI_Extraction'))`
- Severity: `Info`

#### STEP 7 — Create ExtractionResult Record

**Action**: Add a new row (Dataverse)
- Table: `ExtractionResult` (`vafe_ExtractionResult`)
- Fields:
  - **Form Submission (Lookup)**: `variables('var_FormID')`
  - **Extracted Data**: `string(variables('var_AIOutput'))`
  - **Overall Confidence**: `variables('var_Confidence')`
  - **Extraction Status**: *(set via condition — see Step 8)*
  - **Model Version**: `1.0.0`
  - **Extraction Timestamp**: `utcNow()`

> 📝 Add a condition wrapping this step to set Extraction Status: if `var_Confidence >= 0.85` → `Success` (534120000), else `PartialSuccess` (534120001).

#### STEP 8 — Confidence Threshold Branch

**Action**: Condition
- Left value: `variables('var_Confidence')`
- Operator: `is greater than or equal to`
- Right value: `0.85`

**TRUE branch (high confidence — auto-process)**:

**Action**: Update a row (Dataverse)
- Table: `FormSubmission`
- Row ID: `variables('var_FormID')`
- Status: `Extracted` (value: `534120002`)

**Action**: Run a child flow → `VA-Audit-Logger`
- FormSubmissionID: `variables('var_FormID')`
- Action: `ExtractionComplete`
- Details: `concat('Confidence: ', string(variables('var_Confidence')), ' — auto-processing')`
- Severity: `Info`

**Action**: Run a child flow → `VA-D365-Write-Subflow`
- FormSubmissionID: `variables('var_FormID')`

**FALSE branch (low confidence — manual review)**:

**Action**: Update a row (Dataverse)
- Table: `FormSubmission`
- Row ID: `variables('var_FormID')`
- Status: `Correcting` (value: `534120003`)

**Action**: Run a child flow → `VA-Audit-Logger`
- FormSubmissionID: `variables('var_FormID')`
- Action: `CorrectionRequired`
- Details: `concat('Low confidence: ', string(variables('var_Confidence')), ' — routing to manual review')`
- Severity: `Warning`

**Action**: Apply to each (loop over low-confidence fields)
- Input: `variables('var_AIOutput')?['labels']`
- Inside loop — Condition: `item()?['confidence'] < 0.85`
  - TRUE: Add a new row (Dataverse) → `CorrectionRecord`
    - Form Submission: `variables('var_FormID')`
    - Field Name: `item()?['fieldName']`
    - Original Value: `item()?['value']`
    - Field Confidence: `item()?['confidence']`
    - Status: `Pending` (value: `534120000`)

> This will trigger the VA-Manual-Correction-Queue flow (it listens for new CorrectionRecord rows).

---

### STEP 9 — Scope Error Handler (Configure Run After)

After the Scope action, add these error handling actions:

Click **+ New step** → add the following actions, then for each one: click **...** → **Configure run after** → check **has failed** and uncheck **is successful**.

**Action**: Run a child flow → `VA-Audit-Logger`
- FormSubmissionID: `variables('var_FormID')`
- Action: `ExtractionFailed`
- Details: `concat('Scope failed. Error: ', result('AI_Extraction_Scope')?[0]?['error']?['message'])`
- Severity: `Error`

**Action**: Update a row (Dataverse)
- Table: `FormSubmission`
- Row ID: `variables('var_FormID')`
- Status: `Failed` (value: `534120006`)

**Action**: Get secret (Azure Key Vault) — secret: `teams-webhook-alerts`

**Action**: HTTP POST to alerts webhook:
```json
{
  "@type": "MessageCard",
  "themeColor": "FF0000",
  "title": "🚨 VA Form Intake Pipeline — Extraction Failed",
  "text": "AI extraction failed for Form **@{variables('var_FormID')}**. Check flow run history for details.",
  "sections": [
    {
      "facts": [
        { "name": "Form ID", "value": "@{variables('var_FormID')}" },
        { "name": "File", "value": "@{triggerOutputs()?['body/{FilenameWithExtension}']}" },
        { "name": "Timestamp", "value": "@{utcNow()}" }
      ]
    }
  ]
}
```

**Save the flow.** Verify it is set to **On**.

---

## SLA PERFORMANCE MONITORING

Add `var_StepStart` timestamp captures at the beginning of each major section, following the pattern shown in Step 6d. Required SLA thresholds per Tommy Shelby's requirements:

| Step | SLA Threshold | Alert Channel |
|------|--------------|---------------|
| File validation | 1 second | `#va-form-extraction-alerts` |
| AI model extraction | 10 seconds | `#va-form-extraction-alerts` |
| D365 write | 5 seconds | `#va-form-extraction-alerts` |
| End-to-end (full pipeline) | 60 seconds | `#va-form-extraction-alerts` |

**Pattern for each SLA check** (add after each timed section):
```
Action: Compose — SLA_[StepName]
{
  "step": "[StepName]",
  "durationMs": @{div(sub(ticks(utcNow()), ticks(variables('var_StepStart'))), 10000)},
  "threshold": [ThresholdMs],
  "breached": @{greater(div(sub(ticks(utcNow()), ticks(variables('var_StepStart'))), 10000), [ThresholdMs])}
}
```

Add a condition after each Compose: if `outputs('SLA_[StepName]')?['breached']` equals `true` → send Teams alert to `#va-form-extraction-alerts`.

---

## TESTING GUIDE — 5 SMOKE TEST SCENARIOS

Execute these 5 scenarios after all flows are built and connections are verified. Complete **in order**.

### Scenario 1: Happy Path ✅

**Goal**: Full pipeline runs end-to-end successfully.

1. Upload a valid, clean PDF (use the sample `VA Form 10-3542` test file) to the SharePoint FormIntake library
2. Open Power Automate → Monitor → Cloud flow activity → VA-Form-Intake-Pipeline
3. Watch the run complete
4. **Verify** (open Dataverse tables):
   - FormSubmission row created → Status = `Written`
   - ExtractionResult row created → Confidence ≥ 0.85
   - AuditLog: 5 events present: `FormIntake`, `ExtractionStarted`, `ExtractionComplete`, `D365WriteAttempt`, `D365WriteSuccess`
   - D365WriteEvent row: Status = `Success`
   - Dynamics 365: Contact record created or updated

**Pass criteria**: All 5 AuditLog events present, FormSubmission status = Written, D365 contact exists.

---

### Scenario 2: Invalid File Type 🚫

**Goal**: Non-PDF/image file is rejected gracefully.

1. Upload a `.docx` file to FormIntake library
2. Watch flow run in Monitor
3. **Verify**:
   - Flow terminates with status = Cancelled (not Failed)
   - AuditLog: 1 row with Action = `ErrorOccurred`, Severity = `Warning`
   - No FormSubmission row created (the form never passed intake)

**Pass criteria**: Flow cancelled, AuditLog records the invalid file type with full filename.

---

### Scenario 3: Low Confidence → Manual Review Queue 🔍

**Goal**: Poor-quality scan routes to manual review correctly.

1. Upload a deliberately blurry or low-quality scan (or use the designated low-confidence test file)
2. **Verify**:
   - FormSubmission status = `Correcting`
   - CorrectionRecord rows created for each field below 0.85
   - Teams message posted to `#va-form-extraction-reviews` with correct field names and confidence scores
   - Adaptive card appears in Teams channel with Approve/Skip buttons

**Pass criteria**: CorrectionRecord rows exist, Teams notification received within 30 seconds.

---

### Scenario 4: D365 Failure → Retry Flow Pickup 🔄

**Goal**: D365 write failure is captured and retried automatically.

1. In `VA-D365-Write-Subflow`, temporarily disable or break the D365 HTTP connection (rename the connection or change the org URL to an invalid value)
2. Run the happy path again (upload valid PDF)
3. **Verify after initial failure**:
   - D365WriteEvent row created with Status = `Failed` (Pending), RetryCount = 0
4. **Wait 5–10 minutes** for the scheduled retry flow to run
5. **Verify retry**:
   - D365WriteEvent RetryCount incremented
   - VA-D365-Retry-Logic shows a run in Monitor
6. Restore the D365 connection to valid
7. Let retry succeed
8. **Verify**:
   - D365WriteEvent Status = `Success`
   - FormSubmission Status = `Written`

**Pass criteria**: RetryCount incremented, eventual success after connection restored.

---

### Scenario 5: Audit Trail Completeness 📋

**Goal**: All AuditLog events are present after the happy path.

After running Scenario 1 (happy path), open the `vafe_AuditLog` Dataverse table and filter by the FormSubmission ID.

**Required events** (all 5 must be present):

| # | Action | Severity |
|---|--------|----------|
| 1 | `FormIntake` | Info |
| 2 | `ExtractionStarted` | Info |
| 3 | `ExtractionComplete` | Info |
| 4 | `D365WriteAttempt` | Info |
| 5 | `D365WriteSuccess` | Info |

**Pass criteria**: All 5 rows present, timestamps in chronological order, total elapsed time (row 1 → row 5) < 60 seconds.

---

## HANDOFF CHECKLIST (Before Handing to Grace Burgess / QA)

- [ ] All 5 flows saved, turned ON, and visible in VA-Form-Extraction solution
- [ ] All 5 smoke test scenarios passed
- [ ] Flow run history clean (no unexpected failures in last 24 hours)
- [ ] All 6 connections showing green (Connected)
- [ ] Teams webhook notifications received in all 4 channels during testing
- [ ] AuditLog populated with events from testing
- [ ] D365WriteEvent records visible in Dataverse

---

## QUICK REFERENCE — FLOW DEPENDENCY MAP

```
SharePoint FormIntake trigger
        │
        ▼
VA-Form-Intake-Pipeline (main)
        │
        ├──► VA-Audit-Logger (called at each major step)
        │
        ├──► [confidence ≥ 0.85] VA-D365-Write-Subflow
        │           └──► VA-Audit-Logger
        │
        └──► [confidence < 0.85] VA-Manual-Correction-Queue
                    │
                    └──► [after correction] VA-D365-Write-Subflow
                                └──► VA-Audit-Logger

Scheduled (every 5 min):
VA-D365-Retry-Logic
        └──► [status=Failed, retryCount<5] VA-D365-Write-Subflow
```

---

## KEY DATAVERSE STATUS VALUES REFERENCE

| Table | Status Label | Option Set Value |
|-------|-------------|-----------------|
| FormSubmission | Intake | 534120000 |
| FormSubmission | Extracting | 534120001 |
| FormSubmission | Extracted | 534120002 |
| FormSubmission | Correcting | 534120003 |
| FormSubmission | Corrected | 534120004 |
| FormSubmission | Written | 534120005 |
| FormSubmission | Failed | 534120006 |
| ExtractionResult | Success | 534120000 |
| ExtractionResult | PartialSuccess | 534120001 |
| ExtractionResult | Failed | 534120002 |
| D365WriteEvent | Success | 534120001 |
| D365WriteEvent | Failed/Pending | 534120002 |
| D365WriteEvent | PermanentFail | 534120003 |
| CorrectionRecord | Pending | 534120000 |
| CorrectionRecord | Corrected | 534120001 |

---

*Document prepared by John Shelby, Power Automate Flow Orchestration Lead*  
*Phase 2 → 3 Execution — April 26, 2026*  
*Next Step (May 3, 2026): Human operator builds flows. Polly's tables and Michael's AI model must be confirmed published/provisioned first.*
