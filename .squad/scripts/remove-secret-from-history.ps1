#!/usr/bin/env pwsh
<#
.SYNOPSIS
Remove .env.automation from entire git history using git filter-branch
.DESCRIPTION
This script removes .env.automation from all commits in the repository history.
WARNING: This rewrites history and requires force-push.
#>

$ErrorActionPreference = "Stop"

# Get the repository root
$repoRoot = git rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0) {
    Write-Error "Not in a git repository"
    exit 1
}

Write-Host "Repository: $repoRoot" -ForegroundColor Cyan
Write-Host "Removing .env.automation from entire git history..." -ForegroundColor Yellow

# Create a backup branch just in case
$backupBranch = "backup/before-secret-removal-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Write-Host "Creating backup branch: $backupBranch" -ForegroundColor Cyan
git branch $backupBranch
Write-Host "✓ Backup created" -ForegroundColor Green

# Use git-filter-branch to remove the file
# This method is more reliable than filter-repo on Windows
Write-Host "Running git filter-branch..." -ForegroundColor Cyan

$env:FILTER_BRANCH_SQUELCH_WARNING = 1

# Remove .env.automation from all commits
git filter-branch --force `
    --tree-filter 'Remove-Item -Force ".env.automation" -ErrorAction SilentlyContinue' `
    -- --all

if ($LASTEXITCODE -ne 0) {
    Write-Error "filter-branch failed. Backup available at: $backupBranch"
    exit 1
}

Write-Host "✓ Secret file removed from history" -ForegroundColor Green

# Verify the file is gone
$secretFound = git log --all --oneline -- .env.automation
if ($secretFound) {
    Write-Warning "Warning: .env.automation still found in history:"
    Write-Host $secretFound -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ Verified: .env.automation completely removed" -ForegroundColor Green

Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Review the changes: git log --oneline -10"
Write-Host "2. If satisfied, force-push: git push origin --all --force-with-lease"
Write-Host "3. If something went wrong, restore backup: git reset --hard $backupBranch"
