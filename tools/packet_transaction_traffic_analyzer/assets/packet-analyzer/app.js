(function () {
  "use strict";

  const root = document.getElementById("app");
  if (!root) {
    return;
  }

  const urlParams = new URLSearchParams(window.location.search);
  const debugMode = urlParams.get("debug") === "1";
  const persistentScrollbars = true;
  const manifest = window.__PACKET_ANALYZER_MANIFEST__ || {};
  const CASE_CATALOG = Array.isArray(window.__PACKET_ANALYZER_CASE_CATALOG__) ? window.__PACKET_ANALYZER_CASE_CATALOG__ : [];
  const laneInfoMap = new Map((manifest.lanes || []).map((lane) => [String(lane.lane), lane]));
  const laneDataMap = new Map();
  const laneLoadPromises = new Map();
  const loadedScripts = new Set();
  const rowMap = new Map();
  const waveChunkCache = new Map();
  const WAVE_VISIBLE_SLOT_STEPS = [8, 12, 16, 24, 32, 48, 64, 96, 128, 192, 256, 384, 512, 768, 1024];
  const STRUCTURAL_RENDER_INTENTS = new Set([
    "row-toggle",
    "surface-switch",
    "tab-switch",
    "filter-change",
    "lane-change",
    "source-change",
    "wave-focus",
    "layout-change",
  ]);

  const tooltipEl = document.createElement("div");
  tooltipEl.className = "tooltip";
  tooltipEl.hidden = true;
  document.body.appendChild(tooltipEl);

  const menuEl = document.createElement("div");
  menuEl.className = "context-menu";
  menuEl.hidden = true;
  document.body.appendChild(menuEl);

  const debugState = {
    enabled: debugMode,
    bootState: "init",
    renderCount: 0,
    actions: [],
    errors: [],
    laneLoads: [],
  };

  const FAMILY_ORDER = (manifest.families || []).map((family) => family.id);
  const FAMILY_LABELS = Object.fromEntries((manifest.families || []).map((family) => [family.id, family.label]));
  const SECTION_ORDER = ["ingress", "egress", "dma"];
  const SECTION_LABELS = {
    all: "All Sections",
    ingress: "Ingress",
    egress: "Egress",
    dma: "DMA",
  };
  const PREF_KEY = "packet-analyzer-field-prefs:v3";

  const state = {
    lane: String(manifest.meta && manifest.meta.defaultLane != null ? manifest.meta.defaultLane : ((manifest.lanes || [])[0] || {}).lane || -1),
    decodeMode: (manifest.meta && manifest.meta.defaultDecodeMode) || "mu3e-spec",
    surfaceMode: "trace",
    waveSourceId: "",
    frameFilter: "",
    sectionFilter: "all",
    viewTab: "spec",
    specMode: "hex",
    detailsRadix: "hex",
    updateMode: "click",
    trackerFormat: "fields",
    trackerDensity: "1x",
    trackerSync: true,
    wrap: false,
    familyFilters: Object.fromEntries(FAMILY_ORDER.map((family) => [family, true])),
    expandedRows: new Set(),
    selectedRowId: "",
    selectedWordId: "",
    selectedFieldId: "",
    zeroTimePsByLane: {},
    fieldPrefs: {},
    lastScrollTopByLane: {},
    lastScrollLeftByLane: {},
    lastSideScrollTopByTab: {},
    lastSideScrollLeftByTab: {},
    lastWaveScrollTopByKey: {},
    waveScrollRestore: null,
    loadingLane: null,
    fatalError: "",
    wavePanelState: {},
    sharedWaveState: {},
    pendingFieldSync: null,
    pendingWaveSync: null,
    flashFieldKey: "",
    flashRowId: "",
  };

  let menuState = null;
  let holdTimer = null;
  let holdTriggered = false;
  let scrollRaf = 0;
  let waveRenderRaf = 0;
  let fieldSyncRaf = 0;
  let fieldFlashTimer = 0;
  let fieldSyncSettleTimer = 0;
  let traceCenterTimer = 0;
  let sideCenterTimer = 0;
  let waveSelectionHighlightTimer = 0;
  let scrollbarSyncRaf = 0;
  let waveRenderToken = 0;
  let activeWaveLinkKey = "";
  let scrollDragState = null;
  let waveRangeDragState = null;
  let suppressNextWaveClick = false;
  let uiTransitionToken = 0;
  let waveSelectionRequestToken = 0;

  bindEvents();
  bindGlobalErrorCapture();
  exposeDebug();
  seedGlobalRows((manifest.meta && manifest.meta.globalPackets) || []);
  void bootstrap();

  async function bootstrap() {
    debugState.bootState = "loading";
    render();
    try {
      await ensureLaneData(state.lane);
      state.sharedWaveState = {};
      debugState.bootState = "ready";
      state.fieldPrefs = loadFieldPrefs();
      ensureSelection();
      ensureSelectedField(selectedPacket());
      render("selection");
      void preloadOtherLanes();
    } catch (error) {
      noteError(error);
      state.fatalError = error instanceof Error ? error.message : String(error);
      debugState.bootState = "error";
      render();
    }
  }

  function bindGlobalErrorCapture() {
    window.addEventListener("error", (event) => {
      noteError(event.error || event.message || "Unknown window error");
    });
    window.addEventListener("unhandledrejection", (event) => {
      noteError(event.reason || "Unhandled promise rejection");
    });
  }

  function noteError(error) {
    const message = error instanceof Error ? error.stack || error.message : String(error);
    debugState.errors.push({
      time: new Date().toISOString(),
      message: message,
    });
  }

  function recordAction(action, detail) {
    debugState.actions.unshift({
      time: new Date().toISOString(),
      action: action,
      detail: detail || "",
    });
    debugState.actions = debugState.actions.slice(0, 24);
  }

  function motionReduced() {
    return typeof window.matchMedia === "function" && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  }

  function normalizeRenderIntent(intent) {
    return String(intent || "")
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "");
  }

  function rootClassName(renderIntent) {
    const classes = [];
    if (persistentScrollbars) {
      classes.push("has-persistent-scrollbars");
    }
    if (renderIntent) {
      classes.push("render-intent-" + renderIntent);
    }
    return classes.join(" ");
  }

  function animationKey(prefix, value) {
    const suffix = String(value == null || value === "" ? "default" : value)
      .replace(/[^a-zA-Z0-9_-]+/g, "-")
      .replace(/^-+|-+$/g, "") || "default";
    return prefix + "-" + suffix;
  }

  function shouldAnimateRenderIntent(renderIntent) {
    return !!renderIntent && STRUCTURAL_RENDER_INTENTS.has(renderIntent) && !motionReduced() && root.childElementCount > 0;
  }

  function shouldCaptureAnimatedNode(node, rect) {
    if (!rect || rect.width < 1 || rect.height < 1) {
      return false;
    }
    const role = node.getAttribute("data-anim-role") || "";
    if (role === "trace-row") {
      return rect.bottom >= -64 && rect.top <= window.innerHeight + 64;
    }
    return rect.bottom >= -128 && rect.top <= window.innerHeight + 128 && rect.right >= -128 && rect.left <= window.innerWidth + 128;
  }

  function captureUiSnapshot(renderIntent) {
    if (!shouldAnimateRenderIntent(renderIntent)) {
      return null;
    }
    const entries = new Map();
    root.querySelectorAll("[data-anim-key]").forEach((node) => {
      const key = node.getAttribute("data-anim-key") || "";
      if (!key) {
        return;
      }
      const rect = node.getBoundingClientRect();
      if (!shouldCaptureAnimatedNode(node, rect)) {
        return;
      }
      entries.set(key, {
        key: key,
        role: node.getAttribute("data-anim-role") || "",
        rect: {
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
        },
        clone: node.cloneNode(true),
      });
    });
    return {
      intent: renderIntent,
      entries: entries,
    };
  }

  function transitionDuration(intent, role) {
    if (role === "trace-row") {
      return intent === "row-toggle" ? 240 : 210;
    }
    if (role === "surface" || role === "side-view") {
      return 260;
    }
    return 220;
  }

  function transitionDelay(node, role) {
    if (role === "trace-row") {
      const depth = Number(node.style.getPropertyValue("--trace-depth")) || 0;
      return Math.min(72, depth * 18);
    }
    return 0;
  }

  function matchedFrames(oldRect, newRect) {
    const dx = oldRect.left - newRect.left;
    const dy = oldRect.top - newRect.top;
    const sx = oldRect.width / Math.max(1, newRect.width);
    const sy = oldRect.height / Math.max(1, newRect.height);
    return {
      dx: dx,
      dy: dy,
      sx: Number.isFinite(sx) ? sx : 1,
      sy: Number.isFinite(sy) ? sy : 1,
    };
  }

  function animateMatchedElement(node, oldEntry, intent) {
    const newRect = node.getBoundingClientRect();
    if (!shouldCaptureAnimatedNode(node, newRect)) {
      return;
    }
    const frames = matchedFrames(oldEntry.rect, newRect);
    if (Math.abs(frames.dx) < 1 && Math.abs(frames.dy) < 1 && Math.abs(frames.sx - 1) < 0.01 && Math.abs(frames.sy - 1) < 0.01) {
      return;
    }
    node.animate(
      [
        {
          transformOrigin: "top left",
          transform: `translate(${frames.dx}px, ${frames.dy}px) scale(${frames.sx}, ${frames.sy})`,
          opacity: oldEntry.role === "trace-row" ? 0.92 : 0.86,
        },
        {
          transformOrigin: "top left",
          transform: "translate(0px, 0px) scale(1, 1)",
          opacity: 1,
        },
      ],
      {
        duration: transitionDuration(intent, oldEntry.role),
        delay: transitionDelay(node, oldEntry.role),
        easing: "cubic-bezier(0.22, 1, 0.36, 1)",
      }
    );
  }

  function enterFrames(role, intent) {
    if (role === "trace-row") {
      return [
        { opacity: 0, transform: "translateY(-12px) scale(0.985)" },
        { opacity: 1, transform: "translateY(0px) scale(1)" },
      ];
    }
    if (role === "side-view") {
      const offset = intent === "tab-switch" ? 18 : 10;
      return [
        { opacity: 0, transform: `translateX(${offset}px) scale(0.99)` },
        { opacity: 1, transform: "translateX(0px) scale(1)" },
      ];
    }
    if (role === "surface") {
      return [
        { opacity: 0, transform: "translateY(16px) scale(0.992)" },
        { opacity: 1, transform: "translateY(0px) scale(1)" },
      ];
    }
    if (role === "wave-panel") {
      return [
        { opacity: 0, transform: "translateY(12px) scale(0.992)" },
        { opacity: 1, transform: "translateY(0px) scale(1)" },
      ];
    }
    return [
      { opacity: 0, transform: "translateY(8px)" },
      { opacity: 1, transform: "translateY(0px)" },
    ];
  }

  function exitFrames(role, intent) {
    if (role === "trace-row") {
      return [
        { opacity: 1, transform: "translateY(0px) scale(1)" },
        { opacity: 0, transform: "translateY(-10px) scale(0.985)" },
      ];
    }
    if (role === "side-view") {
      const offset = intent === "tab-switch" ? -18 : -10;
      return [
        { opacity: 1, transform: "translateX(0px) scale(1)" },
        { opacity: 0, transform: `translateX(${offset}px) scale(0.99)` },
      ];
    }
    return [
      { opacity: 1, transform: "translateY(0px) scale(1)" },
      { opacity: 0, transform: "translateY(-12px) scale(0.992)" },
    ];
  }

  function sanitizeGhostClone(node) {
    if (!(node instanceof Element)) {
      return;
    }
    node.removeAttribute("id");
    node.querySelectorAll("[id]").forEach((child) => child.removeAttribute("id"));
    [node].concat(Array.from(node.querySelectorAll("[data-row-id], [data-anim-key], [data-anim-role], [data-panel-id], [data-action], [data-role], [data-scroll-sync], [data-word-field-key]"))).forEach((child) => {
      child.removeAttribute("data-row-id");
      child.removeAttribute("data-anim-key");
      child.removeAttribute("data-anim-role");
      child.removeAttribute("data-panel-id");
      child.removeAttribute("data-action");
      child.removeAttribute("data-role");
      child.removeAttribute("data-scroll-sync");
      child.removeAttribute("data-word-field-key");
    });
    node.querySelectorAll("[data-scroll-rail], [data-scroll-thumb]").forEach((child) => child.remove());
  }

  function animateGhostExit(entry, intent) {
    if (!(entry.clone instanceof Element)) {
      return;
    }
    sanitizeGhostClone(entry.clone);
    entry.clone.classList.add("ui-transition-ghost");
    Object.assign(entry.clone.style, {
      left: `${entry.rect.left}px`,
      top: `${entry.rect.top}px`,
      width: `${entry.rect.width}px`,
      height: `${entry.rect.height}px`,
    });
    document.body.appendChild(entry.clone);
    const animation = entry.clone.animate(exitFrames(entry.role, intent), {
      duration: Math.max(160, transitionDuration(intent, entry.role) - 30),
      easing: "cubic-bezier(0.4, 0, 1, 1)",
      fill: "forwards",
    });
    animation.finished.catch(() => {}).finally(() => {
      entry.clone.remove();
    });
  }

  function animateEnteredElement(node, intent) {
    const role = node.getAttribute("data-anim-role") || "";
    node.animate(enterFrames(role, intent), {
      duration: transitionDuration(intent, role),
      delay: transitionDelay(node, role),
      easing: "cubic-bezier(0.22, 1, 0.36, 1)",
      fill: "both",
    });
  }

  function scheduleUiTransition(snapshot) {
    if (!snapshot) {
      return;
    }
    const token = ++uiTransitionToken;
    window.setTimeout(() => {
      if (token !== uiTransitionToken) {
        return;
      }
      root.getBoundingClientRect();
      const currentEntries = new Map();
      root.querySelectorAll("[data-anim-key]").forEach((node) => {
        const key = node.getAttribute("data-anim-key") || "";
        if (key) {
          currentEntries.set(key, node);
        }
      });
      snapshot.entries.forEach((entry, key) => {
        const node = currentEntries.get(key);
        if (node) {
          animateMatchedElement(node, entry, snapshot.intent);
        } else {
          animateGhostExit(entry, snapshot.intent);
        }
      });
      currentEntries.forEach((node, key) => {
        if (!snapshot.entries.has(key)) {
          animateEnteredElement(node, snapshot.intent);
        }
      });
    }, 0);
  }

  function exposeDebug() {
    window.__packetAnalyzerDebug = {
      getState: function () {
        const lane = currentLane();
        return {
          ready: debugState.bootState === "ready" && !state.loadingLane && !state.fatalError,
          bootState: debugState.bootState,
          lane: state.lane,
          loadingLane: state.loadingLane,
          loadedLanes: Array.from(laneDataMap.keys()).sort(),
          renderCount: debugState.renderCount,
          selectedRowId: state.selectedRowId,
          selectedWordId: state.selectedWordId,
          selectedFieldId: state.selectedFieldId,
          surfaceMode: state.surfaceMode,
          frameFilter: state.frameFilter,
          sectionFilter: state.sectionFilter,
          availableSections: availableSections().map((section) => section.id),
          waveSourceId: state.waveSourceId,
          waveViewport: currentWaveViewportDebugState(),
          viewTab: state.viewTab,
          specMode: state.specMode,
          detailsRadix: state.detailsRadix,
          trackerFormat: state.trackerFormat,
          trackerDensity: state.trackerDensity,
          trackerSync: state.trackerSync,
          updateMode: state.updateMode,
          persistentScrollbars: persistentScrollbars,
          sharedWaveViewport: usesSharedWaveViewport() ? currentSharedWaveState() : null,
          visiblePacketCount: visiblePackets().length,
          lanePacketCount: Array.isArray(lane.packets) ? lane.packets.length : 0,
          errors: debugState.errors.slice(),
          actions: debugState.actions.slice(),
          laneLoads: debugState.laneLoads.slice(),
        };
      },
      getErrors: function () {
        return debugState.errors.slice();
      },
    };
  }

  function isLikelySafari() {
    const ua = navigator.userAgent || "";
    const vendor = navigator.vendor || "";
    return /Safari/.test(ua) && /Apple/.test(vendor) && !/Chrome|CriOS|Chromium|Android|Edg|OPR|FxiOS/.test(ua);
  }

  async function preloadOtherLanes() {
    for (const laneInfo of manifest.lanes || []) {
      const laneKey = String(laneInfo.lane);
      if (laneKey === state.lane) {
        continue;
      }
      try {
        await ensureLaneData(laneKey);
      } catch (error) {
        noteError(error);
      }
    }
  }

  async function ensureLaneData(laneKey) {
    const key = String(laneKey);
    if (laneDataMap.has(key)) {
      return laneDataMap.get(key);
    }
    if (laneLoadPromises.has(key)) {
      return laneLoadPromises.get(key);
    }

    const laneInfo = laneInfoMap.get(key);
    if (!laneInfo || !laneInfo.laneScript) {
      return null;
    }

    const promise = loadScriptOnce(laneInfo.laneScript)
      .then(() => {
        const payloads = window.__PACKET_ANALYZER_LANES__ || {};
        const laneData = payloads[key] || payloads[Number(key)];
        if (!laneData) {
          throw new Error("Lane payload did not register after script load: lane " + key);
        }
        seedLaneData(laneData);
        debugState.laneLoads.push({
          lane: key,
          script: laneInfo.laneScript,
          time: new Date().toISOString(),
          packetCount: laneData.packetCount || (laneData.packets || []).length,
        });
        debugState.laneLoads = debugState.laneLoads.slice(-8);
        return laneData;
      })
      .finally(() => {
        laneLoadPromises.delete(key);
      });

    laneLoadPromises.set(key, promise);
    return promise;
  }

  function seedLaneData(laneData) {
    const key = String(laneData.lane);
    laneDataMap.set(key, laneData);
    (laneData.packets || []).forEach((packet) => {
      rowMap.set(packet.rowId, packet);
    });
  }

  function seedGlobalRows(rows) {
    (rows || []).forEach((packet) => {
      if (packet && packet.rowId) {
        rowMap.set(packet.rowId, packet);
      }
    });
  }

  function loadScriptOnce(src) {
    if (loadedScripts.has(src)) {
      return Promise.resolve();
    }
    return new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = src;
      script.async = true;
      script.onload = function () {
        loadedScripts.add(src);
        resolve();
      };
      script.onerror = function () {
        reject(new Error("Failed to load script: " + src));
      };
      document.head.appendChild(script);
    });
  }

  function buildDefaultFieldPrefs() {
    const prefs = {};
    rowMap.forEach((packet) => {
      Object.keys(packet.fieldsByMode || {}).forEach((mode) => {
        const key = prefKey(mode, packet.kind);
        if (prefs[key]) {
          return;
        }
        const fields = packet.fieldsByMode[mode] || [];
        prefs[key] = {
          order: fields.map((field) => field.id),
          hidden: fields.filter((field) => !field.defaultVisible).map((field) => field.id),
        };
      });
    });
    return prefs;
  }

  function loadFieldPrefs() {
    const base = buildDefaultFieldPrefs();
    try {
      const saved = JSON.parse(localStorage.getItem(PREF_KEY) || "{}");
      Object.keys(saved).forEach((key) => {
        if (!base[key]) {
          return;
        }
        const order = Array.isArray(saved[key].order) ? saved[key].order.filter((id) => base[key].order.includes(id)) : base[key].order.slice();
        const missing = base[key].order.filter((id) => !order.includes(id));
        base[key] = {
          order: order.concat(missing),
          hidden: Array.isArray(saved[key].hidden) ? saved[key].hidden.filter((id) => base[key].order.includes(id)) : base[key].hidden.slice(),
        };
      });
    } catch (error) {
      noteError(error);
    }
    return base;
  }

  function saveFieldPrefs() {
    try {
      localStorage.setItem(PREF_KEY, JSON.stringify(state.fieldPrefs));
    } catch (error) {
      noteError(error);
    }
  }

  function prefKey(mode, kind) {
    return mode + ":" + kind;
  }

  function currentLaneInfo() {
    return laneInfoMap.get(state.lane) || (manifest.lanes || [])[0] || { lane: -1, label: "Lane", frameIds: [], packetCount: 0, hitCount: 0 };
  }

  function currentLane() {
    const loaded = laneDataMap.get(state.lane);
    if (loaded) {
      return loaded;
    }
    const laneInfo = currentLaneInfo();
    return {
      lane: laneInfo.lane,
      label: laneInfo.label,
      frameIds: laneInfo.frameIds || [],
      packetCount: laneInfo.packetCount || 0,
      hitCount: laneInfo.hitCount || 0,
      packets: [],
      wavePanels: laneInfo.wavePanels || {},
    };
  }

  function globalPackets() {
    return ((manifest.meta && manifest.meta.globalPackets) || []).filter((packet) => packet && packet.rowId);
  }

  function packetSection(packet) {
    if (!packet) {
      return "ingress";
    }
    if (packet.section && SECTION_ORDER.includes(String(packet.section))) {
      return String(packet.section);
    }
    const rowId = String(packet.rowId || "");
    const kind = String(packet.kind || "").toLowerCase();
    const label = `${packet.kindLabel || ""} ${packet.packetLabel || ""}`.toLowerCase();
    if (kind === "dma_hit" || rowId.startsWith("DMA-") || label.includes("dma")) {
      return "dma";
    }
    if (rowId.startsWith("OPQ-") || label.includes("opq") || label.includes("egress")) {
      return "egress";
    }
    return "ingress";
  }

  function wavePanelSection(panel) {
    if (!panel) {
      return "ingress";
    }
    if (panel.section && SECTION_ORDER.includes(String(panel.section))) {
      return String(panel.section);
    }
    const panelId = String(panel.panelId || "").toLowerCase();
    const title = String(panel.title || "").toLowerCase();
    if (panelId === "dma" || title.includes("dma")) {
      return "dma";
    }
    if (panelId === "egress" || title.includes("egress") || title.includes("opq")) {
      return "egress";
    }
    return "ingress";
  }

  function availableSections() {
    const available = new Set();
    const laneInfo = currentLaneInfo();
    const globals = globalPackets();
    const globalPanels = (manifest.meta && manifest.meta.globalWavePanels) || {};
    if ((manifest.lanes || []).length || (laneInfo.packetCount || 0) > 0 || (currentLane().packets || []).length) {
      available.add("ingress");
    }
    if (globals.some((packet) => packetSection(packet) === "egress") || globalPanels.egress) {
      available.add("egress");
    }
    if (globals.some((packet) => packetSection(packet) === "dma") || globalPanels.dma) {
      available.add("dma");
    }
    return SECTION_ORDER.filter((section) => available.has(section)).map((section) => ({
      id: section,
      label: SECTION_LABELS[section],
    }));
  }

  function ensureSectionSelection() {
    const available = availableSections().map((section) => section.id);
    if (!available.length) {
      state.sectionFilter = "all";
      return;
    }
    if (state.sectionFilter !== "all" && !available.includes(state.sectionFilter)) {
      state.sectionFilter = "all";
    }
  }

  function currentSectionLabel() {
    return SECTION_LABELS[state.sectionFilter] || SECTION_LABELS.all;
  }

  function tracePacketsForSection(section) {
    if (section === "ingress") {
      return currentLane().packets || [];
    }
    return globalPackets().filter((packet) => packetSection(packet) === section);
  }

  function getSummaryFields(packet) {
    return packet && packet.fieldsByMode ? (packet.fieldsByMode[state.decodeMode] || []) : [];
  }

  function detailWords(packet) {
    return packet && packet.detailWordsByMode ? (packet.detailWordsByMode[state.decodeMode] || []) : [];
  }

  function ensurePref(packet) {
    if (!packet) {
      return { order: [], hidden: [] };
    }
    const key = prefKey(state.decodeMode, packet.kind);
    if (!state.fieldPrefs[key]) {
      const fields = getSummaryFields(packet);
      state.fieldPrefs[key] = {
        order: fields.map((field) => field.id),
        hidden: fields.filter((field) => !field.defaultVisible).map((field) => field.id),
      };
    }
    return state.fieldPrefs[key];
  }

  function getOrderedFields(packet) {
    const fields = getSummaryFields(packet);
    if (!packet) {
      return [];
    }
    const pref = ensurePref(packet);
    const ordered = pref.order.map((fieldId) => fields.find((field) => field.id === fieldId)).filter(Boolean);
    fields.forEach((field) => {
      if (!ordered.some((candidate) => candidate.id === field.id)) {
        ordered.push(field);
      }
    });
    return ordered;
  }

  function isHiddenDefault(packet, fieldId) {
    const pref = ensurePref(packet);
    return pref.hidden.includes(fieldId);
  }

  function visiblePackets() {
    ensureSectionSelection();
    const sections = state.sectionFilter === "all" ? availableSections().map((section) => section.id) : [state.sectionFilter];
    const packets = sections.flatMap((section) => tracePacketsForSection(section));
    return packets.filter((packet) => {
      if (!state.familyFilters[packet.kindFamily]) {
        return false;
      }
      if (!packetMatchesFrameFilter(packet)) {
        return false;
      }
      if (!packet.parentRowId) {
        return true;
      }
      return state.expandedRows.has(packet.parentRowId);
    });
  }

  function ensureSelection() {
    const visible = visiblePackets();
    if (!visible.length) {
      if (!rowMap.has(state.selectedRowId)) {
        state.selectedRowId = "";
      }
      return;
    }
    if (state.surfaceMode === "wave" && state.selectedRowId && rowMap.has(state.selectedRowId) && !visible.some((packet) => packet.rowId === state.selectedRowId)) {
      return;
    }
    if (!visible.some((packet) => packet.rowId === state.selectedRowId)) {
      state.selectedRowId = visible[0].rowId;
    }
  }

  function selectedPacket() {
    return rowMap.get(state.selectedRowId) || visiblePackets()[0] || null;
  }

  function makeWordFieldKey(wordId, fieldId) {
    return wordId + "::" + fieldId;
  }

  function makeWordSummaryKey(wordId, fieldId) {
    return "summary::" + wordId + "::" + fieldId;
  }

  function isSummarySelectionKey(value) {
    return typeof value === "string" && value.startsWith("summary::");
  }

  function parseFieldSelectionKey(value) {
    if (!value) {
      return null;
    }
    const text = String(value);
    if (isSummarySelectionKey(text)) {
      const parts = text.split("::");
      if (parts.length < 3) {
        return null;
      }
      return {
        summary: true,
        wordId: parts[1] || "",
        fieldId: parts.slice(2).join("::"),
      };
    }
    const splitAt = text.indexOf("::");
    if (splitAt === -1) {
      return null;
    }
    return {
      summary: false,
      wordId: text.slice(0, splitAt),
      fieldId: text.slice(splitAt + 2),
    };
  }

  function selectPacketWord(rowId, wordId, fieldKey) {
    if (rowId) {
      state.selectedRowId = rowId;
    }
    state.selectedWordId = wordId || "";
    state.selectedFieldId = fieldKey || "";
  }

  function findSelectedWordField(packet) {
    const words = detailWords(packet);
    if (isSummarySelectionKey(state.selectedFieldId)) {
      return null;
    }
    for (const word of words) {
      const fields = word.fieldsByMode ? (word.fieldsByMode[state.decodeMode] || []) : [];
      for (const field of fields) {
        if (makeWordFieldKey(word.wordId, field.id) === state.selectedFieldId) {
          return { key: state.selectedFieldId, word: word, field: field };
        }
      }
    }
    return null;
  }

  function ensureSelectedField(packet) {
    const words = detailWords(packet);
    if (!words.length) {
      state.selectedWordId = "";
      state.selectedFieldId = "";
      return null;
    }
    const found = findSelectedWordField(packet);
    if (found) {
      state.selectedWordId = found.word.wordId;
      return found;
    }
    if (state.selectedWordId) {
      const selectedWord = words.find((word) => word.wordId === state.selectedWordId);
      if (selectedWord) {
        return { key: state.selectedFieldId, word: selectedWord, field: null };
      }
    }
    const firstWord = words[0];
    const firstField = ((firstWord.fieldsByMode || {})[state.decodeMode] || [])[0];
    state.selectedWordId = firstWord.wordId;
    if (!firstField) {
      state.selectedFieldId = "";
      return { key: "", word: firstWord, field: null };
    }
    state.selectedFieldId = makeWordFieldKey(firstWord.wordId, firstField.id);
    return { key: state.selectedFieldId, word: firstWord, field: firstField };
  }

  function relativeTimeLabel(packet) {
    const laneKey = String(packet.lane);
    const zero = state.zeroTimePsByLane[laneKey] || 0;
    const delta = packet.timePs - zero;
    const sign = delta >= 0 ? "+" : "-";
    return sign + formatNs(Math.abs(delta));
  }

  function formatNs(timePs) {
    return (timePs / 1000).toFixed(3) + " ns";
  }

  function currentWavePanels() {
    ensureSectionSelection();
    const panels = [];
    const lane = currentLane();
    const includeAll = state.sectionFilter === "all";
    const addPanel = (panel, section) => {
      if (!panel) {
        return;
      }
      if (!includeAll && state.sectionFilter !== section) {
        return;
      }
      if (!panels.some((item) => item.panelId === panel.panelId)) {
        panels.push(panel);
      }
    };
    const globalPanels = (manifest.meta && manifest.meta.globalWavePanels) || {};
    if (lane.wavePanels && lane.wavePanels.ingress && (includeAll || state.sectionFilter === "ingress")) {
      addPanel(lane.wavePanels.ingress, "ingress");
    }
    addPanel(globalPanels.ingress, "ingress");
    addPanel(globalPanels.egress, "egress");
    addPanel(globalPanels.dma, "dma");
    return panels;
  }

  function hasWaveSurface() {
    return currentWavePanels().length > 0;
  }

  function hasCorrelatedWavePanels() {
    return currentWavePanels().some((panel) => !panel.legacyMode);
  }

  function waveSurfaceLabel() {
    return hasCorrelatedWavePanels() ? "Waveform Correlation" : "Waveform Viewer";
  }

  function waveSurfaceHint() {
    if (hasCorrelatedWavePanels()) {
      return "WaveDrom view of actual VCD-derived FEB_DATA_FRAME content. Left-click a beat decode to focus spec/details on the right; right-click for video-style navigation actions. Frame selection filters the decode overlays across the active source.";
    }
    return "Use Prev/Next and zoom to inspect ingress, egress, and DMA on the shared time axis beside the packet trace. Hover a decode blob for the full label when the current zoom hides text.";
  }

  function ensureSurfaceSelection() {
    if (state.surfaceMode === "wave" && !hasWaveSurface()) {
      state.surfaceMode = "trace";
    }
  }

  function availableFrameIds() {
    const current = currentLane().frameIds || [];
    const fallback = (manifest.meta && manifest.meta.selectedFrames) || [];
    return Array.from(new Set((current.length ? current : fallback).map((value) => String(value)))).sort((left, right) => Number(left) - Number(right));
  }

  function ensureFrameSelection() {
    const frames = availableFrameIds();
    if (!frames.length) {
      state.frameFilter = "";
      return;
    }
    if (!state.frameFilter) {
      return;
    }
    if (!frames.includes(String(state.frameFilter))) {
      state.frameFilter = "";
    }
  }

  function packetMatchesFrameFilter(packet) {
    if (!packet || !state.frameFilter) {
      return true;
    }
    return String(packet.frameId) === String(state.frameFilter);
  }

  function rowIdMatchesFrameFilter(rowId) {
    if (!state.frameFilter || !rowId || !rowMap.has(rowId)) {
      return true;
    }
    return packetMatchesFrameFilter(rowMap.get(rowId));
  }

  function rowIdMatchesFrameValue(rowId, frameId) {
    if (!rowId || frameId == null || !rowMap.has(rowId)) {
      return false;
    }
    return String(rowMap.get(rowId).frameId) === String(frameId);
  }

  function rowVisibilityPresetValue() {
    const enabled = FAMILY_ORDER.filter((family) => state.familyFilters[family]);
    if (enabled.length === FAMILY_ORDER.length) {
      return "all";
    }
    if (enabled.length === 1 && enabled[0] === "frame") {
      return "frames";
    }
    if (enabled.length === 1 && enabled[0] === "subpacket") {
      return "subpackets";
    }
    return "custom";
  }

  function applyRowVisibilityPreset(value) {
    if (value === "frames") {
      FAMILY_ORDER.forEach((family) => {
        state.familyFilters[family] = family === "frame";
      });
      return;
    }
    if (value === "subpackets") {
      FAMILY_ORDER.forEach((family) => {
        state.familyFilters[family] = family === "subpacket";
      });
      return;
    }
    FAMILY_ORDER.forEach((family) => {
      state.familyFilters[family] = true;
    });
  }

  function waveSources() {
    const sources = new Map();
    currentWavePanels().forEach((panel) => {
      const sourceId = panel.sourceId || (manifest.meta && manifest.meta.sourceVcd) || "default";
      if (!sources.has(sourceId)) {
        sources.set(sourceId, {
          id: sourceId,
          label: panel.sourceLabel || sourceId,
        });
      }
    });
    return Array.from(sources.values());
  }

  function caseCatalogEntries() {
    return CASE_CATALOG;
  }

  function inferCurrentCaseKey() {
    const pathMatch = window.location.pathname.match(/\/cases\/([^/]+)\/([^/]+)\/?$/i);
    if (pathMatch) {
      return {
        bucket: pathMatch[1],
        caseId: pathMatch[2],
      };
    }
    const bundlePathMatch = window.location.pathname.match(/\/([^/]+)\/([^/]+)(?:\/([^/]+))?\/packet_analyzer\/?$/i);
    if (bundlePathMatch) {
      return {
        bucket: bundlePathMatch[1],
        caseId: bundlePathMatch[3] ? `${bundlePathMatch[2]}/${bundlePathMatch[3]}` : bundlePathMatch[2],
      };
    }
    const sourceVcd = String((manifest.meta && manifest.meta.sourceVcd) || "");
    const vcdMatch = sourceVcd.match(/\/wave_reports\/([^/]+)\/([^/]+)(?:\/([^/]+))?\//i);
    if (vcdMatch) {
      return {
        bucket: vcdMatch[1],
        caseId: vcdMatch[3] ? `${vcdMatch[2]}/${vcdMatch[3]}` : vcdMatch[2],
      };
    }
    if (manifest.bucket && manifest.caseId) {
      return {
        bucket: String(manifest.bucket),
        caseId: String(manifest.caseId),
      };
    }
    return null;
  }

  function syntheticCaseEntry(key) {
    if (!key || !key.bucket || !key.caseId) {
      return null;
    }
    return {
      bucket: key.bucket,
      caseId: key.caseId,
      label: `${key.bucket} / ${key.caseId}`,
      description: currentSourceDescription(),
      url: window.location.pathname,
      current: true,
      synthetic: true,
    };
  }

  function currentCaseEntry() {
    const currentKey = inferCurrentCaseKey();
    if (currentKey) {
      const matched = caseCatalogEntries().find((entry) => entry.bucket === currentKey.bucket && entry.caseId === currentKey.caseId);
      if (matched) {
        return matched;
      }
      return syntheticCaseEntry(currentKey);
    }
    return caseCatalogEntries().find((entry) => entry.current) || caseCatalogEntries()[0] || null;
  }

  function currentCaseLabel() {
    const current = currentCaseEntry();
    return current ? current.label : selectedSourceLabel();
  }

  function currentCaseDescription() {
    const current = currentCaseEntry();
    return current ? (current.description || current.profileName || current.label || "") : "";
  }

  function currentSourceDescription() {
    const meta = manifest.meta || {};
    const parts = [];
    if (meta.sourceVcd) {
      parts.push(String(meta.sourceVcd).split("/").slice(-3).join("/"));
    }
    if (Array.isArray(meta.selectedFrames) && meta.selectedFrames.length) {
      parts.push(`frames ${meta.selectedFrames.map((frame) => "F" + frame).join(", ")}`);
    }
    return parts.join(" | ");
  }

  function renderCaseOptions() {
    const groups = new Map();
    const current = currentCaseEntry();
    const entries = caseCatalogEntries().slice();
    if (current && current.synthetic) {
      entries.push(current);
    }
    entries.forEach((entry) => {
      if (!groups.has(entry.bucket)) {
        groups.set(entry.bucket, []);
      }
      groups.get(entry.bucket).push(entry);
    });
    return Array.from(groups.entries()).map(([bucket, entries]) => `
      <optgroup label="${escapeHtml(bucket)}">
        ${entries.map((entry) => `<option value="${escapeHtml(entry.url || "")}" ${current && current.bucket === entry.bucket && current.caseId === entry.caseId ? "selected" : ""}>${escapeHtml(entry.caseId || entry.label || "")}</option>`).join("")}
      </optgroup>
    `).join("");
  }

  function selectedSourceLabel() {
    const sources = waveSources();
    if (!sources.length) {
      return (manifest.meta && manifest.meta.sourceVcd) || "n/a";
    }
    if (sources.length === 1) {
      return sources[0].label || sources[0].id;
    }
    ensureWaveSourceSelection();
    const selected = sources.find((source) => source.id === state.waveSourceId);
    return selected ? selected.label : sources[0].label;
  }

  async function findWavePanelFrameLocation(panel, frameId) {
    if (!panel || frameId == null) {
      return null;
    }
    if (panel.legacyMode) {
      return findLegacyWavePanelFrameLocation(panel, frameId);
    }
    for (let chunkIndex = 0; chunkIndex < panel.chunks.length; chunkIndex += 1) {
      const chunk = await loadWaveChunk(panel.chunks[chunkIndex].src);
      const beat = (chunk.beatLinks || []).find((item) => rowIdMatchesFrameValue(item.targetRowId || item.rowId || "", frameId));
      if (beat) {
        const cycleBase = Number(panel.chunks[chunkIndex].cycleStart) || 0;
        const slotStart = Math.max(0, Number(beat.slotStart) || 0);
        return { chunkIndex: chunkIndex, slotStart: slotStart, cycleStart: cycleBase + slotStart };
      }
      const annotation = (chunk.annotations || []).find((item) => rowIdMatchesFrameValue(item.rowId || "", frameId));
      if (annotation) {
        const cycleBase = Number(panel.chunks[chunkIndex].cycleStart) || 0;
        const slotStart = Math.max(0, Number(annotation.slotStart) || 0);
        return { chunkIndex: chunkIndex, slotStart: slotStart, cycleStart: cycleBase + slotStart };
      }
    }
    return null;
  }

  async function findLegacyWavePanelFrameLocation(panel, frameId) {
    const framePacket = Array.from(rowMap.values()).find((packet) => packet && packet.section === panel.panelId && packet.rowType === "frame" && String(packet.frameId) === String(frameId));
    if (framePacket) {
      const direct = findLegacyWavePanelSelectionLocation(panel, framePacket.rowId, "");
      if (direct) {
        return direct;
      }
    }
    for (let chunkIndex = 0; chunkIndex < panel.chunks.length; chunkIndex += 1) {
      const chunkMeta = panel.chunks[chunkIndex];
      const chunk = await loadWaveChunk(chunkMeta.src);
      const slotCount = chunkSlotCount(chunkMeta) || deriveWaveSlotCount(chunk.signal || []);
      const beatRows = await buildLegacyBeatRows(panel, chunk, chunkMeta, 0, slotCount);
      for (const row of beatRows) {
        const cell = (row.cells || []).find((item) => rowIdMatchesFrameValue(item.targetRowId || item.rowId || "", frameId));
        if (cell) {
          const cycleBase = Number(chunkMeta.cycleStart) || 0;
          const slotStart = Math.max(0, Number(cell.slotStart) || 0);
          return { chunkIndex: chunkIndex, slotStart: slotStart, cycleStart: cycleBase + slotStart };
        }
      }
    }
    return null;
  }

  function findWaveSelectionMatch(cells, rowId, wordId) {
    const list = cells || [];
    if (wordId) {
      const exact = list.find((item) => (item.targetRowId || item.rowId || "") === rowId && (item.wordId || "") === wordId);
      if (exact) {
        return exact;
      }
    }
    const rowMatch = list.find((item) => (item.targetRowId || item.rowId || "") === rowId);
    if (rowMatch) {
      return rowMatch;
    }
    if (wordId) {
      return list.find((item) => (item.wordId || "") === wordId) || null;
    }
    return null;
  }

  function legacyWaveCycleForSelection(packet, wordId) {
    if (!packet) {
      return null;
    }
    const words = detailWords(packet);
    if (wordId) {
      const exact = words.find((word) => word.wordId === wordId);
      if (exact && Number.isFinite(Number(exact.cycle))) {
        return Number(exact.cycle);
      }
    }
    if (words.length) {
      const first = words.find((word) => Number.isFinite(Number(word.cycle))) || words[0];
      if (first && Number.isFinite(Number(first.cycle))) {
        return Number(first.cycle);
      }
    }
    if (Number.isFinite(Number(packet.cycle))) {
      return Number(packet.cycle);
    }
    if (Number.isFinite(Number(packet.startCycle))) {
      return Number(packet.startCycle);
    }
    return null;
  }

  function findLegacyWavePanelSelectionLocation(panel, rowId, wordId) {
    const packet = rowMap.get(rowId) || null;
    if (!packet || packet.section !== panel.panelId) {
      return null;
    }
    const cycle = legacyWaveCycleForSelection(packet, wordId);
    if (!Number.isFinite(cycle)) {
      return null;
    }
    const chunkIndex = (panel.chunks || []).findIndex((chunkMeta) => {
      const start = Number(chunkMeta.cycleStart);
      const end = Number(chunkMeta.cycleEnd);
      return Number.isFinite(start) && Number.isFinite(end) && cycle >= start && cycle <= end;
    });
    if (chunkIndex === -1) {
      return null;
    }
    const chunkMeta = panel.chunks[chunkIndex];
    const cycleBase = Number(chunkMeta.cycleStart) || 0;
    return {
      chunkIndex: chunkIndex,
      slotStart: Math.max(0, cycle - cycleBase),
      cycleStart: cycle,
    };
  }

  async function findWavePanelSelectionLocation(panel, rowId, wordId) {
    if (!panel || !rowId) {
      return null;
    }
    if (panel.legacyMode) {
      return findLegacyWavePanelSelectionLocation(panel, rowId, wordId);
    }
    for (let chunkIndex = 0; chunkIndex < panel.chunks.length; chunkIndex += 1) {
      const chunkMeta = panel.chunks[chunkIndex];
      const chunk = await loadWaveChunk(chunkMeta.src);
      const beat = findWaveSelectionMatch(chunk.beatLinks || [], rowId, wordId);
      if (beat) {
        const cycleBase = Number(chunkMeta.cycleStart) || 0;
        const slotStart = Math.max(0, Number(beat.slotStart) || 0);
        return { chunkIndex: chunkIndex, slotStart: slotStart, cycleStart: cycleBase + slotStart };
      }
      if (!wordId) {
        const annotation = (chunk.annotations || []).find((item) => (item.rowId || "") === rowId);
        if (annotation) {
          const cycleBase = Number(chunkMeta.cycleStart) || 0;
          const slotStart = Math.max(0, Number(annotation.slotStart) || 0);
          return { chunkIndex: chunkIndex, slotStart: slotStart, cycleStart: cycleBase + slotStart };
        }
      }
    }
    return null;
  }

  async function focusWavePanelsForFrame(frameId) {
    if (!frameId) {
      return;
    }
    const panels = visibleWavePanels();
    if (usesSharedWaveViewport()) {
      const locations = (await Promise.all(panels.map((panel) => findWavePanelFrameLocation(panel, frameId)))).filter(Boolean);
      if (!locations.length) {
        return;
      }
      state.sharedWaveState[sharedWaveStateKey()] = normalizeSharedWaveState(panels, Object.assign({}, currentSharedWaveState(), {
        cycleStart: Math.min(...locations.map((location) => Number(location.cycleStart) || 0)),
      }));
      scheduleWaveRender();
      return;
    }
    let changed = false;
    for (const panel of panels) {
      const location = await findWavePanelFrameLocation(panel, frameId);
      if (!location) {
        continue;
      }
      const current = normalizeWavePanelState(panel, state.wavePanelState[panel.panelId]);
      const chunkMeta = panel.chunks[location.chunkIndex];
      const slotCount = chunkSlotCount(chunkMeta);
      const next = normalizeWavePanelState(panel, Object.assign({}, current, {
        chunkIndex: location.chunkIndex,
        slotOffset: Math.max(0, Math.min(Math.max(0, slotCount - current.visibleSlots), location.slotStart)),
      }));
      state.wavePanelState[panel.panelId] = next;
      changed = true;
    }
    if (changed) {
      scheduleWaveRender();
    }
  }

  function queueWaveSync(rowId, wordId) {
    state.pendingWaveSync = {
      rowId: rowId || state.selectedRowId || "",
      wordId: wordId || state.selectedWordId || "",
    };
  }

  function findRenderedWaveTarget(rowId, wordId) {
    if (!rowId) {
      return null;
    }
    if (wordId) {
      const exact = root.querySelector(`[data-wave-target-row-id="${CSS.escape(rowId)}"][data-wave-word-id="${CSS.escape(wordId)}"]`);
      if (exact) {
        return exact;
      }
    }
    return root.querySelector(`[data-wave-target-row-id="${CSS.escape(rowId)}"]`);
  }

  function scheduleWaveSelectionHighlight(rowId, wordId, attempt) {
    if (!rowId || state.surfaceMode !== "wave") {
      return;
    }
    const target = findRenderedWaveTarget(rowId, wordId);
    if (target) {
      const linkKey = target.getAttribute("data-wave-link-key") || "";
      if (linkKey) {
        setWaveLinkHover(linkKey);
      }
      return;
    }
    if ((attempt || 0) >= 8) {
      return;
    }
    if (waveSelectionHighlightTimer) {
      window.clearTimeout(waveSelectionHighlightTimer);
    }
    waveSelectionHighlightTimer = window.setTimeout(() => {
      waveSelectionHighlightTimer = 0;
      scheduleWaveSelectionHighlight(rowId, wordId, (attempt || 0) + 1);
    }, 60);
  }

  function applyPendingWaveSync() {
    if (!state.pendingWaveSync) {
      return;
    }
    const pending = state.pendingWaveSync;
    const target = findRenderedWaveTarget(pending.rowId, pending.wordId);
    if (!target) {
      scheduleWaveSelectionHighlight(pending.rowId, pending.wordId, 1);
      return;
    }
    state.pendingWaveSync = null;
    const waveStack = root.querySelector(".wave-panel-stack");
    if (waveStack) {
      centerElementInScroller(waveStack, target.closest(".wave-panel") || target, { vertical: true, horizontal: false });
      state.lastWaveScrollTopByKey[currentWaveScrollKey()] = waveStack.scrollTop;
      syncPersistentScrollbar("wave");
    }
    const linkKey = target.getAttribute("data-wave-link-key") || "";
    if (linkKey) {
      setWaveLinkHover(linkKey);
    }
    scheduleWaveSelectionHighlight(pending.rowId, pending.wordId, 1);
  }

  async function focusWavePanelsForSelection(rowId, wordId) {
    if (!rowId || !hasWaveSurface()) {
      return;
    }
    const packet = rowMap.get(rowId) || null;
    const panels = visibleWavePanels();
    const locations = (await Promise.all(panels.map((panel) => findWavePanelSelectionLocation(panel, rowId, wordId)))).map((location, index) => ({
      panel: panels[index],
      location: location,
    })).filter((entry) => !!entry.location);
    if (!locations.length) {
      if (packet && packet.frameId != null) {
        await focusWavePanelsForFrame(packet.frameId);
      }
      queueWaveSync(rowId, wordId);
      return;
    }
    if (usesSharedWaveViewport()) {
      const shared = normalizeSharedWaveState(panels, currentSharedWaveState());
      const targetCycle = Math.min(...locations.map((entry) => Number(entry.location.cycleStart) || 0));
      shared.cycleStart = targetCycle - Math.floor(shared.visibleSlots / 2);
      state.sharedWaveState[sharedWaveStateKey()] = normalizeSharedWaveState(panels, shared);
      queueWaveSync(rowId, wordId);
      scheduleWaveRender();
      return;
    }
    let changed = false;
    locations.forEach((entry) => {
      const panel = entry.panel;
      const location = entry.location;
      const current = normalizeWavePanelState(panel, state.wavePanelState[panel.panelId]);
      const chunkMeta = panel.chunks[location.chunkIndex];
      const slotCount = chunkSlotCount(chunkMeta);
      const centeredOffset = location.slotStart - Math.floor(current.visibleSlots / 2);
      state.wavePanelState[panel.panelId] = normalizeWavePanelState(panel, Object.assign({}, current, {
        chunkIndex: location.chunkIndex,
        slotOffset: Math.max(0, Math.min(Math.max(0, slotCount - current.visibleSlots), centeredOffset)),
      }));
      changed = true;
    });
    queueWaveSync(rowId, wordId);
    if (changed) {
      scheduleWaveRender();
    }
  }

  function requestWaveSelectionFocus(rowId, wordId) {
    if (state.surfaceMode !== "wave" || !hasWaveSurface() || !rowId) {
      return;
    }
    const token = ++waveSelectionRequestToken;
    queueWaveSync(rowId, wordId);
    scheduleWaveSelectionHighlight(rowId, wordId, 1);
    Promise.resolve(focusWavePanelsForSelection(rowId, wordId)).catch(noteError).finally(() => {
      if (token !== waveSelectionRequestToken) {
        return;
      }
      scheduleWaveRender();
    });
  }

  function ensureWaveSourceSelection() {
    const sources = waveSources();
    if (!sources.length) {
      state.waveSourceId = "";
      return;
    }
    if (!sources.some((source) => source.id === state.waveSourceId)) {
      state.waveSourceId = sources[0].id;
    }
  }

  function visibleWavePanels() {
    const panels = currentWavePanels();
    const sources = waveSources();
    if (sources.length <= 1) {
      return panels;
    }
    ensureWaveSourceSelection();
    return panels.filter((panel) => (panel.sourceId || "") === state.waveSourceId);
  }

  function usesSharedWaveViewport() {
    return waveSources().length <= 1 && currentWavePanels().length > 1;
  }

  function wavePanelsCycleBounds(panels) {
    const chunks = (panels || [])
      .flatMap((panel) => panel.chunks || [])
      .filter((chunk) => Number.isFinite(Number(chunk.cycleStart)) && Number.isFinite(Number(chunk.cycleEnd)));
    if (!chunks.length) {
      return null;
    }
    return {
      cycleStart: Math.min(...chunks.map((chunk) => Number(chunk.cycleStart))),
      cycleEnd: Math.max(...chunks.map((chunk) => Number(chunk.cycleEnd))),
    };
  }

  function packetCycleBounds(packet) {
    if (!packet) {
      return null;
    }
    const startCandidates = [packet.startCycle, packet.cycle]
      .map((value) => Number(value))
      .filter(Number.isFinite);
    const endCandidates = [packet.endCycle, packet.startCycle, packet.cycle]
      .map((value) => Number(value))
      .filter(Number.isFinite);
    if (!startCandidates.length || !endCandidates.length) {
      return null;
    }
    return {
      cycleStart: Math.min(...startCandidates),
      cycleEnd: Math.max(...endCandidates),
    };
  }

  function selectedWaveCycleBounds() {
    const selectedFrames = new Set(((manifest.meta && manifest.meta.selectedFrames) || [])
      .map((value) => String(value)));
    if (!selectedFrames.size) {
      return null;
    }
    const matches = ((manifest.meta && manifest.meta.globalPackets) || [])
      .filter((packet) => selectedFrames.has(String(packet.frameId)) && (packet.rowType === "frame" || packet.kindFamily === "frame"))
      .map(packetCycleBounds)
      .filter(Boolean);
    if (!matches.length) {
      return null;
    }
    return {
      cycleStart: Math.min(...matches.map((item) => item.cycleStart)),
      cycleEnd: Math.max(...matches.map((item) => item.cycleEnd)),
    };
  }

  function intersectCycleBounds(left, right) {
    if (!left || !right) {
      return null;
    }
    const cycleStart = Math.max(left.cycleStart, right.cycleStart);
    const cycleEnd = Math.min(left.cycleEnd, right.cycleEnd);
    return cycleEnd >= cycleStart ? { cycleStart: cycleStart, cycleEnd: cycleEnd } : null;
  }

  function focusedWaveCycleBounds(bounds) {
    const selected = selectedWaveCycleBounds();
    return intersectCycleBounds(selected, bounds) || bounds;
  }

  function autoWaveVisibleSlots(panel, targetSpan, slotCount) {
    const defaultVisible = Number(panel && panel.defaultVisibleSlots) || 16;
    const padded = Math.ceil(Math.max(1, Number(targetSpan) || defaultVisible) * 1.12) + 8;
    const cappedDefault = Math.min(defaultVisible, 512);
    const cappedTarget = Math.min(padded, 512);
    return clampWaveVisibleSlots(panel || { defaultVisibleSlots: cappedDefault }, Math.max(cappedDefault, cappedTarget), slotCount);
  }

  function sharedWaveStateKey() {
    const source = waveSources()[0];
    return source ? String(source.id) : "default";
  }

  function defaultSharedWaveState(panels) {
    const bounds = wavePanelsCycleBounds(panels);
    if (!bounds) {
      return {
        sourceId: sharedWaveStateKey(),
        cycleStart: 0,
        visibleSlots: 16,
        minCycle: 0,
        maxCycle: 0,
      };
    }
    const span = Math.max(1, bounds.cycleEnd - bounds.cycleStart + 1);
    const requestedVisible = Math.max(...panels.map((panel) => Number(panel.defaultVisibleSlots) || 16), 16);
    const focusBounds = focusedWaveCycleBounds(bounds);
    const focusSpan = Math.max(1, focusBounds.cycleEnd - focusBounds.cycleStart + 1);
    const visibleSlots = autoWaveVisibleSlots({ defaultVisibleSlots: requestedVisible }, focusSpan, span);
    const focusCenter = focusBounds.cycleStart + Math.floor(focusSpan / 2);
    return {
      sourceId: sharedWaveStateKey(),
      cycleStart: focusCenter - Math.floor(visibleSlots / 2),
      visibleSlots: visibleSlots,
      minCycle: bounds.cycleStart,
      maxCycle: bounds.cycleEnd,
    };
  }

  function normalizeSharedWaveState(panels, sharedState) {
    const bounds = wavePanelsCycleBounds(panels);
    if (!bounds) {
      return defaultSharedWaveState([]);
    }
    const span = Math.max(1, bounds.cycleEnd - bounds.cycleStart + 1);
    const requestedVisible = Math.max(...panels.map((panel) => Number(panel.defaultVisibleSlots) || 16), 16);
    const next = Object.assign({}, defaultSharedWaveState(panels), sharedState || {});
    next.sourceId = sharedWaveStateKey();
    next.minCycle = bounds.cycleStart;
    next.maxCycle = bounds.cycleEnd;
    next.visibleSlots = clampWaveVisibleSlots({ defaultVisibleSlots: requestedVisible }, next.visibleSlots, span);
    const maxStart = Math.max(bounds.cycleStart, bounds.cycleEnd - next.visibleSlots + 1);
    next.cycleStart = Math.max(bounds.cycleStart, Math.min(maxStart, Number(next.cycleStart) || bounds.cycleStart));
    return next;
  }

  function ensureSharedWaveState() {
    if (!usesSharedWaveViewport()) {
      return;
    }
    const panels = visibleWavePanels();
    const key = sharedWaveStateKey();
    state.sharedWaveState[key] = normalizeSharedWaveState(panels, state.sharedWaveState[key]);
  }

  function currentSharedWaveState() {
    if (!usesSharedWaveViewport()) {
      return null;
    }
    ensureSharedWaveState();
    return state.sharedWaveState[sharedWaveStateKey()] || null;
  }

  function defaultWavePanelState(panel) {
    const fallback = {
      chunkIndex: 0,
      slotOffset: 0,
      visibleSlots: panel.defaultVisibleSlots || 16,
    };
    const bounds = wavePanelsCycleBounds([panel]);
    if (!bounds || !panel || !Array.isArray(panel.chunks) || !panel.chunks.length) {
      return fallback;
    }
    const focusBounds = focusedWaveCycleBounds(bounds);
    const focusSpan = Math.max(1, focusBounds.cycleEnd - focusBounds.cycleStart + 1);
    const focusCenter = focusBounds.cycleStart + Math.floor(focusSpan / 2);
    let chunkIndex = panel.chunks.findIndex((chunk) => {
      const chunkStart = Number(chunk.cycleStart);
      const chunkEnd = Number(chunk.cycleEnd);
      return Number.isFinite(chunkStart) && Number.isFinite(chunkEnd) && focusCenter >= chunkStart && focusCenter <= chunkEnd;
    });
    if (chunkIndex === -1) {
      chunkIndex = panel.chunks.findIndex((chunk) => !!intersectCycleBounds(focusBounds, {
        cycleStart: Number(chunk.cycleStart),
        cycleEnd: Number(chunk.cycleEnd),
      }));
    }
    if (chunkIndex === -1) {
      chunkIndex = 0;
    }
    const chunkMeta = panel.chunks[chunkIndex];
    const slotCount = chunkSlotCount(chunkMeta);
    const visibleSlots = autoWaveVisibleSlots(panel, focusSpan, slotCount);
    const chunkStart = Number(chunkMeta.cycleStart);
    const focusSlot = Number.isFinite(chunkStart) ? focusCenter - chunkStart : 0;
    return {
      chunkIndex: chunkIndex,
      slotOffset: focusSlot - Math.floor(visibleSlots / 2),
      visibleSlots: visibleSlots,
    };
  }

  function chunkSlotCount(chunkMeta) {
    if (!chunkMeta) {
      return 1;
    }
    const explicit = Number(chunkMeta.slotCount);
    if (Number.isFinite(explicit) && explicit > 0) {
      return explicit;
    }
    const start = Number(chunkMeta.slotStart);
    const stop = Number(chunkMeta.slotStop);
    if (Number.isFinite(start) && Number.isFinite(stop) && stop > start) {
      return stop - start;
    }
    return 1;
  }

  function waveSlotChoices(slotCount) {
    const capped = WAVE_VISIBLE_SLOT_STEPS.filter((value) => value <= slotCount);
    const maxPreset = WAVE_VISIBLE_SLOT_STEPS[WAVE_VISIBLE_SLOT_STEPS.length - 1];
    if ((!capped.length || capped[capped.length - 1] !== slotCount) && slotCount <= maxPreset) {
      capped.push(slotCount);
    }
    if (!capped.length) {
      capped.push(Math.min(slotCount, maxPreset));
    }
    return Array.from(new Set(capped)).sort((left, right) => left - right);
  }

  function nearestWaveChoiceIndex(choices, visibleSlots) {
    if (!choices || !choices.length) {
      return 0;
    }
    const target = Number(visibleSlots) || choices[0];
    return choices.reduce((bestIndex, value, index) => {
      return Math.abs(value - target) < Math.abs(choices[bestIndex] - target) ? index : bestIndex;
    }, 0);
  }

  function clampWaveVisibleSlots(panel, requested, slotCount) {
    const choices = waveSlotChoices(slotCount);
    const target = Math.max(1, Math.min(slotCount, Number(requested) || panel.defaultVisibleSlots || slotCount));
    return choices.reduce((best, value) => {
      if (Math.abs(value - target) < Math.abs(best - target)) {
        return value;
      }
      return best;
    }, choices[0]);
  }

  function normalizeWavePanelState(panel, panelState) {
    const next = Object.assign({}, defaultWavePanelState(panel), panelState || {});
    next.chunkIndex = Math.max(0, Math.min(panel.chunkCount - 1, Number(next.chunkIndex) || 0));
    const chunkMeta = panel.chunks[next.chunkIndex];
    const slotCount = chunkSlotCount(chunkMeta);
    next.visibleSlots = clampWaveVisibleSlots(panel, next.visibleSlots, slotCount);
    next.slotOffset = Math.max(0, Math.min(Math.max(0, slotCount - next.visibleSlots), Number(next.slotOffset) || 0));
    return next;
  }

  function waveRangeControlKey(panelId) {
    return panelId ? String(panelId) : "shared";
  }

  function sharedWaveViewportDescriptor(sharedWave) {
    if (!usesSharedWaveViewport()) {
      return null;
    }
    const panels = visibleWavePanels();
    const normalized = normalizeSharedWaveState(panels, sharedWave || currentSharedWaveState());
    const span = Math.max(1, normalized.maxCycle - normalized.minCycle + 1);
    return {
      mode: "shared",
      panelId: "",
      controlKey: waveRangeControlKey(""),
      minCycle: normalized.minCycle,
      maxCycle: normalized.maxCycle,
      cycleStart: normalized.cycleStart,
      cycleEnd: Math.min(normalized.maxCycle, normalized.cycleStart + normalized.visibleSlots - 1),
      visibleSlots: normalized.visibleSlots,
      choices: waveSlotChoices(span),
    };
  }

  function panelWaveViewportDescriptor(panel, panelState) {
    if (!panel) {
      return null;
    }
    const waveState = normalizeWavePanelState(panel, panelState || state.wavePanelState[panel.panelId]);
    const chunkMeta = panel.chunks[waveState.chunkIndex];
    const slotCount = chunkSlotCount(chunkMeta);
    const panelBounds = wavePanelsCycleBounds([panel]) || { cycleStart: 0, cycleEnd: Math.max(0, slotCount - 1) };
    const chunkStart = Number(chunkMeta && chunkMeta.cycleStart);
    const viewStart = Number.isFinite(chunkStart) ? chunkStart + waveState.slotOffset : waveState.slotOffset;
    return {
      mode: "panel",
      panelId: panel.panelId,
      controlKey: waveRangeControlKey(panel.panelId),
      minCycle: panelBounds.cycleStart,
      maxCycle: panelBounds.cycleEnd,
      cycleStart: viewStart,
      cycleEnd: Math.min(panelBounds.cycleEnd, viewStart + waveState.visibleSlots - 1),
      visibleSlots: waveState.visibleSlots,
      choices: waveSlotChoices(slotCount),
      chunkIndex: waveState.chunkIndex,
    };
  }

  function waveViewportDescriptorForPanelId(panelId) {
    if (usesSharedWaveViewport()) {
      return sharedWaveViewportDescriptor(currentSharedWaveState());
    }
    const panel = findWavePanel(panelId);
    return panel ? panelWaveViewportDescriptor(panel, state.wavePanelState[panel.panelId]) : null;
  }

  function currentWaveViewportDebugState() {
    if (!hasWaveSurface()) {
      return null;
    }
    if (usesSharedWaveViewport()) {
      return sharedWaveViewportDescriptor(currentSharedWaveState());
    }
    return visibleWavePanels().map((panel) => panelWaveViewportDescriptor(panel, state.wavePanelState[panel.panelId]));
  }

  function normalizeRequestedCycleRange(cycleStart, cycleEnd) {
    let start = Math.round(Number(cycleStart));
    let end = Math.round(Number(cycleEnd));
    if (!Number.isFinite(start) || !Number.isFinite(end)) {
      return null;
    }
    if (end < start) {
      const tmp = start;
      start = end;
      end = tmp;
    }
    return { cycleStart: start, cycleEnd: end };
  }

  function clampCycleRangeToBounds(range, bounds) {
    if (!range || !bounds) {
      return null;
    }
    const cycleStart = Math.max(bounds.cycleStart, Math.min(bounds.cycleEnd, range.cycleStart));
    const cycleEnd = Math.max(bounds.cycleStart, Math.min(bounds.cycleEnd, range.cycleEnd));
    return normalizeRequestedCycleRange(cycleStart, cycleEnd);
  }

  function findWaveChunkIndexForCycle(panel, cycleStart, cycleEnd) {
    const range = normalizeRequestedCycleRange(cycleStart, cycleEnd);
    if (!panel || !range || !Array.isArray(panel.chunks) || !panel.chunks.length) {
      return 0;
    }
    const center = range.cycleStart + Math.floor((range.cycleEnd - range.cycleStart) / 2);
    let index = panel.chunks.findIndex((chunk) => {
      const chunkStart = Number(chunk.cycleStart);
      const chunkEnd = Number(chunk.cycleEnd);
      return Number.isFinite(chunkStart) && Number.isFinite(chunkEnd) && center >= chunkStart && center <= chunkEnd;
    });
    if (index !== -1) {
      return index;
    }
    index = panel.chunks.findIndex((chunk) => intersectCycleBounds(range, {
      cycleStart: Number(chunk.cycleStart),
      cycleEnd: Number(chunk.cycleEnd),
    }));
    if (index !== -1) {
      return index;
    }
    const firstStart = Number(panel.chunks[0].cycleStart);
    const lastEnd = Number(panel.chunks[panel.chunks.length - 1].cycleEnd);
    if (Number.isFinite(firstStart) && center < firstStart) {
      return 0;
    }
    if (Number.isFinite(lastEnd) && center > lastEnd) {
      return panel.chunks.length - 1;
    }
    return 0;
  }

  function applyWaveRange(panelId, cycleStart, cycleEnd) {
    const requested = normalizeRequestedCycleRange(cycleStart, cycleEnd);
    if (!requested) {
      return false;
    }
    if (usesSharedWaveViewport()) {
      const panels = visibleWavePanels();
      const sharedWave = normalizeSharedWaveState(panels, currentSharedWaveState());
      const bounds = { cycleStart: sharedWave.minCycle, cycleEnd: sharedWave.maxCycle };
      const range = clampCycleRangeToBounds(requested, bounds);
      if (!range) {
        return false;
      }
      const span = Math.max(1, sharedWave.maxCycle - sharedWave.minCycle + 1);
      const requestedVisible = Math.max(1, range.cycleEnd - range.cycleStart + 1);
      const visibleSlots = clampWaveVisibleSlots({ defaultVisibleSlots: requestedVisible }, requestedVisible, span);
      const center = range.cycleStart + Math.floor(requestedVisible / 2);
      sharedWave.visibleSlots = visibleSlots;
      sharedWave.cycleStart = center - Math.floor(visibleSlots / 2);
      state.sharedWaveState[sharedWaveStateKey()] = normalizeSharedWaveState(panels, sharedWave);
      scheduleWaveRender();
      return true;
    }
    const panel = findWavePanel(panelId);
    if (!panel) {
      return false;
    }
    const panelBounds = wavePanelsCycleBounds([panel]);
    const range = clampCycleRangeToBounds(requested, panelBounds);
    if (!range) {
      return false;
    }
    const chunkIndex = findWaveChunkIndexForCycle(panel, range.cycleStart, range.cycleEnd);
    const chunkMeta = panel.chunks[chunkIndex];
    const slotCount = chunkSlotCount(chunkMeta);
    const requestedVisible = Math.max(1, range.cycleEnd - range.cycleStart + 1);
    const visibleSlots = clampWaveVisibleSlots(panel, requestedVisible, slotCount);
    const chunkStart = Number(chunkMeta.cycleStart);
    const center = range.cycleStart + Math.floor(requestedVisible / 2);
    const slotOffset = Number.isFinite(chunkStart) ? center - chunkStart - Math.floor(visibleSlots / 2) : 0;
    state.wavePanelState[panel.panelId] = normalizeWavePanelState(panel, {
      chunkIndex: chunkIndex,
      slotOffset: slotOffset,
      visibleSlots: visibleSlots,
    });
    scheduleWaveRender();
    return true;
  }

  function applyWaveVisibleSlots(panelId, requestedVisibleSlots, centerCycle) {
    const slots = Math.max(1, Math.round(Number(requestedVisibleSlots) || 1));
    const descriptor = waveViewportDescriptorForPanelId(panelId);
    if (!descriptor) {
      return false;
    }
    const center = Number.isFinite(Number(centerCycle))
      ? Number(centerCycle)
      : descriptor.cycleStart + Math.floor(descriptor.visibleSlots / 2);
    return applyWaveRange(panelId, center - Math.floor(slots / 2), center + Math.max(0, slots - Math.floor(slots / 2) - 1));
  }

  function resetWaveViewport(panelId) {
    if (usesSharedWaveViewport()) {
      const panels = visibleWavePanels();
      state.sharedWaveState[sharedWaveStateKey()] = normalizeSharedWaveState(panels, defaultSharedWaveState(panels));
      scheduleWaveRender();
      return true;
    }
    const panel = findWavePanel(panelId);
    if (!panel) {
      return false;
    }
    state.wavePanelState[panel.panelId] = normalizeWavePanelState(panel, defaultWavePanelState(panel));
    scheduleWaveRender();
    return true;
  }

  function waveRangeControlsForPanel(panelId) {
    return root.querySelector(`[data-wave-controls="${CSS.escape(waveRangeControlKey(panelId))}"]`);
  }

  function applyWaveRangeFromControls(panelId) {
    const controls = waveRangeControlsForPanel(panelId);
    if (!controls) {
      return false;
    }
    const startInput = controls.querySelector("[data-wave-range-start]");
    const endInput = controls.querySelector("[data-wave-range-end]");
    if (!startInput || !endInput) {
      return false;
    }
    return applyWaveRange(panelId, startInput.value, endInput.value);
  }

  function applyWaveZoomLevel(panelId, value) {
    return applyWaveVisibleSlots(panelId, Number(value));
  }

  function syncWaveViewportControlDescriptor(descriptor) {
    if (!descriptor) {
      return;
    }
    const controls = waveRangeControlsForPanel(descriptor.panelId || "");
    if (!controls) {
      return;
    }
    const startInput = controls.querySelector("[data-wave-range-start]");
    const endInput = controls.querySelector("[data-wave-range-end]");
    const zoomSelect = controls.querySelector('[data-action="wave-zoom-level"]');
    if (startInput) {
      startInput.min = String(descriptor.minCycle);
      startInput.max = String(descriptor.maxCycle);
      startInput.value = String(descriptor.cycleStart);
    }
    if (endInput) {
      endInput.min = String(descriptor.minCycle);
      endInput.max = String(descriptor.maxCycle);
      endInput.value = String(descriptor.cycleEnd);
    }
    if (zoomSelect) {
      const value = String(descriptor.visibleSlots);
      if (Array.from(zoomSelect.options).some((option) => option.value === value)) {
        zoomSelect.value = value;
      }
    }
  }

  function syncWaveViewportControls() {
    if (state.surfaceMode !== "wave" || !hasWaveSurface()) {
      return;
    }
    if (usesSharedWaveViewport()) {
      syncWaveViewportControlDescriptor(sharedWaveViewportDescriptor(currentSharedWaveState()));
      return;
    }
    visibleWavePanels().forEach((panel) => {
      syncWaveViewportControlDescriptor(panelWaveViewportDescriptor(panel, state.wavePanelState[panel.panelId]));
    });
  }

  function ensureWaveState() {
    ensureWaveSourceSelection();
    ensureSharedWaveState();
    currentWavePanels().forEach((panel) => {
      if (!state.wavePanelState[panel.panelId]) {
        state.wavePanelState[panel.panelId] = defaultWavePanelState(panel);
      }
      state.wavePanelState[panel.panelId] = normalizeWavePanelState(panel, state.wavePanelState[panel.panelId]);
    });
  }

  function currentWaveScrollKey() {
    return [state.lane, state.waveSourceId || "default"].join("::");
  }

  function escapeHtml(text) {
    return String(text == null ? "" : text)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;");
  }

  function render(intent) {
    const renderIntent = normalizeRenderIntent(intent);
    const snapshot = captureUiSnapshot(renderIntent);
    performRender(renderIntent);
    scheduleUiTransition(snapshot);
  }

  function performRender(renderIntent) {
    debugState.renderCount += 1;
    ensureSectionSelection();
    ensureSurfaceSelection();
    ensureWaveState();
    ensureFrameSelection();
    captureCurrentScrollPositions();

    if (state.fatalError) {
      root.className = rootClassName(renderIntent);
      root.innerHTML = `<div class="window"><div class="shell"><div class="window-title"><span>${escapeHtml(manifest.meta.title || "Packet Analyzer")}</span><small>Fatal load error</small></div><div class="content"><section class="trace-panel" data-anim-key="primary-surface" data-anim-role="surface"><div class="panel-title"><span>Load Failure</span></div><div class="scroll-shell trace-scroll-shell"><div class="trace-scroll" data-role="trace-scroll" data-scroll-sync="trace"><div class="empty-state">${escapeHtml(state.fatalError)}</div></div>${renderPersistentScrollbar("trace", "Packet Trace", "y")}${renderPersistentScrollbar("trace", "Packet Trace", "x")}</div></section></div></div></div>`;
      scheduleScrollbarSync();
      return;
    }

    ensureSelection();
    const lane = currentLane();
    const visible = visiblePackets();
    const selected = selectedPacket();
    const selectedField = ensureSelectedField(selected);
    const prevScrollTop = state.lastScrollTopByLane[state.lane] || 0;
    const prevScrollLeft = state.lastScrollLeftByLane[state.lane] || 0;
    const prevSideScrollTop = state.lastSideScrollTopByTab[state.viewTab] || 0;
    const prevSideScrollLeft = state.lastSideScrollLeftByTab[state.viewTab] || 0;
    const prevWaveScrollTop = state.lastWaveScrollTopByKey[currentWaveScrollKey()] || 0;
    const loadingCurrentLane = state.loadingLane === state.lane || (!laneDataMap.has(state.lane) && !!currentLaneInfo().laneScript);
    const visibleCountLabel = loadingCurrentLane && !visible.length ? "loading..." : String(visible.length);
    const title = (manifest.meta && manifest.meta.title) || "Packet Analyzer";
    const subtitle = (manifest.meta && manifest.meta.subtitle) || "";

    root.className = rootClassName(renderIntent);
    root.innerHTML = `
      <div class="window">
        <div class="shell ${state.wrap ? "wrap-enabled" : ""}">
          <div class="window-title">
            <span>${escapeHtml(title)}</span>
            <small>${escapeHtml(subtitle)}</small>
          </div>
          <div class="summary-bar">
            ${summaryCard("Source", currentCaseLabel(), currentCaseDescription())}
            ${summaryCard("Frames", state.frameFilter ? ("F" + String(state.frameFilter)) : ("F" + (((lane.frameIds || []).join(", F")) || "n/a")))}
            ${summaryCard("Section", currentSectionLabel())}
            ${summaryCard("Visible Rows", visibleCountLabel)}
            ${summaryCard("Spec", (manifest.meta && manifest.meta.specReference) || "n/a")}
            ${summaryCard("Decode", decodeModeLabel(state.decodeMode))}
          </div>
          <div class="toolbar">${renderPrimaryToolbar()}</div>
          <div class="surface-switch">
            ${renderSurfaceSelector()}
          </div>
          <div class="content">
            ${renderPrimarySurface(visible, loadingCurrentLane)}
            <section class="side-panel" data-anim-key="side-panel" data-anim-role="panel">
              <div>
                <div class="side-tabs">
                  ${renderTab("spec", "Spec View")}
                  ${renderTab("details", "Details View")}
                  ${renderTab("tracker", "Link Tracker")}
                </div>
              </div>
              <div class="scroll-shell side-body-shell">
                <div class="side-body" data-scroll-sync="side">
                  <div class="side-panel-view" data-anim-key="${animationKey("side-view", selected ? state.viewTab : "empty")}" data-anim-role="side-view">
                    ${selected ? renderSidePanel(selected, visible, selectedField) : '<div class="empty-state">Select a frame or subpacket row to inspect the decoded words.</div>'}
                  </div>
                </div>
                ${renderPersistentScrollbar("side", "Details", "y")}
                ${renderPersistentScrollbar("side", "Details", "x")}
              </div>
            </section>
          </div>
          <div class="status-bar">
            <span class="status-pill">Lane: ${escapeHtml(currentLaneInfo().label || "Current Lane")}</span>
            <span class="status-pill">Loaded: ${escapeHtml(loadedLaneLabels().join(", ") || "None")}</span>
            <span class="status-pill">Section: ${escapeHtml(currentSectionLabel())}</span>
            <span class="status-pill">Surface: ${escapeHtml(surfaceModeLabel())}</span>
            <span class="status-pill">Selection: ${escapeHtml(selectedStatusLabel(selected))}</span>
            <span class="status-pill">Update: ${escapeHtml(updateModeLabel())}</span>
            <span class="status-pill">Tracker: ${escapeHtml(trackerStatusLabel())}</span>
            <span class="status-pill">Generated: ${escapeHtml(generatedStatusLabel())}</span>
          </div>
          ${debugMode ? renderDebugOverlay(selected, visible) : ""}
        </div>
      </div>
    `;

    const scroller = root.querySelector('[data-role="trace-scroll"]');
    if (scroller) {
      scroller.scrollTop = prevScrollTop;
      scroller.scrollLeft = prevScrollLeft;
    }
    const sideBody = root.querySelector(".side-body");
    if (sideBody) {
      sideBody.scrollTop = prevSideScrollTop;
      sideBody.scrollLeft = prevSideScrollLeft;
    }
    const waveStack = root.querySelector(".wave-panel-stack");
    if (waveStack) {
      waveStack.scrollTop = prevWaveScrollTop;
    }
    if (state.waveScrollRestore && state.waveScrollRestore.key === currentWaveScrollKey()) {
      state.waveScrollRestore = null;
    }
    if (state.surfaceMode === "wave") {
      scheduleWaveRender();
    }
    schedulePendingFieldSync();
    scheduleScrollbarSync();
  }

  function captureCurrentScrollPositions() {
    const traceScroller = root.querySelector('[data-role="trace-scroll"]');
    if (traceScroller) {
      state.lastScrollTopByLane[state.lane] = traceScroller.scrollTop;
      state.lastScrollLeftByLane[state.lane] = traceScroller.scrollLeft;
    }
    const sideBody = root.querySelector(".side-body");
    if (sideBody) {
      state.lastSideScrollTopByTab[state.viewTab] = sideBody.scrollTop;
      state.lastSideScrollLeftByTab[state.viewTab] = sideBody.scrollLeft;
    }
    const waveStack = root.querySelector(".wave-panel-stack");
    if (waveStack) {
      const key = currentWaveScrollKey();
      if (state.waveScrollRestore && state.waveScrollRestore.key === key) {
        state.lastWaveScrollTopByKey[key] = state.waveScrollRestore.top;
      } else {
        state.lastWaveScrollTopByKey[key] = waveStack.scrollTop;
      }
    }
  }

  function rememberWaveScrollForInteraction() {
    const waveStack = root.querySelector(".wave-panel-stack");
    if (!waveStack) {
      return;
    }
    state.waveScrollRestore = {
      key: currentWaveScrollKey(),
      top: waveStack.scrollTop,
    };
  }

  function scrollSyncElement(scrollId) {
    if (scrollId === "trace") {
      return root.querySelector('[data-role="trace-scroll"]');
    }
    if (scrollId === "side") {
      return root.querySelector(".side-body");
    }
    if (scrollId === "wave") {
      return root.querySelector(".wave-panel-stack");
    }
    return null;
  }

  function scrollRailElement(scrollId, axis) {
    const axisValue = axis || "y";
    return root.querySelector(`[data-scroll-rail="${CSS.escape(scrollId)}"][data-scroll-axis="${CSS.escape(axisValue)}"]`);
  }

  function scrollThumbElement(scrollId, axis) {
    const axisValue = axis || "y";
    return root.querySelector(`[data-scroll-thumb="${CSS.escape(scrollId)}"][data-scroll-axis="${CSS.escape(axisValue)}"]`);
  }

  function scheduleScrollbarSync() {
    if (!persistentScrollbars) {
      return;
    }
    if (scrollbarSyncRaf) {
      window.cancelAnimationFrame(scrollbarSyncRaf);
    }
    scrollbarSyncRaf = window.requestAnimationFrame(() => {
      scrollbarSyncRaf = 0;
      syncAllPersistentScrollbars();
    });
  }

  function syncAllPersistentScrollbars() {
    ["trace", "side", "wave"].forEach(syncPersistentScrollbar);
  }

  function syncPersistentScrollbar(scrollId, axis) {
    if (!axis) {
      syncPersistentScrollbar(scrollId, "y");
      syncPersistentScrollbar(scrollId, "x");
      return;
    }
    const scroller = scrollSyncElement(scrollId);
    const rail = scrollRailElement(scrollId, axis);
    const thumb = scrollThumbElement(scrollId, axis);
    if (!scroller || !rail || !thumb) {
      return;
    }
    const isHorizontal = axis === "x";
    const trackSize = isHorizontal ? (rail.clientWidth || 0) : (rail.clientHeight || 0);
    if (!trackSize) {
      if (isHorizontal) {
        thumb.style.width = "0px";
        thumb.style.transform = "translateX(0px)";
      } else {
        thumb.style.height = "0px";
        thumb.style.transform = "translateY(0px)";
      }
      rail.classList.remove("is-scrollable");
      return;
    }
    const clientSize = Math.max(1, isHorizontal ? (scroller.clientWidth || 0) : (scroller.clientHeight || 0));
    const scrollSize = Math.max(clientSize, isHorizontal ? (scroller.scrollWidth || 0) : (scroller.scrollHeight || 0));
    const currentOffset = Math.max(0, isHorizontal ? scroller.scrollLeft : scroller.scrollTop);
    const maxScroll = Math.max(0, scrollSize - clientSize);
    const minThumb = Math.min(trackSize, 34);
    const thumbSize = maxScroll > 0 ? Math.max(minThumb, Math.round((clientSize / scrollSize) * trackSize)) : trackSize;
    const travel = Math.max(0, trackSize - thumbSize);
    const thumbOffset = maxScroll > 0 && travel > 0 ? Math.round((currentOffset / maxScroll) * travel) : 0;
    rail.classList.toggle("is-scrollable", maxScroll > 0);
    rail.dataset.scrollId = scrollId;
    rail.dataset.scrollAxis = axis;
    rail.dataset.scrollOffset = String(currentOffset);
    rail.dataset.scrollSize = String(scrollSize);
    rail.dataset.clientSize = String(clientSize);
    if (isHorizontal) {
      thumb.style.width = `${thumbSize}px`;
      thumb.style.transform = `translateX(${thumbOffset}px)`;
    } else {
      thumb.style.height = `${thumbSize}px`;
      thumb.style.transform = `translateY(${thumbOffset}px)`;
    }
  }

  function scrollFromRailPosition(scrollId, axis, thumbOffset) {
    const scroller = scrollSyncElement(scrollId);
    const rail = scrollRailElement(scrollId, axis);
    const thumb = scrollThumbElement(scrollId, axis);
    if (!scroller || !rail || !thumb) {
      return;
    }
    const isHorizontal = axis === "x";
    const maxScroll = Math.max(0, isHorizontal ? ((scroller.scrollWidth || 0) - (scroller.clientWidth || 0)) : ((scroller.scrollHeight || 0) - (scroller.clientHeight || 0)));
    const thumbSize = isHorizontal ? thumb.offsetWidth : thumb.offsetHeight;
    const railSize = isHorizontal ? rail.clientWidth : rail.clientHeight;
    const travel = Math.max(0, railSize - thumbSize);
    if (maxScroll <= 0 || travel <= 0) {
      if (isHorizontal) {
        scroller.scrollLeft = 0;
      } else {
        scroller.scrollTop = 0;
      }
      syncPersistentScrollbar(scrollId, axis);
      return;
    }
    const boundedOffset = Math.max(0, Math.min(travel, thumbOffset));
    if (isHorizontal) {
      scroller.scrollLeft = (boundedOffset / travel) * maxScroll;
    } else {
      scroller.scrollTop = (boundedOffset / travel) * maxScroll;
    }
    syncPersistentScrollbar(scrollId, axis);
  }

  function elementOffsetWithinScroller(scroller, target) {
    if (!scroller || !target) {
      return { left: 0, top: 0 };
    }
    let left = 0;
    let top = 0;
    let node = target;
    while (node && node !== scroller) {
      left += node.offsetLeft || 0;
      top += node.offsetTop || 0;
      node = node.offsetParent;
    }
    if (node === scroller) {
      return { left: left, top: top };
    }
    const scrollerRect = scroller.getBoundingClientRect();
    const targetRect = target.getBoundingClientRect();
    return {
      left: scroller.scrollLeft + (targetRect.left - scrollerRect.left),
      top: scroller.scrollTop + (targetRect.top - scrollerRect.top),
    };
  }

  function centerElementInScroller(scroller, target, options) {
    if (!scroller || !target) {
      return;
    }
    const vertical = !options || options.vertical !== false;
    const horizontal = !options || options.horizontal !== false;
    const offset = elementOffsetWithinScroller(scroller, target);
    let nextTop = scroller.scrollTop;
    let nextLeft = scroller.scrollLeft;
    if (vertical) {
      nextTop = Math.max(0, Math.min(Math.max(0, scroller.scrollHeight - scroller.clientHeight), offset.top + target.offsetHeight / 2 - scroller.clientHeight / 2));
    }
    if (horizontal) {
      nextLeft = Math.max(0, Math.min(Math.max(0, scroller.scrollWidth - scroller.clientWidth), offset.left + target.offsetWidth / 2 - scroller.clientWidth / 2));
    }
    scroller.scrollTop = nextTop;
    scroller.scrollLeft = nextLeft;
  }

  function centerDeltaInScroller(scroller, target) {
    if (!scroller || !target) {
      return { x: 0, y: 0 };
    }
    const offset = elementOffsetWithinScroller(scroller, target);
    return {
      x: (offset.left + target.offsetWidth / 2) - (scroller.scrollLeft + scroller.clientWidth / 2),
      y: (offset.top + target.offsetHeight / 2) - (scroller.scrollTop + scroller.clientHeight / 2),
    };
  }

  function loadedLaneLabels() {
    return (manifest.lanes || [])
      .filter((laneInfo) => laneDataMap.has(String(laneInfo.lane)) || laneDataMap.has(laneInfo.lane))
      .map((laneInfo) => laneInfo.label || ("Lane " + laneInfo.lane));
  }

  function surfaceModeLabel() {
    return state.surfaceMode === "wave" ? waveSurfaceLabel() : "Packet Trace";
  }

  function updateModeLabel() {
    return state.updateMode === "scroll" ? "Update On Scroll" : "Update On Click";
  }

  function trackerStatusLabel() {
    const formatMap = {
      fields: "Fields",
      hex: "Raw Hex",
      bin: "Raw Bin",
      desc: "Description",
    };
    return (formatMap[state.trackerFormat] || state.trackerFormat) + " / " + state.trackerDensity;
  }

  function selectedStatusLabel(packet) {
    if (!packet) {
      return "None";
    }
    const kindLabel = packet.kindLabel || packet.rowType || "Row";
    const packetLabel = packet.packetLabel || "";
    if (!packetLabel || packetLabel === kindLabel) {
      return kindLabel;
    }
    if (packet.rowType === "frame") {
      return packetLabel;
    }
    return `${kindLabel} (${packetLabel})`;
  }

  function packetLaneLabel(packet) {
    if (!packet) {
      return "n/a";
    }
    if (packet.lane === -1 || String(packet.lane) === "-1") {
      return "All Lanes";
    }
    return `Lane ${packet.lane}`;
  }

  function packetFrameLabel(packet) {
    if (!packet || packet.frameId == null || String(packet.frameId) === "") {
      return "Frame n/a";
    }
    return `Frame F${packet.frameId}`;
  }

  function generatedStatusLabel() {
    const raw = (manifest.meta && manifest.meta.generatedAt) || "";
    if (!raw) {
      return "n/a";
    }
    const parsed = new Date(raw);
    if (Number.isNaN(parsed.getTime())) {
      return raw;
    }
    return parsed.toLocaleString();
  }

  function summaryCard(label, value, tooltip) {
    const text = value || "n/a";
    const titleText = tooltip || text;
    const tooltipAttr = tooltip ? ` data-tooltip="${escapeHtml(tooltip)}"` : "";
    return `<div class="summary-card"><strong>${escapeHtml(label)}</strong><span class="summary-value" title="${escapeHtml(titleText)}"${tooltipAttr}>${escapeHtml(text)}</span></div>`;
  }

  function renderPersistentScrollbar(id, label, axis) {
    if (!persistentScrollbars) {
      return "";
    }
    const axisValue = axis || "y";
    const ariaLabel = `${label} ${axisValue === "x" ? "horizontal" : "vertical"} scrollbar`;
    return `
      <div class="persistent-scrollbar persistent-scrollbar-${escapeHtml(axisValue)}" data-scroll-rail="${escapeHtml(id)}" data-scroll-axis="${escapeHtml(axisValue)}" aria-label="${escapeHtml(ariaLabel)}">
        <div class="persistent-scroll-thumb" data-scroll-thumb="${escapeHtml(id)}" data-scroll-axis="${escapeHtml(axisValue)}"></div>
      </div>
    `;
  }

  function renderPrimaryToolbar() {
    const sourceOptions = waveSources()
      .map((source) => `<option value="${escapeHtml(source.id)}" ${source.id === state.waveSourceId ? "selected" : ""}>${escapeHtml(source.label)}</option>`)
      .join("");
    const caseDescription = currentCaseDescription();
    const sectionOptions = availableSections()
      .map((section) => `<option value="${escapeHtml(section.id)}" ${section.id === state.sectionFilter ? "selected" : ""}>${escapeHtml(section.label)}</option>`)
      .join("");
    const frameOptions = availableFrameIds()
      .map((frameId) => `<option value="${escapeHtml(frameId)}" ${String(state.frameFilter) === String(frameId) ? "selected" : ""}>F${escapeHtml(frameId)}</option>`)
      .join("");
    const laneOptions = (manifest.lanes || [])
      .map((lane) => `<option value="${escapeHtml(String(lane.lane))}" ${String(lane.lane) === state.lane ? "selected" : ""}>${escapeHtml(lane.label || ("Lane " + lane.lane))}</option>`)
      .join("");
    const decodeOptions = (manifest.decodeModes || [])
      .map((mode) => `<option value="${escapeHtml(mode.id)}" ${mode.id === state.decodeMode ? "selected" : ""}>${escapeHtml(mode.label)}</option>`)
      .join("");
    return `
      ${caseCatalogEntries().length ? `
      <div class="toolbar-group">
        <span class="toolbar-label">Source</span>
        <select class="tool-select" data-action="case-change">${renderCaseOptions()}</select>
        ${caseDescription ? `<span class="tool-info-badge" data-tooltip="${escapeHtml(caseDescription)}">i</span>` : ""}
      </div>` : ""}
      <div class="toolbar-group">
        <span class="toolbar-label">Lane</span>
        <select class="tool-select" data-action="lane-change">${laneOptions}</select>
      </div>
      ${waveSources().length > 1 ? `
      <div class="toolbar-group">
        <span class="toolbar-label">Interface</span>
        <select class="tool-select" data-action="source-change">${sourceOptions}</select>
      </div>` : ""}
      ${availableFrameIds().length > 1 ? `
      <div class="toolbar-group">
        <span class="toolbar-label">Frame</span>
        <select class="tool-select" data-action="frame-change">
          <option value="" ${!state.frameFilter ? "selected" : ""}>All Frames</option>
          ${frameOptions}
        </select>
      </div>` : ""}
      ${availableSections().length > 1 ? `
      <div class="toolbar-group">
        <span class="toolbar-label">Section</span>
        <select class="tool-select" data-action="section-change">
          <option value="all" ${state.sectionFilter === "all" ? "selected" : ""}>${escapeHtml(SECTION_LABELS.all)}</option>
          ${sectionOptions}
        </select>
      </div>` : ""}
      <div class="toolbar-group">
        <span class="toolbar-label">Decode</span>
        <select class="tool-select" data-action="decode-change">${decodeOptions}</select>
      </div>
      <div class="toolbar-group">
        <span class="toolbar-label">Visible Rows</span>
        <select class="tool-select" data-action="row-visibility-change">
          <option value="all" ${rowVisibilityPresetValue() === "all" ? "selected" : ""}>All Rows</option>
          <option value="frames" ${rowVisibilityPresetValue() === "frames" ? "selected" : ""}>Frames Only</option>
          <option value="subpackets" ${rowVisibilityPresetValue() === "subpackets" ? "selected" : ""}>SubPkts Only</option>
          <option value="custom" ${rowVisibilityPresetValue() === "custom" ? "selected" : ""}>Custom</option>
        </select>
        ${FAMILY_ORDER.map((family) => renderToolbarToggle("family-toggle", family, FAMILY_LABELS[family], state.familyFilters[family])).join("")}
      </div>
      <div class="toolbar-group">
        <span class="toolbar-label">Behavior</span>
        ${renderToolbarToggle("wrap-toggle", "wrap", "Wrap", state.wrap)}
        ${renderToolbarToggle("update-mode", "click", "Update On Click", state.updateMode === "click")}
        ${renderToolbarToggle("update-mode", "scroll", "Update On Scroll", state.updateMode === "scroll")}
      </div>
    `;
  }

  function renderSurfaceSelector() {
    const toggles = [
      renderToolbarToggle("surface-mode", "trace", "Packet Trace", state.surfaceMode === "trace"),
    ];
    if (hasWaveSurface()) {
      toggles.push(renderToolbarToggle("surface-mode", "wave", waveSurfaceLabel(), state.surfaceMode === "wave"));
    }
    return toggles.join("");
  }

  function renderPrimarySurface(visible, loadingCurrentLane) {
    if (state.surfaceMode === "wave" && hasWaveSurface()) {
      return renderWaveSurface();
    }
    return renderTraceSurface(visible, loadingCurrentLane);
  }

  function renderToolbarToggle(action, value, label, active) {
    return `<button class="tool-button ${active ? "active" : ""}" type="button" data-action="${escapeHtml(action)}" data-value="${escapeHtml(value)}">${escapeHtml(label)}</button>`;
  }

  function renderTraceSurface(visible, loadingCurrentLane) {
    return `
      <section class="trace-panel" data-anim-key="primary-surface" data-anim-role="surface">
        <div class="panel-title">
          <span>Packet Trace</span>
          <span class="hint">${escapeHtml(currentLaneInfo().label || "Lane")} | frame packet rows expand into integral subpackets</span>
        </div>
        <div class="scroll-shell trace-scroll-shell">
          <div class="trace-scroll" data-role="trace-scroll" data-scroll-sync="trace">
            ${renderTracePanelBody(visible, loadingCurrentLane)}
          </div>
          ${renderPersistentScrollbar("trace", "Packet Trace", "y")}
          ${renderPersistentScrollbar("trace", "Packet Trace", "x")}
        </div>
      </section>
    `;
  }

  function renderWaveSurface() {
    const panels = visibleWavePanels();
    if (!panels.length) {
      return "";
    }
    const sources = waveSources();
    const sharedWave = usesSharedWaveViewport() ? currentSharedWaveState() : null;
    return `
      <section class="wave-surface" data-anim-key="primary-surface" data-anim-role="surface">
        <div class="panel-title wave-title">
          <span>${escapeHtml(waveSurfaceLabel())}</span>
          <span class="hint">${escapeHtml(waveSurfaceHint())}</span>
        </div>
        ${renderWaveSurfaceControls(sources, sharedWave)}
        <div class="scroll-shell wave-panel-stack-shell">
          <div class="wave-panel-stack" data-scroll-sync="wave">
            ${panels.map((panel) => renderWavePanelShell(panel)).join("")}
          </div>
          ${renderPersistentScrollbar("wave", "Waveform Correlation", "y")}
        </div>
      </section>
    `;
  }

  function renderWaveSurfaceControls(sources, sharedWave) {
    if ((!sources || sources.length <= 1) && !sharedWave) {
      return '<div class="wave-source-bar wave-source-bar-empty" aria-hidden="true"></div>';
    }
    return `
      <div class="wave-source-bar">
        ${sources && sources.length > 1 ? renderWaveSourceSelector(sources) : ""}
        ${sharedWave ? renderWaveViewportControls("", sharedWaveViewportDescriptor(sharedWave)) : ""}
      </div>
    `;
  }

  function renderWaveSourceSelector(sources) {
    const options = sources
      .map((source) => `<option value="${escapeHtml(source.id)}" ${source.id === state.waveSourceId ? "selected" : ""}>${escapeHtml(source.label)}</option>`)
      .join("");
    return `
      <div class="toolbar-group">
        <span class="toolbar-label">Interface</span>
        <select class="tool-select" data-action="wave-source-change">${options}</select>
      </div>
    `;
  }

  function renderWaveViewportControls(panelId, descriptor) {
    if (!descriptor) {
      return "";
    }
    const choices = descriptor.choices && descriptor.choices.length ? descriptor.choices : [descriptor.visibleSlots || 16];
    const zoomOptions = choices
      .map((choice) => `<option value="${escapeHtml(String(choice))}" ${choice === descriptor.visibleSlots ? "selected" : ""}>${escapeHtml(String(choice))} cyc</option>`)
      .join("");
    const panelAttr = escapeHtml(panelId || "");
    return `
      <div class="wave-range-controls" data-wave-controls="${escapeHtml(descriptor.controlKey)}">
        <span class="toolbar-label">Cycles</span>
        <input class="tool-input wave-cycle-input" type="number" inputmode="numeric" data-wave-range-start data-panel-id="${panelAttr}" min="${escapeHtml(String(descriptor.minCycle))}" max="${escapeHtml(String(descriptor.maxCycle))}" value="${escapeHtml(String(descriptor.cycleStart))}" aria-label="Wave cycle start">
        <span class="wave-range-separator">..</span>
        <input class="tool-input wave-cycle-input" type="number" inputmode="numeric" data-wave-range-end data-panel-id="${panelAttr}" min="${escapeHtml(String(descriptor.minCycle))}" max="${escapeHtml(String(descriptor.maxCycle))}" value="${escapeHtml(String(descriptor.cycleEnd))}" aria-label="Wave cycle end">
        <button class="tool-button subtle" type="button" data-action="wave-range-apply" data-panel-id="${panelAttr}">Apply</button>
        <button class="tool-button subtle" type="button" data-action="wave-range-auto" data-panel-id="${panelAttr}">Auto</button>
        <span class="toolbar-label">Zoom</span>
        <select class="tool-select wave-zoom-select" data-action="wave-zoom-level" data-panel-id="${panelAttr}">${zoomOptions}</select>
      </div>
    `;
  }

  function defaultWaveLegend(panel) {
    if (panel && panel.panelId === "dma") {
      return [
        { label: "DMA Word", color: waveBeatTone("header").fill },
      ];
    }
    return [
      { label: "Header", color: waveBeatTone("header").fill },
      { label: "Subheader", color: waveBeatTone("subheader").fill },
      { label: "Hit", color: waveBeatTone("hit").fill },
      { label: "Trailer", color: waveBeatTone("trailer").fill },
    ];
  }

  function renderWaveLegend(panel) {
    const items = (panel.legend && panel.legend.length ? panel.legend : defaultWaveLegend(panel)) || [];
    if (!items.length) {
      return "";
    }
    return `
      <div class="wave-legend">
        ${items.map((item) => `<span><i style="background:${escapeHtml(item.color)}"></i>${escapeHtml(item.label)}</span>`).join("")}
      </div>
    `;
  }

  function wavePanelSubtitle(panel) {
    const subtitle = String((panel && panel.subtitle) || "").trim();
    if (!subtitle || subtitle === "Recovered legacy WaveDrom panel view") {
      return "Waveform panel";
    }
    return subtitle;
  }

  function renderWavePanelShell(panel) {
    if (panel.legacyMode) {
      return renderLegacyWavePanelShell(panel);
    }
    const sharedWave = usesSharedWaveViewport() ? currentSharedWaveState() : null;
    const waveState = sharedWave || normalizeWavePanelState(panel, state.wavePanelState[panel.panelId]);
    const cycleStop = sharedWave ? sharedWave.cycleStart + Math.max(0, sharedWave.visibleSlots - 1) : null;
    return `
      <section class="wave-panel" data-panel-id="${escapeHtml(panel.panelId)}" data-anim-key="${animationKey("wave-panel", panel.panelId)}" data-anim-role="wave-panel">
        <div class="wave-panel-head">
          <div>
            <h3>${escapeHtml(panel.title)}</h3>
            <p>${escapeHtml(wavePanelSubtitle(panel))}${panel.sourceLabel ? ` | ${escapeHtml(panel.sourceLabel)}` : ""}</p>
          </div>
          <div class="wave-toolbar">
            <button class="tool-button subtle" type="button" data-action="wave-prev" data-panel-id="${escapeHtml(panel.panelId)}">Prev</button>
            <div class="wave-status" data-wave-status="${escapeHtml(panel.panelId)}">${sharedWave ? `Shared cycles ${sharedWave.cycleStart}..${cycleStop} | view ${sharedWave.visibleSlots} cyc` : `Chunk ${waveState.chunkIndex + 1}/${panel.chunkCount} | view ${waveState.visibleSlots} cyc`}</div>
            <button class="tool-button subtle" type="button" data-action="wave-next" data-panel-id="${escapeHtml(panel.panelId)}">Next</button>
            <button class="tool-button subtle" type="button" data-action="wave-zoom-out" data-panel-id="${escapeHtml(panel.panelId)}">-</button>
            <button class="tool-button subtle" type="button" data-action="wave-zoom-reset" data-panel-id="${escapeHtml(panel.panelId)}">Reset</button>
            <button class="tool-button subtle" type="button" data-action="wave-zoom-in" data-panel-id="${escapeHtml(panel.panelId)}">+</button>
          </div>
        </div>
        ${sharedWave ? "" : renderWaveViewportControls(panel.panelId, panelWaveViewportDescriptor(panel, waveState))}
        ${renderWaveLegend(panel)}
        <div class="wave-display-wrap">
          <div class="wave-display" id="WaveDrom_Display_${escapeHtml(String(panel.renderIndex))}" data-wave-panel-display="${escapeHtml(panel.panelId)}">
            <div class="wave-render-status">Loading chunk...</div>
          </div>
        </div>
        <div class="wave-decode-shell" data-wave-decode="${escapeHtml(panel.panelId)}"></div>
        <div class="wave-annotation-shell" data-wave-annotations="${escapeHtml(panel.panelId)}"></div>
      </section>
    `;
  }

  function renderLegacyWavePanelShell(panel) {
    const sharedWave = usesSharedWaveViewport() ? currentSharedWaveState() : null;
    const waveState = sharedWave || normalizeWavePanelState(panel, state.wavePanelState[panel.panelId]);
    const cycleStop = sharedWave ? sharedWave.cycleStart + Math.max(0, sharedWave.visibleSlots - 1) : null;
    return `
      <section class="wave-panel wave-panel-legacy" data-panel-id="${escapeHtml(panel.panelId)}" data-anim-key="${animationKey("wave-panel", panel.panelId)}" data-anim-role="wave-panel">
        <div class="wave-panel-head">
          <div>
            <h3>${escapeHtml(panel.title)}</h3>
            <p>${escapeHtml(wavePanelSubtitle(panel))}${panel.sourceLabel ? ` | ${escapeHtml(panel.sourceLabel)}` : ""}</p>
          </div>
          <div class="wave-toolbar">
            <button class="tool-button subtle" type="button" data-action="wave-prev" data-panel-id="${escapeHtml(panel.panelId)}">Prev</button>
            <div class="wave-status" data-wave-status="${escapeHtml(panel.panelId)}">${sharedWave ? `Shared cycles ${sharedWave.cycleStart}..${cycleStop} | view ${sharedWave.visibleSlots} cyc` : `Chunk ${waveState.chunkIndex + 1}/${panel.chunkCount} | view ${waveState.visibleSlots} cyc`}</div>
            <button class="tool-button subtle" type="button" data-action="wave-next" data-panel-id="${escapeHtml(panel.panelId)}">Next</button>
            <button class="tool-button subtle" type="button" data-action="wave-zoom-out" data-panel-id="${escapeHtml(panel.panelId)}">-</button>
            <button class="tool-button subtle" type="button" data-action="wave-zoom-reset" data-panel-id="${escapeHtml(panel.panelId)}">Reset</button>
            <button class="tool-button subtle" type="button" data-action="wave-zoom-in" data-panel-id="${escapeHtml(panel.panelId)}">+</button>
          </div>
        </div>
        ${sharedWave ? "" : renderWaveViewportControls(panel.panelId, panelWaveViewportDescriptor(panel, waveState))}
        ${renderWaveLegend(panel)}
        <div class="wave-display-wrap">
          <div class="wave-display" id="WaveDrom_Display_${escapeHtml(String(panel.renderIndex))}" data-wave-panel-display="${escapeHtml(panel.panelId)}">
            <div class="wave-render-status">Loading chunk...</div>
          </div>
        </div>
        <div class="wave-decode-shell" data-wave-decode="${escapeHtml(panel.panelId)}"></div>
      </section>
    `;
  }

  function renderTracePanelBody(visible, loadingCurrentLane) {
    if (loadingCurrentLane && !visible.length) {
      return `<div class="empty-state">Loading ${escapeHtml(currentLaneInfo().label || state.lane)} payload script...</div>`;
    }
    if (!visible.length) {
      return '<div class="empty-state">Current filters hide every visible row for this lane selection.</div>';
    }
    return `<div class="trace-list">${visible.map((packet) => renderTraceRow(packet)).join("")}</div>`;
  }

  function renderTraceRow(packet) {
    const selected = packet.rowId === state.selectedRowId;
    const visibleFields = getOrderedFields(packet).filter((field) => {
      const linkKey = fieldLinkKey(field);
      return !isHiddenDefault(packet, field.id) || isRowSelectedField(packet.rowId, linkKey);
    });
    const hiddenCount = getOrderedFields(packet).length - visibleFields.length;
    const fields = visibleFields.slice();
    const linkedDetail = selected ? findSelectedWordField(packet) : null;
    if (linkedDetail && !fields.some((field) => fieldLinkKey(field) === linkedDetail.key)) {
      fields.push(buildLinkedTraceField(linkedDetail));
    }
    const depthClass = packet.depth > 0 ? "trace-row-nested" : "";
    const packetCardLabel = packet.rowType === "frame" ? "Packet" : packet.rowType === "hit" ? "Hit" : "SubPkt";
    const cardToneFamily = packet.rowType === "hit" ? "hit" : packet.kindFamily;
    return `
      <div class="trace-row ${selected ? "selected" : ""} ${depthClass}" data-role="trace-row" data-row-id="${escapeHtml(packet.rowId)}" data-anim-key="${animationKey("trace-row", packet.rowId)}" data-anim-role="trace-row" style="--trace-depth:${packet.depth || 0}">
        <div class="row-controls">
          ${packet.expandable ? `<button class="tool-button subtle row-expander" type="button" data-action="toggle-row" data-row-id="${escapeHtml(packet.rowId)}" data-kind="${escapeHtml(packet.kind)}">${state.expandedRows.has(packet.rowId) ? "▾" : "▸"}</button>` : '<span class="row-spacer"></span>'}
          ${renderFixedCard(packetCardLabel, packet.packetLabel || packet.kindLabel, cardToneFamily)}
          ${renderFixedCard("Kind", packet.kindLabel, cardToneFamily)}
          ${renderFixedCard("Lane", String(packet.lane), cardToneFamily)}
          ${renderFixedCard("Time", relativeTimeLabel(packet), cardToneFamily)}
        </div>
        <div class="trace-fields">
          ${fields.map((field) => renderFieldCard(packet, field)).join("")}
        </div>
        <div class="decode-note">
          ${escapeHtml(packet.decodeSummaryByMode[state.decodeMode])}
          ${hiddenCount > 0 ? ` | ${hiddenCount} hidden field${hiddenCount === 1 ? "" : "s"}` : ""}
        </div>
      </div>
    `;
  }

  function fixedTone(family) {
    const map = {
      frame: { label: "#b8cffb", value: "#f0f5ff", text: "#172d5c", border: "#8ca5d1" },
      subpacket: { label: "#d7c8f1", value: "#faf6ff", text: "#44305c", border: "#a89ac1" },
      hit: { label: "#b7e6c6", value: "#eefcf2", text: "#1f4a2b", border: "#81b793" },
    };
    return map[family] || map.frame;
  }

  function renderFixedCard(label, value, family) {
    const tone = fixedTone(family);
    return `
      <div class="fixed-card" style="border-color:${tone.border}; background:${tone.value};">
        <div class="fixed-label" style="background:${tone.label}; color:${tone.text}; border-bottom-color:${tone.border};">${escapeHtml(label)}</div>
        <div class="fixed-value" style="background:${tone.value}; color:${tone.text};">${escapeHtml(value)}</div>
      </div>
    `;
  }

  function renderFieldCard(packet, field) {
    const tooltip = [
      field.label + " " + (field.bits || ""),
      field.cardValue || field.valueHex || "",
      field.description || "",
    ].filter(Boolean).join(" | ");
    const linkKey = fieldLinkKey(field);
    const linkWordId = fieldWordLinkId(field);
    const selectedClass = isRowSelectedField(packet.rowId, linkKey) ? "field-card-selected" : "";
    const pulseClass = shouldPulseField(linkKey, packet.rowId) ? "sync-pulse" : "";
    return `
      <div
        class="field-card ${selectedClass} ${pulseClass}"
        data-field-card="1"
        data-row-id="${escapeHtml(packet.rowId)}"
        data-field-id="${escapeHtml(field.id)}"
        data-link-field-key="${escapeHtml(linkKey)}"
        data-link-word-id="${escapeHtml(linkWordId)}"
        data-tooltip="${escapeHtml(tooltip)}"
      >
        <div class="field-label" style="background:${field.tone.label}; color:${field.tone.text}; border-bottom-color:${field.tone.border};">
          ${escapeHtml(field.label)} ${escapeHtml(field.bits || "")}
        </div>
        <div class="field-value" style="background:${field.tone.value}; color:${field.tone.text};">
          ${escapeHtml(field.cardValue || field.valueHex || "")}
        </div>
      </div>
    `;
  }

  function buildLinkedTraceField(selectedField) {
    return {
      id: "__linked__" + selectedField.key,
      label: selectedField.field.label,
      bits: selectedField.field.bits,
      tone: selectedField.field.tone,
      cardValue: selectedField.field.cardValue || selectedField.field.valueHex || selectedField.field.valueDec || "",
      valueHex: selectedField.field.valueHex || "",
      description: [selectedField.word.wordLabel, selectedField.field.description].filter(Boolean).join(" | "),
      forcedLinkKey: selectedField.key,
    };
  }

  function renderTab(tabId, label) {
    return `<button class="side-tab ${state.viewTab === tabId ? "active" : ""}" type="button" data-action="tab" data-value="${escapeHtml(tabId)}">${escapeHtml(label)}</button>`;
  }

  function renderSidePanel(packet, visible, selectedField) {
    if (state.viewTab === "details") {
      return renderDetailsPanel(packet, selectedField);
    }
    if (state.viewTab === "tracker") {
      return renderTrackerPanel(packet, visible);
    }
    return renderSpecPanel(packet, selectedField);
  }

  function renderSpecPanel(packet, selectedField) {
    const words = detailWords(packet);
    return `
      <div class="side-toolbar">
        <button class="tool-button" type="button" data-action="packet-nav" data-value="-1">Prev</button>
        <button class="tool-button" type="button" data-action="packet-nav" data-value="1">Next</button>
        ${renderToolbarToggle("spec-mode", "hex", "Hex", state.specMode === "hex")}
        ${renderToolbarToggle("spec-mode", "bin", "Bin", state.specMode === "bin")}
      </div>
      <p class="pane-title">Spec View: ${escapeHtml(packet.packetLabel || packet.kindLabel)}</p>
      <p class="pane-subtitle">${escapeHtml(packet.kindLabel)} | ${escapeHtml(packetLaneLabel(packet))} | ${escapeHtml(packetFrameLabel(packet))} | relative ${escapeHtml(relativeTimeLabel(packet))}</p>
      <div class="spec-scroll-track">
        <div class="spec-stack">
          ${words.map((word) => renderSpecWordBlock(word, selectedField, packet.rowId)).join("")}
        </div>
        <div class="spec-scroll-runway" aria-hidden="true"></div>
      </div>
      ${selectedField && selectedField.field ? renderSpecSelectedField(selectedField.word, selectedField.field) : ""}
    `;
  }

  function renderSpecWordBlock(word, selectedField, rowId) {
    const fields = (word.fieldsByMode && word.fieldsByMode[state.decodeMode]) || [];
    const activeWordId = selectedField && selectedField.word ? selectedField.word.wordId : "";
    const activeField = activeWordId === word.wordId ? selectedField.field : null;
    const primaryRow = state.specMode === "hex" ? renderSpecHexCells(word, activeField) : renderSpecBitCells(word, activeField);
    const secondaryRow = state.specMode === "hex" ? renderSpecBitCells(word, activeField) : renderSpecHexCells(word, activeField);
    const pulseClass = shouldPulseWord(word.wordId) ? "sync-pulse" : "";
    return `
      <div class="spec-word-block ${activeWordId === word.wordId ? "active" : ""} ${pulseClass}" data-word-id="${escapeHtml(word.wordId)}">
        <div class="spec-word-head">
          <strong>${escapeHtml(word.wordLabel)}</strong>
          <span>${escapeHtml(word.rawHex)} | datak=${escapeHtml(word.datakHex)} | cycle=${escapeHtml(String(word.cycle))}</span>
        </div>
        <table class="spec-grid">
          <thead>
            <tr>
              <th>View</th>
              <th class="byte-band" colspan="8">Byte 3</th>
              <th class="byte-band" colspan="8">Byte 2</th>
              <th class="byte-band" colspan="8">Byte 1</th>
              <th class="byte-band" colspan="8">Byte 0</th>
            </tr>
            <tr>
              <th>Bits</th>
              ${Array.from({ length: 32 }, (_, index) => `<th class="bits">${31 - index}</th>`).join("")}
            </tr>
          </thead>
          <tbody>
            <tr><td>${state.specMode === "hex" ? "Primary Hex" : "Primary Bin"}</td>${primaryRow}</tr>
            <tr><td>${state.specMode === "hex" ? "Reference Bin" : "Reference Hex"}</td>${secondaryRow}</tr>
            <tr class="field-name-row">
              <td>Field Names</td>
              ${fields.map((field) => renderSpecFieldNameCell(word, field, activeField, rowId)).join("")}
            </tr>
            <tr class="field-value-row">
              <td>Field Values</td>
              ${fields.map((field) => renderSpecFieldValueCell(word, field, activeField, rowId)).join("")}
            </tr>
          </tbody>
        </table>
      </div>
    `;
  }

  function renderSpecHexCells(word, activeField) {
    const hex = word.rawHex.replace(/^0x/, "");
    return hex.split("").map((nibble, index) => {
      const nibbleMsb = 31 - index * 4;
      const nibbleLsb = nibbleMsb - 3;
      const active = activeField && nibbleMsb >= activeField.lsb && nibbleLsb <= activeField.msb;
      return `<td class="bits ${active ? "spec-active-bit" : ""}" colspan="4">${escapeHtml(nibble)}</td>`;
    }).join("");
  }

  function renderSpecBitCells(word, activeField) {
    const cells = [];
    for (let bit = 31; bit >= 0; bit -= 1) {
      const active = activeField && bit <= activeField.msb && bit >= activeField.lsb;
      cells.push(`<td class="bits ${active ? "spec-active-bit" : ""}">${(word.data >> bit) & 1}</td>`);
    }
    return cells.join("");
  }

  function renderSpecFieldNameCell(word, field, activeField, rowId) {
    const active = activeField && activeField.id === field.id;
    const fieldKey = makeWordFieldKey(word.wordId, field.id);
    const pulseClass = shouldPulseField(fieldKey, rowId) ? "sync-pulse" : "";
    return `<td colspan="${field.width}" class="${active ? "spec-field-selected" : ""}" style="background:${field.tone.label}; color:${field.tone.text}; text-align:center;"><button class="spec-band-button ${pulseClass}" type="button" data-action="select-word-field" data-value="${escapeHtml(fieldKey)}" data-word-field-key="${escapeHtml(fieldKey)}" data-row-id="${escapeHtml(rowId || "")}">${escapeHtml(field.label)}</button></td>`;
  }

  function renderSpecFieldValueCell(word, field, activeField, rowId) {
    const active = activeField && activeField.id === field.id;
    const value = state.specMode === "hex" ? field.valueHex : field.valueBin;
    const fieldKey = makeWordFieldKey(word.wordId, field.id);
    const pulseClass = shouldPulseField(fieldKey, rowId) ? "sync-pulse" : "";
    return `<td colspan="${field.width}" class="${active ? "spec-field-selected" : ""}" style="background:${field.tone.value}; color:${field.tone.text}; text-align:center;"><button class="spec-band-button spec-value-button ${pulseClass}" type="button" data-action="select-word-field" data-value="${escapeHtml(fieldKey)}" data-word-field-key="${escapeHtml(fieldKey)}" data-row-id="${escapeHtml(rowId || "")}">${escapeHtml(value)}</button></td>`;
  }

  function renderSpecSelectedField(word, field) {
    return `
      <div class="spec-selected" style="border-color:${field.tone.border}; background:${field.tone.value}; color:${field.tone.text};">
        <strong>${escapeHtml(word.wordLabel)} :: ${escapeHtml(field.label)} ${escapeHtml(field.bits)}</strong>
        <span>${escapeHtml(field.valueHex)} | ${escapeHtml(field.valueDec)} | ${escapeHtml(field.valueBin)}</span>
        <span>${escapeHtml(field.description)}</span>
      </div>
    `;
  }

  function renderDetailsPanel(packet, selectedField) {
    const fields = getOrderedFields(packet);
    const words = detailWords(packet);
    return `
      <div class="side-toolbar">
        ${renderToolbarToggle("details-radix", "hex", "Hex", state.detailsRadix === "hex")}
        ${renderToolbarToggle("details-radix", "dec", "Dec", state.detailsRadix === "dec")}
      </div>
      <p class="pane-title">Details View</p>
      <p class="pane-subtitle">${escapeHtml(packet.kindLabel)} | ${escapeHtml(packetLaneLabel(packet))} | ${escapeHtml(packetFrameLabel(packet))} | absolute ${escapeHtml(packet.timeLabel)}</p>
      <table class="detail-table">
        <thead>
          <tr><th>Field</th><th>Bits</th><th>Value</th><th>Other Base</th><th>Description</th></tr>
        </thead>
        <tbody>
          ${detailMetaRows(packet)}
          ${fields.map((field) => renderDetailFieldRow(field)).join("")}
        </tbody>
      </table>
      <div class="detail-word-stack">
        ${words.map((word) => renderDetailWordSection(word, selectedField, packet.rowId)).join("")}
      </div>
      ${packet.subpacketTable && packet.subpacketTable.length ? renderSubpacketTable(packet.subpacketTable) : ""}
    `;
  }

  function detailMetaRows(packet) {
    const rows = [
      ["Row", packet.rowId, packet.kindLabel, "Current selected analyzer row"],
      ["Lane", String(packet.lane), "F" + packet.frameId, "Ingress lane and frame identifier"],
      ["Cycles", String(packet.startCycle) + ".." + String(packet.endCycle), relativeTimeLabel(packet), "Cycle window covered by the row"],
    ];
    return rows.map((row) => `<tr><td>${escapeHtml(row[0])}</td><td class="mono">meta</td><td class="mono">${escapeHtml(row[1])}</td><td class="mono">${escapeHtml(row[2])}</td><td>${escapeHtml(row[3])}</td></tr>`).join("");
  }

  function renderDetailFieldRow(field) {
    const primary = state.detailsRadix === "hex" ? field.cardValue || field.valueHex : field.valueDec;
    const secondary = state.detailsRadix === "hex" ? field.valueDec : field.valueHex;
    return `<tr><td>${escapeHtml(field.label)}</td><td class="mono">${escapeHtml(field.bits || "meta")}</td><td class="mono">${escapeHtml(primary)}</td><td class="mono">${escapeHtml(secondary)}</td><td>${escapeHtml(field.description || "")}</td></tr>`;
  }

  function renderDetailWordSection(word, selectedField, rowId) {
    const activeWordId = selectedField && selectedField.word ? selectedField.word.wordId : "";
    const fields = (word.fieldsByMode && word.fieldsByMode[state.decodeMode]) || [];
    const pulseClass = shouldPulseWord(word.wordId) ? "sync-pulse" : "";
    return `
      <section class="detail-word ${activeWordId === word.wordId ? "active" : ""} ${pulseClass}" data-word-id="${escapeHtml(word.wordId)}" data-row-id="${escapeHtml(rowId || "")}">
        <div class="detail-word-head">
          <strong>${escapeHtml(word.wordLabel)}</strong>
          <span>${escapeHtml(word.rawHex)} | ${escapeHtml(word.decodeSummaryByMode[state.decodeMode])}</span>
        </div>
        <table class="detail-table compact">
          <thead>
            <tr><th>Field</th><th>Bits</th><th>Value</th><th>Other Base</th><th>Description</th></tr>
          </thead>
          <tbody>
            ${fields.map((field) => {
              const active = selectedField && selectedField.word && selectedField.word.wordId === word.wordId && selectedField.field && selectedField.field.id === field.id;
              const primary = state.detailsRadix === "hex" ? field.valueHex : field.valueDec;
              const secondary = state.detailsRadix === "hex" ? field.valueDec : field.valueHex;
              const fieldKey = makeWordFieldKey(word.wordId, field.id);
              const pulseClass = shouldPulseField(fieldKey, rowId) ? "sync-pulse" : "";
              return `<tr class="${active ? "selected-field" : ""}" data-word-field-row-key="${escapeHtml(fieldKey)}" data-row-id="${escapeHtml(rowId || "")}"><td><button class="detail-field-button ${pulseClass}" type="button" data-action="select-word-field" data-value="${escapeHtml(fieldKey)}" data-word-field-key="${escapeHtml(fieldKey)}" data-row-id="${escapeHtml(rowId || "")}">${escapeHtml(field.label)}</button></td><td class="mono">${escapeHtml(field.bits)}</td><td class="mono">${escapeHtml(primary)}</td><td class="mono">${escapeHtml(secondary)}</td><td>${escapeHtml(field.description)}</td></tr>`;
            }).join("")}
          </tbody>
        </table>
      </section>
    `;
  }

  function renderSubpacketTable(rows) {
    return `
      <section class="detail-word">
        <div class="detail-word-head">
          <strong>SubPacket Index</strong>
          <span>Click a row to jump directly to that integral subpacket.</span>
        </div>
        <table class="detail-table compact">
          <thead>
            <tr><th>SubPkt</th><th>ts(11:4)</th><th>Hits</th><th>Cycles</th></tr>
          </thead>
          <tbody>
            ${rows.map((row) => `<tr><td><button class="detail-field-button" type="button" data-action="select-row" data-value="${escapeHtml(row.rowId)}">S${escapeHtml(String(row.subpktIndex).padStart(3, "0"))}</button></td><td class="mono">0x${escapeHtml((row.shdTs == null ? 0 : row.shdTs).toString(16).padStart(2, "0").toUpperCase())}</td><td class="mono">${escapeHtml(String(row.hitCount))}</td><td class="mono">${escapeHtml(String(row.startCycle))}..${escapeHtml(String(row.endCycle))}</td></tr>`).join("")}
          </tbody>
        </table>
      </section>
    `;
  }

  function renderTrackerPanel(packet, visible) {
    const rows = trackerRows(visible, packet);
    return `
      <div class="side-toolbar">
        ${renderToolbarToggle("tracker-format", "fields", "Fields", state.trackerFormat === "fields")}
        ${renderToolbarToggle("tracker-format", "hex", "0x", state.trackerFormat === "hex")}
        ${renderToolbarToggle("tracker-format", "bin", "Bin", state.trackerFormat === "bin")}
        ${renderToolbarToggle("tracker-format", "desc", "Desc", state.trackerFormat === "desc")}
        ${renderToolbarToggle("tracker-density", "1x", "1x", state.trackerDensity === "1x")}
        ${renderToolbarToggle("tracker-density", "2x", "2x", state.trackerDensity === "2x")}
        ${renderToolbarToggle("tracker-density", "4x", "4x", state.trackerDensity === "4x")}
        ${renderToolbarToggle("tracker-sync", state.trackerSync ? "on" : "off", state.trackerSync ? "Sync" : "Freeze", state.trackerSync)}
      </div>
      <p class="pane-title">Link Tracker</p>
      <p class="pane-subtitle">Synchronized to the selected packet or subpacket row.</p>
      <table class="tracker-table">
        <thead>
          <tr><th>Row</th><th>Kind</th><th>Lane</th><th>Tracker Content</th></tr>
        </thead>
        <tbody>
          ${rows.map((row) => renderTrackerRow(row, packet)).join("")}
        </tbody>
      </table>
    `;
  }

  function trackerRows(visible, packet) {
    if (!visible.length) {
      return [];
    }
    if (!state.trackerSync) {
      return visible.slice(0, 14);
    }
    const idx = visible.findIndex((item) => item.rowId === packet.rowId);
    const start = Math.max(0, idx - 6);
    return visible.slice(start, start + 13);
  }

  function renderTrackerRow(row, selected) {
    const selectedClass = row.rowId === selected.rowId ? "selected-packet" : "";
    return `
      <tr class="${selectedClass}" data-row-id="${escapeHtml(row.rowId)}">
        <td class="mono"><button class="detail-field-button" type="button" data-action="select-row" data-value="${escapeHtml(row.rowId)}">${escapeHtml(row.packetLabel || row.rowId)}</button></td>
        <td>${escapeHtml(row.kindLabel)}</td>
        <td class="mono">${escapeHtml(String(row.lane))}</td>
        <td><div class="tracker-stream">${trackerTokens(row).map((token) => renderTrackerToken(token)).join("")}</div></td>
      </tr>
    `;
  }

  function trackerTokens(packet) {
    if (state.trackerFormat === "hex") {
      return rawHexTokens(packet);
    }
    if (state.trackerFormat === "bin") {
      return rawBinaryTokens(packet);
    }
    if (state.trackerFormat === "desc") {
      return descriptionTokens(packet);
    }
    return fieldTokens(packet);
  }

  function rawHexTokens(packet) {
    const words = detailWords(packet);
    if (!words.length) {
      return [neutralToken(packet.packetLabel || packet.kindLabel)];
    }
    if (state.trackerDensity === "4x") {
      return [neutralToken(words.map((word) => word.rawHex).join(" "))];
    }
    if (state.trackerDensity === "2x") {
      return words.slice(0, 3).map((word) => neutralToken(word.rawHex));
    }
    return words.map((word) => neutralToken(word.rawHex));
  }

  function rawBinaryTokens(packet) {
    const words = detailWords(packet);
    if (!words.length) {
      return [neutralToken(packet.packetLabel || packet.kindLabel)];
    }
    if (state.trackerDensity === "4x") {
      return [neutralToken(words.map((word) => word.rawBin.replaceAll(" ", "")).join(" "))];
    }
    if (state.trackerDensity === "2x") {
      return words.slice(0, 2).map((word) => neutralToken(word.rawBin.replaceAll(" ", "")));
    }
    return words.map((word) => neutralToken(word.rawBin));
  }

  function descriptionTokens(packet) {
    if (state.trackerDensity === "4x") {
      return [neutralToken(packet.kindLabel)];
    }
    if (state.trackerDensity === "2x") {
      return [neutralToken(packet.decodeSummaryByMode[state.decodeMode])];
    }
    return [
      neutralToken(packet.kindLabel),
      neutralToken(packet.decodeSummaryByMode[state.decodeMode]),
      neutralToken("cycle " + packet.startCycle + ".." + packet.endCycle),
      neutralToken(relativeTimeLabel(packet)),
    ];
  }

  function fieldTokens(packet) {
    const fields = getOrderedFields(packet);
    if (state.trackerDensity === "4x") {
      return [neutralToken(packet.decodeSummaryByMode[state.decodeMode])];
    }
    const visibleFields = state.trackerDensity === "2x" ? fields.filter((field) => field.defaultVisible !== false).slice(0, 4) : fields;
    return visibleFields.map((field) => ({
      text: state.trackerDensity === "2x" ? field.label + " " + (field.cardValue || field.valueHex) : field.label + "=" + (field.cardValue || field.valueHex),
      label: field.label,
      style: `background:${field.tone.value}; color:${field.tone.text}; border-color:${field.tone.border};`,
      wordFieldKey: fieldLinkKey(field),
      rowId: packet.rowId,
    }));
  }

  function neutralToken(text) {
    return { text: text, label: "raw", style: "" };
  }

  function renderTrackerToken(token) {
    if (token.wordFieldKey) {
      const active = token.rowId === state.selectedRowId && token.wordFieldKey === state.selectedFieldId ? "tracker-token-selected" : "";
      const pulse = shouldPulseField(token.wordFieldKey, token.rowId) ? "sync-pulse" : "";
      return `<button class="tracker-token tracker-token-button ${active} ${pulse}" type="button" title="${escapeHtml(token.label)}" style="${token.style}" data-action="select-word-field" data-value="${escapeHtml(token.wordFieldKey)}" data-word-field-key="${escapeHtml(token.wordFieldKey)}" data-row-id="${escapeHtml(token.rowId || "")}">${escapeHtml(token.text)}</button>`;
    }
    return `<span class="tracker-token" title="${escapeHtml(token.label)}" style="${token.style}">${escapeHtml(token.text)}</span>`;
  }

  function decodeModeLabel(modeId) {
    const mode = (manifest.decodeModes || []).find((item) => item.id === modeId);
    return mode ? mode.label : modeId;
  }

  function renderDebugOverlay(selected, visible) {
    return `
      <aside class="debug-panel" data-role="debug-overlay">
        <strong>Visual Debug</strong>
        <div>boot=${escapeHtml(debugState.bootState)} render=${escapeHtml(String(debugState.renderCount))} errors=${escapeHtml(String(debugState.errors.length))}</div>
        <div>lane=${escapeHtml(String(state.lane))} loaded=[${escapeHtml(Array.from(laneDataMap.keys()).sort().join(","))}] visible=${escapeHtml(String(visible.length))}</div>
        <div>selected=${escapeHtml(selected ? selected.rowId : "none")} field=${escapeHtml(state.selectedFieldId || "none")}</div>
        <div>surface=${escapeHtml(state.surfaceMode)} tab=${escapeHtml(state.viewTab)} tracker=${escapeHtml(state.trackerFormat + "/" + state.trackerDensity)}</div>
        <div class="debug-log">${debugState.actions.slice(0, 8).map((entry) => `<div>${escapeHtml(entry.action)} ${escapeHtml(entry.detail)}</div>`).join("")}</div>
      </aside>
    `;
  }

  function bindEvents() {
    root.addEventListener("click", onClick);
    root.addEventListener("change", onChange);
    root.addEventListener("mousemove", onMouseMove);
    root.addEventListener("mouseover", onMouseOver);
    root.addEventListener("mouseout", onMouseOut);
    root.addEventListener("contextmenu", onContextMenu);
    root.addEventListener("pointerdown", onPointerDown);
    root.addEventListener("pointerup", clearHoldTimer);
    root.addEventListener("pointerleave", clearHoldTimer);
    root.addEventListener("scroll", onTraceScroll, true);
    document.addEventListener("click", onDocumentClick);
    window.addEventListener("resize", hideTooltip);
    window.addEventListener("resize", scheduleScrollbarSync);
    window.addEventListener("scroll", hideTooltip, true);
    window.addEventListener("pointermove", onWindowPointerMove);
    window.addEventListener("pointerup", onWindowPointerUp);
  }

  function onClick(event) {
    if (suppressNextWaveClick && event.target.closest("[data-wave-panel-display]")) {
      suppressNextWaveClick = false;
      return;
    }
    const waveLinkEl = event.target.closest("[data-wave-link-key][data-wave-target-row-id]");
    if (waveLinkEl) {
      const targetRowId = waveLinkEl.getAttribute("data-wave-target-row-id") || "";
      const wordId = waveLinkEl.getAttribute("data-wave-word-id") || "";
      recordAction("wave-beat-click", targetRowId + ":" + wordId);
      activateWaveBeat(targetRowId, wordId, false);
      return;
    }
    const annotationEl = event.target.closest("[data-wave-row-id]");
    if (annotationEl) {
      recordAction("wave-left-click-ignored", annotationEl.getAttribute("data-wave-row-id") || "");
      return;
    }

    const fieldEl = event.target.closest("[data-field-card]");
    if (fieldEl) {
      const rowId = fieldEl.getAttribute("data-row-id");
      const linkFieldKey = fieldEl.getAttribute("data-link-field-key");
      const linkWordId = fieldEl.getAttribute("data-link-word-id");
      if (rowId) {
        state.selectedRowId = rowId;
      }
      if (linkFieldKey || linkWordId) {
        selectPacketWord(rowId || state.selectedRowId, linkWordId || "", linkFieldKey || "");
        queueFieldSync(rowId || state.selectedRowId, linkFieldKey, linkWordId);
      }
      recordAction("field-click", rowId + ":" + (fieldEl.getAttribute("data-field-id") || ""));
      render("selection");
      requestWaveSelectionFocus(state.selectedRowId, state.selectedWordId);
      return;
    }

    const actionEl = event.target.closest("[data-action]");
    if (actionEl) {
      if (actionEl.getAttribute("data-action") === "toggle-row" && holdTriggered) {
        holdTriggered = false;
        return;
      }
      handleAction(actionEl);
      return;
    }

    const rowEl = event.target.closest(".trace-row[data-row-id]");
    if (rowEl) {
      const rowId = rowEl.getAttribute("data-row-id");
      if (rowId) {
        selectRow(rowId, true);
      }
    }
  }

  function selectRow(rowId, rerender) {
    state.selectedRowId = rowId;
    state.selectedWordId = "";
    ensureSelectedField(selectedPacket());
    recordAction("row-select", rowId);
    if (rerender) {
      render("selection");
    }
    requestWaveSelectionFocus(state.selectedRowId, state.selectedWordId);
  }

  function expandRowAncestors(packet) {
    let current = packet;
    while (current && current.parentRowId) {
      state.expandedRows.add(current.parentRowId);
      current = rowMap.get(current.parentRowId) || null;
    }
  }

  function activateWaveBeat(rowId, wordId, switchToTrace) {
    if (!rowId || !rowMap.has(rowId)) {
      return;
    }
    const packet = rowMap.get(rowId);
    expandRowAncestors(packet);
    state.selectedRowId = rowId;
    state.selectedWordId = wordId || "";
    state.selectedFieldId = "";
    ensureSelectedField(packet);
    queueFieldSync(state.selectedRowId, state.selectedFieldId, state.selectedWordId);
    if (switchToTrace) {
      state.surfaceMode = "trace";
    }
    render(switchToTrace ? "wave-focus" : "selection");
    if (switchToTrace && packet.lane !== -1) {
      scrollRowIntoView(rowId);
    }
  }

  function handleAction(actionEl) {
    const action = actionEl.getAttribute("data-action");
    const value = actionEl.getAttribute("data-value") || "";
    const panelId = actionEl.getAttribute("data-panel-id") || "";
    recordAction(action, value || panelId);

    if (action === "tab") {
      state.viewTab = value;
      render("tab-switch");
      requestWaveSelectionFocus(state.selectedRowId, state.selectedWordId);
      return;
    }
    if (action === "surface-mode") {
      state.surfaceMode = value === "wave" && !hasWaveSurface() ? "trace" : value;
      render("surface-switch");
      if (state.surfaceMode === "wave") {
        if (state.selectedRowId) {
          requestWaveSelectionFocus(state.selectedRowId, state.selectedWordId);
        } else if (state.frameFilter) {
          void focusWavePanelsForFrame(state.frameFilter);
        }
      }
      return;
    }
    if (action === "family-toggle") {
      state.familyFilters[value] = !state.familyFilters[value];
      ensureSelection();
      ensureSelectedField(selectedPacket());
      render("filter-change");
      return;
    }
    if (action === "wrap-toggle") {
      state.wrap = !state.wrap;
      render("layout-change");
      return;
    }
    if (action === "update-mode") {
      state.updateMode = value;
      render("selection");
      return;
    }
    if (action === "spec-mode") {
      state.specMode = value;
      render("selection");
      return;
    }
    if (action === "details-radix") {
      state.detailsRadix = value;
      render("selection");
      return;
    }
    if (action === "tracker-format") {
      state.trackerFormat = value;
      render("selection");
      return;
    }
    if (action === "tracker-density") {
      state.trackerDensity = value;
      render("selection");
      return;
    }
    if (action === "tracker-sync") {
      state.trackerSync = !state.trackerSync;
      render("selection");
      return;
    }
    if (action === "packet-nav") {
      navigatePackets(Number(value));
      return;
    }
    if (action === "toggle-row") {
      toggleRow(actionEl.getAttribute("data-row-id"));
      return;
    }
    if (action === "select-word-field") {
      const targetRowId = actionEl.getAttribute("data-row-id") || state.selectedRowId;
      const packet = targetRowId && rowMap.has(targetRowId) ? rowMap.get(targetRowId) : selectedPacket();
      if (!packet) {
        return;
      }
      expandRowAncestors(packet);
      const words = detailWords(packet);
      const matchingWord = words.find((word) => value.startsWith(word.wordId + "::"));
      const nextWordId = matchingWord ? matchingWord.wordId : state.selectedWordId;
      selectPacketWord(packet.rowId, nextWordId, value);
      ensureSelectedField(packet);
      queueFieldSync(packet.rowId, value, nextWordId);
      render("selection");
      if (state.surfaceMode === "trace" && packet.lane !== -1) {
        scrollRowIntoView(packet.rowId);
      }
      requestWaveSelectionFocus(packet.rowId, nextWordId);
      return;
    }
    if (action === "wave-range-apply") {
      if (applyWaveRangeFromControls(panelId)) {
        recordAction("wave-range-applied", panelId || "shared");
      }
      return;
    }
    if (action === "wave-range-auto") {
      if (resetWaveViewport(panelId)) {
        recordAction("wave-range-auto", panelId || "shared");
      }
      return;
    }
    if (action === "select-row") {
      if (value) {
        if (rowMap.has(value)) {
          const target = rowMap.get(value);
          expandRowAncestors(target);
          state.selectedRowId = value;
          state.selectedWordId = "";
          ensureSelectedField(target);
          render("selection");
          scrollRowIntoView(value);
          requestWaveSelectionFocus(state.selectedRowId, state.selectedWordId);
        }
      }
      return;
    }
    if (action === "wave-prev" || action === "wave-next" || action === "wave-zoom-out" || action === "wave-zoom-in" || action === "wave-zoom-reset") {
      if (usesSharedWaveViewport()) {
        const panels = visibleWavePanels();
        const sharedWave = normalizeSharedWaveState(panels, currentSharedWaveState());
        const span = Math.max(1, sharedWave.maxCycle - sharedWave.minCycle + 1);
        const choices = waveSlotChoices(span);
        const idx = Math.max(0, choices.indexOf(sharedWave.visibleSlots));
        if (action === "wave-prev") {
          sharedWave.cycleStart -= sharedWave.visibleSlots;
        } else if (action === "wave-next") {
          sharedWave.cycleStart += sharedWave.visibleSlots;
        } else if (action === "wave-zoom-out") {
          const nextVisible = choices[Math.min(choices.length - 1, idx + 1)];
          const center = sharedWave.cycleStart + Math.floor(sharedWave.visibleSlots / 2);
          sharedWave.visibleSlots = nextVisible;
          sharedWave.cycleStart = center - Math.floor(nextVisible / 2);
        } else if (action === "wave-zoom-in") {
          const nextVisible = choices[Math.max(0, idx - 1)];
          const center = sharedWave.cycleStart + Math.floor(sharedWave.visibleSlots / 2);
          sharedWave.visibleSlots = nextVisible;
          sharedWave.cycleStart = center - Math.floor(nextVisible / 2);
        } else {
          state.sharedWaveState[sharedWaveStateKey()] = normalizeSharedWaveState(panels, defaultSharedWaveState(panels));
          scheduleWaveRender();
          return;
        }
        state.sharedWaveState[sharedWaveStateKey()] = normalizeSharedWaveState(panels, sharedWave);
        scheduleWaveRender();
        return;
      }
      const panel = findWavePanel(panelId);
      if (!panel) {
        return;
      }
      const waveState = normalizeWavePanelState(panel, state.wavePanelState[panelId]);
      const chunkMeta = panel.chunks[waveState.chunkIndex];
      const slotCount = chunkSlotCount(chunkMeta);
      if (action === "wave-prev") {
        if (waveState.slotOffset > 0) {
          waveState.slotOffset = Math.max(0, waveState.slotOffset - waveState.visibleSlots);
        } else if (waveState.chunkIndex > 0) {
          waveState.chunkIndex -= 1;
          const prevCount = chunkSlotCount(panel.chunks[waveState.chunkIndex]);
          waveState.visibleSlots = clampWaveVisibleSlots(panel, waveState.visibleSlots, prevCount);
          waveState.slotOffset = Math.max(0, prevCount - waveState.visibleSlots);
        }
      } else if (action === "wave-next") {
        if (waveState.slotOffset + waveState.visibleSlots < slotCount) {
          waveState.slotOffset = Math.min(slotCount - waveState.visibleSlots, waveState.slotOffset + waveState.visibleSlots);
        } else if (waveState.chunkIndex < panel.chunkCount - 1) {
          waveState.chunkIndex += 1;
          const nextCount = chunkSlotCount(panel.chunks[waveState.chunkIndex]);
          waveState.visibleSlots = clampWaveVisibleSlots(panel, waveState.visibleSlots, nextCount);
          waveState.slotOffset = 0;
        }
      } else if (action === "wave-zoom-out") {
        const choices = waveSlotChoices(slotCount);
        const idx = Math.max(0, choices.indexOf(waveState.visibleSlots));
        waveState.visibleSlots = choices[Math.min(choices.length - 1, idx + 1)];
        waveState.slotOffset = Math.min(waveState.slotOffset, Math.max(0, slotCount - waveState.visibleSlots));
      } else if (action === "wave-zoom-in") {
        const choices = waveSlotChoices(slotCount);
        const idx = Math.max(0, choices.indexOf(waveState.visibleSlots));
        waveState.visibleSlots = choices[Math.max(0, idx - 1)];
        waveState.slotOffset = Math.min(waveState.slotOffset, Math.max(0, slotCount - waveState.visibleSlots));
      } else {
        state.wavePanelState[panelId] = normalizeWavePanelState(panel, defaultWavePanelState(panel));
        scheduleWaveRender();
        return;
      }
      state.wavePanelState[panelId] = normalizeWavePanelState(panel, waveState);
      scheduleWaveRender();
    }
  }

  function onChange(event) {
    const selectEl = event.target.closest("select[data-action]");
    if (!selectEl) {
      return;
    }
    const action = selectEl.getAttribute("data-action");
    if (action === "case-change") {
      const nextUrl = selectEl.value || "";
      if (nextUrl) {
        window.location.assign(nextUrl);
      }
      return;
    }
    if (action === "lane-change") {
      void setLane(selectEl.value);
      return;
    }
    if (action === "decode-change") {
      state.decodeMode = selectEl.value;
      ensureSelectedField(selectedPacket());
      render("filter-change");
      return;
    }
    if (action === "source-change" || action === "wave-source-change") {
      state.waveSourceId = selectEl.value;
      render("source-change");
      if (state.surfaceMode === "wave" && state.frameFilter) {
        void focusWavePanelsForFrame(state.frameFilter);
      }
      return;
    }
    if (action === "wave-zoom-level") {
      if (applyWaveZoomLevel(selectEl.getAttribute("data-panel-id") || "", selectEl.value)) {
        recordAction("wave-zoom-level", selectEl.value);
      }
      return;
    }
    if (action === "frame-change") {
      state.frameFilter = selectEl.value || "";
      ensureSelection();
      ensureSelectedField(selectedPacket());
      render("filter-change");
      if (state.surfaceMode === "wave" && state.frameFilter) {
        void focusWavePanelsForFrame(state.frameFilter);
      }
      return;
    }
    if (action === "section-change") {
      state.sectionFilter = selectEl.value || "all";
      state.selectedRowId = "";
      state.selectedWordId = "";
      state.selectedFieldId = "";
      ensureSectionSelection();
      ensureSelection();
      ensureSelectedField(selectedPacket());
      render("filter-change");
      if (state.surfaceMode === "wave" && state.frameFilter) {
        void focusWavePanelsForFrame(state.frameFilter);
      }
      return;
    }
    if (action === "row-visibility-change") {
      if (selectEl.value !== "custom") {
        applyRowVisibilityPreset(selectEl.value || "all");
        ensureSelection();
        ensureSelectedField(selectedPacket());
        render("filter-change");
      }
    }
  }

  async function setLane(laneKey) {
    state.lastScrollTopByLane[state.lane] = getCurrentScrollTop();
    state.lane = String(laneKey);
    state.loadingLane = state.lane;
    ensureSelection();
    render("lane-change");
    try {
      await ensureLaneData(state.lane);
      state.sharedWaveState = {};
      state.fieldPrefs = loadFieldPrefs();
    } catch (error) {
      noteError(error);
    } finally {
      state.loadingLane = null;
      ensureSelection();
      ensureSelectedField(selectedPacket());
      render("lane-change");
      if (state.surfaceMode === "wave" && state.frameFilter) {
        void focusWavePanelsForFrame(state.frameFilter);
      }
    }
  }

  function getCurrentScrollTop() {
    const scroller = root.querySelector('[data-role="trace-scroll"]');
    return scroller ? scroller.scrollTop : 0;
  }

  function navigatePackets(delta) {
    const visible = visiblePackets();
    const idx = visible.findIndex((packet) => packet.rowId === state.selectedRowId);
    if (idx === -1) {
      return;
    }
    const nextIdx = Math.max(0, Math.min(visible.length - 1, idx + delta));
    state.selectedRowId = visible[nextIdx].rowId;
    state.selectedWordId = "";
    ensureSelectedField(selectedPacket());
    render("selection");
    scrollRowIntoView(state.selectedRowId);
  }

  function toggleRow(rowId) {
    if (!rowId) {
      return;
    }
    if (state.expandedRows.has(rowId)) {
      state.expandedRows.delete(rowId);
    } else {
      state.expandedRows.add(rowId);
    }
    render("row-toggle");
  }

  function onPointerDown(event) {
    const thumb = event.target.closest("[data-scroll-thumb]");
    if (thumb) {
      const scrollId = thumb.getAttribute("data-scroll-thumb") || "";
      const axis = thumb.getAttribute("data-scroll-axis") || "y";
      const rail = scrollRailElement(scrollId, axis);
      const scroller = scrollSyncElement(scrollId);
      const canScroll = scroller && (axis === "x" ? scroller.scrollWidth > scroller.clientWidth : scroller.scrollHeight > scroller.clientHeight);
      if (rail && scroller && canScroll) {
        event.preventDefault();
        scrollDragState = {
          scrollId: scrollId,
          axis: axis,
          offset: axis === "x" ? (event.clientX - thumb.getBoundingClientRect().left) : (event.clientY - thumb.getBoundingClientRect().top),
        };
        document.body.classList.add("scrollbar-dragging");
      }
      return;
    }
    const rail = event.target.closest("[data-scroll-rail]");
    if (rail) {
      const scrollId = rail.getAttribute("data-scroll-rail") || "";
      const axis = rail.getAttribute("data-scroll-axis") || "y";
      const scroller = scrollSyncElement(scrollId);
      const railThumb = scrollThumbElement(scrollId, axis);
      const canScroll = scroller && (axis === "x" ? scroller.scrollWidth > scroller.clientWidth : scroller.scrollHeight > scroller.clientHeight);
      if (scroller && railThumb && canScroll) {
        event.preventDefault();
        const railRect = rail.getBoundingClientRect();
        const targetOffset = axis === "x"
          ? (event.clientX - railRect.left - railThumb.offsetWidth / 2)
          : (event.clientY - railRect.top - railThumb.offsetHeight / 2);
        scrollFromRailPosition(scrollId, axis, targetOffset);
        scrollDragState = {
          scrollId: scrollId,
          axis: axis,
          offset: axis === "x" ? (railThumb.offsetWidth / 2) : (railThumb.offsetHeight / 2),
        };
        document.body.classList.add("scrollbar-dragging");
      }
      return;
    }
    const waveDisplay = event.target.closest("[data-wave-panel-display]");
    if (event.button === 0 && waveDisplay && !event.target.closest(".context-menu, input, select, button")) {
      startWaveRangeDrag(event, waveDisplay);
    }
    const waveTarget = event.target.closest("[data-wave-target-row-id], [data-wave-row-id]");
    if (waveTarget) {
      rememberWaveScrollForInteraction();
    }
    const expander = event.target.closest('[data-action="toggle-row"]');
    if (!expander) {
      return;
    }
    clearHoldTimer();
    holdTriggered = false;
    const kind = expander.getAttribute("data-kind");
    holdTimer = window.setTimeout(() => {
      holdTriggered = true;
      const visible = (currentLane().packets || []).filter((packet) => packet.kind === kind && packet.expandable);
      const shouldExpand = visible.some((packet) => !state.expandedRows.has(packet.rowId));
      visible.forEach((packet) => {
        if (shouldExpand) {
          state.expandedRows.add(packet.rowId);
        } else {
          state.expandedRows.delete(packet.rowId);
        }
      });
      recordAction("toggle-row-kind", kind || "");
      render("row-toggle");
    }, 450);
  }

  function clearHoldTimer() {
    if (holdTimer) {
      window.clearTimeout(holdTimer);
      holdTimer = null;
    }
  }

  function onWindowPointerMove(event) {
    if (waveRangeDragState) {
      updateWaveRangeDrag(event);
      return;
    }
    if (!scrollDragState) {
      return;
    }
    const rail = scrollRailElement(scrollDragState.scrollId, scrollDragState.axis || "y");
    if (!rail) {
      return;
    }
    const railRect = rail.getBoundingClientRect();
    const pointerOffset = scrollDragState.axis === "x"
      ? (event.clientX - railRect.left - scrollDragState.offset)
      : (event.clientY - railRect.top - scrollDragState.offset);
    scrollFromRailPosition(scrollDragState.scrollId, scrollDragState.axis || "y", pointerOffset);
  }

  function onWindowPointerUp(event) {
    if (waveRangeDragState) {
      finishWaveRangeDrag(event);
      return;
    }
    if (!scrollDragState) {
      return;
    }
    scrollDragState = null;
    document.body.classList.remove("scrollbar-dragging");
  }

  function onMouseOver(event) {
    const waveLinkEl = event.target.closest("[data-wave-link-key]");
    if (waveLinkEl) {
      setWaveLinkHover(waveLinkEl.getAttribute("data-wave-link-key") || "");
    }
    const tipNode = event.target.closest("[data-tooltip], [data-wave-tooltip]");
    if (!tipNode) {
      return;
    }
    const text = tipNode.getAttribute("data-tooltip") || tipNode.getAttribute("data-wave-tooltip") || "";
    showTooltip(text, event.clientX, event.clientY);
  }

  function onMouseMove(event) {
    if (!tooltipEl.hidden) {
      moveTooltip(event.clientX, event.clientY);
    }
  }

  function onMouseOut(event) {
    const waveLinkEl = event.target.closest("[data-wave-link-key]");
    if (waveLinkEl) {
      const linkKey = waveLinkEl.getAttribute("data-wave-link-key") || "";
      const nextLinkEl = event.relatedTarget && event.relatedTarget.closest ? event.relatedTarget.closest("[data-wave-link-key]") : null;
      if (!nextLinkEl || (nextLinkEl.getAttribute("data-wave-link-key") || "") !== linkKey) {
        clearWaveLinkHover();
      }
    }
    const tipNode = event.target.closest("[data-tooltip], [data-wave-tooltip]");
    if (tipNode && event.relatedTarget && tipNode.contains(event.relatedTarget)) {
      return;
    }
    if (tipNode) {
      hideTooltip();
    }
  }

  function wavePanelIdFromElement(element) {
    const panel = element && element.closest ? element.closest(".wave-panel[data-panel-id]") : null;
    return panel ? (panel.getAttribute("data-panel-id") || "") : "";
  }

  function waveCycleFromDisplayPoint(display, clientX) {
    if (!display) {
      return null;
    }
    const panelId = display.getAttribute("data-wave-panel-display") || wavePanelIdFromElement(display);
    const descriptor = waveViewportDescriptorForPanelId(panelId);
    if (!descriptor) {
      return null;
    }
    const rect = display.getBoundingClientRect();
    if (!rect.width) {
      return null;
    }
    const x = Math.max(0, Math.min(rect.width, clientX - rect.left));
    const ratio = x / rect.width;
    const offset = Math.min(Math.max(0, descriptor.visibleSlots - 1), Math.floor(ratio * descriptor.visibleSlots));
    return {
      panelId: panelId,
      cycle: descriptor.cycleStart + offset,
      x: x,
      rect: rect,
      descriptor: descriptor,
    };
  }

  function startWaveRangeDrag(event, display) {
    const point = waveCycleFromDisplayPoint(display, event.clientX);
    if (!point) {
      return false;
    }
    waveRangeDragState = {
      display: display,
      panelId: point.panelId,
      startX: point.x,
      currentX: point.x,
      pointerId: event.pointerId,
      moved: false,
    };
    display.classList.add("wave-drag-armed");
    document.body.classList.add("wave-range-dragging");
    return true;
  }

  function updateWaveRangeDrag(event) {
    if (!waveRangeDragState) {
      return false;
    }
    const display = waveRangeDragState.display;
    if (!display || !display.isConnected) {
      clearWaveRangeDrag();
      return false;
    }
    const point = waveCycleFromDisplayPoint(display, event.clientX);
    if (!point) {
      clearWaveRangeDrag();
      return false;
    }
    waveRangeDragState.currentX = point.x;
    if (Math.abs(waveRangeDragState.currentX - waveRangeDragState.startX) >= 4) {
      waveRangeDragState.moved = true;
      event.preventDefault();
      renderWaveRangeDragOverlay(display, waveRangeDragState.startX, waveRangeDragState.currentX);
    }
    return true;
  }

  function finishWaveRangeDrag(event) {
    if (!waveRangeDragState) {
      return false;
    }
    const display = waveRangeDragState.display;
    const moved = waveRangeDragState.moved;
    const startPoint = display ? waveCycleFromDisplayPoint(display, display.getBoundingClientRect().left + waveRangeDragState.startX) : null;
    const endPoint = display ? waveCycleFromDisplayPoint(display, event.clientX) : null;
    const panelId = waveRangeDragState.panelId;
    clearWaveRangeDrag();
    if (!moved || !startPoint || !endPoint || Math.abs(startPoint.x - endPoint.x) < 8) {
      return false;
    }
    suppressNextWaveClick = true;
    const applied = applyWaveRange(panelId, startPoint.cycle, endPoint.cycle);
    if (applied) {
      recordAction("wave-drag-zoom", `${Math.min(startPoint.cycle, endPoint.cycle)}..${Math.max(startPoint.cycle, endPoint.cycle)}`);
    }
    return applied;
  }

  function renderWaveRangeDragOverlay(display, startX, currentX) {
    let overlay = display.querySelector(".wave-range-drag");
    if (!overlay) {
      overlay = document.createElement("div");
      overlay.className = "wave-range-drag";
      display.appendChild(overlay);
    }
    const left = Math.min(startX, currentX);
    const width = Math.max(1, Math.abs(currentX - startX));
    overlay.style.left = `${left}px`;
    overlay.style.width = `${width}px`;
  }

  function clearWaveRangeDrag() {
    if (waveRangeDragState && waveRangeDragState.display) {
      waveRangeDragState.display.classList.remove("wave-drag-armed");
      const overlay = waveRangeDragState.display.querySelector(".wave-range-drag");
      if (overlay) {
        overlay.remove();
      }
    }
    document.body.classList.remove("wave-range-dragging");
    waveRangeDragState = null;
  }

  function onContextMenu(event) {
    const waveBeatEl = event.target.closest("[data-wave-target-row-id]");
    if (waveBeatEl) {
      event.preventDefault();
      const panelId = waveBeatEl.getAttribute("data-wave-panel-id") || wavePanelIdFromElement(waveBeatEl);
      const cycle = Number(waveBeatEl.getAttribute("data-wave-cycle"));
      openWaveContextMenu(
        event.clientX,
        event.clientY,
        waveBeatEl.getAttribute("data-wave-target-row-id") || "",
        waveBeatEl.getAttribute("data-wave-tooltip") || "",
        waveBeatEl.getAttribute("data-wave-word-id") || "",
        waveBeatEl.getAttribute("data-wave-trace-row-id") || "",
        panelId,
        cycle
      );
      return;
    }
    const waveDisplay = event.target.closest("[data-wave-panel-display]");
    if (waveDisplay) {
      event.preventDefault();
      const point = waveCycleFromDisplayPoint(waveDisplay, event.clientX);
      if (point) {
        openWaveViewportContextMenu(event.clientX, event.clientY, point.panelId, point.cycle);
      }
      return;
    }
    const fieldEl = event.target.closest("[data-field-card]");
    if (fieldEl) {
      event.preventDefault();
      const rowId = fieldEl.getAttribute("data-row-id");
      const fieldId = fieldEl.getAttribute("data-field-id");
      const packet = rowId ? rowMap.get(rowId) : null;
      if (!packet || !fieldId) {
        return;
      }
      state.selectedRowId = rowId;
      ensureSelectedField(packet);
      openFieldContextMenu(event.clientX, event.clientY, packet, fieldId);
      render("selection");
      return;
    }
    const fieldLinkEl = event.target.closest("[data-word-field-key]");
    if (fieldLinkEl) {
      event.preventDefault();
      const rowId = fieldLinkEl.getAttribute("data-row-id") || state.selectedRowId;
      const packet = rowId && rowMap.has(rowId) ? rowMap.get(rowId) : selectedPacket();
      const fieldKey = fieldLinkEl.getAttribute("data-word-field-key") || "";
      if (!packet || !fieldKey) {
        return;
      }
      const selection = parseFieldSelectionKey(fieldKey);
      expandRowAncestors(packet);
      if (selection) {
        selectPacketWord(packet.rowId, selection.wordId, fieldKey);
        queueFieldSync(packet.rowId, fieldKey, selection.wordId);
      }
      ensureSelectedField(packet);
      openFieldLinkContextMenu(event.clientX, event.clientY, packet, fieldKey, (fieldLinkEl.textContent || "").trim());
      render("selection");
      return;
    }
    const rowLinkEl = event.target.closest("[data-action='select-row'][data-value]");
    if (rowLinkEl) {
      event.preventDefault();
      const rowId = rowLinkEl.getAttribute("data-value") || "";
      if (!rowId || !rowMap.has(rowId)) {
        return;
      }
      openRowContextMenu(event.clientX, event.clientY, rowMap.get(rowId), (rowLinkEl.textContent || "").trim());
      return;
    }
    const traceRowEl = event.target.closest(".trace-row[data-row-id]");
    if (traceRowEl) {
      event.preventDefault();
      const rowId = traceRowEl.getAttribute("data-row-id") || "";
      if (!rowId || !rowMap.has(rowId)) {
        return;
      }
      openRowContextMenu(event.clientX, event.clientY, rowMap.get(rowId), rowId);
      return;
    }
    const annotationEl = event.target.closest("[data-wave-row-id]");
    if (annotationEl) {
      event.preventDefault();
      const rowId = annotationEl.getAttribute("data-wave-row-id") || "";
      const tooltip = annotationEl.getAttribute("data-wave-tooltip") || "";
      const panelId = annotationEl.getAttribute("data-wave-panel-id") || wavePanelIdFromElement(annotationEl);
      const cycle = Number(annotationEl.getAttribute("data-wave-cycle"));
      openWaveContextMenu(event.clientX, event.clientY, rowId, tooltip, "", rowId, panelId, cycle);
      return;
    }
  }

  function openFieldContextMenu(x, y, packet, fieldId) {
    const pref = ensurePref(packet);
    const idx = pref.order.indexOf(fieldId);
    const hidden = pref.hidden.includes(fieldId);
    menuState = { type: "field", rowId: packet.rowId, fieldId: fieldId };
    menuEl.innerHTML = [
      menuTitle("Field Layout"),
      menuItem("toggle-default", hidden ? "Show Field By Default" : "Hide Field By Default"),
      menuItem("show-only-field", "Show Only This Field"),
      menuItem("show-all-fields", "Show All Fields"),
      menuItem("move-left", "Move Field Left", idx <= 0),
      menuItem("move-right", "Move Field Right", idx === -1 || idx >= pref.order.length - 1),
      menuSeparator(),
      menuTitle("Navigation"),
      menuItem("open-spec", "Open In Spec View"),
      menuItem("open-details", "Open In Details View"),
      menuItem("open-tracker", "Open In Link Tracker"),
      menuItem("zero-time", "Zero Timestamp At This Row"),
      menuSeparator(),
      menuItem("reset-layout", "Reset Field Layout"),
    ].join("");
    showContextMenu(x, y);
  }

  function openWaveContextMenu(x, y, rowId, tooltip, wordId, traceRowId, panelId, cycle) {
    const cycleValue = Number(cycle);
    menuState = {
      type: "wave",
      rowId: rowId,
      tooltip: tooltip,
      wordId: wordId || "",
      traceRowId: traceRowId || "",
      panelId: panelId || "",
      cycle: Number.isFinite(cycleValue) ? cycleValue : null,
    };
    const rowExists = !!rowId && rowMap.has(rowId);
    const rowPacket = rowExists ? rowMap.get(rowId) : null;
    const tracePacket = traceRowId && rowMap.has(traceRowId) ? rowMap.get(traceRowId) : null;
    const traceLinkable = !!tracePacket || (!!rowPacket && rowPacket.lane !== -1);
    const canZoomHere = Number.isFinite(menuState.cycle);
    menuEl.innerHTML = [
      menuTitle("Waveform Link"),
      menuItem("link-row", "Link To Packet Trace", !traceLinkable),
      menuItem("wave-open-spec", "Open Decode In Spec View", !rowExists),
      menuItem("wave-open-details", "Open Decode In Details View", !rowExists),
      menuItem("wave-open-tracker", "Open Decode In Link Tracker", !rowExists),
      menuSeparator(),
      menuItem("wave-zoom-in-here", "Zoom In Around Cycle", !canZoomHere),
      menuItem("wave-zoom-out-here", "Zoom Out Around Cycle", !canZoomHere),
      menuItem("wave-auto-range", "Reset To Auto Range"),
      menuSeparator(),
      menuItem("wave-show-tooltip", "Show Decode Tooltip"),
      menuItem("wave-zero-time", "Zero Timestamp At Linked Row", !rowExists),
    ].join("");
    showContextMenu(x, y);
  }

  function openWaveViewportContextMenu(x, y, panelId, cycle) {
    const cycleValue = Number(cycle);
    menuState = {
      type: "wave-viewport",
      panelId: panelId || "",
      cycle: Number.isFinite(cycleValue) ? cycleValue : null,
    };
    menuEl.innerHTML = [
      menuTitle(Number.isFinite(menuState.cycle) ? `Cycle ${menuState.cycle}` : "Waveform Range"),
      menuItem("wave-viewport-zoom-in", "Zoom In Around Cycle", !Number.isFinite(menuState.cycle)),
      menuItem("wave-viewport-zoom-out", "Zoom Out Around Cycle", !Number.isFinite(menuState.cycle)),
      menuItem("wave-viewport-auto", "Reset To Auto Range"),
    ].join("");
    showContextMenu(x, y);
  }

  function openFieldLinkContextMenu(x, y, packet, fieldKey, label) {
    const selection = parseFieldSelectionKey(fieldKey);
    menuState = {
      type: "field-link",
      rowId: packet.rowId,
      fieldKey: fieldKey,
      wordId: selection ? selection.wordId : "",
    };
    menuEl.innerHTML = [
      menuTitle(label || "Field Link"),
      menuItem("field-link-open-spec", "Open In Spec View"),
      menuItem("field-link-open-details", "Open In Details View"),
      menuItem("field-link-open-tracker", "Open In Link Tracker"),
      menuSeparator(),
      menuItem("field-link-zero-time", "Zero Timestamp At This Row"),
    ].join("");
    showContextMenu(x, y);
  }

  function openRowContextMenu(x, y, packet, label) {
    const traceLinkable = packet.lane !== -1;
    menuState = { type: "row-link", rowId: packet.rowId };
    menuEl.innerHTML = [
      menuTitle(label || packet.packetLabel || packet.rowId),
      menuItem("row-link-trace", "Link To Packet Trace", !traceLinkable),
      menuItem("row-open-spec", "Open In Spec View"),
      menuItem("row-open-details", "Open In Details View"),
      menuItem("row-open-tracker", "Open In Link Tracker"),
      menuSeparator(),
      menuItem("row-zero-time", "Zero Timestamp At This Row"),
    ].join("");
    showContextMenu(x, y);
  }

  function menuTitle(text) {
    return `<div class="context-title">${escapeHtml(text)}</div>`;
  }

  function menuSeparator() {
    return '<div class="context-separator"></div>';
  }

  function menuItem(action, label, disabled) {
    return `<div class="context-item${disabled ? " muted" : ""}" data-menu-action="${escapeHtml(action)}" data-disabled="${disabled ? "1" : "0"}">${escapeHtml(label)}</div>`;
  }

  function showContextMenu(x, y) {
    menuEl.hidden = false;
    menuEl.style.left = x + "px";
    menuEl.style.top = y + "px";
    menuEl.querySelectorAll(".context-item").forEach((item) => {
      item.addEventListener("click", onMenuItemClick);
    });
  }

  function onMenuItemClick(event) {
    const item = event.currentTarget;
    if (item.getAttribute("data-disabled") === "1" || !menuState) {
      closeContextMenu();
      return;
    }
    const action = item.getAttribute("data-menu-action");
    if (menuState.type === "field") {
      handleFieldContextAction(action);
    } else if (menuState.type === "field-link") {
      handleFieldLinkContextAction(action);
    } else if (menuState.type === "row-link") {
      handleRowContextAction(action);
    } else if (menuState.type === "wave") {
      handleWaveContextAction(action);
    } else if (menuState.type === "wave-viewport") {
      handleWaveViewportContextAction(action);
    }
    closeContextMenu();
  }

  function handleFieldContextAction(action) {
    const packet = rowMap.get(menuState.rowId);
    if (!packet) {
      return;
    }
    const pref = ensurePref(packet);
    const fieldId = menuState.fieldId;
    if (action === "toggle-default") {
      if (pref.hidden.includes(fieldId)) {
        pref.hidden = pref.hidden.filter((id) => id !== fieldId);
      } else {
        pref.hidden = pref.hidden.concat(fieldId);
      }
    } else if (action === "show-only-field") {
      pref.hidden = pref.order.filter((id) => id !== fieldId);
    } else if (action === "show-all-fields") {
      pref.hidden = [];
    } else if (action === "move-left") {
      moveField(pref.order, fieldId, -1);
    } else if (action === "move-right") {
      moveField(pref.order, fieldId, 1);
    } else if (action === "zero-time") {
      state.zeroTimePsByLane[String(packet.lane)] = packet.timePs;
    } else if (action === "open-spec") {
      state.viewTab = "spec";
    } else if (action === "open-details") {
      state.viewTab = "details";
    } else if (action === "open-tracker") {
      state.viewTab = "tracker";
    } else if (action === "reset-layout") {
      const key = prefKey(state.decodeMode, packet.kind);
      const defaults = buildDefaultFieldPrefs()[key];
      if (defaults) {
        state.fieldPrefs[key] = {
          order: defaults.order.slice(),
          hidden: defaults.hidden.slice(),
        };
      }
    }
    saveFieldPrefs();
    render(action.startsWith("open-") ? "tab-switch" : "layout-change");
    requestWaveSelectionFocus(state.selectedRowId, state.selectedWordId);
  }

  function handleWaveContextAction(action) {
    const rowId = menuState.rowId || "";
    const traceRowId = menuState.traceRowId || "";
    if (action === "wave-zoom-in-here" || action === "wave-zoom-out-here") {
      const descriptor = waveViewportDescriptorForPanelId(menuState.panelId || "");
      if (!descriptor || !Number.isFinite(menuState.cycle)) {
        return;
      }
      const idx = nearestWaveChoiceIndex(descriptor.choices, descriptor.visibleSlots);
      const nextIdx = action === "wave-zoom-in-here"
        ? Math.max(0, idx - 1)
        : Math.min(descriptor.choices.length - 1, idx + 1);
      applyWaveVisibleSlots(menuState.panelId || "", descriptor.choices[nextIdx], menuState.cycle);
      return;
    }
    if (action === "wave-auto-range") {
      resetWaveViewport(menuState.panelId || "");
      return;
    }
    if (action === "wave-show-tooltip") {
      if (menuState.tooltip) {
        showTooltip(menuState.tooltip, window.innerWidth / 2, 120);
      }
      return;
    }
    if (action === "link-row") {
      const targetTraceRowId = traceRowId && rowMap.has(traceRowId) ? traceRowId : rowId;
      if (!targetTraceRowId || !rowMap.has(targetTraceRowId)) {
        return;
      }
      const tracePacket = rowMap.get(targetTraceRowId);
      expandRowAncestors(tracePacket);
      state.selectedRowId = targetTraceRowId;
      state.selectedWordId = "";
      state.selectedFieldId = "";
      ensureSelectedField(tracePacket);
      state.surfaceMode = "trace";
      render("surface-switch");
      if (tracePacket.lane !== -1) {
        scrollRowIntoView(targetTraceRowId);
      }
      return;
    }
    if (!rowId || !rowMap.has(rowId)) {
      return;
    }
    const packet = rowMap.get(rowId);
    expandRowAncestors(packet);
    state.selectedRowId = rowId;
    state.selectedWordId = menuState.wordId || "";
    state.selectedFieldId = "";
    ensureSelectedField(packet);
    queueFieldSync(state.selectedRowId, state.selectedFieldId, state.selectedWordId);
    if (action === "wave-open-spec") {
      state.viewTab = "spec";
    } else if (action === "wave-open-details") {
      state.viewTab = "details";
    } else if (action === "wave-open-tracker") {
      state.viewTab = "tracker";
    } else if (action === "wave-zero-time") {
      state.zeroTimePsByLane[String(packet.lane)] = packet.timePs;
    }
    render(action.startsWith("wave-open-") ? "tab-switch" : "selection");
    if (state.surfaceMode === "trace" && packet.lane !== -1) {
      scrollRowIntoView(rowId);
    }
  }

  function handleWaveViewportContextAction(action) {
    if (action === "wave-viewport-auto") {
      resetWaveViewport(menuState.panelId || "");
      return;
    }
    if (action !== "wave-viewport-zoom-in" && action !== "wave-viewport-zoom-out") {
      return;
    }
    const descriptor = waveViewportDescriptorForPanelId(menuState.panelId || "");
    if (!descriptor || !Number.isFinite(menuState.cycle)) {
      return;
    }
    const idx = nearestWaveChoiceIndex(descriptor.choices, descriptor.visibleSlots);
    const nextIdx = action === "wave-viewport-zoom-in"
      ? Math.max(0, idx - 1)
      : Math.min(descriptor.choices.length - 1, idx + 1);
    applyWaveVisibleSlots(menuState.panelId || "", descriptor.choices[nextIdx], menuState.cycle);
  }

  function handleFieldLinkContextAction(action) {
    const rowId = menuState.rowId || "";
    const fieldKey = menuState.fieldKey || "";
    if (!rowId || !rowMap.has(rowId)) {
      return;
    }
    const packet = rowMap.get(rowId);
    const selection = parseFieldSelectionKey(fieldKey);
    expandRowAncestors(packet);
    state.selectedRowId = rowId;
    state.selectedWordId = selection ? selection.wordId : "";
    state.selectedFieldId = fieldKey;
    ensureSelectedField(packet);
    if (selection) {
      queueFieldSync(rowId, fieldKey, selection.wordId);
    }
    if (action === "field-link-open-spec") {
      state.viewTab = "spec";
    } else if (action === "field-link-open-details") {
      state.viewTab = "details";
    } else if (action === "field-link-open-tracker") {
      state.viewTab = "tracker";
    } else if (action === "field-link-zero-time") {
      state.zeroTimePsByLane[String(packet.lane)] = packet.timePs;
    }
    render(action.startsWith("field-link-open-") ? "tab-switch" : "selection");
    requestWaveSelectionFocus(state.selectedRowId, state.selectedWordId);
  }

  function handleRowContextAction(action) {
    const rowId = menuState.rowId || "";
    if (!rowId || !rowMap.has(rowId)) {
      return;
    }
    const packet = rowMap.get(rowId);
    expandRowAncestors(packet);
    state.selectedRowId = rowId;
    state.selectedWordId = "";
    ensureSelectedField(packet);
    if (action === "row-link-trace") {
      state.surfaceMode = "trace";
    } else if (action === "row-open-spec") {
      state.viewTab = "spec";
    } else if (action === "row-open-details") {
      state.viewTab = "details";
    } else if (action === "row-open-tracker") {
      state.viewTab = "tracker";
    } else if (action === "row-zero-time") {
      state.zeroTimePsByLane[String(packet.lane)] = packet.timePs;
    }
    render(action === "row-link-trace" ? "surface-switch" : action.startsWith("row-open-") ? "tab-switch" : "selection");
    if (state.surfaceMode === "trace" && packet.lane !== -1) {
      scrollRowIntoView(rowId);
    }
    requestWaveSelectionFocus(state.selectedRowId, state.selectedWordId);
  }

  function moveField(order, fieldId, delta) {
    const idx = order.indexOf(fieldId);
    if (idx === -1) {
      return;
    }
    const next = idx + delta;
    if (next < 0 || next >= order.length) {
      return;
    }
    const tmp = order[idx];
    order[idx] = order[next];
    order[next] = tmp;
  }

  function onDocumentClick(event) {
    if (!menuEl.hidden && !event.target.closest(".context-menu")) {
      closeContextMenu();
    }
  }

  function closeContextMenu() {
    menuEl.hidden = true;
    menuState = null;
    if (state.waveScrollRestore && state.surfaceMode === "wave") {
      state.waveScrollRestore = null;
    }
  }

  function onTraceScroll(event) {
    const sideBody = event.target.closest(".side-body");
    if (sideBody) {
      state.lastSideScrollTopByTab[state.viewTab] = sideBody.scrollTop;
      state.lastSideScrollLeftByTab[state.viewTab] = sideBody.scrollLeft;
      syncPersistentScrollbar("side");
      return;
    }
    const waveStack = event.target.closest(".wave-panel-stack");
    if (waveStack) {
      state.lastWaveScrollTopByKey[currentWaveScrollKey()] = waveStack.scrollTop;
      syncPersistentScrollbar("wave");
      return;
    }
    const scroller = event.target.closest('[data-role="trace-scroll"]');
    if (!scroller) {
      return;
    }
    state.lastScrollTopByLane[state.lane] = scroller.scrollTop;
    state.lastScrollLeftByLane[state.lane] = scroller.scrollLeft;
    syncPersistentScrollbar("trace");
    if (state.updateMode !== "scroll") {
      return;
    }
    if (scrollRaf) {
      return;
    }
    scrollRaf = window.requestAnimationFrame(() => {
      scrollRaf = 0;
      const firstVisible = firstVisibleRow(scroller);
      if (firstVisible && firstVisible !== state.selectedRowId) {
        state.selectedRowId = firstVisible;
        ensureSelectedField(selectedPacket());
        recordAction("scroll-sync", firstVisible);
        render("scroll-sync");
      }
    });
  }

  function firstVisibleRow(scroller) {
    const rows = Array.from(scroller.querySelectorAll(".trace-row[data-row-id]"));
    const top = scroller.scrollTop;
    const found = rows.find((row) => row.offsetTop + row.offsetHeight > top + 2);
    return found ? found.getAttribute("data-row-id") : "";
  }

  function scrollRowIntoView(rowId) {
    const traceScroller = root.querySelector('[data-role="trace-scroll"]');
    const rowEl = root.querySelector(`.trace-row[data-row-id="${CSS.escape(rowId)}"]`);
    if (rowEl && traceScroller) {
      const selectedFieldEl = state.selectedFieldId
        ? rowEl.querySelector(`[data-link-field-key="${CSS.escape(state.selectedFieldId)}"]`)
        : null;
      centerElementInScroller(traceScroller, selectedFieldEl || rowEl, { vertical: true, horizontal: true });
      state.lastScrollTopByLane[state.lane] = traceScroller.scrollTop;
      state.lastScrollLeftByLane[state.lane] = traceScroller.scrollLeft;
      syncPersistentScrollbar("trace");
    }
  }

  function shouldPulseField(fieldKey, rowId) {
    if (!fieldKey || fieldKey !== state.flashFieldKey) {
      return false;
    }
    if (!rowId) {
      return true;
    }
    return !state.flashRowId || state.flashRowId === rowId;
  }

  function shouldPulseWord(wordId) {
    if (!wordId || !state.flashFieldKey) {
      return false;
    }
    const selection = parseFieldSelectionKey(state.flashFieldKey);
    return !!selection && selection.wordId === wordId;
  }

  function isRowSelectedField(rowId, fieldKey) {
    return !!fieldKey && rowId === state.selectedRowId && fieldKey === state.selectedFieldId;
  }

  function fieldLinkKey(field) {
    if (!field) {
      return "";
    }
    if (field.forcedLinkKey) {
      return field.forcedLinkKey;
    }
    if (field.linkWordId && field.linkFieldId) {
      return makeWordFieldKey(field.linkWordId, field.linkFieldId);
    }
    if (field.linkWordId) {
      return makeWordSummaryKey(field.linkWordId, field.id || "meta");
    }
    return "";
  }

  function fieldWordLinkId(field) {
    return field && field.linkWordId ? field.linkWordId : "";
  }

  function queueFieldSync(rowId, fieldKey, wordId) {
    if (!fieldKey && !wordId) {
      return;
    }
    state.pendingFieldSync = {
      rowId: rowId || state.selectedRowId || "",
      fieldKey: fieldKey,
      wordId: wordId || "",
    };
    state.flashFieldKey = fieldKey;
    state.flashRowId = rowId || state.selectedRowId || "";
    if (fieldFlashTimer) {
      window.clearTimeout(fieldFlashTimer);
    }
    fieldFlashTimer = window.setTimeout(() => {
      fieldFlashTimer = 0;
      if (!state.flashFieldKey && !state.flashRowId) {
        return;
      }
      state.flashFieldKey = "";
      state.flashRowId = "";
      render();
    }, 1250);
  }

  function schedulePendingFieldSync() {
    if (!state.pendingFieldSync) {
      return;
    }
    if (fieldSyncRaf) {
      window.clearTimeout(fieldSyncRaf);
    }
    fieldSyncRaf = window.setTimeout(() => {
      fieldSyncRaf = 0;
      applyPendingFieldSync();
    }, 0);
  }

  function applyPendingFieldSync() {
    const pending = state.pendingFieldSync;
    if (!pending) {
      return;
    }
    state.pendingFieldSync = null;
    recordAction("field-sync-apply", pending.fieldKey || pending.wordId || pending.rowId || "");
    scrollTraceFieldIntoView(pending.rowId, pending.fieldKey);
    scrollSideFieldIntoView(pending.rowId, pending.fieldKey, pending.wordId);
    if (fieldSyncSettleTimer) {
      window.clearTimeout(fieldSyncSettleTimer);
    }
    fieldSyncSettleTimer = window.setTimeout(() => {
      fieldSyncSettleTimer = 0;
      recordAction("field-sync-settle", pending.fieldKey || pending.wordId || pending.rowId || "");
      scrollTraceFieldIntoView(pending.rowId, pending.fieldKey);
      scrollSideFieldIntoView(pending.rowId, pending.fieldKey, pending.wordId);
    }, 80);
  }

  function scrollTraceFieldIntoView(rowId, fieldKey) {
    if (!fieldKey) {
      return;
    }
    const rowSelector = rowId ? `.trace-row[data-row-id="${CSS.escape(rowId)}"]` : ".trace-row.selected";
    const traceScroller = root.querySelector('[data-role="trace-scroll"]');
    const fieldSelector = `${rowSelector} [data-link-field-key="${CSS.escape(fieldKey)}"]`;
    const applyCenter = (attempt) => {
      const fieldEl = root.querySelector(fieldSelector);
      if (!traceScroller || !fieldEl) {
        return false;
      }
      centerElementInScroller(traceScroller, fieldEl, { vertical: true, horizontal: true });
      state.lastScrollTopByLane[state.lane] = traceScroller.scrollTop;
      state.lastScrollLeftByLane[state.lane] = traceScroller.scrollLeft;
      syncPersistentScrollbar("trace");
      const delta = centerDeltaInScroller(traceScroller, fieldEl);
      if (Math.abs(delta.x) <= 18 && Math.abs(delta.y) <= 18) {
        return true;
      }
      if (attempt >= 4) {
        return true;
      }
      traceCenterTimer = window.setTimeout(() => {
        traceCenterTimer = 0;
        applyCenter(attempt + 1);
      }, 80);
      return false;
    };
    if (traceCenterTimer) {
      window.clearTimeout(traceCenterTimer);
      traceCenterTimer = 0;
    }
    if (applyCenter(0)) {
      return;
    }
    if (rowId) {
      scrollRowIntoView(rowId);
    }
  }

  function scrollSideFieldIntoView(rowId, fieldKey, wordId) {
    if (!fieldKey && !wordId) {
      return;
    }
    const sideBody = root.querySelector(".side-body");
    if (!sideBody) {
      return;
    }
    const resolveTarget = () => {
      if (rowId && fieldKey) {
        const scopedFieldTarget = root.querySelector(`.side-body [data-row-id="${CSS.escape(rowId)}"] [data-word-field-key="${CSS.escape(fieldKey)}"]`);
        if (scopedFieldTarget) {
          return scopedFieldTarget;
        }
        const scopedRowTarget = root.querySelector(`.side-body [data-row-id="${CSS.escape(rowId)}"][data-word-field-row-key="${CSS.escape(fieldKey)}"]`);
        if (scopedRowTarget) {
          return scopedRowTarget;
        }
      }
      if (fieldKey) {
        const fieldTarget = root.querySelector(`.side-body [data-word-field-key="${CSS.escape(fieldKey)}"]`);
        if (fieldTarget) {
          return fieldTarget;
        }
        const rowTarget = root.querySelector(`.side-body [data-word-field-row-key="${CSS.escape(fieldKey)}"]`);
        if (rowTarget) {
          return rowTarget;
        }
      }
      if (rowId) {
        const rowTarget = root.querySelector(`.side-body [data-row-id="${CSS.escape(rowId)}"]`);
        if (rowTarget) {
          return rowTarget;
        }
      }
      if (wordId) {
        return root.querySelector(`.side-body [data-word-id="${CSS.escape(wordId)}"]`);
      }
      return null;
    };
    if (sideCenterTimer) {
      window.clearTimeout(sideCenterTimer);
      sideCenterTimer = 0;
    }
    const applyCenter = (attempt) => {
      const target = resolveTarget();
      if (!sideBody || !target) {
        return;
      }
      centerElementInScroller(sideBody, target, { vertical: true, horizontal: true });
      state.lastSideScrollTopByTab[state.viewTab] = sideBody.scrollTop;
      state.lastSideScrollLeftByTab[state.viewTab] = sideBody.scrollLeft;
      syncPersistentScrollbar("side");
      const delta = centerDeltaInScroller(sideBody, target);
      if (Math.abs(delta.x) <= 18 && Math.abs(delta.y) <= 18) {
        return;
      }
      if (attempt >= 4) {
        return;
      }
      sideCenterTimer = window.setTimeout(() => {
        sideCenterTimer = 0;
        applyCenter(attempt + 1);
      }, 80);
    };
    applyCenter(0);
  }

  function showTooltip(text, x, y) {
    const parts = text.split(" | ");
    tooltipEl.innerHTML = `<strong>${escapeHtml(parts[0] || "")}</strong>${parts.slice(1).map((part) => `<div>${escapeHtml(part)}</div>`).join("")}`;
    tooltipEl.hidden = false;
    moveTooltip(x, y);
  }

  function moveTooltip(x, y) {
    const left = Math.min(window.innerWidth - 420, x + 14);
    const top = Math.min(window.innerHeight - 220, y + 16);
    tooltipEl.style.left = Math.max(8, left) + "px";
    tooltipEl.style.top = Math.max(8, top) + "px";
  }

  function hideTooltip() {
    tooltipEl.hidden = true;
  }

  function setWaveLinkHover(linkKey) {
    if (!linkKey) {
      return;
    }
    const selector = `[data-wave-link-key="${CSS.escape(linkKey)}"]`;
    if (activeWaveLinkKey === linkKey && root.querySelector(`${selector}.wave-link-hover`)) {
      return;
    }
    clearWaveLinkHover();
    activeWaveLinkKey = linkKey;
    root
      .querySelectorAll(selector)
      .forEach((node) => node.classList.add("wave-link-hover"));
  }

  function clearWaveLinkHover() {
    if (!activeWaveLinkKey) {
      return;
    }
    root
      .querySelectorAll(`[data-wave-link-key="${CSS.escape(activeWaveLinkKey)}"]`)
      .forEach((node) => node.classList.remove("wave-link-hover"));
    activeWaveLinkKey = "";
  }

  function findWavePanel(panelId) {
    return currentWavePanels().find((panel) => panel.panelId === panelId) || null;
  }

  function scheduleWaveRender() {
    syncWaveViewportControls();
    const waveToken = ++waveRenderToken;
    if (waveRenderRaf) {
      window.clearTimeout(waveRenderRaf);
    }
    waveRenderRaf = window.setTimeout(() => {
      waveRenderRaf = 0;
      renderWavePanels(waveToken);
    }, 0);
  }

  async function renderWavePanels(waveToken) {
    const renderToken = debugState.renderCount;
    clearWaveLinkHover();
    for (const panel of visibleWavePanels()) {
      if (waveToken !== waveRenderToken || renderToken !== debugState.renderCount) {
        return;
      }
      try {
        await renderWavePanel(panel, renderToken, waveToken);
      } catch (error) {
        noteError(error);
      }
    }
    if (waveToken !== waveRenderToken || renderToken !== debugState.renderCount) {
      return;
    }
    const waveStack = root.querySelector(".wave-panel-stack");
    if (waveStack) {
      waveStack.scrollTop = state.lastWaveScrollTopByKey[currentWaveScrollKey()] || 0;
    }
    applyPendingWaveSync();
    scheduleScrollbarSync();
  }

  async function renderWavePanel(panel, renderToken, waveToken) {
    const display = document.getElementById("WaveDrom_Display_" + panel.renderIndex);
    const status = root.querySelector(`[data-wave-status="${CSS.escape(panel.panelId)}"]`);
    if (!display) {
      return;
    }
    if (panel.legacyMode) {
      await renderLegacyWavePanel(panel, renderToken, waveToken, display, status);
      return;
    }
    const annotationHost = root.querySelector(`[data-wave-annotations="${CSS.escape(panel.panelId)}"]`);
    const decodeHost = root.querySelector(`[data-wave-decode="${CSS.escape(panel.panelId)}"]`);
    if (!annotationHost || !decodeHost) {
      return;
    }
    const sharedWave = usesSharedWaveViewport() ? currentSharedWaveState() : null;
    const panelState = sharedWave || normalizeWavePanelState(panel, state.wavePanelState[panel.panelId]);
    if (!sharedWave) {
      state.wavePanelState[panel.panelId] = panelState;
    }
    display.innerHTML = '<div class="wave-render-status">Rendering chunk...</div>';
    const view = sharedWave
      ? await buildSharedWaveViewModel(panel, sharedWave)
      : await buildChunkWaveViewModel(panel, panelState);
    if (waveToken !== waveRenderToken || renderToken !== debugState.renderCount || !view) {
      return;
    }
    if (status) {
      const cycleLabel = view.cycleStart != null && view.cycleEnd != null ? `cycles ${view.cycleStart}..${view.cycleEnd}` : "cycles n/a";
      status.textContent = `${sharedWave ? "Shared" : `Chunk ${panelState.chunkIndex + 1}/${panel.chunkCount}`} | ${cycleLabel} | view ${view.visibleSlots} cyc`;
    }
    display.innerHTML = "";
    if (window.WaveDrom && typeof window.WaveDrom.RenderWaveForm === "function") {
      window.WaveDrom.RenderWaveForm(panel.renderIndex, view.renderJson, "WaveDrom_Display_", false);
      restyleWaveSvg(display.querySelector("svg"), display);
      renderWaveHotspots(display, view.beatRows, panel, view.cycleStart);
    } else {
      display.innerHTML = '<div class="wave-render-status">WaveDrom runtime is unavailable.</div>';
    }
    renderWaveDecodeAxis(decodeHost, view.beatRows, panel, view.visibleSlots, view.cycleStart);
    renderWaveAnnotations(annotationHost, view.annotations, view.chunkMeta || null, panel, view.visibleSlots, view.cycleStart);
  }

  async function renderLegacyWavePanel(panel, renderToken, waveToken, display, status) {
    const decodeHost = root.querySelector(`[data-wave-decode="${CSS.escape(panel.panelId)}"]`);
    const sharedWave = usesSharedWaveViewport() ? currentSharedWaveState() : null;
    const panelState = sharedWave || normalizeWavePanelState(panel, state.wavePanelState[panel.panelId]);
    if (!sharedWave) {
      state.wavePanelState[panel.panelId] = panelState;
    }
    display.innerHTML = '<div class="wave-render-status">Rendering chunk...</div>';
    const view = sharedWave
      ? await buildSharedWaveViewModel(panel, sharedWave)
      : await buildChunkWaveViewModel(panel, panelState);
    if (waveToken !== waveRenderToken || renderToken !== debugState.renderCount || !view) {
      return;
    }
    if (status) {
      const cycleLabel = view.cycleStart != null && view.cycleEnd != null ? `cycles ${view.cycleStart}..${view.cycleEnd}` : "cycles n/a";
      status.textContent = `${sharedWave ? "Shared" : `Chunk ${panelState.chunkIndex + 1}/${panel.chunkCount}`} | ${cycleLabel} | view ${view.visibleSlots} cyc`;
    }
    display.innerHTML = "";
    if (window.WaveDrom && typeof window.WaveDrom.RenderWaveForm === "function") {
      window.WaveDrom.RenderWaveForm(panel.renderIndex, view.renderJson, "WaveDrom_Display_", false);
      restyleWaveSvg(display.querySelector("svg"), display);
      renderWaveHotspots(display, view.beatRows, panel, view.cycleStart);
    } else {
      display.innerHTML = '<div class="wave-render-status">WaveDrom runtime is unavailable.</div>';
    }
    renderWaveDecodeAxis(decodeHost, view.beatRows, panel, view.visibleSlots, view.cycleStart);
  }

  async function buildChunkWaveViewModel(panel, panelState) {
    const chunkMeta = panel.chunks[panelState.chunkIndex];
    if (!chunkMeta) {
      return null;
    }
    const chunk = await loadWaveChunk(chunkMeta.src);
    if (panel.legacyMode) {
      return buildLegacyChunkWaveViewModel(chunk, chunkMeta, panel, panelState);
    }
    return buildWaveViewModel(chunk, chunkMeta, panel, panelState);
  }

  async function buildLegacyChunkWaveViewModel(chunk, chunkMeta, panel, panelState) {
    const slotCount = chunkSlotCount(chunkMeta) || deriveWaveSlotCount(chunk.signal || []);
    const slotStart = Math.max(0, Math.min(Math.max(0, slotCount - 1), panelState.slotOffset));
    const slotStop = Math.max(slotStart + 1, Math.min(slotCount, slotStart + panelState.visibleSlots));
    const renderJson = JSON.parse(JSON.stringify(chunk));
    renderJson.signal = cropWaveSignal(chunk.signal || [], slotStart, slotStop);
    renderJson.config = Object.assign({}, renderJson.config || {}, { hscale: 1 });
    const cycleBase = Number(chunkMeta.cycleStart);
    const cycleStart = Number.isFinite(cycleBase) ? cycleBase + slotStart : null;
    const cycleEnd = cycleStart != null ? cycleStart + Math.max(0, slotStop - slotStart - 1) : null;
    if (renderJson.head && cycleStart != null && cycleEnd != null) {
      renderJson.head = Object.assign({}, renderJson.head, {
        text: `${panel.title}: cycles ${cycleStart}..${cycleEnd}`,
      });
    }
    return {
      renderJson: renderJson,
      annotations: [],
      beatRows: filterWaveBeatRowsByFrame(await buildLegacyBeatRows(panel, chunk, chunkMeta, slotStart, slotStop)),
      cycleStart: cycleStart,
      cycleEnd: cycleEnd,
      visibleSlots: slotStop - slotStart,
    };
  }

  function deriveWaveSlotCount(signal) {
    for (const entry of signal || []) {
      if (Array.isArray(entry)) {
        const nested = deriveWaveSlotCount(entry.slice(1));
        if (nested > 0) {
          return nested;
        }
      } else if (entry && typeof entry === "object" && typeof entry.wave === "string") {
        return entry.wave.length;
      }
    }
    return 0;
  }

  function parseWaveRowSlots(row) {
    const slots = [];
    const labels = Array.isArray(row.data) ? row.data : [];
    let prevToken = "x";
    let dataIndex = 0;
    String(row.wave || "").split("").forEach((char) => {
      const token = char === "." ? prevToken : char;
      let label = null;
      if (char !== "." && !["0", "1", "x", "z"].includes(token)) {
        label = labels[dataIndex] || "";
        dataIndex += 1;
      }
      slots.push({ token: token, label: label });
      prevToken = token;
    });
    return slots;
  }

  function extractWaveDataCells(row) {
    const cells = [];
    const labels = Array.isArray(row.data) ? row.data : [];
    let prevToken = "x";
    let dataIndex = 0;
    let active = null;
    String(row.wave || "").split("").forEach((char, slotIndex) => {
      const token = char === "." ? prevToken : char;
      const isDataToken = !["0", "1", "x", "z"].includes(token);
      if (char !== ".") {
        if (active) {
          cells.push(active);
          active = null;
        }
        if (isDataToken) {
          active = {
            slotStart: slotIndex,
            slotEnd: slotIndex,
            label: labels[dataIndex] || "",
            token: token,
          };
          dataIndex += 1;
        }
      } else if (active && isDataToken) {
        active.slotEnd = slotIndex;
      } else if (active) {
        cells.push(active);
        active = null;
      }
      prevToken = token;
    });
    if (active) {
      cells.push(active);
    }
    return cells;
  }

  function visitLegacySignalRows(entries, groupLabel, visitor) {
    (entries || []).forEach((entry) => {
      if (Array.isArray(entry)) {
        const nextGroup = entry[0] ? String(entry[0]) : groupLabel;
        visitLegacySignalRows(entry.slice(1), nextGroup, visitor);
        return;
      }
      if (entry && typeof entry === "object") {
        visitor(entry, groupLabel || "");
      }
    });
  }

  function legacyWaveDataRowDescriptors(panel, chunk) {
    const rows = [];
    visitLegacySignalRows(chunk.signal || [], "", (entry, groupLabel) => {
      const name = String(entry.name || "").trim();
      if (!name) {
        return;
      }
      if (panel.panelId === "dma") {
        if (name === "data[255:0]") {
          rows.push({
            rowKey: "dma",
            lane: -1,
            row: entry,
          });
        }
        return;
      }
      if (name !== "data[31:0]") {
        return;
      }
      if (panel.panelId === "ingress") {
        const laneMatch = /Lane\s+(\d+)/i.exec(groupLabel || "");
        if (!laneMatch) {
          return;
        }
        rows.push({
          rowKey: `lane-${laneMatch[1]}`,
          lane: Number(laneMatch[1]),
          row: entry,
        });
        return;
      }
      rows.push({
        rowKey: panel.panelId || "egress",
        lane: -1,
        row: entry,
      });
    });
    return rows.sort((left, right) => left.rowKey.localeCompare(right.rowKey, undefined, { numeric: true }));
  }

  function packetRowPriority(packet) {
    if (!packet) {
      return 0;
    }
    if (packet.rowType === "hit") {
      return 3;
    }
    if (packet.rowType === "subpkt" || packet.rowType === "subpacket") {
      return 2;
    }
    if (packet.rowType === "frame") {
      return 1;
    }
    return 0;
  }

  function legacyWaveLinkTargetKey(section, lane, cycle) {
    return [section, String(lane), String(cycle)].join("::");
  }

  function legacyWaveTargetGroup(packet, wordId, label) {
    const wordText = String(wordId || "").toLowerCase();
    const labelText = String(label || "");
    if (wordText === "eop" || /trailer/i.test(labelText)) {
      return "trailer";
    }
    if (wordText.includes("subheader") || /^S[0-9A-F]{2}\//i.test(labelText)) {
      return "subheader";
    }
    if (wordText.includes("hit") || /^[0-9A-F]{8}$/i.test(labelText)) {
      return "hit";
    }
    return "header";
  }

  function legacyWaveTargetTooltip(label, packet, word) {
    const parts = [];
    if (label) {
      parts.push(label);
    }
    if (packet && packet.rowId) {
      parts.push(packet.rowId);
    }
    if (word && word.wordLabel) {
      parts.push(word.wordLabel);
    }
    if (word && word.rawHex) {
      parts.push(word.rawHex);
    }
    if (word && Number.isFinite(Number(word.cycle))) {
      parts.push(`C${Number(word.cycle)}`);
    } else if (packet && Number.isFinite(Number(packet.cycle))) {
      parts.push(`C${Number(packet.cycle)}`);
    }
    return parts.filter(Boolean).join(" | ");
  }

  function buildLegacyWaveLinkTargetIndex(section) {
    const targets = new Map();
    rowMap.forEach((packet) => {
      if (!packet || packet.section !== section) {
        return;
      }
      if (section === "dma") {
        if (packet.kind !== "dma_word") {
          return;
        }
        const cycle = Number(packet.cycle);
        if (!Number.isFinite(cycle)) {
          return;
        }
        const key = legacyWaveLinkTargetKey(section, -1, cycle);
        const candidate = {
          priority: packetRowPriority(packet) + 1,
          rowId: packet.rowId,
          targetRowId: packet.rowId,
          traceRowId: packet.rowId,
          wordId: "",
          group: "header",
          tooltip: [packet.packetLabel, packet.rowId, `C${cycle}`].filter(Boolean).join(" | "),
        };
        const previous = targets.get(key);
        if (!previous || candidate.priority >= previous.priority) {
          targets.set(key, candidate);
        }
        return;
      }
      detailWords(packet).forEach((word) => {
        const cycle = Number(word.cycle != null ? word.cycle : packet.cycle);
        if (!Number.isFinite(cycle)) {
          return;
        }
        const key = legacyWaveLinkTargetKey(section, packet.lane, cycle);
        const candidate = {
          priority: packetRowPriority(packet),
          rowId: packet.rowId,
          targetRowId: packet.rowId,
          traceRowId: packet.rowId,
          wordId: word.wordId || "",
          group: legacyWaveTargetGroup(packet, word.wordId || "", word.rawHex || ""),
          tooltip: legacyWaveTargetTooltip("", packet, word),
        };
        const previous = targets.get(key);
        if (!previous || candidate.priority >= previous.priority) {
          targets.set(key, candidate);
        }
      });
    });
    return targets;
  }

  async function ensureLegacyWaveLinkData(panel) {
    if (!panel || !panel.legacyMode) {
      return;
    }
    if (panel.panelId !== "ingress") {
      return;
    }
    const laneLoads = (manifest.lanes || [])
      .map((laneInfo) => String(laneInfo.lane))
      .filter((laneKey) => laneKey !== "-1");
    await Promise.all(laneLoads.map(async (laneKey) => {
      try {
        await ensureLaneData(laneKey);
      } catch (error) {
        noteError(error);
      }
    }));
  }

  async function buildLegacyBeatRows(panel, chunk, chunkMeta, slotStart, slotStop) {
    await ensureLegacyWaveLinkData(panel);
    const cycleBase = Number(chunkMeta.cycleStart);
    const targetIndex = buildLegacyWaveLinkTargetIndex(panel.panelId);
    const visibleSlotCount = Math.max(1, slotStop - slotStart);
    return legacyWaveDataRowDescriptors(panel, chunk)
      .map((descriptor) => {
        const cells = extractWaveDataCells(descriptor.row)
          .map((cell) => {
            const start = Math.max(slotStart, Number(cell.slotStart) || 0);
            const end = Math.min(slotStop - 1, Number(cell.slotEnd) || Number(cell.slotStart) || 0);
            if (end < start) {
              return null;
            }
            const absoluteCycle = Number.isFinite(cycleBase) ? cycleBase + (Number(cell.slotStart) || 0) : (Number(cell.slotStart) || 0);
            const target = targetIndex.get(legacyWaveLinkTargetKey(panel.panelId, descriptor.lane, absoluteCycle));
            if (!target) {
              return null;
            }
            const label = String(cell.label || "").trim() || target.wordId || target.targetRowId;
            return {
              slotStart: start - slotStart,
              slotEnd: end - slotStart,
              label: label,
              fullLabel: legacyWaveTargetTooltip(label, rowMap.get(target.targetRowId) || null, target.wordId && rowMap.has(target.targetRowId)
                ? detailWords(rowMap.get(target.targetRowId)).find((word) => word.wordId === target.wordId) || null
                : null) || target.tooltip || label,
              linkKey: `${target.targetRowId}::${target.wordId || descriptor.rowKey}::${absoluteCycle}`,
              rowId: target.rowId,
              targetRowId: target.targetRowId,
              traceRowId: target.traceRowId,
              wordId: target.wordId,
              group: target.group,
              kind: target.group,
            };
          })
          .filter(Boolean);
        if (!cells.length) {
          return null;
        }
        return {
          rowKey: descriptor.rowKey,
          slotCount: visibleSlotCount,
          cells: cells,
        };
      })
      .filter(Boolean);
  }

  function mergeLegacyBeatRows(rowSets, visibleSlots) {
    const order = [];
    const rows = new Map();
    (rowSets || []).forEach((rowSet) => {
      (rowSet || []).forEach((row) => {
        const key = row.rowKey || `row-${order.length}`;
        if (!rows.has(key)) {
          rows.set(key, {
            rowKey: key,
            slotCount: visibleSlots,
            cells: [],
          });
          order.push(key);
        }
        rows.get(key).cells.push(...(row.cells || []));
      });
    });
    return order.map((key) => {
      const row = rows.get(key);
      row.cells.sort((left, right) => (left.slotStart || 0) - (right.slotStart || 0));
      row.slotCount = visibleSlots;
      return row;
    });
  }

  function cropWaveSignal(signal, slotStart, slotStop) {
    return (signal || []).map((entry) => cropWaveEntry(entry, slotStart, slotStop));
  }

  function cropWaveEntry(entry, slotStart, slotStop) {
    if (Array.isArray(entry)) {
      if (!entry.length) {
        return [];
      }
      return [entry[0]].concat(entry.slice(1).map((child) => cropWaveEntry(child, slotStart, slotStop)));
    }
    if (!entry || typeof entry !== "object" || typeof entry.wave !== "string") {
      return entry;
    }
    const slots = parseWaveRowSlots(entry).slice(slotStart, slotStop);
    const wave = [];
    const data = [];
    let prevToken = "";
    slots.forEach((slot) => {
      const token = slot.token || "x";
      const renderToken = token === prevToken && ["0", "1", "x", "z"].includes(token) ? "." : token;
      wave.push(renderToken);
      if (slot.label && renderToken !== "." && !["0", "1", "x", "z"].includes(renderToken) && entry.name !== "FEB_DATA_FRAME") {
        data.push(slot.label);
      }
      prevToken = token;
    });
    const cropped = Object.assign({}, entry, { wave: wave.join("") });
    if (data.length) {
      cropped.data = data;
    } else {
      delete cropped.data;
    }
    return cropped;
  }

  function cropWaveAnnotations(annotations, slotStart, slotStop) {
    return (annotations || [])
      .map((annotation) => {
        const start = Math.max(slotStart, Number(annotation.slotStart) || 0);
        const end = Math.min(slotStop - 1, Number(annotation.slotEnd) || 0);
        if (end < start) {
          return null;
        }
        return Object.assign({}, annotation, {
          slotStart: start - slotStart,
          slotEnd: end - slotStart,
        });
      })
      .filter(Boolean);
  }

  function waveAbbreviationLevel(visibleSlots) {
    if (visibleSlots <= 12) {
      return 0;
    }
    if (visibleSlots <= 24) {
      return 1;
    }
    if (visibleSlots <= 64) {
      return 2;
    }
    if (visibleSlots <= 160) {
      return 3;
    }
    return 4;
  }

  function cropWaveBeatLinks(beatLinks, slotStart, slotStop) {
    return (beatLinks || [])
      .map((beat) => {
        const start = Math.max(slotStart, Number(beat.slotStart) || 0);
        const end = Math.min(slotStop - 1, Number(beat.slotEnd) || 0);
        if (end < start) {
          return null;
        }
        return Object.assign({}, beat, {
          slotStart: start - slotStart,
          slotEnd: end - slotStart,
        });
      })
      .filter(Boolean);
  }

  function filterWaveAnnotationsByFrame(annotations) {
    if (!state.frameFilter) {
      return annotations;
    }
    return (annotations || []).filter((annotation) => rowIdMatchesFrameFilter(annotation.rowId || ""));
  }

  function filterWaveBeatRowsByFrame(beatRows) {
    if (!state.frameFilter) {
      return beatRows;
    }
    return (beatRows || [])
      .map((row) => Object.assign({}, row, {
        cells: (row.cells || []).filter((cell) => rowIdMatchesFrameFilter(cell.targetRowId || cell.rowId || "")),
      }))
      .filter((row) => row.cells.length > 0);
  }

  function normalizeWaveBeatRows(beatLinks, slotCount) {
    const groups = new Map();
    beatLinks.forEach((beat) => {
      const band = beat.band || "";
      if (!groups.has(band)) {
        groups.set(band, []);
      }
      groups.get(band).push(beat);
    });
    return Array.from(groups.values()).map((items) => ({
      slotCount: slotCount,
      cells: items
        .slice()
        .sort((left, right) => (left.slotStart || 0) - (right.slotStart || 0))
        .map((beat) => ({
          slotStart: beat.slotStart || 0,
          slotEnd: beat.slotEnd || 0,
          label: beat.label || "",
          fullLabel: beat.tooltip || beat.label || "",
          linkKey: beat.linkKey || `${beat.targetRowId || beat.rowId || ""}::${beat.wordId || ""}::${beat.slotStart || 0}`,
          rowId: beat.rowId || "",
          targetRowId: beat.targetRowId || beat.rowId || "",
          traceRowId: beat.traceRowId || beat.targetRowId || beat.rowId || "",
          wordId: beat.wordId || "",
          group: beat.group || "header",
          kind: beat.kind || "",
        })),
    }));
  }

  function abbreviateHitWaveLabel(text, level) {
    const channel = /channel=(\d+)/.exec(text);
    const col = /col=(\d+)/.exec(text);
    const row = /row=(\d+)/.exec(text);
    const tot = /tot=(\d+)/.exec(text);
    const energy = /energy=0x([0-9A-F]+)/.exec(text);
    if (channel) {
      if (level >= 4) {
        return "";
      }
      if (level === 3) {
        return `C${channel[1]}`;
      }
      return `C${channel[1]}${energy ? ` E${energy[1]}` : ""}`;
    }
    if (level >= 4) {
      return "";
    }
    if (level === 3) {
      return col && row ? `${col[1]}/${row[1]}` : "H";
    }
    return [
      col ? `c${col[1]}` : "",
      row ? `r${row[1]}` : "",
      tot ? `t${tot[1]}` : "",
    ].filter(Boolean).join(" ");
  }

  function displayWaveBeatLabel(cell, slotPixelWidth, visibleSlots) {
    const level = waveAbbreviationLevel(visibleSlots);
    const width = Number(slotPixelWidth) || 0;
    if (width < 26) {
      return "";
    }
    if (cell.group === "header") {
      if (width < 42) {
        return "";
      }
      if (width < 68 && level >= 2) {
        return "";
      }
      const map = {
        preamble: level >= 2 ? "HDR" : "Preamble",
        ts_high: "TSH",
        ts_low_pkg: "TSL",
        debug0: "D0",
        debug1: "D1",
      };
      return map[cell.wordId] || (level >= 2 ? "HDR" : cell.label);
    }
    if (cell.group === "subheader") {
      if (width < 44) {
        return "";
      }
      if (level >= 3 || width < 72) {
        return "SH";
      }
      const token = /^S\d+/.exec(cell.label);
      return token ? token[0] : "SubHdr";
    }
    if (cell.group === "trailer") {
      if (width < 44) {
        return "";
      }
      return level >= 3 || width < 72 ? "TR" : "TRL";
    }
    if (width < 72 || level >= 4) {
      return "";
    }
    if (level >= 3 && width < 110) {
      return "";
    }
    return abbreviateHitWaveLabel(cell.label, level);
  }

  function isWaveCellSelected(cell) {
    if (!cell || !state.selectedRowId) {
      return false;
    }
    const rowId = cell.targetRowId || cell.rowId || "";
    if (rowId !== state.selectedRowId) {
      return false;
    }
    if (state.selectedWordId) {
      return (cell.wordId || "") === state.selectedWordId;
    }
    return true;
  }

  function buildWaveViewModel(chunk, chunkMeta, panel, panelState) {
    const slotCount = chunkSlotCount(chunkMeta) || deriveWaveSlotCount(chunk.signal || []);
    const slotStart = Math.max(0, Math.min(Math.max(0, slotCount - 1), panelState.slotOffset));
    const slotStop = Math.max(slotStart + 1, Math.min(slotCount, slotStart + panelState.visibleSlots));
    const renderJson = JSON.parse(JSON.stringify(chunk));
    renderJson.signal = cropWaveSignal(chunk.signal || [], slotStart, slotStop);
    renderJson.annotations = undefined;
    renderJson.config = Object.assign({}, renderJson.config || {}, { hscale: 1 });
    const cycleBase = Number(chunkMeta.cycleStart);
    const cycleStart = Number.isFinite(cycleBase) ? cycleBase + slotStart : null;
    const cycleEnd = cycleStart != null ? cycleStart + Math.max(0, slotStop - slotStart - 1) : null;
    if (renderJson.head && cycleStart != null && cycleEnd != null) {
      renderJson.head = Object.assign({}, renderJson.head, {
        text: `${panel.title}: cycles ${cycleStart}..${cycleEnd}`,
      });
    }
    const beatRows = panel.decodeEnabled === false ? [] : normalizeWaveBeatRows(cropWaveBeatLinks(chunk.beatLinks || [], slotStart, slotStop), slotStop - slotStart);
    return {
      renderJson: renderJson,
      annotations: filterWaveAnnotationsByFrame(cropWaveAnnotations(chunk.annotations || [], slotStart, slotStop)),
      beatRows: filterWaveBeatRowsByFrame(beatRows),
      cycleStart: cycleStart,
      cycleEnd: cycleEnd,
      visibleSlots: slotStop - slotStart,
    };
  }

  function defaultWaveTokenForRow(name) {
    if (name === "clk250") {
      return "P";
    }
    if (name === "valid" || name === "datak!=0") {
      return "0";
    }
    return "x";
  }

  function blankWaveSlots(slotCount, token) {
    return Array.from({ length: slotCount }, () => ({ token: token, label: null }));
  }

  function emitWaveRowSlots(slots) {
    const wave = [];
    const data = [];
    let prevToken = "";
    slots.forEach((slot) => {
      const token = slot && slot.token ? slot.token : "x";
      const renderToken = token === prevToken && ["0", "1", "x", "z"].includes(token) ? "." : token;
      wave.push(renderToken);
      if (slot && slot.label && renderToken !== "." && !["0", "1", "x", "z"].includes(renderToken)) {
        data.push(slot.label);
      }
      prevToken = token;
    });
    const row = { wave: wave.join("") };
    if (data.length) {
      row.data = data;
    }
    return row;
  }

  function mergeSharedSignalEntry(templateEntry, sourceEntries, cycleStart, visibleSlots) {
    if (Array.isArray(templateEntry)) {
      return [templateEntry[0]].concat(
        templateEntry.slice(1).map((child, index) => mergeSharedSignalEntry(
          child,
          sourceEntries.map((entry) => ({
            meta: entry.meta,
            node: Array.isArray(entry.node) ? entry.node[index + 1] : undefined,
          })),
          cycleStart,
          visibleSlots
        ))
      );
    }
    if (!templateEntry || typeof templateEntry !== "object" || typeof templateEntry.wave !== "string") {
      return templateEntry && typeof templateEntry === "object" ? Object.assign({}, templateEntry) : templateEntry;
    }
    if ((templateEntry.name || "") === "clk250") {
      return Object.assign({}, templateEntry, { wave: "P" + ".".repeat(Math.max(0, visibleSlots - 1)) });
    }
    const slots = blankWaveSlots(visibleSlots, defaultWaveTokenForRow(templateEntry.name || ""));
    sourceEntries.forEach((entry) => {
      if (!entry || !entry.meta || !entry.node || typeof entry.node.wave !== "string") {
        return;
      }
      const chunkStart = Number(entry.meta.cycleStart);
      const chunkEnd = Number(entry.meta.cycleEnd);
      if (!Number.isFinite(chunkStart) || !Number.isFinite(chunkEnd)) {
        return;
      }
      const overlapStart = Math.max(cycleStart, chunkStart);
      const overlapEnd = Math.min(cycleStart + visibleSlots - 1, chunkEnd);
      if (overlapEnd < overlapStart) {
        return;
      }
      const parsed = parseWaveRowSlots(entry.node);
      for (let cycle = overlapStart; cycle <= overlapEnd; cycle += 1) {
        const localIndex = cycle - chunkStart;
        const globalIndex = cycle - cycleStart;
        if (localIndex < 0 || localIndex >= parsed.length || globalIndex < 0 || globalIndex >= slots.length) {
          continue;
        }
        slots[globalIndex] = parsed[localIndex];
      }
    });
    const emitted = emitWaveRowSlots(slots);
    const next = Object.assign({}, templateEntry, { wave: emitted.wave });
    if (emitted.data && !["FEB_DATA_FRAME", "DMA256"].includes(templateEntry.name || "")) {
      next.data = emitted.data;
    } else {
      delete next.data;
    }
    return next;
  }

  function mergeSharedSignal(templateSignal, chunkEntries, cycleStart, visibleSlots) {
    return (templateSignal || []).map((entry, index) => mergeSharedSignalEntry(
      entry,
      chunkEntries.map((chunkEntry) => ({
        meta: chunkEntry.meta,
        node: (chunkEntry.chunk.signal || [])[index],
      })),
      cycleStart,
      visibleSlots
    ));
  }

  function mergeSharedBeatLinks(chunkEntries, cycleStart, visibleSlots) {
    const cycleEnd = cycleStart + visibleSlots - 1;
    const merged = [];
    chunkEntries.forEach((chunkEntry) => {
      const chunkStart = Number(chunkEntry.meta.cycleStart);
      (chunkEntry.chunk.beatLinks || []).forEach((beat) => {
        const beatStart = chunkStart + (Number(beat.slotStart) || 0);
        const beatEnd = chunkStart + (Number(beat.slotEnd) || Number(beat.slotStart) || 0);
        const overlapStart = Math.max(cycleStart, beatStart);
        const overlapEnd = Math.min(cycleEnd, beatEnd);
        if (overlapEnd < overlapStart) {
          return;
        }
        merged.push(Object.assign({}, beat, {
          slotStart: overlapStart - cycleStart,
          slotEnd: overlapEnd - cycleStart,
        }));
      });
    });
    return merged;
  }

  function mergeSharedAnnotations(chunkEntries, cycleStart, visibleSlots) {
    const cycleEnd = cycleStart + visibleSlots - 1;
    const merged = [];
    chunkEntries.forEach((chunkEntry) => {
      const chunkStart = Number(chunkEntry.meta.cycleStart);
      (chunkEntry.chunk.annotations || []).forEach((annotation) => {
        const annoStart = chunkStart + (Number(annotation.slotStart) || 0);
        const annoEnd = chunkStart + (Number(annotation.slotEnd) || Number(annotation.slotStart) || 0);
        const overlapStart = Math.max(cycleStart, annoStart);
        const overlapEnd = Math.min(cycleEnd, annoEnd);
        if (overlapEnd < overlapStart) {
          return;
        }
        merged.push(Object.assign({}, annotation, {
          slotStart: overlapStart - cycleStart,
          slotEnd: overlapEnd - cycleStart,
        }));
      });
    });
    return merged;
  }

  async function buildSharedWaveViewModel(panel, sharedState) {
    if (panel.legacyMode) {
      return buildLegacySharedWaveViewModel(panel, sharedState);
    }
    const cycleStart = Number(sharedState.cycleStart) || 0;
    const visibleSlots = Math.max(1, Number(sharedState.visibleSlots) || 16);
    const cycleEnd = cycleStart + visibleSlots - 1;
    const overlappingMeta = (panel.chunks || []).filter((chunkMeta) => {
      const chunkStart = Number(chunkMeta.cycleStart);
      const chunkEnd = Number(chunkMeta.cycleEnd);
      return Number.isFinite(chunkStart) && Number.isFinite(chunkEnd) && chunkEnd >= cycleStart && chunkStart <= cycleEnd;
    });
    const templateChunkMeta = overlappingMeta[0] || panel.chunks[0];
    if (!templateChunkMeta) {
      return null;
    }
    const templateChunk = await loadWaveChunk(templateChunkMeta.src);
    const chunkEntries = await Promise.all(
      overlappingMeta.map(async (chunkMeta) => ({
        meta: chunkMeta,
        chunk: await loadWaveChunk(chunkMeta.src),
      }))
    );
    const beatRows = panel.decodeEnabled === false ? [] : normalizeWaveBeatRows(mergeSharedBeatLinks(chunkEntries, cycleStart, visibleSlots), visibleSlots);
    return {
      chunkMeta: {
        detail: `cycles ${cycleStart}..${cycleEnd}`,
      },
      renderJson: {
        signal: mergeSharedSignal(templateChunk.signal || [], chunkEntries, cycleStart, visibleSlots),
        config: Object.assign({}, templateChunk.config || {}, { hscale: 1 }),
        head: {
          text: `${panel.title}: cycles ${cycleStart}..${cycleEnd}`,
          tick: 0,
        },
      },
      annotations: filterWaveAnnotationsByFrame(mergeSharedAnnotations(chunkEntries, cycleStart, visibleSlots)),
      beatRows: filterWaveBeatRowsByFrame(beatRows),
      cycleStart: cycleStart,
      cycleEnd: cycleEnd,
      visibleSlots: visibleSlots,
    };
  }

  async function buildLegacySharedWaveViewModel(panel, sharedState) {
    const cycleStart = Number(sharedState.cycleStart) || 0;
    const visibleSlots = Math.max(1, Number(sharedState.visibleSlots) || 16);
    const cycleEnd = cycleStart + visibleSlots - 1;
    const overlappingMeta = (panel.chunks || []).filter((chunkMeta) => {
      const chunkStart = Number(chunkMeta.cycleStart);
      const chunkEnd = Number(chunkMeta.cycleEnd);
      return Number.isFinite(chunkStart) && Number.isFinite(chunkEnd) && chunkEnd >= cycleStart && chunkStart <= cycleEnd;
    });
    const templateChunkMeta = overlappingMeta[0] || panel.chunks[0];
    if (!templateChunkMeta) {
      return null;
    }
    const templateChunk = await loadWaveChunk(templateChunkMeta.src);
    const chunkEntries = await Promise.all(
      overlappingMeta.map(async (chunkMeta) => ({
        meta: chunkMeta,
        chunk: await loadWaveChunk(chunkMeta.src),
      }))
    );
    const beatRowSets = await Promise.all(chunkEntries.map(async (chunkEntry) => {
      const chunkStart = Number(chunkEntry.meta.cycleStart) || 0;
      const slotCount = chunkSlotCount(chunkEntry.meta) || deriveWaveSlotCount(chunkEntry.chunk.signal || []);
      const localStart = Math.max(0, cycleStart - chunkStart);
      const localStop = Math.max(localStart + 1, Math.min(slotCount, cycleEnd - chunkStart + 1));
      if (localStop <= localStart) {
        return [];
      }
      return buildLegacyBeatRows(panel, chunkEntry.chunk, chunkEntry.meta, localStart, localStop);
    }));
    return {
      chunkMeta: {
        detail: `cycles ${cycleStart}..${cycleEnd}`,
      },
      renderJson: {
        signal: mergeSharedSignal(templateChunk.signal || [], chunkEntries, cycleStart, visibleSlots),
        config: Object.assign({}, templateChunk.config || {}, { hscale: 1 }),
        head: {
          text: `${panel.title}: cycles ${cycleStart}..${cycleEnd}`,
          tick: 0,
        },
      },
      annotations: [],
      beatRows: filterWaveBeatRowsByFrame(mergeLegacyBeatRows(beatRowSets, visibleSlots)),
      cycleStart: cycleStart,
      cycleEnd: cycleEnd,
      visibleSlots: visibleSlots,
    };
  }

  function loadWaveChunk(src) {
    if (waveChunkCache.has(src)) {
      return waveChunkCache.get(src);
    }
    const promise = fetch(src, { cache: "no-store" }).then((response) => {
      if (!response.ok) {
        throw new Error("HTTP " + response.status + " while loading " + src);
      }
      return response.json();
    });
    waveChunkCache.set(src, promise);
    return promise;
  }

  function restyleWaveSvg(svg, display) {
    if (!svg) {
      return;
    }
    svg.style.background = "transparent";
    svg.querySelectorAll("text").forEach((node) => {
      node.setAttribute("fill", "#16314f");
      node.setAttribute("font-family", "\"IBM Plex Sans\", \"Segoe UI\", sans-serif");
    });
    svg.querySelectorAll("rect").forEach((node) => {
      const fill = (node.getAttribute("fill") || "").toLowerCase();
      if (fill === "#fff" || fill === "white") {
        node.setAttribute("fill", "transparent");
      }
    });
    fitWaveSvgToDisplay(svg, display);
  }

  function fitWaveSvgToDisplay(svg, display) {
    if (!svg || !display) {
      return;
    }
    const widthAttr = Number(svg.getAttribute("width")) || 0;
    const heightAttr = Number(svg.getAttribute("height")) || 0;
    if (!svg.getAttribute("viewBox") && widthAttr > 0 && heightAttr > 0) {
      svg.setAttribute("viewBox", `0 0 ${widthAttr} ${heightAttr}`);
    }
    svg.setAttribute("preserveAspectRatio", "xMinYMin meet");
    svg.style.display = "block";
    svg.style.maxWidth = "100%";
    svg.style.height = "auto";
    svg.style.width = "100%";
  }

  function waveBeatTone(group) {
    const tones = {
      header: { fill: "#d7e7ff", text: "#173760", stroke: "#5b87ff" },
      subheader: { fill: "#d9f2ff", text: "#144765", stroke: "#70c7ff" },
      hit: { fill: "#dcf8e5", text: "#1f5631", stroke: "#5ecf87" },
      trailer: { fill: "#fff0d6", text: "#694016", stroke: "#f2b55a" },
    };
    return tones[group] || tones.header;
  }

  function renderWaveDecodeAxis(host, beatRows, panel, visibleSlots, cycleStart) {
    if (!host) {
      return;
    }
    if (panel.decodeEnabled === false && !panel.legacyMode) {
      host.innerHTML = '<div class="wave-decode-empty">Mu3e packet decode is not available for DMA payload words.</div>';
      return;
    }
    if (!beatRows.length) {
      host.innerHTML = '<div class="wave-decode-empty">No decoded FEB_DATA_FRAME labels in this window.</div>';
      return;
    }
    const trackWidth = Math.max(240, host.clientWidth || root.clientWidth || 960);
    host.innerHTML = beatRows.map((row) => {
      const slotPixelWidth = trackWidth / Math.max(1, row.slotCount);
      const buttons = row.cells.map((cell) => {
        const left = (cell.slotStart / row.slotCount) * 100;
        const span = Math.max(1, cell.slotEnd - cell.slotStart + 1);
        const width = Math.max(2.8, (span / row.slotCount) * 100);
        const tone = waveBeatTone(cell.group);
        const text = displayWaveBeatLabel(cell, slotPixelWidth * span, visibleSlots);
        const absoluteCycle = Number.isFinite(Number(cycleStart)) ? Number(cycleStart) + (Number(cell.slotStart) || 0) : "";
        return `
          <button
            class="wave-decode-tag ${isWaveCellSelected(cell) ? "wave-link-hover" : ""}"
            type="button"
            data-wave-link-key="${escapeHtml(cell.linkKey)}"
            data-wave-panel-id="${escapeHtml(panel.panelId || "")}"
            data-wave-cycle="${escapeHtml(String(absoluteCycle))}"
            data-wave-row-id="${escapeHtml(cell.targetRowId)}"
            data-wave-target-row-id="${escapeHtml(cell.targetRowId)}"
            data-wave-trace-row-id="${escapeHtml(cell.traceRowId || cell.targetRowId)}"
            data-wave-word-id="${escapeHtml(cell.wordId)}"
            data-wave-tooltip="${escapeHtml(cell.fullLabel)}"
            style="left:${left}%; width:${width}%; background:${escapeHtml(tone.fill)}; color:${escapeHtml(tone.text)}; border-color:${escapeHtml(tone.stroke)};"
          >${escapeHtml(text)}</button>
        `;
      }).join("");
      return `
        <div class="wave-decode-band">
          <div class="wave-decode-track">${buttons}</div>
        </div>
      `;
    }).join("");
    if (activeWaveLinkKey) {
      setWaveLinkHover(activeWaveLinkKey);
    }
  }

  function renderWaveHotspots(display, beatRows, panel, cycleStart) {
    if (!display) {
      return;
    }
    const svg = display.querySelector("svg");
    if (!svg) {
      return;
    }
    const existing = svg.querySelector(".wave-hotspot-layer");
    if (existing) {
      existing.remove();
    }
    if (!beatRows.length) {
      return;
    }
    const useRows = collectWaveBeatUseRows(svg, panel);
    if (!useRows.length) {
      return;
    }
    const layer = document.createElementNS("http://www.w3.org/2000/svg", "g");
    layer.setAttribute("class", "wave-hotspot-layer");
    beatRows.forEach((row, rowIndex) => {
      const sourceUses = useRows[Math.min(rowIndex, Math.max(0, useRows.length - 1))];
      if (!sourceUses || !sourceUses.length) {
        return;
      }
      row.cells.forEach((cell) => {
        for (let slot = cell.slotStart; slot <= cell.slotEnd; slot += 1) {
          const hotspot = cloneWaveBeatUse(sourceUses[slot], cell, panel, cycleStart);
          if (hotspot) {
            layer.appendChild(hotspot);
          }
        }
      });
    });
    svg.appendChild(layer);
    if (activeWaveLinkKey) {
      setWaveLinkHover(activeWaveLinkKey);
    }
  }

  function collectWaveBeatUseRows(svg, panel) {
    if (!svg) {
      return [];
    }
    if (panel && panel.legacyMode) {
      return collectLegacyWaveBeatUseRows(svg, panel);
    }
    return Array.from(svg.querySelectorAll("text.info"))
      .filter((node) => ["FEB_DATA_FRAME", "DMA256"].includes((node.textContent || "").trim()))
      .map((node) => {
        const rowGroup = node.parentNode
          ? Array.from(node.parentNode.children).find((child) => child.tagName && child.tagName.toLowerCase() === "g")
          : null;
        if (!rowGroup) {
          return [];
        }
        return Array.from(rowGroup.children).filter((child) => child.tagName && child.tagName.toLowerCase() === "use");
      })
      .filter((items) => items.length);
  }

  function collectLegacyWaveBeatUseRows(svg, panel) {
    const rowLabel = panel && panel.panelId === "dma" ? "data[255:0]" : "data[31:0]";
    return Array.from(svg.querySelectorAll("text.info"))
      .filter((node) => (node.textContent || "").trim() === rowLabel)
      .map((node) => {
        const rowGroup = node.parentNode
          ? Array.from(node.parentNode.children).find((child) => child.tagName && child.tagName.toLowerCase() === "g")
          : null;
        if (!rowGroup) {
          return [];
        }
        return Array.from(rowGroup.children).filter((child) => child.tagName && child.tagName.toLowerCase() === "use");
      })
      .filter((items) => items.length);
  }

  function cloneWaveBeatUse(sourceUse, cell, panel, cycleStart) {
    if (!sourceUse) {
      return null;
    }
    const href = sourceUse.getAttribute("href")
      || sourceUse.getAttribute("xlink:href")
      || sourceUse.getAttributeNS("http://www.w3.org/1999/xlink", "href")
      || "";
    if (!href) {
      return null;
    }
    const hotspot = document.createElementNS("http://www.w3.org/2000/svg", "use");
    hotspot.setAttribute("href", href);
    hotspot.setAttributeNS("http://www.w3.org/1999/xlink", "href", href);
    ["transform", "x", "y", "width", "height"].forEach((attr) => {
      const value = sourceUse.getAttribute(attr);
      if (value != null && value !== "") {
        hotspot.setAttribute(attr, value);
      }
    });
    hotspot.setAttribute("class", `wave-beat-hotspot wave-beat-${cell.group}${isWaveCellSelected(cell) ? " wave-link-hover" : ""}`);
    hotspot.setAttribute("data-wave-link-key", cell.linkKey);
    hotspot.setAttribute("data-wave-panel-id", panel && panel.panelId ? panel.panelId : "");
    if (Number.isFinite(Number(cycleStart))) {
      hotspot.setAttribute("data-wave-cycle", String(Number(cycleStart) + (Number(cell.slotStart) || 0)));
    }
    hotspot.setAttribute("data-wave-row-id", cell.targetRowId);
    hotspot.setAttribute("data-wave-target-row-id", cell.targetRowId);
    hotspot.setAttribute("data-wave-trace-row-id", cell.traceRowId || cell.targetRowId);
    hotspot.setAttribute("data-wave-word-id", cell.wordId);
    hotspot.setAttribute("data-wave-tooltip", cell.fullLabel);
    return hotspot;
  }

  function renderWaveAnnotations(host, annotations, chunkMeta, panel, visibleSlots, cycleStart) {
    if (!annotations.length) {
      host.innerHTML = '<div class="wave-annotation-empty">No row-linked annotations in this window.</div>';
      return;
    }
    const groups = new Map();
    annotations.forEach((annotation) => {
      if (!groups.has(annotation.band)) {
        groups.set(annotation.band, []);
      }
      groups.get(annotation.band).push(annotation);
    });
    const maxSlot = Math.max(1, ...annotations.map((annotation) => (annotation.slotEnd || 0) + 1));
    host.innerHTML = Array.from(groups.entries()).map(([band, items]) => {
      const rows = packWaveAnnotationRows(items);
      const tracks = rows.map((row) => {
        const buttons = row.map((annotation) => {
          const left = ((annotation.slotStart || 0) / maxSlot) * 100;
          const span = Math.max(1, (annotation.slotEnd || 0) - (annotation.slotStart || 0) + 1);
          const width = Math.max(1.5, (span / maxSlot) * 100);
          const absoluteCycle = Number.isFinite(Number(cycleStart)) ? Number(cycleStart) + (Number(annotation.slotStart) || 0) : "";
          return `
            <button
              class="wave-annotation-tag"
              type="button"
              data-wave-panel-id="${escapeHtml(panel.panelId || "")}"
              data-wave-cycle="${escapeHtml(String(absoluteCycle))}"
              data-wave-row-id="${escapeHtml(annotation.rowId || "")}"
              data-wave-tooltip="${escapeHtml(annotation.tooltip || annotation.label || "")}"
              style="left:${left}%; width:${width}%;"
            >${escapeHtml(compactWaveAnnotationLabel(annotation.label || "", span, visibleSlots))}</button>
          `;
        }).join("");
        return `<div class="wave-annotation-track">${buttons}</div>`;
      }).join("");
      return `
        <div class="wave-annotation-band">
          <div class="wave-annotation-label">${escapeHtml(band)}</div>
          <div class="wave-annotation-rows">${tracks}</div>
        </div>
      `;
    }).join("");
  }

  function packWaveAnnotationRows(items) {
    const rows = [];
    items
      .slice()
      .sort((left, right) => (left.slotStart || 0) - (right.slotStart || 0) || (left.slotEnd || 0) - (right.slotEnd || 0))
      .forEach((annotation) => {
        for (const row of rows) {
          const last = row[row.length - 1];
          if ((annotation.slotStart || 0) > (last.slotEnd || 0)) {
            row.push(annotation);
            return;
          }
        }
        rows.push([annotation]);
      });
    return rows;
  }

  function compactWaveAnnotationLabel(label, slotSpan, visibleSlots) {
    const text = String(label || "");
    const level = waveAbbreviationLevel(visibleSlots || 16);
    if (level >= 4 && slotSpan <= 2) {
      return "";
    }
    if (level >= 3 && slotSpan <= 1) {
      return "";
    }
    if (/^OPQ F\d+$/i.test(text)) {
      return level >= 2 ? text.replace("OPQ ", "") : text;
    }
    if (/^Frame F\d+$/i.test(text)) {
      return text.replace("Frame ", "");
    }
    if (/^S\d+$/i.test(text)) {
      return text;
    }
    const budget = Math.max(3, Math.floor(slotSpan * (level >= 3 ? 1.2 : level === 2 ? 1.6 : 2.2)));
    if (text.length <= budget) {
      return text;
    }
    if (budget <= 3) {
      return text.slice(0, budget);
    }
    return text.slice(0, budget - 3) + "...";
  }
})();
