# AI-BUILDER-SETUP-RUNBOOK.md
## VAForm10-3542-Extractor — AI Builder Model Creation & Training

**Author**: Michael Gray (AI & ML Strategy Lead)  
**Date**: 2026-04-26  
**Phase**: 2 — Stream B Execution  
**Status**: ✅ Ready for Execution  
**Prerequisite**: Grace Burgess QA sign-off on training dataset (DATA-COLLECTION-RUNBOOK.md Section 6)

---

## Overview

This runbook guides a human operator through creating, configuring, training, evaluating, and publishing the `VAForm10-3542-Extractor` custom document processing model in Microsoft AI Builder.

**Estimated Time**: 2–3 business days (May 5–7, 2026)  
**Target Accuracy**: ≥95% overall field extraction on validation set  
**Downstream**: John Shelby (Flow Integration) requires the Model ID from Section 6 Step 4.

---

## Pre-Execution Checklist

Before starting, confirm:

- [ ] Grace Burgess has signed off on training dataset (DATA-COLLECTION-RUNBOOK.md Section 6)
- [ ] `TrainingData/train/` contains 28–35 labeled form+JSON pairs
- [ ] `TrainingData/validation/` contains 6–8 labeled form+JSON pairs
- [ ] `TrainingData/test/` contains 6–8 labeled form+JSON pairs
- [ ] You have **Environment Maker** or **System Customizer** role in the Power Platform environment
- [ ] Environment confirmed: `Department of Veteran Affairs - OTH`
- [ ] You can access [make.powerapps.com](https://make.powerapps.com)

---

## Section 1: Create the Custom Model

1. Navigate to [make.powerapps.com](https://make.powerapps.com) and sign in with your organizational account.
2. In the environment selector (top-right), select: **Department of Veteran Affairs - OTH**
3. In the left navigation pane, click **AI Hub** (may appear as **AI Builder** depending on your interface version).
4. Click **+ New model** (top-right or center button).
5. Select model type: **Document Processing** (under "Extract custom information from documents").
6. Fill in model details:
   - **Name**: `VAForm10-3542-Extractor`
   - **Description**: `Custom document processing model for VA Form 10-3542 burial benefit claim extraction`
   - **Model type**: Custom (train with your documents)
7. Click **Next**.

---

## Section 2: Define Fields to Extract (32 Core Fields)

In the model field editor, add each field below. For each: click **+ Add field**, enter the field name, select the data type, and click **Done**.

> **Tip**: Use the JSON annotation template from DATA-COLLECTION-RUNBOOK.md Section 4 as your reference for correct field names and types.

### Section A — Claimant Information (7 fields)

| Field Name | Data Type | Notes |
|-----------|-----------|-------|
| `claimantRelationship` | Text | Spouse, Child, Parent, etc. |
| `claimantFirstName` | Text | PII — redacted in training data |
| `claimantLastName` | Text | PII — redacted in training data |
| `claimantAddress` | Text | PII — redacted |
| `claimantPhone` | Text | PII — redacted |
| `claimantEmail` | Text | PII — redacted |
| `claimantSSN` | Text | PII — redacted |

### Section B — Deceased Veteran Information (8 fields)

| Field Name | Data Type | Notes |
|-----------|-----------|-------|
| `veteranFirstName` | Text | PII — redacted |
| `veteranLastName` | Text | PII — redacted |
| `veteranServiceNumber` | Text | |
| `veteranBranch` | Text | Army, Navy, Marines, Air Force, Coast Guard |
| `veteranDeathDate` | Date | Format: YYYY-MM-DD |
| `veteranDeathPlace` | Text | |
| `veteranDeathCause` | Text | |
| `veteranVAFileNumber` | Text | |

### Section C — Burial Details (6 fields)

| Field Name | Data Type | Notes |
|-----------|-----------|-------|
| `burialDate` | Date | Format: YYYY-MM-DD |
| `cemeteryName` | Text | |
| `cemeteryAddress` | Text | |
| `burialType` | Text | interment, cremation, scattering |
| `funeralHomeName` | Text | |
| `funeralHomeAddress` | Text | |

### Section D — Benefit Selections (5 fields)

| Field Name | Data Type | Notes |
|-----------|-----------|-------|
| `burialAllowanceRequested` | Boolean | Checkbox on form |
| `plotAllowanceRequested` | Boolean | Checkbox on form |
| `transportationAllowanceRequested` | Boolean | Checkbox on form |
| `beneficiaryEligibilityCode` | Text | A, B, C, or D |
| `totalAmountClaimed` | Number | Dollar amount |

### Section E — Military Service (6 fields)

| Field Name | Data Type | Notes |
|-----------|-----------|-------|
| `serviceStartDate` | Date | Format: YYYY-MM-DD |
| `serviceEndDate` | Date | Format: YYYY-MM-DD |
| `serviceDischargeType` | Text | honorable, general, other-than-honorable, etc. |
| `warPeriod` | Text | WWII, Korea, Vietnam, Gulf War, etc. |
| `medalOrDecoration` | Text | May be null/blank |
| `POWStatus` | Boolean | Checkbox on form |

### Additional Field

| Field Name | Data Type | Notes |
|-----------|-----------|-------|
| `claimFiledDate` | Date | Date claimant signed/submitted |

**Total fields defined: 33**

After adding all fields, click **Next** to proceed to document upload.

---

## Section 3: Upload Training Documents

> All steps performed inside the AI Builder model editor (still on make.powerapps.com).

1. In the model editor, click **Add documents** (or **Upload documents**).
2. Upload all forms from `TrainingData/train/` (28–35 image files).
   - Supported formats: JPEG, PNG, PDF, TIFF
   - Upload in batches if needed (AI Builder may limit single-upload count)
3. For each uploaded form, the editor will display the form image and prompt you to **tag** each field:
   - Locate the field value on the image.
   - Draw a bounding box around the value.
   - Select the corresponding field name from the list.
   - The tagged value is auto-populated.
   - **Cross-reference with the JSON annotation file** (`TrainingData/train/form-NNN.json`) to confirm the correct value.
4. Repeat tagging for all 28–35 training documents.
   > **Note**: Tagging is the most time-intensive step. Budget 3–5 minutes per form (~2–3 hours total for 35 forms).
5. After tagging training documents, add validation documents:
   - Click **Add documents** again.
   - Upload all forms from `TrainingData/validation/` (6–8 forms).
   - Tag these forms using the same process.
6. Confirm document counts in the summary panel before proceeding.

---

## Section 4: Train the Model

1. After uploading and tagging all training and validation documents, click **Train** (top-right of model editor).
2. AI Builder will display a training progress indicator.
   - **Estimated training time**: 20–45 minutes
   - Do NOT close the browser tab during training; or monitor from AI Builder model list
3. While training runs, optionally review the field definitions and confirm all 33 fields are listed.
4. When training completes, the model status changes to **Trained**.
5. Review the training summary:
   - Overall accuracy score (target: ≥95%)
   - Per-field accuracy breakdown
   - Record results in the evaluation log (see Section 5)

---

## Section 5: Evaluate the Model

### Quick Test

1. In the trained model view, click **Quick Test**.
2. Upload a form from `TrainingData/test/` (one not used in training or validation).
3. Review extracted fields and confidence scores displayed by AI Builder.
4. Compare extracted values against the JSON annotation file for that test form.

### Evaluation Scorecard

Create a file `TrainingData/evaluation-results.csv` and record scores for each test form:

```
formId, overall_accuracy, avg_confidence, fields_above_095, fields_085_094, fields_below_085, notes
TRAIN-001, 0.97, 0.96, 30, 2, 1, "burialType confidence low"
```

### Decision Thresholds

| Result | Action |
|--------|--------|
| Overall accuracy ≥95% | ✅ Proceed to publish (Section 6) |
| Overall accuracy 92–94% | ⚠️ Proceed to publish but flag for early retraining review |
| Overall accuracy <92% | ❌ Retrain — add 5–10 more forms, tag, retrain |

### If Retraining Is Required

1. Collect 5–10 additional forms (follow DATA-COLLECTION-RUNBOOK.md Sections 2–4).
2. In the model editor, click **Add documents** and upload new forms to the training set.
3. Tag new forms as in Section 3.
4. Click **Retrain** (AI Builder will retrain with the expanded dataset).
5. Re-evaluate using Section 5 steps.
6. Escalate to Tommy Shelby if accuracy remains <92% after second retraining attempt.

### Field-Level Confidence Review

For each field, note confidence tier:
- **≥0.95** — Auto-accept in production flows (high confidence)
- **0.85–0.94** — Flag for optional human review
- **0.60–0.84** — Route to manual correction queue
- **<0.60** — Reject and escalate to manual processing

Document any fields consistently scoring below 0.85 and consider adding targeted training samples for those fields.

---

## Section 6: Publish the Model

Once accuracy target is met:

1. In the AI Builder model view, click **Publish**.
2. Confirm model details:
   - **Model Name**: `VAForm10-3542-Extractor`
   - **Version**: `1.0.0`
3. Click **Publish** to confirm.
4. **Record the Model ID** (displayed after publish, also available in model details):
   - Model ID: `___________________________`
   - **⚠️ Deliver Model ID to John Shelby immediately** — required for Power Automate flow integration.
5. Add the model to the VA Form Extraction solution:
   - Navigate to **Solutions** in left nav.
   - Open: **VA-Form-Extraction**.
   - Click **+ Add existing** → **AI Models**.
   - Select **VAForm10-3542-Extractor** → **Add**.
6. Confirm the model appears under the solution's AI Models component.

---

## Section 7: Confidence Thresholds Reference (Agreed with Tommy Shelby)

These thresholds are implemented by John Shelby in Power Automate flows. Document here for shared reference:

| Confidence Score | Routing Action | Description |
|-----------------|----------------|-------------|
| ≥0.95 | **Auto-accept** | High confidence — write to D365 directly |
| 0.85–0.94 | **Flag for optional review** | Queue for supervisor spot-check |
| 0.60–0.84 | **Manual correction queue** | Route to human correction workflow |
| <0.60 | **Reject + escalate** | Do not write to D365; trigger escalation alert |

Share this table with John Shelby at time of Model ID handoff.

---

## Section 8: Handoff to John Shelby (Flow Integration)

After publishing, deliver to John Shelby:

- [ ] **Model ID**: `___________________________`
- [ ] **Model Name**: `VAForm10-3542-Extractor`
- [ ] **Model Version**: `1.0.0`
- [ ] **Solution**: VA-Form-Extraction
- [ ] **Output format**: `extracted_fields` (JSON), `field_confidence_scores` (JSON)
- [ ] **Confidence thresholds**: ≥0.95 / 0.85–0.94 / 0.60–0.84 / <0.60 (see Section 7)
- [ ] **Per-field accuracy results** (evaluation-results.csv)
- [ ] Any fields with consistently low confidence (for flow-level handling)

---

## Timeline Reference

| Date | Milestone |
|------|-----------|
| May 5 | Grace QA sign-off received → Begin AI Builder setup |
| May 5 | Create model, define 33 fields (Sections 1–2) |
| May 5–6 | Upload + tag all training and validation documents (Section 3) |
| May 6 | Train model; monitor results (Section 4) |
| May 6–7 | Evaluate model; retrain if needed (Section 5) |
| May 7 | Publish model; deliver Model ID to John Shelby (Sections 6–8) |

---

## Escalation Contacts

| Issue | Contact |
|-------|---------|
| Accuracy <92% after 2 retrain attempts | Tommy Shelby (Team Lead) |
| AI Builder platform errors | IT/Power Platform admin |
| Additional form sourcing needed | VA Partner POC |
| QA re-validation needed | Grace Burgess |
| Flow integration questions | John Shelby |

---

*Prepared by Michael Gray — AI & ML Strategy Lead*  
*Phase Gate 2→3 approved by Tommy Shelby, 2026-04-26*
