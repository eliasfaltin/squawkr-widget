import QtQuick
import "Squawkr.js" as Sq

// Vertical runway strip with wind chevrons, mirroring the web widget's runwaySvg.
// Needs rwy ("01L/19R"), wdir (deg), plus theme colours for track/edge/chevron.
Canvas {
  id: root
  property string rwy: ""
  property real wdir: 0
  property bool hasWind: false
  property color track: "#0d0e16"
  property color edge: "#3a3f5c"
  property color chev: "#7ea0ff"
  property color num: "#c7cdf2"
  width: 96
  height: 190
  onRwyChanged: requestPaint()
  onWdirChanged: requestPaint()
  onHasWindChanged: requestPaint()
  onTrackChanged: requestPaint()
  onEdgeChanged: requestPaint()
  onChevChanged: requestPaint()
  onNumChanged: requestPaint()
  onPaint: {
    var ctx = getContext("2d");
    var s = width / 120;
    ctx.reset();
    ctx.lineWidth = 1.5 * s;
    ctx.fillStyle = track;
    ctx.strokeStyle = edge;
    ctx.beginPath();
    if (ctx.roundRect) ctx.roundRect(42 * s, 14 * s, 36 * s, 190 * s, 5 * s);
    else ctx.rect(42 * s, 14 * s, 36 * s, 190 * s);
    ctx.fill(); ctx.stroke();
    ctx.strokeStyle = edge;
    ctx.lineWidth = 2 * s;
    ctx.setLineDash([7 * s, 9 * s]);
    ctx.beginPath(); ctx.moveTo(60 * s, 22 * s); ctx.lineTo(60 * s, 196 * s); ctx.stroke();
    ctx.setLineDash([]);
    var label = "0";
    if (hasWind) {
      var rec = Sq.recommend(rwy, wdir);
      var m = String(rec.end).match(/\d+/);
      label = ((m ? m[0] : "0").slice(0, 2) || "0");
      if (label.length < 2) label = "0" + label;
      var rel = (wdir + 180 - rec.bh) % 360;
      var dx = Math.sin(rel * Math.PI / 180), dy = -Math.cos(rel * Math.PI / 180);
      var cx = 60, cy = 104, k = 0, mx = 0, my = 0;
      ctx.strokeStyle = chev;
      ctx.lineWidth = 2.6 * s;
      ctx.lineCap = "round";
      ctx.lineJoin = "round";
      for (k = -1; k <= 1; k++) {
        mx = cx + dx * k * 17; my = cy + dy * k * 17;
        var bx = mx - dx * 10, by = my - dy * 10;
        var px = -dy, py = dx;
        ctx.beginPath();
        ctx.moveTo((bx + px * 8) * s, (by + py * 8) * s);
        ctx.lineTo(mx * s, my * s);
        ctx.lineTo((bx - px * 8) * s, (by - py * 8) * s);
        ctx.stroke();
      }
    }
    ctx.fillStyle = num;
    ctx.font = "600 " + (15 * s) + "px monospace";
    ctx.textAlign = "center";
    ctx.fillText(label, 60 * s, 224 * s);
  }
}
