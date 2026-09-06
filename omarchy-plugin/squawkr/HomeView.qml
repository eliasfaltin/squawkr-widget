import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Squawkr.js" as Sq

// Panel home: header, home-airfield hero, tracked minis, footer.
// Cards are plain JS objects from Squawkr.js (airfieldCard/zoneCard shapes).
Column {
  id: root
  property var homeCard: null
  property var tracked: []
  property var trackedRefs: []
  property var ramp: Sq.FALLBACK_RAMP
  property string fontFamily: "monospace"
  property string ageLine: ""
  property string toastText: ""
  property int sel: -1
  signal openDetail(string id)
  signal addRequested()
  signal setHome(string icao)
  signal removeItem(string key)
  signal openService()
  spacing: Style.space(8)

  function cardKey(ref) { return ref.kind === "af" ? ref.icao : ref.id; }
  function detailId(ref) { return ref.kind === "af" ? ref.icao : ref.id; }

  // ---- header ----
  Row {
    width: parent.width
    Text {
      text: "SQUAWKR"
      color: Color.popups.text
      font.family: root.fontFamily
      font.pixelSize: Style.font.title
      font.bold: true
      font.letterSpacing: 2
    }
    Item { width: Style.space(8); height: 1 }
    Text {
      anchors.baseline: parent.children[0].baseline
      text: (root.homeCard ? root.homeCard.name : "—") + " · " + root.ageLine
      color: Color.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
      width: parent.width - 140
    }
  }

  // ---- hero ----
  Rectangle {
    width: parent.width
    height: heroRow.implicitHeight + Style.space(16)
    color: "transparent"
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: if (root.homeCard) root.openDetail(root.homeCard.icao)
    }
    Row {
      id: heroRow
      anchors.centerIn: parent
      width: parent.width - Style.space(16)
      spacing: Style.space(16)
      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        CondIcon {
          cat: root.homeCard ? root.homeCard.cat : "—"
          ink: root.ramp[Sq.catKey(root.homeCard ? root.homeCard.cat : "")]
          width: 52; height: 52
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.homeCard ? root.homeCard.cat : "—"
          color: root.ramp[Sq.catKey(root.homeCard ? root.homeCard.cat : "")]
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 220
        spacing: 4
        Text {
          text: root.homeCard ? root.homeCard.name : "—"
          color: Color.popups.text
          font.family: root.fontFamily
          font.pixelSize: Style.font.heading
          font.bold: true
          wrapMode: Text.Wrap
          width: parent.width
        }
        Text {
          text: (root.homeCard ? root.homeCard.icao : "") + " · HOME"
          color: Color.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
        Text {
          visible: root.homeCard && !root.homeCard.has_metar
          text: "No current weather report for this field."
          color: Color.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
          width: parent.width
        }
      }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(8)
        visible: root.homeCard && root.homeCard.has_metar
        StatBlock { label: "WIND"; main: root.homeCard ? (root.homeCard.wdir + "° · " + root.homeCard.wspd + " kt") : ""; sub: root.homeCard && root.homeCard.gust ? ("gust " + root.homeCard.gust + " kt") : "steady"; fontFamily: root.fontFamily }
        StatBlock { label: "FAVOURED RWY"; main: root.homeCard ? root.homeCard.rwy : ""; sub: ""; fontFamily: root.fontFamily }
        StatBlock { label: "QNH"; main: root.homeCard && root.homeCard.qnh ? root.homeCard.qnh : "—"; sub: root.homeCard ? ((root.homeCard.temp == null ? "—" : root.homeCard.temp) + "°C") : ""; fontFamily: root.fontFamily }
      }
    }
  }

  Rectangle { width: parent.width; height: 1; color: Color.menu.border }

  // ---- tracked minis ----
  Grid {
    width: parent.width
    columns: 3
    columnSpacing: Style.space(8)
    rowSpacing: Style.space(8)
    Repeater {
      model: root.tracked
      delegate: TrackedMini {
        card: modelData.card
        ref: modelData.ref
        ramp: root.ramp
        fontFamily: root.fontFamily
        selected: index === root.sel
        onOpen: root.openDetail(root.detailId(modelData.ref))
        onMakeHome: root.setHome(modelData.ref.icao)
        onRemove: root.removeItem(root.cardKey(modelData.ref))
      }
    }
    // add card
    Rectangle {
      width: (parent.width - Style.space(16)) / 3
      height: 118
      radius: Style.cornerRadius
      color: Color.menu.selectedBackground
      border.width: 1
      border.color: Color.menu.selectedBorder
      visible: root.tracked.length < Sq.MAX_TRACKED
      Text {
        anchors.centerIn: parent
        text: "+ add"
        color: Color.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.addRequested()
      }
    }
  }

  // ---- footer ----
  Item {
    width: parent.width
    height: 20
    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: "a add · h home · x remove · ↵ open"
      color: Color.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
    Text {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: "Full airspace & forecasts →"
      color: Color.accent
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openService()
      }
    }
  }
  Text {
    visible: root.toastText !== ""
    text: root.toastText
    color: Color.popups.text
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }
}
