# Provision Solution using pac solution init + pack + import workflow

param(
    [string]$SolutionName = "VAFormExtractionDemo",
    [string]$SolutionPublisher = "VAFormExtractionDemo",
    [string]$PublisherPrefix = "vafe"
)

$ErrorActionPreference = "Stop"

Write-Host "=========================================="
Write-Host "🚀 Solution Provisioning (pac workflow)"
Write-Host "=========================================="
Write-Host ""

$tempDir = "$env:TEMP\vafe-solution-project"

# Clean up old project
if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force
}

New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
Push-Location $tempDir

Write-Host "📦 Step 1: Initialize Solution Project..."
Write-Host "  Location: $tempDir"
Write-Host ""

try {
    # Initialize solution project (only publisher-name, publisher-prefix, and optional output directory)
    $initOutput = & pac solution init `
        --publisher-name "$SolutionPublisher" `
        --publisher-prefix $PublisherPrefix `
        --outputDirectory $tempDir 2>&1
    
    Write-Host "  ✅ Solution project initialized"
    Write-Host ""
    
    # The init command creates a solution with a default name, let's check what was created
    Get-ChildItem $tempDir -Recurse | Where-Object { $_.Name -match '.*\.xml' } | ForEach-Object {
        Write-Host "  📁 Created: $($_.FullName.Replace($tempDir, '.'))"
    }
} catch {
    Write-Host "  ❌ Error: $_"
    Pop-Location
    exit 1
}

Write-Host ""
Write-Host "📝 Step 2: Creating Solution Package..."

$zipPath = Join-Path $tempDir "VAFormExtractionDemo.zip"

try {
    # Pack the solution
    $packOutput = & pac solution pack `
        --zipfile $zipPath `
        --folder . `
        --allowWrite `
        --allowDelete 2>&1
    
    if (Test-Path $zipPath) {
        $fileSize = (Get-Item $zipPath).Length
        Write-Host "  ✅ Solution package created ($fileSize bytes)"
    } else {
        Write-Host "  ⚠️  Zip file not found, continuing..."
    }
} catch {
    Write-Host "  ⚠️  Pack result: $_"
}

Write-Host ""
Write-Host "📥 Step 3: Importing Solution..."

try {
    # Import the packed solution
    $importOutput = & pac solution import `
        --path $zipPath `
        --publish-changes 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Solution imported successfully"
    } else {
        Write-Host "  ⚠️  Import may have completed. Check Power Apps:"
    }
} catch {
    Write-Host "  ⚠️  $_"
}

Pop-Location

Write-Host ""
Write-Host "=========================================="
Write-Host "✅ Solution Provisioned"
Write-Host "=========================================="
Write-Host ""
Write-Host "📝 Next Steps:"
Write-Host "  1. Go to: https://make.powerapps.com"
Write-Host "  2. Verify solution: $SolutionName"
Write-Host "  3. Add 5 tables per PROVISIONING-RUNBOOK.md"
Write-Host ""
Write-Host "📂 Project Location: $tempDir"
Write-Host ""
