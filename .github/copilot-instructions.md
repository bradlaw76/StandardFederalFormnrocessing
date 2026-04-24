<!-- SPECKIT START -->
**Active Feature**: VA Form 10-3542 Extraction Pipeline (`001-form-extraction-pipeline`)

**Documentation**:
- **Specification**: [specs/001-form-extraction-pipeline/spec.md](../specs/001-form-extraction-pipeline/spec.md) (v1.0.1-Ready)
- **Implementation Plan**: [specs/001-form-extraction-pipeline/plan.md](../specs/001-form-extraction-pipeline/plan.md) (v1.0.1-PowerPlatform)
- **Research**: [specs/001-form-extraction-pipeline/research.md](../specs/001-form-extraction-pipeline/research.md) (Power Platform setup, AI Builder demo, Dataverse schema)
- **Constitution**: [.specify/memory/constitution.md](.specify/memory/constitution.md) (5 core principles: Test-First, Code Quality, UX Consistency, Performance, Observability)

**Tech Stack** (Power Platform Demo):
- **Platform**: Microsoft Power Platform (low-code/no-code)
- **AI Extraction**: AI Builder (custom document model trained on 5 VA forms)
- **Orchestration**: Power Automate cloud flows (intake, extraction routing, D365 write, error handling)
- **Storage (Metadata)**: Dataverse tables (FormSubmission, ExtractionResult, CorrectionRecord, AuditLog)
- **Storage (PDFs)**: SharePoint or Dataverse blob column
- **UI (Correction)**: Power Apps canvas app (optional, for manual field correction)
- **Analytics**: Power BI (extraction metrics dashboard)
- **D365 Integration**: D365 connector in Power Automate + Dynamics 365 VA_FormSubmission table
- **Authentication**: Power Platform built-in OAuth2, Entra ID staff login
- **Audit Logging**: Dataverse audit table (basic, not immutable ledger)

**Development Approach**:
- Test-First (80% coverage minimum)
- SOLID principles; cyclomatic complexity < 5
- Code review gates (pair review for non-trivial changes)
- Performance targets: <5s extraction, <2s D365 write, ≥100 forms/hour

**Next Steps**:
1. Run `/speckit.tasks` to generate dependency-ordered task list for Power Platform setup
2. Phase 0 research complete (research.md regenerated for Power Platform)
3. Phase 1 design in progress (plan.md regenerated; data model + contracts + quickstart ready for implementation)
4. Route tasks to Squad agents for parallel execution (estimated 2–3 days for 1 person)
<!-- SPECKIT END -->

# Copilot Instructions

## SpeckKit Integration

This project is governed by the SpeckKit registry.

Registry:
https://github.com/bradlaw76/SpeckKit-Project-Development

Agent Defaults:
https://raw.githubusercontent.com/bradlaw76/SpeckKit-Project-Development/main/AGENT_BEHAVIOR_DEFAULTS.jsonc

---

## Code Standards (Auto-Apply - DEFAULT YES)

When creating or modifying component files, always apply the component header comment block.
Do not skip unless the user explicitly says to omit comments.

Template:
https://raw.githubusercontent.com/bradlaw76/SpeckKit-Project-Development/main/code-standards/comments/component-header-block.md

Catalog:
https://raw.githubusercontent.com/bradlaw76/SpeckKit-Project-Development/main/code-standards/CODE_STANDARDS_CATALOG.json.md

Rules:
1. Apply the component header comment block to every new component file.
2. Update changelog, last updated, and version when modifying existing components.
3. Fill in all bracketed values based on project context.
4. Only skip if user explicitly says "no comments" or "skip header."

---

## UI References (Ask First - DEFAULT ASK)

UI references are available for platform-specific context. Confirm with the user before loading.

Catalog:
https://raw.githubusercontent.com/bradlaw76/SpeckKit-Project-Development/main/ui-references/UI_REFERENCE_CATALOG.json.md

Rules:
1. Ask: "Should I load UI reference context for the target platform?"
2. Only load if user confirms or the task clearly involves that platform UI.
3. Use reusablePatterns for component conventions.
4. Use visualIndicators for color and badge mappings.

---

## Agent Behavior Summary

Code standards (comment headers): YES, apply automatically.
UI references (platform layouts): ASK, confirm with user.
