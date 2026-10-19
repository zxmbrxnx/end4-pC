import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    required property var di
    anchors.fill: parent

    readonly property bool material: root.di ? root.di.isMaterial : false
    readonly property var permission: root.di ? root.di.openCodeAlertPermission : null
    readonly property var session: root.di ? root.di.openCodeAlertSession : null
    readonly property string kind: root.di ? root.di.openCodeAlertKind : ""

    readonly property string title: {
        if (kind === "permission") return Translation.tr("Permission needed");
        if (kind === "error") return Translation.tr("Session failed");
        return Translation.tr("Session finished");
    }

    readonly property string body: {
        if (kind === "permission") {
            if (!permission) return "";
            const action = permission.action || Translation.tr("Permission");
            const resources = (permission.resources || []).join(" ");
            return `${action} · ${resources}`;
        }
        return root.session ? (root.session.title || "") : "";
    }

    readonly property string iconName: {
        if (kind === "permission") return "gpp_maybe";
        if (kind === "error") return "error";
        return "check_circle";
    }

    readonly property color iconBg: {
        if (kind === "permission") return Appearance.colors.colTertiaryContainer;
        if (kind === "error") return Appearance.colors.colErrorContainer;
        return Appearance.colors.colPrimaryContainer;
    }

    readonly property color iconFg: {
        if (kind === "permission") return Appearance.colors.colOnTertiaryContainer;
        if (kind === "error") return Appearance.colors.colOnErrorContainer;
        return Appearance.colors.colOnPrimaryContainer;
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: root.material ? 4 : 10
            rightMargin: 8
        }
        spacing: 6

        MaterialShapeWrappedMaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            wrappedShape: MaterialShape.Shape.Cookie12Sided
            text: root.iconName
            iconSize: root.material ? 20 : 16
            fill: 1
            padding: 4
            color: root.iconBg
            colSymbol: root.iconFg
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: -2

            StyledText {
                Layout.fillWidth: true
                text: root.title
                elide: Text.ElideRight
                maximumLineCount: 1
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
            }

            StyledText {
                Layout.fillWidth: true
                text: root.body
                elide: Text.ElideRight
                maximumLineCount: 1
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colOnLayer0
                opacity: 0.7
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 2
            visible: root.kind === "permission"

            RippleButton {
                implicitWidth: 24
                implicitHeight: 24
                buttonRadius: 12
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                colRipple: Appearance.colors.colPrimaryActive
                enabled: !OpenCode.actionBusy
                opacity: OpenCode.actionBusy ? 0.5 : 1
                onClicked: {
                    if (!root.permission) return;
                    OpenCode.replyPermission(root.permission.sessionID, root.permission.id, "once");
                    if (root.di) root.di.dismissOpenCodeAlert();
                }

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "check"
                    iconSize: 15
                    color: Appearance.colors.colOnPrimary
                }
            }

            RippleButton {
                implicitWidth: 24
                implicitHeight: 24
                buttonRadius: 12
                colBackground: Appearance.colors.colErrorContainer
                colBackgroundHover: Appearance.colors.colErrorContainerHover
                colRipple: Appearance.colors.colErrorContainerActive
                enabled: !OpenCode.actionBusy
                opacity: OpenCode.actionBusy ? 0.5 : 1
                onClicked: {
                    if (!root.permission) return;
                    OpenCode.replyPermission(root.permission.sessionID, root.permission.id, "reject");
                    if (root.di) root.di.dismissOpenCodeAlert();
                }

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: 15
                    color: Appearance.colors.colOnErrorContainer
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        visible: root.kind !== "permission"
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.session) OpenCode.openSession(root.session.id, root.session.directory);
            if (root.di) root.di.dismissOpenCodeAlert();
        }
    }
}
