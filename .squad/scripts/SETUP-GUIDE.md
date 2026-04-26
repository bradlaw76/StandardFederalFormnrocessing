# Full Automation Setup Guide
## VA Form Extraction — Dataverse Table Provisioning

> **Do this ONCE. After setup, run `provision-full.ps1` against any environment in seconds.**

---

## Why This Is Required

Dataverse's metadata API (table/field/relationship creation) enforces **application identity**, not user
identity, even when the user is a tenant admin. An interactive `az login` token is **rejected** for
`/api/data/v9.2/EntityDefinitions` calls. You need:

1. An **Azure App Registration** (client ID + secret)
2. That app added as a **Power Platform Application User** with the **System Administrator** security role
3. Nothing else — no MSAL library, no extra tooling

Total one-time setup: **~15 minutes**

---

## Step 1 — Create an Azure App Registration

**Portal:** https://portal.azure.com → Entra ID → App registrations → New registration

| Field | Value |
|-------|-------|
| Name | `VA-Form-Extraction-Automation` |
| Supported account types | Single tenant |
| Redirect URI | leave blank |

Click **Register**.

### Record these values:
- **Application (client) ID** ← `$ClientId` in the script
- **Directory (tenant) ID** ← `$TenantId` in the script

---

## Step 2 — Create a Client Secret

App registration → **Certificates & secrets** → **New client secret**

| Field | Value |
|-------|-------|
| Description | `dataverse-automation` |
| Expires | 24 months |

Click **Add**. **Copy the Value immediately** (you cannot view it again).

> Store it in: `.env.automation` (gitignored) or a local file you keep safe.

---

## Step 3 — Add Dynamics CRM API Permission

App registration → **API permissions** → **Add a permission** → **Dynamics CRM**

| Setting | Value |
|---------|-------|
| Permission | `user_impersonation` |
| Type | Delegated |

Click **Add permissions** → Then **Grant admin consent for [tenant]** → Confirm.

---

## Step 4 — Add the App as a Power Platform Application User

This is the critical step that connects the Azure app to Dataverse.

**Portal:** https://admin.powerplatform.microsoft.com

1. Go to **Environments** → Select **Contact Center** → **Settings** → **Users + permissions** → **Application users**
2. Click **+ New app user**
3. Click **+ Add an app** → Search for `VA-Form-Extraction-Automation` → Select it → **Add**
4. Business unit: **Root BU** (default)
5. Security roles: Click **Edit security roles** → Add **System Administrator**
6. Click **Create**

✅ The app is now a Dataverse identity that can create tables.

---

## Step 5 — Save Credentials to `.env.automation`

Create this file at the repo root (it's already in `.gitignore`):

```
DATAVERSE_CLIENT_ID=<paste Application (client) ID>
DATAVERSE_CLIENT_SECRET=<paste client secret value>
DATAVERSE_TENANT_ID=d365demotsce80677168.onmicrosoft.com
DATAVERSE_ORG_URL=https://healthconnectcenter.crm.dynamics.com
```

> The provisioning script reads this file automatically. Never commit it.

---

## Step 6 — Run the Automation Script

```powershell
cd <repo root>
.\.squad\scripts\provision-full.ps1
```

That's it. All 5 tables + all fields + all relationships will be created in ~60 seconds.

---

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `401 Unauthorized` | App not added as App User | Redo Step 4 |
| `403 Forbidden` | App User missing System Administrator role | Re-assign security role in Step 4 |
| `0x80048d19 Payload error` | Token is interactive (user), not app | Verify Step 3 (admin consent granted) |
| `AADSTS700016` | App not found in tenant | Redo Step 1 in the **correct tenant** (`d365demotsce80677168`) |

---

## To Reuse on a New Environment

Just run:

```powershell
.\.squad\scripts\provision-full.ps1 -OrgUrl "https://NEWENV.crm.dynamics.com" -SolutionName "MyNewSolution"
```

No UI. No manual steps.
