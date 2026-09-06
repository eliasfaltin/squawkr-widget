import QtQuick
import qs.Commons
import qs.Ui

Column {
  property string label: ""
  property string main: ""
  property string sub: ""
  property string fontFamily: "monospace"
  spacing: 2
  Text {
    text: label
    color: Color.muted
    font.family: fontFamily
    font.pixelSize: Style.font.caption
  }
  Text {
    text: main || "—"
    color: Color.popups.text
    font.family: fontFamily
    font.pixelSize: Style.font.body
  }
  Text {
    visible: sub !== ""
    text: sub
    color: Color.muted
    font.family: fontFamily
    font.pixelSize: Style.font.caption
  }
}
