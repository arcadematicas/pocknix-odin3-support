# Lepton — juegos Android en CalvOS (integración 08/11/2026)

**Qué es**: Lepton es la herramienta de compatibilidad **Android** de Valve para
ARM64 (la que usa el Steam Frame). Steam la trata como un *compat tool* más (app
**3029110**): se elige por juego en **Propiedades → Compatibilidad**.

> Decisión: **se mantiene DeckStation** para emulación clásica y **no** se adopta
> el Store/`pocknix-emu-*` de upstream. Lepton se integra como capa aparte.

## Qué trae upstream (y hemos incorporado)

| Paquete | Papel |
|---|---|
| `pocknix-lepton` | **Host side**: capa Fossilize, teclado AOSP LatinIME, `steamvr`, rutas que esperan los scripts de Lepton. |
| `pocknix-mesa-android` | Mesa **bionic** (freedreno + zink + turnip) + Fossilize, la vendor tree Android que Lepton monta en su contenedor. Build pesado (NDK r28c, API 30). |
| `pocknix-waydroid` | Integración Waydroid (tuning + instalador de APK). **Opcional**, no instalado por defecto. |

Los tres salen de `origin/main` y viven en la rama **`lepton`** del fork
(`arcadematicas/pocknix-os`).

## Cambios en CalvOS

- `config/packages/base.list`: deps de runtime de Lepton —
  `podman`, `crun`, `catatonit`, `passt`, `android-tools`, `attr`,
  `inotify-tools`, `patch` (`util-linux` y `jq` ya estaban).
- `pocknix-steam`: exporta antes del lanzamiento
  `SYSTEM_PATH`, `SYSTEM_LD_LIBRARY_PATH` y `APP_WANTS_FLATSCREEN=true`
  (Steam arranca los compat tools sin `PATH`; sin el flag, Lepton abre las apps
  Android headless).
- `pocknix-steam-full`: `depends` de `pocknix-lepton` (arrastra `pocknix-mesa-android`),
  `pkgrel 5`.
- `pocknix-steam` `pkgrel 74` (el cambio de env).

## Requisitos del sistema

- **binder/binderfs** en el kernel: ya está en `build-kernel.sh`.
- `gamescope` con **paso de toques** a ventanas Wayland nativas (patch upstream
  `0015-wlserver-pass-touch-through-to-native-wayland-windows.patch`, guardado en
  `reference/upstream-gamescope-0015-touch.patch`). Nuestra base
  es **OGC 3.16.31** y la serie de parches es distinta (0014 nuestro “swallow
  ignored touch”); **hay que portar el 0015** a nuestra base. Sin él, el toque en
  juegos Android puede no llegar; ratón/teclado/Steam Input sí.
- El **runtime Android** lo pone Valve vía Steam (no va en el paquete).

## Cómo probar (cuando el build termine)

1. Instalar los paquetes en la Odin (`pocknix-lepton`, `pocknix-mesa-android` + deps).
2. En Steam: **Propiedades del juego/app Android → Compatibilidad → Lepton**.
3. Lanzar desde el modo juego. Logs: `journalctl -b` y los de Steam.
4. Probar primero un APK sencillo (no un juego 3D) para validar contenedor,
   pantalla y entrada.

## Pendiente

- [ ] Build de `pocknix-mesa-android` (en curso; es el largo).
- [ ] Build/instalación de `pocknix-lepton` (depende del anterior).
- [ ] Portar el patch de toque a nuestro gamescope OGC.
- [ ] Probar Lepton en la Odin con un APK real y decidir si entra en la imagen
      por defecto o como capa opcional.
- [ ] Publicar los paquetes en R2 una vez validados.
