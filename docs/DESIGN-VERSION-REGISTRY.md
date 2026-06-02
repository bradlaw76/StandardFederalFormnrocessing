# Design Version Registry

**Project**: VA Form 10-3542 Extraction Pipeline  
**Purpose**: Track active and prior design documentation versions and provide a safe rollback path.

---

## Active Version

- **Version**: v2.1-expense-mapping
- **Status**: Active
- **Primary document**: `docs/FLOW-DESIGN-BASELINE-LOCK.md`
- **Starter guide**: `docs/V2-MODE2-STARTER.md`
- **Execution scripts**: `solution-src/VAFormExtractionDemo/Scripts/v2/`
- **Activation date**: 2026-06-02

Active version notes:
1. Expense amount persistence normalized to Dataverse `Extraction Result` currency fields for A/B/C/D + total.
2. Canonical live mapping points are `MVP-05-AI-Extraction-Subflow` (`Create ExtractionResult`) and optional downstream write in `MVP-02-D365-Write-Subflow`.
3. Total amount mapping includes null-safe fallback behavior for blank line items.

All new design work must align to v2.1-expense-mapping unless explicitly superseded by a later version entry in this registry.

---

## Prior Version (Reference Only)

- **Version**: v2.0-design-lock
- **Status**: Prior / reference only
- **Documents**:
  - `docs/FLOW-DESIGN-BASELINE-LOCK.md`

- **Version**: v1.x-pre-lock
- **Status**: Prior / reference only
- **Documents**:
  - `solution-src/VAFormExtractionDemo/Documents/FLOW-ARCHITECTURE.md`
  - `specs/03-phase-2-stream-b/FLOW-BUILD-RUNBOOK.md`
  - `solution-src/VAFormExtractionDemo/Flows/BUILD-SUMMARY-MAY-14-15.md`

These documents remain valid historical context and implementation evidence, but are not the source of truth for new design decisions.

---

## Rollback Rules

If rollback to prior design is required:

1. Declare rollback target version in writing (for example: v1.x-pre-lock).
2. Record reason and trigger evidence (runtime failure, failing test, or blocker) in issue/decision notes.
3. Mark v2.0-design-lock as suspended in this file.
4. Re-activate v1.x-pre-lock as active in this file.
5. Add a dated rollback note in `docs/FLOW-DESIGN-BASELINE-LOCK.md`.

No design should be treated as active unless this registry reflects that status.

---

## Future Versioning Convention

Use this format for design versions:

- `v<major>.<minor>-<tag>`

Examples:

- `v2.0-design-lock`
- `v2.1-retry-finalized`
- `v3.0-manual-review-ga`

Increment guidance:

1. **Major**: Breaking design change or architecture shift.
2. **Minor**: Additive design updates within same architecture.
3. **Tag**: Short descriptor of scope.
