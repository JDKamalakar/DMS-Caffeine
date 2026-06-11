import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Services
import qs.Modules.Plugins
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes

PluginComponent {
    id: root
    pluginId: "caffeine"
    pluginService: PluginService

    // Reactive states
    readonly property bool caffeineActive: globalIsActive.value
    property string selectedDuration: {
        if (pluginData && pluginData.selectedDuration !== undefined && pluginData.selectedDuration !== null && pluginData.selectedDuration !== "undefined" && pluginData.selectedDuration !== "") {
            return pluginData.selectedDuration;
        }
        let def = pluginData?.defaultDuration ?? "infinity";
        def = def.trim().toLowerCase();
        if (def === "infinity" || def === "infinite" || def === "inf" || def === "") {
            return "infinity";
        }
        const mins = parseInt(def);
        if (!isNaN(mins) && mins > 0) {
            return (mins * 60).toString();
        }
        return "infinity";
    }
    readonly property int timeLeft: globalTimeLeft.value

    PluginGlobalVar {
        id: globalIsActive
        varName: "isActive"
        defaultValue: false
    }

    PluginGlobalVar {
        id: globalTimeLeft
        varName: "timeLeft"
        defaultValue: 0
    }

    // Sync settings
    property bool showToasts: (pluginData.showToasts ?? true)

    property var durationOptions: {
        const rawPresets = pluginData?.presets ?? "5, 15, 30, 60, 120, infinity";
        const items = rawPresets.split(",").map(item => item.trim()).filter(Boolean);
        const result = [];
        for (const item of items) {
            if (item.toLowerCase() === "infinity" || item.toLowerCase() === "infinite" || item.toLowerCase() === "inf") {
                result.push({ label: "Infinite", value: "infinity" });
            } else {
                const mins = parseInt(item);
                if (!isNaN(mins) && mins > 0) {
                    let label = mins + " Min";
                    if (mins >= 60) {
                        const hrs = mins / 60;
                        if (hrs === 1) {
                            label = "1 Hour";
                        } else if (hrs === Math.round(hrs)) {
                            label = hrs + " Hours";
                        } else {
                            label = hrs.toFixed(1).replace(".0", "") + " Hours";
                        }
                    }
                    result.push({ label: label, value: (mins * 60).toString() });
                }
            }
        }
        return result.length > 0 ? result : [
            { label: "5 Min", value: "300" },
            { label: "15 Min", value: "900" },
            { label: "30 Min", value: "1800" },
            { label: "1 Hour", value: "3600" },
            { label: "2 Hours", value: "7200" },
            { label: "Infinite", value: "infinity" }
        ];
    }

    // Control Center Integration
    ccWidgetIcon: "local_cafe"
    ccWidgetPrimaryText: I18n.tr("Caffeine")
    ccWidgetSecondaryText: {
        // Explicitly depend on caffeineActive, selectedDuration, and timeLeft
        const active = root.caffeineActive;
        const dur = root.selectedDuration;
        const remaining = root.timeLeft;

        if (!active) return I18n.tr("Inactive")
        if (dur === "infinity" || dur === "undefined" || !dur) return I18n.tr("Indefinite")
        if (remaining <= 0) return I18n.tr("Active")
        const mins = Math.ceil(remaining / 60)
        return mins + I18n.tr("m")
    }
    ccWidgetIsActive: caffeineActive
    ccDetailHeight: {
        const rows = Math.ceil(durationOptions.length / 3);
        const headerCardHeight = 72;
        const pillHeight = 48;
        const gridSpacing = 4;
        const gridHeight = rows * pillHeight + Math.max(0, rows - 1) * gridSpacing;
        const titleHeight = 20;
        const durationCardHeight = (Theme.spacingM * 2) + titleHeight + Theme.spacingS + gridHeight;
        return Theme.spacingM + headerCardHeight + Theme.spacingM + durationCardHeight + Theme.spacingM;
    }

    readonly property color pillColor: caffeineActive ? Theme.primary : Theme.surfaceText

    horizontalBarPill: Component {
        Row {
            spacing: caffeineActive ? Theme.spacingS : 0
            DankIcon {
                name: "local_cafe"
                size: Theme.iconSizeSmall
                color: root.pillColor
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                text: root.ccWidgetSecondaryText
                color: root.pillColor
                font.pixelSize: Theme.fontSizeMedium
                anchors.verticalCenter: parent.verticalCenter
                visible: caffeineActive
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: caffeineActive ? Theme.spacingXS : 0
            DankIcon {
                name: "local_cafe"
                size: Theme.iconSizeSmall
                color: root.pillColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
            StyledText {
                text: (root.selectedDuration === "infinity" || root.selectedDuration === "undefined" || !root.selectedDuration) ? "∞" : root.ccWidgetSecondaryText
                color: root.pillColor
                font.pixelSize: Theme.fontSizeSmall
                anchors.horizontalCenter: parent.horizontalCenter
                visible: caffeineActive
            }
        }
    }

    // Click action: always open duration picker popout (via null fallback)
    pillClickAction: null

    // Right click: quick toggle stay-awake with default duration
    pillRightClickAction: function() {
        toggleCaffeine()
    }

    // Popout dimensions
    popoutWidth: 340
    popoutHeight: 0 // auto from content

    Component {
        id: caffeineHeaderComponent
        StyledRect {
            id: headerRoot
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
            border.width: 1
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
            height: 72
            
            RowLayout {
                anchors.fill: parent; anchors.margins: Theme.spacingM; spacing: Theme.spacingM
                Rectangle {
                    width: 42; height: 42; radius: 21
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                    DankIcon { name: "local_cafe"; size: 24; color: Theme.surfaceText; anchors.centerIn: parent }
                }
                Column {
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: 0
                    StyledText { text: I18n.tr("Caffeine"); font.bold: true; font.pixelSize: Theme.fontSizeLarge; color: Theme.surfaceText }
                    Item {
                        width: parent.width; height: 16
                        StyledText {
                            id: modeTxt
                            width: parent.width
                            text: root.caffeineActive ? I18n.tr("Active") : I18n.tr("Inactive")
                            font.pixelSize: Theme.fontSizeSmall - 1
                            color: Theme.primary
                            opacity: 0.85

                            onTextChanged: subtitleAnim.restart()
                            SequentialAnimation {
                                id: subtitleAnim
                                ParallelAnimation {
                                    NumberAnimation { target: modeTxt; property: "opacity"; to: 0; duration: 150; easing.type: Easing.OutQuad }
                                    NumberAnimation { target: modeTxt; property: "y"; to: 5; duration: 150; easing.type: Easing.OutQuad }
                                }
                                PropertyAction { target: modeTxt; property: "y"; value: -5 }
                                ParallelAnimation {
                                    NumberAnimation { target: modeTxt; property: "opacity"; to: 0.85; duration: 150; easing.type: Easing.InQuad }
                                    NumberAnimation { target: modeTxt; property: "y"; to: 0; duration: 150; easing.type: Easing.InQuad }
                                }
                            }
                        }
                    }
                }
                Item {
                    id: toggleBtn
                    height: 38; width: 105
                    Layout.alignment: Qt.AlignVCenter
                    
                    scale: toggleArea.pressed ? 0.9 : (toggleArea.containsMouse ? 1.05 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                    MouseArea {
                        id: toggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => toggleRipple.trigger(mouse.x, mouse.y)
                        onClicked: root.toggleCaffeine()
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: root.caffeineActive ? height / 2 : Theme.cornerRadius
                        color: root.caffeineActive 
                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                            : (toggleArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.4))
                        border.width: 1
                        border.color: root.caffeineActive 
                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.6)
                            : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, toggleArea.containsMouse ? 0.3 : 0.15)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        Behavior on radius { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        
                        DankIcon {
                            id: toggleBtnIcon
                            name: "power_settings_new"
                            size: 18
                            color: Theme.primary
                            
                            SequentialAnimation {
                                running: toggleArea.containsMouse
                                loops: Animation.Infinite
                                onStopped: toggleBtnIcon.rotation = 0
                                NumberAnimation { target: toggleBtnIcon; property: "rotation"; to: -8; duration: 150; easing.type: Easing.InOutQuad }
                                NumberAnimation { target: toggleBtnIcon; property: "rotation"; to: 8; duration: 150; easing.type: Easing.InOutQuad }
                                NumberAnimation { target: toggleBtnIcon; property: "rotation"; to: 0; duration: 150; easing.type: Easing.InOutQuad }
                                PauseAnimation { duration: 400 }
                            }
                        }
                        
                        StyledText {
                            text: root.caffeineActive ? I18n.tr("Turn Off") : I18n.tr("Turn On")
                            color: Theme.primary
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    DankRipple {
                        id: toggleRipple
                        rippleColor: Theme.surfaceText
                        cornerRadius: Theme.cornerRadius
                        anchors.fill: parent
                    }
                }
            }
        }
    }

    Component {
        id: durationGridComponent
        StyledRect {
            id: gridRoot
            height: durationCol.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
            border.width: 1
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)

            Column {
                id: durationCol
                width: parent.width - Theme.spacingM * 2
                x: Theme.spacingM
                y: Theme.spacingM
                spacing: Theme.spacingS

                RowLayout {
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: 4; anchors.rightMargin: 4
                    spacing: Theme.spacingXS
                    DankIcon { name: "timer"; size: 14; color: Theme.surfaceText }
                    StyledText { text: I18n.tr("Keep Awake Duration"); font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.surfaceText; Layout.fillWidth: true }
                }

                Flow {
                    id: durationGrid
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: root.durationOptions

                        delegate: Item {
                            required property var modelData
                            required property int index

                            readonly property int total: root.durationOptions.length
                            readonly property int cols: 3
                            readonly property int r: Math.floor(index / cols)
                            readonly property int c: index % cols
                            readonly property int maxR: Math.floor((total - 1) / cols)
                            
                            readonly property bool isLastItem: index === total - 1
                            readonly property int itemsInLastRow: total % cols === 0 ? cols : total % cols

                            width: {
                                const baseWidth = Math.max(0, durationGrid.width - durationGrid.spacing * 2) / 3;
                                if (isLastItem) {
                                    if (itemsInLastRow === 1) return Math.max(0, durationGrid.width);
                                    if (itemsInLastRow === 2) return Math.max(0, durationGrid.width - baseWidth - durationGrid.spacing);
                                }
                                return baseWidth;
                            }
                            height: 48
                            
                            readonly property bool isSelected: String(root.selectedDuration) === String(modelData.value)
                            readonly property bool hovered: optionMouseArea.containsMouse
                            
                            Shape {
                                id: durationBg
                                anchors.fill: parent

                                readonly property bool isTop: r === 0
                                readonly property bool isBottom: r === maxR
                                readonly property bool isLeft: c === 0
                                readonly property bool isRight: c === cols - 1 || index === total - 1
                                
                                property real innerRadius: 6
                                property real outerRadius: 12
                                
                                property real pillRadius: Math.floor((height - 1) / 2)
                                property real tlr: isSelected ? pillRadius : (isTop && isLeft ? outerRadius : innerRadius)
                                property real trr: isSelected ? pillRadius : (isTop && isRight ? outerRadius : innerRadius)
                                property real blr: isSelected ? pillRadius : (isBottom && isLeft ? outerRadius : innerRadius)
                                property real brr: isSelected ? pillRadius : (isBottom && isRight ? outerRadius : innerRadius)

                                property real tlrAnim: tlr; Behavior on tlrAnim { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }
                                property real trrAnim: trr; Behavior on trrAnim { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }
                                property real blrAnim: blr; Behavior on blrAnim { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }
                                property real brrAnim: brr; Behavior on brrAnim { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }

                                property color paintColor: {
                                    if (typeof popoutScope !== 'undefined' && popoutScope.activeFocus && popoutScope.currentIndex === index) return Theme.primaryPressed;
                                    return isSelected
                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                                        : (hovered
                                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                                            : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.04))
                                }
                                Behavior on paintColor { ColorAnimation { duration: 150 } }
                                
                                property color paintBorder: isSelected
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.6)
                                    : (hovered
                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4)
                                        : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15))
                                Behavior on paintBorder { ColorAnimation { duration: 150 } }

                                ShapePath {
                                    fillColor: durationBg.paintColor
                                    strokeColor: durationBg.paintBorder
                                    strokeWidth: 1
                                    
                                    startX: 0.5 + durationBg.tlrAnim
                                    startY: 0.5
                                    PathLine { x: durationBg.width - 0.5 - durationBg.trrAnim; y: 0.5 }
                                    PathArc { x: durationBg.width - 0.5; y: 0.5 + durationBg.trrAnim; radiusX: durationBg.trrAnim; radiusY: durationBg.trrAnim; direction: PathArc.Clockwise }
                                    PathLine { x: durationBg.width - 0.5; y: durationBg.height - 0.5 - durationBg.brrAnim }
                                    PathArc { x: durationBg.width - 0.5 - durationBg.brrAnim; y: durationBg.height - 0.5; radiusX: durationBg.brrAnim; radiusY: durationBg.brrAnim; direction: PathArc.Clockwise }
                                    PathLine { x: 0.5 + durationBg.blrAnim; y: durationBg.height - 0.5 }
                                    PathArc { x: 0.5; y: durationBg.height - 0.5 - durationBg.blrAnim; radiusX: durationBg.blrAnim; radiusY: durationBg.blrAnim; direction: PathArc.Clockwise }
                                    PathLine { x: 0.5; y: 0.5 + durationBg.tlrAnim }
                                    PathArc { x: 0.5 + durationBg.tlrAnim; y: 0.5; radiusX: durationBg.tlrAnim; radiusY: durationBg.tlrAnim; direction: PathArc.Clockwise }
                                }
                                
                                Rectangle { 
                                    anchors.fill: parent; radius: parent.tlrAnim; color: "white"
                                    anchors.margins: 0.5
                                    opacity: hovered ? 0.05 : 0; Behavior on opacity { NumberAnimation { duration: 150 } } 
                                }
                            }

                            DankRipple { id: optionRipple; anchors.fill: parent; cornerRadius: durationBg.tlrAnim; rippleColor: Theme.primary }

                            MouseArea {
                                id: optionMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: function(mouse) { optionRipple.trigger(mouse.x, mouse.y); }
                                onClicked: {
                                    if (typeof popoutScope !== 'undefined') popoutScope.currentIndex = index
                                    const isSel = String(root.selectedDuration) === String(modelData.value)
                                    if (isSel) {
                                        root.toggleCaffeine(modelData.value)
                                        if (typeof popoutScope !== 'undefined') closePopout()
                                    } else {
                                        root.changeDuration(modelData.value)
                                    }
                                }
                            }

                            StyledText {
                                text: modelData.label
                                color: isSelected ? Theme.primary : Theme.surfaceText
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: isSelected ? Font.Bold : Font.Normal
                                anchors.centerIn: parent
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }

                            Keys.onReturnPressed: function(event) {
                                if (typeof popoutScope !== 'undefined') {
                                    popoutScope.currentIndex = index
                                    root.changeDuration(modelData.value)
                                    event.accepted = true
                                }
                            }
                            Keys.onSpacePressed: function(event) {
                                if (typeof popoutScope !== 'undefined') {
                                    popoutScope.currentIndex = index
                                    root.changeDuration(modelData.value)
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }
            }
        }
    }



    // Popout content: duration selector grid
    popoutContent: Component {
        PopoutComponent {
            id: detailPopout
            headerText: ""
            detailsText: ""
            showCloseButton: false

            Loader {
                width: parent.width
                asynchronous: true
                sourceComponent: popoutInternal
                
                opacity: status === Loader.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 100 } }
            }
        }
    }

    Component {
        id: popoutInternal
        FocusScope {
            id: popoutScope
            width: parent.width
            implicitHeight: popoutMainCol.implicitHeight + 2
            property int currentIndex: 0

            // Keyboard navigation
            Keys.onPressed: function(event) {
                const cols = 3
                const count = root.durationOptions.length
                let idx = popoutScope.currentIndex
                if (event.key === Qt.Key_Right) {
                    idx = (idx + 1) % count
                    event.accepted = true
                } else if (event.key === Qt.Key_Left) {
                    idx = (idx - 1 + count) % count
                    event.accepted = true
                } else if (event.key === Qt.Key_Down) {
                    idx = Math.min(idx + cols, count - 1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Up) {
                    idx = Math.max(idx - cols, 0)
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                    if (idx >= 0 && idx < count) {
                        root.changeDuration(root.durationOptions[idx].value)
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_Escape) {
                    closePopout()
                    event.accepted = true
                }
                if (event.accepted) {
                    popoutScope.currentIndex = idx
                }
            }

            Column {
                id: popoutMainCol
                width: parent.width
                topPadding: 0
                bottomPadding: 2
                spacing: Theme.spacingM

                // --- Caffeine Header Card ---
                Loader {
                    width: parent.width
                    sourceComponent: caffeineHeaderComponent
                }

                // --- Duration Grid Section ---
                Loader {
                    width: parent.width
                    sourceComponent: durationGridComponent
                }
            }
        }
    }

    onCcWidgetToggled: {
        toggleCaffeine()
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            globalTimeLeft.set(globalTimeLeft.value - 1);
            if (globalTimeLeft.value <= 0) {
                countdownTimer.stop();
                toggleCaffeine(); // Turn off caffeine
            }
        }
    }

    // Sync with system state on startup
    Component.onCompleted: {
        Proc.runCommand("check-caffeine-active", ["pgrep", "-f", "DMS Caffeine"], function(output, exitCode) {
            const isActive = (exitCode === 0 && output.trim() !== "");
            if (isActive) {
                globalIsActive.set(true);
                const expiration = pluginService ? pluginService.loadPluginState(pluginId, "expiration", 0) : 0;
                if (expiration > Date.now()) {
                    globalTimeLeft.set(Math.round((expiration - Date.now()) / 1000));
                    countdownTimer.start();
                }
            } else {
                globalIsActive.set(false);
                if (pluginService) {
                    pluginService.savePluginState(pluginId, "expiration", 0);
                }
            }
        })
    }

    function formatDurationLabel(dur) {
        if (dur === "infinity") return I18n.tr("indefinitely");
        const secs = parseInt(dur);
        if (isNaN(secs) || secs <= 0) return dur;
        const mins = secs / 60;
        if (mins < 60) {
            return mins + " " + I18n.tr("minutes");
        }
        const hrs = mins / 60;
        if (hrs === 1) return I18n.tr("1 hour");
        return hrs.toFixed(1).replace(".0", "") + " " + I18n.tr("hours");
    }

    function changeDuration(newDuration) {
        if (newDuration === undefined || newDuration === null || newDuration === "undefined" || newDuration === "") return;
        selectedDuration = newDuration;
        if (pluginService) {
            pluginService.savePluginData(pluginId, "selectedDuration", newDuration);
        }

        if (caffeineActive) {
            // Keep active, but update the duration!
            // 1. Kill the old process
            Proc.runCommand("deactivate-caffeine", ["pkill", "-f", "DMS Caffeine"], null, 0);

            // 2. Start the new process with new duration
            const args = [
                "systemd-inhibit", 
                "--what=idle", 
                "--who=DMS Caffeine", 
                "--why=Manual stay awake override"
            ];
            if (newDuration === "infinity") {
                args.push("sleep", "infinity");
            } else {
                args.push("sleep", newDuration);
            }
            Quickshell.execDetached(args);

            // 3. Update timer
            countdownTimer.stop();
            if (newDuration !== "infinity") {
                const durationSecs = parseInt(newDuration);
                globalTimeLeft.set(durationSecs);
                const expiration = Date.now() + durationSecs * 1000;
                if (pluginService) {
                    pluginService.savePluginState(pluginId, "expiration", expiration);
                }
                countdownTimer.restart();
            } else {
                if (pluginService) {
                    pluginService.savePluginState(pluginId, "expiration", 0);
                }
            }

            if (showToasts) {
                ToastService?.showSuccess(I18n.tr("Duration updated: stay awake for ") + formatDurationLabel(newDuration) + ".")
            }
        }
    }

    function toggleCaffeine(duration) {
        let targetDuration = duration !== undefined ? duration : selectedDuration;
        if (targetDuration === undefined || targetDuration === null || targetDuration === "undefined" || targetDuration === "") {
            targetDuration = "infinity";
        }
        if (globalIsActive.value) {
            // Deactivate
            globalIsActive.set(false); // Set synchronously to avoid race conditions
            countdownTimer.stop();
            if (pluginService) {
                pluginService.savePluginState(pluginId, "expiration", 0);
            }
            Proc.runCommand("deactivate-caffeine", ["pkill", "-f", "DMS Caffeine"], function(output, exitCode) {
                if (showToasts) {
                    ToastService?.showInfo(I18n.tr("Screen sleep is now allowed."))
                }
            })
        } else {
            // Activate
            const args = [
                "systemd-inhibit", 
                "--what=idle", 
                "--who=DMS Caffeine", 
                "--why=Manual stay awake override"
            ];
            if (targetDuration === "infinity") {
                args.push("sleep", "infinity");
            } else {
                args.push("sleep", targetDuration);
            }
            Quickshell.execDetached(args);
            
            if (targetDuration !== "infinity") {
                const durationSecs = parseInt(targetDuration);
                globalTimeLeft.set(durationSecs);
                const expiration = Date.now() + durationSecs * 1000;
                if (pluginService) {
                    pluginService.savePluginState(pluginId, "expiration", expiration);
                }
                countdownTimer.restart();
            } else {
                if (pluginService) {
                    pluginService.savePluginState(pluginId, "expiration", 0);
                }
            }

            globalIsActive.set(true);
            
            if (showToasts) {
                ToastService?.showSuccess(targetDuration === "infinity" ? I18n.tr("Screen will stay awake.") : I18n.tr("Screen will stay awake for ") + formatDurationLabel(targetDuration) + ".")
            }
        }
    }

    ccDetailContent: Component {
        ScrollView {
            width: parent.width
            height: parent.height
            clip: false
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff

            Loader {
                width: parent.width
                asynchronous: true
                sourceComponent: ccDetailInternal
                
                opacity: status === Loader.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 20 } }
            }
        }
    }

    Component {
        id: ccDetailInternal
        Column {
            id: ccDetailCol
            width: parent.width
            padding: Theme.spacingM
            spacing: Theme.spacingM

            // --- Caffeine Header Card ---
            Loader {
                width: Math.max(0, parent.width - Theme.spacingM * 2)
                anchors.horizontalCenter: parent.horizontalCenter
                sourceComponent: caffeineHeaderComponent
            }

            // --- Duration Grid Section ---
            Loader {
                width: Math.max(0, parent.width - Theme.spacingM * 2)
                anchors.horizontalCenter: parent.horizontalCenter
                sourceComponent: durationGridComponent
            }
        }
    }
}
