import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property string icon: "info"
    property string title: ""
    property string body: ""
    property string actionText: ""
    property string actionIcon: "arrow_forward"
    property bool busy: false

    signal actionClicked()

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 32, 280)
        spacing: 10

        MaterialShapeWrappedMaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            wrappedShape: MaterialShape.Shape.Cookie12Sided
            text: root.icon
            iconSize: 26
            fill: 1
            padding: 12
            color: Appearance.colors.colSecondaryContainer
            colSymbol: Appearance.colors.colOnSecondaryContainer

            RotationAnimation on rotation {
                running: root.busy
                from: 0
                to: 360
                duration: 1200
                loops: Animation.Infinite
                direction: RotationAnimation.Clockwise
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: root.title
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            font.pixelSize: Appearance.font.pixelSize.large
            font.weight: Font.Medium
            color: Appearance.colors.colOnLayer1
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.body.length > 0
            text: root.body
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
        }

        RippleButton {
            Layout.alignment: Qt.AlignHCenter
            visible: root.actionText.length > 0
            implicitHeight: 34
            implicitWidth: actionContent.implicitWidth + 28
            buttonRadius: Appearance.rounding.full
            colBackground: Appearance.colors.colPrimary
            colBackgroundHover: Appearance.colors.colPrimaryHover
            colRipple: Appearance.colors.colPrimaryActive
            onClicked: root.actionClicked()

            contentItem: RowLayout {
                id: actionContent
                spacing: 6

                MaterialSymbol {
                    text: root.actionIcon
                    iconSize: 18
                    color: Appearance.colors.colOnPrimary
                }
                StyledText {
                    text: root.actionText
                    color: Appearance.colors.colOnPrimary
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                }
            }
        }
    }
}
