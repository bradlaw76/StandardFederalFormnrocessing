# D365 Connector Setup Guide — Issue #6 [T004]

**Owner**: Alfie Solomons (Dynamics Integration)  
**Status**: In Progress  
**Started**: 2026-04-24  
**Target Completion**: 30–45 min

---

## Objective

Configure the Dynamics 365 connector in Power Platform to enable the VA Form extraction pipeline to write processed form data to D365. Verify OAuth2 authentication, establish trusted connection, and test basic query operations.

---

## Setup Plan

### Phase A: Prerequisites Check (5 min)

Before starting D365 connector configuration, verify:

- [ ] Power Platform environment is created and accessible (depends on T001)
- [ ] Admin or Power Platform admin role in target environment
- [ ] Dynamics 365 instance URL (e.g., `https://org.crm.dynamics.com`)
- [ ] D365 tenant user credentials with API access
- [ ] Service principal / app registration available (OAuth2 authentication)

**Note**: If using app registration, verify the following app permissions in Entra ID:
- `Dynamics CRM.AccessAsOrganization`
- `Dynamics CRM.user_impersonation`

---

### Phase B: D365 Connector Configuration in Power Automate (15 min)

#### Step 1: Open Power Automate Connections

1. Navigate to [Power Automate](https://make.powerautomate.com)
2. Sign in with credentials for the target Power Platform environment
3. In the left sidebar, click **Connections**

#### Step 2: Create New Connection

1. Click **New Connection** (top-left)
2. Search for **Dynamics 365**
3. Select **Dynamics 365** connector from results
4. Click **Create**

#### Step 3: OAuth2 Authentication

The OAuth2 flow will prompt:

**Connection Name**: 
```
VA-Form-D365-Prod
```

**Connection Type**: 
- Select **Cloud** (for online D365)
- OR **On-Premises** (if your D365 is on-premises)

**Credentials**:
- Choose one of two methods:

**Method 1: User Account (Recommended for testing)**
```
- Username: [D365 user account]
- Password: [User password]
- Dynamics 365 URL: https://org.crm.dynamics.com
```

**Method 2: Service Principal (App Registration)**
```
- Tenant ID: [Azure Entra ID Tenant ID]
- Client ID: [App Registration Client/App ID]
- Client Secret: [App Registration Secret]
- Dynamics 365 URL: https://org.crm.dynamics.com
```

#### Step 4: Verify Connection

1. After entering credentials, click **Sign in** or **Create**
2. Power Automate will test the connection
3. If successful, you'll see: ✅ **Connection created successfully**
4. If failed, see **Troubleshooting** section below

---

### Phase C: Service Account / App Registration Setup (10 min)

#### Option A: Using Existing User Account (Simpler)

If testing with a standard D365 user account:

1. Ensure user has **System Administrator** or **Dynamics CRM Online Application Access** role
2. User account must have API access enabled
3. Password must not be set to never expire (if enforced by policy)

**Verification**:
```
In D365 Admin Center:
→ Settings > Security > Users
→ Select user > Manage roles
→ Verify "System Administrator" or similar role is assigned
```

#### Option B: Using App Registration (Recommended for Production)

If using service principal authentication:

1. Navigate to [Azure Entra ID](https://entra.microsoft.com)
2. **Register new application**:
   - Name: `VA-Form-D365-Integration`
   - Supported account types: Single tenant
   - Click **Register**

3. **Grant API Permissions**:
   - Go to **API permissions** in new app registration
   - Click **Add a permission**
   - Search: **Dynamics CRM**
   - Select **Dynamics CRM** (Microsoft)
   - Grant **Delegated permissions**:
     - `user_impersonation`
   - Click **Grant admin consent**

4. **Create Client Secret**:
   - Go to **Certificates & secrets**
   - Click **New client secret**
   - Description: `D365 Integration Secret`
   - Expires: 24 months (or as per security policy)
   - Copy **Value** (you'll need this for Power Automate)

5. **Assign D365 License**:
   - In D365 Admin Center → Settings > Security > Users
   - Create new user for app registration
   - Grant **System Administrator** or custom role with D365 API access
   - Assign D365 license

---

### Phase D: Test D365 Connectivity (10 min)

#### Test 1: List Records (Simple Query)

Create a **test flow** to verify connectivity:

1. In Power Automate, click **Create** → **Cloud flow** → **Automated flow**
2. Trigger: **Manual trigger** (button)
3. Add action: **Dynamics 365** → **List records**
4. Connection: Select your D365 connection (`VA-Form-D365-Prod`)
5. Organization name: (auto-populated from connection)
6. Table name: **Accounts** (standard table for test)
7. Click **Save**
8. Click **Test** → **Manually** → **Run flow**
9. **Expected result**: ✅ Flow runs successfully and returns account records

**Output** (if successful):
```
{
  "value": [
    {
      "accountid": "550e8400-e29b-41d4-a716-446655440000",
      "name": "Adventure Works",
      "customertypecode": "1"
    },
    ...
  ]
}
```

#### Test 2: Create Record (Write Operation)

Create a test record to verify write permissions:

1. Add action to flow: **Dynamics 365** → **Create a new record**
2. Organization name: (auto-populated)
3. Table name: **Contacts** (standard table)
4. Fill in required fields:
   - **First Name**: "Test"
   - **Last Name**: "Connection"
   - **Email**: "test@integration.local"
5. Click **Save**
6. Click **Test** → **Run flow**
7. **Expected result**: ✅ New contact created in D365

**Verification in D365**:
- Navigate to Contacts
- Search for "Test Connection"
- Verify record exists with correct data

---

## Troubleshooting

### Issue 1: "Invalid credentials" during OAuth2

**Possible Causes**:
1. Username/password incorrect
2. Account locked (too many failed login attempts)
3. Multi-factor authentication (MFA) enabled but not set up in Power Automate
4. User doesn't have D365 license

**Resolution**:
- [ ] Verify credentials are correct
- [ ] Check D365 user status (not locked, license active)
- [ ] If MFA enabled, disable for service account or use app registration instead
- [ ] Test login directly in D365 first to confirm access

### Issue 2: "Dynamics 365 URL not found"

**Possible Causes**:
1. Incorrect URL format (e.g., missing `https://`)
2. Org slug is wrong
3. D365 environment is deleted or not provisioned

**Resolution**:
- [ ] Verify URL in D365 Admin Center
- [ ] URL should be: `https://[organization-name].crm.dynamics.com`
- [ ] Copy URL directly from browser address bar in D365

### Issue 3: "Insufficient permissions" when creating records

**Possible Causes**:
1. User/app registration doesn't have write access to table
2. Role doesn't include "Create" permission for table
3. Field is read-only in D365

**Resolution**:
- [ ] In D365 Security Roles, grant Create, Update, Delete on target table
- [ ] Verify user has correct role assigned
- [ ] Check table/field security level settings

### Issue 4: "Connection timeout"

**Possible Causes**:
1. Network connectivity issue
2. D365 instance is offline/being upgraded
3. Firewall blocking Power Automate → D365 traffic

**Resolution**:
- [ ] Test D365 access directly in browser
- [ ] Check D365 service health status
- [ ] If on-premises D365, verify gateway is running and network accessible

---

## Testing Checklist

- [ ] D365 connection created in Power Automate
- [ ] OAuth2 authentication successful
- [ ] Test flow: List records returns data
- [ ] Test flow: Create record successful
- [ ] Record created in D365 is visible and correct
- [ ] User/app registration has sufficient permissions
- [ ] D365 URL verified and documented
- [ ] No timeout or network errors
- [ ] Multi-attempt failures (if any) documented

---

## Deliverables

✅ **Connection Configuration**:
- Connection name: `VA-Form-D365-Prod`
- Connection type: OAuth2
- D365 instance URL: [documented]
- Authentication method: [User Account / App Registration]

✅ **Test Evidence**:
- Screenshot: D365 connection successful
- Screenshot: List records test passed
- Screenshot: Create record test passed
- Test record name: "Test Connection" (Contact in D365)

✅ **Documentation**:
- D365 connector ready for flow integration
- Connection credentials securely stored
- Troubleshooting notes (if any issues encountered)
- Next steps: Field mapping for VA_FormSubmission table

---

## Next Steps (Phase 2 Dependency)

Once D365 connector is verified working:

1. **Polly Gray** (T006): Create Power Platform Solution
2. **Field Mapping** (T009): Map D365 fields to VA_FormSubmission table
3. **John Shelby** (T010): Build D365 write action in intake flow

---

## Notes

- **Critical Path**: D365 connector is blocking Phase 5–6 D365 write operations
- **Handoff**: Verify connection → Hand off to John Shelby for flow integration
- **Permissions**: Service account must have continuous API access (no session timeout)
- **OAuth2 Refresh**: Power Automate handles token refresh automatically

**Started**: 2026-04-24T00:00:00Z  
**Status**: Setup in progress  
**Next Update**: Upon test completion
