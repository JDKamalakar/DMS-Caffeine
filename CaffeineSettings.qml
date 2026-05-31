import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "./dms-common"

PluginSettings {
    id: root
    pluginId: "caffeine"

    SettingsCard {
        id: presetsSection
        SectionTitle { 
            text: I18n.tr("Presets & Default")
            icon: "tune" 
            showReset: presets.isDirty || defaultDuration.isDirty
            onResetClicked: {
                presets.resetToDefault();
                defaultDuration.resetToDefault();
            }
        }

        StringSettingPlus {
            id: presets
            settingKey: "presets"
            label: I18n.tr("Quick Presets")
            description: I18n.tr("Comma-separated list of durations (in minutes, or 'infinity').")
            placeholder: "5, 15, 30, 60, 120, infinity"
            defaultValue: "5, 15, 30, 60, 120, infinity"
        }

        Separator {}

        StringSettingPlus {
            id: defaultDuration
            settingKey: "defaultDuration"
            label: I18n.tr("Default Duration")
            description: I18n.tr("The default duration used on direct toggling.")
            placeholder: "infinity"
            defaultValue: "infinity"
        }
    }

    SettingsCard {
        id: notificationsSection
        SectionTitle { 
            text: I18n.tr("Notifications")
            icon: "notifications" 
            showReset: showToasts.isDirty
            onResetClicked: {
                showToasts.resetToDefault();
            }
        }

        ToggleSettingPlus {
            id: showToasts
            settingKey: "showToasts"
            label: I18n.tr("Show Status Toasts")
            description: I18n.tr("Show a quick pop-up toast when screen stay-awake is toggled.")
            defaultValue: true
        }
    }

    SettingsCard {
        SectionTitle { 
            id: usageTitle
            text: I18n.tr("Usage Guide")
            icon: "menu_book" 
            collapsible: true
            settingKey: "usageGuideExpanded"
        }

        UsageGuide {
            expanded: usageTitle.isExpanded
            items: [
                I18n.tr("<b>Left-click</b> the pill to open the duration picker popout."),
                I18n.tr("<b>Right-click</b> the pill to quick toggle stay-awake with default duration."),
                I18n.tr("The icon will glow when <b>Caffeine</b> is active.")
            ]
        }
    }

    PluginAbout {
        repoUrl: "https://github.com/hthienloc/dms-caffeine"
    }
}
