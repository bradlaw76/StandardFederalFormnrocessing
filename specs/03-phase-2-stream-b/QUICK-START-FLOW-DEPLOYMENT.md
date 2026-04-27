# Quick-Start Flow Deployment Checklist
**Issue #18 — Stream B-2: Power Automate Deployment Guide**  
**Owner**: John Shelby, Flow Orchestration Lead  
**Audience**: Tommy Shelby (Lead), Deployment Engineers  
**Date**: 2026-04-25

---

## Executive Summary

This checklist guides **Tommy Shelby** and the deployment team through provisioning, testing, and launching all 5 Power Automate flows for the VA Form 10-3542 extraction pipeline.

**Deployment Phases**:
1. **Pre-Deployment** (Day 1): Environment setup, secrets, connections
2. **Flow Creation** (Day 2–3): Deploy 5 flows, configure triggers
3. **Integration Testing** (Day 4–5): End-to-end tests, error scenarios
4. **UAT & Sign-Off** (Day 6–7): Stakeholder testing, final approval
5. **Production Launch** (Day 8): Go-live, monitoring, support activation

**Timeline**: 7–10 business days  
**Success Criteria**: All flows passing integration tests, zero critical blockers, stakeholder sign-off

---

## Phase 1: Pre-Deployment Setup

### 1.1 Environment & Infrastructure

- [ ] **Verify D365 Instance Exists**
  - Instance URL: `https://va-form-extraction.crm.dynamics.com`
  - CRM version: Dynamics 365 (2024 or later recommended)
  - Status: Operational & accessible
  - Command:
    ```powershell
    $instanceUrl = "https://va-form-extraction.crm.dynamics.com"
    $response = Invoke-WebRequest -Uri "$instanceUrl/api/discovery/v2.0/instances" -ErrorAction SilentlyContinue
    if ($response.StatusCode -eq 200) { Write-Host "✅ D365 instance accessible" }
    ```

- [ ] **Verify Dataverse Environment Exists**
  - Environment name: VA Form Extraction
  - Organization ID: {UUID}
  - Admin user: flow@va-form-extraction.onmicrosoft.com
  - Command:
    ```powershell
    Get-AdminPowerAppEnvironment | Where-Object { $_.DisplayName -eq "VA Form Extraction" }
    ```

- [ ] **Verify All 5 Dataverse Tables Exist** (Polly's Stream A)
  - [ ] vafe_formsubmission
  - [ ] vafe_extractionresult
  - [ ] vafe_correctionrecord
  - [ ] vafe_auditlog
  - [ ] vafe_d365writeevent
  - Command:
    ```powershell
    $tables = @("vafe_formsubmission", "vafe_extractionresult", "vafe_correctionrecord", "vafe_auditlog", "vafe_d365writeevent")
    foreach ($table in $tables) {
      $record = Get-DataverseTable -LogicalName $table
      Write-Host "✅ Table $table exists (records: $($record.RecordCount))"
    }
    ```

- [ ] **Verify SharePoint FormIntake Library Exists**
  - Site: Department of Veteran Affairs (`/sites/DepartmentofVeteranAffairs`)
  - Library: FormIntake (document set)
  - Accessible: Yes
  - Command:
    ```powershell
    Connect-PnPOnline -Url "https://d365demotsce80677168.sharepoint.com/sites/DepartmentofVeteranAffairs"
    Get-PnPList | Where-Object { $_.Title -eq "FormIntake" }
    ```

- [ ] **Verify AI Builder Model Published** (Michael's Stream B-1)
  - Model name: VAForm10-3542-Extractor
  - Model ID: {from Michael Gray}
  - Status: Published
  - Version: v1
  - Contact Michael: `michael.gray@va-form-extraction.onmicrosoft.com`

### 1.2 Service Principal & Authentication

- [ ] **Create/Verify Service Principal**
  - Name: flow@va-form-extraction.onmicrosoft.com
  - Tenant: Your Entra ID tenant
  - Status: Active
  - Command:
    ```powershell
    $servicePrincipal = Get-AzADServicePrincipal -DisplayName "flow@va-form-extraction.onmicrosoft.com"
    Write-Host "Service Principal: $($servicePrincipal.Id)"
    ```

- [ ] **Assign D365 System Administrator Role to Service Principal**
  - Role: System Administrator
  - Organization: va-form-extraction
  - Command:
    ```powershell
    # In D365 Admin Center:
    # - Users → Service Principal Users
    # - Find: flow@va-form-extraction
    # - Assign: System Administrator security role
    ```

- [ ] **Create Entra ID App Registration** (If using OAuth)
  - App name: VA-Form-Extraction-Flow
  - App ID: {GUID}
  - Secret created: Yes (60-day expiry minimum recommended)
  - API permissions granted:
    - [ ] Dynamics CRM.user_impersonation
    - [ ] Microsoft Graph.User.Read
  - Command:
    ```powershell
    az ad app create --display-name "VA-Form-Extraction-Flow"
    az ad app credential create --id {app-id} --years 2
    ```

- [ ] **Store All Secrets in Azure Key Vault**
  - Vault name: va-form-kv
  - Secrets created:
    - [ ] `SharePointSiteUrl`
    - [ ] `DataverseEnvironmentUrl`
    - [ ] `DataverseOrgId`
    - [ ] `AIBuilderModelId`
    - [ ] `D365InstanceUrl`
    - [ ] `D365ServicePrincipalSecret`
    - [ ] `TeamsChannelId`
  - Command:
    ```powershell
    $secrets = @{
      "SharePointSiteUrl" = "https://d365demotsce80677168.sharepoint.com/sites/DepartmentofVeteranAffairs"
      "DataverseEnvironmentUrl" = "https://va-form-extraction.crm.dynamics.com"
      "AIBuilderModelId" = "$(model-id-from-michael)"
      "D365InstanceUrl" = "https://va-form-extraction.crm.dynamics.com"
    }
    foreach ($secret in $secrets.GetEnumerator()) {
      az keyvault secret set --vault-name va-form-kv --name $secret.Key --value $secret.Value
    }
    ```

### 1.3 Teams Channel Setup

- [ ] **Create Teams Channels**
  - [ ] #va-form-extraction-reviews (Low-confidence corrections)
  - [ ] #va-form-extraction-alerts (Errors & escalations)
  - [ ] #va-form-extraction-admin (Admin-only escalations)
  - [ ] #va-form-extraction-logs (Optional: Audit trail)

- [ ] **Install Power Automate Bot in Team**
  - Command: In Teams → Apps → Power Automate → Add to team → Select team "VA Form Extraction"

- [ ] **Verify Bot Has Permissions**
  - [ ] Can post messages to channels
  - [ ] Can post adaptive cards
  - [ ] Can create approval flows

### 1.4 Connection Setup

All Power Automate connections pre-created & tested:

- [ ] **SharePoint Connection**
  - Name: SharePointConn-VA-FormIntake
  - Authenticated: Yes (with service account)
  - Test: List libraries → confirm FormIntake visible

- [ ] **Dataverse Connection**
  - Name: DataverseConn-VA-Extraction
  - Authenticated: Yes (service principal OAuth)
  - Test: Query a record from vafe_formsubmission

- [ ] **Dynamics 365 Connection** (HTTP)
  - Name: D365HTTPConn-VA-Extraction
  - Authentication: OAuth Bearer Token
  - Test: GET /accounts?$top=1 → returns 200

- [ ] **Teams Connection**
  - Name: TeamsConn-VA-Extraction
  - Authenticated: Yes (service account)
  - Test: Post test message to #va-form-extraction-alerts

- [ ] **AI Builder Connection**
  - Name: Embedded (no separate connection needed)
  - Test: Verify model is selectable in Flow UI

---

## Phase 2: Flow Creation & Configuration

### 2.1 Create Main Flow: VA-Form-Intake-Pipeline

**Files to Reference**:
- `FLOW-ARCHITECTURE.md` (Steps 1–5)
- `FLOW-CONNECTOR-CONFIG.md` (Connector details)

**Steps**:

- [ ] **Create Cloud Flow (Automated)**
  ```
  Power Automate → Create → Automated cloud flow
  Name: VA-Form-Intake-Pipeline
  Trigger: "When a file is created or modified" (SharePoint)
  ```

- [ ] **Configure Trigger**
  - Site: Department of Veteran Affairs (`https://d365demotsce80677168.sharepoint.com/sites/DepartmentofVeteranAffairs`)
  - Library: FormIntake
  - Filter: "File name starts with VA-10-3542-"
  - Frequency: Every 1 minute

- [ ] **Implement Step 1: Validate & Parse Input File**
  - [ ] Get file metadata
  - [ ] Validate file type (pdf, tiff, png, jpg, jpeg)
  - [ ] Validate file size (<5MB)
  - [ ] Create FormSubmission record
  - [ ] Log intake event
  - Reference: FLOW-ARCHITECTURE.md Section 2 (Step 1)

- [ ] **Implement Step 2: Call AI Builder Model**
  - [ ] Get file content (binary)
  - [ ] Convert to base64
  - [ ] Invoke AI Builder model (VAForm10-3542-Extractor)
  - [ ] Capture extracted fields & confidence scores
  - [ ] Create ExtractionResult record
  - [ ] Log extraction event
  - Reference: FLOW-ARCHITECTURE.md Section 3 (Step 2)

- [ ] **Implement Step 3: Data Validation & Transformation**
  - [ ] Calculate average confidence
  - [ ] Check if all fields >0.85 threshold
  - [ ] If high confidence: Transform to D365 payload, create D365WriteEvent
  - [ ] If low confidence: Create CorrectionRecords, invoke Manual-Correction-Queue subflow
  - [ ] Update FormSubmission status
  - [ ] Log validation event
  - Reference: FLOW-ARCHITECTURE.md Section 4 (Step 3)

- [ ] **Implement Step 4: Write to Dynamics 365**
  - [ ] Check for duplicate accounts (SSN or name + DOB)
  - [ ] If new: Create account via D365 API
  - [ ] If exists: Update existing account
  - [ ] Create D365WriteEvent record
  - [ ] Log write event
  - Reference: FLOW-ARCHITECTURE.md Section 5 (Step 4)

- [ ] **Implement Step 5: Update FormSubmission Status & Complete**
  - [ ] Update FormSubmission status = "Written"
  - [ ] Link all related records (ExtractionResult, D365WriteEvent, AuditLog)
  - [ ] Mark form as locked (immutable)
  - [ ] Create final audit record
  - [ ] Send completion notification (if enabled)
  - Reference: FLOW-ARCHITECTURE.md Section 6 (Step 5)

- [ ] **Add Error Handlers**
  - [ ] Step 1 error → Log & notify submitter
  - [ ] Step 2 error → Retry 1x, then route to manual review
  - [ ] Step 3 error → Log & escalate
  - [ ] Step 4 error → Create pending D365WriteEvent (for retry flow)
  - [ ] Step 5 error → Log (form already written, so low priority)
  - Reference: FLOW-ARCHITECTURE.md Section 7 (Error Handling)

- [ ] **Save & Test Main Flow**
  - Save as: "VA-Form-Intake-Pipeline"
  - Cloud environment: VA Form Extraction (Production)

### 2.2 Create Subflow 1: Manual-Correction-Queue

**Files to Reference**:
- `MANUAL-CORRECTION-WORKFLOW.md` (Human review process)
- `FLOW-ARCHITECTURE.md` Section 8 (Subflow 1)

**Steps**:

- [ ] **Create Cloud Flow (Automated)**
  ```
  Power Automate → Create → Automated cloud flow
  Name: Manual-Correction-Queue
  Trigger: "Invoked from a cloud flow"
  Input parameters:
  ├─ FormSubmissionID (string)
  ├─ ExtractionResultID (string)
  ├─ LowConfidenceFields (array)
  └─ AutoReviewThreshold (decimal)
  ```

- [ ] **Implement Queue Logic**
  - [ ] Post approval card to Teams #va-form-extraction-reviews
  - [ ] Poll for CorrectionRecord updates (30-min timeout)
  - [ ] Apply corrections to ExtractionResult
  - [ ] Prepare corrected D365 payload
  - [ ] Invoke D365 write retry (back to Step 4 of main flow)

- [ ] **Save & Test Subflow**
  - Save as: "Manual-Correction-Queue"

### 2.3 Create Subflow 2: D365-Retry-Logic (Scheduled)

**Files to Reference**:
- `D365-RETRY-STRATEGY.md` (Exponential backoff)
- `FLOW-ARCHITECTURE.md` Section 9 (Subflow 2)

**Steps**:

- [ ] **Create Cloud Flow (Scheduled)**
  ```
  Power Automate → Create → Scheduled cloud flow
  Name: D365-Retry-Logic
  Schedule: Every 5 minutes
  ```

- [ ] **Implement Retry Logic**
  - [ ] Query for D365WriteEvent (status = Pending, retry_count < 5)
  - [ ] For each record:
    - [ ] Calculate exponential backoff (2^retry × 100 ms)
    - [ ] Wait before retry
    - [ ] Attempt D365 write (PATCH /accounts)
    - [ ] If success: Update status = "Success"
    - [ ] If failure: Increment retry_count, keep status = "Pending"
    - [ ] If max retries: Mark as "Failed", escalate
  - [ ] Handle error cases (404, 401/403, 409, etc.)
  - [ ] Create audit log entries

- [ ] **Save & Test Subflow**
  - Save as: "D365-Retry-Logic"

### 2.4 Create Subflow 3: Audit-Event-Logger

**Files to Reference**:
- `FLOW-ARCHITECTURE.md` Section 10 (Subflow 3)

**Steps**:

- [ ] **Create Cloud Flow (Automated)**
  ```
  Power Automate → Create → Automated cloud flow
  Name: Audit-Event-Logger
  Trigger: "Invoked from a cloud flow"
  Input parameters:
  ├─ FormSubmissionID (string)
  ├─ EventType (integer — 100000001–100000012)
  ├─ Status (integer — Success/Failure)
  └─ Details (object — JSON)
  ```

- [ ] **Implement Logging**
  - [ ] Create AuditLog record with all parameters
  - [ ] Set immutable flag on record (if Dataverse supports)

- [ ] **Save & Test Subflow**
  - Save as: "Audit-Event-Logger"

### 2.5 Create Subflow 4: Notification-Router

**Files to Reference**:
- `FLOW-ARCHITECTURE.md` Section 11 (Subflow 4)

**Steps**:

- [ ] **Create Cloud Flow (Automated)**
  ```
  Power Automate → Create → Automated cloud flow
  Name: Notification-Router
  Trigger: "Invoked from a cloud flow"
  Input parameters:
  ├─ FormSubmissionID (string)
  ├─ NotificationType (string)
  ├─ Severity (string — Info/Warning/Critical)
  └─ Recipients (array)
  ```

- [ ] **Implement Notification Logic**
  - [ ] Switch on NotificationType
  - [ ] Case 1: FormProcessingComplete → Teams success message
  - [ ] Case 2: D365WriteFailure → Teams alert + email admin
  - [ ] Case 3: CorrectionTimeoutEscalation → Teams escalation
  - [ ] Case 4: LowConfidenceRequiresReview → Teams review card

- [ ] **Save & Test Subflow**
  - Save as: "Notification-Router"

---

## Phase 3: Integration Testing

### 3.1 Unit Tests (Per Flow)

- [ ] **Main Flow Unit Tests**
  - [ ] Trigger: File upload → FormSubmission created ✅
  - [ ] Step 1: File validation → Accepts .pdf, .tiff, .png, .jpg, .jpeg ✅
  - [ ] Step 1: File validation → Rejects .doc, .exe, >5MB ✅
  - [ ] Step 2: AI extraction → Model returns fields & confidence scores ✅
  - [ ] Step 3: High confidence → D365WriteEvent created, ready for write ✅
  - [ ] Step 3: Low confidence → CorrectionRecords created, Manual-Correction-Queue invoked ✅
  - [ ] Step 4: D365 write → Account created successfully ✅
  - [ ] Step 4: D365 duplicate → Existing account updated ✅
  - [ ] Step 5: Status update → FormSubmission marked "Written" + locked ✅
  - [ ] Error handling: File validation error → Notification sent ✅

- [ ] **Manual-Correction-Queue Unit Tests**
  - [ ] Teams card posts to channel ✅
  - [ ] Poll loop detects CorrectionRecord.status = "Applied" ✅
  - [ ] 30-minute timeout escalates to admin ✅
  - [ ] Corrections applied to ExtractionResult ✅
  - [ ] D365 retry initiated with corrected values ✅

- [ ] **D365-Retry-Logic Unit Tests**
  - [ ] Scheduled trigger fires every 5 minutes ✅
  - [ ] Query returns pending records only ✅
  - [ ] Exponential backoff: Retry 1 = 100–150 ms ✅
  - [ ] Exponential backoff: Retry 2 = 200–250 ms ✅
  - [ ] Exponential backoff: Retry 3 = 400–450 ms ✅
  - [ ] Exponential backoff: Retry 4 = 800–850 ms ✅
  - [ ] Exponential backoff: Retry 5 = 1600–1650 ms ✅
  - [ ] Success on retry → Status = "Success" ✅
  - [ ] Max retries exceeded → Escalation task created ✅
  - [ ] Account deleted (404) → Escalation task created ✅

### 3.2 Integration Tests (End-to-End)

- [ ] **Test Scenario 1: High-Confidence Happy Path**
  - Setup: Upload test form with all fields >0.85 confidence
  - Expected: FormSubmission → Extraction → Validation → D365 write → Status "Written"
  - Duration: <60 seconds
  - Result: ✅ Pass / ❌ Fail

- [ ] **Test Scenario 2: Low-Confidence → Manual Correction → D365 Write**
  - Setup: Upload test form with 3 fields <0.85 confidence
  - Expected:
    1. CorrectionRecords created
    2. Teams card posted to #va-form-extraction-reviews
    3. Reviewer corrects fields
    4. Corrections applied to ExtractionResult
    5. D365 write retried with corrected values
    6. FormSubmission status = "Written"
  - Duration: <30 minutes (allows time for manual correction)
  - Result: ✅ Pass / ❌ Fail

- [ ] **Test Scenario 3: D365 Timeout → Auto-Retry → Success**
  - Setup: Mock D365 API to timeout on first attempt, succeed on second
  - Expected:
    1. D365WriteEvent created with status = "Pending"
    2. Main flow completes (doesn't wait for retry)
    3. D365-Retry-Logic scheduled flow runs in 5 min
    4. Retry succeeds, status = "Success"
    5. FormSubmission status = "Written"
  - Duration: ~6 minutes total
  - Result: ✅ Pass / ❌ Fail

- [ ] **Test Scenario 4: D365 Duplicate Account → Update Existing**
  - Setup: Upload form for existing veteran (match on SSN)
  - Expected:
    1. Duplicate detected
    2. Existing account updated (not created)
    3. AuditLog event: D365DuplicateDetected
    4. FormSubmission status = "Written"
  - Duration: <60 seconds
  - Result: ✅ Pass / ❌ Fail

- [ ] **Test Scenario 5: Invalid File Type → Rejection**
  - Setup: Upload .doc file
  - Expected:
    1. Trigger fires (file uploaded)
    2. Step 1 validation fails
    3. Error handler: FormSubmission status = "ValidationFailed"
    4. Notification sent to submitter
  - Duration: <10 seconds
  - Result: ✅ Pass / ❌ Fail

- [ ] **Test Scenario 6: D365 Account Not Found (404) → Escalation**
  - Setup: D365WriteEvent points to deleted account
  - Expected:
    1. D365-Retry-Logic detects 404 on account check
    2. D365WriteEvent status = "Failed"
    3. Escalation task created for admin
    4. Critical notification sent
  - Duration: ~6 minutes
  - Result: ✅ Pass / ❌ Fail

### 3.3 Performance Tests

- [ ] **End-to-End Timing <60 seconds**
  - Upload test form → All steps execute → Status "Written"
  - Actual time: _____ seconds
  - Target: <60 sec
  - Result: ✅ Pass / ❌ Fail

- [ ] **AI Extraction <10 seconds** (per Michael's SLA)
  - Expected: 5–10 sec per form
  - Actual time: _____ seconds
  - Result: ✅ Pass / ❌ Fail

- [ ] **D365 Write <5 seconds** (per SLA)
  - Expected: <5 sec per write call
  - Actual time: _____ seconds
  - Result: ✅ Pass / ❌ Fail

- [ ] **Scheduled Retry Cycle <45 seconds**
  - 10 pending records processed in parallel
  - Expected: <45 sec per cycle
  - Actual time: _____ seconds
  - Result: ✅ Pass / ❌ Fail

### 3.4 Security & Compliance Tests

- [ ] **No Hardcoded Secrets**
  - Verify: All secrets retrieved from Key Vault, not embedded in flow
  - Result: ✅ Pass / ❌ Fail

- [ ] **FormSubmission Immutable After "Written"**
  - Verify: form_locked = true prevents updates
  - Result: ✅ Pass / ❌ Fail

- [ ] **AuditLog Records Immutable**
  - Verify: Cascade rules prevent deletion of audit records
  - Result: ✅ Pass / ❌ Fail

- [ ] **Notifications Mask Sensitive Data**
  - Verify: Teams messages don't expose SSN, DOB, etc.
  - Result: ✅ Pass / ❌ Fail

- [ ] **Dataverse RBAC Enforced**
  - Verify: Users can only access FormSubmission records they own
  - Result: ✅ Pass / ❌ Fail

---

## Phase 4: UAT & Stakeholder Sign-Off

### 4.1 UAT with Data Entry Team

- [ ] **Schedule UAT Session**
  - Duration: 2 hours
  - Participants: 3–5 data entry staff
  - Date/Time: _____________

- [ ] **Test Scenarios with Real Data**
  - [ ] Participant 1: Upload & review high-confidence form (no corrections)
  - [ ] Participant 2: Upload & correct low-confidence form
  - [ ] Participant 3: Test dispute flow (mark field as needing escalation)
  - [ ] Participant 4: Upload second batch, verify queue management
  - [ ] Facilitator: Monitor for usability issues, confusion, bugs

- [ ] **Collect Feedback**
  - [ ] Power Apps form usability: ✅ Intuitive / ❌ Needs improvement
  - [ ] Teams notifications: ✅ Clear / ❌ Confusing
  - [ ] Correction process: ✅ Fast (<10 min) / ❌ Too slow
  - [ ] Issues/blockers: _____________________________________________

- [ ] **Sign-Off** (Data Entry Team Lead)
  - Name: _________________________
  - Date: __________________________
  - Approval: ✅ Approved / ❌ Needs changes

### 4.2 UAT with Operations Team

- [ ] **Schedule UAT Session**
  - Duration: 1 hour
  - Participants: Alfie (D365), IT Admin, On-Call Engineer
  - Date/Time: _____________

- [ ] **Test Operational Scenarios**
  - [ ] Monitor D365 Retry-Logic flow (watch retry cycle)
  - [ ] Simulate D365 connection failure → Verify retry + escalation
  - [ ] Simulate account deletion → Verify escalation task creation
  - [ ] Check monitoring dashboard (Power BI or custom)
  - [ ] Test alert thresholds

- [ ] **Verify Runbooks**
  - [ ] On-call engineer can follow troubleshooting guide
  - [ ] Escalation paths clear
  - [ ] Support contacts documented

- [ ] **Sign-Off** (Operations Lead)
  - Name: _________________________
  - Date: __________________________
  - Approval: ✅ Approved / ❌ Needs changes

### 4.3 Sign-Off from Tommy Shelby (Project Lead)

- [ ] **Code Review**
  - All flow configurations reviewed
  - Error handling verified
  - Security best practices followed
  - Performance metrics acceptable

- [ ] **Documentation Review**
  - [ ] FLOW-ARCHITECTURE.md complete & accurate
  - [ ] FLOW-CONNECTOR-CONFIG.md complete
  - [ ] MANUAL-CORRECTION-WORKFLOW.md clear
  - [ ] D365-RETRY-STRATEGY.md detailed
  - [ ] QUICK-START-FLOW-DEPLOYMENT.md (this checklist) complete

- [ ] **Sign-Off** (Tommy Shelby, Project Lead)
  - Name: _________________________
  - Date: __________________________
  - Approval: ✅ Approved for Production / ❌ Needs changes

---

## Phase 5: Production Launch

### 5.1 Pre-Launch Checklist (Day 0)

- [ ] **Backup All Configurations**
  - [ ] Export all 5 flows as cloud flow packages
  - [ ] Export all connections
  - [ ] Backup Dataverse tables (schema + sample records)
  - [ ] Store in shared drive: `\\va-form-extraction\backups\flows\2026-04-25\`

- [ ] **Communication Plan**
  - [ ] Email to all users: "Flow deployment scheduled for [Date]"
  - [ ] Share troubleshooting guide & support contact
  - [ ] Schedule standby support during launch window

- [ ] **Monitoring & Alerts Ready**
  - [ ] Power BI dashboard configured (optional)
  - [ ] Azure Monitor alerts configured
  - [ ] Teams channel for alerts active
  - [ ] On-call engineer assigned

- [ ] **Go/No-Go Decision**
  - [ ] All tests passed ✅
  - [ ] UAT sign-off obtained ✅
  - [ ] Stakeholders ready ✅
  - [ ] Decision: ✅ GO / ❌ NO-GO
  - [ ] Approver: Tommy Shelby
  - [ ] Date/Time: _____________

### 5.2 Launch Day Tasks

**Launch Window**: ___________ to ___________ (suggest 2-hour window)

- [ ] **Enable Flow Triggers** (Start of window)
  - [ ] Main Flow: VA-Form-Intake-Pipeline → Turn ON
  - [ ] Scheduled Flow: D365-Retry-Logic → Turn ON
  - [ ] Subflows: All enabled (auto-enabled when called from main)
  - [ ] Verify: All flows show "Enabled" status

- [ ] **Monitor Flow Execution** (Throughout window)
  - [ ] Check Power Automate dashboard for errors
  - [ ] Verify FormSubmission records created in Dataverse
  - [ ] Check D365 for new accounts written
  - [ ] Monitor Teams channel for alerts
  - [ ] Confirm no unexpected errors

- [ ] **Send Go-Live Notification**
  - [ ] Email to stakeholders: "Flows now live"
  - [ ] Include support contact & troubleshooting guide

- [ ] **Log Launch Event**
  - [ ] Create AuditLog entry (manual): "SystemLaunchCompleted"
  - [ ] Record: Date, time, who launched, any issues observed

### 5.3 Post-Launch (Day 1–7)

- [ ] **Daily Health Check** (First 7 days)
  - Day 1: Check flow execution count, error count, performance metrics
  - Day 2–7: Continue daily checks
  - Issues: Log, prioritize, escalate if critical

- [ ] **Weekly Metrics Review**
  - Forms processed: _____ (target: 50–60 per day)
  - Success rate: _____ % (target: >98%)
  - Avg processing time: _____ sec (target: <60 sec)
  - Correction queue pending: _____ (target: <5 at any time)
  - D365 write failures: _____ (target: 0)

- [ ] **Collect Feedback**
  - [ ] User satisfaction survey
  - [ ] Issues reported by data entry team
  - [ ] Issues reported by operations team
  - [ ] Performance feedback

- [ ] **Schedule Retrospective** (After first 5 days)
  - Participants: Tommy, John (Flow Lead), Polly (Schema), Michael (AI), Alfie (D365), Grace (QA)
  - Agenda: What went well, what needs improvement, lessons learned
  - Date/Time: _____________

---

## Rollback Plan (If Needed)

**If critical issues found post-launch**:

- [ ] **Immediate Actions**
  - [ ] Turn OFF all flow triggers
  - [ ] Notify all users: "Forms intake temporarily paused for maintenance"
  - [ ] Create incident ticket

- [ ] **Rollback Steps**
  1. Stop all scheduled flows (D365-Retry-Logic, etc.)
  2. Delete any corrupted records from Dataverse (if applicable)
  3. Restore flows from backup (or revert to previous version)
  4. Re-test with sample data
  5. Get sign-off from Tommy before re-enabling

- [ ] **Root Cause Analysis**
  - [ ] Document what failed
  - [ ] Identify root cause
  - [ ] Develop fix
  - [ ] Test fix
  - [ ] Re-launch with approval

---

## Support & Handoff

### On-Call Support

**Primary**: John Shelby (Flow Lead)  
**Secondary**: Alfie Solomons (D365 Integration)  
**Escalation**: Tommy Shelby (Project Lead)

**Support Contact**:
- Email: flow-support@va-form-extraction.onmicrosoft.com
- Teams: @flow-support-channel
- Escalation: @tommy-shelby (Teams)

### Runbooks Provided

- [ ] Troubleshooting guide (D365-RETRY-STRATEGY.md)
- [ ] Manual correction workflow (MANUAL-CORRECTION-WORKFLOW.md)
- [ ] Flow architecture reference (FLOW-ARCHITECTURE.md)
- [ ] Connector config reference (FLOW-CONNECTOR-CONFIG.md)
- [ ] On-call playbook (attached separately)

### Training Scheduled

- [ ] Data Entry Team: Manual Correction Workflow training
- [ ] Operations Team: Troubleshooting & escalation training
- [ ] Admin Team: Flow monitoring & health checks training

---

## Sign-Off

**Deployment Lead**: _________________________  
**Date**: __________________________________

**Project Lead (Tommy Shelby)**: _________________  
**Date**: __________________________________

**QA Lead (Grace Burgess)**: _________________________  
**Date**: __________________________________

---

## Appendix: Quick Reference

### Key Contacts

| Role | Name | Email | Teams |
|------|------|-------|-------|
| Flow Orchestration Lead | John Shelby | john.shelby@va-form-extraction | @john-shelby |
| D365 Integration Lead | Alfie Solomons | alfie.solomons@va-form-extraction | @alfie-solomons |
| Dataverse Schema Lead | Polly Gray | polly.gray@va-form-extraction | @polly-gray |
| AI Model Lead | Michael Gray | michael.gray@va-form-extraction | @michael-gray |
| QA Lead | Grace Burgess | grace.burgess@va-form-extraction | @grace-burgess |
| Project Lead | Tommy Shelby | tommy.shelby@va-form-extraction | @tommy-shelby |

### Key URLs

| Resource | URL |
|----------|-----|
| Power Automate Cloud Portal | https://make.powerautomate.com |
| D365 Instance | https://va-form-extraction.crm.dynamics.com |
| Dataverse Admin | https://admin.poweraplatform.com |
| Azure Key Vault | https://va-form-kv.vault.azure.net |
| SharePoint FormIntake | https://d365demotsce80677168.sharepoint.com/sites/DepartmentofVeteranAffairs/FormIntake |

### Key Documents

- FLOW-ARCHITECTURE.md (Full technical design)
- FLOW-CONNECTOR-CONFIG.md (Connector setup details)
- MANUAL-CORRECTION-WORKFLOW.md (Human review process)
- D365-RETRY-STRATEGY.md (Exponential backoff strategy)

---

**Status**: ✅ **DEPLOYMENT CHECKLIST COMPLETE & READY FOR USE**

**Prepared by**: John Shelby, Flow Orchestration Lead  
**Date**: 2026-04-25  
**Audience**: Tommy Shelby (Deployment Lead), Deployment Team  
**Ready for**: Phase 2 production deployment
