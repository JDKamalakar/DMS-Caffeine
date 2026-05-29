import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "./dms-common"

PluginSettings {
    pluginId: "caffeine"

    SettingsCard {
        SectionTitle { text: I18n.tr("Presets & Default"); icon: "tune" }

        StringSetting {
            settingKey: "presets"
            label: I18n.tr("Quick Presets (minutes or 'infinity')")
            description: I18n.tr("Comma-separated list of durations (in minutes, or 'infinity' for infinite stay-awake).")
            placeholder: "5, 15, 30, 60, 120, infinity"
            defaultValue: "5, 15, 30, 60, 120, infinity"
        }

        StringSetting {
            settingKey: "defaultDuration"
            label: I18n.tr("Default Duration")
            description: I18n.tr("The default duration (in minutes or 'infinity') used on direct toggling.")
            placeholder: "infinity"
            defaultValue: "infinity"
        }
    }

    SettingsCard {
        SectionTitle { text: I18n.tr("Notifications"); icon: "notifications" }

        ToggleSetting {
            settingKey: "showToasts"
            label: I18n.tr("Show Status Toasts")
            description: I18n.tr("Show a quick pop-up toast when screen stay-awake is toggled.")
            defaultValue: true
        }
    }

    PluginAbout {
        pluginName: "Caffeine"
        pluginIcon: "coffee"
        repoUrl: "https://github.com/hthienloc/dms-caffeine"
    }
}
