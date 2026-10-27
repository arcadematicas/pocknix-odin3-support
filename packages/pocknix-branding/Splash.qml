/*
    calvOS splash: la ilustracion completa (wordmark + "Handheld Operating System for Odin 3" +
    ecosistema) a pantalla completa, sobre el mismo campo que el wallpaper y Plymouth, para que
    boot -> splash -> escritorio sea una superficie continua.

    ksplashqml drives `stage` as startup progresses; stage 2 is "show yourself".
    Nothing here waits on a later stage, because Plasma Mobile's shell does not
    emit the full sequence - the unit's own exit is what takes the splash away.
*/
import QtQuick

Rectangle {
    id: root
    color: "#202126"   // el campo del wallpaper final de calvOS (16/10/2026)

    property int stage

    onStageChanged: {
        if (stage == 2) {
            fadeIn.running = true;
        }
    }

    Image {
        id: splash
        anchors.fill: parent
        // Arte 1920x1080. PreserveAspectCrop: en paneles de otra proporcion se recorta un poco
        // por los bordes en vez de deformarse o dejar franjas.
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        source: "images/splash.png"
        opacity: 0
    }

    OpacityAnimator {
        id: fadeIn
        target: splash
        from: 0
        to: 1
        duration: 400
        running: false
    }
}
