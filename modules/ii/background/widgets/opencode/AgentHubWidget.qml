import QtQuick
import QtQuick.Controls
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

    readonly property real defaultWidth: 520
    readonly property real defaultHeight: 500
    readonly property real minWidgetWidth: 320
    readonly property real minWidgetHeight: 280
    readonly property real maxWidgetWidth: Math.max(root.minWidgetWidth, Math.min(760, root.scaledScreenWidth - 24))
    readonly property real maxWidgetHeight: Math.max(root.minWidgetHeight, Math.min(820, root.scaledScreenHeight - 40))

    property real widgetWidth: root.clampSize(
        Number(root.configEntry.width ?? root.defaultWidth),
        root.minWidgetWidth,
        root.maxWidgetWidth
    )
    property real widgetHeight: root.clampSize(
        Number(root.configEntry.height ?? root.defaultHeight),
        root.minWidgetHeight,
        root.maxWidgetHeight
    )
    property real resizeStartHeight: -1

    readonly property bool privacyMode: root.configEntry.privacyMode ?? false
    readonly property bool showCost: root.configEntry.showCost ?? true
    readonly property bool showProject: root.configEntry.showProject ?? true

    property int pageIndex: 0
    property string askSessionID: ""
    property string askAgent: "build"
    property bool askAgentTouched: false
    readonly property var askSession: OpenCode.sessionById(root.askSessionID) || OpenCode.defaultSession

    onAskSessionIDChanged: {
        root.askAgentTouched = false;
        root.syncAskAgent();
    }
    onPageIndexChanged: {
        if (root.pageIndex !== 2)
            GlobalStates.desktopWidgetKeyboardFocus = false;
    }

    Connections {
        target: OpenCode
        function onSnapshotChanged() {
            if (!root.askAgentTouched && root.askSessionID.length === 0)
                root.syncAskAgent();
        }
    }

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    function clampSize(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, value));
    }

    function applyResize(dx, dy, startWidth) {
        if (root.resizeStartHeight < 0)
            root.resizeStartHeight = root.widgetHeight;
        root.widgetWidth = root.clampSize(startWidth + dx, root.minWidgetWidth, root.maxWidgetWidth);
        root.widgetHeight = root.clampSize(root.resizeStartHeight + dy, root.minWidgetHeight, root.maxWidgetHeight);
    }

    function commitSize() {
        root.configEntry.width = Math.round(root.widgetWidth);
        root.configEntry.height = Math.round(root.widgetHeight);
        root.resizeStartHeight = -1;
    }

    function syncAskAgent() {
        const session = OpenCode.sessionById(root.askSessionID) || OpenCode.defaultSession;
        if (!session) return;
        root.askAgent = session.agent === "plan" ? "plan" : "build";
    }

    function focusAskInput() {
        GlobalStates.desktopWidgetKeyboardFocus = true;
        Qt.callLater(() => askInput.forceActiveFocus());
    }

    function sendAskPrompt() {
        const target = root.askSession;
        if (!target) {
            OpenCode.lastActionError = "No OpenCode session available";
            return;
        }
        if (!OpenCode.connected) {
            OpenCode.lastActionError = OpenCode.statusText;
            return;
        }
        if (OpenCode.actionBusy) return;
        if (OpenCode.promptDefault(askInput.text, target.id, root.askAgent)) {
            askInput.text = "";
            root.pageIndex = 0;
        }
    }

    Component.onCompleted: {
        const defaultPage = root.configEntry.defaultPage;
        root.pageIndex = defaultPage === "attention" ? 1 : (defaultPage === "ask" ? 2 : 0);
        root.syncAskAgent();
        if (root.pageIndex === 2)
            GlobalStates.desktopWidgetKeyboardFocus = true;
    }

    Component.onDestruction: {
        if (root.pageIndex === 2)
            GlobalStates.desktopWidgetKeyboardFocus = false;
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

    readonly property int sessionCount: OpenCode.rootSessions.length

    readonly property string footerText: {
        if (OpenCode.lastActionError.length > 0) return OpenCode.lastActionError;
        if (!OpenCode.connected && OpenCode.lastBridgeError.length > 0) return OpenCode.lastBridgeError;
        if (!OpenCode.connected) return OpenCode.statusText;
        return `${root.sessionCount} sessions · ${OpenCode.pendingCount} pending`;
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
        id: card
        implicitWidth: root.widgetWidth
        implicitHeight: root.widgetHeight
        widget: root
        color: Appearance.colors.colLayer1
        tint: Appearance.colors.colLayer1
        tintOpacity: 0.9

        Behavior on implicitWidth {
            animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
        }
        Behavior on implicitHeight {
            animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
        }

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
                    count: root.sessionCount
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

                HubTab {
                    label: "Ask"
                    iconName: "edit_note"
                    selected: root.pageIndex === 2
                    onActivated: {
                        root.pageIndex = 2;
                        root.focusAskInput();
                    }
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
                                model: OpenCode.sortedSessions

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

                Item {
                    id: askPage
                    anchors.fill: parent
                    visible: root.pageIndex === 2

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 6

                        Flickable {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            contentWidth: chipRow.implicitWidth
                            contentHeight: chipRow.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            visible: OpenCode.sortedSessions.length > 0

                            RowLayout {
                                id: chipRow
                                spacing: 4

                                Repeater {
                                    model: OpenCode.sortedSessions.slice(0, 12)

                                    delegate: SessionChip {
                                        required property var modelData

                                        sessionData: modelData
                                        privacyMode: root.privacyMode
                                        selected: root.askSession && root.askSession.id === modelData.id
                                        onActivated: {
                                            root.askSessionID = modelData.id;
                                            root.askAgentTouched = false;
                                            root.syncAskAgent();
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 64
                            visible: OpenCode.sortedSessions.length > 0
                            radius: Appearance.rounding.normal
                            color: Appearance.colors.colSurfaceContainerLow

                            StyledTextArea {
                                id: askInput
                                anchors.fill: parent
                                anchors.margins: 8
                                background: null
                                placeholderText: "Ask this session…"
                                wrapMode: TextArea.Wrap
                                enabled: !OpenCode.actionBusy
                                onActiveFocusChanged: {
                                    if (askInput.activeFocus)
                                        GlobalStates.desktopWidgetKeyboardFocus = true;
                                }
                                Keys.onPressed: (event) => {
                                    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                        && (event.modifiers & Qt.ControlModifier)) {
                                        root.sendAskPrompt();
                                        event.accepted = true;
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: OpenCode.sortedSessions.length === 0

                            EmptyState {
                                anchors.fill: parent
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

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            visible: OpenCode.sortedSessions.length > 0

                            PromptTemplate {
                                label: "Explain"
                                onActivated: {
                                    askInput.text = "Explain the current changes and any risks.";
                                    root.focusAskInput();
                                }
                            }

                            PromptTemplate {
                                label: "Fix"
                                onActivated: {
                                    askInput.text = "Find and fix the current errors, then summarize the changes.";
                                    root.focusAskInput();
                                }
                            }

                            PromptTemplate {
                                label: "Tests"
                                onActivated: {
                                    askInput.text = "Run the relevant tests and fix any failures.";
                                    root.focusAskInput();
                                }
                            }

                            Item { Layout.fillWidth: true }

                            RippleButton {
                                implicitHeight: 30
                                implicitWidth: askModeLabel.implicitWidth + 16
                                buttonRadius: 15
                                colBackground: root.askAgent === "plan"
                                    ? Appearance.colors.colTertiaryContainer
                                    : Appearance.colors.colPrimaryContainer
                                colBackgroundHover: root.askAgent === "plan"
                                    ? Appearance.colors.colTertiaryContainerHover
                                    : Appearance.colors.colPrimaryContainerHover
                                colRipple: root.askAgent === "plan"
                                    ? Appearance.colors.colTertiaryContainerActive
                                    : Appearance.colors.colPrimaryContainerActive
                                onClicked: {
                                    root.askAgent = root.askAgent === "plan" ? "build" : "plan";
                                    root.askAgentTouched = true;
                                    root.focusAskInput();
                                }

                                contentItem: StyledText {
                                    id: askModeLabel
                                    text: root.askAgent === "plan" ? "Plan" : "Build"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Medium
                                    color: root.askAgent === "plan"
                                        ? Appearance.colors.colOnTertiaryContainer
                                        : Appearance.colors.colOnPrimaryContainer
                                }
                            }

                            RippleButton {
                                implicitHeight: 30
                                implicitWidth: 78
                                buttonRadius: 15
                                enabled: root.askSession && OpenCode.connected
                                    && askInput.text.trim().length > 0
                                    && !OpenCode.actionBusy
                                colBackground: enabled
                                    ? Appearance.colors.colPrimary
                                    : Appearance.colors.colLayer2
                                colBackgroundHover: enabled
                                    ? Appearance.colors.colPrimaryHover
                                    : Appearance.colors.colLayer2Hover
                                colRipple: enabled
                                    ? Appearance.colors.colPrimaryActive
                                    : Appearance.colors.colLayer2Active
                                onClicked: root.sendAskPrompt()

                                contentItem: StyledText {
                                    text: "Send"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Medium
                                    color: enabled
                                        ? Appearance.colors.colOnPrimary
                                        : Appearance.colors.colSubtext
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
                    text: root.footerText
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

        ResizeHandler {
            anchorItem: card
            hoverActive: root.containsMouse
            locked: Config.options.background.widgetsLocked
            currentWidth: root.widgetWidth
            resizeMode: "diagonal"

            onResizedXY: (dx, dy, startWidth) => root.applyResize(dx, dy, startWidth)
            onResizeFinished: root.commitSize()
        }
    }
}
