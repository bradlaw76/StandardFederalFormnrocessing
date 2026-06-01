using System.Net;
using System.Text.Json;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using VaPdfSplitter.Models;
using VaPdfSplitter.Services;

namespace VaPdfSplitter.Functions;

public class PdfFunctions
{
    private readonly IPdfService _pdfService;
    private readonly ILogger<PdfFunctions> _logger;
    private readonly long _maxPdfSizeBytes;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = false
    };

    public PdfFunctions(IPdfService pdfService, ILogger<PdfFunctions> logger)
    {
        _pdfService = pdfService;
        _logger = logger;

        var configuredMax = Environment.GetEnvironmentVariable("MAX_PDF_SIZE_BYTES");
        _maxPdfSizeBytes = long.TryParse(configuredMax, out var parsed) ? parsed : 157_286_400L; // 150 MB
    }

    /// <summary>
    /// HTTP POST /api/GetPageCount
    /// Body: { "pdfBase64": "&lt;base64-encoded PDF&gt;" }
    /// Returns: { "pageCount": N, "fileSizeBytes": N }
    /// </summary>
    [Function("GetPageCount")]
    public async Task<HttpResponseData> GetPageCount(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "GetPageCount")] HttpRequestData req)
    {
        _logger.LogInformation("GetPageCount triggered.");

        try
        {
            var body = await req.ReadAsStringAsync();
            if (string.IsNullOrWhiteSpace(body))
                return await BadRequest(req, "Request body is required.");

            var request = JsonSerializer.Deserialize<PageCountRequest>(body, JsonOptions);
            if (request is null || string.IsNullOrWhiteSpace(request.PdfBase64))
                return await BadRequest(req, "pdfBase64 field is required.");

            byte[] pdfBytes;
            try { pdfBytes = Convert.FromBase64String(request.PdfBase64); }
            catch { return await BadRequest(req, "pdfBase64 is not valid Base64."); }

            if (pdfBytes.Length > _maxPdfSizeBytes)
                return await BadRequest(req, $"PDF exceeds maximum allowed size of {_maxPdfSizeBytes} bytes.");

            var pageCount = _pdfService.GetPageCount(pdfBytes);
            var result = new PageCountResponse { PageCount = pageCount, FileSizeBytes = pdfBytes.Length };

            var response = req.CreateResponse(HttpStatusCode.OK);
            await response.WriteStringAsync(JsonSerializer.Serialize(result, JsonOptions));
            response.Headers.Add("Content-Type", "application/json");
            return response;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error in GetPageCount");
            return await InternalError(req, ex.Message);
        }
    }

    /// <summary>
    /// HTTP POST /api/SplitPdf
    /// Body: { "pdfBase64": "...", "startPage": 1, "endPage": 5 }
    /// Returns: { "pdfBase64": "...", "pageCount": N, "fileSizeBytes": N }
    /// </summary>
    [Function("SplitPdf")]
    public async Task<HttpResponseData> SplitPdf(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "SplitPdf")] HttpRequestData req)
    {
        _logger.LogInformation("SplitPdf triggered.");

        try
        {
            var body = await req.ReadAsStringAsync();
            if (string.IsNullOrWhiteSpace(body))
                return await BadRequest(req, "Request body is required.");

            var request = JsonSerializer.Deserialize<SplitPdfRequest>(body, JsonOptions);
            if (request is null || string.IsNullOrWhiteSpace(request.PdfBase64))
                return await BadRequest(req, "pdfBase64 field is required.");

            if (request.StartPage < 1)
                return await BadRequest(req, "startPage must be >= 1.");
            if (request.EndPage < request.StartPage)
                return await BadRequest(req, "endPage must be >= startPage.");

            byte[] pdfBytes;
            try { pdfBytes = Convert.FromBase64String(request.PdfBase64); }
            catch { return await BadRequest(req, "pdfBase64 is not valid Base64."); }

            if (pdfBytes.Length > _maxPdfSizeBytes)
                return await BadRequest(req, $"PDF exceeds maximum allowed size of {_maxPdfSizeBytes} bytes.");

            var resultBytes = _pdfService.SplitPdf(pdfBytes, request.StartPage, request.EndPage);
            var pageCount = _pdfService.GetPageCount(resultBytes);

            var result = new SplitPdfResponse
            {
                PdfBase64 = Convert.ToBase64String(resultBytes),
                PageCount = pageCount,
                FileSizeBytes = resultBytes.Length
            };

            var response = req.CreateResponse(HttpStatusCode.OK);
            await response.WriteStringAsync(JsonSerializer.Serialize(result, JsonOptions));
            response.Headers.Add("Content-Type", "application/json");
            return response;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error in SplitPdf");
            return await InternalError(req, ex.Message);
        }
    }

    private static async Task<HttpResponseData> BadRequest(HttpRequestData req, string message)
    {
        var response = req.CreateResponse(HttpStatusCode.BadRequest);
        await response.WriteStringAsync(JsonSerializer.Serialize(new ErrorResponse { Error = message }, JsonOptions));
        response.Headers.Add("Content-Type", "application/json");
        return response;
    }

    private static async Task<HttpResponseData> InternalError(HttpRequestData req, string detail)
    {
        var response = req.CreateResponse(HttpStatusCode.InternalServerError);
        await response.WriteStringAsync(JsonSerializer.Serialize(
            new ErrorResponse { Error = "Internal server error.", Detail = detail }, JsonOptions));
        response.Headers.Add("Content-Type", "application/json");
        return response;
    }
}
