# HDR APAGADO POR DEFECTO (11/10/2026) — no reintroducir

## Sintoma
Con HDR activo globalmente, en algunos juegos/aplicaciones el **QAM** (menu de Steam) y
**mangoapp/MangoHUD** caian **DETRAS** del juego: no recibian foco ni toque y se pintaban
por debajo. Ver tambien `docs/QAM-DETRAS-DEL-JUEGO-2026-10-09.md` (ese era el
`--force-composition`; ESTE es el HDR).

## Causa raiz
Al anunciar HDR al cliente de Steam — gate **`STEAM_GAMESCOPE_HDR_SUPPORTED=1`** +
perfil Lua del panel (`overlay/usr/share/gamescope/scripts/10-armada/ayn.icna3520.oled.lua`,
HDR 650 nits) + `GAMESCOPE_INTERNAL_DEVICE_ID=ayn-odin-3` — el **cliente Steam pone
`GAMESCOPE_DISPLAY_HDR_ENABLED=1` por defecto**. Eso mete a gamescope en su ruta HDR con
**tonemap por fotograma en TODO, tambien en SDR** → sobrecarga de pacing → el QAM y
mangoapp acaban **detras** del juego.

## Fix (aplicado)
`export STEAM_GAMESCOPE_HDR_SUPPORTED=0` en los DOS sitios donde estaba a 1:

| Fichero | Que |
|---|---|
| `packages/pocknix-steam/pocknix-steam` | lanzador (ruta con gamescope propio) |
| `packages/gamescope-session-steam/usr/share/gamescope-session-plus/sessions.d/steam` | sesion gamescope-session-plus |

Versiones: **`pocknix-steam` pkgrel 67** · **`gamescope-session-steam` pkgrel 4**.

Se **mantiene** el perfil Lua del panel y `GAMESCOPE_INTERNAL_DEVICE_ID` (la colorimetria es
correcta y el panel se identifica), y el **toggle manual de `pocknix-control`**
(`py_modules/pocknix_control/hdr.py`) sigue disponible para activar HDR a proposito
(por juego/sesion).

## ⛔ NO reintroducir
- **`STEAM_GAMESCOPE_HDR_SUPPORTED=1`** en `pocknix-steam` ni en la sesion.
- **`ENABLE_GAMESCOPE_HDR=1`** (la variable de ArmadaOS: ellos tambien lo dejan apagado por
  defecto; `ENABLE_GAMESCOPE_HDR=1` es **opt-in** en armada).
- No "arreglar" el HDR por defecto para que el QAM lo muestre: el cliente Steam ARM64 ni
  siquiera expone ese toggle; el nuestro (`pocknix-control`) es la via manual.

## Como verificar (con la sesion arrancada)
1. `grep -n STEAM_GAMESCOPE_HDR_SUPPORTED` en los dos ficheros -> **0**.
2. Con la sesion en marcha: `xprop -root GAMESCOPE_DISPLAY_HDR_ENABLED` -> **0** (arranque SDR).
3. Abrir el QAM dentro de un juego: se pinta **ENCIMA** y responde a foco/toque;
   MangoHUD (mangoapp) tambien queda por encima.

## Referencias
- Memoria: 09/10/2026 — hipotesis "HDR global ON -> tonemap por frame -> MangoHUD/QAM detras"
  y decision "si se confirma el HDR -> dejarlo OFF".
- `docs/ARMADAOS-ROCKNIX-SEGUNDA-PASADA.md`: armada deja HDR apagado por defecto.

---

# 🛠️ ACTUALIZACIÓN 13/10/2026 — **el gate NO basta** (comprobado en la Odin)

**Corrección importante de este documento**: el fix del 11/10 (`STEAM_GAMESCOPE_HDR_SUPPORTED=0`)
**no impide** que HDR arranque encendido. Medido en la Odin el 13/10:

- El gate **sí llega**: `STEAM_GAMESCOPE_HDR_SUPPORTED=0` esta en el env de `gamescope`, del cliente
  `steam` y de **todos** los `steamwebhelper`.
- **Y aun asi** `GAMESCOPE_DISPLAY_HDR_ENABLED=1` al arrancar la sesion: el cliente Steam ARM64 pone
  el atomo a 1 por su cuenta (el panel se anuncia HDR-capable via el perfil Lua +
  `GAMESCOPE_INTERNAL_DEVICE_ID`).
- Por eso el paso 2 de "**Como verificar**" (esperar `GAMESCOPE_DISPLAY_HDR_ENABLED = 0` solo con el
  gate) es **incorrecto**: da 1.

**El mecanismo que de verdad lo apaga (13/10)** es **`pocknix-hdr-restore`**: fuerza el atomo a la
preferencia guardada (`/var/lib/pocknix/hdr-enabled`, que escribe pocknix-control) o al defecto de
`/etc/pocknix/hdr.conf` (**off**), con **dos pasadas** (su propio comentario: *"el cliente Steam lo
pone a 1 al arrancar"*). Va en `pocknix-system-overlay` (overlay `etc/systemd/system/
pocknix-hdr-restore.service`, `WantedBy=multi-user.target`) y el `.install` la **habilita**.

**Ojo con el gate**: el centro lleva a proposito `STEAM_GAMESCOPE_HDR_SUPPORTED=1` en
`packages/pocknix-steam` (comentario del propio fichero: el panel **debe** anunciarse HDR o el toggle
de PocknixControl dice "el panel no reporta HDR"; el apagado por defecto lo resuelve el restore).
Es decir, el `⛔ NO reintroducir` de arriba esta **superado**: lo prohibido es dejarlo en 1 **sin** el
restore.

**Verificacion buena (13/10)**: `xprop -root GAMESCOPE_DISPLAY_HDR_ENABLED` -> **0** con el servicio
`pocknix-hdr-restore` activo + el QAM/mangoapp **encima** del juego. Medido en la Odin: paso de 1 a 0
al arrancar el servicio.
