import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    pluginId: "caffeine"

    PluginHeader {
        title: "Caffeine Settings"
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
