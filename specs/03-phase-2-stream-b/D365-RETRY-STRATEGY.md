# D365 Retry Strategy & Exponential Backoff Logic
**Issue #18 — Stream B-2: Resilient D365 Write Handling**  
**Owner**: John Shelby, Flow Orchestration Lead  
**Date**: 2026-04-25

---

## Overview

The **D365-Retry-Logic** scheduled flow implements exponential backoff to recover failed D365 writes with intelligent retry strategies. This document defines the exact backoff algorithm, retry limits, and escalation paths.

---

## Backoff Algorithm

### Exponential Backoff Formula

```
delay(retry) = 2^(retry - 1) × base_interval + jitter

Where:
├─ retry ∈ [1, 2, 3, 4, 5] (retry attempt number)
├─ base_interval = 100 ms (configurable)
└─ jitter = random(0, 50) ms (prevent thundering herd)
```

### Retry Schedule

| Attempt | Formula | Base Delay | Jitter | Total Delay | Cumulative |
|---------|---------|-----------|--------|-------------|------------|
| 1 | 2^0 × 100 | 100 ms | 0–50 ms | 100–150 ms | 100–150 ms |
| 2 | 2^1 × 100 | 200 ms | 0–50 ms | 200–250 ms | 300–400 ms |
| 3 | 2^2 × 100 | 400 ms | 0–50 ms | 400–450 ms | 700–850 ms |
| 4 | 2^3 × 100 | 800 ms | 0–50 ms | 800–850 ms | 1.5–1.7 sec |
| 5 | 2^4 × 100 | 1600 ms | 0–50 ms | 1600–1650 ms | 3.1–3.3 sec |

**Total time across all retries**: ~3.1–3.3 seconds max

---

## D365-Retry-Logic Flow Pseudocode

### Scheduled Trigger (Every 5 Minutes)

```
TRIGGER: Scheduled (Every 5 minutes)
TIMEOUT: 45 seconds (must complete before next cycle)
CONCURRENCY: Max 10 pending records per cycle

MAIN LOGIC:
├─ Query D365WriteEvent table for:
│  ├─ status = Pending (100000000)
│  ├─ retry_count < 5
│  ├─ write_date > now - 5 minutes (only recent failures)
│  └─ ORDER BY write_date ASC (oldest first)
│  └─ TOP 10 (batch size limit)
│
├─ For each Pending record (up to 10, in parallel with throttle=5):
│  │
│  ├─ Retry Attempt Logic (see Section 2)
│  │
│  └─ Update D365WriteEvent based on result
│
└─ END OF CYCLE
```

---

## Retry Attempt Logic (Detailed)

### Retry Attempt Pseudocode

```
FUNCTION: retry_d365_write(writeEvent: D365WriteEvent)

┌─ Step 1: Calculate Backoff Delay ──────────────────────────┐
│                                                             │
│  retry_count = writeEvent.retry_count                      │
│  delay_ms = (2 ^ retry_count) * 100 + random(0, 50)       │
│                                                             │
│  Example (Retry 3):                                        │
│  ├─ 2 ^ 2 = 4                                              │
│  ├─ 4 × 100 = 400 ms                                       │
│  └─ + random jitter = 400–450 ms                           │
│                                                             │
│  WAIT(delay_ms)  // Sleep before attempting retry          │
│                                                             │
└───────────────────────────────────────────────────────────┘

┌─ Step 2: Retrieve Current Form Context ───────────────────┐
│                                                             │
│  GET formSubmission FROM Dataverse                         │
│  WHERE formSubmissionId = writeEvent.form_submission      │
│                                                             │
│  GET extractionResult FROM Dataverse                       │
│  WHERE extractionResultId = formSubmission.extraction_result
│                                                             │
│  payload = writeEvent.mapped_fields (JSON)                 │
│  d365_record_id = writeEvent.d365_record_id               │
│  d365_table = writeEvent.d365_table ("accounts")           │
│                                                             │
└───────────────────────────────────────────────────────────┘

┌─ Step 3: Pre-Retry Validation (Circuit Breaker) ──────────┐
│                                                             │
│  IF retry_count >= 5:                                      │
│  └─ MARK as Failed (max retries exceeded)                  │
│  └─ ESCALATE to admin queue                               │
│  └─ RETURN (stop processing this record)                   │
│                                                             │
│  IF write_date < now - 24 hours:                           │
│  └─ MARK as Abandoned (stale retry)                        │
│  └─ LOG audit event (very old write, stopping retries)     │
│  └─ RETURN (stop processing this record)                   │
│                                                             │
│  IF last_retry_response contains "404":                    │
│  └─ Account no longer exists in D365                       │
│  └─ MARK as Failed (Account Deleted)                       │
│  └─ LOG audit event (D365 account not found)               │
│  └─ ESCALATE to admin (account recovery needed)            │
│  └─ RETURN (don't retry a deleted account)                 │
│                                                             │
└───────────────────────────────────────────────────────────┘

┌─ Step 4: Account Existence Check ─────────────────────────┐
│                                                             │
│  TRY:                                                      │
│    HTTP GET https://d365.../api/data/v9.2/accounts(id)   │
│    TIMEOUT: 5 seconds                                     │
│    RESPONSE: statusCode                                   │
│                                                             │
│  IF statusCode = 200:                                      │
│  └─ Account exists → Proceed to Step 5                     │
│                                                             │
│  IF statusCode = 404:                                      │
│  └─ Account deleted/migrated                               │
│  └─ Set last_retry_response = "404 - Account not found"    │
│  └─ GOTO Step 6 (Handle 404)                               │
│                                                             │
│  IF statusCode = 401 OR 403:                               │
│  └─ Auth error (token expired or permission denied)        │
│  └─ GOTO Step 6 (Handle Auth Error)                        │
│                                                             │
│  IF statusCode >= 500:                                     │
│  └─ D365 service error                                     │
│  └─ GOTO Step 6 (Handle Service Error)                     │
│                                                             │
│  IF TIMEOUT or NETWORK_ERROR:                              │
│  └─ Network/connectivity issue                             │
│  └─ GOTO Step 6 (Handle Network Error)                     │
│                                                             │
└───────────────────────────────────────────────────────────┘

┌─ Step 5: Attempt D365 Write ──────────────────────────────┐
│                                                             │
│  TRY:                                                      │
│    IF d365_record_id is new (not yet created):            │
│      METHOD = POST (/accounts)                             │
│      URI = https://d365.../api/data/v9.2/accounts          │
│    ELSE:                                                   │
│      METHOD = PATCH (/accounts(id))                        │
│      URI = https://d365.../api/data/v9.2/accounts(        │
│            d365_record_id)                                 │
│                                                             │
│    BODY = payload (JSON account object)                    │
│    TIMEOUT: 15 seconds                                     │
│    HEADERS:                                                │
│    ├─ Authorization: Bearer $(d365-access-token)          │
│    ├─ Content-Type: application/json                       │
│    └─ If-Match: * (force overwrite any version)            │
│                                                             │
│  ON SUCCESS (statusCode = 204 or 201):                     │
│  └─ GOTO Step 5a (Success)                                 │
│                                                             │
│  ON FAILURE (statusCode >= 400):                           │
│  └─ Set last_retry_response = error details                │
│  └─ GOTO Step 6 (Error Handling)                           │
│                                                             │
│  ON TIMEOUT or NETWORK_ERROR:                              │
│  └─ Set last_retry_response = timeout/network error        │
│  └─ GOTO Step 6 (Error Handling)                           │
│                                                             │
└───────────────────────────────────────────────────────────┘

┌─ Step 5a: Success (Write Succeeded) ──────────────────────┐
│                                                             │
│  UPDATE D365WriteEvent:                                    │
│  ├─ status = Success (100000001)                           │
│  ├─ retry_count = retry_count + 1                          │
│  ├─ last_retry_date = now()                                │
│  └─ last_retry_response = "204 OK - Success"               │
│                                                             │
│  UPDATE FormSubmission:                                    │
│  ├─ status = Written (100000005)                           │
│  ├─ completion_date = now()                                │
│  └─ form_locked = true                                     │
│                                                             │
│  CREATE AuditLog:                                          │
│  ├─ form_submission = FormSubmissionID                     │
│  ├─ event_type = D365WriteRetrySuccess (100000009)         │
│  ├─ status = Success (100000000)                           │
│  └─ details = {                                            │
│      "retryAttempt": retry_count + 1,                      │
│      "originalWriteDate": write_date,                      │
│      "totalTimeToSuccess": now() - write_date              │
│    }                                                        │
│                                                             │
│  SEND NOTIFICATION:                                        │
│  └─ Teams message to #va-form-extraction-alerts:           │
│     "✅ Form vafe_XXXXX successfully written to D365      │
│      (Retry #N after initial timeout)"                     │
│                                                             │
│  RETURN (Success - stop retrying)                          │
│                                                             │
└───────────────────────────────────────────────────────────┘

┌─ Step 6: Error Handling & Retry Decision ─────────────────┐
│                                                             │
│  error_type = classify(last_retry_response)                │
│  retry_count_current = writeEvent.retry_count              │
│                                                             │
│  ┌─ Case 1: Transient Error (5xx, timeout, network) ──────┐
│  │                                                         │
│  │  IF retry_count_current < 5:                            │
│  │  ├─ UPDATE D365WriteEvent:                              │
│  │  │  ├─ status = Pending (still)                         │
│  │  │  ├─ retry_count = retry_count + 1                    │
│  │  │  ├─ last_retry_date = now()                          │
│  │  │  └─ last_retry_response = error details              │
│  │  │                                                       │
│  │  ├─ CREATE AuditLog:                                    │
│  │  │  ├─ event_type = D365WriteRetryFailed (100000010)    │
│  │  │  ├─ status = Failure (100000001)                     │
│  │  │  └─ details = { retryAttempt, error, nextRetryIn: "5min" }
│  │  │                                                       │
│  │  └─ SEND NOTIFICATION (optional):                       │
│  │     "⏱️ Form retry #N scheduled (transient error)"      │
│  │     "Next attempt in ~5 minutes"                        │
│  │                                                         │
│  │  RETURN (Will retry in next 5-min cycle)                │
│  │                                                         │
│  │  ELSE (retry_count = 5):                                │
│  │  └─ GOTO Case 4 (Max retries exceeded)                  │
│  │                                                         │
│  └─────────────────────────────────────────────────────────┘
│
│  ┌─ Case 2: Permanent Error (4xx, validation, auth) ──────┐
│  │                                                         │
│  │  IF error = "404 Not Found":                            │
│  │  └─ Account no longer exists in D365                    │
│  │  └─ GOTO Step 6b (Account Not Found)                    │
│  │                                                         │
│  │  IF error = "401 Unauthorized" or "403 Forbidden":      │
│  │  └─ Auth error (service principal permissions issue)    │
│  │  └─ GOTO Step 6c (Auth Error)                           │
│  │                                                         │
│  │  IF error = "400 Bad Request" or validation:            │
│  │  └─ Payload validation failed                           │
│  │  └─ GOTO Step 6d (Validation Error)                     │
│  │                                                         │
│  │  IF error = "409 Conflict" (optimistic concurrency):    │
│  │  └─ Account was modified by another process             │
│  │  └─ GOTO Step 6e (Conflict)                             │
│  │                                                         │
│  │  ELSE:                                                  │
│  │  └─ Unknown 4xx error                                   │
│  │  └─ GOTO Step 6d (Escalate as permanent error)          │
│  │                                                         │
│  └─────────────────────────────────────────────────────────┘
│
└───────────────────────────────────────────────────────────┘

┌─ Step 6b: Account Not Found (404) ────────────────────────┐
│                                                             │
│  UPDATE D365WriteEvent:                                    │
│  ├─ status = Failed (100000002)                            │
│  ├─ last_retry_response = "404 - Account not found"        │
│  └─ retry_count = retry_count (do not increment)           │
│                                                             │
│  UPDATE FormSubmission:                                    │
│  ├─ status = D365AccountNotFound (100000007)               │
│                                                             │
│  CREATE AuditLog:                                          │
│  ├─ event_type = D365AccountNotFound (100000012)           │
│  ├─ status = Failure (100000001)                           │
│  └─ details = {                                            │
│      "d365RecordId": d365_record_id,                       │
│      "reason": "Account deleted or migrated"               │
│    }                                                        │
│                                                             │
│  CREATE Escalation Task:                                   │
│  ├─ Type: "Account Recovery Required"                      │
│  ├─ Title: "Form vafe_XXXXX - Account Not Found in D365"   │
│  ├─ Description: "Original account ID no longer exists.    │
│     Check for merges, deletions, or migrations."           │
│  ├─ Assigned To: Operations Admin                          │
│  └─ Priority: High                                         │
│                                                             │
│  SEND NOTIFICATION:                                        │
│  └─ Teams message to #va-form-extraction-admin:            │
│     "🚨 CRITICAL: Form account not found in D365           │
│      Form: vafe_XXXXX | D365 ID: {id}                      │
│      Admin action required. Review recovery options."      │
│                                                             │
│  RETURN (Stop processing, admin action needed)             │
│                                                             │
└───────────────────────────────────────────────────────────┘

┌─ Step 6c: Auth Error (401/403) ───────────────────────────┐
│                                                             │
│  UPDATE D365WriteEvent:                                    │
│  ├─ status = Failed (100000002)                            │
│  ├─ last_retry_response = "401/403 - Auth failed"          │
│  └─ last_retry_date = now()                                │
│                                                             │
│  CREATE AuditLog:                                          │
│  ├─ event_type = D365AuthenticationError                   │
│  ├─ status = Failure (100000001)                           │
│  └─ details = { error: "401/403", reason: "Service principal permissions" }
│                                                             │
│  CREATE CRITICAL Escalation Task:                          │
│  ├─ Type: "Service Principal Auth Failure"                 │
│  ├─ Title: "D365 Write Service Principal Auth Failed"      │
│  ├─ Description: "Service principal cannot authenticate    │
│     to D365. Check permissions & token expiry."            │
│  ├─ Assigned To: IT Security Team                          │
│  └─ Priority: CRITICAL (blocks all writes)                 │
│                                                             │
│  SEND NOTIFICATION:                                        │
│  └─ CRITICAL alert to #va-form-extraction-admin            │
│                                                             │
│  RETURN (Stop processing, IT action needed)                │
│                                                             │
└───────────────────────────────────────────────────────────┘

┌─ Step 6d: Validation Error (400) ─────────────────────────┐
│                                                             │
│  UPDATE D365WriteEvent:                                    │
│  ├─ status = Failed (100000002)                            │
│  ├─ last_retry_response = full error message from D365     │
│  └─ last_retry_date = now()                                │
│                                                             │
│  UPDATE FormSubmission:                                    │
│  ├─ status = D365ValidationFailed (100000008)              │
│                                                             │
│  CREATE AuditLog:                                          │
│  ├─ event_type = D365ValidationError                       │
│  ├─ status = Failure (100000001)                           │
│  └─ details = {                                            │
│      "errorMessage": D365 validation error,                │
│      "payload": writeEvent.mapped_fields (JSON)            │
│    }                                                        │
│                                                             │
│  CREATE Escalation Task:                                   │
│  ├─ Type: "Data Validation Failed"                         │
│  ├─ Title: "Form vafe_XXXXX - D365 Validation Error"       │
│  ├─ Description: "Extracted/transformed data failed D365   │
│     validation. Review payload & AI extraction."           │
│  ├─ Assigned To: Data Validation Team / AI Team            │
│  └─ Priority: High                                         │
│                                                             │
│  SEND NOTIFICATION:                                        │
│  └─ Teams message with error details                       │
│                                                             │
│  RETURN (Stop processing, data fix needed)                 │
│                                                             │
└───────────────────────────────────────────────────────────┘

┌─ Step 6e: Conflict (409) ─────────────────────────────────┐
│                                                             │
│  Account was modified concurrently (optimistic lock)       │
│                                                             │
│  IF retry_count_current < 5:                               │
│  ├─ Retry with exponential backoff (normal retry path)     │
│  ├─ UPDATE D365WriteEvent:                                 │
│  │  ├─ status = Pending (still)                            │
│  │  ├─ retry_count = retry_count + 1                       │
│  │  └─ last_retry_response = "409 - Conflict (will retry)" │
│  │                                                          │
│  │  RETURN (Will retry in next 5-min cycle)                │
│  │                                                          │
│  ELSE (retry_count = 5):                                   │
│  └─ GOTO Case 4 (Max retries exceeded)                     │
│                                                             │
└───────────────────────────────────────────────────────────┘

┌─ Step 6f: Max Retries Exceeded (Retry 5 Failed) ─────────┐
│  aka Case 4: Max Retries Exceeded                          │
│                                                             │
│  UPDATE D365WriteEvent:                                    │
│  ├─ status = Failed (100000002)                            │
│  ├─ retry_count = 5 (final)                                │
│  ├─ last_retry_response = error message from last attempt  │
│  └─ last_retry_date = now()                                │
│                                                             │
│  UPDATE FormSubmission:                                    │
│  ├─ status = D365WriteFailedEscalated (100000006)          │
│                                                             │
│  CREATE AuditLog:                                          │
│  ├─ event_type = D365WriteMaxRetriesExceeded (100000011)   │
│  ├─ status = Failure (100000001)                           │
│  └─ details = {                                            │
│      "totalRetries": 5,                                    │
│      "totalTimeSpent": now() - write_date,                 │
│      "lastError": last_retry_response                      │
│    }                                                        │
│                                                             │
│  CREATE CRITICAL Escalation Task:                          │
│  ├─ Type: "D365 Write Failed - Max Retries"                │
│  ├─ Title: "Form vafe_XXXXX - D365 Write Failed (5 retries)"
│  ├─ Description: "Failed to write to D365 after 5 retries  │
│     spanning 3+ hours. Manual intervention required."      │
│  ├─ Assigned To: Operations Admin + Alfie Solomons (D365)  │
│  └─ Priority: CRITICAL                                     │
│                                                             │
│  SEND NOTIFICATION:                                        │
│  └─ CRITICAL alert to #va-form-extraction-admin            │
│     "@operations-admin @alfie-solomons                     │
│      Form vafe_XXXXX failed D365 write after 5 retries.    │
│      Last error: [error message]                           │
│      Review remediation options."                          │
│                                                             │
│  RETURN (Stop processing, manual recovery needed)          │
│                                                             │
└───────────────────────────────────────────────────────────┘
```

---

## Retry Error Classification

### Transient Errors (Retry)

```
Status Code 503 (Service Unavailable)
Status Code 504 (Gateway Timeout)
Status Code 429 (Too Many Requests)
Network Timeout (>15s)
DNS Resolution Failure
Connection Reset

Action: Retry with exponential backoff (max 5 attempts)
```

### Permanent Errors (Don't Retry)

```
Status Code 400 (Bad Request) — validation error
Status Code 401 (Unauthorized) — auth failed
Status Code 403 (Forbidden) — permission denied
Status Code 404 (Not Found) — account/resource doesn't exist
Status Code 405 (Method Not Allowed)
Status Code 422 (Unprocessable Entity) — data issue

Action: Escalate to admin, don't retry
```

### Hybrid Errors (Retry Once, Then Escalate)

```
Status Code 409 (Conflict) — optimistic lock
Status Code 412 (Precondition Failed)

Action: Retry up to 5 times (may resolve if concurrent updates finish)
If still fails: Escalate as permanent error
```

---

## Configuration Constants

```powershell
# Retry Configuration (in code or config file):

BASE_INTERVAL_MS = 100          # Base delay for exponential backoff
MAX_RETRY_ATTEMPTS = 5          # Maximum retry count
RETRY_CYCLE_INTERVAL = 5        # Minutes (scheduled flow trigger)
HTTP_TIMEOUT_SECONDS = 15       # Per D365 API call
QUERY_TIMEOUT_SECONDS = 30      # For Dataverse query
FLOW_TIMEOUT_SECONDS = 45       # Total scheduled flow must complete in this time

JITTER_ENABLED = true           # Add random jitter to prevent thundering herd
JITTER_MAX_MS = 50              # Max random jitter added to delay

D365_WRITE_SLA_MINUTES = 60     # If write pending >60 min, escalate
D365_WRITE_STALE_HOURS = 24     # If write_date >24h ago, abandon retry

BATCH_SIZE_PER_CYCLE = 10       # Max records to process per 5-min cycle
PARALLEL_RETRIES = 5            # Parallel task concurrency (throttle)
```

---

## Performance Analysis

### Timeline Example: Form Retry Over 25+ Minutes

```
Timeline:
├─ 10:00:00 AM: Initial D365 write attempt fails (timeout)
│              D365WriteEvent created: status = "Pending", retry_count = 0
│              FormSubmission: status = "ReadyForD365Write"
│
├─ 10:05:00 AM: D365-Retry-Logic scheduled flow runs (Cycle 1)
│              ├─ Query finds 1 pending record (write from 10:00)
│              ├─ Calculate backoff: 2^0 × 100 + jitter = 100–150 ms
│              ├─ Wait 100–150 ms
│              ├─ Retry D365 write attempt #1 → Still fails (503)
│              ├─ Update: retry_count = 1, status = "Pending"
│              └─ AuditLog: D365WriteRetryFailed
│
├─ 10:10:00 AM: D365-Retry-Logic scheduled flow runs (Cycle 2)
│              ├─ Query finds 1 pending record
│              ├─ Calculate backoff: 2^1 × 100 + jitter = 200–250 ms
│              ├─ Wait 200–250 ms
│              ├─ Retry D365 write attempt #2 → Still fails (504)
│              ├─ Update: retry_count = 2, status = "Pending"
│              └─ AuditLog: D365WriteRetryFailed
│
├─ 10:15:00 AM: D365-Retry-Logic scheduled flow runs (Cycle 3)
│              ├─ Query finds 1 pending record
│              ├─ Calculate backoff: 2^2 × 100 + jitter = 400–450 ms
│              ├─ Wait 400–450 ms
│              ├─ Retry D365 write attempt #3 → Success! (204)
│              ├─ Update: status = "Success", retry_count = 3
│              ├─ Update FormSubmission: status = "Written"
│              └─ AuditLog: D365WriteRetrySuccess
│
└─ Total time: 10:00 AM → 10:15 AM (15 minutes, 3 retries)
   Total backoff time: ~650–750 ms
```

### Worst Case: Max Retries Over 3+ Hours

```
Timeline:
├─ 10:00:00 AM: Initial D365 write attempt fails
│              D365WriteEvent: retry_count = 0
│
├─ 10:05:00 AM: Cycle 1 - Retry #1 fails (backoff ~100–150 ms)
│              retry_count = 1
│
├─ 10:10:00 AM: Cycle 2 - Retry #2 fails (backoff ~200–250 ms)
│              retry_count = 2
│
├─ 10:15:00 AM: Cycle 3 - Retry #3 fails (backoff ~400–450 ms)
│              retry_count = 3
│
├─ 10:20:00 AM: Cycle 4 - Retry #4 fails (backoff ~800–850 ms)
│              retry_count = 4
│
├─ 10:25:00 AM: Cycle 5 - Retry #5 fails (backoff ~1600–1650 ms)
│              retry_count = 5 (MAX)
│              → Max retries exceeded
│              → Escalate to admin
│              → Mark as FAILED
│
└─ Total time: 10:00 AM → 10:25 AM (25 minutes from initial failure)
   Total backoff time: ~3.1–3.3 seconds (plus cycle delays)
```

---

## Monitoring & Alerting

### Metrics to Track

```
D365WriteEvent table metrics:
├─ Total Pending: COUNT(status = "Pending") — should approach 0
├─ Total Successful: COUNT(status = "Success") — cumulative success
├─ Total Failed: COUNT(status = "Failed") — cumulative failures
├─ Avg Retry Count: AVG(retry_count) — should be 1–2 if working
├─ Max Retry Count: MAX(retry_count) — should not exceed 5
└─ Pending Age: MAX(now - write_date) — no record should be pending >60 min

Scheduled Flow Performance:
├─ Execution Time: Should be <45 seconds per 5-min cycle
├─ Execution Frequency: Should run every 5 minutes consistently
├─ Success Rate: 99%+ (occasional failures expected)
└─ Records Processed: Track batch sizes (usually 5–10 per cycle)

Error Metrics:
├─ Transient Error Rate: Count 503/504/timeout errors
├─ Permanent Error Rate: Count 400/401/404 errors
├─ Max Retries Exceeded: Should be <1% of all attempts
└─ Time to Resolution: Avg time from initial failure to success/escalation
```

### Alert Thresholds

| Alert | Condition | Action |
|-------|-----------|--------|
| **High Pending Count** | >50 pending records | Page on-call engineer |
| **Slow Retry Cycle** | Flow execution >45s | Check resource constraints |
| **High Failure Rate** | >5% permanent failures | Investigate D365 health |
| **Max Retries Exceeded** | >3 in last hour | Check D365 connectivity / auth |
| **Stale Pending Record** | >60 min pending age | Manual escalation |

---

## Troubleshooting Guide

### Issue: Many Pending Records Not Retrying

**Symptom**: D365WriteEvent.status = "Pending" for >30 minutes

**Root Causes**:
1. Scheduled flow not running (check Power Automate execution history)
2. Flow timeout (<45s) — too many records queued
3. Query taking too long
4. Throttling limit hit

**Diagnostics**:
```powershell
# Check scheduled flow executions
Get-FlowRun -FlowName "D365-Retry-Logic" -Limit 10

# Check pending records age
Get-DataverseRecords -Table "vafe_d365writeevent" `
  -Filter "vafe_status eq 100000000 and vafe_write_date lt @{AddHours(-1)}"

# Check last execution error
# → Power Automate cloud portal → Flow run history
```

**Fixes**:
- Increase batch size if <50 pending
- Reduce parallel concurrency if timeout
- Check D365 service health

### Issue: Retry Always Fails with 503

**Symptom**: D365WriteEvent.last_retry_response contains "503 Service Unavailable"

**Root Causes**:
1. D365 service degraded
2. D365 tenant running capacity limits
3. Network connectivity issue

**Diagnostics**:
```powershell
# Check D365 service health
Get-D365ServiceHealth

# Check tenant storage usage
Get-D365OrganizationStorage

# Monitor Azure service health (portal)
# → Azure Monitor → Service Health → Dynamics 365 status
```

**Fixes**:
- Wait for D365 service to recover (auto-retry will continue)
- Contact Microsoft Support if persists >1 hour
- Reduce form submission rate if hitting capacity limits

### Issue: Retry Succeeds but FormSubmission Still Shows "ReadyForD365Write"

**Symptom**: D365WriteEvent.status = "Success" but FormSubmission.status ≠ "Written"

**Root Cause**: Final update step failed (race condition or Dataverse issue)

**Fix**:
```powershell
# Manually update FormSubmission status
Update-DataverseRecord -Table "vafe_formsubmission" `
  -RecordId $formSubmissionId `
  -PropertyBag @{
    "vafe_status" = 100000005  # Written
    "vafe_completion_date" = [DateTime]::UtcNow
  }
```

---

## Configuration & Deployment

### Power Automate Flow Settings

```
Flow: D365-Retry-Logic
├─ Schedule Trigger: Every 5 minutes
├─ Timeout: 45 seconds
├─ Retry Policy: 1 automatic retry (Power Automate built-in)
├─ Throttling: 
│  ├─ Parallel tasks: Max 5 concurrent retries
│  └─ Query throttle: Batch 10 records at a time
└─ Environment: VA Form Extraction (Production)
```

### Environment Variables / Configuration

```
Key Vault secrets (for flow to reference):
├─ d365-instance-url: https://va-form-extraction.crm.dynamics.com
├─ d365-api-version: v9.2
├─ d365-http-timeout-sec: 15
├─ dataverse-retry-backoff-base-ms: 100
├─ dataverse-retry-max-attempts: 5
└─ retry-cycle-interval-min: 5
```

---

## Testing & Validation

### Manual Test Cases

**Test 1: Transient Error Recovery (503)**
```
Setup: Create D365WriteEvent with status = "Pending"
Action: Mock D365 API to return 503 on first 2 attempts, 204 on 3rd
Result: Record should be retried, status = "Success" after 3rd attempt
Metrics: retry_count = 2 (not 3), backoff ~400–450 ms total
```

**Test 2: Permanent Error (404)**
```
Setup: Create D365WriteEvent pointing to non-existent account
Action: Run retry cycle
Result: Record marked "Failed", escalation task created
Metrics: retry_count unchanged, status = "Failed"
```

**Test 3: Max Retries (5 Failures)**
```
Setup: Create D365WriteEvent with status = "Pending"
Action: Mock D365 API to always return 503
Result: After 5 retry cycles, status = "Failed", escalation task created
Metrics: retry_count = 5, total time = ~25 min, alert sent
```

**Test 4: High Volume (100 pending records)**
```
Setup: Create 100 D365WriteEvent records in "Pending" status
Action: Run retry cycle with batch_size = 10, parallel = 5
Result: 
  - Cycle processes 10 records with 5 parallel workers
  - Flow completes in <45 sec
  - Remaining 90 records queued for next cycle
Metrics: Throughput = 10 records/cycle (50 records/25 min)
```

---

## Documentation & Runbooks

### On-Call Runbook

**If Alert: "Retry Queue Stuck" (>50 Pending)**

```
1. Check scheduled flow status
   → Power Automate portal → D365-Retry-Logic → Run history
   → Look for failed/timeout runs

2. Check D365 service health
   → Azure portal → Service Health → Dynamics 365
   → Check for ongoing incidents

3. Check Dataverse query performance
   → Dataverse admin → Debugging → Query stats
   → Look for slow queries

4. If flow stuck: Manually trigger
   → Cloud portal → Test → Run → Wait for completion

5. If D365 down: Wait for recovery (expected 30–60 min)
   → Retries will continue automatically
   → No manual action needed

6. If query slow: Update flow batch size
   → Reduce batch_size from 10 → 5
   → Increase parallel from 5 → 3 (reduce load)

7. Escalate if unresolved >1 hour
   → Contact Alfie (D365 team)
   → Contact Microsoft Support (if D365 issue)
```

---

**Status**: ✅ **D365 RETRY STRATEGY COMPLETE**

**Prepared by**: John Shelby, Flow Orchestration Lead  
**Date**: 2026-04-25  
**Audience**: Operations, On-Call Engineers, D365 Admins  
**Ready for**: Phase 2 deployment & on-call training
