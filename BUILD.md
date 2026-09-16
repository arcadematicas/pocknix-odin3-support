# BUILD.md — compilar Pocknix para la AYN Odin 3 (SM8750) desde cero

Esta guía deja a cualquiera (tú, un amigo, un CI) construir la imagen desde los repos
públicos. Escrita el 16/09/2026.

---

## 1. Los repos y qué papel tiene cada uno

| Repo | Papel |
|---|---|
| **`arcadematicas/pocknix-os`** — rama **`odin3-sm8750`** | **El sistema.** Fork de `shuuri-labs/pocknix-os` con TODO: upstream v0.4 + el soporte del Odin 3 + nuestro desarrollo (DeckStation, MAKO, daemons, parches). Aquí se compila. |
| **`arcadematicas/pocknix-odin3-support`** | **El centro.** Fuente de verdad de lo NUESTRO: parches de kernel/gamescope, paquetes propios, overlay, docs y `tools/`. |
| `shuuri-labs/pocknix-os` (`origin`) | **Upstream.** Solo se lee (fetch) para sincronizar. |
| **`odin3-pr`** (misma fork) | 🔒 **CONGELADA.** Rama limpia para el PR upstream **#81** (soporte del Odin 3). **No se toca** salvo para rebasear/responder al mantenedor. Nada de DeckStation/MAKO va aquí. |

### Reglas de oro
1. **Se edita SIEMPRE en el centro** (`pocknix-odin3-support`). `pocknix-os` es el árbol de
   compilación: se regenera con `tools/sync-to-os.sh`.
2. `tools/check-sync.sh` (que el build llama) **aborta si el árbol no coincide con el centro**.
3. Lo que upstream podría aceptar (kernel, DTS, BSP, fixes de arranque) se saca del centro y se
   manda como commits limpios a `odin3-pr`. Nuestro desarrollo (DeckStation, MAKO…) se queda en
   `odin3-sm8750`.

---

## 2. Requisitos de la máquina

- **Linux x86_64** (el build usa `chroot`, bind mounts y `qemu-aarch64-static`).
- **root** (sudo) — se instalan paquetes y se monta un chroot aarch64.
- **`qemu-user-static` / `qemu-aarch64-static`** (emulación aarch64).
- **~60 GB libres** (base ALARM 3,5 GB + chroot 1,5 GB + paquetes + rootfs + imagen 21 GB).
- **Conexión a internet** (base ALARM, fuentes del kernel, ROCKNIX).
- Recomendado: **≥8 núcleos**. El build usa `MAKEFLAGS=-j$(nproc)`; con 4 núcleos tarda mucho.

---

## 3. Compilar (paso a paso)

```bash
# --- 1. los dos repos nuestros ---
mkdir -p ~/odin3 && cd ~/odin3
git clone -b odin3-sm8750 https://github.com/arcadematicas/pocknix-os
git clone https://github.com/arcadematicas/pocknix-odin3-support

# --- 2. el checkout de ROCKNIX (NO está en nuestros repos) ---
git clone --depth 1 https://github.com/ROCKNIX/distribution
export DISTRIBUTION_DIR=~/odin3/distribution

# --- 3. aplicar NUESTRO contenido al árbol de compilación ---
pocknix-odin3-support/tools/sync-to-os.sh
pocknix-odin3-support/tools/check-sync.sh        # debe decir OK

# --- 4. vendorizar ROCKNIX (kernel, parches, firmware del SoC) ---
cd pocknix-os
DEVICE=sm8750 make sync

# --- 5. kernel -> paquetes+rootfs -> imagen ---
DEVICE=sm8750 JOBS=$(nproc) make kernel
DEVICE=sm8750 make build
DEVICE=sm8750 make sd-image
```

Al terminar: **`build/image/sm8750/pocknix-sm8750-sd.img`** (~21 GB).

### Grabar a la microSD

```bash
lsblk                                     # identifica la tarjeta (¡no te equivoques!)
sudo umount /dev/sdX1 /dev/sdX2 2>/dev/null
sudo dd if=build/image/sm8750/pocknix-sm8750-sd.img of=/dev/sdX bs=4M conv=fsync status=progress
sudo sync
```

⚠️ La imagen arranca con root de ~20 GB y `pocknix-expand-root` **la expande hasta llenar la
tarjeta** en el primer arranque. Aviso `partprobe` de "espacio sin usar" es **normal**.

---

## 3-bis. DESARROLLAR SIN REFLASHEAR (el flujo del día a día)

Flashear la imagen entera (~30-45 min) **solo** hace falta para distribuir o para una
instalación desde cero. Para iterar sobre el sistema hay vías mucho más rápidas:

| Cambio | Cómo | Tiempo |
|---|---|---|
| Scripts, configs, unidades systemd | `tools/push-file.sh <fichero-del-centro> <ruta-en-la-odin>` | **segundos** |
| Un paquete nuestro (BSP, decky, tools, gamescope…) | `tools/deploy-to-device.sh <paquete>` | **minutos** |
| Kernel | paquete `linux-pocknix-sm8750` (mismo deploy) + el bootloader | minutos |
| Imagen completa | solo para distribuir / instalar de cero | ~30-45 min |

```bash
# ejemplo: cambio en un daemon -> probarlo en la consola en 10 segundos
tools/push-file.sh packages/pocknix-bsp-sm8750/oled-care/oled-care-daemon.py \
                   /usr/local/bin/oled-care-daemon.py \
                   RELOAD="systemctl try-restart oled-care-daemon.service"

# ejemplo: cambio en el paquete BSP -> compilarlo e instalarlo en caliente
tools/deploy-to-device.sh pocknix-bsp-sm8750
```

La Odin se alcanza en `deck@192.168.4.29` (contraseña por defecto `pocknix`; se le instala
la clave pública con `ssh-copy-id`). **Cada imagen nueva cambia las claves de host**, así que
la primera conexión pide `ssh-keygen -R 192.168.4.29`.

⚠️ **Regla de oro también aquí**: se edita SIEMPRE en `pocknix-odin3-support`. Lo que se
prueba en caliente en la consola tiene que estar en el centro y commiteado, o se pierde en la
siguiente imagen (es exactamente cómo se perdieron el OOBE, los daemons y el `oled-refresher`).

## 4. Qué hace el build (para entenderlo)

```
make sync     vendoriza ROCKNIX -> vendor/rocknix-sm8750 (gitignored, 62 MB)
              + kernel/sm8750/patches/10-mainline (parches ROCKNIX)
make kernel   extrae linux-7.2.4, aplica kernel/sm8750/patches/*/ EN ORDEN NUMÉRICO
              05-speedup (22) -> 10-mainline -> 20-sm8750 -> 30-version
              -> build/kernel/sm8750/out/{Image,KERNEL,dtbs,modules}
make build    build-packages.sh (chroot aarch64 + qemu) -> build/localrepo
              build-image.sh   -> build/rootfs (pacman instala los paquetes)
make sd-image build-sd-image.sh -> build/image/sm8750/pocknix-sm8750-sd.img
```

- **`MAKEFLAGS`**: `build-packages.sh` lo fija a `-j$(nproc)` en el `makepkg.conf` del chroot.
  El tarball de ALARM lo trae **comentado**, y sin esto `make` va en serie (medido: kernel 40 min
  en vez de 5; gtk2/plasma-mobile/dolphin 3 h en vez de ~30 min).
- **Emulación**: la capa de emulación de upstream es **opt-in** y sus paquetes se **saltan**
  (varios no compilan bajo qemu: `azahar` muere con un ICE de gcc, `armsx2-bin` da 404). Para
  hornearla: `POCKNIX_EMULATION=1 make build`.
- **DeckStation/WProton** son NUESTRA capa y siempre van (`deckstation-arm`, `wproton-arm`).

---

## 5. Problemas conocidos

| Síntoma | Causa / arreglo |
|---|---|
| `mkinitcpio: failed to detect root filesystem` | `scripts/lib.sh` debe bind-montear la raíz del chroot sobre sí misma (`mount --bind $root $root`). Ya está. |
| `gamescope` no se reconstruye | `packages/soc/gamescope/socs` debe listar `sm8750`; `build-packages.sh` salta los paquetes de `packages/soc/` cuyo `socs` no incluya el SoC. |
| El kernel no se reconstruye | Faltan `packages/soc/linux-pocknix-sm8750/` y `pocknix-bootloader-sm8750/` (paquetes *thin* que empaquetan la salida de `make kernel`). |
| `warn patch conflict (skipping): 0055/0062` | Los dos parches de backlight `aw99706` chocan con `0056`/`0057`. Benigno, pero el "apagar pantalla por software" puede no estar. |
| `warn patch conflict: 0062-imon-pad / 9900 / 9901` en `30-version` | Están DUPLICADOS en `10-mainline` (idénticos). Inofensivo. |
| `azahar`/`armsx2-bin`/`es-de` fallan | Emulación opt-in. Se saltan solos salvo `POCKNIX_EMULATION=1`. |
| `bootanimation-odin3.zip` (105 MB) no está en git | No lo referencia nadie. Si quieres animación de arranque, cópialo a `pocknix-os/overlay/`. |

---

## 6. Sincronizar con upstream (mantener el sistema al día)

```bash
cd pocknix-os
git fetch origin
git checkout -b sync/upstream-<tag> odin3-sm8750
git -c merge.renames=false merge origin/main     # sin renames: evita conflictos falsos
# resolver conflictos (ver la sección de abajo), verificar el build y luego:
git checkout odin3-sm8750 && git merge --ff-only sync/upstream-<tag>
git push arcadematicas odin3-sm8750
```

**Por qué `-c merge.renames=false`**: sin eso git empareja ficheros de `pocknix-emulation` con
los nuestros de `deckstation-arm` y genera conflictos que no existen.

**Conflicto típico — la capa de emulación**: upstream la mantiene y la hace opt-in; nosotros
teníamos DeckStation en su lugar. La política es: **restaurar los paquetes de upstream** (quedan
opt-in, no se instalan) y **añadir DeckStation encima**. Ver el commit `a543f72`.

---

## 7. Contribuir a upstream (PR #81)

- El PR **#81** (`odin3-pr` → `shuuri-labs/pocknix-os`) manda el **soporte del Odin 3**: kernel
  7.2 + DTS + 71 parches + BSP + paquete del kernel + bootloader + fixes de OOBE.
- Está **abierto** y el mantenedor lo está revisando. Está en **CONFLICTING** desde que upstream
  publicó v0.4 → habrá que rebasearlo.
- **`odin3-pr` no se toca** mientras el mantenedor revise. Cuando responda: rebase + sus cambios
  en un solo push.
- Para sacar algo del centro a upstream: copiar los ficheros a una rama limpia partiendo de
  `origin/main`, con commits pequeños y mensajes en el estilo del repo.
