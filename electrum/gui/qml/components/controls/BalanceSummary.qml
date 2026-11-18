import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

Item {
    id: root

    implicitWidth: balancePane.implicitWidth
    implicitHeight: balancePane.implicitHeight

    property string formattedTotalBalance
    property string formattedTotalBalanceFiat

    function setBalances() {
        root.formattedTotalBalance = Config.formatSats(Daemon.currentWallet.totalBalance)
        if (Daemon.fx.enabled) {
            root.formattedTotalBalanceFiat = Daemon.fx.fiatValue(Daemon.currentWallet.totalBalance, false)
        }
    }

    TextHighlightPane {
        id: balancePane
        leftPadding: constants.paddingXLarge
        rightPadding: constants.paddingXLarge
        // The synchronization message can wrap to several lines.  Reserve
        // enough vertical space for it so that it does not overflow into the
        // toolbar above while the wallet is doing its initial sync.
        implicitHeight: Math.max(balanceLayout.implicitHeight,
                                 syncProgressLabel.implicitHeight + constants.paddingLarge * 2)

        GridLayout {
            id: balanceLayout
            columns: 3
            opacity: Daemon.currentWallet.synchronizing || !Network.isConnected ? 0 : 1

            Label {
                font.pixelSize: constants.fontSizeXLarge
                text: qsTr('Balance') + ':'
                color: Material.accentColor
            }

            Label {
                Layout.alignment: Qt.AlignRight
                font.pixelSize: constants.fontSizeXLarge
                font.family: FixedFont
                text: Daemon.currentWallet
                      ? Config.formatSats(Daemon.currentWallet.totalBalance)
                      : ''
            }
            Label {
                font.pixelSize: constants.fontSizeXLarge
                color: Material.accentColor
                text: Config.baseUnit
            }

            Item {
                visible: Daemon.fx.enabled
                Layout.preferredWidth: 1
            }
            Label {
                Layout.alignment: Qt.AlignRight
                visible: Daemon.fx.enabled
                font.pixelSize: constants.fontSizeLarge
                font.family: FixedFont
                color: constants.mutedForeground
                text: formattedTotalBalanceFiat
            }
            Label {
                visible: Daemon.fx.enabled
                font.pixelSize: constants.fontSizeLarge
                color: constants.mutedForeground
                text: Daemon.fx.fiatCurrency
            }

        }

    }

    Label {
        id: syncProgressLabel
        opacity: Daemon.currentWallet.synchronizing && Network.isConnected ? 1 : 0
        anchors.centerIn: balancePane
        width: balancePane.width - constants.paddingLarge * 2
        text: Daemon.currentWallet.synchronizingProgress
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        color: Material.accentColor
        font.pixelSize: constants.fontSizeLarge
    }

    Label {
        opacity: !Network.isConnected ? 1 : 0
        anchors.centerIn: balancePane
        text: Network.serverStatus
        color: Material.accentColor
        font.pixelSize: constants.fontSizeLarge
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            app.stack.push(Qt.resolvedUrl('../BalanceDetails.qml'))
        }
    }

    // instead of all these explicit connections, we should expose
    // formatted balances directly as a property
    Connections {
        target: Config
        function onBaseUnitChanged() { setBalances() }
        function onThousandsSeparatorChanged() { setBalances() }
    }

    Connections {
        target: Daemon
        function onWalletLoaded() {
            setBalances()
        }
    }

    Connections {
        target: Daemon.fx
        function onEnabledUpdated() { setBalances() }
        function onQuotesUpdated() { setBalances() }
    }

    Connections {
        target: Daemon.currentWallet
        function onBalanceChanged() {
            setBalances()
        }
    }

    Component.onCompleted: setBalances()
}
