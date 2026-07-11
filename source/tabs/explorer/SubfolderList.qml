import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15

import gui 1.0

import "../../style"
import "../../components"

ListView {
    id: root
    interactive: false
    width: parent.width
    height: contentHeight
    property var index: 0
    property var mode: ""
    property var showPhantomFolder: false

    signal move(string model, string folder, string subfolder)
    signal createSubfolder(string model, string folder)

    model: Sql {
        query: "SELECT DISTINCT folder FROM models WHERE category = '" + root.mode + "' AND folder != '' ORDER BY folder ASC;"
    }

    delegate: Item {
        x: 10
        width: root.width - 2*x
        height: 25
        SColumnButton {
            id: button
            label: modelData
            height: 25
            width: parent.width
            active: (EXPLORER.currentTab == mode && EXPLORER.currentFolder == modelData) || basicDrop.containsDrag
            onPressed: {
                EXPLORER.setCurrent(mode, modelData)
            }
            AdvancedDropArea {
                id: basicDrop
                anchors.fill: parent
                onDropped: {
                    var model = EXPLORER.onDrop(mimeData)
                    if(model != "") {
                        root.move(model, mode, modelData)
                    }
                }
            }
        }
    }

    footer: Item {
        width: root.width
        height: (EXPLORER.dragging || root.showPhantomFolder) ? 29 : 0
        visible: EXPLORER.dragging || root.showPhantomFolder

        SColumnButton {
            id: newSubfolderButton
            width: 25
            height: 25
            anchors.horizontalCenter: parent.horizontalCenter
            label: "+"
            active: newSubfolderDrop.containsDrag

            AdvancedDropArea {
                id: newSubfolderDrop
                anchors.fill: parent
                onDropped: {
                    var model = EXPLORER.onDrop(mimeData)
                    if(model != "") {
                        root.createSubfolder(model, mode)
                    }
                }
            }
        }
    }
}