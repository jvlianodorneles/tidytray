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
  property var drawerItems: []
  property bool vertical: false

  signal sniMenuRequested(var item, var target, var mouse)
  signal dragStarted(var entry, var mouse)
  signal reorderRequested(int fromIndex, int toIndex)

  readonly property var effectiveItems: (drawerItems && drawerItems.length > 0)
    ? drawerItems
    : TrayModel.buildDrawerItems(hostedWidgets, sniItems, [])

  readonly property int itemsSpacing: Style.space(6)
  readonly property int stripPadding: Style.space(6)
  readonly property alias itemsRowKids: itemsRow.children

  // Drag & drop reorder state
  property bool isDragActive: false
  property int draggingIndex: -1
  property var draggingItem: null
  property int dropTargetIndex: -1
  property bool dropAfter: false
  property real dragCursorX: 0
  property real dragCursorY: 0

  function indexOfDelegate(delegate) {
    if (!delegate) return -1
    var dId = ""
    if ("widgetId" in delegate && delegate.widgetId) dId = String(delegate.widgetId)
    else if ("itemId" in delegate && delegate.itemId) dId = String(delegate.itemId)
    else if ("modelData" in delegate && delegate.modelData) {
      dId = String(delegate.modelData.id || (delegate.modelData.entry ? delegate.modelData.entry.id : "") || "")
    } else if ("entry" in delegate && delegate.entry) {
      dId = TrayModel.entryId(delegate.entry)
    }
    if (!dId) return -1
    for (var i = 0; i < effectiveItems.length; i++) {
      if (effectiveItems[i].id === dId || effectiveItems[i].key === dId) return i
    }
    return -1
  }

  function startDrag(fromIdx, delegate, localPos) {
    if (fromIdx < 0 || fromIdx >= effectiveItems.length) return
    draggingIndex = fromIdx
    draggingItem = effectiveItems[fromIdx]
    dropTargetIndex = fromIdx
    dropAfter = false
    isDragActive = true
    if (delegate && localPos) {
      var p = dropdownStripRoot.mapFromItem(delegate, localPos.x, localPos.y)
      dragCursorX = p.x
      dragCursorY = p.y
    }
    updateDropCaret()
  }

  function updateDrag(px, py) {
    if (!isDragActive) return
    dragCursorX = px
    dragCursorY = py

    var rowPoint = itemsRow.mapFromItem(dropdownStripRoot, px, py)
    var targetIdx = -1
    var after = false
    var minDistance = 999999
    var kids = itemsRow.children

    for (var i = 0; i < kids.length; i++) {
      var tile = kids[i]
      if (!tile || !tile.visible || tile.width <= 0) continue

      if (dropdownStripRoot.vertical) {
        if (rowPoint.y >= tile.y && rowPoint.y <= tile.y + tile.height) {
          targetIdx = i
          after = rowPoint.y > (tile.y + tile.height / 2)
          break
        }
        var rcy = tile.y + tile.height / 2
        var rdist = Math.abs(rowPoint.y - rcy)
        if (rdist < minDistance) {
          minDistance = rdist
          targetIdx = i
          after = rowPoint.y > rcy
        }
      } else {
        if (rowPoint.x >= tile.x && rowPoint.x <= tile.x + tile.width) {
          targetIdx = i
          after = rowPoint.x > (tile.x + tile.width / 2)
          break
        }
        var rcx = tile.x + tile.width / 2
        var cdist = Math.abs(rowPoint.x - rcx)
        if (cdist < minDistance) {
          minDistance = cdist
          targetIdx = i
          after = rowPoint.x > rcx
        }
      }
    }

    if (targetIdx >= 0) {
      dropTargetIndex = targetIdx
      dropAfter = after
      updateDropCaret()
    }
  }

  function updateDropCaret() {
    if (dropTargetIndex < 0 || !isDragActive) {
      dropCaret.visible = false
      return
    }
    var kids = itemsRow.children
    if (dropTargetIndex >= kids.length) {
      dropCaret.visible = false
      return
    }
    var tile = kids[dropTargetIndex]
    if (!tile || !tile.visible) {
      dropCaret.visible = false
      return
    }
    var gap = dropdownStripRoot.itemsSpacing
    if (dropdownStripRoot.vertical) {
      var ty = tile.y + (dropAfter ? (tile.height + gap / 2) : -gap / 2)
      dropCaret.x = tile.x
      dropCaret.y = Math.max(0, ty - dropCaret.height / 2)
      dropCaret.width = tile.width
      dropCaret.height = 3
    } else {
      var tx = tile.x + (dropAfter ? (tile.width + gap / 2) : -gap / 2)
      dropCaret.x = Math.max(0, tx - dropCaret.width / 2)
      dropCaret.y = tile.y
      dropCaret.width = 3
      dropCaret.height = tile.height
    }
    dropCaret.visible = true
  }

  function cancelDrag() {
    isDragActive = false
    draggingIndex = -1
    draggingItem = null
    dropTargetIndex = -1
    dropAfter = false
    dropCaret.visible = false
  }

  function endDrag() {
    if (!isDragActive) return
    var from = draggingIndex
    var target = dropTargetIndex
    var after = dropAfter
    var to = TrayModel.calculateDropIndex(from, target, after)
    cancelDrag()
    if (from >= 0 && to >= 0 && from !== to) {
      dropdownStripRoot.reorderRequested(from, to)
    }
  }

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

        // Drop caret inside strip
        Rectangle {
          id: dropCaret
          visible: false
          z: 100
          radius: 1.5
          color: Color.accent
        }

        Repeater {
          model: dropdownStripRoot.effectiveItems
          delegate: Item {
            id: stripTile
            required property var modelData
            required property int index

            readonly property string widgetId: modelData ? String(modelData.id || "") : ""
            readonly property bool isThisDragged: dropdownStripRoot.isDragActive && dropdownStripRoot.draggingIndex === index

            opacity: isThisDragged ? 0.35 : 1.0
            implicitWidth: modelData && modelData.isWidget
              ? (dropdownStripRoot.vertical ? Style.bar.sizeHorizontal : Math.max(Style.bar.iconSlot, (hwLoader.item ? hwLoader.item.implicitWidth : 0)))
              : (dropdownStripRoot.vertical ? Style.bar.sizeHorizontal : Style.bar.iconSlot)
            implicitHeight: modelData && modelData.isWidget
              ? (dropdownStripRoot.vertical ? Math.max(Style.bar.iconSlot, (hwLoader.item ? hwLoader.item.implicitHeight : 0)) : Style.bar.sizeHorizontal)
              : (dropdownStripRoot.vertical ? Style.bar.iconSlot : Style.bar.sizeHorizontal)
            width: implicitWidth
            height: implicitHeight

            Loader {
              id: hwLoader
              active: stripTile.modelData && stripTile.modelData.isWidget
              anchors.centerIn: parent
              sourceComponent: Component {
                HostedWidget {
                  bar: dropdownStripRoot.bar
                  barAnchor: dropdownStripRoot.barAnchor
                  vertical: dropdownStripRoot.vertical
                  modelData: stripTile.modelData.modelData
                  onDragStarted: function(entry, mouse) {
                    dropdownStripRoot.dragStarted(entry, mouse)
                  }
                }
              }
            }

            Loader {
              id: sniLoader
              active: stripTile.modelData && stripTile.modelData.isSni
              anchors.centerIn: parent
              sourceComponent: Component {
                SnItemDelegate {
                  bar: dropdownStripRoot.bar
                  vertical: dropdownStripRoot.vertical
                  modelData: stripTile.modelData.modelData
                  onRequestMenu: function(item, target, mouse) {
                    dropdownStripRoot.sniMenuRequested(item, target, mouse)
                  }
                }
              }
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
