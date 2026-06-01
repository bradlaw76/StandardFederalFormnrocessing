# V2 Mode-2 Scripts (Solution Artifact Workflow)

This folder contains the runnable scripts to start and operate v2 using the solution export/import model.

## Files

1. `v2-config.example.psd1` - configuration template
2. `01-export-v1-baseline.ps1` - export managed and unmanaged v1 baseline
3. `02-create-v2-settings.ps1` - generate deployment settings template for v2 package
4. `03-import-v2.ps1` - import v2 managed package
5. `04-rollback-to-v1.ps1` - rollback import to baseline package

## Quick Start

1. Copy `v2-config.example.psd1` to `v2-config.psd1`
2. Fill values in `v2-config.psd1`
3. Run scripts in order:
   - `./01-export-v1-baseline.ps1`
   - Place v2 managed package at `artifacts/v2/candidate/<CandidateManagedZip>`
   - `./02-create-v2-settings.ps1` (optional but recommended)
   - `./03-import-v2.ps1`
4. If needed: `./04-rollback-to-v1.ps1`

## Notes

- Scripts use active PAC auth profile unless `EnvironmentUrl` is set.
- Rollback is package-based and should be followed by smoke testing.
