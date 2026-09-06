import QtQuick

// Flight-condition pictogram, drawn with strokes in the given colour.
// cat is a flight category (CAVOK/VFR/MVFR/IFR/LIFR); unknown renders as cloud.
Canvas {
  id: root
  property string cat: "VFR"
  property color ink: "#6fce9a"
  width: 56
  height: 56
  onCatChanged: requestPaint()
  onInkChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  onPaint: {
    var ctx = getContext("2d");
    var w = width, h = height, s = Math.min(w, h) / 64;
    ctx.reset();
    ctx.strokeStyle = ink;
    ctx.lineWidth = 2.4 * s;
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    var i = 0, a = 0;
    var line = function (x1, y1, x2, y2) {
      ctx.beginPath(); ctx.moveTo(x1 * s, y1 * s); ctx.lineTo(x2 * s, y2 * s); ctx.stroke();
    };
    if (cat === "CAVOK") {
      ctx.beginPath(); ctx.arc(32 * s, 32 * s, 9 * s, 0, Math.PI * 2); ctx.stroke();
      for (i = 0; i < 8; i++) {
        a = i * Math.PI / 4;
        line(32 + 13 * Math.cos(a), 32 + 13 * Math.sin(a), 32 + 21 * Math.cos(a), 32 + 21 * Math.sin(a));
      }
    } else if (cat === "VFR") {
      ctx.beginPath(); ctx.arc(24 * s, 23 * s, 8 * s, 0, Math.PI * 2); ctx.stroke();
      for (i = 4; i <= 8; i++) {
        a = i * Math.PI / 4;
        line(24 + 11 * Math.cos(a), 23 + 11 * Math.sin(a), 24 + 16 * Math.cos(a), 23 + 16 * Math.sin(a));
      }
      ctx.beginPath();
      ctx.moveTo(22 * s, 45 * s);
      ctx.bezierCurveTo(24 * s, 36 * s, 36 * s, 36 * s, 38 * s, 42 * s);
      ctx.bezierCurveTo(46 * s, 43 * s, 48 * s, 51 * s, 42 * s, 53 * s);
      ctx.lineTo(24 * s, 53 * s);
      ctx.stroke();
    } else {
      ctx.beginPath();
      ctx.moveTo(18 * s, 34 * s);
      ctx.bezierCurveTo(20 * s, 25 * s, 32 * s, 25 * s, 34 * s, 31 * s);
      ctx.bezierCurveTo(42 * s, 32 * s, 44 * s, 40 * s, 38 * s, 42 * s);
      ctx.lineTo(20 * s, 42 * s);
      ctx.stroke();
      if (cat === "IFR" || cat === "LIFR") {
        line(14, 48, 46, 48);
        line(20, 55, 50, 55);
      }
    }
  }
}
