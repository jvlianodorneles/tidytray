import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: dropCaretRoot

  property bool active: false
  property bool vertical: false

  implicitWidth: vertical ? Style.bar.sizeHorizontal : 3
  implicitHeight: vertical ? 3 : Style.bar.sizeHorizontal
  visible: opacity > 0

  opacity: active ? 1.0 : 0.0

  Behavior on opacity {
    NumberAnimation { duration: 140 }
  }

  Rectangle {
    anchors.centerIn: parent
    width: dropCaretRoot.vertical ? parent.width - Style.space(8) : 2
    height: dropCaretRoot.vertical ? 2 : parent.height - Style.space(8)
    radius: 1
    color: Color.accent

    // Soft glow shadow / halo
    Rectangle {
      anchors.centerIn: parent
      width: parent.width + 2
      height: parent.height + 2
      radius: 2
      color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
      z: -1
    }
  }
}
