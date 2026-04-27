# Training Data Collection Guide — VA Form 10-3542
**Issue:** #16 | **Owner:** Michael Gray | **Status:** Complete

---

## What You Need

AI Builder requires **minimum 5 sample documents** (10 recommended) of the same form to train a Document Processing model. You need VA Form 10-3542 PDFs in varied states.

---

## Step 1 — Get the Blank Form

Download the official VA Form 10-3542:

- **URL:** https://www.va.gov/find-forms/about-form-10-3542/
- **Direct PDF:** Search "VA Form 10-3542" on va.gov
- Save as: `VA-10-3542-BLANK.pdf`

---

## Step 2 — Create Sample Variants

You need 5–10 samples covering these variations:

| Sample | Type | How to Create |
|--------|------|---------------|
| `VA-10-3542-SAMPLE-01.pdf` | Digital fill — complete | Fill all fields in Adobe/browser |
| `VA-10-3542-SAMPLE-02.pdf` | Digital fill — partial | Leave 3–4 non-required fields blank |
| `VA-10-3542-SAMPLE-03.pdf` | Print + handwrite | Print blank, hand-fill with pen, scan |
| `VA-10-3542-SAMPLE-04.pdf` | Print + handwrite (messy) | Same but use varied handwriting |
| `VA-10-3542-SAMPLE-05.pdf` | Scanned copy (lower quality) | Print filled form, scan at 150 DPI |
| `VA-10-3542-SAMPLE-06.pdf` | Different disability rating | Change rating field only |
| `VA-10-3542-SAMPLE-07.pdf` | Different branch of service | Change branch field only |

### Sample Field Values (Use These — No Real PII)

```
VeteranLastName:    Doe / Smith / Johnson
VeteranFirstName:   John / Jane / Robert  
VeteranDOB:         01/15/1965 / 03/22/1972 / 07/04/1958
VeteranSSN:         000-00-0001 / 000-00-0002 / 000-00-0003  ← NOT real SSNs
ServiceNumber:      12345678 / 87654321 / 11223344
ServiceBranch:      Army / Navy / Marine Corps
DisabilityRating:   30 / 50 / 70 / 100
ClaimDate:          04/01/2026 / 03/15/2026
TreatmentFacility:  VA Medical Center Washington DC
AppointmentDate:    04/15/2026 / 05/01/2026
TransportationMode: Regular / Ambulance / Chair Car
```

> ⚠️ **NEVER use real SSNs, real names of actual veterans, or real service numbers in training data.**

---

## Step 3 — Upload to SharePoint

**Target location:** Contact Center SharePoint site → `FormIntake` library

1. Go to your SharePoint site
2. Navigate to `FormIntake` document library (create it if it doesn't exist)
3. Create folder: `AITrainingData/`
4. Upload all 5–10 sample PDFs into `AITrainingData/`

Name convention: `VA-10-3542-SAMPLE-##.pdf`

---

## Step 4 — Document Metadata

For each sample, record this in a spreadsheet (`training-data-manifest.xlsx`):

| File | Type | Quality | Fields Blank | Notes |
|------|------|---------|-------------|-------|
| VA-10-3542-SAMPLE-01.pdf | Digital fill | High | None | Baseline |
| VA-10-3542-SAMPLE-03.pdf | Handwritten | Medium | 2 | Varied handwriting |

This manifest helps diagnose model failures during tagging.

---

## Acceptance Criteria Checklist

- [ ] VA Form 10-3542 PDF downloaded
- [ ] 5 minimum samples created (10 recommended)
- [ ] Samples cover: digital fill, handwritten, partial, varied quality
- [ ] NO real PII used in any sample
- [ ] All samples uploaded to SharePoint `FormIntake/AITrainingData/`
- [ ] Metadata manifest documented
- [ ] Ready to proceed to issue #19 (Configure Document Type Detection)

---

## Time Estimate

| Task | Time |
|------|------|
| Download blank form | 5 min |
| Create 5 digital samples | 20–30 min |
| Print + handwrite 2 samples | 15–20 min |
| Scan handwritten samples | 10 min |
| Upload to SharePoint | 10 min |
| **Total** | **60–75 min** |
