using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using System.Text.Json;
using VaPdfSplitter.Models;
using VaPdfSplitter.Services;

namespace VaPdfSplitter.Functions;

public class PdfFunctions
{
    private readonly PdfService _svc;
    private readonly ILogger<PdfFunctions> _log;
    private static readonly JsonSerializerOptions _json = new() { PropertyNameCaseInsensitive = true };

    public PdfFunctions(PdfService svc, ILogger<PdfFunctions> log)
    {
        _svc = svc;
        _log = log;
    }

    [Function("GetPageCount")]
    public async Task<HttpResponseData> GetPageCount(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "pdf/page-count")] HttpRequestData req)
    {
        try
        {
            var body = await JsonSerializer.DeserializeAsync<PdfRequest>(req.Body, _json)
                       ?? throw new ArgumentException("Empty request body");

            int count = _svc.GetPageCount(body.FileContent);
            _log.LogInformation("GetPageCount: {File} => {Count} pages", body.FileName, count);
            return await OkJson(req, new PageCountResponse(count));
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "GetPageCount failed");
            return await ErrorJson(req, ex.Message, HttpStatusCode.BadRequest);
        }
    }

    [Function("SplitPdf")]
    public async Task<HttpResponseData> SplitPdf(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "pdf/split")] HttpRequestData req)
    {
        try
        {
            var body = await JsonSerializer.DeserializeAsync<SplitRequest>(req.Body, _json)
                       ?? throw new ArgumentException("Empty request body");

            string result = _svc.ExtractPageRange(body.FileContent, body.StartPage, body.EndPage);
            _log.LogInformation("SplitPdf: {File} pages {S}-{E}", body.FileName, body.StartPage, body.EndPage);
            return await OkJson(req, new SplitResponse(result));
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "SplitPdf failed");
            return await ErrorJson(req, ex.Message, HttpStatusCode.BadRequest);
        }
    }

    private static async Task<HttpResponseData> OkJson<T>(HttpRequestData req, T payload)
    {
        var res = req.CreateResponse(HttpStatusCode.OK);
        await res.WriteAsJsonAsync(payload);
        return res;
    }

    private static async Task<HttpResponseData> ErrorJson(HttpRequestData req, string message, HttpStatusCode code)
    {
        var res = req.CreateResponse(code);
        await res.WriteAsJsonAsync(new ErrorResponse(message));
        return res;
    }
}
