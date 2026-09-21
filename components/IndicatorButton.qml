import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "../TrayModel.js" as TrayModel

BarIconButton {
  id: indicatorRoot

  property bool expanded: false
  property bool dragOver: false
  property string displayMode: "inline"    // inline, dropdown, drawer, flat
  property string indicatorIcon: "chevron" // chevron, dot, dots, plus, none
  property string triggerMode: "click"     // click, hover
  property bool onLeft: false
  property bool onTop: false
  property string barPosition: bar && bar.position ? String(bar.position) : (vertical ? (onLeft ? "left" : "right") : "top")
  property bool vertical: bar ? bar.vertical : (barPosition === "left" || barPosition === "right")
  property int duration: 200

  signal toggleRequested()
  signal rightClicked()
  signal hoverEntered()
  signal hoverExited()

  readonly property bool isChevronLike: {
    var icon = String(indicatorIcon || "").toLowerCase()
    return icon === "chevron" || icon === "caret" || icon === "angle" || icon === "arrow" || icon === "double"
  }

  visible: indicatorIcon !== "none"
  active: indicatorRoot.expanded || indicatorRoot.dragOver
  activeColor: Color.accent
  tooltipText: indicatorRoot.expanded ? "Collapse TidyTray" : "Expand TidyTray (Right-click: Manage)"

  text: TrayModel.chevronGlyph(indicatorRoot.indicatorIcon, indicatorRoot.vertical, indicatorRoot.onLeft, indicatorRoot.onTop)

  textRotation: {
    if (indicatorRoot.indicatorIcon === "plus") return indicatorRoot.expanded ? 45 : 0
    if (indicatorRoot.isChevronLike) {
      return TrayModel.chevronRotation(
        indicatorRoot.displayMode,
        indicatorRoot.barPosition,
        indicatorRoot.onLeft,
        indicatorRoot.onTop,
        indicatorRoot.expanded
      )
    }
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
