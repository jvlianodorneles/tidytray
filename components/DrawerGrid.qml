import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "../TrayModel.js" as TrayModel

Item {
  id: drawerGridRoot

  property var bar: null
  property var hostedWidgets: []
  property var sniItems: []
  property string searchQuery: ""
  property string viewMode: "grid" // "grid" or "list"

  signal openSettingsRequested()
  signal sniActivated(var item)
  signal sniMenuRequested(var item, var target, var mouse)

  readonly property bool isEditing: searchInput.activeFocus
  readonly property int neededHeight: drawerColumn.implicitHeight + Style.space(16)

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
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: drawerGridRoot.viewMode = (drawerGridRoot.viewMode === "grid" ? "list" : "grid")
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
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: drawerGridRoot.openSettingsRequested()
        }
      }
    }

    // Main Content Area: Flow for Grid or Column for List
    Flickable {
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
          visible: drawerGridRoot.hostedWidgets.length === 0 && drawerGridRoot.sniItems.length === 0
        }

        // 1. GRID VIEW
        Flow {
          id: flowView
          width: parent.width
          spacing: Style.space(8)
          visible: drawerGridRoot.viewMode === "grid"

          // Hosted Widgets
          Repeater {
            model: drawerGridRoot.hostedWidgets
            delegate: Item {
              id: gridTile
              required property var modelData
              readonly property string wId: TrayModel.wrapperId(modelData)
              readonly property bool matches: !drawerGridRoot.searchQuery ||
                wId.toLowerCase().indexOf(drawerGridRoot.searchQuery.toLowerCase()) !== -1

              visible: matches
              width: Math.max(Style.bar.iconSlot, hostedWidget.implicitWidth)
              height: Math.max(Style.bar.iconSlot, hostedWidget.implicitHeight)

              HostedWidget {
                id: hostedWidget
                bar: drawerGridRoot.bar
                modelData: gridTile.modelData
                anchors.centerIn: parent
              }
            }
          }

          // SNI Items
          Repeater {
            model: drawerGridRoot.sniItems
            delegate: Item {
              id: sniTile
              required property var modelData
              readonly property string sId: String(modelData.id || "")
              readonly property bool matches: !drawerGridRoot.searchQuery ||
                sId.toLowerCase().indexOf(drawerGridRoot.searchQuery.toLowerCase()) !== -1 ||
                String(modelData.title || "").toLowerCase().indexOf(drawerGridRoot.searchQuery.toLowerCase()) !== -1

              visible: matches
              width: Style.bar.iconSlot
              height: Style.bar.iconSlot

              SnItemDelegate {
                id: snItem
                bar: drawerGridRoot.bar
                modelData: sniTile.modelData
                anchors.centerIn: parent
                onRequestMenu: function(item, target, mouse) {
                  drawerGridRoot.sniMenuRequested(item, target, mouse)
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

          // Hosted Widgets
          Repeater {
            model: drawerGridRoot.hostedWidgets
            delegate: Rectangle {
              id: hostedListRow
              required property var modelData
              readonly property string wId: TrayModel.wrapperId(modelData)
              readonly property bool matches: !drawerGridRoot.searchQuery ||
                wId.toLowerCase().indexOf(drawerGridRoot.searchQuery.toLowerCase()) !== -1

              visible: matches
              width: listViewCol.width
              height: 36
              radius: Style.cornerRadius
              color: Style.hoverFill

              Row {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                HostedWidget {
                  bar: drawerGridRoot.bar
                  modelData: hostedListRow.modelData
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  text: TrayModel.friendlyDisplayName(hostedListRow.wId)
                  textFormat: Text.PlainText
                  renderType: Text.NativeRendering
                  font.pixelSize: Style.font.bodySmall
                  color: Color.foreground
                  anchors.verticalCenter: parent.verticalCenter
                  elide: Text.ElideRight
                }
              }
            }
          }

          // SNI Items
          Repeater {
            model: drawerGridRoot.sniItems
            delegate: Rectangle {
              id: sniListRow
              required property var modelData
              readonly property string sId: String(modelData.id || "")
              readonly property bool matches: !drawerGridRoot.searchQuery ||
                sId.toLowerCase().indexOf(drawerGridRoot.searchQuery.toLowerCase()) !== -1 ||
                String(modelData.title || "").toLowerCase().indexOf(drawerGridRoot.searchQuery.toLowerCase()) !== -1

              visible: matches
              width: listViewCol.width
              height: 36
              radius: Style.cornerRadius
              color: Style.hoverFill

              Row {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                SnItemDelegate {
                  bar: drawerGridRoot.bar
                  modelData: sniListRow.modelData
                  anchors.verticalCenter: parent.verticalCenter
                  onRequestMenu: function(item, target, mouse) {
                    drawerGridRoot.sniMenuRequested(item, target, mouse)
                  }
                }

                Text {
                  text: sniListRow.modelData.title || TrayModel.friendlyDisplayName(sniListRow.sId)
                  textFormat: Text.PlainText
                  renderType: Text.NativeRendering
                  font.pixelSize: Style.font.bodySmall
                  color: Color.foreground
                  anchors.verticalCenter: parent.verticalCenter
                  elide: Text.ElideRight
                }
              }
            }
          }
        }
      }
    }
  }
}
