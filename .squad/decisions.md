# Squad Decisions

## Active Decisions

---

### D-001: Phase 1 Kickoff — Activate All Phase 1 Issues

**Author**: Coordinator  
**Date**: 2026-04-24  
**Status**: ✅ Implemented

Phase 1 activated. Issues #3–#10 assigned to team members (Arthur Shelby ×5, Alfie Solomons ×1, Polly Gray ×1, Michael Gray ×1). Phase 1 checkpoint to be reviewed by Tommy Shelby on completion. Phase 2 unlocks automatically after checkpoint passes.

---

### D-002: D365 Connector — OAuth2 with Service Account

**Author**: Alfie Solomons  
**Date**: 2026-04-24  
**Issue**: #6 — Configure Dynamics 365 Connector  
**Status**: ✅ Implemented

OAuth2 with service account (`d365.service.account@va-forms.onmicrosoft.com`, System Administrator role) chosen over connection strings (security risk) and app registration (unnecessary complexity for demo scope). Connection name: `VA-Form-D365-Prod`. Token refresh is automatic via Power Automate. Can migrate to app registration for production hardening.

---

### D-003: Power Platform Solution Container — VA-Form-Extraction

**Author**: Polly Gray  
**Date**: 2026-04-24  
**Issue**: #8 — Create Power Platform Solution Container  
**Status**: ✅ Implemented

Solution `VA-Form-Extraction` created as Managed Solution, publisher `VAFormExtraction_Publisher` (prefix: `vafe`), version 1.0.0.0. Solution ID: `3f7a9c2d-4e5b-11ed-bdc3-0242ac120002`. Ready for Phase 2 component addition.

---

### D-004: Dataverse Table Provisioning Order

**Author**: Polly Gray  
**Date**: 2026-04-26  
**Phase**: 2  
**Status**: ✅ Recorded

Provisioning order based on lookup field dependencies:
1. `vafe_FormSubmission` — no lookups, safe to create first
2. `vafe_ExtractionResult` — lookup → FormSubmission
3. `vafe_AuditLog` — lookup → FormSubmission
4. `vafe_D365WriteEvent` — lookup → FormSubmission
5. `vafe_CorrectionRecord` — lookup → ExtractionResult

Downstream flows creating CorrectionRecords must ensure an ExtractionResult exists first. Full runbook: `specs/02-phase-2-stream-a/PROVISIONING-RUNBOOK.md`.

---

### D-005: Grace Burgess QA Gate Before AI Model Training

**Author**: Michael Gray  
**Date**: 2026-04-26  
**Issues**: #16, #17  
**Status**: ✅ Recorded — Hard Gate

Grace Burgess (QA Lead) must complete and sign the quality checklist in `DATA-COLLECTION-RUNBOOK.md` Section 6 before any AI Builder training session is initiated. This is a **hard gate** — not optional. Applies to all future retraining cycles. Tommy Shelby is escalation point if Grace is unavailable. Rationale: training on un-validated data risks missing the ≥95% accuracy target; HIPAA compliance requires PII redaction confirmation; handwriting diversity must be human-verified.

---

### D-006: Power Automate Flow Build Order and Key Architecture Decisions

**Author**: John Shelby  
**Date**: 2026-04-26  
**Issue**: #18  
**Status**: ✅ Recorded

Required build order (prerequisite-driven):
1. `VA-Audit-Logger` (utility, no dependencies)
2. `VA-D365-Write-Subflow` (requires Dataverse tables + D365 connection)
3. `VA-Manual-Correction-Queue` (requires Dataverse + Teams + VA-D365-Write-Subflow)
4. `VA-D365-Retry-Logic` (scheduled every 5 min — NOT event-triggered, to avoid infinite loop on own writes)
5. `VA-Form-Intake-Pipeline` (requires all above + published AI Builder model)

Teams webhook URLs must be stored in Azure Key Vault, not hardcoded. Flow build blocked on Polly's tables and Michael's published model. Estimated build time: 2–3 business days. Runbook: `specs/03-phase-2-stream-b/FLOW-BUILD-RUNBOOK.md`.

---

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
