import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui

Item {
  id: indicatorRoot

  property bool expanded: false
  property bool vertical: false
  property string indicatorIcon: "chevron" // chevron, dot, dots, plus, none
  property string triggerMode: "click"     // click, hover
  property int duration: 200

  signal toggleRequested()
  signal rightClicked()
  signal hoverEntered()
  signal hoverExited()

  readonly property int buttonSize: Style.bar.iconSize + Style.space(6)
  implicitWidth: indicatorIcon === "none" ? 0 : (vertical ? Style.bar.sizeHorizontal : buttonSize)
  implicitHeight: indicatorIcon === "none" ? 0 : (vertical ? buttonSize : Style.bar.sizeHorizontal)
  visible: indicatorIcon !== "none"

  Rectangle {
    id: hoverBg
    anchors.centerIn: parent
    width: buttonSize
    height: buttonSize
    radius: Style.radius.small
    color: mouseArea.containsMouse ? Color.bar.buttonHover : "transparent"
    border.color: mouseArea.containsMouse ? Color.bar.buttonBorder : "transparent"
    border.width: 1

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Text {
      id: iconText
      anchors.centerIn: parent
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: Style.fontFace.icon
      font.pixelSize: Style.bar.iconFont
      color: mouseArea.containsMouse ? Color.accent : Color.bar.buttonForeground

      text: {
        switch (indicatorRoot.indicatorIcon) {
          case "dot": return "\uf111"    // nf-fa-circle
          case "dots": return "\uf141"   // nf-fa-ellipsis_h
          case "plus": return "\uf067"   // nf-fa-plus
          case "none": return ""
          case "chevron":
          default:
            return indicatorRoot.vertical ? "\uf078" : "\uf054" // chevron-down or chevron-right
        }
      }

      rotation: {
        if (indicatorRoot.indicatorIcon === "chevron") {
          return indicatorRoot.expanded ? 180 : 0
        }
        if (indicatorRoot.indicatorIcon === "plus") {
          return indicatorRoot.expanded ? 45 : 0
        }
        return 0
      }

      Behavior on rotation {
        NumberAnimation {
          duration: indicatorRoot.duration
          easing.type: Easing.OutCubic
        }
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor

    onEntered: {
      indicatorRoot.hoverEntered()
      if (indicatorRoot.triggerMode === "hover" && !indicatorRoot.expanded) {
        indicatorRoot.toggleRequested()
      }
    }

    onExited: {
      indicatorRoot.hoverExited()
    }

    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) {
        indicatorRoot.rightClicked()
      } else {
        indicatorRoot.toggleRequested()
      }
    }
  }
}
