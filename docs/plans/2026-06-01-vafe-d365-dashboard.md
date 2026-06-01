# VAFE D365 Dashboard Web Resource Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a management-grade executive/operations dashboard as a Dynamics 365 HTML web resource for the VA Form 10-3542 extraction pipeline project.

**Architecture:** Six-file web resource bundle: HTML shell + CSS + three JS modules (data adapter, export, main app). Data adapter supports mock mode for local preview and Dataverse Web API mode for D365 production. All files are CSP-safe with no inline JS or external CDN dependencies.

**Tech Stack:** Vanilla HTML5, CSS3 (custom properties, grid, flexbox), plain ES2017 JS modules pattern (IIFE namespacing for web resource compat), Dataverse Web API REST, Xrm client API context.

**Output directory:** `solution-src/VAFormExtractionDemo/WebResources/`

---

### Task 1: vafe_report.css

**Files:**
- Create: `solution-src/VAFormExtractionDemo/WebResources/vafe_report.css`

Design tokens, layout grid, executive/operations mode, phase/gate cards, blocker badges, team roster, data/compliance table, decision register, action plan table, print stylesheet, responsive 390px–desktop.

---

### Task 2: vafe_data_adapter.js

**Files:**
- Create: `solution-src/VAFormExtractionDemo/WebResources/vafe_data_adapter.js`

Mock provider seeded with full project context. Dataverse provider with TODO mapping stubs for all 8 adapter functions. Normalized schema shared by both providers. Xrm context discovery (parent.Xrm → window.Xrm → graceful error). Provider toggle via `VAFE_CONFIG.useMock`.

---

### Task 3: vafe_export.js

**Files:**
- Create: `solution-src/VAFormExtractionDemo/WebResources/vafe_export.js`

`printReport()` — triggers browser print dialog. `exportActionsCsv(actions)` — builds RFC 4180 CSV blob and triggers download anchor. No external deps.

---

### Task 4: vafe_report.js

**Files:**
- Create: `solution-src/VAFormExtractionDemo/WebResources/vafe_report.js`

Main app: init, render pipeline, filter state, delivery confidence score calculation, blocker impact index, owner load score, expand/collapse drawers, view toggle (exec ↔ ops). Calls data adapter and export module via global namespaces.

---

### Task 5: vafe_report.html

**Files:**
- Create: `solution-src/VAFormExtractionDemo/WebResources/vafe_report.html`

HTML5 shell with semantic landmarks (header, main, nav, section, footer). Eight UI sections. Filter bar. View-toggle and export buttons. Script and link tags referencing sibling web resources. No inline JS, no inline event handlers, no external CDN.

---

### Task 6: vafe_readme.md

**Files:**
- Create: `solution-src/VAFormExtractionDemo/WebResources/vafe_readme.md`

D365 upload instructions, naming convention, form/dashboard embedding, mock→Dataverse switch, adapter mapping table, CSP decisions log.
