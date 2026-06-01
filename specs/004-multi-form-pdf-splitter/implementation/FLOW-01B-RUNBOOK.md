# Runbook: Flow-01B-Batch-Status-Updater

**Feature**: 004-multi-form-pdf-splitter  
**Tasks Covered**: T039–T046 (Phase 6: US4 — Batch Tracking)  
**Estimated Build Time**: 2–3 hours  
**Generated**: 2025-07-17  
**Version**: 1.0.0

---

## Prerequisites — Must Complete Before Starting

| Requirement | Verification |
|---|---|
| Phase 2 (Schema) complete | `BatchSubmission` table in Dataverse; `FormSubmission` has `BatchID` nullable lookup column |
| Phase 5 (Flow-01 complete + Flow 1 modified) | Split PDFs deposit to `FormIntake/`; Flow 1 populates `FormSubmission.BatchID` |
| At least one test batch has been processed | You have real `FormSubmission` records with `BatchID` populated (needed for T046 testing) |
| `Audit-Event-Logger` and `Notification-Router` subflows accessible | Verified: Power Automate → My flows (or Solution flows) |

---

## Flow Overview

```
TRIGGER: Dataverse — When a row is modified in FormSubmission
          (Column filter: Status, BatchID)
          (OData filter: BatchID IS NOT NULL)
  │
  ├─ STEP 1: Query all sibling FormSubmission rows by BatchID
  │
  ├─ STEP 2: Compute status aggregate counts
  │   ├─ varFormsCompleted = COUNT(Status = 'Complete')
  │   ├─ varFormsInReview = COUNT(Status IN 'ReviewRequired', 'ManualIntake')
  │   ├─ varFormsFailed = COUNT(Status IN 'WriteFailed', 'Failed')
  │   └─ varFormsProcessing = COUNT(Status IN 'Intake', 'Extracting', 'Auto-Approved', 'D365Writing')
  │
  ├─ STEP 3: Update BatchSubmission counters + LastProgressTimestamp
  │           + Audit log: BatchStatusUpdate
  │
  ├─ STEP 4: Terminal state check
  │   └─ IF (FormsCompleted + FormsFailed) = TotalFormCount THEN:
  │       ├─ IF FormsFailed = 0 → BatchStatus = Complete
  │       └─ ELSE → BatchStatus = PartiallyFailed
  │       CompletionTimestamp = NOW()
  │       Notify supervisor + uploader
  │       Audit log: BatchComplete
  │
  └─ STEP 5: Concurrency guard (retry on 409 Conflict)
```

---

## Part 1: Create the Flow (T039)

1. Navigate to **Power Automate** → **+ Create** → **Automated cloud flow**
2. Set name: `Flow-01B-Batch-Status-Updater`
3. Choose trigger: Search for **Dataverse** → select **When a row is modified**
4. Click **Create**
5. ⚠️ **DO NOT ENABLE** the flow until T046 (all steps complete and tested)

---

## Part 2: Configure the Dataverse Trigger (T040)

### Action: Dataverse — When a row is modified

Configure the trigger:

| Field | Value |
|---|---|
| **Table Name** | `Form Submissions` |
| **Scope** | `Organization` (to catch all modifications across the environment) |
| **Column filter** | `cr_batchid,statuscode` (comma-separated, no spaces — only fire when BatchID or Status column changes) |
| **Select columns** | `cr_batchid,statuscode,cr_formindexinbatch` |

### Add OData Row Filter

Expand **Advanced options** on the trigger and set:

| Field | Value |
|---|---|
| **Filter rows** | `_cr_batchid_value ne null` |

> **Why this filter is critical**: Without this filter, every Mode 1 FormSubmission status change (where BatchID is null) would trigger this flow. The `ne null` filter ensures Flow-01B only fires for Mode 2 batch-member forms.

---

## Part 3: Initialize Variables

Add **Initialize variable** actions (before Step 1):

| Variable Name | Type | Initial Value |
|---|---|---|
| `varBatchIDFromTrigger` | String | Expression: `triggerOutputs()?['body/_cr_batchid_value']` |
| `varTotalFormCount` | Integer | `0` (will be populated after querying BatchSubmission) |
| `varFormsCompleted` | Integer | `0` |
| `varFormsInReview` | Integer | `0` |
| `varFormsFailed` | Integer | `0` |
| `varFormsProcessing` | Integer | `0` |
| `varRetryCount` | Integer | `0` |
| `varUpdateSucceeded` | Boolean | `false` |

---

## Part 4: Step 1 — Query All Sibling Forms (T041)

### Action: Dataverse — List rows on Form Submissions

| Field | Value |
|---|---|
| **Table Name** | `Form Submissions` |
| **Filter rows** | `_cr_batchid_value eq @{variables('varBatchIDFromTrigger')}` |
| **Select columns** | `cr_formsubmissionid,statuscode` |
| **Row count** | Leave blank (retrieve all sibling forms) |

> **Important**: The OData filter uses the internal name `_cr_batchid_value` (the lookup value column) — not `cr_batchid` (the relationship column). In Dataverse OData queries, lookup values are referenced with the `_value` suffix.

After the List rows action:
- Add **Set variable** → `varTotalFormCount`
- Expression: `length(body('List_sibling_forms')?['value'])`  
  *(Replace `List_sibling_forms` with your actual action name)*

---

## Part 5: Step 2 — Compute Status Aggregates (T042)

Add four **Set variable** actions sequentially:

### 5.1 — Count Completed Forms

Add **Set variable** → `varFormsCompleted`:

```
length(filter(body('List_sibling_forms')?['value'], equals(item()?['statuscode@OData.Community.Display.V1.FormattedValue'], 'Complete')))
```

> **Status label alignment**: The value `'Complete'` must exactly match your FormSubmission `statuscode` option set label. Check your existing `FormSubmission` option set values in Dataverse and substitute the correct label if different.

---

### 5.2 — Count Forms In Review

Add **Set variable** → `varFormsInReview`:

```
length(filter(body('List_sibling_forms')?['value'], or(equals(item()?['statuscode@OData.Community.Display.V1.FormattedValue'], 'ReviewRequired'), equals(item()?['statuscode@OData.Community.Display.V1.FormattedValue'], 'ManualIntake'))))
```

---

### 5.3 — Count Failed Forms

Add **Set variable** → `varFormsFailed`:

```
length(filter(body('List_sibling_forms')?['value'], or(equals(item()?['statuscode@OData.Community.Display.V1.FormattedValue'], 'WriteFailed'), equals(item()?['statuscode@OData.Community.Display.V1.FormattedValue'], 'Failed'))))
```

---

### 5.4 — Count Forms Processing

Add **Set variable** → `varFormsProcessing`:

```
length(filter(body('List_sibling_forms')?['value'], or(or(equals(item()?['statuscode@OData.Community.Display.V1.FormattedValue'], 'Intake'), equals(item()?['statuscode@OData.Community.Display.V1.FormattedValue'], 'Extracting')), or(equals(item()?['statuscode@OData.Community.Display.V1.FormattedValue'], 'Auto-Approved'), equals(item()?['statuscode@OData.Community.Display.V1.FormattedValue'], 'D365Writing')))))
```

---

## Part 6: Step 3 — Update BatchSubmission Counters (T043)

### Concurrency-Safe Update Pattern (T045)

Wrap the update in a **Do Until** loop to handle Dataverse 409 Conflict errors (optimistic concurrency):

#### 6.1 — Do Until: Update Succeeded or Max Retries Reached

Add **Do Until** action:
- **Condition**: `or(variables('varUpdateSucceeded'), greaterOrEquals(variables('varRetryCount'), 3))`
- Expression: `or(equals(variables('varUpdateSucceeded'), true), greaterOrEquals(variables('varRetryCount'), 3))`

Inside the Do Until loop:

#### 6.2 — Dataverse — Update a row on Batch Submissions

| Field | Expression |
|---|---|
| **Row ID** | `@{variables('varBatchIDFromTrigger')}` |
| **Forms Completed** | `@{variables('varFormsCompleted')}` |
| **Forms In Review** | `@{variables('varFormsInReview')}` |
| **Forms Failed** | `@{variables('varFormsFailed')}` |
| **Forms Processing** | `@{variables('varFormsProcessing')}` |
| **Completion Percentage** | `@{mul(div(float(variables('varFormsCompleted')), float(variables('varTotalFormCount'))), 100)}` |
| **Last Progress Timestamp** | `@{utcNow()}` |

#### 6.3 — Set varUpdateSucceeded = true (on success run-after)

Add **Set variable** → `varUpdateSucceeded` = `true`
- Configure **Run after** on this action: only runs if the `Update a row` action **succeeded**

#### 6.4 — Handle 409 Conflict (on failure run-after)

Add a **Condition** (or scope with run-after set to `has failed`):
- Add **Delay**: 2 seconds
- Add **Set variable** → `varRetryCount` = Expression: `add(variables('varRetryCount'), 1)`

After the Do Until loop exits:

#### 6.5 — Audit Log: BatchStatusUpdate

Add **Call child flow — Audit-Event-Logger**:
- ActionType: `BatchStatusUpdate`
- EntityID: `@{variables('varBatchIDFromTrigger')}`
- Details (Expression): `concat('Counters updated: Completed=', string(variables('varFormsCompleted')), ', InReview=', string(variables('varFormsInReview')), ', Failed=', string(variables('varFormsFailed')), ', Processing=', string(variables('varFormsProcessing')), ', Total=', string(variables('varTotalFormCount')))`

---

## Part 7: Step 4 — Terminal State Detection (T044)

### Action: Condition — Are All Forms Resolved?

1. Add **Condition** action
2. **Left side** (Expression): `add(variables('varFormsCompleted'), variables('varFormsFailed'))`
3. **Operator**: `is equal to`
4. **Right side** (Expression): `variables('varTotalFormCount')`

**True branch** (all forms are in a terminal state):

#### 7.1 — Nested Condition: All Complete or Some Failed?

Add nested **Condition**:
- **Left side** (Expression): `variables('varFormsFailed')`
- **Operator**: `is equal to`
- **Right side**: `0`

**True branch (all complete → BatchStatus = Complete)**:

Add **Dataverse — Update a row** on Batch Submissions:
- Row ID: `@{variables('varBatchIDFromTrigger')}`
- Batch Status: `Complete`
- Completion Timestamp: `@{utcNow()}`
- Last Progress Timestamp: `@{utcNow()}`

Add **Call child flow — Audit-Event-Logger**:
- ActionType: `BatchComplete`
- EntityID: `@{variables('varBatchIDFromTrigger')}`
- Details: `All forms completed successfully. Batch is Complete.`

Add **Call child flow — Notification-Router**:
- Recipients: supervisor email AND uploader
- Subject: `✅ Batch Processing Complete`
- Message (Expression): `concat('Batch ', variables('varBatchIDFromTrigger'), ' has completed successfully. All ', string(variables('varFormsCompleted')), ' forms have been processed and written to D365.')`
- Severity: `Info`

**False branch (some failed → BatchStatus = PartiallyFailed)**:

Add **Dataverse — Update a row** on Batch Submissions:
- Row ID: `@{variables('varBatchIDFromTrigger')}`
- Batch Status: `PartiallyFailed`
- Completion Timestamp: `@{utcNow()}`
- Last Progress Timestamp: `@{utcNow()}`

Add **Call child flow — Audit-Event-Logger**:
- ActionType: `BatchComplete`
- EntityID: `@{variables('varBatchIDFromTrigger')}`
- Details (Expression): `concat(string(variables('varFormsFailed')), ' of ', string(variables('varTotalFormCount')), ' forms failed. Batch is PartiallyFailed.')`

Add **Call child flow — Notification-Router**:
- Recipients: supervisor email AND uploader
- Subject: `⚠️ Batch Partially Failed — Action Required`
- Message (Expression): `concat('Batch processing complete with ', string(variables('varFormsFailed')), ' failed form(s) out of ', string(variables('varTotalFormCount')), ' total. ', string(variables('varFormsCompleted')), ' forms succeeded. Please review failed forms in the Batch Status view.')`
- Severity: `Warning`

**False branch** (not all forms resolved — do nothing, flow ends normally):
- Empty

---

## Part 8: Flow Settings — Concurrency Control (T045)

### Configure Flow Settings

1. Click the `...` menu on the flow → **Settings**
2. Set:

| Setting | Value |
|---|---|
| **Concurrency control** | On |
| **Degree of parallelism** | `1` |

> **Why concurrency = 1**: If two child forms from the same batch complete simultaneously, both trigger this flow. With concurrency = 1, they queue and execute sequentially, preventing both from reading the old counter value before the first update commits. The Do Until retry (Part 6) handles the rare case where Dataverse still returns a conflict.

---

## Part 9: Enable and Test (T046)

### Enable the Flow

1. Navigate to **Power Automate** → **Flows** → `Flow-01B-Batch-Status-Updater`
2. Click **Turn on**

### Test Procedure

1. Process a test batch of 3 forms through Flow-01 (upload a 6-page PDF to `Batches/Incoming/`)
2. Wait for the split and feed to complete (`BatchStatus = SplittingComplete`)
3. In Dataverse, view the 3 `FormSubmission` records for this batch — confirm each has `BatchID` set
4. As each form's `Status` changes (Intake → Extracting → Complete):
   - Open the parent `BatchSubmission` record in Dataverse
   - Verify `FormsCompleted` increments within 30 seconds (SC-003)
   - Verify `CompletionPercentage` updates correctly
   - Verify `LastProgressTimestamp` updates
5. When all 3 forms reach `Complete`:
   - Verify `BatchSubmission.BatchStatus = Complete`
   - Verify `CompletionTimestamp` is set
   - Verify completion notification was received

### Acceptance Criteria (SC-003)

- Status updates visible within **30 seconds** of a child form state change
- `FormsCompleted` counter increments on each `Complete` transition
- `CompletionPercentage` = `(FormsCompleted / TotalFormCount) × 100`
- Terminal state (`Complete` or `PartiallyFailed`) detected correctly

---

## Troubleshooting Guide

| Symptom | Likely Cause | Resolution |
|---|---|---|
| Flow fires for Mode 1 forms | OData filter not set correctly | Verify `_cr_batchid_value ne null` in trigger Filter rows |
| Flow fires twice per status change | Concurrency control not enabled | Enable concurrency limit = 1 in flow settings |
| `varFormsCompleted` stays at 0 | Status label mismatch | Check FormSubmission `statuscode` labels; update filter expression to match exact labels |
| 409 Conflict error in run history | Concurrent batch updates (expected) | Verify Do Until retry loop is working; check retry count in run history |
| BatchStatus never reaches `Complete` | `varTotalFormCount` = 0 | Verify the List rows action in Step 1 returns all sibling forms; check the OData filter |
| Notification not received | Notification-Router subflow error | Check the Notification-Router run history separately |

---

**Version**: 1.0.0 | **Generated**: 2025-07-17  
**Status**: Complete runbook — ready for manual implementation  
**Next**: After enabling Flow-01B, proceed to [FLOW-01C-RUNBOOK.md](FLOW-01C-RUNBOOK.md) for stale batch monitoring.
