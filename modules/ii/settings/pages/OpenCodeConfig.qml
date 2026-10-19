import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: page
    forceWidth: true

    ColumnLayout {
        id: mainLayout
        Layout.fillWidth: true
        spacing: 20

        ContentSection {
            icon: "smart_toy"
            shape: MaterialShape.Shape.Cookie12Sided
            title: "OpenCode"
            collapsible: false

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 78
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer1

                RowLayout {
                    anchors {
                        fill: parent
                        margins: 12
                    }
                    spacing: 10

                    MaterialShapeWrappedMaterialSymbol {
                        wrappedShape: MaterialShape.Shape.Cookie12Sided
                        text: OpenCode.connected ? "check_circle" : "terminal"
                        iconSize: 22
                        fill: 1
                        padding: 10
                        color: OpenCode.connected
                            ? Appearance.colors.colPrimary
                            : Appearance.colors.colTertiaryContainer
                        colSymbol: OpenCode.connected
                            ? Appearance.colors.colOnPrimary
                            : Appearance.colors.colOnTertiaryContainer
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            text: "OpenCode"
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer1
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: {
                                const version = OpenCode.snapshot.version ? ` · v${OpenCode.snapshot.version}` : "";
                                return `${OpenCode.statusText}${version}`;
                            }
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }
                    }

                    RippleButton {
                        implicitHeight: 32
                        implicitWidth: 90
                        buttonRadius: Appearance.rounding.full
                        colBackground: Appearance.colors.colPrimary
                        colBackgroundHover: Appearance.colors.colPrimaryHover
                        colRipple: Appearance.colors.colPrimaryActive
                        onClicked: OpenCode.openOpenCode()

                        contentItem: StyledText {
                            text: Translation.tr("Open")
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnPrimary
                        }
                    }

                    RippleButton {
                        visible: !OpenCode.connected
                        implicitHeight: 32
                        implicitWidth: 76
                        buttonRadius: Appearance.rounding.full
                        colBackground: Appearance.colors.colSecondaryContainer
                        colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                        colRipple: Appearance.colors.colSecondaryContainerActive
                        onClicked: OpenCode.retryNow()

                        contentItem: StyledText {
                            text: Translation.tr("Retry")
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                RippleButton {
                    implicitHeight: 32
                    implicitWidth: 118
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colSecondaryContainer
                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                    colRipple: Appearance.colors.colSecondaryContainerActive
                    onClicked: OpenCode.startService()

                    contentItem: StyledText {
                        text: Translation.tr("Start service")
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: OpenCode.lastActionError || (!OpenCode.connected ? OpenCode.lastBridgeError : "")
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    horizontalAlignment: Text.AlignRight
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colError
                }
            }
        }

        ContentSection {
            icon: "widgets"
            shape: MaterialShape.Shape.Puffy
            title: Translation.tr("Desktop widget")

            GroupedList {
                ConfigSwitch {
                    buttonIcon: "toggle_on"
                    text: Translation.tr("Show OpenCode widget")
                    checked: Config.options.background.widgets.opencodeHub.enable
                    onCheckedChanged: Config.options.background.widgets.opencodeHub.enable = checked
                }

                ConfigSwitch {
                    buttonIcon: "payments"
                    text: Translation.tr("Show session cost")
                    checked: Config.options.background.widgets.opencodeHub.showCost
                    onCheckedChanged: Config.options.background.widgets.opencodeHub.showCost = checked
                }

                ConfigSwitch {
                    buttonIcon: "folder"
                    text: Translation.tr("Show project name")
                    checked: Config.options.background.widgets.opencodeHub.showProject
                    onCheckedChanged: Config.options.background.widgets.opencodeHub.showProject = checked
                }

                ConfigSwitch {
                    buttonIcon: "visibility_off"
                    text: Translation.tr("Privacy mode")
                    checked: Config.options.background.widgets.opencodeHub.privacyMode
                    onCheckedChanged: Config.options.background.widgets.opencodeHub.privacyMode = checked
                }

                ConfigSlider {
                    Layout.fillWidth: true
                    text: Translation.tr("Widget width")
                    buttonIcon: "width"
                    value: Config.options.background.widgets.opencodeHub.width
                    from: 320
                    to: 760
                    stepSize: 10
                    usePercentTooltip: false
                    stopIndicatorValues: [520]
                    onValueChanged: Config.options.background.widgets.opencodeHub.width = Math.round(value)
                }

                ConfigSlider {
                    Layout.fillWidth: true
                    text: Translation.tr("Widget height")
                    buttonIcon: "height"
                    value: Config.options.background.widgets.opencodeHub.height
                    from: 280
                    to: 820
                    stepSize: 10
                    usePercentTooltip: false
                    stopIndicatorValues: [500]
                    onValueChanged: Config.options.background.widgets.opencodeHub.height = Math.round(value)
                }

                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colSecondaryContainer
                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                    colRipple: Appearance.colors.colSecondaryContainerActive
                    onClicked: {
                        Config.options.background.widgets.opencodeHub.width = 520;
                        Config.options.background.widgets.opencodeHub.height = 500;
                    }

                    contentItem: StyledText {
                        text: Translation.tr("Reset size")
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                }

                ConfigSelectionArray {
                    text: Translation.tr("Default tab")
                    icon: "tab"
                    currentValue: Config.options.background.widgets.opencodeHub.defaultPage
                    options: [
                        { displayName: Translation.tr("Sessions"), icon: "forum", value: "sessions" },
                        { displayName: Translation.tr("Attention"), icon: "notification_important", value: "attention" },
                        { displayName: Translation.tr("Ask"), icon: "edit_note", value: "ask" }
                    ]
                    onSelected: newValue => Config.options.background.widgets.opencodeHub.defaultPage = newValue
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                text: Translation.tr("You can also drag the bottom-right corner of the widget to resize it.\n"
                    + "Launcher: /ask &lt;prompt&gt; sends to the default session.")
                wrapMode: Text.Wrap
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }

        ContentSection {
            icon: "toast"
            shape: MaterialShape.Shape.Bun
            title: Translation.tr("Bar & alerts")

            GroupedList {
                ConfigSwitch {
                    buttonIcon: "tag"
                    text: Translation.tr("Show active count in bar")
                    checked: Config.options.bar.opencode.showCount
                    onCheckedChanged: Config.options.bar.opencode.showCount = checked
                }

                ConfigSwitch {
                    buttonIcon: "notification_important"
                    text: Translation.tr("Show waiting badge in bar")
                    checked: Config.options.bar.opencode.showWaiting
                    onCheckedChanged: Config.options.bar.opencode.showWaiting = checked
                }

                ConfigSwitch {
                    buttonIcon: "nest_wifi_pro"
                    text: Translation.tr("Agent alerts in dynamic island")
                    checked: Config.options.bar.opencode.dynamicIslandAlerts
                    onCheckedChanged: Config.options.bar.opencode.dynamicIslandAlerts = checked
                }

                ConfigSlider {
                    Layout.fillWidth: true
                    text: Translation.tr("Popup sessions")
                    buttonIcon: "format_list_numbered"
                    value: Config.options.bar.opencode.popupSessionLimit
                    from: 2
                    to: 8
                    stepSize: 1
                    usePercentTooltip: false
                    stopIndicatorValues: [4]
                    onValueChanged: Config.options.bar.opencode.popupSessionLimit = Math.round(value)
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                text: Translation.tr("Add the OpenCode widget from Settings → Bar to show it in the bar.")
                wrapMode: Text.Wrap
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }
    }
}
