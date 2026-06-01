# Quickstart: Multi-Form PDF Splitter (Mode 2)

**Feature**: 004-multi-form-pdf-splitter  
**Date**: 2025-07-17  
**Prerequisites**: Existing pipeline (001-form-extraction-pipeline) must be deployed and working

---

## Prerequisites Checklist

- [ ] **001 Pipeline Deployed**: Flow 1 (Intake Trigger), Flow 2 (Extraction), and supporting subflows are operational
- [ ] **SharePoint Site**: `FormIntake` document library exists and is accessible
- [ ] **Dataverse Environment**: Existing tables (FormSubmission, ExtractionResult, etc.) are deployed
- [ ] **PDF Connector License**: Muhimbi PDF or Adobe PDF Services premium connector license available
- [ ] **Power Automate Premium**: Premium license for the user building Flow 01 (required for premium connectors)

---

## Environment Variables

> These values are required when configuring Flow-01 parameters in Power Automate.

| Parameter | Value |
|---|---|
| `AzureFunctionBaseUrl` | `https://va-pdf-splitter-dev.azurewebsites.net` |
| `AzureFunctionKey` | `<set-in-key-vault-or-app-settings>` |
| SharePoint Library | `FormIntake` (existing — no new folders required) |
| Azure Resource Group | `rg-va-forms-dev` |
| Function App Name | `va-pdf-splitter-dev` |

**Endpoints (both require `x-functions-key` header):**
- `POST /api/pdf/page-count` — body: `{ fileName, fileContent }` → returns `{ pageCount }`
- `POST /api/pdf/split` — body: `{ fileName, fileContent, startPage, endPage }` → returns `{ fileContent }`
---

## Setup Steps

> **ℹ️ Additive integration** — No SharePoint structural changes are required. The Azure Function plugs into the existing `FormIntake/` flow as-is.

### Step 1 (SKIPPED): ~~Create SharePoint Folder Structure~~

> **SKIPPED** — The Azure Function integrates additively. Existing `FormIntake/` library and Flow 1 trigger are unchanged.

### Step 2: Add Columns to FormSubmission Table (Dataverse)

In the Power Platform Maker portal → Dataverse → FormSubmission table:

1. Add column: `BatchID` (Lookup to BatchSubmission table) — **Not required**
2. Add column: `FormIndexInBatch` (Whole Number) — **Not required**
3. Save and publish the table

### Step 3: Create BatchSubmission Table (Dataverse)

In the Power Platform Maker portal → Dataverse → New table:

1. Table name: `BatchSubmission`
2. Display name: `Batch Submission`
3. Primary column: `BatchDisplayID` (Text, format: "BATCH-YYYYMMDD-NNN")
4. Add all columns as specified in `data-model.md` → Section 1

### Step 4: Configure PDF Connector

**Option A: Muhimbi PDF (Recommended)**
1. Go to Power Automate → Connections → New connection
2. Search for "Muhimbi PDF"
3. Authenticate with your Muhimbi account / API key
4. Test connection: Upload a sample PDF and verify `Get PDF Properties` returns page count

**Option B: Adobe PDF Services**
1. Go to Power Automate → Connections → New connection
2. Search for "Adobe PDF Services"
3. Authenticate with Adobe account credentials
4. Test connection: Upload a sample PDF and verify split operation

### Step 5: Build Flow 01 — Batch PDF Splitter

Create a new Power Automate cloud flow:

1. **Trigger**: SharePoint → When a file is created → Library: `FormIntake`, Folder: `Batches/Incoming`
2. **Step 1**: Get file properties → extract page count
3. **Step 2**: Validate (page count, file size, duplicate check — see `contracts/flow-01-batch-splitter.md`)
4. **Step 3**: Create BatchSubmission record in Dataverse
5. **Step 4**: Loop → Split PDF by page ranges → Save each split PDF to batch subfolder
6. **Step 5**: Loop → Move split PDFs to `FormIntake/` root (with 5-second delay between moves)
7. **Step 6**: Retain original PDF in batch subfolder
8. **Step 7**: Update BatchSubmission status to "SplittingComplete"

### Step 6: Build Flow 01B — Batch Status Updater

Create a new Power Automate cloud flow:

1. **Trigger**: Dataverse → When a row is modified → Table: `FormSubmission`, Filter: `BatchID ne null`
2. **Step 1**: Query all FormSubmission rows with same BatchID
3. **Step 2**: Count by status category
4. **Step 3**: Update BatchSubmission counters
5. **Step 4**: Check for terminal state → update BatchStatus if complete

### Step 7: Build Stale Batch Monitor (Scheduled)

Create a new scheduled Power Automate cloud flow:

1. **Schedule**: Every 1 hour
2. **Step 1**: Query BatchSubmission WHERE status is active AND LastProgressTimestamp < 24 hours ago
3. **Step 2**: For each stale batch → log alert + send notification

### Step 8: Update Flow 1 (Minor — Batch Field Population)

Add a conditional step at the end of existing Flow 1:

```
IF FileName starts with "BATCH-" THEN:
  Parse BatchDisplayID and FormIndex from filename
  Lookup BatchSubmission by BatchDisplayID
  Update FormSubmission: BatchID = {looked up}, FormIndexInBatch = {parsed index}
```

This is the **only change** to existing flows.

---

## Testing

### Test 1: Single-Form Bypass

1. Upload a 2-page PDF to `FormIntake/Batches/Incoming/`
2. Expected: Flow 01 detects 2 pages → moves file to `FormIntake/` root → Flow 1 processes normally
3. Verify: No BatchSubmission record created

### Test 2: Multi-Form Split (Small Batch)

1. Create a 6-page test PDF (3 forms concatenated)
2. Upload to `FormIntake/Batches/Incoming/`
3. Expected: 3 individual 2-page PDFs created in batch subfolder → moved to `FormIntake/` root
4. Verify: BatchSubmission record with TotalFormCount = 3
5. Verify: 3 FormSubmission records with BatchID set

### Test 3: Odd Page Count Rejection

1. Upload a 5-page PDF to `FormIntake/Batches/Incoming/`
2. Expected: Validation fails → BatchSubmission created with Status = "ValidationFailed"
3. Verify: Notification sent; file not split

### Test 4: Batch Status Tracking

1. Process a 6-page batch (3 forms)
2. As each form completes extraction → verify BatchSubmission counters update
3. When all 3 forms complete → verify BatchStatus = "Complete"

---

**Status**: ✅ Complete | **Date**: 2025-07-17

