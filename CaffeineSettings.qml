import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "../dms-common"

PluginSettings {
    pluginId: "caffeine"

    PluginHeader {
        title: "Caffeine Settings"
    }

    SettingsCard {
        SectionTitle { text: "Presets & Default" }

        StringSetting {
            settingKey: "presets"
            label: "Quick Presets (minutes or 'infinity')"
            description: "Comma-separated list of durations (in minutes, or 'infinity' for infinite stay-awake)."
            placeholder: "5, 15, 30, 60, 120, infinity"
            defaultValue: "5, 15, 30, 60, 120, infinity"
        }

        StringSetting {
            settingKey: "defaultDuration"
            label: "Default Duration"
            description: "The default duration (in minutes or 'infinity') used on direct toggling."
            placeholder: "infinity"
            defaultValue: "infinity"
        }
    }

    SettingsCard {
        SectionTitle { text: "Notifications" }

        ToggleSetting {
            settingKey: "showToasts"
            label: "Show Status Toasts"
            description: "Show a quick pop-up toast when screen stay-awake is toggled."
            defaultValue: true
        }
    }
}
