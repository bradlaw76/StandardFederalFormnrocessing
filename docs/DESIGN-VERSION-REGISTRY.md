# Design Version Registry

**Project**: VA Form 10-3542 Extraction Pipeline  
**Purpose**: Track active and prior design documentation versions and provide a safe rollback path.

---

## Active Version

- **Version**: v2.0-design-lock
- **Status**: Active
- **Primary document**: `docs/FLOW-DESIGN-BASELINE-LOCK.md`
- **Starter guide**: `docs/V2-MODE2-STARTER.md`
- **Execution scripts**: `solution-src/VAFormExtractionDemo/Scripts/v2/`
- **Activation date**: 2026-05-18

All new design work must align to v2.0-design-lock unless explicitly superseded by a later version entry in this registry.

---

## Prior Version (Reference Only)

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
