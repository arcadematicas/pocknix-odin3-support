# CAUSA RAÍZ: por qué se rompen las consolas al actualizar (repo R2) — 09-oct-2026

## EL PROBLEMA EN UNA FRASE
Los dispositivos apuntaban a **`pocknix.shuuri.net` (de OTRO ✗ — MUERTO, 404)** en vez de a
**nuestro R2**. Al no poder validar el repo de Pocknix, **pacman tira de `[alarm]`+`[aur]`** ✗ →
mezcla versiones (chimera ✗) → **la consola deja de arrancar** ✗. Verificado hoy con pruebas.

## DATOS CLAVE
- URL pública de nuestro repo: `https://pub-fd47305874674bf597b27eb7f880e73b.r2.dev`
- Bucket: `r2:pocknix/{shared,sm8750}` (¡SIN `repo/`!) — el SCRIPT espera `r2:pocknix/repo/<soc>` ✗
- El repo sm8750 tiene: 11 paquetes (kernel, mesa 26.3.0, vulkan, gamescope, turnip, bsp, device,
  bootloader, firmware, fex-emu, mangohud) + `pocknix.db` + `pocknix.files` + `pocknix-repo.gpg`
- Repo section name = **`[pocknix]`** (el db se llama `pocknix.db`) y `[pocknix-shared]` (`pocknix-shared.db`)
- GPG: clave `85C433EE12621EED` (`pocknix-repo@arcadematicas`) — **FIRMA SIN PASSPHRASE** ✓
- EL VENENO: la sección `[aur]` en los pacman de los dispositivos ✗ (ofrecía gamescope 3.16.25 de AUR,
  y mesa/vulkan BAJANDO de versión)

## LO QUE YA ESTÁ HECHO (09-oct)
- `config/pocknix.conf`: `POCKNIX_REPO_URL` → nuestro r2.dev ✓ (backups .bak ✓)
- `config/pacman.conf.in`: `[aur]` ELIMINADO ✓ + añadidas `[pocknix]` (…/sm8750) y `[pocknix-shared]` ✓
- R2: `rclone copy r2:pocknix/sm8750 r2:pocknix/repo/sm8750` y `…/shared …/repo/shared` ✓ (YA alineado ✓)
- `pocknix-firmware-sm8750`: **pkgrel=2** y **construido** ✓ (para tener un delta válido)
- La Odin: `/etc/pacman.conf` → nuestro repo ✓ + `[aur]` fuera ✓ + clave GPG importada ✓
  (su `[pocknix-base]` se quitó provisionalmente: nuestro R2 NO tiene `/base` ✗)

## LO QUE FALTA (2-3 comandos)
```bash
# 1) El gate `make stage` verifica TODOS los SoC y falla por el sm8550 (árbol incompleto ✗):
#    opciones: alinear también sm8550  ó  ver scripts/stage-check.sh (¿limitar al SoC actual?)
rclone copy r2:pocknix/sm8550 r2:pocknix/repo/sm8550   # si ese árbol existe
# 2) Stage + PUBLICAR (re-firma el db → ¡ESTO ES EL ARREGLO!)
cd ~/pocknix-odin3-project/pocknix-os
DEVICE=sm8750 POCKNIX_STAGE_CHECK_OFFLINE=1 make stage PKG="pocknix-firmware-sm8750"
POCKNIX_REPO_GPG_KEY=85C433EE12621EED POCKNIX_REPO_RCLONE_REMOTE=r2:pocknix make publish
# 3) Reponer [pocknix-base]: publicar el snapshot de ALARM (o mirar por qué falta)
# 4) Verificar en la Odin:  pacman -Syy  → sin "signature invalid" →  pacman -Qu
```

## AVISO PARA DAVIDUSKY (y cualquiera)
**✅ YA se puede actualizar con seguridad**: el repo está publicado y FIRMADO. Pasos exactos en
`docs/ACTUALIZAR-ODIN-DAVIDUSKY-2026-10-09.md`. (El aviso antiguo de "no actualizar" queda LEVANTADO.)

## ESTADO DE LAS TARJETAS
- **128 GB**: sistema del 26-sep (kernel 7.2.4) — **FUNCIONA** ✓ (es la buena; NO tocar sin backup)
- **1 TB**: sistema inconsistente ✗ (chimera: mezcla de paquetes). Con 7.2.4 llega al login pero no
  arranca sesión; con 7.2.6/7.2.9 salía un bucle del ADSP — **CORRECCIÓN (Fransis, 09-oct): el kernel
  7.2.6 funcionaba bien; el bucle era por los paquetes mezclados, NO del kernel.** La imagen del 26-sep
  (`build/image/sm8750/pocknix-sm8750-sd.img`) la restaura ✓
- Imagen del 26-sep = `~/pocknix-odin3-project/pocknix-os/build/image/sm8750/pocknix-sm8750-sd.img` (25,6 GB)

## VER TAMBIÉN
- `docs/ODIN3-ARRANQUE-Y-WIFI-2026-10-08.md` (el día del ADSP/boot, con todas las pruebas descartadas)
- `docs/REPOSITORIO-ACTUALIZACIONES.md` (el modelo del repo, de sesiones anteriores)

## ✅ CIERRE (09-oct-2026, madrugada) — el arreglo, hecho y verificado
- `make stage DEVICE=sm8750 PKG="pocknix-firmware-sm8750"` con env
  `POCKNIX_STAGE_CHECK_OFFLINE=1 POCKNIX_STAGE_CHECK_SOCS=sm8750 POCKNIX_REPO_RCLONE_REMOTE=r2:pocknix`.
  El gate (`make stage`) fallaba por el **sm8550** (su árbol no está publicado) → se limita al
  SoC con `POCKNIX_STAGE_CHECK_SOCS=sm8750`. Resultado: **gate OK** (11 paquetes, firmware `-2`).
- `make publish DEVICE=sm8750` (env `POCKNIX_REPO_GPG_KEY=85C433EE12621EED
  POCKNIX_REPO_RCLONE_REMOTE=r2:pocknix`) → firma + `pocknix.db` nuevo + subida a
  **`r2:pocknix/sm8750`** (la ruta que sirve el r2.dev, **SIN** `repo/`).
  Verificado por HTTP: `/sm8750/pocknix.db(+.sig)` 200 de HOY y firma RSA correcta
  (`pocknix-repo@arcadematicas`); firmware `0.1.0-2` 200 y `0.1.0-1` **404** (podada).
- **⚠️ HUEco destapado al verificar la Odin**: su `/etc/pacman.conf` solo tenía
  `[pocknix-shared]`; FALTABA **`[pocknix]`** (per-SoC `…/sm8750`). Añadida (backup
  `/etc/pacman.conf.bak-20261009-003629`) → `pacman -Syy` **valida la firma** y
  mesa/gamescope/kernel/firmware/bsp resuelven desde **`pocknix`**.
- **Para las imágenes**: `devices/sm8750/profile.conf` tenía `POCKNIX_SHIP_SOC_REPO=0`
  (de cuando sm8750 no se publicaba) → las imágenes NO traían la stanza. **Cambiado a `1`**
  (centro+árbol) para que las imágenes nuevas la traigan.
- **`[pocknix-base]` REPUESTO**: la base de upstream SÍ estaba viva
  (`https://pocknix.shuuri.net/repo/base`, 893 paquetes, MISMO snapshot que nuestro lockfile
  `20260826.2`: 0 derivas de versión). Espejada a **`r2:pocknix/base`** (893 pkg + `.sig` +
  `pocknix-base.db`/`.files` + el tarball ALARM `ArchLinuxARM-aarch64-20260826.tar.gz`;
  checksums verificados) y añadida la stanza `[pocknix-base]`
  (`SigLevel = Required DatabaseOptional`, `Server = …r2.dev/base`) en la Odin (backup
  `/etc/pacman.conf.bak-20261009-004420`). Ahora `pacman -Syy` resuelve la base
  (systemd/glibc/openssl) desde **`pocknix-base`** → un `-Syu` ya NO tira de la ALARM viva.
  `POCKNIX_REPO_URL` y `POCKNIX_ALARM_TARBALL_URL` apuntan ya al r2.dev (centro+árbol).

- **ACLARACIÓN (Fransis, 09-oct)**: **el kernel 7.2.6 es correcto** — los bucles del ADSP no eran del
  kernel sino de los **paquetes mezclados** (chimera). Con el repo ya consistente (base pinneada +
  `[pocknix]`/`[pocknix-shared]`/`[pocknix-base]` publicadas y firmadas), un `pacman -Syu` en la Odin
  ya no mezcla versiones.

## 🚀 ACTUALIZACIÓN REAL EN LA ODIN — VERIFICADA (09-oct-2026)
- `sudo pacman -Syu --noconfirm` en la Odin (SSH 192.168.4.22, tarjeta mmcblk0 119G, imagen 26-sep).
- El repo funcionó como debía: **sin "signature invalid"**, **sin mezcla con ALARM**, **sin errores BTF**.
- Subieron 14 paquetes: `linux-pocknix-sm8750 7.2.6-1`, `mesa 26.3.0`, `gamescope` (nuestro),
  `pocknix-bsp-sm8750 0.2.0-6`, `pocknix-base 0.2.0-7`, `deckstation-arm`, `pocknix-decky`,
  `pocknix-steam`, `libretro-cores-pocknix`, `pocknix-desktop-full`… y **se instaló
  `pocknix-firmware-sm8750 0.1.0-2`** (ADSP, que antes no estaba).
- El hook `90-linux-pocknix.hook` **regeneró `/flash/KERNEL`** (7.2.6) + `KERNEL.md5` (md5 OK);
  dejó `KERNEL.bak` = 7.2.4. Snapshot btrfs pre-transacción creado antes de tocar nada.
- **Reinició y volvió** (~1,5 min): kernel en uso **7.2.6**, **0 servicios fallidos**, WiFi UP,
  inputplumber activo, `vhci_hcd` cargado, zram 10,7 G, `pacman -Qu` = **0**.
- **Confirmado por Fransis ("funciona todo bien")**: el fallo histórico **NO era el kernel-7.2.6**
  (va bien) sino la **mezcla de paquetes**. La AVISO de "no actualizar" queda **levantada**: ya se
  puede `pacman -Syu` con normalidad.
