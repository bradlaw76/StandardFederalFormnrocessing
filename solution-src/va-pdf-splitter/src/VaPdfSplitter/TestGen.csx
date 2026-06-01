using PdfSharpCore.Pdf;
using System;
using System.IO;

var doc = new PdfDocument();
doc.AddPage();
doc.AddPage();
using var ms = new MemoryStream();
doc.Save(ms, false);
Console.Write(Convert.ToBase64String(ms.ToArray()));
