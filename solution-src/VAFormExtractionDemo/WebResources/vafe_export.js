/* =============================================================
   VAFE Export Module — Web Resource
   VA Form 10-3542 Extraction Pipeline | D365 Model-Driven App

   Provides:
     VAFE_EXPORT.printReport()
     VAFE_EXPORT.exportActionsCsv(actions)

   No external dependencies. CSP-safe (no eval, no blob URL
   fallback that triggers CSP violations on older UAs).
   ============================================================= */

var VAFE_EXPORT = (function () {
  'use strict';

  /* ── RFC 4180 CSV helpers ─────────────────────────────────── */

  function escapeCsvCell(value) {
    var s = (value === null || value === undefined) ? '' : String(value);
    // Wrap in quotes if the value contains comma, quote, or newline
    if (s.indexOf(',') !== -1 || s.indexOf('"') !== -1 || s.indexOf('\n') !== -1) {
      return '"' + s.replace(/"/g, '""') + '"';
    }
    return s;
  }

  function buildCsvRow(cells) {
    return cells.map(escapeCsvCell).join(',');
  }

  function buildCsv(headers, rows) {
    var lines = [buildCsvRow(headers)];
    rows.forEach(function (row) {
      lines.push(buildCsvRow(row));
    });
    return lines.join('\r\n');
  }

  /* ── Download helper ──────────────────────────────────────── */
  // Creates a temporary anchor with a data: URI to trigger download.
  // Avoids Blob + createObjectURL which can be blocked by strict CSP.
  function downloadFile(filename, mimeType, content) {
    var encoded = encodeURIComponent(content);
    var dataUri = 'data:' + mimeType + ';charset=utf-8,' + encoded;

    var a = document.createElement('a');
    a.setAttribute('href', dataUri);
    a.setAttribute('download', filename);
    a.setAttribute('aria-hidden', 'true');
    a.style.display = 'none';
    document.body.appendChild(a);
    a.click();
    // Clean up after a tick so the click event has time to fire
    setTimeout(function () {
      if (a.parentNode) { a.parentNode.removeChild(a); }
    }, 100);
  }

  /* ── Public: printReport ──────────────────────────────────── */
  function printReport() {
    // The print stylesheet in vafe_report.css handles layout.
    // Force all drawers open so their content is visible in print.
    var collapsibles = document.querySelectorAll(
      '.blocker-card:not(.blocker-card--expanded), .decision-card:not(.decision-card--expanded)'
    );
    var toClose = [];

    collapsibles.forEach(function (el) {
      el.classList.add('blocker-card--expanded', 'decision-card--expanded');
      toClose.push(el);
    });

    window.print();

    // Restore collapsed state after print dialog closes
    toClose.forEach(function (el) {
      el.classList.remove('blocker-card--expanded', 'decision-card--expanded');
    });
  }

  /* ── Public: exportFormsCsv ───────────────────────────────── */
  function exportFormsCsv(submissions) {
    if (!Array.isArray(submissions) || submissions.length === 0) {
      var banner = document.getElementById('export-status');
      if (banner) {
        banner.textContent = 'No submissions to export.';
        banner.removeAttribute('hidden');
        setTimeout(function () { banner.setAttribute('hidden', 'true'); }, 3000);
      }
      return;
    }

    var headers = ['Form ID', 'Status', 'Submitted', 'Confidence (%)', 'Confidence Tier', 'Processing Time (s)', 'D365 Written', 'D365 Write Date'];

    var rows = submissions.map(function (s) {
      return [
        s.formId               || '',
        s.status               || '',
        s.submittedDate        || '',
        s.extractionConfidence !== null && s.extractionConfidence !== undefined ? s.extractionConfidence : '',
        s.confidenceTier       || '',
        s.processingTimeSec    !== null && s.processingTimeSec    !== undefined ? s.processingTimeSec    : '',
        s.d365Written ? 'Yes' : 'No',
        s.d365WriteDate        || ''
      ];
    });

    var csv      = buildCsv(headers, rows);
    var dateStr  = new Date().toISOString().split('T')[0];
    var filename = 'VAFE_Submissions_' + dateStr + '.csv';

    downloadFile(filename, 'text/csv', csv);
  }

  /* ── Public API ───────────────────────────────────────────── */
  return {
    printReport:    printReport,
    exportFormsCsv: exportFormsCsv
  };

}());
