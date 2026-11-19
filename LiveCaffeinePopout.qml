import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import qs.Common
import qs.Widgets
import qs.Services

Item {
    id: liveRoot
    width: parent ? parent.width : 340
    implicitHeight: liveMainCol.implicitHeight

    required property var rootPlugin

    readonly property bool isBarVertical: rootPlugin.isBarVertical
    readonly property bool caffeineActive: rootPlugin.caffeineActive
    readonly property string selectedDuration: rootPlugin.selectedDuration
    readonly property real sessionProgress: rootPlugin.sessionProgress
    readonly property string formattedTimeLeft: rootPlugin.formattedTimeLeft
    readonly property int quickExtendMinutes: rootPlugin.quickExtendMinutes
    readonly property bool colorfulProgress: rootPlugin.colorfulProgress

    readonly property color progressThemeColor: {
        if (!colorfulProgress) return Theme.primary;
        if (selectedDuration === "infinity") return Qt.rgba(0.20, 0.78, 0.35, 1.0); // Vivid Emerald Green
        // Dynamic color transition based on remaining time ratio:
        // When plenty of time remaining -> Green (#2ECC71)
        // Mid-way -> Amber (#FFB300)
        // When running out of time (< 20% remaining) -> Red (#F44336)
        let remRatio = 1.0 - sessionProgress;
        if (remRatio >= 0.50) {
            let t = (remRatio - 0.50) / 0.50; // 0 (at 0.5) to 1 (at 1.0 full time remaining)
            // lerp from amber (#FFB300) to green (#2ECC71)
            return Qt.rgba(1.0 - 0.82 * t, 0.70 + 0.10 * t, 0.0 + 0.44 * t, 1.0);
        } else if (remRatio >= 0.20) {
            let t = (remRatio - 0.20) / 0.30; // 0 (at 0.2) to 1 (at 0.5)
            // lerp from red (#F44336) to amber (#FFB300)
            return Qt.rgba(1.0, 0.34 + 0.36 * t, 0.13 - 0.13 * t, 1.0);
        } else {
            return Qt.rgba(0.96, 0.26, 0.21, 1.0); // Critical Red when low time remaining
        }
    }

    Column {
        id: liveMainCol
        width: parent.width
        spacing: liveRoot.rootPlugin.customInputExpanded ? 4 : Theme.spacingM
        Behavior on spacing { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        // =========================================================================
        // A. HORIZONTAL BAR LAYOUT (Standard Card + Expandable Custom Time Card)
        // =========================================================================
        StyledRect {
            id: hNotificationCard
            visible: !liveRoot.isBarVertical
            width: parent.width
            readonly property real cardOuterRadius: Theme.cornerRadius + 4
            readonly property real cardInnerRadius: Theme.cornerRadius / 2
            topLeftRadius: cardOuterRadius
            topRightRadius: cardOuterRadius
            bottomLeftRadius: liveRoot.rootPlugin.customInputExpanded ? cardInnerRadius : cardOuterRadius
            bottomRightRadius: liveRoot.rootPlugin.customInputExpanded ? cardInnerRadius : cardOuterRadius
            Behavior on bottomLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
            Behavior on bottomRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
            color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
            border.width: 1
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
            implicitHeight: hCardCol.implicitHeight + Theme.spacingM * 2

            Column {
                id: hCardCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                // --- 1. Header: App Chip, Caffeine Title, "now", Notification Bell ---
                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingS

                    Rectangle {
                        width: 26
                        height: 26
                        radius: 13
                        color: Theme.withAlpha(Theme.primary, 0.2)
                        border.width: 1
                        border.color: Theme.withAlpha(Theme.primary, 0.4)

                        DankIcon {
                            name: "local_cafe"
                            size: 15
                            color: Theme.primary
                            anchors.centerIn: parent
                        }
                    }

                    Row {
                        Layout.fillWidth: true
                        spacing: 4

                        StyledText {
                            text: I18n.tr("Caffeine")
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.DemiBold
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: "•"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        StyledText {
                            text: I18n.tr("now")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }

                    DankIcon {
                        name: "notifications_active"
                        size: 16
                        color: Theme.primary
                        opacity: 0.85
                    }
                }

                // --- 2. Title & Subtitle ---
                Column {
                    width: parent.width
                    spacing: 2

                    StyledText {
                        text: {
                            if (!liveRoot.caffeineActive) return I18n.tr("Caffeine is inactive");
                            if (liveRoot.selectedDuration === "infinity") return I18n.tr("Keeping screen awake indefinitely");
                            return I18n.tr("Screen awake: %1 remaining").arg(liveRoot.formattedTimeLeft);
                        }
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                    }

                    StyledText {
                        text: {
                            if (!liveRoot.caffeineActive) return I18n.tr("System idle sleep and lock are allowed");
                            if (liveRoot.selectedDuration === "infinity") return I18n.tr("Sleep inhibitor active until manually turned off");
                            return I18n.tr("Preventing display idle timeout and system suspension");
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }

                // --- 3. Thicker Progress Bar with M3 Wave & Inverted Caffeine Indicator ---
                Item {
                    id: hProgressContainer
                    width: parent.width
                    height: 32

                    CaffeineWaveProgress {
                        id: hWaveProgress
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 28
                        readonly property real targetVal: {
                            if (liveRoot.selectedDuration === "infinity") return 1.0;
                            if (hProgressContainer.width <= 0) return liveRoot.sessionProgress;
                            return Math.min(1.0, Math.max(0.0, (hPlayheadBadge.x + hPlayheadBadge.width * 0.5) / hProgressContainer.width));
                        }
                        value: targetVal
                        Behavior on value { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                        actualValue: value
                        isPlaying: liveRoot.caffeineActive
                        lineWidth: liveRoot.selectedDuration === "infinity" ? 4.5 : 4.0
                        wavelength: 26
                        amp: liveRoot.selectedDuration === "infinity" ? 3.8 : 2.8
                        fillColor: liveRoot.progressThemeColor
                        playheadColor: "transparent"
                        trackColor: Theme.withAlpha(Theme.surfaceContainerHighest, 0.65)
                        actualProgressColor: Theme.withAlpha(liveRoot.progressThemeColor, 0.4)
                    }

                    // Floating Inverted Caffeine Status Badge on Horizontal Playhead
                    Rectangle {
                        id: hPlayheadBadge
                        width: 22
                        height: 22
                        radius: 11
                        color: liveRoot.progressThemeColor
                        border.width: 0
                        anchors.verticalCenter: parent.verticalCenter
                        x: {
                            if (liveRoot.selectedDuration === "infinity") {
                                return (parent.width - width) / 2;
                            }
                            const travelW = parent.width - width;
                            return Math.min(travelW, Math.max(0, travelW * liveRoot.sessionProgress));
                        }
                        Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                        DankIcon {
                            name: liveRoot.selectedDuration === "infinity" ? "all_inclusive" : "local_cafe"
                            size: 13
                            color: Theme.onPrimary
                            anchors.centerIn: parent
                        }
                    }
                }

                // --- 4. Horizontal Buttons (First-Mid-Last Row) ---
                Item {
                    width: parent.width
                    height: 42

                    readonly property real outerRadius: Theme.cornerRadius
                    readonly property real innerRadius: Theme.cornerRadius / 2
                    readonly property real pillRadius: Math.floor((height - 1) / 2)
                    readonly property bool showExtend: liveRoot.selectedDuration !== "infinity"

                    RowLayout {
                        anchors.fill: parent
                        spacing: Theme.spacingXS

                        // 1. Extend Button
                        Item {
                            id: hExtItem
                            Layout.fillHeight: true
                            Layout.fillWidth: !isInfinite
                            Layout.preferredWidth: isInfinite ? 0 : -1
                            Behavior on Layout.preferredWidth { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                            visible: opacity > 0.001
                            opacity: !isInfinite ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                            clip: true
                            readonly property bool isInfinite: liveRoot.selectedDuration === "infinity"

                            readonly property bool hovered: hExtArea.containsMouse

                            Rectangle {
                                id: hExtBg
                                anchors.fill: parent
                                topLeftRadius: (hExtArea.pressed || hExtItem.hovered) ? parent.parent.parent.pillRadius : parent.parent.parent.outerRadius
                                topRightRadius: (hExtArea.pressed || hExtItem.hovered) ? parent.parent.parent.pillRadius : parent.parent.parent.innerRadius
                                bottomLeftRadius: (hExtArea.pressed || hExtItem.hovered) ? parent.parent.parent.pillRadius : parent.parent.parent.outerRadius
                                bottomRightRadius: (hExtArea.pressed || hExtItem.hovered) ? parent.parent.parent.pillRadius : parent.parent.parent.innerRadius

                                Behavior on topLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on topRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on bottomLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on bottomRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                                color: hExtArea.pressed
                                    ? Theme.primaryPressed
                                    : (hExtItem.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.04))
                                border.width: 1
                                border.color: (hExtArea.pressed || hExtItem.hovered)
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.6)
                                    : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                DankRipple {
                                    id: hExtRip
                                    anchors.fill: parent
                                    cornerRadius: hExtBg.topLeftRadius
                                    rippleColor: Theme.primary
                                }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    DankIcon {
                                        name: "add_circle_outline"
                                        size: 16
                                        color: Theme.primary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: I18n.tr("+%1 min").arg(liveRoot.quickExtendMinutes)
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.DemiBold
                                        color: Theme.primary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    DankIcon {
                                        name: liveRoot.rootPlugin.customInputExpanded ? "expand_less" : "expand_more"
                                        size: 14
                                        color: Theme.withAlpha(Theme.primary, 0.7)
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            property bool hDidLongPress: false

                            Timer {
                                id: hLongPressTimer
                                interval: 280
                                repeat: false
                                onTriggered: {
                                    hExtItem.hDidLongPress = true;
                                    liveRoot.rootPlugin.customInputExpanded = !liveRoot.rootPlugin.customInputExpanded;
                                }
                            }

                            MouseArea {
                                id: hExtArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton

                                onPressed: mouse => {
                                    let mapped = mapToItem(parent, mouse.x, mouse.y);
                                    hExtRip.trigger(mapped.x, mapped.y);
                                    hExtItem.hDidLongPress = false;
                                    if (mouse.button === Qt.LeftButton) {
                                        hLongPressTimer.restart();
                                    }
                                }
                                onReleased: mouse => {
                                    if (mouse.button === Qt.LeftButton) {
                                        if (hLongPressTimer.running) {
                                            hLongPressTimer.stop();
                                            if (!hExtItem.hDidLongPress) {
                                                liveRoot.rootPlugin.extendCaffeine(liveRoot.quickExtendMinutes * 60);
                                            }
                                        }
                                    }
                                }
                                onCanceled: {
                                    hLongPressTimer.stop();
                                    hExtItem.hDidLongPress = false;
                                }
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        liveRoot.rootPlugin.customInputExpanded = !liveRoot.rootPlugin.customInputExpanded;
                                    }
                                }
                            }
                        }

                         // 2. Infinite Button (Hidden in infinite mode)
                        Item {
                            id: hInfItem
                            Layout.fillHeight: true
                            Layout.fillWidth: !isInfinite
                            Layout.preferredWidth: isInfinite ? 0 : -1
                            Behavior on Layout.preferredWidth { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                            visible: opacity > 0.001
                            opacity: !isInfinite ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                            clip: true
                            readonly property bool isInfinite: liveRoot.selectedDuration === "infinity"

                            readonly property bool isFirst: !parent.parent.showExtend
                            readonly property bool hovered: hInfArea.containsMouse

                            Rectangle {
                                id: hInfBg
                                anchors.fill: parent
                                topLeftRadius: (hInfArea.pressed || hInfItem.hovered) ? parent.parent.parent.pillRadius : (hInfItem.isFirst ? parent.parent.parent.outerRadius : parent.parent.parent.innerRadius)
                                topRightRadius: (hInfArea.pressed || hInfItem.hovered) ? parent.parent.parent.pillRadius : parent.parent.parent.innerRadius
                                bottomLeftRadius: (hInfArea.pressed || hInfItem.hovered) ? parent.parent.parent.pillRadius : (hInfItem.isFirst ? parent.parent.parent.outerRadius : parent.parent.parent.innerRadius)
                                bottomRightRadius: (hInfArea.pressed || hInfItem.hovered) ? parent.parent.parent.pillRadius : parent.parent.parent.innerRadius

                                Behavior on topLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on topRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on bottomLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on bottomRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                                color: hInfArea.pressed
                                    ? Theme.primaryPressed
                                    : (hInfItem.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.04))
                                border.width: 1
                                border.color: (hInfArea.pressed || hInfItem.hovered)
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.6)
                                    : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                DankRipple {
                                    id: hInfRip
                                    anchors.fill: parent
                                    cornerRadius: hInfBg.topLeftRadius
                                    rippleColor: Theme.primary
                                }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    DankIcon {
                                        name: "all_inclusive"
                                        size: 16
                                        color: Theme.primary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: I18n.tr("Infinite")
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.DemiBold
                                        color: Theme.primary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            MouseArea {
                                id: hInfArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onPressed: mouse => {
                                    let mapped = mapToItem(parent, mouse.x, mouse.y);
                                    hInfRip.trigger(mapped.x, mapped.y);
                                }
                                onClicked: {
                                    liveRoot.rootPlugin.changeDuration("infinity", true);
                                }
                            }
                        }

                        // 3. Stop Button (Only button visible when in infinite mode)
                        Item {
                            id: hStopItem
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            readonly property bool isSoleButton: liveRoot.selectedDuration === "infinity"
                            readonly property bool hovered: hStopArea.containsMouse

                            Rectangle {
                                id: hStopBg
                                anchors.fill: parent
                                topLeftRadius: (hStopArea.pressed || hStopItem.hovered) ? parent.parent.parent.pillRadius : (hStopItem.isSoleButton ? parent.parent.parent.outerRadius : parent.parent.parent.innerRadius)
                                topRightRadius: (hStopArea.pressed || hStopItem.hovered) ? parent.parent.parent.pillRadius : parent.parent.parent.outerRadius
                                bottomLeftRadius: (hStopArea.pressed || hStopItem.hovered) ? parent.parent.parent.pillRadius : (hStopItem.isSoleButton ? parent.parent.parent.outerRadius : parent.parent.parent.innerRadius)
                                bottomRightRadius: (hStopArea.pressed || hStopItem.hovered) ? parent.parent.parent.pillRadius : parent.parent.parent.outerRadius

                                Behavior on topLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on topRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on bottomLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on bottomRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                                color: hStopArea.pressed
                                    ? Theme.withAlpha(Theme.error, 0.35)
                                    : (hStopItem.hovered ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.22) : Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12))
                                border.width: 1
                                border.color: (hStopArea.pressed || hStopItem.hovered)
                                    ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.6)
                                    : Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.3)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                DankRipple {
                                    id: hStopRip
                                    anchors.fill: parent
                                    cornerRadius: hStopBg.topLeftRadius
                                    rippleColor: Theme.error
                                }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    DankIcon {
                                        name: "stop_circle"
                                        size: 16
                                        color: Theme.error
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: I18n.tr("Stop")
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Bold
                                        color: Theme.error
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            MouseArea {
                                id: hStopArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onPressed: mouse => {
                                    let mapped = mapToItem(parent, mouse.x, mouse.y);
                                    hStopRip.trigger(mapped.x, mapped.y);
                                }
                                onClicked: {
                                    liveRoot.rootPlugin.deactivateCaffeine();
                                    liveRoot.rootPlugin.closePopout();
                                }
                            }
                        }
                    }
                }
            }
        }

// =========================================================================
        // B. VERTICAL BAR LAYOUT (Side-by-side: Container 1 & Right-side Stack)
        // =========================================================================
        RowLayout {
            id: vMainRow
            visible: liveRoot.isBarVertical
            width: parent.width
            spacing: Theme.spacingM

            // --- CONTAINER 1: Extra Long & Thick Vertical Progress Capsule (Spans full combined height) ---
            StyledRect {
                id: vProgressContainer
                Layout.preferredWidth: 64
                Layout.preferredHeight: vRightCol.fixedHeight
                Layout.alignment: Qt.AlignTop
                radius: Theme.cornerRadius + 4
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.width: 1
                border.color: Qt.rgba(liveRoot.progressThemeColor.r, liveRoot.progressThemeColor.g, liveRoot.progressThemeColor.b, 0.15)
                clip: true

                // Background Track Capsule
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Theme.withAlpha(Theme.surfaceContainerHighest, 0.45)
                }

                // Wavy Track (Visible across entire height for infinite mode, or strictly in unfilled upper track for timed sessions)
                Item {
                    id: vTrackWaveClipItem
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: {
                        if (liveRoot.selectedDuration === "infinity") return parent.height;
                        // Unfilled track starts from top (0) down to the top of the solid fill (vFillClipItem.y = parent.height - vFillClipItem.height)
                        return Math.max(0, parent.height - vFillClipItem.height);
                    }
                    clip: true

                    Item {
                        id: vTrackWaveItem
                        width: vProgressContainer.height
                        height: vProgressContainer.width
                        x: (parent.width - width) / 2
                        y: (vProgressContainer.height - height) / 2
                        rotation: -90

                        CaffeineWaveProgress {
                            anchors.fill: parent
                            value: 1.0
                            actualValue: 1.0
                            isPlaying: liveRoot.caffeineActive
                            lineWidth: liveRoot.selectedDuration === "infinity" ? 4.5 : 3.5
                            wavelength: liveRoot.selectedDuration === "infinity" ? 26 : 32
                            amp: liveRoot.selectedDuration === "infinity" ? 4.5 : 3.2
                            fillColor: liveRoot.selectedDuration === "infinity"
                                ? liveRoot.progressThemeColor
                                : (Theme.isDark ? Qt.rgba(1.0, 1.0, 1.0, 0.25) : Theme.withAlpha(Theme.primary, 0.22))
                            playheadColor: "transparent"
                            trackColor: "transparent"
                            actualProgressColor: liveRoot.selectedDuration === "infinity"
                                ? liveRoot.progressThemeColor
                                : (Theme.isDark ? Qt.rgba(1.0, 1.0, 1.0, 0.25) : Theme.withAlpha(Theme.primary, 0.22))
                        }
                    }
                }

                // Active Cylindrical Progress Fill (For timed sessions; hidden in infinite mode so the continuous wave shines through)
                Item {
                    id: vFillClipItem
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    visible: liveRoot.selectedDuration !== "infinity"
                    height: {
                        if (liveRoot.selectedDuration === "infinity") return 0;
                        return Math.max(0, parent.height * liveRoot.sessionProgress);
                    }
                    clip: true
                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                    Rectangle {
                        id: vFillRect
                        width: vProgressContainer.width
                        height: Math.max(vFillClipItem.height, vProgressContainer.radius * 2)
                        anchors.bottom: parent.bottom
                        radius: vProgressContainer.radius
                        color: liveRoot.progressThemeColor
                        Behavior on color { ColorAnimation { duration: 300 } }

                        SequentialAnimation on opacity {
                            running: liveRoot.selectedDuration === "infinity" && liveRoot.caffeineActive
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.85; duration: 1100; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 0.50; duration: 1100; easing.type: Easing.InOutQuad }
                        }
                    }
                }

                // Wavy track is strictly in unfilled upper track (vTrackWaveClipItem).
                // Solid filled cylindrical area does not show any wavy line inside it.

                // Floating Status Badge on Vertical Track (Consistent circular shape, smooth progressive entry, no drop from top)
                Rectangle {
                    id: vStatusBadge
                    width: 38
                    height: 38
                    radius: 19 // Always strictly circular

                    readonly property real fillBoundaryY: parent.height * (1.0 - liveRoot.sessionProgress)
                    readonly property bool isFullyInside: liveRoot.selectedDuration !== "infinity" && (y + height <= parent.height - 4) && (y >= fillBoundaryY)
                    readonly property bool isPartiallyInside: liveRoot.selectedDuration !== "infinity" && (y + height * 0.5 >= fillBoundaryY)

                    color: isFullyInside ? Theme.surfaceContainerHighest : Theme.surfaceContainerHighest
                    border.width: 2
                    border.color: isFullyInside ? Theme.surfaceContainerHighest : liveRoot.progressThemeColor
                    Behavior on color { ColorAnimation { duration: 250 } }
                    Behavior on border.color { ColorAnimation { duration: 250 } }

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: {
                        if (liveRoot.selectedDuration === "infinity") {
                            return (parent.height - height) / 2;
                        }
                        const travelH = Math.max(0, parent.height - height);
                        const progress = (!liveRoot.caffeineActive || isNaN(liveRoot.sessionProgress)) ? 0.0 : Math.min(1.0, Math.max(0.0, liveRoot.sessionProgress));
                        const basePos = travelH * (1.0 - progress);

                        // Animate moving inside bit by bit as timer progress increases past 80%
                        if (progress >= 0.80) {
                            let ratio = (progress - 0.80) / 0.20; // 0.0 at 80% to 1.0 at 100%
                            let edgeY = parent.height * (1.0 - progress);
                            let maxInsideY = Math.min(travelH - 8, edgeY + 28);
                            return Math.min(travelH, edgeY + ratio * (maxInsideY - edgeY));
                        }
                        return Math.min(travelH, Math.max(0, basePos));
                    }
                    Behavior on y {
                        enabled: liveRoot.caffeineActive && liveRoot.sessionProgress > 0.001
                        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                    }

                    DankIcon {
                        name: liveRoot.selectedDuration === "infinity" ? "all_inclusive" : "local_cafe"
                        size: 15 // Smaller, refined icon inside vertical progress pill
                        color: liveRoot.progressThemeColor
                        Behavior on color { ColorAnimation { duration: 250 } }
                        anchors.centerIn: parent
                    }
                }
            }

            // --- RIGHT COLUMN: Container 2 (Timer & Stacked Buttons) & Container 3 (Add Custom Time) ---
            Item {
                id: vRightCol
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                readonly property real fixedHeight: vTimerButtonContainer.implicitHeight + (vCustomInputCard.implicitHeight + 4)
                implicitHeight: fixedHeight
                Layout.preferredHeight: fixedHeight

                // --- CONTAINER 2: Timer, Details & Stacked Buttons ---
                StyledRect {
                    id: vTimerButtonContainer
                    width: parent.width
                    anchors.left: parent.left
                    anchors.right: parent.right
                    readonly property real cardOuterRadius: Theme.cornerRadius + 4
                    readonly property real cardInnerRadius: Theme.cornerRadius / 2
                    topLeftRadius: cardOuterRadius
                    topRightRadius: cardOuterRadius
                    bottomLeftRadius: liveRoot.rootPlugin.customInputExpanded ? cardInnerRadius : cardOuterRadius
                    bottomRightRadius: liveRoot.rootPlugin.customInputExpanded ? cardInnerRadius : cardOuterRadius
                    Behavior on bottomLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                    Behavior on bottomRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                    y: liveRoot.rootPlugin.customInputExpanded ? 0 : Math.round((vRightCol.fixedHeight - height) / 2)
                    Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    border.width: 1
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    implicitHeight: vTimerCol.implicitHeight + Theme.spacingM * 2

                    ColumnLayout {
                        id: vTimerCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingM

                        // Header
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingS

                            Rectangle {
                                width: 26
                                height: 26
                                radius: 13
                                color: Theme.withAlpha(Theme.primary, 0.2)
                                border.width: 1
                                border.color: Theme.withAlpha(Theme.primary, 0.4)

                                DankIcon {
                                    name: "local_cafe"
                                    size: 15
                                    color: Theme.primary
                                    anchors.centerIn: parent
                                }
                            }

                            Row {
                                Layout.fillWidth: true
                                spacing: 4

                                StyledText {
                                    text: I18n.tr("Caffeine")
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.DemiBold
                                    color: Theme.surfaceText
                                }

                                StyledText {
                                    text: "•"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }

                                StyledText {
                                    text: I18n.tr("now")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }
                            }

                            DankIcon {
                                name: "notifications_active"
                                size: 16
                                color: Theme.primary
                                opacity: 0.85
                            }
                        }

                        // Headline & Subtitle
                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                width: parent.width
                                text: {
                                    if (!liveRoot.caffeineActive) return I18n.tr("Caffeine is inactive");
                                    if (liveRoot.selectedDuration === "infinity") return I18n.tr("Staying awake indefinitely");
                                    return I18n.tr("%1 remaining").arg(liveRoot.formattedTimeLeft);
                                }
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                                elide: Text.ElideRight
                            }

                            StyledText {
                                width: parent.width
                                text: {
                                    if (!liveRoot.caffeineActive) return I18n.tr("System sleep allowed");
                                    if (liveRoot.selectedDuration === "infinity") return I18n.tr("Inhibitor active indefinitely");
                                    return I18n.tr("Preventing idle suspension");
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                elide: Text.ElideRight
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            height: 6
                        }

                        // --- Stacked Vertical Action Buttons ---
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            readonly property real outerRadius: Theme.cornerRadius
                            readonly property real innerRadius: Theme.cornerRadius / 2
                            readonly property real pillRadius: 19


                            // 1. Stacked Stop / Cancel Button (Top, or sole button in infinite mode)
                            Item {
                                id: vStopItem
                                Layout.fillWidth: true
                                height: 42

                                readonly property bool isSoleButton: liveRoot.selectedDuration === "infinity"
                                readonly property bool hovered: vStopArea.containsMouse

                                Rectangle {
                                    id: vStopBg
                                    anchors.fill: parent
                                    topLeftRadius: (vStopArea.pressed || vStopItem.hovered) ? parent.parent.pillRadius : parent.parent.outerRadius
                                    topRightRadius: (vStopArea.pressed || vStopItem.hovered) ? parent.parent.pillRadius : parent.parent.outerRadius
                                    bottomLeftRadius: (vStopArea.pressed || vStopItem.hovered) ? parent.parent.pillRadius : (vStopItem.isSoleButton ? parent.parent.outerRadius : parent.parent.innerRadius)
                                    bottomRightRadius: (vStopArea.pressed || vStopItem.hovered) ? parent.parent.pillRadius : (vStopItem.isSoleButton ? parent.parent.outerRadius : parent.parent.innerRadius)

                                    Behavior on topLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                    Behavior on topRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                    Behavior on bottomLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                    Behavior on bottomRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                                    color: vStopArea.pressed
                                        ? Theme.withAlpha(Theme.error, 0.35)
                                        : (vStopItem.hovered ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.22) : Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12))
                                    border.width: 1
                                    border.color: (vStopArea.pressed || vStopItem.hovered)
                                        ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.6)
                                        : Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.3)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    DankRipple {
                                        id: vStopRip
                                        anchors.fill: parent
                                        cornerRadius: vStopBg.topLeftRadius
                                        rippleColor: Theme.error
                                    }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        DankIcon {
                                            name: "stop_circle"
                                            size: 16
                                            color: Theme.error
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            text: I18n.tr("Stop")
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.Bold
                                            color: Theme.error
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }

                                MouseArea {
                                    id: vStopArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onPressed: mouse => {
                                        let mapped = mapToItem(parent, mouse.x, mouse.y);
                                        vStopRip.trigger(mapped.x, mapped.y);
                                    }
                                    onClicked: {
                                        liveRoot.rootPlugin.deactivateCaffeine();
                                        liveRoot.rootPlugin.closePopout();
                                    }
                                }
                            }

                            // 2. Stacked Infinite Button (Hidden in infinite mode)
                            Item {
                                id: vInfItem
                                Layout.fillWidth: true
                                height: liveRoot.selectedDuration !== "infinity" ? 42 : 0
                                visible: height > 0
                                opacity: liveRoot.selectedDuration !== "infinity" ? 1.0 : 0.0
                                clip: true
                                Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                                readonly property bool hovered: vInfArea.containsMouse
                                readonly property bool isBottom: false

                                Rectangle {
                                    id: vInfBg
                                    anchors.fill: parent
                                    topLeftRadius: (vInfArea.pressed || vInfItem.hovered) ? parent.parent.pillRadius : parent.parent.innerRadius
                                    topRightRadius: (vInfArea.pressed || vInfItem.hovered) ? parent.parent.pillRadius : parent.parent.innerRadius
                                    bottomLeftRadius: (vInfArea.pressed || vInfItem.hovered) ? parent.parent.pillRadius : (vInfItem.isBottom ? parent.parent.outerRadius : parent.parent.innerRadius)
                                    bottomRightRadius: (vInfArea.pressed || vInfItem.hovered) ? parent.parent.pillRadius : (vInfItem.isBottom ? parent.parent.outerRadius : parent.parent.innerRadius)

                                    Behavior on topLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                    Behavior on topRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                    Behavior on bottomLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                    Behavior on bottomRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                                    color: vInfArea.pressed
                                        ? Theme.primaryPressed
                                        : (vInfItem.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.04))
                                    border.width: 1
                                    border.color: (vInfArea.pressed || vInfItem.hovered)
                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.6)
                                        : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    DankRipple {
                                        id: vInfRip
                                        anchors.fill: parent
                                        cornerRadius: vInfBg.topLeftRadius
                                        rippleColor: Theme.primary
                                    }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        DankIcon {
                                            name: "all_inclusive"
                                            size: 16
                                            color: Theme.primary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            text: I18n.tr("Infinite")
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.DemiBold
                                            color: Theme.primary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }

                                MouseArea {
                                    id: vInfArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onPressed: mouse => {
                                        let mapped = mapToItem(parent, mouse.x, mouse.y);
                                        vInfRip.trigger(mapped.x, mapped.y);
                                    }
                                    onClicked: {
                                        liveRoot.rootPlugin.changeDuration("infinity", true);
                                    }
                                }
                            }
                            // 3. Stacked Extend Button (Bottom)
                            Item {
                                id: vExtItem
                                Layout.fillWidth: true
                                height: liveRoot.selectedDuration !== "infinity" ? 42 : 0
                                visible: height > 0
                                opacity: liveRoot.selectedDuration !== "infinity" ? 1.0 : 0.0
                                clip: true
                                Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                                readonly property bool hovered: vExtArea.containsMouse

                                Rectangle {
                                    id: vExtBg
                                    anchors.fill: parent
                                    topLeftRadius: (vExtArea.pressed || vExtItem.hovered) ? parent.parent.pillRadius : parent.parent.innerRadius
                                    topRightRadius: (vExtArea.pressed || vExtItem.hovered) ? parent.parent.pillRadius : parent.parent.innerRadius
                                    bottomLeftRadius: (vExtArea.pressed || vExtItem.hovered) ? parent.parent.pillRadius : parent.parent.outerRadius
                                    bottomRightRadius: (vExtArea.pressed || vExtItem.hovered) ? parent.parent.pillRadius : parent.parent.outerRadius

                                    Behavior on topLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                    Behavior on topRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                    Behavior on bottomLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                    Behavior on bottomRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                                    color: vExtArea.pressed
                                        ? Theme.primaryPressed
                                        : (vExtItem.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.04))
                                    border.width: 1
                                    border.color: (vExtArea.pressed || vExtItem.hovered)
                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.6)
                                        : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    DankRipple {
                                        id: vExtRip
                                        anchors.fill: parent
                                        cornerRadius: vExtBg.topLeftRadius
                                        rippleColor: Theme.primary
                                    }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        DankIcon {
                                            name: "add_circle_outline"
                                            size: 16
                                            color: Theme.primary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            text: I18n.tr("+%1 min").arg(liveRoot.quickExtendMinutes)
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.DemiBold
                                            color: Theme.primary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        DankIcon {
                                            name: liveRoot.rootPlugin.customInputExpanded ? "expand_less" : "expand_more"
                                            size: 14
                                            color: Theme.withAlpha(Theme.primary, 0.7)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }

                                property bool vDidLongPress: false

                                Timer {
                                    id: vLongPressTimer
                                    interval: 350
                                    repeat: false
                                    onTriggered: {
                                        vExtItem.vDidLongPress = true;
                                        liveRoot.rootPlugin.customInputExpanded = !liveRoot.rootPlugin.customInputExpanded;
                                    }
                                }

                                MouseArea {
                                    id: vExtArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                                    onPressed: mouse => {
                                        let mapped = mapToItem(parent, mouse.x, mouse.y);
                                        vExtRip.trigger(mapped.x, mapped.y);
                                        vExtItem.vDidLongPress = false;
                                        if (mouse.button === Qt.LeftButton) {
                                            vLongPressTimer.restart();
                                        }
                                    }
                                    onReleased: mouse => {
                                        if (mouse.button === Qt.LeftButton) {
                                            if (vLongPressTimer.running) {
                                                vLongPressTimer.stop();
                                                if (!vExtItem.vDidLongPress) {
                                                    liveRoot.rootPlugin.extendCaffeine(liveRoot.quickExtendMinutes * 60);
                                                }
                                            }
                                        }
                                    }
                                    onCanceled: {
                                        vLongPressTimer.stop();
                                        vExtItem.vDidLongPress = false;
                                    }
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton) {
                                            liveRoot.rootPlugin.customInputExpanded = !liveRoot.rootPlugin.customInputExpanded;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

            Item {
                id: vCustomInputSection
                width: parent.width
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                implicitHeight: height
                clip: true
                height: liveRoot.rootPlugin.customInputExpanded ? vCustomInputCard.implicitHeight : 0
                opacity: liveRoot.rootPlugin.customInputExpanded ? 1.0 : 0.0
                visible: liveRoot.isBarVertical && (height > 0 || liveRoot.rootPlugin.customInputExpanded)

                Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

                StyledRect {
                    id: vCustomInputCard
                    width: parent.width
                    implicitHeight: vCustomInputCol.implicitHeight + Theme.spacingM * 2
                    readonly property real cardOuterRadius: Theme.cornerRadius + 4
                    readonly property real cardInnerRadius: Theme.cornerRadius / 2
                    topLeftRadius: cardInnerRadius
                    topRightRadius: cardInnerRadius
                    bottomLeftRadius: cardOuterRadius
                    bottomRightRadius: cardOuterRadius
                    Behavior on topLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                    Behavior on topRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    border.width: 1
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)

                    ColumnLayout {
                        id: vCustomInputCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        // Header row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "more_time"
                                size: 16
                                color: Theme.primary
                            }

                            StyledText {
                                text: I18n.tr("Add Custom Time")
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.DemiBold
                                color: Theme.surfaceText
                                Layout.fillWidth: true
                            }
                        }

                        // Segmented First, Mid, Last Input Capsule
                        Item {
                            id: vSegmentedRowItem
                            Layout.fillWidth: true
                            height: 44

                            readonly property real outerRadius: Theme.cornerRadius
                            readonly property real innerRadius: Theme.cornerRadius / 2
                            readonly property real pillRadius: 19

                            function submitMinutes() {
                                var mins = parseInt(vCustomTextInput.text.trim());
                                if (!isNaN(mins) && mins > 0) {
                                    liveRoot.rootPlugin.extendCaffeine(mins * 60);
                                    vCustomTextInput.text = "";
                                    liveRoot.rootPlugin.customInputExpanded = false;
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                spacing: 2

                                // 1. First Segment: Icon Prefix Badge
                                Rectangle {
                                    Layout.preferredWidth: 44
                                    Layout.fillHeight: true
                                    topLeftRadius: parent.parent.outerRadius
                                    bottomLeftRadius: parent.parent.outerRadius
                                    topRightRadius: parent.parent.innerRadius
                                    bottomRightRadius: parent.parent.innerRadius
                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                                    border.width: 1
                                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)

                                    DankIcon {
                                        name: "timer"
                                        size: 18
                                        color: Theme.primary
                                        anchors.centerIn: parent
                                    }
                                }

                                // 2. Middle Segment: Text Field
                                Rectangle {
                                    id: vFieldSegment
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    topLeftRadius: parent.parent.innerRadius
                                    bottomLeftRadius: parent.parent.innerRadius
                                    topRightRadius: parent.parent.innerRadius
                                    bottomRightRadius: parent.parent.innerRadius
                                    color: Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.04)
                                    border.width: 1
                                    border.color: vCustomTextInput.activeFocus
                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.6)
                                        : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    TextInput {
                                        id: vCustomTextInput
                                        anchors.fill: parent
                                        Connections {
                                            target: liveRoot.rootPlugin
                                            function onCustomInputExpandedChanged() {
                                                if (liveRoot.rootPlugin.customInputExpanded && liveRoot.isBarVertical) {
                                                    vCustomTextInput.forceActiveFocus();
                                                }
                                            }
                                        }
                                        anchors.leftMargin: Theme.spacingM
                                        anchors.rightMargin: Theme.spacingM
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.family: Theme.fontFamily
                                        color: Theme.surfaceText
                                        selectByMouse: true
                                        inputMethodHints: Qt.ImhDigitsOnly
                                        validator: IntValidator { bottom: 1; top: 1440 }

                                        Text {
                                            anchors.fill: parent
                                            verticalAlignment: Text.AlignVCenter
                                            text: I18n.tr("Minutes (e.g. 45)")
                                            color: Theme.surfaceVariantText
                                            font: vCustomTextInput.font
                                            visible: !vCustomTextInput.text && !vCustomTextInput.activeFocus
                                        }

                                        Keys.onReturnPressed: event => {
                                            vSegmentedRowItem.submitMinutes();
                                            event.accepted = true;
                                        }
                                        Keys.onEnterPressed: event => {
                                            vSegmentedRowItem.submitMinutes();
                                            event.accepted = true;
                                        }
                                        onAccepted: vSegmentedRowItem.submitMinutes()
                                    }
                                }

                                // 3. Last Segment: Custom Action Button with Tickmark
                                Item {
                                    id: vTickBtnItem
                                    Layout.preferredWidth: 48
                                    Layout.fillHeight: true

                                    readonly property bool hasValidInput: {
                                        var v = parseInt(vCustomTextInput.text.trim());
                                        return !isNaN(v) && v > 0;
                                    }
                                    readonly property bool hovered: vTickMa.containsMouse

                                    Rectangle {
                                        id: vTickBg
                                        anchors.fill: parent
                                        topLeftRadius: (vTickMa.pressed || (vTickBtnItem.hasValidInput && vTickBtnItem.hovered)) ? parent.parent.parent.pillRadius : parent.parent.parent.innerRadius
                                        bottomLeftRadius: (vTickMa.pressed || (vTickBtnItem.hasValidInput && vTickBtnItem.hovered)) ? parent.parent.parent.pillRadius : parent.parent.parent.innerRadius
                                        topRightRadius: (vTickMa.pressed || (vTickBtnItem.hasValidInput && vTickBtnItem.hovered)) ? parent.parent.parent.pillRadius : parent.parent.parent.outerRadius
                                        bottomRightRadius: (vTickMa.pressed || (vTickBtnItem.hasValidInput && vTickBtnItem.hovered)) ? parent.parent.parent.pillRadius : parent.parent.parent.outerRadius

                                        Behavior on topLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                        Behavior on bottomLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                        Behavior on topRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                        Behavior on bottomRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                                        color: vTickBtnItem.hasValidInput
                                            ? (vTickMa.pressed
                                                ? Theme.primaryPressed
                                                : (vTickBtnItem.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)))
                                            : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.04)

                                        border.width: 1
                                        border.color: vTickBtnItem.hasValidInput
                                            ? ((vTickMa.pressed || vTickBtnItem.hovered) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.8) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.45))
                                            : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Behavior on border.color { ColorAnimation { duration: 150 } }

                                        opacity: vTickBtnItem.hasValidInput ? 1.0 : 0.4
                                        Behavior on opacity { NumberAnimation { duration: 150 } }

                                        DankRipple {
                                            id: vTickRip
                                            anchors.fill: parent
                                            cornerRadius: vTickBg.topRightRadius
                                            rippleColor: Theme.primary
                                        }

                                        DankIcon {
                                            name: "check"
                                            size: 18
                                            color: vTickBtnItem.hasValidInput ? Theme.primary : Theme.surfaceVariantText
                                            anchors.centerIn: parent
                                        }
                                    }

                                    MouseArea {
                                        id: vTickMa
                                        anchors.fill: parent
                                        cursorShape: vTickBtnItem.hasValidInput ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        hoverEnabled: true
                                        onPressed: mouse => {
                                            if (vTickBtnItem.hasValidInput) {
                                                let mapped = mapToItem(parent, mouse.x, mouse.y);
                                                vTickRip.trigger(mapped.x, mapped.y);
                                            }
                                        }
                                        onClicked: {
                                            vSegmentedRowItem.submitMinutes();
                                        }
                                    }
                                }
                            }
                        }
                }
            }

            }
        }

        }
        // =========================================================================
        // C. CONTAINER 3: SEPARATE CONTAINER FOR CUSTOM MINUTES (Expandable for Horizontal)
        // =========================================================================
        Item {
            id: customInputSection
            width: parent.width
            implicitHeight: height
            clip: true
            height: liveRoot.rootPlugin.customInputExpanded ? customInputCard.height : 0
            opacity: liveRoot.rootPlugin.customInputExpanded ? 1.0 : 0.0
            visible: (!liveRoot.isBarVertical) && (height > 0 || liveRoot.rootPlugin.customInputExpanded)

            Behavior on height { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }

            StyledRect {
                id: customInputCard
                width: parent.width
                height: customInputCol.implicitHeight + Theme.spacingM * 2
                implicitHeight: height
                readonly property real cardOuterRadius: Theme.cornerRadius + 4
                readonly property real cardInnerRadius: Theme.cornerRadius / 2
                topLeftRadius: cardInnerRadius
                topRightRadius: cardInnerRadius
                bottomLeftRadius: cardOuterRadius
                bottomRightRadius: cardOuterRadius
                Behavior on topLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                Behavior on topRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.width: 1
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)

                ColumnLayout {
                    id: customInputCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingS

                    // Header row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "more_time"
                            size: 16
                            color: Theme.primary
                        }

                        StyledText {
                            text: I18n.tr("Add Custom Time")
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.DemiBold
                            color: Theme.surfaceText
                            Layout.fillWidth: true
                        }
                    }

                                        // Segmented First, Mid, Last Input Capsule
                    Item {
                        id: hSegmentedRowItem
                        Layout.fillWidth: true
                        height: 44

                        readonly property real outerRadius: Theme.cornerRadius
                        readonly property real innerRadius: Theme.cornerRadius / 2
                        readonly property real pillRadius: 19

                        function submitMinutes() {
                            var mins = parseInt(customTextInput.text.trim());
                            if (!isNaN(mins) && mins > 0) {
                                liveRoot.rootPlugin.extendCaffeine(mins * 60);
                                customTextInput.text = "";
                                liveRoot.rootPlugin.customInputExpanded = false;
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            spacing: 2

                            // 1. First Segment: Icon Prefix Badge
                            Rectangle {
                                Layout.preferredWidth: 44
                                Layout.fillHeight: true
                                topLeftRadius: parent.parent.outerRadius
                                bottomLeftRadius: parent.parent.outerRadius
                                topRightRadius: parent.parent.innerRadius
                                bottomRightRadius: parent.parent.innerRadius
                                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                                border.width: 1
                                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)

                                DankIcon {
                                    name: "timer"
                                    size: 18
                                    color: Theme.primary
                                    anchors.centerIn: parent
                                }
                            }

                            // 2. Middle Segment: Text Field
                            Rectangle {
                                id: fieldSegment
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                topLeftRadius: parent.parent.innerRadius
                                bottomLeftRadius: parent.parent.innerRadius
                                topRightRadius: parent.parent.innerRadius
                                bottomRightRadius: parent.parent.innerRadius
                                color: Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.04)
                                border.width: 1
                                border.color: customTextInput.activeFocus
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.6)
                                    : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                TextInput {
                                    id: customTextInput
                                    anchors.fill: parent
                                    Connections {
                                        target: liveRoot.rootPlugin
                                        function onCustomInputExpandedChanged() {
                                            if (liveRoot.rootPlugin.customInputExpanded && !liveRoot.isBarVertical) {
                                                customTextInput.forceActiveFocus();
                                            }
                                        }
                                    }
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.rightMargin: Theme.spacingM
                                    verticalAlignment: TextInput.AlignVCenter
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.family: Theme.fontFamily
                                    color: Theme.surfaceText
                                    selectByMouse: true
                                    inputMethodHints: Qt.ImhDigitsOnly
                                    validator: IntValidator { bottom: 1; top: 1440 }

                                    Text {
                                        anchors.fill: parent
                                        verticalAlignment: Text.AlignVCenter
                                        text: I18n.tr("Minutes (e.g. 45)")
                                        color: Theme.surfaceVariantText
                                        font: customTextInput.font
                                        visible: !customTextInput.text && !customTextInput.activeFocus
                                    }

                                    Keys.onReturnPressed: event => {
                                        hSegmentedRowItem.submitMinutes();
                                        event.accepted = true;
                                    }
                                    Keys.onEnterPressed: event => {
                                        hSegmentedRowItem.submitMinutes();
                                        event.accepted = true;
                                    }
                                    onAccepted: hSegmentedRowItem.submitMinutes()
                                }
                            }

                            // 3. Last Segment: Custom Action Button with Tickmark
                            Item {
                                id: tickBtnItem
                                Layout.preferredWidth: 48
                                Layout.fillHeight: true

                                readonly property bool hasValidInput: {
                                    var v = parseInt(customTextInput.text.trim());
                                    return !isNaN(v) && v > 0;
                                }
                                readonly property bool hovered: tickMa.containsMouse

                                Rectangle {
                                    id: tickBg
                                    anchors.fill: parent
                                    topLeftRadius: (tickMa.pressed || (tickBtnItem.hasValidInput && tickBtnItem.hovered)) ? parent.parent.parent.pillRadius : parent.parent.parent.innerRadius
                                    bottomLeftRadius: (tickMa.pressed || (tickBtnItem.hasValidInput && tickBtnItem.hovered)) ? parent.parent.parent.pillRadius : parent.parent.parent.innerRadius
                                    topRightRadius: (tickMa.pressed || (tickBtnItem.hasValidInput && tickBtnItem.hovered)) ? parent.parent.parent.pillRadius : parent.parent.parent.outerRadius
                                    bottomRightRadius: (tickMa.pressed || (tickBtnItem.hasValidInput && tickBtnItem.hovered)) ? parent.parent.parent.pillRadius : parent.parent.parent.outerRadius

                                    Behavior on topLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                    Behavior on bottomLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                    Behavior on topRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                    Behavior on bottomRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                                    color: tickBtnItem.hasValidInput
                                        ? (tickMa.pressed
                                            ? Theme.primaryPressed
                                            : (tickBtnItem.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)))
                                        : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.04)

                                    border.width: 1
                                    border.color: tickBtnItem.hasValidInput
                                        ? ((tickMa.pressed || tickBtnItem.hovered) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.8) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.45))
                                        : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    opacity: tickBtnItem.hasValidInput ? 1.0 : 0.4
                                    Behavior on opacity { NumberAnimation { duration: 150 } }

                                    DankRipple {
                                        id: tickRip
                                        anchors.fill: parent
                                        cornerRadius: tickBg.topRightRadius
                                        rippleColor: Theme.primary
                                    }

                                    DankIcon {
                                        name: "check"
                                        size: 18
                                        color: tickBtnItem.hasValidInput ? Theme.primary : Theme.surfaceVariantText
                                        anchors.centerIn: parent
                                    }
                                }

                                MouseArea {
                                    id: tickMa
                                    anchors.fill: parent
                                    cursorShape: tickBtnItem.hasValidInput ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    hoverEnabled: true
                                    onPressed: mouse => {
                                        if (tickBtnItem.hasValidInput) {
                                            let mapped = mapToItem(parent, mouse.x, mouse.y);
                                            tickRip.trigger(mapped.x, mapped.y);
                                        }
                                    }
                                    onClicked: {
                                        hSegmentedRowItem.submitMinutes();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

}
}
