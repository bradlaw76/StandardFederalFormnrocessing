# MANUAL PROVISIONING WALKTHROUGH
# VA Form Extraction Demo - Contact Center Environment
# healthconnectcenter.crm.dynamics.com

## ⚡ Quick Reference

**Environment URL:** https://healthconnectcenter.crm.dynamics.com/
**Admin Account:** admin@D365DemoTSCE80677168.onmicrosoft.com
**Solution Name:** VAFormExtractionDemo
**Publisher Prefix:** vafe

---

## 📋 TABLES TO CREATE (In Order)

| # | Table Name | Schema Name | Owner Type | Purpose |
|---|---|---|---|---|
| 1 | Form Submission | vafe_FormSubmission | User | Parent table - submission tracking |
| 2 | Extraction Result | vafe_ExtractionResult | User | AI extraction output (lookup to #1) |
| 3 | Audit Log | vafe_AuditLog | User | Compliance trail (lookup to #1) |
| 4 | D365 Write Event | vafe_D365WriteEvent | User | Sync tracking (lookup to #1) |
| 5 | Correction Record | vafe_CorrectionRecord | User | Manual corrections (lookup to #2) |

---

## 🚀 STEP-BY-STEP WALKTHROUGH

### Part 1: Create Solution Container

1. **Navigate to Power Apps**
   - Go to: https://make.powerapps.com
   - Select environment: **Contact Center** (healthconnectcenter.crm.dynamics.com)

2. **Create Solution**
   - Left sidebar: **Solutions**
   - Click: **+ New solution**
   - **Name:** VAFormExtractionDemo
   - **Publisher:** 
     - If new: Click "+ Publisher" → Name: "VA Form Extraction Demo" → Prefix: "vafe"
     - If exists: Select existing
   - **Version:** 1.0.0.0
   - Click: **Create**

3. **Verify Solution Created**
   - Solution now appears in solutions list
   - Status: "Managed: No", "Version: 1.0.0.0"

---

### Part 2: Create Table 1 - Form Submission

1. **Enter Solution**
   - Click on **VAFormExtractionDemo** solution
   - Click: **+ New** → **Table**

2. **Basic Info**
   - **Display name:** Form Submission
   - **Plural name:** Form Submissions
   - **Schema name:** vafe_FormSubmission
   - Owner: Leave as **User**
   - Description: "Tracks VA Form 10-3542 submissions through extraction lifecycle"

3. **Primary Column**
   - **Display name:** Form Submission
   - **Data type:** Autonumber (format: "VAFE-{SEQNUM:6}")
   - Keep other defaults

4. **Click: Create**

5. **Add Fields** (See: PROVISIONING-RUNBOOK.md Section 2.1 for exact field specs)
   - UploadDate (DateTime)
   - SourceFile (Single line of text, 255 chars)
   - Status (Choice: Intake, Extracting, Extracted, Correcting, Corrected, Writing, Written)
   - ProcessingNotes (Multi-line text, 2000 chars)
   - ProcessingStart (DateTime)
   - ProcessingEnd (DateTime)
   - ErrorDetails (Multi-line text, 2000 chars)
   - ProcessedBy (Lookup to User)
   - ProcessedTimestamp (DateTime)

---

### Part 3: Create Table 2 - Extraction Result

1. **Return to Solution**
   - Click: **VAFormExtractionDemo** (breadcrumb or sidebar)
   - Click: **+ New** → **Table**

2. **Basic Info**
   - **Display name:** Extraction Result
   - **Plural name:** Extraction Results
   - **Schema name:** vafe_ExtractionResult
   - Description: "Stores AI-extracted field data and confidence scores"

3. **Create Table**

4. **Add Fields**
   - FormSubmissionId (Lookup to Form Submission) ⭐ REQUIRED
   - ExtractedData (Multi-line text, 5000 chars)
   - FieldConfidenceScores (Multi-line text, 5000 chars) 
   - OverallConfidence (Decimal: 0-1, 5 decimal places)
   - ExtractionStatus (Choice: Success, PartialSuccess, Failed)
   - ModelVersion (Single line, 100 chars)
   - ExtractionTimestamp (DateTime)
   - ErrorMessage (Multi-line text, 2000 chars)

---

### Part 4: Create Table 3 - Audit Log

1. **Return to Solution**
   - Click: **+ New** → **Table**

2. **Basic Info**
   - **Display name:** Audit Log
   - **Plural name:** Audit Logs
   - **Schema name:** vafe_AuditLog
   - Description: "Immutable compliance audit trail (HIPAA/VA)"

3. **Create Table**

4. **Add Fields**
   - FormSubmissionId (Lookup to Form Submission) ⭐ REQUIRED
   - Action (Choice: Create, Read, Update, Delete)
   - Timestamp (DateTime)
   - UserId (Single line, 255 chars)
   - IPAddress (Single line, 45 chars)
   - Details (Multi-line text, 2000 chars)
   - ErrorCode (Single line, 50 chars)
   - Severity (Choice: Info, Warning, Error, Critical)
   - CorrelationId (Single line, 100 chars)

---

### Part 5: Create Table 4 - D365 Write Event

1. **Return to Solution**
   - Click: **+ New** → **Table**

2. **Basic Info**
   - **Display name:** D365 Write Event
   - **Plural name:** D365 Write Events
   - **Schema name:** vafe_D365WriteEvent
   - Description: "Tracks synchronization attempts to Dynamics 365 with retry logic"

3. **Create Table**

4. **Add Fields**
   - FormSubmissionId (Lookup to Form Submission) ⭐ REQUIRED
   - D365Status (Choice: Pending, Success, Failed, Retrying)
   - TimestampWritten (DateTime)
   - D365RecordId (Single line, 100 chars)
   - RetryCount (Whole number, 0+)
   - LastRetry (DateTime)
   - ErrorDetails (Multi-line text, 2000 chars)
   - PayloadSent (Multi-line text, 5000 chars)
   - HTTPStatusCode (Whole number, 100-599)

---

### Part 6: Create Table 5 - Correction Record

1. **Return to Solution**
   - Click: **+ New** → **Table**

2. **Basic Info**
   - **Display name:** Correction Record
   - **Plural name:** Correction Records
   - **Schema name:** vafe_CorrectionRecord
   - Description: "Tracks manual corrections made to low-confidence AI extractions"

3. **Create Table**

4. **Add Fields**
   - ExtractionResultId (Lookup to Extraction Result) ⭐ REQUIRED
   - FieldName (Single line, 255 chars)
   - OriginalValue (Multi-line text, 2000 chars)
   - CorrectedValue (Multi-line text, 2000 chars)
   - CorrectionDate (DateTime)
   - ReviewedBy (Lookup to User)
   - CorrectionStatus (Choice: Pending, Approved, Rejected)
   - CorrectionNotes (Multi-line text, 2000 chars)
   - FieldConfidence (Decimal: 0-1, 5 decimal places)
   - ReviewSLA (Whole number, minutes)

---

## 🔗 Part 7: Create Relationships

Once all 5 tables exist, create these 1:N lookups:

| From | To | Type | Cascade Delete |
|---|---|---|---|
| Form Submission | Extraction Result | 1:N | ✅ Yes |
| Form Submission | Audit Log | 1:N | ✅ Yes |
| Form Submission | D365 Write Event | 1:N | ✅ Yes |
| Extraction Result | Correction Record | 1:N | ✅ Yes |

---

## ✅ VERIFICATION CHECKLIST

After all tables created:

- [ ] All 5 tables appear in solution
- [ ] All fields present with correct data types
- [ ] All lookups created with cascade delete enabled
- [ ] Solution version still 1.0.0.0
- [ ] Solution shows "Managed: No"

**Estimated Time:** 45-60 minutes

---

## 📝 REFERENCE

**Full Details:** See `specs/02-phase-2-stream-a/PROVISIONING-RUNBOOK.md`

**Power Apps Documentation:** https://learn.microsoft.com/power-apps/maker/data-platform/create-edit-metadata

