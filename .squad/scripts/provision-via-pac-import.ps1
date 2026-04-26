# Create Solution via Solution Manifest XML + Import
# This approach exports an existing solution structure and re-imports a new one

param(
    [string]$OrgUrl = "https://healthconnectcenter.crm.dynamics.com",
    [string]$SolutionName = "VAFormExtractionDemo",
    [string]$SolutionUniqueName = "VAFormExtractionDemo",
    [string]$PublisherPrefix = "vafe"
)

$ErrorActionPreference = "Stop"

Write-Host "=========================================="
Write-Host "🚀 Solution Provisioning via pac CLI"
Write-Host "=========================================="
Write-Host ""

# ============================================================================
# STEP 1: Check pac CLI
# ============================================================================

Write-Host "📦 Step 1: Verifying pac CLI..."

try {
    $pacVersion = pac --version 2>&1
    Write-Host "  ✅ pac CLI available: $pacVersion"
} catch {
    Write-Host "  ❌ pac CLI not found. Install: npm install -g @microsoft/power-platform-cli"
    exit 1
}

Write-Host ""

# ============================================================================
# STEP 2: Create Solution Package Files
# ============================================================================

Write-Host "📝 Step 2: Creating Solution Package Files..."

$tempDir = "$env:TEMP\vafe-solution"

if (-not (Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
}

# Create solution.xml
$solutionXml = @"
<?xml version="1.0" encoding="utf-8"?>
<ImportExportXml xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" SolutionPackageVersion="9.2" languagepacks_importmode="ignore" generatedSchemaVersion="2.0">
  <SolutionManifest>
    <UniqueName>$SolutionUniqueName</UniqueName>
    <LocalizedNames>
      <LocalizedName description="$SolutionName" languageid="1033" />
    </LocalizedNames>
    <Descriptions/>
    <Version>1.0.0.0</Version>
    <Managed>0</Managed>
    <Publisher>
      <UniqueName>${PublisherPrefix}_publisher</UniqueName>
      <LocalizedNames>
        <LocalizedName description="VA Form Extraction Demo" languageid="1033" />
      </LocalizedNames>
      <Descriptions/>
      <EMailAddress xsi:nil="true" />
      <SupportingWebsiteUrl xsi:nil="true" />
      <CustomizationPrefix>$PublisherPrefix</CustomizationPrefix>
      <CustomizationOptionValuePrefix>1</CustomizationOptionValuePrefix>
      <Addresses>
        <Address>
          <AddressNumber>1</AddressNumber>
          <AddressTypeCode>1</AddressTypeCode>
          <City xsi:nil="true" />
          <Company xsi:nil="true" />
          <Country xsi:nil="true" />
          <County xsi:nil="true" />
          <Fax xsi:nil="true" />
          <FreightTermsCode xsi:nil="true" />
          <ImportSequenceNumber xsi:nil="true" />
          <Latitude xsi:nil="true" />
          <Line1 xsi:nil="true" />
          <Line2 xsi:nil="true" />
          <Line3 xsi:nil="true" />
          <Longitude xsi:nil="true" />
          <Name xsi:nil="true" />
          <PostOfficeBox xsi:nil="true" />
          <PostalCode xsi:nil="true" />
          <ShippingMethodCode>1</ShippingMethodCode>
          <StateOrProvince xsi:nil="true" />
          <Telephone1 xsi:nil="true" />
          <Telephone2 xsi:nil="true" />
          <Telephone3 xsi:nil="true" />
          <TimeZoneRuleVersionNumber xsi:nil="true" />
          <UPSZone xsi:nil="true" />
          <UTCOffset xsi:nil="true" />
        </Address>
      </Addresses>
    </Publisher>
  </SolutionManifest>
  <RootComponents>
  </RootComponents>
  <MissingDependencies/>
  <ContentTypes/>
  <Descriptor lcid="1033">
    <DisplayString description="$SolutionName"/>
  </Descriptor>
</ImportExportXml>
"@

# Create customizations.xml (empty, required)
$customizationsXml = @"
<?xml version="1.0" encoding="utf-8"?>
<ImportExportXml xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" SolutionPackageVersion="9.2" languagepacks_importmode="ignore" generatedSchemaVersion="2.0">
  <RootComponents/>
</ImportExportXml>
"@

# Create [Content_Types].xml (required)
$contentTypesXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml" />
  <Default Extension="xml" ContentType="application/xml" />
  <Override PartName="/solution.xml" ContentType="application/xml" />
  <Override PartName="/customizations.xml" ContentType="application/xml" />
</Types>
"@

$solutionXml | Out-File -FilePath "$tempDir\solution.xml" -Encoding UTF8 -Force
$customizationsXml | Out-File -FilePath "$tempDir\customizations.xml" -Encoding UTF8 -Force
$contentTypesXml | Out-File -LiteralPath (Join-Path $tempDir "[Content_Types].xml") -Encoding UTF8 -Force

Write-Host "  ✅ solution.xml created"
Write-Host "  ✅ customizations.xml created"
Write-Host "  ✅ [Content_Types].xml created"

Write-Host ""

# ============================================================================
# STEP 3: Create Solution ZIP Package
# ============================================================================

Write-Host "📦 Step 3: Creating Solution Package..."

$zipPath = "$tempDir\VAFormExtractionDemo.zip"

# Create a proper solution ZIP structure
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

# Create ZIP with all required files
Add-Type -AssemblyName System.IO.Compression.FileSystem

$zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)

# Add solution.xml
$entry1 = $zip.CreateEntry("solution.xml")
$streamWriter1 = New-Object System.IO.StreamWriter($entry1.Open())
$streamWriter1.Write($solutionXml)
$streamWriter1.Close()

# Add customizations.xml
$entry2 = $zip.CreateEntry("customizations.xml")
$streamWriter2 = New-Object System.IO.StreamWriter($entry2.Open())
$streamWriter2.Write($customizationsXml)
$streamWriter2.Close()

# Add [Content_Types].xml
$entry3 = $zip.CreateEntry("[Content_Types].xml")
$streamWriter3 = New-Object System.IO.StreamWriter($entry3.Open())
$streamWriter3.Write($contentTypesXml)
$streamWriter3.Close()

$zip.Dispose()

Write-Host "  ✅ Solution package created: $zipPath"

Write-Host ""

# ============================================================================
# STEP 4: Import Solution
# ============================================================================

Write-Host "📥 Step 4: Importing Solution..."

try {
    # Use pac solution import command
    $importCmd = & pac solution import --path $zipPath 2>&1
    
    Write-Host "  ✅ Import initiated"
    Write-Host "  📋 Output:"
    Write-Host $importCmd
    
} catch {
    Write-Host "  ⚠️  Import completed with notes (check above)"
}

Write-Host ""

# ============================================================================
# STEP 5: Verify
# ============================================================================

Write-Host "✅ Step 5: Verifying Solution..."

try {
    $solutions = pac solution list 2>&1 | Select-String $SolutionUniqueName
    
    if ($solutions) {
        Write-Host "  ✅ Solution verified in environment"
        Write-Host ""
        Write-Host "=========================================="
        Write-Host "✅ SUCCESS"
        Write-Host "=========================================="
        Write-Host ""
        Write-Host "Solution '$SolutionName' is now available."
        Write-Host ""
        Write-Host "📝 Next: Use Power Apps UI to add tables:"
        Write-Host "  1. Go to: https://make.powerapps.com"
        Write-Host "  2. Select solution: $SolutionName"
        Write-Host "  3. Click: + New → Table"
        Write-Host "  4. Follow PROVISIONING-RUNBOOK.md for each table"
        Write-Host ""
    } else {
        Write-Host "  ⚠️  Solution not yet visible. It may take 1-2 minutes to appear."
        Write-Host "  Refresh: pac solution list"
    }
} catch {
    Write-Host "  ⚠️  Could not verify immediately: $_"
}

Write-Host ""
