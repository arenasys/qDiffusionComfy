import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt.labs.platform 1.1

import gui 1.0

import "../style"

SMenuBar {
    id: root

    function tr(str, file = "WindowBar.qml") {
        return TRANSLATOR.instance.translate(str, file)
    }

    SMenu {
        id: menu
        title: root.tr("File")
        clipShadow: true

        SMenuItem {
            text: root.tr("Update")
            onPressed: {
                GUI.currentTab = "Settings"
                SETTINGS.currentTab = "Program"
                SETTINGS.update()
            }
        }
        SMenuItem {
            text: root.tr("Reload")
            shortcut: "Ctrl+R"
            global: true
            onPressed: {
                SETTINGS.restart()
            }

        }
        SMenuSeparator {}
        SMenuItem {
            text: root.tr("Quit")
            shortcut: "Ctrl+Shift+Q"
            global: true
            onPressed: {
                GUI.quit()
            }
        }
    }
    SMenu {
        title: root.tr("Edit")
        clipShadow: true
        SMenuItem {
            text: root.tr("Refresh models")

            onPressed: {
                GUI.refreshModels()
            }
        }
    }
    SMenu {
        title: root.tr("View")
        clipShadow: true
        SMenuItem {
            visible: GUI.currentTab == "Generate"
            text: root.tr("Swap side")
            checkable: true
            checked: GUI.config != null ? GUI.config.get("swap") : false
            onCheckedChanged: {
                GUI.config.set("swap", checked)
                checked = Qt.binding(function () { return GUI.config != null ? GUI.config.get("swap") : false; })
            }
        }

        SMenuItem {
            visible: GUI.currentTab == "Generate"
            text: root.tr("Autocomplete")
            checkable: true
            checked: GUI.config != null ? GUI.config.get("autocomplete") > 0 : false
            onCheckedChanged: {
                if(GUI.config.get("autocomplete") > 0 == checked) {
                    return
                }

                if(checked) {
                    GUI.config.set("autocomplete", 1)
                } else {
                    GUI.config.set("autocomplete", 0)
                }
                checked = Qt.binding(function () { return GUI.config != null ? GUI.config.get("autocomplete") > 0 : false; })
            }
        }

        SMenuItem {
            visible: GUI.currentTab == "Models"
            text: root.tr("Thumbails")
            shortcut: "Shift"
            checkable: true
            checked: !EXPLORER.showInfo
            onCheckedChanged: {
                if(checked != !EXPLORER.showInfo) {
                    EXPLORER.showInfo = !checked
                    checked = Qt.binding(function () { return !EXPLORER.showInfo; })
                }
            }
        }
        SMenuItem {
            visible: GUI.currentTab == "Models"
            text: root.tr("Zoom in")
            shortcut: "Ctrl+="
            onPressed: {
                EXPLORER.adjustCellSize(100)
            }
        }
        SMenuItem {
            visible: GUI.currentTab == "Models"
            text: root.tr("Zoom out")
            shortcut: "Ctrl+-"
            onPressed: {
                EXPLORER.adjustCellSize(-100)
            }
        }

        SMenuItem {
            visible: GUI.currentTab == "History"
            text: root.tr("Zoom in")
            shortcut: "Ctrl+="
            onPressed: {
                GALLERY.adjustCellSize(50)
            }
        }
        SMenuItem {
            visible: GUI.currentTab == "History"
            text: root.tr("Zoom out")
            shortcut: "Ctrl+-"
            onPressed: {
                GALLERY.adjustCellSize(-50)
            }
        }
    }
    SMenu {
        title: root.tr("Help")
        clipShadow: true

        SMenuItem {
            text: root.tr("About")
            onPressed: {
                GUI.openLink("https://github.com/arenasys/qDiffusion")
            }
        }
    }
}