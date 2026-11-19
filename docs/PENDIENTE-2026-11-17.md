# Pendiente de actualización — 2026-11-17

Inventario sacado con `tools/check-published.sh`, `tools/check-upstream-packages.sh` y
`tools/check-armada-deckard.sh --dias 14`. El orden es el de ejecución: cada tanda se cierra
antes de abrir la siguiente.

## 0. Cerrar base + imagen (en marcha)
- [ ] `make build` despinnado
- [ ] `make packages` con `POCKNIX_FORCE_REBUILD=1`
- [ ] `make snapshot` (sube base, escribe lock, rota `base-prev`, mueve pin)
- [ ] `make build` pinneado
- [ ] `make sd-image`
- [ ] validar en SD: arranque, suspensión, audio, wifi, decky, juegos
- [ ] actualizar la Odin
- [ ] anotar el id de snapshot en `CHANGELOG.md`

## 1. Deuda de publicación (publicar lo ya probado)
| Paquete | Nuestra versión | Publicada |
|---|---|---|
| inputplumber | 0.84.0-1 | 0.83.0-1 |
| linux-pocknix-sm8750 | 7.2.15-4 | 7.2.15-2 |
| pocknix-decky | 0.1.0-73 | 0.1.0-72 |
| pocknix-desktop-kde | 0.1.0-4 | 0.1.0-3 |
| pocknix-emulation | 0.1.0-17 | 0.1.0-13 |
| pocknix-power-profiles | 0.1.0-1 | **nunca** |
| pocknix-turnip-x86 | 20261009-2 | 20261009-1 |
| suyu-libretro | 0.0.4-2 | 0.0.4-1 |
| retroarch-autoconfig-pocknix | 0.1.0-4 | 0.1.0-3 |
| retroarch-shaders-pocknix | 0.1.0-4 | 0.1.0-3 |

**Invertidos** (el repo tiene más nuevo que el árbol → re-sincronizar el árbol, NO publicar):
- `gamescope`: árbol `...-1`, repo `...-3`
- `pocknix-bsp-sm8750`: árbol `0.2.0-51`, repo `0.2.0-52`
- `pocknix-base`: árbol `0.2.0-8`, repo `0.2.0-10`

## 2. Bumps de pkgrel de upstream (scripts/config, riesgo bajo)
- [ ] pocknix-snapshots 6 → 10
- [ ] pocknix-lock-migrate 4 → 6
- [ ] pocknix-steam 76 → 80
- [ ] pocknix-steam-full 4 → 5
- [ ] pocknix-session 5 → 7
- [ ] pocknix-steamos-shim 9 → 10
- [ ] pocknix-tools 25 → 26
- [ ] pocknix-gamepad-calibration 2 → 5
- [ ] pocknix-homescreen 1 → 3
- [ ] pocknix-sdcard-automount 7 → 8

## 3. Versiones con código (riesgo medio)
- [ ] inputplumber 0.83 → 0.84 (va con la tanda 1)
- [ ] pocknix-decky 73 (AddGame) y pocknix-desktop-kde 4 (power profiles)
- [ ] pocknix-emulation 17
- [ ] turnip-x86 / suyu-libretro
- [ ] emuladores bin: rpcs3-bin, xemu-bin, vita3k-bin (cada uno engorda la imagen; decidir uno a uno)
- [ ] proton-cachyos / proton-ge (solo pkgrel)

## 4. Armada / Deckard — selectivo (riesgo medio)
Armada, últimos 14 días, áreas tocadas: `kwin`, `powerdevil`, `inputplumber`, `networkmanager`,
`mesa` (26.3.0 el 10/11), `gamescope-session`, `steamos-manager`, `kernel`.

Deckard (hotfixes diarios, 2.126 paquetes; último 17/11 18:48):
`deckard-mesa 27.0.0_devel` (ya alineados: turnip refrescado a mesa main 27.0),
`vulkan-layers 20261107`, `audio-config 20261117`, `hw-support 20261103`,
`linux-72-deckard`, `scx-scheds`, `mangohud`.

- [ ] vulkan-layers: ver si aporta algo en la Odin 3
- [ ] audio-config: solo si aparece problema de audio
- [ ] hw-support: diff antes de tocar
- [ ] scx-scheds / mangohud: evaluar
- [ ] **no** tragar el repo entero

## 5. Paquetes nuevos de upstream que cambian arquitectura — **PENDIENTE DE ESTUDIO**
`pocknix-ui`, `pocknix-store`, `steamos-manager`, `powerdevil`, `pocknix-kernel-guard`,
`pocknix-system-overlay`.

Fransis no los ha visto y no sabe qué cambian → **no se decide nada** hasta tener un estudio corto:
qué sustituyen, qué añaden o quitan en la Odin, y qué se pierde si no se adoptan.
Adelanto: `pocknix-ui` y `pocknix-store` parecen reemplazar piezas de interfaz y de gestión de
paquetes; `steamos-manager` y `powerdevil` van de sesión y energía.

## 6. Kernel — alto riesgo, al final y solo
`linux-pocknix-sm8750 7.2.15-4` está pendiente de publicar; `-5` si procede.
Historial a no repetir: 7.2.5/7.2.6 traían regresión de display (`dsi_calc_clk_rate_6g`, -22) y de
WiFi (`ath12k ... mhi POWER_ON`, -110). Probar en SD antes que en la interna.

## Reglas de la casa
1. Snapshot automático antes de cada transacción (`pocknix-snapshots`); si algo falla, `pocknix-rollback`.
2. `make stage-check` como puerta obligatoria.
3. Un paquete por commit, con `pkgrel` subido.
4. `check-published` limpio antes de dar una tanda por cerrada.
5. Probar en **SD** antes que en la interna.
6. Anotar cada cierre en `CHANGELOG.md`.

## Notas de la tanda 0 (18/11)
- **`libssc` 0.4.4-2 falla al recompilar** en el chroot nuevo: meson aborta con
  `Dependency 'gobject-introspection-1.0' tool variable 'g_ir_scanner' contains erroneous
  value: '/usr/bin/g-ir-scanner'` (gobject-introspection 1.86.0). No es fatal: el script
  conserva la compilación anterior de `shared`. Revisar `makedepends` o esperar corrección
  en ALARM antes de dar por buena una versión nueva de libssc.
- `make build` rc=0 (17/11 21:00) y `make packages` rc=0 (18/11 05:28).
- **Lección de la tanda 0 (18/11, tarde):** `make snapshot` abortó con checksum de
  `inputplumber`. Causa: tres builds distintos con el MISMO `0.84.0-1` (2.687.592 B del 5/11 en la
  caché del chroot, 2.800.256 B del 16/11 en la caché del rootfs, 2.802.596 B del 17/11 en
  `localrepo`). El rootfs se quedó con el viejo porque la versión no cambió, así que pacman no
  reinstala → la imagen habría llevado binarios viejos sin que ningún `-Syu` los arreglara.
  **Regla nueva: si se recompila un paquete y cambian los bytes, hay que subir `pkgrel`.** Se subió
  `inputplumber` a `0.84.0-2` y se relanzó build + snapshot.
- **Deuda de empaquetado detectada con la imagen (18/11, noche):** `make sd-image` abortó con
  `host-owned (uid/gid 1000) path leaked into the image: /usr/lib/libretro/2048_libretro.so`.
  Causa: `libretro-cores-pocknix` (y otros que instalan binarios vendorizados con `cp -a`) dejan
  ficheros con dueño `alarm:alarm` en el paquete, y al instalarse en el rootfs quedan `1000:1000`.
  En el rootfs solo afectaba a **32 ficheros, todos en `/usr/lib/libretro`**; se corrigieron con
  `chown -R root:root` y la imagen siguió.
  **Pendiente de verdad:** añadir `chown -R root:root "$pkgdir"` al final de `package()` en los
  PKGBUILD que copian binarios (libretro-cores-pocknix, libretro-azahar, libretro-bsnes-hd,
  libretro-hakux, deckstation-arm, dolphin-emu, cemu, es-de, inputplumber, gtk2…) **antes** de
  publicarlos, o el dispositivo recibirá ficheros con dueño incorrecto por `-Syu`.
- **Dos huecos de imagen detectados el 19/11 (Odin actualizada a la base 20261118):**
  1. Falta el symlink **`/usr/sbin -> bin`** (imagen merged-usr incompleta). Rompe cualquier
     paquete cuyo unit use `/usr/sbin/...`: pasó con **tailscale** (`ExecStart=/usr/sbin/tailscaled`,
     status 203/EXEC). Workaround aplicado en la Odin: `ln -sfn bin /usr/sbin`. Arreglar en la
     imagen (lo normal es que lo traiga `filesystem`).
  2. **tailscale no viene instalado** en la imagen; se instaló a mano (`1.104.7`) para poder
     acceder a la consola fuera de casa. Decidir si entra en la lista de paquetes.
  Nota: el `pocknix-base.db` publicado **no incluye `glibc`** (el gate de publicación se quedó sin
  universo base); para publicar se usó el db de `base-prev` como caché. Revisar el snapshot.
- **`pocknix-base-lock 20261118-1` publicado** (shared, firmado) e instalado en la Odin: cierra el
  cabo suelto de la tanda 0.
## Tanda 1 — estado 19/11
- ✅ **Publicados en `shared`**: `inputplumber 0.84.0-2`, `pocknix-decky 0.1.0-73`,
  `pocknix-desktop-kde 0.1.0-4`, `pocknix-power-profiles 0.1.0-1` (primera vez),
  `pocknix-turnip-x86 -2`, `suyu-libretro 0.0.4-2`, `retroarch-autoconfig -4`,
  `retroarch-shaders -4`.
- ✅ **Kernel publicado** en `sm8750`: `linux-pocknix-sm8750 7.2.15-4`.
- ❌ **`pocknix-emulation 0.1.0-17` bloqueado (rama)**: en la rama `lepton` el PKGBUILD
  referencia ficheros (`eden-qt-config.ini.in`, `pocknix-cemu-profile`,
  `cemu-controller0.xml.in`, `dolphin-Dolphin.ini.in`, `dolphin-GCPadNew.ini.in`,
  `retroarch-mGBA-gba.cfg/.slangp`) que se movieron en el refactor `4f9f0950`
  ("split glue into pocknix-emu-*"). En `main` va por **pkgrel 24**. Hay que decidir rama
  antes de publicar emulación. Los paquetes de emulación además se saltan salvo
  `POCKNIX_EMULATION=1`.
- ⚠️ **Gate de publicación**: el `pocknix-base.db` nuevo **no trae glibc** y el de
  `base-prev` no trae los paquetes nuevos (`power-profiles-daemon`). Solución usada: fusionar
  por **%NAME%** (no por directorio) ambos dbs en `build/stage/.dbcache/base.db`.
  Arreglar el snapshot para que el db no pierda paquetes que vienen del tarball.
- ⚠️ **Tres al revés** (repo más nuevo que árbol): `gamescope` (-3 vs -1),
  `pocknix-base` (0.2.0-10 vs -8), `pocknix-bsp-sm8750` (-52 vs -51). Re-sincronizar árbol.
- La Odin ve ya **7 actualizaciones** por repo (inputplumber, decky, desktop-kde,
  turnip-x86, suyu + 2 de base). Pendiente de aplicar/probar.

## Tanda 2 — realidad (19/11/2026, mañana)

Lo que el plan llamaba "bumps de pkgrel de upstream" **no existe como tal**: `lepton` y
`origin/main` han divergido. Un merge de `origin/main` sobre `lepton` da **97 conflictos**,
incluidos parches nuestros (decky/pocknix-control, branding, mesa, gamescope, fex, turnip).
Por eso la actualización se hace **paquete a paquete por el centro** (`sync-to-os.sh`).

### Bug de flujo encontrado y corregido

`sync-to-os.sh` copia `config/pocknix.conf` del centro al árbol. El pin `POCKNIX_BASE_SNAPSHOT`
estaba **solo en el árbol** (lo escribe `make snapshot`), así que el primer sync lo borró y el
build pasó a hacerse contra **ALARM en vivo** en vez de contra la base congelada.
- Corregido: pin `20261118` escrito en el **centro** (`config/pocknix.conf`) y sincronizado.
- Pendiente de arreglar de raíz: `make snapshot` debería escribir el pin en el centro, no en el árbol.

### Publicado

- `pocknix-steam-full 0.1.0-5` — porta de upstream: `license` GPL-2.0-or-later, `pkgdesc` con
  Lepton. Mantiene `pocknix-turnip-x86`, `pocknix-vk-valve`, `gamescope-session-steam`.
  Divergencias documentadas en el PKGBUILD: **sin** `steamos-manager` (lo instala el BSP) y
  **sin** `pocknix-lepton` (arrastra `android-tools`, que no está en nuestra base).
- `pocknix-session 0.1.0-7`, `pocknix-homescreen 0.1.0-3`, `pocknix-sdcard-automount 0.1.0-8`,
  `pocknix-gamepad-calibration 0.1.0-5` — alineados con upstream (sin delta propio; solo
  comentarios y el arranque de `pocknix-game-session.target` antes de Steam).

### Aparcados a propósito

- `pocknix-snapshots` 6→10: exige `pocknix-bsp-common>=0.1.0-37` y nosotros vamos por **-28**
  (con parches propios). Va con la tanda del BSP.
- `pocknix-lock-migrate` 4→6: exige `pocknix-snapshots>=0.1.0-8`, o sea, depende del anterior.
- `pocknix-steamos-shim` 9→10: **divergencia consciente**. Nuestra 9 trae el OOBE marker y los
  stubs `steamos-mandatory-update`/`jupiter-initial-firmware-update` que upstream no tiene;
  su 10 solo reañade `steamos-priv-write` + regla polkit. Revisar cuando se sepa qué arregla.
- `pocknix-steam` 76→80 y `pocknix-tools` 25→26: cientos de líneas en la capa de Steam; sesión
  dedicada con pruebas.

## Corrección importante (19/11/2026): OpenABL

La Odin 3 y el sistema **usan OpenABL desde hace tiempo**. Queda obsoleto cualquier análisis que
diga "seguimos con el ABL de ROCKNIX / Fase 2 pendiente" y lo use como bloqueo del BSP.
Consecuencia: el hook `00-pocknix-abl-gate.hook` de `bsp-common` (aborta si `needs_openabl!=0`)
**no debería bloquear** nuestra cadena de actualización. El resto del riesgo del BSP sigue en pie
(`pocknix-boot-deploy` reensambla `/flash/KERNEL` y `pocknix-repo-line` reescribe `pacman.conf`).

### Estado de la tanda 2 (cierre)

Publicado hoy: `pocknix-steam-full 0.1.0-5`, `pocknix-session 0.1.0-7`,
`pocknix-homescreen 0.1.0-3`, `pocknix-sdcard-automount 0.1.0-8`,
`pocknix-gamepad-calibration 0.1.0-5`, `pocknix-steam 0.1.0-77` (backports de wrapper).
Reparado y pendiente de build: `pocknix-emulation 0.1.0-18` (7 ficheros restaurados).
Bloqueos reales detectados: `pocknix-tools` 25→28 exige `pocknix-ui`, que **no está publicado**;
`bsp-common` 28→41 es reescritura de arranque (reasignar parches propios, no copiar).

## Cierre 19/11/2026 (tarde): re-sync + Odin reiniciada y verificada

### Re-sync de los tres paquetes atrasados
- `gamescope`: el árbol tenía un cambio sin commitear que bajaba `pkgrel 3 -> 1`. Restaurado HEAD (-3, el publicado).
- `pocknix-base`: la version publicada (-10) vivia solo en la rama `sync/upstream-20261108`; es nuestro
  **branding CalvOS Updater**. Traida al árbol.
- `pocknix-bsp-sm8750`: la -52 publicada venia del commit del **Portal** (`21f42fa`, rama `portal-wip`),
  nunca fusionado. Cherry-pick sobre master (sin conflictos) + `pkgrel 53` y `pocknix-firmware-sm8750 5`,
  porque el contenido resultante difiere del -52 ya publicado (mismo numero con distintos bytes esta prohibido).

### Bug real encontrado: pocknix-power-profiles no arrancaba
`WantedBy=multi-user.target` + `After=power-profiles-daemon` (que va tras multi-user) creaba un ciclo de
ordenacion; systemd lo rompia **matando el bridge**, asi que el selector de perfiles del escritorio no
sincronizaba con bajo/medio/alto. Corregido a `WantedBy=graphical.target` (`0.1.0-2`).
**Trampa**: en la Odin quedaban DOS restos del despliegue manual del 16/11: la unidad en
`/etc/systemd/system/` y un symlink de enable en `/usr/lib/systemd/system/multi-user.target.wants/`.
Hubo que borrar ambos; con solo el paquete corregido el ciclo persistia.

### Estado de la Odin tras reiniciar (verificado)
- Arranque ~55 s, **0 servicios fallidos**, **0 ciclos de ordenacion**.
- `pocknix-game-session.target` **activo** -> el flujo nuevo de `pocknix-session 7` funciona de verdad.
- Bridge activo y sincronizado (`balanced <-> medio`); audio `PipeWire 1.6.11` OK; gamescope + Steam arriba.
- `/flash/KERNEL` reconstruido por el BSP (18M, `KERNEL.bak` conservado), sin incidencias de arranque.

### Pendiente / sin confirmar
- Errores `geni_i2c a94000.i2c` + `gpi a00000.dma-controller` (18 cada uno por arranque). Solo hay 2
  arranques en el journal, no se puede comparar con antes; kernel identico 7.2.15. Vigilar.
- `pipewire -2` sigue sin estar en `pocknix-base` (se resolvio forzando `extra` en la Odin).
