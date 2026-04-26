# John Shelby — Agent History

**Role**: Power Automate Flow Orchestration Lead  
**Project**: VA Form Extraction (VA Form 10-3542)  

---

## April 25, 2026 — Issue #18: Flow Architecture Design (Complete)

Designed the complete 5-flow Power Automate architecture for the VA form intake pipeline.

**Deliverables**:
- `FLOW-ARCHITECTURE.md` — Main flow + 4 subflows with pseudocode
- `FLOW-CONNECTOR-CONFIG.md` — 6 connectors, 9 Key Vault secrets, troubleshooting guide
- `MANUAL-CORRECTION-WORKFLOW.md` — Low-confidence correction queue with Teams adaptive cards
- `D365-RETRY-STRATEGY.md` — Exponential backoff (2^retry × 100ms), max 5 retries
- `QUICK-START-FLOW-DEPLOYMENT.md` — 5-phase deployment playbook

**Architecture decisions**:
- Confidence threshold: 0.85 (balances auto-processing vs. manual review volume)
- Retry limit: 5 attempts (~3+ hours total recovery window)
- All flows within the VA-Form-Extraction solution for portability
- AuditLog captures 12 event types for compliance

---

## April 26, 2026 — Issue #18 (Continued): Flow Build Runbook (Phase Gate 2→3 Approved)

Phase gate approved by Tommy Shelby. Produced click-by-click human operator runbook.

**Deliverable**: `specs/03-phase-2-stream-b/FLOW-BUILD-RUNBOOK.md`

---

## Learnings

### Flow Build Order
1. **Connections first, always**: All 6 connections must be created and show green (Connected) before authoring any flow step. Broken connections at authoring time leave unresolvable action references.
2. **Tables must exist before Dataverse CRUD steps**: Power Automate cannot resolve table names or field schema at design time if the Dataverse table doesn't exist yet. This means Polly's provisioning work is a hard blocker for flow configuration — not just a soft dependency.
3. **AI Builder model must be published (not just trained)**: The model appears in the action's model dropdown only after it is published. Draft/unpublished models are invisible to Power Automate.
4. **Subflows before main flow**: Build and save all child flows (Audit-Logger, D365-Write, Manual-Correction-Queue, Retry-Logic) before configuring the main flow's "Run a child flow" actions. Child flows must exist in the same solution to appear in the selector.

### Retry Subflow Architecture
- **Must be scheduled, not event-triggered**: A Dataverse row-change trigger on D365WriteEvent would fire on every update — including the retry's own writes — creating an infinite loop. A 5-minute schedule with a filter query (`status=Failed AND retryCount<5`) is the correct pattern.
- **Top count = 10 per run**: Prevents a single scheduled run from processing an unbound number of records and timing out (Power Automate flow max runtime is 30 days for premium, but individual run timeout is 30 minutes for standard connectors).

### Teams Notifications
- **Webhook approach vs. Teams connector**: Incoming Webhook (HTTP POST with MessageCard JSON) is more reliable in GCC environments than the native Teams connector, which has had intermittent authentication issues in government clouds.
- **Store webhook URLs in Key Vault**: Never hardcode webhook URLs in flow expressions. Key Vault allows URL rotation without touching the flow definition.

### SLA Instrumentation
- Power Automate `ticks()` function returns 100-nanosecond intervals since epoch. To get milliseconds: `div(sub(ticks(endTime), ticks(startTime)), 10000)`.
- Store timing data in the AuditLog `Details` field as JSON to enable future KQL/Power BI analysis against the table.
