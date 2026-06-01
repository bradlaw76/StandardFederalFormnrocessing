# V2 Mode-2 Starter Guide

This guide starts version 2 using solution artifacts, with rollback safety.

## Scope

- Active design version: `v2.0-design-lock`
- Prior design version: `v1.x-pre-lock`
- Source of truth for version status: `docs/DESIGN-VERSION-REGISTRY.md`

## Prerequisites

1. Power Platform CLI (`pac`) installed and authenticated.
2. Access to target environment and solution import permissions.
3. Existing unmanaged solution in environment: `VAFormExtractionDemo`.

## Working Folder

Use:
- `solution-src/VAFormExtractionDemo/Scripts/v2`

## Run Order

1. Prepare config
   - Copy `v2-config.example.psd1` to `v2-config.psd1`
   - Set `SolutionName` and optional `EnvironmentUrl`

2. Export v1 baseline artifacts
   - Run `01-export-v1-baseline.ps1`
   - Output:
   - `artifacts/v2/baseline/VAFormExtractionDemo_v1_baseline_managed.zip`
   - `artifacts/v2/baseline/VAFormExtractionDemo_v1_baseline_unmanaged.zip`

3. Prepare v2 candidate package
   - Place managed package at `artifacts/v2/candidate/VAFormExtractionDemo_v2_candidate_managed.zip`

4. Generate deployment settings template (recommended)
   - Run `02-create-v2-settings.ps1`
   - Fill the generated `deployment-settings.v2.json`
   - Update `SettingsFile` in `v2-config.psd1`

5. Import v2 candidate
   - Run `03-import-v2.ps1`
   - Run smoke tests after import

6. If needed, rollback to v1 baseline
   - Run `04-rollback-to-v1.ps1`

## Minimum Smoke Tests

1. Upload one valid file and verify FormSubmission created.
2. Verify extraction result row written and payload truncation behavior is intact.
3. Verify D365 write event is created.
4. Verify audit log row is created.

## Promotion Rule

Only mark v2 as active in `docs/DESIGN-VERSION-REGISTRY.md` after smoke tests pass.

## Rollback Rule

If smoke tests fail or a blocker appears:

1. Run rollback script.
2. Re-run smoke tests on baseline.
3. Update active status in `docs/DESIGN-VERSION-REGISTRY.md`.
