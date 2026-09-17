# Maintainer: stshunz <https://github.com/stshunz>
# DeckStation ARM — sistema de emulación portable para aarch64/armv7h.
# Proyecto independiente. Versión original (x86_64): deckstation-x86_64.
pkgname=deckstation-arm
pkgver=1.0.0
pkgrel=2
pkgdesc="Sistema de emulación portable para ARM (aarch64/armv7h)"
arch=('aarch64' 'armv7h')
url="https://github.com/stshunz/deckstation-arm"
license=('GPL2')
depends=(
    'python'
    'python-requests'
    'python-pygame'
)
makedepends=()
optdepends=(
    'lib32-mesa: soporte OpenGL 32-bit'
    'vulkan-icd-loader: soporte Vulkan'
    'pulseaudio: audio del sistema'
    'pipewire-pulse: audio moderno'
)
source=()
sha256sums=()
install=deckstation-arm.install

package() {
    # Los archivos viven en el dir del paquete (no en $srcdir: source=() está
    # vacío), así que se referencian con ${startdir}. makepkg aplana las rutas de
    # source=() locales (get_filename -> basename), por eso no se usan ahí.
    local sd="${startdir}"

    # Directorio base
    install -dm755 "${pkgdir}/opt/deckstation"

    # Scripts principales
    install -Dm755 "${sd}/scripts/deckstation-setup.sh" \
        "${pkgdir}/opt/deckstation/scripts/deckstation-setup.sh"
    install -Dm755 "${sd}/scripts/deckstation-launcher.sh" \
        "${pkgdir}/opt/deckstation/scripts/deckstation-launcher.sh"
    install -Dm755 "${sd}/scripts/deckstation-update.sh" \
        "${pkgdir}/opt/deckstation/scripts/deckstation-update.sh"
    install -Dm755 "${sd}/scripts/setup_arm64_apps.py" \
        "${pkgdir}/opt/deckstation/scripts/setup_arm64_apps.py"
    install -Dm755 "${sd}/scripts/lanzar.sh" \
        "${pkgdir}/opt/deckstation/scripts/lanzar.sh"
    install -Dm755 "${sd}/scripts/deckstation-configs.sh" \
        "${pkgdir}/opt/deckstation/scripts/deckstation-configs.sh"

    # Configs de emuladores (portables, rutas relativas)
    install -dm755 "${pkgdir}/opt/deckstation/configs"
    cp -r "${sd}/configs/"* "${pkgdir}/opt/deckstation/configs/"
    # El paquete se construye como root: asegurar que deck pueda leerlos
    # (DeckStation corre como deck y el despliegue de configs lee de aqui).
    chmod -R a+rX "${pkgdir}/opt/deckstation/configs"

    # Overlay: comando del sistema
    install -Dm755 "${sd}/overlay/usr/bin/deckstation" \
        "${pkgdir}/usr/bin/deckstation"

    # Overlay: entrada de escritorio (solo DeckStation/ES-DE; los emuladores se
    # lanzan desde ES-DE, no necesitan .desktop propio)
    install -Dm644 "${sd}/overlay/usr/share/applications/deckstation.desktop" \
        "${pkgdir}/usr/share/applications/deckstation.desktop"

    # Updater (Apps/Updater): actualizador de AppImages con interfaz grafica.
    # Portado de la version x86_64; aqui usa el Python del sistema (aarch64) y
    # un git.txt con las fuentes aarch64. Ver updater/README.md.
    install -dm755 "${pkgdir}/opt/deckstation/Apps/Updater/icons"
    install -Dm755 "${sd}/updater/updater.py"      "${pkgdir}/opt/deckstation/Apps/Updater/updater.py"
    install -Dm755 "${sd}/updater/scraper.py"      "${pkgdir}/opt/deckstation/Apps/Updater/scraper.py"
    install -Dm755 "${sd}/updater/bezel_master.py" "${pkgdir}/opt/deckstation/Apps/Updater/bezel_master.py"
    install -Dm755 "${sd}/updater/launcher.sh"     "${pkgdir}/opt/deckstation/Apps/Updater/launcher.sh"
    install -Dm644 "${sd}/updater/git.txt"         "${pkgdir}/opt/deckstation/Apps/Updater/git.txt"
    install -Dm644 "${sd}/updater/settings.conf"   "${pkgdir}/opt/deckstation/Apps/Updater/settings.conf"
    install -Dm644 "${sd}/updater/CHANGELOG.md"    "${pkgdir}/opt/deckstation/Apps/Updater/CHANGELOG.md"
    install -Dm644 "${sd}/updater/icons/map.json"  "${pkgdir}/opt/deckstation/Apps/Updater/icons/map.json"

    # Estructura de directorios (se crearán en post-install)
    install -dm755 "${pkgdir}/opt/deckstation/Apps"
    install -dm755 "${pkgdir}/opt/deckstation/saves"
    install -dm755 "${pkgdir}/opt/deckstation/logs"
    install -dm755 "${pkgdir}/opt/deckstation/Media"
    install -dm755 "${pkgdir}/opt/deckstation/settings"
}
