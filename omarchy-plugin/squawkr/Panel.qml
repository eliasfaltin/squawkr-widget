import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Squawkr.js" as Sq

// Squawkr native panel — bar popup following the first-party panel pattern
// (weather/activity-monitor): one Panel component, data over curl Processes,
// state in a JSON file, popup via KeyboardPanel (native outside-click,
// Esc, and popout coordination — no external window, no watcher).
Panel {
  id: root
  moduleName: "squawkr.panel"
  ipcTarget: "squawkr.panel"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  property string fontFamily: (root.bar && root.bar.fontFamily) || ""

  // ---- state ----
  property string token: ""
  property var prefs: null
  property var homeCard: null
  property var trackedCards: []
  property string lastFetchText: ""
  property bool refreshing: false
  property string view: "home" // "home" | "search" | "d:<key>"
  property int sel: -1
  property string toastText: ""
  property var searchResults: []
  property string searchQuery: ""
  property var zonePool: []
  property var ramp: Sq.FALLBACK_RAMP
  property string ipCity: ""
  property string relocCheckedCity: ""
  property bool relocNoted: false
  property string stateDir: Quickshell.env("HOME") + "/.local/share/squawkr-widget"
  property string statePath: stateDir + "/state.json"

  function ageLine() {
    if (!root.lastFetchText) return "loading…";
    return "updated " + root.lastFetchText;
  }

  // ---- lifecycle (weather pattern) ----
  function open() {
    stateFile.reload();
    root.controller.show();
    Qt.callLater(root.refresh);
  }
  function openFromHotkey() { root.open(); }
  function close() {
    root.view = "home";
    root.controller.hide();
  }
  function toggle() {
    if (root.opened) root.close();
    else root.open();
  }
  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction);
    return false;
  }

  // ---- prefs mutations ----
  function saveState() {
    var payload = { token: root.token, prefs: root.prefs };
    var json = JSON.stringify(payload);
    var b64 = Qt.btoa(unescape(encodeURIComponent(json)));
    saveProc.command = ["sh", "-c", "mkdir -p " + root.stateDir + " && echo " + b64 + " | base64 -d > " + root.statePath];
    saveProc.running = true;
  }
  function toast(msg) {
    root.toastText = msg;
    toastTimer.restart();
  }
  function trackedKey(ref) { return ref.kind === "af" ? ref.icao : ref.id; }
  function setHome(icao) {
    if (!root.prefs || !icao || icao === root.prefs.home) return;
    var old = root.prefs.home, tr = [], seen = {}, i = 0, k = "";
    for (i = 0; i < root.prefs.tracked.length; i++) {
      var r = root.prefs.tracked[i];
      if (!(r.kind === "af" && r.icao === icao)) tr.push(r);
    }
    root.prefs.home = icao;
    if (old && old !== icao) tr.unshift({ kind: "af", icao: old });
    var out = [];
    for (i = 0; i < tr.length && out.length < Sq.MAX_TRACKED; i++) {
      k = tr[i].kind === "af" ? "af:" + tr[i].icao : "zn:" + tr[i].id;
      if (!seen[k]) { seen[k] = true; out.push(tr[i]); }
    }
    root.prefs.tracked = out;
    root.sel = -1;
    saveState();
    toast(icao + " is now home");
    Qt.callLater(root.refresh);
  }
  function removeTracked(key) {
    if (!root.prefs) return;
    var before = root.prefs.tracked.length, tr = [], i = 0;
    for (i = 0; i < root.prefs.tracked.length; i++)
      if (root.trackedKey(root.prefs.tracked[i]) !== key) tr.push(root.prefs.tracked[i]);
    if (tr.length !== before) {
      root.prefs.tracked = tr;
      root.sel = Math.min(root.sel, tr.length - 1);
      saveState();
      toast("Removed");
      Qt.callLater(root.refresh);
    }
  }
  function addTracked(ref) {
    if (!root.prefs) return;
    if (root.prefs.tracked.length >= Sq.MAX_TRACKED) { toast("Tracking " + Sq.MAX_TRACKED + " already — remove one first"); return; }
    var k = ref.kind === "af" ? "af:" + ref.icao : "zn:" + ref.id, i = 0;
    if (ref.kind === "af" && ref.icao === root.prefs.home) { toast("That's your home field"); return; }
    for (i = 0; i < root.prefs.tracked.length; i++)
      if (root.trackedKey(root.prefs.tracked[i]) === k) { toast("Already tracked"); return; }
    root.prefs.tracked.push(ref);
    root.prefs.tracked = root.prefs.tracked.slice();
    root.view = "home";
    saveState();
    toast("Added");
    Qt.callLater(root.refresh);
  }
  function openService() {
    Qt.openUrlExternally(Sq.SERVICE_URL);
    root.close();
  }
  function openReport(card) {
    var url = Sq.SERVICE_URL + "/app/", q = "";
    if (!card) return;
    if (card.kind === "af") url += "?icao=" + encodeURIComponent(card.icao);
    else {
      q = "?area=" + encodeURIComponent(card.id || card.desig || "");
      if (isFinite(card.lat) && isFinite(card.lon))
        q += "&lat=" + card.lat.toFixed(4) + "&lon=" + card.lon.toFixed(4);
      url += q;
    }
    Qt.openUrlExternally(url);
    root.close();
  }

  // ---- generic API pipeline ----
  // One curl Process, tags route responses. Sequential chains via fetchQueue.
  property var fetchQueue: []
  property var fetchTag: ""
  property var fetchExtra: null

  function apiGet(tag, path, extra) {
    root.fetchQueue.push({ tag: tag, path: path, extra: extra || null });
    if (!apiProc.running && root.fetchTag === "") Qt.callLater(root.fetchNext);
  }
  function fetchNext() {
    // A stale scheduled call must never disturb an in-flight request: only start one
    // when idle. Completion (handleApi) continues the chain itself.
    if (apiProc.running || root.fetchTag !== "") return;
    if (!root.fetchQueue.length) return;
    var job = root.fetchQueue.shift();
    root.fetchTag = job.tag;
    root.fetchExtra = job.extra;
    apiProc.command = ["curl", "-fsS", "--max-time", "10",
      "-H", "authorization: Bearer " + root.token,
      Sq.API_BASE + job.path];
    apiProc.running = true;
  }
  function authHeaders() { return ["-H", "authorization: Bearer " + root.token]; }

  // ---- refresh ----
  function refresh() {
    if (!root.token) { ensureToken(); return; }
    if (!root.prefs) return; // seeding in flight; refresh follows the save
    root.refreshing = true;
    root.fetchQueue = [];
    apiGet("home", "/plugin/airfields/" + encodeURIComponent(root.prefs.home));
    for (var i = 0; i < root.prefs.tracked.length; i++) {
      var ref = root.prefs.tracked[i];
      if (ref.kind === "af") apiGet("track-af", "/plugin/airfields/" + encodeURIComponent(ref.icao), { index: i });
      else apiGet("track-zn", "/plugin/areas?" + "bbox=" + encodeURIComponent(ref.bbox || Sq.SEED_BBOX), { index: i, ref: ref });
    }
  }

  function applyRefreshDone() {
    root.refreshing = false;
    var d = new Date();
    root.lastFetchText = Qt.formatTime(d, "hh:mm");
    checkRelocation();
  }

  // ---- relocation hint (live IP, never a stale pin) ----
  function checkRelocation() {
    if (root.relocNoted || !root.prefs || !root.homeCard) return;
    if (!root.ipCity || root.ipCity === root.relocCheckedCity) return;
    root.relocCheckedCity = root.ipCity;
    apiGet("reloc-search", "/plugin/search?" + "q=" + encodeURIComponent(root.ipCity));
  }

  // ---- first-run seeding ----
  property var seedCands: []
  property bool seedActive: false
  function seedIfNeeded() {
    if (root.prefs || root.seedActive) { if (root.prefs) Qt.callLater(root.refresh); return; }
    root.seedActive = true;
    root.seedCands = [];
    var w = Sq.parseWeatherJson(weatherFile.text());
    if (w && isFinite(+w.latitude) && isFinite(+w.longitude))
      root.seedCands.push({ lat: +w.latitude, lon: +w.longitude });
    // live IP city resolves via search once ipProc answers (see handler)
    if (root.ipCity) seedFromCity(root.ipCity);
    else ipProc.running = true;
  }
  function seedFromCity(city) {
    apiGet("seed-search", "/plugin/search?" + "q=" + encodeURIComponent(city));
  }
  function seedFromCoords(lat, lon) {
    apiGet("seed-fields", "/plugin/airfields?bbox=" + encodeURIComponent(Sq.bboxAround(lat, lon, 3, 2)), { lat: lat, lon: lon });
  }
  function finishSeed(home, hlat, hlon) {
    root.prefs = { home: home, tracked: [] };
    apiGet("seed-track", "/plugin/airfields?bbox=" + encodeURIComponent(Sq.bboxAround(hlat, hlon, 3, 2)), { home: home, hlat: hlat, hlon: hlon });
  }
  function abortSeed() {
    // Seeding failed everywhere: fall back to the configured default home.
    root.prefs = { home: Sq.SEED_HOME, tracked: [] };
    root.seedActive = false;
    saveState();
    Qt.callLater(root.refresh);
  }

  // ---- file: state ----
  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var s = Sq.parseState(text());
      if (s) {
        if (s.token) root.token = s.token;
        // Never clobber in-memory prefs with an older save; adopt real ones.
        if (s.prefs && s.prefs.home && !root.prefs) { root.prefs = s.prefs; root.seedActive = false; }
      }
      if (!root.token) ensureTokenInner();
      else if (!root.prefs) root.seedIfNeeded();
      else Qt.callLater(root.refresh);
    }
    onLoadFailed: {
      // No state yet: token first, then seed.
      ensureTokenInner();
    }
  }
  function ensureToken() { if (!root.token) ensureTokenInner(); else if (!root.prefs) root.seedIfNeeded(); }
  function ensureTokenInner() {
    if (tokenProc.running) return;
    tokenProc.command = ["curl", "-fsS", "--max-time", "10", "-X", "POST",
      "-H", "Content-Type: application/json", "-d", '{"label":"omarchy panel"}',
      Sq.API_BASE + "/plugin/token"];
    tokenProc.running = true;
  }

  // ---- file: theme colours ----
  FileView {
    id: themeFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
    watchChanges: true
    printErrors: false
    onLoaded: root.ramp = Sq.rampColors(Sq.parseColorsToml(text()));
    onLoadFailed: root.ramp = Sq.FALLBACK_RAMP;
  }

  // ---- file: Omarchy weather location (override pin) ----
  FileView {
    id: weatherFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/weather.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      // Pin changes don't reseed a saved home; they apply to fresh seeds.
      if (!root.prefs && root.token) root.seedIfNeeded();
    }
  }

  // ---- processes ----
  Process {
    id: tokenProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var tok = "";
        try { tok = JSON.parse(String(text || "")).token || ""; } catch (e) {}
        if (tok) {
          root.token = tok;
          root.prefs = root.prefs || null;
          saveState();
          root.seedIfNeeded();
        }
      }
    }
  }
  Process {
    id: saveProc
  }
  Process {
    id: apiProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.handleApi(String(text || ""));
    }
  }
  Process {
    id: ipProc
    command: ["curl", "-fsS", "--max-time", "5", "https://wttr.in/?format=%l"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim();
        root.ipCity = raw ? raw.split(",")[0].trim() : "";
        if (!root.prefs && root.token && root.seedActive) {
          if (root.ipCity) root.seedFromCity(root.ipCity);
          else if (root.seedCands.length) {
            var c = root.seedCands.shift();
            root.seedFromCoords(c.lat, c.lon);
          } else root.abortSeed();
        }
      }
    }
  }
  Process {
    id: searchProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.handleSearch(String(text || ""));
    }
  }

  property string searchTag: ""
  function runSearch(q) {
    if (!q || !root.token) { root.searchResults = []; return; }
    root.searchTag = q;
    searchProc.command = ["curl", "-fsS", "--max-time", "8",
      "-H", "authorization: Bearer " + root.token,
      Sq.API_BASE + "/plugin/search?" + "q=" + encodeURIComponent(q)];
    searchProc.running = true;
  }
  function handleSearch(raw) {
    var tag = root.searchTag, j = null, afs = [], q = "", nq = "", zns = [], i = 0;
    if (!tag) return;
    try { j = JSON.parse(raw); } catch (e) { j = null; }
    afs = ((j && j.results) || []).slice(0, 8);
    var norm = function (s) { return String(s == null ? "" : s).toLowerCase().replace(/\s+/g, ""); };
    q = tag; nq = norm(q);
    zns = [];
    for (i = 0; i < root.zonePool.length && zns.length < 8; i++) {
      var z = root.zonePool[i];
      if (norm(z.desig).indexOf(nq) >= 0 || norm(z.name).indexOf(nq) >= 0) zns.push(z);
    }
    var out = [];
    for (i = 0; i < afs.length; i++)
      out.push({ zone: false, code: afs[i].icao, name: afs[i].name, sub: afs[i].iata || "", ref: { kind: "af", icao: afs[i].icao, name: afs[i].name } });
    for (i = 0; i < zns.length; i++)
      out.push({ zone: true, code: zns[i].desig, name: zns[i].name, sub: (zns[i].lo || "GND") + "–" + (zns[i].hi || "UNL"),
        ref: { kind: "zn", id: zns[i].id, bbox: zns[i].bbox, desig: zns[i].desig, name: zns[i].name } });
    root.searchResults = out;
  }
  function prefetchZonePool() {
    var boxes = [Sq.SEED_BBOX], i = 0;
    if (root.homeCard && isFinite(root.homeCard.lat) && isFinite(root.homeCard.lon)) {
      var pad = 1.2;
      boxes.push([root.homeCard.lon - pad, root.homeCard.lat - pad, root.homeCard.lon + pad, root.homeCard.lat + pad].map(function (n) { return n.toFixed(3); }).join(","));
    }
    root.zonePool = [];
    for (i = 0; i < boxes.length; i++)
      apiGet("zonepool", "/plugin/areas?bbox=" + encodeURIComponent(boxes[i]));
  }

  function handleApi(raw) {
    var tag = root.fetchTag, extra = root.fetchExtra, j = null;
    if (!tag) return;
    root.fetchTag = "";
    root.fetchExtra = null;
    try { j = JSON.parse(raw); } catch (e) { j = null; }
    if (tag === "home") {
      if (j) root.homeCard = Sq.airfieldCard(root.prefs.home, j);
      else root.homeCard = { kind: "af", icao: root.prefs.home, name: root.prefs.home, has_metar: false, runways: [], clouds: [] };
    } else if (tag === "track-af") {
      var tc = j ? Sq.airfieldCard(root.prefs.tracked[extra.index].icao, j)
                 : { kind: "af", icao: root.prefs.tracked[extra.index].icao, name: root.prefs.tracked[extra.index].icao, has_metar: false, runways: [], clouds: [] };
      var arr = root.trackedCards.slice(); arr[extra.index] = tc; root.trackedCards = arr;
    } else if (tag === "track-zn") {
      var feats = (j && j.data && j.data.features) || [], zc = null, f = 0;
      for (f = 0; f < feats.length; f++) {
        var cand = Sq.zoneCard(feats[f], extra.ref.bbox);
        if (cand.id === extra.ref.id || cand.desig === extra.ref.desig) { zc = cand; break; }
      }
      if (!zc) zc = { kind: "zn", id: extra.ref.id, desig: extra.ref.desig, name: extra.ref.name || "", status: "unknown", week: "NNNNNNN" };
      var arr2 = root.trackedCards.slice(); arr2[extra.index] = zc; root.trackedCards = arr2;
    } else if (tag === "zonepool") {
      var fs = (j && j.data && j.data.features) || [], k = 0, seen = {}, pool = root.zonePool.slice();
      var seenAll = {};
      for (k = 0; k < pool.length; k++) seenAll[pool[k].desig] = true;
      for (k = 0; k < fs.length; k++) {
        var z2 = Sq.zoneCard(fs[k], Sq.SEED_BBOX);
        if (!seenAll[z2.desig]) { seenAll[z2.desig] = true; pool.push(z2); }
      }
      root.zonePool = pool;
      if (root.searchQuery) runSearch(root.searchQuery);
    } else if (tag === "seed-fields") {
      var list = (j && j.data) || [];
      var near = Sq.nearest(list, extra.lat, extra.lon);
      if (near.length && near[0].icao) finishSeed(near[0].icao, near[0].lat, near[0].lon);
      else if (root.seedCands.length) {
        var c = root.seedCands.shift();
        seedFromCoords(c.lat, c.lon);
      } else abortSeed();
    } else if (tag === "seed-track") {
      var l2 = Sq.nearest(((j && j.data) || []).filter(function (x) { return x.icao !== extra.home; }), extra.hlat, extra.hlon);
      root.prefs = { home: extra.home, tracked: [] };
      if (l2.length) root.prefs.tracked.push({ kind: "af", icao: l2[0].icao, name: l2[0].name });
      root.prefs.tracked = root.prefs.tracked.slice();
      apiGet("seed-zones", "/plugin/areas?bbox=" + encodeURIComponent(Sq.bboxAround(extra.hlat, extra.hlon, 1.0, 0.6)));
    } else if (tag === "seed-zones") {
      var fz = (j && j.data && j.data.features) || [];
      if (fz.length) {
        var zz = Sq.zoneCard(fz[0], Sq.SEED_BBOX);
        root.prefs.tracked.push({ kind: "zn", id: zz.id, bbox: zz.bbox, desig: zz.desig, name: zz.name });
      root.prefs.tracked = root.prefs.tracked.slice();
      }
      root.seedActive = false;
      saveState();
      Qt.callLater(root.refresh);
    } else if (tag === "seed-search") {
      var hits = ((j && j.results) || []).filter(function (h) { return h.icao; });
      if (hits.length) {
        // Resolve the hit's coordinates through its full card, then seed around it —
        // a city name alone carries no position.
        apiGet("seed-hit-card", "/plugin/airfields/" + encodeURIComponent(hits[0].icao));
      } else if (root.seedCands.length) {
        var c2 = root.seedCands.shift();
        seedFromCoords(c2.lat, c2.lon);
      } else abortSeed();
    } else if (tag === "seed-hit-card") {
      if (j) {
        var hc = Sq.airfieldCard("", j);
        if (hc.icao && isFinite(hc.lat) && isFinite(hc.lon)) finishSeed(hc.icao, hc.lat, hc.lon);
        else abortSeed();
      } else abortSeed();
    } else if (tag === "reloc-search") {
      var hits2 = ((j && j.results) || []).filter(function (h) { return h.icao; });
      if (hits2.length) apiGet("reloc-card", "/plugin/airfields/" + encodeURIComponent(hits2[0].icao));
    } else if (tag === "reloc-card") {
      if (j) {
        var rc = Sq.airfieldCard("", j);
        var hl = root.homeCard;
        if (isFinite(rc.lat) && isFinite(rc.lon) && isFinite(hl.lat) && isFinite(hl.lon)) {
          var km = Sq.kmBetween(rc.lat, rc.lon, hl.lat, hl.lon);
          if (km > Sq.RELOCATE_KM) {
            root.relocNoted = true;
            toast("You seem near " + root.ipCity + " — add a local field, set it home with h");
          }
        }
      }
    }
    if (root.fetchQueue.length) fetchNext();
    else if (tag === "home" || tag === "track-af" || tag === "track-zn") {
      // refresh chain drained (zonepool tags may still follow for search only)
      var pendingRefresh = false, q = 0;
      for (q = 0; q < root.fetchQueue.length; q++)
        if (root.fetchQueue[q].tag === "home" || root.fetchQueue[q].tag === "track-af" || root.fetchQueue[q].tag === "track-zn") pendingRefresh = true;
      if (!pendingRefresh) applyRefreshDone();
    }
  }

  Timer {
    id: toastTimer
    interval: 2600
    onTriggered: root.toastText = ""
  }
  Timer {
    id: refreshTimer
    interval: Sq.REFRESH_MS
    running: true
    repeat: true
    onTriggered: if (root.token && root.prefs) root.refresh()
  }
  Timer {
    id: searchDebounce
    interval: 220
    onTriggered: root.runSearch(root.searchQuery)
  }

  // ---- popup ----
  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(560))
    contentHeight: panel.fittedContentHeight(contentBox.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: {
        if (root.view !== "home") root.view = "home";
        else root.close();
      }
      onTabRequested: function (direction) { root.switchPanel(direction); }
      onMoveRequested: function (dx, dy) {
        if (root.view !== "home" || !root.prefs) return;
        var n = root.prefs.tracked.length;
        if (dx !== 0 && n) root.sel = ((root.sel + dx + n) % n + n) % n;
      }
      onActivateRequested: {
        if (root.view === "home" && root.sel >= 0 && root.prefs && root.prefs.tracked[root.sel])
          root.view = "d:" + root.trackedKey(root.prefs.tracked[root.sel]);
      }
      onDeleteRequested: {
        if (root.view === "home" && root.sel >= 0 && root.prefs && root.prefs.tracked[root.sel])
          root.removeTracked(root.trackedKey(root.prefs.tracked[root.sel]));
      }
      onTextKey: function (text) {
        if (root.view === "search") return;
        if (root.view !== "home") return;
        if (text === "a") { root.view = "search"; root.searchQuery = ""; root.searchResults = []; root.prefetchZonePool(); }
        else if (text === "h" && root.sel >= 0 && root.prefs && root.prefs.tracked[root.sel]) {
          var r = root.prefs.tracked[root.sel];
          if (r.kind === "af") root.setHome(r.icao);
          else root.toast("Only an airfield can be home");
        } else if (text === "x" && root.sel >= 0 && root.prefs && root.prefs.tracked[root.sel]) {
          root.removeTracked(root.trackedKey(root.prefs.tracked[root.sel]));
        }
      }

      Item {
        id: contentBox
        anchors.fill: parent
        implicitHeight: homeView.visible ? homeView.implicitHeight : (searchView.visible ? searchView.implicitHeight : detailView.implicitHeight)

        HomeView {
          id: homeView
          anchors.fill: parent
          visible: root.view === "home"
          homeCard: root.homeCard
          tracked: {
            var out = [], i = 0;
            if (root.prefs) for (i = 0; i < root.prefs.tracked.length; i++)
              out.push({ ref: root.prefs.tracked[i], card: root.trackedCards[i] || root.prefs.tracked[i] });
            return out;
          }
          trackedRefs: root.prefs ? root.prefs.tracked : []
          ramp: root.ramp
          fontFamily: root.fontFamily
          ageLine: root.ageLine()
          toastText: root.toastText
          sel: root.sel
          onOpenDetail: function (id) { root.view = "d:" + id; }
          onAddRequested: { root.view = "search"; root.searchQuery = ""; root.searchResults = []; root.prefetchZonePool(); }
          onSetHome: function (icao) { root.setHome(icao); }
          onRemoveItem: function (key) { root.removeTracked(key); }
          onOpenService: root.openService()
        }
        DetailView {
          id: detailView
          anchors.fill: parent
          visible: root.view !== "home" && root.view !== "search"
          card: {
            if (root.view === "home" || root.view === "search" || !root.prefs) return null;
            var key = root.view.slice(2);
            if (root.homeCard && root.homeCard.icao === key) return root.homeCard;
            for (var i = 0; i < root.prefs.tracked.length; i++)
              if (root.trackedKey(root.prefs.tracked[i]) === key)
                return root.trackedCards[i] || root.prefs.tracked[i];
            return null;
          }
          ramp: root.ramp
          fontFamily: root.fontFamily
          onBack: root.view = "home"
          onSetHome: function (icao) { root.setHome(icao); }
          onRemoveItem: function (key) { root.removeTracked(key); root.view = "home"; }
          onOpenReport: {
            var c = detailView.card;
            if (c) root.openReport(c);
          }
        }
        SearchView {
          id: searchView
          anchors.fill: parent
          visible: root.view === "search"
          results: root.searchResults
          fontFamily: root.fontFamily
          onQueryChanged: function (q) { root.searchQuery = q; searchDebounce.restart(); }
          onPicked: function (index) {
            var row = root.searchResults[index];
            if (row && row.ref) root.addTracked(row.ref);
          }
          onCancelled: root.view = "home"
        }
      }
    }
  }
}
