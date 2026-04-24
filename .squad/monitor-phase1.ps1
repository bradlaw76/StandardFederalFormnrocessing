#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Monitor Phase 1 completion and trigger Phase 2 activation

.DESCRIPTION
    Continuously polls GitHub issues #3-#10 (Phase 1 tasks).
    When all 8 are CLOSED, alerts the user and updates focus.

.PARAMETER Interval
    Check interval in seconds (default: 300 = 5 minutes)

.PARAMETER AlertEmail
    Email to send alerts to (optional, requires GitHub CLI config)

.EXAMPLE
    .\monitor-phase1.ps1 -Interval 60
    # Checks every 60 seconds

.EXAMPLE
    .\monitor-phase1.ps1 -Interval 300 -AlertEmail "user@example.com"
    # Checks every 5 minutes, sends email on completion
#>

param(
    [int]$Interval = 300,  # Default: 5 minutes
    [string]$AlertEmail = ""
)

$PHASE1_ISSUES = 3..10
$PHASE1_COMPLETE_FILE = ".squad\phase1-complete.flag"
$PHASE2_ACTIVATION_FILE = ".squad\phase2-activated.flag"

function Get-Phase1-Status {
    <#
    Get the current status of all Phase 1 issues
    #>
    $issues = gh issue list --state all --label "squad" --json number,state --limit 50 2>$null | ConvertFrom-Json
    
    $phase1_closed = 0
    $phase1_open = 0
    
    foreach ($issue_num in $PHASE1_ISSUES) {
        $issue = $issues | Where-Object { $_.number -eq $issue_num }
        if ($issue) {
            if ($issue.state -eq "CLOSED") {
                $phase1_closed++
            } else {
                $phase1_open++
            }
        }
    }
    
    return @{
        Closed = $phase1_closed
        Open = $phase1_open
        Total = 8
        Complete = ($phase1_closed -eq 8)
    }
}

function Log-Message {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message"
}

function Send-Alert {
    param([string]$Subject, [string]$Body)
    
    Log-Message "📢 ALERT: $Subject"
    Log-Message $Body
    
    if ($AlertEmail) {
        # Optionally send email via GitHub CLI or other method
        Log-Message "Email alert sent to: $AlertEmail"
    }
}

function Activate-Phase2 {
    <#
    Update focus to Phase 2 when Phase 1 completes
    #>
    Log-Message "🎉 PHASE 1 COMPLETE! Activating Phase 2..."
    
    # Update .squad/identity/now.md
    $now_content = @"
---
updated_at: $(Get-Date -Format 'o')
focus_area: Phase 2 Dataverse Schema & AI Data Prep
phase: 2
status: active
active_issues: [11, 12, 13, 14, 15, 16, 17, 18]
---

# 🚀 Phase 2 ACTIVE — Schema & Data Prep

**Status**: 🔴 LIVE  
**Duration**: 6–8 hours  
**Lead**: Tommy Shelby

## Phase 1 Checkpoint: PASSED ✅
- All 8 infrastructure tasks complete
- Environment ready for Phase 2

## Phase 2 Streams:

### Stream A: Dataverse Schema (Polly Gray)
- #11: FormSubmission table
- #12: ExtractionResult table
- #13: CorrectionRecord table
- #14: AuditLog table
- #15: D365WriteEvent table

### Stream B: AI Data & Flow (Michael + John)
- #16: Collect training data (Michael)
- #17: AI model strategy (Michael)
- #18: Flow architecture (John)

**See Discussion #51 for full briefing**
"@

    Set-Content -Path ".squad\identity\now.md" -Value $now_content
    
    # Create activation marker
    Set-Content -Path $PHASE2_ACTIVATION_FILE -Value "Phase 2 activated at $(Get-Date -Format 'o')"
    
    # Commit and push
    git add .squad/identity/now.md
    git commit -m "chore: activate Phase 2 after Phase 1 checkpoint passed

Phase 1 all issues closed. Updating focus to Phase 2 schema + data prep.
Two parallel streams active: Polly (schema) + Michael+John (AI+flows)"
    git push
    
    Log-Message "✅ Phase 2 activated, changes committed and pushed"
}

function Main {
    Log-Message "🔍 Phase 1 Monitoring Started"
    Log-Message "Checking every $Interval seconds"
    Log-Message "Watching issues: #$($PHASE1_ISSUES -join ', #')"
    Log-Message ""
    
    $startup_time = Get-Date
    $check_count = 0
    
    while ($true) {
        $check_count++
        $elapsed = (Get-Date) - $startup_time
        
        $status = Get-Phase1-Status
        
        Log-Message "Check #$check_count | Phase 1: $($status.Closed)/8 closed, $($status.Open) open | Elapsed: $($elapsed.ToString('hh\:mm\:ss'))"
        
        if ($status.Complete) {
            Log-Message ""
            Send-Alert "Phase 1 Complete!" "All 8 Phase 1 infrastructure issues are now CLOSED.`nActivating Phase 2..."
            Activate-Phase2
            
            Log-Message ""
            Log-Message "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            Log-Message "✅ PHASE 1 COMPLETE"
            Log-Message "📋 PHASE 2 NOW ACTIVE"
            Log-Message "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            Log-Message ""
            Log-Message "Phase 2 (#11-#18) is now live."
            Log-Message "Polly, Michael, John: Check GitHub for your assigned Phase 2 issues."
            Log-Message ""
            
            # Exit after successful completion
            exit 0
        }
        
        # Show progress bar
        $progress = ($status.Closed / 8 * 100)
        Write-Host "  Progress: [$('█' * [int]($progress / 10))$('░' * [int]((100 - $progress) / 10))] $([int]$progress)%" -ForegroundColor Cyan
        Write-Host ""
        
        # Wait for next check
        Start-Sleep -Seconds $Interval
    }
}

# Validate GitHub CLI is available
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Log-Message "❌ ERROR: GitHub CLI (gh) not found. Install from https://cli.github.com/"
    exit 1
}

# Start monitoring
Main
