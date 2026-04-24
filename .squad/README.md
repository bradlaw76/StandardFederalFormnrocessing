# Squad Setup: VA Form 10-3542 Extraction Pipeline

## Overview

This Squad is organized to execute the VA Form extraction pipeline in parallel phases, with clear handoffs and gates between team members.

**Team Size**: 8 roles (can be 1–8 people, or use @copilot for autonomous work)  
**Duration**: ~20–25 hours (can be condensed with full team in parallel)  
**Platform**: Microsoft Power Platform  
**Scope**: Demo (5 VA forms) → Production ready

---

## Getting Started

### 1. See Your Team & Routing

```bash
# View all team members and their assignments
squad status

# View how work gets routed to team members
cat .squad/routing.md

# View ceremonies (design reviews, retros)
cat .squad/ceremonies.md

# View detailed workflows & phase gates
cat .squad/workflows.md
```

### 2. Start Working

**If you have a GitHub repo with issues**:

```bash
# Start Ralph mode — auto-triages issues, assigns to team members, tracks progress
squad loop --filter "label:squad"

# Or triage manually:
squad triage
```

**For local/ad-hoc work**:

```bash
# Launch interactive squad shell
squad

# Inside shell, you can:
#   /assign phase1:arthur-shelby    → Route phase 1 setup tasks to Arthur Shelby
#   /start task T001                  → Mark task as in-progress
#   /done T001                        → Mark task complete
```

---

## Phase Structure

The project is broken into 7 phases, with clear ownership and parallelization:

### Phase 1: Setup (2–3 hours)
**Lead**: Arthur Shelby  
**Parallel**: Yes (all tasks independent)

Tasks: Environment setup, SharePoint, D365 connector, AI Builder capacity check

### Phase 2: Foundational (6–8 hours)
**Leads**: Polly Gray + John Shelby  
**Parallel**: Schema design ↔ AI model training (parallel), then shared flows

Tasks: Dataverse schema, AI Builder training, shared flows

### Phases 3–6: User Stories (12–15 hours)
**Leads**: John Shelby (intake, extraction, D365 write), Lizzie Stark (review UI)  
**Support**: Grace Burgess, Alfie Solomons  
**Parallel**: Flow development ↔ testing

Tasks: Each phase builds on previous; parallel flow dev + QA

### Phase 7: Polish (2–3 hours)
**Lead**: Tommy Shelby  
**Support**: Entire team  

Tasks: End-to-end testing, metrics, demo readiness

---

## Key Commands

### Check Status
```bash
squad status                    # Overall project status
squad status --phase 1          # Check Phase 1 progress
squad doctor                    # Health check (files, config, connections)
```

### Assign & Track Work
```bash
squad triage                    # Auto-triage GitHub issues
squad loop --interval 5         # Watch for new issues every 5 minutes
squad export                    # Export team state to JSON snapshot
```

### Team Coordination
```bash
squad consult                   # Enter consult mode (talk to your personal squad)
squad extract                   # Extract learnings from session
```

### Git Workflows
```bash
squad init-remote <repo-url>    # Link this project to central team repo
squad link <repo-url>           # Same as above
squad subsquads list            # If using workstreams/subsquads for scaling
```

---

## Workflow Example: Phase 1 Setup

### 1. Kick Off (Tommy Shelby)
```
Check Phase 1 setup in .squad/workflows.md
Create a GitHub issue or task list for Phase 1 tasks (T001–T008)
Label with `squad` for triage
```

### 2. Triage (Tommy Shelby or designated Lead)
```
squad triage
→ Reads all `squad` labeled issues
→ Assigns `squad:arthur-shelby` to environment setup tasks
→ Assigns `squad:polly-gray` to solution container task
→ Etc. for all parallel tasks
→ Leaves comment with triage notes
```

### 3. Parallel Execution
```bash
# Each team member picks up their assigned issues:
# Arthur Shelby runs:
#   - T001: Create Power Platform environment
#   - T002–T003: SharePoint site + library
#   - T005: Verify Power Automate quotas
#   - T008: Entra ID setup

# Alfie Solomons runs:
#   - T004: D365 connector setup

# Polly Gray runs:
#   - T006: Create solution container

# Michael Gray runs:
#   - T007: Verify AI Builder capacity

# All run in parallel (no dependencies)
```

### 4. Checkpoint (Tommy Shelby)
```bash
squad status
# Verifies all Phase 1 tasks complete
# Checks gate criteria:
#   - Power Platform environment accessible? ✓
#   - All connectors enabled? ✓
#   - Quotas confirmed? ✓

# If all gates pass → Approve Phase 2 start
# If blockers → Log as GitHub issue, reroute to team
```

---

## Parallel Work Streams

### When Work Happens in Parallel

**Example: Phase 2**

- **Stream A** (Polly Gray): Design Dataverse schema (T009–T016) — ~4 hours
- **Stream B** (Michael Gray): Collect data, train AI model (T017–T024) — ~6 hours
- **Stream C** (John Shelby): Wait for A & B, build shared flows (T025–T027) — ~2 hours

**Timeline**:
```
Hour 0–4:   Stream A & B run in parallel
Hour 4–6:   Stream B continues; Stream A complete; begins peer review
Hour 6–8:   Streams A & B complete; Stream C starts
Hour 8–10:  Stream C executes
Hour 10:    Phase 2 complete; Gate checklist verified
```

### How to Execute Parallel Streams

**Option 1: GitHub Issues with Labels**
```bash
# Create Phase 2 issues, label by stream:
# - squad:polly-gray, label:phase2-stream-a
# - squad:michael-gray, label:phase2-stream-b
# - squad:john-shelby, label:phase2-stream-c (blocked until a&b done)

squad loop --filter "label:phase2"
# Squad watches all phase2 issues, routes to team, tracks completion
# Squad blocks stream-c until stream-a & stream-b gates pass
```

**Option 2: Local Task Tracking**
```bash
# Edit .squad/workflows.md manually
# Update status for each task as team completes work
# Run squad consult to get AI assistant recommendations on blockers
```

---

## Error Handling & Escalation

### If a Task Blocks

1. **Log the blocker** as a GitHub issue (or update task in workflows.md)
2. **Label it** with `blocker:phase-X` to flag urgency
3. **Route to architect**: `squad:tommy-shelby` 
4. **Escalate if needed**: Comment on issue with @Tommy Shelby mention

### Design Review (Automatic at Phase Boundaries)

Before moving to next phase, a design review happens:
- **Facilitator**: Tommy Shelby
- **Participants**: Phase lead(s) + relevant domain experts
- **Checklist**: Review `.squad/ceremonies.md` for Design Review agenda
- **Duration**: 15–30 min focused review

### Retrospective (After Failures)

If a task fails (error, test failure, rejection):
- **Automatic retro** triggered per `.squad/ceremonies.md`
- **Facilitator**: Lead
- **Agenda**: What happened? → Root cause → Action items for next iteration

---

## Integration with GitHub Copilot

Squad can route async work to GitHub Copilot (@copilot) for autonomous execution:

### Enable Copilot Integration
```bash
squad copilot --on --auto-assign
# Enables auto-assignment of `squad:copilot` labeled issues to @copilot
```

### Good Fit Tasks for @copilot
- ✅ Add a field to Power Apps form (well-defined)
- ✅ Implement error logging in a flow (clear pattern)
- ✅ Write unit tests for a function (bounded scope)
- ❌ Design Dataverse schema (needs architect review)
- ❌ Configure D365 connector (sensitive, requires cert)

### Route a Task to Copilot
```bash
# In GitHub issue:
1. Add label `squad:copilot`
2. (If auto-assign on) → @copilot assigned automatically
3. @copilot picks up task, creates PR with implementation
4. Squad member reviews PR, merges if approved
```

---

## Demo Readiness Checklist

Use this before presenting to stakeholders:

```markdown
# Demo Checklist — VA Form Pipeline

## All Phases Complete?
- [ ] Phase 1: Environment & infrastructure ready
- [ ] Phase 2: Schema, AI model, shared flows working
- [ ] Phase 3: Intake flow tested with 5 test PDFs
- [ ] Phase 4: Extraction flow validated (confidence scores logged)
- [ ] Phase 5: D365 write successful; audit trail confirmed
- [ ] Phase 6: Power Apps review UI working (corrections logged)
- [ ] Phase 7: End-to-end test passed (1 form through full pipeline)

## Performance Targets Met?
- [ ] Extraction latency: <5 seconds per form
- [ ] D365 write latency: <2 seconds
- [ ] No unhandled errors in any flow
- [ ] Audit trail complete for all operations

## Demo Script Ready?
- [ ] Upload form → extraction → auto-approve → D365 write (happy path)
- [ ] Upload form → extraction → review required → correction → D365 write (review path)
- [ ] Show audit log (timestamp, user, action, field changes)
- [ ] Show confidence scores & accuracy baseline

## Known Limitations Documented?
- [ ] Demo scope: 5 forms (not production volume)
- [ ] Baseline accuracy: ~70% (with 5-form training dataset)
- [ ] Manual testing (not automated test suite)
- [ ] No scaling beyond 5 concurrent flows

## Sign-Off
- [ ] Tommy Shelby approval
- [ ] Team lead(s) approval
- [ ] Grace Burgess validation
```

---

## Squad Admin Commands

### Initialize Squad (Already Done)
```bash
squad init                      # Creates .squad/ folder structure
squad upgrade                   # Update to latest Squad version
squad doctor                    # Health check
```

### Export & Import Team State
```bash
squad export                    # Snapshot team state to JSON
squad import squad-export.json  # Restore from snapshot (for backup/share)
```

### Context Hygiene
```bash
squad nap                       # Clean up .squad/ state files
squad nap --deep               # Thorough cleanup + archive
squad scrub-emails             # Remove PII (emails) from state
```

### Advanced: Remote Team Repo
```bash
squad init-remote <team-repo-url>  # Link this project to shared team repo
squad upstream add <source>        # Add upstream Squad sources for sync
```

---

## Folder Structure

```
.squad/
├── config.json              # Squad config (version, teamRoot)
├── team.md                  # Team members & roles
├── routing.md               # How work gets routed to team
├── workflows.md             # Phase structure & gates (custom for this project)
├── ceremonies.md            # Design reviews, retros, etc.
├── decisions.md             # Team decisions log
├── identity/
│   ├── now.md              # Current squad snapshot
│   └── wisdom.md           # Lessons learned archive
├── agents/
│   └── scribe/
│       ├── charter.md      # Scribe agent role
│       └── history.md      # Session summaries
└── templates/              # Custom templates (if needed)

.github/
├── agents/
│   └── squad.agent.md      # Squad integration with GitHub Copilot
└── workflows/              # GitHub Actions for automated triage, assign, etc.
```

---

## Next Steps

1. **Review team.md** — Confirm all 8 roles match your team
2. **Review workflows.md** — Customize phase gates/timing for your team
3. **Set up GitHub issues** — Create issues for all Phase 1 tasks
4. **Run squad triage** — Auto-assign tasks to team members
5. **Kick off Phase 1** — Start environment setup
6. **Track progress** — Use `squad status` to monitor completion

---

## Contact

- **Questions about Squad?** → `squad --help` or https://github.com/bradygaster/squad-cli
- **Project-specific questions?** → See team.md for Tommy Shelby contact
- **Issues?** → Create GitHub issue with `squad` label; Squad will route to right person
