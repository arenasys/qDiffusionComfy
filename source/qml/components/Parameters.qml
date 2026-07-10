import QtQuick 2.15
import QtQuick.Controls 2.15
import QtGraphicalEffects 1.12
import QtQuick.Layouts 1.15
import QtQuick.Dialogs 1.0

import gui 1.0

import "../style"

Item {
    id: root
    anchors.fill: parent
    property var swap: false
    property var advanced: GUI.config != null ? GUI.config.get("advanced") : false
    property alias button: genButton

    function tr(str, file = "Parameters.qml") {
        return TRANSLATOR.instance.translate(str, file)
    }

    signal generate()
    signal enqueue()
    signal cancel()
    signal buildModel()
    signal sizeFinished()

    function sizeDrop(mimedata) {
        
    }

    function seedDrop(mimedata) {
        
    }

    property var forever: false
    property var remaining: 0

    property var binding

    Item {
        anchors.top: parent.top
        anchors.left: root.swap ? undefined : parent.left
        anchors.right: root.swap ? parent.right : undefined
        anchors.bottom: parent.bottom

        width: Math.max(150, parent.width)

        GenerateButton {
            id: genButton
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 2
            height: 40

            function sync() {
                genButton.progress = GUI.statusProgress
                genButton.working = GUI.statusMode == 2 || GUI.statusMode == 5 || genButton.remaining > 0
            }

            Timer {
                id: genButtonTimer
                interval: 100
                onTriggered: {
                    genButton.sync()
                }
            }
            Connections {
                target: GUI
                function onStatusProgressChanged() {
                    genButtonTimer.restart()
                }
                function onStatusModeChanged() {
                    genButtonTimer.restart()
                }
            }

            progress: -1
            working: false
            disabled: (GUI.statusMode != 1 && GUI.statusMode != 2 && GUI.statusMode != 5) || GUI.modelCount == 0
            info: GUI.statusInfo
            remaining: root.remaining

            onRemainingChanged: {
                genButtonTimer.restart()
            }

            onPressed: {
                if(GUI.statusMode == 1) {
                    root.generate()
                } else if(GUI.statusMode == 2) {
                    root.cancel()
                }
                genButton.sync()
            }

            onContextMenu: {
                genContextMenu.popup()
            }

            SContextMenu {
                id: genContextMenu
                SContextMenuItem {
                    text: root.tr("Generate Forever")
                    checkable: true
                    onCheckedChanged: {
                        root.forever = checked
                    }
                }
                SContextMenuItem {
                    text: root.tr("Add to Queue")
                    onPressed: {
                        root.enqueue()
                    }

                }
                SContextMenuItem {
                    height: visible ? 20 : 0
                    visible: GUI.statusMode == 2
                    text: root.tr("Cancel")
                    onPressed: {
                        root.cancel()
                    }
                }
            }
        }
        
        Rectangle {
            id: generateDivider
            anchors.top: genButton.bottom
            anchors.topMargin: 2
            anchors.left: parent.left
            anchors.right: parent.right
            height: 4
            color: COMMON.bg4
        }

        Flickable {
            id: paramScroll
            anchors.top: generateDivider.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true

            contentHeight: paramColumn.height
            contentWidth: parent.width
            boundsBehavior: Flickable.StopAtBounds
            interactive: false

            ScrollBar.vertical: SScrollBarV {
                id: paramScrollBar
                padding: 0
                barWidth: 2

                policy: ScrollBar.AlwaysOff
                totalLength: paramScroll.contentHeight
                incrementLength: 40
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: {
                    paramScrollBar.doIncrement(wheel.angleDelta.y)
                }
            }

            property var positionTarget: null
            function position(item) {
                var yy = paramColumn.mapFromItem(item, 0, item.height).y
                if(yy > paramScroll.contentY && yy < paramScroll.contentY + paramScroll.height) {
                    return
                }
                if(yy - paramScroll.height < 0) {
                    return
                }
                paramScroll.contentY = yy - paramScroll.height
            }

            function targetPosition(item) {
                positionTarget = item
            }

            onContentHeightChanged: {
                if(positionTarget != null) {
                    position(positionTarget)
                }
            }

            Column {
                id: paramColumn
                width: paramScroll.width
                OColumn {
                    id: optColumn
                    text: root.tr("Options")
                    width: parent.width
                    property var typ: ""
                    property var isHR: typ.startsWith("Txt2Img + HR");
                    property var couldHR: typ.startsWith("Txt2Img");
                    property var isImg: typ == "Img2Img" || typ == "Inpainting" || typ == "Upscaling" || typ.endsWith("Detail");
                    property var isInp: typ == "Inpainting" || typ.endsWith("Detail");
                    property var isCFGPP: samplerColumn.sampler.endsWith("CFG++")

                    property var maxSize: 2048
                    function updateMaxSize() {
                        var mx = Math.max(widthInput.value, heightInput.value)
                        var n = maxSize
                        if(mx < 2048) {
                            n = 2048
                        } else if(mx >= 2048) {
                            n = 8192
                        }
                        if(n != maxSize) {
                            maxSize = n
                            sizePulser.restart()
                        }
                    }

                    SAnimation {
                        id: sizePulser
                        minValue: 0.0
                        maxValue: 0.15
                        duration: 500
                        fps: 30
                        pulse: true
                    }

                    input: Item {
                        width: optColumn.width - 100
                        height: 30
                        clip: true
                        SText {
                            id: typLabel
                            text: ""
                            anchors.fill: parent
                            color: COMMON.fg2
                            pointSize: 9.2
                            opacity: 0.7
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideRight

                            Timer {
                                id: typCooldown
                                interval: 100
                                triggeredOnStart: true
                                onTriggered: {
                                    typLabel.text = BASIC.getRequestType()
                                    optColumn.typ = typLabel.text
                                }
                            }

                            function sync() {
                                if(typCooldown.running) {
                                    return
                                }
                                typCooldown.start()
                            }

                            Component.onCompleted: {
                                sync()
                            }

                            Connections {
                                target: BASIC.parameters.values
                                function onUpdated() {
                                    typLabel.sync()
                                }
                            }

                            Connections {
                                target: BASIC.parameters
                                function onUpdated() {
                                    typLabel.sync()
                                }
                            }

                            Connections {
                                target: BASIC
                                function onInputsChanged() {
                                    typLabel.sync()
                                }
                                function onTypeUpdated() {
                                    typLabel.sync()
                                }
                            }

                        }
                    }

                    onExpanded: {
                        paramScroll.targetPosition(optColumn)
                    }

                    OSlider {
                        id: widthInput
                        label: root.tr("Width")
                        width: parent.width
                        height: 30

                        bindMap: root.binding.values
                        bindKey: "width"

                        minValue: 64
                        maxValue: optColumn.maxSize
                        precValue: 0
                        incValue: 8
                        snapValue: 64
                        bounded: false

                        indicatorHighlight.opacity: sizePulser.value
                        indicatorHighlight.visible: sizePulser.running

                        onFinished: {
                            root.sizeFinished()
                        }

                        onEditted: {
                            optColumn.updateMaxSize()
                        }

                        property real rightDragAspectRatio: 1

                        onRightDragStarted: {
                            rightDragAspectRatio = widthInput.value / heightInput.value
                        }

                        onRightDragUpdated: {
                            heightInput.setValue(widthInput.value / rightDragAspectRatio, heightInput.incValue, false)
                        }

                        AdvancedDropArea {
                            anchors.fill: parent

                            onDropped: {
                                root.sizeDrop(mimeData)
                            }
                        }
                    }
                    OSlider {
                        id: heightInput
                        label: root.tr("Height")
                        width: parent.width
                        height: 30

                        bindMap: root.binding.values
                        bindKey: "height"

                        minValue: 64
                        maxValue: optColumn.maxSize
                        precValue: 0
                        incValue: 8
                        snapValue: 64
                        bounded: false

                        indicatorHighlight.opacity: sizePulser.value
                        indicatorHighlight.visible: sizePulser.running

                        onFinished: {
                            root.sizeFinished()
                        }

                        onEditted: {
                            optColumn.updateMaxSize()
                        }

                        property real rightDragAspectRatio: 1

                        onRightDragStarted: {
                            rightDragAspectRatio = widthInput.value / heightInput.value
                        }

                        onRightDragUpdated: {
                            widthInput.setValue(heightInput.value * rightDragAspectRatio, widthInput.incValue, false)
                        }
                        
                        AdvancedDropArea {
                            anchors.fill: parent

                            onDropped: {
                                root.sizeDrop(mimeData)
                            }
                        }
                    }
                    OSlider {
                        id: stepsInput
                        label: root.tr("Steps")
                        width: parent.width
                        height: 30

                        bindMap: root.binding.values
                        bindKey: "steps"

                        minValue: 0
                        maxValue: 100
                        precValue: 0
                        incValue: 1
                        snapValue: 5
                        bounded: false
                    }
                    OSlider {
                        id: scaleInput
                        label: root.tr("Scale")
                        width: parent.width
                        height: 30
                        
                        bindMap: root.binding.values
                        bindKey: "scale"

                        minValue: 1
                        maxValue: optColumn.isCFGPP ? 4 : 20
                        precValue: optColumn.isCFGPP ? 2 : 1
                        incValue: optColumn.isCFGPP ? 0.05 : 1
                        snapValue: optColumn.isCFGPP ? 0.05 : 0.5

                        bounded: false
                    }
                    OTextInput {
                        id: seedInput
                        label: root.tr("Seed")
                        width: parent.width
                        height: 30

                        bindMap: root.binding.values
                        bindKey: "seed"

                        validator: RegExpValidator {
                            regExp: /-1||\d{1,10}/
                        }

                        AdvancedDropArea {
                            anchors.fill: parent

                            onDropped: {
                                root.seedDrop(mimeData)
                            }
                        }

                        override: value == "-1" && !active ? "Random" : ""
                    }
                }
                OColumn {
                    id: samplerColumn
                    text: root.tr("Sampler")
                    width: parent.width
                    isCollapsed: false
                    property var sampler: ""
                    property var scheduler: ""
                    onExpanded: {
                        paramScroll.targetPosition(samplerColumn)
                    }

                    input: OChoice {
                        id: samplerInput
                        label: ""
                        height: 28
                        width: samplerColumn.width - 100

                        bindMap: root.binding.values
                        bindKeyCurrent: "sampler"
                        bindKeyModel: "samplers"

                        onValueChanged: {
                            samplerColumn.sampler = samplerInput.value
                        }
                    }

                    OChoice {
                        id: schedulerInput
                        label: root.tr("Scheduler")
                        width: parent.width
                        height: 30
                        
                        bindMap: root.binding.values
                        bindKeyCurrent: "scheduler"
                        bindKeyModel: "schedulers"

                        property var last: null

                        onSelected: {
                            if(value != "Linear") {
                                last = value
                            } else {
                                last = null
                            }
                        }

                        onOptionsChanged: {
                            if(model != null && last != null) {
                                var idx = model.indexOf(last)
                                if(idx >= 0) {
                                    currentIndex = idx
                                }
                            }
                        }

                        onValueChanged: {
                            samplerColumn.scheduler = schedulerInput.value == "Linear" ? "" : (" " + schedulerInput.value)
                        }

                        function display(text) {
                            return root.tr(text, "Options")
                        }
                    }
                }
                OColumn {
                    id: modelColumn
                    text: root.tr("Model")
                    width: parent.width
                    isCollapsed: false

                    onExpanded: {
                        paramScroll.targetPosition(modelColumn)
                    }

                    property var models: root.binding.values.get("models")

                    OChoice {
                        id: modelModeInput
                        label: root.tr("Mode")
                        width: parent.width
                        height: 30

                        bindMap: root.binding.values
                        bindKeyCurrent: "model_mode"
                        bindKeyModel: "model_modes"

                        function display(text) {
                            return text.charAt(0).toUpperCase() + text.slice(1)
                        }
                    }
                    OChoice {
                        id: unetInput
                        label: modelModeInput.value == "component" ? root.tr("UNET") : root.tr("Checkpoint")
                        width: parent.width
                        height: 30
                        
                        bindMap: root.binding.values
                        bindKeyCurrent: "UNET"
                        bindKeyModel: "UNETs"

                        popupHeight: root.height + 100

                        placeholderValue: "No models"

                        function decoration(value) {
                            return GUI.modelSubfolder(value)
                        }

                        function display(text) {
                            return GUI.modelName(text)
                        }

                        onSelected: {
                            root.binding.values.set("model", value)
                        }
                    }
                    OChoice {
                        id: vaeInput
                        label: root.tr("VAE")
                        width: parent.width
                        height: modelModeInput.value == "component" ? 30 : 0
                        visible: modelModeInput.value == "component"

                        bindMap: root.binding.values
                        bindKeyCurrent: "VAE"
                        bindKeyModel: "VAEs"

                        popupHeight: root.height + 100

                        placeholderValue: "No models"

                        function decoration(value) {
                            return GUI.modelSubfolder(value)
                        }

                        function display(text) {
                            return GUI.modelName(text)
                        }
                    }
                    OChoice {
                        id: clipInput
                        label: root.tr("CLIP")
                        width: parent.width
                        height: modelModeInput.value == "component" ? 30 : 0
                        visible: modelModeInput.value == "component"

                        bindMap: root.binding.values
                        bindKeyCurrent: "CLIP"
                        bindKeyModel: "CLIPs"

                        popupHeight: root.height + 100

                        placeholderValue: "No models"

                        function decoration(value) {
                            return GUI.modelSubfolder(value)
                        }

                        function display(text) {
                            return GUI.modelName(text)
                        }
                    }
                    OChoice {
                        id: clipTypeInput
                        label: root.tr("Type")
                        width: parent.width
                        height: modelModeInput.value == "component" ? 30 : 0
                        visible: modelModeInput.value == "component"

                        bindMap: root.binding.values
                        bindKeyCurrent: "clip_type"
                        bindKeyModel: "clip_types"

                        function display(text) {
                            return text
                        }
                    }
                }

                OColumn {
                    id: netColumn
                    text: root.tr("Networks")
                    width: parent.width
                    padding: false
                    isCollapsed: false

                    onExpanded: {
                        paramScroll.targetPosition(netColumn)
                    }

                    Item {
                        width: parent.width
                        height: Math.min(200, 32+(netList.contentHeight == 0 ? 0 : netList.contentHeight+3))

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            color: "transparent"
                            border.color: COMMON.bg4
                            border.width: 1

                            Item {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 1
                                id: netAdd
                                height: 27

                                Rectangle {
                                    anchors.fill: parent
                                    color: COMMON.bg2
                                }

                                OChoice {
                                    id: netChoice
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    anchors.left: addButton.right
                                    anchors.right: parent.right
                                    anchors.margins: 0
                                    anchors.topMargin: -1
                                    padded: false
                                    label: ""

                                    placeholderValue: "No networks"

                                    entries: GUI.filterFavourites(root.binding.availableNetworks)

                                    Connections {
                                        target: GUI
                                        function onFavUpdated() {
                                            netChoice.entries = GUI.filterFavourites(root.binding.availableNetworks)
                                        }
                                    }

                                    function display(text) {
                                        return GUI.modelName(text)
                                    }

                                    function decoration(value) {
                                        return GUI.modelSubfolder(value)
                                    }
                                }

                                SIconButton {
                                    id: addButton
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    width: height
                                    icon: "qrc:/icons/plus.svg"
                                    color: COMMON.bg4
                                    iconColor: COMMON.bg6

                                    onPressed: {
                                        root.binding.addNetwork(netChoice.model[netChoice.currentIndex])
                                    }
                                }
                            }

                            ListView {
                                id: netList
                                anchors.top: netAdd.bottom
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins:1
                                anchors.topMargin: 0
                                clip: true
                                model: root.binding.activeNetworks

                                boundsBehavior: Flickable.StopAtBounds

                                ScrollBar.vertical: SScrollBarV {
                                    id: netScrollBar
                                    totalLength: netList.contentHeight
                                    showLength: netList.height
                                    incrementLength: 25
                                }

                                delegate: Item {
                                    width: netList.width
                                    height: 25

                                    property var selected: false

                                    Rectangle {
                                        anchors.fill: parent
                                        color: selected ? COMMON.bg2 : Qt.darker(COMMON.bg2, 1.25) 
                                    }

                                    ParametersNetItem {
                                        anchors.fill: parent
                                        anchors.rightMargin: netScrollBar.showing ? 8 : 0
                                        label: GUI.modelName(modelData)
                                        type: GUI.netType(modelData)
                                        decoration: GUI.modelSubfolder(modelData)

                                        onDeactivate: {
                                            root.binding.deleteNetwork(index)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                OColumn {
                    id: ipColumn
                    text: root.tr("Inpainting")
                    width: parent.width
                    isCollapsed: false

                    onExpanded: {
                        paramScroll.targetPosition(ipColumn)
                    }

                    OSlider {
                        id: strengthInput
                        label: root.tr("Strength")
                        width: parent.width
                        height: 30
                        
                        bindMap: root.binding.values
                        bindKey: "strength"

                        disabled: !optColumn.isImg

                        minValue: 0
                        maxValue: 1
                        precValue: 2
                        incValue: 0.01
                        snapValue: 0.05
                    }

                    OSlider {
                        id: paddingInput
                        label: root.tr("Padding")
                        width: parent.width
                        height: 30
                        overlay: value == -1 && !paddingInput.active

                        bindMap: root.binding.values
                        bindKey: "padding"

                        disabled: !optColumn.isInp

                        minValue: -1
                        maxValue: 512
                        precValue: 0
                        incValue: 8
                        snapValue: 16
                        bounded: false

                        override: value == "-1" && !active ? "Full" : ""
                    }

                    OSlider {
                        label: root.tr("Mask Blur")
                        width: parent.width
                        height: 30

                        bindMap: root.binding.values
                        bindKey: "mask_blur"

                        disabled: !optColumn.isInp

                        minValue: 0
                        maxValue: 10
                        precValue: 0
                        incValue: 1
                        snapValue: 1
                        bounded: false
                    }

                    OSlider {
                        label: root.tr("Mask Expand")
                        width: parent.width
                        height: 30

                        bindMap: root.binding.values
                        bindKey: "mask_expand"

                        disabled: !optColumn.isInp

                        minValue: 0
                        maxValue: 10
                        precValue: 0
                        incValue: 1
                        snapValue: 1
                        bounded: false
                    }

                    OChoice {
                        label: root.tr("Upscaler")
                        width: parent.width
                        height: 30

                        bindMap: root.binding.values
                        bindKeyCurrent: "upscaler"
                        bindKeyModel: "upscalers"

                        disabled: !(optColumn.typ == "Img2Img" || optColumn.typ == "Inpainting" || optColumn.typ == "Upscaling")

                        function display(text) {
                            return text === "default" ? root.tr("Default", "Options") : GUI.modelName(text)
                        }

                        function decoration(value) {
                            return value === "default" ? "" : GUI.modelSubfolder(value)
                        }
                    }
                }

                OColumn {
                    id: opColumn
                    text: root.tr("Operation")
                    width: parent.width
                    isCollapsed: false

                    onExpanded: {
                        paramScroll.targetPosition(opColumn)
                    }

                    OChoice {
                        label: root.tr("Preview")
                        width: parent.width
                        height: 30

                        bindMap: root.binding.values
                        bindKeyCurrent: "preview_mode"
                        bindKeyModel: "preview_modes"

                        onSelected: {
                            GUI.config.set("previews", value)
                        }

                        function display(text) {
                            return root.tr(text, "Options")
                        }
                    }

                    OChoice {
                        label: root.tr("Device")
                        width: parent.width
                        height: 30

                        bindMap: root.binding.values
                        bindKeyCurrent: "device"
                        bindKeyModel: "devices"

                        onSelected: {
                            GUI.config.set("device", value)
                        }
                    }

                    OTextInput {
                        label: root.tr("Output Folder")
                        width: parent.width
                        height: 30
                        placeholder: root.tr("Default", "Options")

                        bindMap: root.binding.values
                        bindKey: "output_folder"

                        onFinished: {
                            GUI.config.set("output_folder", value)
                        }
                    }
                }
            }
        }
    }
}