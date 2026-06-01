# T008 Execution Checklist: Configure Entra ID for VA Staff Authentication

**Owner**: ⚙️ Arthur Shelby  
**Issue**: #10 [T008]  
**Estimated Time**: 30–45 min  
**Depends On**: T001 (Power Platform Environment) ✅ *Recommended to complete first*  
**Status**: READY  

---

## Overview
Configure Microsoft Entra ID (Azure AD) authentication for VA staff users. Set up Entra ID app registration (if needed), OAuth2/client credentials, and verify VA staff group for role assignment.

---

## Pre-Flight Checks

### ✅ Prerequisites
- [ ] T001 (Power Platform Environment) is **COMPLETE**
- [ ] You have Microsoft Entra ID admin access
- [ ] You can access **Entra admin center**: https://entra.microsoft.com
- [ ] VA staff group identifier is available (or you can create one)
- [ ] Service account credentials can be obtained from your IT/security team

---

## Execution Steps

### Step 1: Verify Entra ID Tenant Configuration

#### 1a. Access Entra Admin Center
1. Navigate to **Entra admin center**: https://entra.microsoft.com
2. Sign in with tenant admin credentials
3. **Expected**: Dashboard shows tenant information

#### 1b: Verify Tenant Details
1. In sidebar, go **Identity** → **Overview** or **Dashboard**
2. Verify you see:
   - Tenant ID (GUID format)
   - Tenant name (e.g., `contoso.onmicrosoft.com`)
   - Directory status: **Active**
3. **Record Tenant ID** — you'll need this for documentation

### Step 2: Create or Verify Entra ID App Registration

#### 2a. Navigate to App Registrations
1. In **Entra admin center**, go to **Applications** → **App registrations** (left sidebar)
2. Click **+ New registration** (or search for existing `VAFormProcessing` app)
3. **Expected**: You see list of existing apps or registration form

#### 2b: Check for Existing App Registration
**Search for existing app** (if already created):
1. In **App registrations**, search for:
   - `VAFormProcessing`
   - `VA Form Extraction`
   - `StandardFederalFormProcessing`
2. **If FOUND**: Skip to Step 3 (Verify App Configuration)
3. **If NOT FOUND**: Proceed to Step 2c (Create New App)

#### 2c: Create New App Registration
1. Click **+ New registration**
2. Fill in the form:
   - **Name**: `VA Form Extraction Pipeline`
   - **Supported account types**: Select **Accounts in this organizational directory only** (single tenant)
   - **Redirect URI**: 
     - **Platform**: Select **Web** (for service account)
     - **URI**: `https://[tenant].sharepoint.com/sites/VAFormProcessing` (or your Power Platform environment URL)
   - Click **Register**
3. **Expected**: App registration created and you're on the app details page

#### 2d: Document App ID & Tenant ID
1. On the app details page, note:
   - **Application (client) ID**: Copy this (UUID format)
   - **Directory (tenant) ID**: Copy this (UUID format)
2. **Save these values** — you'll need them in Step 3

### Step 3: Configure Client Credentials (OAuth2)

#### 3a. Create Client Secret
1. In the app registration, go to **Certificates & secrets** (left sidebar)
2. Click **+ New client secret**
3. Fill in:
   - **Description**: `VA Form Pipeline Service Account`
   - **Expires**: Select **24 months** (or per your security policy)
4. Click **Add**
5. **IMPORTANT**: Copy the secret value immediately and save it securely (password manager, Key Vault, etc.)
   - ⚠️ **You cannot retrieve this value again** — must copy now or create new secret later

#### 3b: Document Client Credentials
```yaml
APP_REGISTRATION:
  app_name: "VA Form Extraction Pipeline"
  client_id: "[ COPY FROM APP DETAILS ]"
  tenant_id: "[ COPY FROM APP DETAILS ]"
  client_secret: "[ COPY FROM SECRETS PAGE — SAVE SECURELY ]"
  client_secret_expiry: "[ 24 months from today ]"
  created_at: "2026-04-24"
```

### Step 4: Assign Permissions to App

#### 4a. Navigate to API Permissions
1. In app registration, go to **API permissions** (left sidebar)
2. Click **+ Add a permission**
3. **Expected**: Permission selection dialog opens

#### 4b: Add Required Permissions
Add permissions for:

**1. Microsoft Graph** (for user/group operations)
- Click **Microsoft Graph**
- Select **Delegated permissions**
- Search and select:
  - `Directory.Read.All` (read groups and users)
  - `User.Read` (read current user)
- Click **Add permissions**

**2. Dynamics 365** (if connecting to D365)
- Click **APIs my organization uses**
- Search for: `Dynamics 365`
- Select **Dynamics 365 Service**
- Select **user_impersonation**
- Click **Add permissions**

**3. Power Platform / Dataverse** (if connecting to Power Platform)
- Click **APIs my organization uses**
- Search for: `Dataverse` or `Common Data Service`
- Select **user_impersonation**
- Click **Add permissions**

#### 4c: Grant Admin Consent
1. After adding permissions, you should see an **Grant admin consent** button
2. Click **Grant admin consent for [Tenant Name]**
3. **Expected**: Permissions show status **Granted** (green checkmark)
4. ⏳ If not, wait 1-2 minutes and refresh

### Step 5: Create or Verify VA Staff Group

#### 5a. Navigate to Groups
1. In **Entra admin center**, go to **Identity** → **Groups** → **All groups** (left sidebar)
2. Click **+ New group**
3. Search first for existing groups:
   - `VA Staff`
   - `VA Form Reviewers`
   - `VA Personnel`
4. **If FOUND**: Skip to Step 5c (Add Members)
5. **If NOT FOUND**: Proceed to Step 5b (Create New Group)

#### 5b: Create VA Staff Group
1. Click **+ New group**
2. Fill in:
   - **Group type**: `Security` (not Microsoft 365)
   - **Group name**: `VA Staff`
   - **Group description**: `VA personnel for Form 10-3542 processing`
   - **Membership type**: `Assigned` (not Dynamic)
   - **Owners**: Add yourself
3. Click **Create**
4. **Expected**: Group created and you're on group details page

#### 5c: Add VA Staff Members (If Known)
1. In the group details, go to **Members** or **Add members**
2. Search for VA staff users in your organization
3. Add them to the group (or come back to this step later when staff list is available)
4. **Expected**: Members appear in the group member list

#### 5d: Document Group Details
```yaml
VA_STAFF_GROUP:
  group_name: "VA Staff"
  group_id: "[ COPY FROM GROUP DETAILS ]"
  group_type: "Security"
  description: "VA personnel for Form 10-3542 processing"
  members_count: "[ Number of members ]"
  created_at: "2026-04-24"
```

### Step 6: Test Service Account Authentication

#### 6a: Prepare Test
You'll test that the service account (app registration) can authenticate. This requires:
- Client ID (from Step 3)
- Client Secret (from Step 3)
- Tenant ID (from Step 1)

#### 6b: Test OAuth2 Flow (Using cURL or Postman)
1. Open **Postman** or your terminal with `curl`
2. Make a POST request to:
   ```
   https://login.microsoftonline.com/{tenant-id}/oauth2/v2.0/token
   ```
   Where `{tenant-id}` is your Tenant ID

3. In Postman, set:
   - **Method**: POST
   - **Headers**: 
     ```
     Content-Type: application/x-www-form-urlencoded
     ```
   - **Body** (form-data):
     ```
     client_id = {your-client-id}
     client_secret = {your-client-secret}
     scope = https://graph.microsoft.com/.default
     grant_type = client_credentials
     ```

4. Click **Send**
5. **Expected**: Response contains:
   ```json
   {
     "access_token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
     "token_type": "Bearer",
     "expires_in": 3599
   }
   ```

#### 6c: Interpret Results
- ✅ **Success**: You received an `access_token` → Service account authentication works
- ❌ **Error 401**: Client credentials incorrect (verify client ID/secret)
- ❌ **Error 400**: Tenant ID or scope incorrect (verify tenant ID and scope)

#### 6d: Test Graph API Call (Optional)
If token obtained successfully:
1. Copy the `access_token` value
2. Make a GET request to:
   ```
   https://graph.microsoft.com/v1.0/me
   ```
3. In Postman/curl:
   - **Method**: GET
   - **Headers**:
     ```
     Authorization: Bearer {access_token}
     ```
4. Click **Send**
5. **Expected**: Returns current user info (service account details)

### Step 7: Verify Integration Points

#### 7a: Verify Service Account Can Access Power Platform
1. Go to **Power Platform Admin Center**: https://admin.powerplatform.microsoft.com
2. Verify that the service account app registration is recognized
3. (Optional) Assign Power Platform license/roles to service account

#### 7b: Verify Service Account Can Access Dynamics 365
1. If D365 is in scope, verify service account can:
   - Authenticate to D365
   - Create test records
2. (Optional) Assign D365 security role to service account

---

## Documentation: Entra ID Configuration Summary

### ✅ Required Details (Record These)

```yaml
ENTRA_ID_CONFIGURATION:
  tenant_id: "[ COPY FROM TENANT DETAILS ]"
  tenant_name: "[ e.g., contoso.onmicrosoft.com ]"
  
  app_registration:
    app_name: "VA Form Extraction Pipeline"
    client_id: "[ COPY FROM APP REGISTRATION ]"
    client_secret: "[ SAVE SECURELY — DO NOT COMMIT ]"
    client_secret_expiry: "2028-04-24"
    
  api_permissions:
    microsoft_graph: "[ Directory.Read.All, User.Read — Status: Granted ]"
    dynamics_365: "[ user_impersonation — Status: Granted ]"
    dataverse: "[ user_impersonation — Status: Granted ]"
    
  va_staff_group:
    group_name: "VA Staff"
    group_id: "[ COPY FROM GROUP DETAILS ]"
    description: "VA personnel for Form 10-3542 processing"
    member_count: "[ Number or 'TBD' ]"
    
  service_account_tested: true
  oauth2_authentication: "[ Working or Failed ]"
  graph_api_access: "[ Working or Failed ]"
  
  created_at: "2026-04-24"
```

---

## Acceptance Criteria Checklist

### ✅ AC1: Entra ID tenant configured/verified
- [ ] Tenant ID documented
- [ ] Tenant is Active and accessible
- [ ] You have admin permissions in Entra ID

### ✅ AC2: Delegated admin access for VA staff configured
- [ ] App registration created: `VA Form Extraction Pipeline`
- [ ] Client ID and Client Secret obtained
- [ ] OAuth2 credentials documented

### ✅ AC3: Test user/service account login succeeds
- [ ] OAuth2 authentication test passed (received access token)
- [ ] Service account can call Microsoft Graph API
- [ ] No authentication errors

### ✅ AC4: Groups/roles for VA staff defined
- [ ] `VA Staff` security group created
- [ ] Group ID documented
- [ ] VA staff members can be added to group (or placeholder added)

### ✅ AC5: Report — Entra ID auth ready
- [ ] All documentation complete
- [ ] Service account credentials secured (not in source code)
- [ ] Integration points verified (Power Platform, D365 access)
- [ ] Ready for Power Apps/flows to use service account

---

## Readiness Indicators

### 🟢 Ready to Proceed to Power Apps & Flows IF:
- [x] App registration created and credentials obtained
- [x] OAuth2 authentication tested and working
- [x] VA Staff group defined
- [x] All documentation complete

### 🔴 Blocker — Cannot Proceed IF:
- Client credentials cannot be obtained
- OAuth2 authentication fails
- Permissions cannot be granted
- VA staff group cannot be created

---

## Security Best Practices

### 🔐 Credential Management
- [ ] **DO**: Store client secret in Azure Key Vault or secure credential manager
- [ ] **DO NOT**: Commit client secret to GitHub or source code
- [ ] **DO**: Rotate client secret every 12 months
- [ ] **DO**: Use separate service accounts for dev/test/prod environments

### 🔐 Permission Principle
- [ ] App registration has **minimum required permissions** (no over-provisioning)
- [ ] Service account role limited to needed scope (read groups, write records, etc.)
- [ ] Entra ID conditional access policies applied (if configured)

### 🔐 Audit Trail
- [ ] Log all service account actions (via Azure Monitor)
- [ ] Enable Entra ID sign-in logs for monitoring
- [ ] Set up alerts for suspicious service account activity

---

## Troubleshooting

### ❌ Problem: "Cannot create app registration — permission denied"
**Cause**: User role is not app registration admin  
**Solution**:
1. Verify you have **Application Administrator** role in Entra ID
2. Contact your Entra ID admin to grant role
3. Or ask admin to create app registration on your behalf

### ❌ Problem: "Client secret not visible after creation"
**Cause**: Secret value only shown once at creation  
**Solution**:
1. Create a new client secret (the old one is not accessible)
2. Or use existing secret if you saved it immediately
3. Save secrets securely using password manager or Azure Key Vault

### ❌ Problem: "OAuth2 authentication returns 401 error"
**Cause**: Invalid client ID, secret, or tenant ID  
**Solution**:
1. Verify client ID and secret exactly match app registration
2. Verify tenant ID matches your Entra ID tenant
3. Verify client secret hasn't expired
4. Try creating new client secret and testing again

### ❌ Problem: "Cannot add permissions — error 'Invalid resource'"
**Cause**: Resource (Dynamics 365, Dataverse) not available in organization  
**Solution**:
1. Verify the resource is provisioned in your tenant
2. For D365: Verify Dynamics 365 license/instance exists
3. For Dataverse: Verify Power Platform environment exists (T001)
4. Contact your Microsoft admin if resource unavailable

### ❌ Problem: "VA Staff group creation fails"
**Cause**: Group already exists or naming conflict  
**Solution**:
1. Search for existing group with similar name (case-insensitive)
2. Use existing group instead
3. Or use alternate name: `VAFormStaff` or `VAFormProcessing_Users`

---

## Hand-Off Notes

### 🎯 When T008 is Complete:
1. ✅ Document all Entra ID details in YAML above
2. ✅ Confirm all AC items are checked
3. ✅ Service account credentials secured (Key Vault or password manager)
4. ✅ **Dependency unblocked**: Power Apps, flows, and D365 integration can use Entra ID auth
5. ✅ Entra ID authentication ready for Phase 2+ (user provisioning, role assignment)

### 📋 Next Steps:
- **T006** (Polly Gray): Create Power Platform Solution
- **T007** (Michael Gray): Verify AI Builder Capacity
- **T030+** (John Shelby): Build flows (will use service account credentials)
- **T050+** (Lizzie Stark): Build Power Apps (will use Entra ID groups for access control)

### 🔒 Security Reminder:
- [ ] Store client secret in **Azure Key Vault**, not source code
- [ ] Rotate client secret in 12 months
- [ ] Monitor service account activity via Azure Monitor
- [ ] Enable Entra ID sign-in logs for audit

---

## Session Log

| Time | Step | Status | Notes |
|------|------|--------|-------|
| — | Pre-Flight Checks | PENDING | — |
| — | Step 1: Tenant Verification | PENDING | — |
| — | Step 2: App Registration | PENDING | — |
| — | Step 3: Client Credentials | PENDING | — |
| — | Step 4: API Permissions | PENDING | — |
| — | Step 5: VA Staff Group | PENDING | — |
| — | Step 6: Authentication Test | PENDING | — |
| — | Step 7: Integration Verification | PENDING | — |
| — | Documentation | PENDING | — |
| — | **COMPLETE** | — | — |

---

*End T008 Execution Checklist*
