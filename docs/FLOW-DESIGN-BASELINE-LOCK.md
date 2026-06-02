# Flow Design Baseline Lock

**Project**: VA Form 10-3542 Extraction Pipeline  
**Date**: 2026-05-18  
**Intent**: Prevent rework by freezing the current as-built baseline and defining only the next required design deltas.

Version control reference: `docs/DESIGN-VERSION-REGISTRY.md`.

---

## 1) Canonical Naming Decision (Locked)

Use **MVP naming** as canonical for implementation and handoff:

- `MVP-01-SharePoint-To-D365-Intake` (parent)
- `MVP-05-AI-Extraction-Subflow`
- `MVP-02-D365-Write-Subflow`
- `MVP-03-Audit-Logger-Subflow`
- `MVP-04-D365-Retry` (next build)
- `MVP-06-Batch-Folder-Processor` (documented/build artifact available)

Reason: this naming matches the most recent implementation/test evidence.

---

## 2) As-Built Baseline (Do Not Re-Suggest)

The following are treated as already implemented and validated unless runtime evidence proves otherwise:

1. End-to-end happy path executes via parent flow + child subflows.
2. Parent flow passes SharePoint `{Identifier}` to extraction subflow (fix applied).
3. Extraction result persistence works with Dataverse truncation protection for large OCR payloads.
4. D365 write subflow executes and creates write-event records.
5. Audit logger subflow executes and writes info-level entries.
6. Safe baseline `D365PayloadJson` with `Unknown` defaults is intentional for current MVP and not a defect.
7. ExtractionResult table includes currency columns for expense lines and totals: `Expense A Amount`, `Expense B Amount`, `Expense C Amount`, `Expense D Amount`, `Total Amount Claimed`.
8. `MVP-05-AI-Extraction-Subflow` maps expense values directly into `Create ExtractionResult` (no required Compose intermediary).
9. Total amount write path supports null-safe fallback behavior when one or more expense line values are blank.

Evidence sources:
- `solution-src/VAFormExtractionDemo/Flows/BUILD-SUMMARY-MAY-14-15.md`
- `solution-src/VAFormExtractionDemo/Flows/MVP-POWER-AUTOMATE-BUILD-CHECKLIST.md`

### 2026-06-02 Patch Note (Locked)

Live Dataverse/table and flow updates were applied in `VAFormExtractionDemo` solution (Contact Center environment):

1. Added/verified currency fields on `Extraction Result` for expense A/B/C/D and total claimed.
2. Standardized expense mapping target to `MVP-05-AI-Extraction-Subflow` action `Create ExtractionResult`.
3. Confirmed total-amount handling must be expression-based and null-safe when any expense input is blank.

---

## 3) Required Next Design Deltas (Only)

### Delta A: MVP-04 Retry Design Finalization (Required)

Goal: make failed D365 writes deterministic and recoverable without duplicate side effects.

Design requirements:
1. Retry trigger source is `vafe_d365writeevent` rows in failed/retrying states.
2. Retry schedule is explicit (2m, 5m, 10m) with `MaxRetryCount = 3`.
3. Terminal failure writes to dead-letter target and emits alert.
4. Success path updates both write-event status and parent form status consistently.
5. Retry execution must be idempotent for the same `FormSubmissionId + CorrelationId`.

Acceptance criteria:
1. A simulated D365 outage produces retry attempts at defined cadence.
2. Successful recovery after retry updates status to success exactly once.
3. Max-retry exhaustion lands exactly one dead-letter record and one alert.

Owner routing:
- Build/design: `squad:john-shelby`
- D365 validation: `squad:alfie-solomons`
- QA scenarios: `squad:grace-burgess`

---

### Delta B: Manual Review Contract Lock (Required)

Goal: eliminate ambiguity before implementing/adjusting review path.

Design requirements:
1. Entry condition is confidence below accept threshold OR field-level flags.
2. Review payload includes: `FormSubmissionId`, `ExtractionResultId`, flagged fields, model confidence.
3. Reviewer outcomes are limited to: `ApproveWithEdits`, `Reject`, `NeedsEscalation`.
4. Each outcome has explicit status transition and audit action.
5. Approved result re-enters D365 write path exactly once.

Acceptance criteria:
1. State transition matrix has no orphan statuses.
2. Every reviewer action produces an audit record with correlation id.
3. Re-entry to D365 write does not create duplicate contacts for same submission.

Owner routing:
- Contract design: `squad:john-shelby`
- UX/workflow review: `squad:lizzie-stark`
- QA approval: `squad:grace-burgess`

---

### Delta C: Batch Idempotency Guardrails (Required if MVP-06 is used)

Goal: prevent duplicate processing when files are re-run or uploaded twice.

Design requirements:
1. Pre-check key: normalized file fingerprint + source library path + upload timestamp bucket.
2. If active submission exists for key, skip and log `DuplicateSuppressed`.
3. Manual override path exists for explicit reprocess operations.
4. Batch summary must report processed/skipped/failed counts.

Acceptance criteria:
1. Same file run twice yields one processed, one skipped (unless override).
2. Batch summary reconciles with Dataverse writes.
3. Suppressed duplicates remain discoverable in audit log.

Owner routing:
- Flow logic: `squad:john-shelby`
- Data model constraints: `squad:polly-gray`
- QA validation: `squad:grace-burgess`

---

## 4) Explicit Out-of-Scope for This Cycle

1. Full OCR token-to-business-field parser redesign.
2. Model retraining strategy changes beyond current baseline.
3. Broad architecture refactors of already passing happy-path flows.

These are deferred to a later cycle to avoid churn.

---

## 5) Design Questions That Must Be Answered Before Build

These questions are intentionally narrow and should be answered before implementation starts:

1. Should duplicate detection key include content hash, filename, or both?
2. For retry terminal failures, should dead-letter target be SharePoint folder, Dataverse table, or both?
3. For manual review reject outcome, should status return to `Correcting` or move to a terminal `Rejected` state?
4. Should D365 duplicate prevention be keyed on SSN, submission id, or a composite business key?

---

## 6) Squad Execution Sequence (Concrete)

1. Create 3 issues only (one per delta A/B/C) with acceptance criteria copied from this document.
2. Apply routing labels per owner above.
3. Mark each issue with `design-lock` and `no-rework-without-evidence`.
4. Require Tommy review gate before any issue transitions from design to implementation.
5. For copilot-assigned tasks, only route bounded implementation subtasks after the design issue is approved.

---

## 7) Change Control Rule

Any suggestion that conflicts with Section 2 (As-Built Baseline) must include evidence:

- runtime failure record, or
- failing test result, or
- schema/contract mismatch trace.

Without evidence, the suggestion is rejected to prevent rework.
