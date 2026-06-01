using VaPdfSplitter.Services;
using Xunit;

namespace VaPdfSplitter.Tests;

public class PdfServiceTests
{
    private readonly IPdfService _sut = new PdfService();

    /// <summary>Creates a minimal valid 1-page PDF in memory using PdfPig builder.</summary>
    private static byte[] CreateTestPdf(int pages = 1)
    {
        var builder = new UglyToad.PdfPig.Writer.PdfDocumentBuilder();
        for (int i = 0; i < pages; i++)
        {
            var page = builder.AddPage(UglyToad.PdfPig.Content.PageSize.A4);
            page.AddText($"Page {i + 1}", 12,
                new UglyToad.PdfPig.Core.PdfPoint(50, 700),
                builder.AddStandard14Font(UglyToad.PdfPig.Fonts.Standard14Fonts.Standard14Font.Helvetica));
        }
        return builder.Build();
    }

    [Fact]
    public void GetPageCount_ReturnCorrectCount()
    {
        var pdf = CreateTestPdf(3);
        var count = _sut.GetPageCount(pdf);
        Assert.Equal(3, count);
    }

    [Fact]
    public void SplitPdf_ExtractsCorrectRange()
    {
        var pdf = CreateTestPdf(5);
        var split = _sut.SplitPdf(pdf, 2, 4);
        var count = _sut.GetPageCount(split);
        Assert.Equal(3, count);
    }

    [Fact]
    public void SplitPdf_SinglePage_ReturnsOnePage()
    {
        var pdf = CreateTestPdf(5);
        var split = _sut.SplitPdf(pdf, 3, 3);
        Assert.Equal(1, _sut.GetPageCount(split));
    }

    [Fact]
    public void SplitPdf_ThrowsWhenStartGreaterThanEnd()
    {
        var pdf = CreateTestPdf(5);
        Assert.Throws<ArgumentException>(() => _sut.SplitPdf(pdf, 4, 2));
    }

    [Fact]
    public void SplitPdf_ClampsEndPageToTotalPages()
    {
        var pdf = CreateTestPdf(3);
        // endPage > totalPages should clamp and not throw
        var split = _sut.SplitPdf(pdf, 1, 99);
        Assert.Equal(3, _sut.GetPageCount(split));
    }
}
