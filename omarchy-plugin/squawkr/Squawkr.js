// Squawkr native panel — shared logic. Pure functions only (no Quickshell imports);
// Panel.qml owns all side effects (curl Processes, FileViews). A faithful port of the
// web widget's app.js / api.js / render.js behaviour.
//
// NOTE: `var` is declared at function root throughout — qmllint rejects block-scoped `var`.

// ---- config ----------------------------------------------------------------------------------
var API_BASE = "https://plugin-api.squawkr.net";
var SERVICE_URL = "https://squawkr.net";
var SEED_BBOX = "18.0,57.0,19.6,58.0";
var SEED_FIELD_BBOX = "17.5,57.0,19.6,58.2";
var SEED_HOME = "ESSV";
var REFRESH_MS = 90000;
var STALE_CUTOFF_MIN = 90;
var MAX_TRACKED = 3;
var RELOCATE_KM = 150;

// ---- theme signal ramp -----------------------------------------------------------------------
// The shell's Color singleton exposes no green/yellow signal roles, so read them straight from
// the active theme's colors.toml (same source the web panel used). Keys are simple
// `name = "#hex"` lines — a regex is enough, no TOML parser. Falls back to the classic ramp.
function parseColorsToml(text) {
  var out = {}, lines = [], i = 0, m = null;
  try {
    lines = String(text || "").split("\n");
    for (i = 0; i < lines.length; i++) {
      m = /^\s*([a-z_][a-z0-9_]*)\s*=\s*"#?([0-9a-fA-F]{6})"/.exec(lines[i]);
      if (m) out[m[1]] = "#" + m[2];
    }
  } catch (e) {}
  return out;
}

var FALLBACK_RAMP = {
  active: "#e06c6c", sched: "#e0b34a", none: "#6fce9a",
  unknown: "#92949c", geo: "#7c8caa", lifr: "#9650be"
};

function rampColors(pal) {
  return {
    active: pal.red || pal.bright_red || FALLBACK_RAMP.active,
    sched: pal.yellow || pal.bright_yellow || FALLBACK_RAMP.sched,
    none: pal.green || pal.bright_green || FALLBACK_RAMP.none,
    unknown: FALLBACK_RAMP.unknown,
    geo: pal.cyan || pal.blue || FALLBACK_RAMP.geo,
    lifr: pal.magenta || pal.bright_magenta || FALLBACK_RAMP.lifr
  };
}

// Flight category → theme ramp key. VFR/CAVOK read as "clear" (green).
function catKey(cat) {
  if (cat === "CAVOK" || cat === "VFR") return "none";
  if (cat === "MVFR") return "sched";
  if (cat === "IFR") return "active";
  if (cat === "LIFR") return "lifr";
  return "unknown";
}

// ---- prefs -----------------------------------------------------------------------------------
// { home: "ESSV", tracked: [ {kind:"af",icao,name?} | {kind:"zn",id,bbox,desig,name?} ] }
function blankPrefs() { return { home: SEED_HOME, tracked: [] }; }

function parseState(text) {
  var s = null;
  try {
    s = JSON.parse(String(text || ""));
    if (s && (s.token || (s.prefs && s.prefs.home))) return s;
  } catch (e) {}
  return null;
}

// ---- airfields -------------------------------------------------------------------------------
function cleanName(name) {
  var n = String(name || "").split(",")[0].trim();
  var sufs = [" Arpt", " Airport", " Air Base", " AB", " Flygplats"];
  var i = 0;
  for (i = 0; i < sufs.length; i++) {
    if (n.slice(-sufs[i].length) === sufs[i]) { n = n.slice(0, -sufs[i].length).trim(); break; }
  }
  return n || "?";
}

function hdg(end) {
  var d = String(end).match(/\d+/);
  return d ? parseInt(d[0], 10) * 10 : 0;
}

function recommend(rwy, wdir) {
  var ends = [], list = [], best = "—", bh = 0, bs = -9, i = 0, h = 0, s = 0;
  ends = String(rwy).split("/").map(function (e) { return e.trim(); }).filter(function (e) { return e; });
  list = ends.length ? ends : ["—"];
  best = list[0]; bh = hdg(list[0]);
  for (i = 0; i < list.length; i++) {
    h = hdg(list[i]);
    s = Math.cos(((wdir - h + 180) % 360 - 180) * Math.PI / 180);
    if (s > bs) { bs = s; best = list[i]; bh = h; }
  }
  return { end: best, bh: bh };
}

function comps(rwy, wdir, wspd) {
  var bh = recommend(rwy, wdir).bh;
  var off = ((wdir - bh + 180) % 360 - 180) * Math.PI / 180;
  return {
    hw: Math.round(Math.abs(wspd * Math.cos(off))),
    xw: Math.round(Math.abs(wspd * Math.sin(off)))
  };
}

var REL = ["↑", "↗", "→", "↘", "↓", "↙", "←", "↖"];
function relArrow(rwy, wdir) {
  var bh = 0;
  if (!isFinite(+wdir)) return "—";
  bh = recommend(rwy, wdir).bh;
  return REL[Math.round((((+wdir + 180 - bh) % 360) / 45)) % 8];
}

function ageText(mins) {
  if (mins == null) return "—";
  if (mins < 1) return "just now";
  if (mins < 60) return Math.floor(mins) + "m";
  return Math.floor(mins / 60) + "h" + String(Math.floor(mins % 60)).padStart(2, "0");
}

function obsTime(iso) {
  var dt = null;
  if (!iso) return null;
  try {
    dt = new Date(iso);
    return dt.toISOString().slice(11, 16) + "Z";
  } catch (e) { return null; }
}

// Full airfield card from /plugin/airfields/:icao JSON. dataAge.metar is SECONDS → minutes.
function airfieldCard(icao, w) {
  var d = (w && w.data) || {};
  var metar = d.metar || {};
  var wdir = metar.windDir;
  var wspd = metar.windSpeedKt || 0;
  var gust = metar.windGustKt || 0;
  var cat = metar.flightCategory || "—";
  var ageSec = (w.dataAge || {}).metar;
  var ageMin = ageSec != null ? ageSec / 60 : null;
  var runways = d.runways || [];
  var rwy = "", prim = null, i = 0, ids = "";
  if (metar.raw && metar.raw.indexOf("CAVOK") >= 0) cat = "CAVOK";
  if (runways.length) {
    prim = runways[0];
    for (i = 1; i < runways.length; i++)
      if ((runways[i].lengthM || 0) > (prim.lengthM || 0)) prim = runways[i];
    rwy = prim.id || "";
  }
  if (wdir != null && runways.length) {
    ids = runways.map(function (r) { return r.id; }).join("/");
    rwy = recommend(ids, wdir).end;
  } else if (wdir != null && rwy) {
    rwy = recommend(rwy, wdir).end;
  }
  return {
    kind: "af", icao: d.icao || String(icao).toUpperCase(), name: cleanName(d.name),
    rwy: rwy, wdir: wdir != null ? wdir : 0, hasWind: wdir != null, wspd: wspd, gust: gust,
    cat: cat, age: ageText(ageMin), ageMin: ageMin,
    temp: metar.tempC, dew: metar.dewpointC, vis: metar.visibility,
    qnh: metar.altimeterHpa, obs: obsTime(metar.observedAt),
    clouds: metar.clouds || [], runways: runways,
    has_metar: !!metar.raw, has_taf: !!((d.taf || {}).raw),
    lat: d.lat, lon: d.lon, stale: !!(w && w.stale)
  };
}

function cloudsText(a) {
  var cs = a.clouds || [];
  if (!cs.length) return "no cloud reported";
  return cs.map(function (c) { return c.cover + " " + c.base + "′"; }).join(" · ");
}

function skyInterp(a) {
  var head = { CAVOK: "Clear & unlimited", VFR: "Good VFR", MVFR: "Marginal VFR", IFR: "IFR conditions", LIFR: "Low IFR" }[a.cat] || (a.cat || "—");
  var cs = a.clouds || [];
  var ceils = [], words = {}, sky = "", i = 0, c0 = null, ceil = 0;
  ceils = cs.filter(function (c) { return (c.cover === "BKN" || c.cover === "OVC" || c.cover === "OVX") && c.base != null; }).map(function (c) { return c.base; });
  words = { FEW: "few cloud", SCT: "scattered cloud", BKN: "broken cloud", OVC: "overcast", OVX: "sky obscured" };
  if (ceils.length) {
    ceil = Math.min.apply(null, ceils);
    sky = (ceil < 1000 ? "low " : "") + "ceiling " + ceil + " ft";
  } else if (cs.length) {
    c0 = cs[0];
    for (i = 1; i < cs.length; i++)
      if ((cs[i].base == null ? 99999 : cs[i].base) < (c0.base == null ? 99999 : c0.base)) c0 = cs[i];
    sky = (words[c0.cover] || "cloud") + (c0.base ? " at " + c0.base + " ft" : "");
  } else sky = "no cloud reported";
  return [head, sky + (a.vis ? " · " + a.vis + " SM" : "")];
}

// ---- zones -----------------------------------------------------------------------------------
var ACTIVATION_COVERAGE = [
  [10.5, 55.0, 24.5, 69.2],
  [-119.5, 34.0, -116.8, 36.4], [-117.6, 36.3, -114.9, 38.6],
  [-114.6, 31.9, -112.0, 34.1], [-107.3, 31.9, -105.0, 34.2],
  [-87.7, 29.4, -85.2, 31.2], [-76.8, 36.3, -74.5, 38.2],
  [-119.6, 32.0, -116.8, 34.2]
];

function inCoverage(lat, lon) {
  var i = 0, b = null;
  if (!isFinite(lat) || !isFinite(lon)) return false;
  for (i = 0; i < ACTIVATION_COVERAGE.length; i++) {
    b = ACTIVATION_COVERAGE[i];
    if (lon >= b[0] && lon <= b[2] && lat >= b[1] && lat <= b[3]) return true;
  }
  return false;
}

function centroidWalk(c, pts) {
  var i = 0;
  if (c && typeof c[0] === "number") pts.push(c);
  else if (Array.isArray(c)) for (i = 0; i < c.length; i++) centroidWalk(c[i], pts);
}

function centroid(g) {
  var pts = [], sx = 0, sy = 0, i = 0;
  try { centroidWalk(g && g.coordinates, pts); } catch (e) {}
  if (!pts.length) return {};
  for (i = 0; i < pts.length; i++) { sx += pts[i][0]; sy += pts[i][1]; }
  return { lon: sx / pts.length, lat: sy / pts.length };
}

function zoneStatus(p) {
  var s = String(p.status || "").toLowerCase();
  if (s === "active") return "active";
  if (s === "scheduled") return "sched";
  if (s === "inactive" || s === "none" || s === "") return "none";
  return "unknown";
}

function altLbl(v) {
  var n = 0;
  if (v == null || v === "" || v === "GND" || v === "SFC") return "GND";
  n = parseInt(v, 10);
  if (isFinite(n)) return "FL" + String(Math.floor(n / 100)).padStart(3, "0");
  return String(v);
}

var MON = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
function fmtD(dt) { return dt.getUTCDate() + " " + MON[dt.getUTCMonth()]; }

function weekAndLabel(current, next) {
  var now = new Date();
  var dow = (now.getUTCDay() + 6) % 7;
  var monday = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - dow));
  var cells = [], i = 0;
  var d0 = null, d1 = null, cur = null, nxt = null, label = null;
  cur = current ? [current.start ? new Date(current.start) : null, current.end ? new Date(current.end) : null] : null;
  nxt = next ? [next.start ? new Date(next.start) : null, next.end ? new Date(next.end) : null] : null;
  for (i = 0; i < 7; i++) {
    d0 = new Date(monday.getTime() + i * 864e5); d1 = new Date(d0.getTime() + 864e5);
    if (cur && cur[0] && cur[1] && cur[0] < d1 && cur[1] > d0) cells.push("A");
    else if (nxt && nxt[0] && nxt[0] < d1 && (nxt[1] || nxt[0]) > d0) cells.push("W");
    else cells.push("N");
  }
  if (cur && cur[1]) label = "active until " + fmtD(cur[1]);
  else if (nxt && nxt[0]) label = "next " + fmtD(nxt[0]);
  return { week: cells.join(""), when: label };
}

function titleCase(s) {
  return String(s || "").replace(/\w\S*/g, function (t) { return t[0].toUpperCase() + t.slice(1).toLowerCase(); });
}

function zoneCard(feature, bbox) {
  var p = feature.properties || {};
  var c = centroid(feature.geometry);
  var covered = inCoverage(c.lat, c.lon);
  var st = covered ? zoneStatus(p) : "geo";
  var wl = covered ? weekAndLabel(p.current, p.next) : { week: null, when: null };
  var cur = covered ? (p.current || p.next || {}) : {};
  return {
    kind: "zn", desig: p.designator || p.id || "?",
    name: titleCase(p.name || ""), status: st, covered: covered,
    lo: altLbl(p.lower), hi: altLbl(p.upper),
    when: wl.when, week: wl.week, age: "live", id: p.id,
    bbox: bbox || SEED_BBOX, lat: c.lat, lon: c.lon,
    sched: covered ? (cur.schedule || null) : null
  };
}

function zoneStatusWord(st) {
  return { active: "ACTIVE", sched: "SCHEDULED", none: "CLEAR", unknown: "UNKNOWN", geo: "ZONE ONLY" }[st] || "—";
}

function zoneRampKey(st) {
  return { active: "active", sched: "sched", none: "none", unknown: "unknown", geo: "geo" }[st] || "unknown";
}

// ---- location seeding ------------------------------------------------------------------------
var TZ_COORDS = {
  "Europe/Stockholm": [59.33, 18.06], "Europe/Berlin": [52.52, 13.40],
  "Europe/London": [51.51, -0.13], "Europe/Paris": [48.86, 2.35],
  "Europe/Copenhagen": [55.68, 12.57], "Europe/Oslo": [59.91, 10.75],
  "Europe/Helsinki": [60.17, 24.94], "Europe/Vienna": [48.21, 16.37],
  "Europe/Zurich": [47.37, 8.54], "Europe/Amsterdam": [52.37, 4.90],
  "Europe/Madrid": [40.42, -3.70], "Europe/Rome": [41.90, 12.50],
  "Europe/Warsaw": [52.23, 21.01], "Europe/Dublin": [53.35, -6.26],
  "Europe/Athens": [37.98, 23.73], "Europe/Lisbon": [38.72, -9.14],
  "Atlantic/Reykjavik": [64.15, -21.94],
  "America/New_York": [40.71, -74.01], "America/Chicago": [41.88, -87.63],
  "America/Denver": [39.74, -104.99], "America/Los_Angeles": [34.05, -118.24],
  "America/Toronto": [43.65, -79.38], "America/Sao_Paulo": [-23.55, -46.63],
  "Asia/Tokyo": [35.68, 139.69], "Asia/Singapore": [1.35, 103.82],
  "Asia/Dubai": [25.20, 55.27], "Australia/Sydney": [-33.87, 151.21],
  "Pacific/Auckland": [-36.85, 174.76], "Africa/Cairo": [30.04, 31.24]
};

function bboxAround(lat, lon, dLon, dLat) {
  return [(lon - dLon).toFixed(2), (lat - dLat).toFixed(2), (lon + dLon).toFixed(2), (lat + dLat).toFixed(2)].join(",");
}

function nearest(list, lat, lon) {
  return (list || []).slice().sort(function (a, b) {
    return ((a.lat - lat) * (a.lat - lat) + (a.lon - lon) * (a.lon - lon))
         - ((b.lat - lat) * (b.lat - lat) + (b.lon - lon) * (b.lon - lon));
  });
}

function kmBetween(lat1, lon1, lat2, lon2) {
  return 111 * Math.hypot(lat1 - lat2, (lon1 - lon2) * Math.cos((lat1 * Math.PI) / 180));
}

// Parse the weather.json override ({name, latitude, longitude}) — same file
// omarchy-weather-location owns. Returns null when absent/unparseable.
function parseWeatherJson(text) {
  var d = null;
  try {
    d = JSON.parse(String(text || ""));
    if (d && typeof d.name === "string" && d.name) return d;
  } catch (e) {}
  return null;
}
