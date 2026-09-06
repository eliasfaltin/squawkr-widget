import QtQuick
import qs.Commons
import qs.Ui
import "Squawkr.js" as Sq

// Detail for one card: airfield (runway + stats + forecast note) or
// restriction zone (height meter + week strip + windows).
Column {
  id: root
  property var card: null
  property var ramp: Sq.FALLBACK_RAMP
  property string fontFamily: "monospace"
  signal back()
  signal setHome(string icao)
  signal removeItem(string key)
  signal openReport()
  spacing: Style.space(10)

  function isAf() { return card && card.kind === "af"; }
  function title() { return card ? (isAf() ? card.icao : card.desig) : "?"; }
  function subtitle() { return card ? (card.name || "") : ""; }
  function pillText() { return card ? (isAf() ? card.cat : Sq.zoneStatusWord(card.status)) : ""; }
  function pillColor() {
    if (!card) return Color.muted;
    return ramp[isAf() ? Sq.catKey(card.cat) : Sq.zoneRampKey(card.status)];
  }

  // ---- head ----
  Row {
    width: parent.width
    spacing: Style.space(12)
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: 64; height: 30
      radius: 6
      color: "transparent"
      border.width: 1
      border.color: Color.menu.border
      Text {
        anchors.centerIn: parent
        text: "‹ back"
        color: Color.popups.text
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.back()
      }
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - 64 - 90
      text: "<b>" + title() + "</b> · " + subtitle()
      textFormat: Text.RichText
      color: Color.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.title
      elide: Text.ElideRight
    }
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: 78; height: 24
      radius: 5
      color: "transparent"
      border.width: 1
      border.color: pillColor()
      Text {
        anchors.centerIn: parent
        text: pillText()
        color: pillColor()
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }
  }

  // ---- airfield body ----
  Row {
    width: parent.width
    spacing: Style.space(16)
    visible: isAf()
    Column {
      spacing: 2
      RunwayStrip {
        rwy: card && card.rwy ? card.rwy : ""
        wdir: card ? card.wdir : 0
        hasWind: card ? !!card.hasWind : false
        track: Color.menu.selectedBackground
        edge: Color.menu.border
        chev: Color.accent
        num: Color.popups.text
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: card && card.has_metar ? ("RWY " + card.rwy) : "no wind reference"
        color: Color.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
    Column {
      width: parent.width - 120
      spacing: 0
      visible: isAf() && card && card.has_metar
      DRow { lbl: "WIND"; val: card ? (card.wdir + "° · " + card.wspd + " kt" + (card.gust ? " G" + card.gust : "")) : ""; fontFamily: root.fontFamily }
      DRow { lbl: "QNH"; val: card && card.qnh ? (card.qnh + " hPa") : "—"; fontFamily: root.fontFamily }
      DRow { lbl: "TEMP / DEW"; val: card ? ((card.temp == null ? "—" : card.temp) + "° / " + (card.dew == null ? "—" : card.dew) + "°") : ""; fontFamily: root.fontFamily }
      DRow { lbl: "CLOUD"; val: card ? Sq.cloudsText(card) : ""; fontFamily: root.fontFamily }
      Text {
        text: "FORECAST"
        color: Color.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
      Text {
        text: card && card.has_taf ? "Forecast (TAF) issued — see the full report below." : "No forecast available."
        color: Color.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
        width: parent.width
      }
    }
    Column {
      width: parent.width - 120
      spacing: Style.space(6)
      visible: isAf() && card && !card.has_metar
      Text {
        text: "No weather report for this field."
        color: Color.popups.text
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        wrapMode: Text.Wrap
        width: parent.width
      }
      Text {
        text: "No METAR station — wind, sky and flight category aren't available. Runway data only."
        color: Color.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
        width: parent.width
      }
    }
  }

  // ---- zone body ----
  Row {
    width: parent.width
    spacing: Style.space(16)
    visible: !isAf()
    Column {
      spacing: 2
      HeightMeter {
        lo: card ? card.lo : "GND"
        hi: card ? card.hi : "UNL"
        unl: card ? (card.hi === "UNL") : true
        ink: pillColor()
        faint: Color.muted
        track: Color.menu.selectedBackground
        edge: Color.menu.border
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "vertical extent"
        color: Color.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
    Column {
      width: parent.width - 130
      spacing: Style.space(8)
      Text {
        visible: card && card.status === "geo"
        text: "We show this airspace's boundary and limits only. Status unknown — check an official source before you fly."
        color: Color.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
        width: parent.width
      }
      Column {
        visible: card && card.status !== "geo"
        spacing: Style.space(6)
        Text {
          text: "UPCOMING · " + (card && card.when ? card.when : "—")
          color: Color.popups.text
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
        Row {
          spacing: Style.space(6)
          Repeater {
            model: card && card.week ? card.week.split("") : []
            delegate: Column {
              spacing: 3
              property string cell: modelData
              property color cellColor: cell === "A" ? ramp.active : (cell === "W" ? ramp.sched : Color.menu.selectedBackground)
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "MTWTFSS"[index] || ""
                color: Color.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
              Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 26; height: 8
                radius: 4
                color: cellColor
              }
            }
          }
        }
        Text {
          visible: card && card.sched
          text: card ? (card.sched || "") : ""
          color: Color.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.Wrap
          width: parent.width - 130
        }
      }
    }
  }

  // ---- foot ----
  Item {
    width: parent.width
    height: 22
    Text {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: "Full report on squawkr.net →"
      color: Color.accent
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openReport()
      }
    }
  }
}
