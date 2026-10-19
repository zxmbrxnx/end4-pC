import qs.modules.common
import qs.modules.common.widgets
import qs.services as Services
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root

    property color contentColor: Appearance.colors.colOnLayer1
    property bool contentColorOverridden: false
    property bool vertical: Config.options.bar.vertical
    property bool popupOpen: false

    readonly property bool waiting: Services.OpenCode.pendingCount > 0
        && Config.options.bar.opencode.showWaiting
    readonly property bool working: Services.OpenCode.workingCount > 0
    readonly property bool active: Services.OpenCode.connected && (waiting || working)
    readonly property int count: waiting ? Services.OpenCode.pendingCount : (working ? Services.OpenCode.workingCount : 0)
    readonly property bool countVisible: Config.options.bar.opencode.showCount && count > 0
    readonly property string iconName: waiting ? "gpp_maybe" : (working ? "progress_activity" : (Services.OpenCode.connected ? "smart_toy" : "terminal"))
    readonly property color iconColor: {
        if (waiting) return root.contentColorOverridden ? root.contentColor : Appearance.colors.colTertiary;
        if (working) return root.contentColorOverridden ? root.contentColor : Appearance.colors.colPrimary;
        return root.contentColorOverridden ? root.contentColor : Appearance.colors.colSubtext;
    }

    implicitWidth: root.vertical
        ? Appearance.sizes.verticalBarWidth
        : content.implicitWidth + 14
    implicitHeight: root.vertical
        ? content.implicitHeight + 10
        : Appearance.sizes.barHeight
    hoverEnabled: !Config.options.bar.tooltips.clickToShow
    cursorShape: Qt.PointingHandCursor

    onClicked: root.popupOpen = !root.popupOpen

    GridLayout {
        id: content
        anchors.centerIn: parent
        columns: root.vertical ? 1 : (root.countVisible ? 2 : 1)
        columnSpacing: 5
        rowSpacing: 2

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            text: root.iconName
            iconSize: 16
            color: root.iconColor

            RotationAnimation on rotation {
                running: root.working
                from: 0
                to: 360
                duration: 1100
                loops: Animation.Infinite
                direction: RotationAnimation.Clockwise
                onRunningChanged: if (!running) rotation = 0
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            visible: root.countVisible
            text: root.count
            font.pixelSize: root.vertical
                ? Appearance.font.pixelSize.smaller
                : Appearance.font.pixelSize.small
            color: root.waiting
                ? (root.contentColorOverridden ? root.contentColor : Appearance.colors.colTertiary)
                : root.contentColor
        }
    }

    OpenCodePopup {
        hoverTarget: root
        hoverOpen: false
        pinned: root.popupOpen
        onPerformed: root.popupOpen = false
    }
}
