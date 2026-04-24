# Research: Power Platform Setup, AI Builder Demo, Dataverse Schema

**Feature**: VA Form 10-3542 Extraction Pipeline  
**Date**: 2026-04-24  
**Scope**: Phase 0 technical research for Power Platform demo (low-code/no-code)

---

## 1. AI Builder Model Training on 5 Forms

### Research Question
How to train an AI Builder custom document extraction model with only 5 VA forms? What accuracy is achievable?

### Findings

**AI Builder Training Process**:
1. Create new "Form Processing" model in AI Builder
2. Upload 5 completed VA Form 10-3542 PDFs (mix handwritten + typed if possible)
3. Manually label key fields on each form in AI Builder UI (~5 min per form)
4. Train model (~10 seconds automatic training)
5. Test on validation set (if available); iterate if needed
6. Publish model to Dataverse for use in flows

**Expected Accuracy**:
- **5 forms (minimum)**: ~60–75% accuracy (proof-of-concept only)
- **50 forms (recommended)**: ~90%+ accuracy (production-ready)
- **Approach for demo**: Accept ~70% accuracy; use manual correction for low-confidence fields

**Confidence Score Behavior**:
- AI Builder returns 0–100 confidence score per field
- Recommended thresholds:
  - ≥95%: Auto-approve, skip manual review
  - 70–94%: Route to manual review (correction UI)
  - <70%: Mark as "manual extraction required" (staff fills in all fields)

**Timeline**:
- Collect 5 forms: 1 day
- Annotate in AI Builder: 1–2 hours
- Train model: 5 minutes
- Test + iterate: 2 hours
- **Total**: ~1 day

### Decision
✅ **Train AI Builder model on 5 VA forms (minimum for demo); accept ~70% accuracy; route low-confidence fields to manual review UI. Plan for future retraining with larger dataset (50+ forms).**

---

## 2. Dataverse Schema Design

### Research Question
How to design Dataverse tables to support form intake → extraction → correction → D365 write workflow?

### Findings

**Entity Relationships**:

```
FormSubmission (parent)
  ├─ ExtractionResult (child, 1:1 in typical flow)
  │   └─ CorrectionRecord (child, optional, 0–1 per extraction)
  └─ AuditLog (child, many records per form)

D365 Integration:
  └─ FormSubmission.SyncedToD365 (lookup to D365 record)
```

**Table Sizing** (for 5-form demo):
- FormSubmission: 5 rows + future growth
- ExtractionResult: 5 rows
- CorrectionRecord: 0–5 rows (depends on manual review)
- AuditLog: 20–50 rows (multiple events per form)

**Dataverse Capacity**:
- Table rows: Unlimited (governed by storage capacity)
- Storage: 10 GB default per Power Platform environment
- For demo: 5 forms will use <1 MB (plenty of headroom)

**Audit Trail Options**:
- **Option A (Recommended for demo)**: Create custom AuditLog table; log manually in flows
- **Option B**: Use Dataverse built-in audit feature (System-managed, view-only)
- **For demo**: Use Option A (more visibility + control)

### Decision
✅ **Create 4 Dataverse tables (FormSubmission, ExtractionResult, CorrectionRecord, AuditLog). Relationships: FormSubmission → ExtractionResult (1:1), ExtractionResult → CorrectionRecord (optional 0:1), FormSubmission → AuditLog (1:many). Use custom logging (not system audit) for demo.**

---

## 3. Power Automate Flow Architecture

### Research Question
How to orchestrate form intake → AI Builder extraction → confidence routing → D365 write using Power Automate flows?

### Findings

**Flow Design Pattern** (Recommended):

| Flow | Trigger | Logic | Next Step |
|------|---------|-------|-----------|
| **Flow 1: Intake** | SharePoint file created | Validate PDF + store in Dataverse + set Status = "Extracting" | Call Flow 2 |
| **Flow 2: Extraction** | Called from Flow 1 | Call AI Builder API + parse response + create ExtractionResult | Decision: ≥95% → Flow 4; <95% → Queue manual review |
| **Flow 3: Manual Approval** | Power Apps button click | Read CorrectionRecord + call Flow 4 | Trigger D365 write |
| **Flow 4: D365 Write** | Called from Flow 2 or 3 | Call D365 connector + create record + log status | Complete |

**Error Handling**:
- **Retry policy**: Power Automate built-in retry (3 attempts, exponential backoff)
- **Timeout**: 30 seconds per flow action
- **Failed actions**: Log to AuditLog table; send email alert

**Testing Flows**:
- Manual trigger (cloud flows allow manual test run)
- Test with sample PDF
- Verify Dataverse tables populated
- Verify D365 table receives data

### Decision
✅ **4 Power Automate flows: Intake (SharePoint trigger) → Extraction (call AI Builder) → Approval (if needed) → D365 Write (call D365 connector). Use built-in error handling + manual logging to AuditLog.**

---

## 4. Power Apps Correction Form UI

### Research Question
How to build a low-code Power Apps canvas form for VA staff to correct extracted fields?

### Findings

**Power Apps Canvas App Structure**:

```
Screen 1: Home
├─ Gallery: Shows all FormSubmission records with Status = "ReviewRequired"
└─ Button: "Review Form" → Navigate to Screen 2

Screen 2: Correction Form
├─ Text input: Beneficiary Name (pre-filled from ExtractionResult)
├─ Text input: SSN (pre-filled, masked)
├─ Date picker: Travel From Date
├─ Date picker: Travel To Date
├─ Text input: Destination
├─ Text input: Reason for Travel
├─ Text input: Authorized By
├─ Dropdown: Benefit Type
├─ Labels: Show AI confidence score for each field
└─ Buttons:
   ├─ "Approve" → Create CorrectionRecord + Trigger D365 Write Flow
   ├─ "Reject" → Mark form as rejected; ask reason
   └─ "Back" → Return to home

Screen 3: Confirmation
├─ Summary of changes
├─ "Submit" → Confirm and trigger D365 write
└─ "Cancel" → Return to correction form
```

**Validation Rules** (optional for demo):
- SSN: Format ###-##-#### (can skip for demo)
- Dates: TravelToDate ≥ TravelFromDate
- Name: Required, max 100 chars

**Accessibility** (Phase 2, not needed for demo):
- Keyboard navigation
- Screen reader support
- Color contrast

### Decision
✅ **Build Power Apps canvas app with 3 screens (home gallery → correction form → confirmation). Pre-fill with ExtractionResult data. Show AI confidence scores. Approval button triggers D365 Write flow. No validation logic for demo (manual validation acceptable).**

---

## 5. D365 Integration via Dataverse

### Research Question
How to sync corrected data from Dataverse to Dynamics 365 table using Power Automate D365 connector?

### Findings

**D365 Connector Options**:
- **Option A (Recommended)**: D365 connector in Power Automate (native, built-in)
- **Option B**: OData connector (lower-level, requires manual mapping)

**D365 Connector Setup**:
1. Add "Create a new record" action (D365 connector)
2. Select table: VA_FormSubmission (assuming this table exists in D365)
3. Map fields: 
   - BeneficiaryName → va_beneficiary_name
   - SSN → va_ssn
   - TravelFromDate → va_travel_from_date
   - [etc.]
4. Handle errors: Retry built-in; on failure, log to AuditLog + send alert

**Error Scenarios**:
- **Duplicate SSN**: D365 may reject if SSN already exists; handle with lookup + update logic
- **Missing lookup table**: If Destination or BenefitType reference D365 lookup tables, Flow must map correctly
- **Throttling**: D365 throttles at ~2K requests/minute (per org); demo won't hit this limit

**Testing D365 Sync**:
- Manually trigger correction form approval
- Verify D365 table receives record
- Verify Dataverse status updated to "Complete"

### Decision
✅ **Use D365 connector in Power Automate (native). Map Dataverse ExtractionResult fields to D365 VA_FormSubmission table columns. Handle errors with retry + AuditLog logging. Test manually (no automated testing for demo).**

---

## 6. Cost & Timeline Estimate (Demo)

**Timeline**:
```
Day 1: Collect 5 VA forms + annotate in AI Builder (~1 day)
Day 2: Create Dataverse schema + build Power Automate flows (~4–6 hours)
Day 3: Build Power Apps correction form + test end-to-end (~4–6 hours)
────────────────────────────────────────────────────────
Total: ~2–3 days (1 person)
```

**Cost (Azure/Microsoft 365 licensing only)**:
- Power Platform subscription: Already included in Microsoft 365 E3+ or standalone $200/month
- AI Builder capacity: Already included (5 forms uses minimal capacity)
- D365 license: Already included (assuming org has D365)
- No infrastructure costs (all SaaS, no VMs, databases, storage)

**Demo-Only Costs**:
- Minimal; mainly licensing
- No development cost (low-code, no custom code)

---

## 8. Contact Matching Strategy (NEW)

### Research Question
How to automatically match extracted claimant/veteran information to existing Dataverse Contacts table? What matching confidence is required for production use?

### Findings

**Contact Matching Purpose**:
- **Deduplication**: Prevent duplicate veteran/beneficiary records in Dataverse
- **Data enrichment**: Pre-populate known beneficiary attributes (phone, email, address history)
- **Compliance**: Link form to existing contact record for audit trail
- **Efficiency**: Auto-fill contact ID → reduce D365 write friction

**Matching Algorithm Options**:

| Approach | Accuracy | Implementation | Demo Ready? |
|----------|----------|-----------------|-------------|
| **Exact SSN Match** | 99%+ | Hash comparison (case-sensitive) | ✅ Yes |
| **Fuzzy Name + DOB** | 85–95% | LevenshteinDistance or SQL SOUNDEX | ⏳ Phase 2 |
| **Phone Number Match** | 90%+ | Direct string comparison | ⏳ Phase 2 |
| **ML-based Deduplication** | 98%+ | Azure ML or Dynamics 365 deduplication rules | ⏳ Phase 2+ |

**Recommended for Demo: Exact SSN Match + Fallback to Name + DOB**

```
Priority 1: IF ClaimantSSN confidence ≥90% THEN
  └─ Query Contacts WHERE ssn_hashed = HASH(ClaimantSSN)
  └─ Confidence: 99% (SSN is unique identifier)

Priority 2: IF NO SSN MATCH AND (ClaimantFullName + DOB) confidence ≥90% THEN
  └─ Query Contacts WHERE 
      (FirstName + " " + LastName) CONTAINS ClaimantFullName
      AND birthdate = ClaimantDateOfBirth
  └─ Confidence: 85–90% (high specificity)

Priority 3: IF NO MATCH FOUND THEN
  └─ Set ContactMatchConfidence = 0
  └─ Flag for manual review (new contact? or unmatchable?)
```

**Power Automate Implementation** (Demo):
- Query Contacts table via Dataverse connector
- Use "List records" action with filter condition (SSN or Name + DOB)
- Store matched contact ID in ExtractionResult.ClaimantContactID
- If no match, leave null and set flag

**SSN Hashing Strategy** (PII Protection):
- **Approach**: Hash SSN using SHA-256 before comparing
- **Dataverse Contact table**: Assume it has ssn_hashed column (pre-computed)
- **AI Builder extraction**: Hash the extracted raw SSN in-flight (Power Automate)
- **Comparison**: Hash-to-hash (never expose raw SSNs in queries)
- **Cost**: Negligible (hash computation is fast)

**Demo Limitation**: If Dataverse Contact table does NOT have pre-computed SSN hashes:
- For demo only: Store raw SSN in Contact table (not recommended)
- Phase 2: Implement SSN hashing + migration script to hash all existing SSNs

### Decision
✅ **Implement basic contact matching for demo: (1) Exact SSN match (if confidence ≥90%), (2) Fallback to Name + DOB match. Store matched contact ID in ExtractionResult. Log all match attempts to AuditLog. Phase 2: Implement fuzzy name matching + ML-based deduplication.**

---

## 7. Known Limitations (Demo Only)

- **AI Accuracy**: ~70% with 5 forms (will need manual correction for ~30% of fields)
- **No automated testing**: All testing manual (acceptable for demo)
- **No production audit trail**: Basic Dataverse logging only (not immutable ledger)
- **No scaling**: Single D365 environment; not tested for high volume
- **No failover**: No redundancy or disaster recovery (acceptable for demo)

---

## Summary: Key Technical Decisions (Demo)

| Decision | Rationale | Risk Mitigation |
|----------|-----------|-----------------|
| ✅ AI Builder on 5 forms | Minimal training data; fast setup | Low accuracy (~70%); plan retraining with 50+ forms for Phase 2 |
| ✅ Dataverse schema (4 tables) | Native Power Platform storage; easy flow integration | Schema changes difficult post-launch; lock schema early |
| ✅ 4 Power Automate flows | Low-code orchestration; built-in error handling | Flow limits: 50 concurrent flows/env; demo won't hit limit |
| ✅ Power Apps correction form | Low-code UI; quick to build | No form versioning; can't easily revert UI changes mid-demo |
| ✅ D365 connector for sync | Native, built-in D365 integration | Duplicate key errors possible; handle with lookup logic |
| ✅ Basic Dataverse logging | Quick to implement; good for demo | Not immutable; compliance-grade auditing needs Phase 2 |

---

**Status**: ✅ **Research Complete** | **Date**: 2026-04-24 | **Next**: Phase 1 Design (Dataverse schema finalization, flow blueprints)
