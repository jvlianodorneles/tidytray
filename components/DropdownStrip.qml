import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "../TrayModel.js" as TrayModel

Item {
  id: dropdownStripRoot

  property var bar: null
  property Item barAnchor: null
  property var hostedWidgets: []
  property var sniItems: []
  property bool vertical: false

  signal sniMenuRequested(var item, var target, var mouse)
  signal dragStarted(var entry, var mouse)

  readonly property int itemsSpacing: Style.space(6)
  readonly property int stripPadding: Style.space(6)
  readonly property alias itemsRowKids: itemsRow.children

  readonly property int fullContentWidth: vertical
    ? Style.bar.sizeHorizontal
    : (itemsRow.implicitWidth + stripPadding * 2)
  readonly property int fullContentHeight: vertical
    ? (itemsRow.implicitHeight + stripPadding * 2)
    : Style.bar.sizeHorizontal

  implicitWidth: fullContentWidth
  implicitHeight: fullContentHeight

  Flickable {
    id: flickable
    anchors.fill: parent
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: dropdownStripRoot.vertical ? Flickable.VerticalFlick : Flickable.HorizontalFlick

    contentWidth: dropdownStripRoot.vertical ? width : Math.max(width, dropdownStripRoot.fullContentWidth)
    contentHeight: dropdownStripRoot.vertical ? Math.max(height, dropdownStripRoot.fullContentHeight) : height

    interactive: dropdownStripRoot.vertical
      ? (contentHeight > height)
      : (contentWidth > width)

    WheelHandler {
      id: wheelHandler
      acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
      onWheel: function(event) {
        var delta = 0
        if (dropdownStripRoot.vertical) {
          delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
          flickable.contentY = Math.max(0, Math.min(flickable.contentHeight - flickable.height, flickable.contentY - delta))
        } else {
          delta = event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y
          flickable.contentX = Math.max(0, Math.min(flickable.contentWidth - flickable.width, flickable.contentX - delta))
        }
      }
    }

    Item {
      width: flickable.contentWidth
      height: flickable.contentHeight

      Grid {
        id: itemsRow
        anchors.centerIn: parent
        columns: dropdownStripRoot.vertical ? 1 : 9999
        spacing: dropdownStripRoot.itemsSpacing

        // Hosted Widgets
        Repeater {
          model: dropdownStripRoot.hostedWidgets
          delegate: HostedWidget {
            bar: dropdownStripRoot.bar
            barAnchor: dropdownStripRoot.barAnchor
            vertical: dropdownStripRoot.vertical
            onDragStarted: function(entry, mouse) {
              dropdownStripRoot.dragStarted(entry, mouse)
            }
          }
        }

        // SNI Items
        Repeater {
          model: dropdownStripRoot.sniItems
          delegate: SnItemDelegate {
            bar: dropdownStripRoot.bar
            vertical: dropdownStripRoot.vertical
            onRequestMenu: function(item, target, mouse) {
              dropdownStripRoot.sniMenuRequested(item, target, mouse)
            }
          }
        }
      }
    }
  }

  // Left fade indicator (horizontal)
  Rectangle {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: Style.space(16)
    visible: !dropdownStripRoot.vertical && flickable.contentX > 2
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: Color.popups.background }
      GradientStop { position: 1.0; color: "transparent" }
    }
  }

  // Right fade indicator (horizontal)
  Rectangle {
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: Style.space(16)
    visible: !dropdownStripRoot.vertical && (flickable.contentX + flickable.width < flickable.contentWidth - 2)
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: "transparent" }
      GradientStop { position: 1.0; color: Color.popups.background }
    }
  }

  // Top fade indicator (vertical)
  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: Style.space(16)
    visible: dropdownStripRoot.vertical && flickable.contentY > 2
    gradient: Gradient {
      orientation: Gradient.Vertical
      GradientStop { position: 0.0; color: Color.popups.background }
      GradientStop { position: 1.0; color: "transparent" }
    }
  }

  // Bottom fade indicator (vertical)
  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: Style.space(16)
    visible: dropdownStripRoot.vertical && (flickable.contentY + flickable.height < flickable.contentHeight - 2)
    gradient: Gradient {
      orientation: Gradient.Vertical
      GradientStop { position: 0.0; color: "transparent" }
      GradientStop { position: 1.0; color: Color.popups.background }
    }
  }
}
