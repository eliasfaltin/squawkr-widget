import QtQuick

// Restriction-zone vertical-extent meter, mirroring the web widget's heightMeter.
// lo/hi are display labels ("GND", "FL095", "UNL"); color is the zone status colour.
Canvas {
  id: root
  property string lo: "GND"
  property string hi: "UNL"
  property bool unl: true
  property real loFt: 0
  property real hiFt: 10000
  property color ink: "#7c8caa"
  property color faint: "#6b7089"
  property color track: "#0d0e16"
  property color edge: "#2b3050"
  width: 110
  height: 200
  onLoChanged: requestPaint()
  onHiChanged: requestPaint()
  onUnlChanged: requestPaint()
  onLoFtChanged: requestPaint()
  onHiFtChanged: requestPaint()
  onInkChanged: requestPaint()
  onFaintChanged: requestPaint()
  onTrackChanged: requestPaint()
  onEdgeChanged: requestPaint()
  onPaint: {
    var ctx = getContext("2d");
    var s = width / 120;
    var H = 220, TOP = 14, BOT = 198, BX = 8, BW = 22, LX = 38;
    var smax = Math.max(unl ? Math.max(loFt + 20000, 45000) : hiFt * 1.08, 1000);
    var y = function (ft) { return BOT - (ft / smax) * (BOT - TOP); };
    var yU = unl ? TOP : y(hiFt), yL = y(loFt);
    ctx.reset();
    ctx.lineWidth = 1.5 * s;
    ctx.fillStyle = track;
    ctx.strokeStyle = edge;
    ctx.beginPath(); ctx.rect(BX * s, TOP * s, BW * s, (BOT - TOP) * s); ctx.fill(); ctx.stroke();
    ctx.globalAlpha = 0.32;
    ctx.fillStyle = ink;
    ctx.fillRect(BX * s, yU * s, BW * s, Math.max(0, yL - yU) * s);
    ctx.globalAlpha = 1.0;
    ctx.strokeStyle = ink;
    ctx.strokeRect(BX * s, yU * s, BW * s, Math.max(0.5, yL - yU) * s);
    if (unl) {
      ctx.beginPath();
      ctx.moveTo((BX + 3) * s, (TOP + 6) * s);
      ctx.lineTo((BX + BW / 2) * s, TOP * s);
      ctx.lineTo((BX + BW - 3) * s, (TOP + 6) * s);
      ctx.stroke();
    }
    ctx.strokeStyle = faint;
    ctx.lineWidth = 1 * s;
    ctx.beginPath(); ctx.moveTo((BX - 4) * s, BOT * s); ctx.lineTo((BX + BW + 4) * s, BOT * s); ctx.stroke();
    ctx.strokeStyle = ink;
    ctx.beginPath(); ctx.moveTo((BX + BW) * s, yU * s); ctx.lineTo((LX - 3) * s, yU * s); ctx.stroke();
    ctx.strokeStyle = faint;
    ctx.beginPath(); ctx.moveTo((BX + BW) * s, yL * s); ctx.lineTo((LX - 3) * s, yL * s); ctx.stroke();
    ctx.fillStyle = ink;
    ctx.font = "600 " + (12 * s) + "px monospace";
    ctx.textAlign = "left";
    ctx.fillText(hi, LX * s, (yU + 4) * s);
    ctx.fillStyle = faint;
    ctx.font = (11 * s) + "px monospace";
    ctx.fillText(lo, LX * s, (yL + 4) * s);
  }
}
