import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
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

  onManageOpenChanged: {
    if (managePopup && managePopup.open !== manageOpen) {
      managePopup.open = manageOpen
    }
  }

  QtObject {
    id: manageController
    function close() {
      root.manageOpen = false
      if (managePopup) managePopup.open = false
    }
  }

  QtObject {
    id: dropdownController
    function close() {
      root.expanded = false
      if (dropdownPanel) dropdownPanel.open = false
    }
  }

  QtObject {
    id: drawerController
    function close() {
      root.expanded = false
      if (drawerGridPanel) drawerGridPanel.open = false
    }
  }

  QtObject {
    id: menuController
    function close() {
      root.trayMenuOpen = false
      if (trayMenuPanel) trayMenuPanel.open = false
      root.resetTrayMenu()
    }
  }

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
  // In inline, dropdown, and drawer modes, always show the indicator so user can click/manage
  // In flat mode, hide indicator if there are no items in drawer
  readonly property bool showIndicator: {
    if (indicatorIcon === "none") return false
    if (displayMode === "flat") return hasDrawerContent
    return true
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

  implicitWidth: vertical ? barSize : Math.max(showIndicator ? indicatorExtent : 0, totalExtent)
  implicitHeight: vertical ? Math.max(showIndicator ? indicatorExtent : 0, totalExtent) : barSize

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
  // Host Bar Adoption (Access to real bar for drag-and-drop & full shell config)
  // ---------------------------------------------------------------------------
  readonly property var barWindow: root.QsWindow ? root.QsWindow.window : null
  readonly property bool facadeBar: bar !== null && bar !== undefined
    && !("barWidgetRegistry" in bar)

  property var hostBar: root.bar

  function isRealHostBar(b) {
    return b !== null && b !== undefined && typeof b === "object" && "barWidgetRegistry" in b
  }

  function findHostBar(item) {
    if (!item) return null
    if (isRealHostBar(item)) return item
    if ("bar" in item && isRealHostBar(item.bar)) return item.bar
    var kids = item.children
    if (!kids) return null
    for (var i = 0; i < kids.length; i++) {
      var found = findHostBar(kids[i])
      if (found) return found
    }
    return null
  }

  function setBar(b) {
    if (!b) return
    root.hostBar = b
    if (root.facadeBar) {
      root.bar = b
    }
  }

  function adoptHostBar() {
    if (!facadeBar && isRealHostBar(hostBar)) return
    var p = root.parent
    while (p) {
      if (isRealHostBar(p)) {
        setBar(p)
        return
      }
      if ("bar" in p && isRealHostBar(p.bar)) {
        setBar(p.bar)
        return
      }
      p = p.parent
    }
    var bw = root.barWindow
    if (!bw && root.bar && root.bar.barWindow) bw = root.bar.barWindow
    if (bw && bw.contentItem) {
      var found = findHostBar(bw.contentItem)
      if (found) {
        setBar(found)
        return
      }
    }
  }

  Component.onCompleted: {
    adoptAttempts = 0
    adoptHostBar()
    var saved = TrayModel.getPersistedManageState()
    if (saved && saved.open) {
      TrayModel.clearPersistedManageState()
      Qt.callLater(function() {
        root.openManage()
        if (manageComp && saved.tab) {
          manageComp.activeTab = saved.tab
        }
      })
    }
  }

  onParentChanged: {
    adoptAttempts = 0
    Qt.callLater(adoptHostBar)
  }
  onBarChanged: {
    adoptAttempts = 0
    Qt.callLater(adoptHostBar)
  }

  property int adoptAttempts: 0
  Timer {
    interval: 200
    repeat: true
    running: root.facadeBar && root.adoptAttempts < 40
    onTriggered: {
      root.adoptAttempts += 1
      root.adoptHostBar()
    }
  }

  // ---------------------------------------------------------------------------
  // Mutate Config Helper & Atomic Script Fallback
  // ---------------------------------------------------------------------------
  Component {
    id: helperProcessComp
    Process {
      id: proc
      property var onFinished: null
      stderr: StdioCollector {
        onStreamFinished: {
          if (text && text.trim()) console.warn("[tidytray] config-helper:", text.trim())
        }
      }
      onExited: function(exitCode) {
        if (typeof onFinished === "function") {
          onFinished(exitCode === 0)
        }
        proc.destroy()
      }
    }
  }

  function runHelper(action, args, callback) {
    var scriptPath = Qt.resolvedUrl("scripts/config-helper.py").toString().replace(/^file:\/\//, "")
    var fullCmd = ["python3", scriptPath, action].concat(args || [])
    var proc = helperProcessComp.createObject(root, {
      command: fullCmd,
      onFinished: callback
    })
    if (proc) {
      proc.running = true
    }
  }

  function getRealShell() {
    if (root.hostBar && root.hostBar.shell && !("pluginId" in root.hostBar.shell) && typeof root.hostBar.shell.mutateShellConfig === "function") {
      return root.hostBar.shell
    }
    return null
  }

  function captureWidget(sourceId) {
    if (!sourceId) return
    if (root.manageOpen) {
      TrayModel.setPersistedManageState(true, manageComp ? manageComp.activeTab : "items")
    }
    var shellObj = getRealShell()
    var handled = false
    if (shellObj) {
      try {
        shellObj.mutateShellConfig(function(config) {
          handled = TrayModel.captureIntoTray(config, root.moduleName, sourceId)
        })
      } catch (e) {
        handled = false
      }
    }
    if (!handled) {
      runHelper("capture", [root.moduleName, sourceId])
    }
  }

  function releaseWidget(widgetId) {
    if (!widgetId) return
    if (root.manageOpen) {
      TrayModel.setPersistedManageState(true, manageComp ? manageComp.activeTab : "items")
    }
    var shellObj = getRealShell()
    var handled = false
    if (shellObj) {
      try {
        shellObj.mutateShellConfig(function(config) {
          handled = TrayModel.releaseFromTray(config, root.moduleName, widgetId)
        })
      } catch (e) {
        handled = false
      }
    }
    if (!handled) {
      runHelper("release", [root.moduleName, widgetId])
    }
  }

  function reorderHostedWidget(fromIndex, toIndex) {
    if (root.manageOpen) {
      TrayModel.setPersistedManageState(true, manageComp ? manageComp.activeTab : "items")
    }
    var shellObj = getRealShell()
    var handled = false
    if (shellObj) {
      try {
        shellObj.mutateShellConfig(function(config) {
          handled = TrayModel.reorderTrayWidgets(config, root.moduleName, fromIndex, toIndex)
        })
      } catch (e) {
        handled = false
      }
    }
    if (!handled) {
      runHelper("reorder", [root.moduleName, String(fromIndex), String(toIndex)])
    }
  }

  function saveSettings(newSettings) {
    var shellObj = getRealShell()
    var handled = false
    if (shellObj) {
      try {
        shellObj.mutateShellConfig(function(config) {
          var found = TrayModel.findLayoutEntry(config.bar.layout, root.moduleName)
          if (found && found.entry) {
            if (typeof found.entry === "string") {
              found.entry = { id: found.entry }
              found.entries[found.index] = found.entry
            }
            for (var key in newSettings) {
              found.entry[key] = newSettings[key]
            }
            handled = true
          }
        })
      } catch (e) {
        handled = false
      }
    }
    if (!handled) {
      runHelper("save-settings", [root.moduleName, JSON.stringify(newSettings)])
    }
  }

  // ---------------------------------------------------------------------------
  // Drag & Drop Handling (Tracking Host Bar Drag)
  // ---------------------------------------------------------------------------
  property bool caretActive: false
  property bool dragOver: false
  property string currentDraggedId: ""

  readonly property bool isBarDragging: root.hostBar && "barDragSource" in root.hostBar && root.hostBar.barDragSource !== null
  readonly property string draggedModuleId: {
    if (!isBarDragging) return ""
    var src = root.hostBar.barDragSource
    var mId = src ? String(src.moduleName || "") : ""
    return (mId && mId !== root.moduleName) ? mId : ""
  }

  function checkDragHit() {
    if (!root.hostBar || !root.hostBar.barDragSource || !root.currentDraggedId) {
      if (dragOver) dragOver = false
      if (caretActive) caretActive = false
      return
    }
    var sx = root.hostBar.barDragSceneX
    var sy = root.hostBar.barDragSceneY
    var targetItem = (indicatorBtn && indicatorBtn.visible) ? indicatorBtn : root
    var origin = { x: 0, y: 0 }
    try {
      origin = targetItem.mapToItem(null, 0, 0)
    } catch (e) {
      return
    }
    var pad = 10
    var inside = (sx >= origin.x - pad && sx <= origin.x + targetItem.width + pad &&
                  sy >= origin.y - pad && sy <= origin.y + targetItem.height + pad)
    if (inside) {
      dragOver = true
      caretActive = true
      if (root.hostBar) {
        root.hostBar.barDragTarget = null
        root.hostBar.barDragTargetGeometry = null
      }
    } else {
      dragOver = false
      caretActive = false
    }
  }

  Connections {
    target: root.hostBar
    ignoreUnknownSignals: true

    function onBarDragSceneXChanged() { root.checkDragHit() }
    function onBarDragSceneYChanged() { root.checkDragHit() }
    function onBarDragSourceChanged() {
      var src = root.hostBar ? root.hostBar.barDragSource : null
      if (src) {
        var mId = String(src.moduleName || "")
        if (mId && mId !== root.moduleName) {
          root.currentDraggedId = mId
        }
      } else {
        if (root.dragOver && root.currentDraggedId) {
          var idToCapture = root.currentDraggedId
          root.dragOver = false
          root.caretActive = false
          root.currentDraggedId = ""
          Qt.callLater(function() {
            root.captureWidget(idToCapture)
          })
        } else {
          root.dragOver = false
          root.caretActive = false
          root.currentDraggedId = ""
        }
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
        if (root.triggerMode === "hover" && !root.expanded) {
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
            bar: (root.hostBar || root.bar)
            modelData: modelData
            vertical: root.vertical
          }
        }

        Repeater {
          model: root.pinnedSniItems
          delegate: SnItemDelegate {
            bar: (root.hostBar || root.bar)
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
        bar: (root.hostBar || root.bar)
        dragOver: root.dragOver
        expanded: root.expanded
        indicatorIcon: root.indicatorIcon
        triggerMode: root.triggerMode
        duration: root.revealDuration
        visible: root.showIndicator
        anchors.verticalCenter: parent.verticalCenter

        onToggleRequested: root.toggle()
        onRightClicked: root.openManage()
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
              bar: (root.hostBar || root.bar)
              modelData: modelData
              vertical: root.vertical
            }
          }

          Repeater {
            model: root.drawerSniItems
            delegate: SnItemDelegate {
              bar: (root.hostBar || root.bar)
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
    owner: dropdownController
    bar: (root.hostBar || root.bar)
    open: root.displayMode === "dropdown" && root.expanded && !root.manageOpen
    focusTarget: dropdownKeyCatcher

    contentWidth: dropdownPanel.fittedContentWidth(dropdownStrip.implicitWidth)
    contentHeight: dropdownPanel.fittedContentHeight(dropdownStrip.implicitHeight)

    PanelKeyCatcher {
      id: dropdownKeyCatcher
      anchors.fill: parent
      onCloseRequested: root.collapse()
      onTextKey: function(t) {
        if (t === "s") root.openManage()
        else if (t === "r") root.bar && root.bar.restartShell && root.bar.restartShell()
      }

      DropdownStrip {
        id: dropdownStrip
        anchors.fill: parent
        bar: (root.hostBar || root.bar)
        hostedWidgets: root.drawerHostedWidgets
        sniItems: root.drawerSniItems
        vertical: root.vertical
        onSniMenuRequested: function(item, target, mouse) {
          root.openTrayMenu(item, target, mouse)
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Drawer Mode Popup (Grid / List Card)
  // ---------------------------------------------------------------------------
  KeyboardPanel {
    id: drawerGridPanel
    anchorItem: indicatorBtn.visible ? indicatorBtn : root
    owner: drawerController
    bar: (root.hostBar || root.bar)
    open: root.displayMode === "drawer" && root.expanded && !root.manageOpen
    focusTarget: drawerKeyCatcher

    contentWidth: drawerGridPanel.fittedContentWidth(Style.space(340))
    contentHeight: drawerGridPanel.fittedContentHeight(drawerGridComp.neededHeight, Style.space(500))

    PanelKeyCatcher {
      id: drawerKeyCatcher
      anchors.fill: parent
      blocked: drawerGridComp.isEditing
      onCloseRequested: root.collapse()
      onTextKey: function(t) {
        if (t === "s") root.openManage()
      }

      DrawerGrid {
        id: drawerGridComp
        anchors.fill: parent
        bar: (root.hostBar || root.bar)
        hostedWidgets: root.drawerHostedWidgets
        sniItems: root.drawerSniItems
        onOpenSettingsRequested: root.openManage()
        onSniMenuRequested: function(item, target, mouse) {
          root.openTrayMenu(item, target, mouse)
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Management Hub Popup
  // ---------------------------------------------------------------------------
  function openManage() {
    if (manageOpen) {
      manageOpen = false
      if (managePopup) managePopup.open = false
    } else {
      manageOpen = true
      if (managePopup) managePopup.open = true
    }
  }

  KeyboardPanel {
    id: managePopup
    anchorItem: indicatorBtn.visible ? indicatorBtn : root
    owner: manageController
    bar: (root.hostBar || root.bar)
    open: root.manageOpen
    focusTarget: manageKeyCatcher

    contentWidth: managePopup.fittedContentWidth(Style.space(380))
    contentHeight: managePopup.fittedContentHeight(manageComp.neededHeight, Style.space(560))

    onOpenChanged: {
      if (root.manageOpen !== open) {
        root.manageOpen = open
      }
    }

    PanelKeyCatcher {
      id: manageKeyCatcher
      anchors.fill: parent
      blocked: manageComp.isEditing
      onCloseRequested: root.manageOpen = false

      ManagePanel {
        id: manageComp
        anchors.fill: parent
        bar: (root.hostBar || root.bar)
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
        onReorderWidget: function(fromIdx, toIdx) {
          root.reorderHostedWidget(fromIdx, toIdx)
        }
        onReleaseWidget: function(wId) {
          root.releaseWidget(wId)
        }
        onCaptureWidget: function(wId) {
          root.captureWidget(wId)
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
    owner: menuController
    bar: (root.hostBar || root.bar)
    open: root.trayMenuOpen
    focusTarget: menuKeyCatcher

    contentWidth: trayMenuPanel.fittedContentWidth(Style.space(220))
    contentHeight: trayMenuPanel.fittedContentHeight(menuListCol.implicitHeight, Style.space(360))

    onOpenChanged: {
      if (!open) {
        root.trayMenuOpen = false
        root.resetTrayMenu()
      }
    }

    PanelKeyCatcher {
      id: menuKeyCatcher
      anchors.fill: parent
      onCloseRequested: {
        if (root.submenuDepth > 0) root.exitSubmenu()
        else root.trayMenuOpen = false
      }

      Column {
        id: menuListCol
        anchors.fill: parent
        spacing: 2

        // Back navigation header if inside submenu
        Rectangle {
          width: parent.width
          height: 28
          radius: Style.cornerRadius
          color: Style.hoverFill
          visible: root.submenuDepth > 0

          Row {
            anchors.fill: parent
            anchors.leftMargin: 8
            spacing: 6

            Text {
              text: "\uf053" // chevron-left
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: Color.accent
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              text: root.submenuDepth > 0 ? root.submenuStack[root.submenuDepth - 1].title : "Back"
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
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
            id: menuItemDelegate
            required property var modelData
            readonly property bool isSeparator: modelData && modelData.isSeparator
            readonly property bool hasSubmenu: modelData && modelData.hasChildren

            width: menuListCol.width
            height: isSeparator ? 5 : 28
            radius: Style.cornerRadius
            color: (!isSeparator && menuEntryMouse.containsMouse) ? Style.hoverFill : "transparent"

            // Separator line
            Rectangle {
              anchors.centerIn: parent
              width: parent.width - 12
              height: 1
              color: Color.popups.border
              visible: menuItemDelegate.isSeparator
            }

            Row {
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              spacing: 6
              visible: !menuItemDelegate.isSeparator

              Text {
                text: menuItemDelegate.modelData ? String(menuItemDelegate.modelData.text || "") : ""
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                color: menuItemDelegate.modelData && menuItemDelegate.modelData.enabled !== false
                  ? Color.foreground : Color.muted
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 24
                elide: Text.ElideRight
              }

              Text {
                text: "\uf054" // chevron-right
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Color.muted
                visible: menuItemDelegate.hasSubmenu
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            MouseArea {
              id: menuEntryMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              visible: !menuItemDelegate.isSeparator

              onClicked: {
                if (!menuItemDelegate.modelData) return
                if (menuItemDelegate.hasSubmenu) {
                  root.enterSubmenu(menuItemDelegate.modelData, String(menuItemDelegate.modelData.text || ""))
                } else {
                  root.trayMenuOpen = false
                  menuItemDelegate.modelData.triggered()
                }
              }
            }
          }
        }
      }
    }
  }
}
