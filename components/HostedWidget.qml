import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui
import "../TrayModel.js" as TrayModel

Item {
  id: hostedRoot

  required property var modelData
  property var bar: null
  property Item barAnchor: null
  property bool vertical: false

  signal dragStarted(var entry, var mouse)

  readonly property var effectiveBar: {
    if (hostedRoot.bar && "barWidgetRegistry" in hostedRoot.bar) return hostedRoot.bar
    if (typeof root !== "undefined" && root && root.hostBar && "barWidgetRegistry" in root.hostBar) return root.hostBar
    if (typeof root !== "undefined" && root && root.bar && "barWidgetRegistry" in root.bar) return root.bar
    return hostedRoot.bar
  }

  readonly property var entry: modelData && modelData.entry ? modelData.entry : (modelData || ({}))
  readonly property string widgetId: TrayModel.entryId(entry)
  readonly property var widgetSettings: TrayModel.entrySettings(entry)

  readonly property string customType: effectiveBar && typeof effectiveBar.customModuleType === "function"
    ? String(effectiveBar.customModuleType(entry) || "") : ""

  readonly property var registryComponent: {
    if (customType) return null
    var registry = effectiveBar ? effectiveBar.barWidgetRegistry : null
    if (!registry) return null
    var rev = registry.revision
    void rev
    var record = registry.widgets ? registry.widgets[widgetId] : null
    return record ? record.component : null
  }

  readonly property var activeItem: {
    if (registryComponent) return registryLoader.item
    if (customType === "qml") return qmlLoader.item
    if (customType === "command") return commandLoader.item
    return null
  }

  readonly property int fallbackSize: Style.bar.iconSlot
  readonly property int defaultBarSize: effectiveBar ? effectiveBar.barSize : Style.bar.sizeHorizontal

  implicitWidth: activeItem
    ? (hostedRoot.vertical ? defaultBarSize : Math.max(fallbackSize, activeItem.implicitWidth || 0))
    : 0
  implicitHeight: activeItem
    ? (hostedRoot.vertical ? Math.max(fallbackSize, activeItem.implicitHeight || 0) : defaultBarSize)
    : 0
  width: implicitWidth
  height: implicitHeight
  visible: activeItem !== null

  onActiveItemChanged: {
    injectProps()
    Qt.callLater(injectProps)
  }
  onEffectiveBarChanged: injectProps()
  onWidgetSettingsChanged: injectProps()
  onBarAnchorChanged: hookTarget(activeItem)

  function hookTarget(target) {
    if (!target || !barAnchor) return
    try {
      if ("anchorItem" in target && target.anchorItem !== barAnchor) {
        target.anchorItem = barAnchor
        try {
          target.anchorItemChanged.connect(function() {
            if (hostedRoot.barAnchor && target.anchorItem !== hostedRoot.barAnchor) {
              target.anchorItem = hostedRoot.barAnchor
            }
          })
        } catch (e) {}
      }
      if (target.data) {
        for (var i = 0; i < target.data.length; i++) {
          var d = target.data[i]
          if (!d) continue
          if ("anchorItem" in d && d.anchorItem !== barAnchor) {
            d.anchorItem = barAnchor
            try {
              d.anchorItemChanged.connect(function() {
                if (hostedRoot.barAnchor && d.anchorItem !== hostedRoot.barAnchor) {
                  d.anchorItem = hostedRoot.barAnchor
                }
              })
            } catch (e) {}
          }
          if ("item" in d) {
            if (d.item) hookTarget(d.item)
            try {
              d.itemChanged.connect(function() {
                if (d.item) hostedRoot.hookTarget(d.item)
              })
            } catch (e) {}
          }
        }
      }
    } catch (e) {}
  }

  function fixAnchors(obj) {
    hookTarget(obj)
  }

  function injectProps() {
    var target = activeItem
    if (!target) return
    if ("bar" in target) target.bar = effectiveBar
    if ("entry" in target) target.entry = hostedRoot.entry
    if ("moduleName" in target) target.moduleName = widgetId
    if ("settings" in target) target.settings = widgetSettings
    if (barAnchor) fixAnchors(target)
    try {
      target.anchors.fill = target.parent
    } catch (e) {
      target.width = Qt.binding(function() { return hostedRoot.width })
      target.height = Qt.binding(function() { return hostedRoot.height })
    }
  }

  Loader {
    id: registryLoader
    active: hostedRoot.registryComponent !== null
    sourceComponent: hostedRoot.registryComponent
    anchors.fill: parent
    onLoaded: {
      hostedRoot.injectProps()
      Qt.callLater(hostedRoot.injectProps)
    }
  }

  Loader {
    id: qmlLoader
    active: hostedRoot.customType === "qml"
    source: active && effectiveBar && typeof effectiveBar.customModuleSource === "function"
      ? effectiveBar.customModuleSource(entry) : ""
    anchors.fill: parent
    onLoaded: {
      hostedRoot.injectProps()
      Qt.callLater(hostedRoot.injectProps)
    }
  }

  Loader {
    id: commandLoader
    active: hostedRoot.customType === "command"
    sourceComponent: active && effectiveBar && typeof effectiveBar.customModuleComponent === "function"
      ? effectiveBar.customModuleComponent(entry) : null
    anchors.fill: parent
    onLoaded: {
      hostedRoot.injectProps()
      Qt.callLater(hostedRoot.injectProps)
    }
  }

  Component.onCompleted: {
    if (typeof root !== "undefined" && root && typeof root.registerHostedDelegate === "function") {
      root.registerHostedDelegate(hostedRoot)
    }
  }
  Component.onDestruction: {
    if (typeof root !== "undefined" && root && typeof root.unregisterHostedDelegate === "function") {
      root.unregisterHostedDelegate(hostedRoot)
    }
  }

  // Pointer drag handler: lets clicks and interactions reach the hosted widget directly
  DragHandler {
    id: cellDrag
    target: null
    acceptedButtons: Qt.LeftButton
    dragThreshold: Style.space(4)
    grabPermissions: PointerHandler.CanTakeOverFromAnything

    onActiveChanged: {
      if (active) {
        hostedRoot.dragStarted(hostedRoot.entry, null)
        if (typeof root !== "undefined" && root && typeof root.startHostedDrag === "function") {
          root.startHostedDrag(hostedRoot, cellDrag.centroid.position)
        }
      } else {
        if (typeof root !== "undefined" && root && typeof root.endHostedDrag === "function") {
          root.endHostedDrag(hostedRoot)
        }
      }
    }

    onCentroidChanged: {
      if (active && typeof root !== "undefined" && root && typeof root.updateHostedDrag === "function") {
        root.updateHostedDrag(hostedRoot, cellDrag.centroid.position)
      }
    }
  }
}
