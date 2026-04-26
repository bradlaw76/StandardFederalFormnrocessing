# VA Form Extraction - Automated Table Definition Generator
# Generates all field/relationship/business rule definitions for easy copy-paste into Power Apps UI

$ErrorActionPreference = "Stop"

Write-Host "=========================================="
Write-Host "📋 VA Form Extraction - Table Definitions"
Write-Host "=========================================="
Write-Host ""

# ============================================================================
# TABLE 1: Form Submission (Parent)
# ============================================================================

$table1 = @"
TABLE: Form Submission
Schema Name: vafe_FormSubmission
Display Name: Form Submission (Plural: Form Submissions)
Owner: User-owned
Description: Tracks VA Form 10-3542 submissions through extraction lifecycle

PRIMARY COLUMN:
- Display Name: Form Submission
- Data Type: Autonumber
- Format: VAFE-{SEQNUM:6}
- Schema Name: vafe_name

FIELDS TO ADD:
1. UploadDate
   - Type: DateTime
   - Default: Empty
   - Schema: vafe_uploaddate

2. SourceFile
   - Type: Single line of text
   - Max Length: 255
   - Schema: vafe_sourcefile

3. Status
   - Type: Choice
   - Options: Intake | Extracting | Extracted | Correcting | Corrected | Writing | Written
   - Default: Intake
   - Schema: vafe_status

4. ProcessingNotes
   - Type: Multi-line text
   - Max Length: 2000
   - Schema: vafe_processingnotes

5. ProcessingStart
   - Type: DateTime
   - Schema: vafe_processingstart

6. ProcessingEnd
   - Type: DateTime
   - Schema: vafe_processingend

7. ErrorDetails
   - Type: Multi-line text
   - Max Length: 2000
   - Schema: vafe_errordetails

8. ProcessedBy
   - Type: Lookup (User)
   - Schema: vafe_processedby

9. ProcessedTimestamp
   - Type: DateTime
   - Schema: vafe_processedtimestamp
"@

# ============================================================================
# TABLE 2: Extraction Result (Child of FormSubmission)
# ============================================================================

$table2 = @"
TABLE: Extraction Result
Schema Name: vafe_ExtractionResult
Display Name: Extraction Result (Plural: Extraction Results)
Owner: User-owned
Description: Stores AI-extracted field data and confidence scores

FIELDS TO ADD:
1. FormSubmissionId [REQUIRED - LOOKUP]
   - Type: Lookup
   - Related Table: Form Submission
   - Schema: vafe_formsubmissionid

2. ExtractedData
   - Type: Multi-line text
   - Max Length: 5000
   - Schema: vafe_extracteddata

3. FieldConfidenceScores
   - Type: Multi-line text
   - Max Length: 5000
   - Schema: vafe_fieldconfidencescores

4. OverallConfidence
   - Type: Decimal
   - Decimal Places: 5
   - Min: 0, Max: 1
   - Schema: vafe_overallconfidence

5. ExtractionStatus
   - Type: Choice
   - Options: Success | PartialSuccess | Failed
   - Schema: vafe_extractionstatus

6. ModelVersion
   - Type: Single line of text
   - Max Length: 100
   - Schema: vafe_modelversion

7. ExtractionTimestamp
   - Type: DateTime
   - Schema: vafe_extractiontimestamp

8. ErrorMessage
   - Type: Multi-line text
   - Max Length: 2000
   - Schema: vafe_errormessage
"@

# ============================================================================
# TABLE 3: Audit Log (Child of FormSubmission, Immutable)
# ============================================================================

$table3 = @"
TABLE: Audit Log
Schema Name: vafe_AuditLog
Display Name: Audit Log (Plural: Audit Logs)
Owner: User-owned
Description: Immutable compliance audit trail (HIPAA/VA)

FIELDS TO ADD:
1. FormSubmissionId [REQUIRED - LOOKUP]
   - Type: Lookup
   - Related Table: Form Submission
   - Schema: vafe_formsubmissionid

2. Action
   - Type: Choice
   - Options: Create | Read | Update | Delete
   - Schema: vafe_action

3. Timestamp
   - Type: DateTime
   - Default: Now
   - Schema: vafe_timestamp

4. UserId
   - Type: Single line of text
   - Max Length: 255
   - Schema: vafe_userid

5. IPAddress
   - Type: Single line of text
   - Max Length: 45
   - Schema: vafe_ipaddress

6. Details
   - Type: Multi-line text
   - Max Length: 2000
   - Schema: vafe_details

7. ErrorCode
   - Type: Single line of text
   - Max Length: 50
   - Schema: vafe_errorcode

8. Severity
   - Type: Choice
   - Options: Info | Warning | Error | Critical
   - Schema: vafe_severity

9. CorrelationId
   - Type: Single line of text
   - Max Length: 100
   - Schema: vafe_correlationid
"@

# ============================================================================
# TABLE 4: D365 Write Event (Child of FormSubmission)
# ============================================================================

$table4 = @"
TABLE: D365 Write Event
Schema Name: vafe_D365WriteEvent
Display Name: D365 Write Event (Plural: D365 Write Events)
Owner: User-owned
Description: Tracks synchronization attempts to Dynamics 365 with retry logic

FIELDS TO ADD:
1. FormSubmissionId [REQUIRED - LOOKUP]
   - Type: Lookup
   - Related Table: Form Submission
   - Schema: vafe_formsubmissionid

2. D365Status
   - Type: Choice
   - Options: Pending | Success | Failed | Retrying
   - Schema: vafe_d365status

3. TimestampWritten
   - Type: DateTime
   - Schema: vafe_timestampwritten

4. D365RecordId
   - Type: Single line of text
   - Max Length: 100
   - Schema: vafe_d365recordid

5. RetryCount
   - Type: Whole number
   - Min: 0
   - Schema: vafe_retrycount

6. LastRetry
   - Type: DateTime
   - Schema: vafe_lastretry

7. ErrorDetails
   - Type: Multi-line text
   - Max Length: 2000
   - Schema: vafe_errordetails

8. PayloadSent
   - Type: Multi-line text
   - Max Length: 5000
   - Schema: vafe_payloadsent

9. HTTPStatusCode
   - Type: Whole number
   - Min: 100, Max: 599
   - Schema: vafe_httpstatuscode
"@

# ============================================================================
# TABLE 5: Correction Record (Child of ExtractionResult)
# ============================================================================

$table5 = @"
TABLE: Correction Record
Schema Name: vafe_CorrectionRecord
Display Name: Correction Record (Plural: Correction Records)
Owner: User-owned
Description: Tracks manual corrections made to low-confidence AI extractions

FIELDS TO ADD:
1. ExtractionResultId [REQUIRED - LOOKUP]
   - Type: Lookup
   - Related Table: Extraction Result
   - Schema: vafe_extractionresultid

2. FieldName
   - Type: Single line of text
   - Max Length: 255
   - Schema: vafe_fieldname

3. OriginalValue
   - Type: Multi-line text
   - Max Length: 2000
   - Schema: vafe_originalvalue

4. CorrectedValue
   - Type: Multi-line text
   - Max Length: 2000
   - Schema: vafe_correctedvalue

5. CorrectionDate
   - Type: DateTime
   - Default: Now
   - Schema: vafe_correctiondate

6. ReviewedBy
   - Type: Lookup (User)
   - Schema: vafe_reviewedby

7. CorrectionStatus
   - Type: Choice
   - Options: Pending | Approved | Rejected
   - Schema: vafe_correctionstatus

8. CorrectionNotes
   - Type: Multi-line text
   - Max Length: 2000
   - Schema: vafe_correctionnotes

9. FieldConfidence
   - Type: Decimal
   - Decimal Places: 5
   - Min: 0, Max: 1
   - Schema: vafe_fieldconfidence

10. ReviewSLA
    - Type: Whole number
    - Unit: Minute
    - Schema: vafe_reviewsla
"@

# ============================================================================
# RELATIONSHIPS
# ============================================================================

$relationships = @"
RELATIONSHIPS TO CREATE (After all tables exist):

1. Form Submission → Extraction Result (1:N)
   - Parent: Form Submission
   - Child: Extraction Result
   - Relationship Name: FormSubmission_ExtractionResult
   - Foreign Key: FormSubmissionId
   - Cascade Delete: YES

2. Form Submission → Audit Log (1:N)
   - Parent: Form Submission
   - Child: Audit Log
   - Relationship Name: FormSubmission_AuditLog
   - Foreign Key: FormSubmissionId
   - Cascade Delete: YES

3. Form Submission → D365 Write Event (1:N)
   - Parent: Form Submission
   - Child: D365 Write Event
   - Relationship Name: FormSubmission_D365WriteEvent
   - Foreign Key: FormSubmissionId
   - Cascade Delete: YES

4. Extraction Result → Correction Record (1:N)
   - Parent: Extraction Result
   - Child: Correction Record
   - Relationship Name: ExtractionResult_CorrectionRecord
   - Foreign Key: ExtractionResultId
   - Cascade Delete: YES
"@

# ============================================================================
# OUTPUT TO FILES
# ============================================================================

$outputDir = ".\specs\02-phase-2-stream-a\table-definitions"

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$table1 | Out-File -FilePath "$outputDir\01-FormSubmission.txt" -Encoding UTF8 -Force
$table2 | Out-File -FilePath "$outputDir\02-ExtractionResult.txt" -Encoding UTF8 -Force
$table3 | Out-File -FilePath "$outputDir\03-AuditLog.txt" -Encoding UTF8 -Force
$table4 | Out-File -FilePath "$outputDir\04-D365WriteEvent.txt" -Encoding UTF8 -Force
$table5 | Out-File -FilePath "$outputDir\05-CorrectionRecord.txt" -Encoding UTF8 -Force
$relationships | Out-File -FilePath "$outputDir\06-Relationships.txt" -Encoding UTF8 -Force

Write-Host "✅ All table definitions generated!"
Write-Host ""
Write-Host "📁 Output Directory: $outputDir"
Write-Host ""
Write-Host "Files created:"
Get-ChildItem $outputDir | ForEach-Object { Write-Host "  📄 $($_.Name)" }
Write-Host ""
Write-Host "📝 Next Steps:"
Write-Host "  1. Open Power Apps: https://make.powerapps.com"
Write-Host "  2. Navigate to solution: VAFormExtractionDemo"
Write-Host "  3. For each table definition file:"
Write-Host "     - Copy field definitions"
Write-Host "     - Paste into Power Apps UI"
Write-Host "     - Create each field exactly as specified"
Write-Host ""
Write-Host "⏱️  Estimated time: 45-60 minutes for all 5 tables"
Write-Host ""
