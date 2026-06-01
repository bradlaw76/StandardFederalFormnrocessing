# Feature Specification: Multi-Form PDF Splitter (Mode 2)

**Feature Branch**: `004-multi-form-pdf-splitter`  
**Created**: 2025-07-17  
**Status**: Draft  
**Input**: User description: "Mode 2: Multi-Form PDF Splitter — a new intake flow that detects multi-form PDFs (batches of VA Form 10-3542 scanned together), splits them into individual 2-page form PDFs, and feeds each into the existing extraction pipeline while tracking batch-level progress."

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Batch PDF Upload & Detection (Priority: P1)

VA staff scans a stack of completed VA Form 10-3542 forms into a single large PDF (e.g., 20 forms → one 40-page PDF) and uploads it to the system. The system detects that the PDF contains multiple forms and initiates the splitting process automatically.

**Why this priority**: Without reliable detection and splitting, no multi-form PDFs can enter the existing pipeline. This is the foundational capability that unlocks the entire Mode 2 flow.

**Independent Test**: Can be tested by uploading a multi-form PDF (e.g., 6 pages = 3 forms) → verifying the system identifies it as a batch → confirming it triggers the split process rather than the single-form pipeline.

**Acceptance Scenarios**:

1. **Given** a VA staff member uploads a PDF with 40 pages (20 forms), **When** the system inspects the page count, **Then** the system identifies it as a multi-form batch (page count > 2 and even) and initiates the splitting flow.
2. **Given** a VA staff member uploads a standard 2-page PDF (single form), **When** the system inspects the page count, **Then** the system routes it to the existing single-form pipeline (Mode 1) — no splitting occurs.
3. **Given** a VA staff member uploads a PDF with an odd page count (e.g., 41 pages), **When** the system inspects the page count, **Then** the system flags the PDF as a potential error (incomplete form), logs a warning, and routes it to a manual review queue for VA staff to inspect.
4. **Given** a VA staff member uploads a non-PDF file or a corrupted PDF, **When** intake validation runs, **Then** the file is rejected with a clear error message and logged.

---

### User Story 2 - PDF Splitting into Individual Forms (Priority: P1)

Once a multi-form PDF is detected, the system splits it into individual 2-page PDFs (one per VA Form 10-3542) and stores each split PDF individually for downstream processing.

**Why this priority**: The split PDFs are the input to the existing extraction pipeline. Without reliable splitting, no individual forms can be processed.

**Independent Test**: Can be tested by providing a 10-page PDF → verifying exactly 5 individual 2-page PDFs are created → confirming each split PDF is stored and accessible → verifying page content integrity (pages are not reordered, corrupted, or blank).

**Acceptance Scenarios**:

1. **Given** a 40-page batch PDF (20 forms), **When** the splitter runs, **Then** exactly 20 individual 2-page PDFs are created, each containing consecutive page pairs (pages 1–2, 3–4, 5–6, etc.).
2. **Given** the splitter produces individual PDFs, **When** each PDF is stored, **Then** each file is named with a reference to the parent batch and a sequential index (e.g., "BatchID-001.pdf", "BatchID-002.pdf").
3. **Given** the splitter encounters an error mid-split (e.g., storage failure on form 12 of 20), **When** the error occurs, **Then** all successfully split PDFs up to that point are preserved, the error is logged, and the batch is flagged for operator attention — already-split forms are not deleted.
4. **Given** the splitter completes, **When** all individual PDFs are stored, **Then** the original batch PDF is retained (not deleted) for audit trail purposes.

---

### User Story 3 - Feeding Split Forms to Existing Pipeline (Priority: P1)

Each individual 2-page PDF produced by the splitter is submitted to the existing extraction pipeline (the same flow used for single-form Mode 1 uploads). The existing pipeline processes each form independently without modification.

**Why this priority**: Reusing the existing pipeline without modification is a core design decision. This story validates that split PDFs are compatible with the downstream flows (extraction, correction, D365 write).

**Independent Test**: Can be tested by taking a split 2-page PDF → submitting it to the existing extraction pipeline → verifying it processes identically to a directly-uploaded single-form PDF → confirming extraction results, confidence routing, and D365 write all function correctly.

**Acceptance Scenarios**:

1. **Given** the splitter produces 20 individual PDFs, **When** each is submitted to the existing pipeline, **Then** each form enters the intake queue and processes through extraction, confidence routing, human correction (if needed), and D365 write — exactly as a single-form upload would.
2. **Given** the existing pipeline processes a split form, **When** extraction completes, **Then** the extraction result includes a reference to the parent batch (batch ID) so traceability is maintained.
3. **Given** 20 forms are submitted to the pipeline simultaneously, **When** the pipeline processes them, **Then** the system handles the concurrent load without failures or dropped forms (forms may process sequentially or in parallel depending on pipeline capacity).

---

### User Story 4 - Batch Tracking & Status Visibility (Priority: P2)

VA staff and supervisors can see the overall status of a batch — how many forms have been processed, how many are in review, and how many have failed. Each batch has a parent record linking to all its child form records.

**Why this priority**: Batch-level visibility is essential for VA staff to manage daily workloads and identify stalled batches, but the core split-and-process flow must work first.

**Independent Test**: Can be tested by processing a batch of 5 forms → querying batch status → verifying the status correctly reflects the state of each child form (e.g., "3 complete, 1 in review, 1 failed").

**Acceptance Scenarios**:

1. **Given** a batch of 20 forms is being processed, **When** VA staff checks the batch status, **Then** they see a summary: total forms, completed count, in-review count, failed count, and overall batch percentage complete.
2. **Given** all 20 forms in a batch reach "Complete" status, **When** the last form completes, **Then** the batch status automatically transitions to "Complete" and a completion timestamp is recorded.
3. **Given** 3 forms in a batch are in "Write Failed" status, **When** VA staff views the batch, **Then** the failed forms are individually identifiable (by index/name) so staff can investigate or retry each one.
4. **Given** a batch has been partially processed for more than 24 hours with no progress, **When** the system checks for stalled batches, **Then** an alert is generated for the VA supervisor.

---

### User Story 5 - Batch-Level Reporting & Audit (Priority: P3)

Supervisors can generate reports on batch processing history — how many batches processed per day, average forms per batch, batch completion times, and error rates — for operational planning and compliance.

**Why this priority**: Reporting builds on the tracking data from Story 4 and supports longer-term operational improvements. It is valuable but not required for the core split-and-process flow.

**Independent Test**: Can be tested by processing 3 batches of varying sizes → querying the reporting view → verifying aggregate metrics (batches/day, avg forms/batch, avg completion time) are accurate.

**Acceptance Scenarios**:

1. **Given** 10 batches have been processed over a week, **When** a supervisor views the batch report, **Then** they see: total batches, total forms across batches, average forms per batch, average batch completion time, and batch error rate.
2. **Given** a batch audit is requested, **When** a supervisor queries a specific batch by ID, **Then** they see the full lifecycle: upload timestamp, split completion time, individual form statuses, and final batch completion time.

---

### Edge Cases

- What happens when a PDF has exactly 2 pages? (It should route to the existing single-form pipeline, not the splitter.)
- What happens when a PDF has 0 pages or is an empty file? (Reject with clear error.)
- What if the batch PDF contains non-form pages (e.g., a cover sheet making page count odd)? (Flag for manual review due to odd page count.)
- What if storage is full when attempting to save split PDFs? (Log error, flag batch, preserve any already-split files.)
- What is the maximum batch size supported (max page count / max file size)? (Assumed: up to 500 forms = 1,000 pages per PDF.)
- What if two staff members upload the same batch PDF simultaneously? (Duplicate detection via file hash should reject the second upload.)
- What happens if the existing pipeline is temporarily unavailable when split forms are ready to be submitted? (Queue split forms and retry when pipeline is available.)

---

## Requirements *(mandatory)*

### Functional Requirements

**FR-001: Multi-Form Detection**
- System MUST inspect uploaded PDFs for page count to determine if they contain multiple forms
- A PDF with exactly 2 pages MUST be routed to the existing single-form pipeline (Mode 1)
- A PDF with more than 2 pages and an even page count MUST be identified as a multi-form batch and routed to the splitting flow (Mode 2)
- A PDF with an odd page count greater than 2 MUST be flagged as a potential error and routed to a manual review queue

**FR-002: PDF Splitting**
- System MUST split a multi-form PDF into individual 2-page PDFs by extracting consecutive page pairs (pages 1–2, 3–4, 5–6, etc.)
- Each split PDF MUST be a valid, self-contained PDF file
- Each split PDF MUST be stored individually with a unique identifier and a reference to the parent batch
- Split PDF naming MUST include the parent batch identifier and a sequential index
- The original batch PDF MUST be retained after splitting (not deleted)

**FR-003: Batch Record Creation**
- System MUST create a parent batch record when a multi-form PDF is detected
- The batch record MUST include: batch ID, source file name, source file hash, upload timestamp, uploading user, total form count (page count ÷ 2), and batch status
- Each split form MUST be linked to its parent batch record

**FR-004: Pipeline Submission**
- System MUST submit each split 2-page PDF to the existing extraction pipeline (the same intake mechanism used by Mode 1)
- Each submitted form MUST carry metadata linking it to its parent batch
- The existing pipeline flows (extraction, confidence routing, human correction, D365 write) MUST NOT be modified to accommodate Mode 2
- If the existing pipeline is temporarily unavailable, split forms MUST be queued and submitted when the pipeline becomes available

**FR-005: Batch Status Tracking**
- System MUST maintain real-time batch status by aggregating the statuses of all child forms
- Batch status MUST reflect: total forms, forms completed, forms in review, forms failed, and overall percentage complete
- When all child forms reach a terminal state (Complete or Write Failed), the batch MUST automatically transition to a terminal state
- A batch is "Complete" when all child forms are "Complete"; a batch is "Partially Failed" when some child forms are "Write Failed"

**FR-006: Stale Batch Alerting**
- System MUST detect batches with no status changes for more than 24 hours
- System MUST generate an alert to the VA supervisor for stale batches

**FR-007: Duplicate Batch Detection**
- System MUST compute a file hash for each uploaded batch PDF
- If a batch PDF with a matching hash has already been uploaded and is still in progress or completed, the system MUST reject the duplicate and notify the uploading user

**FR-008: Error Handling & Partial Failure**
- If splitting fails mid-process, all successfully split PDFs MUST be preserved
- The batch MUST be flagged with the error details and the index of the last successfully split form
- An operator MUST be able to retry splitting from the point of failure or re-upload the batch

### Key Entities

- **Batch**: Represents a single multi-form PDF upload. Contains batch ID, source file metadata, total form count, batch status, and lifecycle timestamps. A batch has many child FormSubmissions.
- **FormSubmission** (existing entity, extended): Represents an individual form. Extended with an optional parent batch reference (batch ID and form index within the batch). Forms without a parent batch are Mode 1 single-form uploads.
- **BatchStatusSummary**: A derived/computed view aggregating the statuses of all child forms within a batch. Not a persisted entity — computed on demand from child form statuses.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A 40-page batch PDF (20 forms) is detected, split, and all 20 individual forms are submitted to the pipeline within 2 minutes of upload.
- **SC-002**: Split PDFs produce identical extraction results to directly-uploaded single-form PDFs — zero accuracy degradation from the splitting process.
- **SC-003**: Batch status view accurately reflects the real-time state of all child forms — status updates visible within 30 seconds of a child form state change.
- **SC-004**: System supports batches of up to 500 forms (1,000 pages) without failure or timeout.
- **SC-005**: 100% of batch operations (upload, split, submission, completion) are logged for audit compliance.
- **SC-006**: Stale batch alerts fire within 1 hour of the 24-hour threshold being exceeded.
- **SC-007**: VA staff can identify and investigate failed forms within a batch in under 1 minute using the batch status view.
- **SC-008**: Duplicate batch PDFs are rejected before splitting begins — no wasted processing.

---

## Assumptions

1. **Fixed 2-Page Form Boundary**: VA Form 10-3542 is always exactly 2 pages when scanned. This assumption is based on the known form structure (1 header page + 1 data page). If the form template changes to a different page count, the splitting logic will need reconfiguration.
2. **Even Page Count = Valid Batch**: A multi-form PDF with an even page count is assumed to contain only VA Form 10-3542 forms with no extraneous pages (cover sheets, separator pages, etc.). Odd page counts are flagged for manual review.
3. **Existing Pipeline Unchanged**: The existing extraction pipeline (Mode 1 flows) is stable and will not be modified as part of this feature. Mode 2 is purely an additive intake flow that feeds into the existing pipeline.
4. **Storage Capacity**: Sufficient storage is available to hold both the original batch PDFs and all split individual PDFs simultaneously. For a 500-form batch, this means storing the original + 500 split files.
5. **Concurrency**: The existing pipeline can handle the concurrent submission of multiple forms from a single batch. If the pipeline has throttling limits, Mode 2 will submit forms sequentially or in controlled batches.
6. **Batch Size Limit**: Maximum batch size is 500 forms (1,000 pages). Batches exceeding this limit will be rejected with a clear error message.
7. **No Form Type Mixing**: A multi-form PDF contains only VA Form 10-3542 forms — no mixed form types within a single batch PDF.
8. **Audit Retention**: Batch records follow the same 7-year retention policy as individual form records (per existing pipeline spec).
9. **User Permissions**: The same VA staff who can upload single forms can also upload multi-form batches — no additional permissions required for Mode 2.
10. **Scan Quality**: Split PDFs retain the same image quality as the original batch PDF — no quality degradation from the splitting process.

---

**Version**: 1.0.0 | **Created**: 2025-07-17 | **Status**: Ready for Planning
