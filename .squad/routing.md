# Work Routing

How to decide who handles what.

## Routing Table

| Work Type | Route To | Label | Examples |
|-----------|----------|-------|----------|
| **Environment & Infrastructure** | Arthur Shelby | `squad:arthur-shelby` | Power Platform env setup (T001), SharePoint site/library (T002–T003), D365 connector (T004), AI Builder capacity (T007), Entra ID setup (T008) |
| **Dataverse Schema Design** | Polly Gray | `squad:polly-gray` | Create FormSubmission, ExtractionResult, CorrectionRecord, AuditLog, D365WriteEvent tables (T009–T016) |
| **Power Automate Flows** | John Shelby | `squad:john-shelby` | Intake trigger (T030–T037), AI extraction flow (T038–T046), D365 write flow (T047–T057), shared actions (T025–T027), error handling/retry |
| **Power Apps UI** | Lizzie Stark | `squad:lizzie-stark` | Correction form UI (T058–T066), field validation, error messages, form submission logic |
| **AI Builder Model** | Michael Gray | `squad:michael-gray` | Collect/prepare training data (T017), create & annotate model (T018–T024), test baseline accuracy, publish model, version tracking |
| **Dynamics 365 Integration** | Alfie Solomons | `squad:alfie-solomons` | Configure D365 connector (T047), field mapping (T048), test write operations, connection troubleshooting |
| **Quality Assurance & Testing** | Grace Burgess | `squad:grace-burgess` | End-to-end flow testing, 5-form accuracy validation, error scenario testing, audit trail verification, performance metrics logging |
| **Architecture & Oversight** | Tommy Shelby | `squad:tommy-shelby` | Phase gate reviews, SOLID principle enforcement, performance target validation (5s extraction, <2s D365 write), design decisions |
| **Code review** | Tommy Shelby | Review Power Automate flow design, Power Apps validation logic, Dataverse schema relationships, error handling patterns |
| **Testing** | Grace Burgess | Write test cases for each phase, manual acceptance testing, accuracy baseline metrics, compliance audit trail validation |
| **Scope & priorities** | Tommy Shelby | Phase gate decisions, feature prioritization, trade-offs (complexity vs. demo scope), architectural decisions |
| **Async issue work (bugs, tests, small features)** | @copilot 🤖 | Well-defined tasks matching capability profile (e.g., add field to form, update flow logic, minor bug fixes) |
| **Session logging** | Scribe | Automatic — never needs routing |

## Issue Routing

| Label | Action | Who |
|-------|--------|-----|
| `squad` | Triage: analyze issue, evaluate @copilot fit, assign `squad:{member-name}` label | Lead |
| `squad:arthur-shelby` | Pick up infrastructure/environment work | Arthur Shelby ⚙️ |
| `squad:polly-gray` | Pick up Dataverse schema design work | Polly Gray 📊 |
| `squad:john-shelby` | Pick up Power Automate flow work | John Shelby 🔹 |
| `squad:lizzie-stark` | Pick up Power Apps UI work | Lizzie Stark ⚛️ |
| `squad:michael-gray` | Pick up AI Builder model work | Michael Gray 🔹 |
| `squad:alfie-solomons` | Pick up D365 integration work | Alfie Solomons 🔹 |
| `squad:grace-burgess` | Pick up QA/testing work | Grace Burgess 🧪 |
| `squad:tommy-shelby` | Pick up architecture/oversight work | Tommy Shelby 🎨 |
| `squad:copilot` | Assign to @copilot for autonomous work (if enabled) | @copilot 🤖 |

### How Issue Assignment Works

1. When a GitHub issue gets the `squad` label, the **Lead** (Tommy Shelby) triages it — analyzing content, evaluating @copilot's capability profile, assigning the right `squad:{member-name}` label, and commenting with triage notes.
2. **@copilot evaluation:** The Lead checks if the issue matches @copilot's capability profile (🟢 good fit / 🟡 needs review / 🔴 not suitable). If it's a good fit, the Lead may route to `squad:copilot` instead of a squad member.
3. When a `squad:{member-name}` label is applied (e.g., `squad:arthur-shelby`), that member picks up the issue in their next session.
4. When `squad:copilot` is applied and auto-assign is enabled, `@copilot` is assigned on the issue and picks it up autonomously.
5. Members can reassign by removing their label and adding another member's label.
6. The `squad` label is the "inbox" — untriaged issues waiting for Lead review.

### Lead Triage Guidance for @copilot

When triaging, the Lead should ask:

1. **Is this well-defined?** Clear title, reproduction steps or acceptance criteria, bounded scope → likely 🟢
2. **Does it follow existing patterns?** Adding a test, fixing a known bug, updating a dependency → likely 🟢
3. **Does it need design judgment?** Architecture, API design, UX decisions → likely 🔴
4. **Is it security-sensitive?** Auth, encryption, access control → always 🔴
5. **Is it medium complexity with specs?** Feature with clear requirements, refactoring with tests → likely 🟡

## Rules

1. **Eager by default** — spawn all agents who could usefully start work, including anticipatory downstream work.
2. **Scribe always runs** after substantial work, always as `mode: "background"`. Never blocks.
3. **Quick facts → coordinator answers directly.** Don't spawn an agent for "what port does the server run on?"
4. **When two agents could handle it**, pick the one whose domain is the primary concern.
5. **"Team, ..." → fan-out.** Spawn all relevant agents in parallel as `mode: "background"`.
6. **Anticipate downstream work.** If a feature is being built, spawn the tester to write test cases from requirements simultaneously.
7. **Issue-labeled work** — when a `squad:{member}` label is applied to an issue, route to that member. The Lead handles all `squad` (base label) triage.
8. **@copilot routing** — when evaluating issues, check @copilot's capability profile in `team.md`. Route 🟢 good-fit tasks to `squad:copilot`. Flag 🟡 needs-review tasks for PR review. Keep 🔴 not-suitable tasks with squad members.
