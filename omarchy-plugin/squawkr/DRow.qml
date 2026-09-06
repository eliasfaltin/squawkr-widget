import QtQuick
import qs.Commons
import qs.Ui

Row {
  property string lbl: ""
  property string val: ""
  property string fontFamily: "monospace"
  width: parent ? parent.width : 200
  spacing: Style.space(8)
  Text {
    width: 90
    text: lbl
    color: Color.muted
    font.family: fontFamily
    font.pixelSize: Style.font.caption
  }
  Text {
    width: parent.width - 98
    text: val || "—"
    color: Color.popups.text
    font.family: fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.Wrap
  }
}
