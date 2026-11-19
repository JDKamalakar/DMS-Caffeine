import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Modules.Settings.Widgets
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

    readonly property var requiredVariants: [
        {
            id: "standard",
            name: "Caffeine",
            description: "Keep screen awake with customizable presets and popout",
            icon: "local_cafe",
            widgetDisplayMode: "standard"
        },
        {
            id: "status_timer",
            name: "Live Caffeine",
            description: "Dedicated status and remaining countdown timer that auto-expands when awake",
            icon: "local_cafe",
            widgetDisplayMode: "status_timer"
        }
    ]

    function syncVariants() {
        var current = root.variants || [];
        var matches = (current.length === 2 &&
                       current[0] && current[0].id === "standard" &&
                       current[1] && current[1].id === "status_timer");
        if (!matches) {
            if (typeof SettingsData !== "undefined" && SettingsData.setPluginSetting) {
                SettingsData.setPluginSetting(root.pluginId, "variants", root.requiredVariants);
            }
            if (typeof PluginService !== "undefined" && PluginService.pluginDataChanged) {
                PluginService.pluginDataChanged(root.pluginId);
            }
        }
    }

    function loadAll() {
        presetsField.loadValue();
        defaultDurationDropdown.loadValue();
        quickExtendField.loadValue();
        showToastsToggle.loadValue();
        colorfulProgressToggle.loadValue();
        customOsdDropdown.loadValue();
        osdOpacitySlider.loadValue();
    }

    Component.onCompleted: {
        loadAll();
        syncVariants();
    }

    onPluginServiceChanged: {
        if (pluginService) {
            loadAll();
            syncVariants();
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

                // 3. Quick Extend Duration (Middle Segment)
                Rectangle {
                    width: parent.width
                    height: quickExtendCol.implicitHeight + Theme.spacingM * 2

                    topLeftRadius: root.innerR
                    topRightRadius: root.innerR
                    bottomLeftRadius: root.innerR
                    bottomRightRadius: root.innerR

                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    ColumnLayout {
                        id: quickExtendCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

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
                                    name: "add_circle_outline"
                                    size: 18
                                    color: Theme.primary
                                    anchors.centerIn: parent
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                StyledText {
                                    text: "Quick Extend Duration (Minutes)"
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: "Minutes to add when tapping the extend button in the live notification card (default: 5)."
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    wrapMode: Text.WordWrap
                                }
                            }

                            Rectangle {
                                id: quickExtendResetBtn
                                width: 32; height: 32
                                radius: Theme.cornerRadius
                                Layout.alignment: Qt.AlignVCenter
                                color: quickExtendResetMa.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.04)
                                border.color: quickExtendResetMa.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)
                                border.width: 1
                                opacity: quickExtendField.text !== quickExtendField.defaultValue ? (quickExtendResetMa.containsMouse ? 1.0 : 0.9) : 0.0
                                visible: opacity > 0
                                scale: quickExtendResetMa.pressed ? 0.9 : (quickExtendResetMa.containsMouse ? 1.05 : 1.0)
                                
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                                DankRipple { 
                                    id: quickExtendRip
                                    anchors.fill: parent
                                    cornerRadius: parent.radius
                                    rippleColor: Theme.primary 
                                }

                                DankIcon {
                                    name: "restart_alt"
                                    size: 18
                                    anchors.centerIn: parent
                                    color: quickExtendResetMa.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                    rotation: quickExtendResetMa.containsMouse ? 90 : 0
                                    Behavior on rotation { NumberAnimation { duration: 450; easing.type: Easing.OutBack } }
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                MouseArea {
                                    id: quickExtendResetMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        quickExtendField.text = quickExtendField.defaultValue;
                                        root.saveValue(quickExtendField.settingKey, 5);
                                    }
                                    onPressed: (m) => quickExtendRip.trigger(m.x, m.y)
                                }
                            }
                        }

                        DankTextField {
                            id: quickExtendField
                            property string settingKey: "quickExtendMinutes"
                            property string defaultValue: "5"
                            Layout.fillWidth: true
                            placeholderText: "5"
                            
                            function loadValue() {
                                var val = root.loadValue(settingKey, 5);
                                text = (val !== undefined && val !== null && val !== "") ? val.toString() : "5";
                            }
                            onEditingFinished: {
                                var num = parseInt(text.trim());
                                if (!isNaN(num) && num > 0) {
                                    root.saveValue(settingKey, num);
                                } else {
                                    text = "5";
                                    root.saveValue(settingKey, 5);
                                }
                            }
                        }
                    }
                }

                // 4. Status Toasts Notification (Middle Segment)
                Rectangle {
                    width: parent.width
                    height: toastsRow.implicitHeight + Theme.spacingM * 2

                    topLeftRadius: root.innerR
                    topRightRadius: root.innerR
                    bottomLeftRadius: root.innerR
                    bottomRightRadius: root.innerR

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
                                text: I18n.tr("Show Status Toasts")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: I18n.tr("Show a quick pop-up toast when screen stay-awake is toggled.")
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

                // 5. Colorful Progress Bar Toggle (Middle Segment)
                Rectangle {
                    width: parent.width
                    height: colorfulRow.implicitHeight + Theme.spacingM * 2

                    topLeftRadius: root.innerR
                    topRightRadius: root.innerR
                    bottomLeftRadius: root.innerR
                    bottomRightRadius: root.innerR

                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    RowLayout {
                        id: colorfulRow
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
                            color: colorfulProgressToggle.checked ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.5)
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 150 } }

                            DankIcon {
                                anchors.centerIn: parent
                                name: "palette"
                                size: 18
                                color: colorfulProgressToggle.checked ? Theme.primary : Theme.surfaceVariantText
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                text: I18n.tr("Colorful Progress Bar")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: I18n.tr("Use dynamic color transition based on remaining time (green > amber > red).")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                            }
                        }

                        DankToggle {
                            id: colorfulProgressToggle
                            Layout.alignment: Qt.AlignVCenter
                            hideText: true
                            property string settingKey: "colorfulProgress"
                            checked: false
                            
                            function loadValue() {
                                var val = root.loadValue(settingKey, false);
                                checked = (val === true || val === "true");
                            }
                            
                            onToggled: isChecked => {
                                checked = isChecked;
                                root.saveValue(settingKey, isChecked);
                            }
                        }
                    }
                }

                // 6. Custom OSD Position Dropdown (Middle Segment)
                Rectangle {
                    width: parent.width
                    height: customOsdCol.implicitHeight + Theme.spacingM * 2

                    topLeftRadius: root.innerR
                    topRightRadius: root.innerR
                    bottomLeftRadius: root.innerR
                    bottomRightRadius: root.innerR

                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    ColumnLayout {
                        id: customOsdCol
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
                                color: customOsdDropdown.currentValue !== "Off" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.5)
                                Layout.alignment: Qt.AlignVCenter
                                Behavior on color { ColorAnimation { duration: 150 } }

                                DankIcon {
                                    name: "desktop_windows"
                                    size: 18
                                    color: customOsdDropdown.currentValue !== "Off" ? Theme.primary : Theme.surfaceVariantText
                                    anchors.centerIn: parent
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                StyledText {
                                    text: I18n.tr("Custom OSD Position")
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: I18n.tr("Show an animated on-screen display when stay-awake is toggled or changed.")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    wrapMode: Text.WordWrap
                                }
                            }

                            Rectangle {
                                id: customOsdResetBtn
                                width: 32; height: 32
                                radius: Theme.cornerRadius
                                Layout.alignment: Qt.AlignVCenter
                                color: customOsdResetMa.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.04)
                                border.color: customOsdResetMa.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)
                                border.width: 1
                                opacity: customOsdDropdown.currentValue !== "Off" ? (customOsdResetMa.containsMouse ? 1.0 : 0.9) : 0.0
                                visible: opacity > 0
                                scale: customOsdResetMa.pressed ? 0.9 : (customOsdResetMa.containsMouse ? 1.05 : 1.0)

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                                DankRipple {
                                    id: customOsdRip
                                    anchors.fill: parent
                                    cornerRadius: parent.radius
                                    rippleColor: Theme.primary
                                }

                                DankIcon {
                                    name: "restart_alt"
                                    size: 18
                                    anchors.centerIn: parent
                                    color: customOsdResetMa.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                    rotation: customOsdResetMa.containsMouse ? 90 : 0
                                    Behavior on rotation { NumberAnimation { duration: 450; easing.type: Easing.OutBack } }
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                MouseArea {
                                    id: customOsdResetMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        customOsdDropdown.currentValue = "Off";
                                        root.saveValue(customOsdDropdown.settingKey, customOsdDropdown.defaultValue);
                                    }
                                    onPressed: (m) => customOsdRip.trigger(m.x, m.y)
                                }
                            }
                        }

                        DankDropdown {
                            id: customOsdDropdown
                            property string settingKey: "customOsdPosition"
                            property string defaultValue: "off"
                            Layout.fillWidth: true
                            compactMode: true
                            dropdownWidth: parent.width

                            readonly property var osdOptions: [
                                { label: "Off", value: "off" },
                                { label: "Top Left", value: "top_left" },
                                { label: "Top Center", value: "top_center" },
                                { label: "Top Right", value: "top_right" },
                                { label: "Left Center", value: "left_center" },
                                { label: "Center", value: "center" },
                                { label: "Right Center", value: "right_center" },
                                { label: "Bottom Left", value: "bottom_left" },
                                { label: "Bottom Center", value: "bottom_center" },
                                { label: "Bottom Right", value: "bottom_right" }
                            ]

                            options: osdOptions.map(function(opt) { return opt.label; })

                            function loadValue() {
                                var savedVal = root.loadValue(settingKey, defaultValue);
                                var found = osdOptions.find(function(opt) { return opt.value === savedVal; });
                                currentValue = found ? found.label : "Off";
                            }

                            onValueChanged: value => {
                                var found = osdOptions.find(function(opt) { return opt.label === value; });
                                if (found) {
                                    root.saveValue(settingKey, found.value);
                                }
                            }
                        }
                    }
                }

                // 7. OSD Background Opacity / Transparency (Last Segment)
                Rectangle {
                    width: parent.width
                    height: opacityCol.implicitHeight + Theme.spacingM * 2

                    topLeftRadius: root.innerR
                    topRightRadius: root.innerR
                    bottomLeftRadius: root.outerR
                    bottomRightRadius: root.outerR

                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    ColumnLayout {
                        id: opacityCol
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
                                    name: "opacity"
                                    size: 18
                                    color: Theme.primary
                                    anchors.centerIn: parent
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                StyledText {
                                    text: I18n.tr("OSD Background Opacity")
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: I18n.tr("Adjust background transparency of the on-screen display (default: 85%).")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    wrapMode: Text.WordWrap
                                }
                            }

                            Rectangle {
                                width: 32; height: 32
                                radius: Theme.cornerRadius
                                Layout.alignment: Qt.AlignVCenter
                                color: opacityResetMa.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.04)
                                border.color: opacityResetMa.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)
                                border.width: 1
                                opacity: osdOpacitySlider.value !== 85 ? (opacityResetMa.containsMouse ? 1.0 : 0.9) : 0.0
                                visible: opacity > 0
                                scale: opacityResetMa.pressed ? 0.9 : (opacityResetMa.containsMouse ? 1.05 : 1.0)

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                                DankRipple {
                                    anchors.fill: parent
                                    cornerRadius: parent.radius
                                    rippleColor: Theme.primary
                                }

                                DankIcon {
                                    name: "restart_alt"
                                    size: 18
                                    anchors.centerIn: parent
                                    color: opacityResetMa.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                    rotation: opacityResetMa.containsMouse ? 90 : 0
                                    Behavior on rotation { NumberAnimation { duration: 450; easing.type: Easing.OutBack } }
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                MouseArea {
                                    id: opacityResetMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        osdOpacitySlider.value = 85;
                                        root.saveValue(osdOpacitySlider.settingKey, 0.85);
                                    }
                                }
                            }
                        }

                        DankSlider {
                            id: osdOpacitySlider
                            property string settingKey: "osdOpacity"
                            Layout.fillWidth: true
                            minimum: 10
                            maximum: 100
                            step: 1
                            unit: "%"
                            value: 85

                            function loadValue() {
                                var val = root.loadValue(settingKey, 0.85);
                                var num = parseFloat(val);
                                value = (!isNaN(num) && num > 0) ? Math.round(num * 100) : 85;
                            }

                            onSliderValueChanged: val => {
                                root.saveValue(settingKey, Math.max(0.10, Math.min(1.00, val / 100.0)));
                            }
                        }
                    }
                }
            }
        }

        // --- Required Packages Section ---
        Item {
            id: depsWrapper
            width: parent.width
            implicitHeight: depsCol.implicitHeight

            property bool expanded: false
            property var depStatus: ({
                "systemd-inhibit": true,
                "python3": true,
                "bash": true
            })
            property bool isChecking: true

            Process {
                id: depChecker
                command: [
                    "bash", "-c",
                    "python3 -c \"import json, shutil, sys\n" +
                    "cmds = [\n" +
                    "  ('systemd-inhibit', 'systemd-inhibit'),\n" +
                    "  ('python3', 'python3'),\n" +
                    "  ('bash', 'bash')\n" +
                    "]\n" +
                    "results = {k: bool(shutil.which(cmd)) for k, cmd in cmds}\n" +
                    "sys.stdout.write(json.dumps(results))\n\""
                ]
                stdout: StdioCollector {
                    onStreamFinished: {
                        depsWrapper.isChecking = false;
                        try {
                            if (text && text.trim() !== "") {
                                depsWrapper.depStatus = JSON.parse(text.trim());
                            }
                        } catch (e) {
                            console.warn("Failed to parse dependency status:", e);
                        }
                    }
                }
            }

            Component.onCompleted: {
                depChecker.running = true;
            }

            Column {
                id: depsCol
                width: parent.width
                spacing: 0

                Item {
                    id: depsHeaderRow
                    width: parent.width
                    height: 40

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS

                        DankIcon {
                            name: "extension"
                            size: 16
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Required packages")
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.DemiBold
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankIcon {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        name: "expand_more"
                        size: Theme.iconSize || 20
                        color: Theme.surfaceVariantText
                        rotation: depsWrapper.expanded ? 180 : 0

                        Behavior on rotation {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            depsWrapper.expanded = !depsWrapper.expanded;
                            if (depsWrapper.expanded) {
                                depsWrapper.isChecking = true;
                                depChecker.running = true;
                            }
                        }
                    }
                }

                Item {
                    id: animHost
                    width: parent.width
                    clip: true
                    height: depsWrapper.expanded ? groupContent.implicitHeight : 0
                    opacity: depsWrapper.expanded ? 1.0 : 0.0
                    visible: height > 0 || depsWrapper.expanded

                    Behavior on height {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutQuad
                        }
                    }

                    SettingsGroup {
                        id: groupContent
                        width: parent.width

                        SettingsRow {
                            visible: depsWrapper.isChecking
                            iconName: "hourglass_top"
                            title: I18n.tr("Checking packages...")
                        }

                        Repeater {
                            model: [
                                {
                                    id: "systemd-inhibit",
                                    pkg: "systemd (systemd-inhibit)",
                                    features: "System and compositor idle/sleep inhibition support",
                                    present: Boolean(depsWrapper.depStatus["systemd-inhibit"])
                                },
                                {
                                    id: "python3",
                                    pkg: "python3",
                                    features: "Executing dependency check diagnostics and plugin helpers",
                                    present: Boolean(depsWrapper.depStatus["python3"])
                                },
                                {
                                    id: "bash",
                                    pkg: "bash",
                                    features: "Standard system shell for process execution and command dispatching",
                                    present: Boolean(depsWrapper.depStatus["bash"])
                                }
                            ]

                            delegate: SettingsRow {
                                iconName: modelData.present ? "check_circle" : "error"
                                iconColor: modelData.present ? Theme.success : Theme.error
                                title: modelData.pkg
                                subtitle: I18n.tr("Used for: %1").arg(modelData.features)
                                trailingBadge: modelData.present ? I18n.tr("Installed") : I18n.tr("Missing")
                                trailingBadgeColor: modelData.present ? Theme.surfaceVariantText : Theme.error
                            }
                        }
                    }
                }
            }
        }
    }
}
