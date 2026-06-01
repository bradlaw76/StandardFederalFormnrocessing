# Implementation Plan: Multi-Form PDF Splitter (Mode 2)

**Branch**: `004-multi-form-pdf-splitter` | **Date**: 2025-07-17 | **Spec**: [spec.md](spec.md)  
**Input**: Feature specification from `/specs/004-multi-form-pdf-splitter/spec.md`  
**Depends on**: `/specs/001-form-extraction-pipeline/plan.md` (existing pipeline)

---

## Summary

**Objective**: Build a new Power Automate intake flow (Flow 01) that detects multi-form PDFs containing batched VA Form 10-3542 scans, splits them into individual 2-page PDFs, and deposits each into the existing extraction pipeline — without modifying any existing flows.

**Core Value Proposition**: VA staff currently must manually separate batched scans before uploading. Mode 2 automates batch splitting, enabling a single upload of 20+ forms and automatic processing through the existing pipeline, with batch-level tracking and status visibility.

**Approach**:
1. New Flow 01 triggers on PDFs uploaded to a dedicated `FormIntake/Batches/Incoming/` folder
2. Validates page count (must be >2, even), file size (≤150MB), and duplicate detection
3. Splits PDF into individual 2-page files using an Azure Function (HTTP)
4. Deposits split PDFs into the existing `FormIntake/` root folder — triggering existing Flow 1
5. Tracks batch lifecycle via a new `BatchSubmission` Dataverse table
6. Aggregates child form statuses for batch-level visibility

**Key Design Decision**: Flow 01 is purely additive. The existing pipeline flows (Flow 1–4, subflows) are NOT modified. Mode 2 feeds Mode 1 by depositing files into the same SharePoint folder that Flow 1 monitors. The only minor change is a conditional branch in Flow 1 to populate `BatchID` from the filename pattern.

---

## Technical Context

**Platform**: Microsoft Power Platform (low-code/no-code)  
**Primary Components**:
- Power Automate (new Flow 01 + Flow 01B + scheduled monitor)
- Azure Function app (HTTP — for PDF splitting: page counting and split operations)
- Dataverse (new BatchSubmission table + 2 columns on FormSubmission)
- SharePoint (batch intake folder structure)

**Storage**: Dataverse (batch metadata) + SharePoint (PDF files)  
**Testing**: Power Automate cloud flow testing (built-in) + manual end-to-end testing  
**Target Platform**: Microsoft Power Platform (cloud SaaS)  
**Project Type**: Configuration-driven automation (minimal custom code)  
**Performance Goals**:
- 20-form batch: split + feed ≤ 2 minutes (SC-001)
- Batch status updates visible within 30 seconds (SC-003)
- Support up to 250 forms (500 pages) per batch (Phase 1 limit)

**Constraints**:
- Power Automate HTTP action body limit: 100MB per request (applies to Azure Function calls)
- SharePoint file upload limit: 250MB
- Power Automate concurrency: 50 parallel flow runs (for status updater)
- Existing pipeline processes 1 form at a time (sequential)
- 5-second delay between file deposits to avoid pipeline overload

**Scale/Scope**:
- Phase 1: up to 250 forms per batch (500 pages, ~125MB)
- Production target: up to 500 forms per batch (SC-004, requires connector upgrade)
- Demo: 3–5 form batches for testing

---

## Constitution Check

**Gate: Must pass before Phase 0 research**

From `.specify/memory/constitution.md` (v1.0.0):

| Principle | Requirement | Status |
|-----------|-------------|--------|
| **I. Registry-First** | Governance data resolves against registry | ✅ N/A — no governance data changes |
| **II. Profile-Driven Compliance** | Project declares SpeckKit profile | ✅ Existing profile unchanged |
| **III. Graceful Degradation** | Never crash on errors; user-friendly messages | ✅ Flow 01 validates input, preserves partial results, and notifies operators on failure |
| **IV. Spec-Driven Development** | Features specified before implementation; specs define WHAT not HOW | ✅ Spec complete (spec.md v1.0.0); plan follows from spec |
| **V. Simplicity & Incrementalism** | Start simple; avoid premature abstraction; ship working increments | ✅ Single new flow + 1 new table; reuses all existing flows; no new infrastructure |

**Development Workflow Compliance**:

| Rule | Status |
|------|--------|
| Conventional commits (`feat:`, `fix:`, etc.) | ✅ Will use `feat: add batch PDF splitter flow` |
| Feature branch naming (`NNN-feature-name`) | ✅ `004-multi-form-pdf-splitter` |
| Specs in `specs/<branch-name>/` | ✅ `specs/004-multi-form-pdf-splitter/` |

**Post-Phase 1 Re-check**: ✅ PASS
- Flow 01 logic is documented in contracts (flow-01-batch-splitter.md)
- Error handling covers: validation failure, split failure, partial failure, stale batches
- Dataverse schema defined in data-model.md
- No complexity violations — single flow, single table, reuse of existing pipeline

---

## Project Structure

### Documentation (this feature)

```text
specs/004-multi-form-pdf-splitter/
├── spec.md                          # Feature specification
├── plan.md                          # This file
├── research.md                      # Phase 0: PDF splitting options, file limits, concurrency
├── data-model.md                    # Phase 1: BatchSubmission table + FormSubmission extensions
├── quickstart.md                    # Phase 1: Setup guide for building Flow 01
├── contracts/
│   ├── flow-01-batch-splitter.md    # Phase 1: Flow 01 trigger/step/output contract
│   └── batch-status-aggregation.md  # Phase 1: Flow 01B status updater contract
└── tasks.md                         # Phase 2: (generated by /speckit.tasks)
```

### Power Platform Artifacts (No Code Repository)

```text
Power Platform Environment:
├── Dataverse
│   ├── BatchSubmission table          ← NEW
│   ├── FormSubmission table           ← EXTENDED (2 new columns)
│   ├── ExtractionResult table         (unchanged)
│   ├── CorrectionRecord table         (unchanged)
│   ├── AuditLog table                 (unchanged, new ActionType values)
│   └── D365WriteEvent table           (unchanged)
├── Power Automate
│   ├── Flow-01-Batch-PDF-Splitter     ← NEW (trigger: SharePoint Batches/Incoming)
│   ├── Flow-01B-Batch-Status-Updater  ← NEW (trigger: FormSubmission status change)
│   ├── Flow-01C-Stale-Batch-Monitor   ← NEW (scheduled: hourly)
│   ├── Intake-Trigger flow            (existing Flow 1 — minor conditional addition)
│   ├── AI-Builder-Extraction flow     (existing Flow 2 — unchanged)
│   ├── Approval-Workflow flow         (existing Flow 3 — unchanged)
│   ├── D365-Write flow                (existing Flow 4 — unchanged)
│   ├── Audit-Event-Logger subflow     (existing — reused by Flow 01)
│   └── Notification-Router subflow    (existing — reused by Flow 01)
├── SharePoint
│   └── FormIntake/
│       ├── Batches/
│       │   ├── Incoming/              ← NEW (upload target for batch PDFs)
│       │   ├── BATCH-YYYYMMDD-NNN/    ← NEW (per-batch subfolder)
│       │   │   ├── _original_*.pdf    (retained original)
│       │   │   └── BATCH-*-NNN.pdf    (split PDFs, intermediate)
│       │   └── ...
│       ├── *.pdf                      (individual forms — Flow 1 trigger point)
│       └── Processed/                 (existing)
├── Connections
│   └── Azure Function (HTTP)  ← Replaces premium PDF connector
└── Power BI
    └── Extraction-Dashboard           (existing — extend with batch metrics)
```

**Structure Decision**: No new code repositories. All artifacts are Power Platform configuration objects (flows, tables, connections). Documentation lives in `specs/004-multi-form-pdf-splitter/`.

---

## Phase 0: Research & Unknowns Resolution

### Technical Unknowns Resolved

| Unknown | Decision | Reference |
|---------|----------|-----------|
| PDF splitting method | Azure Function (primary); Muhimbi PDF Connector documented as alternative | research.md §1 |
| File size limits | 150MB hard limit; 250 forms max per batch (Phase 1) | research.md §2 |
| Concurrency & throttling | Sequential file deposit with 5-second delay between moves | research.md §3 |
| Batch tracking approach | New BatchSubmission table; aggregated status from child forms | research.md §4 |
| Duplicate detection | Filename + file size + page count (Phase 1); SHA-256 hash (Phase 2) | research.md §5 |
| SharePoint folder structure | `Batches/Incoming/` for upload; `Batches/{BatchID}/` for processing | research.md §6 |

**Output**: `research.md` ✅ Complete

---

## Phase 1: Design & Contracts

### 1. Data Model

**New Entity: BatchSubmission**
- Tracks batch lifecycle: upload → validate → split → feed → complete
- 10-state state machine (see data-model.md §1)
- Aggregated counters for child form statuses (FormsCompleted, FormsInReview, FormsFailed)
- Stale batch detection via LastProgressTimestamp

**Extended Entity: FormSubmission**
- 2 new nullable columns: `BatchID` (Lookup), `FormIndexInBatch` (Integer)
- NULL for Mode 1 single-form uploads; populated for Mode 2 batch forms
- Populated by Flow 1 parsing the batch filename pattern

**Relationships**:
- BatchSubmission (1) → FormSubmission (0..N) via BatchID lookup
- All existing FormSubmission relationships unchanged

**Output**: `data-model.md` ✅ Complete

### 2. Interface Contracts

**Flow 01 — Batch PDF Splitter**:
- Trigger: SharePoint file created in `Batches/Incoming/`
- 5-step pipeline: Validate → Create batch record → Split PDF → Feed pipeline → Retain original
- Full input/output schemas and error handling documented
- Reuses existing subflows: Audit-Event-Logger, Notification-Router

**Flow 01B — Batch Status Updater**:
- Trigger: FormSubmission status change (where BatchID is not null)
- Aggregates child statuses → updates BatchSubmission counters
- Detects terminal state → sets BatchStatus to Complete or PartiallyFailed
- Concurrency guard via Dataverse optimistic concurrency

**Output**: `contracts/flow-01-batch-splitter.md`, `contracts/batch-status-aggregation.md` ✅ Complete

### 3. Quickstart

- Prerequisites checklist (existing pipeline, connector license)
- 8-step setup guide for building all new flows
- 4 test scenarios (single-form bypass, small batch, odd page rejection, status tracking)

**Output**: `quickstart.md` ✅ Complete

---

## Phase 2: Architecture & Implementation Strategy

### High-Level Architecture

```
VA Staff uploads batch PDF (e.g., 40 pages = 20 forms)
         ↓
SharePoint: FormIntake/Batches/Incoming/
         ↓
┌─────────────────────────────────────────────┐
│  FLOW 01: Batch PDF Splitter (NEW)          │
│                                             │
│  1. Validate (page count, size, dupe)       │
│  2. Create BatchSubmission record           │
│  3. Split PDF → 20 individual 2-page PDFs   │
│  4. Deposit each to FormIntake/ root        │
│     (5-second delay between deposits)       │
│  5. Retain original in batch subfolder      │
│  6. Log all events via Audit-Event-Logger   │
└──────────────────┬──────────────────────────┘
                   ↓ (20 individual PDFs in FormIntake/)
┌─────────────────────────────────────────────┐
│  EXISTING PIPELINE (unchanged)              │
│                                             │
│  Flow 1: Intake Trigger                     │
│    → Creates FormSubmission                 │
│    → Parses batch filename → sets BatchID   │
│                                             │
│  Flow 2: AI Builder Extraction              │
│    → Extracts form fields                   │
│    → Contact matching                       │
│    → Confidence routing                     │
│                                             │
│  Flow 3: Approval Workflow                  │
│    → Human correction (if needed)           │
│                                             │
│  Flow 4: D365 Write                         │
│    → Write to Dynamics 365                  │
└──────────────────┬──────────────────────────┘
                   ↓ (each form status change)
┌─────────────────────────────────────────────┐
│  FLOW 01B: Batch Status Updater (NEW)       │
│                                             │
│  Trigger: FormSubmission.Status changed     │
│  → Aggregate child statuses                 │
│  → Update BatchSubmission counters          │
│  → Detect completion / partial failure      │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│  FLOW 01C: Stale Batch Monitor (NEW)        │
│                                             │
│  Schedule: Every 1 hour                     │
│  → Query batches with no progress > 24h     │
│  → Alert supervisor via Notification-Router │
└─────────────────────────────────────────────┘
```

### Technology Stack Decisions

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| **PDF Splitting** | Azure Function (HTTP action) | No premium connector required; deployable to existing Azure subscription; full control over split logic |
| **PDF Page Count** | Azure Function (HTTP action) | Same endpoint family returns page count; consistent with split endpoint |
| **Orchestration** | Power Automate cloud flows (3 new flows) | Consistent with existing pipeline; low-code |
| **Batch Storage** | Dataverse (BatchSubmission table) | Native to Power Platform; relationships + audit |
| **File Storage** | SharePoint (FormIntake library) | Consistent with existing pipeline; folder-based isolation |
| **Status Aggregation** | Power Automate (trigger-based) | Real-time updates on FormSubmission changes |
| **Alerting** | Notification-Router subflow (existing) | Reuse existing notification infrastructure |
| **Duplicate Detection** | Dataverse query (filename + size + page count) | Simple; no custom code; Phase 1 sufficient |

### Implementation Strategy by User Story

| Story | Approach | Effort | Dependencies |
|-------|----------|--------|--------------|
| **US1 (Batch Detection)** | Flow 01 trigger + validation step; page count via Azure Function HTTP call; routing logic (2-page → Mode 1, even → split, odd → reject) | 2–3 hours | Azure Function app deployed |
| **US2 (PDF Splitting)** | Flow 01 split loop; Azure Function HTTP call with page ranges; save to batch subfolder; sequential deposit to FormIntake/ root | 3–4 hours | US1 complete; SharePoint folder structure |
| **US3 (Pipeline Feeding)** | Flow 01 file move step (batch subfolder → FormIntake/ root); Flow 1 conditional branch to parse batch filename and set BatchID | 2–3 hours | US2 complete; Flow 1 minor update |
| **US4 (Batch Tracking)** | BatchSubmission Dataverse table; Flow 01B status aggregation; terminal state detection | 3–4 hours | US1 complete; data-model.md schema |
| **US5 (Reporting/Audit)** | Power BI dashboard extension with batch metrics; AuditLog new ActionType values; stale batch monitor (Flow 01C) | 2–3 hours | US4 complete; Power BI access |
| **Total** | **Low-code configuration** | **~14–18 hours** | **1 person, 2–3 days** |

### Existing Flow Modification Summary

| Flow | Change | Impact |
|------|--------|--------|
| Flow 1 (Intake Trigger) | Add conditional: IF filename starts with "BATCH-" → parse BatchDisplayID + FormIndex → lookup BatchSubmission → set FormSubmission.BatchID + FormIndexInBatch | **Minimal** — single conditional branch at end of existing flow; does not affect Mode 1 processing |
| Flow 2 (Extraction) | None | No change |
| Flow 3 (Approval) | None | No change |
| Flow 4 (D365 Write) | None | No change |
| Audit-Event-Logger | None (reused with new ActionType values) | No change |
| Notification-Router | None (reused for batch alerts) | No change |

### Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Azure Function deployment failure | Low | High | Muhimbi PDF Connector as documented fallback; see [FLOW-01-AZURE-FUNCTION-RUNBOOK.md](implementation/FLOW-01-AZURE-FUNCTION-RUNBOOK.md) for deployment |
| Large batch exceeds connector timeout | Medium | Medium | 250-form Phase 1 limit; chunked processing for Phase 2 |
| Concurrent status updates cause race condition | Medium | Low | Dataverse optimistic concurrency + 3-retry backoff |
| Split PDFs not triggering Flow 1 | Low | High | SharePoint trigger polling is well-tested; verify with test batch before production |
| Pipeline backlog from large batch | Medium | Medium | 5-second deposit delay; monitor pipeline queue depth |

---

## Complexity Tracking

No constitution violations. Mode 2 follows the Simplicity & Incrementalism principle:

- **1 new Dataverse table** (BatchSubmission) + **2 columns** on existing table
- **3 new flows** (all low-code Power Automate)
- **0 existing flows modified** (except 1 conditional branch on Flow 1)
- **Minimal custom code** (Azure Function handles PDF operations — single-purpose, independently deployable)
- **0 new infrastructure** (reuses SharePoint, Dataverse, Power Automate)

---

## Next Steps

1. ✅ **Phase 0**: Research complete → `research.md`
2. ✅ **Phase 1**: Design complete → `data-model.md`, `contracts/`, `quickstart.md`
3. ⏭️ **Phase 2**: Generate `tasks.md` with implementation steps (via `/speckit.tasks`)
4. ⏭️ **Phase 3**: Execute tasks in sequence (1 person, 2–3 days)

---

**Version**: 1.0.0 | **Created**: 2025-07-17 | **Status**: Ready for Task Generation
