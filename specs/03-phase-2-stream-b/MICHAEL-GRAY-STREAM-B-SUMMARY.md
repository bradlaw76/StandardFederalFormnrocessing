# Phase 2 Stream B-1: AI Model Training Strategy — Michael Gray
**Issue #16 & #17 Completion Summary**

**Owner**: Michael Gray (AI & ML Strategy Lead)  
**Phase**: 2 — Foundational (Data & ML)  
**Status**: ✅ STRATEGY COMPLETE  
**Completion Date**: 2026-04-25  
**Next Phase**: Data collection execution (#16) → Model training (#17) → Flow deployment (John Shelby #18)

---

## Overview

Completed comprehensive AI model training strategy for VA Form 10-3542 field extraction using Microsoft AI Builder. Strategy enables >95% field extraction accuracy within 9–10 days, feeding John Shelby's Power Automate flow architecture work.

---

## Issues & Deliverables

### Issue #16: Prepare AI Training Data — Collect Sample VA Forms

**Status**: 📋 Strategy Documented  
**Deliverable**: [DATA-COLLECTION-STRATEGY.md](./DATA-COLLECTION-STRATEGY.md)

**What It Covers**:
- ✅ Data source analysis (form type, collection methods, diversity requirements)
- ✅ Field inventory (32–40 core fields from VA Form 10-3542)
- ✅ Training data format (40–50 samples, 70/15/15 train/val/test split)
- ✅ Image specifications (300 DPI PNG/JPEG, preprocessing pipeline)
- ✅ JSON annotation format (per-form label files with confidence scores)
- ✅ Anonymization & PII masking (HIPAA-compliant)
- ✅ Quality assurance metrics & edge case handling
- ✅ Storage & access control (Azure Blob + SharePoint)
- ✅ Data lifecycle management (collection → training → archive)

**Key Specifications**:
- **Sample Size**: 40–50 labeled forms (minimum for production accuracy)
- **Coverage**: Diverse handwriting, ink colors, paper conditions, form variations
- **Quality Target**: 300 DPI min, <5% OCR error rate, >95% field accuracy
- **Anonymization**: All PII masked (names, SSN, DOB, email, address)
- **Timeline**: ~5 days (collection → annotation → validation)

**Acceptance Criteria**:
- [ ] 40–50 VA Form 10-3542 samples collected & anonymized
- [ ] 70/15/15 train/val/test split created
- [ ] JSON label files with 32–40 fields per form
- [ ] Average confidence score >0.90
- [ ] Anonymization audit passed (0 PII)
- [ ] TrainingDataset folder uploaded to Blob Storage

---

### Issue #17: Design AI Model Training Strategy

**Status**: 📋 Strategy Documented  
**Deliverable**: [MODEL-TRAINING-STRATEGY.md](./MODEL-TRAINING-STRATEGY.md)

**What It Covers**:
- ✅ Platform selection (AI Builder justified vs. alternatives)
- ✅ Training data requirements (40–50 forms, field extraction targets)
- ✅ Training workflow pipeline (6 phases: data prep → model import → training → eval → deployment → monitoring)
- ✅ Model configuration (32–40 field definitions, field types, validation rules)
- ✅ Confidence threshold calibration (0.95–1.0 accept, 0.85–0.94 review, <0.60 reject)
- ✅ Accuracy metrics & measurement methodology
- ✅ Monthly monitoring & retraining procedure
- ✅ Deployment readiness checklist
- ✅ Success criteria & KPIs

**Key Specifications**:
- **Platform**: Microsoft AI Builder (custom document processing model)
- **Model Name**: `VAForm10-3542-Extractor`
- **Accuracy Target**: ≥95% field extraction
- **Processing Time**: <5 seconds per form
- **Confidence Scoring**: 0.0–1.0 (0.95+ = excellent, <0.60 = reject)
- **Retraining**: Monthly or if accuracy drops below 92%
- **Timeline**: ~9–10 days (data prep → published model)

**Acceptance Criteria**:
- [ ] Platform selected & justified (AI Builder)
- [ ] Training workflow documented (6 phases)
- [ ] Field extraction targets defined (32–40 fields)
- [ ] Confidence thresholds configured
- [ ] Accuracy targets set (≥95%)
- [ ] Deployment checklist created
- [ ] Monthly monitoring schedule established

---

## Coordination & Dependencies

### Depends On: Polly Gray (Issue #12 — ExtractionResult Table)
- ✅ Dataverse table schema ready for AI model output
- ✅ `extracted_fields` JSON field available
- ✅ `field_confidence_scores` JSON field available
- ✅ API names standardized (`vafe_` prefix)

**Alignment Verified**:
```json
AI Builder Output → ExtractionResult Table
{
  "extracted_fields": {...}          → vafe_extractionresult.extracted_fields
  "field_confidence_scores": {...}   → vafe_extractionresult.field_confidence_scores
  "ai_model_version": "v1.0"         → vafe_extractionresult.ai_model_version
}
```

### Feeds Into: John Shelby (Issue #18 — Flow Architecture)
- ✅ Model name & availability documented
- ✅ Input/output formats specified
- ✅ Confidence thresholds for flow logic (0.95, 0.85, 0.60)
- ✅ Processing time SLA (<5 sec)
- ✅ Error handling strategy (low-confidence → manual review)

**Handoff to John**:
```
1. AI Builder action: "Invoke Document Processing Model"
2. Model: VAForm10-3542-Extractor
3. Input: Form image (from SharePoint FormIntake)
4. Output: extracted_fields + field_confidence_scores JSON
5. Error logic: If confidence < 0.85, flag for manual review
```

---

## Key Design Decisions

### Decision 1: AI Builder (vs. Document Intelligence / Custom Code)
**Rationale**:
- ✅ Native Power Platform integration (flows call model directly)
- ✅ Low-code (no developer expertise required)
- ✅ Fast training (15–30 min vs. 2–4 hours for custom ML)
- ✅ HIPAA/FedRAMP eligible
- ✅ No per-prediction cost (included in Power Platform licensing)
- ✅ Audit logging built-in

### Decision 2: 40–50 Sample Minimum
**Rationale**:
- ✅ AI Builder typically achieves >90% accuracy with 20–30 samples
- ✅ 40–50 samples ensures >95% accuracy target + edge case coverage
- ✅ Balanced: Sufficient for accuracy without excessive collection effort
- ✅ Enables 70/15/15 split with meaningful test set (6 forms)

### Decision 3: Confidence Threshold Strategy (0.95 / 0.85 / 0.60)
**Rationale**:
- ✅ 0.95+ : Excellent OCR confidence, accept without review
- ✅ 0.85–0.94 : Good confidence, review if needed (balance automation/safety)
- ✅ 0.60–0.84 : Fair/low confidence, recommend manual review (safety margin)
- ✅ <0.60 : Very low, reject extraction (high error probability)

### Decision 4: Monthly Monitoring & Retraining
**Rationale**:
- ✅ Detects data drift (new form variations, handwriting changes)
- ✅ Continuous improvement (accuracy typically improves with more data)
- ✅ Early warning if model accuracy degrades
- ✅ Quarterly baseline: Reestablish accuracy standard

---

## Deliverable Files

| Document | Location | Status | Purpose |
|----------|----------|--------|---------|
| **DATA-COLLECTION-STRATEGY.md** | `specs/03-phase-2-stream-b/` | ✅ Complete | Issue #16: Training data prep strategy |
| **MODEL-TRAINING-STRATEGY.md** | `specs/03-phase-2-stream-b/` | ✅ Complete | Issue #17: AI model training approach |
| **MICHAEL-GRAY-STREAM-B-SUMMARY.md** | `specs/03-phase-2-stream-b/` | ✅ This File | Stream B-1 handoff summary |

---

## Next Steps

### Immediate (Week 1 — May 1–3)
1. **Approval**: Tommy Shelby reviews both strategies
2. **Data Collection** (Issue #16): Michael Gray collects & annotates 40–50 forms
3. **Quality Validation**: Michael + Grace Burgess validate dataset

### Week 2 (May 3–5)
4. **Model Training** (Issue #17): Upload to AI Builder, train model
5. **Model Testing**: Evaluate accuracy, iterate if needed
6. **Model Publishing**: Publish VAForm10-3542-Extractor v1.0

### Week 3 (May 5–7)
7. **Flow Integration** (Issue #18): John Shelby integrates model into flows
8. **End-to-End Testing**: Test complete Intake → Extraction → D365 Write pipeline
9. **Deployment**: Roll out to production flows

### Ongoing
10. **Monthly Monitoring**: Michael Gray tracks accuracy, triggers retraining if needed
11. **Quarterly Review**: Tommy Shelby reviews model performance & accuracy trends

---

## Quality Assurance

### Validation Checklist (Pre-Deployment)

✅ **Data Quality** (Issue #16)
- [ ] 40+ samples collected
- [ ] 70/15/15 split verified
- [ ] All PII anonymized (regex scan + manual audit)
- [ ] Image quality: 100% ≥300 DPI
- [ ] Avg field confidence >0.90
- [ ] JSON labels match field definitions

✅ **Model Training** (Issue #17)
- [ ] Training completed without errors
- [ ] Accuracy ≥95% on test set
- [ ] Edge cases validated (handwriting, smudges, incomplete)
- [ ] Confidence scores calibrated
- [ ] Processing time <5 sec per form

✅ **Integration** (Flow Architecture Readiness)
- [ ] ExtractionResult table schema aligned
- [ ] JSON output format matches Dataverse
- [ ] Power Automate action available in AI Builder
- [ ] Error handling for low-confidence fields
- [ ] Shared action created for reusability

✅ **Documentation** (This File)
- [ ] Training strategy documented (>2,500 words)
- [ ] Field extraction targets listed (32–40 fields)
- [ ] Confidence thresholds specified (0.95, 0.85, 0.60)
- [ ] Deployment checklist created
- [ ] Monthly monitoring procedure defined
- [ ] Risk mitigation strategies documented

---

## KPIs & Success Metrics

| KPI | Target | Current | Status |
|-----|--------|---------|--------|
| **Strategy Completeness** | 100% | 100% | ✅ Complete |
| **Field Extraction Targets** | 32–40 fields | 40 fields | ✅ Defined |
| **Accuracy Target** | ≥95% | TBD (after training) | 🟡 In Progress |
| **Processing Time** | <5 sec/form | TBD (after training) | 🟡 In Progress |
| **Avg Confidence Score** | ≥0.90 | TBD (after training) | 🟡 In Progress |
| **Phase 2 Gate** | Ready for handoff | 90% ready | 🟡 1 approval pending |

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **Low accuracy (<90%)** | Medium | High | Oversample edge cases; iterate training cycles |
| **Data quality issues** | Medium | High | Validation checklist in Issue #16; preprocessing pipeline |
| **PII leakage** | Low | Critical | Regex + manual anonymization audit before release |
| **Model doesn't generalize** | Low | Medium | Cover all variation factors in training; monthly retraining |
| **Processing time >5 sec** | Low | Medium | Monitor during QA testing; optimize if needed |
| **Form variation not covered** | Medium | Low | Monthly retraining includes new variations |

---

## Team Assignments

| Role | Responsibility | Status |
|------|-----------------|--------|
| **Michael Gray** | Strategy owner, data collection, model training, monitoring | 🟢 Active |
| **Grace Burgess (QA)** | Data validation, accuracy testing, edge cases | 🟡 Standby (ready for #16–17) |
| **John Shelby** | Flow integration (Issue #18), uses model output | 🟡 Standby (ready for handoff) |
| **Polly Gray** | Schema owner (ExtractionResult table), JSON alignment | ✅ Complete |
| **Tommy Shelby** | Phase gate approval, oversight | ⏳ Pending review |

---

## Handoff to Phase Gate

**Ready for Approval**: ✅ 90% Ready  
**Awaiting**: Tommy Shelby phase gate review

**Phase Gate Criteria**:
- [ ] Both strategy documents reviewed
- [ ] No major concerns identified
- [ ] Data collection can proceed (Issue #16)
- [ ] Model training strategy approved (Issue #17)
- [ ] Flow architecture can begin (Issue #18 — John Shelby)

**Expected Approval Date**: May 2, 2026

---

## References

**Related Work**:
- [DATA-COLLECTION-STRATEGY.md](./DATA-COLLECTION-STRATEGY.md) — Issue #16
- [MODEL-TRAINING-STRATEGY.md](./MODEL-TRAINING-STRATEGY.md) — Issue #17
- [STREAM-A-COMPLETION-SUMMARY.md](../02-phase-2-stream-a/STREAM-A-COMPLETION-SUMMARY.md) — Polly Gray
- [HANDOFF-FOR-TOMMY-AND-JOHN.md](../02-phase-2-stream-a/HANDOFF-FOR-TOMMY-AND-JOHN.md) — Phase gate review

**External Resources**:
- AI Builder documentation: https://docs.microsoft.com/power-platform/ai-builder/
- Power Automate: https://docs.microsoft.com/power-automate/

---

## Sign-Off

| Role | Name | Date | Status |
|------|------|------|--------|
| **Author** | Michael Gray | 2026-04-25 | ✅ Complete |
| **QA Review** | Grace Burgess | — | ⏳ Pending |
| **Phase Gate** | Tommy Shelby | — | ⏳ Pending |

**Current Status**: 📋 **AWAITING PHASE GATE APPROVAL**

---

**Created by**: Michael Gray, AI & ML Strategy Lead  
**Date**: 2026-04-25  
**Next Milestone**: Phase 2 Gate Checkpoint (Tommy Shelby approval)
