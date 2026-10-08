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
**NO actualizar** hasta que el repo esté publicado y FIRMADO ⚠️ — si actualiza ahora, pacman tirará de
`[alarm]`/`[aur]` y la consola quedará sin arrancar (la chimera ✗).

## ESTADO DE LAS TARJETAS
- **128 GB**: sistema del 26-sep (kernel 7.2.4) — **FUNCIONA** ✓ (es la buena; NO tocar sin backup)
- **1 TB**: sistema inconsistente ✗ (kernel 7.2.4 → llega al login pero no arranca sesión; con 7.2.6/7.2.9
  → bucle del ADSP). La imagen del 26-sep (`build/image/sm8750/pocknix-sm8750-sd.img`) la restaura ✓
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
- **PENDIENTE**: `[pocknix-base]` sin reponer (nuestro R2 no tiene `/base`).
