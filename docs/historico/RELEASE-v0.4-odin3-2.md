# Release v0.4-odin3-2 — arreglado el arranque y cerrado el centro

**Fecha**: 26/09/2026 · **Artefacto**: `pocknix-sm8750-sd.img` (25.602.031.616 bytes)

```
sha256  29c1fde9465296116740a09dc08887b6415dadc24c0ab91c87e850d083eb046e
```

## Por qué esta release

La imagen del 25/09 **no arrancaba**: bootloop con kernel panic y **sin ningún log**. Esta release
corrige ese fallo y, sobre todo, **cierra el agujero de proceso que lo permitió**.

La base es la misma que `v0.4-odin3-1` (ver `RELEASE-v0.4-odin3-1.md` para la tabla de componentes);
lo que cambia es esto:

## Qué se arregló

1. **El arranque (lo importante).** El cmdline del kernel llevaba `rootflags=nologreplay` y las 5
   líneas btrfs del `/etc/fstab` llevaban `,nologreplay`. En Linux 7.2 **`nologreplay` NO es una
   opción de montaje válida de btrfs** (solo existe `rescue=nologreplay`, y esa exige montaje
   solo-lectura). btrfs devolvía `-EINVAL`, **la raíz no montaba** y el kernel paniqueaba **antes de
   userspace** → de ahí que no hubiera ni un log. Mensaje, solo visible en pantalla:

   ```
   VFS: Cannot open root device "PARTLABEL=POCKNIX_ROOT" or unknown-block(179,2)
   ```

   Quitado de los dos sitios. Verificado: arranca con asistente inicial, sonido, botones y WiFi.
   Detalle completo: `docs/INCIDENTE-2026-09-25-nologreplay.md`.

2. **El centro ya cubre todo lo que rompe el arranque.** `config/` y `devices/sm8750/` (incluido
   `profile.conf`, que es donde vive el cmdline) **solo existían en el árbol de compilación** y no los
   vigilaba nadie → por ahí se coló el `nologreplay` sin pasar por ninguna revisión. Ahora están en el
   centro y `tools/check-sync.sh` los compara.

3. **`tools/build-odin3.sh` (nuevo): el orden del build, en código.** `make sync` usa
   `rsync -a --delete` sobre `kernel/sm8750/{patches,dts}` y por tanto **BORRA nuestros parches**
   (rotación, adreno, batería) y nuestros DTS. Si se aplica el centro ANTES de `make sync` —que es lo
   que decía `BUILD.md`— el kernel se compila **sin nuestro trabajo** y solo se ve un `warn` perdido
   entre cientos de líneas (pasó el 26/09: 62 parches en vez de 70). El script fija el orden
   `make sync → sync-to-os → check-sync (aborta) → build` y `BUILD.md` queda corregido.

## ⚠️ Trampa documentada: kernel y módulos tienen que ser del MISMO build

Un kernel compilado en **otra máquina** (aunque declare la misma versión *y* el mismo `vermagic`) **no
sirve** para una imagen ya construida: el **BTF** no coincide, el kernel **rechaza los módulos**
(`failed to validate module ... BTF: -22`) y te deja **sin mando** (no carga `vhci-hcd`) y **sin
sonido**. Comprobar el **Image md5**, no el número de versión. **No recompilar solo el kernel.**

## Cómo probarla

```bash
# Flashear (⚠️ DESTRUCTIVO):
sudo dd if=pocknix-sm8750-sd.img of=/dev/sdX bs=4M status=progress conv=fsync
# Al arrancar, verificar:
uname -r                                  # 7.2.4
dmesg | grep -c "failed to validate"      # 0
lsmod | grep -c vhci                      # el mando (inputplumber) necesita vhci-hcd
# rotación por hardware, sonido, wifi, asistente inicial...
```

## Pendiente tras la release

- Validar en la Odin: arranque, **mando**, **sonido**, WiFi y rotación.
- **Mandársela a David/Jarvis**: su sistema no arranca y, cuando arranca, no le funcionan mando ni
  sonido porque usan un kernel de otro build. Hay que darles **nuestro kernel** o recompilar
  kernel+módulos juntos.
- Parche `0055-backlight-aw99706-upstream-fixes` se salta por conflicto con nuestro stack — revisar.
- Espacio: la raíz de ~25 GB se queda corta para Steam en microSD; valorar la UFS interna.
- Frame limiter del QAM, ext4 vs F2FS, sensores IIO, carga de batería (opcode `0x16`).
