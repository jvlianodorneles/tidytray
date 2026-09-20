import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "../TrayModel.js" as TrayModel

BarIconButton {
  id: indicatorRoot

  property bool expanded: false
  property bool dragOver: false
  property string indicatorIcon: "chevron" // chevron, dot, dots, plus, none
  property string triggerMode: "click"     // click, hover
  property int duration: 200

  signal toggleRequested()
  signal rightClicked()
  signal hoverEntered()
  signal hoverExited()

  visible: indicatorIcon !== "none"
  active: indicatorRoot.expanded || indicatorRoot.dragOver
  activeColor: Color.accent
  tooltipText: "TidyTray"

  text: TrayModel.chevronGlyph(indicatorRoot.indicatorIcon, indicatorRoot.vertical)

  textRotation: {
    if (indicatorRoot.indicatorIcon === "plus") return indicatorRoot.expanded ? 45 : 0
    if (indicatorRoot.indicatorIcon === "chevron") return indicatorRoot.expanded ? 180 : 0
    return 0
  }

  Behavior on textRotation {
    NumberAnimation {
      duration: indicatorRoot.duration
      easing.type: Easing.OutCubic
    }
  }

  onPressed: function(button) {
    if (button === Qt.RightButton) {
      indicatorRoot.rightClicked()
    } else if (button === Qt.LeftButton) {
      indicatorRoot.toggleRequested()
    }
  }

  HoverHandler {
    onHoveredChanged: {
      if (hovered) {
        indicatorRoot.hoverEntered()
        if (indicatorRoot.triggerMode === "hover" && !indicatorRoot.expanded) {
          indicatorRoot.toggleRequested()
        }
      } else {
        indicatorRoot.hoverExited()
      }
    }
  }
}
