import QtQuick

// a column that scrolls once it outgrows maxHeight
Flickable {
  id: scroll
  property real maxHeight
  property alias spacing: column.spacing
  default property alias content: column.data

  width: parent ? parent.width : 0
  height: Math.min(contentHeight, maxHeight)
  contentHeight: column.implicitHeight
  clip: true
  boundsBehavior: Flickable.StopAtBounds

  Column {
    id: column
    width: scroll.width
  }
}
