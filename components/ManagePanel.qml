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
  signal togglePinnedSni(string id)
  signal toggleHiddenSni(string id)

  readonly property bool lightTheme: {
    var bg = Color.background
    return (0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b) > 0.5
  }

  function fade(c, amount) {
    var bg = Color.background
    return Qt.rgba(
      c.r + (bg.r - c.r) * amount,
      c.g + (bg.g - c.g) * amount,
      c.b + (bg.b - c.b) * amount,
      1.0
    )
  }

  readonly property color mutedColor: fade(Color.foreground, 0.45)
  readonly property color surfaceAlt: fade(Color.background, 0.08)

  property string searchQuery: ""
  property string activeTab: "items" // "items" or "config"

  implicitWidth: Style.space(380)
  implicitHeight: contentColumn.implicitHeight + Style.space(16)

  Column {
    id: contentColumn
    anchors.fill: parent
    spacing: Style.space(10)

    // Header
    Row {
      width: parent.width
      spacing: Style.space(8)

      Text {
        text: "\uf013" // nf-fa-cog
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: Style.fontFace.icon
        font.pixelSize: Style.fontSize.large
        color: Color.accent
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        text: "TidyTray"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: Style.fontFace.title
        font.pixelSize: Style.fontSize.large
        font.bold: true
        color: Color.foreground
        anchors.verticalCenter: parent.verticalCenter
      }

      Item {
        width: parent.width - 240
        height: 1
      }

      // Tab switcher: Items vs Config
      Row {
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
          width: 60
          height: 26
          radius: Style.radius.small
          color: manageRoot.activeTab === "items" ? Color.accent : manageRoot.surfaceAlt
          Text {
            anchors.centerIn: parent
            text: "Items"
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.pixelSize: Style.fontSize.small
            color: manageRoot.activeTab === "items" ? Color.background : Color.foreground
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: manageRoot.activeTab = "items"
          }
        }

        Rectangle {
          width: 60
          height: 26
          radius: Style.radius.small
          color: manageRoot.activeTab === "config" ? Color.accent : manageRoot.surfaceAlt
          Text {
            anchors.centerIn: parent
            text: "Settings"
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.pixelSize: Style.fontSize.small
            color: manageRoot.activeTab === "config" ? Color.background : Color.foreground
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: manageRoot.activeTab = "config"
          }
        }
      }

      // Close button
      Rectangle {
        width: 26
        height: 26
        radius: Style.radius.small
        color: closeMouse.containsMouse ? Color.urgent : "transparent"
        anchors.verticalCenter: parent.verticalCenter

        Text {
          anchors.centerIn: parent
          text: "\uf00d" // nf-fa-times
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: Style.fontFace.icon
          font.pixelSize: Style.fontSize.small
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

    Rectangle {
      width: parent.width
      height: 1
      color: manageRoot.surfaceAlt
    }

    // TAB 1: ITEMS MANAGEMENT
    Column {
      width: parent.width
      spacing: Style.space(8)
      visible: manageRoot.activeTab === "items"

      // Search field
      Rectangle {
        width: parent.width
        height: 32
        radius: Style.radius.small
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
            font.family: Style.fontFace.icon
            font.pixelSize: Style.fontSize.small
            color: manageRoot.mutedColor
            anchors.verticalCenter: parent.verticalCenter
          }

          TextInput {
            id: searchField
            width: parent.width - 30
            anchors.verticalCenter: parent.verticalCenter
            text: manageRoot.searchQuery
            color: Color.foreground
            font.pixelSize: Style.fontSize.small
            maximumLength: 64
            selectByMouse: true
            onTextChanged: manageRoot.searchQuery = text

            Text {
              text: "Search widgets or icons..."
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              color: manageRoot.mutedColor
              font.pixelSize: Style.fontSize.small
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

        Column {
          id: itemsListCol
          width: parent.width
          spacing: 4

          // 1. Hosted Widgets Section
          Text {
            text: "CAPTURED BAR WIDGETS (" + manageRoot.hostedWidgets.length + ")"
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.pixelSize: Style.fontSize.tiny
            font.bold: true
            color: manageRoot.mutedColor
            visible: manageRoot.hostedWidgets.length > 0
          }

          Repeater {
            model: manageRoot.hostedWidgets
            delegate: Rectangle {
              required property var modelData
              readonly property string wId: TrayModel.wrapperId(modelData)
              readonly property bool isPinned: manageRoot.pinnedIds.indexOf(wId) !== -1
              readonly property bool isHidden: manageRoot.hiddenIds.indexOf(wId) !== -1
              readonly property bool matchesSearch: !manageRoot.searchQuery ||
                wId.toLowerCase().indexOf(manageRoot.searchQuery.toLowerCase()) !== -1

              width: itemsListCol.width
              height: 36
              radius: Style.radius.small
              color: manageRoot.surfaceAlt
              visible: matchesSearch

              Row {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                Text {
                  text: "\uf009" // nf-fa-th_large
                  textFormat: Text.PlainText
                  renderType: Text.NativeRendering
                  font.family: Style.fontFace.icon
                  font.pixelSize: Style.fontSize.small
                  color: Color.accent
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  text: TrayModel.friendlyDisplayName(parent.parent.wId)
                  textFormat: Text.PlainText
                  renderType: Text.NativeRendering
                  font.pixelSize: Style.fontSize.small
                  color: Color.foreground
                  anchors.verticalCenter: parent.verticalCenter
                  width: 140
                  elide: Text.ElideRight
                }

                Item { width: 10; height: 1 }

                // Actions: Pin / Hide / Eject
                Row {
                  spacing: 4
                  anchors.verticalCenter: parent.verticalCenter

                  // Pin toggle
                  Rectangle {
                    width: 24
                    height: 24
                    radius: 4
                    color: parent.parent.parent.isPinned ? Color.accent : "transparent"
                    Text {
                      anchors.centerIn: parent
                      text: "\uf08d" // nf-fa-thumb_tack
                      textFormat: Text.PlainText
                      renderType: Text.NativeRendering
                      font.family: Style.fontFace.icon
                      font.pixelSize: Style.fontSize.tiny
                      color: parent.parent.parent.parent.isPinned ? Color.background : manageRoot.mutedColor
                    }
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: manageRoot.togglePinnedWidget(parent.parent.parent.wId)
                    }
                  }

                  // Hide toggle
                  Rectangle {
                    width: 24
                    height: 24
                    radius: 4
                    color: parent.parent.parent.isHidden ? Color.urgent : "transparent"
                    Text {
                      anchors.centerIn: parent
                      text: parent.parent.parent.parent.isHidden ? "\uf070" : "\uf06e" // eye-slash / eye
                      textFormat: Text.PlainText
                      renderType: Text.NativeRendering
                      font.family: Style.fontFace.icon
                      font.pixelSize: Style.fontSize.tiny
                      color: parent.parent.parent.parent.isHidden ? Color.background : manageRoot.mutedColor
                    }
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: manageRoot.toggleHiddenWidget(parent.parent.parent.wId)
                    }
                  }

                  // Eject back to bar
                  Rectangle {
                    width: 24
                    height: 24
                    radius: 4
                    color: "transparent"
                    Text {
                      anchors.centerIn: parent
                      text: "\uf08b" // nf-fa-sign_out
                      textFormat: Text.PlainText
                      renderType: Text.NativeRendering
                      font.family: Style.fontFace.icon
                      font.pixelSize: Style.fontSize.tiny
                      color: manageRoot.mutedColor
                    }
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: manageRoot.releaseWidget(parent.parent.parent.wId)
                    }
                  }
                }
              }
            }
          }

          Item { width: 1; height: 6 }

          // 2. SNI Items Section
          Text {
            text: "SYSTEM TRAY ICONS (SNI) (" + manageRoot.sniItems.length + ")"
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.pixelSize: Style.fontSize.tiny
            font.bold: true
            color: manageRoot.mutedColor
            visible: manageRoot.sniItems.length > 0
          }

          Repeater {
            model: manageRoot.sniItems
            delegate: Rectangle {
              required property var modelData
              readonly property string sId: String(modelData.id || "")
              readonly property bool isPinned: manageRoot.pinnedIds.indexOf(sId) !== -1
              readonly property bool isHidden: manageRoot.hiddenIds.indexOf(sId) !== -1
              readonly property bool matchesSearch: !manageRoot.searchQuery ||
                sId.toLowerCase().indexOf(manageRoot.searchQuery.toLowerCase()) !== -1 ||
                String(modelData.title || "").toLowerCase().indexOf(manageRoot.searchQuery.toLowerCase()) !== -1

              width: itemsListCol.width
              height: 36
              radius: Style.radius.small
              color: manageRoot.surfaceAlt
              visible: matchesSearch

              Row {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                Text {
                  text: "\uf2d0" // nf-fa-window_maximize
                  textFormat: Text.PlainText
                  renderType: Text.NativeRendering
                  font.family: Style.fontFace.icon
                  font.pixelSize: Style.fontSize.small
                  color: Color.accent
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  text: modelData.title || TrayModel.friendlyDisplayName(parent.parent.sId)
                  textFormat: Text.PlainText
                  renderType: Text.NativeRendering
                  font.pixelSize: Style.fontSize.small
                  color: Color.foreground
                  anchors.verticalCenter: parent.verticalCenter
                  width: 140
                  elide: Text.ElideRight
                }

                Item { width: 10; height: 1 }

                // Actions: Pin / Hide
                Row {
                  spacing: 4
                  anchors.verticalCenter: parent.verticalCenter

                  // Pin toggle
                  Rectangle {
                    width: 24
                    height: 24
                    radius: 4
                    color: parent.parent.parent.isPinned ? Color.accent : "transparent"
                    Text {
                      anchors.centerIn: parent
                      text: "\uf08d" // nf-fa-thumb_tack
                      textFormat: Text.PlainText
                      renderType: Text.NativeRendering
                      font.family: Style.fontFace.icon
                      font.pixelSize: Style.fontSize.tiny
                      color: parent.parent.parent.parent.isPinned ? Color.background : manageRoot.mutedColor
                    }
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: manageRoot.togglePinnedSni(parent.parent.parent.sId)
                    }
                  }

                  // Hide toggle
                  Rectangle {
                    width: 24
                    height: 24
                    radius: 4
                    color: parent.parent.parent.isHidden ? Color.urgent : "transparent"
                    Text {
                      anchors.centerIn: parent
                      text: parent.parent.parent.parent.isHidden ? "\uf070" : "\uf06e" // eye-slash / eye
                      textFormat: Text.PlainText
                      renderType: Text.NativeRendering
                      font.family: Style.fontFace.icon
                      font.pixelSize: Style.fontSize.tiny
                      color: parent.parent.parent.parent.isHidden ? Color.background : manageRoot.mutedColor
                    }
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: manageRoot.toggleHiddenSni(parent.parent.parent.sId)
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    // TAB 2: CONFIGURATION
    Column {
      width: parent.width
      spacing: Style.space(10)
      visible: manageRoot.activeTab === "config"

      // 1. Display Mode
      Text {
        text: "DISPLAY MODE"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.pixelSize: Style.fontSize.tiny
        font.bold: true
        color: manageRoot.mutedColor
      }

      Row {
        width: parent.width
        spacing: 4

        readonly property var modes: ["inline", "dropdown", "drawer", "flat"]
        readonly property var modeLabels: ["Inline", "Dropdown", "Drawer", "Flat"]

        Repeater {
          model: 4
          Rectangle {
            required property int index
            readonly property string mName: parent.modes[index]
            readonly property bool isSelected: (manageRoot.currentSettings.displayMode || "inline") === mName

            width: (contentColumn.width - 12) / 4
            height: 28
            radius: Style.radius.small
            color: isSelected ? Color.accent : manageRoot.surfaceAlt

            Text {
              anchors.centerIn: parent
              text: parent.parent.modeLabels[parent.index]
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.pixelSize: Style.fontSize.small
              color: parent.isSelected ? Color.background : Color.foreground
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                var copy = Object.assign({}, manageRoot.currentSettings)
                copy.displayMode = parent.mName
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
        font.pixelSize: Style.fontSize.tiny
        font.bold: true
        color: manageRoot.mutedColor
      }

      Row {
        width: parent.width
        spacing: 6

        Rectangle {
          width: (contentColumn.width - 6) / 2
          height: 28
          radius: Style.radius.small
          readonly property bool isSelected: (manageRoot.currentSettings.trigger || "click") === "click"
          color: isSelected ? Color.accent : manageRoot.surfaceAlt

          Text {
            anchors.centerIn: parent
            text: "On Click"
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.pixelSize: Style.fontSize.small
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
          width: (contentColumn.width - 6) / 2
          height: 28
          radius: Style.radius.small
          readonly property bool isSelected: manageRoot.currentSettings.trigger === "hover"
          color: isSelected ? Color.accent : manageRoot.surfaceAlt

          Text {
            anchors.centerIn: parent
            text: "On Hover"
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.pixelSize: Style.fontSize.small
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
        font.pixelSize: Style.fontSize.tiny
        font.bold: true
        color: manageRoot.mutedColor
      }

      Row {
        width: parent.width
        spacing: 4

        readonly property var icons: ["chevron", "dot", "dots", "plus", "none"]
        readonly property var iconLabels: ["Chevron", "Dot", "Dots", "Plus", "None"]

        Repeater {
          model: 5
          Rectangle {
            required property int index
            readonly property string iName: parent.icons[index]
            readonly property bool isSelected: (manageRoot.currentSettings.indicatorIcon || "chevron") === iName

            width: (contentColumn.width - 16) / 5
            height: 28
            radius: Style.radius.small
            color: isSelected ? Color.accent : manageRoot.surfaceAlt

            Text {
              anchors.centerIn: parent
              text: parent.parent.iconLabels[parent.index]
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.pixelSize: Style.fontSize.tiny
              color: parent.isSelected ? Color.background : Color.foreground
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                var copy = Object.assign({}, manageRoot.currentSettings)
                copy.indicatorIcon = parent.iName
                manageRoot.updateSettingsRequested(copy)
              }
            }
          }
        }
      }

      // 4. Deduplication
      Row {
        width: parent.width
        spacing: 8

        Rectangle {
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
            font.family: Style.fontFace.icon
            font.pixelSize: Style.fontSize.tiny
            color: Color.background
            visible: parent.checked
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              var copy = Object.assign({}, manageRoot.currentSettings)
              copy.deduplicateKnown = !parent.checked
              manageRoot.updateSettingsRequested(copy)
            }
          }
        }

        Text {
          text: "Deduplicate apps with native widget (e.g. Dropbox)"
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.pixelSize: Style.fontSize.small
          color: Color.foreground
          anchors.verticalCenter: parent.verticalCenter
        }
      }
    }
  }
}
