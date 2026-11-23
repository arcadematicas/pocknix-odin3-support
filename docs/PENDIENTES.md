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

## BSP
12. (A+F) **Ola BSP 30 → 41**: merge en seco ya analizado; ejecutar con Fransis delante
    (`docs/OLA-BSP-30-a-41.md`). De ahi cuelgan `pocknix-snapshots 10`, `lock-migrate 6`,
    `pocknix-tools` moderno y `pocknix-steam` upstream (`cores.sh`).

## Red
13. (F) **Tailscale** en la Odin nueva: sigue `Logged out`; regenerar enlace y entrar.

## Juegos (aparcado por Fransis)
14. Super Mario 3D Land: compilado + pack HD en el PC (`~/games/SuperMario3DLand`); falta decidir
    atajo de Steam y copia al disco de 16 TB.

## Samba (cerrado, por si acaso)
15. **Hecho**: usuario Samba `deck`/`pocknix` (el invitado era solo lectura), `/mnt/odin` montado en
    el PC con automount. La **raiz de `/opt`** sigue siendo `root:root` (no escribible); sus
    subcarpetas si. Solo tocar si Fransis quiere crear carpetas nuevas en la raiz de `/opt`.

## Como retomar
- Build de referencia: `make packages PKG="..."` en el chroot (uno a la vez), `make stage PKG="..."`,
  `make publish DEVICE=sm8750`. Gate: nombres nuevos necesitan depender de una raiz.
- Paquete nuevo nuestro = `calvos-*` (`docs/CONVENCIONES-PAQUETES.md`).
- Catalogo AppImages: `tools/gen-appman-catalogue.py ~/.local/share/AM/aarch64-appimages`.
