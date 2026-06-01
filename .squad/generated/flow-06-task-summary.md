# Task Summary: Flow 06 Multi-PDF Batch Processor

**Issue**: #34  
**Owner**: John Shelby (Flow Orchestration)  
**Date Created**: 2026-05-18  
**Status**: Ready to Build  
**Estimated Effort**: 2–3 hours (build + test)  

---

## Objective

Enable processing of multiple PDFs in a single batch trigger. Users upload 3–10 PDFs to FormIntake folder, trigger Flow 06 manually, and system creates separate FormSubmission + ExtractionResult + Contact records for each PDF.

## Deliverables

1. ✅ **MVP-06-Batch-Folder-Processor.json** — New manual flow, 10 actions
2. ✅ **MVP-01 Modification** — Add `OptionalFileId` input parameter
3. ✅ **MVP-06-BATCH-PROCESSOR-SETUP.md** — Full step-by-step instructions
4. ✅ **Updated Documentation**:
   - FLOW-ARCHITECTURE.md (added Flow 6 section)
   - MVP-POWER-AUTOMATE-BUILD-CHECKLIST.md (added build order)
   - .squad/decisions.md (decision D-007)

## Changes Summary

### Modified Files
- `solution-src/VAFormExtractionDemo/Documents/FLOW-ARCHITECTURE.md` — Updated overview diagram + added Flow 6 section
- `solution-src/VAFormExtractionDemo/Flows/MVP-POWER-AUTOMATE-BUILD-CHECKLIST.md` — Updated build order
- `.squad/decisions.md` — Added decision D-007 for batch processing architecture

### New Files
- `solution-src/VAFormExtractionDemo/Flows/MVP-06-BATCH-PROCESSOR-SETUP.md` — Complete setup guide
- `.squad/generated/flow-06-task-summary.md` — This file

## Build Steps (From Setup Guide)

### Part 1: Modify Flow 01 (15 min)
- Add `OptionalFileId` text input parameter
- Update `vafe_file_name` field with conditional logic
- Update `vafe_file_url` field with conditional logic

### Part 2: Create Flow 06 (60 min)
- Manual trigger
- List files in FormIntake
- Filter for VA-10-3542-*.pdf
- Loop through each file
- Call Flow 01 per file
- Add 5-second delay between calls
- Compose summary

### Part 3: Test (45 min)
- Clean FormIntake folder
- Upload 3 test PDFs
- Run Flow 06
- Validate Dataverse records
- Check Contact, ExtractionResult, FormSubmission tables

## Success Criteria

✅ **Build:**
- Flow 06 exists in Power Automate
- Flow 01 accepts OptionalFileId parameter
- Flow 06 shows no errors on save

✅ **Test:**
- Upload 3 test PDFs → run Flow 06
- 3 FormSubmission records created (one per file)
- 3 ExtractionResult records created (one per file)
- 3 Contact records created (one per file)
- Each Contact has extracted name, facility, address populated
- Flow 06 completes without errors

## Blocking Dependencies

- ✅ Flow 01 (MVP-01) must exist and be working
- ✅ Dataverse tables (FormSubmission, ExtractionResult, Contact) must exist
- ✅ D365 write flow must be working
- (None blocking — all are ready)

## Next Steps (Post-Build)

1. **Phase 2 Enhancement**: Add file deduplication (track processed file IDs)
2. **Phase 3**: Convert to scheduled flow (every 15 min) with parallel execution
3. **Phase 3**: Add error notification + dead-letter queue for failed files
4. **Future**: Add UI dashboard showing batch history + success rate

## Rollback

If Flow 06 causes issues:
1. Disable Flow 06 toggle in Power Automate
2. Existing Flow 01 trigger (single-file) still works
3. Users fall back to manual single-file processing

## Resources

- Full Setup: `solution-src/VAFormExtractionDemo/Flows/MVP-06-BATCH-PROCESSOR-SETUP.md`
- Flow Architecture: `solution-src/VAFormExtractionDemo/Documents/FLOW-ARCHITECTURE.md`
- Build Checklist: `solution-src/VAFormExtractionDemo/Flows/MVP-POWER-AUTOMATE-BUILD-CHECKLIST.md`
- Squad Decisions: `.squad/decisions.md` (D-007)

---

**Ready to build? Start with Part 1 in MVP-06-BATCH-PROCESSOR-SETUP.md**
