import QtQuick
import qs.Common

Item {
    id: root

    property real value: 0
    property real actualValue: value
    property bool showActualPlaybackState: false
    property real lineWidth: 3.0
    property real wavelength: 26
    property real amp: 2.2
    property real phase: 0.0
    property bool isPlaying: false
    property real currentAmp: 2.2
    property color trackColor: Theme.withAlpha(Theme.surfaceContainerHighest, 0.50)
    property color fillColor: Theme.primary
    property color playheadColor: Theme.primary
    property color actualProgressColor: Theme.withAlpha(Theme.primary, 0.40)

    Behavior on currentAmp {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
        }
    }
    onIsPlayingChanged: currentAmp = isPlaying ? amp : 0
    Component.onCompleted: currentAmp = isPlaying ? amp : 0

    ShaderEffect {
        anchors.fill: parent
        blending: true

        readonly property real widthPx: width
        readonly property real heightPx: height
        readonly property real value: root.value
        readonly property real actualValue: root.actualValue
        readonly property real phase: root.phase
        readonly property real ampPx: root.currentAmp
        readonly property real wavelengthPx: root.wavelength
        readonly property real lineWidthPx: root.lineWidth
        readonly property real showActual: root.showActualPlaybackState ? 1.0 : 0.0
        readonly property color fillColor: root.fillColor
        readonly property color trackColor: root.trackColor
        readonly property color playheadColor: root.playheadColor
        readonly property color actualColor: root.actualProgressColor

        fragmentShader: Qt.resolvedUrl("shaders/wave_progress.frag.qsb")
    }

    signal frameTicked

    FrameAnimation {
        running: root.visible && (root.isPlaying || root.currentAmp > 0) && (root.Window.window?.visible ?? false)
        onTriggered: {
            if (!root.isPlaying)
                return;
            root.phase = (root.phase + 0.03 * frameTime * 60) % 6.28318530718;
            root.frameTicked();
        }
    }
}
