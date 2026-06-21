import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Services

PluginSettings {
    id: root
    pluginId: "caffeine_redesigned"

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

    Column {
        id: mainSettingsCol
        width: parent.width
        spacing: Theme.spacingL

        function loadValue(key, def) {
            return PluginService.loadPluginData(root.pluginId, key, def);
        }

        function saveValue(key, val) {
            PluginService.savePluginData(root.pluginId, key, val);
        }

        function loadValueInternal() {
            presetsRect.loadValue();
            notificationsRect.loadValue();
        }
        
        Component.onCompleted: loadValueInternal()

        Rectangle {
            id: presetsRect
            width: parent.width
            height: presetsGroup.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1
            opacity: 0.8

            function loadValue() {
                presetsField.loadValue();
                defaultDurationDropdown.loadValue();
            }

            Column {
                id: presetsGroup
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM
                        DankIcon { name: "tune"; size: 22; Layout.alignment: Qt.AlignVCenter; opacity: 0.8 }
                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: Theme.spacingXXS
                            StyledText { text: "Quick Presets"; width: parent.width; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Comma-separated list of durations (in minutes, or 'infinity')."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        }
                        Rectangle {
                            id: presetsResetBtn
                            width: 32; height: 32
                            radius: Theme.cornerRadius
                            Layout.alignment: Qt.AlignVCenter
                            color: presetsResetMa.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                            border.color: presetsResetMa.containsMouse ? Theme.primary : Theme.outline
                            border.width: 1
                            opacity: presetsField.text !== presetsField.defaultValue ? (presetsResetMa.containsMouse ? 1.0 : 0.9) : 0.0
                            visible: opacity > 0
                            scale: presetsResetMa.containsMouse ? 1.1 : 1.0
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            Behavior on opacity { NumberAnimation { duration: 250 } }
                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

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
                                    mainSettingsCol.saveValue(presetsField.settingKey, presetsField.defaultValue);
                                }
                                onPressed: (m) => presetsRip.trigger(m.x, m.y)
                            }
                        }
                    }

                    DankTextField {
                        id: presetsField
                        property string settingKey: "presets"
                        property string defaultValue: "5, 15, 30, 60, 120, infinity"
                        width: parent.width
                        placeholderText: defaultValue
                        
                        function loadValue() {
                            text = mainSettingsCol.loadValue(settingKey, defaultValue);
                        }
                        Component.onCompleted: loadValue()
                        onEditingFinished: {
                            mainSettingsCol.saveValue(settingKey, text);
                        }
                    }

                    Item { width: 1; height: Theme.spacingXS }

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM
                        DankIcon { name: "schedule"; size: 22; Layout.alignment: Qt.AlignVCenter; opacity: 0.8 }
                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: Theme.spacingXXS
                            StyledText { text: "Default Duration"; width: parent.width; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "The default duration used on direct toggling, or 'cycle' to switch presets."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        }
                        Rectangle {
                            id: defaultDurationResetBtn
                            width: 32; height: 32
                            radius: Theme.cornerRadius
                            Layout.alignment: Qt.AlignVCenter
                            color: defaultDurationResetMa.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                            border.color: defaultDurationResetMa.containsMouse ? Theme.primary : Theme.outline
                            border.width: 1
                            opacity: defaultDurationDropdown.currentValue !== "Infinite" ? (defaultDurationResetMa.containsMouse ? 1.0 : 0.9) : 0.0
                            visible: opacity > 0
                            scale: defaultDurationResetMa.containsMouse ? 1.1 : 1.0
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            Behavior on opacity { NumberAnimation { duration: 250 } }
                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

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
                                    mainSettingsCol.saveValue(defaultDurationDropdown.settingKey, defaultDurationDropdown.defaultValue);
                                }
                                onPressed: (m) => defaultDurationRip.trigger(m.x, m.y)
                            }
                        }
                    }

                    DankDropdown {
                        id: defaultDurationDropdown
                        property string settingKey: "defaultDuration"
                        property string defaultValue: "infinity"
                        width: parent.width
                        
                        options: root.parsedOptions.map(function(opt) { return opt.label; })
                        
                        function loadValue() {
                            var savedVal = mainSettingsCol.loadValue(settingKey, defaultValue);
                            var found = root.parsedOptions.find(function(opt) { return opt.value === savedVal; });
                            currentValue = found ? found.label : "Infinite";
                        }
                        
                        Component.onCompleted: loadValue()
                        
                        onValueChanged: value => {
                            var found = root.parsedOptions.find(function(opt) { return opt.label === value; });
                            if (found) {
                                mainSettingsCol.saveValue(settingKey, found.value);
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: notificationsRect
            width: parent.width
            height: notificationsGroup.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1
            opacity: 0.8

            function loadValue() {
                showToastsToggle.loadValue();
            }

            Column {
                id: notificationsGroup
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    RowLayout {
                        id: toastsLabelRow
                        width: parent.width
                        spacing: Theme.spacingM
                        DankIcon { name: "notifications"; size: 22; Layout.alignment: Qt.AlignVCenter; opacity: 0.8 }
                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: Theme.spacingXXS
                            StyledText { text: "Show Status Toasts"; width: parent.width; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Show a quick pop-up toast when screen stay-awake is toggled."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        }
                        DankToggle {
                            id: showToastsToggle
                            Layout.alignment: Qt.AlignVCenter
                            property string settingKey: "showToasts"
                            checked: true
                            
                            function loadValue() {
                                var val = mainSettingsCol.loadValue(settingKey, true);
                                checked = (val === true || val === "true");
                            }
                            Component.onCompleted: loadValue()
                            
                            onToggled: isChecked => {
                                mainSettingsCol.saveValue(settingKey, isChecked);
                            }
                        }
                    }
                }
            }
        }
    }
}
