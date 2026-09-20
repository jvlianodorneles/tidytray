import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Services.SystemTray
import qs.Commons
import qs.Ui

Item {
  id: snItemRoot

  property var modelData: null
  property var bar: null
  property color foregroundColor: bar ? bar.foreground : Color.foreground
  property int iconExtent: Style.bar.iconSlot
  property bool vertical: false

  signal requestMenu(var item, var targetItem, var mouse)
  signal dragStarted(var item, var mouse)

  readonly property string itemId: String(modelData && modelData.id ? modelData.id : "")
  readonly property bool isVisible: modelData ? modelData.status !== Status.Passive : false

  visible: isVisible
  implicitWidth: isVisible ? (vertical ? Style.bar.sizeHorizontal : iconExtent) : 0
  implicitHeight: isVisible ? (vertical ? iconExtent : Style.bar.sizeHorizontal) : 0
  width: implicitWidth
  height: implicitHeight

  function iconIsSymbolic(icon) {
    var name = String(icon || "").split("?")[0]
    return name.slice(-9) === "-symbolic"
  }

  function cleanTooltipText(str) {
    return String(str || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .slice(0, 200)
  }

  readonly property string tooltipText: {
    if (!modelData) return ""
    return cleanTooltipText(modelData.tooltipTitle || modelData.title || modelData.id || "")
  }

  Rectangle {
    id: hoverHighlight
    anchors.centerIn: parent
    width: Style.bar.iconCanvas + Style.space(6)
    height: Style.bar.iconCanvas + Style.space(6)
    radius: Style.cornerRadius
    color: mouseArea.containsMouse ? Style.hoverFill : "transparent"
    border.color: mouseArea.containsMouse ? Style.hoverBorderColor : "transparent"
    border.width: mouseArea.containsMouse ? 1 : 0

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Item {
      id: iconContainer
      anchors.centerIn: parent
      width: Style.bar.iconCanvas
      height: Style.bar.iconCanvas

      readonly property string rawIcon: modelData ? String(modelData.icon || "") : ""
      readonly property bool isSymbolic: snItemRoot.iconIsSymbolic(rawIcon)

      Image {
        id: iconImage
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        sourceSize.width: Math.max(16, Math.round(Math.min(width, height) * Screen.devicePixelRatio))
        sourceSize.height: Math.max(16, Math.round(Math.min(width, height) * Screen.devicePixelRatio))
        source: iconContainer.rawIcon
        visible: !iconContainer.isSymbolic
        layer.enabled: iconContainer.isSymbolic
      }

      MultiEffect {
        anchors.fill: iconImage
        source: iconImage
        visible: iconContainer.isSymbolic
        colorization: 1.0
        colorizationColor: snItemRoot.foregroundColor
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    cursorShape: Qt.PointingHandCursor

    property real pressX: 0
    property real pressY: 0
    property bool isDragging: false

    onEntered: {
      if (snItemRoot.bar && snItemRoot.tooltipText && typeof snItemRoot.bar.showTooltip === "function") {
        snItemRoot.bar.showTooltip(snItemRoot, snItemRoot.tooltipText)
      }
    }

    onExited: {
      if (snItemRoot.bar && typeof snItemRoot.bar.hideTooltip === "function") {
        snItemRoot.bar.hideTooltip(snItemRoot)
      }
    }

    onPressed: function(mouse) {
      pressX = mouse.x
      pressY = mouse.y
      isDragging = false
    }

    onPositionChanged: function(mouse) {
      if (!pressed) return
      if (!isDragging) {
        var dx = mouse.x - pressX
        var dy = mouse.y - pressY
        if ((dx * dx + dy * dy) > 36) {
          isDragging = true
          snItemRoot.dragStarted(snItemRoot.modelData, mouse)
        }
      }
    }

    onWheel: function(wheel) {
      if (snItemRoot.modelData && typeof snItemRoot.modelData.scroll === "function") {
        snItemRoot.modelData.scroll(wheel.angleDelta.y, false)
      }
    }

    onClicked: function(mouse) {
      if (isDragging) return
      if (!snItemRoot.modelData) return

      if (mouse.button === Qt.RightButton) {
        snItemRoot.requestMenu(snItemRoot.modelData, snItemRoot, mouse)
      } else if (mouse.button === Qt.MiddleButton) {
        if (typeof snItemRoot.modelData.secondaryActivate === "function") {
          snItemRoot.modelData.secondaryActivate(mouse.x, mouse.y)
        }
      } else {
        if (typeof snItemRoot.modelData.activate === "function") {
          snItemRoot.modelData.activate(mouse.x, mouse.y)
        }
      }
    }
  }
}
