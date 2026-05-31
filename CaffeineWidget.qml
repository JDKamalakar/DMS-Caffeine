import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Services
import qs.Modules.Plugins

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
        const headerHeight = Theme.fontSizeLarge + Theme.spacingXS + Theme.spacingM;
        const gridHeight = rows * 48 + Math.max(0, rows - 1) * Theme.spacingS;
        return headerHeight + gridHeight + Theme.spacingM * 2;
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
                text: root.ccWidgetSecondaryText
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
    popoutWidth: 320
    popoutHeight: 0 // auto from content

    // Popout content: duration selector grid
    popoutContent: Component {
        FocusScope {
            id: popoutScope
            implicitHeight: contentColumn.implicitHeight + Theme.spacingM * 2
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

            Rectangle {
                id: popoutBg
                anchors.fill: parent
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.width: 0
            }

            Column {
                id: contentColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                StyledText {
                    text: I18n.tr("Caffeine") + " — " + I18n.tr(caffeineActive ? "Active" : "Inactive")
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                    bottomPadding: Theme.spacingXS
                }

                Grid {
                    id: durationGrid
                    width: parent.width
                    columns: 3
                    spacing: Theme.spacingS

                    Repeater {
                        model: root.durationOptions

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width: (parent.width - Theme.spacingS * 2) / 3
                            height: 48
                            radius: Theme.cornerRadius
                            color: {
                                if (popoutScope.currentIndex === index) return Theme.primaryPressed
                                if (optionMouseArea.containsMouse) return Theme.surfaceContainerHighest
                                return (root.selectedDuration === modelData.value ? Theme.withAlpha(Theme.primary, 0.12) : "transparent")
                            }
                            border.color: root.selectedDuration === modelData.value ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                            border.width: root.selectedDuration === modelData.value ? 2 : 1

                            MouseArea {
                                id: optionMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (typeof popoutScope !== 'undefined') popoutScope.currentIndex = index
                                    const isSelected = String(root.selectedDuration) === String(modelData.value)
                                    if (isSelected) {
                                        root.toggleCaffeine(modelData.value)
                                        if (typeof popoutScope !== 'undefined') closePopout()
                                    } else {
                                        root.changeDuration(modelData.value)
                                    }
                                }
                            }

                            StyledText {
                                text: modelData.label
                                color: root.selectedDuration === modelData.value ? Theme.primary : Theme.surfaceText
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: root.selectedDuration === modelData.value ? Font.Medium : Font.Normal
                                anchors.centerIn: parent
                            }

                            // Activate on keyboard Enter/Space when focused
                            Keys.onReturnPressed: function(event) {
                                popoutScope.currentIndex = index
                                root.changeDuration(modelData.value)
                                event.accepted = true
                            }
                            Keys.onSpacePressed: function(event) {
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
        Rectangle {
            id: detailRoot
            implicitHeight: detailColumn.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh
            border.width: 0

            Column {
                id: detailColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                StyledText {
                    text: I18n.tr("Keep Awake Duration")
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                    bottomPadding: Theme.spacingXS
                }

                Grid {
                    width: parent.width
                    columns: 3
                    spacing: Theme.spacingS

                    Repeater {
                        model: root.durationOptions

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width: (parent.width - Theme.spacingS * 2) / 3
                            height: 48
                            radius: Theme.cornerRadius
                            color: optionMouseArea.containsMouse 
                                ? Theme.surfaceContainerHighest 
                                : (root.selectedDuration === modelData.value ? Theme.withAlpha(Theme.primary, 0.12) : "transparent")
                            border.color: root.selectedDuration === modelData.value ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                            border.width: root.selectedDuration === modelData.value ? 2 : 1

                            MouseArea {
                                id: optionMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const isSelected = String(root.selectedDuration) === String(modelData.value)
                                    if (isSelected) {
                                        root.toggleCaffeine(modelData.value)
                                    } else {
                                        root.changeDuration(modelData.value)
                                    }
                                }
                            }

                            StyledText {
                                text: modelData.label
                                color: root.selectedDuration === modelData.value ? Theme.primary : Theme.surfaceText
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: root.selectedDuration === modelData.value ? Font.Medium : Font.Normal
                                anchors.centerIn: parent
                            }
                        }
                    }
                }
            }
        }
    }
}
