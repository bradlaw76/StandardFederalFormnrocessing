# Runbook: Flow-01C-Stale-Batch-Monitor

**Feature**: 004-multi-form-pdf-splitter  
**Tasks Covered**: T047–T049 (Phase 6: US4 — Stale Batch Alerting)  
**Estimated Build Time**: 45 minutes  
**Generated**: 2025-07-17  
**Version**: 1.0.0

---

## Prerequisites — Must Complete Before Starting

| Requirement | Verification |
|---|---|
| Phase 2 (Schema) complete | `BatchSubmission` table has `LastProgressTimestamp` and `BatchStatus` columns |
| `Notification-Router` subflow accessible | Verified via Power Automate flows list |
| `Audit-Event-Logger` subflow accessible | Verified via Power Automate flows list |
| Supervisor email address known | Confirmed and documented in T005 reference notes |

---

## Flow Overview

```
TRIGGER: Recurrence — every 1 hour
  │
  ├─ STEP 1: Dataverse List rows — find stale BatchSubmissions
  │           Filter: LastProgressTimestamp < (now - 24h) AND non-terminal status
  │
  └─ STEP 2: Apply to each — for each stale batch:
      ├─ Call Notification-Router (alert to supervisor)
      └─ Call Audit-Event-Logger (ActionType = StaleBatchAlert)
```

---

## Part 1: Create the Flow (T047)

1. Navigate to **Power Automate** → **+ Create** → **Scheduled cloud flow**
2. Set name: `Flow-01C-Stale-Batch-Monitor`
3. Configure recurrence:

| Field | Value |
|---|---|
| **Starting** | Immediately (or next whole hour) |
| **Repeat every** | `1` Hour |
| **Time zone** | Select your organization's primary time zone |
| **At these hours** | Leave blank (runs every hour on the hour) |

4. Click **Create**

---

## Part 2: Initialize Variables

Add the following **Initialize variable** actions before Step 1:

| Variable Name | Type | Initial Value | Purpose |
|---|---|---|---|
| `varStaleThresholdTimestamp` | String | Expression: `addHours(utcNow(), -24)` | The timestamp cutoff — batches with no progress before this time are stale |
| `varAlertCount` | Integer | `0` | Tracks how many stale batches were found in this run (for audit summary) |

---

## Part 3: Step 1 — Query Stale BatchSubmissions (T048)

### Action: Dataverse — List rows on Batch Submissions

1. Add **Dataverse — List rows** action
2. Configure:

| Field | Value / Expression |
|---|---|
| **Table Name** | `Batch Submissions` |
| **Filter rows** | See OData filter below |
| **Select columns** | `cr_batchsubmissionid,cr_batchdisplayid,cr_batchstatus,cr_lastprogresstimestamp,cr_totalformcount,cr_formscompleted,cr_formsfailed,cr_uploadtimestamp,cr_uploadedby,cr_sourcefilename` |
| **Sort by** | `cr_lastprogresstimestamp asc` (oldest first — most urgent at the top) |

### OData Filter Expression

```
cr_lastprogresstimestamp lt @{variables('varStaleThresholdTimestamp')} and cr_batchstatus ne 853400009 and cr_batchstatus ne 853400010 and cr_batchstatus ne 853400002
```

> **Important — Option Set Numeric Values**: The filter uses integer codes for the `cr_batchstatus` option set. You must replace `853400009`, `853400010`, and `853400002` with the **actual numeric values** from your environment:
>
> 1. Navigate to **Dataverse** → **Option Sets** → **Batch Status**
> 2. Note the numeric value for each of these labels:
>    - `Complete` → replace `853400009`
>    - `PartiallyFailed` → replace `853400010`
>    - `ValidationFailed` → replace `853400002`
>
> Alternatively, if using a text-based filter (environment-dependent):
>
> ```
> cr_lastprogresstimestamp lt @{variables('varStaleThresholdTimestamp')} and (cr_batchstatus ne 'Complete' and cr_batchstatus ne 'PartiallyFailed' and cr_batchstatus ne 'ValidationFailed')
> ```

**What this filter does**:
- `cr_lastprogresstimestamp lt {24h ago}` — no activity in 24 hours
- `cr_batchstatus ne 'Complete'` — not already finished
- `cr_batchstatus ne 'PartiallyFailed'` — not already in terminal failure
- `cr_batchstatus ne 'ValidationFailed'` — not rejected at intake (no progress expected)

---

## Part 4: Step 2 — Stale Batch Alert Loop (T049)

### Action: Apply to each — over stale batch rows

1. Add **Apply to each** action
2. Select output from: `body('List_stale_batches')?['value']`  
   *(Replace `List_stale_batches` with your actual action name)*

Inside the loop:

---

### 4.1 — Notify Supervisor via Notification-Router

Add **Call child flow — Notification-Router**:

| Field | Expression / Value |
|---|---|
| **Recipients** | Supervisor email address (from T005 reference notes) |
| **Subject** | `⚠️ Stale Batch Alert: @{items('Apply_to_each')?['cr_batchdisplayid']}` |
| **Message** | See message expression below |
| **Severity** | `Warning` |

**Message expression**:
```
concat(
  '⚠️ STALE BATCH ALERT\n\n',
  'Batch ID: ', items('Apply_to_each')?['cr_batchdisplayid'], '\n',
  'Status: ', items('Apply_to_each')?['cr_batchstatus@OData.Community.Display.V1.FormattedValue'], '\n',
  'Last Activity: ', items('Apply_to_each')?['cr_lastprogresstimestamp'], '\n',
  'Upload Time: ', items('Apply_to_each')?['cr_uploadtimestamp'], '\n',
  'Source File: ', items('Apply_to_each')?['cr_sourcefilename'], '\n',
  'Total Forms: ', string(items('Apply_to_each')?['cr_totalformcount']), '\n',
  'Forms Completed: ', string(items('Apply_to_each')?['cr_formscompleted']), '\n',
  'Forms Failed: ', string(items('Apply_to_each')?['cr_formsfailed']), '\n\n',
  'This batch has had no progress for more than 24 hours. Please investigate the batch record in Power Platform and take appropriate action (retry, escalate, or close).'
)
```

---

### 4.2 — Audit Log: StaleBatchAlert

Add **Call child flow — Audit-Event-Logger**:

| Field | Expression / Value |
|---|---|
| **ActionType** | `StaleBatchAlert` |
| **EntityID** | `@{items('Apply_to_each')?['cr_batchsubmissionid']}` |
| **Details** (Expression) | `concat('Stale batch alert sent for Batch ', items('Apply_to_each')?['cr_batchdisplayid'], '. Last progress: ', items('Apply_to_each')?['cr_lastprogresstimestamp'], '. Status: ', items('Apply_to_each')?['cr_batchstatus@OData.Community.Display.V1.FormattedValue'])` |

---

### 4.3 — Increment Alert Counter

Add **Set variable** → `varAlertCount`:
- Expression: `add(variables('varAlertCount'), 1)`

---

## Part 5: After the Loop — Run Summary (Optional)

Add after the Apply to each loop for operational visibility:

### Action: Compose — Run Summary

Add **Compose** action:
- Input (Expression): `concat('Flow-01C run complete. Stale batches found and alerted: ', string(variables('varAlertCount')), '. Threshold: ', variables('varStaleThresholdTimestamp'))`

This output will appear in the flow run history for quick operational review.

---

## Part 6: Flow Configuration

### Recommended Flow Settings

Navigate to the flow's **Settings**:

| Setting | Value |
|---|---|
| **Run-only users** | Set to "Owner only" (this is a system-level scheduled flow) |
| **Run after** | Leave as default (always run on schedule) |
| **Timeout** | Set to 1 hour (PT1H) — prevents long-running stuck executions |

---

## Part 7: Enable and Verify (End of T049)

### Enable the Flow

1. Navigate to **Power Automate** → **Flows** → `Flow-01C-Stale-Batch-Monitor`
2. Click **Turn on**
3. Click **Run** (manual trigger) to test immediately — verify it runs without error

### Test Procedure (Corresponds to T063)

1. Manually create a `BatchSubmission` record in Dataverse with:
   - `BatchStatus = Splitting`
   - `LastProgressTimestamp = utcNow() - 25 hours`  
     *(Use the Dataverse table editor or a one-time Power Automate flow to set this value)*
2. Manually trigger `Flow-01C-Stale-Batch-Monitor` (Run button in Power Automate)
3. Verify:
   - The manually created batch appears in the flow's List rows results
   - Supervisor receives a stale batch alert notification
   - `AuditLog` contains a `StaleBatchAlert` entry for this batch
4. Optional: wait for the next hourly schedule to confirm the flow runs automatically

### Acceptance Criteria

- Flow runs on schedule (every hour) — verify via flow run history
- Stale batch alert sent within **1 hour** of the 24-hour threshold being exceeded (SC-006)
- `AuditLog.ActionType = StaleBatchAlert` entry created for each stale batch
- Supervisor email received with batch details (BatchDisplayID, status, last activity time)
- Flow does NOT alert on batches with `Complete`, `PartiallyFailed`, or `ValidationFailed` status

---

## Operational Notes

### What "Stale" Means

A batch is stale when:
1. Its `BatchStatus` is a non-terminal value (not Complete, PartiallyFailed, or ValidationFailed)
2. Its `LastProgressTimestamp` is more than 24 hours ago

Common causes of stale batches:
- **Splitting phase stuck**: Muhimbi connector timed out or hit a transient error
- **Feeding phase stuck**: SharePoint move operation failed silently
- **Pipeline backlog**: Forms deposited but existing Flow 1 hasn't processed them
- **Flow disabled**: Flow-01B was turned off, so counters stopped updating

### Supervisor Recovery Actions

When a stale batch alert is received, the supervisor should:

1. Open the `BatchSubmission` record in Dataverse (search by `BatchDisplayID`)
2. Check `BatchStatus` to determine the stuck phase:
   - `Splitting` → check Flow-01 run history; Muhimbi may have failed
   - `Feeding` → check SharePoint `FormIntake/Batches/{BatchDisplayID}/` folder; files may be stuck
   - `SplittingComplete` → check `FormIntake/` root; files may not have been picked up by Flow 1
3. Check `ErrorDetails` field for any error message captured
4. Check `LastSuccessfulSplitIndex` to see how many forms were processed before stalling
5. Take action per the `SplitFailed` recovery runbook if applicable (see T067)

---

**Version**: 1.0.0 | **Generated**: 2025-07-17  
**Status**: Complete runbook — ready for manual implementation  
**Next**: After all three flows are enabled, proceed to [TEST-SCENARIOS.md](TEST-SCENARIOS.md) for Phase 8 end-to-end testing.
