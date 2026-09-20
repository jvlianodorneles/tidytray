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

  readonly property var entry: modelData && modelData.entry ? modelData.entry : (modelData || ({}))
  readonly property string widgetId: TrayModel.entryId(entry)
  readonly property var widgetSettings: TrayModel.entrySettings(entry)

  readonly property string customType: hostedRoot.bar && typeof hostedRoot.bar.customModuleType === "function"
    ? String(hostedRoot.bar.customModuleType(entry) || "") : ""

  readonly property var registryComponent: {
    if (customType) return null
    var registry = hostedRoot.bar ? hostedRoot.bar.barWidgetRegistry : null
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

  implicitWidth: activeItem && activeItem.visible
    ? (hostedRoot.vertical ? (hostedRoot.bar ? hostedRoot.bar.barSize : Style.bar.sizeHorizontal) : activeItem.implicitWidth)
    : 0
  implicitHeight: activeItem && activeItem.visible
    ? (hostedRoot.vertical ? activeItem.implicitHeight : (hostedRoot.bar ? hostedRoot.bar.barSize : Style.bar.sizeHorizontal))
    : 0
  width: implicitWidth
  height: implicitHeight
  visible: activeItem ? activeItem.visible : false

  onActiveItemChanged: Qt.callLater(injectProps)
  onWidgetSettingsChanged: injectProps()

  function injectProps() {
    var target = activeItem
    if (!target) return
    if ("bar" in target) target.bar = hostedRoot.bar
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
    source: active && hostedRoot.bar && typeof hostedRoot.bar.customModuleSource === "function"
      ? hostedRoot.bar.customModuleSource(entry) : ""
    anchors.fill: parent
    onLoaded: {
      hostedRoot.injectProps()
      Qt.callLater(hostedRoot.injectProps)
    }
  }

  Loader {
    id: commandLoader
    active: hostedRoot.customType === "command"
    sourceComponent: active && hostedRoot.bar && typeof hostedRoot.bar.customModuleComponent === "function"
      ? hostedRoot.bar.customModuleComponent(entry) : null
    anchors.fill: parent
    onLoaded: {
      hostedRoot.injectProps()
      Qt.callLater(hostedRoot.injectProps)
    }
  }

  // Mouse detector for dragging widgets out of the drawer
  MouseArea {
    id: dragDetector
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton
    propagateComposedEvents: true
    preventStealing: false

    property real startX: 0
    property real startY: 0
    property bool dragFired: false

    onPressed: function(mouse) {
      startX = mouse.x
      startY = mouse.y
      dragFired = false
      mouse.accepted = false // Allow activeItem to receive clicks
    }

    onPositionChanged: function(mouse) {
      if (!dragFired && pressed) {
        var dx = mouse.x - startX
        var dy = mouse.y - startY
        if ((dx * dx + dy * dy) > 64) {
          dragFired = true
          hostedRoot.dragStarted(hostedRoot.entry, mouse)
        }
      }
    }
  }
}
