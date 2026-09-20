import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs.Commons
import qs.Ui
import "TrayModel.js" as TrayModel
import "components"

BarWidget {
  id: root
  moduleName: "io.github.jvlianodorneles.tidytray"

  // ---------------------------------------------------------------------------
  // Settings & Properties
  // ---------------------------------------------------------------------------
  readonly property var activeSettings: {
    var s = root.settings
    return (s && typeof s === "object") ? s : ({})
  }

  readonly property string displayMode: TrayModel.normalizeDisplayMode(activeSettings.displayMode)
  readonly property string triggerMode: TrayModel.normalizeTrigger(activeSettings.trigger)
  readonly property string indicatorIcon: TrayModel.normalizeIndicatorIcon(activeSettings.indicatorIcon)
  readonly property int rehideSeconds: TrayModel.normalizeRehideSeconds(activeSettings.rehideSeconds)
  readonly property int revealDuration: TrayModel.normalizeDuration(activeSettings.revealDuration, 200)
  readonly property bool deduplicateKnown: activeSettings.deduplicateKnown !== false

  readonly property var pinnedIds: TrayModel.normalizeIdList(activeSettings.pinned)
  readonly property var hiddenIds: TrayModel.normalizeIdList(activeSettings.hidden)
  readonly property var configuredWidgets: TrayModel.normalizeWrappers(activeSettings.widgets)

  property bool expanded: false
  property bool manageOpen: false
  property bool flipToManage: false
  property real flipAngle: 0

  readonly property bool vertical: root.bar ? root.bar.vertical : false
  readonly property int barSize: root.bar ? root.bar.barSize : Style.bar.sizeHorizontal

  // ---------------------------------------------------------------------------
  // Items & Models
  // ---------------------------------------------------------------------------
  readonly property var allSniItems: SystemTray.items ? SystemTray.items.values : []
  readonly property var barLayout: root.bar && root.bar.layoutConfig ? root.bar.layoutConfig : null

  // Hosted widget IDs currently present in TidyTray
  readonly property var hostedWidgetIds: {
    var out = []
    for (var i = 0; i < configuredWidgets.length; i++) {
      var id = TrayModel.wrapperId(configuredWidgets[i])
      if (id) out.push(id)
    }
    return out
  }

  // Filtered SNI items
  readonly property var pinnedSniItems: TrayModel.filterSniItems(
    allSniItems, pinnedIds, hiddenIds, "pinned", deduplicateKnown, barLayout, hostedWidgetIds
  )
  readonly property var drawerSniItems: TrayModel.filterSniItems(
    allSniItems, pinnedIds, hiddenIds, "drawer", deduplicateKnown, barLayout, hostedWidgetIds
  )

  // Filtered hosted widgets
  readonly property var pinnedHostedWidgets: TrayModel.filterHostedWidgets(
    configuredWidgets, pinnedIds, hiddenIds, "pinned"
  )
  readonly property var drawerHostedWidgets: TrayModel.filterHostedWidgets(
    configuredWidgets, pinnedIds, hiddenIds, "drawer"
  )

  readonly property int drawerCount: drawerSniItems.length + drawerHostedWidgets.length
  readonly property bool hasDrawerContent: drawerCount > 0

  // Indicator button visibility:
  // In flat mode, or if drawer is empty, hide indicator unless user configured otherwise
  readonly property bool showIndicator: {
    if (indicatorIcon === "none") return false
    if (displayMode === "flat") return false
    return hasDrawerContent
  }

  // ---------------------------------------------------------------------------
  // Sizing (Deterministic optical sizing without cyclic loops)
  // ---------------------------------------------------------------------------
  readonly property int inlineContentExtent: {
    if (displayMode === "flat" || (displayMode === "inline" && expanded)) {
      return vertical ? inlineContentRow.implicitHeight : inlineContentRow.implicitWidth
    }
    return 0
  }

  readonly property int pinnedExtent: vertical ? pinnedRow.implicitHeight : pinnedRow.implicitWidth
  readonly property int indicatorExtent: showIndicator ? (vertical ? indicatorBtn.implicitHeight : indicatorBtn.implicitWidth) : 0

  readonly property int totalExtent: pinnedExtent + indicatorExtent + inlineContentExtent + (caretActive ? 4 : 0)

  implicitWidth: vertical ? barSize : totalExtent
  implicitHeight: vertical ? totalExtent : barSize

  // ---------------------------------------------------------------------------
  // Auto-rehide Timer
  // ---------------------------------------------------------------------------
  Timer {
    id: rehideTimer
    interval: root.rehideSeconds * 1000
    running: root.expanded && root.rehideSeconds > 0 && !mouseOverTray.containsMouse && !trayMenuOpen && !manageOpen
    onTriggered: root.collapse()
  }

  function expand() {
    expanded = true
    if (rehideTimer.running) rehideTimer.restart()
  }

  function collapse() {
    expanded = false
    manageOpen = false
    rehideTimer.stop()
  }

  function toggle() {
    if (expanded) collapse()
    else expand()
  }

  // ---------------------------------------------------------------------------
  // Mutate Config Helper
  // ---------------------------------------------------------------------------
  function mutateConfig(callback) {
    if (root.bar && root.bar.shell && typeof root.bar.shell.mutateShellConfig === "function") {
      root.bar.shell.mutateShellConfig(callback)
    }
  }

  function saveSettings(newSettings) {
    mutateConfig(function(config) {
      var found = TrayModel.findLayoutEntry(config.bar.layout, root.moduleName)
      if (found && found.entry) {
        if (typeof found.entry === "string") {
          found.entry = { id: found.entry }
          found.entries[found.index] = found.entry
        }
        for (var key in newSettings) {
          found.entry[key] = newSettings[key]
        }
      }
    })
  }

  // ---------------------------------------------------------------------------
  // Drag & Drop Handling (Native Omarchy Bar Drag)
  // ---------------------------------------------------------------------------
  property bool caretActive: false
  property string dropArmedId: ""

  readonly property bool isBarDragging: root.bar && "barDragSource" in root.bar && root.bar.barDragSource !== null
  readonly property string draggedModuleId: {
    if (!isBarDragging) return ""
    var src = root.bar.barDragSource
    var mId = src ? String(src.moduleName || "") : ""
    return (mId && mId !== root.moduleName) ? mId : ""
  }

  Connections {
    target: root.bar

    function onBarDragSourceChanged() {
      if (!root.bar) return
      if (!root.bar.barDragSource && root.dropArmedId) {
        // Dropped!
        var sourceId = root.dropArmedId
        root.dropArmedId = ""
        root.caretActive = false
        root.mutateConfig(function(config) {
          TrayModel.captureIntoTray(config, root.moduleName, sourceId)
        })
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Visual Hierarchy on the Bar
  // ---------------------------------------------------------------------------
  Item {
    id: barContainer
    anchors.fill: parent

    MouseArea {
      id: mouseOverTray
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
      propagateComposedEvents: true
      onEntered: {
        if (root.triggerMode === "hover" && root.hasDrawerContent && !root.expanded) {
          root.expand()
        }
      }
      onExited: {
        if (root.rehideSeconds > 0 && root.expanded) {
          rehideTimer.restart()
        }
      }
    }

    // Main Row / Column
    Row {
      id: mainBarRow
      anchors.fill: parent
      spacing: 0
      visible: !root.vertical

      // 1. Pinned Items Row
      Row {
        id: pinnedRow
        spacing: Style.space(4)
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
          model: root.pinnedHostedWidgets
          delegate: HostedWidget {
            bar: root.bar
            modelData: modelData
            vertical: root.vertical
          }
        }

        Repeater {
          model: root.pinnedSniItems
          delegate: SnItemDelegate {
            bar: root.bar
            modelData: modelData
            vertical: root.vertical
            onRequestMenu: function(item, target, mouse) {
              root.openTrayMenu(item, target, mouse)
            }
          }
        }
      }

      // 2. Drop Caret Visual Indicator
      DropCaret {
        id: dropCaret
        active: root.caretActive
        vertical: root.vertical
        anchors.verticalCenter: parent.verticalCenter
      }

      // 3. Indicator Button (Chevron / Dot / Plus)
      IndicatorButton {
        id: indicatorBtn
        expanded: root.expanded
        vertical: root.vertical
        indicatorIcon: root.indicatorIcon
        triggerMode: root.triggerMode
        duration: root.revealDuration
        visible: root.showIndicator
        anchors.verticalCenter: parent.verticalCenter

        onToggleRequested: root.toggle()
        onRightClicked: root.openManage()
        onHoverEntered: {
          if (root.isBarDragging && root.draggedModuleId) {
            root.dropArmedId = root.draggedModuleId
            root.caretActive = true
          }
          if (root.triggerMode === "hover" && root.hasDrawerContent && !root.expanded) {
            root.expand()
          }
        }
        onHoverExited: {
          if (!mouseOverTray.containsMouse) {
            root.caretActive = false
          }
        }
      }

      // 4. Inline Drawer Container (Smooth Slide-out Animation)
      Item {
        id: inlineDrawerBox
        width: root.inlineContentExtent
        height: parent.height
        clip: true
        visible: root.displayMode === "inline" || root.displayMode === "flat"

        Behavior on width {
          NumberAnimation {
            duration: root.revealDuration
            easing.type: Easing.OutCubic
          }
        }

        Row {
          id: inlineContentRow
          spacing: Style.space(4)
          anchors.verticalCenter: parent.verticalCenter

          Repeater {
            model: root.drawerHostedWidgets
            delegate: HostedWidget {
              bar: root.bar
              modelData: modelData
              vertical: root.vertical
            }
          }

          Repeater {
            model: root.drawerSniItems
            delegate: SnItemDelegate {
              bar: root.bar
              modelData: modelData
              vertical: root.vertical
              onRequestMenu: function(item, target, mouse) {
                root.openTrayMenu(item, target, mouse)
              }
            }
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Dropdown Mode Popup (Floating Strip below the bar)
  // ---------------------------------------------------------------------------
  KeyboardPanel {
    id: dropdownPanel
    anchorItem: indicatorBtn.visible ? indicatorBtn : root
    owner: root
    bar: root.bar
    open: root.displayMode === "dropdown" && root.expanded && !root.manageOpen

    contentWidth: dropdownStrip.implicitWidth
    contentHeight: dropdownStrip.implicitHeight

    PanelKeyCatcher {
      anchors.fill: parent
      onCloseRequested: root.collapse()
      onTextKey: function(t) {
        if (t === "s") root.openManage()
        else if (t === "r") root.bar && root.bar.restartShell && root.bar.restartShell()
      }
    }

    DropdownStrip {
      id: dropdownStrip
      bar: root.bar
      hostedWidgets: root.drawerHostedWidgets
      sniItems: root.drawerSniItems
      vertical: root.vertical
      onSniMenuRequested: function(item, target, mouse) {
        root.openTrayMenu(item, target, mouse)
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Drawer Mode Popup (Grid / List Card)
  // ---------------------------------------------------------------------------
  KeyboardPanel {
    id: drawerGridPanel
    anchorItem: indicatorBtn.visible ? indicatorBtn : root
    owner: root
    bar: root.bar
    open: root.displayMode === "drawer" && root.expanded && !root.manageOpen

    contentWidth: drawerGridComp.implicitWidth
    contentHeight: drawerGridComp.implicitHeight

    PanelKeyCatcher {
      anchors.fill: parent
      onCloseRequested: root.collapse()
      onTextKey: function(t) {
        if (t === "s") root.openManage()
      }
    }

    DrawerGrid {
      id: drawerGridComp
      bar: root.bar
      hostedWidgets: root.drawerHostedWidgets
      sniItems: root.drawerSniItems
      onOpenSettingsRequested: root.openManage()
      onSniMenuRequested: function(item, target, mouse) {
        root.openTrayMenu(item, target, mouse)
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Management Hub Popup (with 3D Flip Perspective)
  // ---------------------------------------------------------------------------
  function openManage() {
    manageOpen = true
  }

  KeyboardPanel {
    id: managePopup
    anchorItem: indicatorBtn.visible ? indicatorBtn : root
    owner: root
    bar: root.bar
    open: root.manageOpen

    contentWidth: manageComp.implicitWidth
    contentHeight: manageComp.implicitHeight

    PanelKeyCatcher {
      anchors.fill: parent
      onCloseRequested: root.manageOpen = false
    }

    Item {
      id: flipContainer
      anchors.fill: parent

      transform: [
        Translate { x: -flipContainer.width / 2; y: -flipContainer.height / 2 },
        Scale {
          xScale: 1 - 0.14 * Math.abs(Math.sin(root.flipAngle * Math.PI / 180))
          yScale: 1 - 0.14 * Math.abs(Math.sin(root.flipAngle * Math.PI / 180))
        },
        Rotation {
          axis.x: 0; axis.y: 1; axis.z: 0
          angle: root.flipAngle
        },
        Matrix4x4 {
          matrix: Qt.matrix4x4(1, 0, 0, 0,
                               0, 1, 0, 0,
                               0, 0, 1, 0,
                               0, 0, -0.0009, 1)
        },
        Translate { x: flipContainer.width / 2; y: flipContainer.height / 2 }
      ]

      ManagePanel {
        id: manageComp
        bar: root.bar
        currentSettings: root.activeSettings
        hostedWidgets: root.configuredWidgets
        sniItems: root.allSniItems
        pinnedIds: root.pinnedIds
        hiddenIds: root.hiddenIds

        onCloseRequested: root.manageOpen = false
        onUpdateSettingsRequested: function(s) { root.saveSettings(s) }
        onTogglePinnedWidget: function(wId) {
          var res = TrayModel.toggleBucketId(root.pinnedIds, root.hiddenIds, wId, "pinned")
          root.saveSettings({ pinned: res.pinned, hidden: res.hidden })
        }
        onToggleHiddenWidget: function(wId) {
          var res = TrayModel.toggleBucketId(root.pinnedIds, root.hiddenIds, wId, "hidden")
          root.saveSettings({ pinned: res.pinned, hidden: res.hidden })
        }
        onReleaseWidget: function(wId) {
          root.mutateConfig(function(config) {
            TrayModel.releaseFromTray(config, root.moduleName, wId)
          })
        }
        onTogglePinnedSni: function(sId) {
          var res = TrayModel.toggleBucketId(root.pinnedIds, root.hiddenIds, sId, "pinned")
          root.saveSettings({ pinned: res.pinned, hidden: res.hidden })
        }
        onToggleHiddenSni: function(sId) {
          var res = TrayModel.toggleBucketId(root.pinnedIds, root.hiddenIds, sId, "hidden")
          root.saveSettings({ pinned: res.pinned, hidden: res.hidden })
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // SNI DBus Menu & Submenu Stack Engine
  // ---------------------------------------------------------------------------
  property bool trayMenuOpen: false
  property var activeTrayItem: null
  property var activeTrayAnchor: null

  QsMenuOpener {
    id: trayMenuOpener
    menu: root.activeTrayItem ? root.activeTrayItem.menu : null
  }

  property var submenuStack: []
  readonly property int submenuDepth: submenuStack.length
  readonly property var currentChildren: submenuDepth > 0
    ? submenuStack[submenuDepth - 1].opener.children
    : trayMenuOpener.children

  Component {
    id: submenuOpenerComp
    QsMenuOpener {}
  }

  function resetTrayMenu() {
    var openers = submenuStack
    submenuStack = []
    for (var i = openers.length - 1; i >= 0; i--) {
      if (openers[i] && openers[i].opener) openers[i].opener.destroy()
    }
  }

  function enterSubmenu(entry, title) {
    var opener = submenuOpenerComp.createObject(root, { menu: entry })
    if (!opener) return
    var stack = submenuStack.slice()
    stack.push({ opener: opener, title: title })
    submenuStack = stack
  }

  function exitSubmenu() {
    if (submenuStack.length <= 0) return
    var stack = submenuStack.slice()
    var popped = stack.pop()
    submenuStack = stack
    if (popped && popped.opener) popped.opener.destroy()
  }

  function openTrayMenu(item, anchor, mouse) {
    resetTrayMenu()
    activeTrayItem = item
    activeTrayAnchor = anchor
    trayMenuOpen = true
  }

  KeyboardPanel {
    id: trayMenuPanel
    anchorItem: root.activeTrayAnchor || root
    owner: root
    bar: root.bar
    open: root.trayMenuOpen

    contentWidth: Style.space(220)
    contentHeight: Math.min(320, menuListCol.implicitHeight + Style.space(16))

    onOpenChanged: {
      if (!open) root.resetTrayMenu()
    }

    PanelKeyCatcher {
      anchors.fill: parent
      onCloseRequested: {
        if (root.submenuDepth > 0) root.exitSubmenu()
        else root.trayMenuOpen = false
      }
    }

    Column {
      id: menuListCol
      width: parent.width
      spacing: 2

      // Back navigation header if inside submenu
      Rectangle {
        width: parent.width
        height: 28
        radius: Style.radius.small
        color: Color.bar.buttonHover
        visible: root.submenuDepth > 0

        Row {
          anchors.fill: parent
          anchors.leftMargin: 8
          spacing: 6

          Text {
            text: "\uf053" // chevron-left
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: Style.fontFace.icon
            font.pixelSize: Style.fontSize.tiny
            color: Color.accent
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            text: root.submenuDepth > 0 ? root.submenuStack[root.submenuDepth - 1].title : "Voltar"
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.pixelSize: Style.fontSize.small
            color: Color.foreground
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.exitSubmenu()
        }
      }

      // Menu Entries
      Repeater {
        model: root.currentChildren
        delegate: Rectangle {
          required property var modelData
          readonly property bool isSeparator: modelData && modelData.isSeparator
          readonly property bool hasSubmenu: modelData && modelData.hasChildren

          width: menuListCol.width
          height: isSeparator ? 5 : 28
          radius: Style.radius.small
          color: (!isSeparator && menuEntryMouse.containsMouse) ? Color.bar.buttonHover : "transparent"

          // Separator line
          Rectangle {
            anchors.centerIn: parent
            width: parent.width - 12
            height: 1
            color: Color.bar.border
            visible: parent.isSeparator
          }

          Row {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 6
            visible: !parent.isSeparator

            Text {
              text: parent.parent.modelData ? String(parent.parent.modelData.text || "") : ""
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.pixelSize: Style.fontSize.small
              color: parent.parent.modelData && parent.parent.modelData.enabled !== false
                ? Color.foreground : Color.bar.buttonForeground
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - 24
              elide: Text.ElideRight
            }

            Text {
              text: "\uf054" // chevron-right
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: Style.fontFace.icon
              font.pixelSize: Style.fontSize.tiny
              color: Color.bar.buttonForeground
              visible: parent.parent.hasSubmenu
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          MouseArea {
            id: menuEntryMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            visible: !parent.isSeparator

            onClicked: {
              if (!parent.modelData) return
              if (parent.hasSubmenu) {
                root.enterSubmenu(parent.modelData, String(parent.modelData.text || ""))
              } else {
                root.trayMenuOpen = false
                parent.modelData.triggered()
              }
            }
          }
        }
      }
    }
  }
}
