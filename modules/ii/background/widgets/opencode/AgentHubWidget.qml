import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "opencodeHub"
    hoverEnabled: true
    visibleWhenLocked: false

    readonly property int maxSessions: Math.max(1, Number(root.configEntry.maxSessions ?? 6))
    readonly property bool privacyMode: root.configEntry.privacyMode ?? false
    readonly property bool showCost: root.configEntry.showCost ?? true
    readonly property bool showProject: root.configEntry.showProject ?? true

    property int pageIndex: 0

    implicitWidth: 360
    implicitHeight: 340

    Component.onCompleted: {
        root.pageIndex = root.configEntry.defaultPage === "attention" ? 1 : 0;
    }

    function statusSummary() {
        if (OpenCode.waitingCount > 0) return `${OpenCode.waitingCount} waiting`;
        if (OpenCode.workingCount > 0) return `${OpenCode.workingCount} working`;
        if (OpenCode.effectiveState === "connected") return "Idle";
        return OpenCode.statusText;
    }

    function statusColor() {
        if (OpenCode.waitingCount > 0) return Appearance.colors.colTertiary;
        if (OpenCode.workingCount > 0) return Appearance.colors.colPrimary;
        if (OpenCode.effectiveState === "error"
            || OpenCode.effectiveState === "incompatible"
            || OpenCode.effectiveState === "not_installed") return Appearance.colors.colError;
        return Appearance.colors.colSubtext;
    }

    function footerText() {
        if (OpenCode.lastActionError.length > 0) return OpenCode.lastActionError;
        if (!OpenCode.connected && OpenCode.lastBridgeError.length > 0) return OpenCode.lastBridgeError;
        if (!OpenCode.connected) return OpenCode.statusText;
        return `${OpenCode.rootSessions.length} sessions · ${OpenCode.pendingCount} pending`;
    }

    function emptyIcon() {
        if (!OpenCode.connected) {
            if (OpenCode.effectiveState === "not_installed") return "block";
            if (OpenCode.effectiveState === "starting"
                || OpenCode.effectiveState === "reconnecting") return "progress_activity";
            if (OpenCode.effectiveState === "incompatible") return "warning";
            return "terminal";
        }
        return "forum";
    }

    function emptyTitle() {
        if (!OpenCode.connected) {
            if (OpenCode.effectiveState === "not_installed") return "OpenCode is not installed";
            if (OpenCode.effectiveState === "starting") return "Connecting to OpenCode";
            if (OpenCode.effectiveState === "reconnecting") return "Reconnecting to OpenCode";
            if (OpenCode.effectiveState === "incompatible") return "OpenCode version not supported";
            return "OpenCode is not open";
        }
        return "No sessions";
    }

    function emptyBody() {
        if (!OpenCode.connected) {
            if (OpenCode.effectiveState === "not_running") return "Open it to see your agent sessions.";
            if (OpenCode.effectiveState === "starting"
                || OpenCode.effectiveState === "reconnecting") return "The widget will reconnect automatically.";
            return OpenCode.lastBridgeError || "";
        }
        return "Start a session in the terminal and it will appear here.";
    }

    function emptyActionText() {
        if (!OpenCode.connected && OpenCode.effectiveState === "not_running") return "Open OpenCode";
        if (OpenCode.connected) return "New session";
        return "";
    }

    component HeaderAction: RippleButton {
        id: action
        property string iconName
        property color fgColor
        signal activated()

        implicitWidth: 28
        implicitHeight: 28
        buttonRadius: 14
        colBackground: "transparent"
        colBackgroundHover: ColorUtils.transparentize(action.fgColor, 0.85)
        colRipple: ColorUtils.transparentize(action.fgColor, 0.7)
        onClicked: action.activated()

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            text: action.iconName
            iconSize: 18
            color: action.hovered ? Appearance.colors.colPrimary : action.fgColor
        }
    }

    component HubTab: RippleButton {
        id: tab
        property string label
        property string iconName
        property int count
        property bool selected
        property bool urgent
        signal activated()

        implicitHeight: 30
        implicitWidth: tabContent.implicitWidth + 18
        buttonRadius: 15
        colBackground: tab.selected ? Appearance.colors.colPrimaryContainer : "transparent"
        colBackgroundHover: tab.selected
            ? Appearance.colors.colPrimaryContainerHover
            : Appearance.colors.colLayer2Hover
        colRipple: tab.selected
            ? Appearance.colors.colPrimaryContainerActive
            : Appearance.colors.colLayer2Active
        onClicked: tab.activated()

        contentItem: RowLayout {
            id: tabContent
            spacing: 5

            MaterialSymbol {
                text: tab.iconName
                iconSize: 17
                color: tab.selected
                    ? Appearance.colors.colOnPrimaryContainer
                    : Appearance.colors.colOnLayer2
            }

            StyledText {
                text: tab.label
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: tab.selected ? Font.Medium : Font.Normal
                color: tab.selected
                    ? Appearance.colors.colOnPrimaryContainer
                    : Appearance.colors.colOnLayer2
            }

            Rectangle {
                visible: tab.count > 0
                implicitWidth: countLabel.implicitWidth + 10
                implicitHeight: 16
                radius: 8
                color: tab.urgent
                    ? Appearance.colors.colError
                    : Appearance.colors.colSecondaryContainer

                StyledText {
                    id: countLabel
                    anchors.centerIn: parent
                    text: tab.count
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: tab.urgent
                        ? Appearance.colors.colOnError
                        : Appearance.colors.colOnSecondaryContainer
                }
            }
        }
    }

    WidgetCard {
        anchors.fill: parent
        widget: root
        color: Appearance.colors.colLayer1
        tint: Appearance.colors.colLayer1
        tintOpacity: 0.9

        ColumnLayout {
            anchors {
                fill: parent
                margins: 12
            }
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialShapeWrappedMaterialSymbol {
                    wrappedShape: MaterialShape.Shape.Cookie12Sided
                    text: "smart_toy"
                    iconSize: 20
                    fill: 1
                    padding: 9
                    color: Appearance.colors.colPrimary
                    colSymbol: Appearance.colors.colOnPrimary
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: -2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        StyledText {
                            text: "OpenCode"
                            font.pixelSize: Appearance.font.pixelSize.larger
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer1
                        }

                        Rectangle {
                            visible: OpenCode.connected
                            implicitWidth: 6
                            implicitHeight: 6
                            radius: 3
                            color: root.statusColor()
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.statusSummary()
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: root.statusColor()
                    }
                }

                HeaderAction {
                    visible: !OpenCode.connected
                    iconName: "refresh"
                    fgColor: Appearance.colors.colOnLayer1
                    onActivated: OpenCode.retryNow()
                }

                HeaderAction {
                    iconName: root.privacyMode ? "visibility_off" : "visibility"
                    fgColor: Appearance.colors.colOnLayer1
                    onActivated: root.configEntry.privacyMode = !root.privacyMode
                }

                HeaderAction {
                    iconName: "terminal"
                    fgColor: Appearance.colors.colOnLayer1
                    onActivated: OpenCode.openOpenCode()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                HubTab {
                    label: "Sessions"
                    iconName: "forum"
                    count: OpenCode.rootSessions.length
                    selected: root.pageIndex === 0
                    onActivated: root.pageIndex = 0
                }

                HubTab {
                    label: "Attention"
                    iconName: "notification_important"
                    count: OpenCode.pendingCount
                    urgent: OpenCode.pendingCount > 0
                    selected: root.pageIndex === 1
                    onActivated: root.pageIndex = 1
                }

                Item { Layout.fillWidth: true }

                StyledText {
                    visible: OpenCode.connected
                    text: OpenCode.snapshot.version || ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Item {
                    id: sessionsPage
                    anchors.fill: parent
                    visible: root.pageIndex === 0

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            visible: !OpenCode.connected && OpenCode.sessions.length > 0
                            implicitHeight: 26
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colTertiaryContainer

                            RowLayout {
                                anchors {
                                    fill: parent
                                    leftMargin: 8
                                    rightMargin: 8
                                }
                                spacing: 6

                                MaterialSymbol {
                                    text: "progress_activity"
                                    iconSize: 15
                                    color: Appearance.colors.colOnTertiaryContainer
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: OpenCode.effectiveState === "reconnecting"
                                        ? "Reconnecting to OpenCode…"
                                        : "OpenCode is not running"
                                    elide: Text.ElideRight
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnTertiaryContainer
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            StyledListView {
                                id: sessionsList
                                anchors.fill: parent
                                clip: true
                                spacing: 6
                                model: OpenCode.sortedSessions.slice(0, root.maxSessions)

                                delegate: SessionRow {
                                    required property var modelData

                                    width: sessionsList.width
                                    session: modelData
                                    privacyMode: root.privacyMode
                                    showCost: root.showCost
                                    showProject: root.showProject
                                    now: OpenCode.now
                                    opacity: OpenCode.connected ? 1 : 0.55

                                    onOpenRequested: OpenCode.openSession(modelData.id, modelData.directory)
                                    onInterruptRequested: OpenCode.interrupt(modelData.id)
                                    onDeleteRequested: OpenCode.deleteSession(modelData.id)
                                }
                            }

                            EmptyState {
                                anchors.fill: parent
                                visible: sessionsList.count === 0
                                icon: root.emptyIcon()
                                title: root.emptyTitle()
                                body: root.emptyBody()
                                actionText: root.emptyActionText()
                                actionIcon: "terminal"
                                busy: OpenCode.effectiveState === "starting"
                                    || OpenCode.effectiveState === "reconnecting"
                                onActionClicked: OpenCode.openOpenCode()
                            }
                        }

                        StyledText {
                            visible: OpenCode.sortedSessions.length > root.maxSessions
                            Layout.fillWidth: true
                            text: `+${OpenCode.sortedSessions.length - root.maxSessions} more sessions`
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }
                }

                Item {
                    id: attentionPage
                    anchors.fill: parent
                    visible: root.pageIndex === 1

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 6

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            StyledListView {
                                id: permissionList
                                anchors.fill: parent
                                clip: true
                                spacing: 6
                                model: OpenCode.permissions

                                delegate: PermissionCard {
                                    required property var modelData

                                    width: permissionList.width
                                    permission: modelData
                                    privacyMode: root.privacyMode
                                    busy: OpenCode.actionBusy
                                    now: OpenCode.now
                                    onReplyRequested: (permission, decision) => OpenCode.replyPermission(permission.sessionID, permission.id, decision)
                                }
                            }

                            EmptyState {
                                anchors.fill: parent
                                visible: permissionList.count === 0 && OpenCode.forms.length === 0
                                icon: "task_alt"
                                title: "No pending approvals"
                                body: OpenCode.connected
                                    ? "Permissions requested by an agent will appear here."
                                    : ""
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            visible: OpenCode.forms.length > 0
                            implicitHeight: formsRow.implicitHeight + 16
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colSecondaryContainer

                            RowLayout {
                                id: formsRow
                                anchors {
                                    fill: parent
                                    leftMargin: 8
                                    rightMargin: 8
                                }
                                spacing: 8

                                MaterialSymbol {
                                    text: "assignment"
                                    iconSize: 16
                                    color: Appearance.colors.colOnSecondaryContainer
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: `${OpenCode.forms.length} form(s) need input`
                                    elide: Text.ElideRight
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnSecondaryContainer
                                }

                                RippleButton {
                                    implicitHeight: 26
                                    implicitWidth: 54
                                    buttonRadius: Appearance.rounding.full
                                    colBackground: Appearance.colors.colSecondary
                                    colBackgroundHover: Appearance.colors.colSecondaryHover
                                    colRipple: Appearance.colors.colSecondaryActive
                                    onClicked: {
                                        const form = OpenCode.forms[0];
                                        if (form) OpenCode.openSession(form.sessionID, form.directory);
                                    }

                                    contentItem: StyledText {
                                        text: "Open"
                                        horizontalAlignment: Text.AlignHCenter
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        font.weight: Font.Medium
                                        color: Appearance.colors.colOnSecondary
                                    }
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                StyledText {
                    Layout.fillWidth: true
                    text: root.footerText()
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: OpenCode.lastActionError.length > 0
                        || (!OpenCode.connected && OpenCode.lastBridgeError.length > 0)
                        ? Appearance.colors.colError
                        : Appearance.colors.colSubtext
                }
            }
        }
    }
}
