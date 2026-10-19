import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Rectangle {
    id: root

    required property var session
    property bool privacyMode: false
    property bool showCost: true
    property bool showProject: true
    property double now: Date.now()

    signal openRequested()
    signal interruptRequested()
    signal deleteRequested()

    property bool confirmDelete: false

    Timer {
        id: confirmDeleteTimer
        interval: 3000
        repeat: false
        onTriggered: root.confirmDelete = false
    }

    readonly property bool waiting: session.status === "waiting"
    readonly property bool working: session.status === "working"
    readonly property bool failed: session.status === "error"
    readonly property color statusColor: {
        if (root.waiting) return Appearance.colors.colTertiary;
        if (root.working) return Appearance.colors.colPrimary;
        if (root.failed) return Appearance.colors.colError;
        return Appearance.colors.colOutline;
    }
    readonly property color foreground: root.waiting ? Appearance.colors.colOnTertiaryContainer : Appearance.colors.colOnLayer2
    readonly property color secondary: root.waiting
        ? ColorUtils.transparentize(Appearance.colors.colOnTertiaryContainer, 0.3)
        : Appearance.colors.colSubtext

    implicitHeight: 62
    radius: Appearance.rounding.normal
    color: root.waiting
        ? Appearance.colors.colTertiaryContainer
        : (rowArea.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2)

    function projectName() {
        if (!root.session.directory) return "";
        const parts = String(root.session.directory).split("/").filter(part => part.length > 0);
        return parts.length > 0 ? parts[parts.length - 1] : String(root.session.directory);
    }

    function metaText() {
        const bits = [];
        if (root.session.agent) bits.push(root.session.agent);
        if (root.session.model && root.session.model.id) bits.push(root.session.model.id);
        if (root.session.subagentCount > 0) bits.push(`+${root.session.subagentCount}`);
        return bits.join(" · ");
    }

    function elapsedText() {
        const stamp = root.session.updated || root.session.created || 0;
        if (!stamp) return "";
        const seconds = Math.max(0, Math.floor((root.now - stamp) / 1000));
        if (seconds < 60) return "now";
        const minutes = Math.floor(seconds / 60);
        if (minutes < 60) return `${minutes}m`;
        const hours = Math.floor(minutes / 60);
        if (hours < 24) return `${hours}h`;
        return `${Math.floor(hours / 24)}d`;
    }

    function costText() {
        if (!root.showCost) return "";
        const cost = Number(root.session.cost || 0);
        if (cost <= 0) return "";
        return cost >= 0.01 ? `$${cost.toFixed(2)}` : "<$0.01";
    }

    component RowAction: RippleButton {
        id: action
        property string iconName
        property color fgColor
        signal activated()

        implicitWidth: 26
        implicitHeight: 26
        buttonRadius: 13
        colBackground: "transparent"
        colBackgroundHover: ColorUtils.transparentize(action.fgColor, 0.85)
        colRipple: ColorUtils.transparentize(action.fgColor, 0.7)
        onClicked: action.activated()

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            text: action.iconName
            iconSize: 17
            color: action.hovered ? Appearance.colors.colPrimary : action.fgColor
        }
    }

    MouseArea {
        id: rowArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openRequested()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 9
        anchors.rightMargin: 8
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        spacing: 8

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 3
            Layout.preferredHeight: 36
            radius: 2
            color: root.statusColor
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 8
                    implicitHeight: 8
                    radius: 4
                    color: root.statusColor
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.privacyMode ? "Session" : (root.session.title || "Untitled session")
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: root.foreground
                }

                Rectangle {
                    visible: root.session.subagentCount > 0 && !root.privacyMode
                    implicitWidth: subagentLabel.implicitWidth + 10
                    implicitHeight: 15
                    radius: 7
                    color: ColorUtils.transparentize(root.foreground, 0.85)

                    StyledText {
                        id: subagentLabel
                        anchors.centerIn: parent
                        text: `+${root.session.subagentCount}`
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: root.foreground
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: {
                    const project = root.privacyMode || !root.showProject ? "" : root.projectName();
                    const meta = root.privacyMode ? "" : root.metaText();
                    return [project, meta].filter(part => part.length > 0).join(" · ");
                }
                elide: Text.ElideRight
                maximumLineCount: 1
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.secondary
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            StyledText {
                Layout.alignment: Qt.AlignRight
                text: root.elapsedText()
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.secondary
            }

            StyledText {
                Layout.alignment: Qt.AlignRight
                text: root.costText()
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.secondary
            }
        }
    }

    Item {
        id: actionsOverlay
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
            rightMargin: 6
        }
        width: actionsRow.implicitWidth + 8
        height: 30
        z: 2
        opacity: rowArea.containsMouse || root.confirmDelete ? 1 : 0
        visible: opacity > 0
        enabled: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Rectangle {
            anchors.fill: parent
            radius: 15
            color: root.color
            opacity: 0.97
        }

        RowLayout {
            id: actionsRow
            anchors.centerIn: parent
            spacing: 1

            RowAction {
                iconName: "terminal"
                fgColor: root.foreground
                onActivated: root.openRequested()
            }

            RowAction {
                iconName: "stop_circle"
                fgColor: Appearance.colors.colError
                visible: root.working
                onActivated: root.interruptRequested()
            }

            RowAction {
                iconName: root.confirmDelete ? "delete_forever" : "delete"
                fgColor: Appearance.colors.colError
                onActivated: {
                    if (root.confirmDelete) {
                        root.confirmDelete = false;
                        confirmDeleteTimer.stop();
                        root.deleteRequested();
                    } else {
                        root.confirmDelete = true;
                        confirmDeleteTimer.restart();
                    }
                }

                StyledToolTip {
                    text: root.confirmDelete ? "Click again to delete" : "Delete session"
                }
            }
        }
    }
}
