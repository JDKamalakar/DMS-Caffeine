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
    property bool caffeineActive: false
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
    property int timeLeft: 0

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
    ccWidgetPrimaryText: "Caffeine"
    ccWidgetSecondaryText: {
        if (!caffeineActive) return "Inactive"
        if (selectedDuration === "infinity" || selectedDuration === "undefined" || !selectedDuration) return "Indefinite"
        if (timeLeft <= 0) return "Active"
        const mins = Math.ceil(timeLeft / 60)
        return mins + "m remaining"
    }
    ccWidgetIsActive: caffeineActive
    ccDetailHeight: {
        const rows = Math.ceil(durationOptions.length / 3);
        const headerHeight = Theme.fontSizeLarge + Theme.spacingXS + Theme.spacingM;
        const gridHeight = rows * 48 + Math.max(0, rows - 1) * Theme.spacingS;
        return headerHeight + gridHeight + Theme.spacingM * 2;
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
            timeLeft--;
            if (timeLeft <= 0) {
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
                caffeineActive = true;
                const expiration = pluginService ? pluginService.loadPluginState(pluginId, "expiration", 0) : 0;
                if (expiration > Date.now()) {
                    timeLeft = Math.round((expiration - Date.now()) / 1000);
                    countdownTimer.start();
                }
            } else {
                caffeineActive = false;
                if (pluginService) {
                    pluginService.savePluginState(pluginId, "expiration", 0);
                }
            }
        })
    }

    function formatDurationLabel(dur) {
        if (dur === "infinity") return "indefinitely";
        const secs = parseInt(dur);
        if (isNaN(secs) || secs <= 0) return dur;
        const mins = secs / 60;
        if (mins < 60) {
            return mins + " minute" + (mins === 1 ? "" : "s");
        }
        const hrs = mins / 60;
        if (hrs === 1) return "1 hour";
        return hrs.toFixed(1).replace(".0", "") + " hours";
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
                timeLeft = durationSecs;
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
                ToastService?.showSuccess("Duration updated: stay awake for " + formatDurationLabel(newDuration) + ".")
            }
        }
    }

    function toggleCaffeine(duration) {
        let targetDuration = duration !== undefined ? duration : selectedDuration;
        if (targetDuration === undefined || targetDuration === null || targetDuration === "undefined" || targetDuration === "") {
            targetDuration = "infinity";
        }
        if (caffeineActive) {
            // Deactivate
            caffeineActive = false; // Set synchronously to avoid race conditions
            countdownTimer.stop();
            if (pluginService) {
                pluginService.savePluginState(pluginId, "expiration", 0);
            }
            Proc.runCommand("deactivate-caffeine", ["pkill", "-f", "DMS Caffeine"], function(output, exitCode) {
                if (showToasts) {
                    ToastService?.showInfo("Screen sleep is now allowed.")
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
            
            caffeineActive = true;
            
            if (targetDuration !== "infinity") {
                const durationSecs = parseInt(targetDuration);
                timeLeft = durationSecs;
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
                ToastService?.showSuccess(targetDuration === "infinity" ? "Screen will stay awake." : "Screen will stay awake for " + formatDurationLabel(targetDuration) + ".")
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
                    text: "Keep Awake Duration"
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
                                    root.changeDuration(modelData.value);
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
