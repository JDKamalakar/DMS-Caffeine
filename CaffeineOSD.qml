import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: osdRoot

    property var rootPlugin: null
    property string osdPosition: {
        if (!rootPlugin || !rootPlugin.pluginData) return "off";
        var pos = rootPlugin.pluginData.customOsdPosition;
        return (pos !== undefined && pos !== null && pos !== "") ? pos : "off";
    }

    // Wayland Layershell configuration
    WlrLayershell.namespace: "dms:plugins:caffeine:osd"
    WlrLayershell.layer: LayerShell.fromEnv("DMS_OSD_LAYER", WlrLayer.Overlay, {
        "allow": ["top", "overlay"],
        "invalidLayer": WlrLayer.Overlay,
        "label": "Caffeine OSD"
    })
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    // Transparent input mask: clicks pass straight through to the desktop/windows
    mask: Region {}

    screen: CompositorService.getFocusedScreen() || Quickshell.screens[0]
    color: "transparent"
    visible: osdPosition !== "off" && isOsdActive

    readonly property bool enableBlur: BlurService.enabled && (Theme.connectedSurfaceBlurEnabled !== false)
    readonly property real bgOpacity: rootPlugin ? (rootPlugin.osdOpacity !== undefined ? rootPlugin.osdOpacity : 0.85) : 0.85

    BackgroundEffect.blurRegion: (visible && enableBlur) ? osdBlurRegion : null

    Region {
        id: osdBlurRegion
        x: cardContainer.x
        y: cardContainer.y
        width: cardContainer.width
        height: cardContainer.height
        radius: cardContainer.height / 2
    }

    // Precise anchors: only occupy the bounds of the pill + margins
    anchors {
        top: osdPosition.startsWith("top")
        bottom: osdPosition.startsWith("bottom")
        left: osdPosition.includes("left")
        right: osdPosition.includes("right")
    }

    margins {
        top: 48
        bottom: 48
        left: 48
        right: 48
    }

    implicitWidth: Math.max(cardContainer.width + 16, 68)
    implicitHeight: cardContainer.height + 16

    property bool isOsdActive: false
    property bool isExpanded: false
    property bool isTurnOffMode: false
    property string displayDuration: ""
    property string displaySubtitle: ""

    readonly property string liveRemainingFormatted: {
        if (!rootPlugin) return "";
        if (isTurnOffMode) return I18n.tr("Off");
        if (rootPlugin.selectedDuration === "infinity" || rootPlugin.selectedDuration === "undefined" || !rootPlugin.selectedDuration) {
            return "∞";
        }
        const totalSecs = rootPlugin.timeLeft;
        if (totalSecs <= 0) return I18n.tr("Active");
        const hrs = Math.floor(totalSecs / 3600);
        const mins = Math.floor((totalSecs % 3600) / 60);
        const secs = totalSecs % 60;
        if (hrs > 0) {
            return hrs + "h " + mins + "m " + secs + "s";
        }
        if (mins > 0) {
            return mins + "m " + secs + "s";
        }
        return secs + "s";
    }

    function triggerOSD(dur) {
        if (osdPosition === "off") return;
        screen = CompositorService.getFocusedScreen() || Quickshell.screens[0];
        isTurnOffMode = false;

        if (dur === "infinity" || dur === "undefined" || !dur) {
            displayDuration = I18n.tr("Infinite");
            displaySubtitle = I18n.tr("Keeping screen awake indefinitely");
        } else {
            var secs = parseInt(dur);
            if (!isNaN(secs) && secs > 0) {
                var mins = Math.round(secs / 60);
                if (mins < 60) {
                    displayDuration = mins + " " + I18n.tr("Min");
                } else {
                    var hrs = mins / 60;
                    displayDuration = (hrs === Math.round(hrs) ? hrs : hrs.toFixed(1)) + " " + I18n.tr("Hours");
                }
                displaySubtitle = I18n.tr("Screen will stay awake for ") + displayDuration;
            } else {
                displayDuration = I18n.tr("Active");
                displaySubtitle = I18n.tr("Keeping screen awake");
            }
        }

        holdTimer.stop();
        collapseAnim.stop();

        isOsdActive = true;
        isExpanded = false;
        cardContainer.opacity = 1.0;
        cardContainer.scale = 1.0;
        expandAnim.restart();
    }

    function triggerTurnOffOSD() {
        if (osdPosition === "off") return;
        screen = CompositorService.getFocusedScreen() || Quickshell.screens[0];
        isTurnOffMode = true;

        displayDuration = I18n.tr("Off");
        displaySubtitle = I18n.tr("Screen sleep is now allowed");

        holdTimer.stop();
        collapseAnim.stop();

        isOsdActive = true;
        isExpanded = false;
        cardContainer.opacity = 1.0;
        cardContainer.scale = 1.0;
        expandAnim.restart();
    }

    Timer {
        id: holdTimer
        interval: 2600
        repeat: false
        onTriggered: {
            collapseAnim.restart();
        }
    }

    SequentialAnimation {
        id: expandAnim
        // Stage 1: Pop in circle
        NumberAnimation { target: cardContainer; property: "scale"; from: 0.8; to: 1.0; duration: 180; easing.type: Easing.OutBack }
        // Stage 2: Animate expand from circle to pill
        PropertyAction { target: osdRoot; property: "isExpanded"; value: true }
        PauseAnimation { duration: 50 }
        // Stage 3: Hold expanded
        ScriptAction { script: holdTimer.restart(); }
    }

    SequentialAnimation {
        id: collapseAnim
        // Stage 1: Animate collapse pill to circle
        PropertyAction { target: osdRoot; property: "isExpanded"; value: false }
        PauseAnimation { duration: 250 }
        // Stage 2: Fade out & shrink
        ParallelAnimation {
            NumberAnimation { target: cardContainer; property: "opacity"; to: 0.0; duration: 220; easing.type: Easing.InQuad }
            NumberAnimation { target: cardContainer; property: "scale"; to: 0.75; duration: 220; easing.type: Easing.InBack }
        }
        // Stage 3: Explicitly hide window and clear blur
        ScriptAction {
            script: {
                osdRoot.isOsdActive = false;
                BackgroundEffect.blurRegion = null;
            }
        }
    }

    Item {
        id: cardContainer
        anchors.centerIn: (osdPosition === "center" || osdPosition === "top_center" || osdPosition === "bottom_center" || osdPosition === "left_center" || osdPosition === "right_center") ? parent : undefined
        anchors.left: osdPosition.includes("left") ? parent.left : undefined
        anchors.right: osdPosition.includes("right") ? parent.right : undefined
        anchors.top: osdPosition.startsWith("top") ? parent.top : undefined
        anchors.bottom: osdPosition.startsWith("bottom") ? parent.bottom : undefined

        width: osdRoot.isExpanded ? Math.max(52, osdTextCol.implicitWidth + 40 + 6 + 10 + 24) : 52
        height: 52
        opacity: 0.0
        scale: 0.8
        clip: true

        Behavior on width {
            NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
        }
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
        Behavior on scale {
            NumberAnimation { duration: 200 }
        }

        // Main Pill Capsule
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Theme.withAlpha(Theme.surfaceContainerHigh || Theme.surfaceVariant || Theme.surface || "#252525", osdRoot.bgOpacity)
            border.width: 1.5
            border.color: osdRoot.isTurnOffMode
                ? Qt.rgba(Theme.surfaceVariantText.r, Theme.surfaceVariantText.g, Theme.surfaceVariantText.b, 0.4)
                : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4)

            // Left icon container
            Rectangle {
                id: iconCircle
                width: 40
                height: 40
                radius: 20
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                color: osdRoot.isTurnOffMode
                    ? Qt.rgba(Theme.surfaceVariantText.r, Theme.surfaceVariantText.g, Theme.surfaceVariantText.b, 0.14)
                    : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)

                DankIcon {
                    name: osdRoot.isTurnOffMode ? "bedtime" : "local_cafe"
                    size: 20
                    color: osdRoot.isTurnOffMode ? Theme.surfaceVariantText : Theme.primary
                    anchors.centerIn: parent
                }
            }

            // Expanding Information Text Row
            Row {
                id: contentRow
                anchors.left: iconCircle.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                opacity: osdRoot.isExpanded ? 1.0 : 0.0
                scale: osdRoot.isExpanded ? 1.0 : 0.9
                spacing: 8
                clip: true

                Behavior on opacity {
                    NumberAnimation { duration: 220; easing.type: Easing.OutQuad }
                }
                Behavior on scale {
                    NumberAnimation { duration: 220; easing.type: Easing.OutBack }
                }

                Column {
                    id: osdTextCol
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Row {
                        spacing: 6
                        StyledText {
                            text: I18n.tr("Caffeine")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                        }

                        Rectangle {
                            height: 18
                            width: durBadgeText.implicitWidth + 10
                            radius: 9
                            color: osdRoot.isTurnOffMode
                                ? Qt.rgba(Theme.surfaceVariantText.r, Theme.surfaceVariantText.g, Theme.surfaceVariantText.b, 0.16)
                                : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                id: durBadgeText
                                anchors.centerIn: parent
                                text: {
                                    if (osdRoot.isTurnOffMode) return I18n.tr("Off");
                                    if (rootPlugin && rootPlugin.caffeineActive && rootPlugin.selectedDuration !== "infinity") {
                                        return osdRoot.liveRemainingFormatted;
                                    }
                                    return osdRoot.displayDuration;
                                }
                                font.pixelSize: Theme.fontSizeSmall - 1
                                font.weight: Font.DemiBold
                                color: osdRoot.isTurnOffMode ? Theme.surfaceVariantText : Theme.primary
                            }
                        }
                    }

                    StyledText {
                        text: osdRoot.displaySubtitle
                        font.pixelSize: Theme.fontSizeSmall - 1
                        color: Theme.surfaceVariantText
                        opacity: 0.9
                    }
                }
            }
        }
    }
}
