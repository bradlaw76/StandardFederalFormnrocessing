namespace VaPdfSplitter.Models;

/// <summary>Request model for getting PDF page count.</summary>
public class PageCountRequest
{
    /// <summary>Base64-encoded PDF bytes.</summary>
    public string PdfBase64 { get; set; } = string.Empty;
}

/// <summary>Response model for page count result.</summary>
public class PageCountResponse
{
    /// <summary>Number of pages in the PDF.</summary>
    public int PageCount { get; set; }

    /// <summary>File size in bytes.</summary>
    public long FileSizeBytes { get; set; }
}

/// <summary>Request model for splitting a PDF.</summary>
public class SplitPdfRequest
{
    /// <summary>Base64-encoded PDF bytes.</summary>
    public string PdfBase64 { get; set; } = string.Empty;

    /// <summary>First page to include (1-based).</summary>
    public int StartPage { get; set; } = 1;

    /// <summary>Last page to include (1-based, inclusive).</summary>
    public int EndPage { get; set; }
}

/// <summary>Response model for split PDF result.</summary>
public class SplitPdfResponse
{
    /// <summary>Base64-encoded bytes of the extracted page range.</summary>
    public string PdfBase64 { get; set; } = string.Empty;

    /// <summary>Number of pages in the resulting PDF.</summary>
    public int PageCount { get; set; }

    /// <summary>File size of the resulting PDF in bytes.</summary>
    public long FileSizeBytes { get; set; }
}

/// <summary>Standard error response.</summary>
public class ErrorResponse
{
    public string Error { get; set; } = string.Empty;
    public string? Detail { get; set; }
}
