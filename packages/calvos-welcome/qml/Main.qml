import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import Pocknix.Ui

// Asistente de primer arranque. Una pagina por paso en el rail de AppWindow; el mando mueve
// el foco con el D-pad, activa con A, vuelve con B y cambia de pagina con LB/RB.
AppWindow {
    id: app
    title: qsTr("Bienvenido a CalvOS")

    readonly property string cli: "/usr/bin/calvos-welcome"
    readonly property string profileCli: "/usr/bin/pocknix-power-profile"
    readonly property string sshCli: "/usr/bin/pocknix-ssh"
    readonly property string shareCli: "/usr/bin/pocknix-share"
    readonly property int servicesIndex: 3
    readonly property int padIndex: 4

    property var networks: []
    property string wifiStatus: ""
    property string wifiError: ""
    property string profile: "medio"
    property string profileMessage: ""
    property var padSeen: []
    property bool sshOn: false
    property bool sshBusy: false
    property bool shareInstalled: false
    property bool shareOn: false
    property bool shareBusy: false
    property string servicesMessage: ""

    function finish() {
        if (finishJob.running)
            return
        finishJob.start([app.cli, "finish"])
    }

    function scan() {
        if (scanJob.running)
            return
        app.wifiError = ""
        app.wifiStatus = qsTr("Buscando redes...")
        scanJob.start(["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY",
                       "device", "wifi", "list", "--rescan", "yes"])
    }

    // nmcli -t separa por ':' y escapa los ':' del SSID con una barra inversa.
    function parseWifi(text) {
        const found = []
        text.split(/\r?\n/).forEach(line => {
            if (!line.trim())
                return
            const parts = []
            let cur = ""
            let escaped = false
            for (let i = 0; i < line.length; ++i) {
                const ch = line.charAt(i)
                if (escaped) {
                    cur += ch
                    escaped = false
                } else if (ch === "\\") {
                    escaped = true
                } else if (ch === ":") {
                    parts.push(cur)
                    cur = ""
                } else {
                    cur += ch
                }
            }
            parts.push(cur)
            const ssid = (parts[0] || "").trim()
            if (!ssid || found.some(e => e.ssid === ssid))
                return
            found.push({
                ssid: ssid,
                signal: parseInt(parts[1], 10) || 0,
                secured: !!parts[2] && parts[2].trim() !== "--"
            })
        })
        found.sort((a, b) => b.signal - a.signal)
        return found
    }

    function choose(entry) {
        if (connectJob.running)
            return
        app.wifiError = ""
        if (entry.secured) {
            pwSheet.net = entry
            pwField.text = ""
            pwSheet.open()
        } else {
            connectJob.ssid = entry.ssid
            connectJob.start(["nmcli", "device", "wifi", "connect", entry.ssid])
        }
    }

    function connectPassword() {
        if (!pwSheet.net || connectJob.running || !pwField.text)
            return
        connectJob.ssid = pwSheet.net.ssid
        connectJob.start(["nmcli", "device", "wifi", "connect", pwSheet.net.ssid,
                          "password", pwField.text])
    }

    function applyProfile(value) {
        if (profileJob.running)
            return
        app.profile = value
        app.profileMessage = qsTr("Aplicando perfil...")
        profileJob.start([app.profileCli, value], { root: true })
    }

    function statusValue(text, key) {
        const prefix = key + "="
        const lines = String(text || "").split(/\r?\n/)
        for (let i = 0; i < lines.length; ++i) {
            if (lines[i].indexOf(prefix) === 0)
                return lines[i].slice(prefix.length).trim()
        }
        return ""
    }

    function refreshSshStatus() {
        if (!sshStatusJob.running)
            sshStatusJob.start([app.sshCli, "status"])
    }

    function refreshShareStatus() {
        if (!shareStatusJob.running)
            shareStatusJob.start([app.shareCli, "status"])
    }

    function refreshServices() {
        refreshSshStatus()
        refreshShareStatus()
    }

    function toggleSsh() {
        if (sshJob.running || shareInstallJob.running || shareJob.running)
            return
        const next = !app.sshOn
        sshJob.previous = app.sshOn
        sshJob.desired = next
        app.sshOn = next
        app.sshBusy = true
        app.servicesMessage = ""
        sshJob.start([app.sshCli, next ? "on" : "off"], { root: true })
    }

    function toggleShare() {
        if (sshJob.running || shareInstallJob.running || shareJob.running)
            return
        const next = !app.shareOn
        shareInstallJob.previous = app.shareOn
        shareJob.previous = app.shareOn
        shareJob.desired = next
        app.shareOn = next
        app.shareBusy = true
        app.servicesMessage = ""
        if (next && !app.shareInstalled)
            shareInstallJob.start([app.shareCli, "install"], { root: true })
        else
            shareJob.start([app.shareCli, next ? "on" : "off"], { root: true })
    }

    function pageAt(index) {
        return [welcomePage, wifiPage, powerPage, servicesPage, padPage][index]
    }
    function currentPage() {
        return pageAt(currentIndex)
    }
    function setInitialFocus() {
        const page = currentPage()
        if (page && page.initialFocus)
            page.initialFocus()
    }

    function padNav(key) {
        const page = currentPage()
        const list = page && page.navTargets
            ? page.navTargets().filter(item => item.visible && item.enabled) : []
        if (list.length === 0)
            return
        const at = list.indexOf(activeFocusItem)
        let next = at < 0 ? 0 : at + ((key === Qt.Key_Right || key === Qt.Key_Down) ? 1 : -1)
        next = Math.max(0, Math.min(list.length - 1, next))
        list[next].forceActiveFocus()
    }

    function sheetNav(key) {
        const list = [pwField, pwCancelBtn, pwConnectBtn].filter(item => item.enabled)
        const at = list.indexOf(activeFocusItem)
        let next = at < 0 ? 0 : at + ((key === Qt.Key_Right || key === Qt.Key_Down) ? 1 : -1)
        next = Math.max(0, Math.min(list.length - 1, next))
        list[next].forceActiveFocus()
    }

    function padPressed(key) {
        if (app.dialogOpen) {
            if (key === Qt.Key_Escape)
                app.closeDialog()
            return
        }
        if (pwSheet.opened) {
            if (key === Qt.Key_Escape)
                pwSheet.close()
            else if (key === Qt.Key_Return)
                app.connectPassword()
            else if (key === Qt.Key_Left || key === Qt.Key_Right
                     || key === Qt.Key_Up || key === Qt.Key_Down)
                app.sheetNav(key)
            return
        }
        // En la prueba del mando LB/RB y las flechas marcan su boton; A marca y ademas
        // activa el control con foco (asi se llega a Continuar sin raton).
        if (app.currentIndex === app.padIndex) {
            const marked = padPage.mark(key)
            if (marked && key !== Qt.Key_Return)
                return
        }
        if (key === Qt.Key_Escape) {
            if (app.currentIndex > 0)
                app.currentIndex--
            return
        }
        if (key === Qt.Key_PageUp) {
            app.currentIndex = Math.max(0, app.currentIndex - 1)
            return
        }
        if (key === Qt.Key_PageDown) {
            app.currentIndex = Math.min(app.padIndex, app.currentIndex + 1)
            return
        }
        if (key === Qt.Key_Return) {
            const item = activeFocusItem
            if (item && item.clicked && item.enabled)
                item.clicked()
            return
        }
        if (key === Qt.Key_Left || key === Qt.Key_Right
            || key === Qt.Key_Up || key === Qt.Key_Down)
            app.padNav(key)
    }

    Component.onCompleted: {
        refreshServices()
        Qt.callLater(setInitialFocus)
    }
    onCurrentIndexChanged: Qt.callLater(setInitialFocus)

    Connections {
        target: Pad
        function onPressed(key) { app.padPressed(key) }
    }

    Job {
        id: scanJob
        onFinished: code => {
            if (code !== 0) {
                app.networks = []
                app.wifiError = error
                app.wifiStatus = qsTr("No se pudieron listar las redes Wi-Fi.")
                return
            }
            app.networks = app.parseWifi(output)
            app.wifiError = ""
            app.wifiStatus = app.networks.length
                ? qsTr("%1 redes disponibles").arg(app.networks.length)
                : qsTr("No se encontraron redes Wi-Fi.")
        }
    }

    Job {
        id: connectJob
        property string ssid
        onFinished: code => {
            if (code === 0) {
                pwSheet.close()
                app.wifiError = ""
                app.wifiStatus = qsTr("Conectado a %1").arg(ssid)
                app.toast(qsTr("Wi-Fi conectado"), app.wifiStatus)
            } else {
                app.wifiError = error
                app.wifiStatus = qsTr("No se pudo conectar a %1").arg(ssid)
                if (!pwSheet.opened)
                    app.notice(qsTr("No se pudo conectar"), error)
            }
        }
    }

    Job {
        id: profileJob
        onFinished: code => {
            app.profileMessage = code === 0
                ? qsTr("Perfil aplicado: %1").arg(app.profile === "alto"
                    ? qsTr("Rendimiento") : qsTr("Equilibrado"))
                : qsTr("No se pudo aplicar el perfil: %1").arg(error)
            if (code !== 0)
                app.notice(qsTr("Perfil no aplicado"), error)
        }
    }

    Job {
        id: sshStatusJob
        onFinished: code => {
            if (sshJob.running)
                return
            if (code !== 0) {
                app.servicesMessage = qsTr("No se pudo consultar el estado de SSH: %1").arg(error)
                return
            }
            app.sshOn = app.statusValue(output, "state") === "on"
            app.servicesMessage = ""
        }
    }

    Job {
        id: shareStatusJob
        onFinished: code => {
            if (shareJob.running || shareInstallJob.running)
                return
            if (code !== 0) {
                app.servicesMessage = qsTr("No se pudo consultar el estado de Samba: %1").arg(error)
                return
            }
            app.shareInstalled = app.statusValue(output, "installed") === "yes"
            app.shareOn = app.statusValue(output, "state") === "on"
            app.servicesMessage = ""
        }
    }

    Job {
        id: sshJob
        property bool previous: false
        property bool desired: false
        onFinished: code => {
            app.sshBusy = false
            if (code === 0) {
                app.sshOn = desired
                app.servicesMessage = ""
                app.toast(qsTr("SSH"), desired ? qsTr("Servicio activado") : qsTr("Servicio desactivado"))
            } else {
                app.sshOn = previous
                app.servicesMessage = qsTr("No se pudo cambiar SSH: %1").arg(error)
                app.notice(qsTr("No se pudo cambiar SSH"), error)
            }
            app.refreshSshStatus()
        }
    }

    Job {
        id: shareInstallJob
        property bool previous: false
        onFinished: code => {
            if (code !== 0) {
                app.shareBusy = false
                app.shareOn = previous
                app.servicesMessage = qsTr("No se pudo instalar Samba: %1").arg(error)
                app.notice(qsTr("No se pudo instalar Samba"), error)
                app.refreshShareStatus()
                return
            }
            app.shareInstalled = true
            shareJob.previous = previous
            shareJob.desired = true
            shareJob.start([app.shareCli, "on"], { root: true })
        }
    }

    Job {
        id: shareJob
        property bool previous: false
        property bool desired: false
        onFinished: code => {
            app.shareBusy = false
            if (code === 0) {
                app.shareOn = desired
                app.servicesMessage = ""
                app.toast(qsTr("Samba (SMB)"), desired ? qsTr("Servicio activado") : qsTr("Servicio desactivado"))
            } else {
                app.shareOn = previous
                app.servicesMessage = qsTr("No se pudo cambiar Samba: %1").arg(error)
                app.notice(qsTr("No se pudo cambiar Samba"), error)
            }
            app.refreshShareStatus()
        }
    }

    Job {
        id: finishJob
        onFinished: Qt.callLater(() => {
            app.close()
            Qt.quit()
        })
    }

    TabPage {
        id: welcomePage
        title: qsTr("Bienvenida")
        icon: "dialog-information-symbolic"

        function initialFocus() { startBtn.forceActiveFocus() }
        function navTargets() { return [startBtn, skipWelcomeBtn] }

        QQC2.Label {
            Layout.fillWidth: true
            text: qsTr("Bienvenido a CalvOS")
            font.bold: true
            font.pointSize: Theme.titleFontSize
            wrapMode: Text.WordWrap
        }
        QQC2.Label {
            Layout.fillWidth: true
            text: qsTr("Vamos a dejar tu Odin lista en un minuto.")
            wrapMode: Text.WordWrap
        }
        QQC2.Label {
            Layout.fillWidth: true
            text: qsTr("Conectaremos el Wi-Fi, elegiremos el perfil de energía y probaremos el mando. Puedes saltar cualquier paso.")
            color: Theme.textMuted
            wrapMode: Text.WordWrap
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacing
            spacing: Theme.spacing
            Button {
                id: startBtn
                text: qsTr("Empezar")
                kind: Button.Primary
                activeFocusOnTab: true
                onClicked: app.currentIndex = 1
            }
            Button {
                id: skipWelcomeBtn
                text: qsTr("Saltar")
                activeFocusOnTab: true
                onClicked: app.currentIndex = app.padIndex
            }
        }
    }

    TabPage {
        id: wifiPage
        title: qsTr("Red")
        icon: "network-wireless-symbolic"
        property bool scanned: false

        function initialFocus() { refreshBtn.forceActiveFocus() }
        function navTargets() {
            const list = [refreshBtn]
            for (let i = 0; i < netRepeater.count; ++i)
                list.push(netRepeater.itemAt(i))
            list.push(skipWifiBtn)
            return list
        }
        onVisibleChanged: {
            if (visible && !scanned) {
                scanned = true
                app.scan()
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: qsTr("Wi-Fi")
            font.bold: true
            font.pointSize: Theme.titleFontSize
        }
        QQC2.Label {
            Layout.fillWidth: true
            text: app.wifiStatus
            color: Theme.textMuted
            wrapMode: Text.WordWrap
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing
            Button {
                id: refreshBtn
                text: qsTr("Actualizar")
                activeFocusOnTab: true
                enabled: !scanJob.running
                onClicked: app.scan()
            }
            Button {
                id: skipWifiBtn
                text: qsTr("Saltar")
                activeFocusOnTab: true
                onClicked: app.currentIndex = 2
            }
        }
        QQC2.Label {
            Layout.fillWidth: true
            visible: app.wifiError !== ""
            text: app.wifiError
            color: Theme.negative
            wrapMode: Text.WordWrap
        }
        Repeater {
            id: netRepeater
            model: app.networks
            Button {
                required property var modelData
                Layout.fillWidth: true
                activeFocusOnTab: true
                text: modelData.ssid + "  ·  " + modelData.signal + "%"
                    + (modelData.secured ? "  ·  " + qsTr("protegida") : "")
                onClicked: app.choose(modelData)
            }
        }
        QQC2.Label {
            Layout.fillWidth: true
            visible: app.networks.length === 0 && !scanJob.running && app.wifiError === ""
            text: qsTr("Si no ves tu red, puedes seguir igualmente: configúrala más tarde en Ajustes.")
            color: Theme.textMuted
            wrapMode: Text.WordWrap
        }
    }

    TabPage {
        id: powerPage
        title: qsTr("Energía")
        icon: "system-run-symbolic"

        function initialFocus() { balancedBtn.forceActiveFocus() }
        function navTargets() { return [balancedBtn, performanceBtn, nextPowerBtn] }

        QQC2.Label {
            Layout.fillWidth: true
            text: qsTr("Energía")
            font.bold: true
            font.pointSize: Theme.titleFontSize
        }
        QQC2.Label {
            Layout.fillWidth: true
            text: qsTr("Elige cuánto rendimiento quieres por defecto. Podrás cambiarlo después.")
            color: Theme.textMuted
            wrapMode: Text.WordWrap
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing
            Button {
                id: balancedBtn
                text: qsTr("Equilibrado")
                kind: app.profile === "medio" ? Button.Primary : Button.Secondary
                activeFocusOnTab: true
                enabled: !profileJob.running
                onClicked: app.applyProfile("medio")
            }
            Button {
                id: performanceBtn
                text: qsTr("Rendimiento")
                kind: app.profile === "alto" ? Button.Primary : Button.Secondary
                activeFocusOnTab: true
                enabled: !profileJob.running
                onClicked: app.applyProfile("alto")
            }
        }
        QQC2.Label {
            Layout.fillWidth: true
            text: qsTr("Elegido: %1").arg(app.profile === "alto"
                ? qsTr("Rendimiento") : qsTr("Equilibrado"))
        }
        QQC2.Label {
            Layout.fillWidth: true
            visible: app.profileMessage !== ""
            text: app.profileMessage
            color: Theme.textMuted
            wrapMode: Text.WordWrap
        }
        Button {
            id: nextPowerBtn
            text: qsTr("Siguiente")
            activeFocusOnTab: true
            onClicked: app.currentIndex = app.servicesIndex
        }
    }

    TabPage {
        id: servicesPage
        title: qsTr("Servicios")
        icon: "network-server-symbolic"

        function initialFocus() { sshRow.forceActiveFocus() }
        function navTargets() { return [sshRow, shareRow, nextServicesBtn] }
        onVisibleChanged: {
            if (visible)
                app.refreshServices()
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: qsTr("Servicios")
            font.bold: true
            font.pointSize: Theme.titleFontSize
        }
        QQC2.Label {
            Layout.fillWidth: true
            text: qsTr("Activa solo lo que necesites. Puedes cambiarlo después en Ajustes.")
            color: Theme.textMuted
            wrapMode: Text.WordWrap
        }
        SwitchRow {
            id: sshRow
            title: qsTr("SSH")
            description: qsTr("Terminal remoto (usuario deck)")
            checked: app.sshOn
            busy: app.sshBusy
            activeFocusOnTab: true
            border.width: activeFocus ? 2 : 1
            border.color: activeFocus ? Theme.accent : Theme.border
            signal clicked()
            onClicked: app.toggleSsh()
            Keys.onReturnPressed: clicked()
            Keys.onSpacePressed: clicked()
            onToggled: clicked()
        }
        SwitchRow {
            id: shareRow
            title: qsTr("Samba (SMB)")
            description: qsTr("Comparte archivos en tu red")
            checked: app.shareOn
            busy: app.shareBusy
            activeFocusOnTab: true
            border.width: activeFocus ? 2 : 1
            border.color: activeFocus ? Theme.accent : Theme.border
            signal clicked()
            onClicked: app.toggleShare()
            Keys.onReturnPressed: clicked()
            Keys.onSpacePressed: clicked()
            onToggled: clicked()
        }
        QQC2.Label {
            Layout.fillWidth: true
            visible: app.servicesMessage !== ""
            text: app.servicesMessage
            color: Theme.negative
            wrapMode: Text.WordWrap
        }
        QQC2.Label {
            Layout.fillWidth: true
            text: app.shareInstalled
                ? qsTr("Samba está instalado.")
                : qsTr("Samba no está instalado: se instalará al activarlo.")
            color: Theme.textMuted
            wrapMode: Text.WordWrap
        }
        Button {
            id: nextServicesBtn
            text: qsTr("Siguiente")
            activeFocusOnTab: true
            onClicked: app.currentIndex = app.padIndex
        }
    }

    TabPage {
        id: padPage
        title: qsTr("Mando")
        icon: "input-gamepad-symbolic"
        readonly property var buttons: [
            { name: "A", label: "A (Sur)" },
            { name: "B", label: "B (Este)" },
            { name: "LB", label: "LB" },
            { name: "RB", label: "RB" },
            { name: "Arriba", label: "D-pad arriba" },
            { name: "Abajo", label: "D-pad abajo" },
            { name: "Izquierda", label: "D-pad izquierda" },
            { name: "Derecha", label: "D-pad derecha" }
        ]

        function initialFocus() { forceActiveFocus() }
        function navTargets() { return [continueBtn, skipPadBtn] }
        function mark(key) {
            let name = ""
            switch (key) {
            case Qt.Key_Return:   name = "A"; break
            case Qt.Key_Escape:   name = "B"; break
            case Qt.Key_PageUp:   name = "LB"; break
            case Qt.Key_PageDown: name = "RB"; break
            case Qt.Key_Up:       name = "Arriba"; break
            case Qt.Key_Down:     name = "Abajo"; break
            case Qt.Key_Left:     name = "Izquierda"; break
            case Qt.Key_Right:    name = "Derecha"; break
            default: return false
            }
            if (app.padSeen.indexOf(name) < 0)
                app.padSeen = app.padSeen.concat([name])
            return true
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: qsTr("Pulsa los botones")
            font.bold: true
            font.pointSize: Theme.titleFontSize
        }
        QQC2.Label {
            Layout.fillWidth: true
            text: qsTr("Detectados %1 de %2. Si no tienes mando, salta este paso.").arg(app.padSeen.length).arg(padPage.buttons.length)
            color: Theme.textMuted
            wrapMode: Text.WordWrap
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Theme.spacing
            rowSpacing: Theme.spacing
            Repeater {
                model: padPage.buttons
                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.minimumHeight: Theme.touchTarget
                    radius: Theme.radius
                    color: app.padSeen.indexOf(modelData.name) >= 0 ? Theme.accentFill : Theme.surfaceHigh
                    border.width: 1
                    border.color: app.padSeen.indexOf(modelData.name) >= 0 ? Theme.accent : Theme.border
                    QQC2.Label {
                        anchors.centerIn: parent
                        text: (app.padSeen.indexOf(modelData.name) >= 0 ? "✓  " : "") + modelData.label
                        color: app.padSeen.indexOf(modelData.name) >= 0 ? Theme.accentText : Theme.text
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacing
            spacing: Theme.spacing
            Button {
                id: continueBtn
                text: qsTr("Continuar")
                kind: Button.Primary
                activeFocusOnTab: true
                onClicked: app.finish()
            }
            Button {
                id: skipPadBtn
                text: qsTr("Saltar")
                activeFocusOnTab: true
                onClicked: app.finish()
            }
        }
    }

    Sheet {
        id: pwSheet
        property var net: null
        height: parent ? Math.min(parent.height - Theme.spacing * 4, Theme.unit * 16) : 0
        onOpened: pwField.forceActiveFocus()
        onClosed: {
            net = null
            pwField.text = ""
        }

        contentItem: ColumnLayout {
            spacing: Theme.spacing
            QQC2.Label {
                Layout.fillWidth: true
                text: qsTr("Contraseña de %1").arg(pwSheet.net ? pwSheet.net.ssid : "")
                font.bold: true
                font.pointSize: Theme.titleFontSize
                wrapMode: Text.WordWrap
            }
            QQC2.TextField {
                id: pwField
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: qsTr("Contraseña Wi-Fi")
                activeFocusOnTab: true
                Keys.onReturnPressed: app.connectPassword()
            }
            QQC2.Label {
                Layout.fillWidth: true
                visible: app.wifiError !== "" && !connectJob.running
                text: app.wifiError
                color: Theme.negative
                wrapMode: Text.WordWrap
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing
                Button {
                    id: pwConnectBtn
                    text: qsTr("Conectar")
                    kind: Button.Primary
                    activeFocusOnTab: true
                    enabled: !connectJob.running && pwField.text !== ""
                    onClicked: app.connectPassword()
                }
                Button {
                    id: pwCancelBtn
                    text: qsTr("Cancelar")
                    activeFocusOnTab: true
                    onClicked: pwSheet.close()
                }
            }
        }
    }
}
