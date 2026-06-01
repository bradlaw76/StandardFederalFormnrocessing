<#
.SYNOPSIS
    Provisions the SharePoint site and document libraries required by the
    VA Form 10-3542 extraction pipeline.

.DESCRIPTION
    Creates:
      - Team site:  /sites/VAFormProcessing
      - Libraries:  FormIntake, ProcessedForms, FormIntakeErrors (dead-letter)
      - Folders:    FormIntake/AITrainingData, FormIntake/Pending,
                    FormIntake/InProgress, ProcessedForms/Archive

.PARAMETER TenantAdminUrl
    SharePoint Admin Center URL.
    Example: https://d365demotsce80677168-admin.sharepoint.com

.PARAMETER SiteOwner
    UPN of the site owner.
    Example: admin@D365DemoTSCE80677168.onmicrosoft.com

.PARAMETER UseInteractive
    When set, uses interactive browser login instead of device code.
    Defaults to device-code (works in headless/terminal sessions).

.EXAMPLE
    .\provision-sharepoint.ps1 `
        -TenantAdminUrl "https://d365demotsce80677168-admin.sharepoint.com" `
        -SiteOwner "admin@D365DemoTSCE80677168.onmicrosoft.com"
#>
param(
    [Parameter(Mandatory)]
    [string]$TenantAdminUrl,

    [Parameter(Mandatory)]
    [string]$SiteOwner,

    [switch]$UseInteractive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─── Helpers ───────────────────────────────────────────────────────────────────

function Write-Step($msg)  { Write-Host "  → $msg" -ForegroundColor Cyan }
function Write-Ok($msg)    { Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Skip($msg)  { Write-Host "  ↷ $msg (already exists)" -ForegroundColor Yellow }
function Write-Fail($msg)  { Write-Host "  ✗ $msg" -ForegroundColor Red }

# ─── Configuration ─────────────────────────────────────────────────────────────

$SiteName   = "VA Form Processing"
$SiteAlias  = "VAFormProcessing"
$SiteDesc   = "Intake and processing hub for VA Form 10-3542 extraction pipeline"

# Derive tenant root from admin URL
# e.g. https://contoso-admin.sharepoint.com → https://contoso.sharepoint.com
$TenantRoot = $TenantAdminUrl -replace "-admin\.sharepoint\.com", ".sharepoint.com"
$SiteUrl    = "$TenantRoot/sites/$SiteAlias"

Write-Host ""
Write-Host "══════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "  VA Form Processing — SharePoint Provisioning" -ForegroundColor Magenta
Write-Host "══════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "  Admin URL : $TenantAdminUrl"
Write-Host "  Site URL  : $SiteUrl"
Write-Host "  Owner     : $SiteOwner"
Write-Host ""

# ─── Connect to Tenant Admin ───────────────────────────────────────────────────

Write-Host "Step 1 — Connecting to SharePoint Online admin..." -ForegroundColor White

try {
    if ($UseInteractive) {
        Connect-PnPOnline -Url $TenantAdminUrl -Interactive
    } else {
        Connect-PnPOnline -Url $TenantAdminUrl -DeviceLogin
    }
    Write-Ok "Connected to tenant admin"
} catch {
    Write-Fail "Connection failed: $_"
    exit 1
}

# ─── Create Site ───────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "Step 2 — Creating team site..." -ForegroundColor White

try {
    $existing = Get-PnPTenantSite -Url $SiteUrl -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Skip "Site $SiteUrl"
    } else {
        Write-Step "Creating: $SiteUrl"
        New-PnPSite -Type TeamSite `
            -Title $SiteName `
            -Alias $SiteAlias `
            -Description $SiteDesc `
            -Owner $SiteOwner `
            -Wait
        Write-Ok "Site created: $SiteUrl"
    }
} catch {
    Write-Fail "Site creation failed: $_"
    exit 1
}

# ─── Connect to the New Site ───────────────────────────────────────────────────

Write-Host ""
Write-Host "Step 3 — Connecting to site for library provisioning..." -ForegroundColor White

try {
    if ($UseInteractive) {
        Connect-PnPOnline -Url $SiteUrl -Interactive
    } else {
        Connect-PnPOnline -Url $SiteUrl -DeviceLogin
    }
    Write-Ok "Connected to $SiteUrl"
} catch {
    Write-Fail "Could not connect to new site: $_"
    exit 1
}

# ─── Library & Folder Definitions ─────────────────────────────────────────────

$Libraries = @(
    @{
        Name        = "FormIntake"
        Title       = "Form Intake"
        Description = "Incoming VA Form 10-3542 PDFs awaiting processing"
        Folders     = @("AITrainingData", "Pending", "InProgress")
        ContentType = "Document"
    },
    @{
        Name        = "ProcessedForms"
        Title       = "Processed Forms"
        Description = "Forms that have completed extraction processing"
        Folders     = @("Archive", "Errors")
        ContentType = "Document"
    },
    @{
        Name        = "FormIntakeErrors"
        Title       = "Form Intake Errors"
        Description = "Dead-letter queue for forms that failed processing (max 3 retries)"
        Folders     = @()
        ContentType = "Document"
    }
)

# ─── Create Libraries ─────────────────────────────────────────────────────────

Write-Host ""
Write-Host "Step 4 — Provisioning document libraries..." -ForegroundColor White

foreach ($lib in $Libraries) {
    Write-Step "Library: $($lib.Name)"

    try {
        $existing = Get-PnPList -Identity $lib.Name -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Skip "  Library '$($lib.Name)'"
        } else {
            New-PnPList -Title $lib.Name `
                -Template DocumentLibrary `
                -OnQuickLaunch
            Write-Ok "  Created library: $($lib.Name)"
        }
    } catch {
        Write-Fail "  Failed to create '$($lib.Name)': $_"
        continue
    }

    # Create folders
    foreach ($folder in $lib.Folders) {
        try {
            $folderPath = "$($lib.Name)/$folder"
            $existing = Get-PnPFolder -Url $folderPath -ErrorAction SilentlyContinue
            if ($existing) {
                Write-Skip "    Folder: $folder"
            } else {
                Add-PnPFolder -Name $folder -Folder $lib.Name | Out-Null
                Write-Ok "    Created folder: $($lib.Name)/$folder"
            }
        } catch {
            Write-Fail "    Could not create folder '$folder' in '$($lib.Name)': $_"
        }
    }
}

# ─── Summary ──────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  ✅ SharePoint Provisioning Complete" -ForegroundColor Green
Write-Host "══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "Site URL  : $SiteUrl"
Write-Host ""
Write-Host "Libraries created:"
Write-Host "  FormIntake/"
Write-Host "    AITrainingData/   ← upload training PDFs here (#16)"
Write-Host "    Pending/          ← drop zone for new form submissions"
Write-Host "    InProgress/       ← forms being processed by flows"
Write-Host "  ProcessedForms/"
Write-Host "    Archive/"
Write-Host "    Errors/"
Write-Host "  FormIntakeErrors/   ← dead-letter queue (failed forms)"
Write-Host ""
Write-Host "Next step: Update FLOW-ARCHITECTURE.md and environment variables"
Write-Host "  in Power Automate with: $SiteUrl"
Write-Host ""
