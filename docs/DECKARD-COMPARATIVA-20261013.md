# Comparativa Deckard: gamescope 3.16.30-4 y Mesa x86_64 (FEX) vs. nuestro stack

- **Fecha:** 2026-10-13
- **Tarea:** A5 del roadmap Odin 3.
- **Objetivo:** decidir **con evidencia** si merece la pena portar a la Odin 3 (a) el gamescope
  `3.16.30-4` (aarch64) de Valve y (b) el shard Mesa x86_64 (lado FEX) de Valve.
- **Alcance:** descarga, inspección de contenido, comparación con lo nuestro y veredicto por
  paquete. **No se ha instalado, modificado ni commiteado nada.**

> ⚠️ **Salvedad de hardware (obligatoria):** todos estos paquetes de Valve están construidos para
> **Deckard / Adreno 750 (SM8650)**. Nuestra Odin 3 es **Adreno 830 (SM8750)**. Cualquier
> afirmación de rendimiento o compatibilidad de este informe es **estática** (contenido, versiones,
> strings, DT_NEEDED); **el comportamiento real tiene que verificarse en la Odin**.

---

## 1. Metodología

Descarga directa desde el repo inmutable de Valve:
`https://holo-packages.steamos.cloud/archlinux-deckard-hotfixes/`
(nombres exactos con `%2B`, sin `.sig`). Extracción con `bsdtar`/`tar --zstd` en
`/tmp/opencode/deckard-cmp/x/`.

### 1.1 Paquetes descargados (tamaño en disco y sha256)

| # | Fichero descargado | Bytes (.pkg.tar.zst) | sha256 |
|---|---|---:|---|
| A | `gamescope-3.16.30-4-aarch64.pkg.tar.zst` | 2.384.046 | `493a6d4366a1e21a5fa00c2c34e3b7756bec2ef12b579af918344fbe09da24f9` |
| B | `deckard-mesa-linux-aarch64-26.3.0_devel%2Bgite07916b4-5-aarch64.pkg.tar.zst` | 19.334.706 | `c30eb810cf537e839f5b7ff66b1088e3c29cf67e17bcbf44856b3ac38064b7cb` |
| C | `deckard-mesa-linux-x86_64-26.3.0_devel%2Bgite07916b4-5-aarch64.pkg.tar.zst` | 34.164.232 | `7358c5af92a3b410b6bea4a0674ec18aefc2b277d3abdcd550d81efebdd7ab60` |
| D | `deckard-mesa-linux-deps-x86_64-20260820-4-aarch64.pkg.tar.zst` | 285.369.953 | `91ca10ed81e33dc3801e795506948628e5a48233beaab911b4f30446c7368467` |

### 1.2 Tamaño instalado y nº de ficheros (árbol extraído)

| Paquete | Ficheros | Instalado (bytes) | `size` del `.PKGINFO` |
|---|---:|---:|---:|
| A gamescope-3.16.30-4 | 42 (+11 dirs = 53 miembros) | ~5.1 MB | 5.123.403 |
| B mesa-aarch64 gite07916b4-5 | 58 | 74.521.391 | 74.503.895 |
| C mesa-x86_64 gite07916b4-5 | 72 | 141.641.245 | 141.622.274 |
| D deps-x86_64 20260820-4 | 7.532 | 850.803.204 | 850.462.129 |

Referencias de "lo nuestro" usadas en las comparativas:

- gamescope propio: `packages/soc-overrides/gamescope` → **3.16.29.ogc2.20260918.4b50dd7**,
  fork OpenGamingCollective + **19 parches armada** (0101–0121) + 3 propios (0009/0010/0011).
- Turnip aarch64 propio: **`pocknix-vk-valve`** hoy fija el shard Valve **`gite07916b4-1`**
  (sha `1bc065a1…`).
- Turnip x86 propio: **`pocknix-turnip-x86` 20260904**, `_versions` con máximo **26.2.2-1**;
  **`fex-rootfs`** embebe la misma a `_mesaver=26.2.2-1` y publica `vk-x86-container.list`.
- Mecanismo guestos: `pocknix-guestos-mount` monta nuestro FEX rootfs en
  `/usr/share/guestos/fex-mesa` con un `graphics_provider.json` mínimo.

---

## 2. (A) gamescope 3.16.30-4 (aarch64)

### 2.1 `.PKGINFO` de ambos gamescope

| Campo | Valve 3.16.30-4 | Nuestro 3.16.29.ogc2 |
|---|---|---|
| `pkgbase` | `gamescope` | `gamescope` (soc-override) |
| `pkgver` | `3.16.30-4` | `3.16.29.ogc2.20260918.4b50dd7-1` |
| `arch` | `aarch64` | `aarch64` |
| `size` | 5.123.403 | — |
| `license` | `MIT` | `MIT` |
| build | `makepkg 7.1.0` (valve) | chroot propio |
| **version string del binario** | `3.16.30 (gcc 15.2.1)` | `3.16.29.ogc2…` |

**Dependencias runtime de Valve 3.16.30-4** (del `.PKGINFO`):
`xorg-xwayland, libavif, aom, rav1e, libxres, xcb-util-errors, freerdp, xcb-util-wm,
libxcomposite, pixman, libinput, seatd, pipewire, libxmu, libxcursor, libdecor, libei, luajit, libdrm`.

Frente a nuestra lista, **lo nuestro ya trae `luajit` y `libdecor`**, pero Valve añade runtime nuevo:
**`libavif`+`aom`+`rav1e`** (captura AV1), **`freerdp`**, **`libei`** (input emulation) y
`xcb-util-errors`. En nuestra `config/packages/base.list` **no aparecen** (`libavif`, `aom`, `rav1e`,
`freerdp`, `libei`, `libeis`, `lcms2`): serían **dependencias nuevas de base** (aunque `luajit`/
`libdecor` ya están cubiertas como deps del gamescope propio).

### 2.2 Contenido (listado completo, 53 miembros)

```
usr/bin/gamescope                         3.340.040
usr/bin/gamescopectl                        118.696
usr/bin/gamescopereaper                     120.312
usr/bin/gamescopestream                     205.184
usr/bin/gamescope-type                       11.088
usr/bin/steamos-session-shell                   187
usr/lib/libVkLayer_FROG_gamescope_wsi_aarch64.so 165.368
usr/share/vulkan/implicit_layer.d/VkLayer_FROG_gamescope_wsi.aarch64.json
usr/share/gamescope/reshade/... (Lilium HDR .fx/.fxh + Textures, ~1.1 MB)
.INSTALL  ->  setcap 'cap_sys_nice=eip' /usr/bin/gamescope
```

Lo relevante:

- **No hay `usr/share/gamescope/scripts/` ni ningún `.lua`.** Es gamescope upstream pelado.
- Trae **ReShade/Lilium** (shaders + texturas HDR) que nosotros no empaquetamos.
- `libVkLayer_FROG_gamescope_wsi_aarch64.so`: la WSI layer de gamescope para FEX/guest.

### 2.3 ¿Tiene nuestros parches armada/Odin3?

Comprobación por `strings` del binario `usr/bin/gamescope`:

| Marca esperada (parche nuestro) | Valve 3.16.30-4 |
|---|---|
| `GAMESCOPE_INTERNAL_DEVICE_ID` (0102/0103 paneles sin EDID) | **AUSENTE** |
| `has_edid` / `device_id` (perfil lua armada) | **AUSENTE** |
| `gamescope.eotf` / `GAMESCOPE_HDR_ENABLED` (HDR gamma22 0104) | **AUSENTE** |
| `armada` (perfil `ayn.icna3520.oled.lua`) | **AUSENTE** |
| `GAMESCOPE_PATCHED_EDID_FILE` | presente |
| `GAMESCOPE_COMPOSITE_FORCE` (0011 force-composition) | presente (env de upstream, **no** nuestra lógica de no-cancelación) |
| `--mangoapp` | presente |
| `--force-composition-rotation` | presente (2) |
| EDID sintético / scripts lua | **AUSENTE** |

**Conclusión:** el gamescope de Valve **NO lleva nuestra pila armada**:

- **0102/0103** (EDID sintético para paneles internos sin EDID + perfiles conocidos): ausentes →
  nuestro perfil `10-armada/ayn.icna3520.oled.lua` (que depende de `display.device_id`,
  `display.has_edid`, `gamescope.eotf.gamma22`) **no podría enganchar el panel de la Odin**.
- **0104/0105/0106/0107/0110/0118** (HDR gamma22 sin HW color mgmt, filtrado de formatos WSI,
  SDR white, metadata): ausentes → se pierde HDR por software.
- **0009** (persistencia del átomo fps-limit): ausente.
- **0010** (rotated-output-max-height): ausente.
- **0011** (force-composition no cancelado por propiedad X): ausente.
- **0118** (virtual white ARM64) / **0101** (fallback appid focus): ausentes.

### 2.4 Veredicto (A)

| Paquete | Versión | Contenido | vs. nuestro 3.16.29.ogc2 | Veredicto | Riesgo |
|---|---|---|---|---|---|
| gamescope-3.16.30-4 | 3.16.30-4 | upstream pelado + FROG WSI + ReShade | **pierde los 19 parches armada + HDR sin EDID + 0009/0010/0011** | **NO** | **ALTO** |

**NO.** Adoptarlo como gamescope base supondría perder el HDR del panel de la Odin (perfil armada
sin EDID), la persistencia del fps-limit y los fixes de rotación/force-composition. Además añade
runtime (`libavif`/`aom`/`rav1e`/`freerdp`/`libei`) que no están en nuestra base. Su único aporte
diferencial (ReShade/Lilium, session-shell, FROG WSI) o ya lo tenemos o no justifica perder la pila.

---

## 3. (B) deckard-mesa-linux-aarch64 gite07916b4-5

Es el shard del Turnip aarch64 (el build que ya vendemos en `pocknix-vk-valve`, hoy pinneado a
`-1`).

| Dato | Valor |
|---|---|
| pkgver | `26.3.0_devel+gite07916b4-5` |
| commit | `e07916b4` (`git-e07916b45f`) |
| Turnip `.so` | `usr/lib/libvulkan_freedreno.so`, **18.857.136 B** |
| sha256 Turnip | `6bed18a0a9d59fc0132766947f1c2657b50c4188776f718cfdf723cf8dd7b4ee` |
| version string | `Mesa 26.3.0-devel (git-e07916b45f)` |
| `dri/` | **solo `libdril_dri.so`** — **NO `msm_dri.so`, NO `swrast`, NO `kms_swrast`** |

**vs. nuestro `pocknix-vk-valve` (hoy `-1`, sha `1bc065a1…`):** mismo commit de mesa
(`e07916b4`), solo cambia el `pkgrel` (`-1`→`-5`). Es un **refresco del pin de versión**.

- El hecho de que **siga sin `msm_dri.so`** confirma que la **Opción 1 (reemplazar el Mesa del
  sistema) sigue descartada** por el mismo motivo de `docs/PRUEBAS-MESA.md`.
- Este shard **NO toca el hardware del Odin por sí mismo**: son bytes; el build es para
  **Adreno 750/SM8650**, y el nuestro es **830/SM8750** → verificar en la Odin antes de coronar
  como "sin riesgo".

| Paquete | Versión | Contenido | vs. nuestro | Veredicto | Riesgo |
|---|---|---|---|---|---|
| mesa-aarch64 gite07916b4-5 | 26.3.0-devel | Turnip + libdril (sin msm/swrast) | **mismo commit**, `pkgrel -1→-5` | **SÍ** (refresco de pin, bajo coste) | BAJO (verificar en HW) |

---

## 4. (C) deckard-mesa-linux-x86_64 gite07916b4-5 (lado FEX)

### 4.1 Naturaleza: **NO es un payload ICD**

El paquete **no instala un driver Vulkan suelto** como hace nuestro `pocknix-vk-valve`. Instala
todo bajo **`/usr/share/guestos/fex-mesa/`** y se declara como **graphics-provider shard** con:

```json
// usr/share/guestos/fex-mesa/graphics_provider.json
{ "graphics_provider_v0": { "root": "./", "locales": false,
    "architectures": {
      "x86_64-linux-gnu": { "dri": "/usr/lib/dri",  "fallback_library_paths": ["/usr/lib"],  "gconv": "/usr/lib/gconv" },
      "i386-linux-gnu":   { "dri": "/usr/lib32/dri","fallback_library_paths": ["/usr/lib32"],"gconv": "/usr/lib32/gconv" } } } }
```

Es decir, **reemplaza la capa gráfica del guest x86** (Mesa x86_64 + lib32 completos), no solo el ICD.

### 4.2 Contenido

- 72 ficheros, **141,6 MB** instalados. x86_64 y `lib32` en paralelo.
- `usr/lib/libvulkan_freedreno.so` (**Turnip x86_64, 19.138.320 B**):

| Dato | Valor |
|---|---|
| sha256 | `f237b35ccad20c7b5c7a3acd57e43ad020e247332f8d48c125344299b0371d97` |
| version string | `Mesa 26.3.0-devel (git-e07916b45f)` |
| ISA | x86_64, "Adreno (TM) 830" en strings |
| ICD | `usr/share/vulkan/icd.d/freedreno_icd.x86_64.json` → `api_version 1.4.362`, `library_path: /usr/lib/libvulkan_freedreno.so` |
| DT_NEEDED | libzstd, libdrm, libxcb-dri3/present/xfixes/sync/randr/shm, libxshmfence, **libdisplay-info.so.3**, libudev, **libSPIRV-Tools.so**, libexpat, libstdc++, libc… |
- Soporte GL/EGL/gbm: `libgallium-26.3.0-devel.so`, `libEGL_mesa`, `libGLX_mesa`, `libgbm`,
  `liblua`, `libfreedreno_noop_drm_shim.so`.
- `usr/lib/dri/`: `libdril_dri.so` + screens **kmsro** (armada-drm, sun4i, vkms, zink…) como
  symlinks; **NO hay `msm_dri.so`**.
- `vulkan/icd.d/` para x86_64 **y** lib32; `implicit_layer.d/VkLayer_MESA_vram_report_limit.json`.

### 4.3 ¿Drop-in como `pocknix-vk-valve`? — **NO**

| Aspecto | Nuestro `pocknix-vk-valve` | Deckard x86_64 shard |
|---|---|---|
| Qué instala | **solo** el ICD + `icd.json` reescrito bajo `/usr/share/pocknix/vk-arm/<ver>-valve/` | árbol `guestos/fex-mesa` completo (GL/EGL/gbm/dri/icd + lib32) |
| Alcance | conmutable por juego | **reemplaza la capa gráfica del guest** |
| `library_path` | reescrito al payload | `/usr/lib/…` (asume ser el provider del root) |
| Extra | 1 `.so` (~19 MB), alias `libdisplay-info.so.1` | ~141 MB + **necesita el shard de deps (§5)** |

**vs. nuestro `pocknix-turnip-x86` 20260904 (máx. 26.2.2):** Valve trae **26.3.0-devel
gite07916b4**, un salto de serie (26.2 → 26.3) y del **mismo commit** que el Turnip aarch64 que ya
usamos y que dio **+13.4 %** en la Odin (`docs/PRUEBAS-MESA.md`). El binario **soporta "Adreno
830"** en strings. Su `libdisplay-info.so.3` **coincide con la soname que ya usamos**, así que en
el rootfs x86 no hay el problema de alias `.so.1` que sí tuvimos en aarch64.

### 4.4 Veredicto (C)

| Aspecto | Veredicto | Riesgo |
|---|---|---|
| Shard completo como sustituto de nuestro mecanismo x86 | **NO** | ALTO |
| Extraer **solo** el `libvulkan_freedreno.so` x86_64 de 26.3.0-devel | **CON DUDAS** | MEDIO |

**NO como drop-in**: no es un payload ICD, es un reemplazo de la capa gráfica del guest (141 MB +
exige el shard de deps) construido para el stack guestos de Valve, no para nuestro `fex-rootfs`.
Replicar ese mecanismo supondría adoptar todo el modelo `graphics_provider.json` de Valve.

---

## 5. (D) deckard-mesa-linux-deps-x86_64-20260820-4

| Dato | Valor |
|---|---|
| pkgver | `20260820-4` |
| Ficheros / instalado | **7.532 / 850,8 MB** |
| Ruta | **todo** bajo `/usr/share/guestos/fex-mesa/` (se **funde en el mismo árbol** que C) |
| Contenido | userland x86_64 SteamOS completo: `usr/lib` (1304), `usr/lib32` (979), `usr/bin` (377), `etc/ssl`, `pam`, `security`, `var` |
| Incluye | glibc, libstdc++, libdrm, libwayland, **libdisplay-info.so.3** (soname coincide con la nuestra), **libvulkan.so.1.4.321**, familia libGL |
| Conflictos con host | **ninguno**: confinado al shard (no pisa rutas del host) |

**Qué añade:** son las **dependencias del shard C** (el runtime x86 que el `libvulkan_freedreno`
x86_64 y la capa GL del guest necesitan). No aporta nada al host aarch64.

**¿Chocan sus libs con las nuestras?** No por ruta (todo en `guestos/fex-mesa`), pero **sí
engordaría el rootfs** en ~850 MB y **duplicaría** un userland x86 que en gran parte ya tenemos
embebido en `ArchLinux.sqsh` (glibc/pdf de FEX). Es un **bundle de conveniencia del modelo Valve**,
no un incremento de capacidad que necesitemos.

### 5.1 Veredicto (D)

| Paquete | Versión | Contenido | vs. nuestro | Veredicto | Riesgo |
|---|---|---|---|---|---|
| deps-x86_64 20260820-4 | 20260820-4 | userland x86 deps del shard (850 MB, todo en `guestos/fex-mesa`) | duplica lo que ya embebemos en `fex-rootfs` | **NO** | MEDIO (espacio/duplicación, sin conflicto de rutas) |

---

## 6. Plan concreto (si se decide tirar de algo) — **sin implementar**

De los cuatro, lo **único con valor real** es (B) el refresco del pin y el `libvulkan_freedreno.so`
x86_64 de 26.3.0-devel de (C). Propuesta mínima, replicando el patrón ya probado:

1. **(B) Refrescar `pocknix-vk-valve` a `-5`**
   - `pocknix-odin3-support/packages/pocknix-vk-valve/PKGBUILD`: `_valve_pkg` → `…gite07916b4-5…`
     y `sha256sums=('c30eb810…')`.
   - (Lo mismo que la actualización A3 del shard aarch64.)

2. **(C) Extraer solo el ICD x86_64 de Turnip 26.3.0-valve y tratarlo como payload**
   - Origen: `deckard-mesa-linux-x86_64-…gite07916b4-5…` →
     `usr/share/guestos/fex-mesa/usr/lib/libvulkan_freedreno.so` (sha `f237b35c…`).
   - Payload nuevo (p. ej. `pocknix-vk-valve-x86`) que instale
     `/usr/share/pocknix/vk-x86/26.3.0-valve/libvulkan_freedreno.so` + `icd.json` **reescrito**
     (library_path al payload, como hace `pocknix-vk-valve` en aarch64).
   - Alternativa: embeberlo como `26.3.0-valve` en `fex-rootfs` (`_mesaver` / `_vkvers` +
     `vk-x86-container.list`) para que `pocknix-proton-wrapper` lo acepte como SLR x86.
   - **Precondición dura:** verificar en la **Odin** que el binario (construido para Adreno
     750/SM8650) habla bien con la **830/SM8750** antes de proponerlo como opción de usuario.

3. **(A) gamescope:** **no portar**. Si en el futuro interesa ReShade/Lilium, tratarlo como
   *asset* extraíble, **no** como reemplazo del gamescope armada.

4. **(D) deps-x86_64:** **no adoptar**; mantener nuestro `fex-rootfs`.

---

## 7. Limpieza

`/tmp/opencode/deckard-cmp` (paquetes + árbol extraído + temporales) **se elimina al cerrar esta
tarea**. Los paquetes no se necesitan una vez registrados aquí sus tamaños y sha256.

---

## 8. Resumen final (veredicto por paquete)

| (a)/(b) | Paquete | Veredicto | Justificación en una línea |
|---|---|---|---|
| (a) | gamescope-3.16.30-4 | **NO** | Upstream pelado sin los 19 parches armada ni HDR sin-EDID; perdería el panel de la Odin y añade deps nuevas. |
| (b) | deckard-mesa-linux-aarch64 gite07916b4-5 | **SÍ** | Mismo commit que ya usamos, solo refresca el pin `-1`→`-5` (actualización de bajo coste). |
| (c) | deckard-mesa-linux-x86_64 gite07916b4-5 | **CON DUDAS** | Como shard drop-in **NO** (no es ICD, sino la capa gráfica del guest); su Turnip x86 26.3.0 sí es candidato a payload, **a verificar en la Odin**. |
| (d) | deckard-mesa-linux-deps-x86_64-20260820-4 | **NO** | 850 MB de userland x86 que duplica lo ya embebido en `fex-rootfs`; no aporta capacidad. |
