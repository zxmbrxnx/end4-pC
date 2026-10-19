import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

RippleButton {
    id: chip
    property var sessionData
    property bool selected: false
    property bool privacyMode: false
    signal activated()

    implicitHeight: 28
    implicitWidth: chipContent.implicitWidth + 18
    buttonRadius: 14
    colBackground: chip.selected
        ? Appearance.colors.colPrimaryContainer
        : Appearance.colors.colLayer2
    colBackgroundHover: chip.selected
        ? Appearance.colors.colPrimaryContainerHover
        : Appearance.colors.colLayer2Hover
    colRipple: chip.selected
        ? Appearance.colors.colPrimaryContainerActive
        : Appearance.colors.colLayer2Active
    onClicked: chip.activated()

    contentItem: Item {
        implicitWidth: chipContent.implicitWidth
        implicitHeight: chipContent.implicitHeight

        RowLayout {
            id: chipContent
            anchors.centerIn: parent
            spacing: 5

            Rectangle {
                implicitWidth: 6
                implicitHeight: 6
                radius: 3
                color: {
                    if (chip.sessionData && chip.sessionData.status === "waiting") return Appearance.colors.colTertiary;
                    if (chip.sessionData && chip.sessionData.status === "working") return Appearance.colors.colPrimary;
                    if (chip.sessionData && chip.sessionData.status === "error") return Appearance.colors.colError;
                    return Appearance.colors.colOutline;
                }
            }

            StyledText {
                Layout.maximumWidth: 150
                text: chip.privacyMode ? "Session" : ((chip.sessionData && chip.sessionData.title) || "Untitled session")
                elide: Text.ElideRight
                maximumLineCount: 1
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: chip.selected ? Font.Medium : Font.Normal
                color: chip.selected
                    ? Appearance.colors.colOnPrimaryContainer
                    : Appearance.colors.colOnLayer2
            }
        }
    }
}
