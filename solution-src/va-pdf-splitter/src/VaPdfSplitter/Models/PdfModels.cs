namespace VaPdfSplitter.Models;

public record PdfRequest(string FileName, string FileContent);
public record SplitRequest(string FileName, string FileContent, int StartPage, int EndPage);
public record PageCountResponse(int PageCount);
public record SplitResponse(string FileContent);
public record ErrorResponse(string Error);
