# Pendientes — actualizado 23/11/2026 (cierre de sesion)

Orden aproximado de prioridad. Dueño: (A) Alfred / (F) Fransis.

## En espera de terceros
1. **SkywardRecomp aarch64/Turnip** (A, en espera). Issues abiertos upstream:
   - **#18** `vkCreateDevice` falla con `VK_ERROR_FEATURE_NOT_PRESENT` porque el port pide
     `uniformAndStorageBuffer8BitAccess` sin comprobarlo y Turnip no lo soporta.
   - **#19** `FATAL: no function at 70007c6440 (lr=70007c5370 nninitStartup+7c4d50)` al menu,
     determinista (~40 s, sin input, tambien con `LARECOMP_NO_LAUNCHER=1`).
   - Apaño local mientras: `SkywardRecomp-v0.8.2-aarch64-turnipfix.AppImage` (shim
     `libvkshim.so` embebido + `AppRun` parcheado) y lanzador `~/.local/bin/skywardrecomp`
     (hace `cd` a la carpeta del juego) + entrada de menu. Cuando salga release: volver al oficial.
2. **Whiplash / Unchained (recomp Xbox)** (A, aparcado). El port no tiene clave de idioma en el
   TOML (el truco `user_language` es de otros ports); el juego toma el idioma del sistema Xbox.
   Español requiere ISO PAL/EUR o menu in-game. Fransis: "olvida juegos".

## Tienda CalvOS
3. (F) Probar con mando **A/B y flechas en fichas y dialogos** (`pocknix-ui 3` + `pocknix-store 6`).
4. (A) Afinar filtro del catalogo AppImages (615 entradas; hay falsos positivos tipo activitywatch).
5. (A) Iconos por app en AppImages (hoy icono generico `application-x-executable`).
6. (A) Buscador dentro de la tienda (hoy solo navegacion por secciones).
7. **"Actualizar sistema" en la tienda: DESCARTADO** (redundante con CalvOS Tools).

## Odin / audio / kernel
8. (A) **class-H**: portar la ventana del puerto (`qcom,ports-hstart/hstop`) al DTS y validar
   `HCtrl`/`BlockCtrl3` como hizo Armada; entonces volver a `CLS_H_LOHIFI`. Hoy: **class-AB a 0 dB**
   fijo en `AYN/Odin3/HiFi.conf` (UCM, bsp-sm8750 58).
9. (A) Investigar por que **gamescope murio** durante la actualizacion de WProton.
10. (A) **Tanda 6 del kernel** (parches pendientes de revisar).
11. (F) **Icono de CalvOS Store**.


## Audio
16. **[PRIORITARIO] Separar el UCM en perfiles Headphones / Speaker, como Armada.**
    Es la solucion de fondo al zumbido y a las conmutaciones de jack: con un perfil combinado,
    PipeWire cambia la disponibilidad del puerto pero NO re-ejecuta la secuencia, y el transporte
    SoundWire puede quedar mal (zumbido + distorsion al enchufar con audio en curso).
    - Diseñar los perfiles en `packages/pocknix-bsp-sm8750/HiFi.conf` (verbs/devices separados).
    - Probar TODAS las combinaciones: jack con juego, jack en silencio, dock, HDMI, suspend.
    - Si va bien, el daemon `pocknix-audio-jack` puede quedar solo como red de seguridad.
    - Ver `docs/INCIDENCIA-AUDIO-ZUMBIDO-JUEGO.md` (evidencias, descartes y plan de captura).
17. Capturar `hw_params` del PCM en estado MALO vs bueno (con audio sonando) para ver si hay firma
    objetiva (periodo/buffer) y, si la hay, fijarla en PipeWire.
18. El servicio en caliente de hoy (reset en enchufe + reset tardio + setpriv + ganancia) va en
    **`bsp 63`**; `bsp 62` publicado no los lleva.

## BSP
12. (A+F) **Ola BSP 30 → 41**: merge en seco ya analizado; ejecutar con Fransis delante
    (`docs/OLA-BSP-30-a-41.md`). De ahi cuelgan `pocknix-snapshots 10`, `lock-migrate 6`,
    `pocknix-tools` moderno y `pocknix-steam` upstream (`cores.sh`).

## Red
13. (F) **Tailscale** en la Odin nueva: sigue `Logged out`; regenerar enlace y entrar.

## Juegos (aparcado por Fransis)
14. Super Mario 3D Land: compilado + pack HD en el PC (`~/games/SuperMario3DLand`); falta decidir
    atajo de Steam y copia al disco de 16 TB.

## Samba (cerrado, con causa documentada)
15. **Regresion nuestra, no del sistema**: la entrada SMB de la tienda habilitaba `smb.service` sin
    ejecutar `pocknix-share on`, que es quien crea la entrada de passdb de `deck`; sin ella el
    invitado no puede escribir (`smb2_create` -> ACCESS_DENIED). Ver
    `docs/INCIDENCIA-2026-11-23-SAMBA.md`.
    - Arreglado en el dispositivo (`pocknix-share on`) y en el motor (`pocknix-store 7`, paso
      `share-passdb`; repara con `sudo pocknix-store setup samba`).
    - PC: `/mnt/odin` montado como **guest** con automount (sin fichero de credenciales).
    - Unico limite que queda: la **raiz de `/opt`** es `root:root`; sus subcarpetas si se escriben.

## Como retomar
- Build de referencia: `make packages PKG="..."` en el chroot (uno a la vez), `make stage PKG="..."`,
  `make publish DEVICE=sm8750`. Gate: nombres nuevos necesitan depender de una raiz.
- Paquete nuevo nuestro = `calvos-*` (`docs/CONVENCIONES-PAQUETES.md`).
- Catalogo AppImages: `tools/gen-appman-catalogue.py ~/.local/share/AM/aarch64-appimages`.

## Cierre 23/11 23:59 — estado exacto
- **`pocknix-store 0.1.0-7` PUBLICADO** en `r2:pocknix/sm8750` (paso `share-passdb` para Samba), pero
  **NO instalado en la Odin**: al ir a instalarlo, la Odin ya no respondia (apagada o sin red).
- Mañana, lo primero:
  1. Encender la Odin y `sudo pacman -Syu` (instala store 7).
  2. Probar la reparacion: `sudo pdbedit -x deck` y luego `sudo pocknix-store setup samba`;
     comprobar con `smbclient //127.0.0.1/opt -N -c 'cd decomps; mkdir zz-test'` y borrar.
  3. Comprobar que `/mnt/odin` del PC sigue escribiendo como invitado (ya se probo el 23/11).
- El PC de sobremesa quedo **apagado** al cierre.

## Avance 24/11 (manana)
- **Hecho (pendiente de probar esta noche)**: `chiaki4deck` en Streaming, **`calvos-rustdesk`** en
  Network (optdepend de `pocknix-desktop-full`), chips de filtro (Todo/Juegos/Multimedia) en
  AppImages, y `docs/CALVOS-WELCOME.md` con el alcance del asistente.
- **Siguiente**: implementar Fase 1 de `calvos-welcome`.
