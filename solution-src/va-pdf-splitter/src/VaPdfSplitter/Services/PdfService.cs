using PdfSharpCore.Pdf;
using PdfSharpCore.Pdf.IO;

namespace VaPdfSplitter.Services;

public class PdfService
{
    private readonly long _maxBytes;

    public PdfService()
    {
        var raw = Environment.GetEnvironmentVariable("MAX_PDF_SIZE_BYTES");
        _maxBytes = long.TryParse(raw, out var v) ? v : 157_286_400L;
    }

    public int GetPageCount(string base64Content)
    {
        var bytes = DecodeAndValidate(base64Content);
        using var stream = new MemoryStream(bytes);
        using var doc = PdfReader.Open(stream, PdfDocumentOpenMode.Import);
        return doc.PageCount;
    }

    public string ExtractPageRange(string base64Content, int startPage, int endPage)
    {
        var bytes = DecodeAndValidate(base64Content);
        using var stream = new MemoryStream(bytes);
        using var srcDoc = PdfReader.Open(stream, PdfDocumentOpenMode.Import);
        int totalPages = srcDoc.PageCount;

        if (startPage < 1 || endPage < startPage || endPage > totalPages)
            throw new ArgumentOutOfRangeException(nameof(startPage),
                $"Page range out of bounds: requested {startPage}-{endPage} but PDF has {totalPages} pages");

        using var outDoc = new PdfDocument();
        for (int p = startPage; p <= endPage; p++)
            outDoc.AddPage(srcDoc.Pages[p - 1]);  // PdfSharpCore is 0-indexed

        using var outStream = new MemoryStream();
        outDoc.Save(outStream, false);
        return Convert.ToBase64String(outStream.ToArray());
    }

    private byte[] DecodeAndValidate(string base64Content)
    {
        byte[] bytes;
        try { bytes = Convert.FromBase64String(base64Content); }
        catch (FormatException ex)
            { throw new ArgumentException("fileContent is not valid base64.", nameof(base64Content), ex); }

        if (bytes.Length > _maxBytes)
            throw new ArgumentException(
                $"PDF exceeds maximum allowed size of {_maxBytes:N0} bytes (got {bytes.Length:N0} bytes).");

        return bytes;
    }
}
