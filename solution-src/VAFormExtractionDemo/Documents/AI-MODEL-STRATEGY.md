# AI Model Training Strategy — VA Form 10-3542 Extractor
**Issue:** #17 | **Owner:** Michael Gray | **Status:** Complete

---

## Model Identity

| Property | Value |
|----------|-------|
| Model Name | `VAForm10-3542-Extractor` |
| Platform | AI Builder — Custom Document Processing |
| Environment | Contact Center (healthconnectcenter.crm.dynamics.com) |
| Solution | VAFormExtractionDemo |
| Form | VA Form 10-3542 (Application for Medical Benefits Transportation) |

---

## Extraction Fields

| Field Name | AI Builder Field Type | Source Location on Form | Notes |
|------------|-----------------------|------------------------|-------|
| `ServiceNumber` | Text | Section 1 — Veteran Identification | 8-digit service number |
| `ClaimDate` | Date | Header / Date of Application | MM/DD/YYYY format |
| `ServiceBranch` | Text | Section 1 — Branch of Service | Army / Navy / Air Force / Marine Corps / Coast Guard |
| `DisabilityRating` | Number | Section 2 — Service-Connected Disability | Percentage 0–100 |
| `BenefitType` | Text | Section 3 — Type of Benefit Requested | May be checkbox group |
| `VeteranLastName` | Text | Section 1 — Veteran Name | Last name |
| `VeteranFirstName` | Text | Section 1 — Veteran Name | First name |
| `VeteranDOB` | Date | Section 1 — Date of Birth | MM/DD/YYYY |
| `VeteranSSN` | Text | Section 1 — Social Security Number | XXX-XX-XXXX (PII — handle carefully) |
| `TreatmentFacility` | Text | Section 4 — Medical Facility | Facility name |
| `AppointmentDate` | Date | Section 4 — Appointment Date | MM/DD/YYYY |
| `TransportationMode` | Text | Section 5 — Mode of Transportation | Ambulance / Chair Car / Regular |
| `ExpenseA_Amount` | Number | Expense line A | Decimal currency amount |
| `ExpenseB_Amount` | Number | Expense line B | Decimal currency amount |
| `ExpenseC_Amount` | Number | Expense line C | Decimal currency amount |
| `ExpenseD_Amount` | Number | Expense line D | Decimal currency amount |
| `totalAmountClaimed` | Number | Expense total | Sum of all claimed amounts |
| `SignatureDate` | Date | Bottom — Veteran Signature | MM/DD/YYYY |
| `CertifyingOfficialName` | Text | Bottom — Certifying Official | Name field |

---

## Confidence Thresholds

| Threshold | Range | Action |
|-----------|-------|--------|
| **Accept** | ≥ 80% | Auto-accept, populate Dataverse, proceed to D365 write |
| **Flag for Review** | 60% – 79% | Create `CorrectionRecord`, route to manual review queue |
| **Reject / Re-extract** | < 60% | Set `ExtractionStatus = Failed`, create high-priority `CorrectionRecord`, notify reviewer |

These thresholds are stored as environment variables in the Power Automate flows so they can be adjusted without code changes.

---

## Validation Rules

| Field | Rule | On Failure |
|-------|------|-----------|
| `ServiceNumber` | 8 digits exactly | Flag |
| `ClaimDate`, `VeteranDOB`, `AppointmentDate`, `SignatureDate` | Valid date, not in future (except AppointmentDate) | Flag |
| `DisabilityRating` | Integer 0–100 | Flag |
| `VeteranSSN` | Pattern `\d{3}-\d{2}-\d{4}` | Reject (PII extraction error) |
| `ServiceBranch` | Must match allowed values list | Flag |
| `TransportationMode` | Must match allowed values list | Flag |
| All required fields | Not null/empty | Flag |

---

## Training Data Requirements

| Category | Count | Purpose |
|----------|-------|---------|
| High quality digital scan | 3–4 | Baseline extraction |
| Handwritten entries | 2–3 | Handwriting robustness |
| Partial completion (some fields blank) | 1–2 | Empty field handling |
| Different layout versions | 1–2 | Form version variance |
| **Total minimum** | **5–10 samples** | AI Builder minimum: 5 |

> ⚠️ **PII Handling:** Training samples must be real or realistic but any actual PII (real SSNs, real names) must be redacted or synthesized before upload to SharePoint.

---

## Model Build Steps (AI Builder)

1. **[Portal]** Go to [make.powerapps.com](https://make.powerapps.com) → Contact Center → AI Builder → **Create**
2. Select **Document Processing** model type
3. Name: `VAForm10-3542-Extractor`
4. Add the 14 fields listed above (use correct field types)
5. Upload 5–10 training document samples from SharePoint `FormIntake` library
6. **Tag** each field in each document (draw bounding boxes)
7. Click **Train**
8. Evaluate confidence scores on test set — adjust tagging if < 80% average
9. **Publish** model

---

## Integration Contract

The trained model will be called by Power Automate flow **#30 (AI Extraction Invocation Flow)** using the action:

```
AI Builder → Process and save information from documents
  Model: VAForm10-3542-Extractor
  Document: [SharePoint file content]
```

Output is mapped directly to `vafe_extractionresult` table fields.

---

## Monitoring

See issue #28 — AI Model Monitoring Dashboard will track:
- Average confidence scores per field over time
- Rate of `Flag for Review` vs `Accept` vs `Reject`
- Model retraining triggers (when acceptance rate drops below 70%)
