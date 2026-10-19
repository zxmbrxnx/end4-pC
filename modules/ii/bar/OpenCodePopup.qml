import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    signal performed()

    function projectName(directory) {
        if (!directory) return "";
        const parts = String(directory).split("/").filter(part => part.length > 0);
        return parts.length > 0 ? parts[parts.length - 1] : String(directory);
    }

    function formatTime(stamp) {
        if (!stamp) return "";
        const seconds = Math.max(0, Math.floor((Date.now() - stamp) / 1000));
        if (seconds < 60) return "now";
        const minutes = Math.floor(seconds / 60);
        if (minutes < 60) return `${minutes}m`;
        const hours = Math.floor(minutes / 60);
        if (hours < 24) return `${hours}h`;
        return `${Math.floor(hours / 24)}d`;
    }

    component SmallAction: RippleButton {
        id: action
        property string label
        property color bg
        property color fg

        implicitHeight: 26
        implicitWidth: labelText.implicitWidth + 18
        buttonRadius: 13
        colBackground: action.bg
        colBackgroundHover: Qt.lighter(action.bg, 1.08)
        colRipple: Qt.darker(action.bg, 1.08)
        enabled: !OpenCode.actionBusy
        opacity: OpenCode.actionBusy ? 0.5 : 1
        onClicked: action.activated()

        signal activated()

        contentItem: StyledText {
            id: labelText
            text: action.label
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.Medium
            color: action.fg
        }
    }

    ColumnLayout {
        implicitWidth: 320
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialShapeWrappedMaterialSymbol {
                wrappedShape: MaterialShape.Shape.Cookie12Sided
                text: OpenCode.connected ? "smart_toy" : "terminal"
                iconSize: 18
                fill: 1
                padding: 8
                color: OpenCode.connected ? Appearance.colors.colPrimary : Appearance.colors.colTertiaryContainer
                colSymbol: OpenCode.connected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnTertiaryContainer
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -2

                StyledText {
                    text: "OpenCode"
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnSurfaceVariant
                }

                StyledText {
                    Layout.fillWidth: true
                    text: OpenCode.statusText
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }

            SmallAction {
                label: "Open"
                bg: Appearance.colors.colPrimary
                fg: Appearance.colors.colOnPrimary
                onActivated: {
                    OpenCode.openOpenCode();
                    root.performed();
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Appearance.colors.colOutlineVariant
            opacity: 0.5
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: OpenCode.connected
                    ? OpenCode.sortedSessions.slice(0, Config.options.bar.opencode.popupSessionLimit)
                    : []

                delegate: Rectangle {
                    id: sessionRow
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: Appearance.rounding.normal
                    color: sessionArea.containsMouse ? Appearance.colors.colLayer2Hover : "transparent"

                    readonly property color statusColor: modelData.status === "waiting"
                        ? Appearance.colors.colTertiary
                        : modelData.status === "working"
                            ? Appearance.colors.colPrimary
                            : modelData.status === "error"
                                ? Appearance.colors.colError
                                : Appearance.colors.colOutline

                    MouseArea {
                        id: sessionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            OpenCode.openSession(sessionRow.modelData.id, sessionRow.modelData.directory);
                            root.performed();
                        }
                    }

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 8
                            rightMargin: 8
                        }
                        spacing: 8

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 8
                            implicitHeight: 8
                            radius: 4
                            color: sessionRow.statusColor
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: sessionRow.modelData.title || "Untitled session"
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnSurfaceVariant
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: {
                                    const parts = [];
                                    if (root.projectName(sessionRow.modelData.directory)) parts.push(root.projectName(sessionRow.modelData.directory));
                                    if (sessionRow.modelData.agent) parts.push(sessionRow.modelData.agent);
                                    if (sessionRow.modelData.subagentCount > 0) parts.push(`+${sessionRow.modelData.subagentCount}`);
                                    return parts.join(" · ");
                                }
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                            }
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignVCenter
                            text: root.formatTime(sessionRow.modelData.updated)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: OpenCode.connected && OpenCode.sortedSessions.length === 0
                text: "No sessions yet"
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: OpenCode.permissions.length > 0

            StyledText {
                text: `${OpenCode.permissions.length} pending approval${OpenCode.permissions.length === 1 ? "" : "s"}`
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Medium
                color: Appearance.colors.colTertiary
            }

            Repeater {
                model: OpenCode.permissions.slice(0, 2)

                delegate: Rectangle {
                    id: permissionRow
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 54
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colTertiaryContainer

                    ColumnLayout {
                        anchors {
                            fill: parent
                            margins: 8
                        }
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            text: `${permissionRow.modelData.action || "Permission"} · ${permissionRow.modelData.sessionTitle || ""}`
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnTertiaryContainer
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            StyledText {
                                Layout.fillWidth: true
                                text: (permissionRow.modelData.resources || []).join(" ")
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                textFormat: Text.PlainText
                                font.family: Appearance.font.family.monospace
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnTertiaryContainer
                                opacity: 0.75
                            }

                            SmallAction {
                                label: "Once"
                                bg: Appearance.colors.colPrimary
                                fg: Appearance.colors.colOnPrimary
                                onActivated: {
                                    OpenCode.replyPermission(
                                        permissionRow.modelData.sessionID,
                                        permissionRow.modelData.id,
                                        "once"
                                    );
                                    root.performed();
                                }
                            }

                            SmallAction {
                                label: "Reject"
                                bg: Appearance.colors.colErrorContainer
                                fg: Appearance.colors.colOnErrorContainer
                                onActivated: {
                                    OpenCode.replyPermission(
                                        permissionRow.modelData.sessionID,
                                        permissionRow.modelData.id,
                                        "reject"
                                    );
                                    root.performed();
                                }
                            }
                        }
                    }
                }
            }

            StyledText {
                visible: OpenCode.permissions.length > 2
                text: `+${OpenCode.permissions.length - 2} more in the Agent Hub`
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: !OpenCode.connected
            spacing: 6

            SmallAction {
                label: "Open"
                bg: Appearance.colors.colPrimary
                fg: Appearance.colors.colOnPrimary
                onActivated: {
                    OpenCode.openOpenCode();
                    root.performed();
                }
            }

            SmallAction {
                label: "Retry"
                bg: Appearance.colors.colSecondaryContainer
                fg: Appearance.colors.colOnSecondaryContainer
                onActivated: {
                    OpenCode.retryNow();
                    root.performed();
                }
            }
        }
    }
}
