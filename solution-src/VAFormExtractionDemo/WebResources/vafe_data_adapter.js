/* =============================================================
   VAFE Data Adapter — Web Resource Module
   VA Form 10-3542 Extraction Pipeline | D365 Model-Driven App

   Operational form-processing data layer.
   Queries vafe_formsubmission, vafe_extractionresult,
   vafe_correctionrecord, vafe_auditlog, vafe_d365writeevent.

   Toggle via VAFE_CONFIG.useMock (set before this script loads).
   ============================================================= */

/* global VAFE_CONFIG */

var VAFE_DATA = (function () {
  'use strict';

  var cfg    = (typeof VAFE_CONFIG !== 'undefined') ? VAFE_CONFIG : {};
  var useMock = (cfg.useMock !== false);
  var envUrl  = cfg.environmentUrl || '';

  /* ── Xrm context discovery ──────────────────────────────── */
  function resolveXrm() {
    try { if (window.parent && window.parent.Xrm) { return window.parent.Xrm; } } catch (_) {}
    if (typeof window.Xrm !== 'undefined') { return window.Xrm; }
    return null;
  }

  function getClientUrl() {
    if (envUrl) { return envUrl.replace(/\/$/, ''); }
    var xrm = resolveXrm();
    if (xrm && xrm.Utility && xrm.Utility.getGlobalContext) {
      try { return xrm.Utility.getGlobalContext().getClientUrl(); } catch (_) {}
    }
    return window.location.origin;
  }

  /* ── Dataverse REST helper ──────────────────────────────── */
  function dvFetch(path) {
    var url = getClientUrl() + '/api/data/v9.2/' + path;
    return fetch(url, {
      method: 'GET',
      credentials: 'same-origin',
      headers: {
        'Accept': 'application/json',
        'OData-MaxVersion': '4.0',
        'OData-Version': '4.0',
        'Prefer': 'odata.include-annotations="*"'
      }
    }).then(function (res) {
      if (!res.ok) {
        return res.json().catch(function () { return {}; }).then(function (b) {
          throw new Error('Dataverse: ' + ((b.error && b.error.message) || 'HTTP ' + res.status));
        });
      }
      return res.json();
    });
  }

  function retrieveMultiple(entitySet, select, filter, top, orderby) {
    var qs = [];
    if (select)  { qs.push('$select='  + select); }
    if (filter)  { qs.push('$filter='  + encodeURIComponent(filter)); }
    if (orderby) { qs.push('$orderby=' + encodeURIComponent(orderby)); }
    if (top)     { qs.push('$top='     + top); }
    return dvFetch(entitySet + (qs.length ? '?' + qs.join('&') : ''))
      .then(function (d) { return d.value || []; });
    // TODO: follow d['@odata.nextLink'] for paginated result sets > top
  }

  /* ──────────────────────────────────────────────────────────
     NORMALIZED SCHEMA

     ProcessingStats
       { totalAllTime, totalThisWeek, totalToday,
         currentlyProcessing, writtenAllTime, writtenThisWeek, writtenToday,
         inReview, failed, autoApprovalRatePct, avgConfidence,
         avgProcessingTimeSec, lastUpdated }

     StatusStage
       { status, label, count, pct, color }

     ReviewItem
       { formId, submittedDate, overallConfidence, flaggedFields,
         assignedTo, slaDeadline, slaStatus }

     Submission
       { formId, status, submittedDate, extractionConfidence,
         confidenceTier, processingTimeSec, d365Written, d365WriteDate }

     ExtractionMetrics
       { totalExtracted, avgConfidence, avgProcessingTimeSec,
         tiers: [{ label, count, pct, color }],
         topFlaggedFields: [{ field, count }] }

     WriteEventSummary
       { totalAttempted, successCount, failedResolved,
         failedPendingRetry, permanentFailure,
         successRatePct, avgWriteTimeMs }

     FailedForm
       { formId, failedAt, reason, failedDate, retryCount, status }

     DailyVolume
       { date, label, submitted, written, failed }
     ────────────────────────────────────────────────────────── */

  /* ──────────────────────────────────────────────────────────
     MOCK PROVIDER — realistic operational seed data
     ────────────────────────────────────────────────────────── */
  var MockProvider = {

    getProcessingStats: function () {
      return Promise.resolve({
        totalAllTime:          150,
        totalThisWeek:          67,
        totalToday:             12,
        currentlyProcessing:     5,   // Extracting (3) + Writing (2)
        writtenAllTime:        112,
        writtenThisWeek:        48,
        writtenToday:            8,
        inReview:               18,   // status = Correcting
        failed:                  8,   // PermanentFailure
        autoApprovalRatePct:    50.7, // of successfully extracted: confidence ≥ 95%
        avgConfidence:          87.3,
        avgProcessingTimeSec:    4.2,
        lastUpdated: '2026-06-01T14:30:00Z'
      });
    },

    getStatusPipeline: function () {
      // Counts of vafe_formsubmission records per vafe_status value.
      // Total active = 150. Percentages of total.
      return Promise.resolve([
        { status: 'Intake',     label: 'Intake',     count:   7, pct:  4.7, color: 'neutral' },
        { status: 'Extracting', label: 'Extracting', count:   3, pct:  2.0, color: 'primary' },
        { status: 'Extracted',  label: 'Extracted',  count:   2, pct:  1.3, color: 'primary' },
        { status: 'Correcting', label: 'In Review',  count:  18, pct: 12.0, color: 'warning' },
        { status: 'Corrected',  label: 'Corrected',  count:   4, pct:  2.7, color: 'accent'  },
        { status: 'Writing',    label: 'Writing',    count:   2, pct:  1.3, color: 'primary' },
        { status: 'Written',    label: 'Written',    count: 112, pct: 74.7, color: 'success' },
        { status: 'Failed',     label: 'Failed',     count:   8, pct:  5.3, color: 'danger'  }
      ]);
    },


    getExtractionMetrics: function () {
      return Promise.resolve({
        totalExtracted: 142,
        avgConfidence: 87.3,
        avgProcessingTimeSec: 4.2,
        tiers: [
          { label: '≥ 95% — Auto-approved', count: 72, pct: 50.7, color: 'success' },
          { label: '85–94% — Review required', count: 52, pct: 36.6, color: 'warning' },
          { label: '60–84% — Manual review', count: 10, pct:  7.0, color: 'high'    },
          { label: '< 60% — Rejected',        count:  8, pct:  5.6, color: 'danger'  }
        ],
        topFlaggedFields: [
          { field: 'TravelBeginDate',        count: 23 },
          { field: 'TreatingFacilityAddress', count: 19 },
          { field: 'ClaimantSSN',            count: 12 },
          { field: 'ExpenseA_Amount',        count:  8 },
          { field: 'TravelFromAddress',      count:  7 },
          { field: 'SignatureDate',          count:  5 }
        ]
      });
    },

    getWriteEventSummary: function () {
      // Aggregated from vafe_d365writeevent.
      return Promise.resolve({
        totalAttempted:     126,
        successCount:       112,
        failedResolved:       6,
        failedPendingRetry:   2,
        permanentFailure:     6,
        successRatePct:      88.9,
        avgWriteTimeMs:      780,
        retrySuccessRatePct: 75.0   // 6 resolved of 8 that needed retry
      });
    },

    getDailyVolume: function () {
      // Last 7 days of vafe_formsubmission aggregated by date(vafe_submissiondate).
      return Promise.resolve([
        { date: '2026-05-26', label: 'Mon 26', submitted: 18, written: 14, failed: 2 },
        { date: '2026-05-27', label: 'Tue 27', submitted: 22, written: 19, failed: 1 },
        { date: '2026-05-28', label: 'Wed 28', submitted: 15, written: 11, failed: 1 },
        { date: '2026-05-29', label: 'Thu 29', submitted: 20, written: 17, failed: 2 },
        { date: '2026-05-30', label: 'Fri 30', submitted: 11, written:  8, failed: 1 },
        { date: '2026-05-31', label: 'Sat 31', submitted: 13, written: 10, failed: 1 },
        { date: '2026-06-01', label: 'Sun  1', submitted: 12, written:  8, failed: 0 }
      ]);
    }
  };

  /* ──────────────────────────────────────────────────────────
     DATAVERSE PROVIDER
     Queries the 5 operational tables directly.
     Replace TODO column names with actual logical names.
     ────────────────────────────────────────────────────────── */
  var DataverseProvider = {

    getProcessingStats: function () {
      // Entity set confirmed: vafe_formsubmissions
      // VERIFY column logical names in maker portal before go-live:
      //   vafe_status (choice), vafe_submissiondate (datetime),
      //   vafe_extractionconfidence (decimal), vafe_processingtimems (whole number)
      return retrieveMultiple(
        'vafe_formsubmissions',
        'vafe_formsubmissionid,vafe_status,vafe_submissiondate,vafe_extractionconfidence,vafe_processingtimems',
        null,
        5000
      ).then(function (rows) {
        var today = new Date().toISOString().split('T')[0];
        var weekAgo = new Date(Date.now() - 7 * 86400000).toISOString().split('T')[0];
        var stats = {
          totalAllTime: rows.length, totalThisWeek: 0, totalToday: 0,
          currentlyProcessing: 0, writtenAllTime: 0, writtenThisWeek: 0, writtenToday: 0,
          inReview: 0, failed: 0, autoApprovalRatePct: 0,
          avgConfidence: 0, avgProcessingTimeSec: 0, lastUpdated: new Date().toISOString()
        };
        var confSum = 0, confCount = 0, timeSum = 0, timeCount = 0, autoCount = 0, extractedCount = 0;
        rows.forEach(function (r) {
          var d = (r.vafe_submissiondate || '').split('T')[0];
          if (d >= weekAgo) { stats.totalThisWeek++; if (d === today) { stats.totalToday++; } }
          if (r.vafe_status === 'Written')    { stats.writtenAllTime++; if (d >= weekAgo) { stats.writtenThisWeek++; if (d === today) { stats.writtenToday++; } } }
          if (r.vafe_status === 'Extracting' || r.vafe_status === 'Writing') { stats.currentlyProcessing++; }
          if (r.vafe_status === 'Correcting') { stats.inReview++; }
          if (r.vafe_status === 'Failed' || r.vafe_status === 'PermanentFailure') { stats.failed++; }
          if (r.vafe_extractionconfidence != null) {
            confSum += r.vafe_extractionconfidence; confCount++;
            extractedCount++;
            if (r.vafe_extractionconfidence >= 95) { autoCount++; }
          }
          if (r.vafe_processingtimems != null) { timeSum += r.vafe_processingtimems; timeCount++; }
        });
        stats.avgConfidence = confCount ? Math.round(confSum / confCount * 10) / 10 : 0;
        stats.avgProcessingTimeSec = timeCount ? Math.round(timeSum / timeCount / 100) / 10 : 0;
        stats.autoApprovalRatePct = extractedCount ? Math.round(autoCount / extractedCount * 1000) / 10 : 0;
        return stats;
      });
    },

    getStatusPipeline: function () {
      // Entity set confirmed: vafe_formsubmissions
      // VERIFY: vafe_status option set values match Intake/Extracting/Extracted/Correcting/Corrected/Writing/Written/Failed
      return retrieveMultiple('vafe_formsubmissions', 'vafe_status', null, 5000)
        .then(function (rows) {
          var statusOrder = ['Intake','Extracting','Extracted','Correcting','Corrected','Writing','Written','Failed'];
          var colorMap = { Intake:'neutral', Extracting:'primary', Extracted:'primary', Correcting:'warning', Corrected:'accent', Writing:'primary', Written:'success', Failed:'danger' };
          var labelMap = { Correcting:'In Review', Failed:'Failed' };
          var counts = {};
          statusOrder.forEach(function (s) { counts[s] = 0; });
          rows.forEach(function (r) { if (counts[r.vafe_status] !== undefined) { counts[r.vafe_status]++; } });
          return statusOrder.map(function (s) {
            return { status: s, label: labelMap[s] || s, count: counts[s], pct: rows.length ? Math.round(counts[s] / rows.length * 1000) / 10 : 0, color: colorMap[s] || 'neutral' };
          });
        });
    },


    getExtractionMetrics: function () {
      // Entity set confirmed: vafe_extractionresults
      // VERIFY column logical names:
      //   vafe_overallconfidencescore (decimal), vafe_processingtimems (whole number),
      //   vafe_fieldconfidencescores (text/JSON — parse below once column name confirmed)
      return retrieveMultiple(
        'vafe_extractionresults',
        'vafe_overallconfidencescore,vafe_processingtimems,vafe_fieldconfidencescores',
        null,
        5000
      ).then(function (rows) {
        var confSum = 0, timeSum = 0, timeCount = 0;
        var t = { auto: 0, review: 0, manual: 0, rejected: 0 };
        var fieldCounts = {};
        rows.forEach(function (r) {
          var c = r.vafe_overallconfidencescore;
          if (c != null) { confSum += c; if (c >= 95) { t.auto++; } else if (c >= 85) { t.review++; } else if (c >= 60) { t.manual++; } else { t.rejected++; } }
          if (r.vafe_processingtimems) { timeSum += r.vafe_processingtimems; timeCount++; }
          var rawFieldConfidence = r.vafe_fieldconfidencescores || r.vafe_field_confidence_scores || '{}';
          try {
            var fc = JSON.parse(rawFieldConfidence);
            Object.keys(fc).forEach(function (k) {
              if (k === 'layoutConfidence') { return; }
              var score = Number(fc[k]);
              if (!isNaN(score) && score < 95) {
                fieldCounts[k] = (fieldCounts[k] || 0) + 1;
              }
            });
          } catch (_) {
            // Ignore malformed confidence payloads and continue processing remaining rows.
          }
        });
        var total = rows.length || 1;
        if (!Object.keys(fieldCounts).length) {
          // Ensure money fields still appear as watch items when confidence payloads are not populated yet.
          ['totalAmountClaimed', 'ExpenseA_Amount', 'ExpenseB_Amount', 'ExpenseC_Amount', 'ExpenseD_Amount'].forEach(function (f) {
            fieldCounts[f] = fieldCounts[f] || 0;
          });
        }
        return {
          totalExtracted: rows.length,
          avgConfidence: Math.round(confSum / total * 10) / 10,
          avgProcessingTimeSec: timeCount ? Math.round(timeSum / timeCount / 100) / 10 : 0,
          tiers: [
            { label: '≥ 95% — Auto-approved',   count: t.auto,     pct: Math.round(t.auto     / total * 1000) / 10, color: 'success'  },
            { label: '85–94% — Review required', count: t.review,   pct: Math.round(t.review   / total * 1000) / 10, color: 'warning'  },
            { label: '60–84% — Manual review',   count: t.manual,   pct: Math.round(t.manual   / total * 1000) / 10, color: 'high'     },
            { label: '< 60% — Rejected',         count: t.rejected, pct: Math.round(t.rejected / total * 1000) / 10, color: 'danger'   }
          ],
          topFlaggedFields: Object.keys(fieldCounts)
            .sort(function (a, b) { return fieldCounts[b] - fieldCounts[a]; })
            .slice(0, 6)
            .map(function (f) { return { field: f, count: fieldCounts[f] }; })
        };
      });
    },

    getWriteEventSummary: function () {
      // Entity set confirmed: vafe_d365writeevents
      // VERIFY column logical names:
      //   vafe_status (choice: Success/Failure/PermanentFailure), vafe_retrycount (whole number), vafe_writetimems (whole number)
      return retrieveMultiple(
        'vafe_d365writeevents',
        'vafe_status,vafe_retrycount,vafe_writetimems',
        null,
        5000
      ).then(function (rows) {
        var s = { totalAttempted: rows.length, successCount: 0, failedResolved: 0, failedPendingRetry: 0, permanentFailure: 0, avgWriteTimeMs: 0 };
        var timeSum = 0, timeCount = 0;
        rows.forEach(function (r) {
          if (r.vafe_status === 'Success')          { s.successCount++; }
          if (r.vafe_status === 'Failure' && r.vafe_retrycount < 3)  { s.failedPendingRetry++; }
          if (r.vafe_status === 'PermanentFailure') { s.permanentFailure++; }
          if (r.vafe_writetimems) { timeSum += r.vafe_writetimems; timeCount++; }
        });
        s.failedResolved = s.totalAttempted - s.successCount - s.failedPendingRetry - s.permanentFailure;
        s.successRatePct = s.totalAttempted ? Math.round(s.successCount / s.totalAttempted * 1000) / 10 : 0;
        s.avgWriteTimeMs = timeCount ? Math.round(timeSum / timeCount) : 0;
        var retryTotal = s.failedResolved + s.failedPendingRetry + s.permanentFailure;
        s.retrySuccessRatePct = retryTotal ? Math.round(s.failedResolved / retryTotal * 1000) / 10 : 0;
        return s;
      });
    },

    getDailyVolume: function () {
      // Entity set confirmed: vafe_formsubmissions
      // Note: Dataverse OData does not support date-grouping; grouping client-side here.
      // VERIFY: vafe_submissiondate column name; vafe_formid is used only as a marker (not actually needed — can remove if causing issues)
      var cutoff = new Date(Date.now() - 7 * 86400000).toISOString();
      return retrieveMultiple(
        'vafe_formsubmissions',
        'vafe_formid,vafe_status,vafe_submissiondate',
        'vafe_submissiondate ge ' + cutoff,
        5000,
        'vafe_submissiondate asc'
      ).then(function (rows) {
        var days = {};
        rows.forEach(function (r) {
          var d = (r.vafe_submissiondate || '').split('T')[0];
          if (!d) { return; }
          if (!days[d]) { days[d] = { submitted: 0, written: 0, failed: 0 }; }
          days[d].submitted++;
          if (r.vafe_status === 'Written')  { days[d].written++; }
          if (r.vafe_status === 'Failed' || r.vafe_status === 'PermanentFailure') { days[d].failed++; }
        });
        return Object.keys(days).sort().map(function (d) {
          var dt = new Date(d);
          var label = dt.toLocaleDateString('en-US', { weekday: 'short', day: 'numeric' });
          return { date: d, label: label, submitted: days[d].submitted, written: days[d].written, failed: days[d].failed };
        });
      });
    }
  };

  /* ── Active provider ───────────────────────────────────── */
  var activeProvider = useMock ? MockProvider : DataverseProvider;

  /* ── Public API ────────────────────────────────────────── */
  return {
    setProvider: function (name) {
      activeProvider = (name === 'dataverse') ? DataverseProvider : MockProvider;
    },
    isMock:  function () { return activeProvider === MockProvider; },
    getXrm:  resolveXrm,

    getProcessingStats:   function () { return activeProvider.getProcessingStats(); },
    getStatusPipeline:    function () { return activeProvider.getStatusPipeline(); },
    getExtractionMetrics: function () { return activeProvider.getExtractionMetrics(); },
    getWriteEventSummary: function () { return activeProvider.getWriteEventSummary(); },
    getDailyVolume:       function () { return activeProvider.getDailyVolume(); }
  };

}());
