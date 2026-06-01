# VA Form Extraction Flow Kit

This folder contains a build-ready flow blueprint for the VA Form 10-3542 pipeline.

## Program Context (BTS SS)

This project is for VA Beneficiary Travel Self-Service (BTS SS).

- Supports upload and filing of manual claims
- Supports recording Letters of Attendance for Community Care appointments
- Uses Power Automate + Dataverse to maintain an auditable claim-processing trail

## What was created

- `01-VAFE-Flow-SharePointIntake.json`
- `02-VAFE-Flow-AIExtraction.json`
- `03-VAFE-Flow-DecisionRouting.json`
- `04-VAFE-Flow-D365Write.json`
- `05-VAFE-Flow-ErrorHandling.json`
- `power-automate-expressions.txt`

## Correct Build Order

Build in this order to satisfy child-flow dependencies:

1. `05-VAFE-Flow-ErrorHandling`
2. `04-VAFE-Flow-D365Write`
3. `03-VAFE-Flow-DecisionRouting`
4. `02-VAFE-Flow-AIExtraction`
5. `01-VAFE-Flow-SharePointIntake`

## Notes

- These files are implementation blueprints for manual creation in Power Automate.
- Use the naming exactly as defined to keep child-flow references valid.
- Environment-specific values are already aligned to this project docs:
  - SharePoint site: `https://d365demotsce80677168.sharepoint.com/sites/DepartmentofVeteranAffairs`
  - Library: `FormIntake`
  - Model: `VAFE-VA10-3542-DocProc-v1`

## Smoke Test

1. Upload `VA-10-3542-TEST-001.pdf` and verify the happy path reaches `Written`.
2. Confirm `vafe_formsubmission`, `vafe_extractionresult`, `vafe_d365writeevent`, and `vafe_auditlog` each receive a new row.
3. Build and validate `MVP-04-D365-Retry` after the happy path is confirmed.

## Simple Start (MVP)

If you want the smallest possible starting point (SharePoint integration + write to Dynamics 365), use these files first:

- `MVP-01-SharePoint-To-D365-Intake.json`
- `MVP-02-D365-Write-Subflow.json`
- `MVP-03-Audit-Logger-Subflow.json`
- `MVP-04-D365-Retry.json`

### MVP Build Order

1. `MVP-03-Audit-Logger-Subflow`
2. `MVP-02-D365-Write-Subflow`
3. `MVP-04-D365-Retry`
4. `MVP-01-SharePoint-To-D365-Intake`

### MVP Scope

- Includes: SharePoint trigger, FormSubmission create/update, D365 write, audit logs.
- Excludes for now: retry handling, confidence routing, manual correction queue.

### MVP UI Build Guide

- Use `MVP-POWER-AUTOMATE-BUILD-CHECKLIST.md` for the verified click-by-click Power Automate setup.
