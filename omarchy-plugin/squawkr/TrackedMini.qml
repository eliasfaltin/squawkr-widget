import QtQuick
import qs.Commons
import qs.Ui
import "Squawkr.js" as Sq

Rectangle {
  id: root
  property var card: null
  property var ref: null
  property var ramp: Sq.FALLBACK_RAMP
  property string fontFamily: "monospace"
  property bool selected: false
  signal open()
  signal makeHome()
  signal remove()
  width: 150
  height: 118
  radius: Style.cornerRadius
  color: Color.menu.selectedBackground
  border.width: selected ? 2 : 1
  border.color: selected ? Color.accent : Color.menu.border

  function statusColor() {
    if (!card) return Color.muted;
    if (card.kind === "af") {
      if (!card.has_metar) return Color.muted;
      return ramp[Sq.catKey(card.cat)];
    }
    return ramp[Sq.zoneRampKey(card.status)];
  }
  function statusWord() {
    if (!card) return "—";
    if (card.kind === "af") return card.has_metar ? card.cat : "no report";
    return Sq.zoneStatusWord(card.status);
  }
  function title() {
    if (!card) return "?";
    return card.kind === "af" ? card.icao : card.desig;
  }
  function subtitle() {
    if (!card) return "";
    return card.name || "";
  }
  function subline() {
    if (!card) return "";
    if (card.kind === "af") {
      if (!card.has_metar) return "no METAR";
      return Sq.relArrow(card.rwy, card.hasWind ? card.wdir : NaN) + " " + card.wspd + "kt";
    }
    if (card.status === "geo") return "boundary + limits only";
    return card.when || "tracked area";
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.open()
  }
  Column {
    anchors.fill: parent
    anchors.margins: Style.space(8)
    spacing: 3
    CondIcon {
      cat: card && card.kind === "af" ? card.cat : "VFR"
      ink: statusColor()
      width: 26; height: 26
      visible: card && card.kind === "af" && card.has_metar
    }
    Text {
      text: title()
      color: Color.popups.text
      font.family: fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
    }
    Text {
      text: subtitle()
      color: Color.muted
      font.family: fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
      width: parent.width
    }
    Text {
      text: statusWord()
      color: statusColor()
      font.family: fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
    }
    Text {
      text: subline()
      color: Color.muted
      font.family: fontFamily
      font.pixelSize: Style.font.caption
    }
  }
  // set-home (airfields) + remove affordances
  Text {
    anchors.top: parent.top
    anchors.right: removeBtn.left
    anchors.margins: 4
    visible: ref && ref.kind === "af"
    text: "⌂"
    color: Color.muted
    font.pixelSize: Style.font.bodySmall
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: function (e) { e.accepted = true; root.makeHome(); }
    }
  }
  Text {
    id: removeBtn
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: 4
    text: "×"
    color: Color.muted
    font.pixelSize: Style.font.body
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: function (e) { e.accepted = true; root.remove(); }
    }
  }
}
