# DATA-COLLECTION-RUNBOOK.md
## VA Form 10-3542 — AI Training Dataset Collection & Preparation

**Author**: Michael Gray (AI & ML Strategy Lead)  
**Date**: 2026-04-26  
**Phase**: 2 — Stream B Execution  
**Status**: ✅ Ready for Execution  
**Operator**: Human operator executes each step; Grace Burgess validates before training begins.

---

## Overview

This runbook guides a human operator through the end-to-end process of collecting, anonymizing, labeling, and organizing 40–50 VA Form 10-3542 training samples for the `VAForm10-3542-Extractor` AI Builder model.

**Estimated Time**: 3–5 business days (May 1–5, 2026)  
**Hard Gate**: Grace Burgess (QA Lead) must sign off on dataset before model training begins.

---

## Section 1: Data Collection Checklist (Pre-Collection)

Complete ALL of the following before collecting any forms:

- [ ] Confirm VA partner point of contact (POC) for form release
  - POC Name: ___________________________
  - POC Email: ___________________________
  - POC Phone: ___________________________
  - Date confirmed: ___________________________
- [ ] Obtain written authorization from VA partner to use forms for AI training
- [ ] Confirm HIPAA anonymization approval from compliance officer
  - Compliance Officer Name: ___________________________
  - Approval Date: ___________________________
  - Approval Reference #: ___________________________
- [ ] Review anonymization checklist (Section 3 below) with compliance officer
- [ ] Identify and confirm storage destination:
  - [ ] SharePoint: `FormIntake/TrainingData/` **OR**
  - [ ] Azure Blob Storage: `formintake-storage / trainingdataset/`
- [ ] Create folder structure in storage destination:
  - `TrainingData/raw/`
  - `TrainingData/anonymized/`
  - `TrainingData/labeled/`
  - `TrainingData/train/`
  - `TrainingData/validation/`
  - `TrainingData/test/`
- [ ] Confirm read/write access to all folders for your account
- [ ] Download and open the form audit log template (see Section 3, Step 5)
- [ ] Install or confirm access to Adobe Acrobat or equivalent PDF redaction tool

**⛔ Do NOT begin collecting forms until all pre-collection items above are checked.**

---

## Section 2: Form Sourcing (40–50 Samples)

**Target**: Collect 40–50 completed, real VA Form 10-3542 forms from VA partners.

### Minimum Viable Set (required before moving to Section 3)

| Category | Minimum Count | Notes |
|----------|--------------|-------|
| Fully completed, clean scans | 30 | All fields filled, readable, ≥300 DPI |
| Partially completed (realistic) | 10 | Some fields blank — real-world scenario |
| Edge cases | 5+ | Smudged ink, unusual handwriting, rotated scan |
| **TOTAL** | **45–50** | Aim for upper end for robustness |

### Diversity Requirements

Label each collected form with metadata (see audit log). Ensure the full set includes:

| Attribute | Required Variants |
|-----------|------------------|
| Handwriting style | Print, cursive, mixed — at least 3 styles |
| Ink color | Black, blue, red, pencil — at least 2 colors |
| Paper condition | Clean, slightly worn, scanned at angle |
| Form fill completeness | All fields complete (30), partial (10), edge cases (5+) |
| Scan resolution | 300 DPI minimum, 400 DPI preferred |
| Image format | JPEG (primary), PNG (secondary), TIFF (acceptable) |

### Step-by-Step: Requesting Forms from VA Partner

1. Contact VA POC (confirmed above) and request batch of de-identified (or to-be-anonymized) completed Form 10-3542 submissions.
2. Specify volume: 40–50 forms.
3. Specify format: scanned PDF or high-resolution image (JPEG/PNG/TIFF).
4. Specify minimum resolution: 300 DPI.
5. Request forms be provided on secure channel (SharePoint share, encrypted email, or VA-approved file transfer).
6. Log receipt of each batch in the audit log.

### Storage: Save Raw Forms

- Save all received forms to: `TrainingData/raw/`
- Naming convention: `raw-001.pdf`, `raw-002.jpg`, etc. (sequential numbering)
- Do NOT rename or alter originals before completing audit log entry.

---

## Section 3: Anonymization Process (PII Removal)

**Complete this section for EVERY collected form.**

### PII Fields to Redact

For each form, black out (fully redact) the following:

- [ ] Claimant full name
- [ ] Social Security Number (SSN)
- [ ] Date of birth
- [ ] Home address (street, city, state, ZIP)
- [ ] Phone numbers
- [ ] Email address
- [ ] Signature
- [ ] Any handwritten personal identifiers not covered above

### Step-by-Step: Anonymizing One Form

1. Open the raw form file from `TrainingData/raw/` in Adobe Acrobat (or equivalent redaction tool).
2. Use the **Redact** tool (not just a black box drawn on top — use proper redaction that removes underlying data).
3. For each PII field listed above:
   - Locate the field on the form.
   - Apply redaction mark.
4. Review the entire form page by page for any PII missed (handwritten notes, margins, etc.).
5. Apply all redactions and save.
6. Save the anonymized file to: `TrainingData/anonymized/`
   - Naming convention: `anon-001.jpg`, `anon-001.pdf` (matching number to raw file)
7. **Log in audit log** (see below): original filename → anonymized filename.
8. **Do NOT delete originals** until compliance officer provides written sign-off.

### Audit Log Format

Maintain a CSV file at `TrainingData/anonymization-audit-log.csv` with these columns:

```
raw_filename, anon_filename, date_anonymized, anonymized_by, pii_fields_redacted, notes
raw-001.pdf, anon-001.jpg, 2026-05-01, J.Smith, "name,ssn,dob,address,phone,signature", ""
raw-002.pdf, anon-002.jpg, 2026-05-01, J.Smith, "name,ssn,dob,address,phone,email,signature", "rotated scan"
```

---

## Section 4: Labeling Guide (Ground Truth Annotation)

For each anonymized form, create a JSON ground-truth annotation file that records the correct value for each extracted field.

### Step-by-Step: Creating a Label File

1. Open the anonymized form: `TrainingData/anonymized/anon-NNN.jpg`
2. Create a new JSON file: `TrainingData/labeled/form-NNN.json`
3. For each field in the form, record the exact text/value as it appears on the form.
4. For redacted fields (PII), use the value `"REDACTED"`.
5. For blank/missing fields, use `null`.
6. Save both the annotated image and JSON to `TrainingData/labeled/`:
   - Copy image: `TrainingData/labeled/form-NNN.jpg`
   - Save JSON: `TrainingData/labeled/form-NNN.json`

### JSON Annotation Template

```json
{
  "formId": "TRAIN-001",
  "sourceFile": "anonymized/anon-001.jpg",
  "metadata": {
    "handwritingStyle": "print",
    "inkColor": "black",
    "paperCondition": "clean",
    "completeness": "full",
    "scanDPI": 400,
    "imageFormat": "JPEG"
  },
  "fields": {
    "claimantRelationship": "Spouse",
    "claimantFirstName": "REDACTED",
    "claimantLastName": "REDACTED",
    "claimantAddress": "REDACTED",
    "claimantPhone": "REDACTED",
    "claimantEmail": "REDACTED",
    "claimantSSN": "REDACTED",
    "veteranFirstName": "REDACTED",
    "veteranLastName": "REDACTED",
    "veteranServiceNumber": "REDACTED",
    "veteranBranch": "Army",
    "veteranDeathDate": "2025-01-15",
    "veteranDeathPlace": "VA Medical Center",
    "veteranDeathCause": "Natural causes",
    "veteranVAFileNumber": "REDACTED",
    "burialDate": "2025-01-22",
    "cemeteryName": "National Cemetery",
    "cemeteryAddress": "REDACTED",
    "burialType": "interment",
    "funeralHomeName": "Example Funeral Home",
    "funeralHomeAddress": "REDACTED",
    "burialAllowanceRequested": true,
    "plotAllowanceRequested": false,
    "transportationAllowanceRequested": true,
    "beneficiaryEligibilityCode": "B",
    "totalAmountClaimed": 2000.00,
    "serviceStartDate": "1970-06-01",
    "serviceEndDate": "1974-05-31",
    "serviceDischargeType": "honorable",
    "warPeriod": "Vietnam",
    "medalOrDecoration": null,
    "POWStatus": false,
    "claimFiledDate": "2025-02-01"
  }
}
```

### JSON Validation

After creating each label file, validate JSON syntax:

```powershell
# PowerShell: Validate a single JSON file
$json = Get-Content "TrainingData/labeled/form-001.json" -Raw
try { $null = $json | ConvertFrom-Json; Write-Host "✅ Valid JSON" } catch { Write-Host "❌ Invalid JSON: $_" }

# Validate all label files at once
Get-ChildItem "TrainingData/labeled/*.json" | ForEach-Object {
    $json = Get-Content $_.FullName -Raw
    try { $null = $json | ConvertFrom-Json; Write-Host "✅ $($_.Name)" }
    catch { Write-Host "❌ $($_.Name): $_" }
}
```

---

## Section 5: Dataset Split

After all 40–50 forms are collected, anonymized, and labeled, split into three sets:

| Set | Proportion | Count (of 45) | Folder |
|-----|-----------|---------------|--------|
| Training | 70% | 31–32 forms | `TrainingData/train/` |
| Validation | 15% | 6–7 forms | `TrainingData/validation/` |
| Test | 15% | 6–7 forms | `TrainingData/test/` |

### Randomization Rules

1. Number all labeled forms sequentially (form-001 through form-NNN).
2. Use the following PowerShell to generate a random assignment:

```powershell
$forms = Get-ChildItem "TrainingData/labeled/*.jpg" | Select-Object -ExpandProperty Name
$shuffled = $forms | Get-Random -Count $forms.Count
$total = $shuffled.Count
$trainEnd = [Math]::Floor($total * 0.70)
$valEnd = $trainEnd + [Math]::Floor($total * 0.15)

$train = $shuffled[0..($trainEnd - 1)]
$validation = $shuffled[$trainEnd..($valEnd - 1)]
$test = $shuffled[$valEnd..($total - 1)]

Write-Host "Training: $($train.Count) | Validation: $($validation.Count) | Test: $($test.Count)"

# Copy files to split folders
$train | ForEach-Object {
    $base = [System.IO.Path]::GetFileNameWithoutExtension($_)
    Copy-Item "TrainingData/labeled/$_" "TrainingData/train/"
    Copy-Item "TrainingData/labeled/$base.json" "TrainingData/train/"
}
$validation | ForEach-Object {
    $base = [System.IO.Path]::GetFileNameWithoutExtension($_)
    Copy-Item "TrainingData/labeled/$_" "TrainingData/validation/"
    Copy-Item "TrainingData/labeled/$base.json" "TrainingData/validation/"
}
$test | ForEach-Object {
    $base = [System.IO.Path]::GetFileNameWithoutExtension($_)
    Copy-Item "TrainingData/labeled/$_" "TrainingData/test/"
    Copy-Item "TrainingData/labeled/$base.json" "TrainingData/test/"
}
```

### Edge Case Distribution Rule

Manually verify that edge-case forms (smudged, rotated, unusual handwriting) are distributed across all 3 sets — not all clustered in train. Aim for at least 1 edge case in each of validation and test.

---

## Section 6: Quality Gate (Grace Burgess Validation)

**⛔ HARD GATE — Model training does NOT begin until Grace Burgess signs off.**

Grace Burgess (QA Lead) must verify the following before runbook handoff to AI Builder Setup:

### Checklist for Grace Burgess

- [ ] All 40–50 forms present in `TrainingData/labeled/` (image + JSON pairs)
- [ ] All PII redacted — spot-check minimum 10 forms manually
- [ ] Audit log (`anonymization-audit-log.csv`) is complete for every form
- [ ] Handwriting diversity: ≥3 handwriting styles represented across dataset
- [ ] Ink color diversity: ≥2 ink colors represented
- [ ] Completeness diversity: ≥10 partially-completed forms included
- [ ] JSON annotations valid — all label files pass JSON linter (see Section 4 script)
- [ ] Image resolution: all images ≥300 DPI (check EXIF metadata or file properties)
- [ ] Dataset split complete: train / validation / test folders populated
- [ ] Edge cases distributed across all 3 splits

### Grace's Sign-Off

When all items above are checked:

```
Grace Burgess Sign-Off
Date: ___________________________
Signature: ___________________________
Notes: ___________________________
```

**Deliver signed checklist to Michael Gray before initiating AI Builder Setup Runbook.**

---

## Timeline Reference

| Date | Milestone |
|------|-----------|
| May 1 | Begin data collection (operator starts Section 1–2) |
| May 1–2 | Anonymization complete (Section 3) |
| May 2–3 | Labeling / annotation complete (Section 4) |
| May 3 | Dataset split complete (Section 5) |
| May 4 | Grace Burgess QA validation (Section 6) |
| May 5 | Grace sign-off → Hand off to AI Builder Setup Runbook |

---

*Prepared by Michael Gray — AI & ML Strategy Lead*  
*Phase Gate 2→3 approved by Tommy Shelby, 2026-04-26*
