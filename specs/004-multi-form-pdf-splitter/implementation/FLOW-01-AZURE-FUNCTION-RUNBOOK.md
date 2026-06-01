# Runbook: Azure Function — PDF Splitter for Flow-01

**Feature**: 004-multi-form-pdf-splitter  
**Purpose**: Deploy and configure the Azure Function that Flow-01-Batch-PDF-Splitter calls to count PDF pages and split batch PDFs into individual 2-page files.  
**Estimated Setup Time**: 1–2 hours  
**Generated**: 2026-05-19  
**Version**: 1.0.0

---

## Overview

Flow-01 makes two HTTP POST calls to this Azure Function:

| Endpoint | Purpose | Called From |
|---|---|---|
| `POST /api/pdf/page-count` | Returns total page count of uploaded PDF | Part 4 of FLOW-01-RUNBOOK.md |
| `POST /api/pdf/split` | Splits a page range and returns a 2-page PDF | Part 11 of FLOW-01-RUNBOOK.md (split loop, per-form iteration) |

Both endpoints are protected by an Azure Function host key passed via the `x-functions-key` header.

---

## Prerequisites

| Requirement | Notes |
|---|---|
| Azure subscription | Contributor access to a resource group |
| Azure Functions runtime | v4 (.NET 8 isolated or Node 20 LTS) |
| PDF library | `PdfPig` (C#) or `pdf-lib` (Node) — see Part 2 |
| Power Automate flow | Flow-01 must be in Draft/Off state during setup |

---

## Part 1: Create the Azure Function App

### Step 1.1 — Create Resource Group (skip if using an existing one)

```
Resource group name : rg-va-forms-{env}
Region              : East US (or match your SharePoint tenant region)
```

### Step 1.2 — Create Function App

In the Azure Portal → **Create a resource** → **Function App**:

| Setting | Value |
|---|---|
| **Subscription** | Your subscription |
| **Resource Group** | `rg-va-forms-{env}` |
| **Function App name** | `va-pdf-splitter-{env}` (must be globally unique) |
| **Runtime stack** | `.NET 8 (isolated)` (recommended) or `Node.js 20 LTS` |
| **Version** | `4` |
| **Region** | Match your Power Automate region |
| **OS** | `Windows` |
| **Plan type** | `Consumption (Serverless)` |
| **Storage account** | Create new or use existing |

Click **Review + create** → **Create**.

---

## Part 2: Deploy the Function Code

### Option A — C# (.NET 8 Isolated)

Create two HTTP-triggered functions. Use `PdfPig` NuGet package for PDF operations.

**`GetPageCount.cs`**:

```csharp
[Function("GetPageCount")]
public async Task<HttpResponseData> RunPageCount(
    [HttpTrigger(AuthorizationLevel.Function, "post", Route = "pdf/page-count")] HttpRequestData req)
{
    var body = await req.ReadFromJsonAsync<PdfRequest>();
    var pdfBytes = Convert.FromBase64String(body!.FileContent);

    using var doc = PdfDocument.Open(pdfBytes);
    int pageCount = doc.NumberOfPages;

    var response = req.CreateResponse(HttpStatusCode.OK);
    await response.WriteAsJsonAsync(new { pageCount });
    return response;
}
```

**`SplitPdf.cs`**:

```csharp
[Function("SplitPdf")]
public async Task<HttpResponseData> RunSplit(
    [HttpTrigger(AuthorizationLevel.Function, "post", Route = "pdf/split")] HttpRequestData req)
{
    var body = await req.ReadFromJsonAsync<SplitRequest>();
    var pdfBytes = Convert.FromBase64String(body!.FileContent);

    // Extract pages [startPage..endPage] (1-based) into a new PDF
    var splitBytes = ExtractPageRange(pdfBytes, body.StartPage, body.EndPage);

    var response = req.CreateResponse(HttpStatusCode.OK);
    await response.WriteAsJsonAsync(new { fileContent = Convert.ToBase64String(splitBytes) });
    return response;
}
```

**Request models**:

```csharp
public record PdfRequest(string FileName, string FileContent);
public record SplitRequest(string FileName, string FileContent, int StartPage, int EndPage);
```

### Option B — Node.js 20 LTS

Use `pdf-lib` package. Entry-point pattern:

```javascript
// api/pdf/page-count/index.js
const { PDFDocument } = require('pdf-lib');

module.exports = async function (context, req) {
    const buf = Buffer.from(req.body.fileContent, 'base64');
    const pdfDoc = await PDFDocument.load(buf);
    context.res = { body: { pageCount: pdfDoc.getPageCount() } };
};

// api/pdf/split/index.js
const { PDFDocument } = require('pdf-lib');

module.exports = async function (context, req) {
    const { fileContent, startPage, endPage } = req.body;
    const buf = Buffer.from(fileContent, 'base64');
    const srcDoc = await PDFDocument.load(buf);
    const newDoc = await PDFDocument.create();

    // startPage/endPage are 1-based
    for (let i = startPage - 1; i < endPage; i++) {
        const [copiedPage] = await newDoc.copyPages(srcDoc, [i]);
        newDoc.addPage(copiedPage);
    }

    const splitBytes = await newDoc.save();
    context.res = { body: { fileContent: Buffer.from(splitBytes).toString('base64') } };
};
```

---

## Part 3: HTTP Request/Response Contract

### `POST /api/pdf/page-count`

**Request body** (JSON):

```json
{
  "fileName": "batch_upload_2026.pdf",
  "fileContent": "<base64-encoded PDF bytes>"
}
```

**Response body** (JSON, HTTP 200):

```json
{
  "pageCount": 42
}
```

**Error response** (HTTP 400 or 500):

```json
{
  "error": "Failed to read PDF: <detail>"
}
```

---

### `POST /api/pdf/split`

**Request body** (JSON):

```json
{
  "fileName": "batch_upload_2026.pdf",
  "fileContent": "<base64-encoded PDF bytes>",
  "startPage": 3,
  "endPage": 4
}
```

> `startPage` and `endPage` are **1-based** page numbers. For form index N, Flow-01 computes:
> - `startPage = ((N - 1) * 2) + 1`
> - `endPage = N * 2`

**Response body** (JSON, HTTP 200):

```json
{
  "fileContent": "<base64-encoded 2-page PDF bytes>"
}
```

**Error response** (HTTP 400 or 500):

```json
{
  "error": "Page range out of bounds: requested 5-6 but PDF has 4 pages"
}
```

---

## Part 4: Required App Settings

After deployment, navigate to **Function App** → **Configuration** → **Application settings** and verify/add:

| Setting | Value | Notes |
|---|---|---|
| `FUNCTIONS_WORKER_RUNTIME` | `dotnet-isolated` or `node` | Set automatically at creation |
| `AzureWebJobsStorage` | `<storage connection string>` | Set automatically at creation |
| `MAX_PDF_SIZE_BYTES` | `157286400` | 150 MB; enforced by function to match flow validation |

> No additional secrets required. The host key (`x-functions-key`) is managed by Azure Functions automatically.

---

## Part 5: Obtain the Function URL and Key

### Step 5.1 — Get the Base URL

1. Navigate to your Function App in the Azure Portal
2. Copy the **URL** from the Overview blade (e.g., `https://va-pdf-splitter-prod.azurewebsites.net`)
3. This is your `AzureFunctionBaseUrl`

### Step 5.2 — Get the Host Key

1. Navigate to **Function App** → **App keys** (under Functions section)
2. Under **Host keys**, copy the value of `default`
3. This is your `AzureFunctionKey`

> **Security**: Store `AzureFunctionKey` as a Power Automate **Environment Variable** (secret type) or in Azure Key Vault. Do not hardcode it in the flow.

---

## Part 6: Add Parameters to Flow-01

In **Flow-01-Batch-PDF-Splitter** in Power Automate:

1. Click **Edit** → expand **Parameters** panel (top of canvas)
2. Add parameter: `AzureFunctionBaseUrl`
   - Type: `String`
   - Default: `https://va-pdf-splitter-{env}.azurewebsites.net`
3. Add parameter: `AzureFunctionKey`
   - Type: `String` (or use a connection reference / environment variable for secret handling)
   - Default: *(paste the host key from Step 5.2)*

> In production, use Power Platform **Environment Variables** of type `Secret` rather than flow parameters to avoid exposing the key in exported flow packages.

---

## Part 7: Smoke Tests

Run these before enabling Flow-01 in production.

### Test 7.1 — Page Count Endpoint

Use a REST client (Postman, curl, or Power Automate HTTP test):

```
POST https://va-pdf-splitter-{env}.azurewebsites.net/api/pdf/page-count
x-functions-key: <your key>
Content-Type: application/json

{
  "fileName": "test.pdf",
  "fileContent": "<base64 of a known 6-page PDF>"
}
```

Expected response: `{ "pageCount": 6 }`

### Test 7.2 — Split Endpoint

```
POST https://va-pdf-splitter-{env}.azurewebsites.net/api/pdf/split
x-functions-key: <your key>
Content-Type: application/json

{
  "fileName": "test.pdf",
  "fileContent": "<base64 of a known 6-page PDF>",
  "startPage": 3,
  "endPage": 4
}
```

Expected response: JSON with `fileContent` field. Decode the base64 and verify the resulting PDF has exactly 2 pages.

### Test 7.3 — Boundary Cases

| Input | Expected Behavior |
|---|---|
| `startPage` = 1, `endPage` = 2 on a 2-page PDF | Returns the entire PDF as a 2-page result |
| `startPage` = `endPage` (1 page only) | Returns a 1-page PDF (odd-page guard in Flow-01 prevents this in production) |
| `startPage` > total pages | HTTP 400 with descriptive error |
| `fileContent` is not valid base64 PDF | HTTP 400 with descriptive error |

---

## Part 8: How Flow-01 Calls This Function

For reference, the exact Power Automate HTTP action configurations are documented in [FLOW-01-RUNBOOK.md](FLOW-01-RUNBOOK.md):

| Flow-01 Step | Endpoint Called | Action Name in Flow |
|---|---|---|
| Part 4 | `POST /api/pdf/page-count` | `Call Azure Function GetPageCount` |
| Part 11.2 (split loop) | `POST /api/pdf/split` | `Call Azure Function SplitPDF` |

The split loop passes `startPage = ((varFormIndex - 1) * 2) + 1` and `endPage = varFormIndex * 2`, iterating from form index 1 to `varTotalFormCount`.

---

**Version**: 1.0.0 | **Generated**: 2026-05-19  
**Status**: Ready for deployment  
**Next**: After smoke tests pass, proceed to [FLOW-01-RUNBOOK.md](FLOW-01-RUNBOOK.md) Part 4 to wire the HTTP actions into the flow.
