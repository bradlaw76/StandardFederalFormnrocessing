# MVP-06: Batch Folder Processor — Multi-PDF Setup Instructions

**Status:** Ready to Build  
**Target Completion:** 2–3 hours  
**Owner:** John Shelby (Flow Orchestration)  
**Last Updated:** 2026-05-18  

---

## Overview

Enable processing of **multiple PDFs in a single batch**. Current flows process one PDF per trigger. This enhancement adds a manual batch trigger that loops through FormIntake folder and processes all VA-10-3542-*.pdf files in parallel/sequence.

**Result:** Users upload 3–10 PDFs → trigger Flow 06 → system creates separate FormSubmission + ExtractionResult + Contact records for each.

---

## Architecture

```
FormIntake Folder (multiple PDFs)
        ↓
[Flow 06: Batch Folder Processor] - Manual trigger
        ↓
    List files in FormIntake
    Filter for VA-10-3542-*.pdf
        ↓
    Apply to each file (loop):
    ├→ Get file content
    ├→ Call Flow 01 (MVP-01) with FileId
    ├→ Delay 5 seconds (throttle)
    └→ Repeat for next file
        ↓
    Compose summary (X files processed)
```

---

## PART 1: Modify Flow 01 (MVP-01-SharePoint-To-D365-Intake)

### Step 1.1: Add Input Parameter

1. Open **Power Automate** → **My flows** → **MVP-01-SharePoint-To-D365-Intake**
2. Click **Edit** → scroll to trigger at top
3. Click trigger card: **"When a file is created or modified (properties only)"**
4. Expand trigger details
5. Click **+ Add an input** button (at bottom of trigger card)
   - **Input type:** Text
   - **Input name:** `OptionalFileId`
   - **Description:** "Optional file ID to process specific file"
   - **Required:** No (leave unchecked)
6. Click **Save**

### Step 1.2: Update File Name Field

1. Scroll down to **Step 1: Create_FormSubmission** action
2. Click the `vafe_file_name` field
3. Clear existing value: `@{triggerOutputs()?['body/{FilenameWithExtension}']}`
4. Replace with:
   ```
   @{if(empty(inputs('OptionalFileId')), triggerOutputs()?['body/{FilenameWithExtension}'], 'batch-process')}
   ```
5. Click **Save**

### Step 1.3: Update File URL Field

1. In same **Step 1: Create_FormSubmission** action
2. Click the `vafe_file_url` field
3. Clear existing value
4. Replace with:
   ```
   @{if(empty(inputs('OptionalFileId')), triggerOutputs()?['body/{Link}'], 'batch')}
   ```
5. Click **Save**

**Why:** When Flow 06 calls Flow 01 with OptionalFileId, we set fallback values to prevent null errors. Actual file data comes via the child flow context.

---

## PART 2: Create Flow 06 (MVP-06-Batch-Folder-Processor)

### Step 2.1: Create Manual Flow

1. In Power Automate, click **+ Create**
2. Choose **Cloud flow** → **Manual trigger**
3. Name the flow: `MVP-06-Batch-Folder-Processor`
4. Click **Create**

### Step 2.2: Add Action 1 — List Files

1. Click **+ New step**
2. Search for: `SharePoint`
3. Select: **List files in folder**
4. Configure:
   - **Site Address:** `https://d365demotsce80677168.sharepoint.com/sites/DepartmentofVeteranAffairs`
   - **Folder ID:** Click dropdown → select **FormIntake** library
5. Click **Save**

### Step 2.3: Add Action 2 — Filter for VA Forms

1. Click **+ New step**
2. Search for: `Data Operations`
3. Select: **Filter array**
4. Configure:
   - **From:** Click lightning icon → select `value` from **List files in folder**
   - Click **Edit in advanced mode**
   - Paste:
   ```
   @{filter(body('List_files_in_folder')?['value'], startsWith(item()?['Name'], 'VA-10-3542-'))}
   ```
   - Click **OK**
5. Rename action to: `Filter_VA_Forms`
6. Click **Save**

### Step 2.4: Add Action 3 — Count Files (Debug Info)

1. Click **+ New step**
2. Search for: `Compose`
3. In input box, paste:
   ```
   @{length(body('Filter_VA_Forms'))}
   ```
4. Rename to: `Count_Files_Found`
5. Click **Save**

### Step 2.5: Add Action 4 — Loop Through Files

1. Click **+ New step**
2. Search for: `Control`
3. Select: **Apply to each**
4. Configure:
   - **Select an output from previous steps:** Click lightning icon → select `Outputs` from **Filter_VA_Forms**
5. Rename to: `Process_Each_File`
6. Click **Save**

### Step 2.6: Inside Loop — Get File

1. Inside the **Apply to each** loop, click **Add an action**
2. Search for: `SharePoint`
3. Select: **Get file**
4. Configure:
   - **Site Address:** `https://d365demotsce80677168.sharepoint.com/sites/DepartmentofVeteranAffairs`
   - **Library name:** `FormIntake`
   - **ID:** Click lightning icon → select `ItemId`
5. Rename to: `Get_File_Details`
6. Click **Save**

### Step 2.7: Inside Loop — Get File Content

1. Click **Add an action**
2. Search for: `SharePoint`
3. Select: **Get file content**
4. Configure:
   - **Site Address:** Same as above
   - **Library name:** `FormIntake`
   - **ID:** Click lightning icon → select `ID` from **Get_File_Details**
5. Rename to: `Get_File_Content`
6. Click **Save**

### Step 2.8: Inside Loop — Call Flow 01

1. Click **Add an action**
2. Search for: `child flow` or `flow`
3. Select: **Run a child flow** (from Power Automate flows connector)
4. Configure:
   - **Flow:** Click dropdown → select `MVP-01-SharePoint-To-D365-Intake`
   - **OptionalFileId:** Click lightning icon → select `ID` from **Get_File_Details**
5. Rename to: `Process_File_with_Flow_01`
6. Click **Save**

### Step 2.9: Inside Loop — Add Delay

1. Click **Add an action**
2. Search for: `Control`
3. Select: **Delay**
4. Configure:
   - **Count:** `5`
   - **Unit:** `Second`
5. Click **Save**

**Why:** Prevents SharePoint throttling when processing many files quickly.

### Step 2.10: After Loop — Summary

1. Click **+ New step** (outside the loop, at same level as "Apply to each")
2. Search for: `Compose`
3. In input, paste:
   ```
   @{concat('Batch processing complete. ', length(body('Filter_VA_Forms')), ' files processed.')}
   ```
4. Rename to: `Batch_Complete_Summary`
5. Click **Save**

---

## PART 3: Testing Procedure

### Pre-Test: Clean FormIntake

1. Go to SharePoint → **Department of Veterans Affairs** site
2. Open **FormIntake** library
3. Delete all existing `VA-10-3542-*.pdf` files
4. Upload 3 test PDFs with exact names:
   - `VA-10-3542-TEST-101.pdf`
   - `VA-10-3542-TEST-102.pdf`
   - `VA-10-3542-TEST-103.pdf`

### Test Run

1. Go to Power Automate → **My flows**
2. Find **MVP-06-Batch-Folder-Processor**
3. Click the flow name to open
4. Click blue **Run** button (top right)
5. Click **Run** again in modal
6. **Wait 2–3 minutes** for completion (5 sec delay × 3 files, plus processing time)

### Validate in Dataverse

1. Open **Model-driven app** → **VA-Form-Extraction**

2. **Check Extraction Results:**
   - Navigate to **Extraction Results** table
   - Should see **3 new records** with:
     - Unique `vafe_extractionresultid` for each
     - vafe_extractionstatus: "Success" or "Pending"
     - vafe_modelversion: populated (e.g., "VAFE-VA10-3542-DocProc-v1")
     - Overall Confidence: decimal value (0.0–1.0)

3. **Check Form Submissions:**
   - Navigate to **Form Submissions** table
   - Should see **3 new records** with:
     - vafe_form_id: TEST-101, TEST-102, TEST-103
     - vafe_status: "Intake" or "Extracted"
     - vafe_file_name: matching uploaded PDF names

4. **Check Contacts:**
   - Navigate to **Contacts** table
   - Should see **3 new records** with extracted data:
     - firstname, lastname (from PDF extraction)
     - birthdate (if present in PDF)
     - address1_line1 (from travel address)
     - jobtitle (treating facility name)

### Success Criteria

✅ **All must be true:**
- Flow 06 run completes with no errors
- 3 FormSubmission records created in Dataverse
- 3 ExtractionResult records created in Dataverse
- 3 Contact records created in Dynamics 365
- Each Contact has extracted name, facility, and address populated
- Overall Confidence scores appear in ExtractionResult

### Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| Flow 06 fails at "List files" | SharePoint permissions | Verify user has Edit access to FormIntake library |
| Flow 06 succeeds but no records in Dataverse | Flow 01 error | Check Flow 01 run history for extraction/D365 write failures |
| 0 files detected | File naming | Ensure PDF names start exactly with `VA-10-3542-` |
| Flow 01 receives OptionalFileId but fails | Null handling | Check Create_FormSubmission action logic |
| Dataverse records appear but missing extracted data | AI extraction failure | Check Extraction Result vafe_errormessage field for AI Builder errors |

---

## PART 4: Integration Points

### After Batch Processing Succeeds

1. **Mark PDFs as Processed (Optional Enhancement)**
   - Add column to FormIntake: `ProcessedDate`
   - In Flow 06, set this after Flow 01 completes
   - Prevents reprocessing same file

2. **Notify on Completion (Optional)**
   - Add **Send an email** action after Batch_Complete_Summary
   - Recipient: `@{triggerBody()?['requestorEmail']}`
   - Subject: `Batch processing complete: X files processed`

3. **Add Error Notification (Recommended)**
   - Wrap "Process_File_with_Flow_01" in **Try-Catch**
   - If Flow 01 fails, log to audit trail instead of stopping batch

---

## PART 5: Flow JSON Export

Save Flow 06 definition to git:

1. In Power Automate, open **MVP-06-Batch-Folder-Processor**
2. Click **Export** (top right menu)
3. Choose **Cloud flows** → **Automated or manual trigger**
4. Download as `MVP-06-Batch-Folder-Processor.json`
5. Save to: `solution-src/VAFormExtractionDemo/Flows/MVP-06-Batch-Folder-Processor.json`

---

## Success Metrics

After this build, you can measure:

| Metric | Target | Validation |
|--------|--------|-----------|
| Single batch throughput | 3 PDFs in <3 min | Upload 3, run Flow 06, check Dataverse |
| Error rate | 0% (all files process) | Run twice, verify no failures |
| Data accuracy | 100% field match | Compare PDF → ExtractionResult fields manually |
| Extraction confidence | ≥90% average | Check vafe_overallconfidence values in Dataverse |

---

## Rollback Plan

If Flow 06 causes issues:

1. **Disable Flow 06** in Power Automate (toggle off)
2. Existing trigger (Flow 01 on SharePoint file upload) still works
3. Users must trigger manually instead of batch
4. No data loss; remove FormSubmission records manually if needed

---

## Next Steps (Post-MVP)

1. **Deduplication Logic** — Track processed file IDs, skip reruns
2. **Scheduled Batch** — Replace manual trigger with "Recurrence" (every 15 min)
3. **Parallel Processing** — Increase "Apply to each" degree of parallelism to 5–10
4. **Monitoring Dashboard** — Power Apps dashboard showing batch history + success rate
5. **Multi-Page PDF Splitting** — Detect page count, split into individual PDFs before processing

---

## Related Documentation

- [Flow Architecture Overview](FLOW-ARCHITECTURE.md)
- [MVP Power Automate Build Checklist](MVP-POWER-AUTOMATE-BUILD-CHECKLIST.md)
- [Flow Build Runbook](../03-phase-2-stream-b/FLOW-BUILD-RUNBOOK.md)

---

## Sign-Off

- [ ] John Shelby (Flow Orchestration) — Flow 06 design approved
- [ ] Grace Burgess (QA/Testing) — Test plan reviewed
- [ ] Tommy Shelby (Oversight) — Ready to build
