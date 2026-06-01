# VA Form Extraction — Dataverse Table Provisioning Runbook

**Document**: PROVISIONING-RUNBOOK.md  
**Author**: Polly Gray, Dataverse Schema Design Lead  
**Date**: April 26, 2026  
**Phase Gate**: 2 → 3 (APPROVED by Tommy Shelby)  
**Status**: ✅ Ready for Execution  

---

## 1. Pre-Flight Checklist

Complete all items before beginning table provisioning.

- [ ] **Power Platform Environment**: "Département of Veteran Affairs - OTH"
  - Environment ID: `b29e4071-1a40-4d24-89d5-41320d7c1371`
  - Region: GCC (Government Community Cloud)
- [ ] **Solution**: "VA-Form-Extraction"
  - Publisher prefix: `vafe_`
  - Publisher: `VAFormExtraction_Publisher`
- [ ] **Dataverse enabled**: ✅ (confirmed Phase 1 — Issue #8)
- [ ] **Role required**: System Administrator or System Customizer
- [ ] **Browser**: Sign in to [make.powerapps.com](https://make.powerapps.com) with your VA credentials
- [ ] **Confirm environment selector** (top-right) shows "Département of Veteran Affairs - OTH"
- [ ] **Navigate to**: Solutions → VA-Form-Extraction → confirm solution opens

> ⚠️ **IMPORTANT**: Provision tables in the exact order listed below. CorrectionRecord depends on ExtractionResult existing first. Do not skip ahead.

---

## 2. Table Provisioning

### Navigation Path (applies to all tables)

> **make.powerapps.com → Solutions → VA-Form-Extraction → Tables → + New Table → Table (Table)**

---

### Table 1: FormSubmission

**Purpose**: Tracks each VA form upload through the entire extraction pipeline (parent of all other tables).

**Create the table:**

1. Navigate: Solutions → VA-Form-Extraction → Tables → **+ New Table**
2. Set:
   - **Display Name**: `Form Submission`
   - **Plural Display Name**: `Form Submissions`
   - **Schema Name**: `vafe_FormSubmission`
   - **Ownership**: Organization
   - **Primary Column Display Name**: `Form Submission ID`
   - **Primary Column Schema Name**: `vafe_FormSubmissionID`
3. Click **Save**

**Add Fields** (after table is created, click **+ New Column** for each):

| # | Display Name | Schema Name | Data Type | Required | Notes |
|---|---|---|---|---|---|
| 1 | Form Submission ID | vafe_FormSubmissionID | Auto Number | System (primary) | Format: `VAFE-{SEQNUM:6}` — set in Auto Number settings |
| 2 | Upload Date | vafe_UploadDate | Date and Time | Required | Date Only: No |
| 3 | Source File | vafe_SourceFile | Text | Required | Max length: 500 |
| 4 | Source File URL | vafe_SourceFileURL | URL | Optional | |
| 5 | Status | vafe_Status | Choice | Required | New global choice — see options below |
| 6 | Processing Notes | vafe_ProcessingNotes | Multiline Text | Optional | Max length: 2000 |
| 7 | Processed By | vafe_ProcessedBy | Text | Optional | Max length: 100 |
| 8 | Processing Start | vafe_ProcessingStart | Date and Time | Optional | |
| 9 | Processing End | vafe_ProcessingEnd | Date and Time | Optional | |
| 10 | Error Details | vafe_ErrorDetails | Multiline Text | Optional | Max length: 2000 |

**Choice field — vafe_Status options** (create as new local choice):

| Label | Value |
|---|---|
| Intake | 100000000 |
| Extracting | 100000001 |
| Extracted | 100000002 |
| Correcting | 100000003 |
| Corrected | 100000004 |
| Writing | 100000005 |
| Written | 100000006 |

**Auto Number field — vafe_FormSubmissionID:**
- After creating the primary column, go to the field → Advanced Options
- Set **Auto number type**: String prefixed number
- Set **Prefix**: `VAFE-`
- Set **Minimum digits**: `6`

**Business Rules** (navigate to: Table → Business Rules → + New Business Rule):

**Rule 1: Lock Written Status**
- Display Name: `Lock Written Status`
- Scope: Entity
- Condition: `vafe_Status` equals `Written (100000006)`
- Action: Set all editable fields to **Locked** (Business Required = false, Lock = true for each)
- Save and Activate

**Rule 2: Auto-Set Processing Start**
- Display Name: `Auto-Set Processing Start`
- Scope: Entity
- Condition: `vafe_Status` equals `Extracting (100000001)`
- Action: Set Field `vafe_ProcessingStart` → Formula: `Now()`
- Save and Activate

**Rule 3: Auto-Set Processing End**
- Display Name: `Auto-Set Processing End`
- Scope: Entity
- Condition: `vafe_Status` equals `Written (100000006)`
- Action: Set Field `vafe_ProcessingEnd` → Formula: `Now()`
- Save and Activate

✅ **Table 1 complete. Proceed to Table 2.**

---

### Table 2: ExtractionResult

**Purpose**: Stores AI extraction output with confidence scores. Child of FormSubmission.

**Create the table:**

1. Navigate: Solutions → VA-Form-Extraction → Tables → **+ New Table**
2. Set:
   - **Display Name**: `Extraction Result`
   - **Plural Display Name**: `Extraction Results`
   - **Schema Name**: `vafe_ExtractionResult`
   - **Ownership**: Organization
   - **Primary Column Display Name**: `Result ID`
   - **Primary Column Schema Name**: `vafe_ResultID`
3. Click **Save**

**Add Fields:**

| # | Display Name | Schema Name | Data Type | Required | Notes |
|---|---|---|---|---|---|
| 1 | Result ID | vafe_ResultID | Auto Number | System (primary) | Format: `RES-{SEQNUM:6}` |
| 2 | Form Submission | vafe_FormSubmissionID | Lookup | Required | Target table: `vafe_FormSubmission` |
| 3 | Extracted Data | vafe_ExtractedData | Multiline Text | Required | Max length: 5000 (JSON) |
| 4 | Field Confidence Scores | vafe_FieldConfidenceScores | Multiline Text | Optional | Max length: 5000 (JSON) |
| 5 | Overall Confidence | vafe_OverallConfidence | Decimal Number | Optional | Min: 0.00, Max: 1.00 |
| 6 | Extraction Status | vafe_ExtractionStatus | Choice | Required | New local choice — see options below |
| 7 | Model Version | vafe_ModelVersion | Text | Optional | Max length: 50 |
| 8 | Extraction Timestamp | vafe_ExtractionTimestamp | Date and Time | Optional | |
| 9 | Error Message | vafe_ErrorMessage | Multiline Text | Optional | Max length: 2000 |

**Auto Number — vafe_ResultID:**
- Prefix: `RES-`, Minimum digits: `6`

**Choice field — vafe_ExtractionStatus options:**

| Label | Value |
|---|---|
| Pending | 100000000 |
| Success | 100000001 |
| Partial Success | 100000002 |
| Failed | 100000003 |

**Lookup field — vafe_FormSubmissionID:**
- Data Type: Lookup
- Related Table: `Form Submission (vafe_FormSubmission)`
- Relationship Name: `vafe_formsubmission_extractionresult`

**Business Rules:**

**Rule 1: Lock After Success**
- Display Name: `Lock After Success`
- Condition: `vafe_ExtractionStatus` equals `Success (100000001)` OR `Partial Success (100000002)`
- Action: Set Field `vafe_ExtractedData` → Locked
- Save and Activate

**Rule 2: Require Confidence On Success**
- Display Name: `Require Confidence On Success`
- Condition: `vafe_ExtractionStatus` equals `Success (100000001)`
- Action: Set Business Required = **true** for `vafe_OverallConfidence`
- Save and Activate

✅ **Table 2 complete. Proceed to Table 3.**

---

### Table 3: AuditLog

**Purpose**: Immutable compliance audit trail. Every pipeline event is logged here. HIPAA-required.

**Create the table:**

1. Navigate: Solutions → VA-Form-Extraction → Tables → **+ New Table**
2. Set:
   - **Display Name**: `Audit Log`
   - **Plural Display Name**: `Audit Logs`
   - **Schema Name**: `vafe_AuditLog`
   - **Ownership**: Organization
   - **Primary Column Display Name**: `Log ID`
   - **Primary Column Schema Name**: `vafe_LogID`
3. Click **Save**

**Add Fields:**

| # | Display Name | Schema Name | Data Type | Required | Notes |
|---|---|---|---|---|---|
| 1 | Log ID | vafe_LogID | Auto Number | System (primary) | Format: `LOG-{SEQNUM:8}` |
| 2 | Form Submission | vafe_FormSubmissionID | Lookup | Required | Target table: `vafe_FormSubmission` |
| 3 | Action | vafe_Action | Choice | Required | New local choice — see options below |
| 4 | Timestamp | vafe_Timestamp | Date and Time | Required | |
| 5 | User ID | vafe_UserID | Text | Optional | Max length: 100 |
| 6 | IP Address | vafe_IPAddress | Text | Optional | Max length: 45 (supports IPv6) |
| 7 | Details | vafe_Details | Multiline Text | Optional | Max length: 2000 |
| 8 | Error Code | vafe_ErrorCode | Text | Optional | Max length: 50 |
| 9 | Severity | vafe_Severity | Choice | Optional | New local choice — see options below |
| 10 | Correlation ID | vafe_CorrelationID | Text | Optional | Max length: 100 (Power Automate flow run ID) |

**Auto Number — vafe_LogID:**
- Prefix: `LOG-`, Minimum digits: `8`

**Choice field — vafe_Action options:**

| Label | Value |
|---|---|
| Form Intake | 100000000 |
| Extraction Started | 100000001 |
| Extraction Complete | 100000002 |
| Extraction Failed | 100000003 |
| Validation Started | 100000004 |
| Correction Required | 100000005 |
| Correction Submitted | 100000006 |
| D365 Write Attempt | 100000007 |
| D365 Write Success | 100000008 |
| D365 Write Failed | 100000009 |
| Status Updated | 100000010 |
| Error Occurred | 100000011 |

**Choice field — vafe_Severity options:**

| Label | Value |
|---|---|
| Info | 100000000 |
| Warning | 100000001 |
| Error | 100000002 |
| Critical | 100000003 |

**Business Rules:**

**Rule 1: Immutable Record**
- Display Name: `Immutable Record`
- Scope: Entity
- Condition: `Modified On` is not null (i.e., record exists = update scenario)
  - Alternative implementation: Condition set on form scope — trigger when form is opened for existing record (use `Form Type` = Update)
- Action: Set ALL fields to **Locked** (vafe_FormSubmissionID, vafe_Action, vafe_Timestamp, vafe_UserID, vafe_IPAddress, vafe_Details, vafe_ErrorCode, vafe_Severity, vafe_CorrelationID)
- Save and Activate

> 💡 **Note**: Business rules run on form load. For server-side enforcement, additionally configure a **Power Automate cloud flow** that blocks update operations on this table via a Dataverse trigger ("When a row is modified" → immediately restore original values). Full immutability at the API level requires a plug-in or flow-based guard.

✅ **Table 3 complete. Proceed to Table 4.**

---

### Table 4: D365WriteEvent

**Purpose**: Tracks each attempt to write data to Dynamics 365 with retry state and HTTP response codes.

**Create the table:**

1. Navigate: Solutions → VA-Form-Extraction → Tables → **+ New Table**
2. Set:
   - **Display Name**: `D365 Write Event`
   - **Plural Display Name**: `D365 Write Events`
   - **Schema Name**: `vafe_D365WriteEvent`
   - **Ownership**: Organization
   - **Primary Column Display Name**: `Event ID`
   - **Primary Column Schema Name**: `vafe_EventID`
3. Click **Save**

**Add Fields:**

| # | Display Name | Schema Name | Data Type | Required | Notes |
|---|---|---|---|---|---|
| 1 | Event ID | vafe_EventID | Auto Number | System (primary) | Format: `D365-{SEQNUM:6}` |
| 2 | Form Submission | vafe_FormSubmissionID | Lookup | Required | Target table: `vafe_FormSubmission` |
| 3 | D365 Status | vafe_D365Status | Choice | Required | New local choice — see options below |
| 4 | Timestamp Written | vafe_TimestampWritten | Date and Time | Optional | |
| 5 | D365 Record ID | vafe_D365RecordID | Text | Optional | Max length: 200 |
| 6 | Retry Count | vafe_RetryCount | Whole Number | Optional | Default value: `0` |
| 7 | Last Retry | vafe_LastRetry | Date and Time | Optional | |
| 8 | Error Details | vafe_ErrorDetails | Multiline Text | Optional | Max length: 2000 |
| 9 | Payload Sent | vafe_PayloadSent | Multiline Text | Optional | Max length: 5000 (JSON) |
| 10 | HTTP Status Code | vafe_HTTPStatusCode | Whole Number | Optional | |

**Auto Number — vafe_EventID:**
- Prefix: `D365-`, Minimum digits: `6`

**Choice field — vafe_D365Status options:**

| Label | Value |
|---|---|
| Pending | 100000000 |
| Success | 100000001 |
| Failed | 100000002 |
| Retrying | 100000003 |

**Set Default Value for Retry Count:**
- When adding `vafe_RetryCount` field → Advanced Options → Default value: `0`

**Business Rules:**

**Rule 1: Max Retry Limit**
- Display Name: `Max Retry Limit`
- Condition: `vafe_RetryCount` is greater than or equal to `5`
- Action 1: Set Field `vafe_D365Status` = `Failed (100000002)`
- Action 2: Set Field `vafe_RetryCount` → Locked
- Save and Activate

**Rule 2: Auto-Timestamp Success**
- Display Name: `Auto-Timestamp Success`
- Condition: `vafe_D365Status` equals `Success (100000001)`
- Action: Set Field `vafe_TimestampWritten` → Formula: `Now()`
- Save and Activate

✅ **Table 4 complete. Proceed to Table 5.**

---

### Table 5: CorrectionRecord

**Purpose**: Tracks manual corrections made to AI-extracted field values. Child of ExtractionResult.  
⚠️ **Requires Table 2 (ExtractionResult) to exist before creating the lookup.**

**Create the table:**

1. Navigate: Solutions → VA-Form-Extraction → Tables → **+ New Table**
2. Set:
   - **Display Name**: `Correction Record`
   - **Plural Display Name**: `Correction Records`
   - **Schema Name**: `vafe_CorrectionRecord`
   - **Ownership**: Organization
   - **Primary Column Display Name**: `Correction ID`
   - **Primary Column Schema Name**: `vafe_CorrectionID`
3. Click **Save**

**Add Fields:**

| # | Display Name | Schema Name | Data Type | Required | Notes |
|---|---|---|---|---|---|
| 1 | Correction ID | vafe_CorrectionID | Auto Number | System (primary) | Format: `COR-{SEQNUM:6}` |
| 2 | Extraction Result | vafe_ExtractionResultID | Lookup | Required | Target table: `vafe_ExtractionResult` |
| 3 | Field Name | vafe_FieldName | Text | Required | Max length: 100 |
| 4 | Original Value | vafe_OriginalValue | Multiline Text | Optional | Max length: 1000 |
| 5 | Corrected Value | vafe_CorrectedValue | Multiline Text | Optional | Max length: 1000 |
| 6 | Correction Date | vafe_CorrectionDate | Date and Time | Optional | |
| 7 | Reviewed By | vafe_ReviewedBy | Text | Optional | Max length: 100 |
| 8 | Correction Status | vafe_CorrectionStatus | Choice | Required | New local choice — see options below |
| 9 | Correction Notes | vafe_CorrectionNotes | Multiline Text | Optional | Max length: 1000 |
| 10 | Field Confidence | vafe_FieldConfidence | Decimal Number | Optional | Min: 0.00, Max: 1.00 |
| 11 | Review SLA | vafe_ReviewSLA | Date and Time | Optional | Target: 30 min from creation |

**Auto Number — vafe_CorrectionID:**
- Prefix: `COR-`, Minimum digits: `6`

**Lookup field — vafe_ExtractionResultID:**
- Data Type: Lookup
- Related Table: `Extraction Result (vafe_ExtractionResult)`
- Relationship Name: `vafe_extractionresult_correctionrecord`

**Choice field — vafe_CorrectionStatus options:**

| Label | Value |
|---|---|
| Pending | 100000000 |
| Corrected | 100000001 |
| Skipped | 100000002 |

**Business Rules:**

**Rule 1: Auto-Set Review SLA**
- Display Name: `Auto-Set Review SLA`
- Scope: Entity
- Condition: `vafe_ReviewSLA` is null (i.e., new record)
- Action: Set Field `vafe_ReviewSLA` → Formula: `DateAdd(Now(), 30, "minutes")`
  > 💡 Note: If the formula builder doesn't support DateAdd directly, set this via a Power Automate flow triggered on "When a row is added" → calculate `utcNow() + 30 minutes` → update `vafe_ReviewSLA`. Document the flow in the flow runbook.
- Save and Activate

**Rule 2: Lock After Correction**
- Display Name: `Lock After Correction`
- Condition: `vafe_CorrectionStatus` equals `Corrected (100000001)`
- Action 1: Set Field `vafe_OriginalValue` → Locked
- Action 2: Set Field `vafe_CorrectedValue` → Locked
- Save and Activate

✅ **Table 5 complete. All tables provisioned. Proceed to Section 3.**

---

## 3. Lookup Relationships (Cascade Delete)

Configure parent-child relationships after all 5 tables exist. For each relationship below:

> **Navigation**: Solutions → VA-Form-Extraction → Tables → **[Parent Table]** → Relationships → + New Relationship → **One-to-Many**

---

### Relationship 1: FormSubmission → ExtractionResult

- **Parent Table**: Form Submission (`vafe_FormSubmission`)
- **Child Table**: Extraction Result (`vafe_ExtractionResult`)
- **Relationship Name**: `vafe_formsubmission_extractionresult`
- **Delete Behavior**: **Cascade** (deleting a FormSubmission deletes all linked ExtractionResults)

Steps:
1. Open `Form Submission` table → Relationships tab
2. Click **+ New Relationship** → One-to-Many
3. Select **Related (child) table**: `Extraction Result`
4. Expand **Advanced Options** → Set **Delete**: `Cascade`
5. Save

---

### Relationship 2: FormSubmission → AuditLog

- **Parent Table**: Form Submission (`vafe_FormSubmission`)
- **Child Table**: Audit Log (`vafe_AuditLog`)
- **Relationship Name**: `vafe_formsubmission_auditlog`
- **Delete Behavior**: **Cascade**

Steps:
1. Open `Form Submission` table → Relationships tab
2. Click **+ New Relationship** → One-to-Many
3. Select **Related (child) table**: `Audit Log`
4. Expand **Advanced Options** → Set **Delete**: `Cascade`
5. Save

---

### Relationship 3: FormSubmission → D365WriteEvent

- **Parent Table**: Form Submission (`vafe_FormSubmission`)
- **Child Table**: D365 Write Event (`vafe_D365WriteEvent`)
- **Relationship Name**: `vafe_formsubmission_d365writeevent`
- **Delete Behavior**: **Cascade**

Steps:
1. Open `Form Submission` table → Relationships tab
2. Click **+ New Relationship** → One-to-Many
3. Select **Related (child) table**: `D365 Write Event`
4. Expand **Advanced Options** → Set **Delete**: `Cascade`
5. Save

---

### Relationship 4: ExtractionResult → CorrectionRecord

- **Parent Table**: Extraction Result (`vafe_ExtractionResult`)
- **Child Table**: Correction Record (`vafe_CorrectionRecord`)
- **Relationship Name**: `vafe_extractionresult_correctionrecord`
- **Delete Behavior**: **Cascade**

Steps:
1. Open `Extraction Result` table → Relationships tab
2. Click **+ New Relationship** → One-to-Many
3. Select **Related (child) table**: `Correction Record`
4. Expand **Advanced Options** → Set **Delete**: `Cascade`
5. Save

---

## 4. Security Roles

Create two custom security roles in the environment.

> **Navigation**: Power Platform Admin Center → Environments → Département of Veteran Affairs - OTH → Settings → Users + Permissions → **Security Roles** → + New Role

---

### Role 1: VA Form Contributor

| Table | Create | Read | Write | Delete | Append | Append To |
|---|---|---|---|---|---|---|
| Form Submission | ✅ User | ✅ User | ✅ User | ❌ | ✅ | ✅ |
| Extraction Result | ✅ User | ✅ User | ✅ User | ❌ | ✅ | ✅ |
| Correction Record | ✅ User | ✅ User | ✅ User | ❌ | ✅ | ✅ |
| Audit Log | ❌ | ✅ User | ❌ | ❌ | ❌ | ✅ |
| D365 Write Event | ❌ | ✅ User | ❌ | ❌ | ❌ | ✅ |

---

### Role 2: VA Form Data Analyst

| Table | Create | Read | Write | Delete |
|---|---|---|---|---|
| Form Submission | ❌ | ✅ Organization | ❌ | ❌ |
| Extraction Result | ❌ | ✅ Organization | ❌ | ❌ |
| Correction Record | ❌ | ✅ Organization | ❌ | ❌ |
| Audit Log | ❌ | ✅ Organization | ❌ | ❌ |
| D365 Write Event | ❌ | ✅ Organization | ❌ | ❌ |

---

## 5. Verification Checklist

After all provisioning steps, run through this checklist to confirm readiness.

### Tables

- [ ] `vafe_FormSubmission` visible in VA-Form-Extraction solution
- [ ] `vafe_ExtractionResult` visible in VA-Form-Extraction solution
- [ ] `vafe_AuditLog` visible in VA-Form-Extraction solution
- [ ] `vafe_D365WriteEvent` visible in VA-Form-Extraction solution
- [ ] `vafe_CorrectionRecord` visible in VA-Form-Extraction solution

### Fields

- [ ] All 10 FormSubmission fields present and correctly typed
- [ ] All 9 ExtractionResult fields present and correctly typed
- [ ] All 10 AuditLog fields present and correctly typed
- [ ] All 10 D365WriteEvent fields present and correctly typed
- [ ] All 11 CorrectionRecord fields present and correctly typed
- [ ] All Auto Number fields display correct prefix format (VAFE-, RES-, LOG-, D365-, COR-)
- [ ] All Choice fields have correct option values

### Business Rules

- [ ] `Lock Written Status` — Active (not draft)
- [ ] `Auto-Set Processing Start` — Active
- [ ] `Auto-Set Processing End` — Active
- [ ] `Lock After Success` — Active
- [ ] `Require Confidence On Success` — Active
- [ ] `Immutable Record` — Active
- [ ] `Max Retry Limit` — Active
- [ ] `Auto-Timestamp Success` — Active
- [ ] `Auto-Set Review SLA` — Active (or replaced by Power Automate flow)
- [ ] `Lock After Correction` — Active

### Relationships

- [ ] FormSubmission → ExtractionResult (1:N, cascade delete configured)
- [ ] FormSubmission → AuditLog (1:N, cascade delete configured)
- [ ] FormSubmission → D365WriteEvent (1:N, cascade delete configured)
- [ ] ExtractionResult → CorrectionRecord (1:N, cascade delete configured)

### Cascade Delete Test

1. Create a test `Form Submission` record in the app
2. Create a child `Extraction Result` record linked to it
3. Create a child `Correction Record` linked to the Extraction Result
4. Delete the parent `Form Submission` record
5. Confirm: ExtractionResult deleted ✅, CorrectionRecord deleted ✅, AuditLog entries deleted ✅, D365WriteEvent entries deleted ✅

### Security Roles

- [ ] `VA Form Contributor` role created
- [ ] `VA Form Data Analyst` role created
- [ ] Test user assigned `VA Form Contributor` — confirm can create/read FormSubmission
- [ ] Test user assigned `VA Form Data Analyst` — confirm read-only access

---

## Appendix: Table Dependency Map

```
vafe_FormSubmission (parent — provision FIRST)
├── vafe_ExtractionResult   (child — provision 2nd; also parent of CorrectionRecord)
│   └── vafe_CorrectionRecord  (grandchild — provision LAST)
├── vafe_AuditLog           (child — provision 3rd)
└── vafe_D365WriteEvent     (child — provision 4th)
```

---

*Runbook produced by Polly Gray, Dataverse Schema Design Lead*  
*VA Form Extraction Project — Phase 2, Stream A*  
*Phase Gate 2→3 Approved: April 26, 2026*
