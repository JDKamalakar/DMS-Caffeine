import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Services

PluginSettings {
    id: root
    pluginId: "caffeineRedesigned"

    readonly property real outerR: Theme.cornerRadius || 12
    readonly property real innerR: 4

    property var parsedOptions: {
        var rawPresets = (presetsField && presetsField.text) ? presetsField.text : "5, 15, 30, 60, 120, infinity";
        var items = rawPresets.split(",").map(function(item) { return item.trim(); }).filter(Boolean);
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
                    result.push({ label: label, value: mins.toString() });
                }
            }
        }
        result.push({ label: "Cycle Presets", value: "cycle" });
        return result;
    }

    function loadValue(key, def) {
        if (typeof PluginService !== "undefined" && PluginService && PluginService.loadPluginData) {
            return PluginService.loadPluginData(root.pluginId, key, def);
        }
        return def;
    }

    function saveValue(key, val) {
        if (typeof PluginService !== "undefined" && PluginService && PluginService.savePluginData) {
            PluginService.savePluginData(root.pluginId, key, val);
            if (PluginService.setGlobalVar) {
                PluginService.setGlobalVar(root.pluginId, key, val);
            }
        }
    }

    function loadAll() {
        presetsField.loadValue();
        defaultDurationDropdown.loadValue();
        showToastsToggle.loadValue();
    }

    Component.onCompleted: loadAll()

    onPluginServiceChanged: {
        if (pluginService) {
            loadAll();
        }
    }

    Connections {
        target: PluginService
        ignoreUnknownSignals: true
        function onPluginDataChanged(pId) {
            if (pId === root.pluginId) {
                root.loadAll();
            }
        }
        function onGlobalVarChanged(pId, varName) {
            if (pId === root.pluginId) {
                root.loadAll();
            }
        }
    }

    Column {
        id: mainSettingsCol
        width: parent.width
        spacing: Theme.spacingL

        // --- General Settings Section ---
        Column {
            width: parent.width
            spacing: Theme.spacingS

            Row {
                spacing: Theme.spacingXS
                leftPadding: Theme.spacingM
                DankIcon {
                    name: "tune"
                    size: 16
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: "General Settings"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // ── Segmented Settings Stack ───────────────────────────
            Column {
                id: prefColumn
                width: parent.width
                spacing: 2

                // 1. Quick Presets (First Segment)
                Rectangle {
                    width: parent.width
                    height: presetsCol.implicitHeight + Theme.spacingM * 2

                    topLeftRadius: root.outerR
                    topRightRadius: root.outerR
                    bottomLeftRadius: root.innerR
                    bottomRightRadius: root.innerR

                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    ColumnLayout {
                        id: presetsCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingM

                            Rectangle {
                                width: 32
                                height: 32
                                radius: 16
                                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                Layout.alignment: Qt.AlignVCenter

                                DankIcon {
                                    name: "tune"
                                    size: 18
                                    color: Theme.primary
                                    anchors.centerIn: parent
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                StyledText {
                                    text: "Quick Presets"
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: "Comma-separated list of durations (in minutes, or 'infinity')."
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    wrapMode: Text.WordWrap
                                }
                            }

                            Rectangle {
                                id: presetsResetBtn
                                width: 32; height: 32
                                radius: Theme.cornerRadius
                                Layout.alignment: Qt.AlignVCenter
                                color: presetsResetMa.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.04)
                                border.color: presetsResetMa.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)
                                border.width: 1
                                opacity: presetsField.text !== presetsField.defaultValue ? (presetsResetMa.containsMouse ? 1.0 : 0.9) : 0.0
                                visible: opacity > 0
                                scale: presetsResetMa.pressed ? 0.9 : (presetsResetMa.containsMouse ? 1.05 : 1.0)
                                
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                                DankRipple { 
                                    id: presetsRip
                                    anchors.fill: parent
                                    cornerRadius: parent.radius
                                    rippleColor: Theme.primary 
                                }

                                DankIcon {
                                    id: presetsResetIcon
                                    name: "restart_alt"
                                    size: 18
                                    anchors.centerIn: parent
                                    color: presetsResetMa.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                    rotation: presetsResetMa.containsMouse ? 90 : 0
                                    Behavior on rotation { NumberAnimation { duration: 450; easing.type: Easing.OutBack } }
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                MouseArea {
                                    id: presetsResetMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        presetsField.text = presetsField.defaultValue;
                                        root.saveValue(presetsField.settingKey, presetsField.defaultValue);
                                    }
                                    onPressed: (m) => presetsRip.trigger(m.x, m.y)
                                }
                            }
                        }

                        DankTextField {
                            id: presetsField
                            property string settingKey: "presets"
                            property string defaultValue: "5, 15, 30, 60, 120, infinity"
                            Layout.fillWidth: true
                            placeholderText: defaultValue
                            
                            function loadValue() {
                                text = root.loadValue(settingKey, defaultValue);
                            }
                            onEditingFinished: {
                                root.saveValue(settingKey, text);
                            }
                        }
                    }
                }

                // 2. Default Duration (Middle Segment)
                Rectangle {
                    width: parent.width
                    height: defaultDurationCol.implicitHeight + Theme.spacingM * 2

                    topLeftRadius: root.innerR
                    topRightRadius: root.innerR
                    bottomLeftRadius: root.innerR
                    bottomRightRadius: root.innerR

                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    ColumnLayout {
                        id: defaultDurationCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingM

                            Rectangle {
                                width: 32
                                height: 32
                                radius: 16
                                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                Layout.alignment: Qt.AlignVCenter

                                DankIcon {
                                    name: "schedule"
                                    size: 18
                                    color: Theme.primary
                                    anchors.centerIn: parent
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                StyledText {
                                    text: "Default Duration"
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: "The default duration used on direct toggling, or 'cycle' to switch presets."
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    wrapMode: Text.WordWrap
                                }
                            }

                            Rectangle {
                                id: defaultDurationResetBtn
                                width: 32; height: 32
                                radius: Theme.cornerRadius
                                Layout.alignment: Qt.AlignVCenter
                                color: defaultDurationResetMa.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.04)
                                border.color: defaultDurationResetMa.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)
                                border.width: 1
                                opacity: defaultDurationDropdown.currentValue !== "Infinite" ? (defaultDurationResetMa.containsMouse ? 1.0 : 0.9) : 0.0
                                visible: opacity > 0
                                scale: defaultDurationResetMa.pressed ? 0.9 : (defaultDurationResetMa.containsMouse ? 1.05 : 1.0)
                                
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                                DankRipple { 
                                    id: defaultDurationRip
                                    anchors.fill: parent
                                    cornerRadius: parent.radius
                                    rippleColor: Theme.primary 
                                }

                                DankIcon {
                                    id: defaultDurationResetIcon
                                    name: "restart_alt"
                                    size: 18
                                    anchors.centerIn: parent
                                    color: defaultDurationResetMa.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                    rotation: defaultDurationResetMa.containsMouse ? 90 : 0
                                    Behavior on rotation { NumberAnimation { duration: 450; easing.type: Easing.OutBack } }
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                MouseArea {
                                    id: defaultDurationResetMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        defaultDurationDropdown.currentValue = "Infinite";
                                        root.saveValue(defaultDurationDropdown.settingKey, defaultDurationDropdown.defaultValue);
                                    }
                                    onPressed: (m) => defaultDurationRip.trigger(m.x, m.y)
                                }
                            }
                        }

                        DankDropdown {
                            id: defaultDurationDropdown
                            property string settingKey: "defaultDuration"
                            property string defaultValue: "infinity"
                            Layout.fillWidth: true
                            compactMode: true
                            dropdownWidth: parent.width
                            
                            options: root.parsedOptions.map(function(opt) { return opt.label; })
                            
                            function loadValue() {
                                var savedVal = root.loadValue(settingKey, defaultValue);
                                var found = root.parsedOptions.find(function(opt) { return opt.value === savedVal; });
                                currentValue = found ? found.label : "Infinite";
                            }
                            
                            onValueChanged: value => {
                                var found = root.parsedOptions.find(function(opt) { return opt.label === value; });
                                if (found) {
                                    root.saveValue(settingKey, found.value);
                                }
                            }
                        }
                    }
                }

                // 3. Status Toasts Notification (Last Segment)
                Rectangle {
                    width: parent.width
                    height: toastsRow.implicitHeight + Theme.spacingM * 2

                    topLeftRadius: root.innerR
                    topRightRadius: root.innerR
                    bottomLeftRadius: root.outerR
                    bottomRightRadius: root.outerR

                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    RowLayout {
                        id: toastsRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: showToastsToggle.checked ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.5)
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 150 } }

                            DankIcon {
                                name: "notifications"
                                size: 18
                                color: showToastsToggle.checked ? Theme.primary : Theme.surfaceVariantText
                                anchors.centerIn: parent
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                text: "Show Status Toasts"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: "Show a quick pop-up toast when screen stay-awake is toggled."
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                            }
                        }

                        DankToggle {
                            id: showToastsToggle
                            Layout.alignment: Qt.AlignVCenter
                            hideText: true
                            property string settingKey: "showToasts"
                            checked: true
                            
                            function loadValue() {
                                var val = root.loadValue(settingKey, true);
                                checked = (val === true || val === "true");
                            }
                            
                            onToggled: isChecked => {
                                checked = isChecked;
                                root.saveValue(settingKey, isChecked);
                            }
                        }
                    }
                }
            }
        }
    }
}
