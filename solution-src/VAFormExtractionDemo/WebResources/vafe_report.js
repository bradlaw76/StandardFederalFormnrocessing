/* =============================================================
   VAFE Report — Operational Form Processing Dashboard
   VA Form 10-3542 Extraction Pipeline | D365 Model-Driven App
   ============================================================= */

/* global VAFE_DATA, VAFE_EXPORT */

var VAFE_APP = (function () {
  'use strict';

  /* ── State ──────────────────────────────────────────────── */
  var state = {
    mode:       'executive',
    isMock:     true,
    stats:      null,
    pipeline:   [],
    metrics:    null,
    writeEvents: null,
    dailyVolume: []
  };

  /* ── Helpers ────────────────────────────────────────────── */
  function esc(v) {
    if (v === null || v === undefined) { return ''; }
    return String(v)
      .replace(/&/g,'&amp;').replace(/</g,'&lt;')
      .replace(/>/g,'&gt;').replace(/"/g,'&quot;');
  }

  function fmt(dateStr, opts) {
    if (!dateStr) { return '—'; }
    try {
      return new Date(dateStr).toLocaleString('en-US', opts || { month:'short', day:'numeric', hour:'2-digit', minute:'2-digit' });
    } catch (_) { return dateStr; }
  }

  function fmtDate(dateStr) {
    return fmt(dateStr, { month:'short', day:'numeric', year:'numeric' });
  }

  function badge(text, cls) {
    return '<span class="badge badge--' + esc(cls) + '">' + esc(text) + '</span>';
  }

  function statusBadge(status) {
    var m = {
      'Intake':      ['Intake',      'not-started'],
      'Extracting':  ['Extracting',  'in-progress'],
      'Extracted':   ['Extracted',   'in-progress'],
      'Correcting':  ['In Review',   'at-risk'    ],
      'Corrected':   ['Corrected',   'pending'    ],
      'Writing':     ['Writing',     'in-progress'],
      'Written':     ['Written',     'complete'   ],
      'Failed':      ['Failed',      'blocked'    ],
      'PermanentFailure': ['Perm. Failed', 'blocked'],
      'RetryPending':['Retry…',      'at-risk'    ]
    };
    var e = m[status] || [status, 'not-started'];
    return badge(e[0], e[1]);
  }

  function conf(v) {
    if (v === null || v === undefined) { return '—'; }
    return esc(v.toFixed(1)) + '%';
  }

  /* ── Pipeline colour map ────────────────────────────────── */
  var pipelineColorMap = {
    'neutral': 'var(--color-neutral-60)',
    'primary': 'var(--color-primary)',
    'warning': 'var(--color-badge-high)',
    'accent':  'var(--color-accent-teal)',
    'success': 'var(--color-success)',
    'danger':  'var(--color-badge-critical)',
    'high':    'var(--color-badge-high)'
  };

  /* ────────────────────────────────────────────────────────────
     RENDER: §1 Processing KPIs
     ────────────────────────────────────────────────────────── */
  function renderKPIs() {
    var s = state.stats;
    if (!s) { return ''; }

    var confCls = s.avgConfidence >= 90 ? 'success' : s.avgConfidence >= 80 ? 'warning' : 'danger';
    var writtenPct = s.totalAllTime ? Math.round(s.writtenAllTime / s.totalAllTime * 100) : 0;

    return [
      '<div class="kpi-grid">',

      kpi('Forms Today',         s.totalToday,           s.totalThisWeek + ' this week',        'neutral'),
      kpi('Written to D365',     s.writtenAllTime,        s.writtenToday + ' today',             'success'),
      kpi('In Review',           s.inReview,              '4-hr SLA — forms in Correcting state', s.inReview > 10 ? 'warning' : 'neutral'),
      kpi('Currently Processing',s.currentlyProcessing,   'Extracting + Writing',                'neutral'),
      kpi('Failed / Error',      s.failed,                'Permanent + pending retry',           s.failed > 0 ? 'danger' : 'success'),
      kpiConf('Avg Extraction Confidence', s.avgConfidence, s.autoApprovalRatePct + '% auto-approved', confCls),
      kpi('Completion Rate',     writtenPct + '%',        s.writtenAllTime + ' of ' + s.totalAllTime + ' total', writtenPct >= 70 ? 'success' : 'warning'),
      kpi('Avg Processing Time', s.avgProcessingTimeSec + 's', 'Target < 5s', s.avgProcessingTimeSec < 5 ? 'success' : 'danger'),

      '</div>'
    ].join('');
  }

  function kpi(label, value, sub, variant) {
    return [
      '<div class="kpi-card kpi-card--' + esc(variant) + '" role="article">',
        '<span class="kpi-card__label">' + esc(label) + '</span>',
        '<div class="kpi-card__value kpi-card__value--large">' + esc(value) + '</div>',
        '<span class="kpi-card__sub">' + esc(sub) + '</span>',
      '</div>'
    ].join('');
  }

  function kpiConf(label, value, sub, variant) {
    var cls = variant === 'success' ? 'high' : variant === 'warning' ? 'medium' : 'low';
    return [
      '<div class="kpi-card kpi-card--' + esc(variant) + '" role="article">',
        '<span class="kpi-card__label">' + esc(label) + '</span>',
        '<div class="kpi-card__value kpi-card__value--large kpi-card__value--' + esc(variant) + '">' + esc(value) + '<span style="font-size:var(--font-size-sm);font-weight:400">%</span></div>',
        '<div class="confidence-gauge"><div class="confidence-gauge__fill confidence-gauge__fill--' + cls + '" style="width:' + esc(value) + '%"></div></div>',
        '<span class="kpi-card__sub">' + esc(sub) + '</span>',
      '</div>'
    ].join('');
  }

  /* ────────────────────────────────────────────────────────────
     RENDER: §2 Status Pipeline
     ────────────────────────────────────────────────────────── */
  function renderPipeline() {
    var stages = state.pipeline;
    if (!stages.length) { return ''; }
    var total = stages.reduce(function (a, s) { return a + s.count; }, 0) || 1;

    var cells = stages.map(function (s, i) {
      var color  = pipelineColorMap[s.color] || 'var(--color-neutral-60)';
      var isLast = i === stages.length - 1;
      return [
        '<div class="pipeline-stage pipeline-stage--' + esc(s.color) + '" role="listitem" aria-label="' + esc(s.label) + ': ' + esc(s.count) + '">',
          '<div class="pipeline-stage__count" style="color:' + color + '">' + esc(s.count) + '</div>',
          '<div class="pipeline-stage__label">' + esc(s.label) + '</div>',
          '<div class="pipeline-stage__pct">' + esc(s.pct) + '%</div>',
        '</div>',
        isLast ? '' : '<div class="pipeline-arrow" aria-hidden="true">›</div>'
      ].join('');
    }).join('');

    return '<div class="pipeline-track" role="list" aria-label="Form status pipeline">' + cells + '</div>';
  }

  /* ────────────────────────────────────────────────────────────
     RENDER: §3 Extraction Metrics
     ────────────────────────────────────────────────────────── */
  function renderExtractionMetrics() {
    var m = state.metrics;
    if (!m) { return '<p class="no-results">Metrics unavailable.</p>'; }

    var tierBars = (m.tiers || []).map(function (t) {
      var color = pipelineColorMap[t.color] || 'var(--color-neutral-60)';
      return [
        '<div class="tier-row">',
          '<span class="tier-row__label">' + esc(t.label) + '</span>',
          '<div class="tier-row__bar-wrap">',
            '<div class="tier-row__bar" style="width:' + esc(t.pct) + '%;background:' + color + '" role="progressbar" aria-valuenow="' + esc(t.pct) + '" aria-valuemin="0" aria-valuemax="100"></div>',
          '</div>',
          '<span class="tier-row__count">' + esc(t.count) + ' <small>(' + esc(t.pct) + '%)</small></span>',
        '</div>'
      ].join('');
    }).join('');

    var fieldRows = (m.topFlaggedFields || []).map(function (f, i) {
      var pct = m.totalExtracted ? Math.round(f.count / m.totalExtracted * 100) : 0;
      return [
        '<tr>',
          '<td>' + esc(i + 1) + '</td>',
          '<td><code>' + esc(f.field) + '</code></td>',
          '<td>' + esc(f.count) + '</td>',
          '<td><div class="progress-bar" style="width:120px;display:inline-block"><div class="progress-bar__fill" style="width:' + esc(pct) + '%"></div></div></td>',
        '</tr>'
      ].join('');
    }).join('');

    return [
      '<div style="display:grid;grid-template-columns:1fr 1fr;gap:var(--space-4)">',
        '<div>',
          '<h3 class="section-heading" style="font-size:var(--font-size-sm)">Confidence Tier Distribution</h3>',
          '<p style="font-size:var(--font-size-xs);color:var(--color-neutral-60);margin-bottom:var(--space-3)">',
            esc(m.totalExtracted) + ' forms extracted · avg ' + conf(m.avgConfidence) + ' · avg ' + esc(m.avgProcessingTimeSec.toFixed(1)) + 's',
          '</p>',
          '<div class="tier-chart">' + tierBars + '</div>',
        '</div>',
        '<div>',
          '<h3 class="section-heading" style="font-size:var(--font-size-sm)">Top Flagged Fields</h3>',
          '<p style="font-size:var(--font-size-xs);color:var(--color-neutral-60);margin-bottom:var(--space-3)">Fields most often below confidence threshold</p>',
          '<div class="data-table-wrap">',
            '<table class="data-table" aria-label="Top flagged fields">',
              '<thead><tr><th>#</th><th>Field</th><th>Count</th><th>Frequency</th></tr></thead>',
              '<tbody>' + fieldRows + '</tbody>',
            '</table>',
          '</div>',
        '</div>',
      '</div>'
    ].join('');
  }

  /* ────────────────────────────────────────────────────────────
     RENDER: §6 D365 Write Events
     ────────────────────────────────────────────────────────── */
  function renderWriteEvents() {
    var w = state.writeEvents;
    if (!w) { return '<p class="no-results">Write event data unavailable.</p>'; }

    var successColor = w.successRatePct >= 95 ? 'success' : w.successRatePct >= 80 ? 'warning' : 'danger';
    var retryColor   = w.retrySuccessRatePct >= 80 ? 'success' : w.retrySuccessRatePct >= 60 ? 'warning' : 'danger';

    return [
      '<div class="kpi-grid" style="grid-template-columns:repeat(auto-fit,minmax(140px,1fr))">',
        kpi('Attempted',       w.totalAttempted,       '',                            'neutral'),
        kpi('Succeeded',       w.successCount,         '',                            'success'),
        kpi('Success Rate',    w.successRatePct + '%', 'Target ≥ 95%',               successColor),
        kpi('Pending Retry',   w.failedPendingRetry,   'MaxRetry = 3',               w.failedPendingRetry > 0 ? 'warning' : 'neutral'),
        kpi('Perm. Failed',    w.permanentFailure,     'Retry limit reached',        w.permanentFailure > 0 ? 'danger' : 'neutral'),
        kpi('Retry Success',   w.retrySuccessRatePct + '%', 'of retried writes',     retryColor),
        kpi('Avg Write Time',  w.avgWriteTimeMs + 'ms', 'Target < 2000ms',           w.avgWriteTimeMs < 2000 ? 'success' : 'danger'),
      '</div>'
    ].join('');
  }

  /* ────────────────────────────────────────────────────────────
     RENDER: §5 Daily Volume (CSS bar chart)
     ────────────────────────────────────────────────────────── */
  function renderDailyVolume() {
    var vol = state.dailyVolume;
    if (!vol.length) { return '<p class="no-results">No volume data.</p>'; }

    var maxSubmitted = Math.max.apply(null, vol.map(function (d) { return d.submitted; })) || 1;

    var bars = vol.map(function (d) {
      var subPct  = Math.round(d.submitted / maxSubmitted * 100);
      var writePct = d.submitted ? Math.round(d.written   / d.submitted * subPct) : 0;
      var failPct  = d.submitted ? Math.round(d.failed    / d.submitted * subPct) : 0;
      return [
        '<div class="vol-bar-group" aria-label="' + esc(d.label) + ': ' + esc(d.submitted) + ' submitted">',
          '<div class="vol-bar-stack">',
            '<div class="vol-bar vol-bar--success" style="height:' + esc(writePct) + '%" title="Written: ' + esc(d.written) + '"></div>',
            '<div class="vol-bar vol-bar--warning" style="height:' + esc(subPct - writePct - failPct) + '%" title="In progress/review"></div>',
            failPct ? '<div class="vol-bar vol-bar--danger"  style="height:' + esc(failPct) + '%" title="Failed: ' + esc(d.failed) + '"></div>' : '',
          '</div>',
          '<div class="vol-bar__label">' + esc(d.label) + '</div>',
          '<div class="vol-bar__count">' + esc(d.submitted) + '</div>',
        '</div>'
      ].join('');
    }).join('');

    return [
      '<div class="vol-chart" aria-label="Daily submission volume">',
        bars,
      '</div>',
      '<div class="vol-legend">',
        '<span class="vol-legend__item vol-legend__item--success">Written to D365</span>',
        '<span class="vol-legend__item vol-legend__item--warning">In Review / Processing</span>',
        '<span class="vol-legend__item vol-legend__item--danger">Failed</span>',
      '</div>'
    ].join('');
  }

  /* ── Section setter ─────────────────────────────────────── */
  function setSection(id, html) {
    var el = document.getElementById(id);
    if (el) { el.innerHTML = html; }
  }

  /* ── Render all ─────────────────────────────────────────── */
  function renderAll() {
    setSection('section-kpis',     renderKPIs());
    setSection('section-pipeline', renderPipeline());
    setSection('section-metrics',  renderExtractionMetrics());
    setSection('section-writes',   renderWriteEvents());
    setSection('section-volume',   renderDailyVolume());
    updateMockBanner();
  }


  /* ── Mock / Xrm banner ──────────────────────────────────── */
  function updateMockBanner() {
    var el = document.getElementById('data-source-banner');
    if (!el) { return; }
    if (state.isMock) {
      el.className  = 'status-banner status-banner--mock';
      el.textContent = 'Mock data — displaying representative form processing data. Set VAFE_CONFIG.useMock = false to connect to live Dataverse (vafe_formsubmission, vafe_extractionresult, vafe_d365writeevent).';
      el.removeAttribute('hidden');
    } else {
      var xrm = VAFE_DATA.getXrm();
      if (!xrm) {
        el.className  = 'status-banner status-banner--warn';
        el.textContent = 'Xrm context unavailable — live data may not load correctly outside Dynamics 365.';
        el.removeAttribute('hidden');
      } else {
        el.setAttribute('hidden', 'true');
      }
    }
  }

  /* ── Loading / error ────────────────────────────────────── */
  function showLoading() {
    setSection('section-kpis', '<div class="loading-overlay"><div class="spinner"></div><span>Loading form processing data…</span></div>');
  }

  function showError(msg) {
    var html = '<div class="status-banner status-banner--error" role="alert"><strong>Error:</strong> ' + esc(msg) + '</div>';
    setSection('section-kpis', html);
  }

  /* ── Drawer toggle ──────────────────────────────────────── */
  function toggleDrawer(target) {
    var header = target.closest('[data-drawer]');
    if (!header) { return; }
    var card   = header.parentElement;
    var isOpen = card.classList.contains('blocker-card--expanded');
    card.classList.toggle('blocker-card--expanded', !isOpen);
    header.setAttribute('aria-expanded', String(!isOpen));
  }

  /* ── View mode ──────────────────────────────────────────── */
  function setViewMode(mode) {
    state.mode = mode;
    document.body.classList.toggle('ops-mode', mode === 'operations');
    ['btn-exec-view','btn-ops-view'].forEach(function (id) {
      var el = document.getElementById(id);
      if (!el) { return; }
      var active = (id === 'btn-exec-view') ? (mode === 'executive') : (mode === 'operations');
      el.setAttribute('aria-pressed', String(active));
      el.classList.toggle('active', active);
    });
    var footer = document.getElementById('footer-mode');
    if (footer) { footer.textContent = mode === 'operations' ? 'Operations View' : 'Executive View'; }
  }

  /* ── Event binding ──────────────────────────────────────── */
  function bindEvents() {
    document.addEventListener('click', function (e) {
      var t = e.target;
      if (t.id === 'btn-exec-view')    { setViewMode('executive');   return; }
      if (t.id === 'btn-ops-view')     { setViewMode('operations');  return; }
      if (t.id === 'btn-print') { VAFE_EXPORT.printReport(); return; }
      toggleDrawer(t);
    });
    document.addEventListener('keydown', function (e) {
      if ((e.key === 'Enter' || e.key === ' ') && e.target.closest('[data-drawer]')) {
        e.preventDefault();
        toggleDrawer(e.target);
      }
    });
  }


  /* ── Data load ──────────────────────────────────────────── */
  function loadData() {
    showLoading();
    state.isMock = VAFE_DATA.isMock();

    return Promise.all([
      VAFE_DATA.getProcessingStats(),
      VAFE_DATA.getStatusPipeline(),
      VAFE_DATA.getExtractionMetrics(),
      VAFE_DATA.getWriteEventSummary(),
      VAFE_DATA.getDailyVolume()
    ]).then(function (r) {
      state.stats       = r[0];
      state.pipeline    = r[1];
      state.metrics     = r[2];
      state.writeEvents = r[3];
      state.dailyVolume = r[4];
      renderAll();
    }).catch(function (err) {
      showError(err && err.message ? err.message : 'Failed to load data.');
    });
  }

  /* ── Init ───────────────────────────────────────────────── */
  function init() {
    var dateEl = document.getElementById('report-date');
    if (dateEl) {
      dateEl.textContent = new Date().toLocaleDateString('en-US', { weekday:'short', year:'numeric', month:'short', day:'numeric' });
    }
    bindEvents();
    loadData();
  }

  return {
    init:        init,
    reload:      loadData,
    getState:    function () { return state; },
    setProvider: function (name) { VAFE_DATA.setProvider(name); loadData(); }
  };

}());

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', function () { VAFE_APP.init(); });
} else {
  VAFE_APP.init();
}
