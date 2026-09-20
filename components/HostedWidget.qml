import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui
import "../TrayModel.js" as TrayModel

Item {
  id: hostedRoot

  property var modelData: null
  property var bar: null
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

  implicitWidth: activeItem && activeItem.visible
    ? (hostedRoot.vertical ? defaultBarSize : Math.max(fallbackSize, activeItem.implicitWidth || 0))
    : 0
  implicitHeight: activeItem && activeItem.visible
    ? (hostedRoot.vertical ? Math.max(fallbackSize, activeItem.implicitHeight || 0) : defaultBarSize)
    : 0
  width: implicitWidth
  height: implicitHeight
  visible: activeItem ? activeItem.visible : false

  onActiveItemChanged: Qt.callLater(injectProps)
  onWidgetSettingsChanged: injectProps()

  function injectProps() {
    var target = activeItem
    if (!target) return
    if ("bar" in target) target.bar = effectiveBar
    if ("entry" in target) target.entry = hostedRoot.entry
    if ("moduleName" in target) target.moduleName = widgetId
    if ("settings" in target) target.settings = widgetSettings
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

  // Pointer drag handler: lets clicks and interactions reach the hosted widget directly
  DragHandler {
    id: cellDrag
    target: null
    acceptedButtons: Qt.LeftButton
    dragThreshold: Style.space(4)
    grabPermissions: PointerHandler.CanTakeOverFromAnything

    onActiveChanged: {
      if (active) hostedRoot.dragStarted(hostedRoot.entry, null)
    }
  }
}
