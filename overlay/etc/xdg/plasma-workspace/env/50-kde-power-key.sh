#!/bin/bash
# Boton de encendido en KDE/Plasma Mobile: quitar "apagar pantalla" y atarlo a "Power Off".
# Script de shuuri-labs/pocknix-os (pocknix-desktop-kde, GPL-2.0-or-later), adaptado: se ejecuta
# como hook de entorno de Plasma (plasma-workspace/env) en vez de /usr/lib/pocknix/desktop.d,
# asi que usa `return` en lugar de `exit` (aqui el fichero se SOURCea).
# KDE lee los atajos globales solo al arrancar la sesion, y Plasma Mobile ata la tecla a
# "Turn Off Screen" mientras la accion "PowerOff" de powerdevil (la que aplica PowerButtonAction)
# queda sin atar. Se re-ata una vez por usuario y solo si los valores son los de por defecto.
case ":${XDG_CURRENT_DESKTOP:-}:" in *:KDE:*) ;; *) return 0 ;; esac
command -v kreadconfig6 >/dev/null 2>&1 && command -v kwriteconfig6 >/dev/null 2>&1 || return 0

stamp="${XDG_CONFIG_HOME:-${HOME}/.config}/pocknix/kde-power-key-seeded"
[ -e "${stamp}" ] && return 0

rc=kglobalshortcutsrc
grp=org_kde_powerdevil
case "$(kreadconfig6 --file "${rc}" --group "${grp}" --key PowerOff)" in
  ""|none,none,*)
    kwriteconfig6 --file "${rc}" --group "${grp}" --key PowerOff "Power Off,none,Power Off" ;;
esac
case "$(kreadconfig6 --file "${rc}" --group "${grp}" --key "Turn Off Screen")" in
  ""|"Power Off,Power Off,"*)
    kwriteconfig6 --file "${rc}" --group "${grp}" --key "Turn Off Screen" \
      "none,Power Off,Turn Off Screen" ;;
esac

mkdir -p "$(dirname "${stamp}")" && touch "${stamp}"
