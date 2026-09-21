import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "../TrayModel.js" as TrayModel

Item {
  id: manageRoot

  property var bar: null
  property var currentSettings: ({})
  property var hostedWidgets: []
  property var sniItems: []
  property var pinnedIds: []
  property var hiddenIds: []

  signal closeRequested()
  signal updateSettingsRequested(var newSettings)
  signal togglePinnedWidget(string id)
  signal toggleHiddenWidget(string id)
  signal releaseWidget(string id)
  signal captureWidget(string id)
  signal togglePinnedSni(string id)
  signal toggleHiddenSni(string id)
  signal reorderWidget(int fromIndex, int toIndex)

  function fade(c, amount) {
    var bg = Color.background
    return Qt.rgba(
      c.r + (bg.r - c.r) * amount,
      c.g + (bg.g - c.g) * amount,
      c.b + (bg.b - c.b) * amount,
      1.0
    )
  }

  readonly property color mutedColor: Color.muted
  readonly property color surfaceAlt: Style.normalFill

  property string searchQuery: ""
  property string activeTab: "items" // "items" or "config"
  property real flipAngle: activeTab === "config" ? 180 : 0
  readonly property real flipScale: 1 - 0.16 * Math.abs(Math.sin(flipAngle * Math.PI / 180))

  Behavior on flipAngle {
    NumberAnimation {
      duration: 380
      easing.type: Easing.InOutCubic
    }
  }

  readonly property bool isEditing: searchField.activeFocus
  readonly property int neededHeight: contentColumn.implicitHeight + Style.space(12)

  // Bar widgets currently on any bar section (candidates to be tucked into TidyTray)
  readonly property var candidateBarWidgets: {
    var layout = manageRoot.bar && manageRoot.bar.layoutConfig ? manageRoot.bar.layoutConfig : null
    if (!layout) return []
    var out = []
    var sections = ["right", "center", "left"]
    for (var s = 0; s < sections.length; s++) {
      var entries = layout[sections[s]]
      if (!Array.isArray(entries)) continue
      for (var i = 0; i < entries.length; i++) {
        var id = TrayModel.entryId(entries[i])
        if (!id || id === "io.github.jvlianodorneles.tidytray" || id === "omarchy.tray") continue
        out.push({ id: id, section: sections[s] })
      }
    }
    return out
  }

  implicitWidth: Style.space(380)
  implicitHeight: neededHeight

  Column {
    id: contentColumn
    width: parent ? parent.width : Style.space(380)
    spacing: Style.space(10)

    // Header: Cog + Title on left, Tabs + Close on right
    Item {
      width: parent.width
      height: 28

      Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(8)

        Text {
          text: "\uf013" // nf-fa-cog
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          color: Color.accent
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: "TidyTray"
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.bold: true
          color: Color.foreground
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)

        // Tab switcher: Items vs Settings
        Rectangle {
          width: 58
          height: 26
          radius: Style.cornerRadius
          color: manageRoot.activeTab === "items" ? Color.accent : manageRoot.surfaceAlt

          Text {
            anchors.centerIn: parent
            text: "Items"
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            color: manageRoot.activeTab === "items" ? Color.background : Color.foreground
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: manageRoot.activeTab = "items"
          }
        }

        Rectangle {
          width: 66
          height: 26
          radius: Style.cornerRadius
          color: manageRoot.activeTab === "config" ? Color.accent : manageRoot.surfaceAlt

          Text {
            anchors.centerIn: parent
            text: "Settings"
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            color: manageRoot.activeTab === "config" ? Color.background : Color.foreground
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: manageRoot.activeTab = "config"
          }
        }

        // Close button
        Rectangle {
          width: 26
          height: 26
          radius: Style.cornerRadius
          color: closeMouse.containsMouse ? Color.urgent : manageRoot.surfaceAlt

          Text {
            anchors.centerIn: parent
            text: "\uf00d" // nf-fa-times
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            color: closeMouse.containsMouse ? Color.background : manageRoot.mutedColor
          }

          MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: manageRoot.closeRequested()
          }
        }
      }
    }

    Rectangle {
      width: parent.width
      height: 1
      color: manageRoot.surfaceAlt
    }

    // 3D Perspective Card Flip Body Container
    Item {
      id: flipContainer
      width: parent.width
      implicitHeight: Math.max(itemsTabCol.implicitHeight, configTabCol.implicitHeight)

      transform: [
        Translate { x: -flipContainer.width / 2; y: -flipContainer.height / 2 },
        Scale { xScale: manageRoot.flipScale; yScale: manageRoot.flipScale },
        Rotation {
          axis.x: 0; axis.y: 1; axis.z: 0
          angle: manageRoot.flipAngle
        },
        Matrix4x4 {
          matrix: Qt.matrix4x4(1, 0, 0,       0,
                               0, 1, 0,       0,
                               0, 0, 1,       0,
                               0, 0, -0.0009, 1)
        },
        Translate { x: flipContainer.width / 2; y: flipContainer.height / 2 }
      ]

      // Face 1: TAB 1: ITEMS MANAGEMENT (Front)
      Column {
        id: itemsTabCol
        width: parent.width
        spacing: Style.space(8)
        visible: manageRoot.flipAngle < 90
        enabled: manageRoot.activeTab === "items"

      // Search field
      Rectangle {
        width: parent.width
        height: 32
        radius: Style.cornerRadius
        color: manageRoot.surfaceAlt
        border.color: searchField.activeFocus ? Color.accent : "transparent"
        border.width: 1

        Row {
          anchors.fill: parent
          anchors.leftMargin: 8
          anchors.rightMargin: 8
          spacing: 6

          Text {
            text: "\uf002" // nf-fa-search
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            color: manageRoot.mutedColor
            anchors.verticalCenter: parent.verticalCenter
          }

          TextInput {
            id: searchField
            width: parent.width - 30
            anchors.verticalCenter: parent.verticalCenter
            text: manageRoot.searchQuery
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            maximumLength: 64
            selectByMouse: true
            onTextChanged: manageRoot.searchQuery = text

            Text {
              text: "Search widgets or icons..."
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              color: manageRoot.mutedColor
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              visible: !searchField.text && !searchField.activeFocus
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }
      }

      // Items Scroll Area
      Flickable {
        width: parent.width
        height: Math.min(320, itemsListCol.implicitHeight)
        contentHeight: itemsListCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: itemsListCol
          width: parent.width
          spacing: 4

          // 1. Captured Bar Widgets Section
          Text {
            text: "CAPTURED BAR WIDGETS (" + manageRoot.hostedWidgets.length + ")"
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            color: manageRoot.mutedColor
            visible: manageRoot.hostedWidgets.length > 0
          }

            Repeater {
              model: manageRoot.hostedWidgets
              delegate: Item {
                id: widgetRowWrapper
                required property var modelData
                required property int index
                readonly property string wId: TrayModel.wrapperId(modelData)
                readonly property bool isPinned: manageRoot.pinnedIds.indexOf(wId) !== -1
                readonly property bool isHidden: manageRoot.hiddenIds.indexOf(wId) !== -1
                readonly property bool matchesSearch: !manageRoot.searchQuery ||
                  wId.toLowerCase().indexOf(manageRoot.searchQuery.toLowerCase()) !== -1

                width: itemsListCol.width
                height: matchesSearch ? 36 : 0
                visible: matchesSearch
                z: rowDragArea.drag.active ? 99 : 1

                Rectangle {
                  id: widgetRowDelegate
                  width: parent.width
                  height: 36
                  radius: Style.cornerRadius
                  color: rowDragArea.drag.active ? Color.accent : manageRoot.surfaceAlt
                  opacity: rowDragArea.drag.active ? 0.85 : 1.0

                  Item {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8

                    Row {
                      anchors.left: parent.left
                      anchors.right: widgetActionsRow.left
                      anchors.rightMargin: 8
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: 8

                      // Drag handle icon (bars)
                      Text {
                        text: "\uf0c9" // nf-fa-bars
                        textFormat: Text.PlainText
                        renderType: Text.NativeRendering
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        color: rowDragArea.drag.active ? Color.background : Color.accent
                        anchors.verticalCenter: parent.verticalCenter
                      }

                      Text {
                        text: TrayModel.friendlyDisplayName(widgetRowWrapper.wId)
                        textFormat: Text.PlainText
                        renderType: Text.NativeRendering
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        color: rowDragArea.drag.active ? Color.background : Color.foreground
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 30
                        elide: Text.ElideRight
                      }
                    }

                    // Drag handle MouseArea covering the drag handle & text area
                    MouseArea {
                      id: rowDragArea
                      anchors.left: parent.left
                      anchors.top: parent.top
                      anchors.bottom: parent.bottom
                      anchors.right: widgetActionsRow.left
                      cursorShape: Qt.SizeVerCursor
                      drag.target: widgetRowDelegate
                      drag.axis: Drag.YAxis

                      onReleased: {
                        var dy = widgetRowDelegate.y
                        widgetRowDelegate.y = 0
                        var step = 42
                        var movedSlots = Math.round(dy / step)
                        var targetIdx = Math.max(0, Math.min(manageRoot.hostedWidgets.length - 1, widgetRowWrapper.index + movedSlots))
                        if (targetIdx !== widgetRowWrapper.index) {
                          manageRoot.reorderWidget(widgetRowWrapper.index, targetIdx)
                        }
                      }
                    }

                    // Actions: Move Up / Move Down / Pin / Hide / Eject
                    Row {
                      id: widgetActionsRow
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: 4

                      // Move Up
                      Rectangle {
                        width: 24
                        height: 24
                        radius: 4
                        color: "transparent"
                        border.color: widgetRowWrapper.index > 0 ? manageRoot.mutedColor : "transparent"
                        border.width: widgetRowWrapper.index > 0 ? 1 : 0
                        visible: widgetRowWrapper.index > 0

                        Text {
                          anchors.centerIn: parent
                          text: "\uf077" // chevron-up
                          textFormat: Text.PlainText
                          renderType: Text.NativeRendering
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                          color: manageRoot.mutedColor
                        }
                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          onClicked: manageRoot.reorderWidget(widgetRowWrapper.index, widgetRowWrapper.index - 1)
                        }
                      }

                      // Move Down
                      Rectangle {
                        width: 24
                        height: 24
                        radius: 4
                        color: "transparent"
                        border.color: widgetRowWrapper.index < manageRoot.hostedWidgets.length - 1 ? manageRoot.mutedColor : "transparent"
                        border.width: widgetRowWrapper.index < manageRoot.hostedWidgets.length - 1 ? 1 : 0
                        visible: widgetRowWrapper.index < manageRoot.hostedWidgets.length - 1

                        Text {
                          anchors.centerIn: parent
                          text: "\uf078" // chevron-down
                          textFormat: Text.PlainText
                          renderType: Text.NativeRendering
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                          color: manageRoot.mutedColor
                        }
                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          onClicked: manageRoot.reorderWidget(widgetRowWrapper.index, widgetRowWrapper.index + 1)
                        }
                      }

                      // Pin toggle
                      Rectangle {
                        width: 24
                        height: 24
                        radius: 4
                        color: widgetRowWrapper.isPinned ? Color.accent : "transparent"
                        border.color: widgetRowWrapper.isPinned ? Color.accent : manageRoot.mutedColor
                        border.width: widgetRowWrapper.isPinned ? 0 : 1

                        Text {
                          anchors.centerIn: parent
                          text: "\uf08d" // nf-fa-thumb_tack
                          textFormat: Text.PlainText
                          renderType: Text.NativeRendering
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                          color: widgetRowWrapper.isPinned ? Color.background : manageRoot.mutedColor
                        }
                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          onClicked: manageRoot.togglePinnedWidget(widgetRowWrapper.wId)
                        }
                      }

                      // Hide toggle
                      Rectangle {
                        width: 24
                        height: 24
                        radius: 4
                        color: widgetRowWrapper.isHidden ? Color.urgent : "transparent"
                        border.color: widgetRowWrapper.isHidden ? Color.urgent : manageRoot.mutedColor
                        border.width: widgetRowWrapper.isHidden ? 0 : 1

                        Text {
                          anchors.centerIn: parent
                          text: widgetRowWrapper.isHidden ? "\uf070" : "\uf06e" // eye-slash / eye
                          textFormat: Text.PlainText
                          renderType: Text.NativeRendering
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                          color: widgetRowWrapper.isHidden ? Color.background : manageRoot.mutedColor
                        }
                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          onClicked: manageRoot.toggleHiddenWidget(widgetRowWrapper.wId)
                        }
                      }

                      // Eject back to bar
                      Rectangle {
                        width: 24
                        height: 24
                        radius: 4
                        color: "transparent"
                        border.color: manageRoot.mutedColor
                        border.width: 1

                        Text {
                          anchors.centerIn: parent
                          text: "\uf08b" // nf-fa-sign_out
                          textFormat: Text.PlainText
                          renderType: Text.NativeRendering
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                          color: manageRoot.mutedColor
                        }
                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          onClicked: manageRoot.releaseWidget(widgetRowWrapper.wId)
                        }
                      }
                    }
                  }
                }
              }
            }

          Item { width: 1; height: 6 }

          // 2. Candidate Widgets currently on the Bar
          Text {
            text: "WIDGETS ON THE BAR (CLICK + TO TUCK INTO TRAY)"
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            color: manageRoot.mutedColor
            visible: manageRoot.candidateBarWidgets.length > 0
          }

          Repeater {
            model: manageRoot.candidateBarWidgets
            delegate: Rectangle {
              id: candidateRowDelegate
              required property var modelData
              readonly property string cId: String(modelData.id || "")
              readonly property bool matchesSearch: !manageRoot.searchQuery ||
                cId.toLowerCase().indexOf(manageRoot.searchQuery.toLowerCase()) !== -1

              width: itemsListCol.width
              height: 36
              radius: Style.cornerRadius
              color: manageRoot.surfaceAlt
              visible: matchesSearch

              Item {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8

                Row {
                  anchors.left: parent.left
                  anchors.right: candidateActionBtn.left
                  anchors.rightMargin: 8
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: 8

                  Text {
                    text: "\uf0c9" // nf-fa-bars
                    textFormat: Text.PlainText
                    renderType: Text.NativeRendering
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    color: manageRoot.mutedColor
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    text: TrayModel.friendlyDisplayName(candidateRowDelegate.cId)
                    textFormat: Text.PlainText
                    renderType: Text.NativeRendering
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    color: Color.foreground
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 30
                    elide: Text.ElideRight
                  }
                }

                // Action: Move to Tray
                Rectangle {
                  id: candidateActionBtn
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  width: 24
                  height: 24
                  radius: 4
                  color: Color.accent

                  Text {
                    anchors.centerIn: parent
                    text: "\uf067" // nf-fa-plus
                    textFormat: Text.PlainText
                    renderType: Text.NativeRendering
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    color: Color.background
                  }
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: manageRoot.captureWidget(candidateRowDelegate.cId)
                  }
                }
              }
            }
          }

          Item { width: 1; height: 6 }

          // 3. SNI Items Section
          Text {
            text: "SYSTEM TRAY ICONS (SNI) (" + manageRoot.sniItems.length + ")"
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            color: manageRoot.mutedColor
            visible: manageRoot.sniItems.length > 0
          }

          Repeater {
            model: manageRoot.sniItems
            delegate: Rectangle {
              id: sniRowDelegate
              required property var modelData
              readonly property string sId: String(modelData.id || "")
              readonly property bool isPinned: manageRoot.pinnedIds.indexOf(sId) !== -1
              readonly property bool isHidden: manageRoot.hiddenIds.indexOf(sId) !== -1
              readonly property bool matchesSearch: !manageRoot.searchQuery ||
                sId.toLowerCase().indexOf(manageRoot.searchQuery.toLowerCase()) !== -1 ||
                String(modelData.title || "").toLowerCase().indexOf(manageRoot.searchQuery.toLowerCase()) !== -1

              width: itemsListCol.width
              height: 36
              radius: Style.cornerRadius
              color: manageRoot.surfaceAlt
              visible: matchesSearch

              Item {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8

                Row {
                  anchors.left: parent.left
                  anchors.right: sniActionsRow.left
                  anchors.rightMargin: 8
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: 8

                  Image {
                    id: sniIconImg
                    width: 18
                    height: 18
                    anchors.verticalCenter: parent.verticalCenter
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 36
                    sourceSize.height: 36
                    source: String(modelData.icon || "")
                    visible: source !== "" && status === Image.Ready
                  }

                  Text {
                    text: "\uf2d0" // nf-fa-window_maximize fallback
                    textFormat: Text.PlainText
                    renderType: Text.NativeRendering
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    color: Color.accent
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !sniIconImg.visible
                  }

                  Text {
                    text: modelData.title || TrayModel.friendlyDisplayName(sniRowDelegate.sId)
                    textFormat: Text.PlainText
                    renderType: Text.NativeRendering
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    color: Color.foreground
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 30
                    elide: Text.ElideRight
                  }
                }

                // Actions: Pin / Hide
                Row {
                  id: sniActionsRow
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: 4

                  // Pin toggle
                  Rectangle {
                    width: 24
                    height: 24
                    radius: 4
                    color: sniRowDelegate.isPinned ? Color.accent : "transparent"
                    border.color: sniRowDelegate.isPinned ? Color.accent : manageRoot.mutedColor
                    border.width: sniRowDelegate.isPinned ? 0 : 1

                    Text {
                      anchors.centerIn: parent
                      text: "\uf08d" // nf-fa-thumb_tack
                      textFormat: Text.PlainText
                      renderType: Text.NativeRendering
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      color: sniRowDelegate.isPinned ? Color.background : manageRoot.mutedColor
                    }
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: manageRoot.togglePinnedSni(sniRowDelegate.sId)
                    }
                  }

                  // Hide toggle
                  Rectangle {
                    width: 24
                    height: 24
                    radius: 4
                    color: sniRowDelegate.isHidden ? Color.urgent : "transparent"
                    border.color: sniRowDelegate.isHidden ? Color.urgent : manageRoot.mutedColor
                    border.width: sniRowDelegate.isHidden ? 0 : 1

                    Text {
                      anchors.centerIn: parent
                      text: sniRowDelegate.isHidden ? "\uf070" : "\uf06e" // eye-slash / eye
                      textFormat: Text.PlainText
                      renderType: Text.NativeRendering
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      color: sniRowDelegate.isHidden ? Color.background : manageRoot.mutedColor
                    }
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: manageRoot.toggleHiddenSni(sniRowDelegate.sId)
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

      // Face 2: TAB 2: CONFIGURATION (Back)
      Column {
        id: configTabCol
        width: parent.width
        spacing: Style.space(10)
        visible: manageRoot.flipAngle >= 90
        enabled: manageRoot.activeTab === "config"
        transform: [
          Translate { x: -configTabCol.width / 2; y: -configTabCol.height / 2 },
          Rotation {
            axis.x: 0; axis.y: 1; axis.z: 0
            angle: 180
          },
          Translate { x: configTabCol.width / 2; y: configTabCol.height / 2 }
        ]

      // 1. Display Mode
      Text {
        text: "DISPLAY MODE"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        color: manageRoot.mutedColor
      }

      Row {
        id: modesRow
        width: parent.width
        spacing: 4

        readonly property var modes: ["inline", "dropdown", "drawer"]
        readonly property var modeLabels: ["Inline", "Dropdown", "Drawer"]

        Repeater {
          model: 3
          Rectangle {
            id: modeItemRect
            required property int index
            readonly property string mName: modesRow.modes[index]
            readonly property bool isSelected: (manageRoot.currentSettings.displayMode || "inline") === mName

            width: (contentColumn.width - 8) / 3
            height: 28
            radius: Style.cornerRadius
            color: isSelected ? Color.accent : manageRoot.surfaceAlt

            Text {
              anchors.centerIn: parent
              text: modesRow.modeLabels[modeItemRect.index]
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              color: modeItemRect.isSelected ? Color.background : Color.foreground
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                var copy = Object.assign({}, manageRoot.currentSettings)
                copy.displayMode = modeItemRect.mName
                manageRoot.updateSettingsRequested(copy)
              }
            }
          }
        }
      }

      // 2. Trigger Mode
      Text {
        text: "OPEN TRIGGER"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        color: manageRoot.mutedColor
      }

      Row {
        width: parent.width
        spacing: 6

        Rectangle {
          id: triggerClickRect
          width: (contentColumn.width - 6) / 2
          height: 28
          radius: Style.cornerRadius
          readonly property bool isSelected: (manageRoot.currentSettings.trigger || "click") === "click"
          color: isSelected ? Color.accent : manageRoot.surfaceAlt

          Text {
            anchors.centerIn: parent
            text: "On Click"
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            color: parent.isSelected ? Color.background : Color.foreground
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              var copy = Object.assign({}, manageRoot.currentSettings)
              copy.trigger = "click"
              manageRoot.updateSettingsRequested(copy)
            }
          }
        }

        Rectangle {
          id: triggerHoverRect
          width: (contentColumn.width - 6) / 2
          height: 28
          radius: Style.cornerRadius
          readonly property bool isSelected: manageRoot.currentSettings.trigger === "hover"
          color: isSelected ? Color.accent : manageRoot.surfaceAlt

          Text {
            anchors.centerIn: parent
            text: "On Hover"
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            color: parent.isSelected ? Color.background : Color.foreground
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              var copy = Object.assign({}, manageRoot.currentSettings)
              copy.trigger = "hover"
              manageRoot.updateSettingsRequested(copy)
            }
          }
        }
      }

      // 3. Indicator Icon
      Text {
        text: "INDICATOR ICON"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        color: manageRoot.mutedColor
      }

      Row {
        id: iconsRow
        width: parent.width
        spacing: 4

        readonly property var icons: ["chevron", "dot", "dots", "plus"]
        readonly property var iconLabels: ["Chevron", "Dot", "Dots", "Plus"]

        Repeater {
          model: 4
          Rectangle {
            id: iconItemRect
            required property int index
            readonly property string iName: iconsRow.icons[index]
            readonly property bool isSelected: (manageRoot.currentSettings.indicatorIcon || "chevron") === iName

            width: (contentColumn.width - 12) / 4
            height: 28
            radius: Style.cornerRadius
            color: isSelected ? Color.accent : manageRoot.surfaceAlt

            Text {
              anchors.centerIn: parent
              text: iconsRow.iconLabels[iconItemRect.index]
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: iconItemRect.isSelected ? Color.background : Color.foreground
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                var copy = Object.assign({}, manageRoot.currentSettings)
                copy.indicatorIcon = iconItemRect.iName
                manageRoot.updateSettingsRequested(copy)
              }
            }
          }
        }
      }

      // 4. Auto-Hide Timeout
      Text {
        text: "AUTO-HIDE TIMEOUT"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        color: manageRoot.mutedColor
      }

      Row {
        width: parent.width
        spacing: 10

        PanelSlider {
          id: rehideSlider
          width: parent.width - 64
          anchors.verticalCenter: parent.verticalCenter
          bar: manageRoot.bar
          minimum: 0
          maximum: 60
          step: 5
          integer: true
          value: manageRoot.currentSettings.rehideSeconds !== undefined ? Number(manageRoot.currentSettings.rehideSeconds) : 0
          onReleased: function(v) {
            var copy = Object.assign({}, manageRoot.currentSettings)
            copy.rehideSeconds = Math.round(v)
            manageRoot.updateSettingsRequested(copy)
          }
        }

        Text {
          width: 54
          anchors.verticalCenter: parent.verticalCenter
          text: Math.round(rehideSlider.liveValue) === 0 ? "Off" : (Math.round(rehideSlider.liveValue) + "s")
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          color: Color.foreground
          horizontalAlignment: Text.AlignRight
        }
      }

      // 5. Deduplication
      Row {
        width: parent.width
        spacing: 8

        Rectangle {
          id: dedupCheckbox
          width: 20
          height: 20
          radius: 4
          readonly property bool checked: manageRoot.currentSettings.deduplicateKnown !== false
          color: checked ? Color.accent : manageRoot.surfaceAlt
          border.color: manageRoot.mutedColor
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: "\uf00c" // nf-fa-check
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            color: Color.background
            visible: parent.checked
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              var copy = Object.assign({}, manageRoot.currentSettings)
              copy.deduplicateKnown = !dedupCheckbox.checked
              manageRoot.updateSettingsRequested(copy)
            }
          }
        }

        Text {
          text: "Deduplicate apps with native widget (e.g. Dropbox)"
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          color: Color.foreground
          anchors.verticalCenter: parent.verticalCenter
        }
      }
    }
  }
}
}
