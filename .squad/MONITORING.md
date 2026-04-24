# Squad Phase Monitoring

Automated monitoring for Squad phase completion and activation.

---

## Option 1: Local PowerShell Monitor (Recommended)

Run the monitoring script locally on your machine. It continuously checks GitHub and alerts you when Phase 1 completes.

### Setup

```bash
cd StandardFederalFormnrocessing
```

### Run (Default: Check every 5 minutes)

```powershell
.\\.squad\monitor-phase1.ps1
```

### Run with Custom Interval (Check every 60 seconds)

```powershell
.\\.squad\monitor-phase1.ps1 -Interval 60
```

### Run with Email Alerts (Optional)

```powershell
.\\.squad\monitor-phase1.ps1 -Interval 300 -AlertEmail "you@example.com"
```

### What It Does

✅ Polls GitHub issues #3–#10 (Phase 1 tasks)  
✅ Shows live progress bar (X/8 closed)  
✅ Checks every 5 minutes (or custom interval)  
✅ When all 8 close: Automatically activates Phase 2  
✅ Updates `.squad/identity/now.md` with Phase 2 focus  
✅ Commits and pushes changes to GitHub  
✅ Exits cleanly

### Output

```
[2026-04-24 20:30:15] 🔍 Phase 1 Monitoring Started
[2026-04-24 20:30:15] Checking every 300 seconds
[2026-04-24 20:30:15] Watching issues: #3, #4, #5, #6, #7, #8, #9, #10

[2026-04-24 20:30:22] Check #1 | Phase 1: 0/8 closed, 8 open | Elapsed: 00:00:07
  Progress: [░░░░░░░░░░] 0%

[2026-04-24 20:35:42] Check #2 | Phase 1: 3/8 closed, 5 open | Elapsed: 00:05:27
  Progress: [███░░░░░░░] 37%

[2026-04-24 20:42:15] Check #3 | Phase 1: 8/8 closed, 0 open | Elapsed: 00:11:60
  Progress: [██████████] 100%

[2026-04-24 20:42:16] 📢 ALERT: Phase 1 Complete!
[2026-04-24 20:42:16] All 8 Phase 1 infrastructure issues are now CLOSED.
[2026-04-24 20:42:16] Activating Phase 2...
[2026-04-24 20:42:20] ✅ Phase 2 activated, changes committed and pushed

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ PHASE 1 COMPLETE
📋 PHASE 2 NOW ACTIVE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Phase 2 (#11-#18) is now live.
Polly, Michael, John: Check GitHub for your assigned Phase 2 issues.
```

---

## Option 2: GitHub Actions Automatic Monitor

Runs automatically on a schedule (every 10 minutes) + manual trigger.

### Setup (Automatic)

No setup needed! The workflow `.github/workflows/squad-phase-monitor.yml` is already configured.

### GitHub Actions Behavior

✅ Runs every 10 minutes (schedule)  
✅ Manually triggerable via GitHub Actions UI  
✅ Shows phase progress in job summary  
✅ Posts comment to issue #1 when phase completes  
✅ Updates focus (`.squad/identity/now.md`) automatically  
✅ Optional: Sends Slack notification (if webhook configured)

### Manual Trigger

Go to: [Actions → Squad Phase Monitor → Run workflow](https://github.com/bradlaw76/StandardFederalFormnrocessing/actions/workflows/squad-phase-monitor.yml)

Select phase to monitor and click "Run".

### View Results

After run completes, check:
- **Job Summary**: Phase progress (closed/open/total)
- **Issue #1 Comments**: Alert comment when complete
- **Git Commits**: `.squad/identity/now.md` auto-updated

---

## Option 3: Manual Check (No Monitoring)

Just run this whenever you want to check status:

```bash
gh issue list --state open --label "squad" --json number,state | grep "#[0-9]"
```

Or for Phase 1 specifically:

```bash
gh issue list --state open --label "squad" --json number | jq '.[] | select(.number >= 3 and .number <= 10)' | wc -l
```

When it shows 0 issues → Phase 1 is complete.

---

## Recommended Setup

1. **Start local monitor** in a terminal window:
   ```powershell
   .\\.squad\monitor-phase1.ps1 -Interval 60
   ```
   Leave running in the background.

2. **GitHub Actions** automatically runs every 10 minutes as backup.

3. **You get notified** when Phase 1 completes (via script output + GitHub comment).

---

## Troubleshooting

### "Unknown command: gh"
Install GitHub CLI: https://cli.github.com/

### "ERROR: GitHub CLI (gh) not found"
Make sure `gh` is in your PATH. Run `gh --version` to verify.

### Script stops abruptly
Check that you're authenticated: `gh auth status`

### Not seeing progress updates
Check interval setting. Default is 300 seconds (5 min). Use `-Interval 60` for 1-minute checks.

---

## Timeline

```
NOW: Start monitor
  ↓
2–3 hours: Phase 1 completes (all #3–#10 closed)
  ↓
Monitor automatically activates Phase 2
  ↓
GitHub comment posted to issue #1
  ↓
Phase 2 (#11–#18) becomes ACTIVE
  ↓
Team picks up Phase 2 work (Polly, Michael, John)
```

---

## What Happens on Completion

When Phase 1 completes, the monitor:

1. ✅ Detects all 8 Phase 1 issues closed
2. ✅ Updates `.squad/identity/now.md` → Phase 2 focus
3. ✅ Commits: `"chore: activate Phase 2 after Phase 1 checkpoint passed"`
4. ✅ Pushes to GitHub
5. ✅ Posts comment to issue #1 with Phase 2 activation notice
6. ✅ Exits cleanly

No manual action needed. Phase 2 is live and ready.

---

## Questions?

Check `.squad/PHASE-2-TASKS.md` for Phase 2 scope.  
Check Discussion #51 for Phase 2 briefing.  
Check `.squad/team.md` for team assignments.
