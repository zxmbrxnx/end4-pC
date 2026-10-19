import QtQuick
import qs.modules.common
import qs.modules.common.widgets

RippleButton {
    id: promptTemplate
    property string label
    signal activated()

    implicitHeight: 24
    implicitWidth: templateLabel.implicitWidth + 16
    buttonRadius: 12
    colBackground: Appearance.colors.colLayer2
    colBackgroundHover: Appearance.colors.colLayer2Hover
    colRipple: Appearance.colors.colLayer2Active
    onClicked: promptTemplate.activated()

    contentItem: Item {
        implicitWidth: templateLabel.implicitWidth
        implicitHeight: templateLabel.implicitHeight

        StyledText {
            id: templateLabel
            anchors.centerIn: parent
            text: promptTemplate.label
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer2
        }
    }
}
