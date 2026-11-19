import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Services
import qs.Modules.Plugins
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import "."

PluginComponent {
    id: root
    pluginId: "caffeineRedesigned"
    pluginService: PluginService

    property string variantId: ""
    property var variantData: null
    readonly property bool isStatusWidgetVariant: variantId === "status_timer" || variantId === "status_widget" || (variantData && variantData.widgetDisplayMode === "status_timer")
    readonly property bool isBarVertical: (typeof isVertical !== "undefined" && isVertical) || (axis && axis.isVertical)

    // Reactive states from DMS SessionService
    readonly property bool caffeineActive: SessionService.idleInhibited
    property string selectedDuration: {
        if (caffeineActive) {
            return (globalSelectedDuration.value && globalSelectedDuration.value !== "undefined" && globalSelectedDuration.value !== "")
                ? globalSelectedDuration.value
                : "infinity";
        }
        return getDefaultConfiguredDuration();
    }
    readonly property string currentDuration: selectedDuration
    readonly property int timeLeft: globalTimeLeft.value
    readonly property int totalDuration: globalTotalDuration.value

    // Auto-hide when caffeine is inactive for the Live Caffeine widget
    visibilityCommand: isStatusWidgetVariant ? (caffeineActive ? "true" : "false") : ""
    conditionVisible: isStatusWidgetVariant ? caffeineActive : true

    PluginGlobalVar {
        id: globalTimeLeft
        varName: "timeLeft"
        defaultValue: 0
    }

    PluginGlobalVar {
        id: globalTotalDuration
        varName: "totalDuration"
        defaultValue: 0
    }

    PluginGlobalVar {
        id: globalSelectedDuration
        varName: "selectedDuration"
        defaultValue: "infinity"
    }

    // Sync settings
    property bool showToasts: {
        if (!pluginData) return true;
        var val = pluginData.showToasts;
        return val === undefined || val === null ? true : (val === true || val === "true");
    }

    property bool colorfulProgress: {
        if (!pluginData) return false;
        var val = pluginData.colorfulProgress;
        return val === undefined || val === null ? false : (val === true || val === "true");
    }

    readonly property real osdOpacity: {
        if (!pluginData) return 0.85;
        var val = parseFloat(pluginData.osdOpacity !== undefined ? pluginData.osdOpacity : pluginData.backgroundOpacity);
        return (!isNaN(val) && val > 0) ? Math.max(0.10, Math.min(1.00, val)) : 0.85;
    }

    readonly property int quickExtendMinutes: {
        if (!pluginData) return 5;
        var val = parseInt(pluginData.quickExtendMinutes);
        return (!isNaN(val) && val > 0) ? val : 5;
    }

    property var durationOptions: {
        var rawPresets = (pluginData && pluginData.presets) ? pluginData.presets : "5, 15, 30, 60, 120, infinity";
        var items = String(rawPresets).split(",").map(function(item) { return item.trim(); }).filter(Boolean);
        var result = [];
        for (var i = 0; i < items.length; i++) {
            var item = items[i];
            if (item.toLowerCase() === "infinity" || item.toLowerCase() === "infinite" || item.toLowerCase() === "inf") {
                result.push({ label: "Infinite", value: "infinity" });
            } else {
                var mins = parseInt(item);
                if (!isNaN(mins) && mins > 0) {
                    var label = mins + " Min";
                    if (mins >= 60) {
                        var hrs = mins / 60;
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

    function getDefaultConfiguredDuration() {
        var def = (pluginData && pluginData.defaultDuration) ? pluginData.defaultDuration : "infinity";
        def = def.trim().toLowerCase();
        if (def === "cycle") {
            return "300"; // In cycle mode, default is 5 mins
        } else if (def === "infinity" || def === "infinite" || def === "inf" || def === "") {
            return "infinity";
        } else {
            var mins = parseInt(def);
            return (!isNaN(mins) && mins > 0) ? (mins * 60).toString() : "infinity";
        }
    }

    function updateSelectedDuration() {
        var defaultDur = getDefaultConfiguredDuration();
        if (root.caffeineActive) {
            // While active, preserve the currently active duration
            var activeDur = (globalSelectedDuration.value && globalSelectedDuration.value !== "undefined" && globalSelectedDuration.value !== "") 
                ? globalSelectedDuration.value 
                : ((pluginData && pluginData.selectedDuration) ? pluginData.selectedDuration : defaultDur);
            selectedDuration = activeDur;
            globalSelectedDuration.set(activeDur);
        } else {
            // When OFF, stage the default configured duration
            selectedDuration = defaultDur;
        }
    }

    function updateVariantData() {
        if (root.variantId && Array.isArray(pluginData?.variants) && pluginData.variants.length) {
            root.variantData = pluginData.variants.find(function(v) { return v && v.id === root.variantId; }) || root.variantData;
        }
    }

    onPluginDataChanged: {
        updateVariantData();
        updateSelectedDuration();
    }
    onDurationOptionsChanged: updateSelectedDuration()
    
    // Set up initial state on completed
    Component.onCompleted: {
        updateVariantData();
        updateSelectedDuration();
        if (SessionService.idleInhibited) {
            const expiration = pluginService ? pluginService.loadPluginState(pluginId, "expiration", 0) : 0;
            const savedTotal = pluginService ? pluginService.loadPluginState(pluginId, "totalDuration", 0) : 0;
            if (expiration > Date.now()) {
                const rem = Math.round((expiration - Date.now()) / 1000);
                globalTimeLeft.set(rem);
                globalTotalDuration.set(savedTotal > 0 ? savedTotal : rem);
                countdownTimer.start();
            }
        } else {
            if (pluginService) {
                pluginService.savePluginState(pluginId, "expiration", 0);
                pluginService.savePluginState(pluginId, "totalDuration", 0);
            }
            globalTotalDuration.set(0);
        }
    }

    // Keep timer and selection in sync when idle inhibition changes
    Connections {
        target: SessionService
        function onIdleInhibitedChanged() {
            if (!SessionService.idleInhibited) {
                countdownTimer.stop();
                globalTimeLeft.set(0);
                globalTotalDuration.set(0);
                if (pluginService) {
                    pluginService.savePluginState(pluginId, "expiration", 0);
                    pluginService.savePluginState(pluginId, "totalDuration", 0);
                }
            }
            root.updateSelectedDuration();
        }
    }

    // Control Center Integration
    ccWidgetIcon: "local_cafe"
    ccWidgetPrimaryText: I18n.tr("Caffeine")
    ccWidgetSecondaryText: {
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
        const gridSpacing = Theme.spacingXS;
        const gridHeight = rows * pillHeight + Math.max(0, rows - 1) * gridSpacing;
        const titleHeight = 20;
        const durationCardHeight = (Theme.spacingM * 2) + titleHeight + Theme.spacingS + gridHeight;
        return Theme.spacingM + headerCardHeight + Theme.spacingM + durationCardHeight + Theme.spacingM;
    }

    // Formatted countdown string for timer display (e.g. "1h 45m" or "45m 20s" or "∞")
    readonly property string formattedTimeLeft: {
        if (!caffeineActive) return I18n.tr("Off");
        if (selectedDuration === "infinity" || selectedDuration === "undefined" || !selectedDuration) return I18n.tr("Indefinite");
        const totalSecs = root.timeLeft;
        if (totalSecs <= 0) return I18n.tr("Active");
        const hrs = Math.floor(totalSecs / 3600);
        const mins = Math.floor((totalSecs % 3600) / 60);
        const secs = totalSecs % 60;
        if (hrs > 0) {
            return mins > 0 ? (hrs + "h " + mins + "m") : (hrs + "h");
        }
        if (mins > 0) {
            return secs > 0 ? (mins + "m " + secs + "s") : (mins + "m");
        }
        return secs + "s";
    }

    // Standard widget pill color: follows standard theme primary / surfaceText
    readonly property color pillColor: caffeineActive ? Theme.primary : Theme.surfaceText

    // Live widget pill color: follows colorfulProgress setting (green -> amber -> red) when active
    readonly property color livePillColor: {
        if (!caffeineActive) return Theme.primary;
        if (!colorfulProgress) return Theme.primary;
        if (selectedDuration === "infinity") return Qt.rgba(0.20, 0.78, 0.35, 1.0); // Vivid Emerald Green
        // Dynamic color transition based on remaining time ratio:
        // Green when plenty of time remaining, Amber mid-way, Red when low time remaining
        let remRatio = 1.0 - sessionProgress;
        if (remRatio >= 0.50) {
            let t = (remRatio - 0.50) / 0.50;
            return Qt.rgba(1.0 - 0.82 * t, 0.70 + 0.10 * t, 0.0 + 0.44 * t, 1.0);
        } else if (remRatio >= 0.20) {
            let t = (remRatio - 0.20) / 0.30;
            return Qt.rgba(1.0, 0.34 + 0.36 * t, 0.13 - 0.13 * t, 1.0);
        } else {
            return Qt.rgba(0.96, 0.26, 0.21, 1.0);
        }
    }

    // Progress ratio (0.0 to 1.0) of elapsed time for timed sessions
    readonly property real rawSessionProgress: {
        if (!caffeineActive || selectedDuration === "infinity" || totalDuration <= 0) return 0.0;
        const elapsed = Math.max(0, totalDuration - timeLeft);
        return Math.min(1.0, Math.max(0.0, elapsed / totalDuration));
    }
    property real sessionProgress: rawSessionProgress
    Behavior on sessionProgress {
        NumberAnimation {
            duration: 650
            easing.type: Easing.OutCubic
        }
    }

    horizontalBarPill: Component {
        Item {
            id: hPillItem
            implicitHeight: Theme.iconSizeSmall + 4
            implicitWidth: root.isStatusWidgetVariant ? liveHRow.implicitWidth : standardHRow.implicitWidth

            // --- Standard Widget Pill Layout ---
            Row {
                id: standardHRow
                visible: !root.isStatusWidgetVariant
                spacing: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    name: "local_cafe"
                    size: Theme.iconSizeSmall
                    color: root.pillColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    id: hTextContainer
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    height: hText.implicitHeight
                    width: (root.caffeineActive && root.ccWidgetSecondaryText !== "") ? hText.implicitWidth : 0
                    opacity: width > 0 ? 1 : 0

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }

                    StyledText {
                        id: hText
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.ccWidgetSecondaryText
                        color: root.pillColor
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Normal
                    }
                }
            }

            // --- Live Widget Android-Style Dynamic Chip ---
            Row {
                id: liveHRow
                visible: root.isStatusWidgetVariant
                spacing: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter

                // Dynamic Live Status Indicator (Solid Pill Capsule)
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 26
                    radius: 13
                    color: root.livePillColor
                    Behavior on color { ColorAnimation { duration: 250 } }
                    implicitWidth: liveChipRow.implicitWidth + 18

                    // Subtle pulsating breath animation for active stay-awake
                    SequentialAnimation on opacity {
                        running: root.caffeineActive
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.90; duration: 1200; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 1.0; duration: 1200; easing.type: Easing.InOutQuad }
                    }

                    Row {
                        id: liveChipRow
                        anchors.centerIn: parent
                        spacing: 6

                        DankIcon {
                            name: "local_cafe"
                            size: 15
                            color: Theme.surfaceContainerHighest
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: root.formattedTimeLeft
                            color: Theme.surfaceContainerHighest
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.DemiBold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            id: vPillItem
            implicitWidth: root.isStatusWidgetVariant ? liveVCol.implicitWidth : standardVCol.implicitWidth
            implicitHeight: root.isStatusWidgetVariant ? liveVCol.implicitHeight : standardVCol.implicitHeight

            // --- Standard Widget Vertical Layout ---
            Column {
                id: standardVCol
                visible: !root.isStatusWidgetVariant
                spacing: Theme.spacingXS
                anchors.horizontalCenter: parent.horizontalCenter

                DankIcon {
                    name: "local_cafe"
                    size: Theme.iconSizeSmall
                    color: root.pillColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Item {
                    id: vTextContainer
                    anchors.horizontalCenter: parent.horizontalCenter
                    clip: true
                    width: vText.implicitWidth
                    height: (root.caffeineActive && vText.text !== "") ? vText.implicitHeight : 0
                    opacity: height > 0 ? 1 : 0

                    Behavior on height {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }

                    StyledText {
                        id: vText
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: (root.selectedDuration === "infinity" || root.selectedDuration === "undefined" || !root.selectedDuration) ? "∞" : root.ccWidgetSecondaryText
                        color: root.pillColor
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Normal
                    }
                }
            }

            // --- Live Widget Android-Style Vertical Chip ---
            Rectangle {
                id: liveVCol
                visible: root.isStatusWidgetVariant
                anchors.horizontalCenter: parent.horizontalCenter
                width: 28
                implicitWidth: width
                height: liveVContent.implicitHeight + 14
                implicitHeight: height
                radius: width / 2
                color: root.livePillColor
                Behavior on color { ColorAnimation { duration: 250 } }

                SequentialAnimation on opacity {
                    running: root.caffeineActive
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.90; duration: 1200; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1.0; duration: 1200; easing.type: Easing.InOutQuad }
                }

                Column {
                    id: liveVContent
                    anchors.centerIn: parent
                    spacing: 4

                    DankIcon {
                        name: "local_cafe"
                        size: 14
                        color: Theme.surfaceContainerHighest
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    // Stacked time components for vertical bar with clean typography & spacing
                    StyledText {
                        visible: root.caffeineActive && root.selectedDuration === "infinity"
                        text: "∞"
                        color: Theme.surfaceContainerHighest
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        visible: root.caffeineActive && root.selectedDuration !== "infinity" && root.timeLeft > 0 && Math.floor(root.timeLeft / 3600) > 0
                        text: Math.floor(root.timeLeft / 3600) + "h"
                        color: Theme.surfaceContainerHighest
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        visible: root.caffeineActive && root.selectedDuration !== "infinity" && root.timeLeft > 0 && (Math.floor((root.timeLeft % 3600) / 60) > 0 || Math.floor(root.timeLeft / 3600) > 0)
                        text: Math.floor((root.timeLeft % 3600) / 60) + "m"
                        color: Theme.surfaceContainerHighest
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        visible: root.caffeineActive && root.selectedDuration !== "infinity" && (root.timeLeft % 60 > 0 || root.timeLeft <= 0)
                        text: Math.max(0, root.timeLeft % 60) + "s"
                        color: Theme.surfaceContainerHighest
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }

    // Click action: always open duration picker popout (via null fallback)
    pillClickAction: null

    // Right click: quick toggle stay-awake with default duration
    pillRightClickAction: () => {
        toggleCaffeine(undefined, true);
    }

    property bool customInputExpanded: false

    // Popout dimensions
    popoutWidth: {
        if (!root.isStatusWidgetVariant) return 340;
        return root.isBarVertical ? 380 : 360;
    }
    popoutHeight: 0 // auto from content

    // Live Caffeine Popout Component (Cleanly delegated to LiveCaffeinePopout.qml)
    Component {
        id: liveNotificationCardComponent
        LiveCaffeinePopout {
            rootPlugin: root
        }
    }

    Component {
        id: caffeineHeaderComponent
        StyledRect {
            id: headerRoot
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
            border.width: 1
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
            implicitHeight: 72
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                Rectangle {
                    width: Theme.iconSizeSmall * 2.5
                    height: Theme.iconSizeSmall * 2.5
                    radius: height / 2
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                    DankIcon {
                        name: "local_cafe"
                        size: Theme.iconSize
                        color: Theme.surfaceText
                        anchors.centerIn: parent
                    }
                }
                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0
                    StyledText {
                        text: I18n.tr("Caffeine")
                        font.bold: true
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                    }
                    Item {
                        width: parent.width
                        height: 16
                        StyledText {
                            id: modeTxt
                            width: parent.width
                            text: root.caffeineActive ? I18n.tr("Active") : I18n.tr("Inactive")
                            font.pixelSize: Theme.fontSizeSmall
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
                    height: 38
                    width: 105
                    Layout.alignment: Qt.AlignVCenter
                    
                    scale: toggleArea.pressed ? 0.9 : (toggleArea.containsMouse ? 1.05 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                    MouseArea {
                        id: toggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => toggleRipple.trigger(mouse.x, mouse.y)
                        onClicked: root.toggleCaffeine(undefined, false)
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
                        spacing: Theme.spacingS
                        
                        DankIcon {
                            id: toggleBtnIcon
                            name: "power_settings_new"
                            size: Theme.iconSizeSmall
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
            implicitHeight: durationCol.implicitHeight + Theme.spacingM * 2
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
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Theme.spacingXS
                    anchors.rightMargin: Theme.spacingXS
                    spacing: Theme.spacingXS
                    DankIcon {
                        name: "timer"
                        size: Theme.iconSizeSmall
                        color: Theme.surfaceText
                    }
                    StyledText {
                        text: I18n.tr("Keep Awake Duration")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                        Layout.fillWidth: true
                    }
                }
                Flow {
                    id: durationGrid
                    width: parent.width
                    spacing: Theme.spacingXS

                    readonly property string activeTargetValue: String(root.selectedDuration)

                    Repeater {
                        id: durationRepeater
                        model: root.durationOptions

                        delegate: Item {
                            id: optionDelegateItem
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
                            
                            readonly property bool isSelected: String(modelData.value) === durationGrid.activeTargetValue
                            readonly property bool hovered: optionMouseArea.containsMouse
                            
                            Shape {
                                id: durationBg
                                anchors.fill: parent

                                readonly property bool isTop: r === 0
                                readonly property bool isBottom: r === maxR
                                readonly property bool isLeft: c === 0
                                readonly property bool isRight: c === cols - 1 || index === total - 1
                                
                                property real innerRadius: Theme.cornerRadius / 2
                                property real outerRadius: Theme.cornerRadius
                                
                                property real pillRadius: Math.floor((height - 1) / 2)
                                property real tlr: isSelected ? pillRadius : (isTop && isLeft ? outerRadius : innerRadius)
                                property real trr: isSelected ? pillRadius : (isTop && isRight ? outerRadius : innerRadius)
                                property real blr: isSelected ? pillRadius : (isBottom && isLeft ? outerRadius : innerRadius)
                                property real brr: isSelected ? pillRadius : (isBottom && isRight ? outerRadius : innerRadius)

                                property real tlrAnim: tlr; Behavior on tlrAnim { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                                property real trrAnim: trr; Behavior on trrAnim { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                                property real blrAnim: blr; Behavior on blrAnim { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                                property real brrAnim: brr; Behavior on brrAnim { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

                                property color paintColor: {
                                    if (typeof popoutScope !== "undefined" && popoutScope.activeFocus && popoutScope.currentIndex === index) return Theme.primaryPressed;
                                    return isSelected
                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
                                        : (hovered
                                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                                            : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.04));
                                }
                                Behavior on paintColor { ColorAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                
                                property color paintBorder: isSelected
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.75)
                                    : (hovered
                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4)
                                        : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15));
                                Behavior on paintBorder { ColorAnimation { duration: 250; easing.type: Easing.OutCubic } }

                                ShapePath {
                                    fillColor: durationBg.paintColor
                                    strokeColor: durationBg.paintBorder
                                    strokeWidth: 1.5
                                    
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
                                    anchors.fill: parent
                                    radius: parent.tlrAnim
                                    color: Theme.surfaceText
                                    anchors.margins: 0.5
                                    opacity: hovered ? 0.05 : 0
                                    Behavior on opacity { NumberAnimation { duration: 150 } } 
                                }
                            }

                            DankRipple {
                                id: optionRipple
                                anchors.fill: parent
                                cornerRadius: durationBg.tlrAnim
                                rippleColor: Theme.primary
                            }

                            MouseArea {
                                id: optionMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: mouse => { optionRipple.trigger(mouse.x, mouse.y); }
                                onClicked: {
                                    if (typeof popoutScope !== "undefined") popoutScope.currentIndex = index;
                                    const targetVal = String(modelData.value);
                                    if (root.caffeineActive) {
                                        if (String(root.selectedDuration) === targetVal) {
                                            root.deactivateCaffeine();
                                            if (typeof popoutScope !== "undefined") closePopout();
                                        } else {
                                            root.changeDuration(targetVal);
                                        }
                                    } else {
                                        root.activateCaffeine(targetVal);
                                        if (typeof popoutScope !== "undefined") closePopout();
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

                            Keys.onReturnPressed: event => {
                                if (typeof popoutScope !== "undefined") {
                                    popoutScope.currentIndex = index;
                                    root.changeDuration(modelData.value);
                                    event.accepted = true;
                                }
                            }
                            Keys.onSpacePressed: event => {
                                if (typeof popoutScope !== "undefined") {
                                    popoutScope.currentIndex = index;
                                    root.changeDuration(modelData.value);
                                    event.accepted = true;
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
                sourceComponent: popoutInternal
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
            Keys.onPressed: event => {
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

                // --- Live Widget Android-Style Notification Card OR Standard Header ---
                Loader {
                    width: parent.width
                    sourceComponent: root.isStatusWidgetVariant ? liveNotificationCardComponent : caffeineHeaderComponent
                }

                // --- Duration Grid Section (Standard Widget only) ---
                Loader {
                    width: parent.width
                    visible: !root.isStatusWidgetVariant
                    sourceComponent: root.isStatusWidgetVariant ? null : durationGridComponent
                }
            }
        }
    }

    onCcWidgetToggled: {
        toggleCaffeine(undefined, true)
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            if (root.selectedDuration === "infinity") {
                countdownTimer.stop();
                return;
            }
            const nextVal = globalTimeLeft.value - 1;
            globalTimeLeft.set(Math.max(0, nextVal));
            if (nextVal <= 0) {
                countdownTimer.stop();
                deactivateCaffeine();
            }
        }
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

    function deactivateCaffeine(silent) {
        countdownTimer.stop();
        globalTimeLeft.set(0);
        globalTotalDuration.set(0);
        var defDur = getDefaultConfiguredDuration();
        
        selectedDuration = defDur;
        globalSelectedDuration.set(defDur);

        if (pluginService) {
            pluginService.savePluginState(pluginId, "expiration", 0);
            pluginService.savePluginState(pluginId, "totalDuration", 0);
        }
        if (typeof SessionService !== "undefined" && SessionService.disableIdleInhibit) {
            SessionService.disableIdleInhibit();
        }
        if (!silent && showToasts && typeof ToastService !== "undefined") {
            ToastService.showInfo(I18n.tr("Screen sleep is now allowed."));
        }
        if (!silent && customOsd) {
            customOsd.triggerTurnOffOSD();
        }
    }

    function activateCaffeine(targetDuration, silentToast) {
        selectedDuration = targetDuration;
        globalSelectedDuration.set(targetDuration);
        if (pluginService) {
            pluginService.savePluginData(pluginId, "selectedDuration", targetDuration);
        }
        let durationMinutes = 0;
        if (targetDuration !== "infinity") {
            const durationSecs = parseInt(targetDuration);
            durationMinutes = Math.round(durationSecs / 60);
            globalTimeLeft.set(durationSecs);
            globalTotalDuration.set(durationSecs);
            const expiration = Date.now() + durationSecs * 1000;
            if (pluginService) {
                pluginService.savePluginState(pluginId, "expiration", expiration);
                pluginService.savePluginState(pluginId, "totalDuration", durationSecs);
            }
            countdownTimer.restart();
        } else {
            countdownTimer.stop();
            globalTimeLeft.set(0);
            globalTotalDuration.set(0);
            if (pluginService) {
                pluginService.savePluginState(pluginId, "expiration", 0);
                pluginService.savePluginState(pluginId, "totalDuration", 0);
            }
        }

        if (typeof SessionService !== "undefined" && SessionService.enableIdleInhibit) {
            SessionService.enableIdleInhibit(durationMinutes > 0 ? durationMinutes : 0);
        }
        
        if (!silentToast && showToasts && typeof ToastService !== "undefined") {
            ToastService.showInfo(targetDuration === "infinity" ? I18n.tr("Screen will stay awake indefinitely.") : I18n.tr("Screen will stay awake for ") + formatDurationLabel(targetDuration) + ".");
        }
        if (customOsd) {
            customOsd.triggerOSD(targetDuration);
        }
    }

    function extendCaffeine(extraSeconds) {
        if (!caffeineActive) {
            activateCaffeine(extraSeconds.toString());
            return;
        }

        const currentSecs = (selectedDuration === "infinity") ? 0 : root.timeLeft;
        const newSecs = Math.max(0, currentSecs + extraSeconds);
        const newTotal = (selectedDuration === "infinity") ? newSecs : Math.max(root.totalDuration + extraSeconds, newSecs);
        const durationMinutes = Math.round(newSecs / 60);

        selectedDuration = newSecs.toString();
        globalSelectedDuration.set(newSecs.toString());
        globalTimeLeft.set(newSecs);
        globalTotalDuration.set(newTotal);
        const expiration = Date.now() + newSecs * 1000;
        if (pluginService) {
            pluginService.savePluginState(pluginId, "expiration", expiration);
            pluginService.savePluginState(pluginId, "totalDuration", newTotal);
        }
        countdownTimer.restart();

        if (typeof SessionService !== "undefined" && SessionService.enableIdleInhibit) {
            SessionService.enableIdleInhibit(durationMinutes > 0 ? durationMinutes : 0);
        }

        if (showToasts && typeof ToastService !== "undefined") {
            ToastService.showInfo(I18n.tr("Extended stay awake by %1 minutes.").arg(Math.round(extraSeconds / 60)));
        }
        if (customOsd) {
            customOsd.triggerOSD(newSecs.toString());
        }
    }

    function changeDuration(newDuration, fromLivePopup) {
        if (newDuration === undefined || newDuration === null || newDuration === "undefined" || newDuration === "") return;
        selectedDuration = newDuration;
        
        globalSelectedDuration.set(newDuration);
        if (pluginService) {
            pluginService.savePluginData(pluginId, "selectedDuration", newDuration);
        }

        if (caffeineActive) {
            // When switching durations while active, cycle inhibition cleanly without turning off
            let durationMinutes = 0;
            if (newDuration !== "infinity") {
                const durationSecs = parseInt(newDuration);
                durationMinutes = Math.round(durationSecs / 60);
                globalTimeLeft.set(durationSecs);
                globalTotalDuration.set(durationSecs);
                const expiration = Date.now() + durationSecs * 1000;
                if (pluginService) {
                    pluginService.savePluginState(pluginId, "expiration", expiration);
                    pluginService.savePluginState(pluginId, "totalDuration", durationSecs);
                }
                countdownTimer.restart();
            } else {
                countdownTimer.stop();
                globalTimeLeft.set(0);
                globalTotalDuration.set(0);
                if (pluginService) {
                    pluginService.savePluginState(pluginId, "expiration", 0);
                    pluginService.savePluginState(pluginId, "totalDuration", 0);
                }
            }

            if (typeof SessionService !== "undefined" && SessionService.enableIdleInhibit) {
                SessionService.enableIdleInhibit(durationMinutes > 0 ? durationMinutes : 0);
            }

            if (showToasts && typeof ToastService !== "undefined") {
                ToastService.showInfo(I18n.tr("Duration updated: stay awake for ") + formatDurationLabel(newDuration) + ".");
            }
            if (customOsd) {
                customOsd.triggerOSD(newDuration);
            }
        }
    }

    function toggleCaffeine(duration, isDefaultTrigger) {
        var defDur = ((pluginData && pluginData.defaultDuration) ? pluginData.defaultDuration : "infinity").trim().toLowerCase();

        if (isDefaultTrigger === true && defDur === "cycle") {
            if (root.caffeineActive) {
                var current = String(selectedDuration);
                var idx = durationOptions.findIndex(function(o) { return String(o.value) === current; });
                if (idx === -1) idx = 0;
                
                if (idx === durationOptions.length - 1) {
                    deactivateCaffeine();
                } else {
                    var nextDur = durationOptions[idx + 1].value;
                    changeDuration(nextDur);
                }
                return;
            }
        }

        if (root.caffeineActive) {
            deactivateCaffeine();
            return;
        }

        // When turning on:
        var targetDuration;
        if (duration !== undefined) {
            targetDuration = duration;
        } else {
            // Clicking turn on from normal widget or right-click without explicit preset:
            // Always use default duration, except when cycle mode is selected (in cycle mode, start at 5 minutes / 300s).
            if (defDur === "cycle") {
                targetDuration = "300"; // 5 minutes
            } else if (defDur === "infinity" || defDur === "infinite" || defDur === "inf" || defDur === "") {
                targetDuration = "infinity";
            } else {
                var mins = parseInt(defDur);
                targetDuration = (!isNaN(mins) && mins > 0) ? (mins * 60).toString() : "infinity";
            }
        }

        if (targetDuration === undefined || targetDuration === null || targetDuration === "undefined" || targetDuration === "") {
            targetDuration = "infinity";
        }
        activateCaffeine(targetDuration);
    }

    ccDetailContent: Component {
        DankFlickable {
            width: parent.width
            height: parent.height
            contentWidth: width
            contentHeight: ccDetailCol.implicitHeight

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

    // Custom On-Screen Display (OSD)
    CaffeineOSD {
        id: customOsd
        rootPlugin: root
    }
}
