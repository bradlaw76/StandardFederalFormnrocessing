# Michael Gray — Squad Agent History

**Role**: AI & ML Strategy Lead  
**Team**: StandardFederalFormnrocessing (VA Form Extraction Pipeline)  
**Status**: Active  
**Last Updated**: 2026-04-25

---

## Role Summary

**Responsibilities**:
- Design AI model training data collection & preparation strategy
- Define data requirements, format, and quality standards
- Coordinate with form intake pipeline (Issue #16–#17)
- Manage AI model training, evaluation, and deployment
- Monthly monitoring & retraining of production models
- Support flow architecture integration (coordinate with John Shelby #18)

**Capability Profile** 🟢 **Good Fit**:
- AI/ML strategy design (custom document processing)
- Training data preparation & annotation
- Model evaluation & accuracy metrics
- HIPAA/compliance requirements
- Power Platform AI Builder expertise

---

## Phase 2 Stream B-1 (Issues #16–#17)

### Issue #16: Prepare AI Training Data — Collect Sample VA Forms

**Status**: 📋 Strategy Complete → Ready for Execution  
**Deliverable**: `DATA-COLLECTION-STRATEGY.md`

**Summary**:
- Defined data collection strategy for 40–50 VA Form 10-3542 samples
- Specified field extraction targets (32–40 fields)
- Training data format: 70% train / 15% val / 15% test split
- Image specs: 300 DPI PNG/JPEG, anonymized (HIPAA compliant)
- Quality assurance: >95% field accuracy, >0.90 avg confidence
- Storage: Azure Blob (FormIntake/TrainingDataset)
- Timeline: ~5 days

**Acceptance Criteria** (Ready for Execution):
- ✅ Data source analysis documented
- ✅ Field inventory specified (32–40 fields)
- ✅ Training format defined (40–50 samples, 70/15/15 split)
- ✅ Quality metrics established
- ✅ Anonymization checklist created
- ✅ Storage & access control configured

### Issue #17: Design AI Model Training Strategy

**Status**: 📋 Strategy Complete → Ready for Execution  
**Deliverable**: `MODEL-TRAINING-STRATEGY.md`

**Summary**:
- Selected Microsoft AI Builder (custom document processing model)
- Model name: `VAForm10-3542-Extractor`
- Accuracy target: ≥95% field extraction
- Processing time: <5 seconds per form
- Confidence thresholds: 0.95 (accept), 0.85 (review), 0.60 (reject)
- Training workflow: 6 phases (data prep → model import → training → eval → deploy → monitor)
- Retraining schedule: Monthly or if accuracy <92%
- Timeline: ~9–10 days (data prep → published model)

**Acceptance Criteria** (Ready for Execution):
- ✅ Platform selected & justified (AI Builder)
- ✅ Training workflow documented (6 phases)
- ✅ Field extraction targets defined (32–40 fields)
- ✅ Confidence thresholds configured
- ✅ Accuracy targets set (≥95%)
- ✅ Deployment checklist created
- ✅ Monthly monitoring procedure defined

---

## Coordination Map

### Upstream Dependency: Polly Gray (Stream A — Issue #12)
**ExtractionResult Table Schema**
- ✅ ALIGNED: JSON fields for extracted_fields & field_confidence_scores
- ✅ READY: API names standardized with `vafe_` prefix
- ✅ Handoff Status: Polly's Stream A complete (issues #11–15)

### Parallel Coordination: John Shelby (Stream B — Issue #18)
**Flow Architecture Design**
- 📋 Handoff Status: Ready for handoff
- 📋 Model Name: `VAForm10-3542-Extractor`
- 📋 Input: Form image (SharePoint FormIntake)
- 📋 Output: `extracted_fields` + `field_confidence_scores` JSON
- 📋 Confidence Logic: 0.95+ accept, 0.85–0.94 review, <0.60 reject
- 📋 Timeline: Data ready by May 1 → John can design flows May 1–5

### QA Partner: Grace Burgess
**Data Validation & Model Testing**
- 📋 Validate Issue #16 dataset (quality metrics, anonymization)
- 📋 Test Issue #17 model accuracy (edge cases, confidence calibration)
- 📋 Baseline metrics: >95% accuracy, >0.90 avg confidence

### Team Lead: Tommy Shelby
**Phase Gate & Oversight**
- ⏳ Phase Gate Approval: Awaiting review of both strategies
- ⏳ Checkpoint: Verify strategy completeness before execution
- ⏳ Escalation: Contact if accuracy <90% or blockers arise

---

## Work Completed This Session

### Documents Created (2026-04-25)

1. **DATA-COLLECTION-STRATEGY.md** (Issue #16)
   - 10 sections, >2,500 words
   - Data source analysis, field inventory, format specs
   - Quality assurance, anonymization, storage & lifecycle
   - Acceptance criteria & success metrics

2. **MODEL-TRAINING-STRATEGY.md** (Issue #17)
   - 11 sections, >3,000 words
   - Platform selection, training workflow, model config
   - Accuracy metrics, monitoring, retraining procedure
   - Deployment checklist & success criteria

3. **MICHAEL-GRAY-STREAM-B-SUMMARY.md** (Handoff Summary)
   - 6 sections, ~1,200 words
   - Overview of both issues, key decisions, team assignments
   - Next steps, quality assurance, phase gate readiness

4. **michael-gray/history.md** (This File)
   - Squad agent history & coordination map
   - Phase 2 progress tracking

### Key Decisions Made

**Decision 1**: AI Builder (over Document Intelligence)
- Rationale: Native Power Platform, low-code, fast training, HIPAA-compliant, no per-prediction cost
- Impact: Enables non-technical team to build & maintain models

**Decision 2**: 40–50 Sample Minimum
- Rationale: Ensures >95% accuracy + edge case coverage
- Impact: Balanced between data quality & collection effort

**Decision 3**: Confidence Threshold Strategy
- Rationale: 0.95/0.85/0.60 thresholds balance automation & safety
- Impact: Low-confidence fields auto-routed to manual review

**Decision 4**: Monthly Monitoring & Retraining
- Rationale: Detects data drift, enables continuous improvement
- Impact: Production models stay accurate as new forms arrive

---

## Next Steps

### Immediate (Week 1 — May 1)
1. **Phase Gate Approval**: Tommy Shelby reviews both strategies
2. **Issue #16 Execution**: Collect 40–50 VA Form 10-3542 samples
3. **Data Annotation**: Create JSON label files (32–40 fields per form)
4. **Quality Validation**: Michael + Grace verify dataset metrics

### Week 2 (May 1–3)
5. **Issue #17 Execution**: Upload to AI Builder, train model
6. **Model Testing**: Evaluate accuracy, iterate if needed
7. **Model Publishing**: Publish VAForm10-3542-Extractor v1.0

### Week 3 (May 3–5)
8. **Issue #18 Integration**: John Shelby integrates model into flows
9. **End-to-End Testing**: Intake → Extraction → D365 Write
10. **Production Rollout**: Deploy to live flows

### Ongoing
11. **Monthly Monitoring**: Track accuracy, trigger retraining if needed
12. **Quarterly Review**: Analyze performance trends

---

## Success Metrics (As of 2026-04-25)

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| **Strategy Completeness** | 100% | 100% | ✅ Complete |
| **Documentation Quality** | >2,000 words per doc | 5,000+ words | ✅ Exceeded |
| **Field Extraction Targets** | 32–40 fields | 40 fields | ✅ Defined |
| **Acceptance Criteria** | All defined | All defined | ✅ Complete |
| **Timeline Estimation** | Documented | 9–10 days | ✅ Estimated |
| **Phase Gate Readiness** | 90%+ | 90% | 🟡 1 approval pending |

---

## Risk Mitigation

| Risk | Prob | Impact | Mitigation |
|------|------|--------|-----------|
| **Low accuracy (<90%)** | Med | High | Oversample edge cases; iterate |
| **Data quality issues** | Med | High | Validation checklist; preprocessing |
| **PII leakage** | Low | Critical | Regex + manual audit before release |
| **Processing time >5 sec** | Low | Med | Monitor during QA; optimize if needed |
| **Model doesn't generalize** | Low | Med | Cover all variation factors; monthly retraining |

---

## Learnings (Added 2026-04-26)

- **Data collection must precede training sequentially**: The 5-day collection + anonymization + labeling window must fully complete before any AI Builder training session is initiated. Attempting to train incrementally with partial data wastes training cycles.
- **Grace Burgess QA gate is a hard gate, not optional**: Skipping Grace's validation risks HIPAA non-compliance (un-redacted PII in training data) and model quality failure. This gate was formalized in `.squad/decisions/inbox/michael-datacollection-apr26.md`.
- **Model field count settled at 33 core fields**: 32 domain fields + `claimFiledDate` = 33 total. This is the canonical count for `VAForm10-3542-Extractor` v1.0.
- **AI Builder training time estimate**: 20–45 minutes per training run (empirical AI Builder estimate for document processing models with 30–50 samples). Plan for up to 2 training iterations if first-pass accuracy falls below 95%.
- **Confidence threshold strategy confirmed** (Tommy Shelby review): ≥0.95 auto-accept, 0.85–0.94 optional review, 0.60–0.84 manual correction, <0.60 reject/escalate. These are now the canonical thresholds for all flow integration work.
- **JSON annotation tagging is the time bottleneck**: Budget 3–5 minutes per form for bounding-box tagging in AI Builder. For 35 training forms + 7 validation forms = ~2.5–3.5 hours of tagging work.

---

## Phase 2 Execution Deliverables (2026-04-26)

1. **DATA-COLLECTION-RUNBOOK.md** — `specs/03-phase-2-stream-b/`
   - 6-section hands-on operator guide
   - Pre-collection checklist, form sourcing, anonymization process
   - JSON labeling template, dataset split script (PowerShell), Grace QA gate
2. **AI-BUILDER-SETUP-RUNBOOK.md** — `specs/03-phase-2-stream-b/`
   - 8-section hands-on operator guide
   - Model creation, 33-field definition, document upload/tagging, training
   - Evaluation scorecard, publish steps, John Shelby handoff checklist
3. **michael-datacollection-apr26.md** — `.squad/decisions/inbox/`
   - Decision: Grace QA gate is a hard gate before training
   - Awaiting Scribe merge into shared decisions file

---

## Related Documents

**Phase 2 Stream A** (Polly Gray):
- [STREAM-A-COMPLETION-SUMMARY.md](../../specs/02-phase-2-stream-a/STREAM-A-COMPLETION-SUMMARY.md)
- [TABLE-SPECIFICATIONS.md](../../specs/02-phase-2-stream-a/TABLE-SPECIFICATIONS.md)
- [SCHEMA-DIAGRAM.md](../../specs/02-phase-2-stream-a/SCHEMA-DIAGRAM.md)

**Phase 2 Stream B** (Michael Gray & John Shelby):
- [DATA-COLLECTION-STRATEGY.md](../../specs/03-phase-2-stream-b/DATA-COLLECTION-STRATEGY.md)
- [MODEL-TRAINING-STRATEGY.md](../../specs/03-phase-2-stream-b/MODEL-TRAINING-STRATEGY.md)
- [MICHAEL-GRAY-STREAM-B-SUMMARY.md](../../specs/03-phase-2-stream-b/MICHAEL-GRAY-STREAM-B-SUMMARY.md)

---

## Status Timeline

| Date | Event | Status |
|------|-------|--------|
| 2026-04-24 | Phase 2 activated (Polly Gray Stream A) | ✅ Complete |
| 2026-04-25 | Stream B-1 strategy complete (Michael Gray) | ✅ This session |
| 2026-05-01 | Phase gate approval, data collection begins | ⏳ Expected |
| 2026-05-03 | Model training complete, published | ⏳ Expected |
| 2026-05-05 | Flow integration complete (John Shelby) | ⏳ Expected |
| 2026-05-07 | End-to-end testing & deployment | ⏳ Expected |

---

## References

**External Resources**:
- Microsoft AI Builder: https://docs.microsoft.com/power-platform/ai-builder/
- Document Processing: https://docs.microsoft.com/power-platform/ai-builder/form-processing-model-overview
- HIPAA Compliance: 45 CFR §164.512(k) (Safe Harbor de-identification)

---

**Agent**: Michael Gray, AI & ML Strategy Lead  
**Created**: 2026-04-25  
**Last Updated**: 2026-04-25  
**Status**: 🟢 Active & Ready for Execution
