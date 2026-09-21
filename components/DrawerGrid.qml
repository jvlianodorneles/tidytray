import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "../TrayModel.js" as TrayModel

Item {
  id: drawerGridRoot

  property var bar: null
  property Item barAnchor: null
  property var hostedWidgets: []
  property var sniItems: []
  property var drawerItems: []
  property string searchQuery: ""
  property string viewMode: "grid" // "grid" or "list"

  signal openSettingsRequested()
  signal sniActivated(var item)
  signal sniMenuRequested(var item, var target, var mouse)
  signal reorderRequested(int fromIndex, int toIndex)

  readonly property var effectiveItems: (drawerItems && drawerItems.length > 0)
    ? drawerItems
    : TrayModel.buildDrawerItems(hostedWidgets, sniItems, [])

  readonly property bool isEditing: searchInput.activeFocus
  readonly property int neededHeight: drawerColumn.implicitHeight + Style.space(16)
  readonly property alias flowKids: flowView.children
  readonly property alias listKids: listViewCol.children

  // Drag & drop reordering state
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
      var p = drawerGridRoot.mapFromItem(delegate, localPos.x, localPos.y)
      dragCursorX = p.x
      dragCursorY = p.y
    }
    updateDropCaret()
  }

  function updateDrag(px, py) {
    if (!isDragActive) return
    dragCursorX = px
    dragCursorY = py

    var ccPoint = contentContainer.mapFromItem(drawerGridRoot, px, py)
    var targetIdx = -1
    var after = false
    var minDistance = 999999

    if (viewMode === "grid") {
      var kids = flowView.children
      for (var i = 0; i < kids.length; i++) {
        var tile = kids[i]
        if (!tile || !tile.visible || tile.width <= 0) continue
        var tileX = flowView.x + tile.x
        var tileY = flowView.y + tile.y

        if (ccPoint.x >= tileX && ccPoint.x <= tileX + tile.width &&
            ccPoint.y >= tileY && ccPoint.y <= tileY + tile.height) {
          targetIdx = i
          after = ccPoint.x > (tileX + tile.width / 2)
          break
        }

        var cx = tileX + tile.width / 2
        var cy = tileY + tile.height / 2
        var dist = Math.sqrt(Math.pow(ccPoint.x - cx, 2) + Math.pow(ccPoint.y - cy, 2))
        if (dist < minDistance) {
          minDistance = dist
          targetIdx = i
          after = ccPoint.x > cx
        }
      }
    } else {
      var rows = listViewCol.children
      for (var j = 0; j < rows.length; j++) {
        var row = rows[j]
        if (!row || !row.visible || row.height <= 0) continue
        var rowY = listViewCol.y + row.y

        if (ccPoint.y >= rowY && ccPoint.y <= rowY + row.height) {
          targetIdx = j
          after = ccPoint.y > (rowY + row.height / 2)
          break
        }

        var rcy = rowY + row.height / 2
        var rdist = Math.abs(ccPoint.y - rcy)
        if (rdist < minDistance) {
          minDistance = rdist
          targetIdx = j
          after = ccPoint.y > rcy
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
    if (viewMode === "grid") {
      var kids = flowView.children
      if (dropTargetIndex >= kids.length) {
        dropCaret.visible = false
        return
      }
      var tile = kids[dropTargetIndex]
      if (!tile || !tile.visible) {
        dropCaret.visible = false
        return
      }
      var gap = flowView.spacing
      var tx = flowView.x + tile.x + (dropAfter ? (tile.width + gap / 2) : -gap / 2)
      dropCaret.x = Math.max(0, tx - dropCaret.width / 2)
      dropCaret.y = flowView.y + tile.y
      dropCaret.width = 3
      dropCaret.height = tile.height
      dropCaret.visible = true
    } else {
      var rows = listViewCol.children
      if (dropTargetIndex >= rows.length) {
        dropCaret.visible = false
        return
      }
      var row = rows[dropTargetIndex]
      if (!row || !row.visible) {
        dropCaret.visible = false
        return
      }
      var rgap = listViewCol.spacing
      var ty = listViewCol.y + row.y + (dropAfter ? (row.height + rgap / 2) : -rgap / 2)
      dropCaret.x = listViewCol.x + row.x
      dropCaret.y = Math.max(0, ty - dropCaret.height / 2)
      dropCaret.width = row.width
      dropCaret.height = 3
      dropCaret.visible = true
    }
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
      drawerGridRoot.reorderRequested(from, to)
    }
  }

  implicitWidth: Style.space(340)
  implicitHeight: neededHeight

  Column {
    id: drawerColumn
    width: parent ? parent.width : Style.space(340)
    spacing: Style.space(10)

    // Top Bar: Search + View Toggle + Settings
    Row {
      width: parent.width
      spacing: Style.space(6)

      // Search box
      Rectangle {
        width: parent.width - 70
        height: 28
        radius: Style.cornerRadius
        color: Style.hoverFill
        border.color: searchInput.activeFocus ? Color.accent : "transparent"
        border.width: 1

        Row {
          anchors.fill: parent
          anchors.leftMargin: 6
          anchors.rightMargin: 6
          spacing: 6

          Text {
            text: "\uf002" // nf-fa-search
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            color: Color.muted
            anchors.verticalCenter: parent.verticalCenter
          }

          TextInput {
            id: searchInput
            width: parent.width - 24
            anchors.verticalCenter: parent.verticalCenter
            text: drawerGridRoot.searchQuery
            color: Color.foreground
            font.pixelSize: Style.font.bodySmall
            maximumLength: 32
            selectByMouse: true
            onTextChanged: drawerGridRoot.searchQuery = text

            Text {
              text: "Filter..."
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              color: Color.muted
              font.pixelSize: Style.font.bodySmall
              visible: !searchInput.text && !searchInput.activeFocus
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }
      }

      // Grid/List toggle
      Rectangle {
        width: 28
        height: 28
        radius: Style.cornerRadius
        color: Style.hoverFill

        Text {
          anchors.centerIn: parent
          text: drawerGridRoot.viewMode === "grid" ? "\uf00b" : "\uf009" // list vs th
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          color: Color.foreground
        }

        MouseArea {
          id: viewToggleMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: drawerGridRoot.viewMode = (drawerGridRoot.viewMode === "grid" ? "list" : "grid")
        }

        PanelToolTip {
          visible: viewToggleMouse.containsMouse
          text: drawerGridRoot.viewMode === "grid" ? "Switch to list view" : "Switch to grid view"
        }
      }

      // Settings button
      Rectangle {
        width: 28
        height: 28
        radius: Style.cornerRadius
        color: Style.hoverFill

        Text {
          anchors.centerIn: parent
          text: "\uf013" // nf-fa-cog
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          color: Color.foreground
        }

        MouseArea {
          id: settingsBtnMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: drawerGridRoot.openSettingsRequested()
        }

        PanelToolTip {
          visible: settingsBtnMouse.containsMouse
          text: "Manage TidyTray (S)"
        }
      }
    }

    // Main Content Area: Flow for Grid or Column for List
    Flickable {
      id: flickableArea
      width: parent.width
      height: Math.min(280, contentContainer.implicitHeight)
      contentHeight: contentContainer.implicitHeight
      clip: true

      Item {
        id: contentContainer
        width: parent.width
        implicitHeight: drawerGridRoot.viewMode === "grid" ? flowView.implicitHeight : listViewCol.implicitHeight

        // Empty state message when no items are tucked in
        Text {
          anchors.centerIn: parent
          text: "Drawer is empty.\nDrag bar widgets here or click settings to manage."
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          horizontalAlignment: Text.AlignHCenter
          font.pixelSize: Style.font.bodySmall
          color: Color.muted
          visible: drawerGridRoot.effectiveItems.length === 0
        }

        // Drop insertion indicator caret
        Rectangle {
          id: dropCaret
          visible: false
          z: 100
          radius: 1.5
          color: Color.accent
        }

        // 1. GRID VIEW
        Flow {
          id: flowView
          width: parent.width
          spacing: Style.space(8)
          visible: drawerGridRoot.viewMode === "grid"

          Repeater {
            id: flowRepeater
            model: drawerGridRoot.viewMode === "grid" ? drawerGridRoot.effectiveItems : []
            delegate: Item {
              id: gridTile
              required property var modelData
              required property int index

              readonly property string wId: modelData ? String(modelData.id || "") : ""
              readonly property bool isThisDragged: drawerGridRoot.isDragActive && drawerGridRoot.draggingIndex === index
              readonly property bool matches: !drawerGridRoot.searchQuery ||
                wId.toLowerCase().indexOf(drawerGridRoot.searchQuery.toLowerCase()) !== -1 ||
                String(modelData.title || "").toLowerCase().indexOf(drawerGridRoot.searchQuery.toLowerCase()) !== -1

              visible: matches
              opacity: isThisDragged ? 0.35 : 1.0
              width: modelData && modelData.isWidget
                ? Math.max(Style.bar.iconSlot, (hostedWidgetLoader.item ? hostedWidgetLoader.item.implicitWidth : 0))
                : Style.bar.iconSlot
              height: Style.bar.iconSlot

              Loader {
                id: hostedWidgetLoader
                active: gridTile.modelData && gridTile.modelData.isWidget
                anchors.centerIn: parent
                sourceComponent: Component {
                  HostedWidget {
                    bar: drawerGridRoot.bar
                    barAnchor: drawerGridRoot.barAnchor
                    modelData: gridTile.modelData.modelData
                  }
                }
              }

              Loader {
                id: snItemLoader
                active: gridTile.modelData && gridTile.modelData.isSni
                anchors.centerIn: parent
                sourceComponent: Component {
                  SnItemDelegate {
                    bar: drawerGridRoot.bar
                    modelData: gridTile.modelData.modelData
                    onRequestMenu: function(item, target, mouse) {
                      drawerGridRoot.sniMenuRequested(item, target, mouse)
                    }
                  }
                }
              }
            }
          }
        }

        // 2. LIST VIEW
        Column {
          id: listViewCol
          width: parent.width
          spacing: 4
          visible: drawerGridRoot.viewMode === "list"

          Repeater {
            id: listRepeater
            model: drawerGridRoot.viewMode === "list" ? drawerGridRoot.effectiveItems : []
            delegate: Rectangle {
              id: listRow
              required property var modelData
              required property int index

              readonly property string wId: modelData ? String(modelData.id || "") : ""
              readonly property bool isThisDragged: drawerGridRoot.isDragActive && drawerGridRoot.draggingIndex === index
              readonly property bool matches: !drawerGridRoot.searchQuery ||
                wId.toLowerCase().indexOf(drawerGridRoot.searchQuery.toLowerCase()) !== -1 ||
                String(modelData.title || "").toLowerCase().indexOf(drawerGridRoot.searchQuery.toLowerCase()) !== -1

              visible: matches
              opacity: isThisDragged ? 0.35 : 1.0
              width: listViewCol.width
              height: 36
              radius: Style.cornerRadius
              color: rowDragArea.containsMouse ? Style.hoverFill : Color.alpha(Color.foreground, 0.04)

              Row {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                Loader {
                  active: listRow.modelData && listRow.modelData.isWidget
                  anchors.verticalCenter: parent.verticalCenter
                  sourceComponent: Component {
                    HostedWidget {
                      bar: drawerGridRoot.bar
                      barAnchor: drawerGridRoot.barAnchor
                      modelData: listRow.modelData.modelData
                    }
                  }
                }

                Loader {
                  active: listRow.modelData && listRow.modelData.isSni
                  anchors.verticalCenter: parent.verticalCenter
                  sourceComponent: Component {
                    SnItemDelegate {
                      bar: drawerGridRoot.bar
                      modelData: listRow.modelData.modelData
                      onRequestMenu: function(item, target, mouse) {
                        drawerGridRoot.sniMenuRequested(item, target, mouse)
                      }
                    }
                  }
                }

                Text {
                  text: listRow.modelData ? listRow.modelData.title : ""
                  textFormat: Text.PlainText
                  renderType: Text.NativeRendering
                  font.pixelSize: Style.font.bodySmall
                  color: Color.foreground
                  anchors.verticalCenter: parent.verticalCenter
                  elide: Text.ElideRight
                  width: parent.width - 60
                }

                Item {
                  width: 1
                  height: 1
                }

                // Drag handle icon on the right
                Text {
                  text: "\uf0c9" // nf-fa-bars
                  textFormat: Text.PlainText
                  renderType: Text.NativeRendering
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  color: Color.muted
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              // Drag area on row for convenient reordering in list view
              MouseArea {
                id: rowDragArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.SizeVerCursor
                z: -1

                property real pressY: 0
                property bool isRowDragging: false

                onPressed: function(mouse) {
                  pressY = mouse.y
                  isRowDragging = false
                }

                onPositionChanged: function(mouse) {
                  if (!pressed) return
                  if (!isRowDragging) {
                    if (Math.abs(mouse.y - pressY) > 4) {
                      isRowDragging = true
                      var p = drawerGridRoot.mapFromItem(listRow, mouse.x, mouse.y)
                      drawerGridRoot.startDrag(listRow.index, listRow, mouse)
                    }
                  } else {
                    var p2 = drawerGridRoot.mapFromItem(listRow, mouse.x, mouse.y)
                    drawerGridRoot.updateDrag(p2.x, p2.y)
                  }
                }

                onReleased: function(mouse) {
                  if (isRowDragging) {
                    isRowDragging = false
                    drawerGridRoot.endDrag()
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  // Floating drag ghost preview
  Rectangle {
    id: dragGhost
    visible: drawerGridRoot.isDragActive && drawerGridRoot.draggingItem !== null
    width: drawerGridRoot.viewMode === "grid" ? Style.bar.iconSlot + 8 : 160
    height: drawerGridRoot.viewMode === "grid" ? Style.bar.iconSlot + 8 : 32
    radius: Style.cornerRadius
    color: Color.popups.background
    border.color: Color.accent
    border.width: 1.5
    z: 200
    opacity: 0.95
    x: drawerGridRoot.dragCursorX - width / 2
    y: drawerGridRoot.dragCursorY - height / 2

    Text {
      anchors.centerIn: parent
      text: drawerGridRoot.draggingItem ? drawerGridRoot.draggingItem.title : ""
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      color: Color.foreground
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
      width: parent.width - 12
      horizontalAlignment: Text.AlignHCenter
    }
  }
}
