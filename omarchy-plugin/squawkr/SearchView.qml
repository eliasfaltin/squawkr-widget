import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Combined airfield + restriction-zone search. Results are flat rows:
// {zone:bool, code, name, sub}. Panel.qml fills them via /plugin/search +
// the prefetched zone pool; picking emits the row index.
Column {
  id: root
  property var results: []
  property int current: -1
  property string fontFamily: "monospace"
  property bool busy: false
  signal queryChanged(string q)
  signal picked(int index)
  signal cancelled()
  spacing: Style.space(8)

  Text {
    text: "Add to your widget"
    color: Color.popups.text
    font.family: root.fontFamily
    font.pixelSize: Style.font.title
    font.bold: true
  }
  Text {
    text: "Search airfields and restriction zones — an ICAO, a place, or a zone name."
    color: Color.muted
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.Wrap
    width: parent.width
  }
  TextField {
    id: field
    width: parent.width
    placeholderText: "e.g. ESSA · Visby · R28"
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    onTextChanged: root.queryChanged(text)
    Component.onCompleted: forceActiveFocus()
    Keys.onEscapePressed: root.cancelled()
    Keys.onReturnPressed: if (root.results.length) root.picked(root.current >= 0 ? root.current : 0)
    Keys.onDownPressed: if (root.results.length) root.current = Math.min(root.current + 1, root.results.length - 1)
    Keys.onUpPressed: if (root.results.length) root.current = Math.max(root.current - 1, 0)
  }
  ListView {
    width: parent.width
    height: Math.min(300, count * 44)
    visible: count > 0
    clip: true
    model: root.results
    currentIndex: root.current
    delegate: Rectangle {
      width: ListView.view.width
      height: 44
      radius: 6
      color: index === root.current ? Color.menu.selectedBackground : "transparent"
      Row {
        anchors.fill: parent
        anchors.margins: Style.space(6)
        spacing: Style.space(8)
        Text {
          anchors.verticalCenter: parent.verticalCenter
          width: 56
          text: modelData.code || ""
          color: Color.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: true
        }
        Column {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - 150
          Text {
            text: modelData.name || ""
            color: Color.popups.text
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            width: parent.width
          }
          Text {
            visible: (modelData.sub || "") !== ""
            text: modelData.sub || ""
            color: Color.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: modelData.zone ? "zone" : "field"
          color: Color.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked(index)
      }
    }
  }
  Text {
    visible: !root.busy && root.results.length === 0 && field.text !== ""
    text: "No airfields or zones match."
    color: Color.muted
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
  Item {
    width: parent.width
    height: 30
    Rectangle {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: 110; height: 28
      radius: 6
      color: "transparent"
      border.width: 1
      border.color: Color.menu.border
      Text {
        anchors.centerIn: parent
        text: "Cancel (Esc)"
        color: Color.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.cancelled()
      }
    }
  }
}
