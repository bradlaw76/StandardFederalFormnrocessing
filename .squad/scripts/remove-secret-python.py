#!/usr/bin/env python3
"""
Remove .env.automation from git history using a Python-based approach.
This is more reliable than shell-based filters on Windows.
"""

import subprocess
import sys
import json
from pathlib import Path

def run_command(cmd, shell=False, capture_output=False):
    """Run a shell command and return result."""
    try:
        if capture_output:
            result = subprocess.run(cmd, shell=shell, capture_output=True, text=True, check=False)
            return result.returncode, result.stdout, result.stderr
        else:
            result = subprocess.run(cmd, shell=shell, check=False)
            return result.returncode, "", ""
    except Exception as e:
        print(f"Error running command: {e}")
        return 1, "", str(e)

def main():
    print("=" * 60)
    print("GIT SECRET REMOVAL TOOL")
    print("=" * 60)
    
    # Verify we're in a git repo
    code, output, err = run_command("git rev-parse --show-toplevel", capture_output=True)
    if code != 0:
        print("❌ Not in a git repository")
        return 1
    
    repo_root = output.strip()
    print(f"Repository: {repo_root}\n")
    
    # Create backup
    import datetime
    backup_branch = f"backup/secret-removal-{datetime.datetime.now().strftime('%Y%m%d-%H%M%S')}"
    print(f"📌 Creating backup branch: {backup_branch}")
    code, _, _ = run_command(f'git branch "{backup_branch}"')
    if code != 0:
        print("❌ Failed to create backup branch")
        return 1
    print("✓ Backup created\n")
    
    # Find all commits that contain .env.automation
    print("🔍 Scanning for commits with .env.automation...")
    code, commits_output, _ = run_command("git log --all --oneline -- .env.automation", capture_output=True)
    
    if commits_output.strip():
        print(f"Found commits referencing .env.automation:")
        for line in commits_output.strip().split('\n'):
            print(f"  {line}")
    
    # Get the commit that ADDED the file (earliest one)
    code, all_commits, _ = run_command("git log --all --reverse --oneline -- .env.automation", capture_output=True)
    
    if all_commits.strip():
        first_commit = all_commits.strip().split('\n')[0].split()[0]
        print(f"\n📋 Earliest commit with file: {first_commit}")
        
        # Rebase from before that commit
        code, commit_info, _ = run_command(f"git show {first_commit} --format=%H -s", capture_output=True)
        if code == 0:
            print(f"\n🔧 Running interactive rebase to edit commits...")
            print(f"   This will remove .env.automation from {first_commit} onwards\n")
            
            # Use git filter-branch with exec to remove the file
            print("⏳ Filtering commits (this may take a minute)...")
            env_vars = {"FILTER_BRANCH_SQUELCH_WARNING": "1"}
            code, _, stderr = run_command(
                f'git filter-branch --force --prune-empty --tree-filter "if [ -f .env.automation ]; then rm -f .env.automation; fi" -- --all',
                shell=True
            )
            
            if code == 0:
                print("✓ Filter completed\n")
                
                # Verify removal
                code, remaining, _ = run_command("git log --all --oneline -- .env.automation", capture_output=True)
                
                if remaining.strip():
                    print("⚠️  Warning: File references still exist (this is normal for deletion commits)")
                    print("   Checking if actual SECRET CONTENT was removed...")
                    
                    # Check first commit for actual content
                    code, content, err = run_command(f"git show {first_commit}:.env.automation 2>/dev/null", capture_output=True, shell=True)
                    
                    if "DATAVERSE_CLIENT_SECRET" in content or "DATAVERSE_CLIENT_ID" in content:
                        print("\n❌ SECRET CONTENT STILL IN HISTORY")
                        print("   Restoring backup...")
                        run_command(f'git reset --hard "{backup_branch}"')
                        return 1
                    else:
                        print("✓ Actual secret content is REMOVED")
                        print("✓ History rewrite successful\n")
                else:
                    print("✓ File completely removed from history\n")
                
                print("=" * 60)
                print("✅ SUCCESS: Secret removed from git history")
                print("=" * 60)
                print("\n📝 NEXT STEPS:")
                print("1. Review changes:")
                print("   git log --oneline -10")
                print("\n2. If satisfied, force-push:")
                print("   git push origin --all --force-with-lease")
                print("\n3. If issues, restore backup:")
                print(f'   git reset --hard "{backup_branch}"\n')
                
                return 0
            else:
                print(f"❌ Filter failed: {stderr}")
                print(f"\n🔄 Restoring backup: {backup_branch}")
                run_command(f'git reset --hard "{backup_branch}"')
                return 1
    else:
        print("ℹ️  No commits found with .env.automation")
        return 0

if __name__ == "__main__":
    sys.exit(main())
