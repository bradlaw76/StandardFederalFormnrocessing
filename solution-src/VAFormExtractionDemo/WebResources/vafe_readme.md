# VAFE Dashboard Web Resources — Deployment Guide

VA Form 10-3542 Extraction Pipeline · Dynamics 365 Model-Driven App

---

## File Inventory

| File | Type | Purpose |
|------|------|---------|
| `vafe_report.html` | HTML Web Resource | Dashboard shell — semantic landmarks, section containers, no inline JS |
| `vafe_report.css`  | CSS Web Resource  | All styles — design tokens, layout, responsive, print stylesheet |
| `vafe_data_adapter.js` | Script Web Resource | Mock + Dataverse providers, Xrm context discovery, normalized schema |
| `vafe_export.js`   | Script Web Resource | `printReport()` and `exportActionsCsv()` — no external deps |
| `vafe_report.js`   | Script Web Resource | Main app — render pipeline, calculations, filter state, event delegation |

Optional sixth file (not auto-generated):

| File | Type | Purpose |
|------|------|---------|
| `vafe_config.js`   | Script Web Resource | Declares `var VAFE_CONFIG = { useMock: false };` for production |

---

## Uploading Files as D365 Web Resources

1. Open **make.powerapps.com** → select your environment.
2. Navigate to **Solutions** → open your solution (e.g., `VAFormExtractionDemo`).
3. Select **New → Web resource**.
4. For each file:
   - **Display name**: human-readable label (e.g., `VAFE Report HTML`)
   - **Name**: logical name (see naming convention below)
   - **Type**: HTML Page / Style Sheet / Script (JScript) — match file type
   - **File**: upload the corresponding file
5. Save and publish.

> **Tip:** Upload CSS and JS before HTML so they exist when you reference them.

---

## Recommended Web Resource Naming Convention

Use `<publisher_prefix>_vafe_<descriptor>.<ext>`.

| File | Suggested Logical Name |
|------|------------------------|
| `vafe_report.html` | `new_vafe_report` |
| `vafe_report.css`  | `new_vafe_report_css` |
| `vafe_data_adapter.js` | `new_vafe_data_adapter` |
| `vafe_export.js`   | `new_vafe_export` |
| `vafe_report.js`   | `new_vafe_report_js` |
| `vafe_config.js`   | `new_vafe_config` |

Replace `new_` with your organisation's publisher prefix.

> **Important:** Web resource logical names are immutable after creation. Choose the prefix carefully.

---

## Adding the Web Resource to a Model-Driven App

### Option A — Dashboard

1. Open **make.powerapps.com** → **Dashboards** → **New** → **Classic dashboard**.
2. Add a **Web resource** component.
3. Select `new_vafe_report` (the HTML web resource).
4. Set width to 100% and height to at least 800px.
5. Save and publish the dashboard.

### Option B — Form Tab

1. Open the form editor for the target table.
2. Add a **Tab** → insert a **Section** → insert a **Web Resource** control.
3. Select `new_vafe_report`.
4. In properties, check **Pass record object-type code and unique identifier as parameters** if you want to pass entity context.
5. Save and publish the form.

### Option C — Custom Page (alternate hosting)

If you prefer Power Apps custom pages over classic web resources, recreate the HTML/CSS/JS as a canvas-based PCF or custom page. The data adapter patterns remain identical — only the hosting shell changes.

---

## Switching from Mock Provider to Dataverse Provider

### Method 1 — Config file (recommended for production)

Create `vafe_config.js` as a separate web resource with this content:

```javascript
var VAFE_CONFIG = {
  useMock: false,
  environmentUrl: ''  // leave empty to auto-detect from Xrm context
};
```

Upload it and add it to the HTML web resource dependencies **before** `vafe_data_adapter.js`.

### Method 2 — Runtime API

From browser console or another script:

```javascript
VAFE_APP.setProvider('dataverse');   // switch to Dataverse + re-fetch
VAFE_APP.setProvider('mock');        // revert to mock data
```

### Method 3 — HTML file edit

In `vafe_report.html`, the `<script src="vafe_config.js">` tag loads the config. If that file is absent, the adapter defaults to `useMock: true`. Creating the config file is the cleanest toggle.

---

## Adapter Functions — Table and Column Mapping

These are the **exact functions** in `vafe_data_adapter.js` where Dataverse logical names must be set. Each has `// TODO:` comments marking the mapping points.

| Function | Entity Set Name (TODO) | Key Columns to Map |
|----------|------------------------|-------------------|
| `DataverseProvider.getProjectSummary()` | `vafe_projects` | `vafe_projectid`, `vafe_name`, `vafe_currentphase`, `vafe_completionpct`, `vafe_status`, `vafe_startdate`, `vafe_targetdate` |
| `DataverseProvider.getPhases()` | `vafe_phases` | `vafe_phaseid`, `vafe_name`, `vafe_shortname`, `vafe_status`, `vafe_completionpct`, `vafe_owner`, `vafe_startdate`, `vafe_enddate`, `vafe_taskstotal`, `vafe_taskscomplete` |
| `DataverseProvider.getGates()` | `vafe_gates` | `vafe_gateid`, `vafe_name`, `vafe_phase`, `vafe_status`, `vafe_owner`, `vafe_duedate`, `vafe_notes` |
| `DataverseProvider.getBlockers()` | `vafe_blockers` | `vafe_blockerid`, `vafe_title`, `vafe_description`, `vafe_severity`, `vafe_status`, `vafe_phase`, `vafe_workstream`, `vafe_owner`, `vafe_raiseddate`, `vafe_targetresolution` |
| `DataverseProvider.getRisks()` | `vafe_risks` | `vafe_riskid`, `vafe_title`, `vafe_severity`, `vafe_probability`, `vafe_impact`, `vafe_mitigation`, `vafe_owner`, `vafe_status` |
| `DataverseProvider.getTeam()` | `vafe_teammembers` | `vafe_teammemberid`, `vafe_name`, `vafe_initials`, `vafe_role`, `vafe_workstream`, `vafe_openactions` |
| `DataverseProvider.getDecisions()` | `vafe_decisions` | `vafe_decisionid`, `vafe_decisioncode`, `vafe_title`, `vafe_rationale`, `vafe_impact`, `vafe_madeby`, `vafe_madedate`, `vafe_status`, `vafe_linkedphase` |
| `DataverseProvider.getActions()` | `vafe_actions` | `vafe_actionid`, `vafe_taskcode`, `vafe_title`, `vafe_owner`, `vafe_duedate`, `vafe_priority`, `vafe_status`, `vafe_phase`, `vafe_workstream` |

> **Steps to map a function:**
> 1. Open `vafe_data_adapter.js`.
> 2. Search for the function name (e.g., `getBlockers`).
> 3. Replace the first argument to `retrieveMultiple()` with your actual entity set name.
> 4. Update the `$select` column list to match your actual logical names.
> 5. Update the mapping object inside `.then(function(rows){...})` to read `r.your_actual_column`.

---

## Xrm Context Discovery

`vafe_data_adapter.js` resolves the Xrm client API in this order:

1. `window.parent.Xrm` — standard location when running in a Unified Interface iframe.
2. `window.Xrm` — fallback for standalone page or legacy hosting.
3. `null` — graceful failure; a warning banner is shown in the dashboard.

The `getClientUrl()` helper then derives the Dataverse environment URL from `Xrm.Utility.getGlobalContext().getClientUrl()`. Set `VAFE_CONFIG.environmentUrl` to override (useful for hardcoded test environments).

---

## CSP-Safe Implementation Decisions

The following choices were made explicitly to comply with Dynamics 365 Unified Interface Content Security Policy:

| Decision | Rationale |
|----------|-----------|
| No inline `<script>` blocks | D365 CSP blocks `script-src 'unsafe-inline'` |
| No inline `onclick`/`onchange` attributes | Same CSP restriction; all events bound via `addEventListener` in JS |
| No `eval()` or `new Function()` | Blocked by `script-src 'unsafe-eval'` restriction |
| No external CDN `<script>` or `<link>` tags | D365 CSP blocks origins outside the tenant; all files are uploaded as web resources |
| No `Blob` + `createObjectURL` for CSV export | Some strict CSP environments block blob URIs; data URIs used instead |
| IIFE module pattern (not ES modules) | `type="module"` script elements behave differently inside D365 iframes; IIFE avoids scoping issues |
| `credentials: 'same-origin'` on fetch | Required for Dataverse cookie-based authentication in same-origin iframe |
| No `window.top` navigation | Iframe-safe; all DOM manipulation stays within `window.document` |
| `aria-live="polite"` on content containers | Screen readers announced updates without aggressive interruption |

---

## Deployment Checklist

### Pre-upload
- [ ] Confirm publisher prefix with your D365 admin (replaces `new_` in logical names)
- [ ] Decide: mock mode (`useMock: true`) or live mode (`useMock: false`) before publishing
- [ ] If live mode: confirm Dataverse tables and columns exist and logical names match adapter TODOs

### Upload order
- [ ] 1. Upload `vafe_report.css` (logical name: `new_vafe_report_css`)
- [ ] 2. Upload `vafe_data_adapter.js` (logical name: `new_vafe_data_adapter`)
- [ ] 3. Upload `vafe_export.js` (logical name: `new_vafe_export`)
- [ ] 4. Upload `vafe_report.js` (logical name: `new_vafe_report_js`)
- [ ] 5. Upload `vafe_config.js` (logical name: `new_vafe_config`) — create this file first
- [ ] 6. Upload `vafe_report.html` last (logical name: `new_vafe_report`)

### Post-upload
- [ ] Update `href` in `vafe_report.html` `<link>` tag to match CSS web resource URL if relative path does not resolve
- [ ] Update `<script src>` paths in `vafe_report.html` to match web resource logical name paths
- [ ] Add web resource to target dashboard or form
- [ ] Test in D365 with mock mode first; verify all 8 sections render
- [ ] Toggle to Dataverse mode; verify Xrm context resolves (no warning banner)
- [ ] Run filter combinations (Phase, Owner, Severity, Workstream) and confirm UI updates
- [ ] Test Print (browser PDF) — verify all drawers expand and print layout renders
- [ ] Test Export CSV — verify download fires and columns are correct
- [ ] Test at 390px viewport width (mobile / narrow iframe)
- [ ] Confirm keyboard navigation: Tab through filter selects and drawer toggles; Enter/Space opens drawers

### Security
- [ ] Confirm no tokens, passwords, or connection strings appear in any uploaded file
- [ ] Confirm `vafe_config.js` contains only `useMock` boolean and optional `environmentUrl`
- [ ] Review Dataverse column select lists — ensure no sensitive fields are fetched unnecessarily

---

## Known Limitations

- **Pagination**: `retrieveMultiple` fetches up to the `$top` value specified. For tables with > 5,000 rows, implement `@odata.nextLink` following in `vafe_data_adapter.js`. The placeholder comment marks this location.
- **Authentication**: Web resources use the authenticated D365 session cookie automatically. No additional auth code is needed.
- **Offline / outside D365**: The dashboard runs fully in mock mode when opened as a local HTML file. Switch to Dataverse mode only when hosted inside D365.
- **Chart library**: No chart library is included (CSP constraint). KPI values, progress bars, and confidence gauge are CSS-only. Replace with a CSP-compliant, self-hosted library if richer visualisation is needed.
