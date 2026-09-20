import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "../TrayModel.js" as TrayModel

Item {
  id: dropdownStripRoot

  property var bar: null
  property Item barAnchor: null
  property var hostedWidgets: []
  property var sniItems: []
  property bool vertical: false

  signal sniMenuRequested(var item, var target, var mouse)
  signal dragStarted(var entry, var mouse)

  readonly property int itemsSpacing: Style.space(6)
  readonly property int stripPadding: Style.space(6)
  readonly property alias itemsRowKids: itemsRow.children

  implicitWidth: vertical ? Style.bar.sizeHorizontal : (itemsRow.implicitWidth + stripPadding * 2)
  implicitHeight: vertical ? (itemsRow.implicitHeight + stripPadding * 2) : Style.bar.sizeHorizontal

  Row {
    id: itemsRow
    anchors.centerIn: parent
    spacing: dropdownStripRoot.itemsSpacing

    // Hosted Widgets
    Repeater {
      model: dropdownStripRoot.hostedWidgets
      delegate: HostedWidget {
        bar: dropdownStripRoot.bar
        barAnchor: dropdownStripRoot.barAnchor
        vertical: dropdownStripRoot.vertical
        onDragStarted: function(entry, mouse) {
          dropdownStripRoot.dragStarted(entry, mouse)
        }
      }
    }

    // SNI Items
    Repeater {
      model: dropdownStripRoot.sniItems
      delegate: SnItemDelegate {
        bar: dropdownStripRoot.bar
        vertical: dropdownStripRoot.vertical
        onRequestMenu: function(item, target, mouse) {
          dropdownStripRoot.sniMenuRequested(item, target, mouse)
        }
      }
    }
  }
}
