# Cierre 2026-10-16 — Publicación de la deuda de paquetes a R2

**Fecha:** 2026-10-16 · **SoC:** `sm8750` · **Bucket:** `https://pub-fd47305874674bf597b27eb7f880e73b.r2.dev`
**Firma:** `pocknix-repo@arcadematicas` · **Centro:** `master` · **Árbol PC:** `odin3-sm8750`

## 1. Resumen

Se publicó la deuda de paquetes en los dos repos R2 (`r2:pocknix/shared` y `r2:pocknix/sm8750`):
**12 paquetes**, verificados **frescos** tras el publish:

- HTTP `200` en cada `.pkg.tar.*` **y** en su `.sig` → **12/12**.
- GPG: **12/12** `Firma correcta de "pocknix-repo@arcadematicas"`.
- `.db`/`.files`/`.pub`: `pocknix-shared.db(+sig)` `200` · `pocknix.db(+sig)` `200` ·
  `pocknix.files` `200` · `pocknix-base.db` `200`.

`tools/check-published.sh` pasa de **24** a **12** de 81 paquetes sin publicar (§4).

## 2. Publicado (12)

### `r2:pocknix/shared` (8)

| Paquete | Versión |
|---|---|
| `deckstation-arm` | `1.0.0-17` |
| `pocknix-branding` | `0.1.0-3` |
| `pocknix-core` | `0.1.0-5` |
| `pocknix-decky` | `0.1.0-53` |
| `pocknix-session` | `0.1.0-5` |
| `pocknix-steam` | `0.1.0-68` |
| `pocknix-turnip-x86` | `20261009-1` |
| `pocknix-vk-valve` | `20261013-1` |

### `r2:pocknix/sm8750` (4)

| Paquete | Versión |
|---|---|
| `fex-emu` | `2610.20261007.14c92681-1` |
| `gamescope` | `1:3.16.31.ogc1.20260928.afd6eac6-1` |
| `linux-pocknix-sm8750` | `7.2.10-1` |
| `mangohud` | `0.8.4-1` |

> `gamescope` trae **el arreglo del HDR/QAM**; `fex-emu` el salto `2608 → 2610`;
> `mangohud` `0.8.3-6 → 0.8.4-1`; el kernel sube a **7.2.10** (el que corre la Odin).

## 3. Diagnóstico: por qué `make packages` fallaba (RESUELTO)

Los runs morían con `rc=2` a los ~60 s tras el `-Syu`, y **no era el paquete**:

1. **Locks huérfanos** — los runs matados dejaban `build/localrepo/*/*.lck` y `repo-add`/`pacman`
   se negaban a operar. *Fix:* `rm -f build/localrepo/*/*.lck` antes de cada run.
2. **`DEVICE` descartado por `sudo`** — `config/pocknix.conf:21` define `: "${DEVICE:=sm8550}"`
   y `sudo env DEVICE=… make …` no lo propaga → todo iba al SoC equivocado.
   *Fix:* forma VAR=value de sudo: `sudo -A DEVICE=sm8750 make packages PKG="…"`.
3. **Montajes duplicados** del chroot apilados por runs previos. *Fix:* `umount -R` de ambos
   chroots antes de reanudar.
4. **Falsa alarma de "cuelgue"** — el `repo-add` inicial del `setup_chroot` corre bajo
   `qemu-aarch64-static` y tarda **~7,5 min**; no se cuelga.

Con esto, `make packages` completó los runs limpios (y `libretro-azahar`, un build C++ de
1732 pasos bajo qemu, terminó sin incidencias a las 17:43).

## 4. Bloqueado (no publicado) y causa raíz

`tools/check-published.sh`: **12 de 81** siguen sin publicar. **Ninguno es un fallo de
compilación**: el gate `scripts/stage-check.sh` (o su resolución de dependencias) los rechaza.

| Paquete | Causa raíz |
|---|---|
| `libretro-azahar-2126.1.2-1` | **Compilado OK** (17:43). El gate lo rechaza: `FAIL … NEW name that no root depends on`. `pocknix-emulation-full` (live) no depende de él — depende de `libretro-cores-pocknix` (set *vendored*), no de los cores compilados por nosotros. |
| `libretro-bsnes-hd-20251205-1` | **Compilado OK** (17:47). Igual: nuevo nombre que ninguna raíz alcanza. |
| `vboycolor-libretro-1.0.0.beta.11-1` | oRFANO real: sin dependientes y no listado en ningún `.list`. |
| `hexagonrpc-0.5.0-2`, `libqrtr-1.2-1`, `msm-firmware-loader-1.8.0-2`, `pd-mapper-1.1-1`, `pocknix-sensors-config-20251206-2` | **La cadena de sensores del ADSP.** Se instala **sí** en el dispositivo vía `devices/sm8750/packages.list` (verificado el 15/10), pero el "reach" del gate (BFS por `depends`+`optdepends` desde las raíces) **no modela `packages.list`** → los marca oRFANOS. |
| `pocknix-bsp-sm8750-0.2.0-9` | **Compilado**, pero su `depends` incluye `pocknix-system-overlay`, ausente de `stage`/`shared`/`base` → falla el `resolve` del gate. |
| `pocknix-system-overlay-0.1.0-2` | Duplicado en el árbol (`packages/shared/pocknix-system-overlay` **y** `packages/pocknix-system-overlay`). El gate lo marca `NEW name que ninguna raíz alcanza` porque **el `pocknix-bsp-sm8750` LIVE aún no depende de él** → **deadlock cross-repo**: no se publica el overlay sin publicar antes el bsp que lo referencia, y el bsp nuevo no pasa el `resolve`. |
| `pocknix-desktop-0.1.0-31` | Exige `pocknix-bsp-common>=0.1.0-22` pero el árbol solo produce **-19**; además pide `pocknix-desktop-flavour` (lo `provides` `pocknix-desktop-plasma-mobile`/`-plasma`, ausentes del repo live). **Inconsistencia dura del árbol.** |
| `pocknix-emulation-0.1.0-17` (+ `-full`) | Capa de emulación de upstream: **no la usamos** (DeckStation es nuestra capa) y su build muere en `eden-qt-config.ini.in`. |

### 🔴 La decisión que falta (una sola, desbloquea 8 paquetes)

**El gate `stage-check` no modela `devices/<soc>/packages.list`.** Ese fichero es la vía real de
instalación de un puñado de paquetes legítimos (toda la **cadena de sensores** del ADSP, los
**cores libretro** compilados por nosotros, etc.) y el reach solo recorre `depends`+`optdepends`,
así que los ve como oRFANOS y no los deja publicar. **No hay waiver**:
`POCKNIX_STAGE_CHECK_*` sólo tiene `SOCS`, `OFFLINE` y `TEMP_DROP`.

Arreglarlo es **tocar el grafo o el gate**, o sea **decisión del dueño** — no se ha parcheado
nada. Dos opciones (para discutir, no implementadas):

1. **Gate**: que el reach añada como aristas los `packages.list` del SoC
   (`devices/<soc>/packages.list`) además de `depends`+`optdepends`.
2. **Metapaquete**: que `pocknix-device-<soc>` declare en `depends` los paquetes de
   `packages.list` (hoy depende de una lista fija — BSP, kernel, bootloader, protones — y el
   resto los instala `build-image.sh`, no el meta). Ojo: los comentarios del PKGBUILD hoy
   prohíben meter capas opcionales ahí (`pacman -Rs`).

Mientras tanto, **todo lo bloqueado queda compilado y verificado, listo para stage en cuanto se
decida**, y el resto del repo sigue consistente (se publicó sólo lo que pasó el gate).

## 5. Reproducir la publicación

```sh
# 1) build (en el PC; SUDO_ASKPASS activo; DEVICE como VAR=value de sudo)
rm -f build/localrepo/*/*.lck
sudo -A DEVICE=sm8750 make packages PKG="<nombres>"

# 2) stage + gate de consistencia (como USUARIO, no root)
POCKNIX_STAGE_CHECK_SOCS=sm8750 make stage-shared PKG="<nombres>"
POCKNIX_STAGE_CHECK_SOCS=sm8750 make stage        PKG="<nombres>"

# 3) publicar + verificar
make publish-shared && make publish
tools/check-published.sh                     # deuda: 12 de 81
curl -fsSIL -o /dev/null -w '%{http_code}\n' "$URL/<seg>/<pkg>"
gpg --verify <pkg>.sig <pkg>                 # en este PC el mensaje sale en español: "Firma correcta"
```

> `POCKNIX_STAGE_CHECK_SOCS=sm8750` es **obligatorio**: el bucket sólo tiene los segmentos
> `sm8750`, `shared` y `base` (no existe `sm8250`/`sm8550`) y sin esa variable el check muere
> buscando la BD de otro SoC.

## 6. Notas de operación

- **Nombres de las BD en R2 (no son obvios)**: el segmento `sm8750` publica `pocknix.db`
  (+ `.files`, + `.sig`), **no** `pocknix-sm8750.db`; el segmento `shared` publica
  `pocknix-shared.db`. El `base` publica `pocknix-base.db`. Comprobar con
  `rclone lsf r2:pocknix/<seg>`.
- **Arquitecturas en los nombres**: `pocknix-turnip-x86` y `pocknix-vk-valve` se publican como
  **`-aarch64`** (aunque sean payload x86 para FEX), no `-any`. Buscar el nombre real antes de
  dar un `404` por fallo.
- **Dedupe** de 5 artefactos duplicados en `build/localrepo/shared`: `msm-firmware-loader-1`,
  `pocknix-steam-57`, `fex-emu-2608`, `gamescope-29`, `mangohud-0.8.3-6`.
- El flujo stage/publish quedó entendido y documentado: `stage-repo.sh` hace `rclone sync`
  LIVE→`build/stage/<seg>` y sustituye **sólo** lo nombrado; `stage-check.sh` retira el marker si
  falla; `publish-repo.sh` firma + `repo-add --sign` + `rclone copy` (y exige `.staged-ok`).
  Tras el publish, los `.staged-ok` quedan **consumidos**.
- `libretro-azahar` y `libretro-bsnes-hd` ya tienen artefacto en `build/localrepo/shared`
  (8,1 MB y 577 KB): **no hay que recompilarlos**, sólo pasarlos por el gate cuando se decida §4.

## 7. Pendiente inmediato

1. **Decisión del dueño** sobre §4 (modelar `packages.list` en el reach, o aristas en el meta) →
   desbloquea **8** paquetes: cadena de sensores (5) + los 2 cores libretro + `vboycolor-libretro`.
2. `pocknix-bsp-sm8750-0.2.0-9` ↔ `pocknix-system-overlay-0.1.0-2`: resolver el **deadlock
   cross-repo** (publicar el overlay y el bsp en el mismo `stage`, o decidir el orden) y el
   **duplicado** del PKGBUILD del overlay.
3. `pocknix-desktop-0.1.0-31`: recompilar `pocknix-bsp-common` a `pkgrel>=22` (o subir el
   `>=22` del `depends`) y confirmar dónde vive `pocknix-desktop-flavour`.
