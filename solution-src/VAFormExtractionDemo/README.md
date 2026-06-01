# VA Form Extraction Solution

## Folder Structure
- **Scripts/** - Provisioning automation (PowerShell)
  - provision-full.ps1 - Full automated table/field/relationship creation
  - SETUP-GUIDE.md - One-time setup (App Registration, App User)
  - AUTOMATION-STATUS.md - Constraints and lessons learned

- **Documents/** - Implementation guides and specifications
  - PROVISIONING-RUNBOOK.md - Step-by-step UI guide
  - Table definition files (.txt) - Copy-paste field specs

- **Flows/** - Power Automate workflows (to be added)

## Quick Start
1. Review SETUP-GUIDE.md (one-time Azure/PIM setup)
2. Run: .\.squad\scripts\provision-full.ps1
3. All tables + fields + relationships created in ~60 seconds
