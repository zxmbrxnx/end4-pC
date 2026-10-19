import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Rectangle {
    id: root

    required property var permission
    property bool privacyMode: false
    property bool busy: false
    property double now: Date.now()

    signal replyRequested(var permission, string decision)

    property bool confirmAlways: false

    implicitHeight: content.implicitHeight + 20
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer2

    function titleText() {
        const action = String(root.permission.action || "");
        if (!action) return "Permission requested";
        return action.charAt(0).toUpperCase() + action.slice(1);
    }

    function commandBody() {
        if (root.privacyMode) return "Command hidden";
        const resources = root.permission.resources || [];
        if (resources.length > 0) return resources.join("\n");
        if (root.permission.message) return String(root.permission.message);
        return "No details available";
    }

    function waitingText() {
        const since = Number(root.permission.waitingSince || 0);
        if (!since) return "";
        const seconds = Math.max(0, Math.floor((root.now - since) / 1000));
        if (seconds < 60) return `waiting ${seconds}s`;
        const minutes = Math.floor(seconds / 60);
        if (minutes < 60) return `waiting ${minutes}m`;
        return `waiting ${Math.floor(minutes / 60)}h`;
    }

    component ActionButton: RippleButton {
        id: action
        property string label
        property color bg
        property color fg

        Layout.fillWidth: true
        implicitHeight: 30
        buttonRadius: Appearance.rounding.full
        colBackground: action.bg
        colBackgroundHover: Qt.lighter(action.bg, 1.08)
        colRipple: Qt.darker(action.bg, 1.08)
        enabled: !root.busy
        opacity: root.busy ? 0.5 : 1

        contentItem: StyledText {
            text: action.label
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Medium
            color: action.fg
        }
    }

    Timer {
        id: confirmTimer
        interval: 3000
        repeat: false
        onTriggered: root.confirmAlways = false
    }

    ColumnLayout {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 10
        }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialShapeWrappedMaterialSymbol {
                Layout.alignment: Qt.AlignTop
                wrappedShape: MaterialShape.Shape.Cookie12Sided
                text: "gpp_maybe"
                iconSize: 18
                fill: 1
                padding: 8
                color: Appearance.colors.colTertiaryContainer
                colSymbol: Appearance.colors.colOnTertiaryContainer
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: root.titleText()
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer2
                }

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        if (root.privacyMode) return root.waitingText();
                        const parts = [];
                        if (root.permission.sessionTitle) parts.push(root.permission.sessionTitle);
                        if (root.permission.directory) parts.push(String(root.permission.directory).split("/").filter(part => part.length > 0).pop() || "");
                        if (root.waitingText()) parts.push(root.waitingText());
                        return parts.filter(part => part.length > 0).join(" · ");
                    }
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: commandText.implicitHeight + 16
            radius: Appearance.rounding.small
            color: Appearance.colors.colLayer1

            StyledText {
                id: commandText
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 8
                }
                text: root.commandBody()
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            ActionButton {
                label: "Once"
                bg: Appearance.colors.colPrimary
                fg: Appearance.colors.colOnPrimary
                onClicked: root.replyRequested(root.permission, "once")
            }

            ActionButton {
                label: root.confirmAlways ? "Confirm" : "Always"
                bg: root.confirmAlways ? Appearance.colors.colError : Appearance.colors.colSecondaryContainer
                fg: root.confirmAlways ? Appearance.colors.colOnError : Appearance.colors.colOnSecondaryContainer
                onClicked: {
                    if (root.confirmAlways) {
                        root.confirmAlways = false;
                        root.replyRequested(root.permission, "always");
                    } else {
                        root.confirmAlways = true;
                        confirmTimer.restart();
                    }
                }
            }

            ActionButton {
                label: "Reject"
                bg: Appearance.colors.colErrorContainer
                fg: Appearance.colors.colOnErrorContainer
                onClicked: root.replyRequested(root.permission, "reject")
            }
        }
    }
}
