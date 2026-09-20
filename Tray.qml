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

  IpcHandler {
    target: "tidytray"
    function status(): string {
      try {
        var kids = []
        for (var i = 0; i < inlineContentRow.children.length; i++) {
          var c = inlineContentRow.children[i]
          kids.push({
            type: String(c),
            widgetId: ("widgetId" in c) ? c.widgetId : "",
            effectiveBar: ("effectiveBar" in c) ? String(c.effectiveBar) : "",
            registryComponent: ("registryComponent" in c) ? String(c.registryComponent) : "",
            activeItem: ("activeItem" in c) ? String(c.activeItem) : "",
            modelData: ("modelData" in c && c.modelData) ? (c.modelData.id || (c.modelData.entry ? c.modelData.entry.id : null) || c.modelData) : null,
            status: ("modelData" in c && c.modelData && "status" in c.modelData) ? c.modelData.status : null,
            isVisible: ("isVisible" in c) ? c.isVisible : c.visible,
            implicitWidth: c.implicitWidth,
            implicitHeight: c.implicitHeight,
            visible: c.visible,
            x: c.x,
            y: c.y,
            width: c.width,
            height: c.height
          })
        }
        var rowKids = []
        for (var j = 0; j < mainBarRow.children.length; j++) {
          var rk = mainBarRow.children[j]
          rowKids.push({
            id: rk.id || String(rk),
            x: rk.x,
            y: rk.y,
            width: rk.width,
            height: rk.height,
            implicitWidth: rk.implicitWidth,
            implicitHeight: rk.implicitHeight,
            visible: rk.visible,
            opacity: rk.opacity
          })
        }
        var dropdownKids = []
        if (dropdownStrip && dropdownStrip.hostedWidgets) {
          dropdownKids.push({
            hostedWidgetsCount: dropdownStrip.hostedWidgets.length,
            sniItemsCount: dropdownStrip.sniItems ? dropdownStrip.sniItems.length : 0,
            bar: String(dropdownStrip.bar)
          })
        }
        var drawerKids = []
        if (drawerGridComp && drawerGridComp.hostedWidgets) {
          drawerKids.push({
            hostedWidgetsCount: drawerGridComp.hostedWidgets.length,
            sniItemsCount: drawerGridComp.sniItems ? drawerGridComp.sniItems.length : 0,
            bar: String(drawerGridComp.bar)
          })
        }
        var drawerTiles = []
        if (drawerGridComp && drawerGridComp.flowKids) {
          for (var d = 0; d < drawerGridComp.flowKids.length; d++) {
            var dc = drawerGridComp.flowKids[d]
            drawerTiles.push({
              type: String(dc),
              wId: dc.wId,
              matches: dc.matches,
              width: dc.width,
              height: dc.height,
              visible: dc.visible,
              implicitWidth: dc.implicitWidth,
              implicitHeight: dc.implicitHeight
            })
          }
        }
        var dropdownTiles = []
        if (dropdownStrip && dropdownStrip.itemsRowKids) {
          for (var dp = 0; dp < dropdownStrip.itemsRowKids.length; dp++) {
            var dpc = dropdownStrip.itemsRowKids[dp]
            dropdownTiles.push({
              type: String(dpc),
              widgetId: ("widgetId" in dpc) ? dpc.widgetId : "",
              width: dpc.width,
              height: dpc.height,
              visible: dpc.visible,
              implicitWidth: dpc.implicitWidth,
              implicitHeight: dpc.implicitHeight
            })
          }
        }
        var popoutInfo = null
        if (drawerBarProxy && drawerBarProxy.activePopout) {
          var ap = drawerBarProxy.activePopout
          popoutInfo = {
            owner: String(ap),
            anchorItem: ("anchorItem" in ap) ? String(ap.anchorItem) : null,
            anchorWindow: ("anchorItem" in ap && ap.anchorItem && ap.anchorItem.QsWindow) ? String(ap.anchorItem.QsWindow.window) : null,
            contentWidth: ("contentWidth" in ap) ? ap.contentWidth : null,
            contentHeight: ("contentHeight" in ap) ? ap.contentHeight : null,
            cardOrigin: ("cardOrigin" in ap) ? ap.cardOrigin : null,
            barH: ("barH" in ap) ? ap.barH : null
          }
        }
        return JSON.stringify({
          displayMode: root.displayMode,
          expanded: root.expanded,
          drawerHostedCount: root.drawerHostedWidgets.length,
          drawerSniCount: root.drawerSniItems.length,
          configuredWidgetsCount: root.configuredWidgets.length,
          effectiveHostBar: String(root.effectiveHostBar),
          dropdownOpen: dropdownPanel ? dropdownPanel.open : false,
          dropdownVisible: dropdownPanel ? dropdownPanel.visible : false,
          drawerOpen: drawerGridPanel ? drawerGridPanel.open : false,
          drawerVisible: drawerGridPanel ? drawerGridPanel.visible : false,
          drawerTiles: drawerTiles,
          dropdownTiles: dropdownTiles,
          rowKids: rowKids,
          popoutInfo: popoutInfo
        })
      } catch (e) {
        return "ERROR: " + e.message + " " + e.stack
      }
    }
    function toggle(): void { root.toggle() }
    function expand(): void { root.expand() }
    function collapse(): void { root.collapse() }
  }

  QtObject {
    id: manageController
    function close() {
      root.manageOpen = false
    }
  }

  QtObject {
    id: dropdownController
    function close() {
      root.expanded = false
    }
  }

  QtObject {
    id: drawerController
    function close() {
      root.expanded = false
    }
  }

  QtObject {
    id: menuController
    function close() {
      root.trayMenuOpen = false
      root.resetTrayMenu()
    }
  }

  // Local popout proxy for hosted widgets placed inside floating panels (drawer/dropdown)
  // so opening a child's PopupCard or KeyboardPanel coordinates locally rather than
  // triggering Bar.qml to close the parent drawer panel.
  QtObject {
    id: drawerBarProxy
    readonly property var hostBar: root.effectiveHostBar
    readonly property Item barAnchor: indicatorBtn.visible ? indicatorBtn : root

    property var activePopout: null

    function fixAnchors(obj) {
      if (!obj || !barAnchor) return
      try {
        if ("anchorItem" in obj && obj.anchorItem !== barAnchor) {
          obj.anchorItem = barAnchor
        }
      } catch (e) {}

      try {
        if (obj.panelLoader && obj.panelLoader.item) {
          fixAnchors(obj.panelLoader.item)
        }
      } catch (e) {}
      try {
        if (obj.panel) {
          fixAnchors(obj.panel)
        }
      } catch (e) {}
      try {
        if (obj.popup) {
          fixAnchors(obj.popup)
        }
      } catch (e) {}

      try {
        if (obj.children) {
          for (var i = 0; i < obj.children.length; i++) {
            var child = obj.children[i]
            if (!child) continue
            if ("anchorItem" in child && child.anchorItem !== barAnchor) {
              child.anchorItem = barAnchor
            }
            if (child.item) {
              fixAnchors(child.item)
            }
            if (child.children && child.children.length > 0) {
              fixAnchors(child)
            }
          }
        }
      } catch (e) {}
    }

    function requestPopout(owner) {
      fixAnchors(owner)
      if (activePopout === owner) return
      if (activePopout) {
        if ("closeForPopoutSwitch" in activePopout) activePopout.closeForPopoutSwitch()
        else if ("close" in activePopout) activePopout.close()
      }
      activePopout = owner
      if (hostBar && typeof hostBar.requestPopout === "function") {
        hostBar.requestPopout(owner)
      }
      root.expanded = false
    }

    function releasePopout(owner) {
      if (activePopout === owner) activePopout = null
      if (hostBar && typeof hostBar.releasePopout === "function") {
        hostBar.releasePopout(owner)
      }
    }

    function closeChildPopouts() {
      if (activePopout) {
        if ("close" in activePopout) activePopout.close()
        activePopout = null
      }
    }

    // Forward presentation and shell API to the real bar
    readonly property var barWidgetRegistry: hostBar ? hostBar.barWidgetRegistry : null
    readonly property var shell: hostBar ? hostBar.shell : null
    readonly property string position: hostBar ? hostBar.position : "top"
    readonly property bool vertical: hostBar ? hostBar.vertical : false
    readonly property int barSize: hostBar ? hostBar.barSize : Style.bar.sizeHorizontal
    readonly property color foreground: hostBar ? hostBar.foreground : "transparent"
    readonly property color barForeground: hostBar ? hostBar.barForeground : "transparent"
    readonly property color background: hostBar ? hostBar.background : "transparent"
    readonly property color urgent: hostBar ? hostBar.urgent : "transparent"
    readonly property string fontFamily: hostBar ? hostBar.fontFamily : ""
    readonly property bool transparent: hostBar ? hostBar.transparent : false
    readonly property var layoutConfig: hostBar ? hostBar.layoutConfig : ({})
    readonly property var clickTargets: hostBar ? hostBar.clickTargets : []

    function showTooltip(target, text) { if (hostBar) hostBar.showTooltip(target, text) }
    function hideTooltip(target) { if (hostBar) hostBar.hideTooltip(target) }
    function registerClickTarget(target) { if (hostBar && hostBar.registerClickTarget) hostBar.registerClickTarget(target) }
    function unregisterClickTarget(target) { if (hostBar && hostBar.unregisterClickTarget) hostBar.unregisterClickTarget(target) }
    function customModuleType(entry) { return hostBar && typeof hostBar.customModuleType === "function" ? hostBar.customModuleType(entry) : "" }
    function customModuleSource(entry) { return hostBar && typeof hostBar.customModuleSource === "function" ? hostBar.customModuleSource(entry) : "" }
    function restartShell() { if (hostBar && hostBar.restartShell) hostBar.restartShell() }
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

  readonly property var effectiveHostBar: (hostBar && isRealHostBar(hostBar)) ? hostBar : bar

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
  }

  function adoptHostBar() {
    if (isRealHostBar(hostBar)) return
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
    running: !root.isRealHostBar(root.hostBar) && root.adoptAttempts < 40
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
        height: parent.height

        Repeater {
          model: root.pinnedHostedWidgets
          delegate: HostedWidget {
            bar: root.effectiveHostBar
            vertical: root.vertical
          }
        }

        Repeater {
          model: root.pinnedSniItems
          delegate: SnItemDelegate {
            bar: root.effectiveHostBar
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
        height: parent.height
      }

      // 3. Indicator Button (Chevron / Dot / Plus)
      IndicatorButton {
        id: indicatorBtn
        bar: root.effectiveHostBar
        dragOver: root.dragOver
        expanded: root.expanded
        indicatorIcon: root.indicatorIcon
        triggerMode: root.triggerMode
        duration: root.revealDuration
        visible: root.showIndicator
        height: parent.height

        onToggleRequested: root.toggle()
        onRightClicked: root.openManage()
      }

      // 4. Inline Drawer Container (Smooth Slide-out Animation)
      Item {
        id: inlineDrawerBox
        width: root.inlineContentExtent
        height: parent.height
        clip: true
        visible: (root.displayMode === "inline" || root.displayMode === "flat")
                 && (root.expanded || root.displayMode === "flat" || width > 0)
        enabled: root.expanded || root.displayMode === "flat"

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
          height: parent.height

          Repeater {
            model: (root.displayMode === "inline" || root.displayMode === "flat") ? root.drawerHostedWidgets : []
            delegate: HostedWidget {
              bar: root.effectiveHostBar
              vertical: root.vertical
            }
          }

          Repeater {
            model: (root.displayMode === "inline" || root.displayMode === "flat") ? root.drawerSniItems : []
            delegate: SnItemDelegate {
              bar: root.effectiveHostBar
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
    bar: root.effectiveHostBar
    open: root.displayMode === "dropdown" && root.expanded && !root.manageOpen
    focusTarget: dropdownKeyCatcher

    contentWidth: dropdownPanel.fittedContentWidth(dropdownStrip.implicitWidth)
    contentHeight: dropdownPanel.fittedContentHeight(dropdownStrip.implicitHeight)

    onOpenChanged: {
      if (!open) drawerBarProxy.closeChildPopouts()
    }

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
        bar: drawerBarProxy
        barAnchor: indicatorBtn.visible ? indicatorBtn : root
        hostedWidgets: root.displayMode === "dropdown" ? root.drawerHostedWidgets : []
        sniItems: root.displayMode === "dropdown" ? root.drawerSniItems : []
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
    bar: root.effectiveHostBar
    open: root.displayMode === "drawer" && root.expanded && !root.manageOpen
    focusTarget: drawerKeyCatcher

    contentWidth: drawerGridPanel.fittedContentWidth(Style.space(340))
    contentHeight: drawerGridPanel.fittedContentHeight(drawerGridComp.neededHeight, Style.space(500))

    onOpenChanged: {
      if (!open) drawerBarProxy.closeChildPopouts()
    }

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
        bar: drawerBarProxy
        barAnchor: indicatorBtn.visible ? indicatorBtn : root
        hostedWidgets: root.displayMode === "drawer" ? root.drawerHostedWidgets : []
        sniItems: root.displayMode === "drawer" ? root.drawerSniItems : []
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
    manageOpen = !manageOpen
  }

  KeyboardPanel {
    id: managePopup
    anchorItem: indicatorBtn.visible ? indicatorBtn : root
    owner: manageController
    bar: root.effectiveHostBar
    open: root.manageOpen
    focusTarget: manageKeyCatcher

    contentWidth: managePopup.fittedContentWidth(Style.space(380))
    contentHeight: managePopup.fittedContentHeight(manageComp.neededHeight, Style.space(560))

    onOpenChanged: {
      if (!open) {
        root.manageOpen = false
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
        bar: root.effectiveHostBar
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
    bar: root.effectiveHostBar
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

  // Explicit binding guards to ensure open states are never permanently overwritten
  Binding {
    target: dropdownPanel
    property: "open"
    value: root.displayMode === "dropdown" && root.expanded && !root.manageOpen
    restoreMode: Binding.RestoreBinding
  }

  Binding {
    target: drawerGridPanel
    property: "open"
    value: root.displayMode === "drawer" && root.expanded && !root.manageOpen
    restoreMode: Binding.RestoreBinding
  }

  Binding {
    target: managePopup
    property: "open"
    value: root.manageOpen
    restoreMode: Binding.RestoreBinding
  }

  Binding {
    target: trayMenuPanel
    property: "open"
    value: root.trayMenuOpen
    restoreMode: Binding.RestoreBinding
  }
}
