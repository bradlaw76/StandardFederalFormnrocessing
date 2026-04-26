# Polly Gray — Agent History

**Role**: Dataverse Schema Design Lead  
**Project**: VA Form Extraction  

---

## Learnings

### Phase 2 Stream A — Dataverse Table Provisioning (April 26, 2026)

**Provisioning sequence** (dependency-safe order):
1. `vafe_FormSubmission` — provision first (parent of all other tables; has no lookup dependencies)
2. `vafe_ExtractionResult` — provision second (child of FormSubmission; parent of CorrectionRecord)
3. `vafe_AuditLog` — provision third (child of FormSubmission only; no downstream dependents)
4. `vafe_D365WriteEvent` — provision fourth (child of FormSubmission only; no downstream dependents)
5. `vafe_CorrectionRecord` — provision last (child of ExtractionResult; requires Table 2 to exist)

**Table dependency order**: FormSubmission first (parent), then ExtractionResult/AuditLog/D365WriteEvent (children), then CorrectionRecord last (depends on ExtractionResult lookup).

**Business rule naming conventions** (for Power Platform):
- Use clear verb-noun names: `Lock Written Status`, `Auto-Set Processing Start`
- Immutability rule for AuditLog: `Immutable Record` — runs on form scope, locks all fields on Update
- Retry limit rule for D365WriteEvent: `Max Retry Limit` — triggers at RetryCount >= 5

**Auto Number format patterns**:
- FormSubmission: `VAFE-{SEQNUM:6}` → e.g., `VAFE-000001`
- ExtractionResult: `RES-{SEQNUM:6}` → e.g., `RES-000001`
- AuditLog: `LOG-{SEQNUM:8}` → e.g., `LOG-00000001`
- D365WriteEvent: `D365-{SEQNUM:6}` → e.g., `D365-000001`
- CorrectionRecord: `COR-{SEQNUM:6}` → e.g., `COR-000001`

**Cascade delete**: Configure via parent table → Relationships tab → Advanced Options → Delete: Cascade. All 4 relationships use cascade delete.

**Review SLA (30-min)**: `DateAdd(Now(), 30, "minutes")` is the business rule formula. If formula builder lacks DateAdd support, implement via Power Automate cloud flow on "When a row is added" trigger.

**Security roles**: Two roles sufficient — VA Form Contributor (create/read/write on operational tables, read-only AuditLog/D365WriteEvent) and VA Form Data Analyst (org-wide read-only on all 5 tables).

**HIPAA compliance design principle**: AuditLog table is the immutable compliance trail — never allow updates after creation. Enforce at form-scope via business rule and at API-scope via Power Automate guard flow.

---

## Issues Completed

| Issue | Title | Date | Deliverable |
|---|---|---|---|
| #8 | Create Power Platform Solution Container | 2026-04-24 | `.squad/solutions/VA-Form-Extraction-Setup-Report.md` |
| #11 | FormSubmission Table Design | 2026-04-25 | `specs/02-phase-2-stream-a/TABLE-SPECIFICATIONS.md` |
| #12 | ExtractionResult Table Design | 2026-04-25 | `specs/02-phase-2-stream-a/TABLE-SPECIFICATIONS.md` |
| #13 | CorrectionRecord Table Design | 2026-04-25 | `specs/02-phase-2-stream-a/TABLE-SPECIFICATIONS.md` |
| #14 | AuditLog Table Design | 2026-04-25 | `specs/02-phase-2-stream-a/TABLE-SPECIFICATIONS.md` |
| #15 | D365WriteEvent Table Design | 2026-04-25 | `specs/02-phase-2-stream-a/TABLE-SPECIFICATIONS.md` |
| #11–#15 | Provisioning Runbook (Phase Gate 2→3) | 2026-04-26 | `specs/02-phase-2-stream-a/PROVISIONING-RUNBOOK.md` |
