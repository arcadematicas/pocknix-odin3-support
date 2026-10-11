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
