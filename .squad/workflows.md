# Squad Workflows — VA Form 10-3542 Extraction Pipeline

## Phase 1: Setup (2–3 hours)

**Goal**: Power Platform environment ready, all connections functional

**Lead**: Arthur Shelby  
**Support**: Tommy Shelby  
**Parallel**: Yes — all tasks can run in parallel

| Task | Owner | Subtasks | Gate |
|------|-------|----------|------|
| **Environment Initialization** | Arthur Shelby | T001: Create/verify PP environment | ✓ Verify tenant access |
| **SharePoint Setup** | Arthur Shelby | T002–T003: Create site + library | ✓ Forms library accessible |
| **D365 Connection** | Alfie Solomons | T004: Configure D365 connector | ✓ OAuth2 auth working |
| **Power Automate Quotas** | Arthur Shelby | T005: Verify connectors + quotas | ✓ AI Builder enabled, flow limits confirmed |
| **Solution Container** | Polly Gray | T006: Create `VA-Form-Extraction` solution | ✓ Solution visible in PP |
| **AI Builder Capacity** | Michael Gray | T007: Verify AI Builder license | ✓ Document quota available |
| **Entra ID Setup** | Arthur Shelby | T008: Configure VA staff auth | ✓ Test login succeeds |

**Checkpoint**: `squad status` shows Phase 1 complete; environment ready for Phase 2

---

## Phase 2: Foundational (6–8 hours)

**Goal**: Dataverse schema locked, AI model trained & published, shared flows in place

**Lead**: Polly Gray + John Shelby  
**Support**: Tommy Shelby, Grace Burgess  
**Parallel**: Yes — schema design and AI training can run in parallel; flows start after both are ready

### Parallel Stream A: Dataverse Schema

| Task | Owner | Dependencies | Gate |
|------|-------|--------------|------|
| **T009–T016** | Polly Gray | Phase 1 complete | Schema finalized, relationships locked |
| - Create tables (FormSubmission, ExtractionResult, CorrectionRecord, AuditLog, D365WriteEvent) | | | |
| - Configure relationships & constraints | | | |
| - Enable auditing & encryption | | | |
| **Design Review** | Tommy Shelby | Schema tasks complete | Approve schema for production use |

### Parallel Stream B: AI Builder Model

| Task | Owner | Dependencies | Gate |
|------|-------|--------------|------|
| **T017–T024** | Michael Gray | Phase 1 complete | Model published, version documented |
| - Collect/prepare 5 training forms | | | |
| - Create custom document model | | | |
| - Annotate fields + train | | | |
| - Test baseline accuracy | | | |
| - Publish to Dataverse | | | |
| **QA Validation** | Grace Burgess | Model published | Baseline accuracy ≥70% (5-form minimum) |

### Sequential Stream C: Shared Flows (starts after Streams A & B)

| Task | Owner | Dependencies | Gate |
|------|-------|--------------|------|
| **T025–T027** | John Shelby | Schema + Model complete | Flows ready for user story flows |
| - Create `Log-Audit-Event` flow | | | |
| - Create `Update-FormStatus` flow | | | |
| - Build error handling template | | | |

**Checkpoint**: `squad status Phase2` shows all foundational tasks complete; ready for user story implementation

---

## Phase 3: User Story 1 — Intake (2–3 hours)

**Goal**: VA staff can upload forms; system validates and queues for extraction

**Lead**: John Shelby  
**Support**: Grace Burgess  
**Parallel**: Intake flow development and test case creation run in parallel

| Task | Owner | Subtasks | Gate |
|------|-------|----------|------|
| **Flow Development** | John Shelby | T030–T036: Build intake trigger + validation + logging | ✓ Flow runs end-to-end |
| **Testing** | Grace Burgess | T037: Test happy path, error cases, duplicates | ✓ All test cases pass |
| **Acceptance** | Tommy Shelby | Review flow design, validate SOLID principles | ✓ Ready for US2 |

**Checkpoint**: 5 test forms upload successfully; duplicate detection works; errors logged to AuditLog

---

## Phase 4: User Story 2 — AI Extraction (3–4 hours)

**Goal**: AI extracts fields with confidence scores; high-confidence results route to D365 write; lower-confidence route to review

**Lead**: John Shelby  
**Support**: Michael Gray, Grace Burgess  
**Parallel**: Flow development and test preparation

| Task | Owner | Subtasks | Gate |
|------|-------|----------|------|
| **Flow Development** | John Shelby | T038–T045: Build extraction flow, contact matching, routing logic | ✓ Flow calls AI Builder successfully |
| **Contact Matching** | Polly Gray | T043: Implement contact matching algorithm | ✓ Contacts queried + matched correctly |
| **Testing** | Grace Burgess | T046: Test accuracy on 5 forms, verify confidence scores, validate routing | ✓ Accuracy ≥70%, routing correct |
| **Acceptance** | Tommy Shelby | Verify routing logic, error handling | ✓ Ready for US3 & US4 |

**Checkpoint**: All 5 forms extract successfully; confidence scores recorded; forms route to correct path (auto-approve vs. review)

---

## Phase 5: User Story 4 — D365 Write (2–3 hours)

**Goal**: Approved forms write to D365; audit trail maintained; retry logic handles failures

**Lead**: Alfie Solomons + John Shelby  
**Support**: Grace Burgess  
**Parallel**: D365 connector setup and flow development

| Task | Owner | Subtasks | Gate |
|------|-------|----------|------|
| **D365 Setup** | Alfie Solomons | T047–T048: Configure connector + field mapping | ✓ D365 connector callable |
| **Flow Development** | John Shelby | T049–T055: Build write flow, error handling, retry logic | ✓ Flow writes records successfully |
| **Testing** | Grace Burgess | T056–T057: Test success path, error scenarios, retry | ✓ All test cases pass; no write failures |
| **Acceptance** | Tommy Shelby | Verify audit trail, retry strategy, error handling | ✓ Ready for US3 |

**Checkpoint**: All 5 forms write to D365 with correct field values; audit log entries created; no unhandled errors

---

## Phase 6: User Story 3 — Human Review UI (4–5 hours)

**Goal**: VA staff can review & correct low-confidence fields; corrections logged; approval flows to D365 write

**Lead**: Lizzie Stark  
**Support**: Polly Gray, Grace Burgess  
**Parallel**: App development and test case design

| Task | Owner | Subtasks | Gate |
|------|-------|----------|------|
| **App Development** | Lizzie Stark | T058–T065: Build canvas app screens, validation, submission logic | ✓ App opens + pre-fills forms |
| **Validation Logic** | Polly Gray | T061–T062: Implement field validators (SSN format, dates, required fields) | ✓ Validation rules enforced |
| **Testing** | Grace Burgess | T066: Test corrections, validation errors, form submission | ✓ Corrections logged; status transitions correctly |
| **Acceptance** | Tommy Shelby | Review app UX, validation patterns, error handling | ✓ Ready for demo |

**Checkpoint**: Power Apps form renders; corrections save to CorrectionRecord; form transitions to "ReadyForD365"

---

## Phase 7: Polish & Demo Readiness (2–3 hours)

**Goal**: End-to-end demo ready; all 5 forms process successfully; metrics captured

**Lead**: Tommy Shelby  
**Support**: Grace Burgess, all team members

| Task | Owner | Subtasks | Gate |
|------|-------|----------|------|
| **End-to-End Testing** | Grace Burgess | 1 form through entire pipeline (intake → extraction → D365 write or review → correction → D365 write) | ✓ No failures |
| **Metrics & Logging** | Polly Gray | Verify accuracy baseline, confidence scores, audit trail complete | ✓ All metrics logged |
| **Performance Validation** | Tommy Shelby | Verify <5s extraction, <2s D365 write, latency targets met | ✓ Performance targets met |
| **Demo Script Prep** | Tommy Shelby | Document demo flow, key talking points, known limitations | ✓ Demo ready |

**Checkpoint**: Full pipeline demo succeeds; all acceptance criteria met; team ready for review/handoff

---

## Work Parallelization Strategy

### Parallel Execution Opportunities

1. **Phase 1**: All 8 tasks can run in parallel (different services, no dependencies)
2. **Phase 2**: 
   - Schema design (Stream A) ↔ AI model training (Stream B) in parallel
   - Shared flows (Stream C) start after both A & B complete
3. **Phase 3–6**: Each phase has lead task + support tasks that can run in parallel:
   - Flow development ↔ test case preparation
   - Design review ↔ acceptance testing

### Sequential Handoff Gates

- Phase 1 → Phase 2: Verify environment access
- Phase 2 → Phase 3: Verify schema + model ready
- Phase 3 → Phase 4: Verify intake flow working
- Phase 4 → Phase 5: Verify extraction results queued
- Phase 5 → Phase 6: Verify D365 writes successful
- Phase 6 → Phase 7: Verify all components integrated

---

## Automation with `squad loop` (Ralph Mode)

To automate this workflow with Squad's continuous work loop:

```bash
# Start Ralph mode — watches GitHub issues with squad labels, assigns to team members
squad loop --filter "label:squad"

# Or run once for status:
squad status
```

This enables:
- Automatic issue triaging to team members
- Parallel task execution tracking
- Blocker detection (missing handoff gate items)
- Automated phase progression (when gate checklist clears)

---

## Decision Log

| Decision | Rationale | Team Approval |
|----------|-----------|---------------|
| Power Platform stack | Low-code/no-code aligns with demo scope; reduces custom development time | ✅ Tommy Shelby |
| 5-form training dataset | Minimal viable training data for AI Builder POC; expandable to production | ✅ Michael Gray |
| Dataverse as primary storage | Native to Power Platform; built-in audit; simplified D365 sync | ✅ Polly Gray |
| Manual testing Phase 2 | Demo scope allows manual validation; automate if scaling to production | ✅ Grace Burgess |
| Phase-based gates | Ensures foundational work complete before user stories; reduces rework | ✅ Tommy Shelby |

---

## Contact & Escalation

- **Phase Lead Issues**: Escalate to Tommy Shelby
- **Technical Blockers**: Ping Arthur Shelby (infrastructure) or John Shelby (flows)
- **Design Questions**: Review board = Tommy Shelby + relevant domain lead
- **Demo Readiness**: Contact Tommy Shelby 24h before demo
