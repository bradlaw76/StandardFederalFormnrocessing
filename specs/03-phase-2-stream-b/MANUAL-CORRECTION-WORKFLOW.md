# Manual Correction Workflow Guide
**Issue #18 — Stream B-2: Human Review Process**  
**Owner**: John Shelby, Flow Orchestration Lead  
**Date**: 2026-04-25

---

## Overview

When AI extraction confidence falls below **0.85** (average), the form enters **Manual-Correction-Queue** for human review. This document defines the end-to-end workflow for data entry teams to review, correct, and approve form data before D365 synchronization.

---

## Workflow Summary

```
Form Extracted (Low Confidence)
    ↓
[CorrectionRecord created for each low-confidence field]
    ↓
[Teams notification posted → @mention reviewer]
    ↓
[Reviewer opens Dataverse form in Power Apps]
    ↓
[Reviewer reviews AI extraction vs. original form image]
    ↓
[Reviewer corrects fields & marks as Reviewed]
    ↓
[Correction-Queue subflow validates corrections]
    ↓
[Corrected data retried to D365]
    ↓
[Notification of completion sent]
```

---

## Key Actors & Responsibilities

| Actor | Role | Responsibility |
|-------|------|-----------------|
| **Data Entry Team (Level 1)** | Frontline Reviewer | Review & correct low-confidence fields |
| **QA Lead (Level 2)** | Quality Reviewer | Spot-check corrections for accuracy |
| **Operations Admin (Level 3)** | Escalation Owner | Handle overdue/disputed corrections |
| **Flow Orchestration (John)** | System Owner | Monitor queue health, adjust thresholds |

---

## Correction Record Anatomy

### CorrectionRecord Table Schema

```
vafe_correctionrecord:

├─ vafe_correction_id (Auto ID)
│  └─ Example: CR-00001
│
├─ vafe_extraction_result (Lookup → ExtractionResult)
│  └─ Links to original AI extraction output
│
├─ vafe_field_name (Text)
│  └─ Example: "veteran_dob"
│
├─ vafe_original_value (Text)
│  └─ What AI extracted: "1/15/1960"
│
├─ vafe_corrected_value (Text)
│  └─ What reviewer corrected to: "01/15/1960" (formatted)
│
├─ vafe_confidence_before (Decimal: 0.0–1.0)
│  └─ Example: 0.78 (below threshold)
│
├─ vafe_confidence_after (Decimal: 0.0–1.0)
│  └─ Example: 1.0 (manual correction = highest confidence)
│
├─ vafe_corrected_by (Lookup → User)
│  └─ Who made the correction (data entry staff)
│
├─ vafe_correction_date (Date Time)
│  └─ When correction was made
│
├─ vafe_status (Choice)
│  ├─ Pending (100000000) — Waiting for review
│  ├─ InReview (100000001) — Reviewer has opened
│  ├─ Disputed (100000002) — Reviewer disagrees, escalated
│  └─ Applied (100000003) — Approved, ready for D365 retry
│
├─ vafe_reason (Text)
│  └─ Why correction was needed: "LowConfidence - Manual Review Required"
│
├─ vafe_reviewer_notes (Multiple Lines of Text)
│  └─ Optional: Reviewer comments (e.g., "Handwriting was unclear, found SSN in signature block")
│
└─ vafe_retry_count (Whole Number)
   └─ How many times D365 write was retried after correction
```

---

## Step-by-Step Correction Workflow

### Step 1: Form Enters Low-Confidence State

**Trigger**: AI extraction average confidence < 0.85

**What Happens**:
1. Main flow (Step 3) detects low-confidence fields
2. For each field with confidence < 0.85:
   - CorrectionRecord created with status = "Pending"
   - Original value stored
   - Field confidence score captured
3. FormSubmission status = "PendingCorrectionReview"
4. Teams notification posted

**Example**:
```
Form: vafe_10001_2026-04-25_smith-john.pdf
Average Confidence: 0.82 (below 0.85 threshold)

Low-Confidence Fields:
├─ veteran_dob: 0.78 confidence → Extracted "1/15/1960"
├─ ssn: 0.82 confidence → Extracted "123-45-6789"
└─ service_number: 0.74 confidence → Extracted "VA-00123456"

→ 3 CorrectionRecords created (Pending)
```

---

### Step 2: Reviewer Receives Teams Notification

**Who**: Data Entry Team Lead (or assigned reviewer)

**Notification Card** (posted to #va-form-extraction-reviews):
```json
{
  "type": "message",
  "attachments": [{
    "contentType": "application/vnd.microsoft.card.adaptive",
    "content": {
      "type": "AdaptiveCard",
      "body": [
        {
          "type": "TextBlock",
          "size": "Large",
          "weight": "Bolder",
          "text": "📋 VA Form Correction Required"
        },
        {
          "type": "TextBlock",
          "text": "Form ID: vafe_10001 | Avg Confidence: 82% (below 85% threshold)"
        },
        {
          "type": "TextBlock",
          "text": "Low-Confidence Fields Requiring Review:",
          "weight": "Bolder"
        },
        {
          "type": "Table",
          "columns": [
            { "width": "25%" },
            { "width": "40%" },
            { "width": "35%" }
          ],
          "rows": [
            [
              { "items": [{ "type": "TextBlock", "text": "Field Name", "weight": "Bolder" }] },
              { "items": [{ "type": "TextBlock", "text": "Extracted Value", "weight": "Bolder" }] },
              { "items": [{ "type": "TextBlock", "text": "Confidence", "weight": "Bolder" }] }
            ],
            [
              { "items": [{ "type": "TextBlock", "text": "veteran_dob" }] },
              { "items": [{ "type": "TextBlock", "text": "1/15/1960" }] },
              { "items": [{ "type": "TextBlock", "text": "78%" }] }
            ],
            [
              { "items": [{ "type": "TextBlock", "text": "ssn" }] },
              { "items": [{ "type": "TextBlock", "text": "123-45-6789" }] },
              { "items": [{ "type": "TextBlock", "text": "82%" }] }
            ],
            [
              { "items": [{ "type": "TextBlock", "text": "service_number" }] },
              { "items": [{ "type": "TextBlock", "text": "VA-00123456" }] },
              { "items": [{ "type": "TextBlock", "text": "74%" }] }
            ]
          ]
        },
        {
          "type": "TextBlock",
          "text": "Review the original form image and correct any errors. Click button below to open review form."
        }
      ],
      "actions": [
        {
          "type": "Action.OpenUrl",
          "title": "🔍 Open Form for Review",
          "url": "https://apps.powerapps.com/play/e/{environment-id}/a/{app-id}?tenantId={tenant-id}"
        },
        {
          "type": "Action.OpenUrl",
          "title": "📄 View Original PDF",
          "url": "https://tenantname.sharepoint.com/sites/va-form-extraction/FormIntake/vafe_10001_2026-04-25_smith-john.pdf"
        }
      ]
    }
  }]
}
```

**Action**: Reviewer clicks **"Open Form for Review"** → Opens Power Apps model-driven form

---

### Step 3: Reviewer Opens Correction Form in Power Apps

**Interface**: Power Apps Model-Driven Form (Correction Form)

**Form Layout**:
```
┌─────────────────────────────────────────────────────┐
│ VA Form 10-3542 Correction Review                   │
├─────────────────────────────────────────────────────┤
│                                                      │
│ Form ID: vafe_10001                                │
│ Original File: vafe_10001_2026-04-25_smith-john.pdf│
│ Submitted: 2026-04-25 10:15 AM                     │
│ Avg Confidence: 82%                                │
│                                                      │
├─ TAB 1: CORRECTIONS ────────────────────────────────┤
│                                                      │
│ ┌─ Field 1: veteran_dob ─────────────────────────┐ │
│ │ AI Extracted: 1/15/1960                        │ │
│ │ Confidence: 78%  ⚠️ (Below threshold)          │ │
│ │ [Text input] → Corrected Value: _____________  │ │
│ │ Notes: [Optional text for reviewer feedback]   │ │
│ │ Status: [ ] Mark as Reviewed                   │ │
│ └────────────────────────────────────────────────┘ │
│                                                      │
│ ┌─ Field 2: ssn ─────────────────────────────────┐ │
│ │ AI Extracted: 123-45-6789                      │ │
│ │ Confidence: 82%  ⚠️ (Below threshold)          │ │
│ │ [Text input] → Corrected Value: _____________  │ │
│ │ Notes: [Optional text for reviewer feedback]   │ │
│ │ Status: [ ] Mark as Reviewed                   │ │
│ └────────────────────────────────────────────────┘ │
│                                                      │
│ ┌─ Field 3: service_number ──────────────────────┐ │
│ │ AI Extracted: VA-00123456                      │ │
│ │ Confidence: 74%  ⚠️ (Below threshold)          │ │
│ │ [Text input] → Corrected Value: _____________  │ │
│ │ Notes: [Optional text for reviewer feedback]   │ │
│ │ Status: [ ] Mark as Reviewed                   │ │
│ └────────────────────────────────────────────────┘ │
│                                                      │
├─ TAB 2: ORIGINAL PDF ──────────────────────────────┤
│ [Embedded PDF viewer showing original form]         │
│ [Reviewer can reference while filling corrections] │
│                                                      │
├─ TAB 3: FULL EXTRACTION ──────────────────────────┤
│ [All 32+ extracted fields listed (read-only)]       │
│ [Useful for context about other fields]            │
│                                                      │
├─────────────────────────────────────────────────────┤
│ [Save Corrections] [Submit for Approval] [Dispute]  │
└─────────────────────────────────────────────────────┘
```

---

### Step 4: Reviewer Reviews Original Form & Corrects Values

**Process**:

1. **Open Tab 2** (Original PDF) → Compare to extracted values
   - Example: Original form shows "01/15/1960" (handwritten)
   - AI extracted as "1/15/1960" (missing leading zero)
   - Reviewer corrects: "01/15/1960"

2. **For Each Low-Confidence Field**:
   - Read original form image
   - Compare to AI extracted value
   - If different: Type corrected value in text field
   - If correct: Leave as-is (default)
   - Optional: Add notes (e.g., "Handwriting was smudged, referred to printed section C")

3. **Mark Field as Reviewed**:
   - Check checkbox: "Mark as Reviewed"
   - This updates CorrectionRecord.status = "InReview"

**Example Corrections**:
```
Field 1: veteran_dob
├─ AI Value: "1/15/1960"
├─ Original Form: Shows "01/15/1960"
├─ Reviewer Corrects to: "01/15/1960"
├─ Reason: "Leading zero was missing in extraction"
└─ Confidence After: 1.0 (manual review = high confidence)

Field 2: ssn
├─ AI Value: "123-45-6789"
├─ Original Form: Shows "123-45-6789" (matches)
├─ Reviewer: No correction needed (confirm as-is)
└─ Confidence After: 1.0 (manual confirmation)

Field 3: service_number
├─ AI Value: "VA-00123456"
├─ Original Form: Shows "VA-00123456" (matches)
├─ Reviewer: No correction needed (confirm as-is)
└─ Confidence After: 1.0 (manual confirmation)
```

---

### Step 5: Reviewer Submits Corrections

**Action**: Click **"Submit for Approval"** button

**What Happens**:
1. All CorrectionRecords with status = "InReview" are marked as "Applied"
2. vafe_corrected_value populated with reviewer input
3. vafe_corrected_by = current user (reviewer)
4. vafe_correction_date = now()
5. vafe_confidence_after = 1.0 (manual review = highest confidence)

**Validation Rules** (enforced by form):
- [ ] All low-confidence fields must be reviewed (no blanks)
- [ ] Corrected values must match expected data type (e.g., date format for DOB)
- [ ] At least one correction or confirmation per field

**On Success**:
- Correction-Queue subflow triggered
- Flow re-extracts ExtractionResult with corrected values
- D365 write retried with corrected data

---

### Step 6a: Correction Approved & Retried

**Notification**: Reviewer receives Teams message confirming submission

```
✅ Corrections Submitted Successfully

Form: vafe_10001
Reviewer: John Smith
Submitted: 2026-04-25 10:45 AM
Corrections: 3 fields corrected
Status: Now retrying D365 write with corrected data...

Next: You'll receive a notification once the form is written to D365.
```

**Behind the Scenes**:
1. Correction-Queue subflow:
   - Validates all corrections
   - Updates ExtractionResult JSON with corrected values
   - Constructs new D365 payload with corrected data

2. Main flow (Step 4 retry):
   - Calls D365 API with corrected payload
   - D365 write succeeds (corrected values pass validation)
   - FormSubmission status = "Written"
   - AuditLog event: "CorrectionApplied + D365WriteSuccess"

3. Notification:
   - Teams message sent: "✅ Form Successfully Written to D365"
   - FormSubmission marked as complete

---

### Step 6b: Correction Disputed (Alternative Path)

**If reviewer clicks "Dispute"**:

**Dispute Form**:
```
┌──────────────────────────────────────────┐
│ Dispute Correction Record                 │
├──────────────────────────────────────────┤
│                                           │
│ Field: veteran_dob                       │
│ AI Extracted: 1/15/1960                  │
│ Reviewer Believes: ________________       │
│ Reason for Dispute: _________________    │
│ [Free text — what's wrong with AI value] │
│                                           │
│ Should This Form Be:                     │
│ ( ) Recategorized as high-confidence     │
│ ( ) Re-extracted by updated AI model     │
│ ( ) Escalated to Admin for decision      │
│                                           │
│ [Submit Dispute]                         │
└──────────────────────────────────────────┘
```

**What Happens**:
1. CorrectionRecord status = "Disputed"
2. FormSubmission status = "DisputedPendingEscalation"
3. Escalation task created → assigned to Operations Admin
4. Admin reviews dispute & makes decision:
   - **Accept AI value** → Proceed with AI extraction (bypass review)
   - **Accept corrected value** → Proceed with correction
   - **Re-extract** → Send form back to AI model for retry
   - **Manual entry** → Route to manual data entry team

---

## Correction Queue Monitoring Dashboard

### Power BI Dashboard (Optional for Operations)

**Metrics Displayed**:
```
┌─────────────────────────────────────────┐
│ VA Form Correction Queue Status         │
├─────────────────────────────────────────┤
│                                          │
│ Pending Reviews: 15 forms                │
│ In Progress: 3 forms (being reviewed)    │
│ Disputed: 2 forms (escalated)            │
│ Completed (Today): 42 forms              │
│ Avg Review Time: 8 minutes               │
│ Overdue (>30 min): 1 form ⚠️             │
│                                          │
│ By Confidence Level:                     │
│ ├─ 0.75–0.85: 25 forms                  │
│ ├─ 0.80–0.85: 12 forms                  │
│ └─ 0.85–0.90: 6 forms                   │
│                                          │
│ Reviewers Activity:                      │
│ ├─ John Smith: 18 corrections (82% acc) │
│ ├─ Jane Doe: 14 corrections (91% acc)   │
│ └─ Bob Wilson: 10 corrections (75% acc) │
│                                          │
└─────────────────────────────────────────┘
```

**Drilldown**: Click on form → View full correction details, audit trail

---

## SLA & Escalation

### Correction SLA

| Metric | Target | Action if Exceeded |
|--------|--------|-------------------|
| **Time to Assign** | <2 min | Auto-assign to next available reviewer |
| **Time to Review** | <30 min | Escalate to QA lead for expedited handling |
| **Time to Approve** | <1 hour total | Escalate to Operations admin |
| **Time to D365 Retry** | <5 min after approval | Auto-retry via D365-Retry-Logic flow |

### Escalation Path

```
Pending Review (30 min) → QA Lead Review (60 min) → Admin Escalation
                                                         │
                                                    Decision:
                                                    ├─ Accept AI
                                                    ├─ Manual Entry
                                                    ├─ Re-extract
                                                    └─ Reject & notify submitter
```

---

## Sample Scenarios

### Scenario 1: Handwriting Correction

**Original Form**: Shows handwritten date "01/15/1960"  
**AI Extraction**: "1/15/1960" (missed leading zero)  
**Confidence**: 78%

**Correction Process**:
1. Reviewer opens form, sees PDF with handwritten date
2. Compares: AI "1/15/1960" vs. Form "01/15/1960"
3. Corrects: Enters "01/15/1960" in correction field
4. Submits: Clicks "Submit for Approval"
5. Validation: Passes (correct date format YYYY-MM-DD or MM/DD/YYYY)
6. Result: CorrectionRecord marked "Applied", D365 retried with corrected value

---

### Scenario 2: Confident AI, No Correction Needed

**Original Form**: Shows printed "VA-00123456" clearly  
**AI Extraction**: "VA-00123456"  
**Confidence**: 88% (already above 0.85!)

**Why is this in correction queue?**
- Average confidence across all fields was 82% (some other field pulled it below 0.85)
- This particular field was above threshold but still routed to queue for review

**Correction Process**:
1. Reviewer reviews field
2. Confirms: AI value matches original form
3. Leaves corrected value blank (or confirms as-is)
4. Submits: CorrectionRecord marked "Applied" with confidence_after = 1.0 (manual confirmation)
5. Result: D365 write retried with original AI value (now confirmed)

---

### Scenario 3: Disputed Correction

**Original Form**: Smudged/unclear handwriting for SSN  
**AI Extraction**: "123-45-6789"  
**Confidence**: 72%

**Correction Process**:
1. Reviewer opens form, sees smudged area
2. Cannot confidently read SSN
3. Clicks "Dispute" button
4. Selects reason: "Cannot read handwriting clearly"
5. Selects action: "Escalate to Admin for decision"
6. Escalation task created for Operations admin

**Admin Decision**:
- Options: 
  1. Accept AI value (assume 123-45-6789 is correct)
  2. Mark for manual entry (route to data entry team)
  3. Reject form (return to submitter for re-submission)
- Admin chooses: "Route to manual data entry team"
- New task created for manual entry specialist

---

## Reviewer Best Practices

### Tips for Accurate Corrections

1. **Compare carefully**: Use split screen (Form + PDF tab) to reference original
2. **Check data types**: Ensure corrected value matches expected format
   - DOB: MM/DD/YYYY or YYYY-MM-DD
   - SSN: XXX-XX-XXXX
   - Phone: (XXX) XXX-XXXX or XXX-XXX-XXXX
3. **Note unusual situations**: Use reviewer notes for edge cases
4. **Don't guess**: If genuinely unsure, dispute rather than guess
5. **Batch similar corrections**: Review similar confidence levels together for consistency

### Data Validation Rules

**Date Fields** (DOB, Service Dates):
- Format: MM/DD/YYYY or YYYY-MM-DD
- Range: No dates >100 years in past or future
- Sanity check: Service start date < service end date

**SSN / Service Number**:
- Format: XXX-XX-XXXX (with dashes)
- No all-zeros (000-00-0000)
- No sequential patterns (111-11-1111)

**Name Fields**:
- Capitalization: First letter of each word capitalized
- Length: 1–50 characters
- No special characters except hyphen, apostrophe, space

**Email**:
- Format: user@domain.extension
- Domain must be valid

---

## Training for Data Entry Team

### Training Topics

1. **Overview**: Why corrections matter (compliance, data quality)
2. **Interface**: Power Apps form navigation & fields
3. **Comparison**: How to read original form vs. AI extraction
4. **Data Types**: Field formats & validation rules
5. **Edge Cases**: Handwriting, smudges, ambiguous characters
6. **Dispute Handling**: When & how to escalate
7. **SLA**: Performance metrics & targets

### Hands-On Practice

1. Sample form with 5 pre-marked low-confidence fields
2. Reviewer corrects sample form (supervised)
3. Corrections reviewed by QA lead
4. Feedback provided & signed off

---

## Metrics & Continuous Improvement

### Track These Metrics

| Metric | Target | Current | Action |
|--------|--------|---------|--------|
| **Correction Accuracy** | >95% | ? | If <95%, review training |
| **Avg Review Time** | <10 min | ? | If >15 min, check volume or training |
| **Disputes/Month** | <5% | ? | If >5%, review confidence thresholds |
| **Overdue Reviews** | 0% | ? | If >0%, add reviewers or escalate faster |
| **D365 Write Success** | >98% | ? | If <98%, review correction quality |

### Monthly Review

1. **Accuracy Audit**: QA lead spot-checks 10% of corrections
2. **Trend Analysis**: Review most common correction types
3. **Threshold Adjustment**: If dispute rate >5%, consider lowering confidence threshold
4. **Reviewer Performance**: Identify training needs, recognize high performers

---

## FAQ for Reviewers

**Q: Can I correct a field to blank?**  
A: No. If the form shows no value, mark "No value present" in notes. Don't leave blank.

**Q: What if I think the AI was right and don't need to correct?**  
A: Mark as reviewed (confirms the value). Corrected value can be left blank = no correction needed.

**Q: How long do I have to correct a form?**  
A: Target: <30 minutes from assignment. Escalates to QA lead if >30 min.

**Q: Can I undo a correction after submitting?**  
A: No (immutable). If you made a mistake, open a dispute explaining the error. Admin will decide.

**Q: What if the original form is illegible?**  
A: Dispute the correction. Select "Cannot read form clearly" → Escalate to admin.

**Q: Do I need to correct ALL low-confidence fields?**  
A: Yes. For each field, either correct it or confirm the AI value (by marking reviewed).

---

## Support & Escalation

**For Questions/Issues**:
1. Check FAQ above
2. Contact QA Lead: qa@va-form-extraction (Teams @qa-lead-channel)
3. For urgent: @operations-admin in Teams

**For System Issues** (flow not triggering, form not opening, etc.):
1. Contact IT Help Desk: it-support@va-form-extraction
2. Reference: FormSubmissionID & timestamp of issue

---

**Status**: ✅ **MANUAL CORRECTION WORKFLOW GUIDE COMPLETE**

**Prepared by**: John Shelby, Flow Orchestration Lead  
**Date**: 2026-04-25  
**Audience**: Data Entry Team, QA Lead, Operations Admin  
**Ready for**: Phase 2 deployment & team training
