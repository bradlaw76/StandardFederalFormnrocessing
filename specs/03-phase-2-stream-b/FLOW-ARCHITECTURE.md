# Power Automate Flow Architecture — VA Form 10-3542 Extraction Pipeline
**Issue #18 — Stream B-2: Flow Orchestration**  
**Owner**: John Shelby, Power Automate Flow Orchestration Lead  
**Date**: 2026-04-25  
**Status**: ✅ DESIGN COMPLETE

---

## Executive Summary

This document defines the **end-to-end Power Automate flow architecture** for the VA Form 10-3542 extraction pipeline. Five flows orchestrate form intake, AI-powered extraction, validation, D365 synchronization, and error recovery.

**Architecture Overview**:
- **Main Flow**: VA-Form-Intake-Pipeline (triggered on SharePoint file upload)
- **Subflow 1**: Manual-Correction-Queue (routes low-confidence extractions to human review)
- **Subflow 2**: D365-Retry-Logic (scheduled recovery for failed D365 writes)
- **Subflow 3**: Audit-Event-Logger (logs all events to compliance table)
- **Subflow 4**: Notification-Router (sends Teams/email alerts)

---

## Flow Topology

```
SharePoint FormIntake
    ↓
[MAIN FLOW: VA-Form-Intake-Pipeline]
    ├─ Step 1: Validate & Parse Input File
    ├─ Step 2: Call AI Builder Model
    ├─ Step 3: Data Validation & Transformation
    ├─ Step 4: Write to Dynamics 365
    └─ Step 5: Update FormSubmission Status
         ↓
    [IF high confidence → D365 direct write]
    [IF low confidence → Manual-Correction-Queue subflow]
    [IF any error → Audit-Event-Logger + Notification-Router]
         ↓
[Scheduled: D365-Retry-Logic (every 5 min)]
    Scans D365WriteEvent table for Pending/Failed
    Retries up to 5 times with exponential backoff
```

---

## MAIN FLOW: VA-Form-Intake-Pipeline

### Flow Properties

| Property | Value |
|----------|-------|
| **Flow Name** | VA-Form-Intake-Pipeline |
| **Flow Type** | Cloud Flow → Automated |
| **Trigger** | When a file is created or modified (SharePoint) |
| **Scope** | FormIntake library, `vafe_` prefix files only |
| **Timeout** | 60 seconds per form (end-to-end SLA) |
| **Batch Mode** | Sequential (1 form at a time) |
| **Retry Policy** | Built-in retries per step (see Error Handling) |

---

### Trigger Definition

**Trigger**: "When a file is created or modified" (SharePoint connector)

```
Trigger Configuration:
├─ Site: VA-Form-Extraction site (D365-integrated)
├─ Library: FormIntake (document set)
├─ Filter: File name starts with "vafe_"
│  (Example: vafe_1001_2026-04-25_shelby-john.pdf)
└─ Advanced: 
   ├─ Trigger Frequency: Every 1 minute
   ├─ Include Attachments: No
   └─ Trigger Sensitivity: Standard
```

**File Naming Convention**:
```
Format: vafe_{sequence}_{YYYY-MM-DD}_{user-identifier}.{ext}
Example: vafe_10001_2026-04-25_va-veteran-smith.pdf
         vafe_10002_2026-04-25_intake-form-batch.tif

Allowed extensions: .pdf, .tiff, .tif, .png, .jpg, .jpeg
Rejected: .doc, .xls, .zip, .exe, etc.
```

---

## STEP 1: Validate & Parse Input File

**Purpose**: Verify file integrity, extract metadata, create FormSubmission record

### Actions (Sequential)

#### 1.1 Initialize Variables

```
Action: Initialize variable
Name: FileContext
Type: Object
Value: {
  "fileName": @{triggerOutputs()['headers']['x-ms-file-name']},
  "fileSize": @{triggerOutputs()['headers']['content-length']},
  "fileUri": @{triggerOutputs()['headers']['x-ms-file-uri']},
  "submissionTime": @{utcNow()},
  "formId": @{substring(triggerOutputs()['headers']['x-ms-file-name'], 5, 5)}
}
```

#### 1.2 Check File Exists & Extract Metadata

```
Action: Get file metadata (SharePoint)
Inputs:
├─ Site: VA-Form-Extraction
├─ Library: FormIntake
├─ ID: @{triggerBody()?['id']}
Outputs: metadata (name, size, modified, created)

Action: Compose - Parse File Extension
Input: @{last(split(body('Get_file_metadata')?['Name'], '.'))}
Output: FileExtension
```

#### 1.3 Validate File Type

```
Action: Condition - Is Valid File Type?
Condition: 
  AND(
    or(
      equals(body('Compose_FileExtension'), 'pdf'),
      equals(body('Compose_FileExtension'), 'tiff'),
      equals(body('Compose_FileExtension'), 'tif'),
      equals(body('Compose_FileExtension'), 'png'),
      equals(body('Compose_FileExtension'), 'jpg'),
      equals(body('Compose_FileExtension'), 'jpeg')
    ),
    lessOrEquals(body('Get_file_metadata')?['size'], 5242880) // 5MB max
  )

If YES → Continue to 1.4
If NO → Go to Error: InvalidFileType (see Error Handling)
```

#### 1.4 Create FormSubmission Record

```
Action: Create a new record (Dataverse)
Table: FormSubmission (vafe_formsubmission)
Fields:
├─ vafe_form_id: @{variables('FileContext').formId}
├─ vafe_file_name: @{body('Get_file_metadata')?['Name']}
├─ vafe_file_url: @{body('Get_file_metadata')?['webUrl']}
├─ vafe_file_size: @{body('Get_file_metadata')?['size']}
├─ vafe_submitted_date: @{body('Get_file_metadata')?['created']}
├─ vafe_status: 100000000 // Intake
├─ vafe_extraction_confidence: 0
└─ vafe_ai_model_version: "VAForm10-3542-Extractor-v1"

Output: FormSubmissionID = @{body('Create_FormSubmission')?['vafe_formsubmissionid']}
```

#### 1.5 Log Intake Event

```
Action: Create a new record (Dataverse)
Table: AuditLog (vafe_auditlog)
Fields:
├─ vafe_form_submission: @{variables('FormSubmissionID')}
├─ vafe_event_type: 100000001 // FileValidated
├─ vafe_event_date: @{utcNow()}
├─ vafe_status: 100000000 // Success
└─ vafe_details: {
    "fileName": "@{body('Get_file_metadata')?['Name']}",
    "fileSize": "@{body('Get_file_metadata')?['size']}",
    "fileExtension": "@{body('Compose_FileExtension')}"
  }
```

**Output**: FormSubmissionID, file URI, status = "Intake"  
**Error Handling**: See Section 6

---

## STEP 2: Call AI Builder Model

**Purpose**: Extract form fields using AI Builder custom model, capture confidence scores

### Actions (Sequential)

#### 2.1 Read File Content

```
Action: Get file content (SharePoint)
Inputs:
├─ Site: VA-Form-Extraction
├─ Library: FormIntake
├─ ID: @{body('Get_file_metadata')?['id']}
Outputs: FileContent (binary)

Action: Compose - Convert to Base64
Input: @{base64(body('Get_file_content'))}
Output: Base64FileContent
```

#### 2.2 Prepare AI Model Payload

```
Action: Compose - Build Model Input
Input JSON:
{
  "file": "@{body('Compose_Base64FileContent')}",
  "fileType": "@{body('Compose_FileExtension')}",
  "modelId": "$(model-id-from-michael)",
  "requestId": "@{variables('FormSubmissionID')}",
  "processingOptions": {
    "returnConfidenceScores": true,
    "returnRawText": true,
    "timeout": 30000
  }
}

Action: Set variable - ModelPayload
Value: @{body('Compose_Build_Model_Input')}
```

#### 2.3 Call AI Builder Model (With Timeout)

```
Action: Invoke AI Builder Model
(Custom Document Processing)
Inputs:
├─ Document: @{body('Get_file_content')}
├─ Model: VAForm10-3542-Extractor
Outputs:
├─ extractedFields: {array of { key, value, text }}
├─ confidenceScores: {array of { key, confidence }}
└─ modelMetadata: { version, processingTime }

Timeout: 30 seconds
Retry Policy: 1 automatic retry

Output Variables:
├─ ExtractionResult = body('Invoke_AI_Builder_Model')?['extractedFields']
├─ ConfidenceScores = body('Invoke_AI_Builder_Model')?['confidenceScores']
└─ ProcessingTime = body('Invoke_AI_Builder_Model')?['modelMetadata']?['processingTime']
```

#### 2.4 Create ExtractionResult Record

```
Action: Create a new record (Dataverse)
Table: ExtractionResult (vafe_extractionresult)
Fields:
├─ vafe_form_submission: @{variables('FormSubmissionID')}
├─ vafe_extracted_fields: @{json(body('Compose_ExtractedFields'))}
│  // JSON array: [{ "fieldName": "...", "value": "...", "rawText": "..." }]
├─ vafe_field_confidence_scores: @{json(body('Compose_ConfidenceScores'))}
│  // JSON array: [{ "fieldName": "...", "confidence": 0.95 }]
├─ vafe_ai_model_version: "VAForm10-3542-Extractor-v1"
├─ vafe_status: 100000000 // Success (if extraction succeeded)
└─ vafe_extraction_timestamp: @{utcNow()}

Output: ExtractionResultID = @{body('Create_ExtractionResult')?['vafe_extractionresultid']}
```

#### 2.5 Log Extraction Event

```
Action: Create a new record (Dataverse)
Table: AuditLog (vafe_auditlog)
Fields:
├─ vafe_form_submission: @{variables('FormSubmissionID')}
├─ vafe_event_type: 100000002 // ExtractionCompleted
├─ vafe_event_date: @{utcNow()}
├─ vafe_status: 100000000 // Success
└─ vafe_details: {
    "processingTimeMs": "@{variables('ProcessingTime')}",
    "fieldsExtracted": "@{length(variables('ExtractionResult'))}",
    "avgConfidence": "@{avg(map(variables('ConfidenceScores'), item().confidence))}"
  }
```

**Output**: ExtractionResult record, confidence_scores JSON, status = "Success"  
**Error Handling**: See Section 6 (Timeout = retry 1x, Model error = log + manual review queue)

---

## STEP 3: Data Validation & Transformation

**Purpose**: Validate confidence thresholds, transform to D365 schema, route low-confidence to manual review

### Actions (Sequential)

#### 3.1 Calculate Average Confidence

```
Action: Compose - Calculate Average Confidence
Input: 
  @{avg(map(body('Parse_Confidence_Scores'), item().confidence))}
Output: AvgConfidence (decimal: 0.0 - 1.0)

Action: Set variable - ConfidenceThreshold
Value: 0.85 // Configurable threshold
```

#### 3.2 Check Minimum Confidence (>0.85)

```
Action: Condition - All Fields Confidence > Threshold?
Condition: 
  AND(
    greaterOrEquals(variables('AvgConfidence'), variables('ConfidenceThreshold')),
    equals(
      length(
        filter(
          variables('ConfidenceScores'),
          item().confidence < 0.85
        )
      ),
      0
    )
  )
```

#### 3.3a - HIGH CONFIDENCE PATH (All >0.85)

```
If YES:
  Action: Set variable - HighConfidence = true
  
  Action: Compose - Transform to D365 Payload
  Input: extracted fields from Step 2
  Mappings:
  ├─ AI Field "veteran_name" → D365 "lastname"
  ├─ AI Field "veteran_dob" → D365 "birthdate" (parse to YYYY-MM-DD)
  ├─ AI Field "ssn" → D365 "ssn" (format: XXX-XX-XXXX)
  ├─ AI Field "service_number" → D365 "accountnumber"
  ├─ [28 more field mappings per Michael's spec]
  └─ Add metadata: { source: "AI-Form-10-3542", submissionId: "@{FormSubmissionID}" }
  
  Output: D365Payload (JSON object ready for API call)
  
  Action: Create a new record (Dataverse)
  Table: D365WriteEvent (vafe_d365writeevent)
  Fields:
  ├─ vafe_form_submission: @{variables('FormSubmissionID')}
  ├─ vafe_mapped_fields: @{json(body('Compose_D365_Payload'))}
  ├─ vafe_status: 100000000 // Pending
  ├─ vafe_retry_count: 0
  └─ vafe_d365_table: "accounts"
  
  Output: D365WriteEventID
  
  → Proceed to STEP 4 (D365 Write)
```

#### 3.3b - LOW CONFIDENCE PATH (Any <0.85)

```
If NO:
  Action: Set variable - HighConfidence = false
  
  Action: Filter - Get Low-Confidence Fields
  Input: @{filter(variables('ConfidenceScores'), item().confidence < 0.85)}
  Output: LowConfidenceFields (array)
  
  Action: For each LowConfidenceField:
    Create a new record (Dataverse)
    Table: CorrectionRecord (vafe_correctionrecord)
    Fields:
    ├─ vafe_extraction_result: @{variables('ExtractionResultID')}
    ├─ vafe_field_name: @{item().fieldName}
    ├─ vafe_original_value: @{item().value}
    ├─ vafe_confidence_before: @{item().confidence}
    ├─ vafe_status: 100000000 // Pending
    └─ vafe_reason: "LowConfidence - Manual Review Required"
  
  Action: Create Pending D365WriteEvent with status = "OnHold"
  
  Action: Invoke subflow - Manual-Correction-Queue
  Inputs:
  ├─ FormSubmissionID: @{variables('FormSubmissionID')}
  ├─ ExtractionResultID: @{variables('ExtractionResultID')}
  ├─ LowConfidenceFields: @{variables('LowConfidenceFields')}
  └─ AutoReviewThreshold: 0.85
  
  → Wait for manual correction (see Subflow 1)
```

#### 3.4 Update FormSubmission Status (After Validation)

```
Action: Update a record (Dataverse)
Table: FormSubmission
Record ID: @{variables('FormSubmissionID')}
Fields:
├─ vafe_status: 
│  IF HighConfidence = true  → 100000003 (ReadyForD365Write)
│  IF HighConfidence = false → 100000004 (PendingCorrectionReview)
├─ vafe_extraction_confidence: @{variables('AvgConfidence')}
└─ vafe_validated_timestamp: @{utcNow()}
```

#### 3.5 Log Validation Event

```
Action: Create a new record (Dataverse)
Table: AuditLog (vafe_auditlog)
Fields:
├─ vafe_form_submission: @{variables('FormSubmissionID')}
├─ vafe_event_type: 
│  IF HighConfidence = true  → 100000003 (ValidationPassed)
│  IF HighConfidence = false → 100000004 (ValidationManualReviewRequired)
├─ vafe_event_date: @{utcNow()}
├─ vafe_status: 100000000 // Success
└─ vafe_details: {
    "avgConfidence": "@{variables('AvgConfidence')}",
    "lowConfidenceFields": "@{if(not(variables('HighConfidence')), length(variables('LowConfidenceFields')), 0)}"
  }
```

**Output**: D365RecordPayload (JSON), status = "ReadyForD365Write" or "PendingCorrectionReview"  
**Error Handling**: See Section 6 (Validation failure → manual review queue, Transform error → escalate)

---

## STEP 4: Write to Dynamics 365

**Purpose**: Create or update account in D365, handle duplicates, retry on failure

### Actions (Sequential)

#### 4.1 Prepare D365 Write Payload

```
Action: Compose - Build D365 Account Payload
Input from Step 3: D365Payload
Output JSON:
{
  "name": "@{body('Parse_D365_Payload')?['veteran_name']}",
  "accountnumber": "@{body('Parse_D365_Payload')?['service_number']}",
  "emailaddress1": "@{body('Parse_D365_Payload')?['email']}",
  "address1_city": "@{body('Parse_D365_Payload')?['city']}",
  "address1_stateorprovince": "@{body('Parse_D365_Payload')?['state']}",
  "address1_postalcode": "@{body('Parse_D365_Payload')?['zip_code']}",
  "customersizecode": 100000000, // Veteran
  "ava_form_source": "vafe_form_10_3542",
  "ava_submission_id": "@{variables('FormSubmissionID')}",
  // [28+ more fields per Alfie's mapping]
}
```

#### 4.2 Check for Duplicate Account

```
Action: Invoke HTTP - Query D365 for Duplicates
Method: GET
URI: https://{org}.crm.dynamics.com/api/data/v9.2/accounts?$filter=
  (accountnumber eq '@{body('Parse_D365_Payload')?['service_number']}') 
  or (lastname eq '@{body('Parse_D365_Payload')?['veteran_name']}' 
  and birthdate eq @{body('Parse_D365_Payload')?['birthdate']})
Headers:
├─ Authorization: Bearer @{connection('dynamics365').token}
├─ Content-Type: application/json
└─ OData-MaxPageSize: 2

Output: DuplicateCheckResult = @{body('Query_D365_Duplicates')?['value']}

Condition: Is Duplicate Found?
Count = @{length(body('Query_D365_Duplicates')?['value'])}
```

#### 4.3a - NO DUPLICATE (CREATE NEW ACCOUNT)

```
If Count = 0:
  Action: Create a record (Dynamics 365 HTTP)
  Method: POST
  URI: https://{org}.crm.dynamics.com/api/data/v9.2/accounts
  Body: @{body('Compose_D365_Account_Payload')}
  
  Output: D365ResponseCreate
  ├─ odata.id: "account/{accountId}"
  ├─ accountid: {UUID}
  └─ statuscode: 201
  
  Action: Set variable - D365RecordID
  Value: @{body('Create_D365_Account')?['accountid']}
  
  Action: Set variable - D365WriteStatus
  Value: "Created"
```

#### 4.3b - DUPLICATE FOUND (UPDATE EXISTING)

```
If Count > 0:
  Action: Set variable - D365RecordID
  Value: @{body('Query_D365_Duplicates')?['value'][0]?['accountid']}
  
  Action: Update a record (Dynamics 365 HTTP)
  Method: PATCH
  URI: https://{org}.crm.dynamics.com/api/data/v9.2/accounts(@{variables('D365RecordID')})
  Body: @{body('Compose_D365_Account_Payload')}
  
  Output: D365ResponseUpdate
  ├─ statuscode: 204
  └─ Response: Empty (success)
  
  Action: Set variable - D365WriteStatus
  Value: "Updated"
  
  Action: Create a new record (Dataverse)
  Table: AuditLog (vafe_auditlog)
  Fields:
  ├─ vafe_form_submission: @{variables('FormSubmissionID')}
  ├─ vafe_event_type: 100000006 // D365DuplicateDetected
  ├─ vafe_status: 100000000 // Success
  └─ vafe_details: {
      "existingAccountId": "@{variables('D365RecordID')}",
      "action": "Updated existing account"
    }
```

#### 4.4 Log D365 Write Event

```
Action: Update a record (Dataverse)
Table: D365WriteEvent
Record ID: @{variables('D365WriteEventID')}
Fields:
├─ vafe_d365_record_id: @{variables('D365RecordID')}
├─ vafe_status: 100000001 // Success
├─ vafe_write_date: @{utcNow()}
├─ vafe_mapped_fields: @{json(body('Compose_D365_Account_Payload'))}
└─ vafe_d365_write_method: @{variables('D365WriteStatus')} // "Created" or "Updated"
```

#### 4.5 Log Completion Event

```
Action: Create a new record (Dataverse)
Table: AuditLog (vafe_auditlog)
Fields:
├─ vafe_form_submission: @{variables('FormSubmissionID')}
├─ vafe_event_type: 100000005 // D365WriteCompleted
├─ vafe_event_date: @{utcNow()}
├─ vafe_status: 100000000 // Success
└─ vafe_details: {
    "d365RecordId": "@{variables('D365RecordID')}",
    "writeMethod": "@{variables('D365WriteStatus')}",
    "d365Timestamp": "@{utcNow()}"
  }
```

**Output**: D365WriteEvent record, status = "Success", D365 record ID  
**Error Handling**: See Section 6 (Connection failure → 3x retry, Duplicate conflict → escalate, Timeout → mark Pending + retry)

---

## STEP 5: Update FormSubmission Status & Complete

**Purpose**: Mark form as written, link all related records, lock submission

### Actions (Sequential)

#### 5.1 Update FormSubmission Final Status

```
Action: Update a record (Dataverse)
Table: FormSubmission
Record ID: @{variables('FormSubmissionID')}
Fields:
├─ vafe_status: 100000005 // Written (completed)
├─ vafe_extraction_result: @{variables('ExtractionResultID')}
├─ vafe_d365_write_event: @{variables('D365WriteEventID')}
├─ vafe_completion_date: @{utcNow()}
└─ vafe_form_locked: true // Immutable from now on
```

#### 5.2 Create Final Audit Record

```
Action: Create a new record (Dataverse)
Table: AuditLog (vafe_auditlog)
Fields:
├─ vafe_form_submission: @{variables('FormSubmissionID')}
├─ vafe_event_type: 100000007 // FormProcessingComplete
├─ vafe_event_date: @{utcNow()}
├─ vafe_status: 100000000 // Success
└─ vafe_details: {
    "totalProcessingTime": "@{sub(ticks(utcNow()), ticks(variables('StartTime')))}ms",
    "d365RecordId": "@{variables('D365RecordID')}",
    "extractionConfidence": "@{variables('AvgConfidence')}",
    "status": "COMPLETE"
  }
```

#### 5.3 Send Completion Notification (If Configured)

```
Action: Condition - Is Notification Enabled?
Lookup: Organization preference (vafe_notification_enabled)

If YES:
  Action: Invoke subflow - Notification-Router
  Inputs:
  ├─ FormSubmissionID: @{variables('FormSubmissionID')}
  ├─ D365RecordID: @{variables('D365RecordID')}
  ├─ NotificationType: "FormProcessingComplete"
  ├─ Status: "Success"
  └─ Recipients: (from configuration)
```

**Output**: Final FormSubmission record, status = "Written" (locked)  
**End-to-End Timing**: <60 seconds

---

## SUBFLOW 1: Manual-Correction-Queue

**Purpose**: Route low-confidence extractions to human review, apply corrections, retry D365 write

### Subflow Properties

| Property | Value |
|----------|-------|
| **Subflow Name** | Manual-Correction-Queue |
| **Type** | Cloud Flow → Automated |
| **Trigger** | Invoked from Main Flow (Step 3) |
| **Queue Monitor** | Monitors CorrectionRecord table for Pending status |

### Actions (Sequential)

#### Q1: Create Approval Task in Teams

```
Action: Post an adaptive card to Teams
Channel: #va-form-extraction-reviews
Card JSON:
{
  "type": "message",
  "attachments": [
    {
      "contentType": "application/vnd.microsoft.card.adaptive",
      "contentUrl": null,
      "content": {
        "type": "AdaptiveCard",
        "version": "1.4",
        "body": [
          {
            "type": "TextBlock",
            "size": "Large",
            "weight": "Bolder",
            "text": "📋 VA Form Correction Required"
          },
          {
            "type": "TextBlock",
            "text": "Form ID: @{variables('FormSubmissionID')} | Confidence: @{variables('AvgConfidence')}"
          },
          {
            "type": "TextBlock",
            "text": "Low-Confidence Fields:",
            "weight": "Bolder"
          },
          {
            "type": "Table",
            "columns": [
              { "width": "30%" },
              { "width": "35%" },
              { "width": "35%" }
            ],
            "rows": [
              [
                {
                  "items": [
                    {
                      "type": "TextBlock",
                      "text": "Field",
                      "weight": "Bolder"
                    }
                  ]
                },
                {
                  "items": [
                    {
                      "type": "TextBlock",
                      "text": "Extracted Value",
                      "weight": "Bolder"
                    }
                  ]
                },
                {
                  "items": [
                    {
                      "type": "TextBlock",
                      "text": "Confidence",
                      "weight": "Bolder"
                    }
                  ]
                }
              ],
              "@{addProperty(array(), 'cells', map(variables('LowConfidenceFields'), 
                array(
                  object('type', 'TextBlock', 'text', item().fieldName),
                  object('type', 'TextBlock', 'text', item().value),
                  object('type', 'TextBlock', 'text', string(item().confidence))
                ))
              )}"
            ]
          },
          {
            "type": "TextBlock",
            "text": "Please review extracted values and correct any errors below."
          }
        ],
        "actions": [
          {
            "type": "Action.OpenUrl",
            "title": "🔍 Review in Dataverse",
            "url": "https://{org}.crm.dynamics.com/main.aspx?appid={app-id}&pagetype=entityrecord&etn=vafe_correctionrecord&id=@{variables('CorrectionRecordID')}"
          },
          {
            "type": "Action.OpenUrl",
            "title": "✅ Mark as Reviewed",
            "url": "https://flow.microsoft.com/approvals/@{variables('FormSubmissionID')}"
          }
        ]
      }
    }
  ]
}
```

#### Q2: Poll for CorrectionRecord Updates (30-minute timeout)

```
Action: Do Until (loop with timeout)
Condition: CorrectionRecord status = "Applied" OR 30 minutes elapsed
Loop Interval: 30 seconds

Inside Loop:
  Action: Get a record (Dataverse)
  Table: CorrectionRecord
  Record ID: @{variables('CorrectionRecordID')}
  
  Action: Condition - Status = Applied?
  IF YES:
    Set variable: CorrectionApplied = true
    Break loop
  
  IF NO AND timeout:
    Set variable: CorrectionApplied = false
    Log escalation event
    Break loop
```

#### Q3: Apply Corrections (If Approved)

```
If CorrectionApplied = true:
  Action: For each CorrectionRecord:
    Get record details (corrected_value, corrected_by)
    
    Action: Update ExtractionResult
    Update JSON: @{replace(
      body('Parse_Extracted_Fields'),
      concat('"', item().vafe_field_name, '": "'),
      concat('"', item().vafe_corrected_value, '": "')
    )}
    
    Action: Update CorrectionRecord
    Fields:
    ├─ vafe_status: 100000001 // Applied
    ├─ vafe_corrected_date: @{utcNow()}
    └─ vafe_confidence_after: 1.0 // Manually approved = high confidence
    
    Action: Create AuditLog
    ├─ event_type: 100000008 // CorrectionApplied
    └─ details: { correctedBy: "@{item().vafe_corrected_by}", field: "@{item().vafe_field_name}" }
  
  → Proceed to D365 Write (re-run Step 4 with corrected values)

Else (30-min timeout, no correction):
  Action: Escalate to Admin
  Update FormSubmission: status = "PendingAdminReview"
  Create AuditLog: event_type = "CorrectionTimeoutEscalation"
  Send notification to admin queue
```

**Output**: Corrected D365 payload, ready for retry D365 write

---

## SUBFLOW 2: D365-Retry-Logic (Scheduled)

**Purpose**: Recover failed D365 writes with exponential backoff (every 5 minutes)

### Scheduled Flow Properties

| Property | Value |
|----------|-------|
| **Subflow Name** | D365-Retry-Logic |
| **Type** | Cloud Flow → Scheduled |
| **Schedule** | Every 5 minutes |
| **Timeout** | 45 seconds (must complete within flow window) |

### Actions (Sequential)

#### R1: Query Pending D365WriteEvent Records

```
Action: List records (Dataverse)
Table: D365WriteEvent (vafe_d365writeevent)
Filter: 
  $filter=vafe_status eq 100000000 (Pending) 
  AND vafe_retry_count lt 5 
  AND vafe_write_date gt @{addMinutes(utcNow(), -5)}
$orderby=vafe_write_date asc
$top: 10 (batch process up to 10 at a time)

Output: PendingWrites = @{body('List_D365WriteEvents')?['value']}
```

#### R2: For Each Pending Write (Parallel, Max 5)

```
Action: Apply to each
Input: @{variables('PendingWrites')}
Parallelization: 5 items at a time (built-in throttle)

Inside Loop:
  R2.1: Get FormSubmission Record
  Retrieve: @{item().vafe_form_submission}
  
  R2.2: Get D365WriteEvent Details
  Retrieve: @{item()}
  
  R2.3: Calculate Retry Backoff
  Current Retry: @{item().vafe_retry_count}
  Backoff Formula: exponential(retry) = 2^retry * 100ms
  Example:
  ├─ Retry 1 → 200ms
  ├─ Retry 2 → 400ms
  ├─ Retry 3 → 800ms
  ├─ Retry 4 → 1600ms
  ├─ Retry 5 → 3200ms (max)
  
  Wait: @{mul(pow(2, item().vafe_retry_count), 100)}ms
```

#### R3: Attempt D365 Write Retry

```
Inside Loop (continued):
  R3.1: Prepare Retry Payload
  Payload = @{item().vafe_mapped_fields}
  D365RecordID = @{item().vafe_d365_record_id}
  D365Table = @{item().vafe_d365_table}
  
  R3.2: Check If Account Still Exists
  Action: Invoke HTTP (Query D365)
  Method: GET
  URI: https://{org}.crm.dynamics.com/api/data/v9.2/accounts(@{D365RecordID})
  Headers: Bearer @{connection('dynamics365').token}
  
  Condition: Account exists?
  ├─ Status 200 → Account found, proceed to R3.3
  ├─ Status 404 → Account deleted/migrated, mark as failed
  └─ Status 5xx → Service error, log & retry again next cycle
```

#### R4: Retry D365 Update

```
If Account Exists:
  R4.1: Attempt Update
  Action: Invoke HTTP (PATCH)
  Method: PATCH
  URI: https://{org}.crm.dynamics.com/api/data/v9.2/accounts(@{D365RecordID})
  Body: @{json(item().vafe_mapped_fields)}
  Timeout: 15 seconds
  Retry Policy: 1 automatic retry
  
  Output: RetryResponse (status 204 = success)
  
  R4.2: Check Retry Success
  Condition: statusCode = 204?
  
  If YES (Success):
    Action: Update D365WriteEvent
    Fields:
    ├─ vafe_status: 100000001 // Success
    ├─ vafe_retry_count: @{add(item().vafe_retry_count, 1)}
    ├─ vafe_last_retry_date: @{utcNow()}
    └─ vafe_last_retry_response: "204 OK - Update successful"
    
    Action: Update FormSubmission
    Fields:
    ├─ vafe_status: 100000005 // Written
    └─ vafe_d365_write_event: @{item().vafe_d365writeeventid}
    
    Action: Create AuditLog
    ├─ event_type: 100000009 // D365WriteRetrySuccess
    ├─ vafe_status: 100000000 // Success
    └─ details: { 
        retryAttempt: "@{add(item().vafe_retry_count, 1)}", 
        originalWriteDate: "@{item().vafe_write_date}"
      }
  
  If NO (Still Failing):
    Action: Condition - Retry Count < 5?
    
    If YES (< 5):
      Action: Update D365WriteEvent
      Fields:
      ├─ vafe_status: 100000000 // Still Pending
      ├─ vafe_retry_count: @{add(item().vafe_retry_count, 1)}
      ├─ vafe_last_retry_date: @{utcNow()}
      └─ vafe_last_retry_response: "@{body('Retry_D365_Update')}"
      
      Action: Create AuditLog
      ├─ event_type: 100000010 // D365WriteRetryFailed
      ├─ vafe_status: 100000001 // Failure
      └─ details: { retryAttempt: "@{add(item().vafe_retry_count, 1)}" }
      
      (Will retry again in next 5-minute cycle)
    
    If NO (= 5):
      Action: Update D365WriteEvent
      Fields:
      ├─ vafe_status: 100000002 // Failed (Max retries exceeded)
      ├─ vafe_retry_count: 5
      └─ vafe_last_retry_response: "Max retries (5) exceeded"
      
      Action: Update FormSubmission
      ├─ vafe_status: 100000006 // D365WriteFailedEscalated
      
      Action: Create AuditLog
      ├─ event_type: 100000011 // D365WriteMaxRetriesExceeded
      └─ details: { totalRetries: "5" }
      
      Action: Invoke subflow - Notification-Router
      ├─ Type: "D365WriteFailure"
      ├─ Severity: "Critical"
      └─ Recipients: Admin queue
```

#### R5: Account Deleted/Migrated Case

```
If Account Does Not Exist (404):
  Action: Update D365WriteEvent
  ├─ vafe_status: 100000002 // Failed
  ├─ vafe_last_retry_response: "404 - Account no longer exists in D365"
  
  Action: Update FormSubmission
  ├─ vafe_status: 100000007 // D365AccountNotFound
  
  Action: Create AuditLog
  ├─ event_type: 100000012 // D365AccountNotFound
  └─ details: { originalD365RecordId: "@{item().vafe_d365_record_id}" }
  
  Action: Create Escalation Task
  ├─ Type: "Account Recovery Required"
  └─ Assigned To: Admin
```

---

## SUBFLOW 3: Audit-Event-Logger

**Purpose**: Centralized logging for all events (immutable compliance trail)

### Subflow Properties

| Property | Value |
|----------|-------|
| **Subflow Name** | Audit-Event-Logger |
| **Type** | Cloud Flow → Automated (Invoked) |
| **Trigger** | Invoked from main flow & all subflows |

### Actions

```
Action: Create a new record (Dataverse)
Table: AuditLog (vafe_auditlog)
Parameters:
├─ FormSubmissionID (from parent flow)
├─ EventType (from parent: FileValidated, ExtractionCompleted, etc.)
├─ Status (Success/Failure)
├─ Details (JSON object with context)

Output: AuditLogID
```

**Events Logged**:
1. FileValidated (100000001)
2. ExtractionCompleted (100000002)
3. ValidationPassed (100000003)
4. ValidationManualReviewRequired (100000004)
5. D365WriteCompleted (100000005)
6. D365DuplicateDetected (100000006)
7. FormProcessingComplete (100000007)
8. CorrectionApplied (100000008)
9. D365WriteRetrySuccess (100000009)
10. D365WriteRetryFailed (100000010)
11. D365WriteMaxRetriesExceeded (100000011)
12. D365AccountNotFound (100000012)

---

## SUBFLOW 4: Notification-Router

**Purpose**: Send Teams/email alerts based on event type and severity

### Subflow Properties

| Property | Value |
|----------|-------|
| **Subflow Name** | Notification-Router |
| **Type** | Cloud Flow → Automated (Invoked) |
| **Trigger** | Invoked from main & subflows |

### Actions

```
Action: Switch - NotificationType

Case 1: FormProcessingComplete
  → Post success card to Teams #va-form-extraction-reviews
  
Case 2: D365WriteFailure
  → Post failure alert to Teams + email admin@va-form-extraction
  
Case 3: CorrectionTimeoutEscalation
  → Post escalation card + create task
  
Case 4: LowConfidenceRequiresReview
  → Post review card to Teams + @mention assigned reviewer

Default: Log only (no notification)
```

---

## Error Handling Strategy

### Error Taxonomy & Recovery Paths

| Phase | Error Type | Retry Logic | Resolution | Escalation |
|-------|-----------|-------------|-----------|-----------|
| **File Validation** | File not found | 1 retry (3s delay) | Manual inspection | Admin queue |
| **File Validation** | Invalid file type | 0 retries | Reject + notify submitter | N/A |
| **File Validation** | File >5MB | 0 retries | Reject + suggest split | N/A |
| **AI Extraction** | Timeout (>30s) | 1 retry (exponential) | Manual review queue | Admin after 1x |
| **AI Extraction** | Model error | 0 retries | Log error + manual review | Admin immediately |
| **AI Extraction** | Low confidence (<0.85) | 0 retries | Route to CorrectionQueue | 30-min timeout escalate |
| **D365 Connection** | Network timeout | 3 retries (exponential) | Retry logic table | Alert admin after 3x |
| **D365 Connection** | Auth failure | 1 retry | Refresh token + retry | Escalate if persists |
| **D365 Write** | Duplicate found | 0 retries | Update existing + audit | Alert admin for review |
| **D365 Write** | Validation error | 0 retries | Log error + manual review | Escalate to D365 admin |
| **D365 Write** | Timeout | 5 retries (via scheduled flow) | Exponential backoff | Alert admin after 5x |

### Error Handling in Main Flow (Try-Catch Pattern)

```
Step 1 Error Handler:
  On Error:
    → Log to AuditLog with event_type = "FileValidationError"
    → Update FormSubmission: status = "ValidationFailed"
    → Notify submitter via email
    → End flow

Step 2 Error Handler:
  On Timeout (>30s):
    → Retry 1 time with full backoff
    → If still timeout:
       → Update FormSubmission: status = "ExtractionTimeout"
       → Route to manual review queue
       → Create AuditLog with error details
  
  On Model Error:
    → Update FormSubmission: status = "ExtractionFailed"
    → Log full error stack to AuditLog
    → Create manual review task
    → Notify AI team

Step 3 Error Handler:
  On Validation Failure:
    → Already handled in-flow (confidence threshold routing)
  
  On Transform Error:
    → Log error to AuditLog
    → Create escalation task for data team
    → Update FormSubmission: status = "TransformationFailed"

Step 4 Error Handler:
  On D365 Connection Failure:
    → Retry 3 times with exponential backoff
    → If 3x fail:
       → Update FormSubmission: status = "D365ConnectionFailed"
       → Create D365WriteEvent with status = "Pending"
       → Trigger D365-Retry-Logic scheduled flow
  
  On Duplicate Detection:
    → Update existing account (see Step 4.3b)
    → Log to AuditLog
    → No escalation (normal flow)
  
  On D365 Write Timeout:
    → Create D365WriteEvent with status = "Pending"
    → Log to AuditLog
    → D365-Retry-Logic will retry in 5 min

Step 5 Error Handler:
  On Final Update Failure:
    → Already written to D365 successfully
    → Mark as "Partially Complete"
    → Retry final update via scheduled task
```

---

## Performance Metrics & SLA

### Per-Form Processing Timeline

| Step | Component | Target | Threshold |
|------|-----------|--------|-----------|
| 1 | File read + validation | 2s | <3s |
| 2 | AI extraction | 5–10s | <15s |
| 3 | Validation + transform | 2s | <3s |
| 4 | D365 write | 3s | <5s |
| 5 | Final audit + status | 2s | <3s |
| **Total** | **End-to-end** | **<60s** | **<90s (alert if exceeds)** |

### Throughput & Concurrency

- **Batch Size**: 1 form at a time (sequential, per trigger design)
- **Forms/Hour**: ~60 (1 form/min average)
- **Parallel Subflows**: Up to 5 correction reviews (Manual-Correction-Queue)
- **Scheduled Flow (D365-Retry)**: 10 pending writes per 5-min cycle

### Error Recovery SLA

| Error Type | Target Recovery Time | Owner |
|-----------|----------------------|-------|
| File validation error | <5 min (notify submitter) | Main flow |
| AI extraction timeout | <15 min (retry) | Main flow |
| Low confidence review | <30 min (manual correction) | Correction queue |
| D365 write failure | <5 min per retry (up to 5x) | Retry-Logic flow |
| Manual escalation | <1 hour (admin review) | Admin |

---

## Connector Configuration Requirements

### Required Connectors

| Connector | Purpose | Auth Type | Scope |
|-----------|---------|-----------|-------|
| **SharePoint** | Read files from FormIntake library | OAuth | Site admin |
| **Dataverse** | CRUD operations on all custom tables | OAuth | Organization |
| **AI Builder** | Invoke custom extraction model | Native | Org (embedded) |
| **Dynamics 365** | Create/update accounts | OAuth | D365 organization |
| **Teams** | Post notifications & approval cards | OAuth | Team channel |
| **HTTP** | Direct API calls (D365 queries) | Bearer token | D365 API endpoint |

### Connector Setup Checklist

- [ ] SharePoint connection configured (FormIntake library access)
- [ ] Dataverse connection verified (all 5 custom tables accessible)
- [ ] AI Builder model ID confirmed (VAForm10-3542-Extractor-v1)
- [ ] D365 HTTP connection with OAuth bearer token
- [ ] Teams channel created & bot has post permission
- [ ] Service principal (optional) for unattended runs
- [ ] All connector secrets stored in Key Vault (not in flow)

---

## Testing Checklist

### Unit Tests (Per Flow)

#### Main Flow (VA-Form-Intake-Pipeline)
- [ ] Trigger fires on .pdf file in FormIntake
- [ ] Trigger ignores .doc, .exe, etc. (file type filter)
- [ ] Trigger ignores files >5MB (size validation)
- [ ] Step 1: FormSubmission record created
- [ ] Step 2: AI model invoked with correct payload
- [ ] Step 3a: High-confidence → D365 write initiated
- [ ] Step 3b: Low-confidence → CorrectionRecord created + Manual-Correction-Queue invoked
- [ ] Step 4: D365 account created successfully
- [ ] Step 4: Duplicate detection works (updates existing)
- [ ] Step 5: FormSubmission marked "Written" + locked
- [ ] All AuditLog events created with correct types

#### Correction Queue (Manual-Correction-Queue)
- [ ] Teams card posts to #va-form-extraction-reviews
- [ ] Loop polls for CorrectionRecord.status = "Applied"
- [ ] 30-minute timeout escalates to admin
- [ ] Corrections applied to ExtractionResult
- [ ] D365 retry invoked with corrected payload
- [ ] AuditLog records correction event

#### Retry Logic (D365-Retry-Logic)
- [ ] Scheduled flow runs every 5 minutes
- [ ] Queries for D365WriteEvent with status = "Pending"
- [ ] Exponential backoff: 200ms → 400ms → 800ms → 1.6s → 3.2s
- [ ] Retry 1, 2, 3: Success → moves to "Success" status
- [ ] Retry 5: Failure → moves to "Failed" + escalates
- [ ] Account deleted case: 404 → escalates with reason

### Integration Tests

- [ ] End-to-end: File upload → FormSubmission → Extraction → Validation → D365 write → Status "Written" (60s target)
- [ ] High-confidence path: All fields >0.85 → auto D365 write
- [ ] Low-confidence path: Any field <0.85 → CorrectionQueue → manual approval → retry
- [ ] D365 duplicate path: Match on SSN → Update existing account
- [ ] Error recovery: D365 timeout → Marked "Pending" → Retry-Logic recovers in next cycle
- [ ] Audit trail: All 12 event types logged to AuditLog (immutable)

### Performance Tests

- [ ] Flow completes <60s per form (end-to-end)
- [ ] AI extraction <10s (Michael's target)
- [ ] Scheduled retry flow processes 10 items in <45s
- [ ] Load test: 10 forms uploaded concurrently → all handled sequentially (expected)

### Security Tests

- [ ] FormSubmission marked immutable after "Written" status
- [ ] AuditLog records are read-only (cascade rules prevent deletion)
- [ ] Notifications do not expose PII (SSN, DOB masked in Teams cards)
- [ ] D365 connector uses OAuth (no hardcoded credentials)
- [ ] All secrets in Key Vault (retrieved at runtime)

---

## Deployment Prerequisites

### Phase 1 Requirements (Must Be Complete)

- [ ] D365 connector configured (VA-Form-D365-Prod)
- [ ] SharePoint FormIntake library created & configured
- [ ] Dataverse enabled in organization
- [ ] Solution container created (VA-Form-Extraction)

### Phase 2 Requirements (Before Deploying Flows)

- [ ] Polly's schema: All 5 tables created (FormSubmission, ExtractionResult, CorrectionRecord, AuditLog, D365WriteEvent)
- [ ] Michael's AI model: VAForm10-3542-Extractor published & tested
- [ ] D365 account fields mapped (32–40 fields per Alfie's spec)
- [ ] Teams channel #va-form-extraction-reviews created

### Connection Requirements

- [ ] Service account created (flow@va-form-extraction.onmicrosoft.com)
- [ ] Service account has Dataverse Admin role
- [ ] Service account has D365 System Administrator role
- [ ] OAuth app registration in Entra ID (if using service principal)
- [ ] Key Vault provisioned for secrets storage

---

## Next Steps & Handoff

### Immediate (This Week)

1. **John Shelby**: Create flow artifacts & deployment checklist (QUICK-START-FLOW-DEPLOYMENT.md)
2. **Alfie Solomons**: Validate D365 field mapping payload (FLOW-CONNECTOR-CONFIG.md section)
3. **Tommy Shelby**: Review architecture & approve Phase 2 gate

### Week 2 (May 1–3)

4. **John Shelby**: Deploy flows to Power Automate dev environment
5. **Grace Burgess** (QA): Execute integration test plan
6. **Michael Gray**: Complete AI model training & publish

### Week 3 (May 5+)

7. **John Shelby**: Deploy flows to production environment
8. **Tommy Shelby**: Go-live coordination & monitoring
9. **Lizzie Stark** (UI): Connect Power Apps dashboard to flows

---

## Document References

- **Related**: `specs/02-phase-2-stream-a/TABLE-SPECIFICATIONS.md` (Polly's schema)
- **Related**: `specs/03-phase-2-stream-b/MODEL-TRAINING-STRATEGY.md` (Michael's AI model)
- **Related**: `docs/D365-CONNECTOR-SETUP.md` (Phase 1 connector config)
- **Related**: `FLOW-CONNECTOR-CONFIG.md` (John's detailed connector setup)
- **Related**: `MANUAL-CORRECTION-WORKFLOW.md` (John's human review guide)
- **Related**: `D365-RETRY-STRATEGY.md` (John's exponential backoff details)
- **Related**: `QUICK-START-FLOW-DEPLOYMENT.md` (John's deployment checklist)

---

**Status**: ✅ **FLOW ARCHITECTURE DESIGN COMPLETE**

**Prepared by**: John Shelby, Power Automate Flow Orchestration Lead  
**Date**: 2026-04-25  
**Reviewed by**: (pending Tommy Shelby approval)  
**Ready for**: Phase 2 Stream B-2 deployment
