using UglyToad.PdfPig;
using UglyToad.PdfPig.Writer;

namespace VaPdfSplitter.Services;

public interface IPdfService
{
    int GetPageCount(byte[] pdfBytes);
    byte[] SplitPdf(byte[] pdfBytes, int startPage, int endPage);
}

public class PdfService : IPdfService
{
    /// <summary>Returns the total number of pages in the provided PDF.</summary>
    public int GetPageCount(byte[] pdfBytes)
    {
        using var document = PdfDocument.Open(pdfBytes);
        return document.NumberOfPages;
    }

    /// <summary>
    /// Extracts pages [startPage..endPage] (1-based, inclusive) from the PDF
    /// and returns them as a new PDF byte array.
    /// </summary>
    public byte[] SplitPdf(byte[] pdfBytes, int startPage, int endPage)
    {
        using var sourceDocument = PdfDocument.Open(pdfBytes);

        int totalPages = sourceDocument.NumberOfPages;
        if (startPage < 1) startPage = 1;
        if (endPage > totalPages) endPage = totalPages;
        if (startPage > endPage)
            throw new ArgumentException($"startPage ({startPage}) must be <= endPage ({endPage}).");

        var builder = new PdfDocumentBuilder();

        for (int pageNum = startPage; pageNum <= endPage; pageNum++)
        {
            builder.AddPage(sourceDocument, pageNum);
        }

        return builder.Build();
    }
}
