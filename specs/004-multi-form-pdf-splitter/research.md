# Research: Multi-Form PDF Splitter (Mode 2)

**Feature**: 004-multi-form-pdf-splitter  
**Date**: 2025-07-17  
**Status**: Complete

---

## Research Task 1: PDF Splitting in Power Automate

**Question**: How can Power Automate split a multi-page PDF into individual 2-page PDFs?

### Decision: Use Muhimbi PDF or Adobe PDF Services connector for PDF splitting

### Rationale

Power Automate does **not** have a native "Split PDF" action. The following options were evaluated:

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **Muhimbi PDF Connector** (Premium) | Native Power Automate connector; `Split PDF` action supports page ranges; no custom code; well-documented | Premium connector (additional license cost); third-party dependency | ✅ **Primary recommendation** |
| **Adobe PDF Services** (Premium) | Enterprise-grade; `Split PDF` action; reliable for large files | Premium connector; Adobe account required; more complex setup | ✅ **Alternative** |
| **Azure Function (custom code)** | Full control; use PyPDF2/iTextSharp; no connector dependency | Requires Azure Function deployment; custom code violates "no-code" principle of existing pipeline; maintenance burden | ⚠️ Fallback only |
| **Power Automate Desktop** (RPA) | Can use desktop PDF tools; free with premium license | Requires attended/unattended desktop; not cloud-native; poor scalability | ❌ Rejected |
| **SharePoint PDF Preview API** | Free; no additional connector | Cannot split PDFs; read-only preview | ❌ Not applicable |

**Implementation approach with Muhimbi**:
1. Receive batch PDF from SharePoint trigger
2. Get page count via `Get PDF Properties` action
3. Loop: For i = 1 to pageCount step 2 → `Split PDF` action with page range `i to i+1`
4. Save each split PDF to SharePoint `FormIntake/Split/` subfolder
5. Each saved file triggers existing Flow 1 (Intake Trigger)

**Implementation approach with Adobe PDF Services**:
1. Similar flow; use `Split PDF` with page ranges
2. Adobe requires OAuth2 setup + API credentials stored in environment variables

### Alternatives Considered
- **Manual splitting before upload**: Rejected — defeats the purpose of automation
- **Convert to images then recombine**: Rejected — lossy; increases processing time; unnecessary complexity

---

## Research Task 2: Power Automate File Size Limits for Batch PDFs

**Question**: What are the file size limits for processing large batch PDFs (up to 500 forms = 1,000 pages)?

### Decision: Set batch PDF limit at 150MB; implement chunked processing for >50 form batches

### Rationale

| Limit | Value | Source |
|-------|-------|--------|
| Power Automate file content action | 100MB per action | Microsoft Docs |
| SharePoint file upload (API) | 250MB per file | SharePoint limits |
| Muhimbi PDF Connector | 40MB per request (default); configurable to 100MB | Muhimbi docs |
| Adobe PDF Services | 100MB per file | Adobe docs |
| Power Automate flow timeout | 30 days (cloud flow) | Microsoft Docs |
| Power Automate action timeout | 24 hours (default HTTP action) | Microsoft Docs |

**VA Form 10-3542 sizing**:
- Single 2-page form (scanned): ~200KB–500KB (image-based scan)
- 10 forms (20 pages): ~2–5MB
- 100 forms (200 pages): ~20–50MB
- 500 forms (1,000 pages): ~100–250MB

**Risk**: 500-form batches may exceed connector limits. Mitigation:
1. Set administrative limit at 250 forms (500 pages) per batch for Phase 1
2. Document the 150MB hard limit based on connector capabilities
3. For batches exceeding limit, prompt user to split into smaller uploads
4. Future: implement server-side chunking if needed

### Alternatives Considered
- **No limit**: Rejected — would cause silent failures for very large files
- **10-form limit**: Rejected — too restrictive for real-world VA batch scanning workflows

---

## Research Task 3: Concurrency & Throttling for Split Form Processing

**Question**: How will 20+ split forms trigger the existing pipeline simultaneously? Will throttling be an issue?

### Decision: Use controlled sequential deposit with configurable delay between split files

### Rationale

**Power Automate SharePoint trigger behavior**:
- SharePoint "When a file is created" trigger polls every 1–3 minutes (not real-time)
- Multiple files created within the same polling window are batched into a single trigger run
- Power Automate default concurrency: 50 parallel flow runs (configurable 1–50)
- Existing Flow 1 processes 1 form at a time (sequential by design)

**Strategy**:
1. Flow 01 splits the batch and saves individual PDFs to a `FormIntake/Batches/{BatchID}/` subfolder
2. After all splits are saved, Flow 01 moves files one-by-one to the `FormIntake/` root folder (where Flow 1 triggers)
3. Add a 5-second delay between moves to avoid overwhelming the pipeline
4. This ensures the existing Flow 1 trigger picks up forms in a controlled, sequential manner

**Why not trigger Flow 1 directly (child flow call)?**:
- The spec requires "existing flows are NOT modified"
- Flow 1 triggers on SharePoint file creation — so we feed it files via SharePoint
- This maintains complete decoupling between Mode 2 and Mode 1

### Alternatives Considered
- **Parallel submission (all at once)**: Rejected — risks exceeding AI Builder concurrency limits; may overload D365 write
- **Direct Dataverse insert (bypass Flow 1)**: Rejected — violates "no modification to existing flows" constraint
- **Queue-based (Service Bus)**: Rejected — adds infrastructure complexity; Power Automate + SharePoint is sufficient

---

## Research Task 4: Batch Tracking in Dataverse

**Question**: How should batch metadata be tracked alongside existing FormSubmission records?

### Decision: New `BatchSubmission` Dataverse table with 1:N relationship to FormSubmission

### Rationale

The existing `FormSubmission` table tracks individual forms. For Mode 2, we need:
1. A parent `BatchSubmission` record to track the batch lifecycle
2. A foreign key on `FormSubmission` pointing back to the batch (optional — null for Mode 1 single uploads)

**Schema approach**:
- Add `BatchID` (Lookup) column to existing `FormSubmission` table — nullable for Mode 1 forms
- Add `FormIndexInBatch` (Integer) column to `FormSubmission` — the sequential position (1, 2, 3…)
- Create new `BatchSubmission` table with batch-level metadata

**Batch status computation**:
- No separate "batch status" column needed — compute from child form statuses via rollup or Power Automate
- Use Dataverse calculated/rollup fields for real-time aggregation
- Alternatively, use a Power Automate flow triggered on FormSubmission status change to update batch counts

### Alternatives Considered
- **Separate linking table (BatchFormLink)**: Rejected — unnecessary; a simple lookup on FormSubmission is cleaner
- **JSON metadata field on FormSubmission**: Rejected — harder to query; Dataverse lookup relationships are the standard pattern
- **No batch tracking (just split and forget)**: Rejected — spec explicitly requires batch status visibility (Story 4)

---

## Research Task 5: Duplicate Batch Detection via File Hash

**Question**: How to compute and compare file hashes in Power Automate for duplicate detection?

### Decision: Use Power Automate expressions for SHA-256 hash computation

### Rationale

Power Automate does not have a native "compute file hash" action. Options:

| Option | Approach | Verdict |
|--------|----------|---------|
| **Azure Function** | Call a lightweight function that computes SHA-256 | ✅ Best accuracy; small custom code footprint |
| **Power Automate expression** | Use `@{hashBytes('SHA256', triggerBody()?['$content'])}` (available in some contexts) | ⚠️ Limited availability; not available for all file actions |
| **Muhimbi / connector** | Some PDF connectors expose document properties including hash | ⚠️ Connector-dependent |
| **Skip hash, use filename + size + date** | Compare filename, file size, and upload date as a proxy for deduplication | ✅ Simple fallback; less reliable but sufficient for demo |

**Recommendation for Phase 1 (Demo)**:
- Use filename + file size + page count as deduplication proxy
- Store these values on BatchSubmission record
- Query existing BatchSubmission records before processing

**Recommendation for Phase 2 (Production)**:
- Deploy lightweight Azure Function for SHA-256 computation
- Store hash on BatchSubmission.FileHash column
- Reject exact duplicates; warn on filename-only matches

### Alternatives Considered
- **No duplicate detection**: Rejected — spec FR-007 requires it
- **Client-side hashing (browser)**: Not applicable — files uploaded via SharePoint, not a custom UI

---

## Research Task 6: SharePoint Folder Structure for Batch Processing

**Question**: How should split PDFs be organized in SharePoint to avoid naming conflicts and enable traceability?

### Decision: Use `FormIntake/Batches/{BatchID}/` for intermediate storage, then move to `FormIntake/` for pipeline trigger

### Rationale

**Folder structure**:
```
FormIntake/                          ← Existing folder; Flow 1 triggers here
├── vafe_SingleForm001.pdf           ← Mode 1 single uploads (existing)
├── Batches/                         ← NEW: Batch processing folder
│   ├── BATCH-20250717-001/          ← Batch subfolder (per batch)
│   │   ├── _original.pdf            ← Original batch PDF (retained for audit)
│   │   ├── BATCH-20250717-001-001.pdf  ← Split form 1 (intermediate)
│   │   ├── BATCH-20250717-001-002.pdf  ← Split form 2 (intermediate)
│   │   └── ...
│   └── BATCH-20250717-002/
│       └── ...
└── Processed/                       ← Existing: processed files moved here
```

**Naming convention for split PDFs**:
- Pattern: `{BatchID}-{FormIndex:000}.pdf`
- Example: `BATCH-20250717-001-003.pdf` = Batch 1, Form 3
- The `vafe_` prefix is NOT used for batch-split files (reserved for Mode 1 single uploads)
- When moved to `FormIntake/` root for pipeline trigger, the filename is preserved

**Why separate Batches/ folder?**:
- Prevents Flow 1 from triggering on intermediate files during splitting
- Allows Flow 01 to control when files enter the pipeline (move to root when ready)
- Original batch PDF is preserved in the batch subfolder for audit

### Alternatives Considered
- **Flat structure (all in FormIntake/)**: Rejected — would trigger Flow 1 prematurely during splitting
- **Separate SharePoint library**: Rejected — adds complexity; same library with subfolder isolation is simpler
- **Azure Blob Storage for intermediates**: Rejected — adds infrastructure; SharePoint is sufficient

---

**Status**: ✅ All research tasks complete | **Date**: 2025-07-17
