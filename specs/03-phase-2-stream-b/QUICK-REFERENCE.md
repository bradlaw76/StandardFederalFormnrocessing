# Phase 2 Stream B-1: Quick Reference Guide
**AI Model Training Data Strategy → Execution Handoff**

**For**: Michael Gray (next execution phase) & John Shelby (flow integration)  
**Date**: 2026-04-25  
**Status**: Ready for Phase Gate Approval & Execution

---

## Quick Links

**Strategy Documents** (COMPLETE & READY):
- [DATA-COLLECTION-STRATEGY.md](./DATA-COLLECTION-STRATEGY.md) — Issue #16 (data prep)
- [MODEL-TRAINING-STRATEGY.md](./MODEL-TRAINING-STRATEGY.md) — Issue #17 (model training)
- [MICHAEL-GRAY-STREAM-B-SUMMARY.md](./MICHAEL-GRAY-STREAM-B-SUMMARY.md) — Handoff summary

**Team Coordination** (Dependencies & Handoffs):
- [Polly Gray — Stream A COMPLETE](../02-phase-2-stream-a/STREAM-A-COMPLETION-SUMMARY.md) → Dataverse schema ready
- [John Shelby — Stream B Issue #18](#todo) → Waiting for model availability

---

## Key Specs at a Glance

### Data Collection (Issue #16)

| Spec | Value |
|------|-------|
| **Sample Size** | 40–50 VA Form 10-3542s |
| **Train / Val / Test** | 70% / 15% / 15% (28 / 6 / 6 forms) |
| **Image Format** | PNG/JPEG, 300 DPI minimum |
| **Coverage** | Handwriting, ink colors, paper conditions, form variations |
| **Anonymization** | All PII masked (HIPAA §45 CFR §164.512k) |
| **Storage** | Azure Blob: `FormIntake/TrainingDataset/` |
| **Timeline** | ~5 days |

**Fields to Extract** (32–40 fields):
```
Section A (7): claimant_full_name, claimant_dob, claimant_ssn, 
               claimant_phone, claimant_address_*, claimant_email
Section B (8): veteran_full_name, veteran_dob, veteran_dod, 
               veteran_ssn, veteran_service_number, veteran_service_branch,
               veteran_rank_or_rate, veteran_discharge_status
Section C (6): claimant_relationship_to_veteran, marital_status_at_death,
               marriage_date, has_dependent_children, 
               number_of_dependents, is_eligible_for_benefits
Section D (5): service_start_date, service_end_date, years_of_service,
               deployment_dates, combat_status
Section E (6): signature_present, signature_date, notarized,
               notary_name, notary_date, form_version
```

---

### Model Training (Issue #17)

| Spec | Value |
|------|-------|
| **Platform** | Microsoft AI Builder (custom document processing) |
| **Model Name** | `VAForm10-3542-Extractor` |
| **Accuracy Target** | ≥95% field extraction |
| **Processing Time** | <5 seconds per form |
| **Confidence Thresholds** | 0.95+ accept, 0.85–0.94 review, <0.60 reject |
| **Retraining** | Monthly or if accuracy <92% |
| **Timeline** | ~9–10 days total (data prep → published model) |

**Confidence Score Logic**:
```json
{
  "extracted_fields": { "field_name": "value", ... },
  "field_confidence_scores": { "field_name": 0.95, ... },
  "ai_model_version": "VAForm10-3542-Extractor-v1.0"
}

Decision Logic in Power Automate:
IF confidence >= 0.85 → Accept & auto-write
IF confidence >= 0.60 AND < 0.85 → Flag for manual review
IF confidence < 0.60 → Reject & escalate
```

---

## Execution Timeline

### Phase 2 Gate → Go (May 1)
1. **Tommy Shelby**: Approve strategy documents
2. **Michael Gray**: Start Issue #16 (data collection)

### Issue #16: Data Collection (May 1–3)
1. Collect 40–50 VA Form 10-3542 samples
2. Anonymize all PII
3. Create 70/15/15 split
4. Generate JSON label files (32–40 fields per form)
5. Upload to Blob Storage (FormIntake/TrainingDataset/)
6. Quality validation: >95% accuracy, >0.90 avg confidence

### Issue #17: Model Training (May 2–5)
1. Upload training data to AI Builder
2. Configure 32–40 field extraction targets
3. Run training (AI Builder automated, ~15–30 min)
4. Evaluate accuracy (target: ≥95%)
5. Publish model: `VAForm10-3542-Extractor-v1.0`

### Issue #18: Flow Integration (May 3–5)
1. **John Shelby**: Integrate model into Power Automate flows
2. Create "Extract Fields" shared action
3. Map output to Dataverse ExtractionResult table
4. Error handling: Low-confidence → manual review
5. End-to-end testing

### Deployment (May 5+)
1. Full end-to-end testing (Intake → Extraction → D365 Write)
2. Production rollout
3. Monitor accuracy (monthly reports)

---

## Dataverse Integration

**ExtractionResult Table** (Polly Gray — Stream A, Issue #12):

```json
{
  "result_id": "UUID",
  "form_submission_id": "form-UUID",
  "extracted_fields": {
    "claimant_full_name": "REDACTED",
    "claimant_dob": "**/**/****",
    "veteran_service_branch": "Army",
    ...
  },
  "field_confidence_scores": {
    "claimant_full_name": 0.98,
    "claimant_dob": 0.87,
    "veteran_service_branch": 0.99,
    ...
  },
  "ai_model_version": "VAForm10-3542-Extractor-v1.0",
  "status": "Pending"  // User updates after review
}
```

**API Names** (from Polly's schema):
- `vafe_formsubmission` — Parent form
- `vafe_extractionresult` — AI extraction output
- `vafe_field_confidence_scores` — Confidence JSON field

---

## For John Shelby (Issue #18 Flow Architecture)

**Model Output Format**:
```
AI Builder Action: "Invoke Document Processing Model"
Input: form_image (from SharePoint FormIntake)
Output:
  ├─ extracted_fields (JSON with 32–40 field values)
  ├─ field_confidence_scores (JSON with confidence 0.0–1.0)
  └─ processing_time (<5 sec)
```

**Flow Logic Template**:
```
IF model_confidence >= 0.85:
  → Write extracted_fields to ExtractionResult (Dataverse)
  → Set status = "Pending"
  → Queue for D365 write

IF model_confidence >= 0.60 AND < 0.85:
  → Write to ExtractionResult with status = "PendingReview"
  → Notify reviewer (Dataverse row sharing)
  → Wait for manual correction

IF model_confidence < 0.60:
  → Write to ExtractionResult with status = "Failed"
  → Log error
  → Send escalation notification
```

---

## Checklists

### Pre-Execution (Tommy Shelby Phase Gate)

- [ ] Both strategies reviewed & approved
- [ ] No major concerns or blockers
- [ ] Data collection can proceed (Issue #16)
- [ ] Model training strategy approved (Issue #17)
- [ ] Flow architecture can begin (Issue #18)
- [ ] Dependencies confirmed with Polly & John

### Issue #16 Acceptance

- [ ] 40–50 VA Form 10-3542 samples collected
- [ ] All PII anonymized (regex + manual audit, 0 violations)
- [ ] 70% training (28), 15% validation (6), 15% test (6)
- [ ] JSON labels for all forms (32–40 fields per form)
- [ ] Avg confidence >0.90
- [ ] Image quality: 100% ≥300 DPI
- [ ] TrainingDataset uploaded to Blob Storage
- [ ] Grace Burgess (QA) sign-off

### Issue #17 Acceptance

- [ ] Model imported & configured in AI Builder
- [ ] 32–40 fields defined with types & validation
- [ ] Model training completed (15–30 min)
- [ ] Accuracy ≥95% on test set (6 forms)
- [ ] Edge cases validated (handwriting, smudges, incomplete)
- [ ] Processing time <5 sec per form
- [ ] Model published: `VAForm10-3542-Extractor-v1.0`
- [ ] Tommy Shelby approval

### Issue #18 Readiness

- [ ] AI Builder model available for use
- [ ] Power Automate action: "Invoke Document Processing Model"
- [ ] Shared action created for reusability
- [ ] JSON output structure documented
- [ ] Error handling for low-confidence fields
- [ ] Confidence thresholds (0.95, 0.85, 0.60) configured

---

## Support & Escalation

| Issue | Contact | Severity |
|-------|---------|----------|
| Strategy questions | Tommy Shelby (Lead) | High |
| Data collection blockers | Michael Gray | High |
| Model training issues | Michael Gray + Grace Burgess (QA) | High |
| Flow integration questions | John Shelby | Medium |
| Dataverse schema issues | Polly Gray | High |
| Escalation | Tommy Shelby | Critical |

---

## Reference Documents

**Within This Directory**:
- [DATA-COLLECTION-STRATEGY.md](./DATA-COLLECTION-STRATEGY.md)
- [MODEL-TRAINING-STRATEGY.md](./MODEL-TRAINING-STRATEGY.md)
- [MICHAEL-GRAY-STREAM-B-SUMMARY.md](./MICHAEL-GRAY-STREAM-B-SUMMARY.md)

**Related (Stream A — Polly Gray)**:
- [TABLE-SPECIFICATIONS.md](../02-phase-2-stream-a/TABLE-SPECIFICATIONS.md)
- [SCHEMA-DIAGRAM.md](../02-phase-2-stream-a/SCHEMA-DIAGRAM.md)

**External Resources**:
- AI Builder Docs: https://docs.microsoft.com/power-platform/ai-builder/
- Power Automate: https://docs.microsoft.com/power-automate/

---

**Ready for Execution**: ✅ YES (Awaiting Phase Gate Approval)  
**Last Updated**: 2026-04-25  
**Next Review**: Upon Phase 2 Gate checkpoint (Tommy Shelby approval)
