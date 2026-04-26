# Issue #16: AI Training Data Collection Strategy
**VA Form 10-3542 Sample Data Preparation**

**Owner**: Michael Gray (AI & ML Strategy Lead)  
**Phase**: 2 — Foundational (Data & ML)  
**Status**: In Progress  
**Target Completion**: April 25, 2026

---

## Executive Summary

This document defines the **training data collection and preparation strategy** for the VA Form 10-3542 Beneficiary Declaration form. The strategy ensures AI Builder custom document processing model achieves >95% field extraction accuracy while maintaining VA compliance and data quality standards.

**Key Metrics**:
- **Sample Size**: 40–50 labeled forms (minimum 40 for production model)
- **Data Split**: 70% training (28 forms), 15% validation (6 forms), 15% test (6 forms)
- **Coverage**: Diverse handwriting, ink colors, paper conditions, form variations
- **Anonymization**: All PII masked per VA/HIPAA requirements
- **Quality Target**: 300 DPI minimum, <5% OCR error rate per field
- **Storage**: Azure Blob Storage or SharePoint FormIntake library (hybrid)

---

## 1. Data Source Analysis

### 1.1 Form Profile: VA Form 10-3542

**Official Name**: Application for Burial Benefits – Beneficiary Declaration  
**Form Type**: Multi-page questionnaire (typically 2–4 pages)  
**Data Entry Method**: Mix of printed, handwritten, and checkbox entries  
**Claimant**: Surviving spouse/family member of deceased veteran  
**Processing Volume (estimated)**: 500–1,000 forms/month at scale

### 1.2 Collection Methods

#### Method A: Public Domain / Non-PII Sample Set
- **Source**: GSA/VA public archives, de-identified training samples
- **Availability**: ⚠️ Limited (VA rarely publishes forms with sample data)
- **Fallback**: Use form template + manually create variation samples

#### Method B: Synthetic Data Generation
- **Approach**: Generate realistic variations using:
  - Template-based form filling with random data
  - Handwriting simulation (iScript, or scanned actual writing styles)
  - Noise injection (paper texture, ink variations, fold lines)
- **Advantage**: Complete control over PII masking
- **Tool**: Adobe PDF SDK or custom Python script (PIL + form overlays)
- **Estimated Samples**: 20–30 synthetic forms

#### Method C: Real Anonymized Samples (If Available)
- **Source**: VA processing partner, historical archive (with consent)
- **Anonymization**: Remove all PII before use
- **Advantage**: Realistic handwriting, paper conditions, edge cases
- **Timeline**: Requires legal/compliance review (2–5 days)
- **Estimated Samples**: 15–25 real forms

### 1.3 Diversity Requirements

Training set MUST cover variations:

| Factor | Variations to Include | Rationale |
|--------|----------------------|-----------|
| **Handwriting Style** | Print, cursive, mixed, slanted | AI must handle all writing styles |
| **Ink Color** | Black, blue, red (signature), faded | Real-world variation |
| **Paper Condition** | Clean, folded, water-stained, aged | Scanning artifacts |
| **Form Layout** | Standard, re-printed version, margin shifts | Form revisions |
| **Completeness** | All fields filled, partial, N/A fields | Real submission patterns |
| **Font Size** | Large (elderly), normal, cramped | Writer comfort variations |
| **Alignment** | On-grid, off-grid, rotated entries | Manual form entry |

**Coverage Goal**: Each combination represented in at least 2 samples (40 samples = 2–3 variations per factor).

---

## 2. Field Inventory & Extraction Targets

### 2.1 Key Fields to Extract

From VA Form 10-3542 specification (32 core fields):

#### Section A: Claimant Information (7 fields)
| Field Name | Data Type | Format | Masking Required |
|------------|-----------|--------|-----------------|
| `claimant_full_name` | Text | "First Middle Last" | ✅ Yes → `**** ****` |
| `claimant_dob` | Date | MM/DD/YYYY | ✅ Yes → `**/**/****` |
| `claimant_ssn` | Text | 9 digits | ✅ Yes → `***-**-****` |
| `claimant_phone` | Text | (XXX) XXX-XXXX | ✅ Yes → `(***) ***-****` |
| `claimant_address_street` | Text | Street address | ✅ Partial masking |
| `claimant_address_city_state_zip` | Text | City, ST 12345 | ✅ Partial masking |
| `claimant_email` | Text | user@domain.com | ✅ Yes → mask domain |

#### Section B: Deceased Veteran Details (8 fields)
| Field Name | Data Type | Format | Masking Required |
|------------|-----------|--------|-----------------|
| `veteran_full_name` | Text | "First Middle Last" | ✅ Yes |
| `veteran_dob` | Date | MM/DD/YYYY | ✅ Yes |
| `veteran_dod` | Date | MM/DD/YYYY | ⚠️ Public record |
| `veteran_ssn` | Text | 9 digits | ✅ Yes |
| `veteran_service_number` | Text | Custom format | ⚠️ Low sensitivity |
| `veteran_service_branch` | Choice | Army/Navy/Marines/etc. | ✅ No masking |
| `veteran_rank_or_rate` | Text | E-5, O-3, etc. | ✅ No masking |
| `veteran_discharge_status` | Choice | Honorable/Dishonorable/etc. | ⚠️ Moderate sensitivity |

#### Section C: Relationship & Eligibility (6 fields)
| Field Name | Data Type | Format | Masking Required |
|------------|-----------|--------|-----------------|
| `claimant_relationship_to_veteran` | Choice | Spouse/Child/Parent/etc. | ✅ No masking |
| `marital_status_at_death` | Choice | Married/Single/Divorced | ⚠️ Sensitive |
| `marriage_date` | Date | MM/DD/YYYY | ⚠️ Low sensitivity |
| `has_dependent_children` | Boolean | Yes/No checkbox | ✅ No masking |
| `number_of_dependents` | Number | 0–10+ | ✅ No masking |
| `is_eligible_for_benefits` | Boolean | Yes/No/Unknown | ✅ No masking |

#### Section D: Military Service & Dates (5 fields)
| Field Name | Data Type | Format | Masking Required |
|------------|-----------|--------|-----------------|
| `service_start_date` | Date | MM/DD/YYYY | ✅ No masking |
| `service_end_date` | Date | MM/DD/YYYY | ✅ No masking |
| `years_of_service` | Number | 0–50 | ✅ No masking |
| `deployment_dates` | Text | Freeform or MM/DD/YYYY | ✅ No masking |
| `combat_status` | Choice | Active/Reserve/Guard/etc. | ✅ No masking |

#### Section E: Signature & Authorization (6 fields)
| Field Name | Data Type | Format | Masking Required |
|------------|-----------|--------|-----------------|
| `signature_present` | Boolean | Yes/No | ✅ No masking |
| `signature_date` | Date | MM/DD/YYYY | ✅ No masking |
| `notarized` | Boolean | Yes/No checkbox | ✅ No masking |
| `notary_name` | Text | Freeform | ✅ Yes (partial) |
| `notary_date` | Date | MM/DD/YYYY | ✅ No masking |
| `form_version` | Text | "10-3542 (Rev 08/2024)" | ✅ No masking |

**Total Extraction Fields**: 32 core + 8 conditional = ~40 potential fields

### 2.2 Confidence Score Mapping

Each extracted field will include a confidence score (0.0–1.0):

```json
{
  "extracted_fields": {
    "claimant_full_name": "REDACTED",
    "claimant_dob": "**/**/****",
    "veteran_service_branch": "Army",
    "relationship_to_veteran": "Spouse"
  },
  "field_confidence_scores": {
    "claimant_full_name": 0.98,      // OCR high confidence
    "claimant_dob": 0.87,            // Handwritten, slightly uncertain
    "veteran_service_branch": 0.95,  // Checkbox field (high confidence)
    "relationship_to_veteran": 0.92  // Printed field
  }
}
```

**Confidence Score Interpretation**:
- **0.95–1.0**: Excellent confidence, accept without review
- **0.85–0.94**: Good confidence, review if needed
- **0.75–0.84**: Fair confidence, recommend review
- **<0.75**: Low confidence, MUST be manually reviewed

---

## 3. Training Data Format & Storage

### 3.1 Data Organization Structure

```
FormIntake/
├── TrainingDataset/
│   ├── Forms/
│   │   ├── Training (70% = 28 forms)
│   │   │   ├── form-001-clean-printed.pdf
│   │   │   ├── form-002-handwritten-cursive.pdf
│   │   │   ├── form-003-mixed-faded-ink.pdf
│   │   │   └── ... (25 more forms)
│   │   │
│   │   ├── Validation (15% = 6 forms)
│   │   │   ├── form-029-validation-01.pdf
│   │   │   └── ... (5 more forms)
│   │   │
│   │   └── Test (15% = 6 forms)
│   │       ├── form-035-test-01.pdf
│   │       └── ... (5 more forms)
│   │
│   ├── Annotations/
│   │   ├── form-001-labels.json
│   │   ├── form-002-labels.json
│   │   └── ... (40 JSON files, 1 per form)
│   │
│   ├── Metadata/
│   │   ├── dataset-manifest.csv
│   │   ├── field-definitions.json
│   │   ├── anonymization-log.json
│   │   └── quality-metrics.json
│   │
│   └── README.md (instructions for AI Builder import)
```

### 3.2 Image Format Specifications

| Property | Requirement | Rationale |
|----------|-------------|-----------|
| **File Format** | JPEG or PNG (300 DPI minimum) | AI Builder native support |
| **Resolution** | 300 DPI (approx. 3000×4000 px @ 8.5×11 in) | OCR quality threshold |
| **Color Space** | RGB or Grayscale | Handles ink color variation |
| **File Size** | 500 KB–2 MB per image | Balance detail vs. storage |
| **Compression** | Minimal (JPEG quality >90) | Preserve text clarity |
| **Rotation** | Detect & auto-correct to 0° | Consistent orientation |
| **Brightness** | Auto-level if <20% under/over | Improve OCR |
| **Noise** | Despeckle if >10% artifacts | Remove scanning artifacts |

**Preprocessing Steps**:
1. Scan/digitize at 300 DPI in grayscale
2. Deskew (auto-rotate to horizontal)
3. Auto-level contrast & brightness
4. Despeckle (remove <5px noise specks)
5. Crop to form boundaries (remove blank margins)
6. Export as PNG or JPEG (quality >90)

### 3.3 JSON Label/Annotation Format

**Per-Form Label File** (form-###-labels.json):

```json
{
  "form_id": "form-001",
  "form_filename": "form-001-clean-printed.pdf",
  "source_type": "synthetic|real|public",
  "scan_date": "2026-04-24",
  "scan_dpi": 300,
  "page_count": 2,
  "quality_flags": ["clean_scan", "printed_text", "all_fields_completed"],
  "extracted_fields": {
    "section_a": {
      "claimant_full_name": {
        "value": "REDACTED",
        "confidence": 0.98,
        "region": {"page": 1, "x": 150, "y": 320, "width": 250, "height": 20},
        "field_type": "printed"
      },
      "claimant_dob": {
        "value": "**/**/****",
        "confidence": 0.92,
        "region": {"page": 1, "x": 420, "y": 320, "width": 120, "height": 20},
        "field_type": "printed"
      }
    },
    "section_b": {
      "veteran_service_branch": {
        "value": "Army",
        "confidence": 0.99,
        "region": {"page": 1, "x": 150, "y": 420, "width": 80, "height": 20},
        "field_type": "checkbox"
      }
    }
  },
  "extraction_validation": {
    "manually_reviewed": true,
    "reviewed_by": "michael-gray",
    "review_date": "2026-04-24",
    "accuracy_confirmed": true,
    "notes": "Clean scan, all fields clearly legible"
  }
}
```

### 3.4 Dataset Manifest (CSV)

**dataset-manifest.csv** tracks all 40+ samples:

```csv
form_id,filename,set (training/validation/test),source_type,page_count,quality_flags,completeness_%,extracted_field_count,avg_confidence,manually_reviewed,review_status,notes
form-001,form-001-clean-printed.pdf,training,synthetic,2,"clean_scan,printed_text,all_fields",100,32,0.94,yes,approved,"High confidence set"
form-002,form-002-handwritten.pdf,training,real,2,"handwritten,cursive,faded",85,28,0.82,yes,approved,"Some illegible entries"
form-003,form-003-mixed-ink.pdf,training,synthetic,2,"mixed_colors,smudged",90,30,0.88,yes,approved,"Red signature, blue form"
...
form-040,form-040-edge-case.pdf,test,real,3,"water_damaged,creased,partial",60,22,0.71,yes,review_required,"4 fields illegible - manual entry needed"
```

---

## 4. Anonymization & Privacy Compliance

### 4.1 PII Masking Rules

**Before storing in training dataset**, apply these masking rules:

| Field | Original | Masked Example | Method |
|-------|----------|----------------|--------|
| Full Name | "John Michael Doe" | "REDACTED" or `****` | Replace entire value |
| SSN | "123-45-6789" | "***-**-6789" | Show last 4 only |
| DOB | "03/15/1950" | "**/**/****" | Full mask (age derivable) |
| Phone | "(555) 123-4567" | "(***) ***-4567" | Show last 4 only |
| Email | "john.doe@example.com" | "****@example.com" | Mask local part |
| Address | "123 Main St, Phoenix, AZ 85001" | "[STREET] [CITY], AZ [ZIP]" | Replace with placeholder |
| Service # | "WD1234567890" | "WD1234567890" | ✅ Keep (low sensitivity) |
| Rank | "Major" | "Major" | ✅ Keep |

### 4.2 Anonymization Checklist

Before releasing training data:

- [ ] All claimant names redacted
- [ ] All SSNs masked (show last 4 only)
- [ ] All DOBs fully masked
- [ ] All phone numbers masked (show last 4 only)
- [ ] All email addresses masked
- [ ] All home addresses masked or zipcode-only
- [ ] Signature image obscured (draw black box over signature block)
- [ ] Notary name partially masked
- [ ] Form version & page numbers retained (non-PII)
- [ ] Service numbers retained (low sensitivity, military member identification only)
- [ ] No metadata with timestamps/scanner IDs that identify source

### 4.3 VA/HIPAA Compliance

✅ **Compliant practices**:
- Masks all PII per HIPAA Privacy Rule
- No direct identifiers (names, SSNs, DOBs)
- Indirect identifiers (age, ZIP code, military rank) reviewed & allowed
- De-identification standard: §45 CFR §164.512(k) (Safe Harbor method)
- Audit log maintained (who accessed, when, for what purpose)
- Data encrypted at rest (Azure Blob Storage encryption)
- Data encrypted in transit (TLS 1.2+)

---

## 5. Data Quality Assurance

### 5.1 Quality Metrics & Thresholds

| Metric | Target | Threshold | Action If Below |
|--------|--------|-----------|------------------|
| **OCR Field Accuracy** | >95% | ≥90% | Rescan/preprocess image |
| **Field Coverage** | ≥95% of expected fields filled | ≥80% | Include in dataset if >80% |
| **Image Clarity (DPI)** | ≥300 DPI | ≥200 DPI (fallback) | Rescan form |
| **Avg. Confidence Score** | 0.90+ | ≥0.80 | Manual review required |
| **Handwriting Legibility** | 100% readable | ≥90% readable | Manual annotation of illegible fields |
| **Scan Artifacts** | <5% of form area | <10% | Rescan or preprocess |

### 5.2 Edge Case Handling

Training set MUST include edge cases:

| Edge Case | Example | Handling |
|-----------|---------|----------|
| **Smudged Ink** | Form with coffee spill over field | Include 2–3 samples; flag confidence |
| **Form Variation** | Different version of 10-3542 | Include 1–2 old versions; note revision |
| **Incomplete Fields** | N/A checkbox marked, field blank | Include 5 samples; flag expected_value=NULL |
| **Illegible Handwriting** | Cursive entries hard to read | Include 2–3 samples; manually annotate |
| **Field Misalignment** | Handwritten entry 1 inch off-grid | Include 1–2 samples; note offset |
| **Multiple Entries (Strike-through)** | "Army" crossed out, "Navy" written | Include 1 sample; clarify correct value |
| **Form Rotation** | Form scanned 90° sideways | Include 1 sample; test deskew preprocessing |

### 5.3 Validation Process

**Step-by-step validation** before AI Builder ingestion:

1. **Image Quality Check**
   - Validate DPI ≥300
   - Check file format (PNG/JPEG)
   - Verify file size 500KB–2MB
   - Test OCR preprocessing (sample 3 forms)

2. **Field Extraction Accuracy**
   - Manually verify 10% of annotated fields (4 forms)
   - Compare extracted_value vs. original form
   - Flag any mismatches for correction

3. **Confidence Score Validation**
   - Check confidence scores 0.0–1.0 range
   - Verify avg_confidence across dataset ≥0.80
   - Identify low-confidence fields (<0.75) for manual review

4. **Anonymization Audit**
   - Scan all JSON labels for PII (regex: SSN, email, phone patterns)
   - Verify no unmasked names in extracted_fields
   - Spot-check 5 forms for redacted signature images

5. **Dataset Balance Check**
   - Verify 70/15/15 split (28/6/6 forms)
   - Confirm coverage of all variation factors (handwriting, ink, conditions)
   - Check no duplicate forms in different splits

---

## 6. Data Storage & Access

### 6.1 Storage Location

**Primary Storage**: Azure Blob Storage (FormIntake container)  
**Backup**: SharePoint FormIntake library (sync'd daily)  
**Access Control**: Role-based (see Section 6.3)  
**Encryption**: AES-256 at rest, TLS 1.2+ in transit

**Azure Blob Path**:
```
FormIntake/TrainingDataset/
├── Forms/Training/
├── Forms/Validation/
├── Forms/Test/
├── Annotations/
└── Metadata/
```

**SharePoint Path**:
```
https://[tenant].sharepoint.com/sites/VAFormExtraction/
├── Shared Documents
│   └── FormIntake
│       └── TrainingDataset
```

### 6.2 Data Lifecycle

| Stage | Duration | Storage | Access | Status |
|-------|----------|---------|--------|--------|
| Collection | 7–14 days | Local disk + Blob temp | Michael Gray only | In Progress |
| Annotation | 3–5 days | Blob FormIntake | Michael Gray + AI Builder | Annotating |
| Validation | 2–3 days | Blob FormIntake | Michael Gray + Reviewers | Validating |
| AI Builder Training | 7–10 days | AI Builder dataset | AI Builder service | Training |
| Model Publishing | 1–2 days | AI Builder → Power Automate | Power Automate service | Published |
| Archive | 30+ days | Blob cold tier | Audit/compliance | Long-term storage |

### 6.3 Access Control Matrix

| Role | Training Set | Annotations | Metadata | Notes |
|------|--------------|-------------|----------|-------|
| Michael Gray (Owner) | RW | RW | RW | Full access |
| John Shelby (Flow Lead) | R | R | R | Needs to understand structure |
| Polly Gray (Schema) | R | R | R | Dataverse mapping reference |
| Grace Burgess (QA) | R | R | RW | Validation & metrics |
| AI Builder Service | R | R | R | Model training access |
| Tommy Shelby (Lead) | R | R | R | Oversight & approval |

**Access Restrictions**:
- ❌ Public/Anonymous: No access
- ❌ External partners: No access (confidential)
- ✅ Internal squad members: Read-only minimum
- ✅ Michael Gray: Admin for dataset management

---

## 7. Deliverables & Acceptance Criteria

### 7.1 Deliverable: TrainingDataset Folder

**Location**: `FormIntake/TrainingDataset/`  
**Contents**:
- ✅ 40–50 labeled VA Form 10-3542 samples
- ✅ 70% training (28 forms), 15% validation (6 forms), 15% test (6 forms)
- ✅ JSON label files (1 per form) with extracted fields & confidence scores
- ✅ dataset-manifest.csv tracking all samples
- ✅ Metadata files (field definitions, anonymization log, quality metrics)
- ✅ README.md with import instructions for AI Builder

### 7.2 Deliverable: Data Quality Report

**Location**: `specs/03-phase-2-stream-b/DATA-QUALITY-REPORT.md`  
**Contents**:
- Image preprocessing results (DPI, format, size)
- Field extraction accuracy (% by field type)
- Confidence score distribution (histogram)
- Edge case coverage (% of variation factors)
- Anonymization audit results (0 PII findings required)
- Validation checklist sign-off

### 7.3 Acceptance Criteria

✅ **Sample Data Collection** (#16)
- [ ] 40–50 VA Form 10-3542 samples collected
- [ ] Samples cover diverse handwriting, ink, paper conditions
- [ ] All samples anonymized (0 PII violations)
- [ ] 70% training / 15% validation / 15% test split
- [ ] All images 300 DPI PNG/JPEG format
- [ ] JSON label files for all forms with extracted fields & confidence scores

✅ **Data Quality Assurance**
- [ ] Avg. field extraction accuracy >95%
- [ ] Avg. confidence score >0.90
- [ ] Edge cases documented (smudged, handwritten, incomplete, etc.)
- [ ] Quality metrics checklist complete (OCR, clarity, coverage)
- [ ] Anonymization audit passed (0 PII in dataset)

✅ **Data Organization & Documentation**
- [ ] TrainingDataset folder structure created & populated
- [ ] dataset-manifest.csv with all 40+ samples listed
- [ ] field-definitions.json with schema for all extraction fields
- [ ] anonymization-log.json with masking rules applied
- [ ] quality-metrics.json with validation results
- [ ] README.md with AI Builder import instructions

✅ **Storage & Access**
- [ ] TrainingDataset uploaded to Azure Blob Storage (FormIntake container)
- [ ] SharePoint FormIntake library synced (backup)
- [ ] Access control configured (Squad members: Read, Michael Gray: Admin)
- [ ] Encryption at rest & in transit configured

---

## 8. Success Metrics & KPIs

### 8.1 Data Quality Metrics

| KPI | Target | Current | Status |
|-----|--------|---------|--------|
| **Sample Size** | 40–50 forms | TBD | 🟡 In Progress |
| **Average Confidence Score** | ≥0.90 | TBD | 🟡 In Progress |
| **Field Accuracy** | ≥95% across all fields | TBD | 🟡 In Progress |
| **Coverage** | All 10 variation factors | TBD | 🟡 In Progress |
| **Anonymization Audit** | 0 PII violations | TBD | 🟡 In Progress |
| **Image Quality** | 100% ≥300 DPI | TBD | 🟡 In Progress |

### 8.2 Timeline

| Milestone | Owner | Duration | Target Date |
|-----------|-------|----------|------------|
| Collect 20 samples | Michael Gray | 3 days | Apr 26 |
| Initial annotation | Michael Gray | 2 days | Apr 28 |
| Quality validation | Michael + Grace | 2 days | Apr 30 |
| Anonymization audit | Michael Gray | 1 day | May 1 |
| Final upload to Blob | Michael Gray | 0.5 days | May 1 |
| **COMPLETE** | | **~8.5 days** | **May 1** |

### 8.3 Risk Mitigation

| Risk | Probability | Impact | Mitigation |
|------|-----------|--------|------------|
| **Insufficient real samples** | High | High | Use synthetic data + form templates |
| **Poor image quality** | Medium | High | Pre-scan at 300 DPI; rescan if needed |
| **PII leakage** | Low | Critical | Regex scan + manual audit before release |
| **Low confidence fields** | Medium | Medium | Oversample edge cases; manual annotation |
| **Form variation** | Medium | Low | Document form version; include both |

---

## 9. Handoff & Next Steps

### 9.1 Data Readiness for Issue #17 (Model Training Strategy)

This dataset feeds Michael Gray's parallel issue #17:
- ✅ Training data ready → Model training can begin
- ✅ Field extraction targets defined → Model config file created
- ✅ Confidence scores established → Threshold validation set
- ✅ Edge cases documented → Retraining strategy informed

### 9.2 Data Readiness for Issue #18 (Flow Architecture)

John Shelby (#18) will use this dataset to:
- Understand field extraction JSON structure (for flow variables)
- Reference confidence thresholds (for decision logic)
- Know where training data stored (for model location in flow)

**Handoff Checklist for John**:
- [ ] JSON field structure matches Dataverse ExtractionResult schema
- [ ] Confidence thresholds (0.95, 0.85, 0.75) match flow logic
- [ ] Training data storage location documented
- [ ] Field definitions available for Power Automate mapping

### 9.3 Coordination with Polly Gray (Dataverse Schema)

Verify JSON structures align:

```json
// This format (from DATA-COLLECTION-STRATEGY.md)
{
  "extracted_fields": { "field_name": "value", ... },
  "field_confidence_scores": { "field_name": 0.95, ... }
}

// Matches Dataverse ExtractionResult table schema (from Polly's issue #12):
// - extracted_fields: JSON (large text field)
// - field_confidence_scores: JSON (large text field)
// ✅ Alignment confirmed
```

---

## 10. References & Resources

**VA Form 10-3542 Official Spec**: 
- Location: `specs/VA Form 10-3542 (form data into BTS3)/VA Form 10-3542 (form data into BTS3).pdf`
- Pages: 1–4 (Beneficiary Declaration sections)

**Related Documents**:
- [SCHEMA-DIAGRAM.md](../02-phase-2-stream-a/SCHEMA-DIAGRAM.md) — Dataverse relationships
- [TABLE-SPECIFICATIONS.md](../02-phase-2-stream-a/TABLE-SPECIFICATIONS.md) — ExtractionResult field schema
- [MODEL-TRAINING-STRATEGY.md](./MODEL-TRAINING-STRATEGY.md) — Issue #17 (parallel)

**External References**:
- Microsoft AI Builder documentation: https://docs.microsoft.com/power-platform/ai-builder/
- Azure Blob Storage guides: https://docs.microsoft.com/azure/storage/blobs/
- HIPAA de-identification standard: 45 CFR §164.512(k)

---

## Approval & Sign-Off

| Role | Name | Status | Date |
|------|------|--------|------|
| **Owner** | Michael Gray | ✅ Draft Complete | 2026-04-25 |
| **Reviewer** | Tommy Shelby | ⏳ Pending | — |
| **Approval** | Tommy Shelby | ⏳ Pending | — |

**Status**: 📋 **DRAFT - AWAITING PHASE GATE REVIEW**

---

**Created by**: Michael Gray, AI & ML Strategy Lead  
**Last Updated**: 2026-04-25  
**Next Review**: Upon Phase 2 Gate checkpoint (after issues #11-15 complete)
