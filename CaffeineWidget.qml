import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Services
import qs.Modules.Plugins

PluginComponent {
    id: root

    // Reactive states
    property bool caffeineActive: false

    // Sync settings
    property bool showToasts: (pluginData.showToasts ?? true)

    // Sync with system state on startup
    Component.onCompleted: {
        // Query if there is an active caffeine process running from a previous shell session
        Proc.runCommand("check-caffeine-active", ["pgrep", "-f", "DMS Caffeine"], function(output, exitCode) {
            caffeineActive = (exitCode === 0 && output.trim() !== "")
        })
    }

    function toggleCaffeine() {
        if (caffeineActive) {
            // Deactivate
            Proc.runCommand("deactivate-caffeine", ["pkill", "-f", "DMS Caffeine"], function(output, exitCode) {
                caffeineActive = false
                if (showToasts) {
                    ToastService?.showInfo("Screen sleep is now allowed.")
                }
            })
        } else {
            // Activate
            Quickshell.execDetached([
                "systemd-inhibit", 
                "--what=idle", 
                "--who=DMS Caffeine", 
                "--why=Manual stay awake override", 
                "sleep", "infinity"
            ])
            caffeineActive = true
            if (showToasts) {
                ToastService?.showSuccess("Screen will stay awake.")
            }
        }
    }

    pillClickAction: () => {
        toggleCaffeine()
    }

    // Horizontal Pill (DankBar)
    horizontalBarPill: Component {
        DankIcon {
            name: "local_cafe"
            size: Theme.iconSizeSmall
            color: caffeineActive ? Theme.primary : Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // Vertical Pill (DankBar side positioning support)
    verticalBarPill: Component {
        DankIcon {
            name: "local_cafe"
            size: Theme.iconSizeSmall
            color: caffeineActive ? Theme.primary : Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
