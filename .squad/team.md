# Squad Team

> StandardFederalFormnrocessing

## Coordinator

| Name | Role | Notes |
|------|------|-------|
| Squad | Coordinator | Routes work, enforces handoffs and reviewer gates. |

## Members

| Name | Role | Charter | Status |
|------|------|---------|--------|
| Arthur Shelby | Environment & Infrastructure | Create Power Platform environment, manage connections, provision SharePoint, D365 setup | Active |
| Polly Gray | Dataverse Schema Design | Create FormSubmission, ExtractionResult, CorrectionRecord, AuditLog, D365WriteEvent tables; relationships & constraints | Active |
| John Shelby | Flow Orchestration | Build intake trigger, AI extraction, D365 write, retry logic, shared actions/flows | Active |
| Lizzie Stark | Correction UI | Create canvas app for field review/correction, validation, error handling | Active |
| Michael Gray | Model Training & Tuning | Collect training data, train custom document model, test accuracy, publish to Dataverse | Active |
| Alfie Solomons | Dynamics Integration | Configure D365 connector, map fields to VA_FormSubmission table, test write operations | Active |
| Grace Burgess | Quality Assurance | End-to-end testing, accuracy metrics, error scenarios, compliance audit trail validation | Active |
| Tommy Shelby | Oversight & Design | Review architecture, ensure SOLID principles, performance targets (5s extraction, <2s D365 write), Phase gates | Active |


## Coding Agent

<!-- copilot-auto-assign: true -->

| Name | Role | Charter | Status |
|------|------|---------|--------|
| @copilot | Coding Agent | — | 🤖 Coding Agent |

### Capabilities

**🟢 Good fit — auto-route when enabled:**
- Bug fixes with clear reproduction steps
- Test coverage (adding missing tests, fixing flaky tests)
- Lint/format fixes and code style cleanup
- Dependency updates and version bumps
- Small isolated features with clear specs
- Boilerplate/scaffolding generation
- Documentation fixes and README updates

**🟡 Needs review — route to @copilot but flag for squad member PR review:**
- Medium features with clear specs and acceptance criteria
- Refactoring with existing test coverage
- API endpoint additions following established patterns
- Migration scripts with well-defined schemas

**🔴 Not suitable — route to squad member instead:**
- Architecture decisions and system design
- Multi-system integration requiring coordination
- Ambiguous requirements needing clarification
- Security-critical changes (auth, encryption, access control)
- Performance-critical paths requiring benchmarking
- Changes requiring cross-team discussion

## Project Context

- **Project:** StandardFederalFormnrocessing
- **Platform:** Microsoft Power Platform (Power Automate, Dataverse, Power Apps, AI Builder, Dynamics 365)
- **Feature:** VA Form 10-3542 Extraction Pipeline
- **Status:** Phase 1 (Setup) — Team assembled, environment initialization in progress
- **Created:** 2026-04-24

## Key Milestones

- **Phase 1 (Setup)**: 2–3 hours — Environment, connections, infrastructure ready
- **Phase 2 (Foundational)**: 6–8 hours — Dataverse schema, AI model trained, shared flows
- **Phase 3–5 (User Stories)**: 12–15 hours — Intake, extraction, review UI, D365 write
- **Demo Scope**: 5 VA forms, baseline accuracy logging, audit trail

## Handoff Gates

1. **Setup → Foundational**: Verify environment accessible, all connectors enabled, Power Automate/AI Builder quotas confirmed
2. **Foundational → User Stories**: Verify Dataverse schema locked, AI model published, shared flows in place
3. **User Stories → Polish**: Verify all 5 forms process end-to-end, accuracy metrics logged, compliance audit trail validated
4. **Ready for Demo**: All user stories passing, performance targets met, error handling tested
