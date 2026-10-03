#!/bin/bash
# sync-to-os.sh — copy OUR content (this repo = THE CENTER) into the pocknix-os build tree.
#
# WHY THIS EXISTS
#   Until 15/09/2026 the fixes lived in two unsynchronised copies: the Odin (applied by hand),
#   this repo, and the pocknix-os build tree. The build only ever reads pocknix-os, so anything
#   that was not there simply never reached the image (the OOBE marker, the power sentinels, the
#   Odin 3 daemons, the adreno GX-collapse patch...). This script makes the copy one-directional
#   and repeatable: edit HERE, run this, build.
#
# USAGE
#   tools/sync-to-os.sh              # apply (idempotent)
#   tools/sync-to-os.sh --dry-run    # show what would change
#   POCKNIX_OS_DIR=/path tools/sync-to-os.sh
#
# The build calls tools/check-sync.sh, which fails if the tree drifted away from the centre.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OS="${POCKNIX_OS_DIR:-${HERE}/../pocknix-os}"
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

[ -d "${OS}" ] || { echo "ERROR: pocknix-os not found at ${OS} (set POCKNIX_OS_DIR)" >&2; exit 1; }

RSYNC=(rsync -a --itemize-changes)
[ "${DRY}" = 1 ] && RSYNC+=(--dry-run)

log() { printf '  %s\n' "$*"; }

# mirror: our directory IS the whole content of the target (it is a package we own outright)
mirror() {
  local src="${HERE}/$1" dst="${OS}/$2"
  [ -d "${src}" ] || { log "SKIP (missing here): $1"; return 0; }
  echo "==> mirror $1 -> $2"
  mkdir -p "${dst}"
  "${RSYNC[@]}" --delete --exclude='.git' "${src}/" "${dst}/" | sed 's/^/    /'
}

# overlay: our files are ADDED into a directory that also holds upstream's files
overlay() {
  local src="${HERE}/$1" dst="${OS}/$2"
  [ -d "${src}" ] || { log "SKIP (missing here): $1"; return 0; }
  echo "==> overlay $1 -> $2"
  mkdir -p "${dst}"
  "${RSYNC[@]}" "${src}/" "${dst}/" | sed 's/^/    /'
}

# --- our own device packages (whole directories) -----------------------------
mirror "packages/pocknix-bsp-sm8750"    "devices/sm8750/packages/pocknix-bsp-sm8750"
mirror "packages/pocknix-device-sm8750" "devices/sm8750/packages/pocknix-device-sm8750"
# El firmware del SoC como PAQUETE (mismo contrato que pocknix-firmware-sm8550): sin esto solo
# se actualizaba en una tarjeta recien flasheada (install_firmware() hacia rsync), y el par ADSP
# con la autenticacion de bateria podia revertirse en silencio con cualquier transaccion de
# linux-firmware. El PKGBUILD + ./paths viven aqui; los blobs los.stagea build-packages.sh desde
# devices/<dev>/firmware/ y vendor/rocknix-extra-firmware/ (NINGUN binario en git).
mirror "packages/pocknix-firmware-sm8750" "devices/sm8750/packages/pocknix-firmware-sm8750"

# --- the SoC packages our branch was missing entirely ------------------------
# Without these two the image could not rebuild its own kernel or bootloader: it silently kept
# whatever was in the localrepo (a 09-11 kernel package whose modules no longer matched the
# freshly built Image). They came from odin3-pr, which had them all along.
mirror "packages/linux-pocknix-sm8750"      "packages/soc/linux-pocknix-sm8750"
mirror "packages/pocknix-bootloader-sm8750" "packages/soc/pocknix-bootloader-sm8750"

# --- gamescope-session-plus (la sesion estandar de SteamOS) -------------------
# Portado de OGC (armadaOS usa esto). gamescope-session = el motor; gamescope-session-steam =
# nuestra sesion "steam" + pocknix-steam-client. Paquetes nuestros (no existen en el arbol).
mirror "packages/gamescope-session"       "packages/shared/gamescope-session"
mirror "packages/gamescope-session-steam" "packages/shared/gamescope-session-steam"

# --- our files that the build copies verbatim into the rootfs ----------------
overlay "overlay" "overlay"

# --- our override of the package-build harness -------------------------------
# scripts/build-packages.sh: adds MAKEFLAGS=-j$(nproc) to the chroot's makepkg.conf (the ALARM
# base ships it commented out, so every build ran SERIAL — hours instead of minutes) and skips
# the opt-in emulation packages unless POCKNIX_EMULATION=1. FULL COPY: if upstream changes its
# build-packages.sh this file has to be re-merged (the check only verifies the two match).
overlay "scripts" "scripts"

# --- our versions of files that live in upstream's packages ------------------
# pocknix-bsp-common is upstream's device-neutral BSP; we carry newer fan control scripts
# (the "off" fan mode, the [ -f ] guard). Copied in, never deleted.
overlay "packages/pocknix-bsp-common" "packages/shared/pocknix-bsp-common"

# --- kernel patches + DTS ----------------------------------------------------
# kernel/patches/ mirrors the build's kernel/sm8750/patches/ layout (05-speedup, 10-mainline,
# 20-sm8750, 30-version). Those dirs also hold ROCKNIX's patches, so these are overlays, not
# mirrors. 05-speedup is the Lorenzo Stoakes "kbuild: significantly speed up kernel builds" series
# (22 of 23; #15 needs a manual port) — it is what makes the kernel build take ~5 min instead of
# ~40 on this machine, so it lives in the centre rather than only in the build tree.
overlay "kernel/patches/05-speedup"  "kernel/sm8750/patches/05-speedup"
overlay "kernel/patches/10-mainline" "kernel/sm8750/patches/10-mainline"
overlay "kernel/patches/20-sm8750"   "kernel/sm8750/patches/20-sm8750"
overlay "kernel/patches/30-version"  "kernel/sm8750/patches/30-version"
overlay "kernel/dts"                 "kernel/sm8750/dts/qcom"

# --- config/ del build: listas de paquetes, pocknix.conf, tuning -------------
# Antes vivia SOLO en el arbol: las listas de paquetes (base.list / base-extras.list), el
# pocknix.conf y el tuning del SoC podian cambiar sin que nadie lo notara. Es el MISMO agujero
# que dejo pasar el cmdline roto del 25/09 (ver docs/INCIDENTE-2026-09-25-nologreplay.md).
# Solo van NUESTROS ficheros; los de upstream (pacman.conf.in, tuning sm8250/sm8550) se quedan
# en el arbol. Es un OVERLAY: anade/actualiza, no borra nada del arbol.
overlay "config" "config"

# --- devices/sm8750: el CMDLINE del kernel y la lista de paquetes del device --
# ⚠️ AQUI ESTABA EL BUG DEL 25/09: `rootflags=nologreplay` vivia en profile.conf, que solo
# existia en el arbol y no lo vigilaba check-sync.sh -> se compilo y la imagen no arrancaba.
# Ahora el cmdline es del centro. Solo van NUESTROS ficheros (profile.conf, packages.list,
# firmware/README.md): la subcarpeta packages/ la traen sus propios mirrors de arriba.
# OJO con los blobs: de devices/sm8750/firmware/ van a git SOLO los dos del cargador
# (qcom/sm8750/adsp.mbn + adsp_dtb.mbn, el par con la autenticacion de bateria); el resto del
# arbol SM8750 se baja de ROCKNIX/extra-firmware en `make sync` a vendor/ (gitignored). Los
# entrega el paquete pocknix-firmware-sm8750, no este overlay.
overlay "devices/sm8750" "devices/sm8750"

# --- per-SoC package overrides -----------------------------------------------
# packages/soc-overrides/<name>/ mirrors packages/soc/<name>/. Needed because build-packages.sh
# SKIPS any packages/soc/ package whose ./socs does not list the current SoC: upstream's
# fex-emu/mangohud/mesa/pocknix-turnip-arm only listed "sm8550 sm8250", so on an sm8750 build
# they were silently never rebuilt (and gamescope's frame-limiter patch never reached the image).
if [ -d "${HERE}/packages/soc-overrides" ]; then
  for d in "${HERE}"/packages/soc-overrides/*/; do
    [ -d "${d}" ] || continue
    overlay "packages/soc-overrides/$(basename "${d}")" "packages/soc/$(basename "${d}")"
  done
fi

# --- pocknix-desktop: our service ordering fixes -----------------------------
# pocknix-flathub.service: upstream orders it after network-online.target and wants it in the
# boot transaction, which stalls multi-user.target for the whole >300 MB flatpak seed. Ours is
# started only by the NM dispatcher once a link is really up (odin3-pr e574b2a).
overlay "packages/pocknix-desktop" "packages/shared/pocknix-desktop"

# --- gamescope: our patches + our PKGBUILD -----------------------------------
# NO tiene bloque propio: lo cubre el bucle `packages/soc-overrides/*` de arriba.
# gamescope es un paquete packages/soc/, asi que el centro solo puede sobrescribirlo
# POR AHI (mirror a packages/soc/gamescope/): su PKGBUILD es una COPIA COMPLETA del del
# build con 0009 (frame limiter del QAM) + 0010 (rotacion HW) + 0011 (--force-composition
# no cancelable por la X property) en source=() y prepare(). Al ser un override, si
# upstream cambia su PKGBUILD hay que re-fusionar (el check solo ve que los ficheros
# cuadran, no que el PKGBUILD siga a upstream). Antes vivia en packages/gamescope/, que
# el build NUNCA veia (build-packages.sh salta packages/soc/ cuyo socs no lista el SoC:
# asi se colo semanas el parche 0009 sin llegar a la imagen).

# --- deckstation-arm: PKGBUILD + el Updater ----------------------------------
# deckstation-arm es un paquete NUESTRO (vendored de stshunz) que vive entero en
# packages/shared/. Aqui solo llevamos las partes que editamos: el PKGBUILD
# (pkgrel + instalacion del Updater) y updater/ (el port aarch64). El resto del
# paquete (configs, scripts, overlay) sigue editandose en el arbol.
overlay "packages/deckstation-arm" "packages/shared/deckstation-arm"

# --- python-pygame-ce: dependencia del Updater ---------------------------------
# pygame no esta en ALARM y el clasico no tiene wheel para Python 3.14. Este
# paquete instala el wheel aarch64 de pygame-ce (drop-in, modulo `pygame`).
overlay "packages/python-pygame-ce" "packages/shared/python-pygame-ce"

# --- pocknix-steam: el sync de la biblioteca de Steam --------------------------
# pocknix-steam llama a pocknix-steam-sync JUSTO ANTES de arrancar Steam, que es el
# unico momento seguro para escribir shortcuts.vdf (Steam lo reescribe al salir).
# Lo reapuntamos a DeckStation: la capa de emulacion de upstream NO esta en esta
# imagen, asi que el script original buscaba ~/ES-DE + /usr/bin/pocknix-play, no
# encontraba nada y el tile nunca aparecia en el modo juego.
overlay "packages/pocknix-steam" "packages/shared/pocknix-steam"

# --- pocknix-tools: la opcion de preparar la capa de emulacion ------------------
# do_deckstation() ahora prepara DeckStation (assets/cores/configs/bios) y OFRECE
# el asistente de WProton; ademas hay una entrada propia para WProton. Solo
# llevamos el script (el PKGBUILD es de upstream y no cambia).
overlay "packages/pocknix-tools" "packages/shared/pocknix-tools"

# --- suyu-libretro: core de Nintendo Switch para RetroArch ---------------------
# Compilado nativo aarch64 (no hay builds publicados). Se instala en
# /usr/lib/libretro/; la integracion con el RetroArch portable de DeckStation
# (copia al dir de cores) es un pendiente aparte.
overlay "packages/suyu-libretro" "packages/shared/suyu-libretro"
overlay "packages/libretro-cores-pocknix" "packages/shared/libretro-cores-pocknix"
overlay "packages/pocknix-decky"   "packages/shared/pocknix-decky"

# --- librerias + shims que necesitan los cores PRECOMPILADOS de ArkOS --------
# Los cores de libretro-cores-pocknix se bajan ya construidos (los compilo
# ArkOS sobre Debian) y enlazan contra sonames que ALARM no tiene:
#   armsx2_libretro.so  -> libplutovg.so.1 + libplutosvg.so.0 + libpcap.so.0.8
#   uae4arm_libretro.so -> libFLAC.so.8
# plutovg y plutosvg se COMPILAN de verdad (no hay nada equivalente en ALARM);
# pocknix-soname-compat trae libFLAC.so.8 (FLAC 1.3.4, ABI distinta de la 1.5.0
# del sistema) y el symlink libpcap.so.0.8 -> libpcap.so.1. Los tres son
# shared (no dependen del SoC) y los engancha `depends` de libretro-cores-pocknix,
# de modo que instalar los cores arrastra las librerias tambien en una
# instalacion limpia (antes solo funcionaba porque se copiaron a mano).
overlay "packages/plutovg"              "packages/shared/plutovg"
overlay "packages/plutosvg"             "packages/shared/plutosvg"
overlay "packages/pocknix-soname-compat" "packages/shared/pocknix-soname-compat"

# --- pocknix-wsquashfs: comprimir juegos a .wsquashfs ------------------------
# Los scripts + los menus de Dolphin + el tipo MIME. En la Odin los juegos viven
# en una microSD pequeña; comprimirlos libera espacio. Es la MISMA receta que usa
# el DeckStation x86_64 de Fransis (mksquashfs -comp zstd -b 1M -noappend), asi
# el resultado es identico. Ver el PKGBUILD para las 3 reglas de los ServiceMenus
# de KDE 6 (carpeta kio/servicemenus, clave ServiceTypes y el bit de ejecucion).
overlay "packages/pocknix-wsquashfs"    "packages/shared/pocknix-wsquashfs"

# --- pocknix-vk-valve: el Turnip de VALVE como payload seleccionable ------------
# Copia SOLO el ICD de Vulkan del paquete aarch64 de Valve (deckard-mesa-linux) a
# /usr/share/pocknix/vk-arm/26.3.0-valve/, junto al alias libdisplay-info.so.1. El driver del
# sistema sigue siendo el nuestro: esto lo elige el tweak "Mesa Version" por juego (+13,4% FPS
# medido). Ver packages/pocknix-vk-valve/PKGBUILD y docs/PRUEBAS-MESA.md.
overlay "packages/pocknix-vk-valve" "packages/shared/pocknix-vk-valve"

# --- pocknix-steam-full: metapaquete de la capa de Steam ------------------------
# Override de UN solo PKGBUILD (el resto del paquete es de upstream y no cambia) unicamente para
# anadir el depends de pocknix-vk-valve: es la capa de juego la que ya lleva los payloads de
# Turnip (pocknix-turnip-arm / pocknix-turnip-x86), y una linea de depends es lo que hace que el
# paquete llegue a las imagenes nuevas y a los dispositivos con -Syu.
overlay "packages/pocknix-steam-full" "packages/shared/pocknix-steam-full"

# --- NOT synced (needs manual work — see the note below) ---------------------
# kernel/patches is an OVERLAY: a patch we REMOVE from the centre is NOT removed from the build.
# If you retire a patch, delete it in pocknix-os too (or the image keeps applying it).

echo
if [ "${DRY}" = 1 ]; then
  echo "dry run — nothing written."
else
  echo "sync done. Verify with: tools/check-sync.sh"
fi
