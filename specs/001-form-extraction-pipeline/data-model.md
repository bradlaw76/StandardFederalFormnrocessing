# Data Model: VA Form 10-3542 (Travel Expense Reimbursement)

**Feature**: VA Form 10-3542 Extraction Pipeline  
**Date**: 2026-04-24  
**Scope**: Dataverse entity schema for form field capture + contact matching

---

## 1. Form Field Mapping to Dataverse Entities

### Section A: Traveler's Information

**Claimant Information** (Person submitting the form):
| Form Field | Dataverse Column | Data Type | Notes |
|-----------|-----------------|-----------|-------|
| 1A. Name of person claiming (Last, First, Middle) | ClaimantFullName | Text (200 chars) | Parse to FirstName, LastName if needed |
| 1B. Claimant's SSN (999-99-9999) | ClaimantSSN | Text (11 chars, encrypted) | **PII - sensitive** |
| 1C. Claimant's Date of Birth (MM/DD/YYYY) | ClaimantDateOfBirth | Date | Used for contact matching + identity verification |

**Claimant Status** (Primary relationship):
| Form Field | Dataverse Column | Data Type | Notes |
|-----------|-----------------|-----------|-------|
| 2A. Claimant Status (checkbox) | ClaimantStatus | Option Set | Values: Veteran, Caregiver, Attendant, Donor, Other |
| 2A. Other (if checked) | ClaimantStatusOther | Text (100 chars) | Free-form if "Other" selected |

**Veteran Information** (If claimant is not the veteran):
| Form Field | Dataverse Column | Data Type | Notes |
|-----------|-----------------|-----------|-------|
| 3A. Name of Veteran (Last, First, Middle) | VeteranFullName | Text (200 chars) | Only populated if claimant status ≠ Veteran |
| 3B. Veteran's SSN (999-99-9999) | VeteranSSN | Text (11 chars, encrypted) | **PII - sensitive** |
| 3C. Veteran's Date of Birth (MM/DD/YYYY) | VeteranDateOfBirth | Date | Used for contact matching if different claimant |

---

### Section B: Trip Information

**Outbound Trip Details**:
| Form Field | Dataverse Column | Data Type | Notes |
|-----------|-----------------|-----------|-------|
| 1A. Address claiming from (Street, City, State, Zip) | TravelFromAddress | Text (500 chars) | Parse to: Street, City, State, ZipCode |
| 1B. Date trip began (MM/DD/YYYY) | TravelBeginDate | Date | Start of travel period |
| 1C. Travel method outbound (e.g., car, train, bus, taxi) | TravelMethodOutbound | Option Set | Values: Car, Train, Bus, Taxi, Air, Other |
| 1C. Travel method detail | TravelMethodOutboundOther | Text (100 chars) | If "Other" selected |

**Return Trip Details**:
| Form Field | Dataverse Column | Data Type | Notes |
|-----------|-----------------|-----------|-------|
| 2A. Return to same address (YES/NO) | ReturnToSameAddress | Boolean | If FALSE, expected different return address |
| 2B. Date trip ended (MM/DD/YYYY) | TravelEndDate | Date | End of travel period |
| 2C. Travel method return (e.g., car, train, bus, taxi) | TravelMethodReturn | Option Set | Values: Car, Train, Bus, Taxi, Air, Other |
| 2C. Travel method detail | TravelMethodReturnOther | Text (100 chars) | If "Other" selected |

**Expense Information**:
| Form Field | Dataverse Column | Data Type | Notes |
|-----------|-----------------|-----------|-------|
| 3. Claiming other expenses (YES/NO) | HasOtherExpenses | Boolean | Tolls, parking, lodging, meals, etc. |

**Other Expenses Detail** (If HasOtherExpenses = YES):
| Form Field | Dataverse Column | Data Type | Notes |
|-----------|-----------------|-----------|-------|
| Expense A description | ExpenseA_Description | Text (200 chars) | E.g., "Lodging", "Meals", "Parking" |
| Expense A amount | ExpenseA_Amount | Decimal (8,2) | USD amount |
| Expense B description | ExpenseB_Description | Text (200 chars) | |
| Expense B amount | ExpenseB_Amount | Decimal (8,2) | |
| Expense C description | ExpenseC_Description | Text (200 chars) | |
| Expense C amount | ExpenseC_Amount | Decimal (8,2) | |
| Expense D description | ExpenseD_Description | Text (200 chars) | |
| Expense D amount | ExpenseD_Amount | Decimal (8,2) | |

**Treatment Facility Information**:
| Form Field | Dataverse Column | Data Type | Notes |
|-----------|-----------------|-----------|-------|
| 4. Treating facility name (VA or Non-VA) | TreatingFacilityName | Text (200 chars) | VA facility or community provider |
| 5. Treating facility address (Optional) | TreatingFacilityAddress | Text (500 chars) | Parse to: Street, City, State, ZipCode |

---

### Section C: Statements and Certifications

**Claimant Certification**:
| Form Field | Dataverse Column | Data Type | Notes |
|-----------|-----------------|-----------|-------|
| Signature of claimant | SignaturePresent | Boolean | Indicate if handwritten signature scanned |
| Date of signature (MM/DD/YYYY) | SignatureDate | Date | When claimant signed the form |

---

## 2. Dataverse Table: ExtractionResult (Enhanced)

Maps AI Builder extraction confidence + extracted values for all form fields.

### Schema

```sql
ExtractionResult (Table)
├─ ExtractionID (Primary Key, GUID)
├─ FormID (Lookup to FormSubmission)
├─ ModelVersion (Text: "AIBuilder-v1")
├─ ExtractionTimestamp (DateTime)
│
├─── Section A: Traveler Information ───
├─ ClaimantFullName (Text)
├─ ClaimantFullName_Confidence (Decimal 0–100)
├─ ClaimantSSN (Text, encrypted)
├─ ClaimantSSN_Confidence (Decimal 0–100)
├─ ClaimantDateOfBirth (Date)
├─ ClaimantDateOfBirth_Confidence (Decimal 0–100)
├─ ClaimantStatus (Option Set: Veteran, Caregiver, Attendant, Donor, Other)
├─ ClaimantStatus_Confidence (Decimal 0–100)
├─ ClaimantStatusOther (Text)
│
├─ VeteranFullName (Text)
├─ VeteranFullName_Confidence (Decimal 0–100)
├─ VeteranSSN (Text, encrypted)
├─ VeteranSSN_Confidence (Decimal 0–100)
├─ VeteranDateOfBirth (Date)
├─ VeteranDateOfBirth_Confidence (Decimal 0–100)
│
├─── Section B: Trip Information ───
├─ TravelFromAddress (Text)
├─ TravelFromAddress_Confidence (Decimal 0–100)
├─ TravelBeginDate (Date)
├─ TravelBeginDate_Confidence (Decimal 0–100)
├─ TravelMethodOutbound (Option Set)
├─ TravelMethodOutbound_Confidence (Decimal 0–100)
│
├─ ReturnToSameAddress (Boolean)
├─ ReturnToSameAddress_Confidence (Decimal 0–100)
├─ TravelEndDate (Date)
├─ TravelEndDate_Confidence (Decimal 0–100)
├─ TravelMethodReturn (Option Set)
├─ TravelMethodReturn_Confidence (Decimal 0–100)
│
├─ HasOtherExpenses (Boolean)
├─ HasOtherExpenses_Confidence (Decimal 0–100)
├─ ExpenseA_Description (Text) + Confidence
├─ ExpenseA_Amount (Decimal) + Confidence
├─ ExpenseB_Description (Text) + Confidence
├─ ExpenseB_Amount (Decimal) + Confidence
├─ ExpenseC_Description (Text) + Confidence
├─ ExpenseC_Amount (Decimal) + Confidence
├─ ExpenseD_Description (Text) + Confidence
├─ ExpenseD_Amount (Decimal) + Confidence
│
├─ TreatingFacilityName (Text)
├─ TreatingFacilityName_Confidence (Decimal 0–100)
├─ TreatingFacilityAddress (Text)
├─ TreatingFacilityAddress_Confidence (Decimal 0–100)
│
├─── Metadata ───
├─ OverallConfidenceScore (Decimal 0–100, average of all field confidences)
├─ CriticalFieldsOnly_Confidence (Decimal 0–100, average of: SSN, Name, DOB, Dates, Facility)
```

---

## 3. Contact Matching Strategy (New)

### Purpose
Automatically match extracted claimant/veteran information to existing Dataverse **Contacts** table to enable:
- Pre-population of known beneficiary data
- Deduplication (prevent duplicate contact records)
- Audit trail linkage (connect form to known person)

### Matching Algorithm

**Primary Match (Claimant → Contacts)**:

```
IF ClaimantFullName AND ClaimantSSN THEN
  QUERY Contacts WHERE:
    (FirstName + " " + LastName) CONTAINS ClaimantFullName
    AND ssn_encrypted = hash(ClaimantSSN)
  CONFIDENCE: 95%+ (SSN is unique identifier)
  
ELSE IF ClaimantFullName AND ClaimantDateOfBirth THEN
  QUERY Contacts WHERE:
    (FirstName + " " + LastName) CONTAINS ClaimantFullName
    AND birthdate = ClaimantDateOfBirth
  CONFIDENCE: 85–90% (name + DOB, less certain)
  
ELSE IF ClaimantFullName ONLY THEN
  QUERY Contacts WHERE:
    (FirstName + " " + LastName) FUZZY_MATCH ClaimantFullName
  CONFIDENCE: 60–75% (name only, high false positive risk)
  RECOMMENDATION: Require human review
```

**Secondary Match (Veteran → Contacts)**:
- If ClaimantStatus ≠ Veteran, also match VeteranFullName + VeteranSSN to Contacts
- Store both Claimant and Veteran contact IDs in ExtractionResult

**Matching Logic in Power Automate Flow**:

```
Flow: AI Builder Extraction → Contact Matching
├─ Extract all fields from AI Builder
├─ Store in ExtractionResult table
│
├─ Decision: Extract SSN confidence ≥90%?
│  ├─ YES → Query Contacts by SSN (hash comparison)
│  └─ NO → Continue to name + DOB match
│
├─ Decision: Extract Name confidence ≥90%?
│  ├─ YES → Query Contacts by name (fuzzy match)
│  └─ NO → Skip contact matching
│
├─ Store matched contact IDs in ExtractionResult
│  ├─ ClaimantContactID (Lookup to Contacts)
│  └─ VeteranContactID (Lookup to Contacts)
│
├─ IF NO MATCH FOUND → Set status = "UnmatchedContact"
│  └─ Flag for human review (new contact record needed?)
│
└─ Continue to confidence routing (≥95% auto-approve, <95% manual review)
```

### Data Security (PII Protection)

**SSN Handling** (Highly Sensitive):
- Extract and immediately encrypt in-flight (Power Automate → Dataverse)
- Store encrypted at rest (Dataverse encryption enabled)
- Compare via hashed values only (do not compare raw SSNs)
- Field-level security (FLS) restricts access to VA staff only
- Mask in UI (show only last 4 digits: ***-**-XXXX)

**Name + DOB Handling** (Moderate Sensitivity):
- No special encryption needed (non-unique, less identifiable)
- Used for fuzzy matching; can be displayed in normal form flow
- Log all contact lookup attempts in AuditLog for compliance

---

## 4. Dataverse Tables Summary

### Updated Table Schema

**FormSubmission Table** (unchanged):
- FormID, FileName, FileBlob, UploadedBy, UploadTimestamp, Status

**ExtractionResult Table** (EXPANDED for all form fields):
- ExtractionID, FormID
- All Section A fields (claimant, veteran, status)
- All Section B fields (trip details, expenses, facility)
- Confidence score per field
- OverallConfidenceScore, CriticalFieldsOnly_Confidence
- *New*: ClaimantContactID (Lookup), VeteranContactID (Lookup)

**CorrectionRecord Table** (unchanged):
- CorrectionID, ExtractionID, CorrectedBy, CorrectionTimestamp
- Corrected values for any field that user modifies
- ApprovalStatus, ApprovalTimestamp

**AuditLog Table** (enhanced):
- AuditID, Timestamp, UserID, ActionType
- TargetEntity (FormID)
- Details (JSON including contact match results)
- Status, ErrorMessage

**New: ContactMatchLog Table** (optional, for compliance):
- MatchLogID (Primary Key, GUID)
- ExtractionID (Lookup to ExtractionResult)
- SearchCriteria (JSON: {SSN, Name, DOB} used for match)
- MatchResult (JSON: matched ContactID or "NoMatch")
- MatchConfidence (Decimal 0–100)
- Timestamp (DateTime)
- PerformedBy (User)

---

## 5. Confidence Thresholds & Routing Rules

### AI Builder Extraction Quality

| Field Type | AI Confidence Threshold | Action if Below | Notes |
|-----------|----------------------|-----------------|-------|
| **Critical** (SSN, Name, DOB) | ≥95% | Manual review required | High-confidence identity verification |
| **Important** (Dates, Facility) | ≥90% | Manual review | Trip details, treatment location |
| **Optional** (Expense details) | ≥80% | May auto-approve if critical fields ✅ | Secondary information |
| **Overall Form** | ≥90% | Auto-approve to D365 | All critical + important fields pass |

### Routing Logic

```
IF OverallConfidenceScore ≥90% AND CriticalFieldsOnly_Confidence ≥95% THEN
  → Auto-approve → D365 Write (no human review)
  
ELSE IF OverallConfidenceScore ≥80% THEN
  → Manual review via Power Apps correction form
  
ELSE IF OverallConfidenceScore <80% THEN
  → Flag as "Manual Extraction Required"
  → Route to VA staff for full manual entry
  → Store extracted data as "draft" reference only
```

---

## 6. Demo Scope vs. Production

### Demo (5 forms):
- Focus on 7 critical fields: Name, SSN, DOB, Travel Dates, Facility, Expense (1 line), Status
- Contact matching: Basic SSN match + name match
- No hashing/encryption (simplified for demo)
- Manual audit logging via Power Apps

### Phase 2 (Production):
- All 20+ form fields extracted with confidence
- Advanced contact matching (fuzzy name matching, phonetic matching)
- Full PII encryption + hashing
- Automated compliance audit trail (ContactMatchLog table)
- Contact deduplication logic (prevent duplicate veterans/beneficiaries)

---

## 7. Implementation Checklist

- ⏳ **AI Builder Training** (5 forms): Annotate all fields listed in Section A–B above
- ⏳ **Dataverse Schema**: Create ExtractionResult with 40+ columns (fields + confidence scores)
- ⏳ **Contact Matching Logic**: Add Power Automate flow step to query Contacts table after extraction
- ⏳ **Power Apps Correction Form**: Display extracted fields; allow edits; show AI confidence per field
- ⏳ **Contact Matching UI** (optional): Show matched contact in Power Apps (e.g., "Matched to: John Smith (ID: xxx)")
- ⏳ **AuditLog Enhancement**: Log all contact match attempts + results

---

**Status**: ✅ **Draft Ready** | **Date**: 2026-04-24 | **Next**: Update research.md with contact matching details, update plan.md with expanded AI Builder field list
