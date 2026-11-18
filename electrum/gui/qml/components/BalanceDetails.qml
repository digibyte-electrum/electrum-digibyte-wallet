import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.electrum 1.0

import "controls"

Pane {
    id: rootItem
    objectName: 'BalanceDetails'

    padding: 0

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: detailsContent.height
            clip: true
            interactive: height < contentHeight

            Pane {
                id: detailsContent
                width: parent.width
                padding: constants.paddingLarge

                ColumnLayout {
                    width: parent.width
                    spacing: constants.paddingLarge

                    InfoTextArea {
                        Layout.fillWidth: true
                        Layout.bottomMargin: constants.paddingLarge
                        visible: Daemon.currentWallet.synchronizing || !Network.isConnected
                        text: Daemon.currentWallet.synchronizing
                                  ? qsTr('Your wallet is not synchronized. The displayed balance may be inaccurate.')
                                  : qsTr('Your wallet is not connected to an Electrum server. The displayed balance may be outdated.')
                        iconStyle: InfoTextArea.IconStyle.Warn
                    }

                    Heading {
                        text: qsTr('Wallet balance')
                    }

                    GridLayout {
                        Layout.alignment: Qt.AlignHCenter
                        visible: Daemon.currentWallet
                        columns: 2

                        Label {
                            text: qsTr('Total')
                        }
                        FormattedAmount {
                            amount: Daemon.currentWallet.totalBalance
                        }
                    }
                }
            }
        }
    }

    property color navigationBarBackgroundColor: constants.highlightBackground
}
