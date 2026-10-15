# Publicar paquetes — el flujo y cómo no olvidarse

**Para qué**: que un cambio que ya está terminado y verificado **llegue de verdad a las consolas**.
Tenerlo en el centro (GitHub) y en el árbol de build **no basta** ✗: pacman solo ve una actualización
si (a) sube `pkgver`/`pkgrel` y (b) esa versión está **publicada** en el repositorio.

**La herramienta que lo comprueba** (esto es lo que evita que se nos olvide):

```sh
tools/check-published.sh          # informe; exit 1 si hay deuda (vale para CI/hooks)
tools/check-published.sh --quiet  # solo la tabla
```

Compara todos los PKGBUILD del centro y del árbol (los nuestros) contra las bases de datos públicas
y lista lo que falta o está a otra versión. **Pásalo antes de dar un paquete por terminado.**

---

## Los repositorios que consumen las consolas

Vienen en `/etc/pacman.conf` de la consola (comprobado en la Odin el 15/10/2026):

| Repo pacman | URL | Qué lleva |
|---|---|---|
| `[pocknix]` | `<bucket>/sm8750` | **los del SoC**: gamescope, fex-emu, kernel, BSP, firmware, bootloader, mesa/turnip… |
| `[pocknix-shared]` | `<bucket>/shared` | neutrales de SoC: herramientas, emuladores, capas (`pocknix-decky`, `deckstation-arm`, `pocknix-vk-valve`…) |
| `[pocknix-base]` | `<bucket>/base` | la base congelada (893 paquetes) |
| `[core] [extra] [alarm]` | mirrorlist | ALARM (el rolling) |

`bucket` = `https://pub-fd47305874674bf597b27eb7f880e73b.r2.dev` (Cloudflare R2), con
`pocknix-repo.gpg` en cada carpeta. La firma es `pocknix-repo@arcadematicas`.

## El flujo (tal como se usó el 06/10 y el 15/10)

```sh
# 1) subir pkgrel en el PKGBUILD correspondiente (con un comentario del bump)
# 2) sincronizar y verificar el árbol
tools/sync-to-os.sh
tools/check-sync.sh

# 3) construir (en el sobremesa: pc-local)
make packages PKG="paquete1 paquete2 ..."

# 4) stage del repo que toque (¡ojo: shared NO es para los del SoC!)
make stage-shared PKG="..."     # neutrales  -> [pocknix-shared]
make stage PKG="..."            # del SoC    -> [pocknix]
#    (el stage-check corre solo al final del stage; si se queja de "no root reaches it",
#     añade el paquete al metapaquete que toque)

# 5) firmar y publicar
make publish-shared             # -> r2:pocknix/shared
make publish                   # -> r2:pocknix/<soc>
#    NUNCA usar POCKNIX_PUBLISH_FROM=localrepo

# 6) verificar por URL pública (HTTP 200 + gpg --verify + pacman -Si con dbpath desechable)
# 7) pasar tools/check-published.sh (debe dar OK)
# 8) documentar el cierre (docs/CIERRE-*.md) y commitear (centro + árbol)
```

## Los que NO se publican a propósito

`armsx2-bin`, `rpcs3-bin`, `xemu-bin`, `vita3k-bin`: sus fuentes no existen o no se pueden construir
con qemu. Van como `optdepends` "bring your own" en `pocknix-emulation-full`. El script ya los excluye.
Ver `docs/CIERRE-20261006-REPOSICION-PAQUETES.md`.

## Deuda detectada el 15/10/2026 (primera pasada del script)

**24 paquetes nuestros sin publicar**, entre ellos los arreglos de estos días:

| Paquete (nuestra versión) | Publicado | Nota |
|---|---|---|
| `gamescope-1:3.16.31.ogc1.20260928.afd6eac6-1` | `1:3.16.29.ogc2.20260918…` | **el arreglo del HDR/QAM** ✗ |
| `fex-emu-2610.20261007.14c92681-1` | `fex-emu-2608.20260804…` | FEX ✗ |
| `pocknix-bsp-sm8750-0.2.0-7` | `0.2.0-6` | sensores (irá como `-8`) ✗ |
| `pocknix-decky-0.1.0-53` | `0.1.0-51` | plugin `panel-de-control` 0.70.1 ✗ |
| `pocknix-vk-valve-20261013-1` | `20261009-1` | capas Valve (RPO/fossilize) ✗ |
| `deckstation-arm-1.0.0-16` | `1.0.0-15` | ✗ |
| `hexagonrpc-0.5.0-2`, `libqrtr-1.2-1`, `libssc-0.4.4-1`, `pd-mapper-1.1-1`, `msm-firmware-loader-1.8.0-2`, `pocknix-sensors-config-20251206-2` | nunca | la pila de sensores (en curso) ✗ |
| `pocknix-system-overlay-0.1.0-2` | nunca | ✗ |
| `libretro-azahar-2126.1.2-1`, `libretro-bsnes-hd-20251205-1`, `vboycolor-libretro-1.0.0.beta.11-1` | nunca | cores libretro ✗ |
| +9 del árbol (`pocknix-turnip-arm`, `pocknix-emulation`, `pocknix-steam`, `azahar`, `mesa`, `fex-rootfs`…) | | ver salida del script |

**Ojo con el kernel**: la Odin corre **7.2.10** pero el repo del SoC publica
`linux-pocknix-sm8750-7.2.9-2` ✗. El kernel se viene desplegando a `/flash/KERNEL`
(`tools/flash-kernel.sh`), no como paquete — hay que comprobar el `pkgver` del PKGBUILD del kernel
en el árbol antes de publicar, o las consolas se quedarán atrás.

## Pendiente de automatizar (idea)

El script puede colgarse de un `post-commit`/hook del centro o de un paso del `Makefile` para que
avise solo cuando la deuda cambie. Hoy es manual a propósito (el flujo de publicación exige red,
GPG y el sobremesa).

---

## ⚠️ PASO 0 (el que faltaba): sincronizar `pc-local` antes de compilar

Los builds se hacen en el **sobremesa** (`pc-local`), y su copia del centro **hay que actualizarla**:
si no, `tools/sync-to-os.sh` aplica contenido **viejo** al árbol y **los paquetes salen sin lo nuevo** ✗.
(Y `tools/check-sync.sh` da un **falso OK** ✗ porque compara el árbol local con el centro **local**: si
ambos están viejos, coinciden.)

```sh
# en pc-local
cd ~/pocknix-odin3-project/pocknix-odin3-support
git pull --ff-only                       # ← si aborta, aparta los ficheros sucios que vengan en el pull
cd ../pocknix-os
git fetch arcadematicas                  # el fork (el portátil pushea ahí)
git reset --mixed arcadematicas/odin3-sm8750   # realinear a la punta del fork (no toca ficheros)
cd ../pocknix-odin3-support
tools/sync-to-os.sh && tools/check-sync.sh
# y solo entonces:  DEVICE=sm8750 make packages PKG="..."   (¡DEVICE es obligatorio!)
```

**Visto el 15/10/2026**: `pc-local` estaba en `98fff0e` (BSP `pkgrel=7`, sin `sensors/`) mientras el
portátil ya tenía `008a9d6` (BSP `-8` + bring-up) → tres publicaciones seguidas construyeron con el
árbol viejo y no se publicó nada nuevo. Un `git pull` de 10 segundos lo habría evitado.

### Por qué los subagentes se quedaban "cancelados" (15/10/2026)

No era un fallo técnico: **hacían una `question` al usuario y la pregunta se rechazaba**
(`question.rejected` en el log del bot de Telegram) → sin respuesta, el subagente termina su turno y
opencode lo marca como cancelado. **Y preguntaban porque `make packages` exige root**
(`error must run as root (chroot/mount needed): try 'sudo make build-packages'`) y **el sobremesa
pide contraseña de sudo** (la del PC no es la de la Odin).

**Reparto de trabajo que funciona**:
1. **Humano (o quien tenga la contraseña de `pc-local`)**: lanza el build ‡
   ```sh
   cd ~/pocknix-odin3-project/pocknix-os
   sudo DEVICE=sm8750 make build-packages PKG="pd-mapper libqrtr hexagonrpc libssc msm-firmware-loader \
        pocknix-sensors-config pocknix-system-overlay pocknix-bsp-sm8750 pocknix-desktop"
   ```
   ⚠️ En background (`setsid nohup … > /tmp/publish-fase1.log 2>&1 &`) para no bloquear la sesión.
2. **Sin root** (lo puede hacer el agente): `make stage-shared PKG="…"` → `make publish-shared`;
   y `make stage PKG="…"` → `make publish` para los del SoC; luego verificar por URL + `gpg`.
   `rclone` ya tiene el remoto `r2:` dado de alta en `pc-local`.

Y regla para futuros subagentes: **no deben usar `question`**; si falta un permiso, que lo digan en el
informe final en vez de bloquearse.

### Los 3 fallos reales del builder (15/10/2026, madrugada)

1. **`/dev/null` del chroot era un FICHERO normal** ✗ (9 bytes, creado por un intento anterior), no un
   char device → `makepkg` daba `Permission denied` + "Cannot find the fakeroot/gzip/strip binary"
   → **abortaba siempre**. Arreglado en `build/pkgbuild-root-sm8750/dev/`:
   ```sh
   sudo rm -f dev/{null,zero,full,random,urandom,tty}
   sudo mknod -m666 dev/null c 1 3 ; sudo mknod -m666 dev/zero c 1 5
   sudo mknod -m666 dev/full c 1 7 ; sudo mknod -m666 dev/random c 1 8
   sudo mknod -m666 dev/urandom c 1 9 ; sudo mknod -m666 dev/tty c 5 0
   sudo mkdir -p dev/pts dev/shm
   ```
   ⚠️ Si vuelve a pasar, es que el chroot quedó sucio (p. ej. tras un `kill -9` a mitad de build).

2. **`sudo` borra el entorno** ✗ → `sudo DEVICE=sm8750 make …` compila para **sm8550** (el SoC por
   defecto). Hay que pasarlo **después** de sudo: **`sudo -A env DEVICE=sm8750 make packages`**.
   Y para sudo sin TTY: `SUDO_ASKPASS` (el pipe `echo pass | sudo -S` **cierra el stdin** y el `make`
   se queda sin poder preguntar nada ✗).

3. **`build-packages.sh` se cuelga tras el `-Syu` del chroot** ⏳ (pendiente de depurar):
   no termina ni da error; el `make` acaba con `die "no packages built"` → **Error 2**.
   Primer paso para depurarlo: `sudo -A env DEVICE=sm8750 bash -x scripts/build-packages.sh pd-mapper`
   con `timeout` y ver la **última línea** ejecutada.

### Lanzar un build sin bloquearse (lo que funciona)

```sh
# en pc-local
printf '#!/bin/sh\necho <CONTRASEÑA>\n' > ~/.build-askpass.sh && chmod 700 ~/.build-askpass.sh
systemd-run --user --unit=build-paquetes --collect \
  -p StandardOutput=file:/tmp/build.log -p StandardError=append:/tmp/build.log \
  -p WorkingDirectory=$HOME/pocknix-odin3-project/pocknix-os \
  --setenv=SUDO_ASKPASS=$HOME/.build-askpass.sh \
  /usr/bin/bash -lc 'sudo -A env DEVICE=sm8750 make packages PKG="…"'
# y seguir con:  journalctl --user -u build-paquetes   /   tail -f /tmp/build.log
```
