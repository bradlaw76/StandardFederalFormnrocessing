# Flow Connector Configuration Guide
**Issue #18 — Stream B-2: Power Automate Connectors**  
**Owner**: John Shelby, Flow Orchestration Lead  
**Date**: 2026-04-25

---

## Connector Inventory & Setup

### 1. SharePoint Connector

**Purpose**: Read form files from FormIntake library, trigger flow on file upload

#### Connection Setup

```powershell
# Step 1: Create SharePoint site connection
# In Power Automate designer:
# - Add action: "When a file is created or modified"
# - Select: Department of Veteran Affairs site
# - Select: FormIntake library
# - Click "Sign in" → authenticate with service account
```

#### Configuration

| Setting | Value | Notes |
|---------|-------|-------|
| **Site URL** | `https://d365demotsce80677168.sharepoint.com/sites/DepartmentofVeteranAffairs` | D365-integrated site |
| **Library** | FormIntake | Document set for form uploads |
| **Filter** | File name starts with `VA-10-3542-` | Intake naming convention |
| **Trigger Frequency** | Every 1 minute | Check for new files |
| **Scope** | Organization-level | All users can upload |

#### Connector Actions Used

1. **When a file is created or modified** (Trigger)
   - Inputs: Site, Library, Filter
   - Outputs: `triggerOutputs()` (file metadata)

2. **Get file metadata** (Action)
   - Input: Site ID, Library ID, File ID
   - Output: File name, size, created date, modified date

3. **Get file content** (Action)
   - Input: Site ID, Library ID, File ID
   - Output: Binary file content (for AI processing)

#### Connection String (For Key Vault)

```
SharePointSiteUrl=https://d365demotsce80677168.sharepoint.com/sites/DepartmentofVeteranAffairs
SharePointLibraryName=FormIntake
```

#### Permissions Required

- SharePoint library viewer (read files)
- SharePoint flow contributor (create/modify files — for audit trail)

---

### 2. Dataverse Connector

**Purpose**: CRUD operations on all 5 custom tables (FormSubmission, ExtractionResult, CorrectionRecord, AuditLog, D365WriteEvent)

#### Connection Setup

```powershell
# In Power Automate designer:
# - Add action: "Create a record" (Dataverse connector)
# - Click "Select environment"
# - Choose: VA Form Extraction environment
# - Click "Sign in" (service account OAuth)
# - Connection auto-created: "VA-Form-Extraction-DataverseConn"
```

#### Configuration

| Setting | Value | Notes |
|---------|-------|-------|
| **Environment** | VA Form Extraction | D365-integrated CDS instance |
| **Auth Type** | OAuth 2.0 (Service Principal) | Unattended operation |
| **Service Account** | flow@va-form-extraction.onmicrosoft.com | Dedicated automation account |
| **Organization ID** | {GUID from Dataverse settings} | Org-level CRUD scope |

#### Connector Actions Used

| Action | Table | Purpose |
|--------|-------|---------|
| **Create a record** | FormSubmission | Create on file validation (Step 1) |
| **Create a record** | ExtractionResult | Create after AI extraction (Step 2) |
| **Create a record** | CorrectionRecord | Create for low-confidence fields (Step 3) |
| **Create a record** | AuditLog | Log all events (Steps 1–5 + subflows) |
| **Create a record** | D365WriteEvent | Create D365 write tracking record (Step 4) |
| **Update a record** | FormSubmission | Update status throughout pipeline (Steps 3–5) |
| **Update a record** | D365WriteEvent | Update retry count & status (Retry-Logic flow) |
| **Update a record** | CorrectionRecord | Mark as "Applied" after correction (Correction-Queue) |
| **Get a record** | D365WriteEvent | Retrieve pending records (Retry-Logic flow) |
| **List records** | D365WriteEvent | Query pending writes for retry (Retry-Logic flow) |

#### Table API Names & Field Mappings

```
FormSubmission Table:
├─ API Name: vafe_formsubmission
├─ Fields:
│  ├─ vafe_form_id (Text)
│  ├─ vafe_file_name (Text)
│  ├─ vafe_file_url (Text)
│  ├─ vafe_file_size (Whole Number)
│  ├─ vafe_submitted_date (Date Time)
│  ├─ vafe_status (Choice: Intake, ReadyForD365Write, Written, etc.)
│  ├─ vafe_extraction_confidence (Decimal: 0.0–1.0)
│  ├─ vafe_extraction_result (Lookup → ExtractionResult)
│  ├─ vafe_d365_write_event (Lookup → D365WriteEvent)
│  └─ vafe_form_locked (Yes/No: true after Written)

ExtractionResult Table:
├─ API Name: vafe_extractionresult
├─ Fields:
│  ├─ vafe_result_id (Auto-generated)
│  ├─ vafe_form_submission (Lookup → FormSubmission)
│  ├─ vafe_extracted_fields (Multiple Lines of Text — JSON)
│  ├─ vafe_field_confidence_scores (Multiple Lines of Text — JSON)
│  ├─ vafe_ai_model_version (Text)
│  ├─ vafe_status (Choice: Success, Failed)
│  └─ vafe_extraction_timestamp (Date Time)

CorrectionRecord Table:
├─ API Name: vafe_correctionrecord
├─ Fields:
│  ├─ vafe_correction_id (Auto-generated)
│  ├─ vafe_extraction_result (Lookup → ExtractionResult)
│  ├─ vafe_field_name (Text)
│  ├─ vafe_original_value (Text)
│  ├─ vafe_corrected_value (Text)
│  ├─ vafe_confidence_before (Decimal: 0.0–1.0)
│  ├─ vafe_confidence_after (Decimal: 0.0–1.0)
│  ├─ vafe_corrected_by (Lookup → User)
│  ├─ vafe_status (Choice: Pending, Applied)
│  └─ vafe_reason (Text)

AuditLog Table:
├─ API Name: vafe_auditlog
├─ Fields:
│  ├─ vafe_log_id (Auto-generated)
│  ├─ vafe_form_submission (Lookup → FormSubmission)
│  ├─ vafe_event_type (Choice: FileValidated, ExtractionCompleted, etc. — 12 types)
│  ├─ vafe_event_date (Date Time)
│  ├─ vafe_status (Choice: Success, Failure)
│  ├─ vafe_details (Multiple Lines of Text — JSON)
│  ├─ vafe_actor (Lookup → User)
│  └─ vafe_retention_days (Whole Number: default 90)

D365WriteEvent Table:
├─ API Name: vafe_d365writeevent
├─ Fields:
│  ├─ vafe_write_id (Auto-generated)
│  ├─ vafe_form_submission (Lookup → FormSubmission)
│  ├─ vafe_d365_table (Text: "accounts")
│  ├─ vafe_d365_record_id (Text — GUID)
│  ├─ vafe_write_date (Date Time)
│  ├─ vafe_mapped_fields (Multiple Lines of Text — JSON)
│  ├─ vafe_status (Choice: Pending, Success, Failed)
│  ├─ vafe_retry_count (Whole Number: 0–5)
│  ├─ vafe_last_retry_date (Date Time)
│  └─ vafe_last_retry_response (Multiple Lines of Text)
```

#### Connection String (For Key Vault)

```
DataverseEnvironmentUrl=https://va-form-extraction.crm.dynamics.com
DataverseOrgId={GUID}
DataverseConnectorId=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

#### Permissions Required

- Dataverse: System Administrator (for service account)
- Or: Custom role with CRUD on all 5 custom tables + AuditLog read

---

### 3. AI Builder Connector

**Purpose**: Invoke custom document processing model (VAForm10-3542-Extractor)

#### Connection Setup

```powershell
# In Power Automate designer:
# - Add action: "Invoke AI Builder Model" (search in connectors)
# - Select: Custom Document Processing model
# - Model dropdown: "VAForm10-3542-Extractor"
# - Model ID: $(model-id-from-michael) [to be filled by Michael Gray]
# - No additional auth needed (embedded in Power Automate environment)
```

#### Configuration

| Setting | Value | Notes |
|---------|-------|-------|
| **Model Name** | VAForm10-3542-Extractor | Published by Michael (Issue #17) |
| **Model Version** | v1 (or current published) | Track in AuditLog for traceability |
| **Processing Timeout** | 30 seconds | Per Step 2 requirements |
| **Input Format** | Binary file content | PDF, TIFF, PNG, JPEG accepted |
| **Output Format** | JSON (extractedFields, confidenceScores) | Structured for Step 3 validation |

#### Model Input Specification

```json
{
  "file": "base64-encoded-file-content",
  "fileName": "vafe_10001_2026-04-25_example.pdf",
  "fileType": "pdf",
  "returnConfidenceScores": true,
  "returnRawText": true,
  "processingTimeMs": 0
}
```

#### Model Output Specification

```json
{
  "extractedFields": [
    {
      "fieldName": "veteran_name",
      "value": "Smith, John",
      "rawText": "Smith, John",
      "boundingBox": {...}
    },
    {
      "fieldName": "ssn",
      "value": "123-45-6789",
      "rawText": "123 45 6789",
      "boundingBox": {...}
    }
    // ... 30+ more fields
  ],
  "confidenceScores": [
    { "fieldName": "veteran_name", "confidence": 0.96 },
    { "fieldName": "ssn", "confidence": 0.88 },
    // ... 30+ more fields
  ],
  "modelMetadata": {
    "version": "VAForm10-3542-Extractor-v1",
    "processingTimeMs": 8200,
    "modelAccuracy": 0.95
  }
}
```

#### Connection String (For Key Vault)

```
AIBuilderModelId=$(model-id-from-michael)
AIBuilderModelName=VAForm10-3542-Extractor
AIBuilderModelVersion=v1
AIBuilderProcessingTimeoutMs=30000
```

#### Permissions Required

- AI Builder: Model creator or Power Automate flow creator role
- Environment: Same as Dataverse (VA Form Extraction)

---

### 4. Dynamics 365 Connector (HTTP)

**Purpose**: Direct API calls to D365 for querying, creating, updating accounts (Step 4)

#### Connection Setup

```powershell
# In Power Automate designer:
# - Add action: "Invoke an HTTP request" (HTTP connector)
# - Method: GET / POST / PATCH
# - URI: https://{org}.crm.dynamics.com/api/data/v9.2/{endpoint}
# - Headers:
#   Authorization: Bearer $(d365-access-token)
#   Content-Type: application/json
# - Authentication: OAuth 2.0 (Service Principal)
```

#### Configuration

| Setting | Value | Notes |
|---------|-------|-------|
| **D365 Instance URL** | `https://va-form-extraction.crm.dynamics.com` | Dev/Test/Prod endpoint |
| **API Version** | v9.2 (or latest) | RESTful Web API |
| **Auth Type** | OAuth 2.0 Bearer Token | Service principal + Entra ID |
| **Service Account** | flow@va-form-extraction.onmicrosoft.com | D365 System Administrator |
| **Timeout** | 15 seconds per call | HTTP timeout for D365 writes |
| **Retry Policy** | 1 automatic retry + circuit breaker | Built-in HTTP resilience |

#### D365 API Endpoints Used

##### 4.1 Query for Duplicate Accounts

```
Method: GET
URI: https://va-form-extraction.crm.dynamics.com/api/data/v9.2/accounts?$filter=
  (accountnumber eq 'SERVICE-NUMBER') 
  or (lastname eq 'LASTNAME' and birthdate eq 1990-01-15)
&$select=accountid,lastname,accountnumber,birthdate
&$top=2

Headers:
  Authorization: Bearer {access-token}
  Prefer: odata.include-annotations=*
  OData-MaxPageSize: 2

Response (200 OK):
{
  "@odata.context": "https://va-form-extraction.crm.dynamics.com/api/data/v9.2/$metadata#accounts",
  "value": [
    {
      "accountid": "00000000-0000-0000-0000-000000000001",
      "name": "Smith, John",
      "accountnumber": "VA-SERVICE-123456",
      "birthdate": "1960-01-15"
    }
  ]
}
```

##### 4.2 Create New Account

```
Method: POST
URI: https://va-form-extraction.crm.dynamics.com/api/data/v9.2/accounts

Headers:
  Authorization: Bearer {access-token}
  Content-Type: application/json

Body (JSON):
{
  "name": "Smith, John",
  "accountnumber": "VA-SERVICE-123456",
  "emailaddress1": "john.smith@example.com",
  "telephone1": "(555) 123-4567",
  "address1_city": "Washington",
  "address1_stateorprovince": "DC",
  "address1_postalcode": "20001",
  "ava_form_source": "vafe_form_10_3542",
  "ava_submission_id": "form-submission-guid",
  // ... 25+ more fields per Alfie's mapping
}

Response (201 Created):
{
  "@odata.context": "https://va-form-extraction.crm.dynamics.com/api/data/v9.2/$metadata#accounts/$entity",
  "id": "00000000-0000-0000-0000-000000000002",
  "@odata.etag": "W/\"1234567890\""
}
```

##### 4.3 Update Existing Account

```
Method: PATCH
URI: https://va-form-extraction.crm.dynamics.com/api/data/v9.2/accounts(00000000-0000-0000-0000-000000000001)

Headers:
  Authorization: Bearer {access-token}
  Content-Type: application/json
  If-Match: *  // Overwrite any version

Body (JSON):
{
  "emailaddress1": "john.smith@newdomain.com",
  "address1_city": "Boston",
  "ava_last_form_submission": "2026-04-25",
  // ... only changed fields
}

Response (204 No Content):
// Empty response = success
```

#### Connection String (For Key Vault)

```
D365InstanceUrl=https://va-form-extraction.crm.dynamics.com
D365ServicePrincipalId={service-principal-guid}
D365ServicePrincipalSecret=$(d365-service-principal-secret)
D365TenantId={entra-tenant-guid}
D365APIVersion=v9.2
```

#### Permissions Required

- D365: System Administrator (for service account)
- Entra ID: Application API permission "Dynamics CRM.user_impersonation"
- D365 Security Role: System Administrator or custom role with account create/update

---

### 5. Teams Connector

**Purpose**: Post notifications, approval cards, escalation alerts to Teams channels

#### Connection Setup

```powershell
# In Power Automate designer:
# - Add action: "Post a message" or "Post an adaptive card" (Teams connector)
# - Click "Sign in" → authenticate with service account
# - Connection auto-created: "VA-Form-Extraction-TeamsConn"
```

#### Configuration

| Setting | Value | Notes |
|---------|-------|-------|
| **Teams Organization** | va-form-extraction.onmicrosoft.com | Same tenant as D365 |
| **Team** | VA Form Extraction | Dedicated team for project |
| **Channels** | Multiple (see below) | One channel per notification type |
| **Bot Name** | VA-Form-Bot | Power Automate bot account |
| **Message Format** | Adaptive Card (JSON) | Rich formatting, buttons |

#### Teams Channels

| Channel | Purpose | Recipient |
|---------|---------|-----------|
| **#va-form-extraction-reviews** | Low-confidence corrections requiring human review | Data Entry team |
| **#va-form-extraction-alerts** | Errors, escalations, D365 write failures | Operations team |
| **#va-form-extraction-admin** | Admin-level escalations, max retry exceeded | Admin queue |
| **#va-form-extraction-logs** | Optional: Audit trail & success logs | Compliance team |

#### Connector Actions Used

1. **Post a message** (Simple text notification)
   ```
   Channel: @{variables('NotificationChannel')}
   Message: "@{variables('NotificationText')}"
   ```

2. **Post an adaptive card** (Rich format with buttons)
   ```
   Channel: #va-form-extraction-reviews
   Body: @{json(adaptiveCardObject)}
   ```

#### Sample Adaptive Card (Low-Confidence Review)

See FLOW-ARCHITECTURE.md Section 3, Step Q1 for full card definition.

#### Connection String (For Key Vault)

```
TeamsChannelId=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
TeamsTeamId=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
TeamsBotId=00000000-0000-0000-0000-000000000000
```

#### Permissions Required

- Teams: Team owner (for bot app installation)
- Power Automate: Flow creator role in Teams environment

---

### 6. HTTP Connector (Generic)

**Purpose**: Direct HTTP calls for APIs not covered by connectors (D365 batch ops, custom webhooks)

#### Configuration

| Setting | Value | Notes |
|---------|-------|-------|
| **Timeout** | 15 seconds (adjustable per action) | Match D365 API SLA |
| **Retry Policy** | 3 retries with exponential backoff | Resilience |
| **Authentication** | OAuth 2.0 Bearer / API Key | Determined by endpoint |

#### Usage Examples

See Sections 4.1–4.3 above for D365 API calls using HTTP connector.

---

## Connector Credentials & Secrets Management

### Key Vault Integration

All connection strings stored in Azure Key Vault (NOT in flow definitions):

```powershell
# Example Key Vault secrets:
az keyvault secret set --vault-name va-form-kv \
  --name "SharePointSiteUrl" \
  --value "https://d365demotsce80677168.sharepoint.com/sites/DepartmentofVeteranAffairs"

az keyvault secret set --vault-name va-form-kv \
  --name "D365InstanceUrl" \
  --value "https://va-form-extraction.crm.dynamics.com"

az keyvault secret set --vault-name va-form-kv \
  --name "AIBuilderModelId" \
  --value "$(model-id-from-michael)"
```

### Service Account Setup

**Service Principal**: `flow@va-form-extraction.onmicrosoft.com`

Roles Required:
- Dataverse: System Administrator
- D365: System Administrator
- SharePoint: Site collection administrator
- Power Automate: Flow contributor
- Teams: Team member
- AI Builder: Environment administrator

### OAuth Token Refresh

All connectors auto-refresh OAuth tokens (handled by Power Automate runtime). No manual intervention required.

---

## Connection Health & Monitoring

### Connector Status Checks

```
In Power Automate cloud portal:
- Navigate to Flows → VA-Form-Intake-Pipeline
- View "Connections used" panel
- Each connector shows: ✅ (healthy) or ⚠️ (needs re-auth)
- If warning: Click connector → "Edit" → "Re-authenticate"
```

### Testing Connections

```powershell
# PowerShell script to test connectors:

# Test SharePoint
$siteUrl = "https://d365demotsce80677168.sharepoint.com/sites/DepartmentofVeteranAffairs"
$site = Connect-PnPOnline -Url $siteUrl -Interactive
Get-PnPList | Where-Object { $_.Title -eq "FormIntake" }

# Test Dataverse
$conn = New-ServicePrincipalConnection -OrganizationUrl "https://va-form-extraction.crm.dynamics.com" `
  -ClientId $(az keyvault secret show --vault-name va-form-kv --name "D365ServicePrincipalId" --query value -o tsv)
Get-CrmRecords -conn $conn -EntityLogicalName "vafe_formsubmission" -TopCount 1

# Test AI Builder
# (Manual test in Power Automate designer: run action with test document)

# Test D365
$token = Get-D365AccessToken
$headers = @{ "Authorization" = "Bearer $token" }
Invoke-RestMethod -Method Get `
  -Uri "https://va-form-extraction.crm.dynamics.com/api/data/v9.2/accounts?$top=1" `
  -Headers $headers

# Test Teams
# (Manual test in Power Automate designer: run action to post card)
```

---

## Connector Updates & Versioning

### Policy

- Connectors auto-update to latest version (minor updates = transparent)
- Major breaking changes = notification + grace period
- Test all flows after connector updates (especially D365, Dataverse)

### Rollback Procedure

If connector update breaks flow:
1. In Power Automate cloud portal, navigate to flow
2. Click "Edit" → locate problematic action
3. Delete action → re-add from connector
4. Re-authenticate connector
5. Save flow
6. Test with sample data

---

## Troubleshooting Guide

### Common Issues & Resolutions

#### Issue: "SharePoint connection failed"
**Cause**: Service account doesn't have FormIntake library access  
**Fix**: Add service account to SharePoint site collection → library permissions → Contribute

#### Issue: "Dataverse record creation failed — validation error"
**Cause**: Field value doesn't match data type or validation rule  
**Fix**: Review Polly's TABLE-SPECIFICATIONS.md for field constraints; validate value format before creating

#### Issue: "AI Builder model timeout"
**Cause**: File too large, model overloaded, or network latency  
**Fix**: Retry 1x (auto-handled by flow); escalate if persists

#### Issue: "D365 write returned 404"
**Cause**: Account doesn't exist (duplicate check failed) or D365 instance URL incorrect  
**Fix**: Verify instance URL in Key Vault; check D365 account existence manually

#### Issue: "Teams message failed to post"
**Cause**: Bot doesn't have permission to channel or channel ID incorrect  
**Fix**: Reinstall VA-Form-Bot in Teams; verify channel ID in Key Vault

#### Issue: "Token expired — cannot connect"
**Cause**: OAuth token refresh failed (rare; usually auto-handled)  
**Fix**: Delete flow connection → re-authenticate service account → test flow

---

## Security Best Practices

1. **Never hardcode credentials**: All secrets in Key Vault
2. **Rotate service account password**: Every 90 days
3. **Monitor connector usage**: Power Automate audit logs
4. **Restrict connector scope**: Use least-privilege roles (avoid Global Admin)
5. **Audit connector access**: Review Dataverse & D365 access logs monthly
6. **MFA for service account**: Enable conditional access policy (if org requires)

---

## Deployment Checklist

- [ ] All 6 connectors configured (SharePoint, Dataverse, AI Builder, D365 HTTP, Teams, HTTP generic)
- [ ] Service principal created & added to Entra ID
- [ ] Service principal assigned required D365, Dataverse, SharePoint roles
- [ ] All secrets stored in Key Vault (no hardcoding)
- [ ] Connectors tested individually (connection health checks)
- [ ] End-to-end flow test (file upload → all connectors exercised)
- [ ] Performance baseline recorded (connector call latency per step)
- [ ] Alert thresholds configured (timeout, auth failure)
- [ ] Rollback procedure documented
- [ ] Operations team trained on connector troubleshooting

---

**Status**: ✅ **CONNECTOR CONFIGURATION GUIDE COMPLETE**

**Prepared by**: John Shelby, Flow Orchestration Lead  
**Date**: 2026-04-25  
**Ready for**: Phase 2 connector provisioning & testing
